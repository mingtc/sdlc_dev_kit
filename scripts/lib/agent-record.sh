#!/usr/bin/env bash
# KIT-CLASS: KIT — which agent made a commit: the record, its transport, and the landing check.
# See process/contracts/agent-record.md.
#
# THE RECORD. One ref per commit, refs/kit-agent/<commit-sha>, pointing at a blob of one or more
# lines `agent=<id> session=<id>`. The agent id is the harness's per-agent id for a dispatched
# agent and `main` for a session's own thread; the session id is the harness session's. The
# IDENTITY is the pair: `main` in two sessions is two identities (a fresh top-level session is a
# separate reviewer), and two dispatched agents in one session are two identities (an orchestrated
# run's Dev and QA legs). scripts/hooks/agent-record.sh writes the record around every Bash call;
# nothing else in the kit writes it. A commit claimed by two identities (two Bash calls running at
# once, both seeing it appear) carries both lines and is AMBIGUOUS: the check below treats it as
# unrecorded rather than guessing.
#
#   kit_agent_claim <repo> <sha> <agent> <session>
#     Adds this agent's line to <sha>'s record (creating it). Compare-and-swap on the ref, so two
#     writers at once never lose a line. Returns non-zero only when every attempt lost the race.
#
#   kit_agent_of <repo> <sha>
#     Prints the DISTINCT identities recorded for <sha>, one `agent=<id> session=<id>` line each:
#     the local record and the one fetched from the remote (refs/kit-agent-remote/), read together.
#     Nothing printed = no record.
#
#   kit_agent_records_push <repo> <remote>
#     Pushes refs/kit-agent/* to <remote>. Never fatal: a record the remote already holds with
#     other content is rejected without --force (by design: a record is not rewritten remotely),
#     and that is reported in one line on stderr.
#
#   kit_agent_records_fetch <repo> <remote>
#     Fetches <remote>'s refs/kit-agent/* into refs/kit-agent-remote/*, never over the local
#     records. Never fatal.
#
#   kit_agent_landing_check <repo> <trunk-rev> <card-id> <branch> [<card-root>]
#     Refuses (kit_refuse 1 qa-verdict-same-agent) when the identity recorded for the QA-verdict
#     commit is one of the identities recorded for the branch's code commits
#     (<trunk-rev>..<branch>). The QA-verdict commit is the newest commit on <trunk-rev> that changed
#     the card's `## QA Verdict` section; the card is <card-root>/<column>/<card-id>-*.md, found by
#     id in each tree (<card-root> defaults to `progress`; a slice's is
#     `progress/subtasks/<parent>`). When the verdict commit has no single recorded identity, or no
#     code commit does, nothing can be compared: it prints `AGENT_CHECK: UNRUNNABLE — <why>` on
#     stdout and returns 0. Never a pass.

KIT_AGENT_NS="refs/kit-agent"
KIT_AGENT_REMOTE_NS="refs/kit-agent-remote"

kit_agent_claim() {
  local repo="$1" sha="$2" agent="$3" session="$4" ref old body blob try=0
  ref="$KIT_AGENT_NS/$sha"
  while [ "$try" -lt 5 ]; do
    try=$((try + 1))
    old="$(git -C "$repo" rev-parse -q --verify "$ref" 2>/dev/null || true)"
    body="$( { [ -z "$old" ] || git -C "$repo" cat-file blob "$old" 2>/dev/null
               printf 'agent=%s session=%s\n' "$agent" "$session"; } | sort -u )"
    blob="$(printf '%s\n' "$body" | git -C "$repo" hash-object -w --stdin 2>/dev/null)" || return 1   # return-class: internal
    [ "$blob" != "$old" ] || return 0
    git -C "$repo" update-ref "$ref" "$blob" "$old" 2>/dev/null && return 0
  done
  return 1   # return-class: internal
}

kit_agent_of() {
  local repo="$1" sha="$2" ref
  for ref in "$KIT_AGENT_NS/$sha" "$KIT_AGENT_REMOTE_NS/$sha"; do
    git -C "$repo" rev-parse -q --verify "$ref" >/dev/null 2>&1 || continue
    git -C "$repo" cat-file blob "$ref" 2>/dev/null
  done | sed -n 's/^\(agent=[^ ]* session=[^ ]*\)$/\1/p' | sort -u
}

kit_agent_records_push() {
  local repo="$1" remote="$2" any
  any="$(git -C "$repo" for-each-ref --count=1 --format='x' "$KIT_AGENT_NS/" 2>/dev/null)"
  [ -n "$any" ] || return 0
  git -C "$repo" push --quiet "$remote" "$KIT_AGENT_NS/*:$KIT_AGENT_NS/*" >/dev/null 2>&1 \
    || echo "Note: some agent records (refs/kit-agent/*) did not reach $remote — the remote holds a different record for the same commit, or the push failed. The trunk push itself is unaffected." >&2
  return 0
}

