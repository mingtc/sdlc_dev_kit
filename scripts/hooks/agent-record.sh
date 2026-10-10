#!/usr/bin/env bash
# KIT-CLASS: KIT — records which agent made each commit, around every Bash call.
# See process/contracts/agent-record.md.
#
# Wired in .claude/settings.json.example as PreToolUse(Bash) `agent-record.sh pre`, and as
# PostToolUse(Bash) and PostToolUseFailure(Bash) `agent-record.sh post`. The harness passes the
# event as JSON on stdin; this reads `tool_use_id`, `cwd`, `session_id` and `agent_id` (present
# only for a dispatched agent; its absence is the session's own thread, recorded as `main`).
#
#   pre   snapshot every branch and remote-tracking tip and every worktree's HEAD, keyed by
#         tool_use_id, under the repository's git directory.
#   post  take the commits reachable from a tip that moved and not from the snapshot, keep only
#         those some worktree's HEAD reflog shows this repository CREATING (commit, cherry-pick,
#         revert, am, a rebase's pick) — a fetched or pulled commit is not the caller's — and add
#         `agent=<id> session=<id>` to each one's record (lib/agent-record.sh).
#
# It rewrites nothing, blocks nothing and prints nothing: all output is discarded and it always
# exits 0, so a defect here can never stop a Bash call. A payload it cannot read records nothing.
set -u

mode="${1:-}"
payload="$(cat 2>/dev/null || true)"
exec >/dev/null 2>&1

_field() {   # a top-level JSON string field, read from the single-line payload; empty if absent
  printf '%s' "$payload" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p"
}

id="$(_field tool_use_id)"
cwd="$(_field cwd)"
case "$id" in ''|*[!A-Za-z0-9_-]*) exit 0 ;; esac
[ -n "$cwd" ] && cd "$cwd" 2>/dev/null || exit 0
gitdir="$(git rev-parse --git-common-dir 2>/dev/null)" || exit 0
gitdir="$(cd "$gitdir" 2>/dev/null && pwd)" || exit 0
dir="$gitdir/kit-agent-pending"
marker="$dir/$id"

_tips() {
  { git for-each-ref --format='%(objectname)' refs/heads refs/remotes  # card-read-exempt: collects every ref tip; resolves no card branch
    git worktree list --porcelain | sed -n 's/^HEAD //p'; } 2>/dev/null | sort -u
}

case "$mode" in
  pre)
    mkdir -p "$dir" 2>/dev/null || exit 0
    # A call whose post never ran leaves its snapshot behind; a day-old one is dropped.
    find "$dir" -type f -mmin +1440 -exec rm -f {} + 2>/dev/null
    _tips > "$marker" 2>/dev/null
    ;;
  post)
    [ -f "$marker" ] || exit 0
    # shellcheck source=../lib/agent-record.sh
    . "$(dirname "$0")/../lib/agent-record.sh" 2>/dev/null || { rm -f "$marker"; exit 0; }
    agent="$(_field agent_id)"; [ -n "$agent" ] || agent=main
    session="$(_field session_id)"; [ -n "$session" ] || session=unknown
    now="$(_tips)"
    new="$(printf '%s\n' "$now" | grep -vxF -f "$marker")"
    if [ -n "$new" ]; then
      # shellcheck disable=SC2046  # one sha per word, by construction
      created="$(git rev-list $new --not $(cat "$marker") 2>/dev/null)"
      made="$(git worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | while IFS= read -r w; do
                git -C "$w" reflog show --format='%H %gs' HEAD 2>/dev/null
              done | grep -E '^[0-9a-f]+ (commit( \((amend|initial|merge)\))?|cherry-pick|revert|am|[a-z -]*rebase[a-z -]* \((pick|reword|edit|squash|fixup|continue)\)): ' \
                   | cut -d' ' -f1 | sort -u)"
      printf '%s\n' "$created" | while IFS= read -r sha; do
        [ -n "$sha" ] || continue
        case $'\n'"$made"$'\n' in
          *$'\n'"$sha"$'\n'*) kit_agent_claim "$PWD" "$sha" "$agent" "$session" ;;
        esac
      done
    fi
    rm -f "$marker"
    ;;
esac
exit 0
