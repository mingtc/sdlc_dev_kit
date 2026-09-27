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
#     rewrites sandbox fixtures throughout this harness and is PROBED AT STARTUP: its
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
# ONE INSTANCE PER MACHINE — AN ASSUMPTION THIS HARNESS DOCUMENTS RATHER THAN A CAUSE IT KNOWS.
#   Run one copy of this harness at a time. Two concurrent runs may collide in the sandbox EVEN
#   AGAINST SEPARATE TREES AND SEPARATE BARE REMOTES, which is the configuration in which it was
#   observed: of two runs started in parallel, one finished normally and the other aborted
#   mid-suite with a FIXTURE FAILURE naming a sandbox file that did not exist. Re-run alone, in
#   the same tree, that second run completed normally — so the tree was not the cause.
#
#   THE CAUSE IS NOT DERIVED, AND THIS PARAGRAPH IS NOT A DIAGNOSIS. It was seen once, on one
#   machine, on one pair of runs. `make_sandbox` takes a fresh `mktemp -d`, which should not
#   collide, and `teardown` removes `$SB_TMP`, a global that every `make_sandbox` reassigns —
#   both are READ from lib/fixtures.sh, and NEITHER HAS BEEN MEASURED against this failure. A
#   host-level cause (temp-dir reaping, a git config lock) is equally unexcluded. Do not read
#   this block as saying which it is.
#
#   IT IS WRITTEN DOWN BECAUSE THE RED IS OTHERWISE UNATTRIBUTABLE, NOT BECAUSE IT IS DANGEROUS.
#   The failure direction is the safe one: the run that failed ABORTED, loudly, naming the
#   missing sandbox file, rather than reporting a green it had not earned. That is a statement
#   about the ONE OBSERVED FAILURE and not a guarantee about every collision, which nothing here
#   has measured. What costs is a reader meeting that red with no way to tell it from a real
#   defect, because the natural response — re-run it — makes it vanish, which is the shape of a
#   flake. That is why the remedy here is a sentence and not a mechanism.
#
#   THIS IS NOT WHAT `case_isolation` ASSERTS, AND THE TWO ARE DELIBERATELY SEPARATE. That case
#   asserts the REAL REPOSITORY's HEAD and working tree are unchanged across a run — isolation
#   FROM this harness TO the repository it is run in. This paragraph is about isolation of the
#   harness from ANOTHER INSTANCE OF ITSELF: the opposite direction, a different subject and a
#   different failure. Folding them would put two properties under one verdict, so a red would
#   no longer say which of them broke.
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
#   awk '!/^[[:space:]]*#/ && /_claude/ && /REAL_REPO_ROOT/ {print FILENAME":"FNR": "fn}
#        /^[A-Za-z_][A-Za-z0-9_]*\(\)/{fn=$1}' scripts/test/run.sh scripts/test/lib/*.sh scripts/test/cases/*.sh
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
# line dies 141 too, once "$big" exceeds the pipe buffer.
#
# THE EXEMPTION THIS BLOCK USED TO CLAIM WAS WRONG, AND THE REASON IT GAVE WAS RIGHT.
# It argued that the many `printf "$out" | grep -q` pipelines below were sound because
# `$out` is one command's captured output, "orders below that buffer". The premise is
# the correct test; the conclusion did not follow, because CAPTURING THE STREAM DOES
# NOT SHRINK IT. `git log … | grep -q` and `subjects="$(git log …)"; printf '%s\n'
# "$subjects" | grep -q` have the SAME failure at the same threshold — the capture only
# moves which process dies of SIGPIPE, and `pipefail` promotes it either way. Measured
# on this machine with the exact `origin_has_path` shape, a target matching on the
# FIRST line so the reader exits at once:
#
#     board size     bytes     capture-then-`grep -q`     reader drains input
#       200 cards    12231          0/100 false reds           0/100
#       800 cards    48831          0/100                      0/100
#      2000 cards   122031        100/100 FALSE REDS           0/100
#      5000 cards   305031        100/100 FALSE REDS           0/100
#
# The threshold is the 64KB pipe buffer, and it is a CLIFF, not a flake: below it
# nothing fails, above it everything does. So the old rule sorted these pipelines into
# "growable" and "exempt" and then applied the WRONG REMEDY to the growable half.
#
# THE RULE, SUPERSEDING THE ABOVE, AND ITS SCOPE STATED SO THE SENTENCE IS TRUE:
# never let an early-exiting reader decide a verdict under `pipefail` WHERE THE PRODUCER
# CAN GROW. `grep -q`, `grep -m`, `head`, `sed …q` and `read` are the family; the
# growable producers are the ones that read a repository, a board, a history or the
# network. IN THIS HARNESS the rule applies without exception — every producer here is a
# fixture a future case can enlarge, so no assertion in it uses a piped early-exiting
# reader at all, and the census in `case_probe_victim_selection_survives_pipefail`
# enforces exactly that. IN THE SHIPPED SCRIPTS it applies to the growable producers,
# which that same case censuses separately; the pipelines validating a SINGLE FLAG VALUE
# (`printf '%s' "$NUM" | grep -qE '^[0-9]+$'`) are deliberately left, because one
# argument cannot approach the buffer and the rewrite would be churn without a defect.
# The unqualified form of this sentence would be false about the tree we ship, which is
# the kind of claim § C of the staleness doctrine calls a bare universal.
# Drop the `-q` and redirect — `| grep -F pat >/dev/null` — which makes the reader
# drain its input while returning the IDENTICAL exit status, or in bash test the string
# directly with `[[ "$out" == *pat* ]]` and have no pipe at all. Both were measured to
# preserve the TRUE NEGATIVE (50/50 correct reds on a genuinely absent pattern), so the
# fix cannot turn a red into a false green. This is why no assertion in the harness uses `grep -q`
# behind a pipe; a bare `grep -q FILE` with no pipe has no producer and is unaffected.
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

