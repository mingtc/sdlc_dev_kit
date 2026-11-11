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
_nr_have_utf8() { [ -n "$(_nr_utf8_locale)" ]; }

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
  [ "$_BPF_RC" -ne 0 ] || cf "(b) an arm whose awk exited 2 — finish-pr.sh exited 0: $(printf '%s' "$_BPF_OUT" | grep BOARD_PROPERTY | head -2 | tr '\n' '|')"
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
    export LC_ALL="$(_nr_utf8_locale)"
    _bpf_land "$id"
    unset LC_ALL
    [ "$_BPF_RC" -ne 0 ] || cf "(c) a stray card with an undecodable byte in a UTF-8 locale landed: $(printf '%s' "$_BPF_OUT" | grep BOARD_PROPERTY | head -2 | tr '\n' '|')"
    origin_has_path "BP-$id.txt" && cf "(c) the branch was merged over an undecodable byte"
    # refused AS THE FINDING (the arm read the card byte-wise), not merely as an arm that could not read it
    case "$_BPF_OUT" in *DISAGREES*) : ;; *) cf "(c) the refusal does not carry the stray card's finding (DISAGREES): $(printf '%s' "$_BPF_OUT" | tr '\n' '|' | cut -c1-300)" ;; esac
  else
    echo "  NOT RUN: no UTF-8 locale installed (locale -a lists none) — row (c), the undecodable byte, did not execute"
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
  printf '%s\n' "$out" | grep -F 'DISAGREES' >/dev/null || cf "(a) control: the planted disagreeing id is not reported: $(printf '%s' "$out" | grep '⚠' | head -3 | tr '\n' '|')"

  mv "$SB_WORK/scripts/lib/board-properties.sh" "$SB_TMP/bp.sh.away"
  out="$(cb_run)"
  printf '%s\n' "$out" | grep -F 'board-drift: clean' >/dev/null && cf "(b) board-properties.sh absent — the verdict reads clean over arms that did not run"
  printf '%s\n' "$out" | grep -F 'DID NOT RUN' >/dev/null || cf "(b) board-properties.sh absent — no arm says it DID NOT RUN: $(printf '%s' "$out" | grep -c 'did not run')"
  mv "$SB_TMP/bp.sh.away" "$SB_WORK/scripts/lib/board-properties.sh"

  if _nr_have_utf8; then
    perl -i -pe 'BEGIN{binmode(STDIN);binmode(STDOUT)} s/^title: .*/"title: caf\xe9"/e' "$SB_WORK/progress/todo/$SB_PREFIX-871-stray.md"
    git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -m "[PM] a byte in the title" --quiet >/dev/null 2>&1
    git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
    out="$(LC_ALL="$(_nr_utf8_locale)" cb_run)"
    printf '%s\n' "$out" | grep -F 'DISAGREES' >/dev/null || cf "(e) a byte its UTF-8 locale cannot decode hid the disagreeing id: $(printf '%s' "$out" | grep -A3 '^\[d\]' | tr '\n' '|' | cut -c1-300)"
  else
    echo "  NOT RUN: no UTF-8 locale installed (locale -a lists none) — row (e), the undecodable byte, did not execute"
  fi
  teardown

  # (c)+(d): a clean trunk with one well-formed card (arm [d] reads cards only when there is one), so
  # any `clean` is a claim over nothing.
  make_sandbox
  seed_issue todo "$SB_PREFIX-873" fine chore "A well-formed card" >/dev/null
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | grep -F 'board-drift: clean' >/dev/null || cf "(c0) control: a clean sandbox does not read clean: $(printf '%s' "$out" | grep '⚠' | head -3 | tr '\n' '|')"
  local cut
  cut="$(grep -n '^kit_bp_corpus()' "$SB_WORK/scripts/lib/board-properties.sh" | head -1 | cut -d: -f1)"
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
  printf '%s\n' "$out" | grep -F 'DID NOT RUN to its end' >/dev/null || cf "(d) an awk that exits 2 inside arm [d] — the arm does not say it did not run to its end: $(printf '%s' "$out" | grep -A3 '^\[d\]' | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -A6 '^\[d\]' | grep '✓ none' >/dev/null && cf "(d) arm [d] printed ✓ none although its reader failed"

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
  if git -C "$SB_WORK" archive --format=tar "origin/$SB_TRUNK" 2>/dev/null | tar -t 2>/dev/null | grep -F 'progress/todo/' >/dev/null; then
    _fixture_die "case_check_board_reads_a_card_that_export_ignore_hides: the export-ignore line did not hide progress/todo/ from git archive, so the case would prove nothing"
  fi
  local out
  out="$(cb_run)"
  printf '%s\n' "$out" | grep -F 'DUPLICATE' >/dev/null \
    || cf "a duplicate id inside an export-ignore'd directory is not reported: $(printf '%s' "$out" | grep -E '^\[d\]|board-drift' | head -4 | tr '\n' '|' | cut -c1-300)"
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
  # the sandbox's own gate is class select: make it full too, so no declared gate is one --quick runs
  sed -i.bak 's#|select|/bin/echo sandbox-gate-green#|full|/bin/echo sandbox-gate-green#' "$V"; rm -f "$V.bak"
  grep -F 'sandbox gate|full|' "$V" >/dev/null || _fixture_die "case_verify_quick_with_no_gate_selected_refuses: the sandbox gate was not reclassed to full"
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
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-q" ./scripts/finish-pr.sh "$id" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(c) finish-pr.sh landed with a pre-merge --quick that ran no gate: $(printf '%s' "$out" | grep -E 'pre-merge|GATE' | head -3 | tr '\n' '|')"
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
  grep -F '| shadow-check | FAIL_REGRESSION |' "$f" >/dev/null \
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

