<!-- KIT-CLASS: KIT — bug template (the RIDER body). Two placeholders are STAMPED by the
     initializer: the ISSUE-PREFIX token and the TRUNK token, and this directory is one the
     initializer reaches. **The tokens are described rather than spelled here on purpose** — a
     header that names them literally is rewritten by the very substitution it is explaining, and
     every initialized tree then carried a sentence with no referent.
     Everything else in angle brackets is for the author to fill in — never leave one in a live
     issue. If your initializer has not wired a key, substitute it by hand before first use. -->

<!-- LINKS IN THIS FILE ARE RELATIVE TO WHERE IT LANDS — progress/todo/ — NOT to the directory it
     sits in: a link written for where the template sits is dead in every card. The self-test
     reads this line to know where to resolve from, so keep its shape; the mint strips this block. -->
---
id: <PREFIX>-NNN
type: bug
title: <one-line summary>
severity: <Blocker | Critical | Major | Minor>
environment: <runtime + OS>     # + dependency versions, live-vs-fixture state
prd: PRD-NNN                    # PRD whose behavior is regressed; n/a if none
prd_reason:                     # with prd: n/a only — ONE line: why no PRD covers the broken behaviour
stories: [PRD-NNN-F1-S1]        # specific story whose AC is broken; [] if none
discovered_in: <PREFIX>-NNN     # the issue whose QA review surfaced this bug
blocks: []                      # other <PREFIX>-NNN this bug blocks — a bug found in QA that must
                                # be fixed before the feature above it can land goes HERE, not in
                                # an activity note: the orchestrator gates dispatch on this field
                                # and cannot read prose
blocked_by: []                  # other <PREFIX>-NNN blocking this bug
branch: fix/<PREFIX>-NNN-<slug>
pr: null   # forge PR/MR reference; stays null on the forge-agnostic path
created_at: YYYY-MM-DD
created_by: QA
forks: none                     # or a list of D-NN, one per fork resolved while working this card
---

# <PREFIX>-NNN — <one-line summary>

> **Status** is the folder this file is in. Same lifecycle as feature issues: `todo → in_progress → dev_complete → qa_complete`. Move the file with **`./scripts/move-issue.sh`** — never by hand (`process/contracts/board-mover.md`: *"Only the mover moves it"*, and every move is published to the trunk as its own commit). Do not duplicate status into frontmatter. Bug-fix branches use the `fix/` prefix instead of `feature/`.

## Bug description

One paragraph: what is broken, which surface of the project owns it, and which PRD / story expectation (or documented behavior) it violates.

## R — Reproduction Steps

**Preconditions:**
- Repo at SHA `<sha>` on branch `<branch>`; dependencies installed (`./setup.sh`, or the project's declared setup command).
- Credentials / fixtures: which credential names are set, or which committed fixture reproduces it offline.
- If the repro needs the project's live resources: name the **declared disposable target** and the reason an offline repro is not enough. Never a shared or production artifact.

**Steps:**
1. <concrete command — the exact invocation, copy-pasteable>
2. <concrete step>
3. <observation step — what to look at: output file, exit code, payload shape>

## E — Expected vs Actual

**Expected** (per [PRD-NNN](../../requirements/PRD-NNN-<slug>.md), story <story ids>) — this bug's AC, one id per bullet, for QA's `## QA Verdict` table below:
- [ ] AC1 — <what should happen, citing the AC>

**Actual:**
- <what happens>
- <evidence — the error text, the wrong output, the raw payload shape, the exit code>

**Notes deliverable.** If this bug is consumer-visible, the fix ships its release-notes /
changelog entries in the same change. If it is **not** consumer-visible (an internal-only fix
with no shipped-surface delta), state that explicitly rather than omitting it — named, or
explicitly dismissed, never absent.

## Ablation

Filled by Dev, only if this branch's diff touches a path the project's `TEST_GLOBS` (`scripts/config.sh`) declares as a test path — `finish-pr.sh` refuses such a landing if this section is absent or not well formed (a non-empty `Broken:` line and a non-empty `Red line:` line). Not required, and left as-is, when the diff touches no declared test path.

Broken: <placeholder>
Red line: <placeholder>

## QA Verdict

Filled by QA at review time ([qa.md § Workflow: review pass / fail](../../.claude/roles/qa.md#workflow-review-pass--fail), step 4), one row per Expected AC id above, plus the fixed `shadow-check` row. `evidence kind` is one of `test` · `file:line` · `gate-diff` · `fixture-diff`. `finish-pr.sh` refuses a PASS landing if this table is missing, a row's evidence kind or pointer is empty or still reads `<placeholder>`, any row's verdict is `FAIL_AC` or `FAIL_REGRESSION`, the AC ids here do not match the Expected bullets above one for one, or the `shadow-check` row is absent or empty.

| AC id | verdict | evidence kind | evidence pointer |
|---|---|---|---|
| AC1 | `<PASS \| PASS_AC_CORRECTED \| FAIL_AC \| FAIL_REGRESSION>` | `<placeholder>` | `<placeholder>` |
| shadow-check | — | — | `assertions removed: none` (or each removed/weakened assertion with its replacement) |

## I — Impact

- **Why this severity** (the frontmatter `severity:`): <one sentence, mapping to the scale in [qa.md § Severity scale](../../.claude/roles/qa.md#severity-scale)>
- **Affected surfaces:** <which modules / commands / endpoints>
- **Affected features:** <other PRDs or features that depend on this behavior>

## D — Environment

- Runtime: <language + version> on <OS + version>
- Repo SHA: <sha> on branch `<branch>`; key dependency versions: <list>
- Repro mode: offline fixture `<name>` / against the project's declared disposable live target
- Reproduction rate: <N>/<M> attempts

## R — References

- Output artifact: `<path/to/output>` (commit small samples; large dumps link out)
- Log / traceback: `<snippet>` or the project's debug-logging invocation
- Suspected `file:line`:
  - `<path/to/source>:<line>` — <reason this is suspected>
  - `<path/to/test>:<line>` — <reason>
- Related PRD: PRD-NNN, story <story ids>
- Related issue: <PREFIX>-NNN (the issue whose QA review surfaced this bug)
- Root-cause hypothesis: <one paragraph — Dev may overturn it after [systematic-debugging](../../.claude/skills/systematic-debugging/) Phase 1>
- Suggested fix direction: <one sentence — Dev decides>

> **Worked example.** A filled RIDER body for a real bug — one that names an exact
> `file:line`, quotes the wrong output, and states why the severity is Critical rather than
> Blocker — is worth more than this skeleton. **Keep the first good one your project files as
> the house reference** and link it from here; do not paste a fictional one, because an
> invented example teaches invented facts.

## Activity

`./scripts/move-issue.sh` appends a line for you on every move; append one by hand only when a
significant decision is logged elsewhere. Elsewhere is the decision register,
[`requirements/DECISIONS.md`](../../requirements/DECISIONS.md); cite its id as `[decision: D-NN]`.

**The entry shape is the INDENTED line below, deliberately not a bullet** — it is an example, not
an entry. Copy it out; do not leave it in place as a bullet.

    YYYY-MM-DD [<Role>] <the decision> [decision: D-NN]

- YYYY-MM-DD [QA] Filed in `todo/` during review of <PREFIX>-NNN.
