# KIT-CLASS: KIT — self-test cases: the agent record (scripts/hooks/agent-record.sh) and
# finish-pr.sh's same-agent refusal. See process/contracts/agent-record.md.
#
# The harness cannot dispatch harness agents, so the hook is driven with the payloads the harness
# sends (tool_use_id, cwd, session_id, and agent_id for a dispatched agent), Pre before and Post
# after real git work in a sandbox — the order the harness runs them in.

# _ar_call <agent|main>[@<session>] <tool-use-id> <command…> — runs <command…> in $SB_WORK between
# the hook's pre and post, as one Bash call of <agent> in <session> (default sess-1) would be. Fails
# the case if the hook printed or exited non-zero.
_ar_call() {
  local agent="${1%@*}" session="sess-1" tuid="$2" hook="$SB_WORK/scripts/hooks/agent-record.sh" payload out rc
  case "$1" in *@*) session="${1#*@}" ;; esac
  shift 2
  if [ "$agent" = main ]; then
    payload="{\"session_id\":\"$session\",\"tool_use_id\":\"$tuid\",\"cwd\":\"$SB_WORK\",\"tool_name\":\"Bash\"}"
  else
    payload="{\"session_id\":\"$session\",\"tool_use_id\":\"$tuid\",\"agent_id\":\"$agent\",\"cwd\":\"$SB_WORK\",\"tool_name\":\"Bash\"}"
  fi
  out="$(printf '%s' "$payload" | "$hook" pre 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && [ -z "$out" ] || cf "($tuid) the pre hook exited $rc or printed: $out"
  ( cd "$SB_WORK" && "$@" ) >/dev/null 2>&1
  out="$(printf '%s' "$payload" | "$hook" post 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && [ -z "$out" ] || cf "($tuid) the post hook exited $rc or printed: $out"
}

# _ar_agents <sha> — the agents recorded for <sha>, space-separated (empty: no record).
_ar_agents() {
  local ref="refs/kit-agent/$1"
  git -C "$SB_WORK" rev-parse -q --verify "$ref" >/dev/null 2>&1 || return 0
  git -C "$SB_WORK" cat-file blob "$ref" | sed -n 's/^agent=\([^ ]*\).*/\1/p' | tr '\n' ' ' | sed 's/ $//'
}

_ar_commit() {   # <file> <message> — a commit the role-prefix hook lets through
  echo "$1" > "$1" && git add "$1" && MSG_OK=1 git commit -q -m "$2"
}

