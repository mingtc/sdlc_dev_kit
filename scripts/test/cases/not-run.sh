# KIT-CLASS: MIXED — self-test harness, "no answer is not a pass". See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/not-run.sh — sourced by scripts/test/run.sh, never run on its own.
# A check that selected nothing, could not read its input, or whose library is absent must say it did
# not run and must not let a verdict read clean, PASS or ✓ (process/contracts/drift-report.md § 4
# item 7). One case per place that used to answer for a check nobody made:
#   the landing's board-property arms, the check-board report, verify.sh --quick, the report's read
#   of the trunk through `git archive`, and the QA Verdict's shadow-check row.
# =============================================================================

# _nr_shim_awk <dir> — an awk that exits 2 for the read arm [d] makes of the cards (the call that
# carries `-v scan=`) and is the real awk for everything else.
_nr_shim_awk() {
  local real
  real="$(command -v awk)"
  mkdir -p "$1"
  printf '#!/bin/sh\ncase " $* " in *" scan="*) exit 2 ;; esac\nexec %s "$@"\n' "$real" > "$1/awk"
  chmod +x "$1/awk"
}

# _nr_have_utf8 — the UTF-8 locale the byte rows need is installed.
_nr_have_utf8() { locale -a 2>/dev/null | /usr/bin/grep -ix 'en_US.UTF-8' >/dev/null; }

