<!-- KIT-CLASS: KIT — transferable doctrine. § A is the pattern; § B is the fill-in for YOUR product's surfaces. The worked incident in A.3 is this kit's own, so nothing here needs anonymizing. -->
# Consumer-output doctrine — what a tool's output owes a reader who cannot re-measure it

**What this governs.** Any output your product hands to someone who **cannot go and check it**: a
report, a per-row label, a status line, a summary figure, a verdict. Not the artifact's internals and
not your own logs — the surface a consumer reads and then **acts on**, having no access to the
evidence underneath it and, usually, no way to tell a measurement from an inference.

**The one discriminator, and every rule below is a consequence of it: RE-MEASURABILITY.** The rest of
this kit's doctrine addresses a reader who can go and check — a maintainer with the tree in front of
them, a reviewer with the diff, a seat that can re-run the guard. When that reader meets a wrong
output they eventually find out. **This sheet's reader never does.** A confident wrong line is not a
smaller version of a hedged wrong line to them; it is a different kind of object, because they will
act on it and nothing downstream will contradict it.

**What follows from that asymmetry, and it is the thing to carry away:** where the reader cannot
re-measure, **the tool's confidence is the only evidence they have**, so confidence becomes a claim in
its own right and obeys the same rules as any other claim.

## Its neighbours, and the seam against each

| Sheet | Its reader | The seam |
|---|---|---|
| [`instruments.md`](instruments.md) | someone who **can re-run the check** — a guard-builder, a seat reading a green | Instruments governs whether the check can see anything and how its own blind spot is named. This sheet governs what the **product** says to someone who will never run the check. An instrument's output is in scope **here too** when it is handed to a consumer in that position — the two sheets overlap deliberately at that one point. |
| [`negative-claims.md`](negative-claims.md) | an implementer writing a sentence, a reviewer reading one | That sheet's wiring gates on a **lexicon** — *cannot*, *impossible*, *not supported*, *does not exist*. **The failures below ship none of those words.** A one-word status label carrying a negative inference is affirmative in form, so a reviewer executing the lexicon check correctly answers *no* and passes it. Same family of error, unreachable by that route. |
| [`distribution.md`](distribution.md) | a consumer holding a pinned copy | § A.4 is this sheet's worked incident at distribution scale, and it is the kit's own. |
| [`staleness.md`](staleness.md) § C | anyone reading a number in prose | *Derive, date, or do not state* is that section's rule for **maintained prose**, whose reader can open the source. A.2 and A.6 below are the same concern where the reader cannot: the number arrives in a generated artifact, so tracing it has to be built into the artifact. |

---

## A. The pattern (this is the transferable part)

### A.1 — The output states what it does not cover, in the words it uses to say what it found

> A label's scope may not exceed its evidence's scope, **and the label itself is where that is
> said** — not a footnote, not the docs, not a caveat file.

The failing shape is a label that is true of the evidence and false of the world. A tool that
examined **one** of several possible sources and found nothing in it may say **"not found in
<source>"**. It may not say **"absent"**, **"missing"** or **"outstanding"** — each of those is a
claim about **every** source, made by a tool that read one, and the consumer cannot tell the
difference: they have no list of sources and no reason to suspect one was skipped.

**And the consequence is not a wrong word; it is a wrong action.** A scope-exceeding label is
usually presented as a *worklist* — chase these, fix these, review these — so the reader acts on it
immediately, against the subjects the tool merely failed to see evidence for.

**The test to apply to any label:** *what population does this word claim to be true of, and what
population did the tool actually read?* If the two differ, the label names the second.

**A label that says less is not a weaker product.** The narrow label is the one a consumer can act on
correctly, and it is the one they can combine with what they know and the tool does not.

### A.2 — READ and DERIVED are distinguished PER ITEM, on the item's own line

> Where a tool both reads facts and infers them, every item carries **which it was**. Not a
> methodology note, not a confidence score — a value on the row.

Three values are usually enough: **read from the source**, **inferred by the tool**, and **nothing
established**. What matters is that the distinction is on the same line as the result, so a consumer
scanning the output sees it without asking for it.