# =============================================================================
# CASE — THE HOOK RECORDS THE AGENT THAT CREATED A COMMIT, AND NOTHING IT MERELY RECEIVED.
# =============================================================================
case_agent_record_hook_attributes_created_commits() {
  cf_reset
  [ -x "$REAL_REPO_ROOT/scripts/hooks/agent-record.sh" ] || {
    cf "scripts/hooks/agent-record.sh is not in the shipped tree or not executable"
    finish "agent-record.sh records main and a dispatched agent for the commits each created, nothing for a pulled commit, and never prints or fails"
    return
  }
  make_sandbox
  publish_sandbox
  local c_main c_sub c_theirs c_both other="$SB_TMP/other" out rc

  # (a) The session's own thread: no agent_id in the payload → agent=main.
  _ar_call main tu-a _ar_commit a.txt "[Dev] main thread commit"
  c_main="$(git -C "$SB_WORK" rev-parse HEAD)"
  [ "$(_ar_agents "$c_main")" = main ] || cf "(a) a main-thread commit records '$(_ar_agents "$c_main")', want 'main'"

  # (b) A dispatched agent: its agent_id is the record.
  _ar_call agent-dev-7 tu-b _ar_commit b.txt "[Dev] subagent commit"
  c_sub="$(git -C "$SB_WORK" rev-parse HEAD)"
  [ "$(_ar_agents "$c_sub")" = agent-dev-7 ] || cf "(b) a dispatched agent's commit records '$(_ar_agents "$c_sub")', want 'agent-dev-7'"
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1

  # (c) A commit made elsewhere and PULLED in this call is not this caller's: no record.
  git clone -q "$SB_ORIGIN" "$other" >/dev/null 2>&1
  ( cd "$other" && git config user.email o@sandbox.invalid && git config user.name O \
      && _ar_commit c.txt "[Dev] someone else's commit" && git push -q origin "HEAD:$SB_TRUNK" ) >/dev/null 2>&1
  c_theirs="$(git -C "$other" rev-parse HEAD)"
  _ar_call agent-qa-3 tu-c git pull -q --ff-only origin "$SB_TRUNK"
  [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$c_theirs" ] \
    || _control_did_not_run "pull the other clone's commit into the sandbox"
  [ -z "$(_ar_agents "$c_theirs")" ] || cf "(c) a pulled commit was recorded as '$(_ar_agents "$c_theirs")' — a pull is not authorship"

  # (d) Two calls running at once both see one commit appear: both claims are kept (ambiguous),
  #     neither overwrites the other.
  local hook="$SB_WORK/scripts/hooks/agent-record.sh"
  printf '{"session_id":"s","tool_use_id":"tu-d1","agent_id":"agent-x","cwd":"%s"}' "$SB_WORK" | "$hook" pre
  printf '{"session_id":"s","tool_use_id":"tu-d2","agent_id":"agent-y","cwd":"%s"}' "$SB_WORK" | "$hook" pre
  ( cd "$SB_WORK" && _ar_commit d.txt "[Dev] overlapping calls" ) >/dev/null 2>&1
  printf '{"session_id":"s","tool_use_id":"tu-d1","agent_id":"agent-x","cwd":"%s"}' "$SB_WORK" | "$hook" post
  printf '{"session_id":"s","tool_use_id":"tu-d2","agent_id":"agent-y","cwd":"%s"}' "$SB_WORK" | "$hook" post
  c_both="$(git -C "$SB_WORK" rev-parse HEAD)"
  [ "$(_ar_agents "$c_both")" = "agent-x agent-y" ] || cf "(d) overlapping calls recorded '$(_ar_agents "$c_both")', want both 'agent-x agent-y'"

  # (e) A payload it cannot read, and a cwd outside any repository: exit 0, silent, nothing written.
  out="$(printf 'not json' | "$hook" post 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && [ -z "$out" ] || cf "(e) an unreadable payload: exit $rc, output '$out' — want 0 and silence"
  out="$(printf '{"tool_use_id":"tu-e","cwd":"%s"}' "$SB_TMP" | "$hook" pre 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && [ -z "$out" ] || cf "(e) a cwd outside a repository: exit $rc, output '$out' — want 0 and silence"

  # (f) Every snapshot a post consumed is gone.
  local left
  left="$(ls -A "$SB_WORK/.git/kit-agent-pending" 2>/dev/null)"
  [ -z "$left" ] || cf "(f) snapshots left behind after their post ran: $left"

  finish "agent-record.sh records main and a dispatched agent for the commits each created, nothing for a pulled commit, both claims for overlapping calls, and never prints or fails"
  teardown
}

# _ar_landing <id> <dev-agent[@session]|none> <qa-agent[@session]|none> — the real order: the card is in
# dev_complete/ with no verdict yet; Dev commits on the branch; QA writes the ## QA Verdict table
# on the trunk and pushes it. `none` runs that step with no hook (no record). Sets AR_OUT, AR_RC.
_ar_landing() {
  local id="$1" dev="$2" qa="$3" card full
  make_sandbox
  seed_issue dev_complete "$id" agentcheck chore "Agent check" "feature/$id-agentcheck"
  card="$SB_WORK/progress/dev_complete/$id-agentcheck.md"
  full="$SB_TMP/card-with-verdict.md"
  cp "$card" "$full"
  awk '/^## QA Verdict/ { skip = 1; next } skip && /^## / { skip = 0 } !skip { print }' "$full" > "$card"
  publish_sandbox

  if [ "$dev" = none ]; then seed_branch "$id" agentcheck "agentcheck.txt"
  else _ar_call "$dev" "tu-dev-$id" seed_branch "$id" agentcheck "agentcheck.txt"; fi

  _ar_qa_verdict() { cp "$full" "$card" && git add "$card" && MSG_OK=1 git commit -q -m "[QA] $id: QA verdict" && git push -q origin "$SB_TRUNK"; }
  if [ "$qa" = none ]; then ( cd "$SB_WORK" && _ar_qa_verdict ) >/dev/null 2>&1
  else _ar_call "$qa" "tu-qa-$id" _ar_qa_verdict; fi

  AR_OUT="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" ./scripts/finish-pr.sh "$id" 2>&1 )"; AR_RC=$?
}

