#!/usr/bin/env bash
# KIT-CLASS: KIT — ad hoc metadata commits, routed the way move-issue.sh routes board moves. See process/EXTRACTION.md.
# Land a hand-made metadata edit — a register entry, a PRD, a dev/ record, an issue body's
# Handoff-to-QA section — on the trunk from WHEREVER your checkout sits, including a linked
# worktree on a branch of its own. It never commits in your checkout.
#
# The code-vs-metadata rule (process/MANUAL.md § The code-vs-metadata rule) sends metadata
# commits direct to the trunk. This script is that route from a linked worktree that is NOT on the
# trunk ref: it reads the named paths' CURRENT CONTENT out of your checkout, writes that content
# into the standing kanban worktree (already synced to the trunk tip), and commits + pushes there,
# the machinery move-issue.sh uses for a board move, for any metadata path instead of only progress/.
#
# YOUR CHECKOUT AFTER A LANDING is left as it was: a path you edited stays modified (or untracked)
# there although the trunk now holds it, and a later `git pull --ff-only` is refused for it until you
# discard your copy — `git checkout -- <path>`, or delete the file if it was untracked.
#
# Usage:
#   ./scripts/register-commit.sh --role <R> --message "..." <path>... [--discard-dirty]
#
#   <R> = @ROLE_SET@
#
#   --message   The commit subject. The script prefixes `[<R>] ` unless the message already begins
#               with the tag `[<R>]`; a tag followed by `:` or by no space is still that tag, and the
#               subject lands with it once and a space after it (`[PM]: x` lands as `[PM] x`). A
#               message beginning with another role's tag is refused.
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
#     on the trunk) is refused rather than silently skipped. Every path is checked before any is
#     staged, so a refusal leaves the kanban worktree as it found it.
#   - It will not land a STALE copy (exit 1, refusal register-checkout-stale, nothing changed on the
#     trunk): a path whose trunk copy gained a line since your checkout was cut, or since this
#     checkout last landed it, that your file lacks. Run it from a checkout at the trunk tip, or bring
#     the trunk's copy in and re-apply your edit. It does not catch a line the trunk REMOVED that
#     your copy keeps, or a path you delete whole; where your checkout shares no history with the
#     trunk and has landed nothing, it says on stderr that the guard did not run.
#   - It will not land a second copy of a card (exit 1, refusal register-card-moved): a new
#     `progress/**/<ID>-*.md` path while the trunk holds that id at another path. Make the edit in the
#     trunk's copy. A landing that also deletes the old path is a move and lands.
#   - It will not land a register entry that cites an answer the trunk lacks (exit 1, refusal
#     register-cites-unlanded-answer, nothing changed): a declared register path (REGISTERS in
#     scripts/check-board.sh) whose landing adds a line naming a question file in the project's question
#     channel, when that file's `**Answer` block is in your checkout and not on the trunk, and the file is
#     not among the paths. Add the question file to the same call: the answer lands, as given, with the
#     entry that cites it.
#
# Examples:
#   ./scripts/register-commit.sh --role PM --message "<PREFIX>-014: record D-NN answered" \
#     requirements/DECISIONS.md
#   ./scripts/register-commit.sh --role Dev --message "<PREFIX>-014: Handoff to QA notes" \
#     progress/dev_complete/<PREFIX>-014-slug.md
#
#   The `--role` value above IS AN EXAMPLE VALUE: this tree accepts the set rendered at `<R> =`,
#   which process/EXTRACTION.md § 2.4 locates. Substitute one of yours.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kanban-worktree.sh
. "$SCRIPT_DIR/lib/kanban-worktree.sh"
# A reader that closes our output (`| head -1`) must not stop us between the commit and the push.
kwt_hold_output

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
  kit_refuse_role_not_declared "$ROLE"
fi

