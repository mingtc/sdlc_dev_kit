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
# status is left in _mu_rc and the output in _mu_out. Records go to a directory emptied first. A run given KILL_NTH (under
# the kill stand-in) gets _md_kill_tmp as its TMPDIR, so what a SIGKILL leaves is removed by teardown.
_mu_rc=0; _mu_out=""
_mu_up() {
  local proj="$1" kt=""; shift
  case " $* " in *" KILL_NTH="*) kt="$(_md_kill_tmp)" ;; esac
  rm -rf "$SB_TMP/up-records"; _mu_rc=0
  _mu_out="$( cd "$MU_ELSE" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/up-records" KILL_PID_FILE="$SB_TMP/kill-pid" ${kt:+"TMPDIR=$kt"} "$@" bash -c 'echo $$ > "$KILL_PID_FILE"; exec "$@"' _ "$MU_NEW/scripts/kit-upgrade.sh" --into "$proj" 2>&1 </dev/null )" || _mu_rc=$?
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
    printf 'modules/example/module.manifest is absent from this tree'
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
  for f in scripts/kit-upgrade.sh scripts/kit-init.sh scripts/module.sh scripts/lib/modules.sh scripts/lib/marker-block.sh scripts/lib/card-head.sh scripts/lib/exit-trap.sh; do
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
  # fixture modules for two that collide without sharing a spelling: pa places docs/x, which pb places a file under; ga's ignore
  # block covers the path gb places
  for c in "pa docs/x" "pb docs/x/y" "gb docs/g/f.txt"; do
    mkdir -p "$SB_WORK/modules/${c%% *}"
    printf 'name: %s\nversion: 0.1.0\npurpose: A fixture module that places %s.\nfile: f.txt -> %s\n' "${c%% *}" "${c#* }" "${c#* }" > "$SB_WORK/modules/${c%% *}/module.manifest"
    printf 'from %s\n' "${c%% *}" > "$SB_WORK/modules/${c%% *}/f.txt"
  done
  mkdir -p "$SB_WORK/modules/ga"
  printf 'name: ga\nversion: 0.1.0\npurpose: A fixture module whose ignore block covers a path.\ngitignore: ignore.txt\n' > "$SB_WORK/modules/ga/module.manifest"
  printf 'docs/g/\n' > "$SB_WORK/modules/ga/ignore.txt"
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
  local L="kit-init.sh --with refuses in the preflight, writing nothing and exiting 1, an unknown module, a stray comma, a path the module would place that exists, a reader this copy of the kit lacks, a block host with no slot, a fragment every mint would refuse and a placed path git ignores, each naming the module and the cause; an enable that fails after the stamp refuses with module-enable-after-stamp and a hand finish that works"
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
  _row "one module's file under another's file" "--with pa,pb" "module pa places docs/x" "module pb places docs/x/y" -- --with pa,pb
  _row "the same, named the other way round" "--with pb,pa" "module pa places docs/x" "module pb places docs/x/y" -- --with pb,pa
  _row "one module's ignore block over another's path" "--with ga,gb" "module ga" "docs/g/f.txt" "module gb" -- --with ga,gb
  # whether docs/SAME.txt is docs/same.txt is the filesystem's to say: the top level's `.git` is found under `.GIT` where it reads case as one
  if [ -n "$ci" ]; then
    _row "two modules that place one path in two cases" "--with ca,cc" "module ca places docs/same.txt" "module cc places docs/SAME.txt" -- --with ca,cc
    _row "a path kit-init copies, spelt in another case" "--with hookycase" ".claude/Settings.json" "kit-init writes it" -- --enable-hooks --with hookycase
  fi
  # a fragment every mint of its template would refuse (a control byte); last, as a run that went through would stamp the tree
  mkdir -p "$SB_WORK/modules/fragbad"
  printf 'name: fragbad\nversion: 0.1.0\npurpose: A fixture module whose fragment holds a control byte.\nfragment: ISSUE body-end f.txt\n' > "$SB_WORK/modules/fragbad/module.manifest"
  printf 'one\036two\n' > "$SB_WORK/modules/fragbad/f.txt"
  _row "a fragment every mint would refuse" "--with fragbad" "modules/fragbad/f.txt (placed as process/fragments.d/ISSUE/fragbad.body-end)" "control byte" -- --with fragbad
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
# CASE — AN ENABLED MODULE WHOSE RECORD DOES NOT NAME THE VERSION THE KIT HOLDS IS WORK, WHATEVER THE KIT'S OWN VERSION.
#   The same kit version is run over a project where (a) the module's version moved and nothing it places did, (b) the
#   record carries a `pending` section a killed run left, (c) the module's files and the kit's version stamp are the new ones and the
#   record still names the old one (a guard against regression). Each is carried: never "Nothing to do", the record
#   ends at the new version with no `pending` section.
# =============================================================================
case_kit_upgrade_at_an_unchanged_kit_version_carries_an_enabled_modules_record() {
  cf_reset
  local L="kit-upgrade.sh at the kit version a project already records still carries an enabled module whose record names another version than the kit holds, or holds a pending section: a module that only changed version, a record a killed run left pending, and files already written under the old record are each never reported as nothing to do and end with the record at the new version and no pending section"
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mu_subject_ok || { finish "$L"; return; }
  local m rec0 newv

  # (a) the module's version moved; nothing it places changed.
  _mu_pair
  m="$MU_NEW/modules/example"
  newv="$(_mu_next_version "$m/module.manifest")"
  sed -e "s/^version: .*/version: $newv/" "$m/module.manifest" > "$m/module.manifest.new" && mv "$m/module.manifest.new" "$m/module.manifest"
  _mu_manifest "$MU_NEW"
  # the project already holds the new kit's copy of the manifests, as it does after the core's files were written
  cp "$m/module.manifest" "$SB_WORK/modules/example/module.manifest"; cp "$MU_NEW/process/KIT-MANIFEST" "$SB_WORK/process/KIT-MANIFEST"
  _mu_land "the core files are current"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(a) the upgrade exited $_mu_rc: $(_mu_flat)"
  printf '%s\n' "$_mu_out" | grep -F 'Nothing to do' >/dev/null && cf "(a) a module that only changed version was reported as nothing to do: $(_mu_flat)"
  grep -F -x "module example $newv" "$SB_WORK/process/MODULES" >/dev/null || cf "(a) the record does not name $newv: $(grep '^module ' "$SB_WORK/process/MODULES" | tr '\n' '|')"
  # the run converges: the record committed, the same upgrade again has nothing to do
  _mu_land "commit the record"
  _mu_up "$SB_WORK"
  printf '%s\n' "$_mu_out" | grep -F 'Nothing to do' >/dev/null || cf "(a) the upgrade run again after the record was committed still has work: $(_mu_flat)"
  teardown

  # (b) a pending section left by a killed run, the version unchanged.
  _mu_pair
  printf 'pending example %s\n' "$(sed -n 's/^module example //p' "$SB_WORK/process/MODULES")" >> "$SB_WORK/process/MODULES"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(b) the upgrade exited $_mu_rc: $(_mu_flat)"
  printf '%s\n' "$_mu_out" | grep -F 'Nothing to do' >/dev/null && cf "(b) a record with a pending section was reported as nothing to do: $(_mu_flat)"
  grep -E '^pending ' "$SB_WORK/process/MODULES" >/dev/null && cf "(b) the pending section is still in the record"
  teardown

  # (c) the files are the new version's, the record is the old one's, at the kit version the project already records: a guard against regression, not a shape the old test got wrong.
  _mu_pair
  rec0="$SB_TMP/record-before"; cp "$SB_WORK/process/MODULES" "$rec0"
  _mu_new_version
  _mu_manifest "$MU_NEW"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(c) the first upgrade exited $_mu_rc: $(_mu_flat)"
  rm -rf "$SB_WORK/process/UPGRADE-CHECKLIST.md" "$SB_WORK/.kit-upgrade"; cp "$rec0" "$SB_WORK/process/MODULES"
  cp "$MU_NEW/process/KIT-VERSION" "$SB_WORK/process/KIT-VERSION"; cp "$MU_NEW/process/KIT-MANIFEST" "$SB_WORK/process/KIT-MANIFEST"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(c) the rerun exited $_mu_rc: $(_mu_flat)"
  printf '%s\n' "$_mu_out" | grep -F 'Nothing to do' >/dev/null && cf "(c) files written under the old record were reported as nothing to do: $(_mu_flat)"
  grep -F -x "module example $MU_NEWVER" "$SB_WORK/process/MODULES" >/dev/null || cf "(c) the record still names the old version: $(grep '^module ' "$SB_WORK/process/MODULES" | tr '\n' '|')"
  grep -E '^pending ' "$SB_WORK/process/MODULES" >/dev/null && cf "(c) a pending section is left in the record"
  printf '%s\n' "$_mu_out" | grep -F 'moved the record' >/dev/null && cf "(c) written module files beside the old record were taken as record-only, whose Next commits process/MODULES alone: $(_mu_flat)"
  printf '%s\n' "$_mu_out" | grep -F 'Review:' >/dev/null || cf "(c) the run does not say to review the whole diff: $(_mu_flat)"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — A RUN WHOSE ONLY WORK IS THE MODULE RECORD MOVES THE RECORD, SAYS SO, AND STAGES NOTHING.
#   The same kit version is run over a project where (a) the module's version moved and nothing it places did, (b) the
#   record carries a `pending` section. The run names the record as the reason, writes it, leaves no checklist and no
#   staging directory, tells the adopter to commit (never to --finish), and the same run again has nothing to do. A second
#   such run after another version move leaves no archive to collide with; --finish after one is refused as nothing to finish.
# =============================================================================
case_a_record_only_kit_upgrade_moves_the_record_says_so_and_stages_nothing() {
  cf_reset
  local L="kit-upgrade.sh over a project whose only work is an enabled module's record (another version than the kit holds, or a pending section) names the record move, writes the record, leaves no checklist and no staging, points at a commit and not at --finish, repeats cleanly, and --finish after it is refused as nothing to finish"
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mu_subject_ok || { finish "$L"; return; }
  local m newv newv2

  # (a) the version moved, twice in a row.
  _mu_pair
  m="$MU_NEW/modules/example"
  newv="$(_mu_next_version "$m/module.manifest")"
  sed -e "s/^version: .*/version: $newv/" "$m/module.manifest" > "$m/module.manifest.new" && mv "$m/module.manifest.new" "$m/module.manifest"
  _mu_manifest "$MU_NEW"
  cp "$m/module.manifest" "$SB_WORK/modules/example/module.manifest"; cp "$MU_NEW/process/KIT-MANIFEST" "$SB_WORK/process/KIT-MANIFEST"
  _mu_land "the core files are current"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(a) the upgrade exited $_mu_rc: $(_mu_flat)"
  printf '%s\n' "$_mu_out" | grep -F 'moved the record' >/dev/null || cf "(a) the run does not say it moved the record: $(_mu_flat)"
  printf '%s\n' "$_mu_out" | grep -F -e '--finish' >/dev/null && cf "(a) the run points at --finish: $(_mu_flat)"
  printf '%s\n' "$_mu_out" | grep -F 'pending' >/dev/null && cf "(a) the run speaks of a pending section there was none of: $(_mu_flat)"
  [ ! -e "$SB_WORK/process/UPGRADE-CHECKLIST.md" ] || cf "(a) a checklist was written for a record-only run"
  [ ! -e "$SB_WORK/.kit-upgrade" ] || cf "(a) a staging directory was left for a record-only run"
  grep -F -x "module example $newv" "$SB_WORK/process/MODULES" >/dev/null || cf "(a) the record does not name $newv: $(grep '^module ' "$SB_WORK/process/MODULES" | tr '\n' '|')"
  _mu_land "commit the record"
  _mu_up "$SB_WORK"
  printf '%s\n' "$_mu_out" | grep -F 'Nothing to do' >/dev/null || cf "(a) the run again still has work: $(_mu_flat)"
  _mu_rc=0; _mu_out="$( cd "$MU_ELSE" && env -u CLAUDE_PROJECT_DIR "$MU_NEW/scripts/kit-upgrade.sh" --finish --into "$SB_WORK" 2>&1 </dev/null )" || _mu_rc=$?
  { [ "$_mu_rc" -ne 0 ] && printf '%s\n' "$_mu_out" | grep -F 'no upgrade is in progress' >/dev/null; } || cf "(a) --finish after a record-only run was not refused as nothing to finish (rc $_mu_rc): $(_mu_flat)"
  # the module moves on again at the same kit version: no archive stands in the way
  newv2="$(_mu_next_version "$m/module.manifest")"
  sed -e "s/^version: .*/version: $newv2/" "$m/module.manifest" > "$m/module.manifest.new" && mv "$m/module.manifest.new" "$m/module.manifest"
  _mu_manifest "$MU_NEW"
  cp "$m/module.manifest" "$SB_WORK/modules/example/module.manifest"; cp "$MU_NEW/process/KIT-MANIFEST" "$SB_WORK/process/KIT-MANIFEST"
  _mu_land "the core files are current again"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(a) the second upgrade exited $_mu_rc: $(_mu_flat)"
  [ ! -e "$SB_WORK/process/upgrades" ] || cf "(a) an archive directory exists after two record-only runs"
  grep -F -x "module example $newv2" "$SB_WORK/process/MODULES" >/dev/null || cf "(a) the second run left the record at another version than $newv2"
  teardown

  # (b) a pending section left by a killed run, the version unchanged.
  _mu_pair
  printf 'pending example %s\n' "$(sed -n 's/^module example //p' "$SB_WORK/process/MODULES")" >> "$SB_WORK/process/MODULES"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(b) the upgrade exited $_mu_rc: $(_mu_flat)"
  printf '%s\n' "$_mu_out" | grep -F 'moved the record' >/dev/null || cf "(b) the run does not say it moved the record: $(_mu_flat)"
  printf '%s\n' "$_mu_out" | grep -F 'cleared the pending section of example' >/dev/null || cf "(b) the run does not say it cleared the pending section: $(_mu_flat)"
  { [ ! -e "$SB_WORK/process/UPGRADE-CHECKLIST.md" ] && [ ! -e "$SB_WORK/.kit-upgrade" ]; } || cf "(b) a checklist or staging was left for a record-only run"
  grep -E '^pending ' "$SB_WORK/process/MODULES" >/dev/null && cf "(b) the pending section is still in the record"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — A RECORD-ONLY RUN IS NOT TAKEN OVER A KILLED MODULE WRITE, AND ITS OWN FAILURE UNDOES NOTHING IT DID NOT DO.
#   (a) The same kit version, a module that moved a version and changed a role doc. The upgrade is killed at the first write
#   after its module files (the staging directory), leaving the new role doc and a `pending` section uncommitted. The run
#   again is the full one: it names the whole diff to commit, and an adopter who commits it and finishes ends with the module
#   intact and nothing to do. (b) A record-only run whose record cannot be written is refused with a Next that undoes nothing:
#   it does not tell the adopter to discard the tree or to remove files it never wrote.
# =============================================================================
case_a_killed_module_write_is_rerun_as_the_full_path_and_a_record_only_failure_undoes_nothing() {
  cf_reset
  local L="kit-upgrade.sh re-run after a kill that left a module's new file uncommitted beside a pending record takes the full path (the checklist and the review-the-whole-diff Next, not a commit of process/MODULES alone), and the adopter who follows it ends with the module intact; a record-only run whose record cannot be written is refused as upgrade-write-failed with a Next that undoes nothing"
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mu_subject_ok || { finish "$L"; return; }
  local m newv run rootp n pts G
  G=(git -c user.email=s@k.invalid -c user.name=s -c commit.gpgsign=false -c core.hooksPath=/dev/null)

  # (a) kill after the module's role doc is written, before the staging directory
  _mu_pair
  m="$MU_NEW/modules/example"
  newv="$(_mu_next_version "$m/module.manifest")"
  sed -e "s/^version: .*/version: $newv/" "$m/module.manifest" > "$m/module.manifest.new" && mv "$m/module.manifest.new" "$m/module.manifest"
  printf 'A line the new version adds to the role doc.\n' >> "$m/_claude/roles/example.md"
  _mu_manifest "$MU_NEW"
  cp -R "$m/." "$SB_WORK/modules/example/"; cp "$MU_NEW/process/KIT-MANIFEST" "$SB_WORK/process/KIT-MANIFEST"
  _mu_land "the core files are current"
  _md_make_count_shim
  run="$SB_TMP/run"; rm -rf "$run"; cp -R "$SB_WORK" "$run"; rootp="$(cd "$run" && pwd -P)"
  echo 0 > "$SB_TMP/count"; rm -f "$SB_TMP/trace"
  _mu_up "$run" PATH="$SB_TMP/cshim:$PATH" KILL_ROOT="$rootp" KILL_NTH=999999999 KILL_COUNT="$SB_TMP/count" KILL_TRACE="$SB_TMP/trace"
  n="$(awk -F'\t' '$2 == "mkdir" && $3 ~ /\.kit-upgrade\/files/ { print $1; exit }' "$SB_TMP/trace" 2>/dev/null)"
  if [ -z "$n" ]; then cf "(a) (control) the counted run made no write to .kit-upgrade/files: $(_mu_flat)"; else
    rm -rf "$run"; cp -R "$SB_WORK" "$run"; rootp="$(cd "$run" && pwd -P)"; echo 0 > "$SB_TMP/count"
    _mu_up "$run" PATH="$SB_TMP/cshim:$PATH" KILL_ROOT="$rootp" KILL_NTH="$n" KILL_COUNT="$SB_TMP/count"
    [ "$_mu_rc" -eq 137 ] || cf "(a) the kill stand-in did not kill (exit $_mu_rc): $(_mu_flat)"
    [ -n "$(find "$SB_TMP/tmp" -mindepth 1 -maxdepth 1 -name 'kit-upgrade-modules.*' 2>/dev/null)" ] \
      || cf "(a) the killed upgrade's scratch (kit-upgrade-modules.*) is not in the sandbox's temp directory: _mu_up did not give the killed run its TMPDIR, so the scratch is left in the machine's temp directory (or kit-upgrade.sh no longer makes one)"
    grep -F -x ' M .claude/roles/example.md' <<<"$(git -C "$run" status --porcelain)" >/dev/null || cf "(a) the kill did not leave the role doc modified: $(git -C "$run" status --porcelain | tr '\n' '|')"
    grep -E '^pending example ' "$run/process/MODULES" >/dev/null || cf "(a) the kill did not leave a pending section"
    _mu_up "$run"
    [ "$_mu_rc" -eq 0 ] || cf "(a) the re-run exited $_mu_rc: $(_mu_flat)"
    printf '%s\n' "$_mu_out" | grep -F 'moved the record' >/dev/null && cf "(a) the re-run after a killed module write was taken as record-only, whose Next commits process/MODULES alone: $(_mu_flat)"
    [ -f "$run/process/UPGRADE-CHECKLIST.md" ] || cf "(a) the re-run wrote no checklist"
    printf '%s\n' "$_mu_out" | grep -F 'Review:' >/dev/null || cf "(a) the re-run's Next does not say to review the whole diff: $(_mu_flat)"
    # the adopter follows it: commit everything, finish, commit; the module is intact
    "${G[@]}" -C "$run" add -A >/dev/null 2>&1; "${G[@]}" -C "$run" commit -q -m "the upgrade" >/dev/null 2>&1
    _mu_rc=0; _mu_out="$( cd "$MU_ELSE" && env -u CLAUDE_PROJECT_DIR "$MU_NEW/scripts/kit-upgrade.sh" --finish --into "$run" 2>&1 </dev/null )" || _mu_rc=$?
    [ "$_mu_rc" -eq 0 ] || cf "(a) --finish exited $_mu_rc: $(_mu_flat)"
    "${G[@]}" -C "$run" add -A >/dev/null 2>&1; "${G[@]}" -C "$run" commit -q -m "finish" >/dev/null 2>&1
    grep -F 'A line the new version adds to the role doc.' "$run/.claude/roles/example.md" >/dev/null || cf "(a) the module's role doc lost the new version's line"
    ( cd "$run" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/rec9" ./scripts/module.sh status example 2>&1 </dev/null ) | grep -E 'edited|missing' >/dev/null && cf "(a) status shows the module's file edited or missing after the adopter followed the Next"
  fi
  teardown

  # (b) a record that cannot be written
  _mu_pair
  m="$MU_NEW/modules/example"
  newv="$(_mu_next_version "$m/module.manifest")"
  sed -e "s/^version: .*/version: $newv/" "$m/module.manifest" > "$m/module.manifest.new" && mv "$m/module.manifest.new" "$m/module.manifest"
  _mu_manifest "$MU_NEW"
  cp "$m/module.manifest" "$SB_WORK/modules/example/module.manifest"; cp "$MU_NEW/process/KIT-MANIFEST" "$SB_WORK/process/KIT-MANIFEST"
  _mu_land "the core files are current"
  chmod a-w "$SB_WORK/process"
  if [ -w "$SB_WORK/process" ]; then chmod u+w "$SB_WORK/process"; echo "      (b) skipped: this user can write a read-only directory"; else
    _mu_up "$SB_WORK"
    chmod u+w "$SB_WORK/process"
    [ "$_mu_rc" -eq 1 ] || cf "(b) a record-only run that could not write the record exited $_mu_rc, not 1: $(_mu_flat)"
    printf '%s\n' "$_mu_out" | grep -F 'upgrade-write-failed' >/dev/null || [ "$(_mu_recs upgrade-write-failed)" -ge 1 ] || cf "(b) no upgrade-write-failed refusal: $(_mu_flat)"
    printf '%s\n' "$_mu_out" | grep -E 'checkout -- \.|UPGRADE-CHECKLIST|\.kit-upgrade/' >/dev/null && cf "(b) the refusal describes the full path's writes or undo: $(_mu_flat 500)"
    printf '%s\n' "$_mu_out" | grep -F 'nothing to undo' >/dev/null || cf "(b) the Next does not say there is nothing to undo: $(_mu_flat 500)"
    [ -z "$(git -C "$SB_WORK" status --porcelain)" ] || cf "(b) the failed run left the tree dirty: $(git -C "$SB_WORK" status --porcelain | tr '\n' '|')"
  fi

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
# CASE — A KILLED kit-upgrade IN A CHECKOUT THAT GIT CONVERTS (core.autocrlf=true, CRLF files) IS FINISHED BY RUNNING IT AGAIN.
#   The same two modules and block hosts as the case above, with PROJECT.md and .gitignore checked out CRLF over LF blobs.
#   The killed run's blocks are compared with the committed file after git's own conversion, so the rerun is not refused as
#   the project's uncommitted change. The first three kill points that leave PROJECT.md changed, the first order only.
# =============================================================================
case_a_killed_kit_upgrade_in_a_crlf_checkout_is_finished_by_running_it_again() {
  cf_reset
  local L="a kit-upgrade killed over two modules that share block hosts, in a checkout with core.autocrlf=true and CRLF files, is finished by running it again, not refused as the project's uncommitted change"
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mu_subject_ok || { finish "$L"; return; }
  local run rootp pts n tried=0
  MU_ENABLE="example second" _mu_pair _mu_shared_hosts_pre
  run="$SB_TMP/run"
  _mu_new_version
  _mu_second_module "$MU_NEW" 0.6.0 blocks; _mu_manifest "$MU_NEW"
  _md_make_count_shim
  git -C "$SB_WORK" config core.autocrlf true
  sed -i.bak 's/$/\r/' "$SB_WORK/PROJECT.md" "$SB_WORK/.gitignore"; rm -f "$SB_WORK/PROJECT.md.bak" "$SB_WORK/.gitignore.bak"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  [ -z "$(git -C "$SB_WORK" status --porcelain)" ] || _control_did_not_run "check PROJECT.md and .gitignore out CRLF with the tree clean"
  rm -rf "$run"; cp -R "$SB_WORK" "$run"; rootp="$(cd "$run" && pwd -P)"; echo 0 > "$SB_TMP/count"; rm -f "$SB_TMP/trace"
  _mu_up "$run" PATH="$SB_TMP/cshim:$PATH" KILL_ROOT="$rootp" KILL_NTH=999999999 KILL_COUNT="$SB_TMP/count" KILL_TRACE="$SB_TMP/trace"
  [ "$_mu_rc" -eq 0 ] || { cf "(control) the counted upgrade exited $_mu_rc: $(_mu_flat)"; finish "$L"; teardown; return; }
  pts="$(_md_kill_points "$SB_TMP/trace" "$rootp" 'PROJECT\.md|\.gitignore')"
  for n in $pts; do
    [ "$tried" -lt 3 ] || break
    rm -rf "$run"; cp -R "$SB_WORK" "$run"
    rootp="$(cd "$run" && pwd -P)"; echo 0 > "$SB_TMP/count"
    _mu_up "$run" PATH="$SB_TMP/cshim:$PATH" KILL_ROOT="$rootp" KILL_NTH="$n" KILL_COUNT="$SB_TMP/count"
    [ "$_mu_rc" -eq 137 ] || { cf "(write $n) exit $_mu_rc, want the kill's 137: $(_mu_flat)"; continue; }
    git -C "$run" status --porcelain | grep -F ' M PROJECT.md' >/dev/null || continue
    tried=$((tried + 1))
    _mu_up "$run"
    [ "$_mu_rc" -eq 0 ] || { cf "(write $n) running the killed upgrade again exited $_mu_rc: $(_mu_flat)"; continue; }
    grep -E '^pending ' "$run/process/MODULES" >/dev/null && cf "(write $n) a pending section is left in the record"
  done
  [ "$tried" -ge 1 ] || cf "(control) no kill point left PROJECT.md changed, so the rerun's refusal was not exercised"
  finish "$L"
  teardown
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
  _refused "an uncommitted block host" upgrade-target-dirty "PROJECT.md" "git stash pop" "commit" --
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

# =============================================================================
# CASE — kit-upgrade REFUSES A FRAGMENT EVERY MINT WOULD REFUSE, BEFORE IT WRITES, AS ENABLE DOES.
#   The new kit's copy of the enabled module changes the fragment it places so that it carries a KIT-MODULES slot line
#   or a control byte (octal 035 to 037). Written over the copy enable wrote, or staged for a merge over the project's
#   edit, it would make every mint of its template refuse. With the fragment clean the same new version is carried.
# =============================================================================
case_kit_upgrade_refuses_a_fragment_every_mint_would_refuse() {
  cf_reset
  local L="kit-upgrade.sh refuses, before it writes, an enabled module's new version whose fragment carries a KIT-MODULES slot line or a control byte (octal 035, 036 or 037), whether it would write the fragment or stage it for a merge: module-fragment-bad, the module's source and the place it would go named, NOTHING WAS CHANGED, a Next: line naming the new kit, the tree byte-equal; the same new version with the fragment clean is carried"
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mu_subject_ok || { finish "$L"; return; }
  _mu_pair
  _mu_new_version
  local s0="$SB_TMP/snap0" s1="$SB_TMP/snap1" src="$MU_NEW/modules/example/fragments/issue-sign-off.txt" placed="process/fragments.d/ISSUE/example.body-end" keep="$SB_TMP/frag.keep" b
  [ -f "$src" ] && [ -f "$SB_WORK/$placed" ] \
    || _fixture_die "case_kit_upgrade_refuses_a_fragment_every_mint_would_refuse: the example module's ISSUE body-end fragment is not fragments/issue-sign-off.txt placed as $placed, so this case would change nothing."
  cp "$src" "$keep"
  # An upgrade that went through is undone, so the next row starts from the committed tree. A tree that does not come
  # back is a fixture failure: every row after it would read another subject.
  _uf_back() {  # <label>
    git -C "$SB_WORK" checkout -q -- . && git -C "$SB_WORK" clean -fdq
    _md_snap "$SB_WORK" > "$s1"
    cmp -s "$s0" "$s1" || _fixture_die "case_kit_upgrade_refuses_a_fragment_every_mint_would_refuse: the tree did not come back after the upgrade of row ($1): $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-240)"
  }
  _uf_bad() {  # <label> <line the new kit's fragment gains> <what the refusal must say>
    { cat "$keep"; printf '%s\n' "$2"; } > "$src"; _mu_manifest "$MU_NEW"
    _md_snap "$SB_WORK" > "$s0"
    _mu_up "$SB_WORK"
    [ "$_mu_rc" -eq 1 ] || cf "($1) the upgrade was not refused (exit $_mu_rc): $(_mu_flat)"
    [ "$(_mu_recs module-fragment-bad)" -ge 1 ] || cf "($1) no refusal=module-fragment-bad record: $(_mu_flat)"
    printf '%s\n' "$_mu_out" | grep -F "modules/example/fragments/issue-sign-off.txt (placed as $placed) $3" >/dev/null \
      || cf "($1) the refusal does not name the module's source, the place it would go and '$3': $(_mu_flat)"
    printf '%s\n' "$_mu_out" | grep -F 'NOTHING WAS CHANGED' >/dev/null || cf "($1) the refusal does not say NOTHING WAS CHANGED"
    printf '%s\n' "$_mu_out" | grep -F "Next: fix each file named above under $MU_NEW" >/dev/null || cf "($1) no Next: line naming the new kit: $(_mu_flat)"
    [ ! -e "$SB_WORK/.kit-upgrade" ] && [ ! -e "$SB_WORK/process/UPGRADE-CHECKLIST.md" ] || cf "($1) the upgrade left staging or a checklist"
    _md_snap "$SB_WORK" > "$s1"
    cmp -s "$s0" "$s1" || { cf "($1) the upgrade changed the tree: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-240)"; _uf_back "$1"; }
  }
  # (a) the fragment as enable wrote it: the upgrade would write the new copy over it.
  _uf_bad markers '<!-- KIT-MODULES:body-end leaked -->' 'carries a KIT-MODULES slot line'
  for b in 035 036 037; do _uf_bad "control $b" "one$(printf "\\$b")two" 'holds a control byte'; done

  # (control) the same new version with the fragment clean is carried: the fragment is written. The tree is then put back.
  { cat "$keep"; printf 'A clean line the new version adds.\n'; } > "$src"; _mu_manifest "$MU_NEW"
  _md_snap "$SB_WORK" > "$s0"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(control) the upgrade with the fragment clean exited $_mu_rc: $(_mu_flat)"
  [ "$(tail -1 "$SB_WORK/$placed")" = "A clean line the new version adds." ] || cf "(control) the clean fragment was not written"
  _uf_back control

  # (b) the project edited the fragment: the upgrade would stage the new copy for a merge.
  printf 'the project own line\n' >> "$SB_WORK/$placed"; _mu_land "the project's edit to the fragment"
  _uf_bad "staged for a merge" "one$(printf '\036')two" 'holds a control byte'
  unset -f _uf_bad _uf_back

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

  # (b3) the staged copy swapped for another file the module ships (its manifest row is real): the checklist's item has no entry in it.
  cp "$MU_NEW/modules/example/SETUP.md" "$SB_WORK/.kit-upgrade/module-notes/example.kit-new"
  _mu_land "the staged module notes, swapped"
  rc=0; out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/rec-fin4" ./scripts/kit-upgrade.sh --finish --into "$SB_WORK" 2>&1 </dev/null )" || rc=$?
  [ "$rc" -eq 1 ] || cf "(b3) --finish over swapped staged module notes exited $rc, want the refusal's 1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  grep -h 'refusal=upgrade-staging-edited' "$SB_TMP"/rec-fin4/*.tsv >/dev/null 2>&1 || cf "(b3) no refusal=upgrade-staging-edited record: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  cp "$SB_TMP/example-notes-staged" "$SB_WORK/.kit-upgrade/module-notes/example.kit-new"
  _mu_land "the staged module notes, restored again"

  # (b4) the module's key renumbered in the item list only: the module's notes are untouched, so the printed restore names the item list.
  sed -i.bak 's/^\(module example, Action required, \[[^]]*\] item \)[0-9][0-9]*$/\19/' "$SB_WORK/.kit-upgrade/action-items"; rm -f "$SB_WORK/.kit-upgrade/action-items.bak"
  _mu_land "the staged item list, renumbered"
  rc=0; out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/rec-fin5" ./scripts/kit-upgrade.sh --finish --into "$SB_WORK" 2>&1 </dev/null )" || rc=$?
  [ "$rc" -eq 1 ] || cf "(b4) --finish over a renumbered module key exited $rc, want the refusal's 1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  restore="$(printf '%s\n' "$out" | grep -E '^  git -C' | sed -n 1p)"
  case "$restore" in *action-items*) ;; *) cf "(b4) the printed restore does not name the item list: $restore" ;; esac
  [ -z "$restore" ] || bash -c "$restore" >/dev/null 2>&1
  rc=0; out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/rec-fin6" ./scripts/kit-upgrade.sh --finish --into "$SB_WORK" 2>&1 </dev/null )" || rc=$?
  grep -h 'refusal=upgrade-verify-failed' "$SB_TMP"/rec-fin6/*.tsv >/dev/null 2>&1 || cf "(b4) after the printed restore, --finish did not reach the Verify: step: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"

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

# =============================================================================
# CASE — module.sh status WITH NO NAME ENDS NON-ZERO ON A REFUSAL, AS status <name> DOES.
#   Operand: an enabled module's process/MODULES with (a) a `module` line whose name is not a module name, and
#   (b) a `file` row of the enabled module whose path leaves the project. Each is a refusal; status must end 1
#   with it, not print it and end 0. (control) The record clean: status ends 0.
# =============================================================================
case_module_status_with_no_name_ends_non_zero_on_a_refusal() {
  cf_reset
  local L="module.sh status with no name ends 1, printing the Error and a Next: line and writing the refusal's record, when process/MODULES names a module whose name is not a module name or an enabled module's file row whose path leaves the project, as status <name> does; with the record clean it ends 0"
  if ! _md_have_example; then skp_lived "$L" "$(_md_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  local miss; miss="$(_md_missing_program)"
  [ -z "$miss" ] || { cf "(prereq) $miss is absent from the tree under test"; finish "$L"; return; }
  _md_sandbox
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || { cf "(prereq) enable exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-200)"; finish "$L"; teardown; return; }
  local rec="$SB_WORK/process/MODULES" row line id
  cp "$rec" "$SB_TMP/MODULES.clean"
  _md_mod status
  [ "$_md_rc" -eq 0 ] || cf "(control) status over a clean record exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  printf 'outside\n' > "$SB_TMP/outside.txt"
  # <row>@<line appended to process/MODULES>@<refusal id>
  while IFS='@' read -r row line id; do
    [ -n "$row" ] || continue
    cp "$SB_TMP/MODULES.clean" "$rec"
    printf '%s\n' "$line" >> "$rec"
    _md_mod status
    [ "$_md_rc" -eq 1 ] || cf "($row) status with no name exited $_md_rc after the refusal, not 1: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
    printf '%s\n' "$_md_out" | grep -F 'Error:' >/dev/null && printf '%s\n' "$_md_out" | grep -F 'Next:' >/dev/null \
      || cf "($row) status printed no Error and Next: lines: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
    [ "$(_md_recs "$id")" -ge 1 ] || cf "($row) no refusal=$id record"
  done <<ST_ROWS
a module line that is no module name@module ../x 1.0.0@module-name-bad
a file row that leaves the project@file $(_old_sha "$SB_TMP/outside.txt") ../outside.txt@module-record-bad
ST_ROWS
  cp "$SB_TMP/MODULES.clean" "$rec"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A RECORD-ONLY RUN IS SENT TO THE FULL PATH BY AN UNCOMMITTED CHANGE IN WHAT THE MODULE PLACES, NOT BY ONE ELSEWHERE IN A FILE IT ONLY ADDS A BLOCK TO.
#   The module's version moved and nothing it places did. (a) An uncommitted edit outside the module's blocks in
#   PROJECT.md and .gitignore: the record is moved, nothing staged, and the edits are left as they were. (b) An edit
#   inside the block: the full path. (c) An edit to a file the module places: the full path. (d) A block host that
#   is untracked, with the block in it: the full path. (e) A block copied, copied and edited, or opened by a lone
#   BEGIN: the full path. (f) A change staged inside the block with the file put back: the full path. (g) A deleted
#   host: the full path, with no reader error.
# =============================================================================
case_a_record_only_kit_upgrade_looks_at_a_blocks_own_lines_in_its_host() {
  cf_reset
  local L="kit-upgrade.sh over a project whose only work is an enabled module's record moves the record and stages nothing when the uncommitted edit is elsewhere in a file the module only adds a block to, and takes the full path when the edit is inside the block, in a file the module places, or in a host with the block that git does not track, a duplicated or lone-marker block, a change staged inside the block, or a deleted host"
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _mu_subject_ok || { finish "$L"; return; }
  local m newv tag

  for tag in outside inside role untracked dup dupedit lonebegin staged deleted; do
    _mu_pair
    m="$MU_NEW/modules/example"
    newv="$(_mu_next_version "$m/module.manifest")"
    sed -e "s/^version: .*/version: $newv/" "$m/module.manifest" > "$m/module.manifest.new" && mv "$m/module.manifest.new" "$m/module.manifest"
    _mu_manifest "$MU_NEW"
    cp "$m/module.manifest" "$SB_WORK/modules/example/module.manifest"; cp "$MU_NEW/process/KIT-MANIFEST" "$SB_WORK/process/KIT-MANIFEST"
    _mu_land "the core files are current"
    case "$tag" in
      outside)
        printf 'An unrelated line.\n' >> "$SB_WORK/PROJECT.md"
        printf 'unrelated-ignore\n' >> "$SB_WORK/.gitignore" ;;
      inside)
        sed -e '/KIT-MODULE:example:gates BEGIN/a\
| mine | `y` | edited inside the block |' "$SB_WORK/PROJECT.md" > "$SB_TMP/p.md" && cp "$SB_TMP/p.md" "$SB_WORK/PROJECT.md" ;;
      role)
        printf 'A line the project added.\n' >> "$SB_WORK/.claude/roles/example.md" ;;
      untracked)
        git -C "$SB_WORK" rm -q --cached .gitignore >/dev/null 2>&1
        sbcommit -q -m "untrack the ignore file" >/dev/null 2>&1 ;;
      dup)
        awk '/KIT-MODULE:example:gates BEGIN/ { f = 1 } f { print } /KIT-MODULE:example:gates END/ { f = 0 }' "$SB_WORK/PROJECT.md" >> "$SB_WORK/PROJECT.md" ;;
      dupedit)
        awk '/KIT-MODULE:example:gates BEGIN/ { f = 1 } f { print } /KIT-MODULE:example:gates END/ { f = 0 }' "$SB_WORK/PROJECT.md" | sed -e '/KIT-MODULE/!s/$/ edited/' >> "$SB_WORK/PROJECT.md" ;;
      lonebegin)
        printf '<!-- KIT-MODULE:example:gates BEGIN -->\n' >> "$SB_WORK/PROJECT.md" ;;
      staged)
        cp "$SB_WORK/PROJECT.md" "$SB_TMP/p-head.md"
        sed -e '/KIT-MODULE:example:gates BEGIN/a\
| mine | `y` | staged inside the block |' "$SB_TMP/p-head.md" > "$SB_WORK/PROJECT.md"
        git -C "$SB_WORK" add PROJECT.md >/dev/null 2>&1
        cp "$SB_TMP/p-head.md" "$SB_WORK/PROJECT.md" ;;
      deleted)
        rm -f "$SB_WORK/PROJECT.md" ;;
    esac
    _mu_up "$SB_WORK"
    [ "$_mu_rc" -eq 0 ] || cf "($tag) the upgrade exited $_mu_rc: $(_mu_flat)"
    if [ "$tag" = outside ]; then
      printf '%s\n' "$_mu_out" | grep -F 'moved the record' >/dev/null || cf "($tag) the run does not say it moved the record: $(_mu_flat)"
      { [ ! -e "$SB_WORK/process/UPGRADE-CHECKLIST.md" ] && [ ! -e "$SB_WORK/.kit-upgrade" ]; } || cf "($tag) a checklist or staging was written for a record-only run"
      grep -F 'An unrelated line.' "$SB_WORK/PROJECT.md" >/dev/null && grep -F 'unrelated-ignore' "$SB_WORK/.gitignore" >/dev/null || cf "($tag) the project's own edits were not left as they were"
      grep -F -x "module example $newv" "$SB_WORK/process/MODULES" >/dev/null || cf "($tag) the record does not name $newv"
    else
      printf '%s\n' "$_mu_out" | grep -F 'moved the record' >/dev/null && cf "($tag) the run was taken as record-only over an uncommitted change in what the module places: $(_mu_flat)"
      printf '%s\n' "$_mu_out" | grep -F 'Review:' >/dev/null || cf "($tag) the run does not say to review the whole diff: $(_mu_flat)"
      printf '%s\n' "$_mu_out" | grep -F "can't open" >/dev/null && cf "($tag) the run printed a reader error: $(_mu_flat)"
    fi
    teardown
  done

  finish "$L"
}

