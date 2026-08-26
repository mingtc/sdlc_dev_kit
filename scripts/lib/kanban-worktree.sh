#!/usr/bin/env bash
# KIT-CLASS: KIT — the .kanban-wt/ worktree machinery. See process/EXTRACTION.md.
# kanban-worktree.sh — shared machinery for the kanban move scripts.
#
# Sourced by move-issue.sh, finish-pr.sh, subtask.sh and archive.sh. All kanban
# git operations (the `git mv`, the Activity-log append, the commit, the push)
# happen inside a STANDING worktree pinned to the trunk — `.kanban-wt/` at the
# repo root, gitignored — instead of hijacking the operator's main checkout.
#
# The operator's current checkout is NEVER switched. If it happens to be
# sitting on the trunk with a clean tree, it is fast-forwarded after a
# successful op (so the board view stays live); otherwise it is left untouched
# (stale-until-pull, like any git collaboration).
#
# WHY DETACHED: `git worktree add .kanban-wt <trunk>` FAILS when the trunk is
# already checked out in the main worktree (the operator's common board-view
# case): `fatal: '<trunk>' is already used by worktree`. So the kanban worktree
# is created DETACHED (`git worktree add --detach`), landing on the trunk's tip;
# every op fetches+resets to <remote>/<trunk>, commits, and pushes HEAD:<trunk>.
# The local trunk branch ref is advanced separately (never via update-ref on a
# ref that's checked out elsewhere — that would desync that worktree).
#
# DETACH-BY-CONSTRUCTION: `.kanban-wt` has been found ATTACHED to the trunk
# mid-run, cause UNKNOWN — and while attached it blocks the operator's checkout
# from ever holding the trunk again. kwt_bootstrap and kwt_sync both call
# kwt__ensure_detached below, which checks the invariant on every op (repairing a
# clean-tree attach, refusing loudly over a dirty one) instead of assuming it.
# This makes the SYMPTOM impossible or loud; it does NOT claim to know the cause.
#
# PREFLIGHT SNIPPET (copy into any launch pack / orchestration doc that spins
# up parallel legs — now also enforced live by kwt__ensure_detached on every op):
#   git worktree list | grep '\.kanban-wt'
#   # must show:  …/.kanban-wt   <sha>  (detached HEAD)
#   # NOT:         …/.kanban-wt   <sha>  [<trunk>]        <- attached; a kanban
#   #                                                        op will now repair
#   #                                                        or refuse this.
#
# Public API (all operate on the globals exported by kwt_resolve):
#   kwt_resolve            → sets MAIN_ROOT, KWT, KWT_LOCK, DEFAULT_BRANCH
#   kwt_lock               → acquire the mkdir-atomic lock (timeout + liveness-aware
#                            serialized reap of an abandoned lock)
#   kwt_unlock             → release the lock (also armed via trap on EXIT)
#   kwt_bootstrap          → ensure $KWT is a registered detached worktree
#   kwt_sync               → fetch the remote + reset --hard the worktree to the tip;
#                            ABORTS first if the worktree has uncommitted tracked
#                            changes (never silently destroy them) unless
#                            KWT_DISCARD_DIRTY=true
#   kwt_finalize           → push HEAD:<trunk>, then conditionally advance the
#                            operator's checkout / local branch ref
#
# Note: this helper does NOT `set -euo pipefail` itself — the sourcing script
# owns shell options. It uses explicit return codes.

# ---------------------------------------------------------------------------
# Remote name — configurable. Every fetch / push / ls-remote / tracking-ref op
# below goes through $KWT_REMOTE instead of a hardcoded `origin`. Default is
# `origin`, so with the var unset the behavior is byte-identical to before.
# Override for a fork/mirror workflow:
#   KWT_REMOTE=upstream ./scripts/move-issue.sh …
# ---------------------------------------------------------------------------
KWT_REMOTE="${KWT_REMOTE:-origin}"

# ---------------------------------------------------------------------------
# The trunk fallback chain's LAST link, as a named constant rather than a literal
# buried in kwt_resolve — kit-init.sh derives the shipped value from this line to
# rewrite the travelling docs, and the seed self-test reads it instead of
# re-hardcoding a branch name. `main` is git's own modern default, so a kit that
# must guess guesses the least surprising thing.
KWT_TRUNK_LAST_RESORT="${KWT_TRUNK_LAST_RESORT:-main}"