# ── THE MANIFEST IS REQUIRED, AND ITS ABSENCE IS A REFUSAL RATHER THAN A SKIP. ───────────────
#
# The header above already says this harness is a witness only when run from a BUILT KIT, that an
# in-place run's day-one cases skip on a path that exists under the other spelling, that at least
# one case has reported a FALSE RED there, and that "no number taken from one belongs in a change
# file." All of that was true, and all of it was PROSE — so the run happened anyway and produced
# numbers somebody then had to decide whether to believe.
#
# `process/KIT-MANIFEST` is generated by the build and never tracked, so its presence is exactly
# the question "am I a built kit?", answered by a file rather than by a reader's discipline.
#
# WHY A REFUSAL AND NOT A SKIP, WHICH IS WHAT THIS WAS FOR ONE COMMIT. The cases that ask about
# the shipped population DERIVE that population from this file. With a skip, a tree without the
# manifest runs those cases against nothing and prints a summary with no red in it — the vacuous
# coverage this whole workstream exists to kill, reintroduced by the fix for it. A skip is the
# correct shape for a subject that is legitimately absent; the manifest is never legitimately
# absent from a tree this harness is entitled to judge.
if [ ! -f "$REAL_REPO_ROOT/process/KIT-MANIFEST" ]; then
  {
    echo "run.sh: REFUSING — there is no process/KIT-MANIFEST in this tree."
    echo
    echo "  This harness is a witness only when it runs from a BUILT KIT: an unzipped release"
    echo "  given day-one git topology. The manifest is written by the build and is never"
    echo "  tracked, so its absence means one of three things, and none of them is runnable:"
    echo
    echo "    * this is the kit's own source repository. Running here is unsupported — the kit"
    echo "      is stored disarmed, so the day-one cases skip on paths that exist under another"
    echo "      spelling and at least one case reports a red with no defect behind it. Build a"
    echo "      zip and run it there instead."
    echo
    echo "    * this is a project that adopted the kit BEFORE the manifest shipped, and has"
    echo "      re-copied scripts/test/ without it. Copy process/KIT-MANIFEST across from the"
    echo "      same zip you took scripts/test/ from; they are one unit."
    echo
    echo "    * the manifest was deleted. Re-unzip it; it is generated, not authored."
    echo
    echo "  Refusing rather than running: the cases that ask about the shipped population derive"
    echo "  that population from this file, and without it they would assert nothing and print"
    echo "  a green while doing it."
  } >&2
  exit 2
