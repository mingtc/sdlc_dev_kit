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
#
# WHICH KNIFE, AND WHY THERE ARE TWO. The signal that a rotation is due is a BYTE
# threshold on § Log, reported by check-board.sh — and bytes can cross it more
# than once in a day.
#   --keep-last <N>        cuts at an ENTRY boundary: keep the newest N, rotate
#                          the rest. Use this when the trigger is a SIZE. It can
#                          be run again the same day and cuts further each time.
#   --before <YYYY-MM-DD>  cuts on a DAY boundary. Right for a milestone close,
#                          and structurally unable to express a same-day second
#                          rotation — everything before today has already gone,
#                          so it reports nothing matched while the file is still
#                          over. That was measured three times before the ordinal
#                          knife existed, and the third run's dry run said
#                          "nothing to archive" on an over-threshold log.
#
# The rotated entries are removed from progress.md and written to
# progress/history/<name>.md with a small YAML header (archived_at, cutoff,
# source). The retained entries plus the preamble stay in progress.md.
#
# EVERY CHUNK GETS AN INDEX ROW in progress/history/INDEX.md — chunk, the span of
# dates it covers, entry count, rotation date, and the cut used. That index is the
# only thing that makes a chunk findable: `ls` gives filenames with no spans, so
# without it locating a date means opening chunks until one matches. The index is
# required, and it is created here ONLY when doing so cannot lie: no chunks present means an
# empty index is TRUE. Where chunks already exist this refuses instead, because a freshly-created
# empty index cannot be told apart from a project that has never rotated. (This line read "never
# created here" while the code below argued the narrower rule and applied it.)
#
# "Nothing matched" is NOT "nothing is due": if the cut you gave rotates nothing
# while § Log is still over the board's threshold, this says so on stderr and
# exits 3, because a clean exit 0 there reads as an all-clear that stops you
# looking.
#
# Entry-boundary forms recognized inside "## Log", the documented one first:
#   * a "### YYYY-MM-DD ..." session heading — THE FORM THE KIT DOCUMENTS. Carries
#     its whole section, undated sub-bullets included, but only when it is a
#     boundary in its own right: nested inside a "## " section it inherits that
#     section's bucket instead.
#   * a "## YYYY-MM-DD ..." session heading — ALSO MATCHED, deliberately, but NOT
#     documented and NOT to be migrated toward. It is the senior form here, carrying
#     every line up to the next "## " heading, which is why the other two forms stop
#     being boundaries underneath it. An earlier version of this comment called it
#     "the modern top-level form" and called "###" older. That was wrong in a way
#     that mattered: check-board.sh's § Log size arm and kit-init.sh's already-lived
#     probe BOTH scan to the next "##" and stop, so a "##" dated entry TERMINATES the
#     § Log section it is supposed to sit inside. Measured: the size arm then reports
#     healthy forever, and the lived probe counts 0 lines and reads a WORKING
#     repository as new — defeating the refusal initializer.md § 3 requires be made
#     "by a rule rather than by the operator's memory". This tool still accepts "##"
#     so that a project which already wrote it is not stranded; accepting a form you
#     no longer document is the forgiving direction.
#   * a bare/bulleted "YYYY-MM-DD ..." or "- YYYY-MM-DD ..." line — the oldest,
#     flattest form. Same nesting rule as "###": a boundary only when not under a
#     "## " section.
#
# Idempotency: after a clean rotation, re-running with the same --before
# finds no entries to archive and exits 0.
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

# SCRIPT_DIR IS INTRODUCED HERE, and this is the largest edit in this change: this
# script had none, deriving its repo root lazily AFTER the argument loop that handles
# --help. The renderer needs a path above that loop, so the resolution moves up. Nothing
# below it changes — the lazy REPO_ROOT resolution is untouched and still authoritative.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/usage.sh
. "$SCRIPT_DIR/lib/usage.sh"