# ---------------------------------------------------------------------------
# The push-race wrapper — one shared definition, sourced rather than
# re-implemented here. kwt_finalize below uses git_push_with_retry instead of a
# single bare push, and git_report_ahead_behind for the looks-pushed check.
# ---------------------------------------------------------------------------
KWT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=push-retry.sh
. "$KWT_LIB_DIR/push-retry.sh"

# ---------------------------------------------------------------------------
# Root + trunk resolution. Works invoked from the main worktree, from a feature
# worktree, or from inside .kanban-wt itself: git-common-dir always points at the
# primary worktree's .git, whose dirname is the main repo root.
#
# THE TRUNK IS RESOLVED IN THREE STEPS, AND EVERY STEP BELOW THE FIRST WARNS.
# The chain is <remote>/HEAD → init.defaultBranch → KWT_TRUNK_LAST_RESORT, and it
# used to be SILENT the whole way down: a fresh repository with no <remote>/HEAD
# got a trunk name nobody had chosen, and found out when the first board move
# pushed to a branch nobody meant. The chain is kept — a hard refusal here would
# break every read-only caller (check-board.sh runs inside the SessionStart hook)
# — but each fallback now says, on stderr, which step it used and how to make the
# question go away. kit-init.sh's `--trunk` confirmation is still the front door:
# it cross-checks the value against <remote>/HEAD and refuses on disagreement, so
# an initialized repository never reaches step 2 at all.
# ---------------------------------------------------------------------------
kwt_resolve() {
  local common_dir
  common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || {
    echo "Error: not inside a git repository." >&2
    return 1
  }
  MAIN_ROOT="$(dirname "$common_dir")"
  KWT="$MAIN_ROOT/.kanban-wt"
  KWT_LOCK="$MAIN_ROOT/.kanban-wt.lock"

  DEFAULT_BRANCH="$(git -C "$MAIN_ROOT" symbolic-ref --short "refs/remotes/$KWT_REMOTE/HEAD" 2>/dev/null | sed "s|^$KWT_REMOTE/||" || true)"
  if [ -z "$DEFAULT_BRANCH" ]; then
    DEFAULT_BRANCH="$(git -C "$MAIN_ROOT" config --get init.defaultBranch 2>/dev/null || true)"
    if [ -n "$DEFAULT_BRANCH" ]; then
      {
        echo "Warning: the trunk was NOT confirmed — $KWT_REMOTE/HEAD is not set, so this op fell"
        echo "         back to STEP 2 of the chain (git config init.defaultBranch) and is treating"
        echo "         '$DEFAULT_BRANCH' as the trunk. If that is wrong, every board move below pushes"
        echo "         to a branch nobody chose. Settle it once:"
        echo "           git remote set-head $KWT_REMOTE <your-trunk>"
      } >&2
    else
      DEFAULT_BRANCH="$KWT_TRUNK_LAST_RESORT"
      {
        echo "Warning: the trunk is a GUESS — neither $KWT_REMOTE/HEAD nor git config"
        echo "         init.defaultBranch is set, so this op fell through to STEP 3 of the chain,"
        echo "         the kit's last-resort literal '$DEFAULT_BRANCH' (KWT_TRUNK_LAST_RESORT in"
        echo "         scripts/lib/kanban-worktree.sh). Nothing here knows your trunk. Fix it before"
        echo "         the next board move:"
        echo "           git remote set-head $KWT_REMOTE <your-trunk>"
        echo "         (or run ./scripts/kit-init.sh --prefix <P> --trunk <your-trunk> on a fresh repo)"
      } >&2
    fi
  fi

  export MAIN_ROOT KWT KWT_LOCK DEFAULT_BRANCH
  return 0
}

