<!-- KIT-CLASS: KIT — contract sheet: the board mover. See process/EXTRACTION.md. -->
# CONTRACT — the board mover

## 1. PURPOSE

To make a work item's **status a fact rather than a claim**, by giving the board exactly one way
to change and making every change self-recording.

## 2. HARD INVARIANTS

- **The container IS the status.** An item's state is where it lives, not a field inside it.
  There is no second place status is written, so there is no second place it can disagree.
  *Why:* the moment status is duplicated into the item's own text, the two drift, and every
  reader has to guess which one is stale.
- **Only the mover moves it.** A status change performed by hand — moving the file, editing a
  field — is a defect, even when the end state looks identical.
  *Why:* a hand move skips the record and the publication below, so the board is right locally
  and wrong for everybody else.
- **Every move APPENDS to the item's own activity log — date, actor, target, note.** Appends
  only: an earlier entry is never rewritten or removed.
  *Why:* the log is the review record; a log that can be edited proves nothing about what
  happened.
- **Every move names its actor, and the actor must be one of the project's declared roles.** An
  unrecognised actor refuses the move rather than being recorded as itself.
  *Why:* an unconstrained actor field silently becomes free text, and the audit trail stops
  being groupable.
- **Every move is published to the trunk as its own commit, regardless of what the operator's
  own workspace is doing.** The operator's workspace is never switched, stashed or reset to
  achieve this.
  *Why:* status that lives only in one person's workspace is invisible to everyone else, and a
  tool that hijacks a workspace to publish will eventually destroy uncommitted work.
- **Concurrent moves are serialized, and a move is all-or-nothing.** Two callers cannot half-move
  two items into each other's transaction.
  *Why:* a partially applied move is the one board state nobody can recover by reading.
- **Uncommitted work found in the mover's own publication area is WAITED ON and REPORTED — never
  discarded.** The default on a collision is to stop, say exactly what was found and how to
  resolve it, and exit non-zero; discarding is available only as an **explicit** instruction from
  a caller who has read what would be lost.
  *Why:* that area is shared between lanes, so the state in it may belong to **another** run.
  "Clean it up and proceed" is a data-loss default that succeeds silently, and the operator who
  loses the work is never the one who chose the default. Waiting costs a re-run; discarding costs
  someone else's session.
- **The mover reads the PUBLISHED board, so an item that has not reached the trunk does not
  exist to it.** An item created in the operator's own workspace is invisible until it is
  published; the mover must therefore state this as the likely cause when it cannot find a named
  item, rather than reporting only that nothing matched.
  *Why:* the move is published to the trunk (invariant above) and is therefore computed against
  the trunk's copy of the board. "Not found" is then a **true statement with an unfindable
  cause** — and it was hit **three times independently**, in three unrelated runs, before anyone
  wrote it down. The counterpart obligation is on creation: see
  [issue-creation.md](issue-creation.md) § 2.
- **The legal target set is closed and validated up front.** A target outside the declared
  lifecycle is refused before anything is touched.
  *Why:* an invented state is invisible to every other tool that walks the lifecycle.

## 3. REFUSAL CONDITIONS

- The named item does not exist, **or more than one item matches the name** ⇒ refuse, listing the
  matches. Guessing between two items is a data-loss move.
- The target state is not in the declared lifecycle ⇒ refuse, listing the legal targets.
- The item is already in the target state ⇒ refuse as a no-op rather than appending a second,
  meaningless log entry.
- No actor was given, or the actor is not a declared role ⇒ refuse, listing the legal roles.
- The target container does not exist ⇒ refuse **before** moving anything.
- The publication of the move fails ⇒ report loudly that the board changed locally and did **not**
  reach the trunk, and name the recovery. A move that is silently local is a lie to everyone else.
- The publication area holds uncommitted work ⇒ **refuse and wait**, listing what was found and
  both ways out (keep it, or discard it deliberately). Never resolve it by destroying it.

## 4. WHAT GREEN MEANS

The move printed, and a reader can check each line without trusting the tool:

1. **from → to**, both named.
2. The **exact activity line** appended.
3. The **published commit identifier** and the trunk it landed on.

Green is those three facts. An exit status with no statement of what moved where is not a
completed move; it is a completed process.

## 5. MINIMAL INTERFACE

**In:** the item's identity, the target state, the acting role, a one-line note.
**Out:** the from/to pair, the appended activity line, the published commit identifier, and a
non-zero exit for every refusal above.
**Not in:** anything about *how* the publication reaches the trunk — that is the auxiliary
checkout contract's problem, and a reimplementation may solve it any way it likes.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/move-issue.sh` — KIT-CLASS: KIT. The move, the activity append, the commit and the
  push.
- `scripts/lib/kanban-worktree.sh` — KIT-CLASS: KIT. How this kit publishes to the trunk
  without touching the operator's workspace; contracted separately in
  [kanban-worktree.md](kanban-worktree.md).
- The lifecycle's member states are configuration, not contract — the project's set is named in
  its own adapter document.
- **`--discard-dirty` is the § 2 wait-never-discard invariant's explicit escape hatch, and it is
  SINGLE-OPERATOR-ONLY.** It exists for the case where you know the uncommitted state is your own
  half-applied move. In any run with a **second lane** — a parallel worker, an orchestrated
  tranche, a background job that also moves cards — passing it can destroy work you never saw.
  Default behaviour (refuse, list, wait) is **unchanged** by this note: the sheet gained the
  invariant after a real collision between two lanes; the implementation already honoured it.