# THE SUBJECT'S TAG: the script adds [<ROLE>]; a message that already begins with that tag keeps it
# once, and one that begins with another declared role's tag is refused before the worktree is touched
# (the commit would otherwise carry two seats' tags, or the wrong one).
case "$MSG" in
  "[${ROLE}]"|"[${ROLE}] "*) TAGGED=1 ;;
  "[${ROLE}]"*)
    # The tag with a delimiter other than a space: keep it once, followed by the space the commit-msg hook requires.
    _rest="${MSG#"[${ROLE}]"}"; _rest="${_rest#:}"; _rest="${_rest#"${_rest%%[! ]*}"}"
    MSG="[${ROLE}] ${_rest}"; TAGGED=1 ;;
  "["*"]"*)
    _lead="${MSG#\[}"; _lead="${_lead%%]*}"
    if [ "$_lead" != "$ROLE" ] && kit_role_member "$KIT_ROLE_SET" "$_lead"; then
      kit_refuse 1 register-message-tag-mismatch \
        "Error: --message begins with [$_lead] but --role is $ROLE; the subject would carry another seat's tag." \
        "Next: drop the tag from --message and let the script add [$ROLE], or re-run with --role $_lead if that is the hat you are wearing."
    fi
    TAGGED="" ;;
  *) TAGGED="" ;;
esac

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

# BEGIN unlanded-answer guard
# A register line that names a question file records a decision whose source the trunk must be able to
# show. Where the file's `**Answer` is only in this checkout, every arm of check-board reads clean over
# an entry citing nothing the trunk holds. The channel and the registers are read from the TRUNK's
# PROJECT.md and check-board.sh, never from the branch being landed. The channel is a directory with or
# without its trailing `/` (as scripts/ask.sh reads it); wherever the guard does not run it says why.
_ug_msgs=(); _ug_next=""
if ! { [ -r "$SCRIPT_DIR/lib/pm-field.sh" ] && [ -r "$SCRIPT_DIR/lib/decision-register.sh" ] \
       && . "$SCRIPT_DIR/lib/pm-field.sh" && . "$SCRIPT_DIR/lib/decision-register.sh"; }; then
  echo "Note: the unlanded-answer guard did not run: scripts/lib/pm-field.sh or scripts/lib/decision-register.sh did not load." >&2
else
  _ug_regs="$(kit_registers_declared "$KWT/scripts/check-board.sh" 2>/dev/null || true)"
  _ug_dir=""; _ug_skip=""
  if [ ! -f "$KWT/PROJECT.md" ]; then
    _ug_skip="the trunk has no PROJECT.md, so no channel is declared"
  else
    _ug_line="$(kit_pm_field '\\*\\*Their channel:\\*\\*' "$KWT/PROJECT.md")"
    if kit_pm_blank "$_ug_line"; then
      _ug_skip="PROJECT.md on the trunk declares no channel"
    else
      _ug_tok="$(kit_pm_channel_token "$_ug_line")"
      _ug_rc=0; _ug_why="$(kit_pm_channel_dir "$CALLER_ROOT" "$_ug_tok")" || _ug_rc=$?
      if [ "$_ug_rc" -eq 0 ]; then _ug_dir="$_ug_why"; else _ug_skip="$_ug_why"; fi
    fi
  fi
  if [ -z "$_ug_regs" ]; then
    echo "Note: the unlanded-answer guard did not run: no REGISTERS declaration could be read from scripts/check-board.sh on the trunk." >&2
  elif [ -z "$_ug_dir" ]; then
    echo "Note: the unlanded-answer guard did not run: $_ug_skip." >&2
  else
    _ug_added="$(mktemp)"
    for rel in "${PATHS[@]}"; do
      _ug_is=""
      while IFS='|' read -r _ug_rp _ug_m _ug_s; do
        if [ -n "$_ug_rp" ] && [ "$_ug_rp" = "$rel" ]; then _ug_is=1; fi
      done <<UG_REGS