# ---------------------------------------------------------------------------
# mkdir-atomic lock. mkdir is atomic on POSIX filesystems — exactly one
# contender wins the create. Poll up to ~30s. A held lock is reaped only when its
# holder is provably gone: same-host + holder PID dead (kill -0) → reap at once;
# cross-host or unknown holder → fall back to the age threshold. The reap is
# SERIALIZED behind a one-winner `mkdir .reap` claim and re-confirmed under it, so
# two racers can never both remove the dead lock, and — because a fresh lock can
# never be created while the dead one occupies the path (mkdir is blocked) — the
# reaper never destroys a live holder's freshly-acquired lock (an earlier
# `rm -rf`/`mv` steal had exactly that race). A LIVE holder is never reaped, so
# finish-pr.sh holding the lock across a slow network merge is safe no matter how
# long the merge takes. On real timeout: clear message + non-zero return, and NO
# half-applied move (we never touched the tree).
# ---------------------------------------------------------------------------
KWT_LOCK_HELD=false
KWT_LOCK_WAIT=30      # seconds to wait for a held lock
KWT_LOCK_STALE=120    # seconds after which a held lock is considered stale
                      # (cross-host / unknown-holder fallback; same-host uses PID liveness)
KWT_REAP_STALE=10     # seconds after which a `.reap` claim dir is considered orphaned
                      # (a reap completes in ms — a survivor means the reaper crashed;
                      #  cleared by the next contender so a leak can't wedge us).

# Portable file-mtime (epoch seconds). BSD stat (`-f %m`, macOS) OR GNU stat
# (`-c %Y`, Linux); 0 if neither works (treated as "very old" → cleanable).
kwt__mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

# Set true by a consumer's --discard-dirty flag to opt back into the old
# destructive `reset --hard` in kwt_sync (otherwise an uncommitted-state worktree
# aborts the sync rather than being silently wiped).
KWT_DISCARD_DIRTY=false

# Echoes "yes" if the CURRENT lock holder is provably abandoned and stealable:
#   - same host + holder PID no longer EXISTS → dead holder; or
#   - cross-host / unknown PID + lock older than the stale threshold.
# A live same-host holder (e.g. finish-pr.sh mid network-merge) is NOT abandoned.
# Liveness uses `kill -0` (same-user) OR `ps -p` (any user) so a different user's
# live process — where `kill -0` gives EPERM, not ESRCH — is NOT mistaken for dead
# and reaped. `|| true` on the seds is load-bearing — under `set -uo pipefail` a
# loser may poll in the window between the winner's mkdir and its `info` write, so
# a missing file must not kill the caller.
kwt__lock_abandoned() {
  local p h e a my
  p="$(sed -n 's/^pid=//p'   "$KWT_LOCK/info" 2>/dev/null | head -1 || true)"
  h="$(sed -n 's/^host=//p'  "$KWT_LOCK/info" 2>/dev/null | head -1 || true)"
  e="$(sed -n 's/^epoch=//p' "$KWT_LOCK/info" 2>/dev/null | head -1 || true)"
  my="$(hostname 2>/dev/null || echo '?')"
  if [ -n "$p" ] && [ -n "$h" ] && [ "$h" = "$my" ]; then
    # Alive if the process EXISTS by either probe; only "truly gone" is abandoned.
    if kill -0 "$p" 2>/dev/null || ps -p "$p" >/dev/null 2>&1; then
      return 0                                # exists (any user) → not abandoned
    fi
    echo yes                                  # truly gone → dead holder
    return 0
  fi
  # cross-host / unknown PID → age fallback. Guard the arithmetic against a
  # non-numeric (corrupt/partially-written) epoch so it can't mis-evaluate.
  if [ -n "$e" ] && [ -z "${e//[0-9]/}" ]; then
    a=$(( $(date +%s) - e ))
    [ "$a" -gt "$KWT_LOCK_STALE" ] && echo yes
  fi
  return 0
}

