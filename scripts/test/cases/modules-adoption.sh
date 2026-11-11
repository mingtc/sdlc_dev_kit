# KIT-CLASS: MIXED — self-test harness, a module on day one and through a kit upgrade. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/modules-adoption.sh — sourced by scripts/test/run.sh, never run on its own.
# kit-init.sh --with (a module enabled inside the initialization commit) and kit-upgrade.sh over an enabled
# module (its new files carried, the record kept true), both driven over the module the kit ships as its
# template (modules/example). The upgrade cases run the real kit-upgrade.sh between a project that has the
# module enabled and a copy of the kit whose module has moved on; the helpers shared with the lifecycle cases
# are in lib/modules.sh. A project that deleted modules/example/ has these cases N/A (the file named in the
# reason); the programs being absent is never N/A, because they ship with the kit.
# =============================================================================

# _mu_sha <file> — the sha256 of a file, or nothing without a tool.
_mu_sha() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" 2>/dev/null | awk '{print $1}'; fi
}
# _mu_manifest <kit dir> — <dir>/process/KIT-MANIFEST over its scripts/ and modules/, as the build writes one.
_mu_manifest() {
  local d="$1" rel
  mkdir -p "$d/process"
  printf '# KIT-CLASS: KIT — the shipped manifest (a test fixture).\n' > "$d/process/KIT-MANIFEST"
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    printf '%s  %s  %s\n' "$(_mu_sha "$d/$rel")" "$rel" "-" >> "$d/process/KIT-MANIFEST"
  done <<MU_MAN_EOF
$(cd "$d" && find scripts modules -type f | LC_ALL=C sort)
MU_MAN_EOF
}
# _mu_land <message> — commit what the sandbox holds and publish it.
_mu_land() {
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "[PM] $1" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
}
# _mu_record_sha <path> — the sha256 process/MODULES records for a file row, or nothing.
_mu_record_sha() { awk -v p="$1" '$1 == "file" && $3 == p { print $2; exit }' "$SB_WORK/process/MODULES" 2>/dev/null; }
# _mu_block_sha <path> — the same for a block row.
_mu_block_sha() { awk -v p="$1" '$1 == "block" && $3 == p { print $2; exit }' "$SB_WORK/process/MODULES" 2>/dev/null; }

