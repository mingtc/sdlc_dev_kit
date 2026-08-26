<!-- KIT-CLASS: KIT — transferable doctrine. § A is the pattern; § B is the fill-in for YOUR fleet. § C is the donor project's failure catalogue, anonymized. -->
# Subagent doctrine — commissioning work you cannot watch, and believing the result

An agent that dispatches other agents has two hard problems. The first is **commissioning**: saying
enough that a worker with none of your context does the right thing, without saying so much that you
have done the work yourself. The second is **belief**: deciding what to accept from something you did
not watch. Most of the weight here falls on the second, because the first is mostly writing and the
second is where runs quietly go wrong.

**Why its own sheet, and where its neighbours are.**
[`orchestration.md`](orchestration.md) governs **who dispatches** — the seat, the runner, the pack,
the pause law. [`model-provisioning.md`](model-provisioning.md) governs **how a worker is
provisioned** — the ladder, the leaf clause. This sheet is the two hard parts in between: **how to
brief**, and **what to believe**. Different moment, different reader: those two are read while
planning a run, this one while writing the brief and while reading what came back.

**How the overlaps are handled, and it is provisional.** Where a rule already lives in another
sheet, this one carries a **pointer plus its own increment** — never a second statement of the rule.
That is the convention [`dogfooding.md`](dogfooding.md) § A.2 and § A.16 already use for
[`instruments.md`](instruments.md), and this sheet follows it rather than inventing one. **It is
applied here provisionally:** the general rule — *every rule has one owning sheet, and the owner is
the sheet a reader is holding at the moment the rule binds* — has been proposed and **not yet
ratified**. Until it is, read the pointers below as this sheet's practice, not as a kit-wide law.

---

## § A — The pattern

### A.1 — Three positions, and the leaf rule

**The pattern is [`orchestration.md`](orchestration.md) § A.1** for the two *standing* positions (the
seat and the runner, and why the split is worth its handoff cost), and **§ A.4** for the third — the
worker, which does one thing and returns. The leaf clause itself — *a dispatched worker does not
spawn subagents* — is [`model-provisioning.md`](model-provisioning.md) § A, point 3.

**What this sheet adds: why the leaf clause is a mechanism rather than advice, and what the seat's
own time is for.**

- **State the leaf clause in every dispatch, verbatim.** Capable models reach for subagents freely,
  and an uncapped worker multiplies cost **invisibly** — because **its own accounting absorbs its
  children's.** That is the reason the clause cannot be left to good sense: the party best placed to
  notice the spend is the one whose report hides it.
- **The seat's context is the scarcest resource in the system,** and it runs on the most expensive
  configuration available. So **where a task is mechanical, repetitive, or large, dispatch it** —
  and there are no exceptions for *"it's faster if I just do it."*

  **Read that against `orchestration.md` § A.1's own tail, which it does not contradict.** That
  section says the lighter delegation patterns — including the seat doing the work itself — are
  *"usually correct"*, and that *"the failure mode here is using the heavy pattern by default."* Both
  are true, because they answer different questions: § A.1 is about **which delegation pattern to
  reach for**, and this rule is about **what the seat's own context gets spent on**. The qualifier —
  *mechanical, repetitive, or large* — is what keeps them apart. Dropped, this becomes an absolute
  standing beside a permission with nothing to resolve them, which is § A.5's defect one level up.

### A.2 — Provision every dispatch explicitly; inheritance is a leak

**The pattern is [`model-provisioning.md`](model-provisioning.md)** — the ladder, its axes, and its
standing riders — with the per-issue rigor line in
[`templates/launch-pack.template.md`](../templates/launch-pack.template.md).

**What this sheet adds:** name the model and the effort on **every** spawn, because **an unset knob
is not a default, it is an inheritance.** Dispatch machinery commonly inherits the *caller's*
configuration when a value is unset, so the coordinator's expensive tier silently becomes every
worker's — or a configuration that must never be used for workers becomes the one they all get. And
write the intended tier next to each work item **before** the run, so the report can grade against
it: *a tier decided at dispatch time is a tier decided under pressure.*

### A.3 — An adversarial brief outperforms a confirmatory one, and it is not close

*"Verify this works"* returns a verification. *"Try to break this, and here is how it broke before"*
returns defects.

