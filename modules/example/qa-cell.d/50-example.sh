#!/usr/bin/env bash
# KIT-CLASS: KIT — the example module's QA cell check: an example-note pointer must name a note under dev/ that exists at the landed revision. See process/EXTRACTION.md.
# Run by scripts/lib/qa-gate.sh on each PASS row of this kind; process/contracts/landing-gate.md § 3 is the contract.
# Arguments: <id> <ac id> <pointer cell> <repo> <landed-commit> <trunk-commit>. Status 0 passes, 3 refuses.
path="${3%%:*}"
case "$path" in
  dev/*) git -C "$4" cat-file -e "$5:$path" 2>/dev/null && exit 0
         echo "$2: the note $path is not at the landed revision." ;;
  *)     echo "$2: an example-note pointer names a file under dev/, and '$path' is not." ;;
esac
echo "Next: point the row at a note under dev/ that the branch commits."
exit 3   # exit-class: internal — the check contract's refusal status; the gate turns it into its own refusal
