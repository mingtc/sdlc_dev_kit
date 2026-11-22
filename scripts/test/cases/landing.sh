# KIT-CLASS: MIXED — self-test harness, landing cases. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/landing.sh — sourced by scripts/test/run.sh, never run on its own.
# Landing: finish-pr.sh end to end, and the verify.sh gate runner with its guard floor.
# =============================================================================

# =============================================================================
# CASE — finish-pr.sh happy path (squash-merge, delete branch, advance)
#
# It asserts the STATE (both refs gone) AND THE CLAIM (what the board note says happened):
# a note composed before the deletes can report a deletion that did not happen. A branch
# held by a second worktree and a delete that cannot succeed are the sibling cases below.
# =============================================================================
case_finish_pr_happy() {
  cf_reset
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-777" sandbox chore "Happy path" "feature/$SB_PREFIX-777-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-777" work CHANGE.txt

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-777" 2>&1 )"; rc=$?

  [ "$rc" -eq 0 ] || cf "finish-pr exited $rc (expected 0): $out"
  git -C "$SB_WORK" rev-parse --verify --quiet "refs/heads/feature/$SB_PREFIX-777-work" >/dev/null 2>&1 \
    && cf "local branch not deleted"
  [ -z "$(git -C "$SB_WORK" ls-remote --heads origin "feature/$SB_PREFIX-777-work" 2>/dev/null)" ] \
    || cf "remote branch not deleted"
  origin_has_path "progress/qa_complete/$SB_PREFIX-777-sandbox.md" \
    || cf "issue not advanced to qa_complete/ on the trunk"
  origin_has_path "CHANGE.txt" || cf "squash-merged change not on the trunk"

  # THE CLAIM. These strings are produced only by the arms that MEASURED a confirmed deletion.
  origin_file_contains "progress/qa_complete/$SB_PREFIX-777-sandbox.md" "local branch deleted" \
    || cf "board note does not report the local delete it performed"
  origin_file_contains "progress/qa_complete/$SB_PREFIX-777-sandbox.md" "branch deleted (confirmed gone)" \
    || cf "board note does not report the CONFIRMED remote delete it performed"
  printf '%s' "$out" | grep "confirmed gone by ls-remote" >/dev/null \
    || cf "run output does not show the remote delete being confirmed by re-measurement"

  finish "finish-pr.sh happy path: squash-merge + delete branch + advance, and the board note reports BOTH deletes truthfully"
  teardown
}

# =============================================================================
# CASE — A CRASH UNDER THE LOCK IS NOT A SUCCESS.
#
# bash 3.2 (macOS /bin/bash), under `set -e`, gives an EXIT trap status 0 after an
# unbound-variable abort and exits with the trap's own status, so a landing that crashed after
# taking the lock exited 0 and a caller's `&&` read it as landed. The crash is PLANTED in the
# sandbox's finish-pr.sh (before the trunk copy is published, so the lander-is-the-trunk's-copy
# check passes) right after kwt_sync, the first statement past the lock. The script runs under
# /bin/bash where it exists — bash 3.2 on macOS, the shell the defect lives in; on a Linux
# adopter /bin/bash is a newer bash and the case proves the abort keeps its status there too.
# Asserted: nonzero exit, no lock left behind, nothing landed on the trunk.
# =============================================================================
case_finish_pr_crash_under_the_lock_is_not_success() {
  cf_reset
  make_sandbox
  local fpr="$SB_WORK/scripts/finish-pr.sh"
  grep -nx 'kwt_sync' "$fpr" >/dev/null 2>&1 \
    || _fixture_die "case_finish_pr_crash_under_the_lock_is_not_success: finish-pr.sh has no bare 'kwt_sync' line to plant after."
  perl -i -pe 'print ": \"\$KIT_PLANTED_UNSET_VARIABLE\"\n" if $_ eq "kwt_sync\n"' "$fpr"
  grep -F 'KIT_PLANTED_UNSET_VARIABLE' "$fpr" >/dev/null 2>&1 \
    || _fixture_die "case_finish_pr_crash_under_the_lock_is_not_success: the plant did not land."
  seed_issue dev_complete "$SB_PREFIX-778" sandbox chore "Crash under the lock" "feature/$SB_PREFIX-778-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-778" work CHANGE.txt

  local sh=bash
  [ -x /bin/bash ] && sh=/bin/bash
  local out rc=0
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$sh" "$fpr" "$SB_PREFIX-778" 2>&1 )" || rc=$?

  printf '%s' "$out" | grep -F 'KIT_PLANTED_UNSET_VARIABLE: unbound variable' >/dev/null \
    || _control_did_not_run "make finish-pr.sh abort on the planted unbound variable (output: $out)"
  [ "$rc" -ne 0 ] || cf "finish-pr.sh exited 0 after aborting on an unbound variable under the lock — a crash read as a landing"
  [ ! -e "$SB_WORK/.kanban-wt.lock" ] || cf "the lock was left behind after the crash"
  origin_has_path "CHANGE.txt" && cf "the change landed on the trunk although the script crashed"
  origin_has_path "progress/qa_complete/$SB_PREFIX-778-sandbox.md" && cf "the issue advanced to qa_complete/ although the script crashed"

  finish "finish-pr.sh: an unbound-variable abort after the lock is taken exits nonzero, releases the lock and lands nothing"
  teardown
}

# =============================================================================
# CASE — THE EXIT-TRAP HELPER KEEPS THE STATUS THE SCRIPT IS EXITING WITH.
#
# lib/exit-trap.sh's kit_on_exit, run under /bin/bash (see the case above) in a stub that
# sources the REAL library: each way a script can end, with a cleanup command that itself
# fails. The cleanup must run every time; the status must be the script's own; a 0 with no
# `exit 0` (a script that fell off its end after crashing, indistinguishable on bash 3.2) is 1.
# =============================================================================
case_exit_trap_keeps_the_status_the_script_exits_with() {
  cf_reset
  local lib="$REAL_SCRIPTS/lib/exit-trap.sh"
  if [ ! -f "$lib" ]; then
    cf "scripts/lib/exit-trap.sh is absent — nothing keeps an aborting script's status"
    finish "kit_on_exit: an unbound-variable abort, a set -e failure and an explicit exit keep their status, a clean exit 0 stays 0, and the cleanup runs every time"
    return
  fi
  local sh=bash
  [ -x /bin/bash ] && sh=/bin/bash
  local d; d="$(mktemp -d)"
  local row body want got
  # <body>|<expected status>
  for row in \
    'echo "$KIT_UNSET_PROBE"|1' \
    'f() { echo "$KIT_UNSET_PROBE"; }; f|1' \
    'false|1' \
    'exit 3|3' \
    'exit 0|0' \
    'true|1'; do
    body="${row%|*}"; want="${row##*|}"
    rm -f "$d/ran"
    printf 'set -euo pipefail\n. "%s"\nkit_on_exit '"'"'touch "%s/ran"; false'"'"'\n%s\necho reached-the-end\n' "$lib" "$d" "$body" > "$d/stub.sh"
    got=0; "$sh" "$d/stub.sh" >/dev/null 2>&1 || got=$?
    [ "$got" -eq "$want" ] || cf "[$body] exited $got, expected $want"
    [ -e "$d/ran" ] || cf "[$body] the cleanup command did not run"
  done
  # A script that ends with `exit 0` and ran clean exits 0 with the cleanup run.
  rm -f "$d/ran"
  printf 'set -euo pipefail\n. "%s"\nkit_on_exit '"'"'touch "%s/ran"'"'"'\n: ok\nexit 0\n' "$lib" "$d" > "$d/stub.sh"
  got=0; "$sh" "$d/stub.sh" >/dev/null 2>&1 || got=$?
  [ "$got" -eq 0 ] && [ -e "$d/ran" ] || cf "a clean run ending in exit 0 exited $got (cleanup ran: $([ -e "$d/ran" ] && echo yes || echo no))"
  rm -rf "$d"

  finish "kit_on_exit: an unbound-variable abort, a set -e failure and an explicit exit keep their status, a clean exit 0 stays 0, and the cleanup runs every time"
}

# =============================================================================
# CASE — THE POST-MERGE PASS LINE NAMES THE REF IT READ, AND THE MACHINE LINE
#        DOES NOT.
#
# The PASS line must name its operand, as the FAIL line does: the clearing branch is the
# direction that errs toward false confidence. `POST_MERGE_GATE: PASS` is a MACHINE
# CONTRACT, so the second assertion is the canary: a ref appended there breaks every
# consumer. The first assertion reads the PASS line alone, because the "Done. … landed on
# '<trunk>'" line already carries the ref.
# =============================================================================
case_finish_pr_post_merge_names_its_ref() {
  cf_reset
  make_sandbox
  # The 6th argument is the card's `branch:` frontmatter, which finish-pr.sh reads to find
  # what to merge; without it the run dies on "local branch 'n/a' not found".
  seed_issue dev_complete "$SB_PREFIX-140" postmerge chore "Post-merge ref naming" "feature/$SB_PREFIX-140-postmerge"
  publish_sandbox
  seed_branch "$SB_PREFIX-140" postmerge "postmerge.txt"

  local out rc pass_line
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" ./scripts/finish-pr.sh "$SB_PREFIX-140" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "finish-pr exited $rc on the happy path: $out"

  # (1) The HUMAN line names the ref — read that line alone, not the whole run.
  pass_line="$(printf '%s\n' "$out" | grep 'post-merge verify --quick: PASS' | head -1)"
  [ -n "$pass_line" ] \
    || cf "no 'post-merge verify --quick: PASS' line in the run output — the gate did not reach its clearing branch: $out"
  printf '%s\n' "$pass_line" | grep "$SB_TRUNK" >/dev/null \
    || cf "the post-merge PASS line does not name the ref it read (the FAIL line does; the clearing branch is the direction that errs toward false confidence): $pass_line"

  # (2) THE CANARY: the machine line is still exactly its token, with no ref appended.
  printf '%s\n' "$out" | grep -x 'POST_MERGE_GATE: PASS' >/dev/null \
    || cf "the machine line is no longer exactly 'POST_MERGE_GATE: PASS' — an automation greps that token, so a ref appended HERE breaks every consumer: $out"

  finish "finish-pr.sh: the post-merge PASS line names the ref it read, and the machine line POST_MERGE_GATE: PASS stays exactly that token"
  teardown
}

# =============================================================================
# CASE — THE POST-MERGE CHECK READS THE TRUNK IT LANDED INTO, IN EVERY POSTURE
#        THE PRE-MERGE GATE ACCEPTS.
#
# UNSTUBBED, DELIBERATELY: a stubbed post-merge verify (FINISH_PR_VERIFY_CMD=true) cannot
# say where it ran. The pre-merge gate requires the gate checkout at the branch tip, so a
# post-merge run that nothing moves reads the branch and can print PASS over a red trunk.
#
# THE FIXTURE. The committed verify.sh RECORDS the revision and the tree it read,
# one line per run, and is RED exactly when TRUNK_BREAK.txt is present — a file the
# trunk gains AFTER the branch forks. So the pre-merge gate (branch tip) is green and
# lets the landing happen, and the landed trunk is red. A post-merge reading that
# says anything but FAIL, or records a revision without the landed commit, read
# something other than the trunk.
#
# THE POSTURES, each one the pre-merge gate ACCEPTS:
#   (A)  --worktree at a linked worktree ON the branch — the documented QA usage;
#   (A2) --worktree at a DETACHED checkout at the branch tip;
#   (C)  the default path, main checkout DETACHED at the branch tip — accepted by the
#        provenance check as "the revision, not the ref name";
#   (F)  the main checkout on the branch BY NAME, with the trunk checked out in ANOTHER
#        worktree — the landing's switch to the trunk fails ("could not switch"), so
#        the checkout stays at the branch tip;
#   (G)  the main checkout on a DIFFERENT BRANCH NAME at the same tip — accepted by
#        revision, and not the branch the switch looks for;
#   (B)  THE CONTROL: the default path, main checkout on the branch BY NAME. The landing
#        switches that checkout to the trunk before deleting the branch, so it reads the
#        trunk. If (B) goes red, the fixture is broken, not the script.
#
# WHAT THIS CASE DOES NOT ASSERT: HOW the right tree is reached. The next case asserts
# that, so this one keeps its meaning whatever the mechanism.
# =============================================================================
_fpr_pm_sandbox() {  # <id> — builds the fixture above; sets FPR_PM_BR, FPR_PM_LOG
  make_sandbox
  cat > "$SB_WORK/scripts/verify.sh" <<'V'
#!/usr/bin/env bash
# SANDBOX GATE THAT SAYS WHERE IT RAN: one line per run — the revision, the tree, the verdict.
# RED exactly when TRUNK_BREAK.txt is present, a file only the trunk has.
root="$(cd "$(dirname "$0")/.." && pwd)"
head="$(git -C "$root" rev-parse HEAD)"
if [ -e "$root/TRUNK_BREAK.txt" ]; then
  # FPR_PM_RO: leave a READ-ONLY directory behind, as some real gates do — the tree it
  # ran in must still be removable, and its removal must not abort the landing script.
  if [ -n "${FPR_PM_RO:-}" ]; then mkdir -p "$root/ro"; : > "$root/ro/f"; chmod 555 "$root/ro"; fi
  printf '%s\t%s\tRED\n' "$head" "$root" >> "$FPR_PM_LOG"; exit 1
fi
printf '%s\t%s\tgreen\n' "$head" "$root" >> "$FPR_PM_LOG"; exit 0
V
  chmod +x "$SB_WORK/scripts/verify.sh"
  FPR_PM_BR="feature/$SB_PREFIX-$1-pm"
  seed_issue dev_complete "$SB_PREFIX-$1" pm chore "Post-merge reads the trunk" "$FPR_PM_BR"
  publish_sandbox
  seed_branch "$SB_PREFIX-$1" pm "CHANGE$1.txt"
  # THE TRUNK MOVES ON AFTER THE FORK — and what it gains turns the gate red.
  echo "only the trunk has this" > "$SB_WORK/TRUNK_BREAK.txt"
  git -C "$SB_WORK" add TRUNK_BREAK.txt >/dev/null 2>&1
  sbcommit -m "trunk moves on after the fork" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  FPR_PM_LOG="$SB_TMP/verify.log"; : > "$FPR_PM_LOG"
}
# _fpr_pm_run <id> [finish-pr args…] — the landing, UNSTUBBED. Sets FPR_PM_OUT, FPR_PM_RC.
_fpr_pm_run() {
  local id="$1"; shift
  FPR_PM_OUT="$( cd "$SB_WORK" && env FPR_PM_LOG="$FPR_PM_LOG" FPR_PM_RO="${FPR_PM_RO:-}" ./scripts/finish-pr.sh "$SB_PREFIX-$id" "$@" 2>&1 )"; FPR_PM_RC=$?
}
# _fpr_pm_landed — the full sha of the squash on origin's trunk (empty if absent). Sets FPR_PM_SQUASH.
_fpr_pm_landed() {
  origin_fetch_or_die
  FPR_PM_SQUASH="$(git -C "$SB_WORK" log -F --grep="(squash-merge $FPR_PM_BR)" --format=%H "origin/$SB_TRUNK" -1 2>/dev/null)"
}
# _fpr_pm_assert_read_the_trunk <label> <branch tip before the landing>
_fpr_pm_assert_read_the_trunk() {
  local L="$1" tip="$2" n pre post read_sha T=$'\t'
  if [ "$FPR_PM_RC" -ne 0 ]; then
    cf "($L) finish-pr exited $FPR_PM_RC, so the landing did not complete and nothing below was measured: $(printf '%s' "$FPR_PM_OUT" | tail -6 | tr '\n' '|')"
    return
  fi
  origin_has_path TRUNK_BREAK.txt \
    || { _control_did_not_run "($L) put TRUNK_BREAK.txt on the trunk"; return; }
  _fpr_pm_landed
  [ -n "$FPR_PM_SQUASH" ] || { cf "($L) no squash commit for $FPR_PM_BR on origin/$SB_TRUNK"; return; }
  n="$(wc -l < "$FPR_PM_LOG" | tr -d ' ')"
  [ "$n" -eq 2 ] || cf "($L) the gate recorded $n run(s), expected 2 (pre-merge, then post-merge): $(tr '\n' '|' < "$FPR_PM_LOG")"
  pre="$(sed -n 1p "$FPR_PM_LOG")"; post="$(sed -n 2p "$FPR_PM_LOG")"
  # CONTROL: the pre-merge gate read the branch tip and was green — the fixture is what it says.
  [ "${pre%%"$T"*}" = "$tip" ] && [ "${pre##*"$T"}" = "green" ] \
    || _control_did_not_run "($L) show the pre-merge gate green at the branch tip ${tip:0:9} (it recorded: $pre)"
  read_sha="${post%%"$T"*}"
  if [ -z "$read_sha" ] || ! git -C "$SB_WORK" merge-base --is-ancestor "$FPR_PM_SQUASH" "$read_sha" 2>/dev/null; then
    cf "($L) the post-merge gate read ${read_sha:0:9}, a tree WITHOUT the landed commit ${FPR_PM_SQUASH:0:9} — not the trunk it landed into (it recorded: ${post:-nothing})"
  fi
  printf '%s\n' "$FPR_PM_OUT" | grep -x 'POST_MERGE_GATE: FAIL' >/dev/null \
    || cf "($L) the trunk it landed into is RED, and the machine line does not say FAIL: $(printf '%s\n' "$FPR_PM_OUT" | grep -E 'POST_MERGE_GATE|post-merge verify' | tr '\n' '|')"
}
case_finish_pr_post_merge_reads_the_landed_trunk() {
  cf_reset
  local tip

  # --- (A) --worktree at a linked worktree ON the branch ----------------------
  _fpr_pm_sandbox 941
  git -C "$SB_WORK" worktree add -q "$SB_TMP/wt" "$FPR_PM_BR" >/dev/null 2>&1
  tip="$(git -C "$SB_WORK" rev-parse "refs/heads/$FPR_PM_BR")"
  [ "$(git -C "$SB_TMP/wt" symbolic-ref -q --short HEAD 2>/dev/null)" = "$FPR_PM_BR" ] \
    || _control_did_not_run "(A) put a linked worktree on $FPR_PM_BR"
  _fpr_pm_run 941 --worktree "$SB_TMP/wt"
  _fpr_pm_assert_read_the_trunk A "$tip"
  teardown

  # --- (A2) --worktree at a DETACHED checkout at the branch tip ---------------
  _fpr_pm_sandbox 942
  git -C "$SB_WORK" worktree add -q --detach "$SB_TMP/wt" "$FPR_PM_BR" >/dev/null 2>&1
  tip="$(git -C "$SB_WORK" rev-parse "refs/heads/$FPR_PM_BR")"
  [ "$(git -C "$SB_TMP/wt" rev-parse HEAD 2>/dev/null)" = "$tip" ] \
    && ! git -C "$SB_TMP/wt" symbolic-ref -q HEAD >/dev/null 2>&1 \
    || _control_did_not_run "(A2) put a detached worktree at the tip of $FPR_PM_BR"
  _fpr_pm_run 942 --worktree "$SB_TMP/wt"
  _fpr_pm_assert_read_the_trunk A2 "$tip"
  teardown

  # --- (C) default path, main checkout DETACHED at the branch tip -------------
  _fpr_pm_sandbox 943
  git -C "$SB_WORK" checkout -q --detach "$FPR_PM_BR" >/dev/null 2>&1
  tip="$(git -C "$SB_WORK" rev-parse "refs/heads/$FPR_PM_BR")"
  [ "$(git -C "$SB_WORK" rev-parse HEAD 2>/dev/null)" = "$tip" ] \
    && ! git -C "$SB_WORK" symbolic-ref -q HEAD >/dev/null 2>&1 \
    || _control_did_not_run "(C) detach the main checkout at the tip of $FPR_PM_BR"
  _fpr_pm_run 943
  _fpr_pm_assert_read_the_trunk C "$tip"
  teardown

  # --- (F) main checkout on the branch by name; the trunk held by ANOTHER worktree
  _fpr_pm_sandbox 945
  git -C "$SB_WORK" checkout -q "$FPR_PM_BR" >/dev/null 2>&1
  git -C "$SB_WORK" worktree add -q "$SB_TMP/trunk-wt" "$SB_TRUNK" >/dev/null 2>&1
  tip="$(git -C "$SB_WORK" rev-parse "refs/heads/$FPR_PM_BR")"
  [ "$(git -C "$SB_TMP/trunk-wt" symbolic-ref -q --short HEAD 2>/dev/null)" = "$SB_TRUNK" ] \
    && [ "$(git -C "$SB_WORK" symbolic-ref -q --short HEAD 2>/dev/null)" = "$FPR_PM_BR" ] \
    || _control_did_not_run "(F) hold $SB_TRUNK in a second worktree with the main checkout on $FPR_PM_BR"
  _fpr_pm_run 945
  printf '%s\n' "$FPR_PM_OUT" | grep 'could not switch the main checkout' >/dev/null \
    || _control_did_not_run "(F) make the landing's switch to $SB_TRUNK fail"
  _fpr_pm_assert_read_the_trunk F "$tip"
  teardown

  # --- (G) main checkout on a DIFFERENT branch name at the same tip ------------
  _fpr_pm_sandbox 946
  git -C "$SB_WORK" checkout -q -b "other/$SB_PREFIX-946" "$FPR_PM_BR" >/dev/null 2>&1
  tip="$(git -C "$SB_WORK" rev-parse "refs/heads/$FPR_PM_BR")"
  [ "$(git -C "$SB_WORK" rev-parse HEAD 2>/dev/null)" = "$tip" ] \
    && [ "$(git -C "$SB_WORK" symbolic-ref -q --short HEAD 2>/dev/null)" = "other/$SB_PREFIX-946" ] \
    || _control_did_not_run "(G) put the main checkout on another branch name at the tip of $FPR_PM_BR"
  _fpr_pm_run 946
  _fpr_pm_assert_read_the_trunk G "$tip"
  teardown

  # --- (B) THE CONTROL: default path, main checkout on the branch BY NAME -----
  _fpr_pm_sandbox 944
  git -C "$SB_WORK" checkout -q "$FPR_PM_BR" >/dev/null 2>&1
  tip="$(git -C "$SB_WORK" rev-parse "refs/heads/$FPR_PM_BR")"
  [ "$(git -C "$SB_WORK" symbolic-ref -q --short HEAD 2>/dev/null)" = "$FPR_PM_BR" ] \
    || _control_did_not_run "(B) put the main checkout on $FPR_PM_BR by name"
  _fpr_pm_run 944
  _fpr_pm_assert_read_the_trunk B "$tip"
  teardown

  finish "finish-pr.sh: the post-merge check reads the trunk it landed into — a committed gate that records where it ran says FAIL on a red trunk under --worktree on the branch (A), --worktree detached (A2), a detached main checkout (C), the trunk held by another worktree (F), another branch name at the tip (G), and the by-name control (B)"
}

