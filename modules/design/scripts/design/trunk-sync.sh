#!/usr/bin/env bash
# KIT-CLASS: KIT — the design module's trunk check and push: the Designer's commits reach the trunk with their shas intact. See process/EXTRACTION.md.
# Every tool that reads the trunk reads <remote>/<trunk>, so a Designer commit that only the local trunk holds
# is invisible to the pin gate (a false STALE-APPROVAL or PIN-ORDER). The Designer commits on the trunk and
# publishes it as it is: a fast-forward push, never a rebase and never a re-landing on the remote's tip,
# because CANVAS.md (`Last pull`, `Last publish`) and the gate cells record commit shas.
#
# Usage:
#   bash scripts/design/trunk-sync.sh check    # at the start of a pull or a publish: local trunk equals <remote>/<trunk>, or refuse
#   bash scripts/design/trunk-sync.sh push     # after a commit: fast-forward <remote>/<trunk> to local trunk, then read the remote back
#
# check refuses when local is ahead (unpushed work), behind, or diverged, and says the next step.
# push refuses when diverged, when the remote refuses the push, or when the remote's tip is not the local one afterwards.
# The remote is $KWT_REMOTE (default origin); the trunk is the kit's own (scripts/lib/kanban-worktree.sh).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/usage.sh
. "$SCRIPT_DIR/../lib/usage.sh"
# shellcheck source=../lib/refuse.sh
. "$SCRIPT_DIR/../lib/refuse.sh"
# shellcheck source=../lib/kanban-worktree.sh
. "$SCRIPT_DIR/../lib/kanban-worktree.sh"

usage() { kit_usage "${BASH_SOURCE[0]}"; }
for _a in "$@"; do case "$_a" in -h|--help) usage; exit 0 ;; esac; done
MODE="${1:-}"
case "$MODE" in check|push) [ $# -eq 1 ] || { usage >&2; exit 2; } ;; *) usage >&2; exit 2 ;; esac

kwt_resolve
R="$KWT_REMOTE"; T="$DEFAULT_BRANCH"
REPO="$(git rev-parse --show-toplevel)"

cur="$(git -C "$REPO" symbolic-ref --short -q HEAD || true)"
[ "$cur" = "$T" ] || kit_refuse 1 design-trunk-not-on-trunk \
  "Error: this checkout is on '${cur:-a detached HEAD}', not the trunk '$T'. The Designer commits on the trunk, and a commit made elsewhere is not one $R/$T can hold as it is." \
  "Next: check out '$T' (git checkout $T), or work in the checkout that has it, then re-run."

git -C "$REPO" fetch --quiet "$R" "$T" || kit_refuse 1 design-trunk-fetch-failed \
  "Error: could not read $R/$T, so nothing here can say whether the trunk holds the Designer's commits." \
  "Next: restore the connection to '$R' (git remote -v; git fetch $R $T), then re-run."

ahead="$(git -C "$REPO" rev-list --count "$R/$T..HEAD")"
behind="$(git -C "$REPO" rev-list --count "HEAD..$R/$T")"
unpushed() { git -C "$REPO" log --format='         %h %s' -n 5 "$R/$T..HEAD"; }

if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
  kit_refuse 1 design-trunk-diverged \
    "Error: local '$T' has $ahead commit(s) $R/$T lacks, and $R/$T has $behind that local lacks." \
    "Next: merge it in (git merge $R/$T), never rebase: a rebase rewrites the shas CANVAS.md and the gate cells record. Then re-run this."
fi
if [ "$behind" -gt 0 ]; then
  kit_refuse 1 design-trunk-behind \
    "Error: $R/$T has $behind commit(s) local '$T' lacks; a commit made now would diverge." \
    "Next: git pull --ff-only $R $T, then re-run."
fi

if [ "$MODE" = check ]; then
  if [ "$ahead" -gt 0 ]; then
    kit_refuse 1 design-trunk-ahead \
      "Error: local '$T' is $ahead commit(s) ahead of $R/$T, so every tool that reads the trunk misses them:" \
      "$(unpushed)" \
      "Next: bash scripts/design/trunk-sync.sh push (or, if a push is not yours to make, tell the human to run: git push $R $T), then re-run."
  fi
  echo "trunk-sync: '$T' equals $R/$T."
  exit 0
fi

if [ "$ahead" -eq 0 ]; then
  echo "trunk-sync: nothing to push; '$T' equals $R/$T."
  exit 0
fi
git -C "$REPO" push --quiet "$R" "HEAD:refs/heads/$T" || kit_refuse 1 design-trunk-push-refused \
  "Error: $R refused the push of '$T' ($ahead commit(s) not on $R/$T):" \
  "$(unpushed)" \
  "Next: git fetch $R $T; if $R/$T moved, merge it (git merge $R/$T), never rebase, and run this again. If the push was denied to this session, tell the human to run: git push $R $T"
remote_tip="$(git -C "$REPO" ls-remote "$R" "refs/heads/$T" | cut -f1)"
[ "$remote_tip" = "$(git -C "$REPO" rev-parse HEAD)" ] || kit_refuse 1 design-trunk-push-unverified \
  "Error: the push of '$T' returned success, but $R's '$T' reads ${remote_tip:-nothing}, not $(git -C "$REPO" rev-parse --short HEAD)." \
  "Next: git fetch $R $T and compare (git log --oneline $R/$T..HEAD), then run this again."
echo "trunk-sync: pushed $ahead commit(s); $R/$T is at $(git -C "$REPO" rev-parse --short HEAD)."
