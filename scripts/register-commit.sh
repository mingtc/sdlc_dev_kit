#!/usr/bin/env bash
# KIT-CLASS: KIT — ad hoc metadata commits, routed the way move-issue.sh routes board moves. See process/EXTRACTION.md.
# Land a hand-made metadata edit — a register entry, a PRD, a dev/ record, an issue body's
# Handoff-to-QA section — on the trunk from WHEREVER your checkout sits, including a linked
# worktree on a branch of its own. It never commits in your checkout.
#
# WHY THIS EXISTS: the code-vs-metadata rule (process/MANUAL.md § The code-vs-metadata rule) is
# mechanical — metadata commits direct to the trunk — but nothing gave a coordinator sitting in a
# linked worktree that is NOT on the trunk ref a way to obey it short of a bare `git commit` on
# the wrong branch. This script is that route: it reads the named paths' CURRENT CONTENT out of
# your checkout, writes that content into the standing kanban worktree (already synced to the
# trunk tip), and commits + pushes there — exactly the machinery move-issue.sh already uses for a
# board move, generalized to any metadata path instead of only progress/.
#
# Usage:
#   ./scripts/register-commit.sh --role <R> --message "..." <path>... [--discard-dirty]
#
#   <R> = @ROLE_SET@
#
#   <path>...   One or more paths, relative to your checkout's root, whose CURRENT ON-DISK
#               CONTENT (tracked or not, staged or not — this reads the working tree, not the
#               index) is what lands. A path absent from your checkout but present on the trunk
#               is taken as a DELETION. Every path must be metadata: this script does not itself
#               check the code-vs-metadata split (your adapter's own list does that); it is the
#               route for the metadata side, not a bypass for the code side.
#
# --discard-dirty   If the kanban worktree holds uncommitted tracked changes (a half-applied
#                    prior op), discard them instead of aborting. Mirrors move-issue.sh's flag;
#                    read its warning before using it — the worktree is shared between lanes.
#
# What it will NOT do:
#   - It will not stop you from calling it for a CODE path — that refusal belongs to the
#     pre-commit hook (scripts/githooks/pre-commit), which catches a bare `git commit` of
#     metadata-only paths off the trunk. This script is the route that refusal names.
#   - It will not invent content: a path that does not exist ANYWHERE (not in your checkout, not
#     on the trunk) is refused rather than silently skipped.
#   - It will not land a STALE copy (exit 1, refusal register-checkout-stale, nothing changed on the
#     trunk): a path whose trunk copy gained a line since your checkout was cut, or since this
#     checkout last landed it, that your file lacks. Run it from a checkout at the trunk tip, or bring
#     the trunk's copy in and re-apply your edit. It does not catch a line the trunk REMOVED that
#     your copy keeps, or a path you delete whole; where your checkout shares no history with the
#     trunk and has landed nothing, it says on stderr that the guard did not run.
#   - It will not land a second copy of a card (exit 1, refusal register-card-moved): a new
#     `progress/**/<ID>-*.md` path while the trunk holds that id at another path. Make the edit in the
#     trunk's copy. A landing that also deletes the old path is a move and lands.
#
# Examples:
#   ./scripts/register-commit.sh --role PM --message "<PREFIX>-014: record D-NN answered" \
#     requirements/DECISIONS.md
#   ./scripts/register-commit.sh --role Dev --message "<PREFIX>-014: Handoff to QA notes" \
#     progress/dev_complete/<PREFIX>-014-slug.md
#
#   The `--role` value above IS AN EXAMPLE VALUE: this tree accepts the set rendered at `<R> =`,
#   from ROLE_PREFIXES in scripts/githooks/commit-msg. Substitute one of yours.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kanban-worktree.sh
. "$SCRIPT_DIR/lib/kanban-worktree.sh"

# --help renders this file's header block; scripts/lib/usage.sh states the window rule.
# shellcheck source=lib/usage.sh
. "$SCRIPT_DIR/lib/usage.sh"

# Refusals go through the one helper: a `refusal=` record and a Next: line.
# shellcheck source=lib/refuse.sh
. "$SCRIPT_DIR/lib/refuse.sh"

# shellcheck source=lib/card-field.sh
. "$SCRIPT_DIR/lib/card-field.sh"

# shellcheck source=lib/role-set.sh
[ -r "$SCRIPT_DIR/lib/role-set.sh" ] && . "$SCRIPT_DIR/lib/role-set.sh"

