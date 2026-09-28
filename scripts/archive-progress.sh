#!/usr/bin/env bash
# KIT-CLASS: KIT — progress.md rotation into progress/history/. See process/EXTRACTION.md.
# Rotate older entries out of progress.md into progress/history/<name>.md.
#
# progress.md is loaded into every session's context (read at session
# start by every role). Without rotation it grows unboundedly. This script
# slices off pre-cutoff entries into dated chunks under progress/history/.
#
# Milestones are user-discretionary: you pick a name + a date
# whenever the file feels heavy. Nothing here detects "milestone close".
#
# Usage — TWO KNIVES, exactly one per run:
#   ./scripts/archive-progress.sh --milestone <name> --keep-last <N>              # dry run
#   ./scripts/archive-progress.sh --milestone <name> --before <YYYY-MM-DD>        # dry run
#   …add --apply to rewrite the files, and --tag to git-tag first for revert safety.
#   --dry-run spells the default preview; with --apply it is refused.
#
# --repo-root <path>  relocates EVERY path this script reads and writes — progress.md,
#                     progress/history/<name>.md, progress/history/INDEX.md — and the tree
#                     that --tag tags. Default: the parent of this script's own directory.
#                     A supported option, not a test seam: it defeats no safety gate.
#
# WHICH KNIFE. The signal that a rotation is due is a BYTE threshold on § Log, reported by
# check-board.sh — and bytes can cross it more than once in a day.
#   --keep-last <N>        cuts at an ENTRY boundary: keep the newest N, rotate
#                          the rest. Use this when the trigger is a SIZE. It can
#                          be run again the same day and cuts further each time.
#   --before <YYYY-MM-DD>  cuts on a DAY boundary. Right for a milestone close,
#                          and unable to express a same-day second rotation: it
#                          reports nothing matched while the file is still over.
#
# The rotated entries are removed from progress.md and written to
# progress/history/<name>.md with a small YAML header (archived_at, cutoff,
# source). The retained entries plus the preamble stay in progress.md.
#
# EVERY CHUNK GETS AN INDEX ROW in progress/history/INDEX.md — chunk, the span of
# dates it covers, entry count, rotation date, and the cut used; it is what makes a
# chunk findable. A missing index is created only when no chunk exists yet (an empty
# index is then true); where chunks already exist this refuses.
#
# "Nothing matched" is NOT "nothing is due": if the cut you gave rotates nothing
# while § Log is still over the board's threshold, this says so on stderr and
# exits 3, because a clean exit 0 there reads as an all-clear that stops you
# looking. So a re-run after a clean rotation exits 0 only if § Log is under it.
#
# § Log ends at the next "## " heading that is not a "## YYYY-MM-DD" entry; that section and
# everything after it stay in progress.md, where they were.
#
# Entry-boundary forms recognized inside "## Log", the documented one first:
#   * a "### YYYY-MM-DD ..." session heading — THE FORM THE KIT DOCUMENTS. Carries
#     its whole section, undated sub-bullets included, but only when it is a
#     boundary in its own right: nested inside a "## " section it inherits that
#     section's bucket instead.
#   * a "## YYYY-MM-DD ..." session heading — accepted so a log that already uses it
#     is not stranded, but NOT documented and NOT to be migrated toward: check-board.sh's
#     § Log size arm and kit-init.sh's already-lived probe both stop at the next "##",
#     so a "##" dated entry ends § Log for them. It carries every line up to the next
#     "## " heading, which is why the other two forms are not boundaries beneath it.
#   * a bare/bulleted "YYYY-MM-DD ..." or "- YYYY-MM-DD ..." line — the oldest,
#     flattest form. Same nesting rule as "###": a boundary only when not under a
#     "## " section.
#
# Manual review before commit: this script does NOT `git add`.
# Review with `git status` / `git diff` and stage + commit yourself.

set -euo pipefail

# Defaults
DRY_RUN=true; SAW_APPLY=false; SAW_DRY=false
DO_TAG=false
MILESTONE=""
BEFORE=""
KEEP_LAST=""
REPO_ROOT=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/usage.sh
. "$SCRIPT_DIR/lib/usage.sh"

