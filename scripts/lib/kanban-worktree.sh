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
# Sourced by every script that touches the board (derive them: grep -l kanban-worktree.sh
# scripts/*.sh). Every kanban git operation (the `git mv`, the Activity append, the commit, the
# push) happens in a STANDING worktree, `.kanban-wt/` at the repo root, gitignored. The operator's
# checkout is NEVER switched: on the trunk with a clean tree it is fast-forwarded after a
# successful op, otherwise left untouched.
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
#   kwt_hold_output        → (lib/hold-output.sh) call in a script that commits here, before its first write that follows
#                            a commit or the lock (a refusal-only preamble may come first): its stdout
#                            and stderr then survive a caller that closes its pipe (`op | head -1`)
#   kwt_resolve            → sets MAIN_ROOT, KWT, KWT_LOCK, DEFAULT_BRANCH
#   kwt_lock               → acquire the mkdir-atomic lock (timeout + liveness-aware
#                            serialized reap of an abandoned lock)
#   kwt_unlock             → release the lock (also armed via trap on EXIT; a script that
#                            locks ends with `exit 0` — lib/exit-trap.sh says why)
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
# The sourcing script owns shell options. A refusal on STATE goes through kit_refuse and ends the op;
# a function returns nonzero only where its caller must keep control (kwt_finalize, whose callers
# report what was and was not published), and the return is marked by lib/refuse.sh's rule.
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
  return 1 2>/dev/null || exit 1   # exit-class: internal
fi
# The EXIT-trap helper kwt_lock arms: a script that locks must END with `exit 0` (exit-trap.sh).
# shellcheck source=exit-trap.sh
if [ ! -f "$KWT_LIB_DIR/exit-trap.sh" ] || ! . "$KWT_LIB_DIR/exit-trap.sh"; then
  echo "Error: scripts/lib/kanban-worktree.sh could not load $KWT_LIB_DIR/exit-trap.sh." >&2
  echo "       Restore it:  git checkout -- scripts/lib/exit-trap.sh" >&2
  return 1 2>/dev/null || exit 1   # exit-class: internal
fi
# The state refusals below go through kit_refuse (refuse.sh), so each leaves a record and a route.
# shellcheck source=refuse.sh
if [ ! -f "$KWT_LIB_DIR/refuse.sh" ] || ! . "$KWT_LIB_DIR/refuse.sh"; then
  echo "Error: scripts/lib/kanban-worktree.sh could not load $KWT_LIB_DIR/refuse.sh." >&2
  echo "       Restore it:  git checkout -- scripts/lib/refuse.sh" >&2
  return 1 2>/dev/null || exit 1   # exit-class: internal
