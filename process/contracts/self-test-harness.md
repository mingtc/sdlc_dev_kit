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
- **A case asserts THE KIT'S FRAME, never one installation's configuration — and the sandbox
  reaches that deliberately, for every seam it copies in.** The machinery is copied in from the real
  tree, which is what makes the test real; the seams that came with it are then handled one of two
  ways, chosen per seam: **RESET** the seam to the kit's shipped value, or **DERIVE** the
  expectation from the seam instead of naming a literal. A third way is never legitimate — copying
  a seam in and then asserting a value only the shipped tree satisfies. **A reset asserts its own
  postcondition; a derivation is used at EVERY site that names that value.**
  *Why:* measured three times, and each time the miss was in the part nobody remembered. A fixture
  that copies an adopter's tree in and neutralizes only *part* of it produces cases that assert that
  project's configuration — or that fail on it — while reporting on the kit, and the seam it missed
  is **silent**, because nothing checks a seam nobody listed. The postcondition is what carries the
  reset half: it makes the next missed seam loud rather than invisible, and it must hold on an
  unconfigured tree too, where the correct behaviour is to change nothing. The every-site clause
  carries the derivation half, and it is the one that looks done when it is not: **a value derived
  once and hardcoded at its other call sites is the same defect as never deriving it**, and it
  fails only in the projects that configured that seam — which is to say, never here. Both halves
  are the complement of the DECLARED-adopter-fact invariant below: that one governs a case that
  pins an installation's fact **on purpose**, this one governs a fixture that hands it one **by
  accident**.
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
- **THE SAME RULE ONE LEVEL DOWN: a case that QUANTIFIES emits its own count, and something
  compares that count to a declared number.** The invariant above governs the *suite's* total. It
  says nothing about a single case whose name promises a population — *"checks the rule across
  three inputs"*, *"every spelling is refused"* — and that is where the count goes wrong invisibly,
  because the suite's total is unaffected by a case that quantified three and ran two.
  **A number in a case's name or docstring is prose; a number the case prints is an operand.**
  *Why:* measured — a case claiming three inputs ran two and skipped the one that broke the rule,
  and passed. Nothing could have caught it: the suite counted the case, not the case's own loop.
  *And the reason it must be a SEPARATE comparison, not a self-check:* a case that emits `n` and
  also asserts `n == 3` from its own body restates its premise (`process/doctrine/instruments.md`
  § A.8's *restated premise*). The declared number lives where a reader edits it deliberately.
- **A GUARD IS NOT ARMED UNTIL ITS ABLATION IS AN ARTIFACT — a file another reader can run, not a
  habit and not a comment.** `process/doctrine/instruments.md` § A.2 establishes that every green
  owes an ablation; this invariant is about **where the ablation lives**. An ablation performed once
  at authoring time and described in prose afterwards is indistinguishable, to every later reader,
  from one that was never performed.
  *Why:* an ablation's whole value is that it is **re-runnable against a tree that has moved.** The
  guard it proved is still green a year later; the question is whether it is still green *for the
  same reason*, and only an artifact can be re-asked. Prose asserting the ablation happened cannot
  go red.
  **The shape to copy, where the guard has more than one red:** a **declared expected-red set**, one
  entry per red with its reason, and a refusal on any difference in **either** direction — including
  a declared red that has gone green, because the reason is then stale and the entry must go.
  **This invariant is NOT a gate, and that is a ruling rather than an omission** — see § 6.

## 3. REFUSAL CONDITIONS

- The sandbox cannot be created — or a seam's reset cannot be applied or cannot be verified, or a
  seam a case depends on can be neither reset nor derived ⇒ refuse, naming what could not be done;
  never fall back to running anywhere else, and never continue against a sandbox that is not the
  shipped frame.
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
  marked as such in [`../EXTRACTION.md`](../EXTRACTION.md) § 1.1, whose "Take but EDIT" table carries
  the row *"any case family that pins **your** facts"* — a class, deliberately not an enumeration,
  because a list of families would go stale the first time one was added. An adopter edits or drops
  those, and expects them to be the first to redden after an extraction.
- The marker invariant in § 2 is the other half of the lesson contracted in
  [landing-gate.md](landing-gate.md): the landing gate refuses a caller-supplied gate command
  unless this harness has set the marker.
- **The ablation-is-an-artifact invariant is doctrine, NOT a gate, and the ruling has a
  measurement behind it.** The obvious mechanisation — refuse a run in which any case lacks a
  companion ablation — was considered and rejected. **Derive the split on your own tree before
  reasoning about it**, because it moves with every case added, and no number for it is written
  here (`doctrine/staleness.md` § C):

  ```sh
  # cases defined
  grep -cE '^case_[a-z_]*\(\)' scripts/test/run.sh
  # of those, the ones carrying an ablation IN THEIR OWN BODY — the closing-brace reset is
  # load-bearing: without it the last case name carries past the function and mentions in the
  # comments between cases are attributed to whichever case happened to precede them.
  awk '/^case_[a-z_]*\(\)/{n=$1; inb=1} /^}/{inb=0; n=""} /[Aa]blat/{if(inb && n!="")print n}' \
    scripts/test/run.sh | sort -u | wc -l
  ```

  Run on the reference implementation the day this invariant landed, the second number was a **small
  minority** of the first. A gate would refuse every run until the remainder is written, which on
  any adopter's tree is a larger wall still — **and a gate whose cost is a wall gets disabled, after which a
  disabled gate reads as armed.** That is the exact failure this invariant exists to prevent,
  committed by the enforcement of the invariant.
- **The general rule that ruling is an instance of**, and it is worth more than the ruling:
  **a check that is mechanically decidable may be a gate; a check that is heuristic must be
  advisory, and must publish its own precision.** Shipping a heuristic as a gate is the same error
  as an over-promising test name — a claim wider than the predicate — committed by the guard
  instead of the test. *Measured:* a detector for checks whose name promises a population flagged
  thirteen, of which **one** was a defect. At that precision a gate is disabled inside a week; a
  list beside its own hit rate is a useful artifact at the same accuracy, because the reader can
  spend attention where it pays. **The output half of this — that the artifact must itself say
  whether it is a judgement or a pile of candidates — is
  [`../doctrine/consumer-output.md`](../doctrine/consumer-output.md) § A.4.**
- **What none of this covers, stated because pretending otherwise is worse.** No assertion about a
  number can see a **comprehension** defect. The measured case: a report with a fully green suite
  and arithmetically perfect output showed a reader the amount due twice and never the amount paid.
  Every number was correct and the artifact was unusable. **A class this harness cannot reach wants
  a named second reader, not a wider suite** — and no green here may be read as evidence that a
  product is usable.
