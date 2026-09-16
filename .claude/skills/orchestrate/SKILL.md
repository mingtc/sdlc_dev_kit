---
name: orchestrate
description: Use when the user invokes /orchestrate — bare, or with issue IDs or a batch label — to drive already-created issues through the Dev → QA lifecycle hands-off, stopping only at the two gates (plan decisions, non-clear-cut PASS/FAIL). Implements the Orchestrator role in .claude/roles/orchestrator.md.
---

<!-- KIT-CLASS: KIT — the procedure that runs the Orchestrator role. Policy lives in the role doc. -->

# Orchestrate

The repeatable entry point for the **Orchestrator role**. Read
[.claude/roles/orchestrator.md](../../roles/orchestrator.md) in full first — it is the
policy/constitution; this skill is the procedure that runs it. Do not restate the policy
here; defer to the role doc for the pause law, the conductor's belt, the gates, the QA
fresh-eyes rule, the sub-issue rule, the confidence rubric, and what stays manual.

Throughout, `<PREFIX>-NNN` is an issue id in this project's own scheme (the initializer stamps
the real prefix into the board scripts and templates) and `<trunk>` is the project's single
trunk branch, default `main`.

## Invocation

```
/orchestrate                          # bare: study the board, propose a run plan, wait for approval
/orchestrate <PREFIX>-029
/orchestrate <PREFIX>-031 <PREFIX>-032
/orchestrate <batch-label>            # resolve the set from progress/todo/ for that PRD or batch
```

## Procedure

### 0. Setup + propose the RUN PLAN (then wait)

1. **Read order — skip what's already in context.** The adapter (`CLAUDE.md`) is auto-loaded
   at session start; do **not** re-read it. Read only what isn't loaded yet:
   `.claude/roles/orchestrator.md`, `PROJECT.md`, the repo-local worker memory index if the
   project keeps one, `progress.md` (recent entries), then
   `ls progress/{todo,in_progress,dev_complete,qa_complete,blocked}/` and
   `ls progress/subtasks/ 2>/dev/null`. **That is the RUNNABLE board and omits the two terminal
   columns on purpose** — `done/` (shipped) and `declined/` (considered and refused, with the
   reason); neither holds work you can pick up, and declining is PM's call, not yours.
2. Resolve the **issue set**: bare `/orchestrate` → study the board and pick the runnable set
   yourself; with args → that set. Each must already exist in `progress/todo/` (PM-created
   feature/spike/chore, or QA-filed bug) and be unblocked (`blocked_by` all landed).
   **Never create top-level issue ids** — that stream belongs to PM and QA. Drop or flag
   anything not ready.
3. Read each issue file plus its PRD stories; build the **dependency order** from
   `blocks`/`blocked_by`; mark mutually-independent issues as parallel candidates (default
   serial).
4. **Propose a RUN PLAN and STOP for sign-off** (role doc § Session start): scope, order,
   per-issue rigor tier, decomposition, and a **GATE FORECAST** — the GATE-A decisions you
   already expect, surfaced *now* so the operator pre-answers them, plus the GATE-B policy
   confirmed. Flag any item that is really new PM scope. Do not enter Phase 1 until the
   operator signs off and answers the pre-surfaced decisions.

> **Notifications (optional):** if the project configures a notification backend, pick this
> session's slug, send a test ping, and fire `attention` / `milestone [k/N]` / `done` /
> `blocked` pings through the run per role doc § Notifications. Subagents never notify; track
> any delivery failure and report it at the end.

### 1. Phase 1 — Batch Plan (a Workflow)

Author and run a Workflow that fans out **one planning agent per issue** (N=1 → a single
agent). Each planning agent:

- reads the issue AC, the PRD stories, the relevant code, and precedent plans for house style;
- invokes the project's planning discipline (`writing-plans`-shaped, TDD-sliced output);
- writes the plan to `dev/plans/YYYY-MM-DD-<PREFIX>-NNN-<slug>.md` and back-links it into
  the issue file's Spec/Plan section;
- returns a structured result: `{ planPath, decisionsForYou: [] }`, where `decisionsForYou`
  lists **only** forks the PRD did not settle (never invent an answer to one).

**Verify each plan's load-bearing assumptions** — function signatures, schema field names,
file paths it reuses — against the codebase before trusting it. Consolidate every
`decisionsForYou` into one list, **grouped by issue and flagged blocking vs informational**.

Under the JIT-plan-per-issue model (role doc § The two-phase model) this phase folds into the
per-issue refresh step instead, and the standalone gate below does not fire.

### 2. GATE A — Plan review (conditional)