kwt_lock() {
  local waited=0 myhost tok back
  myhost="$(hostname 2>/dev/null || echo '?')"
  while true; do
    if mkdir "$KWT_LOCK" 2>/dev/null; then
      # Won the create. Stamp who/when + a UNIQUE token for verify-after-acquire.
      tok="$$.$(date +%s).${RANDOM:-0}"
      printf 'pid=%s\nepoch=%s\nhost=%s\ntoken=%s\n' "$$" "$(date +%s)" "$myhost" "$tok" > "$KWT_LOCK/info" 2>/dev/null || true
      # Verify-after-acquire: if a racing stealer wiped + recreated our fresh lock
      # in the gap, the token won't match — do NOT claim ownership (which would
      # double-hold and let our EXIT trap delete the thief's lock); loop instead.
      back="$(sed -n 's/^token=//p' "$KWT_LOCK/info" 2>/dev/null | head -1 || true)"
      if [ "$back" = "$tok" ]; then
        KWT_LOCK_HELD=true
        trap 'kwt_unlock' EXIT
        return 0
      fi
      continue
    fi

    # Lock is held. Steal only if it is provably abandoned. The removal is SERIALIZED
    # behind a one-winner reap claim (`mkdir .reap` is atomic) so two racers can never
    # both remove the dead lock — and, critically, a FRESH lock can never exist while
    # the dead one occupies $KWT_LOCK (mkdir is blocked by its presence), so the sole
    # reaper that RE-confirms abandonment under the claim only ever removes the dead
    # lock, never a live holder's fresh lock. After removal everyone re-contends on the
    # atomic mkdir at the loop top.
    if [ "$(kwt__lock_abandoned)" = "yes" ]; then
      if mkdir "${KWT_LOCK}.reap" 2>/dev/null; then
        # Won the reap claim → re-confirm under the claim and remove the dead lock,
        # then retry the acquire immediately.
        if [ "$(kwt__lock_abandoned)" = "yes" ]; then
          echo "Warning: kanban lock at $KWT_LOCK looked abandoned — reaping it." >&2
          rm -rf "$KWT_LOCK"
        fi
        rmdir "${KWT_LOCK}.reap" 2>/dev/null || rm -rf "${KWT_LOCK}.reap" 2>/dev/null || true
        continue
      fi
      # mkdir .reap FAILED — a reap is in flight (transient) OR a `.reap` was LEAKED
      # by a crashed reaper (permanent, would wedge every future contender).
      # NEVER unconditionally `continue` here (that busy-spins with no sleep/timeout).
      # Clear an ORPHANED claim — one older than KWT_REAP_STALE — then FALL THROUGH to
      # the bounded backoff + timeout below. Removing a still-live reaper's claim is
      # harmless: the reap re-confirms abandonment under the claim and only ever rm's
      # the dead lock (a fresh lock can't exist while the dead one blocks the mkdir).
      if [ -d "${KWT_LOCK}.reap" ]; then
        local reap_age
        reap_age=$(( $(date +%s) - $(kwt__mtime "${KWT_LOCK}.reap") ))
        if [ "$reap_age" -ge "$KWT_REAP_STALE" ]; then
          echo "Warning: orphaned reap claim at ${KWT_LOCK}.reap (${reap_age}s old) — clearing it." >&2
          rm -rf "${KWT_LOCK}.reap" 2>/dev/null || true
        fi
      fi
    fi

    if [ "$waited" -ge "$KWT_LOCK_WAIT" ]; then
      echo "Error: another kanban op holds the lock at $KWT_LOCK" >&2
      echo "       (waited ${KWT_LOCK_WAIT}s). It will clear when that op finishes; retry then." >&2
      echo "       If you are sure no other op is running, remove it: rm -rf '$KWT_LOCK'" >&2
      return 1
    fi
    sleep 1
    waited=$(( waited + 1 ))
  done
}

kwt_unlock() {
  if [ "$KWT_LOCK_HELD" = "true" ]; then
    rm -rf "$KWT_LOCK" 2>/dev/null || true
    KWT_LOCK_HELD=false
  fi
}

