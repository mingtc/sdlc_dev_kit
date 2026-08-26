<!-- KIT-CLASS: KIT — contract sheet: the verify gate. See process/EXTRACTION.md. -->
# CONTRACT — the verify gate

## 1. PURPOSE

To make *"is this repository healthy right now?"* a **single question with a single answer**, so
that no role ever re-derives the check set from prose and no two roles run a different one.

## 2. HARD INVARIANTS

- **One canonical entrypoint.** Every role, agent and automated caller asks the same runner the
  same way; there is no second, kinder path to the same claim.
  *Why:* two entrypoints become two definitions of green, and the weaker one wins the moment
  someone is in a hurry.
- **A fixed, declared check set, run in a fixed order.** The set is readable without running
  anything, and the order is deterministic so two runs of the same tree agree.
  *Why:* a check set that depends on invocation order or on the caller's environment cannot be
  cited as evidence by anyone but the person who ran it.
- **The check set is DECLARED SEPARATELY from the frame that runs it.** The preflight, the fixed
  ordering, the summary block and the narrowed mode are the kit's shape; *which* checks exist is the
  project's law. They are two different things and want to be readable as two different things —
  a table of gates near the top of the runner, and the frame below it.
  *Why:* interleaving them means an adopter cannot replace their half without reading yours, which
  is how a gate runner gets rewritten from scratch instead of configured.
- **The gate reports the suite it ran.** The count of checks executed is part of the output, not
  an inference from the absence of complaints.
  *Why:* a project once stacked a quietness setting on itself and lost the count line — runs
  looked clean while hiding failures, because silence was being read as success.
- **A narrowed run is a DIFFERENT, WEAKER claim, and says so.** An inner-loop mode that runs a
  caller-named subset must state that it is narrowed, and must never be reportable as the full
  answer.
  *Why:* the whole value of a gate is that its name means one thing.
- **A narrowed run still runs the cross-cutting floor, and NO option disables that floor.** The
  always-on set is the checks that redden because of a change made *somewhere else*.
  *Why:* those are precisely the failures a caller-chosen subset is guaranteed to miss, so making
  them optional makes the narrowed mode actively misleading rather than merely weaker.
- **Green is a state of the tree, never of a session.** The gate reads the working tree it is
  pointed at and holds no memory of a previous run.
  *Why:* a cached pass survives the change that broke it.

## 3. REFUSAL CONDITIONS

- Any check in the set fails ⇒ the whole gate is **red**, with the failing check named.
- A check in the declared set **cannot be run at all** (its runner is missing, its inputs are
  absent) ⇒ **red**, never skipped-and-passed. An unrunnable check is an unknown, and an unknown
  is not a pass.
- The caller asks for a narrowed run **and** for the full claim ⇒ refuse; the two cannot be the
  same output.
- A named subset resolves to nothing ⇒ refuse, naming what did not match. Silently running zero
  checks and reporting success is the worst available outcome.

## 4. WHAT GREEN MEANS

**Countable, and printed:**

1. Every check in the declared set **ran** — the number that ran is stated.
2. Every one of them **passed** — the number that failed is stated and is zero.
3. The run's verdict appears as **one summary block**, per-check and overall, in a form a reader
   can quote into a review without re-running anything.

*"It passed"* with no count is not green; it is an assertion. A narrowed run's summary
additionally names the subset it was given, so its output can never be mistaken for the full set.

## 5. MINIMAL INTERFACE

**In:** the repository tree; optionally a caller-named subset (inner loop only).
**Out:** a per-check verdict, the count of checks run, one overall verdict, and a process exit
status that is non-zero for red — so a human and a machine read the same result.
**Not in:** the check definitions themselves. Which checks exist is the project's law; *that
there is one runner, one order and one summary* is the contract.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/verify.sh` — KIT-CLASS **MIXED**: this sheet describes the **kit half** only (one
  runner, fixed order, one summary block, the narrowed mode with its unskippable floor). The
  concrete checks it runs, and the membership of the always-on floor, are the project's law and
  travel with nothing.
- The kit's copy keeps the two halves apart: the gate set is a **declared table** near the top of
  the runner, and the floor's membership is a commented, readable list beside it. Replace the table;
  keep the frame.
- The count-line invariant in § 2 wants a regression test of its own in the project's suite — the
  one guard whose absence is invisible, because its failure mode is a run that *looks* clean.