usage() { kit_usage "${BASH_SOURCE[0]}"; }   # the path is an ARGUMENT — see lib/usage.sh
# need_val <all remaining args> — refuse an option whose value was not given.
#
# THE SAME HELPER, THE SAME NAME, AND THE SAME SHAPE AS new-issue.sh / new-bug.sh /
# new-refactor.sh, which already had it. It is repeated per script rather than shared
# because several of these source nothing from scripts/lib/ (release.sh by standing
# ruling), and the self-test holds the copies identical.
#
# WHAT IT REPLACES WAS SILENT AND IT WAS EVERYWHERE ELSE. An arm written
# `--x) VAR="${2:-}"; shift 2 ;;` looks safe — `${2:-}` cannot be unbound. But `shift 2`
# with one argument left RETURNS NON-ZERO, and under `set -e` that aborts the script:
# **exit 1, no message, nothing done.** notify.sh was worse, exiting 0 in silence.
# process/contracts/issue-creation.md § 3 says an illegal invocation exits 2 and NAMES the
# option; a missing value is exactly that family, and it was the shape nobody applied it to.
need_val() {
  [ "$#" -ge 2 ] || { echo "Error: $1 requires a value." >&2; exit 2; }
}


while [ $# -gt 0 ]; do
  case "$1" in
    --milestone) need_val "$@"; MILESTONE="$2"; shift 2 ;;
    --before)    need_val "$@"; BEFORE="$2"; shift 2 ;;
    --keep-last) need_val "$@"; KEEP_LAST="$2"; shift 2 ;;
    --apply)     DRY_RUN=false; SAW_APPLY=true; shift ;;
    # ACCEPTED, THOUGH IT IS ALREADY THE DEFAULT. It used to be refused as an unknown
    # option — the set's only refusal of a word that means "change nothing", and the
    # one an operator arrives with from the two mutators that require it. A tool that
    # can preview accepts the word for previewing; anything else teaches by punishment.
    --dry-run)   DRY_RUN=true; SAW_DRY=true; shift ;;
    --tag)       DO_TAG=true; shift ;;
    --repo-root) need_val "$@"; REPO_ROOT="$2"; shift 2 ;;
    -h|--help)   usage; exit 0 ;;
    # AN UNRECOGNISED OPTION EXITS 2; a surplus POSITIONAL exits 1. Two classes, and the
    # kit already told them apart in every script that has a `-*)` arm — these did not, so a
    # mistyped flag was reported with the status a surplus word gets. Named in
    # process/contracts/issue-creation.md § 3: ONE status across the shipped set.
    -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done
# THE SAME REFUSAL AS archive.sh, WORD FOR WORD IN SUBSTANCE. Two sibling sweeps that
# disagreed about a contradictory pair would recreate this whole class inside its fix.
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
# A MISSING INDEX: REFUSE ONLY WHERE THE REFUSAL IS EARNED.
#
# archive-sweep.md § 3 says do not create an index on the fly, and gives its
# REASON: "a new empty index reads as 'nothing was ever archived'." That reason
# bites exactly when the claim would be FALSE — when chunks already exist and an
# empty index would deny them. It does not bite when the claim would be TRUE.
# And which case you are in is CHECKABLE rather than assumable: look for chunks.
#
# This matters because of the upgrade path, which is a different moment from the
# steady state. A fresh adopter gets the index in the zip. An adopter who UPGRADES
# the script does not — so an unconditional refusal fires on their very first
# rotation, and a tool that refuses on first run after an upgrade is the shape
# that gets quietly replaced with a hand `mv`, which loses the log entirely. That
# trade is worse than the one § 3 was protecting against.
#
#   chunks present, index absent  -> REFUSE. The rows carry spans only the adopter
#                                    can supply; fabricating an index here would
#                                    invent coverage, which is the actual § 3 harm.
#   no chunks, index absent       -> CREATE, loudly. "Nothing was ever archived" is
#                                    then simply true, so the empty index misleads
#                                    nobody.
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
  # No chunks: an empty index is the truth. Create it and SAY SO, because a file
  # appearing without explanation is its own small mystery.
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

# Split entries: write pre-cutoff to PRE_TMP, post-cutoff to POST_TMP,
# preamble (everything before "## Log") to PREAMBLE_TMP.
PREAMBLE_TMP=$(mktemp)
PRE_TMP=$(mktemp)
POST_TMP=$(mktemp)
trap 'rm -f "$PREAMBLE_TMP" "$PRE_TMP" "$POST_TMP"' EXIT

