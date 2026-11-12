<!-- KIT-CLASS: KIT — issue template. Two placeholders are STAMPED by the
     initializer: the ISSUE-PREFIX token and the TRUNK token, and this directory is one the
     initializer reaches. **The tokens are described rather than spelled here on purpose** — a
     header that names them literally is rewritten by the very substitution it is explaining, and
     every initialized tree then carried a sentence with no referent.
     Everything else in angle brackets is for the author to fill in — never leave one in a live
     issue. If your initializer has not wired a key, substitute it by hand before first use.
     RULE-COPIES:BEGIN — deliberate copies of the Acceptance Criteria's test-or-justify rule; the self-test holds them.
     key: has a passing test, or a documented justification in progress.md for why it cannot be automated
     copies: .claude/roles/dev.md .claude/workflows/wave-runner.js .claude/workflows/tranche-runner.js
     RULE-COPIES:END -->

<!-- LINKS IN THIS FILE ARE RELATIVE TO WHERE IT LANDS — progress/todo/ — NOT to the directory it
     sits in: a link written for where the template sits is dead in every card. The self-test
     reads this line to know where to resolve from, so keep its shape; the mint strips this block. -->
---
id: <PREFIX>-NNN
type: feature            # feature | spike | chore
#title note: write a " or \ inside the quotes as \" or \\
title: "<one-line summary>"
size: M                  # S (≤1 session) | M (2–4 sessions) | L (split it — scripts/subtask.sh)
prd: PRD-NNN             # or n/a on the lite path (`process/MANUAL.md` § The default path is lite); then fill prd_reason
prd_reason:              # with prd: n/a only — ONE line: why no PRD covers this work
stories: [PRD-NNN-F1-S1] # one or more story IDs from the PRD; [] on the lite path
branch: feature/<PREFIX>-NNN-<slug>
pr: null   # forge PR/MR reference; stays null on the forge-agnostic path
created_at: YYYY-MM-DD
created_by: PM
blocks: []               # other <PREFIX>-NNN this issue blocks
blocked_by: []           # other <PREFIX>-NNN blocking this issue
forks: none              # or a bracketed list [D-NN, ...], one id per fork resolved while working this card
---

# <PREFIX>-NNN — <one-line summary>

> **Status** is the folder this file is in (a folder under `progress/`; `./scripts/move-issue.sh --help` prints them). Move the file with **`./scripts/move-issue.sh`** — never by hand (`process/contracts/board-mover.md`: *"Only the mover moves it"*, and every move is published to the trunk as its own commit). Do not duplicate status into frontmatter.

## References

- **PRD:** [PRD-NNN](../../requirements/PRD-NNN-<slug>.md) — stories <story ids>
- **PROJECT.md:** § <section that gives context>

## Problem

One paragraph: what this issue solves and why it exists. Distilled from the PRD stories above — not a copy-paste of the entire PRD.

## Acceptance Criteria

