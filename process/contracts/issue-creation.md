<!-- KIT-CLASS: KIT — contract sheet: issue / spec creation. See process/EXTRACTION.md. -->
# CONTRACT — issue / requirement creation

## 1. PURPOSE

To make every work item **born complete** — same shape, same required fields, same starting
state — so that every tool and every reader downstream can rely on the shape without checking.

## 2. HARD INVARIANTS

- **Every item is created from a template, and the template is the shape's only definition.**
  There is one template per item kind, and no other way to bring an item into existence.
  *Why:* a shape defined by example is re-derived slightly differently by every author, and the
  first tool that walks the board is the one that discovers it.
- **The structured header is a CONTRACT: a declared set of keys, every one present, each with a
  declared meaning.** An unset key appears with an empty or explicitly-empty value rather than
  being omitted.
  *Why:* "absent" and "empty" mean different things to a reader and the same thing to a careless
  parser; requiring presence removes the ambiguity.
- **Status is NOT one of those keys.** The item's state is its location, and the header never
  restates it.
  *Why:* two sources for one fact is the drift this whole kit is organised against.
- **The identifier is supplied by the caller and validated before anything is written.** Creation
  never mints its own.
  *Why:* creation is stateless and therefore repeatable and testable; the one place numbers are
  chosen stays the one place (see [id-minting.md](id-minting.md)).
- **The identifier in the header and the identifier in the item's own name AGREE.** The
  substitution that stamps the identifier keys on the header's *key*, never on a donor-shaped
  value, so it cannot silently match nothing.
  *Why:* a substitution that matches nothing fails silently and every created item carries the
  template's example identifier — which is exactly how one project produced a whole board of
  items whose header said one thing and whose name said another, and whose drift report then
  flagged every card on it.
- **Creation is inert.** It writes the new item and nothing else: no state change, no
  publication, no notification.
  *Why:* creating a description of work is not the same act as starting it, and conflating them
  makes drafting expensive.
- **Creation is inert — and therefore creation must SAY that the item is not yet published.**
  Because creation publishes nothing (invariant above), the new item exists only in the
  operator's workspace, and the board mover — which computes against the **published** board —
  cannot see it. Creation therefore prints the publication step as an unmissable next step, and
  does not perform it.
  *Why:* the two invariants together are a trap, and it caught **three independent agents** in
  three unrelated runs, each losing the same twenty minutes to a mover saying only that nothing
  matched. The fix belongs to the **prose and the error message**, not to inertness: a creation
  script that commits and pushes would publish drafts nobody has read and would break § 4.3's
  *"nothing else changed"*. The mover's half of this obligation is in
  [board-mover.md](board-mover.md) § 2.
- **A decomposed child names its parent, and the parent is a real item.** A child that names no
  parent, or an absent one, is an orphan the board cannot roll up.
  *Why:* decomposition whose links do not resolve is a tree only in the author's head.

- **THE ONE CARVE-OUT TO INERTNESS: a creator that writes INSIDE the mover's own publication area
  must publish, and says so.** The invariants above hold for every creator that writes into the
  operator's workspace, and their reason is untouched — creating a description of work is not
  starting it, and a script that published drafts nobody had read would break § 4.3. **But a
  creator whose file lands in the shared, trunk-pinned publication area is in a different
  situation: that area is `reset --hard` by the next operation that touches it, so an unpublished
  file there is not a draft being protected — it is a file about to be destroyed.** Inertness
  there does not withhold publication; it loses the work.
  So such a creator **publishes as part of creation**, and the carve-out is **contracted rather
  than tacit**: it names itself as the exception, states this reason, and the exception is scoped
  to *writing into the publication area* — not to a script, and not to a kind of item. A creator
  that could write elsewhere gets no carve-out for choosing not to.
  *Why the carve-out is written down instead of the behaviour being changed:* the alternative is a
  creator that appears inert and silently drops what it wrote, which is worse than either honest
  option — and **an implementation that deviates from its own contract sheet without the sheet
  saying so is a contradiction a reader must resolve by guessing.** Preserve the reason, narrow the
  conclusion ([`../doctrine/supersession.md`](../doctrine/supersession.md)).

## 3. REFUSAL CONDITIONS

- No identifier supplied ⇒ refuse; do not mint one silently.
- The identifier is malformed, or already in use on the board ⇒ refuse (already-retired ⇒ warn
  loudly, per [id-minting.md](id-minting.md)).
- The template for the requested kind is missing ⇒ refuse; **never** fall back to writing an
  ad-hoc shape, because that shape immediately becomes a second definition.
- An item with the same name already exists ⇒ refuse rather than overwriting. Overwriting a
  description of work is data loss with no undo in the reader's hands.
- A decomposition names a parent that does not exist ⇒ refuse.
- **An argument standing in a NAME's position that carries an option's syntax — a leading dash —
  ⇒ refuse, non-zero, naming the position it was standing in.** A dash-leading token is never a
  name, in any position, however plausible it looks.
  *Why:* the failure this replaces was not a refusal — it was an **acceptance with a success
  message**. A help request was consumed as the item's short name; a requirement was created
  under a nonsense identifier; the tool printed *"Created:"*; and the identifier was burned before
  anyone read the file. A wrong argument that is accepted quietly is worse than one that halts.
- **A request for the usage text is ALWAYS legal and ALWAYS succeeds** — it is answered before any
  argument is interpreted, and its exit status says success.
  *Why:* if asking how to use the tool can fail, or can do work, the first thing a new adopter
  types is a mutation.
- **An unrecognised option ⇒ refuse, non-zero, naming it** — never ignored, never treated as a
  positional value.

## 4. WHAT GREEN MEANS

1. **Exactly one** new item exists, in the starting state, and its path is printed.
2. Its header carries **every declared key**, and its identifier **matches its name** — checkable
   by reading the file, and checked in bulk by the drift report.
3. **Nothing else changed**: no other item, no board state, no publication.

## 5. MINIMAL INTERFACE

**In:** the item kind, a validated identifier, a short name, and the kind's own optional links
(a parent, a requirement, a story set).
**Out:** the created item's path, and a non-zero exit for every refusal above.
**Not in:** the content of the work. A template that pre-writes the plan is a template nobody
edits.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/new-issue.sh`, `scripts/new-bug.sh`, `scripts/new-refactor.sh`,
  `scripts/new-prd.sh`, `scripts/subtask.sh` — KIT-CLASS: KIT, one per item kind.
- The templates themselves live under the agent-harness directory (`.claude/templates/`), which is
  path-pinned; the manifest names them, and the initializer stamps them.
- The identifier-substitution invariant in § 2 is a real incident's lesson, recorded in
  [`../EXTRACTION.md`](../EXTRACTION.md) § 2.
