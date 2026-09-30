#!/usr/bin/env bash
# KIT-CLASS: KIT — the configuration seam itself — edit the prefixes, take the rest as-is. See process/EXTRACTION.md.
# THE CONFIGURATION SEAM: every value a script needs but cannot derive is declared here, once.
# A consumer needing a value this seam lacks is a GAP IN THE SEAM, fixed by adding it here,
# never by hard-coding it at the call site (process/contracts/config-seam.md § 3).
#
# `scripts/kit-init.sh` stamps ISSUE_PREFIX, PRD_PREFIX and PROJECT_NAME on day one; after
# that, edit them here. A change takes effect on the next invocation; existing files are NOT
# renamed.
#
# Override at runtime via env var, e.g.:
#   ISSUE_PREFIX=TEST ./scripts/new-issue.sh foo --id TEST-001
#
# The TRUNK is deliberately NOT a knob here: it resolves from <remote>/HEAD
# (scripts/lib/kanban-worktree.sh kwt_resolve), and the project adapter states it
# (CLAUDE.md § "The trunk").

# Issue / bug prefix. Generated filenames look like ${ISSUE_PREFIX}-001-<slug>.md.
# Who reads it:  grep -rlF ISSUE_PREFIX scripts --include='*.sh'
#
# `KIT` is the SHIPPED PLACEHOLDER, not a recommendation. kit-init.sh derives the old value
# from this line, so it must stay alphanumeric and start with a letter. Replace it on day one:
#   ./scripts/kit-init.sh --prefix XYZ --trunk main
ISSUE_PREFIX="${ISSUE_PREFIX:-KIT}"

# PRD prefix. Generated filenames look like ${PRD_PREFIX}-001-<slug>.md; the default is fine
# for most projects. Some readers branch on its value, so a change touches all of them:
#   grep -rlF PRD_PREFIX scripts --include='*.sh'
# THE ONE FALLBACK LITERAL FOR THIS NAME: consumers source this file and write "${PRD_PREFIX}"
# bare. A second ":-PRD" in a consumer is a second authority.
PRD_PREFIX="${PRD_PREFIX:-PRD}"

# Project name, as the role docs and templates spell it. kit-init.sh reads this default to
# learn the name the travelling docs carry, rewrites them, and counts what it left behind.
PROJECT_NAME="${PROJECT_NAME:-<project name>}"

# Archive sweep threshold: how many issues progress/qa_complete/ may hold before
# check-board.sh's arm (b) flags it as due for a sweep (./scripts/archive.sh --apply).
# THE ONE AUTHORITY for this number — the adapter's "archive sweep threshold" row
# (process/templates/CLAUDE-adapter.template.md) points here rather than asking for <N>.
QA_COMPLETE_THRESHOLD="${QA_COMPLETE_THRESHOLD:-10}"

# ── CODE_GLOBS — the one project-supplied definition the code-vs-metadata rule needs
#    (process/MANUAL.md § The code-vs-metadata rule): "which paths are code." Everything NOT
#    matched here is metadata and commits direct to the trunk. Read by
#    scripts/githooks/pre-commit, which refuses a metadata-only commit made off the trunk.
#
# SHIPPED EMPTY ON PURPOSE: empty means UNDECLARED, and the pre-commit hook that reads this
# treats undeclared as unenforced — it will not refuse anything until you fill this in (the
# same convention verify.sh's GUARD_ENUM="" and GATES=() use). check-board.sh's [g] arm reports
# this array as an unfilled day-one obligation until you do. Fill it with your source tree,
# test tree and build/packaging manifest — e.g.:
#
#   CODE_GLOBS=(
#     "src/*"
#     "tests/*"
#     "package.json"
#   )
#
# Matched with `case` against a path RELATIVE TO THE REPOSITORY ROOT, so a trailing `/*` is a
# directory prefix and an exact string is one file. A path matching no glob here is metadata.
#
# LEAVING IT EMPTY ON PURPOSE (not "not yet filled"): add one whole comment line inside the
# parens, `# DECLARED EMPTY — <why>`, e.g. because this project has no branch-gated code path.
# [g] then reports it as declared rather than unfilled; the hook's own behaviour does not change
# — empty is still unenforced.
CODE_GLOBS=(
)