usage() { kit_usage "${BASH_SOURCE[0]}"; }   # the path is an ARGUMENT — see lib/usage.sh
# A usage request always succeeds, in any position, before any argument is interpreted
# (issue-creation.md § 3).
for _a in "$@"; do case "$_a" in -h|--help) usage; exit 0 ;; esac; done
# need_val — refuse an option whose value is missing: exit 2, naming it (issue-creation.md § 3).
need_val() {
  [ "$#" -ge 2 ] || { echo "Error: $1 requires a value." >&2; exit 2; }
}


while [ $# -gt 0 ]; do
  case "$1" in
    --milestone) need_val "$@"; MILESTONE="$2"; shift 2 ;;
    --before)    need_val "$@"; BEFORE="$2"; shift 2 ;;
    --keep-last) need_val "$@"; KEEP_LAST="$2"; shift 2 ;;
    --apply)     DRY_RUN=false; SAW_APPLY=true; shift ;;
    # Accepted though it is the default: a tool that can preview accepts the word for it.
    --dry-run)   DRY_RUN=true; SAW_DRY=true; shift ;;
    --tag)       DO_TAG=true; shift ;;
    --repo-root) need_val "$@"; REPO_ROOT="$2"; shift 2 ;;
    # An unrecognised option exits 2; a surplus positional exits 1 (issue-creation.md § 3).
    -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done
# THE SAME REFUSAL AS archive.sh: two sibling sweeps must not disagree about this pair.
if [ "$SAW_APPLY" = true ] && [ "$SAW_DRY" = true ]; then
  {
    echo "Error: --apply and --dry-run are contradictory — refusing rather than guessing which you meant."
    echo "       --apply rewrites progress.md and the chunk index; --dry-run previews and changes nothing."
    echo "       Run one of them. The bare form (no flag) is the preview."
    echo "       NOTHING WAS CHANGED."
  } >&2
  exit 2
fi

[ -n "$MILESTONE" ] || { echo "Error: --milestone <name> is required." >&2; exit 1; }

# EXACTLY ONE KNIFE PER RUN. Both is a caller who has named two different cuts
# and cannot be given both; neither leaves nothing to cut by.
if [ -n "$BEFORE" ] && [ -n "$KEEP_LAST" ]; then
  echo "Error: --before and --keep-last are two different cuts; pass exactly one." >&2
  exit 1
fi
if [ -z "$BEFORE" ] && [ -z "$KEEP_LAST" ]; then
  {
    echo "Error: no cut given. Pass exactly one of:"
    echo "  --keep-last <N>          keep the newest N entries, rotate everything older"
    echo "  --before <YYYY-MM-DD>    rotate entries dated before that day"
    echo ""
    echo "PREFER --keep-last WHEN THE TRIGGER IS A SIZE. The board's log-size threshold is"
    echo "measured in BYTES and can be crossed more than once in a day; a date can only cut"
    echo "on a day boundary, so a second rotation on the same day has no expressible cut and"
    echo "reports 'nothing to archive' while the file is still over. --keep-last cuts at an"
    echo "ENTRY boundary, so it can be run again the same day and cuts further each time."
  } >&2
  exit 1
fi

if [ -n "$BEFORE" ]; then
  # Validate date format (strict regex, not full calendar validation)
  if ! echo "$BEFORE" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    echo "Error: --before must be YYYY-MM-DD (got: $BEFORE)" >&2
    exit 1
  fi
fi

if [ -n "$KEEP_LAST" ]; then
  if ! echo "$KEEP_LAST" | grep -qE '^[0-9]+$'; then
    echo "Error: --keep-last must be a non-negative integer (got: $KEEP_LAST)" >&2
    exit 1
  fi
fi

# Resolve repo root
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

PROGRESS="$REPO_ROOT/progress.md"
HISTORY_DIR="$REPO_ROOT/progress/history"
CHUNK="$HISTORY_DIR/$MILESTONE.md"

