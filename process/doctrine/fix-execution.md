<!-- KIT-CLASS: KIT — transferable doctrine. § A is the pattern; § B is the fill-in for YOUR program; § C is the donor project's catalogue, anonymized. -->
# Fix-execution doctrine — landing what a round found, without minting what it warned about

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
uses for [`instruments.md`](instruments.md). Applied provisionally: the general ownership rule is
proposed and not yet ratified.

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

**The pattern is [`templates/DECISIONS.skeleton.md`](../templates/DECISIONS.skeleton.md)** — the
three-field entry, stable retired-never-reused ids, the register as a projection, and the
same-commit rule.

**What this sheet adds, for a ruling that is about to be executed rather than merely recorded:**

- **Before execution, not after.** A product decision that lives only in a prompt, a chat or a
  coordinator's memory is invisible to the successor and **uncitable by the work items that depend on
  it**. Record it first; every item that touches it cites the record as its authority.
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

> **AMENDED from the supplied form, on measured grounds. The supplied rule was a single pre-cut
> sweep. One sweep is necessary and is not sufficient**, because it is the wrong instrument for half
> the problem: a sweep at the end is the **only** thing that can find a stale statement in a file
> nobody edited, and the **worst** thing that can find a stale statement a *later phase will be
> written against*. By the time the sweep runs, the phases that inherited the false premise have
> shipped. So the obligation splits by *when the staleness bites*, not by how much of the corpus it
> covers.

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

**ONCE WAS WRONG, AND THE REASON IT SAID ONCE IS KEPT.** The original word was `once`, on the sound
reasoning that a sweep after the last landing reads a tree nobody will change again. That reasoning
fails on its own output: **fixing a finding is a landing**, and a fix round edits the very surfaces
the next reader meets. Measured across two adopting projects — a round's own fixes introduced claims
the round had just finished verifying. So the sweep **re-runs after every fix round, until a round
finds nothing.** A single pass certifies the tree as it was before the fixes, which is not the tree
that ships.

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

> **This kit currently fails that test, and the failure is recorded here rather than in a backlog
> item, because a sheet that names its own adopter's live violation is worth more than one that does
> not.** Its **landing** verdict set has an authoring site and a projection into the runners. Its
> **scrutiny** verdict set — the vocabulary a slate-scrutiny leg returns — has **none**: it exists
> only inside the dispatch packs that use it, one copy per pack, unratified and unguarded. So the
> second enumeration is in exactly the state the first one was in before it was fixed. Named here as
> owed.

### A.9 — Mints cite by content anchor, stamped with the tree they were read against

**The pattern is [`templates/DECISIONS.skeleton.md`](../templates/DECISIONS.skeleton.md)'s anchor
convention** (prefer a section anchor over a bare `file:line`; reserve line anchors for append-only
ledgers) and [`lookup-tables.md`](lookup-tables.md) § A.4.

**What this sheet adds is the stamp, and two corollaries about phases.**

- **Stamp every mint with the tree identifier its citations were read against.** Line numbers rot in
  hours on an active trunk, so a work item minted early in a program carries citations that are stale
  before its implementer opens the file. The stamp does not stop the rot — it makes it **detectable
  rather than discovered.**
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
  it.** Not a link, not a path into a sibling project, not a quotation in a change file — **the
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

**The failure is quiet and it compounds** (§ A.5b's second half), which is why this is a step rather
than a caution: nothing breaks at mint time, every citation still looks fine in review, and the
program only discovers the gap when an implementer opens a path that is not there — by which time the
citing items number in the dozens. **Watch for the sharper version: fixing the instance without
fixing the class.** *In the source program two attachments were transcribed after a leg reported them
as a blocker — and the largest supplied document of all, carrying most of the ids the backlog was
built on, was left sitting in another project's tree for the rest of the crunch. The instance was
closed; the class was not, and nobody noticed until the supplier asked.*

### A.10 — A consent id authorizes a spend, and a full-suite run is its own spend

**The pattern is [`live-resources.md`](live-resources.md) § A.4** — consent carries the authorizing
issue id, never a boolean.

**What this sheet adds:** running the **entire** live suite under one item's id spends the whole
suite's resource budget against a single item's authority. Default to the **targeted selection the
item actually needs**; run the full suite at phase boundaries as **its own budgeted, recorded
decision**. *The source program's one budget overrun — disclosed, reclaimed, harmless — came precisely
from full-ring runs under single-item ids, and the disclosure discipline (ceiling and intent declared
before the spend; the overrun stated, never absorbed) is what kept it a footnote instead of an
incident.*

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

---

## § B — Your program's instance — **fill this in**

> **PROJECT INSTANCE from here down.** Nothing here is inherited. On day one this section is
> correctly empty.

1. **Your scrutiny brief** (§ A.1) — the four questions, the read-only clause, and the sentence
   telling the reviewer that holding is a success. `<fill-in>`
2. **Your ruling-record location and its citation convention** (§ A.2). `<fill-in>`
3. **Your two-bucket sorting record** (§ A.5) — where the parked-with-a-recommendation items live.
   `<fill-in>`
4. **Your surface list for the pre-cut sweep** (§ A.4b), and the inventory format its fixes are
   verified against item by item. `<fill-in>`
5. **Every vocabulary the process uses about itself, and the ONE place each is authored** (§ A.8) —
   plus the guard that reddens when a projection parts from it. A vocabulary you cannot name an
   authoring site for is listed here as **unauthored**, not as fine. `<fill-in>`
6. **Your consent-id policy for full-suite runs** (§ A.10). `<fill-in>`
7. **Your writable homes, and which one each tool reads** (§ A.11). `<fill-in>`
8. **Your own § C.** It will be more convincing to your team than the one below.

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