# ── TEST_GLOBS — the one project-supplied definition the ablation-record rule needs
#    (process/MANUAL.md § The ablation-record rule): "which paths are tests." Read by
#    scripts/finish-pr.sh, which refuses a landing whose branch diff touches a declared test
#    path with no well-formed `## Ablation` section in the issue file.
#
# SHIPPED EMPTY ON PURPOSE: empty means UNDECLARED, and finish-pr.sh treats undeclared as
# unenforced — it reports that the check did not run rather than silently passing (same
# convention CODE_GLOBS above and verify.sh's GATES=() use). check-board.sh's [g] arm reports
# this array as an unfilled day-one obligation until you do. Fill it with your test tree:
#
#   TEST_GLOBS=(
#     "tests/*"
#     "src/**/*.test.js"
#   )
#
# Matched with `case` against a path RELATIVE TO THE REPOSITORY ROOT, same shape as CODE_GLOBS.
#
# LEAVING IT EMPTY ON PURPOSE: the same `# DECLARED EMPTY — <why>` comment line, inside the
# parens, that CODE_GLOBS documents above.
TEST_GLOBS=(
)

# sed_repl <value> — escape a free-text value for the replacement half of `s|…|REPL|`, where
# `|`, `\` and `&` are not literal. The one definition; every minting script uses it.
# NOT COVERED: an embedded newline, which sed rejects in a replacement.
sed_repl() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }

# validate_slug <slug> — implements process/contracts/issue-creation.md § 5 (the shape, and why
# it is this narrow); it does not define it. The refusal's gloss is the one prose restatement,
# kept beside the pattern. It REFUSES rather than sanitising: the name you type is the name you
# get.
validate_slug() {
  local slug="$1" pos ch
  if [ -z "$slug" ]; then
    echo "Error: <slug> is required — see process/contracts/issue-creation.md § 5." >&2
    return 1
  fi
  printf '%s' "$slug" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' && return 0

  # NAME THE POSITION AND THE CHARACTER (§ 3): the commonest offender, a trailing space, is
  # invisible.
  pos=1
  while [ "$pos" -le "${#slug}" ]; do
    ch="$(printf '%s' "$slug" | cut -c"$pos")"
    if ! printf '%s' "$ch" | grep -qE '^[a-z0-9-]$'; then
      case "$ch" in
        " ") ch="a space" ;;
        "")  ch="a non-printing character" ;;
        *)   ch="'$ch'" ;;
      esac
      echo "Error: <slug> '$slug' — $ch at position $pos is not allowed." >&2
      break
    fi
    pos=$(( pos + 1 ))
  done
  if [ "$pos" -gt "${#slug}" ]; then
    # Every character is individually legal, so the fault is where the hyphens sit.
    case "$slug" in
      -*)   echo "Error: <slug> '$slug' — a leading hyphen at position 1 is not allowed." >&2 ;;
      *-)   echo "Error: <slug> '$slug' — a trailing hyphen at position ${#slug} is not allowed." >&2 ;;
      *--*) echo "Error: <slug> '$slug' — two hyphens in a row are not allowed." >&2 ;;
      *)    echo "Error: <slug> '$slug' does not match the declared shape." >&2 ;;
    esac
  fi
  echo "       A short name is lower-case letters, digits and single hyphens between" >&2
  echo "       them — the shape is declared in process/contracts/issue-creation.md § 5." >&2
  echo "       It is not rewritten for you: the name you type is the name you get." >&2
  return 1
}

# kit_trunk_ref <root> — print <remote>/<trunk>, resolved by kwt_resolve, and return 0 when that
# ref exists, 3 when it does not (day one, local-only), 1 when it cannot be resolved. Read as last
# fetched, never fetched: the id readers (next-id.sh, validate_issue_id) share this one resolution.
kit_trunk_ref() {
  ( . "$1/scripts/lib/kanban-worktree.sh" >/dev/null && cd "$1" && kwt_resolve >/dev/null || exit 1
    printf '%s' "$KWT_REMOTE/$DEFAULT_BRANCH"
    git rev-parse --verify --quiet "refs/remotes/$KWT_REMOTE/$DEFAULT_BRANCH" >/dev/null || exit 3 )
}

