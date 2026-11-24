#!/usr/bin/env bash
# KIT-CLASS: MIXED — self-test harness for the kanban scripts. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/run.sh — the kit's self-test harness for the board scripts.
#
# HOW TO RUN
#   ./scripts/test/run.sh          # run every case; exit 0 iff none FAILed
#   ./scripts/test/run.sh --cases <name>[,<name>...]   # run only the named cases (or KIT_TEST_CASES=<names>)
#   ./scripts/test/run.sh --core   # the fast core: a partial run of the CORE_CASES list below (a measured, dated list);
#                                  # a listed case this tree does not define (a removed add-on's) is left out and named
#   ./scripts/test/run.sh --list   # print the case names, one a line, and run nothing; cases held in a pack are counted, not listed
#   A SELECTED RUN IS A PARTIAL RUN, AND IS NEVER A GREEN FULL RUN: it prints a `partial:` line, exits 1 when a
#   selected case FAILs and exits 3 (never 0) when every selected case passed. Exit 0 is the full list's alone.
#   A name that is not a defined case refuses the run (exit 2) before anything runs. The selection is applied
#   after the case-list check, so the full run is the same run it always was. Every run prints each case's
#   seconds in `case-seconds:` lines after its outcome table, and the whole run's in `run-seconds:`.
#   A FULL RUN TAKES HOURS (measured 2026-11-23): the cases run one after another, and the ones that kill a program
#   before each of its writes, and the module-adoption ones, are about half of it. `--core` is the list a change is
#   first checked against: minutes, and a PARTIAL run. The `case-seconds:` lines give the figures to re-measure from.
#   KIT_TEST_KILL_ALL=1 ./scripts/test/run.sh
#                                  # the cases that kill a program before each of its writes use every write
#                                  # and every order of enabling, not the bounded set (lib/modules.sh)
#
# It exits 0 when no case FAILs, and NONZERO when any does, printing a summary at the end of four
# outcomes: PASS, FAIL, SKIP, and N/A-on-lived-tree — a case whose subject (a shipped file) is
# gone from a tree that finished day one. N/A is expected only on an adopted tree, and the
# four add up to the number of cases defined.
#
# WHAT IT IS — and IS NOT
#   • Pure bash + git, plus `perl`, which rewrites sandbox fixtures and is PROBED AT
#     STARTUP: its absence is a refusal with the reason. `node` and `python3` are
#     OPTIONAL — cases needing them SKIP loudly. The KIT's floor is git and a POSIX
#     shell; perl is the HARNESS's dependency. It tests the SCRIPTS, not the project.
#   • It is DELIBERATELY NOT wired into scripts/verify.sh — it is an ON-DEMAND
#     developer/QA tool for proving a change to the board scripts is correct
#     without risking the real board or the real remote. RUN IT BY HAND AFTER
#     TOUCHING ANY SCRIPT IT COVERS — including the hooks, the githooks and lib/.
#     The covering set is the CASES list and the sandbox copies each case makes.
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
# CONCURRENT RUNS. Instances may run side by side on one machine, each in its own tree. Nothing a run
#   writes has a fixed name: every sandbox, bare remote and progress-record directory comes from its own
#   `mktemp -d`, a render server takes an ephemeral port, and none writes user-level git configuration. Measured: two full
#   runs of one build, started together in separate scratch projects, ended with the same outcomes as
#   one run alone. What two runs cannot share is ONE TREE: case_isolation compares the real repository
#   before and after, so a second session writing into the tree under test can fail it. If a run fails
#   while another was running, and the failure names a sandbox file that does not exist, re-run alone
#   before debugging; that symptom has not been reproduced. (case_isolation is a different property:
#   the real repository is unchanged.)
#
# THE TRUNK IS DERIVED; THE PREFIX AND THE ROLE SET ARE THE KIT'S SHIPPED VALUES
#   The trunk comes from this repo's own <remote>/HEAD, else kanban-worktree.sh's
#   KWT_TRUNK_LAST_RESORT. The prefix and the role set are the neutral values lib/fixtures.sh
#   declares, which every sandbox is reset to, so a project that changed any of the three still
#   gets a green harness. A harness that asserts one project's literals is a harness that
#   reddens on adoption and teaches the adopter to ignore it.
#
# PROJECT-SPECIFIC FAMILIES ARE PROBED, NEVER ASSUMED
#   Two families exist only if this project has the surface they test:
#     • the CONSUMER-UPDATER family runs only when CONSUMER_SCRIPT
#       (scripts/test/lib/fixtures.sh) names an executable — a vendoring/updater script
#       is a DISTRIBUTION MODEL, not a kit feature (see process/doctrine/distribution.md);
#     • the RELEASE family runs against release.sh's declared SEAMS
#       (VERSION_FILES / RELEASE_DOCS / the publish config), which the harness
#       fills in inside the sandbox. It never asserts one project's version files.
#   Anything absent SKIPs loudly. A SKIP is a statement about the environment; it
#   is never used to hide a missing behaviour (`grep -rni 'no capability probe'
#   scripts/test/cases` finds the cases that deliberately have none).
#
# AN ADD-ON'S CASES ride with the add-on: modules/<name>/test/cases/*.sh define them, loaded with the
#   harness's own files, and modules/<name>/test/CASE-LIST lists them. They run after the core cases and
#   before case_isolation; a case an add-on defines and does not list refuses the run, as a core
#   case missing from CASES below does (lib/addon-cases.sh). A tree without that directory has none.
#
# A PROJECT'S OWN CASES: define them in a file under scripts/test/cases/ and add their names to the CASES array
#   below, above case_isolation; they run with every other case, whether or not scripts/test/CASE-LIST is on disk.
#
# RUN IT FROM A BUILT KIT. It is a witness only when run from an unzipped release given
# day-one git topology. The repository that maintains the kit stores it DISARMED
# (`_claude/`, not `.claude/`), so in place the day-one cases skip and false reds occur;
# the harness refuses there, because that tree has no process/KIT-MANIFEST.
#
# A few sites read whichever of `_claude/` or `.claude/` exists, so they still find the
# shipped tree in place. That is a convenience at those sites, not a mode this harness
# offers: do not widen it into one. To list them (the comment skip keeps this recipe
# from matching itself):
#
#   awk '!/^[[:space:]]*#/ && /_claude/ && /REAL_REPO_ROOT/ {print FILENAME":"FNR": "fn}
#        /^[A-Za-z_][A-Za-z0-9_]*\(\)/{fn=$1}' scripts/test/run.sh scripts/test/lib/*.sh scripts/test/cases/*.sh
#
# THE PIPEFAIL RULE. Under `set -o pipefail`, a reader that exits before draining its
# input — `grep -q`, `grep -m`, `head`, `sed …q`, `read` — closes the pipe; once the
# producer's output exceeds the 64KB pipe buffer the producer dies of SIGPIPE, and
# pipefail makes that the pipeline's status, so a match reads as "not found". Capturing
# the output into a variable first does not help: it only moves which process dies.
#   • IN THIS HARNESS write no `find … | head -1` and no piped `grep -q`: every producer is a
#     fixture a future case can enlarge. Other early readers (`head` after grep or sed,
#     `grep -m`, `sed …q`, `read`) are not censused; prefer a here-string or a variable for them.
#   • IN THE SHIPPED SCRIPTS the rule binds producers that can grow (a repository, a
#     board, a history, the network, a function's output). A pipe validating a single flag
#     value is left.
#   case_probe_victim_selection_survives_pipefail enforces the harness half and the shipped
#   `git`/`find`/`ls`/`cat` producers piped into `grep -q`; case_shipped_membership_tests_do_not_pipe_a_list
#   enforces a variable list or a function's output piped into a quiet grep. The fix: drop the `-q`
#   and redirect (`| grep -F pat >/dev/null` drains the input and returns the same
#   status), or test the string with `[[ "$out" == *pat* ]]`. A bare `grep -q FILE`
#   has no pipe and is unaffected. A variable that holds a list is read through a
#   here-string (`grep -qx -- "$id" <<< "$list"`), never piped from `printf`.
set -uo pipefail

