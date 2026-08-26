#!/usr/bin/env bash
# KIT-CLASS: KIT — the executable bootstrap: stamp the seams, create the board, wire the hooks, self-check. See process/EXTRACTION.md.
# =============================================================================
# scripts/kit-init.sh — initialize THE KIT in a repository that has already
# received the copy-list (process/EXTRACTION.md § 1, or process/SEED.md step 2).
#
# WHY IT EXISTS
#   A cold-read review of this kit found fifteen defects — two of them silent
#   corruptions — and closed with the sentence this script answers: "every
#   finding was found by reading; all would have been found by running."
#   Reading does not scale and does not repeat. This runs.
#
# WHAT IT DOES (in this order — nothing is written until every check passes)
#   1. PREFLIGHT   — every precondition, all reported at once, then refuse.
#   2. STAMP       — the prefix / trunk / project name / role set / gate command,
#                    through the EXISTING seams only (scripts/config.sh,
#                    .claude/templates/, .claude/roles/, githooks/commit-msg +
#                    move-issue.sh + check-board.sh, scripts/verify.sh). It
#                    creates NO parallel config file, and it COUNTS what it left
#                    behind (see "The census" in --help).
#   3. BOARD       — the status folders with their .gitkeep files, the
#                    progress.md skeleton, the ARCHIVE.md stub, the .gitignore
#                    entries the kanban worktree needs.
#   4. HOOKS       — git config core.hooksPath scripts/githooks.
#   5. COMMIT+PUSH — the initialized tree reaches the trunk, because the board
#                    scripts operate on the REMOTE's copy of the board.
#   6. SELF-CHECK  — a subset of scripts/test/run.sh's concerns, run against THIS
#                    repo: mint a scratch card, move it through two columns,
#                    check-board clean, and a real commit REJECTED by the
#                    commit-msg hook. Then the scratch card is removed.
#
# WHAT IT IS NOT
#   • Not a project scaffolder — no language runtime, no build system, no source
#     tree. It initializes the KIT, not an application.
#   • Not a copier. There is no --from mode: the copy-list is authored in
#     process/EXTRACTION.md § 1 and a second executable copy of it would drift.
#     The preflight instead NAMES every copy-list file it needs and refuses with
#     the missing ones, so "already copied" is verified rather than hoped for.
#   • Not a remote bootstrapper. See --help § "The remote precondition".
#
# USAGE
#   ./scripts/kit-init.sh --prefix XYZ --trunk main [options]
#
# Run --help for the full option list and the refusal recipes.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# LOAD-BEARING, and found by RUNNING this script rather than by reading the kit:
# the kanban scripts resolve their repository from the CURRENT WORKING DIRECTORY
# (kanban-worktree.sh's kwt_resolve() calls `git rev-parse --git-common-dir` with
# no -C), NOT from their own location. Invoked as `/elsewhere/scripts/move-issue.sh`
# from another repo's directory, they operate on THAT repo. So kit-init works from
# the root of the repository it is initializing — always.
cd "$ROOT"

# The remote name the kanban worktree uses (kanban-worktree.sh's KWT_REMOTE knob).
REMOTE="${KWT_REMOTE:-origin}"

# The lifecycle. The status set is a seam WITHOUT a variable across four scripts —
# this one uses it as it is (it does not parameterise it).
STATUS_FOLDERS=(todo in_progress dev_complete qa_complete blocked done)
# + history/ for rotated progress.md sections (archive-progress.sh's destination).
BOARD_FOLDERS=("${STATUS_FOLDERS[@]}" history)
# One .gitkeep per board folder; the count is ASSERTED after creation rather than
# trusted, and the expectation is DERIVED from the folder-set array above — never
# a hand-typed digit.
GITKEEP_EXPECTED=${#BOARD_FOLDERS[@]}

# The one-line receipt this script writes INTO scripts/config.sh (an existing
# seam, not a new file). Its presence is what makes a second run refuse.
STAMP_MARK='# Stamped by scripts/kit-init.sh'

# The scratch card the self-check mints. `-000` is unmistakably not a real
# issue and leaves -001 free for the adopter's first mint.
SCRATCH_NUM='000'
SCRATCH_SLUG='kit-init-self-check'

# The angle-bracket placeholder the travelling docs and templates use for the
# issue prefix (house style: placeholders are <angle-bracketed>). It is stamped
# alongside the config default derived below, because the two forms coexist: the
# shipped templates say `<PREFIX>-NNN`, while config.sh's own default is a real
# token so its derivation regex can read it.
PREFIX_PLACEHOLDER='<PREFIX>'

PREFIX=""; TRUNK=""; PRD_PREFIX_NEW=""; ROLES_NEW=""; GATE_CMD=""; RUN_SELFCHECK=true
PROJECT_NAME_NEW=""

usage() {
  cat <<'EOF'
kit-init.sh — initialize the process kit in a repository that has already
received the copy-list.

  SCOPE: CONFIGURE-ONLY. This script stamps, creates, wires and verifies. It
  does NOT copy the kit — there is no --from mode. Copy the files named in
  process/EXTRACTION.md § 1 first (scripts/, .claude/templates/, the role docs,
  process/); this script's preflight then names anything still missing and
  refuses. Nothing is written unless every precondition passes.

Usage:
  ./scripts/kit-init.sh --prefix XYZ --trunk main [options]

Required:
  --prefix <P>        The issue-id prefix (e.g. GTFS → GTFS-001-<slug>.md).
                      Stamped into scripts/config.sh and .claude/templates/.
  --trunk <B>         Your trunk / default branch. REQUIRED and CONFIRMED: it is
                      cross-checked against <remote>/HEAD and the run refuses on
                      disagreement. It is never inferred — see below.

Options:
  --project-name <N>  Your project's name, as the role docs and templates should
                      spell it (default: this repository's directory name). The
                      name the docs CURRENTLY carry is read out of config.sh's
                      PROJECT_NAME default, never typed here — see "The census".
  --prd-prefix <P>    PRD id prefix (default: left as config.sh has it).
  --roles "A|B|C"     Your role set, as the ERE alternation the commit-msg hook
                      enforces. Stamped into ALL THREE script seams that carry
                      it (githooks/commit-msg, move-issue.sh's --role whitelist,
                      check-board.sh's derivation fallback).
                      Default: left as copied.
  --gate-command <C>  Declare <C> as the gate. If scripts/verify.sh is the shipped
                      frame with an EMPTY GATES table, <C> is written into that
                      table as its first record (name "gate", class core). If no
                      scripts/verify.sh exists at all, a minimal single-gate
                      runner is written around <C>. Refuses if verify.sh already
                      declares a gate, or is not the frame — that file is yours.
                      Omit it and an existing, executable scripts/verify.sh is a
                      REQUIRED precondition instead: finish-pr.sh REFUSES to land
                      without one — and the shipped frame REFUSES TO RUN while its
                      table is empty, so omit the flag only once you have declared
                      your gates in that table by hand.
  --skip-self-check   Stamp and create, but do not run the self-check. Discouraged
                      — the self-check is the only part that PROVES the result.
  -h, --help          This text.

The remote precondition (the silent-corruption class this script exists for):
  kanban-worktree.sh resolves the trunk as <remote>/HEAD → init.defaultBranch →
  a last-resort literal. A fresh repo with no <remote>/HEAD therefore gets a
  trunk name nobody chose (the fallback now WARNS loudly, but a warning read
  after the fact is not a decision made before it). This script GUIDES rather
  than bootstraps: it refuses when the remote or its HEAD is missing and prints
  the recipe — including the LOCAL BARE-REPO recipe for a project with no forge
  at all. Creating a remote is a repository-topology decision an initializer
  must not make on your behalf.

The census (a measurement, not a promise):
  process/contracts/config-seam.md says a search of the travelling files for the
  donor's own values must return NOTHING — "a count, run by the adopter, not a
  promise made by the donor". This script runs that count itself, over
  .claude/roles/ and .claude/templates/, for all three donor tokens — prefix,
  trunk and project name, every one DERIVED from a seam rather than typed in
  here — prints it, and the self-check FAILS when it is non-zero. What the census
  deliberately does NOT count: an identifier of the shape <PREFIX>-<digits>,
  which is a PROVENANCE citation ("this rule is issue 374's lesson"). Rewriting
  those would manufacture a reference to an issue your project never had; they
  are reported separately, as known residue you may delete by hand.

Idempotency:
  A second run REFUSES. It names what is already stamped and writes nothing —
  there is no resume path, because a half-stamped repository is the worst
  outcome available. To re-initialize, revert the initialization commit.
EOF
}

# --- arg parsing -------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --prefix)         PREFIX="${2:-}"; shift 2 ;;
    --project-name)   PROJECT_NAME_NEW="${2:-}"; shift 2 ;;
    --trunk)          TRUNK="${2:-}"; shift 2 ;;
    --prd-prefix)     PRD_PREFIX_NEW="${2:-}"; shift 2 ;;
    --roles)          ROLES_NEW="${2:-}"; shift 2 ;;
    --gate-command)   GATE_CMD="${2:-}"; shift 2 ;;
    --skip-self-check) RUN_SELFCHECK=false; shift ;;
    -h|--help)        usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; echo "Try --help." >&2; exit 1 ;;
  esac