# =============================================================================
# CASE — HOW THE POST-MERGE CHECK REACHES THE TRUNK, AND WHAT IT SAYS WHEN IT
#        CANNOT.
#
# The case above asserts THAT the right tree is read; this one asserts how:
#   * the EXISTING gate checkout is detached to the landed commit — its installed
#     dependencies survive a detach, so the post-merge run meets the pre-merge environment;
#   * the human line names the SHA it read, not only the ref;
#   * ONLY when that checkout has uncommitted tracked changes is a FRESH detached worktree
#     used; it is removed afterwards, and the operator's dirt is left where it was;
#   * a reading that CANNOT RUN says so in its own word — never PASS, and never FAIL,
#     because a FAIL asserts something about the trunk that nobody measured.
#
#   (A) --worktree on the branch: after the landing that worktree is DETACHED AT THE
#       LANDED COMMIT, the run output says it moved it, and the human line names the
#       sha the gate recorded.
#   (D) the main checkout on the branch BY NAME but DIRTY — the landing declines to
#       switch it, so it is still on the branch: the reading is taken in a FRESH
#       worktree at the landed commit, reports FAIL on the red trunk, and leaves
#       neither the worktree nor its directory behind. Its gate leaves a READ-ONLY
#       directory in that tree, and the landing script must still remove it and reach
#       its exit.
#   (E) the landed trunk's verify.sh is NOT EXECUTABLE: COULD NOT RUN, and the
#       machine line says UNRUNNABLE — not PASS, not FAIL.
#   (H) an ENVIRONMENTAL red in the fresh worktree, through the REAL verify.sh: a
#       green trunk whose one gate needs an ignored deps/ directory the fresh tree
#       lacks. verify.sh exits 1 and its summary counts one gate that could not run
#       and none that failed — so the reading is COULD NOT RUN, never FAIL.
# =============================================================================
case_finish_pr_post_merge_moves_the_gate_checkout() {
  cf_reset
  local post read_sha read_root T=$'\t' line work_p

  # --- (A) the linked worktree is moved to the landed commit, and the sha is named
  _fpr_pm_sandbox 951
  git -C "$SB_WORK" worktree add -q "$SB_TMP/wt" "$FPR_PM_BR" >/dev/null 2>&1
  _fpr_pm_run 951 --worktree "$SB_TMP/wt"
  _fpr_pm_landed
  if [ "$FPR_PM_RC" -ne 0 ] || [ -z "$FPR_PM_SQUASH" ]; then
    cf "(A) the landing did not complete (rc=$FPR_PM_RC, squash '${FPR_PM_SQUASH:-none}'), so nothing below was measured: $(printf '%s' "$FPR_PM_OUT" | tail -6 | tr '\n' '|')"
  else
    [ "$(git -C "$SB_TMP/wt" rev-parse HEAD 2>/dev/null)" = "$FPR_PM_SQUASH" ] \
      && ! git -C "$SB_TMP/wt" symbolic-ref -q HEAD >/dev/null 2>&1 \
      || cf "(A) the --worktree checkout is not DETACHED AT THE LANDED COMMIT ${FPR_PM_SQUASH:0:9} after the landing (HEAD $(git -C "$SB_TMP/wt" rev-parse --short HEAD 2>/dev/null), ref '$(git -C "$SB_TMP/wt" symbolic-ref -q --short HEAD 2>/dev/null)')"
    printf '%s\n' "$FPR_PM_OUT" | grep -F "$SB_TMP/wt" | grep -i 'detached' >/dev/null \
      || cf "(A) the run moved the operator's worktree and did not SAY so — no line names '$SB_TMP/wt' as detached"
    post="$(sed -n 2p "$FPR_PM_LOG")"; read_sha="${post%%"$T"*}"
    line="$(printf '%s\n' "$FPR_PM_OUT" | grep 'post-merge verify --quick:' | head -1)"
    [ -n "$read_sha" ] && printf '%s\n' "$line" | grep -F "${read_sha:0:7}" >/dev/null \
      || cf "(A) the post-merge line does not name the sha the gate recorded reading (${read_sha:0:9}): $line"
    # The detach frees the branch, so the landing deletes it rather than naming it as residue.
    git -C "$SB_WORK" rev-parse --verify --quiet "refs/heads/$FPR_PM_BR" >/dev/null \
      && cf "(A) the gate checkout was detached, yet the local branch '$FPR_PM_BR' survived the landing"
    printf '%s\n' "$FPR_PM_OUT" | grep -F "Residue: the local" >/dev/null \
      && cf "(A) the Done line names a local branch the landing could delete as residue"
    [ "$(printf '%s\n' "$FPR_PM_OUT" | grep -cF "Detached the gate checkout '$SB_TMP/wt'")" -eq 1 ] \
      || cf "(A) the run does not report the detach exactly once"
  fi
  teardown

  # --- (D) dirty gate checkout -> a FRESH worktree, removed afterwards ----------
  _fpr_pm_sandbox 952
  git -C "$SB_WORK" checkout -q "$FPR_PM_BR" >/dev/null 2>&1
  echo "uncommitted" >> "$SB_WORK/CHANGE952.txt"      # tracked on the branch: the checkout is DIRTY
  work_p="$(cd "$SB_WORK" && pwd -P)"
  FPR_PM_RO=1 _fpr_pm_run 952
  _fpr_pm_landed
  if [ "$FPR_PM_RC" -ne 0 ] || [ -z "$FPR_PM_SQUASH" ]; then
    cf "(D) the landing did not complete (rc=$FPR_PM_RC), so nothing below was measured: $(printf '%s' "$FPR_PM_OUT" | tail -6 | tr '\n' '|')"
  else
    post="$(sed -n 2p "$FPR_PM_LOG")"; read_sha="${post%%"$T"*}"
    read_root="${post#*"$T"}"; read_root="${read_root%"$T"*}"
    [ -n "$read_sha" ] && git -C "$SB_WORK" merge-base --is-ancestor "$FPR_PM_SQUASH" "$read_sha" 2>/dev/null \
      || cf "(D) the post-merge reading (${read_sha:0:9}) does not contain the landed commit ${FPR_PM_SQUASH:0:9}: ${post:-nothing recorded}"
    case "$read_root" in
      ''|"$SB_WORK"|"$work_p") cf "(D) the reading ran in the DIRTY main checkout ('${read_root:-nowhere}'), not a fresh worktree"
                               read_root="" ;;   # nothing fresh to look for below
    esac
    printf '%s\n' "$FPR_PM_OUT" | grep -x 'POST_MERGE_GATE: FAIL' >/dev/null \
      || cf "(D) the landed trunk is RED and the machine line does not say FAIL: $(printf '%s\n' "$FPR_PM_OUT" | grep -E 'POST_MERGE_GATE|post-merge verify' | tr '\n' '|')"
    printf '%s\n' "$FPR_PM_OUT" | grep -i 'fresh worktree' >/dev/null \
      || cf "(D) the output does not say the reading was taken in a FRESH worktree — a reader cannot tell a red from missing dependencies there"
    printf '%s\n' "$FPR_PM_OUT" | grep -E '^POST_MERGE_GATE: ' >/dev/null \
      || cf "(D) no POST_MERGE_GATE line — the script stopped before reporting (a read-only leftover in the fresh tree)"
    if [ -n "$read_root" ]; then
      [ ! -e "$read_root" ] || { cf "(D) the fresh worktree '$read_root' was left on disk"; chmod -R u+w "$read_root" 2>/dev/null; rm -rf "$(dirname "$read_root")" 2>/dev/null; }
      git -C "$SB_WORK" worktree list --porcelain 2>/dev/null | grep -F "$read_root" >/dev/null \
        && cf "(D) the fresh worktree is still registered with git"
    fi
    [ "$(git -C "$SB_WORK" symbolic-ref -q --short HEAD 2>/dev/null)" = "$FPR_PM_BR" ] \
      || cf "(D) the dirty main checkout was MOVED off $FPR_PM_BR — its owner's posture was not left alone"
    grep -x "uncommitted" "$SB_WORK/CHANGE952.txt" >/dev/null \
      || cf "(D) the dirty main checkout LOST its uncommitted change"
  fi
  teardown

  # --- (E) the landed trunk's gate cannot run -> COULD NOT RUN / UNRUNNABLE -----
  _fpr_pm_sandbox 953
  chmod -x "$SB_WORK/scripts/verify.sh"
  git -C "$SB_WORK" update-index --chmod=-x scripts/verify.sh >/dev/null 2>&1
  sbcommit -m "trunk's gate loses its execute bit" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" checkout -q --detach "$FPR_PM_BR" >/dev/null 2>&1   # the branch's gate IS executable
  [ -x "$SB_WORK/scripts/verify.sh" ] \
    || _control_did_not_run "(E) restore the branch's executable gate, so the pre-merge gate could run"
  _fpr_pm_run 953
  if [ "$FPR_PM_RC" -ne 0 ]; then
    cf "(E) the landing did not complete (rc=$FPR_PM_RC) — an unrunnable POST-merge reading must not move the exit code: $(printf '%s' "$FPR_PM_OUT" | tail -6 | tr '\n' '|')"
  else
    printf '%s\n' "$FPR_PM_OUT" | grep -x 'POST_MERGE_GATE: UNRUNNABLE' >/dev/null \
      || cf "(E) the machine line is not 'POST_MERGE_GATE: UNRUNNABLE': $(printf '%s\n' "$FPR_PM_OUT" | grep -E 'POST_MERGE_GATE' | tr '\n' '|')"
    printf '%s\n' "$FPR_PM_OUT" | grep -E '^POST_MERGE_GATE: (PASS|FAIL)$' >/dev/null \
      && cf "(E) a reading that could not run was reported as PASS or FAIL"
    printf '%s\n' "$FPR_PM_OUT" | grep 'post-merge verify --quick: COULD NOT RUN' >/dev/null \
      || cf "(E) the human line does not say COULD NOT RUN"
    [ "$(wc -l < "$FPR_PM_LOG" | tr -d ' ')" -eq 1 ] \
      || cf "(E) the gate recorded a post-merge run it could not have made: $(tr '\n' '|' < "$FPR_PM_LOG")"
  fi
  teardown

  # --- (H) an ENVIRONMENTAL red in the fresh worktree, through the REAL verify.sh
  make_sandbox
  awk '{print} /^GATES=\($/{print "  \"deps|core|deps/run-gate\""}' "$SB_WORK/scripts/verify.sh" > "$SB_TMP/v.sh" \
    && cat "$SB_TMP/v.sh" > "$SB_WORK/scripts/verify.sh"
  echo "deps/" >> "$SB_WORK/.gitignore"
  mkdir -p "$SB_WORK/deps" && printf '#!/bin/sh\nexit 0\n' > "$SB_WORK/deps/run-gate" && chmod +x "$SB_WORK/deps/run-gate"
  FPR_PM_BR="feature/$SB_PREFIX-954-pm"
  seed_issue dev_complete "$SB_PREFIX-954" pm chore "Environmental red" "$FPR_PM_BR"
  publish_sandbox
  seed_branch "$SB_PREFIX-954" pm CHANGE954.txt
  git -C "$SB_WORK" checkout -q "$FPR_PM_BR" >/dev/null 2>&1
  echo "uncommitted" >> "$SB_WORK/CHANGE954.txt"      # DIRTY: the reading goes to a fresh tree
  ( cd "$SB_WORK" && ./scripts/verify.sh --quick ) >/dev/null 2>&1 \
    || _control_did_not_run "(H) make the real verify.sh green where deps/ is installed"
  git -C "$SB_WORK" check-ignore -q deps/run-gate \
    || _control_did_not_run "(H) keep deps/ ignored, so a fresh worktree lacks it"
  FPR_PM_OUT="$( cd "$SB_WORK" && ./scripts/finish-pr.sh "$SB_PREFIX-954" 2>&1 )"; FPR_PM_RC=$?
  if [ "$FPR_PM_RC" -ne 0 ]; then
    cf "(H) the landing did not complete (rc=$FPR_PM_RC): $(printf '%s' "$FPR_PM_OUT" | tail -6 | tr '\n' '|')"
  else
    printf '%s\n' "$FPR_PM_OUT" | grep -E '^gates declared: .*failed: 0 .*could not run: 1' >/dev/null \
      || _control_did_not_run "(H) get verify.sh's summary to count one gate that could not run and none that failed"
    printf '%s\n' "$FPR_PM_OUT" | grep -x 'POST_MERGE_GATE: UNRUNNABLE' >/dev/null \
      || cf "(H) an environmental red in the fresh tree was not reported UNRUNNABLE: $(printf '%s\n' "$FPR_PM_OUT" | grep -E 'POST_MERGE_GATE|post-merge verify' | tr '\n' '|')"
    printf '%s\n' "$FPR_PM_OUT" | grep -x 'POST_MERGE_GATE: FAIL' >/dev/null \
      && cf "(H) a gate that could not run was reported as a FAIL of the trunk"
  fi
  teardown

  finish "finish-pr.sh: the post-merge check detaches the existing gate checkout to the landed commit, names the sha it read and deletes the branch it freed (A), uses a fresh worktree only for a dirty checkout and removes it even when the gate leaves it read-only (D), and says COULD NOT RUN / UNRUNNABLE rather than PASS or FAIL when the landed gate cannot run (E) or ran and could not run a gate in the fresh tree (H)"
}

# =============================================================================
# CASE — A FRESH POST-MERGE WORKTREE IS PREPARED BY THE LANDED TREE'S POST_MERGE_PREP,
#        AND ONLY THEN.
#
# THE FIXTURE. The committed verify.sh is red unless an IGNORED `.prepared` file exists — the
# stand-in for installed dependencies: the gate checkout has it, a fresh worktree does not.
# The gate appends one line per run to $PM_GATE_LOG, the prep to $PM_PREP_LOG.
#
#   (P1) dirty gate checkout + a declared prep that makes `.prepared`: the reading is PASS,
#        the output says the tree was prepared, and the prep ran exactly once.
#   (P2) the same dirty checkout, NO declared prep: unchanged — FAIL, and the note says how
#        to read the gate checkout in place (commit or stash).
#   (P3) a declared prep that exits 1: UNRUNNABLE (never FAIL), naming POST_MERGE_PREP, and
#        the gate does not run.
#   (P4) CLEAN gate checkout + a declared prep: the checkout is read in place and the prep
#        does NOT run.
#   (P5) NO declared prep + a POST_MERGE_PREP in the environment: not honoured — the
#        declaration is the landed tree's, not the caller's.
# =============================================================================
_fpr_prep_sandbox() {  # <id> <prep line, or empty> — sets FPR_PM_BR, PM_GATE_LOG, PM_PREP_LOG
  make_sandbox
  cat > "$SB_WORK/scripts/verify.sh" <<'V'
#!/usr/bin/env bash
root="$(cd "$(dirname "$0")/.." && pwd)"
printf 'gate\n' >> "$PM_GATE_LOG"
[ -e "$root/.prepared" ] || { echo "gate: .prepared is missing in $root"; exit 1; }
exit 0
V
  chmod +x "$SB_WORK/scripts/verify.sh"
  echo ".prepared" >> "$SB_WORK/.gitignore"
  : > "$SB_WORK/.prepared"
  # The shipped declaration is REPLACED, never appended to: the reader takes the first one.
  if [ -n "$2" ]; then
    grep -v '^POST_MERGE_PREP=' "$SB_WORK/scripts/config.sh" > "$SB_TMP/config.sh" || true
    printf '%s\n' "$2" >> "$SB_TMP/config.sh"
    cat "$SB_TMP/config.sh" > "$SB_WORK/scripts/config.sh"
    [ "$(grep -c '^POST_MERGE_PREP=' "$SB_WORK/scripts/config.sh")" -eq 1 ] \
      || _fixture_die "_fpr_prep_sandbox: config.sh does not hold exactly one POST_MERGE_PREP declaration, so the prep under test is not the one read"
  fi
  FPR_PM_BR="feature/$SB_PREFIX-$1-pm"
  seed_issue dev_complete "$SB_PREFIX-$1" pm chore "Post-merge prep" "$FPR_PM_BR"
  publish_sandbox
  seed_branch "$SB_PREFIX-$1" pm "CHANGE$1.txt"
  PM_GATE_LOG="$SB_TMP/gate.log"; PM_PREP_LOG="$SB_TMP/prep.log"; : > "$PM_GATE_LOG"; : > "$PM_PREP_LOG"
}
_fpr_prep_run() {  # <id> [extra env NAME=value…] — sets FPR_PM_OUT, FPR_PM_RC
  local id="$1"; shift
  FPR_PM_OUT="$( cd "$SB_WORK" && env PM_GATE_LOG="$PM_GATE_LOG" PM_PREP_LOG="$PM_PREP_LOG" "$@" ./scripts/finish-pr.sh "$SB_PREFIX-$id" 2>&1 )"; FPR_PM_RC=$?
}
_fpr_prep_dirty() {  # <id> — the gate checkout on the branch with an uncommitted tracked change
  git -C "$SB_WORK" checkout -q "$FPR_PM_BR" >/dev/null 2>&1
  echo "uncommitted" >> "$SB_WORK/CHANGE$1.txt"
}
case_finish_pr_post_merge_prepares_the_fresh_worktree() {
  cf_reset
  local prep_ok='POST_MERGE_PREP='\''touch .prepared && echo ran >> "$PM_PREP_LOG"'\'''
  local machine

  # --- (P1) dirty checkout + declared prep -> PASS, prepared, prep ran once ------
  _fpr_prep_sandbox 961 "$prep_ok"
  _fpr_prep_dirty 961
  _fpr_prep_run 961
  if [ "$FPR_PM_RC" -ne 0 ]; then
    cf "(P1) the landing did not complete (rc=$FPR_PM_RC): $(printf '%s' "$FPR_PM_OUT" | tail -6 | tr '\n' '|')"
  else
    printf '%s\n' "$FPR_PM_OUT" | grep -i 'fresh worktree' >/dev/null \
      || _control_did_not_run "(P1) route the reading to a fresh worktree"
    printf '%s\n' "$FPR_PM_OUT" | grep -x 'POST_MERGE_GATE: PASS' >/dev/null \
      || cf "(P1) a fresh worktree prepared by the declared POST_MERGE_PREP did not read PASS: $(printf '%s\n' "$FPR_PM_OUT" | grep -E 'POST_MERGE_GATE|post-merge verify|gate:' | tr '\n' '|')"
    printf '%s\n' "$FPR_PM_OUT" | grep 'prepared the fresh worktree with POST_MERGE_PREP' >/dev/null \
      || cf "(P1) the reading does not say the fresh worktree was prepared — a PASS must state what it read"
    [ "$(wc -l < "$PM_PREP_LOG" | tr -d ' ')" -eq 1 ] \
      || cf "(P1) the prep ran $(wc -l < "$PM_PREP_LOG" | tr -d ' ') time(s), expected once: $(tr '\n' '|' < "$PM_PREP_LOG")"
  fi
  teardown

  # --- (P2) dirty checkout, NO declared prep -> unchanged FAIL, and the hint ------
  _fpr_prep_sandbox 962 ""
  _fpr_prep_dirty 962
  _fpr_prep_run 962
  if [ "$FPR_PM_RC" -ne 0 ]; then
    cf "(P2) the landing did not complete (rc=$FPR_PM_RC): $(printf '%s' "$FPR_PM_OUT" | tail -6 | tr '\n' '|')"
  else
    printf '%s\n' "$FPR_PM_OUT" | grep -x 'POST_MERGE_GATE: FAIL' >/dev/null \
      || _control_did_not_run "(P2) get the unprepared fresh worktree to read FAIL: $(printf '%s\n' "$FPR_PM_OUT" | grep -E 'POST_MERGE_GATE' | tr '\n' '|')"
    printf '%s\n' "$FPR_PM_OUT" | grep -i 'prepared the fresh worktree' >/dev/null \
      && cf "(P2) the output claims a preparation nobody declared"
    printf '%s\n' "$FPR_PM_OUT" | grep -i 'commit or stash' >/dev/null \
      || cf "(P2) the uncommitted-changes note does not say to commit or stash to read the gate checkout in place: $(printf '%s\n' "$FPR_PM_OUT" | grep 'uncommitted tracked' | head -2 | tr '\n' '|')"
  fi
  teardown

  # --- (P3) a prep that exits 1 -> UNRUNNABLE, naming it; the gate does not run ----
  _fpr_prep_sandbox 963 "POST_MERGE_PREP='exit 1'"
  _fpr_prep_dirty 963
  _fpr_prep_run 963
  if [ "$FPR_PM_RC" -ne 0 ]; then
    cf "(P3) the landing did not complete (rc=$FPR_PM_RC) — a failed prep must not move the exit code: $(printf '%s' "$FPR_PM_OUT" | tail -6 | tr '\n' '|')"
  else
    printf '%s\n' "$FPR_PM_OUT" | grep -x 'POST_MERGE_GATE: UNRUNNABLE' >/dev/null \
      || cf "(P3) a prep that exited 1 did not read UNRUNNABLE: $(printf '%s\n' "$FPR_PM_OUT" | grep -E 'POST_MERGE_GATE|post-merge verify' | tr '\n' '|')"
    printf '%s\n' "$FPR_PM_OUT" | grep -E '^POST_MERGE_GATE: (PASS|FAIL)$' >/dev/null \
      && cf "(P3) a prep failure measured nothing about the trunk, yet the reading says PASS or FAIL"
    printf '%s\n' "$FPR_PM_OUT" | grep 'COULD NOT RUN' | grep 'POST_MERGE_PREP' | grep 'exited 1' >/dev/null \
      || cf "(P3) the COULD NOT RUN line does not name POST_MERGE_PREP and its exit status: $(printf '%s\n' "$FPR_PM_OUT" | grep 'COULD NOT RUN' | tr '\n' '|')"
    [ "$(wc -l < "$PM_GATE_LOG" | tr -d ' ')" -eq 1 ] \
      || cf "(P3) the gate ran after the prep failed (it recorded $(wc -l < "$PM_GATE_LOG" | tr -d ' ') runs, expected only the pre-merge one)"
  fi
  teardown

  # --- (P4) CLEAN checkout + declared prep -> read in place, prep NOT run ----------
  _fpr_prep_sandbox 964 "$prep_ok"
  git -C "$SB_WORK" checkout -q "$FPR_PM_BR" >/dev/null 2>&1
  _fpr_prep_run 964
  if [ "$FPR_PM_RC" -ne 0 ]; then
    cf "(P4) the landing did not complete (rc=$FPR_PM_RC): $(printf '%s' "$FPR_PM_OUT" | tail -6 | tr '\n' '|')"
  else
    printf '%s\n' "$FPR_PM_OUT" | grep -x 'POST_MERGE_GATE: PASS' >/dev/null \
      || _control_did_not_run "(P4) get the clean gate checkout to read PASS"
    printf '%s\n' "$FPR_PM_OUT" | grep -i 'fresh worktree' >/dev/null \
      && cf "(P4) a clean gate checkout was not read in place"
    [ ! -s "$PM_PREP_LOG" ] \
      || cf "(P4) the prep ran against a gate checkout that was read in place: $(tr '\n' '|' < "$PM_PREP_LOG")"
  fi
  teardown

  # --- (P5) no declared prep, one in the ENVIRONMENT -> not honoured -------------
  _fpr_prep_sandbox 965 ""
  _fpr_prep_dirty 965
  _fpr_prep_run 965 POST_MERGE_PREP='touch .prepared && echo env >> "$PM_PREP_LOG"'
  if [ "$FPR_PM_RC" -ne 0 ]; then
    cf "(P5) the landing did not complete (rc=$FPR_PM_RC): $(printf '%s' "$FPR_PM_OUT" | tail -6 | tr '\n' '|')"
  else
    [ ! -s "$PM_PREP_LOG" ] \
      || cf "(P5) a POST_MERGE_PREP supplied by the environment ran: the prep must be the landed commit's own declaration"
    printf '%s\n' "$FPR_PM_OUT" | grep -x 'POST_MERGE_GATE: FAIL' >/dev/null \
      || cf "(P5) the reading changed under an environment-supplied prep: $(printf '%s\n' "$FPR_PM_OUT" | grep -E 'POST_MERGE_GATE' | tr '\n' '|')"
  fi
  teardown

  finish "finish-pr.sh: a fresh post-merge worktree is prepared by the landed tree's declared POST_MERGE_PREP and the reading says so (P1), nothing runs when none is declared and the note says to commit or stash (P2), a failed prep reads UNRUNNABLE and the gate does not run (P3), a gate checkout read in place is never prepared (P4), and an environment-supplied prep is ignored (P5)"
}

case_finish_pr_post_merge_names_the_dirty_paths() {
  cf_reset
  local card out work_p n

  # --- (N1) dirty card copy + dirty file -> both paths named, the card copy carries its command
  _fpr_pm_sandbox 971
  _fpr_prep_dirty 971
  card="progress/dev_complete/$SB_PREFIX-971-pm.md"
  [ -f "$SB_WORK/$card" ] || _control_did_not_run "(N1) find the seeded card copy at $card"
  echo "stale" >> "$SB_WORK/$card"
  work_p="$(cd "$SB_WORK" && pwd -P)"
  _fpr_pm_run 971
  out="$FPR_PM_OUT"
  if [ "$FPR_PM_RC" -ne 0 ]; then
    cf "(N1) the landing did not complete (rc=$FPR_PM_RC): $(printf '%s' "$out" | tail -6 | tr '\n' '|')"
  else
    printf '%s\n' "$out" | grep -F "CHANGE971.txt" >/dev/null \
      || cf "(N1) the note does not name the dirty file CHANGE971.txt: $(printf '%s\n' "$out" | grep 'uncommitted' | head -2 | tr '\n' '|')"
    printf '%s\n' "$out" | grep -F "git -C '$work_p' checkout -- '$card'" >/dev/null \
      || cf "(N1) the note does not give the checkout command for the dirty card copy $card"
    printf '%s\n' "$out" | grep -F "git -C '$work_p' checkout -- 'CHANGE971.txt'" >/dev/null \
      && cf "(N1) the card-copy command was offered for a path that is not a card copy"
    grep -F "stale" "$SB_WORK/$card" >/dev/null \
      || cf "(N1) the dirty card copy was discarded: the note names the command and runs nothing"
  fi
  teardown

  # --- (N2) dirty non-card file only -> the path is named, no card-copy clause --
  _fpr_pm_sandbox 972
  _fpr_prep_dirty 972
  _fpr_pm_run 972
  out="$FPR_PM_OUT"
  if [ "$FPR_PM_RC" -ne 0 ]; then
    cf "(N2) the landing did not complete (rc=$FPR_PM_RC): $(printf '%s' "$out" | tail -6 | tr '\n' '|')"
  else
    printf '%s\n' "$out" | grep -F "CHANGE972.txt" >/dev/null \
      || cf "(N2) the note does not name the dirty file CHANGE972.txt"
    printf '%s\n' "$out" | grep -F "card copy" >/dev/null \
      && cf "(N2) a card-copy clause was printed with no dirty card copy"
  fi
  teardown

  # --- (N3) more than five dirty files -> five named and a count ---------------------------
  _fpr_pm_sandbox 973
  _fpr_prep_dirty 973
  local i
  for i in 1 2 3 4 5 6; do echo x >> "$SB_WORK/progress/dev_complete/$SB_PREFIX-973-pm.md"; done
  # Five tracked files of its own: the sandbox's own tracked prose (consumers/ among it) is a population a project may remove.
  for i in 1 2 3 4 5; do echo base > "$SB_WORK/DIRTY973-$i.txt"; done
  git -C "$SB_WORK" add DIRTY973-1.txt DIRTY973-2.txt DIRTY973-3.txt DIRTY973-4.txt DIRTY973-5.txt >/dev/null 2>&1
  sbcommit -m "five tracked files to dirty" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  for i in 1 2 3 4 5; do echo x >> "$SB_WORK/DIRTY973-$i.txt"; done
  n="$(git -C "$SB_WORK" diff --name-only | wc -l | tr -d ' ')"
  [ "$n" -gt 5 ] || _control_did_not_run "(N3) dirty more than five tracked files (got $n)"
  _fpr_pm_run 973
  out="$FPR_PM_OUT"
  if [ "$FPR_PM_RC" -ne 0 ]; then
    cf "(N3) the landing did not complete (rc=$FPR_PM_RC): $(printf '%s' "$out" | tail -6 | tr '\n' '|')"
  else
    printf '%s\n' "$out" | grep -F "(+$((n - 5)) more)" >/dev/null \
      || cf "(N3) $n dirty paths did not print five and '(+$((n - 5)) more)': $(printf '%s\n' "$out" | grep -E 'changed:|more\)' | tr '\n' '|')"
    [ "$(printf '%s\n' "$out" | grep -c '^    changed: ')" -eq 5 ] \
      || cf "(N3) the note did not name exactly five paths: $(printf '%s\n' "$out" | grep -E 'changed:' | tr '\n' '|')"
  fi
  teardown

  finish "finish-pr.sh: the uncommitted-changes note names the dirty paths of the gate checkout (N1), gives a card copy its own discard command and discards nothing (N1), prints no card-copy clause for other files (N2), and caps the list at five with a count (N3)"
}

# =============================================================================
# CASE — the branch is checked out in a SECOND WORKTREE: the local delete correctly SKIPS,
# and the board note must not claim it.
# =============================================================================
case_finish_pr_second_worktree() {
  cf_reset
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-779" sandbox chore "Worktree holds the branch" "feature/$SB_PREFIX-779-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-779" work WT.txt

  git -C "$SB_WORK" worktree add "$SB_TMP/wt2" "feature/$SB_PREFIX-779-work" --quiet >/dev/null 2>&1 \
    || cf "could not create the second worktree (test setup)"

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-779" 2>&1 )"; rc=$?

  # The landing still succeeds: a branch a worktree holds is residue, not failure.
  [ "$rc" -eq 0 ] || cf "finish-pr exited $rc (expected 0 — the landing succeeded): $out"
  origin_has_path "WT.txt" || cf "squash-merged change not on the trunk"
  origin_has_path "progress/qa_complete/$SB_PREFIX-779-sandbox.md" || cf "issue not advanced to qa_complete/"
  # The local ref is PRESERVED (never force-delete a checked-out branch)...
  git -C "$SB_WORK" rev-parse --verify --quiet "refs/heads/feature/$SB_PREFIX-779-work" >/dev/null 2>&1 \
    || cf "local branch was deleted while a worktree held it — the skip was not preserved"
  # ...the operator is TOLD, and told WHICH worktree...
  printf '%s' "$out" | grep "checked out in a worktree" >/dev/null \
    || cf "run output does not say the local branch was kept because a worktree holds it"
  printf '%s' "$out" | grep -F "$SB_TMP/wt2" >/dev/null \
    || cf "run output does not name the worktree that holds the branch"
  # ...and the remote arm is INDEPENDENT: it fires anyway and succeeds.
  [ -z "$(git -C "$SB_WORK" ls-remote --heads origin "feature/$SB_PREFIX-779-work" 2>/dev/null)" ] \
    || cf "remote branch not deleted (the remote arm must not be gated on the local one)"
  # THE CLAIM: the note must NOT say the local branch was deleted.
  origin_file_contains "progress/qa_complete/$SB_PREFIX-779-sandbox.md" "LOCAL BRANCH KEPT" \
    || cf "board note does not report that the local branch was kept"
  origin_file_contains "progress/qa_complete/$SB_PREFIX-779-sandbox.md" "local branch deleted" \
    && cf "board note FALSELY claims the local branch was deleted"

  printf '%s\n' "$out" | grep -F "Residue: the local branch 'feature/$SB_PREFIX-779-work' is not confirmed gone" >/dev/null \
    || cf "the Done line does not name the surviving local branch"

  finish "finish-pr.sh with the branch held by a second worktree: local skip preserved, remote still deleted, and neither the note nor the Done line claims the local delete"
  teardown
}

