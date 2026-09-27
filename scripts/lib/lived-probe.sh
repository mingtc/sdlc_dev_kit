#!/usr/bin/env bash
# KIT-CLASS: KIT — the ONE already-lived probe. See process/EXTRACTION.md.
#
#
# HAS THIS REPOSITORY STARTED? One answer for scripts/kit-init.sh (which refuses to initialize
# a lived tree) and scripts/check-board.sh arm [g] (which runs only on one). Four signals: a
# stamped config.sh, a board column holding issue files, a progress.md § Log with entries, an
# ARCHIVE.md with an index.
#
# THE STAMP MATCH IS ANCHORED AND LITERAL: `index($0,m)==1`, so the '.' in the mark is not a
# wildcard and a mid-line mention does not count.
#
# IT EMITS RECORDS, NOT SENTENCES: the callers word the same answer differently, and each
# renders its own.
#
#   stamp|<the matched config.sh line>
#   folder|<name>|<count>
#   log|<count>
#   archive|<count>
#
# STAMP FIRST, on purpose: arm [g] takes the FIRST record as its enabling condition. Empty
# output means NOT STARTED.

# kit_lived_signals <tree> <stamp_mark> <status_folder>...
kit_lived_signals() {
  # A zero-column call is refused: empty output would read as "not started".
  if [ "$#" -lt 3 ]; then
    echo "kit_lived_signals: need <tree> <stamp_mark> <status_folder>... — got $# argument(s). Refusing to report 'not started' about a tree whose board columns were never named." >&2
    return 1
  fi
  local tree="$1" mark="$2"; shift 2
  local c n line

  # (1) THE RECEIPT — anchored and literal, per the stamp rule above.
  if [ -f "$tree/scripts/config.sh" ]; then
    line="$(awk -v m="$mark" 'index($0,m)==1 { print; exit }' "$tree/scripts/config.sh" 2>/dev/null || true)"
    [ -n "$line" ] && printf 'stamp|%s\n' "$line"
  fi

  # (2) BOARD COLUMNS are passed in: the callers hold STATUS_FOLDERS in different types (a bash
  # array, a '|'-delimited string).
  for c in "$@"; do
    [ -d "$tree/progress/$c" ] || continue
    n="$( { find "$tree/progress/$c" -type f -name '*-[0-9]*.md' 2>/dev/null || true; } | wc -l | tr -d ' ')"
    [ "${n:-0}" -gt 0 ] && printf 'folder|%s|%s\n' "$c" "$n"
  done

  # (3) progress.md § Log, and (4) ARCHIVE.md § Archived.
  if [ -f "$tree/progress.md" ]; then
    n="$(awk '/^##[[:space:]]/ { if (inlog) exit; if ($0 ~ /^##[[:space:]]+Log/) { inlog=1; next } } inlog && NF { print }' "$tree/progress.md" 2>/dev/null | wc -l | tr -d ' ')"
    [ "${n:-0}" -gt 0 ] && printf 'log|%s\n' "$n"
  fi
  if [ -f "$tree/ARCHIVE.md" ]; then
    n="$(awk '/^## Archived$/ { a=1; next } a && NF { print }' "$tree/ARCHIVE.md" 2>/dev/null | wc -l | tr -d ' ')"
    [ "${n:-0}" -gt 0 ] && printf 'archive|%s\n' "$n"
  fi
  return 0
}
