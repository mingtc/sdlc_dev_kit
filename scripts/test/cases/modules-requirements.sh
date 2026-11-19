# KIT-CLASS: MIXED — self-test harness, what a module needs, its setup, and how a project finds it. See
# process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/modules-requirements.sh — sourced by scripts/test/run.sh, never run on its own.
# The manifest's `requires:` and `requires-agent:` lines, the checks enable runs on them, the SETUP.md a
# module prints, the catalogue that lists a module while it is off, and the one-line pointers that name the
# catalogue from the files an agent reads first. Driven over small fabricated modules (the grammar is the
# operand, so a module's own text must not decide it) and over every module the kit ships (a census). The
# helpers are in lib/modules.sh. A project that deleted modules/ has the census N/A (the file named in the
# reason); the programs being absent is never N/A, because they ship with the kit.
# =============================================================================

# _mq_mod <name> <manifest line>… — modules/<name> in the sandbox: a manifest with the lines, one file to place.
_mq_mod() {
  local d="$SB_WORK/modules/$1"; shift
  mkdir -p "$d"
  { printf 'name: %s\nversion: 0.1.0\npurpose: A fabricated module that needs things.\nfile: h.txt -> docs/%s-h.txt\n' "${d##*/}" "${d##*/}"; printf '%s\n' "$@"; } > "$d/module.manifest"
  printf 'a file the module places\n' > "$d/h.txt"
}
# _mq_flat — the last module.sh output on one line, for a failure message.
_mq_flat() { printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-"${1:-260}"; }
# _mq_subject_ok — the programs under test ship; their absence is a failure, never an N/A.
_mq_subject_ok() {
  local f
  for f in scripts/module.sh $(script_libs "$REAL_REPO_ROOT/scripts/module.sh" | sed 's|^|scripts/lib/|'); do
    [ -f "$REAL_REPO_ROOT/$f" ] || { cf "(prereq) $f is absent from the tree under test"; return 1; }
  done
}
_mq_missing='command -v kit-no-such-tool-7f3a'