# ORDINAL MODE: convert --keep-last <N> into "the first CUT_AFTER boundaries are
# pre, the rest are post". The total is COUNTED FROM THE FILE, never assumed —
# and it is counted with the SAME three boundary arms the awk uses, so the
# ordinal the awk assigns and the total computed here cannot disagree about what
# a boundary is. (A second, hand-written regex here would be one more derivation
# to get wrong; this one is the same expression as PRE_COUNT's below.)
CUT_AFTER=-1
if [ -n "$KEEP_LAST" ]; then
  TOTAL_ENTRIES=$(awk '
    /^## Log[[:space:]]*$/ { in_log = 1; next }
    in_log != 1 { next }
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
    -v cut_after="$CUT_AFTER" \
    -v preamble_file="$PREAMBLE_TMP" \
    -v pre_file="$PRE_TMP" \
    -v post_file="$POST_TMP" '
  BEGIN { in_log = 0; bucket = ""; dh_active = 0; ord = 0 }

  # ONE DECISION POINT FOR BOTH KNIVES, called from all three boundary arms, so
  # the two selectors cannot drift apart in how they bucket a line. cut_after < 0
  # means date mode (--before); cut_after >= 0 means ordinal mode (--keep-last),
  # where the first cut_after boundaries rotate and the rest are retained.
  #
  # WHY AN ORDINAL KNIFE EXISTS AT ALL: the trigger that says a rotation is due
  # is a BYTE threshold, and bytes can cross it more than once in a day. A date
  # can only cut on a day boundary, so the second rotation of the same day has no
  # expressible cut — it reports nothing to archive while the file is still over.
  # Measured, three times, in a project that then had to hand-edit the log.
  function decide(d) {
    if (cut_after >= 0) { ord++; return (ord <= cut_after) ? "pre" : "post" }
    return (d < before) ? "pre" : "post"
  }

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
  #   1. "## YYYY-MM-DD ..." — ACCEPTED but NOT documented, and not a form to
  #      migrate toward (the header block says why: a "## " dated entry
  #      terminates the Log section that check-board.sh and kit-init.sh scan).
  #      Senior here nonetheless: it carries its WHOLE section — every line up
  #      to (not including) the next "## " heading, whatever THAT line looks
  #      like — because in real Markdown nesting a "###" heading (or a bare
  #      bullet) appearing after a "##" heading stays part of that "##" section
  #      until another "##" (or shallower) heading ends it; nothing narrower
  #      can. Sets dh_active=1 so forms 2/3 below know they are nested and must
  #      NOT re-bucket the tail of the section.
  #   2. "### YYYY-MM-DD ..." — THE FORM THE KIT DOCUMENTS. Entries are grouped
  #      this way, with UNDATED sub-bullets beneath; the header carries its whole
  #      section (the sub-bullets inherit that bucket) — but ONLY when it is a
  #      boundary in its own right, i.e. NOT nested inside an active "## "
  #      section (!dh_active). When nested (e.g. a same-day QA review filed as
  #      "### DATE" under that days own "## DATE" umbrella) it inherits the
  #      bucket of the enclosing section instead.
  #      NOTE: no apostrophes anywhere inside this awk program — it is delimited
  #      by single quotes, so one comment apostrophe ends the program mid-flight.
  #   3. a bare/bulleted date-prefixed line ("YYYY-.." or "- YYYY-.."), the
  #      oldest and flattest form. Same precedence as (2): a boundary only
  #      when not nested under an active "## " section.
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
  # "NOTHING MATCHED MY SELECTOR" IS NOT "NOTHING IS DUE", and reporting the
  # first as the second is the defect this block exists to prevent. A clean exit
  # 0 saying "nothing to archive" reads as "the log is fine" — so when the log is
  # STILL OVER THE BOARD'S THRESHOLD, that same sentence is a false all-clear,
  # and the operator stops looking while the file keeps growing. Two instruments
  # then disagree (the board says a rotation is due; this tool says there is
  # nothing to do) and the one that ACTS is the one reporting success.
  #
  # The threshold is DERIVED from the board checker, never re-declared here:
  # lookup-tables.md § A.1 — "do not mint a second threshold; a project that
  # carries two numbers for one idea will drift them."
  _cb="$(dirname "${BASH_SOURCE[0]}")/check-board.sh"
  THRESH="$(sed -n 's/^PROGRESS_LOG_BYTE_THRESHOLD=\([0-9]*\).*/\1/p' "$_cb" 2>/dev/null | head -1)"
  LOGBYTES="$(awk '/^## Log[[:space:]]*$/{f=1} f{n+=length($0)+1} END{print n+0}' "$PROGRESS")"

  # THE PHRASE "NOTHING TO ARCHIVE" IS RESERVED FOR WHEN IT IS TRUE. Under the
  # threshold, nothing matched AND nothing is due — so it is an honest green and
  # keeps its wording. Over the threshold it would be the false all-clear this
  # block exists to prevent, so that path never prints it at all: a reader
  # grepping for the green phrase must not find it on a run that archived nothing
  # while a rotation was due.
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

  # Genuinely nothing due: the log is under threshold and nothing matched, so the
  # green phrase is earned. Contract archive-sweep.md § 3 — "nothing to do is not
  # an error."
  if [ -n "$BEFORE" ]; then
    echo "Nothing to archive: no entries before $BEFORE."
  else
    echo "Nothing to archive: keeping the newest $KEEP_LAST rotates none of the log's $TOTAL_ENTRIES entr(ies)."
  fi
  if [ -n "$THRESH" ]; then
    echo "  (§ Log is $LOGBYTES / $THRESH bytes — under threshold. Nothing is due.)"
  else
    # NAME THE BLIND SPOT IN THE OUTPUT (instruments.md § A.4): without the
    # threshold this cannot distinguish "nothing due" from "cannot tell", so it
    # says which one it is rather than printing the green half alone.
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

# NAME THE CUT THAT WAS ACTUALLY USED. This line said "dated before $BEFORE"
# unconditionally, which in ordinal mode printed an empty date and described a
# selector the run did not use — the output misreporting its own question, which
# is the read-time defect this whole change is about.
if [ -n "$BEFORE" ]; then
  echo "Found $PRE_COUNT entries dated before $BEFORE."
else
  echo "Found $PRE_COUNT entries to rotate (keeping the newest $KEEP_LAST)."
fi
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

# THE CUT'S IDENTITY, in whichever mode is active. Both of the sites below used
# $BEFORE, which --keep-last never sets: the tag came out literally
# "progress-rotation-" and the chunk header's cutoff field came out empty. Worse than
# cosmetic — a SECOND keep-last rotation hit "tag already exists" and silently skipped
# the revert-safety tag, so the mode with no date was also the mode with no safety net.
# In keep-last mode there is no date cutoff to report, and saying so is the honest
# field; the timestamp is what makes successive rotations distinguishable.
if [ -n "$KEEP_LAST" ]; then
  # UTC, and deliberately: this is an INSTANT, not a calendar day. It discriminates one
  # revert-safety tag from the next, so it must be monotonic — a local clock crossing a DST
  # boundary can hand out the same second twice, and a colliding CUT_ID is the failure the
  # "tag already exists" note below is about. `Z` is written into the value so a reader can
  # see which clock produced it.
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
  # UTC with an explicit Z, and deliberately: an INSTANT, comparable across machines. The
  # Rotated column below is a calendar DAY and is local. That is the rule, not an accident.
  echo "archived_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "cutoff: $CUT_FIELD"
  echo "source: progress.md"
  echo "---"
  echo ""
  cat "$PRE_TMP"
} > "$CHUNK"

