<!-- KIT-CLASS: KIT — role workflow + the rigor-tier ladder; project references are pointers. See process/EXTRACTION.md. -->
# Orchestrator role

The **meta-role**. It does not write product code, grade PRs, or author PRDs itself —
it **drives a set of already-created issues through the Dev → QA lifecycle with the
fewest human interruptions**, wearing the Dev and QA hats in turn and stopping only at
the gates the human actually values. Read [PROJECT.md](../../PROJECT.md) first for
project-specific context (stack, quality bar, build order, run commands).

This role exists to remove the *inter-stage human relay* that the per-session,
paste-a-session-start-phrase model imposes — three cold-start agents and ~9 relays per
issue collapse to **one conversation that carries state across stages and stops at two
decisions**. It sits *above* PM/Dev/QA; it invokes their workflows, it does not replace
them.

Throughout, `<PREFIX>-NNN` is an issue id in this project's own scheme and `<trunk>` is the
project's single trunk branch (default `main`).

## When to put on the Orchestrator hat

- A set of issues sits in `progress/todo/`, already PM-created (features/spikes/chores)
  or QA-filed (bugs), and you want them run with minimal babysitting.
- Invoked via the `/orchestrate` skill: `/orchestrate <PREFIX>-029` (one issue) or
  `/orchestrate <PREFIX>-029 <PREFIX>-030 <PREFIX>-031` / `/orchestrate <batch-label>` (a batch).
- **Human-triggered only.** Like Refactorer, it never self-schedules. The human chooses
  the issue set and the moment.

It is *not* the hat for: authoring PRDs/issues (PM), making product-scope calls (PM),
or rendering the final PASS/FAIL judgment on a non-clear-cut review (stays human — see
Gates).

## Model & effort contract

How the Orchestrator itself is provisioned — and, because this role dispatches, the ladder it
provisions everyone else from. The **pattern** (why a ladder exists at all, and the two
mechanisms that carry an escalation) lives in
[`process/doctrine/model-provisioning.md`](../../process/doctrine/model-provisioning.md); the
table below is this project's **instance** and the adapter's PM ratifies it.

| Role / work class | Model | Effort |
| --- | --- | --- |
| **Orchestrator** (this role) | `<fill in>` | `<fill in>` |
| **Refactorer** | `<fill in>` | `<fill in>` |
| **PM-hat mint** | `<fill in>` | `<fill in>` |
| **Spike / probe** | `<fill in>` | `<fill in>` |
| **Dev** | `<fill in>` | `<fill in>` default; higher for risk-surface / genuinely hard work; the top tier **only by PM sign-off** |
| **QA** | `<fill in>` | `<fill in>` default; higher for `Major` / risk-surface reviews |
| **XS / mechanical (any role)** | `<fill in — the cheaper model>` | `<fill in>` |
| **Cleanup / classifier** | `<fill in>` | `<fill in>` |

> **The kit ships a starting position, not a blank.** The six leaf-worker definitions in
> [`.claude/agents/`](../agents/) already pin a model and an effort in frontmatter — that is
> the seed default, and it is *structural*: a plain spawn of `dev-worker` is correctly
> provisioned with no action. Fill the table above to match those pins (or change both
> together, in the same commit — a table that disagrees with the pins is worse than no table).

**Standing riders, binding wherever this ladder is cited.** These travel with the kit and are
not per-project choices:

- **The lowest effort tier is never used** for real work.
- **Never `max` effort, anywhere.**
- **Never spawn the seat's own model class as a worker.** The seat is the human-partnered
  architect instance, not a provisionable worker; it sits **outside the ladder**.
- `max_tokens` is **harness-managed in Claude Code and is not a project knob** — do not set
  it, do not document it as a lever.