fi

# ── THE HARNESS'S OWN TEXT IS A POPULATION, AUTHORED ONCE. ───────────────────────────────────
#
# Several cases census THIS HARNESS's source — its role literals, its minting cases, its piped
# readers, its landing prologues, its fixture appends. They used to name their subject with
# `${BASH_SOURCE[0]}`, and inside a function that is NOT "this harness": it is the file the
# function was DEFINED in. While the harness is one file the two are the same, which is exactly
# why the difference is invisible. The day a case moves into a sourced file, its census shrinks to
# that one file, every negative census ("none of them does X") gets TRUER, and nothing reddens.
#
# So the population is derived here, once, from the ONE LIST the loader below sources: the entry
# point, then _harness_sourced. The files a census reads and the files the entry point loads
# cannot then differ, because there is one author for both.
#
# THE LIST IS A GLOB — lib/*.sh, then cases/*.sh, beside the entry point, in C-locale order —
# written in _harness_sourced and nowhere else. It stayed empty until the harness was split,
# because a glob also sources whatever a project keeps under those names: a change to announce,
# not to make silently. The split's release note announces it. A file there is harness: loaded,
# and read by every census.
#
# A CONCATENATION, NOT A LIST, for the cases that plant into a copy or excise their own body: they
# read one probe file. A line number of the concatenation is a line of no file, so a census that
# reports one passes it through _harness_where, which names the file and the line in it.
#
# AND EVERY CASE THAT READS IT ASSERTS IT IS WHOLE (_harness_population_is_whole): the case_*()
# definitions across the population must number exactly what CASES lists. A population that lost
# a file then reddens instead of shrinking.
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ENTRY="$HARNESS_DIR/$(basename "${BASH_SOURCE[0]}")"

