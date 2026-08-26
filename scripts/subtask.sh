#!/usr/bin/env bash
# KIT-CLASS: KIT — Orchestrator decomposition into subtask issues. See process/EXTRACTION.md.
# Orchestrator subtask tooling — mirrors move-issue.sh semantics WITHIN the hidden
# subtask tree `progress/subtasks/<parent>/<status>/`. Built lazily, on the first
# decomposition that actually needed it. Subtasks do NOT consume the issue-id
# integer stream — ids are <PARENT>-sM — and they live OFF the main board so the
# PM's backlog stays pristine. The parent stays on the main board and advances to
# qa_complete only when every subtask reaches qa_complete. All commits are stamped
# per --role (default Orchestrator) on the trunk.
#
# This shares the SAME machinery as move-issue.sh / finish-pr.sh:
# scripts/lib/kanban-worktree.sh. Every git op (create / git mv / Activity append /
# commit / push) happens inside the standing detached `.kanban-wt/` worktree pinned
# to the trunk — the operator's checkout is NEVER switched and any working-tree
# state is irrelevant. An older model did `git switch <trunk>` + refuse-on-dirty in
# the operator's own checkout; that is RETIRED. The subtask tree is just a
# different path root under the same worktree, so the move logic is now identical.
#
# Usage:
#   ./scripts/subtask.sh new <PARENT-ID> <suffix> <slug> --title "..." [--prd PRD-NNN] [--stories a,b] [--plan path] [--size S]
#       → creates progress/subtasks/<PARENT-ID>/todo/<PARENT-ID>-<suffix>-<slug>.md
#         from .claude/templates/SUBTASK.template.md, fills frontmatter, commits [Orchestrator].
#   ./scripts/subtask.sh move <PARENT-ID>-<suffix> <target> [--role Orchestrator|Dev|QA] [--note "..."] [--discard-dirty]
#       → git mv within the subtask tree + append Activity + commit "[ROLE] <id> → <target>: NOTE".
#
# Target folders: todo | in_progress | dev_complete | qa_complete | blocked
#
# --discard-dirty: if the kanban worktree has uncommitted tracked changes, discard
#   them instead of aborting the sync. Read move-issue.sh's warning about it first:
#   the worktree is shared between lanes. (There is deliberately no --no-commit —
#   batching left the work uncommitted, which the next op's reset --hard then wiped.)
#
# Examples:
#   ./scripts/subtask.sh new <PREFIX>-014 s1 anchor-resolver --title "Floor: anchor resolution"
#   ./scripts/subtask.sh move <PREFIX>-014-s1 in_progress --role Dev --note "Pickup."
#   ./scripts/subtask.sh move <PREFIX>-014-s1 dev_complete --role Dev --note "Ready for review; gates green."

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kanban-worktree.sh
. "$SCRIPT_DIR/lib/kanban-worktree.sh"

# The subtask lifecycle. done/ is deliberately absent: a subtask tree reaches its
# terminal home under progress/done/subtasks/<parent>/ via archive.sh's sweep,
# once its PARENT lands — never by a direct move here.
STATUSES=(todo in_progress dev_complete qa_complete blocked)

usage() {
  local src="${BASH_SOURCE[0]}" first end
  first="$(awk 'NR>2 && !/^#/{print NR; exit}' "$src")"
  end=$(( ${first:-0} - 1 )); [ "$end" -lt 3 ] && end=3
  sed -n "3,${end}p" "$src" | sed 's|^# \{0,1\}||'
}

# A leading '-' is never a name (process/contracts/issue-creation.md § 3). Guard
# every POSITIONAL, not just the first — `subtask.sh new --help s1 slug` would
# otherwise mint a child whose parent is "--help", with a success message.
# --help exits 0; an unknown option refuses with rc=2.
no_dash() {  # <value> <what it should have been>
  case "$1" in
    -*) echo "Error: '$1' is not a <$2> — a leading '-' is never a name." >&2; usage >&2; exit 2 ;;
  esac
}