# =============================================================================
# CASE — the remote REFUSES the delete (receive.denyDeletes). Forge-agnostic: a plain bare
# repo declining a deletion. git's own stderr must be surfaced.
# =============================================================================
case_finish_pr_remote_delete_refused() {
  cf_reset
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-780" sandbox chore "Remote refuses the delete" "feature/$SB_PREFIX-780-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-780" work REFUSE.txt

  git -C "$SB_ORIGIN" config receive.denyDeletes true >/dev/null 2>&1

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-780" 2>&1 )"; rc=$?

  # NON-FATAL by design: the merge has landed and been pushed, so this is residue.
  [ "$rc" -eq 0 ] || cf "finish-pr exited $rc (expected 0 — a refused delete must not read as a failed landing): $out"
  origin_has_path "REFUSE.txt" || cf "squash-merged change not on the trunk"
  origin_has_path "progress/qa_complete/$SB_PREFIX-780-sandbox.md" || cf "issue not advanced to qa_complete/"
  [ -n "$(git -C "$SB_WORK" ls-remote --heads origin "feature/$SB_PREFIX-780-work" 2>/dev/null)" ] \
    || cf "test setup: receive.denyDeletes did not actually refuse the delete"
  printf '%s' "$out" | grep "WARNING: could NOT delete remote branch" >/dev/null \
    || cf "a refused remote delete was not reported loudly"
  printf '%s' "$out" | grep -E 'remote rejected|denyDeletes|deletion prohibited|pre-receive' >/dev/null \
    || cf "git's own rejection text was not surfaced (still silenced?)"
  printf '%s' "$out" | grep "push origin --delete" >/dev/null \
    || cf "the report does not name the command that finishes the job"
  git -C "$SB_WORK" rev-parse --verify --quiet "refs/heads/feature/$SB_PREFIX-780-work" >/dev/null 2>&1 \
    && cf "local branch not deleted (the local arm must not be gated on the remote one)"
  origin_file_contains "progress/qa_complete/$SB_PREFIX-780-sandbox.md" "NOT DELETED (the push was refused)" \
    || cf "board note does not report the refused remote delete"
  origin_file_contains "progress/qa_complete/$SB_PREFIX-780-sandbox.md" "branch deleted (confirmed gone)" \
    && cf "board note FALSELY claims a confirmed remote delete"

  printf '%s\n' "$out" | grep -F "Residue: the origin branch 'feature/$SB_PREFIX-780-work' is not confirmed gone" >/dev/null \
    || cf "the Done line does not name the surviving remote branch"

  finish "finish-pr.sh with a remote that refuses deletes: loud, git's own error surfaced, exit still 0, and the note and the Done line name the survivor"
  teardown
}

# =============================================================================
# CASE — a delete that reports SUCCESS and does not stick. An exit code cannot see that;
# only re-measuring the remote can. Here a post-receive hook restores any deleted ref.
# =============================================================================
case_finish_pr_remote_delete_resurrected() {
  cf_reset
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-781" sandbox chore "Remote resurrects the ref" "feature/$SB_PREFIX-781-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-781" work RESURRECT.txt
  local tip; tip="$(git -C "$SB_WORK" rev-parse "feature/$SB_PREFIX-781-work")"

  cat > "$SB_ORIGIN/hooks/post-receive" <<'HOOK'
#!/bin/sh
# Restore any ref this push deleted — the observable shape of a mirror or sync
# pushing a branch back into the remote after a successful delete.
while read -r old new ref; do
  case "$new" in
    0000000000000000000000000000000000000000) git update-ref "$ref" "$old" ;;
  esac
done
HOOK
  chmod +x "$SB_ORIGIN/hooks/post-receive"

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-781" 2>&1 )"; rc=$?

  [ "$rc" -eq 0 ] || cf "finish-pr exited $rc (expected 0 — the landing succeeded): $out"
  origin_has_path "RESURRECT.txt" || cf "squash-merged change not on the trunk"
  local still; still="$(git -C "$SB_WORK" ls-remote --heads origin "feature/$SB_PREFIX-781-work" 2>/dev/null)"
  printf '%s' "$still" | grep "$tip" >/dev/null \
    || cf "test setup: the post-receive hook did not resurrect the ref (got: '$still')"
  printf '%s' "$out" | grep "SURVIVED a delete that reported SUCCESS" >/dev/null \
    || cf "an exit-0 delete whose ref survived was NOT caught — the fix relies on re-measuring, not the exit code"
  printf '%s' "$out" | grep "still advertises the ref" >/dev/null \
    || cf "the report does not show the surviving ref it measured"
  printf '%s' "$out" | grep "The LANDING IS FINE" >/dev/null \
    || cf "the report does not distinguish residue from a failed landing"
  origin_file_contains "progress/qa_complete/$SB_PREFIX-781-sandbox.md" "STILL PRESENT after a delete that reported success" \
    || cf "board note does not report the surviving remote branch"
  origin_file_contains "progress/qa_complete/$SB_PREFIX-781-sandbox.md" "branch deleted (confirmed gone)" \
    && cf "board note FALSELY claims a confirmed remote delete"

  finish "finish-pr.sh when the remote accepts a delete then restores the ref: caught by re-measurement, and the note never claims the delete"
  teardown
}

# =============================================================================
# CASE — the printed recovery's step 3 finishes either half of the branch delete, run as printed.
#
# A squash-merged local branch with no upstream is "not fully merged", and an already-deleted one
# is "not found": chained with `&&`, either would skip the remote delete, so the step runs both
# halves independently.
# =============================================================================
case_finish_pr_recovery_step_three_finishes_either_half() {
  cf_reset
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-782" sandbox chore "Recovery step 3" "feature/$SB_PREFIX-782-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-782" work RECOVER.txt
  local out rc b tip step3
  b="feature/$SB_PREFIX-782-work"; tip="$(git -C "$SB_WORK" rev-parse "$b")"
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-782" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "finish-pr exited $rc (expected 0): $out"
  step3="$(printf '%s\n' "$out" | sed -n 's/^     3\. //p')"
  [ -n "$step3" ] || _fixture_die "case_finish_pr_recovery_step_three_finishes_either_half: no printed recovery step 3 to run."

  # (a) Both halves left, the local one squash-merged with no upstream.
  git -C "$SB_WORK" branch -q "$b" "$tip" && git -C "$SB_WORK" push -q origin "$tip:refs/heads/$b" >/dev/null 2>&1 \
    || _fixture_die "case_finish_pr_recovery_step_three_finishes_either_half: could not restore both halves of '$b'."
  sh -c "$step3" >/dev/null 2>&1 || true
  git -C "$SB_WORK" rev-parse --verify --quiet "refs/heads/$b" >/dev/null && cf "(a) step 3 left the local branch"
  [ -z "$(git -C "$SB_WORK" ls-remote --heads origin "$b")" ] || cf "(a) step 3 left the remote branch"

  # (b) A re-run after the local half: only the remote one left.
  git -C "$SB_WORK" push -q origin "$tip:refs/heads/$b" >/dev/null 2>&1 \
    || _fixture_die "case_finish_pr_recovery_step_three_finishes_either_half: could not restore the remote half of '$b'."
  sh -c "$step3" >/dev/null 2>&1 || true
  [ -z "$(git -C "$SB_WORK" ls-remote --heads origin "$b")" ] || cf "(b) step 3 re-run left the remote branch"

  finish "finish-pr.sh's printed recovery step 3 deletes a squash-merged local branch and still deletes the remote one when the local is already gone"
  teardown
}

# THE POST-REFUSAL CONTRACT, ONE AUTHORING SITE: a refusal leaves the local branch, the
# remote branch and the issue untouched, and merges nothing. The merge marker is OPTIONAL:
# a leg with no commit on its branch has nothing that could merge, and asserting it there
# would be a check that cannot fail.
#
#   assert_landing_untouched <label> <id> <slug> <branch> [<merge marker>]
assert_landing_untouched() {
  local lab="$1" id="$2" slug="$3" br="$4" marker="${5:-}"
  git -C "$SB_WORK" rev-parse --verify --quiet "refs/heads/$br" >/dev/null 2>&1 \
    || cf "$lab local branch '$br' was destroyed — a refusal must leave it intact"
  [ -n "$(git -C "$SB_WORK" ls-remote --heads origin "$br" 2>/dev/null)" ] \
    || cf "$lab remote branch '$br' was deleted — a refusal must leave it intact"
  origin_has_path "progress/dev_complete/$id-$slug.md" \
    || cf "$lab issue left dev_complete/ — a refusal must not advance it"
  if [ -n "$marker" ]; then
    origin_has_path "$marker" && cf "$lab '$marker' reached the trunk — a refusal must not merge"
  fi
  return 0   # the last command above is a `&&` whose false branch is the PASSING one
}

# =============================================================================
# CASE — a RED pre-merge gate aborts, destroying nothing.
# =============================================================================
case_finish_pr_premerge_red() {
  cf_reset
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-778" sandbox chore "Pre-merge red" "feature/$SB_PREFIX-778-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-778" work CHANGE.txt

  local out rc
  out="$( cd "$SB_WORK" && FINISH_PR_TEST_ALLOW_STUB=1 FINISH_PR_VERIFY_CMD=true FINISH_PR_PREMERGE_CMD=false \
            "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-778" 2>&1 )"; rc=$?

  [ "$rc" -ne 0 ] || cf "expected nonzero exit on a red pre-merge gate, got 0: $out"
  assert_landing_untouched "(red pre-merge gate)" "$SB_PREFIX-778" sandbox \
    "feature/$SB_PREFIX-778-work" CHANGE.txt

  finish "finish-pr.sh red pre-merge gate aborts (no merge/push/delete/advance)"
  teardown
}

# =============================================================================
# CASE — a pre-merge gate that COULD NOT RUN refuses as firmly as a failing one, and
#        is NAMED as what it is.
#
# The gate runner exits 3 when nothing failed and a gate never executed. The landing
# refuses on any red, and names exit 3 COULD NOT RUN rather than FAILED. Driven through the
# test-only command seam with a gate that exits 3, and a gate that exits 1 as the control.
# =============================================================================
case_finish_pr_premerge_names_an_unrunnable_gate() {
  cf_reset
  local out rc
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-785" sandbox chore "Pre-merge unrunnable" "feature/$SB_PREFIX-785-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-785" work CHANGE.txt
  printf '#!/usr/bin/env bash\nexit 3\n' > "$SB_TMP/gate-exit-3"; chmod +x "$SB_TMP/gate-exit-3"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$SB_TMP/gate-exit-1"; chmod +x "$SB_TMP/gate-exit-1"

  out="$( cd "$SB_WORK" && FINISH_PR_TEST_ALLOW_STUB=1 FINISH_PR_VERIFY_CMD=true FINISH_PR_PREMERGE_CMD="$SB_TMP/gate-exit-3" \
            "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-785" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(3) a pre-merge gate that could not run did not refuse the landing: $out"
  printf '%s\n' "$out" | grep 'pre-merge gate COULD NOT RUN' >/dev/null \
    || cf "(3) the refusal does not say the gate COULD NOT RUN: $(printf '%s' "$out" | grep -i 'pre-merge' | tr '\n' '|')"
  printf '%s\n' "$out" | grep 'pre-merge gate FAILED' >/dev/null \
    && cf "(3) a gate that never executed was reported as FAILED"
  assert_landing_untouched "(3)" "$SB_PREFIX-785" sandbox "feature/$SB_PREFIX-785-work" CHANGE.txt

  # CONTROL: a failing gate is still FAILED.
  out="$( cd "$SB_WORK" && FINISH_PR_TEST_ALLOW_STUB=1 FINISH_PR_VERIFY_CMD=true FINISH_PR_PREMERGE_CMD="$SB_TMP/gate-exit-1" \
            "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-785" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(1) a failing pre-merge gate did not refuse the landing: $out"
  printf '%s\n' "$out" | grep 'pre-merge gate FAILED' >/dev/null \
    || cf "(control) a failing pre-merge gate is no longer reported as FAILED: $(printf '%s' "$out" | grep -i 'pre-merge' | tr '\n' '|')"
  assert_landing_untouched "(1)" "$SB_PREFIX-785" sandbox "feature/$SB_PREFIX-785-work" CHANGE.txt

  finish "finish-pr.sh: a pre-merge gate that exits 3 (could not run) refuses naming COULD NOT RUN, never FAILED; exit 1 is still FAILED; neither lands anything"
  teardown
}

# =============================================================================
# CASE — a pre-merge gate that REFUSED TO RUN (verify.sh exit 2: the runner itself never
#        started — an empty/malformed GATES table, an unknown argument, or a narrowed run's
#        own precondition) is named apart from a FAILED gate (exit 1), not folded into it.
#
# Before this case, finish-pr.sh's pre-merge block special-cased only exit 3; exit 2 fell into
# the same "FAILED — fix the branch" branch as an actual measured red, telling the reader to
# fix branch content when nothing about the branch was ever measured.
# =============================================================================
case_finish_pr_premerge_names_a_refused_gate() {
  cf_reset
  local out rc
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-786" sandbox chore "Pre-merge refused" "feature/$SB_PREFIX-786-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-786" work CHANGE.txt
  printf '#!/usr/bin/env bash\nexit 2\n' > "$SB_TMP/gate-exit-2"; chmod +x "$SB_TMP/gate-exit-2"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$SB_TMP/gate-exit-1b"; chmod +x "$SB_TMP/gate-exit-1b"

  out="$( cd "$SB_WORK" && FINISH_PR_TEST_ALLOW_STUB=1 FINISH_PR_VERIFY_CMD=true FINISH_PR_PREMERGE_CMD="$SB_TMP/gate-exit-2" \
            "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-786" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(2) a pre-merge gate that refused to run did not refuse the landing: $out"
  printf '%s\n' "$out" | grep 'pre-merge gate REFUSED TO RUN' >/dev/null \
    || cf "(2) the refusal does not say the gate REFUSED TO RUN: $(printf '%s' "$out" | grep -i 'pre-merge' | tr '\n' '|')"
  printf '%s\n' "$out" | grep 'pre-merge gate FAILED' >/dev/null \
    && cf "(2) a gate that refused to run was reported as FAILED"
  printf '%s\n' "$out" | grep 'Fix the branch' >/dev/null \
    && cf "(2) a gate that refused to run told the reader to fix the branch, not the gate's own configuration"
  assert_landing_untouched "(2)" "$SB_PREFIX-786" sandbox "feature/$SB_PREFIX-786-work" CHANGE.txt

  # CONTROL: a failing gate (exit 1) is still FAILED, telling the reader to fix the branch.
  out="$( cd "$SB_WORK" && FINISH_PR_TEST_ALLOW_STUB=1 FINISH_PR_VERIFY_CMD=true FINISH_PR_PREMERGE_CMD="$SB_TMP/gate-exit-1b" \
            "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-786" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(control) a failing pre-merge gate did not refuse the landing: $out"
  printf '%s\n' "$out" | grep 'pre-merge gate FAILED' >/dev/null \
    || cf "(control) a failing pre-merge gate is no longer reported as FAILED: $(printf '%s' "$out" | grep -i 'pre-merge' | tr '\n' '|')"
  assert_landing_untouched "(control)" "$SB_PREFIX-786" sandbox "feature/$SB_PREFIX-786-work" CHANGE.txt

  finish "finish-pr.sh: a pre-merge gate that exits 2 (refused to run) refuses naming REFUSED TO RUN and points at the gate's configuration, never 'fix the branch'; exit 1 is still FAILED; neither lands anything"
  teardown
}

# =============================================================================
# CASE — an EMPTY merge aborts, before any branch deletion or advance.
# =============================================================================
case_finish_pr_empty_merge() {
  cf_reset
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-782" sandbox chore "Empty merge" "feature/$SB_PREFIX-782-empty"
  publish_sandbox
  git -C "$SB_WORK" branch "feature/$SB_PREFIX-782-empty" "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/$SB_PREFIX-782-empty" --quiet >/dev/null 2>&1

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-782" 2>&1 )"; rc=$?

  [ "$rc" -ne 0 ] || cf "expected nonzero exit on an empty merge, got 0: $out"
  # NO MERGE MARKER: this branch is created off the trunk with no commit, so nothing could have
  # merged and asserting otherwise would be a check that cannot fail.
  assert_landing_untouched "(empty merge)" "$SB_PREFIX-782" sandbox \
    "feature/$SB_PREFIX-782-empty"

  finish "finish-pr.sh empty-merge aborts (no branch destruction, no advance)"
  teardown
}

