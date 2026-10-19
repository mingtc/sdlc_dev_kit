#!/usr/bin/env bash
# KIT-CLASS: KIT — the generated-attribution wording family, one authoring site.
# See process/EXTRACTION.md.
#
# WHY THIS EXISTS: scripts/githooks/commit-msg's rule (2) refuses the attribution-trailer family
# (doctrine/commit-hygiene.md § A.1) at write time; check-board.sh arm [h] reads history for the
# same family. Two readers of one rule drift, so there is one: kit_attrib_offender below is what
# the hook and arm [h] both call, and the wording list and tool markers it reads are authored once,
# in the hook.
#
# kit_attrib_trailer_words <repo-root>
#   Echoes the hook's declared `ATTRIB_TRAILER_WORDS` value (the `<word>-by` alternation, no
#   trailing colon), or nothing if it cannot be read. Callers must treat empty as "could not
#   read", never as "no wordings declared" — mirrors lib/role-set.sh's kit_role_set.
kit_attrib_trailer_words() {
  sed -n "s/^ATTRIB_TRAILER_WORDS='\(.*\)'/\1/p" "$1/scripts/githooks/commit-msg" 2>/dev/null | head -1
}

# kit_normalize_hyphens — filter, stdin to stdout: every Unicode hyphen/dash a person's editor or
# a harness's own banner commonly substitutes for `-` (U+2010 hyphen, U+2011 non-breaking hyphen,
# U+2012 figure dash, U+2013 en dash, U+2014 em dash, U+2015 horizontal bar, U+2212 minus sign) is
# folded to the plain ASCII hyphen BEFORE either reader matches. Run this first, always: a pattern
# anchored on `-by:` does not see `\xe2\x80\x91by:` and reads a refused wording as clean.
kit_normalize_hyphens() {
  sed \
    -e "s/$(printf '\xe2\x80\x90')/-/g" \
    -e "s/$(printf '\xe2\x80\x91')/-/g" \
    -e "s/$(printf '\xe2\x80\x92')/-/g" \
    -e "s/$(printf '\xe2\x80\x93')/-/g" \
    -e "s/$(printf '\xe2\x80\x94')/-/g" \
    -e "s/$(printf '\xe2\x80\x95')/-/g" \
    -e "s/$(printf '\xe2\x88\x92')/-/g"
}

# kit_attrib_offender <repo-root> <message-text-on-stdin>
#   Echoes the first line of stdin that carries a generated-attribution line, normalized (Unicode
#   hyphens folded), or nothing if none does. Three arms, each anchored at a line start behind
#   optional whitespace, a list bullet and a backtick: (a) a `<word>-by:` trailer naming a tool,
#   (b) "generated (with|by) …" prose, (c) "written (with|by) …" prose naming a tool. The wording
#   list and the markers are the ones the hook declares. Returns 1 for no match AND when either
#   declaration cannot be read: a caller that must not accept on an unreadable declaration checks
#   kit_attrib_trailer_words first.
kit_attrib_offender() {
  local root="$1" words markers body found
  words="$(kit_attrib_trailer_words "$root")"
  markers="$(sed -n "s/^TOOL_TRAILER_MARKERS='\(.*\)'/\1/p" "$root/scripts/githooks/commit-msg" 2>/dev/null | head -1)"
  [ -n "$words" ] && [ -n "$markers" ] || return 1   # return-class: predicate
  body="$(cat | kit_normalize_hyphens)"
  found="$(printf '%s\n' "$body" \
      | grep -iE "^[[:space:]]*([-*][[:space:]]+)?\`?(${words})[[:space:]]*:(.*[^[:alnum:]])?(${markers})([^[:alnum:]]|\$)" \
      | sed -n '1p')"
  [ -n "$found" ] || found="$(printf '%s\n' "$body" \
      | grep -iE '^[[:space:]]*([-*][[:space:]]+)?`?[^[:alnum:]]*generated[[:space:]-]+(with|by)[[:space:]:]' \
      | sed -n '1p')"
  [ -n "$found" ] || found="$(printf '%s\n' "$body" \
      | grep -iE "^[[:space:]]*([-*][[:space:]]+)?\`?[^[:alnum:]]*written[[:space:]-]+(with|by)(.*[^[:alnum:]])?(${markers})([^[:alnum:]]|\$)" \
      | sed -n '1p')"
  [ -n "$found" ] || return 1   # return-class: predicate
  printf '%s\n' "$found"
  return 0
}
