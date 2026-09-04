#!/usr/bin/env bash
# KIT-CLASS: KIT — the ONE already-lived probe. See process/EXTRACTION.md.
#
# WHAT "ALREADY LIVED" MEANS, IN ONE PLACE. Two shipped consumers ask the same question
# of a tree — has this repository STARTED? — and used to answer it with two separate
# implementations of the same four probes: a board carrying issue files, a progress.md
# § Log with entries, an ARCHIVE.md with an index, or a config.sh already stamped.
# scripts/kit-init.sh asks in order to REFUSE to initialize a lived tree;
# scripts/check-board.sh arm [g] asks in order to decide whether to RUN.
#
# THE TWO COPIES HAD ALREADY DIVERGED, which is why this is an extraction and not a
# tidy-up, and why "preserve behaviour exactly" was not available to it. Measured
# 2026-09-02 with /usr/bin/grep, on a config.sh whose stamp line is INDENTED:
#
#     kit-init      grep -q "^$STAMP_MARK"   → NOT lived   (anchored, and a BRE)
#     check-board   grep -qF "$g_stamp"      → LIVED       (literal, unanchored)
#
# So a repository could be "not started" to the initializer and "already lived" to the
# report — with the INITIALIZER as the blind one, i.e. it would have initialized a tree
# the report already considered started. That is the failure this file exists to end.
#
# THE ADJUDICATION, stated rather than smuggled: ANCHORED, like kit-init, AND LITERAL,
# like check-board — which neither had. `index($0,m)==1` is both, with no regex
# metacharacters in play at all, so the '.' characters in the mark stop being wildcards.
# Consequences, both accepted: arm [g] TIGHTENS (a config.sh that merely mentions the
# mark mid-line no longer enables it via the receipt — the other three signals still
# can), and kit-init loses BRE looseness it never wanted.
#
# IT EMITS RECORDS, NOT SENTENCES, and that is what stops the extraction re-creating the
# defect. The two callers legitimately SAY different things about the same answer:
# kit-init lists every signal as a refusal bullet, arm [g] names exactly one as its
# enabling condition, in its own wording. A library that emitted prose would change one
# caller's output; callers that re-worded a library's prose would be a second copy again.
# One authoring site for the probe shapes, and each caller renders. (Said "three"; this file's
# own header two dozen lines above says FOUR, and four is right.)
#
#   stamp|<the matched config.sh line>
#   folder|<name>|<count>
#   log|<count>
#   archive|<count>
#
# STAMP FIRST, and that is load-bearing rather than alphabetical: arm [g] takes the FIRST
# record as its enabling condition, and the receipt is the signal it named before this
# extraction. Empty output means NOT STARTED. kit-init's bullet order changes (stamp
# leads instead of trails); no assertion reads that order.

# kit_lived_signals <tree> <stamp_mark> <status_folder>...
kit_lived_signals() {
  # A ZERO-COLUMN CALL IS REFUSED, NOT ANSWERED. Emitting nothing would be indis-
  # tinguishable from "this tree has not started", which is the silent-blind failure the
  # callers' own fixtures already guard against; the library owes the same.
  if [ "$#" -lt 3 ]; then
    echo "kit_lived_signals: need <tree> <stamp_mark> <status_folder>... — got $# argument(s). Refusing to report 'not started' about a tree whose board columns were never named." >&2
    return 1
  fi
  local tree="$1" mark="$2"; shift 2
  local c n line

  # (1) THE RECEIPT — anchored and literal, per the adjudication above.
  if [ -f "$tree/scripts/config.sh" ]; then
    line="$(awk -v m="$mark" 'index($0,m)==1 { print; exit }' "$tree/scripts/config.sh" 2>/dev/null || true)"
    [ -n "$line" ] && printf 'stamp|%s\n' "$line"
  fi

  # (2) BOARD COLUMNS — the caller passes them, because the two callers hold
  # STATUS_FOLDERS in incompatible TYPES (a bash array in one, a '|'-delimited string in
  # the other). A library that read the variable itself would work for exactly one of them.
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