# _nr_utf8_locale — prints the name of an installed UTF-8 locale (en_US first), or nothing. The byte
# rows need one; a row that has none says so rather than passing silently.
_nr_utf8_locale() {
  local l
  for l in en_US.UTF-8 en_US.utf8 C.UTF-8 C.utf8; do
    if locale -a 2>/dev/null | grep -ix "$l" >/dev/null; then printf '%s' "$l"; return 0; fi
  done
  l="$(locale -a 2>/dev/null | grep -iE '\.utf-?8$' | head -n 1)"
  printf '%s' "$l"
}

# =============================================================================
# CASE — A LIBRARY THAT STOPPED PART WAY IS NOT A CLEAN ANSWER, ONE LEVEL DOWN.
# card-field.sh cut before kit_card_list leaves the board-property arms loading and calling a
# function that is not there. The landing must refuse it (board-property-unreadable) and the
# report must say DID NOT RUN, never PASS and never `board-drift: clean`.
# =============================================================================
case_a_half_loaded_dependency_library_is_not_a_clean_answer() {
  cf_reset
  make_sandbox
  _bpf_seed_requirements
  local lib="$SB_WORK/scripts/lib/card-field.sh" cut out
  cut="$(grep -n '^kit_card_list()' "$lib" | head -n 1 | cut -d: -f1)"
  [ -n "$cut" ] || _fixture_die "case_a_half_loaded_dependency_library_is_not_a_clean_answer: kit_card_list() not found in the sandbox's card-field.sh"
  head -n "$((cut - 1))" "$lib" > "$SB_TMP/cf.cut" && cat "$SB_TMP/cf.cut" > "$lib"
  bash -n "$lib" || _fixture_die "case_a_half_loaded_dependency_library_is_not_a_clean_answer: the truncated card-field.sh does not parse"
  _bpf_card_file "$SB_WORK/progress/todo/$SB_PREFIX-903-target.md" "$SB_PREFIX-903"
  seed_issue todo "$SB_PREFIX-904" fine chore "A well-formed card" >/dev/null
  publish_sandbox

  local id="$SB_PREFIX-902"
  _bpf_begin "$id" halfload
  _bpf_card_file "$SB_WORK/progress/todo/$SB_PREFIX-905-blocker.md" "$SB_PREFIX-905" "blocks: [$SB_PREFIX-903]"
  _bpf_end "$id" halfload
  _bpf_land "$id"
  [ "$_BPF_RC" -ne 0 ] || cf "(a) a landing over a half-loaded card-field.sh exited 0: $(printf '%s' "$_BPF_OUT" | grep BOARD_PROPERTY | head -2 | tr '\n' '|')"
  origin_has_path "BP-$id.txt" && cf "(a) the branch was merged over a half-loaded library"
  case "$_BPF_OUT" in *"board-property-unreadable"*|*"could not read the board"*|*"not ready"*) : ;; *) cf "(a) the refusal does not say the check could not read: $(printf '%s' "$_BPF_OUT" | tr '\n' '|' | cut -c1-300)" ;; esac

  out="$(cb_run)"
  printf '%s\n' "$out" | grep -F 'board-drift: clean' >/dev/null && cf "(b) the report reads clean over a half-loaded card-field.sh"
  printf '%s\n' "$out" | grep -F 'DID NOT RUN' >/dev/null || cf "(b) the report does not say an arm DID NOT RUN over a half-loaded card-field.sh"
  finish "a dependency library cut at a function boundary (kit_card_list undefined) makes the landing refuse and the report say DID NOT RUN, the same answer as a half-loaded board-properties.sh"
  teardown
}

