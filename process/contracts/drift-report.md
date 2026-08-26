<!-- KIT-CLASS: KIT — contract sheet: the drift report. See process/EXTRACTION.md. -->
# CONTRACT — the drift report

## 1. PURPOSE

To answer *"is the board telling the truth?"* on demand, by checking the small set of
disagreements this process can actually produce — before a human plans a day around one of them.

## 2. HARD INVARIANTS

**Six checks. Each is an invariant of the process, not a feature of a report; a reimplementation
owes all six, in any presentation it likes.**

- **1 — Location agrees with the record.** For every live item, the state declared by its last
  activity entry is the state it is actually in.
  *Why:* these two disagree only when someone moved an item by hand, and that is exactly the
  event no other check can see.
- **2 — The reviewed-and-done column is within its depth threshold.** Over it, a sweep is due and
  the report names the sweep.
  *Why:* an unbounded terminal column turns the board back into a list, which is the state the
  board was introduced to fix.
- **3 — The running narrative log is within its size threshold.** Over it, a rotation is due and
  the report names it.
  *Why:* a log nobody can open is a log nobody reads, and the process's memory is in it.
- **4 — Identifier integrity across EVERY state, not just the active ones.** Every item declares
  an identifier; identifiers are unique across the whole lifecycle; each item's declared
  identifier matches its own name.
  *Why:* a duplicate identifier makes every reference ambiguous, and it is created by a rename or
  a copy — both of which look innocent at the time.
- **5 — Recent history is attributed.** Every commit subject in a recent window carries a
  declared role, and the check understands collapsed commits so a landing is judged by its own
  subject.
  *Why:* attribution erodes one unnoticed commit at a time; a periodic count is what makes the
  erosion visible while it is still small.
- **6 — The publication path is not holding unpublished work.** Whatever mechanism publishes
  board changes to the trunk must not be sitting on commits the next operation would discard.
  *Why:* the next operation resets that mechanism to the trunk, so an unpublished commit there is
  work with a scheduled deletion date.
- **The report READS ONLY.** It never fixes, moves, rotates or publishes anything.
  *Why:* a reporter that repairs is a reporter nobody can trust to describe.
- **A check that cannot run says SKIPPED, and says why.** It never reports a pass it did not
  establish.
  *Why:* "no findings" must mean "checked and clean", or the report's only sentence is worthless.
- **A threshold check states WHAT IT MEASURED, not only its verdict.** A check reporting a size or
  a depth names the span it read.
  *Why:* measured — one implementation's log-size check read only the running log's own section
  while the file around it grew to thirty times that span, and reported a comfortable pass the
  whole time. *The measuring device reported OK while blind*, and the verdict alone could not
  reveal it.

## 3. REFUSAL CONDITIONS

- An item carries no identifier at all, or carries one that duplicates another's ⇒ report it by
  name, in both cases, as a finding that needs a human.
- A check's input is unavailable (no history, no publication mechanism, offline) ⇒ report
  **skipped with the reason**; never silently omit the line.
- Findings exist ⇒ the report says so in its final line. Whether findings *fail* a build is the
  project's call; **hiding** them is not on the menu.

## 4. WHAT GREEN MEANS

1. **All six checks ran**, each printing its own line — a missing line is itself a finding.
2. Each line states a **count against its bound** where it has one, not an adjective, and names
   the span the count covers.
3. The last line is a **single verdict**: clean, or findings-above. One sentence a human can act
   on without reading the rest.

## 5. MINIMAL INTERFACE

**In:** the board; the running log; recent history; the publication mechanism's state; the
declared thresholds.
**Out:** one line per check with its count or its skip reason, then one overall verdict line.
**Not in:** any repair. Every finding names the operation that fixes it and stops there.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/check-board.sh` — KIT-CLASS: KIT. The six checks are its sections **[a]** through
  **[f]**, in the order above.
- Its thresholds are named constants at the top of that file — **a seam, not a contract term.**
  Two exist: the depth at which the reviewed-and-done column is due for a sweep, and the byte size
  at which the running log is due for rotation. **Read them from the file** rather than from any
  document; the log-size one is also the constant
  [`../doctrine/lookup-tables.md`](../doctrine/lookup-tables.md) § A.1 reuses for its index
  trigger, deliberately, so that one idea does not carry two numbers.
- Check 5 derives the legal role set from the enforcing rule rather than restating it; see
  [commit-attribution.md](commit-attribution.md).
