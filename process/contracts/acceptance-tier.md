<!-- KIT-CLASS: KIT — contract sheet: the acceptance (conformance) tier and its floor guard. See process/EXTRACTION.md. -->
# CONTRACT — the acceptance tier

## 1. PURPOSE

To keep a standing, countable answer to *"which of our tests would still have to pass if this
product were built again from its own documents?"* — so that the claim *the corpus is sufficient*
can be **measured** instead of believed.

## 2. HARD INVARIANTS

- **A TIER MEMBER MUST SURVIVE A REWRITE FROM THE CORPUS.** The single question that decides
  membership: *if this test fails after the product is rebuilt from its documents alone, is the
  product wrong, or merely different?* Product wrong ⇒ member. Merely different ⇒ not a member.
  *Why:* without one question the tier becomes a taste ranking, and a taste ranking cannot be
  audited by the next reader.
- **TWO TIERS, AND ONLY TWO — unmarked is the default and is never a defect.** A test that fits
  neither is a **finding to record**, not a licence to invent a third category.
  *Why:* a third bucket absorbs every hard case, and the hard cases are the only ones the tier was
  built to expose.
- **THE TIER IS A LENS, NEVER A GATE.** No gate, release ritual or routine run may select on
  membership, and nothing may run **less** of the suite because the tier exists. It adds a way to
  ask a question of the suite, never a way to shrink it.
  *Why:* the moment membership decides what runs, every author is under pressure to mark for speed
  rather than for truth, and the answer stops meaning anything.
- **MEMBERSHIP IS DECIDED AT WRITE TIME, BY WHOEVER WRITES THE TEST.** Never by a later
  reclassification pass, and never by a separate triage body.
  *Why:* the author is the only person who still knows which promise the test was defending; a
  retro-sweep is the failure mode this rule exists to forbid.
- **THE MARKED SET IS A FLOOR, NOT A CENSUS.** Whatever is unmarked is **unexamined**, not judged;
  an incomplete classification must be declared as such wherever the total is published.
  *Why:* a partial pass presented as complete converts an honest gap into a false claim of
  coverage, which is worse than the gap.
- **A PUBLISHED TOTAL CARRIES THE MEASUREMENT THAT PRODUCED IT.** Any count is stated together with
  the way it was derived, so a reader can re-derive it; a transcribed number is treated as
  unverified.
  *Why:* counts drift the instant the suite moves, and a stale digit in the document whose job is
  to be true when read is the defect that costs the most trust.
- **AN ARTIFACT WHOSE EXACT FORM A LEGITIMATE REWRITE MAY RESHAPE IS EVIDENCE, NEVER A MEMBER.** A
  captured rendering of an output surface pins presentation, so it can never carry the tier's mark;
  its value is evidence, and evidence is a different class from membership.
  *Why:* marking presentation as product guarantees a false alarm on the first legitimate rewrite,
  and one false alarm retires the question for everybody.

### The floor guard — the three assertions any implementation owes

A tier that can silently empty out is not a tier. Any implementation must assert all three, and
each must fail loudly and by name:

- **NON-EMPTY SELECTION, PER DECLARED FAMILY.** There is a declared list of families, and selecting
  by membership returns at least one case for the tier and for every family on that list.
  *Why:* an accidental unmarking is invisible in a green suite — the selection simply narrows, and
  nothing else in the run changes.
- **A COUNT AT OR ABOVE A DECLARED FLOOR — a floor, never an equality.** The floor is stated with
  the reasoning that sized it, and is deliberately set below the measured total.
  *Why:* an equality reddens on every member a colleague **adds**, which punishes exactly the
  behaviour the tier wants; a floor only reddens when the set shrinks.
- **SELECTION-NEUTRALITY — membership changes NO DEFAULT RUN.** The default selection is
  byte-identical to what it was before the tier existed, membership never appears in it, and a test
  already selected by another ring stays selected by that ring and stays out of the default run.
  *Why:* this is the mechanical half of *lens, never a gate*; stated only in prose, it is one
  convenient edit away from being untrue.

## 3. REFUSAL CONDITIONS

- The selection is **empty**, for the tier or for any declared family ⇒ fail, naming the family
  that vanished. A quietly narrower selection is the whole hazard.
- The selected count falls **below the declared floor** ⇒ fail, and report both numbers.
- The default run's selection **differs** with the tier present ⇒ fail: the lens has become a gate.
- Membership is used to run **less** of the suite anywhere ⇒ refuse the change, not the tier.
- A presentation-pinning artifact is found **carrying the mark** ⇒ refuse; it is evidence and
  belongs outside the tier.
- A total is republished with **no way to re-derive it** ⇒ refuse the number, not the document.
- A test answers the membership question **neither way** ⇒ record it as a finding; refuse to invent
  a third tier for it.

## 4. WHAT GREEN MEANS

Green is four numbers and one list, all re-derivable:

1. The **selected total** for the tier, beside the way it was measured.
2. The **per-family counts**, against the declared family list — every family non-empty.
3. The **declared floor**, and the total standing at or above it.
4. The **default run's selected count with and without the tier present** — identical, and the same
   for every other ring the suite already had.

A statement that the tier "passed" without those numbers is not a result.

## 5. MINIMAL INTERFACE

**In:** the corpus manifest (what a rewrite would be handed); the suite, each test carrying its own
membership metadata; a declared list of families; one declared floor with its sizing reason.
**Out:** the selected total; the per-family counts; the floor verdict; the default-selection
comparison; and the list of recorded findings — tests that answered neither way.
**Not in:** any power to deselect, skip, reorder or shorten a run. Membership is metadata that is
read, never a selector a gate obeys.

## 6. REFERENCE IMPLEMENTATION

> **Deliberately non-travelling — this sheet has no shipped implementation to point at.**

- **Sections 1–5 above are the whole spec.** A tier is carried in whatever a test runner offers —
  a marker, a tag, a category, a build tag — and that mechanism transfers to nothing: a marker is
  one runner's idea. An adopter marks membership in their own runner and owes the **three
  floor-guard assertions** in their own harness. Nothing else.
- Three things an implementation needs a home for, wherever your stack keeps them: **where the mark
  is registered**, **where the default selection is defined** (so selection-neutrality can be
  asserted against it), and **the constant carrying the floor plus its sizing reason in a comment**.
- [`../doctrine/conformance-tier.md`](../doctrine/conformance-tier.md) — the reasoning, the marking
  convention, the UI seam, and the place a project records which families it marked.
- [`../doctrine/calibration.md`](../doctrine/calibration.md) — the available rituals that exercise
  this contract end to end. Neither ritual may amend the tier, mark a test, or move a floor.
