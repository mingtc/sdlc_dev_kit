<!-- KIT-CLASS: KIT — transferable doctrine. § A is the pattern; § B is the project instance (<fill-in>). -->
# Orchestration doctrine — the seat, the runner, and the pack between them

**KIT-CLASS: KIT, with one project-bound section.** § A travels verbatim; § B is `<fill-in>`.

**This sheet is the rationale; the role docs are the enforcement.** The binding statements live in
[`../../.claude/roles/orchestrator.md`](../../.claude/roles/orchestrator.md) (the runner's
contract: the pause law, the between-leg belt, the run-plan gates) and
[`../../.claude/roles/architect.md`](../../.claude/roles/architect.md) (the seat's contract: which
delegation pattern to use, and the duty to verify independently). When this sheet and a role doc
appear to differ, **the role doc binds** and the difference is a defect in this sheet.

---

## § A — The pattern

### A.1 — Two standing positions, and they are not interchangeable

- **The seat** — standing, human-partnered, long-lived. It holds direction and context: it mints
  or commissions the issues, authors the **pack** that launches a run, answers batched decisions
  between runs, and **verifies independently** after a run closes. The seat does not execute the
  run it commissioned.
- **The runner** — a fresh instance per run, wearing the orchestrator hat for the whole session.
  It executes one pack, serially, dispatching worker legs and grading them, and writes the **run
  report**. It does not renegotiate the pack.

**Why the split, and why it is worth the handoff cost.** The seat's value is accumulated context;
the runner's value is that it has none — it reads the pack, the role doc and the issue files, and
therefore executes what is *written* rather than what was *meant*. Every place the pack was
ambiguous shows up as a question in the report instead of being silently patched from memory. The
handoff cost is the price of that signal, and it is also what makes the pack a testable artifact:
a pack that only its author can execute is not finished.

**This is the heaviest of several delegation patterns.** Lighter ones exist and are usually
correct: the seat doing the work itself; the seat driving one level of subagents. Reserve the
seat-plus-runner arrangement for work that genuinely needs **fan-out inside each issue**
(implementer plus independent reviewer per slice, adversarial review panels, a high-risk refactor)
or a run long enough that the seat's context would be spent on relay. The role docs carry the
ladder; the failure mode here is using the heavy pattern by default.

**What the seat's own time is for, which is a different question from the one above.** The seat runs
on the most expensive configuration available and **its context is the scarcest resource in the
system**. So where a task is **mechanical, repetitive, or large**, dispatch it — and there are no
exceptions for *"it's faster if I just do it."*

