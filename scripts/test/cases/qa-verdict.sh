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
  # still resolves with a real quote (ARCHIVE.md's first line), so the extra row is refused for
  # the AC mismatch, not for a pointer/quote problem of its own.
  local idb="$SB_PREFIX-656"
  seed_issue dev_complete "$idb" extrarow chore "Table names AC9, no such AC" "feature/$idb-work"
  local fb="$SB_WORK/progress/dev_complete/$idb-extrarow.md"
  perl -i -pe 's#^(\| AC1 \| PASS \| test \|.*\|)$#$1\n| AC9 | PASS | test | ARCHIVE.md:1 "condensed index of completed issues" |#' "$fb"
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

  # The population is derived from the scripts, never from the templates: every template a present script reads must
  # exist, and each one except the template a creator mints into requirements/ is a card template, which must carry a
  # frontmatter `type:` line and be judged. A deleted or typeless template stays in the population and fails; the
  # Refactorer's template leaves it exactly when new-refactor.sh is removed with the Refactorer.
  local sc tn tlist=""
  for sc in "$REAL_REPO_ROOT"/scripts/*.sh; do
    [ -f "$sc" ] || continue
    grep -q 'DEST_DIR="\$ROOT/requirements"' "$sc" && continue
    for tn in $(sed -n 's|.*TEMPLATE="\$[A-Za-z_]*/\.claude/templates/\([A-Z]*\)\.template\.md".*|\1|p' "$sc"); do
      case " $tlist " in *" $tn "*) ;; *) tlist="$tlist $tn" ;; esac
    done
  done
  # The other direction: a card template (one with a `type:` line) that no script reads means a creator stopped
  # matching the read above, or a template outlived its creator.
  for tf in "$tdir"/*.template.md; do
    [ -f "$tf" ] || continue
    tn="${tf##*/}"; tn="${tn%.template.md}"
    grep -qE '^type:[[:space:]]' "$tf" || continue
    case " $tlist " in *" $tn "*) ;; *) cf "$tn.template.md is a card template no shipped script reads" ;; esac
  done
  for tn in $tlist; do
    tf="$tdir/$tn.template.md"
    [ -f "$tf" ] || { cf "$tn.template.md is read by a shipped script but is not in $tdir"; cards=$((cards + 1)); continue; }
    grep -qE '^type:[[:space:]]' "$tf" || { cf "$tn.template.md has no frontmatter type: line"; cards=$((cards + 1)); continue; }
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
  [ "$cards" -ge 1 ] || cf "no card template is read by a shipped script, so nothing was judged"
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

  # (a) a file:line pointer that resolves (ARCHIVE.md line 1 — always present in the sandbox), with
  # no quote at all.
  local ida="$SB_PREFIX-678"
  seed_issue dev_complete "$ida" noquote chore "A resolving pointer with no quote" "feature/$ida-work"
  local fa="$SB_WORK/progress/dev_complete/$ida-noquote.md"
  perl -i -pe 's#^\| AC1 \| PASS \| test \|.*\|$#| AC1 | PASS | file:line | ARCHIVE.md:1 |#' "$fa"
  grep -qF '| AC1 | PASS | file:line | ARCHIVE.md:1 |' "$fa" \
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
  # motivating shape: real-looking, resolves, and does not show the claim. Line 1 is the archive's
  # heading; the quote names a sentence that is not that line's text.
  local idb="$SB_PREFIX-679"
  seed_issue dev_complete "$idb" wrongline chore "A quote that is not on the cited line" "feature/$idb-work"
  local fb="$SB_WORK/progress/dev_complete/$idb-wrongline.md"
  perl -i -pe 's#^\| AC1 \| PASS \| test \|.*\|$#| AC1 | PASS | file:line | ARCHIVE.md:1 "this exact sentence is not on line 1" |#' "$fb"
  grep -qF 'not on line 1' "$fb" \
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

  # (b) CONTROL: the same gate-diff row beside one file:line row that quotes the cited line lands.
  local idb="$SB_PREFIX-691"
  seed_issue dev_complete "$idb" mixed chore "A gate-diff row beside a quoted row" "feature/$idb-work"
  local fb="$SB_WORK/progress/dev_complete/$idb-mixed.md"
  local ac2="- [ ] AC2 — a second criterion, graded by a quoted line." ac2l
  perl -i -pe 's/^(- \[ \] AC1 — the sandbox.s seeded behaviour holds\.)$/$1\n- [ ] AC2 — a second criterion, graded by a quoted line./' "$fb"
  ac2l="$(grep -nF -- "$ac2" "$fb" | head -1 | cut -d: -f1)"
  [ -n "$ac2l" ] || _fixture_die "case_finish_pr_qa_verdict_unquoted_kinds_only_refuses: (b) the AC2 bullet was not planted"
  perl -i -pe 's#^\| AC1 \| PASS \| test \|.*\|$#| AC1 | PASS | gate-diff | verify.sh was green before and after |\n| AC2 | PASS | file:line | ARCHIVE.md:1 "condensed index of completed issues" |#' "$fb"
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
# CASE — AN AC BULLET USING A HYPHEN OR COLON SEPARATOR (not only the em-dash separator) IS READ INTO THE POPULATION, so an AC hiding behind either
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

# =============================================================================
# CASE — A MARKDOWN-ESCAPED PIPE (\|) INSIDE A VERDICT-TABLE CELL IS PART OF THE CELL.
# (a) the shipped template's own unfilled row refuses for the cells that are actually wrong — the
#     evidence kind and the pointer are '<placeholder>', and no cell reads 'PASS_AC_CORRECTED \';
# (b) a filled row whose quote contains \| lands when the cited line holds the pipe.
# =============================================================================
case_finish_pr_qa_verdict_escaped_pipe_is_one_cell() {
  cf_reset
  make_sandbox

  local ida="$SB_PREFIX-970" tpl='| AC1 | `<PASS \| PASS_AC_CORRECTED \| FAIL_AC \| FAIL_REGRESSION>` | `<placeholder>` | `<placeholder>` |'
  seed_issue dev_complete "$ida" tplrow chore "The template's unfilled row" "feature/$ida-work"
  local fa="$SB_WORK/progress/dev_complete/$ida-tplrow.md"
  KIT_ROW="$tpl" perl -i -pe 's/^\| AC1 \| PASS \| test \|.*\|$/$ENV{KIT_ROW}/' "$fa"
  grep -qF -- "$tpl" "$fa" || _fixture_die "case_finish_pr_qa_verdict_escaped_pipe_is_one_cell: (a) the template row was not planted"
  publish_sandbox
  seed_branch "$ida" work CHANGE970A.txt

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-a" "$SB_WORK/scripts/finish-pr.sh" "$ida" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) the template's unfilled row — finish-pr.sh exited 0"
  case "$out" in *"AC1 (evidence kind '<placeholder>')"*) : ;; *) cf "(a) the refusal does not name the evidence kind '<placeholder>': $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  case "$out" in *"AC1 (empty or placeholder pointer)"*) : ;; *) cf "(a) the refusal does not name AC1's placeholder pointer: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  case "$out" in *'PASS_AC_CORRECTED \'*) cf "(a) the refusal still reports a cell cut at the escaped pipe: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  origin_has_path "CHANGE970A.txt" && cf "(a) the branch was merged before the refusal"

  # (b) a quote with an escaped pipe, on a cited line that holds the pipe.
  local idb="$SB_PREFIX-971"
  seed_issue dev_complete "$idb" pipequote chore "A quote containing a pipe" "feature/$idb-work"
  local fb="$SB_WORK/progress/dev_complete/$idb-pipequote.md"
  printf '%s\n' 'use a | b to pipe' > "$SB_WORK/EVIDENCE971.txt"
  grep -qF -- 'use a | b to pipe' "$SB_WORK/EVIDENCE971.txt" || _fixture_die "case_finish_pr_qa_verdict_escaped_pipe_is_one_cell: (b) the pipe line was not planted"
  KIT_ROW="| AC1 | PASS | file:line | EVIDENCE971.txt:1 \"use a \\| b to pipe\" |" perl -i -pe 's/^\| AC1 \| PASS \| test \|.*\|$/$ENV{KIT_ROW}/' "$fb"
  grep -qF -- '"use a \| b to pipe"' "$fb" || _fixture_die "case_finish_pr_qa_verdict_escaped_pipe_is_one_cell: (b) the escaped-pipe quote row was not planted"
  publish_sandbox
  seed_branch "$idb" work CHANGE971B.txt

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$idb" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) a quote written \"use a \\| b to pipe\" on a line holding 'use a | b to pipe' — finish-pr.sh exited $rc: $(printf '%s' "$out" | tail -8 | tr '\n' '|')"
  origin_has_path "progress/qa_complete/$idb-pipequote.md" || cf "(b) the card did not advance to qa_complete/"

  finish "finish-pr.sh reads a markdown-escaped pipe as part of its cell: the template's unfilled row is refused for its placeholder kind and pointer (a), and a quote written with \\| lands when the cited line holds the pipe (b)"
  teardown
}

