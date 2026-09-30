#!/usr/bin/env bash
# KIT-CLASS: KIT — ad hoc metadata commits, routed the way move-issue.sh routes board moves. See process/EXTRACTION.md.
# Land a hand-made metadata edit — a register entry, a PRD, a dev/ record, an issue body's
# Handoff-to-QA section — on the trunk from WHEREVER your checkout sits, including a linked
# worktree on a branch of its own. It never commits in your checkout.
#
# WHY THIS EXISTS: the code-vs-metadata rule (process/MANUAL.md § The code-vs-metadata rule) is
# mechanical — metadata commits direct to the trunk — but nothing gave a coordinator sitting in a
# linked worktree that is NOT on the trunk ref a way to obey it short of a bare `git commit` on
# the wrong branch. This script is that route: it reads the named paths' CURRENT CONTENT out of
# your checkout, writes that content into the standing kanban worktree (already synced to the
# trunk tip), and commits + pushes there — exactly the machinery move-issue.sh already uses for a
# board move, generalized to any metadata path instead of only progress/.
#
# Usage:
#   ./scripts/register-commit.sh --role <R> --message "..." <path>... [--discard-dirty]
#
#   <R> = @ROLE_SET@
#
#   <path>...   One or more paths, relative to your checkout's root, whose CURRENT ON-DISK
#               CONTENT (tracked or not, staged or not — this reads the working tree, not the
#               index) is what lands. A path absent from your checkout but present on the trunk
#               is taken as a DELETION. Every path must be metadata: this script does not itself
#               check the code-vs-metadata split (your adapter's own list does that); it is the
#               route for the metadata side, not a bypass for the code side.
#
# --discard-dirty   If the kanban worktree holds uncommitted tracked changes (a half-applied
#                    prior op), discard them instead of aborting. Mirrors move-issue.sh's flag;
#                    read its warning before using it — the worktree is shared between lanes.
#
# What it will NOT do:
#   - It will not stop you from calling it for a CODE path — that refusal belongs to the
#     pre-commit hook (scripts/githooks/pre-commit), which catches a bare `git commit` of
#     metadata-only paths off the trunk. This script is the route that refusal names.
#   - It will not invent content: a path that does not exist ANYWHERE (not in your checkout, not
#     on the trunk) is refused rather than silently skipped.
#
# Examples:
#   ./scripts/register-commit.sh --role PM --message "record D-21..D-24 answered in ANSWER-009" \
#     requirements/DECISIONS.md
#   ./scripts/register-commit.sh --role Dev --message "KIT-014: Handoff to QA notes" \
#     progress/dev_complete/KIT-014-slug.md
#
#   The `--role` value above IS AN EXAMPLE VALUE: this tree accepts the set rendered at `<R> =`,
#   from ROLE_PREFIXES in scripts/githooks/commit-msg. Substitute one of yours.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kanban-worktree.sh
. "$SCRIPT_DIR/lib/kanban-worktree.sh"

# --help renders this file's header block; scripts/lib/usage.sh states the window rule.
# shellcheck source=lib/usage.sh
. "$SCRIPT_DIR/lib/usage.sh"

# shellcheck source=lib/role-set.sh
[ -r "$SCRIPT_DIR/lib/role-set.sh" ] && . "$SCRIPT_DIR/lib/role-set.sh"

# ── THE PROGRESS RECORD — OPTIONAL (process/contracts/progress-record.md), same guard shape
#    move-issue.sh uses: absent, every call is a no-op.
# shellcheck source=lib/progress-record.sh
if [ ! -r "$SCRIPT_DIR/lib/progress-record.sh" ] || ! . "$SCRIPT_DIR/lib/progress-record.sh" \
   || ! command -v kit_progress >/dev/null 2>&1; then
  kit_progress() { :; }
fi

usage() {   # the path is an ARGUMENT — see lib/usage.sh
  local roles tok='@ROLE_SET@'
  if command -v kit_role_display >/dev/null 2>&1; then
    roles="$(kit_role_display "$SCRIPT_DIR/.." || true)"
  fi
  [ -n "${roles:-}" ] \
    || roles='as declared in scripts/githooks/commit-msg (ROLE_PREFIXES) — scripts/lib/role-set.sh is absent, so not listed'
  kit_usage "${BASH_SOURCE[0]}" | ROLE_SET_DISPLAY="$roles" awk -v t="$tok" '
    { i = index($0, t)
      if (i) print substr($0, 1, i-1) ENVIRON["ROLE_SET_DISPLAY"] substr($0, i + length(t))
      else   print }'
}

# --help ALWAYS SUCCEEDS, in any position, before any argument is interpreted.
for _a in "$@"; do case "$_a" in -h|--help) usage; exit 0 ;; esac; done

ROLE=""; MSG=""; PATHS=()
# need_val — byte-identical to every other script's copy (process/EXTRACTION.md § 2.4-adjacent).
need_val() {
  [ "$#" -ge 2 ] || { echo "Error: $1 requires a value." >&2; exit 2; }
}

