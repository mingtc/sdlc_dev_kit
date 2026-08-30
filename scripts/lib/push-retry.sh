#!/usr/bin/env bash
# KIT-CLASS: KIT — shared push-retry machinery for direct-to-trunk pushes.
# See process/EXTRACTION.md.
#
# git_push_with_retry — fetch + rebase-onto-remote-tip + bounded retry, loud and
# non-zero on failure. Built for a measured push race: a worker's hand-made trunk
# commit (a progress.md/handoff append direct to the trunk, or the .kanban-wt
# board-move commit) can lose a push race against a parallel landing and — with a
# plain `git push`, no retry — die silently, its content surviving only in an
# orphaned local commit. That cost one project a graft weeks later, which is why
# this exists as machinery rather than as advice.
#
# This is the ONE definition — source this file from any script that pushes a
# trunk commit (kanban-worktree.sh sources it for kwt_finalize; any other
# worker-invoked script that commits direct to the trunk should source it too)
# rather than re-implementing the retry loop.
#
# Hard constraints:
#   - NEVER `git pull -q 2>/dev/null`. The recorded lesson is explicit: a
#     diverged pull fails silently. Every fetch/push/rebase below is checked by
#     its own exit code; nothing is swallowed.
#   - A rebase that CONFLICTS does not resolve anything and does not loop: it
#     aborts the rebase (restoring the pre-attempt HEAD), reports what a human
#     must do, and returns non-zero. Silent conflict resolution on the trunk is
#     worse than the race it would "fix".
#   - Bounded retries — the bound is GIT_PUSH_RETRY_MAX below, stated in code,
#     not tribal knowledge. The final failure NAMES the commits that did not
#     land (`git log <remote>/<branch>..HEAD`) so they are reported, not
#     discovered by grafting weeks later.
#
# Usage:
#   git_push_with_retry <repo_dir> <remote> <branch> [max_retries]
# <repo_dir> is a working tree (or worktree) checked out with the commit(s) to
# land already made locally on <branch>; <branch> is both the local and remote
# branch name. Returns 0 once pushed; returns 1 (with the reason and the unlanded
# commits printed to stderr) once the bound is exhausted, the initial fetch fails
# outright (offline / remote unreachable — retrying a network that isn't there
# wastes the bound), or a rebase conflicts.
GIT_PUSH_RETRY_MAX="${GIT_PUSH_RETRY_MAX:-5}"   # the bound — override only for tests.

