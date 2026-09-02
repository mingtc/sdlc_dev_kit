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
# NOT EVERY SHIPPED RENDERER USES THIS, AND THAT IS DELIBERATE — TWO RULES, BOTH RULED:
#   * scripts/release.sh renders its SYNOPSIS instead, stopping at its last usage
#     example, because its header carries operator notes below them that are not help
#     text. Measured: on this rule its --help goes from 11 lines to 63. It also sources
#     nothing from lib/ by design. Do not sweep it in.
#   * consumers/update_vendored.sh is a TEMPLATE that leaves the tree into a consumer's
#     repository, where scripts/lib/ does not exist. It keeps its own copy, necessarily.
#
# KNOWN AND NOT FIXED HERE: the window START is the literal 3, which assumes the
# KIT-CLASS marker is exactly line 2. Where a marker wraps, help opens with marker text.

# kit_usage <path to the CALLER's own file>
kit_usage() {
  local src="$1" first end
  [ -n "$src" ] && [ -f "$src" ] || {
    echo "kit_usage: called without a readable source path — the caller must pass its own \"\${BASH_SOURCE[0]}\"." >&2
    return 1
  }
  first="$(awk 'NR>2 && !/^#/{print NR; exit}' "$src")"
  # THE FLOOR IS FOR THE EMPTY CASE, not the small one: `first` can never be below 3
  # (the awk starts at NR>2), and `sed -n "3,2p"` prints line 3 rather than erroring.
  # An ALL-COMMENT file leaves `first` unset, and THAT yields `3,-1p`, which does error.
  end=$(( ${first:-0} - 1 )); [ "$end" -lt 3 ] && end=3
  sed -n "3,${end}p" "$src" | sed 's|^# \{0,1\}||'
}