# =============================================================================
# CASE — THE LANDING GATE MUST BE THE COMMITTED verify.sh AT THE REVISION BEING
# LANDED — AND THIS CASE RUNS WITHOUT THE STUB MARKER.
#
# The revision check is wrapped in `if [ "$ALLOW_STUB" != "true" ]`, so every case that runs
# with `FPR_STUB` bypasses it. Running unmarked is the whole design of this case.
#
# On the default path the gate checkout is the main checkout, usually on the trunk, so the
# gate must refuse unless it is the branch's committed, unmodified verify.sh. The arms are
# labelled `# --- (n)` in the body; the conforming one stops the fix from being an
# unconditional refusal:
#   (i)   checkout on the trunk, branch elsewhere → REFUSE, naming the mismatch, and
#         leave the branch and the issue exactly where they were;
#   (ii)  checkout ON the branch but verify.sh locally modified → REFUSE, naming the
#         modification (the revisions match, so only the cleanliness arm can catch it);
#   (iv)  the gate present, executable and at the right revision, but UNTRACKED → REFUSE;
#   (iii) checkout on the branch, gate committed and unmodified → LANDS.
# =============================================================================
case_finish_pr_gate_revision() {
  cf_reset
  local out rc br

  # --- (i) the default path from a trunk checkout: the revision mismatch ------
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-780" revmm chore "Revision mismatch" "feature/$SB_PREFIX-780-revmm"
  publish_sandbox
  seed_branch "$SB_PREFIX-780" revmm CHANGE780.txt      # leaves the checkout on the trunk
  br="feature/$SB_PREFIX-780-revmm"
  [ "$(git -C "$SB_WORK" symbolic-ref --short HEAD)" = "$SB_TRUNK" ] \
    || cf "(control) the checkout is not on the trunk, so (i) is not testing the mismatch"

  # NO FPR_STUB. Deliberately.
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-780" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(i) finish-pr LANDED from a trunk checkout with the branch elsewhere — the gate ran against a tree that is not shipping: $out"
  printf '%s\n' "$out" | grep -i 'NOT AT THE REVISION BEING LANDED' >/dev/null \
    || cf "(i) the refusal does not name the revision mismatch as the cause: $out"
  printf '%s\n' "$out" | grep -i 'Refusing BEFORE any destructive step' >/dev/null \
    || cf "(i) the refusal does not state that it refused before anything destructive: $out"
  # REFUSED MEANS NOTHING HAPPENED — the assertions that separate "refused" from
  # "refused after doing some of it". Exit code alone cannot tell those apart.
  git -C "$SB_WORK" rev-parse --verify --quiet "refs/heads/$br" >/dev/null 2>&1 \
    || cf "(i) the local branch was deleted during a refusal"
  [ -n "$(git -C "$SB_WORK" ls-remote --heads origin "$br" 2>/dev/null)" ] \
    || cf "(i) the remote branch was deleted during a refusal"
  origin_has_path "progress/dev_complete/$SB_PREFIX-780-revmm.md" \
    || cf "(i) the issue left dev_complete/ on the trunk during a refusal"
  origin_has_path "CHANGE780.txt" \
    && cf "(i) the branch's change reached the trunk during a refusal — it squash-merged"
  teardown

  # --- (ii) on the branch, but the gate is locally modified ------------------
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-781" dirtygate chore "Dirty gate" "feature/$SB_PREFIX-781-dirtygate"
  publish_sandbox
  seed_branch "$SB_PREFIX-781" dirtygate CHANGE781.txt
  br="feature/$SB_PREFIX-781-dirtygate"
  git -C "$SB_WORK" checkout "$br" --quiet >/dev/null 2>&1 \
    || cf "(control) could not check out $br for (ii)"
  printf '\n# a local edit that was never committed\n' >> "$SB_WORK/scripts/verify.sh"
  git -C "$SB_WORK" diff --quiet HEAD -- scripts/verify.sh \
    && cf "(control) scripts/verify.sh is NOT locally modified, so (ii) tests nothing"

  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-781" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(ii) finish-pr LANDED with a locally-modified gate — the gate that ran is not the one that ships: $out"
  printf '%s\n' "$out" | grep -i 'LOCALLY MODIFIED' >/dev/null \
    || cf "(ii) the refusal does not name the modification as the cause (the revisions MATCH here, so only the cleanliness arm can catch it): $out"
  git -C "$SB_WORK" rev-parse --verify --quiet "refs/heads/$br" >/dev/null 2>&1 \
    || cf "(ii) the local branch was deleted during a refusal"
  origin_has_path "progress/dev_complete/$SB_PREFIX-781-dirtygate.md" \
    || cf "(ii) the issue left dev_complete/ during a refusal"
  teardown

  # --- (iv) on the branch, at the right revision, gate present and executable,
  #          but UNTRACKED at that revision ----------------------------------
  #
  # A verify.sh that exists, runs and sits at the right revision but ships in no commit
  # passes every other arm. `git rm --cached` removes it from the INDEX and leaves it on
  # disk, executable and unmodified; committing that on the branch keeps HEAD and the
  # branch tip in agreement, so the revision arm cannot fire.
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-783" untracked chore "Untracked gate" "feature/$SB_PREFIX-783-untracked"
  publish_sandbox
  seed_branch "$SB_PREFIX-783" untracked CHANGE783.txt
  br="feature/$SB_PREFIX-783-untracked"
  git -C "$SB_WORK" checkout "$br" --quiet >/dev/null 2>&1 \
    || cf "(control) could not check out $br for (iv)"
  git -C "$SB_WORK" rm --cached --quiet scripts/verify.sh >/dev/null 2>&1 \
    || cf "(control) could not un-track scripts/verify.sh for (iv)"
  sbcommit -q -m "un-track the gate" >/dev/null 2>&1

  # ── THE FIXTURE IS PROVEN TO ISOLATE THIS ARM: the arms share a refusal prefix and an
  #    exit code, so a fixture that trips a neighbour looks identical from outside.
  [ -e "$SB_WORK/scripts/verify.sh" ] \
    || cf "(control iv) verify.sh is absent — this would trip the MISSING arm, not the tracked-ness one"
  [ -x "$SB_WORK/scripts/verify.sh" ] \
    || cf "(control iv) verify.sh is not executable — this would trip the NOT EXECUTABLE arm"
  [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$(git -C "$SB_WORK" rev-parse "refs/heads/$br")" ] \
    || cf "(control iv) HEAD and the branch tip disagree — this would trip the REVISION arm"
  git -C "$SB_WORK" cat-file -e "HEAD:scripts/verify.sh" 2>/dev/null \
    && cf "(control iv) scripts/verify.sh IS tracked at HEAD — the un-tracking did not take and this leg tests nothing"

  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-783" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] \
    || cf "(iv) finish-pr LANDED with an UNTRACKED gate — it ran a file that ships in no commit: $out"
  printf '%s\n' "$out" | grep -i 'NOT TRACKED' >/dev/null \
    || cf "(iv) the refusal does not name tracked-ness as the cause: $out"
  # …AND NOT ITS NEIGHBOURS. The exit code and the prefix cannot tell these apart.
  printf '%s\n' "$out" | grep -i 'NOT AT THE REVISION BEING LANDED' >/dev/null \
    && cf "(iv) the refusal blames the REVISION arm — the fixture reached a neighbour, so this leg is coverage of an arm it never touched"
  printf '%s\n' "$out" | grep -i 'LOCALLY MODIFIED' >/dev/null \
    && cf "(iv) the refusal blames the MODIFICATION arm — the fixture reached a neighbour"
  printf '%s\n' "$out" | grep -iE 'MISSING —|NOT EXECUTABLE' >/dev/null \
    && cf "(iv) the refusal blames one of the two absent-gate arms — the fixture reached a neighbour"
  # REFUSED MEANS NOTHING HAPPENED.
  git -C "$SB_WORK" rev-parse --verify --quiet "refs/heads/$br" >/dev/null 2>&1 \
    || cf "(iv) the local branch was deleted during a refusal"
  origin_has_path "progress/dev_complete/$SB_PREFIX-783-untracked.md" \
    || cf "(iv) the issue left dev_complete/ during a refusal"
  origin_has_path "CHANGE783.txt" \
    && cf "(iv) the branch's change reached the trunk during a refusal"
  teardown

  # --- (iii) the conforming posture still lands, unmarked --------------------
  # Without this, an unconditional refusal passes (i) and (ii) and breaks the kit.
  # Note there is no stub here either: the REAL scripts/verify.sh --quick runs, and
  # it is green because make_sandbox declared a green `select` gate in it.
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-782" conform chore "Conforming" "feature/$SB_PREFIX-782-conform"
  publish_sandbox
  seed_branch "$SB_PREFIX-782" conform CHANGE782.txt
  br="feature/$SB_PREFIX-782-conform"
  git -C "$SB_WORK" checkout "$br" --quiet >/dev/null 2>&1 \
    || cf "(control) could not check out $br for (iii)"
  [ -z "$(git -C "$SB_WORK" status --porcelain -- scripts/verify.sh)" ] \
    || cf "(control) scripts/verify.sh is dirty in (iii), which would make it test (ii) again"

  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-782" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] \
    || cf "(iii) the CONFORMING posture was refused, unmarked — the revision check is unconditional and no landing can pass it: $out"
  origin_has_path "progress/qa_complete/$SB_PREFIX-782-conform.md" \
    || cf "(iii) the conforming landing did not advance the issue: $out"
  origin_has_path "CHANGE782.txt" || cf "(iii) the conforming landing did not squash-merge the change: $out"

  finish "finish-pr landing gate, run WITHOUT the stub marker: a trunk checkout with the branch elsewhere REFUSES on the revision mismatch, a locally-modified gate REFUSES on the modification, a gate that is present, executable and at the right revision but UNTRACKED there REFUSES on tracked-ness and on nothing else, all three leaving the branch and the issue untouched — and the conforming posture still lands"
  teardown
}

# =============================================================================
# CASE — THE TRUNK'S verify.sh JUDGES THE BRANCH. Unmarked, like the case above.
#
# A branch that added what the trunk's gate refuses AND deleted that gate from its own verify.sh
# would otherwise land green, and its weakened runner would become the trunk's.
#   (a) such a branch is REFUSED, the trunk's runner named, and nothing lands or is left behind;
#   (b) a branch that changes verify.sh and passes the trunk's runner LANDS, and its copy is then
#       the trunk's (it governs the next landing).
# =============================================================================
case_finish_pr_trunk_gate_judges_the_branch() {
  cf_reset
  local out rc br row
  for row in a b; do
    make_sandbox
    printf '#!/usr/bin/env bash\n[ ! -e BAD ] || { echo "strict: BAD present"; exit 1; }\n' > "$SB_WORK/strict-gate"
    chmod +x "$SB_WORK/strict-gate"
    _declare_gate 'strict|core|./strict-gate'
    seed_issue dev_complete "$SB_PREFIX-790" judge chore "Trunk gate judges" "feature/$SB_PREFIX-790-judge"
    publish_sandbox
    br="feature/$SB_PREFIX-790-judge"
    git -C "$SB_WORK" branch "$br" "$SB_TRUNK" >/dev/null 2>&1 && git -C "$SB_WORK" checkout -q "$br" >/dev/null 2>&1 \
      || _fixture_die "case_finish_pr_trunk_gate_judges_the_branch: could not branch."
    if [ "$row" = a ]; then
      : > "$SB_WORK/BAD"
      perl -i -ne 'print unless /"strict\|core\|/' "$SB_WORK/scripts/verify.sh"
    else
      printf '\n# the branch changes its gate runner\n' >> "$SB_WORK/scripts/verify.sh"
    fi
    git -C "$SB_WORK" add -A >/dev/null 2>&1 && sbcommit -q -m "[Dev] $SB_PREFIX-790: change the gate" >/dev/null 2>&1 \
      && git -C "$SB_WORK" push -q -u origin "$br" >/dev/null 2>&1 \
      || _fixture_die "case_finish_pr_trunk_gate_judges_the_branch: could not commit and push row $row."
    ( cd "$SB_WORK" && ./scripts/verify.sh --quick >/dev/null 2>&1 ) \
      || _fixture_die "case_finish_pr_trunk_gate_judges_the_branch: row $row's own runner is not green, so the row tests nothing."

    # NO FPR_STUB. Deliberately.
    out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-790" 2>&1 )"; rc=$?
    printf '%s\n' "$out" | grep -F "changes scripts/verify.sh, so $SB_TRUNK's copy judges it" >/dev/null \
      || cf "($row) the run does not say the trunk's runner judged the branch"
    printf '%s\n' "$out" | grep -F "Pre-merge gate (blocking): $SB_TRUNK's scripts/verify.sh" >/dev/null \
      || cf "($row) the pre-merge banner does not name the runner that ran: $(printf '%s\n' "$out" | grep -F 'Pre-merge gate')"
    ls "$SB_WORK"/scripts/.verify-trunk.* >/dev/null 2>&1 && cf "($row) the trunk's runner was left in scripts/"
    if [ "$row" = a ]; then
      [ "$rc" -ne 0 ] || cf "(a) a branch that deleted the gate it fails LANDED"
      origin_has_path "BAD" && cf "(a) what the trunk's gate refuses reached the trunk"
      origin_has_path "progress/dev_complete/$SB_PREFIX-790-judge.md" || cf "(a) the issue left dev_complete/ during a refusal"
    else
      [ "$rc" -eq 0 ] || cf "(b) a branch that changes verify.sh and passes the trunk's runner did not land (exit $rc): $(printf '%s' "$out" | tail -5 | tr '\n' '|')"
      origin_file_contains "scripts/verify.sh" "the branch changes its gate runner" \
        || cf "(b) the landed trunk does not carry the branch's verify.sh, so it cannot govern the next landing"
    fi
    teardown
  done
  finish "finish-pr.sh: the trunk's verify.sh judges a branch that changes it — a weakened gate is refused, a legitimate change lands and governs the next landing"
}

# CASE — a MISSING or NOT EXECUTABLE gate refuses and says how to WRITE one. The other
# provenance arms mean "your gate is the wrong one", and their remedy is a checkout; these
# two mean "there is no gate", and the checkout advice would send the adopter to fix the
# wrong thing.
case_finish_pr_gate_absent_says_write_one() {
  cf_reset
  local out rc br

  # --- (a) verify.sh MISSING from the gate checkout ---------------------------
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-795" nogate chore "No gate at all" "feature/$SB_PREFIX-795-nogate"
  publish_sandbox
  seed_branch "$SB_PREFIX-795" nogate CHANGE795.txt
  br="feature/$SB_PREFIX-795-nogate"
  git -C "$SB_WORK" checkout "$br" --quiet >/dev/null 2>&1
  rm -f "$SB_WORK/scripts/verify.sh"
  [ ! -e "$SB_WORK/scripts/verify.sh" ] \
    || cf "(control) scripts/verify.sh still exists, so (a) is not testing a MISSING gate"

  # NO FPR_STUB: the provenance block only runs unmarked.
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-795" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) finish-pr LANDED with no gate runner at all: $out"
  printf '%s\n' "$out" | grep -i 'MISSING' >/dev/null \
    || cf "(a) the refusal does not name the gate as MISSING: $out"
  printf '%s\n' "$out" | grep -F -- '--gate-command' >/dev/null \
    || cf "(a) the refusal does not tell an adopter with NO gate how to get one: $out"
  printf '%s\n' "$out" | grep -i 'check the branch out here' >/dev/null \
    && cf "(a) the refusal offers the CHECKOUT remedy to someone who has no gate at all — that is the other arms' advice and it sends them to fix the wrong thing: $out"
  assert_landing_untouched "(a)" "$SB_PREFIX-795" nogate "$br" CHANGE795.txt
  teardown

  # --- (b) verify.sh present but NOT EXECUTABLE -------------------------------
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-796" noexec chore "Gate not executable" "feature/$SB_PREFIX-796-noexec"
  publish_sandbox
  seed_branch "$SB_PREFIX-796" noexec CHANGE796.txt
  br="feature/$SB_PREFIX-796-noexec"
  git -C "$SB_WORK" checkout "$br" --quiet >/dev/null 2>&1
  chmod -x "$SB_WORK/scripts/verify.sh"
  [ ! -x "$SB_WORK/scripts/verify.sh" ] && [ -e "$SB_WORK/scripts/verify.sh" ] \
    || cf "(control) scripts/verify.sh is not in the present-but-unexecutable state (b) needs"

  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-796" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) finish-pr LANDED with a non-executable gate runner: $out"
  printf '%s\n' "$out" | grep -i 'NOT EXECUTABLE' >/dev/null \
    || cf "(b) the refusal does not name the gate as NOT EXECUTABLE: $out"
  printf '%s\n' "$out" | grep -F -- '--gate-command' >/dev/null \
    || cf "(b) the refusal does not carry the write-your-gate advice: $out"
  assert_landing_untouched "(b)" "$SB_PREFIX-796" noexec "$br" CHANGE796.txt

  finish "finish-pr: a MISSING or NON-EXECUTABLE gate refuses before anything destructive and tells an adopter how to GET a gate, not how to move their checkout"
  teardown
}

# =============================================================================
# CASE — --worktree NAMED THROUGH A SYMLINK IS THE SAME CHECKOUT.
#
# The --worktree check must resolve both paths the same way: a logical `pwd` keeps a symlink
# that git's physical resolution drops, and a genuine worktree of this repo is then refused
# as "not a git worktree of THIS repo". On macOS the temp dir itself is such a spelling. The
# link is built here, so the case does not depend on the platform providing one.
#   (a) the main checkout, named through a symlink — accepted, and it lands;
#   (b) CONTROL: a foreign repository — still refused;
#   (c) CONTROL: a symlink to the foreign repository — still refused: resolving the link
#       must not make everything look like this repo.
# =============================================================================
case_finish_pr_worktree_through_a_symlink() {
  cf_reset
  local out rc br
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-786" sandbox chore "Worktree via symlink" "feature/$SB_PREFIX-786-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-786" work CHANGE786.txt
  br="feature/$SB_PREFIX-786-work"
  git -C "$SB_WORK" checkout -q "$br" >/dev/null 2>&1
  ln -s "$SB_WORK" "$SB_TMP/link-to-work"
  [ -L "$SB_TMP/link-to-work" ] || _control_did_not_run "build the symlink"

  # (b) + (c) first, before anything lands
  git init -q "$SB_TMP/foreign" >/dev/null 2>&1
  mkdir -p "$SB_TMP/foreign/scripts" && cp "$SB_WORK/scripts/verify.sh" "$SB_TMP/foreign/scripts/verify.sh"
  git -C "$SB_TMP/foreign" add -A >/dev/null 2>&1
  git -C "$SB_TMP/foreign" -c user.email=t@t -c user.name=t commit -qm foreign --no-verify >/dev/null 2>&1
  ln -s "$SB_TMP/foreign" "$SB_TMP/link-to-foreign"
  local f
  for f in "$SB_TMP/foreign" "$SB_TMP/link-to-foreign"; do
    rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-786" --worktree "$f" 2>&1 )" || rc=$?
    [ "$rc" -ne 0 ] || cf "(control) --worktree '$f', a FOREIGN repository, was accepted"
    printf '%s\n' "$out" | grep 'not a git worktree of THIS repo' >/dev/null \
      || cf "(control) --worktree '$f' was not refused as a foreign repository: $(printf '%s' "$out" | tail -3 | tr '\n' '|')"
  done
  assert_landing_untouched "(control)" "$SB_PREFIX-786" sandbox "$br" CHANGE786.txt

  # (a) the main checkout through the symlink
  rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-786" --worktree "$SB_TMP/link-to-work" 2>&1 )" || rc=$?
  printf '%s\n' "$out" | grep 'not a git worktree of THIS repo' >/dev/null \
    && cf "(a) --worktree named the main checkout through a symlink and was refused as foreign: $(printf '%s' "$out" | grep 'not a git worktree')"
  [ "$rc" -eq 0 ] || cf "(a) the landing through the symlinked --worktree exited $rc: $(printf '%s' "$out" | tail -6 | tr '\n' '|')"
  origin_has_path "CHANGE786.txt" || cf "(a) the change did not reach the trunk"

  finish "finish-pr --worktree: the main checkout named through a symlink is the same checkout and lands (a); a foreign repository is still refused, named directly (b) or through a symlink (c)"
  teardown
}

# =============================================================================
# CASE — A RELATIVE --worktree READS THE SAME GATE AFTER THE MERGE AS BEFORE IT.
#
# The post-merge reading runs the gate from inside the gate checkout. A relative --worktree
# spelled from the caller's directory names nothing from there, and a green trunk would be
# reported as POST_MERGE_GATE: FAIL. `../x/wt` is the shape that shows it: `../wt` resolves to
# itself from inside wt, by coincidence.
# =============================================================================
case_finish_pr_relative_worktree() {
  cf_reset
  local out rc br
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-787" sandbox chore "Relative worktree" "feature/$SB_PREFIX-787-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-787" work CHANGE787.txt
  br="feature/$SB_PREFIX-787-work"
  mkdir -p "$SB_TMP/x"
  git -C "$SB_WORK" worktree add "$SB_TMP/x/wt" "$br" --quiet >/dev/null 2>&1 \
    || _fixture_die "case_finish_pr_relative_worktree: could not create the gate worktree."
  rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-787" --worktree ../x/wt 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "the landing with --worktree ../x/wt exited $rc: $(printf '%s' "$out" | tail -6 | tr '\n' '|')"
  origin_has_path "CHANGE787.txt" || cf "the change did not reach the trunk"
  printf '%s\n' "$out" | grep -x 'POST_MERGE_GATE: PASS' >/dev/null \
    || cf "a green trunk read through a relative --worktree was not POST_MERGE_GATE: PASS: $(printf '%s\n' "$out" | grep -E 'POST_MERGE_GATE|post-merge|No such file' | tr '\n' '|')"
  finish "finish-pr --worktree given as a relative path: the landing completes and the post-merge gate reads PASS on a green trunk"
  teardown
}

case_finish_pr_runs_only_the_trunks_copy() {
  cf_reset
  local out rc br wt
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-784" lander chore "Branch changes the lander" "feature/$SB_PREFIX-784-lander"
  publish_sandbox
  seed_branch "$SB_PREFIX-784" lander CHANGE784.txt
  br="feature/$SB_PREFIX-784-lander"
  git -C "$SB_WORK" checkout -q "$br" >/dev/null 2>&1 \
    && printf '\n# the branch changes the script that lands it\n' >> "$SB_WORK/scripts/finish-pr.sh" \
    && git -C "$SB_WORK" add scripts/finish-pr.sh >/dev/null 2>&1 \
    && sbcommit -q -m "[Dev] $SB_PREFIX-784: change the lander" >/dev/null 2>&1 \
    && git -C "$SB_WORK" push -q origin "$br" >/dev/null 2>&1 \
    && git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1 \
    || _fixture_die "case_finish_pr_runs_only_the_trunks_copy: could not change finish-pr.sh on the branch."
  wt="$SB_TMP/wt784"
  git -C "$SB_WORK" worktree add "$wt" "$br" --quiet >/dev/null 2>&1 \
    || _fixture_die "case_finish_pr_runs_only_the_trunks_copy: could not create the branch's worktree."

  # (a) the branch's own copy, run from the branch's checkout: refused before anything moves.
  rc=0; out="$( cd "$wt" && "$wt/scripts/finish-pr.sh" "$SB_PREFIX-784" --worktree "$wt" 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(a) the branch's own finish-pr.sh landed the branch that changes it"
  printf '%s\n' "$out" | grep -F "is not $SB_TRUNK's committed copy" >/dev/null \
    || cf "(a) the refusal does not say this copy is not the trunk's: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  origin_has_path "CHANGE784.txt" && cf "(a) the branch reached the trunk during a refusal"
  origin_has_path "progress/dev_complete/$SB_PREFIX-784-lander.md" || cf "(a) the issue left dev_complete/ during a refusal"

  # (b) the trunk's copy, from the main checkout, gating the branch's worktree: it lands, and the
  #     branch's finish-pr.sh reaches the trunk to govern the next landing.
  rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-784" --worktree "$wt" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(b) the trunk's copy did not land a branch that changes finish-pr.sh (exit $rc): $(printf '%s' "$out" | tail -5 | tr '\n' '|')"
  origin_file_contains "scripts/finish-pr.sh" "the branch changes the script that lands it" \
    || cf "(b) the landed trunk does not carry the branch's finish-pr.sh"
  finish "finish-pr.sh runs only as the trunk's committed copy: the branch's own copy is refused, the trunk's lands the change"
  teardown
}

# =============================================================================
# THE REFUSAL'S "DROP THEM" ROUTE WORKS, OR IT IS NOT PRINTED. The three tools that refuse a copy that
# is not the trunk's name the uncommitted edits and the command that drops them. `git checkout --`
# restores from the index, so a STAGED edit survived it and the refusal repeated: the route is run
# here exactly as printed. A held file that is untracked is not an edit `git checkout` can restore, so
# it is not named in the hint.
# =============================================================================
case_lander_refusal_drop_route_clears_a_staged_edit() {
  cf_reset
  local out rc s cmd line args
  make_sandbox
  publish_sandbox
  for s in finish-pr move-issue subtask; do
    case "$s" in
      finish-pr)  args="$SB_PREFIX-785" ;;
      move-issue) args="$SB_PREFIX-785 in_progress --role Dev" ;;
      subtask)    args="move $SB_PREFIX-785-s1 qa_complete" ;;
    esac
    # (a) a staged edit: the printed drop route, run as printed, clears the refusal.
    printf '\n# a staged local edit\n' >> "$SB_WORK/scripts/$s.sh" \
      && git -C "$SB_WORK" add "scripts/$s.sh" >/dev/null 2>&1 \
      || _fixture_die "case_lander_refusal_drop_route_clears_a_staged_edit: could not stage an edit to $s.sh."
    rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/$s.sh" $args 2>&1 )" || rc=$?
    printf '%s\n' "$out" | grep -F "committed copy" >/dev/null \
      || cf "(a) $s.sh: the staged edit was not refused as a changed tool: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
    line="$(printf '%s\n' "$out" | grep -F 'to drop them, ' | head -1)"
    cmd="${line#*to drop them, }"
    [ -n "$line" ] && [ "$cmd" != "$line" ] || cf "(a) $s.sh: the refusal prints no drop route for a staged edit"
    case "$cmd" in "git checkout "*) ;; *) cf "(a) $s.sh: the drop route is not a git checkout: $cmd" ;; esac
    ( cd "$SB_WORK" && eval "$cmd" ) >/dev/null 2>&1 || cf "(a) $s.sh: the printed drop route failed: $cmd"
    out="$( cd "$SB_WORK" && "$SB_WORK/scripts/$s.sh" $args 2>&1 )" || true
    printf '%s\n' "$out" | grep -F "committed copy" >/dev/null \
      && cf "(a) $s.sh: after the printed drop route the refusal repeats: $(printf '%s' "$out" | grep -F 'to drop them' | head -1)"
  done
  # (b) a held file that is untracked, beside a staged edit: only the edit is named.
  git -C "$SB_WORK" rm -q --cached scripts/lib/usage.sh >/dev/null 2>&1 \
    && sbcommit -q -m "[PM] $SB_PREFIX-785: usage.sh leaves the trunk" >/dev/null 2>&1 \
    && git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 \
    || _fixture_die "case_lander_refusal_drop_route_clears_a_staged_edit: could not make lib/usage.sh untracked."
  [ -e "$SB_WORK/scripts/lib/usage.sh" ] || _fixture_die "case_lander_refusal_drop_route_clears_a_staged_edit: lib/usage.sh left the disk."
  for s in finish-pr move-issue subtask; do
    case "$s" in
      finish-pr)  args="$SB_PREFIX-785" ;;
      move-issue) args="$SB_PREFIX-785 in_progress --role Dev" ;;
      subtask)    args="move $SB_PREFIX-785-s1 qa_complete" ;;
    esac
    printf '\n# a staged local edit\n' >> "$SB_WORK/scripts/$s.sh" \
      && git -C "$SB_WORK" add "scripts/$s.sh" >/dev/null 2>&1 \
      || _fixture_die "case_lander_refusal_drop_route_clears_a_staged_edit: could not stage an edit to $s.sh (b)."
    out="$( cd "$SB_WORK" && "$SB_WORK/scripts/$s.sh" $args 2>&1 )" || true
    line="$(printf '%s\n' "$out" | grep -F 'Uncommitted edits here (' | head -1)"
    printf '%s\n' "$line" | grep -F "scripts/$s.sh" >/dev/null || cf "(b) $s.sh: the staged edit is not named: $line"
    printf '%s\n' "$line" | grep -F 'lib/usage.sh' >/dev/null && cf "(b) $s.sh: the untracked lib/usage.sh is named, and git checkout cannot restore it: $line"
    git -C "$SB_WORK" checkout HEAD -- "scripts/$s.sh" >/dev/null 2>&1
  done
  finish "the lander refusal's drop route clears a staged edit when run as printed, and names no untracked held file"
  teardown
}

# =============================================================================
# THE LANDING TOOL IS THE TRUNK'S COMMITTED COPY, LIBRARIES INCLUDED. A branch, or a local edit,
# that rewrites a library finish-pr.sh sources judges its own landing, so the comparison against
# the trunk runs before any library is sourced and covers every file the tool runs.
#
# The sandbox card carries a FAIL_AC row, so the true answer to every landing below is a refusal
# on that row. A tool that lands it has been rewritten.
# =============================================================================

# _held_fpr_setup <n> — card <PREFIX>-<n> in dev_complete/ with a FAIL_AC row, its branch pushed
# and checked out at $SB_TMP/wt. Sets HELD_ID and HELD_WT.
_held_fpr_setup() {
  local n="$1" f br
  make_sandbox
  HELD_ID="$SB_PREFIX-$n"; HELD_WT="$SB_TMP/wt"
  seed_issue dev_complete "$HELD_ID" held chore "The landing tool under test" "feature/$HELD_ID-work"
  f="$SB_WORK/progress/dev_complete/$HELD_ID-held.md"
  perl -i -pe 's/^(\| AC1 \| )PASS( \| test \|.*\|)$/${1}FAIL_AC${2}/' "$f"
  grep -qF 'FAIL_AC' "$f" || _fixture_die "_held_fpr_setup: the FAIL_AC row was not planted"
  publish_sandbox
  seed_branch "$HELD_ID" work "CHANGE$n.txt"
  br="feature/$HELD_ID-work"
  git -C "$SB_WORK" worktree add "$HELD_WT" "$br" --quiet >/dev/null 2>&1 \
    || _fixture_die "_held_fpr_setup: could not create the branch's worktree."
}

# _held_edit <file under scripts/> <line> [commit] — append a line to the branch checkout's copy;
# with a third argument, commit and push it on the branch as well.
_held_edit() {
  local rel="$1" line="$2"
  printf '\n%s\n' "$line" >> "$HELD_WT/scripts/$rel"
  bash -n "$HELD_WT/scripts/$rel" || _fixture_die "_held_edit: $rel no longer parses after the plant"
  if [ -n "${3:-}" ]; then
    git -C "$HELD_WT" add "scripts/$rel" >/dev/null 2>&1
    MSG_OK=1 git -C "$HELD_WT" commit -q -m "[Dev] $HELD_ID: change $rel" >/dev/null 2>&1 \
      && git -C "$HELD_WT" push -q origin HEAD >/dev/null 2>&1 \
      || _fixture_die "_held_edit: could not commit $rel on the branch"
  fi
}

# _held_land <dir> — finish-pr.sh as that checkout's own copy, gating that checkout. Sets out, rc.
_held_land() {
  rc=0; out="$( cd "$1" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec" "$1/scripts/finish-pr.sh" "$HELD_ID" --worktree "$1" 2>&1 )" || rc=$?
}

# _held_refused <label> <expected file> — the assertions every refused landing shares.
_held_refused() {
  local lab="$1" file="$2"
  [ "$rc" -eq 1 ] || cf "$lab exit $rc, expected 1: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  printf '%s\n' "$out" | grep -F "is not $SB_TRUNK's committed copy" >/dev/null \
    || cf "$lab the refusal does not say the tool is not the trunk's copy: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  printf '%s\n' "$out" | grep -F "$file" >/dev/null || cf "$lab the refusal does not name $file"
  printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "$lab the refusal names no next action"
  assert_landing_untouched "$lab" "$HELD_ID" held "feature/$HELD_ID-work" "CHANGE${HELD_ID##*-}.txt"
}