fi
# kwt_hold_output, which a script that commits here calls so `<op> | head -1` cannot stop it between
# its commit and its push (hold-output.sh says how).
# shellcheck source=hold-output.sh
if [ ! -f "$KWT_LIB_DIR/hold-output.sh" ] || ! . "$KWT_LIB_DIR/hold-output.sh" \
   || ! command -v kwt_hold_output >/dev/null 2>&1; then
  echo "Error: scripts/lib/kanban-worktree.sh could not load kwt_hold_output from $KWT_LIB_DIR/hold-output.sh." >&2
  echo "       Without it a closed output pipe stops a board op between its commit and its push." >&2
  echo "       Next: restore it with  git checkout -- scripts/lib/hold-output.sh  (or from the release zip), then re-run." >&2
  return 1 2>/dev/null || exit 1   # exit-class: internal
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
  return 1 2>/dev/null || exit 1   # exit-class: internal
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
    [ -n "$named" ] || kit_refuse 1 not-in-git-repository \
    "Error: not inside a git repository." \
    "Next: cd into the project's repository (the directory holding scripts/ and progress/), then re-run."
  common_dir="$(CDPATH= cd "./$cdup" 2>/dev/null && CDPATH= cd "$named" 2>/dev/null && pwd -P)" || {
    echo "Error: git names '$named' as this repository's common git directory, and it" >&2
    echo "       could not be entered from '$PWD/$cdup'." >&2
    return 1   # return-class: internal
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

# Portable file-mtime (epoch seconds). GNU stat (`-c %Y`, Linux) OR BSD stat (`-f %m`,
# macOS); 0 if neither works (treated as "very old" → cleanable). GNU first: its `stat -f`
# is a different option (filesystem status) that prints a block to stdout and exits 1.
kwt__mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

# Set true by a consumer's --discard-dirty: kwt_sync then resets over uncommitted tracked
# changes instead of aborting.
KWT_DISCARD_DIRTY=false

# Set by kwt_sync: true when it fetched and reset to the tip, false when it proceeded offline
# on LOCAL state. A report, not a knob; declared so a `set -u` caller may read it.
KWT_SYNCED=false

# Set by kwt_commit to the commit it made; cleared by kwt_finalize once that commit is pushed (or reported).
# Still set when kwt_unlock runs means the op ended between the two. A report, not a knob.
KWT_UNPUSHED=""
# True once kwt_sync has found no rebase in progress in the kanban worktree: a rebase seen at the exit is then this
# op's own (the retry's), and only that one is aborted. A report for kwt_unlock, not a knob.
KWT_REBASE_OURS=false

# The commands that publish a commit left in $KWT; kwt_finalize's push failure and kwt_unlock each print them
# under their own `Next:` line.
kwt__publish_next() {
  echo "         git -C '$KWT' fetch $KWT_REMOTE $DEFAULT_BRANCH && git -C '$KWT' rebase $KWT_REMOTE/$DEFAULT_BRANCH"
  echo "         git -C '$KWT' push $KWT_REMOTE HEAD:$DEFAULT_BRANCH"
}

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
        kit_on_exit 'kwt_unlock'
        # A signal to the op ends it only once the git command it is running (a push) has returned: bash
        # runs a trap after its foreground command, so the lock is never released over a push still in flight.
        # A hung git command (a push or fetch to a remote that stops answering) needs KILL, which still leaves a push orphaned.
        trap 'exit 143' TERM
        trap 'exit 129' HUP
        trap 'exit 130' INT
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
      local h_pid h_host h_epoch h_age h_detail
      h_pid="$(sed -n 's/^pid=//p'   "$KWT_LOCK/info" 2>/dev/null | head -1 || true)"
      h_host="$(sed -n 's/^host=//p' "$KWT_LOCK/info" 2>/dev/null | head -1 || true)"
      h_epoch="$(sed -n 's/^epoch=//p' "$KWT_LOCK/info" 2>/dev/null | head -1 || true)"
      h_detail="$(
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
      )"
      kit_refuse 1 kanban-lock-held \
        "Error: another kanban op holds the lock at $KWT_LOCK (waited ${KWT_LOCK_WAIT}s)." \
        "$h_detail" \
        "Next: wait for the holder's op to finish, then re-run this same command. A holder that has died is reaped by the next attempt (an unrecorded or other-host lock after ${KWT_LOCK_STALE}s), so leave $KWT_LOCK alone. If it is still held after several attempts, the holder is a live op: ask whose it is and how long it runs (./scripts/ask.sh --role <role> \"<question>\" --default \"wait for the holder, then re-run\")."
    fi
    sleep 1
    waited=$(( waited + 1 ))
  done
}

