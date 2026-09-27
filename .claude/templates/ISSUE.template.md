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
     sits in. A link written for where the template SITS resolves while you read it here and
     is dead in every copy an adopter makes: it passes a link check run in the kit and fails
     the only reader who matters. The self-test reads this line to know where to resolve from,
     so keep its shape IN THE TEMPLATE.
     IT IS GUIDANCE, AND GUIDANCE IS DELETED ONCE THE FILE IS FILLED: this block addresses
     whoever maintains the template, not whoever reads the card. Delete it from the minted card
     along with every other comment — a card is read on every session that touches it, so a line
     that survives here is paid again by every reader, forever. -->
---
id: <PREFIX>-NNN
type: feature            # feature | spike | chore
title: <one-line summary>
size: M                  # S (≤1 session) | M (2–4 sessions) | L (split it — scripts/subtask.sh)
prd: PRD-NNN             # or n/a on the lite path — legal, and then prd_reason is REQUIRED
prd_reason:              # with prd: n/a only — ONE line: why no PRD covers this work
stories: [PRD-NNN-F1-S1] # one or more story IDs from the PRD; [] on the lite path
branch: feature/<PREFIX>-NNN-<slug>
pr: null   # forge PR/MR reference; stays null on the forge-agnostic path
created_at: YYYY-MM-DD
created_by: PM
blocks: []               # other <PREFIX>-NNN this issue blocks
blocked_by: []           # other <PREFIX>-NNN blocking this issue
---

# <PREFIX>-NNN — <one-line summary>

> **Status** is the folder this file is in (`progress/todo/`, `progress/in_progress/`, `progress/dev_complete/`, `progress/qa_complete/`, `progress/blocked/`, `progress/done/`, `progress/declined/`). Move the file with **`./scripts/move-issue.sh`** — never by hand (`process/contracts/board-mover.md`: *"Only the mover moves it"*, and every move is published to the trunk as its own commit). Do not duplicate status into frontmatter.

## References

- **PRD:** [PRD-NNN § F1 § S1, S2](../../requirements/PRD-NNN-<slug>.md)
- **PROJECT.md:** § <section that gives context>

## Problem

One paragraph: what this issue solves and why it exists. Distilled from the PRD stories above — not a copy-paste of the entire PRD.

## Acceptance Criteria

Copied from the PRD stories listed in frontmatter (or authored here on the lite path). Each must be independently verifiable by QA. The issue is `dev_complete` only when every AC has a passing test, or a documented justification in `progress.md` for why it cannot be automated (e.g. behavior observable only through the project's declared live/manual gate). For an AC whose deliverable is prose describing code behaviour, *"it is a description"* is not such a justification: each behavioural claim it makes needs a test or a `file:line` QA can check it against ([qa.md § Workflow: review pass / fail](../../.claude/roles/qa.md#workflow-review-pass--fail), step 4). An AC whose prose makes no claim about behaviour is unaffected.

- [ ] AC1 — from PRD-NNN § F1 § S1: <statement>
- [ ] AC2 — from PRD-NNN § F1 § S1: <statement>
- [ ] AC3 — from PRD-NNN § F1 § S2: <statement>

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

## Out of Scope

What this issue does **not** touch — derived from the PRD's Non-Goals plus anything this issue defers to a follow-up. Telling QA what NOT to flag prevents false-FAIL reviews.

- <out-of-scope item>
- <out-of-scope item>

## Dependencies

- **Code:** <e.g. "blocks <PREFIX>-NNN (<the dependent work>)">
- **Resource:** <e.g. "needs credentials for the project's live gate", "needs a fixture that does not exist yet">

## Spec / Plan

Filled in by Dev. Empty when PM hands off.

- Engineering design (from [brainstorming](../../.claude/skills/brainstorming/)): `dev/specs/<date>-<topic>-design.md`
- Plan (from [writing-plans](../../.claude/skills/writing-plans/)): `dev/plans/YYYY-MM-DD-<PREFIX>-NNN-<slug>.md`

## Activity

`./scripts/move-issue.sh` appends a line for you on every move; append one by hand only when a
significant decision is logged elsewhere.

**"Elsewhere" has one name: the decision register**
([`requirements/DECISIONS.md`](../../requirements/DECISIONS.md)). A ruling made while working this
card is **not durable on this card** — an Activity entry records *this issue*, and a reader asking
*what is currently true* reads the register. So the seat that makes it **promotes it to the register
in the same change**, and the Activity line here cites the id it was given:
`[decision: D-NN]`. Which rulings earn an entry, and the one-question diagnostic that separates a
**fork** (→ the register) from a **fact** (→ amend the PRD), are in
[`process/templates/DECISIONS.skeleton.md`](../../process/templates/DECISIONS.skeleton.md)
§ *Which decisions live HERE*; *when* is
[`process/MANUAL.md`](../../process/MANUAL.md) § Execution discipline item 6.

**The entry shapes are the INDENTED BLOCK below, deliberately not bullets** — the block is
**examples, not entries**, and indenting it is what keeps an author from reading one as a logged
event. *(An earlier wording said a bulleted example makes a freshly minted card report false drift.
Measured 2026-09-03 and superseded: the seed entry below the block is the last bullet either way, and
the shape lines carry an em-dash rather than a transition arrow so the checker treats them as
un-judgeable. The reason to keep them indented is legibility, which is enough.)* Copy a shape out of the block; do not leave one in place as a bullet.

    YYYY-MM-DD [Dev] Picked up — moved to in_progress via ./scripts/move-issue.sh. Branch: <branch>.
    YYYY-MM-DD [Dev] Ready for review — moved to dev_complete. Branch pushed; gates green.
    YYYY-MM-DD [QA] Review — PASS. Squash-merged into `<trunk>` (finish-pr.sh); moved to qa_complete.

- YYYY-MM-DD [PM] Created in `todo/`. PRD-NNN § F1 § S1, S2.
