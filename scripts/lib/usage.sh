#!/usr/bin/env bash
# KIT-CLASS: KIT — the ONE header-block --help renderer. See process/EXTRACTION.md.
#
# THE RULE: a script's `--help` is its own header comment block, from line 3 to the last
# comment line of the block, with the leading `# ` stripped. Write the header once and
# the help follows it — no second copy to drift, and no hard-coded line range, which is
# a census in disguise and has cost this kit twice.
#
# THE PATH IS AN ARGUMENT AND NOT `${BASH_SOURCE[0]}`, AND THAT IS THE WHOLE TRAP HERE.
# Inside a SOURCED function, `${BASH_SOURCE[0]}` names THIS FILE — so the naive lift of
# the five-line body into a library makes every caller's `--help` print the LIBRARY's
# header. `${BASH_SOURCE[1]}` happens to work today and breaks the moment anything wraps
# the call. Callers pass their own path: `kit_usage "${BASH_SOURCE[0]}"`.
#
# NOT EVERY SHIPPED RENDERER USES THIS. Derive the set before reasoning about it —
# this said "TWO RULES, BOTH RULED" and named two files while four others rendered
# their own header block:
#
#     grep -rlF 'sed '"'"'s|^# \{0,1\}||'"'"'' scripts consumers setup.sh
#
#   (-F, and quoted this way, DELIBERATELY. Written as a normal grep pattern this matches NOTHING:
#   grep reads \{0,1\} as an interval quantifier rather than as the literal text being searched
#   for, so the command shipped as a derivation that silently returned an empty set — a recipe
#   that cannot fail, in a comment telling you to derive rather than trust. Verified: it returns
#   seven files.)
#
#   * scripts/release.sh renders its SYNOPSIS instead, stopping at its last usage
#     example, because its header carries operator notes below them that are not help
#     text. Derive both rather than trusting a figure here — `./scripts/release.sh --help | wc -l`
#     against `bash -c '. scripts/lib/usage.sh; kit_usage scripts/release.sh' | wc -l`. (Measured
#     11 against 66 on 2026-09-04; an earlier note here said 63 for the second.) It also sources
#     nothing from lib/ by design. Do not sweep it in.
#   * EVERYTHING UNDER consumers/ is a TEMPLATE that leaves the tree into a consumer's
#     repository, where scripts/lib/ does not exist. Each keeps its own copy, necessarily.
#     (This rule named update_vendored.sh alone; install-skills.sh and setup-consumer.sh
#     leave the tree for exactly the same reason and were simply not listed.)
#   * scripts/notify/telegram.sh and scripts/test/run.sh are NOT ruled. Both stay in the
#     tree and both COULD source this file. They are named here because an exception that
#     is not written down is indistinguishable from an oversight, and these two were the
#     oversight: no reason has been recorded for them, and until one is, they are debt
#     rather than design. Do not read their presence in this list as a carve-out.
#
# THE WINDOW START IS DERIVED at both ends now. It used to be the literal 3, which
# assumed the KIT-CLASS marker was exactly line 2 — false wherever the marker wraps, and
# help then opened with marker text.

# kit_usage <path to the CALLER's own file>
kit_usage() {
  local src="$1" first end
  [ -n "$src" ] && [ -f "$src" ] || {
    echo "kit_usage: called without a readable source path — the caller must pass its own \"\${BASH_SOURCE[0]}\"." >&2
    return 1
  }
  # THE WINDOW START IS DERIVED, NOT A LITERAL 3. The literal encoded a premise — line 1
  # is the shebang, line 2 is the whole KIT-CLASS marker — and the premise is false
  # wherever the marker WRAPS: help then opens with marker text, which is the one thing
  # this window exists to exclude. Several shipped files carry a marker spanning more than one
  # line — derive the set rather than trusting a count here. Every marker's LAST line cites EXTRACTION.md — that is the convention
  # `process/EXTRACTION.md` § The one file classification convention sets — so the marker's
  # end is derivable rather than assumed. Falls back to the KIT-CLASS line itself, then to
  # the old literal, so a file that follows neither convention degrades to today's
  # behaviour rather than to nothing.
  local start
  start="$(awk 'NR<=12 && /EXTRACTION\.md/{print NR+1; exit}' "$src")"
  [ -n "$start" ] || start="$(awk 'NR<=12 && /KIT-CLASS:/{print NR+1; exit}' "$src")"
  [ -n "$start" ] || start=3
  first="$(awk -v s="$start" 'NR>=s && !/^#/{print NR; exit}' "$src")"
  # THE FLOOR IS FOR THE EMPTY CASE, not the small one: `first` can never be below `start`
  # (the awk begins at NR>=s), and `start` is itself never below 3 — the marker it derives from
  # sits below a shebang, and its last fallback is the literal 3. `sed -n "3,2p"` prints line 3
  # rather than erroring. An ALL-COMMENT file leaves `first` unset, and THAT yields `3,-1p`,
  # which does error.
  #
  # THAT PARENTHETICAL READ "(the awk starts at NR>2)" UNTIL 2026-09-07 — describing the line TWO
  # ABOVE IT, after that line was reworded to `NR>=s` in the same edit that made `start` derivable.
  # The conclusion was still true; the reason it gave had stopped being. Recorded rather than
  # silently fixed because the DISTANCE is the useful part: this is the shortest gap between a
  # changed line and a stale description of it found in this repository, and both halves were on
  # one screen to whoever made the change. When you reword an expression, the comment two lines
  # below it is a concrete place to look.
  end=$(( ${first:-0} - 1 )); [ "$end" -lt "$start" ] && end="$start"
  sed -n "${start},${end}p" "$src" | sed 's|^# \{0,1\}||'
}
