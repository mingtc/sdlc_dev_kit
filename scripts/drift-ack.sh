#!/usr/bin/env bash
# KIT-CLASS: KIT — acknowledge one commit of the drift window; the only writer of progress/drift-acknowledged.tsv. See process/EXTRACTION.md.
# Record that a commit scripts/check-board.sh reports in [e] (no [Role] prefix) or [h] (a generated
# trailer) cannot be put right, and why. The commit is then LISTED by those arms with its role, date and
# reason, and NOT COUNTED, so the board-drift verdict can read clean while it stays on show.
# Published history is never rewritten: this is the recorded way out. It covers two cases with one record:
# a commit that bypassed a rule, and a commit the rule never reached (a branch begun before the kit was
# adopted, or a clone whose commit hook was not wired). Say which in the reason.
#
# Usage:
#   ./scripts/drift-ack.sh <sha> --role <R> --reason "<why this commit stays as it is>" [--rev <rev>]
#
#   <R> = @ROLE_SET@
#
#   <sha>      A commit the report names (any length from 7 hex digits). It must lie in the drift
#              window of <rev>: every commit after the one that added scripts/githooks/commit-msg,
#              else the last commits the report names.
#   --role     The seat acknowledging it, one of <R>.
#   --reason   One line, not empty. What happened, and why no rewrite will follow.
#   --rev      The history the window is read from (default: the remote's trunk, which is what the
#              report reads, or HEAD when there is no such ref).
#
# What it will NOT do (exit 1, refusal, nothing changed; each says its Next:):
#   - acknowledge a commit outside the window, an unknown or malformed sha, or one already acknowledged;
#   - accept a reason that is missing, empty or spans lines, or a role the project does not declare;
#   - run while progress/drift-acknowledged.tsv holds uncommitted changes in your checkout.
#
# THE ROW lands on the trunk through scripts/register-commit.sh, as `[<R>] drift-ack: <12 hex>`, in a
# commit that appends that one row to that one file. Any other commit that touches the file is itself a
# finding of the report ([e2]), so write it with this script, never by hand. Your checkout's copy of
# the file is restored to what it was.
#
# Example:
#   ./scripts/drift-ack.sh 9d4d3261 --role PM --reason "branch begun before the kit was adopted; merged unrewritten"
#   The `--role` value above IS AN EXAMPLE VALUE: this tree accepts the set rendered at `<R> =`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/refuse.sh
. "$SCRIPT_DIR/lib/refuse.sh"
# shellcheck source=lib/usage.sh
. "$SCRIPT_DIR/lib/usage.sh"
# shellcheck source=lib/role-set.sh
[ -r "$SCRIPT_DIR/lib/role-set.sh" ] && . "$SCRIPT_DIR/lib/role-set.sh"   # absent: --help names the seam; register-commit.sh still checks the role
# shellcheck source=lib/drift-window.sh
. "$SCRIPT_DIR/lib/drift-window.sh"
# shellcheck source=lib/kanban-worktree.sh
. "$SCRIPT_DIR/lib/kanban-worktree.sh"

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

SHA=""; ROLE=""; REASON=""; REASON_GIVEN=""; REV=""
# need_val — byte-identical to every other script's copy (process/EXTRACTION.md § 2.4-adjacent).
need_val() {
  [ "$#" -ge 2 ] || { echo "Error: $1 requires a value." >&2; exit 2; }
}
while [ $# -gt 0 ]; do
  case "$1" in
    --role) need_val "$@"; ROLE="$2"; shift 2 ;;
    --reason) need_val "$@"; REASON="$2"; REASON_GIVEN=1; shift 2 ;;
    --rev) need_val "$@"; REV="$2"; shift 2 ;;
    -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) [ -z "$SHA" ] || { echo "Error: one <sha> only (got '$SHA' and '$1')." >&2; usage >&2; exit 2; }
       SHA="$1"; shift ;;
  esac
