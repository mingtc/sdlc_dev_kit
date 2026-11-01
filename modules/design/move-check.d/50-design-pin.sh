#!/usr/bin/env bash
# KIT-CLASS: KIT — the design module's card gate: a card may not arrive in in_progress/ or dev_complete/ with an unpinned, unresolved or unapproved design: entry. See process/EXTRACTION.md.
# Run by scripts/move-issue.sh, subtask.sh and finish-pr.sh before a move to in_progress or dev_complete; process/contracts/board-mover.md § 3 is the contract.
# Arguments: <id> <from> <to> <role> <card-file> <repo> <trunk-commit>. Status 0 allows, 3 refuses, any other status is a check that could not run.
#
# A move out of in_progress/ is not judged (the card arrived there judged). Any other arrival is judged in full, unless the card has been
# in in_progress/ on the trunk before (it was judged then; a later drift is reported, not blocked): then only whether its entries are
# pinned at all. The judgement is the trunk's: the trunk's design record is unpacked to a scratch directory, the card as it stands is put
# in it, and scripts/design/check-design-links.py --leaving reads that tree, so a checkout that has not pushed the design record, or has
# edited the tool, is not what judges the move.
case "${1:-}" in -h|--help) printf '%s\n' "usage: 50-design-pin.sh <id> <from> <to> <role> <card-file> <repo> <trunk-commit>  (run by the board mover; status 0 allows, 3 refuses, other: did not run)"; exit 0 ;; esac
id="$1" from="$2" to="$3" card="$5" repo="$6" trunk="$7"
case "$to" in in_progress|dev_complete) ;; *) exit 0 ;; esac
[ "$from" != in_progress ] || exit 0
broken() {  # <what> <next> — a check that cannot answer is a refusal
  echo "The design card gate could not run: $1"
  echo "Next: $2"
  exit 70   # exit-class: internal — the check contract's "did not run" status; the mover turns it into move-check-broken
}
mode=full
if [ "$from" != todo ] && [ -n "$(git -C "$repo" log -1 --format=%h "$trunk" -- ":(glob)progress/**/in_progress/${card##*/}" 2>/dev/null)" ]; then mode=light; fi
command -v python3 >/dev/null 2>&1 || broken "python3 is not found." "install Python 3.9 or later (./scripts/module.sh status design says whether it holds), then move $id again."
scratch="$(mktemp -d "${TMPDIR:-/tmp}/kit-design-pin.XXXXXX")" || broken "no scratch directory could be made." "check the disk and TMPDIR, then move $id again."
trap 'rm -rf "${scratch:?}"' EXIT
git -C "$repo" archive "$trunk" requirements scripts/design scripts/config.sh 2>/dev/null | tar -x -C "$scratch" 2>/dev/null || broken "the trunk's design record ($trunk) could not be unpacked." "run git fetch, commit and push the design module's files (./scripts/module.sh status design), then move $id again."
[ -f "$scratch/scripts/design/check-design-links.py" ] || broken "scripts/design/check-design-links.py is not on the trunk." "commit and push the design module's files (./scripts/module.sh status design), then move $id again."
mkdir -p "$scratch/progress/todo"
rel="progress/todo/${card##*/}"
cp "$card" "$scratch/$rel" 2>/dev/null || broken "the card $card could not be read." "check that the card is where the mover found it, then move $id again."
gitdir="$(git -C "$repo" rev-parse --absolute-git-dir 2>/dev/null)" || broken "the repository's git directory could not be found." "run the move from the project, then move $id again."
out="$( cd "$scratch" && GIT_DIR="$gitdir" PYTHONDONTWRITEBYTECODE=1 python3 scripts/design/check-design-links.py "$scratch" --head "$trunk" --leaving "$rel" 2>&1 </dev/null )"
rc=$?
# an answer is the tool's own summary line; no line, or a status that is neither 0 nor 1, is a tool that did not run
case "$rc" in 0|1) printf '%s\n' "$out" | grep -q '^design-links: ' || { printf '%s\n' "$out" | tail -3; broken "scripts/design/check-design-links.py exited $rc without its summary line." "read what it printed above, fix the design record or the tool, then move $id again."; } ;; esac
found="$(printf '%s\n' "$out" | grep -v '^design-links:' | grep -E '^[A-Z][A-Z-]+ ' | grep -vE '^(UNCITED|UNCLASSIFIED|SCRIPT-COLOUR|UNREAD|UNCOMPARED|DESIGN-STORY) ' | sed "s#progress/todo/#progress/$from/#" || true)"
[ "$mode" = full ] || found="$(printf '%s\n' "$found" | grep -E '^(UNPINNED|BARE-PIN|DESIGN-KEY|DESIGN-NONE|DESIGN-MISSING) ' || true)"
case "$rc" in
  0|1) [ -n "$found" ] || exit 0
     printf '%s\n' "$found"
     echo "Next: make the card's design: key list every screen its ACs cite, each entry pinned as UX-NNN#state@<commit> (the commit of the Designer's Pin-ready: line) of a screen whose gate1 is approved@<sha> (or cite a recorded [decision: D-NN] on the design: line), or take the (UI) tag or the [design: ...] marker off an AC of a card that builds no screen, commit the card to the trunk, then move $id again (requirements/design/README.md § 4)."
     exit 3   # exit-class: internal — the check contract's refusal status; the mover turns it into its own refusal
     ;;
  *) printf '%s\n' "$out" | tail -3
     broken "scripts/design/check-design-links.py exited $rc." "read what it printed above, fix the design record, then move $id again." ;;
esac
