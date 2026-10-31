# KIT-CLASS: KIT — the design module's check-board arm: per card and pinned state, does the pinned design still match the trunk. A report; it decides nothing. See process/EXTRACTION.md.
# Sourced in a subshell by scripts/check-board.sh; process/contracts/drift-report.md § 5 is the contract.
# check-board-arm: advisory
#
# For every card past todo/ and not in done/, declined/ or history/ whose frontmatter carries `design: [UX-NNN#state@<commit>, ...]`,
# scripts/design/pin-drift.py compares the pinned artboard (found through the screen registry at the pin) and the tokens it
# uses with the trunk, and says clean | moved | drift | gone | unresolved. A drift line then says `ruling pending` when a
# question file under dev/questions/ or requirements/DECISIONS.md names both the card and the screen, else `owed`.
# A todo card is unpinned by rule, a landed card's pin is history, a declined one builds nothing: none is read.
# Status 3 when a line is not clean or moved; the arm decides nothing either way.

_dd_tool="$CB_LIB_DIR/../design/pin-drift.py"
_dd_head="${CB_REF:-HEAD}"

# _dd_ruling <card> <ux> — status 0 when a question file or the register names both.
_dd_ruling() {
  for _dd_f in "$CB_TREE"/dev/questions/* "$CB_TREE"/requirements/DECISIONS.md; do
    [ -f "$_dd_f" ] || continue
    if grep -F -- "$1" "$_dd_f" >/dev/null && grep -F -- "$2" "$_dd_f" >/dev/null; then return 0; fi
  done
  return 1
}

if ! command -v python3 >/dev/null 2>&1; then
  echo "      design pin drift: skipped: python3 not found"
  return 0
fi
if [ ! -f "$_dd_tool" ]; then
  echo "      design pin drift: skipped: scripts/design/pin-drift.py is not in this tree"
  return 0
fi
_dd_files="$(git -C "$REPO_ROOT" ls-tree -r --name-only "$_dd_head" -- requirements/design 2>/dev/null)" || _dd_files=""
case "$_dd_files" in
  *"/CANVAS.md"*) : ;;
  *)
    echo "      design pin drift: no screen registry (requirements/design/<canvas>/CANVAS.md) at $_dd_head; nothing to compare"
    return 0 ;;
esac

_dd_out="$(PYTHONDONTWRITEBYTECODE=1 python3 "$_dd_tool" --root "$REPO_ROOT" --head "$_dd_head" --cards "$CB_TREE/progress" 2>&1 </dev/null)" || {
  echo "      design pin drift: pin-drift.py failed: $(printf '%s' "$_dd_out" | tail -1)"
  return 0
}
echo "      design pin drift: compared with ${_dd_head}; cards: $(cb_src)"
_dd_found=0
while IFS= read -r _dd_line; do
  case "$_dd_line" in "pin-drift against "*) continue ;; esac
  _dd_verdict="$(printf '%s\n' "$_dd_line" | awk '$2 ~ /^UX-[0-9]+/ { print $3 }')"
  case "$_dd_verdict" in
    clean|moved) echo "      $_dd_line" ;;
    drift)
      _dd_found=1
      _dd_card="${_dd_line%% *}"
      _dd_ux="$(printf '%s' "$_dd_line" | sed -n 's/^[^ ]* *\(UX-[0-9]*\)#.*/\1/p')"
      if [ -n "$_dd_ux" ] && _dd_ruling "$_dd_card" "$_dd_ux"; then
        echo "      $_dd_line  -> drift, ruling pending"
      else
        echo "      $_dd_line  -> drift, owed (a D-NN raised with scripts/ask.sh)"
      fi ;;
    gone|unresolved) _dd_found=1; echo "      $_dd_line" ;;
    *) echo "      $_dd_line" ;;
  esac
done <<DD_EOF
$_dd_out
DD_EOF
[ "$_dd_found" -eq 0 ] || return 3
return 0
