<!-- KIT-CLASS: KIT — issue template. Two placeholders are STAMPED by the initializer:
     `<PREFIX>-` → this project's issue prefix, and `<trunk>` → this project's trunk branch
     (default `main`). Everything else in angle brackets is for the author to fill in. 
     NOTE: `<trunk>` is wired in the initializer today; `<PREFIX>` is the key it is
     expected to stamp the same way. If your initializer has not wired a key yet,
     substitute it by hand before first use — never leave an angle bracket in a live issue. -->
---
id: <PREFIX>-NNN
type: feature            # feature | spike | chore
title: <one-line summary>
size: M                  # S (≤1 session) | M (2–4 sessions) | L (split it)
prd: PRD-NNN             # or n/a on the lite path
stories: [PRD-NNN-F1-S1] # one or more story IDs from the PRD; [] on the lite path
branch: feature/<PREFIX>-NNN-<slug>
pr: null   # forge PR/MR reference; stays null on the forge-agnostic path
created_at: YYYY-MM-DD
created_by: PM
blocks: []               # other <PREFIX>-NNN this issue blocks
blocked_by: []           # other <PREFIX>-NNN blocking this issue
---

# <PREFIX>-NNN — <one-line summary>

> **Status** is the folder this file is in (`progress/todo/`, `progress/in_progress/`, `progress/dev_complete/`, `progress/qa_complete/`, `progress/blocked/`). Move the file with **`./scripts/move-issue.sh`** — never by hand (`process/contracts/board-mover.md`: *"Only the mover moves it"*, and every move is published to the trunk as its own commit). Do not duplicate status into frontmatter.

## References

- **PRD:** [PRD-NNN § F1 § S1, S2](../../requirements/PRD-NNN-<slug>.md)
- **PROJECT.md:** § <section that gives context>

## Problem

One paragraph: what this issue solves and why it exists. Distilled from the PRD stories above — not a copy-paste of the entire PRD.

## Acceptance Criteria

Copied from the PRD stories listed in frontmatter (or authored here on the lite path). Each must be independently verifiable by QA. The issue is `dev_complete` only when every AC has a passing test, or a documented justification in `progress.md` for why it cannot be automated (e.g. behavior observable only through the project's declared live/manual gate).

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

- Engineering design (from [brainstorming](../../.claude/skills/brainstorming/)): `docs/specs/<date>-<topic>-design.md`
- Plan (from [writing-plans](../../.claude/skills/writing-plans/)): `docs/plans/<date>-<slug>.md`

## Activity

`./scripts/move-issue.sh` appends a line for you on every move; append one by hand only when a
significant decision is logged elsewhere.

**The entry shapes are the INDENTED BLOCK below, deliberately not bullets.** The board checker
reads the **last `- ` bullet** under this heading and compares the folder it names against the
folder the file is actually in — so an example written as a bullet makes a **freshly minted
issue report false drift on the adopter's very first board check.** Copy a shape out of the
block; do not leave one in place as a bullet.

    YYYY-MM-DD [Dev] Picked up — moved to in_progress via ./scripts/move-issue.sh. Branch: <branch>.
    YYYY-MM-DD [Dev] Ready for review — moved to dev_complete. Branch pushed; gates green.
    YYYY-MM-DD [QA] Review — PASS. Squash-merged into `<trunk>` (finish-pr.sh); moved to qa_complete.

- YYYY-MM-DD [PM] Created in `todo/`. PRD-NNN § F1 § S1, S2.
