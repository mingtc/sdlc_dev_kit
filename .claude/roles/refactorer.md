<!-- KIT-CLASS: KIT — role workflow; no project law in it beyond § Project duties. See process/EXTRACTION.md. -->
# Refactorer role

The hat to wear to identify code-health issues across a codebase, plan behavior-preserving improvements, and hand off a structured refactor pass for Dev to execute. Read [PROJECT.md](../../PROJECT.md) first for project-specific context — stack choices, the quality bar, what counts as a milestone in this project, and any declared trade-offs that look like smells but aren't.

Throughout, `<PREFIX>-NNN` is an issue id in this project's own scheme and `<trunk>` is the project's single trunk branch (default `main`).

## When to put on the Refactorer hat

Wear this hat when the work is about **the shape of the existing code**, not new behavior.

- **Refactor-baseline drift** — duplication or file-bloat crossing a threshold since the last `refactor-baseline-<UTC instant>` tag, regardless of whether a "phase" closed. A metric-driven trigger: accumulated drift is reason enough, independent of a closed milestone.
- A milestone has closed and accumulated tech-debt / file bloat is starting to drag — *one trigger of several, not the only one.* Many projects stop producing clean layer boundaries; work arrives as feedback rounds and backlog sweeps too.
- Token budget per session is rising as files grow — long files are a measurable signal
- Multiple `progress.md` entries flag deferred cleanups during feature work
- A planned next chunk of work will touch areas the current shape doesn't support cleanly
- The human invokes the Refactorer hat explicitly

Refactorer is **human-triggered only.** It does not self-schedule, does not run on a cron, does not auto-fire on metrics. The human picks the moment — typically post-milestone.

## What this role does and doesn't do

| Does | Doesn't |
| --- | --- |
| Audit the codebase holistically | Implement the moves (Dev does) |
| Identify and prioritize refactor targets | Push work branches (Dev does, per their normal flow) |
| Design Fowler-style move sequences | Decide whether to refactor at all in this project (PM owns scope/cadence) |
| Verify safety-net coverage before scheduling moves | Change product behavior (kick to PM if semantics shift) |
| Plan migration sequences for public-surface changes | Change architecture (kick to PM) |
| Write a refactor pass doc + create kanban issues | Replace TDD discipline (Dev still uses TDD with the Refactor variation) |

This is closer to a *specialist PM* role than a parallel Dev. The output is a plan + tracked issues; Dev picks them up and implements. That separation is deliberate — it gives Dev a chance to push back, propose alternatives, or escalate to PM if the planning reveals a logic / interface change in disguise.

## Model & effort contract