# =============================================================================
# CASE — A FAILED module.sh disable KEEPS EVERY ROW OF THE MODULE, SO AN UPGRADE READS THE FILES IT REMOVED AS REMOVED.
#   A disable that cannot remove one placed file removes the others and refuses. The record then still holds all the
#   module's rows. An upgrade at the same kit version places nothing the disable removed, status reads the module as
#   enabled with those files missing, and the disable run again, once the file can be removed, finishes: the record
#   is dropped and nothing of the module is left.
# =============================================================================
case_a_failed_module_disable_keeps_every_row_until_the_disable_finishes() {
  cf_reset
  local L="a failed module.sh disable keeps every row of the module in the record, a kit-upgrade.sh run before the disable finishes does not place again the files the disable removed, and the disable run again finishes: the record is dropped and no file or block of the module is left"
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum)"; return; }
  if _pw_is_root; then skp "$L" "running as root: chmod cannot make a path unwritable"; return; fi
  _mu_subject_ok || { finish "$L"; return; }
  local rows0 f
  _mu_pair
  rows0="$(grep -cE '^(file|block) ' "$SB_WORK/process/MODULES")"
  chmod 555 "$SB_WORK/process/roles.d"
  _md_mod disable example
  [ "$_md_rc" -ne 0 ] || cf "(prereq) disable exited 0 although process/roles.d/example could not be removed"
  chmod 755 "$SB_WORK/process/roles.d"
  [ ! -e "$SB_WORK/.claude/roles/example.md" ] || cf "(prereq) the failed disable did not remove the module's other files"
  [ "$(grep -cE '^(file|block) ' "$SB_WORK/process/MODULES")" = "$rows0" ] \
    || cf "(a) the record holds $(grep -cE '^(file|block) ' "$SB_WORK/process/MODULES") rows after the failed disable, not all $rows0: $(grep -E '^(file|block) ' "$SB_WORK/process/MODULES" | awk '{print $3}' | tr '\n' ' ')"
  _md_mod status example
  printf '%s\n' "$_md_out" | grep -F 'not enabled' >/dev/null && cf "(a) status calls the module not enabled while its role layer acts: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-200)"
  _mu_land "after the failed disable"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(b) the upgrade exited $_mu_rc: $(_mu_flat)"
  for f in .claude/roles/example.md .claude/skills/example-skill/SKILL.md; do
    [ ! -e "$SB_WORK/$f" ] || cf "(b) the upgrade placed $f again, which the disable had removed: $(_mu_flat)"
  done
  grep -F 'The example module' "$SB_WORK/PROJECT.md" >/dev/null && cf "(b) the upgrade put the module's block back in PROJECT.md"
  _md_mod disable example
  [ "$_md_rc" -eq 0 ] || cf "(c) the disable run again exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  grep -E '^(module|file|block|kept|pending) ' "$SB_WORK/process/MODULES" >/dev/null 2>&1 && cf "(c) the record still has rows after the disable finished: $(grep -E '^(module|file|block|kept|pending) ' "$SB_WORK/process/MODULES" | tr '\n' '|' | cut -c1-200)"
  [ ! -e "$SB_WORK/process/roles.d/example" ] || cf "(c) process/roles.d/example is still there"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — module.sh enable AND status OVER A MODULE WHOSE DISABLE FAILED PART-WAY SAY SO AND NAME THE WAY ON.
