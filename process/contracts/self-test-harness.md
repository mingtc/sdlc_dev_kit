<!-- KIT-CLASS: KIT — contract sheet: the process self-test harness. See process/EXTRACTION.md. -->
# CONTRACT — the process self-test harness

## 1. PURPOSE

To test **the process machinery itself** — the board mover, the landing gate, the sweep — against
a disposable repository, so that the tools that guard the project are themselves guarded.

## 2. HARD INVARIANTS

- **Every case runs against a THROWAWAY repository, never the real one.** The sandbox is created
  for the run and destroyed with it.
  *Why:* these tools move, merge, delete and publish; a case that pointed at the real repository
  would be indistinguishable from an accident until it happened.
- **The sandbox includes its own publication target.** The tools under test publish for real,
  into a target that exists only for the run — a local bare repository is exactly right.
  *Why:* the publication step is where these tools do their most dangerous work, and stubbing it
  out tests everything except the part that matters.
- **No case reaches the network, a real remote, or a live credential.**
  *Why:* a self-test that needs the outside world is a self-test that stops being run.
- **Accounting is EXPLICIT: passed, failed and skipped are counted separately and all three are
  printed.** A skip is never folded into a pass.
  *Why:* a suite that hides skips slowly becomes a suite that runs nothing and reports success.
- **A capability the environment lacks makes a case SKIP LOUDLY, with its reason.** It never
  silently passes.
  *Why:* the skipped case is exactly the one the next reader assumes was covered.
- **A test-only relaxation of a production rule is reachable ONLY behind an explicit marker that
  no production caller sets.** The harness sets it; nothing else does.
  *Why:* the stub that lets a case run fast is, in production, the hole that lets an unproven
  change land — the two are the same mechanism and only the marker separates them.
- **The harness makes NO claim about the project's own code.** It tests the process machinery,
  and says so.
  *Why:* conflating the two produces a green suite that proves the wrong thing.
- **A case that pins an adopter-specific fact is DECLARED as such.** Cases coupled to one
  installation are named so an adopter can edit or drop them without guessing.
  *Why:* an adopter who inherits red cases they cannot interpret abandons the harness on day one.
- **The case count is DERIVED, never transcribed.** The run's own summary and an independent count
  of the defined cases must agree, and neither number is written into a document.
  *Why:* measured twice — a manifest stated a case count as a "measured, not estimated" fact and
  it had already drifted by the time anyone re-ran the two commands.

## 3. REFUSAL CONDITIONS

- The sandbox cannot be created ⇒ refuse; never fall back to running anywhere else.
- A case would touch the real repository or a real remote ⇒ that is a defect in the case, and the
  frame must make it impossible rather than discouraged.
- Any case fails ⇒ the run is red, and the failing case is named.
- The count of cases the run discovered is zero ⇒ refuse. A suite that selected nothing must never
  report success.

## 4. WHAT GREEN MEANS

1. The run prints **passed / failed / skipped as three numbers**, and failed is zero.
2. The number of cases that ran equals the number the tree declares — an independent count of the
   defined cases matches the reported one.
3. The sandbox is **gone** afterwards, and the real repository is byte-identical to before.

## 5. MINIMAL INTERFACE

**In:** the process machinery under test; a disposable working area.
**Out:** one line per case, then the three counts, then a non-zero exit if any case failed.
**Not in:** the project's own product tests. Different subject, different runner.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/test/run.sh` — KIT-CLASS **MIXED**: this sheet describes the **kit half** (the
  disposable sandbox with its own publication target, the three-way accounting, the capability
  probes, the test-only marker). Any case family that pins one installation's own facts is
  enumerated as such in [`../EXTRACTION.md`](../EXTRACTION.md) § 1 — an adopter edits or drops
  those, and expects them to be the first to redden after an extraction.
- The marker invariant in § 2 is the other half of the lesson contracted in
  [landing-gate.md](landing-gate.md): the landing gate refuses a caller-supplied gate command
  unless this harness has set the marker.