done
[ -n "$SHA" ] || { echo "Error: a <sha> is required." >&2; usage >&2; exit 2; }
[ -n "$ROLE" ] || { echo "Error: --role is required." >&2; usage >&2; exit 2; }

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || kit_refuse 1 not-in-git-repository \
  "Error: not inside a git repository." \
  "Next: cd into the project's checkout, then re-run."

# THE REASON is the record's point: one line, not empty, no tab (the file's column separator).
case "$REASON" in
  *[[:cntrl:]]*)
    kit_refuse 1 drift-ack-reason-malformed \
      "Error: --reason holds a control character (a tab or a line break), and the record is one tab-separated line per commit. Nothing was changed." \
      "Next: re-run with --reason \"<one line saying why this commit stays as it is>\"." ;;
esac
if [ -z "$(printf '%s' "$REASON" | tr -d '[:space:]')" ]; then
  _rs=missing; [ -z "$REASON_GIVEN" ] || _rs=empty
  kit_refuse 1 drift-ack-reason-missing \
    "Error: --reason is $_rs; a commit is acknowledged with the reason it stays, never silently. Nothing was changed." \
    "Next: re-run with --reason \"<one line saying why this commit stays as it is>\" — what happened, and why no rewrite will follow."
fi

ROLE_SET=""
! command -v kit_role_set >/dev/null 2>&1 || ROLE_SET="$(kit_role_set "$ROOT" 2>/dev/null || true)"
if [ -n "$ROLE_SET" ] && ! kit_role_member "$ROLE_SET" "$ROLE"; then
  kit_refuse 1 drift-ack-role-not-declared \
    "Error: --role must be one of this project's declared roles ($ROLE_SET); '$ROLE' is not. Nothing was changed." \
    "Next: re-run with --role set to one of: $ROLE_SET."
fi

case "$SHA" in
  *[!0-9a-fA-F]*|?|??|???|????|?????|??????)
    kit_refuse 1 drift-ack-sha-malformed \
      "Error: '$SHA' is not a commit sha of at least 7 hex digits. Nothing was changed." \
      "Next: copy the sha from the finding ./scripts/check-board.sh printed ([e] or [h]) and re-run." ;;
esac
# THE TRUNK AND ITS REMOTE are what the report reads and what the row lands on.
kwt_resolve
git -C "$ROOT" fetch -q "$KWT_REMOTE" "$DEFAULT_BRANCH" >/dev/null 2>&1 || true
BASE_REF="$KWT_REMOTE/$DEFAULT_BRANCH"
git -C "$ROOT" rev-parse --verify --quiet "$BASE_REF" >/dev/null 2>&1 || BASE_REF="HEAD"
[ -n "$REV" ] || REV="$BASE_REF"
if ! git -C "$ROOT" rev-parse --verify --quiet "$REV" >/dev/null 2>&1; then
  kit_refuse 1 drift-ack-rev-unknown \
    "Error: --rev '$REV' does not resolve, so there is no window to place the commit in. Nothing was changed." \
    "Next: re-run without --rev (the window is read from the remote's trunk), or name a revision this repository holds."
fi

FULL="$(git -C "$ROOT" rev-parse --verify --quiet "$SHA^{commit}" 2>/dev/null || true)"
if [ -z "$FULL" ]; then
  kit_refuse 1 drift-ack-sha-unknown \
    "Error: '$SHA' names no commit in this repository (or names more than one). Nothing was changed." \
    "Next: fetch the history that holds it (git fetch), or copy a longer sha from the finding ./scripts/check-board.sh printed, then re-run."