#   The record still names the module, so enable says it is already enabled, exits 0 and places nothing; the files the
#   failed disable removed stay removed and the record keeps all its rows. Both commands add that recorded things
#   are missing, with both readings (removed here, or left by a disable that stopped part-way, which the disable run again
#   finishes). A module with every recorded thing present, or whose missing things the manifest no longer places, gets no
#   such line.
# =============================================================================
case_module_enable_and_status_after_a_failed_disable_name_the_way_on() {
  cf_reset
  local L="module.sh enable and status over a module whose disable failed part-way say it is already enabled (exit 0, nothing placed, every row kept) and name both readings of what is missing (removed here, or left by a disable that stopped part-way) and the disable run again; a module with nothing missing that the manifest still places gets no such line"
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum)"; return; }
  if _pw_is_root; then skp "$L" "running as root: chmod cannot make a path unwritable"; return; fi
  _mu_subject_ok || { finish "$L"; return; }
  local rows0
  _mu_pair
  _md_mod enable example
  printf '%s\n' "$_md_out" | grep -F 'recorded things are missing' >/dev/null && cf "(control) enable over an intact module names missing things: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  _md_mod status example
  printf '%s\n' "$_md_out" | grep -F 'recorded things are missing' >/dev/null && cf "(control) status over an intact module names missing things: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  rows0="$(grep -cE '^(file|block) ' "$SB_WORK/process/MODULES")"
  chmod 555 "$SB_WORK/process/roles.d"
  _md_mod disable example
  [ "$_md_rc" -ne 0 ] || cf "(prereq) disable exited 0 although process/roles.d/example could not be removed"
  chmod 755 "$SB_WORK/process/roles.d"
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || cf "(enable) over a half-disabled module exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$_md_out" | grep -F 'already enabled' >/dev/null || cf "(enable) does not say the module is already enabled: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$_md_out" | grep -F "$((rows0 - 1)) of $rows0 recorded things are missing" >/dev/null || cf "(enable) does not count the missing things ($((rows0 - 1)) of $rows0): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$_md_out" | grep -F './scripts/module.sh disable example' >/dev/null || cf "(enable) does not name the disable run again: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  [ ! -e "$SB_WORK/.claude/roles/example.md" ] || cf "(enable) placed the role doc the failed disable had removed"
  grep -F 'The example module' "$SB_WORK/PROJECT.md" >/dev/null && cf "(enable) put the module's block back in PROJECT.md"
  [ "$(grep -cE '^(file|block) ' "$SB_WORK/process/MODULES")" = "$rows0" ] || cf "(enable) the record holds $(grep -cE '^(file|block) ' "$SB_WORK/process/MODULES") rows, not all $rows0"
  _md_mod status example
  printf '%s\n' "$_md_out" | grep -F "$((rows0 - 1)) of $rows0 recorded things are missing" >/dev/null || cf "(status) does not count the missing things: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$_md_out" | grep -F './scripts/module.sh disable example' >/dev/null || cf "(status) does not name the disable run again: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$_md_out" | grep -F 'removed here (commit the removal if it is on purpose; git restores one), or left by a disable that stopped part-way' >/dev/null || cf "(status) does not name both readings: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  teardown

  # a file the project deleted by hand: the same line, with both readings
  _mu_pair
  rm -f "$SB_WORK/.claude/skills/example-skill/SKILL.md"
  _md_mod status example
  printf '%s\n' "$_md_out" | grep -F "1 of $rows0 recorded things are missing, and their removal is not committed: removed here (commit the removal if it is on purpose; git restores one), or left by a disable that stopped part-way (./scripts/module.sh disable example finishes it)." >/dev/null \
    || cf "(hand) status over a deleted file does not give the line with both readings: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  teardown

  # a recorded file the module's manifest no longer places, deleted as the upgrade's item says: no line, in either command
  _mu_pair
  sed -e '/^file: _claude\/skills\/example-skill\/SKILL.md/d' "$SB_WORK/modules/example/module.manifest" > "$SB_TMP/manifest.new" && cp "$SB_TMP/manifest.new" "$SB_WORK/modules/example/module.manifest"
  rm -f "$SB_WORK/.claude/skills/example-skill/SKILL.md"
  _md_mod status example
  printf '%s\n' "$_md_out" | grep -F 'recorded things are missing' >/dev/null && cf "(unplaced) status names a row the manifest no longer places: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  _md_mod enable example
  printf '%s\n' "$_md_out" | grep -F 'recorded things are missing' >/dev/null && cf "(unplaced) enable names a row the manifest no longer places: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE MISSING-THINGS LINE COUNTS A MISSING THING ONLY WHILE ITS REMOVAL IS NOT COMMITTED.
