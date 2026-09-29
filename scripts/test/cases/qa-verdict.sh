# KIT-CLASS: MIXED — self-test harness, the '## QA Verdict' landing precondition. See
# process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/qa-verdict.sh — sourced by scripts/test/run.sh, never run on its own.
# finish-pr.sh refuses a PASS landing whose card carries no '## QA Verdict' table, a row with no
# usable evidence, a row whose own verdict is FAIL_AC/FAIL_REGRESSION, a table whose AC ids do not
# match the card's own AC checklist one for one, or no filled 'shadow-check' row.
# =============================================================================

# =============================================================================
# CASE — NO '## QA Verdict' HEADING AT ALL REFUSES, NAMED, WITH A COUNTABLE RECORD.
# RED FIRST: fails on any finish-pr.sh that does not look for the table.
# =============================================================================
case_finish_pr_qa_verdict_missing_table_refuses() {
  cf_reset
  make_sandbox

  local id="$SB_PREFIX-651"
  seed_issue dev_complete "$id" notable chore "No QA Verdict table" "feature/$id-work"
  local f="$SB_WORK/progress/dev_complete/$id-notable.md"
  perl -0pi -e 's/## QA Verdict\n.*?\n\n(?=## Activity)//s' "$f"
  grep -qE '^## QA Verdict' "$f" \
    && _fixture_die "case_finish_pr_qa_verdict_missing_table_refuses: the '## QA Verdict' heading survived the strip"
  publish_sandbox
  seed_branch "$id" work CHANGE651.txt

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "no '## QA Verdict' table — finish-pr.sh exited 0"
  case "$out" in *"QA Verdict"*) : ;; *) cf "the refusal does not name 'QA Verdict': $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "CHANGE651.txt" && cf "the branch was merged before the refusal"
  origin_has_path "progress/qa_complete/$id-notable.md" && cf "the card advanced despite the refusal"
  /usr/bin/grep -q 'refusal=qa-verdict-missing' "$SB_TMP/rec"/*.tsv 2>/dev/null \
    || cf "no progress record carries refusal=qa-verdict-missing: $(cat "$SB_TMP/rec"/*.tsv 2>/dev/null)"

  finish "finish-pr.sh refuses a landing whose card has no '## QA Verdict' table, before the merge, with a countable refusal=qa-verdict-missing record"
  teardown
}

# =============================================================================
# CASE — A ROW WITH NO USABLE EVIDENCE (bad kind, or an empty/placeholder pointer) REFUSES.
# =============================================================================
case_finish_pr_qa_verdict_evidence_missing_refuses() {
  cf_reset
  make_sandbox

  # (a) evidence kind outside the closed list.
  local ida="$SB_PREFIX-652"
  seed_issue dev_complete "$ida" badkind chore "Bad evidence kind" "feature/$ida-work"
  local fa="$SB_WORK/progress/dev_complete/$ida-badkind.md"
  perl -i -pe 's/\| AC1 \| PASS \| test \| sandbox-gate-green \|/| AC1 | PASS | prose | it looked fine |/' "$fa"
  grep -qF '| AC1 | PASS | prose | it looked fine |' "$fa" \
    || _fixture_die "case_finish_pr_qa_verdict_evidence_missing_refuses: (a) the bad-kind row was not planted"
  publish_sandbox
  seed_branch "$ida" work CHANGE652A.txt

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-a" "$SB_WORK/scripts/finish-pr.sh" "$ida" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) evidence kind 'prose' — finish-pr.sh exited 0"
  case "$out" in *AC1*) : ;; *) cf "(a) the refusal does not name AC1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "CHANGE652A.txt" && cf "(a) the branch was merged before the refusal"
  /usr/bin/grep -q 'refusal=qa-verdict-evidence-missing' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
    || cf "(a) no progress record carries refusal=qa-verdict-evidence-missing: $(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null)"

  # (b) pointer is the template's own placeholder text.
  local idb="$SB_PREFIX-653"
  seed_issue dev_complete "$idb" placeholder chore "Placeholder pointer" "feature/$idb-work"
  local fb="$SB_WORK/progress/dev_complete/$idb-placeholder.md"
  perl -i -pe 's/\| AC1 \| PASS \| test \| sandbox-gate-green \|/| AC1 | PASS | test | <placeholder> |/' "$fb"
  grep -qF '| AC1 | PASS | test | <placeholder> |' "$fb" \
    || _fixture_die "case_finish_pr_qa_verdict_evidence_missing_refuses: (b) the placeholder row was not planted"
  publish_sandbox
  seed_branch "$idb" work CHANGE652B.txt

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-b" "$SB_WORK/scripts/finish-pr.sh" "$idb" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) placeholder evidence pointer — finish-pr.sh exited 0"
  origin_has_path "CHANGE652B.txt" && cf "(b) the branch was merged before the refusal"
  /usr/bin/grep -q 'refusal=qa-verdict-evidence-missing' "$SB_TMP/rec-b"/*.tsv 2>/dev/null \
    || cf "(b) no progress record carries refusal=qa-verdict-evidence-missing: $(cat "$SB_TMP/rec-b"/*.tsv 2>/dev/null)"

  finish "finish-pr.sh refuses a landing whose QA Verdict table has a row with no usable evidence — an evidence kind outside test|file:line|gate-diff|fixture-diff, or an empty/placeholder pointer — naming the row, with a refusal=qa-verdict-evidence-missing record"
  teardown
}

# =============================================================================
# CASE — A ROW THAT FOUND A MISMATCH (FAIL_AC, WITH REAL EVIDENCE) BUT THE
# CARD STILL SHIPS AS AN OVERALL PASS. This is the card's motivating case: an evidence-present
# check alone lets it through, so finish-pr.sh must also refuse on the row's OWN verdict.
# =============================================================================
case_finish_pr_qa_verdict_fail_row_on_pass_refuses() {
  cf_reset
  make_sandbox

  local id="$SB_PREFIX-654"
  seed_issue dev_complete "$id" mismatch chore "A FAIL row that still shipped PASS" "feature/$id-work"
  local f="$SB_WORK/progress/dev_complete/$id-mismatch.md"
  perl -i -pe 's/\| AC1 \| PASS \| test \| sandbox-gate-green \|/| AC1 | FAIL_AC | file:line | README.txt:12 (quote does not match the tool output) |/' "$f"
  grep -qF 'FAIL_AC' "$f" \
    || _fixture_die "case_finish_pr_qa_verdict_fail_row_on_pass_refuses: the FAIL_AC row was not planted"
  publish_sandbox
  seed_branch "$id" work CHANGE654.txt

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "a FAIL_AC row with real evidence, on a PASS landing — finish-pr.sh exited 0"
  case "$out" in *AC1*) : ;; *) cf "the refusal does not name AC1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "CHANGE654.txt" && cf "the branch was merged before the refusal"
  origin_has_path "progress/qa_complete/$id-mismatch.md" && cf "the card advanced despite the refusal"
  /usr/bin/grep -q 'refusal=qa-verdict-fail' "$SB_TMP/rec"/*.tsv 2>/dev/null \
    || cf "no progress record carries refusal=qa-verdict-fail: $(cat "$SB_TMP/rec"/*.tsv 2>/dev/null)"

  finish "finish-pr.sh refuses a PASS landing whose QA Verdict table has a row that is itself FAIL_AC or FAIL_REGRESSION — evidence alone is not enough, the row's own verdict is checked too — naming the row, with a refusal=qa-verdict-fail record"
  teardown
}

# =============================================================================
# CASE — THE TABLE'S AC IDS MUST MATCH THE CARD'S AC CHECKLIST ONE FOR ONE.
# (a) the card's AC checklist grew an id the table never gained; (b) the table names an id the
# checklist does not have.
# =============================================================================
case_finish_pr_qa_verdict_ac_mismatch_refuses() {
  cf_reset
  make_sandbox

  # (a) MISSING — a second AC bullet with no matching table row.
  local ida="$SB_PREFIX-655"
  seed_issue dev_complete "$ida" missingrow chore "AC2 has no table row" "feature/$ida-work"
  local fa="$SB_WORK/progress/dev_complete/$ida-missingrow.md"
  perl -i -pe 's/(- \[ \] AC1 — the sandbox.s seeded behaviour holds\.)/$1\n- [ ] AC2 — a second criterion with no QA Verdict row./' "$fa"
  grep -qF 'AC2' "$fa" || _fixture_die "case_finish_pr_qa_verdict_ac_mismatch_refuses: (a) AC2 bullet was not planted"
  publish_sandbox
  seed_branch "$ida" work CHANGE655A.txt

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-a" "$SB_WORK/scripts/finish-pr.sh" "$ida" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) an AC bullet with no table row — finish-pr.sh exited 0"
  case "$out" in *AC2*) : ;; *) cf "(a) the refusal does not name AC2: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "CHANGE655A.txt" && cf "(a) the branch was merged before the refusal"
  /usr/bin/grep -q 'refusal=qa-verdict-ac-mismatch' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
    || cf "(a) no progress record carries refusal=qa-verdict-ac-mismatch: $(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null)"

  # (b) EXTRA — the table has a row for an id the AC checklist does not carry.
  local idb="$SB_PREFIX-656"
  seed_issue dev_complete "$idb" extrarow chore "Table names AC9, no such AC" "feature/$idb-work"
  local fb="$SB_WORK/progress/dev_complete/$idb-extrarow.md"
  perl -i -pe 's/(\| AC1 \| PASS \| test \| sandbox-gate-green \|)/$1\n| AC9 | PASS | test | sandbox-gate-green |/' "$fb"
  grep -qF 'AC9' "$fb" || _fixture_die "case_finish_pr_qa_verdict_ac_mismatch_refuses: (b) AC9 row was not planted"
  publish_sandbox
  seed_branch "$idb" work CHANGE655B.txt

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-b" "$SB_WORK/scripts/finish-pr.sh" "$idb" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) an extra table row with no matching AC bullet — finish-pr.sh exited 0"
  case "$out" in *AC9*) : ;; *) cf "(b) the refusal does not name AC9: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "CHANGE655B.txt" && cf "(b) the branch was merged before the refusal"
  /usr/bin/grep -q 'refusal=qa-verdict-ac-mismatch' "$SB_TMP/rec-b"/*.tsv 2>/dev/null \
    || cf "(b) no progress record carries refusal=qa-verdict-ac-mismatch: $(cat "$SB_TMP/rec-b"/*.tsv 2>/dev/null)"

  finish "finish-pr.sh refuses a landing whose QA Verdict table's AC ids do not match the card's own AC checklist one for one — missing (a) or extra (b) — naming the mismatch, with a refusal=qa-verdict-ac-mismatch record"
  teardown
}

# =============================================================================
# CASE — THE 'shadow-check' ROW IS REQUIRED, AND MUST BE FILLED.
# =============================================================================
case_finish_pr_qa_verdict_shadow_check_required() {
  cf_reset
  make_sandbox

  # (a) ABSENT — no shadow-check row at all.
  local ida="$SB_PREFIX-657"
  seed_issue dev_complete "$ida" noshadow chore "No shadow-check row" "feature/$ida-work"
  local fa="$SB_WORK/progress/dev_complete/$ida-noshadow.md"
  perl -ni -e 'print unless /^\| shadow-check \|/' "$fa"
  grep -qE '^\| shadow-check \|' "$fa" \
    && _fixture_die "case_finish_pr_qa_verdict_shadow_check_required: (a) the shadow-check row survived the strip"
  publish_sandbox
  seed_branch "$ida" work CHANGE657A.txt

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-a" "$SB_WORK/scripts/finish-pr.sh" "$ida" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) no shadow-check row — finish-pr.sh exited 0"
  case "$out" in *shadow-check*) : ;; *) cf "(a) the refusal does not name 'shadow-check': $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "CHANGE657A.txt" && cf "(a) the branch was merged before the refusal"
  /usr/bin/grep -q 'refusal=qa-verdict-shadow-missing' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
    || cf "(a) no progress record carries refusal=qa-verdict-shadow-missing: $(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null)"

  # (b) EMPTY — the row exists but its pointer is blank.
  local idb="$SB_PREFIX-658"
  seed_issue dev_complete "$idb" emptyshadow chore "Empty shadow-check pointer" "feature/$idb-work"
  local fb="$SB_WORK/progress/dev_complete/$idb-emptyshadow.md"
  perl -i -pe 's/\| shadow-check \| — \| — \| assertions removed: none \|/| shadow-check | — | — |  |/' "$fb"
  grep -qF '| shadow-check | — | — |  |' "$fb" \
    || _fixture_die "case_finish_pr_qa_verdict_shadow_check_required: (b) the empty shadow-check row was not planted"
  publish_sandbox
  seed_branch "$idb" work CHANGE657B.txt

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-b" "$SB_WORK/scripts/finish-pr.sh" "$idb" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) an empty shadow-check pointer — finish-pr.sh exited 0"
  origin_has_path "CHANGE657B.txt" && cf "(b) the branch was merged before the refusal"
  /usr/bin/grep -q 'refusal=qa-verdict-shadow-missing' "$SB_TMP/rec-b"/*.tsv 2>/dev/null \
    || cf "(b) no progress record carries refusal=qa-verdict-shadow-missing: $(cat "$SB_TMP/rec-b"/*.tsv 2>/dev/null)"

  finish "finish-pr.sh refuses a landing whose QA Verdict table has no 'shadow-check' row, or one with an empty pointer — the required non-AC shadow-check row — with a refusal=qa-verdict-shadow-missing record"
  teardown
}

# =============================================================================
# CASE — THE GREEN PATH: A WELL-FORMED TABLE LANDS.
# seed_issue's own default table (one AC row, PASS, real evidence, plus a filled shadow-check
# row) is the happy path every other landing case already exercises; this leg names it directly
# and also proves a MULTI-row, all-PASS table with a real shadow-check note lands too.
# =============================================================================
case_finish_pr_qa_verdict_well_formed_lands() {
  cf_reset
  make_sandbox

  # (a) seed_issue's own default: one AC row, PASS, real evidence, shadow-check: none.
  local ida="$SB_PREFIX-659"
  seed_issue dev_complete "$ida" clean chore "A well-formed QA Verdict table" "feature/$ida-work"
  publish_sandbox
  seed_branch "$ida" work CHANGE659A.txt

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$ida" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) a well-formed table — finish-pr.sh exited $rc: $(printf '%s' "$out" | tail -8 | tr '\n' '|')"
  origin_has_path "progress/qa_complete/$ida-clean.md" || cf "(a) the card did not advance to qa_complete/"
  origin_has_path "CHANGE659A.txt" || cf "(a) the squash-merged change is not on the trunk"

  # (b) two AC rows beside a non-AC checklist bullet, PASS_AC_CORRECTED alongside PASS, a shadow-check naming a real
  #     removed assertion — the closed list and the FAIL check both stay quiet on a genuine PASS.
  local idb="$SB_PREFIX-660"
  seed_issue dev_complete "$idb" tworow chore "Two AC rows, one PASS_AC_CORRECTED" "feature/$idb-work"
  local fb="$SB_WORK/progress/dev_complete/$idb-tworow.md"
  # A checklist bullet that is not an AC (no `<id> —`) is not read as one.
  perl -i -pe 's/(- \[ \] AC1 — the sandbox.s seeded behaviour holds\.)/$1\n- [ ] AC2 — a second, independently graded criterion.\n- [x] Tests pass locally/' "$fb"
  perl -i -pe 's/\| AC1 \| PASS \| test \| sandbox-gate-green \|/| AC1 | PASS_AC_CORRECTED | file:line | CHANGE659A.txt:1 |\n| AC2 | PASS | gate-diff | sandbox gate ran clean before and after |/' "$fb"
  perl -i -pe 's/\| shadow-check \| — \| — \| assertions removed: none \|/| shadow-check | — | — | removed the old smoke-only check; replaced by AC2'"'"'s gate-diff |/' "$fb"
  grep -qF 'PASS_AC_CORRECTED' "$fb" || _fixture_die "case_finish_pr_qa_verdict_well_formed_lands: (b) the two-row table was not planted"
  publish_sandbox
  seed_branch "$idb" work CHANGE659B.txt

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$idb" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) a two-row table with PASS_AC_CORRECTED — finish-pr.sh exited $rc: $(printf '%s' "$out" | tail -8 | tr '\n' '|')"
  origin_has_path "progress/qa_complete/$idb-tworow.md" || cf "(b) the card did not advance to qa_complete/"
  origin_has_path "CHANGE659B.txt" || cf "(b) the squash-merged change is not on the trunk"

  finish "finish-pr.sh lands a card whose QA Verdict table is well-formed — every AC id covered exactly once with real evidence, no FAIL row, and a filled shadow-check row — whether the card carries one AC or several, and whether every row is PASS or a mix of PASS/PASS_AC_CORRECTED"
  teardown
}