# A USAGE REQUEST IS ALWAYS LEGAL AND ALWAYS SUCCEEDS, IN ANY POSITION (process/contracts/issue-creation.md § 3).
for _a in "$@"; do case "$_a" in -h|--help) set -- --help; break ;; esac; done
case "${1:-}" in
  -h|--help)
    # The window ends at the header's last comment line, derived rather than typed.
    _rs_end="$(awk 'NR>2 && !/^#/{print NR-1; exit}' "${BASH_SOURCE[0]:-$0}")"
    sed -n "3,${_rs_end:-34}p" "${BASH_SOURCE[0]:-$0}" | sed 's|^# \{0,1\}||'
    exit 0 ;;
esac
# THE SELECTOR (the header says what a selected run is). A flag beats the environment variable.
SEL_VIA=""; SEL_LIST="${KIT_TEST_CASES:-}"; SEL_LISTONLY=""; SEL_CORE=""
[ -z "$SEL_LIST" ] || SEL_VIA="KIT_TEST_CASES"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --cases) [ "$#" -ge 2 ] || { echo "run.sh: --cases takes a list of case names, comma or space separated." >&2; echo "        Next: ./scripts/test/run.sh --list prints the names." >&2; exit 2; }
             SEL_VIA="--cases"; SEL_LIST="$2"; shift 2 ;;
    --cases=*) SEL_VIA="--cases"; SEL_LIST="${1#--cases=}"; shift ;;
    --core) SEL_CORE=1; shift ;;
    --list) SEL_LISTONLY=1; shift ;;
    *) echo "run.sh: unknown option '$1' — this harness takes --cases <names>, --core and --list, or no arguments." >&2
       echo "        Run  run.sh --help  for what it does." >&2
       exit 2 ;;
  esac
done