That does not contradict the paragraph above it, and the qualifier is what keeps the two apart: the
paragraph above chooses **which delegation pattern to reach for** (and the light ones usually win);
this one governs **what the seat's own context is spent on** once a pattern is chosen. Doing the work
itself is a legitimate pattern; doing *bulk* work itself is how a seat runs out of the one thing it
cannot refill. *(Stated with the qualifier deliberately: unqualified, it would be an absolute
standing beside this section's own permission with nothing to resolve them —
[`subagent-control.md`](subagent-control.md) § A.5's defect, in the sheet that warns about it.)*

### A.2 — The pack is a commissioning contract, and the report grades against it

The pack ([`../templates/launch-pack.template.md`](../templates/launch-pack.template.md)) says
what to do and on what terms; the report
([`../templates/run-report.template.md`](../templates/run-report.template.md)) says what happened
and where the pack was wrong. Three properties make the pair work:

- **The pack is not edited mid-run** except to stamp it or to record a ruling that changed the
  order. It is the record of what was asked for; a pack quietly rewritten to match the outcome
  cannot grade anything.
- **The issue ACs are the law, not the pack.** The pack supplies ordering, rigor, standing facts
  and hazards — the things only the seat knows. Where the pack and an issue conflict, the issue's
  AC wins and the conflict is a reported discrepancy.
- **The repo is the truth above both.** Every disagreement between the text and the tree goes in
  the report's discrepancy ledger, and the tree wins. *Report rather than improvise* is the whole
  discipline in four words.

### A.3 — Serial by default, with real landings between issues

One issue at a time; each lands on the trunk before the next branches from it. Serial execution
buys three things that parallelism does not: no merge contention, each issue branching from a
trunk that already contains its predecessor, and a run report whose timeline can bracket an
incident to a single leg.

Parallelism is available and occasionally correct — but it must be **zero-overlap by
construction** (surfaces assigned per lane and named in the briefs), and the price is real:
merge-conflict bounces, plus the shared-register collision class (see
[`../GIT-HOSTING.md`](../GIT-HOSTING.md) § The cross-branch id-collision class). If two lanes must
touch one shared file, the pack states a **seam protocol**: which lane writes it first, and how
the other rebases onto it.

**When the remote refuses pushes, the shape is unchanged** — closes become verified land-ready
verdicts and the landing is deferred to a landing day. The regime is declared at preflight and
re-checked between issues.

### A.4 — Every leg is fresh-eyes, and every worker is a leaf

- **The implementer and the reviewer are different instances.** Context isolation is the point:
  a reviewer that watched the work done cannot review it cold.
- **Every close is reviewed — including a park.** A parked issue goes through a review leg that
  verifies the park is *true*: findings evidence-backed, the issue moved to the blocked folder, no
  half-landed residue. "Parked" and "parked and verified" are different states, and only the
  second is a close. A park nobody could verify halts the run — it is the one state where you
  cannot tell whether work is finished or abandoned.
- **A dispatched worker does not spawn subagents.** Fan-out is the seat's and the runner's job;
  an unbounded tree is where a budget surprise comes from. See
  [`model-provisioning.md`](model-provisioning.md).
- **Every leg is explicitly provisioned** — never left to a default nobody chose — including the
  fix round and the second review pass, which are the call sites that get forgotten. Budget the
  FAIL path: a FAIL costs a fix leg *and* a second review leg at the same tier, and forecasts
  routinely miss by half for exactly this reason.
- **Never relay a leg's self-report as a measurement.** A returned leg's claim without its own
  gate transcript is unverified and gets re-measured by the runner. This is the cheap half of the
  between-leg belt; the rest is in
  [`live-resources.md`](live-resources.md) § A.5 and the orchestrator role doc.

### A.5 — The pause law: four stop events, and everything else parks and passes

**The binding statement is the orchestrator role doc's § The pause law.** The rationale, which is
what this sheet is for: a run that stops is a run that costs a human a context switch, and the
overwhelming majority of mid-run surprises do not need one. So the stop list is closed and short —
**exactly four events may stop a run**, and everything else is *parked and passed*:

1. An **unresolved fork about what to build**, on an issue that **cannot be parked**. If it can be
   parked, park it and go to the next issue.
2. A **destructive or irreversible action** needing authorization not already on record (see
   [`live-resources.md`](live-resources.md)).
3. **Fix rounds exhausted on the LAST remaining issue.** On any other issue: park with evidence
   and continue.
4. A **destructive-resource, credential or safety breach discovered in flight** — stop the *leg*,
   quarantine, record; the run continues unless the breach poisons the shared workspace.

**Park-and-pass, concretely:** park the item with evidence, add the question to the report's
batched decision list, and **dispatch the next leg**. Parking well is success.

**Corollary for an unattended run: do not ask a question nothing will answer.** The four events above
stop a run *for a human*. Where no human is reading — an overnight run, a scheduled one, a leg
dispatched without a watcher — an interactive question is not a pause, it is a **hang**, and the
batched decision list is the only channel that still works. So in an unattended run the list is not a
convenience for the human's morning; it is the sole exit, and a run that stops to ask has stopped for
good.

**A silent stop is a failure mode equal to improvising.** The old formula — *"parking well is
success; improvising is the only failure mode"* — was found incomplete: stopping without a park
note and a next dispatch is a third failure, and the most expensive, because the work is neither
done nor recorded nor handed on.

**Never end a turn on a stated intention.** "Resuming", "next I will", "now dispatching" are not
actions. A turn may end exactly three ways: **a dispatch actually in flight**, **the report
written and the pack stamped**, or **a named stop event with its batched decision list awaiting
the human**. If the words "resuming" appear, the same turn must contain the dispatch.

*The reason this is doctrine rather than advice:* it was written after a run paused twice on
things that were not stop events, and once wrote "resuming" in a turn that then ended.

**AMENDED — the rule above is right and its FORM was wrong: DISPATCH FIRST, NARRATE SECOND.**
Everything above stands, including its reason. What is added is the mechanism, because the
prohibition on its own does not hold: *"never end a turn on a stated intention"* asks the actor to
notice at the exact moment described by the sentence that names the failure — **"describing the
transition discharged the urge to make it."** The narration substitutes for the act, and the check
that would catch it is due precisely when the substitution has already happened.

So the rule is an **ordering**, not a prohibition: **when the next leg is determined, the dispatch
call PRECEDES the status.** The turn then ends on a tool call *by construction* rather than by
remembering to. The belt order becomes belt → **dispatch** → status, never belt → status → dispatch;
the gap between status and dispatch is where every measured instance lived.

*Why this is a mechanism rather than a firmer instruction* — the test is
[`fix-execution.md`](fix-execution.md) § A.5b, and this failure is caught by its **second** half
rather than its first. Nothing here is irreversible; a stalled turn is resumed at no cost. What earns
the mechanism is that the failure is **silent**: an idle session is indistinguishable from a working
one, so nothing surfaces
it but a human's glance or a liveness probe. The instances that produced this amendment were not
caused by carelessness — they were paid by coordinators who had the rule in front of them, more than
once each, including by the party that wrote the brief forbidding it. **Care was demonstrably not the
cure.**

*And note what the original wording already knew:* it said *"if the words 'resuming' appear, the same
turn must contain the dispatch."* That is this amendment, stated as a repair instead of as an order.
The repair asks you to catch yourself; the order removes the opportunity.

### A.6 — Decisions are batched between runs, never negotiated during them

Everything that needs a human or seat judgment and is not a stop event accumulates in the
report's **decision batch**: the question, its evidence, a **recommendation**, an owner, and
whether it blocks anything. The seat answers the batch **between** runs.

- **A decision request without a recommendation is unfinished work handed upward.** The runner
  saw the evidence; it owes an opinion.
- **The batch is where filed issues, subsumed issues, unfiled minors and riders go** — including
  the small ones. A rider (a bound whose *wording* is narrower than its *reason*; a sentence that
  is a universal over a set with one member that does not fit) is cheap to record and expensive
  to rediscover.
- **An issue can be closed as SUBSUMED** by a later change that falsified its premise, rather than
  scheduled behind it. That is retirement working as designed, not a shortcut
  ([`staleness.md`](staleness.md)).

### A.7 — Mid-run reports exist, and they are consult documents, not closes

When the seat must be consulted before a run finishes, the runner writes a **mid-run report**: the
standing table, the incident record, the open decisions, and an explicit banner saying **this is
not a close record** and naming the close deliverable that does not exist yet.

At close, the mid-run report is **superseded by the run report** and stamped as such, keeping its
original wording — it remains the record of *what the seat was consulted on*, and its incident
sections are carried forward **verbatim** into the final report rather than being re-summarized.
Re-summarizing an incident is how details are lost.

### A.8 — The cycle: mint → verify → pack → launch → run → report → stamp → batch

1. **Mint.** Issues are written with acceptance criteria by whoever owns scope, against a charter
   and a plan of record.
2. **Verify the mint.** The seat re-derives the load-bearing figures **from the tree** before the
   pack cites them — signatures, paths, counts, sizes. A stale baseline in a pack becomes a
   runner's false failure, and the most common mint defect is a number copied from an audit that
   the tree has since moved. Where the mint asserts something unverified, the pack labels it
   **the mint's finding to verify, not inherit.**
3. **Pack.** The seat authors the pack: order with reasons, per-issue rigor lines, standing facts,
   hazards, the report's name and its run-specific deliverables.
4. **Launch.** A fresh instance is started on the pack.
5. **Run.** Serial legs, the belt between them, park-and-pass, the report kept current.
6. **Report and stamp.** The report lands; the pack is stamped **SPENT against it by name in the
   same commit**; any mid-run document is stamped superseded; new documents are indexed.
7. **Batch.** The seat answers the decisions, verifies independently, and folds what was learned
   into the next mint — including into the **pack template itself** when a defect class was
   structural rather than incidental. A run whose lessons do not change the next pack was run for
   nothing.

### A.9 — The report grades the pack and the orchestrator too

An accountability rule with a real effect on quality: the report records **the pack's own
expectations that measurement overturned**, and **the orchestrator's own misses** — a leg's
reasoning let through unchallenged, a diff computed against a stale baseline, a pause taken on a
non-blocker. *A report that only grades others is worthless.* This is also the mechanism by which
doctrine earns its text: several rules in this kit exist because a named report recorded a named
miss, and a rule whose reason is a documented incident survives its author.

---

## § B — Project duties — filled by the adapter

> `<fill-in>` — the instance. Do not restate § A here.

1. **Who holds the seat**, and how a run is launched in this project (who starts the runner, with
   what prompt). `<fill-in>`
2. **Where packs and reports live** (the directory, the naming convention, and the index they must
   be registered in). `<fill-in>`
3. **This project's between-leg belt**, as exact commands. `<fill-in>`
4. **The provisioning ladder and the escalation mechanism** this harness actually has — see
   [`model-provisioning.md`](model-provisioning.md) § the project instance. `<fill-in>`
5. **The fix-round budget** (how many rounds before a park) and who may authorize an extra round.
   `<fill-in>`
6. **The verdict vocabulary** in this project's board and Activity-log dialect, including the
   land-ready verdict if the blocked-push regime applies
   ([`../GIT-HOSTING.md`](../GIT-HOSTING.md)). `<fill-in>`
7. **The worktree convention** for runs — one per runner, where, and which older ones are
   provenance that must not be touched. `<fill-in>`
