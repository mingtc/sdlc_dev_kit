# KIT-CLASS: MIXED — self-test harness, the case list beyond the smoke list, and the cases in packs. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/lib/case-list.sh — sourced by scripts/test/run.sh, never run on its own.
# run.sh's CASES array holds the smoke cases and ends with case_isolation. The rest of the harness's
# cases are listed, one name a line (`#` starts a comment), in scripts/test/CASE-LIST, which is a file
# of the pack that holds them while that pack is not unpacked. A tree without the file runs the array
# alone, and a pack's cases are counted from the pack and named in the run's output, never run.
# =============================================================================

# _harness_add_listed_cases <harness dir> — put the names in <dir>/CASE-LIST into CASES, after the array's cases
# and before the last one (case_isolation). Prints the refusal to stderr and returns 1, changing nothing.
_harness_add_listed_cases() {
  local f="$1/CASE-LIST" listed bad dup n last i c
  local all=() have=() LC_ALL=C
  [ -f "$f" ] || return 0
  listed="$(sed 's/\r$//; s/#.*//; s/^[[:space:]]*//; s/[[:space:]]*$//' "$f" | grep . || true)"
  bad="$(printf '%s\n' "$listed" | grep -v -x 'case_[a-z0-9_]*' | grep . || true)"
  if [ -n "$bad" ]; then
    _harness_list_refuse "scripts/test/CASE-LIST lists a name that is not a case function (case_ and lowercase letters, digits, _):" "$bad" "Correct those lines of scripts/test/CASE-LIST."
    return 1
  fi
  dup="$(printf '%s\n' "$listed" | sort | uniq -d | grep . || true)"
  if [ -n "$dup" ]; then
    _harness_list_refuse "scripts/test/CASE-LIST lists a case more than once:" "$dup" "List each case once in scripts/test/CASE-LIST."
    return 1
  fi
  dup="$(comm -12 <(printf '%s\n' "${CASES[@]}" | sort) <(printf '%s\n' "$listed" | sort) | grep . || true)"
  if [ -n "$dup" ]; then
    _harness_list_refuse "scripts/test/CASE-LIST lists case(s) the CASES array in run.sh already names (one function cannot be two cases):" "$dup" "Keep each case in one of the two: the array or scripts/test/CASE-LIST."
    return 1
  fi
  n=${#CASES[@]}; last="${CASES[$((n - 1))]}"
  if [ "$last" != case_isolation ]; then
    echo "harness: REFUSING — the CASES array does not end with case_isolation, so there is no place before it for the cases in scripts/test/CASE-LIST." >&2
    echo "  Fix: put case_isolation last in the CASES array in run.sh." >&2
    return 1
  fi
  for ((i = 0; i < n - 1; i++)); do all+=("${CASES[$i]}"); done
  while IFS= read -r c; do [ -n "$c" ] && all+=("$c"); done <<CASE_LIST_EOF
$listed
CASE_LIST_EOF
  all+=("$last")
  CASES=("${all[@]}")
  return 0
}

# _harness_list_refuse <what is wrong> <the names, one per line> <the fix>
_harness_list_refuse() {
  {
    echo "harness: REFUSING — scripts/test/CASE-LIST and the CASES array disagree, so no case ran."
    echo "  $1"
    printf '%s\n' "$2" | sed 's/^/    /'
    echo "  Fix: $3"
  } >&2
}

# _harness_packed_note <root> — sets PACKED_NOTE to one line naming each pack that holds a case list its tree
# lacks (scripts/test/CASE-LIST or modules/<name>/test/CASE-LIST) and how many cases that list names, and each
# pack the reader could not read, with the command that checks it; empty when there is nothing to say.
# The reader's own program lists and reads the pack, so nothing is unpacked.
_harness_packed_note() {
  local root="$1" kp="$1/scripts/lib/kitpack.sh" dir ext pk members list p n note="" bad="" total=0 LC_ALL=C
  PACKED_NOTE=""
  [ -f "$kp" ] || return 0
  read -r dir ext _ <<< "$( . "$kp" >/dev/null 2>&1; printf '%s %s' "${KIT_PACK_DIR:-}" "${KIT_PACK_EXT:-}" )"
  [ -n "$dir" ] && [ -n "$ext" ] || return 0
  for pk in "$root/$dir"/*."$ext"; do
    [ -f "$pk" ] || continue
    members="$(sh "$kp" ls "$pk" 2>/dev/null </dev/null)" || { bad="${bad:+$bad, }$dir/${pk##*/}"; continue; }
    members="$(printf '%s\n' "$members" | sed 's/^[0-9]* //')"
    while IFS= read -r p; do
      case "$p" in scripts/test/CASE-LIST|modules/*/test/CASE-LIST) ;; *) continue ;; esac
      [ ! -e "$root/$p" ] || continue
      list="$(sh "$kp" cat "$pk" "$p" 2>/dev/null </dev/null)" || { bad="${bad:+$bad, }$dir/${pk##*/}"; break; }
      n="$(printf '%s\n' "$list" | sed 's/\r$//; s/#.*//; s/^[[:space:]]*//; s/[[:space:]]*$//' | grep -c . || true)"
      [ "${n:-0}" -gt 0 ] || continue
      note="${note:+$note, }${n} in $dir/${pk##*/}"; total=$(( total + n ))
    done <<PACKED_MEMBERS_EOF
$members
PACKED_MEMBERS_EOF
  done
  [ -z "$note" ] || PACKED_NOTE="in packs, not in this run: $note ($total case(s)). Next: ./scripts/pack.sh unpack --all, then run this again for the whole list."
  [ -z "$bad" ] || PACKED_NOTE="${PACKED_NOTE:+$PACKED_NOTE }packs this run could not read: $bad. Next: ./scripts/pack.sh verify <name> says what is wrong; restore the pack from the zip."
  return 0
}
