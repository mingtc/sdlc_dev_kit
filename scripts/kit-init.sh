#!/usr/bin/env bash
# KIT-CLASS: KIT — the executable bootstrap: stamp the seams, create the board, wire the hooks, self-check. See process/EXTRACTION.md.
# =============================================================================
# scripts/kit-init.sh — initialize THE KIT in a repository that has already
# received the copy-list (process/EXTRACTION.md § 1, or process/SEED.md step 2).
#
# WHAT IT DOES (in this order — nothing is written until every check passes)
#   1. PREFLIGHT   — every precondition, all reported at once, then refuse.
#   2. STAMP       — the prefix / trunk / project name / role set / gate command,
#                    through the EXISTING seams only (scripts/config.sh,
#                    .claude/templates/, .claude/roles/, PROJECT.md, githooks/commit-msg +
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
#     The preflight checks only a hand-listed MINIMUM of it (COPY_LIST below).
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

# The kanban scripts resolve their repository from the CURRENT WORKING DIRECTORY
# (kwt_resolve has no -C), so kit-init works from the root of the repository it initializes.
cd "$ROOT"

# The remote name the kanban worktree uses (kanban-worktree.sh's KWT_REMOTE knob).
REMOTE="${KWT_REMOTE:-origin}"

# The lifecycle. The status set is a seam WITHOUT a variable: process/EXTRACTION.md § 2.2's
# table lists the files that carry it, and this file is one of its rows.
STATUS_FOLDERS=(todo in_progress dev_complete qa_complete blocked done declined)
# + history/ for rotated progress.md sections (archive-progress.sh's destination).
BOARD_FOLDERS=("${STATUS_FOLDERS[@]}" history)
# One .gitkeep per board folder; the count is ASSERTED after creation, against an
# expectation DERIVED from the folder-set array above.
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
# THE CLASSIFICATION MARKER'S KEY is the convention's own word, not the issue prefix; it only
# LOOKS like the shipped placeholder prefix `KIT`. The prefix substitutions below match
# `<OLD_PREFIX>-`, so they hide the key behind the sentinel first, or every stamped file
# would read `XYZ-CLASS:`.
CLASS_MARKER_KEY='KIT-CLASS:'
CLASS_MARKER_SENTINEL='@@KITCLASSKEY@@'

# THE HAT THIS SCRIPT'S OWN COMMITS CARRY — the PRE-ROLE HAT, process/contracts/role-gate.md
# § 2a's default; KIT_INIT_ROLE overrides it. Never derived by position: seat identity is not a
# position (scripts/lib/role-set.sh). The self-test holds this literal equal to § 2a's token.
KIT_INIT_ROLE_DEFAULT='PM'
SELF_ROLE="${KIT_INIT_ROLE:-$KIT_INIT_ROLE_DEFAULT}"

PREFIX=""; TRUNK=""; PRD_PREFIX_NEW=""; ROLES_NEW=""; GATE_CMD=""; RUN_SELFCHECK=true
PROJECT_NAME_NEW=""

usage() {
  cat <<'EOF'
kit-init.sh — initialize the process kit in a repository that has already
received the copy-list.

  SCOPE: CONFIGURE-ONLY. This script stamps, creates, wires and verifies. It
  does NOT copy the kit — there is no --from mode. Copy the files named in
  process/EXTRACTION.md § 1 first (scripts/, .claude/templates/, the role docs,
  process/); this script's preflight then checks a hand-listed minimum of that
  list and refuses, naming what is missing. It is not a manifest check: a file
  that travels but is not in the minimum is not caught. It reads the shipped
  process/KIT-MANIFEST for one other question only, and refuses while any
  shipped path is on disk but not committed. Nothing is written unless every
  precondition passes.

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
                      REFUSED, naming the character and its position, if <N>
                      contains any of  '  "  `  $  \  &  }  |  or a newline: the
                      name is stamped into a shell assignment in scripts/config.sh,
                      and those either leave that file unsourceable (so every
                      script that reads it dies) or change the stamped value
                      without saying so. It is not rewritten for you.
  --prd-prefix <P>    PRD id prefix (default: left as config.sh has it).
  --roles "A|B|C"     Your role set, as the ERE alternation the commit-msg hook
                      enforces: names of letters and digits, each starting with a
                      letter. Stamped into every script seam that ENFORCES it —
                      the seams are DERIVED at run time, not listed here, and the
                      run prints the ones it stamped. process/EXTRACTION.md § 2.4
                      is where the register lives. Default: left as copied.
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
  KIT_INIT_ROLE=<R>   (environment) The hat this script's own commits carry. Default:
                      the pre-role hat, process/contracts/role-gate.md § 2a. Must be a
                      member of the role set in force, or the run is refused before
                      anything is written. Set it when your project wears another hat
                      before any role is declared, or declares a set without that one.
  --skip-self-check   Stamp and create, but do not run the self-check. Discouraged
                      — the self-check is the only part that PROVES the result.
  -h, --help          This text.

The remote precondition (the silent-corruption class this script exists for):
  kanban-worktree.sh resolves the trunk as <remote>/HEAD → init.defaultBranch →
  a last-resort literal. A fresh repo with no <remote>/HEAD therefore gets a
  trunk name nobody chose (the fallback WARNS loudly, but a warning read
  after the fact is not a decision made before it). This script GUIDES rather
  than bootstraps: it refuses when the remote or its HEAD is missing and prints
  the recipe — including the LOCAL BARE-REPO recipe for a project with no forge
  at all. Creating a remote is a repository-topology decision an initializer
  must not make on your behalf.

The census (a measurement, not a promise):
  process/contracts/config-seam.md says a search of the travelling files for the
  donor's own values must return NOTHING — "a count, run by the adopter, not a
  promise made by the kit". This script runs that count itself, over
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
# need_val — refuse an option whose value is missing: exit 2, naming it (issue-creation.md § 3).
need_val() {
  [ "$#" -ge 2 ] || { echo "Error: $1 requires a value." >&2; exit 2; }
}

# validate_project_name <name> — refuse a --project-name that cannot survive being
# stamped into config.sh. Returns non-zero and names the character AND its position.
#
# The value becomes the default in `PROJECT_NAME="${PROJECT_NAME:-<the value>}"`, through a
# sed replacement, and a hostile character breaks at one of three stages:
#   • UNSOURCEABLE — config.sh stops being valid shell and every script sourcing it dies:
#     '  "  `  and an embedded NEWLINE.
#   • SILENTLY WRONG — it sources, but PROJECT_NAME is not what was typed (the dangerous class):
#       $   expands at source time
#       \   is eaten by the sed replacement
#       &   is sed's "the whole match", splicing the config line into the value
#       }   closes the expansion early, truncating the name
#   • HALF-STAMPED — `|` is the sed DELIMITER: sed aborts AFTER the seams above it are
#     stamped, and a second run refuses with no resume path.
# The self-test re-derives the set by stamping every printable ASCII character and holds this
# function to it in both directions. It REFUSES rather than sanitising: a rewritten name is one
# the caller did not type and cannot search for.
validate_project_name() {
  local name="$1" pos=1 ch what
  if [ -z "$name" ]; then
    echo "Error: --project-name requires a non-empty value." >&2
    return 1
  fi
  case "$name" in
    *"
"*) echo "Error: --project-name — an embedded newline is not allowed." >&2
        echo "       It aborts the substitution that writes scripts/config.sh." >&2
        return 1 ;;
  esac
  while [ "$pos" -le "${#name}" ]; do
    ch="${name:$((pos-1)):1}"
    what=""
    case "$ch" in
      "'")  what="an apostrophe" ;;
      '"')  what="a double quote" ;;
      '`')  what="a backtick" ;;
      '$')  what="a dollar sign" ;;
      '\')  what="a backslash" ;;
      '&')  what="an ampersand" ;;
      '}')  what="a closing brace" ;;
      '|')  what="a pipe" ;;
    esac
    if [ -n "$what" ]; then
      echo "Error: --project-name '$name' — $what at position $pos is not allowed." >&2
      echo "       The name is stamped into scripts/config.sh as the default of" >&2
      echo "       PROJECT_NAME=\"\${PROJECT_NAME:-<name>}\", and that character would" >&2
      case "$ch" in
        "'"|'"'|'`') echo "       leave config.sh unparseable — every script that sources it dies." >&2 ;;
        *)           echo "       change the stamped value without saying so." >&2 ;;
      esac
      echo "       It is not rewritten for you: the name you type is the name you get." >&2
      echo "       Spell it without that character (a hyphen or a space reads fine)." >&2
      return 1
    fi
    pos=$(( pos + 1 ))
  done
  return 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix)         need_val "$@"; PREFIX="$2"; shift 2 ;;
    # Refused at parse time, before anything is written (see validate_project_name).
    --project-name)   need_val "$@"; validate_project_name "$2" || exit 2; PROJECT_NAME_NEW="$2"; shift 2 ;;
    --trunk)          need_val "$@"; TRUNK="$2"; shift 2 ;;
    --prd-prefix)     need_val "$@"; PRD_PREFIX_NEW="$2"; shift 2 ;;
    --roles)          need_val "$@"; ROLES_NEW="$2"; shift 2 ;;
    --gate-command)   need_val "$@"; GATE_CMD="$2"; shift 2 ;;
    --skip-self-check) RUN_SELFCHECK=false; shift ;;
    -h|--help)        usage; exit 0 ;;
    # An unrecognised option exits 2; a surplus positional exits 1 (issue-creation.md § 3).
    -*) echo "Error: unknown option: $1" >&2; echo "Try --help." >&2; exit 2 ;;
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
# THE SAME RULE FOR --prd-prefix: the hygiene instruments derive their PRD id pattern
# (`[A-Za-z0-9]+`) from it, so a prefix outside that class makes them silently miss PRD ids.
if [ -n "$PRD_PREFIX_NEW" ] && ! printf '%s' "$PRD_PREFIX_NEW" | grep -qE '^[A-Za-z][A-Za-z0-9]*$'; then
  pf "--prd-prefix '$PRD_PREFIX_NEW' must be alphanumeric and start with a letter (it becomes ${PRD_PREFIX_NEW}-001-<slug>.md, and the hygiene instruments derive their id pattern from it)."