while [ $# -gt 0 ]; do
  case "$1" in
    --role) need_val "$@"; ROLE="$2"; shift 2 ;;
    --message) need_val "$@"; MSG="$2"; shift 2 ;;
    --discard-dirty) KWT_DISCARD_DIRTY=true; shift ;;
    -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) PATHS+=("$1"); shift ;;
  esac
done

[ -n "$MSG" ]  || { echo "Error: --message is required." >&2; usage >&2; exit 2; }
[ ${#PATHS[@]} -gt 0 ] || { echo "Error: at least one <path> is required." >&2; usage >&2; exit 2; }

# Derived by lib/role-set.sh kit_role_resolve; this literal is only its stamped default (see
# there) — SAME SHAPE move-issue.sh uses, validated BEFORE the worktree is touched: an
# unvalidated role would otherwise reach the commit subject and the hook would reject it
# mid-operation, after the kanban worktree already holds the change.
ROLE_SET_DEFAULT='PM|Dev|QA|Refactorer|UIDesigner|Orchestrator|Architect'
if command -v kit_role_resolve >/dev/null 2>&1; then
  kit_role_resolve "$SCRIPT_DIR/.." "$ROLE_SET_DEFAULT"
else
  KIT_ROLE_SET="$ROLE_SET_DEFAULT"
  KIT_ROLE_SRC="THE KIT'S FALLBACK SET — scripts/lib/role-set.sh is absent, so this project's declared set could not be read"
  KIT_ROLE_DEFAULTED=1
fi
[ -z "${KIT_ROLE_DEFAULTED:-}" ] \
  || echo "Note: --role is being checked against $KIT_ROLE_SRC" >&2
if [ -z "$ROLE" ]; then
  echo "Error: --role is required ($KIT_ROLE_SET)." >&2; usage >&2; exit 2
fi
if ! kit_role_member "$KIT_ROLE_SET" "$ROLE"; then
  { echo "Error: --role must be $KIT_ROLE_SET (got '$ROLE')."
    echo "       That set is $KIT_ROLE_SRC."
  } >&2
  exit 1
fi

# Resolve repo root + trunk (works from any worktree, on any branch).
kwt_resolve

# THE CALLER'S ROOT: where the named paths' current content is read FROM. Resolved the same
# way kwt_resolve finds the main root, so this works whether you are in the main checkout, a
# feature worktree, or .kanban-wt itself.
CALLER_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$CALLER_ROOT" ] || { echo "Error: not inside a git repository." >&2; exit 1; }

# Acquire the lock BEFORE touching the worktree (never a half-applied write).
kwt_lock

# Bootstrap (idempotent) + sync the worktree to <remote>/<trunk>, so what we overlay onto it
# lands ON TOP OF the current trunk tip, not some stale snapshot.
kwt_bootstrap
kwt_sync

CHANGED=()
for rel in "${PATHS[@]}"; do
  src="$CALLER_ROOT/$rel"
  dst="$KWT/$rel"
  if [ -e "$src" ]; then
    if [ -f "$dst" ] && cmp -s "$src" "$dst" 2>/dev/null; then
      continue   # identical — nothing to carry for this path
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    git -C "$KWT" add -- "$rel"
    CHANGED+=("$rel")
  else
    # Present on neither side → refuse rather than silently doing nothing for it.
    if [ ! -e "$dst" ]; then
      echo "Error: '$rel' exists in neither your checkout ($CALLER_ROOT) nor the trunk ($KWT) — nothing to commit for it." >&2
      exit 1
    fi
    # Absent from the caller, present on the trunk → a deletion.
    git -C "$KWT" rm -q -- "$rel"
    CHANGED+=("$rel")
  fi
done

if [ ${#CHANGED[@]} -eq 0 ]; then
  echo "Nothing to commit: every named path already matches the trunk's tip." >&2
  echo "  Paths checked: ${PATHS[*]}" >&2
  exit 1
fi

MESSAGE="[${ROLE}] ${MSG}"
git -C "$KWT" commit -m "$MESSAGE" --quiet
SHA=$(git -C "$KWT" rev-parse --short HEAD)
echo "Commit: ${SHA} — made locally in the kanban worktree, NOT yet published."
echo "Paths:  ${CHANGED[*]}"

# paths= must be ONE TOKEN (progress-record.md § Reserved extra keys' "collapsed to one token"
# rule applies to every extra, not only the reserved ones — the record is read back by splitting
# on spaces): comma-joined, never CHANGED[*]'s space-joined form.
_paths_tok="$(IFS=,; echo "${CHANGED[*]}")"
kit_progress "register-commit.sh" status "landed ${#CHANGED[@]} metadata path(s) as ${ROLE}" "paths=${_paths_tok}" >/dev/null 2>&1 || true

# A push failure AFTER the local commit is FATAL, same as move-issue.sh: propagate it rather
# than reporting success on a commit that never reached the remote.
kwt_finalize || exit 1
echo "Published: ${KWT_LANDED_SHA:-<unknown>} on ${DEFAULT_BRANCH} — \"${MESSAGE}\""