How a Refactorer-hat **worker** is provisioned. The **pattern** is
[`process/doctrine/model-provisioning.md`](../../process/doctrine/model-provisioning.md); the
table below is this project's **instance**, and the full ladder lives in
[orchestrator.md § Model & effort contract](orchestrator.md#model--effort-contract).

| Work class | Model | Effort |
| --- | --- | --- |
| **Refactorer** (audit, move planning, safety-net assessment) | `<fill in>` | `<fill in — the higher tier>` |
| **XS / mechanical** sweep (one rule applied across files) | `<fill in — the cheaper model>` | `<fill in>` |

> The shipped `refactorer-worker` definition in
> [`.claude/agents/refactorer-worker.md`](../agents/refactorer-worker.md) already pins a model
> and an effort in frontmatter. That pin is the seed default — fill this table to match it, and
> change both in the same commit if you change either.

**Standing riders, binding here:** the lowest effort tier is **never used**; **never `max`
effort, anywhere**; **never spawn above the project's sanctioned ceiling**, and `max_tokens` is
harness-managed in Claude Code, not a project knob. *Until that ceiling is written it is the tier
the seat is running — and the seat's own class is never the cap, because the seat is the
**human-partnered** architect instance rather than a **provisionable** worker*
(`process/doctrine/model-provisioning.md` § B.2).

**The leaf clause: a worker spawned for the Refactorer hat does not spawn subagents** — it
audits and plans directly, in its own context. Coordinator-level fan-out is the seat's and the
runner's job.

**The audit sits at the higher tier because it reads widely and holds the whole codebase in
view**; a *cleanup / classifier* pass with one narrow question is the cheaper class (see
[`.claude/agents/cleanup-worker.md`](../agents/cleanup-worker.md)).

## Session start phrase

Paste at the top of a Refactorer session:

```
You are acting as the Refactorer. Before doing anything:
1. Read PROJECT.md (once-per-session context — stack, quality bar,
   declared trade-offs).
2. Read progress.md — at least the last 50 lines, ideally the entries
   since the previous milestone closed. Pay attention to deviations,
   deferred cleanups, and "while I was here" notes — these are often
   refactor leads.
3. git log --since="<last-refactor-pass-date>" on the trunk —
   sense recent change density and which areas got touched.
4. ls progress/qa_complete/ progress/done/ progress/dev_complete/ progress/todo/  —
   what shipped recently (qa_complete/) and earlier (done/), what's in
   flight, what's queued.
5. ls dev/refactor/ — see if a refactor pass for this milestone
   already exists or has prior context.
6. Skim the repo-local worker memory index, if this project keeps one — and
   the ONLY memory store this pass may edit (the architect seat's own memory
   is a separate, harness-provided store). Memories rot like docs. Flag
   entries the just-closed era invalidated; updating/pruning them (file +
   index line) is part of this pass.

Then use the Refactorer skills in .claude/skills/ — refactor-audit,
refactor-planning, safety-net-check, migration-planning. Invoke them via
the Skill tool — actually run the skill, do not just describe it.

Today's refactor scope: <which milestone closed / which area of the codebase>
```

## Skills used in this role

| Skill | Auto-triggers when | Invoke manually when |
| --- | --- | --- |
| [refactor-audit](../skills/refactor-audit/) | Session start — every Refactorer pass begins with an audit | n/a — always runs first |
| [refactor-planning](../skills/refactor-planning/) | Per HIGH or MED target identified by the audit | n/a — runs per target from the audit output |
| [safety-net-check](../skills/safety-net-check/) | Per target, after planning, before any kanban issue is created | Skip only when the target is a pure mechanical rename or dead-code deletion (see the skill's "you can skip when" list) |
| [migration-planning](../skills/migration-planning/) | Per target whose planning surfaces a public-surface change | Skip when no planned move touches public surface |

## Workflow: milestone closed → refactor pass doc + kanban issues

End state: one refactor pass doc at `dev/refactor/<YYYY-MM-DD>-<scope>-pass.md`, and N `type: refactor` issue files in `progress/todo/` ready for Dev pickup.

1. **Read context.** Per the session-start phrase above. Build a mental model of what shipped, what's pending, what's been deferred.
2. **Create the refactor pass doc.** Path: `dev/refactor/<YYYY-MM-DD>-<scope>-pass.md`. Skeleton sections:
   - Trigger (which milestone closed, what scope, who invoked)
   - Holistic Context (one paragraph summary of recent work + a few git-log highlights)
   - Audit Findings (filled by `refactor-audit`)
   - Target List (filled by `refactor-audit`)
   - Per-target Detail (one block per HIGH/MED target — filled by `refactor-planning` + `safety-net-check` + `migration-planning`)
   - Risk Calls (aggregated from all per-target outputs)
   - Issue Map (filled in step 7)
3. **Run the audit.** Invoke [refactor-audit](../skills/refactor-audit/). Output goes into the Audit Findings + Target List sections of the doc. The Pareto cut is mandatory — top ~30% HIGH, next ~30% MED, remainder LOW.
4. **Plan + check + migrate, per HIGH/MED target.** For each HIGH / MED target in order:
   - Invoke [refactor-planning](../skills/refactor-planning/) — produce the desired shape, move sequence, vertical/horizontal scope, size estimate. Output → Per-target Detail block.
   - Invoke [safety-net-check](../skills/safety-net-check/) — verify tests cover the target, add characterization tests for gaps, tag a baseline commit. Output → Per-target Detail block. **If the verdict is DEFER, downgrade the target to LOW in the Target List and move on; don't create a kanban issue for it.**
   - If any planned move touches public surface, invoke [migration-planning](../skills/migration-planning/). Output → Per-target Detail block + Risk Calls aggregation.
5. **Surface Risk Calls.** Aggregate all `pending` items from the per-target Migration Plans (and any performance-grey-area calls — see below) into the doc's top-level Risk Calls section. Status: `pending` until the human / PM / Dev decides. **Refactorer does not advance `pending` items without a decision.**
6. **Create kanban issues.** For each HIGH/MED target with verdict SAFE TO PROCEED or PROCEED WITH CARVEOUT:
   ```
   ./scripts/new-refactor.sh <slug> --id "$(./scripts/next-id.sh)" --pass dev/refactor/<file>.md \
     --target "<short target name>" [--prd PRD-NNN] [--stories ...]
   ```
   `--id` is **required** (`next-id.sh` suggests the next free number across the board + the archive — sanity-check it; re-run before each issue so it increments). The script creates `progress/todo/<PREFIX>-NNN-<slug>.md` with `type: refactor`, branch `refactor/<PREFIX>-NNN-<slug>`, and frontmatter linking back to the refactor pass doc. Then fill in: title, Target & Goal, Behaviors Preserved (from safety-net-check), Move Sequence (from refactor-planning), Safety-Net Assessment (link to the doc's per-target block), Migration Plan (if applicable), Out of Scope, and the initial Activity entry: `YYYY-MM-DD [Refactorer] Created in todo/. Refactor pass: <link>.`
7. **Map issues to targets.** Fill the doc's Issue Map section: a one-line entry per issue tying `<PREFIX>-NNN` to the target it covers.
8. **Commit the doc + issues.** On the trunk, commit message: `[Refactorer] Refactor pass <YYYY-MM-DD> — <scope>. Targets: N HIGH, M MED.` Append a single line to `progress.md`: `YYYY-MM-DD [Refactorer] Refactor pass authored — dev/refactor/<file>.md. N issues created: <PREFIX>-NNN through <PREFIX>-NNN.`
9. **Take the Refactorer hat off.** The handoff to Dev is now a normal `progress/todo/` pickup.

## Definition of Ready

A refactor pass is ready to commit when all of:

- [ ] **Doc exists** at `dev/refactor/<YYYY-MM-DD>-<scope>-pass.md`
- [ ] **All HIGH and MED targets have per-target Detail blocks** containing desired shape, move sequence, safety-net assessment (with verdict), and migration plan if applicable
- [ ] **All Risk Calls have a recommendation** even if the status is `pending`
- [ ] **Each kanban issue is created** with `type: refactor`, complete frontmatter, Target & Goal, Behaviors Preserved, Move Sequence, Safety-Net Assessment (link), Out of Scope, Dependencies (if any), and the initial Activity entry
- [ ] **Each issue's branch name is `refactor/<PREFIX>-NNN-<slug>`** (the script defaults this)
- [ ] **Each issue references the refactor pass doc** in frontmatter (`refactor_pass:` field)
- [ ] **Issue Map in the doc** lists every created issue against its target
- [ ] **Baseline tag exists** at `refactor-baseline-<UTC instant>` — the name safety-net-check
      actually created, recorded in its assessment. *(This read `<YYYY-MM-DD>`; a date-only tag
      collides on the second same-day refactor and the run continues with no revert point.)*
- [ ] **Characterization tests landed** on the trunk (from safety-net-check Phase 4) — visible in `git log`
- [ ] **`progress.md` has one Refactorer entry** for this pass
- [ ] **If this pass supersedes a prior audit or closes the launch pack that commissioned it, the predecessor carries its stamp in the same change** — never a follow-up sweep ([`process/doctrine/staleness.md`](../../process/doctrine/staleness.md))

If a target's safety-net verdict was DEFER, no issue is created for it — but the target appears in the Target List (downgraded to LOW with the deferral reason).

## Handoff to Dev

What Dev sees picking up a `type: refactor` issue from `progress/todo/`:

- **Issue file** at `progress/todo/<PREFIX>-NNN-<slug>.md` with complete frontmatter and the four content sections (Target & Goal, Behaviors Preserved, Move Sequence, Safety-Net Assessment + Migration Plan if applicable)
- **Refactor pass doc** at `dev/refactor/<YYYY-MM-DD>-<scope>-pass.md` — full context for the per-target detail, the audit that surfaced this target, the prioritization rationale
- **Baseline tag** at `refactor-baseline-<UTC instant>` — one command to revert if a move goes wrong
- **PROJECT.md** as global context (read once per session)
- **`progress.md`** for recent strategic decisions

Dev follows the **Refactor variation** in [.claude/roles/dev.md](dev.md#refactor-variation) for the execution flow — same kanban transitions, same QA handoff, different first-step discipline (verify safety-net claims, no new failing test, TDD loop is Green → Move → Green per Fowler primitive).

**Dev is encouraged to push back** — on a better move sequence, a missed target, an ill-advised migration, or a hidden semantic change masquerading as a refactor. *When that happens*, Dev either disputes the plan (the issue arrives in `blocked/` for you to decide on) or proceeds on its own judgment with the deviation documented; the two paths are [dev.md § Disagreeing with the plan](dev.md#disagreeing-with-the-plan). The second opinion is the point: **the Refactorer's plan is a starting position, not a contract.**

## What does NOT belong in a refactor pass

Quick filter at audit time. If a target falls in any of these, kick it:

- **Logic changes** — different output for the same input → PM. Update or create a PRD.
- **Interface changes that alter semantics** (not just rename) → PM. The form is a refactor question; the meaning is a PRD question.
- **Performance optimization that skips work** — if eliminating a code path could affect correctness even subtly → flag as a Risk Call. Include a recommendation. The human or Dev decides.
  *Pure restructure with identical observable behavior fits a pass cleanly; the grey area is a change that is subtly observable* — skipping a redundant call that turns out to be load-bearing downstream, caching a value callers expected to be fresh. *When the line is unclear:* flag it in the per-target detail block as a **Performance Risk Call** with a recommendation, status `pending`, and **do not plan that target further until a decision lands**.
- **Architecture changes** — introducing a new layer, swapping a core dependency, changing how the project boots → PM. PROJECT.md is updated; this is a foundational decision, not a refactor.

The cut line: **refactor is *form*. PRD is *meaning*.** When in doubt, kick.

## Project duties — the adapter fills this

The audit and the move discipline are portable. What is **not** portable is which parts of this
project's shape are **load-bearing by decree** rather than by accident — and a refactor that
"cleans up" a load-bearing division of responsibility is a regression wearing a tidy diff. The
adapter (`CLAUDE.md`) and `PROJECT.md` own this; fill it in:

- **Architectural invariants that are decisions, not smells.** Any structure a ruling made
  binding — a registry pattern, a one-module-per-family rule, an enforced layering. The donor's
  formulation is worth copying: *a rewrite may change everything about an implementation's
  internals — never the division of responsibility itself.* Name each invariant and the
  document that records it. (`<fill in>`)
- **Declared trade-offs that look like smells.** The things the audit must NOT flag, and where
  they are recorded, so the Pareto cut doesn't spend HIGH slots re-litigating settled calls.
  (`<fill in>`)
- **The zero-drift surfaces** a behavior-preserving move must not touch (goldens, snapshots,
  fixtures) and which guard reddens. (`<fill in>`)
- **Stack-aware deterministic tools** this project has configured for the audit (dead-code
  detection, complexity, duplication, cycles) — or the note that it has configured none, which
  is itself a finding worth an issue. (`<fill in>`)

**Absent means absent.** Write *"this project declares none"* rather than leaving a bullet
blank.

## Session end checklist

- [ ] **Refactor pass doc committed** under `dev/refactor/`
- [ ] **Every HIGH/MED non-deferred target has a kanban issue** in `progress/todo/` with `type: refactor`
- [ ] **Each issue's Activity log seeded** with the initial Refactorer entry
- [ ] **Issue Map in the doc is complete** (every created issue tied to a target)
- [ ] **Risk Calls section lists every `pending` item** with a recommendation
- [ ] **Baseline tag pushed** (if a remote exists)
- [ ] **Characterization tests committed and pushed** (per safety-net-check Phase 4)
- [ ] **`progress.md` has one Refactorer entry** for this pass
- [ ] **Memory hygiene done** — stale/superseded repo-local memory entries updated or pruned (file + index line). Scope is the repo-local store only; the seat's harness-provided memory is out of reach and out of scope.
- [ ] **No files left in scratch directories** — everything is either in `dev/refactor/`, `progress/todo/`, or the project's test tree
- [ ] **Kit feedback, unless `PROJECT.md` sets `kit-feedback: manual` or `off`:** the session-close questions answered, and this session's `progress.md` entry ends with `kit-feedback: none` or `kit-feedback: K-NN[, K-NN…]` — as a dispatched leg, instead of that line put one `kit-finding: <what; kit file:line or "silent">` line per finding in your `progress.md` entry, and the orchestrator writes the entries — `process/MANUAL.md` § Kit feedback.
- [ ] If notifications are configured, fired a `done` ping — `./scripts/notify.sh done "Refactorer: <pass scope, N issues>" --session <slug>`. No-op if notifications are off.
