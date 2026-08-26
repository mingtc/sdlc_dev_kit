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
# Usage:
#   ./scripts/archive-progress.sh --milestone <name> --before <YYYY-MM-DD>          # dry run
#   ./scripts/archive-progress.sh --milestone <name> --before <YYYY-MM-DD> --apply  # rewrite the files
#   ./scripts/archive-progress.sh --milestone <name> --before <YYYY-MM-DD> --apply --tag  # also git-tag for revert safety
#
# The pre-cutoff entries are removed from progress.md and written to
# progress/history/<name>.md with a small YAML header (archived_at,
# cutoff, source). The post-cutoff entries plus the preamble stay in
# progress.md. The script does NOT manage a top-of-file pointer comment
# in progress.md — that's a one-time manual addition; chunks
# are discoverable via `ls progress/history/`.
#
# Entry-boundary forms recognized inside "## Log":
#   * a "## YYYY-MM-DD ..." session heading — the modern top-level form;
#     carries its whole section;
#   * an older "### YYYY-MM-DD ..." section header — carries its whole section
#     the same way, when it is not nested inside a "## " section;
#   * a bare/bulleted "YYYY-MM-DD ..." or "- YYYY-MM-DD ..." line — the oldest,
#     flattest form.
#
# Idempotency: after a clean rotation, re-running with the same --before
# finds no entries to archive and exits 0.
#
# Manual review before commit: this script does NOT `git add`.
# Review with `git status` / `git diff` and stage + commit yourself.

set -euo pipefail

# Defaults
DRY_RUN=true
DO_TAG=false
MILESTONE=""
BEFORE=""
REPO_ROOT=""

usage() {
  local src="${BASH_SOURCE[0]}" first end
  first="$(awk 'NR>2 && !/^#/{print NR; exit}' "$src")"
  end=$(( ${first:-0} - 1 )); [ "$end" -lt 3 ] && end=3
  sed -n "3,${end}p" "$src" | sed 's|^# \{0,1\}||'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --milestone) MILESTONE="$2"; shift 2 ;;
    --before)    BEFORE="$2"; shift 2 ;;
    --apply)     DRY_RUN=false; shift ;;
    --tag)       DO_TAG=true; shift ;;
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    -h|--help)   usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -n "$MILESTONE" ] || { echo "Error: --milestone <name> is required." >&2; exit 1; }
[ -n "$BEFORE" ]    || { echo "Error: --before <YYYY-MM-DD> is required." >&2; exit 1; }

# Validate date format (strict regex, not full calendar validation)
if ! echo "$BEFORE" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
  echo "Error: --before must be YYYY-MM-DD (got: $BEFORE)" >&2
  exit 1
fi

# Resolve repo root
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

PROGRESS="$REPO_ROOT/progress.md"
HISTORY_DIR="$REPO_ROOT/progress/history"
CHUNK="$HISTORY_DIR/$MILESTONE.md"

[ -f "$PROGRESS" ]    || { echo "Error: $PROGRESS does not exist." >&2; exit 1; }
[ -d "$HISTORY_DIR" ] || { echo "Error: $HISTORY_DIR does not exist." >&2; exit 1; }

# Split entries: write pre-cutoff to PRE_TMP, post-cutoff to POST_TMP,
# preamble (everything before "## Log") to PREAMBLE_TMP.
PREAMBLE_TMP=$(mktemp)
PRE_TMP=$(mktemp)
POST_TMP=$(mktemp)
trap 'rm -f "$PREAMBLE_TMP" "$PRE_TMP" "$POST_TMP"' EXIT