Copied from the PRD stories listed in frontmatter (or authored here on the lite path); a PRD line that has no id gets its `AC<n>` id as it is copied. Each must be independently verifiable by QA. **This text is frozen once the card leaves `todo/`:** a later change to an AC needs a decision citation on that bullet (`process/MANUAL.md` § Execution discipline, item 6), and a removal is cited too, never silent: on an Activity line naming the AC, or on the bullet kept struck through (`- [ ] ~~AC3 — …~~ [decision: D-NN]`). Every checklist line here is `- [ ] <id> — <text>`, one distinct id per line, the id not followed by `-` and a letter or digit; a line of another shape is never graded and is refused (a bullet struck through completely, recording a removal, excepted). The issue is `dev_complete` only when every AC has a passing test, or a documented justification in `progress.md` for why it cannot be automated (e.g. behavior observable only through the project's declared live/manual gate). For an AC whose deliverable is prose describing code behaviour, *"it is a description"* is not such a justification: each behavioural claim it makes needs a test or a `file:line` QA can check it against ([qa.md § Workflow: review pass / fail](../../.claude/roles/qa.md#workflow-review-pass--fail), step 4). An AC whose prose makes no claim about behaviour is unaffected.

- [ ] AC1 — from <story id>: <statement>
- [ ] AC2 — from <story id>: <statement>
- [ ] AC3 — from <story id>: <statement>

**Every illustrative example inside an AC cites its source or is labelled approximate.** An AC
example is read as the contract, not as decoration — so it either names where the fact came
from (a spec section, a manual page, a measured probe) or says plainly that it is
*illustrative and unverified*.

**Notes deliverable.** If this issue is consumer-visible, its AC list must NAME its notes
deliverable — the release-notes / changelog entries the project keeps — as an AC of its own,
because an AC list is what QA grades and an unnamed deliverable is an ungraded one. If this
issue is **not** consumer-visible (a process doc, a board move, a test-only refactor with no
shipped-surface delta), add an AC stating explicitly that it has no notes deliverable.
**Named, or explicitly dismissed — never absent.**

## Ablation

Filled by Dev, only if this branch's diff touches a path the project's `TEST_GLOBS` (`scripts/config.sh`) declares as a test path — `finish-pr.sh` refuses such a landing if this section is absent or not well formed (a non-empty `Broken:` line and a non-empty `Red line:` line). Not required, and left as-is, when the diff touches no declared test path. If the red line appears only after a build step (a test that reads built output), name that step on the `Broken:` line. The card is the trunk's: land this section's edit with `./scripts/register-commit.sh`, never on a work branch.

Broken: <placeholder>
Red line: <placeholder>

## QA Verdict

Filled by QA at review time ([qa.md § Workflow: review pass / fail](../../.claude/roles/qa.md#workflow-review-pass--fail), step 4, which gives the row rules), one row per AC id above, plus the fixed `shadow-check` row, whose bracketed prompt you replace with `assertions removed: none` or each removed or weakened assertion with its replacement. `verdict` is one of the four tokens the first row's blank lists; `evidence kind` is one of the kinds `kit_qa_evidence_kinds` reads (`scripts/lib/qa-gate.sh`); a `test`/`file:line` pointer is a `path:line` and a short verbatim quote in double quotes, e.g. `src/add.js:12 "return a + b"`, and the other kinds' pointer forms are in that step and `dev/evidence/README.md`. `finish-pr.sh` — and `move-issue.sh <ID> qa_complete` for a card that did not land through it — refuses a PASS landing when the table breaks a rule in `process/contracts/landing-gate.md` § 3. `PASS_AC_CORRECTED` amends a bullet frozen since the card left `todo/`, so it needs a decision citation on that bullet (`process/MANUAL.md` § Execution discipline, item 6). The card is the trunk's: land this section's edit with `./scripts/register-commit.sh`, never on a work branch.

| AC id | verdict | evidence kind | evidence pointer |
|---|---|---|---|
| AC1 | `<PASS \| PASS_AC_CORRECTED \| FAIL_AC \| FAIL_REGRESSION>` | `<placeholder>` | `<placeholder>` |
| AC2 | `<placeholder>` | `<placeholder>` | `<placeholder>` |
| AC3 | `<placeholder>` | `<placeholder>` | `<placeholder>` |
| shadow-check | — | — | `<assertions removed: none — or each removed or weakened assertion, with its replacement>` |

## Out of Scope

What this issue does **not** touch — derived from the PRD's Non-Goals plus anything this issue defers to a follow-up. Telling QA what NOT to flag prevents false-FAIL reviews.

- <out-of-scope item>
- <out-of-scope item>

## Dependencies

- **Code:** <e.g. "blocks <PREFIX>-NNN (<the dependent work>)">
- **Resource:** <e.g. "needs credentials for the project's live gate", "needs a fixture that does not exist yet">

## Spec / Plan

Filled in by Dev. Empty when PM hands off. The card is the trunk's: land this section's edit with `./scripts/register-commit.sh`, never on a work branch.

- Engineering design (from [brainstorming](../../.claude/skills/brainstorming/)): `dev/specs/<date>-<topic>-design.md`
- Plan (from [writing-plans](../../.claude/skills/writing-plans/)): `dev/plans/YYYY-MM-DD-<PREFIX>-NNN-<slug>.md`

## Activity

`./scripts/move-issue.sh` appends a line for you on every move; append one by hand only when a
significant decision is logged elsewhere. Elsewhere is the decision register,
[`requirements/DECISIONS.md`](../../requirements/DECISIONS.md); cite its id as `[decision: D-NN]`. Which
rulings earn an entry is its § *Which decisions live HERE*; *when* is
[`process/MANUAL.md`](../../process/MANUAL.md) § Execution discipline item 6.

**The entry shape is the INDENTED line below, deliberately not a bullet** — it is an example, not
an entry. Copy it out; do not leave it in place as a bullet.

    YYYY-MM-DD [<Role>] <the decision> [decision: D-NN]

- YYYY-MM-DD [PM] Created in `todo/`. PRD-NNN, stories <story ids>.
