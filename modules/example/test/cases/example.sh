# KIT-CLASS: KIT — the example module's own self-test case: the template for a module's cases. See process/EXTRACTION.md.
# =============================================================================
# modules/example/test/cases/example.sh — sourced by scripts/test/run.sh with the harness's own files, and
# listed in modules/example/test/CASE-LIST. It enables the module in a sandbox with the harness's shared
# helpers (scripts/test/lib/modules.sh), proves the project's own scripts READ what the module placed, disables
# it, and proves they stop. Helpers of its own carry the module's prefix, not another file's.
# =============================================================================

_ex_hook() {  # <role> — the commit-msg hook's verdict on a subject tagged with it
  local msg="$SB_TMP/ex-msg.txt"
  printf '[%s] %s: example\n' "$1" "$_MD_ID" > "$msg"
  "$SB_WORK/scripts/githooks/commit-msg" "$msg" >/dev/null 2>&1
}
_ex_kinds() { ( cd "$SB_WORK" && bash -c '. scripts/lib/refuse.sh; . scripts/lib/qa-gate.sh; kit_qa_evidence_kinds "$1" HEAD' _ "$SB_WORK" ); }
_ex_report() { ( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR "$SB_WORK/scripts/check-board.sh" 2>&1 ); }
_ex_land() {  # <message> — commit what the sandbox holds and publish it: the readers below read the trunk
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "[PM] $_MD_ID: $1" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
}
_ex_move() {  # <id> <role> — the board mover, status in _ex_rc and output in _ex_out
  _ex_rc=0
  _ex_out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/records" ./scripts/move-issue.sh "$1" in_progress --role "$2" --note x 2>&1 </dev/null )" || _ex_rc=$?
}
_ex_mint() {  # prd|issue -> the minted file's text on stdout; the file is removed
  local f
  case "$1" in
    prd)   ( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/records" ./scripts/new-prd.sh probe >/dev/null 2>&1 ); f="$(probe_pick "$SB_WORK/requirements" -name 'PRD-*-probe.md')" ;;
    issue) ( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/records" ./scripts/new-issue.sh probe --id "$SB_PREFIX-799" >/dev/null 2>&1 ); f="$SB_WORK/progress/todo/$SB_PREFIX-799-probe.md" ;;
  esac
  [ -f "$f" ] && { cat "$f"; rm -f "$f"; }
  return 0
}