done

say()  { printf '%s\n' "$*"; }
step() { printf '\n── %s\n' "$*"; }

# Preflight failures accumulate so ONE run reports every problem.
PF=()
pf() { PF+=("$1"); }

# =============================================================================
# 1. PREFLIGHT — refuse before writing anything.
# =============================================================================
step "kit-init preflight"

[ -n "$PREFIX" ] || pf "--prefix is required (e.g. --prefix GTFS)."
[ -n "$TRUNK"  ] || pf "--trunk is required (e.g. --trunk main) — the trunk is confirmed, never inferred."
if [ -n "$PREFIX" ] && ! printf '%s' "$PREFIX" | grep -qE '^[A-Za-z][A-Za-z0-9]*$'; then
  pf "--prefix '$PREFIX' must be alphanumeric and start with a letter (it becomes ${PREFIX}-001-<slug>.md)."
fi

# --- the copy-list minimum ---
COPY_LIST=(
  scripts/config.sh
  scripts/new-issue.sh
  scripts/move-issue.sh
  scripts/check-board.sh
  scripts/lib/kanban-worktree.sh
  scripts/githooks/commit-msg
  .claude/templates/ISSUE.template.md
)
MISSING=()
for f in "${COPY_LIST[@]}"; do [ -e "$ROOT/$f" ] || MISSING+=("$f"); done
if [ ${#MISSING[@]} -gt 0 ]; then
  pf "the copy-list is not in place — missing: ${MISSING[*]} (this script configures, it does not copy)."
fi

# --- the push helper: LOADED here, deliberately NOT enumerated in COPY_LIST ---
# kit-init's own publishing pushes go through git_push_with_retry (four sites in
# steps 5 and 6), so this file is a hard dependency of a successful run. It is
# NOT added to COPY_LIST above: that list is a hand-typed presence check, and
# growing it by one entry per dependency somebody trips over leaves it just as
# silent about the next one. What is asserted here instead is the property this
# script actually needs — the helper LOADS and the function it calls IS DEFINED.
#
# Refusing (rather than pushing once, unretried, when the helper is absent) is
# what `process/contracts/config-seam.md` § 2 requires: "a DEGRADED path may not
# carry its own second default … it refuses and names the seam". A bare push that
# loses a race leaves the initialization commit local — one initializer run ended
# one commit ahead of its remote with a fatal at its tail, which is the incident
# this routing exists to close. It is a `pf` rather than an early exit so it is
# reported alongside every other unmet precondition in one pass, and so it lands
# inside the refusal that guarantees NOTHING WAS WRITTEN.
# shellcheck source=lib/push-retry.sh
if [ ! -f "$SCRIPT_DIR/lib/push-retry.sh" ] || ! . "$SCRIPT_DIR/lib/push-retry.sh"; then
  pf "scripts/lib/push-retry.sh is missing or could not be sourced — kit-init publishes its initialization commits through that file's git_push_with_retry, and will not fall back to a single unretried push. Restore it:  git checkout -- scripts/lib/push-retry.sh"
elif ! command -v git_push_with_retry >/dev/null 2>&1; then
  pf "scripts/lib/push-retry.sh sourced, but git_push_with_retry is NOT DEFINED — the file is present and loadable and no longer provides what kit-init calls."
fi

# --- git repo, born HEAD, identity ---
if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  pf "$ROOT is not a git repository — run 'git init' first."
elif ! git -C "$ROOT" rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
  pf "this repository has no commits yet — make the first commit on '$TRUNK' and push it (see the recipe below)."
fi
git -C "$ROOT" config user.email >/dev/null 2>&1 || pf "git user.email is not set — the board scripts commit."
git -C "$ROOT" config user.name  >/dev/null 2>&1 || pf "git user.name is not set — the board scripts commit."

# --- the remote precondition (posture: GUIDE, never bootstrap) ---
REMOTE_HEAD=""
if ! git -C "$ROOT" remote get-url "$REMOTE" >/dev/null 2>&1; then
  pf "no '$REMOTE' remote — the kanban worktree fetches, resets and pushes through it."
else
  # A filesystem remote must be ABSOLUTE. The kanban worktree runs git from
  # .kanban-wt/, one directory down, and git resolves a relative URL against the
  # working directory it is run from — so `../proj.git` reaches the remote from
  # this checkout and misses it from the worktree. Unguarded, that surfaced two
  # steps into the self-check as "does not appear to be a git repository", which
  # reads as an access problem (measured 2026-08-26). Refuse it here, as a URL.
  REMOTE_URL="$(git -C "$ROOT" remote get-url "$REMOTE" 2>/dev/null || true)"
  case "$REMOTE_URL" in
    ""|*://*|*@*:*|/*|'~'*) ;;   # a scheme, scp-style ssh, or an absolute path — fine
    *) pf "the '$REMOTE' remote URL '$REMOTE_URL' is a RELATIVE path — the kanban worktree runs git from .kanban-wt/, where it resolves somewhere else. Make it absolute:  git remote set-url $REMOTE \"\$(cd '$REMOTE_URL' && pwd -P)\"" ;;
  esac
  REMOTE_HEAD="$(git -C "$ROOT" symbolic-ref --short "refs/remotes/$REMOTE/HEAD" 2>/dev/null | sed "s|^$REMOTE/||" || true)"
  if [ -z "$REMOTE_HEAD" ]; then
    pf "$REMOTE/HEAD is not set — WITHOUT IT the trunk is resolved by fallback in kanban-worktree.sh and your first board move may push to a branch nobody chose."
  elif [ -n "$TRUNK" ] && [ "$REMOTE_HEAD" != "$TRUNK" ]; then
    pf "--trunk '$TRUNK' disagrees with $REMOTE/HEAD → '$REMOTE_HEAD'. One of the two is wrong; fix it rather than let the scripts pick."
  fi
  if [ -n "$TRUNK" ] && ! git -C "$ROOT" rev-parse --verify --quiet "refs/remotes/$REMOTE/$TRUNK" >/dev/null 2>&1; then
    pf "$REMOTE/$TRUNK does not exist locally — push the trunk and fetch before initializing."
  fi
fi

# --- the operator's checkout: on the trunk, no uncommitted TRACKED changes ---
CUR_BRANCH="$(git -C "$ROOT" symbolic-ref --short HEAD 2>/dev/null || echo "")"
if [ -n "$TRUNK" ] && [ "$CUR_BRANCH" != "$TRUNK" ]; then
  pf "this checkout is on '${CUR_BRANCH:-a detached HEAD}', not the trunk '$TRUNK' — initialize from the trunk (the board lives there)."
fi
if [ -n "$(git -C "$ROOT" status --porcelain --untracked-files=no 2>/dev/null || true)" ]; then
  pf "this checkout has uncommitted changes to TRACKED files — commit or stash them; kit-init commits the tree it initializes."
fi

# =============================================================================
# THE ALREADY-LIVED REFUSAL.
#
# The rule, stated once: this script refuses any repository that has ALREADY
# LIVED — a board carrying issue files, a progress.md § Log with entries, an
# ARCHIVE.md with an index, or a config.sh already stamped by a previous run.
# Deliberately GENERIC: naming one repository by a path literal would protect
# exactly that one, and "a repo with real work on its board" is the class that
# must never be re-initialized — the kit's own donor is simply its most obvious
# member.
# =============================================================================
LIVED=()
for folder in "${STATUS_FOLDERS[@]}"; do
  [ -d "$ROOT/progress/$folder" ] || continue
  n="$(find "$ROOT/progress/$folder" -type f -name '*-[0-9]*.md' 2>/dev/null | wc -l | tr -d ' ')"
  [ "${n:-0}" -gt 0 ] && LIVED+=("progress/$folder/ carries $n issue file(s)")
done
if [ -f "$ROOT/progress.md" ]; then
  logbody="$(awk '/^##[[:space:]]/ { if (inlog) exit; if ($0 ~ /^##[[:space:]]+Log/) { inlog=1; next } } inlog && NF { print }' "$ROOT/progress.md" | wc -l | tr -d ' ')"
  [ "${logbody:-0}" -gt 0 ] && LIVED+=("progress.md § Log holds ${logbody} line(s) of history")
fi
if [ -f "$ROOT/ARCHIVE.md" ]; then
  arcbody="$(awk '/^## Archived$/ { a=1; next } a && NF { print }' "$ROOT/ARCHIVE.md" | wc -l | tr -d ' ')"
  [ "${arcbody:-0}" -gt 0 ] && LIVED+=("ARCHIVE.md indexes ${arcbody} archived line(s)")
fi
if [ -f "$ROOT/scripts/config.sh" ] && grep -q "^${STAMP_MARK}" "$ROOT/scripts/config.sh" 2>/dev/null; then
  LIVED+=("scripts/config.sh: $(grep -m1 "^${STAMP_MARK}" "$ROOT/scripts/config.sh")")
fi

if [ ${#LIVED[@]} -gt 0 ]; then
  {
    echo ""
    echo "✗ kit-init REFUSES: this repository has already lived."
    echo ""
    for l in "${LIVED[@]}"; do echo "    • $l"; done
    echo ""
    echo "  NOTHING WAS WRITTEN. An initializer that can overwrite a working board is"
    echo "  worse than no initializer — and a half-stamped repository is worse still, so"
    echo "  there is no resume path. If this is a re-run you meant to make, revert the"
    echo "  initialization commit first; if this is the kit's donor repository, you are"
    echo "  in the wrong directory."
  } >&2
  exit 1
fi

# --- the gate command / verify.sh precondition (finish-pr.sh's landing rule) ---
# Three shapes of scripts/verify.sh, and what --gate-command does with each:
#   • absent                        → WRITE a minimal single-gate runner around <C>
#   • the shipped frame, GATES=()   → FILL the table with <C> as its first record
#   • anything else (a declared table, a hand-written runner) → REFUSE; it is yours
# The fill arm exists because the seed SHIPS the frame: without it the README's
# own day-one command refused on every fresh seed, while the frame's header told
# the reader to run the very flag that refused (measured 2026-08-26).
VERIFY="$ROOT/scripts/verify.sh"
verify_is_empty_frame() {  # true iff verify.sh is the frame and its GATES table holds no record
  grep -q '^GATES=($' "$VERIFY" 2>/dev/null \
    && ! grep -qE '^[[:space:]]+"[^"]+\|(core|select|full)\|' "$VERIFY" 2>/dev/null
}
GATE_MODE=""   # write | fill | "" (no --gate-command)
if [ -n "$GATE_CMD" ]; then
  case "$GATE_CMD" in
    *'|'*|*'"'*) pf "--gate-command '$GATE_CMD' contains '|' or '\"' — the GATES table's record format cannot carry either; put the command in a script and name the script." ;;
  esac
  if [ ! -e "$VERIFY" ]; then
    GATE_MODE=write
  elif verify_is_empty_frame; then
    GATE_MODE=fill
  elif grep -q '^GATES=($' "$VERIFY" 2>/dev/null; then
    pf "--gate-command given but scripts/verify.sh already DECLARES a gate — it will not be overwritten or appended to (edit its GATES table instead)."
  else
    pf "--gate-command given but scripts/verify.sh exists and is not the kit's frame — it will not be overwritten (it is yours to edit)."
  fi
else
  if [ ! -f "$VERIFY" ]; then
    pf "no scripts/verify.sh and no --gate-command — finish-pr.sh REFUSES to land without an executable, committed gate runner."
  elif [ ! -x "$VERIFY" ]; then
    pf "scripts/verify.sh is not executable — finish-pr.sh's preflight refuses on exactly that (chmod +x it)."
  fi
fi

if [ ${#PF[@]} -gt 0 ]; then
  {
    echo ""
    echo "✗ kit-init REFUSES — $( [ ${#PF[@]} -eq 1 ] && echo "1 precondition" || echo "${#PF[@]} preconditions" ) unmet. NOTHING WAS WRITTEN."
    echo ""
    for p in "${PF[@]}"; do echo "    • $p"; done
    echo ""
    echo "  The remote + trunk recipe (do all four; step 1 is the OFFLINE case — a local"
    echo "  bare repo is a perfectly good '$REMOTE', and needs no forge account):"
    echo ""
    echo "    1.  git init --bare /path/to/$(basename "$ROOT").git"
    echo "        git remote add $REMOTE /path/to/$(basename "$ROOT").git"
    echo "    2.  git switch -c ${TRUNK:-<your-trunk>}          # if the trunk does not exist yet"
    echo "        MSG_OK=1 git commit --allow-empty -m 'init'   # if there are no commits yet"
    echo "    3.  git push -u $REMOTE ${TRUNK:-<your-trunk>}"
    echo "    4.  git remote set-head $REMOTE ${TRUNK:-<your-trunk>}   # ← the step whose absence is SILENT"
    echo ""
    echo "  Step 4 names the branch EXPLICITLY on purpose: 'set-head $REMOTE -a' asks the"
    echo "  remote what its own HEAD is, and a freshly created bare repo has none — it fails"
    echo "  with 'Cannot determine remote HEAD'. (Fix the bare side instead, if you prefer:"
    echo "  git -C /path/to/$(basename "$ROOT").git symbolic-ref HEAD refs/heads/${TRUNK:-<your-trunk>})"
    echo ""
    echo "  Then re-run:  ./scripts/kit-init.sh --prefix <P> --trunk ${TRUNK:-<your-trunk>}"
  } >&2
  exit 1
fi

say "  repo:   $ROOT"
say "  prefix: $PREFIX"
say "  trunk:  $TRUNK  (confirmed against $REMOTE/HEAD → $REMOTE_HEAD)"
say "  remote: $REMOTE"
say "  ✓ preflight clean — proceeding."

# =============================================================================
# 2. STAMP — through the existing seams only.
# =============================================================================
step "Stamping the seams"

CONFIG="$ROOT/scripts/config.sh"
COMMITMSG="$ROOT/scripts/githooks/commit-msg"
KWTLIB="$ROOT/scripts/lib/kanban-worktree.sh"

# EVERY OLD VALUE IS DERIVED FROM A SEAM, NEVER TYPED HERE. That is what lets this
# script rewrite the travelling docs (whose prose spells the old values out)
# without carrying a single donor literal of its own — and it is what makes the
# census below a measurement rather than a promise.
OLD_PREFIX="$(sed -n 's/^ISSUE_PREFIX="\${ISSUE_PREFIX:-\([A-Za-z0-9]*\)}"/\1/p' "$CONFIG" | head -1)"
[ -n "$OLD_PREFIX" ] || { echo "Error: could not read the current ISSUE_PREFIX default out of scripts/config.sh." >&2; exit 1; }
OLD_NAME="$(sed -n 's/^PROJECT_NAME="\${PROJECT_NAME:-\([^}]*\)}"/\1/p' "$CONFIG" | head -1)"
[ -n "$OLD_NAME" ] || { echo "Error: could not read the current PROJECT_NAME default out of scripts/config.sh." >&2; exit 1; }
# The old trunk is the LAST link of kanban-worktree.sh's own resolution chain —
# the named constant that fires when <remote>/HEAD and init.defaultBranch are both
# silent.
OLD_TRUNK="$(sed -n 's/^KWT_TRUNK_LAST_RESORT="\${KWT_TRUNK_LAST_RESORT:-\([A-Za-z0-9._\/-]*\)}"/\1/p' "$KWTLIB" | head -1)"
[ -n "$OLD_TRUNK" ] || { echo "Error: could not read KWT_TRUNK_LAST_RESORT out of scripts/lib/kanban-worktree.sh." >&2; exit 1; }
NEW_NAME="${PROJECT_NAME_NEW:-$(basename "$ROOT")}"

sed -i.bak -e "s|^ISSUE_PREFIX=.*|ISSUE_PREFIX=\"\${ISSUE_PREFIX:-${PREFIX}}\"|" "$CONFIG"
say "  scripts/config.sh: ISSUE_PREFIX ${OLD_PREFIX} → ${PREFIX}"
if [ -n "$PRD_PREFIX_NEW" ]; then
  sed -i.bak -e "s|^PRD_PREFIX=.*|PRD_PREFIX=\"\${PRD_PREFIX:-${PRD_PREFIX_NEW}}\"|" "$CONFIG"
  say "  scripts/config.sh: PRD_PREFIX → ${PRD_PREFIX_NEW}"
fi
sed -i.bak -e "s|^PROJECT_NAME=.*|PROJECT_NAME=\"\${PROJECT_NAME:-${NEW_NAME}}\"|" "$CONFIG"
say "  scripts/config.sh: PROJECT_NAME ${OLD_NAME} → ${NEW_NAME}"
rm -f "$CONFIG.bak"
printf '\n%s on %s — prefix %s, trunk %s (kit-init.sh --help explains the re-run refusal).\n' \
  "$STAMP_MARK" "$(date +%Y-%m-%d)" "$PREFIX" "$TRUNK" >> "$CONFIG"

# --- the templates ---------------------------------------------------------
# Their BODY prose spells the prefix out in examples. TWO forms are stamped,
# because both are in circulation: the angle-bracket placeholder the shipped
# templates use (<PREFIX>-NNN) and the config default's own token — a knob is
# only real when something turns it, and a substitution that matches neither form
# is a silent no-op that leaves every minted card carrying a placeholder id.
TPL_HITS=0
if [ -d "$ROOT/.claude/templates" ]; then
  for t in "$ROOT"/.claude/templates/*.md; do
    [ -e "$t" ] || continue
    hit=0
    if grep -qF "${PREFIX_PLACEHOLDER}" "$t"; then
      sed -i.bak -e "s|${PREFIX_PLACEHOLDER}|${PREFIX}|g" "$t"; rm -f "$t.bak"; hit=1
    fi
    if [ "$PREFIX" != "$OLD_PREFIX" ] && grep -q "${OLD_PREFIX}-" "$t"; then
      sed -i.bak -e "s|${OLD_PREFIX}-|${PREFIX}-|g" "$t"; rm -f "$t.bak"; hit=1
    fi
    [ "$hit" -eq 1 ] && TPL_HITS=$((TPL_HITS+1))
  done
fi
say "  .claude/templates/: prefix (${PREFIX_PLACEHOLDER} and ${OLD_PREFIX}-) → ${PREFIX}- in ${TPL_HITS} template(s)"

# The templates carry the explicit placeholder `<trunk>` rather than any branch
# name, stamped here. This is the same lesson applied to the second token: a knob
# is only real when something turns it, and the role-doc substitution below is
# conditional on .claude/roles/ existing, so a templates-only copy-list was never
# reached by it.
TRUNK_TPL_HITS=0
if [ -d "$ROOT/.claude/templates" ]; then
  for t in "$ROOT"/.claude/templates/*.md; do
    [ -e "$t" ] || continue
    if grep -q '<trunk>' "$t"; then
      sed -i.bak -e "s|<trunk>|${TRUNK}|g" "$t"; rm -f "$t.bak"
      TRUNK_TPL_HITS=$((TRUNK_TPL_HITS+1))
    fi
  done
fi
say "  .claude/templates/: <trunk> → ${TRUNK} in ${TRUNK_TPL_HITS} template(s)"

# --- the ROLE DOCS ---------------------------------------------------------
# Three agents independently logged that transplanted role docs still spoke the
# donor's dialect, and the contract sheet's "a search returns nothing" had been
# measured by NOTHING (the run that claimed a clean transplant left 134
# project-name hits, 110 prefix hits and 54 trunk hits behind). So: substitute
# here too, then COUNT (below).
#
# The tokens, and why each is spelled the way it is:
#   • the prefix — the angle-bracket placeholder, plus the config default's token
#     ONLY in its PLACEHOLDER shape (<TOKEN> followed by a non-digit: -NNN, -XXX).
#     <TOKEN>-<digits> is a PROVENANCE citation and is deliberately left alone:
#     rewriting `KIT-374` to `XYZ-374` would invent a citation to an issue the
#     adopter never had. (The templates above keep their blanket rewrite — a
#     template carries examples, not provenance.)
#   • the trunk — whole word only, via a delimiter-guarded pattern run TWICE so
#     two adjacent occurrences both land. Without the guard, `development`
#     becomes `<trunk>ment`.
#   • the project name — blanket; it is a name, and every occurrence is the
#     donor's.
# RECURSIVE on purpose: a parked/archived role doc is a file the adopter will one
# day wake, and a census that skips it measures the easy half.
md_files() { [ -d "$1" ] && find "$1" -type f -name '*.md' | sort || true; }
census_count() {  # <dir> <ere> → occurrences of <ere> across the dir's .md files
  local dir="$1" re="$2" n=0 f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n=$(( n + $(grep -oE "$re" "$f" 2>/dev/null | wc -l | tr -d ' ') ))
  done < <(md_files "$dir")
  echo "$n"
}
PLACEHOLDER_RE="(${PREFIX_PLACEHOLDER}|${OLD_PREFIX}-[^0-9])"
TRUNK_RE="(^|[^A-Za-z])${OLD_TRUNK}([^A-Za-z]|\$)"
NAME_RE="${OLD_NAME}"

ROLES_DIR="$ROOT/.claude/roles"
if [ -d "$ROLES_DIR" ]; then
  RD_BEFORE_P="$(census_count "$ROLES_DIR" "$PLACEHOLDER_RE")"
  RD_BEFORE_T="$(census_count "$ROLES_DIR" "$TRUNK_RE")"
  RD_BEFORE_N="$(census_count "$ROLES_DIR" "$NAME_RE")"
  for d in "$ROLES_DIR" "$ROOT/.claude/templates"; do
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      sed -i.bak -e "s|${PREFIX_PLACEHOLDER}|${PREFIX}|g" "$f"
      [ "$PREFIX" = "$OLD_PREFIX" ] || sed -i.bak -E "s|${OLD_PREFIX}-([^0-9])|${PREFIX}-\1|g" "$f"
      if [ "$TRUNK" != "$OLD_TRUNK" ]; then
        sed -i.bak -E "s@(^|[^A-Za-z])${OLD_TRUNK}([^A-Za-z]|\$)@\1${TRUNK}\2@g" "$f"
        sed -i.bak -E "s@(^|[^A-Za-z])${OLD_TRUNK}([^A-Za-z]|\$)@\1${TRUNK}\2@g" "$f"
      fi
      [ "$NEW_NAME" = "$OLD_NAME" ] || sed -i.bak -e "s|${OLD_NAME}|${NEW_NAME}|g" "$f"
      rm -f "$f.bak"
    done < <(md_files "$d")
  done
  say "  .claude/roles/: prefix placeholders ${RD_BEFORE_P} → $(census_count "$ROLES_DIR" "$PLACEHOLDER_RE"), trunk '${OLD_TRUNK}' ${RD_BEFORE_T} → $(census_count "$ROLES_DIR" "$TRUNK_RE"), name '${OLD_NAME}' ${RD_BEFORE_N} → $(census_count "$ROLES_DIR" "$NAME_RE")"
else
  say "  .claude/roles/: absent — nothing to substitute (copy the role docs if you want them stamped)"
fi

# --- the role set: ALL THREE script seams at once -------------------------
OLD_ROLES="$(sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p" "$COMMITMSG" | head -1)"
[ -n "$OLD_ROLES" ] || { echo "Error: could not read ROLE_PREFIXES out of scripts/githooks/commit-msg." >&2; exit 1; }
if [ -n "$ROLES_NEW" ]; then
  # NOTE the '@' delimiter: the role set is a '|'-separated ERE alternation, so
  # the usual s|…|…| would be cut in half by its own data.
  for f in "$COMMITMSG" "$ROOT/scripts/move-issue.sh" "$ROOT/scripts/check-board.sh"; do
    [ -f "$f" ] || continue
    sed -i.bak -e "s@${OLD_ROLES}@${ROLES_NEW}@g" "$f"; rm -f "$f.bak"
  done
  # NOTHING rewrites the hook's help text: it DERIVES the bracketed list from
  # ROLE_PREFIXES at print time. An earlier version patched that sentence with a
  # second sed, which is one more place to drift and one more thing to get wrong.
  ROLES="$ROLES_NEW"
  say "  role set → '${ROLES}' in commit-msg + move-issue.sh + check-board.sh"
else
  ROLES="$OLD_ROLES"
  say "  role set left as copied: '${ROLES}' (change it with --roles)"
fi
# The role this script uses for its OWN commits is DERIVED from the effective
# set — never a literal, so the self-check stays donor-free whatever the set is.
SELF_ROLE="${ROLES%%|*}"

# --- the gate command ---
case "$GATE_MODE" in
fill)
  # Insert the record directly under `GATES=(`. The command travels through
  # ENVIRON, not `awk -v`: -v interprets backslash escapes, and a gate command is
  # not ours to rewrite. `cat >` rather than `mv` keeps the file's mode bits.
  KIT_INIT_GATE_RECORD="  \"gate|core|${GATE_CMD}\"" \
    awk '{ print } /^GATES=\($/ && !done { print ENVIRON["KIT_INIT_GATE_RECORD"]; done=1 }' \
    "$VERIFY" > "$VERIFY.tmp"
  cat "$VERIFY.tmp" > "$VERIFY"; rm -f "$VERIFY.tmp"
  chmod +x "$VERIFY"
  grep -qF "\"gate|core|${GATE_CMD}\"" "$VERIFY" \
    || { echo "Error: the gate record did not land in scripts/verify.sh's GATES table." >&2; exit 1; }
  say "  scripts/verify.sh: GATES table was empty — filled with \"gate|core|${GATE_CMD}\" (extend the table as you grow)"
  ;;
write)
  cat > "$ROOT/scripts/verify.sh" <<EOF
#!/usr/bin/env bash
# KIT-CLASS: MIXED — kit pattern (one gate runner, uniform invocation), PROJECT gates. See process/EXTRACTION.md.
# scripts/verify.sh — the one-shot quality-gate runner. GENERATED by kit-init.sh
# around a single gate command. It is deliberately smaller than the kit's own
# frame: one gate, one summary. When you need a second gate, a --quick/--scope
# split or a guard floor, adopt the full frame (the version of this file in the
# kit's own scripts/ directory) and declare your gates in its GATES table.
#
# Every role runs THIS, in this order, instead of re-deriving commands from prose.
# finish-pr.sh refuses to land unless this file exists, is executable, is tracked
# at HEAD, and has no uncommitted modifications.
set -uo pipefail
REPO_ROOT="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/.." && pwd)"
cd "\$REPO_ROOT"

# --quick and --scope are ACCEPTED and IGNORED here: finish-pr.sh calls
# \`verify.sh --quick\`, and a generated single-gate runner has nothing to skip.
# They are accepted rather than rejected so the landing path works on day one.
for a in "\$@"; do
  case "\$a" in
    --quick|--scope|-*) ;;
    *) ;;
  esac
done

echo "── gate: ${GATE_CMD}"
${GATE_CMD}
GATE_RC=\$?

echo ""
echo "═══ verify.sh summary ═══"
if [ "\$GATE_RC" -eq 0 ]; then echo "PASS  ${GATE_CMD}"; else echo "FAIL  ${GATE_CMD} (rc=\$GATE_RC)"; fi
exit "\$GATE_RC"
EOF
  chmod +x "$ROOT/scripts/verify.sh"
  say "  scripts/verify.sh: written around '${GATE_CMD}' (no runner existed)"
  ;;
*)
  say "  scripts/verify.sh: left as copied (present + executable — finish-pr.sh's landing precondition)"
  if verify_is_empty_frame; then
    say "     ⚠ its GATES table is EMPTY — the frame refuses to run, so finish-pr.sh cannot land anything yet."
    say "       Declare your gates in that table by hand (a re-run of kit-init refuses; --gate-command was for this run)."
  fi
  ;;
esac

# =============================================================================
# 3. BOARD — folders + .gitkeeps, progress.md, ARCHIVE.md, .gitignore.
# =============================================================================
step "Creating the board"

for d in "${BOARD_FOLDERS[@]}"; do
  mkdir -p "$ROOT/progress/$d"
  # WHY .gitkeep and not "create them empty": git does not track an empty
  # directory, so a fresh CLONE has no board — and move-issue.sh ABORTS on a
  # missing target folder. "Create them empty" does not survive a clone.
  [ -e "$ROOT/progress/$d/.gitkeep" ] || : > "$ROOT/progress/$d/.gitkeep"
done
KEEPS="$(find "$ROOT/progress" -name .gitkeep | wc -l | tr -d ' ')"
if [ "$KEEPS" -ne "$GITKEEP_EXPECTED" ]; then
  echo "Error: expected $GITKEEP_EXPECTED .gitkeep files under progress/, found $KEEPS." >&2; exit 1
fi
say "  progress/: ${#BOARD_FOLDERS[@]} folders, ${KEEPS}/${GITKEEP_EXPECTED} .gitkeep files ✓"

if [ ! -f "$ROOT/progress.md" ]; then
  cat > "$ROOT/progress.md" <<EOF
# progress.md

The running log of activity in this project. All roles append entries here. The
kanban folders under \`progress/\` are the source of truth for *current* status —
this file is the *history*.

## Status quick reference

Run \`ls progress/todo/ progress/in_progress/ progress/dev_complete/ progress/qa_complete/ progress/blocked/\`
to see the board. Each filename is \`${PREFIX}-NNN-<slug>.md\`; the folder is the status.
\`./scripts/check-board.sh\` reports board drift. Older entries rotate into
\`progress/history/\` via \`./scripts/archive-progress.sh\`.

## How to write an entry

Two shapes below are REQUIRED, not stylistic — a script reads each one:

- the \`## Log\` heading itself: check-board.sh probes for it
  (\`grep -qE '^##[[:space:]]+Log'\`) before it can report this section's size;
- a dated heading per session: archive-progress.sh splits this file on
  \`## YYYY-MM-DD\` / \`### YYYY-MM-DD\` boundaries when it rotates, so each
  session's entries sit under ONE heading.

\`\`\`markdown
### YYYY-MM-DD [Role] <session title>

- what was decided, deviated from, skipped, or handed off.
\`\`\`

Everything below the next heading is history; nothing above it is.

## Log
EOF
  say "  progress.md: skeleton written (## Log + the dated-heading convention)"
else
  grep -qE '^##[[:space:]]+Log' "$ROOT/progress.md" || {
    echo "Error: progress.md exists but has no '## Log' heading (check-board.sh probes for it)." >&2; exit 1; }
  say "  progress.md: already present with a '## Log' heading — left alone"
fi

if [ ! -f "$ROOT/ARCHIVE.md" ]; then
  cat > "$ROOT/ARCHIVE.md" <<EOF
# ARCHIVE.md

One-line summaries of issues swept off the active board out of
\`progress/qa_complete/\`. The full bodies live in \`progress/done/\`.

The heading below must read exactly \`## Archived\`: archive.sh refuses to
sweep without it, and inserts each new line immediately beneath it.

## Archived
EOF
  say "  ARCHIVE.md: stub written (with the exact '## Archived' heading archive.sh requires)"
else
  grep -q '^## Archived$' "$ROOT/ARCHIVE.md" || {
    echo "Error: ARCHIVE.md exists but has no exact '## Archived' heading (archive.sh refuses without it)." >&2; exit 1; }
  say "  ARCHIVE.md: already present with '## Archived' — left alone"
fi

# The kanban worktree and its lock live at the repo root and are NEVER tracked.
# Without these entries every board move leaves the tree looking dirty.
#
# `.claude/session-role` joins them for a different reason
# (process/contracts/role-gate.md § 2: "a hat declaration is SESSION STATE, never
# repository content"). Tracked, it forks per branch, blocks a boundary
# `git switch` with "local changes would be overwritten", and reaches a landing
# gate as a merge conflict over a fact nobody was collaborating on. Four agents
# paid for it in one twelve-hour transplant; one hit the conflict.
touch "$ROOT/.gitignore"
IGN_ADDED=0
for entry in '.kanban-wt/' '.kanban-wt.lock/' '.kanban-wt.lock.reap/' '.claude/session-role'; do
  grep -qxF "$entry" "$ROOT/.gitignore" || { printf '%s\n' "$entry" >> "$ROOT/.gitignore"; IGN_ADDED=$((IGN_ADDED+1)); }
done
say "  .gitignore: ${IGN_ADDED} entr(y|ies) added (kanban worktree + .claude/session-role)"

# =============================================================================
# 4. HOOKS
# =============================================================================
step "Wiring the git hooks"
git -C "$ROOT" config core.hooksPath scripts/githooks
say "  core.hooksPath = scripts/githooks  (proven below by a real rejected commit)"

# =============================================================================
# 5. COMMIT + PUSH — the board must exist ON THE TRUNK.
#
# Not a nicety: move-issue.sh operates inside .kanban-wt/, which is reset --hard
# to <remote>/<trunk> on every op. A board that exists only in this checkout is
# invisible to every board script.
# =============================================================================
step "Committing the initialized tree to $TRUNK"
ADD_PATHS=()
for p in scripts .claude progress progress.md ARCHIVE.md .gitignore process requirements dev; do
  [ -e "$ROOT/$p" ] && ADD_PATHS+=("$p")
done
git -C "$ROOT" add -A -- "${ADD_PATHS[@]}"
if git -C "$ROOT" diff --cached --quiet; then
  say "  nothing to commit (tree already matches)"
else
  git -C "$ROOT" diff --cached --name-only | sed 's/^/    /'
  git -C "$ROOT" commit -q -m "[$SELF_ROLE] kit-init: initialize the kit — prefix $PREFIX, trunk $TRUNK"
  # THROUGH THE RETRY HELPER, not a bare push — here and at the three self-check
  # pushes below. A single `git push` that loses a race against a parallel
  # landing dies with the commit surviving only locally; one initializer run
  # ended exactly there, one commit ahead of its remote with a fatal at its tail,
  # and a by-hand push completed it. The helper's semantics are IDENTICAL to what
  # stood here (it pushes `HEAD:<branch>`), and its rebase-on-rejection step is
  # safe in this script specifically because the preflight already refuses unless
  # this checkout is ON the trunk — so the rebase can only ever be the trunk onto
  # its own remote tip, which is the same act every board move performs.
  git_push_with_retry "$ROOT" "$REMOTE" "$TRUNK"
  say "  committed + pushed → $REMOTE/$TRUNK"
fi

if [ "$RUN_SELFCHECK" != "true" ]; then
  step "Self-check SKIPPED (--skip-self-check)"
  say "  Nothing has been PROVEN. Run ./scripts/kit-init.sh --help and read the note on this flag."
  exit 0
fi

# =============================================================================
# 6. THE SELF-CHECK.
#
# It keeps the four things that must work on day one or the board is fiction — a
# card can be MINTED with the right identity, MOVED between columns, the board
# REPORTS clean, and the commit-msg hook actually FIRES — plus two invariants that
# were each paid for in a real transplant (a hat declaration is session state; the
# census is counted, not promised).
# Deliberately out of day-one scope: the finish-pr merge cases (they need a code
# branch and a green gate) and the archive sweep (it needs a full qa_complete
# column). scripts/test/run.sh covers those in a throwaway sandbox.
# Every value below is DERIVED: the prefix from --prefix, the trunk from
# <remote>/HEAD, the role from the effective role set's first token.
# =============================================================================
step "Self-check — prefix $PREFIX, trunk $TRUNK, role [$SELF_ROLE]"

SC_FAIL=0
sc_ok()   { printf '  ✓ %s\n' "$1"; }
sc_bad()  { printf '  ✗ %s\n' "$1" >&2; SC_FAIL=$((SC_FAIL+1)); }

SCRATCH_ID="${PREFIX}-${SCRATCH_NUM}"
SCRATCH_FILE="${SCRATCH_ID}-${SCRATCH_SLUG}.md"

# --- (1) mint a scratch card through the real creation path -----------------
if "$ROOT/scripts/new-issue.sh" "$SCRATCH_SLUG" --id "$SCRATCH_ID" >/dev/null 2>&1 \
   && [ -f "$ROOT/progress/todo/$SCRATCH_FILE" ]; then
  sc_ok "minted progress/todo/$SCRATCH_FILE"
  # The identity check a silent substitution no-op would fail: the frontmatter id
  # must carry the REAL prefix, not the template's placeholder.
  if grep -qE "^id: ${SCRATCH_ID}$" "$ROOT/progress/todo/$SCRATCH_FILE"; then
    sc_ok "frontmatter carries 'id: ${SCRATCH_ID}' — the prefix reached the template body"
  else
    sc_bad "frontmatter id is '$(grep -m1 '^id:' "$ROOT/progress/todo/$SCRATCH_FILE" || echo '<none>')', expected 'id: ${SCRATCH_ID}'"
  fi
  git -C "$ROOT" add "progress/todo/$SCRATCH_FILE"
  git -C "$ROOT" commit -q -m "[$SELF_ROLE] kit-init self-check: mint scratch card $SCRATCH_ID"
  git_push_with_retry "$ROOT" "$REMOTE" "$TRUNK"
else
  sc_bad "could not mint $SCRATCH_ID via scripts/new-issue.sh"
fi

# --- (2) move it through TWO columns ----------------------------------------
if [ "$SC_FAIL" -eq 0 ]; then
  for col in in_progress dev_complete; do
    # The move's own output is captured and REPLAYED on failure — a self-check
    # that says only "it did not work" sends the reader back to reading.
    if MV_OUT="$("$ROOT/scripts/move-issue.sh" "$SCRATCH_ID" "$col" --role "$SELF_ROLE" \
         --note "kit-init self-check → $col" 2>&1)"; then
      sc_ok "moved $SCRATCH_ID → progress/$col/"
    else
      sc_bad "move-issue.sh could not move $SCRATCH_ID → $col:"
      printf '%s\n' "$MV_OUT" | sed 's/^/      /' >&2
      break
    fi
  done
fi

# --- (3) the board reports clean --------------------------------------------
# CLAUDE_PROJECT_DIR is passed explicitly: check-board.sh honours it over its own
# location, so an inherited value from another repo's session would have it report
# on THAT board instead of this one.
BOARD_OUT="$(CLAUDE_PROJECT_DIR="$ROOT" "$ROOT/scripts/check-board.sh" 2>&1 || true)"
if printf '%s' "$BOARD_OUT" | grep -q 'board-drift: clean'; then
  sc_ok "check-board.sh: clean"
else
  # Two lines carry ⚠ without being findings-of-ours, and both must be excluded
  # or this check can never pass:
  #   • check-board.sh's own trailing SUMMARY ("── board-drift: findings above ⚠")
  #     — it is emitted whenever there is at least one finding, so matching it as
  #     a finding makes the check self-fulfilling. Every real finding is indented
  #     or starts with its "[x]" section tag; only the summary starts with "──".
  #   • the role-prefix scan over PRE-EXISTING history this script did not author —
  #     an adopter's pre-kit commits legitimately have no [Role] prefix.
  # Anything else is a real finding.
  OTHER="$(printf '%s\n' "$BOARD_OUT" | grep '⚠' | grep -v '^──' | grep -v 'lacks a \[Role\] prefix' || true)"
  if [ -z "$OTHER" ]; then
    sc_ok "check-board.sh: clean apart from pre-existing commits with no [Role] prefix (history predating the kit)"
  else
    sc_bad "check-board.sh reported drift:"
    printf '%s\n' "$OTHER" >&2
  fi
fi

# --- (4) the commit-msg hook FIRES (this is the core.hooksPath proof) -------
if git -C "$ROOT" commit --allow-empty -q -m "kit-init self-check: this subject has no role tag" 2>/dev/null; then
  sc_bad "the commit-msg hook did NOT reject a prefix-less subject — core.hooksPath is not in effect"
  git -C "$ROOT" reset -q --hard HEAD~1
else
  sc_ok "commit-msg hook REJECTED a prefix-less subject (core.hooksPath is live)"
  if git -C "$ROOT" commit --allow-empty -q -m "[$SELF_ROLE] kit-init self-check: commit-msg hook accepts a role-tagged subject"; then
    sc_ok "…and ACCEPTED '[$SELF_ROLE] …'"
    git_push_with_retry "$ROOT" "$REMOTE" "$TRUNK"
  else
    sc_bad "the hook rejected a correctly tagged subject '[$SELF_ROLE] …' — check ROLE_PREFIXES"
  fi
fi

# --- (5) a hat declaration is SESSION STATE, not repository content ----------
# DECLARE a hat the way an actor would, then assert the repository does not see
# it. An ignore entry nobody exercised is a promise, not a guarantee.
SR_DIR="$ROOT/.claude"; SR_FILE="$SR_DIR/session-role"; SR_PRE_EXISTING=false
[ -f "$SR_FILE" ] && SR_PRE_EXISTING=true
mkdir -p "$SR_DIR"
[ "$SR_PRE_EXISTING" = true ] || printf 'Dev\n' > "$SR_FILE"
if git -C "$ROOT" status --porcelain | grep -q 'session-role'; then
  sc_bad "a hat declaration shows up in git status — .claude/session-role is not ignored (role-gate.md § 2)"
else
  sc_ok "a hat declaration is invisible to git status — session state, not repository content"
fi
[ "$SR_PRE_EXISTING" = true ] || rm -f "$SR_FILE"

# --- (6) THE CENSUS — asserted rather than promised --------------------------
# process/contracts/config-seam.md: "A search of the travelling files for the
# donor's own values returns NOTHING — a count, run by the adopter, not a promise
# made by the donor." Here is the count. A token whose new value EQUALS the
# shipped one is skipped: there is nothing to remove, and counting it would fail
# the adopter for agreeing with the kit.
CENSUS_TOTAL=0
census_report() {  # <label> <ere> <changed?>
  local label="$1" re="$2" changed="$3" n=0 d
  if [ "$changed" != "true" ]; then
    sc_ok "census — ${label}: not counted (your value is the shipped one)"
    return
  fi
  for d in "$ROOT/.claude/roles" "$ROOT/.claude/templates"; do
    n=$(( n + $(census_count "$d" "$re") ))
  done
  CENSUS_TOTAL=$(( CENSUS_TOTAL + n ))
  if [ "$n" -eq 0 ]; then sc_ok "census — ${label}: 0 in .claude/roles + .claude/templates"
  else sc_bad "census — ${label}: ${n} occurrence(s) survive in .claude/roles + .claude/templates"; fi
}
census_report "prefix placeholders (${PREFIX_PLACEHOLDER} / ${OLD_PREFIX}-)" "$PLACEHOLDER_RE" "true"
census_report "trunk '${OLD_TRUNK}'"       "$TRUNK_RE" "$( [ "$TRUNK" != "$OLD_TRUNK" ] && echo true || echo false )"
census_report "project name '${OLD_NAME}'" "$NAME_RE"  "$( [ "$NEW_NAME" != "$OLD_NAME" ] && echo true || echo false )"
# Reported, never asserted: <TOKEN>-<digits> is a provenance citation, and
# rewriting it would manufacture a reference the adopter's history never had.
PROV=0
for d in "$ROOT/.claude/roles" "$ROOT/.claude/templates"; do
  PROV=$(( PROV + $(census_count "$d" "${OLD_PREFIX}-[0-9]") ))
done
say "  ℹ ${PROV} provenance citation(s) of the shape ${OLD_PREFIX}-<digits> remain, on purpose — delete them by hand if they distract."

# --- (7) leave the board pristine -------------------------------------------
LEFTOVER="$(find "$ROOT/progress" -type f -name "${SCRATCH_ID}-*.md" 2>/dev/null | head -1)"
if [ -n "$LEFTOVER" ]; then
  git -C "$ROOT" rm -q "$LEFTOVER"
  git -C "$ROOT" commit -q -m "[$SELF_ROLE] kit-init self-check: remove the scratch card — the board is yours, empty"
  git_push_with_retry "$ROOT" "$REMOTE" "$TRUNK"
  sc_ok "scratch card removed — the board is empty (its life stays in the trunk history)"
fi

step "Result"
if [ "$SC_FAIL" -eq 0 ]; then
  say "  ✓ kit-init COMPLETE and PROVEN — prefix $PREFIX, trunk $TRUNK, role tag [$SELF_ROLE] …"
  say ""
  say "  Next: write your project doc + adapter, state your code-vs-metadata globs,"
  if [ -n "$GATE_MODE" ]; then
    say "  extend scripts/verify.sh's gate table as the project grows, and mint your first issue:"
  else
    say "  declare your gates in scripts/verify.sh, and mint your first issue:"
  fi
  say ""
  # THE kit-init × next-id COMPOSITION BUG, replicated TWICE by live agents. The
  # recipe printed here used to embed $(./scripts/next-id.sh), which on the board
  # this script has just left EMPTY correctly REFUSES:
  # process/contracts/id-minting.md makes choosing where numbering starts a
  # DECISION, not an inference. The contract is right; the composition was wrong.
  # So the FIRST id is printed as a literal — computed here, where the prefix is
  # known and the board is known to be empty — and next-id.sh is deferred to the
  # second mint, where it has something to read. next-id.sh is UNCHANGED.
  say "      ./scripts/new-issue.sh <slug> --id ${PREFIX}-001      # the FIRST id: this board is empty,"
  say "                                                    # so next-id.sh correctly refuses"
  say "      ./scripts/new-issue.sh <slug> --id \"\$(./scripts/next-id.sh)\"   # every mint AFTER the first"
  say ""
  say "  Then commit and PUSH the new card before moving it — ./scripts/move-issue.sh"
  say "  reads the trunk's board, not your checkout (new-issue.sh prints the exact commands)."
  exit 0
else
  say "  ✗ kit-init self-check FAILED — $SC_FAIL check(s) above. The tree IS initialized and"
  say "    committed; fix what the failures name and re-run the individual scripts by hand."
  exit 1
fi
