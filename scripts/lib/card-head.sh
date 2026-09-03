#!/usr/bin/env bash
# KIT-CLASS: KIT — the mint-time card re-head, in one place.
# See process/EXTRACTION.md.
#
# WHY THIS EXISTS. Five creation scripts strip a template's travel-classification marker
# at mint time and put a live-card head in its place. The block was written out five
# times, each carrying the same comment deferring the fix: "they source no common file,
# and giving them one is a structural change owned elsewhere. When that lib exists, this
# moves into it." That lib exists, all five already source scripts/config.sh, and the
# deferral's own recorded trigger has therefore fired.
#
# AND THE COPIES HAD ALREADY DIVERGED, in the way a byte-comparison of the wrong operand
# would miss: three act on $WORK and carry the full comment block, one acts on $DEST with
# no comment, and one is indented inside a case arm. "Byte-identical in five scripts" was
# true of three. The differing operand is precisely what an argument fixes.
#
# THE PATH IS AN ARGUMENT, and that is not a style choice: `${BASH_SOURCE[0]}` inside a
# SOURCED function names this library, not the caller — a trap this kit has already
# measured once, when a shared usage renderer printed its own header instead of its
# caller's. The caller passes the card it is minting.

# kit_rehead_card <card-file>
#
# THE TEMPLATE'S TRAVEL CLASSIFICATION GOES; ITS STILL-IN-FORCE INSTRUCTION STAYS.
# process/EXTRACTION.md § The marker and graduation: a minted card's class has become
# PROJECT at the moment of minting, so the KIT-CLASS: marker is stripped. But that marker
# also carried a FILL instruction still in force while the author fills the card, and the
# same manifest forbids an instruction living inside a marker that will be removed — so
# this REPLACES the block rather than deleting it. A blind delete would have taken the
# guidance with the classification, and nowhere else in the kit states it.
#
# THE HEAD MUST NOT CONTAIN THE MARKER KEY, NOT EVEN TO DENY IT. The convention's own way
# to derive what is classified is `grep -rl` for that key, so a card saying "no <key>
# marker" would be a false POSITIVE in the one derivation the manifest recommends — and
# would redden the harness case asserting a minted card is unmarked. Measured: the first
# wording did exactly that. (This reason lived at ONE of the five copies; it applies to
# all of them, and lifting the block without lifting the reason would have lost it.)
#
# THE HEAD IS PREPENDED BY THE SHELL, NOT PASSED INTO awk. `awk -v x="$MULTILINE"` fails
# with "newline in string" and awk then writes NOTHING — measured: the first version of
# this block produced an EMPTY card. awk deletes the old block, printf writes the new
# head, cat appends the rest; every step is POSIX and none carries a newline through an
# assignment.
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
  # THE POSTCONDITION IS ASSERTED, because every failure mode here is SILENT: an awk that
  # wrote nothing, a marker whose shape moved, a card that came out empty. All three leave
  # a file the caller then happily moves into place.
  [ -s "$card" ] \
    || { echo "kit_rehead_card: '$card' is EMPTY after the re-head — the card was destroyed, not minted." >&2; return 1; }
  grep -q '^<!-- KIT-CLASS:' "$card" \
    && { echo "kit_rehead_card: '$card' still carries a KIT-CLASS: marker after the re-head — a live card must not." >&2; return 1; }
  return 0
}