#   A file or block the project removed and committed, from a commit that records the module, is the project's own
#   choice: status and enable stay quiet about it. A removal not yet committed (deleted, or staged with git rm) still
#   counts, and so does one from an enable that was never committed (the state a disable killed part-way leaves before
#   any commit). With one of each, only the uncommitted one is counted.
# =============================================================================
case_the_missing_things_line_counts_only_a_removal_not_committed() {
  cf_reset
  local L="status and enable count a missing file or block only while its removal is not committed: a committed removal gets no line; an unstaged or staged removal, and one from an enable never committed, get the line; with one of each only the uncommitted one is counted"
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum)"; return; }
  _mu_subject_ok || { finish "$L"; return; }
  local rows0 skill=".claude/skills/example-skill/SKILL.md" role=".claude/roles/example.md"
  _mu_pair
  rows0="$(grep -cE '^(file|block) ' "$SB_WORK/process/MODULES")"
  # a file removed and committed: no line, in either command
  git -C "$SB_WORK" rm -q -- "$skill" >/dev/null 2>&1
  _mu_land "remove the example skill on purpose"
  [ ! -e "$SB_WORK/$skill" ] || cf "(prereq) $skill is still there after its removal was committed"
  _md_mod status example
  printf '%s\n' "$_md_out" | grep -F 'recorded things are missing' >/dev/null && cf "(committed file) status names a removal that is committed: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  _md_mod enable example
  printf '%s\n' "$_md_out" | grep -F 'recorded things are missing' >/dev/null && cf "(committed file) enable names a removal that is committed: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  # ...and a second file removed but not committed: only that one is counted
  rm -f "$SB_WORK/$role"
  _md_mod status example
  printf '%s\n' "$_md_out" | grep -F "1 of $rows0 recorded things are missing, and their removal is not committed: removed here (commit the removal if it is on purpose; git restores one), or left by a disable that stopped part-way (./scripts/module.sh disable example finishes it)." >/dev/null \
    || cf "(one of each) status does not count the one uncommitted removal alone: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  # ...staged with git rm, still not committed: still counted
  git -C "$SB_WORK" rm -q --cached -- "$role" >/dev/null 2>&1
  _md_mod enable example
  printf '%s\n' "$_md_out" | grep -F "1 of $rows0 recorded things are missing" >/dev/null || cf "(staged file) enable does not count a removal staged and not committed: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  teardown

  # a block removed: counted until the removal is committed, then not
  _mu_pair
  awk '/KIT-MODULE:example:gates BEGIN/ { s = 1 } !s { print } /KIT-MODULE:example:gates END/ { s = 0 }' "$SB_WORK/PROJECT.md" > "$SB_TMP/project.new" && cp "$SB_TMP/project.new" "$SB_WORK/PROJECT.md"
  grep -F 'KIT-MODULE:example:gates' "$SB_WORK/PROJECT.md" >/dev/null && cf "(prereq) the block is still in PROJECT.md"
  _md_mod status example
  printf '%s\n' "$_md_out" | grep -F "1 of $rows0 recorded things are missing" >/dev/null || cf "(uncommitted block) status does not count a block removed and not committed: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  _mu_land "drop the example gate row on purpose"
  printf '%s\n' "unrelated line" >> "$SB_WORK/PROJECT.md"
  _md_mod status example
  printf '%s\n' "$_md_out" | grep -F 'recorded things are missing' >/dev/null && cf "(committed block) status names a block removal that is committed (the host has another, unrelated edit): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  _md_mod enable example
  printf '%s\n' "$_md_out" | grep -F 'recorded things are missing' >/dev/null && cf "(committed block) enable names a block removal that is committed: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  teardown

  # an enable that was never committed, a file then gone: counted, though git shows no change at the path
  _mu_pair
  _md_mod disable example
  [ "$_md_rc" -eq 0 ] || cf "(prereq) disable exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  _mu_land "disable the example module"
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || cf "(prereq) the enable again exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  rm -f "$SB_WORK/$skill"
  [ -z "$(git -C "$SB_WORK" status --porcelain -- "$skill")" ] || cf "(prereq) git shows a change at $skill, so this row does not test an enable never committed"
  _md_mod status example
  printf '%s\n' "$_md_out" | grep -F "1 of $rows0 recorded things are missing" >/dev/null || cf "(never committed) status does not count a file gone from an enable that was never committed: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  _md_mod enable example
  printf '%s\n' "$_md_out" | grep -F "1 of $rows0 recorded things are missing" >/dev/null || cf "(never committed) enable does not count it: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — module.sh disable WHOSE RECORD CANNOT BE WRITTEN OR DROPPED EXITS 1, SAYS HOW MUCH WAS ALREADY REMOVED, AND THE RE-RUN FINISHES.
