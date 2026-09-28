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
title: <one-line summary of this slice>
size: S                  # subtasks should be S (≤1 session); if M+, re-slice
prd: PRD-NNN             # the parent's, unless --prd names another
stories: [PRD-NNN-F1-S1] # the subset of the parent's stories this slice covers
branch: feature/<PREFIX>-NNN-sM-<slug>
pr: null   # forge PR/MR reference; stays null on the forge-agnostic path
created_at: YYYY-MM-DD
created_by: Orchestrator
---

# <PREFIX>-NNN-sM — <one-line summary>

> A **subtask** of `<parent card>`, on the main board. It lives under
> `progress/subtasks/<PREFIX>-NNN/`, in the folder that is its status. The parent advances to
> `qa_complete/` only when every subtask has reached `qa_complete/`; the mover refuses it
> otherwise. Move this card with `scripts/subtask.sh`, not `move-issue.sh`.

## Why this slice exists

One or two sentences: why the parent was decomposed and what boundary this slice owns.
PM does not curate subtasks — this is an implementation-level split, not a scope change.

## Acceptance Criteria (sliced from the parent)

The subset of the parent's AC this slice satisfies. Each independently QA-testable. The
parent's AC set is the **union** of all its subtasks' AC; no AC is dropped or invented here.

- [ ] AC<n> — from <story id> (parent AC<n>): <statement>

## Out of Scope

- What this slice defers to a sibling subtask (name it, e.g. "the mirror path → <PREFIX>-NNN-s2").

## Spec / Plan

- Plan: `dev/plans/YYYY-MM-DD-<PREFIX>-NNN-<slug>.md` § <slice>

## Activity

- YYYY-MM-DD [Orchestrator] Created under <PREFIX>-NNN — decomposition slice M.