# =============================================================================
# CASE — THE LANDING REFUSES A BOARD-PROPERTY ARM THAT DID NOT ANSWER.
# A branch adds a stray card whose id disagrees with its filename. (a) control: refused as the
# finding. (b) the awk the arm reads cards with fails: the landing refuses (board-property-unreadable)
# rather than printing PASS over an arm that found nothing because it read nothing. (c) one card
# holds a byte its UTF-8 locale cannot decode: the finding is still found and refused.
# =============================================================================
case_board_property_check_refuses_an_arm_that_did_not_answer() {
  cf_reset
  make_sandbox
  _bpf_seed_requirements
  publish_sandbox

  local id="$SB_PREFIX-861" oldp="$PATH"
  _bpf_begin "$id" notrun
  _bpf_card_file "$SB_WORK/progress/todo/$SB_PREFIX-862-stray.md" "$SB_PREFIX-899"
  _bpf_end "$id" notrun

  # (a) control: healthy.
  _bpf_expect_refused "(a) control — a healthy arm" "$id" notrun board-id-integrity "DISAGREES"

  # (b) the arm's awk fails.
  _nr_shim_awk "$SB_TMP/shim"
  export PATH="$SB_TMP/shim:$PATH"
  _bpf_land "$id"
  PATH="$oldp"
  [ "$_BPF_RC" -ne 0 ] || cf "(b) an arm whose awk exited 2 — finish-pr.sh exited 0: $(printf '%s' "$_BPF_OUT" | /usr/bin/grep BOARD_PROPERTY | head -2 | tr '\n' '|')"
  grep -q 'refusal=board-property-unreadable' "$SB_TMP/rec-$id"/*.tsv 2>/dev/null \
    || cf "(b) no progress record carries refusal=board-property-unreadable: $(cat "$SB_TMP/rec-$id"/*.tsv 2>/dev/null | cut -c1-200)"
  case "$_BPF_OUT" in *"Next:"*) : ;; *) cf "(b) the refusal names no Next: $(printf '%s' "$_BPF_OUT" | tr '\n' '|' | cut -c1-300)" ;; esac
  origin_has_path "BP-$id.txt" && cf "(b) the branch was merged although an arm did not answer"

  # (c) a byte its locale cannot decode, in the title of the stray card.
  if _nr_have_utf8; then
    git -C "$SB_WORK" checkout -q "feature/$id-notrun" >/dev/null 2>&1
    _bpf_card_file "$SB_WORK/progress/todo/$SB_PREFIX-862-stray.md" "$SB_PREFIX-899" "$(printf 'title: caf\351')"
    git -C "$SB_WORK" add -A >/dev/null 2>&1
    sbcommit -m "[Dev] $id: a byte in the stray card's title" --quiet >/dev/null 2>&1
    git -C "$SB_WORK" push -q origin "feature/$id-notrun" >/dev/null 2>&1
    git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1
    export LC_ALL=en_US.UTF-8
    _bpf_land "$id"
    unset LC_ALL
    [ "$_BPF_RC" -ne 0 ] || cf "(c) a stray card with an undecodable byte in a UTF-8 locale landed: $(printf '%s' "$_BPF_OUT" | /usr/bin/grep BOARD_PROPERTY | head -2 | tr '\n' '|')"
    origin_has_path "BP-$id.txt" && cf "(c) the branch was merged over an undecodable byte"
  fi

  finish "the landing refuses a board-property arm that did not answer — an awk that fails inside the arm refuses as board-property-unreadable with a Next, and a card holding a byte the locale cannot decode still has its finding found — never BOARD_PROPERTY_CHECK: PASS over an arm that read nothing"
  teardown
}

# =============================================================================
# CASE — THE REPORT NEVER READS clean OVER A CHECK THAT DID NOT RUN.
# (a) control: a card whose id disagrees is reported. (b) board-properties.sh removed, (c) the
# library stops part way (some arm functions undefined), (d) the awk the [d] arm reads with fails,
# (e) a card with an undecodable byte in a UTF-8 locale: every one still ends in findings and
# says "did not run" or shows the finding, never `board-drift: clean` and never `✓ none` for [d].
# =============================================================================
case_check_board_does_not_read_clean_over_a_check_that_did_not_run() {
  cf_reset
  local out oldp="$PATH"

  # (a)+(b)+(e): a planted finding on the trunk.
  make_sandbox
  seed_issue todo "$SB_PREFIX-871" stray chore "A card whose id disagrees" >/dev/null
  sed -i.bak "s/^id: $SB_PREFIX-871\$/id: $SB_PREFIX-879/" "$SB_WORK/progress/todo/$SB_PREFIX-871-stray.md"; rm -f "$SB_WORK/progress/todo/$SB_PREFIX-871-stray.md.bak"
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | grep -F 'DISAGREES' >/dev/null || cf "(a) control: the planted disagreeing id is not reported: $(printf '%s' "$out" | /usr/bin/grep '⚠' | head -3 | tr '\n' '|')"

  mv "$SB_WORK/scripts/lib/board-properties.sh" "$SB_TMP/bp.sh.away"
  out="$(cb_run)"
  printf '%s\n' "$out" | grep -F 'board-drift: clean' >/dev/null && cf "(b) board-properties.sh absent — the verdict reads clean over arms that did not run"
  printf '%s\n' "$out" | grep -F 'DID NOT RUN' >/dev/null || cf "(b) board-properties.sh absent — no arm says it DID NOT RUN: $(printf '%s' "$out" | /usr/bin/grep -c 'did not run')"
  mv "$SB_TMP/bp.sh.away" "$SB_WORK/scripts/lib/board-properties.sh"

  if _nr_have_utf8; then
    perl -i -pe 'BEGIN{binmode(STDIN);binmode(STDOUT)} s/^title: .*/"title: caf\xe9"/e' "$SB_WORK/progress/todo/$SB_PREFIX-871-stray.md"
    git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -m "[PM] a byte in the title" --quiet >/dev/null 2>&1
    git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
    out="$(LC_ALL=en_US.UTF-8 cb_run)"
    printf '%s\n' "$out" | grep -F 'DISAGREES' >/dev/null || cf "(e) a byte its UTF-8 locale cannot decode hid the disagreeing id: $(printf '%s' "$out" | /usr/bin/grep -A3 '^\[d\]' | tr '\n' '|' | cut -c1-300)"
  fi
  teardown

  # (c)+(d): a clean trunk with one well-formed card (arm [d] reads cards only when there is one), so
  # any `clean` is a claim over nothing.
  make_sandbox
  seed_issue todo "$SB_PREFIX-873" fine chore "A well-formed card" >/dev/null
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | grep -F 'board-drift: clean' >/dev/null || cf "(c0) control: a clean sandbox does not read clean: $(printf '%s' "$out" | /usr/bin/grep '⚠' | head -3 | tr '\n' '|')"
  local cut
  cut="$(/usr/bin/grep -n '^kit_bp_corpus()' "$SB_WORK/scripts/lib/board-properties.sh" | head -1 | cut -d: -f1)"
  [ -n "$cut" ] || _fixture_die "case_check_board_does_not_read_clean_over_a_check_that_did_not_run: kit_bp_corpus() not found in the sandbox's board-properties.sh"
  head -n "$((cut - 1))" "$SB_WORK/scripts/lib/board-properties.sh" > "$SB_TMP/bp.cut" && cat "$SB_TMP/bp.cut" > "$SB_WORK/scripts/lib/board-properties.sh"
  out="$(cb_run)"
  printf '%s\n' "$out" | grep -F 'board-drift: clean' >/dev/null && cf "(c) a library that stops part way (kit_bp_corpus and the arms after it undefined) — the verdict reads clean"
  printf '%s\n' "$out" | grep -F 'DID NOT RUN' >/dev/null || cf "(c) a half-loaded library — no arm says it DID NOT RUN"
  teardown

  make_sandbox
  seed_issue todo "$SB_PREFIX-873" fine chore "A well-formed card" >/dev/null
  publish_sandbox
  _nr_shim_awk "$SB_TMP/shim"
  export PATH="$SB_TMP/shim:$PATH"
  out="$(cb_run)"
  PATH="$oldp"
  printf '%s\n' "$out" | grep -F 'board-drift: clean' >/dev/null && cf "(d) an awk that exits 2 inside arm [d] — the verdict reads clean"
  printf '%s\n' "$out" | grep -F 'DID NOT RUN to its end' >/dev/null || cf "(d) an awk that exits 2 inside arm [d] — the arm does not say it did not run to its end: $(printf '%s' "$out" | /usr/bin/grep -A3 '^\[d\]' | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | /usr/bin/grep -A6 '^\[d\]' | /usr/bin/grep '✓ none' >/dev/null && cf "(d) arm [d] printed ✓ none although its reader failed"

  finish "check-board.sh never ends board-drift: clean over an arm that did not run: board-properties.sh absent, half loaded, or an awk failing inside arm [d] each print DID NOT RUN and a findings verdict, and a byte the locale cannot decode no longer hides a finding"
  teardown
}