[ $# -lt 1 ] && { usage >&2; exit 1; }
CMD="$1"; shift

case "$CMD" in
  new)
    [ $# -lt 3 ] && { usage >&2; exit 1; }
    no_dash "$1" "PARENT-ID"; no_dash "$2" "suffix"; no_dash "$3" "slug"
    PARENT="$1"; SUFFIX="$2"; SLUG="$3"; shift 3
    TITLE=""; PRD="n/a"; STORIES="[]"; PLAN=""; SIZE="S"
    while [ $# -gt 0 ]; do case "$1" in
      --title) TITLE="${2:-}"; shift 2 ;;
      --prd) PRD="${2:-}"; shift 2 ;;
      --stories) STORIES="[${2:-}]"; shift 2 ;;
      --plan) PLAN="${2:-}"; shift 2 ;;
      --size) SIZE="${2:-}"; shift 2 ;;
      --discard-dirty) KWT_DISCARD_DIRTY=true; shift ;;
      -h|--help) usage; exit 0 ;;
      -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
      *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
    esac; done
    [ -z "$TITLE" ] && { echo "Error: --title required." >&2; exit 1; }

    # Acquire the lock + bootstrap + sync the worktree BEFORE touching anything,
    # so the create lands on the current <remote>/<trunk> tip.
    kwt_resolve
    kwt_lock
    kwt_bootstrap
    kwt_sync

    TEMPLATE="$KWT/.claude/templates/SUBTASK.template.md"
    [ -f "$TEMPLATE" ] || { echo "Error: template not found at ${TEMPLATE#"$KWT"/}." >&2; exit 1; }

    ID="${PARENT}-${SUFFIX}"
    SLUGFILE="${ID}-${SLUG}.md"
    DEST_DIR="$KWT/progress/subtasks/${PARENT}/todo"
    mkdir -p "$DEST_DIR"
    DEST="$DEST_DIR/$SLUGFILE"
    [ -e "$DEST" ] && { echo "Error: ${DEST#"$KWT"/} already exists." >&2; exit 1; }
    TODAY=$(date +%Y-%m-%d)
    BRANCH="feature/${ID}-${SLUG}"

    # Fill the template (frontmatter + heading + Activity). Every substitution
    # keys on the frontmatter KEY, never on the template's placeholder VALUE, so
    # a template edit cannot make one a silent no-op. This `sed` has no -i, so it
    # is portable (reads TEMPLATE, writes DEST).
    sed -e "s|^id: .*|id: ${ID}|" \
        -e "s|^type: .*|type: subtask|" \
        -e "s|^parent: .*|parent: ${PARENT}|" \
        -e "s|^title: .*|title: ${TITLE}|" \
        -e "s|^size: .*|size: ${SIZE}|" \
        -e "s|^prd: .*|prd: ${PRD}|" \
        -e "s|^stories: .*|stories: ${STORIES}|" \
        -e "s|^branch: .*|branch: ${BRANCH}|" \
        -e "s|^created_at: .*|created_at: ${TODAY}|" \
        -e "s|^created_by: .*|created_by: Orchestrator|" \
        "$TEMPLATE" > "$DEST"

    # The H1. Done as a FIRST-MATCH-ONLY pass rather than a sed pattern: a
    # `s|^# .* — .*|…|` would rewrite every em-dashed heading in the body, not
    # just the title. The H1 is the first `^# ` line after the frontmatter.
    H1_TMP="$(mktemp)"
    awk -v h="# ${ID} — ${TITLE}" 'BEGIN{done=0} done==0 && /^# /{print h; done=1; next} {print}' \
      "$DEST" > "$H1_TMP" && mv "$H1_TMP" "$DEST"

    # Optional --plan. Every substitution is KEYED ON THE KEY, never on the
    # template's placeholder VALUE — that is the whole lesson: a pattern that
    # spells out the placeholder path silently no-ops the day the template's
    # example path changes, and the card then ships with the raw placeholder in
    # it. Three key shapes are handled because templates legitimately differ: the
    # kit template's `- Plan: …` bullet, a frontmatter `plan:` key, and a bare
    # `<plan-path>` token. An earlier version used
    # `sed -i '' … 2>/dev/null || true`, which was BSD-only (a no-op on GNU sed /
    # Linux) AND swallowed the error. perl -i is portable; PLAN is passed via the
    # environment so path characters cannot break the pattern; nothing is
    # swallowed — a failure aborts under `set -e`.
    if [ -n "$PLAN" ]; then
      PLAN="$PLAN" perl -i -pe '
        s{^(\s*[-*]\s*Plan:\s*).*$}{$1`$ENV{PLAN}`};
        s{^plan:.*$}{plan: $ENV{PLAN}};
        s{<plan-path>}{$ENV{PLAN}}g;
      ' "$DEST"
    fi

    git -C "$KWT" add "$DEST"
    MSG="[Orchestrator] ${ID} created under ${PARENT} — decomposition slice (via subtask.sh)"
    git -C "$KWT" commit -m "$MSG" --quiet
    echo "Created: ${DEST#"$KWT"/}  (branch: ${BRANCH})"
    LOCAL_SHA="$(git -C "$KWT" rev-parse --short HEAD)"
    echo "Commit:  ${LOCAL_SHA} — made locally in the kanban worktree, NOT yet published."
    kwt_finalize
    # CONDITIONAL on purpose: kwt_finalize's return is not checked here (that is
    # change 017's item, not this one), so this line must not assert a landing
    # nobody verified. KWT_LANDED_SHA is set only after the library has read the
    # commit back off the ref, so an empty value means exactly "did not publish".
    if [ -n "${KWT_LANDED_SHA:-}" ]; then
      echo "Published: ${KWT_LANDED_SHA} on ${DEFAULT_BRANCH}"
    else
      echo "NOT PUBLISHED: ${LOCAL_SHA} is local only — see the push error above." >&2
    fi
    ;;

  move)
    [ $# -lt 2 ] && { usage >&2; exit 1; }
    no_dash "$1" "subtask id"; no_dash "$2" "target"
    ID="$1"; TARGET="$2"; shift 2
    ROLE="Orchestrator"; NOTE=""
    while [ $# -gt 0 ]; do case "$1" in
      --role) ROLE="${2:-}"; shift 2 ;;
      --note) NOTE="${2:-}"; shift 2 ;;
      --discard-dirty) KWT_DISCARD_DIRTY=true; shift ;;
      -h|--help) usage; exit 0 ;;
      -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
      *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
    esac; done
    case "$TARGET" in todo|in_progress|dev_complete|qa_complete|blocked) ;; *) echo "Error: bad target '$TARGET' (one of: ${STATUSES[*]})." >&2; exit 1 ;; esac
    PARENT="${ID%-s*}"

    kwt_resolve
    kwt_lock
    kwt_bootstrap
    kwt_sync

    BASE="$KWT/progress/subtasks/${PARENT}"
    [ -d "$BASE" ] || { echo "Error: no subtask tree at progress/subtasks/${PARENT}/." >&2; exit 1; }

    # Locate the file across statuses.
    SRC=""; SRC_FOLDER=""
    for s in "${STATUSES[@]}"; do
      m=$(find "$BASE/$s" -name "${ID}-*.md" -type f 2>/dev/null | head -1 || true)
      [ -n "$m" ] && { SRC="$m"; SRC_FOLDER="$s"; break; }
    done
    [ -z "$SRC" ] && { echo "Error: no ${ID}-*.md under progress/subtasks/${PARENT}/." >&2; exit 1; }
    [ "$SRC_FOLDER" = "$TARGET" ] && { echo "Error: ${ID} already in ${TARGET}/." >&2; exit 1; }

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
    echo "Moved: subtasks/${PARENT}/${SRC_FOLDER}/ → ${TARGET}/"
    echo "File:  ${DEST#"$KWT"/}"

    git -C "$KWT" add "$DEST"
    MSG="[${ROLE}] ${ID} → ${TARGET}: ${NOTE}"
    git -C "$KWT" commit -m "$MSG" --quiet
    LOCAL_SHA="$(git -C "$KWT" rev-parse --short HEAD)"
    echo "Commit: ${LOCAL_SHA} — made locally in the kanban worktree, NOT yet published."
    kwt_finalize
    if [ -n "${KWT_LANDED_SHA:-}" ]; then
      echo "Published: ${KWT_LANDED_SHA} on ${DEFAULT_BRANCH} — \"${MSG}\""
    else
      echo "NOT PUBLISHED: ${LOCAL_SHA} is local only — see the push error above." >&2
    fi
    ;;

  -h|--help) usage; exit 0 ;;
  -*) echo "Error: unknown option: $CMD (expected the command 'new' or 'move')" >&2; usage >&2; exit 2 ;;
  *) echo "Unknown command: $CMD" >&2; usage >&2; exit 1 ;;
esac
