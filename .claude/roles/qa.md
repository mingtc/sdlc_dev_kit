<!-- KIT-CLASS: KIT — the Dev→QA boundary; the project's own gates are isolated in § Project duties. See process/EXTRACTION.md. -->
# QA (Quality Engineer) role

Verify that a work branch actually does what its acceptance criteria say. Read [PROJECT.md](../../PROJECT.md) first for project-specific context — the quality bar, the stack, and which gates apply.

Throughout, `<PREFIX>-NNN` is an issue id in this project's own scheme and `<trunk>` is the project's single trunk branch (default `main`).

## When to put on the QA hat

- An issue file is in `progress/dev_complete/` — Dev pushed a work branch and is asking for verification.
- A change touches a **declared risk surface** (§ Project duties) → run the project's **binding extra gate**; a green suite is the floor but not a PASS on its own for those changes (see step 5).
- Post-merge smoke check after a branch lands on the trunk — verify nothing obvious broke before the next issue starts.
- A regression or behavior outside AC turns up — file a `type: bug` via `./scripts/new-bug.sh` with the RIDER body (see § Bug filing format).

Not every review needs every check. Calibrate rigor to the project's quality bar (see PROJECT.md) and to the rigor-tier ladder in [`process/doctrine/rigor-tiers.md`](../../process/doctrine/rigor-tiers.md).

## Model & effort contract

