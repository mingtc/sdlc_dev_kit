# KIT-CLASS: KIT — the design module's own self-test cases: enable and disable, the fragments, the role and the evidence kind it registers, and the wording that says what this version lacks. See process/EXTRACTION.md.
# =============================================================================
# modules/design/test/cases/design.sh — sourced by scripts/test/run.sh with the harness's own files, and
# listed in modules/design/test/CASE-LIST. Each case enables the module in a sandbox with the harness's shared
# helpers (scripts/test/lib/modules.sh) and looks at what the project's own scripts read. Helpers of its own
# carry the prefix _dm_. A project that deleted modules/design/ has these cases N/A (the file named in the reason).
# =============================================================================

# _dm_have — status 0 when the module is in this tree.
_dm_have() { [ -f "$REAL_REPO_ROOT/modules/design/module.manifest" ]; }
_dm_gone_reason() { printf '%s' "modules/design/RELEASE-NOTES.md is absent from this tree"; }

# _dm_corpus — a CORPUS.md of the sandbox's own with the two slot lines the module's blocks go above.
_dm_corpus() {
  mkdir -p "$SB_WORK/requirements"
  printf '# CORPUS.md (sandbox)\n\n| Entry | Kind | Status | Why it is corpus |\n|---|---|---|---|\n| `DECISIONS.md` | `file` | `present` | the rulings |\n\n<!-- KIT-MODULES:corpus-manifest the slot -->\n\n| Path | Bucket |\n|---|---|\n| `requirements/` | `corpus` |\n\n<!-- KIT-MODULES:corpus-buckets the slot -->\n\ntail\n' > "$SB_WORK/requirements/CORPUS.md"
}
_dm_hook() {  # <role> — the commit-msg hook's verdict on a subject tagged with it
  local msg="$SB_TMP/dm-msg.txt"
  printf '[%s] %s: design\n' "$1" "$_MD_ID" > "$msg"
  "$SB_WORK/scripts/githooks/commit-msg" "$msg" >/dev/null 2>&1
}
_dm_kinds() { ( cd "$SB_WORK" && bash -c '. scripts/lib/refuse.sh; . scripts/lib/qa-gate.sh; kit_qa_evidence_kinds "$1" HEAD' _ "$SB_WORK" ); }
_dm_land() {  # <message> — commit what the sandbox holds and publish it: the readers below read the trunk
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "[PM] $_MD_ID: $1" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
}
_dm_move() {  # <id> <role> — the board mover, status in _dm_rc and output in _dm_out
  _dm_rc=0
  _dm_out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/records" ./scripts/move-issue.sh "$1" in_progress --role "$2" --note x 2>&1 </dev/null )" || _dm_rc=$?
}
_dm_mint() {  # prd|issue -> the minted file's text on stdout; the file is removed
  local f
  case "$1" in
    prd)   ( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/records" ./scripts/new-prd.sh probe >/dev/null 2>&1 ); f="$(probe_pick "$SB_WORK/requirements" -name 'PRD-*-probe.md')" ;;
    issue) ( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/records" ./scripts/new-issue.sh probe --id "$SB_PREFIX-799" >/dev/null 2>&1 ); f="$SB_WORK/progress/todo/$SB_PREFIX-799-probe.md" ;;
  esac
  [ -f "$f" ] && { cat "$f"; rm -f "$f"; }
  return 0
}
# _dm_frontmatter <text> — the lines between the first two `---` lines.
_dm_frontmatter() { printf '%s\n' "$1" | awk '/^---[[:space:]]*$/ { n++; next } n == 1 { print } n >= 2 { exit }'; }

