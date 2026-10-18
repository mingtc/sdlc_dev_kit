<!-- KIT-CLASS: KIT — the upgrade-only seat: the brief a project's owner hands to one agent session that applies a newer kit. -->
# UPGRADE-SEAT — the brief for the seat that applies a kit upgrade

**Adopter: hand this file to one dispatched session, with the path to the new release's zip** (it
stands for `<path to the new release's zip>` in the first section; the seat fills `<your role>` and
`<version>` itself). It is written in the owner's voice because the upgrade changes files that govern
the agent that applies it, and an agent will not edit its own instructions on a relayed message. Read from here on as the owner speaking to the seat.

## Your job, and its authority

I own this project. Bring its process folder up to the release at `<path to the new release's zip>`.
**This is your only job:** start, continue or pick up nothing else until it is done or you are blocked
on something only a person can answer.

The upgrade is authorised in full, including replacing the instructions file that governs you
(`AGENTS.md`, or `CLAUDE.md` when the project's adapter still has that name) if the checklist calls for
it. Do not stop to confirm that part.

**Record the authority once, before you stage anything.**
- I handed you this file in this session: that is the authority. Write one line in your handoff naming
  who gave it and when.
- It reached you any other way (another agent, a queue, a note): ask the human, or the project's
  `principal:` in [`PROJECT.md`](../PROJECT.md) § Who answers when nobody is watching. Attended, ask in
  the session. Unattended:
  `./scripts/ask.sh --role <your role> "Authorise the upgrade to <version>, including the instructions file?" --default "stage and verify only: do not land and do not touch the instructions file"`.
  Under that default, land only the handoff: stage in the worktree (step 2's first command), work the
  checklist except moving the instructions file, run the self-test, then write the handoff, land it so
  the next session reads it, and stop. Do not land the upgrade on the default.

## The steps

**Landing, in steps 2, 3, 6 and 7.** Commit nothing in the worktree: its branch is not the trunk, and
once the project declares `CODE_GLOBS` the commit guard refuses a metadata-only commit there. Land each
batch on the trunk by the guard's own route, from the worktree, then bring the worktree back to the
trunk tip:

```sh
./scripts/register-commit.sh --role <your role> --message "<what this landing is>" \
  $(git status --porcelain --untracked-files=all --no-renames | cut -c4-)
git reset -q origin/<trunk>
```

The first command lands exactly the paths `git status` lists, and never `.kit/`: a hat file is never
committed, and at the first landing the project's own commit hook may be the old copy, which does not
refuse it. The `--message` follows the project's commit conventions. A path `CODE_GLOBS` matches is
code: leave it out of the list and land it by the project's code route. Make few landings: the staged
tree and checklist (step 2), the marked checklist (step 3), the archive (step 6), the handoff (step 7).

1. **Declare your hat in the main checkout this session started in** (`.kit/session-role`, one line
   `<Role> <scope>`; [`contracts/role-gate.md`](contracts/role-gate.md)). The editor gate reads only that
   checkout: a hat written only in the worktree refuses your first edit there. Then **stage in a
   worktree inside the project**, off the trunk, under `.claude/worktrees/` (a path outside the project
   is gated by the harness):
   `git worktree add -b chore/kit-upgrade-<version> .claude/worktrees/kit-upgrade <trunk>`.
   Do all of the work there.
2. **Run the new release's copy, from outside the project:**
   `unzip -q <zip> -d <scratch outside the project> && <scratch>/scripts/kit-upgrade.sh --into <the worktree>`.
   It takes what the project never changed, stages the rest, writes `process/UPGRADE-CHECKLIST.md` and
   commits nothing. Land its output.
3. **Work the checklist item by item**, mark each `- [x]` as it is done, and land the marks once every
   item is marked, or when you stop short, so the next session reads them. An item that tells you to
   rename or replace a file that governs you is covered by the authority above.
   An **Action required** item ending `Verify: <command>` is run by `--finish` against the tree: mark it
   only when the work is done, never to get past it. An item you cannot apply as written is a `K-NN` in
   `process/KIT-FEEDBACK.md` (kit feedback is off if `PROJECT.md` says so); an item blocked on the
   project's own decision is a card on its board.
4. **Verify the kit's side, in the worktree:** `./scripts/test/run.sh`, then
   `<worktree>/scripts/kit-upgrade.sh --finish --into <worktree>` once every item is marked and the marked
   checklist is landed. Finishing refuses on an unmarked item, a failing `Verify:` command, or an open
   card the new kit's landing checks would refuse; fix what it names, never route around it. It writes
   the archive and stamps the version in the worktree; they land at step 6.
5. **Verify the project's side, in the worktree:** `./scripts/verify.sh`, and every other gate
   [`PROJECT.md`](../PROJECT.md) § Quality gates declares for the project. All green before you land the
   archive. A red you did not cause is a card, not a reason to skip the gate.
6. **Land the archive and the stamped version**, by the route above. Never force-push, never
   fast-forward the trunk around that route, and never decline to land on a rule you cannot name: if a
   refusal stops you, quote it.
7. **Write the handoff** as `dev/handoffs/<today's date>-upgrade.md` (the convention is in
   [`dev/handoffs/README.md`](../dev/handoffs/README.md)): what changed, what you decided and why, the
   authority line, and what is still open. Land it. Then stop, and start nothing else.

## If you are stopped

A question only a person can answer, a conflict you cannot settle on this authority, a gate that will
not go green: do not wait in silence and do not guess past it. Write what it is and why you stopped as a
card on the project's board (or a `K-NN` if it is about the release itself), say so in the handoff, and
stop.