#   (a) The record cannot be dropped after every removal succeeded: the old exit 0 and "record dropped" over a record that
#   stayed is gone. (b) A removal fails and the record write fails too: the refusal names how many were removed. In
#   both the record keeps every row, and once process/ is writable the disable run again finishes.
# =============================================================================
case_module_disable_says_so_when_the_record_cannot_be_written() {
  cf_reset
  local L="module.sh disable exits 1 and does not say the record was dropped when process/MODULES cannot be dropped or written, names how many files and blocks were already removed, leaves every row, and the disable run again finishes"
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum)"; return; }
  if _pw_is_root; then skp "$L" "running as root: chmod cannot make a path unwritable"; return; fi
  _mu_subject_ok || { finish "$L"; return; }
  local rows0 shape
  for shape in drop write; do
    _mu_pair
    rows0="$(grep -cE '^(file|block) ' "$SB_WORK/process/MODULES")"
    chmod 555 "$SB_WORK/process"
    [ "$shape" = write ] && chmod 555 "$SB_WORK/process/roles.d"
    _md_mod disable example
    chmod 755 "$SB_WORK/process"; [ "$shape" = write ] && chmod 755 "$SB_WORK/process/roles.d"
    [ "$_md_rc" -eq 1 ] || cf "($shape) disable exited $_md_rc, not 1: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
    printf '%s\n' "$_md_out" | grep -F 'record dropped' >/dev/null && cf "($shape) said the record was dropped over a record that stayed: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
    printf '%s\n' "$_md_out" | grep -E 'already removed' >/dev/null || cf "($shape) does not say how many were already removed: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
    if [ "$shape" = write ]; then
      printf '%s\n' "$_md_out" | grep -F 'process/roles.d/example' >/dev/null || cf "($shape) does not name the path that could not be removed: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
      printf '%s\n' "$_md_out" | grep -F 'retries' >/dev/null || cf "($shape) does not say that running disable again retries it: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
    fi
    [ "$(grep -cE '^(file|block) ' "$SB_WORK/process/MODULES")" = "$rows0" ] || cf "($shape) the record does not hold all $rows0 rows"
    _md_mod disable example
    [ "$_md_rc" -eq 0 ] || cf "($shape) the disable run again exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
    grep -E '^(module|file|block|kept|pending) ' "$SB_WORK/process/MODULES" >/dev/null 2>&1 && cf "($shape) the record still has rows after the disable finished"
    teardown
  done
  finish "$L"
}