case_finish_pr_control_fail_row_refuses_on_an_unchanged_tool() {
  cf_reset
  local out rc
  _held_fpr_setup 804
  _held_land "$HELD_WT"
  [ "$rc" -ne 0 ] || cf "(control) a FAIL row on an unchanged tool — finish-pr.sh exited 0"
  if printf '%s\n' "$out" | grep -F "is not $SB_TRUNK's committed copy" >/dev/null; then
    cf "(control) an unchanged tool was refused as not the trunk's copy"
  fi
  grep -q 'refusal=qa-verdict-fail' "$SB_TMP/rec"/*.tsv 2>/dev/null \
    || cf "(control) the FAIL row was not what refused: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  finish "finish-pr.sh from the branch's checkout, nothing changed: the FAIL row refuses the landing (the control the next rows measure against)"
  teardown
}

case_finish_pr_refuses_a_library_gutted_on_the_branch() {
  cf_reset
  local out rc
  _held_fpr_setup 805
  _held_edit lib/qa-gate.sh 'kit_qa_verdict_check() { :; }' commit
  _held_land "$HELD_WT"
  _held_refused "(committed gut)" lib/qa-gate.sh
  finish "finish-pr.sh refuses to land from a checkout whose lib/qa-gate.sh the branch gutted, naming the file, with nothing landed"
  teardown
}

case_finish_pr_refuses_a_library_gutted_uncommitted() {
  cf_reset
  local out rc
  _held_fpr_setup 806
  _held_edit lib/qa-gate.sh 'kit_qa_verdict_check() { :; }'
  _held_land "$HELD_WT"
  _held_refused "(uncommitted gut)" lib/qa-gate.sh
  finish "finish-pr.sh refuses to land from a checkout holding an uncommitted edit of lib/qa-gate.sh, naming the file, with nothing landed"
  teardown
}

case_finish_pr_refuses_when_the_refusal_helper_is_gutted_too() {
  cf_reset
  local out rc
  _held_fpr_setup 807
  _held_edit lib/refuse.sh 'kit_refuse() { return 0; }' commit
  _held_edit finish-pr.sh '# the branch edits the tool that lands it' commit
  _held_land "$HELD_WT"
  _held_refused "(refuse.sh gutted)" lib/refuse.sh
  finish "finish-pr.sh refuses a checkout whose refusal helper is gutted and whose finish-pr.sh is edited: the comparison does not lean on a library it has not yet checked, and the exit is still 1"
  teardown
}

case_finish_pr_lands_a_library_change_through_the_trunks_copy() {
  cf_reset
  local out rc
  _held_fpr_setup 808
  # An honest card (no FAIL row) and, as the branch's change, a comment in a library.
  perl -i -pe 's/FAIL_AC/PASS/' "$SB_WORK/progress/dev_complete/$HELD_ID-held.md"
  git -C "$SB_WORK" add progress >/dev/null 2>&1
  sbcommit -q -m "[PM] honest card" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "case_finish_pr_lands_a_library_change_through_the_trunks_copy: could not publish the honest card"
  git -C "$HELD_WT" merge -q --no-edit "$SB_TRUNK" >/dev/null 2>&1 \
    || _fixture_die "case_finish_pr_lands_a_library_change_through_the_trunks_copy: could not bring the branch up to the trunk"
  _held_edit lib/qa-gate.sh '# a comment the branch adds to a library' commit
  # (a) the branch's own checkout is refused; (b) the trunk's copy, from the main checkout, gating the branch, lands.
  _held_land "$HELD_WT"
  [ "$rc" -eq 1 ] || cf "(a) the branch's own tool exited $rc, expected the refusal 1"
  rc=0; out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$HELD_ID" --worktree "$HELD_WT" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(b) the trunk's copy did not land a branch that changes a library (exit $rc): $(printf '%s' "$out" | tail -5 | tr '\n' '|')"
  origin_file_contains "scripts/lib/qa-gate.sh" "a comment the branch adds to a library" \
    || cf "(b) the landed trunk does not carry the branch's library change"
  finish "a library change lands through the trunk's copy run from the main checkout with --worktree; the branch's own checkout is refused"
  teardown
}

# The mover holds itself and its libraries the same way: its own call to the QA Verdict check
# replaced by a no-op, uncommitted, must not publish a FAIL card to qa_complete/. (control) the
# unchanged mover refuses the FAIL row; (green) a mover run from the clean checkout moves an honest card.
case_move_issue_refuses_its_own_edited_call() {
  cf_reset
  local out rc id f
  make_sandbox
  id="$SB_PREFIX-811"
  seed_issue dev_complete "$id" mover chore "A FAIL row behind an edited mover" "feature/$id-work"
  f="$SB_WORK/progress/dev_complete/$id-mover.md"
  perl -i -pe 's/^(\| AC1 \| )PASS( \| test \|.*\|)$/${1}FAIL_AC${2}/' "$f"
  grep -qF 'FAIL_AC' "$f" || _fixture_die "case_move_issue_refuses_its_own_edited_call: the FAIL_AC row was not planted"
  seed_issue dev_complete "$SB_PREFIX-812" honest chore "An honest card" "feature/$SB_PREFIX-812-work"
  publish_sandbox

  # (control) the unchanged mover refuses the FAIL row.
  rc=0; out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec0" "$SB_WORK/scripts/move-issue.sh" "$id" qa_complete --role QA --note "review" 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(control) a FAIL row on an unchanged mover — exit 0"
  grep -q 'refusal=qa-verdict-fail' "$SB_TMP/rec0"/*.tsv 2>/dev/null \
    || cf "(control) the FAIL row was not what refused: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  # (green) the clean checkout moves an honest card.
  rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-812" qa_complete --role QA --note "review" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(green) a mover run from the clean trunk checkout refused an honest card (exit $rc): $(printf '%s' "$out" | tail -4 | tr '\n' '|')"

  # (a) its own call replaced, uncommitted.
  perl -i -pe 's/^(\s*)kit_qa_verdict_check "\$SRC".*$/$1:/' "$SB_WORK/scripts/move-issue.sh"
  ! grep -F 'kit_qa_verdict_check "$SRC"' "$SB_WORK/scripts/move-issue.sh" >/dev/null \
    || _fixture_die "case_move_issue_refuses_its_own_edited_call: the call was not replaced"
  bash -n "$SB_WORK/scripts/move-issue.sh" || _fixture_die "case_move_issue_refuses_its_own_edited_call: the edited script no longer parses"
  rc=0; out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec" "$SB_WORK/scripts/move-issue.sh" "$id" qa_complete --role QA --note "review" 2>&1 )" || rc=$?
  [ "$rc" -eq 1 ] || cf "(a) exit $rc, expected 1: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  printf '%s\n' "$out" | grep -F "is not $SB_TRUNK's committed copy" >/dev/null \
    || cf "(a) the refusal does not say the tool is not the trunk's copy: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  printf '%s\n' "$out" | grep -F 'scripts/move-issue.sh' >/dev/null || cf "(a) the refusal does not name scripts/move-issue.sh"
  origin_has_path "progress/qa_complete/$id-mover.md" && cf "(a) the FAIL card was published to qa_complete/"
  origin_has_path "progress/dev_complete/$id-mover.md" || cf "(a) the FAIL card left dev_complete/"

  finish "move-issue.sh refuses to run once its own call to the QA Verdict check is replaced (uncommitted), naming scripts/move-issue.sh, with the FAIL card unmoved; unchanged, it refuses the FAIL row and moves an honest card"
  teardown
}

# The refusal itself sources nothing: a checkout whose refusal helper redefines `exit` (and whose gate
# library is gutted) is still refused, through the landing script and through the mover.
_held_exit_shadow='if [ -n "${_held_off:-}" ]; then exit() { _xn=$(( ${_xn:-0} + 1 )); [ "$_xn" -ge 2 ] && unset -f exit; return 0; }; fi'

case_finish_pr_refuses_when_a_library_redefines_exit() {
  cf_reset
  local out rc
  _held_fpr_setup 821
  _held_edit lib/qa-gate.sh 'kit_qa_verdict_check() { :; }' commit
  _held_edit lib/refuse.sh "$_held_exit_shadow" commit
  _held_land "$HELD_WT"
  _held_refused "(exit shadow)" lib/qa-gate.sh
  finish "finish-pr.sh refuses a checkout whose refuse.sh redefines exit and whose qa-gate.sh is gutted: the refusal sources nothing, so nothing it judged runs, and nothing is landed"
  teardown
}

case_move_issue_refuses_when_a_library_redefines_exit() {
  cf_reset
  local out rc id f
  make_sandbox
  id="$SB_PREFIX-822"
  seed_issue dev_complete "$id" shadow chore "A FAIL row behind an exit shadow" "feature/$id-work"
  f="$SB_WORK/progress/dev_complete/$id-shadow.md"
  perl -i -pe 's/^(\| AC1 \| )PASS( \| test \|.*\|)$/${1}FAIL_AC${2}/' "$f"
  grep -qF 'FAIL_AC' "$f" || _fixture_die "case_move_issue_refuses_when_a_library_redefines_exit: the FAIL_AC row was not planted"
  publish_sandbox
  seed_branch "$id" work CHANGE822.txt
  printf '\n%s\n' 'kit_qa_verdict_check() { :; }' >> "$SB_WORK/scripts/lib/qa-gate.sh"
  printf '\n%s\n' "$_held_exit_shadow" >> "$SB_WORK/scripts/lib/refuse.sh"
  bash -n "$SB_WORK/scripts/lib/refuse.sh" || _fixture_die "case_move_issue_refuses_when_a_library_redefines_exit: the shadowed library no longer parses"
  rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$id" qa_complete --role QA --note "review" 2>&1 )" || rc=$?
  [ "$rc" -eq 1 ] || cf "exit $rc, expected 1: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  printf '%s\n' "$out" | grep -F "is not $SB_TRUNK's committed copy" >/dev/null || cf "the refusal does not say the tool is not the trunk's copy"
  origin_has_path "progress/qa_complete/$id-shadow.md" && cf "the FAIL card was published to qa_complete/"
  finish "move-issue.sh refuses a checkout whose refuse.sh redefines exit and whose qa-gate.sh is gutted, with the FAIL card unmoved"
  teardown
}

# A copy of scripts/ outside the repository, run with the working directory in the project, acts on the
# project's board: it is compared with the project's trunk, whatever repository the copy sits in.
case_the_tools_hold_a_copy_of_scripts_outside_the_repository() {
  cf_reset
  local out rc oot id f
  _held_fpr_setup 823
  oot="$SB_TMP/oot"; mkdir -p "$oot"; cp -R "$SB_WORK/scripts" "$oot/scripts"
  # (a) finish-pr.sh with its verdict call removed.
  perl -i -pe 's/^(\s*)kit_qa_verdict_check "\$SRC".*$/$1:/' "$oot/scripts/finish-pr.sh"
  ! grep -F 'kit_qa_verdict_check "$SRC"' "$oot/scripts/finish-pr.sh" >/dev/null \
    || _fixture_die "case_the_tools_hold_a_copy_of_scripts_outside_the_repository: the call was not removed"
  rc=0; out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec" "$oot/scripts/finish-pr.sh" "$HELD_ID" --worktree "$HELD_WT" 2>&1 )" || rc=$?
  _held_refused "(outside copy, edited finish-pr.sh)" scripts/finish-pr.sh
  # (b) a pristine finish-pr.sh with qa-gate.sh gutted.
  rm -rf "$oot/scripts"; cp -R "$SB_WORK/scripts" "$oot/scripts"
  printf '\n%s\n' 'kit_qa_verdict_check() { :; }' >> "$oot/scripts/lib/qa-gate.sh"
  rc=0; out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec" "$oot/scripts/finish-pr.sh" "$HELD_ID" --worktree "$HELD_WT" 2>&1 )" || rc=$?
  _held_refused "(outside copy, gutted qa-gate.sh)" lib/qa-gate.sh
  # (c) the mover, its own call removed, on a FAIL card.
  id="$SB_PREFIX-824"
  seed_issue dev_complete "$id" oot chore "A FAIL row behind an outside mover" "feature/$id-work"
  f="$SB_WORK/progress/dev_complete/$id-oot.md"
  perl -i -pe 's/^(\| AC1 \| )PASS( \| test \|.*\|)$/${1}FAIL_AC${2}/' "$f"
  git -C "$SB_WORK" add progress >/dev/null 2>&1; sbcommit -q -m "[PM] seed oot card" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "case_the_tools_hold_a_copy_of_scripts_outside_the_repository: could not publish the card"
  rm -rf "$oot/scripts"; cp -R "$SB_WORK/scripts" "$oot/scripts"
  perl -i -pe 's/^(\s*)kit_qa_verdict_check "\$SRC".*$/$1:/' "$oot/scripts/move-issue.sh"
  rc=0; out="$( cd "$SB_WORK" && "$oot/scripts/move-issue.sh" "$id" qa_complete --role QA --note "review" 2>&1 )" || rc=$?
  [ "$rc" -eq 1 ] || cf "(outside mover) exit $rc, expected 1: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  printf '%s\n' "$out" | grep -F "is not $SB_TRUNK's committed copy" >/dev/null \
    || cf "(outside mover) the refusal does not say the tool is not the trunk's copy: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  printf '%s\n' "$out" | grep -F 'scripts/move-issue.sh' >/dev/null || cf "(outside mover) the refusal does not name scripts/move-issue.sh"
  printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "(outside mover) the refusal names no next action"
  origin_has_path "progress/qa_complete/$id-oot.md" && cf "(outside mover) the FAIL card was published to qa_complete/"
  finish "a copy of scripts/ outside the repository, run from the project, is held to the project's trunk: an edited finish-pr.sh, a gutted qa-gate.sh and an edited move-issue.sh are each refused with nothing landed or published"
  teardown
}

# With no trunk ref to compare with (offline, the tracking ref gone), the tools refuse before the board
# worktree is touched. Left to run, a gutted check makes its move as a commit there, and the next
# run's recovery text offers to publish it.
case_the_tools_leave_the_board_worktree_alone_when_there_is_no_trunk_ref() {
  cf_reset
  if ! has_issue_template; then skp "the tools refuse, leaving the board worktree untouched, when no trunk ref can be read" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  local out rc id sid head0 head1 wt
  make_sandbox
  id="$SB_PREFIX-828"; sid="$SB_PREFIX-829"
  seed_issue dev_complete "$id" offline chore "A FAIL row behind an offline gut" "feature/$id-work"
  perl -i -pe 's/^(\| AC1 \| )PASS( \| test \|.*\|)$/${1}FAIL_AC${2}/' "$SB_WORK/progress/dev_complete/$id-offline.md"
  grep -qF 'FAIL_AC' "$SB_WORK/progress/dev_complete/$id-offline.md" || _fixture_die "case_the_tools_leave_the_board_worktree_alone_when_there_is_no_trunk_ref: the FAIL_AC row was not planted"
  seed_issue todo "$SB_PREFIX-830" warm chore "A card that makes the board worktree stand"
  _seed_parent "$sid"
  local sl; sl="$(_seed_subtask "$sid" s1 dev_complete offline "A FAIL slice behind an offline gut")"
  perl -i -pe 's/^(\| AC1 \| )PASS( \| test \|.*\|)$/${1}FAIL_AC${2}/' "$sl"
  publish_sandbox
  seed_branch "$id" work CHANGE828.txt
  # The board worktree stands: one ordinary move creates it.
  ( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-830" in_progress --role Dev --note warm ) >/dev/null 2>&1 \
    || _fixture_die "case_the_tools_leave_the_board_worktree_alone_when_there_is_no_trunk_ref: the warm-up move failed"
  wt="$SB_WORK/.kanban-wt"
  # Offline, the tracking ref gone, the gate library gutted.
  git -C "$SB_WORK" update-ref -d "refs/remotes/origin/$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" remote set-url origin "$SB_TMP/no-such-remote.git" >/dev/null 2>&1
  printf '\n%s\n' 'kit_qa_verdict_check() { :; }' >> "$SB_WORK/scripts/lib/qa-gate.sh"
  head0="$(git -C "$wt" rev-parse HEAD 2>/dev/null)"
  rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$id" qa_complete --role QA --note "review" 2>&1 )" || rc=$?
  head1="$(git -C "$wt" rev-parse HEAD 2>/dev/null)"
  [ "$rc" -eq 1 ] || cf "(mover) exit $rc, expected 1: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  [ "$head0" = "$head1" ] || cf "(mover) the board worktree gained a commit ($head0 -> $head1): the gutted check made its move there"
  printf '%s\n' "$out" | grep -F "no origin/$SB_TRUNK ref" >/dev/null || cf "(mover) the refusal does not say there was no origin/$SB_TRUNK ref to compare with: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "(mover) the refusal names no next action"
  head0="$head1"
  rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/subtask.sh" move "${sid}-s1" qa_complete 2>&1 )" || rc=$?
  head1="$(git -C "$wt" rev-parse HEAD 2>/dev/null)"
  [ "$rc" -eq 1 ] || cf "(subtask) exit $rc, expected 1: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  [ "$head0" = "$head1" ] || cf "(subtask) the board worktree gained a commit: the gutted check made its move there"
  printf '%s\n' "$out" | grep -F "no origin/$SB_TRUNK ref" >/dev/null || cf "(subtask) the refusal does not say there was no ref to compare with"
  finish "with no trunk ref to compare with, move-issue.sh and subtask.sh refuse, naming the missing ref and a next action, and leave the board worktree without a new commit"
  teardown
}

# The no-trunk-ref refusal is decided before any library is sourced, so a gutted library that knows about
# it cannot undo it: one that resets the flag, and one that redefines `exit` once the flag is set, through
# each of the three tools.
case_a_library_cannot_defeat_the_no_trunk_ref_refusal() {
  cf_reset
  if ! has_issue_template; then skp "a gutted library cannot defeat the no-trunk-ref refusal" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  local out rc mid sid sl wt h0 h1 hinit o0 o1 gate variant vname tool
  _held_fpr_setup 831
  mid="$SB_PREFIX-832"; sid="$SB_PREFIX-834"
  seed_issue dev_complete "$mid" mover chore "A FAIL card for the mover" "feature/$mid-work"
  perl -i -pe 's/^(\| AC1 \| )PASS( \| test \|.*\|)$/${1}FAIL_AC${2}/' "$SB_WORK/progress/dev_complete/$mid-mover.md"
  seed_issue todo "$SB_PREFIX-833" warm chore "A card that makes the board worktree stand"
  _seed_parent "$sid"
  sl="$(_seed_subtask "$sid" s1 dev_complete variant "A FAIL slice")"
  perl -i -pe 's/^(\| AC1 \| )PASS( \| test \|.*\|)$/${1}FAIL_AC${2}/' "$sl"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m "[PM] seed cards" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "case_a_library_cannot_defeat_the_no_trunk_ref_refusal: could not publish the cards"
  ( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-833" in_progress --role Dev --note warm ) >/dev/null 2>&1 \
    || _fixture_die "case_a_library_cannot_defeat_the_no_trunk_ref_refusal: the warm-up move failed"
  wt="$SB_WORK/.kanban-wt"
  git -C "$SB_WORK" update-ref -d "refs/remotes/origin/$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" remote set-url origin "$SB_TMP/no-such-remote.git" >/dev/null 2>&1
  gate="$SB_WORK/scripts/lib/qa-gate.sh"; cp "$gate" "$SB_TMP/qa-gate.real"
  hinit="$(git -C "$wt" rev-parse HEAD 2>/dev/null)"
  for vname in reset shadow; do
    git -C "$wt" reset -q --hard "$hinit" >/dev/null 2>&1   # a run that did commit must not mask the next
    cp "$SB_TMP/qa-gate.real" "$gate"
    case "$vname" in
      reset)  variant='_held_noref=false' ;;
      shadow) variant='if [ "${_held_noref:-}" = true ]; then exit() { unset -f exit; return 0; }; fi' ;;
    esac
    printf '\n%s\n%s\n' 'kit_qa_verdict_check() { :; }' "$variant" >> "$gate"
    bash -n "$gate" || _fixture_die "case_a_library_cannot_defeat_the_no_trunk_ref_refusal: the $vname library no longer parses"
    for tool in finish-pr mover subtask; do
      h0="$(git -C "$wt" rev-parse HEAD 2>/dev/null)"; o0="$(git -C "$SB_ORIGIN" rev-parse "$SB_TRUNK" 2>/dev/null)"
      rc=0
      case "$tool" in
        finish-pr) out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$HELD_ID" --worktree "$HELD_WT" 2>&1 )" || rc=$? ;;
        mover)     out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$mid" qa_complete --role QA --note review 2>&1 )" || rc=$? ;;
        subtask)   out="$( cd "$SB_WORK" && "$SB_WORK/scripts/subtask.sh" move "${sid}-s1" qa_complete 2>&1 )" || rc=$? ;;
      esac
      h1="$(git -C "$wt" rev-parse HEAD 2>/dev/null)"; o1="$(git -C "$SB_ORIGIN" rev-parse "$SB_TRUNK" 2>/dev/null)"
      [ "$rc" -eq 1 ] || cf "($vname/$tool) exit $rc, expected 1: $(printf '%s' "$out" | tail -3 | tr '\n' '|')"
      printf '%s\n' "$out" | grep -F "no origin/$SB_TRUNK ref" >/dev/null || cf "($vname/$tool) the refusal does not say there was no origin/$SB_TRUNK ref"
      [ "$h0" = "$h1" ] || cf "($vname/$tool) the board worktree gained a commit"
      [ "$o0" = "$o1" ] || cf "($vname/$tool) the trunk moved"
    done
  done
  # With no board worktree standing, the refusal does not create one either.
  git -C "$SB_WORK" worktree remove --force "$wt" >/dev/null 2>&1; rm -rf "$wt"; git -C "$SB_WORK" worktree prune >/dev/null 2>&1
  cp "$SB_TMP/qa-gate.real" "$gate"
  rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$mid" qa_complete --role QA --note review 2>&1 )" || rc=$?
  [ "$rc" -eq 1 ] || cf "(no worktree) exit $rc, expected 1: $(printf '%s' "$out" | tail -3 | tr '\n' '|')"
  printf '%s\n' "$out" | grep -F "no origin/$SB_TRUNK ref" >/dev/null || cf "(no worktree) the refusal does not say there was no ref"
  [ ! -e "$wt" ] || cf "(no worktree) the refusal created the board worktree"
  finish "with no trunk ref to compare with, finish-pr.sh, move-issue.sh and subtask.sh refuse before any library is sourced, so a gutted qa-gate.sh that resets the flag or redefines exit cannot get past it, and no commit reaches the board worktree"
  teardown
}

# Deleting the local trunk branch as well as its tracking ref is not "an empty repository": the repository
# still holds commits and a standing board worktree, so each tool still refuses and none commits there.
case_the_tools_refuse_when_the_local_trunk_is_deleted_too() {
  cf_reset
  if ! has_issue_template; then skp "the tools refuse when the local trunk and its tracking ref are both gone" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  local out rc mid sid sl wt h0 h1 o0 o1 gate tool vname
  _held_fpr_setup 835
  mid="$SB_PREFIX-836"; sid="$SB_PREFIX-838"
  seed_issue dev_complete "$mid" mover chore "A FAIL card for the mover" "feature/$mid-work"
  perl -i -pe 's/^(\| AC1 \| )PASS( \| test \|.*\|)$/${1}FAIL_AC${2}/' "$SB_WORK/progress/dev_complete/$mid-mover.md"
  seed_issue todo "$SB_PREFIX-837" warm chore "A card that makes the board worktree stand"
  _seed_parent "$sid"
  sl="$(_seed_subtask "$sid" s1 dev_complete deleted "A FAIL slice")"
  perl -i -pe 's/^(\| AC1 \| )PASS( \| test \|.*\|)$/${1}FAIL_AC${2}/' "$sl"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m "[PM] seed cards" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "case_the_tools_refuse_when_the_local_trunk_is_deleted_too: could not publish the cards"
  ( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-837" in_progress --role Dev --note warm ) >/dev/null 2>&1 \
    || _fixture_die "case_the_tools_refuse_when_the_local_trunk_is_deleted_too: the warm-up move failed"
  wt="$SB_WORK/.kanban-wt"
  # Offline, HEAD detached, the local trunk and its tracking ref both deleted, the gate library gutted.
  git -C "$SB_WORK" checkout -q --detach >/dev/null 2>&1
  git -C "$SB_WORK" branch -D "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "case_the_tools_refuse_when_the_local_trunk_is_deleted_too: could not delete the local trunk"
  git -C "$SB_WORK" update-ref -d "refs/remotes/origin/$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" remote set-url origin "$SB_TMP/no-such-remote.git" >/dev/null 2>&1
  gate="$SB_WORK/scripts/lib/qa-gate.sh"
  printf '\n%s\n' 'kit_qa_verdict_check() { :; }' >> "$gate"
  bash -n "$gate" || _fixture_die "case_the_tools_refuse_when_the_local_trunk_is_deleted_too: the gutted library no longer parses"
  # Twice: as it stands, then with one corrupt loose ref added, which makes `git rev-list --all` fail.
  for vname in plain garbage; do
    [ "$vname" != garbage ] || printf 'garbage\n' > "$SB_WORK/.git/refs/heads/zz"
    for tool in finish-pr mover subtask; do
      h0="$(git -C "$wt" rev-parse HEAD 2>/dev/null)"; o0="$(git -C "$SB_ORIGIN" rev-parse "$SB_TRUNK" 2>/dev/null)"
      rc=0
      case "$tool" in
        finish-pr) out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$HELD_ID" --worktree "$HELD_WT" 2>&1 )" || rc=$? ;;
        mover)     out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$mid" qa_complete --role QA --note review 2>&1 )" || rc=$? ;;
        subtask)   out="$( cd "$SB_WORK" && "$SB_WORK/scripts/subtask.sh" move "${sid}-s1" qa_complete 2>&1 )" || rc=$? ;;
      esac
      h1="$(git -C "$wt" rev-parse HEAD 2>/dev/null)"; o1="$(git -C "$SB_ORIGIN" rev-parse "$SB_TRUNK" 2>/dev/null)"
      [ "$rc" -eq 1 ] || cf "($vname/$tool) exit $rc, expected 1: $(printf '%s' "$out" | tail -3 | tr '\n' '|')"
      printf '%s\n' "$out" | grep -F "no origin/$SB_TRUNK ref" >/dev/null || cf "($vname/$tool) the refusal does not say there was no origin/$SB_TRUNK ref"
      [ "$h0" = "$h1" ] || cf "($vname/$tool) the board worktree gained a commit"
      [ "$o0" = "$o1" ] || cf "($vname/$tool) the trunk moved"
      git -C "$wt" reset -q --hard "$h0" >/dev/null 2>&1
    done
  done
  finish "with the local trunk and its tracking ref both deleted and the remote unreachable, and again with a corrupt loose ref, finish-pr.sh, move-issue.sh and subtask.sh still refuse, naming the missing ref, and no commit reaches the board worktree"
  teardown
}

# A listed file that is gone here but on the trunk is a difference: a deleted progress-record.sh would
# otherwise leave every refusal uncounted.
case_the_mover_refuses_a_deleted_progress_record_library() {
  cf_reset
  local out rc id
  make_sandbox
  id="$SB_PREFIX-826"
  seed_issue dev_complete "$id" gone chore "A card behind a deleted library" "feature/$id-work"
  publish_sandbox
  seed_branch "$id" work CHANGE826.txt
  rm -f "$SB_WORK/scripts/lib/progress-record.sh"
  rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$id" qa_complete --role QA --note "review" 2>&1 )" || rc=$?
  [ "$rc" -eq 1 ] || cf "exit $rc, expected 1: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  printf '%s\n' "$out" | grep -F 'lib/progress-record.sh' >/dev/null || cf "the refusal does not name lib/progress-record.sh"
  origin_has_path "progress/qa_complete/$id-gone.md" && cf "the card moved with progress-record.sh deleted"
  finish "move-issue.sh refuses a checkout from which lib/progress-record.sh is deleted, naming it, with the card unmoved"
  teardown
}

# A landing that changes a held file from a main checkout that cannot be fast-forwarded ends exit 3, and
# the recovery line it prints leads to a finished board: it carries the switch and the pull.
case_finish_pr_recovery_line_works_from_a_dirty_main_checkout() {
  cf_reset
  local out rc line
  _held_fpr_setup 827
  perl -i -pe 's/FAIL_AC/PASS/' "$SB_WORK/progress/dev_complete/$HELD_ID-held.md"
  git -C "$SB_WORK" add progress >/dev/null 2>&1
  sbcommit -q -m "[PM] honest card" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "case_finish_pr_recovery_line_works_from_a_dirty_main_checkout: could not publish the honest card"
  git -C "$HELD_WT" merge -q --no-edit "$SB_TRUNK" >/dev/null 2>&1 \
    || _fixture_die "case_finish_pr_recovery_line_works_from_a_dirty_main_checkout: could not bring the branch up to the trunk"
  _held_edit lib/qa-gate.sh '# a comment the branch adds to a library' commit
  printf '\nlocal change\n' >> "$SB_WORK/ARCHIVE.md"
  rc=0; out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$HELD_ID" --worktree "$HELD_WT" 2>&1 )" || rc=$?
  [ "$rc" -eq 3 ] || cf "(premise) exit $rc, expected 3 (landed, not finished): $(printf '%s' "$out" | tail -6 | tr '\n' '|')"
  line="$(printf '%s\n' "$out" | grep -F 'git pull --ff-only && ' | grep -F 'move-issue.sh' | tail -1 | sed 's/^[[:space:]]*//')"
  [ -n "$line" ] || cf "the recovery line printed after a failed board advance does not begin with the switch and the pull: $(printf '%s' "$out" | tail -6 | tr '\n' '|')"
  if [ -n "$line" ]; then
    rc=0; ( cd "$SB_WORK" && bash -c "$line" ) >/dev/null 2>&1 || rc=$?
    [ "$rc" -eq 0 ] || cf "the printed recovery line exited $rc"
    origin_has_path "progress/qa_complete/$HELD_ID-held.md" || cf "the card is not in qa_complete/ after the printed recovery"
  fi
  finish "a landing that changes a held file from a dirty main checkout ends exit 3, and the recovery line it prints (switch, pull, then the move) finishes the board"
  teardown
}