# ── THE PROGRESS RECORD — OPTIONAL (process/contracts/progress-record.md), same guard shape
#    move-issue.sh uses: absent, every call is a no-op.
# shellcheck source=lib/progress-record.sh
if [ ! -r "$SCRIPT_DIR/lib/progress-record.sh" ] || ! . "$SCRIPT_DIR/lib/progress-record.sh" \
   || ! command -v kit_progress >/dev/null 2>&1; then
  kit_progress() { :; }
fi

usage() {   # the path is an ARGUMENT — see lib/usage.sh
  local roles tok='@ROLE_SET@'
  if command -v kit_role_display >/dev/null 2>&1; then
    roles="$(kit_role_display "$SCRIPT_DIR/.." || true)"
  fi
  [ -n "${roles:-}" ] \
    || roles='as declared in scripts/githooks/commit-msg (ROLE_PREFIXES) — scripts/lib/role-set.sh is absent, so not listed'
  kit_usage "${BASH_SOURCE[0]}" | ROLE_SET_DISPLAY="$roles" awk -v t="$tok" '
    { i = index($0, t)
      if (i) print substr($0, 1, i-1) ENVIRON["ROLE_SET_DISPLAY"] substr($0, i + length(t))
      else   print }'
}

# --help ALWAYS SUCCEEDS, in any position, before any argument is interpreted.
for _a in "$@"; do case "$_a" in -h|--help) usage; exit 0 ;; esac; done

ROLE=""; MSG=""; PATHS=()
# need_val — byte-identical to every other script's copy (process/EXTRACTION.md § 2.4-adjacent).
need_val() {
  [ "$#" -ge 2 ] || { echo "Error: $1 requires a value." >&2; exit 2; }
}

while [ $# -gt 0 ]; do
  case "$1" in
    --role) need_val "$@"; ROLE="$2"; shift 2 ;;
    --message) need_val "$@"; MSG="$2"; shift 2 ;;
    --discard-dirty) KWT_DISCARD_DIRTY=true; shift ;;
    -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) PATHS+=("$1"); shift ;;
  esac
done