fi
# AND FOR --roles, which is stamped through a sed replacement into single-quoted shell lines:
# '&', '@' and a quote each mis-stamp or break a seam.
if [ -n "$ROLES_NEW" ] && ! printf '%s' "$ROLES_NEW" | grep -qE '^[A-Za-z][A-Za-z0-9]*(\|[A-Za-z][A-Za-z0-9]*)*$'; then
  _r_ok="${ROLES_NEW%%[!A-Za-z0-9|]*}"
  if [ "${#_r_ok}" -lt "${#ROLES_NEW}" ]; then
    _r_why="'${ROLES_NEW:${#_r_ok}:1}' at position $(( ${#_r_ok} + 1 )) is not allowed"
  else
    _r_why="a name is empty or starts with a digit"
  fi
  pf "--roles '$ROLES_NEW' — $_r_why: the set is role names joined by '|', each alphanumeric and starting with a letter."
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
# kit-init's publishing pushes go through git_push_with_retry, so what is asserted is that the
# helper LOADS and DEFINES it — not one more COPY_LIST entry. It refuses rather than falling
# back to an unretried push (process/contracts/config-seam.md § 2: a degraded path may not
# carry its own second default), and as a `pf`, inside the NOTHING WAS WRITTEN refusal.
# shellcheck source=lib/push-retry.sh
if [ ! -f "$SCRIPT_DIR/lib/push-retry.sh" ] || ! . "$SCRIPT_DIR/lib/push-retry.sh"; then
  pf "scripts/lib/push-retry.sh is missing — kit-init publishes its initialization commits through that file's git_push_with_retry, and will not fall back to a single unretried push. Restore it:  git checkout -- scripts/lib/push-retry.sh (This check sees ABSENCE only — an unsourceable file aborts before this message.)"
elif ! command -v git_push_with_retry >/dev/null 2>&1; then
  pf "scripts/lib/push-retry.sh sourced, but git_push_with_retry is NOT DEFINED — the file is present and loadable and no longer provides what kit-init calls."
fi

# shellcheck source=lib/lived-probe.sh
if [ ! -f "$SCRIPT_DIR/lib/lived-probe.sh" ] || ! . "$SCRIPT_DIR/lib/lived-probe.sh"; then
  pf "scripts/lib/lived-probe.sh is missing — kit-init decides whether this repository has ALREADY LIVED through that file, and will not initialize a tree it cannot prove is unlived. Restore it:  git checkout -- scripts/lib/lived-probe.sh (This check sees ABSENCE only — an unsourceable file aborts before this message.)"
elif ! command -v kit_lived_signals >/dev/null 2>&1; then
  pf "scripts/lib/lived-probe.sh sourced, but kit_lived_signals is NOT DEFINED — the file is present and loadable and no longer provides what kit-init calls."
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
  # A filesystem remote must be ABSOLUTE: the kanban worktree runs git from .kanban-wt/,
  # where a relative URL resolves somewhere else.
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