# perl is required: nearly every sandbox is built with it, so there is no skip path.
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
# `process/KIT-MANIFEST` is generated by the build and never tracked, so its presence answers
# "am I a built kit?". The cases about the shipped population derive it from this manifest;
# with a skip they would run against nothing and print a green.
if [ ! -f "$REAL_REPO_ROOT/process/KIT-MANIFEST" ]; then
  {
    echo "run.sh: REFUSING — there is no process/KIT-MANIFEST in this tree."
    echo
    echo "  This harness is a witness only when it runs from a BUILT KIT: an unzipped release"
    echo "  given day-one git topology. The manifest is written by the build and is never"
    echo "  tracked, so its absence means one of four things, and none of them is runnable:"
    echo
    echo "    * this is a clone of the kit's repository. A clone has no manifest. In an unmodified"
    echo "      clone, ./scripts/kit-manifest.sh writes it from the commit, and this runs again;"
    echo "      or run the harness from an unzipped release instead."
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
# Several cases census this harness's source: its role literals, minting cases, piped readers,
# landing prologues and fixture appends. Inside a function `${BASH_SOURCE[0]}` names the file
# the function was DEFINED in, not the harness, so a census must read the population derived
# here from the one list the loader sources: the entry point, then _harness_sourced (lib/*.sh,
# then cases/*.sh, in C-locale order). A file placed there is harness: loaded, and censused.
#
# _harness_probe_copy concatenates the population for the cases that plant into a copy or
# excise their own body; a census reporting a line of it passes it through _harness_where,
# which names the file and the line in it. Every case that reads the population asserts it is
# whole (_harness_population_is_whole), so a population that lost a file reddens.
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ENTRY="$HARNESS_DIR/$(basename "${BASH_SOURCE[0]}")"

_harness_sourced() {  # the files the entry point sources, in load order — THE ONE LIST
  local LC_ALL=C f
  for f in "$HARNESS_DIR"/lib/*.sh "$HARNESS_DIR"/cases/*.sh "$REAL_REPO_ROOT"/modules/*/test/cases/*.sh; do
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
    case "$f" in
      "$HARNESS_DIR"/*) names+=("scripts/test/${f#"$HARNESS_DIR"/}") ;;
      *) names+=("${f#"$REAL_REPO_ROOT"/}") ;;   # an add-on's case file
    esac
    total=$(( total + len )); ends+=("$total")
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
# Held to the case_* functions this shell defines, not to CASES: the case-list check holds the two
# equal before any case runs, and a run cut to fewer cases after that check still defines them all.
_harness_population_is_whole() {
  local n d
  n="$(grep -c '^case_[a-z_0-9]*() {' "$1" || true)"
  d="$(declare -F | grep -c '^declare -f case_' || true)"
  [ "${n:-0}" -eq "${d:-0}" ] \
    || cf "(population) the harness text this case read defines ${n:-0} case_*() function(s) and the shell running it defines ${d:-0}. Either _harness_sources no longer names every file the entry point loads (this census has shrunk to part of the harness and would stay green about the rest), or a case_*() is defined in a shape this count does not read — it reads 'name() {' at column 0 — or text that is not a definition matches it"
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
echo "sandbox seams: prefix=$SB_PREFIX (kit neutral)  trunk=$SB_TRUNK (derived)  first role=$SB_ROLE (kit neutral)"
echo "consumer seam: ${CONSUMER_SCRIPT:-(unset — that family will SKIP)}"
echo
# Before the snapshot: it and case_isolation read `git status`, which must see the same ignore files both times.
# No global or system git config in reach for any case: a key the machine sets must not decide a result.
RUN_GIT_HOME="$(mktemp -d)" || { echo "run.sh: REFUSING — could not create an empty home for the run's git config." >&2; exit 2; }
machine_git_config_off "$RUN_GIT_HOME"
isolation_snapshot

# The run's own progress-record directory. Every refusal a fixture provokes is recorded
# here, so the project's real .progress-records/ is left as the run found it
# (case_isolation compares the two). A case that asserts where a script writes its
# record unsets or overrides it.
RUN_PROGRESS_SCRATCH="$(mktemp -d)" || { echo "run.sh: REFUSING — could not create a scratch directory for the run's progress records." >&2; exit 2; }
export KIT_PROGRESS_DIR="$RUN_PROGRESS_SCRATCH"
# The mover's test seam for the trunk gate it runs on a move to qa_complete/ that no finish-pr.sh landing vouches for
# (scripts/lib/qa-gate.sh kit_trunk_gate_check): ON by default, so the cases that need a card to move stay about their
# own subject. The cases that are about the gate unset both (landing.sh _mvg_run).
export MOVE_ISSUE_TEST_ALLOW_STUB=1 MOVE_ISSUE_GATE_CMD=true
trap 'teardown; rm -rf "$RUN_PROGRESS_SCRATCH" "$RUN_GIT_HOME"' EXIT

# ── THE CASE LIST. Explicit for ORDER, derived for COMPLETENESS. ─────────────
# The array is the smoke list and the cases that must run first, ending with case_isolation. The rest of the cases
# are listed in scripts/test/CASE-LIST (lib/case-list.sh).
# The order cannot be generated: case_isolation must run last (it compares the real
# repo against the snapshot taken above), case_ship_state reads the real tree, and the
# check-board and release families build on cheaper cases having proven their
# primitives. Membership is compared below with the defined case_* functions, so a
# case missing from this list refuses the run rather than silently never running.
CASES=(
  case_move_issue
  case_module_enable_and_disable_are_inverse_and_idempotent
  case_every_shipped_module_is_indexed_and_enables_and_disables_cleanly
  case_kit_upgrade_merges_by_the_shipped_manifest
  case_finish_pr_happy
  case_kit_init_markers_intact
  case_kit_init_commits_under_the_pre_role_hat
  case_next_id
  case_commit_msg
  case_pre_commit_refuses_metadata_off_trunk
  case_check_board_graduation_requires_the_day_one_work
  case_new_prd_failure_leaves_nothing
  case_template_links_resolve_from_their_destination
  case_shipped_scripts_stay_on_the_floor
  case_shipped_manifest_describes_the_tree
  case_pack_round_trip_is_byte_equal
  case_pack_is_a_function_of_its_members
  case_pack_reader_refuses_hostile_members
  case_pack_reader_refuses_to_overwrite
  case_pack_reader_runs_on_the_floor
  case_pack_programs_stay_on_the_floor
  case_pack_survives_the_adopters_git_attributes
  case_packs_dir_is_named_once
  case_pack_unpack_then_remove_leaves_the_tree_as_it_was
  case_pack_remove_keeps_an_edited_member
  case_pack_refusals_name_their_next_step
  case_smoke_list_is_defined_and_alone_sufficient
  case_run_says_how_many_cases_are_in_a_pack
  case_defined_equals_listed_per_population
  case_unpack_all_restores_the_full_population
  case_isolation
)

# THE CORE: the cases `--core` runs, a PARTIAL run like any other selection. A measured list (timed 2026-11-23): every
# case that took at most two seconds, the shortest case of each cases file that has none, and the whole-tree census
# cases (the exit and refusal classifications, the cited case names, the shipped tree's citation check), which catch
# what a change's own cases miss, and the early-exit reader's deterministic row (a card move failed under load once, and
# that row fails every time the defect is there). It is a snapshot: a case added later is outside it until it is listed here, and a
# listed name this tree does not define (a removed add-on's case) is left out of `--core` and named, and the self-test
# holds the list to the shipped tree. The full run, which only the full list's
# exit 0 stands for, still gates a cut.
CORE_CASES=(
  case_move_issue
  case_board_property_i_reads_lists_through_the_one_reader
  case_creator_prints_a_commit_line_the_hook_accepts
  case_progress_record_alone_checks_the_declared_role_set
  case_subtask_qa_verdict_fail_in_backticks_refuses
  case_subtask_qa_verdict_token_invalid_refuses
  case_subtask_refuses_its_own_edited_call
  case_subtask_forks_missing_refuses
  case_read_verdict_reads_the_trunk_and_writes_nothing
  case_read_verdict_names_the_deferred_landing
  case_subtask_qa_verdict_pointer_unresolved_refuses
  case_role_literals_are_declared
  case_register_commit_that_carries_the_role_declaration_still_lands
  case_role_layer_files_with_crlf_lines_are_read
  case_an_unreadable_base_leaves_the_role_set_empty_whatever_the_layers_hold
  case_process_roles_ships_with_no_role_line
  case_session_start_keeps_a_check_board_d_arm_heading_past_the_budget
  case_marker_block_insert_is_idempotent_and_remove_restores_the_bytes
  case_marker_block_gitignore_block_goes_at_the_end_and_a_created_file_is_removed
  case_marker_block_remove_keeps_a_gitignore_that_existed_empty
  case_marker_block_a_refused_write_leaves_no_scratch_file
  case_marker_block_a_refused_write_takes_back_the_file_the_insert_created
  case_marker_block_insert_leaves_a_dangling_link_at_the_host_path_alone
  case_a_pass_row_whose_cell_check_passed_is_not_the_observed_row
  case_the_cell_check_rule_verify_line_fails_on_a_begun_table_with_no_observed_row_and_only_on_one
  case_the_kill_stand_ins_kill_only_the_marked_process_and_its_branch
  case_the_module_less_skip_reason_names_a_file_that_is_absent_and_the_shape_test_reads_a_manifest
  case_fixture_library_lists_follow_the_scripts_source_lines
  case_module_list_ends_with_a_refusal_made_inside_its_loop
  case_the_module_file_writer_refuses_a_linked_directory_above_its_destination
  case_the_upgrades_module_duties_are_listed_once
  case_the_catalogue_lists_a_disabled_module_with_what_it_needs
  case_every_shipped_module_has_setup_steps_and_a_catalogue_row_that_agrees_with_its_manifest
  case_the_files_an_agent_reads_first_name_the_module_catalogue
  case_progress_record_one_place_across_worktrees
  case_refusal_leaves_one_countable_record
  case_kit_upgrade_merges_by_the_shipped_manifest
  case_kit_upgrade_stamps_only_when_the_checklist_is_done
  case_kit_upgrade_refuses_with_a_record
  case_kit_upgrade_stages_nothing_live
  case_check_board_upgrade_line_names_the_duty_and_its_source
  case_member_removed_reads_the_manifest_disposition
  case_kit_upgrade_blocks_the_stub_over_a_graduated_agents_md
  case_kit_upgrade_still_replaces_an_ungraduated_stub
  case_kit_upgrade_removed_upstream_reflects_a_local_edit
  case_kit_upgrade_finish_archives_the_marked_checklist
  case_two_same_version_upgrades_with_real_work_archive_under_different_names
  case_an_arrived_record_alone_is_work_and_is_not_nothing_to_do
  case_the_upgrade_fixture_carries_the_libraries_the_script_sources_unconditionally_at_start
  case_kit_upgrade_finish_runs_verify_commands
  case_kit_upgrade_reads_the_release_history_for_skipped_releases
  case_kit_upgrade_pointers_name_the_file_that_holds_the_entry
  case_upgrade_seat_brief_names_the_trunk_route
  case_ask_help_answers_first
  case_ask_refuses_with_no_principal
  case_ask_refuses_when_asker_is_principal
  case_ask_principal_phrase_is_normalised
  case_ask_channel_stays_inside_the_repository
  case_ask_same_second_asks_file_one_question_each
  case_ask_default_reaches_the_register_byte_for_byte
  case_ask_channel_through_a_symlink_out_of_the_repository_is_refused
  case_ask_writes_one_file_and_returns
  case_ask_never_overwrites_a_standing_ruling
  case_ask_standing_note_names_no_wrong_direction
  case_ask_reads_the_withdrawn_token_as_the_format_shows_it
  case_ask_without_decision_names_the_file_as_the_record
  case_ask_card_option_records_the_parked_card
  case_ask_question_file_names_who_lands_the_answer
  case_answered_question_reconcile_is_named_where_it_is_read
  case_unattended_profile_denies_the_tool
  case_orchestrate_has_an_unattended_branch_where_it_is_read
  case_run_report_template_has_a_no_pack_banner_and_runners_name_it
  case_stop_ask_hook_classifies_turn_endings
  case_agent_record_hook_attributes_created_commits
  case_finish_pr_crash_under_the_lock_is_not_success
  case_exit_trap_keeps_the_status_the_script_exits_with
  case_finish_pr_board_property_check_reads_the_branch_not_a_tag_of_its_name
  case_script_wordings_blocked_by_help_and_stacked_routing
  case_card_branch_resolves_through_one_function
  case_the_acs_the_kit_teaches_are_lines_the_ac_reader_accepts
  case_board_property_loader_reads_the_status_folder_set_from_the_trunks_declaration
  case_check_board_reads_a_card_that_export_ignore_hides
  case_qa_verdict_shadow_check_fail_token_refuses
  case_check_board_arm_keeps_the_callers_locale
  case_verdict_section_and_lived_probe_read_a_byte_wise
  case_check_board_says_did_not_run_when_mktemp_fails
  case_a_reader_cut_off_by_its_consumer_is_not_recorded_as_failed
  case_set_models_writes_an_id_as_given_or_refuses_it_and_pins_only_the_frontmatter
  case_notify_refuses_the_watchdog_as_a_backend
  case_hygiene_instruments_refuse_a_missing_root_and_an_absurd_parameter
  case_staleness_greps_read_a_claim_only_where_it_is_said
  case_verify_refuses_a_gate_with_a_blank_command
  case_new_prd_ignores_a_file_that_carries_no_number
  case_brainstorm_stop_server_does_not_delete_through_a_dotdot_path
  case_check_board_reads_a_lower_case_id_and_a_quoted_path
  case_check_board_reads_a_table_row_with_an_escaped_pipe_in_a_cell
  case_a_grep_failure_is_blamed_on_the_shape_only_when_the_shape_is_bad
  case_make_sandbox_leaves_the_callers_loop_variable_and_working_directory_alone
  case_finish_pr_qa_verdict_missing_table_refuses
  case_finish_pr_qa_verdict_fail_row_on_pass_refuses
  case_pre_commit_refuses_a_hand_move_with_an_unclosed_fence
  case_a_pointer_to_the_last_line_of_a_file_with_no_final_newline_resolves
  case_qa_evidence_kind_sentences_cite_the_declaration
  case_finish_pr_qa_verdict_self_pointer_refuses
  case_qa_gate_verdict_set_is_the_ratified_set
  case_finish_pr_ablation_rename_out_of_globs_refuses
  case_finish_pr_refuses_a_library_gutted_on_the_branch
  case_finish_pr_refuses_when_the_refusal_helper_is_gutted_too
  case_finish_pr_refuses_when_a_library_redefines_exit
  case_move_issue_refuses_when_a_library_redefines_exit
  case_the_tools_leave_the_board_worktree_alone_when_there_is_no_trunk_ref
  case_the_mover_refuses_a_deleted_progress_record_library
  case_the_held_list_names_every_file_the_landing_and_slice_tools_source
  case_finish_pr_stacked_branch_unlanded_base_refuses
  case_archive_apply
  case_one_member_role_tag_refuses_before_mutating
  case_archive_index_refuses_malformed
  case_runner_schema_required_defines
  case_runner_schemas_agree
  case_runner_outcome_vocabulary_agrees
  case_runner_twin_code_is_identical
  case_runner_goldenpaths_empty_skips
  case_minted_card_is_unmarked
  case_shipped_runners_parse
  case_skills_carry_no_foreign_namespace
  case_skills_name_no_forge_unconditionally
  case_project_md_one_row_per_contract_sheet
  case_upstream_name_only_where_kept
  case_dev_index_names_its_subdirs
  case_archive_missing_index_lists_the_store
  case_archive_feature_branch_clean
  case_config_seam_refusal
  case_next_id_outside_a_repository_reports_once
  case_next_id_reads_the_trunk
  case_creation_id_check_reads_the_trunk
  case_commit_msg_attribution_family
  case_commit_msg_reads_trailers_through_the_one_reader
  case_check_board_arm_e_reports_an_empty_subject
  case_pre_commit_undeclared_code_globs_is_a_noop
  case_pre_commit_refuses_metadata_off_trunk
  case_pre_commit_judges_an_amend_on_the_commit_being_made
  case_pre_commit_reads_code_globs_through_the_shared_reader
  case_pre_commit_allows_metadata_on_trunk
  case_pre_commit_allows_code_on_a_branch
  case_pre_commit_refuses_a_commit_with_no_hat
  case_pre_commit_refuses_a_staged_hat_file
  case_push_failure
  case_push_retry_unreachable_remote_names_the_unlanded_commits
  case_bootstrap_failure_next_names_the_trunk_not_set_head_a
  case_archive_progress_sections
  case_rotation_day_uses_the_board_clock
  case_archive_progress_ordinal_knife
  case_archive_progress_honest_noop
  case_archive_progress_dry_run_writes_nothing
  case_archive_progress_apply_does_not_say_would_write
  case_settings_example_glosses_only_real_placeholders
  case_runner_key_guards_admit_every_field_they_read
  case_downtime_queue_claim_drift
  case_check_board_arm_j_reads_the_named_source
  case_check_board_arm_j_finding_is_not_folded
  case_workflow_briefs_compose_from_a_sparse_payload
  case_runner_refuses_a_prose_payload_by_name
  case_runner_no_verdict_is_not_a_failure
  case_runner_absent_reply_is_named_not_judged
  case_runner_throwing_leg_is_named_not_dropped
  case_runner_precondition_failure_has_a_reply
  case_runner_returns_leg_notes_on_every_outcome
  case_leg_report_contract_is_in_every_schema
  case_runner_promotes_only_observed_verdicts
  case_runner_typed_leg_keeps_its_frontmatter_pin
  case_wave_brief_matches_the_legs_checkout
  case_archive_progress_before_must_be_a_calendar_date
  case_archive_progress_index
  case_verify_frame
  case_guard_floor_unenrolled_from_shipped_empty_set
  case_guard_floor_enumerator_mistyped
  case_guard_floor_enumerator_succeeds_empty
  case_guard_floor_unseen_declared_guard
  case_guard_floor_reconciles_and_says_so
  case_guard_floor_wholly_empty_shipped_state
  case_verify_all_core_guard_floor_is_reported_inert
  case_verdict_enum_projection
  case_verify_unrunnable_vs_fail
  case_verify_exit_status_separates_the_reds
  case_check_board_id_clean
  case_check_board_without_its_status_folder_library_names_the_control
  case_check_board_id_duplicate
  case_check_board_id_mismatch
  case_check_board_frontmatter_offset
  case_check_board_register_absent
  case_check_board_citation_forms_and_population
  case_set_models_second_call_moves_the_ladder_row
  case_check_board_arrow_beats_mention
  case_check_board_declined_is_judged_and_counted
  case_check_board_reads_the_configured_archive_threshold
  case_setup_warns_on_a_later_added_column
  case_setup_reads_the_archived_heading_exactly
  case_setup_does_not_say_complete_before_it_refuses
  case_check_board_reads_the_ref
  case_check_board_arm_e_counts_exempt_apart
  case_register_format_text_states_the_bold_stamp
  case_check_board_shallow_clone_does_not_narrow
  case_kwt_file_mtime_is_one_epoch_number
  case_check_board_graduation_enabled_without_receipt
  case_check_board_graduation_not_run_direction
  case_check_board_graduation_reads_the_trunk
  case_seed_done_list_names_the_prd_and_the_model_rows
  case_check_board_replace_population_is_derived
  case_release_refactor_routes_are_delete_if_unused
  case_check_board_names_a_detached_head
  case_check_board_graduation_verdict_is_not_wired
  case_check_board_graduation_refuses_complete_over_nothing_measured
  case_card_title_templates_quote_and_the_reader_strips
  case_archive_index_row_carries_the_bare_title
  case_check_board_unquoted_title_arm
  case_subtask_new_quotes_a_colon_title
  case_day_one_homes_and_role_exception_wordings
  case_session_start_hook_output_stays_within_the_delivery_budget
  case_lived_probe_has_one_authoring_site
  case_kit_init_refuses_lived_board
  case_kit_init_next_line_repeats_only_the_arguments_given
  case_the_hooks_act_is_worded_the_same_wherever_the_kit_names_it
  case_new_prd_failure_leaves_nothing
  case_creators_build_beside_and_publish_with_the_umask
  case_kit_init_roles_help_names_the_layer_files_as_the_other_route
  case_notify_lists_only_adapters
  case_notify_message_flag_carries_a_leading_dash
  case_notify_help_is_the_header_and_the_hook_answers_without_stdin
  case_telegram_chatid_names_a_missing_jq
  case_creator_usage_prints_one_form_on_every_path
  case_move_issue_without_role_prints_one_usage_line
  case_usage_text_states_what_scope_and_approve_shipped_do
  case_no_shipped_file_hard_codes_the_grep_path
  case_cited_case_names_exist
  case_contract_rule_id_tables_match_the_ids_raised
  case_project_credential_blank_is_countable
  case_leaf_workers_carry_the_common_sections
  case_provisioning_ceiling_keeps_the_seat_rule
  case_agent_model_pins_match_their_declaration
  case_optional_model_classes_match_the_pin_files_declaring_delete_if_unused
  case_model_pins_vs_own_ladder
  case_set_models_class_rewrites_pin_and_ladder_only
  case_set_models_all_rewrites_runners_too
  case_set_models_unknown_class_refuses
  case_set_models_and_kit_upgrade_help_name_the_surplus_argument_exit
  case_set_models_list_changes_nothing
  case_doctrine_states_no_rule_count
  case_release_bash_n
  case_consumer_updater
  case_install_skills_writes_nothing_without_a_pack
  case_updater_help_states_the_check_cost_and_points_to_the_hook_page
  case_find_polluter_runs_each_path_whole
  case_find_polluter_refuses_an_unrunnable_test_command
  case_brainstorm_stop_server_leaves_no_server_info
  case_brainstorm_foreground_start_records_the_servers_pid
  case_brainstorm_server_reads_a_zombie_owner_as_exited
  case_reachability_self_test_fails_when_edge_d_is_ablated
  case_release_history_action_required_entries_are_read
  case_cold_signal_reads_non_ascii_paths
  case_agent_prose_carries_its_riders
  case_partial_prefix_derivation_says_so
  case_travelling_scripts_have_a_sheet
  case_gates_command_field_is_excluded_from_the_floor
  case_every_refusal_names_its_next_action
  case_every_nonzero_exit_is_classified
  case_every_library_return_is_classified
  case_role_set_read_is_one_expression
  case_every_arm_file_seam_is_declared_in_the_contract
  case_advisory_headers_carry_the_machine_token
  case_minting_cases_probe_for_the_template
  case_shipped_membership_tests_do_not_pipe_a_list
  case_release_unmutated_names_the_cut
  case_landing_prologue_is_complete
  case_finish_pr_help_names_post_merge_prep
  case_shipped_tree_is_citation_clean_after_kit_init
  case_fixture_append_has_one_authoring_site
  case_population_row_counts_the_defined_cases_not_the_run_list
  case_role_reset_takes_a_narrowed_set
  case_shipped_manifest_describes_the_tree
  case_status_folder_set_is_declared_in_one_shipped_script
  case_the_design_pass_directory_is_design_passes_and_indexed
  case_kit_feedback_shape_has_the_printed_event_moment_effect_and_root_causes
  case_the_harness_runs_an_add_ons_cases_and_refuses_one_that_is_not_listed
  case_the_selector_runs_named_cases_marks_the_run_partial_and_gives_it_its_own_exit_status
  case_update_vendored_does_not_print_a_pin_for_an_artifact_it_could_not_write
  case_archive_progress_finds_a_cut_off_rotation_and_prints_the_row_a_rotation_writes
  case_register_commit_judges_a_trunk_that_tracks_two_spellings_by_the_exact_one
  case_ship_state
  case_isolation_is_read_with_the_machines_git_config_shut_out
  case_the_ac_lines_the_design_guides_teach_are_read_by_the_qa_gates_own_reader
  case_the_designer_role_names_each_capability_this_version_lacks_and_drops_the_line_when_it_ships
  case_no_design_text_tells_a_role_to_render_the_pinned_side_while_the_renderer_is_absent
  case_the_design_module_cites_no_decision_id_the_project_cannot_hold
  case_the_wireframe_docs_name_the_mode_and_the_ignore_set_the_checker_holds
  case_the_token_tools_write_what_the_design_type_reads_and_the_audit_measures_it
  case_render_py_draws_the_pulled_boards_in_real_chrome_with_the_scheme_and_the_theme_that_were_asked_for
  case_normalise_canvas_gives_a_page_save_the_spelling_an_agent_writes_and_says_what_it_cannot_read
  case_the_design_docs_state_what_leaving_takes_what_the_gate_row_needs_and_what_disable_leaves
  case_the_audit_reads_a_targets_size_as_the_browser_does_a_pair_in_its_own_namespace_and_no_unpaired_overlay_as_unread
  case_the_example_modules_release_notes_hold_no_action_required_entry_to_copy_as_one
  case_an_ac_bullet_reader_does_not_fail_when_the_body_runs_on_after_the_bullet
  case_isolation
)

# The cases in scripts/test/CASE-LIST join the list here, then an add-on's.
_harness_add_listed_cases "$HARNESS_DIR" || exit 2
_harness_packed_note "$REAL_REPO_ROOT"

# An add-on's cases (modules/<name>/test/, lib/addon-cases.sh) join the list here: each add-on's
# own test/CASE-LIST is held against what its files define, and a disagreement refuses the run.
_harness_add_addon_cases "$REAL_REPO_ROOT" || exit 2

# Every case_* function that exists must be in CASES, and vice versa. A mismatch is
# FATAL before any case runs.
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
    echo "  Fix the CASES array above, or the add-on's modules/<name>/test/CASE-LIST for one of its cases."
    echo "  Both sides of this comparison are derived, so the only way to satisfy it is to"
    echo "  actually list the case."
  } >&2
  exit 2
fi
echo "locale: LC_ALL=${LC_ALL:-<unset>} LANG=${LANG:-<unset>}  (a bash 3.2 pattern range reads capitals as lowercase under a UTF-8 locale that has a collation)"
echo "case list: ${#CASES[@]} case(s), and every defined case_* is listed."
[ -z "$PACKED_NOTE" ] || echo "$PACKED_NOTE"
echo

# ── THE SELECTOR. Applied after the check above, so the full run is untouched. ───────────────────────────
if [ -n "$SEL_LISTONLY" ]; then printf '%s\n' "${CASES[@]}"; exit 0; fi
PARTIAL=""
if [ -n "$SEL_CORE" ]; then
  if [ -n "$SEL_VIA" ]; then
    echo "run.sh: REFUSING — --core cannot be combined with $SEL_VIA: each selects its own list." >&2
    echo "        Next: run  run.sh --core  alone, or name the cases with --cases and leave --core out." >&2
    exit 2
  fi
  # The list names the cases of add-ons as well as core cases, and a project may delete an add-on's directory
  # (process/MODULES.md): a listed case this tree does not define is left out and named, never a refusal whose
  # route (copy a name from --list) cannot lead out. The list's freshness is held where the add-ons are, by
  # case_every_core_case_is_defined_where_the_shipped_add_ons_are. A name typed to --cases still refuses.
  _core_keep=""; _core_out=""; _core_n_out=0
  for _n in "${CORE_CASES[@]}"; do
    _found=""
    for _c in "${CASES[@]}"; do [ "$_c" = "$_n" ] && { _found=1; break; }; done
    if [ -n "$_found" ]; then _core_keep="$_core_keep $_n"; else _core_out="$_core_out $_n"; _core_n_out=$(( _core_n_out + 1 )); fi
  done
  SEL_VIA="--core"; SEL_LIST="${_core_keep# }"
  [ "$_core_n_out" -eq 0 ] || echo "core: left out $_core_n_out listed case(s) this tree does not define (an add-on whose directory was removed):$_core_out"
fi
if [ -n "$SEL_VIA" ]; then
  _sel_names="$SEL_LIST"
  _sel_names="$(printf '%s' "$_sel_names" | tr ',\n\t' '   ' | tr -s ' ')"; _sel_names="${_sel_names# }"; _sel_names="${_sel_names% }"
  if [ -z "$_sel_names" ]; then
    echo "run.sh: REFUSING — $SEL_VIA names no case, so nothing would run." >&2
    echo "        Next: ./scripts/test/run.sh --list prints the cases this harness defines." >&2
    exit 2
  fi
  _sel_unknown=""
  for _n in $_sel_names; do
    _found=""
    for _c in "${CASES[@]}"; do [ "$_c" = "$_n" ] && { _found=1; break; }; done
    [ -n "$_found" ] || _sel_unknown="$_sel_unknown $_n"
  done
  if [ -n "$_sel_unknown" ]; then
    echo "run.sh: REFUSING — $SEL_VIA names a case this harness does not define:$_sel_unknown" >&2
    echo "        Nothing ran. Next: ./scripts/test/run.sh --list prints the defined case names; copy one from there." >&2
    exit 2
  fi
  _total_cases=${#CASES[@]}
  _sel_cases=()
  for _c in "${CASES[@]}"; do
    for _n in $_sel_names; do [ "$_c" = "$_n" ] && { _sel_cases+=("$_c"); break; }; done
  done
  CASES=("${_sel_cases[@]}")
  PARTIAL="partial: ${#CASES[@]} of $_total_cases case(s) selected by $SEL_VIA — this is NOT a full run; exit 3 means every selected case passed, exit 0 is the full list's alone."
  echo "$PARTIAL"
  echo
fi

# ── THE RUN, AND A STABLE IDENTITY FOR EACH CASE'S OUTCOME. ──────────────────
#
# The outcome is keyed on the case's FUNCTION NAME, not its printed line: a finish line may
# embed a derived count, and an N/A case never reaches its finish line, so the printed text
# differs between two legitimate trees. Compare runs with the case-outcome: lines below.
declare -a CASE_OUTCOMES CASE_SECONDS
_multi=""
for _c in "${CASES[@]}"; do
  _p0=$PASS; _f0=$FAIL; _s0=$SKIP; _l0=$LIVED; _t0=$SECONDS
  "$_c"
  CASE_SECONDS+=("$_c $((SECONDS - _t0))")
  _n=$(( (PASS-_p0) + (FAIL-_f0) + (SKIP-_s0) + (LIVED-_l0) ))
  if   [ "$FAIL"  -gt "$_f0" ]; then _o=FAIL
  elif [ "$LIVED" -gt "$_l0" ]; then _o=LIVED
  elif [ "$SKIP"  -gt "$_s0" ]; then _o=SKIP
  elif [ "$PASS"  -gt "$_p0" ]; then _o=PASS
  else _o=NO-OUTCOME
  fi
  # ── INSTRUMENT CHECK: exactly one outcome per case. A case recording none is invisible in
  #    every count; one recording two makes the outcome table ambiguous.
  [ "$_n" -eq 1 ] || _multi="$_multi $_c($_n)"
  CASE_OUTCOMES+=("$_c $_o")
done

echo
echo "════════════════════════════════════════════════════════"
printf 'summary: %d PASS, %d FAIL, %d SKIP, %d N/A-on-lived-tree\n' "$PASS" "$FAIL" "$SKIP" "$LIVED"
[ -z "$PACKED_NOTE" ] || echo "$PACKED_NOTE"
[ -z "$PARTIAL" ] || echo "$PARTIAL"
# THE N/A LIST IS PRINTED, NOT JUST COUNTED: a case with no subject on this tree otherwise
# looks exactly like a case that passed.
if [ "$LIVED" -gt 0 ]; then
  echo
  echo "N/A on a lived tree — these cases had no subject on THIS tree, each naming the file whose"
  echo "shipped shape is absent. On the pristine tree this list is expected to be empty."
  for _r in "${RESULTS[@]}"; do case "$_r" in "N/A   "*) printf '  %s\n' "${_r#N/A   }" ;; esac; done
fi
echo "════════════════════════════════════════════════════════"

# The machine-readable outcome table: one line per case, keyed on its function name.
echo
for _r in "${CASE_OUTCOMES[@]}"; do printf 'case-outcome: %s\n' "$_r"; done
# Each case's seconds, in the run's order, then the run's own (the whole script, not the sum of the cases):
# the measured list a partition is chosen from. A report; no check reads it.
for _r in "${CASE_SECONDS[@]}"; do printf 'case-seconds: %s\n' "$_r"; done
printf 'run-seconds: %d\n' "$SECONDS"
if [ -n "$_multi" ]; then
  echo
  echo "harness: REFUSING — these case(s) did not record exactly one outcome:$_multi"
  echo "  A case recording NONE is invisible in every count above; a case recording TWO makes the"
  echo "  outcome table ambiguous. Both are defects in the case, not in the tree under test."
  exit 2
fi
[ "$FAIL" -eq 0 ] || exit 1
[ -z "$PARTIAL" ] || exit 3
exit 0