kwt_unlock() {
  # Local git only below, so ignoring signals here cannot hang: a second one must not skip the text or the lock removal.
  # Put back at the end when this op still runs on (finish-pr.sh unlocks, then goes on).
  local _kwt_rearm=false
  [ "$KWT_LOCK_HELD" = "true" ] && _kwt_rearm=true
  trap '' TERM HUP INT
  # A signal runs its trap as soon as the git command it interrupted returns, which can be before the retry's own
  # `git rebase --abort`: a rebase this op started is aborted here, so the Next below can run. Never one that was
  # already open when the op began (KWT_REBASE_OURS): a person may be resolving it.
  local _kwt_gd="" _kwt_midrebase=false
  if [ "$KWT_LOCK_HELD" = "true" ] && [ -n "${KWT:-}" ]; then
    _kwt_gd="$(git -C "$KWT" rev-parse --absolute-git-dir 2>/dev/null || true)"
    if [ "$KWT_REBASE_OURS" = "true" ] && [ -n "$_kwt_gd" ] && { [ -d "$_kwt_gd/rebase-merge" ] || [ -d "$_kwt_gd/rebase-apply" ]; }; then
      git -C "$KWT" rebase --abort >/dev/null 2>&1 || true
    fi
    if [ -n "$_kwt_gd" ] && { [ -d "$_kwt_gd/rebase-merge" ] || [ -d "$_kwt_gd/rebase-apply" ]; }; then _kwt_midrebase=true; fi
  fi
  # The op ended with its commit made and no push landed: killed between the two. kwt_finalize
  # reports its own failures and clears this first, so what reaches here was cut off. The same signal can land after a
  # push that succeeded and before kwt_finalize clears it. The remote's tracking ref, which that push updated, then holds
  # the commit; it is not re-read from the remote here, so the text says only that. Never while a rebase is still stopped:
  # HEAD is then the remote's tip, not this op's commit.
  if [ -n "$KWT_UNPUSHED" ] && [ "$_kwt_midrebase" = "false" ] && git -C "$KWT" merge-base --is-ancestor HEAD "refs/remotes/$KWT_REMOTE/${DEFAULT_BRANCH:-}" 2>/dev/null; then
    {
      echo "Note: this op was ended by a signal after its push to $KWT_REMOTE/${DEFAULT_BRANCH:-} returned success: $KWT_REMOTE/${DEFAULT_BRANCH:-}, as this clone last saw it, holds its commit ($(git -C "$KWT" rev-parse --short HEAD 2>/dev/null || echo "$KWT_UNPUSHED")). The next board op re-reads it from the remote."
      echo "      What the op did after its push did not run: finish-pr.sh's branch deletion and its move to qa_complete, or the main checkout catching up."
      echo "Next: ./scripts/check-board.sh shows whether anything is left undone; bring the main checkout up to the trunk:"
      echo "         git -C '$MAIN_ROOT' pull --ff-only $KWT_REMOTE ${DEFAULT_BRANCH:-}"
      echo "      For finish-pr.sh, do not run it again (nothing is left to merge): delete the landed branch and run move-issue.sh <id> qa_complete --landed-at <the sha above> --role <role> --note '<what the review found>'."
    } >&2
    KWT_UNPUSHED=""
  fi
  if [ -n "$KWT_UNPUSHED" ]; then
    {
      echo "Error: this op ended after its commit ($(git -C "$KWT" rev-parse --short HEAD 2>/dev/null || echo "$KWT_UNPUSHED")) in the kanban worktree, while its push was still to run or in flight."
      echo "       The push may or may not have landed on $KWT_REMOTE. If it did not, the next kanban op's sync REFUSES over this commit and nothing else will publish it."
      echo "Next: run these; they are safe whether or not the push landed (a rebase that conflicts: resolve, git rebase --continue):"
      kwt__publish_next
    } >&2
    KWT_UNPUSHED=""
  fi
  if [ "$KWT_LOCK_HELD" = "true" ]; then
    rm -rf "$KWT_LOCK" 2>/dev/null || true
    KWT_LOCK_HELD=false
  fi
  if [ "$_kwt_rearm" = "true" ]; then
    trap 'exit 143' TERM
    trap 'exit 129' HUP
    trap 'exit 130' INT
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
    return $?   # return-class: relay
  fi

  # A leftover directory with no registration (e.g. partial create) blocks
  # `worktree add`. Prune dead entries, then if the path still exists un-managed,
  # bail with a clear message rather than clobbering.
  git -C "$MAIN_ROOT" worktree prune 2>/dev/null || true
  if git -C "$MAIN_ROOT" worktree list --porcelain 2>/dev/null \
       | grep -xF "worktree $KWT" >/dev/null; then
    kwt__ensure_detached
    return $?   # return-class: relay
  fi
  if [ -e "$KWT" ]; then
    kit_refuse 1 kanban-wt-unregistered \
      "Error: $KWT exists but is not a registered worktree." \
      "Next: look at what it holds (ls -a '$KWT'), then move it aside, which loses nothing, and re-run, which recreates it as the board worktree:  mv '$KWT' '$KWT.stale-$(date +%Y%m%d%H%M%S)'"
  fi

  if ! git -C "$MAIN_ROOT" worktree add --detach "$KWT" "$DEFAULT_BRANCH" --quiet 2>/dev/null; then
    # Fallback: the trunk may not exist locally yet; try <remote>/<trunk>.
    if ! git -C "$MAIN_ROOT" worktree add --detach "$KWT" "refs/remotes/$KWT_REMOTE/$DEFAULT_BRANCH" --quiet 2>/dev/null; then
      kit_refuse 1 kanban-wt-bootstrap-failed \
        "Error: failed to bootstrap kanban worktree at $KWT." \
        "       Neither '$DEFAULT_BRANCH' nor '$KWT_REMOTE/$DEFAULT_BRANCH' could be checked out." \
        "Next: fetch the trunk (git -C '$MAIN_ROOT' fetch $KWT_REMOTE) and re-run. If '$DEFAULT_BRANCH' is not your trunk, the trunk warning earlier in this run says how it was chosen; set it with  git -C '$MAIN_ROOT' remote set-head $KWT_REMOTE <your-trunk>  and re-run."
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

  local dirty untracked detail
  dirty="$(git -C "$KWT" status --porcelain --untracked-files=no 2>/dev/null || true)"
  if [ -n "$dirty" ] && [ "$KWT_DISCARD_DIRTY" != "true" ]; then
    detail="$(
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
    )"
    kit_refuse 1 kanban-wt-attached-dirty \
      "Error: the kanban worktree ($KWT) is ATTACHED to '$branch' (not detached) AND holds" \
      "$detail" \
      "Next: read the changes above first. A board op leaves uncommitted changes here only when it failed mid-write, so changes you did not see an op fail on are not an op's: ask (./scripts/ask.sh --role <role> \"<question>\" --default \"leave them and stop\")." \
      "      If you saw an op fail mid-write and these are its changes, resolve by hand, then re-run. Keep them — commit AND push, which publishes them to $KWT_REMOTE/$branch for everyone, unchecked:" \
      "        git -C '$KWT' add -- progress/ && git -C '$KWT' commit -m '…' && git -C '$KWT' push $KWT_REMOTE HEAD:$branch" \
      "        (SCOPED TO progress/ ON PURPOSE. This worktree sits ON the trunk and pushes TO the" \
      "         trunk, so 'add -A' here commits everything in it, including anything you or a" \
      "         command materialised in it, straight to $branch with nothing in between.)" \
      "      Or set them aside, recoverable with  git -C '$KWT' stash pop:  git -C '$KWT' stash push"
  fi

  # ── BEFORE DETACHING: commits on the attached branch that the remote lacks would be left
  #    reachable only from a local ref no board check reads and no sync updates. Refuse, and
  #    refuse separately when the branch has no remote counterpart: "there are unpublished
  #    commits" and "I cannot tell" are different claims.
  if ! git -C "$KWT" rev-parse --verify --quiet "$KWT_REMOTE/$branch" >/dev/null 2>&1; then
    detail="$(
      echo "       not exist — so whether '$branch' holds anything unpublished CANNOT BE DETERMINED."
      echo "       Detaching would land HEAD on the same commit, but this repair will not report"
      echo "       'nothing else changed' on a state it could not read."
      echo "       Worktree: $KWT"
      echo ""
      echo "  Its last commits (commit, author, subject), for you to judge:"
      git -C "$KWT" log --format='%h %an %s' -n 5 "refs/heads/$branch" 2>/dev/null | sed 's/^/    /'
    )"
    kit_refuse 1 kanban-wt-attached-no-remote \
      "Error: the kanban worktree ($KWT) is ATTACHED to '$branch', and $KWT_REMOTE/$branch does" \
      "$detail" \
      "Next: give the branch a remote counterpart, or detach deliberately by hand, then re-run:" \
      "        git -C '$KWT' push -u $KWT_REMOTE '$branch'      # then re-run" \
      "        git -C '$KWT' switch --detach                    # abandon the attachment as-is"
  fi

  local unpub
  unpub="$(git -C "$KWT" log --format='%h %an %s' "$KWT_REMOTE/$branch..refs/heads/$branch" 2>/dev/null || true)"
  if [ -n "$unpub" ]; then
    detail="$(
      echo "       that $KWT_REMOTE does not have. Detaching would leave them reachable only from a"
      echo "       local branch ref that no board check reads and the next sync does not update —"
      echo "       the orphaned-sibling state, recoverable afterwards only from 'git reflog --all'."
      echo "       Worktree: $KWT"
      echo ""
      echo "  Unpublished on '$branch' (commit, author, subject):"
      echo "$unpub" | sed 's/^/    /'
    )"
    kit_refuse 1 kanban-wt-attached-unpublished \
      "Error: the kanban worktree ($KWT) is ATTACHED to '$branch', and '$branch' carries commit(s)" \
      "$detail" \
      "Next: read each commit above first. A board op detaches this worktree before it commits and never commits on an attached branch, so these commits were made by hand, or another author's work reached this branch: publish none of them and abandon none of them, and ask (./scripts/ask.sh --role <role> \"<question>\" --default \"leave them and stop\")." \
      "      If the person who made them says to publish, the push below publishes ALL of them to $KWT_REMOTE/$branch for everyone, as they were made, with none of the checks the tool that makes such a commit runs; then re-run:" \
      "        git -C '$KWT' push $KWT_REMOTE '$branch':$branch"
  fi

  # With no target, `git switch --detach` detaches at the current commit: it moves no commits
  # and touches no tracked file.
  if git -C "$KWT" switch --detach --quiet 2>/dev/null; then
    echo "Repaired: the kanban worktree ($KWT) was attached to '$branch' — detached it (git switch --detach), landing back on the same commit. Nothing was left unpublished: that was CHECKED above, not assumed." >&2
    return 0
  fi

  echo "Error: the kanban worktree ($KWT) is attached to '$branch' and could not be detached." >&2
  return 1   # return-class: internal
}