# =============================================================================
# CASE — ENABLE REFUSES A MISSING REQUIRED COMMAND, NAMING THE NEXT STEP, AND WARNS OF AN OPTIONAL ONE.
#   Operand: the fabricated module's manifest. (a) a required check that fails refuses with nothing written,
#   the id and how to get it named, a Next: line and a record; (b) the same module enables once the check
#   holds; (c) an optional check that fails enables and warns, naming what is lost; (d) a check may contain
#   a pipe, because the line is read from both ends; (e) a failing check by status, not only by absence.
# =============================================================================
case_module_enable_refuses_a_missing_required_command_and_warns_of_an_optional_one() {
  cf_reset
  local L="module.sh enable refuses, writing nothing and naming the requirement, how to get it and a Next: line, when a required check fails, enables once it holds, enables and warns when only an optional check fails, and reads a check that contains a pipe"
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mq_subject_ok || { finish "$L"; return; }
  _md_sandbox
  local s0="$SB_TMP/snap0" s1="$SB_TMP/snap1"

  # (a) a required command that is not there
  _mq_mod needy "requires: toolx | $_mq_missing | install toolx from its vendor | required"
  _md_snap "$SB_WORK" > "$s0"
  _md_mod enable needy
  [ "$_md_rc" -eq 1 ] || cf "(a) enable exited $_md_rc, want 1: $(_mq_flat)"
  printf '%s\n' "$_md_out" | grep -F 'toolx' >/dev/null || cf "(a) the refusal does not name the requirement: $(_mq_flat)"
  printf '%s\n' "$_md_out" | grep -F 'install toolx from its vendor' >/dev/null || cf "(a) the refusal does not say how to get it: $(_mq_flat)"
  printf '%s\n' "$_md_out" | grep '^Next:' >/dev/null || cf "(a) the refusal carries no Next: line: $(_mq_flat)"
  printf '%s\n' "$_md_out" | grep -F 'NOTHING WAS CHANGED' >/dev/null || cf "(a) the refusal does not say NOTHING WAS CHANGED"
  [ "$(_md_recs module-requires-missing)" = 1 ] || cf "(a) no refusal=module-requires-missing record"
  _md_snap "$SB_WORK" > "$s1"; cmp -s "$s0" "$s1" || cf "(a) the refused enable changed the tree: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-200)"
  [ -e "$SB_WORK/process/MODULES" ] && cf "(a) the refused enable left a record"

  # (b) the same module, with the requirement met by a check that holds
  _mq_mod needy "requires: sh | command -v sh | install a POSIX shell | required"
  _md_mod enable needy
  [ "$_md_rc" -eq 0 ] || cf "(b) enable exited $_md_rc with the requirement met: $(_mq_flat)"
  [ -f "$SB_WORK/docs/needy-h.txt" ] || cf "(b) enable did not place the module's file"
  printf '%s\n' "$_md_out" | grep -F 'warning' >/dev/null && cf "(b) enable warned although every requirement holds: $(_mq_flat)"
  _md_mod disable needy

  # (c) an optional command that is not there
  _mq_mod soft "requires: gizmo | $_mq_missing | install gizmo | optional: the pretty renders"
  _md_mod enable soft
  [ "$_md_rc" -eq 0 ] || cf "(c) enable exited $_md_rc for an optional requirement: $(_mq_flat)"
  printf '%s\n' "$_md_out" | grep -i 'warning' | grep -F 'gizmo' >/dev/null || cf "(c) enable does not warn, naming the optional requirement: $(_mq_flat)"
  printf '%s\n' "$_md_out" | grep -F 'the pretty renders' >/dev/null || cf "(c) the warning does not say what is lost: $(_mq_flat)"
  printf '%s\n' "$_md_out" | grep -F 'install gizmo' >/dev/null || cf "(c) the warning does not say how to get it: $(_mq_flat)"
  grep -E '^module soft ' "$SB_WORK/process/MODULES" >/dev/null || cf "(c) the module is not recorded as enabled"
  _md_mod disable soft

  # (d) a check with a pipe in it holds, and fails, as the shell says
  _mq_mod piped "requires: pipe | printf abc | grep -F b | install grep | required"
  _md_mod enable piped
  [ "$_md_rc" -eq 0 ] || cf "(d) a check containing ' | ' that holds was refused: $(_mq_flat)"
  _md_mod disable piped
  _mq_mod pipedno "requires: pipe | printf abc | grep -F z | install grep | required"
  _md_mod enable pipedno
  [ "$_md_rc" -eq 1 ] || cf "(d) a check containing ' | ' that fails enabled, exit $_md_rc: $(_mq_flat)"

  # (e) a check that fails by its status, then holds
  _mq_mod flagged "requires: flag | test -f ./.needed-flag | create the flag file | required"
  _md_mod enable flagged
  [ "$_md_rc" -eq 1 ] || cf "(e) a check that exits non-zero enabled, exit $_md_rc: $(_mq_flat)"
  : > "$SB_WORK/.needed-flag"
  _md_mod enable flagged
  [ "$_md_rc" -eq 0 ] || cf "(e) enable still refused after the flag was created: $(_mq_flat)"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — A REQUIREMENT CHECK IS BOUNDED, AND NO SCRIPT OF THE KIT RUNS A MODULE'S setup.sh.
#   A check that never ends is stopped and counted as failing, within the limit; enable prints the module's
#   SETUP.md and names setup.sh, and neither enable, status, disable nor list runs it.
# =============================================================================
case_a_requirement_check_is_bounded_and_the_kit_never_runs_a_modules_setup_script() {
  cf_reset
  local L="a requirement check that does not finish is stopped after KIT_MOD_CHECK_SECONDS and counted as failing, and enable prints a module's SETUP.md and names its setup.sh without running it (neither enable, status, list nor disable does)"
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mq_subject_ok || { finish "$L"; return; }
  _md_sandbox
  local t0 t1 mark="$SB_TMP/setup-ran"

  # (a) a check that never ends
  _mq_mod slow "requires: slow | sleep 60 | wait less | required"
  export KIT_MOD_CHECK_SECONDS=1
  t0="$(date +%s)"; _md_mod enable slow; t1="$(date +%s)"
  unset KIT_MOD_CHECK_SECONDS
  [ "$_md_rc" -eq 1 ] || cf "(a) enable exited $_md_rc for a check that never ends, want 1: $(_mq_flat)"
  [ $((t1 - t0)) -le 20 ] || cf "(a) the check ran for $((t1 - t0))s, so nothing stopped it"
  printf '%s\n' "$_md_out" | grep -E 'did not finish|timed out' >/dev/null || cf "(a) the refusal does not say the check did not finish: $(_mq_flat)"
  printf '%s\n' "$_md_out" | grep -F 'wait less' >/dev/null || cf "(a) the refusal does not say how to get it: $(_mq_flat)"
  printf '%s\n' "$_md_out" | grep -F 'KIT_MOD_CHECK_SECONDS' >/dev/null || cf "(a) the timeout refusal does not name KIT_MOD_CHECK_SECONDS, so a slow tool that is there has no way out: $(_mq_flat)"

  # (b) setup: printed, named, never run
  _mq_mod setup1 "requires: sh | command -v sh | a shell | required"
  printf 'Step one: sign in to the tool by hand.\nStep two: copy the key into the vault.\n' > "$SB_WORK/modules/setup1/SETUP.md"
  printf '#!/bin/sh\ntouch "$KIT_TEST_MARK"\n' > "$SB_WORK/modules/setup1/setup.sh"; chmod +x "$SB_WORK/modules/setup1/setup.sh"
  export KIT_TEST_MARK="$mark"
  _md_mod enable setup1
  [ "$_md_rc" -eq 0 ] || cf "(b) enable exited $_md_rc: $(_mq_flat)"
  printf '%s\n' "$_md_out" | grep -F 'Step one: sign in to the tool by hand.' >/dev/null || cf "(b) enable does not print the SETUP.md steps: $(_mq_flat)"
  printf '%s\n' "$_md_out" | grep -F 'modules/setup1/setup.sh' >/dev/null || cf "(b) enable does not name setup.sh: $(_mq_flat)"
  _md_mod status setup1; _md_mod list; _md_mod disable setup1
  unset KIT_TEST_MARK
  [ -e "$mark" ] && cf "(b) a command of the kit ran the module's setup.sh"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — status REPORTS A REQUIREMENT THAT HAS STOPPED HOLDING, AND list SHOWS WHAT EACH MODULE NEEDS.
#   Enabled with every requirement holding, a required one then stops (the flag file goes), then an optional one:
#   status says so by id, with how to get it or what is lost; an agent check is shown and not judged; and it holds
#   again when the file is back. Status exits 0 throughout: it reports, it does not gate.
# =============================================================================
case_status_reports_a_requirement_that_stopped_holding() {
  cf_reset
  local L="module.sh status reports by id a required requirement that stopped holding (with how to get it), an optional one (with what is lost), shows an agent check without judging it, and reports that they hold again; its exit status stays 0"
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mq_subject_ok || { finish "$L"; return; }
  _md_sandbox
  : > "$SB_WORK/.needed-flag"; : > "$SB_WORK/.nice"
  _mq_mod watched \
    'requires: flag | test -f ./.needed-flag | create the flag file | required' \
    'requires: nice | test -f ./.nice | add the nice file | optional: the nice view' \
    'requires-agent: login | call the whoami tool | it names an account | sign in by hand'
  _md_mod enable watched
  [ "$_md_rc" -eq 0 ] || cf "(prereq) enable exited $_md_rc: $(_mq_flat)"
  printf '%s\n' "$_md_out" | grep -F 'login' | grep -F 'call the whoami tool' >/dev/null || cf "(prereq) enable does not print the agent check: $(_mq_flat)"

  _md_mod status watched
  [ "$_md_rc" -eq 0 ] || cf "(a) status exited $_md_rc"
  printf '%s\n' "$_md_out" | grep -E 'requirement flag: holds' >/dev/null || cf "(a) status does not say the flag requirement holds: $(_mq_flat 400)"
  printf '%s\n' "$_md_out" | grep -E 'requirement nice: holds' >/dev/null || cf "(a) status does not say the nice requirement holds: $(_mq_flat 400)"
  printf '%s\n' "$_md_out" | grep -F 'NOT HOLDING' >/dev/null && cf "(a) status reports a requirement not holding although every one holds"
  printf '%s\n' "$_md_out" | grep -E 'agent check login' | grep -F 'it names an account' >/dev/null || cf "(a) status does not show the agent check and what a pass looks like: $(_mq_flat 400)"

  rm -f "$SB_WORK/.needed-flag"
  _md_mod status watched
  [ "$_md_rc" -eq 0 ] || cf "(b) status exited $_md_rc"
  printf '%s\n' "$_md_out" | grep -E 'requirement flag: NOT HOLDING \(required\)' | grep -F 'create the flag file' >/dev/null || cf "(b) status does not report the required requirement that stopped holding, with how to get it: $(_mq_flat 400)"
  printf '%s\n' "$_md_out" | grep -E 'requirement nice: holds' >/dev/null || cf "(b) status stopped reporting the optional requirement that still holds"

  : > "$SB_WORK/.needed-flag"; rm -f "$SB_WORK/.nice"
  _md_mod status watched
  printf '%s\n' "$_md_out" | grep -E 'requirement nice: not holding \(optional\)' | grep -F 'the nice view' >/dev/null || cf "(c) status does not report the optional requirement that stopped holding, with what is lost: $(_mq_flat 400)"
  printf '%s\n' "$_md_out" | grep -E 'requirement flag: holds' >/dev/null || cf "(c) status does not say the flag requirement holds again"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE CATALOGUE LISTS A MODULE THAT IS OFF, WITH WHAT IT NEEDS.
#   Operand: module.sh list, run with nothing enabled, over a fabricated module that needs one thing of each kind.
# =============================================================================
case_the_catalogue_lists_a_disabled_module_with_what_it_needs() {
  cf_reset
  local L="module.sh list, with nothing enabled, shows a disabled module with its purpose and what it needs (a required requirement, an optional one, an agent check), and a module that declares no requirement says so"
  _mq_subject_ok || { finish "$L"; return; }
  _md_sandbox
  _mq_mod cat1 \
    'requires: flag | test -f ./.needed-flag | create the flag file | required' \
    'requires: gizmo | command -v gizmo | install gizmo | optional: the pretty renders' \
    'requires-agent: login | call the whoami tool | it names an account | sign in by hand'
  _mq_mod cat2
  [ ! -e "$SB_WORK/process/MODULES" ] || cf "(prereq) the sandbox already records an enabled module"
  _md_mod list
  [ "$_md_rc" -eq 0 ] || cf "(a) list exited $_md_rc: $(_mq_flat)"
  printf '%s\n' "$_md_out" | grep -E '^  cat1 +0\.1\.0 +disabled +A fabricated module that needs things\.' >/dev/null || cf "(a) list does not show cat1 as disabled with its purpose: $(_mq_flat 400)"
  printf '%s\n' "$_md_out" | grep -F 'needs: flag (required), gizmo (optional), login (agent check)' >/dev/null || cf "(a) list does not show what cat1 needs: $(_mq_flat 500)"
  printf '%s\n' "$_md_out" | awk '/^  cat2 /{f=1; next} f && /needs:/{print; exit}' | grep -F 'declares nothing' >/dev/null || cf "(b) list does not say that cat2 declares nothing: $(_mq_flat 500)"
  [ ! -e "$SB_WORK/process/MODULES" ] || cf "(c) asking for the catalogue created a record"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A requires LINE THAT DOES NOT READ REFUSES THE MANIFEST, NAMING THE LINE.
#   One row per way the line can be wrong; each is refused by enable with nothing written. The control is the
#   same module with a line that reads.
# =============================================================================
case_a_requires_line_that_does_not_read_refuses_the_manifest() {
  cf_reset
  local L="a requires or requires-agent line with too few fields, a severity that is neither required nor optional: <text>, an empty check, an id that is not an id, a repeated id, a tab, or a wrong field count for an agent check refuses the manifest naming the line, writing nothing; the same module with a line that reads enables"
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mq_subject_ok || { finish "$L"; return; }
  _md_sandbox
  local s0="$SB_TMP/snap0" s1="$SB_TMP/snap1" tab; tab="$(printf '\t')"

  _row() {  # <label> <manifest line>… : refused as a bad manifest, nothing written
    local label="$1"; shift
    _mq_mod badreq "$@"
    _md_snap "$SB_WORK" > "$s0"
    _md_mod enable badreq
    [ "$_md_rc" -eq 1 ] || cf "($label) enable exited $_md_rc, want 1: $(_mq_flat)"
    printf '%s\n' "$_md_out" | grep -F 'module.manifest' | grep -F 'requires' >/dev/null || cf "($label) the refusal does not name the manifest line: $(_mq_flat)"
    printf '%s\n' "$_md_out" | grep -F 'unknown key' >/dev/null && cf "($label) the key is refused as unknown instead of the line being read: $(_mq_flat)"
    [ "$(_md_recs module-manifest-bad)" = 1 ] || cf "($label) no refusal=module-manifest-bad record"
    _md_snap "$SB_WORK" > "$s1"; cmp -s "$s0" "$s1" || cf "($label) the refused enable changed the tree"
  }
  _row "three fields" 'requires: a | true | get it'
  _row "an unknown severity" 'requires: a | true | get it | sometimes'
  _row "an optional with no text" 'requires: a | true | get it | optional:'
  _row "an empty check" 'requires: a |  | get it | required'
  _row "an empty how" 'requires: a | true |  | required'
  _row "an id that is not an id" 'requires: Bad_ID | true | get it | required'
  _row "a repeated id" 'requires: a | true | get it | required' 'requires-agent: a | call it | it works | sign in'
  _row "a tab in a field" "requires: a | tru${tab}e | get it | required"
  _row "an agent check with three fields" 'requires-agent: a | call it | it works'
  _row "an agent check with five fields" 'requires-agent: a | call it | it works | sign in | extra'
  _row "no value" 'requires:'
  unset -f _row

  _mq_mod badreq 'requires: a | true | get it | required' 'requires-agent: b | call it | it works | sign in'
  _md_mod enable badreq
  [ "$_md_rc" -eq 0 ] || cf "(control) the same module with lines that read exited $_md_rc: $(_mq_flat)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — kit-init --with REFUSES, BEFORE IT WRITES, A MODULE WHOSE REQUIRED COMMAND IS MISSING, AND RUNS NO setup.sh.
#   Day one has no resume path, so the preflight asks what enable asks: a requirement that fails is named with how
#   to get it, nothing is written, and the module's setup script is not run by the initializer either way.
# =============================================================================
case_kit_init_with_refuses_a_module_whose_required_command_is_missing() {
  cf_reset
  local L="kit-init.sh --with refuses in the preflight, writing nothing, a module whose required command is missing (naming the module, the requirement and how to get it), enables it once the command is there, and never runs the module's setup.sh"
  if ! has_kit_init; then skp "$L" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mq_subject_ok || { finish "$L"; return; }
  [ -f "$REAL_SCRIPTS/kit-init.sh" ] || { cf "(prereq) scripts/kit-init.sh is absent"; finish "$L"; return; }
  local s0 s1 out rc mark
  kit_init_sandbox
  s0="$SB_TMP/snap0"; s1="$SB_TMP/snap1"; mark="$SB_TMP/setup-ran"
  if [ -d "$REAL_REPO_ROOT/modules" ]; then cp -R "$REAL_REPO_ROOT/modules" "$SB_WORK/modules"; else mkdir -p "$SB_WORK/modules"; fi   # DELETE-IF-UNUSED
  _mq_mod dayone "requires: toolx | $_mq_missing | install toolx from its vendor | required"
  printf '#!/bin/sh\ntouch "$KIT_TEST_MARK"\n' > "$SB_WORK/modules/dayone/setup.sh"; chmod +x "$SB_WORK/modules/dayone/setup.sh"
  publish_sandbox

  _md_snap "$SB_WORK" > "$s0"; rm -rf "$SB_TMP/records"; rc=0
  out="$( cd "$SB_WORK" && env KIT_TEST_MARK="$mark" KIT_PROGRESS_DIR="$SB_TMP/records" ./scripts/kit-init.sh --prefix SBX --trunk "$SB_TRUNK" --with dayone 2>&1 </dev/null )" || rc=$?
  [ "$rc" -eq 1 ] || cf "(a) exit $rc, want 1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-260)"
  printf '%s\n' "$out" | grep -F 'NOTHING WAS WRITTEN' >/dev/null || cf "(a) the refusal does not say NOTHING WAS WRITTEN"
  printf '%s\n' "$out" | grep -F -- '--with dayone' >/dev/null || cf "(a) the refusal does not name the module: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -F 'toolx' >/dev/null || cf "(a) the refusal does not name the requirement: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -F 'install toolx from its vendor' >/dev/null || cf "(a) the refusal does not say how to get it"
  printf '%s\n' "$out" | grep '^Next:' >/dev/null || cf "(a) the refusal carries no Next: line"
  _md_snap "$SB_WORK" > "$s1"; cmp -s "$s0" "$s1" || cf "(a) the refused run changed the tree: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-200)"
  "$SB_WORK/scripts/kit-init.sh" --help 2>&1 | tr '\n' ' ' | grep -E -i -- '--with.*requirement' >/dev/null || cf "(a) kit-init --help does not say the --with preflight runs the module's requirement checks"
  grep -q 'Stamped by scripts/kit-init.sh' "$SB_WORK/scripts/config.sh" && cf "(a) the refused run stamped scripts/config.sh"

  _mq_mod dayone "requires: sh | command -v sh | a shell | required"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m "[PM] the module's requirement is met" >/dev/null 2>&1
  rc=0
  out="$( cd "$SB_WORK" && env KIT_TEST_MARK="$mark" ./scripts/kit-init.sh --prefix SBX --trunk "$SB_TRUNK" --with dayone 2>&1 </dev/null )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(b) with the requirement met, exit $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-260)"
  grep -E '^module dayone ' "$SB_WORK/process/MODULES" >/dev/null 2>&1 || cf "(b) the module was not enabled"
  [ -e "$mark" ] && cf "(b) kit-init ran the module's setup.sh"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — EVERY SHIPPED MODULE CARRIES ITS SETUP AND A CATALOGUE ROW THAT AGREES WITH ITS MANIFEST.
#   Derived from modules/*/module.manifest, so a module added later is judged without a case of its own. The
#   row's words are checked against the manifest, so the catalogue cannot say what the manifest does not.
# =============================================================================
case_every_shipped_module_has_setup_steps_and_a_catalogue_row_that_agrees_with_its_manifest() {
  cf_reset
  local L="each module under modules/ has a non-empty SETUP.md, and process/MODULES.md carries a catalogue row naming it with its manifest's purpose and each requirement it declares, by id and by severity"
  local m name dirs="" purpose ids labels row lab doc="$REAL_REPO_ROOT/process/MODULES.md"
  for m in "$REAL_REPO_ROOT"/modules/*/module.manifest; do
    [ -f "$m" ] || continue
    dirs="${dirs}$(basename "$(dirname "$m")")
"
  done
  if [ -z "$dirs" ]; then skp_lived "$L" "$(_md_gone_reason)"; return; fi
  [ -f "$doc" ] || { cf "(prereq) process/MODULES.md is absent from the tree under test"; finish "$L"; return; }
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    [ -s "$REAL_REPO_ROOT/modules/$name/SETUP.md" ] || cf "($name) modules/$name/SETUP.md is absent or empty"
    purpose="$(sed -n 's/^purpose:[[:space:]]*//p' "$REAL_REPO_ROOT/modules/$name/module.manifest" | head -1)"
    ids="$(sed -n -E 's/^requires(-agent)?:[[:space:]]*([a-z0-9][a-z0-9._-]*) \|.*/\2/p' "$REAL_REPO_ROOT/modules/$name/module.manifest")"
    labels="$(sed -n -E -e 's/^requires:[[:space:]]*([a-z0-9][a-z0-9._-]*) \|.*\| required[[:space:]]*$/\1 (required)/p' -e 's/^requires:[[:space:]]*([a-z0-9][a-z0-9._-]*) \|.*\| optional:.*$/\1 (optional)/p' -e 's/^requires-agent:[[:space:]]*([a-z0-9][a-z0-9._-]*) \|.*/\1 (agent check)/p' "$REAL_REPO_ROOT/modules/$name/module.manifest")"
    row="$(grep -F "| \`$name\` |" "$doc" | head -1)"
    if [ -z "$row" ]; then cf "($name) process/MODULES.md has no catalogue row for it"; continue; fi
    case "$row" in *"$purpose"*) ;; *) cf "($name) its catalogue row does not carry the manifest's purpose line" ;; esac
    while IFS= read -r id; do
      [ -n "$id" ] || continue
      case "$row" in *"$id"*) ;; *) cf "($name) its catalogue row does not name the requirement '$id'" ;; esac
    done <<MQ_IDS_EOF
$ids
MQ_IDS_EOF
    while IFS= read -r lab; do
      [ -n "$lab" ] || continue
      case "$row" in *"$lab"*) ;; *) cf "($name) its catalogue row does not say '$lab', which is how the manifest declares it" ;; esac
    done <<MQ_LABELS_EOF
$labels
MQ_LABELS_EOF
  done <<MQ_DIRS_EOF
$dirs
MQ_DIRS_EOF
  finish "$L"
}

# =============================================================================
# CASE — THE FILES AN AGENT READS FIRST NAME THE CATALOGUE.
#   The day-one entry file, the adapter template an adopter builds the entry file from, and the /start skill each
#   carry a pointer to the catalogue and to the command that lists it. The entry file is judged only while it is
#   still the day-one stub: a finished project replaced it with its own.
# =============================================================================
case_the_files_an_agent_reads_first_name_the_module_catalogue() {
  cf_reset
  local L="the day-one AGENTS.md (while it is the stub), the adapter template and the start skill each point at process/MODULES.md and module.sh list, so an agent asked for something a disabled module provides can say which module does it"
  local f any=0
  for f in AGENTS.md process/templates/AGENTS-adapter.template.md .claude/skills/start/SKILL.md; do
    [ -f "$REAL_REPO_ROOT/$f" ] || continue
    if [ "$f" = AGENTS.md ] && ! grep -qF 'BOOTSTRAP-SCAFFOLDING' "$REAL_REPO_ROOT/$f"; then continue; fi
    any=1
    grep -qF 'process/MODULES.md' "$REAL_REPO_ROOT/$f" || cf "($f) does not point at process/MODULES.md"
    grep -qF 'module.sh list' "$REAL_REPO_ROOT/$f" || cf "($f) does not name module.sh list"
  done
  if [ "$any" = 0 ]; then skp_lived "$L" "AGENTS.md is no longer the day-one stub, and the adapter template and .claude/skills/start/SKILL.md are absent from this tree"; return; fi
  finish "$L"
}

# =============================================================================
# CASE — ASKING RUNS NO CHECK, A CHECK GETS NO INPUT FROM THE CALLER, AND ASKING CHANGES NO BYTE.
#   A check that touches a marker file shows what ran. list and status of a disabled module must leave it absent;
#   enable must create it (the control that the marker can be seen). Enable is run with the caller's stdin carrying
#   data, and a check that waits for input must see none. list and status leave the tree as it was, snapshot to snapshot.
# =============================================================================
case_asking_runs_no_check_gives_a_check_no_input_and_changes_no_byte() {
  cf_reset
  local L="module.sh list and status of a disabled module run no module check (a marker file stays absent while enable creates it), a check is given no input from the caller's stdin, and list and status leave every byte of the tree as it was"
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mq_subject_ok || { finish "$L"; return; }
  _md_sandbox
  local mark="$SB_TMP/check-ran" s0="$SB_TMP/snap0" s1="$SB_TMP/snap1"
  export KIT_TEST_MARK="$mark"

  # (a) nothing that only asks runs a check; (c) and it changes no byte
  _mq_mod marked 'requires: m | touch "$KIT_TEST_MARK" | get m | required'
  _md_snap "$SB_WORK" > "$s0"
  _md_mod list; _md_mod status marked; _md_mod status
  _md_snap "$SB_WORK" > "$s1"
  [ -e "$mark" ] && cf "(a) list or status of a disabled module ran the module's check"
  cmp -s "$s0" "$s1" || cf "(c) list or status changed the tree: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-200)"
  _md_mod enable marked
  [ "$_md_rc" -eq 0 ] || cf "(a) the control: enable exited $_md_rc: $(_mq_flat)"
  [ -e "$mark" ] || cf "(a) the control: enable did not run the check, so the marker proves nothing"
  _md_snap "$SB_WORK" > "$s0"
  _md_mod status marked
  _md_snap "$SB_WORK" > "$s1"
  cmp -s "$s0" "$s1" || cf "(c) status of an enabled module changed the tree: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-200)"
  _md_mod disable marked

  # (b) the caller's stdin is not the check's: with data on it, a check that waits for input must see none
  # (a second requirement follows, so a check that is handed the kit's own list of them reads something)
  _mq_mod stdinless 'requires: nostdin | test -z "$(cat)" | close stdin | required' 'requires: after | true | nothing | required'
  rm -rf "$SB_TMP/records"
  ( cd "$SB_WORK" && printf 'caller data\n' | env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/records" ./scripts/module.sh enable stdinless ) >"$SB_TMP/stdin.out" 2>&1
  _md_rc=$?
  [ "$_md_rc" -eq 0 ] || cf "(b) a check that reads input saw the caller's stdin, exit $_md_rc: $(tr '\n' '|' < "$SB_TMP/stdin.out" | cut -c1-240)"

  unset KIT_TEST_MARK
  finish "$L"
  teardown
}

# =============================================================================
# CASE — status IS A REPORT: ONE MODULE IT CANNOT READ DOES NOT STOP THE REST, AND IT EXITS 0.
#   Two modules are enabled and the first one's manifest is then made unreadable. Status without a name reports the
#   second in full, says of the first that its requirements were not checked and why, and exits 0; named, the broken
#   one exits 0 too.
# =============================================================================
case_status_reports_every_enabled_module_and_exits_0_when_one_manifest_cannot_be_read() {
  cf_reset
  local L="module.sh status, with one enabled module's manifest unreadable, still reports the other module in full, says the broken one's requirements were not checked and why, and exits 0 with or without a name"
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mq_subject_ok || { finish "$L"; return; }
  _md_sandbox
  _mq_mod aa 'requires: sh | command -v sh | a shell | required'
  _mq_mod zz 'requires: sh | command -v sh | a shell | required'
  _md_mod enable aa; [ "$_md_rc" -eq 0 ] || cf "(prereq) enable aa exited $_md_rc: $(_mq_flat)"
  _md_mod enable zz; [ "$_md_rc" -eq 0 ] || cf "(prereq) enable zz exited $_md_rc: $(_mq_flat)"
  printf 'requires: broken | only two\n' >> "$SB_WORK/modules/aa/module.manifest"

  _md_mod status
  [ "$_md_rc" -eq 0 ] || cf "(a) status exited $_md_rc"
  printf '%s\n' "$_md_out" | grep -F 'zz 0.1.0' >/dev/null || cf "(a) status does not report zz: $(_mq_flat 400)"
  printf '%s\n' "$_md_out" | grep -F 'requirement sh: holds' >/dev/null || cf "(a) status does not report zz's requirement: $(_mq_flat 400)"
  printf '%s\n' "$_md_out" | grep -F 'requirements: not checked' | grep -F 'manifest' >/dev/null || cf "(a) status does not say aa's requirements were not checked, and why: $(_mq_flat 400)"
  _md_mod status aa
  [ "$_md_rc" -eq 0 ] || cf "(b) status aa exited $_md_rc"
  printf '%s\n' "$_md_out" | grep -F 'intact' >/dev/null || cf "(b) status aa does not report what aa placed: $(_mq_flat 400)"
  finish "$L"
  teardown
}
