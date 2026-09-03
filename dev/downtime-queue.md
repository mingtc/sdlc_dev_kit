<!-- KIT-CLASS: KIT — the queue's shape and its instituting rule travel; every row is yours. -->
# The downtime queue — deferred-but-genuine improvements

> **The instituting rule.** Work we deliberately did **not** do now goes **here**, rather than
> vanishing into an audit footnote — *including items with no beneficiary today, if they are genuine
> improvements.* The reason is that a deferral recorded nowhere is indistinguishable from a
> deferral nobody ever made: the next audit rediscovers it at full price, or worse, someone
> silently does it inside unrelated work.
>
> **Three clauses bind every row:**
>
> 1. **Re-assessed at downtime**, not on a schedule and not on a hunch.
> 2. **Anything picked up goes through the normal mint → Dev → QA path.** This file is an *index*,
>    not a backlog: issues still enter through a PM session, and a row here is not a mandate.
> 3. **Nothing here is licensed to ride along with other work.** An improvement that arrives as a
>    passenger in someone else's change has no acceptance criteria and no reviewer looking at it.

## How to write a row

Every row carries all six fields. The two that get skipped are the two that matter:

- **Why deferred** must be the *reason*, not the fact — *"deferred"* is not a reason. If a person
  ruled on it, quote the ruling.
- **Wake condition** must be a **condition, not a date**: something observable that says *now*.
  *"Later"* and *"next quarter"* are how a queue becomes a graveyard. `Downtime` is an acceptable
  condition; *"when X flakes in anger"*, *"when the next issue touches Y"*, *"if the measured count
  resumes growing"* are better.

**Sizes** are the same ladder the board uses (S / M / L — `XS` belongs to the *model-provisioning* effort ladder and no card template offers it), and an *unsized* row says
`unsized — needs a measurement first` rather than guessing. A row whose size depends on a
measurement nobody has taken is a row that must not be bought yet.

## Removal discipline — strike, never delete

When an item **lands**, strike it here with the work-item id **and its outcome**, including an
honest no-op. When an item is **re-ruled dead**, strike it with the ruling that killed it. Keep the
struck text: the reason a thing was deferred is exactly what the next person needs when the same
idea returns wearing a different name. *(This is
[`process/doctrine/supersession.md`](../process/doctrine/supersession.md) applied to a queue:
preserve the reason, supersede only the conclusion.)*

A struck row that has been read by nobody for a long time may be condensed to its reason and its
outcome — but never to nothing.

**WRITE `open (claimed by <PREFIX>-NNN)` THE MOMENT AN ITEM IS MINTED ONTO THE BOARD**, not at
landing. That is the whole link between this file and the board, and it is what lets a check ask
the one question worth asking: *is any row still `open` whose claiming issue has already landed?*
Without the marker there is no join, and **a stale row looks exactly like a live one** — the cost
is not tidiness, it is a duplicate issue minted for work that already shipped.

**WHAT THAT MARKER CANNOT SEE, stated so nobody believes the check is the whole guard:**

- **A row silently paid by an issue that never claimed it.** The work landed, the row is honest
  about nothing, and no id connects them.
- **A row written for work that already landed.** Mechanically undecidable — nothing in the row
  says when its subject became true. Its only cure is at mint time: *measure the row's subject
  against the trunk before writing the row.*

**And when you count this queue, classify each row's own last cell** — strip markdown emphasis
first, accept any `open…` prefix, and let a trailing `Status:` declaration win over the cell's
opening words. **Then reconcile against a second instrument.** A naive `grep -c "| open |"`
under-reported one adopter's queue by 8 rows of 37.

*This section exists because an adopter shipped this file's discipline and measured what enforced
it: `grep -rln "downtime-queue"` over their whole tree returned exactly one file, the prose that
institutes it. No script read the queue, no test read it, no role doc named it at landing — and it
bit twice in one week, both times as silence (reported by an adopter whose queue had a row reading open for a cure already on the trunk).*

## The queue

| Item | Origin | Size | Why deferred | Wake condition | Status |
|---|---|---|---|---|---|
| `<one bold sentence: what would be done>` | `<where it was raised — an audit, a session, a review>` | `<S/M/L, or "unsized — needs a measurement first">` | `<the reason, quoted if somebody ruled>` | `<an observable condition>` | `<open / open (claimed by <PREFIX>-NNN) / STRUCK — landed as <PREFIX>-NNN, outcome … / STRUCK — ruled dead <date>, because …>` |

<!-- Day one: this table has exactly the header and the shape row above, and that is correct.
     A queue that starts full is a backlog nobody scoped. -->