# =============================================================================
# CASE — AN UPGRADE OVER A HALF-DISABLED MODULE READS WHAT THE DISABLE REMOVED AS REMOVED, IN EVERY SHAPE.
#   (a) A block that could not be removed: the same-version upgrade changes nothing and the disable run again takes the
#   block. (b) A module version that changes a removed file raises the merge item, never placing the file. (c) A run whose
#   only work is the record moves it, keeps every row, and places nothing.
# =============================================================================
case_an_upgrade_over_a_half_disabled_module_reads_removed_files_as_removed() {
  cf_reset
  local L="kit-upgrade.sh over a module whose disable failed part-way places no file the disable removed: a failed block removal stays as it was and the disable run again takes it, a module version that changes a removed file raises a merge item and does not place it, and a record-only run keeps every row"
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum)"; return; }
  if _pw_is_root; then skp "$L" "running as root: chmod cannot make a path unwritable"; return; fi
  _mu_subject_ok || { finish "$L"; return; }
  local rows0 m newv

  # (a) the block cannot be removed.
  _mu_pair
  rows0="$(grep -cE '^(file|block) ' "$SB_WORK/process/MODULES")"
  chmod 444 "$SB_WORK/PROJECT.md"
  _md_mod disable example
  chmod 644 "$SB_WORK/PROJECT.md"
  [ "$_md_rc" -ne 0 ] || cf "(a) disable exited 0 although PROJECT.md could not be rewritten"
  [ "$(grep -cE '^(file|block) ' "$SB_WORK/process/MODULES")" = "$rows0" ] || cf "(a) the record does not hold all $rows0 rows after the failed block removal"
  _mu_land "after the failed block removal"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(a) the upgrade exited $_mu_rc: $(_mu_flat)"
  [ ! -e "$SB_WORK/.claude/roles/example.md" ] || cf "(a) the upgrade placed the role doc the disable had removed"
  _md_mod disable example
  [ "$_md_rc" -eq 0 ] || cf "(a) the disable run again exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  grep -F 'KIT-MODULE:example' "$SB_WORK/PROJECT.md" >/dev/null && cf "(a) the block is still in PROJECT.md after the disable run again"
  teardown

  # (b) a later module version changes a removed file.
  _mu_pair
  chmod 555 "$SB_WORK/process/roles.d"
  _md_mod disable example
  chmod 755 "$SB_WORK/process/roles.d"
  _mu_land "after the failed disable"
  _mu_new_version
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(b) the upgrade exited $_mu_rc: $(_mu_flat)"
  [ ! -e "$SB_WORK/.claude/roles/example.md" ] || cf "(b) the upgrade placed the role doc the disable had removed, which the new version changed"
  grep -F 'merge .claude/roles/example.md — module example' "$SB_WORK/process/UPGRADE-CHECKLIST.md" >/dev/null 2>&1 \
    || cf "(b) no merge item for the removed role doc: $(grep -F example "$SB_WORK/process/UPGRADE-CHECKLIST.md" 2>/dev/null | tr '\n' '|' | cut -c1-300)"
  teardown

  # (c) a run whose only work is the record.
  _mu_pair
  rows0="$(grep -cE '^(file|block) ' "$SB_WORK/process/MODULES")"
  m="$MU_NEW/modules/example"
  newv="$(_mu_next_version "$m/module.manifest")"
  sed -e "s/^version: .*/version: $newv/" "$m/module.manifest" > "$m/module.manifest.new" && mv "$m/module.manifest.new" "$m/module.manifest"
  _mu_manifest "$MU_NEW"
  cp "$m/module.manifest" "$SB_WORK/modules/example/module.manifest"; cp "$MU_NEW/process/KIT-MANIFEST" "$SB_WORK/process/KIT-MANIFEST"
  chmod 555 "$SB_WORK/process/roles.d"
  _md_mod disable example
  chmod 755 "$SB_WORK/process/roles.d"
  _mu_land "after the failed disable"
  _mu_up "$SB_WORK"
  [ "$_mu_rc" -eq 0 ] || cf "(c) the upgrade exited $_mu_rc: $(_mu_flat)"
  printf '%s\n' "$_mu_out" | grep -F 'moved the record' >/dev/null || cf "(c) the run does not say it moved the record: $(_mu_flat)"
  [ "$(grep -cE '^(file|block) ' "$SB_WORK/process/MODULES")" = "$rows0" ] || cf "(c) the record does not keep all $rows0 rows"
  [ ! -e "$SB_WORK/.claude/roles/example.md" ] || cf "(c) the record-only run placed the role doc the disable had removed"
  grep -F -x "module example $newv" "$SB_WORK/process/MODULES" >/dev/null || cf "(c) the record does not name $newv"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — module.sh enable KEEPS THE REASON A PLACEMENT FAILED WHEN THE RECORD CANNOT BE DROPPED, AND A VALUE IN THE ENVIRONMENT IS NEVER IN A REFUSAL.
