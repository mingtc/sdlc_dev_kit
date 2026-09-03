<!-- KIT-CLASS: KIT — the handoff convention. Travels unedited; it names no project. -->
# `dev/handoffs/` — seat-to-seat handoffs

A handoff is what one seated instance leaves for the next: **where the work actually stands**, what
is in flight, what is stranded, and what the next reader must not re-derive.

**Filename: `YYYY-MM-DD-<kind>.md`** — the date first, so an `ls` sorts chronologically and the
newest is the last line. Useful kinds: `architect`, `succession` (the seat is changing hands),
`standing-handoff` (see below).

## The convention: NEWEST HANDOFF WINS

**The newest file in this directory is the plan-of-record**, together with the board (`progress/`).
Every older handoff is a dated snapshot of a moment that has passed — accurate as of its date, kept
as background, **not maintained**.

Three consequences, and they are the whole convention:

1. **No handoff is ever edited to stay current** (with one exception, below). Correcting an old
   handoff makes two documents claim to be current, and the reader cannot tell which won.
2. **A new handoff does not summarize its predecessors.** It states what is true now and cites the
   older one where the reasoning lives. A handoff that re-tells the whole history is a handoff
   nobody finishes reading.
3. **A handoff carries what is NOT written down anywhere else.** Anything already stated in a
   ruling register, a contract sheet or an issue file is *cited*, not copied — a copy in a handoff
   goes stale the moment the original is amended, and it will win arguments it should lose.

## When to write one — while sharp, not while failing

**A coordinator's judgement degrades as its context fills, and it degrades *before* that becomes
obvious.** So the moment to write the handoff is the point where you would still call your own
judgement good — not the point where you need one. A handoff written from a spent context is a
handoff that records the wrong things: it summarizes instead of pointing, it re-derives what was
already settled, and it omits the one item the next reader needs first, because the writer can no
longer tell which item that is.

There is no clean signal for the moment, which is why this is a habit rather than a trigger: write it
at a **natural boundary you chose in advance** — an arc closing, a phase landing, a decision batch
answered — rather than when the session starts to feel long.

*(The reasoning is [`../../process/doctrine/subagent-control.md`](../../process/doctrine/subagent-control.md)
§ A.12, which also names what makes a handoff valuable: not being current, but **being explicit about
what in it is already stale.** A handoff stamped with what it no longer answers is worth several that
are merely current — and that is the one thing the newest-wins rule ABOVE cannot supply on its own,
since it tells a reader which file to trust and nothing about which parts of it have expired.)*

## What a handoff must contain

At minimum, and in this order:

- **The single most important thing the next reader does not know.** Put it first, in one sentence.
- **In flight** — what is mid-change: which work items, which branches, which are landed vs
  land-ready vs stranded, and the exact commands to finish each one. "Stranded" needs its location:
  a local commit nobody has pushed is invisible to everybody but the machine holding it.
- **Blockers** — anything that will stop the next session dead, with what has already been ruled
  out. A blocker described without the failed attempts costs the next reader the same attempts.
- **Standing rulings made this session** — as *pointers* into the ruling register, which is where
  they were authored. If a ruling was made and not authored anywhere, that is the handoff's most
  urgent item.
- **What is deliberately NOT being done**, and why — otherwise the next seat helpfully does it.
- **A key-file lookup table** for the arc in progress: the five or ten paths a newcomer to this
  work would otherwise spend an hour finding.

## The standing-handoff pattern

Sometimes an arc of work runs long enough that a dated snapshot per session is worse than useless —
the reader has to diff five handoffs to learn the current state. For that case, and only that case:

**One file, named `YYYY-MM-DD-standing-handoff.md` and dated for the day it was created, is marked
LIVING and updated in place for the duration of the arc.** It is the sole exception to "no handoff
is ever edited".

Its terms:

- **It says LIVING in its own first lines**, together with the arc it covers and the condition that
  ends it. A living document that does not announce itself is just an edited snapshot.
- **It stays the newest file in the directory** while it is live, so the newest-wins rule still
  points at it. If a genuinely dated handoff has to land during the arc, the standing handoff is
  re-dated in the same change and says why.
- **It is CLOSED, not deleted, when the arc ends**: struck to a dated snapshot with one line saying
  what superseded it. It stops being living the moment the arc it named is over, and the strike is
  what records the reason it existed.
- **It is not a second board.** Live status belongs in `progress/`; the standing handoff carries the
  arc's reasoning, its ops laws, and the sequence to finish it.

## Index

**This directory gets one row in [`../README.md`](../README.md), in the change that creates the
directory — and the row points here. Its members are indexed by this README and by their dated
filenames, not by rows up there.**

*This paragraph used to say "every file here also gets a row" — per file. **The granularity was
wrong; the reason was not**, so the reason is kept: the index discipline is bidirectional, nothing
under `dev/` exists unindexed, and a directory admitted as a single **location** row is exactly what
makes that true here. What changed is that the row is the directory's, not the file's — because this
directory **already has** a member index. `YYYY-MM-DD-<kind>.md` makes `ls` sort chronologically and
the newest the last line, which is this README's own opening convention; a table restating what `ls`
prints is a second copy, and the copy is the one that disagrees after either is amended.*

**Where this argument does NOT transfer:** a directory whose member names carry no ordering has no
index of its own, and per-file rows are then the right answer **for that directory**. The rule is
*a directory needs one member index*, not *directories never get per-file rows*.
