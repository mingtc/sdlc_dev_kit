<!-- KIT-CLASS: KIT — transferable doctrine. § A is the pattern (definition, question, convention); § B is the fill-in for YOUR marked set. -->
# Conformance-tier doctrine — the tests that pin the PRODUCT, not this implementation

A suite does two different jobs at once, and nothing in a suite says which job a given test is
doing. This document names the split, gives the one question that decides it, and states how a
new test joins the tier.

**The contract sheet is [`../contracts/acceptance-tier.md`](../contracts/acceptance-tier.md)** — the
invariants and the three floor-guard assertions any implementation owes. This sheet is the
*reasoning* and the *convention*.

---

## A. The pattern

### A.1 The definition

> A test is **CONFORMANCE-tier** iff it **must still pass after a full rewrite of the
> implementation from the corpus** — it pins the **PRODUCT** (consumer-observable contracts,
> measured external truths, recorded rulings). A test is **regression-tier** iff a rewrite may
> legitimately break it (it pins **THIS implementation**).
>
> The operational question: **"if this fails after regeneration, is the product wrong, or merely
> different?"**

"The corpus" is not a vibe: it is the manifest in
[`../../requirements/CORPUS.md`](../../requirements/CORPUS.md) — whatever that file enumerates
(the specs with their statuses, the decision register, the living capability matrices, the front
door, the release notes, the shipped guide). *Rewritten from the corpus* means: a competent
implementer is handed exactly those documents and nothing else, and writes the product again.

### A.2 Why the tier is worth marking even if nobody ever regenerates anything

Asking *"if this fails after a rewrite, is the product wrong?"* of a test family is the sharpest
cheap way to find out whether the family tests anything a consumer would notice. A family that
cannot answer the question is the interesting finding — usually it is pinning an internal that
was never a promise, and it will fight every future refactor for no consumer's benefit.

**And the question can be turned into a measurement.** Hiding a module and regenerating it from the
corpus with this tier as the acceptance criterion is an **available** ritual — never an obligation —
stated in [`calibration.md`](calibration.md) § A.1, alongside the seed acceptance test that measures
the process side. Its deliverable is a findings list, and it never marks a test or moves a floor.

### A.3 The tier is a **lens, not a gate**

Nothing selects on tier membership as a gate. The gate runner and the release ritual are untouched
by this tier and never mention it; the **full suite** remains the review gate and the release gate
exactly as before, and any existing ring selections (a live ring, a slow ring) are unchanged. The
mark is metadata: it adds a way to *ask a question of the suite*, never a way to run less of it.

Concretely, three properties want a meta-guard of their own:

1. the **default selection expression** is byte-identical to what it was before the tier existed,
   and the tier's name does not appear in it;
2. the tier **overlays** any existing ring selections — a test in a ring that also carries the tier
   mark is still selected by that ring and still deselected by default;
3. the tier is **non-empty and above a floor**, per declared family, so a family that gets
   quietly unmarked reddens with a message naming it.

Those three are the floor-guard assertions the contract sheet states as obligations; this is where
their reasoning lives.

### A.4 The marking convention — how a new test joins the tier

**Who decides:** whoever writes the test, at the moment they write it — the same person, in the
same change, as the rest of the Definition of Done. It is not a periodic sweep and there is no
tier-triage meeting.

**When:** at the point the test is written or moved, never later. A retro-classification pass is
exactly the sweep this convention exists to avoid.

**The one later act.** A mark that is **wrong on its face** is removed when found, on a reason
anyone can check against the tree. Inside a calibration ritual it is recorded as a finding instead.
Such a mark is one that no answer about the test's promise could make a member. One example is a
test of this repository's own machinery: § B's first finding, which the donor recorded as a finding
and which under this rule is face-wrong. The reason above stands. Only its conclusion narrowed,
because a checkable reason is not a guess. Nothing is added or re-decided later. The classes and the
checkable-reason rule are the contract's
([`../contracts/acceptance-tier.md`](../contracts/acceptance-tier.md) § 2).

**The question to ask, and nothing else:** *if this fails after regeneration, is the product
wrong, or merely different?* Product wrong → tier member. Merely different → leave it unmarked;
regression-tier is the **default**, and an unmarked test is not a defect.

**How to mark — the mechanics are your runner's, the units are not.** Whatever your runner offers
(a marker, a tag, a category, a build tag), use exactly one and apply it at one of two granularities:

- **A whole file** whose every test answers the same way: one file-level mark, placed where a reader
  meets it first, with a one-line comment saying *why* this file pins the product. Where a ring mark
  is already there, **add** to it — never replace it.
- **A mixed file:** mark the individual tests. This is the common case in any module that mixes a
  consumer-visible grammar with this implementation's internals.
- **Never** hand-mark hundreds of functions to cover a family; if a family is that big, the
  file-level mark is the right unit.

**Two tiers, and only two.** A test that fits neither is a **finding to record**, not a licence
to invent a third category.

### A.5 What the tier is not

- It is **not** a quality ranking. A regression-tier test can be the most valuable test in the
  suite; it simply pins a choice a rewrite is allowed to make differently.
- It is **not** permission to delete anything. Nothing in this doctrine deletes, merges or
  rewrites a test.
- It is **not** a claim of completeness. **The marked set is a floor, not a census** — whatever is
  unmarked is *unexamined*, not *judged regression-tier* — and any published total must say so.

### A.6 Interactive UI states — the semantics/rendering seam

*Contributed by an external adoption run* — a real interactive application taken through this kit
end to end, with § A applied test by test and audited by a fresh-eyes reviewer. The rules below are
**framework-agnostic**; the mechanics of the run that produced them are quarantined in the example
box at the end.

**The tier question ports unchanged. For a UI it resolves along exactly one seam: semantics vs
rendering.**

