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
#   • Pure bash + git only. No language runtime, no package manager, no new
#     dependency. It tests the SCRIPTS, not the project.
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
# exists to measure. Measured: the skip is the difference between six hits and five.
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
# KIT_STAMP_MARK / KIT_PREFIX_PLACEHOLDER above is forced rather than chosen: those two
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
  SB_TRUNK="$(sed -n 's/^KWT_TRUNK_LAST_RESORT="\${KWT_TRUNK_LAST_RESORT:-\([A-Za-z0-9._\/-]*\)}"/\1/p' \
                "$REAL_SCRIPTS/lib/kanban-worktree.sh" 2>/dev/null | head -1)"
fi
[ -n "$SB_TRUNK" ] || SB_TRUNK="main"
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
  REC="$rec_body" perl -i -pe '$_ .= "  \"$ENV{REC}\"\n" if /^GATES=\($/' "$v"
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
KIT_TREE_PREFIX="$(sed -n 's/^ISSUE_PREFIX="\${ISSUE_PREFIX:-\([A-Za-z0-9]*\)}"/\1/p' "$REAL_SCRIPTS/config.sh" 2>/dev/null | head -1)"

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
# same three seams kit-init stamps and by the same substitution run backwards.
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
  cur="$(sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p" "$cm" | head -1)"
  [ -n "$cur" ] \
    || _fixture_die "_neu_roles: no ROLE_PREFIXES line in the sandbox's commit-msg — the seam was renamed or moved, so the role vocabulary was NOT neutralized and every --role literal in this file would be judged against whatever the adopter declared."
  if [ "$cur" != "$KIT_NEUTRAL_ROLE_PREFIXES" ]; then
    for f in "$cm" "$SB_WORK/scripts/move-issue.sh" "$SB_WORK/scripts/check-board.sh"; do
      [ -f "$f" ] || continue
      # The '@' delimiter is kit-init's, for kit-init's reason: the value is a
      # '|'-separated ERE alternation and would cut an s|…|…| in half with its own data.
      NEU_CUR="$cur" NEU_NEW="$KIT_NEUTRAL_ROLE_PREFIXES" \
        perl -i -pe 's@\Q$ENV{NEU_CUR}\E@$ENV{NEU_NEW}@g' "$f"
    done
  fi
  # POSTCONDITION, asserted whether or not anything was rewritten — the anchor-and-property
  # shape, not "something changed": on the kit's own tree the set already IS the shipped
  # one and the correct behaviour is to change nothing.
  grep -qF "ROLE_PREFIXES='$KIT_NEUTRAL_ROLE_PREFIXES'" "$cm" \
    || _fixture_die "_neu_roles: the sandbox's commit-msg does not carry the shipped role set after the reset (it reads '$cur')."
}

