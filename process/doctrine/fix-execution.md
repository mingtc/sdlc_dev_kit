<!-- KIT-CLASS: KIT — transferable doctrine. § A is the pattern; § B is the fill-in for YOUR program; § C is the donor project's catalogue, anonymized. -->
# Fix-execution doctrine — landing what a round found, without minting what it warned about

> **Size note, owed by [`lookup-tables.md`](lookup-tables.md) § A.1.** This sheet is over that
> section's 32,768-byte trigger and is **deliberately not split**: its § A items are a single
> execution order, and a reader who arrives at A.9 needs A.1's framing to act on it.

A measurement round ends with verified findings and a slate of work items. This sheet is about the
next stretch: turning that slate into landed changes and a cut. **The characteristic failure of this
phase is not bad fixes.** It is **fixes that re-create the defect class the round just paid to find**,
and **truth that rots corpus-wide while every individual change passes review.**

**Where it sits.** [`dogfooding.md`](dogfooding.md) produces the findings and hands off at its § A.13
/ § A.14. [`subagent-control.md`](subagent-control.md) is the dispatch machinery these runs ride on.
This sheet is the span between them and the cut — the two gaps a mint → implement → verify → land
model leaves open: **between findings and implementation**, and **between the last landing and the
release**.

**How the overlaps are handled.** Where a rule already lives elsewhere, this sheet carries a
**pointer plus its own increment** — the convention [`dogfooding.md`](dogfooding.md) § A.2 already
uses for [`instruments.md`](instruments.md).

---

## § A — The pattern

### A.1 — A minted work item is a hypothesis; scrutinize the slate before implementing it

The items were minted from findings by someone reasoning at **findings altitude**. Before any
implementation: **one fresh-context reviewer per item, read-only**, answering four questions with
file-level evidence.

1. **Does the proposed fix close the finding it names?**
2. **What else does it move?**
3. **Does it re-create a defect the round already found?**
4. **Is any part of it secretly a decision nobody made?** — and if so, who decides.

An item can be well-written, well-cited and still aimed at the wrong **mechanism**. That is the
failure this pass exists for, and it is invisible from inside the mint.

**Expect the pass to pay.** In the program that produced this sheet, most of the slate needed
rescoping before implementation — none aimed at a wrong *problem*, several at a wrong *mechanism*,
two would have re-minted the round's own headline defect, and one systematic mint error was repeated
across every item (caught once, fixed everywhere).

**What makes it work — and the first is the one that gets left out.**

- **Holding or rescoping an item is a SUCCESS, and the reviewer must be told so in the brief** — or
  they will grade for implementability and hand back a plan instead of a verdict.
- **Read-only, and say so.** It is what lets several reviewers run concurrently against one working
  tree, which is usually the only way the pass is affordable. That is a property of the *fleet*, not
  of the review, and it goes unstated at the cost of a deadlock.
- **The reviewer re-derives the item's claims from their cited sources, and checks what the source
  did NEXT.** A finding filed weeks ago may have been closed, narrowed or reversed by its own author
  since; the slate will not know. Reading only the item cannot reach that class, and it is where the
  most expensive rescopes live — an item can faithfully quote a finding its source has since ruled
  unfixable.

**And the closing rule, which is what makes the pass more than a document.** The rescopes are
**applied to the item files** by whoever owns minting, citing the scrutiny record — so implementers
work from **corrected contracts, not from a side-channel of caveats**. A scrutiny pass whose findings
live only in the reviewer's report has moved the defect rather than removed it: the next reader opens
the item, not the report.

### A.2 — A ruling is recorded before it is executed — verbatim, with its order and the order's consequence

**The pattern is [`requirements/DECISIONS.md`](../../requirements/DECISIONS.md)** — the
three-field entry, stable retired-never-reused ids, the register as a projection, and the
same-commit rule.

**What this sheet adds, for a ruling that is about to be executed rather than merely recorded:**

- **Before execution, not after.** A product decision that lives only in a prompt, a chat, a
  coordinator's memory, **a run log or a message to a peer** is invisible to the successor and
  **uncitable by the work items that depend on it**. Record it first; every item that touches it
  cites the record as its authority. *The crisp form, and the two surfaces added because this is what
  a real crunch loses rulings to:* **a ruling is not recorded until it is in the file the work will be
  done from.** A run log is written once and read by whoever was there; a peer message is read by one
  person. Neither is where the next implementer opens the item.
- **Verbatim, in the decider's own words.** A paraphrase of a ruling is a second authoring site for
  it, and the paraphrase is the copy that goes stale. Where the decider hedged, the hedge is part of
  the ruling — it is what tells a later leg the ruling may be reopened on evidence.
- **What was explicitly NOT ruled, listed beside what was.** Otherwise a skipped question is
  indistinguishable from a settled one, and the default gets adopted silently by whoever needs an
  answer first.
- **The ruled ORDER, and why the order is load-bearing** — not the sequence alone
  ([`subagent-control.md`](subagent-control.md) § A.11). A reader who can see what breaks can also
  tell when the constraint has stopped applying.