awk -v before="$BEFORE" \
    -v preamble_file="$PREAMBLE_TMP" \
    -v pre_file="$PRE_TMP" \
    -v post_file="$POST_TMP" '
  BEGIN { in_log = 0; bucket = ""; dh_active = 0 }

  # Preamble: everything before the "## Log" heading (inclusive of "## Log" itself)
  in_log == 0 {
    print > preamble_file
    if ($0 ~ /^## Log[[:space:]]*$/) {
      in_log = 1
    }
    next
  }

  # Inside the Log section. THREE entry-boundary forms, in NESTING-PRECEDENCE
  # order, most senior first:
  #   1. "## YYYY-MM-DD ..." — the MODERN top-level session heading. It carries
  #      its WHOLE section — every line up to (not including) the next "## "
  #      heading, whatever THAT line looks like — because in real Markdown
  #      nesting a "###" heading (or a bare bullet) appearing after a "##"
  #      heading stays part of that "##" section until another "##" (or
  #      shallower) heading ends it; nothing narrower can. Sets dh_active=1 so
  #      forms 2/3 below know they are nested and must NOT re-bucket the tail of
  #      the section.
  #   2. "### YYYY-MM-DD ..." — the OLDER section-header form. Older entries
  #      are grouped this way, with UNDATED sub-bullets beneath; the header
  #      carries its whole section (the sub-bullets inherit that bucket) —
  #      but ONLY when it is a boundary in its own right, i.e. NOT nested
  #      inside an active "## " section (!dh_active). When nested (e.g. a
  #      same-day QA review filed as "### DATE" under that days own "## DATE"
  #      umbrella) it inherits the bucket of the enclosing section instead.
  #      NOTE: no apostrophes anywhere inside this awk program — it is delimited
  #      by single quotes, so one comment apostrophe ends the program mid-flight.
  #   3. a bare/bulleted date-prefixed line ("YYYY-.." or "- YYYY-.."), the
  #      oldest and flattest form. Same precedence as (2): a boundary only
  #      when not nested under an active "## " section.
  /^## [0-9]{4}-[0-9]{2}-[0-9]{2}/ {
    match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/); date = substr($0, RSTART, 10)
    if (date < before) {
      bucket = "pre"
    } else {
      bucket = "post"
    }
    dh_active = 1
  }
  /^### [0-9]{4}-[0-9]{2}-[0-9]{2}/ && !dh_active {
    match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/); date = substr($0, RSTART, 10)
    if (date < before) {
      bucket = "pre"
    } else {
      bucket = "post"
    }
  }
  /^(- )?[0-9]{4}-[0-9]{2}-[0-9]{2} / && !dh_active {
    match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/); date = substr($0, RSTART, 10)
    if (date < before) {
      bucket = "pre"
    } else {
      bucket = "post"
    }
  }

  {
    # Fail-safe: NEVER drop a Log line (byte-complete pure move). Anything
    # explicitly after the cutoff goes to the retained (post) bucket; everything
    # else — pre-cutoff entries AND any undated lines that precede the first
    # entry (e.g. the blank line right after "## Log") — goes to the pre bucket.
    # Leading undated lines sort at the very front of the log body, ahead of the
    # first archived entry, so routing them to pre keeps preamble+pre+post a
    # byte-exact reconstruction of the original. Routing them to post would
    # reorder them behind the archived entries.
    #
    # This fail-safe is not decoration: the earlier awk had an "intentionally
    # dropped" branch, and every line from just after "## Log" through the first
    # bare-date bullet fell into it — silent data loss on --apply.
    if (bucket == "post") print > post_file
    else                  print > pre_file
  }
' "$PROGRESS"

# Count pre-cutoff entries (number of entry-boundary lines: a "## DATE" session
# heading, a "### DATE" section header, OR a bare/bulleted date-prefixed line).
# The three arms EXACTLY mirror the awk boundary above — the "## " and "### " arms
# have NO trailing-space requirement (a heading whose date is at end-of-line is
# still a boundary), while the bullet arm keeps its trailing space. Anything the
# awk ROUTES into the pre bucket, this counts — including a "### DATE" line nested
# inside a "## DATE" section: the awk does not re-bucket a nested line, but it is
# still a boundary-shaped line physically present in the pre bucket, so counting it
# here is what "no false no-op" needs. This is a literal count of boundary-shaped
# LINES, not of top-level entries.
PRE_COUNT=$(grep -cE '^## [0-9]{4}-[0-9]{2}-[0-9]{2}|^### [0-9]{4}-[0-9]{2}-[0-9]{2}|^(- )?[0-9]{4}-[0-9]{2}-[0-9]{2} ' "$PRE_TMP" || true)

# Idempotency: after a clean rotation, no entries match the cutoff → no-op
# (checked BEFORE the chunk-exists guard so re-running with the same args
# after a complete rotation exits 0 instead of erroring on the existing file)
if [ "$PRE_COUNT" = "0" ]; then
  echo "Nothing to archive: no entries before $BEFORE."
  exit 0
fi

# Refuse to overwrite an existing non-empty chunk.
if [ -s "$CHUNK" ]; then
  echo "Error: $CHUNK already exists and is non-empty." >&2
  echo "Choose another --milestone name, or delete the existing chunk first." >&2
  exit 1
fi

echo "Found $PRE_COUNT entries dated before $BEFORE."
echo "Would write to: ${CHUNK#"$REPO_ROOT"/}"
echo ""
echo "First 3 archivable entries:"
# awk (not `grep ... | head -3`) reads the whole stream, so grep never takes a
# SIGPIPE from head closing early — which under `set -o pipefail` would abort
# the script (rc 141) before the chunk is written.
grep -E '^## [0-9]{4}-[0-9]{2}-[0-9]{2}|^### [0-9]{4}-[0-9]{2}-[0-9]{2}|^(- )?[0-9]{4}-[0-9]{2}-[0-9]{2} ' "$PRE_TMP" | awk 'NR<=3 { print "  " $0 }'
echo ""

if [ "$DRY_RUN" = "true" ]; then
  echo "(dry run — no changes made. Re-run with --apply to rewrite the files.)"
  exit 0
fi

# --apply path

if [ "$DO_TAG" = "true" ]; then
  TAG_NAME="progress-rotation-$BEFORE"
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
  echo "archived_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "cutoff: $BEFORE"
  echo "source: progress.md"
  echo "---"
  echo ""
  cat "$PRE_TMP"
} > "$CHUNK"

# Rewrite progress.md: preamble + post entries
cat "$PREAMBLE_TMP" "$POST_TMP" > "$PROGRESS"

echo ""
echo "Done. Wrote:"
echo "  - ${CHUNK#"$REPO_ROOT"/} ($PRE_COUNT entries)"
echo "  - ${PROGRESS#"$REPO_ROOT"/} (rewritten — pre-cutoff entries removed)"
echo ""
echo "Review with: git status; git diff progress.md; cat ${CHUNK#"$REPO_ROOT"/}"
echo "Then commit manually."
