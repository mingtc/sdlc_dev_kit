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

**How the overlaps are handled.** Where a rule already lives in another
sheet, this one carries a **pointer plus its own increment** — never a second statement of the rule.
That is the convention [`dogfooding.md`](dogfooding.md) § A.2 and § A.16 already use for
[`instruments.md`](instruments.md), and this sheet follows it rather than inventing one.

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

**Where the line between a sentence and a mechanism falls IS SETTLED, and not here.**
[`fix-execution.md`](fix-execution.md) § A.5b holds it — *a MECHANISM where the act is irreversible
OR the failure is silent and compounding; a SENTENCE everywhere else* — and claims the rule
exclusively, which is why this sheet points rather than restates.

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

### A.10 — Name a deferred decision INSIDE the work item that touches it

When a decision is held back, the worker who later picks up adjacent work must meet the boundary **in
the item they are reading**, not in a register they might not open.

So write the deferred decision, and the reason it is deferred, into **every** work item whose scope
runs up against it — the register remains its authority, and the item carries the pointer. Then a
worker cannot wander across the line by accident, and the decider's authority survives contact with
an eager implementer.

**When no work item exists yet to carry it**, write one at the moment of deferral — a one-line stub
naming the decision and its reason — rather than carrying the intent in the session until a quiet
moment. A session's working memory does not survive the handover. For a kit upgrade, the stub holds
the deferral until `kit-upgrade.sh` can run; from then on, its committed checklist does.

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
a handoff must contain, the second trigger (the stop you did not choose, where a handoff owes an
enumeration of what is HELD) and the standing-handoff exception.

**What this sheet adds is the OBLIGATION on a coordinator, where that document states the timing
in its own § When to write one — while sharp, not while failing:** a coordinator's judgement
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

### A.14 — A file that means two things has no correct writer

A.13 is about a coordinator reading **the wrong surface**. This is the failure one step earlier:
the surface is the right one, and it has quietly been made to mean **two things**.

> **When a second consumer starts reading an artifact for a fact the artifact was not built to
> carry, the fix is a SECOND artifact, not a cleverer query against the first.**

**Why a fleet meets this before a single author does.** A file written by one worker and read by
another is the fleet's whole coordination surface, and **nobody holds both ends**. The writer knows
what it meant; the second reader knows what it needed; the overload exists in neither head, so no
review catches it — each side is looking at a file that is correct **for its own purpose**.

**The failure shape, and it is worth stating because it does not look like a bug.** Two rulings that
are each correct meet inside one overloaded file and produce a report where **both halves are false
and neither rule is wrong.** Measured: a notes file whose newest write was used to derive a
*stopped work* timestamp, so an ordinary late entry dragged the derived stop **past** the last work
— the disagreement branch never fired, and the page printed *"finished for the day, and nothing
since"* directly above *"work moved 1 minute ago."* Nothing failed. Nothing was unguarded. The file
was asked what it meant and gave the two different answers it had been built to give.

**Why the cleverer query is the tempting wrong answer, and this is the part to hold onto.** At the
moment the defect surfaces, a smarter read of the overloaded file is always available and always
cheaper — *derive the timestamp from the commit that introduced the heading*, not from the file's
mtime. It works. **And it leaves the file meaning two things**, so it buys one fix and keeps the
generator: the next consumer arrives, reads the file for a third fact, and the query gets smarter
again. **Name what each file MEANS, and split it when the answer needs an "and".**

**The reader-side twin, so both directions are named.** Coming the other way, an operand's second
consumer is discovered rather than designed — *this field's order looked free until another script
turned out to read its leading token.* Same defect, opposite end: there, you are the consumer nobody
named; here, you are the author about to create one. [`instruments.md`](instruments.md) § A.6 owns
the consumer-side rule, where the operand belongs to an instrument; **this one binds the author
deciding, before anything reads it, what one file is FOR.**

### A.15 — A prompted worker cannot time itself: the cadence contract for peers you are not watching

A worker that is **prompted** — it advances one burst per message and then stops — has a property
that changes what a spawner owes it. **An idle prompted worker cannot send anything.** Not a
heartbeat, not *"I am blocked"*, not *"still going"*, because **sending is an act and an idle
session is not acting.** So two prompted workers that agree to keep each other informed **fall
silent together, and the silence is indistinguishable from work.**

[`../contracts/liveness-watchdog.md`](../contracts/liveness-watchdog.md) § 2 already owns the
signal half — *the signal must be a by-product of work, not something a worker can emit*, and
*liveness is artifact freshness and never the absence of news*. **What follows is the half it does
not cover: what a spawner owes a SET of prompted peers over a task longer than one session.**

**Scope, and it is narrow on purpose.** This binds **prompted** workers. A fleet of autonomous
loops — workers that wake on their own clock — does not need item 1 and would find the cadence a
tax, which by [`generality.md`](generality.md) § A.2 makes the **intervals a setting with a
default and never doctrine.** State your own in § B; the numbered obligations below are the rule.