# Rewrite progress.md: preamble + post entries
cat "$PREAMBLE_TMP" "$POST_TMP" > "$PROGRESS"

# INDEX THE CHUNK. Preserve-AND-index: the contract's running-log invariant says
# the log rotates "on the same preserve-and-index rules" as the board sweep, and
# rotating without indexing exports the problem instead of solving it
# (lookup-tables.md § A.6). Until this existed the chunks were findable only by
# `ls` — filenames with no spans, so locating a date meant opening them in turn.
#
# The span is DERIVED from the chunk's own content, not from the selector: with
# --keep-last the cut is an ordinal and there is no date in the arguments to copy,
# and with --before the boundary date is not the same as the newest entry the
# chunk actually holds.
SPAN_FIRST="$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$PRE_TMP" | sort | head -1 || true)"
SPAN_LAST="$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$PRE_TMP" | sort | tail -1 || true)"
[ -n "$SPAN_FIRST" ] || SPAN_FIRST="(undated)"
[ -n "$SPAN_LAST" ]  || SPAN_LAST="(undated)"
if [ -n "$KEEP_LAST" ]; then CUT_DESC="\`--keep-last $KEEP_LAST\`"; else CUT_DESC="\`--before $BEFORE\`"; fi
# The Rotated column is a CALENDAR DAY and so it is the operator's local day, like every
# other day this board writes. It was `date -u` and the two cells either side of it were not:
# SPAN_FIRST/SPAN_LAST are grepped out of the chunk's own content, which move-issue.sh and
# subtask.sh stamped locally. One generated row, two clocks, eight hours apart — and the two
# UTC stamps above are a different thing entirely (see their comments): those are INSTANTS.
IDX_ROW="| [\`$MILESTONE.md\`]($MILESTONE.md) | $SPAN_FIRST → $SPAN_LAST | $PRE_COUNT | $(date +%Y-%m-%d) | $CUT_DESC |"