# =============================================================================
# CASE — A [+name] ARM RUNS IN THE CALLER'S LOCALE. The report reads byte-wise, but an arm in
# scripts/check-board.d is the project's own command and must see the locale it was launched in.
# =============================================================================
case_check_board_arm_keeps_the_callers_locale() {
  cf_reset
  local loc out
  loc="$(_nr_utf8_locale)"
  if [ -z "$loc" ]; then
    echo "  NOT RUN: no UTF-8 locale installed (locale -a lists none) — the caller's-locale row did not execute"
    finish "check-board.sh's [+name] arms keep the caller's locale — NOT RUN here: no UTF-8 locale is installed"
    return 0
  fi
  make_sandbox
  publish_sandbox
  mkdir -p "$SB_WORK/scripts/check-board.d"
  {
    printf '# check-board-arm: advisory\n'
    printf "if printf 'ÉTÉ' | grep -i 'été' >/dev/null; then echo '      locale-arm: caller-locale match yes'; else echo '      locale-arm: caller-locale match no'; fi\n"
  } > "$SB_WORK/scripts/check-board.d/50-locale.sh"
  out="$(LC_ALL="$loc" cb_run)"
  printf '%s\n' "$out" | grep -F 'locale-arm: caller-locale match yes' >/dev/null \
    || cf "an advisory arm launched under $loc did not see that locale (grep -i on non-ASCII text): $(printf '%s' "$out" | grep -F 'locale-arm' | head -2 | tr '\n' '|')"
  finish "check-board.sh restores the caller's locale for a check-board.d arm, so a project's own arm answers as it does outside the report"
  teardown
}

