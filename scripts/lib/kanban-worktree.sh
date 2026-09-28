#!/usr/bin/env bash
# KIT-CLASS: KIT — the .kanban-wt/ worktree machinery. See process/EXTRACTION.md.
#
# FOR BOARD FILES ONLY. This is the one checkout on the trunk while the main one is on a work
# branch, so it reads as a spare clean tree, and it is not one: its HEAD and its push target ARE
# the trunk, so anything present here is one commit from the trunk with no branch and no gate.
# Do not build here, materialise files here, `git checkout <ref> -- .` into here or run a
# blanket `git add -A` here. The checkout route stages its payload, so a plain `git commit`
# carries it past every guard below (process/contracts/kanban-worktree.md § 1).
#
# Sourced by move-issue.sh, finish-pr.sh, subtask.sh and archive.sh. Every kanban git operation
# (the `git mv`, the Activity append, the commit, the push) happens in a STANDING worktree,
# `.kanban-wt/` at the repo root, gitignored. The operator's checkout is NEVER switched: on the
# trunk with a clean tree it is fast-forwarded after a successful op, otherwise left untouched.
#
# DETACHED, because `git worktree add .kanban-wt <trunk>` fails while the trunk is checked out in
# the main worktree. Every op fetches and resets to <remote>/<trunk>, commits, and pushes
# HEAD:<trunk>. The local trunk ref is advanced separately, never by update-ref on a ref checked
# out elsewhere (that desyncs that worktree). kwt__ensure_detached checks the invariant on every
# op rather than assuming it.
#
# Preflight for a launch that spins up parallel legs:
#   git worktree list | grep '\.kanban-wt'
#   # must show:  …/.kanban-wt   <sha>  (detached HEAD)
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
#   kwt_open_subtasks <id> → print each card of <id>'s subtask tree neither in qa_complete/ nor declined/
#
# The sourcing script owns shell options; this file uses explicit return codes.
#
# CALLER CONTRACT: the push-helper load below refuses with a non-zero return, which stops only a
# caller that runs `set -e` or checks the status of its `. lib/kanban-worktree.sh`. Do one. The
# shape to copy (-F, so no grep reads the `$` as an anchor):
#   grep -rnF '! . "$CONFIG"' scripts

# ---------------------------------------------------------------------------
# THE PUBLICATION REMOTE for every kit operation, board and release alike: the one authoritative
# definition contracts/config-seam.md requires. Default `origin`; for a fork or mirror:
#   KWT_REMOTE=upstream ./scripts/move-issue.sh …
# A remote NAME, never a URL: the trunk resolves through refs/remotes/$KWT_REMOTE/HEAD, and a URL
# falls silently through to KWT_TRUNK_LAST_RESORT. The prefix is narrower than the meaning, and
# renaming it would silently ignore every current setter.
# ---------------------------------------------------------------------------
KWT_REMOTE="${KWT_REMOTE:-origin}"

# ---------------------------------------------------------------------------
# The trunk chain's LAST link, a named constant: kit-init.sh and the self-test derive the
# shipped value from this line, so keep its shape.
KWT_TRUNK_LAST_RESORT="${KWT_TRUNK_LAST_RESORT:-main}"

# ---------------------------------------------------------------------------
# The push-race wrapper (push-retry.sh): sourced, never re-implemented.
#
# `${BASH_SOURCE[0]:-$0}`, never a bare `${BASH_SOURCE[0]}`: outside bash that is unset,
# `dirname ""` is `.`, and the source silently resolves against $PWD.
#
# A FAILED LOAD REFUSES: otherwise kwt_finalize's push branch fires on a missing function and
# misreports it as a push failure (contracts/config-seam.md § 2: a degraded path refuses and
# names the seam).
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
    echo "       race leaves the commit local and unpublished."
    echo "       This library REFUSES to load half-defined rather than let the"
    echo "       next kwt_finalize report a missing function as a push failure."
    echo "       Restore it:  git checkout -- scripts/lib/push-retry.sh"
  } >&2
  return 1 2>/dev/null || exit 1