- **Whether the ruling has ever been EXECUTED, said in the record itself.** A rule nothing has yet
  had to obey is **untested**, and its record should say so. The audit question is cheap and it is
  the only thing separating a rule that works from one that has merely never been tried: *has this
  ever actually been executed, or only described afterwards?* Until a prospective case meets it, the
  instances that accumulate under it are **retrospective** — read backwards onto work that was going
  to happen anyway — and those look exactly like compliance. The mark comes off the first time a
  real case obeys the rule and the ruling survives the meeting.

*The failure this prevents is not hypothetical: a ruling recorded on one writable surface while the
coordinator's main surface went unpushed left the successor unable to find the authority its own
launch prompt cited.*

### A.3 — Carry the round's own traps as acceptance criteria in every mint

A round's most valuable output is often the **shape** of its worst finding. **The fix program's
dominant risk is re-entering those shapes while fixing them** — so the traps travel as **acceptance
criteria, not as advice.** Advice in a brief is read once; an AC is graded.

Worked forms, from the program that produced this sheet: any new status token is **one** constant
that code and docs project from, under a bidirectional guard; any helper calls the real code path,
with a test that reddens on divergence; any *"derived"* label is backed by a mechanism a **planted
new member** can prove.

*In the source program the only two implementation defects that survived to review were exactly these
classes, and both were caught by fresh-eyes review briefed to look for them.*

### A.4 — Truth is corpus-wide, review is per-item — and that owes TWO obligations, not one

Every landed change outruns some sibling statement of the same fact. Per-item review judges the
item's own grep list, and **nobody's grep list is the corpus.**

**One pre-cut sweep is necessary and is not sufficient.** A sweep at the end is the **only** thing
that can find a stale statement in a file nobody edited, and the **worst** thing that can find one a
*later phase will be written against*: by the time it runs, the phases that inherited the false
premise have shipped. So the obligation splits by *when the staleness bites*.

**A.4a — In-change, one hop, every change.** The author checks the statements **its own operands
make**, and the statements that **cite those operands**. That is one hop, the files are already open,
and it is the same discipline [`staleness.md`](staleness.md) § A.1 already requires for retirement —
*paid by the change that causes it, in the same commit, never a sweep.* This sheet only extends the
trigger list: **a claim you just outran is a retirement you now owe.** The cheap forms:

- a count or universal in the file you edited (`staleness.md` § C);
- a document that cites the thing you changed — found by searching for the **name**, not the path;
- and, where a change lands in a **phase program**, whether it falsifies a statement a *later* phase
  is scheduled to be written against. That one is cheap to check and expensive to miss, because the
  later phase will treat the falsified statement as its specification.

**A.4b — Pre-cut, corpus-wide, and REPEATED until a round finds nothing.** After the last landing
and before the cut: **one fresh-context checker per consumer-facing surface**, each verifying every
claim on its surface against the tree **as it stands** — hunting claims that contradict the landed reality, same-change
duties that missed a surface, dead cross-references, and bare counts or universals with no
derivation or date. This is the half A.4a structurally cannot reach: **surfaces no diff touched.**

*Calibrate expectations by measurement: in the source program a full sweep after a fully-green,
individually-reviewed program found dozens of defects, a large minority of them false consumer
claims — several pre-dating the program and visible only because the sweep read surfaces nobody's
diff had touched.*

**Repeated, because fixing a finding is a landing:** a fix round edits the very surfaces the next
reader meets. Measured across two adopting projects — a round's own fixes introduced claims the round
had just finished verifying. So the sweep **re-runs after every fix round, until a round finds
nothing.** A single pass certifies the tree as it was before the fixes, which is not the tree that
ships.

**THE CHECKERS NEED NOT BE CONTEMPORANEOUS — and the price of that is one named reader, not a
disclaimer.** Requiring them all to read the **same** tree makes a one-file fix cost a whole sweep
again; not requiring it permits a cut assembled from readings of trees that never existed together.
So:

- **A surface's verdict is carried forward only while no file that surface CLAIMS has changed.** The
  surface list is what says which files those are; a list with no path expression per surface cannot
  support this rule and has to re-read everything.
- **The record names each surface's OWN tree**, never one global sha, and the sweep **prints the
  span** — oldest surface tree to newest.
- **A NON-ZERO SPAN OWES ONE ADDITIONAL READER, whose subject is CROSS-REFERENCES.** This is the
  load-bearing clause and it is why the permission is safe. A carried-forward verdict answers for
  what a surface says **about itself**; it does not answer for what one surface says **about
  another**, and two checkers reading two different trees can both be right while the claim spanning
  them is false. That residual is not eliminated by any per-surface rule — so it is **assigned**
  rather than assumed away.
- **A zero span owes no such reader**, which is the whole incentive: a sweep run at one tree is
  cheaper to certify than one assembled across several, and the doctrine should say so rather than
  pretending the two are equivalent.

*Why this is stated rather than left to the gate: a gate cannot enforce a span rule its doctrine has
not chosen.*