# =============================================================================
# THE HELD LIST IS DERIVED FROM WHAT IS SOURCED, TRANSITIVELY. A file a held script (or the mover it
# runs) sources, directly or through a library, that the script's own list does not name can be
# rewritten unseen. PASS/FAIL: the operand is the real tree, and a planted control (a new library
# sourced directly, one sourced only through another library) has a known answer.
# =============================================================================

# _held_derive <scripts dir> <root>… — the files the roots run: the roots, and every file a source
# command on a non-comment line names (a variable it sources is followed to its assignment), followed
# through lib/ only. One `x.sh` or `lib/x.sh` per line.
_held_derive() {
  local dir="$1" roots f n p body vars v todo seen=""
  shift
  roots=" $* "; todo="$*"
  while [ -n "$todo" ]; do
    set -- $todo; f="$1"; shift; todo="$*"
    case " $seen " in *" $f "*) continue ;; esac
    seen="$seen $f"
    case "$f" in lib/*) : ;; *) case "$roots" in *" $f "*) : ;; *) continue ;; esac ;; esac
    [ -f "$dir/$f" ] || continue
    body="$(grep -v '^[[:space:]]*#' "$dir/$f")"
    vars="$(printf '%s\n' "$body" | grep -oE '(^|[;&|!({]|then|else|do)[[:space:]]*(\.|source)[[:space:]]+"?\$\{?[A-Za-z_][A-Za-z0-9_]*' | grep -oE '[A-Za-z_][A-Za-z0-9_]*$' | sort -u || true)"
    {
      printf '%s\n' "$body" | grep -E '(^|[;&|!({]|then|else|do)[[:space:]]*(\.|source)[[:space:]]+' | grep -oE '[A-Za-z0-9_-]+\.sh' || true
      for v in $vars; do printf '%s\n' "$body" | grep -E "^[[:space:]]*(local[[:space:]]+)?$v=" | grep -oE '[A-Za-z0-9_-]+\.sh' || true; done
    } | sort -u > "$dir/.derive.tmp"
    while IFS= read -r n; do
      p=""; [ -f "$dir/lib/$n" ] && p="lib/$n"; [ -z "$p" ] && [ -f "$dir/$n" ] && p="$n"
      [ -n "$p" ] && todo="$todo $p"
    done < "$dir/.derive.tmp"
  done
  rm -f "$dir/.derive.tmp"
  printf '%s\n' $seen | sort -u
}

# _held_listed <script> — the files the script's own list names, one per line; nothing when it has none.
_held_listed() {
  awk '/^_held_files="$/ { on = 1; next } on && /^"$/ { exit } on { print }' "$1" | sort -u
}

# _held_missing <scripts dir> <script> <root>… — what the roots run that the script's list does not name.
_held_missing() {
  local dir="$1" script="$2"; shift 2
  _held_derive "$dir" "$@" > "$dir/.d.tmp"; _held_listed "$dir/$script" > "$dir/.l.tmp"
  comm -23 "$dir/.d.tmp" "$dir/.l.tmp"
  rm -f "$dir/.d.tmp" "$dir/.l.tmp"
}

case_the_held_list_names_every_file_the_landing_and_slice_tools_source() {
  cf_reset
  local d miss n s roots
  if ! has_issue_template; then skp "every file the landing, mover and slice tools source is on their held list" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  d="$(mktemp -d)"; cp -R "$REAL_SCRIPTS" "$d/scripts"; rm -rf "$d/scripts/test"
  # Each tool and the files it runs: the landing script also runs the mover, which is a root of its own.
  # <script>:<roots, space-separated>
  local rows="finish-pr.sh:finish-pr.sh,move-issue.sh move-issue.sh:move-issue.sh subtask.sh:subtask.sh" row
  for row in $rows; do
    s="${row%%:*}"; roots="${row#*:}"; roots="${roots//,/ }"
    grep -q '^_held_files="$' "$d/scripts/$s" || cf "scripts/$s carries no _held_files list"
    miss="$(_held_missing "$d/scripts" "$s" $roots)"
    [ -z "$miss" ] || cf "$s runs files its list does not name: $(printf '%s' "$miss" | tr '\n' ' ')"
    while IFS= read -r n; do
      [ -z "$n" ] || [ -f "$d/scripts/$n" ] || cf "$s lists $n, which is not a file under scripts/"
    done <<< "$(_held_listed "$d/scripts/$s")"
  done
  # THE CONTROL: a library sourced directly by each tool, and one sourced only through another library.
  printf '%s\n' ':' > "$d/scripts/lib/zz-deep.sh"
  printf '%s\n' '. "$(dirname "${BASH_SOURCE[0]}")/zz-deep.sh" || return 1' >> "$d/scripts/lib/usage.sh"
  for row in $rows; do
    s="${row%%:*}"; roots="${row#*:}"; roots="${roots//,/ }"
    printf '%s\n' ':' > "$d/scripts/lib/zz-direct-${s%.sh}.sh"
    printf '%s\n' ". \"\$SCRIPT_DIR/lib/zz-direct-${s%.sh}.sh\"" >> "$d/scripts/$s"
    miss="$(_held_missing "$d/scripts" "$s" $roots | tr '\n' ' ')"
    case "$miss" in *lib/zz-direct-${s%.sh}.sh*) : ;; *) cf "(control) $s: a library it sources directly was not found: [$miss]" ;; esac
    case "$miss" in *lib/zz-deep.sh*) : ;; *) cf "(control) $s: a library sourced through another library was not found: [$miss]" ;; esac
  done
  rm -rf "$d"
  finish "every file finish-pr.sh (with the mover it runs), move-issue.sh as a root of its own and subtask.sh source, directly or through a library, is named in that script's _held_files list; a planted new library, direct or transitive, turns the check red for each"
}

# =============================================================================
# CASE — THE GATE-EXECUTABLE HARDENING. One case, four legs:
#   (a) a caller-supplied FINISH_PR_PREMERGE_CMD is REFUSED on the production
#       path (no marker) before ANY destructive step;
#   (b) a genuine worktree's TRACKED scripts/verify.sh (green) is ACCEPTED via
#       --worktree — the legitimate worktree-QA capability, preserved;
#   (c) --worktree pointed at a scratch dir carrying a FABRICATED verify.sh is
#       REFUSED (it is not a git worktree of this repo);
#   (d) the sandbox stub injection STILL works, but ONLY behind the explicit
#       test-only marker.
# =============================================================================
case_finish_pr_gate_hardening() {
  cf_reset
  local out rc

  # --- (a) production path REFUSES a fabricated premerge command --------------
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-790" sandbox chore "Fabricated stub" "feature/$SB_PREFIX-790-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-790" work CHANGE.txt
  printf '#!/usr/bin/env bash\necho PASS\nexit 0\n' > "$SB_TMP/fabricated-gate.sh"
  chmod +x "$SB_TMP/fabricated-gate.sh"

  out="$( cd "$SB_WORK" && FINISH_PR_PREMERGE_CMD="$SB_TMP/fabricated-gate.sh" \
            "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-790" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) fabricated stub was ACCEPTED (expected a nonzero refusal), got 0"
  printf '%s' "$out" | grep -i 'FINISH_PR_TEST_ALLOW_STUB\|refus' >/dev/null \
    || cf "(a) the refusal did not name why it was refused: $out"
  assert_landing_untouched "(a)" "$SB_PREFIX-790" sandbox "feature/$SB_PREFIX-790-work" CHANGE.txt
  teardown

  # --- (b) a genuine worktree's tracked verify.sh (green) is ACCEPTED ---------
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-791" sandbox chore "Worktree accept" "feature/$SB_PREFIX-791-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-791" work CHANGE.txt
  git -C "$SB_WORK" worktree add "$SB_TMP/wt-791" "feature/$SB_PREFIX-791-work" --quiet >/dev/null 2>&1

  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-791" \
            --worktree "$SB_TMP/wt-791" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) the genuine-worktree accept path exited $rc (expected 0): $out"
  origin_has_path "progress/qa_complete/$SB_PREFIX-791-sandbox.md" \
    || cf "(b) issue not advanced to qa_complete/ (the landing did not proceed)"
  origin_has_path "CHANGE.txt" || cf "(b) squash-merged change not on the trunk"
  git -C "$SB_WORK" worktree remove --force "$SB_TMP/wt-791" >/dev/null 2>&1
  teardown

  # --- (c) --worktree at a scratch dir with a FABRICATED verify.sh is REFUSED --
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-792" sandbox chore "Scratch worktree" "feature/$SB_PREFIX-792-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-792" work CHANGE.txt
  mkdir -p "$SB_TMP/scratch/scripts"
  printf '#!/usr/bin/env bash\necho "fabricated: PASS"\nexit 0\n' > "$SB_TMP/scratch/scripts/verify.sh"
  chmod +x "$SB_TMP/scratch/scripts/verify.sh"

  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-792" \
            --worktree "$SB_TMP/scratch" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(c) a scratch-dir fabricated verify.sh was ACCEPTED (expected a refusal), got 0"
  assert_landing_untouched "(c)" "$SB_PREFIX-792" sandbox "feature/$SB_PREFIX-792-work" CHANGE.txt
  teardown

  # --- (d) the marker + stub path still works --------------------------------
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-793" sandbox chore "Marker stub" "feature/$SB_PREFIX-793-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-793" work CHANGE.txt
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-793" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(d) the marker+stub path exited $rc (expected 0 — sandbox injection must survive): $out"
  origin_has_path "progress/qa_complete/$SB_PREFIX-793-sandbox.md" \
    || cf "(d) marker+stub did not land the issue to qa_complete/"

  finish "finish-pr gate hardening: fabricated stub REFUSED (a), genuine --worktree ACCEPTED (b), scratch-dir --worktree REFUSED (c), marker stub survives (d)"
  teardown
}

# =============================================================================
# THE GUARD-FLOOR RECONCILIATION CASES, and why they are keyed on BEHAVIOUR
#
# EVERY ASSERTION BELOW READS AN EXIT CODE AND WHICH SIDE'S ITEMS ARE NAMED — never the
# wording of a refusal. A refusal's phrasing is the part most likely to be rewritten; its
# exit code and the list it prints are the contract.
#
# EVERY CASE INVOKES `--scope`: the whole guard-floor block sits inside
# `if [ "$SCOPED" -eq 1 ]`, so a plain full run never reaches it.
#
# THE STATES, named by their two variables (what GUARD_SET holds, what the enumerator
# does), one case each. verify.sh has more outcomes than these, so check the list against
# the case set rather than trusting a count:
#   (1) SPACE − SET, from the SHIPPED empty GUARD_SET  → rc 2, the enumerated guard named
#   (2) enumerator MIS-TYPED (rc 1, not 127)           → rc 2, the enumerator's OWN stderr surfaced
#   (3) enumerator succeeds and returns NOTHING        → rc 2, no reconciled claim
#   (4) SET − SPACE, two on disk, enumerator sees one  → rc 2, the UNSEEN one named
#   (5) wholly empty: no set, enumerator returns none  → rc 0, and NO reconciled claim
#   (6) DECLARED == ENUMERATED, both non-empty         → rc 0, and the reconciled claim IS
#       emitted: the only state that reaches the green line. (5) also exits 0, so without
#       this one every assertion about that claim is an assertion about its ABSENCE.
#
# STATES 1 AND 5 ARE BOTH BUILT ON THE SHIPPED EMPTY GUARD_SET: a fixture that always
# declares a populated set passes against it by construction.
# =============================================================================

# Add one record to the sandbox's GUARD_SET, self-asserting like _declare_gate.
_guard_declare() {  # <verify.sh> <entry>
  local v="$1" e="$2"
  grep -qE '^GUARD_SET=\($' "$v" \
    || _fixture_die "_guard_declare: no '^GUARD_SET=(' line in the sandbox's verify.sh — the anchor moved, so '$e' was NOT declared and the case would run against an empty floor."
  perl -i -pe 'BEGIN{$r=shift} $_ .= "  $r\n" if /^GUARD_SET=\($/' "$e" "$v"
  grep -qxF "  $e" "$v" \
    || _fixture_die "_guard_declare: '$e' is not in GUARD_SET after the insert."
}

# Declare the enumerator command. _neu_scalar asserts the line reads what we wrote.
# THE COMMAND MUST CONTAIN NO BACKSLASH ESCAPE: _neu_scalar rewrites the line through perl,
# so a `\n` splits the assignment, and verify.sh then reads GUARD_ENUM as unset and exits 0.
# Use `echo`, which supplies its own newline, and `true` for the deliberately-empty
# enumeration.
_guard_enum() {  # <verify.sh> <command>
  _neu_scalar "$1" GUARD_ENUM "GUARD_ENUM=\"$2\""
}

case_guard_floor_unenrolled_from_shipped_empty_set() {
  cf_reset
  make_sandbox
  local v="$SB_WORK/scripts/verify.sh" out rc
  # THE SHIPPED STATE: GUARD_SET stays EMPTY (the neutralizer left it so). A guard
  # exists on disk and the enumeration finds it; nothing declares it.
  : > "$SB_WORK/guard-a.txt"
  _guard_enum "$v" "echo guard-a.txt"
  out="$( cd "$SB_WORK" && "$v" --scope some/item 2>&1 )"; rc=$?

  [ "$rc" -eq 2 ] \
    || cf "(unenrolled) exit $rc, expected 2 — an enumerated guard that GUARD_SET does not declare must refuse"
  printf '%s' "$out" | grep -F 'guard-a.txt' >/dev/null \
    || cf "(unenrolled) the refusal does not NAME the unenrolled guard, so an operator cannot act on it: $out"

  finish "guard floor: a guard the enumeration lists and the SHIPPED EMPTY GUARD_SET does not declare refuses (rc 2) and names it"
  teardown
}

case_guard_floor_enumerator_mistyped() {
  cf_reset
  make_sandbox
  local v="$SB_WORK/scripts/verify.sh" out rc probe_rc
  : > "$SB_WORK/guard-a.txt"
  _guard_declare "$v" 'guard-a.txt'
  # A MIS-TYPED command, not a missing one: the probe must exit NON-ZERO AND NOT 127, or it
  # cannot tell treating "non-zero" as "not found" from the fixed behaviour.
  ( cd "$SB_WORK" && git ls-fils 'guard-*' ) >/dev/null 2>&1; probe_rc=$?
  { [ "$probe_rc" -ne 0 ] && [ "$probe_rc" -ne 127 ]; } \
    || _fixture_die "case_guard_floor_enumerator_mistyped: the mis-typed enumerator exited $probe_rc — this case needs a non-zero that is NOT 127, or it cannot tell the fixed behaviour from the defect."
  _guard_enum "$v" "git ls-fils 'guard-*'"
  out="$( cd "$SB_WORK" && "$v" --scope some/item 2>&1 )"; rc=$?

  [ "$rc" -eq 2 ] \
    || cf "(mis-typed) exit $rc, expected 2 — an enumerator that did not run cleanly must refuse rather than reconcile against its empty output"
  # WHICH REFUSAL FIRED — not merely that one did. Both refusal arms exit 2 and echo
  # $GUARD_ENUM back, so the arm is asserted by a token ONLY THAT ARM prints:
  printf '%s' "$out" | grep -F 'did not run cleanly (exit' >/dev/null \
    || cf "(mis-typed) the UNRUNNABLE arm did not fire — a non-zero enumerator was reported as having run cleanly, which is the defect this case exists for: $out"
  # ...and the enumerator's own stderr by a token ONLY THE ENUMERATOR can produce. 'ls-fils'
  # is verify.sh quoting the command back; "not a git command" is git itself speaking, and
  # it reaches the operator only if the stderr capture is actually surfaced.
  printf '%s' "$out" | grep -F 'not a git command' >/dev/null \
    || cf "(mis-typed) the enumerator's own stderr was swallowed, so the operator cannot see WHY it failed: $out"

  finish "guard floor: a MIS-TYPED enumerator (non-zero, not 127) refuses (rc 2) and surfaces the enumerator's own stderr"
  teardown
}

case_guard_floor_enumerator_succeeds_empty() {
  cf_reset
  make_sandbox
  local v="$SB_WORK/scripts/verify.sh" out rc probe_rc probe_out
  : > "$SB_WORK/guard-a.txt"
  _guard_declare "$v" 'guard-a.txt'
  # THE REALISTIC SHAPE: `git ls-files` over a guard that is not yet TRACKED exits 0 and
  # prints nothing. A fixture built on a FAILING command cannot reach this path — the
  # defect here is a command that works.
  probe_out="$( cd "$SB_WORK" && git ls-files 'guard-a.txt' 2>/dev/null )"; probe_rc=$?
  { [ "$probe_rc" -eq 0 ] && [ -z "$probe_out" ]; } \
    || _fixture_die "case_guard_floor_enumerator_succeeds_empty: the probe exited $probe_rc with output '$probe_out' — this case needs exit 0 AND empty output, or it is testing the mis-typed path again."
  _guard_enum "$v" "git ls-files 'guard-a.txt'"
  out="$( cd "$SB_WORK" && "$v" --scope some/item 2>&1 )"; rc=$?

  [ "$rc" -eq 2 ] \
    || cf "(empty-but-clean) exit $rc, expected 2 — an enumerator that ran cleanly and saw NOTHING while GUARD_SET declares items must refuse, not reconcile"
  # KEYED ON THE CLAIM'S OWN FORM: the NOTE that DENIES reconciliation contains "was
  # reconciled", so a bare grep for the word fires on correct output.
  printf '%s' "$out" | grep 'reconciled BOTH ways' >/dev/null \
    && cf "(empty-but-clean) the run claimed reconciliation over an enumeration that returned nothing: $out"

  finish "guard floor: an enumerator that SUCCEEDS and returns nothing over a populated GUARD_SET refuses (rc 2) and claims no reconciliation"
  teardown
}

case_guard_floor_unseen_declared_guard() {
  cf_reset
  make_sandbox
  local v="$SB_WORK/scripts/verify.sh" out rc
  # TWO guards on disk, BOTH declared, and the enumerator scoped to ONE: the SET − SPACE
  # direction (the `unseen` loop).
  : > "$SB_WORK/guard-a.txt"; : > "$SB_WORK/guard-b.txt"
  _guard_declare "$v" 'guard-a.txt'
  _guard_declare "$v" 'guard-b.txt'
  _guard_enum "$v" "echo guard-a.txt"
  out="$( cd "$SB_WORK" && "$v" --scope some/item 2>&1 )"; rc=$?

  [ "$rc" -eq 2 ] \
    || cf "(unseen) exit $rc, expected 2 — a DECLARED guard the enumeration cannot see is not reconciled by it"
  # WHICH SIDE NAMES ITEMS is the discriminator: the UNSEEN guard must be named. Both
  # paths appear in the file, so naming guard-b is what distinguishes this direction
  # from the other one.
  printf '%s' "$out" | grep -F 'guard-b.txt' >/dev/null \
    || cf "(unseen) the refusal does not name the DECLARED guard the enumeration missed: $out"

  finish "guard floor: a DECLARED guard outside the enumeration's scope refuses (rc 2) and names the unseen one — the SET − SPACE direction"
  teardown
}

# THE POSITIVE ARM. The other assertions on "reconciled BOTH ways" are negative (`&& cf`),
# so a reworded success line would leave them green over a claim no longer emitted. A
# phrase asserted only by its absence is not asserted.
case_guard_floor_reconciles_and_says_so() {
  cf_reset
  make_sandbox
  local v="$SB_WORK/scripts/verify.sh" out rc
  # DECLARED == ENUMERATED, exactly. Neither direction has anything to report, which is the
  # only state that reaches the green line.
  : > "$SB_WORK/guard-a.txt"; : > "$SB_WORK/guard-b.txt"
  _guard_declare "$v" 'guard-a.txt'
  _guard_declare "$v" 'guard-b.txt'
  _guard_enum "$v" "printf '%s\\n' guard-a.txt guard-b.txt"
  out="$( cd "$SB_WORK" && "$v" --scope some/item 2>&1 )"; rc=$?

  [ "$rc" -eq 0 ] \
    || cf "(reconciled) exit $rc, expected 0 — a GUARD_SET the enumeration matches exactly is the reconciled state and must not refuse: $out"
  printf '%s' "$out" | grep 'reconciled BOTH ways' >/dev/null \
    || cf "(reconciled) the run did NOT emit the reconciliation claim over a set the enumeration matches exactly, so the phrase the canary cases assert the ABSENCE of is emitted by nothing: $out"
  # THE COUNT TOO, because the green line is the one most mistakable for a measurement of the
  # tree: two guards declared must read as two, not as whatever the shipped set happened to hold.
  printf '%s' "$out" | grep '2 DECLARED item(s)' >/dev/null \
    || cf "(reconciled) the green line does not report the 2 DECLARED items this case set up: $out"

  finish "guard floor: a GUARD_SET the enumeration matches exactly reconciles, exits 0 and SAYS SO — the positive direction the absence canaries cannot prove"
  teardown
}

case_guard_floor_wholly_empty_shipped_state() {
  cf_reset
  make_sandbox
  local v="$SB_WORK/scripts/verify.sh" out rc
  # THE SHIPPED STATE, END TO END: GUARD_SET empty, an enumerator declared, and nothing
  # to find. Setting GUARD_ENUM before writing a first guard is legitimate, so this must
  # NOT refuse — and it must not claim a reconciliation it did not perform either.
  _guard_enum "$v" "true"
  out="$( cd "$SB_WORK" && "$v" --scope some/item 2>&1 )"; rc=$?

  [ "$rc" -eq 0 ] \
    || cf "(wholly empty) exit $rc, expected 0 — declaring GUARD_ENUM before the first guard exists is legitimate and must not refuse"
  # The one assertion here that touches the claim's wording, unavoidably: both states exit
  # 0. Keyed on the claim's own phrase, not on "reconciled", which the denying NOTE uses.
  printf '%s' "$out" | grep 'reconciled BOTH ways' >/dev/null \
    && cf "(wholly empty) the run claimed reconciliation with an empty GUARD_SET and an empty enumeration — nothing was reconciled: $out"

  finish "guard floor: the wholly-empty shipped state exits 0 with a NOTE and claims no reconciliation"
  teardown
}

# =============================================================================
# CASE — THE GATE RUNNER'S OWN CONTRACT.
#
# NO CAPABILITY PROBE on verify.sh having any particular gate: it would turn a gutted frame
# into a SKIP instead of a FAIL. Everything here is pure bash.
#
# The properties:
#   (a) an EMPTY gate table REFUSES (nonzero) instead of printing a green summary
#       with nothing behind it — an empty-but-passing runner silently authorises
#       every landing, because finish-pr.sh treats a green --quick as its gate;
#   (b) --list answers even an empty table (it is the question an adopter asks);
#   (c) exit codes are UNLAUNDERED: a red gate makes the run exit nonzero and the
#       summary name it;
#   (d) --quick skips the `full` class and only that;
#   (e) --scope runs the `select` gate with the selection PLUS the whole guard
#       floor, and a vanished guard is a hard stop rather than a silent shrink.
# =============================================================================
case_verify_frame() {
  cf_reset
  make_sandbox                     # make_sandbox already declared one select gate
  local v="$SB_WORK/scripts/verify.sh" out rc

  # (a) empty table refuses. Strip the gate this sandbox declared.
  perl -i -ne 'print unless /sandbox gate\|select/' "$v"
  out="$( cd "$SB_WORK" && "$v" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) an EMPTY gate table exited 0 — a runner with no gates must never look green"
  printf '%s' "$out" | grep 'REFUSING' >/dev/null || cf "(a) the empty-table refusal is not stated: $out"
  # (b) --list still answers.
  out="$( cd "$SB_WORK" && "$v" --list 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) --list exited $rc on an empty table (it is informational)"
  printf '%s' "$out" | grep '0 declared gate' >/dev/null || cf "(b) --list does not report the empty table: $out"

  # Re-declare: one green select gate, one red full gate, one guard path.
  # THE RED GATE IS A SANDBOX-LOCAL SCRIPT, not `/usr/bin/false`: an absent system binary
  # returns 127, which is UNRUNNABLE rather than FAIL.
  : > "$SB_WORK/guard-one.txt"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$SB_WORK/red-gate"; chmod +x "$SB_WORK/red-gate"
  _declare_gate 'green|select|/bin/echo ran-green'
  _declare_gate 'redbuild|full|./red-gate'
  _guard_declare "$v" guard-one.txt

  # (c) unlaundered exit codes.
  out="$( cd "$SB_WORK" && "$v" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(c) a red gate did not make the run exit nonzero"
  printf '%s' "$out" | grep 'FAIL  redbuild' >/dev/null || cf "(c) the summary does not name the failed gate: $out"
  printf '%s' "$out" | grep 'PASS  green' >/dev/null    || cf "(c) the summary does not name the passing gate: $out"

  # (d) --quick skips the `full` class and only that.
  out="$( cd "$SB_WORK" && "$v" --quick 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(d) --quick exited $rc despite the only red gate being class full"
  printf '%s' "$out" | grep 'SKIP  redbuild' >/dev/null || cf "(d) --quick did not skip the full-class gate: $out"
  printf '%s' "$out" | grep 'PASS  green' >/dev/null    || cf "(d) --quick skipped the select-class gate too: $out"

  # (e) --scope passes the selection PLUS the guard floor to the select gate.
  out="$( cd "$SB_WORK" && "$v" --scope some/item 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(e) the scoped run exited $rc: $out"
  printf '%s' "$out" | grep 'some/item' >/dev/null || cf "(e) the scoped run did not pass the requested item: $out"
  # `some/item` matches nothing, and the gate still passes: the frame cannot resolve an item, so the
  # quoted block must say whose word "matched" is.
  printf '%s\n' "$out" | grep '^SCOPE: NARROWED' | grep -F "the runner's word, not this frame's" >/dev/null \
    || cf "(e) the SCOPE line does not say the runner, not the frame, decides whether an item matched: $out"
  printf '%s' "$out" | grep 'guard-one.txt' >/dev/null \
    || cf "(e) the scoped run did not append the GUARD_SET floor — a scoped run must never be narrower than the guards: $out"
  # ...and a vanished guard is a hard stop.
  rm -f "$SB_WORK/guard-one.txt"
  out="$( cd "$SB_WORK" && "$v" --scope some/item 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(e) a vanished guard did not stop the scoped run — the floor shrank silently"
  printf '%s' "$out" | grep 'guard-one.txt' >/dev/null || cf "(e) the vanished-guard refusal does not name the path: $out"

  finish "verify.sh frame: empty table REFUSES, --list answers anyway, exit codes unlaundered, --quick skips only 'full', --scope appends the guard floor, says the runner resolves its items, and a vanished guard is a hard stop"
  teardown
}

# =============================================================================
# CASE — UNRUNNABLE IS NOT FAIL, AND `ran` EXCLUDES IT.
#
# verify.sh has four result states: PASS, FAIL, SKIP and UNRUNNABLE. 127 (command not
# found) and 126 (found, not executable) are statements about the RUNNER'S ENVIRONMENT: the
# gate never executed, so nothing was measured.
#
# BOTH ASSERTIONS THAT MATTER ARE THE SECOND DIRECTION:
#   • `FAIL <gate>` must be ABSENT for an unrunnable gate: asserting UNRUNNABLE is present
#     cannot catch a regression that emits both or re-merges the states;
#   • `ran:` must EXCLUDE the unrunnable, or the count line contradicts its per-gate lines.
# =============================================================================
case_verify_unrunnable_vs_fail() {
  cf_reset
  make_sandbox
  # Ship-state first: make_sandbox declares its own always-green gate, and this case
  # needs to control the whole table.
  _neu_array "$SB_WORK/scripts/verify.sh" GATES
  # THE FAILING GATE IS A SANDBOX-LOCAL SCRIPT, NOT `/bin/false`, which is absent on some
  # platforms and would return 127: a portability slip in the fixture would then be
  # indistinguishable from the defect under test.
  printf '#!/usr/bin/env bash\nexit 1\n' > "$SB_WORK/failing-gate"
  chmod +x "$SB_WORK/failing-gate"
  _declare_gate 'green|core|/bin/echo gate-ran-green'
  _declare_gate 'broken|core|./failing-gate'
  _declare_gate 'missing-interp|core|/nonexistent-dir-for-the-harness/interpreter'
  publish_sandbox

  local v="$SB_WORK/scripts/verify.sh" out rc counts
  out="$( cd "$SB_WORK" && "$v" 2>&1 )"; rc=$?

  # A red run, and red for a reason that includes an unknown.
  [ "$rc" -ne 0 ] || cf "verify.sh exited 0 with a failing gate and an unrunnable one: $out"

  # --- the three states, each present in its OWN vocabulary ------------------
  printf '%s\n' "$out" | grep '^PASS  green$' >/dev/null \
    || cf "no 'PASS  green' line — the runnable-and-green gate is not reported: $out"
  printf '%s\n' "$out" | grep '^FAIL  broken (rc=1)$' >/dev/null \
    || cf "no 'FAIL  broken (rc=1)' line — a genuinely failing gate must still say FAIL: $out"
  printf '%s\n' "$out" | grep '^UNRUNNABLE  missing-interp ' >/dev/null \
    || cf "no 'UNRUNNABLE  missing-interp' line — the fourth state is not being reported: $out"
  printf '%s\n' "$out" | grep '^UNRUNNABLE  missing-interp ' | grep 'rc=127' >/dev/null \
    || cf "the UNRUNNABLE line does not carry rc=127: $(printf '%s\n' "$out" | grep '^UNRUNNABLE')"
  printf '%s\n' "$out" | grep '^UNRUNNABLE  missing-interp ' | grep -i 'NOTHING was measured' >/dev/null \
    || cf "the UNRUNNABLE line does not say nothing was measured — the label alone leaves the reader to guess: $(printf '%s\n' "$out" | grep '^UNRUNNABLE')"

  # --- THE SECOND DIRECTION: the states must not have collapsed either way ---
  printf '%s\n' "$out" | grep '^FAIL  missing-interp' >/dev/null \
    && cf "the unrunnable gate ALSO produced a 'FAIL' line — the two states are merged: $out"
  printf '%s\n' "$out" | grep '^UNRUNNABLE  broken' >/dev/null \
    && cf "a genuinely FAILING gate was labelled UNRUNNABLE — the states are merged in the other direction, and a real red now reads as an environment problem: $out"

  # --- the count line, and `ran` EXCLUDING the unrunnable --------------------
  counts="$(printf '%s\n' "$out" | grep '^gates declared:' || true)"
  [ -n "$counts" ] || cf "no 'gates declared:' count line — verify-gate.md § 4: a pass with no count is an assertion, not a measurement: $out"
  printf '%s' "$counts" | grep 'gates declared: 3' >/dev/null || cf "the count line does not report 3 declared gates: $counts"
  printf '%s' "$counts" | grep 'ran: 2' >/dev/null \
    || cf "REGRESSION — 'ran' does not exclude the unrunnable gate (expected 'ran: 2' of 3 declared). The count line is re-merging the two states the per-gate lines separate: $counts"
  printf '%s' "$counts" | grep 'passed: 1' >/dev/null        || cf "the count line does not report 1 passed: $counts"
  printf '%s' "$counts" | grep 'failed: 1' >/dev/null        || cf "the count line does not report 1 failed: $counts"
  printf '%s' "$counts" | grep 'could not run: 1' >/dev/null || cf "the count line does not report 1 could-not-run: $counts"
  printf '%s' "$counts" | grep 'skipped: 0' >/dev/null       || cf "the count line does not report 0 skipped: $counts"
  # And the block says what an unrunnable gate MEANS, since a reader quotes this block.
  printf '%s\n' "$out" | grep -i 'UNKNOWN, not a measured failure' >/dev/null \
    || cf "the summary does not say the unrunnable gate is an UNKNOWN rather than a failure: $out"

  # --- rc=126 is the same state: found, but not executable ------------------
  # The implementation claims {126,127}, so both are held. A file that exists and is
  # not executable is the other half, and it is the half a chmod regression breaks.
  _neu_array "$v" GATES
  printf '#!/usr/bin/env bash\necho should-never-run\n' > "$SB_WORK/not-executable-gate"
  chmod 0644 "$SB_WORK/not-executable-gate"
  _declare_gate 'green|core|/bin/echo gate-ran-green'
  _declare_gate 'not-exec|core|./not-executable-gate'
  publish_sandbox
  out="$( cd "$SB_WORK" && "$v" 2>&1 )"; rc=$?
  if printf '%s\n' "$out" | grep '^UNRUNNABLE  not-exec '; then >/dev/null
    printf '%s\n' "$out" | grep '^UNRUNNABLE  not-exec ' | grep 'rc=126' >/dev/null \
      || cf "the non-executable gate is UNRUNNABLE but not at rc=126: $(printf '%s\n' "$out" | grep '^UNRUNNABLE')"
    printf '%s\n' "$out" | grep '^FAIL  not-exec' >/dev/null \
      && cf "the non-executable gate produced BOTH UNRUNNABLE and FAIL: $out"
    printf '%s\n' "$out" | grep '^gates declared:' | grep 'ran: 1' >/dev/null \
      || cf "'ran' does not exclude the rc=126 gate: $(printf '%s\n' "$out" | grep '^gates declared:')"
    [ "$rc" -ne 0 ] || cf "verify.sh exited 0 with an unrunnable gate — finish-pr treats a green --quick as a landing precondition: $out"
  else
    # Not every shell/platform returns 126 here. That is an environment fact, not a
    # defect, and it is reported as one rather than quietly passing or failing.
    skp "verify.sh: rc=126 (found, not executable) is UNRUNNABLE" "this platform did not produce rc=126 for a non-executable gate command; the rc=127 half is asserted in the case above"
  fi

  finish "verify.sh: UNRUNNABLE is reported for rc=127 and is NOT also FAIL, a real failure is still FAIL and NOT unrunnable, and the count line's 'ran' EXCLUDES the gate that never executed"
  teardown
}

# =============================================================================
# CASE — verify.sh's EXIT STATUS SEPARATES THE TWO REDS, as its summary does.
#
# Callers that read the status (the landing script's post-merge check is one) must tell
# "your tree is broken" from "this gate could not start" without parsing prose:
#   0  every gate that ran passed and none was unrunnable;
#   1  at least one gate FAILED — whatever else happened (a measured failure dominates);
#   3  nothing failed, and at least one gate COULD NOT RUN — an unknown, still red.
# (2 stays the runner's own refusal: an empty or malformed table, an unknown argument.)
# THE FOUR ROWS ARE THE PRECEDENCE, and each holds the summary beside the status, so a
# status that moved without its count line — or the reverse — reddens.
# =============================================================================
case_verify_exit_status_separates_the_reds() {
  cf_reset
  make_sandbox
  printf '#!/usr/bin/env bash\nexit 1\n' > "$SB_WORK/failing-gate"; chmod +x "$SB_WORK/failing-gate"
  local v="$SB_WORK/scripts/verify.sh" out rc
  # _vx_row <label> <want rc> <want failed> <want could-not-run> <gate record…>
  _vx_row() {
    local L="$1" want="$2" wf="$3" wu="$4"; shift 4
    _neu_array "$v" GATES
    local g; for g in "$@"; do _declare_gate "$g"; done
    rc=0; out="$( cd "$SB_WORK" && "$v" 2>&1 )" || rc=$?
    [ "$rc" -eq "$want" ] || cf "($L) exit $rc, expected $want: $(printf '%s\n' "$out" | grep -E '^(PASS|FAIL|UNRUNNABLE) |^gates declared:' | tr '\n' '|')"
    printf '%s\n' "$out" | grep '^gates declared:' | grep "failed: $wf · could not run: $wu " >/dev/null \
      || cf "($L) the summary does not count failed: $wf and could not run: $wu: $(printf '%s\n' "$out" | grep '^gates declared:')"
  }
  _vx_row "none"        0 0 0 'green|core|/bin/echo ok'
  _vx_row "failed only" 1 1 0 'green|core|/bin/echo ok' 'broken|core|./failing-gate'
  _vx_row "unrunnable only" 3 0 1 'green|core|/bin/echo ok' 'missing|core|/nonexistent-dir-for-the-harness/interpreter'
  _vx_row "both — a failure dominates" 1 1 1 'broken|core|./failing-gate' 'missing|core|/nonexistent-dir-for-the-harness/interpreter'
  unset -f _vx_row
  finish "verify.sh's exit status separates the two reds: 0 green, 1 when any gate FAILED (it dominates), 3 when nothing failed and a gate COULD NOT RUN — each row agreeing with the summary's counts"
  teardown
}

# =============================================================================
# CASE — A STACKED BRANCH WHOSE BASE IS STILL UNLANDED refuses, naming the exact
# `git rebase --onto` step, before anything destructive.
#
# feature/<A> branches off the trunk; feature/<B> branches off feature/<A>, so B's history
# carries A's commits. A is never landed. finish-pr.sh on B must refuse rather than squash A's
# unreviewed work in under B's issue.
# =============================================================================
case_finish_pr_stacked_branch_unlanded_base_refuses() {
  cf_reset
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-820" stacked chore "Stacked on an unlanded base" "feature/$SB_PREFIX-820-b"
  publish_sandbox
  git -C "$SB_WORK" branch "feature/$SB_PREFIX-820-a" "$SB_TRUNK" >/dev/null 2>&1

  git -C "$SB_WORK" checkout -q "feature/$SB_PREFIX-820-a" >/dev/null 2>&1
  echo "a's change" > "$SB_WORK/A.txt"
  git -C "$SB_WORK" add A.txt >/dev/null 2>&1
  sbcommit -m "[Dev] $SB_PREFIX-820: base work" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/$SB_PREFIX-820-a" --quiet >/dev/null 2>&1

  git -C "$SB_WORK" branch "feature/$SB_PREFIX-820-b" "feature/$SB_PREFIX-820-a" >/dev/null 2>&1
  git -C "$SB_WORK" checkout -q "feature/$SB_PREFIX-820-b" >/dev/null 2>&1
  echo "b's change" > "$SB_WORK/B.txt"
  git -C "$SB_WORK" add B.txt >/dev/null 2>&1
  sbcommit -m "[Dev] $SB_PREFIX-820: stacked work" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/$SB_PREFIX-820-b" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" ./scripts/finish-pr.sh "$SB_PREFIX-820" 2>&1 )"; rc=$?

  [ "$rc" -eq 1 ] || cf "finish-pr exited $rc (expected 1 — refused): $out"
  printf '%s\n' "$out" | grep -F "stacked on 'feature/$SB_PREFIX-820-a'" >/dev/null \
    || cf "refusal does not name the unlanded base branch: $out"
  printf '%s\n' "$out" | grep -F "git rebase --onto $SB_TRUNK feature/$SB_PREFIX-820-a feature/$SB_PREFIX-820-b" >/dev/null \
    || cf "refusal does not print the exact rebase --onto step: $out"
  origin_has_path "progress/qa_complete/$SB_PREFIX-820-stacked.md" \
    && cf "NOTHING WAS CHANGED was violated — the issue advanced anyway"
  git -C "$SB_WORK" rev-parse --verify --quiet "refs/heads/feature/$SB_PREFIX-820-b" >/dev/null 2>&1 \
    || cf "the stacked branch was deleted despite the refusal"

  finish "finish-pr.sh refuses a branch stacked on a still-unlanded base, naming the base and the exact git rebase --onto step"
  teardown
}

# =============================================================================
# CASE — RED FIRST, THEN GREEN, for the squash-landed half of the same defect: once the base
# is rebased away, the SAME branch lands cleanly.
#
# feature/<A> squash-lands to the trunk (as finish-pr.sh itself would do it); feature/<B>,
# stacked on A's original (now unreachable) commits, still carries them. finish-pr.sh on B
# must refuse, naming the squash and the rebase step; after `git rebase --onto` it must land.
# =============================================================================
case_finish_pr_stacked_branch_squashed_base_refuses() {
  cf_reset
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-821" astacked chore "Base branch" "feature/$SB_PREFIX-821-a"
  seed_issue dev_complete "$SB_PREFIX-822" bstacked chore "Stacked on a squash-landed base" "feature/$SB_PREFIX-821-b"
  publish_sandbox
  git -C "$SB_WORK" branch "feature/$SB_PREFIX-821-a" "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" branch "feature/$SB_PREFIX-821-b" "$SB_TRUNK" >/dev/null 2>&1

  git -C "$SB_WORK" checkout -q "feature/$SB_PREFIX-821-a" >/dev/null 2>&1
  echo "a1" > "$SB_WORK/A.txt"
  git -C "$SB_WORK" add A.txt >/dev/null 2>&1
  sbcommit -m "[Dev] $SB_PREFIX-821: a1" --quiet >/dev/null 2>&1
  echo "a2" >> "$SB_WORK/A.txt"
  sbcommit -am "[Dev] $SB_PREFIX-821: a2" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/$SB_PREFIX-821-a" --quiet >/dev/null 2>&1

  git -C "$SB_WORK" branch -f "feature/$SB_PREFIX-821-b" "feature/$SB_PREFIX-821-a" >/dev/null 2>&1
  git -C "$SB_WORK" checkout -q "feature/$SB_PREFIX-821-b" >/dev/null 2>&1
  echo "b's change" > "$SB_WORK/B.txt"
  git -C "$SB_WORK" add B.txt >/dev/null 2>&1
  sbcommit -m "[Dev] $SB_PREFIX-822: stacked work" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/$SB_PREFIX-821-b" --quiet >/dev/null 2>&1

  # Squash-land the base directly onto the trunk (the same shape finish-pr.sh itself produces),
  # then retire the base branch — the shape the card's problem statement describes.
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" merge --squash "feature/$SB_PREFIX-821-a" --quiet >/dev/null 2>&1
  sbcommit -m "[QA] $SB_PREFIX-821: a1+a2 (squash-merge feature/$SB_PREFIX-821-a)" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push origin "$SB_TRUNK" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push origin --delete "feature/$SB_PREFIX-821-a" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" branch -D "feature/$SB_PREFIX-821-a" --quiet >/dev/null 2>&1

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" ./scripts/finish-pr.sh "$SB_PREFIX-822" 2>&1 )"; rc=$?

  # ── RED: the base is gone (no ref left names it), yet the refusal still fires — from the
  #      patch-id match against the trunk's own squash commit, not from a live ref.
  [ "$rc" -eq 1 ] || cf "(red) finish-pr exited $rc (expected 1 — refused): $out"
  printf '%s\n' "$out" | grep -F "already squash-landed on $SB_TRUNK" >/dev/null \
    || cf "(red) refusal does not say the base already squash-landed: $out"
  local rebase_cmd
  rebase_cmd="$(printf '%s\n' "$out" | grep -oE "git rebase --onto $SB_TRUNK [0-9a-f]+ feature/$SB_PREFIX-821-b" | head -1)"
  [ -n "$rebase_cmd" ] || cf "(red) refusal does not print a git rebase --onto step naming the branch: $out"
  origin_has_path "progress/qa_complete/$SB_PREFIX-822-bstacked.md" \
    && cf "(red) NOTHING WAS CHANGED was violated — the issue advanced anyway"

  # ── GREEN: run the printed command, then land.
  if [ -n "$rebase_cmd" ]; then
    ( cd "$SB_WORK" && eval "$rebase_cmd" ) >/dev/null 2>&1 \
      || cf "(green) the printed rebase --onto command itself failed"
    git -C "$SB_WORK" push -u origin "feature/$SB_PREFIX-821-b" --force --quiet >/dev/null 2>&1
    out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" ./scripts/finish-pr.sh "$SB_PREFIX-822" 2>&1 )"; rc=$?
    [ "$rc" -eq 0 ] || cf "(green) finish-pr still refused after the rebase (rc=$rc): $out"
    origin_has_path "progress/qa_complete/$SB_PREFIX-822-bstacked.md" \
      || cf "(green) issue not advanced to qa_complete/ after the rebase"
    origin_has_path "B.txt" || cf "(green) the rebased branch's own change did not land"
  fi

  finish "finish-pr.sh refuses a branch stacked on a since-squash-landed base (detected by patch-id, no live ref needed), names the rebase --onto step, and lands cleanly once it is run"
  teardown
}

# =============================================================================
# CASE — A STACKED BRANCH WHOSE BASE LANDED THROUGH finish-pr.sh WHILE A WORKTREE HELD THE
# BASE'S BRANCH. The landing keeps that local ref (LOCAL BRANCH KEPT), so a ref-only check
# finds the ref inside the stacked branch's history and says the base "has not landed".
# It has: its patch-id is on the trunk. The refusal must say so, and the printed
# `git rebase --onto` line must still land the branch.
# Controls: a base that has not landed still says so (case_..._unlanded_base_refuses), and a
# base that landed with its ref deleted still says squash-landed (case_..._squashed_base_refuses).
# =============================================================================
case_finish_pr_stacked_branch_landed_base_ref_kept_refuses_as_squash_landed() {
  cf_reset
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-823" kbase chore "Base held by a worktree" "feature/$SB_PREFIX-823-a"
  seed_issue dev_complete "$SB_PREFIX-824" ktop chore "Stacked on a landed base" "feature/$SB_PREFIX-823-b"
  publish_sandbox
  seed_branch "$SB_PREFIX-823" a A.txt
  git -C "$SB_WORK" checkout -q -b "feature/$SB_PREFIX-823-b" "feature/$SB_PREFIX-823-a" >/dev/null 2>&1
  echo "b's change" > "$SB_WORK/B.txt"
  git -C "$SB_WORK" add B.txt >/dev/null 2>&1
  sbcommit -m "[Dev] $SB_PREFIX-824: stacked work" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/$SB_PREFIX-823-b" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1

  # Land the base through the script with a second worktree holding its branch.
  git -C "$SB_WORK" worktree add -q "$SB_TMP/wt-base" "feature/$SB_PREFIX-823-a" >/dev/null 2>&1 \
    || cf "could not create the worktree holding the base branch (test setup)"
  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" ./scripts/finish-pr.sh "$SB_PREFIX-823" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || _control_did_not_run "landing the base through finish-pr.sh (rc=$rc): $out"
  git -C "$SB_WORK" rev-parse --verify --quiet "refs/heads/feature/$SB_PREFIX-823-a" >/dev/null 2>&1 \
    || _control_did_not_run "the base's local branch survives its landing"

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" ./scripts/finish-pr.sh "$SB_PREFIX-824" 2>&1 )"; rc=$?

  [ "$rc" -eq 1 ] || cf "finish-pr exited $rc (expected 1 — refused): $out"
  printf '%s\n' "$out" | grep -F "already squash-landed on $SB_TRUNK" >/dev/null \
    || cf "refusal does not say the base already squash-landed: $out"
  printf '%s\n' "$out" | grep -F "has not landed" >/dev/null \
    && cf "refusal says the base 'has not landed' although its patch-id is on the trunk: $out"
  printf '%s\n' "$out" | grep -F "feature/$SB_PREFIX-823-a" >/dev/null \
    || cf "refusal does not name the surviving base branch: $out"
  local rebase_cmd
  rebase_cmd="$(printf '%s\n' "$out" | grep -oE "git rebase --onto $SB_TRUNK [0-9a-f]+ feature/$SB_PREFIX-823-b" | head -1)"
  [ -n "$rebase_cmd" ] || cf "refusal does not print a git rebase --onto step naming the branch: $out"
  origin_has_path "progress/qa_complete/$SB_PREFIX-824-ktop.md" \
    && cf "NOTHING WAS CHANGED was violated — the issue advanced anyway"

  if [ -n "$rebase_cmd" ]; then
    git -C "$SB_WORK" worktree add -q "$SB_TMP/wt-top" "feature/$SB_PREFIX-823-b" >/dev/null 2>&1
    ( cd "$SB_TMP/wt-top" && eval "$rebase_cmd" ) >/dev/null 2>&1 \
      || cf "the printed rebase --onto command itself failed"
    git -C "$SB_TMP/wt-top" push --force --quiet origin "feature/$SB_PREFIX-823-b" >/dev/null 2>&1
    git -C "$SB_WORK" worktree remove --force "$SB_TMP/wt-top" >/dev/null 2>&1
    out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" ./scripts/finish-pr.sh "$SB_PREFIX-824" 2>&1 )"; rc=$?
    [ "$rc" -eq 0 ] || cf "finish-pr still refused after the rebase (rc=$rc): $out"
    origin_has_path "B.txt" || cf "the rebased branch's own change did not land"
  fi

  finish "finish-pr.sh says a stacked branch's base has already squash-landed, never that it has not landed, when the base's own local branch was left behind by a worktree; the printed rebase step lands the branch"
  teardown
}

# =============================================================================
# CASE — verify.sh PRINTS A NOTE AT START WHEN A GUARD FLOOR IS DECLARED AND NO GATE IS `select`.
#
# GUARD_SET/GUARD_ENUM are only ever reconciled inside the --scope preflight, and --scope
# refuses outright when no gate is classed `select`. So a project whose gates are all `core`
# can declare a guard floor that nothing reads; the NOTE says so. Strip the sandbox's one
# `select` gate (make_sandbox declares it by default) to reproduce the all-core shape, declare
# a guard, and check the NOTE is printed and that a `select` gate makes it go away.
# =============================================================================
case_verify_all_core_guard_floor_is_reported_inert() {
  cf_reset
  make_sandbox                     # make_sandbox already declared one select gate
  local v="$SB_WORK/scripts/verify.sh" out rc

  # All-core: strip the one select gate this sandbox ships with, leaving only core/full.
  perl -i -ne 'print unless /sandbox gate\|select/' "$v"
  _declare_gate 'core check|core|/bin/echo ran-core'
  : > "$SB_WORK/guard-one.txt"
  _guard_declare "$v" guard-one.txt

  out="$( cd "$SB_WORK" && "$v" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "a full run with only core/full gates and a declared guard exited $rc, want 0: $out"
  # Two independent checks against the whole (multi-line) output, never a single-line
  # co-occurrence: the notice wraps its "NOTE" opener and its "never reconciled or run"
  # clause onto different echo lines, so a piped `grep NOTE | grep -F …` would see no line
  # holding both and fail even against a correct notice.
  printf '%s\n' "$out" | grep -F 'verify.sh: NOTE' >/dev/null \
    || cf "RED: a declared GUARD_SET on an all-core project prints no NOTE at all — this is the card's own bug: $out"
  printf '%s\n' "$out" | grep -F 'never reconciled or run' >/dev/null \
    || cf "RED: a declared GUARD_SET on an all-core project prints no notice that it is inert — this is the card's own bug: $out"

  # A --scope run still refuses outright (no select gate to take a selection) — the case the
  # notice exists to explain, not a second thing left unfixed.
  out="$( cd "$SB_WORK" && "$v" --scope some/item 2>&1 )"; rc=$?
  [ "$rc" -eq 2 ] || cf "--scope on an all-core project exited $rc, want 2 (REFUSING): $out"
  printf '%s\n' "$out" | grep 'no gate is classed' >/dev/null \
    || cf "--scope's own refusal message is missing: $out"

  # ── GREEN control: add a select gate back and the notice must disappear — the floor is now
  #    reachable, and a notice that never turns off would misreport every project forever.
  _declare_gate 'sandbox gate|select|/bin/echo sandbox-gate-green'
  out="$( cd "$SB_WORK" && "$v" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(control) a full run with a select gate present exited $rc: $out"
  printf '%s\n' "$out" | grep -F 'never reconciled or run' >/dev/null \
    && cf "(control) the notice still fires once a select gate exists — it no longer describes this configuration: $out"

  finish "verify.sh: a GUARD_SET/GUARD_ENUM declared on a project with no 'select' gate prints a NOTE at runner start that the floor is never reconciled or run (ablation-proven: the notice is present exactly when there is no select gate, and gone once one is declared); --scope itself still refuses outright, unchanged"
  teardown
}

# =============================================================================
# CASE — publish_sandbox AFTER A BOARD OP COMMITS NO GITLINK.
# The board mover leaves .kanban-wt/ behind; the sandbox excludes it, so a later `git add -A` in
# publish_sandbox leaves it out of the trunk commit. Control: the same publish without the exclude
# (removed in the case) does commit a mode-160000 entry, so the check has a subject.
# =============================================================================
case_publish_after_a_board_op_commits_no_gitlink() {
  cf_reset
  make_sandbox
  local id="$SB_PREFIX-910"
  seed_issue todo "$id" gl chore "Gitlink control"
  publish_sandbox
  if ! ( cd "$SB_WORK" && ./scripts/move-issue.sh "$id" in_progress --role "$SB_ROLE" --note "bootstrap the worktree" >/dev/null 2>&1 ) \
     || [ ! -d "$SB_WORK/.kanban-wt" ]; then
    skp "publish_sandbox after a board op commits no gitlink" "the board mover would not run here, so .kanban-wt was never created"
    teardown; return
  fi
  printf 'x\n' > "$SB_WORK/after-board-op.txt"
  publish_sandbox
  case "$(git -C "$SB_WORK" ls-tree -r HEAD)" in
    *"160000 "*) cf "publish_sandbox committed a mode-160000 entry (a gitlink) after a board op: $(git -C "$SB_WORK" ls-tree -r HEAD | grep '^160000' | tr '\n' '|')" ;;
  esac
  git -C "$SB_WORK" ls-tree -r --name-only HEAD | grep -x 'after-board-op.txt' >/dev/null \
    || cf "the second publish_sandbox did not commit the new file, so the gitlink check read a commit that is not the publish"
  # Control: with the exclude gone, the same publish does commit the worktree as a gitlink.
  : > "$SB_WORK/.git/info/exclude"
  printf 'y\n' > "$SB_WORK/control.txt"
  publish_sandbox
  case "$(git -C "$SB_WORK" ls-tree -r HEAD)" in
    *"160000 "*) : ;;
    *) cf "(control) without the exclude, publish_sandbox did not commit .kanban-wt as a gitlink — the check above has no subject" ;;
  esac
  finish "publish_sandbox after a board op leaves .kanban-wt out of the trunk commit (no mode-160000 entry); without the sandbox's exclude the same publish commits it, so the check has a subject"
  teardown
}

# =============================================================================
# CASE — A CARD EDITED ON THE WORK BRANCH: the overlapping edit is refused with the route named,
# the non-overlapping one still lands.
# Real order: the card is in_progress on the trunk, the branch is cut and edits the card, then the
# mover moves the card to dev_complete on the trunk with an Activity line, then QA lands.
# Rows: (a) the branch appends to the Activity the mover also appended to — the squash conflicts,
# the refusal (rule squash-conflict) names the ISSUE FILE, the trunk's ownership of the card and
# register-commit.sh, and nothing merges; (b) control — the branch edits the AC line, far from the
# Activity the mover appended to — the landing succeeds and the card advances.
# =============================================================================
_fpr_card_edit_land() {  # <id> <slug> <overlap|apart> — sets _FCE_OUT, _FCE_RC
  local id="$1" slug="$2" mode="$3" f
  seed_issue in_progress "$id" "$slug" chore "Card edited on the branch" "feature/$id-$slug"
  publish_sandbox
  git -C "$SB_WORK" checkout -q -b "feature/$id-$slug" "$SB_TRUNK" >/dev/null 2>&1 \
    || _fixture_die "_fpr_card_edit_land: could not cut feature/$id-$slug"
  f="$SB_WORK/progress/in_progress/$id-$slug.md"
  if [ "$mode" = overlap ]; then
    printf '%s\n' "- 2026-01-02 [Dev] Branch-side Activity line." >> "$f"
  else
    sed -i.bak 's/^- \[ \] AC1 .*/- [x] AC1 — the sandbox'"'"'s seeded behaviour holds./' "$f"; rm -f "$f.bak"
  fi
  echo "a real change" > "$SB_WORK/CE-$id.txt"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[Dev] $id: the branch work and the card" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/$id-$slug" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" checkout "$SB_TRUNK" --quiet >/dev/null 2>&1
  printf '%s\n' "- 2026-01-02 [Dev] Moved to dev_complete on the trunk." >> "$SB_WORK/progress/in_progress/$id-$slug.md"
  git -C "$SB_WORK" mv "progress/in_progress/$id-$slug.md" "progress/dev_complete/$id-$slug.md" >/dev/null 2>&1 \
    || _fixture_die "_fpr_card_edit_land: could not move $id to dev_complete on the trunk"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[Dev] $id: to dev_complete" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push origin "$SB_TRUNK" --quiet >/dev/null 2>&1
  _FCE_OUT="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-$id" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; _FCE_RC=$?
}

