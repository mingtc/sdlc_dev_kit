# KIT-CLASS: MIXED — self-test harness, the shared fixtures. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/lib/fixtures.sh — sourced by scripts/test/run.sh, never run on its own.
# The fixtures every case family builds on: the neutral config, the PASS/FAIL/SKIP
# recorders, make_sandbox and the seeders, the seam neutralizers (_neu_*, _kit_neutral_*), the
# origin_* readers, and the anchored plant helpers.
# =============================================================================

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

# THE SCAFFOLDING SENTINEL, DECLARED — the whole line the two shipped root documents carry.
# It belongs in this block for the reason the block gives: it is the kit's SHIPPED value for
# a seam the sandbox copies in, and it must be DERIVED FROM NOTHING IN THE ADOPTER'S TREE.
# It was the one constant of that class this harness DERIVED — with a sed over CLAUDE.md in
# the tree under test — and the cost is measured. Both root documents are REPLACE-class: SEED
# § "Day one is done when" requires an adopter to have replaced BOTH, so on the only tree an
# adopter ever has, the derivation reads nothing and the harness REFUSED TO START. Zero cases,
# on every tree that had followed the kit's own instructions.
#
# THE ORIGINAL REASON SURVIVES; ONLY ITS MECHANISM IS SUPERSEDED. The derivation carried a
# no-fallback rule, and the rule's why was right: "a harness that cannot read the mark would
# seed a fixture check-board.sh cannot see, and every graduation case would then pass by not
# testing anything." That property now lives in case_scaffolding_fixture_matches_the_tree
# arm (b), which asserts check-board.sh probes for THIS literal — so a mark the tool does not
# look for still reddens, and the fixture still cannot be invisible to the tool in silence.
# The mark keeps two independent authors (this constant, and check-board.sh's own probe); the
# shipped documents are a THIRD, asserted by arm (a) wherever a shipped copy is still present.
#
# IT IS THE WHOLE LINE, NOT THE TOKEN, and every reader matches it with `grep -qxF`. A bare
# token also matches a backticked mention in prose and would match the adapter template if
# that file ever grew one — and an adopter who built their adapter from a template carrying
# the token would read "still scaffolding" forever. Anchoring to the entire shipped line makes
# the shipped line the only thing that satisfies it. seed_scaffolding_tree writes exactly this.
KIT_SCAFFOLD_MARK='<!-- BOOTSTRAP-SCAFFOLDING — a tool reads this line. It goes when this file goes. -->'

# THE REPLACE DISPOSITION DECLARATION, which arm (g1) uses to SELECT its population while
# KIT_SCAFFOLD_MARK above remains the TEST it applies. Two constants because they are two
# halves of one arm and neither implies the other: a file may declare the disposition and be
# correctly graduated (declaration present, sentinel gone → ✓), and a synthetic fixture that
# writes only the sentinel is no longer in the population at all.
#
# THAT IS EXACTLY HOW THIS CONSTANT CAME TO EXIST. `seed_scaffolding_tree` wrote only the
# sentinel, which was the whole of the arm's input when the member list was hardcoded in
# check-board.sh. Once (g1) began deriving its population from the files' own declarations,
# the synthetic tree stopped being a REPLACE file and the arm correctly went quiet — and the
# case asserting "arm [g] WAS reporting while it ran" failed, exactly as a case testing a
# premise should when the premise stops holding. The fixture had drifted from what the kit
# ships, not the other way round.
KIT_REPLACE_DISPOSITION='KIT-DISPOSITION: REPLACE'

# THE FILL DISPOSITION, for the same reason and with the same asymmetry: arm (g2) now gates its
# angle-bracket count on PROJECT.md DECLARING FILL, so a synthetic PROJECT.md carrying blanks but
# no declaration is correctly not measured. Every fixture that wants the FILL finding to fire must
# write the declaration the shipped sheet carries.
KIT_FILL_DISPOSITION='KIT-DISPOSITION: FILL'

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
PASS=0; FAIL=0; SKIP=0; LIVED=0
declare -a RESULTS
ok()   { PASS=$((PASS+1)); RESULTS+=("PASS  $1"); printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); RESULTS+=("FAIL  $1${2:+ — $2}"); printf '  \033[31mFAIL\033[0m  %s%s\n' "$1" "${2:+ — $2}"; }
skp()  { SKIP=$((SKIP+1)); RESULTS+=("SKIP  $1${2:+ — $2}"); printf '  \033[33mSKIP\033[0m  %s%s\n' "$1" "${2:+ — $2}"; }