# =============================================================================
# CASE — THE REPORT READS EVERY TRACKED FILE OF THE REF, export-ignore OR NOT.
# `git archive` honours a .gitattributes export-ignore, so a card the attribute hides was never
# read and the report still named the ref as read.
# =============================================================================
case_check_board_reads_a_card_that_export_ignore_hides() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-881" one chore "Minted twice" >/dev/null
  seed_issue todo "$SB_PREFIX-881" two chore "Minted twice" >/dev/null
  printf 'progress/todo export-ignore\n' > "$SB_WORK/.gitattributes"
  publish_sandbox
  if git -C "$SB_WORK" archive --format=tar "origin/$SB_TRUNK" 2>/dev/null | tar -t 2>/dev/null | /usr/bin/grep -F 'progress/todo/' >/dev/null; then
    _fixture_die "case_check_board_reads_a_card_that_export_ignore_hides: the export-ignore line did not hide progress/todo/ from git archive, so the case would prove nothing"
  fi
  local out
  out="$(cb_run)"
  printf '%s\n' "$out" | grep -F 'DUPLICATE' >/dev/null \
    || cf "a duplicate id inside an export-ignore'd directory is not reported: $(printf '%s' "$out" | /usr/bin/grep -E '^\[d\]|board-drift' | head -4 | tr '\n' '|' | cut -c1-300)"
  finish "check-board.sh reads the ref with every tracked file, so a .gitattributes export-ignore on a board column no longer hides a duplicate id behind a clean verdict"
  teardown
}