# validate_issue_id "$ID" "$ROOT" — validate a caller-supplied id and check collisions
# (read-only). The creation scripts are STATELESS: the caller picks the number (typically via
# ./scripts/next-id.sh) and passes --id. Uses ISSUE_PREFIX; returns non-0 on a hard error.
validate_issue_id() {
  local id="$1" root="$2" existing
  if [ -z "$id" ]; then
    echo "Error: --id is required (e.g. --id ${ISSUE_PREFIX}-034)." >&2
    echo "       Get the next id with:  ./scripts/next-id.sh   (then sanity-check it)." >&2
    echo "       These scripts are stateless — the caller passes the number in." >&2
    return 1
  fi
  if ! printf '%s' "$id" | grep -qE "^${ISSUE_PREFIX}-[0-9]+$"; then
    echo "Error: --id '$id' must look like ${ISSUE_PREFIX}-NNN." >&2
    return 1
  fi
  # Hard collision: this id is already a live file anywhere under progress/ — here, or on the
  # trunk, which a branch cut before a mint there cannot see.
  existing="$(find "$root/progress" -type f -name "${id}-*.md" 2>/dev/null | head -1)"
  if [ -n "$existing" ]; then
    echo "Error: ${id} already exists at ${existing#"$root"/}." >&2
    return 1
  fi
  local ref rc=0 idre="(^|[^A-Za-z0-9])${id}([^0-9]|\$)"
  ref="$(kit_trunk_ref "$root")" || rc=$?
  if [ "$rc" -eq 0 ]; then
    existing="$(git -C "$root" ls-tree -r --name-only "refs/remotes/$ref" -- progress 2>/dev/null | grep -E "/${id}-[^/]*\.md\$" || true)"
    if [ -n "$existing" ]; then
      echo "Error: ${id} already exists on $ref (as last fetched) at ${existing%%$'\n'*} — not yet in this checkout." >&2
      return 1
    fi
  fi
  # Soft collision: this id appears in ARCHIVE.md (an archived issue used it), here or on the trunk.
  local where=""
  if [ -f "$root/ARCHIVE.md" ] && grep -qE "$idre" "$root/ARCHIVE.md" 2>/dev/null; then
    where="ARCHIVE.md"
  elif [ "$rc" -eq 0 ] && git -C "$root" show "refs/remotes/$ref:ARCHIVE.md" 2>/dev/null | grep -E "$idre" >/dev/null; then
    where="$ref's ARCHIVE.md (as last fetched)"
  fi
  if [ -n "$where" ]; then
    echo "Warning: ${id} appears in $where — it may already belong to an archived issue." >&2
    echo "         Proceeding; ensure this is intentional (./scripts/next-id.sh suggests the next free id)." >&2
  fi
  return 0
}

# THE PUSH-BEFORE-YOU-MOVE TRAP: a creation script writes into the OPERATOR'S checkout, and
# move-issue.sh reads the board only from the trunk (.kanban-wt/ and the fetched remote ref),
# so an unpushed card is invisible to it ("no file matching <ID>-*.md").
#
# PRINT, NOT PERFORM, for every creation script: creation is INERT
# (process/contracts/issue-creation.md § 2), so the step is made unmissable, not automatic.
#
#   Usage:  print_push_before_move "<path/to/created/file.md>"
print_push_before_move() {
  local path="${1:-}" rel
  # `${BASH_SOURCE[0]:-$0}`, never the bare form: this file is sourced, and under `set -u` an
  # unset BASH_SOURCE would abort before the warning prints.
  rel="${path#"$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)/"}"
  echo ""
  echo "  ⚠ PUSH IT BEFORE YOU MOVE IT. ./scripts/move-issue.sh reads the board from the"
  echo "    trunk — the .kanban-wt worktree for the move itself, and the freshly-fetched"
  echo "    remote ref when it reports a miss — so a file that exists only in this"
  echo "    checkout is invisible to it — the move fails with 'no file matching'."
  echo ""
  echo "      git add \"${rel}\" && git commit -m \"[<Role>] <ID>: mint\" && git push"
  echo ""
  echo "    Then, and only then:  ./scripts/move-issue.sh <ID> in_progress --role <Role> --note \"…\""
}