INDEX="$HISTORY_DIR/INDEX.md"

[ -f "$PROGRESS" ]    || { echo "Error: $PROGRESS does not exist." >&2; exit 1; }
[ -d "$HISTORY_DIR" ] || { echo "Error: $HISTORY_DIR does not exist." >&2; exit 1; }
# § Log's heading is declared once, in lib/lived-probe.sh. Loaded here, before any write.
# shellcheck source=lib/lived-probe.sh
{ [ -f "$SCRIPT_DIR/lib/lived-probe.sh" ] && . "$SCRIPT_DIR/lib/lived-probe.sh" && [ -n "${KIT_LOG_HEADING_ERE:-}" ]; } \
  || { echo "Error: scripts/lib/lived-probe.sh is missing or declares no KIT_LOG_HEADING_ERE — it declares the '## Log' heading this script splits on. Nothing was written." >&2; exit 1; }
# A MISSING INDEX (archive-sweep.md § 3: a new empty index reads as "nothing was ever
# archived"). Chunks present -> REFUSE: the rows carry spans only the adopter can supply.
# No chunks -> CREATE, loudly: the empty index is then true, and an unconditional refusal
# would fire on the first rotation after an upgrade.
if [ ! -f "$INDEX" ]; then
  EXISTING_CHUNKS="$(find "$HISTORY_DIR" -maxdepth 1 -type f -name '*.md' ! -name 'INDEX.md' 2>/dev/null | sort)"
  if [ -n "$EXISTING_CHUNKS" ]; then
    {
      echo "Error: ${INDEX#"$REPO_ROOT"/} is missing, and this directory already holds rotated chunks:"
      printf '%s\n' "$EXISTING_CHUNKS" | sed "s|^$HISTORY_DIR/|    |"
      echo "  An index created now would show ZERO rows, which reads as 'nothing was ever"
      echo "  archived' — false, and the chunks above are the proof. This tool will not write"
      echo "  that claim for you (archive-sweep.md § 3)."
      echo "  Backfill it by hand: create the file with the header row"
      echo "    | Chunk | Covers | Entries | Rotated | Cut |"
      echo "    |---|---|---|---|---|"
      echo "  and one row per chunk above — the date spans are inside each chunk. Then re-run."
    } >&2
    exit 1
  fi
  # No chunks: an empty index is the truth. Create it and SAY SO — but not during a dry run,
  # whose summary says nothing was changed. The refusal above stays in both modes.
  if [ "$DRY_RUN" = "true" ]; then
    echo "Note: ${INDEX#"$REPO_ROOT"/} is absent. --apply would create it with only a header" >&2
    echo "      (no chunk exists yet, so an empty index is true). NOT creating it now." >&2
  else
  {
    echo "<!-- Rotation index. Created by archive-progress.sh because it was absent and no"
    echo "     rotated chunk existed yet, so an empty index was simply true. Rows are"
    echo "     appended DIRECTLY BELOW the header row, newest first; no row is ever"
    echo "     rewritten. Contract: process/contracts/archive-sweep.md § 2. -->"
    echo "# \`progress/history/\` — the rotation index"
    echo ""
    echo "One row per rotated chunk. The \`Covers\` column is the hook that lets a reader pick a"
    echo "chunk without opening it — read this file, never \`ls\`."
    echo ""
    echo '| Chunk | Covers | Entries | Rotated | Cut |'
    echo '|---|---|---|---|---|'
  } > "$INDEX"
  echo "Note: created ${INDEX#"$REPO_ROOT"/} (it was absent and no chunk existed, so an empty index was true)." >&2
  fi
fi

# Split entries: write pre-cutoff to PRE_TMP, post-cutoff to POST_TMP,
# preamble (everything before "## Log") to PREAMBLE_TMP.
PREAMBLE_TMP=$(mktemp)
PRE_TMP=$(mktemp)
POST_TMP=$(mktemp)
TAIL_TMP=$(mktemp)
trap 'rm -f "$PREAMBLE_TMP" "$PRE_TMP" "$POST_TMP" "$TAIL_TMP"' EXIT

