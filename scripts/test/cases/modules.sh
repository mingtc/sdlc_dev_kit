# KIT-CLASS: MIXED — self-test harness, the module lifecycle (enable, disable, resume). See
# process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/modules.sh — sourced by scripts/test/run.sh, never run on its own.
# scripts/module.sh and scripts/lib/modules.sh, driven over the module the kit ships as its template
# (modules/example) and over small fabricated ones. Each case enables as an adopter would, looks at what
# was placed and recorded, takes it back, and proves the tree is as it was. The helpers are in
# lib/modules.sh. A project that deleted modules/example/ has its example cases N/A (the file named in
# the reason); the program being absent is never N/A, because it ships with the kit.
# =============================================================================

# =============================================================================
# CASE — ENABLE PLACES AND RECORDS A MODULE, DISABLE TAKES BACK EXACTLY THAT, AND EACH IS A NO-OP THE
# SECOND TIME.
#   Operand: a byte snapshot of the tree before enable. After disable it must be equal, and after a second
#   enable or a second disable nothing may move.
# =============================================================================
case_module_enable_and_disable_are_inverse_and_idempotent() {
  cf_reset
  local L="module.sh enable places the module's files, role layer, evidence-kind layer, fragments, checks, arm and block and records each by its sha256; disable returns the tree to its bytes from before enable; a second enable and a second disable are no-ops that say so"
  if ! _md_have_example; then skp_lived "$L" "$(_md_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _md_sandbox
  local s0="$SB_TMP/snap0" s1="$SB_TMP/snap1" s2="$SB_TMP/snap2" f n rows
  _md_snap "$SB_WORK" > "$s0"
  [ -s "$s0" ] || _fixture_die "${FUNCNAME[0]}: the snapshot of the sandbox is empty."
  [ -f "$SB_WORK/scripts/module.sh" ] || cf "(prereq) scripts/module.sh is absent from the tree under test"

  # (a) list before: the module is shipped and not enabled.
  _md_mod list
  [ "$_md_rc" -eq 0 ] || cf "(a) list exited $_md_rc: $_md_out"
  printf '%s\n' "$_md_out" | grep -E '^  example +[0-9]+\.[0-9]+\.[0-9]+ +disabled' >/dev/null || cf "(a) list does not show example as disabled: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-200)"

  # (b) enable.
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || cf "(b) enable exited $_md_rc: $_md_out"
  for f in .claude/roles/example.md .claude/skills/example-skill/SKILL.md scripts/check-board.d/50-example.sh \
           scripts/move-check.d/in_progress/50-example.sh scripts/qa-cell.d/example-note/50-example.sh \
           process/fragments.d/PRD/example.slot-story-fields process/fragments.d/ISSUE/example.body-end \
           process/roles.d/example process/evidence-kinds.d/example process/MODULES; do
    [ -f "$SB_WORK/$f" ] || cf "(b) enable did not place $f"
  done
  grep -F '<!-- KIT-MODULE:example:gates BEGIN -->' "$SB_WORK/PROJECT.md" >/dev/null || cf "(b) enable did not put the module's block in PROJECT.md"
  grep -E '^module example [0-9]+\.[0-9]+\.[0-9]+$' "$SB_WORK/process/MODULES" >/dev/null || cf "(b) process/MODULES has no 'module example <version>' line"
  grep -E '^pending ' "$SB_WORK/process/MODULES" >/dev/null && cf "(b) process/MODULES still records the enable as pending after it finished"
  for f in .claude/roles/example.md scripts/check-board.d/50-example.sh process/fragments.d/ISSUE/example.body-end; do
    grep -E "^file $(_old_sha "$SB_WORK/$f") $f\$" "$SB_WORK/process/MODULES" >/dev/null || cf "(b) process/MODULES does not record $f with the sha256 of the file as placed"
  done
  grep -E '^block [0-9a-f]{64} PROJECT.md gates$' "$SB_WORK/process/MODULES" >/dev/null || cf "(b) process/MODULES does not record the PROJECT.md block"
  [ -x "$SB_WORK/scripts/move-check.d/in_progress/50-example.sh" ] || cf "(b) the module's executable move check lost its mode when placed"
  printf '%s\n' "$_md_out" | grep -F 'read the TRUNK' >/dev/null || cf "(b) enable does not say that check-board reads the trunk, so a role it adds is unknown there until the commit is pushed"
  printf '%s\n' "$_md_out" | grep -F 'git add -A --' >/dev/null || cf "(b) enable does not print what to commit"
  grep -F 'KIT-MODULE' "$SB_WORK/.claude/roles/example.md" >/dev/null && cf "(b) a module file carries a marker line it should not"
  _md_snap "$SB_WORK" > "$s1"

  # (c) status: every recorded thing intact, derived from the record rather than from a number.
  _md_mod status example
  n="$(printf '%s\n' "$_md_out" | grep -c 'intact')"
  rows="$(grep -cE '^(file|block) ' "$SB_WORK/process/MODULES")"
  { [ "$rows" -ge 1 ] && [ "$n" = "$rows" ]; } || cf "(c) status shows $n intact line(s) for $rows recorded row(s): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$_md_out" | grep -E 'edited|missing' >/dev/null && cf "(c) status reports an edited or missing file straight after enable"

  # (d) a second enable is a no-op: the tree does not move, and it says so.
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || cf "(d) the second enable exited $_md_rc: $_md_out"
  printf '%s\n' "$_md_out" | grep -F 'already enabled' >/dev/null || cf "(d) the second enable does not say the module is already enabled: $_md_out"
  _md_snap "$SB_WORK" > "$s2"
  cmp -s "$s1" "$s2" || cf "(d) the second enable changed the tree"

  # (e) disable returns the tree to its bytes from before enable.
  _md_mod disable example
  [ "$_md_rc" -eq 0 ] || cf "(e) disable exited $_md_rc: $_md_out"
  _md_snap "$SB_WORK" > "$s2"
  cmp -s "$s0" "$s2" || cf "(e) the tree is not byte-equal to its state before enable: $(diff "$s0" "$s2" | tr '\n' '|' | cut -c1-300)"
  [ ! -e "$SB_WORK/process/MODULES" ] || cf "(e) process/MODULES remains with no module enabled"
  _md_mod list
  printf '%s\n' "$_md_out" | grep -E '^  example .* disabled' >/dev/null || cf "(e) list does not show example as disabled again"

  # (f) a second disable is a no-op.
  _md_mod disable example
  [ "$_md_rc" -eq 0 ] || cf "(f) the second disable exited $_md_rc: $_md_out"
  printf '%s\n' "$_md_out" | grep -F 'not enabled' >/dev/null || cf "(f) the second disable does not say the module is not enabled: $_md_out"
  _md_snap "$SB_WORK" > "$s1"
  cmp -s "$s0" "$s1" || cf "(f) the second disable changed the tree"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — DISABLE KEEPS, AND NAMES, WHAT THE PROJECT EDITED; A KEPT FILE BLOCKS A RE-ENABLE UNTIL IT IS DEALT WITH.
# =============================================================================
case_module_disable_reports_and_keeps_an_edited_file() {
  cf_reset
  local L="module.sh disable removes each file and block still byte-equal to what enable wrote, keeps and names an edited file and an edited block, records what it kept, and a re-enable then refuses before writing, naming the leftovers as its own"
  if ! _md_have_example; then skp_lived "$L" "$(_md_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _md_sandbox
  local s1="$SB_TMP/snap1" s2="$SB_TMP/snap2" f
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || { cf "enable exited $_md_rc: $_md_out"; finish "$L"; teardown; return; }
  printf 'a line the project added\n' >> "$SB_WORK/.claude/roles/example.md"
  perl -pi -e 's/^(\| The example module.s gate.*)$/$1\n| the project row | `x` | y |/' "$SB_WORK/PROJECT.md"
  grep -F 'the project row' "$SB_WORK/PROJECT.md" >/dev/null || _fixture_die "${FUNCNAME[0]}: the block edit was not planted."
  _md_mod status example
  printf '%s\n' "$_md_out" | grep -E '^  edited +\.claude/roles/example.md' >/dev/null || cf "(a) status does not show the edited role doc as edited: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$_md_out" | grep -E '^  edited +PROJECT.md' >/dev/null || cf "(a) status does not show the edited block as edited"

  _md_mod disable example
  [ "$_md_rc" -eq 0 ] || cf "(b) disable exited $_md_rc: $_md_out"
  printf '%s\n' "$_md_out" | grep -F 'KEPT' >/dev/null || cf "(b) disable does not say it kept anything: $_md_out"
  printf '%s\n' "$_md_out" | grep -F '.claude/roles/example.md' >/dev/null || cf "(b) disable does not name the kept role doc"
  printf '%s\n' "$_md_out" | grep -F 'PROJECT.md' >/dev/null || cf "(b) disable does not name the kept block"
  grep -F 'a line the project added' "$SB_WORK/.claude/roles/example.md" >/dev/null || cf "(b) the edited role doc was changed or deleted"
  grep -F 'the project row' "$SB_WORK/PROJECT.md" >/dev/null || cf "(b) the edited block was changed or deleted"
  for f in .claude/skills/example-skill/SKILL.md scripts/check-board.d/50-example.sh process/roles.d/example process/evidence-kinds.d/example scripts/move-check.d/in_progress/50-example.sh; do
    [ -e "$SB_WORK/$f" ] && cf "(b) $f, still byte-equal to what enable wrote, was not removed"
  done
  grep -E '^kept example ' "$SB_WORK/process/MODULES" >/dev/null || cf "(b) process/MODULES keeps no 'kept example' record of the two files disable left"
  grep -E '^module example ' "$SB_WORK/process/MODULES" >/dev/null && cf "(b) process/MODULES still records example as enabled"
  _md_mod status example
  printf '%s\n' "$_md_out" | grep -F 'not enabled' >/dev/null || cf "(b) the module is still recorded as enabled after disable"

  # (c) a re-enable refuses on the kept files, writing nothing.
  _md_snap "$SB_WORK" > "$s1"
  _md_mod enable example
  [ "$_md_rc" -ne 0 ] || cf "(c) enable took over an edited file the module no longer owns (exit 0)"
  printf '%s\n' "$_md_out" | grep -F 'Next:' >/dev/null || cf "(c) the refusal carries no Next: line: $_md_out"
  printf '%s\n' "$_md_out" | grep -F '.claude/roles/example.md' >/dev/null || cf "(c) the refusal does not name the file in the way"
  printf '%s\n' "$_md_out" | grep -F 'left by an earlier disable' >/dev/null || cf "(c) the refusal does not say the file is a leftover of this module's own disable: $_md_out"
  _md_snap "$SB_WORK" > "$s2"
  cmp -s "$s1" "$s2" || cf "(c) the refused enable changed the tree"
  [ "$(_md_recs module-enable-conflict)" -ge 1 ] || cf "(c) the refusal left no refusal=module-enable-conflict record"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — ENABLE REFUSES BEFORE IT WRITES, NAMES THE NEXT STEP, AND THE CLI SHAPE HOLDS.
#   One arm per refusal the contract names; each asserts the tree did not move and a record was left.
# =============================================================================
case_module_enable_refuses_before_writing_and_names_the_next_step() {
  cf_reset
  local L="module.sh enable refuses an unknown module, a path that is not the module's, a core file, a missing slot, a host with no final newline and a manifest that does not read — each with a Next: line, a record and nothing written — and refuses a bad option with status 2"
  if ! _md_have_example; then skp_lived "$L" "$(_md_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _md_sandbox
  local s0="$SB_TMP/snap0" s1="$SB_TMP/snap1"
  [ -f "$SB_WORK/scripts/module.sh" ] || cf "(prereq) scripts/module.sh is absent from the tree under test"
  _md_snap "$SB_WORK" > "$s0"
  # _md_refused <tag> <fragment the message must carry> <rule>
  _md_refused() {
    [ "$_md_rc" -eq 1 ] || cf "($1) exited $_md_rc, want 1: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-200)"
    printf '%s\n' "$_md_out" | grep -F 'Next:' >/dev/null || cf "($1) no Next: line"
    printf '%s\n' "$_md_out" | grep -F -- "$2" >/dev/null || cf "($1) the message does not carry '$2': $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
    [ "$(_md_recs "$3")" -ge 1 ] || cf "($1) no refusal=$3 record"
    _md_snap "$SB_WORK" > "$s1"
    cmp -s "$s0" "$s1" || cf "($1) the refusal changed the tree: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-200)"
  }

  _md_mod enable no-such-module;                                   _md_refused unknown "no-such-module" module-unknown
  _md_mod enable Bad_Name;                                         _md_refused badname "Bad_Name" module-name-bad

  # a path that exists and differs
  mkdir -p "$SB_WORK/.claude/roles"; printf 'mine\n' > "$SB_WORK/.claude/roles/example.md"
  _md_snap "$SB_WORK" > "$s0"
  _md_mod enable example;                                          _md_refused conflict ".claude/roles/example.md" module-enable-conflict
  rm -f "$SB_WORK/.claude/roles/example.md"; rmdir "$SB_WORK/.claude/roles" 2>/dev/null

  # a file the kit itself ships
  mkdir -p "$SB_WORK/process"
  printf '%s  %s  KIT\n' "$(printf '%064d' 0)" ".claude/roles/example.md" > "$SB_WORK/process/KIT-MANIFEST"
  _md_snap "$SB_WORK" > "$s0"
  _md_mod enable example;                                          _md_refused core "one of the kit's own files" module-enable-conflict
  rm -f "$SB_WORK/process/KIT-MANIFEST"

  # a missing slot
  cp "$SB_WORK/PROJECT.md" "$SB_TMP/PROJECT.keep"; grep -v 'KIT-MODULES:gates' "$SB_TMP/PROJECT.keep" > "$SB_WORK/PROJECT.md"
  _md_snap "$SB_WORK" > "$s0"
  _md_mod enable example;                                          _md_refused slot "KIT-MODULES:gates" module-enable-conflict
  # a host with no final newline
  printf '# PROJECT.md (sandbox)\n\n<!-- KIT-MODULES:gates the slot -->' > "$SB_WORK/PROJECT.md"
  _md_snap "$SB_WORK" > "$s0"
  _md_mod enable example;                                          _md_refused newline "does not end with a newline" module-enable-conflict
  cp "$SB_TMP/PROJECT.keep" "$SB_WORK/PROJECT.md"

  # a manifest that does not read: an unknown key; a source carrying an armed name; two entries on one path
  cp "$SB_WORK/modules/example/module.manifest" "$SB_TMP/manifest.keep"
  printf 'frobnicate: yes\n' >> "$SB_WORK/modules/example/module.manifest"
  _md_snap "$SB_WORK" > "$s0"
  _md_mod enable example;                                          _md_refused key "frobnicate" module-manifest-bad
  mkdir -p "$SB_WORK/modules/example/.claude"; printf 'x\n' > "$SB_WORK/modules/example/.claude/f.md"
  cp "$SB_TMP/manifest.keep" "$SB_WORK/modules/example/module.manifest"; printf 'file: .claude/f.md -> docs-example/f.md\n' >> "$SB_WORK/modules/example/module.manifest"
  _md_snap "$SB_WORK" > "$s0"
  _md_mod enable example;                                          _md_refused armed "a harness reads" module-manifest-bad
  rm -rf "$SB_WORK/modules/example/.claude"
  cp "$SB_TMP/manifest.keep" "$SB_WORK/modules/example/module.manifest"; printf 'file: gates.md -> process/roles.d/example\n' >> "$SB_WORK/modules/example/module.manifest"
  _md_snap "$SB_WORK" > "$s0"
  _md_mod enable example;                                          _md_refused dup "process/roles.d/example" module-manifest-bad
  cp "$SB_TMP/manifest.keep" "$SB_WORK/modules/example/module.manifest"

  # the CLI shape
  _md_mod --not-a-real-flag
  [ "$_md_rc" -eq 2 ] || cf "(shape) an unknown option exited $_md_rc, want 2"
  printf '%s\n' "$_md_out" | grep -F -- '--not-a-real-flag' >/dev/null || cf "(shape) the refusal does not name the option"
  _md_mod enable
  [ "$_md_rc" -eq 2 ] || cf "(shape) enable with no name exited $_md_rc, want 2"
  _md_mod frobnicate
  [ "$_md_rc" -eq 2 ] || cf "(shape) an unknown command exited $_md_rc, want 2"
  _md_mod list extra
  [ "$_md_rc" -eq 1 ] || cf "(shape) a surplus positional exited $_md_rc, want 1"
  _md_mod --help list extra
  [ "$_md_rc" -eq 0 ] || cf "(shape) --help after other arguments exited $_md_rc, want 0"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — ENABLE REFUSES, BEFORE WRITING, A MODULE WHOSE EXTENSION POINT HAS NO READER IN THIS PROJECT'S COPY OF THE KIT.
#   A project that took an older kit and then enabled a module would get a check that is placed and never
#   run. For each point a module can use, the file that reads it is damaged in the sandbox (its token cut
#   out), and enable must refuse naming that file, with a Next: line and nothing written; restored, the
#   same enable succeeds. The ablation is the whole case: it is the question "does the reader exist" asked
#   of one file at a time.
# =============================================================================
case_module_enable_refuses_a_point_whose_reader_is_missing_from_this_copy_of_the_kit() {
  cf_reset
  local L="module.sh enable refuses, naming the file to merge, with a Next: line and nothing written, when this project's copy of the kit lacks the reader of a point the module uses (the hook's role layer, the QA gate's kinds and cell checks, check-board's arm loop, the mover's checks, the mint's fragments, the template's slot line) — and enables once the reader is back"
  if ! _md_have_example; then skp_lived "$L" "$(_md_gone_reason)"; return; fi
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _md_sandbox
  local s0="$SB_TMP/snap0" s1="$SB_TMP/snap1" row file token keep="$SB_TMP/reader.keep"
  [ -f "$SB_WORK/scripts/module.sh" ] || cf "(prereq) scripts/module.sh is absent from the tree under test"
  # <file>|<token the reader carries> — the readers example's points need. Each file is cut at its token.
  local readers="scripts/githooks/commit-msg|kit_role_extend
scripts/check-board.sh|kit_role_extend
scripts/lib/role-set.sh|roles.d
scripts/lib/qa-gate.sh|kit_qa_evidence_kinds
scripts/lib/qa-gate.sh|qa-cell.d
scripts/lib/addon-check.sh|kit_move_checks
scripts/lib/addon-check.sh|kit_addon_check_run
scripts/lib/card-head.sh|kit_card_fragments
scripts/check-board.sh|check-board.d
scripts/move-issue.sh|kit_move_checks
scripts/subtask.sh|kit_move_checks
scripts/new-prd.sh|kit_card_fragments
scripts/new-issue.sh|kit_card_fragments
.claude/templates/PRD.template.md|KIT-MODULES:story-fields"
  # (control) with every reader in place the module enables, so every refusal below is the damage's.
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || { cf "(control) enable refused with every reader in place (exit $_md_rc): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"; finish "$L"; teardown; return; }
  _md_mod disable example
  _md_snap "$SB_WORK" > "$s0"
  while IFS='|' read -r file token; do
    [ -n "$file" ] || continue
    [ -f "$SB_WORK/$file" ] || _fixture_die "${FUNCNAME[0]}: $file is not in the sandbox, so its reader cannot be damaged."
    grep -qF -- "$token" "$SB_WORK/$file" || _fixture_die "${FUNCNAME[0]}: $file does not carry '$token' to begin with."
    cp "$SB_WORK/$file" "$keep"
    # Cut every occurrence of the token, leaving the file otherwise as it was.
    TOKEN="$token" perl -pi -e 'BEGIN { $t = $ENV{TOKEN} } s/\Q$t\E/CUT-BY-THE-CASE/g' "$SB_WORK/$file"
    grep -qF -- "$token" "$SB_WORK/$file" && _fixture_die "${FUNCNAME[0]}: the token '$token' survived the cut in $file."
    _md_snap "$SB_WORK" > "$s0"
    _md_mod enable example
    row="$file ($token)"
    [ "$_md_rc" -eq 1 ] || cf "($row) enable was not refused with status 1 (exit $_md_rc): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-200)"
    printf '%s\n' "$_md_out" | grep -F "$file" >/dev/null || cf "($row) the refusal does not name $file"
    printf '%s\n' "$_md_out" | grep '^Next:' >/dev/null || cf "($row) the refusal carries no Next: line"
    printf '%s\n' "$_md_out" | grep -F 'NOTHING WAS CHANGED' >/dev/null || cf "($row) the refusal does not say nothing was changed"
    [ "$(_md_recs module-reader-missing)" -ge 1 ] || cf "($row) no refusal=module-reader-missing record"
    _md_snap "$SB_WORK" > "$s1"
    cmp -s "$s0" "$s1" || cf "($row) the refused enable changed the tree: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-200)"
    cp "$keep" "$SB_WORK/$file"
    rm -rf "$SB_TMP/records"
  done <<READERS_EOF
$readers
READERS_EOF

  # A reader that is absent altogether is the same refusal.
  cp "$SB_WORK/scripts/lib/addon-check.sh" "$keep"; rm -f "$SB_WORK/scripts/lib/addon-check.sh"
  _md_mod enable example
  { [ "$_md_rc" -eq 1 ] && printf '%s\n' "$_md_out" | grep -F 'scripts/lib/addon-check.sh is absent' >/dev/null; } || cf "(absent) a missing reader file was not refused by name (exit $_md_rc): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-200)"
  cp "$keep" "$SB_WORK/scripts/lib/addon-check.sh"

  # A move check for done/ needs the archive sweep to run it: archive.sh is a reader like the others.
  mkdir -p "$SB_WORK/modules/dn"
  printf 'name: dn\nversion: 0.1.0\npurpose: A fabricated module with a done/ move check.\nmove-check: c.sh -> done/50-x.sh\n' > "$SB_WORK/modules/dn/module.manifest"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$SB_WORK/modules/dn/c.sh"
  cp "$SB_WORK/scripts/archive.sh" "$keep"
  TOKEN=kit_move_checks perl -pi -e 'BEGIN { $t = $ENV{TOKEN} } s/\Q$t\E/CUT-BY-THE-CASE/g' "$SB_WORK/scripts/archive.sh"
  _md_mod enable dn
  { [ "$_md_rc" -eq 1 ] && printf '%s\n' "$_md_out" | grep -F 'scripts/archive.sh' >/dev/null && printf '%s\n' "$_md_out" | grep '^Next:' >/dev/null; } \
    || cf "(done) a done/ move check was not refused when archive.sh does not run it (exit $_md_rc): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  cp "$keep" "$SB_WORK/scripts/archive.sh"
  _md_mod enable dn
  [ "$_md_rc" -eq 0 ] || cf "(done) the done/ move check was refused with archive.sh's reader back (exit $_md_rc): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-200)"
  _md_mod disable dn

  # A module that uses none of the points needs none of the readers: a plain file module enables over a
  # project whose copy of the kit has none of them.
  mkdir -p "$SB_WORK/modules/plain"
  printf 'name: plain\nversion: 0.1.0\npurpose: A fabricated module with one file.\nfile: f.txt -> plain/f.txt\n' > "$SB_WORK/modules/plain/module.manifest"
  printf 'f\n' > "$SB_WORK/modules/plain/f.txt"
  TOKEN=kit_role_extend perl -pi -e 'BEGIN { $t = $ENV{TOKEN} } s/\Q$t\E/CUT/g' "$SB_WORK/scripts/githooks/commit-msg"
  _md_mod enable plain
  [ "$_md_rc" -eq 0 ] || cf "(plain) a module using no extension point was refused for a reader it does not need (exit $_md_rc): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-200)"
  _md_mod disable plain

  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE KILL STAND-INS KILL THE PROCESS UNDER TEST, NOT EVERY ANCESTOR WHOSE COMMAND TEXT NAMES A SCRIPT.
#   An ancestor whose command line only names a script is not the program under test, and a stand-in that matched
#   on command text killed it too. The stand-in kills the process the case MARKED (the pid it recorded) and the
#   processes between it and the stand-in, and nothing above. The decoy here is a script whose file name carries
#   the text, run as the marked program's parent.
# =============================================================================
case_the_kill_stand_ins_kill_only_the_marked_process_and_its_branch() {
  cf_reset
  local L="a kill stand-in SIGKILLs the process the case marked and the processes between it and the stand-in, not an ancestor above it whose command line only names kit-upgrade.sh, and does not kill when the marked process is not an ancestor"
  command -v ps >/dev/null 2>&1 || { skp "$L" "no ps: the stand-in cannot walk the process tree"; return; }
  make_sandbox
  local kd="$SB_TMP/kd" st
  mkdir -p "$kd"; : > "$kd/a.txt"
  _md_make_kill_shim
  # the program under test: one move the stand-in aims at, then a mark that must never be written
  cat > "$kd/under-test.sh" <<'UT_EOF'
#!/bin/bash
mv "$KD/a.txt" "$KD/target"
echo ran-on > "$KD/after"
UT_EOF
  # the decoy: its file name carries the text a text-matching stand-in looks for; it runs the marked program
  cat > "$kd/decoy-kit-upgrade.sh" <<'DC_EOF'
#!/bin/bash
rc=0
env KD="$KD" KILL_PID_FILE="$KD/pid" KILL_ON=target PATH="$KD/shim:$PATH" \
  bash -c 'echo $$ > "$KILL_PID_FILE"; exec "$@"' _ bash "$KD/under-test.sh" || rc=$?
echo "$rc" > "$KD/decoy-status"
DC_EOF
  ln -s "$SB_TMP/shim" "$kd/shim"
  (cd "$kd" && KD="$kd" bash "$kd/decoy-kit-upgrade.sh" >/dev/null 2>&1) || true
  [ -f "$kd/decoy-status" ] || cf "(a) the ancestor whose command line names kit-upgrade.sh was killed with the program under test"
  [ "$(cat "$kd/decoy-status" 2>/dev/null)" = 137 ] || cf "(a) the marked program did not die by SIGKILL (status '$(cat "$kd/decoy-status" 2>/dev/null)', want 137)"
  [ -e "$kd/after" ] && cf "(a) the marked program kept running after the move the stand-in aims at"
  [ -e "$kd/target" ] && cf "(a) the move the stand-in aims at was made, so nothing was killed before it"

  # (b) a mark that is not an ancestor: nothing is killed, and the move goes through.
  rm -f "$kd/after" "$kd/target" "$kd/decoy-status"; : > "$kd/a.txt"
  echo 999999 > "$kd/pid2"
  st=0
  env KD="$kd" KILL_PID_FILE="$kd/pid2" KILL_ON=target PATH="$kd/shim:$PATH" bash "$kd/under-test.sh" >/dev/null 2>&1 || st=$?
  [ "$st" -eq 0 ] || cf "(b) the program was killed or failed (status $st) though the marked pid is not one of its ancestors"
  [ -e "$kd/after" ] || cf "(b) the program did not run to its end though the marked pid is not one of its ancestors"
  [ -e "$kd/target" ] || cf "(b) the move was not made though the marked pid is not one of its ancestors"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — A KILLED ENABLE IS FINISHED BY RUNNING IT AGAIN, OR TAKEN BACK BY DISABLE, AND LEAVES NOTHING TO DELETE BY HAND.
#   The kill is real: a stand-in for mv, first on PATH, SIGKILLs the module.sh process tree at the move that
#   would place a chosen file, so nothing runs after it (no trap, no cleanup). Enable writes its record
#   ahead of the files, as `pending`, one row before each path; the rerun trusts those rows, and only
#   those, to tell its own files from the project's.
# =============================================================================
case_a_killed_enable_is_finished_by_enable_or_taken_back_by_disable() {
  cf_reset
  local L="an enable killed part-way (SIGKILL at the move of one file) leaves a pending record and a part-placed tree; running enable again finishes it to the tree a clean enable leaves; disable takes it back to the bytes from before; a file the project changed meanwhile is refused by name, not adopted, and kept by disable; no stray temporary file remains"
  if ! _md_have_example; then skp_lived "$L" "$(_md_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  command -v ps >/dev/null 2>&1 || { skp "$L" "no ps: the stand-in cannot find the process tree to kill"; return; }
  _md_sandbox
  local s0="$SB_TMP/snap0" sr="$SB_TMP/snap-resumed" sc="$SB_TMP/snap-clean" s1="$SB_TMP/snap1" shim="$SB_TMP/shim" victim="scripts/check-board.d/50-example.sh"
  [ -f "$SB_WORK/scripts/module.sh" ] || cf "(prereq) scripts/module.sh is absent from the tree under test"
  _md_make_kill_shim
  _md_snap "$SB_WORK" > "$s0"

  # (a) the kill: the process died by a signal (not a refusal), and left a pending record.
  _md_kill_enable "$victim"
  [ "$_md_rc" -ge 128 ] || cf "(a) the stand-in did not kill the enable (exit $_md_rc): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-200)"
  grep -E '^pending example ' "$SB_WORK/process/MODULES" >/dev/null || { cf "(a) a killed enable left no 'pending example' record: $(cat "$SB_WORK/process/MODULES" 2>/dev/null | tr '\n' '|' | cut -c1-200)"; finish "$L"; teardown; return; }
  grep -E '^module example ' "$SB_WORK/process/MODULES" >/dev/null && cf "(a) the killed enable is already recorded as enabled"
  [ -f "$SB_WORK/.claude/roles/example.md" ] || cf "(a) the premise failed: nothing was placed before the kill, so there is nothing to resume"
  [ -e "$SB_WORK/$victim" ] && cf "(a) the premise failed: the file the kill was aimed at was placed"
  grep -F "$victim" "$SB_WORK/process/MODULES" >/dev/null || cf "(a) the pending record does not name the file the run had reached ($victim)"
  grep -F 'scripts/check-board.d/' "$SB_WORK/process/MODULES" >/dev/null && :
  grep -F 'process/roles.d/example' "$SB_WORK/process/MODULES" >/dev/null && cf "(a) the pending record names a path the run never reached"
  _md_mod status example
  printf '%s\n' "$_md_out" | grep -F 'did not finish' >/dev/null || cf "(a) status does not say the enable did not finish: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-200)"
  _md_mod list
  printf '%s\n' "$_md_out" | grep -E '^  example .*UNFINISHED' >/dev/null || cf "(a) list does not mark the module as unfinished: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-200)"

  # (b) enable again finishes it, to the tree a clean enable leaves.
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || cf "(b) the rerun of a killed enable exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$_md_out" | grep -F 'did not finish' >/dev/null || cf "(b) the rerun does not say it is finishing an earlier enable"
  grep -E '^module example ' "$SB_WORK/process/MODULES" >/dev/null || cf "(b) the finished enable is not recorded as enabled"
  grep -E '^pending ' "$SB_WORK/process/MODULES" >/dev/null && cf "(b) the pending record survived the finish"
  [ -z "$(find "$SB_WORK" -name '*.kit-mod-new' -not -path "$SB_WORK/.git/*" 2>/dev/null)" ] || cf "(b) a temporary file of the killed run remains: $(find "$SB_WORK" -name '*.kit-mod-new' -not -path "$SB_WORK/.git/*" | tr '\n' ' ')"
  _md_snap "$SB_WORK" > "$sr"
  _md_mod disable example
  _md_snap "$SB_WORK" > "$s1"
  cmp -s "$s0" "$s1" || cf "(b) disable after a finished resume left the tree different from before: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-240)"
  _md_mod enable example
  _md_snap "$SB_WORK" > "$sc"
  cmp -s "$sr" "$sc" || cf "(b) the tree a resumed enable left is not the tree a clean enable leaves: $(diff "$sr" "$sc" | tr '\n' '|' | cut -c1-240)"
  _md_mod disable example

  # (c) disable takes back an enable that never finished.
  _md_kill_enable "$victim"
  [ "$_md_rc" -ge 128 ] || { cf "(kill) the second enable was not killed by the stand-in (exit $_md_rc)"; finish "$L"; teardown; return; }
  _md_mod disable example
  [ "$_md_rc" -eq 0 ] || cf "(c) disable of an unfinished enable exited $_md_rc: $_md_out"
  _md_snap "$SB_WORK" > "$s1"
  cmp -s "$s0" "$s1" || cf "(c) disable of an unfinished enable did not return the tree to its bytes: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-240)"
  [ ! -e "$SB_WORK/process/MODULES" ] || cf "(c) process/MODULES remains after the unfinished enable was taken back"

  # (d) a file the project changed meanwhile is not adopted by the rerun, and is kept by disable.
  _md_kill_enable "$victim"
  [ "$_md_rc" -ge 128 ] || { cf "(kill) the third enable was not killed by the stand-in (exit $_md_rc)"; finish "$L"; teardown; return; }
  printf 'the project edited this\n' >> "$SB_WORK/.claude/roles/example.md"
  _md_snap "$SB_WORK" > "$s0"
  _md_mod enable example
  { [ "$_md_rc" -eq 1 ] && printf '%s\n' "$_md_out" | grep -F '.claude/roles/example.md' >/dev/null && printf '%s\n' "$_md_out" | grep '^Next:' >/dev/null; } \
    || cf "(d) the rerun adopted or ignored a placed file the project had changed (exit $_md_rc): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  _md_snap "$SB_WORK" > "$s1"
  cmp -s "$s0" "$s1" || cf "(d) the refused rerun changed the tree"
  _md_mod disable example
  grep -F 'the project edited this' "$SB_WORK/.claude/roles/example.md" >/dev/null || cf "(d) disable deleted the file the project had edited"
  printf '%s\n' "$_md_out" | grep -F 'KEPT' >/dev/null || cf "(d) disable did not report the kept file"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — A WRITE THAT FAILS PART-WAY TAKES BACK WHAT THE RUN HAD PLACED AND LEAVES NO RECORD.
#   The directory a later file belongs in is made unwritable, so the earlier files are placed and the
#   later one cannot be. The refusal says nothing was changed, and that has to be true: the tree is the
#   snapshot from before, with no pending record to resume from.
# =============================================================================
case_module_enable_takes_back_what_it_placed_when_a_write_fails() {
  cf_reset
  local L="when a file cannot be written part-way through an enable, the run takes back every file and block it had placed, drops its pending record and refuses with module-write-failed and a Next: line, so the tree is the one from before and a second enable starts clean"
  if ! _md_have_example; then skp_lived "$L" "$(_md_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  [ "$(id -u)" != 0 ] || { skp "$L" "running as root, which writes into a directory chmod made unwritable"; return; }
  _md_sandbox
  local s0="$SB_TMP/snap0" s1="$SB_TMP/snap1" dir="$SB_WORK/scripts/check-board.d"
  [ -f "$SB_WORK/scripts/module.sh" ] || cf "(prereq) scripts/module.sh is absent from the tree under test"
  [ -d "$dir" ] || _fixture_die "${FUNCNAME[0]}: scripts/check-board.d is not in the sandbox, so there is no directory to make unwritable."
  _md_snap "$SB_WORK" > "$s0"
  chmod 555 "$dir"
  _md_mod enable example
  chmod 755 "$dir"
  [ "$_md_rc" -eq 1 ] || cf "(a) the enable was not refused (exit $_md_rc): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$_md_out" | grep -F 'scripts/check-board.d/50-example.sh' >/dev/null || cf "(a) the refusal does not name the file it could not write"
  printf '%s\n' "$_md_out" | grep '^Next:' >/dev/null || cf "(a) the refusal carries no Next: line"
  [ "$(_md_recs module-write-failed)" -ge 1 ] || cf "(a) no refusal=module-write-failed record"
  [ -f "$SB_WORK/.claude/roles/example.md" ] && cf "(b) a file the run had placed before the failure was not taken back"
  [ -e "$SB_WORK/process/MODULES" ] && cf "(b) a record remains after the failed enable: $(tr '\n' '|' < "$SB_WORK/process/MODULES" | cut -c1-200)"
  _md_snap "$SB_WORK" > "$s1"
  cmp -s "$s0" "$s1" || cf "(b) the tree is not the one from before the failed enable: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-240)"
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || cf "(c) the enable after the failure's cause was removed exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  _md_mod disable example

  finish "$L"
  teardown
}

# =============================================================================
# CASE — DISABLE ASKS BEFORE IT REMOVES, AND KEEPS A ROLE LAYER THAT HISTORY USES.
#   (1) A shared file disable cannot rewrite (no final newline, as an editor may save it) is found before the
#   first removal: the refusal says nothing was changed and that is so, the record still says enabled and
#   every placed thing is intact. (2) A role the trunk's history carries is not withdrawn: check-board's [e]
#   judges each trunk commit against today's role set, so disable keeps the layer, says so and names how to
#   retire the role; the control with no such commit removes it. (3) The kept layer is the module's own: put
#   back as it was, a re-enable takes it up; still edited, the refusal says what to do.
# =============================================================================
case_module_disable_checks_before_it_removes_and_keeps_a_role_layer_that_history_uses() {
  cf_reset
  local L="disable of a module whose block sits in a file with no final newline refuses before removing anything (rule module-disable-blocked, a Next: line, the record and every placed thing untouched) and succeeds once the newline is back; a role layer whose role a trunk commit carries is kept and named with the way to retire it, check-board's [e] stays clean, and a layer no commit uses is removed; a kept file put back as it was is taken up by the next enable, and one still changed is refused with an act that works"
  if ! _md_have_example; then skp_lived "$L" "$(_md_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _md_sandbox
  [ -f "$SB_WORK/scripts/module.sh" ] || cf "(prereq) scripts/module.sh is absent from the tree under test"
  local s0="$SB_TMP/snap0" s1="$SB_TMP/snap1" s2="$SB_TMP/snap2" out rec0 id="$_MD_ID" role dis
  role="$(sed -n 's/^role:[[:space:]]*\([A-Za-z0-9_-]*\).*/\1/p' "$SB_WORK/modules/example/module.manifest" | sed -n '1p')"
  [ -n "$role" ] || _fixture_die "${FUNCNAME[0]}: the example module's manifest declares no role."
  _md_snap "$SB_WORK" > "$s0"

  # (1) a block host with no final newline.
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || { cf "(1) enable exited $_md_rc: $_md_out"; finish "$L"; teardown; return; }
  printf '%s' "$(cat "$SB_WORK/PROJECT.md")" > "$SB_WORK/PROJECT.md"
  _md_snap "$SB_WORK" > "$s1"; rec0="$(cat "$SB_WORK/process/MODULES")"
  _md_mod disable example
  { [ "$_md_rc" -eq 1 ] && printf '%s\n' "$_md_out" | grep -F 'PROJECT.md does not end with a newline' >/dev/null && printf '%s\n' "$_md_out" | grep '^Next:' >/dev/null && printf '%s\n' "$_md_out" | grep -F 'NOTHING WAS CHANGED' >/dev/null; } \
    || cf "(1) a disable over a host with no final newline was not refused naming it, with a Next: line (exit $_md_rc): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  [ "$(_md_recs module-disable-blocked)" -ge 1 ] || cf "(1) no refusal=module-disable-blocked record"
  _md_snap "$SB_WORK" > "$s2"
  cmp -s "$s1" "$s2" || cf "(1) the refused disable changed the tree: $(diff "$s1" "$s2" | tr '\n' '|' | cut -c1-240)"
  [ "$rec0" = "$(cat "$SB_WORK/process/MODULES")" ] || cf "(1) the refused disable changed the record"
  _md_mod status example
  printf '%s\n' "$_md_out" | grep -E 'missing' >/dev/null && cf "(1) after the refused disable a placed thing is missing: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-200)"
  printf '\n' >> "$SB_WORK/PROJECT.md"
  _md_mod disable example
  [ "$_md_rc" -eq 0 ] || cf "(1) disable after the newline was restored exited $_md_rc: $_md_out"
  _md_snap "$SB_WORK" > "$s2"
  cmp -s "$s0" "$s2" || cf "(1) the tree is not the one from before enable: $(diff "$s0" "$s2" | tr '\n' '|' | cut -c1-240)"

  # (2) a role the trunk's history carries.
  _md_mod enable example
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[PM] $id: enable the example module" >/dev/null 2>&1
  sbcommit -q --allow-empty -m "[$role] $id: a commit by the seat" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  out="$( cb_run )"
  printf '%s\n' "$out" | grep -F 'lacks a [Role] prefix' | grep -F '[Example]' >/dev/null && cf "(2) (control) check-board flags the [Example] commit while the module is enabled"
  _md_mod disable example
  [ "$_md_rc" -eq 0 ] || cf "(2) disable exited $_md_rc: $_md_out"
  [ -f "$SB_WORK/process/roles.d/example" ] || cf "(2) the role layer was removed though a trunk commit carries [Example]"
  dis="$_md_out"
  _md_mod status example
  printf '%s\n' "$_md_out" | grep -F 'because you had edited' >/dev/null && cf "(2) status says a role layer kept for history was kept because it was edited: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$_md_out" | grep -F 'history' >/dev/null || cf "(2) status does not give history as a reason a role layer is kept: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$dis" | grep -F '[Example]' >/dev/null && printf '%s\n' "$dis" | grep -F 'process/ROLES' >/dev/null || cf "(2) disable does not name the role and how to retire it: $(printf '%s' "$dis" | tr '\n' '|' | cut -c1-300)"
  [ -e "$SB_WORK/.claude/roles/example.md" ] && cf "(2) the module's role doc was kept though nothing needs it"
  grep -E '^kept example ' "$SB_WORK/process/MODULES" >/dev/null || cf "(2) the kept layer is not recorded under 'kept example'"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[PM] $id: disable the example module" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  out="$( cb_run )"
  printf '%s\n' "$out" | grep -F 'lacks a [Role] prefix' | grep -F '[Example]' >/dev/null && cf "(2) check-board flags the [Example] commit after the disable: $(printf '%s' "$out" | grep -F '[Example]' | head -2 | tr '\n' '|')"
  # (2b) the layer is the project's once kept: deleting it on purpose is what the board then reports.
  rm -f "$SB_WORK/process/roles.d/example"; git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[PM] $id: retire the role" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  out="$( cb_run )"
  printf '%s\n' "$out" | grep -F 'lacks a [Role] prefix' | grep -F '[Example]' >/dev/null || cf "(2b) (control) check-board does not flag [Example] once the layer is deleted, so the premise of the keep is not shown"

  # (3) a kept file, put back as it was, is taken up; still changed, the refusal's act works.
  teardown
  _md_sandbox
  _md_mod enable example
  cp "$SB_WORK/.claude/roles/example.md" "$SB_TMP/role.orig"
  printf 'a line the project added\n' >> "$SB_WORK/.claude/roles/example.md"
  _md_mod disable example
  _md_mod enable example
  { [ "$_md_rc" -eq 1 ] && printf '%s\n' "$_md_out" | grep -F 'restore the module' >/dev/null; } || cf "(3) a re-enable over a still-edited kept file was not refused with the restore act (exit $_md_rc): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  cp "$SB_TMP/role.orig" "$SB_WORK/.claude/roles/example.md"
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || cf "(3) the Next: act of the refusal (restore the module's copy) did not make enable succeed (exit $_md_rc): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  _md_mod status example
  printf '%s\n' "$_md_out" | grep -E 'edited|missing' >/dev/null && cf "(3) status after the re-enable reports an edited or missing thing"
  grep -E '^kept ' "$SB_WORK/process/MODULES" >/dev/null && cf "(3) the kept record survived the re-enable"
  _md_mod disable example
  [ ! -e "$SB_WORK/.claude/roles/example.md" ] || cf "(3) the taken-up file was not removed by the next disable"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — A KILLED ENABLE LEAVES NO STRAY FILE AND NO EMPTY .gitignore, AND A RESUME RECORDS THE BYTES IT WRITES.
#   Kill at the move of a block host (marker-block's side file is the stray) and at the move of a .gitignore
#   the enable creates (the file must not exist half-made); kill, change the module's source, and resume (the
#   record's sha is the new bytes, so nothing reads as edited).
# =============================================================================
case_a_kill_leaves_no_stray_file_and_a_resume_records_the_bytes_it_writes() {
  cf_reset
  local L="a hard kill at a block host's move leaves no marker-block side file after the resume or the disable, a kill while a missing .gitignore is created leaves no empty .gitignore, and a resume after the module's source changed places the new bytes and records their sha, so status reports nothing edited and disable keeps nothing, and a record side file left with nothing enabled is named by status, which leaves it, and removed by enable and by disable, also when the name is refused, and disable also removes the directories of a placed file the project had removed"
  if ! _md_have_example; then skp_lived "$L" "$(_md_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  command -v ps >/dev/null 2>&1 || { skp "$L" "no ps: the stand-in cannot find the process tree to kill"; return; }
  _md_sandbox
  [ -f "$SB_WORK/scripts/module.sh" ] || cf "(prereq) scripts/module.sh is absent from the tree under test"
  _md_make_kill_shim
  local s0="$SB_TMP/snap0" s1="$SB_TMP/snap1" st

  # (a) kill while PROJECT.md's block is moved in.
  _md_snap "$SB_WORK" > "$s0"
  _md_kill_enable PROJECT.md
  [ "$_md_rc" -ge 128 ] || { cf "(a) the stand-in did not kill the enable (exit $_md_rc)"; finish "$L"; teardown; return; }
  [ -n "$(_md_strays "$SB_WORK")" ] || cf "(a) (premise) the kill left no side file, so the sweep below is untested"
  # The killed run's scratch outside the project is the harness's to remove: it is in the sandbox (_md_kill_tmp).
  [ -n "$(find "$SB_TMP/tmp" -mindepth 1 -maxdepth 1 -name 'kit-module.*' 2>/dev/null)" ] \
    || cf "(a) the killed enable's scratch (kit-module.*) is not in the sandbox's temp directory: the run was not given it, so the scratch is left in the machine's temp directory, which nothing empties (or enable no longer makes one)"
  [ -n "$(find "$SB_TMP/tmp" -mindepth 1 -maxdepth 1 -name 'kit-mb.*' 2>/dev/null)" ] \
    || cf "(a) the killed enable's marker-block scratch (kit-mb.*) is not in the sandbox's temp directory: a bare mktemp ignores TMPDIR on macOS, so the scratch is left in the machine's temp directory (or marker-block no longer makes one)"
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || cf "(a) the resume exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  st="$(_md_strays "$SB_WORK")"; [ -z "$st" ] || cf "(a) a stray file remains after the resume: $(printf '%s' "$st" | tr '\n' ' ')"
  _md_mod disable example
  _md_snap "$SB_WORK" > "$s1"; cmp -s "$s0" "$s1" || cf "(a) the tree after the resume and the disable is not the one from before: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-240)"
  # and the disable of a run killed there takes the side file too
  _md_kill_enable PROJECT.md
  _md_mod disable example
  st="$(_md_strays "$SB_WORK")"; [ -z "$st" ] || cf "(a) a stray file remains after the disable of a killed enable: $(printf '%s' "$st" | tr '\n' ' ')"
  _md_snap "$SB_WORK" > "$s1"; cmp -s "$s0" "$s1" || cf "(a) the disable of a killed enable did not restore the tree: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-240)"

  # (b) kill while the .gitignore (absent before) is created.
  [ ! -e "$SB_WORK/.gitignore" ] || _fixture_die "${FUNCNAME[0]}: the sandbox already has a .gitignore, so the creation cannot be killed."
  _md_kill_enable .gitignore
  [ "$_md_rc" -ge 128 ] || { cf "(b) the stand-in did not kill the enable (exit $_md_rc)"; finish "$L"; teardown; return; }
  { [ ! -e "$SB_WORK/.gitignore" ] || [ -s "$SB_WORK/.gitignore" ]; } || cf "(b) the kill left an EMPTY .gitignore that disable would not remove"
  _md_mod disable example
  [ -e "$SB_WORK/.gitignore" ] && cf "(b) disable left a .gitignore the module's enable created"
  st="$(_md_strays "$SB_WORK")"; [ -z "$st" ] || cf "(b) a stray file remains: $(printf '%s' "$st" | tr '\n' ' ')"
  _md_snap "$SB_WORK" > "$s1"; cmp -s "$s0" "$s1" || cf "(b) the tree is not the one from before: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-240)"

  # (c) kill, change the module's sources (one placed already, one not), resume.
  _md_kill_enable scripts/check-board.d/50-example.sh
  [ "$_md_rc" -ge 128 ] || { cf "(c) the stand-in did not kill the enable (exit $_md_rc)"; finish "$L"; teardown; return; }
  printf '# changed upstream\n' >> "$SB_WORK/modules/example/check-board.d/50-example.sh"
  printf '\nA line the module gained.\n' >> "$SB_WORK/modules/example/_claude/roles/example.md"
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || cf "(c) the resume after a source change exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  grep -F 'changed upstream' "$SB_WORK/scripts/check-board.d/50-example.sh" >/dev/null || cf "(c) the arm was not placed from the changed source"
  grep -F 'A line the module gained.' "$SB_WORK/.claude/roles/example.md" >/dev/null || cf "(c) the role doc placed before the kill was not refreshed from the changed source"
  _md_mod status example
  printf '%s\n' "$_md_out" | grep -E 'edited|missing' >/dev/null && cf "(c) status reports a thing edited or missing that nobody touched: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  _md_mod disable example
  printf '%s\n' "$_md_out" | grep -F 'KEPT' >/dev/null && cf "(c) disable kept a file the module wrote: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  _md_snap "$SB_WORK" > "$s1"
  diff "$s0" "$s1" | grep -v 'modules/example' | grep '^[<>]' >/dev/null && cf "(c) disable did not return the tree: $(diff "$s0" "$s1" | grep -v 'modules/example' | tr '\n' '|' | cut -c1-240)"

  # (d) a side file of the record left by a kill, with no module enabled: status leaves it and names it, disable
  # takes it; planted here rather than killed for, so this adds no kill.
  printf 'half a record\n' > "$SB_WORK/process/MODULES.kit-mod-new"
  _md_mod status example
  [ -e "$SB_WORK/process/MODULES.kit-mod-new" ] || cf "(d) status removed the record's side file; it changes no byte"
  printf '%s\n' "$_md_out" | grep -F 'MODULES.kit-mod-new' | grep -F 'enable' >/dev/null || cf "(d) status does not name the leftover and what removes it: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$_md_out" | grep -F 'MODULES.kit-mod-new' | grep -E 'disable <|take it back' >/dev/null && cf "(d) the note advises a disable, which would take out a working module"
  _md_mod status
  [ -e "$SB_WORK/process/MODULES.kit-mod-new" ] || cf "(d) status with no name removed the record's side file"
  [ "$(printf '%s\n' "$_md_out" | grep -cF 'MODULES.kit-mod-new')" -eq 1 ] || cf "(d) status with no name does not name the leftover exactly once: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  printf 'half a record\n' > "$SB_WORK/process/MODULES.kit-mod-new"
  _md_mod disable example
  [ "$_md_rc" -eq 0 ] || cf "(d) disable of a module that is not enabled exited $_md_rc"
  [ ! -e "$SB_WORK/process/MODULES.kit-mod-new" ] || cf "(d) disable left the record's side file when nothing was enabled"
  printf 'half a record\n' > "$SB_WORK/process/MODULES.kit-mod-new"
  _md_mod disable ../x
  [ "$_md_rc" -ne 0 ] || cf "(d) (premise) disable of a name that is no module name exited 0"
  [ ! -e "$SB_WORK/process/MODULES.kit-mod-new" ] || cf "(d) a disable refused for its name left the record's side file, which enable removes before any refusal of a named run"

  # (e0) enable of a module takes the leftover too, also when that module is already enabled, and status names it once.
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || cf "(e0) (premise) enable exited $_md_rc"
  printf 'half a record\n' > "$SB_WORK/process/MODULES.kit-mod-new"
  _md_mod status example
  [ "$(printf '%s\n' "$_md_out" | grep -cF 'MODULES.kit-mod-new')" -eq 1 ] || cf "(e0) status of an enabled module does not name the leftover exactly once: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  _md_mod status
  [ "$(printf '%s\n' "$_md_out" | grep -cF 'MODULES.kit-mod-new')" -eq 1 ] || cf "(e0) status of every enabled module names the leftover other than once: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  _md_mod enable example
  printf '%s\n' "$_md_out" | grep -F 'already enabled' >/dev/null || cf "(e0) (premise) the second enable was not the already-enabled route: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-200)"
  [ ! -e "$SB_WORK/process/MODULES.kit-mod-new" ] || cf "(e0) enable of an already-enabled module left the record's side file"
  _md_mod disable example

  # (e) a placed file the project removed is 'already gone', and the directories it leaves empty go with it.
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || cf "(e) (premise) enable exited $_md_rc"
  rm -f "$SB_WORK/scripts/qa-cell.d/example-note/50-example.sh" "$SB_WORK/scripts/move-check.d/in_progress/50-example.sh"
  _md_mod disable example
  [ ! -d "$SB_WORK/scripts/qa-cell.d" ] || cf "(e) disable left the empty directory of a placed file the project had removed: $(find "$SB_WORK/scripts/qa-cell.d" | tr '\n' ' ')"
  [ ! -d "$SB_WORK/scripts/move-check.d" ] || cf "(e) disable left the empty directory of a placed file the project had removed: $(find "$SB_WORK/scripts/move-check.d" | tr '\n' ' ')"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — ENABLE BEFORE kit-init REFUSES A MODULE WHOSE FILES CARRY THE PROJECT'S BLANKS.
#   Placed with the blanks open, the files would be filled by kit-init's later stamp and then read as the
#   project's own edit, kept by every disable. The refusal names kit-init; a module with no blank enables.
# =============================================================================
case_module_enable_before_kit_init_refuses_a_module_whose_files_carry_blanks() {
  cf_reset
  local L="on a tree kit-init has not stamped, module.sh enable refuses a module whose files carry <PREFIX>, <trunk> or <project name>, naming the files and kit-init (rule module-before-kit-init, a Next: line, nothing written), enables a module with no blank, and enables the first once the stamp is there with the values in its files"
  if ! _md_have_example; then skp_lived "$L" "$(_md_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _md_sandbox
  [ -f "$SB_WORK/scripts/module.sh" ] || cf "(prereq) scripts/module.sh is absent from the tree under test"
  local s0="$SB_TMP/snap0" s1="$SB_TMP/snap1" cfg="$SB_WORK/scripts/config.sh"
  cp "$cfg" "$SB_TMP/config.stamped"
  grep -v '^# Stamped by scripts/kit-init.sh' "$SB_TMP/config.stamped" > "$cfg"
  grep -F 'Stamped by scripts/kit-init.sh' "$cfg" >/dev/null && _fixture_die "${FUNCNAME[0]}: the stamp line was not taken out of config.sh."
  _md_snap "$SB_WORK" > "$s0"
  _md_mod enable example
  { [ "$_md_rc" -eq 1 ] && printf '%s\n' "$_md_out" | grep -F '.claude/roles/example.md' >/dev/null && printf '%s\n' "$_md_out" | grep -F 'kit-init' >/dev/null && printf '%s\n' "$_md_out" | grep '^Next:' >/dev/null; } \
    || cf "(a) enable on an unstamped tree was not refused naming the file and kit-init (exit $_md_rc): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  [ "$(_md_recs module-before-kit-init)" -ge 1 ] || cf "(a) no refusal=module-before-kit-init record"
  _md_snap "$SB_WORK" > "$s1"; cmp -s "$s0" "$s1" || cf "(a) the refusal changed the tree"
  mkdir -p "$SB_WORK/modules/blankless"
  printf 'name: blankless\nversion: 0.1.0\npurpose: A fabricated module with no blank.\nfile: f.txt -> blankless/f.txt\n' > "$SB_WORK/modules/blankless/module.manifest"
  printf 'plain\n' > "$SB_WORK/modules/blankless/f.txt"
  _md_mod enable blankless
  [ "$_md_rc" -eq 0 ] || cf "(b) a module with no blank was refused on an unstamped tree (exit $_md_rc): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-200)"
  _md_mod disable blankless
  cp "$SB_TMP/config.stamped" "$cfg"
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || cf "(c) enable after the stamp exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-200)"
  grep -F "$SB_PREFIX-NNN" "$SB_WORK/.claude/roles/example.md" >/dev/null || cf "(c) the role doc does not carry the project's prefix"
  grep -F '<PREFIX>' "$SB_WORK/.claude/roles/example.md" >/dev/null && cf "(c) the role doc still carries <PREFIX>"
  _md_mod disable example

  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE MANIFEST KEYS FOR THE FRAGMENT, MOVE-CHECK AND QA-CELL POINTS PLACE THEIR FILES WHERE EACH POINT'S READER LOOKS,
# AND A VALUE THAT COULD NEVER BE READ THERE IS REFUSED.
# =============================================================================
case_the_manifest_keys_for_fragments_move_checks_and_cell_checks_place_and_refuse() {
  cf_reset
  local L="a manifest's fragment:, move-check: and qa-cell: lines place their sources at process/fragments.d/<template>/<module>.<mode>, scripts/move-check.d/<status folder>/ and scripts/qa-cell.d/<kind>/, and a template that is neither PRD nor ISSUE, a mode that is none, a status folder the project does not have, a file name that is no NN-<name>.sh and a second fragment for one place are each refused with a Next: line and nothing written"
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _md_sandbox
  [ -f "$SB_WORK/scripts/module.sh" ] || cf "(prereq) scripts/module.sh is absent from the tree under test"
  local s0="$SB_TMP/snap0" s1="$SB_TMP/snap1" d="$SB_WORK/modules/mk" f
  mkdir -p "$d"
  printf 'x\n' > "$d/a.txt"; printf '#!/usr/bin/env bash\nexit 0\n' > "$d/c.sh"
  _mk_manifest() { { printf 'name: mk\nversion: 0.1.0\npurpose: A fabricated module.\n'; printf '%s\n' "$@"; } > "$d/module.manifest"; }

  # (a) a good manifest places each file at its point's directory.
  _mk_manifest 'fragment: PRD frontmatter a.txt' 'fragment: PRD slot-story-fields a.txt' 'fragment: ISSUE body-end a.txt' 'move-check: c.sh -> blocked/20-x.sh' 'qa-cell: c.sh -> example-note/20-x.sh'
  _md_snap "$SB_WORK" > "$s0"
  _md_mod enable mk
  [ "$_md_rc" -eq 0 ] || cf "(a) a good manifest was refused (exit $_md_rc): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  for f in process/fragments.d/PRD/mk.frontmatter process/fragments.d/PRD/mk.slot-story-fields process/fragments.d/ISSUE/mk.body-end scripts/move-check.d/blocked/20-x.sh scripts/qa-cell.d/example-note/20-x.sh; do
    [ -f "$SB_WORK/$f" ] || cf "(a) $f was not placed"
  done
  _md_mod disable mk
  _md_snap "$SB_WORK" > "$s1"
  cmp -s "$s0" "$s1" || cf "(a) disable did not return the tree to its bytes: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-200)"

  # (b) each bad value is refused with the manifest rule, a Next: line, a record and nothing written.
  _mk_bad() {  # <tag> <fragment the message must carry> <manifest line>…
    local tag="$1" want="$2"; shift 2
    _mk_manifest "$@"
    rm -rf "$SB_TMP/records"
    _md_snap "$SB_WORK" > "$s0"
    _md_mod enable mk
    [ "$_md_rc" -eq 1 ] || cf "($tag) was not refused (exit $_md_rc): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-200)"
    printf '%s\n' "$_md_out" | grep -F -- "$want" >/dev/null || cf "($tag) the message does not carry '$want': $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
    printf '%s\n' "$_md_out" | grep '^Next:' >/dev/null || cf "($tag) no Next: line"
    [ "$(_md_recs module-manifest-bad)" -ge 1 ] || cf "($tag) no refusal=module-manifest-bad record"
    _md_snap "$SB_WORK" > "$s1"
    cmp -s "$s0" "$s1" || cf "($tag) the refusal changed the tree"
  }
  _mk_bad template   "is not PRD or ISSUE"           'fragment: BUG body-end a.txt'
  _mk_bad mode       "is not frontmatter, body-end"  'fragment: PRD middle a.txt'
  _mk_bad slotname   "names no slot"                 'fragment: PRD slot- a.txt'
  _mk_bad shape      "is not '<PRD|ISSUE>"           'fragment: PRD body-end'
  _mk_bad twice      "two entries write"             'fragment: PRD body-end a.txt' 'fragment: PRD body-end a.txt'
  _mk_bad casedup    "two entries write"             'file: a.txt -> docs/Note.md' 'file: a.txt -> docs/note.md'
  _mk_bad blockgit   "inside modules/ or .git/"      'block: .GIT/config s a.txt'
  _mk_bad blockrec   "own bookkeeping"               'block: PROCESS/modules s a.txt'
  _mk_bad folder     "no status folder"              'move-check: c.sh -> nowhere/20-x.sh'
  _mk_bad checkname  "is not <status folder>/NN-"    'move-check: c.sh -> blocked/x.sh'
  _mk_bad cellname   "is not <evidence kind>/NN-"    'qa-cell: c.sh -> Bad_Kind/20-x.sh'
  _mk_bad arm        "has no '# check-board-arm:"    'arm: c.sh -> 20-x.sh'

  finish "$L"
  teardown
}

# =============================================================================
# CASE — ENABLE REFUSES A FRAGMENT EVERY MINT OF ITS TEMPLATE WOULD REFUSE, BEFORE IT WRITES.
#   A fragment source carrying a KIT-MODULES slot line of its own or a control byte (octal 035 to 037) would be
#   placed, and every mint of its template would then refuse. Enable asks the mint's own question of each
#   fragment it would place and names the module's source to fix.
# =============================================================================
case_module_enable_refuses_a_fragment_every_mint_would_refuse() {
  cf_reset
  local L="enable refuses a module whose fragment source carries a KIT-MODULES slot line or a control byte (octal 035, 036 or 037), with module-fragment-bad, naming the source under modules/<name>/ and the place it would go and only that one, NOTHING WAS CHANGED and a Next: line, and the tree unchanged; the same module with the fragment clean enables"
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _md_sandbox
  [ -f "$SB_WORK/scripts/module.sh" ] || cf "(prereq) scripts/module.sh is absent from the tree under test"
  local s0="$SB_TMP/snap0" s1="$SB_TMP/snap1" d="$SB_WORK/modules/mf" b
  mkdir -p "$d/fragments"
  printf 'name: mf\nversion: 0.1.0\npurpose: A fabricated module.\nfragment: ISSUE body-end fragments/end.txt\nfragment: PRD slot-story-fields fragments/story.txt\n' > "$d/module.manifest"
  printf '**MF:** story\n' > "$d/fragments/story.txt"
  _mf_bad() {  # <tag> <text of fragments/end.txt> <what the line must say>
    printf '%s\n' "$2" > "$d/fragments/end.txt"
    _md_snap "$SB_WORK" > "$s0"
    _md_mod enable mf
    [ "$_md_rc" -eq 1 ] || cf "($1) enable was not refused (exit $_md_rc): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
    _md_snap "$SB_WORK" > "$s1"
    cmp -s "$s0" "$s1" || cf "($1) the refusal changed the tree: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-200)"
    [ "$(_md_recs module-fragment-bad)" -ge 1 ] || cf "($1) no refusal=module-fragment-bad record: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
    printf '%s\n' "$_md_out" | grep -F "modules/mf/fragments/end.txt (placed as process/fragments.d/ISSUE/mf.body-end) $3" >/dev/null \
      || cf "($1) the refusal does not name the source, the place it would go and '$3': $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
    printf '%s\n' "$_md_out" | grep -F 'fragments/story.txt' >/dev/null && cf "($1) the refusal names the clean fragment too"
    printf '%s\n' "$_md_out" | grep -F 'NOTHING WAS CHANGED' >/dev/null || cf "($1) the refusal does not say NOTHING WAS CHANGED"
    printf '%s\n' "$_md_out" | grep '^Next:.*modules/mf/.*module.sh enable mf' >/dev/null || cf "($1) no Next: line naming modules/mf/ and enable again"
    [ "$_md_rc" -ne 0 ] || _md_mod disable mf   # an enable that went through is taken back, so the next row starts from the same tree
  }
  _mf_bad markers '<!-- KIT-MODULES:story-fields leaked -->' 'carries a KIT-MODULES slot line'
  for b in 035 036 037; do _mf_bad "control $b" "one$(printf "\\$b")two" 'holds a control byte'; done
  unset -f _mf_bad
  # (control) the same module with the fragment clean enables and places it.
  printf 'MF-END\n' > "$d/fragments/end.txt"
  _md_mod enable mf
  [ "$_md_rc" -eq 0 ] || cf "(control) enable of the clean module exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  [ -f "$SB_WORK/process/fragments.d/ISSUE/mf.body-end" ] || cf "(control) the clean fragment was not placed"
  _md_mod disable mf
  finish "$L"
  teardown
}

# =============================================================================
# CASE — EVERY SHIPPED MODULE READS AS A MODULE: ITS MANIFEST NAMES ITS DIRECTORY, IT HAS A ROW IN THE MODULES INDEX,
# AND IT ENABLES AND DISABLES BACK TO THE BYTES IT FOUND.
#   Derived from modules/*/module.manifest, so a module added later is judged without a case of its own for this.
# =============================================================================
# _md_tool_here <requirement id> — status 0 when the tool is on PATH; python3 also needs 3.9 or later (the floor the shipped modules ask), so an
# older python behind the name counts as absent.
_md_tool_here() {
  command -v "$1" >/dev/null 2>&1 || return 1
  [ "$1" != python3 ] || python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' >/dev/null 2>&1
}
case_every_shipped_module_is_indexed_and_enables_and_disables_cleanly() {
  cf_reset
  local L="each module under modules/ has a manifest whose name is its directory, a row in modules/README.md (a row may outlive a deleted directory), and enables and disables in a sandbox to the bytes it found, with every recorded thing intact in between"
  local m name dirs="" s0 s1 skipped="" judged=0 absent id
  for m in "$REAL_REPO_ROOT"/modules/*/module.manifest; do
    [ -f "$m" ] || continue
    dirs="${dirs}$(basename "$(dirname "$m")")
"
  done
  if [ -z "$dirs" ]; then skp_lived "$L" "$(_md_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _md_sandbox
  [ -f "$SB_WORK/scripts/module.sh" ] || cf "(prereq) scripts/module.sh is absent from the tree under test"
  s0="$SB_TMP/snap0"; s1="$SB_TMP/snap1"
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    [ "$(sed -n 's/^name:[[:space:]]*//p' "$REAL_REPO_ROOT/modules/$name/module.manifest" | head -1)" = "$name" ] \
      || cf "($name) its manifest's name is not its directory"
    grep -F "[\`$name\`]" "$REAL_REPO_ROOT/modules/README.md" >/dev/null 2>&1 || cf "($name) modules/README.md has no row for it"
    _md_snap "$SB_WORK" > "$s0"
    _md_mod enable "$name"
    if [ "$_md_rc" -ne 0 ]; then
      # a required requirement that does not hold on this machine is the module's refusal, not the lifecycle's defect: named, not failed
      if [ "$(_md_recs module-requires-missing)" -ge 1 ] && [ ! -e "$SB_WORK/process/MODULES" ]; then
        # legitimate only when a tool the manifest requires (a `requires:` id) is really absent here; a check that fails with every tool present is the module's defect
        absent=""
        for id in $(sed -n -E 's/^requires:[[:space:]]*([a-z0-9][a-z0-9._-]*) \|.*\| required[[:space:]]*$/\1/p' "$REAL_REPO_ROOT/modules/$name/module.manifest"); do
          _md_tool_here "$id" || absent="$absent $id"
        done
        if [ -n "$absent" ]; then skipped="${skipped}${skipped:+, }$name"; continue; fi
        cf "($name) enable refused a required requirement although every tool it names is present: its check fails on this machine"; continue
      fi
      cf "($name) enable exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"; continue
    fi
    judged=$((judged + 1))
    _md_mod status "$name"
    printf '%s\n' "$_md_out" | grep -E 'edited|missing' >/dev/null && cf "($name) status reports an edited or missing thing straight after enable"
    _md_mod disable "$name"
    _md_snap "$SB_WORK" > "$s1"
    cmp -s "$s0" "$s1" || cf "($name) disable did not return the tree to its bytes: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-200)"
  done <<MODULE_DIRS_EOF
$dirs
MODULE_DIRS_EOF

  # The other direction is deliberately not checked: EXTRACTION.md sanctions deleting a module's directory,
  # and the index row of a module the project declined may stay.

  if [ -n "$skipped" ]; then
    if [ "$judged" -eq 0 ] && [ -z "$_cf" ]; then skp "$L" "every module's required requirement fails on this machine (refused module-requires-missing): $skipped"; teardown; return; fi
    printf '  note  not judged here, a required requirement does not hold (refused module-requires-missing): %s\n' "$skipped"
  fi
  finish "$L"
  teardown
}

# =============================================================================
# CASE — ENABLE TAKES ONLY WHAT IT WROTE; A MODULE'S BLOCKS ARE PER SLOT; DISABLE'S LEFTOVERS STAY RECORDED.
#   A file that already equals the module's copy is not adopted (disable would delete it); two blocks of one
#   module in one file, one per slot, are two blocks; a path in a non-canonical spelling is refused; a disable
#   that keeps an edited file leaves the record that says whose it was.
# =============================================================================
_mx_proj() {  # <dir> — a project that holds module.sh and its libraries, a PROJECT.md and a CORPUS.md with their slots
  mkdir -p "$1/scripts/lib" "$1/requirements" "$1/modules"
  cp "$REAL_SCRIPTS/module.sh" "$1/scripts/"
  local l
  for l in $(script_libs "$REAL_SCRIPTS/module.sh"); do cp "$REAL_SCRIPTS/lib/$l" "$1/scripts/lib/"; done
  printf '# PROJECT.md\n\n| Gate | C |\n|---|---|\n| g | `x` |\n\n<!-- KIT-MODULES:gates the slot -->\n\ntail\n' > "$1/PROJECT.md"
  printf '# CORPUS\n\n<!-- KIT-MODULES:corpus-manifest the slot -->\n\nmid\n\n<!-- KIT-MODULES:corpus-buckets the slot -->\n' > "$1/requirements/CORPUS.md"
}
_mx_put() { mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" > "$1"; }   # <path> <content>
_mx_mod() {  # <kit dir> <name> <version> <manifest line>… — modules/<name>/module.manifest; the caller writes the files
  local d="$1/modules/$2"; mkdir -p "$d"
  { printf 'name: %s\nversion: %s\npurpose: A fabricated module.\n' "$2" "$3"; shift 3; printf '%s\n' "$@"; } > "$d/module.manifest"
}
_mx_rc=0; _mx_out=""
_mx_run() { _mx_rc=0; _mx_out="$( cd "$1" && shift && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/records" ./scripts/module.sh "$@" 2>&1 </dev/null )" || _mx_rc=$?; }

# =============================================================================
# CASE — THE FIXTURES' LIBRARY LISTS FOLLOW THE SCRIPTS' OWN SOURCE LINES.
#   Operand: a copy of the scripts under test whose module.sh sources one more library. _mx_proj copies
#   it into the project it builds (and module.sh runs there), and each of the three prerequisite checks
#   (_md_missing_program, _mq_subject_ok, _mu_subject_ok) names it when the copy lacks it. On the real
#   tree the checks are quiet.
# =============================================================================
case_fixture_library_lists_follow_the_scripts_source_lines() {
  cf_reset
  local L="the fixtures that copy or check module.sh's libraries take the list from the scripts' source lines: a library module.sh gains is copied by _mx_proj and named as missing by each prerequisite check"
  [ -f "$REAL_SCRIPTS/module.sh" ] || { cf "scripts/module.sh is absent from the tree under test"; finish "$L"; return; }
  make_sandbox
  local K="$SB_TMP/fl-kit" P="$SB_TMP/fl-proj" got
  mkdir -p "$K"; cp -R "$REAL_SCRIPTS" "$K/scripts"
  printf 'kit_fl_probe() { :; }\n' > "$K/scripts/lib/fl-probe.sh"
  awk '{ print } $0 == ". \"$SCRIPT_DIR/lib/modules.sh\"" { print ". \"$SCRIPT_DIR/lib/fl-probe.sh\"" }' "$REAL_SCRIPTS/module.sh" > "$K/scripts/module.sh"
  grep -qF '. "$SCRIPT_DIR/lib/fl-probe.sh"' "$K/scripts/module.sh" || _fixture_die "case_fixture_library_lists_follow_the_scripts_source_lines: the new source line did not land in module.sh"
  chmod +x "$K/scripts/module.sh"
  # (copy) _mx_proj copies the new library, and module.sh runs in the project it builds.
  ( REAL_REPO_ROOT="$K"; REAL_SCRIPTS="$K/scripts"; _mx_proj "$P" )
  [ -f "$P/scripts/lib/fl-probe.sh" ] || cf "(_mx_proj) the project lacks scripts/lib/fl-probe.sh, which its module.sh sources"
  _mx_run "$P" list
  [ "$_mx_rc" -eq 0 ] || cf "(_mx_proj) module.sh list in the built project exited $_mx_rc: $(printf '%s' "$_mx_out" | tr '\n' '|' | cut -c1-200)"
  # (checks) the copy lacks the library: each prerequisite check names it.
  rm -f "$K/scripts/lib/fl-probe.sh"
  got="$( REAL_REPO_ROOT="$K"; REAL_SCRIPTS="$K/scripts"; _md_missing_program )"
  [ "$got" = scripts/lib/fl-probe.sh ] || cf "(_md_missing_program) named '$got', not scripts/lib/fl-probe.sh"
  got="$( REAL_REPO_ROOT="$K"; REAL_SCRIPTS="$K/scripts"; _cf=""; _mq_subject_ok; printf '%s' "$_cf" )"
  case "$got" in *scripts/lib/fl-probe.sh*) ;; *) cf "(_mq_subject_ok) did not name scripts/lib/fl-probe.sh: '$got'" ;; esac
  got="$( REAL_REPO_ROOT="$K"; REAL_SCRIPTS="$K/scripts"; _cf=""; _mu_subject_ok; printf '%s' "$_cf" )"
  case "$got" in *scripts/lib/fl-probe.sh*) ;; *) cf "(_mu_subject_ok) did not name scripts/lib/fl-probe.sh: '$got'" ;; esac
  # (control) the real tree: every check is quiet.
  got="$(_md_missing_program)"; [ -z "$got" ] || cf "(control) _md_missing_program names $got on the real tree"
  got="$( _cf=""; _mq_subject_ok; _mu_subject_ok; printf '%s' "$_cf" )"; [ -z "$got" ] || cf "(control) a prerequisite check fails on the real tree: $got"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A REFUSAL INSIDE module.sh list's LOOP ENDS THE COMMAND WITH ITS CODE.
#   Operand: module.sh list in a project whose lib/modules.sh is made to refuse while listing one
#   module, in a call the loop makes itself (not inside a command substitution, whose exit is its
#   own). The refusal is the command's exit status and nothing is listed after it; without the
#   stand-in, the same project lists both modules and exits 0.
# =============================================================================
case_module_list_ends_with_a_refusal_made_inside_its_loop() {
  cf_reset
  local L="a refusal made while module.sh list reads its modules ends the command with the refusal's exit status, and nothing is listed after it"
  [ -f "$REAL_SCRIPTS/module.sh" ] || { cf "scripts/module.sh is absent from the tree under test"; finish "$L"; return; }
  make_sandbox
  local P="$SB_TMP/ml"
  _mx_proj "$P"
  _mx_mod "$P" ma 0.1.0 'file: h.sh -> tools/ma.sh'; _mx_put "$P/modules/ma/h.sh" 'echo a'
  _mx_mod "$P" mz 0.1.0 'file: h.sh -> tools/mz.sh'; _mx_put "$P/modules/mz/h.sh" 'echo z'
  # (control) as shipped: both listed, exit 0.
  _mx_run "$P" list
  [ "$_mx_rc" -eq 0 ] || cf "(control) module.sh list exited $_mx_rc: $(printf '%s' "$_mx_out" | tr '\n' '|' | cut -c1-200)"
  case "$_mx_out" in *" ma "*" mz "*"Enable one with"*) ;; *) cf "(control) module.sh list did not list ma and mz: $(printf '%s' "$_mx_out" | tr '\n' '|' | cut -c1-200)" ;; esac
  # (refusal) listing mz refuses: exit 3, the refusal printed, and the list stops there.
  printf '%s\n' 'kit_mod_is_enabled() { [ "$1" != mz ] || kit_refuse 3 module-list-probe "Error: the probe refuses to list mz." "Next: none; this is the self-test'"'"'s stand-in."; return 1; }' >> "$P/scripts/lib/modules.sh"
  _mx_run "$P" list
  [ "$_mx_rc" -eq 3 ] || cf "(refusal) module.sh list exited $_mx_rc, not the refusal's 3: $(printf '%s' "$_mx_out" | tr '\n' '|' | cut -c1-200)"
  case "$_mx_out" in *"the probe refuses to list mz"*) ;; *) cf "(refusal) the refusal is not in the output: $(printf '%s' "$_mx_out" | tr '\n' '|' | cut -c1-200)" ;; esac
  case "$_mx_out" in *"Enable one with"*) cf "(refusal) module.sh list went on past the refusal: $(printf '%s' "$_mx_out" | tr '\n' '|' | cut -c1-200)" ;; esac
  finish "$L"
  teardown
}

case_module_enable_takes_only_what_it_wrote_and_blocks_are_per_slot() {
  cf_reset
  local L="enable refuses a target that already exists even when byte-equal (so disable cannot delete a file the project or another module had), puts one block per slot of a file for one module and takes each back, refuses './' and '//' spellings, refuses a record row that leaves the project, and a disable that keeps an edited file leaves it recorded under 'kept' for status, list and a re-enable"
  [ -f "$REAL_SCRIPTS/module.sh" ] && [ -f "$REAL_SCRIPTS/lib/modules.sh" ] || { cf "scripts/module.sh or scripts/lib/modules.sh is absent from the tree under test"; finish "$L"; return; }
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  make_sandbox
  local P="$SB_TMP/mx-e" s0="$SB_TMP/mx-e.s0" s1="$SB_TMP/mx-e.s1"

  _mx_proj "$P"
  _mx_mod "$P" ma 0.1.0 'file: h.sh -> tools/h.sh'; _mx_put "$P/modules/ma/h.sh" 'echo h'
  _mx_mod "$P" mx 0.1.0 'file: h.sh -> tools/h.sh'; _mx_put "$P/modules/mx/h.sh" 'echo h'
  _mx_mod "$P" mc 0.1.0 'block: requirements/CORPUS.md corpus-manifest a.md' 'block: requirements/CORPUS.md corpus-buckets b.md'
  printf '| A | B |\n|---|---|\n| AAA row | x |\n' > "$P/modules/mc/a.md"; printf '| C | D |\n|---|---|\n| BBB row | y |\n' > "$P/modules/mc/b.md"

  # (a) a second module whose file is byte-equal to the first's is refused, and the first's file survives its disable.
  _mx_run "$P" enable ma
  [ "$_mx_rc" -eq 0 ] || { cf "enable ma exited $_mx_rc: $_mx_out"; finish "$L"; teardown; return; }
  _md_snap "$P" > "$s0"
  _mx_run "$P" enable mx
  [ "$_mx_rc" -eq 1 ] && printf '%s\n' "$_mx_out" | grep -F 'tools/h.sh' >/dev/null && printf '%s\n' "$_mx_out" | grep -F 'Next:' >/dev/null \
    || cf "(a) enabling a module whose file is byte-equal to another module's was not refused naming tools/h.sh with a Next: line (exit $_mx_rc): $(printf '%s' "$_mx_out" | tr '\n' '|' | cut -c1-240)"
  _md_snap "$P" > "$s1"; cmp -s "$s0" "$s1" || cf "(a) the refused enable changed the tree"
  grep -F 'module mx' "$P/process/MODULES" >/dev/null && cf "(a) mx is recorded though it was refused"
  _mx_run "$P" status ma
  printf '%s\n' "$_mx_out" | grep -E '^  intact +tools/h.sh' >/dev/null || cf "(a) ma's file is not intact after the refused enable: $_mx_out"
  # a file the project already had, identical to the module's copy, is refused the same way
  _mx_run "$P" disable ma; [ -e "$P/tools/h.sh" ] && cf "(a) (control) ma's file survived its own disable"
  _mx_put "$P/tools/h.sh" 'echo h'
  _mx_run "$P" enable mx
  [ "$_mx_rc" -eq 1 ] || cf "(a) enable took a file the project already had, byte-equal to the module's copy (exit $_mx_rc): $_mx_out"
  [ -f "$P/tools/h.sh" ] || cf "(a) the project's own file was removed"
  rm -f "$P/tools/h.sh"; rmdir "$P/tools" 2>/dev/null

  # (b) two blocks of one module in one file, one per slot, are two blocks.
  _mx_run "$P" enable mc
  [ "$_mx_rc" -eq 0 ] || cf "(b) enable of a module with a block in each slot of one file exited $_mx_rc: $_mx_out"
  grep -F 'AAA row' "$P/requirements/CORPUS.md" >/dev/null && grep -F 'BBB row' "$P/requirements/CORPUS.md" >/dev/null \
    || cf "(b) the file does not hold both blocks (the second replaced the first): $(tr '\n' '|' < "$P/requirements/CORPUS.md")"
  [ "$(grep -n 'AAA row' "$P/requirements/CORPUS.md" | cut -d: -f1)" -lt "$(grep -n 'KIT-MODULES:corpus-manifest' "$P/requirements/CORPUS.md" | cut -d: -f1)" ] || cf "(b) the first block is not before its own slot"
  _mx_run "$P" status mc
  [ "$(printf '%s\n' "$_mx_out" | grep -cE '^  intact +requirements/CORPUS.md')" = 2 ] || cf "(b) status does not show both blocks intact: $_mx_out"
  # edit the second block: disable removes the first, KEEPS the second, and names the right slot
  perl -pi -e 's/^(\| BBB row.*)$/$1\n| the project row | z |/' "$P/requirements/CORPUS.md"
  _mx_run "$P" disable mc
  grep -F 'AAA row' "$P/requirements/CORPUS.md" >/dev/null && cf "(b) the unedited first block was not removed"
  grep -F 'BBB row' "$P/requirements/CORPUS.md" >/dev/null || cf "(b) the edited second block was removed"
  printf '%s\n' "$_mx_out" | grep -F 'slot corpus-buckets' >/dev/null || cf "(b) disable does not name the kept block's slot: $_mx_out"

  # (c) THE KEPT RECORD: status, list and a re-enable say whose leftovers these are.
  grep -E '^kept mc 0\.1\.0$' "$P/process/MODULES" >/dev/null || cf "(c) process/MODULES has no 'kept mc' record after a disable that kept a block: $(tr '\n' '|' < "$P/process/MODULES" 2>/dev/null | cut -c1-200)"
  grep -E '^module mc ' "$P/process/MODULES" >/dev/null && cf "(c) mc is still recorded as enabled"
  _mx_run "$P" status mc
  printf '%s\n' "$_mx_out" | grep -F 'kept' >/dev/null && printf '%s\n' "$_mx_out" | grep -F 'requirements/CORPUS.md' >/dev/null || cf "(c) status of a disabled module with kept files does not say so: $_mx_out"
  _mx_run "$P" list
  printf '%s\n' "$_mx_out" | grep -E '^  mc .*kept' >/dev/null || cf "(c) list does not mark the module that left files behind: $_mx_out"
  _mx_run "$P" enable mc
  [ "$_mx_rc" -eq 1 ] && printf '%s\n' "$_mx_out" | grep -F 'Next:' >/dev/null || cf "(c) a re-enable over the kept block was not refused with a Next: line (exit $_mx_rc): $_mx_out"
  # clearing the leftover and enabling again works, and drops the kept record
  rm -f "$P/requirements/CORPUS.md"; printf '# CORPUS\n\n<!-- KIT-MODULES:corpus-manifest the slot -->\n\nmid\n\n<!-- KIT-MODULES:corpus-buckets the slot -->\n' > "$P/requirements/CORPUS.md"
  _mx_run "$P" enable mc
  [ "$_mx_rc" -eq 0 ] || cf "(c) enable after the leftover was cleared exited $_mx_rc: $_mx_out"
  grep -E '^kept ' "$P/process/MODULES" >/dev/null && cf "(c) the kept record survived a successful enable"
  _mx_run "$P" disable mc

  # (e) A RECORD ROW whose path leaves the project is refused, never acted on: process/MODULES is tracked, so a merge
  #     or a hand edit can put anything in it, and disable removes the file a row names when its sha matches.
  _mx_run "$P" enable ma
  [ "$_mx_rc" -eq 0 ] || { cf "enable ma exited $_mx_rc: $_mx_out"; finish "$L"; teardown; return; }
  printf 'outside\n' > "$SB_TMP/outside.txt"
  printf 'file %s ../outside.txt\n' "$(_old_sha "$SB_TMP/outside.txt")" >> "$P/process/MODULES"
  _mx_run "$P" disable ma
  [ "$_mx_rc" -eq 1 ] && printf '%s\n' "$_mx_out" | grep -F 'Next:' >/dev/null || cf "(e) a record row naming ../outside.txt was not refused with a Next: line (exit $_mx_rc): $(printf '%s' "$_mx_out" | tr '\n' '|' | cut -c1-200)"
  [ -f "$SB_TMP/outside.txt" ] || cf "(e) disable deleted a file outside the project because a record row named it"
  sed -i.bak '/outside.txt/d' "$P/process/MODULES"; rm -f "$P/process/MODULES.bak"
  _mx_run "$P" disable ma

  # (d) PATHS in one canonical form: './' and '//' and a '.' component are refused before anything is written.
  local bad
  for bad in './.git/hooks/post-checkout' 'process//KIT-VERSION' 'a/./b' 'dir/' '.GIT/hooks/post-commit' '.Git' 'Process/modules' 'MODULES/x'; do
    _mx_mod "$P" mp 0.1.0 "file: p.txt -> $bad"; _mx_put "$P/modules/mp/p.txt" p
    _md_snap "$P" > "$s0"
    _mx_run "$P" enable mp
    [ "$_mx_rc" -eq 1 ] && printf '%s\n' "$_mx_out" | grep -F 'Next:' >/dev/null || cf "(d) the target '$bad' was not refused with a Next: line (exit $_mx_rc): $(printf '%s' "$_mx_out" | tr '\n' '|' | cut -c1-200)"
    _md_snap "$P" > "$s1"; cmp -s "$s0" "$s1" || cf "(d) the refused target '$bad' changed the tree"
  done
  [ -e "$P/.git/hooks/post-checkout" ] && cf "(d) a module placed a git hook through './.git/'"

  # (f) A SYMBOLIC LINK: a block target under a linked directory, or a linked host, is refused and the file
  #     it points at is untouched, as a file target under a linked directory already was.
  local out_dir="$SB_TMP/outside-dir"
  mkdir -p "$out_dir"; printf '# host\n\n<!-- KIT-MODULES:s the slot -->\n' > "$out_dir/t.md"
  ln -s "$out_dir" "$P/shared"; ln -s "$out_dir/t.md" "$P/linked.md"
  mkdir -p "$P/modules/ml"; printf '| X |\n|---|\n| row |\n' > "$P/modules/ml/b.md"
  cp "$out_dir/t.md" "$SB_TMP/t.before"
  for bad in 'shared/t.md' 'linked.md'; do
    _mx_mod "$P" ml 0.1.0 "block: $bad s b.md"
    _md_snap "$P" > "$s0"
    _mx_run "$P" enable ml
    [ "$_mx_rc" -eq 1 ] && printf '%s\n' "$_mx_out" | grep -F 'symbolic link' >/dev/null && printf '%s\n' "$_mx_out" | grep -F 'Next:' >/dev/null \
      || cf "(f) a block target '$bad' through a symbolic link was not refused naming the link (exit $_mx_rc): $(printf '%s' "$_mx_out" | tr '\n' '|' | cut -c1-240)"
    cmp -s "$SB_TMP/t.before" "$out_dir/t.md" || cf "(f) the file outside the project was written through '$bad'"
  done

  finish "$L"
  teardown
}

# =============================================================================
# CASE — A MODULE'S IGNORE LINES ARE A BLOCK AT THE END OF .gitignore, WRITTEN IN `#` COMMENTS, CREATED WITH THE FILE
# AND TAKEN BACK WITH IT.
#   Operand: a byte snapshot. Enable into an existing .gitignore and disable restore it; enable with no .gitignore
#   and disable leave none; a .gitignore with no final newline is refused with nothing written; an edited block is
#   kept and named; the slot name is reserved; one `gitignore:` line a module.
# =============================================================================
case_module_gitignore_block_is_appended_to_gitignore_and_taken_back() {
  cf_reset
  local L="a manifest's gitignore: line puts a block in # comments at the end of .gitignore (created when absent), records it, takes it back so the file is byte-equal or gone, refuses a .gitignore with no final newline before writing, keeps an edited block and names it, and refuses 'gitignore' as a block slot and a second gitignore: line"
  [ -f "$REAL_SCRIPTS/module.sh" ] && [ -f "$REAL_SCRIPTS/lib/modules.sh" ] || { cf "scripts/module.sh or scripts/lib/modules.sh is absent from the tree under test"; finish "$L"; return; }
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  make_sandbox
  local P="$SB_TMP/mx-g" s0="$SB_TMP/mx-g.s0" s1="$SB_TMP/mx-g.s1" orig

  _mx_proj "$P"
  _mx_mod "$P" mg 0.1.0 'file: f.md -> mg/f.md' 'gitignore: ig.txt'
  _mx_put "$P/modules/mg/f.md" f1
  printf '# the mg module cache\n.mg-cache/\n' > "$P/modules/mg/ig.txt"

  # (a) no .gitignore: enable creates it, in # comments, and disable leaves none.
  _md_snap "$P" > "$s0"
  _mx_run "$P" enable mg
  [ "$_mx_rc" -eq 0 ] || { cf "(a) enable of a module with a gitignore: line exited $_mx_rc: $(printf '%s' "$_mx_out" | tr '\n' '|' | cut -c1-240)"; finish "$L"; teardown; return; }
  [ -f "$P/.gitignore" ] || cf "(a) enable did not create .gitignore"
  [ "$(sed -n 1p "$P/.gitignore")" = '# KIT-MODULE:mg:gitignore BEGIN' ] || cf "(a) .gitignore does not open with the block's # marker: $(tr '\n' '|' < "$P/.gitignore" | cut -c1-200)"
  grep -F '<!--' "$P/.gitignore" >/dev/null && cf "(a) a <!-- marker is in .gitignore, where it is a pattern"
  grep -qxF '.mg-cache/' "$P/.gitignore" || cf "(a) the module's ignore line is not in .gitignore"
  grep -E '^block [0-9a-f]{64} \.gitignore gitignore$' "$P/process/MODULES" >/dev/null || cf "(a) process/MODULES does not record the .gitignore block: $(tr '\n' '|' < "$P/process/MODULES" | cut -c1-240)"
  _mx_run "$P" status mg
  printf '%s\n' "$_mx_out" | grep -E '^  intact +\.gitignore \(block, slot gitignore\)' >/dev/null || cf "(a) status does not show the .gitignore block intact: $_mx_out"
  _mx_run "$P" disable mg
  [ -e "$P/.gitignore" ] && cf "(a) disable left the .gitignore enable created: $(tr '\n' '|' < "$P/.gitignore")"
  _md_snap "$P" > "$s1"; cmp -s "$s0" "$s1" || cf "(a) the tree is not as it was before enable: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-200)"

  # (b) an existing .gitignore: the block goes last, the lines above are untouched, a second enable moves nothing, and disable restores the bytes.
  printf 'node_modules/\n.env\n' > "$P/.gitignore"; orig="$(cat "$P/.gitignore")"
  _md_snap "$P" > "$s0"
  _mx_run "$P" enable mg
  [ "$_mx_rc" -eq 0 ] || cf "(b) enable into an existing .gitignore exited $_mx_rc: $_mx_out"
  [ "$(sed -n '1,2p' "$P/.gitignore")" = "$orig" ] || cf "(b) the project's own lines were changed: $(tr '\n' '|' < "$P/.gitignore" | cut -c1-200)"
  [ "$(sed -n 3p "$P/.gitignore")" = '# KIT-MODULE:mg:gitignore BEGIN' ] || cf "(b) the block is not appended after the project's lines"
  cp "$P/.gitignore" "$SB_TMP/mx-g.once"
  _mx_run "$P" enable mg
  printf '%s\n' "$_mx_out" | grep -F 'already enabled' >/dev/null || cf "(b) the second enable does not say it is already enabled: $_mx_out"
  cmp -s "$SB_TMP/mx-g.once" "$P/.gitignore" || cf "(b) the second enable changed .gitignore"
  _mx_run "$P" disable mg
  _md_snap "$P" > "$s1"; cmp -s "$s0" "$s1" || cf "(b) disable did not restore .gitignore byte for byte: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-200)"

  # (c) no final newline: refused before anything is written, with a Next: line.
  printf 'node_modules/' > "$P/.gitignore"
  _md_snap "$P" > "$s0"
  _mx_run "$P" enable mg
  [ "$_mx_rc" -eq 1 ] && printf '%s\n' "$_mx_out" | grep -F '.gitignore' >/dev/null && printf '%s\n' "$_mx_out" | grep -F 'newline' >/dev/null && printf '%s\n' "$_mx_out" | grep -F 'Next:' >/dev/null \
    || cf "(c) a .gitignore with no final newline was not refused naming it and the newline, with a Next: line (exit $_mx_rc): $(printf '%s' "$_mx_out" | tr '\n' '|' | cut -c1-240)"
  _md_snap "$P" > "$s1"; cmp -s "$s0" "$s1" || cf "(c) the refused enable changed the tree"
  [ -e "$P/mg/f.md" ] && cf "(c) a file was placed before the .gitignore refusal"

  # (d) an edited block is kept, named, and still acts.
  printf 'node_modules/\n' > "$P/.gitignore"
  _mx_run "$P" enable mg
  perl -pi -e 's/^(\.mg-cache\/)$/$1\n.mine\//' "$P/.gitignore"
  _mx_run "$P" status mg
  printf '%s\n' "$_mx_out" | grep -E '^  edited +\.gitignore \(block, slot gitignore\)' >/dev/null || cf "(d) status does not call the edited block edited: $_mx_out"
  _mx_run "$P" disable mg
  grep -qxF '.mine/' "$P/.gitignore" || cf "(d) disable removed an edited block"
  printf '%s\n' "$_mx_out" | grep -F '.gitignore' >/dev/null && printf '%s\n' "$_mx_out" | grep -F 'KEPT' >/dev/null || cf "(d) disable does not name the kept .gitignore: $_mx_out"

  # (e) the slot name is reserved, and a module has one gitignore: line.
  rm -f "$P/.gitignore" "$P/process/MODULES" "$P/mg/f.md"
  _mx_mod "$P" mh 0.1.0 'block: .gitignore gitignore ig.txt'; printf '.x/\n' > "$P/modules/mh/ig.txt"
  _mx_run "$P" enable mh
  [ "$_mx_rc" -eq 1 ] && printf '%s\n' "$_mx_out" | grep -F 'reserved' >/dev/null && printf '%s\n' "$_mx_out" | grep -F 'Next:' >/dev/null \
    || cf "(e) 'block: .gitignore gitignore' was not refused as reserved (exit $_mx_rc): $(printf '%s' "$_mx_out" | tr '\n' '|' | cut -c1-200)"
  _mx_mod "$P" mi 0.1.0 'gitignore: ig.txt' 'gitignore: ig2.txt'; printf '.x/\n' > "$P/modules/mi/ig.txt"; printf '.y/\n' > "$P/modules/mi/ig2.txt"
  _mx_run "$P" enable mi
  [ "$_mx_rc" -eq 1 ] && printf '%s\n' "$_mx_out" | grep -F 'two entries' >/dev/null || cf "(e) two gitignore: lines were not refused (exit $_mx_rc): $(printf '%s' "$_mx_out" | tr '\n' '|' | cut -c1-200)"
  [ -e "$P/.gitignore" ] && cf "(e) a refused enable created .gitignore"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — A MANIFEST THAT NAMES A HOST OR A DIRECTORY IN ANOTHER CASE THAN THE PROJECT'S, OR A ROLE THE BASE SET CARRIES, IS REFUSED.
#   Placed as written, the first is recorded in a spelling the project does not use (a row `status` then calls missing and
#   `disable` ignores), and the second is kept by every disable for as long as history carries the tag. Each is met at
#   enable, before anything is written; the same manifest spelt as the project spells it enables.
# =============================================================================
case_module_enable_refuses_a_host_or_directory_in_another_case_and_a_role_the_base_set_carries() {
  cf_reset
  local L="module.sh enable refuses, before it writes and with a Next: line, a block host spelt in another case than the file the project has, a new file under a directory spelt in another case, a role tag the base role set carries (in either case) and one process/ROLES carries; the same module spelt as the project spells it, with a role of its own, enables"
  if ! _md_have_example; then skp_lived "$L" "$(_md_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _md_sandbox
  local s0="$SB_TMP/snap0" s1="$SB_TMP/snap1" d="$SB_WORK/modules/fab"
  mkdir -p "$d" "$SB_WORK/docs"; printf 'x\n' > "$d/f.txt"; printf 'a row\n' > "$d/g.md"; printf 'mine\n' > "$SB_WORK/docs/keep.md"
  # _fab <manifest lines…> — the fabricated module's manifest, with the header every row shares.
  _fab() { { printf 'name: fab\nversion: 0.1.0\npurpose: A fixture module.\n'; printf '%s\n' "$@"; } > "$d/module.manifest"; }
  # _row <label> <must name…> -- <manifest lines…>: refused, naming every word, a Next: line, nothing written.
  _row() {
    local label="$1" want; shift
    local names=()
    while [ "$1" != -- ]; do names+=("$1"); shift; done; shift
    _fab "$@"; _md_snap "$SB_WORK" > "$s0"
    _md_mod enable fab
    [ "$_md_rc" -eq 1 ] || cf "($label) exit $_md_rc, want 1: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
    printf '%s\n' "$_md_out" | grep '^Next:' >/dev/null || cf "($label) no Next: line"
    for want in "${names[@]}"; do
      printf '%s\n' "$_md_out" | grep -F -- "$want" >/dev/null || cf "($label) the refusal does not name '$want': $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
    done
    _md_snap "$SB_WORK" > "$s1"
    cmp -s "$s0" "$s1" || cf "($label) the refusal changed the tree: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-200)"
    if [ "$_md_rc" -eq 0 ]; then _md_mod disable fab; fi   # a row that was not refused leaves the module enabled; the next row starts clean
  }
  _row "a block host in another case" "project.md" "PROJECT.md" -- "block: project.md gates g.md"
  _row "a new file under a directory in another case" "DOCS/new.md" "docs" -- "file: f.txt -> DOCS/new.md"
  _row "a role the base set carries" "PM" "role" -- "role: PM   a seat" "file: f.txt -> docs/new.md"
  _row "a role the base set carries, in another case" "Pm" "role" -- "role: Pm   a seat" "file: f.txt -> docs/new.md"
  mkdir -p "$SB_WORK/process"; printf 'Keeper   a seat the project declared\n' > "$SB_WORK/process/ROLES"
  _row "a role process/ROLES carries" "Keeper" "role" -- "role: Keeper   a seat" "file: f.txt -> docs/new.md"
  # (control) the project's spelling and a role of its own
  _fab "block: PROJECT.md gates g.md" "role: Fabber   a seat" "file: f.txt -> docs/new.md"
  _md_mod enable fab
  [ "$_md_rc" -eq 0 ] || cf "(control) the same module spelt as the project spells it exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  [ -f "$SB_WORK/docs/new.md" ] || cf "(control) the file was not placed"
  # (control, case-sensitive) where `docs` and `Docs` are two directories, the exact spelling is the project's and enables
  _md_mod disable fab
  if [ ! -e "$SB_WORK/Docs" ]; then
    mkdir "$SB_WORK/Docs"
    if [ -d "$SB_WORK/Docs" ] && [ "$(ls -A "$SB_WORK" | grep -c '^[Dd]ocs$')" = 2 ]; then
      _fab "file: f.txt -> docs/two.md"
      _md_mod enable fab
      [ "$_md_rc" -eq 0 ] || cf "(control, case-sensitive) docs/two.md, where docs and Docs are both directories, exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
    fi
  fi
  unset -f _row _fab
  # (case-blindness) two spellings are one path only where the filesystem reads them as one: a project's `.git` found under
  # `.GIT` says so, and a directory a project made and named `.GIT` beside it, on a filesystem that tells the two apart, does not
  local cb="$SB_TMP/case-probe" ans
  rm -rf "$cb"; mkdir -p "$cb/.git"
  if [ -e "$cb/.GIT" ]; then ans=same; else mkdir -p "$cb/.GIT"; ans=apart; fi
  if ( KIT_MOD_ROOT="$cb"; . "$SB_WORK/scripts/lib/modules.sh" && _kit_mod_same_path docs/a.txt docs/A.txt ); then
    [ "$ans" = same ] || cf "(case-blindness) a directory named .GIT beside .git, on a filesystem that keeps them apart, made docs/a.txt and docs/A.txt one path"
  else
    [ "$ans" = apart ] || cf "(case-blindness) on a filesystem that reads .GIT as .git, docs/a.txt and docs/A.txt were two paths"
  fi
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE MODULE-LESS SKIP NAMES A FILE THAT IS ABSENT, AND THE SHAPE TEST READS A MANIFEST AS A FILE.
#   Operand: the two reasons the module cases give when the example module has no manifest (_md_gone_reason, _mu_example_reason), run
#   against a tree that keeps modules/example/ with its notes and setup steps and has no manifest. A reason that names a file that is
#   present there is false, and _lived_names_a_file must read a manifest as a file.
# =============================================================================
case_the_module_less_skip_reason_names_a_file_that_is_absent_and_the_shape_test_reads_a_manifest() {
  cf_reset
  local L="when a tree keeps modules/ and has deleted the manifests, the skip reason of the module cases names a file that is absent there (the manifest), not one that is present, and the shape test skp_lived applies reads a manifest as a file"
  local root fn r named n
  root="$(mktemp -d)" || { cf "(prereq) no scratch directory"; finish "$L"; return; }
  mkdir -p "$root/modules/example"
  : > "$root/modules/example/RELEASE-NOTES.md"; : > "$root/modules/example/SETUP.md"
  for fn in _md_gone_reason _mu_example_reason; do
    r="$(REAL_REPO_ROOT="$root" "$fn")"
    [ -n "$r" ] || { cf "($fn) gives no reason on a tree with no manifest"; continue; }
    _lived_names_a_file "$r" || cf "($fn) its reason names no file the shape test reads: $r"
    n=0
    for named in $(printf '%s' "$r" | grep -oE '[A-Za-z0-9_./-]+\.(md|sh|json|js|py|txt|yml|yaml|example|skeleton|template|manifest)'); do
      n=$((n + 1))
      [ ! -e "$root/$named" ] || cf "($fn) its reason names $named, which is present in the tree it judged: $r"
    done
    [ "$n" -gt 0 ] || cf "($fn) its reason names no file at all: $r"
  done
  _lived_names_a_file "modules/example/module.manifest is absent from this tree" || cf "(shape) a reason naming module.manifest is not read as naming a file"
  rm -rf "$root"
  finish "$L"
}