IDX_HEADER='| Chunk | Covers | Entries | Rotated | Cut |'
IDX_SEP='|---|---|---|---|---|'

# THE INSERTION POINT IS TWO LINES, NOT ONE — and checking only the first is what
# the presence-vs-well-formedness defect looks like here. The insert below prints
# the header, then reads THE NEXT LINE and reprints it as the separator. If that
# line is not a separator, the file's FIRST DATA ROW is consumed and reprinted in
# the separator's position and the new row lands SECOND — silently breaking the
# newest-first ordering this index exists to provide. Reproduced from an adopter
# following a recipe that omitted the separator.
#
# `grep -qF` on the header alone ACCEPTED that file. A presence check standing in
# for a well-formedness check is the guard looking slightly to the left of the
# defect (`doctrine/instruments.md` § A.6): the header really was present, and
# present was never the property the insert needed.
#
# THE SEPARATOR IS MATCHED BY SHAPE, NOT BY BYTES. Any GFM separator row — pipes,
# dashes, optional alignment colons, whitespace — is legitimate, and refusing an
# adopter's `| --- | --- |` because it is not our exact spelling would be the
# validator-mismatch rule (§ A.8) in the change that adds a validator.
_idx_hdr_line="$(grep -nF -m1 "$IDX_HEADER" "$INDEX" | cut -d: -f1)"
if [ -z "$_idx_hdr_line" ]; then
  # REFUSE rather than append at a guess: the one document that must stay ordered
  # is the one an append-at-a-guess corrupts (archive-sweep.md § 3).
  {
    echo ""
    echo "Error: ${INDEX#"$REPO_ROOT"/} has no recognisable insertion point."
    echo "  Expected a table whose header row is exactly:"
    echo "    $IDX_HEADER"
    echo "  The chunk and the rewritten log ARE ON DISK; only the index row is missing."
    echo "  Add these two lines, then append this row by hand under them:"
    echo "    $IDX_HEADER"
    echo "    $IDX_SEP"
    echo "    $IDX_ROW"
  } >&2
  exit 1
fi
_idx_next="$(sed -n "$((_idx_hdr_line + 1))p" "$INDEX")"
if ! printf '%s' "$_idx_next" | grep -qE '^[[:space:]]*\|[-:| [:space:]]*-[-:| [:space:]]*\|[[:space:]]*$'; then
  # REFUSE, AND DO NOT REPAIR. The absent-index case refuses rather than writing an
  # index it would have to invent (§ 3); this is that call one level down — an index
  # the tool cannot write correctly is one it must not write at all. Inserting the
  # missing separator "helpfully" would be the tool editing the adopter's own record
  # to suit itself, which is the same defect as fabricating the index: a claim
  # nobody made, in the one file whose value is that its rows are the adopter's.
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
    echo "  how an index comes to state things nobody put there."
    echo "  The chunk and the rewritten log ARE ON DISK; only the index row is missing."
    echo "  Fix the two lines, then append this row by hand under them:"
    echo "    $IDX_ROW"
  } >&2
  exit 1
fi
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