# =============================================================================
# CASE — THE PROJECT'S OWN SCRIPTS READ WHAT THE EXAMPLE MODULE REGISTERS WITH WHILE IT IS ENABLED, AND NOTHING AFTER.
#   The role is accepted by the commit-msg hook and the board mover, the arm is in check-board's report, the
#   kind is in the QA gate's list, the cell check passes and refuses, the fragments are minted into a new PRD
#   and card, and the move check refuses a card with no sign-off line, naming the next step. Each is asserted
#   absent before enable (so the proof is the module's) and again after disable (the role layer excepted: it
#   stays while a commit carries the role).
# =============================================================================
case_the_example_module_is_read_by_what_it_registers_with_while_enabled_and_by_nothing_after() {
  cf_reset
  local L="while the example module is enabled the commit-msg hook and the board mover accept its role, check-board runs its arm, the QA gate lists its evidence kind and runs its cell check, a new PRD and card carry its fragments and the board mover refuses a card without the sign-off line with a Next: line; before enable and once the module is disabled and its kept role layer deleted none of that is so"
  if [ ! -f "$REAL_REPO_ROOT/modules/example/module.manifest" ]; then skp_lived "$L" "modules/example/RELEASE-NOTES.md is absent from this tree"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  if [ ! -f "$REAL_REPO_ROOT/.claude/templates/PRD.template.md" ]; then skp "$L" ".claude/templates/PRD.template.md absent (copy-list incomplete)"; return; fi
  _md_sandbox
  mkdir -p "$SB_WORK/requirements" "$SB_WORK/dev"
  local id="$_MD_ID" b="$SB_PREFIX-731" out card prd issue
  seed_issue todo "$b" example chore "A card the control moves before the module is enabled"
  _ex_land "seed a second card"
  [ -f "$SB_WORK/scripts/module.sh" ] || cf "(prereq) scripts/module.sh is absent from the tree under test"

  # (control) before enable none of it is so.
  _ex_hook Example && cf "(control) the hook accepted [Example] before the module was enabled"
  case " $(_ex_kinds) " in *" example-note "*) cf "(control) the QA gate already lists example-note" ;; esac
  _ex_report | grep -F '[+example]' >/dev/null && cf "(control) check-board shows the example arm before enable"
  _ex_mint prd | grep -F 'Example field' >/dev/null && cf "(control) a new PRD carries the example field before enable"
  _ex_mint issue | grep -F 'example-sign-off' >/dev/null && cf "(control) a new card carries the sign-off line before enable"
  _ex_move "$b" "$SB_ROLE"
  [ "$_ex_rc" -eq 0 ] || cf "(control) the board mover refused a plain move before enable (exit $_ex_rc): $(printf '%s' "$_ex_out" | tr '\n' '|' | cut -c1-200)"

  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || { cf "enable exited $_md_rc: $_md_out"; finish "$L"; teardown; return; }
  _ex_land "enable the example module"

  # (a) the role: the hook and the mover accept it, and a base role still works.
  _ex_hook Example || cf "(a) the hook refused [Example] after enable"
  _ex_hook "$SB_ROLE" || cf "(a) the hook refused a base role after enable — a module must only ADD"

  # (b) the move check: a card without the sign-off line is refused, naming the next step; with it, the mover
  #     accepts the module's role and the commit carries the tag the hook had to accept.
  _ex_move "$id" Example
  { [ "$_ex_rc" -eq 1 ] && printf '%s\n' "$_ex_out" | grep -F "has no 'example-sign-off:' line" >/dev/null && printf '%s\n' "$_ex_out" | grep '^Next:' >/dev/null; } \
    || cf "(b) a card with no sign-off line was not refused by the module's move check with a Next: line (exit $_ex_rc): $(printf '%s' "$_ex_out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$_ex_out" | grep -F -- '--role must be' >/dev/null && cf "(b) the mover refused the module's role itself"
  card="$SB_WORK/progress/todo/$id-modules.md"
  printf '\nexample-sign-off: pending\n' >> "$card"
  _ex_land "give the card its sign-off line"
  _ex_move "$id" Example
  [ "$_ex_rc" -eq 0 ] || cf "(b) the mover refused a card with its sign-off line and the module's role (exit $_ex_rc): $(printf '%s' "$_ex_out" | tr '\n' '|' | cut -c1-240)"
  origin_log_has_subject "\[Example\] $id" || cf "(b) the move's commit does not carry the [Example] tag the hook had to accept"

  # (c) check-board runs the arm, and does not report the [Example] commit as an unprefixed one.
  out="$( _ex_report )"
  printf '%s\n' "$out" | grep -F '[+example]' >/dev/null || cf "(c) check-board has no [+example] header"
  printf '%s\n' "$out" | grep -F 'example module: enabled, nothing to report' >/dev/null || cf "(c) the arm's line is not in the report"
  printf '%s\n' "$out" | grep -F '[Example]' | grep -F '⚠' >/dev/null && cf "(c) check-board reported the [Example] commit as an unprefixed one"

  # (d) the QA gate lists the kind, and the placed cell check passes a note under dev/ and refuses another place.
  case " $(_ex_kinds) " in *" example-note "*) : ;; *) cf "(d) the QA gate does not list example-note: $(_ex_kinds)" ;; esac
  case " $(_ex_kinds) " in *" test "*) : ;; *) cf "(d) the built-in kinds went missing: $(_ex_kinds)" ;; esac
  printf 'a note\n' > "$SB_WORK/dev/note.md"; _ex_land "a note"
  local chk="$SB_WORK/scripts/qa-cell.d/example-note/50-example.sh" head
  head="$(git -C "$SB_WORK" rev-parse HEAD)"
  ( bash "$chk" "$id" AC1 dev/note.md:1 "$SB_WORK" "$head" "$head" >/dev/null 2>&1 ) || cf "(d) the cell check refused a note under dev/ that the landed revision holds"
  out="$( bash "$chk" "$id" AC1 src/note.md:1 "$SB_WORK" "$head" "$head" 2>&1 )" && cf "(d) the cell check passed a pointer outside dev/"
  printf '%s\n' "$out" | grep '^Next:' >/dev/null || cf "(d) the cell check refused without a Next: line"

  # (e) the fragments are minted into a new PRD and a new card.
  prd="$( _ex_mint prd )"; issue="$( _ex_mint issue )"
  [ "$(printf '%s\n' "$prd" | grep -cF '**Example field:** none')" -ge 1 ] || cf "(e) a new PRD does not carry the example field"
  printf '%s\n' "$prd" | grep -F 'KIT-MODULES' >/dev/null && cf "(e) a slot line survived into the minted PRD"
  printf '%s\n' "$issue" | grep -x 'example-sign-off: pending' >/dev/null || cf "(e) a new card does not carry the sign-off line"

  # (f) disable: the role is refused again, and the arm, the kind, the fragments and the check are gone.
  _md_mod disable example
  [ "$_md_rc" -eq 0 ] || cf "(f) disable exited $_md_rc: $_md_out"
  # The move above committed under [Example], so the role layer stays while that history exists (disable says
  # so); the role is withdrawn when the project deletes the layer on purpose.
  [ -f "$SB_WORK/process/roles.d/example" ] || cf "(f) the role layer was removed though a commit carries [Example]"
  printf '%s\n' "$_md_out" | grep -F 'process/ROLES' >/dev/null || cf "(f) disable does not say how to retire the role: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-200)"
  rm -f "$SB_WORK/process/roles.d/example"
  _ex_hook Example && cf "(f) the hook still accepts [Example] once the layer is deleted"
  _ex_land "disable the example module"
  case " $(_ex_kinds) " in *" example-note "*) cf "(f) the QA gate still lists example-note after disable" ;; esac
  _ex_report | grep -F '[+example]' >/dev/null && cf "(f) check-board still runs the arm after disable"
  _ex_mint prd | grep -F 'Example field' >/dev/null && cf "(f) a new PRD still carries the example field after disable"
  _ex_mint issue | grep -F 'example-sign-off' >/dev/null && cf "(f) a new card still carries the sign-off line after disable"
  [ -e "$SB_WORK/scripts/move-check.d/in_progress/50-example.sh" ] && cf "(f) the move check file remains"

  finish "$L"
  teardown
}
