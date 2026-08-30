<!-- KIT-CLASS: KIT — role workflow; the project-law duties are isolated in § Project duties. See process/EXTRACTION.md. -->
# Dev (Software Engineer) role

Implement issues and bug fixes. Read [PROJECT.md](../../PROJECT.md) first for project-specific context (stack choices, quality bar, build order, setup/run commands).

Throughout, `<PREFIX>-NNN` is an issue id in this project's own scheme and `<trunk>` is the project's single trunk branch (default `main`).

## When to put on the Dev hat

- An issue is in `progress/todo/` (any `type:` — feature, spike, chore, bug) and ready to pull.
- An issue you already own is sitting in `progress/in_progress/` from a prior session — resume it.
- A non-trivial refactor or spike is needed before the next issue is workable.
- During the build phase this is typically the default hat — most sessions start here.

## Model & effort contract

How a Dev-hat **worker** is provisioned. The **pattern** is
[`process/doctrine/model-provisioning.md`](../../process/doctrine/model-provisioning.md); the
table below is this project's **instance**, ratified by PM, and the full ladder for every role
lives in [orchestrator.md § Model & effort contract](orchestrator.md#model--effort-contract).

| Work class | Model | Effort |
| --- | --- | --- |
| **Dev (default)** | `<fill in>` | `<fill in>` |
| Dev on a declared risk surface, or genuinely hard work | `<fill in>` | `<fill in — one step up>` |
| Dev on a beast-class problem | `<fill in>` | `<fill in — top tier>`, **only by PM sign-off** |
| **XS / mechanical** Dev work | `<fill in — the cheaper model>` | `<fill in>` |

> The shipped `dev-worker` definition in [`.claude/agents/dev-worker.md`](../agents/dev-worker.md)
> already pins a model and an effort in frontmatter. That pin is the seed default — fill this
> table to match it, and change both in the same commit if you change either.

**Standing riders, binding here:** the lowest effort tier is **never used**; **never `max`
effort, anywhere**; **never spawn the seat's own model class** — the seat is the
human-partnered architect instance, not a provisionable worker, and sits outside the ladder.
`max_tokens` is harness-managed in Claude Code and is not a project knob.

**The leaf clause: a worker spawned for the Dev hat does not spawn subagents** — it works
directly, in its own context. Coordinator-level fan-out is the seat's and the runner's job.
(§ Subagent strategy below describes the *seated*, human-partnered Dev hat; a dispatched Dev
worker is a leaf and that section does not apply to it.)

## Session start phrase

Paste verbatim at session start:

```
You are acting as a Senior Engineer. Before doing anything:
1. Read CLAUDE.md.
2. Read PROJECT.md (once-per-session context).
3. Skim the repo-local worker memory index, if this project keeps one
   (+ any entry it flags relevant): collaboration prefs + emergent
   disciplines that may govern this work. It resolves on a fresh clone;
   the architect seat's own memory is a separate, harness-provided store
   and is not a worker read.
4. Read progress.md — last 50 lines or last session's entries.
5. ls progress/in_progress/ progress/todo/ progress/blocked/  — see what's
   mine to continue, what's available, and what's stuck.
6. Read the issue file I intend to pick up (or am in the middle of). Note
   id, branch, prd, stories, AC, Dependencies.
7. If continuing, read the referenced PRD at requirements/PRD-NNN-*.md.
8. git status — report current branch and any uncommitted state.

Then use the dev skills in .claude/skills/ — start by reading
using-superpowers, then apply brainstorming, writing-plans, executing-plans,
subagent-driven-development, test-driven-development, systematic-debugging,
verification-before-completion, using-git-worktrees, requesting-code-review,
receiving-code-review, finishing-a-development-branch as appropriate. Invoke
them via the Skill tool — don't skip the skill, follow its workflow.

Tell me which issue you intend to pick up and wait for confirmation before
starting work.
```

## Skills used in this role and how they chain

Skills marked **auto** trigger themselves from context once the Dev hat is on. **Manual** = invoke by slash command.

| Skill | Trigger | Produces | Where output goes |
| --- | --- | --- | --- |
| [using-superpowers](../skills/using-superpowers/) | auto, every session | Bootstrap — reminds to check skills before acting | n/a |
| [brainstorming](../skills/brainstorming/) | auto when HOW is unclear; manual | Short engineering design spec | `dev/specs/YYYY-MM-DD-<topic>-design.md` (committed) |
| [writing-plans](../skills/writing-plans/) | auto after brainstorming; manual | Bite-sized, TDD-shaped task list | `dev/plans/YYYY-MM-DD-<PREFIX>-NNN-<slug>.md` (committed) |
| [using-git-worktrees](../skills/using-git-worktrees/) | auto before execution | Isolated workspace + clean baseline | `.worktrees/<branch>/` (gitignored) |
| [subagent-driven-development](../skills/subagent-driven-development/) | manual; preferred when tasks are independent | Commits per task, two-stage reviewed | Worktree branch |
| [executing-plans](../skills/executing-plans/) | manual; fallback when subagents not a fit | Commits per task, inline checkpoints | Worktree branch |
| [test-driven-development](../skills/test-driven-development/) | auto inside every implementation step | Red-green-refactor commits | Worktree branch |
| [systematic-debugging](../skills/systematic-debugging/) | auto on failure or unexpected behavior | Root-cause analysis + failing test | Test file, then fix commit |
| [verification-before-completion](../skills/verification-before-completion/) | auto before claiming done | Fresh gate-runner output | Reported in chat + issue Activity + progress.md |
| [requesting-code-review](../skills/requesting-code-review/) | auto in subagent loops; manual before handoff | Reviewer report (Critical/Important/Minor) | Acted on in-session |
| [receiving-code-review](../skills/receiving-code-review/) | auto when QA or reviewer responds | Verified fixes or reasoned pushback | New commits or review replies |
| [finishing-a-development-branch](../skills/finishing-a-development-branch/) | auto when execution reports done | Pushed branch, preserved branch, or discarded work — **never a merged commit; landing is QA's act via `finish-pr.sh`** | Pushed work branch + issue file moved to `progress/dev_complete/` (via `move-issue.sh`) |

**The canonical chain for a `progress/todo/` feature issue:**

> Pick up issue → move to `in_progress/` (via `move-issue.sh`) → [brainstorming] (if HOW unclear) → [writing-plans] → [using-git-worktrees] → [subagent-driven-development] (or [executing-plans]) → inside each task: [test-driven-development], [systematic-debugging] on failure → [requesting-code-review] after each task → [verification-before-completion] before claiming done → [finishing-a-development-branch] (push the branch — no forge PR) → `move-issue.sh` to `dev_complete/`. QA then lands it with `finish-pr.sh` (pure-git squash-merge; see qa.md).

**Calibrate the chain to the change — the rigor-tier ladder.** The full chain above is the TIER 2/3 weight. A **TIER 1** change — a copy/comment tweak or a test-only edit with **no behavior change** — skips brainstorming + writing-plans, runs a single inline implementer, and skips the binding extra gate unless a declared risk surface actually changed. The full ladder (TIER 1/2/3 + the binding-gate decision rule) lives in [`process/doctrine/rigor-tiers.md`](../../process/doctrine/rigor-tiers.md); apply the same tiers in a non-orchestrated Dev session.

## Workflow: `progress/todo/` issue → branch ready for QA

> **Forge-agnostic pure git — there is no PR/MR object.** Dev hands off a **pushed work
> branch** (`feature|fix|refactor/<PREFIX>-NNN-<slug>`, recorded in the issue's `branch:`
> frontmatter); QA checks it out with `git switch <branch>` and lands it with the pure-git
> `finish-pr.sh` (squash-merge → `<trunk>`). **There is nothing to "open", "approve", or
> "comment on"**, and no forge object or URL to record. **The issue file's Activity log IS the
> handoff record** (see "Handoff to QA" below + qa.md). Throughout this doc, "the work branch
> under review" is meant wherever an old habit might say "the PR". (Docs/process/metadata
> issues skip the branch entirely — see the adapter's direct-to-trunk lite variant.)

1. **Pick up the issue.** Read `progress/todo/<PREFIX>-NNN-<slug>.md`. Note `id`, `type`, `branch`, `prd`, `stories`, AC, Dependencies.
2. **Move the file.** `./scripts/move-issue.sh <PREFIX>-NNN in_progress --role Dev --note "Picked up. Branch: <branch>."` — the script performs the move in the standing kanban worktree, auto-commits as `[Dev] <PREFIX>-NNN → in_progress: ...`, and pushes; your current checkout and branch are never touched.
3. **Design check.** Two artifacts can settle the design:
   - **PM PRD** at `requirements/PRD-NNN-<slug>.md` (referenced by the issue's frontmatter) — defines WHAT.
   - **Engineering design** at `dev/specs/...` (output of [brainstorming](../skills/brainstorming/)) — defines HOW.

   Skip [brainstorming] only when HOW is unambiguous — true for issues where the PRD + existing patterns fully constrain the implementation. For anything with architectural forks, cross-cutting changes, or genuine design space, [brainstorming]'s HARD-GATE applies — run it and commit the design spec before planning.
4. **Plan.** Invoke [writing-plans](../skills/writing-plans/). Output to `dev/plans/YYYY-MM-DD-<PREFIX>-NNN-<slug>.md`. Bite-sized TDD-shaped tasks. Update the issue file's "Spec / Plan" section with both links.
5. **Isolate.** Invoke [using-git-worktrees](../skills/using-git-worktrees/). The skill creates `.worktrees/<branch>/` on the branch from the issue's frontmatter. Baseline tests must be green before proceeding.
6. **Execute.** Invoke [subagent-driven-development](../skills/subagent-driven-development/) (preferred) or [executing-plans](../skills/executing-plans/). Both require [using-git-worktrees] to have run.
7. **TDD loop inside every task.** Red → verify red → green → verify green → refactor → commit. The Iron Law: no production code without a failing test first. Where TDD genuinely doesn't fit (manual/live verification, hard-to-test integrations), fall back to characterization tests + manual verification — and document the deviation in `progress.md` so QA knows what was and wasn't automated.

   **Selective-run in the inner loop.** Red/green iteration does not need the whole suite. If the project's gate runner offers a scoped mode (`./scripts/verify.sh --scope <paths…>` or equivalent), use it — but understand what makes a scoped run *safer than naming tests alone*, **and what it does not make it**: it runs the tests you name **plus the declared set of cross-cutting drift guards**, and there is **no flag that turns that floor off**. Those guards exist because they redden for a change made **somewhere else**, which is precisely what a naive "just run the tests I touched" sails past. **But the floor is only as complete as the declaration**: a guard that exists in the tree and was never added to the runner's list is not run, and nothing reports it — so a scoped run is never the full-gate claim, whatever the guard count says.

   > **Selective-run is for the TDD inner loop ONLY. The FULL suite remains mandatory at the
   > `dev_complete` handoff, at QA, and at release. Coverage is never cut and the drift guards
   > are never skipped.**

   If you add or rename a cross-cutting guard, **the guard and its enrolment in the runner's always-on set are one coupled set and ride the same change.** Your code globs put the runner on the metadata side while the file it guards is code, so this is the **executable-declaration** case of the adapter's metadata carve-out — not the documentation-of-code case its worked examples show. Split them and the branch's gate cannot see the guard while the trunk's cannot see what it guards. *(Doctrine: [`process/doctrine/commit-hygiene.md`](../../process/doctrine/commit-hygiene.md) § A.5 — the gate's unit is the SET. The rule it carves out of is [`process/MANUAL.md`](../../process/MANUAL.md) § The code-vs-metadata rule.)*
8. **Debug systematically.** Invoke [systematic-debugging](../skills/systematic-debugging/) on any test failure or unexpected behavior. Phase 1 (root cause) before any fix. Three failed fixes in a row → stop, question architecture, escalate by moving the issue to `progress/blocked/` (see below).
9. **Review per task.** [subagent-driven-development] already calls [requesting-code-review] after every task. If running [executing-plans], invoke [requesting-code-review] manually at task boundaries.
10. **Update progress.md.** During or after each meaningful task: decisions, surprises, deviations, skipped tests with reasons.
11. **Verify before claiming done.** Invoke [verification-before-completion](../skills/verification-before-completion/) — run the project's one-shot gate runner (**`./scripts/verify.sh`**; the commands it wraps are per PROJECT.md — deterministic order, no re-derivation). If the project configures a linter or typechecker, they are gates too; if it configures none, they are not gates here — read PROJECT.md, do not assume either way.
12. **Finish the branch.** Invoke [finishing-a-development-branch](../skills/finishing-a-development-branch/), choose the **push-the-branch** option — **push the work branch; do NOT create a forge PR** (the handoff is pure git). The handoff notes go in the issue file's Activity log per "Handoff to QA" below, not in a forge review description.
13. **Move the file to `dev_complete/`.** **No branch switch — do NOT `git switch <trunk>`.** Kanban ops run inside the standing detached kanban worktree, so editing `progress/in_progress/` on your own checkout is the footgun: the loose edit is destroyed when `move-issue.sh` re-derives the move in the kanban worktree. Just run `./scripts/move-issue.sh <PREFIX>-NNN dev_complete --role Dev --note "Ready for review. Branch <branch> pushed; gates green. Handoff notes below."` — no checkout switch is needed; the script does the folder move + Activity entry + commit inside the kanban worktree and pushes the trunk. The Activity `--note` (plus the "Handoff to QA" notes you append to the issue body) IS the review record — there is no forge object or URL to record. Append a session summary to `progress.md`.

### Worktree decision

| Situation | Use worktree? |
| --- | --- |
| New feature/spike/chore issue | yes |
| Bug fix touching > 1 file | yes |
| Multi-task plan | yes |
| One-line typo fix on an issue already in `in_progress/` | no — work in place |
| Spike / exploratory throwaway | yes, so it can be discarded cleanly |

### Getting blocked

If you hit something that needs a PM decision (AC ambiguous, architectural fork, missing dependency that should have been resolved before pickup):

1. `./scripts/move-issue.sh <PREFIX>-NNN blocked --role Dev --note "Blocked: <one-sentence blocker>. Needs PM clarification."`
2. Append a clear `## Blocker` section inside the issue body with the question, options considered, what unblocks you.
3. Append a `progress.md` line.
4. Pick a different issue from `todo/`, or end the session.

### Spawning a follow-up issue

If during work you discover a separable tech-debt task, refactor, or spike that shouldn't bloat the current issue: run `./scripts/new-issue.sh <slug> --id "$(./scripts/next-id.sh)" --prd PRD-NNN --stories ...` to create a new `progress/todo/<PREFIX>-NNN-<slug>.md` (`--id` required; `next-id.sh` suggests the next free number — sanity-check it). Reference it from the current issue's "Out of Scope" and from `progress.md`. Stay focused on the current ticket.

## Subagent strategy

> **Seated hat only.** This section is for the human-partnered Dev hat choosing how to run its
> own session. A **dispatched** Dev worker is a **leaf** — it does not spawn subagents
> (§ Model & effort contract). Fan-out is a coordinator decision, not a worker's.

| Mode | When to pick | Source |
| --- | --- | --- |
| **Do it yourself, inline** | Plan tightly coupled (each task depends on the last's runtime context), or no plan yet | [subagent-driven-development] decision tree |
| **[subagent-driven-development](../skills/subagent-driven-development/)** | Written plan, tasks mostly independent, stay in this session. Good default where each task is self-contained. | The skill's "When to Use" |
| **[dispatching-parallel-agents](../skills/dispatching-parallel-agents/)** | 2+ truly independent investigations (e.g. 3 unrelated test files broken). Not for executing a sequential plan. | "One agent per independent problem domain" |

Concrete rules from the skills:

- [subagent-driven-development] runs subagents **serially** (one implementer at a time) with two-stage review per task. Do not fan out implementers in parallel — explicit red flag.
- [dispatching-parallel-agents] is for **investigation/debugging fan-out**, not implementation of a sequential plan.
- Subagents do not inherit session context. Construct exactly what they need (task text, scene-setting, constraints).

## Definition of Done

Before moving the issue file to `progress/dev_complete/` (via `move-issue.sh`), every item below must be true. This is the bar enforced by [verification-before-completion](../skills/verification-before-completion/).

- [ ] Every AC in the issue has a passing test, or a documented justification in `progress.md` for why it can't be automated.
- [ ] **Full** gate run **in this session**: 0 failures. Quote the **result line**, not the run. **A scoped/selective run does NOT satisfy this item** — selective-run (step 7) is for the TDD inner loop ONLY. The line you quote here must come from an unscoped `./scripts/verify.sh`.
- [ ] No skipped tests without a `progress.md` entry explaining why and linking a follow-up issue if needed.
- [ ] Every gate the project's runner wraps is green — read PROJECT.md for the list; do not re-derive it.
- [ ] **The project's binding extra gate has been run** where this change class requires it (§ Project duties). A green offline suite is the **floor, not a PASS**, for changes on a declared risk surface.
- [ ] **A stamp is owed on the predecessor when this change lands a successor doc, closes a plan, or overturns a recorded conclusion — in the same commit, never a follow-up issue** ([`process/doctrine/staleness.md`](../../process/doctrine/staleness.md)).
- [ ] **The ruling is recorded where it is looked up — in the same change.** A PM/seat ruling that changes behavior, **and any measured discovery** (a probe result that settles what a dependency actually does), gets its entry in the project's decision register — or in its corpus home where it has one — **in the same change**, not only an issue-file note. An Activity line records *this issue*; the next reader looking up *what is currently true* will not find it. Keep the register a **projection**: state the current ruling, one line of why, and its provenance; the history stays in the ledger.
- [ ] **A negative capability claim ships with its enumeration — or with "unmeasured" language.** If the change writes or edits a shipped *cannot / impossible / not supported / does not exist*, it either lists the **forms actually tried** (enough to see the edge of the evidence) or says the untried forms are **unmeasured, not refuted**; and the claim's scope may not exceed its evidence's scope (evidence about one grammar grounds a claim about that grammar, not its class). Doctrine: [`process/doctrine/negative-claims.md`](../../process/doctrine/negative-claims.md).
- [ ] **A claim established outside the test suite commits the script that established it**, under the evidence directory's `probes/` subdirectory. **A spike is the obvious case, not the only one** — the duty is about the EVIDENCE TYPE, not the issue type. Wherever a number, a negative, or a compatibility guarantee is settled by a program run outside the suite — because its inputs cannot be committed, its runtime is too long, or it compares two revisions — **that program IS the evidence**, and a schema bump or a dependency-floor move carries more weight than most spikes do. The scripts are what lets a later reader audit the edge of a negative claim, which captures alone may not preserve. A leg that ran no script says so explicitly rather than shipping an empty `probes/` — named, or explicitly dismissed, never absent.
- [ ] **A claim of ABSENCE or FUTURITY is guarded or deleted.** If the change writes a forward-looking sentence into a shipped surface — *a future release may…*, *not yet*, *does not ship today* — it is **deleted first** (roadmap prose belongs where the roadmap is maintained, not in what ships), and kept only if a reader must plan around it now. Kept means **registered in a guard with a falsifier** — the import path, parameter or capability key whose *existence* would make the claim false — resolved in both directions. The incident that earned this rule: a promise about a future capability outlived its own truth by eight releases, because nobody re-checks a documented *later*.
- [ ] `progress.md` appended with: what was built, decisions, deviations, anything QA should know.
- [ ] Work branch pushed (forge-agnostic — a pushed branch, **not** a forge PR).
- [ ] Issue file Activity log appended, including the "Handoff to QA" notes below (the Activity log IS the review record — there is no forge review object).
- [ ] Issue file moved to `progress/dev_complete/` (via `move-issue.sh`).
- [ ] **Every duty in § Project duties below is discharged** for the surfaces this change touched.

### Output-length calibration

The artifacts above are billed output; size them deliberately.

- **Lead with the outcome** — the verdict first, the reasoning after, if at all.
- **Final report ≤ ~30 lines.** A handoff is a set of pointers, not a narrative.
- **Commit subjects compact** — what + why in one line. No transcripts, no pasted output, no
  multi-paragraph bodies restating the diff.
- **Activity notes carry evidence POINTERS** (`file:line`, a test name, a result line, a
  command + its count) — never a pasted transcript. The pointer is the evidence; the reader can
  re-run the command.

## Project duties — the adapter fills this

The workflow above is portable. **The cross-cutting duties that make a change complete in
*this* project are not** — and a Dev worker cannot honour a duty nobody wrote down. The adapter
(`CLAUDE.md`) and `PROJECT.md` own this list; fill it in, and make each entry name a
**surface → obligation** pair plus **the guard that reddens** when the pair is broken:

- **The binding extra gate.** What must be run beyond a green suite, for which change classes,
  against which target, with what authorization. (`<fill in>`)
- **Living capability matrices.** Any hand-kept document that must agree with a code surface —
  a support matrix, a block/feature table. Name the surface, the document, and the guard.
  (`<fill in>`)
- **Generated / projected documents.** Any document that is a *projection* of code rather than
  prose — a permissions or scopes registry, a generated reference. The rule that makes these
  safe: **authored in one place, projected everywhere else, held byte-identical by a guard.**
  Name the source of truth and the regeneration command. (`<fill in>`)
- **The front door.** Whatever a consumer meets *first* — package metadata, the README, the
  rendered `--help`, release notes — and the rule that **consumer-doc truth is part of
  shipping, not a periodic sweep**: touch a consumer-reaching surface and correct the door in
  the same change. Name the guard. (`<fill in>`)
- **Privilege / escalation rules.** If the project talks to a system with a permission model,
  state what the code may and may not do about it (the donor's rule, worth copying: *the
  library never widens, requests or escalates a privilege — it describes requirements and
  surfaces the platform's own denial; a grant is an operator action*). (`<fill in>`)
- **Zero-drift surfaces.** Which pinned outputs must not move, and what a consented change
  looks like. (`<fill in>`)

Two rules govern how you fill this in, and they are **not** optional:

1. **A duty with no guard is a wish.** If a surface→document obligation has no test that
   reddens, write the guard in the same change that writes the duty — otherwise the duty
   decays into folklore within a release.
2. **Absent means absent.** If this project genuinely has no matrices, no generated docs, no
   live gate, write *"this project declares none"* under the bullet. A blank bullet reads as an
   unfinished adapter, and the next worker will guess.

## Handoff to QA

There is **no PR/MR object** — QA reviews the pushed **work branch** and the issue file. Append
a `## Handoff to QA` section to the **issue file body** (above `## Activity`) with the content
below; that section + the Activity log ARE the review record QA reads:

```markdown
## Handoff to QA

### Spec / Plan
- Engineering design (if produced): `dev/specs/<file>.md`
- Plan: `dev/plans/<file>.md`

### Acceptance Criteria
- [ ] AC1 ... (verified via `<test file>::<test name>`)
- [ ] AC2 ... (verified manually — see evidence below)
(copy from the issue; mark each with how it's verified)

### What changed
<2-4 bullets — the why, not a file-by-file diff>

### How to review locally
1. `git switch <branch>`   (the branch from the issue's `branch:` frontmatter)
2. <project's setup / run command — see PROJECT.md>
3. <steps a QA can actually follow>

### Binding-gate evidence
<for changes on a declared risk surface — the gate's own output, before/after>

### Known limitations
<anything QA should not flag as a bug — e.g. "the nested case is deferred to <PREFIX>-NNN">
```

If QA fails the review:
- **AC unmet** → QA moves the file back to `progress/in_progress/` (via `move-issue.sh`); you re-enter the workflow at step 4 (re-plan) or step 7 (fix).
- **Bug found** (regression / behavior outside AC) → QA files a **new** `type: bug` issue in `progress/todo/` via `./scripts/new-bug.sh`. Your original issue may still go to `progress/qa_complete/` if its AC is fully met; the bug enters the queue independently.

## Session end checklist

- [ ] Every issue file touched is in its correct folder (`in_progress/`, `dev_complete/`, or `blocked/`).
- [ ] Every moved file has a current Activity entry (and, if `dev_complete/`, the "Handoff to QA" notes in its body).
- [ ] `progress.md` appended with today's entries.
- [ ] Branch(es) pushed (forge-agnostic — pushed branches, not forge PRs).
- [ ] Scratch files / experimental tests cleaned up or moved into the plan.
- [ ] Worktrees in `.worktrees/` for files in `dev_complete/` are **preserved** (per [finishing-a-development-branch](../skills/finishing-a-development-branch/) Option 2 — QA may need them).
- [ ] Worktrees for merged or discarded work cleaned up via the skill.
- [ ] If notifications are configured, fired a `done` ping — `./scripts/notify.sh done "Dev: <PREFIX>-NNN <state>" --session <slug>`. No-op if notifications are off.

## Bug-fix variation

Starts from a `type: bug` issue in `progress/todo/` (not a feature). Most of the chain is the same; the differences:

| Step | Feature flow | Bug-fix flow |
| --- | --- | --- |
| Branch name | `feature/<PREFIX>-NNN-<slug>` (from frontmatter) | `fix/<PREFIX>-NNN-<slug>` (from frontmatter) |
| First action | [brainstorming] / [writing-plans] | **[systematic-debugging](../skills/systematic-debugging/) Phase 1 first** — read the RIDER bug report carefully, reproduce consistently, check recent changes. No fixes until root cause is identified. |
| First test | A normal AC test | **A failing test that reproduces the bug** (per [systematic-debugging] Phase 4 Step 1 + [test-driven-development] "Debugging Integration"). Becomes the permanent regression test. |
| Verification | [verification-before-completion] on AC | Same, **plus** red-green-revert-red on the regression test to prove it actually catches the bug. |
| Done bar | All AC pass | AC pass **and** the bug's reproduction is now a permanent test in the suite. |
| Handoff notes | Standard | Add a `## Root cause` section to the issue's Handoff-to-QA notes per [systematic-debugging] — what was wrong, why, what test prevents recurrence. |

If three fix attempts fail per [systematic-debugging] Phase 4.5: **stop**, run `./scripts/move-issue.sh <PREFIX>-NNN blocked --role Dev --note "Three fix attempts failed; needs design conversation."`, and escalate to PM. Do not attempt fix #4 in the same shape.

## Refactor variation

Starts from a `type: refactor` issue in `progress/todo/` (created by the Refactorer per [.claude/roles/refactorer.md](refactorer.md)). Most of the workflow is the same — issue pickup, branch push, kanban moves, QA handoff. The differences:

| Step | Feature flow | Refactor flow |
| --- | --- | --- |
| Issue body | Acceptance Criteria | **Behaviors Preserved** (existing + characterization tests) + **Move Sequence** (Fowler primitives, ordered) + **Safety-Net Assessment** + **Migration Plan** (if applicable). The contract is "these behaviors continue to work," not "this new behavior exists." |
| Branch name | `feature/<PREFIX>-NNN-<slug>` | `refactor/<PREFIX>-NNN-<slug>` |
| First action | [brainstorming] / [writing-plans] | **Verify the safety-net claims still hold.** Check out the baseline tag (e.g. `refactor-baseline-<date>`), run the full suite — green? Read the Refactorer's Move Sequence. **If you disagree with the plan, see "Disagreeing with the plan" below.** |
| First test | A failing test for new behavior | **No new failing test.** The existing tests + characterization tests added during safety-net-check *are* the test scaffold. |
| TDD loop | Red → Green → Refactor | **Green → Move → Green → Commit per Fowler primitive.** Each move is one commit named for the primitive (e.g. `[Dev] <PREFIX>-NNN: Extract Function <name>`). After every move, the full suite must pass; if it doesn't, revert the move and either re-attempt smaller or escalate. |
| Multiple moves in one commit | Allowed (within a single AC slice) | **Forbidden.** Each Fowler primitive is its own commit. Horizontal sweeps may group commits by directory or rule application but never mix primitives. |
| Verification | [verification-before-completion] on AC | Same skill, different assertion: **every behavior in "Behaviors Preserved" still passes** + the full gate runner green + **no behavior outside "Intentionally unconstrained" has observably changed**. |
| Done bar | All AC pass | All Behaviors Preserved still pass + Move Sequence executed (no skipped moves without a `progress.md` deviation note) + no public surface changed beyond what's listed in Migration Plan. |
| Handoff notes | Standard | Add a `## Behaviors Preserved` section listing each behavior with its verifying test, and a `## Commit-by-Move log` listing each Fowler primitive and its commit SHA. |

### Disagreeing with the plan

The Refactorer's plan is a starting position. If on reading it you see a better move sequence, a missed target, or an ill-advised migration, you have two options:

- **(a) Discuss with the Refactorer.** Append a note to the issue's Activity log explaining the disagreement, then `./scripts/move-issue.sh <PREFIX>-NNN blocked --role Dev --note "Refactor plan disputed: <one-sentence reason>."` Refactorer reads, decides, and either updates the plan or proceeds; the issue moves back to `in_progress/` after the discussion resolves.
- **(b) Proceed with your judgment and document the deviation.** Append a `progress.md` line and a note in the issue Activity. This is the existing Dev practice for plan deviations — same standard applies. QA will see the deviation in the issue's Activity log / Handoff-to-QA notes.

The second opinion is the point of the Dev role being a separate hat from Refactorer. Use it.

### If the planned refactor reveals a logic / semantic change

If during execution it becomes clear that the moves are not behavior-preserving — the planning underestimated the change, or a "rename" turns out to require shape changes that callers can observe — STOP and escalate:

1. `./scripts/move-issue.sh <PREFIX>-NNN blocked --role Dev --note "Refactor reveals semantic change: <one sentence>. Needs PM/Refactorer call."`
2. Append a clear `## Blocker` section inside the issue body with what you found.
3. Append a `progress.md` line.
4. Pick a different issue from `todo/`, or end the session.

The Refactorer or PM will decide whether to convert to a PRD-level change (logic / interface decision), reshape the refactor plan, or defer.
