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
    printf '%s\n' "$FPR_PM_OUT" | grep -F "'$FPR_PM_BR' is no longer checked out anywhere" >/dev/null \
      || cf "(A) the detach freed the branch the board note calls KEPT, and the run did not say so"
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

  finish "finish-pr.sh: the post-merge check detaches the existing gate checkout to the landed commit, names the sha it read and says the branch is now unheld (A), uses a fresh worktree only for a dirty checkout and removes it even when the gate leaves it read-only (D), and says COULD NOT RUN / UNRUNNABLE rather than PASS or FAIL when the landed gate cannot run (E) or ran and could not run a gate in the fresh tree (H)"
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

  finish "finish-pr.sh with the branch held by a second worktree: local skip preserved, remote still deleted, and the note does NOT claim the local delete"
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

  finish "finish-pr.sh with a remote that refuses deletes: loud, git's own error surfaced, exit still 0, and the note names the survivor"
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
#   (3) SPACE − SET, from the SHIPPED empty GUARD_SET  → rc 2, the enumerated guard named
#   (4) enumerator MIS-TYPED (rc 1, not 127)           → rc 2, the enumerator's OWN stderr surfaced
#   (5) enumerator succeeds and returns NOTHING        → rc 2, no reconciled claim
#   (6) SET − SPACE, two on disk, enumerator sees one  → rc 2, the UNSEEN one named
#   (7) wholly empty: no set, enumerator returns none  → rc 0, and NO reconciled claim
#   (8) DECLARED == ENUMERATED, both non-empty         → rc 0, and the reconciled claim IS
#       emitted: the only state that reaches the green line. (7) also exits 0, so without
#       this one every assertion about that claim is an assertion about its ABSENCE.
#
# STATES 3 AND 7 ARE BOTH BUILT ON THE SHIPPED EMPTY GUARD_SET: a fixture that always
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
  printf '%s' "$out" | grep 'guard-one.txt' >/dev/null \
    || cf "(e) the scoped run did not append the GUARD_SET floor — a scoped run must never be narrower than the guards: $out"
  # ...and a vanished guard is a hard stop.
  rm -f "$SB_WORK/guard-one.txt"
  out="$( cd "$SB_WORK" && "$v" --scope some/item 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(e) a vanished guard did not stop the scoped run — the floor shrank silently"
  printf '%s' "$out" | grep 'guard-one.txt' >/dev/null || cf "(e) the vanished-guard refusal does not name the path: $out"

  finish "verify.sh frame: empty table REFUSES, --list answers anyway, exit codes unlaundered, --quick skips only 'full', --scope appends the guard floor and a vanished guard is a hard stop"
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