# =============================================================================
# CASE — finish-pr.sh REFUSES A QA VERDICT COMMITTED BY THE IDENTITY (session, agent) THAT WROTE
#        THE CODE.
# =============================================================================
case_finish_pr_refuses_a_verdict_by_the_code_agent() {
  cf_reset
  local id

  # (a) One dispatched agent, one session, wrote the code and the verdict: refused, nothing moved.
  id="$SB_PREFIX-861"
  _ar_landing "$id" agent-dev-1@sess-x agent-dev-1@sess-x
  [ "$AR_RC" -eq 1 ] || cf "(a) a1/X both sides: finish-pr exited $AR_RC, want 1: $(printf '%s' "$AR_OUT" | tail -5)"
  case "$AR_OUT" in *"same agent, in the same session"*) : ;; *) cf "(a) the refusal does not say the verdict's agent and session wrote the code" ;; esac
  git -C "$SB_WORK" rev-parse -q --verify "refs/heads/feature/$id-agentcheck" >/dev/null 2>&1 \
    || cf "(a) the branch is gone — the refusal ran after something moved"
  origin_has_path "progress/dev_complete/$id-agentcheck.md" || cf "(a) the card left dev_complete/ on a refused landing"
  teardown

  # (b) The session's own thread wrote both, in ONE session: refused.
  id="$SB_PREFIX-862"
  _ar_landing "$id" main@sess-x main@sess-x
  [ "$AR_RC" -eq 1 ] || cf "(b) main/X both sides: finish-pr exited $AR_RC, want 1: $(printf '%s' "$AR_OUT" | tail -5)"
  teardown

  # (c) Control: two dispatched agents of one session (an orchestrated run's Dev and QA legs) —
  #     lands, and the records reach the remote with the trunk push.
  id="$SB_PREFIX-863"
  _ar_landing "$id" agent-dev-1@sess-x agent-qa-2@sess-x
  [ "$AR_RC" -eq 0 ] || cf "(c) a1/X vs a2/X: finish-pr exited $AR_RC, want 0: $(printf '%s' "$AR_OUT" | tail -5)"
  origin_has_path "progress/qa_complete/$id-agentcheck.md" || cf "(c) a1/X vs a2/X: the card did not reach qa_complete/"
  case "$AR_OUT" in *"AGENT_CHECK: UNRUNNABLE"*) cf "(c) both sides carry a record, yet the check printed UNRUNNABLE" ;; esac
  [ -n "$(git -C "$SB_WORK" ls-remote origin 'refs/kit-agent/*' 2>/dev/null)" ] \
    || cf "(c) no refs/kit-agent/* on the remote after the landing pushed the trunk"
  teardown

  # (d) Control: the session's own thread in two DIFFERENT sessions (a fresh top-level QA session)
  #     — lands.
  id="$SB_PREFIX-866"
  _ar_landing "$id" main@sess-x main@sess-y
  [ "$AR_RC" -eq 0 ] || cf "(d) main/X vs main/Y: finish-pr exited $AR_RC, want 0: $(printf '%s' "$AR_OUT" | tail -5)"
  case "$AR_OUT" in *"AGENT_CHECK: UNRUNNABLE"*) cf "(d) both sides carry a record, yet the check printed UNRUNNABLE" ;; esac
  teardown

  # (e) No record on either side (hooks not wired): UNRUNNABLE printed, and it lands.
  id="$SB_PREFIX-864"
  _ar_landing "$id" none none
  [ "$AR_RC" -eq 0 ] || cf "(e) no records: finish-pr exited $AR_RC, want 0: $(printf '%s' "$AR_OUT" | tail -5)"
  case "$AR_OUT" in *"AGENT_CHECK: UNRUNNABLE"*) : ;; *) cf "(e) no records, and no 'AGENT_CHECK: UNRUNNABLE' line — a check that did not run must say so" ;; esac
  teardown

  # (f) The verdict is recorded and the code is not: UNRUNNABLE, lands.
  id="$SB_PREFIX-865"
  _ar_landing "$id" none agent-qa-2@sess-x
  [ "$AR_RC" -eq 0 ] || cf "(f) code unrecorded: finish-pr exited $AR_RC, want 0: $(printf '%s' "$AR_OUT" | tail -5)"
  case "$AR_OUT" in *"AGENT_CHECK: UNRUNNABLE"*) : ;; *) cf "(f) code commits unrecorded, and no 'AGENT_CHECK: UNRUNNABLE' line" ;; esac
  teardown

  finish "finish-pr.sh refuses a verdict whose (session, agent) committed the branch's code (a1/X twice, main/X twice), lands a1/X vs a2/X and main/X vs main/Y and pushes the records, and prints UNRUNNABLE when either side has no record"
}