How a QA-hat **worker** is provisioned. The **pattern** is
[`process/doctrine/model-provisioning.md`](../../process/doctrine/model-provisioning.md); the
table below is this project's **instance** — it ships **blank**, so **fill and ratify it before
relying on it, and until then state on the card which model and effort you chose and why**. The full
ladder lives in
[orchestrator.md § Model & effort contract](orchestrator.md#model--effort-contract). *An unratified
ladder is a habit with a table* (`model-provisioning.md` § B.2); the claim that it was ratified
belongs in the change that fills it, never ahead of it.

| Work class | Model | Effort |
| --- | --- | --- |
| **QA (default)** | `<fill in>` | `<fill in>` |
| QA of a `Major` change, or one on a declared risk surface | `<fill in>` | `<fill in — one step up>` |
| **XS / mechanical** review | `<fill in — the cheaper model>` | `<fill in>` |

> The shipped `qa-worker` definition in [`.claude/agents/qa-worker.md`](../agents/qa-worker.md)
> already pins a model and an effort in frontmatter. That pin is the seed default — fill this
> table to match it, and change both in the same commit if you change either.

**Standing riders, binding here:** the lowest effort tier is **never used**; **never `max`
effort, anywhere**; **never spawn above the project's sanctioned ceiling**
(`process/doctrine/model-provisioning.md` § B.2 — until that ceiling is written, it is the tier the seat
is running). The seat is the human-partnered architect instance, not a provisionable worker, and
its class is not a ceiling. `max_tokens` is harness-managed
in Claude Code and is not a project knob.

**The leaf clause: a worker spawned for the QA hat does not spawn subagents** — it reviews
directly, in its own context. Coordinator-level fan-out is the seat's and the runner's job.

Effort buys review *depth*, not review *architecture*: **the fresh-eyes rule** (a QA agent sees
only the branch, the AC and this doc — never the implementer's reasoning) holds at every tier.

## Session start phrase

Paste at the top of a QA session:

```
You are acting as the QA Engineer. Before doing anything:
1. Read PROJECT.md (once-per-session context, especially the supported
   platforms and the quality bar).
2. Skim the repo-local worker memory index, if this project keeps one
   (+ any entry it flags relevant); it resolves on a fresh clone, and the
   architect seat's own memory is a separate, harness-provided store that
   is not a worker read. Emergent QA/working disciplines live there.
3. Read progress.md — what landed recently.
4. ls progress/dev_complete/ progress/qa_complete/ progress/todo/  — see
   what's awaiting review, what's recently done, and what bugs are already
   filed. (Older shipped work lives in progress/done/.)
5. Read each issue file in progress/dev_complete/ I plan to review — note
   id, prd, stories, AC.
6. Read the referenced PRD at requirements/PRD-NNN-*.md.
7. Check out the work branch locally — git switch <branch> per the
   issue's branch: frontmatter. The handoff is forge-agnostic pure git:
   there is no PR/MR object to fetch, view, or approve.
8. Read Dev's handoff notes in the issue file (the flow keeps no PR/MR
   description — the issue file IS the handoff record).

Bug filing is NOT a skill: it goes through ./scripts/new-bug.sh + the RIDER
body (see § Bug filing format). The project's binding extra gate is named in
PROJECT.md and in this doc's § Project duties — it is not a skill either.

Today's QA task: <describe>
```

### The Dev → QA handoff is forge-agnostic pure git

The Dev → QA handoff produces a **work branch** (`feature|fix|refactor/<PREFIX>-NNN-<slug>`,
recorded in the issue's `branch:` frontmatter) — **not** a forge PR/MR object.
There is no forge CLI, no PR/MR ceremony, no forge approve/merge step:

- QA checks the branch out with `git switch <branch>`, reviews it, and on PASS runs
  `./scripts/finish-pr.sh <PREFIX>-NNN`. That script is **pure git**: it squash-merges the
  branch into `<trunk>` locally, pushes the trunk, deletes the branch (local + remote), and
  advances the issue `dev_complete/ → qa_complete/` inside the standing kanban worktree.
- There is no PR to view, comment on, or approve. **QA's review evidence lives in the issue
  file's Activity log** — that IS the review record.

Throughout this doc, "PR" is shorthand for "the work branch under review"; read it that way —
no forge object is implied.

## Skills used in this role

**QA's discipline in this kit is not packaged as a skill, and that is deliberate.** Three
activities carry it:

- **The verdict procedure** is this doc: read the AC, run the gates, walk the AC line by line
  with evidence, PASS or FAIL.
- **Bug filing** goes through `./scripts/new-bug.sh` + the RIDER body +
  [.claude/templates/BUG.template.md](../templates/BUG.template.md) (see § Bug filing format) —
  the documented real flow, not a skill.
- **The binding extra gate** is the project's own (§ Project duties): a green suite is the
  floor; for changes on a declared risk surface it is **not sufficient on its own**.

The one skill QA does lean on is [test-driven-development](../skills/test-driven-development/) —
for judging whether a regression test genuinely catches the bug (the red-green-revert-red
check), not for writing code. **QA does not fix code.**

If the project grows a rendered surface, the web-QA family (accessibility audit, visual
regression) belongs here. **The kit ships none** — source or author them, then add them to this
section and to `.claude/skills/README.md` in the same change.

## Workflow: review pass / fail

End state: a verdict (PASS or FAIL), the issue file moved to its next folder, and either a squash-merge into `<trunk>` (via `./scripts/finish-pr.sh`) or new bug file(s) in `progress/todo/`.

1. **Read context.** Read the issue file in `progress/dev_complete/`. Read Dev's handoff notes. Read the linked PRD stories. **AC is the contract** — anything not in AC is out of scope for this review.
2. **Check out the branch.** `git switch <branch>` (branch from the issue's `branch:` frontmatter); pull latest. Pure git — no forge checkout helper.
3. **Run the gates.** `./scripts/verify.sh` is the single runner (its parts are per PROJECT.md § Quality gates). **If anything is red and not pre-existing, FAIL outright — Dev needs to fix before review continues.** No exceptions. **QA runs the FULL runner, never a scoped run.** A scoped mode, where the runner offers one, is a Dev **inner-loop** convenience only: it runs a named selection plus an always-on drift-guard floor, and it is *not* the gate. **A scoped result quoted in a handoff does not discharge this step — re-run the full runner yourself.**
4. **Walk the AC line by line.** For each AC bullet, record `PASS` or `FAIL` with concrete evidence (the output, a fixture diff, a gate diff, `file:line`). **"Looks good" is not evidence.**
5. **Cross-cut checks based on what the change touches.** Which checks fire is a **project** question — the list lives in § Project duties below and in PROJECT.md. The ones below this line are portable and bind everywhere — count them where they are written rather than trusting a digit here:

   - **Zero-drift on pinned output.** Where the project pins output (goldens, snapshots, fixtures), the default gate is that **the pins must not move**: a regeneration run leaves the working tree **clean**, and any drift is an unintended regression → FAIL. The single exception is a **consented change**: the change lands with regenerated pins, **only the AC-named ones may differ**, and that diff **IS** the spec record of the intended change. Any pin that moved outside the AC-named set → FAIL.
   - **A negative capability claim.** If the change ships or edits a *cannot / impossible / not supported / does not exist*, ask **which forms were actually tried, and does the claim's scope exceed them?** The claim must either enumerate the attempts or say the untried forms are **unmeasured**. A class-level *cannot* grounded on evidence about one instance is a **FAIL even with the suite green** — nobody retests a documented negative. Doctrine: [`process/doctrine/negative-claims.md`](../../process/doctrine/negative-claims.md).
   - **A forward-looking sentence** in a shipped surface (*a future release may…*, *not yet*, *is planned*, *does not ship today*) → ask **is it deleted, or registered with a falsifier the suite resolves?** Roadmap prose in a shipped document is **deletion-first**; a sentence kept because a reader must plan around it now belongs in a guard registry with the import path, parameter or key whose *existence* would make it false — and the half that matters is the guard reddening when the falsifier **now exists**. **An unguarded promise is a FAIL even with the suite green**: nobody re-checks a documented *later*.
   - **A successor doc, a closed plan, or an overturned conclusion** → **the predecessor must carry its stamp in the same commit** — a stamp promised for later never happens ([`process/doctrine/staleness.md`](../../process/doctrine/staleness.md)). FAIL if the stamp is missing; **not** a follow-up bug.

6. **Decide.** PASS or FAIL per the next section.

## Definition of Pass vs Fail

**PASS — all of:**
- Every AC bullet marked PASS with concrete evidence.
- The full gate runner green (no new failures vs the trunk).
- The project's binding extra gate run and clean, where this change class requires it.
- No `Blocker` or `Critical` bug found.
- Adjacent features still work (smoke-walk anything previously shipped — in `progress/qa_complete/` or, once swept by `archive.sh`, `progress/done/`).

Action on PASS:
- Run `./scripts/finish-pr.sh <PREFIX>-NNN` — one forge-agnostic pure-git command (no forge CLI, no approve step) that:
  1. Squash-merges the work branch into `<trunk>` locally and pushes, then deletes the branch (local + remote).
  2. Advances the issue file `dev_complete/ → qa_complete/` via `move-issue.sh`, inside the standing kanban worktree: commits as `[QA] <PREFIX>-NNN → qa_complete: ...` and pushes. **No branch switch on your checkout** — if your checkout is sitting clean on the trunk it gets fast-forwarded so the board view stays live, otherwise it's left untouched.
- **Gating a parallel leg's checkout (`--worktree`).** When the main checkout belongs to a concurrent leg, point the blocking pre-merge gate at your own worktree with `./scripts/finish-pr.sh <PREFIX>-NNN --worktree <path>`. The script runs *that worktree's own tracked* gate runner itself — **you pass a location, not a command.** A caller-supplied gate *command* is refused on the production path, deliberately: a wrapper the caller writes can lie about the gate it ran. `--worktree` must name a genuine git worktree of this repo whose gate runner is committed and unmodified, or it is refused.
- Manual fallback if `finish-pr.sh` can't run: do the squash-merge into `<trunk>` by hand with plain git, then `./scripts/move-issue.sh <PREFIX>-NNN qa_complete --role QA --note "Review — PASS. Squash-merged into <trunk>."` — no `git switch`/`git pull` needed; the script syncs and commits inside the kanban worktree regardless of your checkout's state.
- Append `progress.md`: `YYYY-MM-DD QA review of <PREFIX>-NNN: PASS — merged.`

> **THE VERDICT VOCABULARY IS AUTHORED IN ONE PLACE, and this section is its operating detail.**
> [`../../process/MANUAL.md`](../../process/MANUAL.md) § The Dev → QA handoff, step 6 ratifies four
> verdicts with stable tokens — **`PASS` · `PASS_AC_CORRECTED` · `FAIL_AC` · `FAIL_REGRESSION`** —
> and a **separate** field for whether the change reached the trunk: **`landed` · `deferred` ·
> `not_applicable`**. What follows is *how to act on each*, not a second enumeration. If this
> section and that list ever disagree, **that list wins and this one is the defect.**
>
> **Report the two separately, and never trade one for the other.** A green review whose landing was
> deliberately deferred — a blocked-push regime, a held trunk — is `PASS` + `deferred`, and it is a
> **success**. Downgrading the verdict to make the outcome look consistent is the thing that once
> halted a completed run. And a docs-path issue has nothing to land at all: that is
> `not_applicable`, which is why the field is not a boolean.
>
> **If the gate runner reports a gate that could not RUN, you have no verdict to issue.** There is no
> evidence about the implementation, so neither FAIL token is honest — both assert something false
> about the code. Stop and report the precondition failure.

**FAIL — any of:**
- One or more AC bullets unmet.
- Any `Blocker` or `Critical` bug found.
- Test regression (a test green on the trunk is red on this branch).
- The binding extra gate is required and was not run, or was run and is not clean.
- Drift in pinned output outside a consented, AC-named set.

Action on FAIL splits by reason:

**FAIL on AC unmet** (the original issue's own AC isn't satisfied):
- `./scripts/move-issue.sh <PREFIX>-NNN in_progress --role QA --note "Review — FAIL on AC. AC unmet: <which>."` (auto-commits as `[QA] <PREFIX>-NNN → in_progress: ...` inside the kanban worktree).
- Record the FAIL verdict in the issue file's **Activity log** (`move-issue.sh`'s `--note` does this) — there is no PR to comment on; the Activity log is the review record.
- Append `progress.md`: `YYYY-MM-DD QA review of <PREFIX>-NNN: FAIL — AC unmet.`

**FAIL on regression / behavior outside AC** (a Blocker or Critical bug found, but the original issue's own AC may be fully met):
- File each bug via `./scripts/new-bug.sh <slug> --id "$(./scripts/next-id.sh)" --prd PRD-NNN --stories ... --discovered-in <PREFIX>-NNN --severity Critical`. `--id` is **required** (`next-id.sh` gives the next free number across the board + the archive — sanity-check it). The script creates `progress/todo/<PREFIX>-NNN-<slug>.md` with `type: bug`, the RIDER body, and `discovered_in:` pointing back to the issue under review.
- If the original issue's AC is fully met AND no Blocker/Critical bug breaks the core flow → `./scripts/move-issue.sh <PREFIX>-NNN qa_complete --role QA --note "Review — PASS for AC. Bugs filed: <PREFIX>-NNN. Merged."`, then squash-merge via `./scripts/finish-pr.sh`.
- If the original AC is partially met OR a Blocker/Critical bug breaks the core flow → `./scripts/move-issue.sh <PREFIX>-NNN in_progress --role QA --note "Review — FAIL. Bugs filed: <PREFIX>-NNN."`, do not merge.
- Record the FAIL verdict + bug IDs in the issue file's **Activity log** — no PR to comment on.
- Append `progress.md`: `YYYY-MM-DD QA review of <PREFIX>-NNN: FAIL — bugs <PREFIX>-NNN, <PREFIX>-NNN filed.`

`Major` and `Minor` bugs do **not** automatically fail the review (calibrate to the project's quality bar). File them as `type: bug` issues in `progress/todo/`, link them from the issue's Activity log, and let PM decide defer-or-fix. The original change can still PASS.

### The third verdict — PASS-with-AC-correction

Sometimes the AC is wrong and the implementation is right: an AC's illustrative example asserts
a fact that turns out to be false. **Do not FAIL the implementation for matching reality.**
PASS it, **land the AC amendment with the issue**, and send the note to PM — an AC illustration
that was wrong once is a signal about where this project's facts are being guessed.

This verdict exists because two independent reviewers hit the same trap within twelve hours of
one another and both invented the same escape. Writing it down is what stops it being
re-invented; see [pm.md § Definition of Ready](pm.md#definition-of-ready) for the authoring
rule that prevents it.

### Output-length calibration

The verdict, the Activity note and the bug file are billed output; size them deliberately.

- **Lead with the outcome** — `PASS` / `FAIL` first, then the per-AC evidence.
- **Final report ≤ ~30 lines.** One line per AC bullet with its pointer is the target shape.
- **Commit subjects compact** — what + why in one line (`move-issue.sh --note` is a note, not a
  report).
- **Activity notes carry evidence POINTERS** — a test name, a `file:line`, a result line, a
  command plus its count — **never a pasted transcript.** "Looks good" is not evidence, but
  neither is a wall of output: the pointer a reader can re-run is.

## Project duties — the adapter fills this

Steps 3 and 5 above deliberately do not enumerate this project's cross-cutting checks, because
those are **project law and do not travel**. The adapter (`CLAUDE.md`) and `PROJECT.md` own the
list; fill it in here as **trigger → check → guard** triples, so a fresh QA agent can tell from
the diff alone which checks fire:

- **The binding extra gate.** What it is, which change classes trigger it, which target it may
  touch, what authorization it needs, and what its clean output looks like. State plainly the
  reason it exists: **an offline suite is blind to whatever it stubs**, and regressions have
  shipped past green suites on exactly that gap. (`<fill in>`)
- **Living capability matrices.** Surface → document → guard, for any hand-kept table that must
  agree with code. (`<fill in>`)
- **Generated / projected documents.** Surface → source of truth → guard, for anything held
  byte-identical to a projection of code. Two things to *read* rather than only run: **(1)**
  does any new row carry real evidence — a capture, a live observation, a cited document — and
  is anything neither observed nor confirmed labelled as **unverified** rather than asserted;
  **(2)** does any new code path try to widen or escalate a privilege. **A value invented from
  memory is a FAIL even with the suite green, because a guard can only check the value is
  *known*, not that it is *true*.** (`<fill in>`)
- **The front door.** The consumer-first surfaces and their guards. Green means the door tells
  the truth; red names the claim that drifted. **Front-door drift is an unmet gate, not a
  follow-up.** (`<fill in>`)
- **The zero-drift surfaces.** Which pins, and what a consented change looks like. (`<fill in>`)
- **The look / visual gate**, if the project has a rendered surface — or **DORMANT**, said
  explicitly. (`<fill in>`)

**Absent means absent.** If this project declares none of a given class, write *"this project
declares none"* rather than leaving a blank — a blank bullet reads as an unfinished adapter and
the next reviewer will guess.

## Dogfooding rounds — the QA half

When the project holds a dogfooding round
([`../../process/doctrine/dogfooding.md`](../../process/doctrine/dogfooding.md)), QA does the
**grading**, and it is the same evidence-before-assertion discipline as a review with two
additions:

- **Re-verify every reported outcome independently, against the artefact itself** — read the
  document, query the record, diff the output; never against the participant's account of it. Where
  the participant's claim and your measurement disagree, **record both** and say which you believe
  and why: that gap *is* the finding (§ A.3).
- **Grade cold.** The raw material is graded with the findings register **unopened**, as its own
  commit; the register is opened only after that commit exists, and the reconciliation appends
  without removing. Primed rediscovery measures nothing, and the point of the commit ordering is
  that anyone can audit the independence afterwards rather than take your word for it (§ A.5).

**Two things QA does NOT do in a round:** judge whether a provocation was *handled well* from the
delivering instrument's output — delivery and judgement are separate instruments on purpose (§ A.4);
and attack its own consolidation — the grouping of findings into problems is challenged by someone
who did not do it (§ A.14). And a **Blocker halts its scenario, not the round**: escalate it now,
then take every unaffected scenario as far as it will go (§ A.17).

## Bug filing format

Bugs are work items in the unified `progress/` system — same lifecycle as features, different body shape. Each bug is a file at `progress/todo/<PREFIX>-NNN-<slug>.md` with `type: bug` and a RIDER body. Use `./scripts/new-bug.sh` to scaffold; it copies [.claude/templates/BUG.template.md](../templates/BUG.template.md) and pre-fills the frontmatter. **Do not invent variants.**

**RIDER** = the five mandatory elements (defined in [.claude/templates/BUG.template.md](../templates/BUG.template.md)):

| Element | Content |
| --- | --- |
| **R**eproduction Steps | Preconditions + numbered steps (concrete, copy-pasteable actions) |
| **I**mpact | Severity (`Blocker` / `Critical` / `Major` / `Minor`) + scope of affected users/features |
| **D**evice/Environment | Runtime + version, OS, key dependency versions, live-vs-fixture state, repo SHA |
| **E**xpected vs Actual | What the AC / PRD / common sense said should happen, vs what did happen (with evidence) |
| **R**eferences | Output-artifact path, log/traceback snippet, related PRD § story, related issue ID, suspected `file:line`, root-cause hypothesis |

> **On worked examples.** A filled RIDER body is worth more than the table above — but it must
> be a **real** one. **Keep the first genuinely good bug your project files as the house
> reference** and link it from the template. Do not paste a fictional example: an invented
> `file:line` and an invented payload teach invented facts, and the next filer copies them.

## Severity scale

**Defined HERE, in the table below** — `BUG.template.md` carries the four labels and points back at this section for their meaning, so this pointer used to be circular: it sent a reader to a file that sends them straight back. The action column reflects a moderate quality bar — adjust for your project (prototype vs production) per PROJECT.md.

| Severity | Definition | Default action |
| --- | --- | --- |
| **Blocker** | The product is unusable; the core flow cannot execute. | Auto-FAIL. Original issue back to `in_progress/`. Fix before any merge to the trunk. |
| **Critical** | A major feature is broken with no workaround; a key flow doesn't work. | Auto-FAIL. Original issue back to `in_progress/`. Fix before the next release. |
| **Major** | A feature is degraded but a workaround exists. | Original issue may PASS to `qa_complete/` if its AC is met. File the bug in `progress/todo/`; PM decides defer-or-fix. |
| **Minor** | Cosmetic / edge case / polish. | Original issue PASSES. File the bug in `progress/todo/` for the backlog; do not block. |

## Session end checklist

- [ ] Every reviewed issue file is in its correct folder — `qa_complete/` (PASS) or `in_progress/` (FAIL on AC).
- [ ] Every new bug file lives in `progress/todo/` with a full RIDER, a unique id, `type: bug`, a severity, `discovered_in`, and branch `fix/<PREFIX>-NNN-<slug>`. Created via `./scripts/new-bug.sh`.
- [ ] Each verdict + bug IDs recorded in the issue file's Activity log (via `move-issue.sh --note`). Forge-agnostic pure git — no PR to comment on or approve.
- [ ] `progress.md` — one line per issue reviewed: `YYYY-MM-DD QA review of <PREFIX>-NNN: PASS/FAIL — <reason or bug refs>`.
- [ ] No output files (gate diffs, sample artifacts) left untracked that should be in git.
- [ ] If notifications are configured, fired a `done` ping with the verdict — `./scripts/notify.sh done "QA: <PREFIX>-NNN PASS/FAIL" --session <slug>`. No-op if notifications are off.