git_push_with_retry() {
  local repo="$1" remote="$2" branch="$3" max="${4:-$GIT_PUSH_RETRY_MAX}"
  local attempt=0 pre_head

  pre_head="$(git -C "$repo" rev-parse HEAD 2>/dev/null)" || {
    echo "Error: git_push_with_retry: '$repo' is not a valid git checkout." >&2
    return 1
  }

  # Initial fetch: if the remote is flat-out unreachable, no amount of retrying
  # fixes that — fail fast rather than burning the bound on a dead network.
  if ! git -C "$repo" fetch "$remote" "$branch" --quiet; then
    echo "Error: git_push_with_retry: fetch of $remote/$branch failed — remote unreachable or offline." >&2
    return 1
  fi

  while [ "$attempt" -lt "$max" ]; do
    attempt=$(( attempt + 1 ))

    if git -C "$repo" push "$remote" "HEAD:$branch" --quiet 2>/dev/null; then
      echo "git_push_with_retry: pushed HEAD -> $remote/$branch (attempt $attempt/$max)."
      return 0
    fi

    echo "Warning: git_push_with_retry: push to $remote/$branch rejected (attempt $attempt/$max) — remote advanced; fetching + rebasing onto its tip." >&2

    if ! git -C "$repo" fetch "$remote" "$branch" --quiet; then
      echo "Error: git_push_with_retry: re-fetch of $remote/$branch failed mid-retry." >&2
      return 1
    fi

    if ! git -C "$repo" rebase "$remote/$branch" --quiet 2>/dev/null; then
      git -C "$repo" rebase --abort >/dev/null 2>&1 || true
      # READ HEAD HERE, do not report the capture from before the loop. $pre_head is
      # taken once at entry; if an earlier attempt's rebase SUCCEEDED and a later one
      # conflicts, the abort returns HEAD to where THIS attempt began — not to
      # $pre_head — and the message named a sha HEAD is no longer at. The list below
      # is keyed on the same ref as the sentence above it, so the two cannot disagree.
      local at_head; at_head="$(git -C "$repo" rev-parse HEAD 2>/dev/null || echo "$pre_head")"
      {
        echo "Error: git_push_with_retry: rebase onto $remote/$branch CONFLICTED — stopping."
        echo "       This does NOT resolve the conflict and does NOT loop. The rebase was"
        echo "       aborted, so HEAD is back where this attempt started: $at_head."
        echo "       Commits that did NOT land:"
        git -C "$repo" log --oneline "$remote/$branch..$at_head" 2>/dev/null | sed 's/^/         /'
        echo "       A human must resolve by hand:"
        echo "         git -C '$repo' rebase $remote/$branch   # fix conflicts, git rebase --continue"
        echo "         git -C '$repo' push $remote HEAD:$branch"
      } >&2
      return 1
    fi
    # Rebase succeeded (or was a no-op) — loop back and retry the push.
  done

  {
    echo "Error: git_push_with_retry: exhausted $max attempts pushing to $remote/$branch."
    echo "       Commits that did NOT land:"
    git -C "$repo" log --oneline "$remote/$branch..HEAD" 2>/dev/null | sed 's/^/         /'
    echo "       Push by hand after resolving whatever kept losing the race:"
    echo "         git -C '$repo' push $remote HEAD:$branch"
  } >&2
  return 1
}

# git_report_ahead_behind <dir> <remote> <branch> — the "looks-pushed" check,
# encoded rather than remembered. move-issue.sh / finish-pr.sh push THEIR OWN
# board/squash commit via the kanban worktree; a hand-made trunk commit made
# separately in the OPERATOR'S main checkout stays local, so a leg that did both
# looks pushed once the board move succeeds. This reports the actual ahead/behind
# state of <dir>'s checked-out <branch> vs <remote>/<branch> so that gap cannot go
# unnoticed. Read-only: fetches, never resets or pushes.
git_report_ahead_behind() {
  local dir="$1" remote="$2" branch="$3"
  git -C "$dir" fetch "$remote" "$branch" --quiet 2>/dev/null || {
    echo "Note: git_report_ahead_behind: could not fetch $remote/$branch (offline?) — ahead/behind unknown." >&2
    return 0
  }
  local counts ahead behind
  counts="$(git -C "$dir" rev-list --left-right --count "$remote/$branch...$branch" 2>/dev/null)" || return 0
  behind="$(printf '%s' "$counts" | awk '{print $1}')"
  ahead="$(printf '%s' "$counts" | awk '{print $2}')"
  if [ "${ahead:-0}" != "0" ]; then
    echo "Warning: '$dir' local $branch is ${ahead} commit(s) AHEAD of $remote/$branch and NOT pushed (the looks-pushed check)." >&2
    echo "         Push it: git -C '$dir' push $remote $branch" >&2
  else
    # NAMES THE TREE IT READ, exactly as the warning branch above does. This
    # branch used to print "nothing local left unpushed" with no subject, so a
    # statement about ONE checkout read as a global clearance — and it was
    # measured doing that beside a commit made in a DIFFERENT worktree that had
    # not landed. The complaint was specific and the all-clear was vague, and an
    # instrument specific in failure and vague in success errs only ever toward
    # false confidence, because the vague half is where a reader stops.
    echo "Ahead/behind $remote/$branch in '$dir': ahead=${ahead:-0} behind=${behind:-0} — nothing local left unpushed THERE." >&2
  fi
}