# § Log runs from its heading to the next "## " heading that is not a "## YYYY-MM-DD" entry;
# everything from that heading on is TAIL_TMP, kept in place. Every reader below uses both.
LOG_RE="$KIT_LOG_HEADING_ERE"

# ORDINAL MODE: convert --keep-last <N> into "the first CUT_AFTER boundaries are
# pre, the rest are post". The total is counted from the file with the SAME three
# boundary arms the awk uses, so the two cannot disagree about what a boundary is.
CUT_AFTER=-1
if [ -n "$KEEP_LAST" ]; then
  TOTAL_ENTRIES=$(awk -v log_re="$LOG_RE" '
    $0 ~ log_re && !in_log { in_log = 1; next }
    in_log != 1 { next }
    /^##[[:space:]]/ && !/^## [0-9]{4}-[0-9]{2}-[0-9]{2}/ { exit }
    /^## [0-9]{4}-[0-9]{2}-[0-9]{2}/ { n++; dh = 1; next }
    /^### [0-9]{4}-[0-9]{2}-[0-9]{2}/ && !dh { n++; next }
    /^(- )?[0-9]{4}-[0-9]{2}-[0-9]{2} / && !dh { n++; next }
    END { print n + 0 }
  ' "$PROGRESS")
  CUT_AFTER=$(( TOTAL_ENTRIES - KEEP_LAST ))
  [ "$CUT_AFTER" -lt 0 ] && CUT_AFTER=0
  echo "Log holds $TOTAL_ENTRIES entr(ies); keeping the newest $KEEP_LAST, rotating the oldest $CUT_AFTER."
fi

awk -v before="$BEFORE" \
    -v log_re="$LOG_RE" \
    -v cut_after="$CUT_AFTER" \
    -v preamble_file="$PREAMBLE_TMP" \
    -v pre_file="$PRE_TMP" \
    -v post_file="$POST_TMP" \
    -v tail_file="$TAIL_TMP" '
  BEGIN { in_log = 0; bucket = ""; dh_active = 0; ord = 0 }

  # ONE DECISION POINT FOR BOTH KNIVES, called from all three boundary arms, so
  # the two selectors cannot drift apart in how they bucket a line. cut_after < 0
  # means date mode (--before); cut_after >= 0 means ordinal mode (--keep-last),
  # where the first cut_after boundaries rotate and the rest are retained.
  function decide(d) {
    if (cut_after >= 0) { ord++; return (ord <= cut_after) ? "pre" : "post" }
    return (d < before) ? "pre" : "post"
  }

  # Preamble: everything before the "## Log" heading (inclusive of "## Log" itself)
  in_log == 0 {
    print > preamble_file
    if ($0 ~ log_re) {
      in_log = 1
    }
    next
  }

  # After § Log: the first "## " heading that is not a dated entry, and all that follows.
  in_log == 1 && /^##[[:space:]]/ && !/^## [0-9]{4}-[0-9]{2}-[0-9]{2}/ { in_log = 2 }
  in_log == 2 { print > tail_file; next }

  # Inside the Log section. THREE entry-boundary forms, most senior first (the
  # header block describes them):
  #   1. "## YYYY-MM-DD ..." carries its WHOLE section, up to the next "## "
  #      heading; sets dh_active=1 so forms 2/3 know they are nested and must
  #      NOT re-bucket the tail of the section.
  #   2. "### YYYY-MM-DD ..." and 3. a bare/bulleted date line are boundaries
  #      only when not nested under an active "## " section (!dh_active).
  #   NOTE: no apostrophes anywhere inside this awk program — it is delimited
  #   by single quotes, so one comment apostrophe ends the program mid-flight.
  /^## [0-9]{4}-[0-9]{2}-[0-9]{2}/ {
    match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/); date = substr($0, RSTART, 10)
    bucket = decide(date)
    dh_active = 1
  }
  /^### [0-9]{4}-[0-9]{2}-[0-9]{2}/ && !dh_active {
    match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/); date = substr($0, RSTART, 10)
    bucket = decide(date)
  }
  /^(- )?[0-9]{4}-[0-9]{2}-[0-9]{2} / && !dh_active {
    match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/); date = substr($0, RSTART, 10)
    bucket = decide(date)
  }

  {
    # Fail-safe: NEVER drop a Log line (byte-complete pure move). Anything
    # explicitly after the cutoff goes to the retained (post) bucket; everything
    # else — including undated lines before the first entry — goes to pre, which
    # keeps preamble+pre+post+tail a byte-exact reconstruction of the original.
    if (bucket == "post") print > post_file
    else                  print > pre_file
  }
