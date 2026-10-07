<!-- KIT-CLASS: KIT — the upgrade-only seat: the brief a project's owner hands to one agent session that applies a newer kit. -->
# UPGRADE-SEAT — the brief for the seat that applies a kit upgrade

**Adopter: hand this file to one dispatched session, with the path to the new release's zip, and fill
the two blanks in the first section.** It is written in the owner's voice because the upgrade changes
files that govern the agent that applies it, and an agent will not edit its own instructions on a
relayed message. Read from here on as the owner speaking to the seat.

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
  Under that default, do every step through step 5 except moving the instructions file, then write the
  handoff and stop. Do not land on the default.

## The steps

1. **Stage in a worktree inside the project**, off the trunk, under `.claude/worktrees/` (a path outside
   the project is gated by the harness):
   `git worktree add -b chore/kit-upgrade-<version> .claude/worktrees/kit-upgrade <trunk>`.
   Do all of the work there.
2. **Run the new release's copy, from outside the project:**
   `unzip -q <zip> -d <scratch outside the project> && <scratch>/scripts/kit-upgrade.sh --into <the worktree>`.
   It takes what the project never changed, stages the rest, writes `process/UPGRADE-CHECKLIST.md` and
   commits nothing. Commit its output through the project's own conventions.
3. **Work the checklist item by item**, mark each `- [x]` as it is done, and commit the marks as you go.
   An item that tells you to rename or replace a file that governs you is covered by the authority above.
   An **Action required** item ending `Verify: <command>` is run by `--finish` against the tree: mark it
   only when the work is done, never to get past it. An item you cannot apply as written is a `K-NN` in
   `process/KIT-FEEDBACK.md` (kit feedback is off if `PROJECT.md` says so); an item blocked on the
   project's own decision is a card on its board.
4. **Verify the kit's side, in the worktree:** `./scripts/test/run.sh`, then
   `<worktree>/scripts/kit-upgrade.sh --finish --into <worktree>` once every item is marked and the marked
   checklist is committed. Finishing refuses on an unmarked item, a failing `Verify:` command, or an open
   card the new kit's landing checks would refuse; fix what it names, never route around it. Commit the
   archive it writes.
5. **Verify the project's side, in the worktree:** `./scripts/verify.sh`, and every other gate
   [`PROJECT.md`](../PROJECT.md) § Quality gates declares for the project. All green before you land. A
   red you did not cause is a card, not a reason to skip the gate.
6. **Land by the project's own route**: its board, gates and commit conventions, as any change here
   lands. Never force-push, never fast-forward the trunk around that route, and never decline to land
   on a rule you cannot name: if a refusal stops you, quote it.
7. **Write `HANDOFF.md`** at the top of the project: what changed, what you decided and why, the
   authority line, and what is still open. Then stop, and start nothing else.

## If you are stopped

A question only a person can answer, a conflict you cannot settle on this authority, a gate that will
not go green: do not wait in silence and do not guess past it. Write what it is and why you stopped as a
card on the project's board (or a `K-NN` if it is about the release itself), say so in `HANDOFF.md`, and
stop.