fi
# ...and REACHABLE: a file that sources without defining these is the same outage.
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
# Root + trunk resolution, from the main worktree, a feature worktree or .kanban-wt: the common
# git dir's dirname is the main repo root.
#
# The common dir is made absolute by `cd … && pwd -P`, not `--path-format=absolute`, which git
# before 2.31 echoes back as the answer and exits 0. The query runs from the top level
# (`--show-cdup`) because git before 2.13 answers relative to it. Every `cd` clears CDPATH, which
# would otherwise redirect a relative `cd` and print into the captured answer.
#
# NOT `git worktree list --porcelain` (progress-record.sh's route): its fallback is this checkout,
# and the lock and the standing worktree must be ONE per repository, whichever checkout asks.
#
# THE TRUNK: <remote>/HEAD → init.defaultBranch → KWT_TRUNK_LAST_RESORT, and every step below the
# first WARNS. Not a refusal: read-only callers (check-board.sh in the SessionStart hook) must
# still run. kit-init.sh's `--trunk` cross-checks <remote>/HEAD, so an initialized repository
# stays on step 1.
# ---------------------------------------------------------------------------
kwt_resolve() {
  local cdup named common_dir
  cdup="$(git rev-parse --show-cdup 2>/dev/null)" &&
    named="$(CDPATH= cd "./$cdup" && git rev-parse --git-common-dir 2>/dev/null)" &&
    [ -n "$named" ] || {
    echo "Error: not inside a git repository." >&2
    return 1
  }
  common_dir="$(CDPATH= cd "./$cdup" 2>/dev/null && CDPATH= cd "$named" 2>/dev/null && pwd -P)" || {
    echo "Error: git names '$named' as this repository's common git directory, and it" >&2
    echo "       could not be entered from '$PWD/$cdup'." >&2
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
# mkdir-atomic lock: exactly one contender wins the create; poll up to KWT_LOCK_WAIT. A held
# lock is reaped only when its holder is provably gone (same host and PID dead → at once;
# cross-host or unknown → by age). The reap is serialised behind a one-winner `mkdir .reap`
# claim and re-confirmed under it, and a fresh lock cannot exist while the dead one occupies the
# path, so a live holder's lock is never removed, however slow its op. On timeout: a message, a
# non-zero return, and nothing touched.
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

# Set true by a consumer's --discard-dirty: kwt_sync then resets over uncommitted tracked
# changes instead of aborting.
KWT_DISCARD_DIRTY=false

# Set by kwt_sync: true when it fetched and reset to the tip, false when it proceeded offline
# on LOCAL state. A report, not a knob; declared so a `set -u` caller may read it.
KWT_SYNCED=false

# Set by kwt_finalize to the commit that ACTUALLY LANDED, read after the push. Callers print
# this, never a sha captured earlier: a retried push rebases, which makes a new commit. A
# report, not a knob.
KWT_LANDED_SHA=""

# Echoes "yes" if the CURRENT lock holder is provably abandoned:
#   - same host + holder PID no longer exists; or
#   - cross-host / unknown PID + lock older than KWT_LOCK_STALE.
# Liveness is `kill -0` OR `ps -p`, so another user's live process (EPERM) is not taken for
# dead. The `|| true` on the seds is load-bearing: a loser may poll between the winner's mkdir
# and its `info` write.
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

    # Held. Steal only if provably abandoned, behind the one-winner reap claim (see the lock
    # block above); after the removal everyone re-contends on the mkdir.
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
      # The claim is held: a reap in flight, or a claim LEAKED by a crashed reaper. Never
      # `continue` here (a busy-spin): clear a claim older than KWT_REAP_STALE and fall through
      # to the bounded wait. Clearing a live reaper's claim is harmless; it re-confirms first.
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
      # NAME THE HOLDER from the info file (contracts/kanban-worktree.md § 3). An absent or
      # unreadable info file is reported as that, not as blanks.
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
       | grep -xF "worktree $KWT" >/dev/null; then
    kwt__ensure_detached  # detach-by-construction, not assumed.
    return $?
  fi

  # A leftover directory with no registration (e.g. partial create) blocks
  # `worktree add`. Prune dead entries, then if the path still exists un-managed,
  # bail with a clear message rather than clobbering.
  git -C "$MAIN_ROOT" worktree prune 2>/dev/null || true
  if git -C "$MAIN_ROOT" worktree list --porcelain 2>/dev/null \
       | grep -xF "worktree $KWT" >/dev/null; then
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
# Detach-by-construction (see DETACHED in the header): checked on every op, never assumed.
#
# - Already detached → no-op.
# - Attached + dirty (uncommitted TRACKED changes) → REFUSE: a detach would carry them across a
#   HEAD move on a shared board worktree.
# - Attached + commits the remote lacks, or no remote counterpart → REFUSE (below).
# - Attached + clean → `git switch --detach` onto the same commit, and say so.
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
      # Untracked files are listed as CONTEXT, not refused on: the refusal is scoped to what
      # `reset --hard` destroys, but untracked files accumulate and the remedy below would
      # commit them.
      untracked="$(git -C "$KWT" ls-files --others --exclude-standard 2>/dev/null || true)"
      if [ -n "$untracked" ]; then
        echo ""
        echo "  ALSO PRESENT, untracked — NOT what the refusal above is about, and NOT destroyed by a"
        echo "  reset: these survive every board move and accumulate. A blanket 'add -A' would commit"
        echo "  them to the trunk:"
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

  # ── BEFORE DETACHING: commits on the attached branch that the remote lacks would be left
  #    reachable only from a local ref no board check reads and no sync updates. Refuse, and
  #    refuse separately when the branch has no remote counterpart: "there are unpublished
  #    commits" and "I cannot tell" are different claims.
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

  # With no target, `git switch --detach` detaches at the current commit: it moves no commits
  # and touches no tracked file.
  if git -C "$KWT" switch --detach --quiet 2>/dev/null; then
    echo "Repaired: the kanban worktree ($KWT) was attached to '$branch' — detached it (git switch --detach), landing back on the same commit. Nothing was left unpublished: that was CHECKED above, not assumed." >&2
    return 0
  fi

  echo "Error: the kanban worktree ($KWT) is attached to '$branch' and could not be detached." >&2
  return 1
}

# ---------------------------------------------------------------------------
# Sync: make the detached worktree match <remote>/<trunk>, the source of truth, by reset --hard
# to the fetched tip. It REFUSES first over what that reset would destroy:
#   - uncommitted TRACKED changes (`status --porcelain -uno`: exactly what reset --hard destroys;
#     untracked files survive it). Opt out: KWT_DISCARD_DIRTY=true (--discard-dirty).
#   - commits not on <remote>/<trunk>. No opt-out: discarding a commit is a hand command.
# ---------------------------------------------------------------------------
kwt_sync() {
  # Dirty guard FIRST: it is local, so it must run even when the fetch below fails.
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
        # Untracked files are listed as CONTEXT, not refused on: the refusal is scoped to what
        # `reset --hard` destroys, but untracked files accumulate and the remedy below would
        # commit them.
        untracked="$(git -C "$KWT" ls-files --others --exclude-standard 2>/dev/null || true)"
        if [ -n "$untracked" ]; then
          echo ""
          echo "  ALSO PRESENT, untracked — NOT what the refusal above is about, and NOT destroyed by a"
          echo "  reset: these survive every board move and accumulate. A blanket 'add -A' would commit"
          echo "  them to the trunk:"
          echo "$untracked" | sed 's/^/    /'
        fi
        echo ""
        echo "  Resolve one of two ways:"
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

  # Checked again at sync time; the tree is known clean (or opted out) by here.
  kwt__ensure_detached || return 1

  if ! git -C "$KWT" fetch "$KWT_REMOTE" "$DEFAULT_BRANCH" --quiet 2>/dev/null; then
    # OFFLINE: proceed (a board move is a local file move) but say what state this acts on and
    # what happens next. KWT_SYNCED is the seam; the return stays 0 so a `set -e` caller goes
    # on. The commit this op makes is protected by the next sync's unpushed-commit guard.
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

  # ── UNPUSHED-COMMIT GUARD, between the fetch and the reset. The dirty guard cannot see a
  #    commit (the tree is clean after one), and reset --hard would orphan it silently.
  #    kwt_finalize's message and check-board.sh's [f] arm only inform an operator between
  #    ops, and an unattended run never pauses there.
  #    NO OPT-OUT FLAG: discarding a commit should cost a deliberate hand command.
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
  # Captured BEFORE the push, only to tell "the retry rebased this op's commit" from "the
  # commit is unreferenced". It is not the operand of the ancestry check below.
  local pre_head
  pre_head="$(git -C "$KWT" rev-parse HEAD 2>/dev/null || true)"

  # Through the shared retry wrapper, never a bare push.
  if ! git_push_with_retry "$KWT" "$KWT_REMOTE" "$DEFAULT_BRANCH"; then
    echo "Error: push of HEAD → $KWT_REMOTE/$DEFAULT_BRANCH failed (remote likely advanced concurrently, or offline)." >&2
    echo "       The commit was made LOCALLY in the kanban worktree but is NOT on $KWT_REMOTE." >&2
    echo "       The next kanban op's sync now REFUSES rather than resetting over it (see kwt_sync)," >&2
    echo "       so it is not about to be destroyed — but nothing else will publish it either:" >&2
    echo "         git -C '$KWT' fetch $KWT_REMOTE $DEFAULT_BRANCH && git -C '$KWT' rebase $KWT_REMOTE/$DEFAULT_BRANCH" >&2
    echo "         git -C '$KWT' push $KWT_REMOTE HEAD:$DEFAULT_BRANCH" >&2
    return 1
  fi

  # ── READ THE REF BACK: a push's exit status is not the commit being on the ref (a mirror can
  #    un-apply it). This is also the one guard that catches an ORPHANED SIBLING, a commit
  #    reachable from no ref, which `git status`, `<remote>/<trunk>..HEAD` and check-board.sh
  #    all miss.
  #    THE OPERAND IS THE POST-PUSH HEAD, NOT $pre_head: a won race rebases, which makes a new
  #    commit and orphans $pre_head on the success path.
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
        # Only $pre_head tells a rebased commit from a lost one.
        if [ -n "$pre_head" ] && [ "$pre_head" != "$post_head" ]; then
          echo "       Note: a push retry rebased this op's commit, so it began life as"
          echo "       $(git -C "$KWT" rev-parse --short "$pre_head" 2>/dev/null) — that sha is orphaned BY THE REBASE, not the one to replay."
        fi
      } >&2
      return 1
    fi
  fi

  # The landed sha is the one the ancestry check cleared. Empty means NOT PUBLISHED, and
  # callers refuse on it (fails closed).
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
    # The looks-pushed check: this op pushed only the kanban worktree's commit, and a
    # hand-made trunk commit in the main checkout may still be local.
    git_report_ahead_behind "$MAIN_ROOT" "$KWT_REMOTE" "$DEFAULT_BRANCH"
  else
    # The trunk may be checked out in a THIRD worktree, where update-ref would desync its
    # index, so scan all worktrees first.
    git -C "$MAIN_ROOT" fetch "$KWT_REMOTE" "$DEFAULT_BRANCH" --quiet 2>/dev/null || true
    if git -C "$MAIN_ROOT" worktree list --porcelain 2>/dev/null \
         | grep -xF "branch refs/heads/$DEFAULT_BRANCH" >/dev/null; then
      echo "Note: $DEFAULT_BRANCH is checked out in another worktree — its local ref left as-is (pull there when ready)." >&2
    else
      git -C "$MAIN_ROOT" update-ref "refs/heads/$DEFAULT_BRANCH" "refs/remotes/$KWT_REMOTE/$DEFAULT_BRANCH" 2>/dev/null || true
    fi
  fi
  return 0
}

# kwt_open_subtasks <parent-id> — print, one per line and relative to $KWT, every card under
# progress/subtasks/<parent-id>/<status>/ whose status is neither qa_complete nor declined. Empty output: no tree,
# or every slice reviewed. A parent reaches qa_complete (or done) only when this prints nothing.
# Read after kwt_sync, so it answers for the published board.
kwt_open_subtasks() {
  local base="$KWT/progress/subtasks/$1" all f
  [ -d "$base" ] || return 0
  all="$(find "$base" -mindepth 2 -maxdepth 2 -type f -name '*.md' 2>/dev/null | sort)"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in "$base"/qa_complete/*|"$base"/declined/*) continue ;; esac
    printf '%s\n' "${f#"$KWT"/}"
  done <<KWT_OPEN_EOF
$all
KWT_OPEN_EOF
  return 0
}
