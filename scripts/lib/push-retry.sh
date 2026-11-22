#!/usr/bin/env bash
# KIT-CLASS: KIT — shared push-retry machinery for direct-to-trunk pushes.
# See process/EXTRACTION.md.
#
# git_push_with_retry — fetch + rebase-onto-remote-tip + bounded retry, loud and non-zero on
# failure. A trunk commit that loses a push race to a parallel landing must not die silently
# as an orphaned local commit. The ONE definition: any script that pushes a trunk commit
# sources this rather than re-implementing the loop (kanban-worktree.sh does, for kwt_finalize).
#
# Hard constraints:
#   - NEVER `git pull -q 2>/dev/null`: a diverged pull fails silently. Every fetch, push and
#     rebase below is checked by its own exit code.
#   - A CONFLICTING rebase is aborted, reported and returned non-zero: never resolved, never
#     looped. Silent conflict resolution on the trunk is worse than the race.
#   - Bounded by GIT_PUSH_RETRY_MAX. The final failure NAMES the commits that did not land.
#
# Usage:
#   git_push_with_retry <repo_dir> <remote> <branch> [max_retries]
# Once HEAD is pushed it also pushes the agent records (lib/agent-record.sh), and a record the
# remote refuses never fails the push.
# <repo_dir> is a working tree (or worktree) with the commit(s) already made on <branch>, which
# names both the local and remote branch. Returns 0 once pushed; 1 (reason and unlanded commits
# on stderr) when the bound is exhausted, the initial fetch fails (offline: retrying wastes the
# bound), or a rebase conflicts.
GIT_PUSH_RETRY_MAX="${GIT_PUSH_RETRY_MAX:-5}"   # the bound — override only for tests.

# Every trunk push also carries the agent records (refs/kit-agent/*), never fatally.
# shellcheck source=agent-record.sh
. "$(dirname "${BASH_SOURCE[0]}")/agent-record.sh"

git_push_with_retry() {
  local repo="$1" remote="$2" branch="$3" max="${4:-$GIT_PUSH_RETRY_MAX}"
  local attempt=0 pre_head _unlanded

  pre_head="$(git -C "$repo" rev-parse HEAD 2>/dev/null)" || {
    echo "Error: git_push_with_retry: '$repo' is not a valid git checkout." >&2
    return 1   # return-class: internal
  }

  # Initial fetch: if the remote is flat-out unreachable, no amount of retrying
  # fixes that — fail fast rather than burning the bound on a dead network.
  if ! git -C "$repo" fetch "$remote" "$branch" --quiet; then
    {
      echo "Error: git_push_with_retry: fetch of $remote/$branch failed — remote unreachable or offline."
      echo "       Commits that did NOT land:"
      if _unlanded="$(git -C "$repo" log --oneline "$remote/$branch..HEAD" 2>/dev/null)"; then
        [ -z "$_unlanded" ] || printf '%s\n' "$_unlanded" | sed 's/^/         /'
      else
        echo "         (cannot list: no $remote/$branch ref)"
      fi
    } >&2
    return 1   # return-class: internal
  fi

  while [ "$attempt" -lt "$max" ]; do
    attempt=$(( attempt + 1 ))

    if git -C "$repo" push "$remote" "HEAD:$branch" --quiet 2>/dev/null; then
      echo "git_push_with_retry: pushed HEAD -> $remote/$branch (attempt $attempt/$max)."
      kit_agent_records_push "$repo" "$remote"
      return 0
    fi

    echo "Warning: git_push_with_retry: push to $remote/$branch rejected (attempt $attempt/$max) — remote advanced; fetching + rebasing onto its tip." >&2

    if ! git -C "$repo" fetch "$remote" "$branch" --quiet; then
      echo "Error: git_push_with_retry: re-fetch of $remote/$branch failed mid-retry." >&2
      return 1   # return-class: internal
    fi

    local rb_err rb_unmerged
    if ! rb_err="$(git -C "$repo" rebase "$remote/$branch" --quiet 2>&1)"; then
      rb_unmerged="$(git -C "$repo" diff --name-only --diff-filter=U 2>/dev/null || true)"
      git -C "$repo" rebase --abort >/dev/null 2>&1 || true
      # Read HEAD here, not $pre_head: after an earlier successful rebase, the abort returns
      # HEAD to where THIS attempt began.
      local at_head; at_head="$(git -C "$repo" rev-parse HEAD 2>/dev/null || echo "$pre_head")"
      if [ -n "$rb_unmerged" ]; then
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
      elif grep -q 'Commit-message guard' <<< "$rb_err"; then
        {
          echo "Error: git_push_with_retry: rebase onto $remote/$branch STOPPED with no conflict — stopping."
          echo "       A hook refused a commit being replayed. The guard said:"
          grep -E 'Commit-message guard|Subject:' <<< "$rb_err" | sed 's/^ */         /'
          echo "       The rebase was aborted, so HEAD is back where this attempt started: $at_head."
          echo "       Commits that did NOT land:"
          git -C "$repo" log --oneline "$remote/$branch..$at_head" 2>/dev/null | sed 's/^/         /'
          echo "       Replay them with the escape (it also waives the guard's trailer rule for them), then push:"
          echo "         MSG_OK=1 git -C '$repo' rebase $remote/$branch"
          echo "         git -C '$repo' push $remote HEAD:$branch"
        } >&2
      else
        {
          echo "Error: git_push_with_retry: rebase onto $remote/$branch FAILED with no conflict — stopping."
          echo "       git said:"
          sed 's/^/         /' <<< "$rb_err"
          echo "       The rebase was aborted, so HEAD is back where this attempt started: $at_head."
          echo "       Commits that did NOT land:"
          git -C "$repo" log --oneline "$remote/$branch..$at_head" 2>/dev/null | sed 's/^/         /'
          echo "       Fix what git names, then:"
          echo "         git -C '$repo' rebase $remote/$branch"
          echo "         git -C '$repo' push $remote HEAD:$branch"
        } >&2
      fi
      return 1   # return-class: internal
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
  return 1   # return-class: internal
}