**This is new here, and the novelty is precise: the kit already has adversarial *structures* — the
review panels of [`orchestration.md`](orchestration.md) § A.1 and the architect role doc, and
[`rigor-tiers.md`](rigor-tiers.md)' TIER 3 adversarial verification of findings. It has had nothing
about how a brief is *written*.** That is what follows.

The strongest reviews come from briefs that:

- **name the specific thing to attack**, not the general area;
- **hand over the failure history** — a reviewer told *"this instrument has failed twice, each time
  by reporting success on a failure"* looks in a different place than one told *"please review"*;
- **say plainly that a negative verdict is a success**, so the reviewer is not choosing between
  honesty and appearing useful;
- **forbid re-deriving what is already established**, so the run is spent on the unreviewed layer.

Where a claim is load-bearing, ask for it to be **watched failing** — the guard planted, the red
observed, the transcript quoted, the plant reverted. A guard that has never been seen to fail is a
guess about the future ([`instruments.md`](instruments.md) is the sheet on that).

### A.4 — Never relay a worker's self-report as a measurement

**The pattern is [`live-resources.md`](live-resources.md) § A.5** — *the instrument beats the
self-report*, and the asymmetry it names: reviews check the work that was described to them,
instruments check the world. Its participant-facing sibling is
[`dogfooding.md`](dogfooding.md) § A.3, and
[`templates/launch-pack.template.md`](../templates/launch-pack.template.md) states the rule verbatim
in every pack's anti-fabrication block.

**What this sheet adds: the two shapes a worker's report fails in, and the fix for both.** A returned
report is a **claim**; the coordinator re-measures anything it is about to act on or pass upward.
This is not distrust — a worker reports what it *believes*, and belief is exactly what fails
silently.

- **A green whose scope is smaller than it appears** — a check that passed because it could not see
  the case, not because the case is fine.
- **A count, hash or figure quoted rather than derived** — accurate at some earlier moment.

So **require a returned report to carry its own evidence**: the runner's raw summary, **the exit
status read without laundering it through a filter**, the transcript. A claim arriving without its
evidence is treated as unverified and re-measured — and saying so in the brief up front costs
nothing.

### A.5 — Contradictory demands break a worker

Two instructions that cannot both be satisfied do not produce a compromise; they produce a worker
looping until it exhausts its retries and returning **nothing**, after substantial work.

The commonest instance: a free-form answer *"in your own words"* required to fit a rigid structured
shape. Others: *change nothing* plus *make the check pass*; *be exhaustive* plus a hard output limit;
*do not create anything* plus a task that requires creating something.

Two habits, and the second is the cheaper one:

- **Read every brief for the pair before dispatching.** An absolute at the top and a permission two
  hundred lines down never meet on the page, and the later, more specific clause is the one that
  reads as operative — so the resolution devolves silently to the worker.
- **Prefer the loosest output contract that still serves the consumer of the result.** Structure the
  things you will compute on; let prose be prose.

**And a contradiction a worker resolved is still a defect in the artifact that contained it** — so a
worker that finds one reports it as a finding, not merely as a resolved ambiguity. Otherwise the trap
stays in the brief for the next dispatch.

### A.6 — Put refusals in the tooling, not only in the instructions

**The pattern is [`live-resources.md`](live-resources.md) § A.10** — *the structural cure beats the
instruction, and it lands in the same run.*

**What this sheet adds, and it is uncomfortable: in practice these fences catch the coordinator as
often as the workers.** A coordinator issuing a plausible-looking command with a missing parameter,
or acting on a resource another process still holds, is a normal event rather than an aberration —
which is the argument for the refusal living at the **seam** rather than in the brief. An instruction
is followed by some workers and not others; a refusal at the seam is followed by all of them,
including whoever wrote it.

**Where the line between a sentence and a mechanism falls** is not this sheet's to settle alone — see
§ C's closing caution, which argues for the sentence, against
[`live-resources.md`](live-resources.md) § A.10, which argues for the structure. The reconciliation
belongs in the kit's own ruling record, not here.

### A.7 — Verification theatre: a check that cannot fail

**The pattern is [`instruments.md`](instruments.md) § A.8** — *a green that could not have gone red*
— which owns the two shapes (**the unconditional report**, a command whose result is discarded
followed by a message asserting it passed; and **the restated premise**, a calculation fed the number
it was supposed to derive) and the validator-mismatch rule beside them. The defence in one line:
**make every check able to fail, and then confirm that it can.**

