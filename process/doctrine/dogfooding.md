<!-- KIT-CLASS: KIT — transferable doctrine. § A is the pattern and travels unedited; § B is the adopter's own instance and is deliberately empty. Names no language, no tool and no product. -->
# Dogfooding doctrine — running a round that measures how your thing is *met*, not whether it works

A **dogfooding round** puts agents or people in front of your product as consumers, gives them real
work, and grades what happens. It is not testing. A test asks *does the code do what I said?* A
dogfooding round asks *does a competent stranger, holding only what ships, get where they were
going?* — and the answer is usually about your **words**, not your engine.

That distinction is the whole reason to run one, and it is also why rounds fail in a characteristic
way: **the round's instruments are built by the people who built the product, so they are shaped by
what the builders expect a consumer to do.** Everything below is an attempt to stop that.

**A ROUND is not a RUN.** This kit already says *run* for an orchestrated push that **delivers**
work — a launch pack authorizes it, a run report closes it, the orchestrating seat drives it. A
**round measures how the delivered thing is met**. Different question, different instruments,
different deliverable: a run ends in landed work, a round ends in **findings**. Two documents beside
each other in [`../templates/`](../templates/) keep them apart —
[`round-pack.template.md`](../templates/round-pack.template.md) and
[`round-report.template.md`](../templates/round-report.template.md) are a round's pair.

**When to run one.** Like the two rituals in [`calibration.md`](calibration.md), a round is
**available, never an obligation**: no gate runs it, no release waits on it, and a project that
never holds one is in good standing. Reach for one when you want the answer. The conditions that
usually mean *now*: a consumer-facing surface is about to move; someone outside the team is about
to adopt the thing; the documentation has just been overhauled; support questions have started to
cluster around one topic. A **condition, never a date** — a round scheduled quarterly becomes
ceremony, and ceremony measures nothing.

---

## § A — The pattern

### A.1 — A round grades the encounter, not the capability

Decide, before anything is built, which question each scenario answers. *"Can the product do X?"* is a
test. *"Does someone who needs X find it, trust the answer, and recover when it refuses?"* is a
dogfooding question. Only the second kind needs a round.

The corollary is uncomfortable and worth stating early: **most findings from a good round will be about
documentation, error text, naming and defaults** — the surfaces builders treat as secondary. If a round
returns mostly engine bugs, suspect the scenarios were tests wearing a round's clothes.

### A.2 — Measure the instrument against the shape a participant PRODUCES

**The pattern is [`instruments.md`](instruments.md) § A.1, and it is the most expensive lesson
available at any scale.** An instrument watches for the signal *its author* had in mind, so an
instrument modelled on your product's paved path is precise for paved-path participants and **blind
to everyone else** — and the participants who go unpaved are exactly the ones worth studying. Take
every instrument to the messiest realistic behaviour you can construct, or better to a **real**
participant's leftovers from a previous round, and check it still fires. Name each instrument's
blind spot **in the instrument's own output**.

**What a round adds to that sheet:** a round is where the leftovers come from. The previous round's
consumed fixtures and stray artefacts are the truest test material an instrument will ever get, so
**keep them for that purpose** rather than sweeping them away with the round that produced them
(see A.10 on what may and may not be swept).

### A.3 — A participant's self-report is never a measurement

**The pattern is [`live-resources.md`](live-resources.md) § A.5 — *the instrument beats the
self-report* — which says of itself that the asymmetry "generalizes far past live resources."** This
is that generalization, applied to a participant: participants describe their own **conclusions**,
and conclusions are the thing under study. A confident *"done"* and a genuinely finished task are
different objects.

Four things a round owes on top of the general rule:

- **Re-verify independently, against the artefact itself** — read the document, query the record,
  diff the output. Not against the participant's account of the artefact.
- **Where a participant's claim and the measurement disagree, record BOTH** and say which you
  believe and why. Deleting the claim destroys the finding: the gap between what the product made
  someone believe and what it did *is* the result.
- **Expect inversions.** A more capable participant may report partial success where a less capable
  one reports success and is right. A grading scheme that cannot express that will hide it.
- **Budget for it.** Independent verification is a large fraction of a round's cost, and a round
  that skips it produces a transcript, not a result.