# --- the kit itself must be COMMITTED: no shipped path on disk and untracked ---
# kit-init's own commit (§ 5) adds only the paths it writes and trusts the adopter's first
# commit to hold the rest; a shipped path left uncommitted is on disk here and absent from the
# trunk and every clone.
# THE POPULATION is process/KIT-MANIFEST's path column plus the manifest itself (read, never
# copied). THE TEST is "ON DISK AND NOT TRACKED":
#   * NOT "absent from HEAD": deleting a shipped file before the first commit is the supported
#     way to decline it.
#   * IGNORED COUNTS: ignoring cannot be how a shipped file is declined, and a global excludes
#     file written for other repositories is the likeliest cause. `git add -f` overrides.
# No manifest, or one whose path column yields nothing, means no check, and it says so.
KIT_MANIFEST_FILE="$ROOT/process/KIT-MANIFEST"
if [ -f "$KIT_MANIFEST_FILE" ] && git -C "$ROOT" rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
  _km_paths="$(grep -v '^#' "$KIT_MANIFEST_FILE" | awk -F'  ' 'NF>=2 {print $2}' || true)"
  if [ -z "$_km_paths" ]; then
    say "  ℹ process/KIT-MANIFEST yields no paths (empty, or not '<sha256>  <path>  <class>' with two-space separators) — the uncommitted-kit check is skipped."
  else
    # -z so a C-quoted name still compares equal. No reader exits early (`sed -n '1,5p'`,
    # not `head`), so pipefail cannot turn a SIGPIPE into a false refusal.
    UNCOMMITTED_KIT="$(comm -23 \
      <({ printf '%s\n' process/KIT-MANIFEST; printf '%s\n' "$_km_paths"; } | while IFS= read -r _p; do
          if [ -e "$ROOT/$_p" ]; then printf '%s\n' "$_p"; fi
        done | sort -u) \
      <(git -C "$ROOT" ls-files -c -z 2>/dev/null | tr '\0' '\n' | sort -u))"
    if [ -n "$UNCOMMITTED_KIT" ]; then
      _uk_n="$(printf '%s\n' "$UNCOMMITTED_KIT" | wc -l | tr -d ' ')"
      _uk_eg="$(printf '%s\n' "$UNCOMMITTED_KIT" | sed -n '1,5p' | tr '\n' ' ')"
      _uk_ign="$(printf '%s\n' "$UNCOMMITTED_KIT" | git -C "$ROOT" check-ignore --stdin 2>/dev/null || true)"
      _uk_ign_note=""
      if [ -n "$_uk_ign" ]; then
        _uk_ign_note="
        $(printf '%s\n' "$_uk_ign" | wc -l | tr -d ' ') of them are IGNORED ($(printf '%s\n' "$_uk_ign" | sed -n '1,5p' | tr '\n' ' ')) — 'git check-ignore -v <path>' names the rule; a global excludes file is the usual one. The command below adds them with -f; delete a file instead if you do not want it."
      fi
      pf "${_uk_n} shipped kit path(s) are on disk but NOT COMMITTED (e.g. ${_uk_eg}) — kit-init commits only the paths it writes, so the rest would never reach '$TRUNK'.${_uk_ign_note}
        Commit exactly the shipped paths still on disk (nothing else of yours), then push:
          cd \"\$(git rev-parse --show-toplevel)\" && { echo process/KIT-MANIFEST; awk -F'  ' '!/^#/ && NF>=2 {print \$2}' process/KIT-MANIFEST; } | while IFS= read -r p; do [ ! -e \"\$p\" ] || echo \"\$p\"; done | git --literal-pathspecs add -f --pathspec-from-file=-
          MSG_OK=1 git commit -m '[PM] commit the kit files' && git push"
    fi
  fi
elif [ ! -f "$KIT_MANIFEST_FILE" ]; then
  say "  ℹ no process/KIT-MANIFEST — the uncommitted-kit check is skipped (it reads that file)."
fi

# --- every path § 5 will commit must be ADDABLE: none of them ignored ---
# git refuses an EXPLICIT pathspec that an ignore rule matches, even over tracked content, and
# § 5 runs AFTER stamping — a failure there leaves a half-initialized repository with no resume
# path. THE TEST IS § 5's OWN COMMAND, dry-run (it stages nothing), not a re-derivation of git's
# ignore rules. The remedy UN-ignores: skipping an ignored directory would silently drop
# whatever kit-init later creates inside it.
# THE LIST IS DECLARED ONCE, here, and § 5 reads it.
KIT_COMMIT_PATHS=(scripts .claude progress progress.md ARCHIVE.md .gitignore process requirements dev PROJECT.md)
if git -C "$ROOT" rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
  _kc_present=()
  for _p in "${KIT_COMMIT_PATHS[@]}"; do [ -e "$ROOT/$_p" ] && _kc_present+=("$_p"); done
  if [ ${#_kc_present[@]} -gt 0 ] && ! _kc_out="$(git -C "$ROOT" add -A --dry-run -- "${_kc_present[@]}" 2>&1)"; then
    _kc_ign=()
    for _p in "${_kc_present[@]}"; do
      git -C "$ROOT" check-ignore --no-index -q -- "$_p" 2>/dev/null && _kc_ign+=("$_p")
    done
    if [ ${#_kc_ign[@]} -gt 0 ]; then
      _kc_neg=""
      for _p in "${_kc_ign[@]}"; do
        if [ -d "$ROOT/$_p" ]; then _kc_neg="$_kc_neg'!/$_p/' "; else _kc_neg="$_kc_neg'!/$_p' "; fi
      done
      pf "path(s) kit-init commits are IGNORED: ${_kc_ign[*]} — its commit step would fail on them AFTER stamping, leaving a half-initialized repository with no resume path. 'git check-ignore -v --no-index <path>' names the rule. Un-ignore them in this repository (a line in .gitignore overrides .git/info/exclude and a global excludes file), commit that, then push:
          cd \"\$(git rev-parse --show-toplevel)\" && printf '%s\\n' ${_kc_neg}>> .gitignore && git add .gitignore && MSG_OK=1 git commit -m '[PM] un-ignore the paths the kit commits' && git push"
    else
      pf "git cannot stage the paths kit-init commits (a dry run of its own 'git add' failed) — it would fail AFTER stamping. git said: $(printf '%s' "$_kc_out" | tr '\n' ' ' | cut -c1-300)"
    fi
  fi
fi

# =============================================================================
# THE ALREADY-LIVED REFUSAL.
#
# This script refuses any repository that has ALREADY LIVED — a board carrying issue
# files, a progress.md § Log with entries, an ARCHIVE.md with an index, or a config.sh
# already stamped by a previous run. Deliberately GENERIC: the class, never one repository
# named by path.
# =============================================================================
# The probes live in scripts/lib/lived-probe.sh, shared with check-board.sh arm [g]; this
# renders. GUARDED WITH `command -v`: under `set -e` an undefined function here would exit 127
# before the refusal flush below could name the missing library.
# FILLED THROUGH PROCESS SUBSTITUTION, NEVER A PIPE: a piped `while read` runs in a subshell,
# LIVED would be empty afterwards, and a lived repository would be initialized silently.
LIVED=()
if command -v kit_lived_signals >/dev/null 2>&1; then
  while IFS= read -r rec; do
    [ -n "$rec" ] || continue
    case "$rec" in
      stamp\|*)   LIVED+=("scripts/config.sh: ${rec#stamp|}") ;;
      folder\|*)  _lv="${rec#folder|}"; LIVED+=("progress/${_lv%%|*}/ carries ${_lv##*|} issue file(s)") ;;
      log\|*)     LIVED+=("progress.md § Log holds ${rec#log|} line(s) of history") ;;
      archive\|*) LIVED+=("ARCHIVE.md indexes ${rec#archive|} archived line(s)") ;;
    esac
  done < <(kit_lived_signals "$ROOT" "$STAMP_MARK" "${STATUS_FOLDERS[@]}")
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