' "$PROGRESS"

# Count pre-cutoff entries: boundary-shaped LINES in the pre bucket, with the SAME three arms
# as the awk above ("## " and "### " need no trailing space; the bullet arm does). A "### DATE"
# nested under a "## DATE" is counted too — it is physically in the pre bucket.
PRE_COUNT=$(grep -cE '^## [0-9]{4}-[0-9]{2}-[0-9]{2}|^### [0-9]{4}-[0-9]{2}-[0-9]{2}|^(- )?[0-9]{4}-[0-9]{2}-[0-9]{2} ' "$PRE_TMP" || true)

# Idempotency: after a clean rotation, no entries match the cutoff → no-op
# (checked BEFORE the chunk-exists guard, so a re-run does not error on the existing file)
if [ "$PRE_COUNT" = "0" ]; then
  # "NOTHING MATCHED MY SELECTOR" IS NOT "NOTHING IS DUE": over the board's threshold a clean
  # "nothing to archive" would be a false all-clear. The threshold is DERIVED from the board
  # checker, never re-declared here (lookup-tables.md § A.1).
  _cb="$(dirname "${BASH_SOURCE[0]}")/check-board.sh"
  THRESH="$(sed -n 's/^PROGRESS_LOG_BYTE_THRESHOLD=\([0-9]*\).*/\1/p' "$_cb" 2>/dev/null | head -1)"
  # § Log as the board slices it: to the next `## ` heading, in bytes (check-board.sh arm c).
  LOGBYTES="$(awk -v log_re="$LOG_RE" '/^##[[:space:]]/ { if (f) exit; if ($0 ~ log_re) f=1 } f { print }' "$PROGRESS" | wc -c | tr -d ' ')"

  # "Nothing to archive" is printed only under the threshold, so a reader grepping for the
  # green phrase never finds it on a run where a rotation was due.
  if [ -n "$THRESH" ] && [ "$LOGBYTES" -gt "$THRESH" ]; then
    {
      if [ -n "$BEFORE" ]; then
        echo "Nothing matched: no entries dated before $BEFORE."
      else
        echo "Nothing matched: the log holds $KEEP_LAST or fewer entries, so keeping the newest $KEEP_LAST rotates none."
      fi
      echo ""
      echo "AND A ROTATION IS STILL DUE, so this run did NOT do what you ran it for."
      echo "  § Log measures $LOGBYTES bytes against the board's threshold of $THRESH."
      echo "  Nothing matched the cut you gave — that is a statement about YOUR SELECTOR,"
      echo "  not about the log. Do not read this exit as an all-clear."
      if [ -n "$BEFORE" ]; then
        echo "  A date can only cut on a day boundary. If today's entries alone put the log"
        echo "  over, --before cannot express the cut. Use --keep-last <N> instead, which"
        echo "  cuts at an ENTRY boundary and can be run again the same day."
      else
        echo "  Lower --keep-last until it cuts, or split by milestone."
      fi
    } >&2
    exit 3
  fi

  # Genuinely nothing due (archive-sweep.md § 3 — "nothing to do is not an error").
  if [ -n "$BEFORE" ]; then
    echo "Nothing to archive: no entries before $BEFORE."
  else
    echo "Nothing to archive: keeping the newest $KEEP_LAST rotates none of the log's $TOTAL_ENTRIES entr(ies)."
  fi
  if [ -n "$THRESH" ]; then
    echo "  (§ Log is $LOGBYTES / $THRESH bytes — under threshold. Nothing is due.)"
  else
    # Name the blind spot (instruments.md § A.4): without the threshold this cannot tell
    # "nothing due" from "cannot tell".
    echo "  (could not read the board's log threshold from ${_cb##*/} — 'nothing is due' is UNVERIFIED)"
  fi
  exit 0
