#!/usr/bin/env bash
# KIT-CLASS: KIT — the design module's landing check: a card with a (UI) AC, or an AC citing a screen, may not reach qa_complete/ without a design row for it. See process/EXTRACTION.md.
# Run by scripts/finish-pr.sh (before its squash), scripts/move-issue.sh and subtask.sh before a move to qa_complete; process/contracts/board-mover.md § 3 is the contract.
# Arguments: <id> <from> <to> <role> <card-file> <repo> <trunk-commit>. Status 0 allows, 3 refuses, any other status is a check that could not run.
#
# The card is read on the trunk (QA commits the verdict there), and the check is the trunk's: scripts/design/check-design-cell.py --rows.
case "${1:-}" in -h|--help) printf '%s\n' "usage: 50-design-rows.sh <id> <from> <to> <role> <card-file> <repo> <trunk-commit>  (run by the board mover; status 0 allows, 3 refuses, other: did not run)"; exit 0 ;; esac
id="$1" to="$3" repo="$6" trunk="$7"
[ "$to" = qa_complete ] || exit 0
broken() {  # <what> <next> — a check that cannot answer is a refusal
  echo "The design rows check could not run: $1"
  echo "Next: $2"
  exit 70   # exit-class: internal — the check contract's "did not run" status; the mover turns it into move-check-broken
}
command -v python3 >/dev/null 2>&1 || broken "python3 is not found." "install Python 3.9 or later (./scripts/module.sh status design says whether it holds), then land $id again."
tmp="$(mktemp -d "${TMPDIR:-/tmp}/kit-design-rows.XXXXXX")" || broken "no scratch directory could be made." "check the disk and TMPDIR, then land $id again."
trap 'rm -rf "${tmp:?}"' EXIT
for f in check-design-cell.py check-design-links.py; do
  git -C "$repo" show "$trunk:scripts/design/$f" > "$tmp/$f" 2>/dev/null || broken "scripts/design/$f is not on the trunk." "commit and push the design module's files (./scripts/module.sh status design), then land $id again."
done
out="$(PYTHONDONTWRITEBYTECODE=1 python3 "$tmp/check-design-cell.py" --rows "$repo" "$trunk" "$id" 2>&1 </dev/null)"
rc=$?
case "$rc" in
  0) printf '%s\n' "$out" | grep -q '^design-rows: ok$' && exit 0
     printf '%s\n' "$out" | tail -3
     broken "scripts/design/check-design-cell.py exited 0 without saying design-rows: ok." "read what it printed above, fix the tool, then land $id again." ;;
  1) printf '%s\n' "$out" | grep -q 'the design rows are refused' || { printf '%s\n' "$out" | tail -3; broken "scripts/design/check-design-cell.py exited 1 without a refusal." "read what it printed above, fix the tool, then land $id again."; }
     printf '%s\n' "$out"
     echo "Next: give each such AC a verdict row of evidence kind design, one UX-NNN#state@<pin> entry per state the AC cites (.claude/templates/design/QA-verdict-design.fragment.md), commit the images and the card to the trunk (./scripts/register-commit.sh), then land again."
     exit 3   # exit-class: internal — the check contract's refusal status; the mover turns it into its own refusal
     ;;
  *) printf '%s\n' "$out" | tail -3
     broken "scripts/design/check-design-cell.py exited $rc." "read what it printed above, then land $id again." ;;
esac