1. **Only the spawner has a clock, and the act that ends the run retires it.** Arm the wake-ups
   **before** spawning anything — an idle notice on every child, plus a recurring timer at roughly
   half the cadence you expect notes at. *Why:* an idle child cannot tell you it is idle, so the
   only clock in the system is yours.
   **And the arming obliges a retirement:** the act that ends the run walks **an enumeration of
   what it armed**, not a list of handles it happens to hold. A scheduled wake-up has no pid and no
   session directory, so a teardown made of handles cannot reach it. That invariant is
   [`../contracts/liveness-watchdog.md`](../contracts/liveness-watchdog.md) § 2 and § 3 — it is
   cited here rather than restated because **arming without retiring is how this item was first
   drafted**, and a sheet that tells you to arm and stops has shipped the asymmetry.
2. **Every worker owes notes from INSIDE its work** — at each job boundary and at a stated
   interval, whichever comes first. *Why:* the only signal a prompted worker can produce unasked is
   one it produces **while acting**, so the note must ride on the work rather than wait for a gap.
   **A note is not a question, and the two instructions are different:** *"do not stop to report
   between jobs"* and *"go silent"* read alike to a worker told the first and cost a run the
   second.
3. **Age is read from ARTIFACTS, never asked.** Derive it from what the work leaves behind — the
   shared log both sides write, committer dates across all refs, the newest commit's subject. Never
   from a worker's answer to *"are you alive?"*, and never from a file's mtime: a status page
   rewriting itself on a loop is permanently fresh and proves only that the loop runs.
   *Why:* § A.4's rule, aimed at liveness — a self-report is not a measurement — and the party
   likeliest to have stopped is the party you are asking.
4. **Overdue has a NAMED ACT and a NAMED OWNER** — who pokes whom, with what words, at what
   threshold. *Why:* a trigger nobody owns does not fire. An escalation written as *"someone should
   check"* is a description of a hope.
5. **Pause and done are FILES.** A stop is a file the workers read and a completion is a file they
   write, both in a place a person can open. *Why:* the human supervising usually **cannot see the
   sessions at all**, and a deliberately stopped pair must not read as a stalled one. A stop that
   exists only inside a conversation cannot be exercised by anyone outside it.

> **AND THE OBLIGATION MUST LIVE WHERE A SESSION THAT WAS NEVER PROMPTED WILL FIND IT.**
> Item 2 is the one that fails this way, and it fails silently. An obligation delivered only in a
> worker's opening instructions **is a conversation citing itself** — it binds the session that
> received it and **evaporates at the next restart**, because the successor inherits the queue, the
> repository and the board, and does not inherit the prompt.
>
> **Measured, on one pair across one restart boundary:** eight unprompted progress notes before the
> restart and **none** after, from a successor that was neither idle nor failing — it landed work,
> bounced a review, closed board asymmetries. It simply never knew it owed anyone a note, and
> **nothing in the repository told it.** The two notes that eventually arrived came only after a
> human poked it by hand, which is the spawner's clock covering for a contract that had lapsed.
>
> **So the cadence obligation is written into the project's own working agreement** —
> `process/LOCAL-PROCEDURES.md`, minted on day one ([`../SEED.md`](../SEED.md) step 8) — as a line
> the session-start read order surfaces. The kit ships that line; § B names where yours went.
> *This is the kit's own law about rulings applied to obligations:* a conversation may not be its
> own evidence, which is why `DECISIONS.md` exists rather than a memory of what was agreed.
>
> **What would falsify this:** a project whose workers reliably keep the cadence across restarts
> **without** the working-agreement line — which would mean the prompt was never the only carrier
> and the line is ceremony. The cheap test is the one that produced the measurement above: restart a
> worker mid-queue, hand it nothing, and read the log for a note it owed.

**An environment note, measured 2026-09 on one harness (background agent sessions) — a setting to check on
yours, not a rule** ([`generality.md`](generality.md) § A.1: one environment is not independence):

- **The send must carry the check.** A peer can meet its obligation to send by *nudging* — a message
  with no state check behind it — and still miss the moment it exists to see. Measured: ready moments
  sat unseen for 17–47 minutes with both sides healthy, and the healthier the other side, the longer.
  Make the state check part of every send, not a separate duty.
- **An idle prompted peer can be reaped.** Measured: about an hour after its last activity, in
  whatever state it was in, with no log. Item 1's idle notice cannot fire for a peer that is gone, so
  **whether a peer still exists is read from a process listing**, never inferred from the absence of an
  idle notice; whether it is live is still artifact freshness (§ A.15's cited sheet, § 2).

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
6. **Your cadence, if your workers are prompted** (§ A.15) — the note interval and the wake-up
   interval, **where the note is written**, who pokes an overdue worker and with what words, and the
   paths of the pause and done files. **And the line in your working agreement that carries the
   worker's half**, named by path, because § A.15's whole point is that this one may not live in a
   prompt. `<fill-in>`
7. **Your own § C.** It will be more convincing to your team than the one below.

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
| Two prompted sessions each waited for the other to speak first | Half a working day lost; the silence looked exactly like progress from outside | § A.15: only the spawner has a clock, and notes come from inside the work |
| A restarted session inherited the queue and the board but not its predecessor's opening instructions | A cadence obligation lapsed silently; the successor worked correctly and reported to nobody | § A.15: the obligation lives in the working agreement — one delivered at session start is a conversation citing itself |

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
