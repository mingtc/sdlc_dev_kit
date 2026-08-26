<!-- KIT-CLASS: KIT — transferable doctrine. § A is the pattern (two available rituals and what each must declare); § B is the fill-in for YOUR runs. -->
# Calibration doctrine — the rituals that measure whether the corpus and the process actually work

**Everything in this document is an AVAILABLE ritual, never an obligation.** No gate runs it, no
release waits on it, and a project that never performs either ritual is in good standing. What the
two rituals buy is a *measurement* of two claims a kit otherwise only asserts — *the corpus is
sufficient to rebuild the product* and *the process transplants to a project it was not written
for* — and a measurement is worth having precisely because it is allowed to come back negative.
Reach for one when you want the answer, not on a schedule.

They are the acceptance half of the same idea as
[`conformance-tier.md`](conformance-tier.md): the tier states *which tests would have to pass after
a rebuild*, and these rituals are how you find out whether that is true. Run either one and the
tier is the acceptance criterion; read the tier's doctrine first.

---

## A. The pattern

### A.1 Ritual one — the REGENERATION SPIKE (does the corpus rebuild the product?)

**The question:** hand a competent worker the corpus and nothing else — can it rebuild a piece of
this product, and does the acceptance tier notice where it got the product *wrong*?

**The protocol:**

1. **Choose one decision-dense module and justify the choice** — a unit whose behaviour is
   dominated by recorded rulings and measured external truths rather than by volume, with a bounded
   dependency surface. Record the candidates rejected and why; an unbounded target measures
   stamina, not the corpus.
2. **Hide it, and hide its dedicated tests** — the module, the tests written against it, and the
   history that would reveal either. State exactly what was hidden.
3. **Declare the visibility ruling** — what the regenerating worker may read. The corpus members,
   plus the acceptance-tier tests (visible by definition: they are the acceptance criterion). State
   what it may not read: the rest of the source, the rest of the suite, internal working notes,
   history.
4. **Regenerate**, then compare: public surface, data shapes, refusal text, and a **behavioural
   table** with both versions loaded side by side and fed the same inputs.
5. **Classify every divergence** into exactly three classes — **corpus gap** (the corpus failed to
   say it; name the missing sentence and the document that should have carried it), **merely
   different** (legitimate variance the product does not care about), and **acceptance-class** (the
   rebuilt product is *wrong* and nothing caught it — the finding the ritual exists to produce).
6. **Ship nothing.** The regenerated code is evidence, not a candidate for landing.

### A.2 Ritual two — the SEED ACCEPTANCE TEST (does the process transplant?)

**The question:** give a fresh worker the kit's own bootstrap instructions and a one-sentence goal,
on unfamiliar ground — does a real project come out, and which of the kit's steps had to be
guessed?

**The protocol:**

1. **A cold bootstrap.** One fresh worker, the bootstrap document, and a goal stated in the user's
   words — never the vocabulary the answer is supposed to invent. External truth comes from a
   pinned local source, not from a search.
2. **Count the bootstrap steps executed versus guessed.** A step that had to be guessed is a defect
   in the instructions, and its count is the headline number.
3. **Then load the process, not just the bootstrap:** at least two work items driven through the
   full implement-then-review boundary with **genuinely fresh reviewers**, and the donor project
   off-limits (needing to consult it is itself a finding about the copy list).
4. **Audit from artifacts.** An independent pass reads only the outputs — history, the board, the
   registers, the gate runs — never the workers' transcripts. What the artifacts cannot show did
   not happen.
5. **Name what was never exercised.** Every contract the run did not touch is **unproven, not
   passed**, and is listed by name.

### A.3 What BOTH rituals must declare — the honest-worker limits

Neither ritual has a sandbox, and pretending otherwise is the one failure that voids the result.
Each run states, up front and in its own findings document:

- **Blinding is honour-system**, declared and not enforced. Nothing prevented the worker from
  reading what it was told not to read.
- **The supporting evidence that blinding held** — divergences a peeking worker would not have
  produced — offered as *supporting*, never as proof.
- **Every information channel that leaked**, bounded and recorded (an interface discovered through
  collection errors, a stray probe, a reviewer who was the same agent wearing a second hat).
- **The scope the run does not cover** — one project, one stack, one night, and the contracts never
  exercised.

A run that cannot make these declarations has still produced findings; it has not produced a
measurement.

### A.4 The deliverable is the DIFF, and the findings list is the product

Neither ritual delivers code, a fix or a verdict. **The deliverable is the divergence list** — each
item classified, each corpus gap naming the missing sentence and its home document, each
acceptance-class item named as the serious result it is. Findings are **recorded, not fixed** in the
same breath: what gets minted from them is a separate decision by whoever owns the backlog, and the
findings document survives whether or not anything is minted.

Nothing about a calibration run may change the acceptance tier's own status. It reads the tier; it
does not amend it, mark tests, or raise a floor.

---

## B. Your project's instance — **fill this in**

> **PROJECT INSTANCE from here down.** Nothing here is inherited. On day one this section is
> correctly empty — neither ritual is owed.

**What goes here, one row per run:** the ritual, the work item that ran it, and the **path of the
findings document** it produced. Nothing else: the findings belong in their own document, and
summarising them here would create a second copy that drifts.

| Ritual | Run | Findings document |
|---|---|---|
| Regeneration spike (§ A.1) | `<work item>` | `<path>` |
| Seed acceptance test (§ A.2) | `<work item>` | `<path>` |

### Two worked examples from the donor project (anonymized) — what each ritual actually produced

**The regeneration spike.** One decision-dense module was hidden together with its dedicated
tests and regenerated from the corpus alone. Output: divergences in the three classes of § A.1
step 5, **including acceptance-class items that nothing in the suite caught** — which is the whole
point of the ritual, and the only kind of finding that cannot be produced any other way. A second,
unplanned finding came out of the setup itself: the hidden module's own tests carried **no tier
mark at all**, so the corpus was measured *more purely* than intended. The spike's own
recommendation — **mark tier membership per assertion where a file mixes the two tiers, rather than
per file** — became convention and lives in [`conformance-tier.md`](conformance-tier.md) § A.4.

**The seed acceptance test.** A cold bootstrap of a throwaway project from the seed document plus a
one-sentence goal, then two work items under multi-agent load, then an artifacts-only adherence
audit. Output: the headline executed-versus-guessed count, **the review boundary biting three times
for real** (which is the strongest available evidence that the boundary is not ceremony), a fix
program addressed to the kit rather than to the throwaway project, and **five contract sheets
listed as unproven, not passed** because the run never touched them. Several of the fixes it
produced are load-bearing text in this kit today: the landing gate's two-layer correction, the
session-state-is-not-repository-content rule, the metadata-may-ride-its-code-branch clarification,
and the mandate to mint a local-procedures file at the close of day one.

**A later external run** exercised § A.2 on a different surface — an interactive terminal
application — and contributed the UI half of the tier's doctrine
([`conformance-tier.md`](conformance-tier.md) § A.6). That is the shape this doctrine expects: a
calibration run's output is **findings and doctrine, never a landed product.**