# =============================================================================
# CASE — THE REFUSAL FOR AN ARM THAT DID NOT ANSWER NAMES THE FILE, AND A TRUNK-SIDE FAILURE IS
# NOT BLAMED ON THE BRANCH. (a) the awk fails only on the landed tree and says which file it
# could not open: the refusal carries that line. (b) the awk fails only on the trunk's own tree:
# the refusal is board-property-unreadable, not the finding the trunk "newly" shows.
# =============================================================================
case_board_property_refusal_names_the_file_and_the_side() {
  cf_reset
  make_sandbox
  _bpf_seed_requirements
  publish_sandbox
  local id="$SB_PREFIX-911" oldp="$PATH" shim="$SB_TMP/shim2"
  _bpf_begin "$id" side
  _bpf_card_file "$SB_WORK/progress/todo/$SB_PREFIX-912-stray.md" "$SB_PREFIX-919"
  _bpf_end "$id" side
  mkdir -p "$shim"

  # (a) fails on the landed tree only (the tree that holds the branch's marker file).
  {
    printf '#!/bin/sh\n'
    printf 'case " $* " in *" scan="*) ;; *) exec /usr/bin/awk "$@" ;; esac\n'
    printf 'for a in "$@"; do case "$a" in root=*) r="${a#root=}" ;; esac; done\n'
    printf 'if [ -e "${r}BP-%s.txt" ]; then echo "awk: cannot open file ${r}progress/todo/shimmed-file.md" >&2; exit 2; fi\n' "$id"
    printf 'exec /usr/bin/awk "$@"\n'
  } > "$shim/awk"; chmod +x "$shim/awk"
  export PATH="$shim:$PATH"
  _bpf_land "$id"
  PATH="$oldp"
  [ "$_BPF_RC" -ne 0 ] || cf "(a) an awk failing on the landed tree — finish-pr.sh exited 0"
  case "$_BPF_OUT" in *"shimmed-file.md"*) : ;; *) cf "(a) the refusal does not carry the failing reader's own line naming the file: $(printf "%s" "$_BPF_OUT" | grep -A7 "^Error:" | tr "\n" "|" | cut -c1-900)" ;; esac

  # (b) fails on the trunk's own tree only (the tree without the branch's marker file).
  {
    printf '#!/bin/sh\n'
    printf 'case " $* " in *" scan="*) ;; *) exec /usr/bin/awk "$@" ;; esac\n'
    printf 'for a in "$@"; do case "$a" in root=*) r="${a#root=}" ;; esac; done\n'
    printf 'if [ ! -e "${r}BP-%s.txt" ]; then exit 2; fi\n' "$id"
    printf 'exec /usr/bin/awk "$@"\n'
  } > "$shim/awk"; chmod +x "$shim/awk"
  export PATH="$shim:$PATH"
  _bpf_land "$id"
  PATH="$oldp"
  [ "$_BPF_RC" -ne 0 ] || cf "(b) a trunk-side failing reader — finish-pr.sh exited 0"
  # read from THIS landing's output (the progress records of (a) are in the same directory)
  case "$_BPF_OUT" in *"the TRUNK's own tree"*) : ;; *) cf "(b) a reader that failed on the trunk's tree was not refused as a trunk-side board-property-unreadable: $(printf '%s' "$_BPF_OUT" | grep -A3 '^Error:' | tr '\n' '|' | cut -c1-500)" ;; esac
  case "$_BPF_OUT" in *DISAGREES*) cf "(b) the trunk-side failure was blamed on the branch as its finding (DISAGREES)" ;; esac
  finish "the unreadable-arm refusal carries the reader's own error line naming the file, and an arm that died on the trunk's tree refuses as board-property-unreadable instead of putting the trunk's findings on the branch"
  teardown
}