> A UI test is **conformance-tier** iff it (a) drives a **real input event** through the framework's
> own driver — never a method call on a widget — **and** (b) asserts an **observable semantic** (a
> state word, a documented key's effect, an exit status, a count) in a form that **survives
> re-rendering**: tokens or patterns over the composited frame, never byte-equality of the frame.

**Both clauses are load-bearing.** Drop (a) and the test pins the view-model rather than the product
a user touches; drop (b) and it pins this implementation's pixels.

**A golden can never carry the conformance mark.** Said flatly, because the phrase "golden
evidence for UI" invites the opposite reading: a captured rendering pins glyphs, layout, spacing and
colour — precisely what a legitimate rewrite may shape differently. Goldens are an **evidence
class**, always implementation-tier, in two modes:

- **ZERO-DRIFT (the default gate):** goldens must not move; a snapshot failure is an unintended
  rendering regression until proven otherwise.
- **CONSENTED-CHANGE:** a consented rendering change lands **with** regenerated goldens, and **the
  golden diff IS the spec record of the change** — only the goldens the AC names may move.

**Re-baselining is a human act, never a script's.** No automatic regenerate-the-baselines switch
belongs in any gate, in either mode.

**"Golden" is EARNED by a determinism contract** — three requirements, or the artifact is a flake
with a filename:

1. the output geometry is **declared in the test**, never inherited from the environment;
2. the captured state comes from a **frozen-clock, scripted-state fixture** — no wall-clock age,
   process id, elapsed duration or child-process timing may reach the golden;
3. determinism is **demonstrated, not asserted** — two consecutive runs, zero diffs, quoted.

**Two runtime rings.** In-process driver tests cannot prove the seam between the UI and the
operating system, so name both rings: a **driver ring** (in-process, one per AC, cheap, inside the
ordinary gate) and a **boundary ring** (the real installed entry point, real child processes, input
delivered as bytes at the real terminal boundary, frames parsed by hand) — binding for any change
that touches that seam, **run fresh by the reviewer and never discharged by the implementer's own
evidence**.

**The locator rule** — the boundary case the contributing run recorded rather than resolved:
**the assertion decides the tier; the locator should prefer semantics but may not always be able
to.** A conformance test that finds its target by a rendering detail before asserting a semantic is
acceptable, and is worth recording as a finding — not a reason to unmark it, and not a reason to
pretend the locator pins the product.

**Nothing here changes § A.3 or § A.4.** One mark in whatever the runner offers, two tiers only,
regression by default, marked at write time by the test's author — and every count published with the
measurement that produced it.

<!-- EXAMPLE BOX — the contributing run's incident, genericized at the PM's word
     (2026-08-21): the run's framework names and counts are meaningless outside their own
     project; the LESSON is what travels. -->
> **The contributing run's incident (an interactive terminal application, 2026-08-10).** The
> run marked a deliberate MINORITY of its suite as conformance-tier — the rendered state
> words, the closed key surface (every key driven as a real input event, off-surface keys
> proven inert), and the exit-status policy verified from a real shell. It ran BOTH rings:
> the framework's in-process driver, and a real-PTY boundary ring driving the actual
> installed entry point. **The boundary ring earned its keep on day one: it caught a
> child-process hang that the entire green in-process suite sailed past.** That incident —
> not any count — is why the two-ring rule above is stated as binding rather than advisory,
> and why the boundary ring is run fresh by the reviewer, never discharged by the
> implementer's own evidence. The snapshot-regeneration switch appeared in no gate, ever.
<!-- /EXAMPLE BOX -->

---

## B. Your project's instance — **fill this in**

> **PROJECT INSTANCE from here down.** Nothing here is inherited.

**What goes here:**

1. **Your marked set, by family**, as a table: family · count · files · **why it pins the
   product**. The "why" column is the one that makes the table auditable; a family with no reason
   written down will be unmarked by the next refactor and nobody will notice.
2. **The measurement beside every count** — the command that produced it and the date. A
   transcribed digit in the document whose job is to be true when read is the defect that costs the
   most trust ([`staleness.md`](staleness.md) § C).
3. **Your floor, and the reasoning that sized it.** Set it **below** the measured total and assert
   it with *at-or-above*, never equality: an equality reddens on every member a colleague **adds**,
   which punishes exactly the behaviour the tier wants.
4. **An explicit statement that the pass was partial**, if it was. Classifying everything is a
   legitimate non-goal; presenting a partial pass as a census is not.
5. **Worked examples in the OTHER direction** — the families you deliberately left unmarked, and
   why. Naming what is *out* is the half that makes the definition usable.
6. **Findings — families that resisted the question**, recorded rather than resolved, per § A.4's
   *two tiers and only two*.

### Worked examples from the donor project (anonymized) — the shapes, not the counts

**Marked (product-pinning), and the reason in each case:**

- **Golden / round-trip output** — the exact text a consumer receives, byte-pinned, plus the stated
  round-trip property that the writer accepts exactly what the reader emits.
- **The front door** — the package summary, the metadata body and the rendered help text. A rewrite
  that describes itself wrongly is wrong.
- **Capability matrices** — they are corpus members; their completeness against real code is a
  product claim.
- **Release-note promises** — every line is a commitment, and it must be readable from the artifact
  a consumer holds.
- **The live rings against the real external system** — measured external truth a rewrite cannot
  legitimately change.
- **Permission/scope requirements** — measured external truth, and the generated projection is the
  consumer's paste-ready list.
- **Refusal characterization** — a refusal string and its evaluation order are consumer-visible.
- **Address/URL grammars** — the accepted shapes, the returned field values, and the loud negatives
  quoted verbatim.

**Left unmarked, and the reason in each case:**

- A test pinning the **internal stage sequence** of a parser. A rewrite that parses in a different
  order and emits identical output is *merely different*.
- A characterization test over a **shared transport core** extracted during a refactor. A
  regeneration need not have that seam at all.
- A test pinning **how two test harnesses divide ownership** between themselves. It is about the
  suite, not about the product.
- A test pinning a **migration scaffold** that exists because of the order *this* implementation was
  built in. A rewrite from the corpus has no such history.

**The worked instance of per-assertion marking.** A regeneration spike's own recommendation was
*"mark per assertion, not per file"*, because address-parsing modules mix the two tiers inside one
file. What earned the mark there: the grammars and their field values, the accepted-shape
vocabulary, the negatives. What did not: **parameter names**, **docstring prose**, the **exact
refusal wording**, and **source-literal / absence greps** — each of those pins this
implementation's text or module layout, which a rewrite may shape differently.

**Findings that resisted the question, and why each was left as a finding:**

1. **Tests over the process kit's own scripts** (that the release ritual refuses to tag an
   undocumented version; that the gate runner reports the suite it ran). Real, and it is the
   **process** refusing, not the product promising — a regeneration of the product need not ship
   this repository's scripts at all. *Face-wrong under § A.4: outside a calibration ritual the mark
   is removed, not recorded.*
2. **The offline twins of the live gates.** They exercise the *harness* that drives the live arm,
   offline. The live arm is product; its harness is this suite's own machinery. This is the reason a
   ring mark should key on the ring, never on a filename pattern.
3. **Suites named "characterization" that characterize an INTERNAL dispatch.** Worth re-asking if
   their assertions ever move onto consumer-visible refusal text.
4. **A source-text scan that pins a genuinely product-level property** (that no field of a payload
   is silently dropped) **by reading this implementation's module layout**. It would not survive a
   rewrite as written; the honest fix is a different assertion, not a mark.