# ---------------------------------------------------------------------------
# Sync: make the detached worktree match <remote>/<trunk>, the source of truth, by reset --hard
# to the fetched tip. It REFUSES first over what that reset would destroy:
#   - uncommitted TRACKED changes (`status --porcelain -uno`: exactly what reset --hard destroys;
#     untracked files survive it). Opt out: KWT_DISCARD_DIRTY=true (--discard-dirty).
#   - commits not on <remote>/<trunk>. No opt-out: discarding a commit is a hand command.
# ---------------------------------------------------------------------------
kwt_sync() {
  local detail
  # A rebase already open here is somebody's to finish, and the dirty guard below would misdescribe it.
  local _kwt_gd2; _kwt_gd2="$(git -C "$KWT" rev-parse --absolute-git-dir 2>/dev/null || true)"
  if [ -n "$_kwt_gd2" ] && { [ -d "$_kwt_gd2/rebase-merge" ] || [ -d "$_kwt_gd2/rebase-apply" ]; }; then
    kit_refuse 1 kanban-sync-rebase-in-progress \
      "Error: a rebase is in progress in the kanban worktree — refusing to sync over it." \
      "       Worktree: $KWT" \
      "Next: finish it by hand, then re-run this command: resolve the conflicts, git -C '$KWT' add -- progress/, git -C '$KWT' rebase --continue, then git -C '$KWT' push $KWT_REMOTE HEAD:$DEFAULT_BRANCH. Or give it up with git -C '$KWT' rebase --abort. The op changed nothing; it left the rebase as it found it."
  fi
  KWT_REBASE_OURS=true
  # Dirty guard FIRST: it is local, so it must run even when the fetch below fails.
  if [ "$KWT_DISCARD_DIRTY" != "true" ]; then
    local dirty untracked
    dirty="$(git -C "$KWT" status --porcelain --untracked-files=no 2>/dev/null || true)"
    if [ -n "$dirty" ]; then
      detail="$(
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
      )"
      kit_refuse 1 kanban-sync-dirty \
        "Error: the kanban worktree has uncommitted tracked changes — refusing to sync." \
        "$detail" \
        "Next: read the changes above first. A board op leaves uncommitted changes here only when it failed mid-write, so changes you did not see an op fail on are not an op's: ask (./scripts/ask.sh --role <role> \"<question>\" --default \"leave them and stop\")." \
        "      If you saw an op fail mid-write and these are its changes, resolve one of two ways, then re-run. Keep them — commit AND push (an unpushed commit BLOCKS the next sync until it lands), which publishes them to $KWT_REMOTE/$DEFAULT_BRANCH for everyone, unchecked:" \
        "        git -C '$KWT' add -- progress/ && git -C '$KWT' commit -m '…' && git -C '$KWT' push $KWT_REMOTE HEAD:$DEFAULT_BRANCH" \
        "        (SCOPED TO progress/ ON PURPOSE — 'add -A' in this worktree commits everything in" \
        "         it straight to $DEFAULT_BRANCH, with no branch and no gate in between.)" \
        "      Or set them aside, recoverable with  git -C '$KWT' stash pop:  git -C '$KWT' stash push"
    fi
  fi

  # Checked again at sync time; the tree is known clean (or opted out) by here.
  kwt__ensure_detached || return 1   # return-class: relay

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
  unpushed="$(git -C "$KWT" log --format='%h %an %s' "$KWT_REMOTE/$DEFAULT_BRANCH..HEAD" 2>/dev/null || true)"
  if [ -n "$unpushed" ]; then
    detail="$(
      echo "       Syncing would 'git reset --hard $KWT_REMOTE/$DEFAULT_BRANCH' and make them UNREACHABLE"
      echo "       from any ref — recoverable only from 'git reflog --all', and invisible to"
      echo "       check-board.sh once that has happened."
      echo "       Worktree: $KWT"
      echo ""
      echo "  Unpushed (commit, author, subject):"
      echo "$unpushed" | sed 's/^/    /'
    )"
    kit_refuse 1 kanban-sync-unpushed \
      "Error: the kanban worktree holds commit(s) that are NOT on $KWT_REMOTE/$DEFAULT_BRANCH — refusing to sync." \
      "$detail" \
      "Next: read each commit above first. The push below publishes ALL of them to $KWT_REMOTE/$DEFAULT_BRANCH for everyone, as they were made, with none of the checks the tool that makes such a commit runs." \
      "      Publish only if you saw an op of yours fail and name every one of these commits in its \"Commits that did NOT land\" list (or in the exit text of an op that ended after its commit while its push was still to run or in flight). The author column cannot tell you an op made a commit: a commit made by hand carries the same author, and can carry a move's subject. Then re-run:" \
      "        git -C '$KWT' fetch $KWT_REMOTE $DEFAULT_BRANCH && git -C '$KWT' rebase $KWT_REMOTE/$DEFAULT_BRANCH" \
      "        git -C '$KWT' push $KWT_REMOTE HEAD:$DEFAULT_BRANCH" \
      "      A commit that  git log $KWT_REMOTE/$DEFAULT_BRANCH..$DEFAULT_BRANCH  run in your main checkout also lists is local work of the main checkout, which this worktree was built from. It is not this tool's to publish: the person who made it publishes it from the main checkout when it is ready, never through this worktree. If you did not make it, ask (./scripts/ask.sh --role <role> \"<question>\" --default \"leave them and stop\")." \
      "      Any other commit — made by hand, or another author's — publish none of them and discard none of them: ask (./scripts/ask.sh --role <role> \"<question>\" --default \"leave them and stop\")."
  fi

  git -C "$KWT" reset --hard "$KWT_REMOTE/$DEFAULT_BRANCH" --quiet
  return 0
}

