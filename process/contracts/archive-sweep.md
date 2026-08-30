<!-- KIT-CLASS: KIT — contract sheet: the archive sweep. See process/EXTRACTION.md. -->
# CONTRACT — the archive sweep

## 1. PURPOSE

To keep the working board **readable** as the project ages, by retiring completed work into an
indexed store — **without ever losing the record it is retiring**.

## 2. HARD INVARIANTS

- **The sweep PRESERVES; it never summarises away.** The retired item is moved whole, with its
  full activity log intact, into the retired store.
  *Why:* the log is the review record and the only evidence the process produced; an archive that
  keeps a one-line summary has destroyed the thing worth keeping.
- **Retirement is by state, never by age.** Only items in the terminal reviewed state are
  eligible, whatever their date.
  *Why:* an age rule eventually retires something that is still open, and the board silently
  loses work.
- **Every retired item gains an INDEX entry, and the index is append-only at a fixed insertion
  point.** One entry per item, carrying at least its identifier, its title and its retirement
  date.
  *Why:* an archive without an index is a folder, and a folder is where records go to become
  unfindable.
- **The threshold triggers, it does not decide** — **and the trigger and the knife must be
  COMMENSURABLE.** Crossing the depth threshold is a signal that a sweep is due; the sweep itself is
  an explicit act. **And the selector the act is performed with must be able to cut at the
  granularity the trigger measures in.** A signal nobody can act on is not a trigger.
  *Why:* the first half is because a sweep that fires on its own moves records while nobody is
  watching, and the first time it is wrong nobody sees it. **The second half is because a trigger
  measured in one unit and a knife that cuts in another produce a due sweep with no expressible
  cut.** Measured: a running log whose threshold is counted in **bytes**, and a rotation whose only
  selector was a **date**. Bytes cross the threshold two or three times in a working day; a date can
  only cut on a day boundary — so the second rotation of the day had everything-before-today already
  gone, matched nothing, and said so. **The tool's success is what made it inert.** The cure is a
  selector in the trigger's own terms — for an entry log, "keep the newest N entries" — not a bigger
  threshold and not a warning.
- **Preview by default; change only when explicitly asked.** The default run states exactly what
  it would move and what it would write, and changes nothing.
  *Why:* the operation is bulk and irreversible-by-hand; a wrong sweep costs more than every
  preview it ever printed.
- **The sweep is one transaction and is published as one commit.** Items, index and any dependent
  trees move together or not at all.
  *Why:* a half-swept board has items whose index entry exists and whose record does not.
- **Dependent trees follow their parent, and only once the parent is retired.** A decomposition's
  children retire with the parent, never ahead of it.
  *Why:* children retired early become unreachable from a parent that is still open.
- **The same discipline governs the running log.** The narrative log is rotated into a dated
  store on the same preserve-and-index rules, never truncated in place. **Explicitly, because "the
  same rules" was read as covering only the preserve half: every rotated chunk gains its own INDEX
  ROW**, carrying at minimum the chunk's identifier, **the span of dates it covers**, and the
  rotation date. The span is the load-bearing field — it is what lets a reader choose a chunk without
  opening any of them.
  *Why:* truncating a log in place is the one archive operation with no recovery — and **a rotation
  that preserves without indexing has not solved the problem, it has exported it.** Measured: a
  rotation whose chunks were "discoverable by listing the directory", which is filenames with no
  spans, so finding a date meant opening chunks until one matched. That is the folder this sheet's
  index invariant exists to prevent, reached by the other half of the same operation.
  [`../doctrine/lookup-tables.md`](../doctrine/lookup-tables.md) § A.6 states the general form, and
  adds the consequence: **a chunk that itself crosses the index trigger owes its own index**, and the
  parent row becomes a pointer to it.
- **A rotation breaks every line-anchored citation into the rotated span, at once.** That is a
  property of the operation, not a bug in it — so the citations into a rotatable document are
  addressed by a stable identifier before the rotation, never by line number
  ([`../doctrine/lookup-tables.md`](../doctrine/lookup-tables.md) § A.4, § A.6).
  *Why:* the breakage is silent and simultaneous; nothing fails, every pointer simply now means
  something else.

## 3. REFUSAL CONDITIONS

- The retired store or the index is missing ⇒ refuse; do not create an index on the fly, because
  a new empty index reads as *"nothing was ever archived"*.
  **Narrowed, and the reason above is exactly what narrows it:** an empty index is a *false* claim
  only when the store already holds retired material. Where the index is missing and **nothing has
  been retired yet**, an empty index is TRUE, and refusing teaches a first-time adopter that the
  tool is broken. So: **index missing and the store already holds retired material ⇒ refuse, listing
  what it holds as the proof** — that listing is what makes the refusal checkable rather than
  asserted, and a backfill recipe is owed with it. **Index missing and the store empty ⇒ the tool may
  create it, carrying a note saying the emptiness was true when written.**
  *The conclusion moved; the reason did not. Both halves are still "never write a claim the tree
  contradicts".*
- The index has no recognisable insertion point ⇒ refuse, saying exactly what heading is expected.
  Appending at a guess corrupts the one document that must stay ordered.
- Nothing is eligible ⇒ say so plainly and exit successfully. Nothing to do is not an error.
  **But "nothing matched THE SELECTOR I WAS GIVEN" is a different fact from "nothing is due", and
  reporting the first as the second is a false all-clear.** So when nothing is eligible **while the
  trigger is still crossed**, the tool says that — naming the measurement and the threshold it is
  against — and does **not** exit as success.
  *Why:* a clean exit saying *nothing to archive* reads as *the artefact is fine*, and the operator
  stops looking. Two instruments then disagree — the board reports a rotation due, the rotation tool
  reports nothing to do — **and the one that reports success is the one whose job was to act.** This
  is the read-time half of [`../doctrine/instruments.md`](../doctrine/instruments.md) § A.9: the tool
  answered its own question correctly, and the reader heard an answer to a different one.
- The publication of the sweep fails ⇒ report that the sweep is committed locally and did **not**
  reach the trunk, and name the recovery.

## 4. WHAT GREEN MEANS

1. **N items moved**, and N is printed — the same N in the preview and in the applied run.
2. **N index entries written**, at the declared insertion point.
3. Every moved item is **byte-identical** to what it was before the move.
4. The sweep is **one published commit**, whose identifier is printed.

## 5. MINIMAL INTERFACE

**In:** the board; the retired store; the index; an explicit apply request.
**Out:** the eligible set, the planned index entries, the moved count, the published commit
identifier — and in preview mode, all of that with nothing changed.
**Not in:** any judgement about the work itself.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/archive.sh` — KIT-CLASS: KIT. The board sweep and the index write.
- `scripts/archive-progress.sh` — KIT-CLASS: KIT. The running log's rotation into its dated
  store, on the same preserve-and-index rules.
- The depth threshold that signals a due sweep is reported by `scripts/check-board.sh`, contracted
  in [drift-report.md](drift-report.md); it is a named constant there — a seam, not a contract
  term.
- **This sweep is NOT the retirement mechanism** of
  [`../doctrine/retention.md`](../doctrine/retention.md): it moves a record into a directory that
  still exists, over the corpus of closed work items, and removes no bytes. The two are separate on
  purpose, and neither one's rules reach the other.
