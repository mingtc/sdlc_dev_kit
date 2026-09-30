<!-- KIT-CLASS: KIT — refactor-issue template. Two placeholders are STAMPED by the
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
type: refactor
title: <one-line summary>
target_module: <short identifier for the area being refactored>
refactor_pass: dev/refactor/<YYYY-MM-DD>-<scope>-pass.md
size: M                  # S (≤1 session) | M (2–4 sessions) | L (split it)
prd: n/a                 # usually n/a for refactor; set if scope ties to a specific PRD
prd_reason:              # with prd: n/a — ONE line: why no PRD covers this (required, even when obvious)
stories: []              # usually empty; populate if scope ties to specific stories
branch: refactor/<PREFIX>-NNN-<slug>
pr: null   # forge PR/MR reference; stays null on the forge-agnostic path
created_at: YYYY-MM-DD
created_by: Refactorer
blocks: []               # other <PREFIX>-NNN this issue blocks
blocked_by: []           # other <PREFIX>-NNN blocking this issue
forks: none              # or a list of D-NN, one per fork resolved while working this card
---

# <PREFIX>-NNN — <one-line summary>

> **Status** is the folder this file is in (`progress/todo/`, `progress/in_progress/`, `progress/dev_complete/`, `progress/qa_complete/`, `progress/blocked/`, `progress/done/`, `progress/declined/`). Move the file with **`./scripts/move-issue.sh`** — never by hand (`process/contracts/board-mover.md`: *"Only the mover moves it"*). Do not duplicate status into frontmatter.

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

**Notes deliverable.** If this refactor is consumer-visible — a moved or renamed path an adopter
imports, a changed command, a changed default — its Behaviors Preserved list must NAME its notes
deliverable as an item of its own, because that list is what QA grades and an unnamed deliverable is
an ungraded one. **A refactor is the case most likely to need the explicit dismissal**, and the
issue template names it by name: a test-only refactor with no shipped-surface delta still owes an
item stating that it has no notes deliverable. **Named, or explicitly dismissed — never absent.**

If any behavior is intentionally unconstrained (safety-net-check Phase 3 decided the behavior is incidental and refactor is free to change it), list it separately so Dev and QA know not to defend it:

**Intentionally unconstrained (refactor may change):**

- <e.g. log line format>
- <e.g. internal field ordering in private types>

## Ablation

Filled by Dev, only if this branch's diff touches a path the project's `TEST_GLOBS` (`scripts/config.sh`) declares as a test path — `finish-pr.sh` refuses such a landing if this section is absent or not well formed (a non-empty `Broken:` line and a non-empty `Red line:` line). Not required, and left as-is, when the diff touches no declared test path.

Broken: <placeholder>
Red line: <placeholder>

## QA Verdict

Filled by QA at review time ([qa.md § Workflow: review pass / fail](../../.claude/roles/qa.md#workflow-review-pass--fail), step 4), one row per Behaviors-Preserved id above (read as this template's AC), plus the fixed `shadow-check` row. `evidence kind` is one of `test` · `file:line` · `gate-diff` · `fixture-diff`. `finish-pr.sh` refuses a PASS landing if this table is missing, a row's evidence kind or pointer is empty or still reads `<placeholder>`, any row's verdict is `FAIL_AC` or `FAIL_REGRESSION`, the ids here do not match the Behaviors-Preserved bullets above one for one, or the `shadow-check` row is absent or empty.

| AC id | verdict | evidence kind | evidence pointer |
|---|---|---|---|
| B1 | `<PASS \| PASS_AC_CORRECTED \| FAIL_AC \| FAIL_REGRESSION>` | `<placeholder>` | `<placeholder>` |
| B2 | `<placeholder>` | `<placeholder>` | `<placeholder>` |
| B3 | `<placeholder>` | `<placeholder>` | `<placeholder>` |
| shadow-check | — | — | `assertions removed: none` (or each removed/weakened assertion with its replacement) |

## Move Sequence

The ordered Fowler-style moves from refactor-planning Phase 3. Each move is one commit (or one tight cluster for horizontal sweeps), named for its Fowler primitive.

**Scope:** vertical | horizontal

1. **<Move primitive>** — <one-line description: what it touches>
2. **<Move primitive>** — <one-line description>
3. **<Move primitive>** — <one-line description>

If Dev disagrees with the order or the set, see the Refactor variation guidance in [.claude/roles/dev.md](../../.claude/roles/dev.md#refactor-variation).

## Safety-Net Assessment

The result of safety-net-check for this target. Restated here for Dev's convenience; full detail in the refactor pass doc.

- **Baseline tag:** `refactor-baseline-<UTC instant>` — `git reset --hard <tag>` to undo if needed
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
significant decision is logged elsewhere. Elsewhere is the decision register,
[`requirements/DECISIONS.md`](../../requirements/DECISIONS.md); cite its id as `[decision: D-NN]`.

**The entry shape is the INDENTED line below, deliberately not a bullet** — it is an example, not
an entry. Copy it out; do not leave it in place as a bullet.

    YYYY-MM-DD [<Role>] <the decision> [decision: D-NN]

- YYYY-MM-DD [Refactorer] Created in `todo/`. Refactor pass: `dev/refactor/<file>.md` § Target T<n>.