fi

# Refuse to overwrite an existing non-empty chunk.
if [ -s "$CHUNK" ]; then
  echo "Error: $CHUNK already exists and is non-empty." >&2
  echo "Choose another --milestone name, or delete the existing chunk first." >&2
  exit 1
fi

# Name the cut that was actually used.
if [ -n "$BEFORE" ]; then
  echo "Found $PRE_COUNT entries dated before $BEFORE."
else
  echo "Found $PRE_COUNT entries to rotate (keeping the newest $KEEP_LAST)."
fi
echo "Would write to: ${CHUNK#"$REPO_ROOT"/}"
echo ""
echo "First 3 archivable entries:"
# awk (not `grep ... | head -3`) so grep never takes a SIGPIPE, which under
# `set -o pipefail` would abort the script (rc 141) before the chunk is written.
grep -E '^## [0-9]{4}-[0-9]{2}-[0-9]{2}|^### [0-9]{4}-[0-9]{2}-[0-9]{2}|^(- )?[0-9]{4}-[0-9]{2}-[0-9]{2} ' "$PRE_TMP" | awk 'NR<=3 { print "  " $0 }'
echo ""

IDX_HEADER='| Chunk | Covers | Entries | Rotated | Cut |'
IDX_SEP='|---|---|---|---|---|'

# THE INSERTION POINT IS TWO LINES: the insert prints the header, then reprints the NEXT line
# as the separator. If that line is not a separator, the first data row is consumed and the
# new row lands second, breaking newest-first order. So check well-formedness, not presence
# (instruments.md § A.6). The separator is matched by SHAPE (any GFM separator), not bytes.
# Checked BEFORE any write, so a refusal leaves the log and the chunk as they were. A dry run
# with no index skips it: --apply creates one with this header.
if [ -f "$INDEX" ]; then
  _idx_hdr_line="$(grep -nF -m1 "$IDX_HEADER" "$INDEX" | cut -d: -f1 || true)"
  if [ -z "$_idx_hdr_line" ]; then
    # REFUSE rather than append at a guess: the one document that must stay ordered
    # is the one an append-at-a-guess corrupts (archive-sweep.md § 3).
    {
      echo ""
      echo "Error: ${INDEX#"$REPO_ROOT"/} has no recognisable insertion point."
      echo "  Expected a table whose header row is exactly:"
      echo "    $IDX_HEADER"
      echo "  Nothing was written. Add these two lines, then re-run:"
      echo "    $IDX_HEADER"
      echo "    $IDX_SEP"
    } >&2
    exit 1
  fi
  _idx_next="$(sed -n "$((_idx_hdr_line + 1))p" "$INDEX")"
  if ! printf '%s' "$_idx_next" | grep -qE '^[[:space:]]*\|[-:| [:space:]]*-[-:| [:space:]]*\|[[:space:]]*$'; then
    # REFUSE, AND DO NOT REPAIR: this file is the adopter's record, and inserting the separator
    # would be the tool rewriting it to suit itself.
    {
      echo ""
      echo "Error: ${INDEX#"$REPO_ROOT"/} is MALFORMED — the header row is not followed by a separator."
      echo "  Line $((_idx_hdr_line + 1)) is:"
      echo "    ${_idx_next:-(empty)}"
      echo "  A markdown table's header owes a separator on the very next line, and this"
      echo "  insert reads that line and reprints it. Without one, YOUR FIRST DATA ROW"
      echo "  would be consumed into the separator's place and the new row would land"
      echo "  second — breaking the newest-first order this index exists to give you."
      echo "  The file must open its table with exactly these two lines:"
      echo "    $IDX_HEADER"
      echo "    $IDX_SEP"
      echo "  Nothing was written. This tool will not insert the separator for you: this"
      echo "  file is your record, and a tool that quietly rewrites it to suit itself is"
      echo "  how an index comes to state things nobody put there. Fix the two lines, then re-run."
    } >&2
    exit 1
  fi