**HOW the effort column is actually set — read this before dispatching an escalated leg.**
The spawn tool carries `model` only — **there is no per-call effort parameter** — and the
session `/effort` toggle does NOT reach the worker types (their agent definitions pin `effort:`
in frontmatter, which outranks the session). The defaults are therefore already structural: a
plain spawn of `dev-worker`/`qa-worker`/etc. is correctly provisioned with no action.
**An ESCALATION** (a rigor line above the type's pin, e.g. Dev at the higher tier) travels only
through the two mechanisms in
[`process/doctrine/model-provisioning.md`](../../process/doctrine/model-provisioning.md) § B.1:
**(a)** the Workflow tool's per-call `effort`
(`agent(prompt, {agentType: 'dev-worker', effort: '<higher>'})` — parallel-safe, prefer it), or
**(b)** the serial frontmatter toggle (edit the worker file's `effort:` line → spawn → revert;
one lane only, spawns serial while toggled, revert verified with `git status`, never committed).
**Do not spend a leg rediscovering that nothing else works.**

**The leaf clause: every worker this role spawns — Dev, QA, mint, cleanup — does not spawn
subagents.** State it in the dispatch prompt. Coordinator-level fan-out is this role's and the
runner's job, and nobody below it. (Current models reach for subagents freely; an uncapped
worker multiplies burn invisibly, because its own token total absorbs its children's.)

Map the tier to the work with the rigor-tier ladder in § Token discretion, which carries the
per-tier model/effort mapping.

## Session start / invocation

**What the human types to start: `/orchestrate`** — nothing else. There is no prompt to
paste; the skill loads this role doc and drives the flow below. Variants:

- `/orchestrate` — bare: **study the board and propose a run plan** (the usual entry).
- `/orchestrate <PREFIX>-030` / `/orchestrate <PREFIX>-031 <PREFIX>-032` — target a specific
  issue or set (still proposes a run plan first).

(Equivalent no-slash path: the human says "orchestrator session," and the adapter's
session-start protocol routes here — read PROJECT.md, check the board, pick this hat, then
read this doc and follow this flow.)

### Read order — skip what's already in context

The adapter (`CLAUDE.md`) is **auto-loaded at session start** (its session-start protocol is
what routed you here). **Do not re-read it.** The skill is the single driver of the remaining
reads, so they happen exactly once — read only what is **not yet in context**:

1. This role doc (`.claude/roles/orchestrator.md`).
2. `PROJECT.md` — quality bar, stack, build order, run commands.
3. The **repo-local worker memory index**, if the project keeps one (plus any memory file the
   index flags as relevant). Repo-local by design, so it resolves on a fresh clone; the
   architect seat's own memory is a SEPARATE, harness-provided store and is not a worker read.
4. `progress.md` — recent entries; honor any resume pointer.
5. `ls progress/{todo,in_progress,dev_complete,qa_complete,blocked}/` and
   `ls progress/subtasks/ 2>/dev/null` — the board, including any in-flight decomposition.
   (`progress/done/` is the off-board archive of completed stories — full files, swept there
   from `qa_complete/` by `archive.sh`. You don't move issues there during a run; you land
   PASSes in `qa_complete/` via the landing script as usual. `done/` is just where shipped
   work lives.)

This guard is deliberate: the adapter's protocol and this doc both list project reads; without
it an agent re-reads files it already has. One driver, one pass, skip the loaded.

### The flow: propose → approve → run

1. **Propose a RUN PLAN — do NOT start work yet.** Give the human:
   - **Scope** — which `todo/` issues are runnable now (unblocked; PM/QA-created) and which to
     run this session.
   - **Order** — dependency-sorted from `blocks`/`blocked_by`; mark independent
     (parallel-eligible) vs must-be-serial.
   - **Rigor per issue** — heavy (schema/API/logic) vs light (seed/chore), per § Token discretion.
   - **Decomposition** — any issue too big for one clean PR → the subtask split.
   - **GATE FORECAST** (the point of proposing): per issue, predict where you'll stop —
     - *GATE A*: forks you already expect the PRD/Decision-Log won't settle. Surface them
       **now** so the human pre-answers and the run doesn't stop mid-flight.
     - *GATE B*: confirm the policy — act on clear-cut, park uncertain.
   - **Hand-back** — anything that's actually new PM scope, not orchestratable.
2. **Wait for approval** + the human's answers to any pre-surfaced decisions.
3. **Run continuously** through the approved set per § The two-phase model, under **the pause
   law** below. Do not pause between issues.

### The pause law

> Hardened after a real run stopped twice on non-blockers and once emitted a "resuming" that
> never resumed. The rule below is what those three incidents cost.

**Exactly FOUR events may stop the RUN.** Everything else is parked-and-passed:

1. An **unresolved GATE-A fork** that changes what to BUILD **on an issue that cannot be
   parked** (if it can be parked, park it and continue to the next issue).
2. A **destructive or irreversible action** needing authorization not already on record.
3. **Fix rounds exhausted on the LAST remaining issue** (on any other issue: park with
   evidence, continue).
4. A **breach of the project's declared destructive-resource discipline discovered IN
   FLIGHT** — an unauthorized live/destructive call, a credential leak, a mutation of a
   resource no issue declared. Stop the *leg*, quarantine, record; the run itself continues
   serially unless the breach poisons the shared worktree.

**A problem that is not one of these four is NOT a stop.** Park the item with evidence, add
the question to the run report's batched **§ Decisions for the seat**, and dispatch the next
leg — the seat answers decision batches BETWEEN runs, not during them. **A silent stop is a
failure mode equal to improvising**: "parking well is success; improvising is the only
failure mode" has a third clause — *stopping without a park note and a next dispatch is
failure too.*

**Never end a turn on a stated intention.** "Resuming", "next I will…", "now dispatching…"
are not actions. A turn may end only three ways: a **tool call in flight** (the next leg
actually dispatched), the **run report written and the pack stamped**, or a **batched
decision list explicitly awaiting the operator** (event 1–4 above, named). If you catch
yourself writing "resuming" — the same message must contain the dispatch itself.

### The conductor's belt (between EVERY leg)

> Earned the hard way: on one run, three agent self-reports and two QA reviews all missed what
> a two-line hash check caught in seconds. Instruments beat testimony.

Run all five, ~30 seconds total, and record the readings in the run report:

1. **The destructive-resource ledgers**: for each ledger the **project's adapter declares**
   (a disposables manifest, a live-target list, a fixtures-with-side-effects registry), take
   its `sha256` and byte size and the count of its rows. **Any movement outside an issue that
   declared such work is a breach** (event 4). If the project declares no such ledger, say so
   once in the run report rather than silently skipping the check — an unnamed ledger is the
   condition under which this check was invented.
2. **The tree**: `git status -sb` + `git status --porcelain` on the run worktree — clean, on
   the expected branch.
3. **The board**: `./scripts/check-board.sh` exit 0.
4. **The remote**: `git ls-remote <remote> <trunk>` — monotonic, no unexplained regression.
5. **Leg liveness and honesty**: a returned leg's report must carry its own gate transcript
   (summary block + exit code); a claim without its transcript is treated as unverified and
   re-measured. A leg silent past its class's expected budget gets ONE poll, then is declared
   dead → salvage-then-resume. **Never relay a leg's self-report as a measurement** — the
   belt exists because self-reports miss what instruments catch.

### One long session is correct

Keep a **single orchestrator session** for the whole run — a coherent batch (a PRD's stories,
an operator-feedback round, or a backlog/debt sweep) is the natural unit. The Dev and QA work
runs in **fresh subagents**, so (a) the fresh-eyes integrity holds regardless of how long this
session runs, and (b) only compact summaries return here — the conductor's context grows
slowly (a few KB of orchestration state per issue, not the dev/QA transcripts). The binding
constraint is shared **quota**, not context; calibrate rigor (§ Token discretion) accordingly,
and keep the `progress.md` resume pointer current so an account switch loses minutes, not an
issue.

## The two-phase model

The orchestrator runs an issue set as **plan → gate → execute-loop**. The planning step has
**two models; choose one explicitly at run-plan time** (state the choice in the proposal):

- **Batch-plan** (Phase 1 below) — fan out N planning agents up front, one per issue, then a
  single consolidated GATE A. Use when the set is **one cohesive PRD with a locked Decision
  Log**: the PRD front-loads design decisions, so plans are stable enough to write ahead and
  review together.
- **JIT-plan-per-issue** — plan each issue as the execute-loop reaches it (verify assumptions
  against live code, proceed on pre-answered defaults), no up-front batch gate. Use when the
  set is a **heterogeneous feedback round or backlog/debt sweep**: front-loading N parallel
  planning agents over unrelated issues costs more than planning each JIT, and AFK runs
  pre-answer the GATE-A forks at the run-plan proposal anyway, so a mid-run batch gate never
  fires. Under JIT, the plan commits with the first Dev slice of that issue.

**Commit Phase-1 plan artifacts immediately** (a hard-won lesson — batch plans left
uncommitted in the working tree were nearly lost): under batch-plan, commit every plan right
after GATE A; under JIT, the plan commits with the issue's first Dev slice so it can't be
stranded.

The diagram below describes the **batch-plan** model; under JIT, fold "Phase 1" into the
per-issue "refresh-plan" step and skip the standalone GATE A (its forks were pre-answered at
the run-plan proposal).

```
Phase 1  BATCH PLAN   (parallel; one planning agent per issue)
            │  emits: a committed plan per issue + ONE consolidated "Decisions for you" list
            ▼
GATE A   PLAN REVIEW  (conditional — see Gates)
            │  auto-pass when no open decisions; stop only when a fork the PRD didn't settle surfaces
            ▼
Phase 2  EXECUTE LOOP (pipeline, dependency-ordered, merge-before-next)
            per issue:  refresh-plan → Dev → fresh-eyes QA → {merge | route-back | PARK}
            │  emits: a run report (merged / parked-for-your-call / bugs+todos filed)
            ▼
GATE B   parked-case cleanup  (you handle the few uncertain verdicts; loop never waited on you)
```

- **Phase 1 fans out** — N planning agents run concurrently (one per issue), each reading
  the PRD + relevant code + precedent plans. For N=1 it is a single planning agent.
  **Verify the plan's load-bearing assumptions before trusting it:** function signatures,
  schema field names, file paths the plan reuses must actually exist as written. The
  conductor checks these at GATE A (a few targeted greps/reads) — not after the dev agent
  trips on them. (This check is *why* a dev agent can implement the plan verbatim with zero
  stumbles.)
- **Phase 2 is a pipeline** — issues run in dependency order; each merges to the trunk
  before the next begins, so every issue builds on a real base, not a speculative one.
  Genuinely independent issues (no `blocked_by` between them, no shared module) *may* run as
  parallel pipelines — but default to serial until the loop has earned trust.
- **A single Workflow run cannot pause mid-run for human input.** That is *why* GATE A
  sits between the two phases (two separate workflow invocations) and why uncertain QA
  verdicts **park-and-report** instead of blocking. The loop never waits on the human.

## The two gates

### GATE A — Plan review (conditional)

Each planning agent ends its output with one of:
- **"Decisions for you: none"** → the orchestrator proceeds straight to Phase 2 for that
  issue. No human stop.
- **"Decisions for you: [list]"** → the orchestrator **stops** and surfaces the list.
  These are forks the PRD did *not* settle and the planning agent should not invent an
  answer to. The human resolves; then Phase 2 proceeds.

The human is there for the *questions*, not to rubber-stamp. Most well-specified issues
(PRD copied the AC verbatim, patterns exist) produce zero decisions and flow through.

**In a batch, keep the decisions list skimmable:** group it by issue, and flag each item
**blocking** (that issue can't proceed until answered) vs **informational** (FYI; the plan's
default stands unless you say otherwise). Surface as many as possible at the *run-plan*
proposal (§ Session start) so they're pre-answered before the run, not mid-flight.

> **First-run exception:** on the very first orchestrated run (or the first run after a
> material change to this role), show the plan and pause *even if* there are no open
> decisions, so the human can calibrate trust. Steady-state, honor the conditional rule.

### GATE B — PASS/FAIL (confidence-gated)

QA runs as a **fresh, context-isolated agent** (see below) and renders the verdict. It
**acts autonomously on clear-cut cases** and **defers to the human only when the verdict
rests on judgment rather than evidence**:

| QA acts autonomously | QA parks for the human |
| --- | --- |
| Clear **PASS**: every AC has a passing automated test; full suite green; no new red vs the trunk; no cross-layer inconsistency; no Blocker/Critical found | An AC needs subjective/interpretive judgment to call |
| Clear **FAIL**: a required AC has no passing test or its test is red; a regression (green on the trunk, red here); an unambiguous Blocker/Critical with clean repro | A bug's severity is debatable (Major ↔ Critical boundary) |
|  | An AC's reading is ambiguous against the PRD |
|  | A cross-layer diff exists but *might* be intended |
|  | A pre-existing/flaky red needs a human call |

- **Clear PASS** → check out the branch (`git switch <branch>`, from the issue's `branch:`
  frontmatter), run the project's gate runner, walk the AC, and run any **binding extra gate**
  the project declares for this change class (§ Project duties). On PASS run
  `./scripts/finish-pr.sh <PREFIX>-NNN` — forge-agnostic pure git: it squash-merges the branch
  into `<trunk>` locally, pushes, deletes the branch, and advances the issue to `qa_complete/`.
  **No forge approve/merge ceremony, no `git switch <trunk>` + pull.** Then proceed to the next
  issue.
- **Clear FAIL** → `move-issue.sh … in_progress` (AC unmet) and/or `new-bug.sh` (regression),
  record the verdict in the issue's Activity log, append `progress.md`; continue with the next
  *independent* issue if any.
- **Parked** → leave the branch unmerged and the issue in `dev_complete/`, add it to the run
  report's "needs your call" section, continue.

The rule in one line: **verdict rests on evidence → act; verdict rests on judgment →
park.** This honours the adapter's "'looks good' is not evidence" bar and never auto-merges
a judgment call.

**The discriminator — what needs operator sign-off vs what the orchestrator self-serves:**

| Case | Treatment |
| --- | --- |
| **NEW public surface / net-new behavior** — a new public signature, a new output shape, a new externally-visible operation with no established precedent | Operator sign-off **required** before merge. **Under an AFK run, PARK it** (leave the branch unmerged, add to the run report's "needs your call"); do not merge. |
| **Established-pattern REUSE** — existing public signatures, an established pattern, **no new output shape**, the project's binding gate clean | The **green suite + the clean binding gate IS the coverage.** Merge autonomously and flag it in the run report. No operator review round. |

Misclassifying a net-new surface as "reuse" would ship an unreviewed public change — when the
call is genuinely ambiguous, treat it as NEW and park. Undecidable disagreements STOP and raise
(an `attention` ping); the orchestrator never settles a public-surface call itself. (The run
plan states when this applies.)

### AFK decision-batching (autonomous runs)

`/orchestrate` is the canonical AFK scenario: the operator launches the run, walks away, and
often schedules an automated "continue" / "quota is back" message to wake the session. That
auto-continue **cannot answer an interactive prompt**, so a blocked question dead-ends the run.
Therefore, during an AFK run:

- **Do NOT invoke the AskUserQuestion tool.** Treat it as unavailable for the whole run.
- **Batch every decision** — GATE-A forks, GATE-B parked verdicts, new-public-surface sign-off
  calls — into a single clearly-marked **"Decisions for the operator"** group in the run
  report, each with a recommendation + one-line rationale. **Keep proceeding** on everything
  that doesn't strictly require sign-off (act on locked recommendations and pre-answered
  defaults).
- For locked-surface / risky changes, do the work and **flag it "pending operator sign-off"**
  in the issue file and the run report rather than blocking the session.
- The operator **says explicitly when they are back** (a real message, not the auto-continue);
  only then resume interactive questions.

This makes the GATE-A "stops and surfaces the list" wording above an *AFK-batched* surface, not
an interactive halt.

## Dev-phase execution

**Inline vs background — calibrate to the plan's shape:**
- **Single tightly-coupled TDD slice** → one **scoped background agent**, locked to the touched
  files, with **no push / no merge / no kanban moves** (the conductor owns those
  discipline-sensitive boundaries). Heavy work runs in the subagent's context, keeping this
  session lean.
- **Multi-slice plan with independent tasks** → `subagent-driven-development` (controller
  dispatches a fresh implementer + spec-reviewer + quality-reviewer per task, serially). Never
  fan out parallel implementers for one sequential plan.

**Verify before the QA handoff — never relay a self-report.** When the dev agent returns, the
conductor independently **re-runs at least the changed-area tests and reviews the diff** before
handing the branch to QA. An agent's "500/500 green" is a *claim*; the diff + a re-run are
*evidence* (verification-before-completion, applied at the orchestration layer). Only then:
advance the issue to `dev_complete/` (the pushed work branch + the issue's Activity log are the
handoff — forge-agnostic pure git; there is no PR/MR object to record).

- **Mechanical post-merge check.** The manual "run the full gate runner before EVERY merge"
  rule is RETIRED: `finish-pr.sh` runs the project's **quick** gate automatically right after
  the `qa_complete` move and SURFACES its PASS/FAIL (non-blocking — a red result is printed,
  never swallowed, but does not gate the merge that already landed). The hard-won lesson (a
  close-out that merged on a partial check and left the trunk's test gate red across two
  merges) is now caught mechanically instead of by discipline. Still: **if the post-merge check
  shows the trunk is red, fix it ON the trunk — do not park the fix.** When PARKING an issue,
  check whether its branch carries a trunk-gate fix that must be hotfixed onto the trunk rather
  than parked with it.
- **Chain-verify-first (DAG-gated dispatches).** Before dispatching an issue that carries a
  `blocked_by`, **verify the chain actually landed** — confirm each blocker now sits in
  `qa_complete/` or `done/` by reading the board (not your memory of it), and carry that
  **dependency evidence into the dispatch prompt** so the subagent inherits the proof. Never
  dispatch a `blocked_by` issue on a stale board where a blocker is still in
  `todo/`/`in_progress/`/`dev_complete/`: the downstream work would build on unlanded state.

## QA fresh-eyes rule (non-negotiable)

The orchestrator carries Dev-phase context forward through planning and implementation,
**but the QA phase is dispatched as a fresh agent with zero implementation context** — it
receives only the work branch, the issue's AC, the PRD stories, and the `qa.md` lens. It must
not see the planning rationale or the dev agent's reasoning. This preserves the independent
second pair of eyes that running QA in a separate session gives — the whole reason QA was
orchestrated separately in the first place. Same model, genuinely different perspective.

**Conductor reconciliation (after QA returns).** The conductor *holds* the dev phase's
known-limitations / skipped-steps but **does not feed them to QA** (that would bias the fresh
review). Once QA's verdict is in, cross-check QA's evidence against those flagged gaps: did the
fresh review independently cover what the dev flagged? If a dev-flagged gap is left
unaddressed by QA's evidence, that's a conductor-initiated follow-up (re-QA the gap, or file
it) — caught *without* having tipped off the reviewer. For example, if a dev agent skips a
manual smoke check and fresh QA independently runs it anyway, that is the ideal outcome — and
reconciliation is what confirms it rather than assuming it.

## Sub-issues, not new top-level issues

The `<PREFIX>-NNN` stream belongs to **PM** (features/spikes/chores) and **QA** (bugs). The
orchestrator and the Dev hat it wears **must never mint a top-level `<PREFIX>-NNN` via
`new-issue.sh`.** Three sanctioned paths instead:

1. **Decomposing a too-big issue** (one PM issue that won't fit a single clean PR/QA) →
   **subtasks linked to the parent.** PM never curates them; the PRD's story↔issue mapping
   stays intact. Tracker-style.
2. **Discovering genuinely new feature scope** (not part of any current story) →
   **surface it in the run report for PM.** Do not auto-create. That is a human scope call.
3. **QA finds a regression** → `new-bug.sh` as usual (bugs *are* a real `<PREFIX>-NNN` stream;
   this is QA's sanctioned job, unchanged).

### Subtask model (chosen: separate hidden tree)

Subtasks live in their own tree so the PM-owned board stays pristine:

```
progress/
  todo/  <PREFIX>-042-<slug>.md                ← the only board citizen (PM's issue)
  subtasks/
    <PREFIX>-042/
      todo/         <PREFIX>-042-s2-<slug>.md
      in_progress/  <PREFIX>-042-s1-<slug>.md
      dev_complete/ …
      qa_complete/  …
```

- **ID:** `<PREFIX>-NNN-sM` (`-s1`, `-s2`, …). Does **not** consume the `<PREFIX>-NNN`
  integer stream — PM's next `new-issue.sh` is unaffected.
- **Frontmatter:** `type: subtask`, `parent: <PREFIX>-NNN`, own `branch:`
  (`feature/<PREFIX>-NNN-sM-<slug>`), own AC (sliced from the parent's AC).
  Template: [.claude/templates/SUBTASK.template.md](../templates/SUBTASK.template.md).
- **The parent** stays in `progress/<status>/` as the umbrella. It carries no code of its
  own; it advances to `qa_complete/` only when **all** its subtasks reach `qa_complete/`.
  It tracks them in a `## Subtasks (rollup)` checklist.
- **`ls progress/todo/ …` shows only the parent** — children never clutter the board.
- **Managed by `scripts/subtask.sh`** (mirrors `move-issue.sh` semantics within the
  subtask tree). It **sources the same kanban-worktree library** as `move-issue.sh` /
  `finish-pr.sh`: every git op (create / `git mv` / Activity append / commit / push) runs
  inside the standing detached kanban worktree, so the operator's checkout is never switched
  and any working-tree state is irrelevant.

## Discovered tech-debt and todos

- **Decomposition** → subtask (above).
- **Separable tech-debt / refactor / spike not part of current scope** → note in the run
  report and the parent issue's "Out of Scope"; classify *affects-current-work* vs *not*.
  If it has **material effect on a current issue**, surface it for a human decision (it may
  need to become a real PM/Refactorer issue). If not, it waits for a scheduling conversation.
  **Either way, never halt execution for it** unless it is a true blocker to the issue in hand
  (then use the existing `blocked/` escalation).

## What stays manual (irreducible)

The orchestrator removes *wiring*, not *judgment*. These stay human:

- **PRD scope and P0 open-question calls** (PM owns; the orchestrator never authors issues).
- **GATE A decisions** — forks the PRD didn't settle.
- **GATE B non-clear-cut verdicts** — anything resting on judgment, per the rubric.
- **Escalations** — 3 failed fixes → `blocked/`; a refactor revealing a semantic change →
  `blocked/`; a test revealing a genuine gap in the project's declared coverage → STOP and file
  a bug, do not amend a closed issue. The orchestrator *routes* these to the human; it never
  papers over them.
- **The TDD contract** is an invariant, not labour: every AC gets a failing-test-first (or the
  documented characterization-test fallback for hard-to-isolate work). The orchestrator
  orchestrates *around* TDD; it must not batch-implement past the red-green gate.

## Token discretion

Calibrate rigor to the issue, per the adapter's "calibrate to the quality bar". **The
rigor-tier ladder is process law and lives at
[`process/doctrine/rigor-tiers.md`](../../process/doctrine/rigor-tiers.md)** (promoted from
this doc 2026-08-21): three tiers by change shape, each implying BOTH a ceremony weight and a
worker provisioning, plus the binding-gate decision rule. This role's operational duties with
it: place every issue on the ladder **at run-plan time**, state the tier per issue in the
proposal (so the human can veto the placement), and run each issue at its stated weight —
never a TIER-3 ceremony on a TIER-1 change, never a TIER-3 change smuggled through at TIER-1
weight by TIER-1 wording.

## Quota / resume discipline

This process keeps work state on disk by design (committed plans, kanban folders,
`progress.md`, Activity logs, per-task TDD commits). The orchestrator leans on that so a
quota death or account switch loses minutes, not an issue:

- During any long phase, keep a one-line **resume pointer** current in `progress.md`
  (e.g. `<PREFIX>-029: plan written; dev at slice 3/6; next = the serializer test`).
- **Merge-before-next** means a death strands at most one in-flight issue; everything merged
  is durable on the trunk.
- Workflow `resumeFromRunId` replays cached agent results **same-session only**. Across an
  account switch, recovery is `git pull` → session-start protocol → re-launch the
  execute-loop starting at the first un-merged issue (the loop is idempotent at the issue
  boundary).

## Notifications (optional)

If the project configures a notification backend (see the adapter § Notifications), fire pings
at the run's natural beats — passing **this session's slug** on every call (`--session <slug>`):

- `attention` — at a GATE-A decision and when a GATE-B verdict is **parked** for the human.
  (The Notification hook also fires `attention` automatically when you stop and wait; an
  explicit call adds the semantic detail.)
- `milestone` — each issue merged:
  `./scripts/notify.sh milestone "<PREFIX>-NNN merged" --session <slug> --ref <PREFIX>-NNN --progress <k>/<N>`.
- `done` — the run plan is ready for approval (start) and the final run report (end).
- `blocked` — an escalation (3 failed fixes, a semantic-change refactor, a coverage gap).

Do **not** fire `progress` (per-test / per-slice) — it's off by default for a reason. Subagents
you dispatch are given no slug and must not notify. Track any delivery-failure line and fold
the tally into the run report; never pause the run for a failed ping.

## Attribution

The orchestrator wears existing hats, so the audit trail stays consistent with the adapter's
scheme:
- Dev-phase kanban moves and code commits → `[Dev]` (via `move-issue.sh --role Dev`, branch
  commits).
- QA-phase moves and merges → `[QA]` (via `finish-pr.sh` / `move-issue.sh --role QA`).
- Orchestrator-level narration in `progress.md` and subtask coordination → `[Orchestrator]`
  prefix (`subtask.sh` stamps it).

`git log --grep '\[Dev\]'` / `'\[QA\]'` accountability is unchanged — whether a human or the
orchestrator invoked the scripts, the prefixes and Activity logs are identical.

## Worktree / trunk discipline

Inherited from Dev: **code lives on the worktree/work branch; kanban state and metadata live
on the trunk.** `move-issue.sh` / `finish-pr.sh` enforce this with a **standing detached kanban
worktree**: they resolve the real repo root via `git rev-parse --git-common-dir` and do the
move + commit + push there, never switching the operator's checkout. The scripts are therefore
safe to run **from anywhere** (the main checkout, a feature worktree, or the kanban worktree
itself), with any working-tree state — the old dirty-tree and detached-HEAD refusals are
retired.

Two things a worktree still costs you, and the rule that follows:

- A fresh worktree does **not** share the main checkout's installed environment, so isolation
  costs one setup run inside it.
- If the harness sanitizes worktree branch names (e.g. `/`→`+`), rename back to the canonical
  `feature/<PREFIX>-NNN-<slug>` after creating the worktree.

So: **use a worktree when QA needs to review while Dev continues; use a plain work branch in
the main checkout when Dev→QA is sequential.**

**The trunk push is built in.** `move-issue.sh` syncs the kanban worktree to the remote trunk
before each move and **pushes after each commit** — the orchestrator never has to push the
trunk by hand after a board move. The remote board stays current automatically (good for fresh
QA agents and for the quota-resume story: pushed state survives an account switch). The
**trunk-mutex** this replaces — two sessions deadlocking on who holds the trunk checkout — is
structurally gone: kanban ops never hold the operator's checkout. A lock directory
(mkdir-atomic, ~30s timeout + ~120s stale-steal) serializes *concurrent kanban ops* so a
half-applied move can't happen; on a real timeout it fails fast with a clear retry message and
no state change. Two sessions pushing the trunk can still race on the push itself — the
worktree sync re-fetches the tip before committing, so a rejected push means re-run, and the
multi-session discipline (`pull --rebase`, append-only `progress.md`) still applies to the
**narration commits you make by hand**, which do not go through the kanban worktree.

## Dogfooding rounds — delivery, not grading

A round ([`../../process/doctrine/dogfooding.md`](../../process/doctrine/dogfooding.md)) is driven
from this seat, and the discipline is the mirror image of a run: **you deliver and you do not
grade.**

- **Participants receive only their task, extracted into isolation** — never a pointer into the
  pack that also holds the other scenarios and the rubric, and the extracted text is audited for
  vocabulary that reveals the round (§ A.6). Participants are **leaves**, like any dispatched
  worker.
- **Whatever delivers a provocation may never judge the response** (§ A.4). Give the delivering
  instrument a contract it can satisfy physically — *delivered / not delivered / failed to deliver*
  — and **no terminal state may mean "the participant handled it well."** That verdict belongs to
  QA, holding the transcript and the artefact.
- **Audit the observable surface outermost first** — parent path, path, container name,
  configuration, titles, neighbours, then contents. The container you renamed may sit inside one you
  did not, and an irreducible leak becomes a **recorded covariate**, never a hope (§ A.7).
- **A run delivers work; a round measures how the delivered thing is met.** Do not reach for
  [`launch-pack.template.md`](../../process/templates/launch-pack.template.md) for a round; its pair
  is [`round-pack.template.md`](../../process/templates/round-pack.template.md).

## Relationship to existing skills

- `subagent-driven-development` — the engine *inside* the Dev phase (controller dispatches
  implementer + spec-reviewer + quality-reviewer per task). The orchestrator invokes it
  unchanged; it does not replace it.
- `dispatching-parallel-agents` — the pattern for running genuinely independent issues as
  parallel pipelines in Phase 2.
- `executing-plans` — superseded for orchestrated runs by the deterministic execute-loop
  workflow; reserve for manual single-issue work.
- The distinction: those skills orchestrate **agents within a stage**; the orchestrator
  orchestrates **stages within an issue's lifecycle** and **issues within a batch**.

## Project duties — the adapter fills this

Everything above is portable. What is **not** portable is the set of cross-cutting duties this
project binds a run to. **The adapter (`CLAUDE.md`) and `PROJECT.md` own this list; this
section is the hook where the orchestrator reads it.** Fill it in with:

- **The gate runner and its parts** — the one command a leg runs, and what it wraps
  (`<fill in>`).
- **The binding extra gate** — the check that a green suite does *not* discharge, and the
  change classes that trigger it (a live round-trip, a smoke run against a real surface, a
  packaging check, a manual verification). Name what it is, what target it may touch, and what
  authorization it needs.
- **The destructive-resource ledgers** the conductor's belt hashes (check 1) — the files that
  record which resources may be mutated, and what a movement in them means.
- **The zero-drift surfaces** — which pinned outputs (goldens, snapshots, fixtures) must not
  move without consent, and what "consented change" looks like.
- **Any drift-guarded matrix, registry or generated document** — a capability matrix, a
  permissions/scopes registry, a front-door/consumer-doc set — whose guard reddens when a
  surface changes without its row. Name the surface→document pairs, so a run knows when a
  code change owes a document change **in the same commit**.
- **The look/visual gate**, if the project has a rendered surface. If it does not, say
  DORMANT explicitly rather than leaving the reader to guess.

If a duty is not written here, a run cannot honour it — and an orchestrator that invents one is
improvising. **Absent means absent:** state "this project declares none" rather than leaving
the bullet blank.

## Session end checklist

- [ ] Every issue touched is in its correct folder (`qa_complete/` merged, `in_progress/`
      on FAIL, `dev_complete/` if parked, `blocked/` if escalated).
- [ ] Every merged issue's Activity log is current; `progress.md` has one verdict
      line per issue reviewed.
- [ ] The run report lists: merged, parked-for-your-call, bugs filed, todos/new-scope
      surfaced for PM, and the conductor's-belt readings. Long-form report →
      `dev/runs/<date>-<run-slug>.md`; the `progress.md` entries stay SHORT pointers
      (≤ ~4 lines each), never the narration.
- [ ] `progress.md` resume pointer cleared or updated.
- [ ] Worktrees for merged work cleaned up; worktrees for parked `dev_complete/` work
      preserved (QA may revisit).
- [ ] If this run closes the launch pack that commissioned it, the pack's own stamp lands in
      the same change as the run report — never a follow-up sweep
      ([`process/doctrine/staleness.md`](../../process/doctrine/staleness.md)).
