#!/usr/bin/env bash
# KIT-CLASS: KIT — the ONE reader that turns a card's `branch:` value into a revision.
# See process/EXTRACTION.md.
#
# subtask.sh and move-issue.sh (the forks: / QA / Ablation checks at hand-off), kit-upgrade.sh
# (the re-check of open cards) and finish-pr.sh (the landing) all resolve the branch through
# kit_card_branch_rev, so they can never disagree about which code a card's checks read. A
# script that resolves a card's branch another way is a second reader.
#
# kit_card_branch_rev <repo> <branch> [<remote>]
#   Prints the ref holding the branch's tip and returns 0, or prints nothing and returns 1.
#   Order: the local branch first (it is what finish-pr.sh lands), then a remote-tracking ref —
#   <remote>'s alone when <remote> is given, else the first remote that has it. A <remote> of `-`
#   names none: the local branch alone, for a caller that lands or deletes the branch itself.
#   An empty branch, `n/a` and `null` are not branches. The ref must name a commit.
kit_card_branch_rev() {
  local repo="$1" branch="$2" remote="${3:-}" r
  case "$branch" in ''|n/a|null) return 1 ;; esac   # return-class: predicate
  if [ "$remote" = - ]; then
    set -- "refs/heads/$branch"
  elif [ -n "$remote" ]; then
    set -- "refs/heads/$branch" "refs/remotes/$remote/$branch"
  else
    set -- "refs/heads/$branch" $(git -C "$repo" for-each-ref --format='%(refname)' "refs/remotes/*/$branch" 2>/dev/null)
  fi
  for r in "$@"; do
    git -C "$repo" rev-parse --verify -q "$r^{commit}" >/dev/null 2>&1 && { printf '%s' "$r"; return 0; }
  done
  return 1   # return-class: predicate
}
