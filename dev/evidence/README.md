<!-- KIT-CLASS: KIT — the verdict-evidence convention. Travels unedited; it names no project. -->
# `dev/evidence/` — binary evidence a QA Verdict row cites

`dev/evidence/<card-id>/` holds the files that show an AC met when the proof is not a line of code: a
screenshot, a render, a diff image. A `## QA Verdict` row cites one with the `artifact` evidence kind
(`.claude/roles/qa.md` step 4) as `<path> <full blob sha>`.

**Who does what, stated here once.** QA cites an image by its blob sha and never takes or reads one
(`.claude/agents/qa-worker.md`). Dev, or the project's tooling, commits the file to the trunk, a build
screenshot included. A human or the orchestrator compares the images, and QA records their result on the row.

- **The file is on the trunk before the row cites it**, committed with `./scripts/register-commit.sh --role
  <role> --message "<message>" dev/evidence/<card-id>/<file>`. The landing resolves the pair on the trunk,
  never on the work branch, so a file that exists only on the branch is refused.
- **The sha is the whole blob sha**, copied from `git rev-parse <remote>/<trunk>:<path>` (all of it;
  a prefix is refused). It ties the row to the bytes it cites.
- **Name each file for the AC it shows** (`AC2-login-error.png`); a row citing several files lists
  each `<path> <sha>` pair.
- **A file is never edited after a verdict cites it.** A changed render is a new file, cited from that AC's row.
- The table still needs one `test` or `file:line` row with a quote (the gate re-reads that line), or a row whose `qa-cell` check passed.