case_finish_pr_card_edited_on_the_branch_names_the_route() {
  cf_reset
  make_sandbox

  local ida="$SB_PREFIX-951"
  _fpr_card_edit_land "$ida" clash overlap
  [ "$_FCE_RC" -ne 0 ] || cf "(a) a branch and the mover both appending to the card's Activity — finish-pr.sh exited 0"
  grep -q "refusal=squash-conflict" "$SB_TMP/rec-$ida"/*.tsv 2>/dev/null \
    || cf "(a) no progress record carries refusal=squash-conflict: $(printf '%s' "$_FCE_OUT" | tr '\n' '|' | cut -c1-300)"
  case "$_FCE_OUT" in *"ISSUE FILE"*) : ;; *) cf "(a) the refusal does not name the ISSUE FILE: $(printf '%s' "$_FCE_OUT" | tr '\n' '|' | cut -c1-400)" ;; esac
  case "$_FCE_OUT" in *"register-commit.sh"*) : ;; *) cf "(a) the refusal does not name register-commit.sh as the route for the card: $(printf '%s' "$_FCE_OUT" | tr '\n' '|' | cut -c1-400)" ;; esac
  case "$_FCE_OUT" in *"the trunk's"*) : ;; *) cf "(a) the refusal does not say the card is the trunk's: $(printf '%s' "$_FCE_OUT" | tr '\n' '|' | cut -c1-400)" ;; esac
  case "$_FCE_OUT" in *"git checkout origin/$SB_TRUNK -- "*) : ;; *) cf "(a) the refusal does not restore the card from the remote's trunk (origin/$SB_TRUNK): $(printf '%s' "$_FCE_OUT" | tr '\n' '|' | cut -c1-500)" ;; esac
  case "$_FCE_OUT" in *"git checkout $SB_TRUNK -- "*) cf "(a) the refusal restores the card from the LOCAL trunk, which can lag the remote: $(printf '%s' "$_FCE_OUT" | tr '\n' '|' | cut -c1-500)" ;; esac
  origin_has_path "CE-$ida.txt" && cf "(a) the branch was merged despite the conflict"

  local idb="$SB_PREFIX-952"
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1
  _fpr_card_edit_land "$idb" apart apart
  [ "$_FCE_RC" -eq 0 ] || cf "(b) control: a non-overlapping card edit on the branch did not land: $(printf '%s' "$_FCE_OUT" | tr '\n' '|' | cut -c1-400)"
  origin_has_path "progress/qa_complete/$idb-apart.md" || cf "(b) control: the card did not advance to qa_complete/ — the refusal in (a) has no clean case beside it"

  finish "a branch that edits the card's Activity against the mover's append is refused naming the ISSUE FILE, the trunk's ownership of the card and register-commit.sh; a non-overlapping card edit on a branch still lands"
  teardown
}

# =============================================================================
# CASE — finish-pr.sh --help NAMES POST_MERGE_PREP WHERE IT DESCRIBES THE FRESH WORKTREE.
#
# Pins the --help header's post-merge worktree clause (process/contracts/landing-gate.md § 4).
# =============================================================================
case_finish_pr_help_names_post_merge_prep() {
  cf_reset
  make_sandbox
  local out
  out="$( cd "$SB_WORK" && ./scripts/finish-pr.sh --help </dev/null 2>&1 )"
  case "$out" in *POST_MERGE_PREP*) : ;; *) cf "finish-pr.sh --help does not name POST_MERGE_PREP: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  finish "finish-pr.sh --help names POST_MERGE_PREP"
  teardown
}

# =============================================================================
# CASE — THE FIRST CARD THAT DECLARES THE GATES HAS A ROUTE. Unmarked, like the cases above.
#
# The trunk's runner judges a branch that changes verify.sh, and a trunk whose GATES table is still
# empty refuses to run. A project that finds its stack through its first card declares the gates on
# that card's branch, so the landing refuses on the trunk's empty table. The refusal stays (a runner
# with no gate authorises nothing); it now names the way out:
#   (a) the refusal says REFUSED TO RUN, names the trunk's empty table, and names the route: land
#       the gate table on the trunk first with register-commit.sh, then re-run finish-pr.sh;
#   (b) following that route (register-commit.sh from the branch's checkout, then the same landing)
#       lands the card;
#   (c) a gate runner refused for any other reason names no such route, and a trunk whose table is
#       filled lands a branch that changes verify.sh as before (the case above).
# =============================================================================
case_finish_pr_empty_gate_table_names_the_route() {
  cf_reset
  local out rc br
  make_sandbox
  # The sandbox declares one gate on its trunk; this project has not chosen its stack yet, so none.
  perl -i -ne 'print unless /^  "sandbox gate\|select\|/' "$SB_WORK/scripts/verify.sh"
  seed_issue dev_complete "$SB_PREFIX-791" firstgate chore "The first card declares the gates" "feature/$SB_PREFIX-791-firstgate"
  publish_sandbox
  br="feature/$SB_PREFIX-791-firstgate"
  git -C "$SB_WORK" branch "$br" "$SB_TRUNK" >/dev/null 2>&1 && git -C "$SB_WORK" checkout -q "$br" >/dev/null 2>&1 \
    || _fixture_die "case_finish_pr_empty_gate_table_names_the_route: could not branch."
  git -C "$SB_WORK" show "$SB_TRUNK:scripts/verify.sh" > "$SB_TMP/trunk-verify.sh"
  awk '/^GATES=\($/ { i = 1; next } i && /^\)/ { i = 0 } i && /^[[:space:]]*"/ { n++ } END { exit (n > 0) }' "$SB_TMP/trunk-verify.sh" \
    || _fixture_die "case_finish_pr_empty_gate_table_names_the_route: the sandbox trunk's GATES table is not empty, so the case tests nothing."
  _declare_gate 'first|core|/bin/echo first-gate-green'
  echo "the first card's own change" > "$SB_WORK/CHANGE791.txt"   # the table rides with the card's code, as a first card's does
  git -C "$SB_WORK" add -A >/dev/null 2>&1 && sbcommit -q -m "[Dev] $SB_PREFIX-791: declare the gates" >/dev/null 2>&1 \
    && git -C "$SB_WORK" push -q -u origin "$br" >/dev/null 2>&1 \
    || _fixture_die "case_finish_pr_empty_gate_table_names_the_route: could not commit and push the branch."
  ( cd "$SB_WORK" && ./scripts/verify.sh --quick >/dev/null 2>&1 ) \
    || _fixture_die "case_finish_pr_empty_gate_table_names_the_route: the branch's own runner is not green, so the row tests nothing."

  # (a) NO FPR_STUB. The refusal names the route.
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-791" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) a branch landed on a trunk whose gate table is empty: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  printf '%s\n' "$out" | grep 'pre-merge gate REFUSED TO RUN' >/dev/null \
    || cf "(a) the refusal no longer says REFUSED TO RUN: $(printf '%s' "$out" | grep -i 'pre-merge' | tr '\n' '|')"
  printf '%s\n' "$out" | grep '^Next:' | grep -F 'register-commit.sh' | grep -F 'scripts/verify.sh' >/dev/null \
    || cf "(a) the refusal's Next: line does not name register-commit.sh landing scripts/verify.sh as the way out: $(printf '%s' "$out" | tail -8 | tr '\n' '|')"
  printf '%s\n' "$out" | grep -i 'empty' | grep -F "$SB_TRUNK" >/dev/null \
    || cf "(a) the refusal does not say the trunk's gate table is empty: $(printf '%s' "$out" | tail -8 | tr '\n' '|')"
  printf '%s\n' "$out" | grep -F 'finish-pr.sh' | grep -i 're-run' >/dev/null \
    || cf "(a) the refusal does not end by saying to re-run finish-pr.sh: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  assert_landing_untouched "(a)" "$SB_PREFIX-791" firstgate "$br"

  # (b) The route works as named: land the table on the trunk, then the same landing succeeds.
  ( cd "$SB_WORK" && ./scripts/register-commit.sh --role Dev --message "$SB_PREFIX-791: declare the gates" scripts/verify.sh ) >/dev/null 2>&1 \
    || cf "(b) register-commit.sh refused to land scripts/verify.sh on the trunk, so the route the refusal names does not work"
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-791" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) after the gate table landed on the trunk the card still did not land (exit $rc): $(printf '%s' "$out" | tail -6 | tr '\n' '|')"
  teardown

  # (c) A gate refused for another reason names no route to the table.
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-792" otherrefusal chore "Refused for another reason" "feature/$SB_PREFIX-792-otherrefusal"
  publish_sandbox
  seed_branch "$SB_PREFIX-792" otherrefusal CHANGE792.txt
  printf '#!/usr/bin/env bash\nexit 2\n' > "$SB_TMP/gate-exit-2c"; chmod +x "$SB_TMP/gate-exit-2c"
  out="$( cd "$SB_WORK" && FINISH_PR_TEST_ALLOW_STUB=1 FINISH_PR_VERIFY_CMD=true FINISH_PR_PREMERGE_CMD="$SB_TMP/gate-exit-2c" \
            "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-792" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(c) a pre-merge gate that refused to run did not refuse the landing"
  printf '%s\n' "$out" | grep -F 'register-commit.sh' >/dev/null \
    && cf "(c) a gate refused for a reason other than an empty table was sent to land a gate table: $(printf '%s' "$out" | tail -6 | tr '\n' '|')"

  teardown

  # (d) A REAL exit 2 from a table that is not empty (a malformed record), with no test stub, is kept
  # apart from an empty one: the probe reads `verify.sh --list`, and the Next: names no route to a table.
  make_sandbox
  _declare_gate 'notarecord'
  seed_issue dev_complete "$SB_PREFIX-793" malformed chore "A malformed table" "feature/$SB_PREFIX-793-malformed"
  publish_sandbox
  br="feature/$SB_PREFIX-793-malformed"
  git -C "$SB_WORK" branch "$br" "$SB_TRUNK" >/dev/null 2>&1 && git -C "$SB_WORK" checkout -q "$br" >/dev/null 2>&1 \
    || _fixture_die "case_finish_pr_empty_gate_table_names_the_route: could not branch for (d)."
  echo "a change" > "$SB_WORK/CHANGE793.txt"
  git -C "$SB_WORK" add -A >/dev/null 2>&1 && sbcommit -q -m "[Dev] $SB_PREFIX-793: a change" >/dev/null 2>&1 \
    && git -C "$SB_WORK" push -q -u origin "$br" >/dev/null 2>&1 \
    || _fixture_die "case_finish_pr_empty_gate_table_names_the_route: could not commit and push the branch for (d)."
  ( cd "$SB_WORK" && ./scripts/verify.sh --list 2>&1 ) | grep -F 'the table is empty' >/dev/null \
    && _fixture_die "case_finish_pr_empty_gate_table_names_the_route: (d)'s table reads as empty, so the row tests nothing."
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-793" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(d) a malformed gate table landed"
  printf '%s\n' "$out" | grep 'pre-merge gate REFUSED TO RUN' >/dev/null \
    || cf "(d) the malformed table did not refuse as REFUSED TO RUN, so the row tests the wrong refusal: $(printf '%s' "$out" | tail -6 | tr '\n' '|')"
  printf '%s\n' "$out" | grep '^Next:' | grep -F 'register-commit.sh' >/dev/null \
    && cf "(d) a malformed (non-empty) table was sent to land a gate table: $(printf '%s' "$out" | tail -6 | tr '\n' '|')"

  finish "finish-pr.sh: a trunk whose GATES table is empty still refuses a branch that declares the gates, and the refusal names the route (land scripts/verify.sh on the trunk with register-commit.sh, then re-run); the route lands the card; a gate refused for another reason names no such route"
  teardown
}

# =============================================================================
# CASE — A BRANCH THAT MOVES DURING THE GATE IS NOT LANDED UNREAD.
#
# finish-pr.sh reads the QA Verdict at the branch tip it resolved, then runs the pre-merge gate,
# which can take long. A commit that reaches the branch meanwhile would be squashed with the rest
# while the Activity note certifies the earlier revision. The gate stub below is the Dev committing
# in parallel: it adds LATE.txt to the branch. Asserted: nonzero exit, the refusal named, nothing
# landed, the branch and card untouched.
# =============================================================================
case_finish_pr_refuses_a_branch_that_moved_during_the_gate() {
  cf_reset
  make_sandbox
  local out rc br
  seed_issue dev_complete "$SB_PREFIX-807" moved chore "Branch moves during the gate" "feature/$SB_PREFIX-807-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-807" work CHANGE.txt
  br="feature/$SB_PREFIX-807-work"
  cat > "$SB_TMP/gate-moves-the-branch" <<'STUB'
#!/usr/bin/env bash
export GIT_AUTHOR_NAME=late GIT_AUTHOR_EMAIL=late@example.invalid GIT_COMMITTER_NAME=late GIT_COMMITTER_EMAIL=late@example.invalid
b="$(git rev-parse "refs/heads/$W807_BRANCH")" || exit 9
ix="$(mktemp)" || exit 9
rm -f "$ix"
GIT_INDEX_FILE="$ix" git read-tree "$b" || exit 9
GIT_INDEX_FILE="$ix" git update-index --add --cacheinfo "100644,$(echo late | git hash-object -w --stdin),LATE.txt" || exit 9
t="$(GIT_INDEX_FILE="$ix" git write-tree)" || exit 9
n="$(git commit-tree "$t" -p "$b" -m 'a commit that arrived during the gate')" || exit 9
git update-ref "refs/heads/$W807_BRANCH" "$n" "$b" || exit 9
rm -f "$ix"
: > "$W807_MARK"
exit 0
STUB
  chmod +x "$SB_TMP/gate-moves-the-branch"

  out="$( cd "$SB_WORK" && W807_MARK="$SB_TMP/gate-moved-it" W807_BRANCH="$br" FINISH_PR_TEST_ALLOW_STUB=1 FINISH_PR_VERIFY_CMD=true FINISH_PR_PREMERGE_CMD="$SB_TMP/gate-moves-the-branch" \
            "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-807" 2>&1 )"; rc=$?
  [ -e "$SB_TMP/gate-moved-it" ] \
    || cf "the gate stub did not move the branch, so the row tests nothing: $(printf '%s' "$out" | tail -6 | tr '\n' '|')"
  [ "$rc" -ne 0 ] || cf "a branch that moved during the gate landed (rc=0): $out"
  printf '%s\n' "$out" | grep 'moved while the pre-merge gate ran' >/dev/null \
    || cf "the refusal is not the branch-moved one: $(printf '%s' "$out" | tail -6 | tr '\n' '|')"
  printf '%s\n' "$out" | grep '^Next:' >/dev/null \
    || cf "the branch-moved refusal names no Next: $(printf '%s' "$out" | tail -6 | tr '\n' '|')"
  assert_landing_untouched "(branch moved)" "$SB_PREFIX-807" moved "$br" CHANGE.txt
  origin_has_path "LATE.txt" && cf "the late commit's file reached the trunk"

  finish "finish-pr.sh: a branch that moved during the pre-merge gate is refused with nothing landed, and the refusal names its Next"
  teardown
}

# =============================================================================
# CASE — A TAG WITH THE BRANCH'S SHORT NAME IS NOT WHAT IS LANDED.
#
# The branch is resolved as refs/heads/<name> for the existence check and the gate, and was read by
# short name for the QA read and the squash; a tag of the same name wins a short-name lookup.
# The tag is made at a commit holding TAGGED.txt. Asserted: the branch's own change lands and the
# tag's does not, and the Activity note names the branch's tip.
# =============================================================================
case_finish_pr_lands_the_branch_not_a_tag_of_its_name() {
  cf_reset
  make_sandbox
  local out rc br tagc tip
  seed_issue dev_complete "$SB_PREFIX-808" tagged chore "A tag shares the branch name" "feature/$SB_PREFIX-808-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-808" work CHANGE.txt
  br="feature/$SB_PREFIX-808-work"
  tip="$(git -C "$SB_WORK" rev-parse --short "refs/heads/$br")"
  git -C "$SB_WORK" checkout -q -b "scratch-808" "$SB_TRUNK" >/dev/null 2>&1 \
    && echo "tag only" > "$SB_WORK/TAGGED.txt" \
    && git -C "$SB_WORK" add TAGGED.txt >/dev/null 2>&1 \
    && sbcommit -q -m "a commit only the tag points at" >/dev/null 2>&1 \
    && tagc="$(git -C "$SB_WORK" rev-parse HEAD)" \
    && git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1 \
    && git -C "$SB_WORK" tag "$br" "$tagc" >/dev/null 2>&1 \
    || _fixture_die "case_finish_pr_lands_the_branch_not_a_tag_of_its_name: could not plant the tag."
  [ "$(git -C "$SB_WORK" rev-parse "$br^{commit}" 2>/dev/null)" = "$tagc" ] \
    || _fixture_die "case_finish_pr_lands_the_branch_not_a_tag_of_its_name: the tag does not win the short name, so the row tests nothing."

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-808" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "finish-pr exited $rc (expected 0): $(printf '%s' "$out" | tail -6 | tr '\n' '|')"
  origin_has_path "CHANGE.txt" || cf "the branch's own change did not land"
  origin_has_path "TAGGED.txt" && cf "the tag's commit landed in place of the branch's"
  origin_file_contains "progress/qa_complete/$SB_PREFIX-808-tagged.md" "verdict read at $tip" \
    || cf "the Activity note does not name the branch's tip $tip"

  finish "finish-pr.sh: a tag with the branch's short name is not what is read or squashed; the branch lands"
  teardown
}

# =============================================================================
# CASE — A TAG WITH THE BRANCH'S SHORT NAME DOES NOT HIDE THE BRANCH FROM THE LANDING CHECKS.
#
# The ablation, forks and board-property checks read the branch's diff. Given the short name they
# read a same-named tag's. The branch here touches a declared test path with no '## Ablation'
# section; the tag points at a commit that touches nothing the check looks at. Asserted: the
# landing refuses on the missing section and merges nothing.
# =============================================================================
case_finish_pr_checks_read_the_branch_not_a_tag_of_its_name() {
  cf_reset
  make_sandbox
  _declare_test_globs 'tests/*'
  local id="$SB_PREFIX-809" br out rc tagc
  br="feature/$id-work"
  seed_issue dev_complete "$id" hidden chore "A tag hides a test change" "$br"
  publish_sandbox
  git -C "$SB_WORK" branch "$br" "$SB_TRUNK" >/dev/null 2>&1 \
    && git -C "$SB_WORK" checkout -q "$br" >/dev/null 2>&1 \
    && mkdir -p "$SB_WORK/tests" \
    && echo "a real change" > "$SB_WORK/tests/CHANGE809.txt" \
    && git -C "$SB_WORK" add tests/CHANGE809.txt >/dev/null 2>&1 \
    && sbcommit -q -m "[Dev] $id: add a real change" >/dev/null 2>&1 \
    && git -C "$SB_WORK" push -q -u origin "$br" >/dev/null 2>&1 \
    && git -C "$SB_WORK" checkout -q -b "scratch-809" "$SB_TRUNK" >/dev/null 2>&1 \
    && echo "harmless" > "$SB_WORK/BENIGN809.txt" \
    && git -C "$SB_WORK" add BENIGN809.txt >/dev/null 2>&1 \
    && sbcommit -q -m "a harmless commit" >/dev/null 2>&1 \
    && tagc="$(git -C "$SB_WORK" rev-parse HEAD)" \
    && git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1 \
    && git -C "$SB_WORK" tag "$br" "$tagc" >/dev/null 2>&1 \
    || _fixture_die "case_finish_pr_checks_read_the_branch_not_a_tag_of_its_name: could not set up the branch and the tag."
  [ "$(git -C "$SB_WORK" rev-parse "$br^{commit}" 2>/dev/null)" = "$tagc" ] \
    || _fixture_die "case_finish_pr_checks_read_the_branch_not_a_tag_of_its_name: the tag does not win the short name, so the row tests nothing."

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "a branch that touches a test path with no '## Ablation' section landed behind a same-named tag (rc=0)"
  case "$out" in *"Ablation"*) : ;; *) cf "the refusal does not name 'Ablation': $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  origin_has_path "tests/CHANGE809.txt" && cf "the branch was merged before the refusal"
  origin_has_path "progress/qa_complete/$id-hidden.md" && cf "the card advanced despite the refusal"

  finish "finish-pr.sh: the ablation check reads the branch, not a tag that shares its name"
  teardown
}

# =============================================================================
# CASES — THE SAME TAG DOES NOT HIDE A BRANCH FROM THE FORKS CHECK OR THE BOARD-PROPERTY CHECK.
#
# Each runs the shape of an existing refusal (a branch that adds a register entry under 'forks: none';
# a branch that cites a decision that is no entry) with a tag of the branch's name at a harmless
# commit. The refusal must still fire, and nothing may land.
# =============================================================================
_w807_tag_branch() {  # <branch> <scratch-branch> <file>: tag <branch> at a commit holding only <file>
  git -C "$SB_WORK" checkout -q -b "$2" "$SB_TRUNK" >/dev/null 2>&1 \
    && echo "harmless" > "$SB_WORK/$3" \
    && git -C "$SB_WORK" add "$3" >/dev/null 2>&1 \
    && sbcommit -q -m "a harmless commit" >/dev/null 2>&1 \
    && git -C "$SB_WORK" tag "$1" HEAD >/dev/null 2>&1 \
    && git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1
}

case_finish_pr_forks_check_reads_the_branch_not_a_tag_of_its_name() {
  cf_reset
  make_sandbox
  _forks_seed_register "$SB_WORK/requirements/DECISIONS.md"
  publish_sandbox
  local id="$SB_PREFIX-810" br out rc
  br="feature/$id-work"
  seed_issue dev_complete "$id" forkhide chore "A tag hides a register entry" "$br"
  publish_sandbox
  git -C "$SB_WORK" branch "$br" "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" checkout -q "$br" >/dev/null 2>&1
  printf '\n### D-02\n\n**Ruling.** A brand new fork, resolved on this branch.\n' >> "$SB_WORK/requirements/DECISIONS.md"
  git -C "$SB_WORK" add requirements/DECISIONS.md >/dev/null 2>&1
  sbcommit -m "[Dev] $id: add D-02" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "$br" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" checkout "$SB_TRUNK" --quiet >/dev/null 2>&1
  _w807_tag_branch "$br" scratch-810 BENIGN810.txt \
    || _fixture_die "case_finish_pr_forks_check_reads_the_branch_not_a_tag_of_its_name: could not plant the tag."

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "a branch adding D-02 under 'forks: none' landed behind a same-named tag (rc=0)"
  case "$out" in *"shows a fork"*D-02*) : ;; *) cf "the refusal is not the forks check naming D-02: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  origin_has_path "progress/qa_complete/$id-forkhide.md" && cf "the card advanced despite the refusal"

  finish "finish-pr.sh: the forks check reads the branch, not a tag that shares its name"
  teardown
}

case_finish_pr_board_property_check_reads_the_branch_not_a_tag_of_its_name() {
  cf_reset
  make_sandbox
  _bpf_seed_requirements
  publish_sandbox
  local id="$SB_PREFIX-811" br out rc
  br="feature/$id-work"
  seed_issue dev_complete "$id" bphide chore "A tag hides a dangling citation" "$br"
  publish_sandbox
  git -C "$SB_WORK" branch "$br" "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" checkout -q "$br" >/dev/null 2>&1
  printf 'See [decision: D-77].\n' > "$SB_WORK/docs/note811.md"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[Dev] $id: the work" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "$br" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" checkout "$SB_TRUNK" --quiet >/dev/null 2>&1
  _w807_tag_branch "$br" scratch-811 BENIGN811.txt \
    || _fixture_die "case_finish_pr_board_property_check_reads_the_branch_not_a_tag_of_its_name: could not plant the tag."

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "a branch citing D-77, which is no entry, landed behind a same-named tag (rc=0)"
  case "$out" in *D-77*) : ;; *) cf "the refusal does not name D-77: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  origin_has_path "docs/note811.md" && cf "the branch was merged before the refusal"

  finish "finish-pr.sh: the board-property check reads the branch, not a tag that shares its name"
  teardown
}