# _mu_pair — SB_WORK is a project that adopted kit 0.1.0 with the example module enabled (committed, published);
# MU_NEW is a copy of the same kit, unpacked beside it, whose module the caller then moves on. The project's
# manifest lists the kit's scripts and modules as they were shipped, so the upgrade's file pass reads the module's
# disarmed files by the usual rule.
_mu_pair() {
  _md_sandbox
  MU_NEW="$SB_TMP/new-kit"; MU_ELSE="$SB_TMP/elsewhere"
  mkdir -p "$MU_ELSE" "$SB_WORK/process" "$MU_NEW/process"
  [ -z "${1:-}" ] || "$1"
  printf '0.1.0\n' > "$SB_WORK/process/KIT-VERSION"
  _mu_manifest "$SB_WORK"
  cp -R "$SB_WORK/scripts" "$MU_NEW/scripts"; cp -R "$SB_WORK/modules" "$MU_NEW/modules"
  cp "$SB_WORK/process/KIT-VERSION" "$MU_NEW/process/KIT-VERSION"
  printf '# notes\n\n## [0.2.0] — 2026-01-02\n\n### Changed\n\n- **Not an item.**\n' > "$MU_NEW/process/KIT-RELEASE-NOTES.md"
  _mu_manifest "$MU_NEW"
  _mu_land "adopt kit 0.1.0"
  for _mu_m in ${MU_ENABLE:-example}; do
    _md_mod enable "$_mu_m"
    [ "$_md_rc" -eq 0 ] || _fixture_die "_mu_pair: enabling the $_mu_m module in the fixture exited $_md_rc: $_md_out"
  done
  _mu_land "enable the module(s)"
}
# _mu_second_module <dir> <version> [blocks] — a small module of its own, `second`, in <dir>/modules: one file, release notes.
# With a third argument it also puts two blocks in PROJECT.md (slots `gates` and `extra`, a host the example module uses
# too) and a block in .gitignore, each carrying the version, so a new version rewrites all three.
_mu_second_module() {
  local m="$1/modules/second" v="$2"
  mkdir -p "$m"
  printf '# KIT-CLASS: KIT — a fixture module.\nname: second\nversion: %s\npurpose: A second fixture module.\nrelease-notes: RELEASE-NOTES.md\nfile: note.txt -> docs/second-note.txt\n' "$v" > "$m/module.manifest"
  printf 'the second module note, version %s\n' "$v" > "$m/note.txt"
  printf '# second — release notes\n\n## [%s]\n\n### Action required\n\n- **Do the second thing at %s.** A fixture entry.\n' "$v" "$v" > "$m/RELEASE-NOTES.md"
  [ -z "${3:-}" ] || {
    printf 'block: PROJECT.md gates gates.md\nblock: PROJECT.md extra extra.md\ngitignore: gitignore.txt\n' >> "$m/module.manifest"
    printf '| Gate | Your command | The contract it implements |\n|---|---|---|\n| The second gate %s | `N/A: a toy` | y |\n' "$v" > "$m/gates.md"
    printf '| Gate | Your command | The contract it implements |\n|---|---|---|\n| The second extra gate %s | `N/A: a toy` | y |\n' "$v" > "$m/extra.md"
    printf '# the second module ignores\n.second-%s/\n' "$v" > "$m/gitignore.txt"
  }
}
# _mu_shared_hosts_pre — the _mu_pair hook that gives the project `second` with blocks, and PROJECT.md the slot for the
# second of them.
_mu_shared_hosts_pre() {
  _mu_second_module "$SB_WORK" 0.5.0 blocks
  printf '<!-- KIT-MODULES:extra the second slot -->\n' >> "$SB_WORK/PROJECT.md"
}
# _mu_two_modules_pre — the _mu_pair hook that gives the project the second module before the pair is built.
_mu_two_modules_pre() { _mu_second_module "$SB_WORK" 0.5.0; }
# _mu_next_version <manifest> — the module version after the one the manifest declares (the patch number plus one), so
# a fixture that moves the module on does not depend on which version the kit ships it at.
_mu_next_version() {
  local v; v="$(sed -n 's/^version:[[:space:]]*//p' "$1" | sed -n '1p')"
  printf '%s.%s' "${v%.*}" "$(( ${v##*.} + 1 ))"
}
# _mu_new_version — the new kit's example module, moved on a version (MU_OLDVER to MU_NEWVER): a role doc, a skill, a move check and the
# gate table and cell check changed, a note file added, the PRD fragment dropped, and release notes with one Action required entry.
_mu_new_version() {
  local m="$MU_NEW/modules/example"
  MU_OLDVER="$(sed -n 's/^version:[[:space:]]*//p' "$m/module.manifest" | sed -n '1p')"; MU_NEWVER="$(_mu_next_version "$m/module.manifest")"
  # the new file is the first thing the module places, so a run killed after it still has writes to make
  sed -e "s/^version: .*/version: $MU_NEWVER/" -e '/^fragment: PRD /d' "$m/module.manifest" \
    | awk '{ print } /^purpose:/ { print "file: _claude/skills/example-skill/NOTES.md -> .claude/skills/example-skill/NOTES.md" }' > "$m/module.manifest.new" && mv "$m/module.manifest.new" "$m/module.manifest"
  printf 'A line the new version adds to the role doc.\n' >> "$m/_claude/roles/example.md"
  printf 'A line the new version adds to the skill.\n' >> "$m/_claude/skills/example-skill/SKILL.md"
  printf '# a comment the new version adds\n' >> "$m/move-check.d/50-example.sh"
  printf '# a comment the new version adds\n' >> "$m/qa-cell.d/50-example.sh"
  sed -e 's/(a toy)/(a revised toy)/' "$m/gates.md" > "$m/gates.md.new" && mv "$m/gates.md.new" "$m/gates.md"
  printf 'A note the new version adds.\n' > "$m/_claude/skills/example-skill/NOTES.md"
  cat > "$m/RELEASE-NOTES.md" <<MU_NOTES_EOF
# The example module — release notes

## [$MU_NEWVER] — 2026-01-02

### Action required

- **Take the sign-off line.** Add \`example-sign-off: pending\` to every open card.

### Changed

- **Not an item: under Changed.**

## [$MU_OLDVER] — 2026-01-01

### Action required

- **Old item.** Applied by any module at that version.
MU_NOTES_EOF
  printf '0.2.0\n' > "$MU_NEW/process/KIT-VERSION"
  _mu_manifest "$MU_NEW"
}
# _mu_project_edits — what the project did to the module's files since it enabled them.
_mu_project_edits() {
  printf 'the project own line\n' >> "$SB_WORK/.claude/skills/example-skill/SKILL.md"
  printf '# the project own comment\n' >> "$SB_WORK/scripts/check-board.d/50-example.sh"
  rm -f "$SB_WORK/process/fragments.d/ISSUE/example.body-end" "$SB_WORK/scripts/move-check.d/in_progress/50-example.sh"
}
# _mu_up <project> [VAR=value…] — the NEW kit's kit-upgrade.sh, run from a directory outside both trees; the
# status is left in _mu_rc and the output in _mu_out. Records go to a directory emptied first.
_mu_rc=0; _mu_out=""
_mu_up() {
  local proj="$1"; shift
  rm -rf "$SB_TMP/up-records"; _mu_rc=0
  _mu_out="$( cd "$MU_ELSE" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/up-records" KILL_PID_FILE="$SB_TMP/kill-pid" "$@" bash -c 'echo $$ > "$KILL_PID_FILE"; exec "$@"' _ "$MU_NEW/scripts/kit-upgrade.sh" --into "$proj" 2>&1 </dev/null )" || _mu_rc=$?
}
_mu_recs() { cat "$SB_TMP"/up-records/*.tsv 2>/dev/null | grep -c "refusal=$1" || true; }
# _mu_flat — the last output on one line, for a failure message.
_mu_flat() { printf '%s' "$_mu_out" | tr '\n' '|' | cut -c1-"${1:-300}"; }
# _mu_example_as_shipped — status 0 when every file of modules/example is the copy process/KIT-MANIFEST records (or the
# tree has no manifest to say otherwise): a project that changed or upgraded the module has no shipped operand.
_mu_example_as_shipped() {
  local m="$REAL_REPO_ROOT/process/KIT-MANIFEST" h rel
  [ -f "$m" ] || return 0
  while read -r h rel; do
    case "$rel" in modules/example/*) ;; *) continue ;; esac
    [ "$(_mu_sha "$REAL_REPO_ROOT/$rel")" = "$h" ] || return 1   # return-class: predicate
  done <<MU_SHIPPED_EOF
$(awk -F'  ' '!/^#/ && NF >= 2 { print $1 " " $2 }' "$m")
MU_SHIPPED_EOF
  return 0
}
# _mu_example_reason — why the example module cannot be the subject of a case here, or nothing. Each reason names a file
# of the module by a name skp_lived's shape test reads.
_mu_example_reason() {
  if [ ! -f "$REAL_REPO_ROOT/modules/example/module.manifest" ]; then
    printf 'modules/example/RELEASE-NOTES.md is absent from this tree'
  elif ! _mu_example_as_shipped; then
    printf 'modules/example/RELEASE-NOTES.md or another file of modules/example is not the copy process/KIT-MANIFEST records (this project changed or upgraded the module), so the fixture that moves it on has no shipped operand'
  fi
  return 0
}
# _mu_nosha_path — a directory of the tools the programs use, as links to the machine's own, without shasum and
# sha256sum: a PATH on which no sha256 tool exists. Printed.
_mu_nosha_path() {
  local d="$SB_TMP/nosha" t
  mkdir -p "$d"
  for t in bash env awk sed grep egrep cmp cat tr head tail sort uniq mktemp rm mkdir cp mv dirname basename git chmod ls find wc cut date sleep ps readlink ln diff comm touch tee xargs sh perl od expr test seq id stat; do
    if [ -x "$(command -v "$t" 2>/dev/null)" ]; then ln -sf "$(command -v "$t")" "$d/$t"; fi
  done
  printf '%s' "$d"
}
# _mu_clone_tree <dir> — the tree under test as it stands, working-tree changes included, as a git repository of its own.
_mu_clone_tree() {
  local d="$1"
  git clone -q "$REAL_REPO_ROOT" "$d" 2>/dev/null || return 1   # return-class: predicate
  ( cd "$REAL_REPO_ROOT" && tar -cf - --exclude=.git . ) | ( cd "$d" && tar -xf - ) || return 1   # return-class: predicate
  if [ -n "$(git -C "$d" status --porcelain 2>/dev/null)" ]; then
    git -C "$d" add -A >/dev/null 2>&1
    MSG_OK=1 git -C "$d" -c user.email=s@k.invalid -c user.name=s -c commit.gpgsign=false commit -q -m "the tree as it stands" >/dev/null 2>&1 || return 1   # return-class: predicate
  fi
  return 0
}
# _mu_subject_ok — the programs under test ship; their absence is a failure, never an N/A.
_mu_subject_ok() {
  local f
  for f in scripts/kit-upgrade.sh scripts/kit-init.sh scripts/module.sh scripts/lib/modules.sh scripts/lib/marker-block.sh scripts/lib/exit-trap.sh; do
    [ -f "$REAL_REPO_ROOT/$f" ] || { cf "(prereq) $f is absent from the tree under test"; return 1; }
  done
}

# =============================================================================
# CASE — kit-init --with ENABLES A MODULE INSIDE THE INITIALIZATION COMMIT.
#   Operand: the commit kit-init makes, read back from git. The module's role doc, skill, record, table
#   and ignore block are in THAT commit (not left beside it), carry this project's prefix and name, and
#   the trunk has them. The self-check that follows mints a card and moves it through the module's own move
#   check, so the fragment the module adds is in the card. Without --with nothing is enabled. A name given
#   twice is enabled once.
# =============================================================================
case_kit_init_with_enables_a_module_inside_the_initialization_commit() {
  cf_reset
  local L="kit-init.sh --with example enables the module after the stamp and before the initialization commit, so process/MODULES, the module's files and its table and ignore block are in that commit and on the trunk, stamped with this project's values, a name given twice is enabled once, the self-check passes through the module's move check, and a run without --with enables nothing"
  if ! has_kit_init; then skp "$L" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mu_subject_ok || { finish "$L"; return; }
  local out rc sha f n

  # (control) the same sandbox without --with: nothing is enabled.
  _mu_ki_sandbox
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(control) kit-init without --with exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  [ -e "$SB_WORK/process/MODULES" ] && cf "(control) a run without --with left a record of enabled modules"
  [ -e "$SB_WORK/.claude/roles/example.md" ] && cf "(control) a run without --with placed the example module's role doc"
  teardown

  # the module also places a file in docs/, which no part of kit-init's own commit names: it joins through the record
  _mu_ki_sandbox 'file: gitignore.txt -> docs/example-note.txt'
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" --with example --with example 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) kit-init --with example exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep 'kit-init COMPLETE and PROVEN' >/dev/null || cf "(a) no COMPLETE-and-PROVEN line: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep '✗' >/dev/null && cf "(a) a self-check assertion failed with the module enabled: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -F 'Nothing is committed' >/dev/null && cf "(a) module.sh's own 'Nothing is committed' note reached the output of a run that commits next"
  printf '%s\n' "$out" | grep -F 'modules enabled: example (recorded in process/MODULES' >/dev/null || cf "(a) the run does not say it enabled example once: $(printf '%s' "$out" | grep -F 'modules enabled' | head -1)"
  n="$(grep -c '^module example ' "$SB_WORK/process/MODULES" 2>/dev/null || true)"
  [ "$n" = 1 ] || cf "(a) process/MODULES records the module $n time(s), want once (the name was given twice)"

  # (b) everything the module placed is in the initialization commit, and on the trunk.
  local init
  init="$(git -C "$SB_WORK" log --format='%H %s' | awk '/kit-init: initialize the kit/ { print $1; exit }')"
  [ -n "$init" ] || { cf "(b) no initialization commit in the log"; finish "$L"; teardown; return; }
  for f in process/MODULES .claude/roles/example.md .claude/skills/example-skill/SKILL.md process/roles.d/example docs/example-note.txt \
           process/evidence-kinds.d/example scripts/check-board.d/50-example.sh scripts/move-check.d/in_progress/50-example.sh; do
    git -C "$SB_WORK" cat-file -e "$init:$f" 2>/dev/null || cf "(b) $f is not in the initialization commit"
    git -C "$SB_WORK" diff --quiet "$init" HEAD -- "$f" 2>/dev/null || cf "(b) $f changed after the initialization commit"
    origin_has_path "$f" || cf "(b) $f did not reach the trunk"
  done
  git -C "$SB_WORK" show "$init:PROJECT.md" 2>/dev/null | grep -F '<!-- KIT-MODULE:example:gates BEGIN -->' >/dev/null || cf "(b) the module's table is not in PROJECT.md as the initialization commit holds it"
  git -C "$SB_WORK" show "$init:.gitignore" 2>/dev/null | grep -F '# KIT-MODULE:example:gitignore BEGIN' >/dev/null || cf "(b) the module's ignore block is not in .gitignore as the initialization commit holds it"
  [ -z "$(git -C "$SB_WORK" status --porcelain --untracked-files=all 2>/dev/null)" ] || cf "(b) the run left uncommitted paths: $(git -C "$SB_WORK" status --porcelain --untracked-files=all | tr '\n' '|' | cut -c1-200)"

  # (c) the module's files carry THIS project's values: the stamp came first.
  grep -F '<PREFIX>' "$SB_WORK/.claude/roles/example.md" >/dev/null && cf "(c) the module's role doc still carries the <PREFIX> blank"
  grep -F 'SBX-NNN' "$SB_WORK/.claude/roles/example.md" >/dev/null || cf "(c) the module's role doc does not carry this project's prefix"
  sha="$(_mu_sha "$SB_WORK/.claude/roles/example.md")"
  grep -E "^file $sha \.claude/roles/example\.md\$" "$SB_WORK/process/MODULES" >/dev/null || cf "(c) the record's sha256 for the role doc is not the file's"

  # (d) the module is live, not just present: the card the self-check minted carried the fragment the move check wants.
  printf '%s\n' "$out" | grep -F 'moved SBX-000 → progress/in_progress/' >/dev/null || cf "(d) the self-check's move through the module's move check did not pass: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  "$SB_WORK/scripts/module.sh" status example > "$SB_TMP/status.out" 2>&1
  grep -E 'edited|missing' "$SB_TMP/status.out" >/dev/null && cf "(d) status shows an edited or missing thing straight after kit-init: $(tr '\n' '|' < "$SB_TMP/status.out" | cut -c1-200)"
  "$SB_WORK/scripts/kit-init.sh" --help 2>&1 | grep -F -- '--with' >/dev/null || cf "(e) kit-init --help does not describe --with"

  finish "$L"
  teardown
}

# _mu_ki_sandbox — a day-one sandbox that also holds the modules and a PROJECT.md with the blanks kit-init fills and
# the gate table's slot: kit_init_sandbox does not copy modules/, and a module's table needs a host.
_mu_ki_sandbox() {
  kit_init_sandbox
  # a tree with the module enabled carries its role doc in the roles kit_init_sandbox copies: day one has none
  rm -f "$SB_WORK/.claude/roles/example.md"
  if [ -d "$REAL_REPO_ROOT/modules" ]; then cp -R "$REAL_REPO_ROOT/modules" "$SB_WORK/modules"; else mkdir -p "$SB_WORK/modules"; fi   # DELETE-IF-UNUSED
  [ -z "${1:-}" ] || printf '%s\n' "$1" >> "$SB_WORK/modules/example/module.manifest"
  # fixture modules that place a path kit-init itself writes: the Claude Code settings it copies under --enable-hooks, and progress.md
  mkdir -p "$SB_WORK/modules/hooky" "$SB_WORK/modules/notey" "$SB_WORK/.claude"
  printf 'name: hooky\nversion: 0.1.0\npurpose: A fixture module that places the settings file.\nfile: h.json -> .claude/settings.json\n' > "$SB_WORK/modules/hooky/module.manifest"
  printf '{"hooks": {}}\n' > "$SB_WORK/modules/hooky/h.json"
  printf 'name: notey\nversion: 0.1.0\npurpose: A fixture module that places the progress log.\nfile: n.md -> progress.md\n' > "$SB_WORK/modules/notey/module.manifest"
  printf '# a progress log a module placed\n' > "$SB_WORK/modules/notey/n.md"
  # fixture modules that place one path between them (ca and cb), or two spellings of it (ca and cc), and one that spells
  # the settings file kit-init copies in another case
  local c
  for c in "ca docs/same.txt" "cb docs/same.txt" "cc docs/SAME.txt" "hookycase .claude/Settings.json"; do
    mkdir -p "$SB_WORK/modules/${c%% *}"
    printf 'name: %s\nversion: 0.1.0\npurpose: A fixture module that places %s.\nfile: f.txt -> %s\n' "${c%% *}" "${c#* }" "${c#* }" > "$SB_WORK/modules/${c%% *}/module.manifest"
    printf 'from %s\n' "${c%% *}" > "$SB_WORK/modules/${c%% *}/f.txt"
  done
  printf '{}\n' > "$SB_WORK/.claude/settings.json.example"
  printf '# <project name> — PROJECT.md (sandbox)\n\nIssue ids are <PREFIX>-NNN on <trunk>.\n\n| Gate | Your command | The contract it implements |\n|---|---|---|\n| g | `x` | y |\n\n<!-- KIT-MODULES:gates the slot -->\n\ntail\n' > "$SB_WORK/PROJECT.md"
  publish_sandbox
}

# =============================================================================
# CASE — kit-init --with REFUSES BEFORE IT WRITES, AND NAMES WHAT STOPS IT.
#   Each row is a refusal enable would make, or a malformed name, met in the preflight: the exit status is 1,
#   NOTHING WAS WRITTEN is true (the tree is byte-equal to the one before, no stamp, no record), and the line
#   names the module and what is in its way. The last row is the one the preflight cannot see: an enable that
#   fails after the stamp names the hand finish, and that finish works.
# =============================================================================
case_kit_init_with_refuses_before_it_writes_and_names_what_stops_it() {
  cf_reset
  local L="kit-init.sh --with refuses in the preflight, writing nothing and exiting 1, an unknown module, a stray comma, a path the module would place that exists, a reader this copy of the kit lacks, a block host with no slot and a placed path git ignores, each naming the module and the cause; an enable that fails after the stamp refuses with module-enable-after-stamp and a hand finish that works"
  if ! has_kit_init; then skp "$L" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mu_subject_ok || { finish "$L"; return; }
  _mu_ki_sandbox
  local s0="$SB_TMP/snap0" s1="$SB_TMP/snap1" out rc ci=""
  [ ! -e "$SB_WORK/.GIT" ] || ci=1

  _row() {  # <label> <must name…> -- <kit-init args…>: refused, nothing written, every word named
    local label="$1" want; shift
    local names=()
    while [ "$1" != -- ]; do names+=("$1"); shift; done; shift
    _md_snap "$SB_WORK" > "$s0"; rm -rf "$SB_TMP/records"
    rc=0; out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/records" ./scripts/kit-init.sh --prefix SBX --trunk "$SB_TRUNK" "$@" 2>&1 </dev/null )" || rc=$?
    [ "$rc" -eq 1 ] || cf "($label) exit $rc, want 1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
    printf '%s\n' "$out" | grep -F 'NOTHING WAS WRITTEN' >/dev/null || cf "($label) the refusal does not say NOTHING WAS WRITTEN"
    printf '%s\n' "$out" | grep '^Next:' >/dev/null || cf "($label) the refusal carries no Next: line"
    for want in "${names[@]}"; do
      printf '%s\n' "$out" | grep -F -- "$want" >/dev/null || cf "($label) the refusal does not name '$want': $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
    done
    _md_snap "$SB_WORK" > "$s1"
    cmp -s "$s0" "$s1" || cf "($label) the refused run changed the tree: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-200)"
    grep -q 'Stamped by scripts/kit-init.sh' "$SB_WORK/scripts/config.sh" && cf "($label) the refused run stamped scripts/config.sh"
    [ "$(cat "$SB_TMP"/records/*.tsv 2>/dev/null | grep -c 'refusal=preflight-unmet' || true)" -ge 1 ] || cf "($label) no refusal=preflight-unmet record"
  }
  _row "a module the kit does not ship" "--with nope" "no module 'nope'" -- --with nope
  _row "a stray comma" "stray comma" -- --with example,
  _row "a lone comma" "stray comma" -- --with ,
  _row "one good name and one bad" "--with nope" -- --with example,nope
  [ "$(printf '%s\n' "$out" | grep -c -- '--with example:')" = 0 ] || cf "(one good name and one bad) the refusal names the module that is fine"

  # a library enable runs on is missing from this copy of the kit
  git -C "$SB_WORK" rm -q scripts/lib/marker-block.sh >/dev/null 2>&1; sbcommit -q -m "[PM] marker-block.sh removed" >/dev/null 2>&1
  _row "a library that is missing" "--with" "scripts/lib/marker-block.sh" "Restore them" -- --with example
  git -C "$SB_WORK" reset -q --hard HEAD~1 >/dev/null 2>&1

  # no sha256 tool: enable records one per file
  _md_snap "$SB_WORK" > "$s0"; rc=0
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/records" PATH="$(_mu_nosha_path)" ./scripts/kit-init.sh --prefix SBX --trunk "$SB_TRUNK" --with example 2>&1 </dev/null )" || rc=$?
  [ "$rc" -eq 1 ] || cf "(no sha256 tool) exit $rc, want 1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$out" | grep -F 'no sha256 tool' >/dev/null || cf "(no sha256 tool) the refusal does not name the missing tool: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$out" | grep -F 'NOTHING WAS WRITTEN' >/dev/null || cf "(no sha256 tool) the refusal does not say NOTHING WAS WRITTEN"
  _md_snap "$SB_WORK" > "$s1"; cmp -s "$s0" "$s1" || cf "(no sha256 tool) the refused run changed the tree"

  # a path the module would place exists already
  mkdir -p "$SB_WORK/.claude/roles"; printf 'the project own\n' > "$SB_WORK/.claude/roles/example.md"
  _row "a path that exists" "--with example" ".claude/roles/example.md" -- --with example
  rm -f "$SB_WORK/.claude/roles/example.md"

  # a placed path git ignores: the initialization commit would leave it out
  printf '.claude/roles/example.md\n' > "$SB_WORK/.gitignore"
  _row "an ignored path" "--with example" "ignored by git" ".claude/roles/example.md" -- --with example
  rm -f "$SB_WORK/.gitignore"

  # a reader this project's copy of the kit lacks: the hook would not accept the module's role
  sed -i.bak 's/kit_role_extend/kit_role_unread/g' "$SB_WORK/scripts/githooks/commit-msg"; rm -f "$SB_WORK/scripts/githooks/commit-msg.bak"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m "[PM] a hook that does not read the role layer" >/dev/null 2>&1
  _row "a reader that is missing" "--with example" "scripts/githooks/commit-msg" "kit_role_extend" -- --with example
  git -C "$SB_WORK" reset -q --hard HEAD~1 >/dev/null 2>&1

  # a block host with no slot line
  sed -i.bak '/KIT-MODULES:gates/d' "$SB_WORK/PROJECT.md"; rm -f "$SB_WORK/PROJECT.md.bak"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m "[PM] a PROJECT.md with no slot" >/dev/null 2>&1
  _row "a block host with no slot" "--with example" "PROJECT.md" "KIT-MODULES:gates" -- --with example
  git -C "$SB_WORK" reset -q --hard HEAD~1 >/dev/null 2>&1
  # a path kit-init itself writes between the preflight and the enable
  _row "a path kit-init copies (--enable-hooks)" "--with hooky" ".claude/settings.json" "kit-init writes it" -- --enable-hooks --with hooky
  _row "a path kit-init creates (progress.md)" "--with notey" "progress.md" "kit-init writes it" -- --with notey
  _row "two modules that place one path" "--with ca,cb" "module ca places docs/same.txt" "module cb places docs/same.txt" -- --with ca,cb
  # whether docs/SAME.txt is docs/same.txt is the filesystem's to say: the top level's `.git` is found under `.GIT` where it reads case as one
  if [ -n "$ci" ]; then
    _row "two modules that place one path in two cases" "--with ca,cc" "module ca places docs/same.txt" "module cc places docs/SAME.txt" -- --with ca,cc
    _row "a path kit-init copies, spelt in another case" "--with hookycase" ".claude/Settings.json" "kit-init writes it" -- --enable-hooks --with hookycase
  fi
  unset -f _row
  teardown

  # (control) where case tells paths apart, those spellings are different files and day one places both
  if [ -z "$ci" ]; then
    _mu_ki_sandbox
    rc=0; out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" --enable-hooks --with ca,cc,hookycase 2>&1)" || rc=$?
    [ "$rc" -eq 0 ] || cf "(control, case-sensitive) modules whose paths differ only in case exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
    [ -f "$SB_WORK/docs/same.txt" ] && [ -f "$SB_WORK/docs/SAME.txt" ] || cf "(control, case-sensitive) the two spellings were not both placed"
    teardown
  fi

  # (control) the same module without the flag that makes kit-init write its path is enabled
  _mu_ki_sandbox
  rc=0; out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" --with hooky 2>&1)" || rc=$?
  [ "$rc" -eq 0 ] || cf "(control) --with hooky without --enable-hooks exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  [ -f "$SB_WORK/.claude/settings.json" ] || cf "(control) the module's settings file was not placed"
  teardown

  # (last) an enable that fails AFTER the stamp: a write the preflight cannot foresee.
  _mu_ki_sandbox
  mkdir -p "$SB_TMP/shimfail"
  cat > "$SB_TMP/shimfail/mv" <<'MU_FAIL_EOF'
#!/bin/bash
case "${@: -1}" in *.claude/roles/example.md) echo "mv: simulated write failure" >&2; exit 1 ;; esac
exec /bin/mv "$@"
MU_FAIL_EOF
  chmod +x "$SB_TMP/shimfail/mv"
  rm -rf "$SB_TMP/records"; rc=0
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/records" PATH="$SB_TMP/shimfail:$PATH" ./scripts/kit-init.sh --prefix SBX --trunk "$SB_TRUNK" --with example 2>&1 </dev/null )" || rc=$?
  [ "$rc" -eq 1 ] || cf "(late) exit $rc, want 1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  [ "$(cat "$SB_TMP"/records/*.tsv 2>/dev/null | grep -c 'refusal=module-enable-after-stamp' || true)" -ge 1 ] || cf "(late) no refusal=module-enable-after-stamp record"
  printf '%s\n' "$out" | grep -F 'the tree is stamped and not committed' >/dev/null || cf "(late) the refusal does not say the tree is stamped and not committed"
  printf '%s\n' "$out" | grep -F 'NOTHING WAS CHANGED' >/dev/null && cf "(late) module.sh's NOTHING WAS CHANGED is relayed above a stamped tree: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -F './scripts/module.sh enable example' >/dev/null || cf "(late) the refusal does not name the hand finish"
  [ -e "$SB_WORK/process/MODULES" ] && cf "(late) a record remains after the failed enable: $(tr '\n' '|' < "$SB_WORK/process/MODULES" | cut -c1-160)"
  grep -q 'Stamped by scripts/kit-init.sh' "$SB_WORK/scripts/config.sh" || cf "(late) the premise failed: the run did not reach the stamp"
  # the finish the refusal names, with the cause gone, and the commit it asks for
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || cf "(late) the hand finish the refusal names exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-200)"
  [ -f "$SB_WORK/.claude/roles/example.md" ] || cf "(late) the hand finish did not place the module"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — kit-upgrade.sh CARRIES AN ENABLED MODULE'S NEW VERSION AND KEEPS THE RECORD TRUE.
#   Pins module-lifecycle.md § 2's upgrade invariant, one lettered assertion per row of it: (a) replaced as enable
#   wrote it, (b) a block, (c) newly placed, (d) edited by both, (e) edited by the project alone, (f) deleted by the
#   project, (g) no longer placed, (h)-(j) the record, the checklist, nothing committed, (k)-(l) status and disable
#   afterwards. The operand is a project with the example module enabled and a copy of the kit whose module moved on.
# =============================================================================
case_kit_upgrade_carries_an_enabled_modules_new_version_and_keeps_the_record_true() {
  cf_reset
  local L="kit-upgrade.sh replaces the placed files and block an enabled module's new version changes where the project left them as enable wrote them, writes a file the module now places, keeps and stages one the project edited that the module changed, leaves a project's deletion and a project's edit the module did not touch, lists a file the module no longer places without deleting it, raises the module's own newer Action required entries, moves process/MODULES with the files, commits nothing, and disable afterwards leaves only what the project edited"
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mu_subject_ok || { finish "$L"; return; }
  _mu_pair
  _mu_project_edits; _mu_land "the project's edits to the module"
  _mu_new_version
  local head0 role0 skill_mine arm_mine pj0 st cl="$SB_WORK/process/UPGRADE-CHECKLIST.md" f want
  head0="$(git -C "$SB_WORK" rev-parse HEAD)"
  role0="$(cat "$SB_WORK/.claude/roles/example.md")"
  skill_mine="$(cat "$SB_WORK/.claude/skills/example-skill/SKILL.md")"; arm_mine="$(cat "$SB_WORK/scripts/check-board.d/50-example.sh")"
  pj0="$(cat "$SB_WORK/PROJECT.md")"
  st="$SB_WORK/.kit-upgrade/modules/example"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || { cf "the upgrade exited $_mu_rc: $(_mu_flat)"; finish "$L"; teardown; return; }
  printf '%s\n' "$_mu_out" | grep -F 'enabled modules (example): written 4, to merge 2, no longer placed 1, checklist items 1' >/dev/null \
    || cf "(summary) the run does not report the module's findings as written 4, to merge 2, no longer placed 1, checklist items 1: $(_mu_flat 400)"

  # (a) as enable wrote it: replaced.
  [ "$(cat "$SB_WORK/.claude/roles/example.md")" = "$role0
A line the new version adds to the role doc." ] || cf "(a) the role doc, as enable wrote it, was not replaced by the new version"
  [ "$(_mu_record_sha .claude/roles/example.md)" = "$(_mu_sha "$SB_WORK/.claude/roles/example.md")" ] || cf "(a) the record's sha256 for the replaced role doc is not the file's"
  [ "$(tail -1 "$SB_WORK/scripts/qa-cell.d/example-note/50-example.sh")" = "# a comment the new version adds" ] || cf "(a) the cell check, as enable wrote it, was not replaced by the new version"
  [ -x "$SB_WORK/scripts/qa-cell.d/example-note/50-example.sh" ] || cf "(a) the replaced cell check lost its executable bit"
  [ "$(_mu_record_sha scripts/qa-cell.d/example-note/50-example.sh)" = "$(_mu_sha "$SB_WORK/scripts/qa-cell.d/example-note/50-example.sh")" ] || cf "(a) the record's sha256 for the replaced cell check is not the file's"
  # (b) a block as enable wrote it: replaced, the rest of the host as it was.
  grep -F 'a revised toy' "$SB_WORK/PROJECT.md" >/dev/null || cf "(b) the module's table in PROJECT.md was not replaced"
  [ "$(printf '%s\n' "$pj0" | sed -e '/KIT-MODULE:example:gates BEGIN/,/KIT-MODULE:example:gates END/d')" = "$(sed -e '/KIT-MODULE:example:gates BEGIN/,/KIT-MODULE:example:gates END/d' "$SB_WORK/PROJECT.md")" ] \
    || cf "(b) PROJECT.md changed outside the module's markers"
  # (c) a file the module now places: written, recorded.
  [ "$(cat "$SB_WORK/.claude/skills/example-skill/NOTES.md" 2>/dev/null)" = "A note the new version adds." ] || cf "(c) the file the module now places was not written"
  [ -n "$(_mu_record_sha .claude/skills/example-skill/NOTES.md)" ] || cf "(c) the file the module now places is not recorded"
  # (d) edited by the project and changed by the module: kept, staged, recorded at the new copy.
  [ "$(cat "$SB_WORK/.claude/skills/example-skill/SKILL.md")" = "$skill_mine" ] || cf "(d) the skill the project edited was OVERWRITTEN"
  [ "$(cat "$st/_claude/skills/example-skill/SKILL.md.kit-new" 2>/dev/null | tail -1)" = "A line the new version adds to the skill." ] || cf "(d) the module's new skill is not staged at .kit-upgrade/modules/example/_claude/skills/example-skill/SKILL.md.kit-new"
  [ "$(_mu_record_sha .claude/skills/example-skill/SKILL.md)" = "$(_mu_sha "$st/_claude/skills/example-skill/SKILL.md.kit-new")" ] || cf "(d) the record does not move the edited skill's row to the module's new copy"
  # (e) edited by the project, unchanged by the module: kept, no item, the record as it was.
  [ "$(cat "$SB_WORK/scripts/check-board.d/50-example.sh")" = "$arm_mine" ] || cf "(e) the arm the project edited was changed"
  [ ! -e "$st/scripts/check-board.d/50-example.sh.kit-new" ] || cf "(e) a file the module did not change was staged for merging"
  # (f) deleted by the project, unchanged by the module: stays deleted. Deleted and changed: stays deleted, staged.
  [ ! -e "$SB_WORK/process/fragments.d/ISSUE/example.body-end" ] || cf "(f) a fragment the project deleted, which the module did not change, came back"
  [ ! -e "$SB_WORK/scripts/move-check.d/in_progress/50-example.sh" ] || cf "(f) a move check the project deleted came back"
  [ -f "$st/scripts/move-check.d/in_progress/50-example.sh.kit-new" ] || cf "(f) the changed move check the project deleted is not staged"
  # (g) no longer placed: listed, never deleted, still recorded.
  [ -f "$SB_WORK/process/fragments.d/PRD/example.slot-story-fields" ] || cf "(g) the PRD fragment the module no longer places was DELETED"
  [ -n "$(_mu_record_sha process/fragments.d/PRD/example.slot-story-fields)" ] || cf "(g) the record dropped the row of the file the module no longer places, so disable cannot take it"
  # the record
  grep -F -x "module example $MU_NEWVER" "$SB_WORK/process/MODULES" >/dev/null || cf "(h) process/MODULES does not record the module at $MU_NEWVER"
  # the checklist
  if [ ! -f "$cl" ]; then cf "(i) no process/UPGRADE-CHECKLIST.md was written"; else
    for want in "module example, Action required, [$MU_NEWVER] item 1: Take the sign-off line." \
                'merge .claude/skills/example-skill/SKILL.md — module example: this project changed it, and so did the module' \
                'merge scripts/move-check.d/in_progress/50-example.sh — module example: this project removed it, and the module changed it' \
                'removed upstream: process/fragments.d/PRD/example.slot-story-fields — module example'; do
      grep -F -- "$want" "$cl" | grep '^- \[ \] ' >/dev/null || cf "(i) no unmarked item carries '$want'"
    done
    grep -F 'Old item' "$cl" >/dev/null && cf "(i) an item carries the entry of the version the module already had"
    grep -F 'Not an item' "$cl" >/dev/null && cf "(i) an item carries an entry that is not under Action required"
  fi
  [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$head0" ] || cf "(j) the upgrade COMMITTED"
  [ "$(cat "$SB_WORK/process/KIT-VERSION")" = 0.1.0 ] || cf "(j) the first run stamped process/KIT-VERSION"
  # status tells the truth, and disable takes back exactly what is still the module's.
  _md_mod status example
  printf '%s\n' "$_md_out" | grep -E '^  edited +\.claude/skills/example-skill/SKILL\.md' >/dev/null || cf "(k) status does not show the edited skill as edited"
  printf '%s\n' "$_md_out" | grep -E '^  edited +scripts/check-board\.d/50-example\.sh' >/dev/null || cf "(k) status does not show the edited arm as edited"
  printf '%s\n' "$_md_out" | grep -E '^  intact +\.claude/roles/example\.md' >/dev/null || cf "(k) status does not show the replaced role doc as intact"
  _md_mod disable example
  [ "$_md_rc" -eq 0 ] || cf "(l) disable exited $_md_rc: $_md_out"
  for f in .claude/roles/example.md .claude/skills/example-skill/NOTES.md process/fragments.d/PRD/example.slot-story-fields scripts/qa-cell.d/example-note/50-example.sh process/roles.d/example; do
    [ ! -e "$SB_WORK/$f" ] || cf "(l) disable left $f, which is still as the module wrote it"
  done
  [ -f "$SB_WORK/.claude/skills/example-skill/SKILL.md" ] && [ -f "$SB_WORK/scripts/check-board.d/50-example.sh" ] || cf "(l) disable deleted a file the project edited"
  grep -F 'KIT-MODULE:example:gates' "$SB_WORK/PROJECT.md" >/dev/null && cf "(l) disable left the module's table in PROJECT.md"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — AN UPGRADE WITH NOTHING NEW FOR AN ENABLED MODULE CHANGES NOTHING OF ITS, AND ONE WITH SOMETHING IS NEVER "NOTHING TO DO".
#   (a) the same kit again: "Nothing to do", the tree byte-equal. (b) a newer kit whose module is the same: the
#   record is not rewritten at all (its inode is the same), no module item, no staged copy. (c) the same kit version
#   with the project's stamp changed since enable, so the module's file renders differently: the file is written.
#   (d) the same, with the file edited by the project too: a merge item, not "Nothing to do".
# =============================================================================
case_kit_upgrade_with_nothing_new_for_an_enabled_module_changes_nothing() {
  cf_reset
  local L="kit-upgrade.sh over a project whose enabled module the new kit has not changed writes nothing for it: the same kit again prints that there is nothing to do and leaves the tree byte-equal, and a newer kit leaves process/MODULES unwritten and raises no module item; a module file that renders differently under the same kit version is still carried (written, or a merge item) and never reported as nothing to do"
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mu_subject_ok || { finish "$L"; return; }
  _mu_pair
  local s0="$SB_TMP/snap0" s1="$SB_TMP/snap1" rec0 ino0
  _md_snap "$SB_WORK" > "$s0"; rec0="$(cat "$SB_WORK/process/MODULES")"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(a) the upgrade exited $_mu_rc: $(_mu_flat)"
  printf '%s\n' "$_mu_out" | grep -F 'already runs kit 0.1.0' >/dev/null || cf "(a) the run does not say there is nothing to do: $(_mu_flat)"
  _md_snap "$SB_WORK" > "$s1"
  cmp -s "$s0" "$s1" || cf "(a) the tree changed: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-240)"

  printf '0.1.1\n' > "$MU_NEW/process/KIT-VERSION"
  ino0="$(ls -i "$SB_WORK/process/MODULES" | awk '{print $1}')"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(b) the upgrade to a newer kit exited $_mu_rc: $(_mu_flat)"
  [ "$rec0" = "$(cat "$SB_WORK/process/MODULES")" ] || cf "(b) process/MODULES changed though the module did not"
  [ "$ino0" = "$(ls -i "$SB_WORK/process/MODULES" | awk '{print $1}')" ] || cf "(b) process/MODULES was rewritten though the module did not change"
  grep -F 'module example' "$SB_WORK/process/UPGRADE-CHECKLIST.md" 2>/dev/null | grep '^- \[' >/dev/null && cf "(b) the checklist carries a module item though the module did not change"
  [ ! -e "$SB_WORK/.kit-upgrade/modules" ] || cf "(b) a staged copy exists though the module did not change: $(find "$SB_WORK/.kit-upgrade/modules" -type f | tr '\n' ' ')"
  printf '%s\n' "$_mu_out" | grep -F 'enabled modules (example): written 0, to merge 0, no longer placed 0, checklist items 0' >/dev/null || cf "(b) the summary does not report the module as untouched: $(_mu_flat 400)"
  teardown

  # (c) the same kit version, but the project's stamp has changed since enable: the module's files render differently.
  _mu_pair
  sed -i.bak "s/prefix $SB_PREFIX,/prefix ZZQ,/" "$SB_WORK/scripts/config.sh"; rm -f "$SB_WORK/scripts/config.sh.bak"
  grep -F 'prefix ZZQ,' "$SB_WORK/scripts/config.sh" >/dev/null || _fixture_die "${FUNCNAME[0]}: the stamp was not changed in the fixture."
  _mu_land "the stamp changes"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(c) the upgrade exited $_mu_rc: $(_mu_flat)"
  printf '%s\n' "$_mu_out" | grep -F 'Nothing to do' >/dev/null && cf "(c) a module file that renders differently under the same kit version was reported as nothing to do"
  grep -F 'ZZQ-NNN' "$SB_WORK/.claude/roles/example.md" >/dev/null || cf "(c) the module's role doc was not re-rendered with the project's stamp"
  teardown

  # (d) the same, and the project edited the role doc too: a merge item, not "nothing to do".
  _mu_pair
  printf 'the project own line\n' >> "$SB_WORK/.claude/roles/example.md"
  sed -i.bak "s/prefix $SB_PREFIX,/prefix ZZQ,/" "$SB_WORK/scripts/config.sh"; rm -f "$SB_WORK/scripts/config.sh.bak"
  _mu_land "the project edits the role doc and the stamp changes"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(d) the upgrade exited $_mu_rc: $(_mu_flat)"
  printf '%s\n' "$_mu_out" | grep -F 'Nothing to do' >/dev/null && cf "(d) a module merge item under the same kit version was reported as nothing to do"
  grep -F 'merge .claude/roles/example.md — module example' "$SB_WORK/process/UPGRADE-CHECKLIST.md" 2>/dev/null | grep '^- \[ \] ' >/dev/null || cf "(d) no unmarked item asks for the role doc's merge"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — WITH TWO MODULES ENABLED, EACH IS CARRIED AND RECORDED AT ITS OWN VERSION.
#   The record's version decides which release-notes entries the next upgrade raises, so a module recorded at another
#   module's version drops or repeats entries silently. The example module moves on; `second` (a fixture module built
#   here, because the example alone cannot show this) stays at 0.5.0 in one order of enabling and moves to 0.6.0 in the
#   other; the last module the scan reads must not set the version of the rest.
# =============================================================================
case_kit_upgrade_records_each_of_two_enabled_modules_at_its_own_version() {
  cf_reset
  local L="kit-upgrade.sh over two enabled modules records each at the version its own copy in the new kit declares (a module that did not move keeps its version, whichever module the scan reads last), raises each module's own release-notes entries, and writes each module's files"
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mu_subject_ok || { finish "$L"; return; }
  local order second_new want_second cl
  for order in "example second" "second example"; do
    MU_ENABLE="$order" _mu_pair _mu_two_modules_pre
    _mu_new_version
    second_new=0.5.0
    if [ "$order" = "second example" ]; then
      second_new=0.6.0; _mu_second_module "$MU_NEW" 0.6.0; _mu_manifest "$MU_NEW"
    fi
    _mu_up "$SB_WORK"
    [ "$_mu_rc" -eq 0 ] || { cf "($order) the upgrade exited $_mu_rc: $(_mu_flat)"; teardown; continue; }
    cl="$SB_WORK/process/UPGRADE-CHECKLIST.md"
    grep -F -x "module example $MU_NEWVER" "$SB_WORK/process/MODULES" >/dev/null || cf "($order) example is not recorded at $MU_NEWVER: $(grep '^module ' "$SB_WORK/process/MODULES" | tr '\n' '|')"
    grep -F -x "module second $second_new" "$SB_WORK/process/MODULES" >/dev/null || cf "($order) second is not recorded at $second_new: $(grep '^module ' "$SB_WORK/process/MODULES" | tr '\n' '|')"
    grep -E '^pending ' "$SB_WORK/process/MODULES" >/dev/null && cf "($order) a pending section is left in the record"
    grep -F "module example, Action required, [$MU_NEWVER] item 1" "$cl" >/dev/null || cf "($order) no item for example's entry at $MU_NEWVER"
    if [ "$order" = "second example" ]; then
      grep -F "module second, Action required, [0.6.0] item 1" "$cl" >/dev/null || cf "($order) no item for second's entry at 0.6.0"
      [ "$(cat "$SB_WORK/docs/second-note.txt" 2>/dev/null)" = "the second module note, version 0.6.0" ] || cf "($order) second's file was not replaced by its new version"
    else
      grep -F "module second, Action required" "$cl" >/dev/null && cf "($order) an item for second, which did not move"
    fi
    _md_mod status second
    printf '%s\n' "$_md_out" | grep -E 'edited|missing' >/dev/null && cf "($order) status shows second edited or missing after the upgrade: $(printf '%s' "$_md_out" | tr '\n' '|')"
    teardown
  done
  finish "$L"
}

# =============================================================================
# CASE — THE UPGRADE'S DUTIES TOWARD AN ENABLED MODULE HAVE ONE HOME.
#   Pins the doctrine rule that a rule stated in prose is a list in prose: the checklist duties kit-upgrade.sh carries for a
#   module are listed in full in contracts/kit-upgrade.md and cited, not restated, by the guide, the release notes and the script header.
# =============================================================================
case_the_upgrades_module_duties_are_listed_once() {
  cf_reset
  local L="the list of what the upgrade puts on the checklist for an enabled module (a module whose enable never finished among them) is stated in contracts/kit-upgrade.md alone: MODULES.md, the other sheets, the release notes and kit-upgrade.sh's header cite it"
  [ -f "$REAL_REPO_ROOT/process/contracts/kit-upgrade.md" ] || { skp_lived "$L" "process/contracts/kit-upgrade.md is absent from this tree"; return; }
  local hits
  hits="$(cd "$REAL_REPO_ROOT" && grep -l -i 'whose enable never finished' process/MODULES.md process/KIT-RELEASE-NOTES.md process/contracts/*.md scripts/kit-upgrade.sh scripts/lib/modules.sh 2>/dev/null | tr '\n' ' ')"
  [ "$hits" = "process/contracts/kit-upgrade.md " ] || cf "the duty list is stated in: ${hits:-(nowhere)}; want process/contracts/kit-upgrade.md alone"
  finish "$L"
}

# =============================================================================
# CASE — A KILLED kit-upgrade IS FINISHED BY RUNNING IT AGAIN, AT EVERY WRITE IT MAKES.
#   The upgrade runs under stand-ins for cp, mv, mkdir, rm, mktemp and chmod that SIGKILL it (no trap, no cleanup)
#   before the Nth write into the project, for the N that _md_kill_points chooses from an uninterrupted run's writes (all
#   of them with KIT_TEST_KILL_ALL=1): the core's, the module's, the staging's, the checklist's and the record's. After EACH kill:
#     - `module.sh disable` keeps none of the module's own files (a record that named a replaced file by its old sha256
#       would keep it as "edited");
#     - running the upgrade again reaches the tree an uninterrupted run leaves, byte for byte, with no stray file, and
#       "nothing was changed" is printed only by a rerun that changed nothing.
#   A write that FAILS (not a kill) is refused as upgrade-write-failed, saying what was written and how to finish.
#   Kill points: the boundaries, the writes around every one to a shared file, the record or the checklist, and one in
#   eight (_md_kill_points); the second-kill pass uses nine of the first forty. KIT_TEST_KILL_ALL=1 runs every write.
# =============================================================================
case_a_killed_kit_upgrade_is_finished_by_running_it_again() {
  cf_reset
  local L="a kit-upgrade killed before each of its writes in turn leaves a project that module.sh disable takes back without keeping any file the module wrote, and running the upgrade again reaches the tree an uninterrupted run leaves, with no stray file and no 'nothing was changed' after a write; a write that fails is refused as upgrade-write-failed naming what was written and how to finish"
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mu_subject_ok || { finish "$L"; return; }
  _mu_pair
  _mu_project_edits; _mu_land "the project's edits to the module"
  _mu_new_version
  _md_make_count_shim
  local clean="$SB_TMP/clean" run="$SB_TMP/run" run2="$SB_TMP/run2" n total=0 rootp out f pre kept strays nf="" n2 n1 G pts n2s
  cp -R "$SB_WORK" "$clean"
  _mu_up "$clean"
  [ "$_mu_rc" -eq 0 ] || { cf "(control) the uninterrupted upgrade exited $_mu_rc: $(_mu_flat)"; finish "$L"; teardown; return; }
  _md_snap "$clean" > "$SB_TMP/clean.snap"
  [ -s "$SB_TMP/clean.snap" ] || _fixture_die "${FUNCNAME[0]}: the snapshot of the uninterrupted run is empty."

  # the writes of an uninterrupted run, counted and traced, are the kill points to choose from
  rm -rf "$run"; cp -R "$SB_WORK" "$run"; rootp="$(cd "$run" && pwd -P)"; echo 0 > "$SB_TMP/count"; rm -f "$SB_TMP/trace"
  _mu_up "$run" PATH="$SB_TMP/cshim:$PATH" KILL_ROOT="$rootp" KILL_NTH=999999999 KILL_COUNT="$SB_TMP/count" KILL_TRACE="$SB_TMP/trace"
  [ "$_mu_rc" -eq 0 ] || { cf "(control) the counted upgrade exited $_mu_rc: $(_mu_flat)"; finish "$L"; teardown; return; }
  total="$(cat "$SB_TMP/count")"
  pts="$(_md_kill_points "$SB_TMP/trace" "$rootp" 'PROJECT\.md|\.gitignore|process/MODULES|UPGRADE-CHECKLIST|module-records|KIT-VERSION')"
  for n in $pts; do
    rm -rf "$run"; cp -R "$SB_WORK" "$run"
    rootp="$(cd "$run" && pwd -P)"; echo 0 > "$SB_TMP/count"
    _mu_up "$run" PATH="$SB_TMP/cshim:$PATH" KILL_ROOT="$rootp" KILL_NTH="$n" KILL_COUNT="$SB_TMP/count"
    if [ "$_mu_rc" -ne 137 ]; then cf "(write $n) exit $_mu_rc, want the kill's 137: $(_mu_flat)"; continue; fi
    # (1) disable, straight after the kill
    rm -rf "$run2"; cp -R "$run" "$run2"
    kept="$( cd "$run2" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/rec2" ./scripts/module.sh disable example 2>&1 </dev/null )"
    for f in '\.claude/roles/example\.md' '\.claude/skills/example-skill/NOTES\.md' 'PROJECT\.md' '\.gitignore' 'process/roles\.d/example'; do
      printf '%s\n' "$kept" | grep -E "^    $f( |\$)" >/dev/null && cf "(write $n) disable after the kill KEPT $f, a file the module wrote and the project did not edit"
    done
    # a kill point between the checklist and the record: the one --finish has to be able to finish
    if [ -z "$nf" ] && [ -f "$run/process/UPGRADE-CHECKLIST.md" ] && ! grep -F -x "module example $MU_NEWVER" "$run/process/MODULES" >/dev/null; then nf="$n"; fi
    # (2) the rerun
    _md_snap "$run" > "$SB_TMP/pre.snap"
    _mu_up "$run"
    if [ "$_mu_rc" -ne 0 ]; then cf "(write $n) running the killed upgrade again exited $_mu_rc: $(_mu_flat)"; continue; fi
    if printf '%s\n' "$_mu_out" | grep -i 'nothing was changed' >/dev/null; then
      _md_snap "$run" > "$SB_TMP/post.snap"
      cmp -s "$SB_TMP/pre.snap" "$SB_TMP/post.snap" || cf "(write $n) the rerun printed 'nothing was changed' and changed the tree"
    fi
    _md_snap "$run" > "$SB_TMP/run.snap"
    cmp -s "$SB_TMP/clean.snap" "$SB_TMP/run.snap" || cf "(write $n) the rerun did not reach the tree an uninterrupted run leaves: $(diff "$SB_TMP/clean.snap" "$SB_TMP/run.snap" | tr '\n' '|' | cut -c1-300)"
    strays="$(_md_strays "$run"; find "$run/process" -name 'MODULES.*' -o -name 'UPGRADE-CHECKLIST.md.*' 2>/dev/null)"
    [ -z "$strays" ] || cf "(write $n) a temporary file survived the rerun: $(printf '%s' "$strays" | tr '\n' ' ')"
  done
  [ "$total" -ge 10 ] || cf "(control) the kill stand-ins counted only $total write(s) in the upgrade, so the enumeration did not reach them"
  echo "      (the upgrade makes $total write(s) into the project; $(printf '%s\n' "$pts" | wc -l | tr -d ' ') of them were kill points)"

  # (3) --finish finishes a record the checklist outlived: kill at the first write after the checklist, mark, commit, finish
  G=(git -c user.email=s@k.invalid -c user.name=s -c commit.gpgsign=false -c core.hooksPath=/dev/null)
  if [ -z "$nf" ]; then cf "(control) no kill point fell between the checklist and the record"; else
    rm -rf "$run"; cp -R "$SB_WORK" "$run"; rootp="$(cd "$run" && pwd -P)"; echo 0 > "$SB_TMP/count"
    _mu_up "$run" PATH="$SB_TMP/cshim:$PATH" KILL_ROOT="$rootp" KILL_NTH="$nf" KILL_COUNT="$SB_TMP/count"
    sed -i.bak 's/^- \[ \] /- [x] /' "$run/process/UPGRADE-CHECKLIST.md"; rm -f "$run/process/UPGRADE-CHECKLIST.md.bak"
    "${G[@]}" -C "$run" add -A >/dev/null 2>&1; "${G[@]}" -C "$run" commit -q -m "the upgrade, marked" >/dev/null 2>&1
    out="$( cd "$run" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/rec3" ./scripts/kit-upgrade.sh --finish --into "$run" 2>&1 </dev/null )" || cf "(finish) --finish after a kill at write $nf exited nonzero: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
    grep -F -x "module example $MU_NEWVER" "$run/process/MODULES" >/dev/null || cf "(finish) --finish stamped the kit and left the module at its old version: $(grep -E '^(module|pending)' "$run/process/MODULES" | tr '\n' '|')"
    grep -E '^pending ' "$run/process/MODULES" >/dev/null && cf "(finish) --finish left a pending section"
    [ ! -e "$run/.kit-upgrade" ] || cf "(finish) --finish left the staging directory"
  fi

  # (4) a rerun that is itself killed, at each of its first 40 writes in turn (the clean-up, the record and the module's files), is finished by a third run: the ahead rows are kept whole
  n1=""
  # the first kill point after the newly placed file is on disk and before the module's block is replaced
  for n in $pts; do
    rm -rf "$run"; cp -R "$SB_WORK" "$run"; rootp="$(cd "$run" && pwd -P)"; echo 0 > "$SB_TMP/count"
    _mu_up "$run" PATH="$SB_TMP/cshim:$PATH" KILL_ROOT="$rootp" KILL_NTH="$n" KILL_COUNT="$SB_TMP/count"
    if [ -f "$run/.claude/skills/example-skill/NOTES.md" ] && ! grep -F 'a revised toy' "$run/PROJECT.md" >/dev/null && [ ! -f "$run/process/UPGRADE-CHECKLIST.md" ]; then n1="$n"; break; fi
  done
  if [ -z "$n1" ]; then cf "(control) no kill point fell after the newly placed file and before the checklist"; else
    n2s="1 2 3 5 8 13 21 34 40"; [ -z "${KIT_TEST_KILL_ALL:-}" ] || n2s="$(seq 1 40)"
    for n2 in $n2s; do
      rm -rf "$run"; cp -R "$SB_WORK" "$run"; rootp="$(cd "$run" && pwd -P)"; echo 0 > "$SB_TMP/count"
      _mu_up "$run" PATH="$SB_TMP/cshim:$PATH" KILL_ROOT="$rootp" KILL_NTH="$n1" KILL_COUNT="$SB_TMP/count"
      echo 0 > "$SB_TMP/count"
      _mu_up "$run" PATH="$SB_TMP/cshim:$PATH" KILL_ROOT="$rootp" KILL_NTH="$n2" KILL_COUNT="$SB_TMP/count"
      [ "$_mu_rc" -ne 0 ] || break
      _mu_up "$run"
      if [ "$_mu_rc" -ne 0 ]; then cf "(second kill $n1/$n2) the third run exited $_mu_rc: $(_mu_flat)"; continue; fi
      _md_snap "$run" > "$SB_TMP/run.snap"
      cmp -s "$SB_TMP/clean.snap" "$SB_TMP/run.snap" || cf "(second kill $n1/$n2) the third run did not reach the tree an uninterrupted run leaves: $(diff "$SB_TMP/clean.snap" "$SB_TMP/run.snap" | tr '\n' '|' | cut -c1-300)"
    done
  fi

  # a write that FAILS part-way: once where the record is written (process/) and once where a module file goes
  if [ "$(id -u)" != 0 ]; then
    for f in process .claude/roles; do
      rm -rf "$run"; cp -R "$SB_WORK" "$run"
      chmod 555 "$run/$f"
      _mu_up "$run"
      chmod 755 "$run/$f"
      [ "$_mu_rc" -eq 1 ] || cf "(write failure in $f) exit $_mu_rc, want 1: $(_mu_flat)"
      [ "$(_mu_recs upgrade-write-failed)" -ge 1 ] || cf "(write failure in $f) no refusal=upgrade-write-failed record: $(_mu_flat)"
      printf '%s\n' "$_mu_out" | grep -i 'nothing was changed' >/dev/null && cf "(write failure in $f) the refusal says nothing was changed after the kit files were written: $(_mu_flat)"
      printf '%s\n' "$_mu_out" | grep -E 'written [0-9]+ of [0-9]+ kit file' >/dev/null || cf "(write failure in $f) the refusal does not say what was written: $(_mu_flat)"
      printf '%s\n' "$_mu_out" | grep -F 'run this again' >/dev/null || cf "(write failure in $f) the refusal does not say how to finish: $(_mu_flat)"
      _mu_up "$run"
      [ "$_mu_rc" -eq 0 ] || cf "(write failure in $f) running the upgrade again exited $_mu_rc: $(_mu_flat)"
      _md_snap "$run" > "$SB_TMP/run.snap"
      cmp -s "$SB_TMP/clean.snap" "$SB_TMP/run.snap" || cf "(write failure in $f) the rerun did not reach the tree an uninterrupted run leaves: $(diff "$SB_TMP/clean.snap" "$SB_TMP/run.snap" | tr '\n' '|' | cut -c1-300)"
    done
  fi

  finish "$L"
  teardown
}

# _mu_snap_body <project> — the whole tree, the checklist too: a rerun lists every file the killed run replaced or added.
_mu_snap_body() { _md_snap "$1"; }
# _mu_module_items <project> — the checklist's lines about the modules, sorted: what a rerun owes the project whole.
_mu_module_items() { grep -E 'module (example|second)' "$1/process/UPGRADE-CHECKLIST.md" 2>/dev/null | LC_ALL=C sort; }

# =============================================================================
# CASE — A KILLED kit-upgrade OVER MODULES THAT SHARE A BLOCK HOST IS FINISHED BY RUNNING IT AGAIN; THE PROJECT'S OWN EDIT STILL IS NOT.
#   Two modules put blocks in the same PROJECT.md and .gitignore, and one of them puts two blocks in PROJECT.md. The
#   upgrade is killed before each of its writes in turn, in both orders of enabling and with the second module alone.
#   After EACH kill the host holds a block the killed run wrote and is not committed, and running the upgrade again must
#   reach the tree an uninterrupted run leaves, not refuse it as the project's uncommitted change. Where PROJECT.md is
#   changed by the kill, the same state with a line of the project's own added outside any block, and with a block edited
#   by hand, must still be refused as upgrade-target-dirty, and the refusal's own route (stash only the path it names)
#   must lead to the tree an uninterrupted run leaves.
#   Kill points: the boundaries, the writes around every one to a shared file, the record or the checklist, and one in
#   eight (_md_kill_points), for the first order only, the project's-edit rows at every third of them; KIT_TEST_KILL_ALL=1
#   runs every write and every row, in all three orders.
# =============================================================================
case_a_killed_kit_upgrade_over_modules_sharing_a_block_host_is_finished_by_running_it_again() {
  cf_reset
  local L="a kit-upgrade killed before each of its writes in turn, over two modules that put blocks in the same PROJECT.md and .gitignore (one of them two blocks in PROJECT.md), is finished by running it again to the tree an uninterrupted run leaves, in both orders of enabling; a line of the project's own in that PROJECT.md, or a block edited by hand, at the same kill points is still refused as upgrade-target-dirty, and stashing only the path the refusal names lets the rerun finish"
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mu_subject_ok || { finish "$L"; return; }
  local order clean run run3 n total rootp dirtied edited G pts orders=("example second")
  [ -z "${KIT_TEST_KILL_ALL:-}" ] || orders=("example second" "second example" "second")
  G=(git -c user.email=s@k.invalid -c user.name=s -c commit.gpgsign=false -c core.hooksPath=/dev/null)
  for order in "${orders[@]}"; do
    MU_ENABLE="$order" _mu_pair _mu_shared_hosts_pre
    clean="$SB_TMP/clean"; run="$SB_TMP/run"; run3="$SB_TMP/run3"
    _mu_new_version
    _mu_second_module "$MU_NEW" 0.6.0 blocks; _mu_manifest "$MU_NEW"
    _md_make_count_shim
    rm -rf "$clean"; cp -R "$SB_WORK" "$clean"
    _mu_up "$clean"
    [ "$_mu_rc" -eq 0 ] || { cf "($order, control) the uninterrupted upgrade exited $_mu_rc: $(_mu_flat)"; teardown; continue; }
    grep -F 'revised toy' "$clean/PROJECT.md" >/dev/null || [ "$order" = second ] || cf "($order, control) the uninterrupted upgrade did not rewrite the example module's block"
    grep -F 'second gate 0.6.0' "$clean/PROJECT.md" >/dev/null || cf "($order, control) the uninterrupted upgrade did not rewrite the second module's block"
    _mu_snap_body "$clean" > "$SB_TMP/clean.snap"; _mu_module_items "$clean" > "$SB_TMP/clean.items"
    dirtied=0; edited=0
    # the writes of an uninterrupted run, counted and traced, are the kill points to choose from
    rm -rf "$run"; cp -R "$SB_WORK" "$run"; rootp="$(cd "$run" && pwd -P)"; echo 0 > "$SB_TMP/count"; rm -f "$SB_TMP/trace"
    _mu_up "$run" PATH="$SB_TMP/cshim:$PATH" KILL_ROOT="$rootp" KILL_NTH=999999999 KILL_COUNT="$SB_TMP/count" KILL_TRACE="$SB_TMP/trace"
    [ "$_mu_rc" -eq 0 ] || { cf "($order, control) the counted upgrade exited $_mu_rc: $(_mu_flat)"; teardown; continue; }
    total="$(cat "$SB_TMP/count")"
    pts="$(_md_kill_points "$SB_TMP/trace" "$rootp" 'PROJECT\.md|\.gitignore|process/MODULES|UPGRADE-CHECKLIST|module-records')"
    for n in $pts; do
      rm -rf "$run"; cp -R "$SB_WORK" "$run"
      rootp="$(cd "$run" && pwd -P)"; echo 0 > "$SB_TMP/count"
      _mu_up "$run" PATH="$SB_TMP/cshim:$PATH" KILL_ROOT="$rootp" KILL_NTH="$n" KILL_COUNT="$SB_TMP/count"
      [ "$_mu_rc" -eq 137 ] || { cf "($order, write $n) exit $_mu_rc, want the kill's 137: $(_mu_flat)"; continue; }
      # the project's own edit, in a state the kill left PROJECT.md short of what a finished upgrade leaves (a rerun still
      # writes a block there, so an edit of the project's is in its way): refused, whatever the kill had written
      if ! cmp -s "$run/PROJECT.md" "$clean/PROJECT.md"; then
        dirtied=$((dirtied + 1))
        # the three rows below run at every such point with KIT_TEST_KILL_ALL=1, and at every third without it
        if [ -z "${KIT_TEST_KILL_ALL:-}" ] && [ $((dirtied % 3)) -ne 1 ]; then :; else
        rm -rf "$run3"; cp -R "$run" "$run3"
        printf 'the project own line\n' >> "$run3/PROJECT.md"
        _mu_up "$run3"
        if [ "$_mu_rc" -ne 1 ] || [ "$(_mu_recs upgrade-target-dirty)" -lt 1 ] || ! printf '%s\n' "$_mu_out" | grep -F "git stash push -u -- PROJECT.md" >/dev/null; then
          cf "($order, write $n) a line of the project's own in PROJECT.md was not refused as upgrade-target-dirty with a stash of that path alone: exit $_mu_rc: $(_mu_flat)"
        fi
        # ...and a block the killed run already wrote, edited by hand (a block the run had not reached would be left to the
        # merge it becomes, and not be written over)
        rm -rf "$run3"; cp -R "$run" "$run3"
        sed -i.bak -e 's/a revised toy/by hand/' -e 's/second gate 0\.6\.0/second gate by hand/' "$run3/PROJECT.md"; rm -f "$run3/PROJECT.md.bak"
        if ! cmp -s "$run/PROJECT.md" "$run3/PROJECT.md"; then
          edited=$((edited + 1))
          _mu_up "$run3"
          if [ "$_mu_rc" -ne 1 ] || [ "$(_mu_recs upgrade-target-dirty)" -lt 1 ]; then
            cf "($order, write $n) a block the killed run wrote, edited by hand in PROJECT.md, was not refused as upgrade-target-dirty: exit $_mu_rc: $(_mu_flat)"
          fi
        fi
        # the route the refusal names: stash that path alone, run again
        rm -rf "$run3"; cp -R "$run" "$run3"
        printf 'the project own line\n' >> "$run3/PROJECT.md"
        "${G[@]}" -C "$run3" stash push -q -u -- PROJECT.md >/dev/null 2>&1 || cf "($order, write $n) the stash the refusal names did not run"
        _mu_up "$run3"
        if [ "$_mu_rc" -ne 0 ]; then cf "($order, write $n) running the upgrade again after the stash exited $_mu_rc: $(_mu_flat)"
        else
          _mu_snap_body "$run3" > "$SB_TMP/run.snap"; _mu_module_items "$run3" > "$SB_TMP/run.items"
          { cmp -s "$SB_TMP/clean.snap" "$SB_TMP/run.snap" && cmp -s "$SB_TMP/clean.items" "$SB_TMP/run.items"; } || cf "($order, write $n) after the stash the rerun did not reach the tree an uninterrupted run leaves: $(diff "$SB_TMP/clean.snap" "$SB_TMP/run.snap" | tr '\n' '|' | cut -c1-300)"
        fi
        fi
      fi
      # the rerun with nothing of the project's in it
      _mu_up "$run"
      if [ "$_mu_rc" -ne 0 ]; then cf "($order, write $n) running the killed upgrade again exited $_mu_rc: $(_mu_flat)"; continue; fi
      _mu_snap_body "$run" > "$SB_TMP/run.snap"; _mu_module_items "$run" > "$SB_TMP/run.items"
      { cmp -s "$SB_TMP/clean.snap" "$SB_TMP/run.snap" && cmp -s "$SB_TMP/clean.items" "$SB_TMP/run.items"; } || cf "($order, write $n) the rerun did not reach the tree an uninterrupted run leaves: $(diff "$SB_TMP/clean.snap" "$SB_TMP/run.snap" | tr '\n' '|' | cut -c1-300)"
      grep -E '^pending ' "$run/process/MODULES" >/dev/null && cf "($order, write $n) a pending section is left in the record"
    done
    [ "$total" -ge 10 ] || cf "($order, control) the kill stand-ins counted only $total write(s) in the upgrade"
    [ "$dirtied" -ge 3 ] || cf "($order, control) only $dirtied kill point(s) left PROJECT.md changed, so the project's-edit rows were barely exercised"
    [ "$edited" -ge 3 ] || cf "($order, control) only $edited kill point(s) held a written block to edit, so the edited-block row was barely exercised"
    echo "      ($order: $total write(s), $(printf '%s\n' "$pts" | wc -l | tr -d ' ') of them kill points; PROJECT.md changed at $dirtied of them)"
    teardown
  done
  finish "$L"
}

# =============================================================================
# CASE — kit-upgrade REFUSES BEFORE IT WRITES WHEN AN ENABLED MODULE CANNOT BE JUDGED, AND SAYS WHAT TO DO.
#   Each row: exit 1, a Next: line, a refusal record naming the rule, and a tree byte-equal to the one before
#   (no staging, no checklist, no file of the core replaced either).
# =============================================================================
case_kit_upgrade_refuses_before_it_writes_when_an_enabled_module_cannot_be_judged() {
  cf_reset
  local L="kit-upgrade.sh over a project with an enabled module refuses, writing nothing, when no sha256 tool is on the machine, when the new kit's module manifest does not read (an unknown key, a target spelt .GIT/), when the new kit has no scripts/lib/modules.sh, when a host the module's block is in has uncommitted changes, and when process/MODULES names a path outside the project; each leaves a Next: line and a refusal record naming its rule"
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mu_subject_ok || { finish "$L"; return; }
  _mu_pair
  _mu_new_version
  local s0="$SB_TMP/snap0" s1="$SB_TMP/snap1"
  _refused() {  # <label> <rule> <must name…> -- <the run's extra env…>
    local label="$1" rule="$2" want; shift 2
    local names=()
    while [ "$1" != -- ]; do names+=("$1"); shift; done; shift
    [ "$_mu_rc" -eq 1 ] || cf "($label) exit $_mu_rc, want 1: $(_mu_flat)"
    printf '%s\n' "$_mu_out" | grep '^Next:' >/dev/null || cf "($label) the refusal carries no Next: line: $(_mu_flat)"
    [ "$(_mu_recs "$rule")" -ge 1 ] || cf "($label) no refusal=$rule record"
    for want in "${names[@]}"; do
      printf '%s\n' "$_mu_out" | grep -F -- "$want" >/dev/null || cf "($label) the refusal does not name '$want': $(_mu_flat)"
    done
    _md_snap "$SB_WORK" > "$s1"
    cmp -s "$s0" "$s1" || cf "($label) the refused upgrade changed the tree: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-240)"
    [ ! -e "$SB_WORK/.kit-upgrade" ] && [ ! -e "$SB_WORK/process/UPGRADE-CHECKLIST.md" ] || cf "($label) the refused upgrade left staging or a checklist"
  }
  _md_snap "$SB_WORK" > "$s0"

  # (a) no sha256 tool on the machine: a PATH of the tools the programs use, without shasum and sha256sum.
  _mu_up "$SB_WORK" PATH="$(_mu_nosha_path)"
  _refused "no sha256 tool" upgrade-modules-no-sha "no sha256 tool" "(example)" --

  # (a2) no scratch directory for the module scan.
  _mu_up "$SB_WORK" TMPDIR="$SB_TMP/no-such-directory"
  _refused "no scratch directory" upgrade-write-failed "scratch directory" --

  # (b) the new kit's manifest does not read.
  cp "$MU_NEW/modules/example/module.manifest" "$SB_TMP/manifest.keep"
  printf 'bogus: x\n' >> "$MU_NEW/modules/example/module.manifest"; _mu_manifest "$MU_NEW"
  _mu_up "$SB_WORK"
  _refused "an unknown manifest key" module-manifest-bad "unknown key 'bogus'" --
  cp "$SB_TMP/manifest.keep" "$MU_NEW/modules/example/module.manifest"
  printf 'file: gates.md -> .GIT/hooks/post-commit\n' >> "$MU_NEW/modules/example/module.manifest"; _mu_manifest "$MU_NEW"
  _mu_up "$SB_WORK"
  _refused "a target spelt .GIT/" module-manifest-bad ".GIT/hooks/post-commit" --
  cp "$SB_TMP/manifest.keep" "$MU_NEW/modules/example/module.manifest"; _mu_manifest "$MU_NEW"

  # (c) the new kit cannot read the record.
  mv "$MU_NEW/scripts/lib/modules.sh" "$SB_TMP/modules.sh.keep"; _mu_manifest "$MU_NEW"
  _mu_up "$SB_WORK"
  _refused "no lib/modules.sh in the new kit" upgrade-source-not-a-kit "has no scripts/lib/modules.sh to read them with" --
  mv "$SB_TMP/modules.sh.keep" "$MU_NEW/scripts/lib/modules.sh"; _mu_manifest "$MU_NEW"

  # (d) a host the module's block is rewritten in has uncommitted changes.
  printf 'an edit the project has not committed\n' >> "$SB_WORK/PROJECT.md"
  _md_snap "$SB_WORK" > "$s0"
  _mu_up "$SB_WORK"
  _refused "an uncommitted block host" upgrade-target-dirty "PROJECT.md" --
  git -C "$SB_WORK" checkout -q -- PROJECT.md

  # (e) the record names a path outside the project.
  printf 'file %s ../outside.txt\n' "$(printf 'a%.0s' $(seq 1 64))" >> "$SB_WORK/process/MODULES"
  _mu_land "a record that names a path outside the project"
  _md_snap "$SB_WORK" > "$s0"
  _mu_up "$SB_WORK"
  _refused "a record path outside the project" module-record-bad "../outside.txt" --
  unset -f _refused

  finish "$L"
  teardown
}

# _mu_vf_setup — a project with the example module enabled, upgraded to a kit whose module notes carry a passing and a failing
# Verify: line (and a second module, shipped and not enabled, whose notes would fail if read); the checklist marked and landed.
_mu_vf_setup() {
  _mu_pair
  _mu_new_version
  cat > "$MU_NEW/modules/example/RELEASE-NOTES.md" <<MU_VF_EOF
# The example module — release notes

## [$MU_NEWVER] — 2026-01-02

### Action required

- **Passing item.** Nothing to do.
  Verify: true

- **Failing item.** Create the marker file module-verify-marker at the project's top level.
  Verify: [ -f module-verify-marker ]

## [$MU_OLDVER] — 2026-01-01

### Added

- **The toy module.**
MU_VF_EOF
  # a module the project did not enable, whose notes would fail if they were read
  _mu_second_module "$MU_NEW" 0.5.0
  printf '# second — release notes\n\n## [0.5.0]\n\n### Action required\n\n- **Unread item.**\n  Verify: false\n' > "$MU_NEW/modules/second/RELEASE-NOTES.md"
  _mu_manifest "$MU_NEW"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || { cf "(a) the upgrade exited $_mu_rc: $(_mu_flat)"; return 1; }
  [ "$(grep -c 'Action required, \[' "$SB_WORK/process/UPGRADE-CHECKLIST.md")" = 2 ] || cf "(a) the checklist should carry the module's two Action required items and no more: $(grep -F 'Action required' "$SB_WORK/process/UPGRADE-CHECKLIST.md" | cut -c1-100 | tr '\n' '|')"
  sed -i.bak 's/^- \[ \] /- [x] /' "$SB_WORK/process/UPGRADE-CHECKLIST.md"; rm -f "$SB_WORK/process/UPGRADE-CHECKLIST.md.bak"
  _mu_land "the upgrade, marked"
}

# =============================================================================
# CASE — --finish RUNS THE Verify: LINES OF AN ENABLED MODULE'S OWN RELEASE NOTES, AND REFUSES ON A FAILING ONE.
#   The module's notes are read by the same reader as the kit's (notes_items), from a copy staged at the first run.
#   A module that is shipped and not enabled has no item on the checklist and contributes none.
#   Known answers: one passing and one failing line refuse by name and change nothing; once the failing line's
#   action is done, --finish stamps and the archive says the passing line was verified.
# =============================================================================
case_finish_runs_the_verify_lines_of_an_enabled_modules_release_notes() {
  cf_reset
  local L="kit-upgrade.sh --finish runs the Verify: line of each Action required item from an enabled module's own release notes: a failing one is refused as upgrade-verify-failed naming the module and the item and stamps nothing, a passing one is recorded as verified, and a shipped module that is not enabled adds no line"
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mu_subject_ok || { finish "$L"; return; }
  local cl rc out arch
  _mu_vf_setup || { finish "$L"; teardown; return; }
  cl="$SB_WORK/process/UPGRADE-CHECKLIST.md"
  # the checklist line shows the command --finish will run, as the kit's own lines do
  grep -F 'Failing item' "$cl" | grep -F 'Verify: [ -f module-verify-marker ]' >/dev/null || cf "(a) the failing module item's checklist line does not show its Verify: command: $(grep -F 'Failing item' "$cl" | cut -c1-200)"
  grep -F 'Passing item' "$cl" | grep -F 'Verify: true' >/dev/null || cf "(a) the passing module item's checklist line does not show its Verify: command: $(grep -F 'Passing item' "$cl" | cut -c1-200)"

  # (b) the failing line refuses, by module and item, and stamps nothing.
  rc=0; out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/rec-fin" ./scripts/kit-upgrade.sh --finish --into "$SB_WORK" 2>&1 </dev/null )" || rc=$?
  [ "$rc" -eq 1 ] || cf "(b) --finish exited $rc, want the refusal's 1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  grep -h 'refusal=upgrade-verify-failed' "$SB_TMP"/rec-fin/*.tsv >/dev/null 2>&1 || cf "(b) no refusal=upgrade-verify-failed record: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -F 'module example' | grep -F 'Failing item' >/dev/null || cf "(b) the refusal does not name the module and the failing item: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -F 'Passing item' >/dev/null && cf "(b) the refusal lists the passing item as failed"
  [ "$(cat "$SB_WORK/process/KIT-VERSION")" = 0.1.0 ] || cf "(b) process/KIT-VERSION was stamped though a Verify: line failed"
  [ -f "$cl" ] || cf "(b) the checklist was removed by a refused --finish"

  # (b2) the staged copy of the module's notes edited and committed: its sha256 is no file the new kit's manifest holds for the module.
  cp "$SB_WORK/.kit-upgrade/module-notes/example.kit-new" "$SB_TMP/example-notes-staged"
  sed -i.bak 's/Verify: \[ -f module-verify-marker \]/Verify: true/' "$SB_WORK/.kit-upgrade/module-notes/example.kit-new"; rm -f "$SB_WORK/.kit-upgrade/module-notes/example.kit-new.bak"
  _mu_land "the staged module notes, edited"
  rc=0; out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/rec-fin3" ./scripts/kit-upgrade.sh --finish --into "$SB_WORK" 2>&1 </dev/null )" || rc=$?
  [ "$rc" -eq 1 ] || cf "(b2) --finish over edited staged module notes exited $rc, want the refusal's 1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  grep -h 'refusal=upgrade-staging-edited' "$SB_TMP"/rec-fin3/*.tsv >/dev/null 2>&1 || cf "(b2) no refusal=upgrade-staging-edited record: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  [ "$(cat "$SB_WORK/process/KIT-VERSION")" = 0.1.0 ] || cf "(b2) process/KIT-VERSION was stamped over edited staged module notes"
  cp "$SB_TMP/example-notes-staged" "$SB_WORK/.kit-upgrade/module-notes/example.kit-new"
  _mu_land "the staged module notes, restored"

  # (c) the action done, --finish stamps and the archive records the passing line.
  : > "$SB_WORK/module-verify-marker"
  rc=0; out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/rec-fin2" ./scripts/kit-upgrade.sh --finish --into "$SB_WORK" 2>&1 </dev/null )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(c) --finish exited $rc once the marker existed: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  [ "$(cat "$SB_WORK/process/KIT-VERSION")" = 0.2.0 ] || cf "(c) --finish did not stamp process/KIT-VERSION: $(cat "$SB_WORK/process/KIT-VERSION")"
  arch="$(ls "$SB_WORK"/process/upgrades/*-to-0.2.0.md 2>/dev/null | head -1)"
  { [ -n "$arch" ] && grep -F 'verified, exit 0:' "$arch" | grep -F 'module example' | grep -F 'Passing item' >/dev/null; } \
    || cf "(c) the archive does not record the module's passing line as verified"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A MODULE DISABLED AFTER THE UPGRADE WAS STAGED HAS ITS Verify: LINES SKIPPED AT --finish, AND SAID SO.
#   The checklist line was written while the module was enabled. A module that is not enabled at --finish contributes
#   nothing, so a failing line of its notes does not refuse; the archive records the item as declared and not run.
# =============================================================================
case_finish_skips_the_verify_lines_of_a_module_disabled_since_the_upgrade() {
  cf_reset
  local L="kit-upgrade.sh --finish does not run, and does not refuse on, the Verify: line of a module that was disabled after the upgrade was staged: it stamps, and the archive lists the item as declared and not run"
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mu_subject_ok || { finish "$L"; return; }
  local rc out arch
  _mu_vf_setup || { finish "$L"; teardown; return; }
  # (control) with the module enabled, the failing line refuses: the premise of what follows.
  rc=0; out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/rec-skip0" ./scripts/kit-upgrade.sh --finish --into "$SB_WORK" 2>&1 </dev/null )" || rc=$?
  [ "$rc" -eq 1 ] || _fixture_die "${FUNCNAME[0]}: --finish with the module enabled exited $rc, so nothing below measures a disabled module: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  _md_mod disable example
  [ "$_md_rc" -eq 0 ] || _fixture_die "${FUNCNAME[0]}: disabling the module exited $_md_rc: $_md_out"
  _mu_land "disable the module"
  rc=0; out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/rec-skip1" ./scripts/kit-upgrade.sh --finish --into "$SB_WORK" 2>&1 </dev/null )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(a) --finish refused on a module that is no longer enabled (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  [ "$(cat "$SB_WORK/process/KIT-VERSION")" = 0.2.0 ] || cf "(a) --finish did not stamp process/KIT-VERSION: $(cat "$SB_WORK/process/KIT-VERSION")"
  arch="$(ls "$SB_WORK"/process/upgrades/*-to-0.2.0.md 2>/dev/null | head -1)"
  { [ -n "$arch" ] && grep -F 'declared, not run' "$arch" | grep -F 'module example' | grep -F 'Failing item' >/dev/null; } \
    || cf "(b) the archive does not list the disabled module's failing item as declared and not run"
  [ -n "$arch" ] && grep -F 'verified, exit 0:' "$arch" | grep -F 'Passing item' >/dev/null && cf "(b) the archive says a disabled module's line was verified"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — kit-upgrade NAMES WHAT IT CANNOT CARRY FOR AN ENABLED MODULE, AND CARRIES THE REST.
#   Each row is a checklist item, not a refusal: the files that can be written are written.
#     (a) an enable that never finished           (b) a module the new kit no longer ships
#     (c) a block host with no final newline      (d) a point whose reader this project's copy lacks
#     (e) a role the module drops that history carries    (f) a path under a symbolic link
# =============================================================================
case_kit_upgrade_names_what_it_cannot_carry_for_an_enabled_module() {
  cf_reset
  local L="kit-upgrade.sh puts on the checklist, and carries the rest around, a module whose enable never finished, a module the new kit no longer ships, a block whose host has no final newline (the new block staged), a point whose reader this project's copy lacks, a role layer the new version would shrink below a role the history carries (kept as it is), and files under a symbolic link (never written through it)"
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mu_subject_ok || { finish "$L"; return; }
  local cl st before after outside

  # (a) a module whose enable never finished: the run names it and changes nothing for it.
  _mu_pair
  _md_mod disable example
  _md_make_kill_shim
  _md_kill_enable scripts/check-board.d/50-example.sh
  [ -f "$SB_WORK/process/MODULES" ] && grep -E '^pending example ' "$SB_WORK/process/MODULES" >/dev/null || _fixture_die "${FUNCNAME[0]}: the killed enable left no pending record."
  _mu_land "an enable that did not finish"
  _mu_new_version
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(a) the upgrade exited $_mu_rc: $(_mu_flat)"
  grep -F 'module example has an enable that did not finish' "$SB_WORK/process/UPGRADE-CHECKLIST.md" 2>/dev/null | grep '^- \[ \] ' >/dev/null || cf "(a) no unmarked item names the module whose enable did not finish"
  grep -E '^pending example ' "$SB_WORK/process/MODULES" >/dev/null || cf "(a) the upgrade changed the record of the unfinished enable"
  teardown

  # (b) the module is gone from the new kit.
  _mu_pair
  rm -rf "$MU_NEW/modules/example"; _mu_manifest "$MU_NEW"
  _md_snap "$SB_WORK" > "$SB_TMP/b0"; before="$(cat "$SB_WORK/process/MODULES")"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(b) the upgrade exited $_mu_rc: $(_mu_flat)"
  grep -F 'module example is enabled here and the new kit no longer ships it' "$SB_WORK/process/UPGRADE-CHECKLIST.md" 2>/dev/null | grep '^- \[ \] ' >/dev/null || cf "(b) no unmarked item says the new kit no longer ships the module"
  [ "$before" = "$(cat "$SB_WORK/process/MODULES")" ] || cf "(b) the record changed though the module is gone"
  [ -f "$SB_WORK/.claude/roles/example.md" ] || cf "(b) a file the module placed was removed"
  teardown

  # (c) a block host with no final newline: the block is a merge item and the rest is carried.
  _mu_pair
  printf '%s' "$(cat "$SB_WORK/PROJECT.md")" > "$SB_WORK/PROJECT.md"; _mu_land "a PROJECT.md with no final newline"
  _mu_new_version
  before="$(cat "$SB_WORK/PROJECT.md")"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(c) the upgrade exited $_mu_rc: $(_mu_flat)"
  cl="$SB_WORK/process/UPGRADE-CHECKLIST.md"; st="$SB_WORK/.kit-upgrade/modules/example"
  grep -F 'merge PROJECT.md (block, slot gates) — module example' "$cl" 2>/dev/null | grep -F 'does not end with a newline' | grep '^- \[ \] ' >/dev/null || cf "(c) no unmarked item names the block host with no final newline"
  [ "$(cat "$SB_WORK/PROJECT.md")" = "$before" ] || cf "(c) PROJECT.md was changed"
  grep -F 'a revised toy' "$st/PROJECT.md.gates-block.kit-new" >/dev/null 2>&1 || cf "(c) the module's new table is not staged at .kit-upgrade/modules/example/PROJECT.md.gates-block.kit-new"
  grep -F 'A line the new version adds to the role doc.' "$SB_WORK/.claude/roles/example.md" >/dev/null || cf "(c) the files that could be written were not written"
  teardown

  # (d) a reader this project's copy of the kit lacks.
  _mu_pair
  sed -i.bak 's/kit_card_fragments/kit_card_fragmentz/g' "$SB_WORK/scripts/new-issue.sh"; rm -f "$SB_WORK/scripts/new-issue.sh.bak"
  _mu_land "a new-issue.sh that does not read fragments"
  _mu_new_version
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(d) the upgrade exited $_mu_rc: $(_mu_flat)"
  grep -F 'module example adds to extension points whose readers this project' "$SB_WORK/process/UPGRADE-CHECKLIST.md" 2>/dev/null | grep -F "its checks are placed and never run" | grep -F "scripts/new-issue.sh does not carry 'kit_card_fragments'" | grep '^- \[ \] ' >/dev/null \
    || cf "(d) no unmarked item names scripts/new-issue.sh as the reader the project lacks: $(grep -F 'module example' "$SB_WORK/process/UPGRADE-CHECKLIST.md" 2>/dev/null | cut -c1-200 | tr '\n' '|')"
  teardown

  # (e0) the new version drops its role layer altogether, and a commit on the trunk carries the role.
  _mu_pair
  _mu_role="$(sed -n 's/^role:[[:space:]]*\([A-Za-z0-9_-]*\).*/\1/p' "$SB_WORK/modules/example/module.manifest" | sed -n '1p')"
  sbcommit -q --allow-empty -m "[$_mu_role] $SB_PREFIX-730: uses the role" >/dev/null 2>&1; git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  _mu_new_version
  sed -i.bak '/^role:/d' "$MU_NEW/modules/example/module.manifest"; rm -f "$MU_NEW/modules/example/module.manifest.bak"; _mu_manifest "$MU_NEW"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(e0) the upgrade exited $_mu_rc: $(_mu_flat)"
  before="$(grep -F 'removed upstream: process/roles.d/example' "$SB_WORK/process/UPGRADE-CHECKLIST.md" 2>/dev/null)"
  [ -n "$before" ] || cf "(e0) no item names the role layer the new version no longer places"
  printf '%s\n' "$before" | grep -F 'commits on this branch or the trunk carry the role Example' >/dev/null || cf "(e0) the item does not say that commits carry the role: $before"
  printf '%s\n' "$before" | grep -E 'delete it|disable still takes it' >/dev/null && cf "(e0) the item tells the project to delete a role layer in use, or says disable takes it: $before"
  [ -f "$SB_WORK/process/roles.d/example" ] || cf "(e0) the role layer in use was deleted"
  teardown

  # (e1) a target whose only change is its case: on a case-insensitive filesystem the file is the same file.
  _mu_pair
  _mu_new_version
  sed -i.bak 's#-> \.claude/roles/example\.md#-> .claude/roles/Example.md#' "$MU_NEW/modules/example/module.manifest"; rm -f "$MU_NEW/modules/example/module.manifest.bak"
  _mu_manifest "$MU_NEW"
  if [ -e "$SB_WORK/.claude/roles/EXAMPLE.MD" ]; then
    _mu_up "$SB_WORK"
    [ "$_mu_rc" -eq 0 ] || cf "(e1) the upgrade exited $_mu_rc: $(_mu_flat)"
    grep -F 'removed upstream: .claude/roles/example.md' "$SB_WORK/process/UPGRADE-CHECKLIST.md" >/dev/null 2>&1 && cf "(e1) the role doc, renamed only in case, is listed as removed upstream: it is the same file here"
    [ "$(grep -ci '^file .* \.claude/roles/example\.md$' "$SB_WORK/process/MODULES")" = 1 ] || cf "(e1) the record does not hold exactly one row for the role doc: $(grep -i 'roles/example.md' "$SB_WORK/process/MODULES" | tr '\n' '|')"
    [ -f "$SB_WORK/.claude/roles/Example.md" ] || cf "(e1) the role doc is gone"
  else
    _mu_up "$SB_WORK"
    [ "$_mu_rc" -eq 0 ] || cf "(e1) the upgrade exited $_mu_rc: $(_mu_flat)"
    grep -F 'removed upstream: .claude/roles/example.md' "$SB_WORK/process/UPGRADE-CHECKLIST.md" >/dev/null 2>&1 || cf "(e1) on a case-sensitive filesystem the old spelling is a file of its own and is not listed as removed upstream"
    [ -f "$SB_WORK/.claude/roles/Example.md" ] && [ -f "$SB_WORK/.claude/roles/example.md" ] || cf "(e1) on a case-sensitive filesystem a spelling is missing"
  fi
  teardown

  # (e) a role the new version drops, which a commit on the trunk carries.
  _mu_pair _mu_two_roles
  sbcommit -q --allow-empty -m "[Example2] $SB_PREFIX-730: uses the second role" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  _mu_new_version
  sed -i.bak '/^role: Example2/d' "$MU_NEW/modules/example/module.manifest"; rm -f "$MU_NEW/modules/example/module.manifest.bak"; _mu_manifest "$MU_NEW"
  before="$(cat "$SB_WORK/process/roles.d/example")"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(e) the upgrade exited $_mu_rc: $(_mu_flat)"
  [ "$(cat "$SB_WORK/process/roles.d/example")" = "$before" ] || cf "(e) the role layer was rewritten without the role the history carries"
  grep -F 'merge process/roles.d/example — module example: the new version no longer adds the role Example2' "$SB_WORK/process/UPGRADE-CHECKLIST.md" 2>/dev/null | grep '^- \[ \] ' >/dev/null \
    || cf "(e) no unmarked item names the role the layer keeps"
  teardown

  # (f) a path under a symbolic link: never written through it.
  _mu_pair
  outside="$SB_TMP/outside"; mkdir -p "$outside"
  cp -R "$SB_WORK/.claude/skills/example-skill/." "$outside/"
  rm -rf "$SB_WORK/.claude/skills/example-skill"; ln -s "$outside" "$SB_WORK/.claude/skills/example-skill"
  _mu_land "the skill directory is a symbolic link"
  _mu_new_version
  before="$(cat "$outside/SKILL.md")"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(f) the upgrade exited $_mu_rc: $(_mu_flat)"
  [ "$(cat "$outside/SKILL.md")" = "$before" ] || cf "(f) the module's new skill was written THROUGH the symbolic link"
  [ ! -e "$outside/NOTES.md" ] || cf "(f) the new file was placed through the symbolic link"
  grep -F 'symbolic link' "$SB_WORK/process/UPGRADE-CHECKLIST.md" 2>/dev/null | grep -F 'module example' | grep '^- \[ \] ' >/dev/null || cf "(f) no unmarked item says a path is under a symbolic link"
  teardown

  finish "$L"
}
# _mu_two_roles — before the pair is built, the module in the sandbox adds a second role.
_mu_two_roles() {
  printf 'role: Example2   a second toy seat\n' >> "$SB_WORK/modules/example/module.manifest"
}

# =============================================================================
# CASE — A REAL kit-upgrade WITH A MODULE ENABLED RUNS TO --finish ON THE SHIPPED TREE.
#   The old project and the new kit are each a clone of the tree under test (its own scripts and manifest, not
#   a fabricated pair). The module is enabled in the old one and moved on in the new one; the project edits one
#   of its files. The first run carries the new version and raises the module's item; marking every item,
#   committing it and finishing stamps the version, archives the checklist and leaves a record whose rows are
#   true. This is where an upgrade that ignores a module's record, or reads a manifest it did not ship, is found.
# =============================================================================
case_a_real_kit_upgrade_with_a_module_enabled_runs_to_finish() {
  cf_reset
  local L="on clones of the shipped tree, a kit-upgrade with the example module enabled in the project carries the module's new version, raises its Action required entry, and after the items are marked and committed --finish stamps the version, archives the checklist and removes the staging, leaving process/MODULES with the module at the new version and every row true"
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mu_subject_ok || { finish "$L"; return; }
  git -C "$REAL_REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { skp "$L" "the tree under test is not a git work tree to clone"; return; }
  [ ! -e "$REAL_REPO_ROOT/process/MODULES" ] || { skp_lived "$L" "process/MODULES records an enabled module in this tree, so it is not the unenabled kit this case clones twice (modules/README.md ships with none enabled)"; return; }
  [ -f "$REAL_REPO_ROOT/process/KIT-MANIFEST" ] && [ -f "$REAL_REPO_ROOT/process/KIT-VERSION" ] || { skp "$L" "process/KIT-MANIFEST or process/KIT-VERSION is absent (a tree that is not a built kit has nothing to upgrade from)"; return; }
  make_sandbox
  local old="$SB_TMP/old" new="$SB_TMP/new" else_dir="$SB_TMP/else" G f rc=0 out cl m oldv newv
  G=(git -c user.email=s@k.invalid -c user.name=s -c commit.gpgsign=false)
  mkdir -p "$else_dir"
  _mu_clone_tree "$old" && _mu_clone_tree "$new" || _fixture_die "${FUNCNAME[0]}: could not clone the tree under test."
  [ -f "$old/scripts/module.sh" ] && [ -f "$new/scripts/kit-upgrade.sh" ] || { cf "(prereq) the clone holds no scripts/module.sh or scripts/kit-upgrade.sh"; finish "$L"; teardown; return; }
  # the old project: a stamp (a clone of a tree kit-init has not run in has none), a PROJECT.md with the slot, the module enabled.
  if ! grep -q '^# Stamped by scripts/kit-init.sh' "$old/scripts/config.sh"; then
    printf '\n# Stamped by scripts/kit-init.sh on 2026-01-01 — prefix %s, trunk %s (kit-init.sh --help explains the re-run refusal).\n' "$SB_PREFIX" "$SB_TRUNK" >> "$old/scripts/config.sh"
  fi
  printf '# PROJECT.md (clone)\n\n| Gate | Your command | The contract it implements |\n|---|---|---|\n| g | `x` | y |\n\n<!-- KIT-MODULES:gates the slot -->\n\ntail\n' > "$old/PROJECT.md"
  if [ -f "$old/.gitignore" ]; then [ -z "$(tail -c1 "$old/.gitignore")" ] || printf '\n' >> "$old/.gitignore"; fi
  MSG_OK=1 "${G[@]}" -C "$old" commit -q -am "a stamp and a PROJECT.md the module can go in" || _fixture_die "${FUNCNAME[0]}: could not commit the clone."
  out="$( cd "$old" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/rec-old" ./scripts/module.sh enable example 2>&1 </dev/null )" || rc=$?
  [ "$rc" -eq 0 ] || { cf "(prereq) enabling the example module in the clone exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"; finish "$L"; teardown; return; }
  printf 'the project own line\n' >> "$old/.claude/skills/example-skill/SKILL.md"
  git -C "$old" add -A >/dev/null 2>&1; MSG_OK=1 "${G[@]}" -C "$old" commit -q -m "enable the example module and edit its skill"
  # the new kit: the module moved on, its manifest rows kept true, a newer version.
  m="$new/modules/example"
  oldv="$(sed -n 's/^version:[[:space:]]*//p' "$m/module.manifest" | sed -n '1p')"; newv="$(_mu_next_version "$m/module.manifest")"
  sed -e "s/^version: .*/version: $newv/" "$m/module.manifest" > "$m/module.manifest.new" && mv "$m/module.manifest.new" "$m/module.manifest"
  printf 'A line the new version adds to the role doc.\n' >> "$m/_claude/roles/example.md"
  printf 'A line the new version adds to the skill.\n' >> "$m/_claude/skills/example-skill/SKILL.md"
  printf '# The example module — release notes\n\n## [%s] — 2026-01-02\n\n### Action required\n\n- **Take the sign-off line.** Add `example-sign-off: pending` to every open card.\n\n## [%s]\n\n### Added\n\n- **The toy module.**\n' "$newv" "$oldv" > "$m/RELEASE-NOTES.md"
  printf '99.0.0\n' > "$new/process/KIT-VERSION"
  for f in modules/example/module.manifest modules/example/_claude/roles/example.md modules/example/_claude/skills/example-skill/SKILL.md modules/example/RELEASE-NOTES.md; do
    if awk -F'  ' -v p="$f" '$2 == p { f = 1 } END { exit !f }' "$new/process/KIT-MANIFEST"; then
      awk -F'  ' -v OFS='  ' -v p="$f" -v h="$(_mu_sha "$new/$f")" '$2 == p { $1 = h } { print }' "$new/process/KIT-MANIFEST" > "$new/process/KIT-MANIFEST.new" && mv "$new/process/KIT-MANIFEST.new" "$new/process/KIT-MANIFEST"
    else
      printf '%s  %s  %s  %s\n' "$(_mu_sha "$new/$f")" "$f" KIT - >> "$new/process/KIT-MANIFEST"
    fi
  done

  rc=0; out="$( cd "$else_dir" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/rec-up" "$new/scripts/kit-upgrade.sh" --into "$old" 2>&1 </dev/null )" || rc=$?
  [ "$rc" -eq 0 ] || { cf "(a) the upgrade exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"; finish "$L"; teardown; return; }
  cl="$old/process/UPGRADE-CHECKLIST.md"
  grep -F 'A line the new version adds to the role doc.' "$old/.claude/roles/example.md" >/dev/null || cf "(a) the role doc was not replaced by the module's new version"
  grep -F 'the project own line' "$old/.claude/skills/example-skill/SKILL.md" >/dev/null || cf "(a) the project's edit to the skill was lost"
  grep -F "module example, Action required, [$newv] item 1: Take the sign-off line." "$cl" | grep '^- \[ \] ' >/dev/null || cf "(a) no unmarked item carries the module's Action required entry"
  grep -F 'merge .claude/skills/example-skill/SKILL.md — module example' "$cl" | grep '^- \[ \] ' >/dev/null || cf "(a) no unmarked item asks for the skill's merge"
  grep -F 'stamp what arrived' "$cl" | grep '^- \[ \] ' >/dev/null || cf "(a) no unmarked item asks to stamp what arrived"
  [ "$(grep -c '^- \[ \] ' "$cl")" = 3 ] || cf "(a) the checklist holds $(grep -c '^- \[ \] ' "$cl") item(s), want the module's two and the stamp item and nothing else: $(grep '^- \[' "$cl" | cut -c1-120 | tr '\n' '|')"

  # mark, commit, finish.
  sed -i.bak 's/^- \[ \] /- [x] /' "$cl"; rm -f "$cl.bak"
  git -C "$old" add -A >/dev/null 2>&1; MSG_OK=1 "${G[@]}" -C "$old" commit -q -m "the upgrade, marked"
  rc=0; out="$( cd "$old" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/rec-fin" ./scripts/kit-upgrade.sh --finish --into "$old" 2>&1 </dev/null )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(b) --finish exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"
  [ "$(cat "$old/process/KIT-VERSION" 2>/dev/null)" = 99.0.0 ] || cf "(b) --finish did not stamp process/KIT-VERSION: $(cat "$old/process/KIT-VERSION" 2>/dev/null)"
  [ ! -e "$old/.kit-upgrade" ] && [ ! -e "$cl" ] || cf "(b) --finish left the staging or the checklist"
  ls "$old"/process/upgrades/*-to-99.0.0.md >/dev/null 2>&1 || cf "(b) --finish did not archive the checklist"
  grep -F -x "module example $newv" "$old/process/MODULES" >/dev/null || cf "(c) process/MODULES does not record the module at $newv"
  ( cd "$old" && ./scripts/module.sh status example ) > "$SB_TMP/real.status" 2>&1
  grep -E '^  intact +\.claude/roles/example\.md' "$SB_TMP/real.status" >/dev/null || cf "(c) status does not show the replaced role doc as intact: $(tr '\n' '|' < "$SB_TMP/real.status" | cut -c1-240)"
  grep -E '^  edited +\.claude/skills/example-skill/SKILL\.md' "$SB_TMP/real.status" >/dev/null || cf "(c) status does not show the project's edited skill as edited"
  grep -E '^  missing' "$SB_TMP/real.status" >/dev/null && cf "(c) status shows a missing thing after the upgrade"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — module.sh status WITH NO SHA256 TOOL SAYS IT CANNOT JUDGE, NOT THAT EVERY FILE IS EDITED.
#   Operand: status of an enabled module, run on a PATH without shasum and sha256sum. enable and disable
#   refuse there; status only reports, so it names what it cannot do and calls no present file edited.
# =============================================================================
case_module_status_without_a_sha256_tool_says_it_cannot_judge() {
  cf_reset
  local L="module.sh status of an enabled module, on a machine with no sha256 tool, exits 0, says it cannot judge a file as intact or edited, and calls no present file edited or intact; with the tool back the same files read intact"
  if ! _md_have_example; then skp_lived "$L" "$(_md_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _md_sandbox
  [ -f "$SB_WORK/scripts/module.sh" ] || cf "(prereq) scripts/module.sh is absent from the tree under test"
  local out rc=0
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || { cf "(prereq) enable exited $_md_rc"; finish "$L"; teardown; return; }
  out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/records" PATH="$(_mu_nosha_path)" ./scripts/module.sh status example 2>&1 </dev/null )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(a) status exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$out" | grep -F 'cannot judge' | grep -F 'sha256' >/dev/null || cf "(a) status does not say it cannot judge without a sha256 tool: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -E '^  (edited|intact) ' >/dev/null && cf "(a) status judged a file without a sha256 tool: $(printf '%s' "$out" | grep -E '^  (edited|intact) ' | head -2 | tr '\n' '|')"
  printf '%s\n' "$out" | grep -E '^  unjudged +\.claude/roles/example\.md' >/dev/null || cf "(a) the role doc's row is not marked unjudged: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  _md_mod status example
  printf '%s\n' "$_md_out" | grep -E '^  intact +\.claude/roles/example\.md' >/dev/null || cf "(b) with the tool, the role doc does not read intact: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  finish "$L"
  teardown
}