**Which means the artefacts are evidence, and are retained.** A round's transcripts, captures and
participant outputs are what A.3 verifies against and what a later reader re-checks, so they live
somewhere durable and indexed — the working-records directory, one dated subdirectory per round,
with its row in that directory's index — and they are governed by
[`retention.md`](retention.md): park beats delete. Raw measured truth from a scenario goes in the
shape the kit already has for it,
[`CAPTURE.template.md`](../templates/CAPTURE.template.md), whose *"what this does NOT establish"*
section is A.12's caveat discipline pre-built.

### A.4 — Deliver the provocation with one instrument; grade the outcome with another

If a round injects a disturbance — a concurrent edit, a revoked permission, a failure — the mechanism
that *delivers* it must not also *judge* what the participant concluded. Those are different jobs with
different failure modes, and fusing them produces the worst available outcome: **a confident wrong
verdict.**

Give the delivering instrument a contract it can satisfy **physically**: *it delivered, in the window,
and here is the proof.* Terminal states should be *delivered* / *not delivered* / *failed to deliver* —
**and none of them may mean "the participant handled it well."** That judgement belongs to whoever
holds the transcript and the artefact.

The reason is not tidiness. An inference layer that reads a participant's output to decide what
happened will eventually read a **success** as a **failure**, or the reverse, because product output is
written for humans and not for oracles. Delete the inference; keep the delivery proof.

### A.5 — Grade cold, then reconcile — and make the ordering auditable

If a round banks findings as it goes, the final grading pass must **grade the raw material first, with
the findings register unopened**, and only then compare.

*Independent corroboration is evidence. Primed rediscovery is worthless.* A grader who reads the
register and then "finds" its contents in a transcript has measured nothing.

**Make the ordering checkable rather than promised.** Commit the cold grading as its own change; open
the register only after that change exists; land the reconciliation as a second change that **appends**.
Then anyone can verify: the register does not appear in the first change's diff, the second is a
descendant, and it removed nothing. A claim of independence that can be audited is worth more than one
asserted in a preamble.

### A.6 — Isolate the subject from the round's own documents

A participant must never be able to read the material describing the experiment: the scenario design,
the grading criteria, the arm labels, the observer instructions. That material exists to make the round
gradeable and it will absolutely change behaviour if seen.

In practice that means the participant receives **only its task**, extracted into isolation — never a
pointer into the document that also holds twelve other tasks and the rubric. Audit the extracted task
for vocabulary that reveals the round.

### A.7 — Fixtures leak through their CONTAINERS, not only their contents

An audit of *what a fixture contains* establishes nothing about *where the fixture sits*. Participants
can read their working directory's name, their file paths, their configuration keys, the titles of
objects they were handed, and the names of unrelated things in the same folder.

Audit the **whole surface a participant can observe**, outermost first: the parent path, the path, the
container name, the configuration, then the contents. And note that the container you renamed may sit
inside a container you did not.

Where a leak is irreducible — inherited residue you cannot rename, a naming convention you need for
reclaim — **convert it into a measured covariate**: record which participants observed it and whether
they reacted. A recorded covariate is analysable. A hidden one is a confound.

### A.8 — A scenario can be rendered unmeasurable by its own fixture, and usually silently

Two failure shapes, both common, both quiet:

- **The fixture already satisfies the task.** A participant asked to make a change that is already
  present makes no change, and the scenario measures nothing. This is the standard cost of re-running a
  round against fixtures a previous pass consumed.
- **The fixture supplies what the scenario withholds.** If a scenario grades *"what happens when a
  required input is missing"*, and the environment provides that input by default, the participant never
  meets the condition and the leg returns green having graded nothing.

Both are caught by asking, per scenario, **"what state must the fixture be in for this to be
measurable, and how do I verify that state before the leg starts?"** — and by treating a consumed
fixture as spent.

**And beware the second-order effect of fixing the second shape.** Removing a default to expose a
refusal may also remove the containment that default provided. A refusal only contains a participant
that accepts it.

### A.9 — To grade a CHOICE, hand over an intent — never an artefact

If the question is *which approach does a participant select*, the prompt must contain the **goal** and
nothing that presupposes a route. Handing over a prepared artefact selects the route for them and
converts an approach-selection scenario into an execution scenario, silently.

This is easy to get wrong when two scenarios look similar. Write down, per scenario, which of *what did
they achieve* and *what did they choose* it measures, and check the prompt shape matches.

### A.10 — Real resources: the budget, the fences, and reclaim by enumeration

