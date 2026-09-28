#!/usr/bin/env bash
# KIT-CLASS: KIT — the ABSENCE half of the liveness ritual. See process/EXTRACTION.md.
# stall.sh — has work stopped moving? Reads the remote's freshest ref and reports.
#
# The liveness rules (process/contracts/liveness-watchdog.md) are not a control on their own:
# a rule that is read, agreed with and scoped out watches nothing. This answers WHO LOOKS.
#
# WHAT IT MEASURES: the NEWEST COMMITTER DATE ACROSS EVERY HEAD ON THE REMOTE — never HEAD,
#   never the checkout. HEAD is one lane; a project can be busy on every other branch.
#
# WHAT IT CANNOT DO:
#   * See unpushed work. A POLICY: the process publishes to the remote, so a leg working past
#     the threshold without pushing is stalled from the process's point of view.
#   * Tell a stall from a deliberate pause. It reports; a person decides.
#   * Detect a GAMED signal (an empty commit, a heartbeat line). `liveness-watchdog.md` § 2:
#     the signal must be a by-product of work, which no program can enforce.
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
#   2  usage error: a missing, bad or unknown argument. Nothing was read.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=../lib/usage.sh
. "$SCRIPT_DIR/../lib/usage.sh"
usage() { kit_usage "${BASH_SOURCE[0]}"; }   # the path is an ARGUMENT — see lib/usage.sh
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

# THE THRESHOLD IS REQUIRED AND HAS NO DEFAULT: it is relative to the run's declared cadence
# (`liveness-watchdog.md` § 2), which this script cannot know.
[ -n "$QUIET_MINUTES" ] \
  || { echo "stall.sh: --quiet-minutes is required and has no default — the threshold belongs to your run's declared cadence, not to this script." >&2; usage >&2; exit 2; }
case "$QUIET_MINUTES" in
  ''|*[!0-9]*) echo "stall.sh: --quiet-minutes must be a whole number of minutes (got '$QUIET_MINUTES')." >&2; exit 2 ;;
esac

# ── THE READ: `git ls-remote`, not a local tracking ref, which is only as fresh as the last
#    fetch. The dates come from the objects, so a fetch is attempted first; a failed read is
#    UNKNOWN, never a stall.
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

# ── INSTRUMENT CHECK: a walk that read no commit date is UNKNOWN, not stalled, and names the
#    refs it could not read.
if [ "$NEWEST" -eq 0 ]; then
  echo "stall.sh: UNKNOWN — '$REMOTE' has heads but no commit date could be read for any of them:$UNREAD. A fetch may have failed, or these refs are not present locally. Reporting unknown rather than stalled, because a walk that measured nothing is not evidence of silence." >&2
  exit 1
fi

NOW="$(date +%s)"
QUIET_SECONDS=$(( QUIET_MINUTES * 60 ))
AGE=$(( NOW - NEWEST ))
AGE_MIN=$(( AGE / 60 ))
HEADS="$(printf '%s\n' "$LS" | grep -c 'refs/heads/' || true)"

# THE SPAN IS PRINTED ON THE CLEARING BRANCH TOO (doctrine/instruments.md § A.4): an
# all-clear with no subject reads as covering everything.
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