#   A placed file cannot be written and the empty record cannot be removed: the refusal says why the placement failed, not
#   only that the record could not be written. A KIT_MOD_STATE_NOTE the user exported does not reach any refusal.
# =============================================================================
case_module_enable_keeps_the_reason_a_placement_failed_and_ignores_an_exported_note() {
  cf_reset
  local L="module.sh enable whose placement fails and whose empty record cannot be removed says which path could not be written, and an exported KIT_MOD_STATE_NOTE is in no refusal"
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum)"; return; }
  if _pw_is_root; then skp "$L" "running as root: chmod cannot make a path unwritable"; return; fi
  _md_have_example || { skp_lived "$L" "$(_md_gone_reason)"; return; }
  _md_sandbox
  local shim="$SB_TMP/shim"
  mkdir -p "$shim" "$SB_WORK/.claude/roles"
  printf '#!/bin/sh\nfor a in "$@"; do case "$a" in */process/MODULES) exit 1 ;; esac; done\nexec /bin/rm "$@"\n' > "$shim/rm"
  chmod +x "$shim/rm"
  chmod 555 "$SB_WORK/.claude/roles"
  _md_rc=0; _md_out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR PATH="$shim:$PATH" KIT_MOD_STATE_NOTE="leaked from the environment" KIT_PROGRESS_DIR="$SB_TMP/records" ./scripts/module.sh enable example 2>&1 </dev/null )" || _md_rc=$?
  chmod 755 "$SB_WORK/.claude/roles"
  [ "$_md_rc" -ne 0 ] || cf "enable exited 0 although a placed file could not be written"
  printf '%s\n' "$_md_out" | grep -F 'Could not write .claude/roles/example.md either' >/dev/null || cf "the refusal does not keep the path that could not be written: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$_md_out" | grep -F 'leaked from the environment' >/dev/null && cf "an exported KIT_MOD_STATE_NOTE is in the refusal: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE COMMIT HINT OF A DISABLE RUN AGAIN STAGES WHAT THE FIRST RUN REMOVED, TOO, AND NOTHING ELSE.