**Why per item, and why this is the clause people cut as clutter.** The whole hazard of an inference
is that a *wrong* one usually makes the output look **better** — the totals reconcile, the exceptions
list shortens, the thing that should have been flagged quietly became a match. **A defect that
improves the appearance of the result is invisible exactly where the consumer would otherwise have
caught it.** The per-item marker is the only place that failure is visible on the day it happens,
because the aggregate cannot show it by construction.

**The clause survives its own strongest objection, which is that it is the author showing their
working.** It is not: the consumer's question is not *how clever was the tool* but *is this line
something the tool was told, or something it decided?* Those two have different failure modes and the
consumer treats them differently — and only they can, because only they know the domain.

### A.3 — Where every candidate value is wrong in a DIFFERENT direction, synthesise none of them, and record the absence as a decision

> When a figure could be computed several ways and each way is wrong in its own direction, the tool
> prints the **decomposition** and not the total, and says **why the total is absent** where the
> total would have been.

The failure this prevents is choosing among wrong answers **on the consumer's behalf, about their own
domain**. Each candidate embeds an assumption the tool is not in a position to make; picking one and
presenting it as a figure hides the assumption inside a number.

**This is not a deferral, and it must not be written as one.** A deferral is a worthwhile thing
scheduled later. This is a thing that **cannot be done honestly with the information available**, and
the record exists so the next person to notice the obvious missing feature finds **the reason rather
than the gap**. *The gap is the correct output* — and it is only correct if it is legible as a
decision. An unexplained hole reads as an oversight and gets filled by the next implementer.

**So the absence owes three things where it appears:** what is missing, why every available answer
would be wrong, and **the observable event that would discharge it** — a new input seen, a rule
agreed — never a date. (Same shape as [`supersession.md`](supersession.md)'s conditions: the
condition names an event, not a calendar.)

**The kit's own incident, and it is exactly this clause failing.**
[`distribution.md`](distribution.md) § A.4 records an updater that answered *"which version is
vendored?"* by listing a glob and taking the first entry, in a long-lived directory that can hold a
stale artifact beside the current one:

> *"Sort order then decides the answer — and when it picks the older file, a perfectly healthy
> checkout reports **UPDATE AVAILABLE** and offers, as the remedy, a **downgrade**. The remedy is
> worse than the disease, and everything about the report looks correct."*

Two candidates, each wrong in its own direction, one picked by an accident of ordering, and the
consumer handed a confident instruction to make their checkout worse. **The fix that shipped is this
clause's shape**: *"the tooling refuses, lists the candidates, and says what to delete."*

### A.4 — Where the predicate is not mechanically decidable, hand back a CENSUS, and say in the output that that is what it is

> A check that can distinguish right from wrong may render a verdict. A check that cannot produces a
> **list a human reads**, and **states in its own output** that it is doing so.

The disposition half of this rule — *which* checks may be gates — is
[`instruments.md`](instruments.md)'s territory and is argued there. **The half that belongs here is
the output**: the artifact a consumer holds must itself say whether they are reading a judgement or a
pile of candidates. A heuristic detector whose output is formatted like a verdict will be read as
one, however carefully its disposition was reasoned about upstream.

**Why it matters more than it sounds.** A low-precision check presented as a verdict is wrong far
more often than it is right, and the cost is not the wrong answers — **it is that after a week nobody
runs it**. A check nobody runs is indistinguishable from one that does not exist, and it is **worse**,
because the thing it watched looks watched. *A disabled gate reads as armed.*

**And the honest form is not an apology.** A list that says *"these are candidates; most will be
fine; here is what I could not tell apart"* is a **more** useful artifact than a verdict of the same
accuracy, because the consumer can spend their attention where it pays. The tool's job was to have
found them.

### A.5 — An inference whose error leaves no trace is DEMOTED: the tool proposes, the consumer decides

> Where a wrong inference would leave **nothing in any output to notice**, the tool loses the
> authority to make it. It may **propose** the pairing, the merge, the match — it must present it for
> confirmation.