# =============================================================================
# _qvp_land <id> <slug> <row template>  — land a card whose AC1 row is the template, and leave the
# result in _QVP_OUT / _QVP_RC. In the template @CHG@ is the branch's own marker file (its line 1
# is "a real change") and @EV@ / @L@ are an evidence file (a copy of the card's text, never the card
# itself: the gate refuses a pointer to the card) and the line of its AC1 bullet (which holds
# "seeded behaviour holds"), so a quote is true or false on a line the fixture controls.
# An optional 4th argument is appended to the evidence file as a line of its own, @X@ being its line number.
# The card is cut, published and landed in the order the roles do it: seeded in dev_complete/,
# published to the trunk, the branch cut from it, finish-pr.sh run.
# =============================================================================
_QVP_OUT=""; _QVP_RC=0
_qvp_land() {
  local id="$1" slug="$2" tpl="$3" f="$SB_WORK/progress/dev_complete/$1-$2.md" ev="EVIDENCE${1##*-}.md" l x="" row chg
  chg="CHANGE${id##*-}.txt"
  seed_issue dev_complete "$id" "$slug" chore "Pointer-by-pointer row $id" "feature/$id-work"
  cp "$f" "$SB_WORK/$ev"
  l="$(grep -nF -- '- [ ] AC1 —' "$SB_WORK/$ev" | head -1 | cut -d: -f1)"
  [ -n "$l" ] || _fixture_die "_qvp_land: the AC1 bullet of $id was not found"
  # An optional 4th argument is a line appended to the evidence file; @X@ is its line number (so the
  # row template must be a single line).
  if [ -n "${4:-}" ]; then
    printf '%s\n' "$4" >> "$SB_WORK/$ev"
    x="$(wc -l < "$SB_WORK/$ev" | tr -d ' ')"
  fi
  row="${tpl//@CHG@/$chg}"; row="${row//@EV@/$ev}"; row="${row//@L@/$l}"; row="${row//@X@/$x}"
  KIT_ROW="$row" perl -i -pe 's/^\| AC1 \| PASS \| test \|.*\|$/$ENV{KIT_ROW}/' "$f"
  grep -qF -- "$(printf '%s' "$row" | head -1)" "$f" || _fixture_die "_qvp_land: the row of $id was not planted"
  publish_sandbox
  seed_branch "$id" work "$chg"
  _QVP_OUT="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-$id" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; _QVP_RC=$?
}

