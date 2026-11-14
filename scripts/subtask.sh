#!/usr/bin/env bash
# KIT-CLASS: KIT — Orchestrator decomposition into subtask issues. See process/EXTRACTION.md.
# Orchestrator subtask tooling — mirrors move-issue.sh semantics WITHIN the hidden
# subtask tree `progress/subtasks/<parent>/<status>/`. Subtasks do NOT consume the
# issue-id integer stream — ids are <PARENT>-sM — and they live OFF the main board so
# the PM's backlog stays pristine. The parent stays on the main board and advances to
# qa_complete only when every subtask reaches qa_complete or is declined with its reason:
# move-issue.sh and finish-pr.sh refuse it otherwise, and archive.sh refuses to retire an open slice. Commits carry the seat's tag:
# SUBTASK_ROLE for `new`, --role for `move` (both default Orchestrator).
#
# This shares the SAME machinery as move-issue.sh / finish-pr.sh:
# scripts/lib/kanban-worktree.sh. Every git op (create / git mv / Activity append /
# commit / push) happens inside the standing detached `.kanban-wt/` worktree pinned
# to the trunk — the operator's checkout is NEVER switched and any working-tree
# state is irrelevant.
#
# Usage:
#   ./scripts/subtask.sh new <PARENT-ID> <suffix> <slug> --title "..." [--prd @PRD_PREFIX@-NNN] [--stories a,b] [--plan path] [--size S]
#       → creates progress/subtasks/<PARENT-ID>/todo/<PARENT-ID>-<suffix>-<slug>.md
#         from .claude/templates/SUBTASK.template.md, fills frontmatter (prd: the parent's
#         unless --prd is given), commits as SUBTASK_ROLE.
#   ./scripts/subtask.sh move <PARENT-ID>-<suffix> <target> [--role <R>] [--note "..."] [--discard-dirty]
#       → git mv within the subtask tree + append Activity + commit "[ROLE] <id> → <target>: NOTE".
#
#   <R> = @ROLE_SET@
#
# Target folders: @SUBTASK_TARGETS@
# (blocked and declined each need --note, as in move-issue.sh: the blocker, or the reason a slice
# will not be done, is the record)
#
#   SUBTASK_ROLE   the seat this script commits as (default: Orchestrator). The tag
#                  is CHECKED against your declared role set before anything moves.
#                  Read by the `new` arm; the `move` arm takes an explicit `--role` instead
#                  and defaults to Orchestrator without consulting this variable.
#
# --discard-dirty: if the kanban worktree has uncommitted tracked changes, discard
#   them instead of aborting the sync. Read move-issue.sh's warning about it first:
#   the worktree is shared between lanes. (There is deliberately no --no-commit:
#   uncommitted work there blocks every later board operation.)
#
# Examples:
#   ./scripts/subtask.sh new <PREFIX>-014 s1 anchor-resolver --title "Floor: anchor resolution"
#   ./scripts/subtask.sh move <PREFIX>-014-s1 in_progress --role Dev --note "Pickup."
#   ./scripts/subtask.sh move <PREFIX>-014-s1 dev_complete --role Dev --note "Ready for review; gates green."
#
#   The `--role` value above IS AN EXAMPLE VALUE: this tree accepts the set rendered at `<R> =`,
#   which process/EXTRACTION.md § 2.4 locates. Substitute one of yours.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# THE TOOL THAT REVIEWS A SLICE IS THE TRUNK'S COMMITTED COPY, as finish-pr.sh's is for a landing: a
# branch, or a local edit, may not rewrite the checks that judge it. The comparison is plain shell and
# runs BEFORE any file below is sourced, so it leans on none of them; the trunk is resolved as
# lib/kanban-worktree.sh's kwt_resolve does. THE LIST IS DERIVED, never counted: every file this script
# sources, directly or through a library, plus the script it reads a declaration from. The self-test
# fails when a sourced file is missing from it.
_held_files="
check-board.sh
config.sh
lib/addon-check.sh
lib/agent-record.sh
lib/attrib-trailer.sh
lib/board-properties.sh
lib/branch-rev.sh
lib/card-field.sh
lib/card-head.sh
lib/decision-register.sh
lib/exit-trap.sh
lib/glob-array.sh
lib/hold-output.sh
lib/kanban-worktree.sh
lib/progress-record.sh
lib/push-retry.sh
lib/qa-gate.sh
lib/refuse.sh
lib/role-set.sh
lib/status-folders.sh
lib/usage.sh
subtask.sh
"
_held_help=false
for _a in "$@"; do case "$_a" in -h|--help) _held_help=true ;; esac; done   # a usage request always succeeds
_held_rem="${KWT_REMOTE:-origin}"
_held_trunk="$(git symbolic-ref --short "refs/remotes/$_held_rem/HEAD" 2>/dev/null || true)"
_held_trunk="${_held_trunk#"$_held_rem"/}"
[ -n "$_held_trunk" ] || _held_trunk="$(git config --get init.defaultBranch 2>/dev/null || true)"
[ -n "$_held_trunk" ] || _held_trunk="${KWT_TRUNK_LAST_RESORT:-main}"
# git runs from the working directory, the repository this tool goes on to change, not the one this
# copy of scripts/ sits in. Its own fetch: the comparison cannot wait for kwt_sync. A failed fetch
# (offline) compares against the last one's ref.
[ "$_held_help" = true ] || git fetch "$_held_rem" "$_held_trunk" --quiet >/dev/null 2>&1 || true
_held_off=""; _held_noref=false
# With no trunk ref to read there is nothing to compare with, and that is not a pass: it is decided
# here, before anything is sourced, so nothing sourced can change it. It is a refusal whenever the
# repository holds a commit; with no commit at all, an empty repository, the bootstrap refuses it by name.
if [ "$_held_help" = true ]; then
  :