kit_agent_records_fetch() {
  local repo="$1" remote="$2"
  git -C "$repo" fetch --quiet "$remote" "+$KIT_AGENT_NS/*:$KIT_AGENT_REMOTE_NS/*" >/dev/null 2>&1 || true
  return 0
}

# _kit_agent_verdict_section <repo> <rev> <card-id> <card-root> — the card's `## QA Verdict`
# section at <rev> (heading to the next `## ` heading), or nothing when the card is absent there.
_kit_agent_verdict_section() {
  local repo="$1" rev="$2" id="$3" root="$4" path
  path="$(git -C "$repo" ls-tree -r --name-only "$rev" -- "$root/" 2>/dev/null \
          | awk -v id="$id" -v root="$root/" '!found && index($0, root) == 1 {
              rest = substr($0, length(root) + 1); n = split(rest, p, "/")
              if (n == 2 && index(p[2], id "-") == 1) { print; found = 1 } }')"
  [ -n "$path" ] || return 0
  git -C "$repo" show "$rev:$path" 2>/dev/null \
    | awk 'done { next } /^## QA Verdict/ { on = 1; print; next } on && /^## / { done = 1; next } on { print }'
}

kit_agent_landing_check() {
  local repo="$1" trunk="$2" id="$3" branch="$4" root="${5:-progress}"
  local c verdict="" new old v_agents code_agents="" a sha n_code=0 n_rec=0

  # The verdict commit: the newest trunk commit whose `## QA Verdict` section differs from its
  # parent's. The card is looked up by id in each tree, so a column move is not a change.
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    new="$(_kit_agent_verdict_section "$repo" "$c" "$id" "$root")"
    old="$(git -C "$repo" rev-parse -q --verify "$c^" >/dev/null 2>&1 \
           && _kit_agent_verdict_section "$repo" "$c^" "$id" "$root" || true)"
    if [ -n "$new" ] && [ "$new" != "$old" ]; then verdict="$c"; break; fi
  done <<< "$(git -C "$repo" log --format=%H "$trunk" -- ":(glob)$root/*/${id}-*.md" 2>/dev/null)"

  if [ -z "$verdict" ]; then
    echo "AGENT_CHECK: UNRUNNABLE — no commit on $trunk wrote ${id}'s ## QA Verdict section, so there is no verdict commit to attribute."
    return 0
  fi
  v_agents="$(kit_agent_of "$repo" "$verdict")"
  case "$(printf '%s' "$v_agents" | awk 'END { print NR }')" in
    0) echo "AGENT_CHECK: UNRUNNABLE — the QA verdict commit ${verdict:0:9} has no identity record (written outside the harness hooks, or the hooks are not wired)."; return 0 ;;
    1) : ;;
    *) echo "AGENT_CHECK: UNRUNNABLE — the QA verdict commit ${verdict:0:9} is claimed by more than one identity ($(printf '%s' "$v_agents" | tr '\n' ';')), so it is not attributable."; return 0 ;;
  esac

  while IFS= read -r sha; do
    [ -n "$sha" ] || continue
    n_code=$((n_code + 1))
    a="$(kit_agent_of "$repo" "$sha")"
    case "$(printf '%s' "$a" | awk 'END { print NR }')" in
      1) n_rec=$((n_rec + 1)); code_agents="${code_agents}${a}"$'\n' ;;
    esac
  done <<< "$(git -C "$repo" rev-list "$trunk..$branch" 2>/dev/null)"

  if [ "$n_rec" -eq 0 ]; then
    echo "AGENT_CHECK: UNRUNNABLE — none of the ${n_code} code commit(s) on '$branch' has a single recorded identity, so the verdict's ($v_agents) has nothing to be compared with."
    return 0
  fi
  case $'\n'"$code_agents" in *$'\n'"$v_agents"$'\n'*)
    kit_refuse 1 qa-verdict-same-agent \
      "Error: ${id}'s QA verdict (commit ${verdict:0:9}) was committed by the same agent, in the same session, that committed code on '$branch': $v_agents." \
      "       The checker must not be the author." \
      "Next: have a different agent — a dispatched QA agent, or a fresh session — re-walk the AC on the branch and commit a changed ## QA Verdict table on the trunk (the check reads the NEWEST commit that changed that section), then re-run the command that refused." \
      "      Re-committing this table under the same agent and session changes nothing; if no other agent is available, stop and hand off." \
      "       NOTHING WAS CHANGED." ;;
  esac
  return 0
}
