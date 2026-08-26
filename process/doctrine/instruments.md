<!-- KIT-CLASS: KIT — transferable doctrine. § A is the pattern; § B is the fill-in for YOUR instruments. The worked example is this kit's own harness, so nothing here needs anonymizing. -->
# Instrument doctrine — an instrument is believed only when it has been watched failing

**What this governs.** Anything whose job is to *notice*: a guard, a gate, a drift report, an
oracle, a probe, a monitor, an audit, a test that stands in for a class of behaviour. One rule
underneath all of it — **a green from an instrument nobody has watched fail is not information** —
and three consequences that are each expensive to learn the hard way.

**Why its own sheet.** [`negative-claims.md`](negative-claims.md) governs **making** a claim, at
authoring time, and says of a registration with no falsifier that it "is not a weaker guard; it is a
suppression file with better manners." This sheet governs the moment before that: **whether the
check behind the claim can see anything at all.** Different moment, different reader — one is read
while writing a sentence, this one while building the thing that would catch the sentence being
wrong. Folding either into the other buries it under a heading nobody opens at the moment it
matters. Separate sheets, mutual pointer.

It is also the general form of two rules that arrived in
[`dogfooding.md`](dogfooding.md) (§ A.2, § A.16) and were promoted here because they bind every
guard author, not only whoever runs a round.

---

## § A — The pattern

### A.1 — Measure the instrument against the shape it will MEET, not the shape it was built from

An instrument watches for the signal **its author had in mind**. That is not a flaw in the author;
it is the definition of building one. The consequence is structural: if the thing being watched has
a paved path and an unpaved one, an instrument modelled on the paved path is precise for paved-path
subjects and **blind to everyone else** — and the unpaved cases are exactly the ones worth
catching, because they are where behaviour is unconstrained.

So, before an instrument is believed:

- **Take it to the messiest realistic input you can construct**, and check it still fires. Not a
  fixture written to satisfy it — a fixture written to defeat it.
- **Better, take it to real leftovers**: the output a real subject actually produced, from a
  previous run, incident or round. A fixture its author wrote is a fixture shaped by the same
  imagination that shaped the instrument.
- **A guard is believed only when watched behaving correctly on the exact shape it will meet.**
  Anything less is a claim about the fixture.

### A.2 — A negative check is not verification: every green owes an ablation

Verifying that the wrong thing is **absent** never establishes that the right thing is **present**.

- *"No forbidden vocabulary in the configuration"* is not *"the configuration works."*
- *"The content is missing from the read-back"* is not *"the write did not land."*
- *"The audit returned no violations"* is not *"the audit can see this violation."*

**Every audit owes both halves**: absence of the wrong thing **and** presence of the right thing,
with the presence half **exercised** — by a probe, or an **ablation**, that *fails when the
capability is missing*. The habit to build, asked of every green check: **"what would this look
like if the thing I need were simply not there?"** If the answer is "exactly the same", the check
is decoration.

This is the cheapest rule on this sheet and the most frequently broken. Expect to break it.

**The ablation shape, concretely.** Remove the logic under test from a copy, re-run the case against
input that *did* produce a finding, and assert the finding **disappears**. That makes a subsequent
pass attributable to the logic rather than to whatever the surrounding machinery happened to print.
Two details are load-bearing: **ablate a copy, never the live instrument**, and **check the ablated
copy still runs at all** — an ablation that breaks the harness proves nothing except that it broke.

### A.3 — Sometimes a capability probe is the WRONG instrument, and that decision is recorded

A.2's probe can itself be the defect. If a case guards its own subject with *"does this check still
exist?"*, then **deleting or refactoring the check away turns the case from a FAIL into a SKIP** —
the guard reports "not applicable" at the precise moment its subject vanished, which is the failure
mode it existed to prevent.

So the rule is not *"always add a capability probe"*. It is: **choose, and record the choice in the
instrument itself.**

- Probe where the capability is a genuine **environment** fact — a tool that may not be installed,
  a credential that may be absent, a surface this project may not have. A missing environment is
  honestly a SKIP.
- **Do not probe** where the capability is the **subject** — the check, the guard, the behaviour
  under test. There, absence must be a FAIL. Write the reason next to the case, so the next reader
  does not "fix" the gap by adding the probe that breaks it.

### A.4 — Name the blind spot in the instrument's OWN output

Every instrument has a blind spot. The only question is whether it is **named**, and named where it
will be read: **in the instrument's own output**, beside the verdict — not in a design document, not
in a commit message, not in someone's memory.

A reader who meets a silent or surprising green must find the explanation *there*, at the moment of
confusion. **A blind spot recorded is a limitation; a blind spot unrecorded is a defect that will be
found again, at full price, by whoever trusts the green next.**

The same applies to a deliberate narrowing: a check that scans the last N items, samples rather than
enumerates, or skips a class by design, **says so in the line that reports its result**. Silent
truncation reads as "covered everything."

---

## § B — Your project's instance — **fill this in**

> **PROJECT INSTANCE from here down.** Nothing here is inherited. On day one this section is
> correctly empty.

1. **Your instruments**, one row each: what it watches, and its **named blind spot** — plus where in
   its own output that blind spot appears (§ A.4). `<fill-in>`
2. **Which of them have been ablated** (§ A.2), and where the ablation lives. An instrument with no
   ablation is listed here as **unproven, not passing**. `<fill-in>`
3. **Your probe-or-fail rulings** (§ A.3): each case that deliberately carries **no** capability
   probe, and the one-line reason. `<fill-in>`
4. **The real leftovers you keep as test material** (§ A.1) — where they are, and which instrument
   each set was used to defeat. `<fill-in>`

---

## § C — Worked example: this kit's own self-test harness

> Not anonymized, because it is ours. Read `scripts/test/run.sh` alongside this.

**The ablation (§ A.2), done properly.** The harness's board-checker cases do not merely assert that
a drift finding appears. A control leg **strips the check under test out of the sandbox's copy** of
the drift report, re-runs a board that *did* produce a finding, and asserts the finding is **gone** —
so a passing leg is attributable to the check's logic rather than to any output the script happened
to emit. It also refuses to proceed if the ablated copy no longer parses, and if the ablation
removed nothing. That is § A.2's presence half, exercised.

**The probe that was deliberately NOT written (§ A.3).** Two of those same cases carry an explicit
note that there is **no** grep-probe asking whether the drift report still contains the check — the
reasoning being that such a probe "would turn the check being deleted or refactored away into a SKIP
instead of a FAIL." The decision and its reason are recorded **in the harness**, next to the cases
they govern. That comment is where this sheet's § A.3 came from.

**And the failures the same harness had, which are § A.1 exactly.** Its sandbox fixtures were built
from the shape the kit ships, so they assume ship state: run inside a project that has actually been
initialized, the initializer cases fail rather than skip, because the fixture copies a
already-stamped configuration; and one case's fixture already declared the very gate the case
existed to prove was refused, so the leg returned green having graded nothing. Both were found by
running the harness somewhere its author had not — which is § A.1's whole instruction.

**And a § A.2 breach in a shipped instrument.** The drift report prints *"every scanned subject
carries a role prefix"* on a repository with **no history at all** — a green whose honest reading is
*nothing was scanned*. The fix is the one this sheet prescribes: a check whose input is unavailable
reports **skipped, with the reason**, never a pass.
