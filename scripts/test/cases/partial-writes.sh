# KIT-CLASS: MIXED — self-test harness, a write that fails part-way. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/partial-writes.sh — sourced by scripts/test/run.sh, never run on its own.
# One class: a sequence of writes where a later one fails (a hook refusal, an unwritable path, an
# ignored path). The script must say so, leave the state it found or name the exit from the state it
# left, and never print the success line of a write that did not happen.
# Faults are made with chmod and a directory in a file's place; a run as root cannot fail that way,
# so the cases that need it say so and skip.
# =============================================================================

_pw_is_root() { [ "$(id -u)" = 0 ]; }

# _pw_kwt_clean — status 0 when the kanban worktree holds no staged or modified path.
_pw_kwt_clean() { [ -z "$(git -C "$SB_WORK/.kanban-wt" status --porcelain --untracked-files=no 2>/dev/null)" ]; }

# =============================================================================
# CASE — register-commit.sh: A PATH THAT FAILS AFTER THE FIRST IS STAGED LEAVES THE KANBAN WORKTREE
# AS IT FOUND IT, AND THE REFUSAL NAMES A NEXT.
# Five faults, each behind a first path that stages cleanly: a gitignored path, a directory, an
# unreadable file, a path outside the project, and a message the commit hook refuses. After each, the
# kanban worktree is clean, a Next is printed, and the next call lands. The outside path writes nothing.
# =============================================================================
case_register_commit_leaves_the_kanban_worktree_as_found_when_a_later_write_fails() {
  cf_reset
  local L="register-commit.sh refuses a later path that is ignored, a directory, unreadable or outside the project, and a message the hook refuses, each with a Next, the kanban worktree clean and nothing written outside"
  if _pw_is_root; then skp "$L" "running as root: chmod cannot make a file unreadable"; return; fi
  make_sandbox
  mkdir -p "$SB_WORK/docs"
  printf 'one\n' > "$SB_WORK/docs/a.md"
  printf 'ignored.txt\n' > "$SB_WORK/.gitignore"
  publish_sandbox
  local out rc n=0 fault
  printf 'two\n' >> "$SB_WORK/docs/a.md"
  printf 'x\n' > "$SB_WORK/ignored.txt"
  printf 'x\n' > "$SB_WORK/docs/b.md"; chmod 000 "$SB_WORK/docs/b.md"
  printf 'MINE\nextra\n' > "$SB_TMP/outsider.txt"   # holds every line of the user's file below, so the stale guard lets it through
  printf 'MINE\n' > "$SB_WORK/outsider.txt"   # the user's own file where the worktree's ../outsider.txt lands
  for fault in ignored dir unreadable outside trailer; do
    n=$((n + 1))
    local args=(docs/a.md) msg="m$n"
    case "$fault" in
      ignored)    args+=(ignored.txt) ;;
      dir)        args+=(docs) ;;
      unreadable) args+=(docs/b.md) ;;
      outside)    args+=(../outsider.txt) ;;
      trailer)    msg=$'trailer\n\nCo-Authored-By: Claude <noreply@example.invalid>' ;;
    esac
    rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "$msg" "${args[@]}" 2>&1 )" || rc=$?
    [ "$rc" -ne 0 ] || cf "($fault) exited 0 on a write that cannot land: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
    printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "($fault) no Next: line: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
    if [ -d "$SB_WORK/.kanban-wt" ]; then
      _pw_kwt_clean || cf "($fault) the kanban worktree holds staged changes: $(git -C "$SB_WORK/.kanban-wt" status --short | tr '\n' '|')"
    fi
  done
  [ "$(cat "$SB_WORK/outsider.txt" 2>/dev/null)" = MINE ] || cf "(outside) the user's own $SB_WORK/outsider.txt was overwritten or deleted"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "control" docs/a.md 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(control) the call after the refusals did not land (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  chmod 644 "$SB_WORK/docs/b.md" 2>/dev/null
  finish "$L"
  teardown
}

