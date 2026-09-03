<!-- KIT-CLASS: KIT — subtask template (the Orchestrator's decomposition slice). Two
     placeholders are STAMPED by the
     initializer: the ISSUE-PREFIX token and the TRUNK token, and this directory is one the
     initializer reaches. **The tokens are described rather than spelled here on purpose** — a
     header that names them literally is rewritten by the very substitution it is explaining, and
     every initialized tree then carried a sentence with no referent.
     Everything else in angle brackets is for the author to fill in — never leave one in a live
     issue. If your initializer has not wired a key, substitute it by hand before first use. -->

<!-- LINKS IN THIS FILE ARE RELATIVE TO WHERE IT LANDS — progress/todo/ — NOT to the directory it
     sits in. A link written for where the template SITS resolves while you read it here and
     is dead in every copy an adopter makes: it passes a link check run in the kit and fails
     the only reader who matters. The self-test reads this line to know where to resolve from,
     so keep its shape. -->
---
id: <PREFIX>-NNN-sM      # parent <PREFIX>-NNN + subtask index; does NOT consume the id stream
type: subtask
parent: <PREFIX>-NNN     # the PM-owned issue this decomposes
title: <one-line summary of this slice>
size: S                  # subtasks should be S (≤1 session); if M+, re-slice
prd: PRD-NNN             # inherited from parent
stories: [PRD-NNN-F1-S1] # the subset of the parent's stories this slice covers
branch: feature/<PREFIX>-NNN-sM-<slug>
pr: null   # forge PR/MR reference; stays null on the forge-agnostic path
created_at: YYYY-MM-DD
created_by: Orchestrator
---

<!-- NO `blocks:` / `blocked_by:` HERE, AND THAT IS A DECISION, NOT AN OVERSIGHT — recorded so it is
     not re-raised. A subtask's ordering is already carried by two things the board can read: the `sM`
     index within its parent, and the `parent:` field itself. A dependency on work OUTSIDE the parent
     belongs on the PARENT, because the parent is the unit the board dispatches and the unit the
     orchestrator's chain check walks; putting it on a slice hides it from the level that acts on it.
     If you find yourself wanting these fields here, the honest reading is usually that the slice is
     not a slice — re-scope it into its own issue, which does carry them. -->

# <PREFIX>-NNN-sM — <one-line summary>

> A **subtask** of [<PREFIX>-NNN](../../../<status>/<PREFIX>-NNN-<slug>.md). It lives under
> `progress/subtasks/<PREFIX>-NNN/<status>/`; its folder is its status. The parent stays on
> the main board and advances to `qa_complete/` only when every subtask reaches
> `qa_complete/`. Move it with `scripts/subtask.sh`, not `move-issue.sh`.

## Why this slice exists

One or two sentences: why the parent was decomposed and what boundary this slice owns.
PM does not curate subtasks — this is an implementation-level split, not a scope change.

## Acceptance Criteria (sliced from the parent)

The subset of the parent's AC this slice satisfies. Each independently QA-testable. The
parent's AC set is the **union** of all its subtasks' AC; no AC is dropped or invented here.

- [ ] AC<n> — from PRD-NNN § F1 § S1 (parent AC<n>): <statement>

## Out of Scope

- What this slice defers to a sibling subtask (name it, e.g. "the mirror path → <PREFIX>-NNN-s2").

## Spec / Plan

- Plan: `dev/plans/YYYY-MM-DD-<PREFIX>-NNN-<slug>.md` § <slice>

## Activity

- YYYY-MM-DD [Orchestrator] Created under <PREFIX>-NNN — decomposition slice M.