- Consolidated list empty → proceed to Phase 2 (announce it, don't stop).
- Non-empty → **stop**, present the decisions, resolve with the operator, then proceed.
- **First-run exception:** on the very first orchestrated run in a repo, present the plan(s)
  and stop even with an empty list, for trust calibration. Steady-state, honor the
  conditional rule.

### 3. Phase 2 — Execute Loop (a Workflow, dependency-ordered)

A pipeline over the ordered issue set. **Run the conductor's belt between every leg** (role
doc § The conductor's belt) and record its readings in the run report. Per issue:

1. **Refresh** — reconcile the plan against the current trunk (catches drift from issues
   merged earlier in this batch). Material change → surface or park.
2. **Dev** (role doc § Dev-phase execution) — isolate (a worktree, or a plain work branch in
   the main checkout for a single tightly-coupled slice), confirm a green baseline, then:
   **single coupled slice → one scoped background agent** (locked to the touched files; no
   push, no merge, no board moves); **multi-slice plan → `subagent-driven-development`** with
   TDD inside each task. When it returns, **verify before handoff — re-run at least the
   changed-area tests and read the diff yourself**; never relay a self-report. Then hand off
   the pushed work branch with the board mover
   (`move-issue.sh … dev_complete --role Dev`), which commits and publishes the board move
   itself. Honor the worktree/trunk split (role doc § Worktree / trunk discipline).
   A **docs/process/metadata** issue skips the branch entirely and commits direct to
   `<trunk>` — the adapter's lite variant.
3. **QA (fresh eyes)** — dispatch a **fresh, context-isolated** agent (work branch + AC + PRD
   + the `qa.md` lens only; no dev rationale, no planning notes). Render the verdict per the
   confidence rubric:
   - clear PASS → land it with the project's landing script; advance the board; the next
     issue builds on the merge.
   - clear FAIL → bounce to `in_progress` and/or file a bug (the verdict is recorded in the
     issue's Activity log — there is no forge object to comment on); continue with the next
     independent issue.
   - uncertain → **park** (branch unmerged, issue left in `dev_complete/`), add it to the run
     report's batched decisions, and continue.
   After the verdict, **reconcile** QA's evidence against the dev phase's known-limitations
   (which QA never saw) — confirm the fresh review covered the flagged gaps, and follow up if
   it did not (role doc § Conductor reconciliation).
4. Discovered tech-debt or todos → file it (a subtask if this is decomposition) and surface
   it; **never halt for it** (role doc § Discovered tech-debt).

Keep a `progress.md` resume pointer current through long phases (role doc § Quota / resume).

### 4. Report

Emit a run report: **landed** / **parked for your call** / **bugs filed** / **new scope or
todos surfaced for PM**, plus the conductor's-belt readings per leg. Then run the role's
session-end checklist. A run that closes a launch pack stamps that pack in the same change as
the report.

## Dispatch attribution — what a watcher can read while the run is in flight

**The problem this solves:** ten legs in flight are ten anonymous processes unless the dispatcher
says what each one is. **Attribution is assigned by the dispatcher, never reported by the agent** —
which is the property worth keeping, because an agent cannot misreport which issue it is on if it
never says. The dispatcher already knew; it writes it down. (Same shape as the belt's rule that
instruments beat testimony, role doc § The conductor's belt.)

**Every clause below must pay off with nothing watching.** That is the test, not whether something
reads it: a label makes the CLI legible, a declared phase list makes the plan checkable, a recorded
step makes the post-mortem evidence rather than recollection. **A field that exists only to feed a
viewer fails this test and does not belong here.**

### 1. Every dispatch carries a label, `<verb>:<subject>`

**The verb names the seat and the round** — `dev`, `qa`, `dev-fix`, `qa2`, `park-qa` are what the
shipped runners in [`.claude/workflows/`](../../workflows/) already pass, and that is the
convention: the round is part of the verb because *a second QA pass after a fix* and *a first QA
pass* are different facts about where the run stands. Do not flatten them into a generic verb; the
flattening is what loses the answer to "which role, and how many times has this bounced".

**The subject is one of three kinds, and a dispatcher that cannot name which kind it has is
improvising:**

| kind | the subject is | example |
|---|---|---|
| a tracked item | its id | `dev:<PREFIX>-042` |
| a named artifact | its path | `refactor:<path/to/the/file>` |
| **a question** | the question, briefly | `ask:<the-question-in-a-few-words>` |

**The third kind is the one with no home today, and it is a real kind rather than a catch-all.** A
leg dispatched to *answer* something — derive a population, take a measurement, return a verdict on
a claim — produces an ANSWER, not a diff, and **it is done when the question is answered, not when a
file changes.** Calling that a `dev` leg mis-states its definition of done, which is how such a leg
gets graded against a diff it was never going to produce.

**The honest gap, stated rather than solved:** a question's subject is free text and free text
drifts. Keep it short and accept it. The alternative is minting ids for questions, which is ceremony
for something usually answered once and never cited again.

### 2. Phases are declared before the first dispatch, not counted afterwards

The runner's `meta.phases` is the declaration — *what comes next* is then a statement of intent a
reader can check, rather than a shape inferred from however many groups happened to open. **A
declared phase that never opens is visible; an undeclared group that opens is not**, which is why
the declaration is the artifact and the count is not.

### 3. Every level declares a state, and the two terminal failures are distinct

A position without a terminal state cannot be read: *step 4 of 7* says nothing about whether the
work is alive, finished, failed or abandoned, and an agent that crashed looks exactly like an agent
still thinking.

| state | meaning | how it is decided |
|---|---|---|
| `planned` | declared, not started | in the plan, no start record |
| `running` | started, no terminal record | started, nothing terminal yet |
| `done` | finished, succeeded | its own terminal record |
| **`failed`** | finished, did not succeed | **distinct from `done`, and stays visible** |
| **`abandoned`** | descoped or superseded | **distinct from `failed`** |

**`failed` and `abandoned` are the pair that matters.** Both are "not running", and conflating them
is how a real failure is read as a tidy-up. A failed node stays until somebody acknowledges it; an
abandoned one is a deliberate act and says so.

**This is NOT a second outcome vocabulary, and the distinction is load-bearing.** These five are
**lifecycle positions** — where a node is. The RUN-OUTCOME vocabulary in
[`process/MANUAL.md`](../../../process/MANUAL.md) § The RUN-OUTCOME vocabulary is **the summary of a
finished leg**, composed from a verdict and a landing, and that section is its sole authoring site.
A leg in state `done` still has a RUN-OUTCOME; a leg in state `running` does not have one yet.
**Never encode an outcome as a state or a state as an outcome** — if what you want to say is *how a
leg ended*, the vocabulary is that list and not this one.

### 4. Report position as a step in a published sequence — never as a percentage

**Steps-completed-over-steps-declared is a fact; rendering it as a percentage is a claim about
remaining TIME, and it will be wrong in the flattering direction.** The steps are not equal — a leg
whose gate run dwarfs the six steps around it will sit at the same number for a long time, and a bar
that stalls at 85% manufactures an expectation of imminence until the watcher stops watching.

The line to write instead needs no estimate and is strictly more useful:

```
qa:<PREFIX>-042 — step 4 of 7 (adversarial re-read) · 6m on this step · 23m total
```

*"Six minutes on a step that usually takes one"* is actionable; *"57%"* is not.

**A step number is checkable, which is why this is not a role grading itself.** The sequences are
already published and enumerable — the seven-step Dev → QA boundary in
[`process/MANUAL.md`](../../../process/MANUAL.md) § The Dev → QA handoff, and each role doc's own
Definition of Done. A leg claiming *step 9 of 7* is visibly wrong. That is a different class from a
leg estimating how well it is doing.

**Estimation can be EARNED later, and only from accumulated per-step timings** — *step 4 is p90 at
8 minutes and this one is at 14* is a measurement. A weight hardcoded now would be the borrowed
number [`process/doctrine/rigor-tiers.md`](../../../process/doctrine/rigor-tiers.md) refuses.

### 5. Liveness has a threshold, and the threshold is the project's

*Alive* is decidable; *stalled* is not — a leg running the full gate is legitimately silent for
minutes. **Any staleness threshold is a declared seam with a project default, never a kit
constant**, which is the same refusal [`scripts/notify/stall.sh`](../../../scripts/notify/stall.sh)
makes when it requires `--quiet-minutes` and supplies none.

### 6. A script announces its phases; it needs no new mechanism

**A role dispatches agents; a script runs steps**, and the second case needs no new mechanism: a
script that names each step as it begins is readable at the CLI with nothing added, and that
readability is the whole justification. **The shipped scripts already do this, in their own shapes
rather than one** — `verify.sh` prints `── GATE: <name>` per declared gate, `check-board.sh` prefixes
every arm's line with its letter. **Match the script's existing shape; do not impose a common one**,
because the value is a legible transcript, not a parseable format. **Do not stream per-assertion
results**: a suite with five-digit assertion counts reports at the granularity its harness already
emits, and at that scale the useful signal is not progress but **the first failure**, which is
already greppable.

## Scaling notes

- **N=1** → a single planning agent in Phase 1 and a single-item pipeline in Phase 2.
- **N>1, dependent** → serial pipeline, merge-before-next.
- **N>1, independent** → may run parallel pipelines (see `dispatching-parallel-agents`);
  serialize only at the merge-to-trunk boundary, and assign **zero-overlap surfaces** per
  pair. Default serial until the loop has earned trust.
- **A single Workflow run cannot pause for human input** — that is *why* GATE A sits between
  the two workflows, and why an uncertain QA verdict parks-and-reports instead of blocking.
- **Provisioning each dispatched worker (model + effort)** → the rigor-tier ladder in
  [`process/doctrine/rigor-tiers.md`](../../../process/doctrine/rigor-tiers.md), which
  maps each tier to a model and an effort, and each role doc's own § "Model & effort contract"
  (that section lives in the role docs, not in the sheet above) for the standing
  riders, the leaf clause, and the two mechanisms that actually carry an escalation. Read it
  there; **this skill states no provisioning policy of its own.**

## Hard rules (from the role doc — do not violate)

- Never auto-merge a non-clear-cut verdict.
- Never create a top-level issue id.
- Never batch past the TDD red-green gate.
- Never end a turn on a stated intention — a turn ends with a dispatch in flight, the run
  report written, or a named batched decision awaiting the operator.
- Route every escalation to the operator; never paper over one.
