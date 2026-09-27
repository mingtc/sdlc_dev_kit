#!/usr/bin/env bash
# KIT-CLASS: KIT — the mint-time card re-head, in one place.
# See process/EXTRACTION.md.
#
# The creation scripts strip a template's travel-classification marker at mint time and put
# a live-card head in its place; this is that block's one copy. The card path is an argument
# because `${BASH_SOURCE[0]}` inside a sourced function names this library, not the caller.

# kit_rehead_card <card-file>
#
# REPLACE, DON'T DELETE: a minted card's class is PROJECT, so the KIT-CLASS: marker goes
# (process/EXTRACTION.md § The marker and graduation), but it carried a FILL instruction still
# in force, and the head below is its only other statement.
#
# THE HEAD MUST NOT CONTAIN THE MARKER KEY, NOT EVEN TO DENY IT: `grep -rl` for that key is how
# classified files are derived, and a minted card must stay unmarked.
#
# THE HEAD IS PREPENDED BY THE SHELL, NOT PASSED INTO awk: `awk -v x="$MULTILINE"` fails with
# "newline in string" and awk then writes nothing, leaving an empty card.
kit_rehead_card() {
  local card="$1" body head
  [ -n "$card" ] && [ -f "$card" ] || {
    echo "kit_rehead_card: called without a readable card path — the caller must pass the file it is minting." >&2
    return 1
  }
  head='<!-- A live card, not a template. It carries NO travel-classification marker, by design:
     this file was born in this repository and never travels, and process/EXTRACTION.md § The one
     file classification convention states that the absence is deliberate rather than an oversight.
     Fill every <angle-bracket>; never leave one in a live card. -->'
  body="${card}.rehead"
  awk '
    /^<!-- KIT-CLASS:/ { skip = 1; next }
    skip && /-->/      { skip = 0; next }
    skip              { next }
                      { print }
  ' "$card" > "$body"
  { printf '%s\n' "$head"; cat "$body"; } > "$card"
  rm -f "$body"
  # The postcondition is asserted because every failure mode here is silent.
  [ -s "$card" ] \
    || { echo "kit_rehead_card: '$card' is EMPTY after the re-head — the card was destroyed, not minted." >&2; return 1; }
  grep -q '^<!-- KIT-CLASS:' "$card" \
    && { echo "kit_rehead_card: '$card' still carries a KIT-CLASS: marker after the re-head — a live card must not." >&2; return 1; }
  return 0
}
