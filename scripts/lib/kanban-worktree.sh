#!/usr/bin/env bash
# KIT-CLASS: KIT — the .kanban-wt/ worktree machinery. See process/EXTRACTION.md.
#
# WHAT THIS DIRECTORY IS FOR, AND WHAT IT IS NOT. It is FOR BOARD FILES. It is the only
# checkout on the trunk while the main one is on a work branch, which makes it read as a
# spare clean tree — and it is not one. Its HEAD IS the trunk and its push target IS the
# trunk, so anything present here is one ordinary commit away from the trunk with no branch
# and no landing gate in between. Do not build here, do not materialise files here, do not
# `git checkout <ref> -- .` into here, and do not run a blanket `git add -A` here.
#
# This is stated because its ABSENCE cost a project its trunk: a commit made in this
# directory replaced a project README with a generated distribution page and added four
# release artifacts to the trunk. Note the route the guards below CANNOT close —
# `git checkout <ref> -- .` stages its payload, so a plain `git commit -m` carries it and no
# guard is ever consulted. See process/contracts/kanban-worktree.md § 1.
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
#                            ABORTS first if the worktree holds uncommitted tracked
#                            changes (unless KWT_DISCARD_DIRTY=true) or any commit
#                            not yet on <remote>/<trunk> (no opt-out — see below).
#                            Reports what it did in KWT_SYNCED.
#   kwt_finalize           → push HEAD:<trunk>, then conditionally advance the
#                            operator's checkout / local branch ref
#
# Note: this helper does NOT `set -euo pipefail` itself — the sourcing script
# owns shell options. It uses explicit return codes.
#
# CALLER CONTRACT — THE LOAD REFUSAL'S TEETH ARE YOURS, NOT OURS. The push-helper
# load below REFUSES (returns non-zero, loudly) rather than continuing with
# git_push_with_retry undefined. That refusal only STOPS a caller that runs
# `set -e` or checks the source's status: every current caller
# (move-issue.sh, finish-pr.sh, subtask.sh, archive.sh) runs `set -euo pipefail`
# and source this file as a bare simple command, so they abort. A caller that
# does neither gets the message and keeps going with the functions missing —
# which is the original outage one level up. So: check the status of your
# `. lib/kanban-worktree.sh`, or run `set -e`. (config.sh's own load sites are
# the shape to copy — `grep -rn '! \. "$CONFIG"' scripts` — each checking at
# the call site.)

