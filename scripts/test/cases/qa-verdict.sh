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
  grep -q 'refusal=qa-verdict-missing' "$SB_TMP/rec"/*.tsv 2>/dev/null \
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
  perl -i -pe 's/^\| AC1 \| PASS \| test \|.*\|$/| AC1 | PASS | prose | it looked fine |/' "$fa"
  grep -qF '| AC1 | PASS | prose | it looked fine |' "$fa" \
    || _fixture_die "case_finish_pr_qa_verdict_evidence_missing_refuses: (a) the bad-kind row was not planted"
  publish_sandbox
  seed_branch "$ida" work CHANGE652A.txt

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-a" "$SB_WORK/scripts/finish-pr.sh" "$ida" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) evidence kind 'prose' — finish-pr.sh exited 0"
  case "$out" in *AC1*) : ;; *) cf "(a) the refusal does not name AC1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "CHANGE652A.txt" && cf "(a) the branch was merged before the refusal"
  grep -q 'refusal=qa-verdict-evidence-missing' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
    || cf "(a) no progress record carries refusal=qa-verdict-evidence-missing: $(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null)"

  # (b) pointer is the template's own placeholder text.
  local idb="$SB_PREFIX-653"
  seed_issue dev_complete "$idb" placeholder chore "Placeholder pointer" "feature/$idb-work"
  local fb="$SB_WORK/progress/dev_complete/$idb-placeholder.md"
  perl -i -pe 's/^\| AC1 \| PASS \| test \|.*\|$/| AC1 | PASS | test | <placeholder> |/' "$fb"
  grep -qF '| AC1 | PASS | test | <placeholder> |' "$fb" \
    || _fixture_die "case_finish_pr_qa_verdict_evidence_missing_refuses: (b) the placeholder row was not planted"
  publish_sandbox
  seed_branch "$idb" work CHANGE652B.txt

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-b" "$SB_WORK/scripts/finish-pr.sh" "$idb" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) placeholder evidence pointer — finish-pr.sh exited 0"
  origin_has_path "CHANGE652B.txt" && cf "(b) the branch was merged before the refusal"
  grep -q 'refusal=qa-verdict-evidence-missing' "$SB_TMP/rec-b"/*.tsv 2>/dev/null \
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
  # Verdict FAIL_AC, but the pointer itself still resolves with a real quote — isolates the row's
  # OWN-verdict check (qa-verdict-fail) from the pointer/quote checks items 1-2 added.
  perl -i -pe 's/^(\| AC1 \| )PASS( \| test \|.*\|)$/${1}FAIL_AC${2}/' "$f"
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
  grep -q 'refusal=qa-verdict-fail' "$SB_TMP/rec"/*.tsv 2>/dev/null \
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
  # ^...$ anchors the match to the bullet's OWN line — seed_issue's QA Verdict row now quotes this
  # same text verbatim, and an unanchored match would also fire inside that quoted cell.
  perl -i -pe 's/^(- \[ \] AC1 — the sandbox.s seeded behaviour holds\.)$/$1\n- [ ] AC2 — a second criterion with no QA Verdict row./' "$fa"
  grep -qF 'AC2' "$fa" || _fixture_die "case_finish_pr_qa_verdict_ac_mismatch_refuses: (a) AC2 bullet was not planted"
  publish_sandbox
  seed_branch "$ida" work CHANGE655A.txt

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-a" "$SB_WORK/scripts/finish-pr.sh" "$ida" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) an AC bullet with no table row — finish-pr.sh exited 0"
  case "$out" in *AC2*) : ;; *) cf "(a) the refusal does not name AC2: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "CHANGE655A.txt" && cf "(a) the branch was merged before the refusal"
  grep -q 'refusal=qa-verdict-ac-mismatch' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
    || cf "(a) no progress record carries refusal=qa-verdict-ac-mismatch: $(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null)"

  # (b) EXTRA — the table has a row for an id the AC checklist does not carry. Its own pointer
  # still resolves with a real quote (the shadow-check row's own line), so the extra row is
  # refused for the AC mismatch, not for a pointer/quote problem of its own.
  local idb="$SB_PREFIX-656"
  seed_issue dev_complete "$idb" extrarow chore "Table names AC9, no such AC" "feature/$idb-work"
  local fb="$SB_WORK/progress/dev_complete/$idb-extrarow.md"
  local rel9="progress/dev_complete/$idb-extrarow.md"
  local shadow_line9
  shadow_line9="$(grep -nF -- '| shadow-check | — | — | assertions removed: none |' "$fb" | head -1 | cut -d: -f1)"
  [ -n "$shadow_line9" ] || _fixture_die "case_finish_pr_qa_verdict_ac_mismatch_refuses: (b) shadow-check row not found to anchor AC9's quote"
  # '#' as the delimiter: the replacement's own path contains '/', which would otherwise close
  # the s/// early.
  perl -i -pe "s#^(\\| AC1 \\| PASS \\| test \\|.*\\|)\$#\$1\n| AC9 | PASS | test | ${rel9}:${shadow_line9} \"assertions removed: none\" |#" "$fb"
  grep -qF 'AC9' "$fb" || _fixture_die "case_finish_pr_qa_verdict_ac_mismatch_refuses: (b) AC9 row was not planted"
  publish_sandbox
  seed_branch "$idb" work CHANGE655B.txt

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-b" "$SB_WORK/scripts/finish-pr.sh" "$idb" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) an extra table row with no matching AC bullet — finish-pr.sh exited 0"
  case "$out" in *AC9*) : ;; *) cf "(b) the refusal does not name AC9: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "CHANGE655B.txt" && cf "(b) the branch was merged before the refusal"
  grep -q 'refusal=qa-verdict-ac-mismatch' "$SB_TMP/rec-b"/*.tsv 2>/dev/null \
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
  grep -q 'refusal=qa-verdict-shadow-missing' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
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
  grep -q 'refusal=qa-verdict-shadow-missing' "$SB_TMP/rec-b"/*.tsv 2>/dev/null \
    || cf "(b) no progress record carries refusal=qa-verdict-shadow-missing: $(cat "$SB_TMP/rec-b"/*.tsv 2>/dev/null)"

  finish "finish-pr.sh refuses a landing whose QA Verdict table has no 'shadow-check' row, or one with an empty pointer — the required non-AC shadow-check row — with a refusal=qa-verdict-shadow-missing record"
  teardown
}

# =============================================================================
# CASE — THE SHIPPED 'shadow-check' ROW, LEFT UNTOUCHED BY QA, IS REFUSED.
# The row each card template ships is the operand the gate judges: a row that ships already
# answered ("assertions removed: none") passes untouched, so a QA who never read the diff lands.
# The route is the real one — a card carrying the template's row byte for byte, a branch, and
# finish-pr.sh — for every card template the kit ships, the row read from the SHIPPED templates.
# NOT COVERED: whether a QA's filled-in answer is true; the gate reads that a cell was written.
# =============================================================================
case_finish_pr_qa_verdict_shipped_shadow_row_refuses_untouched() {
  cf_reset
  make_sandbox

  local tdir="$REAL_REPO_ROOT/.claude/templates" t tf row n=0 cards=0 id=880 f out rc
  if [ ! -d "$tdir" ]; then
    skp "the shipped shadow-check row is refused untouched" ".claude/templates/ is absent from this tree"
    teardown; return
  fi

  # The population is derived: every shipped card template, told from the PRD template by the `type:` line a card's
  # frontmatter carries and a PRD's does not, never by the row under test (a template that lost its row must be
  # judged and fail, not drop out). The Refactorer's template is optional: absent from a tree that finished day one
  # it is skipped, absent from one that did not it is a defect.
  [ -f "$tdir/REFACTOR.template.md" ] || _member_removed .claude/templates/REFACTOR.template.md \
    || cf "REFACTOR.template.md is not in $tdir and this tree has not removed the Refactorer"
  for tf in "$tdir"/*.template.md; do
    [ -f "$tf" ] || continue
    grep -qE '^type:[[:space:]]' "$tf" || continue
    t="${tf##*/}"; t="${t%.template.md}"; cards=$((cards + 1))
    row="$(grep -E '^\| shadow-check \|' "$tf" || true)"
    # INSTRUMENT CHECK: exactly one row, or the loop below judges nothing.
    [ "$(printf '%s\n' "$row" | grep -c .)" -eq 1 ] \
      || { cf "$t.template.md carries $(printf '%s\n' "$row" | grep -c .) shadow-check rows, expected exactly one"; continue; }
    n=$((n + 1)); id=$((id + 1))
    local cid="$SB_PREFIX-$id" slug; slug="untouched-$(printf '%s' "$t" | tr 'A-Z' 'a-z')"
    seed_issue dev_complete "$cid" "$slug" chore "Shadow row left as shipped ($t)" "feature/$cid-work"
    f="$SB_WORK/progress/dev_complete/$cid-$slug.md"
    ROW="$row" perl -i -pe 'BEGIN { $r = $ENV{ROW} } $_ = "$r\n" if /^\| shadow-check \|/' "$f"
    grep -qxF -- "$row" "$f" \
      || _fixture_die "case_finish_pr_qa_verdict_shipped_shadow_row_refuses_untouched: the $t row was not planted verbatim"
    publish_sandbox
    seed_branch "$cid" work "CHANGE$id.txt"

    out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-$t" "$SB_WORK/scripts/finish-pr.sh" "$cid" 2>&1 )"; rc=$?
    [ "$rc" -ne 0 ] || cf "$t: a card whose shadow-check row is the template's, untouched, landed (exit 0)"
    origin_has_path "CHANGE$id.txt" && cf "$t: the branch was merged although the shadow-check row was never filled"
    grep -q 'refusal=qa-verdict-shadow-missing' "$SB_TMP/rec-$t"/*.tsv 2>/dev/null \
      || cf "$t: no progress record carries refusal=qa-verdict-shadow-missing (output: $(printf '%s' "$out" | tail -3 | tr '\n' '|' | cut -c1-200))"
  done
  [ "$cards" -ge 1 ] || cf "no shipped card template was found (a card template carries a frontmatter type: line), so nothing was judged"
  [ "$n" -eq "$cards" ] || cf "judged $n of the $cards shipped card templates"

  finish "finish-pr.sh refuses a landing whose shadow-check row is still the one the card template ships — for each of the $n shipped card templates, the row read from the template itself, so an unread row cannot pass"
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
  # A checklist bullet that is not an AC (no `<id> —`) is not read as one. ^...$ anchors to the
  # bullet's OWN line, never the QA Verdict row that now quotes this same text verbatim.
  perl -i -pe 's/^(- \[ \] AC1 — the sandbox.s seeded behaviour holds\.)$/$1\n- [ ] AC2 — a second, independently graded criterion.\n- [x] Tests pass locally/' "$fb"
  # AC1's pointer: CHANGE659A.txt:1 — a real file already on $SB_TRUNK (merged by (a)'s landing,
  # above, before this branch is cut from it), line 1 is "a real change" (seed_branch's own
  # marker content), quoted verbatim. AC2 is gate-diff, exempt from the quote by item 2.
  perl -i -pe 's/^\| AC1 \| PASS \| test \|.*\|$/| AC1 | PASS_AC_CORRECTED | file:line | CHANGE659A.txt:1 "a real change" |\n| AC2 | PASS | gate-diff | sandbox gate ran clean before and after |/' "$fb"
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

# =============================================================================
# CASE — A path:line TOKEN THAT DOES NOT RESOLVE AT THE REVISION BEING LANDED REFUSES: (a) the
# named file does not exist at all; (b) the file exists but the cited line is past its length.
# Both are "real-looking and wrong" pointers — never exercised against the caller's own working
# tree, always against $BRANCH (the revision finish-pr.sh is about to land).
# =============================================================================
case_finish_pr_qa_verdict_pointer_unresolved_refuses() {
  cf_reset
  make_sandbox

  # (a) the file does not exist on the branch at all.
  local ida="$SB_PREFIX-676"
  seed_issue dev_complete "$ida" absent chore "Pointer names a file that does not exist" "feature/$ida-work"
  local fa="$SB_WORK/progress/dev_complete/$ida-absent.md"
  perl -i -pe 's/^\| AC1 \| PASS \| test \|.*\|$/| AC1 | PASS | file:line | test\/does-not-exist.test.js:1 "anything" |/' "$fa"
  grep -qF 'does-not-exist.test.js' "$fa" \
    || _fixture_die "case_finish_pr_qa_verdict_pointer_unresolved_refuses: (a) the absent-file row was not planted"
  publish_sandbox
  seed_branch "$ida" work CHANGE676A.txt

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-a" "$SB_WORK/scripts/finish-pr.sh" "$ida" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) a pointer naming a file absent from the branch — finish-pr.sh exited 0"
  case "$out" in *AC1*) : ;; *) cf "(a) the refusal does not name AC1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "CHANGE676A.txt" && cf "(a) the branch was merged before the refusal"
  grep -q 'refusal=qa-verdict-pointer-unresolved' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
    || cf "(a) no progress record carries refusal=qa-verdict-pointer-unresolved: $(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null)"

  # (b) the file exists but the cited line is past its own length.
  local idb="$SB_PREFIX-677"
  seed_issue dev_complete "$idb" pastend chore "Pointer names a line past the file's end" "feature/$idb-work"
  local fb="$SB_WORK/progress/dev_complete/$idb-pastend.md"
  perl -i -pe 's/^\| AC1 \| PASS \| test \|.*\|$/| AC1 | PASS | file:line | README.md:99999 "anything" |/' "$fb"
  grep -qF 'README.md:99999' "$fb" \
    || _fixture_die "case_finish_pr_qa_verdict_pointer_unresolved_refuses: (b) the past-EOF row was not planted"
  publish_sandbox
  seed_branch "$idb" work CHANGE677B.txt

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-b" "$SB_WORK/scripts/finish-pr.sh" "$idb" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) a pointer whose line is past the file's end — finish-pr.sh exited 0"
  origin_has_path "CHANGE677B.txt" && cf "(b) the branch was merged before the refusal"
  grep -q 'refusal=qa-verdict-pointer-unresolved' "$SB_TMP/rec-b"/*.tsv 2>/dev/null \
    || cf "(b) no progress record carries refusal=qa-verdict-pointer-unresolved: $(cat "$SB_TMP/rec-b"/*.tsv 2>/dev/null)"

  finish "finish-pr.sh refuses a landing whose QA Verdict table has a path:line pointer that does not resolve at the revision being landed — the file absent (a) or the line past the file's length (b) — with a refusal=qa-verdict-pointer-unresolved record"
  teardown
}

# =============================================================================
# CASE — A QUOTE ABSENT FROM A test/file:line ROW REFUSES (qa-verdict-quote-missing); A QUOTE
# PRESENT BUT NOT ON THE CITED LINE REFUSES (qa-verdict-quote-not-found) — made concrete: a pointer
# that is real and resolves, but does not show the claim.
# =============================================================================
case_finish_pr_qa_verdict_quote_checks_refuse() {
  cf_reset
  make_sandbox

  # (a) a file:line pointer that resolves (the card's own frontmatter, line 2 — always present and
  # the same across every seeded card), with no quote at all.
  local ida="$SB_PREFIX-678"
  seed_issue dev_complete "$ida" noquote chore "A resolving pointer with no quote" "feature/$ida-work"
  local fa="$SB_WORK/progress/dev_complete/$ida-noquote.md"
  local rela="progress/dev_complete/$ida-noquote.md"
  perl -i -pe "s#^\\| AC1 \\| PASS \\| test \\|.*\\|\$#| AC1 | PASS | file:line | ${rela}:2 |#" "$fa"
  grep -qF "| AC1 | PASS | file:line | ${rela}:2 |" "$fa" \
    || _fixture_die "case_finish_pr_qa_verdict_quote_checks_refuse: (a) the unquoted row was not planted"
  publish_sandbox
  seed_branch "$ida" work CHANGE678A.txt

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-a" "$SB_WORK/scripts/finish-pr.sh" "$ida" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) a resolving pointer with no quote — finish-pr.sh exited 0"
  origin_has_path "CHANGE678A.txt" && cf "(a) the branch was merged before the refusal"
  grep -q 'refusal=qa-verdict-quote-missing' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
    || cf "(a) no progress record carries refusal=qa-verdict-quote-missing: $(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null)"

  # (b) a resolving pointer whose quote is real text, but not present on the cited line — the
  # motivating shape: real-looking, resolves, and does not show the claim. Line 2 is "id: <id>";
  # the quote names a sentence that is not that line's text.
  local idb="$SB_PREFIX-679"
  seed_issue dev_complete "$idb" wrongline chore "A quote that is not on the cited line" "feature/$idb-work"
  local fb="$SB_WORK/progress/dev_complete/$idb-wrongline.md"
  local relb="progress/dev_complete/$idb-wrongline.md"
  perl -i -pe "s#^\\| AC1 \\| PASS \\| test \\|.*\\|\$#| AC1 | PASS | file:line | ${relb}:2 \"this exact sentence is not on line 2\" |#" "$fb"
  grep -qF 'not on line 2' "$fb" \
    || _fixture_die "case_finish_pr_qa_verdict_quote_checks_refuse: (b) the mismatched-quote row was not planted"
  publish_sandbox
  seed_branch "$idb" work CHANGE679B.txt

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-b" "$SB_WORK/scripts/finish-pr.sh" "$idb" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) a quote not found on the cited line — finish-pr.sh exited 0"
  origin_has_path "CHANGE679B.txt" && cf "(b) the branch was merged before the refusal"
  grep -q 'refusal=qa-verdict-quote-not-found' "$SB_TMP/rec-b"/*.tsv 2>/dev/null \
    || cf "(b) no progress record carries refusal=qa-verdict-quote-not-found: $(cat "$SB_TMP/rec-b"/*.tsv 2>/dev/null)"

  finish "finish-pr.sh refuses a landing whose QA Verdict table has a test/file:line row with no quoted evidence (a, refusal=qa-verdict-quote-missing) or a quote that is not on the cited line (b, refusal=qa-verdict-quote-not-found)"
  teardown
}

# =============================================================================
# CASE — A TABLE OF ONLY gate-diff/fixture-diff ROWS REFUSES (qa-verdict-no-observed): those kinds carry
# no quote, so a table made only of them gives the gate nothing to re-read. One test/file:line row
# beside them lands.
# =============================================================================
case_finish_pr_qa_verdict_unquoted_kinds_only_refuses() {
  cf_reset
  make_sandbox

  # (a) every AC row is gate-diff: a real, non-placeholder pointer, nothing the gate can check.
  local ida="$SB_PREFIX-690"
  seed_issue dev_complete "$ida" gateonly chore "Only gate-diff rows" "feature/$ida-work"
  local fa="$SB_WORK/progress/dev_complete/$ida-gateonly.md"
  perl -i -pe 's/^\| AC1 \| PASS \| test \|.*\|$/| AC1 | PASS | gate-diff | verify.sh was green before and after |/' "$fa"
  grep -qF '| AC1 | PASS | gate-diff |' "$fa" \
    || _fixture_die "case_finish_pr_qa_verdict_unquoted_kinds_only_refuses: (a) the gate-diff-only row was not planted"
  publish_sandbox
  seed_branch "$ida" work CHANGE690A.txt

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-a" "$SB_WORK/scripts/finish-pr.sh" "$ida" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) a table of only gate-diff rows — finish-pr.sh exited 0"
  origin_has_path "CHANGE690A.txt" && cf "(a) the branch was merged before the refusal"
  origin_has_path "progress/qa_complete/$ida-gateonly.md" && cf "(a) the card advanced despite the refusal"
  grep -q 'refusal=qa-verdict-no-observed' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
    || cf "(a) no progress record carries refusal=qa-verdict-no-observed: $(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null)"

  # (b) CONTROL: the same gate-diff row beside one file:line row that quotes its own line lands.
  local idb="$SB_PREFIX-691"
  seed_issue dev_complete "$idb" mixed chore "A gate-diff row beside a quoted row" "feature/$idb-work"
  local fb="$SB_WORK/progress/dev_complete/$idb-mixed.md"
  local relb="progress/dev_complete/$idb-mixed.md" ac2="- [ ] AC2 — a second criterion, graded by a quoted line." ac2l
  perl -i -pe 's/^(- \[ \] AC1 — the sandbox.s seeded behaviour holds\.)$/$1\n- [ ] AC2 — a second criterion, graded by a quoted line./' "$fb"
  ac2l="$(grep -nF -- "$ac2" "$fb" | head -1 | cut -d: -f1)"
  [ -n "$ac2l" ] || _fixture_die "case_finish_pr_qa_verdict_unquoted_kinds_only_refuses: (b) the AC2 bullet was not planted"
  perl -i -pe 's#^\| AC1 \| PASS \| test \|.*\|$#| AC1 | PASS | gate-diff | verify.sh was green before and after |\n| AC2 | PASS | file:line | '"${relb}:${ac2l}"' "a second criterion" |#' "$fb"
  grep -qF "| AC2 | PASS | file:line |" "$fb" \
    || _fixture_die "case_finish_pr_qa_verdict_unquoted_kinds_only_refuses: (b) the mixed table was not planted"
  publish_sandbox
  seed_branch "$idb" work CHANGE690B.txt

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$idb" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) a gate-diff row beside a quoted file:line row — finish-pr.sh exited $rc: $(printf '%s' "$out" | tail -8 | tr '\n' '|')"
  origin_has_path "progress/qa_complete/$idb-mixed.md" || cf "(b) the card did not advance to qa_complete/"

  finish "finish-pr.sh refuses a landing whose QA Verdict table has no test/file:line row (a, refusal=qa-verdict-no-observed) and lands one that has a quoted row beside its gate-diff row (b)"
  teardown
}

# =============================================================================
# CASE — EVERY STOCK NON-ANSWER IS REFUSED AS A PLACEHOLDER, WHOLE-CELL, CASE-INSENSITIVE, NOT
# JUST THE TEMPLATE'S OWN '<placeholder>' TOKEN.
# =============================================================================
case_finish_pr_qa_verdict_placeholder_forms_refuse() {
  cf_reset
  make_sandbox

  local forms=('n/a' 'NA' 'None' 'TBD' 'see above' 'SEE BELOW' '-' '—' 'x' '...' '?' '<anything>')
  local n=680
  local form id f out rc
  for form in "${forms[@]}"; do
    id="$SB_PREFIX-$n"
    seed_issue dev_complete "$id" "ph$n" chore "Placeholder form '${form}'" "feature/$id-work"
    f="$SB_WORK/progress/dev_complete/$id-ph$n.md"
    perl -i -pe "s#^\\| AC1 \\| PASS \\| test \\|.*\\|\$#| AC1 | PASS | test | ${form} |#" "$f"
    publish_sandbox
    seed_branch "$id" work "CHANGE${n}.txt"

    out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-$n" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; rc=$?
    [ "$rc" -ne 0 ] || cf "'${form}' — finish-pr.sh exited 0"
    origin_has_path "CHANGE${n}.txt" && cf "'${form}' — the branch was merged before the refusal"
    grep -q 'refusal=qa-verdict-evidence-missing' "$SB_TMP/rec-$n"/*.tsv 2>/dev/null \
      || cf "'${form}' — no progress record carries refusal=qa-verdict-evidence-missing"
    n=$((n+1))
  done

  finish "finish-pr.sh refuses a landing whose QA Verdict pointer cell is a stock non-answer (n/a, na, none, tbd, see above, see below, -, —, x, ..., ?, or any <...> span — case-insensitive, whole cell) with a refusal=qa-verdict-evidence-missing record"
  teardown
}

# =============================================================================
# CASE — AN AC BULLET USING A HYPHEN OR COLON SEPARATOR (not the em-dash the table's own
# population used to require) IS READ INTO THE POPULATION, so an AC hiding behind either
# separator with no table row still refuses, instead of shipping silently.
# =============================================================================
case_finish_pr_qa_verdict_ac_separator_forms_refuse() {
  cf_reset
  make_sandbox

  # AC7 with a hyphen separator, AC8 with a colon separator — both missing their own table row.
  local id="$SB_PREFIX-692"
  seed_issue dev_complete "$id" seps chore "AC7 (hyphen) and AC8 (colon) have no table row" "feature/$id-work"
  local f="$SB_WORK/progress/dev_complete/$id-seps.md"
  # ^...$ anchors to the bullet's OWN line, never the QA Verdict row that quotes this text verbatim.
  perl -i -pe 's/^(- \[ \] AC1 — the sandbox.s seeded behaviour holds\.)$/$1\n- [ ] AC7 - a criterion separated by a hyphen, with no QA Verdict row.\n- [ ] AC8: a criterion separated by a colon, with no QA Verdict row./' "$f"
  grep -qF 'AC7 - a criterion' "$f" && grep -qF 'AC8: a criterion' "$f" \
    || _fixture_die "case_finish_pr_qa_verdict_ac_separator_forms_refuse: AC7/AC8 bullets were not planted"
  publish_sandbox
  seed_branch "$id" work CHANGE692.txt

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "AC7 (hyphen) and AC8 (colon) with no table rows — finish-pr.sh exited 0"
  case "$out" in *AC7*AC8*|*AC8*AC7*) : ;; *) cf "the refusal does not name both AC7 and AC8: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  origin_has_path "CHANGE692.txt" && cf "the branch was merged before the refusal"
  grep -q 'refusal=qa-verdict-ac-mismatch' "$SB_TMP/rec"/*.tsv 2>/dev/null \
    || cf "no progress record carries refusal=qa-verdict-ac-mismatch: $(cat "$SB_TMP/rec"/*.tsv 2>/dev/null)"

  finish "finish-pr.sh reads an AC bullet separated by a hyphen or a colon (not only the em-dash) into the one-for-one population, so AC7 (hyphen) and AC8 (colon) with no QA Verdict row both refuse the landing, naming both, with a refusal=qa-verdict-ac-mismatch record"
  teardown
}

# _fmt_token <card number> — the verdict-cell spelling planted in that card.
_fmt_token() {
  case "$1" in
    811) printf '%s' '`FAIL_AC`' ;;
    812) printf '%s' '`FAIL_REGRESSION`' ;;
    813) printf '%s' '**FAIL_AC**' ;;
    814) printf '%s' 'FAIL_REGRESSION' ;;
    *)   printf '%s' '`PASS`' ;;
  esac
}

# =============================================================================
# CASE — A FAIL VERDICT WRITTEN THE WAY THE CARD TEMPLATES SHOW IT IS STILL A FAIL. The templates
# and the QA role doc write the verdict tokens in backticks; the gate strips them from the other
# cells, so it strips them here: `FAIL_AC`, `FAIL_REGRESSION` and **FAIL_AC** each refuse a PASS
# landing exactly as the bare token does, and a backticked `PASS` still lands. One sandbox per
# spelling, each in the roles' order: card seeded and planted, published, branch cut, landing run.
# =============================================================================
case_finish_pr_qa_verdict_fail_token_formatting_refuses() {
  cf_reset
  local n tok f out rc
  for n in 811 812 813 814 815; do
    tok="$(_fmt_token "$n")"
    make_sandbox
    seed_issue dev_complete "$SB_PREFIX-$n" fmt chore "Verdict spelling $n" "feature/$SB_PREFIX-$n-work"
    f="$SB_WORK/progress/dev_complete/$SB_PREFIX-$n-fmt.md"
    TOK="$tok" perl -i -pe 's/^(\| AC1 \| )PASS( \| test \|.*\|)$/$1.$ENV{TOK}.$2/e' "$f"
    grep -qF -- "| AC1 | ${tok} |" "$f" \
      || _fixture_die "case_finish_pr_qa_verdict_fail_token_formatting_refuses: the verdict ${tok} was not planted in $SB_PREFIX-$n"
    publish_sandbox
    seed_branch "$SB_PREFIX-$n" work "CHANGE$n.txt"

    out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec" "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-$n" 2>&1 )"; rc=$?
    if [ "$n" = 815 ]; then
      [ "$rc" -eq 0 ] || cf "a backticked PASS verdict — finish-pr.sh exited $rc: $(printf '%s' "$out" | tail -8 | tr '\n' '|')"
      origin_has_path "progress/qa_complete/$SB_PREFIX-$n-fmt.md" || cf "the card with a backticked PASS did not advance to qa_complete/"
    else
      [ "$rc" -ne 0 ] || cf "a verdict written ${tok} on a PASS landing — finish-pr.sh exited 0"
      grep -q 'refusal=qa-verdict-fail' "$SB_TMP/rec"/*.tsv 2>/dev/null \
        || cf "the verdict ${tok} left no refusal=qa-verdict-fail record: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
      origin_has_path "CHANGE$n.txt" && cf "the verdict ${tok}: the branch was merged before the refusal"
    fi
    teardown
  done

  finish "finish-pr.sh reads a verdict written in backticks or bold as the token it spells: \`FAIL_AC\`, \`FAIL_REGRESSION\` and **FAIL_AC** refuse a PASS landing with a refusal=qa-verdict-fail record, and a backticked \`PASS\` lands"
}

# _tok_token <card number> — the verdict-cell spelling planted in that card.
_tok_token() {
  case "$1" in
    841) printf '%s' 'FAIL' ;;
    842) printf '%s' 'Fail_AC' ;;
    843) printf '%s' 'FAILED' ;;
    844) printf '%s' '<placeholder>' ;;
    *)   printf '%s' '`PASS_AC_CORRECTED`' ;;
  esac
}

# =============================================================================
# CASE — A VERDICT CELL THAT IS NOT ONE OF THE FOUR TOKENS REFUSES (qa-verdict-token-invalid). The gate
# compares the cell with the four tokens exactly; a mistyped FAIL would otherwise read as a pass. FAIL,
# Fail_AC, FAILED and an unfilled placeholder each refuse a PASS landing with a record and leave the
# trunk untouched; a backticked PASS_AC_CORRECTED lands. One sandbox per spelling, each in the roles'
# order: card seeded and planted, published, branch cut, landing run.
# =============================================================================
case_finish_pr_qa_verdict_token_invalid_refuses() {
  cf_reset
  local n tok f out rc
  for n in 841 842 843 844 845; do
    tok="$(_tok_token "$n")"
    make_sandbox
    seed_issue dev_complete "$SB_PREFIX-$n" tok chore "Verdict token $n" "feature/$SB_PREFIX-$n-work"
    f="$SB_WORK/progress/dev_complete/$SB_PREFIX-$n-tok.md"
    TOK="$tok" perl -i -pe 's/^(\| AC1 \| )PASS( \| test \|.*\|)$/$1.$ENV{TOK}.$2/e' "$f"
    grep -qF -- "| AC1 | ${tok} |" "$f" \
      || _fixture_die "case_finish_pr_qa_verdict_token_invalid_refuses: the verdict ${tok} was not planted in $SB_PREFIX-$n"
    publish_sandbox
    seed_branch "$SB_PREFIX-$n" work "CHANGE$n.txt"

    out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec" "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-$n" 2>&1 )"; rc=$?
    if [ "$n" = 845 ]; then
      [ "$rc" -eq 0 ] || cf "a backticked PASS_AC_CORRECTED verdict — finish-pr.sh exited $rc: $(printf '%s' "$out" | tail -8 | tr '\n' '|')"
      origin_has_path "progress/qa_complete/$SB_PREFIX-$n-tok.md" || cf "the card with a backticked PASS_AC_CORRECTED did not advance to qa_complete/"
    else
      [ "$rc" -ne 0 ] || cf "a verdict cell ${tok} on a PASS landing — finish-pr.sh exited 0"
      grep -q 'refusal=qa-verdict-token-invalid' "$SB_TMP/rec"/*.tsv 2>/dev/null \
        || cf "the verdict cell ${tok} left no refusal=qa-verdict-token-invalid record: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
      case "$out" in
        *PASS_AC_CORRECTED*) : ;;
        *) cf "the refusal for ${tok} does not name the four tokens: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;;
      esac
      origin_has_path "CHANGE$n.txt" && cf "the verdict cell ${tok}: the branch was merged before the refusal"
    fi
    teardown
  done

  finish "finish-pr.sh refuses a verdict cell outside PASS / PASS_AC_CORRECTED / FAIL_AC / FAIL_REGRESSION (FAIL, Fail_AC, FAILED, an unfilled placeholder) with a refusal=qa-verdict-token-invalid record naming the four, and lands a backticked PASS_AC_CORRECTED"
}

# =============================================================================
# CASE — THE GATE'S TOKEN SET IS THE SET MANUAL.md STEP 6 RATIFIES. qa-gate.sh holds KIT_QAV_VERDICTS;
# the ratifying table in process/MANUAL.md is the authoring site. Both are re-read from the shipped
# files (never restated here); the instrument is controlled first: an empty extraction on either side
# would make the comparison vacuous.
# =============================================================================
case_qa_gate_verdict_set_is_the_ratified_set() {
  cf_reset
  local manual="$REAL_REPO_ROOT/process/MANUAL.md" lib="$REAL_SCRIPTS/lib/qa-gate.sh" ratified gate n_ratified n_gate
  [ -f "$manual" ] || { skp "qa-gate.sh's verdict set is the set MANUAL step 6 ratifies" "process/MANUAL.md absent"; return; }
  ratified="$(_verdict_tokens_manual "$manual")"
  gate="$(sed -n "s/^KIT_QAV_VERDICTS='\\(.*\\)'\$/\\1/p" "$lib" | tr ' ' '\n' | grep . | sort || true)"
  n_ratified="$(printf '%s\n' "$ratified" | grep -c . || true)"
  n_gate="$(printf '%s\n' "$gate" | grep -c . || true)"
  [ "$n_ratified" -gt 0 ] || cf "no ratified verdict tokens were extracted from MANUAL.md — the comparison would be vacuous"
  [ "$n_gate" -gt 0 ] || cf "no KIT_QAV_VERDICTS declaration was found in qa-gate.sh — the comparison would be vacuous"
  [ "$gate" = "$ratified" ] \
    || cf "qa-gate.sh's KIT_QAV_VERDICTS [$(printf '%s' "$gate" | tr '\n' ' ')] is not the ratified set [$(printf '%s' "$ratified" | tr '\n' ' ')]"
  finish "qa-gate.sh's KIT_QAV_VERDICTS is exactly the verdict set process/MANUAL.md step 6 ratifies"
}