fi

if [ "$DRY_RUN" = "true" ]; then
  echo "(dry run — no changes made. Re-run with --apply to rewrite the files.)"
  exit 0
fi

# --apply path

# THE CUT'S IDENTITY, in whichever mode is active: --keep-last sets no $BEFORE, so it gets a
# timestamped id (for a distinct revert-safety tag) and a cutoff field that says so.
if [ -n "$KEEP_LAST" ]; then
  # UTC: an INSTANT that must not repeat across a DST change, or the tag would collide.
  CUT_ID="keep-last-${KEEP_LAST}-$(date -u +%Y%m%dT%H%M%SZ)"
  CUT_FIELD="none (kept the newest ${KEEP_LAST} entries)"
else
  CUT_ID="$BEFORE"
  CUT_FIELD="$BEFORE"
fi

if [ "$DO_TAG" = "true" ]; then
  TAG_NAME="progress-rotation-$CUT_ID"
  if git -C "$REPO_ROOT" rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    echo "Warning: tag $TAG_NAME already exists; skipping tag." >&2
  else
    git -C "$REPO_ROOT" tag "$TAG_NAME"
    echo "Tagged: $TAG_NAME"
  fi
fi

# Write the chunk: header + pre entries (exact original content)
{
  echo "---"
  # UTC with an explicit Z: an INSTANT. The Rotated column below is a local calendar DAY.
  echo "archived_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "cutoff: $CUT_FIELD"
  echo "source: progress.md"
  echo "---"
  echo ""
  cat "$PRE_TMP"
} > "$CHUNK"

# Rewrite progress.md: preamble + post entries + whatever followed § Log
cat "$PREAMBLE_TMP" "$POST_TMP" "$TAIL_TMP" > "$PROGRESS"

# INDEX THE CHUNK (the running log rotates on the same preserve-and-index rules as the board
# sweep; lookup-tables.md § A.6). The span is DERIVED from the chunk's own content, not from
# the selector: --keep-last has no date, and --before's date is not the newest entry held.
SPAN_FIRST="$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$PRE_TMP" | sort | head -1 || true)"
SPAN_LAST="$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$PRE_TMP" | sort | tail -1 || true)"
[ -n "$SPAN_FIRST" ] || SPAN_FIRST="(undated)"
[ -n "$SPAN_LAST" ]  || SPAN_LAST="(undated)"
if [ -n "$KEEP_LAST" ]; then CUT_DESC="\`--keep-last $KEEP_LAST\`"; else CUT_DESC="\`--before $BEFORE\`"; fi
# The Rotated column is a CALENDAR DAY, local like every other day this board writes, so it
# shares a clock with SPAN_FIRST/SPAN_LAST (grepped from locally-stamped entries).
IDX_ROW="| [\`$MILESTONE.md\`]($MILESTONE.md) | $SPAN_FIRST → $SPAN_LAST | $PRE_COUNT | $(date +%Y-%m-%d) | $CUT_DESC |"

# Append DIRECTLY BELOW the header row, newest first, rewriting no existing row.
awk -v hdr="$IDX_HEADER" -v row="$IDX_ROW" '
  { print }
  index($0, hdr) == 1 && !done { getline sep; print sep; print row; done = 1 }
' "$INDEX" > "$INDEX.tmp" && mv "$INDEX.tmp" "$INDEX"

echo ""
echo "Done. Wrote:"
echo "  - ${CHUNK#"$REPO_ROOT"/} ($PRE_COUNT entries)"
echo "  - ${PROGRESS#"$REPO_ROOT"/} (rewritten — pre-cutoff entries removed)"
echo ""
echo "Review with: git status; git diff progress.md; cat ${CHUNK#"$REPO_ROOT"/}"
echo "Then commit manually."