elif git rev-parse --verify --quiet "$_held_rem/$_held_trunk^{commit}" >/dev/null 2>&1; then
  for _f in $_held_files; do
    # config.sh alone may be gone: its absence is this script's own seam refusal, which names it.
    [ "$_f" != config.sh ] || [ -e "$SCRIPT_DIR/$_f" ] || continue
    if git cat-file -e "$_held_rem/$_held_trunk:scripts/$_f" 2>/dev/null; then
      [ -e "$SCRIPT_DIR/$_f" ] && git show "$_held_rem/$_held_trunk:scripts/$_f" 2>/dev/null | cmp -s - "$SCRIPT_DIR/$_f" 2>/dev/null \
        || _held_off="$_held_off scripts/$_f"
    elif [ -e "$SCRIPT_DIR/$_f" ]; then   # here, and not on the trunk
      _held_off="$_held_off scripts/$_f"
    fi
  done
elif ! _held_rl="$(git rev-list -n 1 --all 2>/dev/null)" || [ -n "$_held_rl" ]; then   # a failing rev-list is not an empty one
  _held_noref=true
fi
if [ -n "$_held_off" ] || [ "$_held_noref" = true ]; then
  if [ "$_held_noref" = true ]; then
    _held_err="Error: cannot tell whether the tool that reviews a slice here is ${_held_trunk}'s committed copy: no ${_held_rem}/${_held_trunk} ref could be read
       (the fetch failed, or this directory is not a clone of the project). NOTHING WAS CHANGED. (lander-not-trunk-copy)"
    _held_next="Next: fetch the trunk (git fetch ${_held_rem} ${_held_trunk}); if ${_held_trunk} is not your trunk, set it with
       git remote set-head ${_held_rem} <your-trunk>; then re-run."
  else
    _held_err="Error: the tool that reviews a slice here is not ${_held_trunk}'s committed copy — these differ from
       ${_held_rem}/${_held_trunk} (changed on this branch or locally, or older than the trunk's):
      ${_held_off}
       A branch or a local edit may not change the tool that judges it. NOTHING WAS CHANGED. (lander-not-trunk-copy)"
    _held_next="Next: bring the scripts here to the trunk's. A branch that is only behind them (it changed none of
       them) is brought up to date in place:  git fetch ${_held_rem} && git rebase ${_held_rem}/${_held_trunk}
       Otherwise run the trunk's copy of this command, from the main checkout on ${_held_trunk}, freshly pulled:
         git switch ${_held_trunk} && git pull --ff-only && ./scripts/subtask.sh <the same arguments>
       If the trunk's copy cannot do this, ask the human: there is no override."
  fi
  # NOTHING IS SOURCED HERE, not even the refusal helper: a library that has just failed the comparison
  # could redefine `exit`. So the refusal is printed in plain shell, and its progress record is not written.
  printf '%s\n%s\n' "$_held_err" "$_held_next" >&2
  exit 1   # exit-class: internal
fi
unset _held_files _held_help _held_rem _held_trunk _held_off _held_noref _held_rl _a _f

# shellcheck source=lib/kanban-worktree.sh
. "$SCRIPT_DIR/lib/kanban-worktree.sh"
# A reader that closes our output (`| head -1`) must not stop us between the commit and the push.
kwt_hold_output

# shellcheck source=lib/refuse.sh
. "$SCRIPT_DIR/lib/refuse.sh"
# The `forks:` precondition's register resolution — the SAME parser finish-pr.sh and
# check-board.sh arm [l] use.
# shellcheck source=lib/decision-register.sh
. "$SCRIPT_DIR/lib/decision-register.sh"
# The QA Verdict / forks: / Ablation card checks — the SAME parser finish-pr.sh calls for a
# landing card, called here for a slice's own card before `move <id> qa_complete`.
# shellcheck source=lib/qa-gate.sh
. "$SCRIPT_DIR/lib/qa-gate.sh"
# shellcheck source=lib/branch-rev.sh
. "$SCRIPT_DIR/lib/branch-rev.sh"
# shellcheck source=lib/card-field.sh
. "$SCRIPT_DIR/lib/card-field.sh"
# The same-agent check finish-pr.sh runs (process/contracts/agent-record.md).
# shellcheck source=lib/agent-record.sh
. "$SCRIPT_DIR/lib/agent-record.sh"

# GUARDED: usage() renders the role set through this library, and a usage request must
# succeed (issue-creation.md § 3). The operational path fails loudly without it.
# shellcheck source=lib/role-set.sh
[ -r "$SCRIPT_DIR/lib/role-set.sh" ] && . "$SCRIPT_DIR/lib/role-set.sh"

