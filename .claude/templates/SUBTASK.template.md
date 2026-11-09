<!-- KIT-CLASS: KIT — subtask template (the Orchestrator's decomposition slice). Two
     placeholders are STAMPED by the
     initializer: the ISSUE-PREFIX token and the TRUNK token, and this directory is one the
     initializer reaches. **The tokens are described rather than spelled here on purpose** — a
     header that names them literally is rewritten by the very substitution it is explaining, and
     every initialized tree then carried a sentence with no referent.
     Everything else in angle brackets is for the author to fill in — never leave one in a live
     issue. If your initializer has not wired a key, substitute it by hand before first use.
     NO `blocks:` / `blocked_by:` in this frontmatter, by decision: a dependency outside the parent
     belongs on the PARENT, the unit the board dispatches; a slice that needs one is its own issue. -->

<!-- LINKS IN THIS FILE ARE RELATIVE TO WHERE IT LANDS — progress/subtasks/<PREFIX>-NNN/<status>/ —
     four segments deep (scripts/subtask.sh's DEST_DIR), NOT the directory it sits in: a link written
     for where the template sits is dead in every card. The self-test reads this line to know where
     to resolve from, so keep its shape; the mint strips this block. -->
---
id: <PREFIX>-NNN-sM      # parent <PREFIX>-NNN + subtask index; does NOT consume the id stream
type: subtask
parent: <PREFIX>-NNN     # the PM-owned issue this decomposes
#title note: write a " or \ inside the quotes as \" or \\
title: "<one-line summary of this slice>"
size: S                  # subtasks should be S (≤1 session); if M+, re-slice
prd: PRD-NNN             # the parent's, unless --prd names another
stories: [PRD-NNN-F1-S1] # the subset of the parent's stories this slice covers
branch: feature/<PREFIX>-NNN-sM-<slug>
pr: null   # forge PR/MR reference; stays null on the forge-agnostic path
created_at: YYYY-MM-DD
created_by: Orchestrator
forks: none              # or a bracketed list [D-NN, ...], one id per fork resolved while working this slice
---

# <PREFIX>-NNN-sM — <one-line summary>

> A **subtask** of `<parent card>`, on the board. It lives under
> `progress/subtasks/<PREFIX>-NNN/`, in the folder that is its status. The parent advances to
> `qa_complete/` only when every subtask has reached `qa_complete/` or been declined with its reason;
> the mover, the lander and the sweep refuse it otherwise. Move this card with `scripts/subtask.sh`, not `move-issue.sh`.

## Why this slice exists

One or two sentences: why the parent was decomposed and what boundary this slice owns.
PM does not curate subtasks — this is an implementation-level split, not a scope change.

## Acceptance Criteria (sliced from the parent)

The subset of the parent's AC this slice satisfies. Each independently QA-testable. The
parent's AC set is the **union** of all its subtasks' AC; no AC is dropped or invented here.

- [ ] AC<n> — from <story id> (parent AC<n>): <statement>

## Ablation

Filled by Dev, only if this slice's own diff (against its declared `branch:`, where one exists) touches a path the project's `TEST_GLOBS` (`scripts/config.sh`) declares as a test path — `subtask.sh move <id> qa_complete` refuses such a move if this section is absent or not well formed (a non-empty `Broken:` line and a non-empty `Red line:` line). Not required, and left as-is, when the diff touches no declared test path. If the red line appears only after a build step (a test that reads built output), name that step on the `Broken:` line. The card is the trunk's: land this section's edit with `./scripts/register-commit.sh`, never on a work branch.

Broken: <placeholder>
Red line: <placeholder>

## QA Verdict

Filled by QA at review time ([qa.md § Workflow: review pass / fail](../../../../.claude/roles/qa.md#workflow-review-pass--fail), step 4, which gives the row rules), one row per AC id above, plus the fixed `shadow-check` row, whose bracketed prompt you replace with `assertions removed: none` or each removed or weakened assertion with its replacement. `verdict` is one of the four tokens the first row's blank lists; `evidence kind` is one of the kinds `kit_qa_evidence_kinds` reads (`scripts/lib/qa-gate.sh`); a `test`/`file:line` pointer is a `path:line` and a short verbatim quote in double quotes, e.g. `src/add.js:12 "return a + b"`, and the other kinds' pointer forms are in that step and `dev/evidence/README.md`. `subtask.sh move <id> qa_complete` refuses the move when the table breaks a rule in `process/contracts/landing-gate.md` § 3. `PASS_AC_CORRECTED` amends a bullet frozen since the card left `todo/`, so it needs a decision citation on that bullet (`process/MANUAL.md` § Execution discipline, item 6). The card is the trunk's: land this section's edit with `./scripts/register-commit.sh`, never on a work branch.

| AC id | verdict | evidence kind | evidence pointer |
|---|---|---|---|
| AC<n> | `<PASS \| PASS_AC_CORRECTED \| FAIL_AC \| FAIL_REGRESSION>` | `<placeholder>` | `<placeholder>` |
| shadow-check | — | — | `<assertions removed: none — or each removed or weakened assertion, with its replacement>` |

## Out of Scope

- What this slice defers to a sibling subtask (name it, e.g. "the mirror path → <PREFIX>-NNN-s2").

## Spec / Plan

- Plan: `dev/plans/YYYY-MM-DD-<PREFIX>-NNN-<slug>.md` § <slice>

## Activity

- YYYY-MM-DD [Orchestrator] Created under <PREFIX>-NNN — decomposition slice M.