# ---------------------------------------------------------------------------
# Remote name — configurable. Every fetch / push / ls-remote / tracking-ref op
# below goes through $KWT_REMOTE instead of a hardcoded `origin`. Default is
# `origin`, so with the var unset the behavior is byte-identical to before.
# Override for a fork/mirror workflow:
#   KWT_REMOTE=upstream ./scripts/move-issue.sh …
# ---------------------------------------------------------------------------
# THE PUBLICATION REMOTE, and since 2026-09-02 it governs EVERY kit operation rather
# than only the board ones: the mover, the archive sweep, the subtask mover, the PR
# landing, the drift report, the initializer — and the RELEASE push, which used to read
# its own RELEASE_REMOTE and therefore sent releases to origin while a fork's board went
# elsewhere. contracts/config-seam.md names the publication remote as a value requiring
# exactly ONE authoritative definition; this is it.
#
# IT IS A REMOTE NAME, NOT A URL. The machinery below reads refs/remotes/$KWT_REMOTE/HEAD
# to resolve the trunk, and a URL there fails that resolution silently and falls through
# to KWT_TRUNK_LAST_RESORT. release.sh's RELEASE_REMOTE override may be a URL; this may
# not. The prefix is now narrower than what the value means — renaming it would silently
# ignore every current setter, so it stays and this paragraph carries the meaning.
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
#
# `${BASH_SOURCE[0]:-$0}`, NEVER a bare `${BASH_SOURCE[0]}`. BASH_SOURCE is
# bash's; in any other shell it is unset, `dirname ""` is `.`, and this line then
# resolves SILENTLY to the CURRENT WORKING DIRECTORY instead of this file's
# directory — so the source below looked for push-retry.sh in $PWD and failed on
# every load while the helper sat next to this file the whole time. Measured on
# an adopter 2026-08-26 and reported as a MISSING FILE; the file was never
# missing. `process/contracts/config-seam.md` § 2 names the class: "a silent
# fallback to somebody else's default is the failure mode with the longest delay
# between cause and symptom". The `:-$0` form is the kit's own idiom for this —
# derive the current sites with
#   grep -rn 'BASH_SOURCE\[0\]:-\$0' scripts
# rather than trusting a number written here — and it resolves correctly under
# both shells, including when this file is sourced from inside a function.
#
# THE SOURCE IS CHECKED, AND ITS FAILURE REFUSES. It used to be an unguarded `.`
# whose failure left the outer source exiting 0 with git_push_with_retry
# undefined, so kwt_finalize's `if ! git_push_with_retry` branch fired on a
# missing FUNCTION and reported "push failed (remote likely advanced
# concurrently, or offline)" — a misdiagnosis, over a board move that had
# silently lost the retry this helper exists to provide. A bare `[ -f ]` guard
# reaches exactly that state more quietly, which is why this refuses instead:
# `config-seam.md` § 2 — "a DEGRADED path may not carry its own second default …
# it refuses and names the seam". Same shape as new-issue.sh's config.sh load.
# ---------------------------------------------------------------------------
KWT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=push-retry.sh
if [ ! -f "$KWT_LIB_DIR/push-retry.sh" ] || ! . "$KWT_LIB_DIR/push-retry.sh"; then
  {
    echo "Error: scripts/lib/kanban-worktree.sh could not load its push helper."
    echo "       Looked for: $KWT_LIB_DIR/push-retry.sh"
    echo "       That file is the ONE definition of the push-race retry"
    echo "       (git_push_with_retry) every trunk-publishing op goes through."
    echo "       Without it a board move pushes ONCE with no retry, and a lost"
    echo "       race leaves the commit local — which cost one project a graft"
    echo "       weeks later (see that file's header)."
    echo "       This library REFUSES to load half-defined rather than let the"
    echo "       next kwt_finalize report a missing function as a push failure."
    echo "       Restore it:  git checkout -- scripts/lib/push-retry.sh"
  } >&2
  return 1 2>/dev/null || exit 1
fi
# ...and REACHABLE, not merely present: a file that sources without defining what
# this library calls is the same outage wearing a more plausible cause. This is
# the loud-absence assertion, not a presence check.
if ! command -v git_push_with_retry >/dev/null 2>&1 \
   || ! command -v git_report_ahead_behind >/dev/null 2>&1; then
  {
    echo "Error: $KWT_LIB_DIR/push-retry.sh sourced, but git_push_with_retry"
    echo "       and/or git_report_ahead_behind is NOT DEFINED. The file is"
    echo "       present and loadable; it no longer provides what this library"
    echo "       calls, so kwt_finalize would publish without a retry."
  } >&2
  return 1 2>/dev/null || exit 1
fi

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

# Set by kwt_sync: true when it fetched and reset to the tip, false when the fetch
# failed and it proceeded on LOCAL state. Declared here so a caller may read it
# under `set -u` without knowing whether kwt_sync ran. It is a REPORT, not a knob:
# setting it yourself changes nothing.
KWT_SYNCED=false

