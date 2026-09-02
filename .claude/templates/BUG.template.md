<!-- KIT-CLASS: KIT — bug template (the RIDER body). Two placeholders are STAMPED by the
     initializer: the ISSUE-PREFIX token and the TRUNK token, and this directory is one the
     initializer reaches. **The tokens are described rather than spelled here on purpose** — a
     header that names them literally is rewritten by the very substitution it is explaining, and
     every initialized tree then carried a sentence with no referent.
     Everything else in angle brackets is for the author to fill in — never leave one in a live
     issue. If your initializer has not wired a key, substitute it by hand before first use. -->
---
id: <PREFIX>-NNN
type: bug
title: <one-line summary>
severity: Critical              # Blocker | Critical | Major | Minor
environment: <runtime + OS>     # + dependency versions, live-vs-fixture state
prd: PRD-NNN                    # PRD whose behavior is regressed; n/a if none
stories: [PRD-NNN-F1-S1]        # specific story whose AC is broken; [] if none
discovered_in: <PREFIX>-NNN     # the issue whose QA review surfaced this bug
branch: fix/<PREFIX>-NNN-<slug>
pr: null   # forge PR/MR reference; stays null on the forge-agnostic path
created_at: YYYY-MM-DD
created_by: QA
---

# <PREFIX>-NNN — <one-line summary>

> **Status** is the folder this file is in. Same lifecycle as feature issues: `todo → in_progress → dev_complete → qa_complete`. Bug-fix branches use the `fix/` prefix instead of `feature/`.

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

**Expected** (per [PRD-NNN § F1 § S1](../../requirements/PRD-NNN-<slug>.md)):
- <what should happen, citing the AC>

**Actual:**
- <what happens>
- <evidence — the error text, the wrong output, the raw payload shape, the exit code>

**Notes deliverable.** If this bug is consumer-visible, the fix ships its release-notes /
changelog entries in the same change. If it is **not** consumer-visible (an internal-only fix
with no shipped-surface delta), state that explicitly rather than omitting it — named, or
explicitly dismissed, never absent.

## I — Impact

- **Severity:** Blocker | Critical | Major | Minor
- **Why this severity:** <one sentence, mapping to the scale in [qa.md § Severity scale](../../.claude/roles/qa.md#severity-scale)>
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
- Related PRD: PRD-NNN § F1 § S1
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
significant decision is logged elsewhere.

**The entry shapes are the INDENTED BLOCK below, deliberately not bullets** — the board
checker reads the **last `- ` bullet** under this heading, so an example written as a bullet
makes a freshly filed bug report false drift.

    YYYY-MM-DD [Dev] Picked up — moved to in_progress via ./scripts/move-issue.sh. Branch: fix/<PREFIX>-NNN-<slug>.
    YYYY-MM-DD [Dev] Ready for review — moved to dev_complete. Branch pushed; gates green.
    YYYY-MM-DD [QA] Review — PASS. Squash-merged into `<trunk>` (finish-pr.sh); moved to qa_complete.

- YYYY-MM-DD [QA] Filed in `todo/` during review of <PREFIX>-NNN.