# _dm_ki_sandbox — a day-one sandbox that holds the modules, a PROJECT.md with the blanks kit-init fills and the gates
# slot, and a CORPUS.md with its slots: kit-init's own sandbox is another case file's, and a module's cases do not
# lean on the load order of files they do not own.
_dm_ki_sandbox() {
  make_sandbox
  mkdir -p "$SB_WORK/.claude"
  cp -R "$REAL_REPO_ROOT/.claude/templates" "$SB_WORK/.claude/templates"
  [ ! -d "$REAL_REPO_ROOT/.claude/roles" ] || cp -R "$REAL_REPO_ROOT/.claude/roles" "$SB_WORK/.claude/roles"
  _kit_neutral_claude
  sandbox_hat_clear
  cp -R "$REAL_REPO_ROOT/modules" "$SB_WORK/modules"
  printf '# <project name> — PROJECT.md (sandbox)\n\nIssue ids are <PREFIX>-NNN on <trunk>.\n\n| Gate | Your command | The contract it implements |\n|---|---|---|\n| g | `x` | y |\n\n<!-- KIT-MODULES:gates the slot -->\n\ntail\n' > "$SB_WORK/PROJECT.md"
  _dm_corpus
  publish_sandbox
}

# =============================================================================
# CASE — THE DESIGN MODULE IS ENABLED ON DAY ONE, INSIDE THE INITIALIZATION COMMIT.
#   Operand: the commit kit-init makes, read back from git. The module's role doc, rules, record and both CORPUS
#   blocks are in THAT commit, stamped with this project's prefix, and the self-check that follows passes with the
#   module live.
# =============================================================================
case_kit_init_with_design_places_the_module_in_the_initialization_commit() {
  cf_reset
  local L="kit-init.sh --with design puts the design module's role doc, rules, templates, record and its PROJECT.md, CORPUS.md and .gitignore blocks in the initialization commit, stamped with this project's prefix, and the self-check passes with the module live"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  [ -f "$REAL_SCRIPTS/kit-init.sh" ] || { skp "$L" "scripts/kit-init.sh absent"; return; }
  [ -f "$REAL_REPO_ROOT/.claude/templates/ISSUE.template.md" ] || { skp "$L" ".claude/templates/ISSUE.template.md absent (copy-list incomplete)"; return; }
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_ki_sandbox
  local out rc init f
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" --with design 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) kit-init --with design exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep 'kit-init COMPLETE and PROVEN' >/dev/null || cf "(a) no COMPLETE-and-PROVEN line: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep '✗' >/dev/null && cf "(a) a self-check assertion failed with the design module enabled: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  init="$(git -C "$SB_WORK" log --format='%H %s' | awk '/kit-init: initialize the kit/ { print $1; exit }')"
  [ -n "$init" ] || { cf "(b) no initialization commit in the log"; finish "$L"; teardown; return; }
  for f in process/MODULES .claude/roles/designer.md .claude/templates/design/CANVAS.template.md .claude/templates/design/COMMENTS.template.md \
           requirements/design/README.md process/roles.d/design process/evidence-kinds.d/design \
           process/fragments.d/PRD/design.slot-story-fields process/fragments.d/ISSUE/design.frontmatter; do
    git -C "$SB_WORK" cat-file -e "$init:$f" 2>/dev/null || cf "(b) $f is not in the initialization commit"
    origin_has_path "$f" || cf "(b) $f did not reach the trunk"
  done
  for f in PROJECT.md:gates requirements/CORPUS.md:corpus-manifest requirements/CORPUS.md:corpus-buckets; do
    git -C "$SB_WORK" show "$init:${f%%:*}" 2>/dev/null | grep -F "<!-- KIT-MODULE:design:${f##*:} BEGIN -->" >/dev/null || cf "(b) the module's ${f##*:} block is not in ${f%%:*} as the initialization commit holds it"
  done
  git -C "$SB_WORK" show "$init:.gitignore" 2>/dev/null | grep -F '# KIT-MODULE:design:gitignore BEGIN' >/dev/null || cf "(b) the module's ignore block is not in .gitignore as the initialization commit holds it"
  grep -F '<PREFIX>' "$SB_WORK/.claude/roles/designer.md" >/dev/null && cf "(c) the role doc still carries the <PREFIX> blank"
  grep -F 'SBX-NNN' "$SB_WORK/.claude/roles/designer.md" >/dev/null || cf "(c) the role doc does not carry this project's prefix"
  [ -z "$(git -C "$SB_WORK" status --porcelain --untracked-files=all 2>/dev/null)" ] || cf "(b) the run left uncommitted paths: $(git -C "$SB_WORK" status --porcelain --untracked-files=all | tr '\n' '|' | cut -c1-200)"
  "$SB_WORK/scripts/module.sh" status design > "$SB_TMP/status.out" 2>&1
  grep -E 'edited|missing' "$SB_TMP/status.out" >/dev/null && cf "(d) status shows an edited or missing thing straight after kit-init: $(tr '\n' '|' < "$SB_TMP/status.out" | cut -c1-200)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE DESIGN MODULE IS ENABLED LATER, AND DISABLE RETURNS A BYTE-IDENTICAL TREE.
#   Operand: a byte snapshot of the tree before enable. Enable places the role doc, the rules, the templates and
#   both CORPUS blocks and records them; disable (nothing edited, no commit carrying [Designer]) leaves the
#   snapshot equal.
# =============================================================================
case_enabling_design_later_and_disabling_it_returns_the_tree_byte_for_byte() {
  cf_reset
  local L="enabling the design module in a running project places and records its files and blocks, and disabling it returns the tree byte for byte"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _md_sandbox
  local s0="$SB_TMP/snap0" s1="$SB_TMP/snap1" f n rows
  _md_snap "$SB_WORK" > "$s0"
  [ -s "$s0" ] || _fixture_die "${FUNCNAME[0]}: the snapshot of the sandbox is empty."
  _md_mod enable design
  [ "$_md_rc" -eq 0 ] || { cf "enable exited $_md_rc: $_md_out"; finish "$L"; teardown; return; }
  for f in .claude/roles/designer.md .claude/templates/design/CANVAS.template.md .claude/templates/design/COMMENTS.template.md \
           requirements/design/README.md process/roles.d/design process/evidence-kinds.d/design \
           process/fragments.d/PRD/design.slot-story-fields process/fragments.d/ISSUE/design.frontmatter process/MODULES; do
    [ -f "$SB_WORK/$f" ] || cf "(a) enable did not place $f"
  done
  grep -F '<!-- KIT-MODULE:design:gates BEGIN -->' "$SB_WORK/PROJECT.md" >/dev/null || cf "(a) enable did not put the module's gate rows in PROJECT.md"
  grep -F '<!-- KIT-MODULE:design:corpus-manifest BEGIN -->' "$SB_WORK/requirements/CORPUS.md" >/dev/null || cf "(a) enable did not put the module's manifest rows in CORPUS.md"
  grep -F '<!-- KIT-MODULE:design:corpus-buckets BEGIN -->' "$SB_WORK/requirements/CORPUS.md" >/dev/null || cf "(a) enable did not put the module's bucket rows in CORPUS.md"
  grep -F 'requirements/design/' "$SB_WORK/requirements/CORPUS.md" >/dev/null || cf "(a) CORPUS.md does not admit requirements/design/"
  grep -E '^module design [0-9]+\.[0-9]+\.[0-9]+$' "$SB_WORK/process/MODULES" >/dev/null || cf "(a) process/MODULES has no 'module design <version>' line"
  _md_mod status design
  n="$(printf '%s\n' "$_md_out" | grep -c 'intact')"
  rows="$(grep -cE '^(file|block) ' "$SB_WORK/process/MODULES")"
  { [ "$rows" -ge 1 ] && [ "$n" = "$rows" ]; } || cf "(b) status shows $n intact line(s) for $rows recorded row(s): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  _md_snap "$SB_WORK" > "$s1"
  cmp -s "$s0" "$s1" && cf "(a) enable changed no byte"
  _md_mod disable design
  [ "$_md_rc" -eq 0 ] || cf "(c) disable exited $_md_rc: $_md_out"
  _md_snap "$SB_WORK" > "$SB_TMP/snap2"
  cmp -s "$s0" "$SB_TMP/snap2" || cf "(c) disable left a different tree: $(diff "$s0" "$SB_TMP/snap2" | head -6 | tr '\n' '|' | cut -c1-300)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A NEW PRD AND A NEW CARD CARRY THE DESIGN LINES ONLY WHILE THE MODULE IS ENABLED.
#   The PRD gets `**UI:** none` in its story block and the card `design: none` in its frontmatter (not elsewhere),
#   and nothing else of the module's design fields; before enable and after disable neither is there.
# =============================================================================
case_a_prd_and_a_card_carry_the_design_lines_only_while_the_design_module_is_enabled() {
  cf_reset
  local L="a PRD minted while the design module is enabled carries a UI line in its story block and a card minted then carries design: none in its frontmatter and nothing more of the module's fields; before enable and after disable neither does"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  [ -f "$REAL_REPO_ROOT/.claude/templates/PRD.template.md" ] || { skp "$L" ".claude/templates/PRD.template.md absent (copy-list incomplete)"; return; }
  _md_sandbox
  local prd issue fm
  # (control) before enable.
  _dm_mint prd | grep -F '**UI:**' >/dev/null && cf "(control) a new PRD carries a UI line before the module is enabled"
  _dm_mint issue | grep -E '^design' >/dev/null && cf "(control) a new card carries a design key before the module is enabled"
  _md_mod enable design
  [ "$_md_rc" -eq 0 ] || { cf "enable exited $_md_rc: $_md_out"; finish "$L"; teardown; return; }
  _dm_land "enable the design module"
  prd="$( _dm_mint prd )"; issue="$( _dm_mint issue )"
  [ "$(printf '%s\n' "$prd" | grep -cxF '**UI:** none')" = 1 ] || cf "(a) a new PRD does not carry exactly one '**UI:** none' line"
  printf '%s\n' "$prd" | grep -F 'KIT-MODULES' >/dev/null && cf "(a) a slot line survived into the minted PRD"
  printf '%s\n' "$prd" | awk '/^##### F1-S1/ { s = 1 } s && /^\*\*UI:\*\* none$/ { f = 1 } s && /^\*\*Acceptance Criteria\*\*/ { exit } END { exit !f }' || cf "(a) the UI line is not in the first story, above its Acceptance Criteria"
  printf '%s\n' "$prd" | grep -E '^(Design:|\*\*Design:\*\*|design-scope)' >/dev/null && cf "(a) a new PRD carries a design field beyond the UI line"
  fm="$( _dm_frontmatter "$issue" )"
  printf '%s\n' "$fm" | grep -x 'design: none' >/dev/null || cf "(b) a new card's frontmatter does not carry 'design: none'"
  [ "$(printf '%s\n' "$issue" | grep -c '^design')" = 1 ] || cf "(b) a new card carries a design key outside or beside the frontmatter's one"
  printf '%s\n' "$issue" | grep -E '^design-scope' >/dev/null && cf "(b) a new card carries a design-scope key the module does not mint"
  _md_mod disable design
  [ "$_md_rc" -eq 0 ] || cf "(c) disable exited $_md_rc: $_md_out"
  _dm_land "disable the design module"
  _dm_mint prd | grep -F '**UI:**' >/dev/null && cf "(c) a new PRD still carries a UI line after disable"
  _dm_mint issue | grep -E '^design' >/dev/null && cf "(c) a new card still carries a design key after disable"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — [Designer] IS ACCEPTED BY THE HOOK AND THE MOVER, AND THE design KIND BY THE QA GATE, WHILE THE MODULE IS
# ENABLED, AND NEITHER BEFORE.
# =============================================================================
case_the_designer_role_and_the_design_evidence_kind_are_read_while_the_module_is_enabled() {
  cf_reset
  local L="while the design module is enabled the commit-msg hook and the board mover accept [Designer] and the QA gate lists the design evidence kind beside the built-in ones; before enable the hook refuses the role and the gate lacks the kind, and once the module is disabled and its kept role layer deleted neither is so"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _md_sandbox
  local id="$_MD_ID"
  _dm_hook Designer && cf "(control) the hook accepted [Designer] before the module was enabled"
  case " $(_dm_kinds) " in *" design "*) cf "(control) the QA gate already lists the design kind" ;; esac
  _md_mod enable design
  [ "$_md_rc" -eq 0 ] || { cf "enable exited $_md_rc: $_md_out"; finish "$L"; teardown; return; }
  _dm_land "enable the design module"
  _dm_hook Designer || cf "(a) the hook refused [Designer] after enable"
  _dm_hook "$SB_ROLE" || cf "(a) the hook refused a base role after enable"
  case " $(_dm_kinds) " in *" design "*) : ;; *) cf "(b) the QA gate does not list the design kind: $(_dm_kinds)" ;; esac
  case " $(_dm_kinds) " in *" test "*) : ;; *) cf "(b) the built-in kinds went missing: $(_dm_kinds)" ;; esac
  _dm_move "$id" Designer
  [ "$_dm_rc" -eq 0 ] || cf "(c) the mover refused the module's role (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  origin_log_has_subject "\[Designer\] $id" || cf "(c) the move's commit does not carry the [Designer] tag the hook had to accept"
  _md_mod disable design
  [ "$_md_rc" -eq 0 ] || cf "(d) disable exited $_md_rc: $_md_out"
  [ -f "$SB_WORK/process/roles.d/design" ] || cf "(d) the role layer was removed though a commit carries [Designer]"
  rm -f "$SB_WORK/process/roles.d/design"
  _dm_hook Designer && cf "(d) the hook still accepts [Designer] once the layer is deleted"
  _dm_land "disable the design module"
  case " $(_dm_kinds) " in *" design "*) cf "(d) the QA gate still lists the design kind after disable" ;; esac
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE DESIGNER ROLE SAYS, FOR EACH CAPABILITY THIS VERSION LACKS, THAT IT NEEDS THE NEXT VERSION OF THE KIT.
#   The expected answer is fixed here: six capabilities, each named by a token the role must carry and by the file
#   whose presence in the module means it ships. The line is required while the file is absent and forbidden once
#   it is present, so a lane that ships a capability must take its line out, and the module README's one line goes
#   with the last of them.
# =============================================================================
case_the_designer_role_names_each_capability_this_version_lacks_and_drops_the_line_when_it_ships() {
  cf_reset
  local L="the shipped Designer role carries a 'needs the next version of the kit' line for each capability whose file the module does not ship yet (design-pull, design-publish, the design drift check, the card gate, tokens and the colour utility) and no such line for one it does ship, and the module README carries its one line while any is missing"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  local m="$REAL_REPO_ROOT/modules/design" role readme row tok glob shipped missing=0 lines
  role="$m/_claude/roles/designer.md"; readme="$m/README.md"
  [ -f "$role" ] || { cf "(prereq) modules/design/_claude/roles/designer.md is absent"; finish "$L"; return; }
  [ -f "$readme" ] || { cf "(prereq) modules/design/README.md is absent"; finish "$L"; return; }
  lines="$(grep -F 'needs the next version of the kit' "$role" || true)"
  while IFS='|' read -r tok glob; do
    [ -n "$tok" ] || continue
    shipped=0
    # shellcheck disable=SC2086
    [ -z "$(ls $m/$glob 2>/dev/null)" ] || shipped=1
    if [ "$shipped" = 1 ]; then
      printf '%s\n' "$lines" | grep -F -- "$tok" >/dev/null && cf "(a) the module ships $glob and the Designer role still says $tok needs the next version of the kit"
    else
      missing=1
      printf '%s\n' "$lines" | grep -F -- "$tok" >/dev/null || cf "(a) $glob is not shipped and the Designer role has no 'needs the next version of the kit' line naming $tok"
    fi
  done <<DM_CAPS_EOF
/design-pull|_claude/skills/design-pull/SKILL.md
/design-publish|_claude/skills/design-publish/SKILL.md
50-design-drift.sh|check-board.d/50-design-drift.sh
move-check.d/todo|move-check.d/todo/*.sh
m3-tokens.mjs|scripts/design/m3-tokens.mjs
material-color-utilities|scripts/design/vendor/material-color-utilities/index.js
DM_CAPS_EOF
  if [ "$missing" = 1 ]; then
    grep -F 'do not improvise' "$role" >/dev/null || cf "(b) the Designer role does not tell the agent not to improvise a capability that is not installed"
    grep -F 'needs the next version of the kit' "$readme" >/dev/null || cf "(c) the module README carries no 'needs the next version of the kit' line while a capability is missing"
  else
    grep -F 'needs the next version of the kit' "$readme" >/dev/null && cf "(c) every capability ships and the module README still says one needs the next version of the kit"
  fi
  finish "$L"
}