# =============================================================================
# CASE — A LANDED verify.sh THAT RUNS NO GATE UNDER --quick IS READ AS COULD NOT RUN, NOT FAIL.
# The pre-merge gate runs the trunk's copy; post-merge runs the landed one. A branch that classes
# every gate `full` makes the second exit 2, which measured nothing.
# =============================================================================
case_post_merge_verify_exit_two_reads_unrunnable() {
  cf_reset
  make_sandbox
  local id="$SB_PREFIX-921" V="$SB_WORK/scripts/verify.sh" out rc
  seed_issue dev_complete "$id" reclass chore "Reclasses every gate full" "feature/$id-reclass"
  publish_sandbox
  seed_branch "$id" reclass CHANGE921.txt
  git -C "$SB_WORK" checkout -q "feature/$id-reclass" >/dev/null 2>&1
  sed -i.bak 's#|select|/bin/echo sandbox-gate-green#|full|/bin/echo sandbox-gate-green#' "$V"; rm -f "$V.bak"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[Dev] $id: class every gate full" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q -u origin "feature/$id-reclass" >/dev/null 2>&1
  # the gate checkout is the branch's own, as the landing gate requires when a branch changes verify.sh
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-pm" ./scripts/finish-pr.sh "$id" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "the landing did not complete (rc=$rc), so the post-merge reading below was not taken: $(printf '%s' "$out" | tail -4 | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -x 'POST_MERGE_GATE: UNRUNNABLE' >/dev/null \
    || cf "a post-merge verify.sh --quick that exited 2 is not POST_MERGE_GATE: UNRUNNABLE: $(printf '%s\n' "$out" | grep -E 'POST_MERGE_GATE|post-merge verify' | tr '\n' '|')"
  finish "finish-pr.sh reads a post-merge verify.sh exit of 2 as UNRUNNABLE (nothing was measured), not as a FAIL asserting the trunk is red"
  teardown
}

# =============================================================================
# CASE — THE OTHER BYTE-SENSITIVE READERS READ BYTE-WISE: the agent-record verdict section and the
# lived-tree probe's progress.md and ARCHIVE.md readers. A \xe9 row under a UTF-8 locale stopped
# their awk and cut what they returned short.
# =============================================================================
case_verdict_section_and_lived_probe_read_a_byte_wise() {
  cf_reset
  local loc r out
  loc="$(_nr_utf8_locale)"
  if [ -z "$loc" ]; then
    echo "  NOT RUN: no UTF-8 locale installed (locale -a lists none) — the byte-wise reader row did not execute"
    finish "the verdict-section and lived-probe readers read byte-wise — NOT RUN here: no UTF-8 locale is installed"
    return 0
  fi
  make_sandbox
  r="$SB_TMP/arrepo"
  git init -q "$r" >/dev/null 2>&1
  mkdir -p "$r/progress/todo"
  { printf -- '---\nid: KIT-931\n---\n\n## QA Verdict\n\n| AC1 | PASS | caf\351 |\n| AC2 | PASS | TAILMARK |\n\n## Activity\n'; } > "$r/progress/todo/KIT-931-x.md"
  git -C "$r" add -A >/dev/null 2>&1
  git -C "$r" -c user.email=t@t -c user.name=t commit -q -m seed >/dev/null 2>&1
  out="$(LC_ALL="$loc" bash -c ". '$SB_WORK/scripts/lib/agent-record.sh' && _kit_agent_verdict_section '$r' HEAD KIT-931 progress" 2>/dev/null)"
  printf '%s\n' "$out" | grep -F 'TAILMARK' >/dev/null \
    || cf "the verdict section stops at a row holding a byte the locale cannot decode (the rows after it are lost): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  mkdir -p "$SB_TMP/lived"
  { printf '# progress\n\n## Log\n\nfirst caf\351 line\nsecond line\n'; } > "$SB_TMP/lived/progress.md"
  out="$(LC_ALL="$loc" bash -c ". '$SB_WORK/scripts/lib/lived-probe.sh' && kit_lived_signals '$SB_TMP/lived' 'NO_SUCH_MARK=' todo" 2>/dev/null)"
  printf '%s\n' "$out" | grep -x 'log|2' >/dev/null \
    || cf "the lived probe's § Log count stops at a line holding an undecodable byte (want log|2): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  finish "the verdict-section and lived-probe readers read byte-wise, so a byte the locale cannot decode no longer cuts a verdict section or a § Log count short"
  teardown
}

# =============================================================================
# CASE — A mktemp THAT FAILS IS A DID NOT RUN, NOT A CLEAN ARM. The arm's reader failures are
# recorded in a temp file; without one nothing could be said about them.
# =============================================================================
case_check_board_says_did_not_run_when_mktemp_fails() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-941" fine chore "A well-formed card" >/dev/null
  publish_sandbox
  local oldp="$PATH" shim="$SB_TMP/shim3" out
  mkdir -p "$shim"
  printf '#!/bin/sh\nexit 1\n' > "$shim/mktemp"; chmod +x "$shim/mktemp"
  export PATH="$shim:$PATH"
  out="$(cb_run)"
  PATH="$oldp"
  printf '%s\n' "$out" | grep -F 'board-drift: clean' >/dev/null && cf "mktemp failing — the verdict reads clean over arms whose readers could not be watched"
  printf '%s\n' "$out" | grep -F 'DID NOT RUN' >/dev/null || cf "mktemp failing — no arm says it DID NOT RUN: $(printf '%s' "$out" | grep -E '^\[d\]|board-drift' | head -3 | tr '\n' '|')"
  finish "check-board.sh says DID NOT RUN, and the verdict is not clean, when it cannot make the temp file its readers' failures are recorded in"
  teardown
}