# --- THE PRE-KIT BOUNDARY ------------------------------------------------------
# The last commit before this script wrote anything. Commits up to it predate the attribution
# rule this run wires (the commit-msg hook), so the self-check does not count their findings.
# Empty in a repository with no commits yet; every consumer handles that.
KI_BASE_SHA="$(git -C "$ROOT" rev-parse --verify --quiet HEAD 2>/dev/null || true)"

# --- the gate command / verify.sh precondition (finish-pr.sh's landing rule) ---
# Three shapes of scripts/verify.sh, and what --gate-command does with each:
#   • absent                        → WRITE a minimal single-gate runner around <C>
#   • the shipped frame, GATES=()   → FILL the table with <C> as its first record
#   • anything else (a declared table, a hand-written runner) → REFUSE; it is yours
# The fill arm exists because the seed SHIPS the frame.
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

# --- the hat this run's own commits carry must be in the set it will enforce ---
# Checked before anything is written: the commit-msg hook would reject the first commit AFTER
# the stamping. The set is the one this run leaves in force (--roles, else the hook's).
# `|| true` IS LOAD-BEARING: with the hook absent, pipefail and `set -e` would end the
# preflight before it could NAME the missing file.
PF_ROLES="${ROLES_NEW:-$( { sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p" "$ROOT/scripts/githooks/commit-msg" 2>/dev/null || true; } | head -1)}"
if [ -n "$PF_ROLES" ]; then
  case "|$PF_ROLES|" in
    *"|$SELF_ROLE|"*) : ;;
    *) pf "this script signs its own commits as [$SELF_ROLE] — the pre-role hat (process/contracts/role-gate.md § 2a's default${KIT_INIT_ROLE:+, here set by KIT_INIT_ROLE}) — and the role set '$PF_ROLES' does not contain it, so the commit-msg hook would reject them. Name the hat your project wears before any role is declared: KIT_INIT_ROLE=<one of the set> ./scripts/kit-init.sh …" ;;
  esac
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
    echo "        git -C /path/to/$(basename "$ROOT").git symbolic-ref HEAD refs/heads/${TRUNK:-<your-trunk>}   # the bare side's HEAD names the trunk"
    echo "        git remote add $REMOTE /path/to/$(basename "$ROOT").git"
    echo "    2.  git switch -c ${TRUNK:-<your-trunk>}          # if the trunk does not exist yet"
    echo "        git add -A && MSG_OK=1 git commit -m 'init'   # if there are no commits yet: commit the kit AS UNZIPPED"
    echo "    3.  git push -u $REMOTE ${TRUNK:-<your-trunk>}"
    echo "    4.  git remote set-head $REMOTE ${TRUNK:-<your-trunk>}   # ← the step whose absence is SILENT"
    echo ""
    echo "  Step 4 names the branch EXPLICITLY on purpose: 'set-head $REMOTE -a' asks the"
    echo "  remote what its own HEAD is, and a freshly created bare repo has none — it fails"
    echo "  with 'Cannot determine remote HEAD'. Step 1's symbolic-ref line writes the same"
    echo "  fact on the bare side, at creation — without it the bare repo's HEAD keeps git's"
    echo "  own default branch name, and a clone of it checks out nothing. Do both."
    echo ""
    echo "  Then re-run:  ./scripts/kit-init.sh --prefix <P> --trunk ${TRUNK:-<your-trunk>}"
  } >&2
  exit 1
fi

say "  repo:   $ROOT"
say "  prefix: $PREFIX"
say "  trunk:  $TRUNK  (confirmed against $REMOTE/HEAD → $REMOTE_HEAD)"
say "  remote: $REMOTE"
say "  commit hat: [$SELF_ROLE] (the pre-role hat — process/contracts/role-gate.md § 2a${KIT_INIT_ROLE:+; set by KIT_INIT_ROLE})"
say "  ✓ preflight clean — proceeding."

# =============================================================================
# 2. STAMP — through the existing seams only.
# =============================================================================
step "Stamping the seams"

CONFIG="$ROOT/scripts/config.sh"
COMMITMSG="$ROOT/scripts/githooks/commit-msg"
KWTLIB="$ROOT/scripts/lib/kanban-worktree.sh"

