#!/usr/bin/env bash
# KIT-CLASS: KIT — the ONE reader of a card's frontmatter field. See process/EXTRACTION.md.
#
# Every script that reads a key of a card's frontmatter (`branch:`, `prd:`, `id:`, `forks:`, `pr:`,
# `title:`…) reads it through this file, so a card resolves to the same value at hand-off, at
# landing, at the upgrade re-check and in the reports. A read of a card key written any other way
# is a second reader.
#
# kit_card_field <card-file> <key> [--raw]
#   Prints the value of the first `<key>:` line between the card's first two `---` lines, with a
#   trailing `# comment` and surrounding whitespace removed. `--raw` keeps a `#` in the value, for
#   free text such as `title:`. For `title:`, `--raw` also strips one pair of outer double quotes and
#   unescapes `\"` and `\\` inside them (the templates ship the title quoted, so a `: ` in it is
#   valid YAML); an unquoted title is returned unchanged. Prints nothing when the key is absent or empty, and always returns
#   0. A `<key>:` line in the body is never read.
#
# kit_card_has_field <card-file> <key>
#   Returns 0 when the frontmatter carries a `<key>:` line (empty or not), 1 when it does not.
_kit_card_scan() {
  awk -v k="$2" -v mode="$3" '
    /^---[[:space:]]*$/ { n++; next }
    n == 1 && index($0, k ":") == 1 {
      found = 1
      if (mode != "has") {
        sub(/^[^:]*:[[:space:]]*/, "")
        if (mode == "value") sub(/(^|[[:space:]]+)#.*$/, "")
        sub(/[[:space:]]+$/, "")
        if (mode == "raw" && k == "title" && length($0) >= 2 && substr($0, 1, 1) == "\"" && substr($0, length($0), 1) == "\"") {
          v = substr($0, 2, length($0) - 2); $0 = ""
          for (i = 1; i <= length(v); i++) {
            c = substr(v, i, 1)
            if (c == "\\" && (substr(v, i + 1, 1) == "\"" || substr(v, i + 1, 1) == "\\")) { i++; c = substr(v, i, 1) }
            $0 = $0 c
          }
        }
        print
      }
      exit
    }
    END { exit !found }' "$1"
}
kit_card_field() {
  _kit_card_scan "$1" "$2" "$([ "${3:-}" = --raw ] && echo raw || echo value)" || true
}
kit_card_has_field() {
  _kit_card_scan "$1" "$2" has
}

# kit_card_id_of_path <path>
#   Prints the card id a card file's name begins with: `<PREFIX>-NNN` for `<id>-<slug>.md` or `<id>.md`,
#   in any folder. A file under a `subtasks/` directory is a slice: its id is `<PREFIX>-NNN-s<N>`, the
#   parent's id plus the suffix, so a slice is never read as its parent. Prints nothing for any other
#   name, and always returns 0.
kit_card_id_of_path() {
  local _kcid_name _kcid_id=""
  _kcid_name="$(basename "$1")"
  case "$1" in
    subtasks/*|*/subtasks/*)
      _kcid_id="$(printf '%s\n' "$_kcid_name" | sed -nE 's/^([A-Za-z][A-Za-z0-9]*-[0-9]+-s[0-9]+)(-.*)?\.md$/\1/p')" ;;
  esac
  [ -n "$_kcid_id" ] || _kcid_id="$(printf '%s\n' "$_kcid_name" | sed -nE 's/^([A-Za-z][A-Za-z0-9]*-[0-9]+)(-.*)?\.md$/\1/p')"
  [ -z "$_kcid_id" ] || printf '%s\n' "$_kcid_id"
  return 0
}