# kwt_commit <message> <what> [<next>] — commit what the caller staged in $KWT. A refusal (the commit-msg hook, a
# pre-commit gate) resets the WHOLE board worktree to its HEAD (`reset --hard`; untracked files stay) and ends the
# op, so the half-done change is not left staged for the next op to refuse over. That is safe because the sync
# refused tracked changes at the start and the lock excludes other ops; a hand edit made in the worktree during
# the op is lost. <what> is the noun the Error line names ("the move"); <next> (text only, no "Next:") replaces the default.
kwt_commit() {
  local msg="$1" what="${2:-this change}" nxt="${3:-}"
  if git -C "$KWT" commit -m "$msg" --quiet; then
    KWT_UNPUSHED="$(git -C "$KWT" rev-parse HEAD 2>/dev/null || true)"
    return 0
  fi
  if git -C "$KWT" reset -q --hard HEAD >/dev/null 2>&1; then
    kit_refuse 1 kanban-commit-refused \
      "Error: the commit in the kanban worktree was refused (the reason is printed above), so ${what} was not made." \
      "       The kanban worktree was put back as the sync left it (a hand edit made in it during this run is dropped with the staged change); nothing was changed on the trunk." \
      "Next: ${nxt:-remove what the refusal named (a tool trailer, a bad role prefix, a note the commit-msg hook rejects), then run the same command again.}"
  fi
  kit_refuse 1 kanban-commit-refused \
    "Error: the commit in the kanban worktree was refused (the reason is printed above), so ${what} was not made." \
    "       The kanban worktree could NOT be put back: it still holds the staged change, and every board op refuses until it is cleared." \
    "Next: git -C '$KWT' reset --hard HEAD   # then fix what the refusal named and run the same command again"
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
    KWT_UNPUSHED=""   # this text is the report; the exit must not repeat it
    echo "Error: push of HEAD → $KWT_REMOTE/$DEFAULT_BRANCH failed (remote likely advanced concurrently, or offline)." >&2
    echo "       The commit was made LOCALLY in the kanban worktree but is NOT on $KWT_REMOTE." >&2
    echo "       The next kanban op's sync now REFUSES rather than resetting over it (see kwt_sync)," >&2
    echo "       so it is not about to be destroyed — but nothing else will publish it either." >&2
    echo "Next: publish it once $KWT_REMOTE answers (a rebase that conflicts: resolve, git rebase --continue), then push:" >&2
    kwt__publish_next >&2
    return 1   # return-class: refusal
  fi

  # ── READ THE REF BACK: a push's exit status is not the commit being on the ref (a mirror can
  #    un-apply it). This is also the one guard that catches an ORPHANED SIBLING, a commit
  #    reachable from no ref, which `git status`, `<remote>/<trunk>..HEAD` and check-board.sh
  #    all miss.
  #    THE OPERAND IS THE POST-PUSH HEAD, NOT $pre_head: a won race rebases, which makes a new
  #    commit and orphans $pre_head on the success path.
  local post_head
  post_head="$(git -C "$KWT" rev-parse HEAD 2>/dev/null || true)"
  KWT_UNPUSHED=""   # pushed: what follows is judged by the ancestry check, which prints its own text
  if [ -n "$post_head" ]; then
    git -C "$KWT" fetch "$KWT_REMOTE" "$DEFAULT_BRANCH" --quiet 2>/dev/null || true
    if ! git -C "$KWT" merge-base --is-ancestor "$post_head" "$KWT_REMOTE/$DEFAULT_BRANCH" 2>/dev/null; then
      {
        echo "Error: the push reported success, but $(git -C "$KWT" rev-parse --short "$post_head" 2>/dev/null || echo "$post_head") is NOT an ancestor of $KWT_REMOTE/$DEFAULT_BRANCH."
        echo "       The commit this op made is not on the trunk. It is not lost — it is"
        echo "       UNREFERENCED, which is the state no board check can see."
        echo "Next: confirm what it carried, then replay it onto the trunk, before the next kanban op (reflog expiry is the only clock on it):"
        echo "         git -C '$KWT' log -1 $post_head          # confirm what it carried"
        echo "         git -C '$MAIN_ROOT' cherry-pick $post_head   # replay it onto the trunk"
        echo "       (cherry-pick preserves the original author and [Role]-prefixed subject.)"
        # Only $pre_head tells a rebased commit from a lost one.
        if [ -n "$pre_head" ] && [ "$pre_head" != "$post_head" ]; then
          echo "       Note: a push retry rebased this op's commit, so it began life as"
          echo "       $(git -C "$KWT" rev-parse --short "$pre_head" 2>/dev/null) — that sha is orphaned BY THE REBASE, not the one to replay."
        fi
      } >&2
      return 1   # return-class: refusal
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
      local ff_err ff_ahead
      if ff_err="$(git -C "$MAIN_ROOT" merge --ff-only "$KWT_REMOTE/$DEFAULT_BRANCH" --quiet 2>&1)"; then
        echo "Fast-forwarded the main checkout ($DEFAULT_BRANCH) to keep the board view live."
      else
        # Two causes, told apart by what git says: commits here the trunk lacks (diverged), or an
        # untracked file here that the trunk now tracks (a card just landed from this checkout's
        # working tree).
        ff_ahead="$(git -C "$MAIN_ROOT" rev-list --count "$KWT_REMOTE/$DEFAULT_BRANCH..HEAD" 2>/dev/null || echo 0)"
        if [ "$ff_ahead" != 0 ]; then
          echo "Note: main checkout could not be fast-forwarded (diverged: it has $ff_ahead commit(s) the trunk lacks); pull manually." >&2
        elif grep -qi -- 'untracked working tree files' <<< "$ff_err"; then
          echo "Note: main checkout could not be fast-forwarded: an untracked file in it is now tracked on the trunk and would be overwritten. Move or remove that file, then run  git pull --ff-only." >&2
        else
          echo "Note: main checkout could not be fast-forwarded (not diverged; git said: $(printf '%s' "$ff_err" | head -1)); pull manually." >&2
        fi
      fi
    else
      echo "Note: main checkout is on $DEFAULT_BRANCH with local changes — left untouched. If it holds an edited copy of a path just landed, discard that copy first (git checkout -- <path>; delete it if untracked); a pull is refused for it otherwise."
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
# or every slice reviewed or declined. A parent reaches qa_complete (or done) only when this prints nothing.
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