#   The first run removes every file and cannot drop the record; the run again finds them already gone. Following the
#   Next line it prints (git add -A over the paths it names) leaves no deletion behind. Before the first run the project
#   removed the block in PROJECT.md by hand and committed that; before the run again it edits PROJECT.md and a tracked
#   file of its own. Neither edit is the module's: both are still unstaged after the hint, and nothing else is.
# =============================================================================
case_the_commit_hint_of_a_disable_run_again_stages_what_the_first_run_removed() {
  cf_reset
  local L="following the commit hint a module.sh disable run again prints, after a first run that removed the files but could not drop the record, stages every removal and leaves only the project's own edits (one in a block host whose block was removed and committed, one in another tracked file) unstaged"
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum)"; return; }
  if _pw_is_root; then skp "$L" "running as root: chmod cannot make a path unwritable"; return; fi
  _mu_subject_ok || { finish "$L"; return; }
  local hint staged unstaged other
  _mu_pair
  awk '/KIT-MODULE:example:gates BEGIN/ { s = 1 } !s { print } /KIT-MODULE:example:gates END/ { s = 0 }' "$SB_WORK/PROJECT.md" > "$SB_TMP/project.new" && cp "$SB_TMP/project.new" "$SB_WORK/PROJECT.md"
  _mu_land "drop the example gate row on purpose"
  chmod 555 "$SB_WORK/process"
  _md_mod disable example
  chmod 755 "$SB_WORK/process"
  [ "$_md_rc" -ne 0 ] || cf "(prereq) the first disable exited 0 although the record could not be dropped"
  printf '%s\n' "a line of the project's own" >> "$SB_WORK/PROJECT.md"
  other="$(git -C "$SB_WORK" ls-files -- scripts/config.sh)"
  [ -n "$other" ] || cf "(prereq) scripts/config.sh is not tracked in the sandbox"
  printf '%s\n' "# a line of the project's own" >> "$SB_WORK/scripts/config.sh"
  _md_mod disable example
  [ "$_md_rc" -eq 0 ] || cf "the disable run again exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  hint="$(printf '%s\n' "$_md_out" | sed -n 's/^  \(git add -A -- .*\)$/\1/p')"
  [ -n "$hint" ] || cf "the run again prints no commit hint: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  if [ -n "$hint" ]; then
    ( cd "$SB_WORK" && eval "$hint" ) >/dev/null 2>&1 || cf "the printed hint failed when run: $hint"
    staged="$(git -C "$SB_WORK" diff --cached --name-only 2>/dev/null)"
    unstaged="$(git -C "$SB_WORK" diff --name-only 2>/dev/null | LC_ALL=C sort | tr '\n' ' ')"
    printf '%s\n' "$staged" | grep -xF PROJECT.md >/dev/null && cf "following the hint staged PROJECT.md, whose only change is the project's own line: $hint"
    printf '%s\n' "$staged" | grep -xF scripts/config.sh >/dev/null && cf "following the hint staged scripts/config.sh, which the module never touched: $hint"
    [ "$unstaged" = "PROJECT.md scripts/config.sh " ] || cf "following the hint did not leave exactly the project's two edits unstaged: [$unstaged]"
    [ -z "$(git -C "$SB_WORK" ls-files --others --exclude-standard 2>/dev/null)" ] || cf "following the hint left untracked files: $(git -C "$SB_WORK" ls-files --others --exclude-standard | tr '\n' '|' | cut -c1-200)"
    [ -z "$(git -C "$SB_WORK" ls-files -- .claude/roles/example.md)" ] || cf "the first run's deletion of .claude/roles/example.md is not staged"
    printf '%s\n' "$staged" | grep -xF .gitignore >/dev/null || cf "the first run's removal of the block in .gitignore is not staged: $hint"
  fi
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A DISABLE NAMES A BLOCK'S HOST IN ITS COMMIT HINT ONLY WHEN THE BLOCK ITSELF CHANGED.
#   (a) The project removed the module's block in PROJECT.md by hand, committed that, then added a line of its own to
#   PROJECT.md: the disable's hint does not name PROJECT.md, so following it leaves that line unstaged. (b) Removed by hand
#   and not committed: the hint names PROJECT.md, so following it stages the removal.
# =============================================================================
case_a_disable_names_a_gone_blocks_host_only_when_the_block_changed() {
  cf_reset
  local L="module.sh disable names a block host already without the block in its commit hint only when the block's own lines differ from HEAD: a removal committed earlier plus an unrelated edit leaves the edit unstaged; a removal not committed is staged by the hint"
  _mu_reason="$(_mu_example_reason)"; if [ -n "$_mu_reason" ]; then skp_lived "$L" "$_mu_reason"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum)"; return; }
  _mu_subject_ok || { finish "$L"; return; }
  local hint
  _mu_pair
  awk '/KIT-MODULE:example:gates BEGIN/ { s = 1 } !s { print } /KIT-MODULE:example:gates END/ { s = 0 }' "$SB_WORK/PROJECT.md" > "$SB_TMP/project.new" && cp "$SB_TMP/project.new" "$SB_WORK/PROJECT.md"
  _mu_land "drop the example gate row on purpose"
  printf '%s\n' "a line of the project's own" >> "$SB_WORK/PROJECT.md"
  _md_mod disable example
  [ "$_md_rc" -eq 0 ] || cf "(a) disable exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  hint="$(printf '%s\n' "$_md_out" | sed -n 's/^  \(git add -A -- .*\)$/\1/p')"
  [ -n "$hint" ] || cf "(a) disable prints no commit hint: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  case " $hint " in *" PROJECT.md "*) cf "(a) the hint names PROJECT.md, whose block's removal was committed: $hint" ;; esac
  if [ -n "$hint" ]; then
    ( cd "$SB_WORK" && eval "$hint" ) >/dev/null 2>&1 || cf "(a) the printed hint failed when run: $hint"
    git -C "$SB_WORK" diff --cached --name-only 2>/dev/null | grep -xF PROJECT.md >/dev/null && cf "(a) following the hint staged the project's own line in PROJECT.md"
    [ "$(git -C "$SB_WORK" diff --name-only 2>/dev/null | tr '\n' ' ')" = "PROJECT.md " ] || cf "(a) following the hint did not leave exactly PROJECT.md unstaged: [$(git -C "$SB_WORK" diff --name-only | tr '\n' ' ')]"
  fi
  teardown

  _mu_pair
  awk '/KIT-MODULE:example:gates BEGIN/ { s = 1 } !s { print } /KIT-MODULE:example:gates END/ { s = 0 }' "$SB_WORK/PROJECT.md" > "$SB_TMP/project.new" && cp "$SB_TMP/project.new" "$SB_WORK/PROJECT.md"
  _md_mod disable example
  [ "$_md_rc" -eq 0 ] || cf "(b) disable exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  hint="$(printf '%s\n' "$_md_out" | sed -n 's/^  \(git add -A -- .*\)$/\1/p')"
  case " $hint " in *" PROJECT.md "*) : ;; *) cf "(b) the hint does not name PROJECT.md, whose block was removed and not committed: $hint" ;; esac
  if [ -n "$hint" ]; then
    ( cd "$SB_WORK" && eval "$hint" ) >/dev/null 2>&1 || cf "(b) the printed hint failed when run: $hint"
    [ -z "$(git -C "$SB_WORK" diff --name-only 2>/dev/null)" ] || cf "(b) following the hint left unstaged changes: $(git -C "$SB_WORK" diff --name-only | tr '\n' ' ')"
  fi
  finish "$L"
  teardown
}
