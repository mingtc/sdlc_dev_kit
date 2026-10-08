#!/usr/bin/env bash
# KIT-CLASS: KIT — the ONE `PROJECT.md` marker-line field reader and the ONE blank test for its
# value. See process/EXTRACTION.md.
#
# scripts/ask.sh and check-board.sh arm [g] both read the `principal:` and channel lines through
# kit_pm_field, and both judge whether a value is filled through kit_pm_blank, so the two can
# never disagree about either.
#
# kit_pm_field <marker-regex> <file>
#   Reads the FIRST line in <file> matching <marker-regex> (an awk ERE, the same shape both
#   callers already passed: `` `principal:` `` or `\*\*Their channel:\*\*` ) and echoes the
#   value that follows the marker on that line:
#     - the first backtick-delimited span after the marker, if there is one;
#     - otherwise the REST OF THE LINE, with leading and trailing Markdown emphasis (`*`, `_`)
#       and whitespace stripped — a bare fill (`PM`, `nobody`) is read as that text, and a bare
#       path keeps its own underscores.
#   Echoes nothing if the marker is not found.
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

# kit_pm_blank <value> — status 0 if <value> (as kit_pm_field extracted it) carries no usable
# content, 1 otherwise. Blank is:
#   - empty, or empty after trimming leading/trailing whitespace;
#   - the shipped `<angle-bracket>` span, whole value;
#   - a placeholder a project left instead of answering: `TBD` (case-insensitive, the whole
#     value), `[fill in…]` / `[fill in: …]` (case-insensitive, bracketed), `{{ … }}`, or nothing but
#     underscores.
# This is a SHAPE test, not a truth test: a plausible non-answer ("the team", "someone") is not
# caught, and is not this function's job.
kit_pm_blank() {
  local v="$1" lower
  v="${v#"${v%%[![:space:]]*}"}"   # trim leading whitespace
  v="${v%"${v##*[![:space:]]}"}"   # trim trailing whitespace
  [ -n "$v" ] || return 0
  case "$v" in
    '<'[a-z]*'>') return 0 ;;
    '{{'*'}}') return 0 ;;
  esac
  case "$v" in
    *[!_]*) ;;
    *) return 0 ;;   # nothing but underscores (the empty case is caught above)
  esac
  lower="$(printf '%s' "$v" | tr 'A-Z' 'a-z')"
  case "$lower" in
    tbd) return 0 ;;
    '[fill in'*']') return 0 ;;
  esac
  return 1   # return-class: predicate
}