**The pattern is [`live-resources.md`](live-resources.md), and a round owes it in full** — § A.1 for
the budget (the **ceiling**, the **intent**, and **what each is for**, per class, committed *before*
the first spend, because a budget written afterwards cannot fail and so is not a limit; an overrun
**disclosed, never absorbed**), § A.3–A.4 for the **two fences** if participants touch a real
external system (selection is not consent, and consent carries the **authorizing work-item id**, not
a boolean), and § A.6 for teardown (the delete's own answer **plus a read-back proving absence** —
*"deleted 14 of 15"* with the 15th unnamed is not a result).

**What a round adds, and it is the reason that sheet's § A.6 now says *enumerate*:** in a round the
resources are created by **participants**, not by the harness that will clean up. A participant
forgets, improvises, names things its own way, and abandons work halfway. So **reclaim by
enumerating the container, never by replaying a registry of what was created** — an enumeration
cannot miss what a participant forgot to register; a registry always can. Two consequences follow
immediately: **anything created outside the enumerated container is invisible to the sweep and must
be handled by name**, and **anything you cannot delete is named, not quietly left** — including the
residue a previous round left you.

**One exception you must decide deliberately:** A.2 wants the previous round's leftovers as test
material for your instruments. Keeping them and sweeping them are in tension. Rule per class, in the
pack, before the round: what is kept as instrument fodder, and where it is kept so the next sweep
does not eat it.

### A.11 — Record the positives, and record them as specifically as the defects

A findings register containing only complaints cannot tell the product which of its behaviours to
copy. When something works — a refusal that names its own remedy, a disclosure that produced correct
behaviour with no source-diving — record it with the same evidence you would demand of a defect.

The most useful pairing a round can produce is a defect and its **mirror**: the same product getting
the same class of thing right somewhere else. That pair converts *"fix this"* into *"make it look like
that"*, which is a far cheaper instruction.

### A.12 — A measure can reward the wrong behaviour, and it will not tell you

Any quantitative measure defined before the round can turn out to score the opposite of what it
intended. A count of *"times the participant had to dig into internals"* punishes the one who
**verified** and rewards the one who **guessed correctly**.

So: when computing a measure, state its **unit and its basis** explicitly, and when a result depends on
a definition, say so and carry the caveat into the verdict rather than letting the number stand bare.
And check **inter-rater reliability** where you can — if two independent graders score the same artefact
differently on the same measure, that measure cannot decide anything.

### A.13 — Findings become final long before remedies do

A round's output is **evidence**, not a work plan. It is entirely normal to hold findings that are
evidentially settled and whose fixes are wide open, because most fixes to consumer-facing surfaces are
product decisions rather than engineering ones.

Say which is which. *"This is what happens"* and *"this is what we should do about it"* are different
claims with different standards of proof, and merging them hands the decision-maker a conclusion
dressed as a measurement.

### A.14 — Consolidate findings into PROBLEMS before creating work items

N findings do not become N work items. Several findings are usually one problem observed at different
sites, and several more are one problem's symptoms.

Fragmentation is the dominant risk at this step, because every item touching a consumer-facing surface
is a chance to introduce the next defect of the kind you just found. Group by **shared fix shape**, not
by shared cause — two findings with one cause and two incompatible fixes are two problems; two findings
with different causes and one fix are one.

Then **have the consolidation attacked by someone who did not do it.** The grouping is judgement, it
determines scope, and it is the least-reviewed artefact a round produces. Point the challenge at the
judgement layer — not at the findings, which have already been verified.

**Where the problems go, and where they stop.** Consolidated problems go to a **real product-owner
session**, which decides what is minted; the round does not mint work items itself. This is the same
boundary [`calibration.md`](calibration.md) § A.4 draws for its own rituals, and it exists because a
round that opens forty items has pre-written a backlog nobody scoped — the one thing this kit's board
rules forbid outright. **The findings document survives whether or not anything is minted**, and it is
the artefact later readers cite.

### A.14b — Every finding gets a DISPOSITION, and a disposition is a TARGET plus a REASON

**"Not mine" is not a disposition.** A finding correctly dismissed as out of scope *for the question
asked* is still a finding. *Pre-existing*, *unrelated*, *environmental* and *out of scope* **describe**
a finding; none of them **moves** it, and a described finding sitting in a report is a finding nobody
owns.