# ── N/A ON A LIVED TREE — a FOURTH outcome kind, and a CLOSED one. ────────────
#
# WHAT IT IS FOR. Some cases assert the shape of a file AS THE KIT SHIPS IT. On a tree that has
# finished day one, that shape is legitimately gone: the adopter filled it, replaced it, or the
# initializer stamped it. Such a case has no subject any more. It has not passed, it has not
# failed, and calling it SKIP is wrong for a reason that is about to matter — the adopted-tree
# gate asserts `S(adopted) = S(pristine)`, so a case reaching for the general `skp` on a lived
# tree satisfies that equation only by accident and hides a case that stopped measuring.
#
# WHY NOT THE OBVIOUS FIX. The tempting repair for these cases is to widen the assertion to
# "accept the shipped shape OR the adopted one" — say, to accept 0 or 1 blanks on a line whose
# shipped form has exactly one. That DELETES the case: it then passes on every tree and measures
# neither, while still printing PASS. `skp_lived` is the alternative — the case keeps its full
# strength on the tree where its subject exists, and says out loud that it has no subject on the
# tree where it does not.
#
# THE PRECEDENT ALREADY SHIPPED. `case_ship_state` has always read the initializer's stamp
# receipt and skipped with "this tree has been adopted". It is the first `skp_lived`.
#
# THE REASON MUST NAME A FILE, AND THE HELPER REFUSES ONE THAT DOES NOT. A reason like "this
# tree has been adopted" is a category, not a subject: it cannot be checked, and it is how a
# whole family of cases quietly goes N/A forever. So the reason must name the file whose shipped
# shape is absent. A refusal here is a FAIL, not a skip — a mis-declared N/A is a case-authoring
# defect and it must be loud.
#
# THE SPAN OF THAT CHECK, STATED (doctrine/instruments.md § A.4). It is a SHAPE test: the reason
# must contain a token that looks like a file name — one with a known extension. It does NOT
# check that the file exists, deliberately: a `DELETE-IF-UNUSED` member removed on day one is
# exactly the case this kind exists for, and requiring existence would force those reasons to
# lie. It cannot tell the subject file from a file merely cited in passing. It stops a reason
# that names no file at all, and that is all it claims to stop.
_lived_names_a_file() {  # <reason>
  printf '%s' "${1:-}" | grep -E '[A-Za-z0-9_-]\.(md|sh|json|js|py|txt|yml|yaml|example|skeleton|template)([^A-Za-z0-9]|$)' >/dev/null
}
skp_lived() {  # <case finish line> <why the subject is absent on a tree that has lived>
  if ! _lived_names_a_file "${2:-}"; then
    bad "$1" "REFUSED by skp_lived: the reason must NAME THE FILE whose shipped shape is absent, and this one names none — '${2:-}'. A reason that names no file cannot be checked by anyone, which is how a case goes N/A forever. (The check is a SHAPE test: a token with a known file extension. It does not verify the file exists.)"
    return
  fi
  LIVED=$((LIVED+1)); RESULTS+=("N/A   $1 — $2"); printf '  \033[36mN/A\033[0m   %s — %s\n' "$1" "$2"
}

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
  # they resolve the sandbox as their root).
  cp -R "$REAL_SCRIPTS" "$SB_WORK/scripts"

  # ...AND THE REST OF THE SHIPPED EXECUTABLE SURFACE, because a case that EXECUTES a shipped
  # tool can only reach a tool the sandbox carries. Until this line, the sandbox held `scripts/`
  # and nothing else, so `consumers/` and `setup.sh` — shipped programs an adopter can run — had
  # never been executed by this harness at all. That was not a decision; it was the shape of one
  # `cp -R`. `case_cli_shape_across_the_shipped_set` named them on every run as a HOLE rather
  # than an exemption, which is the distinction that kept arguing after its author moved on.
  #
  # GUARDED, because an adopter may legitimately have deleted either: the kit is a copy that
  # becomes theirs. A missing one is not this fixture's business — the population accounting in
  # case_cli_shape_across_the_shipped_set is what reports a shipped program that went missing.
  #
  # WHAT IS DELIBERATELY *NOT* COPIED: `.claude/`, `process/`, `docs/` and the root documents.
  # Cases that need `.claude/templates` or `.claude/roles` build them themselves (kit_init_sandbox
  # does, and several cases copy the templates directly), and a wholesale copy would make those
  # fixtures redundant and ambiguous while reaching no tool that this pair does not. Cases that
  # read `process/` read it from the REAL tree on purpose, because it is the shipped text they
  # are judging rather than a mutable copy.
  [ -d "$REAL_REPO_ROOT/consumers" ] && cp -R "$REAL_REPO_ROOT/consumers" "$SB_WORK/consumers"
  [ -f "$REAL_REPO_ROOT/setup.sh" ]  && cp "$REAL_REPO_ROOT/setup.sh" "$SB_WORK/setup.sh"

  # THIS HOLE IS DELIBERATE AND IT IS THE ONLY ONE LEFT, so it says why rather than reading as
  # the same oversight the two lines above just fixed. A sandbox containing this harness would
  # let a case execute the harness inside the harness: `scripts/test/run.sh` builds sandboxes,
  # tears them down and asserts over the real tree, so a nested run would create sandboxes
  # inside a sandbox that the outer teardown then removes underneath it, and its own
  # case_isolation would be measuring a tree the outer run is actively rewriting. There is no
  # ordering that makes that meaningful.
  # WHAT IT COSTS, NAMED: `scripts/test/run.sh` is a shipped program bound by the CLI contract
  # and nothing here exercises it. That is reported on every run by
  # case_cli_shape_across_the_shipped_set's unreached list, and the guard that keeps its
  # EXECUTABLE BIT honest lives in the builder rather than here, for the reason a harness that
  # cannot run cannot assert its own executability.
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
           "$SB_WORK/progress/declined" "$SB_WORK/progress/history"
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
  # not a status folder — check-board declares the statuses, and the initializer builds
  # `("${STATUS_FOLDERS[@]}" history)` for the rotated-log destination. A sweep replacing
  # this list with STATUS_FOLDERS silently stops creating `progress/history/` and surfaces
  # later as an unrelated case failing. A correct derivation does exist — STATUS_FOLDERS plus
  # `history` explicitly — it simply buys less than it costs in a builder. *The obvious
  # derivation is wrong here; the correct one is not worth it. Those are different
  # sentences and only the second is true of derivation in general.*
  for d in todo in_progress dev_complete qa_complete blocked done declined history; do
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

