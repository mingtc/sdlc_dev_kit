# KIT-CLASS: MIXED — self-test harness, script-usability cases. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/script-nits.sh — sourced by scripts/test/run.sh, never run on its own.
# Small defects in three scripts' behaviour: how the acting role is passed and what a usage error prints
# (finish-pr.sh, subtask.sh), what a killed pre-merge gate leaves behind (finish-pr.sh), and what a rewrite
# does to a file's mode (release.sh).
# =============================================================================

# =============================================================================
# CASE — THE ACTING ROLE IS AN OPTION OF finish-pr.sh AND OF `subtask.sh new`, THE ENVIRONMENT KNOB STILL WORKS.
# `finish-pr.sh` took only FINISH_PR_ROLE and `subtask.sh new` only SUBTASK_ROLE, while `subtask.sh move` and
# `move-issue.sh` take `--role`: three spellings of one thing, and the wrong one answered with the whole help.
#   (a) `finish-pr.sh <id> --role <not declared>` is refused as a role the project does not declare, not as an
#       unknown option;  (b) the same for `subtask.sh new … --role`;
#   (c) CONTROL: FINISH_PR_ROLE and SUBTASK_ROLE are still read, and refuse the same way;
#   (d) the option wins over the knob (a declared --role beats an undeclared knob, so the refusal is by --role).
# =============================================================================
case_the_acting_role_is_an_option_of_finish_pr_and_of_subtask_new_and_the_knobs_still_work() {
  cf_reset
  local L="finish-pr.sh and subtask.sh new take --role (a role the project does not declare is refused as that, not as an unknown option), and FINISH_PR_ROLE and SUBTASK_ROLE still work"
  make_sandbox
  local fp="$SB_WORK/scripts/finish-pr.sh" st="$SB_WORK/scripts/subtask.sh" out rc want="the role tag 'Bogus' is not in this project's declared role set"
  if [ ! -f "$fp" ] || [ ! -f "$st" ]; then skp "$L" "finish-pr.sh or subtask.sh absent"; teardown; return; fi
  rc=0; out="$( cd "$SB_WORK" && env -u FINISH_PR_ROLE "$fp" "$SB_PREFIX-1" --role Bogus 2>&1 )" || rc=$?
  { [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -F "$want" >/dev/null && ! printf '%s\n' "$out" | grep -F 'unknown option' >/dev/null; } \
    || cf "(a) finish-pr.sh --role Bogus was not refused as an undeclared role (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  rc=0; out="$( cd "$SB_WORK" && env -u SUBTASK_ROLE "$st" new "$SB_PREFIX-1" s1 slug --title t --role Bogus 2>&1 )" || rc=$?
  { [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -F "$want" >/dev/null && ! printf '%s\n' "$out" | grep -F 'unknown option' >/dev/null; } \
    || cf "(b) subtask.sh new --role Bogus was not refused as an undeclared role (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  rc=0; out="$( cd "$SB_WORK" && FINISH_PR_ROLE=Bogus "$fp" "$SB_PREFIX-1" 2>&1 )" || rc=$?
  { [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -F "$want" >/dev/null; } \
    || cf "(c) control: FINISH_PR_ROLE=Bogus was not refused as an undeclared role (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  rc=0; out="$( cd "$SB_WORK" && SUBTASK_ROLE=Bogus "$st" new "$SB_PREFIX-1" s1 slug --title t 2>&1 )" || rc=$?
  { [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -F "$want" >/dev/null; } \
    || cf "(c) control: SUBTASK_ROLE=Bogus was not refused as an undeclared role (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  rc=0; out="$( cd "$SB_WORK" && FINISH_PR_ROLE=Bogus "$fp" "$SB_PREFIX-1" --role Worse 2>&1 )" || rc=$?
  printf '%s\n' "$out" | grep -F "the role tag 'Worse' is not in this project's declared role set" >/dev/null \
    || cf "(d) --role did not win over FINISH_PR_ROLE (the refusal should name 'Worse'): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A USAGE ERROR PRINTS THE ERROR, A ONE-LINE SYNOPSIS AND --help, NOT THE WHOLE HELP.
# A wrong option or a bare call printed the script's entire header (91 lines for finish-pr.sh, 47 for subtask.sh)
# with no error line on a bare call; move-issue.sh already answers in a few lines. `--help` itself still prints
# the header in full.
# =============================================================================
case_a_usage_error_prints_a_one_line_synopsis_and_not_the_whole_help() {
  cf_reset
  local L="a usage error from finish-pr.sh and subtask.sh is short and points at --help; --help still prints the whole header"
  make_sandbox
  local fp="$SB_WORK/scripts/finish-pr.sh" st="$SB_WORK/scripts/subtask.sh" row cmd out rc n
  if [ ! -f "$fp" ] || [ ! -f "$st" ]; then skp "$L" "finish-pr.sh or subtask.sh absent"; teardown; return; fi
  # <row>@<command>@<exit status wanted>
  while IFS='@' read -r row cmd want; do
    [ -n "$row" ] || continue
    rc=0; out="$( cd "$SB_WORK" && eval "$cmd" 2>&1 </dev/null )" || rc=$?
    n="$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
    [ "$rc" -eq "$want" ] || cf "($row) exit $rc, wanted $want: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"
    [ "$n" -le 8 ] || cf "($row) the usage error printed $n lines, the whole help: $(printf '%s' "$out" | head -3 | tr '\n' '|' | cut -c1-160)"
    printf '%s\n' "$out" | grep -F -- '--help' >/dev/null || cf "($row) the usage error does not point at --help: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"
  done <<ROWS
fp-bare@"$fp"@1
fp-unknown-option@"$fp" "$SB_PREFIX-1" --bogus@2
fp-unknown-arg@"$fp" "$SB_PREFIX-1" stray@1
st-bare@"$st"@1
st-new-unknown-option@"$st" new "$SB_PREFIX-1" s1 slug --bogus@2
st-move-unknown-option@"$st" move "$SB_PREFIX-1-s1" in_progress --bogus@2
ROWS
  for cmd in "$fp" "$st"; do
    n="$( cd "$SB_WORK" && "$cmd" --help 2>&1 | wc -l | tr -d ' ' )"
    [ "$n" -gt 30 ] || cf "(control) $(basename "$cmd") --help printed only $n lines: the whole header is what --help is for"
  done
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A KILLED PRE-MERGE GATE LEAVES NO WORKTREE BEHIND.
# finish-pr.sh runs the pre-merge gate in a fresh detached worktree and, when the branch changes
# scripts/verify.sh, stages the trunk's copy of it there as `scripts/.verify-trunk.XXXXXX`. A TERM mid-gate
# ran the lock's exit hook and nothing else: the worktree (a full checkout in TMPDIR, with that staged runner in
# it) and its registration in the repository were left, run after run.
#   (a) the whole process group is sent TERM while the gate sleeps: finish-pr.sh exits non-zero and TMPDIR holds
#       no finish-pr-premerge directory, `git worktree list` names none, and the lock is released;
#   (b) CONTROL: the same landing, not killed, passes and leaves the same nothing.
# =============================================================================
case_a_killed_pre_merge_gate_leaves_no_worktree_behind() {
  cf_reset
  local L="a TERM to finish-pr.sh while its pre-merge gate runs leaves no pre-merge worktree in TMPDIR or in git's list, and releases the lock; an unkilled landing leaves none either"
  make_sandbox
  local fp="$SB_WORK/scripts/finish-pr.sh" br="feature/$SB_PREFIX-795-hang" tmpd="$SB_TMP/premerge-tmp" pid i mark="$SB_TMP/gate-started" rc left
  if [ ! -f "$fp" ]; then skp "$L" "finish-pr.sh absent"; teardown; return; fi
  mkdir -p "$tmpd"
  printf '#!/usr/bin/env bash\n: > "%s"\nexec sleep 120\n' "$mark" > "$SB_WORK/hang-gate"; chmod +x "$SB_WORK/hang-gate"
  _declare_gate 'hang|core|./hang-gate'
  seed_issue dev_complete "$SB_PREFIX-795" hang chore "A gate that hangs" "$br"
  publish_sandbox
  git -C "$SB_WORK" branch "$br" "$SB_TRUNK" >/dev/null 2>&1 && git -C "$SB_WORK" checkout -q "$br" >/dev/null 2>&1 \
    || _fixture_die "case_a_killed_pre_merge_gate_leaves_no_worktree_behind: could not branch."
  printf '\n# the branch changes its gate runner, so the trunk copy is staged beside it\n' >> "$SB_WORK/scripts/verify.sh"
  git -C "$SB_WORK" add -A >/dev/null 2>&1 && sbcommit -q -m "[Dev] $SB_PREFIX-795: touch the gate runner" >/dev/null 2>&1 \
    && git -C "$SB_WORK" push -q -u origin "$br" >/dev/null 2>&1 \
    || _fixture_die "case_a_killed_pre_merge_gate_leaves_no_worktree_behind: could not commit and push."
  ( cd "$SB_WORK" && exec env TMPDIR="$tmpd" setsid "$fp" "$SB_PREFIX-795" > "$SB_TMP/fp.out" 2>&1 ) &
  pid=$!
  for i in $(seq 1 600); do [ -e "$mark" ] && break; sleep 0.2; done
  if [ ! -e "$mark" ]; then kill -KILL "-$pid" 2>/dev/null; cf "(a) the gate never started within 120 s: $(tail -3 "$SB_TMP/fp.out" | tr '\n' '|' | cut -c1-200)"; finish "$L"; teardown; return; fi
  kill -TERM "-$pid" 2>/dev/null
  for i in $(seq 1 150); do kill -0 "$pid" 2>/dev/null || break; sleep 0.2; done
  if kill -0 "$pid" 2>/dev/null; then kill -KILL "-$pid" 2>/dev/null; cf "(a) finish-pr.sh was still running 30 s after TERM"; fi
  wait "$pid" 2>/dev/null; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) a killed landing exited 0"
  left="$(ls -d "$tmpd"/finish-pr-premerge.* 2>/dev/null | tr '\n' ' ')"
  [ -z "$left" ] || cf "(a) the pre-merge worktree directory was left in TMPDIR: $left"
  git -C "$SB_WORK" worktree list 2>/dev/null | grep 'finish-pr-premerge' >/dev/null \
    && cf "(a) the pre-merge worktree is still registered: $(git -C "$SB_WORK" worktree list | grep finish-pr-premerge | head -1)"
  [ ! -d "$SB_WORK/.kanban-wt.lock" ] || cf "(a) the board lock was not released"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — release.sh REWRITES A VERSION FILE WITHOUT CHANGING ITS MODE.
# bump_one wrote the new bytes to mktemp's 0600 file and `mv`d it over the target, so an executable version file
# (a script that carries its own version line) lost the exec bit git records, and any file became 0600.
#   (a) an executable file keeps its mode through bump_one and holds the new version;
#   (b) a 0644 file stays 0644.
# bump_one and _bump_expr are extracted from the real script at run time, never copied.
# =============================================================================
case_release_bump_keeps_the_mode_of_the_file_it_rewrites() {
  cf_reset
  local L="release.sh's bump_one keeps an executable file executable and a 0644 file 0644 while it rewrites the version"
  make_sandbox
  local rel="$REAL_SCRIPTS/release.sh" fn="$SB_TMP/bump-fns.sh" root="$SB_TMP/bump-root" m0 m1 rc out
  if [ ! -f "$rel" ]; then skp "$L" "release.sh absent"; teardown; return; fi
  { sed -n '/^_bump_expr() {/,/^}/p' "$rel"; sed -n '/^bump_one() {/,/^}/p' "$rel"; } > "$fn"
  [ "$(grep -c '^bump_one() {' "$fn")" -eq 1 ] && [ "$(grep -c '^_bump_expr() {' "$fn")" -eq 1 ] \
    || _fixture_die "case_release_bump_keeps_the_mode_of_the_file_it_rewrites: could not extract bump_one and _bump_expr from release.sh"
  mkdir -p "$root"
  printf '#!/bin/sh\nVERSION="1.0.0"\n' > "$root/tool.sh"; chmod 755 "$root/tool.sh"
  printf 'VERSION="1.0.0"\n' > "$root/plain.txt"; chmod 644 "$root/plain.txt"
  _mode() { perl -e 'printf "%04o", (stat shift)[2] & 07777' "$1"; }
  for f in tool.sh plain.txt; do
    m0="$(_mode "$root/$f")"
    rc=0; out="$( REPO_ROOT="$root" NUM=2.0.0 TMPDIR="$SB_TMP" bash -c '. "$1"; bump_one "$2" "VERSION=" "\""' _ "$fn" "$f" 2>&1 )" || rc=$?
    m1="$(_mode "$root/$f")"
    [ "$rc" -eq 0 ] || cf "(a/b) bump_one $f exited $rc: $out"
    grep -F 'VERSION="2.0.0"' "$root/$f" >/dev/null || cf "bump_one $f did not write the new version"
    [ "$m0" = "$m1" ] || cf "bump_one changed the mode of $f from $m0 to $m1"
  done
  finish "$L"
  teardown
}