_kit_neutral_config() {
  local c="$SB_WORK/scripts/config.sh"
  local v="$SB_WORK/scripts/verify.sh"
  local r="$SB_WORK/scripts/release.sh"

  # ── config.sh: the three values kit-init.sh stamps on day one. The exact line
  #    SHAPE matters, not just the value — kit-init parses these with anchored
  #    seds (`^ISSUE_PREFIX="\${ISSUE_PREFIX:-\([A-Za-z0-9]*\)}"`), so the
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

  # ── the role set, across the three seams kit-init stamps.
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
publish_sandbox() {
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[PM] seed sandbox board" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" remote add origin "$SB_ORIGIN" >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" remote set-head origin "$SB_TRUNK" >/dev/null 2>&1
}

# On the remote's trunk: does path exist in the tree?
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
    cf "(control) could not copy this harness to plant into — the control did not run, so the green above is unproven"
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
# THAT IS THE POINT OF IT. The seven existing finish-pr cases run with
# FINISH_PR_TEST_ALLOW_STUB=1, and the revision check is wrapped in
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
# THREE DIRECTIONS. The third is what stops the fix from being an unconditional
# refusal, which would pass the first two and break every landing in the kit:
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

  finish "finish-pr landing gate, run WITHOUT the stub marker: a trunk checkout with the branch elsewhere REFUSES on the revision mismatch, a locally-modified gate REFUSES on the modification, both leaving the branch and the issue untouched — and the conforming posture still lands"
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
  local victim; victim="$(find "$probe" -name '*.md' -type f | head -1)"
  if [ -z "$victim" ]; then
    cf "(control) could not copy a SKILL.md to plant into — the control did not run, so the green above is unproven"
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
  local src; src="$(find "$skills" -name 'SKILL.md' -type f | head -1)"
  [ -n "$src" ] && cp "$src" "$probe/victim.md"
  if [ ! -f "$probe/victim.md" ]; then
    cf "(control) could not copy a SKILL.md to plant into — neither control ran, so the green above is unproven"
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
  local src; src="$(find "$agent" -name 'SKILL.md' -type f | head -1)"
  [ -n "$src" ] && cp "$src" "$victim"
  if [ ! -f "$victim" ]; then
    cf "(control) could not copy a SKILL.md to plant into — the control did not run, so the green above is unproven"
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
    cf "(control) could not copy dev/README.md to plant against — the control did not run, so the green above is unproven"
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
    local pd; pd="$(find "$probe" -mindepth 1 -maxdepth 1 -type d | head -1)"
    if [ -z "$pd" ]; then
      cf "(control) could not copy a marker directory to plant into — the control did not run"
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

# THE RUN-OUTCOME VOCABULARY IS HAND-COPIED INTO BOTH RUNNERS AND RATIFIED NOWHERE. Unlike
# VERDICTS — which has a declaration in each runner AND a case pinning both to the ratified table in
# process/MANUAL.md — nothing under process/ names this set, so there is no authority to pin to.
# What is available is AGREEMENT, and that is what this case holds: the same discipline the schema
# case above applies, for the same reason (the runtime grants these files no imports, so the copies
# cannot be removed).
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
    cf "the runners' run-outcome vocabularies have DIVERGED -- they are hand-maintained copies with no ratified source to fall back on: $(diff "$a" "$b" | tr '\n' ' ')"
  fi

  finish "the two shipped runners' run-outcome vocabularies agree and every declared token is returned ($n token(s), $unused unused)"
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
    printf '%s\n' "$code" | grep -qF 'CFG.goldenPaths &&' \
      || { bad=$(( bad + 1 )); cf "$lab: the drift step has no guard on CFG.goldenPaths — '??' alone does not produce a skip, it only delivers the empty string to a step that would then run against nothing"; }

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
    grep -q 'RE-HEAD THE CARD' "$SB_WORK/scripts/$msh" \
      || cf "scripts/$msh does not re-head the card it mints — its cards will open by calling themselves templates"
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
# same lesson the refusal now encodes, one level up: five scripts each holding a
# copy of one project's prefix IS the silently-wrong-prefix bug, and in the sweep
# it is worse than a bad mint (a sweep under the wrong prefix finds nothing and
# reports "nothing to sweep" on a full column). So the conclusion is superseded
# and the guard is transformed: every one of the five must now REFUSE and NAME
# config.sh. All five are asserted, because fixing one in isolation would leave
# the other four inconsistent — which is exactly how the debt survived.
# =============================================================================
case_config_seam_refusal() {
  cf_reset
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
  prefixes="$(sed -n "s/^ROLE_PREFIXES='\\(.*\\)'.*/\\1/p" "$hook")"
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
  last_resort="$(sed -n 's/^KWT_TRUNK_LAST_RESORT="\${KWT_TRUNK_LAST_RESORT:-\([A-Za-z0-9._\/-]*\)}"/\1/p' \
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
  E="$e" perl -i -pe '$_ .= "  $ENV{E}\n" if /^GUARD_SET=\($/' "$v"
  grep -qxF "  $e" "$v" \
    || _fixture_die "_guard_declare: '$e' is not in GUARD_SET after the insert."
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
  perl -i -pe '$_ .= "  \"green|select|/bin/echo ran-green\"\n  \"redbuild|full|./red-gate\"\n" if /^GATES=\($/' "$v"
  perl -i -pe '$_ .= "  guard-one.txt\n" if /^GUARD_SET=\($/' "$v"

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
# THERE ARE NOW THREE IMPLEMENTATIONS OF THIS SIGNAL SET — the initializer's
# already-lived probe, this arm's re-derivation of it, and this fixture. The first two
# are tracked as their own defect; this comment exists so the third is discoverable from
# either of them rather than being found by accident.
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

cb_run() { ( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR "$SB_WORK/scripts/check-board.sh" 2>&1 ); }

# =============================================================================
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
  printf '<!-- BOOTSTRAP-SCAFFOLDING -->\n# scaffolding\n' > "$SB_WORK/CLAUDE.md"
  printf '<!-- BOOTSTRAP-SCAFFOLDING -->\n# scaffolding\n' > "$SB_WORK/README.md"
  printf '# PROJECT.md\n\nTrunk: <trunk>\n'               > "$SB_WORK/PROJECT.md"
  publish_sandbox

  local out
  out="$(cb_run)"
  printf '%s\n' "$out" | grep -q '^\[g\]' \
    || cf "(a) no [g] section — the arm is absent, which no other assertion here can detect"
  printf '%s\n' "$out" | _cb_g_section | grep -q 'THIS CHECK DID NOT RUN' \
    || cf "(a) with no signal at all the arm did not say it had not run: $out"
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
  printf '<!-- BOOTSTRAP-SCAFFOLDING -->\n# scaffolding\n' > "$SB_WORK/CLAUDE.md"
  printf '<!-- BOOTSTRAP-SCAFFOLDING -->\n# scaffolding\n' > "$SB_WORK/README.md"
  printf '# PROJECT.md\n\nTrunk: <trunk>\n'               > "$SB_WORK/PROJECT.md"
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
  printf '<!-- BOOTSTRAP-SCAFFOLDING -->\n# scaffolding\n' > "$SB_WORK/CLAUDE.md"
  printf '<!-- BOOTSTRAP-SCAFFOLDING -->\n# scaffolding\n' > "$SB_WORK/README.md"
  printf '# PROJECT.md\n\nTrunk: <trunk>\n'               > "$SB_WORK/PROJECT.md"
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
  printf '<!-- BOOTSTRAP-SCAFFOLDING -->\n# scaffolding\n' > "$SB_WORK/CLAUDE.md"
  printf '<!-- BOOTSTRAP-SCAFFOLDING -->\n# scaffolding\n' > "$SB_WORK/README.md"
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
  printf '<!-- BOOTSTRAP-SCAFFOLDING -->\n# scaffolding\n' > "$SB_WORK/CLAUDE.md"
  printf '<!-- BOOTSTRAP-SCAFFOLDING -->\n# scaffolding\n' > "$SB_WORK/README.md"
  printf '# PROJECT.md\n\nTrunk: <trunk>\n'               > "$SB_WORK/PROJECT.md"

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
# THE ISSUE-TEMPLATE CAPABILITY PROBE — ONE AUTHORING SITE. Eight cases need a minted card, so
# eight carried their own copy of this path, in TWO spellings of the skip reason. The path, the
# spelling policy below and the reason string are one decision, and a decision stated eight times
# is eight places to amend and seven to forget.
#
# `.claude/` ONLY, DELIBERATELY, AND DO NOT WIDEN THIS TO THE DUAL SPELLING. These eight cases
# exercise a BUILT kit — `kit_init_sandbox` copies `.claude/templates` and nothing else — so the
# maintainer repository's disarmed `_claude/` tree is not their operand and finding it would make
# them run against a tree they are not testing. The sites elsewhere in this file that read
# whichever spelling exists are reading the SHIPPED tree in place, which is a different question;
# the header says why that is a convenience and not a supported mode.
ISSUE_TEMPLATE_REL='.claude/templates/ISSUE.template.md'
ISSUE_TEMPLATE_ABSENT="$ISSUE_TEMPLATE_REL absent (copy-list incomplete)"
has_issue_template() { [ -f "$REAL_REPO_ROOT/$ISSUE_TEMPLATE_REL" ]; }

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
  grep -qxF '.claude/session-role' "$SB_WORK/.gitignore" \
    || cf ".claude/session-role was not written into the new repo's .gitignore"
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

case_kit_init_refuses_lived_board() {
  cf_reset
  if ! has_kit_init; then skp "kit-init: refuses a repo that has already lived" "scripts/kit-init.sh absent"; return; fi
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

case_creation_scripts_substitute_hostile_values() {
  cf_reset
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
  if [ ! -d "$REAL_REPO_ROOT/.claude/templates" ]; then
    skp "creation scripts substitute hostile values" ".claude/templates absent — the creation scripts exit before their substitution block"
    return
  fi
  make_sandbox
  mkdir -p "$SB_WORK/.claude/templates" "$SB_WORK/requirements"
  cp -R "$REAL_REPO_ROOT/.claude/templates/." "$SB_WORK/.claude/templates/"
  _kit_neutral_claude
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

  finish "creation scripts: a value carrying sed's delimiter or its whole-match metacharacter lands VERBATIM in the card, no .bak is ever left on the board, and a refusal after id validation creates nothing"
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
seed_release_files() {
  local target="$1" notes_target="${2:-$1}"
  printf '1.0.0\n' > "$SB_WORK/VERSION"
  cat > "$SB_WORK/pkg.conf" <<'EOF'
[package]
name = "sandbox"
version = "1.0.0"
EOF
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
assert_release_unmutated() {
  grep -qx '1.0.0' "$SB_WORK/VERSION" || cf "VERSION was mutated despite an aborted preflight"
  grep -q 'version = "1.0.0"' "$SB_WORK/pkg.conf" || cf "pkg.conf was mutated despite an aborted preflight"
  git -C "$SB_WORK" rev-parse -q --verify refs/tags/v1.1.0 >/dev/null 2>&1 \
    && cf "tag v1.1.0 was created despite an aborted preflight"
  origin_file_contains "VERSION" '1.0.0' || cf "a version bump reached the remote despite an aborted preflight"
}
run_release() {  # <version> [extra args…]
  ( cd "$SB_WORK" && RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=true \
      RELEASE_BOARD_CMD="$SB_TMP/board-clean.sh" \
      "$SB_WORK/scripts/release.sh" "$@" 2>&1 )
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
  grep -qx '1.0.0' "$SB_WORK/VERSION" || cf "(malformed) a version file was mutated"
  teardown

  # (b) the tag already exists
  make_sandbox; seed_release_files 1.1.0; publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  git -C "$SB_WORK" tag -a v1.1.0 -m "pre-existing" >/dev/null 2>&1
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(tag-exists) expected nonzero when v1.1.0 already exists, got 0"
  grep -qx '1.0.0' "$SB_WORK/VERSION" || cf "(tag-exists) a version file was mutated"
  teardown

  # (c) off-trunk
  make_sandbox; seed_release_files 1.1.0; publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  git -C "$SB_WORK" checkout -b feature/off-trunk "$SB_TRUNK" --quiet >/dev/null 2>&1
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(off-trunk) expected nonzero on a feature branch, got 0"
  assert_release_unmutated
  teardown

  # (d) dirty working tree
  make_sandbox; seed_release_files 1.1.0; publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  echo "dirty" > "$SB_WORK/DIRTY.txt"
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(dirty) expected nonzero on a dirty tree, got 0"
  grep -qx '1.0.0' "$SB_WORK/VERSION" || cf "(dirty) a version file was mutated"
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
  assert_release_unmutated
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
  assert_release_unmutated
  teardown

  # (d) board drift
  make_sandbox; seed_release_files 1.1.0; publish_sandbox; write_board_stub "$SB_TMP/board-drift.sh" drift
  out="$( cd "$SB_WORK" && RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=true RELEASE_BOARD_CMD="$SB_TMP/board-drift.sh" \
            "$SB_WORK/scripts/release.sh" 1.1.0 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(board-drift) expected nonzero, got 0"
  assert_release_unmutated
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
  assert_release_unmutated
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
  assert_release_unmutated
  seed_release_doc "$SB_WORK/NOTES.md" "Release notes" 1.1.0
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[Dev] add the consumer-facing section" >/dev/null 2>&1
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
  assert_release_unmutated
  # …and correcting the HEADER (never the measurement) unblocks it.
  perl -i -pe 's/^## \[1\.1\.0\] — 2026-07-24$/## [1.1.0] — 2026-09-30/' "$SB_WORK/NOTES.md"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[Dev] date the section at the cut" >/dev/null 2>&1
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
  assert_release_unmutated

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
    grep -qx '1.0.0' "$SB_WORK/VERSION" || cf "(undo) the bump survived the printed undo"
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
  grep -qx '1.0.0' "$SB_WORK/VERSION" || cf "(i) VERSION was bumped during a refusal: $(cat "$SB_WORK/VERSION")"
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
    cf "(control) could not copy the derivation's authoring site — the control did not run, so the green above is unproven"
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
  # a run in place finds no .claude/templates at all. The three kit-init cases skip
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
  case_archive_progress_ordinal_knife
  case_archive_progress_honest_noop
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
  case_kit_init_refuses_lived_board
  case_kit_init_gate_fill
  case_kit_init_gate_and_remote_refusals
  case_option_parsing_hygiene
  case_creation_scripts_substitute_hostile_values
  case_first_mile
  case_release_happy
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
