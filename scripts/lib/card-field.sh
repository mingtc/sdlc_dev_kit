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
#   free text such as `title:`. Prints nothing when the key is absent or empty, and always returns
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
