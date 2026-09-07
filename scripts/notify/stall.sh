#!/usr/bin/env bash
# KIT-CLASS: KIT — the ABSENCE half of the liveness ritual. See process/EXTRACTION.md.
# stall.sh — has work stopped moving? Reads the remote's freshest ref and reports.
#
# THIS EXISTS BECAUSE THE DISCIPLINE ALONE DID NOT WORK, and that is measured rather than
# assumed. process/contracts/liveness-watchdog.md carried the rules for months; a project
# read them honestly, found their scope test was "any run expected to outlast a human's
# attention", had no runs of that length, and declared the whole ritual not applicable.
# The failure that then arrived was not a run hanging — it was work stopping, three times,
# with nobody watching. A sentence that is read, agreed with, and correctly scoped out is
# not a control. This is the smallest program that answers the question the sentence could
# not: WHO LOOKS.
#
# WHAT IT MEASURES, and why not the obvious thing:
#   NEWEST COMMITTER DATE ACROSS EVERY HEAD ON THE REMOTE — never HEAD, never the checkout.
#   `HEAD` is one branch in one worktree, and in a process that moves work between refs
#   constantly it measures one lane of a road. Measured at one instant in a project of
#   exactly this shape: 697 minutes since HEAD moved, 1 minute since anything moved. A
#   monitor keyed on HEAD reported a dead project that was working normally.
#
# WHAT IT CANNOT DO, said here rather than discovered:
#   * It cannot see unpushed work. That is a POLICY, not an oversight — the process
#     publishes to the remote, so a leg working past the threshold without pushing is
#     stalled from the process's point of view. Reading every clone needs access this
#     process does not have.
#   * It cannot tell a stall from a deliberate pause. It reports; a person decides.
#   * It cannot detect a signal being GAMED. An empty commit moves the freshest ref, and so
#     does a heartbeat line in the log. `liveness-watchdog.md` § 2 states the rule — the
#     signal must be a by-product of work — and no program can enforce it.
#
# Usage:
#   ./scripts/notify/stall.sh --quiet-minutes 90            # report; exit 3 if stalled
#   ./scripts/notify/stall.sh --quiet-minutes 90 --notify    # ...and send through notify.sh
#   ./scripts/notify/stall.sh --quiet-minutes 90 --remote upstream
#   ./scripts/notify/stall.sh --help
#
# Exit codes, because a caller needs to branch on them:
#   0  moving   — something on the remote is newer than the threshold
#   3  STALLED  — nothing has moved within the threshold. NOT an error; a finding.
#   1  unknown  — the remote could not be read. Unknown and alive are different answers.
#   2  usage error (bad or unknown argument). Nothing was read.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
usage() {
  local src="${BASH_SOURCE[0]:-$0}" start end
  start="$(awk 'NR<=12 && /EXTRACTION\.md/{print NR+1; exit}' "$src")"
  [ -n "$start" ] || start=3
  end="$(awk -v s="$start" 'NR>=s && !/^#/{print NR-1; exit}' "$src")"
  sed -n "${start},${end:-40}p" "$src" | sed 's|^# \{0,1\}||'
}
case "${1:-}" in -h|--help) usage; exit 0 ;; esac

QUIET_MINUTES=""; REMOTE="${KWT_REMOTE:-origin}"; DO_NOTIFY=false; SESSION="stall-watch"
need_val() { [ "$#" -ge 2 ] || { echo "stall.sh: $1 requires a value." >&2; usage >&2; exit 2; }; }
while [ $# -gt 0 ]; do
  case "$1" in
    --quiet-minutes) need_val "$@"; QUIET_MINUTES="$2"; shift 2 ;;
    --remote)        need_val "$@"; REMOTE="$2"; shift 2 ;;
    --session)       need_val "$@"; SESSION="$2"; shift 2 ;;
    --notify)        DO_NOTIFY=true; shift ;;
    -h|--help)       usage; exit 0 ;;
    *) echo "stall.sh: unknown option '$1'" >&2; usage >&2; exit 2 ;;
  esac
done

# THE THRESHOLD IS REQUIRED AND HAS NO DEFAULT, deliberately. `liveness-watchdog.md` § 2
# says the threshold is relative to the run's DECLARED CADENCE, so a default here would be
# this script inventing a cadence for a project it knows nothing about — and an alarm on a
# borrowed number fires through every night and weekend until somebody mutes it.
[ -n "$QUIET_MINUTES" ] \
  || { echo "stall.sh: --quiet-minutes is required and has no default — the threshold belongs to your run's declared cadence, not to this script." >&2; usage >&2; exit 2; }