**VERIFY BY EXECUTION WHERE THE SURFACE CAN BE EXECUTED, not only by reading.** A claim about what a
command prints, what a refusal says, or what a flag does is checkable by running it, and reading is
the weaker instrument for exactly those: it confirms the sentence is plausible against the source
rather than true against the binary. **Usage and `--help` text are surfaces**, and a surface list
that omits them omits the claims most cheaply falsified.

**STAND AS A NAIVE CONSUMER, not as the author.** The checker's question is *"does this document tell
someone who has never seen this repository something false?"* — not *"can I reconstruct what the
author meant?"* An author-stance read repairs the sentence silently while reading it, which is why
the checker must be someone who did not write it. **Brief them adversarially** — that is
`doctrine/subagent-control.md` § A.3's finding, not a second rule, and it is not close.

**Fix the findings by MECHANISM, never by symptom.** Generated regions through their generators,
projections through their sources, guarded phrases by transforming the guard **with its reason**. A
hand-edited generated region is a defect even when its bytes are correct.

### A.5 — Two buckets at mint time, and the sorting question is "is there a decision here", never "is it small"

Split every candidate fix into **net-positive-and-only-effort** (mintable — land it) and **carries a
tradeoff** (a functional change, a lopsided-complexity edge-case fix, a new supported surface — the
decider's, parked with a recommendation).

**Sorting by size is the failure mode.** A one-line signature change can be a decision; a five-file
documentation surgery can be pure effort. Miscategorising in the **permissive** direction lands work
nobody consented to; in the **restrictive** direction it costs one batched question. The asymmetry is
the whole rule: when torn, park it and batch it
([`subagent-control.md`](subagent-control.md) § A.9).

### A.5b — A MECHANISM where the act is irreversible OR the failure is silent and compounding; a SENTENCE everywhere else

§ A.5 sorts a fix by *whether there is a decision in it*. This rule sorts the **remedy**: having
decided to fix something, do you write a sentence, or do you build a thing that refuses?

> **A mechanism is owed where the act is IRREVERSIBLE, or where the failure is SILENT AND
> COMPOUNDING. Everywhere else, prefer the sentence.**

**Why two halves rather than one, and the second is the one that gets left out.** The irreversible
half is easy to accept: where an act cannot be undone, an instruction that is usually followed is not
enough, and the structural cure lands in the same change as the rule
([`live-resources.md`](live-resources.md) § A.10). The **silent-and-compounding** half was added
later, on evidence, and it covers a class the first half misses entirely: failures that are perfectly
recoverable and that **nothing reports**, so the recovery never starts. The cost is not the failure;
it is the interval between the failure and anyone noticing, multiplied by everything built on the
false belief in between.

**The two tests, asked in order:**

1. **Can this act be undone?** If no — mechanism.
2. **If it goes wrong, what tells anyone?** If the honest answer is *nothing*, or *a later reader who
   happens to look* — mechanism, however recoverable the damage is. If something reports it loudly
   and soon, a sentence is enough, and the sentence is cheaper forever.

**Why the second half is not merely permitted but necessary.** The argument against it is that care
should cover a recoverable failure. Measured against that: a defect class was documented, and then
**the two people best informed about it in the repository both walked into it within five minutes of
writing it down** — one while annotating the entry, one while verifying the annotation. The finding
recorded at the time is the rule's real basis: *the trap does not require inattention, and **care is
demonstrably not the cure**.* Where a failure is silent, the person best placed to catch it is the
person least able to, because they are looking at the thing they just did.

**And the counterweight, which is why this is a boundary and not a licence.** When a process fails,
the instinct is to add process, and machinery accumulated in reaction to failures becomes
indistinguishable from scar tissue to whoever inherits it
([`subagent-control.md`](subagent-control.md) § C). At least one member of **this sheet's own § C
catalogue** was correctly answered by documentation rather than machinery — a guard that fired on an
honest report, working as designed, whose amendment was to name the exemption where reports are
written. **A rule enforced by a new subsystem costs more forever than a rule stated once and
followed**, so the burden of proof sits on the mechanism, and these two tests are how it is
discharged.

**The worked instance, and it is the added half's first payment.** A board mover's sync could leave a
metadata commit reachable from no ref at all. **Nothing about it is irreversible** — the commit is
recoverable from the reflog, and the donor project recovered one that way. Under an
*irreversible-only* boundary, every guard for it would have been a sentence. What earned the
mechanism was the second test: the tree is clean after the commit, so the dirty check cannot see it;
the commit is not an ancestor of the ref, so the divergence arm reports **in sync ✓**; and the leg's
own board note **truthfully** says the record was committed. **Nothing reports it, and every later
reader believes the missing record is present.** That is the shape, exactly.

**State which half you invoked, and why, in the change that invokes it.** A mechanism built without
naming its half is a mechanism nobody can argue with later — and the two halves have different
expiry: an act can stop being irreversible, and a silent failure can acquire a report, at which point
the mechanism should be re-litigated rather than inherited.

*This rule is stated here and nowhere else.* [`subagent-control.md`](subagent-control.md) § C and
[`live-resources.md`](live-resources.md) § A.10 each argue one side of it from their own evidence and
point here for the boundary; [`orchestration.md`](orchestration.md) § A.5 applies it. It sits in this
sheet because the moment it binds is **while deciding how to fix something**, which is this sheet's
subject.

### A.5c — A second failure in the CURE'S OWN BLIND SPOT ends the item; it does not buy another round

**The fix-round budget is a count, and the count is the whole rule.** One bounded round on a FAIL,
then the item is done failing. That is right for the ordinary case and it has no way to express the
one that matters most:

> **round N's defect lives in exactly the blind spot round N−1's fix created.**

**Another round is the wrong response to that, and spending one is how a leg burns its budget
reproducing the same class.** The second failure is not more of the first — it is *evidence about the
approach*, and a third attempt from the same angle by the same author will find the blind spot the
second cure creates. **The terminating move is a change of SHAPE or of AUTHOR: a different approach,
or different eyes. Never another round.**

**How to tell a cure-shaped failure from an ordinary second one** — the question is not "is this
related to the fix", because everything after a fix is related to it:

- **Ordinary:** the fix was incomplete, or wrong, in the region it was aimed at. Another attempt at
  the same region is a reasonable thing to want, and the budget correctly refuses it anyway.
- **Cure-shaped:** the fix *worked*, and the new failure sits where the fix's own assumptions do not
  look — the guard that now passes for the wrong reason, the case the narrowed scope excludes, the
  operand the new expression cannot see. **The cure did not miss it; the cure produced the place
  where it could hide.**

**AND THIS IS A SHAPE-OR-SCOPE CHANGE, NEVER A PROVISIONING ESCALATION.** *"Try again, harder"* — a
bigger model, more effort, a longer leash — reads as the obvious answer. But **a bounce never
silently escalates the model or the effort**: escalation is a deliberate per-item decision
([`model-provisioning.md`](model-provisioning.md) § B.1), and here it would not work anyway, because
capability is not what is missing when the search is pointed at the wrong place. Say
**different approach** or **different author**, and say which.

*What this owes the record:* the item stops with the blind spot **named** — what the cure assumed, and
where the new failure sits relative to that assumption. A stop that says only *"failed again"* hands
the next reader the same budget and the same angle.

### A.5d — A protection reachable only by memory is not a protection; move the default, confirm the effect, or change the reader

§ A.5b decides **sentence or mechanism**. This rule binds **one step later**, when the answer was
*mechanism*, the mechanism was built, it demonstrably works — and it turns out to sit on a branch a
bare invocation does not take. **§ A.5b reads as satisfied by that state and it is not:** its
obligation was discharged the moment the thing that refuses existed, and the damage still happened,
because nobody invoked it.

> **Where a correct rule exists and keeps being broken by the people who know it, the defect is in
> the rule's REACHABILITY, not in anyone's care.**

**"Be more careful" is the remedy that has already failed by the time the class is visible**, because
by then the people breaking the rule are the people who wrote it down. § A.5b's own evidence is the
first proof of that on this sheet — *the two people best informed about a defect class both walked
into it within five minutes of writing it down*, and the finding recorded there is that **care is
demonstrably not the cure**. What is left is to change the geometry: **what a bare invocation gets
you, what a step's success actually proves, and who is reading.**

**Three remedies, and they are ordered by cost because that is the order to try them in.** The first
removes the memory requirement entirely; the second replaces it with one mechanical act at the moment
of the step; the third is what is left when neither is available.

| # | The remedy | What it does to the memory requirement |
|---|---|---|
| **1** | **Move the DEFAULT.** Where a consequential effect is reachable by a safe route and an unsafe route, and the unsafe one is what a bare invocation gets you, **change which route is the default. Do not document the safe route better, do not add a warning, do not ask for care.** | **Removes it.** Nobody has to remember anything. |
| **2** | **Confirm the EFFECT, not the report** — and the confirming read is **chosen by the effect's class**: write a file → re-read the file; commit → ask the log; **push → ask the remote, never the local ref**; move a card → ask the board; edit a guard → **watch it fail**. | **Replaces it** with one mechanical act at the moment of the step. |
| **3** | **Change WHO IS READING.** Hand forward the prose adjacent to the change that was **left alone** — a list, not a judgement: *"these lines sit next to what I touched and I did not change them."* | **Moves it** to a party who can discharge it. |

**Remedy 1 carries its own exit, and the exit is what makes it a rule rather than a preference.**
Where a default genuinely cannot be moved — callers break, the protection is expensive — this rule
does **not** license a warning instead. It requires the attempts to be **enumerated**, in the
vocabulary [`negative-claims.md`](negative-claims.md) § A.1 already ships: the routes actually tried,
listed, enough that a reader can see the edge of the evidence. *A default that could not be moved* is
a measured result and is written as one; *a default nobody tried to move* is not a finding.

**And remedy 1 ships with a reviewer's question rather than a guard**, deliberately: *for the thing
this change protects, what happens if nobody invokes the protection?* **If the answer is the damage,
the default is the defect.** No guard is offered because a guard for this class would have to refuse
on the presence of a protection it cannot tell is optional, and a gate that refuses on the ordinary
case gets disabled — and **a disabled gate reads as armed** to everyone who does not go looking.
§ A.6 below states the same cost from the other end: a gate that reddens for reasons unrelated to
its property trains everyone to ignore it.

**Remedy 2's whole content is one sentence: the report is evidence the tool ran, never that it
worked.** A success message, an exit status and an absent error are all reports *about* the effect;
none of them is the effect. The shape above is a **shape**, not a table to copy: name your own
per-effect confirming read in § B, because the classes that matter are your program's. **The
widening is the part that is easy to lose** — where a step has an effect beyond the file it writes,
the confirming read is of the **effect**, and reading the file can pass while the work is still
wrong.

**Remedy 3's mechanism is a change of READER, not a change of care** — an author reading their own
change sees what they meant; a second party handed *"here are the lines I left alone"* is reading a
claim about untouched text, which is the one thing an author cannot check about their own work.
**That is why it can work where "be careful" cannot.**

**Three things bound remedy 3, and all three are its own limits rather than objections to it:**

- **No gate.** A guard refusing on the presence of nearby prose would refuse on every documentation
  edit ever made. This is a reporting duty and a reviewer's read.
- **A window, not a practice to drop.** Where the list gets expensive on a large edit, **narrow the
  window and say so**; dropping the practice is not the sanctioned remedy.
- **Its second-party half is UNMEASURED.** The one measured catch had the author produce *and* read
  its own list, and it still worked — so *"the list works because a second party reads it"* is a
  mechanism this sheet states and **has not measured**. Notice whether the author-reads-own-list
  shape is carrying the weight; do not build a gate for it.

**Remedy 3 does NOT extend to a negative result, and the boundary is stated elsewhere and binds
here.** [`negative-claims.md`](negative-claims.md) § A.5 measured a case where the reviewer *was* the
second reader: both parties were right about the mechanism and **both stopped at the same place,
having taken the same route.** For a negative, what is owed is a second **route**, not a second
reader. Remedy 3 changes who reads a positive claim about untouched text; it does not turn a
route-bound *cannot* into a measured one.

**Why this is one rule and not three.** Each remedy answers the same question from a different
distance, and each was reached after the same discovery: **the people breaking the rule already knew
it.** Stated separately, each arrives as a tip. Stated together, the common premise is the argument,
and the three become a **cost-ordered choice** a reader makes once.

**What this rule does NOT claim.** It states no rate for any of the three classes — every count
behind it is an instance count from a record, with **no sweep attempted**. It is not the rule that
decides *which* route a given tool should default to; whether a bulk operation previews or mutates is
each tool's own contract sheet's business
([`../contracts/issue-creation.md`](../contracts/issue-creation.md) parks that question in terms).
**This rule binds one level up**, and only in a narrower state: **a protection has already been
built, it works, and it has been found to sit on a branch a bare invocation does not take.** Nothing
here permits *"the mechanism exists, it is strong, it is optional, and the remedy is a warning."*

*A protection you have to remember to invoke is one you will eventually not invoke, on a day when
you are busy — which is exactly the day it matters.*

### A.6 — A gate budgets a PROPERTY, never a machine

A gate that asserts a **wall-clock** budget measures the host's load, not the property it exists to
bound — and under a loaded host it will **serially refuse legitimate landings until someone is
tempted to bypass a binding gate, which is the real cost.** Budget on load-independent measures:
process CPU time, work units, bytes processed, counts.

*(The kit already prefers CPU deltas for **liveness** — [`../MANUAL.md`](../MANUAL.md) § Execution
discipline, item 4. It has never said it about **gate budgets**, which is what this rule adds.)*

**And re-cutting such an instrument owes two things, both easy to skip:**

- **Prove the new budget BITES** — plant the slowdown, watch the red, restore. A re-cut budget that
  has never been seen to refuse is a number, not a gate
  ([`instruments.md`](instruments.md) is the sheet on that).
- **Keep the original reason in the instrument's own text.** The old threshold had a why; the new one
  supersedes the conclusion and not the reason ([`supersession.md`](supersession.md)). An instrument
  whose reason was overwritten is one nobody can re-tune safely.

A gate that reddens for reasons unrelated to its property **trains everyone to ignore it** — the
validator-mismatch rule of [`instruments.md`](instruments.md) § A.8, with **host load as the concrete
attacker**. That is what makes a wall-clock budget worse than a merely inaccurate one: it does not
just measure the wrong thing, it teaches the team that this gate's red means nothing.

### A.7 — Every claim about remote state is a dated reading, and landing steps must survive their caller

Two independent lessons from one seam.

- **"Deleted, confirmed gone" and "pushed, accepted" are readings at an instant.** A mirror, a sync
  or a replica can un-do them *after* the reading was honestly true — including a force-push that
  reports success and never lands. So verify remote state **by reading the tree at the moment you
  rely on it**, never by a remembered confirmation; and for publish steps read back **immediately,
  and once more after a delay**, because the reverting agent runs on its own clock. When a deletion
  or a publish keeps un-doing itself, that is a **remote-side question to escalate — never a loop to
  fight.**
- **Multi-step landing scripts get killed mid-run** — by caller timeouts, by shells, by the host. So
  make each step **idempotent or detectable-as-done**, and **print the remaining-steps recovery as
  part of normal output**, so a successor (or the same coordinator with a fresh shell) can finish the
  job from the script's own words. *The script that saved its own interrupted landing was the one that
  printed its recovery lines; the coordinator's contribution was only to read them.* The caller's
  half of the same rule: **never wrap a landing script in a short timeout.**

### A.8 — One authoring site, everything derived from it, and a guard that bites when they part

This is **not** "have one enumeration". It is the projection discipline, applied to the process's
vocabulary about itself: **one authoring site; every other appearance derived from it; and a guard
that reddens when the two part.**

The failure it prevents, measured: a reviewer correctly returned a ratified *"pass, every gate green,
landing deferred"* verdict, and the run machinery — whose schema knew only pass/fail — **halted a
successful run.** The role doc's vocabulary and the machinery's enum were authored separately, so they
diverged, and the divergence was read as a failure.

**The test to apply, and it is harsher than it looks:** for every vocabulary the process uses about
itself, name the **one place it is authored**. If you cannot, the vocabulary has no authoring site,
and every appearance of it is an independent assertion.

### A.9 — Mints cite by content anchor, stamped with the tree they were read against

**The pattern is [`requirements/DECISIONS.md`](../../requirements/DECISIONS.md)'s anchor
convention and its tree stamp** (prefer a section anchor over a bare `file:line`; reserve line
anchors for append-only ledgers; record the tree the anchors were read against) and
[`lookup-tables.md`](lookup-tables.md) § A.4. **Here it binds every mint, with two corollaries about
phases.**

- **Stamp every mint with the tree identifier its citations were read against.** Line numbers rot in
  hours on an active trunk, so a work item minted early in a program carries citations that are stale
  before its implementer opens the file.
- **When a slate is executed in phases, mint each phase's items AFTER the prior phase lands**,
  against the tree they will actually meet. Minting the whole slate up front produces citations that
  were never true at the moment they were used.
- **A count inherited from a mint is re-derived on the branch.** *In the source program the count had
  moved between mint and implementation, and the reason nothing broke is that the mint had made the
  count re-derivable rather than load-bearing.*

**And the operand has to be in the repository doing the citing. A citation into a document you do not
control is not a citation, it is a hope.**

A findings round is usually fed by documents from **somewhere else** — another project's feedback
file, an attachment, a report pasted into a conversation. Those become the authority for dozens of
work items, and the items cite them by id or by section for the whole life of the program. **Every one
of those citations is unresolvable the moment the source moves, is edited, or belongs to a repository
this one does not own.**

- **Copy every supplied document into this repository, verbatim, before minting anything that cites
  it.** Not a link, not a path into a sibling project, not a quotation in a card — **the
  document.** It is an operand, and an operand outside version control is not one.
- **Date the copy by the day it was supplied, and never edit it.** Later feedback from the same source
  is a **new dated file**, because the thing that makes the original citable is that it still says
  what it said when it was cited. *One carve-out, serving that same reason rather than weakening it:
  a document that arrived corrupted in transit (mojibake, stripped bytes) may be repaired
  **mechanically** — and the raw bytes are preserved beside the repair, so the transformation is a
  diff anyone can run rather than a claim anyone must trust. Corruption moves the text away from the
  referent its citations mean; the repair moves it back. An un-preserved repair is an edit; a
  preserved one is a restoration with its own witness.*
- **A supplied document that cannot be recovered is NAMED as missing**, beside the ones that were —
  with what depends on it. *A missing input nobody names reads exactly like an input nobody needed.*

**Consuming a supplied document incurs a DUTY TO ACKNOWLEDGE, and it runs the other way.**

The rules above make the supplier's document citable. Nothing makes the supplier's *finding* answerable.
So from the filer's side, **"we fixed it" and "we never read it" look identical** — the notes are
append-only and newest-first, a fix arrives as a line about the fix, and no line is about their report.

- **Every finding consumed from a supplied document gets a DISPOSITION that the filer can find**, and
  there are exactly four: **fixed** (with what landed), **declined** (with the reason), **already
  shipped** (with where), or **not ours** (with why). *"Read it" is not a disposition and neither is
  silence.*
- **The disposition is recorded where the FILER can reach it, in a record keyed by THEIR identifier
  for the finding** — their own item id, their section number, their line. Keying it by yours makes it
  findable by you, which is not the problem being solved.
- **This does not go into content you ship onward.** A supplier's identifier means nothing in a third
  party's tree, and putting it there manufactures exactly the unresolvable citation the rules above
  exist to prevent. The acknowledgement belongs in **your** change records, your reply, or a
  disposition file beside the copied document — all of which the filer can be pointed at, and none of
  which travels to somebody it would confuse.
- **The cost runs BOTH ways, which is the argument for making this a duty rather than a courtesy.**
  Without a disposition the supplier cannot tell fixed from ignored — and **you cannot either.**
  *Measured: two findings were re-read as live months after being fixed and shipped, because nothing
  in any document connected a fix to the report that caused it. The re-reading cost more than the
  acknowledgement would have.*

**The failure is quiet and it compounds** (§ A.5b's second half), which is why this is a step rather
than a caution: nothing breaks at mint time, every citation still looks fine in review, and the
program only discovers the gap when an implementer opens a path that is not there — by which time the
citing items number in the dozens. **Watch for the sharper version: fixing the instance without
fixing the class.** *In the source program two attachments were transcribed after a leg reported them
as a blocker — and the largest supplied document of all, carrying most of the ids the backlog was
built on, was left sitting in another project's tree for the rest of the crunch. The instance was
closed; the class was not, and nobody noticed until the supplier asked.*

### A.10 — A consent id authorizes a spend, and a full-suite run is its own spend

**Stated in full in [`live-resources.md`](live-resources.md) § A.4:** consent carries the authorizing
issue id, the id buys one item's targeted selection, and a full-suite run at a phase boundary is its
own budgeted, recorded decision.

### A.11 — One writer per surface at a time, and the checker watches every writable home

Serialization lessons that cost real wall-time.

- **Shared-append surfaces serialize a slate whether or not the code overlaps.** A release-notes
  section every item writes into is a lock, and the run plan should say so **once**, rather than the
  slate discovering it as merge bounces.
- **The coordinator must not commit to a checkout a run holds.** A metadata commit made while a work
  branch is checked out lands **on the branch**. Route coordination commits through a dedicated
  always-on-trunk worktree, and treat *"the run holds the checkout"* as a lock.
- **Board state read from a live checkout races the run** — mid-switch, folders transiently show
  phantom historical files. Read it from the always-on-trunk worktree, or only from a quiet checkout,
  and **know which one your tooling reads.**
- **A sync check must cover every writable home.** One that verifies the staging worktree against the
  remote but never asks whether the *main checkout* is ahead or behind will report a clean board while
  a day of unpushed history sits beside it — which is exactly how the ruling in § A.2 went missing.

**A FLEET SHARING ONE WORKING TREE: what it owes, and why an instruction is not enough.**

Several agents in one checkout means **any one of them switching branches changes every other's
answer.** The bullets above cover the coordinator; these cover the topology.

- **FILE DISJOINTNESS IS NOT ISOLATION.** Assigning non-overlapping files is necessary and it is not
  sufficient, because the things that actually contend cannot be assigned to an item at all: **HEAD ·
  the current branch · the index · a gitignored build tree · the next free id in any sequence.** A
  peer can move every one of them with zero file overlap the whole time. **Say this to the legs**; a
  brief that promises non-overlap and stops there is *reassuring about exactly the surfaces it does
  not cover*, which is worse than saying nothing.
- **A WRITING PHASE GETS A WORKTREE OF ITS OWN. This is structural, and the structure is the point.**
  Not *"confirm the branch first"*, not *"wait your turn"*. **A rule of that shape was shipped, and
  it was violated repeatedly by the very seat that had written it down and promoted it to durable
  law.** An instruction a careful actor keeps breaking is not an instruction problem: the working
  tree is the operative object, and there is no ordering of checks that makes a shared root's branch
  yours while something else can move it.
- **A COORDINATED FLEET PRODUCES PROBE-NOT-SUBJECT ERRORS AT A RATE, and the rate is a property of
  the FLEET, not a failing of whoever wrote the probe.** Enough concurrent measurement and some
  fraction of what a leg reports will be about its own instrument, its own stale read, or a peer's
  in-flight change. Budget for it.
  **The cheap defence is DISCLOSURE, not better probes** — every finding states what it measured,
  when, and against which ref, so a peer can tell *"the subject is wrong"* from *"you read it while I
  was moving it"* **without re-running anything**. Better probes are expensive and reduce the rate;
  disclosure is free and makes the residue diagnosable, which is the property that actually matters.
  *The measured instance — a correct measurement carrying an invented attribution — is
  [`instruments.md`](instruments.md) § C's last example, and the rule is its § A.9.*

---

## § B — Your program's instance — **fill this in**

> **PROJECT INSTANCE from here down.** Nothing here is inherited. On day one this section is
> correctly empty.

1. **Your scrutiny brief** (§ A.1) — the four questions, the read-only clause, and the sentence
   telling the reviewer that holding is a success. `<fill-in>`
2. **Your ruling-record location and its citation convention** (§ A.2). `<fill-in>`
3. **Your two-bucket sorting record** (§ A.5) — where the parked-with-a-recommendation items live.
   `<fill-in>`
4. **The inventory format the pre-cut sweep's fixes are verified against** item by item (§ A.4b).
   The surface list itself lives in `PROJECT.md` § The pre-cut sweep's surface list. `<fill-in>`
5. **Every vocabulary the process uses about itself, and the ONE place each is authored** (§ A.8) —
   plus the guard that reddens when a projection parts from it. A vocabulary you cannot name an
   authoring site for is listed here as **unauthored**, not as fine. `<fill-in>`
6. **Your per-effect confirming reads** (§ A.5d, remedy 2) — one row per class of effect your work
   actually produces, each naming **what is asked** rather than what is reported: the file, the log,
   the remote, the board, the guard's red. **A wrapper is one implementation of a row, never the
   rule** — the kit requires only git and a POSIX shell, so a row is satisfied by a habit, a
   checklist line or a script, and a project that has built a wrapper names it here as its
   instance. `<fill-in>`
7. **Your consent-id policy for full-suite runs** (§ A.10). `<fill-in>`
8. **Your writable homes, and which one each tool reads** (§ A.11). `<fill-in>`
9. **Your own § C.** It will be more convincing to your team than the one below.

---

## § C — Worked example: the donor project's catalogue (anonymized)

> Shapes, not incidents. Each happened **under the practices above** during one fix program, and each
> names the amendment — a sentence where a sentence carries it, a seam fix where it cannot.

| The failure | What it cost | The amendment |
|---|---|---|
| A reviewer returned the ratified *"pass, landing deferred"* verdict; the run machinery's schema knew only pass/fail and **halted a successful run** | A completed, fully-green review treated as a stop | § A.8: one authoring site, projected into the machinery's schema; *land-ready* is continue-and-defer, never halt |
| A multi-step landing script was killed by its caller's timeout between the merge-push and the board move | Partial state; manual completion from the script's own recovery lines | § A.7: idempotent / detectable-as-done steps; recovery printed as normal output; never wrap a landing in a short timeout |
| A wall-clock gate budget under external host load refused many consecutive legitimate landings | A pipeline blocked for hours; the temptation to bypass a binding gate | § A.6: budget the property; prove the re-cut bites with a planted slowdown |
| Every item in a slate repeated the same hand-written instruction, and all of them were wrong the same way | A slate's worth of wrong instructions; caught by scrutiny, ruled once | § A.1 catches it; the seam fix **derives** the instruction from the item's own tags instead of restating it per item |
| The board checker verified the staging worktree's sync and never the main checkout's ahead/behind | A ruling invisible to its successor for a day; a divergence repaired under time pressure | § A.11: the sync check covers every writable home; the session-close ritual asserts it on all of them |
| Deleted remote branches were re-advertised after a confirmed deletion; a force-push reported success and never applied | Repeated phantom residue; one publish that had to be re-published | § A.7: remote-state claims are dated readings; read back twice; a recurring un-doing escalates |
| Board folders read from a live checkout mid-branch-switch showed phantom historical files | A false alarm mid-run; diagnosis against a moving surface | § A.11: read board state from the always-on-trunk worktree or a quiet checkout |
| An enumeration wearing a *"derived rather than typed"* docstring was a hand-typed tuple; a genuinely new member shipped and never joined it | Several shipped statements of a false closed set, one machine-readable | § A.3: a derived label is a claim about **mechanism** — back it with real introspection and a guard proven by planting a new member |
| A slate's full live-suite runs under single-item consent ids overspent a declared budget several times over | An overrun, disclosed and fully reclaimed; a consent id stretched past its item | § A.10: targeted selection per item; the full suite as its own budgeted decision |
| A fully-green, individually-reviewed program still shipped many stale sibling statements, a large minority of them false consumer claims | Would have cut a release contradicting itself across surfaces | § A.4b: the pre-cut sweep as a phase; fixes by mechanism; the inventory saved as an addressable contract |
| A guard forcing closure stamps on cited launch documents fired on a legitimate **mid-program** phase report | A red gate on an honest report | **Working as designed** — the guard's own in-flight exemption carried it. The amendment is **documentation, not machinery**: name the exemption where reports are written |

**The pattern behind the left column** — and it differs from
[`subagent-control.md`](subagent-control.md) § C's, which is *a claim made where a measurement was
available*. These are **seams between two artifacts that each held one half of a truth**: a vocabulary
and a schema, a script and its caller, a checker and the home it did not watch, a label and its
mechanism, an instruction and the state it described.

**So the cheapest correction is the projection discipline a product already applies to itself: one
authoring site, everything else derived from it, and a guard that bites when they part. The process
should hold itself to the rule it enforces on the product.**

> Note the last row before adopting that as a universal: at least one member of this very catalogue
> was correctly answered by **documentation rather than machinery**. What reconciles this closing
> line with [`subagent-control.md`](subagent-control.md) § C's caution against accumulating process
> is **§ A.5b**, which states the boundary and owns it. Both sides of it were paid for; neither is
> wrong inside its own scope.
