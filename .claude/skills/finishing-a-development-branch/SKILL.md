---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to end the work - guides completion by presenting structured options for handing off, preserving, or discarding the branch
---

# Finishing a Development Branch

## Overview

Guide completion of development work by presenting clear options and handling chosen workflow.

**Core principle:** Verify tests → Detect environment → Present options → Execute choice → Clean up.

## What this skill does NOT do: land the work

**Ending a branch and LANDING it are two different acts here, and only one of them is yours.**
A code landing goes through the project's landing script (`./scripts/finish-pr.sh`), run by **QA**,
which squash-merges, deletes the branch and advances the issue as one transaction. This skill takes
the work to the point where QA can land it, and stops.

**So there is no "merge it locally" option, and its absence is deliberate.** A local merge into the
base branch has no correct form under that law: it bypasses the landing script, the board move and
QA attribution, and it produces a trunk nobody reviewed. It would also now simply fail — the landing
script refuses a gate checkout that is not at the revision being landed, so a self-merged branch
strands the work *and* cannot be landed afterwards. Reworded, that option is still wrong; it is
removed.

**Forge PRs are not the handoff either.** The handoff is a **pushed branch** plus the issue moved to
the reviewed-ready column — pure git, no forge CLI. If your project has added the optional forge
flavor, its adapter says so and names the command; absent that, do not create a PR.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## The Process

### Step 1: Verify Tests

**Before presenting options, verify tests pass:**

```bash
# Run the project's declared test/gate command — the adapter names it
<the project's test command>
```

**If tests fail:**
```
Tests failing (<N> failures). Must fix before completing:

[Show failures]

Cannot hand off until tests pass.
```

Stop. Don't proceed to Step 2.

**If tests pass:** Continue to Step 2.

### Step 2: Detect Environment

**Determine workspace state before presenting options:**

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
```

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| `GIT_DIR == GIT_COMMON` (normal repo) | The 3 options | No worktree to clean up |
| `GIT_DIR != GIT_COMMON`, named branch | The 3 options | Provenance-based (see Step 6) |
| `GIT_DIR != GIT_COMMON`, detached HEAD | The 3 options, push names a new branch | No cleanup (externally managed) |

### Step 3: Confirm the Trunk

The branch is landed onto the project's trunk, which the adapter names. Confirm it rather than
guessing between `main` and `master`:

```bash
# The board's chain, abbreviated: <remote>/HEAD, then init.defaultBranch.
# Test the value, not the exit status: a pipeline ending in sed exits 0.
trunk="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')"
[ -n "$trunk" ] || trunk="$(git config --get init.defaultBranch 2>/dev/null || true)"
[ -n "$trunk" ] || echo "Trunk unresolved — ask, or run: git remote set-head origin <trunk>" >&2
echo "$trunk"
```

You need it only to report what the work will land onto — this skill never merges into it.

### Step 4: Present Options

**Present exactly these 3 options:**

```
Implementation complete. What would you like to do?