# THE SCAFFOLDING SENTINEL IS NOT DERIVED AND IS NOT HERE. It is DECLARED with the neutral
# config above, because the tree it used to be derived from is the one tree it must survive:
# both root documents are REPLACE-class, and a harness whose constants come out of files the
# kit instructs the adopter to delete cannot run on an adopted tree at all. The reasoning,
# and the property the derivation's no-fallback rule protected, are at its declaration.

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

# THE ADOPTION SIGNAL, ONE AUTHORING SITE. Two signals, either sufficient, and the one that
# fired is returned so a caller can print it: a case that declines to measure something owes
# the reader the reason it declined (process/doctrine/instruments.md § A.4).
#
# WHY IT IS A FUNCTION NOW. case_ship_state derived this inline, and it was the only case that
# needed it. case_scaffolding_fixture_matches_the_tree's arm (e) needs the SAME judgement about
# the SAME tree, and a second copy of a two-signal derivation is how the two drift into
# disagreeing about whether one tree has been adopted — which would show up as one case
# measuring a document the other calls adopter-owned, with nothing to say which was right.
_tree_has_lived() {   # -> the signal that fired, or empty for a tree that has not been adopted
  local rv="$REAL_SCRIPTS/verify.sh" rc_cfg="$REAL_SCRIPTS/config.sh" n
  if [ -f "$rc_cfg" ] && grep -q "^$KIT_STAMP_MARK" "$rc_cfg" 2>/dev/null; then
    printf '%s' "scripts/config.sh carries kit-init's stamp receipt — this tree has been adopted"
    return 0
  fi
  if [ -f "$rv" ]; then
    n="$(_neu_array_records "$rv" GATES)"
    if [ "$n" -ne 0 ]; then
      printf '%s' "scripts/verify.sh declares $n gate(s) — this project has filled its own table"
      return 0
    fi
  fi
  return 0
}