**What this sheet adds is who it catches.** Verification theatre is described as a property of an
instrument, and it is — but in a dispatched run the instrument is frequently **the report a worker
hands back**, and both shapes arrive wearing a worker's confidence. A leg that ran a command, lost
its status, and wrote *"the gate passed"* has produced an unconditional report about work nobody
watched; a leg handed a figure in its brief and asked to confirm it has produced a restated premise.
So the coordinator's version of § A.8's rule is § A.4's: **the report carries its own evidence — the
raw summary and the unlaundered exit status — or it is re-measured.** The theatre is the same; what
differs is that you cannot inspect the check, only its account of itself.

### A.8 — A resume is only safe for work without side effects

Re-running a partially-completed slate replays what completed and re-runs what did not. That is safe
when the work was pure computation, and unsafe the moment a leg **changed the world** — the replayed
legs' effects do not reset, so the second pass operates on state its predecessor already modified.

Before resuming, ask: **did any completed leg have an external effect?** If yes, either reset the
state first or retire the affected legs. Otherwise the run is contaminated, and — the expensive part
— **contaminated invisibly, because everything reports success.**

### A.9 — Batch decisions; a non-blocker is not a stop

**The pattern is [`orchestration.md`](orchestration.md) § A.5** — the pause law: a closed list of
four events that may stop a run, everything else parked and passed, and a silent stop treated as a
failure equal to improvising.

**Worth recording, because it is evidence about the rule rather than a restatement of it:** the
donor's independently-written version of this rule arrived at **the same four halting events, in the
same order**, and at the same silent-stop corollary in near-identical words. Two authors, no contact,
same closed list. A rule two parties derive separately from their own incidents is not a convention;
it is a finding.

**What this sheet adds, for unattended runs: do not ask a question nothing will answer.** If no human
will read a prompt, an interactive question is not a pause — it is a **hang**. In an unattended run
the batched-decision list is the only channel, and a run that stops to ask has stopped for good.

### A.10 — Name a deferred decision INSIDE the work item that touches it

When a decision is held back, the worker who later picks up adjacent work must meet the boundary **in
the item they are reading**, not in a register they might not open.

So write the deferred decision, and the reason it is deferred, into **every** work item whose scope
runs up against it — the register remains its authority, and the item carries the pointer. Then a
worker cannot wander across the line by accident, and the decider's authority survives contact with
an eager implementer.

### A.11 — When order is load-bearing, state the order AND its consequence

**The pattern is [`templates/launch-pack.template.md`](../templates/launch-pack.template.md)**, whose
mission section already requires that *"order is a seat decision and deserves its reason in one
clause."*

**What this sheet adds: the reason must name what breaks, not merely assert a sequence.** *"Do A
before B"* is followed inconsistently. *"Do A before B, because B first would remove the only route
participants have to X"* is followed, because the reader can see the consequence and can therefore
tell when the constraint stops applying. Sequencing constraints are among the most expensive things
to leave implicit, and the cost lands on whoever inherits the slate rather than on whoever wrote it.

### A.12 — Hand off while sharp, not while failing

**The pattern is [`../../dev/handoffs/README.md`](../../dev/handoffs/README.md)** — newest-wins, what
a handoff must contain, and the standing-handoff exception.

**What this sheet adds is the timing, which that document does not state:** a coordinator's judgement
degrades as its context fills, and it degrades **before** that becomes obvious. Write the handoff at
the point where you would still call your own judgement good — not at the point where you need one.

And the most valuable thing a handoff carries is **what is stale in the document itself**: *a handoff
whose predecessor is stamped with what it no longer answers is worth several that are merely
current.*

### A.13 — Read and write the same surface

Where a coordinator reads state from one location and writes to another — a working copy and a
separate staging area, a cached view and a live source — **its own picture goes stale and it will
report numbers that were true earlier.** Synchronise before measuring, and prefer measuring the
surface you will act on.

The general form of two defects the kit has paid for separately: a checker that watched one writable
home and not the other, and a printed commit id read before a rebase moved it.

---

## § B — Your fleet's instance — **fill this in**

> **PROJECT INSTANCE from here down.** Nothing here is inherited. On day one this section is
> correctly empty.

1. **Your position names and their boundaries** (§ A.1) — who may dispatch, and who may not.
   `<fill-in>`