# EVERY OLD VALUE IS DERIVED FROM A SEAM, NEVER TYPED HERE: this script rewrites the
# travelling docs without carrying a donor literal, and the census below is a measurement.
OLD_PREFIX="$(sed -n 's/^ISSUE_PREFIX="\${ISSUE_PREFIX:-\([^}]*\)}"/\1/p' "$CONFIG" | head -1)"
[ -n "$OLD_PREFIX" ] || { echo "Error: could not read the current ISSUE_PREFIX default out of scripts/config.sh." >&2; exit 1; }
# It is matched below as a regex, so it keeps --prefix's shape (config.sh says so beside it).
printf '%s' "$OLD_PREFIX" | grep -qE '^[A-Za-z][A-Za-z0-9]*$' || { echo "Error: scripts/config.sh's ISSUE_PREFIX default '$OLD_PREFIX' must be alphanumeric and start with a letter. Nothing was written." >&2; exit 1; }
OLD_NAME="$(sed -n 's/^PROJECT_NAME="\${PROJECT_NAME:-\([^}]*\)}"/\1/p' "$CONFIG" | head -1)"
[ -n "$OLD_NAME" ] || { echo "Error: could not read the current PROJECT_NAME default out of scripts/config.sh." >&2; exit 1; }
# The old trunk is the LAST link of kanban-worktree.sh's own resolution chain —
# the named constant that fires when <remote>/HEAD and init.defaultBranch are both
# silent.
OLD_TRUNK="$(sed -n 's/^KWT_TRUNK_LAST_RESORT="\${KWT_TRUNK_LAST_RESORT:-\([^}]*\)}"/\1/p' "$KWTLIB" | head -1)"
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
# Their BODY prose spells the prefix out in examples. TWO forms are stamped: the
# angle-bracket placeholder (<PREFIX>-NNN) and the config default's own token. A
# substitution that matched neither would leave every minted card with a placeholder id.
TPL_HITS=0
if [ -d "$ROOT/.claude/templates" ]; then
  for t in "$ROOT"/.claude/templates/*.md; do
    [ -e "$t" ] || continue
    hit=0
    if grep -qF "${PREFIX_PLACEHOLDER}" "$t"; then
      sed -i.bak -e "s|${PREFIX_PLACEHOLDER}|${PREFIX}|g" "$t"; rm -f "$t.bak"; hit=1
    fi
    if [ "$PREFIX" != "$OLD_PREFIX" ] && grep -q "${OLD_PREFIX}-" "$t"; then
      # Three expressions, one invocation, applied in order per line: hide the marker's
      # key, rewrite the prefix, put the key back — atomic per file.
      sed -i.bak -E -e "s|${CLASS_MARKER_KEY}|${CLASS_MARKER_SENTINEL}|g" \
                    -e "s|${OLD_PREFIX}-|${PREFIX}-|g" \
                    -e "s|${CLASS_MARKER_SENTINEL}|${CLASS_MARKER_KEY}|g" "$t"; rm -f "$t.bak"; hit=1
    fi
    [ "$hit" -eq 1 ] && TPL_HITS=$((TPL_HITS+1))
  done
fi
say "  .claude/templates/: prefix (${PREFIX_PLACEHOLDER} and ${OLD_PREFIX}-) → ${PREFIX}- in ${TPL_HITS} template(s)"

# repl_esc <value> <delimiter> — <value>, literal in the replacement half of s<d>…<d>…<d>.
# A legal branch name may carry '&', '|' or '@', so the trunk is escaped, never refused.
repl_esc() { printf '%s' "$1" | sed -e "s/[\\\\&$2]/\\\\&/g"; }
TRUNK_R_PIPE="$(repl_esc "$TRUNK" '|')"
TRUNK_R_AT="$(repl_esc "$TRUNK" '@')"

# The templates carry the explicit placeholder `<trunk>`, stamped here on its own: the
# role-doc substitution below runs only when .claude/roles/ exists.
TRUNK_TPL_HITS=0
if [ -d "$ROOT/.claude/templates" ]; then
  for t in "$ROOT"/.claude/templates/*.md; do
    [ -e "$t" ] || continue
    if grep -q '<trunk>' "$t"; then
      sed -i.bak -e "s|<trunk>|${TRUNK_R_PIPE}|g" "$t"; rm -f "$t.bak"
      TRUNK_TPL_HITS=$((TRUNK_TPL_HITS+1))
    fi
  done
fi
say "  .claude/templates/: <trunk> → ${TRUNK} in ${TRUNK_TPL_HITS} template(s)"

# --- PROJECT.md: the three blanks this run already holds -------------------
# Left blank, the adopter types them again and the two copies can diverge. Every other blank
# is the adopter's.
PM="$ROOT/PROJECT.md"
if [ -f "$PM" ]; then
  PM_HITS="$( { grep -oE "<project name>|${PREFIX_PLACEHOLDER}|<trunk>" "$PM" || true; } | wc -l | tr -d ' ')"
  sed -i.bak -e "s|<project name>|${NEW_NAME}|g" \
             -e "s|${PREFIX_PLACEHOLDER}|${PREFIX}|g" \
             -e "s|<trunk>|${TRUNK_R_PIPE}|g" "$PM"; rm -f "$PM.bak"
  say "  PROJECT.md: <project name>, ${PREFIX_PLACEHOLDER}, <trunk> → ${NEW_NAME}, ${PREFIX}, ${TRUNK} (${PM_HITS} blank(s))"
fi

# --- the ROLE DOCS ---------------------------------------------------------
# Substituted here, then COUNTED (the census below). The tokens:
#   • the prefix — the angle-bracket placeholder, plus the config default's token
#     ONLY in its PLACEHOLDER shape (<TOKEN> followed by a non-digit: -NNN, -XXX).
#     <TOKEN>-<digits> is a PROVENANCE citation and is deliberately left alone:
#     rewriting it would invent a citation to an issue the adopter never had.
#     (The templates above keep their blanket rewrite — a template carries examples.)
#   • the trunk — whole word only, via a delimiter-guarded pattern run TWICE so
#     two adjacent occurrences both land. Without the guard, `development`
#     becomes `<trunk>ment`.
#   • the project name — blanket; every occurrence is the donor's.
# RECURSIVE on purpose: a parked role doc is one the adopter will one day wake.
md_files() { [ -d "$1" ] && find "$1" -type f -name '*.md' | sort || true; }
census_count() {  # <dir> <ere> [exclude-line-ere] → occurrences across the dir's .md files
  # THE THIRD ARGUMENT mirrors the substitution's marker exemption: `KIT-CLASS:` matches the
  # residue pattern `KIT-[^0-9]`, so the two must move together. The exclusion is per LINE,
  # so a placeholder sharing a line with a marker would go uncounted.
  local dir="$1" re="$2" excl="${3:-}" n=0 f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ -n "$excl" ]; then
      n=$(( n + $(grep -vE "$excl" "$f" 2>/dev/null | grep -oE "$re" 2>/dev/null | wc -l | tr -d ' ') ))
    else
      n=$(( n + $(grep -oE "$re" "$f" 2>/dev/null | wc -l | tr -d ' ') ))
    fi
  done < <(md_files "$dir")
  echo "$n"
}
PLACEHOLDER_RE="(${PREFIX_PLACEHOLDER}|${OLD_PREFIX}-[^0-9])"
# `(^|…)` IS AN ERE EXTENSION: on a `grep` stricter than the system one it matches nothing
# and the CENSUS under-reports. `sed -E` handles it, so the tree is rewritten right and only
# the printed count would be wrong. The floor stays git + a POSIX shell rather than naming a
# grep. When this file is open for another reason, replace it with a portable equivalent
# proven against a strict and a lenient matcher.
# ere_lit <value> — <value> as an ERE matching only itself, inside s|…| or s@…@. The old trunk
# and name are whatever the seams' defaults say, so they are matched literally.
ere_lit() { printf '%s' "$1" | sed -e 's/[]$.*(){}+?|[@]/[&]/g' -e 's/[\\^]/\\&/g'; }
TRUNK_LIT="$(ere_lit "$OLD_TRUNK")"
TRUNK_RE="(^|[^A-Za-z])${TRUNK_LIT}([^A-Za-z]|\$)"
NAME_RE="$(ere_lit "$OLD_NAME")"

ROLES_DIR="$ROOT/.claude/roles"
if [ -d "$ROLES_DIR" ]; then
  RD_BEFORE_P="$(census_count "$ROLES_DIR" "$PLACEHOLDER_RE" "$CLASS_MARKER_KEY")"
  RD_BEFORE_T="$(census_count "$ROLES_DIR" "$TRUNK_RE")"
  RD_BEFORE_N="$(census_count "$ROLES_DIR" "$NAME_RE")"
  for d in "$ROLES_DIR" "$ROOT/.claude/templates"; do
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      sed -i.bak -e "s|${PREFIX_PLACEHOLDER}|${PREFIX}|g" "$f"
      [ "$PREFIX" = "$OLD_PREFIX" ] || sed -i.bak -E \
          -e "s|${CLASS_MARKER_KEY}|${CLASS_MARKER_SENTINEL}|g" \
          -e "s|${OLD_PREFIX}-([^0-9])|${PREFIX}-\1|g" \
          -e "s|${CLASS_MARKER_SENTINEL}|${CLASS_MARKER_KEY}|g" "$f"
      if [ "$TRUNK" != "$OLD_TRUNK" ]; then
        sed -i.bak -E "s@(^|[^A-Za-z])${TRUNK_LIT}([^A-Za-z]|\$)@\1${TRUNK_R_AT}\2@g" "$f"
        sed -i.bak -E "s@(^|[^A-Za-z])${TRUNK_LIT}([^A-Za-z]|\$)@\1${TRUNK_R_AT}\2@g" "$f"
      fi
      [ "$NEW_NAME" = "$OLD_NAME" ] || sed -i.bak -E -e "s|${NAME_RE}|${NEW_NAME}|g" "$f"
      rm -f "$f.bak"
    done < <(md_files "$d")
  done
  say "  .claude/roles/: prefix placeholders ${RD_BEFORE_P} → $(census_count "$ROLES_DIR" "$PLACEHOLDER_RE" "$CLASS_MARKER_KEY"), trunk '${OLD_TRUNK}' ${RD_BEFORE_T} → $(census_count "$ROLES_DIR" "$TRUNK_RE"), name '${OLD_NAME}' ${RD_BEFORE_N} → $(census_count "$ROLES_DIR" "$NAME_RE")"
else
  say "  .claude/roles/: absent — nothing to substitute (copy the role docs if you want them stamped)"
fi

# --- the role set: every ENFORCING script seam at once ---------------------
# THE CANONICAL READ — byte-identical to scripts/lib/role-set.sh's kit_role_set (this script
# does not source lib/role-set.sh; the self-test holds the sites identical). FALLBACK POLICY
# HERE: fatal — an initializer that cannot read the set it is about to rewrite must not guess.
OLD_ROLES="$(sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p" "$COMMITMSG" | head -1)"
[ -n "$OLD_ROLES" ] || { echo "Error: could not read ROLE_PREFIXES out of scripts/githooks/commit-msg." >&2; exit 1; }
if [ -n "$ROLES_NEW" ]; then
  # NOTE the '@' delimiter: the role set is a '|'-separated ERE alternation, so
  # the usual s|…|…| would be cut in half by its own data.
  # EVERY SEAM THAT ENFORCES THE SET, DERIVED rather than listed: a seam left unstamped
  # refuses the project's own roles.
  # NON-RECURSIVE, AND THAT IS THE WHOLE SAFETY OF IT: a recursive sweep reaches the self-test
  # under scripts/test/, which asserts what the kit SHIPS, and would rewrite its assertions to
  # match what they measure. The glob excludes it by shape.
  # Substring safety rests on the already-lived refusal (OLD_ROLES is the shipped alternation,
  # not one short token); the glob bounds the blast radius. Keep it.
  STAMPED_SEAMS="$( { grep -lF -- "$OLD_ROLES" "$ROOT"/scripts/*.sh "$ROOT"/scripts/githooks/* 2>/dev/null || true; } )"
  # ASSERTED, NOT ASSUMED: an empty derivation means the tree moved under this run, and
  # stamping nothing while reporting success is the failure to avoid.
  [ -n "$STAMPED_SEAMS" ] || {
    echo "Error: no shipped script carries the role set that was just read out of scripts/githooks/commit-msg — refusing to report a stamping that did not happen." >&2; exit 1; }
  STAMPED_REL=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    sed -i.bak -e "s@${OLD_ROLES}@${ROLES_NEW}@g" "$f"; rm -f "$f.bak"
    STAMPED_REL="${STAMPED_REL}${STAMPED_REL:+ }${f#"$ROOT"/}"
  done <<STAMP_EOF
$STAMPED_SEAMS
STAMP_EOF
  # Nothing rewrites the hook's help text: it derives the list from ROLE_PREFIXES at print time.
  ROLES="$ROLES_NEW"
  # The receipt names what was actually stamped.
  say "  role set → '${ROLES}' in ${STAMPED_REL}"
else
  ROLES="$OLD_ROLES"
  say "  role set left as copied: '${ROLES}' (change it with --roles)"
fi
# This script's own commits use SELF_ROLE (the pre-role hat), not a member picked from ROLES.

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
#
# EXIT STATUS — the frame's, never the gate's own: 0 green; 1 the gate FAILED; 3 the
# gate COULD NOT RUN (its command was not found or not executable: 127 or 126). The
# gate's own code is kept in the printed line. Callers read these values — the
# landing script names a 3 "COULD NOT RUN" — so a gate that fails with its own 2 or 3
# must not reach them as the runner's.
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

# The gate's code, mapped onto the frame's: 126/127 is a gate that never ran (an
# UNKNOWN, not a failure); any other non-zero is a failure, whatever number it used.
P=0; F=0; U=0
if [ "\$GATE_RC" -eq 0 ]; then
  LINE="PASS  ${GATE_CMD}"; P=1; STATUS=0
elif [ "\$GATE_RC" -eq 126 ] || [ "\$GATE_RC" -eq 127 ]; then
  LINE="UNRUNNABLE  ${GATE_CMD} (rc=\$GATE_RC — the command never executed; NOTHING was measured)"; U=1; STATUS=3
else
  LINE="FAIL  ${GATE_CMD} (rc=\$GATE_RC)"; F=1; STATUS=1
fi

# The frame's summary block, in the frame's shape: marker, the gate's line, the counts.
echo ""
echo "═══ verify.sh summary ═══"
echo "\$LINE"
echo "───"
echo "gates declared: 1 · ran: \$(( P + F )) · passed: \$P · failed: \$F · could not run: \$U · skipped: 0"
if [ "\$U" -gt 0 ]; then echo "NOTE: 1 gate(s) could NOT RUN — that is an UNKNOWN, not a measured failure."; fi
exit "\$STATUS"
EOF
  chmod +x "$ROOT/scripts/verify.sh"
  # The generated runner speaks the FRAME's statuses, not its gate's; the self-test drives
  # this heredoc through kit-init and holds its count line to the frame's shape.
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
  # .gitkeep, because git does not track an empty directory: a fresh CLONE would have no
  # board, and move-issue.sh ABORTS on a missing target folder.
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

Run \`ls progress/todo/ progress/in_progress/ progress/dev_complete/ progress/qa_complete/ progress/blocked/ progress/declined/\`
to see the board. \`declined/\` is terminal — a card considered and refused, kept for the reason it carries. Each filename is \`${PREFIX}-NNN-<slug>.md\`; the folder is the status.
\`./scripts/check-board.sh\` reports board drift. Older entries rotate into
\`progress/history/\` via \`./scripts/archive-progress.sh\`.

## How to write an entry

Two shapes below are REQUIRED, not stylistic — a script reads each one:

- the \`## Log\` heading itself: check-board.sh probes for it
  (\`grep -qE '^##[[:space:]]+Log'\`) before it can report this section's size;
- a dated \`###\` boundary per session: archive-progress.sh splits this file on
  \`### YYYY-MM-DD\` when it rotates, so each session's entries sit under ONE
  heading. **\`###\`, not \`##\`, and that is load-bearing rather than stylistic.**
  Two tools read the \`## Log\` *section* by scanning from its heading to the next
  \`##\`: check-board.sh's § Log size arm and this initializer's already-lived
  probe. An entry written as \`## YYYY-MM-DD\` therefore *terminates the section it
  is supposed to be inside* — the size arm measures only the preamble and reports
  healthy forever, and the lived probe counts zero log lines, so a repository with a
  full history reads as new.

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
# `.claude/session-role` is SESSION STATE, never repository content (role-gate.md § 2):
# tracked, it forks per branch and reaches a landing as a merge conflict.
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
# THE MODE BIT IS REPAIRED HERE, before § 5's commit, so it reaches the trunk and every clone
# (setup.sh repairs only its own checkout). A hand copy can drop it, and git then IGNORES a
# non-executable hook and the commit succeeds.
chmod +x "$ROOT"/scripts/githooks/* 2>/dev/null || true
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
for p in "${KIT_COMMIT_PATHS[@]}"; do
  [ -e "$ROOT/$p" ] && ADD_PATHS+=("$p")
done
git -C "$ROOT" add -A -- "${ADD_PATHS[@]}"
if git -C "$ROOT" diff --cached --quiet; then
  say "  nothing to commit (tree already matches)"
else
  git -C "$ROOT" diff --cached --name-only | sed 's/^/    /'
  git -C "$ROOT" commit -q -m "[$SELF_ROLE] kit-init: initialize the kit — prefix $PREFIX, trunk $TRUNK"
  # THROUGH THE RETRY HELPER, here and at the self-check pushes below: a bare push that loses
  # a race leaves the commit local. Its rebase-on-rejection is safe because the preflight
  # guarantees this checkout is ON the trunk.
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
# The four things that must work on day one or the board is fiction — a card can be MINTED
# with the right identity, MOVED between columns, the board REPORTS clean, and the commit-msg
# hook FIRES — plus two invariants: a hat declaration is session state, and the census.
# Out of day-one scope: the finish-pr merge cases and the archive sweep; scripts/test/run.sh
# covers those in a throwaway sandbox.
# =============================================================================
step "Self-check — prefix $PREFIX, trunk $TRUNK, role [$SELF_ROLE]"

SC_FAIL=0
sc_ok()   { printf '  ✓ %s\n' "$1"; }
sc_bad()  { printf '  ✗ %s\n' "$1" >&2; SC_FAIL=$((SC_FAIL+1)); }

SCRATCH_ID="${PREFIX}-${SCRATCH_NUM}"
SCRATCH_FILE="${SCRATCH_ID}-${SCRATCH_SLUG}.md"

# --- (1) mint a scratch card through the real creation path -----------------
# The output is captured and REPLAYED on failure, like (2)'s: a refusal that hides its cause
# trains the reader to re-run.
MINT_OUT="$("$ROOT/scripts/new-issue.sh" "$SCRATCH_SLUG" --id "$SCRATCH_ID" 2>&1)" && MINT_RC=0 || MINT_RC=$?
if [ "$MINT_RC" -eq 0 ] && [ -f "$ROOT/progress/todo/$SCRATCH_FILE" ]; then
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
  sc_bad "could not mint $SCRATCH_ID via scripts/new-issue.sh (exit $MINT_RC):"
  if [ -n "$MINT_OUT" ]; then
    printf '%s\n' "$MINT_OUT" | sed 's/^/      /' >&2
  else
    printf '      (the command printed nothing; the card simply did not appear at progress/todo/%s)\n' "$SCRATCH_FILE" >&2
  fi
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
# THE VERDICT LINE DECIDES. Nothing else does: re-scanning the rendered ⚠ lines would make this
# a second parser of a human-readable format, and advisory lines would fail installs.
# (scripts/release.sh gate (d) keys on the verdict line the same way.)
if printf '%s' "$BOARD_OUT" | grep -q 'board-drift: clean'; then
  sc_ok "check-board.sh: clean"
else
  # The verdict is not clean. EXACTLY ONE cause is tolerable: a commit that predates this
  # run predates the attribution rule this run installs.
  # NOT REDUNDANT WITH check-board.sh ARM (e)'s scoping. Arm (e) asks "was the rule in force
  # when this commit was made" (after the hook FILE arrived); this asks "did THIS RUN cause
  # the finding" (after KI_BASE_SHA). The boundaries differ on purpose; keep both.
  #
  # Advisory sections are dropped by their OWN DECLARATION: an arm that reports without
  # deciding says "reports only" in its header line, and everything under it is skipped until
  # the next "[x]" section. "reports only" IS A MACHINE CONTRACT: specified in
  # process/contracts/drift-report.md § 4, produced by check-board.sh's advisory headers,
  # consumed here. Change it in all three.
  # THE HEADER LINE IS NOT SKIPPED unless the arm declared itself advisory: arms [b] and [c]
  # print their finding ON the header line.
  KI_FINDINGS="$(printf '%s\n' "$BOARD_OUT" | awk '
      /^\[[a-z]\]/ { adv = (index($0, "reports only") > 0) }
      adv          { next }
                   { print }
    ' | grep '⚠' | grep -v '^──' || true)"

  KI_PREKIT=""; KI_REAL=""
  while IFS= read -r ki_line; do
    [ -n "$ki_line" ] || continue
    case "$ki_line" in
      *"lacks a [Role] prefix"*|*"carries a generated trailer"*)
        # BOTH HISTORY ARMS: arm [h] (a tool trailer) shares arm (e)'s rule epoch, the hook
        # FILE's arrival, so a trailer committed before THIS RUN wired core.hooksPath gets
        # the same tolerance and the same boundary as a missing prefix.
        ki_sha="$(printf '%s' "$ki_line" | sed -n 's/.*⚠[[:space:]]*\([0-9a-f]\{7,\}\)[[:space:]].*/\1/p')"
        if [ -n "$ki_sha" ] && [ -n "$KI_BASE_SHA" ] \
           && git -C "$ROOT" merge-base --is-ancestor "$ki_sha" "$KI_BASE_SHA" >/dev/null 2>&1; then
          KI_PREKIT="${KI_PREKIT}${ki_line}
