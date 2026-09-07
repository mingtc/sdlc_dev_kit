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
  only: an earlier entry is never rewritten or removed. **The target is IN the entry**, not only in
  the publication's own subject line.
  *Why:* the log is the review record; a log that can be edited proves nothing about what
  happened. And an entry that omits its target is **un-judgeable**: a drift checker holding a
  card's container against its own last entry has nothing to hold it to, so the check goes blind in
  exactly the workflow that uses a custom note — which is the workflow the manual mandates.
  *And the invariant buys more than the drift check it was written for: because every move carries
  its target, one card's log holds the ORDERED SEQUENCE of its states, so a **backward** transition —
  an item returned from review — is derivable without anything new being written down. That is the
  operand behind the oversize signal in [`../doctrine/rigor-tiers.md`](../doctrine/rigor-tiers.md)
  § The question this ladder does NOT answer. Named here rather than there because it is a property
  of this invariant; any implementation honouring § 2 supplies it for free.*

- **RECORDING WITHOUT MOVING IS A SECOND OPERATION, and it changes no container.** An append that
  states something about an item — a declaration owed before an act, a ruling cited, an observation
  the next reader needs — is **not a move**, is available on an item **already in its target
  state**, and **carries no target, because there is none.** Every invariant above about *moves*
  binds moves; this one binds the other operation, and the two are named separately by the tool
  rather than distinguished by an omitted argument.
  *Why, and this is the reason it is an invariant rather than a convenience:* **doctrine's most
  safety-critical artefacts are the ones a card is required to carry BEFORE the act they
  authorize** — a budget committed before the first spend, a consent id recorded before the run it
  permits. The item is already in the right column, so a mover with only a move refuses. **A
  process that names a tool for an act its tool cannot perform gets that act done by hand**, in
  several steps, every one of them skippable and none of them reported — which is the failure this
  invariant exists to close, not a gap in convenience.
  **Two things it must not disturb, stated because they are what a careless version breaks:**
  **(i)** *the container IS the status* survives intact — this operation writes no status anywhere,
  so status still lives in exactly one place; and **(ii)** the entry **must not emit a structured
  status token**, so a drift checker reading the last activity entry treats it as un-judgeable and
  skips it, rather than reading a note as a declaration about a card that has not moved. A mover
  that reuses its move formatter here writes a target that does not exist, and the checker believes
  it. **The guarantee is the tool's to make**, so a note whose own text would introduce such a
  token is refused rather than passed through.
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
- **A REFUSAL LEAVES NOTHING BEHIND — and where it cannot promise that outright, it tries.**
  Every refusal decided from the invocation alone — argument shape, which of the two operations,
  target legality, actor legality — is decided before the tool creates, locks or synchronises
  anything. A refusal that depends on the board's CONTENTS cannot make that promise
  unconditionally, because reading the published board may mean materializing it; it is held to
  the weaker, still-testable form instead: **the cheap read is attempted first, it may only
  REFUSE, and a read that cannot answer falls through rather than refusing.** Inspecting a
  published ref is not building a checkout, and that is where the line sits: the first leaves
  nothing an operator must clean up, the second does.
  *Why:* measured. A syntactically valid invocation naming an item that did not exist created the
  auxiliary checkout ([kanban-worktree.md](kanban-worktree.md)) before it could look, and left a
  registered, untracked directory in a repository other lanes were working in — one blanket
  `git add` from being committed, and it had to be proven safe before it could be removed. The
  refusal itself was correct; the state it left was the cost, and excluding the directory from
  version control is a mitigation each project applies separately and the next operator does not
  inherit. **The fall-through half is the load-bearing half, not a caveat:** a probe that answers
  from a stale or unreadable ref and refuses anyway says "no such item" about an item that
  exists — a worse failure than the checkout it saved, and one the operator cannot diagnose.
- **The legal target set is closed and validated up front.** A target outside the declared
  lifecycle is refused before anything is touched.
  *Why:* an invented state is invisible to every other tool that walks the lifecycle.

## 3. REFUSAL CONDITIONS

- The named item does not exist, **or more than one item matches the name** ⇒ refuse, listing the
  matches. Guessing between two items is a data-loss move. The non-existence half is the one
  refusal that must be **attempted against the published board before any auxiliary state
  exists** (§ 2); the multiple-match half is decided by the authoritative read, which is also the
  read that can list.
- The target state is not in the declared lifecycle ⇒ refuse, listing the legal targets.
- **A MOVE** whose item is already in the target state ⇒ refuse as a no-op rather than appending a
  second, meaningless log entry — **and name the record-without-moving operation in the refusal**,
  because "already there, nothing to do" is false for the caller who wanted to record something.
  This refusal is **scoped to a move** and must never reach a note-only append: applying it there is
  precisely what makes a mandated declaration unperformable by its named tool.
- A **note-only append with no note** ⇒ refuse. A move has a defensible default note, because the
  move itself is the fact being recorded; here the note is the entire content.
- A **note-only append whose note would read as a status declaration** — it carries a transition
  arrow or a folder name in a structured position — ⇒ refuse, naming the offending shape. The
  formatter emits none; this closes the only remaining way one arrives.
- Both operations requested at once, or neither ⇒ refuse. A caller who has asked to move and not to
  move does not know which they wanted, and this is the one guess the tool must never make.
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

**For a record-without-moving append, green is three facts and the first one is different: the item
and the container it STAYED IN, then the exact entry, then the published commit.** It must not print
a `from → to` line, because it performed no transition — a tool that prints one is asserting a
transition it did not make, and the log's own transition shorthand then counts landings that never
happened.

## 5. MINIMAL INTERFACE

**In:** the item's identity, the acting role, a one-line note, and **either** a target state (a
move) **or** an explicit record-without-moving selector — never both, never neither.
**Out:** for a move, the from/to pair; for a record, the container the item stayed in. Then in both
cases the appended activity line, the published commit identifier, and a non-zero exit for every
refusal above.
**Not in:** anything about *how* the publication reaches the trunk — that is the auxiliary
checkout contract's problem, and a reimplementation may solve it any way it likes.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/move-issue.sh` — KIT-CLASS: KIT. The move, the activity append, the commit and the
  push.
- **The § 2 pre-flight probe is a TREE READ, not a checkout** — `git ls-tree` against the
  publication remote's trunk ref, and a miss re-read after one single-branch fetch before it may
  refuse, because that tracking ref is a CACHE: an item another operator pushed a minute ago is
  absent from it and present on the trunk. It refuses only. The lookup inside the auxiliary
  checkout still decides every acceptance, the multiple-match refusal and the already-in-target
  refusal — so anything the probe cannot match (an unreadable ref, a trunk carrying no board, a
  pattern passed where an identity belongs) costs the old behaviour and nothing else.
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