# =============================================================================
# CASE — THE REPORT'S OTHER ARMS DO NOT READ clean OVER A READER THAT FAILED.
# The board-property arms were made status-checked first; the arms that read a card, progress.md,
# PROJECT.md or the downtime queue with their own awk were not. One awk shim per arm exits 2 for that
# arm's own call only (the shim is told a fragment of the awk program, so nothing else fails). Each row
# must show the arm's DID NOT RUN line, none of the clean-reading text it printed before, and a verdict
# that is not clean; the control, the same board with the real awk, shows that text.
# =============================================================================
# _nr_arm_section <letter> — one arm's lines out of a report on stdin.
_nr_arm_section() {
  awk -v t="[$1]" 'index($0, t) == 1 { f = 1; print; next } f && /^(\[|──)/ { exit } f'
}
# _nr_shim_awk_for <dir> <fragment> — an awk that exits 2 when its arguments hold <fragment>.
_nr_shim_awk_for() {
  local real
  real="$(command -v awk)"
  mkdir -p "$1"
  printf '#!/bin/sh\ncase "$*" in *'"'"'%s'"'"'*) exit 2 ;; esac\nexec %s "$@"\n' "$2" "$real" > "$1/awk"
  chmod +x "$1/awk"
}
case_check_board_other_arms_say_did_not_run_when_their_reader_failed() {
  cf_reset
  make_sandbox
  local id="$SB_PREFIX-951"
  seed_issue todo "$id" fine chore "A well-formed card" >/dev/null
  seed_issue done "$SB_PREFIX-952" landed chore "A landed card" >/dev/null
  mkdir -p "$SB_WORK/dev/questions"
  { _ask_pm_section 'Nadia, shop manager' 'dev/questions/'; printf -- '- `kit-feedback: auto` — the kit default\n'; } > "$SB_WORK/PROJECT.md"
  printf '# progress.md\n\n## Log\n\n### 2026-01-02 [Dev] a session\n\n- did the work.\n- `kit-feedback: none`\n' > "$SB_WORK/progress.md"
  printf '| Item | Origin | Size | Why deferred | Wake condition | Status |\n|---|---|---|---|---|---|\n| **Live** | audit | S | — | now | open (claimed by %s) |\n' "$id" > "$SB_WORK/dev/downtime-queue.md"
  printf '# a question\n\n**Parks card:** %s\n\n**Answer (2026-01-02, Nadia):** Yes.\n' "$id" > "$SB_WORK/dev/questions/2026-01-01-q-ask.md"
  publish_sandbox

  local out sec oldp="$PATH" row letter frag clean ctl why
  out="$(cb_run)"
  printf '%s\n' "$out" | grep -F 'board-drift: clean' >/dev/null || cf "(control) the fixture board does not read clean: $(printf '%s' "$out" | grep '⚠' | head -4 | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -F 'DID NOT RUN' >/dev/null && cf "(control) an arm says DID NOT RUN on a healthy board: $(printf '%s' "$out" | grep -F 'DID NOT RUN' | head -3 | tr '\n' '|' | cut -c1-300)"

  # <row>|<arm letter>|<a fragment of the arm's awk program>|<text a dead arm must not print>|<1 if the control prints it>
  while IFS='|' read -r row letter frag clean ctl; do
    [ -n "$row" ] || continue
    sec="$(printf '%s\n' "$out" | _nr_arm_section "$letter")"
    if [ "$ctl" = 1 ]; then
      printf '%s\n' "$sec" | grep -F -- "$clean" >/dev/null || cf "($row, control) arm [$letter] does not print '$clean': $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-300)"
    fi
    _nr_shim_awk_for "$SB_TMP/shim-$row" "$frag"
    PATH="$SB_TMP/shim-$row:$oldp"
    why="$(cb_run)"
    PATH="$oldp"
    sec="$(printf '%s\n' "$why" | _nr_arm_section "$letter")"
    printf '%s\n' "$why" | grep -F 'board-drift: clean' >/dev/null && cf "($row) a reader of arm [$letter] exited 2 — the verdict reads clean"
    printf '%s\n' "$sec" | grep -F 'DID NOT RUN' >/dev/null || cf "($row) arm [$letter] does not say DID NOT RUN although its reader exited 2: $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-300)"
    printf '%s\n' "$sec" | grep -F -- "$clean" >/dev/null && cf "($row) arm [$letter] printed '$clean' although its reader exited 2"
  done <<'NR_ROWS'
a|a|Activity|✓ none across|1
c|c|if (inlog) exit|Log SLICE: 0 /|0
j|j|Wake condition|no open row claims a landed issue ✓|1
m|m|index($0, k ":")|landed issue(s) carry prd|1
nproject|n|kit-feedback:[[:space:]]|newest entry|1
nlog|n|have = 1|newest entry|1
tchannel|t|marker|does not cite it since the answer|1
tcard|t|Parks card|no card named|0
u|u|index($0, "title:") == 1|✓ none:|1
NR_ROWS

  finish "check-board.sh arms [a] [c] [j] [m] [n] [t] [u] each say DID NOT RUN, print none of their clean-reading text and leave the verdict not clean when their own reader exits non-zero, while the control reads clean with the real awk"
  teardown
}