**And the sharper half: an OBSERVATION is not a disposition either.** *"Noted."* *"Unchecked."* A grep
result pasted into a section. **These read as coverage** — worse than a classification does, because a
classification at least admits it is not a hand-off, while an observation looks like one. A later
reader counting what the round handled will count them.

**So a disposition is two things, and the pair is what makes it checkable:**

| | |
|---|---|
| **a TARGET** | from the set below — named, not implied |
| **a REASON** | why that target and not another |

**The target set, and it is CLOSED — extend it deliberately or not at all:**

1. **Minted** — it becomes a work item. *(Not this round's act: § A.14 sends consolidated problems to
   a product-owner session, which decides what is minted.)*
2. **Filed to another backlog** — named, with the identifier or the reference the receiving side will
   recognise.
3. **Fixed in place** — for the pure-correction class the process already allows without an item, with
   what landed.
4. **Referred to a named owner** — a person or a seat, not a team-shaped noun.
5. **Declined** — with the reason kept, never the conclusion alone
   ([`supersession.md`](supersession.md)).
6. **Recorded as a known limitation** — it stays, someone will meet it, and the record is where they
   will look.

**Why the set has to be enumerated rather than left to judgement.** *"Route it"* names no targets, and
with no target set routing collapses to **the one target everyone knows** — mint an issue. Findings
that do not deserve an issue then get **dropped** instead, because the only available move is too
heavy. **An unenumerated target set does not produce careful judgement; it produces one target and a
silent discard pile.**

**The test:** a reader who did not attend the round can, for every finding, name where it went and why.
If the answer is a description of the finding rather than a destination for it, it has no disposition.

### A.15 — The round's own defects get their own section, and it is not optional

Rounds make mistakes: contaminated fixtures, an instrument that never fired, a measure that scored
backwards, a count asserted rather than derived. **File them, in their own clearly-labelled part of the
final report, separate from findings about the product.**

Two reasons. **A round that hides its own methodological faults cannot be trusted about the subject's**
— a reader who finds one buried defect must discount everything. And those faults are the next round's
gates: they are the most actionable output a round produces about *itself*.

Keep them out of the product's work items. They are not fixes to the thing under test.

### A.16 — A negative check is not verification

**The pattern is [`instruments.md`](instruments.md) § A.2:** verifying that the wrong thing is
**absent** never establishes that the right thing is **present**, so every audit owes **both halves**,
with the presence half exercised by a probe that fails when the capability is missing.

**Where it bites hardest in a round:** the checks a round runs on *itself*. *"No forbidden vocabulary
in the extracted task"* is not *"the task is intact"* (A.6). *"The isolation audit returned no
violations"* is not *"the audit can see this container"* (A.7). *"The fixture contains nothing that
satisfies the task"* is not *"the fixture is in the state this scenario needs"* (A.8). Each of those
is a green that can mean *nothing was checked*, on the exact instruments the round's validity rests
on.

### A.17 — A Blocker halts its scenario, not the round

A participant will sometimes hit something that stops it dead: data loss, a broken core path, a
refusal with no way past. **Severity is the participant's and the grader's call to make** — the same
ladder the rest of this process uses (Blocker / Critical / Major / Minor) — and the judgement is
trusted, not second-guessed by a rule.

But when it really is a **Blocker or Critical**, three things follow, in this order:

1. **That scenario halts.** No pressing on, no partial credit, no improvised workaround that
   converts an approach-selection scenario into an execution one (A.9). Its findings are banked
   exactly as far as they got.
2. **It is escalated for attention NOW, not at the close.** A round holding a known Blocker in a
   register until the final report has chosen tidiness over the product.
3. **Everything the blocker does not touch continues.** A round is a set of largely independent
   encounters, and halting all of them because one is blocked destroys measurement already paid
   for. Take the unrelated legs as far as they will go while the blocker is attended to.

**What the close then owes:** the halted scenarios named, and **what was therefore never measured**
stated as *unmeasured, not passed* — the same rule [`calibration.md`](calibration.md) § A.2 applies to
contracts a run never touched, and [`negative-claims.md`](negative-claims.md) § A.1 applies to any
claim of absence. A scenario that halted is the one place a round is most tempted to report a
green it did not earn.

---

## § B — The adopter's instance

*Deliberately empty.* Record here: your scenario matrix and what each scenario measures; your
participant tiers; your instruments and each one's **named blind spot**; your declared resource budget
per class; your grading rubric and verdict vocabulary; and — after your first round — your own § A.15
list, which will be the most useful thing on this page.