# =============================================================================
# CASE — register-commit.sh RECORDS `landed` ONLY AFTER THE PUBLISH.
# A pre-receive hook on the remote refuses the push: the commit stays local, and no record says it landed.
# =============================================================================
case_register_commit_records_landed_only_after_the_push() {
  cf_reset
  local L="register-commit.sh writes its landed record after the publish, so a refused push leaves no record that anything landed"
  make_sandbox
  printf 'one\n' > "$SB_WORK/note.md"
  publish_sandbox
  printf '#!/bin/sh\nexit 1\n' > "$SB_ORIGIN/hooks/pre-receive"; chmod +x "$SB_ORIGIN/hooks/pre-receive"
  printf 'two\n' >> "$SB_WORK/note.md"
  local out rc
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK KIT_PROGRESS_DIR="$SB_TMP/records" ./scripts/register-commit.sh --role PM --message "refused push" note.md 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(prereq) the push was not refused, so the premise is gone: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  if cat "$SB_TMP"/records/*.tsv 2>/dev/null | grep -F 'landed 1 metadata' >/dev/null; then
    cf "a landed record exists for a commit the remote refused"
  fi
  finish "$L"
  teardown
}

# =============================================================================
# CASE — move-issue.sh AND subtask.sh: A COMMIT THE HOOK REFUSES UNDOES THE MOVE, SAYS SO, AND PRINTS
# NO `Moved:` LINE. The next move is not refused for a dirty worktree.
# =============================================================================
case_a_refused_board_commit_undoes_the_move_and_says_so() {
  cf_reset
  local L="move-issue.sh and subtask.sh, when the commit hook refuses the note, print no Moved: line, put the kanban worktree back, print a Next, and the next move lands"
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  make_sandbox
  local id="$SB_PREFIX-871" q="$SB_PREFIX-872" out rc bad=$'bad\n\nCo-Authored-By: Claude <noreply@example.invalid>'
  seed_issue todo "$id" hookmv chore "A card the hook refuses to move"
  seed_issue in_progress "$q" parent chore "Parent in progress"
  mkdir -p "$SB_WORK/progress/subtasks/$q/todo"
  seed_issue "subtasks/$q/todo" "$q-s1" slice chore "A slice"
  publish_sandbox
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/move-issue.sh "$id" in_progress --role Dev --note "$bad" 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(move-issue) exited 0 on a refused commit"
  printf '%s\n' "$out" | grep -E '^Moved:' >/dev/null && cf "(move-issue) printed Moved: for a move that did not happen"
  printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "(move-issue) no Next: line: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  _pw_kwt_clean || cf "(move-issue) the kanban worktree holds the staged move: $(git -C "$SB_WORK/.kanban-wt" status --short | tr '\n' '|')"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/move-issue.sh "$id" in_progress --role Dev --note "clean" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(move-issue control) the next move was refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/subtask.sh move "$q-s1" in_progress --note "$bad" 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(subtask) exited 0 on a refused commit"
  printf '%s\n' "$out" | grep -E '^Moved:' >/dev/null && cf "(subtask) printed Moved: for a move that did not happen"
  printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "(subtask) no Next: line: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  _pw_kwt_clean || cf "(subtask) the kanban worktree holds the staged move: $(git -C "$SB_WORK/.kanban-wt" status --short | tr '\n' '|')"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — archive.sh: A COMMIT THE HOOK REFUSES LEAVES NO SWEEP STAGED. A pre-commit hook refuses the
# sweep's commit: the kanban worktree is clean, a Next is printed, no "Commit:" or "Published:" line is,
# and the sweep lands once the hook allows it.
# =============================================================================
case_a_refused_archive_commit_leaves_the_kanban_worktree_clean_and_says_so() {
  cf_reset
  local L="archive.sh --apply, when the commit hook refuses the sweep, prints a Next and no Commit: or Published: line, leaves the kanban worktree clean, and the next sweep lands"
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-873" arch chore "A card the hook refuses to archive"
  publish_sandbox
  local hooks="$SB_TMP/refusing-hooks" out rc
  mkdir -p "$hooks"; printf '#!/bin/sh\necho "hook: no commits today" >&2\nexit 1\n' > "$hooks/pre-commit"; chmod +x "$hooks/pre-commit"
  git -C "$SB_WORK" config core.hooksPath "$hooks"
  rc=0; out="$( cd "$SB_WORK" && ./scripts/archive.sh --apply 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "exited 0 on a refused commit"
  printf '%s\n' "$out" | grep -E '^(Commit|Published):' >/dev/null && cf "printed a Commit:/Published: line for a sweep that did not commit"
  printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "no Next: line: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$out" | grep -F 'archive.sh --apply again' >/dev/null || cf "the Next is the generic one, not the sweep's: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  _pw_kwt_clean || cf "the kanban worktree holds the staged sweep: $(git -C "$SB_WORK/.kanban-wt" status --short | tr '\n' '|')"
  git -C "$SB_WORK" config core.hooksPath "$SB_WORK/scripts/githooks"
  rc=0; out="$( cd "$SB_WORK" && ./scripts/archive.sh --apply 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(control) the next sweep was refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  [ -f "$SB_WORK/progress/done/$SB_PREFIX-873-arch.md" ] || cf "(control) the card was not swept once the hook allowed it"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — a board op TERMINATED BETWEEN ITS LOCAL COMMIT AND ITS PUSH. A pre-receive hook holds the
# push; the op's process group gets TERM. The exit prints the unpushed commit and a Next that, run as
# printed, publishes it; the next op then lands.
# =============================================================================
case_a_board_op_terminated_in_its_push_names_the_unpushed_commit_and_how_to_publish_it() {
  cf_reset
  local L="a board op terminated between its commit and its push prints the unpushed commit and a Next that publishes it, and the next op lands"
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  make_sandbox
  local id="$SB_PREFIX-874" out ref rc=0 pid i hold="$SB_TMP/in-hook" cmds sha
  seed_issue todo "$id" termmv chore "A card whose move is terminated in its push"
  publish_sandbox
  printf '#!/bin/sh\ntouch "%s"\nsleep 30\nexit 1\n' "$hold" > "$SB_ORIGIN/hooks/pre-receive"; chmod +x "$SB_ORIGIN/hooks/pre-receive"
  ( cd "$SB_WORK" && exec perl -e 'use POSIX; setsid(); exec @ARGV' env -u MSG_OK ./scripts/move-issue.sh "$id" in_progress --role Dev --note "terminated" ) > "$SB_TMP/term.out" 2>&1 &
  pid=$!
  for i in $(seq 1 60); do [ -e "$hold" ] && break; sleep 1; done
  [ -e "$hold" ] || cf "(prereq) the push never reached the hook, so the premise is gone: $(tr '\n' '|' < "$SB_TMP/term.out" | cut -c1-200)"
  kill -TERM -- "-$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  out="$(cat "$SB_TMP/term.out")"
  printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "the terminated op printed no Next: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  [ "$(git -C "$SB_WORK/.kanban-wt" rev-list --count "origin/$SB_TRUNK..HEAD" 2>/dev/null)" = 1 ] || cf "(prereq) no unpushed commit in the kanban worktree"
  sha="$(git -C "$SB_WORK/.kanban-wt" rev-parse --short HEAD 2>/dev/null)"
  printf '%s\n' "$out" | grep -F "$sha" >/dev/null || cf "the exit text does not name the unpushed commit $sha: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -F 'may or may not' >/dev/null || cf "the exit text does not hedge whether the push landed: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  rm -f "$SB_ORIGIN/hooks/pre-receive"
  # The next op's refusal over that commit accepts the exit text as the word that it was not pushed.
  rc=0; ref="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/move-issue.sh "$id" qa_complete --role Dev --note "meanwhile" 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "the next op ran over the unpushed commit"
  printf '%s\n' "$ref" | grep -F 'exit text of an op that ended after its commit while its push was still to run or in flight' >/dev/null || cf "the sync's refusal does not accept the exit text as the word the commit is unpublished: $(printf '%s' "$ref" | tr '\n' '|' | cut -c1-300)"
  cmds="$(printf '%s\n' "$out" | sed -n 's/^ *\(git -C .*\)$/\1/p')"
  if [ -z "$cmds" ]; then cf "the exit text prints no git command on a line of its own"; else
    bash -c "$cmds" >/dev/null 2>&1 || cf "a printed command failed: $cmds"
  fi
  git -C "$SB_ORIGIN" log --format=%s -3 "$SB_TRUNK" 2>/dev/null | grep -F 'terminated' >/dev/null || cf "the printed commands did not publish the commit"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/move-issue.sh "$id" dev_complete --role Dev --note "after" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "the next op after the printed Next was refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — a TERM TO THE OP'S OWN PID, not its group, during a push that lands: the exit text hedges and never says the
# commit is not on the remote; the printed commands, run once the push has landed, are harmless, and the next op lands.
# =============================================================================
case_a_term_to_the_ops_pid_alone_does_not_report_a_landing_push_as_unpublished() {
  cf_reset
  local L="a board op sent TERM to its own pid while its push lands anyway says the push may or may not have landed, never that it did not, and the printed commands are harmless"
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  make_sandbox
  local id="$SB_PREFIX-875" out rc=0 pid i hold="$SB_TMP/in-hook2" cmds
  seed_issue todo "$id" termpid chore "A card whose op is terminated while its push lands"
  publish_sandbox
  printf '#!/bin/sh\ntouch "%s"\nsleep 6\nexit 0\n' "$hold" > "$SB_ORIGIN/hooks/pre-receive"; chmod +x "$SB_ORIGIN/hooks/pre-receive"
  ( cd "$SB_WORK" && exec perl -e 'use POSIX; setsid(); exec @ARGV' env -u MSG_OK ./scripts/move-issue.sh "$id" in_progress --role Dev --note "landed anyway" ) > "$SB_TMP/term2.out" 2>&1 &
  pid=$!
  for i in $(seq 1 60); do [ -e "$hold" ] && break; sleep 1; done
  [ -e "$hold" ] || cf "(prereq) the push never reached the hook, so the premise is gone: $(tr '\n' '|' < "$SB_TMP/term2.out" | cut -c1-200)"
  kill -TERM "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  out="$(cat "$SB_TMP/term2.out")"
  printf '%s\n' "$out" | grep -E 'NOT on |is not on ' >/dev/null && cf "the exit text states the commit is unpublished, which the orphaned push disproves: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -F 'may or may not' >/dev/null || cf "the exit text does not hedge whether the push landed: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  for i in $(seq 1 60); do git -C "$SB_ORIGIN" log --format=%s -3 "$SB_TRUNK" 2>/dev/null | grep -F 'landed anyway' >/dev/null && break; sleep 1; done
  git -C "$SB_ORIGIN" log --format=%s -3 "$SB_TRUNK" 2>/dev/null | grep -F 'landed anyway' >/dev/null || cf "(prereq) the orphaned push never landed, so the premise is gone"
  cmds="$(printf '%s\n' "$out" | sed -n 's/^ *\(git -C .*\)$/\1/p')"
  if [ -z "$cmds" ]; then cf "the exit text prints no git command on a line of its own"; else
    bash -c "$cmds" >/dev/null 2>&1 || cf "a printed command failed after the push had landed: $cmds"
  fi
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/move-issue.sh "$id" dev_complete --role Dev --note "after" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "the next op was refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — set-models.sh: A WRITE IT CANNOT MAKE IS REFUSED BEFORE THE FIRST WRITE; NO SUCCESS LINE, NO RECORD.
# A directory where a rewrite's scratch file goes, for the pin and for the ladder; and a pin directory
# the user cannot write to. Nothing changes, a Next is printed, and the control still sets.
# =============================================================================
case_set_models_refuses_a_write_it_cannot_make_and_prints_no_success_line() {
  cf_reset
  local L="set-models.sh refuses before writing when a pin, the ladder or their directory cannot be written, prints no success line, records nothing and names a Next"
  make_sandbox
  local ad orch
  read -r ad orch <<<"$(_seed_provisioning_sandbox)"
  if [ -z "$ad" ]; then skp "$L" "no .claude/agents + roles/orchestrator.md in the real tree"; teardown; return; fi
  local sm="$SB_WORK/scripts/set-models.sh" out rc fault before after
  before="$(cat "$ad/dev-worker.md" "$orch")"
  for fault in pin-new ladder-new agents-dir; do
    case "$fault" in
      pin-new)    mkdir "$ad/dev-worker.md.new" ;;
      ladder-new) mkdir "$orch.new" ;;
      agents-dir) if _pw_is_root; then continue; fi; chmod 555 "$ad" ;;
    esac
    rc=0; out="$( cd "$SB_WORK" && ./scripts/set-models.sh --class dev --model mX --effort high 2>&1 )" || rc=$?
    [ "$rc" -ne 0 ] || cf "($fault) exited 0 on a write that cannot be made: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
    printf '%s\n' "$out" | grep -E '^set-models: dev -> ' >/dev/null && cf "($fault) printed the success line for a write that did not happen"
    printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "($fault) no Next: line: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
    after="$(cat "$ad/dev-worker.md" "$orch")"
    [ "$before" = "$after" ] || cf "($fault) the pin or the ladder changed although the run refused"
    grep -F 'dev-worker.md' "$SB_WORK/.claude/model-pins.record" 2>/dev/null | grep -F mX >/dev/null && cf "($fault) the record names the pin the run did not write"
    case "$fault" in
      pin-new)    rmdir "$ad/dev-worker.md.new" ;;
      ladder-new) rmdir "$orch.new" ;;
      agents-dir) chmod 755 "$ad" ;;
    esac
  done
  rc=0; out="$( cd "$SB_WORK" && ./scripts/set-models.sh --class dev --model mX --effort high 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(control) the write that can be made was refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  # the record of what was written: read-only, it is refused before any write like the files it sits beside
  if ! _pw_is_root && [ -f "$SB_WORK/.claude/model-pins.record" ]; then
    before="$(cat "$ad/dev-worker.md" "$orch")"
    chmod 444 "$SB_WORK/.claude/model-pins.record"
    rc=0; out="$( cd "$SB_WORK" && ./scripts/set-models.sh --class dev --model mY --effort low 2>&1 )" || rc=$?
    chmod 644 "$SB_WORK/.claude/model-pins.record"
    [ "$rc" -ne 0 ] || cf "(record) exited 0 although the record cannot be written"
    printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "(record) no Next: line"
    [ "$before" = "$(cat "$ad/dev-worker.md" "$orch")" ] || cf "(record) a pin or the ladder changed although the run refused"
  fi
  finish "$L"
  teardown
}

# =============================================================================
# CASE — update_vendored.sh: A FAILED rm OR cp ON THE FAST PATH IS NOT A VENDORING.
# A vendor directory the user cannot write to, beside an older artifact. The updater exits non-zero, prints
# no pin line on stdout (consumers capture it), and the older artifact is the only one there.
# =============================================================================
case_update_vendored_does_not_print_a_pin_for_an_artifact_it_could_not_write() {
  cf_reset
  local L="update_vendored.sh exits non-zero with an empty stdout when the vendor directory cannot be written, and vendors normally when it can"
  if _pw_is_root; then skp "$L" "running as root: chmod cannot make a directory unwritable"; return; fi
  make_sandbox
  if [ ! -f "$SB_WORK/consumers/update_vendored.sh" ]; then teardown; skp "$L" "consumers/ absent"; return; fi
  local P="$SB_TMP/cp" out err rc upd
  mkdir -p "$P"
  _consumer_project "$P"
  upd="$P/consumers/update_vendored.sh"
  _consumer_fill "$upd" pin first refresh config docs
  mkdir -p "$P/consumer/vendor-ro" "$P/consumer/vendor-ok"
  : > "$P/consumer/vendor-ro/thing-0.9.0.tgz"
  chmod 555 "$P/consumer/vendor-ro"
  rc=0; out="$( cd "$P/consumer" && env VENDORED_NAME=thing ARTIFACT_GLOB='thing-*.tgz' VENDORED_REPO_URL="file://$P/upstream" VENDOR_DIR=./vendor-ro bash "$upd" 2>"$SB_TMP/upd.err" )" || rc=$?
  err="$(cat "$SB_TMP/upd.err")"
  [ "$rc" -ne 0 ] || cf "(fault) exited 0 although the artifact could not be written: $(printf '%s' "$err" | tr '\n' '|' | cut -c1-240)"
  [ -z "$out" ] || cf "(fault) printed a pin line on stdout for an artifact that is not there: $out"
  case "$err" in *"Vendored:"*) cf "(fault) said Vendored: for an artifact that is not there" ;; esac
  [ ! -e "$P/consumer/vendor-ro/thing-1.0.0.tgz" ] || cf "(prereq) the artifact was written, so the fault did nothing"
  chmod 755 "$P/consumer/vendor-ro"
  rc=0; out="$( cd "$P/consumer" && env VENDORED_NAME=thing ARTIFACT_GLOB='thing-*.tgz' VENDORED_REPO_URL="file://$P/upstream" VENDOR_DIR=./vendor-ok bash "$upd" 2>/dev/null )" || rc=$?
  [ "$rc" -eq 0 ] && [ -f "$P/consumer/vendor-ok/thing-1.0.0.tgz" ] && [ -n "$out" ] \
    || cf "(control) a writable vendor directory did not vendor (rc=$rc, stdout [$out])"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — module.sh disable: A REMOVAL THAT FAILS IS NOT COUNTED, THE RECORD IS NOT DROPPED, AND THE
# REFUSAL IS TRUE ABOUT WHAT WAS CHANGED. Three shapes: a placed file in a directory the user cannot
# write to, a block host the user cannot write, and a dangling symlink at a placed path. After the
# first two a re-run recovers; the third is kept and named.
# =============================================================================
case_module_disable_does_not_count_a_removal_that_failed() {
  cf_reset
  local L="module.sh disable keeps the record and names the path when a removal fails, does not say NOTHING WAS CHANGED after removing others, recovers on a re-run, and names a dangling link instead of calling it gone"
  if ! _md_have_example; then skp_lived "$L" "$(_md_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  if _pw_is_root; then skp "$L" "running as root: chmod cannot make a path unwritable"; return; fi
  _md_sandbox
  local d="$SB_WORK/process/roles.d" f
  # (a) a placed file in a directory that cannot be written.
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || { cf "(prereq) enable exited $_md_rc: $_md_out"; finish "$L"; teardown; return; }
  chmod 555 "$d"
  _md_mod disable example
  [ "$_md_rc" -ne 0 ] || cf "(a) disable exited 0 although process/roles.d/example could not be removed: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$_md_out" | grep -F 'process/roles.d/example' >/dev/null || cf "(a) the output does not name the path that stayed: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$_md_out" | grep -F 'record dropped' >/dev/null && cf "(a) said the record was dropped with a file still on disk"
  printf '%s\n' "$_md_out" | grep -F 'Next:' >/dev/null || cf "(a) no Next: line"
  _md_mod status example
  printf '%s\n' "$_md_out" | grep -F 'not enabled' >/dev/null && cf "(a) status says the module is not enabled while its role layer still acts"
  chmod 755 "$d"
  _md_mod disable example
  [ "$_md_rc" -eq 0 ] || cf "(a) the re-run after the fix exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  [ ! -e "$d/example" ] || cf "(a) the re-run left process/roles.d/example"

  # (b) a block host that cannot be written.
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || { cf "(prereq b) enable exited $_md_rc: $_md_out"; finish "$L"; teardown; return; }
  chmod 444 "$SB_WORK/PROJECT.md"
  _md_mod disable example
  [ "$_md_rc" -ne 0 ] || cf "(b) disable exited 0 although PROJECT.md could not be rewritten"
  printf '%s\n' "$_md_out" | grep -F 'NOTHING WAS CHANGED' >/dev/null && cf "(b) said NOTHING WAS CHANGED after removing the module's other files: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$_md_out" | grep -F 'PROJECT.md' >/dev/null || cf "(b) the output does not name PROJECT.md"
  [ -z "$(ls "$SB_WORK"/PROJECT.md.kit-mb.* 2>/dev/null)" ] || cf "(b) a scratch copy was left beside PROJECT.md"
  chmod 644 "$SB_WORK/PROJECT.md"
  _md_mod disable example
  [ "$_md_rc" -eq 0 ] || cf "(b) the re-run after the fix exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  grep -F 'The example module' "$SB_WORK/PROJECT.md" >/dev/null && cf "(b) the block is still in PROJECT.md after the re-run"

  # (c) a dangling symlink at a placed path.
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || { cf "(prereq c) enable exited $_md_rc: $_md_out"; finish "$L"; teardown; return; }
  f="$SB_WORK/.claude/skills/example-skill/SKILL.md"
  rm -f "$f" && ln -s "$SB_TMP/nowhere" "$f"
  _md_mod disable example
  [ -L "$f" ] || cf "(c) the dangling link was removed without being judged"
  printf '%s\n' "$_md_out" | grep -F '.claude/skills/example-skill/SKILL.md' >/dev/null || cf "(c) the output does not name the link it left: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  rm -f "$f"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — kit-init.sh: A STRAY .gitkeep UNDER progress/ DOES NOT FAIL THE RUN AFTER IT STAMPED, AND A
# --prefix THE KIT SHIPS IS REFUSED BEFORE ANYTHING IS WRITTEN.
# =============================================================================
case_kit_init_does_not_fail_after_stamping_on_what_the_preflight_could_see() {
  cf_reset
  local L="kit-init.sh completes over a .gitkeep the project keeps under progress/, and refuses a --prefix equal to the shipped placeholder before it writes"
  if ! has_kit_init; then skp "$L" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  local shipped out rc head
  shipped="$(sed -n 's/^ISSUE_PREFIX="\${ISSUE_PREFIX:-\([^}]*\)}"/\1/p' "$SB_WORK/scripts/config.sh" | head -1)"
  [ -n "$shipped" ] || _fixture_die "case_kit_init_does_not_fail_after_stamping_on_what_the_preflight_could_see: could not read the shipped prefix from scripts/config.sh"
  publish_sandbox
  head="$(git -C "$SB_WORK" rev-parse HEAD)"
  # (a) the shipped prefix: refused in the preflight, nothing written.
  rc=0; out="$("$SB_WORK/scripts/kit-init.sh" --prefix "$shipped" --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) --prefix $shipped was accepted"
  printf '%s\n' "$out" | grep -F 'NOTHING WAS WRITTEN' >/dev/null || cf "(a) the refusal does not say nothing was written: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$head" ] || cf "(a) HEAD moved on a refused run"
  [ -z "$(git -C "$SB_WORK" status --porcelain)" ] || cf "(a) the tree changed on a refused run: $(git -C "$SB_WORK" status --porcelain | tr '\n' '|')"
  # (a2) the stamp phrase in the MIDDLE of a committed comment is not the stamp: the prefix is still refused
  printf "# note: the line '%s on <date>' is what kit-init writes\n" "$KIT_STAMP_MARK" >> "$SB_WORK/scripts/config.sh"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "a comment that quotes the stamp" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  head="$(git -C "$SB_WORK" rev-parse HEAD)"
  rc=0; out="$("$SB_WORK/scripts/kit-init.sh" --prefix "$shipped" --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a2) --prefix $shipped was accepted over a comment that quotes the stamp"
  printf '%s\n' "$out" | grep -F 'placeholder the kit ships' >/dev/null || cf "(a2) the shipped prefix was not refused as the placeholder: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$head" ] || cf "(a2) HEAD moved on a refused run"
  # (b) a stray .gitkeep of the project's own, committed.
  mkdir -p "$SB_WORK/progress/todo/parked"
  : > "$SB_WORK/progress/todo/parked/.gitkeep"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "project keeps a parked folder" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  rc=0; out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) a stray .gitkeep failed the run after the stamp (rc=$rc): $(printf '%s' "$out" | tail -4 | tr '\n' '|' | cut -c1-300)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — kit-init.sh: A RUN CUT OFF BEFORE ITS COMMIT IS TOLD A RECOVERY THAT WORKS AS PRINTED.
# Two windows, built by hand: the stamp's first write (config.sh modified, its .bak beside it, no stamp
# line) and the stamp present with no commit. The refusal prints a stash command on its own line; running
# it and re-running kit-init completes. The first window's text does not tell the user to commit.
# =============================================================================
case_kit_init_names_the_recovery_from_a_run_cut_off_before_its_commit() {
  cf_reset
  local L="kit-init.sh, over a half-run that never committed, prints a stash command that clears it and a re-run completes; it does not say to commit a half-stamped tree"
  if ! has_kit_init; then skp "$L" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  local window out rc cmd
  for window in w1 w2; do
    kit_init_sandbox
    publish_sandbox
    cp "$SB_WORK/scripts/config.sh" "$SB_WORK/scripts/config.sh.bak"
    sed -i.tmp -e 's|^ISSUE_PREFIX=.*|ISSUE_PREFIX="${ISSUE_PREFIX:-SBX}"|' "$SB_WORK/scripts/config.sh"; rm -f "$SB_WORK/scripts/config.sh.tmp"
    if [ "$window" = w2 ]; then
      printf '\n%s on 2026-01-01 — prefix SBX, trunk %s (kit-init.sh --help explains the re-run refusal).\n' "$KIT_STAMP_MARK" "$SB_TRUNK" >> "$SB_WORK/scripts/config.sh"
    fi
    rc=0; out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?
    [ "$rc" -ne 0 ] || cf "($window) kit-init ran over a half-stamped tree"
    case "$out" in *"placeholder the kit ships"*) cf "($window) refuses the user's own prefix as the shipped placeholder: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
    if [ "$window" = w1 ]; then
      case "$out" in *"commit or stash"*|*"commit them"*) cf "(w1) tells the user to commit a half-stamped tree: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
    else
      case "$out" in *"revert the initialization commit"*) cf "(w2) names an initialization commit that does not exist: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
    fi
    cmd="$(printf '%s\n' "$out" | sed -n 's/^ *\(git stash push --include-untracked.*\)$/\1/p' | head -1)"
    if [ -z "$cmd" ]; then
      cf "($window) the refusal prints no stash command on a line of its own: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
    else
      ( cd "$SB_WORK" && bash -c "$cmd" ) >/dev/null 2>&1 || cf "($window) the printed command failed: $cmd"
      rc=0; out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?
      [ "$rc" -eq 0 ] || cf "($window) after the printed command the re-run did not complete (rc=$rc): $(printf '%s' "$out" | tail -4 | tr '\n' '|' | cut -c1-300)"
    fi
    teardown
  done
  finish "$L"
}

# =============================================================================
# CASE — kit-init.sh CUT OFF AFTER ITS COMMITS: the commits are pushed and the scratch card sits in
# dev_complete. The re-run refuses as lived and its Next must name every commit the newest run made, and
# none of an earlier run already undone; the commands, run as printed, reach a state the re-run accepts and
# the board check reads clean. Two rounds: the second cut-off follows the first run's undo.
# =============================================================================
case_kit_init_killed_after_its_commits_names_every_commit_to_revert() {
  cf_reset
  local L="kit-init.sh, over a run cut off after its commits, prints a Next that names every commit it made and, run as printed, lets the re-run complete"
  if ! has_kit_init; then skp "$L" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  publish_sandbox
  local out rc cmds n sha round since="" earlier="" mine bl usr=""
  rc=0; out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)" || rc=$?
  [ "$rc" -eq 0 ] || { cf "(prereq) kit-init did not complete (rc=$rc): $(printf '%s' "$out" | tail -4 | tr '\n' '|' | cut -c1-300)"; finish "$L"; teardown; return; }
  for round in 1 2; do
    # Cut off before the scratch card was removed: that commit is undone, locally and on the remote.
    git -C "$SB_WORK" reset -q --hard HEAD~1 && git -C "$SB_WORK" push -q -f origin "HEAD:$SB_TRUNK"
    # A user's own commit that merely names kit-init's self-check lies on top of the first cut-off run; it is not kit-init's.
    if [ "$round" = 1 ]; then
      ( cd "$SB_WORK" && MSG_OK=1 git commit -q --allow-empty -m "[Dev] kit-init self-check notes for the team" && git push -q origin "HEAD:$SB_TRUNK" ) >/dev/null 2>&1
      usr="$(git -C "$SB_WORK" rev-parse --short HEAD)"
    fi
    [ -n "$(ls "$SB_WORK/progress/dev_complete" 2>/dev/null | grep -v '^\.')" ] || cf "(round $round, prereq) no scratch card in dev_complete, so the window is not the one under test"
    rc=0; out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)" || rc=$?
    [ "$rc" -ne 0 ] || cf "(round $round) the re-run did not refuse over a lived board"
    printf '%s\n' "$out" | grep 'already lived' >/dev/null || cf "(round $round) the re-run did not refuse as lived: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
    # The commits of THIS run: kit-init's own role-tagged subjects above the last undo.
    mine="$(git -C "$SB_WORK" log --format='%h %s' ${since:+"$since..HEAD"} | grep -E '^[0-9a-f]+ \[[^]]*\] (kit-init: initialize the kit — prefix [^ ]+, trunk [^ ]+|kit-init self-check: (mint scratch card [^ ]+|commit-msg hook accepts a role-tagged subject|remove the scratch card — the board is yours, empty)|[^ ]+ → [a-z_]+: kit-init self-check → [a-z_]+)$' | cut -d' ' -f1)"
    n="$(printf '%s\n' "$mine" | grep -c .)"
    cmds="$(printf '%s\n' "$out" | sed -n -E 's/^ *((MSG_OK=1 )?git .*)$/\1/p')"
    if [ -z "$cmds" ]; then cf "(round $round) the refusal prints no git command on a line of its own: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"; break; fi
    for sha in $mine; do
      printf '%s\n' "$cmds" | grep -F "$sha" >/dev/null || cf "(round $round) the printed commands omit kit-init's commit $sha ($n made)"
    done
    printf '%s\n' "$cmds" | grep -F "$usr" >/dev/null && cf "(round $round) the printed commands revert $usr, a user's commit that only names kit-init's self-check"
    for sha in $earlier; do
      printf '%s\n' "$cmds" | grep -F "$sha" >/dev/null && cf "(round $round) the printed commands revert $sha, a commit of a run already undone"
    done
    ( cd "$SB_WORK" && bash -c "$cmds" ) >/dev/null 2>&1 || cf "(round $round) a printed command failed: $cmds"
    earlier="$earlier $mine"; since="$(git -C "$SB_WORK" rev-parse --short HEAD)"
    bl="$(cd "$SB_WORK" && ./scripts/check-board.sh --full 2>&1 | grep -F 'lacks a [Role] prefix')" || bl=""
    [ -z "$bl" ] || cf "(round $round) the board check reads the undo commit as unprefixed: $bl"
    rc=0; out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)" || rc=$?
    [ "$rc" -eq 0 ] || { cf "(round $round) after the printed commands the re-run did not complete (rc=$rc): $(printf '%s' "$out" | tail -4 | tr '\n' '|' | cut -c1-300)"; break; }
  done
  finish "$L"
  teardown
}

# =============================================================================
# CASE — archive-progress.sh: --apply CHECKS WHAT IT WILL WRITE BEFORE IT WRITES, AND AGREES WITH ITSELF
# ABOUT THE INDEX HEADER. A read-only progress.md, an indented index header, and a --milestone with a
# path separator each refuse with a Next and write nothing, including outside the history directory.
# =============================================================================
case_archive_progress_refuses_before_the_first_write() {
  cf_reset
  local L="archive-progress.sh --apply refuses a read-only progress.md, an indented index header and a milestone with a path separator, each with a Next and no chunk, no rewrite and nothing outside progress/history"
  if _pw_is_root; then skp "$L" "running as root: chmod cannot make a file read-only"; return; fi
  make_sandbox
  local R="$SB_TMP/apw" out rc
  mkdir -p "$R/progress/history"
  _ap_seed_small_log "$R"
  printf '# rotation index\n\n| Chunk | Covers | Entries | Rotated | Cut |\n|---|---|---|---|---|\n' > "$R/progress/history/INDEX.md"
  cp "$R/progress.md" "$SB_TMP/progress.before"
  # (a) progress.md read-only
  chmod 444 "$R/progress.md"
  rc=0; out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone ro --keep-last 1 --apply 2>&1 )" || rc=$?
  chmod 644 "$R/progress.md"
  [ "$rc" -ne 0 ] || cf "(a) exited 0 although progress.md could not be rewritten"
  printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "(a) no Next: line: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  [ ! -e "$R/progress/history/ro.md" ] || cf "(a) the chunk was written before the failure, so the re-run says chunk-exists"
  cmp -s "$SB_TMP/progress.before" "$R/progress.md" || cf "(a) progress.md changed"
  # (b) an indented header: the precheck and the insert must agree
  printf '# rotation index\n\n  | Chunk | Covers | Entries | Rotated | Cut |\n  |---|---|---|---|---|\n' > "$R/progress/history/INDEX.md"
  rc=0; out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone ind --keep-last 1 --apply 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(b) an indented header passed the precheck: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$out" | grep -F 'one row added' >/dev/null && cf "(b) said one row was added to an index it could not insert into"
  [ ! -e "$R/progress/history/ind.md" ] || cf "(b) the chunk was written"
  cmp -s "$SB_TMP/progress.before" "$R/progress.md" || cf "(b) progress.md changed"
  # (c) a milestone with a path separator
  printf '# rotation index\n\n| Chunk | Covers | Entries | Rotated | Cut |\n|---|---|---|---|---|\n' > "$R/progress/history/INDEX.md"
  rc=0; out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone ../../escaped --keep-last 1 --apply 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(c) a milestone with a path separator was accepted"
  printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "(c) no Next: line"
  [ ! -e "$R/escaped.md" ] || cf "(c) a file was written outside progress/history"
  # (c2) the last file to be staged cannot be: the chunk and the log are not touched either
  mkdir "$R/progress/history/INDEX.md.new"
  rc=0; out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone stg --keep-last 1 --apply 2>&1 )" || rc=$?
  rm -rf "$R/progress/history/INDEX.md.new"   # cp -p put the index inside it
  [ "$rc" -ne 0 ] || cf "(c2) exited 0 although the index could not be staged"
  printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "(c2) no Next: line"
  [ ! -e "$R/progress/history/stg.md" ] || cf "(c2) the chunk was written before the index was staged, so the re-run says chunk-exists"
  cmp -s "$SB_TMP/progress.before" "$R/progress.md" || cf "(c2) progress.md was rewritten before the index was staged"
  # (c3) a kill between the log's rename and the index's: the log is rotated, the chunk is there, the index lacks it
  printf '# progress.md\n\n## Log\n\n## 2026-08-21 [Dev] two\nbody\n\n' > "$R/progress.md"
  printf -- '---\narchived_at: x\n---\n\n## 2026-08-20 [Dev] one\nbody\n\n' > "$R/progress/history/killed.md"
  touch -t 203001010000 "$R/progress/history/killed.md"
  rc=0; out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone later --keep-last 1 --apply 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(c3) a rotated log with an unindexed chunk was reported as nothing to do: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$out" | grep -F 'killed.md' >/dev/null || cf "(c3) the output does not name the unindexed chunk"
  printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "(c3) no Next: line"
  rm -f "$R/progress/history/killed.md"
  cp "$SB_TMP/progress.before" "$R/progress.md"
  # (d) the control still rotates
  rc=0; out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone ok --keep-last 1 --apply 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] && [ -s "$R/progress/history/ok.md" ] || cf "(d) the control rotation failed (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — register-commit.sh REFUSES A PATH THROUGH A SYMBOLIC LINK ON THE TRUNK, AND NO ROLLBACK FOLLOWS ONE.
# A link inside the repository and a link that leads out of the kanban worktree. After each: a Next, the kanban
# worktree clean, the user's own file where the link leads unchanged, and a later call lands.
# =============================================================================
case_register_commit_refuses_a_path_through_a_link() {
  cf_reset
  local L="register-commit.sh refuses a path whose part is a symbolic link on the trunk, with a Next, the kanban worktree clean and the file the link leads to untouched, and a later call lands"
  make_sandbox
  mkdir -p "$SB_WORK/docs" "$SB_WORK/other" "$SB_TMP/other"
  printf 'one\n' > "$SB_WORK/docs/a.md"
  ln -s docs "$SB_WORK/dl"
  ln -s ../other "$SB_WORK/lnk"
  printf 'USER\n' > "$SB_WORK/other/x"
  ln -s a.md "$SB_WORK/docs/f.md"
  publish_sandbox
  printf 'USER\nmore\n' > "$SB_TMP/other/x"   # what the caller's own lnk/x holds
  printf 'two\n' >> "$SB_WORK/docs/a.md"
  local out rc via
  for via in dl/a.md lnk/x; do
    rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "via link" "$via" 2>&1 )" || rc=$?
    [ "$rc" -ne 0 ] || cf "($via) exited 0 through a link"
    printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "($via) no Next: line: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
    if [ -d "$SB_WORK/.kanban-wt" ]; then
      _pw_kwt_clean || cf "($via) the kanban worktree is not clean: $(git -C "$SB_WORK/.kanban-wt" status --short | tr '\n' '|')"
    fi
    [ "$(cat "$SB_WORK/other/x")" = USER ] || cf "($via) the file the link leads to was changed or deleted"
    [ -f "$SB_WORK/docs/a.md" ] || cf "($via) docs/a.md was deleted"
  done
  # (delete) a tracked link is removed by naming it once it is gone from the checkout; nothing it leads to is touched
  rm -f "$SB_WORK/docs/f.md"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "delete a link" docs/f.md 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(delete) deleting a tracked link was refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  [ -z "$(git -C "$SB_ORIGIN" ls-tree "$SB_TRUNK" -- docs/f.md)" ] || cf "(delete) the link is still on the trunk"
  [ "$(git -C "$SB_ORIGIN" show "$SB_TRUNK:docs/a.md")" = one ] || cf "(delete) the file the link led to changed on the trunk"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "control" docs/a.md 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(control) a later call was stuck (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — archive-progress.sh FINDS A CUT-OFF ROTATION ON EVERY RUN, AND THE ROW IT PRINTS IS THE ROW A ROTATION WRITES.
# The state a kill leaves after the log's rename is built from a real rotation. The printed row's Covers, Entries
# and Cut equal the real row's. A grown log and another milestone do not lose the unindexed chunk. A chunk whose
# entries are still in the log (a kill after the chunk's rename) is refused with the command that deletes it.
# =============================================================================
case_archive_progress_finds_a_cut_off_rotation_and_prints_the_row_a_rotation_writes() {
  cf_reset
  local L="archive-progress.sh refuses a chunk the index lacks on every run, prints the row a real rotation writes, and names the delete for a chunk whose entries are still in the log"
  make_sandbox
  local R="$SB_TMP/apk" R2="$SB_TMP/apk2" R3="$SB_TMP/apk3" out rc real printed a b
  local hdr='# idx\n\n| Chunk | Covers | Entries | Rotated | Cut |\n|---|---|---|---|---|\n'
  local d
  for d in "$R" "$R2" "$R3"; do
    mkdir -p "$d/progress/history"
    { echo "# progress.md"; echo ""; echo "## Log"; echo ""
      for n in 1 2 3 4 5 6; do echo "## 2026-08-0$n [Dev] e$n"; echo "body"; echo ""; done
    } > "$d/progress.md"
    printf "$hdr" > "$d/progress/history/INDEX.md"
  done
  # the real rotation
  rc=0; out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R2" --milestone q3 --keep-last 2 --apply 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || _fixture_die "${FUNCNAME[0]}: the real rotation failed: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  real="$(grep -F 'q3.md' "$R2/progress/history/INDEX.md" | head -1)"
  # the state a kill after the log's rename leaves: the rotated log, the chunk, the index as it was
  cp "$R2/progress.md" "$R/progress.md"; cp "$R2/progress/history/q3.md" "$R/progress/history/q3.md"
  rc=0; out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone later --keep-last 5 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(a) the cut-off rotation was reported as nothing to do"
  printed="$(printf '%s\n' "$out" | grep -F '| [`q3.md`]' | head -1)"
  [ -n "$printed" ] || cf "(a) no index row printed: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  for a in 3 4 6; do
    b="$(printf '%s' "$real" | awk -F'|' -v f=$a '{ gsub(/^ +| +$/, "", $f); print $f }')"
    c="$(printf '%s' "$printed" | awk -F'|' -v f=$a '{ gsub(/^ +| +$/, "", $f); print $f }')"
    [ "$b" = "$c" ] || cf "(a) column $a of the printed row is [$c], a real rotation writes [$b]"
  done
  # a grown log and another milestone: the chunk is still found
  { echo "## 2026-08-07 [Dev] e7"; echo "body"; echo ""; } >> "$R/progress.md"
  rc=0; out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone q5 --keep-last 2 --apply 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(b) a rotation ran over an unindexed chunk"
  printf '%s\n' "$out" | grep -F 'q3.md' >/dev/null || cf "(b) the refusal does not name q3.md"
  [ ! -e "$R/progress/history/q5.md" ] || cf "(b) a second chunk was written over the unindexed one"
  # a kill after the chunk's rename: the entries are still in the log
  cp "$R2/progress/history/q3.md" "$R3/progress/history/q3.md"
  rc=0; out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R3" --milestone other --keep-last 2 --apply 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(c) a rotation ran over a chunk whose entries are still in the log"
  printf '%s\n' "$out" | grep -F "rm 'progress/history/q3.md'" >/dev/null || cf "(c) no delete command: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  [ ! -e "$R3/progress/history/other.md" ] || cf "(c) a duplicate chunk was written"
  finish "$L"
  teardown
}

# _tw_reap <pid> — waits at most 60 s for the op to end, then kills it; sets TW_RC to its status, or hung. A row whose op never ends
# (the ablated form: a push held for ever) fails on its own instead of hanging the run.
_tw_reap() {
  local p="$1" i rc=0
  for i in $(seq 1 60); do kill -0 "$p" 2>/dev/null || break; sleep 1; done
  if kill -0 "$p" 2>/dev/null; then kill -KILL "$p" 2>/dev/null; wait "$p" 2>/dev/null; TW_RC=hung; return 0; fi
  wait "$p" 2>/dev/null; rc=$?
  TW_RC="$rc"
}

# =============================================================================
# CASE — A TERM TO THE OP'S OWN PID WAITS FOR THE GIT COMMAND IT IS RUNNING BEFORE THE LOCK IS RELEASED.
# bash runs a trap after its foreground command, so the signal is answered once the git command has returned:
# (push) a pre-receive hook holds the push for six seconds; TERM goes to the op's pid alone. Two seconds later the
#   op is alive and holds the lock; after it ends (143) the push has landed and the lock is gone.
# (rebase) the push is rejected because the trunk moved; the retry's rebase is held by a pre-rebase hook; TERM goes
#   to the op's pid alone. The lock is held until the rebase has finished, the worktree is not left mid-rebase,
#   and the rebased commit sits on the trunk's new tip.
# =============================================================================
case_a_term_to_the_ops_pid_waits_for_its_push_and_its_rebase_before_the_lock_goes() {
  cf_reset
  local L="a board op sent TERM to its own pid keeps the lock until the push or the retry's rebase it is running has returned, leaves no rebase in progress, and then exits 143"
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  make_sandbox
  local id="$SB_PREFIX-876" id2="$SB_PREFIX-877" out rc=0 pid i hold="$SB_TMP/in-hook3" lock="$SB_WORK/.kanban-wt.lock" other="$SB_TMP/other"
  seed_issue todo "$id" termwait chore "A card whose op is terminated while its push is held"
  seed_issue todo "$id2" termrebase chore "A card whose op is terminated during its retry's rebase"
  publish_sandbox
  # (push)
  printf '#!/bin/sh\ntouch "%s"\nsleep 6\nexit 0\n' "$hold" > "$SB_ORIGIN/hooks/pre-receive"; chmod +x "$SB_ORIGIN/hooks/pre-receive"
  ( cd "$SB_WORK" && exec perl -e 'use POSIX; setsid(); exec @ARGV' env -u MSG_OK ./scripts/move-issue.sh "$id" in_progress --role Dev --note "waited for its push" ) > "$SB_TMP/term3.out" 2>&1 &
  pid=$!
  for i in $(seq 1 60); do [ -e "$hold" ] && break; sleep 1; done
  [ -e "$hold" ] || cf "(prereq, push) the push never reached the hook: $(tr '\n' '|' < "$SB_TMP/term3.out" | cut -c1-200)"
  kill -TERM "$pid" 2>/dev/null
  sleep 2
  kill -0 "$pid" 2>/dev/null || cf "(push) the op ended while its push was still held by the hook"
  [ -d "$lock" ] || cf "(push) the lock was released while the push was still in flight"
  _tw_reap "$pid"; rc="$TW_RC"
  [ "$rc" = 143 ] || cf "(push) the op ended with status $rc, not 143"
  [ ! -d "$lock" ] || cf "(push) the lock is still there after the op ended"
  git -C "$SB_ORIGIN" log --format=%s -3 "$SB_TRUNK" 2>/dev/null | grep -F 'waited for its push' >/dev/null || cf "(push) the push had not landed by the time the lock was released"
  rm -f "$SB_ORIGIN/hooks/pre-receive"
  # (rebase): the first push is held until the trunk has moved, then rejected; the retry's rebase is held too
  local gate="$SB_TMP/gate" go="$SB_TMP/go" rbhold="$SB_TMP/in-rebase"
  printf '#!/bin/sh\nif mkdir "%s" 2>/dev/null; then touch "%s"; n=0; while [ ! -e "%s" ] && [ $n -lt 60 ]; do sleep 1; n=$((n+1)); done; exit 1; fi\nexit 0\n' "$gate" "$hold.2" "$go" > "$SB_ORIGIN/hooks/pre-receive"
  chmod +x "$SB_ORIGIN/hooks/pre-receive"
  printf '#!/bin/sh\nif mkdir "%s.d" 2>/dev/null; then touch "%s"; sleep 6; fi\nexit 0\n' "$rbhold" "$rbhold" > "$SB_WORK/scripts/githooks/pre-rebase"; chmod +x "$SB_WORK/scripts/githooks/pre-rebase"
  ( cd "$SB_WORK" && exec perl -e 'use POSIX; setsid(); exec @ARGV' env -u MSG_OK ./scripts/move-issue.sh "$id2" in_progress --role Dev --note "rebased then ended" ) > "$SB_TMP/term4.out" 2>&1 &
  pid=$!
  for i in $(seq 1 60); do [ -e "$hold.2" ] && break; sleep 1; done
  [ -e "$hold.2" ] || cf "(prereq, rebase) the push never reached the hook: $(tr '\n' '|' < "$SB_TMP/term4.out" | cut -c1-200)"
  git clone -q "$SB_ORIGIN" "$other" >/dev/null 2>&1
  printf 'moved\n' > "$other/OTHER-LANE.txt"
  git -C "$other" add OTHER-LANE.txt >/dev/null 2>&1
  git -C "$other" -c user.email=o@kit.invalid -c user.name=other -c commit.gpgsign=false commit -q -m "[PM] another lane moves the trunk" >/dev/null 2>&1
  git -C "$other" push -q origin "HEAD:$SB_TRUNK" >/dev/null 2>&1 || cf "(prereq, rebase) the second clone could not move the trunk"
  touch "$go"
  for i in $(seq 1 60); do [ -e "$rbhold" ] && break; sleep 1; done
  [ -e "$rbhold" ] || cf "(prereq, rebase) the retry never reached its rebase: $(tr '\n' '|' < "$SB_TMP/term4.out" | cut -c1-300)"
  kill -TERM "$pid" 2>/dev/null
  sleep 2
  kill -0 "$pid" 2>/dev/null || cf "(rebase) the op ended while its rebase was still held"
  [ -d "$lock" ] || cf "(rebase) the lock was released while the rebase was still running"
  _tw_reap "$pid"; rc="$TW_RC"
  [ "$rc" = 143 ] || cf "(rebase) the op ended with status $rc, not 143"
  [ ! -d "$lock" ] || cf "(rebase) the lock is still there after the op ended"
  [ ! -d "$(git -C "$SB_WORK/.kanban-wt" rev-parse --git-path rebase-merge 2>/dev/null)" ] || cf "(rebase) the kanban worktree is left mid-rebase"
  [ ! -d "$(git -C "$SB_WORK/.kanban-wt" rev-parse --git-path rebase-apply 2>/dev/null)" ] || cf "(rebase) the kanban worktree is left mid-rebase (apply)"
  git -C "$SB_WORK/.kanban-wt" log --format=%s -3 2>/dev/null | grep -F 'another lane moves the trunk' >/dev/null || cf "(rebase) the op's commit was not rebased onto the trunk's new tip: $(git -C "$SB_WORK/.kanban-wt" log --format=%s -3 2>/dev/null | tr '\n' '|')"
  rm -f "$SB_ORIGIN/hooks/pre-receive" "$SB_WORK/scripts/githooks/pre-rebase"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A KANBAN LOCK WHOSE HOLDER IS A ZOMBIE IS REAPED.
# A holder that has exited and that its parent has not reaped (a container started without an init) still
# answers kill -0 and ps -p; ps -o stat= names it with a Z. The next op on the same host reaps the lock and
# moves the card; read as alive, the holder would make it wait KWT_LOCK_WAIT and refuse kanban-lock-held.
# The control runs the library's own probe, taken from the sandbox's copy, on a live holder (held) and a
# reaped one (abandoned).
# =============================================================================
case_a_kanban_lock_held_by_a_zombie_is_reaped() {
  cf_reset
  local L="a kanban lock whose holder on this host is a zombie is reaped by the next op, which moves the card; the same probe reads a live holder as holding the lock and a reaped one as gone"
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  [ -n "$(ps_stat "$$")" ] || { skp "$L" "ps -o stat= names no state on this machine, so a zombie cannot be told"; return; }
  make_sandbox
  local id="$SB_PREFIX-892" out rc=0 lock="$SB_WORK/.kanban-wt.lock" lib="$SB_WORK/scripts/lib/kanban-worktree.sh" fn pid ans st
  seed_issue todo "$id" zombie chore "A card moved past a zombie's lock"
  publish_sandbox
  if ! zombie_start; then
    st="$(ps_stat "${ZOMBIE_PID:-x}")"; zombie_stop; teardown
    _fixture_die "case_a_kanban_lock_held_by_a_zombie_is_reaped: no zombie within five seconds (pid '$ZOMBIE_PID', ps says '$st')."
  fi
  mkdir "$lock" && printf 'pid=%s\nepoch=%s\nhost=%s\ntoken=%s\n' "$ZOMBIE_PID" "$(date +%s)" "$(hostname 2>/dev/null || echo '?')" "$ZOMBIE_PID.zombie" > "$lock/info" \
    || { zombie_stop; teardown; _fixture_die "case_a_kanban_lock_held_by_a_zombie_is_reaped: could not plant the lock at $lock."; }
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/move-issue.sh "$id" in_progress --role Dev --note "moved past a zombie's lock" 2>&1 )" || rc=$?
  st="$(ps_stat "$ZOMBIE_PID")"
  case "$st" in Z*) ;; *) cf "(instrument) the holder was no longer a zombie when the op ended (ps says '$st'), so the rows below prove nothing" ;; esac
  zombie_stop
  [ "$rc" -eq 0 ] || cf "the op did not move the card past a zombie's lock (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -F 'looked abandoned' >/dev/null || cf "the op did not say it reaped the lock: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/in_progress/$id-zombie.md" || cf "the card did not reach in_progress/ on the trunk"
  [ ! -e "$lock" ] || cf "the lock is still there after the op ended"
  # The control: the same probe on a live holder and on a reaped one.
  fn="$(sed -n '/^kwt__lock_abandoned() {$/,/^}$/p' "$lib")"
  [[ "$fn" == *'kill -0'* ]] \
    || { teardown; _fixture_die "case_a_kanban_lock_held_by_a_zombie_is_reaped: no kwt__lock_abandoned() with a kill -0 probe in $lib."; }
  mkdir -p "$lock"
  sleep 60 & pid=$!
  printf 'pid=%s\nepoch=%s\nhost=%s\ntoken=live\n' "$pid" "$(date +%s)" "$(hostname 2>/dev/null || echo '?')" > "$lock/info"
  ans="$( eval "$fn"; KWT_LOCK="$lock"; KWT_LOCK_STALE=120; kwt__lock_abandoned 2>&1 )"
  [ -z "$ans" ] || cf "(control) the probe read a live holder as abandoned: '$ans'"
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  ans="$( eval "$fn"; KWT_LOCK="$lock"; KWT_LOCK_STALE=120; kwt__lock_abandoned 2>&1 )"
  [ "$ans" = yes ] || cf "(control) the probe did not read a reaped holder as abandoned: '$ans'"
  rm -rf "$lock"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — kit-init.sh CUT OFF AFTER A PUSHED SELF-CHECK MOVE, BEFORE THE CHECKOUT CAUGHT UP: the trunk holds commits the
# checkout does not. The re-run refuses as lived and its Next must name every commit the run made on the trunk, newest
# included, and bring the checkout up to the trunk first; run as printed, the commands let the re-run complete.
# =============================================================================
case_kit_init_cut_off_before_the_checkout_caught_up_names_the_trunks_commits() {
  cf_reset
  local L="kit-init.sh, over a run whose newest commits are on the trunk but not in the checkout, prints a Next that brings the checkout to the trunk and names every commit the run made there, and, run as printed, lets the re-run complete"
  if ! has_kit_init; then skp "$L" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  publish_sandbox
  local out rc cmds sha mine
  rc=0; out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)" || rc=$?
  [ "$rc" -eq 0 ] || { cf "(prereq) kit-init did not complete (rc=$rc): $(printf '%s' "$out" | tail -4 | tr '\n' '|' | cut -c1-300)"; finish "$L"; teardown; return; }
  # The trunk keeps the whole run; the checkout is two commits behind it, as when the run was cut off before its fast-forward.
  mine="$(git -C "$SB_WORK" log --format='%h %s' "origin/$SB_TRUNK" | grep -E '^[0-9a-f]+ \[[^]]*\] (kit-init: initialize the kit — prefix [^ ]+, trunk [^ ]+|kit-init self-check: (mint scratch card [^ ]+|commit-msg hook accepts a role-tagged subject|remove the scratch card — the board is yours, empty)|[^ ]+ → [a-z_]+: kit-init self-check → [a-z_]+)$' | cut -d' ' -f1)"
  git -C "$SB_WORK" reset -q --hard HEAD~2 || cf "(prereq) could not set the checkout back"
  [ "$(git -C "$SB_WORK" rev-parse HEAD)" != "$(git -C "$SB_WORK" rev-parse "origin/$SB_TRUNK")" ] || cf "(prereq) the checkout is not behind the trunk"
  [ -n "$(ls "$SB_WORK/progress/dev_complete" 2>/dev/null | grep -v '^\.')" ] || cf "(prereq) no scratch card in dev_complete, so the window is not the one under test"
  rc=0; out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)" || rc=$?
  [ "$rc" -ne 0 ] || cf "the re-run did not refuse over a lived board"
  printf '%s\n' "$out" | grep 'already lived' >/dev/null || cf "the re-run did not refuse as lived: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  cmds="$(printf '%s\n' "$out" | sed -n -E 's/^ *((MSG_OK=1 )?git .*)$/\1/p')"
  if [ -z "$cmds" ]; then cf "the refusal prints no git command on a line of its own: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"; finish "$L"; teardown; return; fi
  for sha in $mine; do
    printf '%s\n' "$cmds" | grep -F "$sha" >/dev/null || cf "the printed commands omit kit-init's commit $sha, which is on the trunk"
  done
  ( cd "$SB_WORK" && bash -c "$cmds" ) >/dev/null 2>&1 || cf "a printed command failed: $cmds"
  rc=0; out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)" || rc=$?
  [ "$rc" -eq 0 ] || cf "after the printed commands the re-run did not complete (rc=$rc): $(printf '%s' "$out" | tail -4 | tr '\n' '|' | cut -c1-300)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE ALREADY-LIVED NEXT OFF THE TRUNK, AND OVER A DIVERGED CHECKOUT.
# The checkout is two commits behind a trunk that holds a whole kit-init run.
# (branch) on another branch, and on a detached HEAD, the Next prints no `git merge`: pasting it would move that branch.
# (diverged) after one unrelated commit on the stale trunk checkout, the Next prints no `git merge` either, every commit it
#   reverts is in the checkout's history, and it says to `git pull --rebase` the remote's trunk and run kit-init again.
# =============================================================================
case_kit_init_lived_refusal_off_the_trunk_and_on_a_diverged_checkout_prints_no_merge() {
  cf_reset
  local L="kit-init.sh, over a lived checkout behind the trunk that is on another branch, on a detached HEAD or diverged from the trunk, prints no git merge line; a diverged one names only commits in its history and says to pull --rebase first"
  if ! has_kit_init; then skp "$L" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  publish_sandbox
  local out rc sha cmds
  rc=0; out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)" || rc=$?
  [ "$rc" -eq 0 ] || { cf "(prereq) kit-init did not complete (rc=$rc): $(printf '%s' "$out" | tail -4 | tr '\n' '|' | cut -c1-300)"; finish "$L"; teardown; return; }
  git -C "$SB_WORK" reset -q --hard HEAD~2 || cf "(prereq) could not set the checkout back"
  # (branch) another branch, then a detached HEAD
  git -C "$SB_WORK" checkout -q -b side-branch || cf "(prereq) could not leave the trunk"
  rc=0; out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)" || rc=$?
  printf '%s\n' "$out" | grep 'already lived' >/dev/null || cf "(branch) the re-run did not refuse as lived: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -F 'git merge' >/dev/null && cf "(branch) the Next prints a git merge line on a checkout that is not on the trunk"
  git -C "$SB_WORK" checkout -q --detach || cf "(prereq) could not detach"
  rc=0; out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)" || rc=$?
  printf '%s\n' "$out" | grep 'already lived' >/dev/null || cf "(detached) the re-run did not refuse as lived: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -F 'git merge' >/dev/null && cf "(detached) the Next prints a git merge line on a detached HEAD"
  # (diverged) back on the trunk, one commit of its own that the trunk does not have
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" || cf "(prereq) could not return to the trunk"
  printf 'x\n' > "$SB_WORK/unrelated.txt"
  git -C "$SB_WORK" add unrelated.txt
  ( cd "$SB_WORK" && MSG_OK=1 git commit -q -m "[Dev] an unrelated change on the stale checkout" ) >/dev/null 2>&1 || cf "(prereq) could not commit the unrelated file"
  rc=0; out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)" || rc=$?
  printf '%s\n' "$out" | grep 'already lived' >/dev/null || cf "(diverged) the re-run did not refuse as lived: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -F 'git merge' >/dev/null && cf "(diverged) the Next prints a git merge line over a diverged checkout"
  cmds="$(printf '%s\n' "$out" | sed -n -E 's/^ *((MSG_OK=1 )?git .*)$/\1/p')"
  for sha in $(printf '%s\n' "$cmds" | sed -n -E 's/.*git revert --no-commit (.*)$/\1/p'); do
    git -C "$SB_WORK" merge-base --is-ancestor "$sha" HEAD || cf "(diverged) the Next reverts $sha, which is not in the checkout's history"
  done
  printf '%s\n' "$cmds" | grep -F "git pull --rebase origin $SB_TRUNK" >/dev/null || cf "(diverged) the Next does not say to git pull --rebase origin $SB_TRUNK: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-500)"
  finish "$L"
  teardown
}