# git__merge_then_push_cmd <dir> <remote> <branch> — prints the command that merges <remote>/<branch> into local
# <branch> and pushes it: in the worktree that holds <branch>, else after switching <dir>'s checkout to it.
git__merge_then_push_cmd() {
  local dir="$1" remote="$2" branch="$3" holder qd qh
  printf -v qd '%q' "$dir"
  holder="$(git -C "$dir" worktree list --porcelain 2>/dev/null | awk -v b="refs/heads/$branch" '/^worktree /{p=substr($0,10)} $0 == "branch " b {print p; exit}')"
  if [ -n "$holder" ]; then
    printf -v qh '%q' "$holder"
    printf '%s' "git -C $qh merge $remote/$branch && git -C $qh push $remote $branch"
  else
    printf '%s' "git -C $qd switch $branch && git -C $qd merge $remote/$branch && git -C $qd push $remote $branch"
  fi
}

# git_report_ahead_behind <dir> <remote> <branch> — the "looks-pushed" check. A board move
# pushes its own commit via the kanban worktree; a hand-made trunk commit in the OPERATOR'S
# checkout stays local and looks pushed. Reports <dir>'s ahead/behind against <remote>/<branch>.
# Read-only: fetches, never resets or pushes.
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
  if [ "${ahead:-0}" != "0" ] && [ "${behind:-0}" != "0" ]; then
    echo "Warning: '$dir' local $branch is ${ahead} commit(s) AHEAD of $remote/$branch and NOT pushed, and ${behind} BEHIND it (the looks-pushed check)." >&2
    echo "         A plain push is rejected; merge first, then push: $(git__merge_then_push_cmd "$dir" "$remote" "$branch")" >&2
  elif [ "${ahead:-0}" != "0" ]; then
    echo "Warning: '$dir' local $branch is ${ahead} commit(s) AHEAD of $remote/$branch and NOT pushed (the looks-pushed check)." >&2
    echo "         Push it: git -C '$dir' push $remote $branch" >&2
  else
    # Names the tree it read: an all-clear without a subject reads as a global clearance.
    echo "Ahead/behind $remote/$branch in '$dir': ahead=${ahead:-0} behind=${behind:-0} — nothing local left unpushed THERE." >&2
  fi
}

# git_refuse_unpublished_trunk <dir> <remote> <branch> — the same question as the check above, asked
# BEFORE a landing: refuses (kit_refuse, status 1) while local <branch> holds commits <remote>/<branch>
# lacks, because the landing goes on the remote's tip beside them and local <branch> then cannot follow
# it. `trunk-ahead` when the remote holds nothing local lacks, `trunk-diverged` when it holds some.
# Compares the two REFS in <dir> after a fetch, never <dir>'s checked-out HEAD, so it reads the same
# wherever <branch> is checked out. A diverged Next: runs the merge in the worktree that holds <branch>;
# where none does, it switches <dir>'s checkout to <branch> first (git refuses if that would lose edits). Offline it reads the last fetched ref and says so. Behind-only and
# equal return 0, as does a repository with no local <branch> or no <remote>/<branch> to compare.
# Changes nothing. Needs lib/refuse.sh loaded (kanban-worktree.sh sources it).
git_refuse_unpublished_trunk() {
  local dir="$1" remote="$2" branch="$3" stale="" counts behind ahead fix qd
  GIT_TERMINAL_PROMPT=0 git -C "$dir" fetch "$remote" "$branch" --quiet 2>/dev/null \
    || stale=" (read from the last fetch: the fetch of $remote/$branch failed)"
  counts="$(git -C "$dir" rev-list --left-right --count "refs/remotes/$remote/$branch...refs/heads/$branch" 2>/dev/null)" || return 0
  behind="${counts%%[[:space:]]*}"
  ahead="${counts##*[[:space:]]}"
  [ "${ahead:-0}" -gt 0 ] || return 0
  local unpushed; unpushed="$(git -C "$dir" log --format='         %h %s' -n 5 "refs/remotes/$remote/$branch..refs/heads/$branch" 2>/dev/null)" || unpushed=""
  printf -v qd '%q' "$dir"
  if [ "${behind:-0}" -eq 0 ]; then
    kit_refuse 1 trunk-ahead \
      "Error: local '$branch' is $ahead commit(s) ahead of $remote/$branch and not pushed$stale. A landing now goes on $remote/$branch's tip beside them: a second history, and local '$branch' then diverges from it. Nothing was changed." \
      "       Unpushed, newest first, up to 5:" \
      "$unpushed" \
      "Next: push them, then run the same command again:  git -C $qd push $remote $branch"
  fi
  fix="$(git__merge_then_push_cmd "$dir" "$remote" "$branch")"
  kit_refuse 1 trunk-diverged \
    "Error: local '$branch' has $ahead commit(s) $remote/$branch lacks, and $remote/$branch has $behind that local '$branch' lacks$stale. A landing now goes on $remote/$branch's tip and cannot be fast-forwarded into local '$branch'. Nothing was changed." \
    "       Unpushed, newest first, up to 5:" \
    "$unpushed" \
    "Next: merge $remote/$branch into local '$branch', push, then run the same command again:  $fix"
}