# ── A USAGE REQUEST IS ANSWERED BEFORE THE SEAM IS SOURCED ─────────────────────
# (process/contracts/issue-creation.md § 3: a usage request always succeeds), in any position,
# before any argument is interpreted. usage() reads the seam itself, guarded, to render the
# prefix: its absence must not turn a usage request into a refusal.
# shellcheck source=lib/usage.sh
. "$SCRIPT_DIR/lib/usage.sh"

# The subtask lifecycle is the board's status folders (lib/status-folders.sh) MINUS done/, which is
# deliberately absent: a subtask tree reaches its terminal home under progress/done/subtasks/<parent>/
# via archive.sh's sweep, once its PARENT lands — never by a direct move here.
# shellcheck source=lib/status-folders.sh
. "$SCRIPT_DIR/lib/status-folders.sh"
SUBTASK_FOLDERS="$(printf '|%s|' "$KIT_STATUS_FOLDERS" | sed 's/|done|/|/; s/^|//; s/|$//')"
IFS='|' read -r -a STATUSES <<< "$SUBTASK_FOLDERS"

usage() {   # the path is an ARGUMENT — see lib/usage.sh
  local roles prd
  if command -v kit_role_display >/dev/null 2>&1; then
    roles="$(kit_role_display "$SCRIPT_DIR/.." || true)"
  fi
  # EVERY DEGRADATION NAMES THE SEAM, never the shipped set: a guess that is right about the kit
  # and wrong about this project is the defect being removed, not a fallback from it.
  [ -n "${roles:-}" ] \
    || roles='as declared in scripts/githooks/commit-msg (ROLE_PREFIXES) — scripts/lib/role-set.sh is absent, so not listed'
  # The prefix is RENDERED, never typed: a literal in the help window is a second copy of the
  # seam value. With the seam absent, name it rather than print the kit's placeholder. `:-`
  # because `set -u` would otherwise turn a usage request into an abort.
  [ -f "$SCRIPT_DIR/config.sh" ] && . "$SCRIPT_DIR/config.sh" || true
  prd="${PRD_PREFIX:-}"
  [ -n "$prd" ] || prd='<PRD_PREFIX from scripts/config.sh>'
  # SUBSTITUTED BY POSITION, in ONE left-to-right pass: `sed` and gsub would interpret `|`, `&`
  # and backslashes in the values, and a pass per token would re-scan a value the previous pass
  # emitted. `out` is finished text; only `rest` is searched.
  # Never spell a role-set alternation in a comment: the self-test reads it as a stray seam copy.
  kit_usage "${BASH_SOURCE[0]}" \
    | ROLE_SET_DISPLAY="$roles" PRD_PREFIX_DISPLAY="$prd" TARGETS_DISPLAY="${SUBTASK_FOLDERS//|/ | }" awk '
    BEGIN { tk[1] = "@ROLE_SET@";      val[1] = ENVIRON["ROLE_SET_DISPLAY"]
            tk[2] = "@PRD_PREFIX@";    val[2] = ENVIRON["PRD_PREFIX_DISPLAY"]
            tk[3] = "@SUBTASK_TARGETS@"; val[3] = ENVIRON["TARGETS_DISPLAY"] }
    { out = ""; rest = $0
      while (1) {
        i = 0
        for (k = 1; k <= 3; k++) { p = index(rest, tk[k]); if (p && (i == 0 || p < i)) { i = p; t = tk[k]; v = val[k] } }
        if (i == 0) break
        out = out substr(rest, 1, i-1) v
        rest = substr(rest, i + length(t)) }
      print out rest }'
}

for _a in "$@"; do case "$_a" in -h|--help) usage; exit 0 ;; esac; done

# config.sh is loaded HERE for its SHARED VALIDATORS, not for a prefix — no OPERATION below
# mints one (`--prd` is shape-checked, never minted), so the "THE PREFIX HAS ONE AUTHORITY" block
# is not copied here. It is the configuration SEAM, so a missing file still gets a named
# cause (process/contracts/config-seam.md), in the same shape as the other seam readers.
# The `|| ! . "$CONFIG"` half is kept for that consistency only: under `set -e` an
# unsourceable seam aborts inside the `.`, before this refusal can print.
# shellcheck source=config.sh
CONFIG="$SCRIPT_DIR/config.sh"
if [ ! -f "$CONFIG" ] || ! . "$CONFIG"; then
  kit_refuse 1 config-seam-missing \
    "Error: scripts/config.sh is missing." \
    "       Looked for: $CONFIG" \
    "       It is the configuration SEAM, and this script sources it for the shared" \
    "       validators (process/contracts/config-seam.md). It reads no prefix from it," \
    "       so there is nothing to guess and nothing to fall back to." \
    "       (This check sees ABSENCE only — an unsourceable file aborts before this message.)" \
    "Next: restore it (git checkout -- scripts/config.sh) — the way back on a tree" \
    "       that HAD it. ON A FRESH REPO, initialize the kit instead (it refuses one" \
    "       that has already lived):" \
    "         ./scripts/kit-init.sh --prefix <P> --trunk <trunk>"
fi

# Loaded below the usage arm: a usage request must not depend on it.
CARDLIB="$SCRIPT_DIR/lib/card-head.sh"
if [ ! -f "$CARDLIB" ] || ! . "$CARDLIB"; then
  kit_refuse 1 card-head-lib-missing \
    "Error: scripts/lib/card-head.sh is missing — it strips the" \
    "       template's KIT-CLASS marker and writes the live-card head in its place." \
    "       (This check sees ABSENCE only — an unsourceable file aborts before this message.)" \
    "Next: restore it (git checkout -- scripts/lib/card-head.sh), then re-run."