fi
# THE WINDOW is the one the report reads: lib/drift-window.sh, never a second derivation.
ROLE_SCAN_N="$(sed -n 's/^ROLE_SCAN_N=\([0-9][0-9]*\).*/\1/p' "$SCRIPT_DIR/check-board.sh" 2>/dev/null | sed -n '1p')"
kit_drift_window "$ROOT" "$REV" "${ROLE_SCAN_N:-20}"
CANDIDATES="$(kit_drift_ack_candidates "$ROOT" "$REV")"
case $'\n'"$CANDIDATES"$'\n' in
  *$'\n'"$FULL"$'\n'*) ;;
  *)
    if [ -n "$KIT_DW_EPOCH" ]; then
      _why="the window of $REV is every commit after ${KIT_DW_EPOCH:0:9}, which added scripts/githooks/commit-msg"
    else
      _why="the window of $REV is its last ${ROLE_SCAN_N:-20} commits (no commit adds scripts/githooks/commit-msg, or this is a shallow clone)"
    fi
    kit_refuse 1 drift-ack-outside-window \
      "Error: ${FULL:0:9} is outside the drift window: $_why. The report does not read it, so nothing needs acknowledging. Nothing was changed." \
      "Next: take the sha from a finding of ./scripts/check-board.sh ([e] or [h]) run on the history you mean, or re-run with --rev set to the revision that report read." ;;
esac

# THE TRUNK'S COPY of the record is the base: the row is appended to what is published, so a row another
# seat landed meanwhile is kept, and the duplicate test reads the file the landing will change.
BASE="$(git -C "$ROOT" show "$BASE_REF:$KIT_DRIFT_ACK_PATH" 2>/dev/null || true)"
HERE="$(git -C "$ROOT" show "$REV:$KIT_DRIFT_ACK_PATH" 2>/dev/null || true)"
for _rows in "$BASE" "$HERE"; do
  _dup="$(awk -F'\t' -v s="$FULL" 'NR > 1 && $1 == s { print; exit }' <<< "$_rows")"
  if [ -n "$_dup" ]; then
    kit_refuse 1 drift-ack-duplicate \
      "Error: ${FULL:0:9} is already acknowledged in $KIT_DRIFT_ACK_PATH: $_dup. Nothing was changed." \
      "Next: nothing to do for that commit; pass the sha of another finding, or re-run ./scripts/check-board.sh to see what is still reported."
  fi
done

DEST="$ROOT/$KIT_DRIFT_ACK_PATH"
if [ -n "$(git -C "$ROOT" status --porcelain -- "$KIT_DRIFT_ACK_PATH" 2>/dev/null)" ]; then
  kit_refuse 1 drift-ack-record-dirty \
    "Error: $KIT_DRIFT_ACK_PATH has uncommitted changes in this checkout, and this script rewrites it from the trunk's copy. Nothing was changed." \
    "Next: discard them (git checkout -- $KIT_DRIFT_ACK_PATH, or delete the file if it is untracked), then re-run; a hand edit stays a finding of the report whatever you do with the file now."
fi

DATE="$(date +%Y-%m-%d)"
mkdir -p "$ROOT/progress"
{
  if [ -n "$BASE" ]; then printf '%s\n' "$BASE"; else printf '%s\n' "$KIT_DRIFT_ACK_HEADER"; fi
  printf '%s\t%s\t%s\t%s\n' "$FULL" "$ROLE" "$DATE" "$REASON"
} > "$DEST"

rc=0
( cd "$ROOT" && "$SCRIPT_DIR/register-commit.sh" --role "$ROLE" --message "drift-ack: ${FULL:0:12}" "$KIT_DRIFT_ACK_PATH" ) || rc=$?

# Your checkout's copy goes back to what this checkout holds: the landing is on the trunk, and a copy left
# modified here would refuse the next fast-forward.
if git -C "$ROOT" cat-file -e "HEAD:$KIT_DRIFT_ACK_PATH" 2>/dev/null; then
  git -C "$ROOT" checkout -q -- "$KIT_DRIFT_ACK_PATH" || true
else
  rm -f "$DEST"
fi

if [ "$rc" -ne 0 ]; then
  echo "drift-ack.sh: register-commit.sh exited $rc; nothing was acknowledged." >&2
  exit "$rc"   # exit-class: internal
fi
echo "Acknowledged ${FULL:0:9} as $ROLE on $DATE: $REASON"
echo "Next: ./scripts/check-board.sh lists it under [e] or [h] as drift-acknowledged and no longer counts it; pull the trunk to see the row in your checkout."
