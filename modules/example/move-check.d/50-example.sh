#!/usr/bin/env bash
# KIT-CLASS: KIT — the example module's move check: a card may not start while it lacks the sign-off line the module's fragment mints. See process/EXTRACTION.md.
# Run by scripts/move-issue.sh before the move; process/contracts/board-mover.md § 3 is the contract.
# Arguments: <id> <from> <to> <role> <card-file> <repo> <trunk-commit>. Status 0 allows, 3 refuses.
if ! grep -q '^example-sign-off:' "$5" 2>/dev/null; then
  echo "$1 has no 'example-sign-off:' line, which a card carries while the example module is enabled."
  echo "Next: add 'example-sign-off: pending' to the card, commit it to the trunk, then move it again."
  exit 3   # exit-class: internal — the check contract's refusal status; the mover turns it into its own refusal
fi
exit 0