A.2 marks inferences so they can be seen. This clause is about the ones that, once made, **cannot be
seen at all**: two records silently treated as one, a value silently attributed to the wrong owner. No
line appears anywhere saying a decision was taken, so there is no row for the consumer to disbelieve.

**The asymmetry is the whole argument, and it is worth stating as arithmetic.** A proposal the
consumer rejects costs them seconds. A silent wrong merge costs a misattribution that surfaces — if
ever — long after the evidence is gone, to someone who cannot reconstruct what the tool did. **The
costs differ by orders of magnitude in one direction only**, which is what makes this a rule rather
than a preference.

**A short list the consumer has to look at is the accepted cost**, and it is accepted by naming it,
not by minimising it. Where the tool applies a tolerance to reach the proposal, the tolerance is
stated **in the output beside the proposal** — that statement is the behaviour, not a footnote to it.

**How wide a tolerance should be is not answerable in doctrine.** Do not invent a margin before a
second real example exists; the wrong margin chosen early is harder to see than none at all.

### A.6 — Prefer the longer form the consumer can CHECK to the shorter one they must TRUST — and pay the split's cost where it lands

> Where a figure or a status is load-bearing, prefer the decomposed form each part of which the
> consumer can trace back to something visible, over the combined form they can only accept.

The test is arithmetic the reader can perform with their eye: a figure they can trace to a block on
the same page is checkable; a figure merging two blocks is not. It generalises past money — a count
covering two populations, a status covering two states, one sentence covering two sections.

**Why this is not a preference about brevity.** A combined figure **moves work from the writer to the
reader on exactly the day it matters**. It costs nothing on the occasions the number is right; on the
occasion it is wrong, the reader must decompose it by hand, at the worst moment, with no tool for it.
The longer form spends a line every time to save an hour once.

**THE COST OF THIS CLAUSE, STATED NEXT TO IT RATHER THAN DISCOVERED LATER.** Splitting one figure into
two **creates a state boundary that did not previously exist**, and each half then acquires its own
emptiness case. *One side empty while the other is not* is a shape nobody had to handle before the
split. **So a split is not free: it buys checkability with a new boundary, and the implementer who
performs it owes a fixture for each half being empty while the other is not.**

This clause agrees with [`staleness.md`](staleness.md) § C rather than competing with it: that section
says a number must earn its place; this one says that **where a number is load-bearing, prefer the
form the reader can trace.**

### A.7 — A limit is placed where the AFFECTED PARTY is standing when it bites, and detection is separated from remedy

> **A limitation recorded where the affected party does not look has not been disclosed.**
> Disclosure is a property of *where the words are*, not of whether they exist.

Writing a caveat into engineering records — a suspicions file, a probe, a guard's own limits list —
satisfies *"volunteer the limitation"* on paper and discloses **nothing** to a consumer who reads none
of them. The warning belongs wherever the consumer is when the failure could bite, which is usually
the one surface they read without being told to.

**And that surface has a budget.** A permanent banner about a condition that is almost never true
trains the reader to skip the place they otherwise read reliably — **spending the one surface you have
on a problem they almost never have**. A warning's real price is the attention it costs on every
occasion the condition is **false**.

**Three questions decide any warning's placement, and they are the reviewer's check because no guard
can run them:**

1. **Where is the reader standing when this fails?** Not where the subject of the warning lives.
2. **What does this cost on every occasion the condition is false?** That is the price you pay for it.
3. **Is this for DETECTION or for REMEDY?** *Detection* goes where they look without thinking;
   *remedy* goes one step down, where they look **having been told** — it is only useful to someone who
   already knows they have a problem. Putting a remedy in the detection surface fails **even when
   every line of it is load-bearing**, which is the defence that must not be accepted.

**And of any recorded limitation:** *which surface is it on, and does the affected party read that
surface?*

**Where the condition cannot be detected at all, say THAT, in one line, in the place they already
look.** A stale copy is precisely the one that does not know it is stale. The honest line — *"this
page is written by the copy it describes"* — is **true every occasion**, so it is news rather than
boilerplate, and it tells the consumer what the surface can and cannot vouch for.