# _qvp_refused <label> <id> <slug> <rule> — the last _qvp_land was refused with <rule> and left the card where it was.
_qvp_refused() {
  [ "$_QVP_RC" -ne 0 ] || cf "$1: finish-pr.sh exited 0"
  grep -q "refusal=$4" "$SB_TMP/rec-$2"/*.tsv 2>/dev/null \
    || cf "$1: no progress record carries refusal=$4: $(cat "$SB_TMP/rec-$2"/*.tsv 2>/dev/null | cut -c1-200)"
  origin_has_path "progress/qa_complete/$2-$3.md" && cf "$1: the card advanced despite the refusal"
  return 0
}

# =============================================================================
# CASE — A ROW THAT CITES SEVERAL LOCATIONS IS CHECKED POINTER BY POINTER.
# Each quote is read against the path:line it follows: (a)/(b) two true pointers land in either
# order; (c) a false quote on the second pointer is refused naming THAT pointer; (d) a fabricated
# quote on the FIRST pointer is refused naming the first pointer (the last quote being true does not
# carry it); (e) a pointer with no quote of its own is qa-verdict-quote-missing, naming it.
# =============================================================================
case_finish_pr_qa_verdict_pointers_are_checked_one_by_one() {
  cf_reset
  make_sandbox

  local ida="$SB_PREFIX-980" idb="$SB_PREFIX-981" idc="$SB_PREFIX-982" idd="$SB_PREFIX-983" ide="$SB_PREFIX-984"

  _qvp_land "$ida" truefirst '| AC1 | PASS | file:line | @CHG@:1 "a real change"; @EV@:@L@ "seeded behaviour holds" |'
  [ "$_QVP_RC" -eq 0 ] || cf "(a) two true pointers, each with its own true quote — finish-pr.sh exited $_QVP_RC: $(printf '%s' "$_QVP_OUT" | tail -4 | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/qa_complete/$ida-truefirst.md" || cf "(a) the card did not advance to qa_complete/"

  _qvp_land "$idb" swapped '| AC1 | PASS | file:line | @EV@:@L@ "seeded behaviour holds"; @CHG@:1 "a real change" |'
  [ "$_QVP_RC" -eq 0 ] || cf "(b) the same two true pointers in the other order — finish-pr.sh exited $_QVP_RC: $(printf '%s' "$_QVP_OUT" | tail -4 | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/qa_complete/$idb-swapped.md" || cf "(b) the card did not advance to qa_complete/"

  _qvp_land "$idc" falsesecond '| AC1 | PASS | file:line | @CHG@:1 "a real change"; @EV@:@L@ "this sentence is on no line of the card" |'
  _qvp_refused "(c) a false quote on the second pointer" "$idc" falsesecond qa-verdict-quote-not-found
  case "$_QVP_OUT" in *'"this sentence is on no line of the card" not found at EVIDENCE'"${idc##*-}"'.md:'*) : ;; *) cf "(c) the refusal does not name the second pointer for its quote: $(printf '%s' "$_QVP_OUT" | tr '\n' '|' | cut -c1-400)" ;; esac
  case "$_QVP_OUT" in *"not found at CHANGE982.txt"*) cf "(c) the refusal names the first pointer, which holds its quote: $(printf '%s' "$_QVP_OUT" | tr '\n' '|' | cut -c1-400)" ;; esac

  _qvp_land "$idd" fabricatedfirst '| AC1 | PASS | file:line | @CHG@:1 "kit-init refuses a blank principal"; @EV@:@L@ "seeded behaviour holds" |'
  _qvp_refused "(d) a fabricated quote on the first pointer, the last quote true" "$idd" fabricatedfirst qa-verdict-quote-not-found
  case "$_QVP_OUT" in *'"kit-init refuses a blank principal" not found at CHANGE983.txt:1-1'*) : ;; *) cf "(d) the refusal does not name the first pointer for its quote: $(printf '%s' "$_QVP_OUT" | tr '\n' '|' | cut -c1-400)" ;; esac

  _qvp_land "$ide" noquote '| AC1 | PASS | file:line | @CHG@:1 "a real change"; @EV@:@L@ (same claim, no quote) |'
  _qvp_refused "(e) a second pointer whose quote was deleted" "$ide" noquote qa-verdict-quote-missing
  case "$_QVP_OUT" in *"AC1 (EVIDENCE${ide##*-}.md:"*) : ;; *) cf "(e) the refusal does not name the pointer that has no quote: $(printf '%s' "$_QVP_OUT" | tr '\n' '|' | cut -c1-400)" ;; esac
  case "$_QVP_OUT" in *"AC1 (CHANGE984.txt"*) cf "(e) the refusal names the first pointer, which has its quote: $(printf '%s' "$_QVP_OUT" | tr '\n' '|' | cut -c1-400)" ;; esac

  finish "finish-pr.sh reads each quote of a multi-pointer row against the path:line it follows: two true pointers land in either order (a, b); a false quote is refused naming its own pointer, whichever pointer holds it (c, d); a pointer with no quote of its own is qa-verdict-quote-missing naming that pointer (e)"
  teardown
}

# =============================================================================
# CASE — ONE ROW PER AC ID, AND A QUOTE OF AT LEAST EIGHT CHARACTERS.
# (a) two rows for one AC id are refused (qa-verdict-ac-duplicate) with the id named and the legitimate
#     shape (one row, several pointers) in the Next line; (b) a seven-character quote that is on its
#     line is refused (qa-verdict-quote-too-short) naming its pointer; (c) the same line quoted at
#     eight characters lands; (d) a quote shorter than eight that is the cited line's whole text lands
#     (a version stamp is a short line).
# =============================================================================
case_finish_pr_qa_verdict_one_row_per_ac_and_quote_floor() {
  cf_reset
  make_sandbox

  local ida="$SB_PREFIX-985" idb="$SB_PREFIX-986" idc="$SB_PREFIX-987" idd="$SB_PREFIX-988"

  _qvp_land "$ida" duplicate '| AC1 | PASS | file:line | @CHG@:1 "a real change" |
| AC1 | PASS | file:line | @EV@:@L@ "seeded behaviour holds" |'
  _qvp_refused "(a) two rows for AC1" "$ida" duplicate qa-verdict-ac-duplicate
  case "$_QVP_OUT" in *"more than one row"*AC1*) : ;; *) cf "(a) the refusal does not name AC1 as repeated: $(printf '%s' "$_QVP_OUT" | tr '\n' '|' | cut -c1-400)" ;; esac
  case "$_QVP_OUT" in *"Next:"*"one row"*"every pointer"*) : ;; *) cf "(a) the Next line does not name the one-row shape: $(printf '%s' "$_QVP_OUT" | tr '\n' '|' | cut -c1-500)" ;; esac

  _qvp_land "$idb" sevenchars '| AC1 | PASS | file:line | @CHG@:1 "real ch" |'
  _qvp_refused "(b) a seven-character quote" "$idb" sevenchars qa-verdict-quote-too-short
  case "$_QVP_OUT" in *'AC1 (CHANGE986.txt:1 "real ch")'*) : ;; *) cf "(b) the refusal does not name the short quote and its pointer: $(printf '%s' "$_QVP_OUT" | tr '\n' '|' | cut -c1-400)" ;; esac

  _qvp_land "$idc" eightchars '| AC1 | PASS | file:line | @CHG@:1 "real cha" |'
  [ "$_QVP_RC" -eq 0 ] || cf "(c) an eight-character quote on its line — finish-pr.sh exited $_QVP_RC: $(printf '%s' "$_QVP_OUT" | tail -4 | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/qa_complete/$idc-eightchars.md" || cf "(c) the card did not advance to qa_complete/"

  # The card's own line 1 is the frontmatter fence: three characters, and the whole line.
  _qvp_land "$idd" wholeline '| AC1 | PASS | file:line | @EV@:1 "---" |'
  [ "$_QVP_RC" -eq 0 ] || cf "(d) a short quote that is the cited line's whole text — finish-pr.sh exited $_QVP_RC: $(printf '%s' "$_QVP_OUT" | tail -4 | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/qa_complete/$idd-wholeline.md" || cf "(d) the card did not advance to qa_complete/"

  finish "finish-pr.sh refuses a table with two rows for one AC id (a, qa-verdict-ac-duplicate) and a quote shorter than eight characters (b, qa-verdict-quote-too-short), lands the same line quoted at eight (c) and lands a shorter quote that is the cited line's whole text (d)"
  teardown
}

# =============================================================================
# CASE — A VERBATIM QUOTE OF A BACKTICKED LINE LANDS.
# The evidence cell is read with its backticks removed, so the cited line is read without them too.
# (a) the quote written verbatim, backticks and all; (b) the same quote with the backticks dropped;
# (c) a quote that differs from the line by a word is still refused; (d) a short quote that is a
# backticked line's whole text lands.
# =============================================================================
case_finish_pr_qa_verdict_quote_of_a_backticked_line() {
  cf_reset
  make_sandbox

  local ida="$SB_PREFIX-990" idb="$SB_PREFIX-991" idc="$SB_PREFIX-992" idd="$SB_PREFIX-993"
  local line='- 2026-01-02 [PM] the `statement`, `offer-notes` and `tenure` are listed:'

  _qvp_land "$ida" verbatim '| AC1 | PASS | file:line | @EV@:@X@ "the `statement`, `offer-notes` and `tenure` are listed:" |' "$line"
  [ "$_QVP_RC" -eq 0 ] || cf "(a) a quote of a backticked line, written verbatim — finish-pr.sh exited $_QVP_RC: $(printf '%s' "$_QVP_OUT" | tail -4 | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/qa_complete/$ida-verbatim.md" || cf "(a) the card did not advance to qa_complete/"

  _qvp_land "$idb" stripped '| AC1 | PASS | file:line | @EV@:@X@ "the statement, offer-notes and tenure are listed:" |' "$line"
  [ "$_QVP_RC" -eq 0 ] || cf "(b) the same quote written without its backticks — finish-pr.sh exited $_QVP_RC: $(printf '%s' "$_QVP_OUT" | tail -4 | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/qa_complete/$idb-stripped.md" || cf "(b) the card did not advance to qa_complete/"

  _qvp_land "$idc" otherword '| AC1 | PASS | file:line | @EV@:@X@ "the `statement`, `offer-notes` and `lease` are listed:" |' "$line"
  _qvp_refused "(c) a quote that differs from the backticked line by a word" "$idc" otherword qa-verdict-quote-not-found
  case "$_QVP_OUT" in *'"the statement, offer-notes and lease are listed:" not found at EVIDENCE'"${idc##*-}"'.md:'*) : ;; *) cf "(c) the refusal does not name the quote and its pointer: $(printf '%s' "$_QVP_OUT" | tr '\n' '|' | cut -c1-400)" ;; esac

  _qvp_land "$idd" wholeline '| AC1 | PASS | file:line | @EV@:@X@ "`tag-1`" |' '`tag-1`'
  [ "$_QVP_RC" -eq 0 ] || cf "(d) a short quote that is a backticked line's whole text — finish-pr.sh exited $_QVP_RC: $(printf '%s' "$_QVP_OUT" | tail -4 | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/qa_complete/$idd-wholeline.md" || cf "(d) the card did not advance to qa_complete/"

  finish "finish-pr.sh compares a quote and the cited line without backticks: a verbatim quote of a backticked line lands (a), so does the same quote written without them (b), a quote that differs by a word is qa-verdict-quote-not-found (c), and a short quote that is a backticked line's whole text lands (d)"
  teardown
}

# =============================================================================
# CASE — ONLY A POINTER'S OWN QUOTES ARE READ; A QUOTED PHRASE IN PROSE IS NOT.
# The first double-quoted string after a pointer is its quote; a later one is a quote only when it
# follows the previous quote with whitespace or `;` alone between. (a) prose after a pointer and its
# quote, with a quoted phrase the line lacks, lands; (b) a word between the pointer and its quote
# lands; (c) two adjacent quotes, the second absent from the line, are refused; (d) the same with a
# `;` between; (e) a fabricated first quote is refused whatever follows it; (f) a quoted phrase
# after prose that follows an adjacent pair is not read, and the pair is.
# =============================================================================
case_finish_pr_qa_verdict_prose_quotes_are_not_read() {
  cf_reset
  make_sandbox

  local ida="$SB_PREFIX-920" idb="$SB_PREFIX-921" idc="$SB_PREFIX-922" idd="$SB_PREFIX-923" ide="$SB_PREFIX-924" idf="$SB_PREFIX-925"

  _qvp_land "$ida" proseafter '| AC1 | PASS | file:line | @EV@:@L@ "seeded behaviour holds" and grep finds no "not available" anywhere |'
  [ "$_QVP_RC" -eq 0 ] || cf "(a) a pointer, its true quote, then prose quoting a phrase the line lacks — finish-pr.sh exited $_QVP_RC: $(printf '%s' "$_QVP_OUT" | tail -4 | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/qa_complete/$ida-proseafter.md" || cf "(a) the card did not advance to qa_complete/"

  _qvp_land "$idb" wordbefore '| AC1 | PASS | file:line | @EV@:@L@ says "seeded behaviour holds" |'
  [ "$_QVP_RC" -eq 0 ] || cf "(b) a word between the pointer and its quote — finish-pr.sh exited $_QVP_RC: $(printf '%s' "$_QVP_OUT" | tail -4 | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/qa_complete/$idb-wordbefore.md" || cf "(b) the card did not advance to qa_complete/"

  _qvp_land "$idc" adjacent '| AC1 | PASS | file:line | @EV@:@L@ "seeded behaviour holds" "a sentence on no line of the card" |'
  _qvp_refused "(c) an adjacent second quote the line lacks" "$idc" adjacent qa-verdict-quote-not-found
  case "$_QVP_OUT" in *'"a sentence on no line of the card" not found at EVIDENCE'"${idc##*-}"'.md:'*) : ;; *) cf "(c) the refusal does not name the second quote: $(printf '%s' "$_QVP_OUT" | tr '\n' '|' | cut -c1-400)" ;; esac

  _qvp_land "$idd" semicolon '| AC1 | PASS | file:line | @EV@:@L@ "seeded behaviour holds"; "a sentence on no line of the card" |'
  _qvp_refused "(d) a second quote after a semicolon, the line lacks it" "$idd" semicolon qa-verdict-quote-not-found
  case "$_QVP_OUT" in *'"a sentence on no line of the card" not found at EVIDENCE'"${idd##*-}"'.md:'*) : ;; *) cf "(d) the refusal does not name the second quote: $(printf '%s' "$_QVP_OUT" | tr '\n' '|' | cut -c1-400)" ;; esac

  _qvp_land "$ide" fabricatedfirst '| AC1 | PASS | file:line | @CHG@:1 "kit-init refuses a blank principal" and also "a real change" |'
  _qvp_refused "(e) a fabricated first quote with a true phrase after it" "$ide" fabricatedfirst qa-verdict-quote-not-found
  case "$_QVP_OUT" in *'"kit-init refuses a blank principal" not found at CHANGE924.txt:1-1'*) : ;; *) cf "(e) the refusal does not name the first quote: $(printf '%s' "$_QVP_OUT" | tr '\n' '|' | cut -c1-400)" ;; esac

  _qvp_land "$idf" pairthenprose '| AC1 | PASS | file:line | @EV@:@L@ "seeded behaviour holds" "the sandbox" then "not available" |'
  [ "$_QVP_RC" -eq 0 ] || cf "(f) an adjacent true pair, then a quoted phrase after prose — finish-pr.sh exited $_QVP_RC: $(printf '%s' "$_QVP_OUT" | tail -4 | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/qa_complete/$idf-pairthenprose.md" || cf "(f) the card did not advance to qa_complete/"

  finish "finish-pr.sh reads a pointer's first quote and each quote that follows the previous one with only whitespace or ';' between, and nothing else in double quotes: prose after a quote (a) and a word before the first quote (b) land; an adjacent second quote the line lacks is refused with or without a ';' (c, d); a fabricated first quote is refused whatever follows (e); an adjacent true pair then a prose phrase lands (f)"
  teardown
}

# =============================================================================
# CASE — move-issue.sh <ID> qa_complete READS THE QA VERDICT TABLE AT THE TRUNK TIP.
# The direct-to-trunk route (no branch, no finish-pr.sh) and the by-hand landing both end in this
# move, so it runs the landing's own check. Each card is the real workflow's order: seeded in
# dev_complete/, the table either left as the template or filled, then moved as QA.
# (a) the template table, committed to the trunk: refused, naming register-commit.sh, nothing moved;
# (b) the Subject's own sequence — the table filled in a LOCAL commit that was not pushed — is
#     refused (the mover reads the trunk), and lands once that commit is on the trunk;
# (c) finish-pr.sh's own landing of a filled card still succeeds and says it skipped the check;
# (d) the skip cannot be passed by hand: --landed-at with a commit that is not that card's
#     squash on the trunk is refused, and the card stays put.
# =============================================================================
_mvq_template_table() {  # <card file> — the QA Verdict rows as the card templates ship them
  KIT_ROW='| AC1 | `<PASS \| PASS_AC_CORRECTED \| FAIL_AC \| FAIL_REGRESSION>` | `<placeholder>` | `<placeholder>` |' \
    perl -i -pe 's/^\| AC1 \| PASS \| test \|.*\|$/$ENV{KIT_ROW}/' "$1"
  KIT_ROW='| shadow-check | — | — | `<assertions removed: none — or each removed or weakened assertion, with its replacement>` |' \
    perl -i -pe 's/^\| shadow-check \|.*\|$/$ENV{KIT_ROW}/' "$1"
  grep -qF '`<placeholder>`' "$1" && grep -qF '<assertions removed: none' "$1" \
    || _fixture_die "_mvq_template_table: the template rows were not planted in $1"
}

_mvq_seed_template() {  # <id> <slug> <title> [<path to keep the filled card at>] — a dev_complete card whose table is the template
  seed_issue dev_complete "$1" "$2" chore "$3"
  [ -z "${4:-}" ] || cp "$SB_WORK/progress/dev_complete/$1-$2.md" "$4"
  _mvq_template_table "$SB_WORK/progress/dev_complete/$1-$2.md"
}

case_move_issue_qa_complete_runs_the_verdict_check() {
  cf_reset
  make_sandbox

  local ida="$SB_PREFIX-694" idb="$SB_PREFIX-695" idc="$SB_PREFIX-696" idd="$SB_PREFIX-697"
  local out rc fb="$SB_WORK/progress/dev_complete/$SB_PREFIX-695-subject.md"

  # (c) a filled card with a branch, for finish-pr.sh.
  seed_issue dev_complete "$idc" landed chore "Filled card, landed by finish-pr.sh" "feature/$idc-work"
  # (a) a direct-to-trunk card whose table is the template, on the trunk; (b) the Subject's card,
  # its filled table kept aside for the local commit; (d) a template card for the forged-flag rows.
  _mvq_seed_template "$ida" direct "Direct to trunk, template table"
  _mvq_seed_template "$idb" subject "Table filled locally, not pushed" "$SB_TMP/$idb.filled"
  _mvq_seed_template "$idd" forged "Template table, forged skip"
  publish_sandbox
  seed_branch "$idc" work CHANGE696.txt

  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-a" ./scripts/move-issue.sh "$ida" qa_complete --role QA --note "Review PASS, direct to trunk" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) a template table — move-issue.sh qa_complete exited 0"
  case "$out" in *register-commit.sh*) : ;; *) cf "(a) the refusal's Next does not name register-commit.sh: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  grep -q 'refusal=qa-verdict-evidence-missing' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
    || cf "(a) no progress record carries refusal=qa-verdict-evidence-missing: $(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null | cut -c1-200)"
  origin_has_path "progress/qa_complete/$ida-direct.md" && cf "(a) the card reached qa_complete/ despite the refusal"
  origin_has_path "progress/dev_complete/$ida-direct.md" || cf "(a) the card left dev_complete/ during the refusal"

  # (b) filled in a local commit, NOT published.
  cp "$SB_TMP/$idb.filled" "$fb"
  git -C "$SB_WORK" add "progress/dev_complete/$idb-subject.md" >/dev/null 2>&1
  sbcommit -m "[QA] $idb: fill the verdict" --quiet >/dev/null 2>&1
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-b" ./scripts/move-issue.sh "$idb" qa_complete --role QA --note "Review PASS" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) the table filled in an unpublished commit — the move exited 0"
  origin_has_path "progress/qa_complete/$idb-subject.md" && cf "(b) the card reached qa_complete/ with the template table on the trunk"
  grep -q 'refusal=qa-verdict-' "$SB_TMP/rec-b"/*.tsv 2>/dev/null \
    || cf "(b) no progress record carries a qa-verdict refusal: $(cat "$SB_TMP/rec-b"/*.tsv 2>/dev/null | cut -c1-200)"
  # (a failed push here means the trunk moved on, which only an unrefused move above can cause)
  if git -C "$SB_WORK" push origin "$SB_TRUNK" --quiet >/dev/null 2>&1; then
    out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-b2" ./scripts/move-issue.sh "$idb" qa_complete --role QA --note "Review PASS" 2>&1 )"; rc=$?
    [ "$rc" -eq 0 ] || cf "(b) the same move after publishing the table exited $rc: $(printf '%s' "$out" | tail -4 | tr '\n' '|' | cut -c1-300)"
    origin_has_path "progress/qa_complete/$idb-subject.md" || cf "(b) the card did not reach qa_complete/ once its table was on the trunk"
  else
    cf "(b) the filled table could not be published: the trunk had moved on"
  fi

  # (c) finish-pr.sh lands a filled card and the mover it calls skips the check, saying so.
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-c" "$SB_WORK/scripts/finish-pr.sh" "$idc" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(c) finish-pr.sh on a filled card exited $rc: $(printf '%s' "$out" | tail -4 | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/qa_complete/$idc-landed.md" || cf "(c) the card did not reach qa_complete/"
  case "$out" in *"QA Verdict check skipped"*) : ;; *) cf "(c) the move did not say it skipped the check: $(printf '%s' "$out" | tail -8 | tr '\n' '|' | cut -c1-300)" ;; esac

  # (d) the skip is not a flag a seat can pass by hand: a trunk commit that is not this card's squash.
  local other
  other="$(git -C "$SB_WORK" rev-parse "origin/$SB_TRUNK~1")"
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-d" ./scripts/move-issue.sh "$idd" qa_complete --role QA --note "Review PASS" --landed-at "$other" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(d) --landed-at naming a commit that is not the card's squash — the move exited 0"
  grep -q 'refusal=landed-at-unverified' "$SB_TMP/rec-d"/*.tsv 2>/dev/null \
    || cf "(d) no progress record carries refusal=landed-at-unverified: $(cat "$SB_TMP/rec-d"/*.tsv 2>/dev/null | cut -c1-200)"
  case "$out" in *"Next:"*) : ;; *) cf "(d) the refusal names no next action: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-d2" ./scripts/move-issue.sh "$idd" qa_complete --role QA --note "Review PASS" --landed-at not-a-commit 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(d) --landed-at naming no commit — the move exited 0"
  origin_has_path "progress/qa_complete/$idd-forged.md" && cf "(d) the template card reached qa_complete/ through a forged --landed-at"

  finish "move-issue.sh <ID> qa_complete refuses a card whose QA Verdict table is the template on the trunk (a), including the table filled in a commit not yet published (b, which lands once published); finish-pr.sh's own landing of a filled card still succeeds and the mover says it skipped the check (c); --landed-at is verified against the card's squash on the trunk and a hand-passed value is refused (d)"
  teardown
}

# =============================================================================
# CASE — THE LANDING'S ACTIVITY ENTRY NAMES THE REVISIONS IT READ. A pointer is a coordinate in a
# tree that moves, so the card records which tree the QA Verdict was read in:
# (a) finish-pr.sh's entry names the branch tip the verdict gate read and the squash commit it
#     landed — both resolve in the repository, and the read one is the branch tip (the squash is not);
# (b) a direct-to-trunk move-issue.sh ... qa_complete names the trunk tip it read, and it resolves
#     to the commit the trunk stood at before the move.
# =============================================================================
case_qa_landing_activity_names_the_revision_read() {
  cf_reset
  make_sandbox

  local ida="$SB_PREFIX-698" idb="$SB_PREFIX-699"
  seed_issue dev_complete "$ida" landed chore "Landed by finish-pr.sh" "feature/$ida-work"
  seed_issue dev_complete "$idb" direct chore "Direct to trunk"
  publish_sandbox
  seed_branch "$ida" work CHANGE698.txt
  local tip entry out rc fa fb
  tip="$(git -C "$SB_WORK" rev-parse "feature/$ida-work")"

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-a" "$SB_WORK/scripts/finish-pr.sh" "$ida" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) finish-pr.sh exited $rc: $(printf '%s' "$out" | tail -4 | tr '\n' '|' | cut -c1-300)"
  git -C "$SB_WORK" fetch origin --quiet >/dev/null 2>&1
  fa="$(git -C "$SB_WORK" show "origin/$SB_TRUNK:progress/qa_complete/$ida-landed.md" 2>/dev/null)"
  entry="$(printf '%s\n' "$fa" | grep -F 'Review — PASS. Squash-merged' | tail -1)"
  [ -n "$entry" ] || cf "(a) the card carries no 'Review — PASS. Squash-merged' entry"
  # every 7+ hex token on the entry's line must resolve; the branch tip must be one, and the squash another
  local tok seen_tip=0 seen_other=0 n=0
  for tok in $(printf '%s\n' "$entry" | grep -oE "[0-9a-f]{7,40}"); do
    n=$((n + 1))
    git -C "$SB_WORK" cat-file -e "${tok}^{commit}" 2>/dev/null || { cf "(a) '$tok' on the entry does not resolve to a commit"; continue; }
    if [ "$(git -C "$SB_WORK" rev-parse "${tok}^{commit}")" = "$tip" ]; then seen_tip=1; else seen_other=1; fi
  done
  [ "$seen_tip" -eq 1 ] || cf "(a) the entry does not name the branch tip the gate read ($tip): $entry"
  [ "$seen_other" -eq 1 ] || cf "(a) the entry names no squash commit besides the branch tip: $entry"
  [ "$n" -ge 2 ] || cf "(a) the entry names fewer than two revisions: $entry"
  case "$entry" in *$'\n'*) cf "(a) the entry is not one line" ;; esac

  # (b) the trunk tip the move reads
  local before
  git -C "$SB_WORK" fetch origin --quiet >/dev/null 2>&1
  before="$(git -C "$SB_WORK" rev-parse "origin/$SB_TRUNK")"
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-b" ./scripts/move-issue.sh "$idb" qa_complete --role QA --note "Review PASS, direct to trunk" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) move-issue.sh qa_complete exited $rc: $(printf '%s' "$out" | tail -4 | tr '\n' '|' | cut -c1-300)"
  git -C "$SB_WORK" fetch origin --quiet >/dev/null 2>&1
  fb="$(git -C "$SB_WORK" show "origin/$SB_TRUNK:progress/qa_complete/$idb-direct.md" 2>/dev/null)"
  entry="$(printf '%s\n' "$fb" | grep -F 'direct to trunk' | tail -1)"
  [ -n "$entry" ] || cf "(b) the card carries no entry for the move"
  seen_tip=0
  for tok in $(printf '%s\n' "$entry" | grep -oE "[0-9a-f]{7,40}"); do
    git -C "$SB_WORK" cat-file -e "${tok}^{commit}" 2>/dev/null || { cf "(b) '$tok' on the entry does not resolve to a commit"; continue; }
    [ "$(git -C "$SB_WORK" rev-parse "${tok}^{commit}")" = "$before" ] && seen_tip=1
  done
  [ "$seen_tip" -eq 1 ] || cf "(b) the entry does not name the trunk tip the move read ($before): $entry"

  finish "finish-pr.sh's Activity entry names the branch tip the verdict gate read and the squash commit it landed (a), and a direct-to-trunk move to qa_complete names the trunk tip it read (b); every revision named resolves in the repository"
  teardown
}

# =============================================================================
# CASE — EVERY LANDING WRITES THE REVISION CLAUSE, ONE STRING ON BOTH ROUTES.
# The clause is "(verdict read at <short sha>)": finish-pr.sh appends it to an operator's --note
# instead of letting the note replace it, writes it alone when there is no note, and the direct-to-
# trunk move writes the same string. Each card is the real workflow's order: seeded in dev_complete/,
# published, the branch cut from the trunk where there is one, then the route run.
# (a) finish-pr.sh with --note: the entry holds the note's words and the clause, with the branch tip;
# (b) finish-pr.sh without --note: the clause is there, as the default note composes it;
# (c) move-issue.sh ... qa_complete, no branch: the same clause, with the trunk tip it read.
# =============================================================================
case_landing_note_always_carries_the_revision_clause() {
  cf_reset
  make_sandbox

  local ida="$SB_PREFIX-940" idb="$SB_PREFIX-941" idc="$SB_PREFIX-942"
  seed_issue dev_complete "$ida" withnote chore "Landed with an operator note" "feature/$ida-work"
  seed_issue dev_complete "$idb" nonote chore "Landed without a note" "feature/$idb-work"
  seed_issue dev_complete "$idc" direct chore "Direct to trunk"
  publish_sandbox
  seed_branch "$ida" work CHANGE940.txt
  seed_branch "$idb" work CHANGE941.txt
  local tipa tipb before out rc entry
  tipa="$(git -C "$SB_WORK" rev-parse --short "feature/$ida-work")"
  tipb="$(git -C "$SB_WORK" rev-parse --short "feature/$idb-work")"

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-a" "$SB_WORK/scripts/finish-pr.sh" "$ida" --note "Reviewed by hand, all rows hold." 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) finish-pr.sh --note exited $rc: $(printf '%s' "$out" | tail -4 | tr '\n' '|' | cut -c1-300)"
  git -C "$SB_WORK" fetch origin --quiet >/dev/null 2>&1
  entry="$(git -C "$SB_WORK" show "origin/$SB_TRUNK:progress/qa_complete/$ida-withnote.md" 2>/dev/null | grep -F '→ qa_complete' | tail -1)"
  case "$entry" in *"Reviewed by hand, all rows hold."*) : ;; *) cf "(a) the operator's words are not on the entry: $entry" ;; esac
  case "$entry" in *"(verdict read at $tipa)"*) : ;; *) cf "(a) the entry does not hold '(verdict read at $tipa)': $entry" ;; esac

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-b" "$SB_WORK/scripts/finish-pr.sh" "$idb" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) finish-pr.sh without --note exited $rc: $(printf '%s' "$out" | tail -4 | tr '\n' '|' | cut -c1-300)"
  git -C "$SB_WORK" fetch origin --quiet >/dev/null 2>&1
  entry="$(git -C "$SB_WORK" show "origin/$SB_TRUNK:progress/qa_complete/$idb-nonote.md" 2>/dev/null | grep -F '→ qa_complete' | tail -1)"
  case "$entry" in *"Squash-merged"*"(verdict read at $tipb)"*) : ;; *) cf "(b) the default entry does not hold '(verdict read at $tipb)': $entry" ;; esac

  git -C "$SB_WORK" fetch origin --quiet >/dev/null 2>&1
  before="$(git -C "$SB_WORK" rev-parse --short "origin/$SB_TRUNK")"
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-c" ./scripts/move-issue.sh "$idc" qa_complete --role QA --note "Review PASS, direct to trunk" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(c) move-issue.sh qa_complete exited $rc: $(printf '%s' "$out" | tail -4 | tr '\n' '|' | cut -c1-300)"
  git -C "$SB_WORK" fetch origin --quiet >/dev/null 2>&1
  entry="$(git -C "$SB_WORK" show "origin/$SB_TRUNK:progress/qa_complete/$idc-direct.md" 2>/dev/null | grep -F '→ qa_complete' | tail -1)"
  case "$entry" in *"Review PASS, direct to trunk (verdict read at $before)"*) : ;; *) cf "(c) the direct move does not end '(verdict read at $before)': $entry" ;; esac

  finish "a landing's Activity entry carries '(verdict read at <sha>)' on both routes: finish-pr.sh appends it to an operator --note (a) and writes it in the default note (b), and the direct-to-trunk move writes the same string (c)"
  teardown
}

# =============================================================================
# CASE — A QA VERDICT ROW WHOSE EVIDENCE POINTER IS THE CARD'S OWN FILE REFUSES, ON EVERY ROUTE.
# The card records the review; it is not the content reviewed, and its path changes at every board
# move: a pointer written at progress/dev_complete/<card>.md resolves before the move and not after.
# Each card is the real workflow's order: seeded in dev_complete/, its table pointing at the card,
# published to the trunk, the branch cut from it where there is one, then the route run.
# This case is the landing route; the next is the direct-to-trunk mover and the reader.
# =============================================================================
_qsp_point() {  # <card file> <repo-relative target> — the AC1 row quotes the target's first line
  local f="$1" target="$2" l
  l="$(sed -n 1p "$SB_WORK/$target" 2>/dev/null)"
  [ -n "$l" ] || _fixture_die "_qsp_point: $target has no first line to quote"
  KIT_ROW="| AC1 | PASS | file:line | ${target}:1 \"${l}\" |" perl -i -pe 's/^\| AC1 \| PASS \| (?:test|file:line) \|.*\|$/$ENV{KIT_ROW}/' "$f"
  grep -qF -- "| AC1 | PASS | file:line | ${target}:1 " "$f" || _fixture_die "_qsp_point: the row was not planted in $f"
}

case_finish_pr_qa_verdict_self_pointer_refuses() {
  cf_reset
  make_sandbox

  local id="$SB_PREFIX-792" out rc
  seed_issue dev_complete "$id" landed chore "Landed by the script, row points at the card" "feature/$id-work"
  _qsp_point "$SB_WORK/progress/dev_complete/$id-landed.md" "progress/dev_complete/$id-landed.md"
  publish_sandbox
  seed_branch "$id" work CHANGE792.txt

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "a row naming the card's own file — finish-pr.sh exited 0"
  case "$out" in *"cite the content the AC is about, not the card"*) : ;; *) cf "the refusal's Next: does not say to cite the content, not the card: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)" ;; esac
  case "$out" in *"progress/dev_complete/$id-landed.md:"*) : ;; *) cf "the refusal does not name the pointer: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)" ;; esac
  grep -q 'refusal=qa-verdict-self-pointer' "$SB_TMP/rec"/*.tsv 2>/dev/null \
    || cf "no progress record carries refusal=qa-verdict-self-pointer: $(cat "$SB_TMP/rec"/*.tsv 2>/dev/null | cut -c1-200)"
  origin_has_path "CHANGE792.txt" && cf "the branch was merged before the refusal"
  origin_has_path "progress/qa_complete/$id-landed.md" && cf "the card advanced despite the refusal"

  finish "the landing script refuses a QA Verdict row whose evidence pointer is the card's own file, before the merge, naming the pointer and the Next: line (cite the content, not the card), with a countable refusal=qa-verdict-self-pointer record"
  teardown
}

# =============================================================================
# CASE — THE SAME ROW REFUSES AT THE DIRECT-TO-TRUNK MOVE AND IN THE READER, AND ONLY THAT ROW.
# (a) move-issue.sh <ID> qa_complete, the pointer at the card's pre-move path (the shape of the run
#     that found it): refused with a record and a Next: line, the card stays in dev_complete/;
# (b) read-verdict.sh on a card already in qa_complete/ whose row names its old dev_complete/ path
#     (also unresolved there) and on one naming its current path: the gate's would-REFUSE line
#     names qa-verdict-self-pointer for both;
# (c) CONTROLS: a row pointing at another card's file lands, one pointing at ordinary content lands,
#     and the refused card lands once re-pointed at the content its AC is about.
# =============================================================================
case_qa_verdict_self_pointer_refuses_at_the_move_and_the_reader() {
  cf_reset
  make_sandbox

  local ida="$SB_PREFIX-791" idc="$SB_PREFIX-793" idc2="$SB_PREFIX-794" idd="$SB_PREFIX-795" ide="$SB_PREFIX-796" idf="$SB_PREFIX-797"
  local out rc id

  seed_issue dev_complete "$ida" direct chore "Direct to trunk, row points at the card" "n/a"
  _qsp_point "$SB_WORK/progress/dev_complete/$ida-direct.md" "progress/dev_complete/$ida-direct.md"
  # (b) cards already in qa_complete/: one names its old path, one its current path.
  seed_issue qa_complete "$idc" moved chore "In qa_complete/, row names the old path" "n/a"
  KIT_ROW="| AC1 | PASS | file:line | progress/dev_complete/$idc-moved.md:1 \"---\" |" perl -i -pe 's/^\| AC1 \| PASS \| test \|.*\|$/$ENV{KIT_ROW}/' "$SB_WORK/progress/qa_complete/$idc-moved.md"
  seed_issue qa_complete "$idc2" here chore "In qa_complete/, row names the current path" "n/a"
  KIT_ROW="| AC1 | PASS | file:line | progress/qa_complete/$idc2-here.md:1 \"---\" |" perl -i -pe 's/^\| AC1 \| PASS \| test \|.*\|$/$ENV{KIT_ROW}/' "$SB_WORK/progress/qa_complete/$idc2-here.md"
  grep -qF "progress/dev_complete/$idc-moved.md:1" "$SB_WORK/progress/qa_complete/$idc-moved.md" \
    && grep -qF "progress/qa_complete/$idc2-here.md:1" "$SB_WORK/progress/qa_complete/$idc2-here.md" \
    || _fixture_die "case_qa_verdict_self_pointer_refuses_at_the_move_and_the_reader: the (b) rows were not planted"
  # (c) controls: another card's file, ordinary content (the seed's default).
  seed_issue dev_complete "$idd" other chore "The card another card's row points at" "n/a"
  seed_issue dev_complete "$ide" cites chore "Row points at another card's file" "n/a"
  _qsp_point "$SB_WORK/progress/dev_complete/$ide-cites.md" "progress/dev_complete/$idd-other.md"
  seed_issue dev_complete "$idf" plain chore "Row points at ordinary content" "n/a"
  publish_sandbox

  # (a) the direct-to-trunk mover, at the pre-move path.
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-a" ./scripts/move-issue.sh "$ida" qa_complete --role QA --note "Review PASS, direct to trunk" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) a row naming the card's own pre-move path — move-issue.sh qa_complete exited 0"
  case "$out" in *"cite the content the AC is about, not the card"*) : ;; *) cf "(a) the refusal's Next: does not say to cite the content, not the card: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)" ;; esac
  case "$out" in *"progress/dev_complete/$ida-direct.md:"*) : ;; *) cf "(a) the refusal does not name the pointer: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)" ;; esac
  grep -q 'refusal=qa-verdict-self-pointer' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
    || cf "(a) no progress record carries refusal=qa-verdict-self-pointer: $(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null | cut -c1-200)"
  origin_has_path "progress/qa_complete/$ida-direct.md" && cf "(a) the card reached qa_complete/ despite the refusal"
  origin_has_path "progress/dev_complete/$ida-direct.md" || cf "(a) the card left dev_complete/ during the refusal"

  # (b) read-verdict.sh names the rule for both spellings.
  for id in "$idc" "$idc2"; do
    out="$( cd "$SB_WORK" && ./scripts/read-verdict.sh "$id" 2>&1 )"; rc=$?
    [ "$rc" -eq 0 ] || cf "(b) $id: read-verdict.sh exited $rc, want 0"
    case "$out" in *"would REFUSE this table (qa-verdict-self-pointer)"*) : ;; *) cf "(b) $id: the would-REFUSE line does not name qa-verdict-self-pointer: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)" ;; esac
  done

  # (c) controls.
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-c1" ./scripts/move-issue.sh "$ide" qa_complete --role QA --note "Review PASS, direct to trunk" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(c) a row pointing at another card's file — move-issue.sh qa_complete exited $rc: $(printf '%s' "$out" | tail -4 | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/qa_complete/$ide-cites.md" || cf "(c) the card pointing at another card's file did not reach qa_complete/"
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-c2" ./scripts/move-issue.sh "$idf" qa_complete --role QA --note "Review PASS, direct to trunk" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(c) a row pointing at ordinary content — move-issue.sh qa_complete exited $rc: $(printf '%s' "$out" | tail -4 | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/qa_complete/$idf-plain.md" || cf "(c) the card pointing at ordinary content did not reach qa_complete/"

  # (c, last) the refused card, re-pointed at content and published, lands. A mover that let (a)
  # through has already moved it, which (a) reports.
  git -C "$SB_WORK" pull --ff-only --quiet >/dev/null 2>&1 || _fixture_die "case_qa_verdict_self_pointer_refuses_at_the_move_and_the_reader: the work checkout could not fast-forward to the trunk"
  if [ -f "$SB_WORK/progress/dev_complete/$ida-direct.md" ]; then
    _qsp_point "$SB_WORK/progress/dev_complete/$ida-direct.md" "ARCHIVE.md"
    git -C "$SB_WORK" add "progress/dev_complete/$ida-direct.md" >/dev/null 2>&1
    sbcommit -m "[QA] $ida: cite the content the AC is about" --quiet >/dev/null 2>&1
    git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 || cf "(c) the re-pointed row could not be published"
    out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-c3" ./scripts/move-issue.sh "$ida" qa_complete --role QA --note "Review PASS, direct to trunk" 2>&1 )"; rc=$?
    [ "$rc" -eq 0 ] || cf "(c) the card re-pointed at content — move-issue.sh qa_complete exited $rc: $(printf '%s' "$out" | tail -4 | tr '\n' '|' | cut -c1-300)"
    origin_has_path "progress/qa_complete/$ida-direct.md" || cf "(c) the re-pointed card did not reach qa_complete/"
  else
    cf "(c) the refused card is not in dev_complete/ to be re-pointed"
  fi

  finish "a QA Verdict row whose evidence pointer is the card's own file is refused at the direct-to-trunk move to qa_complete/ at the card's pre-move path (a), with the Next: line and a countable record, and read-verdict.sh's would-REFUSE line names qa-verdict-self-pointer for the old path and the current path (b); a row pointing at another card's file or at ordinary content, and the refused card once re-pointed, still lands (c)"
  teardown
}

# =============================================================================
# CASE — THE RELEASE NOTES' SELF-POINTER `Verify:` LINE JUDGES WHAT THE GATE JUDGES.
# The line is read out of the shipped notes the way `kit-upgrade.sh --finish` reads it (that script's
# own notes_items reader, extracted at run time) and run under `bash -c` in the project root.
# Rows, in the real order (cards seeded, published to the trunk, then the line run):
#   (a) a clean tree: an in-flight card whose TABLE points at ordinary content            -> exit 0;
#   (b) an in-flight card whose PROSE names its own file plus `:` (a table that does not)   -> exit 0;
#   (c) a card in qa_complete/ whose table names its own file (not in flight)               -> exit 0;
#   (d) a planted self-pointer row on an in-flight card                                     -> exit 1;
#   (e) a project with no progress/ at all                                                  -> exit 0.
# =============================================================================
case_release_notes_self_pointer_verify_judges_what_the_gate_judges() {
  cf_reset
  make_sandbox
  local notes="$REAL_REPO_ROOT/process/KIT-RELEASE-NOTES.md" hist="$REAL_REPO_ROOT/process/KIT-RELEASE-HISTORY.md" ku="$SB_WORK/scripts/kit-upgrade.sh"
  [ -f "$notes" ] && [ -f "$ku" ] \
    || { skp "the self-pointer Verify: line judges what the gate judges" "process/KIT-RELEASE-NOTES.md or scripts/kit-upgrade.sh is absent from this tree"; teardown; return; }
  local fn="$SB_TMP/notes-items.sh" rows cmd
  sed -n '/^notes_items() {/,/^}/p' "$ku" > "$fn"
  [ -s "$fn" ] || _fixture_die "case_release_notes_self_pointer_verify_judges_what_the_gate_judges: scripts/kit-upgrade.sh has no notes_items reader to extract"
  rows="$( . "$fn"; if [ -f "$hist" ]; then notes_items "$notes" "$hist"; else notes_items "$notes"; fi )"
  cmd="$(printf '%s\n' "$rows" | awk -F'\t' '$3 ~ /points at its own card/ { print $5; exit }')"
  if [ -z "$cmd" ]; then
    skp "the self-pointer Verify: line judges what the gate judges" "no Action required item about a QA Verdict row pointing at its own card carries a Verify: line in the shipped notes"
    teardown; return
  fi

  local ida="$SB_PREFIX-781" idb="$SB_PREFIX-782" idc="$SB_PREFIX-783" idd="$SB_PREFIX-784" out rc
  seed_issue dev_complete "$ida" plain chore "Table points at ordinary content" "n/a"
  seed_issue in_progress "$idb" prose chore "Prose names its own file" "n/a"
  printf '\nSee progress/in_progress/%s-prose.md:12 for the earlier note.\n' "$idb" >> "$SB_WORK/progress/in_progress/$idb-prose.md"
  seed_issue qa_complete "$idc" landed chore "Landed card, table names its own file" "n/a"
  KIT_ROW="| AC1 | PASS | file:line | progress/qa_complete/$idc-landed.md:1 \"---\" |" perl -i -pe 's/^\| AC1 \| PASS \| test \|.*\|$/$ENV{KIT_ROW}/' "$SB_WORK/progress/qa_complete/$idc-landed.md"
  grep -qF "progress/qa_complete/$idc-landed.md:1" "$SB_WORK/progress/qa_complete/$idc-landed.md" \
    || _fixture_die "case_release_notes_self_pointer_verify_judges_what_the_gate_judges: the qa_complete row was not planted"
  publish_sandbox
  _run() { ( cd "$1" && env -u KIT_PROGRESS_DIR bash -c "$cmd" </dev/null >"$SB_TMP/verify.out" 2>&1 ); }

  _run "$SB_WORK"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a,b,c) the line exited $rc on a tree with no in-flight self-pointer (a clean table, a card whose prose names its own file, a landed card): $(tr '\n' '|' < "$SB_TMP/verify.out" | cut -c1-300)"

  seed_issue dev_complete "$idd" planted chore "Table points at its own card" "n/a"
  _qsp_point "$SB_WORK/progress/dev_complete/$idd-planted.md" "progress/dev_complete/$idd-planted.md"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[QA] $idd: plant a self-pointer" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "case_release_notes_self_pointer_verify_judges_what_the_gate_judges: the planted card could not be published"
  _run "$SB_WORK"; rc=$?
  [ "$rc" -eq 1 ] || cf "(d) the line exited $rc, want 1, on an in-flight card whose QA Verdict row points at its own file: $(tr '\n' '|' < "$SB_TMP/verify.out" | cut -c1-300)"

  mkdir -p "$SB_TMP/bare-project"
  _run "$SB_TMP/bare-project"; rc=$?
  [ "$rc" -eq 0 ] || cf "(e) the line exited $rc in a project with no progress/: $(tr '\n' '|' < "$SB_TMP/verify.out" | cut -c1-300)"

  finish "the release notes' self-pointer Verify: line, run as kit-upgrade.sh --finish runs it, exits 0 on a clean tree, on an in-flight card whose prose names its own file and on a landed card, 1 on an in-flight card whose QA Verdict row points at its own file, and 0 where there is no progress/"
  teardown
}

# =============================================================================
# CASE — WHAT COUNTS AS THE CARD'S OWN FILE. The gate finds the card by its id under a progress/
# directory, not by the path of the file it was handed (read-verdict.sh hands it a scratch copy):
# every column's spelling, a leading ./, a slice's subtasks/ column and a different slug are the
# card; another card's id (including one that begins with this id's digits), a parent's slice, and a
# file outside progress/ that happens to share the card's name are not. The rows are checked through
# the gate itself, handed a copy of the card under another name.
# =============================================================================
case_qa_gate_self_pointer_spellings() {
  cf_reset
  make_sandbox

  local id="$SB_PREFIX-798" near="$SB_PREFIX-7980" other="$SB_PREFIX-799" col n=0 out rc q card="$SB_TMP/card.md"
  seed_issue dev_complete "$id" subject chore "The card under test" "n/a"
  seed_issue dev_complete "$near" nearid chore "Another id that begins with this id" "n/a"
  seed_issue dev_complete "$other" another chore "Another card" "n/a"
  mkdir -p "$SB_WORK/progress/subtasks/$id/dev_complete" "$SB_WORK/docs"
  printf '%s\n' '---' > "$SB_WORK/progress/subtasks/$id/dev_complete/$id-s1-slice.md"
  printf '%s\n' '---' > "$SB_WORK/docs/$id-subject.md"
  publish_sandbox
  cp "$SB_WORK/progress/dev_complete/$id-subject.md" "$card"

  _qsg_check() {  # <label> <pointer path> <self|notself>
    n=$((n + 1))
    q="$(git -C "$SB_WORK" show "HEAD:${2#./}" 2>/dev/null | sed -n 1p)"; [ -n "$q" ] || q='---'
    KIT_ROW="| AC1 | PASS | file:line | ${2}:1 \"${q}\" |" perl -i -pe 's/^\| AC1 \| PASS \| (?:test|file:line) \|.*\|$/$ENV{KIT_ROW}/' "$card"
    grep -qF -- "| AC1 | PASS | file:line | ${2}:1 " "$card" || _fixture_die "_qsg_check: the row for $1 was not planted"
    out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-$n" bash -c '. scripts/lib/refuse.sh; . scripts/config.sh; . scripts/lib/qa-gate.sh; kit_qa_verdict_check "$@"' _ "$card" "$id" "$SB_WORK" HEAD 2>&1 )"; rc=$?
    case "$3" in
      self)
        [ "$rc" -ne 0 ] || cf "$1: $2 is the card's own file — the gate exited 0"
        grep -q 'refusal=qa-verdict-self-pointer' "$SB_TMP/rec-$n"/*.tsv 2>/dev/null \
          || cf "$1: $2 — no record carries refusal=qa-verdict-self-pointer (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)" ;;
      *)
        [ "$rc" -eq 0 ] || cf "$1: $2 is not the card's own file — the gate exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
        grep -q 'refusal=qa-verdict-self-pointer' "$SB_TMP/rec-$n"/*.tsv 2>/dev/null \
          && cf "$1: $2 is not the card's own file — it was refused as a self-pointer" ;;
    esac
  }

  for col in todo in_progress dev_complete qa_complete blocked done declined; do
    _qsg_check "(a) $col" "progress/$col/$id-subject.md" self
  done
  _qsg_check "(b) leading ./" "./progress/dev_complete/$id-subject.md" self
  _qsg_check "(c) a slice's own column" "progress/subtasks/$id/dev_complete/$id-s1-slice.md" notself
  _qsg_check "(d) another slug" "progress/qa_complete/$id-renamed-slug.md" self
  _qsg_check "(e) another card" "progress/dev_complete/$other-another.md" notself
  _qsg_check "(f) an id that begins with this id" "progress/dev_complete/$near-nearid.md" notself
  _qsg_check "(g) outside progress/" "docs/$id-subject.md" notself
  _qsg_check "(h) ordinary content" "ARCHIVE.md" notself

  finish "the gate takes the card's own file to be any file named <card id>-*.md under a progress/ directory — every column, a leading ./, a different slug — found by id and not by the path it was handed (a scratch copy here), and takes another card, an id that merely begins with this id, a parent's slice and a same-named file outside progress/ to be content"
  teardown
}