[ -n "$MSG" ]  || { echo "Error: --message is required." >&2; usage >&2; exit 2; }
[ ${#PATHS[@]} -gt 0 ] || { echo "Error: at least one <path> is required." >&2; usage >&2; exit 2; }

# Derived by lib/role-set.sh kit_role_resolve; this literal is only its stamped default (see
# there) — SAME SHAPE move-issue.sh uses, validated BEFORE the worktree is touched: an
# unvalidated role would otherwise reach the commit subject and the hook would reject it
# mid-operation, after the kanban worktree already holds the change.
ROLE_SET_DEFAULT='PM|Dev|QA|Refactorer|UIDesigner|Orchestrator|Architect'
if command -v kit_role_resolve >/dev/null 2>&1; then
  kit_role_resolve "$SCRIPT_DIR/.." "$ROLE_SET_DEFAULT"
else
  KIT_ROLE_SET="$ROLE_SET_DEFAULT"
  KIT_ROLE_SRC="THE KIT'S FALLBACK SET — scripts/lib/role-set.sh is absent, so this project's declared set could not be read"
  KIT_ROLE_DEFAULTED=1
fi
[ -z "${KIT_ROLE_DEFAULTED:-}" ] \
  || echo "Note: --role is being checked against $KIT_ROLE_SRC" >&2
if [ -z "$ROLE" ]; then
  echo "Error: --role is required ($KIT_ROLE_SET)." >&2; usage >&2; exit 2
fi
if ! kit_role_member "$KIT_ROLE_SET" "$ROLE"; then
  kit_refuse 1 role-not-declared \
    "Error: --role must be $KIT_ROLE_SET (got '$ROLE')." \
    "       That set is $KIT_ROLE_SRC." \
    "Next: re-run with --role set to one of: $KIT_ROLE_SET."
fi

# Resolve repo root + trunk (works from any worktree, on any branch).
kwt_resolve

# THE CALLER'S ROOT: where the named paths' current content is read FROM. Resolved the same
# way kwt_resolve finds the main root, so this works whether you are in the main checkout, a
# feature worktree, or .kanban-wt itself.
CALLER_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$CALLER_ROOT" ] || kit_refuse 1 not-a-git-repository \
  "Error: not inside a git repository." \
  "Next: run it from inside the project's checkout (cd into the project), then re-run."

# Acquire the lock BEFORE touching the worktree (never a half-applied write).
kwt_lock

# Bootstrap (idempotent) + sync the worktree to <remote>/<trunk>, so what we overlay onto it
# lands ON TOP OF the current trunk tip, not some stale snapshot.
kwt_bootstrap
kwt_sync

# STALE-CHECKOUT GUARD: the overlay below lands your WHOLE file, so a checkout cut before the trunk
# changed a path would silently delete what the trunk gained. It is stale when some line the trunk
# ADDED since the base is absent from your file. The base is the content this checkout last landed
# for the path when it landed one (a first landing leaves the edit uncommitted here, so the merge-base
# stays old and a second edit would otherwise read as conflicting with its own first), else the
# merge-base's copy. A deliberate removal, or a retirement that moves an id into a Retired table,
# adds nothing to the trunk's side and still lands. Not checked: a line the trunk REMOVED that your
# copy keeps, and a path you delete whole.
TIP="$(git -C "$KWT" rev-parse HEAD 2>/dev/null || true)"
CALLER_HEAD="$(git -C "$CALLER_ROOT" rev-parse HEAD 2>/dev/null || true)"
BASE=""
[ -z "$TIP" ] || [ -z "$CALLER_HEAD" ] || BASE="$(git -C "$KWT" merge-base "$CALLER_HEAD" "$TIP" 2>/dev/null || true)"
LANDED_LOG="$(git -C "$CALLER_ROOT" rev-parse --git-path register-commit-landed 2>/dev/null || true)"
case "$LANDED_LOG" in /*|"") ;; *) LANDED_LOG="$CALLER_ROOT/$LANDED_LOG" ;; esac
STALE_LINE=""; GUARD_SKIPPED=""
_stale_path() {   # $1 = rel; 0 when the trunk added a line your file lacks (the first is left in STALE_LINE)
  local rel="$1" d="$KWT/$1" tmp lb="" have=""
  [ -f "$CALLER_ROOT/$rel" ] && [ -f "$d" ] || return 1
  tmp="$(mktemp -d)"
  if [ -n "$LANDED_LOG" ] && [ -f "$LANDED_LOG" ]; then
    lb="$(awk -F'\t' -v p="$rel" '$2==p { b=$1 } END { print b }' "$LANDED_LOG" 2>/dev/null || true)"
    if [ -n "$lb" ] && git -C "$KWT" cat-file blob "$lb" >"$tmp/base" 2>/dev/null; then have=1; fi
  fi
  if [ -z "$have" ] && [ -n "$BASE" ]; then
    git -C "$KWT" show "$BASE:$rel" >"$tmp/base" 2>/dev/null || : >"$tmp/base"; have=1
  fi
  if [ -z "$have" ]; then
    GUARD_SKIPPED="${GUARD_SKIPPED}${GUARD_SKIPPED:+ }$rel"; rm -rf "$tmp"; return 1
  fi
  { diff "$tmp/base" "$d" || true; } | sed -n 's/^> //p' >"$tmp/added"
  # A blank or whitespace-only line carries nothing to lose, and an empty result reads as "not stale": skip them.
  STALE_LINE="$(awk 'FILENAME == ARGV[1] { s[$0]=1; next } $0 !~ /^[[:space:]]*$/ && !($0 in s) { print; exit }' "$CALLER_ROOT/$rel" "$tmp/added")"
  rm -rf "$tmp"
  [ -n "$STALE_LINE" ]
}
# A CARD IS ITS ID, NOT ITS PATH: creating a `progress/**/<ID>-*.md` file while the trunk already holds
# that id at another path would put the card in two columns. A path the same landing deletes is a move,
# not a second copy. The trunk's path is where the edit belongs.
_card_elsewhere() {   # $1 = rel; prints the trunk's path for the id when the landing would duplicate it
  local rel="$1" id f other p gone
  case "$rel" in progress/*.md) ;; *) return 1 ;; esac
  [ -f "$CALLER_ROOT/$rel" ] && [ ! -e "$KWT/$rel" ] || return 1
  id="$(kit_card_id_of_path "$rel")"; [ -n "$id" ] || return 1
  while IFS= read -r f; do
    other="${f#"$KWT"/}"
    [ "$(kit_card_id_of_path "$other")" = "$id" ] || continue
    gone=""
    for p in "${PATHS[@]}"; do [ "$p" = "$other" ] && [ ! -e "$CALLER_ROOT/$p" ] && gone=1; done
    [ -n "$gone" ] || { printf '%s\n' "$other"; return 0; }
  done < <(find "$KWT/progress" -type f \( -name "${id}.md" -o -name "${id}-*.md" \) 2>/dev/null | sort)
  return 1
}
for rel in "${PATHS[@]}"; do
  if _trunk_path="$(_card_elsewhere "$rel")"; then
    kit_refuse 1 register-card-moved \
      "Error: '$rel' would create a second copy of a card the trunk already holds at '$_trunk_path'." \
      "       Nothing was changed on the trunk." \
      "Next: make the edit in the trunk's copy — bring '$_trunk_path' into your checkout, re-apply your edit there, and land that path."
  fi
done
for rel in "${PATHS[@]}"; do
  if _stale_path "$rel" && ! cmp -s "$CALLER_ROOT/$rel" "$KWT/$rel"; then
    kit_refuse 1 register-checkout-stale \
      "Error: your copy of '$rel' lacks a line the trunk gained since your checkout was cut — landing it would delete that work." \
      "       The first such line: ${STALE_LINE:0:160}" \
      "       Nothing was changed on the trunk." \
      "Next: bring the trunk's '$rel' into your checkout (or run from a checkout at the trunk tip), re-apply your edit on top of it, re-run."
  fi
done
[ -z "$GUARD_SKIPPED" ] \
  || echo "Note: the stale-checkout guard did not run for: $GUARD_SKIPPED (your checkout shares no history with the trunk and has landed nothing)." >&2

CHANGED=()
for rel in "${PATHS[@]}"; do
  src="$CALLER_ROOT/$rel"
  dst="$KWT/$rel"
  if [ -e "$src" ]; then
    if [ -f "$dst" ] && cmp -s "$src" "$dst" 2>/dev/null; then
      continue   # identical — nothing to carry for this path
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    git -C "$KWT" add -- "$rel"
    CHANGED+=("$rel")
  else
    # Present on neither side → refuse rather than silently doing nothing for it.
    if [ ! -e "$dst" ]; then
      kit_refuse 1 path-not-found \
        "Error: '$rel' exists in neither your checkout ($CALLER_ROOT) nor the trunk ($KWT) — nothing to commit for it." \
        "Next: check the path (relative to your checkout's root) and write the file there before re-running."
    fi
    # Absent from the caller, present on the trunk → a deletion.
    git -C "$KWT" rm -q -- "$rel"
    CHANGED+=("$rel")
  fi
done

if [ ${#CHANGED[@]} -eq 0 ]; then
  kit_refuse 1 nothing-to-commit \
    "Nothing to commit: every named path already matches the trunk's tip." \
    "  Paths checked: ${PATHS[*]}" \
    "Next: edit the files first, or name the paths you actually changed; if the edit already landed, there is nothing to do."
fi

MESSAGE="[${ROLE}] ${MSG}"
git -C "$KWT" commit -m "$MESSAGE" --quiet
SHA=$(git -C "$KWT" rev-parse --short HEAD)
echo "Commit: ${SHA} — made locally in the kanban worktree, NOT yet published."
echo "Paths:  ${CHANGED[*]}"

# paths= must be ONE TOKEN (progress-record.md § Reserved extra keys' "collapsed to one token"
# rule applies to every extra, not only the reserved ones — the record is read back by splitting
# on spaces): comma-joined, never CHANGED[*]'s space-joined form.
_paths_tok="$(IFS=,; echo "${CHANGED[*]}")"
kit_progress "register-commit.sh" status "landed ${#CHANGED[@]} metadata path(s) as ${ROLE}" "paths=${_paths_tok}" >/dev/null 2>&1 || true

# A push failure AFTER the local commit is FATAL, same as move-issue.sh: propagate it rather
# than reporting success on a commit that never reached the remote.
kwt_finalize || exit 1   # exit-class: internal
echo "Published: ${KWT_LANDED_SHA:-<unknown>} on ${DEFAULT_BRANCH} — \"${MESSAGE}\""
# Remember what this checkout landed, per path: the base of its next stale check.
if [ -n "$LANDED_LOG" ]; then
  for rel in "${CHANGED[@]}"; do
    if [ -f "$CALLER_ROOT/$rel" ]; then
      _b="$(git -C "$KWT" hash-object -- "$rel" 2>/dev/null || true)"
      [ -z "$_b" ] || printf '%s\t%s\n' "$_b" "$rel" >>"$LANDED_LOG" 2>/dev/null || true
    fi
  done
fi
exit 0