# Does <root>'s <doc> declare the kit class on line 1? The discriminator arm (a) narrows itself
# by, lifted out so it can be run against a FABRICATED root in the control below — the real
# root documents are never mutated, because this harness must not write outside its sandbox.
_root_doc_is_shipped_copy() {   # <root> <doc>
  local l1
  [ -f "$1/$2" ] || return 1
  l1="$(sed -n '1p' "$1/$2")"
  case "$l1" in
    *"$KIT_CLASS_MARKER_KEY KIT"*) return 0 ;;
    *) return 1 ;;
  esac
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
    || _fixture_die "_neu_roles: no ROLE_PREFIXES line in the sandbox's commit-msg — the seam was renamed or moved, so the role vocabulary was NOT neutralized and every --role literal in this harness would be judged against whatever the adopter declared."
  local seams=""
  if [ "$cur" != "$KIT_NEUTRAL_ROLE_PREFIXES" ]; then
    # NON-RECURSIVE, kit-init's reason verbatim: a recursive sweep would also match
    # scripts/test/run.sh — this file — and rewrite the assertions to agree with
    # whatever they were measuring.
    seams="$( { grep -lF -- "$cur" "$SB_WORK"/scripts/*.sh "$SB_WORK"/scripts/githooks/* 2>/dev/null || true; } )"
    [ -n "$seams" ] \
      || _fixture_die "_neu_roles: the sandbox's commit-msg declares '$cur' but NO file under scripts/ carries it — the derivation found nothing to reset, so the role vocabulary is not neutralized and every --role literal in this harness would be judged against whatever the adopter declared."
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
  # ── AND A SECOND DERIVATION THAT SHARES NO MATCHER WITH THE REWRITE. The check above uses
  #    `grep -lF -- "$cur"` — the SAME expression that chose what to rewrite — so it cannot see
  #    anything the rewrite could not see. A file carrying the set in a shape that matcher does not
  #    produce is neither reset nor reported, and this fixture returns success. That is exactly the
  #    defect the role-set work removed from the PRODUCT (a space-padded copy that `grep -lF` could
  #    not match, so the enforcement moved and the header did not), surviving here in the fixture
  #    that neutralizes for it. Derive twice, independently, and compare.
  #
  #    THE SECOND DERIVATION IS SHAPE-INSENSITIVE and keyed on the PROPERTY rather than on the
  #    value: any alternation of capitalized words that shares a member with the shipped set and is
  #    not the shipped set. It normalizes the spacing around the separators first, which is what
  #    makes it blind to the padding the literal matcher is blind to.
  #
  #    THE REWRITE STAYS LITERAL, deliberately — a loose matcher driving a global substitution is
  #    how substrings get corrupted, which kit-init's stamping loop already argues at its own glob.
  #    The asymmetry is the point: narrow to CHANGE, wide to CHECK.
  #
  #    MEASURED before it was wired, because a die here aborts every case that builds a sandbox:
  #    0 hits on the shipped tree, 4 on a tree narrowed by `kit-init --roles` (the state this
  #    function is handed), and 0 again after a correct reset. The middle number is the one that
  #    proves it can see; the outer two are the ones that prove it will not fire on a good tree.
  local shaped
  shaped="$(
    { grep -rnoE '[A-Z][A-Za-z]+([[:space:]]*\|[[:space:]]*[A-Z][A-Za-z]+){1,}' \
           "$SB_WORK"/scripts/*.sh "$SB_WORK"/scripts/githooks/* 2>/dev/null || true; } \
    | awk -v ok="$KIT_NEUTRAL_ROLE_PREFIXES" '
        BEGIN { n = split(ok, M, "|"); for (i = 1; i <= n; i++) mem[M[i]] = 1 }
        { a = $0; sub(/^[^:]*:[^:]*:/, "", a)
          gsub(/[[:space:]]*\|[[:space:]]*/, "|", a)
          if (a == ok) next
          k = split(a, T, "|")
          for (i = 1; i <= k; i++) if (T[i] in mem) { print; next } }' \
    | sort -u )"
  [ -z "$shaped" ] \
    || _fixture_die "_neu_roles: a role-set alternation survives the reset in a shape the literal matcher cannot see, so the rewrite missed it AND the check above passed: $(printf '%s' "$shaped" | sed "s@$SB_WORK/@@g" | tr '\n' ' ' | cut -c1-300) — the cases judging --role literals against the shipped set would redden as though the tools were broken."
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
    # THE TENTH RELEASE SEAM, and it had to land with the seam itself. An adopter's
    # SHIP_MANIFEST names files that exist in THEIR tree and not in a sandbox, so a
    # sandbox that inherited it would make every release case refuse at gate (g) — a red
    # that looks like a release defect and is a fixture defect.
    _neu_scalar "$r" SHIP_MANIFEST       'SHIP_MANIFEST=""'
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
# THE SENTINEL IS NOT DERIVED FROM check-board.sh's PROBE, and that half of the rule is
# unchanged: the probe is the CONSUMER, and deriving the fixture from the consumer would make
# every case here agree with the tool by construction, which is the one thing a control must
# not do. What is superseded is where the fixture's own copy comes from. It was read out of
# the shipped root documents on the grounds that they are the AUTHORITY — they are what an
# adopter actually deletes — and that grounds is exactly why it could not stay: a document the
# kit tells the adopter to delete is not a source a harness can still read on a tree that
# finished day one. The copy is now the harness's declared KIT_SCAFFOLD_MARK. The documents
# remain an author and are still held against that constant wherever a shipped copy survives
# (case_scaffolding_fixture_matches_the_tree arm (a)), so a rename there still reaches a red.
# It writes the WHOLE shipped line, because the whole line is what check-board.sh matches.
seed_scaffolding_tree() {
  local want_project=true
  while [ $# -gt 0 ]; do
    case "$1" in
      --no-project) want_project=false; shift ;;
      *) _fixture_die "seed_scaffolding_tree: unknown argument '$1'" ;;
    esac
  done
  # BOTH HALVES, because arm (g1) needs both: the declaration puts the file in the
  # REPLACE population and the sentinel is the unreplaced-yet test applied to it. The
  # declaration goes in a KIT-CLASS comment block, which is where the shipped files carry
  # it and what the graduation rule requires — see process/EXTRACTION.md § The
  # KIT-DISPOSITION: marker. Writing the sentinel alone produces a tree the arm skips.
  for _sf in CLAUDE.md README.md; do
    {
      printf '<!-- KIT-CLASS: KIT — synthetic scaffolding for the harness.\n'
      printf '     %s — the notice itself is the line below, in the body. -->\n' "$KIT_REPLACE_DISPOSITION"
      printf '%s\n# scaffolding\n' "$KIT_SCAFFOLD_MARK"
    } > "$SB_WORK/$_sf"
  done
  if [ "$want_project" = true ]; then
    # THE DECLARATION FIRST, then the blank. (g2) gates on the declaration, so a sheet with
    # blanks and no declaration is a tree the arm correctly skips — which is not the premise
    # any caller of this helper wants.
    printf '<!-- %s — synthetic fill sheet. -->\n# PROJECT.md\n\nTrunk: <trunk>\n' \
      "$KIT_FILL_DISPOSITION" > "$SB_WORK/PROJECT.md"
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