"
        else
          KI_REAL="${KI_REAL}${ki_line}
"
        fi ;;
      *) KI_REAL="${KI_REAL}${ki_line}
" ;;
    esac
  done <<KI_EOF
$KI_FINDINGS
KI_EOF

  if [ -z "$KI_REAL" ] && [ -n "$KI_PREKIT" ]; then
    sc_ok "check-board.sh: the only findings are commits predating this run, which the attribution rules did not yet bind"
  elif [ -z "$KI_REAL" ]; then
    # The verdict is dirty and nothing this script can attribute explains it: say exactly
    # that. STATED LIMIT: an arm that sets the verdict while printing NO ⚠ line is invisible here.
    sc_ok "check-board.sh: no finding this run can attribute to itself (the report's verdict is not clean; its lines are below)"
  else
    sc_bad "check-board.sh reported drift:"
    printf '%s\n' "$KI_REAL" | sed '/^$/d' >&2
  fi

  # CONTEXT, AFTER THE DECISION AND NEVER PART OF IT. Printed so the operator sees the
  # whole report, and separated so nobody mistakes it for the reason.
  KI_CONTEXT="$(printf '%s\n' "$BOARD_OUT" | grep '⚠' | grep -v '^──' || true)"
  if [ -n "$KI_CONTEXT" ]; then
    echo "    (the full report's advisory and informational lines, for context — not the basis of the result above:)" >&2
    printf '%s\n' "$KI_CONTEXT" | sed 's/^/      /' >&2
  fi
