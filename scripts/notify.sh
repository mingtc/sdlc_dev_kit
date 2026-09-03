#!/usr/bin/env bash
# KIT-CLASS: KIT — transport-agnostic notifier; a no-op unless a backend is set. See process/EXTRACTION.md.
# Outbound notifications — the INTERACTION LAYER (transport-agnostic).
#
# This is the stable API every caller uses. It gates by notification class,
# requires a session slug, builds a normalized message, and dispatches to the
# ONE backend selected by NOTIFY_BACKEND. Swapping chat apps = change
# NOTIFY_BACKEND + add an adapter under scripts/notify/<backend>.sh; callers
# never change.
#
# OFF BY DEFAULT. With NOTIFY_BACKEND unset every send is a silent no-op, so this
# whole subsystem is inert until a project configures it.
#
# Usage:
#   ./scripts/notify.sh <class> <message> --session <slug> [--ref X] [--progress k/N]
#   ./scripts/notify.sh test [--session <slug>]
#
# Classes:  attention | blocked | done | milestone | progress
#   attention = needs your input (gate / permission / approval)
#   blocked   = stopped / escalation / error
#   done      = a run or major task finished
#   milestone = coarse progress (issue merged, branch landed)
#   progress  = fine-grained steps (step 3/99)
# Each class is routed by two environment lists:
#   NOTIFY_WITH_MSG_AND_ALERT = sent AND your phone buzzes (loud)
#   NOTIFY_WITH_MSG_ONLY      = sent silently — lands in the chat, no phone alert
#   in NEITHER list           = not sent at all   (in both → treated as alert)
#
# Config (the project's environment file): NOTIFY_BACKEND, NOTIFY_WITH_MSG_AND_ALERT,
#   NOTIFY_WITH_MSG_ONLY, NOTIFY_ON_SETUP_FAILURE, NOTIFY_PROJECT, + that backend's
#   credentials. The kit reads `.env` at the repo root because that is where a
#   project's secrets already live; that file is the PROJECT's to own and must never
#   be committed (state the variable in your own credential doc).
#
# Delivery is BEST-EFFORT: a failed send NEVER aborts the caller (exit 0), but
# prints a loud "⚠ delivery FAILED" so the calling agent can track it and tell
# the user. `test` is the exception — it exits non-zero on failure, which is the
# mechanism a caller branches on.
#
# NOTHING IN THE KIT BRANCHES ON NOTIFY_ON_SETUP_FAILURE, AND THAT IS THE DESIGN, NOT AN
# OVERSIGHT — but it was stated nowhere, so the knob read as enforced. This comment used to
# say "a session-start check can branch on" it; the shipped `hooks/session-start.sh` does not
# mention NOTIFY at all, so there is no such call site to branch in. The knob DECLARES the
# project's policy and `test`'s exit status carries the fact; the CALLER — an adapter's own
# session-start wiring, or the agent reading the warning — is what acts on the pair. If you
# want the kit itself to halt a session on a failed delivery test, that is a behaviour change
# and it is not this knob's current meaning.
#
# SESSION SLUG: pings fire only when given --session. The human-launched session
# holds its slug in context and passes it; subagents it spawns are NOT given one,
# so their calls no-op — the launching session is the single voice. Two
# concurrent human sessions each pass their own slug and stay distinguishable.

set -uo pipefail   # NOT -e: a failed send must not abort the caller

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"

# Load the environment file (best-effort; comments and blank lines are ignored by
# the shell).
if [ -f "$ROOT/.env" ]; then
  set -a; . "$ROOT/.env"; set +a
fi

NOTIFY_BACKEND="${NOTIFY_BACKEND:-none}"
NOTIFY_WITH_MSG_AND_ALERT="${NOTIFY_WITH_MSG_AND_ALERT:-attention,blocked,done}"
NOTIFY_WITH_MSG_ONLY="${NOTIFY_WITH_MSG_ONLY:-milestone}"
NOTIFY_WITH_MSG_AND_ALERT="${NOTIFY_WITH_MSG_AND_ALERT// /}"   # tolerate "a, b"
NOTIFY_WITH_MSG_ONLY="${NOTIFY_WITH_MSG_ONLY// /}"
NOTIFY_ON_SETUP_FAILURE="${NOTIFY_ON_SETUP_FAILURE:-continue}"

if [ -n "${NOTIFY_PROJECT:-}" ]; then
  PROJECT="$NOTIFY_PROJECT"
else
  PROJECT="$(basename "$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$ROOT")")"
fi

warn() { printf 'notify: %s\n' "$*" >&2; }

CMD="${1:-}"
[ -z "$CMD" ] && { warn "usage: notify.sh <attention|blocked|done|milestone|progress|test> <message> --session <slug>"; exit 2; }
shift || true

case "$CMD" in
  # A USAGE REQUEST IS ALWAYS LEGAL AND ALWAYS SUCCEEDS — issue-creation.md § 3. This
  # arm did not exist, so `notify.sh --help` fell through to the unknown-class refusal
  # and exited 2: asking how to use the tool was itself an error.
  -h|--help)
    echo "usage: notify.sh <attention|blocked|done|milestone|progress|test> <message> --session <slug>"
    echo "       [--ref <ref>] [--progress <n/m>] [--message <text>]"
    echo ""
    echo "  test   probe the configured transport and report; NON-ZERO if it fails."
    echo "  others deliver a notification. Delivery failure is FAIL-SOFT (exit 0) on"
    echo "         purpose: a notification is not the work. An illegal INVOCATION is not."
    exit 0 ;;
  test) MODE=test ;;
  attention|blocked|done|milestone|progress) MODE=send; CLASS="$CMD" ;;
  *) warn "unknown class/command '$CMD' (use: attention|blocked|done|milestone|progress|test)"; exit 2 ;;