# =============================================================================
# CASE — verify.sh --quick OVER A TABLE WHOSE EVERY GATE IS CLASS full REFUSES.
# (a) --quick exits 2 naming the class column; (b) the full run and a table with a core gate are
# unchanged; (c) finish-pr.sh, unstubbed, refuses the landing and merges nothing.
# =============================================================================
case_verify_quick_with_no_gate_selected_refuses() {
  cf_reset
  make_sandbox
  local V="$SB_WORK/scripts/verify.sh" out rc id="$SB_PREFIX-891"
  awk '{print} /^GATES=\($/{print "  \"only|full|true\""}' "$V" > "$SB_TMP/v.sh" && cat "$SB_TMP/v.sh" > "$V"
  out="$( cd "$SB_WORK" && ./scripts/verify.sh --quick 2>&1 )"; rc=$?
  [ "$rc" -eq 2 ] || cf "(a) --quick over a table whose only gate is class full exited $rc, not 2: $(printf '%s' "$out" | tail -3 | tr '\n' '|')"
  case "$out" in *"Next:"*"core"*) : ;; *) cf "(a) the refusal does not name the class column in a Next: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  ( cd "$SB_WORK" && ./scripts/verify.sh >/dev/null 2>&1 ) || cf "(b) the FULL run of a one-gate full table no longer passes"
  sed -i.bak 's/"only|full|true"/"only|core|true"/' "$V"; rm -f "$V.bak"
  ( cd "$SB_WORK" && ./scripts/verify.sh --quick >/dev/null 2>&1 ) || cf "(b) --quick over a core gate no longer passes"
  sed -i.bak 's/"only|core|true"/"only|full|true"/' "$V"; rm -f "$V.bak"

  seed_issue dev_complete "$id" quick chore "Quick selects nothing" "feature/$id-quick"
  publish_sandbox
  seed_branch "$id" quick CHANGE891.txt
  out="$( cd "$SB_WORK" && env FINISH_PR_TEST_ALLOW_STUB=1 FINISH_PR_VERIFY_CMD=true KIT_PROGRESS_DIR="$SB_TMP/rec-q" ./scripts/finish-pr.sh "$id" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(c) finish-pr.sh landed with a pre-merge --quick that ran no gate: $(printf '%s' "$out" | /usr/bin/grep -E 'pre-merge|GATE' | head -3 | tr '\n' '|')"
  origin_has_path "CHANGE891.txt" && cf "(c) the branch was merged although the pre-merge gate ran nothing"
  finish "verify.sh --quick refuses (exit 2, a Next naming the class column) when every declared gate is class full, the full run and a core gate are unchanged, and finish-pr.sh does not land on a pre-merge gate that ran nothing"
  teardown
}

# =============================================================================
# CASE — A FAIL TOKEN ON THE shadow-check ROW IS A FAIL ROW.
# =============================================================================
case_qa_verdict_shadow_check_fail_token_refuses() {
  cf_reset
  make_sandbox
  local id="$SB_PREFIX-857"
  seed_issue dev_complete "$id" shadowfail chore "Shadow-check marked FAIL" "feature/$id-work"
  local f="$SB_WORK/progress/dev_complete/$id-shadowfail.md"
  perl -i -pe 's/^\| shadow-check \| — \|/| shadow-check | FAIL_REGRESSION |/' "$f"
  /usr/bin/grep -F '| shadow-check | FAIL_REGRESSION |' "$f" >/dev/null \
    || _fixture_die "case_qa_verdict_shadow_check_fail_token_refuses: the FAIL_REGRESSION token was not planted on the shadow-check row"
  publish_sandbox
  seed_branch "$id" work CHANGE857.txt
  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "a shadow-check row marked FAIL_REGRESSION landed (rc=0)"
  grep -q 'refusal=qa-verdict-fail' "$SB_TMP/rec"/*.tsv 2>/dev/null \
    || cf "no progress record carries refusal=qa-verdict-fail: $(cat "$SB_TMP/rec"/*.tsv 2>/dev/null | cut -c1-200)"
  origin_has_path "CHANGE857.txt" && cf "the branch was merged before the refusal"
  finish "finish-pr.sh reads a FAIL_AC or FAIL_REGRESSION token on the shadow-check row as a FAIL row (refusal=qa-verdict-fail), where it used to continue past the row before the verdict was read"
  teardown
}