fi

# A leading '-' is never a name (process/contracts/issue-creation.md § 3). Guard
# every POSITIONAL, not just the first — `subtask.sh new --bogus s1 slug` would
# otherwise mint a child whose parent is "--bogus".
no_dash() {  # <value> <what it should have been>
  case "$1" in
    -*) echo "Error: '$1' is not a <$2> — a leading '-' is never a name." >&2; usage >&2; exit 2 ;;
  esac
}

[ $# -lt 1 ] && { usage >&2; exit 1; }
CMD="$1"; shift

# need_val — refuse an option whose value is missing: exit 2, naming it (issue-creation.md § 3).
need_val() {
  [ "$#" -ge 2 ] || { echo "Error: $1 requires a value." >&2; exit 2; }
}

case "$CMD" in
  new)
    [ $# -lt 3 ] && { usage >&2; exit 1; }
    no_dash "$1" "PARENT-ID"; no_dash "$2" "suffix"; no_dash "$3" "slug"
    PARENT="$1"; SUFFIX="$2"; SLUG="$3"; shift 3
    TITLE=""; PRD=""; STORIES_GIVEN=""; STORIES="[]"; PLAN=""; SIZE="S"
    while [ $# -gt 0 ]; do case "$1" in
      --title) need_val "$@"; TITLE="$2"; shift 2 ;;
      --prd) need_val "$@"; PRD="$2"; shift 2 ;;
      --stories) need_val "$@"; STORIES_GIVEN="$2"; STORIES="[$2]"; shift 2 ;;
      --plan) need_val "$@"; PLAN="$2"; shift 2 ;;
      --size) need_val "$@"; SIZE="$2"; shift 2 ;;
      --discard-dirty) KWT_DISCARD_DIRTY=true; shift ;;
      -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
      *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
    esac; done
    [ -n "$TITLE" ] || kit_refuse 2 title-required \
      "Error: --title required." \
      "Next: re-run with  --title \"<the slice's title>\"."

    # THE SEAT THIS ARM ACTS AS: [Orchestrator], the decomposer. A knob, never derived, and
    # validated before anything moves.
    ROLE="${SUBTASK_ROLE:-Orchestrator}"
    kit_require_role "$SCRIPT_DIR/.." "$ROLE" SUBTASK_ROLE

    # THE SLUG IS A GIT REF: it becomes `branch: feature/<ID>-<SLUG>` in the published card,
    # and one git cannot check out burns the id (issue-creation.md § 5; validate_slug in
    # scripts/config.sh — one shape, one site).
    validate_slug "$SLUG" || exit 2   # exit-class: usage
    # --prd and --stories have the shape new-issue.sh checks (validate_card_links, one reader).
    validate_card_links "$PRD" "$STORIES_GIVEN" "" || exit 2   # exit-class: usage
    # The suffix is validated too, and NARROWER than a slug: the `move` arm recovers the parent
    # with ${ID%-s*}, so a suffix that is not s<digits> resolves to the wrong parent.
    case "$SUFFIX" in
      s[0-9]*) case "${SUFFIX#s}" in *[!0-9]*) SUFFIX_BAD=1 ;; *) SUFFIX_BAD=0 ;; esac ;;
      *) SUFFIX_BAD=1 ;;
    esac
    if [ "$SUFFIX_BAD" -ne 0 ]; then
      kit_refuse 2 subtask-suffix-malformed \
        "Error: the subtask suffix must be s<digits> — got '$SUFFIX'." \
        "       It becomes part of the card's filename AND of the git branch name, and the" \
        "       move arm recovers the parent id from it, so a different shape resolves to the" \
        "       wrong parent rather than failing. NOTHING WAS CHANGED." \
        "Next: re-run with a suffix of the form s<digits>, e.g. s1."
    fi

    # THE PARENT IS AN ISSUE, NEVER A SUBTASK: the move arm recovers a parent with ${ID%-s*}.
    case "${PARENT##*-s}" in
      "$PARENT"|''|*[!0-9]*) ;;
      *) kit_refuse 1 parent-is-subtask \
           "Error: '$PARENT' is a subtask id — decompose its parent instead. NOTHING WAS CHANGED." \
           "Next: re-run naming the issue as the parent: ./scripts/subtask.sh new ${PARENT%-s*} <suffix> <slug> --title \"…\"." ;;
    esac

    # Acquire the lock + bootstrap + sync the worktree BEFORE touching anything,
    # so the create lands on the current <remote>/<trunk> tip.
    kwt_resolve
    kwt_lock
    kwt_bootstrap
    kwt_sync
    # THE COMMIT IS JUDGED BY THE HOOK IN $KWT, a copy of the trunk; the check above read this checkout's.
    kit_require_role_on_trunk "$KWT" "$ROLE" "${KWT_SYNCED:-false}" "$KWT_REMOTE/$DEFAULT_BRANCH" "the role tag '$ROLE'"

    TEMPLATE="$KWT/.claude/templates/SUBTASK.template.md"
    [ -f "$TEMPLATE" ] || kit_refuse 1 template-missing \
      "Error: template not found at ${TEMPLATE#"$KWT"/}." \
      "Next: the trunk has no ${TEMPLATE#"$KWT"/} — restore it there (the kit ships it; git checkout the kit's copy and push), then re-run."

    # THE PARENT MUST EXIST (issue-creation.md § 3): creation here publishes, so an orphan would
    # reach the trunk. Searched on the published board ($KWT), the surface the mover reads.
    # Depth 2 is progress/<column>/<card>: a subtask tree without its parent card is no parent.
    # Captured whole, then cut: `| head -1` would SIGPIPE the producer under `pipefail`.
    PARENT_CARD="$(find "$KWT/progress" -maxdepth 2 -type f -name "${PARENT}-*.md" 2>/dev/null || true)"
    PARENT_CARD="${PARENT_CARD%%$'\n'*}"
    if [ -z "$PARENT_CARD" ]; then
      kit_refuse 1 parent-not-found \
        "Error: parent '${PARENT}' does not exist on the published board — refusing to create an orphan." \
        "  Looked for progress/<column>/${PARENT}-*.md in the trunk-pinned kanban worktree." \
        "Next: if you have just created ${PARENT}, PUBLISH IT FIRST (git add, commit, push the card): the board mover and this" \
        "  script both read the published board, so an unpushed card is invisible to both. Otherwise check the id."
    fi
    # A retired parent takes no new work: archive.sh sweeps a done/ parent's tree, todo cards and all.
    case "$(basename "$(dirname "$PARENT_CARD")")" in
      done|declined)
        kit_refuse 1 parent-retired \
          "Error: parent '${PARENT}' is in progress/$(basename "$(dirname "$PARENT_CARD")")/ — a retired issue takes no new subtasks. Open a new issue." \
          "Next: open a new issue for the work (./scripts/new-issue.sh) and decompose that one." ;;
    esac

    # prd: INHERITED from the parent unless --prd was given; a parent with none, or with its
    # template placeholder, gives n/a.
    if [ -z "$PRD" ]; then
      PRD="$(kit_card_field "$PARENT_CARD" prd)"
      case "$PRD" in ''|*-NNN) PRD="n/a" ;; esac
    fi

    ID="${PARENT}-${SUFFIX}"
    SLUGFILE="${ID}-${SLUG}.md"
    DEST_DIR="$KWT/progress/subtasks/${PARENT}/todo"
    mkdir -p "$DEST_DIR"
    DEST="$DEST_DIR/$SLUGFILE"
    [ ! -e "$DEST" ] || kit_refuse 1 subtask-exists \
      "Error: ${DEST#"$KWT"/} already exists." \
      "Next: pick a suffix not yet used under progress/subtasks/${PARENT}/, or move the existing card with  ./scripts/subtask.sh move ${ID} <target>."
    TODAY=$(date +%Y-%m-%d)
    BRANCH="feature/${ID}-${SLUG}"

    # BUILT BESIDE THE DESTINATION, PUBLISHED BEFORE THE COMMIT (lib/card-head.sh): a failed step
    # leaves the shared worktree clean. The trap keeps kwt_lock's own EXIT action, kwt_unlock.
    WORK="$(kit_card_work "$DEST_DIR")"
    kit_on_exit 'rm -f "$WORK" "$WORK.h1" "$WORK.plan" "$WORK.rehead" "$WORK.stamp" "$WORK.fill"; kwt_unlock'

    # Fill the template (frontmatter + heading + Activity). Every substitution
    # keys on the frontmatter KEY, never on the template's placeholder VALUE, so
    # a template edit cannot make one a silent no-op. This `sed` has no -i, so it
    # is portable (reads TEMPLATE, writes WORK).
    # EVERY INTERPOLATED VALUE GOES THROUGH sed_repl (scripts/config.sh): `&` and the
    # delimiter are live in a sed replacement.
    # The title is written double-quoted (a `: ` in plain YAML is a parse error): `\` and `"` escaped.
    TITLE_Q="$(printf '%s' "$TITLE" | sed -e 's/[\\"]/\\&/g')"
    sed -e "s|^id: .*|id: $(sed_repl "$ID")|" \
        -e "s|^type: .*|type: subtask|" \
        -e "s|^parent: .*|parent: $(sed_repl "$PARENT")|" \
        -e "s|^title: .*|title: \"$(sed_repl "$TITLE_Q")\"|" \
        -e "s|^size: .*|size: $(sed_repl "$SIZE")|" \
        -e "s|^prd: .*|prd: $(sed_repl "$PRD")|" \
        -e "s|^stories: .*|stories: $(sed_repl "$STORIES")|" \
        -e "s|^branch: .*|branch: $(sed_repl "$BRANCH")|" \
        -e "s|^created_at: .*|created_at: ${TODAY}|" \
        -e "s|^created_by: .*|created_by: $(sed_repl "$ROLE")|" \
        "$TEMPLATE" > "$WORK"

    # The H1. Done as a FIRST-MATCH-ONLY pass rather than a sed pattern: a
    # `s|^# .* — .*|…|` would rewrite every em-dashed heading in the body, not
    # just the title. The H1 is the first `^# ` line after the frontmatter.
    # ENVIRON, NOT `awk -v`: -v processes escape sequences, so a backslash in a title would
    # become a TAB or a NEWLINE. Not perl either: it is past the kit's git-plus-POSIX-shell floor.
    H1="# ${ID} — ${TITLE}" awk 'BEGIN{done=0} done==0 && /^# /{print ENVIRON["H1"]; done=1; next} {print}' \
      "$WORK" > "$WORK.h1" && mv "$WORK.h1" "$WORK" || exit 1   # exit-class: internal

    # RE-HEAD THE CARD (process/EXTRACTION.md § The marker and graduation): the KIT-CLASS
    # marker goes, its still-in-force FILL instruction stays.
    kit_rehead_card "$WORK" || exit 1   # exit-class: internal
    # The seed entry's date, and the parent and slice the body names (lib/card-head.sh).
    kit_stamp_card "$WORK" "$ID" "$TODAY" || exit 1   # exit-class: internal
    kit_fill_card "$WORK" "<PREFIX>-NNN" "$PARENT" "${PARENT%-*}-NNN" "$PARENT" \
      "decomposition slice M." "decomposition slice ${SUFFIX}." \
      "<parent card>" "$(basename "$PARENT_CARD")" || exit 1   # exit-class: internal
    # What an add-on contributes (process/fragments.d/ISSUE/), read from the trunk's tree like the
    # template: process/contracts/issue-creation.md § 3.
    kit_card_fragments "$WORK" ISSUE "$KWT/process/fragments.d" || exit 1   # exit-class: internal


    # Optional --plan. Keyed on the KEY, never on the template's placeholder VALUE, which
    # would silently no-op when the template's example path changes. Three shapes: the
    # `- Plan: …` bullet, a frontmatter `plan:` key, and a bare `<plan-path>` token.
    # awk + ENVIRON (not perl: the floor). `<plan-path>` is replaced by index/substr, because
    # `&` and a backslash are live in gsub's replacement.
    if [ -n "$PLAN" ]; then
      PLAN="$PLAN" awk '
        BEGIN { p = ENVIRON["PLAN"]; tok = "<plan-path>"; tl = length(tok) }
        /^[[:space:]]*[-*][[:space:]]*Plan:[[:space:]]*/ {
          match($0, /^[[:space:]]*[-*][[:space:]]*Plan:[[:space:]]*/)
          print substr($0, 1, RLENGTH) "`" p "`"; next
        }
        /^plan:/ { print "plan: " p; next }
        {
          while ((i = index($0, tok)) > 0)
            $0 = substr($0, 1, i - 1) p substr($0, i + tl)
          print
        }
      ' "$WORK" > "$WORK.plan" && mv "$WORK.plan" "$WORK" || exit 1   # exit-class: internal
    fi

    kit_publish_card "$WORK" "$DEST" || exit 1   # exit-class: internal

    git -C "$KWT" add "$DEST"
    MSG="[$ROLE] ${ID} created under ${PARENT} — decomposition slice (via subtask.sh)"
    kwt_commit "$MSG" "the slice"
    echo "Created: ${DEST#"$KWT"/}  (branch: ${BRANCH})"
    LOCAL_SHA="$(git -C "$KWT" rev-parse --short HEAD)"
    echo "Commit:  ${LOCAL_SHA} — made locally in the kanban worktree; publishing to the trunk next."
    # THE RETURN IS CHECKED: a failed push must not exit 0 while the card is only a local
    # commit in the kanban worktree.
    FINALIZE_RC=0
    kwt_finalize || FINALIZE_RC=$?
    if [ -n "${KWT_LANDED_SHA:-}" ]; then
      echo "Published: ${KWT_LANDED_SHA} on ${DEFAULT_BRANCH}"
    else
      kit_refuse 1 subtask-not-published \
        "NOT PUBLISHED: ${LOCAL_SHA} is local only — see the push error above." \
        "  Every later board operation REFUSES until you publish it." \
        "Next: publish ${LOCAL_SHA} as the Next: line above says; the slice's card is already in that commit, so do not re-run this command."
    fi
    [ "$FINALIZE_RC" -eq 0 ] || exit "$FINALIZE_RC"   # exit-class: internal
    ;;

  move)
    [ $# -lt 2 ] && { usage >&2; exit 1; }
    no_dash "$1" "subtask id"; no_dash "$2" "target"
    ID="$1"; TARGET="$2"; shift 2
    ROLE="Orchestrator"; NOTE=""
    while [ $# -gt 0 ]; do case "$1" in
      --role) need_val "$@"; ROLE="$2"; shift 2 ;;
      --note) need_val "$@"; NOTE="$2"; shift 2 ;;
      --discard-dirty) KWT_DISCARD_DIRTY=true; shift ;;
      -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
      *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
    esac; done
    [[ "$TARGET" =~ ^($SUBTASK_FOLDERS)$ ]] || kit_refuse 1 unknown-target \
      "Error: bad target '$TARGET' (one of: ${STATUSES[*]})." \
      "Next: re-run with one of those folders as the target."
    [ "$TARGET" != declined ] || [ -n "$NOTE" ] \
      || kit_refuse 1 declined-needs-note \
           "Error: declined needs --note \"why\" — the reason is the whole record of a slice that will not be done." \
           "Next: re-run with  --note \"<why this slice will not be done>\"."
    # The same rule as move-issue.sh: a park whose blocker is not written down cannot be unparked
    # by anyone but the seat that parked it.
    [ "$TARGET" != blocked ] || [ -n "$NOTE" ] \
      || kit_refuse 1 blocked-needs-note \
           "Error: moving a slice to blocked/ requires --note \"…\" naming the blocker." \
           "Next: re-run with  --note \"<what blocks it and who can clear it>\"."
    # THE ROLE IS VALIDATED HERE, BEFORE ANY MUTATION: a role the commit-msg hook rejects
    # would fail mid-operation, leaving the git mv and the Activity entry uncommitted in the
    # shared kanban worktree. Refusing here costs a re-run; at the hook, a reconciliation.
    # Derived by lib/role-set.sh kit_role_resolve; this literal is only its stamped default (see there).
    ROLE_SET_DEFAULT='PM|Dev|QA|Refactorer|UIDesigner|Orchestrator|Architect'
    if command -v kit_role_resolve >/dev/null 2>&1; then
      kit_role_resolve "$SCRIPT_DIR/.." "$ROLE_SET_DEFAULT"
    else
      KIT_ROLE_SET="$ROLE_SET_DEFAULT"
      KIT_ROLE_SRC="THE KIT'S FALLBACK SET — scripts/lib/role-set.sh is absent, so this project's declared set could not be read"
      KIT_ROLE_DEFAULTED=1
    fi
    # NAMED, NOT SILENT, AND BEFORE ANYTHING IS ENFORCED: otherwise an acceptance or a refusal
    # reads as being about this project's declared set when it is not.
    [ -z "${KIT_ROLE_DEFAULTED:-}" ] \
      || echo "Note: --role is being checked against $KIT_ROLE_SRC" >&2
    if [ -z "$ROLE" ]; then
      kit_refuse 1 role-empty \
        "Error: --role cannot be empty ($KIT_ROLE_SET)." \
        "Next: re-run with --role set to one of: $KIT_ROLE_SET."
    fi
    if ! kit_role_member "$KIT_ROLE_SET" "$ROLE"; then
      kit_refuse_role_not_declared "$ROLE"
    fi
    PARENT="${ID%-s*}"

    kwt_resolve
    kwt_lock
    kwt_bootstrap
    kwt_sync
    # THE COMMIT IS JUDGED BY THE HOOK IN $KWT, a copy of the trunk; the check above read this checkout's.
    if command -v kit_require_role_on_trunk >/dev/null 2>&1; then
      kit_require_role_on_trunk "$KWT" "$ROLE" "${KWT_SYNCED:-false}" "$KWT_REMOTE/$DEFAULT_BRANCH" "--role $ROLE"
    fi

    BASE="$KWT/progress/subtasks/${PARENT}"
    [ -d "$BASE" ] || kit_refuse 1 subtask-tree-not-found \
      "Error: no subtask tree at progress/subtasks/${PARENT}/." \
      "Next: check the subtask id (ls progress/subtasks/); a slice exists once  ./scripts/subtask.sh new ${PARENT} s<N> <slug> --title \"…\"  has published it."

    # Locate the file across statuses.
    SRC=""; SRC_FOLDER=""
    for s in "${STATUSES[@]}"; do
      m=$(find "$BASE/$s" -name "${ID}-*.md" -type f 2>/dev/null | head -1 || true)
      [ -n "$m" ] && { SRC="$m"; SRC_FOLDER="$s"; break; }
    done
    [ -n "$SRC" ] || kit_refuse 1 subtask-not-found \
      "Error: no ${ID}-*.md under progress/subtasks/${PARENT}/." \
      "Next: check the subtask id (ls progress/subtasks/${PARENT}/*/); create the slice first with  ./scripts/subtask.sh new ${PARENT} s<N> <slug> --title \"…\"  if it does not exist."
    [ "$SRC_FOLDER" != "$TARGET" ] || kit_refuse 1 card-already-in-target \
      "Error: ${ID} already in ${TARGET}/." \
      "Next: nothing to move; to move it elsewhere name that folder as the target."

    # ── A SLICE MOVING TO qa_complete/ IS CHECKED THE SAME WAY A LANDING CARD IS:
    #    its own QA Verdict table, its own `forks:`, and — if its diff touches a declared test
    #    path — its own `## Ablation` section. ONE parser, lib/qa-gate.sh, shared with
    #    finish-pr.sh; same rule ids, same messages. Refused, before the git mv, so nothing moves.
    #    THE DIFF BASIS: forks-contradicted and the Ablation touched-path test both need a diff.
    #    finish-pr.sh has a real feature branch; a slice does NOT necessarily have one of its own
    #    yet (SUBTASK.template.md's `branch:` may name a branch never created — a slice can be
    #    worked, and reviewed, on the parent's branch, or before any branch exists). So the new
    #    revision is the slice's `branch:` frontmatter WHEN that ref resolves locally or on
    #    $KWT_REMOTE; when it does not, the diff basis is the trunk against itself — a real,
    #    empty diff, not a skipped check — so forks-contradicted and the Ablation "touches a
    #    declared test path" test both legitimately find nothing to derive. That is NOT the same
    #    claim as "no fork was resolved" or "no test path was touched" while working the slice:
    #    it is what a diff-less check can see, and this comment is that limit stated, not hidden.
    if [ "$TARGET" = "qa_complete" ]; then
      _st_trunk="${KWT_REMOTE}/${DEFAULT_BRANCH}"
      _st_slice_branch="$(kit_card_field "$SRC" branch)"
      _st_new_rev="$_st_trunk"
      if _st_rev="$(kit_card_branch_rev "$MAIN_ROOT" "$_st_slice_branch" "$KWT_REMOTE")"; then
        _st_new_rev="$_st_rev"
      else
        echo "Note: ${ID}'s branch ('${_st_slice_branch:-none declared}') is not a local or ${KWT_REMOTE} ref —" >&2
        echo "      the forks: and Ablation checks read no diff for this slice (a real, empty one," >&2
        echo "      the trunk against itself), so a fork or a touched test path with no branch to" >&2
        echo "      carry it is NOT derived. The QA Verdict table check is unaffected." >&2
      fi
      kit_forks_check "$SRC" "$ID" "$MAIN_ROOT" "$_st_trunk" "$_st_new_rev" "$SCRIPT_DIR/check-board.sh"
      # The slice's own code lives at $_st_new_rev (its own branch when one resolves, else the
      # trunk — derived just above), so evidence pointers are read there, never the caller's
      # working tree.
      kit_qa_verdict_check "$SRC" "$ID" "$MAIN_ROOT" "$_st_new_rev" "$_st_trunk"
      kit_ablation_check "$SRC" "$ID" "$MAIN_ROOT" "$_st_trunk" "$_st_new_rev"
      # The board properties (check-board.sh [d] [i] [l] [p] [r] [q]): a finding THIS slice's branch
      # introduces refuses, read on the trunk with the branch merged in. A slice with no branch of
      # its own reads the trunk against itself, so only the card's own move is judged.
      kit_board_property_check "$MAIN_ROOT" "$_st_trunk" "$_st_new_rev" \
        "${SRC#"$KWT"/}" "progress/subtasks/${PARENT}/qa_complete/$(basename "$SRC")"
      # The checker is not the author: the slice's verdict commit against its branch's code commits.
      # A slice with no branch of its own has no code commits to compare: UNRUNNABLE, printed.
      kit_agent_records_fetch "$MAIN_ROOT" "$KWT_REMOTE"
      kit_agent_landing_check "$MAIN_ROOT" "$_st_trunk" "$ID" "$_st_new_rev" "progress/subtasks/${PARENT}"
    fi

    # An add-on's move checks for this transition (scripts/move-check.d/<target>/, lib/addon-check.sh;
    # process/contracts/board-mover.md § 3): the same ones move-issue.sh runs, before anything moves.
    kit_move_checks "$MAIN_ROOT" "refs/remotes/${KWT_REMOTE}/${DEFAULT_BRANCH}" "$ID" "$SRC_FOLDER" "$TARGET" "$ROLE" "$SRC"

    mkdir -p "$BASE/$TARGET"
    DEST="$BASE/$TARGET/$(basename "$SRC")"
    if git -C "$KWT" ls-files --error-unmatch "$SRC" >/dev/null 2>&1; then
      git -C "$KWT" mv "$SRC" "$DEST"
    else
      mv "$SRC" "$DEST"
    fi

    TODAY=$(date +%Y-%m-%d); [ -z "$NOTE" ] && NOTE="git mv to ${TARGET}/."
    ENTRY="- ${TODAY} [${ROLE}] ${NOTE}"
    [ -n "$(tail -c1 "$DEST" 2>/dev/null)" ] && printf '\n' >> "$DEST"
    printf '%s\n' "$ENTRY" >> "$DEST"

    git -C "$KWT" add "$DEST"
    MSG="[${ROLE}] ${ID} → ${TARGET}: ${NOTE}"
    kwt_commit "$MSG" "the move"
    # REPORTED ONLY NOW: a commit the hook refuses is put back, and a line saying it happened would be false.
    echo "Moved: subtasks/${PARENT}/${SRC_FOLDER}/ → ${TARGET}/"
    echo "File:  ${DEST#"$KWT"/}"
    LOCAL_SHA="$(git -C "$KWT" rev-parse --short HEAD)"
    echo "Commit: ${LOCAL_SHA} — made locally in the kanban worktree; publishing to the trunk next."
    # THE RETURN IS CHECKED — same reason as the `new` arm above.
    FINALIZE_RC=0
    kwt_finalize || FINALIZE_RC=$?
    if [ -n "${KWT_LANDED_SHA:-}" ]; then
      echo "Published: ${KWT_LANDED_SHA} on ${DEFAULT_BRANCH} — \"${MSG}\""
    else
      kit_refuse 1 subtask-not-published \
        "NOT PUBLISHED: ${LOCAL_SHA} is local only — see the push error above." \
        "  Every later board operation REFUSES until you publish it." \
        "Next: publish ${LOCAL_SHA} as the Next: line above says; the move is already in that commit, so do not re-run this command."
    fi
    [ "$FINALIZE_RC" -eq 0 ] || exit "$FINALIZE_RC"   # exit-class: internal
    ;;

  -*) echo "Error: unknown option: $CMD (expected the command 'new' or 'move')" >&2; usage >&2; exit 2 ;;
  *) echo "Unknown command: $CMD" >&2; usage >&2; exit 1 ;;
esac
exit 0