1. Push the branch and hand off for review  (the normal ending)
2. Keep the branch as-is (I'll handle it later)
3. Discard this work

Which option?
```

**On a detached HEAD**, option 1 needs a branch name — ask for one, or offer the issue-derived
`feature/<ID>-<slug>`.

**Don't add explanation** — keep options concise. Option 1 is the normal ending and may be named as
such, which is the one word of guidance worth spending: an agent choosing between three neutral
options will otherwise pick the one that sounds tidiest, and "discard" often sounds tidy.

### Step 5: Execute Choice

#### Option 1: Push the Branch and Hand Off

```bash
git push -u origin <feature-branch>
```

Then **advance the work item to the reviewed-ready column using the board's own mover** — never by
hand, and never by editing a status field inside the item.

**The command lives in the role doc, not here** (`.claude/roles/dev.md`, the step that follows
"finish the branch"). It is not reprinted in this skill on purpose: that step also carries the
footgun that goes with it — the move must NOT be preceded by a branch switch, because the mover
re-derives the move inside the standing kanban worktree and a loose edit to your own checkout is left
STRANDED at a path the trunk has since renamed. (Not destroyed — the mover never touches your
checkout; see `process/MANUAL.md` § The kanban worktree.) A copy of the command here would be a
second authoring site, and the copy that drifts is the one without the warning.

**Do NOT clean up the worktree, and do NOT delete the branch.** Both are needed after this point:
the reviewer lands from the branch, and the landing script's gate must run against a checkout that
is **at the revision being landed** — a worktree still sitting on the branch is exactly that. Tear
it down after the work has landed, not before (see the orphaned-worktree note under Common
Mistakes).

**No forge PR.** The handoff is the pushed branch plus the board move. If the project's adapter
declares the optional forge flavor, it names the command; otherwise creating a PR splits the review
record across two places, and the one the process reads is the item's own activity log.

#### Option 2: Keep As-Is

Report: "Keeping branch <name>. Worktree preserved at <path>."

**Don't cleanup worktree.**

#### Option 3: Discard

**Confirm first:**
```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for exact confirmation.

If confirmed:
```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
```

Then: Cleanup worktree (Step 6), then force-delete branch:
```bash
git branch -D <feature-branch>
```

### Step 6: Cleanup Workspace

**Only runs for Option 3 (Discard).** Options 1 and 2 always preserve the worktree — option 1
because the reviewer needs the branch checked out to land it, option 2 because the work is not
finished.

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

**If `GIT_DIR == GIT_COMMON`:** Normal repo, no worktree to clean up. Done.

**If worktree path is under `.worktrees/`, `worktrees/`, `~/.config/superpowers/worktrees/`, or the worktree directory your instructions declare:** these are the locations `using-git-worktrees` creates or adopts — the skills own this worktree, so they own the cleanup. (That third path is an external tool's; `using-git-worktrees` § Directory Selection says why it is spelled that way.)

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
git worktree remove "$WORKTREE_PATH"
git worktree prune  # Self-healing: clean up any stale registrations
```

**Otherwise:** The host environment (harness) owns this workspace. Do NOT remove it. If your platform provides a workspace-exit tool, use it. Otherwise, leave the workspace in place.

## Quick Reference

| Option | Push | Board move | Keep Worktree | Delete Branch |
|--------|------|-----------|---------------|---------------|
| 1. Push + hand off | yes | yes | yes | no — the reviewer lands from it |
| 2. Keep as-is | - | - | yes | - |
| 3. Discard | - | - | - | yes (force) |

**No row merges.** Landing is the reviewer's act, through the project's landing script.

## Common Mistakes

**Skipping test verification**
- **Problem:** Hand off broken code
- **Fix:** Always verify tests before offering options

**Open-ended questions**
- **Problem:** "What should I do next?" is ambiguous
- **Fix:** Present exactly the 3 structured options

**Merging into the trunk yourself**
- **Problem:** Bypasses the landing script, the board move and the reviewer's attribution — and the
  landing script will then refuse, because the gate checkout is no longer at the revision being
  landed. The work is stranded and unlandable in one move.
- **Fix:** Option 1. Push, move the item, stop.

**Cleaning up the worktree after handing off**
- **Problem:** Removes the checkout the reviewer's gate needs to run at the landed revision
- **Fix:** Only cleanup for Option 3, and tear a handed-off worktree down only once the work has
  actually landed

**Deleting branch before removing worktree**
- **Problem:** `git branch -d` fails because worktree still references the branch
- **Fix:** Remove the worktree first, then delete the branch (Option 3's order)

**Running git worktree remove from inside the worktree**
- **Problem:** Command fails silently when CWD is inside the worktree being removed
- **Fix:** Always `cd` to main repo root before `git worktree remove`

**Cleaning up harness-owned worktrees**
- **Problem:** Removing a worktree the harness created causes phantom state
- **Fix:** Only clean up worktrees under `.worktrees/`, `worktrees/`, `~/.config/superpowers/worktrees/`, or the worktree directory your instructions declare

**Orphaned worktree after the work lands**
- **Problem:** Option 1 — and the project's landing script — deliberately preserve the worktree, and Step 6 cleanup only runs for Option 3. Once the work actually **lands**, nothing tears the worktree down → an empty `.worktrees/<branch>` lingers indefinitely (the lingering-worktree class).
- **Fix:** After the work handed off via Option 1 has **landed**, return and tear it down: `cd` to the main repo root, then `git worktree remove <path>` + `git worktree prune`. (Orchestrator runs: this is the "Worktrees for merged work cleaned up" line in that role's session-end checklist.)

**No confirmation for discard**
- **Problem:** Accidentally delete work
- **Fix:** Require typed "discard" confirmation

## Red Flags

**Never:**
- Proceed with failing tests
- Merge the branch into the trunk yourself — landing is the reviewer's act, via the project's landing script
- Create a forge PR unless the project's adapter declares the forge flavor
- Delete work without confirmation
- Force-push without explicit request
- Remove a worktree before confirming merge success
- Clean up worktrees you didn't create (provenance check)
- Run `git worktree remove` from inside the worktree

**Always:**
- Verify tests before offering options
- Detect environment before presenting menu
- Present exactly the 3 options
- Move the work item through the board's mover when you hand off (Option 1)
- Get typed confirmation for Option 3
- Clean up worktree for Option 3 only
- `cd` to main repo root before worktree removal
- Run `git worktree prune` after removal