# Set by kwt_finalize to the commit that ACTUALLY LANDED — read back after the
# push, never computed before it. Callers print THIS, never a sha they captured
# earlier: git_push_with_retry rebases onto the remote tip when a race rejects the
# first attempt, and a rebase makes a NEW commit. A sha captured before the push is
# then a claim about a commit that exists on no ref — true when computed, false when
# printed, and indistinguishable from the landed one at a glance. Declared here so a
# caller may read it under `set -u`. It is a REPORT, not a knob.
KWT_LANDED_SHA=""

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
      # NAME THE HOLDER. The lock's own info file already records pid/host/epoch —
      # it is written at acquire time for exactly this purpose and was then not
      # read back here, so the operator was told "something holds it" and had to
      # go and cat the file to learn what. `contracts/kanban-worktree.md` § 3
      # requires the holder named; this is that requirement, met from the data
      # already on disk rather than from a new mechanism.
      #
      # An UNREADABLE or ABSENT info file is reported as that, not as blanks: a
      # lock directory with no info is itself worth knowing about (it means a
      # holder died between `mkdir` and the stamp), and printing "pid= host="
      # would read as a holder with no identity.
      local h_pid h_host h_epoch h_age
      h_pid="$(sed -n 's/^pid=//p'   "$KWT_LOCK/info" 2>/dev/null | head -1 || true)"
      h_host="$(sed -n 's/^host=//p' "$KWT_LOCK/info" 2>/dev/null | head -1 || true)"
      h_epoch="$(sed -n 's/^epoch=//p' "$KWT_LOCK/info" 2>/dev/null | head -1 || true)"
      {
        echo "Error: another kanban op holds the lock at $KWT_LOCK (waited ${KWT_LOCK_WAIT}s)."
        if [ -n "$h_pid" ] || [ -n "$h_host" ]; then
          if [ -n "$h_epoch" ] && [ -z "${h_epoch//[0-9]/}" ]; then
            h_age=$(( $(date +%s) - h_epoch ))
            echo "       Holder: pid ${h_pid:-<unrecorded>} on host ${h_host:-<unrecorded>}, held for ${h_age}s."
          else
            echo "       Holder: pid ${h_pid:-<unrecorded>} on host ${h_host:-<unrecorded>}, age unknown (epoch '${h_epoch:-<empty>}' is not a number)."
          fi
          echo "       If that host is this one, check it:  ps -p ${h_pid:-<pid>}"
        else
          echo "       Holder: UNRECORDED — $KWT_LOCK/info is absent or unreadable, which usually means a"
          echo "       holder died between creating the lock and stamping it. The staleness reaper clears"
          echo "       such a lock only by AGE (${KWT_LOCK_STALE}s), because there is no pid to probe."
        fi
        echo "       It will clear when that op finishes; retry then."
        echo "       If you are sure no other op is running, remove it: rm -rf '$KWT_LOCK'"
      } >&2
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

  local dirty untracked
  dirty="$(git -C "$KWT" status --porcelain --untracked-files=no 2>/dev/null || true)"
  if [ -n "$dirty" ] && [ "$KWT_DISCARD_DIRTY" != "true" ]; then
    {
      echo "Error: the kanban worktree ($KWT) is ATTACHED to '$branch' (not detached) AND holds"
      echo "       uncommitted tracked changes — refusing to repair it while they're there."
      echo "       Worktree: $KWT"
      echo ""
      echo "  Uncommitted changes:"
      echo "$dirty" | sed 's/^/    /'
      # PART 2 OF THE MISMATCH, REPORTED AND NOT REFUSED ON. The refusal above stays
      # scoped to TRACKED changes because its recorded reason is correct and measured:
      # `-uno` scopes a DESTRUCTION guard to exactly what `reset --hard` destroys, and
      # reset --hard leaves untracked files in place. But `reset --hard` not removing
      # them is precisely why they ACCUMULATE across every board move — and the remedy
      # printed below would commit them. So they are listed as CONTEXT, labelled, and
      # they do not change what refuses. Two scopes, two reasons, both stated.
      untracked="$(git -C "$KWT" ls-files --others --exclude-standard 2>/dev/null || true)"
      if [ -n "$untracked" ]; then
        echo ""
        echo "  ALSO PRESENT, untracked — NOT what the refusal above is about, and NOT destroyed by a"
        echo "  reset: these survive every board move and accumulate. A blanket 'add -A' would commit"
        echo "  them to the trunk, which is how a distribution payload once reached a project's main:"
        echo "$untracked" | sed 's/^/    /'
      fi
      echo ""
      echo "  Resolve by hand, then re-run:"
      echo "    • Keep them — commit AND push:"
      echo "        git -C '$KWT' add -- progress/ && git -C '$KWT' commit -m '…' && git -C '$KWT' push $KWT_REMOTE HEAD:$branch"
      echo "        (SCOPED TO progress/ ON PURPOSE. This worktree sits ON the trunk and pushes TO the"
      echo "         trunk, so 'add -A' here commits everything in it — including anything you or a"
      echo "         command materialised in it — straight to $branch with nothing in between.)"
      echo "    • Discard them — git -C '$KWT' reset --hard, then re-run (it will detach cleanly)"
      echo "    • Or re-run with --discard-dirty (mirrors kwt_sync's own opt-out)"
    } >&2
    return 1
  fi

  # ── BEFORE DETACHING: does the attached branch carry commits the remote does
  #    not have? Detaching lands HEAD on the same commit and moves nothing — the
  #    old message said so and it was true — but it leaves those commits reachable
  #    ONLY from a local branch ref that the next `reset --hard` does not update
  #    and no board check consults. That is how a metadata commit becomes an
  #    ORPHANED SIBLING: measured in a project running this process, two commits
  #    ended up on one parent, one reached the ref, and the other was reachable
  #    from nothing — `git branch -a --contains` returned empty — while the leg's
  #    own board note truthfully said the records had been committed. "Nothing
  #    else changed" was the narration on that repair, and it was the sentence
  #    that made a benign reading of a lossy state.
  #
  #    So the claim is now CHECKED before it is made, and the repair refuses when
  #    it cannot honestly make it.
  #    Two distinct refusals, because "there are unpublished commits" and "I
  #    cannot tell whether there are" are different claims and only one of them
  #    may be asserted. A refusal that states a fact it did not measure is the
  #    same disease as the reassurance it replaced.
  if ! git -C "$KWT" rev-parse --verify --quiet "$KWT_REMOTE/$branch" >/dev/null 2>&1; then
    {
      echo "Error: the kanban worktree ($KWT) is ATTACHED to '$branch', and $KWT_REMOTE/$branch does"
      echo "       not exist — so whether '$branch' holds anything unpublished CANNOT BE DETERMINED."
      echo "       Detaching would land HEAD on the same commit, but this repair will not report"
      echo "       'nothing else changed' on a state it could not read."
      echo "       Worktree: $KWT"
      echo ""
      echo "  Its last commits, for you to judge:"
      git -C "$KWT" log --oneline -n 5 "refs/heads/$branch" 2>/dev/null | sed 's/^/    /'
      echo ""
      echo "  Give the branch a remote counterpart, or detach deliberately by hand:"
      echo "        git -C '$KWT' push -u $KWT_REMOTE '$branch'      # then re-run"
      echo "        git -C '$KWT' switch --detach                    # abandon the attachment as-is"
    } >&2
    return 1
  fi

  local unpub
  unpub="$(git -C "$KWT" log --oneline "$KWT_REMOTE/$branch..refs/heads/$branch" 2>/dev/null || true)"
  if [ -n "$unpub" ]; then
    {
      echo "Error: the kanban worktree ($KWT) is ATTACHED to '$branch', and '$branch' carries commit(s)"
      echo "       that $KWT_REMOTE does not have. Detaching would leave them reachable only from a"
      echo "       local branch ref that no board check reads and the next sync does not update —"
      echo "       the orphaned-sibling state, recoverable afterwards only from 'git reflog --all'."
      echo "       Worktree: $KWT"
      echo ""
      echo "  Unpublished on '$branch':"
      echo "$unpub" | sed 's/^/    /'
      echo ""
      echo "  Publish them first (this is almost always what you want):"
      echo "        git -C '$KWT' push $KWT_REMOTE '$branch':$branch"
      echo "  …then re-run. To abandon them instead, do it deliberately and by hand:"
      echo "        git -C '$KWT' switch --detach && git -C '$KWT' branch -D '$branch'"
    } >&2
    return 1
  fi

  # `git switch --detach` with no target ref detaches HEAD AT THE CURRENT
  # COMMIT — it moves no commits and touches no tracked file, so it is safe
  # even over a dirty tree (KWT_DISCARD_DIRTY only widens who is allowed past
  # the refusal above, not what this command itself does).
  if git -C "$KWT" switch --detach --quiet 2>/dev/null; then
    echo "Repaired: the kanban worktree ($KWT) was attached to '$branch' — detached it (git switch --detach), landing back on the same commit. Nothing was left unpublished: that was CHECKED above, not assumed." >&2
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
# An unpushed local COMMIT is not caught by the dirty guard either (the tree is
# CLEAN after a commit). That was once documented as reset-on-the-next-sync BY
# DESIGN, with two compensators: kwt_finalize's push-failure message, and
# check-board.sh's [f] arm reporting the state before the next op destroys it.
# THE REASON STANDS AND BOTH COMPENSATORS REMAIN — but both are procedures that
# inform an operator who must then act BETWEEN two ops, and an orchestrated run
# does not pause between ops. So the conclusion moved: kwt_sync now REFUSES on an
# unpushed commit rather than resetting over it, and the compensators became the
# second and third lines of defence instead of the only ones.
# ---------------------------------------------------------------------------
kwt_sync() {
  # Dirty guard FIRST — it is a purely LOCAL check, so it must run regardless of
  # connectivity. An earlier ordering checked only after a successful fetch, so
  # the offline early-return below silently bypassed the guard and proceeded on a
  # contaminated worktree.
  if [ "$KWT_DISCARD_DIRTY" != "true" ]; then
    local dirty untracked
    dirty="$(git -C "$KWT" status --porcelain --untracked-files=no 2>/dev/null || true)"
    if [ -n "$dirty" ]; then
      {
        echo "Error: the kanban worktree has uncommitted tracked changes — refusing to sync."
        echo "       Syncing would 'git reset --hard $KWT_REMOTE/$DEFAULT_BRANCH' and DESTROY them."
        echo "       Worktree: $KWT"
        echo ""
        echo "  Uncommitted changes:"
        echo "$dirty" | sed 's/^/    /'
        # PART 2 OF THE MISMATCH, REPORTED AND NOT REFUSED ON. The refusal above stays
        # scoped to TRACKED changes because its recorded reason is correct and measured:
        # `-uno` scopes a DESTRUCTION guard to exactly what `reset --hard` destroys, and
        # reset --hard leaves untracked files in place. But `reset --hard` not removing
        # them is precisely why they ACCUMULATE across every board move — and the remedy
        # printed below would commit them. So they are listed as CONTEXT, labelled, and
        # they do not change what refuses. Two scopes, two reasons, both stated.
        untracked="$(git -C "$KWT" ls-files --others --exclude-standard 2>/dev/null || true)"
        if [ -n "$untracked" ]; then
          echo ""
          echo "  ALSO PRESENT, untracked — NOT what the refusal above is about, and NOT destroyed by a"
          echo "  reset: these survive every board move and accumulate. A blanket 'add -A' would commit"
          echo "  them to the trunk, which is how a distribution payload once reached a project's main:"
          echo "$untracked" | sed 's/^/    /'
        fi
        echo ""
        echo "  Resolve one of two ways:"
        # SUPERSEDED CONCLUSION, REASON KEPT: this said an unpushed commit "is reset on
        # the next sync". The unpushed-commit guard in kwt_sync replaced that behaviour
        # — the sync now REFUSES instead of resetting. Pushing is still the advice, but
        # for the opposite reason: unpushed work no longer vanishes, it BLOCKS.
        echo "    • Keep them — commit AND push (an unpushed commit BLOCKS the next sync until it lands):"
        echo "        git -C '$KWT' add -- progress/ && git -C '$KWT' commit -m '…' && git -C '$KWT' push $KWT_REMOTE HEAD:$DEFAULT_BRANCH"
        echo "        (SCOPED TO progress/ ON PURPOSE — 'add -A' in this worktree commits everything in"
        echo "         it straight to $DEFAULT_BRANCH, with no branch and no gate in between.)"
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
    # OFFLINE. We proceed rather than refuse — a board move is a local file move
    # and blocking it would make the process unusable on a plane — but the caller
    # is told, in the line that reports it, WHAT it is now working on and WHAT
    # happens next. KWT_SYNCED is the seam a caller may branch on; the return
    # code stays 0 so no existing caller's `set -e` turns "offline" into "abort".
    #
    # This warning used to end at "proceeding with local state", which named the
    # act and not its consequence. The consequence used to be a LOST COMMIT: this
    # op would commit onto stale state, its push would fail, and the NEXT sync's
    # `reset --hard` destroyed it. The guard below closes that, which is why this
    # can remain a warning instead of becoming a refusal — the thing it warned
    # about is no longer reachable, so the warning no longer has to carry it.
    KWT_SYNCED=false
    {
      echo "Warning: could not fetch $KWT_REMOTE/$DEFAULT_BRANCH (offline?) — proceeding on LOCAL state."
      echo "         This op is about to act on the board as of the last successful sync, not as of"
      echo "         the trunk: a card another session has already moved may be moved again here."
      echo "         Its push will also fail while the remote is unreachable. The commit will then"
      echo "         be REFUSED by the next sync rather than reset over — push it when the remote"
      echo "         returns:  git -C '$KWT' push $KWT_REMOTE HEAD:$DEFAULT_BRANCH"
    } >&2
    return 0
  fi
  KWT_SYNCED=true

  # ── UNPUSHED-COMMIT GUARD, and it must run between the fetch and the reset.
  #    `reset --hard` destroys a committed-but-unpushed commit as silently as it
  #    destroys an uncommitted edit — more silently, in fact, because the tree is
  #    CLEAN after a commit, so the dirty guard above cannot see it. This was
  #    documented as "reset on the next sync by design", with two compensators
  #    named: kwt_finalize's push-failure message, and check-board.sh's [f] arm
  #    reporting the state before the next op destroys it. THE REASON STANDS AND
  #    BOTH COMPENSATORS REMAIN TRUE — the conclusion is what moves. Both are
  #    procedures: they inform an operator who must then act between two ops, and
  #    a run that never pauses between ops never reads either. The act is silent
  #    and its cost compounds (the record is gone from the trunk while the leg's
  #    own note truthfully says it was committed), so it earns a mechanism.
  #
  #    NO OPT-OUT FLAG, deliberately. KWT_DISCARD_DIRTY covers uncommitted work,
  #    where "I know, throw it away" is a routine intent; a COMMIT is a deliberate
  #    act and discarding one should cost a deliberate hand command, not a flag
  #    that rides along on every invocation of a wrapper script.
  local unpushed
  unpushed="$(git -C "$KWT" log --oneline "$KWT_REMOTE/$DEFAULT_BRANCH..HEAD" 2>/dev/null || true)"
  if [ -n "$unpushed" ]; then
    {
      echo "Error: the kanban worktree holds commit(s) that are NOT on $KWT_REMOTE/$DEFAULT_BRANCH — refusing to sync."
      echo "       Syncing would 'git reset --hard $KWT_REMOTE/$DEFAULT_BRANCH' and make them UNREACHABLE"
      echo "       from any ref — recoverable only from 'git reflog --all', and invisible to"
      echo "       check-board.sh once that has happened."
      echo "       Worktree: $KWT"
      echo ""
      echo "  Unpushed:"
      echo "$unpushed" | sed 's/^/    /'
      echo ""
      echo "  Resolve one of two ways:"
      echo "    • Publish them (almost always right — an op made them and its push did not land):"
      echo "        git -C '$KWT' fetch $KWT_REMOTE $DEFAULT_BRANCH && git -C '$KWT' rebase $KWT_REMOTE/$DEFAULT_BRANCH"
      echo "        git -C '$KWT' push $KWT_REMOTE HEAD:$DEFAULT_BRANCH"
      echo "    • Discard them — BY HAND, so the choice is on the record:"
      echo "        git -C '$KWT' reset --hard $KWT_REMOTE/$DEFAULT_BRANCH"
    } >&2
    return 1
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
  # THE COMMIT WE ARE ABOUT TO PUBLISH, captured BEFORE the push. It is NOT the
  # operand of the ancestry assertion below — see there — because a won race
  # orphans it by design. It is kept for ONE thing that can only be said with it:
  # telling "the retry rebased this op's commit" apart from "the commit is
  # unreferenced", which are opposite states that look identical without it.
  local pre_head
  pre_head="$(git -C "$KWT" rev-parse HEAD 2>/dev/null || true)"

  # Push the commit just made in the worktree to the trunk — via the shared
  # pull-rebase-retry wrapper rather than a single bare push, so a diverged
  # remote (a parallel landing winning the race) is rebased onto and retried
  # instead of dying silently.
  if ! git_push_with_retry "$KWT" "$KWT_REMOTE" "$DEFAULT_BRANCH"; then
    echo "Error: push of HEAD → $KWT_REMOTE/$DEFAULT_BRANCH failed (remote likely advanced concurrently, or offline)." >&2
    echo "       The commit was made LOCALLY in the kanban worktree but is NOT on $KWT_REMOTE." >&2
    echo "       The next kanban op's sync now REFUSES rather than resetting over it (see kwt_sync)," >&2
    echo "       so it is not about to be destroyed — but nothing else will publish it either:" >&2
    echo "         git -C '$KWT' fetch $KWT_REMOTE $DEFAULT_BRANCH && git -C '$KWT' rebase $KWT_REMOTE/$DEFAULT_BRANCH" >&2
    echo "         git -C '$KWT' push $KWT_REMOTE HEAD:$DEFAULT_BRANCH" >&2
    return 1
  fi

  # ── READ THE REF BACK. "Pushed, accepted" is a reading at an instant, not a
  #    property: a mirror or a replica can un-apply it, and a force-push has been
  #    measured reporting success without landing. The push wrapper's exit code
  #    says the command succeeded; only this says the COMMIT IS ON THE REF.
  #
  #    This is also the one guard that can catch an ORPHANED SIBLING — a commit
  #    made in this worktree that ends up reachable from no ref at all. Such a
  #    commit is invisible to `git status` (the tree is clean), invisible to
  #    `<remote>/<trunk>..HEAD` (it is not an ancestor of HEAD either), and
  #    therefore invisible to check-board.sh's divergence arm, which reports
  #    "in sync ✓" while a committed record is missing from the trunk. Measured in
  #    a project running this process: two commits became siblings on one parent,
  #    one reached the ref, the other was recoverable only from `git reflog --all`
  #    and cost a review window to find. A guard that fires at the moment of loss
  #    beats a report that cannot describe the loss at all.
  #    THE OPERAND IS THE POST-PUSH HEAD, NOT $pre_head, and that is the whole
  #    point of reading it here. git_push_with_retry REBASES onto the remote tip
  #    when a race rejects the first attempt (push-retry.sh:5,20-23 says so) — and
  #    a rebase makes a NEW commit, so the operation that SUCCEEDED is the same
  #    operation that orphaned $pre_head. Asserting on $pre_head therefore fired
  #    on the SUCCESS path of every won race: it reported a landing that had
  #    worked as a failure, and advised a cherry-pick that produced a DUPLICATE.
  local post_head
  post_head="$(git -C "$KWT" rev-parse HEAD 2>/dev/null || true)"
  if [ -n "$post_head" ]; then
    git -C "$KWT" fetch "$KWT_REMOTE" "$DEFAULT_BRANCH" --quiet 2>/dev/null || true
    if ! git -C "$KWT" merge-base --is-ancestor "$post_head" "$KWT_REMOTE/$DEFAULT_BRANCH" 2>/dev/null; then
      {
        echo "Error: the push reported success, but $(git -C "$KWT" rev-parse --short "$post_head" 2>/dev/null || echo "$post_head") is NOT an ancestor of $KWT_REMOTE/$DEFAULT_BRANCH."
        echo "       The commit this op made is not on the trunk. It is not lost — it is"
        echo "       UNREFERENCED, which is the state no board check can see:"
        echo "         git -C '$KWT' log -1 $post_head          # confirm what it carried"
        echo "         git -C '$MAIN_ROOT' cherry-pick $post_head   # replay it onto the trunk"
        echo "       (cherry-pick preserves the original author and [Role]-prefixed subject.)"
        echo "       Do this before the next kanban op; reflog expiry is the only clock on it."
        # ABSENT AND BROKEN ARE DIFFERENT FACTS, and only $pre_head tells them apart
        # here: if the retry rebased, the pre-push sha is orphaned BY THE REBASE and
        # is not the one to replay.
        if [ -n "$pre_head" ] && [ "$pre_head" != "$post_head" ]; then
          echo "       Note: a push retry rebased this op's commit, so it began life as"
          echo "       $(git -C "$KWT" rev-parse --short "$pre_head" 2>/dev/null) — that sha is orphaned BY THE REBASE, not the one to replay."
        fi
      } >&2
      return 1
    fi
  fi

  # The landed sha, read AFTER the push and AFTER the ancestry check above — so by
  # construction it names a commit that is on <remote>/<trunk>, which is exactly the
  # claim a caller's "published commit: <sha>" line makes.
  # Reads $post_head rather than HEAD: it names the sha the assertion above
  # actually cleared. Empty $post_head yields empty, and callers read empty as
  # NOT PUBLISHED and refuse — it fails closed.
  KWT_LANDED_SHA="$(git -C "$KWT" rev-parse --short "$post_head" 2>/dev/null || true)"

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