2. **Your closed list of run-halting events** (§ A.9), if it differs from the pause law's four, and
   **why** it differs. `<fill-in>`
3. **Your dispatch template** (§§ A.2, A.3, A.5) — including where the rigor line goes, where the
   failure history goes, and the absolutes block every later permission is checked against.
   `<fill-in>`
4. **Which of your seams carry refusals** (§ A.6), and which rules are carried by a sentence instead
   — with the reason for each placement. `<fill-in>`
5. **Your resume policy** (§ A.8): which of your work classes have external effects, so a resume is
   decidable rather than argued. `<fill-in>`
6. **Your own § C.** It will be more convincing to your team than the one below.

---

## § C — Worked example: the donor project's failure catalogue (anonymized)

> Shapes, not incidents, so they transfer. Every one happened **while following the practices above**,
> and each is why a rule above reads the way it does.

| The failure | What it cost | The amendment |
|---|---|---|
| An instrument watched for the signal **its author** expected; participants produced a different one | A whole scenario returned nothing — twice, for two different reasons | [`dogfooding.md`](dogfooding.md) § A.2 / [`instruments.md`](instruments.md) § A.1: measure against real leftovers, and name the blind spot in the instrument's own output |
| An oracle read the product's own output to decide what had happened, and the success text contained the failure's vocabulary | Two rounds of rework; a successful operation graded as a refusal | [`dogfooding.md`](dogfooding.md) § A.4: the delivering instrument proves delivery only. Delete the inference layer |
| An audit checked that the wrong thing was **absent** and never that the right thing was **present** | Many parallel legs ran and all blocked immediately; a full pass wasted | [`instruments.md`](instruments.md) § A.2, and § A.7 above: both halves, presence exercised |
| A prose instruction was paired with a rigid output contract | A worker exhausted its retries and returned nothing after substantial work | § A.5: read every brief for the contradictory pair |
| A partially-failed slate was resumed, and completed legs had already changed live state | Two scenarios contaminated; one became ungradeable | § A.8: a resume is only safe without side effects |
| A check reported success unconditionally; a calculation was fed the premise it should have derived | An arithmetic error survived its own verification and reached a plan | § A.7: every check must be able to fail, and be confirmed able |
| An isolation container was renamed while its **parent** still described the experiment | A leak survived three audits; participants could read their own condition | [`dogfooding.md`](dogfooding.md) § A.7: audit outermost-first, whole observable surface |
| An identifier was asserted rather than read from its register | A duplicate id in the register the graders would cite | § A.4: derive, do not assert — including your own bookkeeping |
| Coordinator commands were issued against tooling whose interface was assumed rather than read | Work silently not done; a record claiming an action that never happened | §§ A.6, A.13: read the interface; refusals at the seam; measure the surface you act on |
| Reviewers repeatedly found a **guard's reach smaller than its documentation claimed** | Several defects hid behind green checks | § A.3: ask for the guard to be watched failing **on the exact shape it polices** |
| Consolidation of findings into work items was done by one party, unreviewed | A fabricated cost attached to the highest-value item; the flagship finding omitted entirely | [`dogfooding.md`](dogfooding.md) § A.14: have the judgement layer attacked by someone who did not produce it |

**The single pattern behind most of the rows** — more useful than any individual one — is **a claim
made where a measurement was available.** Asserted counts, assumed interfaces, inherited premises,
absence read as evidence of presence. The cheapest correction is one sentence held as doctrine rather
than a new subsystem: **derive it, or do not state it.**

**And a caution about the correction itself.** When a process fails, the instinct is to add process.
Machinery accumulated in reaction to failures becomes indistinguishable from scar tissue to whoever
inherits it, and a rule enforced by a new subsystem costs more forever than a rule stated once and
followed. **Prefer the sentence; reserve the mechanism for what genuinely cannot be carried by
discipline.**

> **That caution states one side of a real boundary, and it is in live tension with
> [`live-resources.md`](live-resources.md) § A.10 (*"the structural cure beats the instruction"*) —
> the two were written from different incidents and neither is wrong inside its own scope.
> **The boundary itself is [`fix-execution.md`](fix-execution.md) § A.5b**, which owns it and states
> it wider than either sheet proposed alone. Read it before concluding from this paragraph alone that
> a sentence will do: the caution above is the burden of proof on a mechanism, not a verdict.
