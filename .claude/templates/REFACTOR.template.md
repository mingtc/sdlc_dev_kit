<!-- KIT-CLASS: KIT — refactor-issue template. Two placeholders are STAMPED by the initializer:
     `<PREFIX>-` → this project's issue prefix, and `<trunk>` → this project's trunk branch
     (default `main`). Everything else in angle brackets is author fill-in. 
     NOTE: `<trunk>` is wired in the initializer today; `<PREFIX>` is the key it is
     expected to stamp the same way. If your initializer has not wired a key yet,
     substitute it by hand before first use — never leave an angle bracket in a live issue. -->
---
id: <PREFIX>-NNN
type: refactor
title: <one-line summary>
target_module: <short identifier for the area being refactored>
refactor_pass: dev/refactor/<YYYY-MM-DD>-<scope>-pass.md
size: M                  # S (≤1 session) | M (2–4 sessions) | L (split it)
prd: n/a                 # usually n/a for refactor; set if scope ties to a specific PRD
stories: []              # usually empty; populate if scope ties to specific stories
branch: refactor/<PREFIX>-NNN-<slug>
pr: null   # forge PR/MR reference; stays null on the forge-agnostic path
created_at: YYYY-MM-DD
created_by: Refactorer
blocks: []               # other <PREFIX>-NNN this issue blocks
blocked_by: []           # other <PREFIX>-NNN blocking this issue
---

# <PREFIX>-NNN — <one-line summary>

> **Status** is the folder this file is in (`progress/todo/`, `progress/in_progress/`, `progress/dev_complete/`, `progress/qa_complete/`, `progress/blocked/`). Move the file with **`./scripts/move-issue.sh`** — never by hand (`process/contracts/board-mover.md`: *"Only the mover moves it"*). Do not duplicate status into frontmatter.

## References

- **Refactor pass:** [dev/refactor/<file>.md](../../dev/refactor/<file>.md) § Target T<n>
- **PROJECT.md:** § <section that gives stack / quality-bar context>

## Target & Goal

One paragraph: what is being refactored and what "better" looks like for this target. This is the *desired shape* from refactor-planning Phase 1, restated here so Dev can read the issue without opening the pass doc.

## Behaviors Preserved

Refactor's equivalent of Acceptance Criteria. The contract Dev must hold: these behaviors continue to work after the refactor lands. Each bullet references the test that exercises it.

- [ ] B1 — <behavior>: verified by `<test file>::<test name>` (existing) or `<test file>::<characterization test name>` (added during safety-net-check)
- [ ] B2 — <behavior>: verified by `<test>`
- [ ] B3 — <behavior>: verified by `<test>`

If any behavior is intentionally unconstrained (safety-net-check Phase 3 decided the behavior is incidental and refactor is free to change it), list it separately so Dev and QA know not to defend it:

**Intentionally unconstrained (refactor may change):**

- <e.g. log line format>
- <e.g. internal field ordering in private types>

## Move Sequence

The ordered Fowler-style moves from refactor-planning Phase 3. Each move is one commit (or one tight cluster for horizontal sweeps), named for its Fowler primitive.

**Scope:** vertical | horizontal

1. **<Move primitive>** — <one-line description: what it touches>
2. **<Move primitive>** — <one-line description>
3. **<Move primitive>** — <one-line description>

If Dev disagrees with the order or the set, see the Refactor variation guidance in [.claude/roles/dev.md](../../.claude/roles/dev.md#refactor-variation).

## Safety-Net Assessment

The result of safety-net-check for this target. Restated here for Dev's convenience; full detail in the refactor pass doc.

- **Baseline tag:** `refactor-baseline-<YYYY-MM-DD>` — `git reset --hard <tag>` to undo if needed
- **Tests covering this target:** see refactor pass doc § Target T<n>
- **Characterization tests added:** `<test name(s)>` — on `<trunk>` as of the baseline tag
- **Verdict:** SAFE TO PROCEED | PROCEED WITH CARVEOUT (see below)

If the verdict was PROCEED WITH CARVEOUT, the carveout scope is described in the refactor pass doc.

## Migration Plan (if applicable)

Only present if the planned moves touch public surface. Restate the migration sequence from migration-planning Phase 3 here, or link to the refactor pass doc if it is substantial.

- <Surface item> — <classification> — <plan summary>

If no public surface changes, delete this section.

## Out of Scope

What this issue does **not** touch. Often easier to list for refactors than for features — "everything outside the target module's blast radius" is the default.

- <out-of-scope item>
- <out-of-scope item>

## Dependencies

- **Code:** <e.g. "blocked by <PREFIX>-NNN (must land first)", "blocks <PREFIX>-NNN (the next target depends on this shape)">
- **Resource:** <e.g. "needs `<tool>` installed for verification — see PROJECT.md">

## Activity

`./scripts/move-issue.sh` appends a line for you on every move; append one by hand only when a
significant decision is logged elsewhere.

**The entry shapes are the INDENTED BLOCK below, deliberately not bullets** — the board checker
reads the **last `- ` bullet** under this heading, so an example written as a bullet makes a
freshly minted issue report false drift.

    YYYY-MM-DD [Dev] Picked up — moved to in_progress via ./scripts/move-issue.sh. Branch: refactor/<PREFIX>-NNN-<slug>.
    YYYY-MM-DD [Dev] Ready for review — moved to dev_complete. Branch pushed; gates green.
    YYYY-MM-DD [QA] Review — PASS. Squash-merged into `<trunk>` (finish-pr.sh); moved to qa_complete.

- YYYY-MM-DD [Refactorer] Created in `todo/`. Refactor pass: `dev/refactor/<file>.md` § Target T<n>.