**A stated limit with a way out is not a shrug; a shrug is a limit with no way out anywhere.** The
remedy still exists one step down, reached by someone with a reason to look. That is the difference
between hiding a remedy and placing one. Where one action discharges several caveats at once, that
action is the way out to name.

**Prefer a limit that is conditional BY CONSTRUCTION and verified by calling it** — it appears below
the measured floor and is silent at or above, so it is news when it appears. Verified by *running the
thing*, never by reading it; see [`instruments.md`](instruments.md) § A.2.

### A.8 — The clause the rest of § A are faces of: never present an INFERENCE in a MEASUREMENT's words

Every clause above is one face of a single failure — **an inference wearing a measurement's words,
shown to the person who cannot tell them apart.** A flat *"it runs here: YES"* derived from a source
sweep, printed with nothing beside it, is the general case: true of what was examined, read as a
statement about the reader's machine, by the one party with no way to separate the two.

Where you can only state one rule from this sheet to a reviewer, state that one.

---

## B. Your project's instance — **fill this in**

Delete this section wholesale if your project's only outputs are read by people who can re-measure
them. Filling it in is what makes § A enforceable here rather than admirable.

| Duty | Fill in |
|---|---|
| **Which surfaces are in scope?** | `<the outputs a consumer reads and acts on>` — derived from your own tree, listed by path, not recalled. A surface omitted here is a surface this sheet does not reach. |
| **Who is the consumer, and what can they NOT check?** | `<who reads it; which evidence is unavailable to them>`. This is the sheet's premise; if the answer is "they can check everything", say so and delete the rest. |
| **The read/derived vocabulary** | `<the fixed set of values>` (A.2) and the one place they are authored, so a projection cannot drift from it. |
| **Where an absent value is recorded** | `<the convention for A.3>` — what a refused synthesis looks like on the surface, and where its discharging **event** is written. |
| **Census-shaped outputs** | `<which of your outputs are candidate lists, not verdicts>` and the words each uses to say so (A.4). |
| **Which inferences are DEMOTED to proposals** | `<the list>` (A.5), with what each tolerance is and where it is stated in the output. |
| **The detection surface** | `<the one place the consumer reads without being told to>` (A.7) — and what is allowed to occupy it. |
| **Who checks this, and when** | `<the review step>` — A.7's three questions and A.2's per-item test are reviewer checks; none of § A is mechanically decidable in general, so do not wire a gate and call it covered. |

**Two duties worth stating even where the table is empty:**

1. **A new consumer-facing surface joins the first row in the same change that creates it.** A sheet
   whose scope list lags is a sheet that silently stops binding.
2. **Where a fix under A.6 splits a figure, the fixtures for each half being empty while the other is
   not land with it** — the cost named in A.6, paid by the change that incurs it.

---

## Why this is its own sheet and not a section of an existing one

Because the sheets it is nearest to are **looked up by different people at different moments**, which
is this kit's own test for a sheet boundary ([`negative-claims.md`](negative-claims.md) states it about
itself).

- **`instruments.md`** binds *whoever builds the instrument* and *whoever consumes the result* — of a
  **guard**. A product's consumer is neither, and would never reach a guard-builder's sheet looking for
  what a label may say. Routing a product-surface rule into that sheet would also re-commit A.7's own
  error: placing the rule where its subject lives rather than where its reader is standing.
- **`negative-claims.md`** is reached through a lexicon check, and none of the failures above ships
  one of its four words. The doctrine would be unreachable at the moment it is needed — a gap in the
  **mechanism**, not only in the prose.
- **`staleness.md` § C** governs a number in maintained prose, read by someone who can open the source.
  Here the reader cannot.

**Size, and why it is not an argument in either direction.** A doctrine sheet is exempt from
[`lookup-tables.md`](lookup-tables.md) § A.1's byte trigger **by how it is read** — addressed on demand,
never loaded at session start — so neither this sheet's size nor a neighbour's decides where a rule
lives. Derive the sizes with the command § A.1 names before using one in an argument; the trigger binds
on the **role-mandatory-read** axis only.