fi

# --- (4) the commit-msg hook FIRES (this is the core.hooksPath proof) -------
# git's own stderr is the diagnosis: a non-executable hook is IGNORED ("not set as
# executable") and the commit succeeds — a mode problem, not a core.hooksPath one.
# `|| _ki_hook_rc=$?`, NOT `; _ki_hook_rc=$?`: under `set -e` the rejection (rc=1, the
# healthy outcome) would kill the run at the assignment.
_ki_hook_rc=0
_ki_hook_out="$(git -C "$ROOT" commit --allow-empty -q -m "kit-init self-check: this subject has no role tag" 2>&1)" || _ki_hook_rc=$?
if [ "$_ki_hook_rc" -eq 0 ]; then
  case "$_ki_hook_out" in
    *"not set as executable"*|*"hook was ignored"*)
      sc_bad "the commit-msg hook was IGNORED because it is not executable — core.hooksPath IS set; the file's mode is the problem. Fix: chmod +x scripts/githooks/*" ;;
    *)
      sc_bad "the commit-msg hook did NOT reject a prefix-less subject — core.hooksPath is not in effect" ;;
  esac
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
if git -C "$ROOT" status --porcelain | grep 'session-role' >/dev/null; then
  sc_bad "a hat declaration shows up in git status — .claude/session-role is not ignored (role-gate.md § 2)"
