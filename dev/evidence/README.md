<!-- KIT-CLASS: KIT — the verdict-evidence convention. Travels unedited; it names no project. -->
# `dev/evidence/` — binary evidence a QA Verdict row cites

`dev/evidence/<card-id>/` holds the files QA produced to show an AC met when the proof is not a line
of code: a screenshot, a render, a diff image. A `## QA Verdict` row cites one with the `artifact`
evidence kind (`.claude/roles/qa.md` step 4) as `<path> <full blob sha>`.

- **QA commits the file to the trunk first**, with `./scripts/register-commit.sh --role QA --message
  "<message>" dev/evidence/<card-id>/<file>`, then writes the row. The landing resolves the pair on
  the trunk, never on the work branch, so a file that exists only on the branch is refused.
- **The sha is the whole blob sha**, copied from `git rev-parse <remote>/<trunk>:<path>` (all of it;
  a prefix is refused). It ties the row to the bytes QA looked at.
- **Name each file for the AC it shows** (`AC2-login-error.png`); a row citing several files lists
  each `<path> <sha>` pair.
- **A file is never edited after a verdict cites it.** A changed render is a new file and a new row.
- The table still needs one `test` or `file:line` row with a quote: the gate re-reads that line.