# ---------------------------------------------------------------------------
# Bootstrap: ensure $KWT is a registered worktree. Idempotent — a porcelain
# scan of registered worktrees means a second invocation reuses the existing
# tree with no error. Created DETACHED at the trunk's tip.
# ---------------------------------------------------------------------------
kwt_bootstrap() {
  if git -C "$MAIN_ROOT" worktree list --porcelain 2>/dev/null \
       | grep -qxF "worktree $KWT"; then
    kwt__ensure_detached  # detach-by-construction, not assumed.
    return $?
  fi

  # A leftover directory with no registration (e.g. partial create) blocks
  # `worktree add`. Prune dead entries, then if the path still exists un-managed,
  # bail with a clear message rather than clobbering.
  git -C "$MAIN_ROOT" worktree prune 2>/dev/null || true
  if git -C "$MAIN_ROOT" worktree list --porcelain 2>/dev/null \
       | grep -qxF "worktree $KWT"; then
    kwt__ensure_detached
    return $?
  fi
  if [ -e "$KWT" ]; then
    echo "Error: $KWT exists but is not a registered worktree." >&2
    echo "       Remove it (rm -rf '$KWT') and re-run, or register it manually." >&2
    return 1
  fi

  if ! git -C "$MAIN_ROOT" worktree add --detach "$KWT" "$DEFAULT_BRANCH" --quiet 2>/dev/null; then
    # Fallback: the trunk may not exist locally yet; try <remote>/<trunk>.
    if ! git -C "$MAIN_ROOT" worktree add --detach "$KWT" "refs/remotes/$KWT_REMOTE/$DEFAULT_BRANCH" --quiet 2>/dev/null; then
      echo "Error: failed to bootstrap kanban worktree at $KWT." >&2
      echo "       Neither '$DEFAULT_BRANCH' nor '$KWT_REMOTE/$DEFAULT_BRANCH' could be checked out." >&2
      echo "       If the trunk name above is not yours, see the trunk warning earlier in this run." >&2
      return 1
    fi
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Detach-by-construction. The WHY DETACHED block at the top explains the real git
# constraint this exists for: `git worktree add .kanban-wt <trunk>` FAILS while
# the trunk is checked out in the main worktree, so $KWT is always CREATED
# detached. This guards the invariant afterward too — checked (and repaired, or
# refused with a clear message) rather than assumed, because $KWT has been found
# attached mid-run with an unknown cause. THIS FUNCTION DOES NOT CLAIM TO KNOW
# THAT CAUSE — it only makes the symptom impossible or loud.
#
# - Already detached → no-op, return 0.
# - Attached + clean (no uncommitted TRACKED changes) → repair: `git switch
#   --detach` back onto the current commit (no content changes), and SAY what
#   it did.
# - Attached + dirty → REFUSE. Never `git switch --detach` over uncommitted
#   tracked changes — that would silently carry them across a HEAD move on
#   someone else's board worktree. This does not route around kwt_sync's own
#   dirty-tree abort (its `reset --hard` guard, unchanged below); it is a
#   second, earlier refusal for the same reason, not a workaround of it.
# ---------------------------------------------------------------------------
kwt__ensure_detached() {
  local branch
  branch="$(git -C "$KWT" symbolic-ref -q --short HEAD 2>/dev/null || true)"
  if [ -z "$branch" ]; then
    return 0  # already detached
  fi

  local dirty
  dirty="$(git -C "$KWT" status --porcelain --untracked-files=no 2>/dev/null || true)"
  if [ -n "$dirty" ] && [ "$KWT_DISCARD_DIRTY" != "true" ]; then
    {
      echo "Error: the kanban worktree ($KWT) is ATTACHED to '$branch' (not detached) AND holds"
      echo "       uncommitted tracked changes — refusing to repair it while they're there."
      echo "       Worktree: $KWT"
      echo ""
      echo "  Uncommitted changes:"
      echo "$dirty" | sed 's/^/    /'
      echo ""
      echo "  Resolve by hand, then re-run:"
      echo "    • Keep them — commit AND push: git -C '$KWT' add -A && git -C '$KWT' commit -m '…' && git -C '$KWT' push $KWT_REMOTE HEAD:$branch"
      echo "    • Discard them — git -C '$KWT' reset --hard, then re-run (it will detach cleanly)"
      echo "    • Or re-run with --discard-dirty (mirrors kwt_sync's own opt-out)"
    } >&2
    return 1
  fi

  # `git switch --detach` with no target ref detaches HEAD AT THE CURRENT
  # COMMIT — it moves no commits and touches no tracked file, so it is safe
  # even over a dirty tree (KWT_DISCARD_DIRTY only widens who is allowed past
  # the refusal above, not what this command itself does).
  if git -C "$KWT" switch --detach --quiet 2>/dev/null; then
    echo "Repaired: the kanban worktree ($KWT) was attached to '$branch' — detached it (git switch --detach), landing back on the same commit (nothing else changed)." >&2
    return 0
  fi

  echo "Error: the kanban worktree ($KWT) is attached to '$branch' and could not be detached." >&2
  return 1
}

# ---------------------------------------------------------------------------
# Sync: make the detached worktree match <remote>/<trunk>. The remote is the
# source of truth — every op pushes — so reset --hard to the fetched tip is
# correct and discards any local divergence in the worktree (there should be none).
#
# `reset --hard` silently obliterates any uncommitted change to a TRACKED
# file in the worktree (a loose `pr:` edit, a half-applied move). Before resetting
# we therefore REFUSE and abort loudly when such state exists — never auto-destroy.
# `status --porcelain -uno` scopes the check to exactly what reset --hard destroys
# (untracked files survive it, so they are intentionally ignored — and this also
# keeps a stray editor droppings file on a synced mount from blocking every op).
# Opt back into the destructive behaviour with KWT_DISCARD_DIRTY=true (consumers'
# --discard-dirty).
#
# Note: an unpushed local COMMIT is NOT caught here (the tree is clean after a
# commit) — it is reset on the next sync by design; kwt_finalize's push-failure
# message tells the operator to push it first, and check-board.sh's last check
# reports the state before the next op destroys it.
# ---------------------------------------------------------------------------
kwt_sync() {
  # Dirty guard FIRST — it is a purely LOCAL check, so it must run regardless of
  # connectivity. An earlier ordering checked only after a successful fetch, so
  # the offline early-return below silently bypassed the guard and proceeded on a
  # contaminated worktree.
  if [ "$KWT_DISCARD_DIRTY" != "true" ]; then
    local dirty
    dirty="$(git -C "$KWT" status --porcelain --untracked-files=no 2>/dev/null || true)"
    if [ -n "$dirty" ]; then
      {
        echo "Error: the kanban worktree has uncommitted tracked changes — refusing to sync."
        echo "       Syncing would 'git reset --hard $KWT_REMOTE/$DEFAULT_BRANCH' and DESTROY them."
        echo "       Worktree: $KWT"
        echo ""
        echo "  Uncommitted changes:"
        echo "$dirty" | sed 's/^/    /'
        echo ""
        echo "  Resolve one of two ways:"
        echo "    • Keep them — commit AND push (an unpushed commit is reset on the next sync):"
        echo "        git -C '$KWT' add -A && git -C '$KWT' commit -m '…' && git -C '$KWT' push $KWT_REMOTE HEAD:$DEFAULT_BRANCH"
        echo "    • Discard them — re-run the command with --discard-dirty"
        echo "        (or by hand: git -C '$KWT' reset --hard $KWT_REMOTE/$DEFAULT_BRANCH)"
      } >&2
      return 1
    fi
  fi

  # Detach-by-construction, checked again at sync time — the tree is known clean
  # (or KWT_DISCARD_DIRTY opted out of the check) by this point, so this never
  # routes around the dirty-tree abort just above; it only ever repairs a
  # worktree the abort already let through.
  kwt__ensure_detached || return 1

  if ! git -C "$KWT" fetch "$KWT_REMOTE" "$DEFAULT_BRANCH" --quiet 2>/dev/null; then
    echo "Warning: could not fetch $KWT_REMOTE/$DEFAULT_BRANCH (offline?); proceeding with local state." >&2
    return 0
  fi

  git -C "$KWT" reset --hard "$KWT_REMOTE/$DEFAULT_BRANCH" --quiet
  return 0
}

# ---------------------------------------------------------------------------
# Finalize: push the worktree's HEAD to the trunk, then keep the operator's
# view / local branch ref current:
#   - main checked out on the trunk, clean tree → merge --ff-only (moves ref +
#     index + worktree together; the board view stays live).
#   - main checked out on the trunk, dirty tree → leave untouched (stale-until-pull).
#   - the trunk NOT checked out anywhere       → update-ref the local branch to
#     <remote>/<trunk> so it's current when the operator returns to it.
# NEVER update-ref a branch checked out in another worktree (it desyncs that
# worktree's index — makes the operator's checkout look dirty).
# ---------------------------------------------------------------------------
kwt_finalize() {
  # Push the commit just made in the worktree to the trunk — via the shared
  # pull-rebase-retry wrapper rather than a single bare push, so a diverged
  # remote (a parallel landing winning the race) is rebased onto and retried
  # instead of dying silently.
  if ! git_push_with_retry "$KWT" "$KWT_REMOTE" "$DEFAULT_BRANCH"; then
    echo "Error: push of HEAD → $KWT_REMOTE/$DEFAULT_BRANCH failed (remote likely advanced concurrently, or offline)." >&2
    echo "       The commit was made LOCALLY in the kanban worktree but is NOT on $KWT_REMOTE." >&2
    echo "       The NEXT kanban op's sync resets --hard to $KWT_REMOTE/$DEFAULT_BRANCH and will" >&2
    echo "       DISCARD this commit unless you push it first:" >&2
    echo "         git -C '$KWT' fetch $KWT_REMOTE $DEFAULT_BRANCH && git -C '$KWT' rebase $KWT_REMOTE/$DEFAULT_BRANCH" >&2
    echo "         git -C '$KWT' push $KWT_REMOTE HEAD:$DEFAULT_BRANCH" >&2
    return 1
  fi

  local main_head
  main_head="$(git -C "$MAIN_ROOT" symbolic-ref --short HEAD 2>/dev/null || echo "")"

  if [ "$main_head" = "$DEFAULT_BRANCH" ]; then
    # The trunk is checked out in the operator's main worktree.
    if git -C "$MAIN_ROOT" diff --quiet 2>/dev/null && git -C "$MAIN_ROOT" diff --cached --quiet 2>/dev/null; then
      # Clean → fast-forward the live board view.
      git -C "$MAIN_ROOT" fetch "$KWT_REMOTE" "$DEFAULT_BRANCH" --quiet 2>/dev/null || true
      if git -C "$MAIN_ROOT" merge --ff-only "$KWT_REMOTE/$DEFAULT_BRANCH" --quiet 2>/dev/null; then
        echo "Fast-forwarded the main checkout ($DEFAULT_BRANCH) to keep the board view live."
      else
        echo "Note: main checkout could not be fast-forwarded (diverged); pull manually." >&2
      fi
    else
      echo "Note: main checkout is on $DEFAULT_BRANCH with local changes — left untouched (pull when ready)."
    fi
    # The looks-pushed check: this op only pushed the KANBAN WORKTREE's own
    # commit. If the main checkout also carries a hand-made trunk commit of its
    # own, that commit is separate and may still be local — report the actual
    # ahead/behind state so that gap is never silently mistaken for "pushed"
    # just because this op succeeded.
    git_report_ahead_behind "$MAIN_ROOT" "$KWT_REMOTE" "$DEFAULT_BRANCH"
  else
    # The trunk is not checked out in the MAIN worktree — but it may be checked
    # out in a THIRD worktree (the operator's own `.worktrees/<branch>`, a sibling
    # session, …). update-ref on a branch checked out anywhere desyncs that
    # worktree's index (makes it look dirty), so honor the header's promise and
    # scan ALL worktrees first.
    git -C "$MAIN_ROOT" fetch "$KWT_REMOTE" "$DEFAULT_BRANCH" --quiet 2>/dev/null || true
    if git -C "$MAIN_ROOT" worktree list --porcelain 2>/dev/null \
         | grep -qxF "branch refs/heads/$DEFAULT_BRANCH"; then
      echo "Note: $DEFAULT_BRANCH is checked out in another worktree — its local ref left as-is (pull there when ready)." >&2
    else
      git -C "$MAIN_ROOT" update-ref "refs/heads/$DEFAULT_BRANCH" "refs/remotes/$KWT_REMOTE/$DEFAULT_BRANCH" 2>/dev/null || true
    fi
  fi
  return 0
}
