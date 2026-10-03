#!/usr/bin/env bash
# KIT-CLASS: KIT — the ONE `PROJECT.md` marker-line field reader. See process/EXTRACTION.md.
#
# scripts/ask.sh and check-board.sh arm [g] both read the `principal:` and channel lines through
# this one function, so the two can never disagree about whether a field is filled.
#
# kit_pm_field <marker-regex> <file>
#   Reads the FIRST line in <file> matching <marker-regex> (an awk ERE, the same shape both
#   callers already passed: `` `principal:` `` or `\*\*Their channel:\*\*` ) and echoes the
#   value that follows the marker on that line:
#     - the first backtick-delimited span after the marker, if there is one;
#     - otherwise the REST OF THE LINE, with leading and trailing Markdown emphasis (`*`, `_`)
#       and whitespace stripped — a bare fill (`PM`, `nobody`) is read as that text, and a bare
#       path keeps its own underscores.
#   Echoes nothing if the marker is not found. Callers treat empty, and the shipped
#   `<angle-bracket>` blank, as unfilled themselves (`_is_blank` in ask.sh) — this reader only
#   extracts the value; it does not judge blankness.
kit_pm_field() {
  awk -v marker="$1" '
    match($0, marker) {
      rest = substr($0, RSTART + RLENGTH)
      if (match(rest, /`[^`]*`/)) {
        print substr(rest, RSTART + 1, RLENGTH - 2)
        exit
      }
      v = rest
      gsub(/^[*_ \t]+/, "", v)
      gsub(/[*_ \t]+$/, "", v)
      print v
      exit
    }' "$2"
}
