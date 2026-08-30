<!-- KIT-CLASS: KIT — subtask template (the Orchestrator's decomposition slice). Two
     placeholders are STAMPED by the initializer: `<PREFIX>-` → this project's issue prefix,
     and `<trunk>` → this project's trunk branch (default `main`). 
     NOTE: the initializer stamps BOTH `<trunk>` and `<PREFIX>` in this directory today.
     If your initializer has not wired a key yet, substitute it by hand before first
     use — never leave an angle bracket in a live issue. -->
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