# =============================================================================
# CASE — subtask.sh move <slice> qa_complete APPLIES THE SAME CHECK TO A SLICE'S OWN VERDICT.
#        The real order: the slice card is in dev_complete/ with no verdict; Dev commits on the
#        slice's branch; QA writes the slice's ## QA Verdict on the trunk; then the move.
# =============================================================================
case_subtask_move_refuses_a_verdict_by_the_code_agent() {
  cf_reset
  if ! has_issue_template; then skp "subtask.sh move <slice> qa_complete refuses a slice verdict committed by the identity that wrote its code" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  local p row qa want f full sb out rc
  for row in 867:agent-dev-1@sess-x:1 868:agent-qa-2@sess-x:0; do
    p="$SB_PREFIX-${row%%:*}"; qa="${row#*:}"; want="${qa##*:}"; qa="${qa%:*}"
    make_sandbox
    _seed_parent "$p"
    sb="feature/${p}-s1-agent"
    f="$(_seed_subtask "$p" s1 dev_complete agent "A slice under the agent check" "$sb")"
    full="$SB_TMP/slice-with-verdict.md"
    cp "$f" "$full"
    awk '/^## QA Verdict/ { skip = 1; next } skip && /^## / { skip = 0 } !skip { print }' "$full" > "$f"
    publish_sandbox
    _ar_slice_dev() { git checkout -q -b "$sb" "$SB_TRUNK" && _ar_commit "slice${p##*-}.txt" "[Dev] ${p}-s1: a real change" && git push -q -u origin "$sb" && git checkout -q "$SB_TRUNK"; }
    _ar_call agent-dev-1@sess-x "tu-sdev-$p" _ar_slice_dev
    _ar_slice_qa() { cp "$full" "$f" && git add "$f" && MSG_OK=1 git commit -q -m "[QA] ${p}-s1: QA verdict" && git push -q origin "$SB_TRUNK"; }
    _ar_call "$qa" "tu-sqa-$p" _ar_slice_qa
    out="$( cd "$SB_WORK" && "$SB_WORK/scripts/subtask.sh" move "${p}-s1" qa_complete 2>&1 )"; rc=$?
    if [ "$want" = 1 ]; then
      [ "$rc" -eq 1 ] || cf "(${qa}) same identity on the slice's code and verdict: subtask.sh move exited $rc, want 1: $(printf '%s' "$out" | tail -5 | tr '\n' '|')"
      origin_has_path "progress/subtasks/${p}/dev_complete/${p}-s1-agent.md" || cf "(${qa}) the slice moved on a refused check"
      case "$out" in *"same agent, in the same session"*) : ;; *) cf "(${qa}) the refusal is not the same-agent one: $(printf '%s' "$out" | tail -3 | tr '\n' '|')" ;; esac
    else
      [ "$rc" -eq 0 ] || cf "(${qa}) different identities: subtask.sh move exited $rc, want 0: $(printf '%s' "$out" | tail -5 | tr '\n' '|')"
      origin_has_path "progress/subtasks/${p}/qa_complete/${p}-s1-agent.md" || cf "(${qa}) the slice did not advance to qa_complete/"
      case "$out" in *"AGENT_CHECK: UNRUNNABLE"*) cf "(${qa}) both sides carry a record, yet the check printed UNRUNNABLE" ;; esac
    fi
    teardown
  done
  finish "subtask.sh move <slice> qa_complete refuses a slice verdict committed by the (session, agent) that committed the slice branch's code, and moves one committed by another agent"
}