case "$QUIET_MINUTES" in
  ''|*[!0-9]*) echo "stall.sh: --quiet-minutes must be a whole number of minutes (got '$QUIET_MINUTES')." >&2; exit 2 ;;
esac

# ── THE READ. `git ls-remote` rather than a local ref: a local tracking ref is only as
#    fresh as the last fetch, so reading it would measure THIS machine's habits and report
#    them as the project's. The refs come back as sha + name; each sha's committer date is
#    then read from the object, which requires it to be present locally — so a fetch is
#    attempted first and its failure is reported as UNKNOWN rather than as a stall.
LS="$(git ls-remote --heads "$REMOTE" 2>&1)" || {
  echo "stall.sh: UNKNOWN — could not read '$REMOTE'. Unknown and alive are different answers, and this is the first: $(printf '%s' "$LS" | tr '\n' ' ' | cut -c1-200)" >&2
  exit 1
}
[ -n "$LS" ] || {
  echo "stall.sh: UNKNOWN — '$REMOTE' reports no heads at all. That is not a stall; it is a remote with nothing on it." >&2
  exit 1
}
git fetch --quiet "$REMOTE" 2>/dev/null || true

NEWEST=0; NEWEST_REF=""; UNREAD=""
while IFS= read -r line; do
  [ -n "$line" ] || continue
  sha="${line%%	*}"; ref="${line#*	}"
  ts="$(git show -s --format=%ct "$sha" 2>/dev/null || true)"
  if [ -z "$ts" ]; then UNREAD="$UNREAD ${ref#refs/heads/}"; continue; fi
  if [ "$ts" -gt "$NEWEST" ]; then NEWEST="$ts"; NEWEST_REF="${ref#refs/heads/}"; fi
done <<EOF
$LS
EOF

# ── INSTRUMENT CHECK: a walk that read no commit date would report "stalled" over nothing,
#    which is the false-alarm that trains a reader to ignore the next one. Unknown, not
#    stalled — and it NAMES the refs it could not read rather than reporting a bare failure.
if [ "$NEWEST" -eq 0 ]; then
  echo "stall.sh: UNKNOWN — '$REMOTE' has heads but no commit date could be read for any of them:$UNREAD. A fetch may have failed, or these refs are not present locally. Reporting unknown rather than stalled, because a walk that measured nothing is not evidence of silence." >&2
  exit 1
fi

NOW="$(date +%s)"
QUIET_SECONDS=$(( QUIET_MINUTES * 60 ))
AGE=$(( NOW - NEWEST ))
AGE_MIN=$(( AGE / 60 ))
HEADS="$(printf '%s\n' "$LS" | grep -c 'refs/heads/' || true)"

# THE SPAN IS PRINTED ON THE CLEARING BRANCH AS WELL AS THE COMPLAINING ONE
# (doctrine/instruments.md § A.4): a clearance with no subject is read as covering whatever
# the reader had in mind, and "moving" with no ref name beside it is exactly that.
SPAN="across $HEADS head(s) on '$REMOTE'; newest is '$NEWEST_REF'"
[ -n "$UNREAD" ] && SPAN="$SPAN; NOT MEASURED — no commit date readable for:$UNREAD"

if [ "$AGE" -gt "$QUIET_SECONDS" ]; then
  MSG="STALLED: nothing has moved on '$REMOTE' for ${AGE_MIN}m (threshold ${QUIET_MINUTES}m) — $SPAN"
  echo "$MSG"
  if [ "$DO_NOTIFY" = true ]; then
    if [ -x "$SCRIPT_DIR/../notify.sh" ]; then
      "$SCRIPT_DIR/../notify.sh" attention "$MSG" --session "$SESSION" || true
    else
      echo "stall.sh: scripts/notify.sh is not executable or not present, so --notify reached nobody. THE FINDING ABOVE STANDS AND WAS NOT DELIVERED." >&2
    fi
  fi
  exit 3
fi

echo "moving: newest commit on '$REMOTE' is ${AGE_MIN}m old (threshold ${QUIET_MINUTES}m) — $SPAN"
exit 0
