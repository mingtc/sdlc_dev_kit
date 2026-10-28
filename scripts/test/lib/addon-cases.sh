# KIT-CLASS: MIXED — self-test harness, an add-on's cases. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/lib/addon-cases.sh — sourced by scripts/test/run.sh, never run on its own.
# An add-on ships its cases beside its files: modules/<name>/test/cases/*.sh define them (run.sh loads
# those files with its own, so they are part of the harness it censuses) and modules/<name>/test/CASE-LIST
# lists them, one function name per line, `#` starting a comment. The list is what keeps the harness's
# rule that a case nobody listed never runs: a case an add-on defines and does not list, lists and
# does not define, or names as another case does, refuses the whole run. A case is a function
# written `case_<name>() {` at the start of a line, as the core's are. A tree with no such directory
# runs the core cases only.
# =============================================================================

# _harness_add_addon_cases <root> — check every add-on's cases against its list and put the listed
# ones into CASES, after the core cases and before the last one (case_isolation, which compares the
# repository before and after the run). Prints the refusal to stderr and returns 1, changing nothing.
_harness_add_addon_cases() {
  local root="$1" d name f defined listed bad rest last n c i
  local extra=() all=() fn
  local LC_ALL=C
  for d in "$root"/modules/*/test; do
    [ -d "$d" ] || continue
    name="${d#"$root"/modules/}"; name="${name%/test}"
    defined=""
    for f in "$d"/cases/*.sh; do
      [ -f "$f" ] || continue
      defined="${defined}$(grep -o '^case_[a-z0-9_]*() {' "$f" | sed 's/() {$//')"$'\n'
    done
    defined="$(printf '%s' "$defined" | grep . | sort || true)"
    if [ ! -f "$d/CASE-LIST" ]; then
      [ -z "$defined" ] && continue
      _harness_addon_refuse "$name" "it defines case(s) but has no modules/$name/test/CASE-LIST to list them in:" "$defined" "Create modules/$name/test/CASE-LIST and list each case in it, one per line."
      return 1
    fi
    listed="$(sed 's/\r$//; s/#.*//; s/^[[:space:]]*//; s/[[:space:]]*$//' "$d/CASE-LIST" | grep . || true)"
    bad="$(printf '%s\n' "$listed" | grep -v -x 'case_[a-z0-9_]*' | grep . || true)"
    if [ -n "$bad" ]; then
      _harness_addon_refuse "$name" "modules/$name/test/CASE-LIST lists a name that is not a case function (case_ and lowercase letters, digits, _):" "$bad" "Correct those lines of modules/$name/test/CASE-LIST."
      return 1
    fi
    bad="$(printf '%s\n' "$listed" | sort | uniq -d | grep . || true)"
    if [ -n "$bad" ]; then
      _harness_addon_refuse "$name" "modules/$name/test/CASE-LIST lists a case more than once:" "$bad" "List each case once in modules/$name/test/CASE-LIST."
      return 1
    fi
    rest="$(comm -23 <(printf '%s\n' "$defined") <(printf '%s\n' "$listed" | sort) | grep . || true)"
    if [ -n "$rest" ]; then
      _harness_addon_refuse "$name" "it defines case(s) that modules/$name/test/CASE-LIST does not list (these would never run):" "$rest" "Add each to modules/$name/test/CASE-LIST, or delete the function."
      return 1
    fi
    rest="$(comm -13 <(printf '%s\n' "$defined") <(printf '%s\n' "$listed" | sort) | grep . || true)"
    if [ -n "$rest" ]; then
      _harness_addon_refuse "$name" "modules/$name/test/CASE-LIST lists case(s) that no file in modules/$name/test/cases/ defines (these would error):" "$rest" "Define each in modules/$name/test/cases/, or remove it from modules/$name/test/CASE-LIST."
      return 1
    fi
    while IFS= read -r fn; do
      [ -n "$fn" ] || continue
      for c in ${CASES[@]+"${CASES[@]}"} ${extra[@]+"${extra[@]}"}; do
        if [ "$c" = "$fn" ]; then
          _harness_addon_refuse "$name" "modules/$name/test/CASE-LIST lists a name another case already carries (one function cannot be two cases):" "$fn" "Rename the add-on's case; a core case's name is not the add-on's to take."
          return 1
        fi
      done
      extra+=("$fn")
    done <<ADDON_LIST_EOF
$listed
ADDON_LIST_EOF
  done
  [ "${#extra[@]}" -gt 0 ] || return 0
  n=${#CASES[@]}
  last="${CASES[$((n - 1))]}"
  if [ "$last" != case_isolation ]; then
    echo "harness: REFUSING — the core case list does not end with case_isolation, so there is no place before it for an add-on's cases." >&2
    return 1
  fi
  for ((i = 0; i < n - 1; i++)); do all+=("${CASES[$i]}"); done
  all+=("${extra[@]}" "$last")
  CASES=("${all[@]}")
  return 0
}

# _harness_addon_refuse <add-on> <what is wrong> <the names, one per line> <the fix>
_harness_addon_refuse() {
  {
    echo "harness: REFUSING — the add-on '$1' and its case list disagree, so no case ran."
    echo "  $2"
    printf '%s\n' "$3" | sed 's/^/    /'
    echo "  Fix: $4"
  } >&2
}