else
  sc_ok "a hat declaration is invisible to git status — session state, not repository content"
fi
[ "$SR_PRE_EXISTING" = true ] || rm -f "$SR_FILE"

# --- (6) THE CENSUS — asserted rather than promised --------------------------
# process/contracts/config-seam.md: the donor's values in the travelling files are COUNTED,
# by the adopter. A token whose new value EQUALS the shipped one is skipped: counting it
# would fail the adopter for agreeing with the kit.
CENSUS_TOTAL=0
census_report() {  # <label> <ere> <changed?> [exclude-line-ere]
  local label="$1" re="$2" changed="$3" excl="${4:-}" n=0 d
  if [ "$changed" != "true" ]; then
    sc_ok "census — ${label}: not counted (your value is the shipped one)"
    return
  fi
  for d in "$ROOT/.claude/roles" "$ROOT/.claude/templates"; do
    n=$(( n + $(census_count "$d" "$re" "$excl") ))
  done
  CENSUS_TOTAL=$(( CENSUS_TOTAL + n ))
  if [ "$n" -eq 0 ]; then sc_ok "census — ${label}: 0 in .claude/roles + .claude/templates"
  else sc_bad "census — ${label}: ${n} occurrence(s) survive in .claude/roles + .claude/templates"; fi
}
# NO COLON IN THIS LABEL: the harness asserts on `census — prefix placeholders[^:]*: 0 in`.
# `${CLASS_MARKER_KEY%:}` keeps the name derived and drops the key's colon.
census_report "prefix placeholders (${PREFIX_PLACEHOLDER} / ${OLD_PREFIX}-, excluding the ${CLASS_MARKER_KEY%:} key)" "$PLACEHOLDER_RE" "true" "$CLASS_MARKER_KEY"
census_report "trunk '${OLD_TRUNK}'"       "$TRUNK_RE" "$( [ "$TRUNK" != "$OLD_TRUNK" ] && echo true || echo false )"
census_report "project name '${OLD_NAME}'" "$NAME_RE"  "$( [ "$NEW_NAME" != "$OLD_NAME" ] && echo true || echo false )"

# THE MARKER SURVIVED — asserted in two directions (contracts/initializer.md § 2): the key is
# still PRESENT and the defaced spelling ABSENT; either alone passes on deleted markers.
MK_OK=0; MK_BAD=0
for d in "$ROOT/.claude/roles" "$ROOT/.claude/templates"; do
  # `|| true` INSIDE the substitution is load-bearing: a no-match grep under pipefail would
  # abort `set -e` on a healthy tree.
  MK_OK=$((  MK_OK  + $( { grep -rl "$CLASS_MARKER_KEY" "$d" 2>/dev/null || true; } | wc -l | tr -d ' ') ))
  MK_BAD=$(( MK_BAD + $( { grep -rl "${PREFIX}-CLASS:" "$d" 2>/dev/null || true; } | wc -l | tr -d ' ') ))
done
if [ "$MK_BAD" -gt 0 ]; then
  sc_bad "classification markers: ${MK_BAD} file(s) now read '${PREFIX}-CLASS:' — the stamper rewrote the convention's KEY, not a value"
elif [ "$MK_OK" -eq 0 ]; then
  sc_bad "classification markers: NONE found carrying '${CLASS_MARKER_KEY}' in .claude/roles + .claude/templates — expected the shipped markers to be intact"
else
  sc_ok "classification markers intact — ${MK_OK} file(s) carry '${CLASS_MARKER_KEY}', 0 read '${PREFIX}-CLASS:'"
fi
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
  # The FIRST id is printed as a literal: on this empty board next-id.sh correctly refuses
  # (process/contracts/id-minting.md: where numbering starts is a decision). next-id.sh takes
  # over from the second mint.
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
