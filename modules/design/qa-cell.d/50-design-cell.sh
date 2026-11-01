#!/usr/bin/env bash
# KIT-CLASS: KIT — the design module's QA cell check: a design row must hold identical entries whose pins, images and renders the trunk backs. See process/EXTRACTION.md.
# Run by scripts/lib/qa-gate.sh on each PASS row of the design kind; process/contracts/landing-gate.md § 3 is the contract.
# Arguments: <id> <ac id> <pointer cell> <repo> <landed-commit> <trunk-commit>. Status 0 passes, 3 refuses, any other status is a check that could not run.
#
# The judgement is scripts/design/check-design-cell.py, taken from the trunk with the link check it reads. It reads the card and the
# evidence images on the TRUNK, where QA commits them (register-commit.sh): a file only the branch holds is refused.
id="$1" ac="$2" cell="$3" repo="$4" trunk="$6"
broken() {  # <what> <next> — a check that cannot answer is a refusal
  echo "$ac: the design cell check could not run: $1"
  echo "Next: $2"
  exit 70   # exit-class: internal — the check contract's "did not run" status; the gate turns it into qa-verdict-cell-check-broken
}
command -v python3 >/dev/null 2>&1 || broken "python3 is not found." "install Python 3.9 or later (./scripts/module.sh status design says whether it holds), then land again."
tmp="$(mktemp -d "${TMPDIR:-/tmp}/kit-design-cell.XXXXXX")" || broken "no scratch directory could be made." "check the disk and TMPDIR, then land again."
trap 'rm -rf "${tmp:?}"' EXIT
for f in check-design-cell.py check-design-links.py; do
  git -C "$repo" show "$trunk:scripts/design/$f" > "$tmp/$f" 2>/dev/null || broken "scripts/design/$f is not on the trunk." "commit and push the design module's files (./scripts/module.sh status design), then land again."
done
out="$(PYTHONDONTWRITEBYTECODE=1 python3 "$tmp/check-design-cell.py" "$repo" "$trunk" "$id" "$ac" "$cell" 2>&1 </dev/null)"
rc=$?
case "$rc" in
  0) printf '%s\n' "$out" | grep -q '^design-cell: ok$' && exit 0
     printf '%s\n' "$out" | tail -3
     broken "scripts/design/check-design-cell.py exited 0 without saying design-cell: ok." "read what it printed above, fix the tool, then land again." ;;
  1) printf '%s\n' "$out" | grep -q 'the design cell is refused' || { printf '%s\n' "$out" | tail -3; broken "scripts/design/check-design-cell.py exited 1 without a refusal." "read what it printed above, fix the tool, then land again."; }
     printf '%s\n' "$out"
     echo "Next: write the row as UX-NNN#state@<pin>: identical; dev/evidence/$id/UX-NNN-state-pin.png, dev/evidence/$id/UX-NNN-state-build.png, commit both PNGs to the trunk (./scripts/register-commit.sh --role QA; the pin image is the render the pin commit holds, the build image a screenshot of the build), then land again; or mark the row FAIL_AC with the differing element ids (.claude/templates/design/QA-verdict-design.fragment.md)."
     exit 3   # exit-class: internal — the check contract's refusal status; the gate turns it into its own refusal
     ;;
  *) printf '%s\n' "$out" | tail -3
     broken "scripts/design/check-design-cell.py exited $rc." "read what it printed above, then land again." ;;
esac