# THE ONE FETCH THE THREE origin_* READERS SHARE, AND ITS FAILURE IS A FIXTURE FAILURE.
#
# All three used to run this fetch as `>/dev/null 2>&1` with its status discarded, and that made a
# BROKEN REMOTE indistinguishable from an ABSENT FILE. MEASURED, and both conditions are necessary:
#   * a failed fetch alone is harmless — `git show origin/<trunk>:<path>` reads the
#     remote-tracking ref, which is already current, so the reader still answers correctly;
#   * a stale remote-tracking ref alone is harmless — the fetch repairs it;
#   * a STALE REF **AND** A FAILED FETCH together produce a confident FALSE NEGATIVE: the reader
#     reports the file absent from the trunk while the push that put it there LANDED. Reproduced on
#     a built tree with the push asserted to have landed and the marker asserted present in the bare
#     repository.
#
# That is the exact symptom of an intermittent red this suite has carried since 2026-09-03 —
# "the filled verify.sh was not pushed to the trunk", failing once and passing on an immediate
# re-run with nothing changed. This does NOT prove it caused that failure; nothing captured the
# tree at the moment it went red, which is why the investigation ran out of prescribed
# measurements. What IS proven is that these readers CANNOT TELL the two apart, so the red they
# print is not evidence about the subject.
#
# WHY _fixture_die AND NOT cf. A fetch that fails says nothing about the script under test. Reported
# as a finding it is a red for the wrong reason, which teaches the reader to re-run instead of to
# look — the same lesson a flake teaches, and the reason this family survived: the failure is always
# in the FALSE-RED direction, and every caller reads `… || cf …`. origin_log_has_subject's own
# header already records that argument for a DIFFERENT cause in this same function family (a
# SIGPIPE from `git log | grep -q`), fixed there and left standing here.
#
# WHY THE DIE IS SAFE, DERIVED RATHER THAN ASSUMED. Three cases deliberately break the remote —
# they set origin to a path that does not exist — and NONE of them calls any of these three
# readers. The intersection of "breaks the remote" and "reads the remote through these helpers" is
# EMPTY, with both sets non-empty, so a failed fetch inside a caller is never deliberate.
#
# AND IT DISTINGUISHES AN UNREACHABLE REMOTE FROM AN UNEXPECTED FAILURE, because the first is a
# state a case CHOOSES. THREE cases point `origin` at a path that does not exist, deliberately, to
# measure what the tools do about a remote they cannot reach — and they then read the trunk through
# the CACHED remote-tracking ref, which is correct and is the thing they are asserting.
# MEASURED, on the first certified run of the checked fetch: it aborted the whole suite in
# case_release_behind_the_remote, because that case calls assert_release_unmutated AFTER breaking
# the remote, and that helper reads the trunk. **The suppressed fetch was load-bearing.**
#
# So the discriminator is the REMOTE URL, derived rather than a list of case names: a local path
# that is not there means somebody meant it, and the reader proceeds off the cache exactly as
# before. A URL that IS there and still will not fetch is the fixture failing, and that is the only
# case that dies. *A relative URL is resolved against the WORKTREE, not the harness's cwd — one of
# the three points origin at `../origin.git`, which RESOLVES and must still be fetched.*
origin_fetch_or_die() {
  local url path err
  url="$(git -C "$SB_WORK" remote get-url origin 2>/dev/null || true)"
  case "$url" in
    ''|http*|git@*|ssh:*|git:*) : ;;   # nothing local to stat — let the fetch itself answer
    *)
      path="${url#file://}"
      case "$path" in /*) : ;; *) path="$SB_WORK/$path" ;; esac
      [ -e "$path" ] || return 0       # deliberately unreachable: skip the fetch, read the cache
      ;;
  esac
  err="$(git -C "$SB_WORK" fetch origin "$SB_TRUNK" --quiet 2>&1)" && return 0
  _fixture_die "origin_fetch_or_die: origin resolves to '$path' and the fetch of $SB_TRUNK still failed, so every read of the trunk below would report ABSENT whether or not the content is there — a fixture failure reported as a finding about the subject. git said: $(printf '%s' "$err" | tr '\n' '|' | cut -c1-200)"
}

origin_has_path() {
  origin_fetch_or_die
  local paths  # ls-tree grows with the board; the reader below must DRAIN it (header: THE PIPEFAIL RULE)
  paths="$(git -C "$SB_WORK" ls-tree -r --name-only "origin/$SB_TRUNK" 2>/dev/null)"
  printf '%s\n' "$paths" | grep -xF "$1" >/dev/null
}
origin_file_contains() {  # <path> <pattern>
  origin_fetch_or_die
  local body  # the file may be a log that grows; the reader below must DRAIN it (header: THE PIPEFAIL RULE)
  body="$(git -C "$SB_WORK" show "origin/$SB_TRUNK:$1" 2>/dev/null)"
  printf '%s\n' "$body" | grep "$2" >/dev/null
}
origin_log_has_subject() {  # <pattern>
  # THE READER MUST DRAIN ITS INPUT — never `grep -q` behind a pipe. See the PIPEFAIL
  # RULE in this file's header: `git log` grows with the trunk, `grep -q` exits on the
  # first match, and the producer's SIGPIPE became this function's answer. It returned
  # "not found" for subjects that were present, and only ever in the direction of a
  # FALSE RED, which is why it survived: every caller reads it as `… || cf …`.
  # Capturing into `$subjects` does NOT fix this and was once believed to — the capture
  # only changes which process takes the signal. Dropping the `-q` is what fixes it.
  local subjects
  origin_fetch_or_die
  subjects="$(git -C "$SB_WORK" log "origin/$SB_TRUNK" --format='%s' 2>/dev/null)"
  printf '%s\n' "$subjects" | grep "$1" >/dev/null
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