_harness_sourced() {  # the files the entry point sources, in load order — THE ONE LIST
  local LC_ALL=C f
  for f in "$HARNESS_DIR"/lib/*.sh "$HARNESS_DIR"/cases/*.sh; do
    [ -f "$f" ] && printf '%s\n' "$f"
  done
  return 0
}

_harness_sources() {  # every file of the harness: the entry point, then what it sources
  printf '%s\n' "$HARNESS_ENTRY"
  _harness_sourced
}

_harness_probe_copy() {  # <dest> — the whole population, concatenated in load order
  local dest="$1" f
  : > "$dest" || return 1
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    cat "$f" >> "$dest" || return 1
  done <<HARNESS_SOURCES_EOF
$(_harness_sources)
HARNESS_SOURCES_EOF
}

# _harness_where — a filter: each stdin line that STARTS with a line number of the population copy
# has that number rewritten to scripts/test/<file>:<line>. Other lines pass through unchanged.
_harness_where() {
  local f len total=0 line n i prev names=() ends=()
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    len="$(wc -l < "$f" | tr -d ' ')"
    total=$(( total + len )); names+=("scripts/test/${f#"$HARNESS_DIR"/}"); ends+=("$total")
  done <<HARNESS_WHERE_EOF
$(_harness_sources)
HARNESS_WHERE_EOF
  while IFS= read -r line; do
    n="${line%%[!0-9]*}"
    [ -n "$n" ] || { printf '%s\n' "$line"; continue; }
    i=0; prev=0
    while [ "$i" -lt "${#ends[@]}" ] && [ "$n" -gt "${ends[$i]}" ]; do prev="${ends[$i]}"; i=$(( i + 1 )); done
    if [ "$i" -lt "${#ends[@]}" ]; then printf '%s:%s%s\n' "${names[$i]}" "$(( n - prev ))" "${line#"$n"}"
    else printf '%s\n' "$line"; fi
  done
}

# _harness_population_is_whole <probe copy> — the instrument check a census of this harness owes.
# Counted on the copy BEFORE any excision, so a case that cuts its own body out is still counted.
_harness_population_is_whole() {
  local n
  n="$(grep -c '^case_[a-z_0-9]*() {' "$1" || true)"
  [ "${n:-0}" -eq "${#CASES[@]}" ] \
    || cf "(population) the harness text this case read defines ${n:-0} case_*() function(s) and CASES lists ${#CASES[@]}. Either _harness_sources no longer names every file the entry point loads (this census has shrunk to part of the harness and would stay green about the rest), or a case_*() is defined in a shape this count does not read — it reads 'name() {' at column 0 — or text that is not a definition matches it"
}

# THE LOADER, over the same list.
_harness_loaded=()
while IFS= read -r _hs; do
  [ -n "$_hs" ] && _harness_loaded+=("$_hs")
done <<HARNESS_SOURCED_EOF
$(_harness_sourced)
HARNESS_SOURCED_EOF
for _hs in ${_harness_loaded[@]+"${_harness_loaded[@]}"}; do
  # shellcheck source=/dev/null
  . "$_hs" || { echo "run.sh: REFUSING — could not load $_hs, which the harness sources; every case it defines would be missing from the run." >&2; exit 2; }
done
unset _hs _harness_loaded

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
  case_move_issue_declined_requires_a_reason
  case_move_issue_set_pr_on_a_minted_card
  case_role_literals_are_declared
  case_progress_record_is_one_shape_and_optional
  case_progress_record_one_place_across_worktrees
  case_finish_pr_happy
  case_finish_pr_post_merge_names_its_ref
  case_finish_pr_post_merge_reads_the_landed_trunk
  case_finish_pr_post_merge_moves_the_gate_checkout
  case_finish_pr_second_worktree
  case_finish_pr_remote_delete_refused
  case_finish_pr_remote_delete_resurrected
  case_finish_pr_premerge_red
  case_finish_pr_premerge_names_an_unrunnable_gate
  case_finish_pr_empty_merge
  case_finish_pr_gate_absent_says_write_one
  case_finish_pr_gate_hardening
  case_finish_pr_worktree_through_a_symlink
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
  case_runner_no_verdict_is_not_a_failure
  case_runner_absent_reply_is_named_not_judged
  case_runner_throwing_leg_is_named_not_dropped
  case_runner_precondition_failure_has_a_reply
  case_runner_returns_leg_notes_on_every_outcome
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
  case_verify_exit_status_separates_the_reds
  case_check_board_id_clean
  case_check_board_id_duplicate
  case_check_board_id_mismatch
  case_check_board_frontmatter_offset
  case_check_board_registers
  case_check_board_register_absent
  case_check_board_citations
  case_check_board_arrow_beats_mention
  case_check_board_declined_is_judged_and_counted
  case_setup_warns_on_a_later_added_column
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
  case_prd_coverage_counts_only
  case_kit_feedback_line_is_reported_not_refused
  case_check_board_names_a_detached_head
  case_check_board_fill_arm_reads_blanks_not_usage
  case_check_board_graduation_verdict_is_not_wired
  case_kit_init_survives_the_documented_first_commit
  case_kit_init_refuses_an_uncommitted_kit
  case_kit_init_still_fails_on_a_real_finding
  case_kit_init_happy
  case_kit_init_repairs_hook_mode
  case_kit_init_roles_leave_no_seam
  case_kit_init_signs_with_the_pre_role_hat
  case_kit_init_generated_runner_speaks_the_frame
  case_help_advertises_exactly_what_the_role_arm_accepts
  case_role_enforcement_derives_and_names_its_fallback
  case_lived_probe_has_one_authoring_site
  case_kit_init_refuses_lived_board
  case_kit_init_project_name_refusal
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
  case_release_ship_manifest_is_driven_against_the_bump
  case_release_publish
  case_release_publish_recovery
  case_release_local_only_recovery
  case_release_bash_n
  case_release_spaced_path
  case_consumer_updater
  case_hygiene_instruments_declare_blind_spots
  case_cold_signal_reads_non_ascii_paths
  case_agent_prose_carries_its_riders
  case_partial_prefix_derivation_says_so
  case_travelling_scripts_have_a_sheet
  case_release_hook_rejection_leaves_no_bump
  case_template_links_resolve_from_their_destination
  case_missing_option_value_refuses
  case_shipped_scripts_stay_on_the_floor
  case_help_never_opens_with_the_class_marker
  case_role_examples_carry_their_label
  case_role_set_read_is_one_expression
  case_every_arm_file_seam_is_declared_in_the_contract
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
  case_declared_exit_codes_are_driven
  case_shipped_manifest_describes_the_tree
  case_restated_rules_are_registered
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

# ── THE RUN, AND A STABLE IDENTITY FOR EACH CASE'S OUTCOME. ──────────────────
#
# WHY THE OUTCOME IS DERIVED HERE RATHER THAN READ OFF THE PRINTED LINES. Comparing two runs of
# this harness — the shipped tree against a tree that has finished day one — needs to know THE
# SAME CASE's outcome in both. The printed line cannot supply that, and this was measured rather
# than reasoned:
#
#   * a case that names its span embeds a DERIVED COUNT in its finish line ("among the 18 shipped
#     scripts…" / "…the 19…"), so the better the case behaves — naming its span is this kit's own
#     rule — the more certainly its text differs between two legitimate trees;
#   * a case that goes N/A never reaches its finish line at all, so its text differs by
#     construction.
#
# So a comparison keyed on the printed text reports a moved case wherever a count moved, and is
# blind wherever a case changed kind. Keyed on the FUNCTION NAME it reports neither. The block
# below is therefore the machine-readable half of this harness's output; the human half above it
# is unchanged.
declare -a CASE_OUTCOMES
_multi=""
for _c in "${CASES[@]}"; do
  _p0=$PASS; _f0=$FAIL; _s0=$SKIP; _l0=$LIVED
  "$_c"
  _n=$(( (PASS-_p0) + (FAIL-_f0) + (SKIP-_s0) + (LIVED-_l0) ))
  if   [ "$FAIL"  -gt "$_f0" ]; then _o=FAIL
  elif [ "$LIVED" -gt "$_l0" ]; then _o=LIVED
  elif [ "$SKIP"  -gt "$_s0" ]; then _o=SKIP
  elif [ "$PASS"  -gt "$_p0" ]; then _o=PASS
  else _o=NO-OUTCOME
  fi
  # ── INSTRUMENT CHECK: exactly one outcome per case. A case that records NOTHING is invisible
  #    in every count this harness prints — it looks identical to a case that was never written.
  #    A case that records TWO makes every set comparison below ambiguous. Both are reported by
  #    name rather than absorbed into a total.
  [ "$_n" -eq 1 ] || _multi="$_multi $_c($_n)"
  CASE_OUTCOMES+=("$_c $_o")
done

echo
echo "════════════════════════════════════════════════════════"
printf 'summary: %d PASS, %d FAIL, %d SKIP, %d N/A-on-lived-tree\n' "$PASS" "$FAIL" "$SKIP" "$LIVED"
# THE N/A LIST IS PRINTED, NOT JUST COUNTED. It is a new enumeration, derived from the run rather
# than typed anywhere, and it is what a reviewer reads at the cut: a case that has quietly had no
# subject for six months looks exactly like a case that passed, unless the list is in front of them.
if [ "$LIVED" -gt 0 ]; then
  echo
  echo "N/A on a lived tree — these cases had no subject on THIS tree, each naming the file whose"
  echo "shipped shape is absent. On the pristine tree this list is expected to be empty."
  for _r in "${RESULTS[@]}"; do case "$_r" in "N/A   "*) printf '  %s\n' "${_r#N/A   }" ;; esac; done
fi
echo "════════════════════════════════════════════════════════"

# The machine-readable outcome table: one line per case, keyed on the case's own function name.
# Stable across trees by construction — see the comment on the run loop above. A reader comparing
# two runs uses these lines; a human reads the block above.
echo
for _r in "${CASE_OUTCOMES[@]}"; do printf 'case-outcome: %s\n' "$_r"; done
if [ -n "$_multi" ]; then
  echo
  echo "harness: REFUSING — these case(s) did not record exactly one outcome:$_multi"
  echo "  A case recording NONE is invisible in every count above; a case recording TWO makes the"
  echo "  outcome table ambiguous. Both are defects in the case, not in the tree under test."
  exit 2
fi
[ "$FAIL" -eq 0 ]
