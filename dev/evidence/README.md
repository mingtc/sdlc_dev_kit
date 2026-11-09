<!-- KIT-CLASS: KIT — the verdict-evidence convention. Travels unedited; it names no project. -->
# `dev/evidence/` — binary evidence a QA Verdict row cites

`dev/evidence/<card-id>/` holds the files that show an AC met when the proof is not a line of code: a
screenshot, a render, a diff image. A `## QA Verdict` row cites one with the `artifact` evidence kind
(`.claude/roles/qa.md` step 4) as `<path> <full blob sha>`.

**Who commits what, and when — stated here once.** QA cites an image by its blob sha and never takes or reads one
(`.claude/agents/qa-worker.md`). A human or the orchestrator compares the images, and QA records their result on the row.
A file is committed in one place, by Dev or the project's tooling, and which place depends on whether a QA row will cite it:

- **A file an `artifact` row will cite** (a build screenshot included) goes to the trunk, below.
- **Any other evidence Dev produces for its card** (probe output, a log, a record a manual check read) is committed on the
  card's work branch, under `dev/evidence/<card-id>/`, by Dev, in a commit of its own whenever it changes, before or after
  the code commit; it reaches the trunk when the branch lands. `scripts/githooks/pre-commit` lets that commit through when
  every staged path is under the directory of the card the branch's own name carries (`<kind>/<card-id>-<slug>`). Another
  card's directory, or any other metadata path in the same commit (the card file included), keeps the refusal.
- **A path a test reads is code, not evidence**: list it in `CODE_GLOBS` and it commits with the code.

- **The file is on the trunk before the row cites it**, committed with `./scripts/register-commit.sh --role
  <role> --message "<message>" dev/evidence/<card-id>/<file>`. The landing resolves the pair on the trunk,
  never on the work branch, so a file that exists only on the branch is refused.
- **The sha is the whole blob sha**, copied from `git rev-parse <remote>/<trunk>:<path>` (all of it;
  a prefix is refused). It ties the row to the bytes it cites.
- **Name each file for the AC it shows** (`AC2-login-error.png`); a row citing several files lists
  each `<path> <sha>` pair.
- **A file is never edited after a verdict cites it.** A changed render is a new file, cited from that AC's row.
- The table still needs one `test` or `file:line` row with a quote (the gate re-reads that line), or a row whose `qa-cell` check passed.
