#!/usr/bin/env bash
# KIT-CLASS: KIT — the ONE header-block --help renderer. See process/EXTRACTION.md.
#
# THE RULE: a script's `--help` is its own header comment block, from the line after the
# KIT-CLASS marker to the last comment line before the first code line, `# ` stripped. A
# KIT-DISPOSITION line under the marker is for tools, not readers, and is skipped: keep it on one
# line ending in a full stop (a wrapped one is skipped only up to the first line that ends in one).
# Write the header once: no second copy to drift, no hard-coded line range.
#
# THE PATH IS AN ARGUMENT, NOT `${BASH_SOURCE[0]}`: inside a sourced function that names THIS
# file, so every caller would print the library's header. Callers pass their own path:
# `kit_usage "${BASH_SOURCE[0]}"`.
#
# Not every shipped renderer uses this. Derive the set (-F and this quoting keep \{0,1\} literal;
# as a plain pattern it silently matches nothing):
#
#     grep -rlF 'sed '"'"'s|^# \{0,1\}||'"'"'' scripts consumers setup.sh
#
#   * scripts/release.sh renders its SYNOPSIS only (operator notes follow its usage examples)
#     and sources only the few libraries its top names, by design. Do not sweep it in.
#   * consumers/ holds TEMPLATES that leave for a consumer repository, where scripts/lib/ does
#     not exist; each keeps its own copy.
#   * scripts/test/run.sh could source this file and does not. No reason is recorded: debt, not
#     a carve-out.

# kit_usage <path to the CALLER's own file>
kit_usage() {
  local src="$1" first end
  [ -n "$src" ] && [ -f "$src" ] || {
    echo "kit_usage: called without a readable source path — the caller must pass its own \"\${BASH_SOURCE[0]}\"." >&2
    return 1   # return-class: internal
  }
  # The window starts after the marker's LAST line, which cites EXTRACTION.md (a marker may
  # wrap). Falls back to the KIT-CLASS line, then to line 3.
  local start
  start="$(awk 'NR<=12 && /EXTRACTION\.md/{print NR+1; exit}' "$src")"
  [ -n "$start" ] || start="$(awk 'NR<=12 && /KIT-CLASS:/{print NR+1; exit}' "$src")"
  [ -n "$start" ] || start=3
  # A KIT-DISPOSITION line is skipped; one that does not end in a full stop continues onto the comment
  # lines below it, up to and including the first that does.
  start="$(awk -v s="$start" 'NR<s{next} skip && !/^#/{skip=0} skip{if (/\.[[:space:]]*$/) skip=0; next} /^#[[:space:]]*KIT-DISPOSITION:/{if (!/\.[[:space:]]*$/) skip=1; next} {f=1; print NR; exit} END{if (!f) print s}' "$src")"
  first="$(awk -v s="$start" 'NR>=s && !/^#/{print NR; exit}' "$src")"
  # `first` is never below `start`. The floor is for an ALL-COMMENT file, which leaves `first`
  # unset and would otherwise give `3,-1p`, an error.
  end=$(( ${first:-0} - 1 )); [ "$end" -lt "$start" ] && end="$start"
  sed -n "${start},${end}p" "$src" | sed 's|^# \{0,1\}||'
}