$_ug_regs
UG_REGS
      [ -n "$_ug_is" ] && [ -f "$CALLER_ROOT/$rel" ] || continue
      _ug_base=/dev/null; [ ! -f "$KWT/$rel" ] || _ug_base="$KWT/$rel"
      { diff "$_ug_base" "$CALLER_ROOT/$rel" || true; } | sed -n 's/^> //p' >"$_ug_added"
      for _ug_q in "$CALLER_ROOT/$_ug_dir"/*-ask.md; do
        [ -f "$_ug_q" ] || continue
        _ug_qrel="$_ug_dir/${_ug_q##*/}"
        grep -qF -- "$_ug_qrel" "$_ug_added" || continue
        grep -qE '^\*\*Answer' "$_ug_q" || continue
        if [ -f "$KWT/$_ug_qrel" ] && grep -qE '^\*\*Answer' "$KWT/$_ug_qrel"; then continue; fi
        _ug_in=""
        for _ug_p in "${PATHS[@]}"; do if [ "$_ug_p" = "$_ug_qrel" ]; then _ug_in=1; fi; done
        [ -z "$_ug_in" ] || continue
        case " $_ug_next " in *" '$_ug_qrel' "*) continue ;; esac
        _ug_next="${_ug_next:+$_ug_next }'$_ug_qrel'"
        _ug_msgs+=("Error: '$rel' adds a line naming '$_ug_qrel', whose **Answer is in your checkout and not on the trunk — the entry would cite a decision the trunk cannot show.")
      done
    done
    rm -f "$_ug_added"
    if [ ${#_ug_msgs[@]} -gt 0 ]; then
      kit_refuse 1 register-cites-unlanded-answer \
        "${_ug_msgs[@]}" \
        "       Nothing was changed on the trunk." \
        "Next: add $_ug_next to this call so the answer lands with the entry that cites it, then re-run."
    fi
  fi
fi
# END unlanded-answer guard

# Every path must exist on one side BEFORE any is staged: a refusal part-way would leave the earlier
# paths staged in the kanban worktree, which every other board op then refuses to touch.
for rel in "${PATHS[@]}"; do
  if [ ! -e "$CALLER_ROOT/$rel" ] && [ ! -e "$KWT/$rel" ]; then
    kit_refuse 1 path-not-found \
      "Error: '$rel' exists in neither your checkout ($CALLER_ROOT) nor the trunk ($KWT) — nothing to commit for it." \
      "Next: check the path (relative to your checkout's root) and write the file there before re-running."
  fi
done

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

# THE COMMIT IS JUDGED BY THE HOOK IN $KWT, a copy of the trunk with this call's files laid over it, so a
# call that carries the role's own declaration is judged by the tree it will commit. A refusal first puts
# the worktree back as the sync left it. The subshell keeps kit_refuse's exit from skipping that.
if command -v kit_require_role_on_trunk >/dev/null 2>&1; then
  _rc_chk=0
  ( kit_require_role_on_trunk "$KWT" "$ROLE" "${KWT_SYNCED:-false}" "$KWT_REMOTE/$DEFAULT_BRANCH" "--role $ROLE" ) || _rc_chk=$?
  if [ "$_rc_chk" -ne 0 ]; then
    for rel in "${CHANGED[@]}"; do
      # LITERAL pathspecs: a name like docs/[a].md is a glob to git, and would match a tracked sibling.
      GIT_LITERAL_PATHSPECS=1 git -C "$KWT" reset -q -- "$rel" >/dev/null 2>&1 || true
      GIT_LITERAL_PATHSPECS=1 git -C "$KWT" checkout -q -- "$rel" >/dev/null 2>&1 || rm -f "$KWT/$rel"
    done
    exit "$_rc_chk"   # exit-class: internal
  fi
fi

if [ -n "$TAGGED" ]; then MESSAGE="$MSG"; else MESSAGE="[${ROLE}] ${MSG}"; fi
git -C "$KWT" commit -m "$MESSAGE" --quiet
SHA=$(git -C "$KWT" rev-parse --short HEAD)
echo "Commit: ${SHA} — made locally in the kanban worktree; publishing to the trunk next."
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
# Your checkout still holds the edited copy of each path: name the ones git sees as modified or
# untracked, because a later pull is refused for them until the copy is discarded.
for rel in "${CHANGED[@]}"; do
  [ -e "$CALLER_ROOT/$rel" ] || continue
  _st="$(git -C "$CALLER_ROOT" status --porcelain -- "$rel" 2>/dev/null | head -1 | cut -c1-2 || true)"
  case "$_st" in
    "") ;;
    "??") echo "Note: your checkout still holds an untracked '$rel' that the trunk now tracks; delete it (rm '$rel') or a pull is refused." ;;
    [!\ ]*) echo "Note: your checkout still holds a staged copy of '$rel'; discard it (git restore --staged --worktree -- '$rel') or a pull is refused." ;;
    *) echo "Note: your checkout still holds an edited copy of '$rel'; discard it (git checkout -- '$rel') or a pull is refused." ;;
  esac
done
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
