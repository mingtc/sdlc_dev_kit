#!/usr/bin/env bash
# KIT-CLASS: KIT — the ONE reader of a card's frontmatter field. See process/EXTRACTION.md.
#
# subtask.sh, move-issue.sh, finish-pr.sh and kit-upgrade.sh all read `branch:` (and `prd:`, `id:`)
# through kit_card_field, so a card resolves to the same value at hand-off, at landing and at the
# upgrade re-check.
#
# kit_card_field <card-file> <key>
#   Prints the value of the first `<key>:` line between the card's first two `---` lines, with a
#   trailing `# comment` and surrounding whitespace removed. Prints nothing when the key is absent
#   or empty. A `<key>:` line in the body is never read.
kit_card_field() {
  awk -v k="$2" '
    /^---[[:space:]]*$/ { n++; next }
    n == 1 && index($0, k ":") == 1 {
      sub(/^[^:]*:[[:space:]]*/, "")
      sub(/(^|[[:space:]]+)#.*$/, "")
      sub(/[[:space:]]+$/, "")
      print; exit
    }' "$1"
}