esac

MESSAGE=""; SESSION=""; REF=""; PROGRESS=""
# A LEADING '-' IS NEVER A NAME — process/contracts/issue-creation.md § 3's first CLI-SHAPE
# clause, which every creation script enforces and this one did not. Measured before this
# landed: `notify.sh attention --message` consumed `--message` AS THE MESSAGE BODY, sent a
# notification reading "--message", and exited 0. An operator who forgot the value got a
# delivered notification saying nothing, which is worse than a refusal and quieter than one.
if [ "$MODE" = "send" ]; then
  case "${1:-}" in
    -?*) echo "Error: '$1' is not a message — a leading '-' is never a value. Quote it if you meant it literally." >&2
         echo "       Run  $(basename "$0") --help  for the usage." >&2
         exit 2 ;;
  esac
  MESSAGE="${1:-}"; shift || true
fi
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
    --session) need_val "$@"; SESSION="$2"; shift 2 ;;
    --ref) need_val "$@"; REF="$2"; shift 2 ;;
    --progress) need_val "$@"; PROGRESS="$2"; shift 2 ;;
    --message) need_val "$@"; MESSAGE="$2"; shift 2 ;;
    # AN UNRECOGNISED OPTION REFUSES. It used to warn and CARRY ON — so a typo'd flag
    # delivered the message anyway and exited 0, which is a refusal that reads as
    # success. THIS DOES NOT TOUCH THE FAIL-SOFT CONTRACT above: a failed DELIVERY still
    # exits 0 on purpose, because a notification is not the work. That convention is
    # about what happened when the tool RAN; this is about whether the invocation was
    # even legal. Same distinction check-board.sh draws for its informational verdict.
    -*) echo "Error: unknown option: $1" >&2; exit 2 ;;
    *) echo "Error: unknown argument: $1" >&2; exit 2 ;;
  esac
done

ADAPTER="$ROOT/scripts/notify/${NOTIFY_BACKEND}.sh"

# Backend disabled — the single-app latch default.
if [ "$NOTIFY_BACKEND" = "none" ]; then
  if [ "$MODE" = "test" ]; then
    echo "notify: disabled (NOTIFY_BACKEND=none). Notifications are optional — set NOTIFY_BACKEND in your environment file to enable."
  fi
  exit 0   # silent no-op for sends
fi

if [ ! -f "$ADAPTER" ]; then
  avail="$(find "$ROOT/scripts/notify" -maxdepth 1 -name '*.sh' -print0 2>/dev/null | xargs -0 -n1 basename 2>/dev/null | sed 's/\.sh$//' | paste -sd, -)"
  warn "no adapter for NOTIFY_BACKEND='$NOTIFY_BACKEND' (expected scripts/notify/${NOTIFY_BACKEND}.sh). Available: ${avail:-none}"
  [ "$MODE" = "test" ] && exit 1 || exit 0
fi

export NOTIFY_PROJECT_RESOLVED="$PROJECT"
export NOTIFY_SESSION="$SESSION"
export NOTIFY_REF="$REF"   # structural correlation key for a future inbound `poll` verb

if [ "$MODE" = "test" ]; then
  if bash "$ADAPTER" test; then
    echo "notify: ✅ test OK via '$NOTIFY_BACKEND' (project=$PROJECT)"
    exit 0
  else
    rc=$?
    # THE VOCABULARY IS `continue|abort`, matching .env.example — the one spelling an adopter
    # actually types. This line said "stop:" while .env.example said "abort", so the two
    # statements of the legal values disagreed and neither was checked by anything.
    warn "❌ test FAILED via '$NOTIFY_BACKEND' (see DIAGNOSIS above). Policy NOTIFY_ON_SETUP_FAILURE=$NOTIFY_ON_SETUP_FAILURE — abort: halt + tell the user; continue: warn + proceed. Nothing here enforces it; the caller acts on this exit status."
    exit "$rc"
  fi
fi

# --- send ---
# Class routing — alert (loud) wins over msg-only (silent); absent from both → not sent.
case ",$NOTIFY_WITH_MSG_AND_ALERT," in
  *",$CLASS,"*) NOTIFY_SILENT="false" ;;
  *)
    case ",$NOTIFY_WITH_MSG_ONLY," in
      *",$CLASS,"*) NOTIFY_SILENT="true" ;;
      *) exit 0 ;;   # in neither list — silent no-op (not sent)
    esac
    ;;
esac
export NOTIFY_SILENT

# Session required (the subagent guard).
if [ -z "$SESSION" ]; then
  warn "[$CLASS] skipped: no --session slug. Pings fire only from the human-launched session, not subagents."
  exit 0
fi

case "$CLASS" in
  attention) TAG="🔔 attention" ;;
  blocked)   TAG="⛔ blocked" ;;
  done)      TAG="✅ done" ;;
  milestone) TAG="📦 milestone" ;;
  progress)  TAG="⏳ progress" ;;
esac

PREFIX="[$PROJECT · $SESSION]"
[ -n "$PROGRESS" ] && PREFIX="$PREFIX [$PROGRESS]"
[ -n "$REF" ] && MESSAGE="$REF: $MESSAGE"

export NOTIFY_TEXT="$PREFIX $TAG — $MESSAGE"
export NOTIFY_CLASS="$CLASS"

if bash "$ADAPTER" send; then
  exit 0
else
  warn "⚠ delivery FAILED ($NOTIFY_BACKEND) for [$CLASS] — message NOT sent. The run continues; the agent should track this and tell the user. Diagnose with: ./scripts/notify.sh test"
  exit 0   # fail-soft: never abort the caller
fi
