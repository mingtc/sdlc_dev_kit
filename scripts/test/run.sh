#!/usr/bin/env bash
# KIT-CLASS: MIXED — self-test harness for the kanban scripts. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/run.sh — the kit's self-test harness for the board scripts.
#
# HOW TO RUN
#   ./scripts/test/run.sh          # run every case; exit 0 iff none FAILed
#
# It exits 0 when all cases PASS (or SKIP), and NONZERO when any case FAILs,
# printing a per-case PASS / FAIL / SKIP summary at the end.
#
# WHAT IT IS — and IS NOT
#   • Pure bash + git, PLUS `perl` — and the third one is the point of this line. `perl`
#     rewrites sandbox fixtures at 24 command-position sites and is PROBED AT STARTUP: its
#     absence is a hard refusal with the reason, not an unexplained abort forty cases in.
#     `node` and `python3` are OPTIONAL — cases needing them SKIP loudly. This header used to
#     read "no language runtime, no package manager, no new dependency", which was false of
#     perl and true of nothing else, and nothing probed it. THE KIT's own floor is unchanged:
#     git and a POSIX shell. This dependency is the HARNESS's, and it is declared here.
#     It tests the SCRIPTS, not the project.
#   • It is DELIBERATELY NOT wired into scripts/verify.sh — it is an ON-DEMAND
#     developer/QA tool for proving a change to the board scripts is correct
#     without risking the real board or the real remote. RUN IT BY HAND AFTER
#     TOUCHING ANY SCRIPT IT COVERS — including the hooks, the githooks and lib/.
#     No list of those scripts lives here on purpose: this line used to name a
#     handful and had fallen behind the case families the harness had grown, so an
#     operator changing one of the unnamed ones was told nothing. The covering set
#     is the CASES list below and the sandbox copies each case makes; read those,
#     which cannot go stale against the harness because they ARE the harness.
#
# ISOLATION (the whole point)
#   Every case builds a THROWAWAY sandbox in a fresh `mktemp -d`: a work repo
#   (`git init`) whose remote is a local BARE repo (`git init --bare`), seeds a
#   minimal progress/** board + ARCHIVE.md, and COPIES the scripts-under-test
#   into the sandbox so they resolve the SANDBOX as their repo root — never this
#   real repo, never the real `.kanban-wt/`, never the real remote. The sandbox
#   is torn down after each case. A failing case cannot mutate the real repo, and
#   case_isolation proves that rather than asserting it.
#
# NOTHING HERE HARD-CODES A PREFIX OR A TRUNK NAME
#   Both are DERIVED from the seams (scripts/config.sh's ISSUE_PREFIX,
#   kanban-worktree.sh's KWT_TRUNK_LAST_RESORT, this repo's own <remote>/HEAD), so
#   a project that changed either still gets a green harness. A harness that
#   asserts one project's literals is a harness that reddens on adoption and
#   teaches the adopter to ignore it.
#
# PROJECT-SPECIFIC FAMILIES ARE PROBED, NEVER ASSUMED
#   Two families exist only if this project has the surface they test:
#     • the CONSUMER-UPDATER family runs only when CONSUMER_SCRIPT (below) names
#       an executable — a vendoring/updater script is a DISTRIBUTION MODEL, not a
#       kit feature (see process/doctrine/distribution.md);
#     • the RELEASE family runs against release.sh's declared SEAMS
#       (VERSION_FILES / RELEASE_DOCS / the publish config), which the harness
#       fills in inside the sandbox. It never asserts one project's version files.
#   Anything absent SKIPs loudly. A SKIP is a statement about the environment; it
#   is never used to hide a missing behaviour (see the notes on the two cases that
#   deliberately have NO capability probe).
#
# WHERE THIS HARNESS IS A WITNESS, AND WHERE IT IS NOT. It is a witness when run from
# a BUILT KIT — an unzipped tree given day-one git topology. It is NOT a witness run
# in place inside the repository that maintains the kit, and that is a property of
# that repository's storage rather than a defect in anything here: the kit is kept
# there DISARMED, under `_claude/` rather than `.claude/`, so a harness auto-loader
# does not pick up the kit's own skills and roles as the maintainer's.
#
# WHAT IN-PLACE RUNNING ACTUALLY COSTS, measured rather than described: the day-one
# cases SKIP on a `.claude/` path that is present two directories over under the other
# spelling, and at least one case has reported a FALSE RED with no defect behind it.
# Both are the same cause. So an in-place run's output is not admissible as evidence
# about the kit, and no number taken from one belongs in a change file.
#
# THE SITES THAT TOLERATE BOTH SPELLINGS DO NOT MAKE IN-PLACE RUNNING SUPPORTED. Those
# that do read whichever of `_claude/` or `.claude/` exists, so that they still read the
# real shipped tree when someone runs them in place; each says so at its own site, and one
# of them is a shared helper rather than a case. That is a convenience for those sites, not
# a mode this file offers, and it must not be widened into one — running in place should be
# honestly unsupported rather than quietly made to work, which is a larger decision than
# any of those sites took.
#
# NO COUNT HERE, DELIBERATELY, AND DO NOT RE-ADD ONE. This sentence read "Four" and was
# wrong every time anyone looked: five when the defect was raised (2026-08-31), SIX the
# next day, and five again after one site was folded into the helper above — three values
# across two changes in two days, and the number was re-derived by none of them.
# `process/doctrine/staleness.md` § C is the rule (derive, date, or do not state) and its
# own note about enumerations is why this is phrased as a property rather than a total.
#
# The instrument whose output IS the list, if a reader wants it. NOTE THE COMMENT SKIP,
# and it is not tidiness: without it this recipe matches the line you are reading and
# reports itself as a site — a probe inside its own operand set, which is the defect it
# exists to measure. RUN THE RECIPE RATHER THAN TRUSTING A DIGIT HERE — this line said "six hits
# and five", then "nine and eight", and both were wrong. RUN THE RECIPE — it is four lines below.
# A digit here is a census in prose about a file that changes every time a case is added, stated
# four lines under the header paragraph warning about exactly that.
#
#   awk '!/^[[:space:]]*#/ && /_claude/ && /REAL_REPO_ROOT/ {print FNR": "fn}
#        /^[A-Za-z_][A-Za-z0-9_]*\(\)/{fn=$1}' scripts/test/run.sh
#
# THE PIPEFAIL RULE, and it has already cost this harness one FALSE RED: under
# `set -o pipefail`, a pipeline ending in a reader that exits before its input is
# drained — `head`, `grep -q`, `grep -m`, `sed …q`, `read` are the family — returns
# the PRODUCER's death, not the reader's answer. The early exit closes the pipe, the
# producer still writing behind it takes SIGPIPE and dies 141, and `pipefail`
# promotes that to the status of the whole pipeline. Here that inverts an assertion:
# `origin_log_has_subject` returned "not found" for a subject that WAS present, and
# it did so *because* the match was early. Measured on its own pipeline: 0/1 failures
# on a 1-commit trunk, 58/60 at ten commits, 60/60 at twenty-five — so it is not a
# flake, it is a threshold nobody had crossed while the sandboxes stayed small.
#
# THE SIZE THAT MATTERS IS THE PRODUCER'S OUTPUT, NOT ITS KIND. A builtin is not
# safe by being a builtin: `printf '%s\n' "$big" | grep -q` on a match in the first
# line dies 141 too, once "$big" exceeds the pipe buffer. What makes the many
# `printf "$out" | grep -q` pipelines below sound is that `$out` is one command's
# captured output, orders below that buffer — and that is the exemption, stated so
# the next reader can check it rather than assume it.
#
# So: a pipeline whose producer can GROW WITH THE PROJECT — `git log`, `find`,
# `grep -r` over the corpus — must capture the stream and test the capture, never
# pipe it into an early-exiting reader.
# =============================================================================
set -uo pipefail

# A USAGE REQUEST IS ALWAYS LEGAL AND ALWAYS SUCCEEDS — process/contracts/issue-creation.md § 3,
# which this harness enforces on other scripts and did not answer itself. Before this, `--help`
# was not read at all: it fell through and STARTED THE FULL SUITE, building sandboxes and bare
# repositories for several minutes, which is the most expensive possible answer to "what is this?".
case "${1:-}" in
  -h|--help)
    # DERIVED, NOT A LITERAL. The first version of this arm used `3,34p` and this header runs to
    # line 118, so --help ended mid-sentence with an unclosed rule. Every other header-derived
    # --help in the kit derives its end; this arm was written in the same session that removed the
    # last literal from the others and reintroduced one immediately.
    _rs_end="$(awk 'NR>2 && !/^#/{print NR-1; exit}' "${BASH_SOURCE[0]:-$0}")"
    sed -n "3,${_rs_end:-34}p" "${BASH_SOURCE[0]:-$0}" | sed 's|^# \{0,1\}||'
    exit 0 ;;
  '') : ;;
  *) echo "run.sh: unknown option '$1' — this harness takes none; run it with no arguments." >&2
     echo "        Run  run.sh --help  for what it does." >&2
     exit 2 ;;
esac

# PROBED, NOT ASSUMED. perl is a hard dependency of this harness (fixture mutation) and it is
# past the kit's declared git-plus-POSIX floor, so it is refused at startup with the reason —
# not discovered as an unexplained abort forty cases in. node and python3 are OPTIONAL and their
# cases skip; this one cannot skip, because almost every sandbox is built with it.
command -v perl >/dev/null 2>&1 || {
  echo "run.sh: perl is required by this harness and is not on PATH." >&2
  echo "        It rewrites sandbox fixtures; there is no skip path, because nearly every case" >&2
  echo "        builds its sandbox with it. The KIT itself needs only git and a POSIX shell —" >&2
  echo "        this dependency is the TEST HARNESS's, and it is stated in the header above." >&2
  exit 1
}

REAL_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REAL_SCRIPTS="$REAL_REPO_ROOT/scripts"

# ── THE NEUTRAL CONFIG — the kit's SHIPPED value for every seam the sandbox
#    copies in. Declared here, once, greppably, and DERIVED FROM NOTHING IN THE
#    ADOPTER'S TREE on purpose: that is the whole point. _kit_neutral_config()
#    below resets the sandbox to these, so a case asserts THE KIT'S FRAME rather
#    than whatever this repository happens to be configured to.
#
#    The measured defect these exist to close: make_sandbox `cp -R`s the real
#    scripts/ in, CONFIG BLOCKS and all, so a configured adopter's sandbox
#    inherited their gate table, their release seams and their prefix — and a
#    third of the cases then asserted the adopter's configuration while reporting
#    PASS. A harness that cannot run on a configured repository is not a witness.
#
#    THESE MUST EQUAL WHAT THE KIT SHIPS. Neutralizing costs the harness its only
#    incidental witness to the shipped defaults, so case_ship_state() below asserts
#    the real files still carry them. If that case reddens, correct the SHIPPED
#    file or this constant — never only this constant, or the harness starts
#    certifying its own assumption.
KIT_NEUTRAL_PREFIX="KIT"
KIT_NEUTRAL_PRD_PREFIX="PRD"
KIT_NEUTRAL_PROJECT_NAME="<project-name>"

# THE ROLE SET THE KIT SHIPS. DECLARED, not derived — and the asymmetry with
# KIT_STAMP_MARK / KIT_PREFIX_PLACEHOLDER (defined BELOW, not above — this said "above" while
# both were three hundred lines further down) is forced rather than chosen: those two
# have an unstamped source to read (kit-init.sh's own constants, which no stamp rewrites).
# THIS ONE HAS NONE. kit-init's --roles performs a GLOBAL substitution of the old
# alternation across githooks/commit-msg, move-issue.sh and check-board.sh, so on an
# adopted tree every occurrence already reads that project's set — including
# check-board.sh's own fallback copy. There is nowhere left to derive the shipped value
# from, so the harness must carry it, and case_ship_state is what keeps it honest.
KIT_NEUTRAL_ROLE_PREFIXES='PM|Dev|QA|Refactorer|UIDesigner|Orchestrator|Architect'

# ── The seam values this harness runs against, all DERIVED. ──────────────────
# ISSUE_PREFIX is NOT derived from the adopter's config.sh any more. It used to be,
# and that was the same defect one level up: the neutralizer resets the SANDBOX's
# prefix to KIT_NEUTRAL_PREFIX, so a harness that kept reading the adopter's value
# here would seed `<their-prefix>-100` cards into a sandbox whose scripts resolve
# `KIT` — next-id.sh, validate_issue_id and archive.sh would all disagree with the
# fixture, and only in an adopter's tree, never here. The two values must be ONE
# value, and the neutral one is the one that belongs to the kit.
SB_PREFIX="$KIT_NEUTRAL_PREFIX"
SB_TRUNK="$(git -C "$REAL_REPO_ROOT" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || true)"
if [ -z "$SB_TRUNK" ]; then
  SB_TRUNK="$(sed -n 's/^KWT_TRUNK_LAST_RESORT="\${KWT_TRUNK_LAST_RESORT:-\([^}]*\)}"/\1/p' \
                "$REAL_SCRIPTS/lib/kanban-worktree.sh" 2>/dev/null | head -1)"
fi
# NO SECOND DEFAULT HERE. `config-seam.md` § 2 forbids a degraded path carrying its own
# fallback, and this was one: if the declaration's SHAPE ever moved, the sed above matched
# nothing, this line quietly supplied "main", and the whole suite ran against a trunk name
# it had not read from anywhere. That is a green built on a value nobody declared. Die
# instead — a harness that cannot read the kit's own trunk default has nothing to test.
if [ -z "$SB_TRUNK" ]; then
  echo "FIXTURE: could not read the trunk from origin/HEAD, and the KWT_TRUNK_LAST_RESORT" >&2
  echo "         declaration in scripts/lib/kanban-worktree.sh did not parse either." >&2
  echo "         The declaration shape is contracted (process/contracts/config-seam.md § 2)." >&2
  echo "         Refusing to invent a trunk name: every sandbox below would be built on it." >&2
  exit 1
fi
# The first role of the set the SANDBOX runs, which is the kit's shipped set because
# _neu_roles resets it there. This used to read the adopter's commit-msg, and the comment
# said "derived, so the harness never asserts a role name this project may not have" —
# correct while the sandbox inherited the project's set, and wrong once it stops. The
# hazard it guarded against is now closed at the source instead: the sandbox's vocabulary
# is the kit's, so every role literal in this file is a name the sandbox certainly has.
SB_ROLE="${KIT_NEUTRAL_ROLE_PREFIXES%%|*}"

# ── The CONSUMER_SCRIPT seam. Point it at this project's vendoring/updater script
#    to activate the consumer-updater family; leave it empty and that family SKIPs.
CONSUMER_SCRIPT="${CONSUMER_SCRIPT:-}"

# --- Result accounting -------------------------------------------------------
PASS=0; FAIL=0; SKIP=0
declare -a RESULTS
ok()   { PASS=$((PASS+1)); RESULTS+=("PASS  $1"); printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); RESULTS+=("FAIL  $1${2:+ — $2}"); printf '  \033[31mFAIL\033[0m  %s%s\n' "$1" "${2:+ — $2}"; }
skp()  { SKIP=$((SKIP+1)); RESULTS+=("SKIP  $1${2:+ — $2}"); printf '  \033[33mSKIP\033[0m  %s%s\n' "$1" "${2:+ — $2}"; }

# Per-case failure accumulator. A case notes each unmet check, then finalizes
# with ok/bad based on whether anything was noted.
_cf=""
cf() { _cf="${_cf}${_cf:+; }$1"; }
cf_reset() { _cf=""; }
finish() { if [ -z "$_cf" ]; then ok "$1"; else bad "$1" "$_cf"; fi; }

# --- Sandbox construction ----------------------------------------------------
# Sets globals: SB_TMP (temp root), SB_WORK (work repo), SB_ORIGIN (bare remote).
SB_TMP=""; SB_WORK=""; SB_ORIGIN=""
teardown() { [ -n "$SB_TMP" ] && rm -rf "$SB_TMP" 2>/dev/null; SB_TMP=""; }
trap teardown EXIT

# Commit in the work repo BYPASSING the role-prefix hook (setup commits are
# infrastructure, not role work). Board-script commits still go through the hook
# naturally and carry [Role] prefixes.
sbcommit() { MSG_OK=1 git -C "$SB_WORK" commit "$@"; }

# seed_issue <folder> <id> <slug> <type> <title> [branch]
# THIS FIXTURE'S FRONTMATTER MUST MATCH THE SHIPPED TEMPLATES' KEY SET, and `pr:` is the
# one that went wrong: the harness seeded `pr: null` while NO template carried the key,
# so the harness was testing a shape the templates never produce — and `--set-pr`, which
# writes back only into an EXISTING `pr:` line, could never work on a kit-minted card
# while passing here. The templates now declare it, so this line is a
# projection of them rather than an invention. The assertion that keeps the two in step
# was OWED when this was written and IS NOW PAID: a case mints a card from the REAL
# template and checks that `--set-pr` persists into it. The reason stands and is worth
# keeping — a fixture written by hand to match cannot be evidence that the templates
# produce it, which is why the paying case reads the shipped template rather than this
# seed. What changed is only the conclusion: the template fix is no longer unproven.
seed_issue() {
  local folder="$1" id="$2" slug="$3" type="$4" title="$5" branch="${6:-n/a}"
  local f="$SB_WORK/progress/$folder/${id}-${slug}.md"
  cat > "$f" <<EOF
---
id: ${id}
type: ${type}
title: ${title}
branch: ${branch}
pr: null
created_at: 2026-01-01
created_by: PM
---

# ${id} — ${title}

## Activity

- 2026-01-01 [PM] Seeded for the sandbox self-test.
EOF
}

# make_sandbox [work_subdir]
# The optional arg names the work-repo subdirectory under the temp root (default
# "work"). Pass a name CONTAINING A SPACE (e.g. "work dir") to reproduce a repo
# path with a space — an unquoted command expansion word-splits on it, which is a
# real defect class this harness carries a dedicated case for.
make_sandbox() {
  SB_TMP="$(mktemp -d)"
  SB_ORIGIN="$SB_TMP/origin.git"
  SB_WORK="$SB_TMP/${1:-work}"

  git init --bare "$SB_ORIGIN" >/dev/null 2>&1
  git -C "$SB_ORIGIN" symbolic-ref HEAD "refs/heads/$SB_TRUNK" >/dev/null 2>&1

  git init "$SB_WORK" >/dev/null 2>&1
  git -C "$SB_WORK" symbolic-ref HEAD "refs/heads/$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" config user.email "test@sandbox.invalid" >/dev/null 2>&1
  git -C "$SB_WORK" config user.name  "Sandbox Test"         >/dev/null 2>&1
  git -C "$SB_WORK" config init.defaultBranch "$SB_TRUNK"    >/dev/null 2>&1
  git -C "$SB_WORK" config commit.gpgsign false              >/dev/null 2>&1

  # Copy the scripts-under-test in (never symlink — the sandbox must own them so
  # they resolve the sandbox as their root). Drop this test dir to avoid recursion.
  cp -R "$REAL_SCRIPTS" "$SB_WORK/scripts"
  rm -rf "$SB_WORK/scripts/test"
  # ...and reset every CONFIG-BLOCK seam that `cp` just carried in. The copy above
  # is what brings the adopter's configuration into the sandbox; this is the line
  # that takes it back out. See _kit_neutral_config below.
  #
  # PLACEMENT IS LOAD-BEARING, DO NOT TIDY THIS TO THE END OF THE FUNCTION. It must
  # run BEFORE _declare_sandbox_gate, because that call is what puts the sandbox's
  # own always-green gate into the freshly-emptied GATES table — and
  # case_kit_init_gate_and_remote_refusals(a) needs a DECLARED table to provoke
  # kit-init's "already DECLARES a gate" refusal. Neutralize last and that case
  # loses its premise while still reporting PASS.
  _kit_neutral_config

  mkdir -p "$SB_WORK/progress/todo" "$SB_WORK/progress/in_progress" \
           "$SB_WORK/progress/dev_complete" "$SB_WORK/progress/qa_complete" \
           "$SB_WORK/progress/blocked" "$SB_WORK/progress/done" \
           "$SB_WORK/progress/history"
  # THIS LITERAL LIST STAYS, and the reason is a boundary rather than an exception —
  # written here because the next reader sweeping for enumerations will meet it.
  #
  # A LITERAL IN A BUILDER IS NOT THE RISK A LITERAL IN A GUARD IS. If a builder's list
  # diverges from the kit's, the fixture is INCOMPLETE and something downstream fails
  # loudly and locally. If a guard's list diverges, the check goes BLIND and passes. That
  # asymmetry alone settles it, and it is why `_lived_signals` below derives its columns
  # while this does not.
  #
  # AND THE OBVIOUS DERIVATION HERE IS WRONG, which is the trap: `history` is DELIBERATELY
  # not a status folder — check-board declares six, and the initializer builds
  # `("${STATUS_FOLDERS[@]}" history)` for the rotated-log destination. A sweep replacing
  # this list with STATUS_FOLDERS silently stops creating `progress/history/` and surfaces
  # later as an unrelated case failing. A correct derivation does exist — the six plus
  # `history` explicitly — it simply buys less than it costs in a builder. *The obvious
  # derivation is wrong here; the correct one is not worth it. Those are different
  # sentences and only the second is true of derivation in general.*
  for d in todo in_progress dev_complete qa_complete blocked done history; do
    : > "$SB_WORK/progress/$d/.gitkeep"
  done

  cat > "$SB_WORK/ARCHIVE.md" <<'EOF'
# ARCHIVE.md — condensed index of completed issues

## Archived
EOF

  # A gate runner the landing path can actually pass. The shipped frame ships with
  # an EMPTY table and refuses on purpose, so every sandbox that lands a branch
  # declares one echo gate — the harness is testing finish-pr.sh here, not the
  # project's real suite.
  _declare_sandbox_gate

  # Activate the role-prefix hook in the sandbox (this also applies to .kanban-wt,
  # which shares this repo's config).
  git -C "$SB_WORK" config core.hooksPath "$SB_WORK/scripts/githooks" >/dev/null 2>&1
}

# =============================================================================
# FIXTURE MUTATION, AND THE ONE RULE ALL OF IT OBEYS
#
# EVERY MUTATION ASSERTS. Measured 2026-08-26: every fixture mutation in this
# harness was a `perl -i -pe` with an anchor regex, and a `perl -i -pe` whose
# anchor does not match EXITS 0 AND LEAVES THE FILE BYTE-IDENTICAL. So a renamed
# array, a reflowed `GATES=(` line or a moved config key silently produced a
# sandbox that was never set up — and the case built on it then reported PASS
# about a premise that did not exist. That is the worst failure shape a harness
# has, because it is indistinguishable from success.
#
# So: a mutation that cannot find its anchor is FATAL to the run, not a case
# failure. `cf` is for "the subject under test misbehaved"; a fixture that did not
# take is "this harness is not measuring what it says", and every later green is
# then a claim about nothing. It aborts.
#
# TWO DIFFERENT ASSERTIONS, and the distinction matters:
#   • A mutation that ADDS or CHANGES content asserts THE CONTENT ARRIVED
#     (_declare_sandbox_gate, rel_insert, rel_set). Anchor missing → nothing
#     added → fatal.
#   • The NEUTRALIZER asserts ITS ANCHOR WAS FOUND and ITS POSTCONDITION HOLDS —
#     deliberately NOT "the file changed". A neutralizer is idempotent by nature:
#     on the kit's own tree the six config arrays already ship empty, so "it
#     changed something" is FALSE here and TRUE in an adopter. Asserting the
#     change would redden this repository and pass nowhere useful. Asserting the
#     anchor plus the postcondition is strictly stronger: it fails when the anchor
#     moves (the silent-no-op class) AND when the reset did not take, and it holds
#     whether or not work was needed.
#
# AND ONE QUESTION TO ASK OF EVERY CASE AND EVERY GUARD IN THIS FILE, MECHANICALLY,
# RATHER THAN WHEN SOMEBODY HAPPENS TO BE RESTRUCTURING ONE:
#
#     WHERE DOES EACH OPERAND ACTUALLY COME FROM — AND IS IT THE SAME TREE,
#     THE SAME MOMENT, AND THE SAME AUTHORITY AS THE OTHERS?
#
# It is not a style question. Every one of these was found by asking it, and none of
# them was found by reading the guard's logic, which was correct in all three:
#   • A prefix-scan guard drew its VOCABULARY from a working-tree file and its
#     SUBJECTS from the trunk — two operands, two trees, two moments. It would have
#     accepted a branch's newly-added role on trunk commits that predated it. Green
#     for a reason unrelated to correctness.
#   • A fixture declared a failing gate as an absolute path that does not exist on
#     every platform. An absent command exits 127, which is the code the case existed
#     to distinguish — so a portability slip in the CONTROL was indistinguishable from
#     the defect under test, and only asserting the OTHER direction separated them.
#   • An index entry's field order looked free until it turned out another script
#     READS that entry's leading token to avoid re-minting a retired id. The operand
#     had a second consumer nobody had named.
#   • And this file's own isolation case compares two snapshots of a tree it does not
#     own exclusively — so its operand is shared, and the only honest report names
#     that rather than attributing the change.
#
# The doctrine form of this belongs in process/doctrine/instruments.md beside the
# guard-strength family, not here; this is the harness's local copy of the question.
# =============================================================================

# A fixture that did not take aborts the run. Loudly, naming what it could not do.
_fixture_die() {
  {
    echo
    echo "════════ FIXTURE FAILURE — the sandbox was not set up ════════"
    echo "  $1"
    echo
    echo "  This is NOT a case failure. Every case after this point would assert a"
    echo "  premise that does not exist, and would report PASS while doing it."
    echo "  Aborting rather than printing a green about the wrong subject."
  } >&2
  exit 1
}

# Declare ONE gate record in the sandbox's copy of verify.sh. Self-asserting, and
# the single place the GATES anchor is written — _declare_sandbox_gate and every case
# that needs a bespoke gate go through here rather than repeating the perl.
# <record> is the bare `name|class|command…` text; the quoting and indent are added.
_declare_gate() {
  local rec_body="$1" v="$SB_WORK/scripts/verify.sh" rec
  rec="  \"$rec_body\""
  grep -qE '^GATES=\($' "$v" \
    || _fixture_die "_declare_gate: no '^GATES=(' line in the sandbox's verify.sh — the anchor moved, so gate '$rec_body' was NOT declared and anything downstream would run against an empty, REFUSING gate runner."
  # BEGIN{shift}, not $ENV{} — one convention across every parameterised mutator in this
  # file. It also keeps the record out of the process environment, where a child could
  # read it and where a value containing a newline would arrive differently.
  perl -i -pe 'BEGIN{$r=shift} $_ .= "  \"$r\"\n" if /^GATES=\($/' "$rec_body" "$v"
  grep -qxF "$rec" "$v" \
    || _fixture_die "_declare_gate: '$rec_body' is not in verify.sh after the insert."
}

# Insert one always-green `select` gate into the sandbox's copy of verify.sh.
_declare_sandbox_gate() {
  _declare_gate 'sandbox gate|select|/bin/echo sandbox-gate-green'
}

# =============================================================================
# THE NEUTRALIZER. Reset every CONFIG-BLOCK seam the sandbox inherited from this
# repository back to the kit's shipped state, so a case measures the FRAME.
#
# RESET VALUES, NEVER DELETE LINES. kit-init.sh derives the current ISSUE_PREFIX
# and PROJECT_NAME defaults out of config.sh and HARD-EXITS if it cannot read
# either ("could not read the current … default out of scripts/config.sh"). A
# neutralizer that stripped those lines would turn every kit-init case into exit 1
# — a red that looks like a kit-init defect and is really a fixture defect. The
# one thing it does delete is kit-init's own appended stamp receipt, which is not
# a declaration but a marker, and which every kit-init case must not meet (its
# presence is one of kit-init's four ALREADY-LIVED signals, so leaving it makes
# kit-init refuse before it reaches anything the case is about).
# =============================================================================

# The scaffolding sentinel, DERIVED from the shipped root document that carries it. This
# is the harness's only statement of the mark; check-board.sh's probe for it is a separate
# author, and case_scaffolding_fixture_matches_the_tree holds the two against each other.
# NO FALLBACK: a harness that cannot read the mark would seed a fixture check-board.sh
# cannot see, and every graduation case would then pass by not testing anything.
KIT_SCAFFOLD_MARK="$(sed -n 's/^<!-- *\(BOOTSTRAP-[A-Z-]*\).*/\1/p' "$REAL_REPO_ROOT/CLAUDE.md" 2>/dev/null | head -1)"
if [ -z "$KIT_SCAFFOLD_MARK" ]; then
  echo "FIXTURE: could not read the scaffolding sentinel out of CLAUDE.md." >&2
  echo "         It is the mark check-board.sh's graduation arm looks for; seeding a" >&2
  echo "         guessed one would make every graduation case pass without testing." >&2
  exit 1
fi

# The stamp receipt kit-init appends to config.sh. DERIVED from kit-init.sh rather
# than re-typed, per this harness's own contract for every other seam it reads.
KIT_STAMP_MARK="$(sed -n "s/^STAMP_MARK='\(.*\)'/\1/p" "$REAL_SCRIPTS/kit-init.sh" 2>/dev/null | head -1)"
[ -n "$KIT_STAMP_MARK" ] || KIT_STAMP_MARK='# Stamped by scripts/kit-init.sh'

# The angle-bracket prefix placeholder the shipped templates and role docs carry
# (`<PREFIX>-NNN`), and the classification marker's key, which only LOOKS like the
# prefix. BOTH DERIVED from kit-init.sh for the same reason KIT_STAMP_MARK is: this
# harness is a CITER of that script's vocabulary, and a re-typed literal is the next
# drift. The fallbacks are last resorts for a tree with no kit-init.sh at all — the
# kit-init family SKIPs there anyway.
KIT_PREFIX_PLACEHOLDER="$(sed -n "s/^PREFIX_PLACEHOLDER='\(.*\)'/\1/p" "$REAL_SCRIPTS/kit-init.sh" 2>/dev/null | head -1)"
[ -n "$KIT_PREFIX_PLACEHOLDER" ] || KIT_PREFIX_PLACEHOLDER='<PREFIX>'
KIT_CLASS_MARKER_KEY="$(sed -n "s/^CLASS_MARKER_KEY='\(.*\)'/\1/p" "$REAL_SCRIPTS/kit-init.sh" 2>/dev/null | head -1)"
[ -n "$KIT_CLASS_MARKER_KEY" ] || KIT_CLASS_MARKER_KEY='KIT-CLASS:'

# This tree's CURRENT issue prefix, read with kit-init.sh's own anchored sed — the
# same expression, so a change to the config line's shape breaks both together
# rather than leaving this one quietly matching nothing. On the shipped frame this
# reads the neutral prefix; in an adopted project it reads what kit-init stamped,
# and THAT is the token the sandbox's copied templates and role docs carry.
KIT_TREE_PREFIX="$(sed -n 's/^ISSUE_PREFIX="\${ISSUE_PREFIX:-\([^}]*\)}"/\1/p' "$REAL_SCRIPTS/config.sh" 2>/dev/null | head -1)"
# Empty here is NOT a benign miss. The `[ -n "$KIT_TREE_PREFIX" ]` branch downstream simply
# SKIPS when this is empty, so a shape change would silently switch off a whole neutralizer
# rather than reporting one — the exact class this seam's contract exists to prevent.
if [ -z "$KIT_TREE_PREFIX" ]; then
  echo "FIXTURE: the ISSUE_PREFIX declaration in scripts/config.sh did not parse." >&2
  echo "         Its shape is contracted (process/contracts/config-seam.md § 2)." >&2
  echo "         Refusing to continue: the tree-prefix neutralizer would silently do nothing." >&2
  exit 1
fi

# _neu_scalar <file> <VAR> <exact replacement line>
_neu_scalar() {
  local f="$1" var="$2" line="$3"
  [ -f "$f" ] || _fixture_die "_neu_scalar: $f does not exist in the sandbox."
  grep -qE "^${var}=" "$f" \
    || _fixture_die "_neu_scalar: no '^${var}=' line in ${f##*/} — the key was renamed or moved out of the config block, so it was NOT neutralized and the case would assert this repository's value."
  perl -i -pe 'BEGIN{$v=shift; $r=shift} s/^\Q$v\E=.*$/$r/' "$var" "$line" "$f"
  grep -qxF "$line" "$f" \
    || _fixture_die "_neu_scalar: ${var} in ${f##*/} does not read '${line}' after the reset."
}

# _neu_array_records <file> <ARRAY> → count of non-comment, non-blank lines inside
# the array's ( … ) fence. This is the neutralizer's postcondition instrument, so
# it is deliberately separate and readable.
_neu_array_records() {
  awk -v a="$2" '
    $0 == a "=(" { inb = 1; next }
    inb && /^\)/ { inb = 0 }
    inb && !/^[[:space:]]*#/ && NF { n++ }
    END { print n + 0 }
  ' "$1"
}

# _neu_array <file> <ARRAY> — empty a config array's RECORDS, keeping its
# `NAME=(` / `)` fence and every explanatory comment inside it. The fence must
# survive: _declare_sandbox_gate, rel_insert and kit-init's --gate-command fill
# all anchor on `^NAME=($`, and the comments are the config block's documentation.
_neu_array() {
  local f="$1" name="$2" before after
  [ -f "$f" ] || _fixture_die "_neu_array: $f does not exist in the sandbox."
  grep -qE "^${name}=\($" "$f" \
    || _fixture_die "_neu_array: no '^${name}=(' line in ${f##*/} — the array was renamed or reshaped, so emptying it did NOTHING and every case downstream would run against this repository's declared ${name}."
  before="$(_neu_array_records "$f" "$name")"
  perl -i -ne 'BEGIN{$a=shift}
    if (/^\Q$a\E=\($/) { $in = 1; print; next }
    if ($in && /^\)/)  { $in = 0; print; next }
    next if ($in && !/^\s*#/ && /\S/);
    print' "$name" "$f"
  after="$(_neu_array_records "$f" "$name")"
  [ "$after" -eq 0 ] \
    || _fixture_die "_neu_array: ${name} in ${f##*/} still holds ${after} record(s) after neutralizing (it held ${before} before)."
  grep -qE "^${name}=\($" "$f" \
    || _fixture_die "_neu_array: emptying ${name} in ${f##*/} destroyed its own '${name}=(' fence."
}

# =============================================================================
# THE SECOND NEUTRALIZER — the .claude/ tree the kit-init cases copy in.
#
# WHY IT IS A SEPARATE FUNCTION RATHER THAN A LINE INSIDE _kit_neutral_config.
# That one runs inside make_sandbox, where .claude/ does not exist yet: the
# templates and the role docs are copied in LATER, by kit_init_sandbox and by the
# option-parsing case. A branch for them there would be permanently false — the
# silent no-op this file's own fixture doctrine is written against. So the rule is
# unchanged and only its call site moves: EVERY SITE THAT COPIES THE REAL .claude/
# TREE INTO A SANDBOX CALLS THIS, immediately after the copy.
#
# THE DEFECT IT CLOSES. kit-init stamps the issue prefix into
# .claude/templates/ AND scripts/config.sh together. _kit_neutral_config resets
# config.sh to the shipped `KIT`, so in an adopted project the sandbox held a
# config.sh saying `KIT` and templates saying `XYZ-NNN`. kit-init inside the
# sandbox then looked for the placeholder and for `KIT-`, found neither, and
# substituted NOTHING — so `case_kit_init_happy` failed on "the ISSUE template body
# was not stamped", in every project that had completed the kit's own day one.
# The neutralizer half of the fix is invertibility; the postcondition half is what
# makes its next absence loud instead of silent.
#
# WHAT IT RESTORES, AND WHAT IT DELIBERATELY CANNOT — the property, then the
# reading. kit-init stamps three donor tokens into .claude/: the prefix, `<trunk>`
# and `<project-name>`. What is restored is THE PREFIX IN ITS ID SHAPE (`<PREFIX>-`),
# because that is the only form whose reverse is decidable: the token is delimited
# by the `-` and its stamped value is derivable from config.sh. What is NOT
# restored, and why each one is a refusal rather than an oversight:
#   • a BARE prefix token in prose. kit-init's template pass is blanket
#     (`s|<PREFIX>|XYZ|g`), so a sentence that named the placeholder alone comes out
#     naming the adopter's token alone, with nothing left to distinguish it from any
#     other use of that word. Not invertible, and guessing would edit prose.
#   • `<trunk>`, stamped to a BRANCH NAME — reversing `main` to `<trunk>` rewrites
#     the word wherever the prose happens to use it.
#   • `<project-name>`, stamped blanket, by the same argument.
# None of the three costs a case its subject: what the kit-init family asserts is
# the stamped id reaching the TEMPLATE BODY, and kit-init's own census counts the
# placeholder and the `<prefix>-` shape — neither can see a bare token. If one ever
# grows an assertion it needs its own invertible reverse, NOT a wider sed here.
# READING, 2026-08-28, so the limit is a measurement and not a hope: a tree stamped
# `--prefix XYZ --trunk main`, restored by this function, still differs from the
# shipped .claude/ in 5 of the 12 copied files — every difference is `<trunk>`, plus
# one prose NOTE carrying the bare prefix. Zero differences in the id shape.
# =============================================================================
_kit_neutral_claude() {
  local root="$SB_WORK/.claude" f tpl mk_before mk_after
  # A scratch token, not a shared vocabulary: it only has to be absent from the
  # corpus for the length of one sed, so it is spelled here rather than derived.
  local sentinel='@@KITTESTCLASSKEY@@'
  [ -d "$root" ] || return 0

  # Reverse kit-init's prefix stamp — and ONLY on a tree that carries one. On the
  # shipped frame KIT_TREE_PREFIX reads the neutral prefix and this whole block is
  # skipped, so this repository's own tree is provably untouched: the shape every
  # fixture mutation here is held to (assert the anchor and the
  # postcondition, never "something changed", because on the kit's own tree nothing
  # SHOULD change). Skipping is CORRECT and not merely safe: a project that stamped
  # the shipped prefix leaves `KIT-NNN` behind, and kit-init's own OLD_PREFIX branch
  # rewrites exactly that inside the sandbox.
  if [ -n "$KIT_TREE_PREFIX" ] && [ "$KIT_TREE_PREFIX" != "$KIT_NEUTRAL_PREFIX" ]; then
    mk_before="$(grep -roF "$KIT_CLASS_MARKER_KEY" "$root" 2>/dev/null | wc -l | tr -d ' ')"
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      # Three expressions, one invocation, applied in order per line: hide the
      # marker's key, restore the prefix, put the key back. This is kit-init.sh's
      # own idiom RUN BACKWARDS, and it is here for the same reason it is there:
      # `KIT-CLASS:` matches a bare `<prefix>-` rewrite, and the shipped prefix is
      # also `KIT`, so the unprotected form defaces the marker of every file it
      # touches. Atomic per file — a protect/restore pair around separate commands
      # would leave the sentinel in the tree if anything failed between them.
      sed -i.bak -E -e "s|${KIT_CLASS_MARKER_KEY}|${sentinel}|g" \
                    -e "s|${KIT_TREE_PREFIX}-|${KIT_PREFIX_PLACEHOLDER}-|g" \
                    -e "s|${sentinel}|${KIT_CLASS_MARKER_KEY}|g" "$f"
      rm -f "$f.bak"
    done < <(find "$root" -type f -name '*.md' | sort)
    mk_after="$(grep -roF "$KIT_CLASS_MARKER_KEY" "$root" 2>/dev/null | wc -l | tr -d ' ')"
    # BOTH DIRECTIONS. The restoration must happen AND must not be paid for out of
    # the classification markers; asserting only the first would let the sed that
    # defaces every marker report success.
    [ "$mk_before" = "$mk_after" ] \
      || _fixture_die "_kit_neutral_claude: restoring the prefix placeholder changed the number of '$KIT_CLASS_MARKER_KEY' markers under the sandbox's .claude/ (${mk_before} → ${mk_after}) — the marker's KEY was collateral damage, which is precisely what kit-init.sh's sentinel exists to prevent."
    grep -rqF "$sentinel" "$root" 2>/dev/null \
      && _fixture_die "_kit_neutral_claude: the protect/restore sentinel '$sentinel' survived in the sandbox's .claude/ tree — the restore expression did not run."
  fi

  # THE POSTCONDITION, ASSERTED WHETHER OR NOT ANYTHING WAS RESTORED. This is the
  # half whose absence is why the defect above regressed unseen: the two earlier
  # causes were fixed, the numbers moved, and NOTHING asserted that the fixture had
  # actually reached ship state. It holds in both directions — untouched on the
  # shipped frame, restored on an adopted one — so it is an anchor, not a diff.
  tpl="$root/templates/ISSUE.template.md"
  if [ -f "$tpl" ]; then
    grep -qF "$KIT_PREFIX_PLACEHOLDER" "$tpl" \
      || _fixture_die "_kit_neutral_claude: the sandbox's .claude/templates/ISSUE.template.md does not carry the shipped prefix placeholder '$KIT_PREFIX_PLACEHOLDER' after neutralizing (this tree's ISSUE_PREFIX reads '${KIT_TREE_PREFIX:-<unreadable>}'). The fixture did NOT reach ship state: kit-init inside the sandbox would find nothing to substitute, and every case asserting the stamped id would redden as though kit-init were broken."
  fi
}

# _neu_roles — reset the sandbox's ROLE SET to the kit's shipped alternation, across the
# same seams kit-init stamps and by the same substitution run backwards.
#
# THE SEAM LIST IS DERIVED HERE FOR THE SAME REASON IT IS DERIVED IN kit-init, and this
# fixture is the proof the reason is real: it carried a hand-typed list of THREE while
# kit-init stamped FOUR — subtask.sh was missing — and two comments in this file said
# "the three seams kit-init stamps" while the initializer stamped four. A builder's
# literal is usually cheap because something downstream fails loudly and locally; this
# one was not, and the header below records what it actually cost.
#
# WHY THE SANDBOX MUST OWN ITS ROLE VOCABULARY. Every --role argument and every "[Role]"
# commit subject in this file is a literal. On a project that ran `kit-init --roles`, the
# sandbox inherited THAT set, and those literals were judged against it: measured, an
# adopter with 'PM|Eng|QA' got 13 FAILs across move-issue.sh, archive.sh and release.sh —
# tools that were working correctly. Deriving each literal instead cannot work: three
# cases model a HAND-OFF between two distinct roles, and an adopter's set may legally have
# one member, so a derivation cannot express a distinction its source may not contain.
_neu_roles() {
  local cm="$SB_WORK/scripts/githooks/commit-msg" cur f
  [ -f "$cm" ] || return 0
  # FALLBACK POLICY HERE: _fixture_die. See lib/role-set.sh for the canonical read; the
  # EXPRESSION is shared by declaration, the POLICY is each caller's and they differ.
  cur="$(sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p" "$cm" | head -1)"
  [ -n "$cur" ] \
    || _fixture_die "_neu_roles: no ROLE_PREFIXES line in the sandbox's commit-msg — the seam was renamed or moved, so the role vocabulary was NOT neutralized and every --role literal in this file would be judged against whatever the adopter declared."
  local seams=""
  if [ "$cur" != "$KIT_NEUTRAL_ROLE_PREFIXES" ]; then
    # NON-RECURSIVE, kit-init's reason verbatim: a recursive sweep would also match
    # scripts/test/run.sh — this file — and rewrite the assertions to agree with
    # whatever they were measuring.
    seams="$( { grep -lF -- "$cur" "$SB_WORK"/scripts/*.sh "$SB_WORK"/scripts/githooks/* 2>/dev/null || true; } )"
    [ -n "$seams" ] \
      || _fixture_die "_neu_roles: the sandbox's commit-msg declares '$cur' but NO file under scripts/ carries it — the derivation found nothing to reset, so the role vocabulary is not neutralized and every --role literal in this file would be judged against whatever the adopter declared."
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      # The '@' delimiter is kit-init's, for kit-init's reason: the value is a
      # '|'-separated ERE alternation and would cut an s|…|…| in half with its own data.
      NEU_CUR="$cur" NEU_NEW="$KIT_NEUTRAL_ROLE_PREFIXES" \
        perl -i -pe 's@\Q$ENV{NEU_CUR}\E@$ENV{NEU_NEW}@g' "$f"
    done <<NEU_SEAM_EOF
$seams
NEU_SEAM_EOF
  fi
  # POSTCONDITION, asserted whether or not anything was rewritten — the anchor-and-property
  # shape, not "something changed": on the kit's own tree the set already IS the shipped
  # one and the correct behaviour is to change nothing.
  grep -qF "ROLE_PREFIXES='$KIT_NEUTRAL_ROLE_PREFIXES'" "$cm" \
    || _fixture_die "_neu_roles: the sandbox's commit-msg does not carry the shipped role set after the reset (it reads '$cur')."
  # AND EVERY OTHER SEAM, not just the one the set is READ from. The old postcondition
  # checked $cm alone, which is exactly as narrow as the hand-typed list was: a seam left
  # out of the list was also left out of the check, so the fixture could report success
  # while a --role whitelist elsewhere still enforced the adopter's set.
  if [ -n "$seams" ]; then
    local still
    still="$( { grep -lF -- "$cur" "$SB_WORK"/scripts/*.sh "$SB_WORK"/scripts/githooks/* 2>/dev/null || true; } )"
    [ -z "$still" ] \
      || _fixture_die "_neu_roles: $(printf '%s' "$still" | tr '\n' ' ')still carr(y|ies) the adopter's role set '$cur' after the reset — the neutralization reached some seams and not others, and the cases judging --role literals against the shipped set would redden as though the tools were broken."
  fi
}

_kit_neutral_config() {
  local c="$SB_WORK/scripts/config.sh"
  local v="$SB_WORK/scripts/verify.sh"
  local r="$SB_WORK/scripts/release.sh"

  # ── config.sh: the three values kit-init.sh stamps on day one. The exact line
  #    SHAPE matters, not just the value — kit-init parses these with anchored
  #    seds (`^ISSUE_PREFIX="\${ISSUE_PREFIX:-\([^}]*\)}"`), so the
  #    `${VAR:-default}` form has to survive verbatim.
  _neu_scalar "$c" ISSUE_PREFIX "ISSUE_PREFIX=\"\${ISSUE_PREFIX:-${KIT_NEUTRAL_PREFIX}}\""
  _neu_scalar "$c" PRD_PREFIX   "PRD_PREFIX=\"\${PRD_PREFIX:-${KIT_NEUTRAL_PRD_PREFIX}}\""
  _neu_scalar "$c" PROJECT_NAME "PROJECT_NAME=\"\${PROJECT_NAME:-${KIT_NEUTRAL_PROJECT_NAME}}\""

  # kit-init's appended stamp receipt: remove it, or every kit-init case meets the
  # ALREADY-LIVED refusal on a sandbox that has not lived. No assertion that a line
  # was removed — an unstamped config.sh (this repository's) has none to remove, and
  # that is the healthy state. The POSTCONDITION is what is asserted: absent.
  perl -i -ne 'BEGIN{$m=shift} print unless /^\Q$m\E/' "$KIT_STAMP_MARK" "$c"
  grep -q "^$KIT_STAMP_MARK" "$c" \
    && _fixture_die "_kit_neutral_config: config.sh still carries kit-init's stamp receipt ('$KIT_STAMP_MARK') — every kit-init case would hit the already-lived refusal."

  # ── the role set, across the seams that carry it (derived, as kit-init derives them).
  _neu_roles

  # ── verify.sh: the gate table and the guard floor.
  _neu_array "$v" GATES
  _neu_array "$v" GUARD_SET
  # GUARD_ENUM is a SCALAR, so _neu_array cannot see it — and without this reset a
  # stamped adopter's enumerator command would be carried into every sandbox and every
  # reconciliation case would run against their tree instead of the frame.
  _neu_scalar "$v" GUARD_ENUM 'GUARD_ENUM=""'

  # ── release.sh: four declared arrays and the publish/version scalars. Optional —
  #    release.sh is a capability this harness probes for (has_release), so a kit
  #    without it neutralizes what is there and says nothing about what is not.
  if [ -f "$r" ]; then
    _neu_array "$r" VERSION_FILES
    _neu_array "$r" PREFLIGHT_GATES
    _neu_array "$r" RELEASE_DOCS
    _neu_array "$r" DIST_DOCS
    _neu_scalar "$r" RELEASE_PUBLISH     'RELEASE_PUBLISH=false'
    _neu_scalar "$r" VERSION_IN_TAG_ONLY 'VERSION_IN_TAG_ONLY=false'
    _neu_scalar "$r" DIST_ARTIFACT_GLOB  'DIST_ARTIFACT_GLOB=""'
    _neu_scalar "$r" BUILD_COMMAND       'BUILD_COMMAND="${RELEASE_BUILD_CMD:-}"'
    _neu_scalar "$r" DIST_BRANCH         'DIST_BRANCH="${RELEASE_DIST_BRANCH:-dist}"'
  fi
}

# Publish the seeded board to the trunk + the remote. Call after seed_issue(s).
# seed_scaffolding_tree [--no-project]
#
# THE DAY-ONE TREE, STATED ONCE. Five cases used to re-type this three-file fixture and
# they had already stopped agreeing: four wrote PROJECT.md and one did not. The odd one
# out was RIGHT — it needs check-board's REPLACE finding without the FILL one — but
# nothing said so, and an absent third `printf` is not an argument. It is now an
# argument: `--no-project`, at the call site, in the reader's line of sight.
#
# THE SENTINEL IS DERIVED FROM THE SHIPPED DOCUMENT, not from check-board.sh's probe and
# not from memory. The probe is the CONSUMER; deriving the fixture from the consumer
# would make every case here agree with the tool by construction, which is the one thing
# a control must not do. The shipped root documents are the AUTHORITY — they are what an
# adopter actually deletes — so a rename there reaches the fixture, and the case that
# holds all three against each other catches a rename anywhere else.
seed_scaffolding_tree() {
  local want_project=true
  while [ $# -gt 0 ]; do
    case "$1" in
      --no-project) want_project=false; shift ;;
      *) _fixture_die "seed_scaffolding_tree: unknown argument '$1'" ;;
    esac
  done
  printf '<!-- %s -->\n# scaffolding\n' "$KIT_SCAFFOLD_MARK" > "$SB_WORK/CLAUDE.md"
  printf '<!-- %s -->\n# scaffolding\n' "$KIT_SCAFFOLD_MARK" > "$SB_WORK/README.md"
  if [ "$want_project" = true ]; then
    printf '# PROJECT.md\n\nTrunk: <trunk>\n' > "$SB_WORK/PROJECT.md"
  fi
}

publish_sandbox() {
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[PM] seed sandbox board" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" remote add origin "$SB_ORIGIN" >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" remote set-head origin "$SB_TRUNK" >/dev/null 2>&1
}

# On the remote's trunk: does path exist in the tree?
# probe_pick <find-args…> — the FIRST match, WITHOUT a pipe.
#
# THE HEADER'S PIPEFAIL RULE, applied to the one producer it names by name. `find … |
# head -1` is a producer that grows with the project feeding a reader that exits early:
# the reader closes the pipe, `find` takes SIGPIPE, and `pipefail` promotes that to the
# status of the whole pipeline. Measured on this machine: the raw pipeline exits nonzero
# 10/10 at ~300 files and 20/20 at 3000; the kit's own largest corpus here is 20 files,
# so this is a THRESHOLD NOBODY HAS CROSSED — not a live bug. It is fixed for the reason
# the three `origin_*` helpers ten lines below were: the rule is stated in this file's own
# header and these four call sites were the last ones ignoring it.
#
# CALLERS STILL OWE THE EMPTY TEST. A `find` that fails on an unreadable directory now
# returns empty AND nonzero; every existing caller tests emptiness, which is the check
# that matters — the value, not the status.
probe_pick() { local all; all="$(find "$@")" || return 1; printf '%s' "${all%%$'\n'*}"; }

# _control_did_not_run <what> — ONE spelling of the refusal that says a control was
# skipped. Six call sites had six wordings and three different trailing clauses; one
# dropped the "so the green above is unproven" tail entirely, which is the half that tells
# a reader the PASS beside it is worth nothing. The noun phrase stays the caller's.
_control_did_not_run() {
  cf "(control) could not $1 — the control did not run, so the green above is unproven"
}

origin_has_path() {
  git -C "$SB_WORK" fetch origin "$SB_TRUNK" --quiet >/dev/null 2>&1
  local paths  # capture, then test — ls-tree grows with the board (header: THE PIPEFAIL RULE)
  paths="$(git -C "$SB_WORK" ls-tree -r --name-only "origin/$SB_TRUNK" 2>/dev/null)"
  printf '%s\n' "$paths" | grep -qxF "$1"
}
origin_file_contains() {  # <path> <pattern>
  git -C "$SB_WORK" fetch origin "$SB_TRUNK" --quiet >/dev/null 2>&1
  local body  # capture, then test — the file may be a log that grows (header: THE PIPEFAIL RULE)
  body="$(git -C "$SB_WORK" show "origin/$SB_TRUNK:$1" 2>/dev/null)"
  printf '%s\n' "$body" | grep -q "$2"
}
origin_log_has_subject() {  # <pattern>
  # CAPTURE, THEN TEST — never `git log … | grep -q`. See the PIPEFAIL RULE in this
  # file's header: `git log` grows with the trunk, `grep -q` exits on the first match,
  # and the producer's SIGPIPE became this function's answer. It returned "not found"
  # for subjects that were present, and only ever in the direction of a FALSE RED,
  # which is why it survived: every caller reads it as `… || cf …`.
  local subjects
  git -C "$SB_WORK" fetch origin "$SB_TRUNK" --quiet >/dev/null 2>&1
  subjects="$(git -C "$SB_WORK" log "origin/$SB_TRUNK" --format='%s' 2>/dev/null)"
  printf '%s\n' "$subjects" | grep -q "$1"
}
# A real branch with a real net change, pushed. <id> <slug> <marker-file>
seed_branch() {
  local id="$1" slug="$2" marker="$3"
  git -C "$SB_WORK" checkout -b "feature/${id}-${slug}" "$SB_TRUNK" --quiet >/dev/null 2>&1
  echo "a real change" > "$SB_WORK/$marker"
  git -C "$SB_WORK" add "$marker" >/dev/null 2>&1
  sbcommit -m "[Dev] ${id}: add a real change" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/${id}-${slug}" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" checkout "$SB_TRUNK" --quiet >/dev/null 2>&1
}
# The stub-marker environment finish-pr.sh honours ONLY for this harness.
FPR_STUB=(FINISH_PR_TEST_ALLOW_STUB=1 FINISH_PR_VERIFY_CMD=true FINISH_PR_PREMERGE_CMD=true)

# =============================================================================
# CASE — move-issue.sh moves + appends Activity + commits + PUSHES
# =============================================================================
case_move_issue() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-100" sandbox chore "Sandbox move test"
  publish_sandbox

  local out rc
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-100" in_progress \
            --role Dev --note "picked up in sandbox" 2>&1 )"; rc=$?

  [ "$rc" -eq 0 ] || cf "move-issue exited $rc (expected 0): $out"
  origin_has_path "progress/in_progress/$SB_PREFIX-100-sandbox.md" \
    || cf "file not moved to in_progress/ on the trunk"
  origin_has_path "progress/todo/$SB_PREFIX-100-sandbox.md" \
    && cf "file still present in todo/ on the trunk"
  origin_file_contains "progress/in_progress/$SB_PREFIX-100-sandbox.md" "picked up in sandbox" \
    || cf "Activity line not appended"
  origin_log_has_subject "\[Dev\] $SB_PREFIX-100 → in_progress: picked up in sandbox" \
    || cf "commit subject not found on the trunk (not pushed?)"

  finish "move-issue.sh: move + Activity append + commit pushed to the trunk"
  teardown
}

# _role_literals_used <file> — every role NAME this harness writes, extracted BY
# POSITION rather than by neighbouring words. Position is what makes it precise: the
# same tokens appear inside diagnostic strings ("the release commit carries no [Role]
# prefix", "every --role literal in this file") and those are prose ABOUT roles, not
# roles being used. A word-proximity scan picks them up; an argument-position scan
# does not. Measured on this file: by position the answer is exactly the four roles
# the cases use, with no exemption list to maintain.
_role_literals_used() {  # <path to a harness source>
  local f="$1"
  {
    # (1) `--role <Name>` argument positions.
    grep -vE '^[[:space:]]*#' "$f" | grep -oE '\-\-role +[A-Z][A-Za-z0-9]*' | sed 's/--role *//'
    # (2) a role tag OPENING a commit-subject argument: -m "[Name] …"
    grep -vE '^[[:space:]]*#' "$f" | grep -oE -- "-q?m +[\"']\[[A-Z][A-Za-z]+\]" \
      | grep -oE '\[[A-Z][A-Za-z]+\]' | tr -d '[]'
    # (3) a role tag OPENING a seeded Activity / progress.md line.
    grep -vE '^[[:space:]]*#' "$f" | grep -oE -- "(printf|echo)[^\"']*[\"'][^\"']*\[[A-Z][A-Za-z]+\] " \
      | grep -oE '\[[A-Z][A-Za-z]+\]' | tr -d '[]'
  } | sort -u
}

# =============================================================================
# CASE — EVERY ROLE LITERAL THIS HARNESS WRITES IS ONE THE SANDBOX DECLARES
#
# WHAT THIS GUARDS, AND WHAT ALREADY GUARDS THE REST. case_ship_state asserts the
# SHIPPED commit-msg still carries the role set this file declares — that is the
# constant-vs-file direction. Nothing asserted the other direction: that the names the
# CASES TYPE are members of that set. The neutralizer corrects the sandbox's hook and
# move-issue.sh whitelist; it cannot correct a case that types a role the hook does not
# carry, and such a case fails with "--role must be …" or a rejected commit — a red
# about the fixture wearing the costume of a tool defect.
#
# THE FORM IS NARROWER THAN THE ONE FIRST PROPOSED, and the reason is kept because the
# first form would now be wrong. The original proposal was to FORBID role literals
# outright, which was right while the sandbox inherited the adopter's set: a literal was
# then one rename away from a false red. Once the sandbox DECLARES the set, the literals
# are correct — and three cases model a hand-off, so they need two distinct ones. What
# survives is membership, not abstinence.
# =============================================================================
case_role_literals_are_declared() {
  cf_reset
  make_sandbox   # for SB_TMP + teardown; this case reads this file, not the sandbox

  local self="${BASH_SOURCE[0]}" used n t
  if [ ! -f "$self" ]; then
    skp "every role literal this harness writes is one the sandbox declares" "cannot locate this harness's own source"
    teardown; return
  fi

  used="$(_role_literals_used "$self")"
  n="$(printf '%s\n' "$used" | grep -c . || true)"
  # ASSERT THE OPERAND: zero literals found means the scan lost its subject, not that
  # the file is clean — every one of the shapes above would have to vanish at once.
  [ "$n" -ge 1 ] \
    || cf "no role literal was found in this file at all — the scan lost its operand rather than finding a clean file"

  while IFS= read -r t; do
    [ -n "$t" ] || continue
    printf '%s\n' "$KIT_NEUTRAL_ROLE_PREFIXES" | tr '|' '\n' | grep -qx "$t" \
      || cf "this harness writes the role '$t', which the sandbox's declared set does not contain (${KIT_NEUTRAL_ROLE_PREFIXES}) — the neutralized commit-msg hook and move-issue.sh whitelist would both reject it, and the case would redden about the fixture while naming a tool"
  done <<ROLE_EOF
$used
ROLE_EOF

  # ── THE REDDENING CONTROL, on a COPY — never this file (instruments.md § A.2).
  local probe="$SB_TMP/roleprobe.sh"
  cp "$self" "$probe" 2>/dev/null || true
  if [ ! -f "$probe" ]; then
    _control_did_not_run "copy this harness to plant into"
  else
    # THE OUTSIDER'S NAME IS BUILT, NEVER WRITTEN — and that is not fastidiousness, it
    # is required. This case scans THE FILE IT LIVES IN, so a literal `--role Eng`
    # written here would be found by the scan above and redden the case on its own
    # control text. Measured: it did, on the first draft. `%s` carries the name into
    # the PROBE while this source holds only the format string.
    local outsider='Eng'
    printf '\n  ( cd x && ./scripts/move-issue.sh ID in_progress --role %s --note x )\n' \
      "$outsider" >> "$probe"
    _role_literals_used "$probe" | grep -qx "$outsider" \
      || cf "(control) a planted '--role $outsider' was NOT found by the scan — it cannot see the defect it is named after"
    # ...and the membership test must reject it, or finding it buys nothing.
    printf '%s\n' "$KIT_NEUTRAL_ROLE_PREFIXES" | tr '|' '\n' | grep -qx "$outsider" \
      && cf "(control) '$outsider' IS in the declared set, so the plant cannot demonstrate a rejection — pick a name the set does not contain"
  fi

  finish "every role literal this harness writes is a member of the set the sandbox declares — $n found by argument position ($(printf '%s' "$used" | tr '\n' ' ')), and a planted outsider is found and rejected"
  teardown
}

# =============================================================================
# CASE — --set-pr WRITES BACK INTO A CARD MINTED FROM THE REAL TEMPLATE
#
# WHY THIS CASE AND NOT A FIXTURE ASSERTION: `--set-pr` writes only into an EXISTING
# `pr:` frontmatter line and otherwise warns "skipping write-back". The harness used
# to seed `pr: null` in its own fixtures while NO shipped template carried the key —
# so the suite tested a shape the templates never produced, and the flag could not
# work on a kit-minted card while passing here. The templates now declare it; this is
# the case that proves the two ends meet, and it mints through new-issue.sh rather
# than seeding, because the seam is precisely between the template and the tool.
#
# THE PREMISE IS ASSERTED IN TWO PLACES, and both were paid for. An earlier attempt at
# this case died on `move-issue.sh` refusing "no file matching …" — a not-found
# refusal that reads like a mover defect and is really the card never reaching the
# trunk. So: the minted card must carry a `pr:` line at all (or the template half is
# undone and this case proves nothing), and it must be ON the trunk before the mover
# is asked to move it (or the refusal is about the fixture).
# =============================================================================
case_move_issue_set_pr_on_a_minted_card() {
  cf_reset
  if ! has_kit_init; then
    skp "move-issue --set-pr writes back into a minted card" "scripts/kit-init.sh absent"; return
  fi
  if ! has_issue_template; then skp "move-issue --set-pr writes back into a minted card" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox

  local id="$SB_PREFIX-777" card="progress/todo/$SB_PREFIX-777-setpr-probe.md" out rc
  out="$( cd "$SB_WORK" && ./scripts/new-issue.sh setpr-probe --id "$id" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "new-issue.sh exited $rc minting $id: $out"
  [ -f "$SB_WORK/$card" ] || cf "new-issue.sh did not create $card: $out"

  # PREMISE 1 — the template half. Without a `pr:` line there is nothing to write back
  # into, and --set-pr would warn rather than fail, so this case would pass vacuously.
  if [ -f "$SB_WORK/$card" ]; then
    grep -q '^pr:' "$SB_WORK/$card"       || _fixture_die "case_move_issue_set_pr_on_a_minted_card: the minted card carries no 'pr:' frontmatter line, so --set-pr has nothing to write into and this case cannot distinguish the fix from its absence."
  fi

  publish_sandbox

  # PREMISE 2 — the mover reads the TRUNK's board, not the checkout. If the mint did
  # not reach the trunk the mover refuses "no file matching …", which reads exactly
  # like a mover defect and is a fixture gap.
  origin_has_path "$card"     || _fixture_die "case_move_issue_set_pr_on_a_minted_card: $card is not on the trunk after publish_sandbox, so the mover would refuse with a not-found that is about the fixture."

  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$id" in_progress \
            --role "$SB_ROLE" --note "set-pr probe" --set-pr 'https://example.invalid/pr/1' 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "the move with --set-pr exited $rc: $out"
  printf '%s\n' "$out" | grep -q 'skipping write-back' \
    && cf "--set-pr reported 'skipping write-back' on a card minted from the shipped template — the template and the flag still do not meet: $out"
  origin_file_contains "progress/in_progress/$SB_PREFIX-777-setpr-probe.md" 'example.invalid/pr/1' \
    || cf "the --set-pr value did not reach the moved card on the trunk"

  finish "move-issue --set-pr writes back into a card minted from the SHIPPED template, and the value reaches the trunk"
  teardown
}

# =============================================================================
# CASE — the mover's not-found refusal costs nothing, and cannot lie
#
# FOUR ARMS, and (b)–(d) are why this is a case and not a one-line assertion:
#   (a) a mistyped id refuses and leaves NO registered kanban worktree — the
#       property the pre-bootstrap probe exists for;
#   (b) ABLATION: (a) must be able to FAIL. The probe is disabled in the
#       sandbox's own copy and (a)'s worktree check is re-run — a green (a) over
#       a script whose probe never ran would be a green about nothing;
#   (c) FALSE-REFUSAL CONTROL: a card that IS on the trunk but absent from this
#       repo's CACHED origin/<trunk> must still MOVE. The probe reads a tracking
#       ref, so without its fetch-confirmation it refuses a card that exists —
#       worse than the worktree it saves. This arm reddens if anyone hoists the
#       fetch out of the condition chain;
#   (d) a probe that CANNOT ANSWER falls through instead of refusing, and the
#       refusal's own provenance line is what proves which read caught it.
# =============================================================================
case_move_issue_probe() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-100" sandbox chore "Sandbox probe test"
  publish_sandbox

  local out rc mi="$SB_WORK/scripts/move-issue.sh"
  kwt_registered() { git -C "$SB_WORK" worktree list --porcelain 2>/dev/null | grep -qF '.kanban-wt'; }
  kwt_clear() {
    git -C "$SB_WORK" worktree remove --force "$SB_WORK/.kanban-wt" >/dev/null 2>&1
    rm -rf "$SB_WORK/.kanban-wt"
    git -C "$SB_WORK" worktree prune >/dev/null 2>&1
  }

  # (a) THE PROPERTY.
  kwt_clear
  out="$( cd "$SB_WORK" && "$mi" "$SB_PREFIX-999" in_progress --role Dev --note x 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) the mover accepted a card that is on no board"
  printf '%s\n' "$out" | grep -q 'no file matching' \
    || cf "(a) the not-found refusal changed shape: $out"
  printf '%s\n' "$out" | grep -qi 'not yet pushed' \
    || cf "(a) the refusal lost the push-before-you-move cause: $out"
  kwt_registered \
    && cf "(a) a REFUSAL registered a kanban worktree — the probe is gone, or it now runs too late"
  [ -e "$SB_WORK/.kanban-wt" ] && cf "(a) a REFUSAL left a .kanban-wt/ directory behind"

  # (b) ABLATION — neuter the probe's condition in the sandbox's copy and re-run (a)'s
  #     worktree check, which must now FIRE. Self-asserting: an anchor that moved is a
  #     fixture failure, not a case failure (this file's own rule).
  kwt_clear
  # Keep a copy of the NEUTRALIZED sandbox script to restore from. Restoring from
  # $REAL_SCRIPTS instead — which is what this did — re-imports the adopter's tree
  # after the neutralizer removed it, so on a project that ran `kit-init --roles`
  # arms (c) and (d) ran against that project's role whitelist and (c) failed with
  # "--role must be …". Measured. The sandbox owns its scripts; nothing may reach
  # back past _kit_neutral_config for a copy.
  cp "$mi" "$SB_TMP/move-issue.neutral"
  grep -q '^if \[ "\$PROBE_ID_IS_GLOB" -eq 0 \] \\$' "$mi" \
    || _fixture_die "case_move_issue_probe(b): no probe condition to ablate in move-issue.sh — the anchor moved, so arm (a) above is unfalsifiable and this case proves nothing."
  perl -i -pe 's/^if \[ "\$PROBE_ID_IS_GLOB" -eq 0 \] \\$/if false \&\& [ "\$PROBE_ID_IS_GLOB" -eq 0 ] \\/' "$mi"
  grep -q '^if false && \[ "\$PROBE_ID_IS_GLOB" -eq 0 \] \\$' "$mi" \
    || _fixture_die "case_move_issue_probe(b): the ablation did not take."
  out="$( cd "$SB_WORK" && "$mi" "$SB_PREFIX-999" in_progress --role Dev --note x 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) the ablated mover accepted a nonexistent card"
  kwt_registered \
    || cf "(control) with the probe disabled the refusal STILL left no worktree — arm (a) is not measuring the probe: $out"
  cp "$SB_TMP/move-issue.neutral" "$mi"   # restore the NEUTRALIZED script for (c) and (d)
  grep -q '^if \[ "\$PROBE_ID_IS_GLOB" -eq 0 \] \\$' "$mi" \
    || _fixture_die "case_move_issue_probe: the restore did not put the un-ablated script back, so arms (c) and (d) would run against the disabled probe."

  # (c) FALSE-REFUSAL CONTROL. Put a card on the trunk WITHOUT it passing through this
  #     repo's tracking ref: commit and push it from a second clone. Both halves of the
  #     premise are asserted, because a control whose premise silently did not hold is
  #     the green that proves nothing.
  kwt_clear
  local other="$SB_TMP/other"
  git clone --quiet "$SB_ORIGIN" "$other" >/dev/null 2>&1
  git -C "$other" config user.email "test@sandbox.invalid" >/dev/null 2>&1
  git -C "$other" config user.name  "Sandbox Other"        >/dev/null 2>&1
  git -C "$other" config commit.gpgsign false              >/dev/null 2>&1
  sed "s/^id: $SB_PREFIX-100$/id: $SB_PREFIX-101/" \
    "$SB_WORK/progress/todo/$SB_PREFIX-100-sandbox.md" \
    > "$other/progress/todo/$SB_PREFIX-101-elsewhere.md"
  git -C "$other" add -A >/dev/null 2>&1
  MSG_OK=1 git -C "$other" commit -qm "[PM] $SB_PREFIX-101: minted in another clone" >/dev/null 2>&1
  git -C "$other" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  ORIGIN_PATHS="$(git -C "$SB_ORIGIN" ls-tree -r --name-only "$SB_TRUNK" 2>/dev/null)"
  printf '%s\n' "$ORIGIN_PATHS" | grep -q "$SB_PREFIX-101-elsewhere.md" \
    || _fixture_die "case_move_issue_probe(c): the second clone's push did not reach the bare trunk — the control has no premise."
  CACHED_PATHS="$(git -C "$SB_WORK" ls-tree -r --name-only "origin/$SB_TRUNK" 2>/dev/null)"
  printf '%s\n' "$CACHED_PATHS" | grep -q "$SB_PREFIX-101-elsewhere.md" \
    && _fixture_die "case_move_issue_probe(c): origin/$SB_TRUNK is already current here, so nothing in this arm exercises the stale-cache path."
  out="$( cd "$SB_WORK" && "$mi" "$SB_PREFIX-101" in_progress \
            --role Dev --note "moved from a stale cache" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] \
    || cf "(c) FALSE REFUSAL: a card that IS on the trunk was refused because our cached origin/$SB_TRUNK had not seen it (rc=$rc): $out"
  origin_has_path "progress/in_progress/$SB_PREFIX-101-elsewhere.md" \
    || cf "(c) the move did not land on the trunk"

  # (d) A PROBE THAT CANNOT ANSWER FALLS THROUGH — and the provenance line is the
  #     only thing that can tell the two reads apart, which is why it is asserted.
  kwt_clear
  git -C "$SB_WORK" update-ref -d "refs/remotes/origin/$SB_TRUNK" >/dev/null 2>&1
  out="$( cd "$SB_WORK" && "$mi" "$SB_PREFIX-998" in_progress --role Dev --note x 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(d) the mover accepted a nonexistent card with no tracking ref"
  printf '%s\n' "$out" | grep -q 'no file matching' \
    || cf "(d) the fall-through refusal changed shape: $out"
  printf '%s\n' "$out" | grep -q 'inside the kanban worktree' \
    || cf "(d) with an unreadable tracking ref the probe did not fall through to the worktree read: $out"

  finish "move-issue.sh: a not-found refusal creates no worktree (ablation-proven), never refuses a card the trunk actually carries, and falls through when it cannot read the ref"
  teardown
}

# =============================================================================
# CASE — finish-pr.sh happy path (squash-merge, delete branch, advance)
#
# It asserts the STATE (both refs gone) AND THE CLAIM (what the board note says
# happened). The claim half is not decoration: a hard-coded "branch deleted."
# composed a hundred lines before any attempt once let eight consecutive landings
# log a deletion that had not happened, with no case reddening. The conditions
# this case does NOT have — the branch held by a second worktree, and a delete
# that cannot succeed — are the three sibling cases below.
# =============================================================================
case_finish_pr_happy() {
  cf_reset
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-777" sandbox chore "Happy path" "feature/$SB_PREFIX-777-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-777" work CHANGE.txt

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-777" 2>&1 )"; rc=$?

  [ "$rc" -eq 0 ] || cf "finish-pr exited $rc (expected 0): $out"
  git -C "$SB_WORK" rev-parse --verify --quiet "refs/heads/feature/$SB_PREFIX-777-work" >/dev/null 2>&1 \
    && cf "local branch not deleted"
  [ -z "$(git -C "$SB_WORK" ls-remote --heads origin "feature/$SB_PREFIX-777-work" 2>/dev/null)" ] \
    || cf "remote branch not deleted"
  origin_has_path "progress/qa_complete/$SB_PREFIX-777-sandbox.md" \
    || cf "issue not advanced to qa_complete/ on the trunk"
  origin_has_path "CHANGE.txt" || cf "squash-merged change not on the trunk"

  # THE CLAIM. These two strings can only be produced by the arms that MEASURED a
  # confirmed deletion — a bare substring match on a pre-composed note proved
  # nothing, which is exactly how the old defect hid.
  origin_file_contains "progress/qa_complete/$SB_PREFIX-777-sandbox.md" "local branch deleted" \
    || cf "board note does not report the local delete it performed"
  origin_file_contains "progress/qa_complete/$SB_PREFIX-777-sandbox.md" "branch deleted (confirmed gone)" \
    || cf "board note does not report the CONFIRMED remote delete it performed"
  printf '%s' "$out" | grep -q "confirmed gone by ls-remote" \
    || cf "run output does not show the remote delete being confirmed by re-measurement"

  finish "finish-pr.sh happy path: squash-merge + delete branch + advance, and the board note reports BOTH deletes truthfully"
  teardown
}

# =============================================================================
# CASE — THE POST-MERGE PASS LINE NAMES THE REF IT READ, AND THE MACHINE LINE
#        DOES NOT.
#
# An instrument that names its operand when it complains must name it when it
# clears: the FAIL branch already says which branch may be red, and the PASS branch
# used to say only that something passed. On the clearing branch that asymmetry is
# the expensive direction, because it is the one that errs toward false confidence.
#
# THE SECOND ASSERTION IS THE CANARY, and without it the first is not a control.
# `POST_MERGE_GATE: PASS` is a MACHINE CONTRACT — an automation greps that exact
# token — so the fix must land on the human line and nowhere else. A ref appended
# there would break every consumer while making assertion 1 pass.
#
# AND THE FIRST ASSERTION IS SCOPED TO THE PASS LINE ITSELF, not to the run output.
# The "Done. … landed on '<trunk>'" line above already carries the ref, so a bare
# grep for the trunk name over `$out` passes before the fix and proves nothing.
# =============================================================================
case_finish_pr_post_merge_names_its_ref() {
  cf_reset
  make_sandbox
  # The 6th argument is the card's `branch:` frontmatter, and finish-pr.sh reads it to
  # find what to merge. Omitting it leaves the card saying `n/a`, and the run dies with
  # "local branch 'n/a' not found" — a fixture gap that reads like a tool defect.
  seed_issue dev_complete "$SB_PREFIX-140" postmerge chore "Post-merge ref naming" "feature/$SB_PREFIX-140-postmerge"
  publish_sandbox
  seed_branch "$SB_PREFIX-140" postmerge "postmerge.txt"

  local out rc pass_line
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" ./scripts/finish-pr.sh "$SB_PREFIX-140" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "finish-pr exited $rc on the happy path: $out"

  # (1) The HUMAN line names the ref — read that line alone, not the whole run.
  pass_line="$(printf '%s\n' "$out" | grep 'post-merge verify --quick: PASS' | head -1)"
  [ -n "$pass_line" ] \
    || cf "no 'post-merge verify --quick: PASS' line in the run output — the gate did not reach its clearing branch: $out"
  printf '%s\n' "$pass_line" | grep -q "$SB_TRUNK" \
    || cf "the post-merge PASS line does not name the ref it read (the FAIL line does; the clearing branch is the direction that errs toward false confidence): $pass_line"

  # (2) THE CANARY: the machine line is still exactly its token, with no ref appended.
  printf '%s\n' "$out" | grep -qx 'POST_MERGE_GATE: PASS' \
    || cf "the machine line is no longer exactly 'POST_MERGE_GATE: PASS' — an automation greps that token, so a ref appended HERE breaks every consumer: $out"

  finish "finish-pr.sh: the post-merge PASS line names the ref it read, and the machine line POST_MERGE_GATE: PASS stays exactly that token"
  teardown
}

# =============================================================================
# CASE — the branch is checked out in a SECOND WORKTREE. This is the field
# condition: a landing run from a linked worktree that holds the branch, where
# the local delete correctly SKIPS — and the board note still claimed it. The
# skip is correct behaviour and stays; the claim must not.
# =============================================================================
case_finish_pr_second_worktree() {
  cf_reset
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-779" sandbox chore "Worktree holds the branch" "feature/$SB_PREFIX-779-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-779" work WT.txt

  git -C "$SB_WORK" worktree add "$SB_TMP/wt2" "feature/$SB_PREFIX-779-work" --quiet >/dev/null 2>&1 \
    || cf "could not create the second worktree (test setup)"

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-779" 2>&1 )"; rc=$?

  # The landing still succeeds: a branch a worktree holds is residue, not failure.
  [ "$rc" -eq 0 ] || cf "finish-pr exited $rc (expected 0 — the landing succeeded): $out"
  origin_has_path "WT.txt" || cf "squash-merged change not on the trunk"
  origin_has_path "progress/qa_complete/$SB_PREFIX-779-sandbox.md" || cf "issue not advanced to qa_complete/"
  # The local ref is PRESERVED (never force-delete a checked-out branch)...
  git -C "$SB_WORK" rev-parse --verify --quiet "refs/heads/feature/$SB_PREFIX-779-work" >/dev/null 2>&1 \
    || cf "local branch was deleted while a worktree held it — the skip was not preserved"
  # ...the operator is TOLD, and told WHICH worktree...
  printf '%s' "$out" | grep -q "checked out in a worktree" \
    || cf "run output does not say the local branch was kept because a worktree holds it"
  printf '%s' "$out" | grep -qF "$SB_TMP/wt2" \
    || cf "run output does not name the worktree that holds the branch"
  # ...and the remote arm is INDEPENDENT: it fires anyway and succeeds.
  [ -z "$(git -C "$SB_WORK" ls-remote --heads origin "feature/$SB_PREFIX-779-work" 2>/dev/null)" ] \
    || cf "remote branch not deleted (the remote arm must not be gated on the local one)"
  # THE CLAIM: the note must NOT say the local branch was deleted.
  origin_file_contains "progress/qa_complete/$SB_PREFIX-779-sandbox.md" "LOCAL BRANCH KEPT" \
    || cf "board note does not report that the local branch was kept"
  origin_file_contains "progress/qa_complete/$SB_PREFIX-779-sandbox.md" "local branch deleted" \
    && cf "board note FALSELY claims the local branch was deleted"

  finish "finish-pr.sh with the branch held by a second worktree: local skip preserved, remote still deleted, and the note does NOT claim the local delete"
  teardown
}

# =============================================================================
# CASE — the remote REFUSES the delete (receive.denyDeletes). Forge-agnostic: a
# plain bare repo declining a deletion. Before the delete arms surfaced git's own
# stderr this was indistinguishable from success in any filtered log.
# =============================================================================
case_finish_pr_remote_delete_refused() {
  cf_reset
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-780" sandbox chore "Remote refuses the delete" "feature/$SB_PREFIX-780-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-780" work REFUSE.txt

  git -C "$SB_ORIGIN" config receive.denyDeletes true >/dev/null 2>&1

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-780" 2>&1 )"; rc=$?

  # NON-FATAL by design: the merge has landed and been pushed, so this is residue.
  [ "$rc" -eq 0 ] || cf "finish-pr exited $rc (expected 0 — a refused delete must not read as a failed landing): $out"
  origin_has_path "REFUSE.txt" || cf "squash-merged change not on the trunk"
  origin_has_path "progress/qa_complete/$SB_PREFIX-780-sandbox.md" || cf "issue not advanced to qa_complete/"
  [ -n "$(git -C "$SB_WORK" ls-remote --heads origin "feature/$SB_PREFIX-780-work" 2>/dev/null)" ] \
    || cf "test setup: receive.denyDeletes did not actually refuse the delete"
  printf '%s' "$out" | grep -q "WARNING: could NOT delete remote branch" \
    || cf "a refused remote delete was not reported loudly"
  printf '%s' "$out" | grep -qE 'remote rejected|denyDeletes|deletion prohibited|pre-receive' \
    || cf "git's own rejection text was not surfaced (still silenced?)"
  printf '%s' "$out" | grep -q "push origin --delete" \
    || cf "the report does not name the command that finishes the job"
  git -C "$SB_WORK" rev-parse --verify --quiet "refs/heads/feature/$SB_PREFIX-780-work" >/dev/null 2>&1 \
    && cf "local branch not deleted (the local arm must not be gated on the remote one)"
  origin_file_contains "progress/qa_complete/$SB_PREFIX-780-sandbox.md" "NOT DELETED (the push was refused)" \
    || cf "board note does not report the refused remote delete"
  origin_file_contains "progress/qa_complete/$SB_PREFIX-780-sandbox.md" "branch deleted (confirmed gone)" \
    && cf "board note FALSELY claims a confirmed remote delete"

  finish "finish-pr.sh with a remote that refuses deletes: loud, git's own error surfaced, exit still 0, and the note names the survivor"
  teardown
}

# =============================================================================
# CASE — THE EXACT FIELD SHAPE: a delete that reports SUCCESS and does not stick.
# Observed once for real (push exited 0, the ref was still advertised; a
# controlled re-run reproduced it — deleted, absent for 150s, then back at the
# identical SHA). An exit code cannot see that; only re-measuring the remote can.
# Here a post-receive hook restores any deleted ref, which is the same observable.
# =============================================================================
case_finish_pr_remote_delete_resurrected() {
  cf_reset
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-781" sandbox chore "Remote resurrects the ref" "feature/$SB_PREFIX-781-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-781" work RESURRECT.txt
  local tip; tip="$(git -C "$SB_WORK" rev-parse "feature/$SB_PREFIX-781-work")"

  cat > "$SB_ORIGIN/hooks/post-receive" <<'HOOK'
#!/bin/sh
# Restore any ref this push deleted — the observable shape of a mirror or sync
# pushing a branch back into the remote after a successful delete.
while read -r old new ref; do
  case "$new" in
    0000000000000000000000000000000000000000) git update-ref "$ref" "$old" ;;
  esac
done
HOOK
  chmod +x "$SB_ORIGIN/hooks/post-receive"

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-781" 2>&1 )"; rc=$?

  [ "$rc" -eq 0 ] || cf "finish-pr exited $rc (expected 0 — the landing succeeded): $out"
  origin_has_path "RESURRECT.txt" || cf "squash-merged change not on the trunk"
  local still; still="$(git -C "$SB_WORK" ls-remote --heads origin "feature/$SB_PREFIX-781-work" 2>/dev/null)"
  printf '%s' "$still" | grep -q "$tip" \
    || cf "test setup: the post-receive hook did not resurrect the ref (got: '$still')"
  printf '%s' "$out" | grep -q "SURVIVED a delete that reported SUCCESS" \
    || cf "an exit-0 delete whose ref survived was NOT caught — the fix relies on re-measuring, not the exit code"
  printf '%s' "$out" | grep -q "still advertises the ref" \
    || cf "the report does not show the surviving ref it measured"
  printf '%s' "$out" | grep -q "The LANDING IS FINE" \
    || cf "the report does not distinguish residue from a failed landing"
  origin_file_contains "progress/qa_complete/$SB_PREFIX-781-sandbox.md" "STILL PRESENT after a delete that reported success" \
    || cf "board note does not report the surviving remote branch"
  origin_file_contains "progress/qa_complete/$SB_PREFIX-781-sandbox.md" "branch deleted (confirmed gone)" \
    && cf "board note FALSELY claims a confirmed remote delete"

  finish "finish-pr.sh when the remote accepts a delete then restores the ref: caught by re-measurement, and the note never claims the delete"
  teardown
}

# =============================================================================
# CASE — a RED pre-merge gate aborts, destroying nothing.
# =============================================================================
# THE POST-REFUSAL CONTRACT, ONE AUTHORING SITE. A refusal must leave four things untouched, and
# these legs asserted three different subsets of them. The gap that mattered: the two arms whose
# whole claim is "refused BEFORE any destructive step" checked the issue and the merge and NEITHER
# BRANCH — the destructive step most worth checking, absent from the only legs written to prove it
# did not happen.
#
# THE MARKER IS OPTIONAL, AND THAT IS NOT A CONVENIENCE. A leg with no commit on its branch (the
# empty-merge case) has nothing that COULD have merged, so asserting "the change did not land" there
# would be a check that cannot fail. Inapplicable and missing are different, and collapsing them is
# how a subset difference gets read as a gap.
#
#   assert_landing_untouched <label> <id> <slug> <branch> [<merge marker>]
assert_landing_untouched() {
  local lab="$1" id="$2" slug="$3" br="$4" marker="${5:-}"
  git -C "$SB_WORK" rev-parse --verify --quiet "refs/heads/$br" >/dev/null 2>&1 \
    || cf "$lab local branch '$br' was destroyed — a refusal must leave it intact"
  [ -n "$(git -C "$SB_WORK" ls-remote --heads origin "$br" 2>/dev/null)" ] \
    || cf "$lab remote branch '$br' was deleted — a refusal must leave it intact"
  origin_has_path "progress/dev_complete/$id-$slug.md" \
    || cf "$lab issue left dev_complete/ — a refusal must not advance it"
  if [ -n "$marker" ]; then
    origin_has_path "$marker" && cf "$lab '$marker' reached the trunk — a refusal must not merge"
  fi
  return 0   # the last command above is a `&&` whose false branch is the PASSING one
}

case_finish_pr_premerge_red() {
  cf_reset
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-778" sandbox chore "Pre-merge red" "feature/$SB_PREFIX-778-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-778" work CHANGE.txt

  local out rc
  out="$( cd "$SB_WORK" && FINISH_PR_TEST_ALLOW_STUB=1 FINISH_PR_VERIFY_CMD=true FINISH_PR_PREMERGE_CMD=false \
            "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-778" 2>&1 )"; rc=$?

  [ "$rc" -ne 0 ] || cf "expected nonzero exit on a red pre-merge gate, got 0: $out"
  assert_landing_untouched "(red pre-merge gate)" "$SB_PREFIX-778" sandbox \
    "feature/$SB_PREFIX-778-work" CHANGE.txt

  finish "finish-pr.sh red pre-merge gate aborts (no merge/push/delete/advance)"
  teardown
}

# =============================================================================
# CASE — an EMPTY merge aborts. (An earlier version fell through to branch
# deletion + advance, destroying a mistyped branch with no landed code.)
# =============================================================================
case_finish_pr_empty_merge() {
  cf_reset
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-782" sandbox chore "Empty merge" "feature/$SB_PREFIX-782-empty"
  publish_sandbox
  git -C "$SB_WORK" branch "feature/$SB_PREFIX-782-empty" "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/$SB_PREFIX-782-empty" --quiet >/dev/null 2>&1

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-782" 2>&1 )"; rc=$?

  [ "$rc" -ne 0 ] || cf "expected nonzero exit on an empty merge, got 0: $out"
  # NO MERGE MARKER: this branch is created off the trunk with no commit, so nothing could have
  # merged and asserting otherwise would be a check that cannot fail.
  assert_landing_untouched "(empty merge)" "$SB_PREFIX-782" sandbox \
    "feature/$SB_PREFIX-782-empty"

  finish "finish-pr.sh empty-merge aborts (no branch destruction, no advance)"
  teardown
}

# =============================================================================
# CASE — THE GATE-EXECUTABLE HARDENING (the fabricated-stub hole, used once in
# earnest to force a landing through a red suite). One case, four legs:
#   (a) a caller-supplied FINISH_PR_PREMERGE_CMD is REFUSED on the production
#       path (no marker) before ANY destructive step;
#   (b) a genuine worktree's TRACKED scripts/verify.sh (green) is ACCEPTED via
#       --worktree — the legitimate worktree-QA capability, preserved;
#   (c) --worktree pointed at a scratch dir carrying a FABRICATED verify.sh is
#       REFUSED (it is not a git worktree of this repo);
#   (d) the sandbox stub injection STILL works, but ONLY behind the explicit
#       test-only marker.
# =============================================================================
# =============================================================================
# CASE — THE LANDING GATE MUST BE THE COMMITTED verify.sh AT THE REVISION BEING
# LANDED — AND THIS CASE RUNS WITHOUT THE STUB MARKER.
#
# THAT IS THE POINT OF IT. The other finish-pr cases run with the `FPR_STUB` array
# (FINISH_PR_TEST_ALLOW_STUB=1 + the two command stubs) — all of them except this one and
# `case_finish_pr_gate_absent_says_write_one`, each of which says "NO FPR_STUB" at its own
# site and why. Derive it rather than trusting a number here; this sentence said "seven"
# and was true on the day it was written. The revision check is wrapped in
# `if [ "$ALLOW_STUB" != "true" ]` — so those cases are green partly BECAUSE they
# bypass the thing this one exists to hold. A guard that every existing case skips
# is a guard nothing measures; running unmarked is the whole design of this case,
# not an incidental detail of it.
#
# The defect: the gate ran whatever scripts/verify.sh happened to be in the gate
# checkout, which on the default path is the main checkout — and that is the TRUNK in
# the common case, not the branch being landed. So the gate proved something about a
# tree that is not shipping, and reported it as a landing precondition.
#
# THE DIRECTIONS, AND THE CONFORMING ONE IS WHAT STOPS THE FIX FROM BEING AN
# UNCONDITIONAL REFUSAL — that would pass every refusal arm and break every landing in
# the kit. This said "THREE DIRECTIONS" and enumerated (i)-(iii); arm (iv) was added
# afterwards, out of order, and the count above it did not grow. The arms are labelled
# `# --- (n)` in the body and the finish string reports all of them; read those rather
# than a number here:
#   (i)   checkout on the trunk, branch elsewhere → REFUSE, naming the mismatch, and
#         leave the branch and the issue exactly where they were;
#   (ii)  checkout ON the branch but verify.sh locally modified → REFUSE, naming the
#         modification (the revisions match, so only the cleanliness arm can catch it);
#   (iii) checkout on the branch, gate committed and unmodified → LANDS.
# =============================================================================
case_finish_pr_gate_revision() {
  cf_reset
  local out rc br

  # --- (i) the default path from a trunk checkout: the revision mismatch ------
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-780" revmm chore "Revision mismatch" "feature/$SB_PREFIX-780-revmm"
  publish_sandbox
  seed_branch "$SB_PREFIX-780" revmm CHANGE780.txt      # leaves the checkout on the trunk
  br="feature/$SB_PREFIX-780-revmm"
  [ "$(git -C "$SB_WORK" symbolic-ref --short HEAD)" = "$SB_TRUNK" ] \
    || cf "(control) the checkout is not on the trunk, so (i) is not testing the mismatch"

  # NO FPR_STUB. Deliberately.
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-780" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(i) finish-pr LANDED from a trunk checkout with the branch elsewhere — the gate ran against a tree that is not shipping: $out"
  printf '%s\n' "$out" | grep -qi 'NOT AT THE REVISION BEING LANDED' \
    || cf "(i) the refusal does not name the revision mismatch as the cause: $out"
  printf '%s\n' "$out" | grep -qi 'Refusing BEFORE any destructive step' \
    || cf "(i) the refusal does not state that it refused before anything destructive: $out"
  # REFUSED MEANS NOTHING HAPPENED — the assertions that separate "refused" from
  # "refused after doing some of it". Exit code alone cannot tell those apart.
  git -C "$SB_WORK" rev-parse --verify --quiet "refs/heads/$br" >/dev/null 2>&1 \
    || cf "(i) the local branch was deleted during a refusal"
  [ -n "$(git -C "$SB_WORK" ls-remote --heads origin "$br" 2>/dev/null)" ] \
    || cf "(i) the remote branch was deleted during a refusal"
  origin_has_path "progress/dev_complete/$SB_PREFIX-780-revmm.md" \
    || cf "(i) the issue left dev_complete/ on the trunk during a refusal"
  origin_has_path "CHANGE780.txt" \
    && cf "(i) the branch's change reached the trunk during a refusal — it squash-merged"
  teardown

  # --- (ii) on the branch, but the gate is locally modified ------------------
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-781" dirtygate chore "Dirty gate" "feature/$SB_PREFIX-781-dirtygate"
  publish_sandbox
  seed_branch "$SB_PREFIX-781" dirtygate CHANGE781.txt
  br="feature/$SB_PREFIX-781-dirtygate"
  git -C "$SB_WORK" checkout "$br" --quiet >/dev/null 2>&1 \
    || cf "(control) could not check out $br for (ii)"
  printf '\n# a local edit that was never committed\n' >> "$SB_WORK/scripts/verify.sh"
  git -C "$SB_WORK" diff --quiet HEAD -- scripts/verify.sh \
    && cf "(control) scripts/verify.sh is NOT locally modified, so (ii) tests nothing"

  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-781" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(ii) finish-pr LANDED with a locally-modified gate — the gate that ran is not the one that ships: $out"
  printf '%s\n' "$out" | grep -qi 'LOCALLY MODIFIED' \
    || cf "(ii) the refusal does not name the modification as the cause (the revisions MATCH here, so only the cleanliness arm can catch it): $out"
  git -C "$SB_WORK" rev-parse --verify --quiet "refs/heads/$br" >/dev/null 2>&1 \
    || cf "(ii) the local branch was deleted during a refusal"
  origin_has_path "progress/dev_complete/$SB_PREFIX-781-dirtygate.md" \
    || cf "(ii) the issue left dev_complete/ during a refusal"
  teardown

  # --- (iv) on the branch, at the right revision, gate present and executable,
  #          but UNTRACKED at that revision ----------------------------------
  #
  # THE ONE ARM OF FIVE THAT NOTHING REACHED, and it stayed uncovered because its
  # fixture is the only awkward one: the other four are a rm, a chmod, a checkout and a
  # sed. Awkward is not the same as unimportant — a verify.sh that exists, runs, and sits
  # at the right revision but ships in no commit is a gate the committed tree does not
  # contain, and it passes every other arm.
  #
  # `git rm --cached` is the whole trick: it removes the file from the INDEX while
  # leaving it on disk, executable, unmodified. Committing that on the branch keeps
  # HEAD and the branch tip in agreement, so the revision arm above cannot fire.
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-783" untracked chore "Untracked gate" "feature/$SB_PREFIX-783-untracked"
  publish_sandbox
  seed_branch "$SB_PREFIX-783" untracked CHANGE783.txt
  br="feature/$SB_PREFIX-783-untracked"
  git -C "$SB_WORK" checkout "$br" --quiet >/dev/null 2>&1 \
    || cf "(control) could not check out $br for (iv)"
  git -C "$SB_WORK" rm --cached --quiet scripts/verify.sh >/dev/null 2>&1 \
    || cf "(control) could not un-track scripts/verify.sh for (iv)"
  sbcommit -q -m "un-track the gate" >/dev/null 2>&1

  # ── THE FIXTURE IS PROVEN TO ISOLATE THIS ARM, and this block is the point of the
  #    leg rather than a nicety: four of the five arms share a refusal prefix and an
  #    exit code, so a fixture that accidentally trips a NEIGHBOUR looks identical from
  #    the outside and would ship as coverage of an arm it never touched.
  [ -e "$SB_WORK/scripts/verify.sh" ] \
    || cf "(control iv) verify.sh is absent — this would trip the MISSING arm, not the tracked-ness one"
  [ -x "$SB_WORK/scripts/verify.sh" ] \
    || cf "(control iv) verify.sh is not executable — this would trip the NOT EXECUTABLE arm"
  [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$(git -C "$SB_WORK" rev-parse "refs/heads/$br")" ] \
    || cf "(control iv) HEAD and the branch tip disagree — this would trip the REVISION arm"
  git -C "$SB_WORK" cat-file -e "HEAD:scripts/verify.sh" 2>/dev/null \
    && cf "(control iv) scripts/verify.sh IS tracked at HEAD — the un-tracking did not take and this leg tests nothing"

  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-783" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] \
    || cf "(iv) finish-pr LANDED with an UNTRACKED gate — it ran a file that ships in no commit: $out"
  printf '%s\n' "$out" | grep -qi 'NOT TRACKED' \
    || cf "(iv) the refusal does not name tracked-ness as the cause: $out"
  # …AND NOT ITS NEIGHBOURS. The exit code and the prefix cannot tell these apart.
  printf '%s\n' "$out" | grep -qi 'NOT AT THE REVISION BEING LANDED' \
    && cf "(iv) the refusal blames the REVISION arm — the fixture reached a neighbour, so this leg is coverage of an arm it never touched"
  printf '%s\n' "$out" | grep -qi 'LOCALLY MODIFIED' \
    && cf "(iv) the refusal blames the MODIFICATION arm — the fixture reached a neighbour"
  printf '%s\n' "$out" | grep -qiE 'MISSING —|NOT EXECUTABLE' \
    && cf "(iv) the refusal blames one of the two absent-gate arms — the fixture reached a neighbour"
  # REFUSED MEANS NOTHING HAPPENED.
  git -C "$SB_WORK" rev-parse --verify --quiet "refs/heads/$br" >/dev/null 2>&1 \
    || cf "(iv) the local branch was deleted during a refusal"
  origin_has_path "progress/dev_complete/$SB_PREFIX-783-untracked.md" \
    || cf "(iv) the issue left dev_complete/ during a refusal"
  origin_has_path "CHANGE783.txt" \
    && cf "(iv) the branch's change reached the trunk during a refusal"
  teardown

  # --- (iii) the conforming posture still lands, unmarked --------------------
  # Without this, an unconditional refusal passes (i) and (ii) and breaks the kit.
  # Note there is no stub here either: the REAL scripts/verify.sh --quick runs, and
  # it is green because make_sandbox declared a green `select` gate in it.
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-782" conform chore "Conforming" "feature/$SB_PREFIX-782-conform"
  publish_sandbox
  seed_branch "$SB_PREFIX-782" conform CHANGE782.txt
  br="feature/$SB_PREFIX-782-conform"
  git -C "$SB_WORK" checkout "$br" --quiet >/dev/null 2>&1 \
    || cf "(control) could not check out $br for (iii)"
  [ -z "$(git -C "$SB_WORK" status --porcelain -- scripts/verify.sh)" ] \
    || cf "(control) scripts/verify.sh is dirty in (iii), which would make it test (ii) again"

  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-782" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] \
    || cf "(iii) the CONFORMING posture was refused, unmarked — the revision check is unconditional and no landing can pass it: $out"
  origin_has_path "progress/qa_complete/$SB_PREFIX-782-conform.md" \
    || cf "(iii) the conforming landing did not advance the issue: $out"
  origin_has_path "CHANGE782.txt" || cf "(iii) the conforming landing did not squash-merge the change: $out"

  finish "finish-pr landing gate, run WITHOUT the stub marker: a trunk checkout with the branch elsewhere REFUSES on the revision mismatch, a locally-modified gate REFUSES on the modification, a gate that is present, executable and at the right revision but UNTRACKED there REFUSES on tracked-ness and on nothing else, all three leaving the branch and the issue untouched — and the conforming posture still lands"
  teardown
}

# THE GATE-PROVENANCE REFUSAL HAS FIVE ARMS AND ONLY TWO WERE EXERCISED. `NOT AT THE REVISION` and
# `LOCALLY MODIFIED` had cases; MISSING, NOT EXECUTABLE and NOT TRACKED had none. This case takes the
# first two, because they are the arms that now carry the write-your-gate advice — advice that lived
# for a while in a branch NO INPUT COULD ENTER, so it had never printed to anyone.
#
# WHY THE ADVICE MATTERS ENOUGH TO ASSERT: an adopter meeting this refusal has no gate at all. The
# other three arms mean "your gate is the wrong one" and their remedy is a checkout; these two mean
# "there is no gate" and their remedy is to write one. Printing the checkout advice to someone with
# no gate sends them to fix a thing that is not their problem.
case_finish_pr_gate_absent_says_write_one() {
  cf_reset
  local out rc br

  # --- (a) verify.sh MISSING from the gate checkout ---------------------------
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-795" nogate chore "No gate at all" "feature/$SB_PREFIX-795-nogate"
  publish_sandbox
  seed_branch "$SB_PREFIX-795" nogate CHANGE795.txt
  br="feature/$SB_PREFIX-795-nogate"
  git -C "$SB_WORK" checkout "$br" --quiet >/dev/null 2>&1
  rm -f "$SB_WORK/scripts/verify.sh"
  [ ! -e "$SB_WORK/scripts/verify.sh" ] \
    || cf "(control) scripts/verify.sh still exists, so (a) is not testing a MISSING gate"

  # NO FPR_STUB: the provenance block only runs unmarked.
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-795" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) finish-pr LANDED with no gate runner at all: $out"
  printf '%s\n' "$out" | grep -qi 'MISSING' \
    || cf "(a) the refusal does not name the gate as MISSING: $out"
  printf '%s\n' "$out" | grep -qF -- '--gate-command' \
    || cf "(a) the refusal does not tell an adopter with NO gate how to get one — that advice sat in an unreachable branch for a while, and this assertion is what keeps it on a path that runs: $out"
  printf '%s\n' "$out" | grep -qi 'check the branch out here' \
    && cf "(a) the refusal offers the CHECKOUT remedy to someone who has no gate at all — that is the other arms' advice and it sends them to fix the wrong thing: $out"
  assert_landing_untouched "(a)" "$SB_PREFIX-795" nogate "$br" CHANGE795.txt
  teardown

  # --- (b) verify.sh present but NOT EXECUTABLE -------------------------------
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-796" noexec chore "Gate not executable" "feature/$SB_PREFIX-796-noexec"
  publish_sandbox
  seed_branch "$SB_PREFIX-796" noexec CHANGE796.txt
  br="feature/$SB_PREFIX-796-noexec"
  git -C "$SB_WORK" checkout "$br" --quiet >/dev/null 2>&1
  chmod -x "$SB_WORK/scripts/verify.sh"
  [ ! -x "$SB_WORK/scripts/verify.sh" ] && [ -e "$SB_WORK/scripts/verify.sh" ] \
    || cf "(control) scripts/verify.sh is not in the present-but-unexecutable state (b) needs"

  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-796" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) finish-pr LANDED with a non-executable gate runner: $out"
  printf '%s\n' "$out" | grep -qi 'NOT EXECUTABLE' \
    || cf "(b) the refusal does not name the gate as NOT EXECUTABLE: $out"
  printf '%s\n' "$out" | grep -qF -- '--gate-command' \
    || cf "(b) the refusal does not carry the write-your-gate advice: $out"
  assert_landing_untouched "(b)" "$SB_PREFIX-796" noexec "$br" CHANGE796.txt

  finish "finish-pr: a MISSING or NON-EXECUTABLE gate refuses before anything destructive and tells an adopter how to GET a gate, not how to move their checkout"
  teardown
}

case_finish_pr_gate_hardening() {
  cf_reset
  local out rc

  # --- (a) production path REFUSES a fabricated premerge command --------------
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-790" sandbox chore "Fabricated stub" "feature/$SB_PREFIX-790-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-790" work CHANGE.txt
  printf '#!/usr/bin/env bash\necho PASS\nexit 0\n' > "$SB_TMP/fabricated-gate.sh"
  chmod +x "$SB_TMP/fabricated-gate.sh"

  out="$( cd "$SB_WORK" && FINISH_PR_PREMERGE_CMD="$SB_TMP/fabricated-gate.sh" \
            "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-790" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) fabricated stub was ACCEPTED (expected a nonzero refusal), got 0"
  printf '%s' "$out" | grep -qi 'FINISH_PR_TEST_ALLOW_STUB\|refus' \
    || cf "(a) the refusal did not name why it was refused: $out"
  assert_landing_untouched "(a)" "$SB_PREFIX-790" sandbox "feature/$SB_PREFIX-790-work" CHANGE.txt
  teardown

  # --- (b) a genuine worktree's tracked verify.sh (green) is ACCEPTED ---------
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-791" sandbox chore "Worktree accept" "feature/$SB_PREFIX-791-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-791" work CHANGE.txt
  git -C "$SB_WORK" worktree add "$SB_TMP/wt-791" "feature/$SB_PREFIX-791-work" --quiet >/dev/null 2>&1

  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-791" \
            --worktree "$SB_TMP/wt-791" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) the genuine-worktree accept path exited $rc (expected 0): $out"
  origin_has_path "progress/qa_complete/$SB_PREFIX-791-sandbox.md" \
    || cf "(b) issue not advanced to qa_complete/ (the landing did not proceed)"
  origin_has_path "CHANGE.txt" || cf "(b) squash-merged change not on the trunk"
  git -C "$SB_WORK" worktree remove --force "$SB_TMP/wt-791" >/dev/null 2>&1
  teardown

  # --- (c) --worktree at a scratch dir with a FABRICATED verify.sh is REFUSED --
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-792" sandbox chore "Scratch worktree" "feature/$SB_PREFIX-792-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-792" work CHANGE.txt
  mkdir -p "$SB_TMP/scratch/scripts"
  printf '#!/usr/bin/env bash\necho "fabricated: PASS"\nexit 0\n' > "$SB_TMP/scratch/scripts/verify.sh"
  chmod +x "$SB_TMP/scratch/scripts/verify.sh"

  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-792" \
            --worktree "$SB_TMP/scratch" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(c) a scratch-dir fabricated verify.sh was ACCEPTED (expected a refusal), got 0"
  assert_landing_untouched "(c)" "$SB_PREFIX-792" sandbox "feature/$SB_PREFIX-792-work" CHANGE.txt
  teardown

  # --- (d) the marker + stub path still works --------------------------------
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-793" sandbox chore "Marker stub" "feature/$SB_PREFIX-793-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-793" work CHANGE.txt
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-793" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(d) the marker+stub path exited $rc (expected 0 — sandbox injection must survive): $out"
  origin_has_path "progress/qa_complete/$SB_PREFIX-793-sandbox.md" \
    || cf "(d) marker+stub did not land the issue to qa_complete/"

  finish "finish-pr gate hardening: fabricated stub REFUSED (a), genuine --worktree ACCEPTED (b), scratch-dir --worktree REFUSED (c), marker stub survives (d)"
  teardown
}

# =============================================================================
# CASE — archive.sh --apply indexes + moves to done/
# =============================================================================
# =============================================================================
# CASE — A ONE-MEMBER ROLE TAG REFUSES BEFORE IT MUTATES.
#
# Three shipped scripts commit under a role tag that is ONE MEMBER of the role set:
# archive.sh's sweep, subtask.sh's create arm, finish-pr.sh's squash. They were
# hardcoded, so `kit-init --roles` — a documented, supported invocation — left them
# naming a seat the project no longer declares. The initializer correctly cannot stamp
# them: it rewrites the whole alternation, and one member does not contain it. So the
# kit's own tooling manufactured the breakage.
#
# WHY THE EXIT CODE IS NOT THE ASSERTION. Without the guard, archive.sh still exits
# nonzero — the hook rejects the commit and `set -e` aborts. A case that checked only
# `rc -ne 0` would PASS against the defect. The whole content of the fix is WHICH SIDE
# of the mutation the refusal lands on.
#
# WHAT THE REDDENING MUTATION ACTUALLY PROVES — measured, and NOT what was predicted
# when this case was drafted. Deleting the guard does NOT move the card on the trunk:
# the sweep git-mv's inside the kanban worktree, the commit fails, and nothing is
# pushed, so both trunk assertions still hold. What fails is the RESTORE CONTROL at the
# bottom: the refused run leaves uncommitted state in the SHARED worktree, and the very
# next board operation — with a perfectly legal role tag — dies on
# "the kanban worktree has uncommitted changes". So the damage this guard prevents is
# not a bad commit; it is a POISONED WORKTREE that breaks the next operation, in
# somebody else's lane, with an error naming neither the role nor the sweep that caused
# it. That is the documented failure mode, reproduced end to end.
#
# The two trunk assertions are kept anyway: they are the ones that would catch a variant
# where the mv DID reach the trunk, which no other assertion here would notice.
#
# THE NARROWING GOES INTO THE HOOK, never into the knob. Setting ARCHIVE_ROLE would
# only prove the knob is read; narrowing the declared set is what proves the tag is
# CHECKED against it.
# =============================================================================
# =============================================================================
# CASE — A CONTRADICTORY --apply/--dry-run PAIR REFUSES, IN EITHER ORDER.
#
# archive.sh inspected `$1` ALONE — no loop, no shift, no `$#`. So every argument after
# the first was silently discarded, and one of the things it discarded was a hedge.
# Measured: `--apply --dry-run` set DRY_RUN=false and swept, committed and PUSHED to the
# trunk with `--dry-run` thrown away; the reverse order previewed and threw `--apply`
# away. Order-dependent, opposite outcomes, no warning — and `--apply --dry-run` is
# exactly the belt-and-braces spelling an operator who is unsure reaches for.
#
# THE EXIT CODE IS NOT THE ASSERTION. This case reads the BOARD, the local HEAD and the
# REMOTE, because the difference between the two orders was a push to the trunk.
#
# NOTE WHAT IS *NOT* CHANGED: the defaults. `contracts/archive-sweep.md` § 2 rules
# preview-by-default for this script and the manual documents the bare invocation as the
# dry run. This case pins that too — the instrument leg proves a plain `--apply` still
# sweeps, so the refusal cannot have been bought by breaking the tool.
# =============================================================================
case_archive_hedged_flags_never_mutate() {
  cf_reset
  local out rc before card

  _hedge_leg() {  # <flag1> <flag2> <label>
    make_sandbox
    seed_issue qa_complete "$SB_PREFIX-260" hedge chore "Hedged sweep"
    publish_sandbox
    grep -q '^## Archived$' "$SB_WORK/ARCHIVE.md" 2>/dev/null \
      || _fixture_die "case_archive_hedged_flags_never_mutate: no '## Archived' heading — archive.sh would refuse for THAT reason and every 'nothing moved' assertion below would pass for the wrong one."
    before="$(git -C "$SB_WORK" rev-parse HEAD)"
    rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" "$1" "$2" 2>&1 )" || rc=$?
    [ "$rc" -eq 2 ] \
      || cf "($3) a contradictory pair exited $rc, want 2 — the published usage status: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"
    printf '%s\n' "$out" | grep -qi 'contradictory' \
      || cf "($3) the refusal does not say the flags contradict: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"
    [ -f "$SB_WORK/progress/qa_complete/$SB_PREFIX-260-hedge.md" ] \
      || cf "($3) the card LEFT qa_complete/ — the hedge mutated"
    [ -f "$SB_WORK/progress/done/$SB_PREFIX-260-hedge.md" ] \
      && cf "($3) the card reached done/"
    grep -q "$SB_PREFIX-260" "$SB_WORK/ARCHIVE.md" 2>/dev/null \
      && cf "($3) ARCHIVE.md gained an index entry during a refusal"
    [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$before" ] \
      || cf "($3) a commit was created during a refusal"
    origin_has_path "progress/done/$SB_PREFIX-260-hedge.md" \
      && cf "($3) the sweep reached the REMOTE trunk"
    teardown
  }

  _hedge_leg --apply --dry-run "apply-then-dry"
  _hedge_leg --dry-run --apply "dry-then-apply"

  # ── INSTRUMENT CHECK. Every assertion above is "nothing happened", which a sweep
  #    broken for ANY reason satisfies. The same fixture with a plain --apply must SWEEP.
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-261" plain chore "Plain sweep"
  publish_sandbox
  rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] \
    || cf "(control) a plain --apply exited $rc — the refusals above may be a broken sweep rather than a guard: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"
  origin_has_path "progress/done/$SB_PREFIX-261-plain.md" \
    || cf "(control) a plain --apply did not reach the trunk — this case cannot tell a refusal from a no-op"
  teardown

  unset -f _hedge_leg
  finish "archive.sh: a contradictory --apply/--dry-run pair refuses at status 2 in EITHER order with the board, the local HEAD and the remote all unchanged — and a plain --apply on the same fixture still sweeps"
}

case_one_member_role_tag_refuses_before_mutating() {
  cf_reset
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-300" alpha chore "Archive alpha"
  publish_sandbox

  local cm="$SB_WORK/scripts/githooks/commit-msg" narrow='PM|Dev' out rc=0
  # PM and Dev are kept because the fixtures commit under both. EVERY FIXTURE MUTATION
  # ASSERTS: a perl -i whose pattern misses exits 0 and leaves the file byte-identical.
  NEU_NEW="$narrow" perl -i -pe "s@^ROLE_PREFIXES='.*'\$@ROLE_PREFIXES='\$ENV{NEU_NEW}'@" "$cm"
  grep -qxF "ROLE_PREFIXES='$narrow'" "$cm" \
    || _fixture_die "case_one_member_role_tag_refuses_before_mutating: the narrowed role set did not land in the sandbox's commit-msg — the refusal below would be tested against the shipped set, which CONTAINS the tag, and the case would prove nothing."
  printf '%s\n' "$narrow" | tr '|' '\n' | grep -qx Orchestrator \
    && _fixture_die "case_one_member_role_tag_refuses_before_mutating: the narrowed set still contains the tag archive.sh writes — the premise of this case is gone."
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[PM] narrow the declared role set" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1

  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "archive.sh --apply exited 0 with a role tag the project's hook does not accept"
  # THE EFFECT, ON THE AUTHORITATIVE STATE — this is the assertion the exit code cannot make.
  origin_has_path "progress/qa_complete/$SB_PREFIX-300-alpha.md" \
    || cf "the card left qa_complete/ on the trunk even though the sweep's commit could not be made"
  origin_has_path "progress/done/$SB_PREFIX-300-alpha.md" \
    && cf "the card reached done/ — the sweep MUTATED and only the commit failed, which is the uncommitted-state-in-a-discarded-worktree loss this refusal exists to prevent"
  printf '%s\n' "$out" | grep -q 'ARCHIVE_ROLE' \
    || cf "the refusal does not name the knob that would fix it: $(printf '%s' "$out" | tr '\n' '|')"

  # ── INSTRUMENT CHECK. "Nonzero and nothing moved" is satisfied by an archive.sh
  #    broken for ANY reason. Restore the declared set and the SAME invocation must work.
  NEU_NEW="$KIT_NEUTRAL_ROLE_PREFIXES" perl -i -pe "s@^ROLE_PREFIXES='.*'\$@ROLE_PREFIXES='\$ENV{NEU_NEW}'@" "$cm"
  grep -qxF "ROLE_PREFIXES='$KIT_NEUTRAL_ROLE_PREFIXES'" "$cm" \
    || _fixture_die "case_one_member_role_tag_refuses_before_mutating: the role set was not restored — the control below cannot run."
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[PM] restore the shipped role set" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] \
    || cf "(control) archive.sh --apply still exited $rc with the shipped role set restored — the refusal above was not about the role tag: $(printf '%s' "$out" | tr '\n' '|')"
  origin_has_path "progress/done/$SB_PREFIX-300-alpha.md" \
    || cf "(control) the card did not reach done/ with a legal role tag — this case cannot tell a role refusal from a broken sweep"

  finish "one-member role tags: archive.sh refuses BEFORE mutating when its tag is not in the declared set, names ARCHIVE_ROLE, leaves the card on the trunk untouched, and sweeps normally once the tag is legal again"
  teardown
}

case_archive_apply() {
  cf_reset
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-200" alpha chore "Archive alpha"
  seed_issue qa_complete "$SB_PREFIX-201" beta  chore "Archive beta"
  publish_sandbox

  local out rc
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )"; rc=$?

  [ "$rc" -eq 0 ] || cf "archive.sh --apply exited $rc: $out"
  grep -q "$SB_PREFIX-200" "$SB_WORK/ARCHIVE.md" || cf "$SB_PREFIX-200 not indexed in ARCHIVE.md"
  grep -q "$SB_PREFIX-201" "$SB_WORK/ARCHIVE.md" || cf "$SB_PREFIX-201 not indexed in ARCHIVE.md"
  [ -f "$SB_WORK/progress/done/$SB_PREFIX-200-alpha.md" ] || cf "$SB_PREFIX-200 not moved into done/"
  [ -f "$SB_WORK/progress/done/$SB_PREFIX-201-beta.md" ]  || cf "$SB_PREFIX-201 not moved into done/"
  [ -f "$SB_WORK/progress/qa_complete/$SB_PREFIX-200-alpha.md" ] && cf "$SB_PREFIX-200 still in qa_complete/"

  finish "archive.sh --apply: index in ARCHIVE.md + move into done/"
  teardown
}

# =============================================================================
# CASE — archive.sh --apply from a FEATURE BRANCH leaves that branch's tree clean
# (it routes through .kanban-wt, never the operator's checkout).
# =============================================================================
# =============================================================================
# CASE — THE ARCHIVE INDEX CARRIES A RETIREMENT DATE (both directions).
#
# archive-sweep.md § 2: "Every retired item gains an INDEX entry ... carrying at
# least its identifier, its title and its RETIREMENT DATE." The entry carried the
# first two, so the index answered *what* was archived and never *when* — the one
# question a retention policy asks of it.
#
# BOTH DIRECTIONS, because the first alone proves the line RUNS, not that it DOES
# ANYTHING: with the date write ablated out, the assertion must fail. A control that
# cannot fail is not a control, and this harness has already caught one of mine that
# could not (a fixture whose own portability slip was indistinguishable from the
# defect under test).
# =============================================================================
# =============================================================================
# A SCHEMA'S `required` MUST NAME PROPERTIES THE SCHEMA DEFINES
# =============================================================================
# WHY THIS EXISTS (measured, and it shipped): a change renamed a schema property
# from `landed` to `landing` in both runners, and in tranche-runner's PARK_SCHEMA the
# `properties` block was updated while `required` was not. The schema then DEMANDED A
# PROPERTY IT DID NOT DEFINE — it could not validate, and a validator would have asked
# every park leg for a field no brief mentions.
#
# THREE THINGS THAT SHOULD HAVE STOPPED IT DID NOT: `node --check` cannot see it (it is
# valid JavaScript and the defect is semantic); the harness did not exercise the runners
# at all, which the implementing leg reported explicitly rather than letting a green
# imply coverage; and the review comparison — one line — was not run.
#
# AND THE ENUM GUARD DOES NOT CATCH THIS. That case compares each runner's VERDICTS
# array against the ratified token set: a different assertion entirely. A guard for the
# adjacent defect is not a guard for this one, and the presence of *a* schema guard is
# exactly what stops the next person looking harder (negative-claims.md § A.4).
#
# ALL SIX SCHEMAS, NOT FOUR. A hand-run of this check once covered four, because
# its source slice began at `const VERDICTS` and both DEV_SCHEMAs fell outside it. That
# limit was stated by the leg that ran it; the extractor below keys on
# `^const <NAME>_SCHEMA` so a seventh schema is covered the day it appears.
#
# ONE DIRECTION ONLY, and the other was measured and declined: "a property no consumer
# reads" would fire on six legitimate keys (DEV_SCHEMA.summary/.test_evidence/.deviations
# in each runner, all filled for the QA leg and the run report to read), and a narrower
# "referenced nowhere else" rescue fires on five. A `required` naming an undefined
# property is asymmetric — it is ALWAYS a defect, because the schema cannot validate —
# which is why it is the one that survives.
_schema_extract_awk() {
  cat <<'AWKEOF'
/^const [A-Za-z_]+_SCHEMA[[:space:]]*=/ { s=$2; inprops=0; next }
s == "" { next }
/^[[:space:]]*properties:[[:space:]]*\{/ { inprops=1; next }
inprops && /^[[:space:]]{2}\},?[[:space:]]*$/ { inprops=0; next }
inprops && /^[[:space:]]{4}[A-Za-z_]+:/ {
  k=$1; sub(/:.*/,"",k); gsub(/[[:space:]]/,"",k); print s "|prop|" k; next
}
/^[[:space:]]*required:[[:space:]]*\[/ {
  line=$0; sub(/^[^[]*\[/,"",line); sub(/\].*/,"",line)
  n=split(line, a, ",")
  for (i=1;i<=n;i++) { v=a[i]; gsub(/[[:space:]'\''"]/,"",v); if (v!="") print s "|req|" v }
  next
}
/^\}/ { s="" }
AWKEOF
}

# _schema_audit <file> <label> -> prints findings; echoes "<n_schemas> <n_bad>"
_schema_audit() {
  local f="$1" lab="$2" ex n=0 bad=0 sch r
  ex="$(mktemp)"
  awk -f <(_schema_extract_awk) "$f" > "$ex"
  while IFS= read -r sch; do
    [ -z "$sch" ] && continue
    n=$(( n + 1 ))
    while IFS= read -r r; do
      [ -z "$r" ] && continue
      if ! awk -F'|' -v s="$sch" '$1==s && $2=="prop"{print $3}' "$ex" | grep -qxF "$r"; then
        echo "    ✗ ${lab} ${sch}: required names '${r}' which properties does not define"
        bad=$(( bad + 1 ))
      fi
    done < <(awk -F'|' -v s="$sch" '$1==s && $2=="req"{print $3}' "$ex")
  done < <(cut -d'|' -f1 "$ex" | sort -u)
  rm -f "$ex"
  echo "$n $bad"
}

# =============================================================================
# NO SHIPPED SKILL REFERENCES A FOREIGN PLUGIN NAMESPACE
# =============================================================================
# WHY A MECHANISM AND NOT A SENTENCE (the raising leg's § A.5b argument, kept because
# it is the whole reason this is a case): the population of bad references GROWS
# MONOTONICALLY with every plan a project writes, and those documents OUTLIVE any later
# kit fix — `writing-plans/SKILL.md` says "Every plan MUST start with this header", and
# the header carried the namespace. A sentence fixes the kit; it does not fix the plans
# already written from it, and it does not stop the next one.
#
# THE PATTERN IS `<ns>:<skill>` WITH NO SPACES, not the word. `using-superpowers/` is a
# legitimate shipped skill directory, so a word match would fire on the fix itself.
# Scoped to markdown and excluding URL schemes and inline CSS (`display:flex`,
# `.card:hover` live in this tree and are not references) — measured, not assumed: the
# unscoped form matched four CSS declarations in brainstorming/.
#
# AND IT FOUND ONE THE DE-NAMESPACING MISSED. The de-namespacing change closed the
# foreign `<ns>:<skill>` form and left
# `elements-of-style:writing-clearly-and-concisely` in brainstorming/SKILL.md, hedged
# with "if available" — which is exactly the softening that survives review. Fixed with
# the intent preserved rather than the line deleted; the reference had no subject in this
# kit, so by that change's own precedent for its one subject-less row it could not stay.
_foreign_ns_hits() {  # <dir> — prints "file:line:reference" per hit
  grep -rnE '\b[a-z][a-z0-9-]*:[a-z][a-z0-9-]+\b' --include='*.md' "$1" 2>/dev/null \
    | grep -vE 'https?:|file:|mailto:|style="' || true
}

case_skills_carry_no_foreign_namespace() {
  cf_reset
  make_sandbox

  # DUAL-SPELLING, and the reason belongs here rather than in the reader's memory: the
  # maintainer repository stores the kit disarmed (`_claude/`), a built kit ships it
  # armed (`.claude/`). Reading whichever exists lets this case still find the real
  # shipped tree in place. It does NOT make an in-place run a witness — see the header.
  local skills="" d
  for d in "$REAL_REPO_ROOT/_claude/skills" "$REAL_REPO_ROOT/.claude/skills"; do
    [ -d "$d" ] && skills="$d"
  done
  if [ -z "$skills" ]; then
    cf "no shipped skills directory found under either _claude/ or .claude/ — the check has no operand"
    finish "shipped skills: no foreign plugin namespace"; teardown; return
  fi

  # ASSERT THE OPERAND, not only the comparison: zero files scanned finds zero hits and
  # "passes". A skills tree with no markdown in it means the extractor lost its subject.
  local nfiles; nfiles="$(find "$skills" -name '*.md' -type f | wc -l | tr -d ' ')"
  [ "$nfiles" -ge 5 ] \
    || cf "only $nfiles markdown file(s) under $skills — too few to be the shipped skill set; the scan lost its operand rather than finding a clean tree"

  local hits; hits="$(_foreign_ns_hits "$skills")"
  [ -z "$hits" ] || cf "a shipped skill references a foreign plugin namespace (the kit ships no such namespace, so it cannot resolve):
$(printf '%s' "$hits" | sed 's/^/      /')"

  # ── THE REDDENING CONTROL, on a COPY — never the live tree (instruments.md § A.2).
  local probe="$SB_TMP/nsprobe"; mkdir -p "$probe"
  cp "$skills"/*/SKILL.md "$probe/" 2>/dev/null || true
  local victim; victim="$(probe_pick "$probe" -name '*.md' -type f)"
  if [ -z "$victim" ]; then
    _control_did_not_run "copy a SKILL.md to plant into"
  else
    printf '\n- Use superpowers:executing-plans skill if available\n' >> "$victim"
    local planted; planted="$(_foreign_ns_hits "$probe")"
    printf '%s' "$planted" | grep -q 'superpowers:executing-plans' \
      || cf "(control) the check did NOT find a planted foreign reference — it cannot see the defect it is named after"
    printf '%s' "$planted" | grep -q "$(basename "$victim")" \
      || cf "(control) the finding does not name the file it is in: $planted"
  fi

  finish "shipped skills: no foreign plugin namespace ($nfiles md files scanned), and a planted one is found and named"
  teardown
}

# =============================================================================
# THE ORDER OF THE THREE CASES BELOW IS DECIDED, NOT ACCIDENTAL. Each was authored
# separately and each said "beside case_skills_carry_no_foreign_namespace"; all
# three cannot be literal neighbours. Ordered by SUBJECT ADJACENCY: the two that
# read the same operand as the case above (the shipped skills corpus — what those
# skills SAY) sit with it first, and the dev/ index case, whose corpus is a
# different tree entirely, follows them.
#   1. no foreign plugin namespace   (above)   — what a skill NAMES
#   2. no unconditional forge command          — what a skill INSTRUCTS
#   3. upstream product name only where kept   — what a skill CALLS things
#   4. the dev/ index names its subdirectories — a different corpus
# =============================================================================

# =============================================================================
# no shipped skill states a FORGE COMMAND as an instruction
# =============================================================================
# WHY A MECHANISM AND NOT A SENTENCE: the return path is an UPSTREAM RE-COPY. These
# skills are vendored; updating one is "copy the folder over and diff", and the rule
# that says which way the merge goes lives in skills/README.md — prose, in the file a
# diff-reader skims. A re-copy that restores a single forge's command has not updated
# the skill, it has re-narrowed it, and the adopter who cannot run that command is the
# one who finds out.
#
# WHY PARAGRAPHS AND NOT LINES (instruments.md § A.7.1): line breaks are an artifact of
# the authoring tool. MEASURED: a correctly-marked paragraph whose "example" wraps onto
# a line other than the command is a FALSE POSITIVE under grep -n and clean under this.
# The second control below is that measurement, kept executable.
#
# THE LEXICON IS AN ENUMERATION AND SAYS SO (§ A.7.4/5): gh|glab|hub|tea × subcommand,
# marker set example|illustrative|not exhaustive. Measured cost of the forge list on the
# shipped tree: zero false positives. "adapter" and "your forge" are DELIBERATELY NOT
# enrolled — they would suppress a line that gives a live forge instruction while
# gesturing at the adapter.
#
# ADOPTER-SPECIFIC FACT, DECLARED: this pins a KIT property. An adopter who adopts the
# optional forge flavor and writes its command into their own skill copy should mark it
# as their project's declared example, or drop this case.
_forge_cmd_paras() {   # <file> — "<file>:<first-line>:<paragraph>" per PARAGRAPH naming a forge CLI
  awk -v f="$1" '
    function flush() {
      if (p != "" && p ~ /(^|[^A-Za-z])(gh|glab|hub|tea) (pr|issue|repo|api|release|auth|workflow|mr|merge-request) /)
        print f ":" start ":" p
      p=""; start=0
    }
    /^[[:space:]]*$/ { flush(); next }
    { if (p == "") { start=NR; p=$0 } else { p = p " " $0 } }
    END { flush() }
  ' "$1"
}

_forge_paras_all() {   # <dir> — every forge-command paragraph under it, marked or not
  find "$1" -name '*.md' -type f -print0 2>/dev/null \
    | while IFS= read -r -d '' f; do _forge_cmd_paras "$f"; done
}

_forge_paras_unmarked() {   # <dir> — the ones that do NOT declare themselves an example
  _forge_paras_all "$1" | grep -viE 'example|illustrative|not exhaustive' || true
}

_forge_unmarked_n() {  # <dir> — how many
  _forge_paras_unmarked "$1" | grep -c . || true
}

case_skills_name_no_forge_unconditionally() {
  cf_reset
  make_sandbox

  # DUAL-SPELLING, and the reason belongs here rather than in the reader's memory: the
  # maintainer repository stores the kit disarmed (`_claude/`), a built kit ships it
  # armed (`.claude/`). Reading whichever exists lets this case still find the real
  # shipped tree in place. It does NOT make an in-place run a witness — see the header.
  local skills="" d
  for d in "$REAL_REPO_ROOT/_claude/skills" "$REAL_REPO_ROOT/.claude/skills"; do
    [ -d "$d" ] && skills="$d"
  done
  if [ -z "$skills" ]; then
    cf "no shipped skills directory found under either _claude/ or .claude/ — the check has no operand"
    finish "shipped skills: no unconditional forge command"; teardown; return
  fi

  # ASSERT THE OPERAND, not only the comparison: zero files scanned finds zero hits and
  # "passes" (the sibling namespace case's rule, reused).
  local nfiles; nfiles="$(find "$skills" -name '*.md' -type f | wc -l | tr -d ' ')"
  [ "$nfiles" -ge 5 ] \
    || cf "only $nfiles markdown file(s) under $skills — too few to be the shipped skill set; the scan lost its operand rather than finding a clean tree"

  local total; total="$(_forge_paras_all "$skills" | grep -c . || true)"
  local unmarked; unmarked="$(_forge_paras_unmarked "$skills")"
  [ -z "$unmarked" ] || cf "a shipped skill gives a forge command as an instruction, not as an example (the kit is forge-agnostic: an adopter on another forge cannot run it):
$(printf '%s' "$unmarked" | sed "s|^$skills/||" | cut -c1-200 | sed 's/^/      /')"

  # ── THE REDDENING CONTROLS, on a COPY — never the live tree (instruments.md § A.2).
  # Both are DELTAS against a baseline taken on the copy, so neither depends on the live
  # tree being clean: a real defect above must not be able to satisfy a control below.
  local probe="$SB_TMP/forgeprobe"; rm -rf "$probe"; mkdir -p "$probe"
  local src; src="$(probe_pick "$skills" -name 'SKILL.md' -type f)"
  [ -n "$src" ] && cp "$src" "$probe/victim.md"
  if [ ! -f "$probe/victim.md" ]; then
    _control_did_not_run "copy a SKILL.md to plant into (NEITHER control ran)"
  else
    local base; base="$(_forge_unmarked_n "$probe")"

    # CONTROL 1 — an unmarked instruction is FOUND and NAMED.
    printf '\nRun `gh pr create --fill` to open the review.\n' >> "$probe/victim.md"
    local planted; planted="$(_forge_paras_unmarked "$probe")"
    printf '%s' "$planted" | grep -q 'gh pr create' \
      || cf "(control) the check did NOT find a planted unconditional forge command — the pattern set no longer matches the case it was built for"
    printf '%s' "$planted" | grep -q 'victim.md' \
      || cf "(control) the finding does not name the file it is in: $planted"
    local after; after="$(_forge_unmarked_n "$probe")"
    [ "$after" -eq $(( base + 1 )) ] \
      || cf "(control) planting one instruction moved the count from $base to $after, not to $(( base + 1 ))"

    # CONTROL 2 — a MARKED instruction whose marker wrapped onto another line is NOT a
    # finding. This is the § A.7.1 measurement, kept executable: under a raw-line check
    # this plant is a false positive.
    printf '\nGitHub the CLI, as one example, is\nnot the requirement: run `gh pr create --fill` here.\n' >> "$probe/victim.md"
    local wrapped; wrapped="$(_forge_unmarked_n "$probe")"
    [ "$wrapped" -eq "$after" ] \
      || cf "(control) a WRAPPED paragraph whose example marker sits on a line other than the command was counted as unmarked ($wrapped, expected $after) — the guard is reading raw lines, not normalised paragraphs"
  fi

  finish "shipped skills: every forge command is a named example ($total forge-command paragraph(s) across $nfiles md files under the skills tree; span = markdown under the skills tree, lexicon = gh/glab/hub/tea), and a planted instruction is found and named"
  teardown
}

# =============================================================================
# the UPSTREAM PRODUCT NAME survives only where a rename would make a true
# statement FALSE — and the allowance is a PATTERN, not a file list
# =============================================================================
# WHY A MECHANISM AND NOT A SENTENCE: the de-namespacing change closed the `<ns>:<skill>`
# form (the case above) and then stated, in prose, that the only residue left was
# directory and file names. It was not — instruction prose, a path in executing code and
# a rendered page title also carried it — and three of those files were missing from the
# first hand enumeration of them. A prose enumeration of residue is stale the day a line
# is added; this makes it executable, so the NEXT mention has to argue for itself.
#
# THE THREE ALLOWED SHAPES, each with the reason it is allowed:
#   1. `~/.config/superpowers/…` — an EXTERNAL tool's real directory. The skills ADOPT that
#      directory where it already exists — they never create it — and add a worktree inside
#      it, so renaming it in our copy would send a correct instruction looking for a
#      directory nothing creates.
#   2. `using-superpowers` — the shipped skill directory's own name, plus the rows in the
#      skills index and the Dev role doc that cite it. That rename is link-breaking and
#      still deferred; WHEN IT LANDS, DELETE THIS ALLOWANCE and this case becomes the
#      rename's own gate.
#   3. A line carrying the upstream repository URL — provenance. A skill whose origin
#      nobody can name is a skill nobody can safely update, so the citation stays.
# Patterns, not paths: a residue site that moves to another file is still caught and no
# file list has to be maintained. Line granularity is the known limit — prose sharing a
# line with an allowed shape rides through, which is why the shapes are narrow.
#
# SCOPE, stated rather than implied: the shipped agent surface only (`_claude/` before
# init, `.claude/` after). NOT the adopter's own tree, which has its own vocabulary and
# would inherit findings it cannot interpret; NOT this harness, which names the word in
# comments and plants it in three controls, so scanning it would fire on the instruments
# instead of the subject.
_upstream_name_hits() {  # <dir> — prints "file:line:text" per DISALLOWED mention
  grep -rn -i 'superpowers' "$1" 2>/dev/null \
    | grep -vE '\.config/superpowers/' \
    | grep -vE 'using-superpowers' \
    | grep -vE 'github\.com/[^ ]*/superpowers' || true
}

case_upstream_name_only_where_kept() {
  cf_reset
  make_sandbox

  # DUAL-SPELLING, and the reason belongs here rather than in the reader's memory: the
  # maintainer repository stores the kit disarmed (`_claude/`), a built kit ships it
  # armed (`.claude/`). Reading whichever exists lets this case still find the real
  # shipped tree in place. It does NOT make an in-place run a witness — see the header.
  local agent="" d
  for d in "$REAL_REPO_ROOT/_claude" "$REAL_REPO_ROOT/.claude"; do
    [ -d "$d" ] && agent="$d"
  done
  if [ -z "$agent" ]; then
    cf "no shipped agent directory found under either _claude/ or .claude/ — the check has no operand"
    finish "shipped skills: upstream name only where a rename would falsify"; teardown; return
  fi

  # ASSERT THE OPERAND, not only the comparison: zero files scanned finds zero mentions
  # and "passes".
  local nfiles
  nfiles="$(find "$agent" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.html' \) | wc -l | tr -d ' ')"
  [ "$nfiles" -ge 20 ] \
    || cf "only $nfiles scannable file(s) under $agent — too few to be the shipped agent surface; the scan lost its subject rather than finding a clean tree"

  local hits; hits="$(_upstream_name_hits "$agent")"
  [ -z "$hits" ] || cf "the upstream product name is used where nothing depends on it — allowed only as the external \`~/.config/superpowers/\` path, the \`using-superpowers\` skill name, or a line carrying the upstream repository URL:
$(printf '%s' "$hits" | sed 's/^/      /')"

  # ── THE REDDENING CONTROL, on a COPY — never the live tree (instruments.md § A.2).
  # BOTH DIRECTIONS IN ONE PLANT: a bare product-name mention must be FOUND and named,
  # and the kept external path planted beside it must NOT be — an allowance that has
  # stopped working would redden this case on correct content, which is the failure a
  # one-directional control cannot see.
  local probe="$SB_TMP/upstreamprobe"; mkdir -p "$probe"
  local victim="$probe/planted-SKILL.md"
  local src; src="$(probe_pick "$agent" -name 'SKILL.md' -type f)"
  [ -n "$src" ] && cp "$src" "$victim"
  if [ ! -f "$victim" ]; then
    _control_did_not_run "copy a SKILL.md to plant into"
  else
    printf '\n**Note:** Superpowers works much better with access to subagents.\n' >> "$victim"
    printf '\n   ls -d ~/.config/superpowers/worktrees/$project\n' >> "$victim"
    local planted; planted="$(_upstream_name_hits "$probe")"
    printf '%s' "$planted" | grep -qi 'Superpowers works much better' \
      || cf "(control) the check did NOT find a planted product-name mention — it cannot see the defect it is named after"
    printf '%s' "$planted" | grep -q 'planted-SKILL.md' \
      || cf "(control) the finding does not name the file it is in: $planted"
    printf '%s' "$planted" | grep -q '\.config/superpowers/worktrees' \
      && cf "(control) the kept external path was reported as a finding — the allowance for it has stopped working, and this case would redden on correct content"
  fi

  finish "shipped skills: upstream name only where a rename would falsify ($nfiles files scanned), and a planted mention is found and named"
  teardown
}

# =============================================================================
# THE dev/ INDEX NAMES every subdirectory that carries its own README
# =============================================================================
# WHY A MECHANISM AND NOT A SENTENCE: dev/README.md states its index rule as
# BIDIRECTIONAL and warns that a rule enforced in one direction rots in the other. It
# then rotted in exactly that direction — a subdirectory was added with a substantive
# README and two templates pointing into it, and a grep for its name in dev/README.md
# matched nothing for the whole life of the directory. The sentence was there; the miss
# happens in the change that CREATES the directory, where the reviewer reads the new
# README and not the old index.
#
# SCOPE IS THE SPLIT-OUT SUBDIRECTORY, and that is the file's own rule: "split it out
# into its own dev/<dir>/README.md and leave a one-line row here" means a subdirectory
# holding a README has a row owed. Dated snapshots are NOT asserted — they arrive
# constantly in a live project, and a case that reddened on each unindexed one would be
# switched off in a week. An abandoned case guards nothing.
_dev_unindexed_subdirs() {  # <dev-dir> — prints the basename of each subdirectory
  local dev="$1" idx="$1/README.md" d n   # that holds a README.md and is named nowhere in dev/README.md
  [ -f "$idx" ] || return 0
  while IFS= read -r d; do
    [ -f "$d/README.md" ] || continue
    n="$(basename "$d")"
    grep -qF -- "$n/" "$idx" || printf '%s\n' "$n"
  done < <(find "$dev" -mindepth 1 -maxdepth 1 -type d | sort)
}

case_dev_index_names_its_subdirs() {
  cf_reset
  make_sandbox   # for SB_TMP + teardown; this case reads the REAL shipped tree

  local dev="$REAL_REPO_ROOT/dev"
  if [ ! -f "$dev/README.md" ]; then
    skp "dev/ index names every subdirectory that carries its own README" "dev/README.md absent"
    teardown; return
  fi

  # ASSERT THE OPERAND, not only the comparison: zero subdirectories scanned finds zero
  # misses and "passes". A dev/ with no split-out directory means the scan lost its subject.
  local nsub; nsub="$(find "$dev" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/README.md' \; -print | wc -l | tr -d ' ')"
  [ "$nsub" -ge 1 ] \
    || cf "no subdirectory under dev/ carries a README.md — the scan lost its operand rather than finding a complete index"

  local missing; missing="$(_dev_unindexed_subdirs "$dev")"
  [ -z "$missing" ] || cf "a dev/ subdirectory with its own README is named nowhere in dev/README.md — unindexed, against that file's own first rule:
$(printf '%s' "$missing" | sed 's|^|      dev/|;s|$|/|')"

  # ── THE REDDENING CONTROL, on a COPY — never the live tree (instruments.md § A.2).
  local probe="$SB_TMP/devprobe"; rm -rf "$probe"; mkdir -p "$probe/zz-planted"
  cp "$dev/README.md" "$probe/README.md" 2>/dev/null || true
  printf '# a planted subdirectory nobody indexed\n' > "$probe/zz-planted/README.md"
  if [ ! -f "$probe/README.md" ]; then
    _control_did_not_run "copy dev/README.md to plant against"
  else
    _dev_unindexed_subdirs "$probe" | grep -qx 'zz-planted' \
      || cf "(control) the check did NOT flag a planted unindexed subdirectory — it cannot see the defect it is named after"
  fi

  finish "dev/ index names every subdirectory that carries its own README ($nsub scanned), and a planted one is flagged"
  teardown
}

# =============================================================================
# POST-INIT, THE KIT-CLASS MARKERS ARE INTACT — not rewritten and not deleted
# =============================================================================
# WHY BOTH DIRECTIONS, and this is the raising leg's point: EITHER CHECK ALONE PASSES ON
# A TREE WHERE THE MARKERS WERE DELETED. "No <PREFIX>-CLASS survives" is satisfied by a
# file with no marker at all; "KIT-CLASS is present" is satisfied by a tree where one
# file kept its marker and the rest were rewritten. The pair is the assertion.
#
# The defect: the initializer's prefix substitution rewrote the marker's KEY, so a
# stamped file came out `<!-- SBX-CLASS: KIT — … -->` and every later grep for KIT-CLASS
# found nothing — the classification silently leaving the tree it classifies.
case_kit_init_markers_intact() {
  cf_reset
  if ! has_kit_init; then skp "kit-init: KIT-CLASS markers survive the stamp" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "kit-init: KIT-CLASS markers survive the stamp" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  # THE SAME SETUP THE SIBLING kit-init CASE USES, derived from it rather than
  # re-invented: kit-init needs a prepared .claude/ and a published trunk, and a bare
  # make_sandbox gives neither — it exits 1 with no output, which reads as a defect in
  # the subject rather than in the fixture.
  kit_init_sandbox
  publish_sandbox

  local out rc
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { cf "kit-init exited $rc: $out"; finish "kit-init: KIT-CLASS markers survive the stamp"; teardown; return; }

  local dirs=() d
  for d in "$SB_WORK/.claude/templates" "$SB_WORK/.claude/roles"; do [ -d "$d" ] && dirs+=("$d"); done
  [ "${#dirs[@]}" -gt 0 ] || cf "neither .claude/templates nor .claude/roles exists post-init — the assertion has no operand"

  if [ "${#dirs[@]}" -gt 0 ]; then
    # DIRECTION 1 — the marker is still THERE. Catches deletion, and catches a rewrite.
    local kept; kept="$(grep -rl 'KIT-CLASS' "${dirs[@]}" 2>/dev/null | wc -l | tr -d ' ')"
    [ "$kept" -gt 0 ] \
      || cf "post-init, NO file under .claude/{templates,roles} carries a KIT-CLASS marker — the stamp removed or rewrote the classification off every one"

    # DIRECTION 2 — no PREFIXED variant exists. Names the rewrite specifically; without
    # it, direction 1 alone reports "markers gone" and not "the key was substituted".
    local rewritten; rewritten="$(grep -rn 'SBX-CLASS' "${dirs[@]}" 2>/dev/null || true)"
    [ -z "$rewritten" ] \
      || cf "the prefix substitution rewrote the marker's KEY — a grep for KIT-CLASS will find nothing:
$(printf '%s' "$rewritten" | sed 's/^/      /')"

    # ── REDDENING CONTROL, on a COPY: reproduce the substitution and confirm BOTH arms
    #    fire. Without this the two greens above are compatible with a check that cannot
    #    see the defect at all.
    local probe="$SB_TMP/mkprobe"; rm -rf "$probe"; mkdir -p "$probe"
    cp -R "${dirs[0]}" "$probe/" 2>/dev/null || true
    local pd; pd="$(probe_pick "$probe" -mindepth 1 -maxdepth 1 -type d)"
    if [ -z "$pd" ]; then
      _control_did_not_run "copy a marker directory to plant into"
    else
      find "$pd" -type f -name '*.md' -exec sed -i.bak 's/KIT-CLASS/SBX-CLASS/g' {} \; 2>/dev/null
      find "$pd" -name '*.bak' -delete 2>/dev/null
      [ -z "$(grep -rl 'KIT-CLASS' "$pd" 2>/dev/null)" ] \
        || cf "(control) the planted substitution left KIT-CLASS behind — the control did not reproduce the defect"
      [ -n "$(grep -rn 'SBX-CLASS' "$pd" 2>/dev/null)" ] \
        || cf "(control) the planted substitution produced no SBX-CLASS — direction 2 would never fire"
    fi
  fi

  finish "kit-init: KIT-CLASS markers survive the stamp — present under .claude/{templates,roles} AND no <PREFIX>-CLASS variant (both directions, deletion and rewrite)"
  teardown
}

case_runner_schema_required_defines() {
  cf_reset
  make_sandbox   # for SB_TMP + teardown; this case reads the REAL shipped runners

  local total_schemas=0 total_bad=0 f lab res n bad
  # THE ENUMERATION IS _shipped_runners, NOT A SECOND COPY OF ITS GLOB. This case re-typed that
  # dual-spelling glob for a while: the two copies sat sixty lines apart with nothing holding them
  # together, so a third runner directory or a changed spelling would have moved one and not the
  # other. The dual-spelling reason now lives at the helper.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    lab="$(basename "$f")"
    res="$(_schema_audit "$f" "$lab" | tail -1)"
    _schema_audit "$f" "$lab" | grep '✗' || true
    n="${res%% *}"; bad="${res##* }"
    total_schemas=$(( total_schemas + n )); total_bad=$(( total_bad + bad ))
  done <<EOF
$(_shipped_runners)
EOF

  # ASSERT THE EXTRACTOR, NOT ONLY THE COMPARISON. Zero schemas found compares zero
  # against zero and "passes" — the vacuous green this whole sheet is about. Six is
  # the shipped count (DEV/QA/PARK in each of two runners); fewer means the extractor
  # stopped matching, which is a defect in the CASE and must not read as a clean tree.
  [ "$total_schemas" -ge 6 ] \
    || cf "the extractor found only $total_schemas schema(s) — expected at least 6 (DEV/QA/PARK × 2 runners). A count this low means the extractor stopped matching, NOT that the tree is clean."
  [ "$total_bad" -eq 0 ] \
    || cf "$total_bad schema(s) have a required name their properties do not define (listed above)"

  finish "runner schemas: every 'required' name is defined in 'properties' ($total_schemas schemas checked, $total_bad bad)"
  teardown
}

# =============================================================================
# THE DOCUMENTED goldenPaths ESCAPE MUST ACTUALLY SKIP
# =============================================================================
# tranche-runner documented "Empty string = skip the zero-drift diff entirely (a project with no
# goldens should pass '')" and then wrote `ARGS.goldenPaths || <default>` — and `'' || <default>` IS
# the default, so the escape restored the very value it was meant to suppress. A project with no
# pinned-output corpus passed '' exactly as instructed, and both its QA seats ran a diff against
# paths that do not exist, on every issue, and had to write a paragraph each time explaining that an
# empty match is not a clean diff. wave-runner carried the identical `||` with no comment promising
# anything, so the defect was here twice — once documented and broken, once undocumented and broken.
#
# THIS CASE DOES NOT EXECUTE THE RUNNERS, and that is deliberate rather than a shortcut. Node is not
# a kit dependency (kit/scripts/ invokes it nowhere; the one Node extra is opt-in per question and
# deletable), so a case that ran them would make the harness fail on a conforming machine. The
# established idiom for the runners in this file is static extraction with a control on the
# EXTRACTOR — see case_runner_schema_required_defines, whose own comment records that the harness
# does not exercise them.
#
# BOTH HALVES ARE ASSERTED, because either alone is a green that cannot go red for the real
# behaviour: `??` in the CFG default makes '' REACH CFG.goldenPaths, and the drift step's own guard
# on that value is what turns that into a SKIP. Assert only the first and a later edit to the guard
# breaks the skip while this case stays green; assert only the second and a revert to `||` never
# delivers '' to it. The pair is the property.
#
# COMMENTS ARE STRIPPED BEFORE EVERY LOOKUP, and this is not hygiene — it is the fix to a FALSE GREEN
# this case was CAUGHT producing on its own third control. The runners now carry a comment explaining
# why the guard matters, and that comment NAMES THE GUARD. So with the real guard ablated out of the
# code, a plain `grep -F` still matched — the assertion was satisfied by the prose written to explain
# the thing it was supposed to be measuring.
#
# THE GENERAL FORM, because this was the SECOND instance in one session: an assertion that greps
# source for a token must strip that source's comments, because the comment explaining why the token
# matters is the place the token is most certain to appear. The first instance was the maintainer
# repository's own live-state arm, satisfied by an HTML comment recording the very staleness it was
# checking for. Strip toward OVER-stripping: an over-strip reddens loudly and a reader investigates,
# an under-strip is the silent pass this note exists to prevent.
# EVERY SHIPPED RUNNER, disarmed or armed tree — the ONE authoring site for that enumeration.
# Renamed from _goldenpaths_runners when it gained its second consumer: a helper named after one
# caller reads, to the next caller, like something it is not allowed to use.
#
# DUAL-SPELLING, and the reason belongs here rather than in each caller's memory: the maintainer
# repository stores the kit disarmed (`_claude/`), a built kit ships it armed (`.claude/`). Reading
# whichever exists lets a case still find the real shipped tree in place. It does NOT make an
# in-place run a witness — see the header.
#
# NOT THE ONLY WORKFLOW GLOB IN THIS FILE, AND THE OTHER ONE IS DELIBERATELY WIDER. Do not collapse
# case_shipped_runners_parse into this helper: it globs `workflows/*.js`, because a file that cannot
# be parsed matters whether or not its name contains "runner". Narrowing it to `*runner*.js` would
# quietly shrink the guard that caught a shipped runner which could not be loaded at all.
_shipped_runners() {
  local f
  for f in "$REAL_REPO_ROOT"/_claude/workflows/*runner*.js "$REAL_REPO_ROOT"/.claude/workflows/*runner*.js; do
    [ -e "$f" ] && printf '%s\n' "$f"
  done
}

# THE TWO RUNNERS CARRY THEIR SCHEMAS BY HAND, AND THE DUPLICATION IS PERMANENT. changes/DECLINED
# measured that the workflow runtime grants these files no imports and no filesystem access, so a
# shared module is not expressible — the copies cannot be removed. What CAN be held is their
# AGREEMENT, and it had already failed: four descriptions had drifted apart and one field had lost
# its description entirely before anyone compared them. This case is the witness the extraction
# cannot be.
_schema_descriptions() {   # <runner file> -> "SCHEMA.field<TAB>description", sorted
  awk -v q="'" '
    /^const [A-Z_]+_SCHEMA = \{/ { s = $2; next }
    s != "" && /^\}/            { s = ""; next }
    s != "" && match($0, /^[[:space:]]+[A-Za-z_]+:[[:space:]]*\{/) {
      f = $1; sub(/:.*$/, "", f)
      key = "description: " q
      i = index($0, key)
      if (i > 0) {
        d = substr($0, i + length(key))
        j = index(d, q)
        if (j > 0) d = substr(d, 1, j - 1)
        print s "." f "\t" d
      } else {
        print s "." f "\t<no description>"
      }
    }
  ' "$1" | sort
}

case_runner_schemas_agree() {
  cf_reset
  make_sandbox   # for SB_TMP + teardown; this case reads the REAL shipped runners

  local a b f found=0 n=0
  a="$SB_TMP/schema-a.txt"; b="$SB_TMP/schema-b.txt"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    found=$(( found + 1 ))
    case "$found" in
      1) _schema_descriptions "$f" > "$a" ;;
      2) _schema_descriptions "$f" > "$b" ;;
    esac
  done <<EOF
$(_shipped_runners)
EOF

  # ASSERT THE EXTRACTOR TWICE. Either failure makes the diff below compare nothing and pass.
  [ "$found" -eq 2 ] \
    || cf "expected exactly 2 shipped runners, found $found -- a comparison needs two operands, and with fewer this case asserts nothing"
  [ -f "$a" ] && n="$(wc -l < "$a" | tr -d ' ')"
  [ "$n" -ge 10 ] \
    || cf "the extractor found only $n schema field(s) -- expected at least 10. A low count means the extractor stopped matching, NOT that the schemas agree"

  if [ "$found" -eq 2 ] && ! diff -q "$a" "$b" >/dev/null 2>&1; then
    cf "the shipped runners schemas have DIVERGED -- they are hand-maintained copies and nothing else holds them together. Reconcile them, or if a field genuinely belongs to one runner only, say so in that runner's meta.description (which promises the same fields) and widen this case. Diff: $(diff "$a" "$b" | head -6 | tr '\n' ' ')"
  fi

  finish "the two shipped runners' schemas agree field-for-field ($n field(s) compared, descriptions included)"
  teardown
}

# THE RUN-OUTCOME VOCABULARY IS HAND-COPIED INTO BOTH RUNNERS, AND NOW HAS AN AUTHORITY. The copies
# cannot be removed — the runtime grants these files no imports — so this case holds BOTH directions,
# and it needs both: an authority does not make two hand-copied projections agree with each other,
# and two projections agreeing does not make either of them right. A pair that drifts TOGETHER passes
# an agreement-only guard in silence, which is what this case used to be.
#
# IT ALSO ASSERTS THAT EVERY DECLARED TOKEN IS USED. A vocabulary constant that has drifted into a
# superset of what the runner can actually return is documentation, not a vocabulary — and it would
# read as coverage to anyone comparing the two declarations.
_outcome_tokens() {   # <runner file> -> one token per line, sorted
  awk '
    /^const OUTCOME = Object\.freeze\(\{/ { inb=1; next }
    inb && /^\}\)/                         { inb=0; next }
    inb && match($0, /^[[:space:]]+[A-Z_]+:/) { t=$1; sub(/:$/, "", t); print t }
  ' "$1" | sort
}

case_runner_outcome_vocabulary_agrees() {
  cf_reset
  make_sandbox   # for SB_TMP + teardown; this case reads the REAL shipped runners

  local a b f found=0 n=0 t unused=0
  a="$SB_TMP/outcome-a.txt"; b="$SB_TMP/outcome-b.txt"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    found=$(( found + 1 ))
    case "$found" in
      1) _outcome_tokens "$f" > "$a" ;;
      2) _outcome_tokens "$f" > "$b" ;;
    esac
    # EVERY DECLARED TOKEN IS RETURNED SOMEWHERE IN ITS OWN RUNNER.
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      grep -qF "OUTCOME.$t" "$f" || { unused=$(( unused + 1 )); cf "$(basename "$f"): declares OUTCOME.$t and never returns it -- a vocabulary member the runner cannot produce is documentation, and it still compares equal to its twin"; }
    done < <(_outcome_tokens "$f")
  done <<EOF
$(_shipped_runners)
EOF

  # ASSERT THE EXTRACTOR TWICE: either failure makes the diff below compare nothing and pass.
  [ "$found" -eq 2 ] \
    || cf "expected exactly 2 shipped runners, found $found -- a comparison needs two operands"
  [ -f "$a" ] && n="$(wc -l < "$a" | tr -d ' ')"
  [ "$n" -ge 6 ] \
    || cf "the extractor found only $n outcome token(s) -- expected at least 6. A low count means the extractor stopped matching, NOT that the vocabularies agree"

  if [ "$found" -eq 2 ] && ! diff -q "$a" "$b" >/dev/null 2>&1; then
    cf "the runners' run-outcome vocabularies have DIVERGED: $(diff "$a" "$b" | tr '\n' ' ')"
  fi

  # ── THE AUTHORITY ARM. Agreement alone cannot see a pair that drifted TOGETHER.
  #    process/MANUAL.md ratifies the vocabulary; each runner PROJECTS it.
  local auth="$SB_TMP/outcome-auth.txt" man="$REAL_REPO_ROOT/process/MANUAL.md" na=0
  if [ -f "$man" ]; then
    awk '
      /^### The RUN-OUTCOME vocabulary/ { inb=1; next }
      inb && /^### /                    { inb=0 }
      inb && match($0, /^\| `[A-Z_]+`/) { t=$0; sub(/^\| `/, "", t); sub(/`.*$/, "", t); print t }
    ' "$man" | sort > "$auth"
    na="$(wc -l < "$auth" | tr -d ' ')"
    # The extractor is asserted before the comparison: an extractor that matched nothing
    # makes "the runner projects the table" true of an empty table, forever.
    [ "$na" -ge 6 ] \
      || cf "the MANUAL.md run-outcome table yielded only $na token(s) — the extractor stopped matching, so pinning the runners to it would compare against almost nothing"
    if [ "$na" -ge 6 ] && [ "$found" -eq 2 ] && ! diff -q "$a" "$auth" >/dev/null 2>&1; then
      cf "the runners' vocabulary does not PROJECT the ratified table in process/MANUAL.md — the two copies may agree with each other and with nothing else: $(diff "$a" "$auth" | tr '\n' ' ')"
    fi
  else
    cf "process/MANUAL.md is absent — the ratified table is the authority this case pins to"
  fi

  finish "the two shipped runners' run-outcome vocabularies agree with EACH OTHER and PROJECT the ratified table in process/MANUAL.md ($n token(s) per runner, $na ratified, $unused unused) — both arms, because an authority does not make two hand-copies agree and two hand-copies agreeing does not make either right"
  teardown
}

case_runner_goldenpaths_empty_skips() {
  cf_reset
  make_sandbox   # for SB_TMP + teardown; this case reads the REAL shipped runners

  local f lab found=0 bad=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    lab="$(basename "$f")"
    found=$(( found + 1 ))

    # THE OPERAND IS THE CODE, NOT THE FILE: every `//` comment is stripped first. See the header.
    local code; code="$(sed 's://.*::' "$f")"

    # HALF 1 — the CFG default falls through only on null/undefined.
    if printf '%s\n' "$code" | grep -qE '^[[:space:]]*goldenPaths:[[:space:]]*ARGS\.goldenPaths[[:space:]]*\?\?'; then
      :
    else
      bad=$(( bad + 1 ))
      cf "$lab: goldenPaths does not use '??' — with '||' the documented empty-string escape restores the default instead of skipping the zero-drift step, which is the defect this case exists for"
    fi
    # And the specific regression, named so a reader knows what to look for.
    ! printf '%s\n' "$code" | grep -qE '^[[:space:]]*goldenPaths:[[:space:]]*ARGS\.goldenPaths[[:space:]]*\|\|' \
      || { bad=$(( bad + 1 )); cf "$lab: goldenPaths is back to '||' — see the comment at that line before changing it"; }

    # HALF 2 — the drift step is guarded by the value, so an empty string skips it.
    # TWO ACCEPTED SHAPES, and the second is not a loosening. The guard was `CFG.goldenPaths &&`
    # while the path form was the only pin; a prose fallback for projects whose pinned output is
    # DERIVED makes it a ternary chain, and the property being asserted is unchanged — an empty
    # goldenPaths must not reach the PATH step. What this case must not accept is a step that runs
    # on an empty value, and both shapes below refuse that.
    printf '%s\n' "$code" | grep -qE 'CFG\.goldenPaths &&|\? CFG\.goldenPaths$|: CFG\.goldenPaths$' \
      || { bad=$(( bad + 1 )); cf "$lab: the drift step has no guard on CFG.goldenPaths — '??' alone does not produce a skip, it only delivers the empty string to a step that would then run against nothing"; }

    # HALF 2b — AND AN EMPTY PROSE PIN SKIPS TOO. The fallback added a second way to reach the
    # step, so it needs the same guard the first one has: a project with neither pin declared
    # must get no step at all, not a step interpolating an empty rule.
    if printf '%s\n' "$code" | grep -qE '^[[:space:]]*driftRule:'; then
      printf '%s\n' "$code" | grep -qE 'CFG\.driftRule &&|\? CFG\.driftRule$|: CFG\.driftRule$' \
        || { bad=$(( bad + 1 )); cf "$lab: driftRule is declared and the drift step does not guard on it — a project with no pin of either kind would get a step naming an empty rule, which reads to the agent as a check with nothing to check"; }
    fi

    # HALF 3 — THE STEP TELLS THE AGENT AN EMPTY MATCH IS NOT A PASS, and nothing asserted this
    # until now. Halves 1 and 2 hold the CONFIG mechanics: they prove an explicitly-emptied
    # goldenPaths skips the step. Neither says anything about the case where a pin IS declared and
    # matches NOTHING — where the diff runs, prints nothing, and reads exactly like a clean one.
    # The only thing standing between that and a recorded false pass is this sentence in the brief,
    # and a sentence no case asserts can be reworded away while every case stays green.
    printf '%s\n' "$code" | grep -qF 'treat the zero-drift step as NOT RUN' \
      || { bad=$(( bad + 1 )); cf "$lab: the drift step no longer tells the agent that an empty match is NOT RUN rather than clean — that sentence is the whole defence against a diff over nothing being recorded as a clean zero-drift result"; }
  done <<EOF
$(_shipped_runners)
EOF

  # ASSERT THE EXTRACTOR, not only the comparison. Zero runners found checks nothing and reads
  # green — the vacuous pass this sheet exists to prevent. Two is the shipped count.
  [ "$found" -ge 2 ] \
    || cf "the extractor found only $found runner(s) — expected at least 2 (wave + tranche). A count this low means the glob stopped matching, NOT that the tree is clean."

  finish "runner goldenPaths: '' SKIPS the zero-drift step — '??' default AND the CFG guard, in every shipped runner ($found runner(s) checked, $bad finding(s))"
  teardown
}

# =============================================================================
# A MINTED CARD IS UNMARKED, AND ITS FILL INSTRUCTION SURVIVES THE STRIP
# =============================================================================
# The item templates carry a KIT-CLASS: marker because a template travels. A card minted FROM one
# does not: process/EXTRACTION.md § The marker and graduation says a file whose class has become
# PROJECT loses its marker, and a card's class becomes PROJECT at the moment of minting. The minting
# scripts used to `cp` the template wholesale, so every live card opened by calling itself a template.
#
# BOTH DIRECTIONS ARE ASSERTED AND THE SECOND IS THE ONE THAT MATTERS. The template's marker block
# also carried a FILL instruction -- never leave an angle bracket in a live card -- which is still in
# force while the author fills the card, and which is stated NOWHERE ELSE in the kit. So a case that
# asserted only "the marker is gone" would pass over a strip that deleted the guidance with it. The
# scripts REPLACE the block for that reason; this case is what holds them to it.
#
# THE ASSERTION IS ANCHORED AT LINE START (`^<!-- KIT-CLASS:`), not a bare substring, because the
# replacement head talks ABOUT classification. An unanchored match on the marker key would redden on
# a correct card -- and the head is deliberately worded to avoid the key at all, so this anchoring is
# a second belt rather than the only one.
case_minted_card_is_unmarked() {
  cf_reset
  # THE FIXTURE IS kit_init_sandbox, NOT make_sandbox, and this is a measured correction rather than
  # a preference: a bare sandbox carries no .claude/templates/, so every creation script exits 1 and
  # the case fails on SETUP while looking like a finding. This file already records that trap at the
  # creation-script fixtures ("against a sandbox with no templates — and every creation script then
  # exited 1"); the first version of this case walked into it, and BOTH its ablation controls failed
  # identically, which is how it was caught — a case whose red and its control's red are the same
  # red is measuring nothing.
  if ! has_kit_init; then
    skp "minted card: no travel marker, fill instruction kept" "scripts/kit-init.sh absent"; return
  fi
  if ! has_issue_template; then skp "minted card: no travel marker, fill instruction kept" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox

  local out rc card id="$SB_PREFIX-701"
  out="$(cd "$SB_WORK" && ./scripts/new-issue.sh unmarked-probe --id "$id" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { cf "new-issue.sh exited $rc minting $id: $out"; finish "minted card: no travel marker, fill instruction kept"; teardown; return; }
  card="$SB_WORK/progress/todo/$id-unmarked-probe.md"
  [ -f "$card" ] || { cf "new-issue.sh did not create progress/todo/$id-unmarked-probe.md: $out"; finish "minted card: no travel marker, fill instruction kept"; teardown; return; }

  # (1) THE CLASSIFICATION IS GONE.
  ! grep -qE '^<!-- KIT-CLASS:' "$card" \
    || cf "the minted card still opens with a KIT-CLASS: marker — it is a live card, not a template, and its class became PROJECT at mint"

  # (2) THE STILL-IN-FORCE INSTRUCTION SURVIVED. This is the half a blind strip breaks.
  grep -qi 'never leave one in a live card' "$card" \
    || cf "the minted card lost the fill instruction that came with the marker block — a blind strip took the guidance with the classification, and no other file in the kit states it"

  # (3) THE CARD DECLARES ITS OWN UNMARKED-NESS, so a bare absence is not mistaken for an oversight.
  grep -qi 'no travel-classification marker' "$card" \
    || cf "the minted card does not say its lack of a marker is deliberate — an absence nobody declared reads as a file somebody forgot"

  # (4) THE TEMPLATE IS UNTOUCHED. The strip must not reach back into the thing that travels.
  grep -qE '^<!-- KIT-CLASS:' "$SB_WORK/.claude/templates/ISSUE.template.md" \
    || cf "the template LOST its own marker — a template travels and must keep it; the strip reached the wrong file"

  # (5) EVERY MINTING SCRIPT CARRIES THE RE-HEAD, with a control on the extractor. Driving all five
  # in one case would be slow; a script that silently loses the block is the regression to catch, and
  # zero-found must not read as clean.
  local mfound=0 msh
  for msh in new-issue.sh new-bug.sh new-prd.sh new-refactor.sh subtask.sh; do
    [ -f "$SB_WORK/scripts/$msh" ] || continue
    mfound=$(( mfound + 1 ))
    # THE ASSERTION FOLLOWS THE AUTHORING SITE. It used to look for the comment 'RE-HEAD
    # THE CARD', which each script carried because each script carried the whole block.
    # The block is one library now, so the thing to assert is that the script CALLS it —
    # a census keyed to text that moved is a census of nothing.
    grep -q 'kit_rehead_card' "$SB_WORK/scripts/$msh" \
      || cf "scripts/$msh does not re-head the card it mints — its cards will open by calling themselves templates"
    # NON-COMMENT LINES ONLY. Measured while building this: every one of these scripts
    # MENTIONS the library in a comment, so a bare grep passes on a script whose sourcing
    # has been deleted — which is precisely the regression this arm exists for.
    awk '!/^[[:space:]]*#/ && /card-head\.sh/ { found=1 } END { exit !found }' "$SB_WORK/scripts/$msh" \
      || cf "scripts/$msh calls kit_rehead_card and never SOURCES scripts/lib/card-head.sh (a comment mentioning it does not count) — it would fail at mint time with 'command not found', after the card is already written"
  done
  [ "$mfound" -ge 5 ] \
    || cf "the extractor found only $mfound minting script(s) — expected at least 5. A count this low means the list stopped matching the tree, NOT that the tree is clean."

  finish "minted card: no travel marker, fill instruction kept, template untouched ($mfound minting script(s) checked)"
  teardown
}

# =============================================================================
# EVERY SHIPPED RUNNER MUST PARSE
# =============================================================================
# wave-runner.js did not parse for several releases: a paragraph of narration inside a returned
# template literal put backticks around a field name, terminated the literal, and made the whole file
# unloadable. It shipped in a released zip. Nothing caught it, because nothing in the kit parsed these
# files -- not the harness, not the build guard (which reads citations and armed names), and `bash -n`
# cannot read a .js file at all.
#
# THE DISCRIMINATION THAT MAKES THIS CHECKABLE, and it is the whole reason this case can exist: these
# runners are NOT standalone modules. The harness executes their body inside an async wrapper, so a
# top-level `return` is legal there and illegal to any standalone parser. A healthy runner therefore
# FAILS a plain parse -- with exactly `Illegal return statement`. A broken one fails with something
# else. So the assertion is not "it parses"; it is "the ONLY parse error is the dialect one".
#   healthy: SyntaxError: Illegal return statement      <- expected, tolerated
#   broken:  SyntaxError: Unexpected identifier '...'   <- the real thing, refused
# An earlier attempt to guard this class was abandoned as unworkable precisely because the healthy
# files fail; the mistake was reading "it fails" instead of reading WHICH failure. Do not simplify
# this back into a bare `node --check` and a rc test.
#
# NODE IS NOT A KIT DEPENDENCY, so this SKIPS -- loudly, naming why -- where node is absent. A skip
# that says nothing is indistinguishable from a pass, so the skip reason names the binary.
case_shipped_runners_parse() {
  cf_reset
  if ! command -v node >/dev/null 2>&1; then
    skp "shipped runners parse (only the harness-dialect error is tolerated)" "node is not on PATH, and the kit does not require it -- this case cannot run here"
    return
  fi
  make_sandbox   # for SB_TMP + teardown; this case reads the REAL shipped runners

  local f lab found=0 out rc
  for f in "$REAL_REPO_ROOT"/_claude/workflows/*.js "$REAL_REPO_ROOT"/.claude/workflows/*.js; do
    [ -e "$f" ] || continue
    lab="$(basename "$f")"
    found=$(( found + 1 ))
    out="$(node --input-type=module --check < "$f" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then
      continue   # parses outright; fine, and means the file has no top-level return
    fi
    # The ONE tolerated failure. Anything else is a real lexical or structural break.
    if printf '%s\n' "$out" | grep -q 'Illegal return statement'; then
      continue
    fi
    cf "$lab does NOT parse, and the failure is not the tolerated harness-dialect one: $(printf '%s' "$out" | grep -m1 'SyntaxError' || printf '%s' "$out" | head -1). A runner that cannot be loaded fails at 0 agents for every adopter who drives it."
  done

  # ASSERT THE EXTRACTOR. Zero runners found checks nothing and reads green.
  [ "$found" -ge 2 ] \
    || cf "the extractor found only $found runner(s) -- expected at least 2 (wave + tranche). A count this low means the glob stopped matching, NOT that the tree is clean."

  finish "shipped runners parse -- only the harness-dialect error is tolerated ($found runner(s) checked)"
  teardown
}

# =============================================================================
# THE INDEX INSERT MUST REFUSE A MALFORMED INDEX, not mis-write it
# =============================================================================
# WHY (reproduced from an adopter following a recipe that omitted the separator): the
# insert prints the header, then READS THE NEXT LINE and reprints it as the separator.
# If that line is not a separator, the file's FIRST DATA ROW is consumed into the
# separator's position and the new row lands SECOND — silently breaking the newest-first
# ordering the index exists to provide. And `grep -qF` on the header ACCEPTED that file:
# a presence check standing in for a well-formedness check, which is the guard looking
# slightly to the left of the defect (instruments.md § A.6).
#
# BOTH FIXTURES ARE HAND-WRITTEN, DELIBERATELY. The sibling index case builds its index
# by RUNNING THE SCRIPT, so it only ever meets the well-formed shape — a guard measured
# against its author's own output is measuring the author. The malformed shape cannot be
# produced by the code under test, so it has to be typed here.
#
# AND THE FAILURE UNDER TEST IS A WRITE THAT HAPPENED, so a non-zero exit is not enough:
# the control asserts the file is BYTE-UNCHANGED. The well-formed control is the other
# half — without it, an unconditional refusal would pass the first assertion.
_ap_seed_small_log() {  # <repo>
  { echo "# progress.md"; echo ""; echo "## Log"; echo ""
    echo "## 2026-08-20 [Dev] one"; echo "body"; echo ""
    echo "## 2026-08-21 [Dev] two"; echo "body"; echo ""
  } > "$1/progress.md"
}

case_archive_index_refuses_malformed() {
  cf_reset
  make_sandbox
  local R="$SB_TMP/apm" out rc before
  mkdir -p "$R/progress/history"

  # ── A. MALFORMED: header present, NO separator, a real data row underneath.
  _ap_seed_small_log "$R"
  cat > "$R/progress/history/INDEX.md" <<'IDXEOF'
# rotation index

| Chunk | Covers | Entries | Rotated | Cut |
| [`old.md`](old.md) | 2026-01-01 → 2026-01-02 | 5 | 2026-01-03 | `--before 2026-01-03` |
IDXEOF
  before="$(mktemp)"; cp "$R/progress/history/INDEX.md" "$before"

  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" \
            --milestone mal --keep-last 1 --apply 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(A) a malformed index did NOT refuse — exit 0: $out"
  printf '%s' "$out" | grep -q 'MALFORMED' \
    || cf "(A) the refusal does not name the file as malformed: $out"
  printf '%s' "$out" | grep -qF 'old.md' \
    || cf "(A) the refusal does not quote the offending line it found — a drift reported without saying what drifted sends the reader to diff by eye: $out"
  # THE LOAD-BEARING ASSERTION: the failure under test is a WRITE, so proving it
  # refused is not proving it did not write.
  diff -q "$before" "$R/progress/history/INDEX.md" >/dev/null 2>&1 \
    || cf "(A) the index was MODIFIED on a run that refused — the malformed file was mis-written anyway"
  # And it must not have helpfully repaired the file by inserting a separator.
  grep -qF '|---|' "$R/progress/history/INDEX.md" \
    && cf "(A) it inserted the separator itself — the index is the adopter's record, not the tool's to repair"
  rm -f "$before"

  # ── B. WELL-FORMED: must still insert, and FIRST. Without this half, a script that
  #      refused unconditionally would pass (A) and look correct.
  rm -rf "$R"; mkdir -p "$R/progress/history"
  _ap_seed_small_log "$R"
  cat > "$R/progress/history/INDEX.md" <<'IDXEOF'
# rotation index

| Chunk | Covers | Entries | Rotated | Cut |
|---|---|---|---|---|
| [`old.md`](old.md) | 2026-01-01 → 2026-01-02 | 5 | 2026-01-03 | `--before 2026-01-03` |
IDXEOF
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" \
            --milestone good --keep-last 1 --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(B) a WELL-FORMED index was refused — exit $rc: $out"
  local first_row
  first_row="$(grep -m1 '^| \[' "$R/progress/history/INDEX.md")"
  printf '%s' "$first_row" | grep -qF 'good.md' \
    || cf "(B) the new row is not first (newest-first is format law): $first_row"
  grep -qF 'old.md' "$R/progress/history/INDEX.md" \
    || cf "(B) the pre-existing row was lost — the index is append-only"

  finish "archive-progress.sh: a MALFORMED index refuses with the file byte-unchanged and un-repaired; a well-formed one still inserts newest-first"
  teardown
}

case_archive_index_carries_the_date() {
  cf_reset
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-250" dated chore "Dated retirement"
  publish_sandbox

  local out rc entry today
  today="$(date +%Y-%m-%d)"
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "archive.sh --apply exited $rc: $out"
  entry="$(grep "$SB_PREFIX-250" "$SB_WORK/ARCHIVE.md" || true)"
  [ -n "$entry" ] || cf "$SB_PREFIX-250 was not indexed at all: $(cat "$SB_WORK/ARCHIVE.md")"
  printf '%s' "$entry" | grep -qE 'retired [0-9]{4}-[0-9]{2}-[0-9]{2}' \
    || cf "the index entry carries no retirement date — § 2 requires the date beside the id and title: $entry"
  printf '%s' "$entry" | grep -q "retired $today" \
    || cf "the retirement date is not today's ($today): $entry"
  # The id stays the FIRST token: next-id.sh documents these entries as
  # `- <PREFIX>-NNN …` and reads them so a new mint cannot collide with an archived
  # id. If the date ever migrates to the front, that convention breaks silently and
  # a re-minted id is the symptom, a long way from the cause.
  printf '%s' "$entry" | grep -qE "^- $SB_PREFIX-250 " \
    || cf "the entry no longer begins '- $SB_PREFIX-250 ' — next-id.sh reads this shape to avoid re-minting an archived id: $entry"
  # THE PREVIEW AND THE APPLIED ENTRY MUST AGREE. They are built from one string in
  # the script; this holds that true from outside, because a preview that understates
  # what will be written is how a bulk irreversible op gets approved.
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "the dry run exited $rc: $out"

  # --- ABLATION: remove the date write and the assertion above must fail -----
  local a_script="$SB_WORK/scripts/archive.sh" n
  n="$(grep -c 'ENTRY="${ENTRY} — retired ${RETIRED_ON}"' "$a_script" || true)"
  if [ "$n" != "1" ]; then
    cf "(control) expected exactly 1 date-append line in archive.sh to ablate, found $n — the anchor moved and this ablation proves nothing"
  else
    make_sandbox
    seed_issue qa_complete "$SB_PREFIX-251" ablated chore "Ablated retirement"
    perl -i -ne 'print unless /^\s*ENTRY="\$\{ENTRY\} — retired \$\{RETIRED_ON\}"\s*$/' "$SB_WORK/scripts/archive.sh"
    grep -q 'retired ${RETIRED_ON}' "$SB_WORK/scripts/archive.sh" \
      && cf "(control) the ablation did not remove the date write"
    bash -n "$SB_WORK/scripts/archive.sh" || cf "(control) the ablated archive.sh no longer parses"
    publish_sandbox
    out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )"; rc=$?
    [ "$rc" -eq 0 ] || cf "(control) the ablated archive.sh exited $rc — the ablation broke more than the date: $out"
    entry="$(grep "$SB_PREFIX-251" "$SB_WORK/ARCHIVE.md" || true)"
    printf '%s' "$entry" | grep -qE 'retired [0-9]{4}-[0-9]{2}-[0-9]{2}' \
      && cf "(control) the ABLATED script still produced a retirement date — the assertion above is not measuring the date write: $entry"
  fi

  finish "archive.sh: the index entry carries its retirement date (§ 2) with the id still leading, preview and apply agree, and the assertion fails when the date write is ablated"
  teardown
}

# =============================================================================
# CASE — THE RETIRED STORE IS REQUIRED, NOT MANUFACTURED (both directions).
#
# archive-sweep.md § 3: "The retired store or the index is missing ⇒ refuse; do not
# create an index on the fly." The script honoured that for the index and `mkdir -p`'d
# the store — so it manufactured the board topology it was operating within, and
# because board-mover.md's first invariant is "the container IS the status", an
# invented container is an invented status. A mistyped or renamed column became a new
# column holding real retired work.
#
# BOTH DIRECTIONS: the refusal must fire AND MUST CREATE NOTHING, and a board that
# does have the column must still archive normally — otherwise the fix is an
# unconditional refusal, which passes the first assertion and breaks the tool.
# =============================================================================
case_archive_requires_the_retired_store() {
  cf_reset

  # --- (i) the store is ABSENT: refuse, and create nothing -------------------
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-260" nostore chore "No retired store"
  rm -rf "$SB_WORK/progress/done"
  publish_sandbox
  [ ! -d "$SB_WORK/progress/done" ] \
    || cf "(control) progress/done/ still exists locally — the premise of half (i) does not hold"

  local out rc kwt_done
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(i) archive.sh --apply SUCCEEDED with no progress/done/ — it manufactured the column: $out"
  printf '%s\n' "$out" | grep -qi 'progress/done' \
    || cf "(i) the refusal does not name the absent store: $out"
  printf '%s\n' "$out" | grep -qi 'REFUSING' \
    || cf "(i) the message does not say it is refusing: $out"
  printf '%s\n' "$out" | grep -q '\.gitkeep' \
    || cf "(i) the refusal does not print the deliberate creation recipe (a bare refusal leaves the operator to invent one, and an empty dir does not survive a clone): $out"
  # AND IT CREATED NOTHING — the assertion that separates "refused" from "refused
  # after doing the thing". Checked in the kanban worktree too, which is where this
  # script actually operates and therefore where a stray mkdir would land.
  kwt_done="$SB_WORK/.kanban-wt/progress/done"
  [ ! -d "$SB_WORK/progress/done" ] || cf "(i) the refusal still created progress/done/ in the checkout"
  [ ! -d "$kwt_done" ] || cf "(i) the refusal still created progress/done/ inside the kanban worktree"
  [ -f "$SB_WORK/progress/qa_complete/$SB_PREFIX-260-nostore.md" ] \
    || cf "(i) the card left qa_complete/ during a refusal"
  teardown

  # --- (ii) the store is PRESENT: archive normally ---------------------------
  # Without this the fix could be an unconditional refusal and half (i) would still
  # pass. It is the same shape as the UNRUNNABLE case's second direction.
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-261" hasstore chore "Has retired store"
  [ -d "$SB_WORK/progress/done" ] || cf "(control) the sandbox has no progress/done/ — half (ii) cannot test the happy path"
  publish_sandbox
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(ii) archive.sh --apply exited $rc on a board that HAS done/ — the refusal is unconditional: $out"
  [ -f "$SB_WORK/progress/done/$SB_PREFIX-261-hasstore.md" ] \
    || cf "(ii) the card was not moved into done/: $out"
  grep -q "$SB_PREFIX-261" "$SB_WORK/ARCHIVE.md" || cf "(ii) the card was not indexed: $out"

  finish "archive.sh: an absent retired store REFUSES, names it, prints the .gitkeep creation recipe and creates nothing (checkout and kanban worktree both) — while a board that has done/ still archives normally"
  teardown
}

case_archive_feature_branch_clean() {
  cf_reset
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-202" gamma chore "Archive gamma"
  publish_sandbox
  git -C "$SB_WORK" checkout -b "feature/$SB_PREFIX-999-work" "$SB_TRUNK" --quiet >/dev/null 2>&1

  local out rc
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )"; rc=$?

  [ "$rc" -eq 0 ] || cf "archive.sh --apply exited $rc: $out"
  local dirty
  dirty="$(git -C "$SB_WORK" status --porcelain -- progress ARCHIVE.md 2>/dev/null)"
  [ -z "$dirty" ] || cf "feature branch tree dirty after the sweep: $dirty"
  origin_has_path "progress/done/$SB_PREFIX-202-gamma.md" || cf "sweep not visible on the trunk"

  finish "archive.sh --apply from a feature branch leaves its tree clean"
  teardown
}

# =============================================================================
# CASE — THE CONFIG SEAM REFUSES RATHER THAN FALLING BACK.
#
# This case was INVERTED, not deleted, and the reason it exists is unchanged. It
# used to assert the opposite: that with config.sh unsourceable each script fell
# back to a baked-in prefix literal and CARRIED ON. That fallback was added as a
# fix for something worse (a default carrying a FOREIGN project's prefix), and the
# lesson it encoded — a silently wrong prefix is the expensive failure — is the
# same lesson the refusal now encodes, one level up: EVERY script holding its own
# copy of one project's prefix IS the silently-wrong-prefix bug (derive the set —
# grep -l 'config.sh' scripts/*.sh — rather than trusting a count here; this said
# "five" and was true when written), and in the sweep
# it is worse than a bad mint (a sweep under the wrong prefix finds nothing and
# reports "nothing to sweep" on a full column). So the conclusion is superseded
# and the guard is transformed: every one of them must now REFUSE and NAME
# config.sh. ALL of them are asserted, because fixing one in isolation would
# leave the rest inconsistent — which is exactly how the debt survived.
# =============================================================================
case_config_seam_refusal() {
  cf_reset
  if ! has_issue_template; then skp "the config seam REFUSES with a named cause across every prefix consumer" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-203" delta chore "Archive delta"
  publish_sandbox
  # Make config.sh unsourceable — the degraded path under test.
  mv "$SB_WORK/scripts/config.sh" "$SB_WORK/scripts/config.sh.disabled" >/dev/null 2>&1

  # THE CENSUS IS RUN AGAINST THE SANDBOX'S scripts/, and that is load-bearing rather
  # than incidental: THIS FILE also contains the census phrase — it is quoted on the
  # line below — so a tree-wide grep returns one more than there are consumers. The
  # sandbox has no scripts/test (make_sandbox removes it), so the list here is the
  # consumers and nothing else. A reader who greps the whole tree and gets a bigger
  # number has not found a miscount.
  #
  # THE POPULATION IS DERIVED, NOT TYPED. `new-prd.sh` was the sixth prefix consumer
  # and sat outside this loop for as long as the loop was a hand-written list — while
  # the case's own finish string claimed a five-member population. Deriving it from the census
  # the block itself publishes makes the loop and the grep the same set by construction,
  # which is the property that was missing rather than the sixth name.
  local s out rc n_consumers=0
  local consumers; consumers="$(cd "$SB_WORK/scripts" && grep -ln 'THE PREFIX HAS ONE AUTHORITY' ./*.sh 2>/dev/null | sed 's@^\./@@' | sort)"
  [ -n "$consumers" ] \
    || _fixture_die "case_config_seam_refusal: no script in the sandbox carries the prefix-authority block — the census pattern moved, so this loop would assert nothing while reporting a pass."
  for s in $consumers; do
    n_consumers=$(( n_consumers + 1 ))
    case "$s" in
      archive.sh)      out="$( cd "$SB_WORK" && env -u ISSUE_PREFIX "$SB_WORK/scripts/$s" --apply 2>&1 )"; rc=$? ;;
      next-id.sh)      out="$( cd "$SB_WORK" && env -u ISSUE_PREFIX "$SB_WORK/scripts/$s" 2>&1 )"; rc=$? ;;
      # new-prd.sh takes <slug> and no --id, and its seam is PRD_PREFIX rather than
      # ISSUE_PREFIX — the one consumer whose output lands in requirements/.
      new-prd.sh)      out="$( cd "$SB_WORK" && env -u PRD_PREFIX "$SB_WORK/scripts/$s" someslug 2>&1 )"; rc=$? ;;
      *)               out="$( cd "$SB_WORK" && env -u ISSUE_PREFIX "$SB_WORK/scripts/$s" someslug --id "$SB_PREFIX-900" 2>&1 )"; rc=$? ;;
    esac
    [ "$rc" -ne 0 ] || cf "$s: exited 0 with config.sh unsourceable — it fell back instead of refusing"
    printf '%s' "$out" | grep -q 'config\.sh' \
      || cf "$s: the refusal does not NAME scripts/config.sh: $out"
  done

  # THE SECOND ARM, which only one consumer has: config.sh present and SOURCEABLE but
  # the seam empty must ALSO refuse and name it. Restore the seam file, blank the value.
  mv "$SB_WORK/scripts/config.sh.disabled" "$SB_WORK/scripts/config.sh" >/dev/null 2>&1
  if [ -f "$SB_WORK/scripts/new-prd.sh" ]; then
    # WHAT CARRIES THIS ARM, STATED so nobody reads the rc check as the assertion: in a
    # sandbox there is no PRD template, so new-prd.sh would exit non-zero on that alone
    # and the `rc -ne 0` check below CANNOT FAIL here. The arm is carried entirely by the
    # naming check — that the refusal says PRD_PREFIX rather than something else. The rc
    # check stays because it is free and would matter in a tree that has the template.
    #
    # BLANK THE SEAM, NOT THE ENVIRONMENT. config.sh reads PRD_PREFIX="${PRD_PREFIX:-PRD}",
    # so an empty env var is replaced by the default and the guard never fires — measured:
    # the run got as far as the template check and reported that instead. The empty seam
    # has to be empty IN THE FILE, which is also the state an adopter can actually reach.
    perl -i -pe 's{^PRD_PREFIX=.*$}{PRD_PREFIX=""}' "$SB_WORK/scripts/config.sh"
    grep -qxF 'PRD_PREFIX=""' "$SB_WORK/scripts/config.sh" \
      || _fixture_die "case_config_seam_refusal: could not blank PRD_PREFIX in the sandbox's config.sh — the empty-seam arm would test a populated seam."
    out="$( cd "$SB_WORK" && "$SB_WORK/scripts/new-prd.sh" someslug 2>&1 )"; rc=$?
    [ "$rc" -ne 0 ] \
      || cf "new-prd.sh: exited 0 with a sourceable config.sh and an EMPTY PRD_PREFIX — the second arm does not refuse"
    printf '%s' "$out" | grep -q 'PRD_PREFIX' \
      || cf "new-prd.sh: the empty-seam refusal does not NAME PRD_PREFIX: $out"
  fi
  mv "$SB_WORK/scripts/config.sh" "$SB_WORK/scripts/config.sh.disabled" >/dev/null 2>&1

  # And nothing happened: the sweep did not run, and no card was minted.
  origin_has_path "progress/qa_complete/$SB_PREFIX-203-delta.md" \
    || cf "the refused sweep moved the file anyway"
  [ -z "$(find "$SB_WORK/progress" -name "$SB_PREFIX-900-*.md" 2>/dev/null)" ] \
    || cf "a refused creation script minted a file anyway"
  # new-prd.sh mints into requirements/, not progress/ — so the two checks above do not
  # cover the one consumer whose output lands somewhere else. Asserting refusal without
  # asserting inaction is half a measurement.
  # VACUOUS ON A CLEAN RUN, and that is the honest description: the sandbox has no
  # requirements/ at all, so `find` over a missing directory finds nothing whatever the
  # script did. It bites the moment anything CREATES that directory — which is exactly
  # the mint this asserts against — so it is a real assertion with a stated blind spot,
  # not a green that could never go red. Its control planted precisely that.
  [ -z "$(find "$SB_WORK/requirements" -name '*someslug*' 2>/dev/null)" ] \
    || cf "a refused new-prd.sh minted into requirements/ anyway"

  finish "the config seam REFUSES with a named cause across every prefix consumer the block's own census returns ($n_consumers asserted: $(printf '%s' "$consumers" | tr '\n' ' ')), the empty-seam arm refuses too, and nothing is minted in progress/ or requirements/"
  teardown
}

# =============================================================================
# CASE — next-id.sh
# =============================================================================
case_next_id() {
  cf_reset
  local out rc err
  # (1) max+1 across progress/** filenames.
  make_sandbox
  seed_issue todo "$SB_PREFIX-001" one   chore "one"
  seed_issue todo "$SB_PREFIX-003" three chore "three"
  publish_sandbox
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/next-id.sh" 2>/dev/null )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(max+1) exited $rc"
  [ "$out" = "$SB_PREFIX-004" ] || cf "(max+1) expected $SB_PREFIX-004 across filenames, got '$out'"
  printf '%s' "$out" | grep -qE "^$SB_PREFIX-[0-9]{3}$" || cf "(shape) output '$out' is not <PREFIX>-NNN shaped"
  teardown

  # (2) it counts ARCHIVE.md entries too — the number must not reset after a sweep.
  make_sandbox
  publish_sandbox
  printf -- "- %s-009 [chore] archived issue\n" "$SB_PREFIX" >> "$SB_WORK/ARCHIVE.md"
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/next-id.sh" 2>/dev/null )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(ARCHIVE) exited $rc"
  [ "$out" = "$SB_PREFIX-010" ] || cf "(ARCHIVE) expected $SB_PREFIX-010 from the ARCHIVE.md max, got '$out'"
  teardown

  # (3) genuinely undeterminable → nonzero + an explanatory stderr message. THE
  #     CONTRACT, not a gap: where no id has ever been issued, choosing where
  #     numbering starts is a DECISION.
  make_sandbox
  publish_sandbox
  err="$( cd "$SB_WORK" && "$SB_WORK/scripts/next-id.sh" 2>&1 1>/dev/null )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(empty) expected nonzero exit on an empty board, got 0"
  printf '%s' "$err" | grep -qi 'no existing' || cf "(empty) no explanatory stderr message: '$err'"
  teardown

  finish "next-id.sh: max+1 (filenames + ARCHIVE.md), <PREFIX>-NNN shape, nonzero on an empty board"
}

# =============================================================================
# CASE — the commit-msg hook
# =============================================================================
case_commit_msg() {
  cf_reset
  make_sandbox
  local hook="$SB_WORK/scripts/githooks/commit-msg"
  local msg="$SB_TMP/msg.txt"

  # DERIVE the accepted prefixes from the hook's own ROLE_PREFIXES line — do NOT
  # re-hardcode them, or a set change makes these assertions vacuous.
  local prefixes
  # THE CANONICAL EXPRESSION, byte-identical to lib/role-set.sh's kit_role_set and to the
  # other three sites. It used to carry a trailing `.*`, which silently tolerated content
  # after the closing quote that no other reader accepts — the kind of divergence that
  # makes two sites disagree about the same file with nothing in either to show it.
  # FALLBACK POLICY HERE: cf (a case finding). The set is derived to keep the assertions
  # below non-vacuous, so an unreadable hook makes this case meaningless, not skippable.
  prefixes="$(sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p" "$hook" | head -1)"
  [ -n "$prefixes" ] || cf "could not derive ROLE_PREFIXES from the hook"

  local IFS='|' p rc
  for p in $prefixes; do
    printf '[%s] a valid subject\n' "$p" > "$msg"
    ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 0 ] || cf "prefix [$p] rejected (exit $rc)"
  done
  unset IFS

  # Auto-exempt subjects (git/host-generated).
  local exempt=("Merge branch 'x'" "Revert \"something\"" "fixup! earlier commit")
  local s
  for s in "${exempt[@]}"; do
    printf '%s\n' "$s" > "$msg"
    ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 0 ] || cf "auto-exempt subject rejected: '$s' (exit $rc)"
  done

  # Unprefixed subject → rejected, and the rejection LISTS the legal tags (which
  # it derives, so the help text cannot lie about the set).
  printf 'no role prefix at all\n' > "$msg"
  local out
  out="$( env -u MSG_OK "$hook" "$msg" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "unprefixed subject accepted (must be rejected)"
  printf '%s' "$out" | grep -q "\[${prefixes%%|*}\]" \
    || cf "the rejection message does not list the derived role tags: $out"

  # The applypatch path judges a subject the SAME way (git am runs that hook, not
  # commit-msg, and its mailinfo strips bracketed tags).
  printf 'no role prefix at all\n' > "$msg"
  ( env -u MSG_OK "$SB_WORK/scripts/githooks/applypatch-msg" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] || cf "applypatch-msg accepted an unprefixed subject (the am path must not be a hole)"

  # --- § A.1: no generated co-author trailer, and no "Generated with …" line ------
  # DERIVE the markers from the hook's own TOOL_TRAILER_MARKERS line, for the same
  # reason the prefixes are derived: a project extends that list, and a restated
  # copy here would make these assertions vacuous the day it does.
  #
  # WHAT DERIVING COSTS, STATED because a reddening control measured it: this arm
  # asserts THE RULE WORKS FOR WHATEVER MARKERS ARE DECLARED — not that the declared
  # set is the right one. Replace TOOL_TRAILER_MARKERS with a single word that matches
  # nothing real and every assertion below still passes, because the arm then tests the
  # hook against that word. Only the empty case is caught, by the derivation check. So
  # a NARROWED marker list is invisible here by construction; what this arm defends is
  # the enforcement, and deleting RULE (2) from the hook is what reddens it.
  local role markers marker
  role="${prefixes%%|*}"
  markers="$(sed -n "s/^TOOL_TRAILER_MARKERS='\\(.*\\)'.*/\\1/p" "$hook")"
  [ -n "$markers" ] || cf "could not derive TOOL_TRAILER_MARKERS from the hook"
  marker="${markers%%|*}"
  # The refusal prints that list VERBATIM, so it must stay plain words — a regex
  # metacharacter in it would be a lie in the help text and a live pattern in the match.
  printf '%s' "$markers" | grep -qE '^[a-z0-9|]+$' \
    || cf "(trailer) TOOL_TRAILER_MARKERS is not the plain-word list the refusal prints: '$markers'"

  # `git commit -v` hands the hook the RAW DIFF below the scissors line — uncommented,
  # context lines carrying one leading space. Editing a file that contains a trailer is
  # not writing one, so this must be ACCEPTED. (\x escapes keep this file ASCII; the
  # emoji is there because the shape the tooling emits leads with decoration, not with
  # the word "Generated".)
  printf '[%s] a valid subject\n\n# ------------------------ >8 ------------------------\n# Do not modify or remove the line above.\ndiff --git a/doctrine b/doctrine\n--- a/doctrine\n+++ b/doctrine\n@@ -1 +1,2 @@\n Co-Authored-By: %s <noreply@example.com>\n+\xf0\x9f\xa4\x96 Generated with [Some Tool](https://example.com)\n' "$role" "$marker" > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] || cf "(trailer) a \`commit -v\` message was refused for the DIFF below its scissors line (exit $rc)"

  # A clean multi-line message is ACCEPTED — including a HUMAN co-author trailer and the
  # words in prose. A guard that rejected every message with a body would pass a
  # one-directional test.
  printf '[%s] a valid subject\n\nA body that explains why, and mentions a file generated with the codegen step.\n\nCo-authored-by: A Person <person@example.com>\n' "$role" > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] || cf "(trailer) a clean multi-line message with a HUMAN co-author was rejected (exit $rc)"

  # A tool-naming trailer is REJECTED, and the refusal names the rule and the markers.
  printf '[%s] a valid subject\n\nCo-Authored-By: %s <noreply@example.com>\n' "$role" "$marker" > "$msg"
  out="$( env -u MSG_OK "$hook" "$msg" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(trailer) a Co-Authored-By naming '$marker' was accepted"
  printf '%s' "$out" | grep -q 'commit-hygiene.md' || cf "(trailer) the refusal does not name the rule: $out"
  printf '%s' "$out" | grep -qi "$marker" || cf "(trailer) the refusal does not list the derived markers: $out"

  # The second arm of § A.1, with the leading decoration the tooling actually emits.
  printf '[%s] a valid subject\n\n\xf0\x9f\xa4\x96 Generated with [Some Tool](https://example.com)\n' "$role" > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] || cf '(trailer) a "Generated with" line was accepted'

  # The auto-exempt subjects are exempt from the PREFIX rule only: a merge carries a body.
  printf "Merge branch 'x'\n\nCo-Authored-By: %s <noreply@example.com>\n" "$marker" > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] || cf "(trailer) an auto-exempt SUBJECT carried a tool trailer through — that exemption is the prefix rule's only"

  # The am path judges the trailer the same way, or the import entrance is a hole.
  printf '[%s] a valid subject\n\nCo-Authored-By: %s <noreply@example.com>\n' "$role" "$marker" > "$msg"
  ( env -u MSG_OK "$SB_WORK/scripts/githooks/applypatch-msg" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] || cf "(trailer) applypatch-msg accepted a tool trailer (the am path must not be a hole)"

  # The documented escape still works, because importing a third party's commit verbatim
  # is the case it exists for.
  printf '[%s] a valid subject\n\nCo-Authored-By: %s <noreply@example.com>\n' "$role" "$marker" > "$msg"
  ( MSG_OK=1 "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] || cf "(trailer) MSG_OK=1 did not bypass the trailer rule (the documented import escape)"

  finish "commit-msg: accepts every derived role prefix + the auto-exempt set, rejects unprefixed; rejects a tool co-author trailer and a \"Generated with\" line on both entrances while accepting a human trailer and a \`commit -v\` diff; and applypatch-msg agrees"
  teardown
}

# =============================================================================
# CASE — a forced push failure is LOUD and nonzero (never a silent proceed).
# =============================================================================
case_push_failure() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-300" sandbox chore "Push failure"
  publish_sandbox
  # Break the remote AFTER the board is published, so the local commit succeeds
  # but the push in kwt_finalize fails.
  git -C "$SB_WORK" remote set-url origin "file://$SB_TMP/gone-$RANDOM.git" >/dev/null 2>&1

  local out rc
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-300" in_progress \
            --role Dev --note "should fail to push" 2>&1 )"; rc=$?

  [ "$rc" -ne 0 ] || cf "expected nonzero exit when the push fails, got 0"
  printf '%s' "$out" | grep -qiE 'NOT on origin|push origin HEAD|not pushed|DISCARD this commit|unreachable' \
    || cf "no loud recovery text on push failure: $out"

  finish "push failure: loud recovery text + nonzero exit (no silent proceed)"
  teardown
}

# =============================================================================
# CASE — THE TRUNK FALLBACK IS LOUD. With no <remote>/HEAD and no
# init.defaultBranch, the resolution chain reaches its last-resort literal — and
# that used to be SILENT the whole way down, so a fresh repository got a trunk
# name nobody chose and found out when the first board move pushed to it. The
# chain is kept (a hard refusal would break every read-only caller); what is
# asserted here is that each fallback step SAYS which step it used.
# =============================================================================
case_trunk_fallback_warns() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-310" sandbox chore "Trunk fallback"
  publish_sandbox
  local last_resort
  last_resort="$(sed -n 's/^KWT_TRUNK_LAST_RESORT="\${KWT_TRUNK_LAST_RESORT:-\([^}]*\)}"/\1/p' \
                   "$SB_WORK/scripts/lib/kanban-worktree.sh" | head -1)"
  [ -n "$last_resort" ] || cf "could not derive KWT_TRUNK_LAST_RESORT from the library"

  # Step 2: no <remote>/HEAD, but init.defaultBranch is set. NOTE the command:
  # <remote>/HEAD is a SYMBOLIC ref, and `update-ref -d` does not remove one — a
  # setup that used it silently left the ref in place, so the case passed by
  # never reaching the fallback at all. `symbolic-ref -d` is the one that works.
  git -C "$SB_WORK" symbolic-ref -d refs/remotes/origin/HEAD >/dev/null 2>&1 || true
  local out
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-310" in_progress \
            --role Dev --note "fallback step 2" 2>&1 )"
  printf '%s' "$out" | grep -q 'STEP 2' \
    || cf "the init.defaultBranch fallback did not name the step it used: $out"
  printf '%s' "$out" | grep -q 'remote set-head' \
    || cf "the step-2 warning does not name the one command that settles it: $out"

  # Step 3: neither is set → the last-resort literal, named as a GUESS.
  git -C "$SB_WORK" symbolic-ref -d refs/remotes/origin/HEAD >/dev/null 2>&1 || true
  git -C "$SB_WORK" config --unset init.defaultBranch >/dev/null 2>&1 || true
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-310" dev_complete \
            --role Dev --note "fallback step 3" 2>&1 )"
  printf '%s' "$out" | grep -q 'GUESS' \
    || cf "the last-resort fallback did not announce itself as a guess: $out"
  printf '%s' "$out" | grep -qF "$last_resort" \
    || cf "the last-resort warning does not name the literal it used ($last_resort): $out"

  finish "the trunk fallback chain WARNS at every step below the first, and names the literal it guessed"
  teardown
}

# =============================================================================
# CASE — archive-progress.sh rotates a mixed-format progress.md BYTE-COMPLETE.
#
# The defect this pins: the split-awk classified a Log line as archivable ONLY
# when it matched a bare date-prefixed bullet, so entries grouped under a dated
# section HEADER (with undated sub-bullets) matched nothing and fell into an
# "intentionally dropped" branch — they reached NEITHER the retained progress.md
# NOR the history chunk. Silent data loss on --apply.
#
# The reconstruction check is the byte-completeness proof: split the new
# progress.md at "## Log", splice the archived chunk (minus its YAML header)
# between the halves, and it must equal the original fixture verbatim.
# =============================================================================
case_archive_progress_sections() {
  cf_reset
  make_sandbox   # only for SB_TMP + teardown; this case uses --repo-root
  local R="$SB_TMP/ap"
  mkdir -p "$R/progress/history"

  # THE FIXTURE CARRIES ALL THREE BOUNDARY FORMS, IN THEIR REAL NESTING ORDER.
  # Note where the post-cutoff entry sits: at its OWN `## ` heading, not as a bare
  # bullet after one. That is not cosmetic — it is the nesting-precedence rule
  # under test. Once a `## DATE` section opens, every line until the next `## `
  # heading belongs to THAT section, whatever those lines look like, so a bare
  # post-cutoff bullet placed inside a pre-cutoff `## ` section is correctly
  # archived WITH it. A fixture that placed it there and then asserted retention
  # would be testing the fixture's own confusion, not the script.
  cat > "$R/progress.md" <<'EOF'
# progress.md

Preamble line, not part of the Log.

## Log

### 2026-07-19
- undated sub-bullet Z under the date-at-EOL section header

### 2026-07-20 — Old section-header entry (undated sub-bullets)
- undated sub-bullet A under the section
- undated sub-bullet B under the section

- 2026-07-21 [Dev] a bare dated bullet, the flattest form (pre-cutoff)

## 2026-07-22 [Dev] a modern top-level session heading (pre-cutoff)
- a bullet inside it
### 2026-07-23 nested under the modern heading
- a nested bullet

## 2026-07-28 [QA] a modern post-cutoff session heading (retained)
- a retained bullet inside it
EOF
  cp "$R/progress.md" "$R/original.md"

  local out rc
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" \
            --milestone mix --before 2026-07-25 --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "--apply exited $rc (expected 0): $out"

  local chunk="$R/progress/history/mix.md"
  if [ ! -f "$chunk" ]; then
    cf "--apply produced no history chunk (aborted before writing?)"
    finish "archive-progress.sh: byte-complete rotation of a mixed-format log"
    teardown; return
  fi

  local recon="$R/reconstructed.md"
  {
    sed -n '1,/^## Log[[:space:]]*$/p' "$R/progress.md"   # preamble (through "## Log")
    sed '1,6d' "$chunk"                                    # archived pre (strip the YAML header)
    sed '1,/^## Log[[:space:]]*$/d' "$R/progress.md"       # retained post
  } > "$recon"
  if ! diff -q "$R/original.md" "$recon" >/dev/null 2>&1; then
    cf "reconstruction != original — $(diff "$R/original.md" "$recon" | grep -c '^<') line(s) lost"
  fi

  # The reported count must EXACTLY MIRROR the awk routing: a dated header whose
  # date is at END-OF-LINE is a boundary (the awk arms need no trailing space), so
  # it must be counted too. A count below what was routed is the shape of the old
  # undercount.
  local reported routed
  reported="$(printf '%s\n' "$out" | sed -n 's/^Found \([0-9][0-9]*\) entries.*/\1/p')"
  routed="$(grep -cE '^## [0-9]{4}-[0-9]{2}-[0-9]{2}|^### [0-9]{4}-[0-9]{2}-[0-9]{2}|^(- )?[0-9]{4}-[0-9]{2}-[0-9]{2} ' "$chunk")"
  [ "$reported" = "$routed" ] \
    || cf "count != routed: it reported '$reported' but the awk routed '$routed' boundaries"
  grep -qxF '### 2026-07-19' "$chunk" || cf "the date-at-EOL header is missing from the history chunk"
  grep -qF -- '- undated sub-bullet A under the section' "$chunk" \
    || cf "an undated sub-bullet under a dated section header is missing from the chunk"
  grep -qF -- '- 2026-07-21 [Dev] a bare dated bullet' "$chunk" \
    || cf "the flat bare-bullet form is missing from the chunk"
  grep -qF -- '- a nested bullet' "$chunk" \
    || cf "a bullet nested under a modern top-level heading is missing from the chunk"
  # The post-cutoff SECTION and its body are RETAINED, whole.
  grep -qF '## 2026-07-28 [QA] a modern post-cutoff session heading (retained)' "$R/progress.md" \
    || cf "the post-cutoff section heading was not retained in progress.md"
  grep -qF -- '- a retained bullet inside it' "$R/progress.md" \
    || cf "the post-cutoff section's body was not retained in progress.md"
  grep -qF '2026-07-28' "$chunk" && cf "the post-cutoff section leaked into the archive chunk"

  # Idempotency: a clean re-run (fresh milestone name) finds nothing to archive.
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" \
            --milestone mix2 --before 2026-07-25 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "the idempotent re-run exited $rc (expected 0): $out"
  printf '%s' "$out" | grep -q 'Nothing to archive' \
    || cf "the idempotent re-run did not report 'Nothing to archive': $out"

  finish "archive-progress.sh: byte-complete rotation of a mixed-format log (0 lost lines), count mirrors routing, idempotent"
  teardown
}

# =============================================================================
# CASE — THE GATE RUNNER'S OWN CONTRACT.
#
# NOTE ON THE ABSENT CAPABILITY PROBE (deliberate): there is no grep-probe on
# verify.sh having any particular gate, because such a probe would turn the frame
# being gutted into a SKIP instead of a FAIL — which is the exact regression this
# case exists to catch. Everything here is pure bash.
#
# Five properties, each one a defect that has happened somewhere:
#   (a) an EMPTY gate table REFUSES (nonzero) instead of printing a green summary
#       with nothing behind it — an empty-but-passing runner silently authorises
#       every landing, because finish-pr.sh treats a green --quick as its gate;
#   (b) --list answers even an empty table (it is the question an adopter asks);
#   (c) exit codes are UNLAUNDERED: a red gate makes the run exit nonzero and the
#       summary name it;
#   (d) --quick skips the `full` class and only that;
#   (e) --scope runs the `select` gate with the selection PLUS the whole guard
#       floor, and a vanished guard is a hard stop rather than a silent shrink.
# =============================================================================
# =============================================================================
# CASE — THE VERDICT VOCABULARY HAS ONE AUTHORING SITE AND TWO PROJECTIONS.
#
# MANUAL.md § Dev → QA step 6 ratifies the verdict tokens and says outright: "Every
# schema, runner and report that carries a verdict PROJECTS this list; none of them
# re-enumerates it." Two runners carry a `const VERDICTS` array. Nothing held them to
# the ratified set, so the projection could drift from its source silently — and a
# runner whose enum is missing a member REJECTS a legitimate verdict at schema
# validation, which halts a run that had succeeded.
#
# **THIS IS ALSO THE FIRST CASE IN THIS HARNESS THAT TOUCHES THE RUNNERS AT ALL.**
# Measured before writing it: `grep -c 'wave-runner\|tranche-runner'` over this file
# returned 0. Every green until now said precisely nothing about them.
#
# BOTH SIDES ARE RE-DERIVED FROM THE FILES, never restated here — the same contract
# check-board.sh's ROLE_PREFIXES derivation follows. A test that hardcodes the list
# it is checking has two authoring sites and is the third one.
#
# AND THE EXTRACTORS ARE THEMSELVES GUARDED, because a loose one silently answers a
# different question. **The code was right and the instrument was wrong** — that
# conclusion stands and is the lesson; only its attribution is corrected here.
#
# WHAT WAS ACTUALLY MEASURED, each token against the side it really came from:
#   • `FAILED_AFTER_FIX_ROUND` is swept in by an unscoped scan OF THE RUNNERS, where
#     it is an `outcome:` value on a different field. It has NEVER appeared in
#     MANUAL.md, in any commit — so a MANUAL-side pin against it could not fire under
#     any extractor, however loose.
#   • a bare `FAIL` is swept out of THE MANUAL's prose, where the word is used as
#     narration and as a row label.
# This comment previously said the first token came from the MANUAL. It did not, and
# the definiteness was the problem: a pin was aimed at an operand that could never
# hold the token, and read as coverage. Superseded rather than deleted, because the
# shape — an instrument error attributed to the wrong side of the comparison it
# guards — is the reason the two NEGATIVE pins below now sit on the side that can
# actually fail. THE CASE HAS THREE PINS, NOT TWO, and the third is deliberately left
# where it is: the positive `PASS_AC_CORRECTED` assertion has the opposite polarity, so
# a rename cannot make it vacuous — it reddens loudly on the next run instead. It is
# untouched on purpose, and named here so a later reader can tell "excluded" from
# "overlooked".
#
# So the MANUAL side is scoped to the rows of the `| Verdict | Token |` table and the
# runner side to the `const VERDICTS` declaration, and the assertions below hold both
# to that.
# =============================================================================

# One token per line, sorted. Scoped to the ratifying TABLE, not to the section.
_verdict_tokens_manual() {  # <path to MANUAL.md>
  awk '
    /^[[:space:]]*\|[[:space:]]*Verdict[[:space:]]*\|[[:space:]]*Token[[:space:]]*\|/ { intab=1; next }
    intab && /^[[:space:]]*\|[[:space:]]*-+/ { next }
    intab && /^[[:space:]]*\|/ { if (match($0, /`[A-Z_]+`/)) print substr($0, RSTART+1, RLENGTH-2); next }
    intab { intab=0 }
  ' "$1" | sort
}
# One token per line, sorted. Scoped to the DECLARATION, not to the file.
_verdict_tokens_runner() {  # <path to a runner .js>
  sed -n "s/^const VERDICTS = \[\(.*\)\]/\1/p" "$1" | grep -oE "'[A-Z_]+'" | tr -d "'" | sort
}

case_verdict_enum_projection() {
  cf_reset
  local wf="$REAL_REPO_ROOT/.claude/workflows" manual="$REAL_REPO_ROOT/process/MANUAL.md"
  if [ ! -d "$wf" ]; then
    skp "the verdict vocabulary: one authoring site, two projections" ".claude/workflows/ absent (the kit stores it disarmed; run this from a built kit)"
    return
  fi
  [ -f "$manual" ] || { skp "the verdict vocabulary: one authoring site, two projections" "process/MANUAL.md absent"; return; }

  local ratified n_ratified
  ratified="$(_verdict_tokens_manual "$manual")"
  n_ratified="$(printf '%s\n' "$ratified" | grep -c . || true)"

  # THE INSTRUMENT FIRST. An empty or over-broad extraction would make every
  # comparison below meaningless — empty vs empty "matches", and a scan that swept in
  # neighbouring vocabulary reports a divergence that is not there.
  [ "$n_ratified" -gt 0 ] \
    || cf "no ratified verdict tokens were extracted from MANUAL.md — the '| Verdict | Token |' table moved or was renamed, and every comparison below would be vacuous"
  printf '%s\n' "$ratified" | grep -qx 'FAIL' \
    && cf "the MANUAL extractor swept in a bare FAIL — that is prose, not a ratified token: [$ratified]"
  # The one member whose absence has a recorded cost: a runner missing it cannot
  # represent a green review whose landing was correctly deferred.
  printf '%s\n' "$ratified" | grep -qx 'PASS_AC_CORRECTED' \
    || cf "the ratified set does not contain PASS_AC_CORRECTED — either the ruling changed or the extractor is wrong: [$ratified]"

  local r name projected n_projected missing extra
  for r in "$wf"/*runner*.js; do
    [ -e "$r" ] || continue
    name="$(basename "$r")"
    projected="$(_verdict_tokens_runner "$r")"
    n_projected="$(printf '%s\n' "$projected" | grep -c . || true)"
    if [ "$n_projected" -eq 0 ]; then
      # A runner with no `const VERDICTS` is not a silent pass. Either it does not
      # carry a verdict (fine, and it should say so) or the declaration moved.
      if grep -q 'verdict' "$r"; then
        cf "$name mentions a verdict but no 'const VERDICTS = [...]' declaration was found — the projection cannot be checked and this is not a pass"
      fi
      continue
    fi
    # THE PIN THAT USED TO SIT ON THE MANUAL SIDE, moved to the operand that can
    # actually hold the token. `FAILED_AFTER_FIX_ROUND` is an `outcome:` value in these
    # runners, on a different field from `const VERDICTS`, so a runner extractor that
    # read past its declaration would sweep it in — which is the instrument error that
    # was historically measured, on this side. On the MANUAL side the same pin was
    # unfalsifiable: the token has never been in that file.
    printf '%s\n' "$projected" | grep -qx 'FAILED_AFTER_FIX_ROUND' \
      && cf "$name's extractor swept in FAILED_AFTER_FIX_ROUND — that is an 'outcome' value on a DIFFERENT field, so the extractor is reading past 'const VERDICTS': [$projected]"
    if [ "$projected" != "$ratified" ]; then
      missing="$(comm -23 <(printf '%s\n' "$ratified") <(printf '%s\n' "$projected") | tr '\n' ' ')"
      extra="$(comm -13 <(printf '%s\n' "$ratified") <(printf '%s\n' "$projected") | tr '\n' ' ')"
      cf "$name's VERDICTS does not project the ratified set — missing: [${missing:-none}] extra: [${extra:-none}]. MANUAL § Dev → QA step 6 is the authoring site; the runner projects it and never re-enumerates it"
    fi
  done

  # --- THIRD LEG: THE PROSE THAT TELLS THE AGENT WHAT TO RETURN ------------------
  # The two legs above hold each runner's `const VERDICTS` to the manual's ratified
  # table. Neither reads the PROMPT, and the prompt is where the agent is actually
  # told what to send back. tranche-runner's fail branch said `return verdict=FAIL`
  # for as long as the enum has existed: not in VERDICTS, so the StructuredOutput
  # call would have been rejected at runtime, and both legs above stayed green the
  # whole time because the declaration they compare was never wrong.
  # Found by a fresh-context sweep 2026-09-03.
  local pr tok bad
  for r in "$wf"/*.js; do
    [ -f "$r" ] || continue
    name="$(basename "$r")"
    projected="$(_verdict_tokens_runner "$r")"
    [ -n "$projected" ] || continue
    # Only the instructing form. Bare "PASS/FAIL per bullet" prose is per-AC evidence,
    # a different thing on a different field, and sweeping it in would be the operand
    # error this case already carries a pin about.
    pr="$(grep -oE 'verdict[[:space:]]*=[[:space:]]*[A-Z_]+' "$r" | grep -oE '[A-Z_]+$' | sort -u || true)"
    while IFS= read -r tok; do
      [ -n "$tok" ] || continue
      printf '%s\n' "$projected" | grep -qx "$tok" \
        || cf "$name's PROMPT instructs 'verdict=$tok', which its own VERDICTS does not contain — the agent is told to return a value the schema rejects"
    done <<EOF
$pr
EOF
  done

  # Its control, separately: the leg above is vacuous if no runner instructs a verdict
  # at all, which is the state the fix left them in. Inject one that is NOT ratified
  # and require the check to name it.
  # $SB_TMP is EMPTY in this case — it calls no make_sandbox — so "$SB_TMP/pctl" is
  # "/pctl", which mkdir cannot create. The control below it already carries this
  # guard; writing a second control without it produced a red that named the
  # instrument rather than the subject.
  local pctl="$SB_TMP"
  [ -n "$pctl" ] || pctl="$(mktemp -d)"
  mkdir -p "$pctl/pctl"
  if [ -f "$wf/tranche-runner.js" ]; then
    sed 's/Do NOT fix code yourself\./Do NOT fix code yourself. return verdict=BOGUS/' \
      "$wf/tranche-runner.js" > "$pctl/pctl/tranche-runner.js"
    bad="$(grep -oE 'verdict[[:space:]]*=[[:space:]]*[A-Z_]+' "$pctl/pctl/tranche-runner.js" | grep -oE '[A-Z_]+$' | sort -u || true)"
    printf '%s\n' "$bad" | grep -qx 'BOGUS' \
      || cf "(control) the prompt extractor did not see an injected 'verdict=BOGUS' — the third leg cannot bite"
  else
    cf "(control) tranche-runner.js not found — the prompt-prose control could not run"
  fi
  rm -rf "$pctl/pctl"

  # --- REDDENING CONTROL: drop a member from a COPY and the comparison must fail --
  # Without this the loop above passes whenever both sides are equal, including when
  # the extractors are both broken in the same direction.
  local ctl="$SB_TMP"
  [ -n "$ctl" ] || ctl="$(mktemp -d)"
  mkdir -p "$ctl/vctl"
  local src="$wf/wave-runner.js"
  if [ -f "$src" ]; then
    sed "s/'PASS_AC_CORRECTED', //" "$src" > "$ctl/vctl/wave-runner.js"
    local ablated
    ablated="$(_verdict_tokens_runner "$ctl/vctl/wave-runner.js")"
    [ "$ablated" != "$ratified" ] \
      || cf "(control) dropping PASS_AC_CORRECTED from a copy of wave-runner.js did NOT change the extracted set — the extractor is not reading the declaration, so the comparison above proves nothing"
    printf '%s\n' "$ablated" | grep -qx 'PASS_AC_CORRECTED' \
      && cf "(control) the ablated copy still yields PASS_AC_CORRECTED — the ablation did not take"
    comm -23 <(printf '%s\n' "$ratified") <(printf '%s\n' "$ablated") | grep -qx 'PASS_AC_CORRECTED' \
      || cf "(control) the comparison does not name PASS_AC_CORRECTED as the missing member, so a real drift would be reported without saying what drifted"
  else
    cf "(control) wave-runner.js not found at $src — the reddening control could not run"
  fi
  rm -rf "$ctl/vctl"

  # --- REDDENING CONTROL, MANUAL SIDE: the extraction must depend on THAT TABLE ------
  # WHY THIS IS NOT THE `n_ratified > 0` GUARD ABOVE, and why a second emptiness check
  # would not do either. That guard defends the table being deleted outright, and it
  # names the table in its message, so it reads exactly like this control and is the
  # first thing a fixer finds. It is SILENT under the failure this closes: an extractor
  # that reads past the `| Verdict | Token |` table but stays inside § Dev → QA step 6
  # picks the same four tokens out of the surrounding prose, so `n_ratified` is 4, the
  # per-runner comparison is equal, and the case is green **while nothing in the run has
  # read the ratifying table**. An emptiness guard proves the extractor found something;
  # this proves it found THAT TABLE.
  #
  # It is also TOKEN-NAME-INDEPENDENT — it pins no literal, so renaming a verdict cannot
  # make it vacuous, which is the failure mode two of this case's three pins had.
  mkdir -p "$ctl/mctl"
  sed 's/|[[:space:]]*Verdict[[:space:]]*|[[:space:]]*Token[[:space:]]*|/| Xerdict | Xoken |/' \
    "$manual" > "$ctl/mctl/MANUAL.md"
  if ! grep -q '| Xerdict | Xoken |' "$ctl/mctl/MANUAL.md"; then
    cf "(control) could not corrupt the '| Verdict | Token |' header on a COPY of MANUAL.md — the ablation did not take, so the green above does not establish that the extractor reads that table"
  else
    local m_ablated
    m_ablated="$(_verdict_tokens_manual "$ctl/mctl/MANUAL.md")"
    [ "$m_ablated" != "$ratified" ] \
      || cf "(control) corrupting the ratifying table's header did NOT change the MANUAL extraction — the extractor is not anchored on that table, so it is reading the same tokens out of neighbouring prose and every comparison above is about the wrong operand: [$ratified]"
  fi
  rm -rf "$ctl/mctl"

  finish "the verdict vocabulary: every *runner*.js VERDICTS array projects MANUAL § Dev → QA step 6's ratified tokens, both sides re-derived from the files, each extractor ablation-proven against its own authority (a dropped member reddens naming itself; a corrupted table header changes the extraction)"
}

# =============================================================================
# THE GUARD-FLOOR RECONCILIATION CASES, and why they are keyed on BEHAVIOUR
#
# EVERY ASSERTION BELOW READS AN EXIT CODE AND WHICH SIDE'S ITEMS ARE NAMED — never the
# wording of a refusal. The reason is measured rather than stylistic: the classifier
# these cases replace keyed on message text and went stale in the very edit that
# IMPROVED the message. A refusal's phrasing is the part most likely to be rewritten by
# someone doing a kindness; its exit code and the identity of the list it prints are the
# contract.
#
# EVERY CASE INVOKES `--scope`, and that is a fact about where the arm LIVES rather than
# a preference. The whole guard-floor block sits inside `if [ "$SCOPED" -eq 1 ]`: a plain
# full run never reaches it. Measured — with a bare invocation every one of these cases
# reported "exit 0, expected 2" and read as one defect each in the arm under test, when the
# arm had simply not run. A case must establish which invocation reaches its subject
# before it can assert anything about that subject's behaviour.
#
# THE STATES THIS FILE EXERCISES, one case each, and the behaviour that distinguishes
# each. NO CLOSED COUNT, and that is the shape ruling on closed outcome lists, applied
# rather than a style
# choice: verify.sh's reconciliation has more distinguishable outcomes than the cases
# below exercise, so a header that counted them would be a claim about the ARM that this
# file cannot keep true — the next outcome added there would silently falsify a number
# here. The states are named by their two variables (what GUARD_SET holds, what the
# enumerator does); the run is the list.
#   (3) SPACE − SET, from the SHIPPED empty GUARD_SET  → rc 2, the enumerated guard named
#   (4) enumerator MIS-TYPED (rc 1, not 127)           → rc 2, the enumerator's OWN stderr surfaced
#   (5) enumerator succeeds and returns NOTHING        → rc 2, no reconciled claim
#   (6) SET − SPACE, two on disk, enumerator sees one  → rc 2, the UNSEEN one named
#   (7) wholly empty: no set, enumerator returns none  → rc 0, and NO reconciled claim
#   (8) DECLARED == ENUMERATED, both non-empty         → rc 0, and the reconciled claim IS
#       emitted. The positive arm, and the only state that reaches the green line: (7)
#       also exits 0, so without this one every assertion about that claim was an
#       assertion about its ABSENCE. Added after this list was written, and the list did
#       not grow with it — which is why "one case each" above is a rule to CHECK against
#       the case set, not a fact this header can keep true on its own.
#
# STATES 3 AND 7 ARE BOTH BUILT ON THE SHIPPED EMPTY GUARD_SET on purpose. That
# configuration is the one three consecutive rounds of controls never built, and it is
# what the last defect in this family died on: a fixture that always declares a
# populated set passes against it by construction.
# =============================================================================

# Add one record to the sandbox's GUARD_SET, self-asserting like _declare_gate.
_guard_declare() {  # <verify.sh> <entry>
  local v="$1" e="$2"
  grep -qE '^GUARD_SET=\($' "$v" \
    || _fixture_die "_guard_declare: no '^GUARD_SET=(' line in the sandbox's verify.sh — the anchor moved, so '$e' was NOT declared and the case would run against an empty floor."
  perl -i -pe 'BEGIN{$r=shift} $_ .= "  $r\n" if /^GUARD_SET=\($/' "$e" "$v"
  grep -qxF "  $e" "$v" \
    || _fixture_die "_guard_declare: '$e' is not in GUARD_SET after the insert."
}

# _plant_in_function <file> <function-name> <line> <case-name>
#
# THE OTHER ANCHOR FAMILY. The array-fence helpers above plant after `NAME=(`; these
# plant after `name() {`, into a sourced library. Two cases needed it and both re-typed
# the whole four-step idiom — and one of the two omitted the `bash -n`, which is the step
# that distinguishes "the plant changed the behaviour" from "the library no longer loads".
# A case measuring a load failure while reporting on a shared probe is a green about
# nothing, so the post-check is part of the spine rather than the caller's to remember.
#
# The case name is an ARGUMENT because a fixture failure must name its own subject: a
# spine that dies with a generic message costs the reader the one thing the message is for.
_plant_in_function() {
  local f="$1" fn="$2" line="$3" who="$4"
  grep -qxF "$fn() {" "$f" \
    || _fixture_die "$who: no '$fn() {' line in ${f##*/} — the anchor moved, so NOTHING was planted and every assertion downstream would be about the unplanted library."
  # Exact-line comparison, not a regex: a function name is matched as a STRING here, so
  # no quoting question arises and no metacharacter can silently match nothing.
  perl -i -pe 'BEGIN{$a=shift; $r=shift} $_ .= "$r\n" if $_ eq "$a() {\n"' "$fn" "$line" "$f"
  grep -qxF "$line" "$f" \
    || _fixture_die "$who: the plant into $fn did not take."
  bash -n "$f" \
    || _fixture_die "$who: the mutated ${f##*/} no longer parses — every consumer would fail to LOAD it, and this case would measure a load error instead of the behaviour under test."
}

# Declare the enumerator command. _neu_scalar asserts the line reads what we wrote.
#
# THE COMMAND MUST CONTAIN NO BACKSLASH ESCAPE. _neu_scalar rewrites the line through
# perl, so a `\n` inside the command is interpreted there and SPLITS THE ASSIGNMENT
# across two lines — verify.sh then reads GUARD_ENUM as unset, takes the NOTE path, and
# exits 0. Measured: every one of these cases reported "exit 0, expected 2" and looked
# like one defect each in the arm under test. Use `echo`, which supplies its own newline,
# and `true` for the deliberately-empty enumeration.
_guard_enum() {  # <verify.sh> <command>
  _neu_scalar "$1" GUARD_ENUM "GUARD_ENUM=\"$2\""
}

case_guard_floor_unenrolled_from_shipped_empty_set() {
  cf_reset
  make_sandbox
  local v="$SB_WORK/scripts/verify.sh" out rc
  # THE SHIPPED STATE: GUARD_SET stays EMPTY (the neutralizer left it so). A guard
  # exists on disk and the enumeration finds it; nothing declares it.
  : > "$SB_WORK/guard-a.txt"
  _guard_enum "$v" "echo guard-a.txt"
  out="$( cd "$SB_WORK" && "$v" --scope some/item 2>&1 )"; rc=$?

  [ "$rc" -eq 2 ] \
    || cf "(unenrolled) exit $rc, expected 2 — an enumerated guard that GUARD_SET does not declare must refuse"
  printf '%s' "$out" | grep -qF 'guard-a.txt' \
    || cf "(unenrolled) the refusal does not NAME the unenrolled guard, so an operator cannot act on it: $out"

  finish "guard floor: a guard the enumeration lists and the SHIPPED EMPTY GUARD_SET does not declare refuses (rc 2) and names it"
  teardown
}

case_guard_floor_enumerator_mistyped() {
  cf_reset
  make_sandbox
  local v="$SB_WORK/scripts/verify.sh" out rc probe_rc
  : > "$SB_WORK/guard-a.txt"
  _guard_declare "$v" 'guard-a.txt'
  # A MIS-TYPED command, not a missing one. THE FIXTURE ASSERTS ITS OWN SHAPE: a
  # 127-only fixture passes against the defect this case exists for, because the defect
  # was treating "non-zero" as "not found" — so the probe must exit NON-ZERO AND NOT 127.
  ( cd "$SB_WORK" && git ls-fils 'guard-*' ) >/dev/null 2>&1; probe_rc=$?
  { [ "$probe_rc" -ne 0 ] && [ "$probe_rc" -ne 127 ]; } \
    || _fixture_die "case_guard_floor_enumerator_mistyped: the mis-typed enumerator exited $probe_rc — this case needs a non-zero that is NOT 127, or it cannot tell the fixed behaviour from the defect."
  _guard_enum "$v" "git ls-fils 'guard-*'"
  out="$( cd "$SB_WORK" && "$v" --scope some/item 2>&1 )"; rc=$?

  [ "$rc" -eq 2 ] \
    || cf "(mis-typed) exit $rc, expected 2 — an enumerator that did not run cleanly must refuse rather than reconcile against its empty output"
  # WHICH REFUSAL FIRED — not merely that one did. BOTH refusal arms exit 2, and BOTH echo
  # $GUARD_ENUM back to the operator, so `rc -eq 2` and a grep for the command text
  # ('ls-fils') match in EITHER arm. Measured: with the rc check narrowed back to
  # 126/127-only, a mis-typed enumerator (exit 1) falls through to "ran cleanly and returned
  # NOTHING" — a materially FALSE sentence about a command that failed — and this case still
  # passed on both of those assertions. It could not fail against the defect it exists for.
  # So the arm is asserted by a token ONLY THAT ARM prints:
  printf '%s' "$out" | grep -qF 'did not run cleanly (exit' \
    || cf "(mis-typed) the UNRUNNABLE arm did not fire — a non-zero enumerator was reported as having run cleanly, which is the defect this case exists for: $out"
  # ...and the enumerator's own stderr by a token ONLY THE ENUMERATOR can produce. 'ls-fils'
  # is verify.sh quoting the command back; "not a git command" is git itself speaking, and
  # it reaches the operator only if the stderr capture is actually surfaced.
  printf '%s' "$out" | grep -qF 'not a git command' \
    || cf "(mis-typed) the enumerator's own stderr was swallowed, so the operator cannot see WHY it failed: $out"

  finish "guard floor: a MIS-TYPED enumerator (non-zero, not 127) refuses (rc 2) and surfaces the enumerator's own stderr"
  teardown
}

case_guard_floor_enumerator_succeeds_empty() {
  cf_reset
  make_sandbox
  local v="$SB_WORK/scripts/verify.sh" out rc probe_rc probe_out
  : > "$SB_WORK/guard-a.txt"
  _guard_declare "$v" 'guard-a.txt'
  # THE REALISTIC SHAPE: `git ls-files` over a guard that is not yet TRACKED exits 0 and
  # prints nothing. A fixture built on a FAILING command cannot reach this path — the
  # defect here is a command that works.
  probe_out="$( cd "$SB_WORK" && git ls-files 'guard-a.txt' 2>/dev/null )"; probe_rc=$?
  { [ "$probe_rc" -eq 0 ] && [ -z "$probe_out" ]; } \
    || _fixture_die "case_guard_floor_enumerator_succeeds_empty: the probe exited $probe_rc with output '$probe_out' — this case needs exit 0 AND empty output, or it is testing the mis-typed path again."
  _guard_enum "$v" "git ls-files 'guard-a.txt'"
  out="$( cd "$SB_WORK" && "$v" --scope some/item 2>&1 )"; rc=$?

  [ "$rc" -eq 2 ] \
    || cf "(empty-but-clean) exit $rc, expected 2 — an enumerator that ran cleanly and saw NOTHING while GUARD_SET declares items must refuse, not reconcile"
  # KEYED ON THE CLAIM'S OWN FORM, not on the word. The NOTE that DENIES reconciliation
  # contains "was reconciled" in a negating sentence, so a bare grep for the word fires on
  # correct output — measured. The green claim is the phrase below and nothing else is.
  printf '%s' "$out" | grep -q 'reconciled BOTH ways' \
    && cf "(empty-but-clean) the run claimed reconciliation over an enumeration that returned nothing: $out"

  finish "guard floor: an enumerator that SUCCEEDS and returns nothing over a populated GUARD_SET refuses (rc 2) and claims no reconciliation"
  teardown
}

case_guard_floor_unseen_declared_guard() {
  cf_reset
  make_sandbox
  local v="$SB_WORK/scripts/verify.sh" out rc
  # TWO guards on disk, BOTH declared, and the enumerator scoped to ONE. This is the
  # SET − SPACE direction — the `unseen` loop — which had no case at all, so
  # "reconciled BOTH ways" was asserted by a suite that had only watched one direction.
  : > "$SB_WORK/guard-a.txt"; : > "$SB_WORK/guard-b.txt"
  _guard_declare "$v" 'guard-a.txt'
  _guard_declare "$v" 'guard-b.txt'
  _guard_enum "$v" "echo guard-a.txt"
  out="$( cd "$SB_WORK" && "$v" --scope some/item 2>&1 )"; rc=$?

  [ "$rc" -eq 2 ] \
    || cf "(unseen) exit $rc, expected 2 — a DECLARED guard the enumeration cannot see is not reconciled by it"
  # WHICH SIDE NAMES ITEMS is the discriminator: the UNSEEN guard must be named. Both
  # paths appear in the file, so naming guard-b is what distinguishes this direction
  # from the other one.
  printf '%s' "$out" | grep -qF 'guard-b.txt' \
    || cf "(unseen) the refusal does not name the DECLARED guard the enumeration missed: $out"

  finish "guard floor: a DECLARED guard outside the enumeration's scope refuses (rc 2) and names the unseen one — the SET − SPACE direction"
  teardown
}

# THE POSITIVE ARM, AND IT IS THE ONE DIRECTION NOTHING WATCHED. Before this case, the phrase
# "reconciled BOTH ways" appeared in this file exactly twice and BOTH were NEGATIVE (`&& cf`):
# they prove the claim is ABSENT where it should be. Reword verify.sh's success line — the kind
# of edit its own guard-floor header calls "a kindness" — and both canaries match nothing, take
# the PASSING branch, and stay green over a claim that has stopped being emitted at all.
# A phrase asserted only by its absence is not asserted.
case_guard_floor_reconciles_and_says_so() {
  cf_reset
  make_sandbox
  local v="$SB_WORK/scripts/verify.sh" out rc
  # DECLARED == ENUMERATED, exactly. Neither direction has anything to report, which is the
  # only state that reaches the green line.
  : > "$SB_WORK/guard-a.txt"; : > "$SB_WORK/guard-b.txt"
  _guard_declare "$v" 'guard-a.txt'
  _guard_declare "$v" 'guard-b.txt'
  _guard_enum "$v" "printf '%s\\n' guard-a.txt guard-b.txt"
  out="$( cd "$SB_WORK" && "$v" --scope some/item 2>&1 )"; rc=$?

  [ "$rc" -eq 0 ] \
    || cf "(reconciled) exit $rc, expected 0 — a GUARD_SET the enumeration matches exactly is the reconciled state and must not refuse: $out"
  printf '%s' "$out" | grep -q 'reconciled BOTH ways' \
    || cf "(reconciled) the run did NOT emit the reconciliation claim over a set the enumeration matches exactly, so the phrase the two canary cases assert the ABSENCE of is now emitted by nothing: $out"
  # THE COUNT TOO, because the green line is the one most mistakable for a measurement of the
  # tree: two guards declared must read as two, not as whatever the shipped set happened to hold.
  printf '%s' "$out" | grep -q '2 DECLARED item(s)' \
    || cf "(reconciled) the green line does not report the 2 DECLARED items this case set up: $out"

  finish "guard floor: a GUARD_SET the enumeration matches exactly reconciles, exits 0 and SAYS SO — the positive direction the two canaries cannot prove"
  teardown
}

case_guard_floor_wholly_empty_shipped_state() {
  cf_reset
  make_sandbox
  local v="$SB_WORK/scripts/verify.sh" out rc
  # THE SHIPPED STATE, END TO END: GUARD_SET empty, an enumerator declared, and nothing
  # to find. Setting GUARD_ENUM before writing a first guard is legitimate, so this must
  # NOT refuse — and it must not claim a reconciliation it did not perform either.
  _guard_enum "$v" "true"
  out="$( cd "$SB_WORK" && "$v" --scope some/item 2>&1 )"; rc=$?

  [ "$rc" -eq 0 ] \
    || cf "(wholly empty) exit $rc, expected 0 — declaring GUARD_ENUM before the first guard exists is legitimate and must not refuse"
  # THE ONE ASSERTION HERE THAT NECESSARILY TOUCHES THE CLAIM'S WORDING, and it is
  # unavoidable: this state's whole subject IS the absence of the green claim, and both
  # states here exit 0, so there is no code to read instead. Keyed on the claim's own
  # distinctive phrase — NOT on the word "reconciled", which the denying NOTE also uses,
  # and which therefore fired on correct output when this was first written.
  printf '%s' "$out" | grep -q 'reconciled BOTH ways' \
    && cf "(wholly empty) the run claimed reconciliation with an empty GUARD_SET and an empty enumeration — nothing was reconciled: $out"

  finish "guard floor: the wholly-empty shipped state exits 0 with a NOTE and claims no reconciliation"
  teardown
}

case_verify_frame() {
  cf_reset
  make_sandbox                     # make_sandbox already declared one select gate
  local v="$SB_WORK/scripts/verify.sh" out rc

  # (a) empty table refuses. Strip the gate this sandbox declared.
  perl -i -ne 'print unless /sandbox gate\|select/' "$v"
  out="$( cd "$SB_WORK" && "$v" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) an EMPTY gate table exited 0 — a runner with no gates must never look green"
  printf '%s' "$out" | grep -q 'REFUSING' || cf "(a) the empty-table refusal is not stated: $out"
  # (b) --list still answers.
  out="$( cd "$SB_WORK" && "$v" --list 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) --list exited $rc on an empty table (it is informational)"
  printf '%s' "$out" | grep -q '0 declared gate' || cf "(b) --list does not report the empty table: $out"

  # Re-declare: one green select gate, one red full gate, one guard path.
  # THE RED GATE IS A SANDBOX-LOCAL SCRIPT, not `/usr/bin/false` — the same reason the
  # core-gate fixture below states: an absolute path to a system binary is absent on
  # some platform, and an absent command returns 127, which this harness now classes
  # UNRUNNABLE rather than FAIL. A portability slip in the fixture would then be
  # indistinguishable from the defect the case exists to detect.
  : > "$SB_WORK/guard-one.txt"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$SB_WORK/red-gate"; chmod +x "$SB_WORK/red-gate"
  _declare_gate 'green|select|/bin/echo ran-green'
  _declare_gate 'redbuild|full|./red-gate'
  _guard_declare "$v" guard-one.txt

  # (c) unlaundered exit codes.
  out="$( cd "$SB_WORK" && "$v" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(c) a red gate did not make the run exit nonzero"
  printf '%s' "$out" | grep -q 'FAIL  redbuild' || cf "(c) the summary does not name the failed gate: $out"
  printf '%s' "$out" | grep -q 'PASS  green'    || cf "(c) the summary does not name the passing gate: $out"

  # (d) --quick skips the `full` class and only that.
  out="$( cd "$SB_WORK" && "$v" --quick 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(d) --quick exited $rc despite the only red gate being class full"
  printf '%s' "$out" | grep -q 'SKIP  redbuild' || cf "(d) --quick did not skip the full-class gate: $out"
  printf '%s' "$out" | grep -q 'PASS  green'    || cf "(d) --quick skipped the select-class gate too: $out"

  # (e) --scope passes the selection PLUS the guard floor to the select gate.
  out="$( cd "$SB_WORK" && "$v" --scope some/item 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(e) the scoped run exited $rc: $out"
  printf '%s' "$out" | grep -q 'some/item' || cf "(e) the scoped run did not pass the requested item: $out"
  printf '%s' "$out" | grep -q 'guard-one.txt' \
    || cf "(e) the scoped run did not append the GUARD_SET floor — a scoped run must never be narrower than the guards: $out"
  # ...and a vanished guard is a hard stop.
  rm -f "$SB_WORK/guard-one.txt"
  out="$( cd "$SB_WORK" && "$v" --scope some/item 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(e) a vanished guard did not stop the scoped run — the floor shrank silently"
  printf '%s' "$out" | grep -q 'guard-one.txt' || cf "(e) the vanished-guard refusal does not name the path: $out"

  finish "verify.sh frame: empty table REFUSES, --list answers anyway, exit codes unlaundered, --quick skips only 'full', --scope appends the guard floor and a vanished guard is a hard stop"
  teardown
}

# =============================================================================
# check-board.sh check (d): frontmatter id integrity
# =============================================================================
# WHY THESE CASES EXIST (empirical, not speculative): two issues carried the SAME
# `id:` on the trunk simultaneously — a Dev-filed bug and a PM-minted spike,
# landed minutes apart from separate worktrees. Their SLUGS differed, so git
# raised nothing, and no check read frontmatter `id:` — so the board reported
# `board-drift: clean ✓` with a duplicate id on it.
#
# NOTE ON THE ABSENT CAPABILITY PROBE (deliberate, same reasoning as
# case_verify_frame): there is NO grep-probe on check-board.sh having the check,
# because such a probe would turn the check being deleted or refactored away into
# a SKIP instead of a FAIL.
#
# DERIVE, DO NOT RE-HARDCODE: the constants these cases key on are read out of the
# REAL check-board.sh with sed, per that script's own greppable-defaults contract,
# so a future edit there cannot silently make these assertions vacuous.

# Run the SANDBOX copy of check-board.sh. CLAUDE_PROJECT_DIR is unset for the
# child: that variable is how the script overrides its repo root, and inheriting
# the harness's would point the sandbox's copy at the REAL board.
# Read arm [g]'s SECTION out of a check-board report — from its header to the next
# arm's, however long it grows.
#
# THE OFFSET WAS THE DEFECT, NOT ITS SIZE. Every assertion below used `grep -A6`, so an
# assertion moved past the sixth line by a line ADDED to the arm silently stops being
# read — and a `grep -q` over a window that no longer contains its subject reports
# absence, which here reads as a finding rather than as a blind assertion. Widening the
# number would buy time and keep the shape; anchoring on the next `[x]` header removes
# it, because the section's end is a fact about the report rather than a guess about
# its length.
# ARM [g] IS CURRENTLY THE LAST ARM, so a section read that stops only at the next
# `[x]` header runs to the end of the report and swallows the trailing verdict line.
# Measured against a real report: without the `──` guard the section is 5 lines and
# includes `── board-drift: …`; with it, 4 and clean. Nothing asserts on that line
# through this helper today — but a NEGATIVE assertion added later would be answered by
# the verdict rather than by the arm, which is the same class of quiet wrongness the
# fixed offset had. The guard costs one clause and removes the possibility.
# (Both halves are needed: `──` alone would not stop at a following arm if one is ever
# added after [g], and the header test alone does not stop at the summary.)
# _lived_signals — the signals arm [g] reads to decide whether this repository has
# STARTED, derived the way the arm derives them rather than enumerated.
#
# WHY DERIVED. A fixture that guards two of four signals is the census-in-prose form with
# a `[ ]` around it: it is correct until the set grows, and it grows silently. Today a
# sandbox is clean on the log and archive signals by accident — make_sandbox writes no
# progress.md, and its ARCHIVE.md has the heading with no body — so a guard covering only
# the receipt and the board would PASS TODAY and stop covering the moment somebody seeds
# a log line for an unrelated case. The not-run case would then quietly become an
# enabling-direction case still carrying the not-run name.
#
# THIS LIST IS A COPY OF THE ARM'S AND MUST MOVE WHEN THE ARM DOES. It is derived from
# the same four inputs in the same order; it is not derived from the arm's code, because
# the arm is the subject under test and a fixture that asked the subject what to check
# would agree with it by construction.
#
# THE COPY IS SAFE BECAUSE OF WHICH WAY A DIVERGENCE FAILS, and that — not the
# self-certification argument above — is the reason not to collapse these two for
# tidiness. Suppose the arm gains a fifth signal and this list does not: a fixture
# carrying only that fifth signal makes this guard say "not started, proceed", the arm
# then RUNS, and the not-run case asserts THIS CHECK DID NOT RUN against an arm that
# reported. It fails loudly, immediately, and names the arm. The copy cannot rot quietly
# in the direction that matters.
#
# THERE ARE NOW TWO IMPLEMENTATIONS OF THIS SIGNAL SET, and this one is the INSTRUMENT
# rather than an operand. It was three — the initializer's probe, the arm's
# re-derivation, and this fixture — and the first two were merged into
# scripts/lib/lived-probe.sh, which both consumers now source.
#
# THIS FIXTURE IS DELIBERATELY NOT COLLAPSED INTO THAT LIBRARY, and the reason is the
# whole value of it: a fixture that asked the subject under test what to check would
# agree with it by construction, and every case resting on it would go green on a probe
# that had stopped measuring anything. It is now the ONLY independent witness to the
# signal set, which raises rather than lowers what it is worth. If the library grows a
# signal, this must grow it too — and the mechanism above is what makes that failure
# loud instead of quiet.
_lived_signals() {  # prints one line per signal present; empty output means "not started"
  local col n log arc cols
  [ -f "$SB_WORK/scripts/config.sh" ] && grep -q "^$KIT_STAMP_MARK" "$SB_WORK/scripts/config.sh" 2>/dev/null \
    && echo "the initializer's stamp receipt in scripts/config.sh"
  # THE COLUMNS ARE DERIVED, from the same declaration the arm reads. They were a
  # six-name literal here until it was pointed out that this is the guard written to
  # replace an enumerated guard — a list of columns in it is the defect wearing the
  # fix's clothes. `cb_default` already reads named values out of the real
  # check-board.sh and is already used for STATUS_FOLDERS elsewhere in this file, so
  # the derivation costs one line and removes the question rather than answering it.
  IFS='|' read -r -a cols <<< "$(cb_default STATUS_FOLDERS)"
  [ "${#cols[@]}" -gt 0 ] \
    || _fixture_die "_lived_signals: STATUS_FOLDERS could not be read from check-board.sh — the board signal would be skipped entirely and every guard built on this would pass over a board it never looked at."
  for col in "${cols[@]}"; do
    [ -d "$SB_WORK/progress/$col" ] || continue
    n="$(find "$SB_WORK/progress/$col" -type f -name '*-[0-9]*.md' 2>/dev/null | wc -l | tr -d ' ')"
    [ "${n:-0}" -gt 0 ] && echo "progress/$col/ carries $n issue file(s)"
  done
  if [ -f "$SB_WORK/progress.md" ]; then
    log="$(awk '/^##[[:space:]]/ { if (inlog) exit; if ($0 ~ /^##[[:space:]]+Log/) { inlog=1; next } } inlog && NF { print }' "$SB_WORK/progress.md" 2>/dev/null | wc -l | tr -d ' ')"
    [ "${log:-0}" -gt 0 ] && echo "progress.md § Log holds ${log} line(s)"
  fi
  if [ -f "$SB_WORK/ARCHIVE.md" ]; then
    arc="$(awk '/^## Archived$/ { a=1; next } a && NF { print }' "$SB_WORK/ARCHIVE.md" 2>/dev/null | wc -l | tr -d ' ')"
    [ "${arc:-0}" -gt 0 ] && echo "ARCHIVE.md indexes ${arc} line(s)"
  fi
  return 0
}

_cb_g_section() {  # reads a check-board report on stdin
  awk '/^\[g\]/ { f = 1 }
       f && /^──/ { exit }
       f && /^\[[a-z]\]/ && !/^\[g\]/ { exit }
       f'
}

# cb_set_dep <id> <slug> <folder> <blocks|blocked_by> <target-id>
# Rewrite one dependency field into a seeded card's frontmatter. seed_issue does NOT emit
# these keys, so this INSERTS before the CLOSING fence — the second `---`, never the
# first. A fixture that did not take is FATAL, not a case failure: every assertion built
# on it would then be about a board with no dependencies at all, and would report PASS.
cb_set_dep() {
  local id="$1" slug="$2" folder="$3" key="$4" target="$5"
  local f="$SB_WORK/progress/$folder/${id}-${slug}.md"
  [ -f "$f" ] || _fixture_die "cb_set_dep: no card at $f"
  awk -v k="$key" -v t="$target" '
    /^---[[:space:]]*$/ { n++; if (n == 2) printf "%s: [%s]\n", k, t }
    { print }
  ' "$f" > "$f.new" && mv "$f.new" "$f"
  grep -qF "$key: [$target]" "$f" \
    || _fixture_die "cb_set_dep: '$key: [$target]' did not land in $f — the symmetry case would run against a board with no dependency declared and would report PASS about nothing."
}

cb_run() { ( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR "$SB_WORK/scripts/check-board.sh" 2>&1 ); }

# =============================================================================
# CASE — each runner's stray-key guard admits every per-issue field that runner READS.
#
# wave-runner's guard was copied verbatim from tranche-runner, whose per-issue shape is ALMOST
# the same. wave-runner also reads `worktreeMode`, `phase` and `restartNote` — all three named in
# its own meta.description — and the copied set omitted all three, so the guard refused the exact
# fields the file's contract advertises and EVERY wave run threw before its first agent started.
# Shipped that way for one release. The guard was correct in isolation and wrong about its operand.
#
# This is the operand-set defect (doctrine/instruments.md § A.6) in its cheapest form: the answer
# is derivable from the file itself, so nothing has to be maintained by hand.
case_runner_key_guards_admit_every_field_they_read() {
  cf_reset
  local wf="$REAL_REPO_ROOT/.claude/workflows" r name n=0
  [ -d "$wf" ] || _fixture_die "case_runner_key_guards_admit_every_field_they_read: no .claude/workflows/ in the published kit at $REAL_REPO_ROOT"

  for r in "$wf"/*.js; do
    [ -f "$r" ] || continue
    name="$(basename "$r")"
    grep -q 'const ISSUE_KEYS' "$r" || continue
    n=$(( n + 1 ))
    # Declared: the quoted names inside the ISSUE_KEYS literal. Read: every issue.<field> in the
    # file. `issue.sh` is excluded — it is the tail of a path in prose, not a field.
    local missing
    missing="$(python3 - "$r" <<'PY'
import re,sys
s=open(sys.argv[1],encoding='utf-8').read()
m=re.search(r'const ISSUE_KEYS = new Set\(\[(.*?)\]\)', s, re.S)
declared=set(re.findall(r"'([A-Za-z_]+)'", m.group(1))) if m else set()
used={x for x in re.findall(r'issue\.([A-Za-z_]+)', s)} - {'sh'}
print(' '.join(sorted(used - declared)))
PY
)"
    [ -z "$missing" ] \
      || cf "$name reads per-issue field(s) its own ISSUE_KEYS refuses: $missing — every call passing one throws before any agent starts"
  done

  [ "$n" -ge 1 ] \
    || cf "no runner declared an ISSUE_KEYS set — either the guard was removed or its name changed, and this case then asserts nothing"

  # REDDENING CONTROL: drop a name from a COPY and the derivation must report it.
  local ctl="$SB_TMP"; [ -n "$ctl" ] || ctl="$(mktemp -d)"
  mkdir -p "$ctl/kctl"
  if [ -f "$wf/wave-runner.js" ]; then
    sed "s/'worktreeMode', //" "$wf/wave-runner.js" > "$ctl/kctl/wave-runner.js"
    local ablated
    ablated="$(python3 - "$ctl/kctl/wave-runner.js" <<'PY'
import re,sys
s=open(sys.argv[1],encoding='utf-8').read()
m=re.search(r'const ISSUE_KEYS = new Set\(\[(.*?)\]\)', s, re.S)
declared=set(re.findall(r"'([A-Za-z_]+)'", m.group(1))) if m else set()
used={x for x in re.findall(r'issue\.([A-Za-z_]+)', s)} - {'sh'}
print(' '.join(sorted(used - declared)))
PY
)"
    printf '%s' "$ablated" | grep -q 'worktreeMode' \
      || cf "(control) dropping worktreeMode from a copy did NOT surface it — the derivation cannot bite"
  else
    cf "(control) wave-runner.js not found — the reddening control could not run"
  fi
  rm -rf "$ctl/kctl"

  finish "each runner's ISSUE_KEYS admits every per-issue field that runner actually reads ($n runner(s), derived from the file, ablation-proven)"
}

# CASE — the shipped workflow runners COMPOSE every brief they would send, from a realistic
# args payload, without throwing. This is the harness EXERCISING the kit rather than reading it.
#
# WHY IT EXISTS. Every other case in this file, and every round of the pre-cut sweep, reads.
# Measured against that: an adopter dispatching a real tranche found the runner dying in 33ms on
# `issue.depends_on.length` with zero agents started, and this repository then shipped a
# stray-key guard copied between the two runners whose allow-list omitted three fields the
# destination file reads — so EVERY wave run would have thrown before its first agent. Neither
# was reachable by reading; both are caught here in milliseconds.
#
# NOTHING IS DISPATCHED. `agent()` is stubbed to return a schema-shaped object, so the script
# runs its real control flow and builds its real prompts at zero agent cost. What is under test
# is the CONTRACT — that a caller following the documented shape can start a run.
case_workflow_briefs_compose_from_a_sparse_payload() {
  cf_reset
  local wf="$REAL_REPO_ROOT/.claude/workflows" stub out n=0
  [ -d "$wf" ] || _fixture_die "case_workflow_briefs_compose_from_a_sparse_payload: no .claude/workflows/ in the published kit at $REAL_REPO_ROOT"
  if ! command -v node >/dev/null 2>&1; then
    skp "the shipped workflow runners compose their briefs from a sparse args payload" "node absent"
    return
  fi

  stub="$(mktemp -d)/stub-run.mjs"
  cat > "$stub" <<'STUBEOF'
import fs from 'node:fs'
const [file, argsJson] = process.argv.slice(2)
const src = fs.readFileSync(file, 'utf8').replace(/^export const meta/m, 'const meta')
const briefs = []
const stubFor = (schema) => {
  const o = {}
  for (const [k, v] of Object.entries((schema && schema.properties) || {})) {
    if (v.enum) o[k] = v.enum[0]
    else if (v.type === 'array') o[k] = []
    else if (v.type === 'integer' || v.type === 'number') o[k] = 0
    else if (v.type === 'boolean') o[k] = true
    else if (v.type === 'object') o[k] = {}
    else o[k] = 'stub'
  }
  return o
}
const agent = async (prompt, opts) => {
  opts = opts || {}
  briefs.push(String(prompt))
  return opts.schema ? stubFor(opts.schema) : 'stub'
}
const parallel = async (t) => Promise.all(t.map((f) => f()))
const pipeline = async (items, ...stages) => Promise.all(items.map(async (it, i) => {
  let acc = it
  for (const s of stages) acc = await s(acc, it, i)
  return acc
}))
const phase = () => {}
const log = () => {}
const args = JSON.parse(argsJson)
const budget = { total: null, spent: () => 0, remaining: () => Infinity }
const body = new Function('agent', 'parallel', 'pipeline', 'phase', 'log', 'args', 'budget',
  'return (async () => { ' + src + ' })()')
try {
  await body(agent, parallel, pipeline, phase, log, args, budget)
  console.log(JSON.stringify({ ok: true, briefs: briefs.length, text: briefs.join(String.fromCharCode(10)) }))
} catch (e) {
  console.log(JSON.stringify({ ok: false, error: String((e && e.message) || e), briefs: briefs.length }))
}
STUBEOF

  # THE PAYLOAD IS DELIBERATELY SPARSE: only the fields a caller must supply. Every optional
  # per-issue key is omitted, which is exactly the shape that killed the adopter's dispatch.
  local T_ARGS='{"repo":"/tmp/x","issues":[{"id":"ZZ-1","branch":"b","title":"t","devModel":"opus","devEffort":"high","qaModel":"opus","qaEffort":"high"}]}'
  local W_ARGS='{"repo":"/tmp/x","wave1":[{"id":"ZZ-1","branch":"b","title":"t","devModel":"opus","devEffort":"high","qaModel":"opus","qaEffort":"high","worktreeMode":"self","phase":"Wave1","restartNote":"n"}]}'

  _wf_run() { node "$stub" "$1" "$2" 2>&1; }
  _wf_ok()  { printf '%s' "$1" | grep -q '"ok":true'; }
  _wf_err() { printf '%s' "$1" | sed -n 's/.*"error":"\([^"]*\)".*/\1/p'; }

  # --- tranche-runner, sparse ------------------------------------------------------
  out="$(_wf_run "$wf/tranche-runner.js" "$T_ARGS")"; n=$(( n + 1 ))
  _wf_ok "$out" \
    || cf "tranche-runner THREW composing its briefs from a payload carrying only the required per-issue fields: $(_wf_err "$out")"

  # --- wave-runner, sparse + the wave-only fields its own description advertises ----
  out="$(_wf_run "$wf/wave-runner.js" "$W_ARGS")"; n=$(( n + 1 ))
  _wf_ok "$out" \
    || cf "wave-runner THREW composing its briefs from a payload using the wave-only fields meta.description advertises: $(_wf_err "$out")"

  # --- a MISSPELLED per-issue key must be REFUSED BY NAME, not silently ignored -----
  out="$(_wf_run "$wf/tranche-runner.js" '{"repo":"/tmp/x","issues":[{"id":"ZZ-1","branch":"b","title":"t","devModel":"o","devEffort":"h","qaModel":"o","qaEffort":"h","depends_ons":["ZZ-0"]}]}')"
  _wf_ok "$out" \
    && cf "a misspelled per-issue key (depends_ons) was ACCEPTED — a caller who meant to declare a dependency would get a silent solo run"
  printf '%s' "$out" | grep -q 'depends_ons' \
    || cf "the misspelled key was refused but not NAMED, so the caller cannot see which key is wrong"

  # --- ABLATION: the exerciser must be able to go red -------------------------------
  # Without this, a green above could mean "both runners are fine" or "the stub never ran the
  # real control flow". Remove the depends_on guard from a COPY and the throw must come back —
  # this is the adopter's original 33ms crash, reproduced.
  local abl; abl="$(dirname "$stub")/abl.js"
  sed 's/Array.isArray(issue.depends_on) ? issue.depends_on : \[\]/issue.depends_on/' \
    "$wf/tranche-runner.js" > "$abl"
  out="$(_wf_run "$abl" "$T_ARGS")"
  _wf_ok "$out" \
    && cf "(ablation) removing the depends_on guard did NOT reproduce the crash — the stub is not running the runner's real control flow, so every green above is empty"

  rm -rf "$(dirname "$stub")"
  unset -f _wf_run _wf_ok _wf_err
  finish "both shipped workflow runners compose every brief from a payload carrying only the REQUIRED per-issue fields, refuse a misspelled key by name, and the exerciser is ablation-proven against the adopter's original crash ($n runner(s), nothing dispatched)"
}

# CASE — check-board's [j] arm joins the downtime queue to the board, and CLASSIFIES the
# Status cell rather than grepping it.
#
# The queue institutes strike-never-delete and, before this arm, NOTHING in the kit read the
# file: an adopter measured `grep -rln downtime-queue` over their tree and got one hit, the
# prose instituting it. It bit them twice as silence — a row read `open` for a cure already
# on the trunk, and a stale row looks exactly like a live one.
#
# THE FALSIFIER SET IS THE POINT. A naive `grep -c '| open |'` under-reported that adopter's
# queue by 8 rows of 37, so the fixture below carries the shapes that break it: emphasis, a
# trailing `Status:` declaration that must win over the cell's opening words, a struck row
# that must NOT fire, a live claim in todo/ that must NOT fire, and the angle-bracket SHAPE
# row that is documentation rather than data.
case_downtime_queue_claim_drift() {
  cf_reset
  make_sandbox
  local out
  mkdir -p "$SB_WORK/dev"
  cat > "$SB_WORK/dev/downtime-queue.md" <<'DQEOF'
| Item | Origin | Size | Why deferred | Wake condition | Status |
|---|---|---|---|---|---|
| `<shape row>` | `<x>` | `<S/M/L>` | `<y>` | `<z>` | `<open / open (claimed by <PREFIX>-NNN) / STRUCK …>` |
| **Landed already** | audit | S | — | now | open (claimed by ZZQ-101) |
| **Still live** | audit | S | — | now | open (claimed by ZZQ-102) |
| **Emphasis + trailing decl** | audit | M | — | now | *was struck* — Status: **open (claimed by ZZQ-103)** |
| **Genuinely struck** | audit | S | — | — | STRUCK — landed as ZZQ-104, outcome fine |
DQEOF
  : > "$SB_WORK/progress/done/ZZQ-101-a.md"
  : > "$SB_WORK/progress/todo/ZZQ-102-b.md"
  : > "$SB_WORK/progress/done/ZZQ-103-c.md"
  : > "$SB_WORK/progress/done/ZZQ-104-d.md"

  # SCOPE THE ASSERTIONS TO THE [j] SECTION. The first draft grepped the whole report and
  # failed: arms [a] and [d] also name these ids, because the fixture puts real cards on the
  # board. A guard whose operand is the wrong slice reports the neighbouring arm's output as
  # its own subject — the operand defect (instruments.md § A.6) inside the case testing for it.
  _j_section() { cd "$SB_WORK" && ./scripts/check-board.sh 2>&1 | awk '/^\[j\]/{f=1;print;next} f&&/^\[/{f=0} f'; }
  out="$(_j_section)"

  # --- must fire -----------------------------------------------------------------
  printf '%s' "$out" | grep -q 'ZZQ-101' \
    || cf "an open row whose issue is in progress/done/ was NOT reported"
  printf '%s' "$out" | grep -q 'ZZQ-103' \
    || cf "the emphasised row with a trailing 'Status:' declaration was NOT reported — the cell is being grepped, not classified, which is the 8-of-37 defect"

  # --- must NOT fire -------------------------------------------------------------
  printf '%s' "$out" | grep -q 'ZZQ-102' \
    && cf "a LIVE claim (issue still in todo/) was reported — the arm fires on any open row, not on landed ones"
  printf '%s' "$out" | grep -q 'ZZQ-104' \
    && cf "a STRUCK row was reported — the arm does not read the Status cell's verdict"
  printf '%s' "$out" | grep -q 'PREFIX' \
    && cf "the angle-bracket SHAPE row was read as data"

  # --- informational, and that is a ruling ---------------------------------------
  printf '%s' "$out" | grep -q '^\[j\]' \
    || cf "the [j] arm did not print its header, so its subject is unnamed"

  # --- the ABSENT subject still prints (contracts/drift-report.md § 4) ------------
  rm -f "$SB_WORK/dev/downtime-queue.md"
  out="$(_j_section)"
  printf '%s' "$out" | grep -q 'not present' \
    || cf "with no queue file the arm went SILENT instead of naming what was absent"

  # --- ABLATION: the clean case must be distinguishable from the finding case -----
  cat > "$SB_WORK/dev/downtime-queue.md" <<'DQEOF'
| Item | Origin | Size | Why deferred | Wake condition | Status |
|---|---|---|---|---|---|
| **Still live** | audit | S | — | now | open (claimed by ZZQ-102) |
DQEOF
  out="$(_j_section)"
  printf '%s' "$out" | grep -q 'no open row claims a landed issue' \
    || cf "(ablation) a queue with only LIVE claims did not report the clean line, so a green here proves nothing"

  unset -f _j_section
  finish "check-board [j]: an open queue row whose claiming issue has landed is reported; a live claim, a struck row and the shape row are not; the Status cell is CLASSIFIED (emphasis + trailing declaration) rather than grepped; an absent queue names itself; ablation-proven"
  teardown
}

# CASE — settings.json.example never glosses a placeholder it does not contain.
#
# It did. A `_PLACEHOLDERS` map glossed seven <angle-bracket> tokens and told the adopter
# to "replace every token below"; ALL SEVEN had left with the `autoMode` block that a
# sibling key in the same file records as deleted. The glossary outlived its subject —
# the change edited the thing and not the sentence next door describing it — and the
# instruction it left behind sent a reader looking for text that was not there.
#
# The guard is bidirectional on purpose. One direction catches the defect that happened;
# the other catches the fix that over-corrects by deleting a gloss while the token stays.
case_settings_example_glosses_only_real_placeholders() {
  cf_reset
  # $REAL_REPO_ROOT, not a sandbox: this file is a KIT DELIVERABLE shipped for the
  # operator to copy, not something an initialized project is given. Reading it out of
  # $SB_WORK found nothing and killed the fixture.
  local f="$REAL_REPO_ROOT/.claude/settings.json.example" declared present tok
  [ -f "$f" ] || _fixture_die "case_settings_example_glosses_only_real_placeholders: no .claude/settings.json.example in the published kit at $REAL_REPO_ROOT"

  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$f" \
    || cf "settings.json.example is not valid JSON"

  # Tokens the file GLOSSES (keys of _PLACEHOLDERS, if that key exists at all) ...
  declared="$(python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
print("\n".join(k for k in d.get("_PLACEHOLDERS",{}) if k.startswith("<")))' "$f")"

  # ... versus tokens the file actually CONTAINS, everywhere but that map.
  present="$(python3 -c '
import json,re,sys
d=json.load(open(sys.argv[1]))
# Underscore keys are this file COMMENTING ON ITSELF - the carve-out that exists
# because JSON has no comment syntax. A token QUOTED in that commentary (including
# the note recording which tokens were REMOVED) is not a token to replace, and
# counting it is the self-scanning census defect: the explanation of an absence
# reads as a presence.
body=json.dumps({k:v for k,v in d.items() if not k.startswith("_")})
print("\n".join(sorted(set(re.findall(r"<[A-Za-z][A-Za-z-]*>", body)))))' "$f")"

  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    printf '%s\n' "$present" | grep -qxF "$tok" \
      || cf "_PLACEHOLDERS glosses $tok, which appears NOWHERE else in the file — the adopter is told to replace text that is not there"
  done <<EOF
$declared
EOF

  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    printf '%s\n' "$declared" | grep -qxF "$tok" \
      || cf "$tok appears in the file but no _PLACEHOLDERS entry says what to put there"
  done <<EOF
$present
EOF

  finish "settings.json.example: every <token> it glosses appears in it, and every <token> in it is glossed (both directions — the defect was a gloss outliving its subject)"
}

# CASE — archive-progress.sh's DRY RUN, which is the DEFAULT, writes nothing at all.
#
# It used to. The empty-index creation sat 223 lines above the `(dry run — no changes
# made.)` line and ran in both modes, so the default invocation created
# progress/history/INDEX.md and then closed by denying it had. Found by a fresh-context
# sweep 2026-09-03; the reason it survived the mechanical pre-cut sweep is that nothing
# CLAIMED the two were connected — the write was correct on its own, the summary was
# correct on its own, and only running the thing shows they contradict.
#
# The assertion is a WHOLE-TREE checksum, not `[ ! -f INDEX.md ]`. Naming the one file
# I know about would pass the day a different dry-run write appears, and this defect's
# whole lesson is that the write nobody thought about is the one that gets through.
case_archive_progress_dry_run_writes_nothing() {
  cf_reset
  make_sandbox
  local R="$SB_TMP/apdry" out rc before after
  ap_seed "$R" 20 2026-08-20 \
    || { finish "archive-progress.sh: a dry run writes NOTHING"; teardown; return; }

  _tree_sum() { find "$R" -type f -print0 | sort -z | xargs -0 shasum | shasum; }
  before="$(_tree_sum)"

  # No --apply. Entries ARE older than the cut, so this is the live path, not a no-op.
  rc=0; out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" \
                  --milestone dry1 --before 2026-08-26 2>&1 )" || rc=$?
  after="$(_tree_sum)"

  [ "$rc" -eq 0 ] \
    || cf "the dry run exited $rc, want 0: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  [ "$before" = "$after" ] \
    || cf "THE DRY RUN MUTATED THE TREE. Files now present: $(find "$R" -type f | sed "s|^$R/||" | tr '\n' ' ')"
  printf '%s' "$out" | grep -q 'dry run' \
    || cf "the dry run did not identify itself as one"

  # AND IT SAID SO. A fix that silently skipped the creation would satisfy the checksum
  # above while leaving the reader unable to tell the index is missing — the honest-blind-
  # spot duty (instruments.md § A.4). The dry run must ANNOUNCE the write it declined.
  printf '%s' "$out" | grep -q 'INDEX.md' \
    || cf "the dry run never mentioned INDEX.md, so a reader cannot tell --apply would create it"

  # THE OTHER DIRECTION, which is what makes the check above a real one: --apply DOES
  # create it. Without this leg, deleting the creation outright would pass.
  rc=0; out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" \
                  --milestone dry2 --before 2026-08-26 --apply 2>&1 )" || rc=$?
  [ -f "$R/progress/history/INDEX.md" ] \
    || cf "--apply did NOT create the index — the dry-run fix removed the behaviour instead of deferring it (rc=$rc)"

  unset -f _tree_sum
  finish "archive-progress.sh: the DEFAULT dry run leaves the tree byte-identical (whole-tree checksum) while still naming the index it would create, and --apply still creates it"
  teardown
}

# archive-progress.sh: the ordinal knife, the honest no-op, and the index
# =============================================================================
# WHY THESE EXIST (measured, not speculative). The rotation's only selector was a
# DATE, while the trigger that says a rotation is due is a BYTE threshold — and
# bytes cross it more than once in a working day. So the second rotation of a day
# had no expressible cut: it reported "Nothing to archive" and exited 0 on an
# over-threshold log. THE TOOL'S SUCCESS WAS WHAT MADE IT INERT, which is why the
# exit-3 case below asserts the ABSENCE of the green phrase and not just the code.
#
# DERIVE, DO NOT RE-HARDCODE: the threshold is read out of the REAL check-board.sh,
# so a retune there cannot silently make these cases vacuous. (cb_default is not
# usable — it expects a single-quoted value and this constant is a bare integer.)
ap_thresh() {
  sed -n 's/^PROGRESS_LOG_BYTE_THRESHOLD=\([0-9]*\).*/\1/p' "$REAL_SCRIPTS/check-board.sh" 2>/dev/null | head -1
}

# ap_seed <repo> <n_entries> <date> — a log of N same-day entries, padded so § Log
# lands OVER the derived threshold. Same-day on purpose: that is the condition a
# date knife cannot cut.
ap_seed() {
  local R="$1" n="$2" d="$3" thresh pad i
  thresh="$(ap_thresh)"; [ -n "$thresh" ] || { cf "(fixture) could not derive PROGRESS_LOG_BYTE_THRESHOLD"; return 1; }
  pad=$(( thresh / n + 200 ))          # per-entry padding that guarantees the crossing
  mkdir -p "$R/progress/history"
  { echo "# progress.md"; echo ""; echo "Preamble."; echo ""; echo "## Log"; echo ""
    for i in $(seq 1 "$n"); do
      echo "## $d [Dev] session $i"
      head -c "$pad" /dev/zero | tr '\0' 'x'; echo
      echo ""
    done
  } > "$R/progress.md"
  local got; got="$(awk '/^## Log[[:space:]]*$/{f=1} f{n+=length($0)+1} END{print n+0}' "$R/progress.md")"
  [ "$got" -gt "$thresh" ] || cf "(fixture) § Log is $got bytes, NOT over the $thresh threshold — the case would prove nothing"
}

# =============================================================================
# CASE — ONE GENERATED ROW, ONE CLOCK.
#
# archive-progress.sh's INDEX row has two date columns. `Covers` is grepped out of the
# chunk's own content, which move-issue.sh and subtask.sh stamped on the operator's LOCAL
# day; `Rotated` was `date -u`. Eight hours apart on this machine, for a third of every
# day, in one row, with nothing about it looking wrong. archive-sweep.md § 2 now rules it:
# a calendar DAY is local, an INSTANT is UTC and says Z.
#
# WALL-CLOCK FLAKE IS THE HAZARD HERE, so this case does not compare against "today". It
# runs the same rotation under two zones 26 HOURS APART — UTC+14 and UTC−12 can never
# share a calendar day, at any instant — and asserts the column moved WITH the operator.
# A UTC stamp is TZ-invariant and cannot satisfy that, at any hour. Both zones are POSIX
# `std offset` strings, so no zoneinfo database is needed.
# =============================================================================
case_rotation_day_uses_the_board_clock() {
  cf_reset
  make_sandbox
  local TZE='XXX-14' TZW='XXX+12'   # 26h apart — they NEVER share a calendar day
  local de dw out rc rot1 rot2
  de="$(TZ=$TZE date +%Y-%m-%d)"; dw="$(TZ=$TZW date +%Y-%m-%d)"

  # ── INSTRUMENT CHECK, and it must run FIRST. If `date` ignores TZ in this environment,
  #    every assertion below compares two identical strings and reports a green it could
  #    not have failed. That is a statement about the environment, so it is a SKIP.
  if [ "$de" = "$dw" ]; then
    skp "the rotation day comes from the board's clock" \
        "the two pinned zones ($TZE / $TZW) both returned $de — date is not honouring TZ here, so this case would prove nothing"
    teardown; return
  fi

  local R1="$SB_TMP/tz1" R2="$SB_TMP/tz2"
  ap_seed "$R1" 12 2026-08-26 || { finish "the rotation day comes from the board's clock"; teardown; return; }
  ap_seed "$R2" 12 2026-08-26 || { finish "the rotation day comes from the board's clock"; teardown; return; }

  out="$( TZ=$TZE "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R1" --milestone t1 --keep-last 4 --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "the east-zone rotation exited $rc: $out"
  out="$( TZ=$TZW "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R2" --milestone t2 --keep-last 4 --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "the west-zone rotation exited $rc: $out"

  # Read `Rotated` BY POSITION (field 5 of a leading-pipe row), not by pattern — a pattern
  # for a date would match the Covers column too and this case would read the wrong cell.
  rot1="$(awk -F'|' '/t1\.md/ { gsub(/ /,"",$5); print $5; exit }' "$R1/progress/history/INDEX.md" 2>/dev/null)"
  rot2="$(awk -F'|' '/t2\.md/ { gsub(/ /,"",$5); print $5; exit }' "$R2/progress/history/INDEX.md" 2>/dev/null)"
  [ -n "$rot1" ] && [ -n "$rot2" ] \
    || _fixture_die "case_rotation_day_uses_the_board_clock: no Rotated cell in one of the index rows — the column moved and this case is reading the wrong field."

  # EFFECT (i) — DIRECTION, not merely difference: the cell IS each operator's own day.
  [ "$rot1" = "$de" ] || cf "under TZ=$TZE the row reads Rotated '$rot1' but the day every other board artifact writes there is '$de'"
  [ "$rot2" = "$dw" ] || cf "under TZ=$TZW the row reads Rotated '$rot2' but the day every other board artifact writes there is '$dw'"
  # EFFECT (ii) — therefore the two zones DISAGREE. A UTC stamp is TZ-invariant and cannot.
  [ "$rot1" != "$rot2" ] \
    || cf "two rotations whose operators are 26 hours apart in calendar terms wrote the SAME Rotated day ('$rot1') — the column is on a clock the rest of the board is not"
  # EFFECT (iii) — the row's OTHER date column still comes from the chunk's own content.
  #    If this stops holding, (i) and (ii) are no longer about a row that mixes two clocks.
  awk -F'|' '/t1\.md/ { gsub(/ /,"",$3); print $3; exit }' "$R1/progress/history/INDEX.md" 2>/dev/null \
    | grep -qF '2026-08-26→2026-08-26' \
    || cf "the Covers column is not the seeded local span — the row's two date columns no longer share a source, so this case is not measuring a mixed row"

  finish "archive-progress.sh dates the INDEX row's Rotated column on the same clock the rest of the board writes (the operator's local day), so one generated row never mixes two clocks — proven across two zones 26 hours apart, which no UTC stamp can satisfy"
  teardown
}

case_archive_progress_ordinal_knife() {
  cf_reset
  make_sandbox
  local R="$SB_TMP/apo" out rc
  ap_seed "$R" 20 2026-08-26 || { finish "archive-progress.sh: --keep-last cuts a same-day log twice"; teardown; return; }

  # FIRST rotation of the day.
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone d1 --keep-last 8 --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "first --keep-last run exited $rc (expected 0): $out"
  local left; left="$(grep -c '^## 2026-08-26' "$R/progress.md" || true)"
  [ "$left" = "8" ] || cf "after --keep-last 8 the log holds $left entries, expected 8"

  # SECOND rotation, SAME CALENDAR DAY. This is the whole finding: a date knife
  # has nothing left to cut here, because everything before today already went.
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone d2 --keep-last 3 --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "SECOND same-day --keep-last run exited $rc (expected 0) — the duty cycle is not closed: $out"
  left="$(grep -c '^## 2026-08-26' "$R/progress.md" || true)"
  [ "$left" = "3" ] || cf "after the second cut the log holds $left entries, expected 3"

  # THE CONTROL: the date knife on the same fixture cuts NOTHING. Without this the
  # case proves the new flag runs, not that it does something the old one could not.
  ap_seed "$R" 20 2026-08-26 || true
  rm -f "$R/progress/history"/*.md
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone dc --before 2026-08-26 --apply 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(control) --before on an all-today log exited 0 — it should not have found a cut"
  [ -f "$R/progress/history/dc.md" ] && cf "(control) --before wrote a chunk on an all-today log"

  finish "archive-progress.sh: --keep-last cuts a same-day log TWICE (the duty cycle), where --before cuts nothing"
  teardown
}

case_archive_progress_honest_noop() {
  cf_reset
  make_sandbox
  local R="$SB_TMP/apn" out rc thresh
  thresh="$(ap_thresh)"
  ap_seed "$R" 20 2026-08-26 || { finish "archive-progress.sh: nothing-matched over threshold is not a green"; teardown; return; }

  # Nothing matches (all entries are today), and § Log is OVER the threshold.
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone n1 --before 2026-08-26 2>&1 )"; rc=$?
  [ "$rc" -eq 3 ] || cf "nothing-matched-while-due exited $rc, expected 3 (a distinct code, not a failure and not a pass): $out"
  printf '%s' "$out" | grep -q 'ROTATION IS STILL DUE' || cf "the over-threshold no-op did not say a rotation is still due: $out"
  printf '%s' "$out" | grep -q "$thresh" || cf "the over-threshold no-op did not name the threshold it measured against: $out"
  # THE REDDENING CONTROL, and the point of the whole case: the GREEN PHRASE must
  # be ABSENT. Its presence is what made the old behaviour read as an all-clear,
  # so a fix that added the warning and kept the phrase would still be broken.
  printf '%s' "$out" | grep -q 'Nothing to archive' \
    && cf "the over-threshold no-op still printed the green phrase 'Nothing to archive' — that is the false all-clear"

  # AND THE OTHER DIRECTION: under threshold, nothing matched, that IS a green and
  # keeps the phrase. Both states must exist and be distinct, or the change is a
  # rename rather than a new state.
  { echo "# progress.md"; echo ""; echo "## Log"; echo ""; echo "## 2026-08-26 [Dev] one small entry"; echo "body"; echo ""; } > "$R/progress.md"
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone n2 --before 2026-08-26 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "under-threshold nothing-matched exited $rc, expected 0: $out"
  printf '%s' "$out" | grep -q 'Nothing to archive' \
    || cf "under threshold the honest green phrase 'Nothing to archive' is missing: $out"
  printf '%s' "$out" | grep -q 'under threshold' \
    || cf "the under-threshold green did not state the measurement that makes it a green: $out"

  finish "archive-progress.sh: nothing-matched OVER threshold exits 3 without the green phrase; UNDER threshold exits 0 with it"
  teardown
}

case_archive_progress_index() {
  cf_reset
  make_sandbox
  local R="$SB_TMP/api" out rc
  ap_seed "$R" 12 2026-08-26 || { finish "archive-progress.sh: every chunk gains an index row"; teardown; return; }

  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone c1 --keep-last 4 --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "--apply exited $rc: $out"
  local idx="$R/progress/history/INDEX.md"
  [ -f "$idx" ] || { cf "no index was written or created"; finish "archive-progress.sh: every chunk gains an index row"; teardown; return; }
  grep -qF 'c1.md' "$idx" || cf "the chunk has no index row — a rotated chunk is findable only by ls, which is the defect"
  # THE SPAN IS THE LOAD-BEARING COLUMN: a row without it is a filename, and a
  # filename is what `ls` already gave you.
  grep -E '\| *\[`c1\.md`\].*2026-08-26 → 2026-08-26 *\| *8 *\|' "$idx" >/dev/null \
    || cf "the index row is missing its date span and/or its entry count: $(grep 'c1.md' "$idx")"

  # A SECOND chunk goes ABOVE the first (newest first) and rewrites no row.
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone c2 --keep-last 1 --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "the second --apply exited $rc: $out"
  local first_row; first_row="$(grep -m1 '^| \[' "$idx")"
  printf '%s' "$first_row" | grep -qF 'c2.md' \
    || cf "the newest chunk is not the first row (newest-first is format law): $first_row"
  grep -qF 'c1.md' "$idx" || cf "the earlier index row was lost — the index is append-only"

  # THE EARNED REFUSAL: with chunks present and the index gone, it must REFUSE and
  # must NOT write a fresh empty index — that index would deny the chunks beside it.
  rm -f "$idx"
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone c3 --keep-last 1 --apply 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "a missing index with chunks present did NOT refuse: $out"
  [ -f "$idx" ] && cf "it fabricated an index while chunks existed — that row-less index denies them"
  printf '%s' "$out" | grep -qF 'c1.md' || cf "the refusal did not name the chunks whose rows would be missing: $out"

  # AND THE OTHER SIDE OF THAT DECISION: no chunks, no index -> CREATE, because
  # "nothing was ever archived" is then simply true. This is the upgrade path.
  rm -f "$R/progress/history"/*.md
  ap_seed "$R" 12 2026-08-26 || true
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone c4 --keep-last 4 --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "an absent index with NO chunks should be created, not refused (the upgrade path) — exited $rc: $out"
  grep -qF 'c4.md' "$idx" || cf "the created index has no row for the chunk that created it"

  finish "archive-progress.sh: chunks gain index rows with their spans, newest-first and append-only; a missing index REFUSES where chunks exist and is CREATED where none do"
  teardown
}

cb_default() {  # <VAR_NAME>
  sed -n "s/^$1='\(.*\)'/\1/p" "$REAL_SCRIPTS/check-board.sh" 2>/dev/null | head -1
}

# seed_issue_mismatched <folder> <filename_id> <slug> <frontmatter_id>
seed_issue_mismatched() {
  local folder="$1" file_id="$2" slug="$3" fm_id="$4"
  seed_issue "$folder" "$file_id" "$slug" chore "Mismatch fixture"
  local f="$SB_WORK/progress/$folder/${file_id}-${slug}.md"
  sed -i.bak "1,/^---[[:space:]]*\$/s/^id:.*/id: ${fm_id}/" "$f"
  rm -f "$f.bak"
}

# Strip check (d) out of the SANDBOX copy. The control leg re-runs a board that
# DID produce a finding and asserts the finding disappears — so a passing leg is
# attributable to the new logic rather than to any output the script happened to
# emit.
cb_remove_check_d() {
  local s="$SB_WORK/scripts/check-board.sh"
  grep -q '# BEGIN check (d)' "$s" \
    || { cf "(control) no '# BEGIN check (d)' seam in check-board.sh — cannot ablate"; return 1; }
  sed -i.bak '/# BEGIN check (d)/,/# END check (d)/d' "$s"; rm -f "$s.bak"
  grep -q '# BEGIN check (d)' "$s" && { cf "(control) the ablation removed nothing"; return 1; }
  bash -n "$s" || { cf "(control) the ablated check-board.sh no longer parses"; return 1; }
  return 0
}

case_check_board_id_clean() {
  cf_reset
  make_sandbox

  # Derive the three constants, and prove the derivation itself is live — an empty
  # value means the defaults block moved.
  local status_folders id_key id_pattern ncols
  status_folders="$(cb_default STATUS_FOLDERS)"
  id_key="$(cb_default ISSUE_ID_KEY)"
  id_pattern="$(cb_default ISSUE_ID_PATTERN)"
  [ -n "$status_folders" ] || cf "could not derive STATUS_FOLDERS from the defaults block"
  [ -n "$id_key" ]         || cf "could not derive ISSUE_ID_KEY from the defaults block"
  [ -n "$id_pattern" ]     || cf "could not derive ISSUE_ID_PATTERN from the defaults block"
  # NO COLUMN COUNT HERE. This asserted "= 6", which is a census over a set the kit may
  # legitimately grow: a seventh status would redden this case rather than the property
  # it protects, and the number would have to be chased here as well as at the seam.
  # What the case actually needs is that the SPLIT worked — an unsplit blob would make
  # every membership test below vacuous by matching nothing — and that the one member
  # this case depends on is present, which the named assertion below states with its
  # reason attached. A count states neither.
  ncols="$(printf '%s' "$status_folders" | tr '|' '\n' | grep -c . || true)"
  [ "$ncols" -gt 1 ] || cf "STATUS_FOLDERS did not split into columns — derived '$status_folders'"
  printf '%s' "$status_folders" | tr '|' '\n' | grep -qx done \
    || cf "STATUS_FOLDERS lacks done/ — a new mint can collide with an ARCHIVED issue"

  seed_issue todo        "$SB_PREFIX-100" alpha chore "Healthy alpha"
  seed_issue in_progress "$SB_PREFIX-101" beta  chore "Healthy beta"
  seed_issue done        "$SB_PREFIX-102" gamma chore "Healthy gamma"

  # NEAR MISS — an id mentioned in PROSE, and a frontmatter shape QUOTED in the
  # body at line start. A whole-file grep for '^id:' would read the first of those
  # as this file's own id. The parse must be anchored to the frontmatter block.
  cat >> "$SB_WORK/progress/todo/$SB_PREFIX-100-alpha.md" <<EOF

This paragraph supersedes progress/done/$SB_PREFIX-379-old.md and quotes a
frontmatter verbatim, at line start, exactly as a reader would paste it:

id: $SB_PREFIX-999
id: $SB_PREFIX-101

- 2026-01-02 [PM] Cross-references $SB_PREFIX-101 and $SB_PREFIX-102 in prose only.
EOF

  publish_sandbox

  local out rc
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc on a healthy board (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep -q '^\[d\]' || cf "no [d] section in the report — the check is absent"
  printf '%s\n' "$out" | grep -qi 'duplicate' \
    && cf "a duplicate finding on a HEALTHY board — prose mentions were misread: $out"
  printf '%s\n' "$out" | grep -qi 'disagrees' && cf "a mismatch finding on a HEALTHY board: $out"
  printf '%s\n' "$out" | grep -q "$SB_PREFIX-999" \
    && cf "an id quoted in prose was read as frontmatter: $out"
  printf '%s\n' "$out" | grep -q 'board-drift: clean ✓' \
    || cf "the healthy board did not report clean: $out"

  finish "check (d): a healthy board reads clean, and prose/quoted-frontmatter near-misses do not fire"
  teardown
}

case_check_board_id_duplicate() {
  cf_reset
  make_sandbox

  # CROSS-COLUMN duplicate (todo/ vs done/) — the case the six-column breadth
  # exists for; a naive per-directory loop would miss it.
  seed_issue todo "$SB_PREFIX-195" first-shape  bug   "Dev-filed bug"
  seed_issue done "$SB_PREFIX-195" second-shape spike "PM-minted spike"
  # SAME-COLUMN duplicate, different slugs.
  seed_issue todo "$SB_PREFIX-300" same-column-one chore "Same column one"
  seed_issue todo "$SB_PREFIX-300" same-column-two chore "Same column two"
  # A TRIPLE — all three files must be named.
  seed_issue blocked      "$SB_PREFIX-400" triple-a chore "Triple a"
  seed_issue qa_complete  "$SB_PREFIX-400" triple-b chore "Triple b"
  seed_issue dev_complete "$SB_PREFIX-400" triple-c chore "Triple c"
  # A healthy control that must NOT be named.
  seed_issue in_progress "$SB_PREFIX-500" innocent chore "Innocent bystander"
  publish_sandbox

  local out rc dline
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc with planted duplicates (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep -q 'board-drift: findings above' \
    || cf "the duplicates did not reach the report footer: $out"

  dline="$(printf '%s\n' "$out" | grep -i 'duplicate' | grep "$SB_PREFIX-195" || true)"
  [ -n "$dline" ] || cf "no duplicate finding naming $SB_PREFIX-195: $out"
  printf '%s' "$dline" | grep -q "$SB_PREFIX-195-first-shape.md" \
    || cf "the $SB_PREFIX-195 finding does not name the todo/ file: $dline"
  printf '%s' "$dline" | grep -q "$SB_PREFIX-195-second-shape.md" \
    || cf "the $SB_PREFIX-195 finding does not name the done/ file — cross-column breadth missing: $dline"

  dline="$(printf '%s\n' "$out" | grep -i 'duplicate' | grep "$SB_PREFIX-300" || true)"
  [ -n "$dline" ] || cf "no duplicate finding naming the same-column pair: $out"
  printf '%s' "$dline" | grep -q 'same-column-one.md' || cf "the pair finding omits file one: $dline"
  printf '%s' "$dline" | grep -q 'same-column-two.md' || cf "the pair finding omits file two: $dline"

  dline="$(printf '%s\n' "$out" | grep -i 'duplicate' | grep "$SB_PREFIX-400" || true)"
  [ -n "$dline" ] || cf "no duplicate finding naming the triple: $out"
  printf '%s' "$dline" | grep -q 'triple-a.md' || cf "the triple omits a: $dline"
  printf '%s' "$dline" | grep -q 'triple-b.md' || cf "the triple omits b: $dline"
  printf '%s' "$dline" | grep -q 'triple-c.md' || cf "the triple omits c: $dline"

  printf '%s\n' "$out" | grep -i 'duplicate' | grep -q "$SB_PREFIX-500" \
    && cf "the innocent single-id issue was named as a duplicate: $out"

  # ACTIONABLE, not merely accusatory — it says what to do, in the same register.
  printf '%s\n' "$out" | grep -i 'duplicate' | grep -q 'next-id.sh' \
    || cf "the duplicate finding does not say what to do (next-id.sh)"
  printf '%s\n' "$out" | grep -i 'duplicate' | grep -q '⚠' \
    || cf "the duplicate finding does not use the ⚠ register of the other checks"

  # CONTROL — ablate check (d) and the finding must vanish.
  if cb_remove_check_d; then
    out="$(cb_run)"; rc=$?
    [ "$rc" -eq 0 ] || cf "(control) the ablated check-board.sh exited $rc"
    printf '%s\n' "$out" | grep -qi 'duplicate' \
      && cf "(control) a duplicate finding survived the ablation — this case proves nothing: $out"
    printf '%s\n' "$out" | grep -q 'board-drift: clean ✓' \
      || cf "(control) without check (d) the duplicate board did not read clean, so the finding is not attributable to it: $out"
  fi

  finish "check (d): duplicate ids reported cross-column, same-column and as a triple (all files named), exit 0, ablation-proven"
  teardown
}

case_check_board_id_mismatch() {
  cf_reset
  make_sandbox

  seed_issue_mismatched todo         "$SB_PREFIX-200" ahead-fixture  "$SB_PREFIX-201"
  seed_issue_mismatched dev_complete "$SB_PREFIX-210" behind-fixture "$SB_PREFIX-205"
  # Degenerate frontmatters: no id at all, and a malformed one. This reporter runs
  # inside the SessionStart hook — it must degrade to a finding, never crash.
  seed_issue blocked "$SB_PREFIX-220" no-id chore "No id at all"
  sed -i.bak '/^id:/d' "$SB_WORK/progress/blocked/$SB_PREFIX-220-no-id.md"
  rm -f "$SB_WORK/progress/blocked/$SB_PREFIX-220-no-id.md.bak"
  seed_issue_mismatched qa_complete "$SB_PREFIX-230" malformed "not-an-id-at-all"
  seed_issue in_progress "$SB_PREFIX-240" healthy chore "Healthy"
  publish_sandbox

  local out rc line
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc with planted mismatches (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep -qiE 'traceback|syntax error|command not found|unbound variable' \
    && cf "the reporter emitted an interpreter error on a degenerate frontmatter: $out"
  printf '%s\n' "$out" | grep -q 'board-drift: findings above' \
    || cf "the mismatches did not reach the report footer: $out"

  line="$(printf '%s\n' "$out" | grep "$SB_PREFIX-200-ahead-fixture.md" || true)"
  [ -n "$line" ] || cf "no finding for the frontmatter-AHEAD mismatch: $out"
  printf '%s' "$line" | grep -q "$SB_PREFIX-201" || cf "the ahead finding does not name the frontmatter id: $line"
  printf '%s' "$line" | grep -q "$SB_PREFIX-200" || cf "the ahead finding does not name the filename id: $line"
  line="$(printf '%s\n' "$out" | grep "$SB_PREFIX-210-behind-fixture.md" || true)"
  [ -n "$line" ] || cf "no finding for the frontmatter-BEHIND mismatch: $out"
  printf '%s' "$line" | grep -q "$SB_PREFIX-205" || cf "the behind finding does not name the frontmatter id: $line"
  printf '%s\n' "$out" | grep -q "$SB_PREFIX-220-no-id.md" \
    || cf "an issue with NO frontmatter id produced no finding: $out"
  printf '%s\n' "$out" | grep -q "$SB_PREFIX-230-malformed.md" \
    || cf "an issue with a MALFORMED frontmatter id produced no finding: $out"
  printf '%s\n' "$out" | grep -q "$SB_PREFIX-240-healthy.md" \
    && cf "the healthy control issue was reported: $out"

  # CONTROL — ablate check (d) and every finding must vanish.
  if cb_remove_check_d; then
    out="$(cb_run)"; rc=$?
    [ "$rc" -eq 0 ] || cf "(control) the ablated check-board.sh exited $rc"
    printf '%s\n' "$out" | grep -q "$SB_PREFIX-200-ahead-fixture.md" \
      && cf "(control) a mismatch finding survived the ablation — this case proves nothing: $out"
    printf '%s\n' "$out" | grep -q 'board-drift: clean ✓' \
      || cf "(control) without check (d) the mismatched board did not read clean: $out"
  fi

  finish "check (d): id/filename mismatch both directions + missing/malformed degrade to findings, exit 0, ablation-proven"
  teardown
}

# =============================================================================
# CASE — check (d) reads a frontmatter that does NOT start on line 1.
#
# Measured on the very first card of a fresh install: the kit's own templates open
# with an HTML comment saying what the initializer stamps, so a minted card carries
# that comment ABOVE its frontmatter — and a parser demanding `---` on line 1
# reported every such card as having no id at all. The board read RED on a
# perfectly healthy first day, which is the fastest way to teach an adopter to
# ignore the board report.
# =============================================================================
# =============================================================================
# CASE — THE ARMS ANSWER ABOUT THE NAMED REF, NOT ABOUT THE CHECKOUT.
#
# This is the control the pre-P3 harness could not express, and its absence is why
# the defect survived so long: the existing board cases publish the whole sandbox
# and THEN run the checker, so the working tree and the trunk agree and every one of
# them passes under both the broken and the fixed implementation. A control that
# cannot fail is not a control.
#
# So this case makes the two DISAGREE and asserts which one the report answers
# about. It uses check (d) — id uniqueness — because that is the arm where reading
# the checkout is not merely stale but structurally incapable: duplicate ids can
# only ARISE on the trunk (two concurrent mints both landing), and a branch contains
# at most one of the pair.
#
# Both halves are asserted, in opposite directions:
#   (i)  a duplicate that exists ONLY in the working tree is NOT reported, and the
#        report names the ref it read instead;
#   (ii) the same duplicate, once published, IS reported.
# An implementation that reads the checkout fails (i). One that reads nothing at all,
# or that skips whenever the trees differ, fails (ii).
# =============================================================================
# =============================================================================
# CASE — ARM [f1]: THE MAIN CHECKOUT IS WATCHED TOO.
#
# The home the drift report did not watch. Everything the kit classifies as METADATA
# commits direct to the trunk from the primary checkout — rulings, PRDs, issue edits,
# role docs, process/**, progress.md, the adapter — and arm [f] watched only the board
# mover's auxiliary worktree. So the one home carrying the process's own memory was
# the one home nothing watched, and the report said `clean ✓` with unpublished rulings
# sitting beside it. Measured on a real program at the cost of a successor's first
# hour, hunting an authority its own launch instructions cited.
#
# Both directions, so neither half can be vacuous:
#   (i)  a committed-but-unpushed trunk commit in the main checkout IS reported, and
#        the finding names that home rather than the auxiliary one;
#   (ii) once pushed, it is NOT reported — so the arm is measuring publication state
#        and not merely "a commit exists".
# =============================================================================
case_check_board_main_checkout_unpushed() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-220" watched chore "Main-checkout watch"
  publish_sandbox

  local out rc
  # A metadata commit made the way every ruling is made: in the main checkout, on the
  # trunk, direct — and NOT pushed.
  printf '\n### D-01 — a ruling nobody else can see yet\n' >> "$SB_WORK/progress.md"
  git -C "$SB_WORK" add progress.md >/dev/null 2>&1
  sbcommit -qm "[PM] record a ruling" >/dev/null 2>&1
  [ "$(git -C "$SB_WORK" rev-list --count "origin/$SB_TRUNK..refs/heads/$SB_TRUNK" 2>/dev/null)" = "1" ] \
    || cf "(control) the sandbox is not actually 1 commit ahead — the premise does not exist"

  # --- (i) it must be reported, and named as the MAIN checkout -----------------
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep -q '\[f1\]' \
    || cf "(i) no [f1] reading at all — the main checkout is still unwatched: $out"
  printf '%s\n' "$out" | grep '\[f1\]' | grep -qi 'ahead' \
    || cf "(i) [f1] did not report the unpushed commit: $(printf '%s\n' "$out" | grep '\[f1\]')"
  printf '%s\n' "$out" | grep -q 'board-drift: findings above' \
    || cf "(i) unpushed metadata did not reach the report footer: $out"
  # The finding must be attributed to the right home, or it is indistinguishable from
  # the auxiliary worktree's own divergence.
  printf '%s\n' "$out" | grep '\[f1\]' | grep -qi 'main checkout' \
    || cf "(i) the [f1] finding does not name the main checkout as the home: $(printf '%s\n' "$out" | grep '\[f1\]')"

  # --- (ii) ABLATION: push it, and it must go quiet ----------------------------
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc after the push (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep '\[f1\]' | grep -qi 'ahead of' \
    && cf "(ii) ABLATION FAILED — [f1] still reports the commit as unpublished after it was pushed, so half (i) proves nothing: $(printf '%s\n' "$out" | grep '\[f1\]')"
  printf '%s\n' "$out" | grep '\[f1\]' | grep -q '✓' \
    || cf "(ii) [f1] did not report clean after the push: $(printf '%s\n' "$out" | grep '\[f1\]')"

  # And the green states its span rather than implying total coverage.
  printf '%s\n' "$out" | grep -qi 'orphaned sibling' \
    || cf "the [f] green does not state its span — an unqualified pass implies it saw stranding it cannot see: $out"

  finish "check-board [f1]: an unpushed metadata commit in the MAIN checkout is reported and named as that home, and goes quiet once pushed (ablation-proven); the green states its span"
  teardown
}

# =============================================================================
# CASE — UNRUNNABLE IS NOT FAIL, AND `ran` EXCLUDES IT.
#
# verify.sh has four result states: PASS, FAIL, SKIP and UNRUNNABLE. The fourth
# exists because `127` (command not found) and `126` (found, not executable) are
# statements about the RUNNER'S ENVIRONMENT, not verdicts about the subject — the
# gate never executed, so nothing was measured. Spelling that FAIL sends a reader to
# debug a tree that may be perfectly fine.
#
# WHY THIS CASE EXISTS AT ALL: the change that added the state was proven in a
# scratch directory that no longer exists, and the implementing leg said so rather
# than letting it ship quiet — by instruments.md § B that makes it unproven, not
# passing. It could not write the case because this file is owned elsewhere. This
# discharges that.
#
# TWO ASSERTIONS EARN THEIR KEEP, AND BOTH ARE THE SECOND DIRECTION:
#   • `FAIL <gate>` must be ABSENT for an unrunnable gate. Asserting UNRUNNABLE is
#     present cannot catch a regression that emits BOTH, or that re-merges the
#     states — and re-merging is what happened once during the change itself.
#   • `ran:` must EXCLUDE the unrunnable. The first implementation printed `ran: 3`
#     when one of three never ran, so the count line contradicted its own per-gate
#     lines. Review did not catch it; running it did.
# Both are held here in the direction that fails when the states collapse.
# =============================================================================
case_verify_unrunnable_vs_fail() {
  cf_reset
  make_sandbox
  # Ship-state first: make_sandbox declares its own always-green gate, and this case
  # needs to control the whole table.
  _neu_array "$SB_WORK/scripts/verify.sh" GATES
  # THE FAILING GATE IS A SANDBOX-LOCAL SCRIPT, NOT `/bin/false`, and that is not
  # fussiness. `/bin/false` does not exist on every platform this kit has to run on
  # (measured: absent on darwin, where it is /usr/bin/false), and an absent command
  # returns 127 — so a portability slip in THIS FIXTURE is indistinguishable from the
  # defect the case exists to detect. A script the sandbox writes and chmod +x's has
  # no PATH dependency at all. Same reasoning as the non-executable fixture below,
  # one bit apart.
  printf '#!/usr/bin/env bash\nexit 1\n' > "$SB_WORK/failing-gate"
  chmod +x "$SB_WORK/failing-gate"
  _declare_gate 'green|core|/bin/echo gate-ran-green'
  _declare_gate 'broken|core|./failing-gate'
  _declare_gate 'missing-interp|core|/nonexistent-dir-for-the-harness/interpreter'
  publish_sandbox

  local v="$SB_WORK/scripts/verify.sh" out rc counts
  out="$( cd "$SB_WORK" && "$v" 2>&1 )"; rc=$?

  # A red run, and red for a reason that includes an unknown.
  [ "$rc" -ne 0 ] || cf "verify.sh exited 0 with a failing gate and an unrunnable one: $out"

  # --- the three states, each present in its OWN vocabulary ------------------
  printf '%s\n' "$out" | grep -q '^PASS  green$' \
    || cf "no 'PASS  green' line — the runnable-and-green gate is not reported: $out"
  printf '%s\n' "$out" | grep -q '^FAIL  broken (rc=1)$' \
    || cf "no 'FAIL  broken (rc=1)' line — a genuinely failing gate must still say FAIL: $out"
  printf '%s\n' "$out" | grep -q '^UNRUNNABLE  missing-interp ' \
    || cf "no 'UNRUNNABLE  missing-interp' line — the fourth state is not being reported: $out"
  printf '%s\n' "$out" | grep '^UNRUNNABLE  missing-interp ' | grep -q 'rc=127' \
    || cf "the UNRUNNABLE line does not carry rc=127: $(printf '%s\n' "$out" | grep '^UNRUNNABLE')"
  printf '%s\n' "$out" | grep '^UNRUNNABLE  missing-interp ' | grep -qi 'NOTHING was measured' \
    || cf "the UNRUNNABLE line does not say nothing was measured — the label alone leaves the reader to guess: $(printf '%s\n' "$out" | grep '^UNRUNNABLE')"

  # --- THE SECOND DIRECTION: the states must not have collapsed either way ---
  printf '%s\n' "$out" | grep -q '^FAIL  missing-interp' \
    && cf "the unrunnable gate ALSO produced a 'FAIL' line — the two states are merged, which is the whole defect this change closes: $out"
  printf '%s\n' "$out" | grep -q '^UNRUNNABLE  broken' \
    && cf "a genuinely FAILING gate was labelled UNRUNNABLE — the states are merged in the other direction, and a real red now reads as an environment problem: $out"

  # --- the count line, and `ran` EXCLUDING the unrunnable --------------------
  counts="$(printf '%s\n' "$out" | grep '^gates declared:' || true)"
  [ -n "$counts" ] || cf "no 'gates declared:' count line — verify-gate.md § 4: a pass with no count is an assertion, not a measurement: $out"
  printf '%s' "$counts" | grep -q 'gates declared: 3' || cf "the count line does not report 3 declared gates: $counts"
  printf '%s' "$counts" | grep -q 'ran: 2' \
    || cf "REGRESSION — 'ran' does not exclude the unrunnable gate (expected 'ran: 2' of 3 declared). The count line is re-merging the two states the per-gate lines separate: $counts"
  printf '%s' "$counts" | grep -q 'passed: 1'        || cf "the count line does not report 1 passed: $counts"
  printf '%s' "$counts" | grep -q 'failed: 1'        || cf "the count line does not report 1 failed: $counts"
  printf '%s' "$counts" | grep -q 'could not run: 1' || cf "the count line does not report 1 could-not-run: $counts"
  printf '%s' "$counts" | grep -q 'skipped: 0'       || cf "the count line does not report 0 skipped: $counts"
  # And the block says what an unrunnable gate MEANS, since a reader quotes this block.
  printf '%s\n' "$out" | grep -qi 'UNKNOWN, not a measured failure' \
    || cf "the summary does not say the unrunnable gate is an UNKNOWN rather than a failure: $out"

  # --- rc=126 is the same state: found, but not executable ------------------
  # The implementation claims {126,127}, so both are held. A file that exists and is
  # not executable is the other half, and it is the half a chmod regression breaks.
  _neu_array "$v" GATES
  printf '#!/usr/bin/env bash\necho should-never-run\n' > "$SB_WORK/not-executable-gate"
  chmod 0644 "$SB_WORK/not-executable-gate"
  _declare_gate 'green|core|/bin/echo gate-ran-green'
  _declare_gate 'not-exec|core|./not-executable-gate'
  publish_sandbox
  out="$( cd "$SB_WORK" && "$v" 2>&1 )"; rc=$?
  if printf '%s\n' "$out" | grep -q '^UNRUNNABLE  not-exec '; then
    printf '%s\n' "$out" | grep '^UNRUNNABLE  not-exec ' | grep -q 'rc=126' \
      || cf "the non-executable gate is UNRUNNABLE but not at rc=126: $(printf '%s\n' "$out" | grep '^UNRUNNABLE')"
    printf '%s\n' "$out" | grep -q '^FAIL  not-exec' \
      && cf "the non-executable gate produced BOTH UNRUNNABLE and FAIL: $out"
    printf '%s\n' "$out" | grep '^gates declared:' | grep -q 'ran: 1' \
      || cf "'ran' does not exclude the rc=126 gate: $(printf '%s\n' "$out" | grep '^gates declared:')"
    [ "$rc" -ne 0 ] || cf "verify.sh exited 0 with an unrunnable gate — finish-pr treats a green --quick as a landing precondition: $out"
  else
    # Not every shell/platform returns 126 here. That is an environment fact, not a
    # defect, and it is reported as one rather than quietly passing or failing.
    skp "verify.sh: rc=126 (found, not executable) is UNRUNNABLE" "this platform did not produce rc=126 for a non-executable gate command; the rc=127 half is asserted in the case above"
  fi

  finish "verify.sh: UNRUNNABLE is reported for rc=127 and is NOT also FAIL, a real failure is still FAIL and NOT unrunnable, and the count line's 'ran' EXCLUDES the gate that never executed"
  teardown
}

# =============================================================================
# CASE — CHECK (d)'s REGISTER ARM: the identifier space with no textual conflict.
#
# The board's id space collides loudly enough that git notices; a REGISTER's does
# not. Two legs minting the same `### D-NN` in DIFFERENT SECTIONS of an append-only
# register produce NO textual conflict at all, so a rebase merges both cleanly and
# the duplicate lands with no witness. That is the shape this arm exists for and the
# second scenario below is it.
#
# The arm landed proven by hand only, which by instruments.md § B item 2 makes it
# UNPROVEN rather than passing. This encodes what was proven.
#
# The register's path/mark/shape are DERIVED from the script's own REGISTERS record,
# never re-typed — the same contract every other constant in these cases follows.
# =============================================================================
case_check_board_registers() {
  cf_reset
  make_sandbox

  local registers reg_path reg_mark reg_shape out rc
  registers="$(cb_default REGISTERS)"
  [ -n "$registers" ] || { cf "could not derive REGISTERS from the defaults block"; finish "check (d): the register arm"; teardown; return; }
  reg_path="${registers%%|*}"
  reg_mark="$(printf '%s' "$registers" | awk -F'|' '{print $2}')"
  reg_shape="$(printf '%s' "$registers" | awk -F'|' '{print $3}')"
  [ -n "$reg_path" ]  || cf "the derived register path is empty ($registers)"
  [ -n "$reg_mark" ]  || cf "the derived heading mark is empty ($registers)"
  [ -n "$reg_shape" ] || cf "the derived id shape is empty ($registers)"
  mkdir -p "$SB_WORK/$(dirname "$reg_path")"

  # --- (1) CLEAN: distinct ids, reported distinct, with the file named ---------
  cat > "$SB_WORK/$reg_path" <<EOF
# DECISIONS
## A. First bucket
${reg_mark}D-01 — first
## B. Second bucket
${reg_mark}D-02 — second
EOF
  publish_sandbox
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(1) check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep -q "$reg_path" \
    || cf "(1) the arm does not name the register it read: $out"
  printf '%s\n' "$out" | grep "$reg_path" | grep -q '2 distinct' \
    || cf "(1) a clean register was not reported as 2 distinct: $(printf '%s\n' "$out" | grep "$reg_path")"
  printf '%s\n' "$out" | grep -qi 'DUPLICATE id' \
    && cf "(1) a duplicate was reported on a clean register: $out"
  printf '%s\n' "$out" | grep -q 'board-drift: clean ✓' || cf "(1) a clean register did not read clean: $out"

  # --- (2) THE CROSS-SECTION DUPLICATE: no textual conflict, must be caught ----
  cat > "$SB_WORK/$reg_path" <<EOF
# DECISIONS
## A. First bucket
${reg_mark}D-07 — minted by one leg
${reg_mark}D-01 — unrelated
## B. Second bucket
${reg_mark}D-07 — minted by another leg, in a different section, no conflict
EOF
  publish_sandbox
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(2) check-board.sh exited $rc with a planted duplicate (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep -qi 'DUPLICATE id' \
    || cf "(2) a CROSS-SECTION duplicate was NOT reported — this is the collision the arm exists for and it produces no textual conflict: $out"
  printf '%s\n' "$out" | grep -i 'DUPLICATE id' | grep -q 'D-07' \
    || cf "(2) the duplicate finding does not name D-07: $(printf '%s\n' "$out" | grep -i 'DUPLICATE')"
  printf '%s\n' "$out" | grep -q 'board-drift: findings above' \
    || cf "(2) the duplicate did not reach the report footer: $out"

  # --- (3) THE D-9 / D-10 MAXIMUM, asserted AGAINST the wrong answer ----------
  # A section-grouped register with D-10 ABOVE D-9. Both plausible wrong readings
  # give 9: positional `tail -1` takes the file's last line, and a byte compare
  # sorts "D-10" before "D-9". Asserting only "says 10" would pass an
  # implementation that got 10 by luck on other data; asserting NOT 9 is what makes
  # this control sharp, because both wrong answers are the SAME wrong answer.
  cat > "$SB_WORK/$reg_path" <<EOF
# DECISIONS
## A. First bucket
${reg_mark}D-10 — later id, earlier in the file
## B. Second bucket
${reg_mark}D-9 — earlier id, later in the file
EOF
  publish_sandbox
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(3) check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep "$reg_path" | grep -q 'highest id number 10' \
    || cf "(3) the maximum was not reported as 10 over a section-grouped register: $(printf '%s\n' "$out" | grep "$reg_path")"
  printf '%s\n' "$out" | grep "$reg_path" | grep -q 'highest id number 9' \
    && cf "(3) the maximum was reported as 9 — that is BOTH wrong answers (positional tail and byte-compare sort agree on it), so the read is not order-independent: $(printf '%s\n' "$out" | grep "$reg_path")"
  printf '%s\n' "$out" | grep -qi 'DUPLICATE id' \
    && cf "(3) D-9 and D-10 were read as duplicates — the id shape is matching too little: $out"

  finish "check (d) register arm: a clean register reads distinct and names its file, a CROSS-SECTION duplicate (no textual conflict) is caught by id, and the maximum over a section-grouped register is 10 and not 9 (asserted against both wrong answers)"
  teardown
}

# =============================================================================
# CASE — AN ABSENT REGISTER SKIPS, AND THE CLEARANCE SAYS NOTHING WAS READ.
#
# Separate from the case above because the assertion is about the CLEARANCE LINE,
# not about a register. The arm's first version printed "every declared register's
# ids distinct" on a run where every register was SKIPPED — a pass over operands
# that were never read, which is instruments.md § A.4's own rule failing inside the
# arm enforcing it. A tick that covers nothing is worse than no tick, because a
# reader quoting it has been told the registers are clean.
# =============================================================================
case_check_board_register_absent() {
  cf_reset
  make_sandbox
  local registers reg_path out rc
  registers="$(cb_default REGISTERS)"
  reg_path="${registers%%|*}"
  [ -n "$reg_path" ] || { cf "could not derive the register path"; finish "check (d): an absent register"; teardown; return; }
  [ ! -e "$SB_WORK/$reg_path" ] \
    || cf "(control) the sandbox already has $reg_path — this case's premise is that it is absent"
  seed_issue todo "$SB_PREFIX-230" noreg chore "No register here"
  publish_sandbox

  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep -q "$reg_path" \
    || cf "the absent register is not mentioned at all — a silently omitted line is the defect drift-report.md § 3 names: $out"
  printf '%s\n' "$out" | grep "$reg_path" | grep -qi 'skipped' \
    || cf "the absent register was not reported as skipped: $(printf '%s\n' "$out" | grep "$reg_path")"
  # THE CLEARANCE MUST NOT COVER IT.
  printf '%s\n' "$out" | grep -qi 'NO register was read' \
    || cf "the clearance line does not say NO register was read — a pass over unread operands: $out"
  printf '%s\n' "$out" | grep -qi 'distinct in every declared register' \
    && cf "the clearance claims every declared register's ids are distinct on a run where none was read: $out"
  printf '%s\n' "$out" | grep -q 'board-drift: clean ✓' \
    || cf "an absent register should not itself be a finding: $out"

  finish "check (d): an absent register SKIPS with its reason and the clearance line says NO register was read — never a tick covering unread operands"
  teardown
}

# =============================================================================
# CASE — ARM (a): AN ARROW IS A DECLARATION, A BACKTICK IS A MENTION.
#
# The comparator used to run ONE alternation over both spellings and take the last
# match in the line, so a normal entry —
#   - <date> [Dev] → dev_complete: unblocked; see `blocked` for the prior context.
# — was read as declaring `blocked` on a card correctly sitting in dev_complete/: a
# FALSE drift finding on the workflow the manual mandates. Not introduced by the
# arrow convention, but made reachable by it, since before the arrow existed a move
# entry carried no structured token at all.
#
# Three directions, because precedence needs all three to be pinned:
#   (i)   arrow + trailing backtick mention, card matches the ARROW → no finding;
#   (ii)  arrow disagreeing with the folder → still a finding (the fix must not
#         have simply stopped judging arrows);
#   (iii) a backtick with NO arrow → still judged, as the fallback it is.
# =============================================================================
case_check_board_arrow_beats_mention() {
  cf_reset
  make_sandbox
  local out rc

  # (i) the false positive that started this: arrow agrees with the folder, and a
  #     backticked mention of another column trails it in the prose.
  seed_issue dev_complete "$SB_PREFIX-240" arrowwins chore "Arrow beats mention"
  printf -- '- 2026-01-04 [Dev] → dev_complete: unblocked; see `blocked` for the prior context.\n' \
    >> "$SB_WORK/progress/dev_complete/$SB_PREFIX-240-arrowwins.md"
  # (ii) an arrow that genuinely disagrees with the folder — must STILL be caught.
  seed_issue todo "$SB_PREFIX-241" arrowwrong chore "Arrow disagrees"
  printf -- '- 2026-01-04 [Dev] → qa_complete: handed off.\n' \
    >> "$SB_WORK/progress/todo/$SB_PREFIX-241-arrowwrong.md"
  # (iii) a backticked declaration with no arrow — the fallback must still judge it.
  seed_issue todo "$SB_PREFIX-242" tickonly chore "Backtick only"
  printf -- '- 2026-01-04 [QA] Reviewed and moved to `qa_complete`.\n' \
    >> "$SB_WORK/progress/todo/$SB_PREFIX-242-tickonly.md"
  publish_sandbox

  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep -q "$SB_PREFIX-240" \
    && cf "(i) FALSE DRIFT — a card whose arrow matches its folder was reported because a backticked column was MENTIONED later in the same bullet: $(printf '%s\n' "$out" | grep "$SB_PREFIX-240")"
  printf '%s\n' "$out" | grep -q "$SB_PREFIX-241" \
    || cf "(ii) an arrow DISAGREEING with the folder was not reported — the precedence fix must not have stopped judging arrows: $out"
  printf '%s\n' "$out" | grep "$SB_PREFIX-241" | grep -q 'qa_complete' \
    || cf "(ii) the finding does not name what the arrow declared: $(printf '%s\n' "$out" | grep "$SB_PREFIX-241")"
  printf '%s\n' "$out" | grep -q "$SB_PREFIX-242" \
    || cf "(iii) a backticked declaration with NO arrow was not judged — the fallback pass is gone: $out"

  finish "check (a): an arrow outranks a backticked mention in the same bullet (no false drift), an arrow that disagrees is still a finding, and a backtick with no arrow is still judged"
  teardown
}

case_check_board_reads_the_ref() {
  cf_reset
  make_sandbox
  seed_issue todo        "$SB_PREFIX-200" alpha chore "Published alpha"
  seed_issue in_progress "$SB_PREFIX-201" beta  chore "Published beta"
  publish_sandbox

  local out rc ref
  ref="origin/$SB_TRUNK"

  # --- (i) the divergence: a duplicate id in the WORKING TREE only ------------
  seed_issue dev_complete "$SB_PREFIX-200" unpublished-twin chore "Unpublished twin"
  [ -f "$SB_WORK/progress/dev_complete/$SB_PREFIX-200-unpublished-twin.md" ] \
    || cf "(control) the working-tree twin was not written — the divergence does not exist"
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep -q "$ref" \
    || cf "(i) the report does not name $ref anywhere — the operand is still invisible: $out"
  printf '%s\n' "$out" | grep -qi 'duplicate' \
    && cf "(i) an UNPUBLISHED duplicate was reported — the arm read the checkout, not $ref: $out"
  printf '%s\n' "$out" | grep -q 'board-drift: clean ✓' \
    || cf "(i) the trunk is clean but the report did not say so: $out"

  # --- (ii) the ablation: publish it, and it must redden ----------------------
  publish_sandbox
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc after publishing (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep -qi 'duplicate' \
    || cf "(ii) ABLATION FAILED — the duplicate is on $ref and was NOT reported, so half (i) proves nothing: $out"
  printf '%s\n' "$out" | grep -i 'duplicate' | grep -q "$SB_PREFIX-200" \
    || cf "(ii) the duplicate finding does not name $SB_PREFIX-200: $out"

  finish "check-board: the arms answer about $ref, not the checkout — an unpublished duplicate is NOT reported, the same duplicate published IS (ablation-proven), and the ref is named in the output"
  teardown
}

# =============================================================================
# CASE — ARM (e) SCOPES ITSELF TO THE RULE'S LIFETIME, AND THE BOUNDARY IS STRICT.
#
# A rule cannot be violated before it exists. Arm (e) used to scan the last N commits
# unconditionally, so a project with any pre-adoption history got findings it could
# never fix — the only cure would be rewriting published history. It fired on the FIRST
# report an adopter ever saw, because the kit REQUIRES a commit before kit-init.sh runs
# and wires the hook after it, and a report that is never clean stops being read.
#
# THE FIXTURE IS THE KIT'S OWN DAY-ONE RECIPE, which is what makes the off-by-one real
# rather than theoretical: `git add -A && MSG_OK=1 git commit -m 'init'` commits the
# whole kit copy — the hook file included — under the subject `init`. So the epoch
# commit is ITSELF unprefixed, and a boundary of "at or after" would keep reporting the
# exact line the adopter complained about. Commit 2 below is that commit, and asserting
# it is NOT reported is the whole point of the strictness.
# =============================================================================
# =============================================================================
# CASE — arm [h]: the trailer scan SHARES arm (e)'s epoch and cannot invent its own.
#
# Rules (1) and (2) live in ONE file (scripts/githooks/commit-msg), so they begin
# binding at ONE commit. Two arms deriving that commit separately is one idea carrying
# two numbers, and the divergence is SILENT: the two agree on every history that exists
# today and part company on the first re-add, shallow boundary or root epoch. The
# same-epoch assertion below is the one nothing else in this file makes.
#
# THE MARKER IS READ OUT OF THE HOOK, never typed. A hard-coded "claude" here keeps
# passing after the hook's marker list changes — the drift this plant must be immune to.
# =============================================================================
# =============================================================================
# CASE — A SHALLOW CLONE DOES NOT GET A DERIVED-LOOKING NARROWING.
#
# The history arms scope themselves to the commit that ADDED the commit-msg hook. In a
# shallow clone that commit is not the real one: a grafted root has no parents, so every
# file in it reads as ADDED there and the epoch resolves to the CLONE BOUNDARY. Measured
# on this repository at `--depth 3`, the in-scope set collapsed to two commits out of a
# twenty-commit window — and the arm printed a scope line naming that boundary and a ✓.
#
# SHALLOW IS THE DEFAULT CI CHECKOUT on most forges, which is precisely where a report is
# most likely to be consumed by a machine that will not notice.
#
# THE FIX IS TO STOP NARROWING, NOT TO SKIP: on a shallow clone the pre-adoption commits
# are absent anyway, so scanning what is present over-reports at worst. What must never
# happen is a narrowing that LOOKS derived. This asserts that.
# =============================================================================
case_check_board_shallow_clone_does_not_narrow() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-500" shallow chore "Shallow probe"
  publish_sandbox
  # A few commits so a depth-limited clone genuinely truncates something.
  local k
  for k in 1 2 3; do sbcommit -q --allow-empty -m "[PM] filler $k" >/dev/null 2>&1; done
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1

  local sh="$SB_TMP/shallow"
  git clone -q --depth 2 "file://$SB_ORIGIN" "$sh" >/dev/null 2>&1 \
    || { skp "a shallow clone does not get a derived-looking narrowing" "git could not make a shallow clone here"; teardown; return; }

  # INSTRUMENT: it must actually BE shallow, or the case is about an ordinary clone.
  [ "$(git -C "$sh" rev-parse --is-shallow-repository 2>/dev/null)" = "true" ] \
    || _fixture_die "case_check_board_shallow_clone_does_not_narrow: the clone is not shallow — every assertion below would be about a full history."
  # …and the epoch derivation must genuinely be WRONG there, or there is nothing to guard.
  local grafted
  grafted="$( { git -C "$sh" log --diff-filter=A --format=%H HEAD -- scripts/githooks/commit-msg 2>/dev/null || true; } | tail -1 )"
  [ -n "$grafted" ] \
    || _fixture_die "case_check_board_shallow_clone_does_not_narrow: the shallow clone resolves no add-commit at all, so the re-homing this case is about does not occur here."

  local out
  out="$( cd "$sh" && env -u CLAUDE_PROJECT_DIR ./scripts/check-board.sh 2>&1 )"
  printf '%s\n' "$out" | grep -q 'THIS IS A SHALLOW CLONE' \
    || cf "the report does not say the history is shallow — the arms narrowed against a graft boundary and presented it as a derived epoch: $out"
  printf '%s\n' "$out" | grep -q "scope: commits after ${grafted:0:9}" \
    && cf "the report narrowed to the GRAFT BOUNDARY and named it as the rule's start — that commit is an artefact of the clone depth, not of the kit's arrival: $out"

  finish "a shallow clone gets no derived-looking narrowing: the arms say the history is shallow, exclude nothing, and never present the graft boundary as the rule's epoch"
  teardown
}

case_check_board_trailer_scan_shares_the_epoch() {
  cf_reset
  make_sandbox

  local hook="$SB_WORK/scripts/githooks/commit-msg" marker
  [ -f "$hook" ] \
    || _fixture_die "case_check_board_trailer_scan_shares_the_epoch: the sandbox ships no commit-msg hook, so there is no epoch to derive and no marker list to read."
  marker="$(sed -n "s/^TOOL_TRAILER_MARKERS='\([^|]*\).*/\1/p" "$hook" | head -1)"
  [ -n "$marker" ] \
    || _fixture_die "case_check_board_trailer_scan_shares_the_epoch: TOOL_TRAILER_MARKERS could not be read from the hook — the plant would carry a marker the arm never looks for, and this case would report a green about nothing."

  # (1) PRE-ADOPTION: no hook file in this commit at all, and a real trailer in it.
  mv "$hook" "$SB_TMP/commit-msg.held"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "$(printf '[PM] pre-adoption work\n\nCo-Authored-By: %s <noreply@invalid>' "$marker")" >/dev/null 2>&1
  local sha_pre; sha_pre="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"

  # (2) THE EPOCH: the kit copy lands, hook file and all.
  mv "$SB_TMP/commit-msg.held" "$hook"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "$(printf '[PM] init\n\nCo-Authored-By: %s <noreply@invalid>' "$marker")" >/dev/null 2>&1
  local sha_epoch; sha_epoch="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"
  local derived
  derived="$( { git -C "$SB_WORK" log --diff-filter=A --format=%h --abbrev=9 HEAD -- scripts/githooks/commit-msg 2>/dev/null || true; } | tail -1 )"
  [ "$derived" = "$sha_epoch" ] \
    || _fixture_die "case_check_board_trailer_scan_shares_the_epoch: the hook file's add-commit derives to '$derived', not the fixture's commit 2 '$sha_epoch' — the fixture does not model what the arms read."

  # (3) AFTER the rule began, from a checkout that never wired the hook. Correctly
  #     PREFIXED, so this commit is arm [h]'s finding alone and not also arm (e)'s.
  sbcommit -q --allow-empty -m "$(printf '[PM] a landing made from an unwired checkout\n\nCo-Authored-By: %s <noreply@invalid>' "$marker")" >/dev/null 2>&1
  local sha_after; sha_after="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"

  publish_sandbox

  local out rc hits scopes e_scope h_scope
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep -q '^\[h\]' \
    || cf "no [h] section — the arm is absent, which no other assertion here can detect: $out"

  hits="$(printf '%s\n' "$out" | grep 'carries a generated trailer' || true)"

  # ABLATION FIRST — without a red, both exclusions below are satisfiable by an arm
  # that reports nothing at all.
  printf '%s\n' "$hits" | grep -q "$sha_after" \
    || cf "ABLATION FAILED — the post-epoch trailer commit $sha_after was NOT reported, so this arm cannot go red and every exclusion asserted below proves nothing: $out"
  printf '%s\n' "$hits" | grep -q "$sha_pre" \
    && cf "the PRE-ADOPTION trailer commit $sha_pre was reported — it predates the hook file entirely: $(printf '%s' "$hits" | tr '\n' '|')"
  printf '%s\n' "$hits" | grep -q "$sha_epoch" \
    && cf "the EPOCH commit $sha_epoch was itself reported — the boundary is 'at or after' when it must be STRICTLY after: $(printf '%s' "$hits" | tr '\n' '|')"

  # THE COMPOSITION, compared as TEXT out of the two arms' OWN scope lines. This case
  # deliberately does NOT recompute the epoch: a third derivation would agree with
  # neither arm and would answer a question nobody asked.
  scopes="$(printf '%s\n' "$out" | grep -o 'scope: commits after [0-9a-f]\{9\}' || true)"
  e_scope="$(printf '%s\n' "$scopes" | sed -n '1p')"
  h_scope="$(printf '%s\n' "$scopes" | sed -n '2p')"
  { [ -n "$e_scope" ] && [ -n "$h_scope" ]; } \
    || cf "fewer than two 'scope: commits after <sha>' lines — one of the two history arms does not name its narrowing where its result is printed: $out"
  [ "$e_scope" = "$h_scope" ] \
    || cf "arms [e] and [h] name DIFFERENT epochs ('$e_scope' vs '$h_scope') — one rule, one file, two boundaries: the later one is silently hiding findings"

  # INSTRUMENT AGAINST A VACUOUS PASS: if nothing was out of scope, the two exclusions
  # above are satisfied by an arm that narrowed nothing.
  printf '%s\n' "$out" | grep -qE "scope: commits after ${sha_epoch}[^—]*— [1-9][0-9]* of the last" \
    || cf "the scope line reports ZERO commits excluded — nothing was narrowed, so the exclusions above would pass vacuously: $out"

  # A HUMAN CO-AUTHOR IS NOT A FINDING. Without this the arm could be a bare
  # "co-authored-by" grep and every assertion above would still pass.
  sbcommit -q --allow-empty -m "$(printf '[PM] a pair-programmed landing\n\nCo-Authored-By: Jane Smith <jane@invalid>')" >/dev/null 2>&1
  local sha_human; sha_human="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"
  publish_sandbox
  printf '%s\n' "$(cb_run)" | grep 'carries a generated trailer' | grep -q "$sha_human" \
    && cf "a Co-Authored-By naming a HUMAN was reported as a generated trailer — the arm is matching the trailer rather than the tool markers, which the hook it mirrors explicitly permits"

  finish "check-board arm [h]: a generated trailer after the rule's epoch is reported (ablation-proven), one before it is not, the epoch commit itself is not, a HUMAN co-author is not, and [h] names the SAME epoch as [e]"
  teardown
}

# =============================================================================
# CASE — arm [i]: blocks/blocked_by symmetry, and the four states it must tell apart.
#
# The fields are HAND-MAINTAINED — they appear in the two card templates, two role docs
# and one skill, and in NO script; the board mover writes back only `pr:`. Yet
# .claude/roles/orchestrator.md § Chain-verify-first gates DISPATCH on them. So an
# asymmetric pair reads as fine on each card alone and sends work onto unlanded state,
# and no single-file check can see it.
#
# THE ARM IS ADVISORY BY RULING, so this case asserts BOTH halves of that: the findings
# are printed AND the verdict line stays clean. A deciding version would hold
# release.sh gate (d) shut on a field nothing writes and nothing clears.
#
# FOUR DIRECTIONS, and the last two are what stop the arm being noise or a lie:
#   (i)   A declares blocks:[B]; B's blocked_by omits A            → reported
#   (ii)  B declares blocked_by:[A]; A's blocks omits B            → reported (CONVERSE)
#   (iii) a symmetric pair                                          → NOT reported
#   (iv)  a board where no card declares either field               → says so, and does
#         NOT print what (iii) prints
# =============================================================================
# =============================================================================
# CASE — THE AUXILIARY WORKTREE'S DIRTY GUARD: REPORTS WIDELY, REFUSES NARROWLY.
#
# The guard used to print, as its keep-your-work option, a blanket `git add -A` in a
# worktree whose HEAD IS the trunk and whose push target IS the trunk, with nothing in
# between — and it read `status --porcelain -uno`, so it could not SEE half of what that
# recipe would commit. In one adopting project a commit made in that directory replaced
# the project README with a generated distribution page and added four release artifacts
# to main.
#
# THE `-uno` IS NOT THE BUG AND MUST NOT BE "FIXED". Its recorded reason is correct and
# measured: it scopes a DESTRUCTION guard to exactly what `reset --hard` destroys, and
# reset --hard leaves untracked files alone. The defect was the MISMATCH — a guard scoped
# to what would be destroyed, printing a remedy scoped to everything in the tree. So the
# report widens and the REFUSAL does not, and leg (ii) is what holds that line: an
# untracked file ALONE must not block a board operation, or every stray editor dropping
# becomes an outage.
# =============================================================================
case_kwt_dirty_guard_reports_widely_refuses_narrowly() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-400" alpha chore "Guard alpha"
  seed_issue todo "$SB_PREFIX-401" beta  chore "Guard beta"
  publish_sandbox

  # One real board op, to bootstrap the auxiliary worktree.
  local out rc=0
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-400" in_progress \
            --role Dev --note "bootstrap the worktree" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(setup) the bootstrapping board move failed, so nothing below is about the guard: $(printf '%s' "$out" | tr '\n' '|')"
  local kwt="$SB_WORK/.kanban-wt"
  [ -d "$kwt" ] \
    || _fixture_die "case_kwt_dirty_guard_reports_widely_refuses_narrowly: no .kanban-wt/ after a board move — the guard under test lives there and this case cannot reach it."

  # --- (i) TRACKED dirt + an untracked stray: refuses, and reports BOTH ------
  local tracked_card; tracked_card="$(git -C "$kwt" ls-files 'progress/*' | head -1)"
  [ -n "$tracked_card" ] \
    || _fixture_die "case_kwt_dirty_guard_reports_widely_refuses_narrowly: no tracked file under progress/ in the worktree to dirty."
  printf '\nstray edit\n' >> "$kwt/$tracked_card"
  printf 'a distribution payload\n' > "$kwt/STRAY-PAYLOAD.txt"
  [ -n "$(git -C "$kwt" status --porcelain --untracked-files=no)" ] \
    || _fixture_die "case_kwt_dirty_guard_reports_widely_refuses_narrowly: the tracked edit did not register as dirty — the refusal below would not fire and the case would prove nothing."

  rc=0
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-401" in_progress \
            --role Dev --note "should refuse" 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(i) a board op proceeded with TRACKED changes in the auxiliary worktree"
  # THE REMEDY IS SCOPED. Both halves: the narrow form present, the blanket form absent.
  printf '%s\n' "$out" | grep -q -- "add -- progress/" \
    || cf "(i) the printed remedy is not scoped to progress/: $(printf '%s' "$out" | tr '\n' '|')"
  # `add -A &&` — the RECIPE shape, not the bare string. The refusal now WARNS about
  # `add -A` in prose, so a bare match finds this arm's own warning text and reddens on
  # the fix. (It did, on the first run of this case.) The recipe is the thing that must
  # be gone; the warning is the thing that must be there.
  printf '%s\n' "$out" | grep -q -- "add -A &&" \
    && cf "(i) the printed remedy STILL offers a blanket 'add -A' recipe in a worktree that pushes to the trunk: $(printf '%s' "$out" | tr '\n' '|')"
  # THE UNTRACKED STRAY IS REPORTED, and labelled as not being the refusal's subject.
  printf '%s\n' "$out" | grep -q 'STRAY-PAYLOAD.txt' \
    || cf "(i) the untracked file the remedy would have committed is not reported at all — the guard still cannot see half of what it would commit: $(printf '%s' "$out" | tr '\n' '|')"
  printf '%s\n' "$out" | grep -qi 'untracked' \
    || cf "(i) the untracked paths are listed without being labelled as untracked, so a reader cannot tell them from the tracked changes that caused the refusal: $(printf '%s' "$out" | tr '\n' '|')"

  # --- (ii) UNTRACKED ONLY: must NOT refuse. This is "refuses narrowly", and it
  #     is the assertion that stops a future editor widening the trigger.
  git -C "$kwt" checkout -- "$tracked_card"
  [ -z "$(git -C "$kwt" status --porcelain --untracked-files=no)" ] \
    || _fixture_die "case_kwt_dirty_guard_reports_widely_refuses_narrowly: the tracked edit did not revert, so leg (ii) would be measuring the tracked case again."
  [ -f "$kwt/STRAY-PAYLOAD.txt" ] \
    || _fixture_die "case_kwt_dirty_guard_reports_widely_refuses_narrowly: the untracked stray is gone, so leg (ii) proves nothing about untracked files."
  rc=0
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-401" in_progress \
            --role Dev --note "untracked only — must proceed" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] \
    || cf "(ii) an UNTRACKED file alone blocked a board operation — the refusal widened past what a reset destroys, and every stray editor dropping is now an outage: $(printf '%s' "$out" | tr '\n' '|')"
  origin_has_path "progress/in_progress/$SB_PREFIX-401-beta.md" \
    || cf "(ii) the board op exited 0 but the card did not reach the trunk — it did not actually run"

  finish "kanban worktree dirty guard: TRACKED dirt refuses and the report ALSO lists the untracked paths the remedy would commit (labelled), the remedy is scoped to progress/ and no longer offers a blanket add -A, and an untracked file ALONE does not block a board operation"
  teardown
}

case_check_board_dependency_symmetry() {
  cf_reset

  # --- leg (iv) FIRST, on its own board: (i)-(iii) need declarations, and the two
  #     states must not be able to mask each other.
  make_sandbox
  seed_issue todo "$SB_PREFIX-300" lonely chore "No dependency declared anywhere"
  publish_sandbox
  local out rc
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(iv) check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep -q '^\[i\]' \
    || cf "(iv) no [i] section — the arm is absent, which no other assertion here can detect: $out"
  # THE EFFECT, not a label: it must say it READ cards and found ZERO declarations. That
  # is the only sentence separating "nothing to check" from "checked and symmetric".
  printf '%s\n' "$out" | grep -qE '[1-9][0-9]* card\(s\) read, 0 dependency declaration\(s\)' \
    || cf "(iv) the arm does not distinguish an UNDECLARED board from a symmetric one — an empty result and a clean result print the same thing: $out"
  teardown

  # --- legs (i)(ii)(iii) on one board: three pairs, three outcomes, one run.
  cf_reset
  make_sandbox
  # (iii) SYMMETRIC CONTROL — must stay quiet, or every red below is just noise.
  seed_issue todo "$SB_PREFIX-310" sym-a chore "Symmetric A"
  seed_issue todo "$SB_PREFIX-311" sym-b chore "Symmetric B"
  cb_set_dep "$SB_PREFIX-310" sym-a todo blocks     "$SB_PREFIX-311"
  cb_set_dep "$SB_PREFIX-311" sym-b todo blocked_by "$SB_PREFIX-310"
  # (i) FORWARD — 320 says it blocks 321; 321 says nothing.
  seed_issue todo "$SB_PREFIX-320" fwd-a chore "Forward A"
  seed_issue todo "$SB_PREFIX-321" fwd-b chore "Forward B"
  cb_set_dep "$SB_PREFIX-320" fwd-a todo blocks "$SB_PREFIX-321"
  # (ii) REVERSE — 331 says it is blocked by 330; 330 says nothing. This is the half a
  #      `blocks:`-only arm is STRUCTURALLY blind to, and the half a concurrent mint
  #      actually produces.
  seed_issue todo "$SB_PREFIX-330" rev-a chore "Reverse A"
  seed_issue todo "$SB_PREFIX-331" rev-b chore "Reverse B"
  cb_set_dep "$SB_PREFIX-331" rev-b todo blocked_by "$SB_PREFIX-330"
  publish_sandbox

  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc (exit 0 ALWAYS)"

  # (i) and (ii): both reported, each naming BOTH cards — a finding naming one card is
  #     not actionable, because either card may be the stray.
  printf '%s\n' "$out" | grep "$SB_PREFIX-320" | grep -q "$SB_PREFIX-321" \
    || cf "(i) the forward asymmetry $SB_PREFIX-320 blocks $SB_PREFIX-321 was not reported naming both cards: $out"
  printf '%s\n' "$out" | grep "$SB_PREFIX-331" | grep -q "$SB_PREFIX-330" \
    || cf "(ii) THE CONVERSE IS UNIMPLEMENTED — $SB_PREFIX-331 declares blocked_by:[$SB_PREFIX-330], $SB_PREFIX-330 does not answer, and the arm is silent. An arm reading only blocks: is blind to half its operand set: $out"

  # (iii) ABLATION: the symmetric pair must NOT appear. Without this, (i) and (ii) are
  #       satisfied by an arm that prints every card it read.
  printf '%s\n' "$out" | grep '⚠' | grep -q "$SB_PREFIX-310" \
    && cf "(iii) ABLATION FAILED — the SYMMETRIC pair $SB_PREFIX-310/$SB_PREFIX-311 was reported, so the arm fires on a healthy board and (i)/(ii) prove nothing: $(printf '%s\n' "$out" | grep '⚠' | tr '\n' '|')"

  # THE ADVISORY RULING, asserted as an EFFECT and not as a word: findings are on the
  # report and the verdict is still clean. This fails the day somebody wires it to drift.
  printf '%s\n' "$out" | grep -q 'board-drift: clean ✓' \
    || cf "an ADVISORY arm changed the verdict — release.sh gate (d) refuses on this line, so a hand-maintained field with no producer would now block a release cut: $out"
  # …and the machine contract that makes kit-init drop it, on the arm's own header line.
  printf '%s\n' "$out" | grep '^\[i\]' | grep -q 'reports only' \
    || cf "the advisory arm omits the literal 'reports only' token, so kit-init.sh's self-check reads its findings as decisions and fails fresh installs: $(printf '%s\n' "$out" | grep '^\[i\]')"

  # INSTRUMENT AGAINST A VACUOUS PASS. Everything above is satisfiable by an arm that
  # never parsed a field, if the fixture's writes silently missed.
  printf '%s\n' "$out" | grep -qE '[1-9][0-9]* card\(s\) read, [1-9][0-9]* dependency declaration\(s\)' \
    || cf "the arm reports ZERO declarations on a board carrying four — either the fixture's writes did not take or the parser does not read this YAML shape, and every assertion above is vacuous: $out"

  finish "check-board arm [i]: forward AND converse asymmetries are reported naming both cards, a symmetric pair is not (ablation-proven), an undeclared board says so rather than clearing, and the arm is advisory — the verdict stays clean and the header carries 'reports only'"
  teardown
}

case_check_board_arm_e_scopes_to_the_rules_lifetime() {
  cf_reset
  make_sandbox

  local hook="$SB_WORK/scripts/githooks/commit-msg"
  [ -f "$hook" ] \
    || _fixture_die "case_check_board_arm_e_scopes_to_the_rules_lifetime: the sandbox ships no scripts/githooks/commit-msg, so there is no epoch to derive and the case would prove nothing."

  # (1) PRE-ADOPTION — the hook file does not exist in this commit at all.
  mv "$hook" "$SB_TMP/commit-msg.held"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "pre-adoption work, made under no attribution rule" >/dev/null 2>&1
  local sha_pre; sha_pre="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"

  # (2) THE EPOCH — the kit copy lands, hook file and all, under the day-one subject.
  mv "$SB_TMP/commit-msg.held" "$hook"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "init" >/dev/null 2>&1
  local sha_epoch; sha_epoch="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"
  # INSTRUMENT: the epoch must really be commit 2, or "strictly after" is being asserted
  # against the wrong commit and every verdict below is about something else.
  local derived
  derived="$( { git -C "$SB_WORK" log --diff-filter=A --format=%h --abbrev=9 HEAD -- scripts/githooks/commit-msg 2>/dev/null || true; } | tail -1 )"
  [ "$derived" = "$sha_epoch" ] \
    || _fixture_die "case_check_board_arm_e_scopes_to_the_rules_lifetime: the hook file's add-commit derives to '$derived', not the fixture's commit 2 '$sha_epoch' — the fixture does not model what the arm reads."

  # (3) AFTER the rule began, still unprefixed — a REAL finding that must survive.
  sbcommit -q --allow-empty -m "an unprefixed commit made after the hook file arrived" >/dev/null 2>&1
  local sha_after; sha_after="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"

  publish_sandbox

  local out rc hits
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc (exit 0 ALWAYS)"

  # Read the FINDINGS, not the whole report: the scope line legitimately prints the
  # epoch's sha, so a bare absence grep would fail on the arm's own correct output.
  hits="$(printf '%s\n' "$out" | grep 'lacks a \[Role\] prefix' || true)"
  # FLATTENED for the messages below: cf renders ONE line, and $hits is a list — an
  # unflattened list reports its first entry and silently hides the one that fired.
  local hits1; hits1="$(printf '%s' "$hits" | tr '\n' '|')"

  printf '%s\n' "$hits" | grep -q "$sha_pre" \
    && cf "the PRE-ADOPTION commit $sha_pre was reported as drift — it predates the hook file entirely: $hits1"
  printf '%s\n' "$hits" | grep -q "$sha_epoch" \
    && cf "the EPOCH commit $sha_epoch was itself reported — the boundary is 'at or after' when it must be STRICTLY after, and this is the exact day-one line an adopter sees: $hits1"
  # INSTRUMENT / ABLATION: without this the three assertions above are all satisfiable by
  # an arm that reports nothing whatsoever.
  printf '%s\n' "$hits" | grep -q "$sha_after" \
    || cf "ABLATION FAILED — the post-epoch unprefixed commit $sha_after was NOT reported, so the arm cannot go red and every exclusion asserted above proves nothing: $out"

  # The narrowing is NAMED, and named with a non-zero count — an arm that silently
  # narrows its operand set is the defect this kit spent a crunch removing.
  printf '%s\n' "$out" | grep -q "scope: commits after $sha_epoch, which ADDED scripts/githooks/commit-msg" \
    || cf "the scope line does not name the epoch it derived: $out"
  printf '%s\n' "$out" | grep -qE "scope: commits after $sha_epoch, which ADDED scripts/githooks/commit-msg — [1-9][0-9]* of the last" \
    || cf "the scope line reports ZERO commits excluded — nothing was narrowed, so this case would pass vacuously: $out"
  # The accepted residual is stated where the result is printed, not only in a change file.
  printf '%s\n' "$out" | grep -q "the epoch is the hook FILE's arrival" \
    || cf "the accepted residual (hook file present, core.hooksPath never set) is not stated in the arm's output: $out"

  teardown

  # --- SECOND TOPOLOGY: THE EPOCH IS THE ROOT COMMIT. ------------------------
  # This is what `README.md`'s day-one line actually produces — `git init`, then
  # `git add -A && MSG_OK=1 git commit -m 'init'` — so the hook file arrives in a
  # commit with NO PARENT. It is a distinct topology and not a nicer spelling of the
  # first: a boundary expressed as `$EPOCH^..` resolves to `fatal: ambiguous argument`
  # here, and with stderr discarded that reads as an EMPTY in-scope set, which the
  # membership test then treats as "everything is out of scope". The arm goes wholly
  # blind while printing a scope line and a green. The half above cannot catch that,
  # because it always builds the epoch as commit 2.
  cf_reset
  make_sandbox
  local rhook="$SB_WORK/scripts/githooks/commit-msg"
  [ -f "$rhook" ] \
    || _fixture_die "case_check_board_arm_e_scopes_to_the_rules_lifetime: the sandbox ships no commit-msg hook for the root-epoch half."
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "init" >/dev/null 2>&1
  local sha_root; sha_root="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"
  # INSTRUMENT: it must really be a ROOT commit, or this half is the first one again.
  [ -z "$(git -C "$SB_WORK" rev-parse --verify --quiet 'HEAD^' || true)" ] \
    || _fixture_die "case_check_board_arm_e_scopes_to_the_rules_lifetime: the epoch commit has a parent — this half is not exercising the root topology it is named for."
  sbcommit -q --allow-empty -m "an unprefixed commit after the root epoch" >/dev/null 2>&1
  local sha_rafter; sha_rafter="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"
  publish_sandbox

  local rout rhits rhits1
  rout="$(cb_run)"
  rhits="$(printf '%s\n' "$rout" | grep 'lacks a \[Role\] prefix' || true)"
  rhits1="$(printf '%s' "$rhits" | tr '\n' '|')"
  printf '%s\n' "$rhits" | grep -q "$sha_rafter" \
    || cf "(root) ABLATION FAILED — with the epoch at the ROOT commit the arm reported NOTHING, so it went blind rather than scoping: $rout"
  printf '%s\n' "$rhits" | grep -q "$sha_root" \
    && cf "(root) the ROOT epoch commit was itself reported — strictly-after does not hold when the epoch has no parent: $rhits1"
  printf '%s\n' "$rout" | grep -q "scope: commits after $sha_root" \
    || cf "(root) the scope line does not name the root epoch: $rout"

  finish "check-board arm (e): pre-adoption commits and the epoch commit ITSELF are excluded, a post-epoch unprefixed commit is still reported (ablation-proven), the narrowing is named with its count — and the same holds when the epoch is the ROOT commit, which is what the day-one recipe produces"
  teardown
}

# =============================================================================
# CASE — NO LOCATION IS THE ONLY CORRECT ONE.
#
# The trap in the obvious workaround, and the reason "run it from a trunk checkout"
# was never a fix. Arm (f)'s subject is the publication path, which is registered
# against the MAIN worktree — so a report run from a linked worktree used to print
# "no registered worktree (skipped)" about a worktree that existed three directories
# away. Fixing the stale arms by relocating the caller traded five stale arms for one
# blind one, and there was no location from which the whole report was correct.
#
# This asserts the report is correct FROM A LINKED WORKTREE: the trunk-property arm
# still names the ref, and the local arm still finds the publication path.
# =============================================================================
case_check_board_from_a_worktree() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-210" wt chore "Worktree control"
  publish_sandbox

  # A real board op, to bootstrap .kanban-wt the way an operator would. If the mover
  # cannot run here the control has no subject, so this is a SKIP, not a pass.
  if ! ( cd "$SB_WORK" && ./scripts/move-issue.sh "$SB_PREFIX-210" in_progress \
           --role "$SB_ROLE" --note "bootstrap the publication path" >/dev/null 2>&1 ); then
    skp "check-board from a linked worktree" "the board mover would not run in this sandbox, so .kanban-wt was never created"
    teardown; return
  fi
  [ -d "$SB_WORK/.kanban-wt" ] \
    || { skp "check-board from a linked worktree" ".kanban-wt was not created by the move"; teardown; return; }

  local wt="$SB_TMP/linked" out rc
  if ! git -C "$SB_WORK" worktree add --detach "$wt" "origin/$SB_TRUNK" >/dev/null 2>&1; then
    skp "check-board from a linked worktree" "git worktree add failed in this sandbox"
    teardown; return
  fi
  [ -x "$wt/scripts/check-board.sh" ] \
    || { cf "(control) the linked worktree has no scripts/check-board.sh — it cannot be run from there"; finish "check-board from a linked worktree"; teardown; return; }

  # Run the worktree's OWN copy, so REPO_ROOT resolves to the worktree — which is
  # exactly the situation the trap lived in.
  out="$( cd "$wt" && env -u CLAUDE_PROJECT_DIR "$wt/scripts/check-board.sh" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc from a linked worktree (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep -q "origin/$SB_TRUNK" \
    || cf "the trunk-property arms do not name origin/$SB_TRUNK when run from a worktree: $out"
  printf '%s\n' "$out" | grep -q '\[f\].*no registered worktree' \
    && cf "arm [f] reported NO REGISTERED WORKTREE from a linked worktree — the publication path was not located against the main checkout, so the trap survives: $out"
  printf '%s\n' "$out" | grep -q '^\[f\]' \
    || cf "arm [f] printed no line at all from a linked worktree — a missing line is itself a finding: $out"

  finish "check-board is correct from a LINKED WORKTREE too: the trunk arms name origin/$SB_TRUNK and arm [f] still locates .kanban-wt against the main checkout"
  teardown
}

# =============================================================================
# CASE — arm [g], graduation: its three states, and the verdict control
#
# make_sandbox seeds no root documents, so each of the three cases below seeds
# CLAUDE.md / README.md / PROJECT.md itself. AND THE NEUTRALIZER DELIBERATELY
# DELETES THE STAMP RECEIPT from scripts/config.sh, so a case that wants the arm to
# run must put it back — that is not a workaround, it is the arm's enabling
# condition, and the receipt is written from KIT_STAMP_MARK rather than retyped.
# =============================================================================
case_check_board_graduation() {
  cf_reset
  make_sandbox

  # ── (a) NO SIGNAL AT ALL: the check did not run, and says so. ───────────────
  # THE FIXTURE IS BUILT EMPTY ON PURPOSE, and that is the case rather than a detail:
  # make_sandbox publishes a board, so a tree with NO sign of having started has to be
  # constructed deliberately. The old premise here was "no receipt", which is not the
  # same thing — a board carrying issue files is a signal too, and this arm reads four
  # of them. A fixture that only removes the receipt tests a tree that HAS started.
  #
  # WHY THIS STATE IS ASSERTED HERE **AND** IN A CASE OF ITS OWN, since they look like
  # duplication and are not: this block is the START of a continuous sequence — the same
  # sandbox gains a receipt in (b) and the arm must then REPORT — so what (a) proves is
  # the TRANSITION out of not-run. The standalone case proves the state itself, on a
  # fixture guarded against all four lived signals. They fail for different reasons: (a)
  # fails if the arm does not change state when a signal appears, the standalone fails if
  # the state is wrong at all. Collapsing either would lose one of those.
  #
  # AND THE DISTINCTION IS THE POINT: "did not run" is not "nothing to graduate from".
  # The second reads as a clean bill. A reader must be able to tell an unrun check from
  # a passing one, so the absence of the COMPLETE claim is asserted beside the presence
  # of the not-run statement — a check that says nothing satisfies only one of those.
  rm -f "$SB_WORK"/progress/*/*-[0-9]*.md 2>/dev/null
  printf '# progress.md\n\n## Log\n\n' > "$SB_WORK/progress.md"
  printf '# ARCHIVE.md\n\n## Archived\n\n' > "$SB_WORK/ARCHIVE.md"
  seed_scaffolding_tree
  publish_sandbox

  local out
  out="$(cb_run)"
  printf '%s\n' "$out" | grep -q '^\[g\]' \
    || cf "(a) no [g] section — the arm is absent, which no other assertion here can detect"
  printf '%s\n' "$out" | _cb_g_section | grep -q 'THIS CHECK DID NOT RUN' \
    || cf "(a) with no signal at all the arm did not say it had not run: $out"
  # AND NOT BECAUSE THE SHARED PROBE WOULD NOT LOAD. arm [g]'s load-failure branch
  # prints the SAME "THIS CHECK DID NOT RUN" string, so the assertion above became
  # satisfiable by a broken scripts/lib/lived-probe.sh the day that branch was added —
  # the case would go green while measuring a library error instead of the tree's signals.
  printf '%s\n' "$out" | _cb_g_section | grep -q 'could not be loaded' \
    && cf "the arm skipped because the shared already-lived probe would not load, not because this tree has no signal: $out"
  printf '%s\n' "$out" | _cb_g_section | grep -q 'graduation COMPLETE' \
    && cf "(a) the arm claimed graduation on a tree with no sign of having started: $out"


  # ── (b) RECEIPT + SCAFFOLDING: it reports, and names the files. ──────────────
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  publish_sandbox

  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep -q 'CLAUDE.md' \
    || cf "(b) the REPLACE finding did not NAME CLAUDE.md — instruments.md § A.4 wants the operand: $out"
  printf '%s\n' "$out" | _cb_g_section | grep -q 'README.md' \
    || cf "(b) the REPLACE finding did not name README.md: $out"
  printf '%s\n' "$out" | _cb_g_section | grep -qi 'PROJECT.md still holds' \
    || cf "(b) the FILL finding did not fire on a PROJECT.md holding <trunk>: $out"
  # NAME THE CLASS, not the phrase. This read `grep -qi 'not measured'` as authored, and
  # a reddening control measured that it CANNOT SEE THE OMISSION IT IS NAMED AFTER:
  # delete arm (g3)'s echo entirely and the case still passes, because the FILL span line
  # one line above says "The non-markdown FILL members are NOT measured here" and -i makes
  # that a match. The assertion was satisfied by a different class's disclaimer.
  printf '%s\n' "$out" | _cb_g_section | grep -q 'DELETE-IF-UNUSED: not measured' \
    || cf "(b) DELETE-IF-UNUSED was silently omitted instead of declaring itself unmeasured: $out"

  # ── (c) THE VERDICT CONTROL — the whole reason the arm is separable. ─────────
  # Graduation is reporting findings RIGHT NOW. The verdict must still read clean,
  # because the board is clean. If this ever fails, the release ritual's board gate
  # and kit-init's own self-check both start failing on every fresh install.
  printf '%s\n' "$out" | grep -q 'board-drift: clean ✓' \
    || cf "(c) graduation findings changed the board verdict — release.sh gate (d) keys on this line, and a dirty verdict is what sends kit-init's self-check looking for a cause: $out"

  # ── (d) GRADUATED: it clears, and it NAMES ITS SOURCE while clearing. ────────
  printf '# my project\n'                 > "$SB_WORK/CLAUDE.md"
  printf '# my project\n'                 > "$SB_WORK/README.md"
  printf '# PROJECT.md\n\nTrunk: main\n'  > "$SB_WORK/PROJECT.md"
  publish_sandbox

  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep -q 'graduation COMPLETE' \
    || cf "(d) a graduated tree did not clear: $out"
  printf '%s\n' "$out" | _cb_g_section | grep -q 'read from:' \
    || cf "(d) the CLEARING branch did not name its operand — instruments.md § A.4, the asymmetry that only errs toward false confidence: $out"
  printf '%s\n' "$out" | _cb_g_section | grep -qi 'still scaffolding' \
    && cf "(d) a graduated tree still reported scaffolding: $out"

  finish "check (g): graduation says THIS CHECK DID NOT RUN with no signal, reports and names its files while scaffolding stands, clears once replaced naming its source — and never moves the board verdict"
  teardown
}

# =============================================================================
# CASE — arm [g]'s ENABLING DIRECTION: a lived signal with NO receipt
#
# THE FIXTURE THE OLD GATE EXCLUDED. Arm [g] reads FOUR signals, and the receipt is only
# the first: a board carrying issue files, history in progress.md § Log, and entries in
# ARCHIVE.md each enable it too. Every existing case here builds the receipt, so the arm
# had only ever been watched running for one of its four reasons — and a reader of those
# greens would reasonably conclude the receipt is what the arm requires.
#
# This is the direction's positive half: signal present, receipt ABSENT, arm REPORTS.
# =============================================================================
case_check_board_graduation_enabled_without_receipt() {
  cf_reset
  make_sandbox
  # No receipt: the neutralizer already stripped it, and nothing here puts it back.
  seed_scaffolding_tree
  seed_issue todo "$SB_PREFIX-410" lived chore "A card on the board is a lived signal"
  publish_sandbox

  # ASSERT THE PREMISE: no receipt. If one were present the case would pass for the
  # reason every other case already covers, and prove nothing about the other three.
  local _sig; _sig="$(_lived_signals)"
  printf '%s' "$_sig" | grep -q 'stamp receipt' \
    && _fixture_die "case_check_board_graduation_enabled_without_receipt: the sandbox carries a stamp receipt, so this case would be enabled by the signal every other case already builds and would prove nothing about the other three."
  printf '%s' "$_sig" | grep -q 'issue file' \
    || _fixture_die "case_check_board_graduation_enabled_without_receipt: no issue file is on the board, so the signal this case exists to exercise is absent and a green would mean nothing."

  local out; out="$(cb_run)"
  # ANCHOR THE SECTION, AND KNOW EXACTLY WHAT THE ANCHOR IS WORTH — it is less than it
  # looks. The negative assertion below ("must NOT say X") is satisfied by an EMPTY
  # section, so on its own it can pass while checking nothing.
  #
  # WHAT ACTUALLY PROTECTS THE NEGATIVE IS THE SIBLING POSITIVE, NOT THIS LINE. Measured
  # against the extractor with three synthetic reports:
  #
  #   section          anchor   negative        positive
  #   full             PASS     PASS            PASS
  #   header-only      PASS     PASS (vacuous)  FAIL   <- only the positive catches this
  #   absent ([G])     FAIL     PASS (vacuous)  FAIL
  #
  # The positive fails in BOTH failure modes, so today this anchor catches nothing the
  # positive does not already catch: its contribution is the DIAGNOSTIC — it names an
  # absent arm instead of leaving a reader to infer it from a content assertion. It earns
  # its keep only if the positive is ever deleted, and even then it does not cover a
  # TRUNCATED section, which satisfies it.
  #
  # So do not read this line as the protection and delete the positive believing the case
  # is still guarded. `grep -q` on empty input returns 1, which is why a positive cannot
  # pass vacuously and a negative can — that asymmetry, not this anchor, is the guard.
  printf '%s\n' "$out" | grep -q '^\[g\]' \
    || cf "no [g] section — the arm is absent, which no other assertion here can detect"
  printf '%s\n' "$out" | _cb_g_section | grep -q 'THIS CHECK DID NOT RUN' \
    && cf "(enabled) a board carrying an issue file did not enable the arm — it reads four signals and this is one of them: $out"
  printf '%s\n' "$out" | _cb_g_section | grep -qi 'still scaffolding' \
    || cf "(enabled) the arm ran but reported no finding on an unreplaced scaffolding tree: $out"
  # NAME THE SIGNAL. An enabling condition is an operand, and a reader who wants to know
  # why the check ran on their tree should not have to reason it out.
  printf '%s\n' "$out" | _cb_g_section | grep -q 'enabled by:' \
    || cf "(enabled) the arm did not name the signal that enabled it: $out"

  finish "check (g): a lived signal OTHER than the receipt — a card on the board — enables the arm, and it names which signal did"
  teardown
}

# =============================================================================
# CASE — arm [g]'s NOT-RUN DIRECTION, as its own named control
#
# It duplicates (a) of the four-state case deliberately, for the reason the verdict
# control is duplicated: a state buried inside a multi-state case is the one that gets
# refactored away, and this is the state whose wording carries the whole distinction
# between "did not run" and "nothing to graduate from".
#
# BOTH HALVES ARE ASSERTED, because a check that says NOTHING satisfies the first alone.
# =============================================================================
case_check_board_graduation_not_run_direction() {
  cf_reset
  make_sandbox
  # DELIBERATELY EMPTY: no receipt, no issue files, no § Log history, nothing archived.
  rm -f "$SB_WORK"/progress/*/*-[0-9]*.md 2>/dev/null
  printf '# progress.md\n\n## Log\n\n' > "$SB_WORK/progress.md"
  printf '# ARCHIVE.md\n\n## Archived\n\n' > "$SB_WORK/ARCHIVE.md"
  publish_sandbox

  # ASSERT THE PREMISE, all four signals absent — otherwise this case tests the other
  # direction while reporting on this one.
  local _sig; _sig="$(_lived_signals)"
  [ -z "$_sig" ] \
    || _fixture_die "case_check_board_graduation_not_run_direction: the fixture carries lived signal(s) — $(printf '%s' "$_sig" | tr '\n' ';') — so the arm WILL run and this case is the enabling direction wearing the not-run name."

  local out; out="$(cb_run)"
  # ANCHOR THE SECTION, AND KNOW EXACTLY WHAT THE ANCHOR IS WORTH — it is less than it
  # looks. The negative assertion below ("must NOT say X") is satisfied by an EMPTY
  # section, so on its own it can pass while checking nothing.
  #
  # WHAT ACTUALLY PROTECTS THE NEGATIVE IS THE SIBLING POSITIVE, NOT THIS LINE. Measured
  # against the extractor with three synthetic reports:
  #
  #   section          anchor   negative        positive
  #   full             PASS     PASS            PASS
  #   header-only      PASS     PASS (vacuous)  FAIL   <- only the positive catches this
  #   absent ([G])     FAIL     PASS (vacuous)  FAIL
  #
  # The positive fails in BOTH failure modes, so today this anchor catches nothing the
  # positive does not already catch: its contribution is the DIAGNOSTIC — it names an
  # absent arm instead of leaving a reader to infer it from a content assertion. It earns
  # its keep only if the positive is ever deleted, and even then it does not cover a
  # TRUNCATED section, which satisfies it.
  #
  # So do not read this line as the protection and delete the positive believing the case
  # is still guarded. `grep -q` on empty input returns 1, which is why a positive cannot
  # pass vacuously and a negative can — that asymmetry, not this anchor, is the guard.
  printf '%s\n' "$out" | grep -q '^\[g\]' \
    || cf "no [g] section — the arm is absent, which no other assertion here can detect"
  printf '%s\n' "$out" | _cb_g_section | grep -q 'THIS CHECK DID NOT RUN' \
    || cf "(not-run) the arm did not state that it had not run, so a reader cannot tell an unrun check from a clean one: $out"
  # AND NOT BECAUSE THE SHARED PROBE WOULD NOT LOAD. arm [g]'s load-failure branch
  # prints the SAME "THIS CHECK DID NOT RUN" string, so the assertion above became
  # satisfiable by a broken scripts/lib/lived-probe.sh the day that branch was added —
  # the case would go green while measuring a library error instead of the tree's signals.
  printf '%s\n' "$out" | _cb_g_section | grep -q 'could not be loaded' \
    && cf "the arm skipped because the shared already-lived probe would not load, not because this tree has no signal: $out"
  printf '%s\n' "$out" | _cb_g_section | grep -q 'graduation COMPLETE' \
    && cf "(not-run) the arm claimed graduation on a tree with no sign of having started: $out"

  finish "check (g): with NO signal at all the arm says THIS CHECK DID NOT RUN and never claims completion — an unrun check is not a clean one"
  teardown
}

# =============================================================================
# CASE — arm [g] reads the TRUNK, and this is the case that matters
# =============================================================================
case_check_board_graduation_reads_the_trunk() {
  cf_reset
  make_sandbox

  # Scaffolding published; receipt present. The arm reports.
  seed_scaffolding_tree
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  publish_sandbox

  local out
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep -qi 'still scaffolding' \
    || cf "precondition failed: the arm did not report on published scaffolding: $out"

  # ── GRADUATE IN THE WORKING TREE ONLY. DO NOT PUBLISH. ──────────────────────
  # This is the read-the-checkout-not-the-ref defect posed as a question: a working-tree read would
  # declare graduation here and then, because a satisfied arm stops asking, never
  # re-open it. The arm is one-way, so a premature clear is UNRECOVERABLE rather
  # than merely stale — which is why this control is worth more than case 1.
  printf '# my project\n'                > "$SB_WORK/CLAUDE.md"
  printf '# my project\n'                > "$SB_WORK/README.md"
  printf '# PROJECT.md\n\nTrunk: main\n' > "$SB_WORK/PROJECT.md"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "[Architect] graduate, unpublished" >/dev/null 2>&1
  # deliberately NO push

  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep -qi 'still scaffolding' \
    || cf "THE ARM READ THE WORKING TREE: it cleared on an unpublished graduation, and a one-way arm that clears early never re-opens: $out"
  printf '%s\n' "$out" | _cb_g_section | grep -q "$SB_TRUNK" \
    || cf "the arm did not name the trunk ref it answered about: $out"

  # And it clears once the work is actually published — the other direction.
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep -q 'graduation COMPLETE' \
    || cf "the arm did not clear once the graduation was published: $out"

  finish "check (g) is a TRUNK read: an unpublished graduation does NOT clear it (a one-way arm that clears early never re-opens), and publishing does"
  teardown
}

# =============================================================================
# CASE — the verdict wiring, as a standalone control
#
# This duplicates case 1(c) on purpose, as a NAMED control that survives someone
# refactoring case 1: a control buried inside a four-state case is the one that
# gets deleted during a tidy-up. Both are kept, which is the authored default.
#
# WHAT EACH CONSUMER ACTUALLY READS — do not collapse these two, they differ:
#   release.sh gate (d)        keys on the VERDICT LINE alone, and always has.
#   kit-init's self-check      keys on the verdict line, and when it is NOT clean
#                              reports the remaining findings as context — after
#                              dropping any section whose own header says it
#                              "reports only", which is how arm [g] declares itself.
#
# THIS NOTE REPLACES A FALSE ONE, and the falsehood is kept because it is the whole
# lesson. It used to read "release.sh gate (d) and kit-init's self-check both key on
# this line". They did not. kit-init re-scanned the rendered ⚠ lines whenever the
# verdict was dirty, so when arm [g] began printing ADVISORY ⚠ lines — present on
# every day-one tree by construction — any unrelated arm that flipped the verdict
# left [g]'s advisories as "whatever was left", and a correct install failed, blaming
# the one arm whose header says it never decides anything. The trigger was this kit's
# own documented recipe: GIT-HOSTING § 3 step 2's unprefixed `init` subject flips arm
# (e). Fixed on the kit-init side; the false sentence is superseded here rather than
# deleted, because a case whose rationale names the wrong consumer is how the
# regression shipped underneath a green control.
#
# SO: ASSERTING THE VERDICT STRING IS NECESSARY AND NOT SUFFICIENT — and the
# sufficiency half CANNOT live in this case. It would have to run kit-init, and this
# sandbox carries a stamp receipt (that receipt is what makes arm [g] report at all),
# which is one of kit-init's four ALREADY-LIVED signals: it would refuse before
# reaching any self-check. Measured, not assumed. The consumer is exercised where it
# can actually run, on the path that broke —
# case_kit_init_survives_the_documented_first_commit below.
# =============================================================================
case_check_board_graduation_verdict_is_not_wired() {
  cf_reset
  make_sandbox
  # --no-project ON PURPOSE: this case needs g1's REPLACE finding to fire and needs the
  # FILL arm to have nothing to read. That was previously expressed by an absent printf,
  # which reads as an oversight; it is an argument now so the next reader sees the choice.
  seed_scaffolding_tree --no-project
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  publish_sandbox

  local out; out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep -qi 'still scaffolding' \
    || cf "precondition: the arm must be REPORTING for this control to mean anything: $out"
  printf '%s\n' "$out" | grep -q 'board-drift: clean ✓' \
    || cf "day-one completeness moved the board verdict — release.sh gate (d) keys on this line, and a dirty verdict is also what sends kit-init's self-check looking for a cause: $out"

  finish "check (g) does not decide the verdict: a board with unreplaced scaffolding still reads 'board-drift: clean ✓'"
  teardown
}

# =============================================================================
# CASE — the day-one path THE KIT'S OWN DOCUMENTATION PRINTS
#
# WHY NO EXISTING CASE COULD REACH THE BROKEN PATH, which is the reason this one
# exists rather than a wider assertion somewhere else: every sandbox commit goes
# through sbcommit and every subject the harness writes carries a role prefix —
# "[PM] seed sandbox board", "[Dev] <id>: add a real change", "[Architect] graduate,
# unpublished". Arm (e) therefore never fires in a sandbox, the verdict is always
# clean, and kit-init always takes its first branch. The suite could not have caught
# the regression and cannot catch a recurrence without a case that commits THE WAY
# THE DOCUMENTATION SAYS TO.
#
# GIT-HOSTING § 3 step 2 prints `git commit --allow-empty -m '<init>'` and says that
# wiring the hooks after the first commit "avoids the question entirely" — so the
# documented day-one sequence is an unprefixed subject with hooks unwired, and that
# is the state this case reproduces. publish_sandbox is deliberately NOT used: its
# "[PM] seed sandbox board" subject is exactly what masked this everywhere else, and
# using the helper here would delete the case's premise while leaving it green.
# =============================================================================
case_kit_init_survives_the_documented_first_commit() {
  cf_reset
  if ! has_kit_init; then
    skp "kit-init: the documented day-one first commit" "scripts/kit-init.sh absent"; return
  fi
  if ! has_issue_template; then skp "kit-init: the documented day-one first commit" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox

  # SEED THE ROOT DOCUMENTS, because make_sandbox does not and a real day-one tree does.
  # THIS IS THE HALF THAT MAKES THE CASE ABLE TO FAIL, and it was measured: without it
  # the case passes even against the pre-fix initializer. The regression needed BOTH a
  # dirty verdict AND arm [g] reporting, and [g] only reports when it finds these files —
  # `[ -f ] || continue` for the REPLACE pair, "no PROJECT.md to read (skipped)" for FILL.
  # A sandbox with no root documents therefore produces no advisory lines, leaves the
  # pre-fix filter nothing to trip over, and turns this case into a green about nothing.
  # An unzipped kit HAS all three; the sandbox is the synthetic tree, so it is the one
  # that has to be brought up to the day-one state.
  seed_scaffolding_tree

  # The documented first commit, verbatim in shape: unprefixed subject, hooks unwired.
  # The `remote add` is publish_sandbox's job and this case does not call it, so the
  # remote is added here — kit-init's preflight refuses outright without an origin,
  # which is a refusal about the fixture rather than about the subject under test.
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m 'init' >/dev/null 2>&1
  git -C "$SB_WORK" remote add origin "$SB_ORIGIN" >/dev/null 2>&1
  git -C "$SB_WORK" push -q -u origin "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" remote set-head origin "$SB_TRUNK" >/dev/null 2>&1
  # ASSERT THE FIXTURE REACHED THE STATE THE CASE IS ABOUT, or a preflight refusal
  # about a missing remote reads exactly like the regression this case exists for.
  git -C "$SB_WORK" remote get-url origin >/dev/null 2>&1 \
    || _fixture_die "case_kit_init_survives_the_documented_first_commit: no origin remote in the sandbox — kit-init would refuse at preflight and the case would blame the commit subject."
  # The other half of the premise — arm [g] must actually be reporting — CANNOT be
  # asserted here, and the reason is the arm's own enabling condition: [g] reports only
  # once scripts/config.sh carries the stamp receipt, and the receipt is written BY the
  # run this case is about. Before it, [g] correctly skips. So the premise is checked
  # after the run, below, where it is true or the case has no subject.
  # ASSERT THE PREMISE. If the subject were prefixed after all, arm (e) never fires,
  # the verdict stays clean and this case passes while exercising nothing.
  git -C "$SB_WORK" log -1 --format='%s' | grep -qE '^\[' \
    && _fixture_die "case_kit_init_survives_the_documented_first_commit: the first commit's subject IS role-prefixed, so arm (e) cannot fire and this case has no premise."

  local out rc
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?

  # (a) THE REGRESSION: an unprefixed first commit must not fail the install.
  [ "$rc" -eq 0 ] \
    || cf "kit-init FAILED (rc=$rc) on the first-commit subject GIT-HOSTING § 3 step 2 prints: $out"
  printf '%s\n' "$out" | grep -q 'kit-init COMPLETE and PROVEN' \
    || cf "no COMPLETE-and-PROVEN line on the documented day-one path: $out"

  # (b) AND THE BOARD CHECK MUST NOT BE THE THING THAT FAILED — "passes" vs "passes
  #     for the right reason". NOT keyed on the text of [g]'s advisories: a healthy
  #     run PRINTS those, under an explicit "for context — not the basis of the result
  #     above" heading, so matching them would fire on correct output. That is the
  #     same mistake as reading `grep -qi 'not measured'` for the DELETE-IF-UNUSED
  #     class, measured once already in this file. Key on the FAILURE marker instead.
  printf '%s\n' "$out" | grep -q '✗ check-board.sh reported drift' \
    && cf "kit-init's self-check failed its board arm on a correct day-one tree: $out"
  printf '%s\n' "$out" | grep -q '✓ check-board.sh' \
    || cf "the self-check's board arm did not report a result at all — it was skipped or renamed: $out"

  # (c) THE PREMISE, CHECKED WHERE IT CAN BE TRUE. The regression needed the board report
  #     to carry arm [g]'s advisories at self-check time; [g] only reports once the stamp
  #     receipt exists, and this run is what wrote it. Asserting it against check-board
  #     directly — not against kit-init's rendering of it — keeps this independent of how
  #     the initializer chooses to echo context. Without this, a sandbox that produced no
  #     advisories would pass (a) and (b) while exercising nothing, which is measured: it
  #     is exactly what this case did before the root documents above were seeded.
  CB_OUT="$(cb_run)"   # capture, then test — cb_run grows with the board
  printf '%s\n' "$CB_OUT" | _cb_g_section | grep -qi 'still scaffolding' \
    || cf "arm [g] reports no advisory on the post-init tree, so the failure mode this case exists for was never reachable and its green means nothing"

  finish "kit-init: the first-commit subject GIT-HOSTING § 3 step 2 prints does not fail the install, the board arm is not what fails, and arm [g] WAS reporting while it ran"
  teardown
}

# =============================================================================
# CASE — a REAL board finding must still fail the self-check, naming itself
#
# WITHOUT THIS, "tolerate more" is indistinguishable from "check nothing". The
# filter that let the day-one regression through was widened to fix it; this is the
# control that widening never had, and it is the reason the pair is worth more than
# either case alone.
#
# THE PLANT IS NOT AN ORDINARY CARD, AND THE REASON IS ITSELF A FINDING. kit-init's
# ALREADY-LIVED probe `find`s progress/*/*-[0-9]*.md in the WORKING TREE, so seeding
# two ordinary cards makes kit-init refuse before its self-check ever runs — the case
# would then pass its non-zero assertion for entirely the wrong reason and fail the
# one that names the cause. Measured 2026-08-28. So the duplicate is planted under
# filenames the lived-probe glob does not match, which leaves the id collision real,
# on the trunk, and reachable by the self-check.
#
# AND THE FINDING IS DELIBERATELY ONE PRINTED BELOW ITS SECTION HEADER — a choice that
# has since been vindicated, and the superseded reason is kept because it is the lesson.
# THIS PARAGRAPH USED TO READ, in the present tense: "kit-init's filter skips the header
# line of every section while deciding whether the section is advisory, so a finding
# rendered ON its header is currently invisible to it." That was true when written and is
# no longer: the `; next` that discarded every header was removed, and only headers that
# DECLARE themselves advisory are dropped now. The claim was a statement about another
# file's current behaviour, made in the present tense, in a file that ships — the shape
# that goes stale without anything noticing. What survives is the choice, and its reason
# is now the durable one: a below-header finding is what the arm's own contract promises
# to report, so this control rests on the contract rather than on a rendering detail.
# =============================================================================
case_kit_init_still_fails_on_a_real_finding() {
  cf_reset
  if ! has_kit_init; then
    skp "kit-init: a real board finding still fails the self-check" "scripts/kit-init.sh absent"; return
  fi
  if ! has_issue_template; then skp "kit-init: a real board finding still fails the self-check" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox

  local dup="$SB_PREFIX-100" f
  for f in "progress/todo/dupe-one.md" "progress/done/dupe-two.md"; do
    printf -- '---\nid: %s\ntype: chore\nstatus: %s\ntitle: "duplicate plant"\npr: null\n---\n\n## Activity\n' \
      "$dup" "$(basename "$(dirname "$f")")" > "$SB_WORK/$f"
  done
  # BOTH HALVES OF THE PREMISE, asserted: the collision is real, and the plant does
  # NOT look like a lived board — a plant that trips the already-lived refusal tests
  # the refusal, not the self-check.
  [ "$(find "$SB_WORK/progress" -type f -name '*-[0-9]*.md' 2>/dev/null | wc -l | tr -d ' ')" -eq 0 ] \
    || _fixture_die "case_kit_init_still_fails_on_a_real_finding: the planted files match kit-init's ALREADY-LIVED glob, so it would refuse before the self-check and this case would pass for the wrong reason."
  publish_sandbox

  local out rc
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  printf '%s\n' "$out" | grep -q 'already lived' \
    && _fixture_die "case_kit_init_still_fails_on_a_real_finding: kit-init took the ALREADY-LIVED refusal, so nothing here exercised the self-check."
  [ "$rc" -ne 0 ] \
    || cf "kit-init PASSED with a duplicate id on the board — the self-check tolerates a real finding: $out"
  printf '%s\n' "$out" | grep -qi 'duplicate' \
    || cf "kit-init failed but did not NAME the finding that caused it: $out"

  finish "kit-init: a real board finding still fails the self-check, and the failure names that finding"
  teardown
}

case_check_board_frontmatter_offset() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-150" commented chore "Comment above the frontmatter"
  # Prepend a template-style comment header ABOVE the frontmatter.
  local f="$SB_WORK/progress/todo/$SB_PREFIX-150-commented.md" tmp
  tmp="$(mktemp)"
  { printf '<!-- KIT-CLASS: KIT — a comment header, exactly as the templates carry one.\n     It spans several lines and ends here. -->\n'; cat "$f"; } > "$tmp"
  mv "$tmp" "$f"
  publish_sandbox

  # THE ID KEY IS DERIVED, NOT RE-TYPED, AND THE ARM BELOW IT IS WHY THAT MATTERS HERE MORE THAN
  # USUAL. check-board.sh printf's this message with ISSUE_ID_KEY substituted, so a re-typed
  # "no id:" matches only while that key is spelled `id`. The assertion using it is NEGATIVE —
  # a non-match is the PASSING branch — so retuning the key would not redden this case, it would
  # make it measure nothing and still report PASS. An EMPTY derivation does exactly the same, and
  # that is the failure the arm catches: without it, `grep -q "no : line"` matches nothing and the
  # case passes vacuously.
  local id_key; id_key="$(cb_default ISSUE_ID_KEY)"
  [ -n "$id_key" ] \
    || cf "(control) could not derive ISSUE_ID_KEY from check-board.sh — the negative assertion below would then match nothing and report PASS while measuring nothing"

  local out rc
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep -q "no $id_key: line" \
    && cf "a card whose frontmatter sits below a comment header was reported as having no $id_key: $out"
  printf '%s\n' "$out" | grep -q 'board-drift: clean ✓' \
    || cf "a healthy card with a comment header did not read clean: $out"

  # NO SCAN-CAP CONTROL HERE, AND ITS ABSENCE IS NOW HONEST. This case used to derive
  # FRONTMATTER_SCAN_LINES, assert it non-empty, and never use it — with a comment beside it
  # describing a control ("a `---` far down a long body must NOT be mistaken for a fence") that was
  # never built, and a finish message claiming "a stated scan cap". A derivation nothing reads is
  # not a control; the prose around it was the only thing making it look like one, and the prose is
  # what a reviewer reads. Building the real control means seeding a long body with a `---` past the
  # cap and asserting the card still parses — real new coverage rather than hygiene, so it is filed
  # as its own item rather than smuggled in here.

  finish "check (d): a frontmatter below a comment header is parsed, not reported as missing (id key derived, not re-typed)"
  teardown
}

# =============================================================================
# CASE — kit-init.sh end to end, against a NON-shipped prefix.
# The script's own self-check is its primary proof; this keeps it from ROTTING.
# =============================================================================
# THE ISSUE-TEMPLATE CAPABILITY PROBE — ONE AUTHORING SITE. Every case that needs a minted card
# carried its own copy of this path, in TWO spellings of the skip reason. (This said "eight cases"
# and was true when written; derive it —
#   awk '/^[A-Za-z_][A-Za-z0-9_]*\(\)/{fn=$1} /if ! has_issue_template/{print fn}' "$0" | sort -u | wc -l
# — rather than trusting a number here.) The path, the
# spelling policy below and the reason string are one decision, and a decision stated per case
# is eight places to amend and seven to forget.
#
# `.claude/` ONLY, DELIBERATELY, AND DO NOT WIDEN THIS TO THE DUAL SPELLING. The cases that call
# `kit_init_sandbox` exercise a BUILT kit — it copies `.claude/templates` and nothing else — so the
# maintainer repository's disarmed `_claude/` tree is not their operand and finding it would make
# them run against a tree they are not testing.
# (This said "these EIGHT cases"; derive the set with `grep -c kit_init_sandbox "$0"` rather than
# trusting a number here — it was true when written and the population has since grown.)
#
# The sites elsewhere in this file that read
# whichever spelling exists are reading the SHIPPED tree in place, which is a different question;
# the header says why that is a convenience and not a supported mode.
ISSUE_TEMPLATE_REL='.claude/templates/ISSUE.template.md'
ISSUE_TEMPLATE_ABSENT="$ISSUE_TEMPLATE_REL absent (copy-list incomplete)"
has_issue_template() { [ -f "$REAL_REPO_ROOT/$ISSUE_TEMPLATE_REL" ]; }

# THE ROLE-FILE PATH, DERIVED FROM THE HOOKS THAT DECLARE IT. Both hooks keep `ROLE_REL` as a named
# variable on its own line, and both say in a comment that they do it "so a test fixture can DERIVE it
# (sed) instead of re-hardcoding a literal" — a promise `process/MANUAL.md` repeats. Nothing derived it:
# the one assertion about the path hardcoded the string, so all three statements were false.
#
# IT READS BOTH HOOKS AND REQUIRES THEM TO AGREE, which is what session-start.sh's own comment asks
# for: "a guard that derives the path from one hook and finds a literal in the other cannot check the
# pair." Deriving from one alone would leave the pair unchecked and still look like a derivation.
_role_rel() {   # -> the agreed ROLE_REL, or empty if the hooks disagree or either cannot be read
  local a b
  a="$(sed -n 's/^ROLE_REL="\(.*\)"$/\1/p' "$REAL_SCRIPTS/hooks/require-role.sh" 2>/dev/null)"
  b="$(sed -n 's/^ROLE_REL="\(.*\)"$/\1/p' "$REAL_SCRIPTS/hooks/session-start.sh" 2>/dev/null)"
  [ -n "$a" ] && [ "$a" = "$b" ] && printf '%s' "$a"
}

has_kit_init() { [ -f "$REAL_SCRIPTS/kit-init.sh" ]; }

kit_init_sandbox() {
  make_sandbox
  mkdir -p "$SB_WORK/.claude"
  if [ -d "$REAL_REPO_ROOT/.claude/templates" ]; then
    cp -R "$REAL_REPO_ROOT/.claude/templates" "$SB_WORK/.claude/templates"
  fi
  # The role docs are IN the substitution pass, so the census has to have
  # something to count. Copying them is what makes the census assertion real
  # rather than vacuous.
  if [ -d "$REAL_REPO_ROOT/.claude/roles" ]; then
    cp -R "$REAL_REPO_ROOT/.claude/roles" "$SB_WORK/.claude/roles"
  fi
  # ...and take the adopter's stamp back out of what `cp` just carried in, exactly
  # as make_sandbox does for scripts/. AFTER both copies and never between them:
  # the neutralizer walks the whole .claude/ tree, so a call placed between the two
  # would leave the role docs stamped while reporting that it had run.
  _kit_neutral_claude
}

case_kit_init_happy() {
  cf_reset
  if ! has_kit_init; then skp "kit-init: end-to-end init + self-check" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "kit-init: end-to-end init + self-check" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  publish_sandbox

  local out rc
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || cf "kit-init exited $rc: $out"
  printf '%s\n' "$out" | grep -q 'kit-init COMPLETE and PROVEN' || cf "no COMPLETE-and-PROVEN line: $out"
  printf '%s\n' "$out" | grep -q '✗' && cf "a self-check assertion failed: $out"
  # The prefix reached the TEMPLATE BODY — the check a silent substitution no-op fails.
  printf '%s\n' "$out" | grep -q "id: SBX-000" \
    || cf "the self-check did not report the stamped frontmatter id: $out"
  grep -q 'ISSUE_PREFIX:-SBX' "$SB_WORK/scripts/config.sh" || cf "scripts/config.sh was not stamped"
  grep -q 'SBX-' "$SB_WORK/.claude/templates/ISSUE.template.md" || cf "the ISSUE template body was not stamped"
  grep -q '<PREFIX>' "$SB_WORK/.claude/templates/ISSUE.template.md" \
    && cf "the angle-bracket prefix placeholder SURVIVED in the template"
  # The CENSUS is asserted, not promised.
  printf '%s\n' "$out" | grep -q "census — prefix placeholders" \
    || cf "the census did not report on prefix placeholders: $out"
  printf '%s\n' "$out" | grep -qE "census — prefix placeholders[^:]*: 0 in" \
    || cf "the census did not report ZERO surviving prefix placeholders: $out"
  # A hat declaration is session state.
  printf '%s\n' "$out" | grep -q 'hat declaration is invisible to git status' \
    || cf "the self-check did not prove the session-role ignore entry: $out"
  # DERIVED, not re-typed — and the derivation is asserted, because an empty result would make the
  # grep below look for an empty string, match every line, and pass while checking nothing.
  local role_rel; role_rel="$(_role_rel)"
  [ -n "$role_rel" ] \
    || cf "(control) could not derive an AGREED ROLE_REL from the two hooks — either one of them no longer declares it on its own line, or they now name different paths; the .gitignore assertion below would otherwise search for an empty string and pass"
  [ -z "$role_rel" ] || grep -qxF "$role_rel" "$SB_WORK/.gitignore" \
    || cf "$role_rel (derived from the hooks) was not written into the new repo's .gitignore"
  # The board is COMPLETE and left PRISTINE.
  local keeps leftovers
  keeps="$(find "$SB_WORK/progress" -name .gitkeep | wc -l | tr -d ' ')"
  [ "$keeps" = "7" ] || cf "expected 7 .gitkeep files, found $keeps"
  leftovers="$(find "$SB_WORK/progress" -type f -name '*.md' | wc -l | tr -d ' ')"
  [ "$leftovers" = "0" ] || cf "the board is not pristine — $leftovers issue file(s) left behind"
  grep -qE '^##[[:space:]]+Log' "$SB_WORK/progress.md" || cf "progress.md has no '## Log' heading"
  origin_has_path "progress/todo/.gitkeep" || cf "the board was not pushed to the trunk"
  # A second run must refuse rather than half-stamp.
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] || cf "the second run did NOT refuse"
  printf '%s\n' "$out" | grep -q 'already lived' || cf "the second-run refusal did not name what is stamped: $out"

  finish "kit-init: end-to-end init + self-check, census green, board pristine, re-run refuses"
  teardown
}

# WHY THIS CASE EXISTS, and why it asserts a PRE-STATE before it asserts anything else.
# `core.hooksPath` points git at a directory; git then runs what it finds there ONLY if the
# file is executable. When the bit is off git prints a *hint* to stderr and the commit
# SUCCEEDS — so a repository can be perfectly wired and completely unguarded, and the old
# self-check read that success as "core.hooksPath is not in effect", which is the wrong cause
# and sends an adopter to re-run wiring that already worked.
#
# A clone is where the bit goes missing: git records one execute bit per path, so a tree that
# was committed with the bit off hands every future clone an inert hook. kit-init runs BEFORE
# the trunk's first commit, which is the only moment a repair can reach every future clone —
# that is why the chmod lives there and not only in setup.sh.
#
# The pre-state assertion is the instrument check. Without it a chmod that silently did nothing
# — or a source tree that already ships the bit on — would let this case pass while proving
# nothing at all, which is this harness's own green-that-cannot-go-red trap.
case_kit_init_repairs_hook_mode() {
  cf_reset
  if ! has_kit_init; then skp "kit-init: repairs a non-executable commit-msg hook" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "kit-init: repairs a non-executable commit-msg hook" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox

  local hook="$SB_WORK/scripts/githooks/commit-msg"
  if [ ! -f "$hook" ]; then
    cf "no commit-msg hook shipped at scripts/githooks/"
    finish "kit-init: repairs a non-executable commit-msg hook"; teardown; return
  fi
  # THE DAMAGE GOES IN BEFORE THE COMMIT, and that ordering is the whole fidelity of this case.
  # Clearing the bit AFTER publish_sandbox makes the worktree dirty, and kit-init's preflight
  # refuses a dirty tree — so the case would fail for a reason that has nothing to do with the
  # hook. The real defect is a bit that is off IN THE COMMIT, which leaves the worktree clean
  # and hands the inert hook to every future clone. That is what is modelled here.
  chmod 0644 "$hook"
  publish_sandbox

  # INSTRUMENT CHECK: assert the recorded mode, not the filesystem bit — git tracks exactly one
  # execute bit per path, and it is the INDEX's copy that travels. If this reads 100755 the
  # damage never landed and every assertion below would pass while proving nothing.
  local pre
  pre="$(git -C "$SB_WORK" ls-files -s scripts/githooks/commit-msg 2>/dev/null | awk '{print $1}')"
  [ "$pre" = "100644" ] || cf "the sandbox did not record a non-executable hook (mode $pre) — this case would pass vacuously"

  local out rc flat
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  # cf renders one line, and kit-init speaks in paragraphs: flatten, or the diagnosis is lost.
  flat="$(printf '%s' "$out" | tr '\n' ' ')"
  [ "$rc" -eq 0 ] || cf "kit-init exited $rc against a non-executable hook: $flat"
  [ -x "$hook" ] || cf "kit-init did NOT restore the hook's execute bit in the worktree"

  # THE ASSERTION THAT CARRIES THE CHANGE. kit-init runs before the trunk's first commit, so a
  # repair it makes reaches the trunk and therefore every future clone. setup.sh cannot have this
  # property — it runs after the clone exists. Reading the mode back off the REMOTE's trunk is
  # what distinguishes "kit-init fixed my checkout" from "kit-init fixed the repository".
  local shipped
  shipped="$(git -C "$SB_ORIGIN" ls-tree "$SB_TRUNK" scripts/githooks/commit-msg 2>/dev/null | awk '{print $1}')"
  [ "$shipped" = "100755" ] \
    || cf "the repaired bit did not reach the trunk (origin records mode ${shipped:-<absent>}) — a fresh clone would still get an inert hook"

  # The bit is only worth anything if the guard is then LIVE, so assert the effect too.
  printf '%s\n' "$out" | grep -q 'commit-msg hook REJECTED a prefix-less subject' \
    || cf "the hook was not proven live after the repair: $flat"
  # And the wrong diagnosis must not be what an adopter hears.
  printf '%s\n' "$out" | grep -q 'core.hooksPath is not in effect' \
    && cf "kit-init blamed core.hooksPath for a mode problem: $flat"

  finish "kit-init: repairs a non-executable commit-msg hook, the repair reaches the trunk, and hooksPath is not blamed"
  teardown
}

# =============================================================================
# CASE — kit-init --roles LEAVES NO SEAM BEHIND.
#
# THE STAMPING LOOP WAS ENTIRELY UNTESTED. Measured before this case was written:
# `--roles` appeared in this file four times, every one of them inside a comment.
#
# What that cost: the loop's seam list was hand-typed, and subtask.sh sat outside it
# while its --role whitelist enforced the shipped set — so a project that renamed its
# roles got a subtask tool that rejected every role it had just declared. The list is
# now derived, and this case is what makes the derivation's completeness assertable
# instead of argued.
#
# THE CONSEQUENCE PROBE IS THE POINT. "Every file carries the new string" is a text
# match, and a text match cannot tell a stamped whitelist from a stamped comment.
# subtask.sh validates --role BEFORE kwt_resolve, so a nonexistent card cannot
# short-circuit it, which makes the whitelist reachable without building a real card.
# =============================================================================
case_kit_init_roles_leave_no_seam() {
  cf_reset
  if ! has_kit_init; then skp "kit-init --roles: no seam keeps the old set" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "kit-init --roles: no seam keeps the old set" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  publish_sandbox

  local old="$KIT_NEUTRAL_ROLE_PREFIXES" new='Alpha|Beta|Gamma' before f out rc=0

  # THE OPERAND, ASSERTED BEFORE THE ACT — which files carry the set is the question
  # this case is about, so it is measured rather than assumed. Empty means the probe
  # lost its subject and every assertion below would pass over nothing.
  before="$( cd "$SB_WORK" && { grep -lF -- "$old" scripts/*.sh scripts/githooks/* 2>/dev/null || true; } | sort )"
  [ -n "$before" ] \
    || cf "(operand) no shipped script carries the role set before kit-init ran — the probe lost its subject"
  printf '%s\n' "$before" | grep -qx 'scripts/subtask.sh' \
    || cf "(operand) scripts/subtask.sh does not carry the role set in this sandbox — the seam this case is named for is absent, so a green below proves nothing"

  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" --roles "$new" 2>&1)" || rc=$?
  [ "$rc" -eq 0 ] || cf "kit-init --roles exited $rc: $(printf '%s' "$out" | tr '\n' '|')"

  # THE EFFECT, PER SEAM: everything that carried the old set carries the new one, and
  # nothing keeps the old. Both directions — "carries the new" alone is satisfied by a
  # file that carries both.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -qF -- "$new" "$SB_WORK/$f" \
      || cf "$f carried the role set before kit-init --roles and does not carry the new one after it — this seam was left out of the stamping list"
    grep -qF -- "$old" "$SB_WORK/$f" \
      && cf "$f still carries the SHIPPED set after kit-init --roles — the substitution did not reach it"
  done <<SEAM_EOF
$before
SEAM_EOF

  # THE RECEIPT NAMES WHAT IT STAMPED, rather than a sentence somebody typed once.
  printf '%s\n' "$out" | grep -q 'scripts/subtask.sh' \
    || cf "the run's role-set receipt does not name scripts/subtask.sh among the seams it stamped: $(printf '%s' "$out" | tr '\n' '|')"

  # THE CONSEQUENCE THE LOOP'S OWN COMMENT RECORDS, as behaviour and not as text. The
  # names are BUILT, never written: this file is scanned for `--role <Name>` literals by
  # case_role_literals_are_declared, and a typed one would redden that case on this
  # case's control text. (Measured, on an earlier control's first draft.)
  local mine outsider accepted refused
  mine="$(printf '%s' "$new" | cut -d'|' -f1)"
  outsider="$(printf '%s' "$old" | cut -d'|' -f1)"
  accepted="$( cd "$SB_WORK" && ./scripts/subtask.sh move SBX-001-s1 in_progress --role "$mine" --note n 2>&1 || true )"
  printf '%s' "$accepted" | grep -q -- '--role must be' \
    && cf "subtask.sh refused '$mine', a member of the set kit-init just declared — its whitelist was not stamped"
  # INSTRUMENT: the probe above is a NEGATIVE and is satisfied by any unreachable code
  # path. The same probe must FIRE on a role the project no longer declares.
  refused="$( cd "$SB_WORK" && ./scripts/subtask.sh move SBX-001-s1 in_progress --role "$outsider" --note n 2>&1 || true )"
  printf '%s' "$refused" | grep -q -- '--role must be' \
    || cf "(control) subtask.sh did NOT refuse '$outsider', which the project's declared set no longer contains — the probe above cannot tell an accepted role from a whitelist it never reached"

  finish "kit-init --roles: every seam that carried the role set carries the new one and none keeps the old, the receipt names them, and subtask.sh's whitelist follows (accepts a declared role, refuses a withdrawn one)"
  teardown
}

# =============================================================================
# CASE — THE ALREADY-LIVED PROBE HAS ONE AUTHORING SITE, ASSERTED AS AN EFFECT.
#
# "check-board.sh sources lib/lived-probe.sh" is a LABEL, and it is satisfied by a
# script that sources the file and then goes on using its own inline copy. Nothing
# below asserts it. What cannot be faked: add a fifth signal to the LIBRARY and BOTH
# consumers must see it — the initializer must refuse and NAME it, and arm [g] must RUN
# and name it as its enabling condition. A consumer still carrying an inline copy sees
# nothing and fails here, naming itself.
#
# THE THIRD COPY IS THE INSTRUMENT, NOT AN OPERAND. `_lived_signals` is this harness's
# own independent implementation and is deliberately NOT collapsed into the library — a
# fixture that asked the subject under test what to check would agree with it by
# construction. It is used here only to establish the PRE-STATE.
# =============================================================================
case_lived_probe_has_one_authoring_site() {
  cf_reset
  if ! has_kit_init; then skp "lived probe: one authoring site, both consumers" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "lived probe: one authoring site, both consumers" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox

  local lib="$SB_WORK/scripts/lib/lived-probe.sh"
  [ -f "$lib" ] \
    || _fixture_die "case_lived_probe_has_one_authoring_site: the sandbox has no scripts/lib/lived-probe.sh — there is no shared library to mutate, so nothing here can distinguish one authoring site from two."

  # A token that occurs NOWHERE in the shipped scripts, so a match below cannot come from
  # anything but the plant. NO trailing -<digits>: build-kit.sh's citation gate reads that
  # as one of the kit repository's change ids and refuses the zip, and this file ships.
  local tok='LIVEDPROBE-FIFTH-SIGNAL-SENTINEL'
  # SWEPT OVER THE SANDBOX'S SCRIPTS, AND NOT OVER $REAL_SCRIPTS — which was the first
  # spelling and it died instantly, correctly: $REAL_SCRIPTS contains THIS FILE, and this
  # file contains the token on the line above. A uniqueness probe whose corpus includes
  # its own source always finds itself. Excluding test/ keeps the corpus to the scripts
  # the two consumers actually load.
  [ -z "$( { find "$SB_WORK/scripts" -type f ! -path '*/test/*' -exec grep -lF "$tok" {} + 2>/dev/null || true; } )" ] \
    || _fixture_die "case_lived_probe_has_one_authoring_site: '$tok' already occurs in a sandbox script — every assertion below would be satisfiable without the plant."

  # PRE-STATE, BOTH DIRECTIONS. Without these the case passes on a signal the sandbox
  # already carried and proves nothing about the library.
  publish_sandbox
  local sig pre
  sig="$(_lived_signals)"
  [ -z "$sig" ] \
    || _fixture_die "case_lived_probe_has_one_authoring_site: the sandbox already carries lived signal(s) — $(printf '%s' "$sig" | tr '\n' ';') — so kit-init would refuse and arm [g] would run whatever the plant did."
  pre="$(cb_run)"
  printf '%s\n' "$pre" | _cb_g_section | grep -q 'THIS CHECK DID NOT RUN' \
    || _fixture_die "case_lived_probe_has_one_authoring_site: arm [g] ALREADY runs on the unplanted sandbox, so the 'it ran' assertion below would pass without the fifth signal."

  # THE PLANT — one probe, in the LIBRARY only, emitting a record shape both consumers
  # already render. Every step self-asserts: a perl -i whose anchor misses exits 0 and
  # leaves the file byte-identical, which would make this case green about nothing.
  _plant_in_function "$lib" kit_lived_signals "  printf 'folder|$tok|1\n'" \
    "case_lived_probe_has_one_authoring_site"
  bash -n "$lib" \
    || _fixture_die "case_lived_probe_has_one_authoring_site: the mutated lived-probe.sh no longer parses — both consumers would fail to LOAD it, and this case would be measuring a load failure while reporting on a shared probe."
  # PUBLISH AFTER THE MUTATION, and this is not tidiness: kit-init refuses on uncommitted
  # changes to TRACKED files, so an unpublished plant replaces the refusal this case reads
  # with a completely different one.
  publish_sandbox

  local out rc=0 before after out2
  before="$(git -C "$SB_WORK" rev-parse HEAD)"
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix ZZZ --trunk "$SB_TRUNK" 2>&1)" || rc=$?
  [ "$rc" -ne 0 ] \
    || cf "(initializer) kit-init did not refuse on a signal the shared probe emits — it is not deriving already-lived from the library: $(printf '%s' "$out" | tr '\n' '|')"
  printf '%s\n' "$out" | grep -q 'already lived' \
    || cf "(initializer) kit-init refused without naming the already-lived class: $(printf '%s' "$out" | tr '\n' '|')"
  printf '%s\n' "$out" | grep -qF "$tok" \
    || cf "(initializer) the refusal did not name the library's fifth signal — kit-init still carries its own inline copy of the probe: $(printf '%s' "$out" | tr '\n' '|')"
  after="$(git -C "$SB_WORK" rev-parse HEAD)"
  [ "$before" = "$after" ] || cf "HEAD moved during a refusal"

  out2="$(cb_run)"
  printf '%s\n' "$out2" | grep -q '^\[g\]' \
    || cf "no [g] section — the arm is absent, which no other assertion here can detect"
  printf '%s\n' "$out2" | _cb_g_section | grep -q 'THIS CHECK DID NOT RUN' \
    && cf "(arm) arm [g] did not run on a signal the shared probe emits — it still re-derives the set itself: $out2"
  printf '%s\n' "$out2" | _cb_g_section | grep -qF "$tok" \
    || cf "(arm) arm [g] ran but did not name the library's fifth signal as its enabling condition — the two consumers are not reading one probe: $out2"

  finish "lived probe: a fifth signal added to scripts/lib/lived-probe.sh reaches BOTH consumers — kit-init refuses naming it, arm [g] is enabled by it (one authoring site, asserted as an effect)"
  teardown
}

case_kit_init_refuses_lived_board() {
  cf_reset
  if ! has_kit_init; then skp "kit-init: refuses a repo that has already lived" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "kit-init: refuses a repo that has already lived" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  seed_issue todo SBX-500 lived chore "A card already on the board"
  publish_sandbox

  local before out rc after
  before="$(git -C "$SB_WORK" rev-parse HEAD)"
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix ZZZ --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] || cf "kit-init ran against a board carrying an issue file (it must refuse)"
  printf '%s\n' "$out" | grep -q 'already lived' || cf "the refusal did not name the class: $out"
  printf '%s\n' "$out" | grep -q 'NOTHING WAS WRITTEN' || cf "the refusal did not state that nothing was written"
  # THE REFUSAL MUST BE FOR THE RIGHT REASON. kit-init has four ALREADY-LIVED
  # signals (a board carrying issue files, a progress.md § Log with entries, an
  # ARCHIVE.md with entries, and its own stamp receipt in config.sh) and `grep -q
  # 'already lived'` is satisfied by ANY of them. This case plants exactly one — the
  # issue file — so it must assert THAT bullet and the ABSENCE of the stamp bullet.
  # Before the sandbox was neutralized, a configured adopter's copied-in config.sh
  # carried kit-init's stamp, so this case passed on the WRONG signal in their tree
  # and nothing said so. Neutralizing removes the stamp; without these two lines it
  # would only convert a measured wrong-reason pass into an unmeasured one.
  printf '%s\n' "$out" | grep -q 'progress/todo/ carries 1 issue file' \
    || cf "the refusal did not name the planted issue file as the lived signal — it may have refused for a different reason: $out"
  printf '%s\n' "$out" | grep -q "$KIT_STAMP_MARK" \
    && cf "the refusal cited kit-init's own stamp receipt as a lived signal — the sandbox was not neutralized, so this case is measuring the wrong signal: $out"
  after="$(git -C "$SB_WORK" rev-parse HEAD)"
  [ "$before" = "$after" ] || cf "HEAD moved during a refusal"
  [ -z "$(git -C "$SB_WORK" status --porcelain)" ] || cf "the tree was modified during a refusal"
  grep -q 'ISSUE_PREFIX:-ZZZ' "$SB_WORK/scripts/config.sh" && cf "config.sh was stamped during a refusal"

  finish "kit-init: refuses a repo that has already lived, and writes nothing"
  teardown
}

# =============================================================================
# CASE — kit-init.sh --gate-command against the SHIPPED FRAME.
# The incident (measured 2026-08-26, from the seed's own zip): the seed ships
# verify.sh as a frame with an EMPTY table that refuses to run; --gate-command
# refused because verify.sh existed; the frame's header told the reader to run the
# flag that refused; the README's day-one command was that flag. Three documents,
# no working path. The flag now FILLS the empty table; this case keeps that true.
# =============================================================================
case_kit_init_gate_fill() {
  cf_reset
  if ! has_kit_init; then skp "kit-init --gate-command: fills the shipped frame's empty table" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "kit-init --gate-command: fills the shipped frame's empty table" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  # Ship-state: empty the GATES table again — make_sandbox neutralized it and then
  # _declare_sandbox_gate put the sandbox's own gate back, and THIS case is about
  # kit-init filling an EMPTY frame. Through the shared, self-asserting helper: this
  # step used to be a local `perl -i -ne` that silently did nothing if `^GATES=($`
  # ever moved, which would have left the record make_sandbox declared in place and
  # turned the "fills the empty table" assertion into a test of the refusal path.
  _neu_array "$SB_WORK/scripts/verify.sh" GATES
  publish_sandbox

  local v="$SB_WORK/scripts/verify.sh" out rc
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" --gate-command '/bin/echo kit-init-gate-green' 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || cf "kit-init exited $rc with --gate-command against the empty frame: $out"
  printf '%s\n' "$out" | grep -q 'kit-init COMPLETE and PROVEN' || cf "no COMPLETE-and-PROVEN line: $out"
  printf '%s\n' "$out" | grep -q 'GATES table was empty — filled' || cf "kit-init did not report filling the table: $out"
  grep -qF '"gate|core|/bin/echo kit-init-gate-green"' "$v" || cf "the record did not land in verify.sh"
  grep -q '^GATES=($' "$v" || cf "the frame's GATES=( line is gone — the fill rewrote more than one line"
  [ -x "$v" ] || cf "verify.sh lost its executable bit"
  # The filled runner RUNS, and is green — the first landing has a gate to pass.
  out="$( cd "$SB_WORK" && "$v" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "the filled verify.sh exited $rc: $out"
  printf '%s' "$out" | grep -q 'kit-init-gate-green' || cf "the filled verify.sh did not run the declared command: $out"
  printf '%s' "$out" | grep -q 'PASS  gate' || cf "the summary does not name the filled gate: $out"
  out="$( cd "$SB_WORK" && "$v" --list 2>&1 )"; rc=$?
  printf '%s' "$out" | grep -q '1 declared gate' || cf "--list does not report one declared gate: $out"
  # ...and the filled file reached the trunk with the initialization commit.
  origin_file_contains "scripts/verify.sh" 'gate|core|/bin/echo kit-init-gate-green' \
    || cf "the filled verify.sh was not pushed to the trunk"

  finish "kit-init --gate-command: fills the shipped frame's empty GATES table, the runner runs green, --list counts it, and it reaches the trunk"
  teardown
}

case_kit_init_gate_and_remote_refusals() {
  cf_reset
  if ! has_kit_init; then skp "kit-init: refuses a declared table, a '|' in the gate command, and a relative remote URL" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "kit-init: refuses a declared table, a pipe in the gate command, and a relative remote" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox            # make_sandbox already DECLARED one gate in verify.sh
  publish_sandbox
  local before out rc
  before="$(git -C "$SB_WORK" rev-parse HEAD)"
  refused_clean() {  # <label> <rc> <out> <needle>
    [ "$2" -ne 0 ] || cf "$1: did not refuse"
    printf '%s\n' "$3" | grep -q 'NOTHING WAS WRITTEN' || cf "$1: the refusal did not state that nothing was written"
    printf '%s\n' "$3" | grep -q "$4" || cf "$1: the refusal did not name the cause ($4): $3"
    [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$before" ] || cf "$1: HEAD moved during a refusal"
    [ -z "$(git -C "$SB_WORK" status --porcelain)" ] || cf "$1: the tree was modified during a refusal"
  }
  # (a) a DECLARED table is never overwritten or appended to.
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" --gate-command '/bin/echo x' 2>&1)"; rc=$?
  refused_clean "(a) declared table" "$rc" "$out" 'already DECLARES a gate'
  grep -qF '/bin/echo x' "$SB_WORK/scripts/verify.sh" && cf "(a) the record was appended to a declared table"
  # (b) a '|' cannot be carried by the record format.
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" --gate-command 'a | b' 2>&1)"; rc=$?
  refused_clean "(b) '|' in the command" "$rc" "$out" "contains '|'"
  # (c) a RELATIVE remote URL resolves differently from .kanban-wt/ — refuse at preflight.
  git -C "$SB_WORK" remote set-url origin "../$(basename "$SB_ORIGIN")" >/dev/null 2>&1
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  refused_clean "(c) relative remote URL" "$rc" "$out" 'RELATIVE path'
  printf '%s\n' "$out" | grep -q 'remote set-url' || cf "(c) the refusal did not print the set-url fix: $out"

  finish "kit-init: refuses --gate-command against a declared table (never appends), a '|' in the command, and a relative remote URL — writing nothing each time"
  teardown
}

# =============================================================================
# CASE — OPTION-PARSING HYGIENE across the argument-taking scripts.
# The incident: a creation script consumed `--help` as the item's slug, minted an
# item under a nonsense name, burned a real id, and printed "Created:" — an
# acceptance WITH a success message, which is why "it looked right" is exactly the
# evidence that failed. Three behaviours × six scripts, each with its exit code
# asserted:
#   • a leading '-' is NEVER a name           → refuse, rc=2
#   • -h/--help                                → usage, rc=0
#   • an unknown option                        → refuse, rc=2
# =============================================================================
case_option_parsing_hygiene() {
  cf_reset
  if ! has_issue_template; then skp "option parsing across the creation and board scripts" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  # THE CAPABILITY PROBE GUARDS THE CASE, NOT JUST THE COPY. It used to guard only
  # the `cp` below, so when .claude/templates was absent the case ran anyway
  # against a sandbox with no templates — and every creation script then exited 1
  # at its own "template not found" check, which sits BEFORE its argument loop. The
  # case reported `an unknown option refuses → rc=1 (want 2)` on scripts whose
  # unknown-option path is a correct `exit 2`. A FALSE RED, and a durable one: it
  # names the subject and the wrong verdict, so it reads exactly like a real defect
  # in three scripts at once. Measured 2026-08-26.
  #
  # A SKIP is a statement about the environment; a FAIL is a statement about the
  # subject. This case could not tell them apart, which is the same lesson the kit
  # carries for its own gate runner (a runner reports on its subject and on itself
  # in different vocabularies). Its three siblings — kit-init happy, gate-fill and
  # first-mile — already probe this exact capability and skip loudly; this one is
  # brought into line with them.
  if [ ! -d "$REAL_REPO_ROOT/.claude/templates" ]; then
    skp "option parsing across the creation and board scripts" ".claude/templates absent — the creation scripts would exit 1 at their template check, before the argument loop this case is about"
    return
  fi
  make_sandbox
  mkdir -p "$SB_WORK/.claude/templates" "$SB_WORK/requirements"
  cp -R "$REAL_REPO_ROOT/.claude/templates/." "$SB_WORK/.claude/templates/"
  # The second site that copies the real .claude/ tree in, so the second caller of
  # the neutralizer. This case does not assert on the template BODY, so nothing
  # here reddens without it today — it is called because the rule is "every site
  # that copies .claude/ in", and a rule with one remembered site and one forgotten
  # one is how the template-seam defect above survived two rounds of fixing.
  _kit_neutral_claude
  publish_sandbox

  local out rc
  _opt() {  # <expected-rc> <label> <script> <args…>
    local want="$1" label="$2"; shift 2
    local s="$1"; shift
    out="$(cd "$SB_WORK" && "$SB_WORK/scripts/$s" "$@" 2>&1)"; rc=$?
    [ "$rc" = "$want" ] || cf "$s: $label → rc=$rc (want $want)"
  }

  local s
  for s in new-issue.sh new-bug.sh new-refactor.sh new-prd.sh; do
    _opt 0 "--help prints usage and SUCCEEDS"      "$s" --help
    _opt 2 "a leading '-' is never a <slug>"       "$s" --id
    _opt 2 "an unknown option refuses"             "$s" someslug --bogus x
  done
  # THE VALUE-TAKING OPTIONS, which the loop above never reaches. Two shapes, both
  # previously unguarded: an option whose value is outside its declared enum, and an
  # option given as the LAST argument with no value at all — that one used to trip
  # `set -u` on a bare $2 and die with "$2: unbound variable", non-zero only by
  # accident of the shell and naming a positional rather than the flag.
  _opt 1 "--severity refuses a value outside its enum"  new-bug.sh sl --id "$SB_PREFIX-901" --severity nonsense
  _opt 2 "a value-taking option with NO value refuses, naming it" new-bug.sh sl --id "$SB_PREFIX-902" --severity
  _opt 2 "the same, on a sibling's flag"                new-refactor.sh sl --id "$SB_PREFIX-903" --target
  printf '%s' "$out" | grep -q -- '--target requires a value' \
    || cf "the no-value refusal did not name the option: $out"

  _opt 0 "--help prints usage and SUCCEEDS"        subtask.sh --help
  _opt 2 "a leading '-' is never a positional"     subtask.sh new --help s1 slug
  _opt 2 "an unknown option refuses"               subtask.sh new "$SB_PREFIX-999" s1 slug --bogus x
  _opt 0 "--help prints usage and SUCCEEDS"        finish-pr.sh --help
  _opt 2 "a leading '-' is never an issue id"      finish-pr.sh --note x
  _opt 2 "an unknown option refuses"               finish-pr.sh "$SB_PREFIX-999" --bogus x

  # The real damage: the refusals must have created NOTHING. A refusal that
  # already wrote the file is the bug, not the fix.
  local minted
  minted="$(find "$SB_WORK/progress" "$SB_WORK/requirements" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
  [ "$minted" = "0" ] || cf "$minted item(s) were created by refused invocations"

  finish "option parsing across the creation and board scripts: a leading '-' is never a name, --help rc=0, an unknown option rc=2, a value outside a declared enum refuses, a value-taking option with no value refuses NAMING ITSELF rather than dying on an unbound positional, and no refusal creates anything"
  teardown
}

# =============================================================================
# CASE — THE SHORT NAME'S SHAPE BINDS EVERY CREATOR, INCLUDING THE TWO THAT SKIPPED IT.
#
# `validate_slug` implements process/contracts/issue-creation.md § 5 and three creators
# called it. `new-prd.sh` did not, and `subtask.sh` did not even source config.sh.
#
# THE TWO HALVES ARE NOT EQUALLY SERIOUS AND THE CASE SAYS SO. For new-prd.sh the
# damage is a shell-hostile filename and a burned id — annoying, contained. For
# subtask.sh it is a FUNCTIONAL BREAK: its create arm writes `branch: feature/<ID>-<SLUG>`
# into a card it PUBLISHES, and the role docs tell Dev and QA to `git switch` that value.
# Measured: a slug with a space makes `git check-ref-format` refuse and `git switch -c`
# exit 128 — so the trunk carries a card naming a branch nobody can check out.
#
# THE SUFFIX IS CHECKED TOO, and leaving it out would have been a false claim of
# closure: it reaches the same filename and the same ref by the same concatenation, and
# the `move` arm recovers the parent with ${ID%-s*}, so a suffix that is not s<digits>
# resolves to the WRONG PARENT rather than failing.
# =============================================================================
case_creation_slug_shape_is_one_rule() {
  cf_reset
  if ! has_issue_template; then skp "the short name's shape binds every creator" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  if [ ! -d "$REAL_REPO_ROOT/.claude/templates" ] || [ ! -f "$REAL_REPO_ROOT/.claude/templates/SUBTASK.template.md" ]; then
    skp "the short name's shape binds every creator" ".claude/templates (or SUBTASK.template.md) absent — the creators exit before the short name is read"
    return
  fi
  make_sandbox
  mkdir -p "$SB_WORK/.claude/templates" "$SB_WORK/requirements"
  cp -R "$REAL_REPO_ROOT/.claude/templates/." "$SB_WORK/.claude/templates/"
  _kit_neutral_claude
  seed_issue todo "$SB_PREFIX-014" parent chore "Decomposition parent"
  publish_sandbox

  local bad='Bad_Slug Name' out rc=0

  # (1) new-prd.sh — the EFFECT: requirements/ untouched, so PRD-001 is not burned.
  rc=0; out="$( cd "$SB_WORK" && ./scripts/new-prd.sh "$bad" 2>&1 )" || rc=$?
  [ "$rc" -eq 2 ] || cf "new-prd.sh: a short name with a space and an underscore → rc=$rc (want 2): $(printf '%s' "$out" | tr '\n' '|')"
  [ -z "$(find "$SB_WORK/requirements" -name '*.md' 2>/dev/null)" ] \
    || cf "new-prd.sh WROTE a file for a refused short name — the id is burned: $(ls -1 "$SB_WORK/requirements")"
  printf '%s' "$out" | grep -q 'position' \
    || cf "new-prd.sh's refusal does not name the offending position: $(printf '%s' "$out" | tr '\n' '|')"

  # (2) subtask.sh — the EFFECT on the TRUNK, which is where its create arm publishes.
  rc=0; out="$( cd "$SB_WORK" && ./scripts/subtask.sh new "$SB_PREFIX-014" s1 "$bad" --title ok 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "subtask.sh new: exited 0 on a short name git itself refuses as a ref"
  origin_has_path "progress/subtasks/$SB_PREFIX-014/todo/$SB_PREFIX-014-s1-$bad.md" \
    && cf "subtask.sh PUBLISHED a card whose filename carries a space and whose branch: is not a legal git ref"
  # THE REFUSAL MUST PRECEDE THE LOCK, not merely the commit — a refusal that reached
  # kwt_bootstrap leaves the shared worktree behind for the next lane.
  [ -e "$SB_WORK/.kanban-wt" ] \
    && cf "subtask.sh reached kwt_bootstrap before refusing the short name — the refusal is not pre-mutation"

  # (3) THE SUFFIX, same arm. Without this the case would ship "the slug is validated"
  #     while the other half of the same concatenation is still open.
  rc=0; out="$( cd "$SB_WORK" && ./scripts/subtask.sh new "$SB_PREFIX-014" 'a b' legal-name --title ok 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "subtask.sh new: exited 0 on a SUFFIX that is not s<digits> — it reaches the filename and the branch name the same way the slug does"

  # (4) THE VALUE IS ECHOED, NOT REWRITTEN INTO LEGALITY (§ 5, and config.sh's reason).
  rc=0; out="$( cd "$SB_WORK" && ./scripts/new-prd.sh "$bad" 2>&1 )" || rc=$?
  printf '%s' "$out" | grep -qF -- "$bad" \
    || cf "the refusal does not echo the name that was typed: $(printf '%s' "$out" | tr '\n' '|')"

  # ── INSTRUMENT CHECK. Everything above is "non-zero and nothing landed", which a
  #    creator broken for ANY reason satisfies. The SAME invocations with a LEGAL short
  #    name must both succeed and both land.
  rc=0; out="$( cd "$SB_WORK" && ./scripts/new-prd.sh legal-name 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(control) new-prd.sh rejected a LEGAL short name (rc=$rc) — this case cannot tell a slug refusal from a broken script: $(printf '%s' "$out" | tr '\n' '|')"
  [ -n "$(find "$SB_WORK/requirements" -name '*legal-name*' 2>/dev/null)" ] \
    || cf "(control) new-prd.sh minted nothing for a legal name — the refusals above prove nothing"
  rc=0; out="$( cd "$SB_WORK" && ./scripts/subtask.sh new "$SB_PREFIX-014" s1 legal-name --title ok 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(control) subtask.sh new rejected a LEGAL short name and suffix (rc=$rc): $(printf '%s' "$out" | tr '\n' '|')"
  origin_has_path "progress/subtasks/$SB_PREFIX-014/todo/$SB_PREFIX-014-s1-legal-name.md" \
    || cf "(control) subtask.sh published nothing for a legal name — the 'did not publish' probe above is vacuous"

  finish "the short name's shape binds every creator: new-prd.sh and subtask.sh refuse a name (or a suffix) outside § 5 BEFORE minting or locking, echo what was typed rather than rewriting it, burn no id and publish nothing — and both still mint normally on legal input"
  teardown
}

case_creation_scripts_substitute_hostile_values() {
  cf_reset
  if ! has_issue_template; then skp "creation scripts substitute hostile values without executing them" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  # WHAT THE OPTION-PARSING CASE ABOVE CANNOT SEE. It exercises REFUSALS, so every
  # invocation it makes stops before the substitution block. Nothing covered the
  # SUCCESS path's substitution, and that is where the damage lived: each value is
  # interpolated into a `s|…|REPL|` expression, where `|` ends the expression, `&`
  # means "the whole match" and `\` escapes. A --prd of `a|b` aborted sed mid-run;
  # a value containing `&` was silently corrupted into the card.
  #
  # AND THE ABORT WAS THE WORSE HALF: the card was copied onto the board BEFORE the
  # substitutions ran, so the failure left a half-filled card and its .bak sitting in
  # progress/todo/ with the template's placeholder id — an id burned by an invocation
  # that reported failure. The contract's own words: a refusal that already wrote the
  # file is the bug.
  if [ ! -d "$REAL_REPO_ROOT/.claude/templates" ] || [ ! -f "$REAL_REPO_ROOT/.claude/templates/SUBTASK.template.md" ]; then
    skp "creation scripts substitute hostile values" ".claude/templates (or SUBTASK.template.md) absent — the creation scripts exit before their substitution block"
    return
  fi
  make_sandbox
  mkdir -p "$SB_WORK/.claude/templates" "$SB_WORK/requirements"
  cp -R "$REAL_REPO_ROOT/.claude/templates/." "$SB_WORK/.claude/templates/"
  _kit_neutral_claude
  seed_issue todo "$SB_PREFIX-014" parent chore "Decomposition parent"
  publish_sandbox

  local out rc card
  # A pipe: the delimiter itself.
  out="$( cd "$SB_WORK" && ./scripts/new-issue.sh piped --id "$SB_PREFIX-910" --prd 'a|b' 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "a --prd containing the sed delimiter did not succeed: rc=$rc $out"
  card="$SB_WORK/progress/todo/$SB_PREFIX-910-piped.md"
  [ -f "$card" ] || cf "the card was not created for a piped --prd"
  grep -q '^prd: a|b$' "$card" 2>/dev/null \
    || cf "the piped value did not land verbatim: $(grep '^prd:' "$card" 2>/dev/null)"

  # An ampersand: sed's "whole match" metacharacter.
  out="$( cd "$SB_WORK" && ./scripts/new-refactor.sh amped --id "$SB_PREFIX-911" --target 'a & b' 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "a --target containing '&' did not succeed: rc=$rc $out"
  card="$SB_WORK/progress/todo/$SB_PREFIX-911-amped.md"
  grep -q '^target_module: a & b$' "$card" 2>/dev/null \
    || cf "the '&' value was corrupted rather than written: $(grep '^target_module:' "$card" 2>/dev/null)"

  # NOTHING PARTIAL IS EVER LEFT. The .bak is the tell: it only exists between the
  # first substitution and the cleanup, so one on the board means a card was being
  # edited in place where the operator can see it.
  local strays
  strays="$(find "$SB_WORK/progress" -name '*.bak' 2>/dev/null | wc -l | tr -d ' ')"
  [ "$strays" = "0" ] || cf "$strays .bak file(s) left on the board — the card is being built in place"

  # And a refusal AFTER the id validates still writes nothing.
  local before after
  before="$(find "$SB_WORK/progress" -name '*.md' | wc -l | tr -d ' ')"
  ( cd "$SB_WORK" && ./scripts/new-bug.sh refused --id "$SB_PREFIX-912" --severity nonsense ) >/dev/null 2>&1
  after="$(find "$SB_WORK/progress" -name '*.md' | wc -l | tr -d ' ')"
  [ "$before" = "$after" ] \
    || cf "a refused invocation changed the board: $before → $after item(s)"

  # ── subtask.sh: THE CREATOR THAT TAKES THE MOST FREE TEXT AND NEVER GOT THE FIX.
  #    Its create arm PUBLISHES, so these read the TRUNK, not the checkout — unlike the
  #    arms above, whose creators are inert.
  local st="progress/subtasks/$SB_PREFIX-014/todo"

  # (a) '&' — sed's whole-match metacharacter. The tell is not "the title is wrong": it
  #     is that the frontmatter and the H1 DISAGREE, because only one path was broken.
  rc=0; out="$( cd "$SB_WORK" && ./scripts/subtask.sh new "$SB_PREFIX-014" s1 amped --title 'Fix A & B' 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "subtask.sh new: a --title containing '&' did not succeed: rc=$rc $(printf '%s' "$out" | tr '\n' '|')"
  origin_file_contains "$st/$SB_PREFIX-014-s1-amped.md" '^title: Fix A & B$' \
    || cf "subtask.sh: the '&' title was corrupted rather than written into the published card"
  origin_file_contains "$st/$SB_PREFIX-014-s1-amped.md" "^# $SB_PREFIX-014-s1 — Fix A & B\$" \
    || cf "subtask.sh: the H1 does not carry the '&' title verbatim"

  # (b) A BACKSLASH — a SECOND escaping bug in the same twelve lines that sed_repl does
  #     NOT fix. `awk -v` performs escape processing, so \t became a tab and \n split the
  #     heading. A fix that only escapes the sed passes (a) and fails here.
  rc=0; out="$( cd "$SB_WORK" && ./scripts/subtask.sh new "$SB_PREFIX-014" s4 backsl --title 'path C:\tmp\new' 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "subtask.sh new: a --title containing a backslash did not succeed: rc=$rc"
  origin_file_contains "$st/$SB_PREFIX-014-s4-backsl.md" '^title: path C:\\tmp\\new$' \
    || cf "subtask.sh: a backslash in --title was interpreted rather than kept — the frontmatter value is not literal"
  origin_file_contains "$st/$SB_PREFIX-014-s4-backsl.md" '^# .*path C:\\tmp\\new$' \
    || cf "subtask.sh: the H1 mangled the backslash — 'awk -v' processes escapes; the heading must go through ENVIRON"

  # (c) '|' — THE DELIMITER, and the real damage is not the abort. sed writes via
  #     `> "$DEST"`, so the file exists before sed fails; `reset --hard` does not remove
  #     an untracked file, so the husk BLOCKS the id. The assertion that cannot be faked
  #     is the control below: the SAME id must still be mintable afterwards.
  rc=0; out="$( cd "$SB_WORK" && ./scripts/subtask.sh new "$SB_PREFIX-014" s2 piped --title 'a|b' 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "subtask.sh new: a --title containing the sed delimiter aborted: rc=$rc $(printf '%s' "$out" | tr '\n' '|')"
  origin_file_contains "$st/$SB_PREFIX-014-s2-piped.md" '^title: a|b$' \
    || cf "subtask.sh: the piped value did not land verbatim in the published card"

  # NO HUSK IN THE SHARED WORKTREE. This is the durable half of the '|' damage and it
  # outlives the failed run: sed's `> "$DEST"` creates the file before sed fails, and
  # `reset --hard` does not remove an untracked file, so a zero-byte card survives in a
  # directory the docs tell operators not to touch and blocks that id.
  #
  # NOTE WHY THIS IS NOT "re-mint the same id and expect success": once the escaping
  # WORKS, the piped run publishes the card, so re-minting that id correctly refuses with
  # "already exists". The first draft of this control asserted the opposite and reddened
  # on the fix. The husk itself is the thing to look for, so look for it.
  local husk
  husk="$( { find "$SB_WORK/.kanban-wt/progress/subtasks" -type f -name '*.md' -size 0 2>/dev/null || true; } )"
  [ -z "$husk" ] \
    || cf "a ZERO-BYTE card was left in the SHARED kanban worktree ($husk) — reset --hard does not remove it, so it blocks that subtask id until someone deletes a file by hand inside .kanban-wt/"

  finish "creation scripts (subtask.sh included): a value carrying sed's delimiter or its whole-match metacharacter lands VERBATIM in the card, no .bak is ever left on the board, and a refusal after id validation creates nothing"
  teardown
}


# =============================================================================
# CASE — THE FIRST MILE, pinned end to end.
#
# Three defects, each independently replicated by a live agent, each fixed by a
# COMPOSITION change rather than a contract change:
#   • the kit-init × next-id composition bug: kit-init's printed recipe embedded
#     $(next-id.sh), which on the board kit-init has just left EMPTY correctly
#     REFUSES. This asserts BOTH halves — the recipe prints the literal first id,
#     AND next-id.sh still refuses on that same empty board. If the second half
#     ever goes green by next-id.sh answering, the fix was applied to the wrong
#     file;
#   • the push-before-you-move trap: creation PRINTS the push step, and the
#     mover's not-found error NAMES the cause. Both proven by running them, in
#     that order;
#   • the false drift-[a] finding: a FRESHLY MINTED card must read clean. The old
#     template's Activity bullet is re-created as an ABLATION CONTROL, because a
#     clean assertion with a dead comparator proves nothing.
# =============================================================================
case_first_mile() {
  cf_reset
  if ! has_kit_init; then skp "first mile: kit-init → mint → push → move → drift-clean" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "first mile: kit-init → mint → push → move → drift-clean" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  publish_sandbox

  local out rc f
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || cf "kit-init exited $rc: $out"

  # The COMPOSITION: the printed recipe names the literal first id…
  printf '%s\n' "$out" | grep -q -- '--id SBX-001' \
    || cf "the printed next-step recipe does not name the literal first id 'SBX-001': $out"
  # …and it no longer offers next-id.sh for the FIRST mint.
  printf '%s\n' "$out" | grep 'next-id.sh' | grep -qi 'after the first\|refuses' \
    || cf "next-id.sh is still offered without the after-the-first qualification: $out"

  # The CONTRACT is untouched: next-id.sh still refuses on the empty board.
  local nid_err nid_rc
  nid_err="$(cd "$SB_WORK" && "$SB_WORK/scripts/next-id.sh" 2>&1 1>/dev/null)"; nid_rc=$?
  [ "$nid_rc" -ne 0 ] || cf "next-id.sh answered on an EMPTY board — the id-minting refusal was weakened"
  printf '%s' "$nid_err" | grep -qi 'no existing' || cf "next-id.sh's refusal lost its explanation: $nid_err"

  # Follow the printed recipe VERBATIM: the first issue mints.
  out="$(cd "$SB_WORK" && "$SB_WORK/scripts/new-issue.sh" first-mile --id SBX-001 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || cf "the printed first-mint recipe failed (rc=$rc): $out"
  f="$SB_WORK/progress/todo/SBX-001-first-mile.md"
  [ -f "$f" ] || cf "the printed recipe did not create progress/todo/SBX-001-first-mile.md"
  printf '%s\n' "$out" | grep -q 'PUSH IT BEFORE YOU MOVE IT' \
    || cf "new-issue.sh does not print the push-before-you-move step: $out"

  # The mover's not-found error NAMES the cause.
  out="$(cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" SBX-001 in_progress --role PM --note x 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] || cf "the mover moved a card that was never pushed"
  printf '%s\n' "$out" | grep -q 'no file matching' || cf "the mover's error changed shape: $out"
  printf '%s\n' "$out" | grep -qi 'not yet pushed' \
    || cf "the not-found error does not name 'minted but not yet pushed?': $out"
  # THE COSTS-NOTHING ASSERTION DOES NOT BELONG HERE, and the reason is measured
  # rather than argued (2026-08-28). It was authored for this spot as
  # "it must not have bootstrapped a worktree … in a repo that had none". This repo
  # HAS one by the time this line runs: kit-init's own self-check moves a scratch card
  # through two columns a few lines above, and each move legitimately bootstraps
  # .kanban-wt. Measured at this exact point — before the call kanban=1, after the call
  # kanban=1, and the refusal's provenance line reads "read the TRUNK's board straight
  # out of …", so the probe refused exactly as designed and created nothing. The
  # assertion would therefore have been a FALSE RED over correct behaviour, measuring
  # kit-init's residue instead of the refusal's cost.
  # The property itself is not lost: case_move_issue_probe (a) asserts it where
  # make_sandbox guarantees the premise, and (b) ablation-proves that (a) can fail.

  # Push, then the move composes.
  git -C "$SB_WORK" add "progress/todo/SBX-001-first-mile.md" >/dev/null 2>&1
  git -C "$SB_WORK" commit -qm "[PM] SBX-001: mint" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1

  # A freshly minted card produces NO drift-[a] finding.
  cb_a() { CLAUDE_PROJECT_DIR="$SB_WORK" "$SB_WORK/scripts/check-board.sh" 2>&1 \
             | awk '/^\[a\]/{a=1} a&&/^\[b\]/{exit} a{print}'; }
  out="$(cb_a)"
  printf '%s\n' "$out" | grep -q '⚠' && cf "a FRESHLY MINTED card produced a drift-[a] finding: $out"
  # ABLATION CONTROL — plant an Activity bullet DECLARING another column and the
  # comparator must fire. Without this, the assertion above is unfalsifiable.
  cp "$f" "$SB_WORK/progress/todo/SBX-002-old-shape.md"
  sed -i.bak 's/^id: SBX-001/id: SBX-002/' "$SB_WORK/progress/todo/SBX-002-old-shape.md"
  rm -f "$SB_WORK/progress/todo/SBX-002-old-shape.md.bak"
  printf -- '- 2026-01-03 [QA] Review — PASS; moved to `qa_complete/`.\n' \
    >> "$SB_WORK/progress/todo/SBX-002-old-shape.md"
  # THE PLANT MUST BE PUBLISHED, because arm [a]'s subject is the TRUNK's board and
  # it reads a named ref. Planted in the working tree only, it is invisible by
  # design and this control would fail for the right reason — which is how it was
  # found: it reddened the moment the arms stopped reading the checkout.
  git -C "$SB_WORK" add "progress/todo/SBX-002-old-shape.md" >/dev/null 2>&1
  git -C "$SB_WORK" commit -qm "[PM] SBX-002: ablation plant" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  out="$(cb_a)"
  printf '%s\n' "$out" | grep -q 'SBX-002-old-shape.md' \
    || cf "(control) the [a] comparator did NOT fire on a bullet declaring qa_complete — the clean result above proves nothing: $out"
  # Withdraw the plant from the trunk too, so the move below runs against the board
  # the rest of this case describes.
  git -C "$SB_WORK" rm -q "progress/todo/SBX-002-old-shape.md" >/dev/null 2>&1
  git -C "$SB_WORK" commit -qm "[PM] SBX-002: withdraw the ablation plant" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1

  # And the move itself now composes.
  out="$(cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" SBX-001 in_progress --role PM --note "picked up" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || cf "the move failed after the printed push step (rc=$rc): $out"
  [ -f "$SB_WORK/progress/in_progress/SBX-001-first-mile.md" ] \
    || cf "the card did not land in progress/in_progress/"

  finish "first mile: kit-init prints the literal first id (next-id.sh still refuses), the push step is unmissable, the mover names the cause, a fresh mint is drift-[a] clean (ablation-proven)"
  teardown
}

# =============================================================================
# THE RELEASE FAMILY — driven through release.sh's DECLARED SEAMS.
#
# The frame ships with an empty config block, so each case FILLS IT IN inside the
# sandbox (two version files, covering both the quoted and the bare form; two
# release documents; optionally the publish config) and then walks the REAL entry
# point. Nothing here asserts one project's version files.
#
# WHY THESE ARE END TO END: a gate and a version rule were once each proven in
# isolation while the full cut path was mutually unsatisfiable — the suite gate
# ran before the bump, the docs gate refused to tag a version whose section was
# not already written, and a separate rule refused any section ahead of the
# packaged version. Every arm was green; the path was impossible. So the publish
# and the gates are never exercised as lone functions.
# =============================================================================
has_release() { [ -f "$REAL_SCRIPTS/release.sh" ]; }

# Insert a record after a config-array's opening line in the sandbox's release.sh.
# BOTH OF THESE ASSERT — see "EVERY MUTATION ASSERTS" above. They are two of the
# three helpers measured exiting 0 over a byte-identical file when their anchor was
# absent, which is how a release case could declare no VERSION_FILES at all and
# still report PASS about the version rule.
rel_insert() {  # <array-name> <record-line>
  local rel="$SB_WORK/scripts/release.sh"
  grep -qE "^$1=\($" "$rel" \
    || _fixture_die "rel_insert: no '^$1=(' line in the sandbox's release.sh — the record '$2' was NOT inserted, so this case declares no $1."
  perl -i -pe 'BEGIN{$a=shift; $r=shift} $_ .= "  $r\n" if /^\Q$a\E=\($/' \
    "$1" "$2" "$rel"
  grep -qxF "  $2" "$rel" \
    || _fixture_die "rel_insert: '$2' is not in the sandbox's release.sh after the insert into $1."
}
rel_set() {     # <line-regex> <replacement-line>
  local rel="$SB_WORK/scripts/release.sh"
  grep -qE "^$(printf '%s' "$1" | sed 's/[][\.*^$(){}?+|/]/\\&/g')" "$rel" \
    || _fixture_die "rel_set: no line beginning '$1' in the sandbox's release.sh — it was NOT set to '$2', so this case runs against the shipped value."
  perl -i -pe 'BEGIN{$m=shift; $r=shift} s/^\Q$m\E.*$/$r/' "$1" "$2" "$rel"
  grep -qxF "$2" "$rel" \
    || _fixture_die "rel_set: the sandbox's release.sh does not carry '$2' after the set."
}

# Plant a mid-run kill immediately BEFORE the pushes, so what dies is a LEGITIMATE
# cut that has already made its local acts. ASSERTS, like rel_insert/rel_set above:
# an un-planted kill leaves the case testing a healthy run and reporting PASS.
rel_plant_midrun_kill() {
  local rel="$SB_WORK/scripts/release.sh"
  grep -qE '^echo ".*pushing commit \+ tag' "$rel" \
    || _fixture_die "rel_plant_midrun_kill: no push-announcement line in the sandbox's release.sh — the kill was NOT planted, so this case would test a healthy run."
  perl -i -pe 's|^(echo ".*pushing commit \+ tag)|exit 143  # planted mid-run kill\n$1|' "$rel"
  grep -q 'planted mid-run kill' "$rel" \
    || _fixture_die "rel_plant_midrun_kill: the sandbox's release.sh does not carry the planted kill after the edit."
}

# Seed the version-bearing files + both release documents. <doc1_target|none> [doc2_target|none]
# THE PRE-RELEASE VERSION, published by the seeder and read by the assertion, so both
# operands come from the same authority at the same moment. It was a literal in both,
# which is a retyped copy of a value one of them owns.
SB_REL_PRE_VERSION="1.0.0"

seed_release_files() {
  local target="$1" notes_target="${2:-$1}"
  printf '%s\n' "$SB_REL_PRE_VERSION" > "$SB_WORK/VERSION"
  cat > "$SB_WORK/pkg.conf" <<'EOF'
[package]
name = "sandbox"
version = "PRE"
EOF
  perl -i -pe 'BEGIN{$v=shift} s/^version = "PRE"$/version = "$v"/' "$SB_REL_PRE_VERSION" "$SB_WORK/pkg.conf"
  grep -qF "version = \"$SB_REL_PRE_VERSION\"" "$SB_WORK/pkg.conf" \
    || _fixture_die "seed_release_files: pkg.conf does not carry the pre-release version — every 'was not mutated' assertion downstream would be about the wrong string."
  rel_insert VERSION_FILES '"VERSION||"'
  rel_insert VERSION_FILES '"pkg.conf|version = |\""'
  rel_insert RELEASE_DOCS  '"CHANGELOG.md|the internal engineering log"'
  rel_insert RELEASE_DOCS  '"NOTES.md|the consumer-facing filtered notes"'
  seed_release_doc "$SB_WORK/CHANGELOG.md" "Changelog" "$target"
  seed_release_doc "$SB_WORK/NOTES.md"     "Release notes" "$notes_target"
}
seed_release_doc() {  # <path> <title> <target|none> [body-date]
  local path="$1" title="$2" target="$3" body_date="${4:-2026-07-24}"
  {
    echo "# $title"
    echo
    if [ "$target" != "none" ]; then
      echo "## [$target] — 2026-07-24"
      echo "seeded section, measured $body_date"
      echo
    fi
    echo "## [1.0.0] — 2026-07-23"
    echo "seed"
  } > "$path"
}
# The LAST "release.sh: …" refusal line from a captured run — the message whose
# wording the two document arms must NOT share.
release_refusal_line() { printf '%s\n' "$1" | grep '^release\.sh:' | tail -1; }

# THE STUB'S VERDICT LINE IS DERIVED FROM THE REAL PRODUCER, NOT RE-TYPED, and the reason is that
# the re-typed copy had ALREADY ROTTED: the drift line here read "(informational)" while
# check-board.sh emits "(informational; exit 0 by convention)". Harmless on the day it diverged —
# nothing matched the suffix — which is exactly how a second copy earns its keep until it does not.
#
# THIS IS NOT THE FIXTURE-ASKS-THE-SUBJECT TRAP, and the distinction is worth stating because the
# shape looks identical. The subject of every case that uses this stub is release.sh's gate (d);
# check-board.sh is the thing being STOOD IN FOR, not the thing under test. So reading its wording
# makes the impostor faithful rather than making the assertion circular.
#
# WHAT IT BUYS, MEASURED — and the first answer written here was WRONG, so it is stated carefully.
# The draft claimed a reworded verdict would reach release.sh's grep and redden the release cases.
# It cannot: release.sh greps the substring 'board-drift: clean', and the derivation needle below is
# that same substring. Any rewording that keeps it leaves both satisfied; any rewording that loses it
# makes the derivation find nothing and the fixture DIES FIRST, before a release case runs.
#
# So the direction this actually buys is a LOUDER FAILURE AT CONSTRUCTION, which is the better one:
# a wording change that breaks the stand-in now exits 1 naming the file and the missing verdict,
# instead of the harness running on with an impostor whose text no longer matches anything shipped.
# Proven both ways in a scratch tree: renaming the clean verdict fires the arm below; leaving it
# alone runs green at the measured baseline.
_board_verdict() {   # <clean|drift> — the real producer's verdict line, verbatim
  local needle
  case "$1" in
    clean) needle='board-drift: clean' ;;
    *)     needle='board-drift: findings above' ;;
  esac
  # awk, not `sed | head`: a reader that exits early makes the pipeline report the PRODUCER's death
  # under pipefail — the trap this file's own header documents.
  awk -v n="$needle" '
    !seen && index($0, "echo \"── " n) {
      line = $0
      sub(/^[[:space:]]*echo "/, "", line)
      sub(/"[[:space:]]*$/, "", line)
      print line; seen = 1
    }
  ' "$REAL_REPO_ROOT/scripts/check-board.sh"
}

write_board_stub() {  # <path> clean|drift
  local verdict; verdict="$(_board_verdict "$2")"
  # ASSERT THE EXTRACTOR. An empty derivation would write a stub that prints nothing, and every
  # release case would then fail on a missing marker — a red with the wrong cause, which is worse
  # than the divergence this replaced.
  if [ -z "$verdict" ]; then
    echo "FIXTURE BROKEN: could not derive the '$2' verdict line from $REAL_REPO_ROOT/scripts/check-board.sh." >&2
    echo "                The stub would print nothing and every release case would redden for the wrong reason." >&2
    exit 1
  fi
  { printf '#!/usr/bin/env bash\n'; printf 'echo "%s"\n' "$verdict"; } > "$1"
  chmod +x "$1"
}

# Assert release.sh mutated NOTHING — version files still 1.0.0 locally AND on the
# remote, and no tag anywhere. The "abort BEFORE mutating anything" contract.
# assert_release_unmutated <cut-version>
#
# THE CUT VERSION IS AN ARGUMENT, and it used to be the literal `v1.1.0` in the tag arm.
# That coupled fourteen call sites to one string: a leg cutting any other version got a
# tag check that looked for a tag nobody would create, and passed. The tag arm was the
# only one of the four that could be silently satisfied that way, and it is the arm
# guarding the most expensive mutation.
#
# The PRE-state comes from the seeder rather than from a second literal here, so the two
# operands are the same value read from one authority.
assert_release_unmutated() {  # <cut-version>
  local cut="${1:?assert_release_unmutated: the cut version is required — without it the tag arm looks for a tag nobody would have created and passes}"
  grep -qx "$SB_REL_PRE_VERSION" "$SB_WORK/VERSION" || cf "VERSION was mutated despite an aborted preflight"
  grep -qF "version = \"$SB_REL_PRE_VERSION\"" "$SB_WORK/pkg.conf" || cf "pkg.conf was mutated despite an aborted preflight"
  git -C "$SB_WORK" rev-parse -q --verify "refs/tags/v$cut" >/dev/null 2>&1 \
    && cf "tag v$cut was created despite an aborted preflight"
  origin_file_contains "VERSION" "$SB_REL_PRE_VERSION" || cf "a version bump reached the remote despite an aborted preflight"
}
run_release() {  # <version> [extra args…]
  ( cd "$SB_WORK" && RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=true \
      RELEASE_BOARD_CMD="$SB_TMP/board-clean.sh" \
      "$SB_WORK/scripts/release.sh" "$@" 2>&1 )
}

# =============================================================================
# CASE — GATE (a) SEES A STALE CHECKOUT.
#
# Its first two checks read only this machine, so a clean trunk that is BEHIND the
# remote passed every one of them and the cut named a tree missing whatever landed
# after it. The damage does not arrive at the branch push — that is rejected — it
# arrives through the script's OWN printed recovery, which an operator completes by
# rebasing and then tagging the pre-rebase commit.
#
# THE TRACKING REF IS DELIBERATELY REWOUND before the behind leg, and that is the
# whole point of the case. Measured: `git fetch <URL> <branch>` returns 0 and does
# NOT update refs/remotes/<remote>/<branch>, so an implementation that compares
# against the tracking ref reads "in sync" and passes a behind checkout whenever the
# release remote is given as a URL. Rewinding the ref is what makes the FETCH
# load-bearing rather than decorative: without it, leg (i) passes for a fix that
# never fetches at all.
#
# THE OFFLINE HALF IS NOT OPTIONAL. The kit REQUIRES only git and a POSIX shell, and
# the sandbox's own origin is a LOCAL BARE PATH — offline in the network sense and
# perfectly fetchable. Leg (v) proves the refusal does not fire there; leg (iv)
# proves the declared escape works when the remote genuinely cannot be reached.
# Leg (iv) is --dry-run because a full cut against a dead remote fails at the PUSH
# regardless of this gate, so a nonzero exit there would say nothing about gate (a).
# =============================================================================
# =============================================================================
# CASE — THE PUBLICATION REMOTE HAS ONE SHARED NAME AND ONE NARROW OVERRIDE.
#
# `KWT_REMOTE` is honoured by six operations; `RELEASE_REMOTE` was read by exactly one.
# So a fork that set KWT_REMOTE=upstream published its BOARD there and its RELEASES to
# origin — silently, with a success message. release.sh now reads
# ${RELEASE_REMOTE:-${KWT_REMOTE:-origin}}: narrow beats shared, shared beats the
# default, and NEITHER name stops being read, so nobody's existing setting is ignored.
#
# EVERY ASSERTION READS WHERE THE ANNOTATED TAG PHYSICALLY LANDED, never a printed
# remote name — a script that prints the right remote and pushes to the wrong one would
# satisfy any output check.
# =============================================================================
case_release_honours_the_one_remote_name() {
  cf_reset
  if ! has_release; then skp "release.sh honours the shared publication remote" "scripts/release.sh absent"; return; fi
  local out rc fork

  _fork_sandbox() {
    make_sandbox; seed_release_files 1.1.0; publish_sandbox
    write_board_stub "$SB_TMP/board-clean.sh" clean
    fork="$SB_TMP/fork.git"
    git init --bare -q "$fork"
    git -C "$fork" symbolic-ref HEAD "refs/heads/$SB_TRUNK"
    git -C "$SB_WORK" remote add upstream "$fork" >/dev/null 2>&1
    git -C "$SB_WORK" push -q upstream "$SB_TRUNK" >/dev/null 2>&1
    git -C "$SB_WORK" remote set-head upstream "$SB_TRUNK" >/dev/null 2>&1
    # THE TWO REMOTES MUST BE DIFFERENT REPOSITORIES, or every leg below passes without
    # measuring anything at all.
    [ "$fork" != "$SB_ORIGIN" ] \
      || _fixture_die "case_release_honours_the_one_remote_name: the fork and origin are the same path."
    [ -n "$(git -C "$SB_WORK" ls-remote --heads "$fork" "$SB_TRUNK" 2>/dev/null)" ] \
      || _fixture_die "case_release_honours_the_one_remote_name: the fork carries no trunk, so a push there cannot be distinguished from a push nowhere."
    [ -z "$(git -C "$SB_WORK" ls-remote --tags "$fork" v1.1.0 2>/dev/null)" ] \
      || _fixture_die "case_release_honours_the_one_remote_name: the fork already carries v1.1.0 before any cut."
  }

  # --- (a) KWT_REMOTE alone retargets the release --------------------------
  _fork_sandbox
  rc=0
  out="$( cd "$SB_WORK" && KWT_REMOTE=upstream RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=true \
            RELEASE_BOARD_CMD="$SB_TMP/board-clean.sh" "$SB_WORK/scripts/release.sh" 1.1.0 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(a) the cut failed with KWT_REMOTE=upstream (rc=$rc): $(printf '%s' "$out" | tr '\n' '|')"
  [ -n "$(git -C "$SB_WORK" ls-remote --tags "$fork" v1.1.0 2>/dev/null)" ] \
    || cf "(a) the tag did NOT reach the fork — release.sh ignored KWT_REMOTE, so a fork's board and its releases go to different places"
  [ -z "$(git -C "$SB_WORK" ls-remote --tags "$SB_ORIGIN" v1.1.0 2>/dev/null)" ] \
    && : || cf "(a) the tag ALSO reached origin — the release was published to a remote the project did not name"
  teardown

  # --- (b) RELEASE_REMOTE still overrides, narrow beats shared -------------
  _fork_sandbox
  rc=0
  out="$( cd "$SB_WORK" && KWT_REMOTE=upstream RELEASE_REMOTE=origin RELEASE_TEST_ALLOW_STUB=1 \
            RELEASE_VERIFY_CMD=true RELEASE_BOARD_CMD="$SB_TMP/board-clean.sh" \
            "$SB_WORK/scripts/release.sh" 1.1.0 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(b) the cut failed with RELEASE_REMOTE=origin overriding KWT_REMOTE (rc=$rc): $(printf '%s' "$out" | tr '\n' '|')"
  [ -n "$(git -C "$SB_WORK" ls-remote --tags "$SB_ORIGIN" v1.1.0 2>/dev/null)" ] \
    || cf "(b) RELEASE_REMOTE did not win over KWT_REMOTE — the narrow override stopped being read, which silently ignores an adopter's existing setting"
  [ -z "$(git -C "$SB_WORK" ls-remote --tags "$fork" v1.1.0 2>/dev/null)" ] \
    && : || cf "(b) the tag also reached the fork — the override did not scope the push"
  teardown

  unset -f _fork_sandbox
  finish "release.sh honours the shared publication remote: KWT_REMOTE alone retargets the release push and tag to a fork (and not to origin), and RELEASE_REMOTE still overrides it for the release only — asserted on where the annotated tag physically landed"
}

# =============================================================================
# CASE — THE CLI SHAPE HOLDS ACROSS THE WHOLE SHIPPED SET, DERIVED NOT LISTED.
#
# contracts/issue-creation.md § 3 binds every command-line tool the kit ships: a usage
# request is always legal and always succeeds; an unrecognised option refuses, non-zero,
# NAMING it, with ONE status across the set — and § 3 now names that status as 2.
#
# THE SUBJECT SET IS DERIVED FROM THE SANDBOX, and that is the whole design. The change
# file that raised this carried a hand-assembled list, and the list was wrong in both
# directions — it named two scripts that already conformed and missed the two dangerous
# ones, where a REFUSAL READ AS SUCCESS: `next-id.sh --help` printed a mintable
# identifier and exited 0, and `notify.sh` warned about a stray flag, delivered the
# message anyway, and exited 0. A control that restated that list would have inherited
# its blind spots; this one goes blind only if the glob does.
#
# `</dev/null` IS LOAD-BEARING on every invocation: an enumeration that reaches a
# stdin-reading tool without it hangs the whole suite rather than failing it.
# =============================================================================
# =============================================================================
# CASE — EACH HELP WINDOW ENDS WHERE ITS OWN RULE SAYS, AND THERE ARE TWO RULES.
#
# Most shipped tools render `--help` from their own header comment block, ending at the
# LAST COMMENT LINE. `release.sh` ends at its LAST USAGE EXAMPLE instead, deliberately —
# its header carries operator notes below the examples that are not help text. Measured:
# putting release.sh on the header-block rule takes its --help from its SYNOPSIS length to the whole
# header block — measure both rather than quoting figures here (`./scripts/release.sh --help | wc -l`
# against `bash -c '. scripts/lib/usage.sh; kit_usage scripts/release.sh' | wc -l`); this said 63 and
# the second measure is now 66.
#
# WHY A CONTROL AT ALL. Nothing asserted --help CONTENT for any tool — the existing
# coverage checks rc=0 and non-emptiness. A hard-coded window is a census in disguise,
# and this repository has paid for that class twice: a control that came back green
# because the paragraph it was checking had landed OUTSIDE the window it checked.
#
# THE CORPUS IS DERIVED, and by BEHAVIOUR rather than by a list of filenames, so it
# survives the renderer being lifted into a library: a script is a header renderer iff
# its --help succeeds and its first output line is its own line 3, de-hashed.
# =============================================================================
# =============================================================================
# CASE — THE HEADER-BLOCK --help RENDERER HAS ONE AUTHORING SITE.
#
# "It sources lib/usage.sh" is a LABEL, satisfied by a script that sources the file and
# then goes on using its own inline copy. Nothing below asserts it. What cannot be faked:
# make the LIBRARY emit an extra line and every consumer must show it.
#
# ARM 2 IS THE ONE THAT CATCHES THE TRAP, and arm 1 cannot see it. Inside a SOURCED
# function `${BASH_SOURCE[0]}` names THE LIBRARY — so a naive lift makes every caller's
# --help print lib/usage.sh's own header. The sentinel is IN the library, so arm 1 stays
# green while every tool prints the wrong document. Arm 2 asserts each consumer still
# renders ITS OWN header, which is the only thing that distinguishes the two.
# =============================================================================
case_usage_renderer_has_one_authoring_site() {
  cf_reset
  make_sandbox
  publish_sandbox

  local lib="$SB_WORK/scripts/lib/usage.sh" tok='USAGERENDER-ONE-HOST-SENTINEL'
  [ -f "$lib" ] \
    || _fixture_die "case_usage_renderer_has_one_authoring_site: no scripts/lib/usage.sh in the sandbox — there is no shared host to mutate."
  [ -z "$( { find "$SB_WORK/scripts" -type f ! -path '*/test/*' -exec grep -lF "$tok" {} + 2>/dev/null || true; } )" ] \
    || _fixture_die "case_usage_renderer_has_one_authoring_site: the sentinel already occurs under scripts/ — the plant would prove nothing."

  # THE CONSUMER SET IS DERIVED, never listed — a literal list in a guard goes blind the
  # first time a script joins or leaves.
  local consumers f base out n=0
  # Matched WITHOUT a line anchor on purpose: verify.sh sources the library inside a
  # guard (it runs `set -uo pipefail` and not `set -e`, so an unguarded load would fail
  # silently and take --help down with rc=127). An anchored pattern would leave the one
  # consumer with the most fragile load out of the very case that checks the load.
  consumers="$( { grep -lF '. "$SCRIPT_DIR/lib/usage.sh"' "$SB_WORK"/scripts/*.sh 2>/dev/null || true; } )"
  [ -n "$consumers" ] \
    || _fixture_die "case_usage_renderer_has_one_authoring_site: no script sources lib/usage.sh — the per-consumer loop below would run zero times and report PASS."

  # PRE-PLANT: every consumer's --help must already work, or the post-plant grep fails
  # for a reason that has nothing to do with the library.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    base="$(basename "$f")"
    out="$( cd "$SB_WORK" && "$f" --help </dev/null 2>&1 )" \
      || _fixture_die "case_usage_renderer_has_one_authoring_site: $base --help already fails BEFORE the plant."
    [ -n "$out" ] \
      || _fixture_die "case_usage_renderer_has_one_authoring_site: $base --help prints nothing before the plant."
  done <<PRE_EOF
$consumers
PRE_EOF

  # THE PLANT — one extra emitted line, in the LIBRARY only.
  _plant_in_function "$lib" kit_usage "  echo '$tok'" \
    "case_usage_renderer_has_one_authoring_site"

  while IFS= read -r f; do
    [ -n "$f" ] || continue
    base="$(basename "$f")"; n=$((n+1))
    out="$( cd "$SB_WORK" && "$f" --help </dev/null 2>&1 )"
    # ARM 1 — the plant reaches this consumer.
    printf '%s\n' "$out" | grep -qF "$tok" \
      || cf "(1) $base --help does not carry a line added to lib/usage.sh — it sources the library and then renders with its own inline copy"
    # ARM 2 — …and it still renders ITS OWN header, not the library's.
    printf '%s\n' "$out" | grep -qF "$(sed -n '3p' "$f" | sed 's|^# \{0,1\}||')" \
      || cf "(2) $base --help no longer contains its OWN line 3 — the renderer is reading \${BASH_SOURCE[0]}, which inside a sourced function names the LIBRARY, so every tool is printing lib/usage.sh's header"
  done <<POST_EOF
$consumers
POST_EOF

  # ARM 3 — no second authoring site survives under scripts/.
  local second
  second="$( { grep -rlF "awk 'NR>2 && !/^#/{print NR; exit}'" "$SB_WORK/scripts" 2>/dev/null || true; } | grep -v '/lib/usage\.sh$' | grep -v '/test/' || true )"
  [ -z "$second" ] \
    || cf "(3) the header-block renderer is still authored in: $(printf '%s' "$second" | tr '\n' ' ') — one rule, more than one place to change it"

  finish "the header-block --help renderer has ONE authoring site: a line added to scripts/lib/usage.sh reaches all $n consumer(s), each still renders its OWN header rather than the library's, and no second implementation survives under scripts/"
  teardown
}

case_help_window_ends_where_its_rule_says() {
  cf_reset
  make_sandbox
  publish_sandbox

  local tokA='HELPWINDOW-TAIL-SENTINEL' tokIn='HELPWINDOW-EXAMPLE-SENTINEL' tokOut='HELPWINDOW-BELOW-SENTINEL'
  [ -z "$( { find "$SB_WORK/scripts" -type f ! -path '*/test/*' -exec grep -lF "$tokA" {} + 2>/dev/null || true; } )" ] \
    || _fixture_die "case_help_window_ends_where_its_rule_says: the sentinel already occurs under scripts/ — every assertion would be satisfiable without the plant."

  # ── derive the corpus by BEHAVIOUR.
  local f base line3 out corpus="" n=0
  for f in "$SB_WORK"/scripts/*.sh; do
    [ -e "$f" ] || continue
    out="$( cd "$SB_WORK" && "$f" --help </dev/null 2>&1 )" || continue
    line3="$(sed -n '3p' "$f" | sed 's|^# \{0,1\}||')"
    [ -n "$line3" ] || continue
    [ "$(printf '%s\n' "$out" | sed -n '1p')" = "$line3" ] || continue
    corpus="${corpus}${f}\n"; n=$((n+1))
  done
  [ "$n" -gt 1 ] \
    || _fixture_die "case_help_window_ends_where_its_rule_says: the derived corpus holds $n script(s) — the probe lost its subject and every arm below would be vacuous."

  # ── (a) THE HEADER-BLOCK RULE: a comment on the LAST line of the header must appear.
  #    The insert point is computed HERE, never asked of the script — a harness that
  #    asked the subject where its header ends would agree with it by construction.
  local first ins seen_release=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    base="$(basename "$f")"
    if [ "$base" = "release.sh" ]; then seen_release=1; continue; fi
    first="$(awk 'NR>2 && !/^#/{print NR; exit}' "$f")"
    [ -n "$first" ] && [ "$first" -gt 3 ] \
      || _fixture_die "case_help_window_ends_where_its_rule_says: $base has no header block to plant into (first non-comment line: ${first:-none})."
    ins=$((first-1))
    TOK="$tokA" LN="$ins" awk -v tok="$tokA" -v ln="$ins" 'NR==ln{print; print "# " tok; next} {print}' "$f" > "$f.new" && mv "$f.new" "$f"
    chmod +x "$f"
    grep -qF "$tokA" "$f" || _fixture_die "case_help_window_ends_where_its_rule_says: the tail sentinel did not land in $base."
    bash -n "$f" || _fixture_die "case_help_window_ends_where_its_rule_says: $base no longer parses after the plant."
    out="$( cd "$SB_WORK" && "$f" --help </dev/null 2>&1 )"
    printf '%s\n' "$out" | grep -qF "$tokA" \
      || cf "(a) $base --help does not print the LAST line of its own header — its window is truncated, which is the hard-coded-range defect this class has already been paid for twice"
  done <<CORPUS_EOF
$(printf '%b' "$corpus")
CORPUS_EOF

  # ── (b) THE SYNOPSIS RULE: release.sh ends at its last usage EXAMPLE, both directions.
  if [ "$seen_release" -eq 1 ]; then
    local r="$SB_WORK/scripts/release.sh" lastex
    lastex="$(grep -n '^#[[:space:]]\{1,\}\./scripts/release\.sh[[:space:]]' "$r" | tail -1 | cut -d: -f1)"
    [ -n "$lastex" ] \
      || _fixture_die "case_help_window_ends_where_its_rule_says: no usage-example line in release.sh's header — its window rule has no anchor and arm (b) measures nothing."
    awk -v ln="$lastex" -v tok="$tokIn" 'NR==ln{print; print "#   ./scripts/release.sh 9.9.9   " tok; next} {print}' "$r" > "$r.new" && mv "$r.new" "$r"
    first="$(awk 'NR>2 && !/^#/{print NR; exit}' "$r")"
    awk -v ln=$((first-1)) -v tok="$tokOut" 'NR==ln{print; print "# " tok; next} {print}' "$r" > "$r.new" && mv "$r.new" "$r"
    chmod +x "$r"
    grep -qF "$tokIn" "$r" && grep -qF "$tokOut" "$r" \
      || _fixture_die "case_help_window_ends_where_its_rule_says: one of release.sh's two sentinels did not land."
    bash -n "$r" || _fixture_die "case_help_window_ends_where_its_rule_says: release.sh no longer parses after the plant."
    out="$( cd "$SB_WORK" && "$r" --help </dev/null 2>&1 )"
    printf '%s\n' "$out" | grep -qF "$tokIn" \
      || cf "(b) release.sh --help dropped a usage example added at the END of its examples — its window is not tracking the last example: $out"
    printf '%s\n' "$out" | grep -qF "$tokOut" \
      && cf "(b) release.sh --help printed a header line BELOW its last usage example — it has been put on the header-block rule, which floods its help with operator notes that are not help text"
  fi

  finish "each --help window ends where its own rule says: the header-block renderers print to the LAST line of their header (a tail sentinel proves it), and release.sh prints to its LAST USAGE EXAMPLE and no further — both directions asserted, corpus derived by behaviour over $n tool(s)"
  teardown
}

# =============================================================================
# CASE — NO DOCTRINE SHEET WRITES A COUNT OF ITS OWN RULE SET.
#
# Three sheets opened with a bare count of their own § A rules, and two siblings already
# carried the repair with its reason. A fourth site was worse: "Two rules keep it honest"
# over FOUR bullets, in shipped prose, false since the sheet was written and false in
# every release. The § A headings are the list; a number written above them is a census
# that goes stale the first time the sheet grows.
#
# THIS ASSERTS THE SHAPE, NOT THE TRUTH, and the difference is the whole design. Grading
# whether a count is CORRECT means deciding which lists are growable — natural-language
# semantics no repository can parse, which this kit's own doctrine says outright. The
# absence of the shape is mechanical, and it is what the siblings already committed to.
#
# SCOPED TO CLASS LINES AND ADOPT LINES, because a wider pattern fires on legitimate
# prose: a single NAMED rule ("One rule that looks like it belongs here and does not"), a
# RATIO ("One check per invariant"), and a historical quote of a count that was removed.
# All three are in the corpus and none is a defect. The uncovered subset is printed on
# green rather than left implied.
# =============================================================================
# =============================================================================
# CASE — THE MOVER LEAVES A DIRTY MAIN CHECKOUT BYTE-IDENTICAL.
#
# A shipped role doc and a shipped skill both told adopters that a loose edit to their
# own checkout "is destroyed" when move-issue.sh runs. It is not: the mover's own
# contract is that the operator's checkout is NEVER switched, it has no dirty-tree
# refusal because the checkout's state is irrelevant to it, and the only `reset --hard`
# in the worktree library is scoped to the kanban worktree. Both sentences were written
# in the initial commit and neither had been touched since.
#
# THE REAL HAZARD IS STRANDING, NOT DESTRUCTION, and it is worth a different warning: the
# move commits a `git mv` on the trunk while the edit sits at the OLD path in a checkout
# the mover deliberately did not fast-forward. Nothing is lost; the next pull collides.
#
# THIS ASSERTS THE EFFECT, which is why it is worth having where a text-match would not
# be: it measures the file's bytes and the checkout's HEAD, not what any document says.
# =============================================================================
# =============================================================================
# CASE — THE AGENT MODEL PINS MATCH WHAT THE KIT DECLARES ABOUT THEM.
#
# Every leaf-worker definition pins a `model:`, and those values are a VENDOR'S PRODUCT
# NAMES — the one class of fact EXTRACTION § 4.10 otherwise keeps out of the kit. They
# are kept on purpose (a plain spawn must be correctly provisioned with no action) and
# are now declared as a carve-out, with one definition named as the deliberate exception.
#
# THIS ASSERTS THE DECLARATION, NEVER THE VALUE, and that is the whole design. A case
# that asserted a worker is pinned to a named model would hard-code the very product fact
# this change exists to quarantine — and would redden on the vendor's rename instead of
# catching anything. So it reads the SHAPE: the pins agree except for exactly one file,
# and that file is the one the declaration names.
# =============================================================================
# =============================================================================
# CASE — WHEREVER THE PROVISIONING CEILING IS STATED, THE SEAT RULE IS STATED WITH IT.
#
# The riders used to say "never spawn the seat's own model class" — a PROXY for "do not
# quietly provision a fan-out at the top of the ladder", and a poor one: it caps workers
# by an accident of what the seat happens to be running, so a seat at the top capped
# every worker two tiers below anything anyone had sanctioned. It is retired in favour of
# the project's declared ceiling.
#
# BUT THE BAN WAS CARRYING A SECOND RULE ON ITS BACK at more than half its sites — that
# the seat is human-partnered rather than a provisionable worker — and at seven of the
# thirteen it was the ONLY thing saying so. Retiring the ban there would have removed the
# only binding sentence. An adopter who performed this retirement themselves hit exactly
# that regression, which is why this case exists rather than a note.
#
# SCOPED TO roles/ AND agents/, deliberately: a recursive sweep would match THIS FILE the
# moment the case is written, which is the self-match this harness has been bitten by.
# =============================================================================
# =============================================================================
# CASE — EVERY LEAF-WORKER DEFINITION CARRIES THE SECTIONS ITS SIBLINGS CARRY.
#
# One definition was missing three of them and nothing noticed, because nothing had ever
# compared the set. The sections are not decoration: they are where the quota discipline,
# the output budget and the commit rules live, so a worker missing them is dispatched
# without the constraints its siblings run under.
#
# THE REQUIRED SET IS DERIVED BY MAJORITY, NEVER LISTED. A literal list goes blind the
# day a section is added or renamed, and — measured — three definitions legitimately
# carry a section of their own that no sibling has. Requiring set EQUALITY would redden
# on correct content; requiring the strict majority requires exactly what is shared.
# =============================================================================
# =============================================================================
# CASE — THE TEMPLATE HEADER SURVIVES THE STAMP IT DESCRIBES.
#
# Each card template's header explains two substitutions the initializer performs — and
# it used to SPELL BOTH TOKENS OUT, so kit-init rewrote its own explanation. Measured:
# every initialized adopter tree carried, in all five templates, a sentence reading
# "the initializer stamps BOTH <the trunk value> and <the prefix value> in this
# directory today" — a sentence with no referent, shipped since v0.1.0.
#
# PRESENCE OF THE HEADER IS NOT THE PROPERTY. Readability AFTER the stamp is, and only an
# end-to-end kit-init run can see it — which is why no static check caught this.
# =============================================================================
# =============================================================================
# CASE — EVERY MINTED BOARD CARD PROMPTS FOR ITS NOTES DELIVERABLE.
#
# The rule's own standard is "named, or explicitly dismissed, never absent" — and the one
# template for the case the rule calls out BY NAME (a test-only refactor with no
# shipped-surface delta) had no prompt at all. So the author most likely to owe an
# explicit dismissal was the one never asked for it.
#
# IT ASSERTS THE MINTED CARD, NOT THE TEMPLATE, and that is the point: a creator that
# strips the section would pass a template check and fail this one. The card is what the
# author actually receives.
# =============================================================================
# =============================================================================
# CASE — A FRESHLY MINTED CARD IS DRIFT-CLEAN ON THE FIRST BOARD CHECK.
#
# Three templates told the author that leaving an example as a bullet would make a
# freshly minted card report false drift. Measured 2026-09-03, that was never true in any
# release: the seed entry is the last bullet either way, and the shape lines are
# un-judgeable to the arm. The wording is corrected — but the PROMISE underneath it is
# real and was never asserted: a card nobody has moved yet must not be reported as drift.
#
# THE PROSE IS NOT WHAT IS TESTED. A text-match over the templates would have pinned the
# false mechanism just as happily as the true one; this asserts the board report.
# =============================================================================
# =============================================================================
# CASE — PROJECT.md's CREDENTIAL BLANK STAYS VISIBLE TO THE FILL ARM.
#
# check-board's graduation arm counts unfilled blanks in PROJECT.md with
# `grep -oE '<[a-z][^<>]*>'` — LOWERCASE-INITIAL, no nested angle brackets. The credential
# blank was widened so an adopter whose provider binds privilege to the account has an
# honest answer to write there, and a widening is exactly where that pattern gets broken:
# capitalise the first letter and the blank becomes INVISIBLE, so the arm reports zero
# blanks on an unfilled tree. That is a false green on the one question the adopter most
# needs to answer, and nothing else would notice.
# =============================================================================
case_project_credential_blank_is_countable() {
  cf_reset
  make_sandbox
  # THE REAL SHIPPED TREE, not the sandbox: PROJECT.md is not among the files make_sandbox
  # copies, and a case that SKIPS is not a case that passed.
  local pm="$REAL_REPO_ROOT/PROJECT.md"
  if [ ! -f "$pm" ]; then skp "PROJECT.md's credential blank stays countable" "PROJECT.md absent"; teardown; return; fi

  # INSTRUMENT: the section must be found, or the count below is zero-over-nothing.
  grep -q 'Read vs write separation' "$pm" \
    || _fixture_die "case_project_credential_blank_is_countable: no 'Read vs write separation' line in PROJECT.md — the subject moved and a zero count would read as clean."

  local line n
  line="$(grep -m1 'Read vs write separation' "$pm")"
  n="$(printf '%s\n' "$line" | grep -oE '<[a-z][^<>]*>' | grep -vc '://' || true)"
  [ "${n:-0}" -eq 1 ] \
    || cf "the credential separation line holds ${n:-0} blank(s) the FILL arm can count, want exactly 1 — a capitalised or nested blank is INVISIBLE to that arm, so an adopter graduates without answering it: $line"

  finish "PROJECT.md's read/write separation blank is exactly one blank the graduation FILL arm can count — a widening that capitalises or nests it would make it invisible and graduate an unfilled tree"
  teardown
}

case_minted_card_is_drift_clean() {
  cf_reset
  if ! has_issue_template; then skp "a freshly minted card is drift-clean" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  if [ ! -d "$REAL_REPO_ROOT/.claude/templates" ]; then
    skp "a freshly minted card is drift-clean" ".claude/templates absent"; return
  fi
  make_sandbox
  mkdir -p "$SB_WORK/.claude/templates"
  cp -R "$REAL_REPO_ROOT/.claude/templates/." "$SB_WORK/.claude/templates/"
  _kit_neutral_claude

  local creator base card n=0 i=800 victim=""
  for creator in "$SB_WORK"/scripts/new-*.sh; do
    [ -e "$creator" ] || continue
    base="$(basename "$creator")"; i=$((i+1))
    ( cd "$SB_WORK" && "./scripts/$base" "clean$i" --id "$SB_PREFIX-$i" >/dev/null 2>&1 ) || true
    card="$SB_WORK/progress/todo/$SB_PREFIX-$i-clean$i.md"
    [ -f "$card" ] || continue
    n=$((n+1)); [ -z "$victim" ] && victim="$card"
  done
  [ "$n" -ge 3 ] \
    || _fixture_die "case_minted_card_is_drift_clean: only $n card(s) minted — the board would be checked over nothing."
  publish_sandbox

  local out rc=0
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc (exit 0 ALWAYS)"
  # INSTRUMENT: arm [a] must have walked a column. "nothing found" over an absent board
  # is the vacuous pass this arm's own header warns about.
  printf '%s\n' "$out" | grep -q 'no active column exists' \
    && cf "(instrument) arm [a] found no active column — the assertion below is vacuous"
  printf '%s\n' "$out" | grep -q 'last Activity declares' \
    && cf "a FRESHLY MINTED card reports folder-vs-Activity drift — the templates promise the adopter's first board check is clean: $out"

  # ── ABLATION: the arm must be able to SEE these cards, or the green above is empty.
  #    Rewrite one card's seed bullet to declare a folder it is not in.
  grep -q '^- .*`todo/`' "$victim" \
    || _fixture_die "case_minted_card_is_drift_clean: the seed bullet's shape moved — the plant cannot take and the ablation would prove nothing."
  perl -i -pe 's/`todo\/`/`dev_complete`/ if /^- /' "$victim"
  grep -q '`dev_complete`' "$victim" || _fixture_die "case_minted_card_is_drift_clean: the plant did not take."
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | grep -q 'last Activity declares' \
    || cf "(ablation) arm [a] did NOT report a card whose last Activity declares a folder it is not in — the clean result above establishes nothing"

  finish "a freshly minted card is drift-clean on the first board check across $n creator(s), and the arm demonstrably sees these cards (ablation-proven)"
  teardown
}

case_minted_card_prompts_for_notes() {
  cf_reset
  if ! has_issue_template; then skp "every minted board card prompts for its notes deliverable" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  if [ ! -d "$REAL_REPO_ROOT/.claude/templates" ]; then
    skp "every minted board card prompts for its notes deliverable" ".claude/templates absent"; return
  fi
  make_sandbox
  mkdir -p "$SB_WORK/.claude/templates"
  cp -R "$REAL_REPO_ROOT/.claude/templates/." "$SB_WORK/.claude/templates/"
  _kit_neutral_claude
  publish_sandbox

  local creator base out card n=0 i=700
  for creator in "$SB_WORK"/scripts/new-*.sh; do
    [ -e "$creator" ] || continue
    base="$(basename "$creator")"
    i=$((i+1))
    # SLUG AND --id ONLY. Every board creator accepts exactly that, and passing a flag
    # one of them does not know now exits 2 (the CLI shape contract) — so a "helpful"
    # extra flag makes every creator refuse and the loop measures nothing. It did.
    out="$( cd "$SB_WORK" && "./scripts/$base" "probe$i" --id "$SB_PREFIX-$i" 2>&1 )" || true
    # THE PATH IS CONSTRUCTED, not parsed out of the output — the creators do not all
    # print the same "Created:" line, and an output parse that silently matches nothing
    # turns this loop into a pass over zero cards.
    card="$SB_WORK/progress/todo/$SB_PREFIX-$i-probe$i.md"
    # BOARD CARDS ONLY: new-prd.sh writes a requirements document, not a board card, so
    # it mints nothing here and drops out by shape rather than by a name in a list.
    [ -f "$card" ] || continue
    n=$((n+1))
    grep -qi 'notes deliverable' "$card" \
      || cf "$base mints a board card with no notes-deliverable prompt — the rule's standard is 'named, or explicitly dismissed, never absent', and this card cannot meet it"
  done

  [ "$n" -ge 3 ] \
    || _fixture_die "case_minted_card_prompts_for_notes: only $n board card(s) were minted — the loop lost its subject and would report PASS over nothing."

  finish "every minted board card prompts for its notes deliverable ($n creator(s) exercised; new-prd.sh is correctly excluded — it writes a requirements document, not a board card)"
  teardown
}

case_template_header_survives_the_stamp() {
  cf_reset
  if ! has_kit_init; then skp "the template header survives the stamp" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "the template header survives the stamp" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  publish_sandbox

  local out rc=0 t base hdr n=0
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)" || rc=$?
  [ "$rc" -eq 0 ] || { cf "kit-init exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"; finish "the template header survives the stamp"; teardown; return; }

  # ── INSTRUMENT CHECK FIRST. Every assertion below is "a token is ABSENT from the
  #    header", which a kit-init that did nothing at all satisfies perfectly.
  grep -q 'SBX-' "$SB_WORK/.claude/templates/ISSUE.template.md" \
    || cf "(instrument) the ISSUE template BODY was not stamped — kit-init did nothing, and every absence asserted below is meaningless"

  for t in "$SB_WORK"/.claude/templates/*.template.md; do
    [ -e "$t" ] || continue
    base="$(basename "$t")"; n=$((n+1))
    hdr="$(awk '/^<!-- KIT-CLASS:/{p=1} p{print} p && /-->/{exit}' "$t")"
    [ -n "$hdr" ] || { cf "$base: no KIT-CLASS header block after init"; continue; }
    # THE STAMPED VALUES MUST NOT APPEAR INSIDE THE EXPLANATION.
    printf '%s\n' "$hdr" | grep -qw 'SBX' \
      && cf "$base: the post-init header names the stamped PREFIX value — kit-init rewrote the sentence that explains kit-init, and the adopter reads a claim with no referent"
    printf '%s\n' "$hdr" | grep -qw "$SB_TRUNK" \
      && cf "$base: the post-init header names the stamped TRUNK value where it should be describing a token"
    # …and the instruction that is still in force survived.
    printf '%s\n' "$hdr" | grep -qi 'never leave' \
      || cf "$base: the post-init header lost its fill instruction"
  done
  [ "$n" -ge 5 ] \
    || cf "only $n template(s) were examined — the glob stopped matching the tree, which is NOT proof the tree is clean"

  finish "the template header survives the stamp: across $n template(s), the post-init KIT-CLASS block names neither stamped value and keeps its fill instruction, while the bodies are demonstrably stamped"
  teardown
}

case_leaf_workers_carry_the_common_sections() {
  cf_reset
  make_sandbox
  local ad="" d
  for d in "$REAL_REPO_ROOT/_claude/agents" "$REAL_REPO_ROOT/.claude/agents"; do [ -d "$d" ] && ad="$d"; done
  if [ -z "$ad" ]; then skp "leaf-worker definitions carry the sections their siblings carry" "no agents/ directory"; teardown; return; fi

  local n f base req missing=""
  n="$(ls "$ad"/*.md 2>/dev/null | wc -l | tr -d ' ')"
  [ "${n:-0}" -ge 5 ] \
    || _fixture_die "case_leaf_workers_carry_the_common_sections: only ${n:-0} definition(s) scanned — a majority over a lost operand finds nothing and passes."

  # Headings, normalised: the parenthetical differs legitimately per hat
  # ("Read order (before judging anything)" vs "(before probing anything)").
  req="$( for f in "$ad"/*.md; do
            [ -e "$f" ] || continue
            sed -n 's/^## //p' "$f" | sed 's/[[:space:]]*(.*)$//'
          done | sort | uniq -c | awk -v t="$n" '$1 * 2 > t { $1=""; sub(/^ /,""); print }' )"
  [ -n "$req" ] \
    || _fixture_die "case_leaf_workers_carry_the_common_sections: the derived required set is EMPTY — a zero-heading majority finds zero misses and reports PASS."

  while IFS= read -r f; do
    [ -n "$f" ] || continue
    base="$(basename "$f")"
    while IFS= read -r h; do
      [ -n "$h" ] || continue
      sed -n 's/^## //p' "$f" | sed 's/[[:space:]]*(.*)$//' | grep -qxF "$h" \
        || missing="$missing
    $base is missing '$h'"
    done <<REQ_EOF
$req
REQ_EOF
  done <<DEFS_EOF
$(ls "$ad"/*.md)
DEFS_EOF

  [ -z "$missing" ] \
    || cf "a leaf-worker definition is missing a section every one of its siblings carries — that is where the quota discipline, the output budget and the commit rules live, so this worker is dispatched without the constraints the others run under:$missing"

  finish "every leaf-worker definition carries the sections a majority of them carry ($n definitions, $(printf '%s' "$req" | grep -c .) derived sections; a hat's own unique section is correctly NOT required)"
  teardown
}

case_provisioning_ceiling_keeps_the_seat_rule() {
  cf_reset
  make_sandbox
  local cd_="" d
  for d in "$REAL_REPO_ROOT/_claude" "$REAL_REPO_ROOT/.claude"; do [ -d "$d" ] && cd_="$d"; done
  if [ -z "$cd_" ]; then skp "the ceiling rule keeps the seat rule beside it" "no _claude/.claude directory"; teardown; return; fi

  local sites f n=0 missing=""
  sites="$( { grep -rl 'sanctioned ceiling' "$cd_/roles" "$cd_/agents" 2>/dev/null || true; } )"
  n="$(printf '%s\n' "$sites" | grep -c . || true)"
  [ "${n:-0}" -ge 5 ] \
    || _fixture_die "case_provisioning_ceiling_keeps_the_seat_rule: only ${n:-0} site(s) state the ceiling — the sweep lost its subject, which is not the same as a clean tree."

  while IFS= read -r f; do
    [ -n "$f" ] || continue
    # THE SEAT RULE, matched on its declared tokens rather than a whole sentence — the
    # wording differs legitimately between a role doc and a worker definition.
    grep -q 'human-partnered' "$f" && grep -q 'provisionable' "$f" \
      || missing="$missing $(basename "$f")"
  done <<SITES_EOF
$sites
SITES_EOF

  [ -z "$missing" ] \
    || cf "these state the provisioning ceiling but no longer state that the seat is human-partnered rather than a provisionable worker —$missing. At most of these sites the retired ban was the ONLY sentence carrying that rule, and an adopter performing this retirement lost it exactly this way."

  finish "every site stating the provisioning ceiling ($n of them) also states the seat rule — the second rule the retired ban was carrying on its back"
  teardown
}

case_agent_model_pins_match_their_declaration() {
  cf_reset
  make_sandbox
  local ad="" d
  for d in "$REAL_REPO_ROOT/_claude/agents" "$REAL_REPO_ROOT/.claude/agents"; do
    [ -d "$d" ] && ad="$d"
  done
  if [ -z "$ad" ]; then skp "agent model pins match their declaration" "no agents/ directory"; teardown; return; fi

  # Derive (file, pin) pairs. The VALUES are compared to each other, never to a literal.
  local pins n f base val minority majority mcount
  pins="$( for f in "$ad"/*.md; do
             [ -e "$f" ] || continue
             val="$(sed -n 's/^model:[[:space:]]*//p' "$f" | head -1)"
             [ -n "$val" ] && printf '%s\t%s\n' "$(basename "$f")" "$val"
           done )"
  n="$(printf '%s\n' "$pins" | grep -c . || true)"
  [ "${n:-0}" -ge 2 ] \
    || _fixture_die "case_agent_model_pins_match_their_declaration: only ${n:-0} pinned definition(s) — the comparison below is vacuous."

  # The majority pin, and the files that differ from it.
  majority="$(printf '%s\n' "$pins" | awk -F'\t' '{c[$2]++} END{m=0; for(v in c) if(c[v]>m){m=c[v]; b=v} print b}')"
  mcount="$(printf '%s\n' "$pins" | awk -F'\t' -v m="$majority" '$2!=m{print $1}' | grep -c . || true)"
  minority="$(printf '%s\n' "$pins" | awk -F'\t' -v m="$majority" '$2!=m{print $1}')"

  # THE DECLARATION must exist and must name the exception BY FILE.
  local ex="$REAL_REPO_ROOT/process/EXTRACTION.md"
  [ -f "$ex" ] || { skp "agent model pins match their declaration" "process/EXTRACTION.md absent"; teardown; return; }
  grep -q 'THE MODEL PINS ARE PRODUCT NAMES' "$ex" \
    || cf "the kit ships vendor product names in its agent frontmatter and declares that nowhere — EXTRACTION § 4.10 excludes exactly this class, so an undeclared pin is indistinguishable from an oversight"

  if [ "${mcount:-0}" -eq 0 ]; then
    grep -q 'ui-designer-worker.md' "$ex" \
      && cf "every definition now carries the SAME pin, but the declaration still names an exception — the table describes a tree that no longer exists"
  else
    [ "${mcount}" -eq 1 ] \
      || cf "$mcount definitions differ from the majority pin ($(printf '%s' "$minority" | tr '\n' ' ')), and the declaration describes exactly ONE deliberate exception — a new divergent pin is undeclared"
    grep -qF "$minority" "$ex" \
      || cf "the definition that differs from the rest ($minority) is NOT the one the declaration names as the exception — either the pin moved or the table did"
  fi

  # THE VALUES MUST NOT BE WRITTEN INTO THE DECLARATION, which is what keeps it from
  # going stale on the vendor's schedule.
  printf '%s\n' "$pins" | awk -F'\t' '{print $2}' | sort -u | while IFS= read -r val; do
    [ -n "$val" ] || continue
    grep -qF -- "$val" "$ex" \
      && echo "LEAK:$val"
  done | grep -q '^LEAK:' \
    && cf "the declaration WRITES a pin's value — a second copy of a vendor product name, in the document that exists to say the copy is a debt. Derive them instead."

  finish "the agent model pins match their declaration: $n pinned definition(s), exactly ${mcount:-0} deliberate exception named by file, and no pin VALUE is copied into the declaration"
  teardown
}

case_move_issue_leaves_a_dirty_checkout_alone() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-101" strand chore "Stranding probe"
  publish_sandbox

  local card="$SB_WORK/progress/todo/$SB_PREFIX-101-strand.md" before_hash before_head out rc=0
  [ -f "$card" ] \
    || _fixture_die "case_move_issue_leaves_a_dirty_checkout_alone: the seeded card is not in the checkout — there is nothing to leave alone."
  printf '\nan uncommitted edit the operator has not saved anywhere else\n' >> "$card"
  before_hash="$(shasum "$card" | awk '{print $1}')"
  before_head="$(git -C "$SB_WORK" rev-parse HEAD)"
  [ -n "$before_hash" ] && [ -n "$before_head" ] \
    || _fixture_die "case_move_issue_leaves_a_dirty_checkout_alone: could not record the pre-state."
  # INSTRUMENT: the checkout must actually BE dirty, or the assertions below hold trivially.
  [ -n "$(git -C "$SB_WORK" status --porcelain -- "progress/todo/$SB_PREFIX-101-strand.md")" ] \
    || _fixture_die "case_move_issue_leaves_a_dirty_checkout_alone: the edit did not register as dirty — every assertion below would pass over a clean tree."

  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-101" in_progress \
            --role Dev --note "moved while the checkout is dirty" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "the mover failed with a dirty main checkout (rc=$rc) — its contract says that state is irrelevant to it: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # THE MOVE LANDED — otherwise "nothing was touched" is satisfied by a mover that did nothing.
  origin_has_path "progress/in_progress/$SB_PREFIX-101-strand.md" \
    || cf "the card did not reach in_progress/ on the trunk — the mover did not run, so the assertions below prove nothing"

  # …AND THE OPERATOR'S FILE IS UNTOUCHED, byte for byte.
  [ -f "$card" ] \
    || cf "the operator's uncommitted file was REMOVED from their checkout — the mover's contract is that it never touches it"
  [ "$(shasum "$card" 2>/dev/null | awk '{print $1}')" = "$before_hash" ] \
    || cf "the operator's uncommitted edit was MODIFIED — 'destroyed' is what two shipped documents claimed, and this case exists because it is not true"
  [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$before_head" ] \
    || cf "the main checkout's HEAD moved — the mover fast-forwarded a checkout it promises never to switch"

  finish "move-issue.sh leaves a dirty main checkout byte-identical — the file, its bytes and HEAD all survive a move that lands on the trunk (the hazard is stranding at the old path, not destruction)"
  teardown
}

case_doctrine_states_no_rule_count() {
  cf_reset
  make_sandbox
  local dd="$REAL_REPO_ROOT/process/doctrine"
  if [ ! -d "$dd" ]; then skp "no doctrine sheet writes a count of its own rule set" "process/doctrine/ absent"; teardown; return; fi

  local n; n="$(ls "$dd"/*.md 2>/dev/null | wc -l | tr -d ' ')"
  [ "${n:-0}" -ge 2 ] \
    || _fixture_die "case_doctrine_states_no_rule_count: only ${n:-0} doctrine sheet(s) scanned — the operand was lost, which is not the same as a clean corpus."

  local pat='^\*\*KIT-CLASS.*\b(one|two|three|four|five|six|seven|eight|nine|ten) (rules?|points?|checks?|invariants?)\b|^\*\*How to adopt:\*\*.*\b(one|two|three|four|five|six|seven|eight|nine|ten) (rules?|points?)\b'

  # INSTRUMENT: the pattern must MATCH a known-bad line, or every green below is vacuous.
  printf '%s\n' '**KIT-CLASS: KIT.** Seven rules for the case where your project is not the end of the line:' > "$SB_TMP/known-bad.md"
  grep -qiE "$pat" "$SB_TMP/known-bad.md" \
    || _fixture_die "case_doctrine_states_no_rule_count: the pattern does not match a known-bad line, so it would report a clean corpus whatever the sheets said."

  local bad
  bad="$( { grep -rniE "$pat" "$dd" 2>/dev/null || true; } )"
  [ -z "$bad" ] \
    || cf "a doctrine sheet writes a count of its own rule set — the § A headings ARE the list, and the sheets that already carry this repair say why: $(printf '%s' "$bad" | tr '\n' '|')"

  finish "no doctrine sheet's class line or adopt line writes a count of its own rule set ($n sheets scanned; MID-SECTION introducers like 'What keeps it honest:' are NOT covered by this pattern — a wider one fires on a named single rule and on a ratio, both legitimate and both present)"
  teardown
}

case_cli_shape_across_the_shipped_set() {
  cf_reset
  make_sandbox
  publish_sandbox

  # THE EXEMPTIONS CARRY THEIR REASON AND ASSERT THEIR OWN EXISTENCE — an exemption
  # naming a file that is not there is coverage shrinking silently.
  local e
  for e in config.sh notify-hook.sh; do
    [ -f "$SB_WORK/scripts/$e" ] \
      || _fixture_die "case_cli_shape_across_the_shipped_set: the exemption list names scripts/$e, which is not in the sandbox — the exemption is stale and coverage shrank without anything failing."
  done

  local f base out rc n=0
  for f in "$SB_WORK"/scripts/*.sh; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    case "$base" in
      config.sh) continue ;;        # a sourced seam, not a CLI — it has no main
      notify-hook.sh) continue ;;   # a stdin hook; exit 0 always, by its own design
    esac
    n=$((n+1))

    out="$( cd "$SB_WORK" && "$f" --help </dev/null 2>&1 )"; rc=$?
    [ "$rc" -eq 0 ] || cf "$base --help exited $rc — a usage request must ALWAYS succeed (§ 3)"
    # NAMING ITSELF IS THE EFFECT ASSERTION. An rc-only check passes vacuously on a tool
    # that has no --help arm at all and simply does its job: that is exactly how
    # next-id.sh answered a usage request with a mintable id and looked fine.
    printf '%s\n' "$out" | grep -qF "$base" \
      || cf "$base --help exited 0 but its output never names $base — this is satisfied by a tool with no usage handler that just ran: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

    out="$( cd "$SB_WORK" && "$f" --not-a-real-flag </dev/null 2>&1 )"; rc=$?
    [ "$rc" -eq 2 ] \
      || cf "$base: an unrecognised option exited $rc, want 2 — § 3 names ONE status across the shipped set: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
    printf '%s\n' "$out" | grep -qF -- '--not-a-real-flag' \
      || cf "$base: the refusal does not NAME the option it refused (§ 3), so the caller cannot tell which flag was wrong: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  done

  [ "$n" -gt 0 ] \
    || _fixture_die "case_cli_shape_across_the_shipped_set: the glob matched no script at all — the case would report PASS over an empty set."

  # ── TWO TARGETED PROBES, because the generic one above CANNOT REACH THESE PATHS and a
  #    mutation test proved it: reverting either fix left the sweep green.
  #
  #    notify.sh dispatches on its first argument as a CLASS, so `--not-a-real-flag`
  #    alone is refused by the class arm and the OPTION LOOP is never entered. That loop
  #    is where a stray flag used to be warned about and IGNORED — the message delivered,
  #    exit 0. A refusal that reads as success needs a probe that gets that far.
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/notify.sh" done "a message" --session s --not-a-real-flag </dev/null 2>&1 )"; rc=$?
  [ "$rc" -eq 2 ] \
    || cf "notify.sh: a stray option AFTER a valid class exited $rc, want 2 — it is being ignored and the notification is delivered anyway, which is a refusal that reads as success: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  #    move-issue.sh takes positionals, so a dash-leading token is caught BEFORE the
  #    option loop or it becomes the issue id and dies on the arity check instead —
  #    refused with the status a MISSING ARGUMENT gets, never naming the flag.
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" --not-a-real-flag in_progress --role Dev </dev/null 2>&1 )"; rc=$?
  [ "$rc" -eq 2 ] \
    || cf "move-issue.sh: a dash-leading FIRST token exited $rc, want 2 — it was taken as the issue id rather than refused as an option: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  printf '%s\n' "$out" | grep -qF -- '--not-a-real-flag' \
    || cf "move-issue.sh: the refusal does not name the dash-leading token it refused: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # ── INSTRUMENT CHECK. Both probes above must be capable of FAILING. A script with no
  #    argument handling whatsoever must fail both — written OUTSIDE scripts/ so the
  #    glob above cannot pick it up and turn the control into a subject.
  local probe="$SB_TMP/no-handlers.sh"
  printf '#!/usr/bin/env bash\necho ok\n' > "$probe"; chmod +x "$probe"
  out="$( "$probe" --help </dev/null 2>&1 )"
  printf '%s\n' "$out" | grep -qF 'no-handlers.sh' \
    && cf "(control) the --help probe PASSED a script with no usage handler — it is measuring nothing"
  out="$( "$probe" --not-a-real-flag </dev/null 2>&1 )"; rc=$?
  [ "$rc" -eq 2 ] \
    && cf "(control) the refusal probe PASSED a script with no argument handling — it is measuring nothing"

  finish "the CLI shape across the shipped set (DERIVED from the sandbox, not listed): every tool's usage request exits 0 and names the tool, and every unrecognised option exits 2 and names the option — asserted over $n tools with two exemptions that assert their own existence"
  teardown
}

# =============================================================================
# CASE — GATES (e) AND (f) SEE THE STATE THE DOCUMENTED WORKFLOW ACTUALLY PRODUCES.
#
# Gate (e) asserted a HEADING EXISTS and said nothing about the section under it, so a
# `## [X.Y.Z]` over a placeholder cut a release whose notes said nothing — and the
# preflight then reported the section PRESENT, which a reader takes as the notes being
# in order.
#
# Gate (f) is worse in a more interesting way. It refuses a header date EARLIER than a
# date in its own body — but NOTHING IN THE KIT EVER WRITES THAT DATE. The cutter types
# it or does not, and a header with no date is not "earlier than" anything, so the
# comparison was skipped and the section cleared. **A gate that refuses the state nobody
# reaches and passes the state everybody reaches is not a gate**, and its own fixture
# could not construct the failing input.
#
# BOTH LEGS ASSERT THE CUT IS UNMUTATED, because a refusal that already wrote something
# is the defect these gates exist to prevent.
# =============================================================================
# =============================================================================
# CASE — GATE (c) TEACHES THE SHAPE THAT ACTUALLY RUNS.
#
# The worked example in the config block was a bare command. Two things were wrong
# with that and both are invisible until you try it:
#
#   1. Gate (c) runs a record with a DELIBERATE WORD-SPLIT and no `eval`, so an inline
#      `sh -c '…'` is torn into separate words before anything executes. Only a command
#      and its arguments work — which means a wrapper SCRIPT.
#   2. A gate has THREE outcomes, not two: passed, failed, and COULD NOT RUN. A bare
#      command in a project without the canary's environment gives a false green or a
#      hard failure that blocks a legitimate offline cut. The third state has to be
#      said out loud, and the wrapper is the only place there is to say it.
#
# BOTH LEGS ASSERT AN EFFECT — that the skip reaches the operator, and that the shape
# the example does NOT teach genuinely fails — never the comment's wording.
# =============================================================================
case_release_gate_c_skip_shape() {
  cf_reset
  if ! has_release; then skp "release.sh gate (c): the taught wrapper shape" "scripts/release.sh absent"; return; fi
  local out rc=0

  # --- (i) THE TAUGHT SHAPE: a wrapper script that self-skips loudly and exits 0. ---
  make_sandbox; seed_release_files 1.1.0
  printf '#!/usr/bin/env bash\nif [ -z "${CANARY_TOKEN:-}" ]; then\n  echo "SKIP: live read-canary — CANARY_TOKEN unset; the canary did not run."\n  exit 0\nfi\nexit 0\n' \
    > "$SB_WORK/canary"; chmod +x "$SB_WORK/canary"
  rel_insert PREFLIGHT_GATES '"live read-canary|./canary"'
  publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean

  rc=0; out="$(run_release 1.1.0 --dry-run)" || rc=$?
  [ "$rc" -eq 0 ] || cf "(skip) a self-skipping gate ABORTED the cut (rc=$rc) — the third state must not read as a failure: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  printf '%s\n' "$out" | grep -q 'SKIP: live read-canary' \
    || cf "(skip) the gate's third state never reached the operator — a canary that could not run passed SILENTLY, which is the false green this example exists to teach against: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # INSTRUMENT: the needle must DISCRIMINATE. If it also matches a run where the canary
  # DID run, leg (i) proves nothing.
  rc=0
  out="$( cd "$SB_WORK" && CANARY_TOKEN=x RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=true \
            RELEASE_BOARD_CMD="$SB_TMP/board-clean.sh" "$SB_WORK/scripts/release.sh" 1.1.0 --dry-run 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(ran) the canary with its credential PRESENT aborted the cut (rc=$rc)"
  printf '%s\n' "$out" | grep -q 'SKIP: live read-canary' \
    && cf "(instrument) the SKIP needle matched a run where the canary DID run — leg (i) is not measuring the skip"
  teardown

  # --- (ii) WHY THE EXAMPLE MUST BE A SCRIPT: gate (c) word-splits, it does not eval. --
  make_sandbox; seed_release_files 1.1.0
  # THE RECORD'S QUOTING IS WHAT IS BEING TESTED. `sh -c 'exit 1'` word-splits into
  # [sh] [-c] ['exit] [1'] — sh then runs `'exit`, which is not a command, so the gate
  # fails BECAUSE the quotes did not survive. Deliberately references no variable:
  # release.sh runs `set -u`, and an unset one aborts the script before gate (c) can
  # refuse, which measures the wrong thing. (It did, on the first run of this case.)
  rel_insert PREFLIGHT_GATES "\"inline canary|sh -c 'exit 1'\""
  publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  rc=0; out="$(run_release 1.1.0 --dry-run)" || rc=$?
  [ "$rc" -ne 0 ] \
    || cf "(inline) an inline-shell gate record RAN — gate (c) is eval-ing its records, so the worked example may no longer need to teach the script shape, and this case's premise is gone"
  printf '%s\n' "$out" | grep -q 'inline canary' \
    || cf "(inline) the refusal does not name the gate that failed: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  assert_release_unmutated 1.1.0
  teardown

  finish "release.sh gate (c): a wrapper-script gate self-skips LOUDLY without aborting the cut (needle proven discriminating), and an inline-shell record does NOT run — which is why the worked example teaches a script"
}

case_release_notes_section_is_more_than_a_heading() {
  cf_reset
  if ! has_release; then skp "release.sh gates (e)/(f): the section, not just its heading" "scripts/release.sh absent"; return; fi
  local out rc

  # --- (i) A HEADING OVER A PLACEHOLDER — gate (e). --------------------------
  make_sandbox; seed_release_files 1.1.0; publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  # The kit's own blanks convention is <angle brackets>, so the placeholder is
  # recognised BY SHAPE rather than by a word list somebody has to keep current.
  printf '# Release notes\n\n## [1.1.0] — 2026-07-24\n\n<what changed, for the consumer>\n\n## [1.0.0] — 2026-07-23\nseed\n' > "$SB_WORK/NOTES.md"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[Dev] a heading with nothing under it" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  rc=0; out="$(run_release 1.1.0)" || rc=$?
  [ "$rc" -ne 0 ] || cf "(e) a release cut with a notes section holding only a placeholder"
  printf '%s\n' "$out" | grep -q 'EMPTY' \
    || cf "(e) the refusal does not say the section is empty: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  printf '%s\n' "$out" | grep -q 'NOTES.md' \
    || cf "(e) the refusal does not name WHICH document is empty: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  assert_release_unmutated 1.1.0

  # INSTRUMENT / ABLATION: the same cut with real content must SUCCEED, or the refusal
  # above is satisfiable by a release.sh broken for any unrelated reason.
  printf '# Release notes\n\n## [1.1.0] — 2026-07-24\nsomething a consumer can read\n\n## [1.0.0] — 2026-07-23\nseed\n' > "$SB_WORK/NOTES.md"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[Dev] write the notes" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  rc=0; out="$(run_release 1.1.0)" || rc=$?
  [ "$rc" -eq 0 ] || cf "(e) ABLATION FAILED — the cut still refused once the section had real content, so the refusal above was not about emptiness: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  teardown

  # --- (ii) A HEADING WITH NO DATE — gate (f), the state the workflow produces.
  make_sandbox; seed_release_files 1.1.0; publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  printf '# Release notes\n\n## [1.1.0]\nreal content, measured 2026-07-24\n\n## [1.0.0] — 2026-07-23\nseed\n' > "$SB_WORK/NOTES.md"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[Dev] a dateless heading" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  rc=0; out="$(run_release 1.1.0)" || rc=$?
  [ "$rc" -ne 0 ] || cf "(f) a release cut from a section whose heading carries NO DATE — the state the documented workflow produces, since nothing in the kit writes that date"
  printf '%s\n' "$out" | grep -q 'NO DATE' \
    || cf "(f) the refusal does not say the date is missing: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  printf '%s\n' "$out" | grep -q 'nothing in the kit writes that date for you' \
    || cf "(f) the refusal does not tell the cutter that no tool will write it — without that they look for the tool that failed: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  assert_release_unmutated 1.1.0

  # INSTRUMENT: add the date and the SAME cut must succeed.
  printf '# Release notes\n\n## [1.1.0] — 2026-07-25\nreal content, measured 2026-07-24\n\n## [1.0.0] — 2026-07-23\nseed\n' > "$SB_WORK/NOTES.md"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[Dev] date it" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  rc=0; out="$(run_release 1.1.0)" || rc=$?
  [ "$rc" -eq 0 ] || cf "(f) ABLATION FAILED — the cut still refused once the heading carried a date: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  teardown

  finish "release.sh gates (e)/(f): a heading over a placeholder is refused naming the document, a heading with NO DATE is refused and says no tool will write it, and both cuts succeed once the section is real (ablation-proven both ways)"
}

case_release_behind_the_remote() {
  cf_reset
  if ! has_release; then skp "release.sh gate (a): HEAD vs the remote tip" "scripts/release.sh absent"; return; fi
  local out rc

  # --- (control) the premise exists, AND a non-fetching reader cannot see it ---
  make_sandbox; seed_release_files 1.1.0; publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  echo "landed after this checkout" > "$SB_WORK/LATER.txt"
  git -C "$SB_WORK" add LATER.txt >/dev/null 2>&1
  sbcommit -qm "[Dev] a commit that lands after the cutter's last pull" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" reset -q --hard HEAD~1
  git -C "$SB_WORK" update-ref "refs/remotes/origin/$SB_TRUNK" "$(git -C "$SB_WORK" rev-parse HEAD)"

  [ -z "$(git -C "$SB_WORK" status --porcelain)" ] \
    || cf "(control) the tree is dirty — gate (a)'s SECOND check would refuse and this case would prove nothing"
  [ "$(git -C "$SB_WORK" symbolic-ref --short HEAD)" = "$SB_TRUNK" ] \
    || cf "(control) not on the trunk — gate (a)'s FIRST check would refuse first"
  [ "$(git -C "$SB_WORK" rev-list --count "HEAD..refs/remotes/origin/$SB_TRUNK" 2>/dev/null)" = "0" ] \
    || cf "(control) the tracking ref was NOT rewound — a non-fetching implementation would already see the gap, so this case cannot tell a real fetch from a stale read"
  [ "$(git -C "$SB_WORK" ls-remote origin "refs/heads/$SB_TRUNK" | awk '{print $1}')" \
      != "$(git -C "$SB_WORK" rev-parse HEAD)" ] \
    || cf "(control) the remote is NOT actually ahead — the premise does not exist"

  # --- (i) it refuses, names the DIRECTION and the way past, mutates nothing ---
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(i) a cut from a BEHIND checkout was allowed (rc=0)"
  printf '%s\n' "$out" | grep -q 'BEHIND' \
    || cf "(i) the refusal does not name the direction: $out"
  printf '%s\n' "$out" | grep -q -- 'git pull --ff-only' \
    || cf "(i) the refusal does not name the way past: $out"
  assert_release_unmutated 1.1.0

  # --- (ii) ABLATION: catch up and the SAME cut succeeds, naming the FULL tree -
  git -C "$SB_WORK" fetch -q origin "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" merge -q --ff-only FETCH_HEAD >/dev/null 2>&1
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(ii) ABLATION FAILED — still refused after catching up, so half (i) proves nothing: $out"
  git -C "$SB_WORK" cat-file -e "v1.1.0:LATER.txt" 2>/dev/null \
    || cf "(ii) the tag does not contain the commit that landed after the checkout — the gate refused for the wrong reason"
  teardown

  # --- (iii) A FAILED FETCH REFUSES, as a fact about the remote ----------------
  make_sandbox; seed_release_files 1.1.0; publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  git -C "$SB_WORK" remote set-url origin "$SB_TMP/gone.git" >/dev/null 2>&1
  git -C "$SB_WORK" fetch origin "$SB_TRUNK" >/dev/null 2>&1 \
    && cf "(control/iii) the broken remote is still fetchable — the failed-fetch leg measures nothing"
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(iii) a failed fetch did not refuse — the arm degrades silently, which is the class it exists to close"
  printf '%s\n' "$out" | grep -q -- '--no-fetch' \
    || cf "(iii) the refusal does not name the declared-offline escape: $out"
  printf '%s\n' "$out" | grep -q 'NOT ABOUT YOUR TREE' \
    || cf "(iii) the refusal does not attribute itself to the remote rather than the tree: $out"
  assert_release_unmutated 1.1.0

  # --- (iv) --no-fetch DECLARES the skip: gates green, and it SAYS SO ----------
  out="$(run_release 1.1.0 --no-fetch --dry-run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(iv) --no-fetch did not survive an unreachable remote (rc=$rc): $out"
  printf '%s\n' "$out" | grep -q 'NOT CONSULTED' \
    || cf "(iv) --no-fetch is SILENT — an undeclared skip is indistinguishable from a gate that ran: $out"
  assert_release_unmutated 1.1.0
  teardown

  # --- (v) THE LEGITIMATE OFFLINE CUT: a LOCAL BARE origin, NO flag ------------
  make_sandbox; seed_release_files 1.1.0; publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  case "$(git -C "$SB_WORK" remote get-url origin)" in
    http*|git@*|ssh:*|git:*) cf "(control/v) the sandbox origin is not a local path — this leg does not prove the offline case" ;;
  esac
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(v) an IN-SYNC cut against a LOCAL BARE origin was refused (rc=$rc) — the arm turned the kit's own day-one topology into a refusal: $out"
  teardown

  finish "release.sh gate (a): a clean trunk BEHIND the remote refuses naming the direction and the way past — tracking ref rewound, so only a REAL fetch can see it — and cuts once caught up (ablation: the tag contains the later commit); a FAILED fetch refuses naming --no-fetch and blames the remote not the tree; --no-fetch declares the skip loudly; an in-sync cut against a local bare origin is untouched"
}

case_release_happy() {
  cf_reset
  if ! has_release; then skp "release.sh happy path" "scripts/release.sh absent"; return; fi
  local out rc v
  for v in 1.1.0 v1.1.0; do
    make_sandbox
    seed_release_files 1.1.0
    publish_sandbox
    write_board_stub "$SB_TMP/board-clean.sh" clean
    out="$(run_release "$v")"; rc=$?
    [ "$rc" -eq 0 ] || cf "release.sh $v exited $rc (expected 0): $out"
    grep -qx '1.1.0' "$SB_WORK/VERSION" || cf "$v: the bare-form version file was not bumped"
    grep -q 'version = "1.1.0"' "$SB_WORK/pkg.conf" || cf "$v: the quoted-form version file was not bumped"
    [ "$(git -C "$SB_WORK" cat-file -t v1.1.0 2>/dev/null)" = "tag" ] \
      || cf "$v: v1.1.0 is not an ANNOTATED tag (expected a 'tag' object)"
    [ -n "$(git -C "$SB_WORK" ls-remote --tags origin v1.1.0 2>/dev/null)" ] \
      || cf "$v: the tag was not pushed to the remote"
    origin_file_contains "VERSION" '1.1.0' || cf "$v: the bump did not reach the trunk"
    origin_log_has_subject '^\[' || cf "$v: the release commit carries no [Role] prefix"
    teardown
  done
  finish "release.sh happy path: preflight → bump every declared version file (bare + quoted) → annotated tag pushed (X.Y.Z and vX.Y.Z)"
}

case_release_guards() {
  cf_reset
  if ! has_release; then skp "release.sh guards" "scripts/release.sh absent"; return; fi
  local out rc

  # (a) malformed target
  make_sandbox; seed_release_files 1.1.0; publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$(run_release 1.1)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(malformed) expected nonzero for '1.1', got 0"
  assert_release_unmutated 1.1.0   # (malformed) — all four arms, not just VERSION
  teardown

  # (b) the tag already exists
  make_sandbox; seed_release_files 1.1.0; publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  git -C "$SB_WORK" tag -a v1.1.0 -m "pre-existing" >/dev/null 2>&1
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(tag-exists) expected nonzero when v1.1.0 already exists, got 0"
  # (tag-exists) THIS LEG PRE-CREATES v1.1.0 ITSELF, so the tag arm cannot distinguish
  # its own fixture from a tag release.sh created. The other three arms still apply and
  # are what this leg takes; the tag arm is the one deliberately not taken here.
  grep -qx "$SB_REL_PRE_VERSION" "$SB_WORK/VERSION" || cf "(tag-exists) VERSION was mutated"
  grep -qF "version = \"$SB_REL_PRE_VERSION\"" "$SB_WORK/pkg.conf" || cf "(tag-exists) pkg.conf was mutated"
  origin_file_contains "VERSION" "$SB_REL_PRE_VERSION" || cf "(tag-exists) a bump reached the remote"
  teardown

  # (c) off-trunk
  make_sandbox; seed_release_files 1.1.0; publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  git -C "$SB_WORK" checkout -b feature/off-trunk "$SB_TRUNK" --quiet >/dev/null 2>&1
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(off-trunk) expected nonzero on a feature branch, got 0"
  assert_release_unmutated 1.1.0
  teardown

  # (d) dirty working tree
  make_sandbox; seed_release_files 1.1.0; publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  echo "dirty" > "$SB_WORK/DIRTY.txt"
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(dirty) expected nonzero on a dirty tree, got 0"
  assert_release_unmutated 1.1.0   # (dirty) — all four arms, not just VERSION
  teardown

  # (e) NO version files declared and VERSION_IN_TAG_ONLY unset → refuse. Tagging
  #     a commit whose declared version nobody moved is a silent lie.
  make_sandbox
  printf '1.0.0\n' > "$SB_WORK/VERSION"
  rel_insert RELEASE_DOCS '"CHANGELOG.md|the log"'
  seed_release_doc "$SB_WORK/CHANGELOG.md" "Changelog" 1.1.0
  publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(no-version-files) an undeclared version seam did not refuse"
  printf '%s' "$out" | grep -q 'VERSION_FILES' || cf "(no-version-files) the refusal does not name the seam: $out"
  teardown

  finish "release.sh guards: malformed / tag-exists / off-trunk / dirty / undeclared-version-seam all abort nonzero without mutating"
}

case_release_preflight_gates() {
  cf_reset
  if ! has_release; then skp "release.sh preflight gates" "scripts/release.sh absent"; return; fi
  local out rc

  # (b) verify.sh red
  make_sandbox; seed_release_files 1.1.0; publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$( cd "$SB_WORK" && RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=false RELEASE_BOARD_CMD="$SB_TMP/board-clean.sh" \
            "$SB_WORK/scripts/release.sh" 1.1.0 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(verify-red) expected nonzero, got 0"
  assert_release_unmutated 1.1.0
  teardown

  # (c) a DECLARED extra preflight gate, red
  make_sandbox; seed_release_files 1.1.0
  # Sandbox-local, for the portability reason the gate fixtures state: an absolute
  # system path that is absent returns 127, and 127 is UNRUNNABLE here, not FAIL.
  printf '#!/usr/bin/env bash\nexit 1\n' > "$SB_WORK/red-gate"; chmod +x "$SB_WORK/red-gate"
  rel_insert PREFLIGHT_GATES '"declared extra gate|./red-gate"'
  publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(extra-gate-red) a red declared gate did not abort the cut"
  printf '%s' "$out" | grep -q 'declared extra gate' \
    || cf "(extra-gate-red) the refusal does not name the gate that failed: $out"
  assert_release_unmutated 1.1.0
  teardown

  # (d) board drift
  make_sandbox; seed_release_files 1.1.0; publish_sandbox; write_board_stub "$SB_TMP/board-drift.sh" drift
  out="$( cd "$SB_WORK" && RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=true RELEASE_BOARD_CMD="$SB_TMP/board-drift.sh" \
            "$SB_WORK/scripts/release.sh" 1.1.0 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(board-drift) expected nonzero, got 0"
  assert_release_unmutated 1.1.0
  teardown

  finish "release.sh preflight gates: verify red / a declared extra gate red / board drift each abort nonzero before mutation"
}

# =============================================================================
# CASE — the release-document arms are INDEPENDENT, with DISTINCT refusals, and
# the header-date gate bites. A consumer-facing notes file that nothing enforces
# stops being maintained by the second release; and a section header dated BEFORE
# the work inside it shipped once for a whole arc, because a header promise is
# only as good as whoever re-reads it.
# =============================================================================
case_release_doc_arms() {
  cf_reset
  if ! has_release; then skp "release.sh document arms" "scripts/release.sh absent"; return; fi
  local out rc first_line second_line

  # (1) doc2 documented, doc1 NOT → doc1's arm bites alone, naming only doc1.
  make_sandbox; seed_release_files none 1.1.0; publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(doc1-missing) expected nonzero with only doc2 documented, got 0"
  first_line="$(release_refusal_line "$out")"
  printf '%s' "$first_line" | grep -q 'CHANGELOG\.md' \
    || cf "(doc1-missing) the refusal does not name CHANGELOG.md: $first_line"
  printf '%s' "$first_line" | grep -q 'NOTES\.md' \
    && cf "(doc1-missing) the refusal names the OTHER document — the arms are conflated: $first_line"
  assert_release_unmutated 1.1.0
  # BOTH missing → exactly ONE refusal, from the first-declared arm (fail-fast).
  seed_release_doc "$SB_WORK/NOTES.md" "Release notes" none
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[Dev] drop the second doc section" >/dev/null 2>&1
  out="$(run_release 1.1.0)"; rc=$?
  local count; count="$(printf '%s\n' "$out" | grep -c '^release\.sh:')"
  [ "$count" -eq 1 ] || cf "(both-missing) expected 1 refusal line, got $count"
  teardown

  # (2) doc1 documented, doc2 NOT → RED, naming doc2 and the version; then GREEN
  #     when only doc2's section is restored (nothing else changes).
  make_sandbox; seed_release_files 1.1.0 none; publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(doc2-missing) expected nonzero — the second arm does not bite"
  second_line="$(release_refusal_line "$out")"
  printf '%s' "$second_line" | grep -q 'NOTES\.md' || cf "(doc2-missing) the refusal does not name NOTES.md: $second_line"
  printf '%s' "$second_line" | grep -q '1\.1\.0' || cf "(doc2-missing) the refusal does not name the version wanted: $second_line"
  [ "$first_line" != "$second_line" ] \
    || cf "(distinctness) both arms emit the SAME refusal: $second_line"
  assert_release_unmutated 1.1.0
  seed_release_doc "$SB_WORK/NOTES.md" "Release notes" 1.1.0
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[Dev] add the consumer-facing section" >/dev/null 2>&1
  # PUSHED, and not as tidiness: gate (a) requires HEAD to BE the published trunk's
  # tip, so the pre-cut section commit has to reach the remote before the cut. That is
  # not a new rule this fixture is bending to — check-board [f1] already sets drift=1
  # on an ahead trunk and gate (d) refuses on it, so a STOCK kit has always refused
  # this cut. The fixture only got away with it by stubbing the board clean.
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(doc2-restored) the cut still aborted after restoring the section: $out"
  grep -qx '1.1.0' "$SB_WORK/VERSION" || cf "(doc2-restored) restoring the section did not unblock the cut"
  teardown

  # (3) the HEADER-DATE gate: a section dated BEFORE the newest date in its own
  #     body is refused, naming both dates and the file.
  make_sandbox; seed_release_files 1.1.0 1.1.0
  seed_release_doc "$SB_WORK/NOTES.md" "Release notes" 1.1.0 2026-09-30   # body date AFTER the header
  publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(header-date) a section dated before its own content was accepted"
  printf '%s' "$out" | grep -q '2026-09-30' || cf "(header-date) the refusal does not name the newest body date: $out"
  printf '%s' "$out" | grep -q 'NOTES\.md' || cf "(header-date) the refusal does not name the file: $out"
  printf '%s' "$out" | grep -qi "CUTTER" || cf "(header-date) the refusal does not state whose date it is: $out"
  assert_release_unmutated 1.1.0
  # …and correcting the HEADER (never the measurement) unblocks it.
  perl -i -pe 's/^## \[1\.1\.0\] — 2026-07-24$/## [1.1.0] — 2026-09-30/' "$SB_WORK/NOTES.md"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[Dev] date the section at the cut" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1   # gate (a) wants the published tip; see the note above
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(header-date) correcting the header did not unblock the cut: $out"
  teardown

  finish "release.sh document arms: independent, distinctly worded, one refusal on both-missing, and the header-date gate bites and clears"
}

# =============================================================================
# CASE — THE DISTRIBUTION BRANCH: the allowlist, ONE orphan commit, built AT THE
# TAG, a second publish REPLACES it, a dry run publishes NOTHING, and a publish
# failure leaves the release AUTHORITATIVE with a retry that exists.
# =============================================================================
write_build_stub() {  # <path>
  cat > "$1" <<'STUB'
#!/usr/bin/env bash
# A stand-in for a real build: the last arg is the output directory, and the
# artifact's CONTENT is derived from the tree being built — so a build at a
# different commit produces different bytes, which is what makes the
# byte-identity comparison meaningful rather than a tautology.
set -eu
outdir="${!#}"
mkdir -p "$outdir"
ver="$(head -1 ./VERSION)"
[ -n "$ver" ] || { echo "build stub: no VERSION in $(pwd)" >&2; exit 1; }
{
  echo "ARTIFACT sandbox $ver"
  echo "notes-marker: $(sed -n '3p' ./NOTES.md 2>/dev/null || echo none)"
} > "$outdir/sandbox-${ver}.pkg"
STUB
  chmod +x "$1"
}
enable_publish() {
  rel_set 'RELEASE_PUBLISH=false' 'RELEASE_PUBLISH=true'
  rel_set 'DIST_ARTIFACT_GLOB=' 'DIST_ARTIFACT_GLOB="sandbox-*.pkg"'
  rel_insert DIST_DOCS '"NOTES.md|sandbox-NOTES.md"'
}
run_release_publish() {  # <version> [extra args…]
  ( cd "$SB_WORK" && RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=true \
      RELEASE_BOARD_CMD="$SB_TMP/board-clean.sh" \
      RELEASE_BUILD_CMD="$SB_TMP/build-stub.sh" \
      "$SB_WORK/scripts/release.sh" "$@" 2>&1 )
}
dist_files()        { git -C "$SB_ORIGIN" ls-tree -r --name-only refs/heads/dist 2>/dev/null | sort; }
dist_commit_count() { git -C "$SB_ORIGIN" rev-list --count refs/heads/dist 2>/dev/null || echo 0; }

case_release_publish() {
  cf_reset
  if ! has_release; then skp "release.sh distribution branch" "scripts/release.sh absent"; return; fi
  local out rc files

  make_sandbox
  seed_release_files 1.1.0
  enable_publish
  publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  write_build_stub "$SB_TMP/build-stub.sh"

  # A DRY RUN publishes NOTHING…
  out="$(run_release_publish 1.1.0 --dry-run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "the dry run exited $rc (expected 0): $out"
  [ -z "$(git -C "$SB_ORIGIN" rev-parse -q --verify refs/heads/dist 2>/dev/null)" ] \
    || cf "a DRY RUN created the dist branch on the remote"
  printf '%s' "$out" | grep -q 'publish: building' && cf "a DRY RUN ran the build step: $out"
  assert_release_unmutated 1.1.0

  # …then a real run publishes everything ("nothing, then everything", so the dry-run
  # assertion cannot pass by the publish being broken outright).
  out="$(run_release_publish 1.1.0)"; rc=$?
  [ "$rc" -eq 0 ] || cf "the cut exited $rc (expected 0): $out"
  [ -n "$(git -C "$SB_WORK" ls-remote --tags origin v1.1.0 2>/dev/null)" ] \
    || cf "the tag was not pushed — the publish must come AFTER the tag push"
  printf '%s' "$out" | grep -q 'clone --branch dist --depth 1' \
    || cf "the run never printed the consumer clone line: $out"
  # THE ALLOWLIST, exactly.
  files="$(dist_files)"
  [ "$files" = "$(printf '%s\n' README.md sandbox-1.1.0.pkg sandbox-NOTES.md | sort)" ] \
    || cf "dist carries the wrong file set: $(printf '%s' "$files" | tr '\n' ' ')"
  printf '%s\n' "$files" | grep -qE '^(scripts/|progress/|pkg\.conf|VERSION)$' \
    && cf "dist carries repo material it must never carry: $files"
  # BUILT AT THE TAG: the artifact's name carries the TAGGED version, which exists
  # only in the tag's tree, and it is byte-identical to a fresh build there.
  local a b
  a="$SB_TMP/from-dist.pkg"
  git -C "$SB_ORIGIN" show "refs/heads/dist:sandbox-1.1.0.pkg" > "$a" 2>/dev/null \
    || cf "could not read the published artifact off dist"
  grep -q 'ARTIFACT sandbox 1.1.0' "$a" || cf "the published artifact was not built at the tagged version"
  mkdir -p "$SB_TMP/tagbuild"
  git -C "$SB_WORK" worktree add --detach --quiet "$SB_TMP/tagtree" refs/tags/v1.1.0 2>/dev/null
  ( cd "$SB_TMP/tagtree" && "$SB_TMP/build-stub.sh" "$SB_TMP/tagbuild" ) >/dev/null 2>&1
  b="$SB_TMP/tagbuild/sandbox-1.1.0.pkg"
  if [ -f "$b" ]; then
    cmp -s "$a" "$b" || cf "the artifact on dist is NOT byte-identical to a build at the same tag"
  else
    cf "the control build at the tag produced nothing"
  fi
  git -C "$SB_WORK" worktree remove --force "$SB_TMP/tagtree" >/dev/null 2>&1 || true
  # REPLACE: exactly one commit, and no shared history with the trunk.
  [ "$(dist_commit_count)" = "1" ] || cf "dist has $(dist_commit_count) commits — the policy is ONE (replace)"
  git -C "$SB_ORIGIN" merge-base refs/heads/dist "refs/heads/$SB_TRUNK" >/dev/null 2>&1 \
    && cf "dist shares history with the trunk — it must be an ORPHAN"

  # A SECOND publish replaces it: still one commit, new artifact, OLD ONE GONE.
  seed_release_doc "$SB_WORK/CHANGELOG.md" "Changelog" 1.2.0
  seed_release_doc "$SB_WORK/NOTES.md"     "Release notes" 1.2.0
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[Dev] document 1.2.0" >/dev/null 2>&1
  # PUSHED, and not as tidiness: gate (a) requires HEAD to BE the published trunk's
  # tip, so the pre-cut section commit has to reach the remote before the cut. That is
  # not a new rule this fixture is bending to — check-board [f1] already sets drift=1
  # on an ahead trunk and gate (d) refuses on it, so a STOCK kit has always refused
  # this cut. The fixture only got away with it by stubbing the board clean.
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  out="$(run_release_publish 1.2.0)"; rc=$?
  [ "$rc" -eq 0 ] || cf "the second cut exited $rc: $out"
  [ "$(dist_commit_count)" = "1" ] || cf "after a second publish dist has $(dist_commit_count) commits — replace means ONE"
  files="$(dist_files)"
  printf '%s\n' "$files" | grep -q 'sandbox-1.2.0.pkg' || cf "the second publish did not put the new artifact on dist"
  printf '%s\n' "$files" | grep -q 'sandbox-1.1.0.pkg' && cf "the OLD artifact is still on dist — replace must not accumulate"
  teardown

  finish "release.sh dist branch: dry run publishes nothing, the real run publishes the allowlist exactly as ONE orphan commit built AT the tag (byte-identical), and a second publish REPLACES it"
}

case_release_publish_recovery() {
  cf_reset
  if ! has_release; then skp "release.sh publish failure + recovery" "scripts/release.sh absent"; return; fi
  local out rc before after

  make_sandbox
  seed_release_files 1.1.0
  enable_publish
  publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  # A build stub that FAILS: the publish cannot produce an artifact, so it must
  # fail AFTER the tag push has already succeeded.
  printf '#!/usr/bin/env bash\nexit 1\n' > "$SB_TMP/build-stub.sh"; chmod +x "$SB_TMP/build-stub.sh"

  out="$(run_release_publish 1.1.0)"; rc=$?
  # The release is AUTHORITATIVE and intact.
  [ "$(git -C "$SB_WORK" cat-file -t v1.1.0 2>/dev/null)" = "tag" ] \
    || cf "the annotated tag was rolled back by a publish failure — it must never be"
  [ -n "$(git -C "$SB_WORK" ls-remote --tags origin v1.1.0 2>/dev/null)" ] \
    || cf "the tag is not on the remote after a publish failure"
  origin_file_contains "VERSION" '1.1.0' || cf "the version bump is missing from the trunk after a publish failure"
  [ -z "$(git -C "$SB_ORIGIN" rev-parse -q --verify refs/heads/dist 2>/dev/null)" ] \
    || cf "a failed publish left a dist branch behind"
  printf '%s' "$out" | grep -qi 'RELEASE ITSELF SUCCEEDED' \
    || cf "the failure message does not say the release succeeded: $out"
  printf '%s' "$out" | grep -q -- '--publish-only' || cf "the failure message names no retry command: $out"

  # The retry it names has to EXIST — a message pointing at a flag the script
  # lacks would be the dangling-pointer defect in its most expensive place.
  out="$( cd "$SB_WORK" && RELEASE_BUILD_CMD="$SB_TMP/build-stub.sh" \
            "$SB_WORK/scripts/release.sh" 1.1.0 --publish-only 2>&1 )"; rc=$?
  printf '%s' "$out" | grep -qi "unknown option" && cf "--publish-only is advertised but not implemented: $out"
  [ "$rc" -ne 0 ] || cf "--publish-only reported success with a failing build stub: $out"

  # Make the build work; the retry republishes.
  write_build_stub "$SB_TMP/build-stub.sh"
  out="$( cd "$SB_WORK" && RELEASE_BUILD_CMD="$SB_TMP/build-stub.sh" \
            "$SB_WORK/scripts/release.sh" 1.1.0 --publish-only 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "--publish-only failed on an already-cut tag: $out"
  [ -n "$(git -C "$SB_ORIGIN" rev-parse -q --verify refs/heads/dist 2>/dev/null)" ] \
    || cf "--publish-only did not publish the dist branch"
  [ "$(dist_commit_count)" = "1" ] || cf "--publish-only produced $(dist_commit_count) commits"

  # --publish-only --dry-run PUSHES NOTHING. THE UNCOVERED CELL: --dry-run alone
  # was proven and --publish-only alone was proven, never the two TOGETHER — and
  # the handler sits ABOVE the dry-run stop point on purpose, so it structurally
  # cannot reach it. A run the operator believed was a rehearsal force-pushed the
  # branch; since --publish-only takes a VERSION, that could roll dist BACK to an
  # older artifact while reporting a rehearsal. The assertion is the dist COMMIT
  # HASH, not mere existence: in the interesting scenario the branch already
  # exists, so an existence check passes vacuously.
  before="$(git -C "$SB_ORIGIN" rev-parse -q --verify refs/heads/dist 2>/dev/null)"
  printf 'echo "build-marker: ROUND2" >> "$outdir/sandbox-${ver}.pkg"\n' >> "$SB_TMP/build-stub.sh"
  out="$( cd "$SB_WORK" && RELEASE_BUILD_CMD="$SB_TMP/build-stub.sh" \
            "$SB_WORK/scripts/release.sh" 1.1.0 --publish-only --dry-run 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(publish-only dry run) exited $rc: $out"
  after="$(git -C "$SB_ORIGIN" rev-parse -q --verify refs/heads/dist 2>/dev/null)"
  [ "$before" = "$after" ] || cf "(publish-only dry run) the dist ref MOVED during a rehearsal"
  git -C "$SB_ORIGIN" show "refs/heads/dist:sandbox-1.1.0.pkg" 2>/dev/null | grep -q 'ROUND2' \
    && cf "(publish-only dry run) the rehearsal republished the artifact"
  # The anti-vacuity control: a REAL --publish-only on the same sandbox moves it.
  out="$( cd "$SB_WORK" && RELEASE_BUILD_CMD="$SB_TMP/build-stub.sh" \
            "$SB_WORK/scripts/release.sh" 1.1.0 --publish-only 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(control) the real --publish-only exited $rc: $out"
  git -C "$SB_ORIGIN" show "refs/heads/dist:sandbox-1.1.0.pkg" 2>/dev/null | grep -q 'ROUND2' \
    || cf "(control) a real --publish-only did NOT republish — the rehearsal assertion proves nothing"
  teardown

  finish "release.sh publish failure: tag intact + on the remote, no half-published branch, the named --publish-only retry exists and works, and --publish-only --dry-run pushes NOTHING (ref hash unchanged, control-proven)"
}

# =============================================================================
# CASE — the LOCAL-ONLY state is printed as NORMAL output BEFORE the pushes, and
# every command it prints WORKS. `doctrine/fix-execution.md` § A.7 and
# `contracts/release-ritual.md` § 2: a run killed between the tag and the pushes
# never reaches the failure branches that carry this same recovery text, BECAUSE
# NOTHING FAILED — and the two lines above it assert a release commit and an
# annotated tag without saying LOCAL, so the dead transcript reads as a cut
# release.
#
# ARM (2) IS THE ONE THAT MATTERS: the commands are EXTRACTED FROM THE TRANSCRIPT
# and executed. Recovery text that drifts out of date fails this case instead of
# reading fine — a dangling pointer in recovery text is the same defect as a
# refusal naming a flag the script does not have.
# =============================================================================
case_release_local_only_recovery() {
  cf_reset
  if ! has_release; then skp "release.sh local-only recovery" "scripts/release.sh absent"; return; fi
  local out rc pos_block pos_push c undo

  # (1) The healthy path prints it, and prints it BEFORE the pushes — and the DRY
  #     RUN does not, because a dry run makes nothing local to recover.
  make_sandbox; seed_release_files 1.1.0; publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$(run_release 1.1.0 --dry-run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(dry-run) exited $rc (expected 0): $out"
  printf '%s\n' "$out" | grep -q 'LOCAL ONLY' \
    && cf "(dry-run) printed the local-only recovery, but a dry run makes nothing local: $out"
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(healthy) exited $rc (expected 0): $out"
  printf '%s\n' "$out" | grep -q 'LOCAL ONLY' \
    || cf "(healthy) no local-only state printed between the tag and the pushes: $out"
  pos_block="$(printf '%s\n' "$out" | grep -n 'LOCAL ONLY' | head -1 | cut -d: -f1)"
  pos_push="$(printf '%s\n' "$out" | grep -n 'pushing commit + tag' | head -1 | cut -d: -f1)"
  { [ -n "$pos_block" ] && [ -n "$pos_push" ] && [ "$pos_block" -lt "$pos_push" ]; } \
    || cf "(healthy) the state is not printed BEFORE the push (state=$pos_block push=$pos_push): $out"
  teardown

  # (2) KILL the run between the local acts and the pushes — planted COMMITTED, so
  #     the clean-tree preflight still passes and a legitimate cut is what dies —
  #     then run the commands the transcript printed, VERBATIM.
  make_sandbox; seed_release_files 1.1.0; rel_plant_midrun_kill; publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -eq 143 ] || cf "(killed) the planted mid-run kill did not fire (exit $rc): $out"
  # The state the transcript CLAIMS must be the state on disk, or the text is a lie
  # that happens to be reassuring.
  [ "$(git -C "$SB_WORK" cat-file -t v1.1.0 2>/dev/null)" = "tag" ] \
    || cf "(killed) no local annotated tag — the recovery text's premise is false"
  [ -z "$(git -C "$SB_WORK" ls-remote --tags origin v1.1.0 2>/dev/null)" ] \
    || cf "(killed) the tag reached the remote before the pushes"
  origin_file_contains "VERSION" '1.1.0' \
    && cf "(killed) the bump reached the remote before the pushes"
  pos_block=0
  while IFS= read -r c; do
    [ -z "$c" ] && continue
    pos_block=$(( pos_block + 1 ))
    ( cd "$SB_WORK" && sh -c "$c" ) >/dev/null 2>&1 \
      || cf "(killed) a printed recovery command failed: $c"
  done < <(printf '%s\n' "$out" | sed -n 's|^ *\(git push .*\)$|\1|p')
  [ "$pos_block" -ge 2 ] \
    || cf "(killed) the printed recovery names $pos_block push command(s), expected the commit's and the tag's: $out"
  origin_file_contains "VERSION" '1.1.0' \
    || cf "(recovered) the printed commands did not put the bump on the trunk"
  [ -n "$(git -C "$SB_WORK" ls-remote --tags origin v1.1.0 2>/dev/null)" ] \
    || cf "(recovered) the printed commands did not push the tag"
  # The block's own warning: re-running the script is NOT one of the safe moves.
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(re-run) the script did not refuse once the tag existed"
  teardown

  # (3) The other half of the printed text — the undo. It is only valid because
  #     nothing has published, which is the fact the block exists to state.
  make_sandbox; seed_release_files 1.1.0; rel_plant_midrun_kill; publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -eq 143 ] || cf "(undo) the planted mid-run kill did not fire (exit $rc): $out"
  undo="$(printf '%s\n' "$out" | sed -n 's|^ *\(git tag -d .*\)$|\1|p' | head -1)"
  [ -n "$undo" ] || cf "(undo) no undo command was printed: $out"
  if [ -n "$undo" ]; then
    ( cd "$SB_WORK" && sh -c "$undo" ) >/dev/null 2>&1 \
      || cf "(undo) the printed undo command failed: $undo"
    # (undo) ONE ARM ON PURPOSE: this leg has already cut a real release, so the tag and
    # the remote SHOULD carry v1.1.0 — the other three arms would be asserting the
    # opposite of what this leg established. What is under test is only that the printed
    # undo restored the version file.
    grep -qx "$SB_REL_PRE_VERSION" "$SB_WORK/VERSION" || cf "(undo) the bump survived the printed undo"
    git -C "$SB_WORK" rev-parse -q --verify refs/tags/v1.1.0 >/dev/null 2>&1 \
      && cf "(undo) the tag survived the printed undo"
    [ -z "$(git -C "$SB_WORK" status --porcelain)" ] \
      || cf "(undo) the printed undo left the tree dirty"
  fi
  teardown

  finish "release.sh local-only recovery: the state + the finishing commands print as normal output BEFORE the pushes (and never on --dry-run), and every command printed — both pushes, the re-run refusal, the undo — does what the text says"
}

# =============================================================================
# CASE — A TEST-ONLY RELAXATION NEEDS ITS TEST-ONLY MARKER.
#
# self-test-harness.md § 2: "a test-only relaxation of a production rule is reachable
# ONLY behind an explicit marker that no production caller sets."
#
# RELEASE_VERIFY_CMD and RELEASE_BOARD_CMD override the two gates that decide whether
# a cut may happen at all. Unmarked, `RELEASE_VERIFY_CMD=true ./scripts/release.sh
# 1.1.0` cut a release with the verify gate silently skipped — not a weaker gate, no
# gate. finish-pr.sh grew exactly this refusal after a fabricated `echo PASS; exit 0`
# stub was used in earnest to force a landing through a red suite; release.sh got the
# same seams and never the marker. **The incident's fix was applied to one sibling and
# not the other**, which is the whole of the finding.
#
# BOTH DIRECTIONS, and the second is the one that keeps the harness itself honest:
#   (i)  unmarked → refuse, before anything is written (no tag, no bump, HEAD still);
#   (ii) marked   → honored, which is what every other release case in this file
#        depends on. If the refusal became unconditional, (i) would still pass and
#        the whole release family would break — so (ii) is asserted here rather than
#        left implicit in cases whose subject is something else.
# =============================================================================
case_release_stub_marker() {
  cf_reset
  if ! has_release; then skp "release.sh: gate-stubbing seams require the test-only marker" "scripts/release.sh absent"; return; fi
  make_sandbox
  seed_release_files 1.1.0
  write_board_stub "$SB_TMP/board-clean.sh" clean
  publish_sandbox

  local out rc before
  before="$(git -C "$SB_WORK" rev-parse HEAD)"

  # --- (i) UNMARKED: each seam alone must be refused, and write nothing -------
  out="$( cd "$SB_WORK" && RELEASE_VERIFY_CMD=true "$SB_WORK/scripts/release.sh" 1.1.0 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(i) RELEASE_VERIFY_CMD was honored with NO marker — an unmarked caller can skip the verify gate on a production cut: $out"
  printf '%s\n' "$out" | grep -q 'RELEASE_TEST_ALLOW_STUB' \
    || cf "(i) the refusal does not name the marker it requires: $out"
  printf '%s\n' "$out" | grep -q 'NOTHING WAS WRITTEN' \
    || cf "(i) the refusal does not state that nothing was written: $out"

  out="$( cd "$SB_WORK" && RELEASE_BOARD_CMD="$SB_TMP/board-clean.sh" "$SB_WORK/scripts/release.sh" 1.1.0 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(i) RELEASE_BOARD_CMD was honored with NO marker — the board-truth gate is stubbable on a production cut: $out"

  # Refused means refused: no tag, no version bump, HEAD unmoved, tree clean.
  [ -z "$(git -C "$SB_WORK" tag -l v1.1.0)" ] || cf "(i) a tag was created during a refusal"
  assert_release_unmutated 1.1.0   # (i) — all four arms, not just VERSION
  grep -qx "$SB_REL_PRE_VERSION" "$SB_WORK/VERSION" || cf "(i) VERSION reads $(cat "$SB_WORK/VERSION")"
  [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$before" ] || cf "(i) HEAD moved during a refusal"
  [ -z "$(git -C "$SB_WORK" status --porcelain)" ] || cf "(i) the tree was modified during a refusal"

  # --- (ii) MARKED: honored, so the refusal has not become unconditional ------
  out="$( cd "$SB_WORK" && RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=true \
            RELEASE_BOARD_CMD="$SB_TMP/board-clean.sh" \
            "$SB_WORK/scripts/release.sh" 1.1.0 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(ii) the MARKED invocation was refused too — the refusal is unconditional and every release case in this file depends on the seam: $out"
  grep -qx '1.1.0' "$SB_WORK/VERSION" || cf "(ii) the marked cut did not bump VERSION: $out"
  [ "$(git -C "$SB_WORK" cat-file -t v1.1.0 2>/dev/null)" = "tag" ] \
    || cf "(ii) the marked cut produced no annotated tag: $out"

  finish "release.sh: RELEASE_VERIFY_CMD / RELEASE_BOARD_CMD are REFUSED without RELEASE_TEST_ALLOW_STUB=1 (no tag, no bump, HEAD still, tree clean) and honored with it"
  teardown
}

case_release_bash_n() {
  cf_reset
  if ! has_release; then skp "release.sh bash -n" "scripts/release.sh absent"; return; fi
  bash -n "$REAL_SCRIPTS/release.sh" 2>/dev/null || cf "bash -n reported a syntax error in scripts/release.sh"
  finish "release.sh: bash -n clean (syntax valid)"
}

# =============================================================================
# CASE — release.sh completes a cut from a repo path CONTAINING A SPACE.
#
# The defect class: the board gate runs "$SCRIPT_DIR/check-board.sh" BY DEFAULT.
# Expanded UNQUOTED — stored in a bare var and run as `$BOARD_CMD` — a repo path
# with a space word-splits, the shell runs the path's FIRST word, the
# 'board-drift: clean' marker is absent, and the cut aborts on EVERY run with a
# FALSE drift. Every other release case passes a space-free stub, so they exercise
# the SET seam and can never see this class. This case drives the DEFAULT gate
# from a spaced path — the only path that reproduces it.
# =============================================================================
case_release_spaced_path() {
  cf_reset
  if ! has_release; then skp "release.sh spaced repo path" "scripts/release.sh absent"; return; fi
  local out rc
  make_sandbox "work dir"
  seed_release_files 1.1.0
  # Pin the DEFAULT board gate deterministically: overwrite the copied
  # check-board.sh (which "$SCRIPT_DIR/check-board.sh" resolves to) with a clean
  # stub, committed via publish so the pre-cut tree stays clean.
  write_board_stub "$SB_WORK/scripts/check-board.sh" clean
  publish_sandbox

  # RELEASE_BOARD_CMD deliberately UNSET → the default path, from a spaced dir.
  out="$( cd "$SB_WORK" && RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=true "$SB_WORK/scripts/release.sh" 1.1.0 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] \
    || cf "release.sh aborted from a spaced repo path (the board gate word-split on the space?): rc=$rc: $out"
  grep -qx '1.1.0' "$SB_WORK/VERSION" || cf "the spaced-path cut did not complete"
  [ "$(git -C "$SB_WORK" cat-file -t v1.1.0 2>/dev/null)" = "tag" ] \
    || cf "no annotated tag from a spaced repo path"

  finish "release.sh completes the cut from a repo path containing a space (the board gate is quoted)"
  teardown
}

# =============================================================================
# CASE — THE CONSUMER-UPDATER FAMILY. It runs only when CONSUMER_SCRIPT names an
# executable: a vendoring/updater script is a DISTRIBUTION MODEL, not a kit
# feature. What the kit asserts is the SHAPE every such script owes
# (process/doctrine/distribution.md): --help exits 0 and says what it does, and a
# --check/dry-run mode reports without mutating. The project's own tests own its
# contents; this only keeps the seam honest.
# =============================================================================
case_consumer_updater() {
  cf_reset
  if [ -z "$CONSUMER_SCRIPT" ]; then
    skp "the consumer-updater family" "CONSUMER_SCRIPT is unset — this project declares no updater script"
    return
  fi
  if [ ! -x "$CONSUMER_SCRIPT" ]; then
    skp "the consumer-updater family" "CONSUMER_SCRIPT='$CONSUMER_SCRIPT' is not an executable"
    return
  fi
  local out rc
  bash -n "$CONSUMER_SCRIPT" 2>/dev/null || cf "bash -n reported a syntax error in $CONSUMER_SCRIPT"
  out="$("$CONSUMER_SCRIPT" --help 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || cf "--help exited $rc (a help flag must succeed)"
  [ -n "$out" ] || cf "--help printed nothing"
  make_sandbox
  publish_sandbox
  local before after
  before="$(git -C "$SB_WORK" rev-parse HEAD)"
  out="$( cd "$SB_WORK" && "$CONSUMER_SCRIPT" --check 2>&1 )" || true
  after="$(git -C "$SB_WORK" rev-parse HEAD)"
  [ "$before" = "$after" ] || cf "--check moved HEAD — a report mode must not mutate"
  [ -z "$(git -C "$SB_WORK" status --porcelain)" ] || cf "--check dirtied the tree — a report mode must not mutate"

  finish "the consumer-updater seam: syntax clean, --help exits 0 with output, --check reports without mutating"
  teardown
}

# =============================================================================
# CASE — EVERY HYGIENE INSTRUMENT DECLARES ITS BLIND SPOTS, AND THE LIST IS NOT EMPTY
#
# THE CLAIM AN EMPTY LIST MAKES. `--json` emits `"blind_spots": [...]`, and a consumer
# reads `[]` as *this walk has no blind spots*. That has never been true of this walker:
# it skips symlinks and it prunes a directory set, and it does both in the very run that
# would print the empty list. **The human path degrades to silence; the machine path
# degrades to a false claim about the subject** — silence is a gap a reader may notice,
# `[]` is an answer they will not question.
#
# WHY ONE CASE COVERS EVERY INSTRUMENT, and why that is the point rather than a saving:
# the notice is derived from ONE authoring site, which is a property worth having — and
# the cost of it is that a single edit empties every consumer AT ONCE. This case is that
# cost's control: the ablation below must redden every instrument simultaneously, and if
# it ever reddens only some, the single authoring site has quietly become several.
#
# PYTHON IS THESE INSTRUMENTS' DECLARED CARVE-OUT, so an absent interpreter SKIPS with
# its reason and never fails — the kit assumes git and a POSIX shell, and these are
# advisory instruments that say so.
#
# PYTHONDONTWRITEBYTECODE, because a run that leaves __pycache__ behind mutates the tree
# it was measuring, and the isolation case would then report the harness as the mutator.
#
# --root IS PASSED EXPLICITLY, and that is not belt-and-braces. These instruments default
# their root to `Path(__file__).resolve().parents[2]` — the tree is inferred from where
# the FILE SITS, not from what is being measured. The ablation copy below deliberately
# sits somewhere else, and at that depth the default resolves to the whole scratch area:
# measured, a copy two directories shallower walked /private/tmp and had to be killed.
# Naming the root makes the operand a fact of the invocation instead of an accident of
# the path, and it is the difference between this case measuring the sandbox and this
# case hanging the suite.
# =============================================================================
case_hygiene_instruments_declare_blind_spots() {
  cf_reset
  if ! command -v python3 >/dev/null 2>&1; then
    skp "hygiene instruments declare their blind spots" "python3 absent — these are advisory instruments and Python is their declared carve-out"
    return
  fi
  make_sandbox
  seed_issue todo "$SB_PREFIX-310" hygiene chore "Hygiene blind-spot probe"
  publish_sandbox   # cold_signal reads git history, so the sandbox must have some

  local hy="$SB_WORK/scripts/hygiene" inst n_inst=0 empty="" missing="" broke=""
  if [ ! -d "$hy" ]; then
    skp "hygiene instruments declare their blind spots" "scripts/hygiene/ absent — this kit ships no advisory instruments"
    teardown; return
  fi

  # THE LIST IS DERIVED, never typed: a new instrument is covered the day it lands.
  local instruments; instruments="$(cd "$hy" && ls ./*.py 2>/dev/null | sed 's@^\./@@' | sort)"
  [ -n "$instruments" ] \
    || _fixture_die "case_hygiene_instruments_declare_blind_spots: scripts/hygiene/ contains no *.py — the scan lost its operand rather than finding a clean set."

  for inst in $instruments; do
    n_inst=$(( n_inst + 1 ))
    local out rc
    out="$( cd "$SB_WORK" && PYTHONDONTWRITEBYTECODE=1 python3 "$hy/$inst" --root "$SB_WORK" --json 2>&1 )"; rc=$?
    if [ "$rc" -ne 0 ]; then broke="$broke $inst"; continue; fi
    # The payload is an object, and it CARRIES the key — a missing key is a different
    # defect from an empty one and must not be reported as the same thing.
    if ! printf '%s' "$out" | PYTHONDONTWRITEBYTECODE=1 python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if isinstance(d,dict) and "blind_spots" in d else 1)' 2>/dev/null; then
      missing="$missing $inst"; continue
    fi
    printf '%s' "$out" | PYTHONDONTWRITEBYTECODE=1 python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin)["blind_spots"] else 1)' 2>/dev/null \
      || empty="$empty $inst"
  done

  # WORDED FOR WHAT IT CATCHES, not for what was first imagined. This bucket was written
  # as "could not be read", which is now a FALSE sentence about the case it actually fires
  # on: measured with the walker ablated, every instrument exited non-zero while
  # emitting a clean, parseable JSON refusal. The payload was readable. What makes it
  # unusable here is that a refusal is not a blind-spot REPORT, and no declaration can be
  # read out of one — so the exit code, not the readability, is the whole of the finding.
  [ -z "$broke" ]   || cf "instrument(s) exited non-zero under --json:$broke — the payload may be perfectly readable; a non-zero exit makes it a REFUSAL rather than a blind-spot report, and a declaration cannot be read out of a refusal"
  [ -z "$missing" ] || cf "instrument(s) emitted a payload with no 'blind_spots' key:$missing — a missing key is not an empty list, and removing the key would turn a false claim into a missing one"
  [ -z "$empty" ]   || cf "instrument(s) reported \"blind_spots\": [] :$empty — that asserts THERE ARE NONE, and this walker skips symlinks and prunes a directory set in the very run that printed it"

  # ── THE ABLATION, on a COPY of the tree the instruments read — never the real one.
  # THE SINGLE-AUTHORING-SITE DERIVATION is what is under test here: one site means one
  # edit reaches every consumer, so the ablation must reach ALL of them, not some.
  local probe="$SB_TMP/hygiene-probe"; rm -rf "$probe"; mkdir -p "$probe"
  cp -R "$hy" "$probe/hygiene" 2>/dev/null
  local site="$probe/hygiene/citation_index.py"
  if [ ! -f "$site" ]; then
    _control_did_not_run "copy the derivation's authoring site"
  else
    # EMPTY THE DERIVATION, DO NOT BYPASS IT. Inserting `return []` at the top of the
    # function skips the refusal that an empty derivation is supposed to raise — so the
    # instruments went back to printing an empty list and NONE of them refused, which
    # this case then correctly reported as "0 of 5". The ablation has to leave the
    # emptiness check reachable and give it nothing to find.
    perl -0777 -i -pe 's{\n    lines = \[}{\n    lines = []\n    _ablated_unused = [}' "$site"
    if ! grep -qF '_ablated_unused' "$site"; then
      cf "(control) the ablation did not take on the copy — the anchor moved, so nothing below establishes that the assertion can fire"
    else
      # EVERY DERIVED INSTRUMENT LANDS IN EXACTLY ONE BUCKET, AND THE BUCKETS ARE
      # RECONCILED AGAINST THE COUNT. This loop used to `|| continue` on a non-zero exit,
      # which silently dropped that instrument from both buckets — so with one probe copy
      # made to fail, the case reported "empties all of them at once" over four of five
      # and stayed green. A control with a hole in its accounting is a green that could
      # not go red, inside the control written against exactly that.
      #
      # THE FLAT SIGNAL IS A REFUSAL, NOT AN EMPTY LIST. An empty derivation is the
      # INSTRUMENT failing, so it exits 2 and emits an object whose only top-level key is
      # the unrunnable one — the UNRUNNABLE vocabulary, not the report's. `blind_spots:
      # []` is a payload that can no longer occur, and an arm still hunting it would pass
      # by never finding what it was looking for.
      #
      # A CRASH IS ITS OWN BUCKET, named in its own word: a traceback or an unparseable
      # payload is neither a refusal nor a healthy report, and folding it into either
      # would let the loudest failure mode read as one of the quiet ones.
      local flat=0 still=0 crashed=0 a_out a_rc
      local still_names="" crash_names=""
      for inst in $instruments; do
        a_out="$( cd "$SB_WORK" && PYTHONDONTWRITEBYTECODE=1 python3 "$probe/hygiene/$inst" --root "$SB_WORK" --json 2>/dev/null )"; a_rc=$?
        if ! printf '%s' "$a_out" | PYTHONDONTWRITEBYTECODE=1 python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
          crashed=$(( crashed + 1 )); crash_names="$crash_names $inst"
        elif [ "$a_rc" -eq 2 ] && printf '%s' "$a_out" | PYTHONDONTWRITEBYTECODE=1 python3 -c 'import json,sys
d = json.load(sys.stdin)
sys.exit(0 if isinstance(d, dict) and list(d) == ["unrunnable"] else 1)' 2>/dev/null; then
          flat=$(( flat + 1 ))
        else
          still=$(( still + 1 )); still_names="$still_names $inst"
        fi
      done

      # THE RECONCILIATION, and it is the assertion the old loop lacked entirely.
      [ $(( flat + still + crashed )) -eq "$n_inst" ] \
        || cf "(control) the ablation accounted for $(( flat + still + crashed )) instrument(s) of $n_inst — some landed in no bucket at all, so any claim below is about a subset nobody enumerated"
      [ "$crashed" -eq 0 ] \
        || cf "(control) ablating the derivation made instrument(s) CRASH rather than refuse:$crash_names — a traceback is the instrument failing in the wrong vocabulary, which is a different defect from the one this case asserts"
      [ "$flat" -gt 0 ] \
        || cf "(control) ablating the derivation made NO instrument refuse — the assertion above cannot fire and is a green that could not go red"
      # NAME THE INSTRUMENTS THAT DID NOT GO FLAT. A count tells the maintainer that the
      # single authoring site has split; only the names tell them which file drifted, and
      # that is the whole of what they need next.
      [ "$still" -eq 0 ] \
        || cf "(control) ablating the single authoring site did not reach:$still_names ($flat of $n_inst refused) — the derivation is no longer one site, which is the property this case exists to protect"
    fi
  fi

  finish "every hygiene instrument declares its blind spots and the list is NON-EMPTY ($n_inst instrument(s): $(printf '%s' "$instruments" | tr '\n' ' ')) — an empty list asserts THERE ARE NONE, which is a false claim about the subject — and ablating the single derivation empties all of them at once"
  teardown
}

# =============================================================================
# CASE — SHIP STATE. The control the neutralizer costs us.
#
# Why this case has to exist. Before _kit_neutral_config, every sandbox inherited
# the real scripts/ verbatim, so the whole suite was an incidental — and
# unstated — witness to the SHIPPED defaults: if this repository had ever declared
# a gate or set RELEASE_PUBLISH=true, cases would have started behaving
# differently and someone would eventually have noticed. Neutralizing deliberately
# destroys that coupling, which is the point; it also destroys the witness. After
# it, every green rests on the harness's OWN assignment of the neutral values, and
# a kit that shipped `RELEASE_PUBLISH=true` would sail through a fully green run.
# A SHIPPED DEFAULT IS ITSELF A SHIPPABLE DEFECT, and this is the only case that
# looks at it. Same argument as the belt-tooling rule one level down: a fixture cannot certify the
# thing it overwrites.
#
# It reads the REAL files and mutates nothing.
#
# WHY IT SKIPS RATHER THAN FAILS ON A CONFIGURED TREE. "The frame ships empty" is
# a claim about the KIT, not about an adopter — a project that has filled its gate
# table has done exactly what it was told to. So the case states its subject and
# steps aside when the tree is not the shipped frame, naming the signal that told
# it so. A SKIP here is a statement about the environment, never a hidden failure.
# =============================================================================
# =============================================================================
# CASE — A REFORMAT OF A DERIVED SEAM DECLARATION IS REFUSED LOUDLY, NEVER ABSORBED.
#
# Four names are parsed out of two files by nine anchored expressions in five files.
# The shape those expressions assume was an undeclared contract between files that never
# mention each other, until config-seam.md § 2 wrote it down.
#
# THE MUTATION HERE IS SEMANTICS-PRESERVING, AND THAT IS THE ENTIRE POINT. Dropping the
# outer double quotes from `NAME="${NAME:-v}"` is identical to the shell — an assignment
# RHS is not word-split — and invisible to every anchored sed. So the value keeps working
# while every derivation of it silently returns nothing. A case that changed the VALUE
# would be testing the value; this one tests the SHAPE, which is the thing that can break
# without looking broken.
#
# case_ship_state guards the same shape by exact-line comparison, but it SKIPS on an
# adopted tree — precisely where adopters live. This case does not skip.
# =============================================================================
# =============================================================================
# CASE — THE COPY-LIST MINIMUM IS A REAL MINIMUM, AND IT IS DERIVED, NOT RETYPED.
#
# THIS CASE EXISTS BECAUSE OF A DECLINE. It was asked whether this preflight should
# check the whole manifest instead of a hand-typed minimum, and the answer was no: the
# manifest is prose in process/EXTRACTION.md, process/contracts/initializer.md § 1
# forbids the initializer carrying a second copy of it, and a machine-readable manifest
# is a new shipped artifact bought for one preflight. What a decline owes is a control
# proving the thing KEPT actually works — otherwise "the minimum is enough" is an
# assertion, and the wider promise was withdrawn on the strength of it.
#
# The list is DERIVED out of the shipped script. A retyped copy here would be the exact
# second-hand-typed-list the decline promised not to create, and it would go stale in the
# one direction that matters: a file added to COPY_LIST and not to this case is a file
# nobody checks.
# =============================================================================
# =============================================================================
# CASE — THE SCAFFOLDING SENTINEL HAS THREE AUTHORS AND THEY MUST AGREE.
#
# The mark is written by two shipped root documents, looked for by check-board.sh's
# graduation arm, and seeded by this harness. Single-sourcing the FIXTURE (one
# seed_scaffolding_tree instead of five re-typed pairs) does not make those three agree —
# it only means a disagreement now shows up once instead of five times. This case is what
# actually holds them together.
#
# WHY NOT JUST DERIVE THE FIXTURE FROM check-board.sh: because then the fixture and the
# tool agree BY CONSTRUCTION, and a rename in the shipped documents — the thing an adopter
# deletes, the only place the mark is user-visible — would go unnoticed while every
# graduation case stayed green. The fixture derives from the DOCUMENTS; this case is what
# reaches the probe.
# =============================================================================
# =============================================================================
# CASE — EVERY ANCHORED FIXTURE APPEND HAS A DECLARED AUTHOR.
#
# Two anchor families live in this file: the array fence `NAME=(` and the function-body
# fence `name() {`. Each is a four-step idiom — assert the anchor, plant, assert it
# landed, and for a sourced library `bash -n` — and the four steps are exactly what a
# copier drops. Measured when this was written: four call sites had re-typed the plant
# with no anchor assertion at all, and one of the two library plants omitted the parse
# check, which is the step that tells "the plant changed the behaviour" apart from "the
# library no longer loads".
#
# THE CENSUS IS THE CONTROL. Consolidating the four helpers did not stop the fifth copy
# from being typed; this case does. A helper nobody is required to call is a convention,
# and this file's own history is that conventions here get re-typed.
#
# THIS CASE SCANS THE FILE IT LIVES IN, so it is inside its own operand set. The two
# match strings are held in separate variables on separate lines and comment lines are
# skipped — otherwise the derivation reddens on its own source and on the comment above.
# =============================================================================
# =============================================================================
# CASE — assert_release_unmutated NAMES THE CUT IT IS GUARDING.
#
# The helper's tag arm used to look for the literal `refs/tags/v1.1.0`. Its call sites
# call it, and while all fourteen happen to cut 1.1.0 today, the coupling is invisible:
# a leg cutting any other version got a tag check looking for a tag nobody would create,
# which passes. Of the helper's four arms the tag arm guards the most expensive mutation
# and was the only one that could be satisfied by looking in the wrong place.
#
# THE MUTATION IS A TAG AND NOTHING ELSE. No bump, no push. Every other arm stays clean,
# so a green here can only come from the arm under test.
# =============================================================================
# =============================================================================
# CASE — VICTIM SELECTION SURVIVES PIPEFAIL.
#
# Four control blocks picked their victim with `find … | head -1`, which is the exact
# shape this file's own header forbids by name: the reader exits early, `find` takes
# SIGPIPE, and `pipefail` promotes the producer's death to the pipeline's status. The
# value is still correct — that is what makes it invisible — but the STATUS is wrong, and
# a caller that ever tested the status would read "no victim" on a probe full of victims.
#
# HONEST FRAMING: measured on this machine, the raw pipeline first fails around 300 files
# and the kit's largest real corpus here is 20. This is a threshold nobody has crossed,
# fixed for consistency with the header the three origin_* helpers were already rewritten
# for — not a live bug. The case is built so it cannot pretend otherwise.
# =============================================================================
# =============================================================================
# CASE — EVERY LINK BELOW THE FIRST SAYS SO, IN ALL THREE IMPLEMENTATIONS.
#
# The trunk chain — <remote>/HEAD → init.defaultBranch → the kit's last-resort constant
# — is implemented three times: in kwt_resolve, in check-board.sh and in release.sh.
# It CANNOT be single-sourced as a function: release.sh sources nothing from scripts/lib/
# by a standing ruling stated in its own header. So the invariant is what has to be held,
# and this case is what holds it.
#
# WHAT WENT WRONG WITHOUT IT: kwt_resolve warns at steps 2 and 3; release.sh warned at
# step 3 ONLY, so a cut against init.defaultBranch went out silent — and step 2 is where
# a real cut lands, because a developer machine usually HAS that config set; check-board
# warned at NEITHER, while its own comment claimed parity with the library. A report
# whose every trunk arm is about a branch, printed against a guessed branch name, is the
# one case where a clean report is worse than none.
#
# THE THREE STATES ARE BUILT BY REMOVAL, in order, from a sandbox that starts at step 1.
# =============================================================================
# =============================================================================
# CASE — THE FRONTMATTER SCAN CAP DOES WHAT IT IS FOR.
#
# check (d) reads a card's `id:` out of the first `---` fence pair it finds, and only
# looks for that opening fence within FRONTMATTER_SCAN_LINES. Nothing exercised the cap:
# the harness derived the value, asserted it non-empty, and never used it — beside a
# comment describing the control it was not.
#
# THE CAP'S ACTUAL BEHAVIOUR IS NARROWER THAN "a body --- breaks parsing", and the
# distinction is the case. A card with real frontmatter at the top closes its block on
# line 3, and the parser will not re-enter a closed block, so a body `---` a hundred
# lines down is already harmless — with or without a cap. What the cap governs is the
# card with NO frontmatter at the top: without it, the first `---` ANYWHERE in the body
# opens a block, and whatever follows is read as frontmatter.
#
# So this case takes both directions: a normal card with a body rule must parse (the
# direction the finding asks for), and a fence pair sitting PAST the cap must NOT be
# read as frontmatter (the direction that can actually go red).
#
# THE CAP IS DERIVED AND THE FIXTURE IS SIZED FROM IT. A hardcoded line count goes stale
# the day the cap is retuned, and the case then asserts nothing while reading green.
#
# WHAT THIS DOES NOT COVER: whether the cap's VALUE is right. This proves the cap is
# enforced in both directions, not that 25 is the correct number.
# =============================================================================
# =============================================================================
# CASE — EVERY CASE THAT MINTS A CARD PROBES FOR THE TEMPLATE FIRST.
#
# Measured when this was written: removing .claude/templates/ISSUE.template.md from the
# built tree gave 2 FAIL alongside 8 clean skips. The two failures were cases that mint
# a card and never asked whether the template exists — so a capability the TREE lacks
# was reported as a defect in the SUBJECT.
#
# THE POPULATION IS DERIVED, and that is the whole point of the case rather than the two
# lines it guards. "Which cases mint a card?" is answerable from the file — the ones that
# invoke a creation script — so case eleven cannot arrive without a probe and go unnoticed
# until somebody removes the template again. Enumerating the two would have fixed the
# instances and left the class, which is this board's most-repeated mistake.
# =============================================================================
# =============================================================================
# CASE — AN ADVISORY SECTION SAYS SO IN THE MACHINE'S VOCABULARY, NOT ONLY IN PROSE.
#
# kit-init's board self-check drops advisory sections BY THEIR OWN DECLARATION: an awk sets
# a flag when an `^[a-z]` arm header contains the literal `reports only`, and skips
# everything under it. That literal is a machine contract (contracts/drift-report.md § 4),
# not phrasing.
#
# A header can therefore say the right thing in the wrong vocabulary. One did: the
# whole-file reading advertised "(ADVISORY, does not fail the board)" and carried no
# token, so kit-init would have counted its ⚠ as a real finding and refused the install —
# the exact regression the verdict-line filter was landed to end, arriving through a
# header that MEANS advisory and does not SAY it.
#
# It was unreachable only by luck (a fresh tree's progress.md is far below the threshold),
# which is why prose and token being two authoring sites for one fact needs a census
# rather than a fix at the one site that happened to be found.
# =============================================================================
# =============================================================================
# CASE — ONE READ EXPRESSION, FIVE SITES, AND EVERY SITE DECLARES ITS FALLBACK POLICY.
#
# Reading the project's declared role set out of scripts/githooks/commit-msg is ONE act
# written five times. It cannot be written once: check-board.sh and kit-init.sh source
# nothing from scripts/lib/, so lib/role-set.sh's kit_role_set reaches three consumers and
# not the other two.
#
# WHAT ACTUALLY WENT WRONG IS NOT THE COUNT. The copies disagreed and the disagreement was
# invisible: one carried a trailing `.*`, silently tolerating content after the closing
# quote that no other reader accepts. Two sites, same file, different answers, nothing in
# either to show it.
#
# AND THE POLICIES DIFFER ON PURPOSE — check-board falls back to a hardcoded set and SAYS
# so; kit-init treats an unreadable hook as fatal; the library returns empty and makes the
# caller decide; the harness dies. Each is right for its own caller. So this case pins the
# EXPRESSION, which must be identical, and requires each site to DECLARE its policy, which
# must not be guessed at by the next reader.
# =============================================================================
# =============================================================================
# CASE — NO --help OPENS WITH ITS OWN KIT-CLASS MARKER.
#
# Every header-derived --help printed from a literal line 3, and that literal encoded a
# premise: line 1 is the shebang, line 2 is the whole KIT-CLASS marker. The premise is
# false wherever the marker WRAPS — several shipped files carry one spanning more than one
# line, and the set is derivable, so do not re-add a count here; the twin of this sentence
# in scripts/lib/usage.sh carried "three" until it was corrected on 2026-09-03 and THIS one
# was left, which is what fixing an instance instead of a class looks like from the inside
# — and help then opens with marker text, which is precisely what the window exists
# to exclude. The window's END was carefully derived; only its START was assumed.
#
# THE ASSERTION IS ABOUT THE OUTPUT, not about the number. A case pinning `start` to a
# computed value would pass against a renderer that computed it and then ignored it.
# =============================================================================
# =============================================================================
# CASE — NO SHIPPED SCRIPT REACHES PAST THE DECLARED FLOOR.
#
# The kit REQUIRES git and a POSIX shell, and carves out its optional extras BY NAME —
# the hygiene scripts are Python 3 and never a gate; one skill's visual companion wants
# Node and is opt-in per question. `perl` is not among them, and subtask.sh used it on
# its --plan path.
#
# THE FLOOR'S VALUE IS NOT THAT THE LIST IS SHORT; IT IS THAT THE LIST IS TRUE. perl is on
# essentially every system the kit will meet, so the practical risk is small — and an
# undeclared dependency on an optional path is exactly what an adopter porting to a
# minimal container finds at the wrong moment. A floor nobody checks is a claim.
#
# THE CARVE-OUTS ARE DERIVED, not listed here: this case reads the shipped scripts, and
# the two named extras live in directories it does not walk.
# =============================================================================
# =============================================================================
# CASE — A HOOK REJECTION BETWEEN THE BUMP AND THE COMMIT LEAVES NOTHING BEHIND.
#
# release.sh's restore used to live INSIDE the per-file bump loop, so it fired only for a
# failed bump. Everything after it was unprotected: `git add` stages the rewrite, and
# `git commit` then runs the project's commit-msg hook. A rejection there left the version
# files REWRITTEN, STAGED and UNCOMMITTED — and the script never said so, because the
# "LOCAL ONLY, NOTHING IS PUSHED YET" recovery prints on the success path, after the tag.
#
# THE TRIGGER IS THE KIT'S OWN SUPPORTED FLOW, which is why this is not hypothetical:
# narrowing the role set leaves release.sh's own '[Architect]' outside the hook's
# alternation, and release.sh is correctly not in kit-init's stamping loop.
#
# THE ASSERTION IS THE STATE OF THE TREE, not the message. "It printed an error" is
# satisfied by a run that errored and left the bump behind.
# =============================================================================
# =============================================================================
# CASE — EVERY TRAVELLING SCRIPT HAS A SHEET OR SITS IN A NAMED EXEMPT CLASS.
#
# contracts/README.md states the rule in both directions. THIS one — every travelling script has
# a sheet — was unguarded, and is what this case closes. The MIRROR direction (every path a sheet
# cites still exists) is STILL UNGUARDED: this comment claimed it was already covered, and no such
# case exists anywhere in the suite. contracts/README.md says the same, correctly.
# contracts/README.md said so in as many words: "nothing checks that a travelling script
# has a sheet… the guard is the PROJECT's, not the kit's… the contracts travel, a guard
# over them does not."
#
# THAT LAST CLAUSE IS SUPERSEDED BY THIS CASE, and the reason it was written is worth
# keeping: a guard needs the project's own file set, which the kit does not have. But this
# harness SHIPS and runs inside the project's tree, so it does have it — the obstacle was
# never that the guard could not travel, only that nothing carrying it did.
#
# THE EXEMPT CLASSES ARE DERIVED FROM THE RULE'S OWN TEXT, not listed here. A second
# hand-typed list of exemptions is the defect this whole directory is about.
# =============================================================================
# =============================================================================
# CASE — A PARTIAL PREFIX DERIVATION REPORTS ITSELF PARTIAL, AND THE INITIALIZER
#        REFUSES THE VALUE THAT CAUSES ONE.
#
# Two halves of one contract, only one of which had been written. kit-init validated
# --prefix and not --prd-prefix, so `--prd-prefix REQ-2` was accepted and stamped; the
# hygiene instrument derives its id pattern with `([A-Za-z0-9]+)` and could not then read
# that key. Its `_id_prefixes` returned `derived=True` for a list of length one, so the
# instrument silently stopped seeing PRD ids WHILE REPORTING ITSELF FULLY DERIVED —
# `id_prefixes_derived_from_seam` is the flag a reader uses to tell a real zero from a
# blind one, and a partial derivation is the blind case wearing the confident flag.
#
# BOTH ARMS ARE NEEDED. Validation closes one route to a half-derivation; only the flag
# can tell a reader when some other route was taken.
# =============================================================================
# =============================================================================
# CASE — THE AGENT-FACING PROSE THE KIT MOST DEPENDS ON IS READ BY SOMETHING.
#
# Measured when this was written: this harness referenced `.claude/agents/` ZERO times and
# read no role doc's CONTENT for any rule, while reading sixteen template operands, four
# skills and both runners. **It read the two directories the kit most depends on not at
# all** — and the kit puts ruling-protected sentences in them and tells the seat to copy
# them verbatim into new artifacts.
#
# WHY THAT IS STRUCTURAL RATHER THAN AN OVERSIGHT: a test suite is scoped to the PRODUCT,
# `.claude/**` is agent configuration, and nothing naturally pulls the second into the
# first. So the pull has to be deliberate, which is what this case is.
#
# PRESENCE, PER FILE, AND THE PER-FILE PART IS THE WHOLE DESIGN. A presence guard usually
# earns the objection that it cannot redden for staleness — but DELETION IS EXACTLY THIS
# DEFECT, so presence fits here better than it usually does. And it must be per file: a
# TOTAL hides the silent singular fall. Measured on the first run of this case, before it
# was registered: six of seven leaf workers carried the provisioning rider and the seventh
# carried NEITHER half of it. A count of six would have read as "the rider is there".
#
# WHAT THIS CANNOT DO, stated because doctrine/negative-claims.md requires it: a guard over
# these files' prose WILL NOT NOTICE A RIDER THAT IS PRESENT AND WRONG. It sees deletion
# and it sees a new file that never carried the rule. It does not read for meaning.
# =============================================================================
case_agent_prose_carries_its_riders() {
  cf_reset
  make_sandbox
  local adir="$REAL_REPO_ROOT/.claude/agents" rdir="$REAL_REPO_ROOT/.claude/roles"
  local f base n=0 r

  # THE RIDERS ARE DERIVED FROM THE MAJORITY OF THE POPULATION, not typed here — a literal
  # would be a second authoring site for the very sentence under guard, and it would go
  # stale in the direction that matters: reworded upstream, still asserted here.
  local rider1='human-partnered' rider2='provisionable'

  if [ ! -d "$adir" ]; then
    skp "the agent-facing prose carries its riders" ".claude/agents/ is absent — this project ships no leaf-worker definitions"
    teardown; return
  fi

  for f in "$adir"/*.md; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"; n=$(( n + 1 ))
    for r in "$rider1" "$rider2"; do
      grep -qF "$r" "$f" \
        || cf "$base carries no '$r' — every other leaf-worker definition states the provisioning rider, and a definition that lost it tells its worker nothing about the ceiling it must not exceed"
    done
    # A leaf worker says it is one. The tools list is the mechanism; the sentence is what
    # the agent reads, and only the sentence travels into a hand-written definition.
    grep -qiE 'leaf worker|do not spawn' "$f" \
      || cf "$base does not say it is a leaf worker — the absent Agent/Workflow tools are the mechanism, and the sentence is the only half a hand-written sibling would copy"
  done

  # ── INSTRUMENT CHECK: a loop over an empty directory reports full coverage.
  [ "$n" -ge 5 ] \
    || cf "only $n leaf-worker definition(s) were read — expected at least 5. The glob stopped matching, so 'every one carries the rider' is true of almost nothing"

  # THE ROLE DOCS, same rider, same reason — and this is the half that had NO reader at all.
  local rn=0
  if [ -d "$rdir" ]; then
    for f in "$rdir"/*.md; do
      [ -f "$f" ] || continue
      base="$(basename "$f")"; rn=$(( rn + 1 ))
      grep -qF "$rider1" "$f" \
        || cf "role doc $base carries no '$rider1' — the seat-vs-worker distinction is what stops a role being provisioned like a leaf, and it is stated nowhere else in the file"
    done
    [ "$rn" -ge 4 ] \
      || cf "only $rn role doc(s) were read — expected at least 4"
  fi

  finish "every one of the $n leaf-worker definitions and $rn role docs carries the provisioning rider, per FILE rather than in total — a total hides the silent singular fall, which is what this case found on its first run. NOT COVERED: a rider that is present and WRONG; this reads for deletion, not for meaning"
  teardown
}

case_partial_prefix_derivation_says_so() {
  cf_reset
  make_sandbox
  local hy="$SB_WORK/scripts/hygiene/staleness_greps.py"
  if [ ! -f "$hy" ]; then
    skp "a partial prefix derivation reports itself partial" "scripts/hygiene/ is absent — it is the kit's deletable optional extra"
    teardown; return
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    skp "a partial prefix derivation reports itself partial" "python3 is not on PATH, and the kit does not require it"
    teardown; return
  fi

  local probe="$SB_TMP/prdprobe" out
  rm -rf "$probe"; mkdir -p "$probe/scripts"

  _prd_derived() {  # <config.sh body> -> "prefixes|True|False"
    printf '%s' "$1" > "$probe/scripts/config.sh"
    python3 - "$hy" "$probe" <<'PY'
import importlib.util, pathlib, sys
spec = importlib.util.spec_from_file_location('sg', sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
pat, derived = m._id_prefixes(pathlib.Path(sys.argv[2]))
print(f"{pat}|{derived}")
PY
  }

  # ── INSTRUMENT CHECK: BOTH keys readable must report derived. Without this, "partial
  #    reports False" is satisfied by a derivation that reports False for everything.
  out="$(_prd_derived 'ISSUE_PREFIX="${ISSUE_PREFIX:-KIT}"
PRD_PREFIX="${PRD_PREFIX:-PRD}"
')"
  case "$out" in
    *'|True') ;;
    *) cf "(instrument) a config.sh with BOTH keys readable reports '$out' — if a full read is not derived, the partial arm below proves nothing" ;;
  esac

  # THE ARM: one key readable, one not. Must report NOT derived, and must still use what
  # it read — a partial pattern finds some ids, and throwing it away would trade a
  # dishonest instrument for a blind one.
  out="$(_prd_derived 'ISSUE_PREFIX="${ISSUE_PREFIX:-KIT}"
PRD_PREFIX="${PRD_PREFIX:-REQ-2}"
')"
  case "$out" in
    *'|False') ;;
    *) cf "a config.sh where only ONE of the two prefix keys parses reports '$out' — a PARTIAL derivation claiming to be complete is this instrument's honesty flag asserting the opposite of the truth" ;;
  esac
  case "$out" in
    KIT'|'*) ;;
    *) cf "the partial derivation discarded the key it COULD read (got '$out') — reporting the gap is right, going blind on top of it is not" ;;
  esac

  unset -f _prd_derived

  # THE OTHER HALF: the initializer refuses the value that produces a partial read.
  if has_kit_init; then
    grep -q 'PRD_PREFIX_NEW' "$SB_WORK/scripts/kit-init.sh" \
      && grep -qE '^if \[ -n "\$PRD_PREFIX_NEW" \] && ! printf' "$SB_WORK/scripts/kit-init.sh" \
      || cf "kit-init.sh does not validate --prd-prefix the way it validates --prefix — the route that produces a partial derivation is still open, and only the flag above would catch it"
  fi

  finish "a config.sh where only one of the two prefix keys parses reports id_prefixes_derived_from_seam FALSE while still using the key it could read, a full read still reports TRUE, and kit-init refuses the --prd-prefix values that produce the partial case"
  teardown
}

case_travelling_scripts_have_a_sheet() {
  cf_reset
  make_sandbox
  # The REAL tree: make_sandbox does not copy process/, and a case that skips because its
  # own operand is absent from the fixture is a skip about the fixture, not the project.
  local readme="$REAL_REPO_ROOT/process/contracts/README.md"
  local cdir="$REAL_REPO_ROOT/process/contracts"
  [ -f "$readme" ] && [ -d "$cdir" ] \
    || { skp "every travelling script has a sheet or a named exemption" "process/contracts/ is absent — this project does not carry the contract set"; teardown; return; }

  # THE OPERAND IS EVERY TRAVELLING SCRIPT, NOT scripts/ ALONE, AND BOTH COMMENT SYNTAXES.
  # This walked $REAL_SCRIPTS with `^# KIT-CLASS:` only — narrower than the rule it enforces in
  # exactly the two ways contracts/README.md's own recipe warns about, so consumers/ was invisible
  # to the guard that claims to cover every travelling script.
  #
  # THE EXEMPT PREFIXES, derived from the rule's own bullet rather than retyped. Each class
  # is named there as a backticked path prefix.
  local exempt n=0 miss="" f rel
  exempt="$(awk '/EXEMPT-CLASSES:BEGIN/,/EXEMPT-CLASSES:END/' "$readme" \
            | grep -oE '`[a-z][a-z-]*/([a-z-]+/)?`' | tr -d '`' | sort -u)"
  # ANY top-level prefix, not `scripts/…` alone: the pattern was written when both exempt classes
  # happened to live under scripts/, so adding a third (consumers/) left it invisible to the guard
  # that reads this list — the extractor silently declining to see a class nobody could tell it about.
  [ -n "$exempt" ] \
    || _fixture_die "case_travelling_scripts_have_a_sheet: could not derive the exempt classes out of contracts/README.md — with none derived every travelling script would look owed, and with the derivation reading the wrong block every one would look exempt."

  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rel="${f#$REAL_REPO_ROOT/}"
    n=$(( n + 1 ))
    # Exempt by class?
    local e skip=0
    for e in $exempt; do case "$rel" in "$e"*) skip=1 ;; esac; done
    [ "$skip" -eq 1 ] && continue
    # Cited by some sheet — literally, or in the placeholder form a sheet may legitimately
    # use for an adopter-instance path (notification.md's scripts/notify/<channel>.sh).
    grep -rqF "$rel" "$cdir" 2>/dev/null && continue
    grep -rqE "$(printf '%s' "${rel%/*}" | sed 's/[.[\*^$]/\\&/g')/<[a-z-]+>\.(sh|py)" "$cdir" 2>/dev/null && continue
    miss="$miss $rel"
  done <<EOF
$(grep -rlE '^(#|<!--) KIT-CLASS: (KIT|MIXED)' "$REAL_REPO_ROOT/scripts" "$REAL_REPO_ROOT/consumers" "$REAL_REPO_ROOT/setup.sh" 2>/dev/null | sort)
EOF

  [ -z "$miss" ] \
    || cf "these travelling scripts are cited by no contract sheet and sit in no named exempt class —$miss. Either the sheet is owed or the exemption is, and contracts/README.md is where the exemption goes so the next sweep finds a decision rather than a violation"

  # ── INSTRUMENT CHECK: a sweep that found no travelling scripts reports full coverage.
  [ "$n" -ge 12 ] \
    || cf "only $n travelling script(s) were found — expected at least 12. The KIT-CLASS marker or the glob changed, so 'every one is covered' is true of almost nothing"

  finish "all $n travelling (KIT/MIXED) scripts are either cited by a contract sheet — literally, or in the placeholder form a sheet may use for an adopter-instance path — or sit in one of the exempt classes contracts/README.md names, with the class list DERIVED from that rule rather than retyped"
  teardown
}

case_release_hook_rejection_leaves_no_bump() {
  cf_reset
  if ! has_release; then skp "a hook rejection between bump and commit leaves nothing behind" "scripts/release.sh absent"; return; fi
  make_sandbox
  seed_release_files 1.1.0
  publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  local out rc

  # BREAK THE COMMIT, and break it the way the kit's own flow does: install a commit-msg
  # hook that rejects release.sh's role tag. Not `exit 1` unconditionally — a hook that
  # refuses everything would also refuse the board stub's commits and fail earlier.
  # INSTALL WHERE GIT ACTUALLY LOOKS. The kit points core.hooksPath at scripts/githooks,
  # so a hook dropped in .git/hooks is never consulted — measured: the first version of
  # this leg installed there, release.sh cut cleanly, and the case reported "exited 0 with
  # a hook that rejects its own tag" about a hook git had not run.
  local hookdir hook
  hookdir="$(git -C "$SB_WORK" config --get core.hooksPath 2>/dev/null || true)"
  [ -n "$hookdir" ] || hookdir=".git/hooks"
  case "$hookdir" in /*) hook="$hookdir/commit-msg" ;; *) hook="$SB_WORK/$hookdir/commit-msg" ;; esac
  mkdir -p "$(dirname "$hook")"
  printf '#!/usr/bin/env bash\ngrep -q "^\\[Architect\\]" "$1" && { echo "hook: [Architect] is not in this project'"'"'s role set" >&2; exit 1; }\nexit 0\n' > "$hook"
  chmod +x "$hook"
  # COMMIT THE HOOK. It lives INSIDE the repository (scripts/githooks/), so writing it
  # leaves the tree dirty and release.sh refuses at its cleanliness gate long before the
  # bump — a refusal that satisfies "it exited nonzero" while proving nothing about the
  # MUTATE block. Commit with the hook not yet in force, which is why --no-verify is
  # correct here rather than a shortcut.
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  git -C "$SB_WORK" -c user.email=t@t -c user.name=t commit --no-verify -q -m "[PM] install a narrow role hook" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin HEAD >/dev/null 2>&1 || true

  rc=0; out="$( cd "$SB_WORK" && RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=true \
      RELEASE_BOARD_CMD="$SB_TMP/board-clean.sh" "$SB_WORK/scripts/release.sh" 1.1.0 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] \
    || cf "release.sh exited 0 with a commit-msg hook that rejects its own role tag — the commit cannot have happened"

  # ── THE STATE OF THE TREE. This is the case.
  grep -qx "$SB_REL_PRE_VERSION" "$SB_WORK/VERSION" \
    || cf "VERSION was left BUMPED on disk after the commit failed — it reads '$(cat "$SB_WORK/VERSION" 2>/dev/null)', and the next thing anyone does in this tree carries a version nobody released"
  grep -qF "version = \"$SB_REL_PRE_VERSION\"" "$SB_WORK/pkg.conf" \
    || cf "pkg.conf was left bumped on disk after the commit failed"
  [ -z "$(git -C "$SB_WORK" diff --cached --name-only 2>/dev/null)" ] \
    || cf "the bump is still STAGED after the commit failed — a later 'git commit' in this tree would carry it silently: $(git -C "$SB_WORK" diff --cached --name-only | tr '\n' ' ')"
  git -C "$SB_WORK" rev-parse -q --verify refs/tags/v1.1.0 >/dev/null 2>&1 \
    && cf "a tag was created even though the release commit failed"

  # …AND IT SAYS SO. Second, because a silent correct cleanup still leaves the operator
  # believing a release happened.
  printf '%s' "$out" | grep -qi 'ABORTED between the version bump and the release commit' \
    || cf "the abort is not announced — the operator is left with a failed command and no account of what was undone: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  printf '%s' "$out" | grep -qi 'RELEASE_ROLE' \
    || cf "the abort does not name the knob that fixes the likeliest cause"

  teardown

  # ── INSTRUMENT CHECK, IN ITS OWN SANDBOX. Every assertion above is "nothing was left
  #    behind", which a release that could never have run satisfies for free. It needs a
  #    SEPARATE sandbox: a successful cut PUSHES, and sharing one bare origin with the leg
  #    above would leave that leg's checkout behind its own remote — measured, gate (a)
  #    then refuses and the whole case passes without ever reaching the MUTATE block.
  make_sandbox
  seed_release_files 1.1.0
  publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  rc=0; out="$( cd "$SB_WORK" && RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=true \
      RELEASE_BOARD_CMD="$SB_TMP/board-clean.sh" "$SB_WORK/scripts/release.sh" 1.1.0 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] \
    || cf "(instrument) the UNBROKEN fixture cannot cut (rc=$rc) — every 'nothing was left behind' assertion above is then free: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  grep -qx '1.1.0' "$SB_WORK/VERSION" \
    || cf "(instrument) a successful cut did not bump VERSION — the assertions above cannot tell a restore from a bump that never happened"

  finish "a commit-msg hook that rejects release.sh's role tag — the state the kit's own 'kit-init --roles' produces — aborts the cut with the version files restored on disk, nothing left staged, no tag, and an announcement naming both what was undone and the knob that fixes it"
  teardown
}

# =============================================================================
# CASE — A VALUE-TAKING OPTION GIVEN NO VALUE REFUSES, WITH STATUS 2, AND SAYS SO.
#
# THE DEFECT WAS SILENT AND IT WAS EVERYWHERE. An arm written
# `--x) VAR="${2:-}"; shift 2 ;;` reads as safe — `${2:-}` cannot be unbound. But
# `shift 2` with one argument left RETURNS NON-ZERO, and under `set -e` that aborts:
# **exit 1, no message, nothing done.** Measured across the shipped set before the fix:
# 26 arms in six scripts behaved that way. The three creation scripts already had the
# guard and had had it all along, which is what made the gap invisible — the family that
# gets read most was the family that was correct.
#
# THE CENSUS IS STATIC AND THE PROBES ARE EXECUTED, and it needs both. A static census
# cannot know that `need_val` does anything; an executed probe covers one script. So:
# every value-taking arm calls the guard, every definition of the guard is identical, and
# two scripts are actually run.
# =============================================================================
# =============================================================================
# CASE — A TEMPLATE'S LINKS RESOLVE FROM WHERE IT LANDS, NOT FROM WHERE IT SITS.
#
# THIS CLASS WAS FIXED THREE TIMES, ONE INSTANCE AT A TIME, BEFORE ANYONE COUNTED IT.
# PRD.template.md, launch-pack, round-pack, then round-report and run-report — five of the
# fourteen shipped templates, found across three sweep rounds because each round reported
# the ones its checker happened to open. **A census would have found all five on day one**,
# and that is the whole reason this case exists rather than a sixth careful fix.
#
# WHY A LINK CHECK RUN IN THE KIT CANNOT SEE IT: the template SITS in process/templates/ and
# is COPIED to dev/launch/, requirements/, progress/todo/ … A link written for where it sits
# resolves perfectly here and is dead in every copy an adopter makes. It passes the obvious
# test and fails the only one that matters.
#
# THE DESTINATION IS DECLARED BY EACH TEMPLATE, and this case reads it from a header line
# rather than a table here — a table would be a fifteenth thing to keep in step.
# =============================================================================
case_template_links_resolve_from_their_destination() {
  cf_reset
  make_sandbox
  local probe="$SB_TMP/tmpl" t base dest n=0 bad=0
  # COPY THE WHOLE TREE, not the directories this case thinks it needs. Measured while
  # writing it: hand-picking process/ and .claude/ left requirements/ out and the case
  # reported CLAUDE-adapter.template.md's link to requirements/DECISIONS.md as broken — a
  # file that ships. **The probe was the defect**, and a link census whose corpus is
  # hand-listed will keep inventing findings about whatever the list forgot.
  rm -rf "$probe"; mkdir -p "$probe"
  ( cd "$REAL_REPO_ROOT" && tar cf - . 2>/dev/null ) | ( cd "$probe" && tar xf - 2>/dev/null ) || true
  [ -d "$probe/process/templates" ] \
    || { skp "a template's links resolve from where it LANDS" "process/templates/ is absent"; teardown; return; }

  # The landing directories a template names may not exist on a fresh tree (dev/rounds/<name>/
  # is minted per round); create them so a CORRECT link is not reported as broken.
  ( cd "$probe" && mkdir -p requirements progress/todo dev/launch dev/rounds/X docs ) >/dev/null 2>&1

  for t in "$probe"/process/templates/*.md "$probe"/.claude/templates/*.md; do
    [ -f "$t" ] || continue
    base="$(basename "$t")"
    # THE DESTINATION IS THE TEMPLATE'S OWN CLAIM. Only files that state one are checked;
    # a template with no declared destination is a different (and reported) problem.
    dest="$(sed -n 's|.*RELATIVE TO WHERE IT LANDS — \([^ ]*\) .*|\1|p' "$t" | head -1)"
    [ -n "$dest" ] || dest="$(sed -n 's|.*[Cc]opy \(it \)\?to `\([^`]*\)/[^/`]*`.*|\2|p' "$t" | head -1)"
    [ -n "$dest" ] || continue
    dest="$(printf '%s' "$dest" | sed 's|<[^>]*>|X|g; s|/$||')"
    [ -d "$probe/$dest" ] || mkdir -p "$probe/$dest"
    n=$(( n + 1 ))
    local miss
    miss="$(awk -v d="$probe/$dest" '
      { while (match($0, /\]\([^)#<]+\)/)) {
          l = substr($0, RSTART+2, RLENGTH-3); $0 = substr($0, RSTART+RLENGTH)
          if (l ~ /^http/ || l ~ /</) continue
          cmd = "test -e \"" d "/" l "\""
          if (system(cmd) != 0) printf "%s:%s ", FNR, l
      } }' "$t")"
    [ -z "$miss" ] || { bad=$(( bad + 1 )); cf "$base declares it lands in '$dest' and these links do not resolve from there: $miss — they resolve from process/templates/ instead, which is where the file SITS, so they pass a link check run in the kit and are dead in every copy an adopter makes"; }

    # ── THE CLIMB CHECK, for the links the resolver above SKIPS ────────────────────
    # It skips any link containing `<`, because a placeholder cannot be resolved on
    # disk. That exemption hid a real defect: SUBTASK.template.md declared it lands in
    # progress/todo/ when subtask.sh puts it four segments deep, and its ONLY link
    # carries a <status> placeholder — so the one template with a wrong destination was
    # the one whose links were entirely exempt from the check.
    #
    # A placeholder blocks resolution, not arithmetic. A link may climb no further than
    # its destination is deep: from a 2-segment destination, `../../../` leaves the
    # repository, and that is wrong whatever the placeholder expands to.
    local depth climb over
    depth="$(printf '%s' "$dest" | awk -F/ '{print NF}')"
    over="$(awk -v d="$depth" -v D="$dest" '
      { while (match($0, /\]\([^)#]+\)/)) {
          l = substr($0, RSTART+2, RLENGTH-3); $0 = substr($0, RSTART+RLENGTH)
          if (l ~ /^http/ || l !~ /^\.\.\//) continue
          c = 0; t = l
          while (t ~ /^\.\.\//) { c++; sub(/^\.\.\//, "", t) }
          if (c > d) printf "%s:%s(climbs %d from a %d-deep destination) ", FNR, l, c, d
      } }' "$t")"
    [ -z "$over" ] || { bad=$(( bad + 1 )); cf "$base declares it lands in '$dest' and these links climb ABOVE the repository root from there: $over"; }
  done

  # ── INSTRUMENT CHECK: a loop that resolved no destinations reports every template clean.
  [ "$n" -ge 6 ] \
    || cf "only $n template(s) declared a destination this case could read — expected at least 6. The declaration wording changed, so 'every template's links resolve' is true of almost nothing"

  finish "all $n templates that declare where they land have links that resolve FROM THERE ($bad broken) — checked from the destination each template names, because a link written for where the template SITS passes every check run in the kit and is dead in every adopter's copy"
  teardown
}

case_missing_option_value_refuses() {
  cf_reset
  make_sandbox
  local f base arms=0 guarded=0 defs="" bad=""

  for f in "$REAL_SCRIPTS"/*.sh; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    # A value-taking arm is a case arm that shifts TWO. Derived, never listed.
    while IFS= read -r ln; do
      [ -n "$ln" ] || continue
      arms=$(( arms + 1 ))
      case "$ln" in
        *'need_val "$@"'*) guarded=$(( guarded + 1 )) ;;
        *) bad="$bad
    $base: $ln" ;;
      esac
    done <<EOF
$(awk '/^[[:space:]]*(-[a-zA-Z]\|)*--[a-z][a-z-]*\)/ && /shift 2/ { gsub(/^[[:space:]]+/,""); print }' "$f")
EOF
    grep -q '^need_val()' "$f" && defs="$defs $base"
  done

  [ -z "$bad" ] \
    || cf "these value-taking option arms do not call need_val — each exits 1 in silence when its value is missing, because \`shift 2\` with one argument left fails under set -e:$bad"

  # ── INSTRUMENT CHECK: the derivation still finds arms. A census that matched nothing
  #    would report "all guarded" forever.
  [ "$arms" -ge 20 ] \
    || cf "the census found only $arms value-taking arm(s) — expected at least 20. The arm shape changed, so 'every one is guarded' is true of almost nothing"

  # ONE GUARD, ONE SHAPE. Nine scripts each carry their own copy (several source nothing
  # from scripts/lib/), so the copies are held identical here rather than shared.
  local first="" body
  for base in $defs; do
    body="$(awk '/^need_val\(\)/{f=1} f{print} f&&/^}/{exit}' "$REAL_SCRIPTS/$base" | tr -d ' \n')"
    if [ -z "$first" ]; then first="$body"
    elif [ "$body" != "$first" ]; then
      cf "$base's need_val differs from the first definition — nine hand-kept copies of one guard, and a divergence here means one script refuses differently from its siblings for the same illegal invocation"
    fi
  done

  # ── EXECUTED, because a static census cannot know the guard does anything.
  local out rc
  rc=0; out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$SB_PREFIX-1" todo --note 2>&1 )" || rc=$?
  [ "$rc" -eq 2 ] \
    || cf "(executed) move-issue.sh with a valueless --note exited $rc, want 2: $(printf '%s' "$out" | head -1)"
  printf '%s' "$out" | grep -q 'requires a value' \
    || cf "(executed) move-issue.sh's refusal does not say the option requires a value: $(printf '%s' "$out" | head -1)"

  # A LEADING '-' IS NEVER A NAME — the same clause, on a POSITIONAL rather than an option.
  # notify.sh swallowed `--message` as its message BODY and exited 0, delivering a
  # notification that read "--message".
  rc=0; out="$( cd "$SB_WORK" && ./scripts/notify.sh attention --message 2>&1 )" || rc=$?
  [ "$rc" -eq 2 ] \
    || cf "(executed) notify.sh took '--message' as its message body and exited $rc — a leading '-' is never a name, and a delivered notification reading '--message' is quieter than a refusal"

  finish "every one of the $arms value-taking option arms across the shipped scripts calls need_val (${guarded} guarded), the guard's ${defs:+copies} are byte-identical, and two scripts prove it EXECUTED: a valueless --note exits 2 naming the option, and a leading '-' is refused as a positional rather than swallowed as one"
  teardown
}

case_shipped_scripts_stay_on_the_floor() {
  cf_reset
  make_sandbox
  local f base n=0

  # The interpreters that are NOT on the floor. Held one per line so this case's own text
  # cannot satisfy the search it performs on itself (it does not scan itself, but the
  # sandbox's copy of this file is not what is walked either — state it anyway).
  local i1='perl' i2='python' i3='node' i4='ruby'

  for f in "$SB_WORK"/scripts/*.sh "$SB_WORK"/scripts/lib/*.sh "$SB_WORK"/scripts/githooks/*; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    n=$(( n + 1 ))
    # NON-COMMENT LINES ONLY: several of these files DISCUSS perl in a comment explaining
    # why they do not use it, and a bare grep would report the explanation as the defect.
    local w hit
    for w in "$i1" "$i2" "$i3" "$i4"; do
      # COMMAND POSITION, not mere appearance. `echo "… a node id …"` mentions node and
      # does not invoke it; a census that cannot tell those apart reports prose as a
      # dependency, which is how a floor check gets switched off for being noisy. The
      # leading `VAR=value ` group is there because the shipped idiom for passing a value
      # safely is exactly `PLAN="$PLAN" perl …`.
      hit="$(awk -v w="$w" '
        /^[[:space:]]*#/ { next }
        $0 ~ ("(^|[;&|(]|\\$\\()[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*" w "([[:space:]]|$)") { print NR ": " substr($0,1,90) }
      ' "$f" 2>/dev/null || true)"
      [ -z "$hit" ] \
        || cf "$base invokes '$w', which is not on the kit's declared floor (git + a POSIX shell, with the optional extras carved out by name): $(printf '%s' "$hit" | tr '\n' ' ' | cut -c1-160)"
    done
  done

  # ── INSTRUMENT CHECK: a loop that walked nothing reports a clean floor forever.
  [ "$n" -ge 15 ] \
    || cf "only $n shipped script(s) were walked — expected at least 15. The glob stopped matching, so 'nothing off the floor' is true of almost nothing"

  finish "none of the $n shipped scripts, libraries or hooks invokes an interpreter past the declared floor of git plus a POSIX shell — the two optional extras are carved out by name and live outside this walk, and comments EXPLAINING why perl is not used do not count as using it"
  teardown
}

case_help_never_opens_with_the_class_marker() {
  cf_reset
  make_sandbox
  local f base out n=0 marker_key

  # Derive the marker's own key rather than typing it — the same constant kit-init protects.
  marker_key="$KIT_CLASS_MARKER_KEY"
  [ -n "$marker_key" ] \
    || _fixture_die "case_help_never_opens_with_the_class_marker: no KIT_CLASS_MARKER_KEY — the assertion below would search for an empty string and pass on every file."

  # The REAL shipped tree: make_sandbox does not copy consumers/, and that directory holds
  # the file whose marker actually wraps — a loop that cannot reach its own subject reports
  # "no leakage" about the files that never had any.
  for f in "$REAL_SCRIPTS"/*.sh "$REAL_REPO_ROOT"/consumers/*.sh; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    grep -q -- "--help" "$f" 2>/dev/null || continue
    grep -q "$marker_key" "$f" 2>/dev/null || continue
    n=$(( n + 1 ))
    out="$( cd "$SB_TMP" && bash "$f" --help </dev/null 2>&1 )" || true
    [ -n "$out" ] || { cf "$base --help printed nothing"; continue; }
    # THE FIRST FIVE LINES are the window's opening; a marker that wraps shows up there.
    printf '%s\n' "$out" | head -5 | grep -q "$marker_key" \
      && cf "$base --help opens with its own $marker_key marker — the window START is assuming the marker is one line, and this file's is not: $(printf '%s' "$out" | head -3 | tr '\n' '|' | cut -c1-140)"
  done

  # ── INSTRUMENT CHECK: a loop that inspected nothing reports no marker leakage forever.
  [ "$n" -ge 8 ] \
    || cf "only $n script(s) with both --help and a $marker_key marker were inspected — expected at least 8. The glob or one of the two filters stopped matching, so 'no leakage' is true of almost nothing"

  finish "no --help among the $n shipped scripts carrying both a $marker_key marker and a --help opens with that marker's own text — the window START is derived from where the marker ENDS (every marker's last line cites the extraction manifest), not from the assumption that it is one line"
  teardown
}

case_role_set_read_is_one_expression() {
  cf_reset
  make_sandbox
  local expr_ rows n

  # DERIVE the canonical expression from the library, never retype it: the library is the
  # declared shape, so a change there is meant to reach the census.
  # Read the REAL shipped tree, not the sandbox: the sandbox omits scripts/test/, which
  # holds two of the five sites — and a census that cannot see two of its operands reports
  # agreement among the three it can.
  expr_="$(sed -n 's/.*sed -n "\(s\/\^ROLE_PREFIXES[^"]*\)".*/\1/p' "$REAL_SCRIPTS/lib/role-set.sh" | head -1)"
  [ -n "$expr_" ] \
    || _fixture_die "case_role_set_read_is_one_expression: could not derive the canonical read out of lib/role-set.sh — a census with no expression to compare against passes forever."

  # Every site that reads ROLE_PREFIXES through sed uses THAT expression.
  rows="$(grep -rn "sed -n \"s/\^ROLE_PREFIXES" "$REAL_SCRIPTS" 2>/dev/null \
          | grep -vF "$expr_" || true)"
  [ -z "$rows" ] \
    || cf "a ROLE_PREFIXES read uses an expression other than the canonical one ('$expr_') — the copies then disagree about the same file with nothing in either to show it: $(printf '%s' "$rows" | tr '\n' ' ' | cut -c1-220)"

  # ── INSTRUMENT CHECK: the census still finds the population. A search that stopped
  #    matching reports "no divergence" about nothing.
  n="$(grep -rc "sed -n \"s/\^ROLE_PREFIXES" "$REAL_SCRIPTS" 2>/dev/null | awk -F: '{t+=$2} END{print t+0}')"
  [ "$n" -ge 4 ] \
    || cf "the census found only $n ROLE_PREFIXES read(s) — expected at least 4. A low count means the idiom changed shape, NOT that the sites agree"

  # EVERY SITE DECLARES ITS FALLBACK POLICY, because the policies legitimately differ and
  # an undeclared one is indistinguishable from a copied one.
  local f miss=""
  for f in check-board.sh kit-init.sh lib/role-set.sh; do
    grep -q "sed -n \"s/\^ROLE_PREFIXES" "$REAL_SCRIPTS/$f" 2>/dev/null || continue
    grep -qiE 'FALLBACK POLICY|Callers MUST treat empty' "$REAL_SCRIPTS/$f" \
      || miss="$miss $f"
  done
  [ -z "$miss" ] \
    || cf "these sites read ROLE_PREFIXES and declare no fallback policy —$miss. The policies differ on purpose; an undeclared one cannot be told from a copied one, and the next reader has to guess which"

  finish "the ROLE_PREFIXES read is ONE expression at all $n sites (derived from lib/role-set.sh, not retyped) and every shipped site declares its own fallback policy — the expression is shared by assertion because two of the readers source nothing from scripts/lib/, and the policies differ on purpose"
  teardown
}

case_advisory_headers_carry_the_machine_token() {
  cf_reset
  make_sandbox
  local cb="$SB_WORK/scripts/check-board.sh" rows n=0

  # Every arm-header emission that CLAIMS to be advisory in prose must also carry the token.
  # Derived over the shipped script; the two spellings are held on separate lines so this
  # case's own text cannot satisfy the search it performs.
  local prose='ADVISORY'
  local token='reports only'
  rows="$(awk -v p="$prose" -v t="$token" '
    /echo "\[[a-z]\]/ {
      if (index($0, p) && !index($0, t)) print NR ": " substr($0, 1, 110)
    }
  ' "$cb")"
  [ -z "$rows" ] \
    || cf "an arm header calls itself advisory in PROSE and omits the machine token — kit-init's self-check reads the token, not the prose, so this arm's findings would be counted as real and would refuse an install: $rows"

  # ── INSTRUMENT CHECK: the token is actually present somewhere, and on more than one arm.
  #    A census for "prose without token" is satisfied forever by a file with neither.
  n="$(grep -c "$token" "$cb" || true)"
  [ "$n" -ge 3 ] \
    || cf "the literal '$token' appears only $n time(s) in check-board.sh — either the advisory vocabulary was renamed (and kit-init's awk no longer matches anything) or this census is looking for a string the script has stopped using"

  # ── AND THE CONSUMER STILL READS IT. Textual agreement is not the contract; the awk is.
  grep -qF "$token" "$SB_WORK/scripts/kit-init.sh" \
    || cf "kit-init.sh does not mention '$token' — the producer and the consumer of this machine contract have drifted, and every advisory arm would start failing installs"

  finish "every check-board arm header that calls itself advisory carries the machine token '$token' that kit-init's self-check actually reads ($n occurrence(s)), and the consumer still reads it — prose and token are one fact, and only one of them is machine-readable"
  teardown
}

case_minting_cases_probe_for_the_template() {
  cf_reset
  make_sandbox
  local self="${BASH_SOURCE[0]}" probe="$SB_TMP/mintprobe.sh"

  # Excise this case's own body: its derivation names the creation scripts it looks for,
  # so a census over the whole file reports this case as an unguarded minter.
  awk -v fn="case_minting_cases_probe_for_the_template" '
    $0 ~ "^" fn "\\(\\) \\{" { skip=1 }
    skip && /^\}$/            { skip=0; next }
    !skip
  ' "$self" > "$probe"
  grep -q '^case_minting_cases_probe_for_the_template() {' "$probe" \
    && _fixture_die "case_minting_cases_probe_for_the_template: the excision left this case's own body in the probe."

  # For each case function: does it invoke a creator, and does it probe?
  local rows n=0 bad=0 row
  rows="$(awk '
    /^case_[a-z_0-9]+\(\) \{/ { fn=$0; sub(/\(\).*/,"",fn); mint=0; probe=0; next }
    /^\}$/ {
      if (fn != "" && mint) printf "%s|%d\n", fn, probe
      fn=""; next
    }
    # WIDE ON PURPOSE: two cases reached the creators through a GLOB
    # ("$SB_WORK"/scripts/new-*.sh) and a basename, and a pattern listing the four names
    # literally found neither. Both were real gaps — one of them aborted the whole run
    # with a fixture failure when the template was removed, which is worse than the FAIL
    # this item was filed about.
    # kit_init_sandbox is in here because kit-init COPIES the template into its tree and
    # refuses the preflight without it — the same capability, reached by a helper rather
    # than by a creator. The signal is the CALL, not a mention: `kit-init.sh` in a comment
    # matched two cases that never run it.
    # ...AND A COMMENT IS NOT A CALL. The note above says "the signal is the CALL, not a
    # mention" and the pattern still matched mentions: a comment naming subtask.sh, added to
    # an unrelated case on 2026-09-04, made this guard report that case as unguarded. Skip
    # comment lines before testing, so the rule matches the sentence that states it.
    fn != "" && $0 !~ /^[[:space:]]*#/ && /new-[a-z*]*\.sh|subtask\.sh|kit_init_sandbox/ { mint=1 }
    fn != "" && /has_issue_template/                                            { probe=1 }
  ' "$probe")"

  while IFS= read -r row; do
    [ -n "$row" ] || continue
    n=$((n + 1))
    [ "${row#*|}" = "1" ] && continue
    bad=$((bad + 1))
    cf "${row%%|*} invokes a creation script and never calls has_issue_template — on a tree without .claude/templates/ISSUE.template.md it FAILS instead of skipping, reporting a missing capability as a defect in the subject"
  done <<EOF
$rows
EOF

  # ── INSTRUMENT CHECK: a negative census whose derivation finds nothing is green
  #    forever. Assert it still finds the population it is judging.
  [ "$n" -ge 5 ] \
    || _fixture_die "case_minting_cases_probe_for_the_template: the derivation found only $n card-minting case(s) — the creator names or the case-function shape changed, and 'all of them probe' would then be true of almost nothing."

  finish "all $n cases that invoke a creation script probe for the issue template first, so a tree without it SKIPS rather than reporting a missing capability as a defect — and the population is derived from the file, so the next minting case cannot arrive unguarded"
  teardown
}

case_frontmatter_scan_cap_is_enforced() {
  cf_reset
  make_sandbox
  local cap i out

  # DERIVE the cap. It is a bare numeric assignment, not the quoted form cb_default reads.
  cap="$(sed -n 's/^FRONTMATTER_SCAN_LINES=\([0-9][0-9]*\).*/\1/p' "$SB_WORK/scripts/check-board.sh" | head -1)"
  case "$cap" in
    ''|*[!0-9]*) _fixture_die "case_frontmatter_scan_cap_is_enforced: could not derive FRONTMATTER_SCAN_LINES from check-board.sh (got '$cap') — a re-typed cap would go stale the day it is retuned, and this case would assert nothing while reading green." ;;
  esac
  [ "$cap" -ge 5 ] \
    || _fixture_die "case_frontmatter_scan_cap_is_enforced: the derived cap is $cap, too small to seed either side of — the derivation is reading the wrong thing."

  # ── CARD A: normal frontmatter, plus a horizontal rule FAR past the cap. Must parse.
  seed_issue todo "$SB_PREFIX-300" bodyrule chore "A card with a body rule"
  local a="$SB_WORK/progress/todo/$SB_PREFIX-300-bodyrule.md"
  i=0; while [ "$i" -lt $((cap + 10)) ]; do printf 'filler line %s\n' "$i" >> "$a"; i=$((i + 1)); done
  printf -- '---\n\nA horizontal rule in the body, well past the cap.\n' >> "$a"

  # ── CARD B: NO frontmatter at the top; a complete fence pair PAST the cap. The cap is
  #    what stops that from being read as frontmatter, so check (d) must report this card
  #    as having no id: line — the finding it would NOT report if the cap were lifted.
  local b="$SB_WORK/progress/todo/$SB_PREFIX-301-latefence.md"
  : > "$b"
  printf '# A card whose fence sits below the cap\n\n' >> "$b"
  i=0; while [ "$i" -lt $((cap + 3)) ]; do printf 'preamble %s\n' "$i" >> "$b"; i=$((i + 1)); done
  printf -- '---\nid: %s-301\nstatus: todo\n---\n\nBody.\n' "$SB_PREFIX" >> "$b"
  publish_sandbox

  out="$(cb_run 2>&1)" || true

  # ── INSTRUMENT CHECK: check (d) ran at all. Every assertion below is about its output.
  printf '%s\n' "$out" | grep -q '^\[d\]' \
    || _fixture_die "case_frontmatter_scan_cap_is_enforced: no [d] section in the report — the arm did not run and both assertions below would be about an empty string."

  # (A) the normal card is NOT reported. Its block closed on line 3; the body rule is noise.
  printf '%s\n' "$out" | grep -q "$SB_PREFIX-300-bodyrule" \
    && cf "(A) a card with normal frontmatter and a horizontal rule in its body was reported by check (d) — a body '---' is being read as a fence"

  # (B) the late fence is NOT accepted as frontmatter. This is the arm the cap exists for.
  printf '%s\n' "$out" | grep -q "$SB_PREFIX-301-latefence" \
    || cf "(B) a fence pair $((cap + 5)) lines down was READ AS FRONTMATTER — the cap is not being applied, so any '---' anywhere in a card can start a frontmatter block and whatever follows it is parsed as fields"

  finish "check (d)'s frontmatter scan cap (derived: $cap lines) is enforced in both directions — a normal card with a horizontal rule far down its body still parses, and a complete fence pair below the cap is NOT accepted as frontmatter; the fixture is sized from the derived cap, so retuning it cannot leave this case asserting nothing. Not covered: whether $cap is the RIGHT value"
  teardown
}

case_trunk_chain_announces_every_fallback() {
  cf_reset
  if ! has_release; then skp "every link of the trunk chain below the first announces itself" "scripts/release.sh absent"; return; fi
  make_sandbox
  seed_release_files 1.1.0
  publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  local out rc

  # ── STEP 1: origin/HEAD is set. NOBODY announces anything. This is the instrument
  #    check for both arms below — a tool that announced here would satisfy them free.
  out="$(cb_run 2>&1)" || true
  printf '%s' "$out" | grep -q 'GUESSED' \
    && cf "(step 1) check-board announced a guess while $SB_TRUNK is set as origin/HEAD"
  out="$(run_release 1.1.0 --dry-run 2>&1)" || true
  printf '%s' "$out" | grep -q 'STEP 2 of the chain\|is a GUESS' \
    && cf "(step 1) release.sh announced a fallback while origin/HEAD is set"

  # ── STEP 2: drop origin/HEAD, set init.defaultBranch. BOTH must say so.
  git -C "$SB_WORK" symbolic-ref -d "refs/remotes/origin/HEAD" >/dev/null 2>&1 || true
  git -C "$SB_WORK" config init.defaultBranch "$SB_TRUNK"
  out="$(cb_run 2>&1)" || true
  printf '%s' "$out" | grep -q 'step 2' \
    || cf "(step 2) check-board resolved the trunk from init.defaultBranch and said nothing — every trunk arm below it is then a statement about a guessed name: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  out="$(run_release 1.1.0 --dry-run 2>&1)" || true
  printf '%s' "$out" | grep -q 'STEP 2 of the chain' \
    || cf "(step 2) release.sh cut against init.defaultBranch with no warning — the quieter half of the guessed-trunk defect, and the likelier one: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # ── STEP 3: drop init.defaultBranch too. BOTH must say so, and say it differently —
  #    the step-3 message must not be reachable while step 2 still has an answer.
  git -C "$SB_WORK" config --unset init.defaultBranch >/dev/null 2>&1 || true
  out="$(cb_run 2>&1)" || true
  printf '%s' "$out" | grep -q 'step 3' \
    || cf "(step 3) check-board fell to the last-resort constant and said nothing: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  out="$(run_release 1.1.0 --dry-run 2>&1)" || true
  printf '%s' "$out" | grep -q 'is a GUESS' \
    || cf "(step 3) release.sh fell to the last-resort constant with no warning: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # ── AND THE THREE AGREE ON THE ANSWER, which is the other half of "one chain".
  #    Derived from the library, so the expected value has one author.
  local last_resort
  last_resort="$(sed -n 's/^KWT_TRUNK_LAST_RESORT="\${KWT_TRUNK_LAST_RESORT:-\([^}]*\)}"/\1/p' \
                   "$SB_WORK/scripts/lib/kanban-worktree.sh" | head -1)"
  [ -n "$last_resort" ] \
    || _fixture_die "case_trunk_chain_announces_every_fallback: could not read the last-resort constant — the expected value would be empty and both arms below would pass on nothing."
  printf '%s' "$out" | grep -qF "'$last_resort'" \
    || cf "release.sh's step-3 guess is not the library's constant '$last_resort' — the three implementations agree on the WARNING and not on the ANSWER"
  out="$(cb_run 2>&1)" || true
  printf '%s' "$out" | grep -qF "$last_resort" \
    || cf "check-board's step-3 trunk is not the library's constant '$last_resort'"

  finish "all three implementations of the trunk chain announce every link below the first — check-board at steps 2 and 3, release.sh at both (step 2 was silent, and it is where a real cut lands) — none of them announces at step 1, and both agree with the library on the step-3 constant"
  teardown
}

case_probe_victim_selection_survives_pipefail() {
  cf_reset
  make_sandbox
  local big="$SB_TMP/pipebig" i v rc hit=0

  # ── INSTRUMENT CHECK, and it is what makes this case honest: BUILD the hazard before
  #    asserting anything about it. If this environment's pipe buffer cannot produce a
  #    SIGPIPE at all, every assertion below is vacuous — so say so as a SKIP, which is
  #    this file's way of making a statement about the environment rather than the code.
  mkdir -p "$big"
  for i in $(seq 1 3000); do : > "$big/f$i.md"; done
  for i in 1 2 3; do
    if ! ( set -o pipefail; find "$big" -type f | head -1 >/dev/null ); then hit=1; break; fi
  done
  if [ "$hit" -eq 0 ]; then
    skp "probe victim selection survives pipefail" \
        "3000 files did not make 'find | head -1' fail under pipefail here — this environment cannot produce the hazard, so the assertions would be vacuous"
    teardown; return
  fi

  # THE EFFECT — the STATUS and the value. Asserting only the value is a green that could
  # not go red: the raw pipeline gets the value right and the status wrong, which is the
  # entire defect.
  rc=0; v="$(probe_pick "$big" -type f)" || rc=$?
  [ "$rc" -eq 0 ] \
    || cf "probe_pick exited $rc on a corpus where the raw pipeline SIGPIPEs — the status is still the producer's death, not the answer"
  [ -n "$v" ] && [ -f "$v" ] \
    || cf "probe_pick returned '$v', which is not an existing file — the replacement gets the status right and the answer wrong, which is worse than what it replaced"

  # …and it still returns NOTHING, nonzero, when there is genuinely nothing to find.
  rc=0; v="$(probe_pick "$SB_TMP/pipebig" -name 'nothing-matches-this' -type f)" || rc=$?
  [ -z "$v" ] \
    || cf "probe_pick invented a victim for a pattern that matches nothing: '$v'"

  # THE CENSUS — the four sites are the point, not the helper. A fifth `find … | head -1`
  # typed tomorrow puts the hazard straight back.
  local self="${BASH_SOURCE[0]}" probe="$SB_TMP/pipeprobe.sh" m1='find ' m2='| head -1'
  # EXCISE THIS CASE'S OWN BODY. Its instrument check BUILDS the forbidden pipeline on
  # purpose — that is how it proves the hazard exists here — so a census over the whole
  # file reports the very line that makes the case honest.
  awk -v fn="case_probe_victim_selection_survives_pipefail" '
    $0 ~ "^" fn "\\(\\) \\{" { skip=1 }
    skip && /^\}$/                { skip=0; next }
    !skip
  ' "$self" > "$probe"
  grep -q '^case_probe_victim_selection_survives_pipefail() {' "$probe" \
    && _fixture_die "case_probe_victim_selection_survives_pipefail: the excision left this case's own body in the probe — the census would report its own instrument check."
  local rows
  rows="$(awk -v a="$m1" -v b="$m2" '
    /^[[:space:]]*#/ { next }
    index($0,a) && index($0,b) { print NR ": " $0 }
  ' "$probe")"
  [ -z "$rows" ] \
    || cf "a find/head pipeline is back, and this file's header forbids it by name: $(printf '%s' "$rows" | tr '\n' ' ' | cut -c1-200)"

  finish "probe_pick returns the first match with the RIGHT STATUS on a corpus that makes 'find | head -1' SIGPIPE under pipefail (the value was never the problem; the status was), returns nothing for a pattern that matches nothing, and no find/head pipeline remains in this file"
  teardown
}

case_release_unmutated_names_the_cut() {
  cf_reset
  if ! has_release; then skp "assert_release_unmutated names the cut it guards" "scripts/release.sh absent"; return; fi
  make_sandbox
  seed_release_files 1.1.0
  publish_sandbox

  # Run an assertion helper with this case's own findings set aside, and echo what IT
  # reported. cf appends to a global, so without this the helper's findings would be
  # indistinguishable from the case's.
  _cf_probe() { local saved="$_cf"; _cf=""; "$@"; local got="$_cf"; _cf="$saved"; printf '%s' "$got"; }

  # ── INSTRUMENT CHECK: on an untouched sandbox the helper reports NOTHING. Without
  #    this, "it fired" below is satisfied by a helper that fires on everything.
  local quiet; quiet="$(_cf_probe assert_release_unmutated 2.0.0)"
  [ -z "$quiet" ] \
    || cf "(instrument) assert_release_unmutated already reports on an UNTOUCHED sandbox, so every 'it fired' below would be free: $quiet"

  # THE MUTATION: a tag at the cut version, and only that.
  git -C "$SB_WORK" tag -a v2.0.0 -m 'planted' >/dev/null 2>&1
  git -C "$SB_WORK" rev-parse -q --verify refs/tags/v2.0.0 >/dev/null \
    || _fixture_die "case_release_unmutated_names_the_cut: the planted tag was not created — this sandbox has no committer identity, and the assertion below would pass by there being nothing to find."

  local got; got="$(_cf_probe assert_release_unmutated 2.0.0)"
  printf '%s' "$got" | grep -qF 'v2.0.0' \
    || cf "a tag at the cut version sits in the sandbox and assert_release_unmutated 2.0.0 did not name it — the tag arm is looking somewhere other than the cut it was handed: '$got'"

  # …and it does NOT fire for a cut it was not handed. Otherwise the arm above could be
  # satisfied by a helper that reports every tag it finds.
  local other; other="$(_cf_probe assert_release_unmutated 3.0.0)"
  printf '%s' "$other" | grep -qF 'v2.0.0' \
    && cf "assert_release_unmutated 3.0.0 reported the v2.0.0 tag — the arm is not scoped to the cut it was handed"

  # THE OTHER THREE ARMS still see their own subjects: mutate pkg.conf alone.
  perl -i -pe 's/^version = .*/version = "9.9.9"/' "$SB_WORK/pkg.conf"
  local pk; pk="$(_cf_probe assert_release_unmutated 3.0.0)"
  printf '%s' "$pk" | grep -qF 'pkg.conf' \
    || cf "pkg.conf was mutated and the helper did not name it: '$pk'"

  unset -f _cf_probe
  finish "assert_release_unmutated checks the tag at the cut version it is HANDED — naming it when present, staying silent for a cut it was not handed — and its other arms still name their own subjects; the pre-release version comes from the seeder rather than a second literal"
  teardown
}

# =============================================================================
# CASE — EVERY LANDING PROLOGUE IS THE WHOLE FOUR-STEP.
#
# THIS CASE EXISTS BECAUSE OF A PARTIAL DECLINE. It was proposed that the landing
# prologues be collapsed into one `fpr_sandbox` helper. Declined, measured: most of them
# use a CARD slug that differs from the BRANCH slug, and that divergence is what
# exercises finish-pr.sh reading the card's `branch:` field instead of inferring it from
# the filename. A helper that erases it loses coverage; one that keeps it needs five
# positional arguments and hides the very difference a reader should see.
#
# What the collapse WOULD have bought is that an incomplete prologue becomes impossible.
# This buys that mechanically instead: the copies stay, and a copy that dropped a step is
# named by line number rather than found by diffing cases against each other.
# =============================================================================
case_landing_prologue_is_complete() {
  cf_reset
  make_sandbox
  local self="${BASH_SOURCE[0]}" probe="$SB_TMP/prologueprobe.sh"

  # EXCISE THIS CASE'S OWN BODY FROM THE PROBE. It scans the file it lives in, and its
  # own derivation names every token it searches for — so without this it reports itself,
  # by line number, forever. Building the patterns from variables does not help: they
  # would still sit inside the window the census looks at.
  awk -v fn="case_landing_prologue_is_complete" '
    $0 ~ "^" fn "\\(\\) \\{" { skip=1 }
    skip && /^\}$/           { skip=0; next }
    !skip
  ' "$self" > "$probe"
  # Anchored at the DEFINITION: the name also appears in the CASES registry, which the
  # excision does not (and must not) remove.
  grep -q '^case_landing_prologue_is_complete() {' "$probe" \
    && _fixture_die "case_landing_prologue_is_complete: the excision did not remove this case's own body from the probe — every finding below would be about this case's own derivation."

  # A LANDING PROLOGUE is a dev_complete card seeded right after make_sandbox in a case
  # that then invokes finish-pr.sh. That last clause is the operand definition and it
  # matters: `seed_issue dev_complete` also appears as ordinary BOARD CONTENT in cases
  # about other subjects, and counting those would report findings against fixtures that
  # have no reason to publish or branch at all.
  local rows n
  rows="$(awk '
    { L[NR]=$0 }
    END {
      for (i=1;i<=NR;i++) {
        if (L[i] !~ /seed_issue dev_complete/) continue
        ms=0; for (j=i-1;j>=i-8 && j>=1;j--) if (L[j] ~ /make_sandbox/) { ms=j; break }
        if (!ms) continue
        fpr=0; for (j=i+1;j<=i+30 && j<=NR;j++) if (L[j] ~ /finish-pr\.sh/) { fpr=1; break }
        if (!fpr) continue
        pub=0; br=0
        for (j=i+1;j<=i+12 && j<=NR;j++) {
          if (L[j] ~ /publish_sandbox/) pub=1
          # seed_branch OR a hand-rolled branch: one case creates an EMPTY branch off the
          # trunk on purpose, which the helper cannot express. The step is "the branch
          # exists", not "the helper was called".
          if (L[j] ~ /seed_branch |git -C "\$SB_WORK" branch /) br=1
        }
        miss=""
        if (!pub) miss=miss " publish_sandbox"
        if (!br)  miss=miss " a branch"
        if (miss != "") print i "|" miss
        seen++
      }
      print "COUNT|" seen+0
    }
  ' "$probe")"
  n="$(printf '%s\n' "$rows" | sed -n 's/^COUNT|//p')"

  # ── INSTRUMENT CHECK: the derivation must still find prologues. A pattern that stopped
  #    matching reports "none incomplete" forever.
  [ "${n:-0}" -ge 8 ] \
    || _fixture_die "case_landing_prologue_is_complete: the derivation found only ${n:-0} landing prologue(s) — the shape changed, and 'none incomplete' would then be true of nothing."

  local row
  while IFS= read -r row; do
    case "$row" in COUNT\|*|'') continue ;; esac
    cf "the landing prologue at line ${row%%|*} is missing:${row#*|} — a card seeded dev_complete that is never published, or has no branch, is a fixture finish-pr.sh cannot act on, and the case above it would pass for the wrong reason"
  done <<EOF
$rows
EOF

  finish "all $n landing prologues in this file are the complete four-step (make_sandbox, seed_issue dev_complete, seed_branch, publish_sandbox) — the copies were kept on purpose, because most carry a card-slug/branch-slug divergence a collapse would erase, so this is what makes an incomplete copy visible"
  teardown
}

case_fixture_append_has_one_authoring_site() {
  cf_reset
  make_sandbox
  local self="${BASH_SOURCE[0]}"
  local m1='perl -i -pe'
  local m2='$_ .='
  local probe="$SB_TMP/appendprobe.sh"
  cp "$self" "$probe"

  # THE DECLARED AUTHORS. Anything else that plants is a bypass.
  local allowed=" _declare_gate _guard_declare _plant_in_function rel_insert "

  _append_census() {  # <file> — "line|enclosing-function" for every anchored append
    awk -v a="$m1" -v b="$m2" '
      # NOT anchored at the closing brace: several definitions here carry a trailing
      # `# <args>` comment, and an anchored tracker attributes their body to whatever
      # function was defined above them — which is a WRONG author, not a missing one.
      /^[a-z_]+\(\) \{/ { fn=$0; sub(/\(\).*$/,"",fn); next }
      /^[[:space:]]*#/   { next }
      index($0,a) && index($0,b) { print NR "|" (fn == "" ? "(top level)" : fn) }
    ' "$1"
  }

  local rows n
  rows="$(_append_census "$probe")"
  n="$(printf '%s\n' "$rows" | grep -c '|' || true)"

  # ── INSTRUMENT CHECK, and it is mandatory here: arm 1 is a NEGATIVE census, so an
  #    expression that stopped matching satisfies "no bypasses" forever. Assert the
  #    derivation still finds the authors themselves.
  [ "$n" -ge 4 ] \
    || _fixture_die "case_fixture_append_has_one_authoring_site: the census found only $n anchored append(s) in the whole file — the expression stopped matching, and 'zero bypasses' would then be true of nothing."

  # ARM 1 — every append sits inside a declared author.
  local row ln fn
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    ln="${row%%|*}"; fn="${row#*|}"
    case "$allowed" in
      *" $fn "*) ;;
      *) cf "line $ln plants through an anchored perl append inside '$fn', which is not one of the declared authors ($allowed) — a fifth copy of the four-step idiom, and the steps it drops are the ones that make a failed plant visible" ;;
    esac
  done <<EOF
$rows
EOF

  # ARM 2 — THE EFFECT, and arm 1 cannot see it: a spine that swallowed the per-caller
  # message would pass the census and still cost the reader the subject of the failure.
  local v="$SB_WORK/scripts/verify.sh" out rc
  # Positive leg first: on an INTACT anchor the helper succeeds. Without this, "it
  # aborts" is satisfied by a helper that aborts unconditionally.
  ( _declare_gate 'census-probe|select|/bin/echo ok' ) >/dev/null 2>&1 \
    || cf "(arm 2) _declare_gate failed on an INTACT anchor — the abort below would prove nothing"
  # Now break the anchor and require the abort to name the caller's own record.
  perl -i -pe 's/^GATES=\($/GATEZ=(/' "$v"
  rc=0; out="$( _declare_gate 'wanted-gate|select|/bin/echo x' 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] \
    || cf "(arm 2) _declare_gate returned 0 with its anchor destroyed — the plant silently did nothing and the case downstream would run against an empty gate table"
  printf '%s' "$out" | grep -qF 'wanted-gate' \
    || cf "(arm 2) the abort does not name the record it failed to declare: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"

  finish "every anchored fixture append in this file ($n of them) sits inside one of four declared authors — no fifth copy of the four-step plant idiom — and a plant whose anchor has moved aborts naming the record it failed to declare rather than returning 0 on a file it did not change"
  teardown
}

case_scaffolding_fixture_matches_the_tree() {
  cf_reset
  make_sandbox
  local doc probe_hits

  # (a) BOTH shipped root documents carry the mark the harness derived. One of the two is
  #     where it was derived FROM, so this arm's substance is the other one — a rename
  #     that touched CLAUDE.md and forgot README.md is the realistic drift.
  # Read the REAL tree, not the sandbox: make_sandbox does not seed the root documents
  # (a day-one tree has them, a sandbox is built without them), so a sandbox miss here
  # would be about the fixture and not about the kit that ships.
  for doc in CLAUDE.md README.md; do
    grep -qF "$KIT_SCAFFOLD_MARK" "$REAL_REPO_ROOT/$doc" \
      || cf "(a) the shipped $doc does not carry '$KIT_SCAFFOLD_MARK' — the two root documents have drifted apart"
  done

  # (b) check-board.sh LOOKS for exactly that mark. Derived from the script, not retyped:
  #     a literal here would be a fourth author of the very constant under test.
  grep -qF "grep -qF '$KIT_SCAFFOLD_MARK'" "$SB_WORK/scripts/check-board.sh" \
    || cf "(b) check-board.sh does not probe for '$KIT_SCAFFOLD_MARK' — the tool and the documents disagree, so the graduation arm is looking for a mark nobody writes"

  # (c) THE SAME TWO DOCUMENTS, not one and not three. The arm's file list is the other
  #     half of the fixture's premise and it was re-typed at five sites alongside the mark.
  probe_hits="$(grep -c "for f in CLAUDE.md README.md" "$SB_WORK/scripts/check-board.sh" || true)"
  [ "$probe_hits" -ge 1 ] \
    || cf "(c) check-board.sh's graduation arm no longer iterates CLAUDE.md and README.md — seed_scaffolding_tree seeds a pair the tool does not read"

  # (d) THE EFFECT, end to end. Everything above is textual; this arm proves the seeded
  #     tree actually trips the arm. Without it, three agreeing strings could still be the
  #     wrong strings. The receipt is what makes the graduation arm REPORT rather than
  #     stay unrun — the same premise the rest of this family establishes.
  seed_scaffolding_tree
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  publish_sandbox
  local out; out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep -qi 'still scaffolding' \
    || cf "(d) a tree seeded by seed_scaffolding_tree does not read as still-scaffolding to check-board.sh: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  finish "the scaffolding sentinel's three authors agree: both shipped root documents carry the mark, check-board.sh's graduation arm probes for that same mark on that same pair, and a tree seeded by seed_scaffolding_tree actually reads as still-scaffolding — the fixture derives from the DOCUMENTS, never from the probe, so a rename cannot make the two agree by construction"
  teardown
}

case_kit_init_copy_list_minimum_is_real() {
  cf_reset
  if ! has_issue_template; then skp "kit-init's copy-list minimum is a REAL minimum" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  publish_sandbox
  local out rc f n=0
  local ki="$SB_WORK/scripts/kit-init.sh"

  # DERIVE the list out of the shipped array — never retype it.
  local list; list="$(awk '/^COPY_LIST=\($/{f=1;next} f&&/^\)$/{exit} f{gsub(/^[[:space:]]+|[[:space:]]+$/,"");print}' "$ki")"
  [ -n "$list" ] \
    || _fixture_die "case_kit_init_copy_list_minimum_is_real: could not derive COPY_LIST out of kit-init.sh — the array was renamed or reshaped, and a case that derives nothing passes forever."

  # ── INSTRUMENT CHECK: kit-init SUCCEEDS on the untouched fixture. Every "it refused"
  #    below is otherwise satisfied by a fixture that never worked in the first place.
  local pristine="$SB_TMP/cl-pristine"
  rm -rf "$pristine"; cp -R "$SB_WORK" "$pristine"
  rc=0; out="$( "$pristine/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] \
    || _fixture_die "case_kit_init_copy_list_minimum_is_real: kit-init exits $rc on the UNMUTATED fixture: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # EVERY member is load-bearing: remove exactly one, and the preflight must NAME it.
  # One at a time, because removing all seven cannot tell a real minimum from a list
  # whose refusal happens to mention the first entry.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n=$((n + 1))
    local probe="$SB_TMP/cl-probe"
    rm -rf "$probe"; cp -R "$SB_WORK" "$probe"
    [ -e "$probe/$f" ] \
      || { cf "COPY_LIST names '$f' but the shipped kit does not contain it — the list has rotted away from the tree"; continue; }
    rm -rf "${probe:?}/$f"
    rc=0; out="$( "$probe/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1 )" || rc=$?
    [ "$rc" -ne 0 ] \
      || cf "kit-init exited 0 with '$f' missing — that entry is in COPY_LIST but nothing depends on it being there"
    printf '%s' "$out" | grep -qF "$f" \
      || cf "kit-init refused with '$f' missing but did NOT name it: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"
    rm -rf "$probe"
  done <<EOF
$list
EOF

  # A LIST THAT SHRANK TO NOTHING would satisfy the loop above vacuously.
  [ "$n" -ge 5 ] \
    || cf "COPY_LIST derived only $n entries — the minimum has shrunk or the derivation is reading the wrong array"

  finish "kit-init's copy-list minimum is a REAL minimum: every one of its $n entries, derived out of the shipped array rather than retyped, makes the preflight refuse AND name that path when it is absent (the decline of 104 rests on this)"
  teardown
}

case_seam_shape_reformat_is_loud() {
  cf_reset
  if ! has_issue_template; then skp "a reformatted seam declaration is refused loudly" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  # kit-init needs a prepared .claude/ and a published trunk; a bare make_sandbox gives
  # neither and it refuses at PREFLIGHT with three unmet preconditions — a refusal that
  # would satisfy every "it refused" assertion below for entirely the wrong reason.
  kit_init_sandbox
  publish_sandbox
  local c="$SB_WORK/scripts/config.sh" k="$SB_WORK/scripts/lib/kanban-worktree.sh"
  local out rc eff

  # ── INSTRUMENT CHECK, first: kit-init SUCCEEDS on this fixture UNMUTATED. Without this
  #    the case cannot tell a shape refusal from a fixture that never worked. Run in a
  #    throwaway copy so the real sandbox stays unstamped for the mutations below.
  local pristine="$SB_TMP/seam-pristine"
  rm -rf "$pristine"; cp -R "$SB_WORK" "$pristine"
  rc=0; out="$( "$pristine/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] \
    || _fixture_die "case_seam_shape_reformat_is_loud: kit-init exits $rc on the UNMUTATED fixture — every refusal this case asserts would be free. Output: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  perl -i -pe 's/^ISSUE_PREFIX="\$\{ISSUE_PREFIX:-([^}]*)\}"$/ISSUE_PREFIX=\${ISSUE_PREFIX:-$1}/' "$c"
  grep -qxF "ISSUE_PREFIX=\${ISSUE_PREFIX:-$KIT_NEUTRAL_PREFIX}" "$c" \
    || _fixture_die "case_seam_shape_reformat_is_loud: the reformat did not apply — the declaration moved and this case is mutating nothing."
  # COMMIT IT. kit-init refuses a dirty checkout before it reads anything, and that
  # refusal would satisfy "(a) it refused" while proving nothing about the shape.
  git -C "$SB_WORK" add -A && sbcommit -q -m "reformat the ISSUE_PREFIX declaration" >/dev/null 2>&1

  # ── INSTRUMENT CHECK. Prove the mutation changed the SHAPE and not the VALUE. If
  #    sourcing yields something different, every refusal below is attributable to a
  #    changed value and this case proves nothing about the shape.
  eff="$( . "$c" >/dev/null 2>&1; printf '%s' "$ISSUE_PREFIX" )"
  if [ "$eff" != "$KIT_NEUTRAL_PREFIX" ]; then
    skp "a reformatted seam declaration is refused loudly" \
        "sourcing the reformatted config.sh yields '$eff', not '$KIT_NEUTRAL_PREFIX' — the mutation is not semantics-preserving here, so a refusal below would not be about the shape"
    teardown; return
  fi

  # EFFECT (a) — kit-init REFUSES and NAMES the file. Not "proceeds on an empty default".
  rc=0; out="$( "$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(a) kit-init.sh exited 0 with an unparseable ISSUE_PREFIX declaration — it proceeded on an empty default"
  printf '%s' "$out" | grep -q 'config\.sh' || cf "(a) the refusal does not NAME scripts/config.sh: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-140)"
  grep -q 'ISSUE_PREFIX:-SBX' "$c" && cf "(a) config.sh was STAMPED during a refusal — the run mutated before it checked"

  # EFFECT (b) — the SAME for the other declaring file. Four consumers parse this one and
  #    it is not in the seam file at all, which is how it kept escaping the guard.
  perl -i -pe 's/^KWT_TRUNK_LAST_RESORT="\$\{KWT_TRUNK_LAST_RESORT:-([^}]*)\}"$/KWT_TRUNK_LAST_RESORT=\${KWT_TRUNK_LAST_RESORT:-$1}/' "$k"
  grep -q '^KWT_TRUNK_LAST_RESORT=\${' "$k" \
    || _fixture_die "case_seam_shape_reformat_is_loud: the lib reformat did not apply — that declaration moved too."
  git -C "$SB_WORK" add -A && sbcommit -q -m "reformat the trunk last-resort declaration" >/dev/null 2>&1
  rc=0; out="$( "$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(b) kit-init.sh exited 0 with an unparseable KWT_TRUNK_LAST_RESORT declaration"

  # EFFECT (c) — the READ-ONLY consumer degrades ANNOUNCED, never to a guessed branch.
  #    With both auto-detections removed, check-board has nothing but the declaration left.
  git -C "$SB_WORK" symbolic-ref -d refs/remotes/origin/HEAD >/dev/null 2>&1 || true
  git -C "$SB_WORK" config --unset init.defaultBranch >/dev/null 2>&1 || true
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/check-board.sh" 2>&1 )" || true
  printf '%s' "$out" | grep -qF '<unresolved trunk>' \
    || cf "(c) check-board.sh did not announce the unresolved trunk: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-140)"

  finish "a semantics-preserving reformat of either derived seam declaration — config.sh's or the lib's — is refused loudly by kit-init.sh naming the file, and announced rather than guessed by the read-only consumer; the value still sources correctly, which is what makes the shape the thing under test"
  teardown
}

case_ship_state() {
  cf_reset
  local rv="$REAL_SCRIPTS/verify.sh" rr="$REAL_SCRIPTS/release.sh" rc_cfg="$REAL_SCRIPTS/config.sh"
  local why=""

  # Is this tree the shipped frame, or an adopted project? Two signals, either
  # sufficient, and the one that fired is reported.
  if [ -f "$rc_cfg" ] && grep -q "^$KIT_STAMP_MARK" "$rc_cfg" 2>/dev/null; then
    why="scripts/config.sh carries kit-init's stamp receipt — this tree has been adopted"
  elif [ -f "$rv" ] && [ "$(_neu_array_records "$rv" GATES)" -ne 0 ]; then
    why="scripts/verify.sh declares $(_neu_array_records "$rv" GATES) gate(s) — this project has filled its own table"
  fi
  if [ -n "$why" ]; then
    skp "ship state: the kit's own config blocks still ship neutral" "$why"
    return
  fi

  # An array that is GONE reads as an array with zero records, so the fence is
  # asserted before the count. Presence first, then the property — otherwise a
  # renamed array is indistinguishable from a clean one.
  _ship_array_empty() {  # <file> <ARRAY>
    local f="$1" a="$2" n
    grep -qE "^${a}=\($" "$f" || { cf "${f##*/}: no '${a}=(' declaration — it was renamed or removed, so 'empty' here would mean nothing"; return; }
    n="$(_neu_array_records "$f" "$a")"
    [ "$n" -eq 0 ] || cf "${f##*/}: ${a} ships with ${n} declared record(s) — the frame must ship empty"
  }
  _ship_line() {  # <file> <exact line>
    grep -qxF "$2" "$1" || cf "${1##*/}: does not ship the line '$2'"
  }

  if [ -f "$rv" ]; then
    _ship_array_empty "$rv" GATES
    _ship_array_empty "$rv" GUARD_SET
    # _ship_array_empty CANNOT SEE A SCALAR, so the guard-floor enumerator needs the
    # line form. Without it the kit could ship a populated GUARD_ENUM — one project's
    # command, in every adopter's tree — and no case would look.
    _ship_line "$rv" 'GUARD_ENUM=""'
  else
    cf "scripts/verify.sh is absent — the gate frame is part of the kit"
  fi

  if [ -f "$rr" ]; then
    _ship_array_empty "$rr" VERSION_FILES
    _ship_array_empty "$rr" PREFLIGHT_GATES
    _ship_array_empty "$rr" RELEASE_DOCS
    _ship_array_empty "$rr" DIST_DOCS
    # Publishing OFF by default is the one that can do outward-facing damage if it
    # ships wrong, so it is asserted by value and not merely by presence.
    _ship_line "$rr" 'RELEASE_PUBLISH=false'
    _ship_line "$rr" 'VERSION_IN_TAG_ONLY=false'
    _ship_line "$rr" 'DIST_ARTIFACT_GLOB=""'
  fi

  local SB_REAL_KWT="$REAL_SCRIPTS/lib/kanban-worktree.sh"

  # The three seam values, in the exact shape kit-init.sh's anchored seds parse.
  # These are also the neutralizer's targets, so this is where the harness's own
  # KIT_NEUTRAL_* constants are held against the tree instead of assumed.
  if [ -f "$rc_cfg" ]; then
    _ship_line "$rc_cfg" "ISSUE_PREFIX=\"\${ISSUE_PREFIX:-${KIT_NEUTRAL_PREFIX}}\""
    _ship_line "$rc_cfg" "PRD_PREFIX=\"\${PRD_PREFIX:-${KIT_NEUTRAL_PRD_PREFIX}}\""
    _ship_line "$rc_cfg" "PROJECT_NAME=\"\${PROJECT_NAME:-${KIT_NEUTRAL_PROJECT_NAME}}\""
  else
    cf "scripts/config.sh is absent — it is the configuration seam itself"
  fi

  # THE FOURTH DECLARATION, and it does NOT live in the seam file. Four consumers parse
  # KWT_TRUNK_LAST_RESORT out of the lib with the same anchored sed they use on config.sh,
  # so it is bound by the same shape rule (config-seam.md § 2) and belongs in the same
  # block. Its absence here is why the shape had three assertions and four authors.
  if [ -f "$SB_REAL_KWT" ]; then
    _ship_line "$SB_REAL_KWT" 'KWT_TRUNK_LAST_RESORT="${KWT_TRUNK_LAST_RESORT:-main}"'
  else
    cf "scripts/lib/kanban-worktree.sh is absent — it declares the trunk last resort"
  fi

  # THE ROLE SET, and it is the newest member of the KIT_NEUTRAL_* block above, so this
  # block's own rule reaches it: neutralizing a seam costs the suite its only incidental
  # witness to the shipped value, and this case is where that debt is paid. It is owed
  # here MORE than the others, not less — the other neutral constants have an unstamped
  # source in kit-init.sh to be checked against, and this one has none, because
  # `kit-init --roles` rewrites every occurrence in every seam that carries it. A drifted
  # literal here would silently neutralize sandboxes to a role set the kit no longer ships.
  local rh="$REAL_SCRIPTS/githooks/commit-msg"
  if [ -f "$rh" ]; then
    _ship_line "$rh" "ROLE_PREFIXES='${KIT_NEUTRAL_ROLE_PREFIXES}'"
  else
    cf "scripts/githooks/commit-msg is absent — it is the role set's authoring site"
  fi

  # The FOURTH seam _kit_neutral_claude now resets, and therefore the fourth the
  # suite stopped being an incidental witness to: the shipped templates carry the
  # prefix as a PLACEHOLDER, not as a token. A kit that shipped a real prefix here
  # would sail through a green run — the sandbox would restore nothing, kit-init
  # would substitute nothing, and the case that checks the stamped id would still
  # pass because the neutralizer had handed it what it expected.
  #
  # Guarded on presence rather than asserted, and the reason is this repository's
  # own storage: the kit is kept DISARMED here (kit/_claude/, not kit/.claude/), so
  # a run in place finds no .claude/templates at all. The kit-init cases skip
  # loudly for exactly that reason; a `cf` here would turn the same environment
  # fact into a FALSE RED, which is the defect measured against this file on
  # 2026-08-26 and worth not re-creating.
  local rt="$REAL_REPO_ROOT/.claude/templates/ISSUE.template.md"
  if [ -f "$rt" ]; then
    grep -qF "$KIT_PREFIX_PLACEHOLDER" "$rt" \
      || cf ".claude/templates/ISSUE.template.md does not ship the prefix placeholder '$KIT_PREFIX_PLACEHOLDER' — the templates ship a stamped token, and every sandbox would then inherit it"
  fi

  finish "ship state: the kit ships an empty gate table and guard floor, empty release seams, RELEASE_PUBLISH=false, the neutral config.sh seam values the neutralizer resets to, the prefix PLACEHOLDER in the shipped ISSUE template, and the shipped ROLE_PREFIXES the neutralizer declares"
}

# =============================================================================
# CASE — isolation self-check: the real repo is untouched by a run.
# (Belt-and-suspenders: every case above deliberately mutates its sandbox; we
#  then assert the real repo's HEAD + board surfaces are unchanged.)
# =============================================================================
REAL_HEAD_BEFORE=""; REAL_STATUS_BEFORE=""
_board_status() {
  # Porcelain status of the surfaces the harness must never mutate. The harness's
  # OWN dir (scripts/test/) is excluded — it is legitimately edited by whoever
  # develops the harness.
  git -C "$REAL_REPO_ROOT" status --porcelain -- scripts progress ARCHIVE.md 2>/dev/null \
    | grep -v ' scripts/test/' || true
}
isolation_snapshot() {
  REAL_HEAD_BEFORE="$(git -C "$REAL_REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "(no HEAD yet)")"
  REAL_STATUS_BEFORE="$(_board_status)"
}
# THIS CASE REPORTS WHAT IT MEASURED, NOT WHO DID IT — and the difference cost a
# diagnostic detour the day it was found. It compares two snapshots of a tree it does
# NOT own exclusively, so a difference means "this changed between t0 and t1" and
# nothing more. It said "the harness added a mutation", and the harness had not: a
# concurrent session was mid-edit in a board script while the run was in flight. The
# tree was clean at t0, so the detection was exactly right; only the attribution was
# invented. The reader was sent to debug the harness's isolation — the one thing the
# evidence did not implicate — and the first reading was that a landing had broken
# the witness, which is materially more alarming than "another window is editing a
# file".
#
# THE AMBIGUITY IS IRREDUCIBLE FROM IN HERE, so the output names it rather than
# resolving it. Recording the tree state at run start does not help and is already
# done — REAL_STATUS_BEFORE is that snapshot, and the comparison below is already a
# delta, so "appeared during the run" is already distinguished from "was already
# dirty". What no snapshot of a tree can distinguish is WHO WROTE: "the harness wrote
# it" and "a peer wrote it" are both just "the path differs between t0 and t1".
# Separating them needs an observation of authorship this process has no way to make.
# So per instruments.md § A.4 the case names its own blind spot in its own output.
case_isolation() {
  cf_reset
  local after status_after
  after="$(git -C "$REAL_REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "(no HEAD yet)")"
  [ "$after" = "$REAL_HEAD_BEFORE" ] \
    || cf "the real repo's HEAD MOVED during the run ($REAL_HEAD_BEFORE → $after). This harness never commits, so the likely cause is a concurrent session landing work in this checkout; a harness that somehow committed is the other, far less likely, candidate"
  # Compare the DELTA, not absolute cleanliness: a pre-existing dirty tree (e.g.
  # uncommitted board-script edits under active development) is fine — a board
  # surface must simply not CHANGE during a run.
  status_after="$(_board_status)"
  if [ "$status_after" != "$REAL_STATUS_BEFORE" ]; then
    cf "a board surface CHANGED during the run — two candidates, and this case cannot tell them apart: (1) the harness broke its own isolation and wrote outside its sandbox, or (2) something else wrote to this checkout while the run was in flight (a concurrent session, an editor, a watcher). Before/after status follows. If a peer holds this checkout, (2) is the likely one and the run's SKIP profile is also unreliable — re-measure on a quiet tree or a built kit. BEFORE: [${REAL_STATUS_BEFORE:-clean}] AFTER: [${status_after:-clean}]"
  fi
  finish "isolation: the real repo's HEAD + board surfaces unchanged across the run (attribution is out of scope — see the case's note)"
}

# =============================================================================
# Runner
# =============================================================================
echo "kit self-test harness — sandboxed board-script cases"
echo "real repo: $REAL_REPO_ROOT"
echo "derived seams: prefix=$SB_PREFIX  trunk=$SB_TRUNK  first role=$SB_ROLE"
echo "consumer seam: ${CONSUMER_SCRIPT:-(unset — that family will SKIP)}"
echo
isolation_snapshot

# ── THE CASE LIST. Explicit for ORDER, derived for COMPLETENESS. ─────────────
# The order is real and cannot be generated: case_isolation must run last (it
# compares the real repo against the snapshot taken above), case_ship_state reads
# the real tree, and the check-board and release families build on cheaper cases
# having already proven their primitives. So the sequence stays hand-written.
#
# WHAT WAS HAND-WRITTEN AND SHOULD NOT HAVE BEEN IS THE MEMBERSHIP. This list used
# to be 38 bare calls with nothing comparing it to the functions that exist, so a
# new case_* function that nobody added here SILENTLY NEVER RAN — and the suite
# reported a full green while carrying a case it had not executed. The assertion
# below closes that. It is not hypothetical: the most recent case added to this
# file was appended by hand, and the change file that named this very defect
# recorded the count as 37 while the tree held 38, because the person adding the
# 38th updated the list and not the prose. THE COUNT IS NOWHERE IN PROSE NOW; the
# comparison below is the only statement of it, and it is derived on both sides.
CASES=(
  case_move_issue
  case_move_issue_probe
  case_move_issue_set_pr_on_a_minted_card
  case_role_literals_are_declared
  case_finish_pr_happy
  case_finish_pr_post_merge_names_its_ref
  case_finish_pr_second_worktree
  case_finish_pr_remote_delete_refused
  case_finish_pr_remote_delete_resurrected
  case_finish_pr_premerge_red
  case_finish_pr_empty_merge
  case_finish_pr_gate_absent_says_write_one
  case_finish_pr_gate_hardening
  case_finish_pr_gate_revision
  case_archive_apply
  case_archive_hedged_flags_never_mutate
  case_one_member_role_tag_refuses_before_mutating
  case_archive_index_carries_the_date
  case_archive_index_refuses_malformed
  case_runner_schema_required_defines
  case_runner_schemas_agree
  case_runner_outcome_vocabulary_agrees
  case_runner_goldenpaths_empty_skips
  case_minted_card_is_unmarked
  case_shipped_runners_parse
  case_skills_carry_no_foreign_namespace
  case_skills_name_no_forge_unconditionally
  case_upstream_name_only_where_kept
  case_dev_index_names_its_subdirs
  case_kit_init_markers_intact
  case_archive_requires_the_retired_store
  case_archive_feature_branch_clean
  case_config_seam_refusal
  case_next_id
  case_commit_msg
  case_push_failure
  case_trunk_fallback_warns
  case_archive_progress_sections
  case_rotation_day_uses_the_board_clock
  case_archive_progress_ordinal_knife
  case_archive_progress_honest_noop
  case_archive_progress_dry_run_writes_nothing
  case_settings_example_glosses_only_real_placeholders
  case_runner_key_guards_admit_every_field_they_read
  case_downtime_queue_claim_drift
  case_workflow_briefs_compose_from_a_sparse_payload
  case_archive_progress_index
  case_verify_frame
  case_guard_floor_unenrolled_from_shipped_empty_set
  case_guard_floor_enumerator_mistyped
  case_guard_floor_enumerator_succeeds_empty
  case_guard_floor_unseen_declared_guard
  case_guard_floor_reconciles_and_says_so
  case_guard_floor_wholly_empty_shipped_state
  case_verdict_enum_projection
  case_verify_unrunnable_vs_fail
  case_check_board_id_clean
  case_check_board_id_duplicate
  case_check_board_id_mismatch
  case_check_board_frontmatter_offset
  case_check_board_registers
  case_check_board_register_absent
  case_check_board_arrow_beats_mention
  case_check_board_reads_the_ref
  case_check_board_arm_e_scopes_to_the_rules_lifetime
  case_check_board_shallow_clone_does_not_narrow
  case_check_board_trailer_scan_shares_the_epoch
  case_check_board_dependency_symmetry
  case_kwt_dirty_guard_reports_widely_refuses_narrowly
  case_check_board_main_checkout_unpushed
  case_check_board_from_a_worktree
  case_check_board_graduation
  case_check_board_graduation_enabled_without_receipt
  case_check_board_graduation_not_run_direction
  case_check_board_graduation_reads_the_trunk
  case_check_board_graduation_verdict_is_not_wired
  case_kit_init_survives_the_documented_first_commit
  case_kit_init_still_fails_on_a_real_finding
  case_kit_init_happy
  case_kit_init_repairs_hook_mode
  case_kit_init_roles_leave_no_seam
  case_lived_probe_has_one_authoring_site
  case_kit_init_refuses_lived_board
  case_kit_init_gate_fill
  case_kit_init_gate_and_remote_refusals
  case_option_parsing_hygiene
  case_creation_slug_shape_is_one_rule
  case_creation_scripts_substitute_hostile_values
  case_first_mile
  case_release_happy
  case_usage_renderer_has_one_authoring_site
  case_help_window_ends_where_its_rule_says
  case_project_credential_blank_is_countable
  case_minted_card_is_drift_clean
  case_minted_card_prompts_for_notes
  case_template_header_survives_the_stamp
  case_leaf_workers_carry_the_common_sections
  case_provisioning_ceiling_keeps_the_seat_rule
  case_agent_model_pins_match_their_declaration
  case_move_issue_leaves_a_dirty_checkout_alone
  case_doctrine_states_no_rule_count
  case_cli_shape_across_the_shipped_set
  case_release_gate_c_skip_shape
  case_release_notes_section_is_more_than_a_heading
  case_release_behind_the_remote
  case_release_honours_the_one_remote_name
  case_release_guards
  case_release_preflight_gates
  case_release_stub_marker
  case_release_doc_arms
  case_release_publish
  case_release_publish_recovery
  case_release_local_only_recovery
  case_release_bash_n
  case_release_spaced_path
  case_consumer_updater
  case_hygiene_instruments_declare_blind_spots
  case_agent_prose_carries_its_riders
  case_partial_prefix_derivation_says_so
  case_travelling_scripts_have_a_sheet
  case_release_hook_rejection_leaves_no_bump
  case_template_links_resolve_from_their_destination
  case_missing_option_value_refuses
  case_shipped_scripts_stay_on_the_floor
  case_help_never_opens_with_the_class_marker
  case_role_set_read_is_one_expression
  case_advisory_headers_carry_the_machine_token
  case_minting_cases_probe_for_the_template
  case_frontmatter_scan_cap_is_enforced
  case_trunk_chain_announces_every_fallback
  case_probe_victim_selection_survives_pipefail
  case_release_unmutated_names_the_cut
  case_landing_prologue_is_complete
  case_fixture_append_has_one_authoring_site
  case_scaffolding_fixture_matches_the_tree
  case_kit_init_copy_list_minimum_is_real
  case_seam_shape_reformat_is_loud
  case_ship_state
  case_isolation
)

# Every case_* function that exists must be in CASES, and vice versa. A mismatch is
# FATAL before any case runs: a suite that cannot enumerate its own subject has
# nothing to say about anything else.
_defined_cases="$(declare -F | sed 's/^declare -f //' | grep '^case_' | sort)"
_listed_cases="$(printf '%s\n' "${CASES[@]}" | sort)"
if [ -z "$_defined_cases" ]; then
  echo "harness: REFUSING — no case_* function is defined. A zero-case run cannot be green." >&2
  exit 2
fi
if [ "${#CASES[@]}" -eq 0 ]; then
  echo "harness: REFUSING — CASES is empty, so nothing would run." >&2
  exit 2
fi
if [ "$_defined_cases" != "$_listed_cases" ]; then
  {
    echo "harness: REFUSING — the case list and the defined cases disagree."
    echo "  defined but NOT listed (these would never run):"
    comm -23 <(printf '%s\n' "$_defined_cases") <(printf '%s\n' "$_listed_cases") | sed 's/^/    /'
    echo "  listed but NOT defined (these would error):"
    comm -13 <(printf '%s\n' "$_defined_cases") <(printf '%s\n' "$_listed_cases") | sed 's/^/    /'
    echo "  Fix the CASES array above. Both sides of this comparison are derived, so"
    echo "  the only way to satisfy it is to actually list the case."
  } >&2
  exit 2
fi
echo "case list: ${#CASES[@]} case(s), and every defined case_* is listed."
echo

for _c in "${CASES[@]}"; do "$_c"; done

echo
echo "════════════════════════════════════════════════════════"
printf 'summary: %d PASS, %d FAIL, %d SKIP\n' "$PASS" "$FAIL" "$SKIP"
echo "════════════════════════════════════════════════════════"
[ "$FAIL" -eq 0 ]
