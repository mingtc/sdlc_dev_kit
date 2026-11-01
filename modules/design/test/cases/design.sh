# KIT-CLASS: KIT — the design module's own self-test cases: enable and disable, the fragments, the role and the evidence kind it registers, and the wording that says what this version lacks. See process/EXTRACTION.md.
# =============================================================================
# modules/design/test/cases/design.sh — sourced by scripts/test/run.sh with the harness's own files, and
# listed in modules/design/test/CASE-LIST. Each case enables the module in a sandbox with the harness's shared
# helpers (scripts/test/lib/modules.sh) and looks at what the project's own scripts read. Helpers of its own
# carry the prefix _dm_. A project that deleted modules/design/ has these cases N/A (the file named in the reason).
# =============================================================================

# _dm_have — status 0 when the module is in this tree.
_dm_have() { [ -f "$REAL_REPO_ROOT/modules/design/RELEASE-NOTES.md" ]; }
_dm_gone_reason() { printf '%s' "modules/design/RELEASE-NOTES.md is absent from this tree"; }

# _dm_manifest_places <manifest> <key> <target regex> — status 0 when a line of that key places something at a target of that shape.
_dm_manifest_places() {
  awk -v k="$2:" -v re="$3" '$1 == k { t = $0; sub(/^.*-> */, "", t); if (t ~ re) f = 1 } END { exit !f }' "$1"
}
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
  # a real register, so the self-check's citation arm reads one and a decision id a fixture cites is judged against it
  if [ -f "$REAL_REPO_ROOT/requirements/DECISIONS.md" ]; then mkdir -p "$SB_WORK/requirements"; cp "$REAL_REPO_ROOT/requirements/DECISIONS.md" "$SB_WORK/requirements/DECISIONS.md"; fi
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
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's enable requires it"; return; }
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
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's enable requires it"; return; }
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
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's enable requires it"; return; }
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
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's enable requires it"; return; }
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
# CASE — THE DESIGNER ROLE SAYS, FOR EACH CAPABILITY THE MODULE DOES NOT SHIP, THAT IT NEEDS THE NEXT VERSION OF THE KIT.
#   The expected answer is fixed here: each capability is named by a token the role must carry and by the manifest line
#   that places it, read from module.manifest (a capability ships when a line of that key has a target of that shape,
#   wherever the module keeps the source). The role's line is required while nothing places it and forbidden once
#   something does, so a lane that ships a capability must take its line out. The module README and the rules'
#   README carry their one line while any capability is missing, and the gate row's N/A goes with the link check.
# =============================================================================
case_the_designer_role_names_each_capability_this_version_lacks_and_drops_the_line_when_it_ships() {
  cf_reset
  local L="the shipped Designer role carries a 'needs the next version of the kit' line for each capability that module.manifest does not place yet (the pull and publish commands, the drift check, the card gate, the token generator and the colour utility, render, the audits, the link check, the PRD view, the flow graph) and none for one it places, the module README and the rules README carry their line while any is missing, and the gate row is N/A only while the link check is not placed"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  local m="$REAL_REPO_ROOT/modules/design" role readme rules tok key re missing=0 lines f hits
  role="$m/_claude/roles/designer.md"; readme="$m/README.md"; rules="$m/requirements/design/README.md"
  for f in "$role" "$readme" "$rules" "$m/gates.md"; do
    [ -f "$f" ] || { cf "(prereq) ${f#$REAL_REPO_ROOT/} is absent"; finish "$L"; return; }
  done
  lines="$(grep -F 'needs the next version of the kit' "$role" || true)"
  while IFS='|' read -r tok key re; do
    [ -n "$tok" ] || continue
    if _dm_manifest_places "$m/module.manifest" "$key" "$re"; then
      printf '%s\n' "$lines" | grep -F -- "$tok" >/dev/null && cf "(a) module.manifest places $tok and the Designer role still says it needs the next version of the kit"
    else
      missing=1
      printf '%s\n' "$lines" | grep -F -- "$tok" >/dev/null || cf "(a) module.manifest does not place $tok and the Designer role has no 'needs the next version of the kit' line naming it"
    fi
  done <<'DM_CAPS_EOF'
/design-pull|file|^[.]claude/skills/design-pull/SKILL[.]md$
/design-publish|file|^[.]claude/skills/design-publish/SKILL[.]md$
50-design-drift.sh|arm|.
50-design-pin.sh|move-check|^todo/
m3-tokens.mjs|file|^scripts/design/m3-tokens[.]mjs$
material-color-utilities|file|^scripts/design/vendor/material-color-utilities/index[.]js$
render.py|file|^scripts/design/render[.]py$
contrast-audit.py|file|^scripts/design/contrast-audit[.]py$
check-design-links.py|file|^scripts/design/check-design-links[.]py$
prd-view.py|file|^scripts/design/prd-view[.]py$
flow-from-links.py|file|^scripts/design/flow-from-links[.]py$
DM_CAPS_EOF
  if [ "$missing" = 1 ]; then
    grep -F 'do not improvise' "$role" >/dev/null || cf "(b) the Designer role does not tell the agent not to improvise a capability that is not installed"
    grep -F 'needs the next version of the kit' "$readme" >/dev/null || cf "(c) the module README carries no 'needs the next version of the kit' line while a capability is missing"
    grep -F 'needs the next version of the kit' "$rules" >/dev/null || cf "(c) the rules README carries no 'needs the next version of the kit' line while a capability is missing"
  else
    grep -F 'needs the next version of the kit' "$readme" >/dev/null && cf "(c) every capability is placed and the module README still says one needs the next version of the kit"
    grep -F 'needs the next version of the kit' "$rules" >/dev/null && cf "(c) every capability is placed and the rules README still says one needs the next version of the kit"
  fi
  if _dm_manifest_places "$m/module.manifest" file '^scripts/design/check-design-links[.]py$'; then
    grep -F 'N/A' "$m/gates.md" >/dev/null && cf "(d) the link check is placed and the gate row still says N/A"
  else
    grep -F 'N/A' "$m/gates.md" >/dev/null || cf "(d) the link check is not placed and the gate row carries no N/A with its reason"
  fi
  # (e) the human never draws, edits or switches a screen: the design tool's agent does, and the human looks, decides and carries.
  hits="$(find "$m" -type f -not -path "$m/test/*" -exec grep -niE 'human[^.]{0,60}[[:space:]](draws|edits|switches)|human (should|must|will|can|may) (draw|edit|switch)|you (draw|edit)[[:space:]]|who draws|drawn (on|by)|(switching|switches) (the|a) screen' {} + || true)"
  [ -z "$hits" ] || cf "(e) design text attributes drawing, editing or switching a screen to a human: $(printf '%s' "$hits" | tr '\n' '|' | cut -c1-200)"
  # (f) while the adapter is not placed, the role names create and update as the intended workflow that needs the next version.
  if ! _dm_manifest_places "$m/module.manifest" file '^[.]claude/skills/design-pull/SKILL[.]md$'; then
    printf '%s\n' "$lines" | grep -F 'Creating and updating' >/dev/null || cf "(f) the adapter is not placed and the Designer role has no 'Creating and updating … needs the next version of the kit' line"
  fi
  finish "$L"
}

# =============================================================================
# CASE — EVERY AC SHAPE THE DESIGN GUIDES TEACH IS READ BY THE QA GATE'S OWN READER.
#   Operand: the checklist lines of the PRD guide and the card guide, run through _qav_ac_ids from the shipped
#   scripts/lib/qa-gate.sh. The expected id is the one the line itself starts with (AC then digits), so a tag
#   or a phrase placed between the id and its separator makes the line invisible to the gate and fails here:
#   a checklist bullet the gate cannot see is a (UI) AC that needs no verdict row, and a row QA writes for it is
#   refused as extra.
# =============================================================================
case_the_ac_lines_the_design_guides_teach_are_read_by_the_qa_gates_own_reader() {
  cf_reset
  local L="every checklist line in the design module's PRD guide and card guide, run through the QA gate's own AC reader, yields exactly the id it starts with, and each guide teaches a (UI) line"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  [ -f "$REAL_SCRIPTS/lib/qa-gate.sh" ] || { cf "(prereq) scripts/lib/qa-gate.sh is absent"; finish "$L"; return; }
  local g f lines line want got
  for f in PRD-design.fragment.md ISSUE-design.fragment.md; do
    g="$REAL_REPO_ROOT/modules/design/_claude/templates/design/$f"
    [ -f "$g" ] || { cf "(prereq) modules/design/_claude/templates/design/$f is absent"; continue; }
    lines="$(grep -E '^- \[[ xX]\] AC[0-9]+' "$g" || true)"
    [ -n "$lines" ] || { cf "($f) teaches no checklist line"; continue; }
    printf '%s\n' "$lines" | grep -F '(UI)' >/dev/null || cf "($f) teaches no (UI) checklist line"
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      want="$(printf '%s' "$line" | grep -oE '^- \[[ xX]\] AC[0-9]+' | grep -oE 'AC[0-9]+')"
      got="$(bash -c '. "$1/lib/refuse.sh"; . "$1/lib/qa-gate.sh"; _qav_ac_ids "$2"' _ "$REAL_SCRIPTS" "$line" 2>&1)"
      [ "$got" = "$want" ] || cf "($f) the QA gate reads '$line' as [${got:-nothing}], not [$want]"
    done <<DM_ACS_EOF
$lines
DM_ACS_EOF
  done
  finish "$L"
}

# =============================================================================
# CASE — NO SHIPPED DESIGN TEXT TELLS A ROLE TO RENDER THE PINNED SIDE WHILE THE RENDERER IS NOT PLACED.
#   While module.manifest places no scripts/design/render.py, no file of the module (its own test cases excepted)
#   says `git archive`, "render the pinned", "renders the pinned", "QA renders" or "render the build", and the QA
#   guide tells QA to read the pinned PNG with `git show <pin>:requirements/design/…/renders/…` and not to pass a
#   row that has no image. Once the renderer is placed the lane that places it rewrites the text, and this case
#   no longer holds it.
# =============================================================================
case_no_design_text_tells_a_role_to_render_the_pinned_side_while_the_renderer_is_absent() {
  cf_reset
  local L="while module.manifest places no render.py, no shipped design text tells a role to render the pinned side, and the QA guide names the committed PNG read with git show and forbids a PASS without an image"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  local m="$REAL_REPO_ROOT/modules/design" f hits qa
  if _dm_manifest_places "$m/module.manifest" file '^scripts/design/render[.]py$'; then
    skp "$L" "modules/design/module.manifest places render.py, so the text is the renderer's lane's own"; return
  fi
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    hits="$(grep -niE 'git archive|render(s)? the pinned|QA renders|render the build' "$f" || true)"
    [ -z "$hits" ] || cf "(a) ${f#$REAL_REPO_ROOT/} tells a role to render while render.py is absent: $(printf '%s' "$hits" | tr '\n' '|' | cut -c1-160)"
  done <<DM_FILES_EOF
$(find "$m" -type f -not -path "$m/test/*")
DM_FILES_EOF
  qa="$m/_claude/templates/design/QA-verdict-design.fragment.md"
  [ -f "$qa" ] || { cf "(prereq) the QA guide is absent"; finish "$L"; return; }
  grep -F 'git show <pin>:requirements/design/' "$qa" >/dev/null || cf "(b) the QA guide does not name the committed PNG read with git show <pin>:requirements/design/…"
  grep -iE 'not (a )?PASS|does not pass|never (a )?PASS' "$qa" >/dev/null || cf "(b) the QA guide does not say a row with no image is not a PASS"
  finish "$L"
}

# =============================================================================
# THE CHECKERS AND THE DRIFT ARM. The operand of each case below is the placed tool or the placed arm, run in a sandbox that
# enabled the module, over a project fixture whose answer is written here: each expected verdict is hard-coded, none is
# derived from the tools or from the fixture's own files.
# =============================================================================

# _dm_python — status 0 when the tools can run here (python3 3.9 or later); the cases SKIP loudly otherwise.
_dm_python() { command -v python3 >/dev/null 2>&1 && python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' >/dev/null 2>&1; }
_dm_has() { case "$1" in *"$2"*) return 0 ;; esac; return 1; }   # <text> <fixed needle>
# _dm_py <args…> — python3 in the sandbox, status in _dm_rc and output in _dm_out.
_dm_py() { _dm_rc=0; _dm_out="$( cd "$SB_WORK" && env PYTHONDONTWRITEBYTECODE=1 python3 "$@" 2>&1 </dev/null )" || _dm_rc=$?; }
# _dm_commit <message> — commit the whole sandbox tree; the new commit is in _DM_SHA.
_dm_commit() { git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m "[PM] $_MD_ID: $1" >/dev/null 2>&1; _DM_SHA="$(git -C "$SB_WORK" rev-parse HEAD)"; }
_dm_report() { ( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR ./scripts/check-board.sh 2>&1 ); }
# _dm_arm <report> — the lines of the [+design-drift] arm.
_dm_arm() { printf '%s\n' "$1" | awk '/^\[\+design-drift\]/ { f = 1; print; next } f && /^$/ { exit } f { print }'; }
# _dm_row <text> <card> <ux#state@pin prefix> — the pin-drift row for that card and pinned state, or nothing.
_dm_row() { printf '%s\n' "$1" | awk -v c="$2" -v u="$3" '$1 == c && index($2, u) == 1 { print; exit }'; }
# _dm_verdict <text> <card> <ux#state@pin prefix> — the verdict word of that row, or "absent".
_dm_verdict() { local r; r="$(_dm_row "$1" "$2" "$3")"; if [ -z "$r" ]; then printf 'absent'; else printf '%s' "$r" | awk '{ print $3 }'; fi; }
# _dm_edit <file> <sed expression> — an in-place edit that leaves no backup file.
_dm_edit() { LC_ALL=C sed -i.dmbak "$2" "$1" && rm -f "$1.dmbak"; }

# _dm_art <path> <nnn> <root vars> <body> [<stories>] — an artboard whose :root block holds the vars it uses.
_dm_art() {
  mkdir -p "$(dirname "$1")"
  printf '<!doctype html><html><body><x-dc>\n<style>:root { %s }</style>\n<div id="ux-%s-root" data-ux="UX-%s" data-stories="%s">\n%s\n</div></x-dc></body></html>\n' "$3" "$2" "$2" "${5:-PRD-001-F1-S1}" "$4" > "$1"
}
# _dm_registry <canvas dir> <row>… — the canvas record with its screen registry; a row is `UX-id|file|states|stories|gate1|gate2`.
_dm_registry() {
  local d="$1" r; shift
  mkdir -p "$d"
  { printf '# CANVAS — app\n\n### Screens\n\n| UX-id | file | title | platform | pair | states | stories | gate1 | gate2 |\n|---|---|---|---|---|---|---|---|---|\n'
    for r in "$@"; do printf '%s\n' "$r" | awk -F'|' '{ printf "| %s | %s | t | phone |  | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5, $6 }'; done; } > "$d/CANVAS.md"
}
_dm_tokens() { mkdir -p "$SB_WORK/requirements/design/tokens"; printf '%s\n' "$1" > "$SB_WORK/requirements/design/tokens/${2:-app.tokens.json}"; }   # <json> [<file name>]
# _dm_card <number> <shelf> <design line> — a card on a status shelf of the sandbox.
_dm_card() {  # a shelf name written beside its number reads as a citation to the builder, so the number comes first
  mkdir -p "$SB_WORK/progress/$2"
  printf -- '---\nid: %s-%s\ntype: chore\ntitle: t\nbranch: n/a\npr: null\ncreated_at: 2026-01-01\ncreated_by: PM\nforks: none\n%s\n---\n\n# card\n' "$SB_PREFIX" "$1" "$3" > "$SB_WORK/progress/$2/$SB_PREFIX-$1-c.md"
}

# _dm_drift_fixture — the module enabled in a sandbox, a design project whose pin commit is _DM_P, cards pinned to it, and a
# later trunk commit that changes the design. Every screen of the pin has one fixed answer at the later commit:
#   UX-001 text changed (drift)           UX-002 file moved (moved)          UX-003 removed (gone)       UX-004 same (clean)
#   UX-005 states a,b marked: only b's text changed        UX-006 states a,b unmarked: one text changed
#   UX-007 same bytes, a token it uses changed             UX-008 same bytes, an unused token changed and one added
#   UX-009 only the root's data-stories changed
#   UX-010 uses a var that names no token (uncompared)     UX-011 token is an alias of another file's token, which changed (drift)
#   UX-012 token is an alias nothing defines (uncompared)  UX-014 in a canvas named café, token in a file named 品牌 (drift on the token)
#   UX-015 pinned at a state its row does not list (uncompared)   UX-016 a Latin-1 artboard that changed (drift)
#   UX-017 a duplicate bare attribute that changed (drift)   UX-018 an implied </p>: a shared element changed (drift for state b)
#   UX-019 only a comment changed (drift, saying markup outside every id)
#   UX-020..022 the pinned state's own branch is marked Empty, emtpy and {{variant}} where the row lists `empty` (uncompared, not set aside)
#   UX-023 reads the changed token as `var( --color-primary )` with an empty :root; UX-024 only declares it in :root (drift on the token)
#   UX-025 links a stylesheet that changed (drift); UX-026 one the repository lacks (uncompared), UX-027 a remote one (clean: no gap)
#   UX-028 an unquoted link, 029 an @import in a style, 030 a script src, 031 an img src, 032 a sheet that @imports a sheet: the file changed (drift)
#   UX-033 reads a token by var() only in a linked sheet (drift on the token); UX-036 a commented-out link (clean)
#   UX-034 two ids swapped under the pinned branch and a text changed under the other (drift); UX-035 an id moved from state a into pinned b (drift)
_dm_drift_fixture() {
  local S='--color-surface: #ffffff;' P='--color-primary: #485d92;'
  _md_sandbox
  _md_mod enable design
  [ "$_md_rc" -eq 0 ] || { cf "enable exited $_md_rc: $_md_out"; return 1; }
  _dm_land "enable the design module"
  _dm_tokens '{"color":{"primary":{"$value":"#485d92"},"surface":{"$value":"#ffffff"},"error":{"$value":"#b3261e"}},"link":{"main":{"$value":"{base.blue}"}},"ghost":{"x":{"$value":"{nope.nothing}"}}}'
  _dm_tokens '{"base":{"blue":{"$value":"#0000ff"}}}' base.tokens.json
  _dm_tokens '{"jp":{"blue":{"$value":"#123456"}}}' 品牌.tokens.json
  local D="$SB_WORK/requirements/design/app/project"
  _dm_art "$D/A.dc.html" 001 "$P" '<h1 id="ux-001-title" style="color: var(--color-primary)">List</h1>'
  _dm_art "$D/B.dc.html" 002 "$S" '<h1 id="ux-002-title" style="color: var(--color-surface)">Edit</h1>'
  _dm_art "$D/D.dc.html" 003 "$S" '<h1 id="ux-003-title" style="color: var(--color-surface)">Gone</h1>'
  _dm_art "$D/E.dc.html" 004 "$S" '<h1 id="ux-004-title" style="color: var(--color-surface)">Same</h1>'
  _dm_art "$D/F.dc.html" 005 "$S" '<sc-if value="{{a}}"><div id="ux-005-a" data-state="a"><p id="ux-005-a-text" style="color: var(--color-surface)">Alpha</p></div></sc-if><sc-if value="{{b}}"><div id="ux-005-b" data-state="b"><p id="ux-005-b-text">Beta</p></div></sc-if>'
  _dm_art "$D/G.dc.html" 006 "$S" '<sc-if value="{{a}}"><div id="ux-006-a"><p id="ux-006-a-text" style="color: var(--color-surface)">Alpha</p></div></sc-if><sc-if value="{{b}}"><div id="ux-006-b"><p id="ux-006-b-text">Beta</p></div></sc-if>'
  _dm_art "$D/H.dc.html" 007 "$P" '<h1 id="ux-007-title" style="color: var(--color-primary)">Tok</h1>'
  _dm_art "$D/I.dc.html" 008 "$S" '<h1 id="ux-008-title" style="color: var(--color-surface)">Quiet</h1>'
  _dm_art "$D/J.dc.html" 009 "$S" '<h1 id="ux-009-title" style="color: var(--color-surface)">Meta</h1>'
  _dm_art "$D/K.dc.html" 010 '--brand: #123456;' '<h1 id="ux-010-title" style="color: var(--brand)">Brand</h1>'
  _dm_art "$D/L.dc.html" 011 '--link-main: #0000ff;' '<h1 id="ux-011-title" style="color: var(--link-main)">Link</h1>'
  _dm_art "$D/M.dc.html" 012 '--ghost-x: #000000;' '<h1 id="ux-012-title" style="color: var(--ghost-x)">Ghost</h1>'
  _dm_art "$SB_WORK/requirements/design/café/project/K.dc.html" 014 '--jp-blue: #123456;' '<h1 id="ux-014-title" style="color: var(--jp-blue)">Jp</h1>'
  _dm_art "$D/O.dc.html" 015 "$S" '<h1 id="ux-015-title" style="color: var(--color-surface)">Typo</h1>'
  _dm_art "$D/P.dc.html" 016 "$S" "$(printf '<h1 id="ux-016-title" style="color: var(--color-surface)">caf\351</h1>')"
  _dm_art "$D/Q.dc.html" 017 "$S" '<input class class="x" id="ux-017-in" style="color: var(--color-surface)">'
  _dm_art "$D/R.dc.html" 018 "$S" '<p data-state="a">alpha<div id="ux-018-shared" style="color: var(--color-surface)">Shared</div><p data-state="b">beta</p>'
  _dm_art "$D/S.dc.html" 019 "$S" '<!-- one --><h1 id="ux-019-title" style="color: var(--color-surface)">Comment</h1>'
  _dm_art "$D/T20.dc.html" 020 "$S" '<div id="ux-020-x" data-state="Empty"><p id="ux-020-t" style="color: var(--color-surface)">Hi</p></div>'
  _dm_art "$D/T21.dc.html" 021 "$S" '<div id="ux-021-x" data-state="emtpy"><p id="ux-021-t" style="color: var(--color-surface)">Hi</p></div>'
  _dm_art "$D/T22.dc.html" 022 "$S" '<div id="ux-022-x" data-state="{{variant}}"><p id="ux-022-t" style="color: var(--color-surface)">Hi</p></div>'
  _dm_art "$D/T23.dc.html" 023 '' '<h1 id="ux-023-t" style="color: var( --color-primary )">Spaced</h1>'
  _dm_art "$D/T24.dc.html" 024 '--color-primary: #485d92;' '<h1 id="ux-024-t">Declared only</h1>'
  _dm_art "$D/T25.dc.html" 025 "$S" '<link rel="stylesheet" href="app.css"><h1 id="ux-025-t" style="color: var(--color-surface)">Sheet</h1>'
  _dm_art "$D/T26.dc.html" 026 "$S" '<link rel="stylesheet" href="missing.css"><h1 id="ux-026-t" style="color: var(--color-surface)">Sheet</h1>'
  _dm_art "$D/T27.dc.html" 027 "$S" '<link rel="stylesheet" href="https://example.invalid/x.css"><h1 id="ux-027-t" style="color: var(--color-surface)">Sheet</h1>'
  printf 'h1 { margin: 10px }\n' > "$D/app.css"
  mkdir -p "$D/ds"
  printf 'h2 { margin: 1px }\n' > "$D/a4.css"; printf 'h2 { margin: 2px }\n' > "$D/a7.css"; printf 'var x = 1;\n' > "$D/a8.js"
  printf '<svg xmlns="http://www.w3.org/2000/svg"><rect width="1" height="1"/></svg>\n' > "$D/ds/a9.svg"
  printf '@import "b2.css";\n' > "$D/b1.css"; printf 'h2 { margin: 3px }\n' > "$D/b2.css"; printf 'h1 { color: var(--color-primary) }\n' > "$D/v.css"
  _dm_art "$D/T28.dc.html" 028 "$S" '<link rel=stylesheet href=a4.css><h1 id="ux-028-t" style="color: var(--color-surface)">Unquoted</h1>'
  _dm_art "$D/T29.dc.html" 029 "$S" '<style>@import "a7.css";</style><h1 id="ux-029-t" style="color: var(--color-surface)">Import</h1>'
  _dm_art "$D/T30.dc.html" 030 "$S" '<script src="a8.js"></script><h1 id="ux-030-t" style="color: var(--color-surface)">Script</h1>'
  _dm_art "$D/T31.dc.html" 031 "$S" '<img src="ds/a9.svg"><h1 id="ux-031-t" style="color: var(--color-surface)">Image</h1>'
  _dm_art "$D/T32.dc.html" 032 "$S" '<link rel="stylesheet" href="b1.css"><h1 id="ux-032-t" style="color: var(--color-surface)">Chain</h1>'
  _dm_art "$D/T33.dc.html" 033 '' '<link rel="stylesheet" href="v.css"><h1 id="ux-033-t">Sheet var</h1>'
  _dm_art "$D/T34.dc.html" 034 "$S" '<p data-state="a"><i id="ux-034-y">1</i><i id="ux-034-z">2</i></p><p data-state="b">q</p>'
  _dm_art "$D/T35.dc.html" 035 "$S" '<p data-state="a"><i id="ux-035-m">1</i> x</p><p data-state="b">q</p>'
  _dm_art "$D/T36.dc.html" 036 "$S" '<!-- <link rel="stylesheet" href="gone.css"> --><h1 id="ux-036-t" style="color: var(--color-surface)">Commented</h1>'
  _dm_registry "$SB_WORK/requirements/design/app" \
    'UX-001|A.dc.html|default, empty|PRD-001-F1-S1|open|open' 'UX-002|B.dc.html|default|PRD-001-F1-S1|open|open' \
    'UX-003|D.dc.html|default|PRD-001-F1-S1|open|open' 'UX-004|E.dc.html|default|PRD-001-F1-S1|open|open' \
    'UX-005|F.dc.html|a, b|PRD-001-F1-S1|open|open' 'UX-006|G.dc.html|a, b|PRD-001-F1-S1|open|open' \
    'UX-007|H.dc.html|default|PRD-001-F1-S1|open|open' 'UX-008|I.dc.html|default|PRD-001-F1-S1|open|open' \
    'UX-009|J.dc.html|default|PRD-001-F1-S1|open|open' 'UX-010|K.dc.html|default|PRD-001-F1-S1|open|open' \
    'UX-011|L.dc.html|default|PRD-001-F1-S1|open|open' 'UX-012|M.dc.html|default|PRD-001-F1-S1|open|open' \
    'UX-015|O.dc.html|default|PRD-001-F1-S1|open|open' 'UX-016|P.dc.html|default|PRD-001-F1-S1|open|open' \
    'UX-017|Q.dc.html|default|PRD-001-F1-S1|open|open' 'UX-018|R.dc.html|a, b|PRD-001-F1-S1|open|open' \
    'UX-019|S.dc.html|default|PRD-001-F1-S1|open|open' 'UX-020|T20.dc.html|default, empty|PRD-001-F1-S1|open|open' \
    'UX-021|T21.dc.html|default, empty|PRD-001-F1-S1|open|open' 'UX-022|T22.dc.html|default, empty|PRD-001-F1-S1|open|open' \
    'UX-023|T23.dc.html|default|PRD-001-F1-S1|open|open' 'UX-024|T24.dc.html|default|PRD-001-F1-S1|open|open' \
    'UX-025|T25.dc.html|default|PRD-001-F1-S1|open|open' 'UX-026|T26.dc.html|default|PRD-001-F1-S1|open|open' \
    'UX-027|T27.dc.html|default|PRD-001-F1-S1|open|open' 'UX-028|T28.dc.html|default|PRD-001-F1-S1|open|open' \
    'UX-029|T29.dc.html|default|PRD-001-F1-S1|open|open' 'UX-030|T30.dc.html|default|PRD-001-F1-S1|open|open' \
    'UX-031|T31.dc.html|default|PRD-001-F1-S1|open|open' 'UX-032|T32.dc.html|default|PRD-001-F1-S1|open|open' \
    'UX-033|T33.dc.html|default|PRD-001-F1-S1|open|open' 'UX-034|T34.dc.html|a, b|PRD-001-F1-S1|open|open' \
    'UX-035|T35.dc.html|a, b|PRD-001-F1-S1|open|open' 'UX-036|T36.dc.html|default|PRD-001-F1-S1|open|open'
  _dm_registry "$SB_WORK/requirements/design/café" 'UX-014|K.dc.html|default|PRD-001-F1-S1|open|open'
  _dm_commit "the design at its pin"; _DM_P="$_DM_SHA"
  local p="@$_DM_P" id="$SB_PREFIX"
  _dm_card 701 in_progress "design: [UX-001#default$p, UX-002#default$p, UX-003#default$p, UX-004#default$p, UX-004#default@deadbee, UX-099#x$p, UX-005#a$p, UX-005#b$p, UX-006#a$p, UX-007#default$p, UX-008#default$p, UX-009#default$p]"
  _dm_card 706 in_progress "design: [UX-010#default$p, UX-011#default$p, UX-012#default$p, UX-014#default$p, UX-015#typo$p, UX-016#default$p, UX-017#default$p, UX-018#b$p, UX-019#default$p]"
  _dm_card 710 in_progress "design: [UX-020#empty$p, UX-021#empty$p, UX-022#empty$p, UX-023#default$p, UX-024#default$p, UX-025#default$p, UX-026#default$p, UX-027#default$p]"
  _dm_card 711 in_progress "design: [UX-027#default$p, UX-028#default$p, UX-029#default$p, UX-030#default$p, UX-031#default$p, UX-032#default$p, UX-033#default$p, UX-036#default$p]"
  _dm_card 712 in_progress "design: [UX-034#a$p, UX-035#b$p]"
  _dm_card 707 in_progress "design: TBD"
  printf -- '---\nid: app2-709\ntype: chore\ntitle: t\nbranch: n/a\npr: null\ncreated_at: 2026-01-01\ncreated_by: PM\nforks: none\ndesign: [UX-004#default%s]\n---\n\n# card\n' "$p" > "$SB_WORK/progress/in_progress/app2-709-c.md"
  _dm_card 704 qa_complete "design: [UX-001#empty$p]"
  _dm_card 702 done "design: [UX-001#default$p]"
  _dm_card 705 declined "design: [UX-001#default$p]"
  _dm_card 703 todo "design: [UX-001#default]"
  mkdir -p "$SB_WORK/dev/questions"
  printf 'Question about %s-701 and the screen UX-001: is the list title final?\n' "$id" > "$SB_WORK/dev/questions/Q-1-title.md"
  _dm_commit "pin the cards"
  # the later commit: the design moves on under the pinned cards
  _dm_edit "$D/A.dc.html" 's|>List<|>Lists<|'
  git -C "$SB_WORK" mv "$D/B.dc.html" "$D/B2.dc.html"
  _dm_edit "$SB_WORK/requirements/design/app/CANVAS.md" 's/UX-002 | B.dc.html/UX-002 | B2.dc.html/'
  git -C "$SB_WORK" rm -q -f "$D/D.dc.html"
  _dm_edit "$SB_WORK/requirements/design/app/CANVAS.md" '/^| UX-003 /d'
  _dm_edit "$D/F.dc.html" 's|>Beta<|>Beta two<|'
  _dm_edit "$D/G.dc.html" 's|>Beta<|>Beta two<|'
  _dm_edit "$D/J.dc.html" 's|data-stories="PRD-001-F1-S1"|data-stories="PRD-001-F1-S1 PRD-002-F1-S1"|'
  _dm_tokens '{"color":{"primary":{"$value":"#3b4f82"},"surface":{"$value":"#ffffff"},"error":{"$value":"#ba1a1a"},"success":{"$value":"#1b6d2f"}},"link":{"main":{"$value":"{base.blue}"}},"ghost":{"x":{"$value":"{nope.nothing}"}}}'
  _dm_tokens '{"base":{"blue":{"$value":"#0000fe"}}}' base.tokens.json
  _dm_tokens '{"jp":{"blue":{"$value":"#123457"}}}' 品牌.tokens.json
  _dm_edit "$D/Q.dc.html" 's|class="x"|class="y"|'
  _dm_edit "$D/R.dc.html" 's|>Shared<|>Shared two<|'
  _dm_edit "$D/S.dc.html" 's|<!-- one -->|<!-- two -->|'
  for n in 20 21 22; do _dm_edit "$D/T$n.dc.html" 's|>Hi<|>Hi two<|'; done
  printf 'h1 { margin: 90px }\n' > "$D/app.css"
  printf 'h2 { margin: 91px }\n' > "$D/a4.css"; printf 'h2 { margin: 92px }\n' > "$D/a7.css"; printf 'var x = 2;\n' > "$D/a8.js"
  printf '<svg xmlns="http://www.w3.org/2000/svg"><rect width="2" height="2"/></svg>\n' > "$D/ds/a9.svg"; printf 'h2 { margin: 93px }\n' > "$D/b2.css"
  _dm_art "$D/T34.dc.html" 034 "$S" '<p data-state="a"><i id="ux-034-z">2</i><i id="ux-034-y">1</i></p><p data-state="b">q2</p>'
  _dm_art "$D/T35.dc.html" 035 "$S" '<p data-state="a"> x2</p><p data-state="b"><i id="ux-035-m">1</i>q</p>'
  perl -pi -e 's/caf\xe9/cafe/' "$D/P.dc.html"
  _dm_land "the design moves on"
  return 0
}

# =============================================================================
# CASE — THE DRIFT ARM NAMES EACH PINNED STATE'S VERDICT IN check-board.sh, READS ONLY CARDS PAST todo/ AND NOT LANDED, AND REPORTS.
#   Operand: the [+design-drift] section of the project's own check-board.sh, which reads the trunk. Absent after disable; an
#   advisory arm (its header says it reports only).
# =============================================================================
case_the_design_drift_arm_names_each_pin_verdict_in_check_board_and_reads_only_cards_past_todo_and_not_landed() {
  cf_reset
  local L="check-board.sh runs the design drift arm only while the module is enabled; it reports reports-only, gives each pinned state of a card past todo/ its verdict (clean, moved, drift, gone, unresolved), says ruling pending or owed on a drift, and reads no card in todo/, done/ or declined/"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_drift_fixture || { finish "$L"; teardown; return; }
  local rep arm p7 c="$SB_PREFIX-701" v
  p7="${_DM_P:0:7}"
  rep="$(_dm_report)"; arm="$(_dm_arm "$rep")"
  [ -n "$arm" ] || { cf "(a) the report has no [+design-drift] section: $(printf '%s' "$rep" | tail -5 | tr '\n' '|' | cut -c1-240)"; finish "$L"; teardown; return; }
  _dm_has "$arm" "reports only" || cf "(a) the arm's header does not say it reports only"
  _dm_has "$arm" "compared with origin/$SB_TRUNK" || cf "(a) the arm does not name the revision it compared with"
  v="$(_dm_verdict "$arm" "$c" "UX-001#default@$p7")"; [ "$v" = drift ] || cf "(b) UX-001, whose text changed, reads '$v', not drift"
  v="$(_dm_verdict "$arm" "$c" "UX-002#default@$p7")"; [ "$v" = moved ] || cf "(b) UX-002, whose file moved with its bytes, reads '$v', not moved"
  v="$(_dm_verdict "$arm" "$c" "UX-003#default@$p7")"; [ "$v" = gone ] || cf "(b) UX-003, whose row was removed, reads '$v', not gone"
  v="$(_dm_verdict "$arm" "$c" "UX-004#default@$p7")"; [ "$v" = clean ] || cf "(b) UX-004, unchanged, reads '$v', not clean"
  v="$(_dm_verdict "$arm" "$c" "UX-004#default@deadbee")"; [ "$v" = unresolved ] || cf "(b) a pin to a commit that does not exist reads '$v', not unresolved"
  v="$(_dm_verdict "$arm" "$c" "UX-099#x@$p7")"; [ "$v" = unresolved ] || cf "(b) a pin to a screen with no row at the pin reads '$v', not unresolved"
  _dm_has "$(_dm_row "$arm" "$c" "UX-001#default@$p7")" "drift, ruling pending" || cf "(c) the drift on UX-001, whose card and screen a question file names, does not say ruling pending"
  _dm_has "$(_dm_row "$arm" "$SB_PREFIX-704" "UX-001#empty@$p7")" "drift, owed" || cf "(c) the drift on a qa_complete card nothing rules on does not say owed"
  [ "$(_dm_verdict "$arm" "$SB_PREFIX-704" "UX-001#empty@$p7")" = drift ] || cf "(d) a card in qa_complete/ was not read: it is past todo/ and not landed"
  for v in 702 703 705; do
    [ -z "$(printf '%s\n' "$arm" | awk -v c="$SB_PREFIX-$v" '$1 == c { print }')" ] || cf "(d) the arm read the card $SB_PREFIX-$v, which sits in a shelf it must not read"
  done
  # (e) one bad file costs a line, not the report; nothing it could not compare reads clean
  c="$SB_PREFIX-706"
  v="$(_dm_verdict "$arm" "$c" "UX-010#default@$p7")"; [ "$v" = uncompared ] || cf "(e) UX-010, whose var names no token, reads '$v', not uncompared"
  v="$(_dm_verdict "$arm" "$c" "UX-012#default@$p7")"; [ "$v" = uncompared ] || cf "(e) UX-012, whose token is an alias nothing defines, reads '$v', not uncompared"
  v="$(_dm_verdict "$arm" "$c" "UX-015#typo@$p7")"; [ "$v" = uncompared ] || cf "(e) a pin to a state its row does not list reads '$v', not uncompared"
  v="$(_dm_verdict "$arm" "$c" "UX-016#default@$p7")"; [ "$v" = drift ] || cf "(e) UX-016, a Latin-1 artboard that changed, reads '$v', not drift"
  v="$(_dm_verdict "$arm" "$c" "UX-019#default@$p7")"; [ "$v" = drift ] || cf "(e) the last screen of the last card reads '$v': the report stopped early"
  v="$(_dm_verdict "$arm" "$SB_PREFIX-707" "design:#*@-")"; [ "$v" = uncompared ] || cf "(e) a card whose design: value is TBD reads '$v', not uncompared"
  v="$(_dm_verdict "$arm" "app2-709" "UX-004#default@$p7")"; [ "$v" = clean ] || cf "(e) a card of a lower-case prefix reads '$v' for its clean pin: its id was not read from the card"
  # (f) a registry removed outright is said, not "nothing to compare"
  git -C "$SB_WORK" rm -r -q -f requirements/design/app requirements/design/café
  _dm_land "remove the design record"
  arm="$(_dm_arm "$(_dm_report)")"
  v="$(_dm_verdict "$arm" "$SB_PREFIX-701" "UX-004#default@$p7")"; [ "$v" = gone ] || cf "(f) with the registry removed outright a pinned state reads '$v', not gone: $(printf '%s' "$arm" | head -3 | tr '\n' '|' | cut -c1-200)"
  # (g) a tool that cannot run is "did not run", not a quiet status 0
  printf 'def broken(:\n' > "$SB_WORK/scripts/design/pin-drift.py"
  rep="$(_dm_report)"
  { _dm_has "$rep" "pin-drift.py did not run" && _dm_has "$rep" "50-design-drift.sh exited 1"; } || cf "(g) a pin-drift.py that cannot run is not reported as an arm that did not run: $(_dm_arm "$rep" | head -3 | tr '\n' '|' | cut -c1-240)"
  cp "$REAL_REPO_ROOT/modules/design/scripts/design/pin-drift.py" "$SB_WORK/scripts/design/pin-drift.py"
  # the arm is the module's: gone with it
  _md_mod disable design
  [ "$_md_rc" -eq 0 ] || cf "(e) disable exited $_md_rc: $_md_out"
  [ ! -e "$SB_WORK/scripts/check-board.d/50-design-drift.sh" ] || cf "(e) the arm file is still placed after disable"
  _dm_has "$(_dm_report)" "[+design-drift]" && cf "(e) check-board still runs the design drift arm after disable"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A PINNED STATE IS JUDGED BY ITS data-state BRANCH WHEN THE ARTBOARD MARKS ONE, BY THE FILE WHEN IT DOES NOT, AND BY THE
# TOKENS IT USES.
#   Operand: scripts/design/pin-drift.py run by hand over the fixture. A change under another state's branch reads clean;
#   the same change on an unmarked artboard reads drift and says per-file; a token a screen uses that changed is drift though
#   its bytes are the same; an unused token's change and an added token are not; a change of the root's data-stories alone is not.
# =============================================================================
case_pin_drift_judges_a_state_by_its_data_state_branch_and_the_tokens_it_uses() {
  cf_reset
  local L="pin-drift.py reads a change under another state's data-state branch as clean, the same change on an artboard with no data-state as drift marked per-file, a changed token the screen uses as drift with unchanged bytes, an unused token's change or an added token as clean, and a change of the root's data-stories alone as clean"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_drift_fixture || { finish "$L"; teardown; return; }
  local c="$SB_PREFIX-701" p7 r
  p7="${_DM_P:0:7}"
  _dm_py scripts/design/pin-drift.py
  [ "$_dm_rc" -eq 0 ] || cf "(prereq) pin-drift.py exited $_dm_rc: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  r="$(_dm_row "$_dm_out" "$c" "UX-005#a@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-005#a@$p7")" = clean ] && _dm_has "$r" "changed only under other states"; } || cf "(a) UX-005#a, whose only change is under state b, does not read clean with that noted: $r"
  r="$(_dm_row "$_dm_out" "$c" "UX-005#b@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-005#b@$p7")" = drift ] && _dm_has "$r" "ids: ~ux-005-b-text"; } || cf "(a) UX-005#b, whose branch text changed, does not read drift naming ~ux-005-b-text: $r"
  _dm_has "$r" "[per-file" && cf "(a) UX-005#b, whose artboard marks its states, is called per-file"
  r="$(_dm_row "$_dm_out" "$c" "UX-006#a@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-006#a@$p7")" = drift ] && _dm_has "$r" "[per-file: no data-state marks]"; } || cf "(b) UX-006#a, an artboard with no data-state, does not read drift marked per-file: $r"
  r="$(_dm_row "$_dm_out" "$c" "UX-007#default@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-007#default@$p7")" = drift ] && _dm_has "$r" "tokens: --color-primary" && _dm_has "$r" "(none: tokens only)"; } || cf "(c) UX-007, whose bytes are the same and whose token color.primary changed, does not read drift on --color-primary alone: $r"
  [ "$(_dm_verdict "$_dm_out" "$c" "UX-008#default@$p7")" = clean ] || cf "(c) UX-008, which uses neither the changed nor the added token, does not read clean: $(_dm_row "$_dm_out" "$c" "UX-008#default@$p7")"
  r="$(_dm_row "$_dm_out" "$c" "UX-009#default@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-009#default@$p7")" = clean ] && _dm_has "$r" "registry bookkeeping"; } || cf "(d) UX-009, whose root's data-stories alone changed, does not read clean as bookkeeping: $r"
  [ "$(_dm_verdict "$_dm_out" "$c" "UX-001#default@$p7")" = drift ] || cf "(e) UX-001, whose title text changed, does not read drift"
  c="$SB_PREFIX-706"
  r="$(_dm_row "$_dm_out" "$c" "UX-010#default@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-010#default@$p7")" = uncompared ] && _dm_has "$r" "--brand names no token"; } || cf "(f) UX-010, a var naming no token, does not read uncompared saying so: $r"
  r="$(_dm_row "$_dm_out" "$c" "UX-011#default@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-011#default@$p7")" = drift ] && _dm_has "$r" "tokens: --link-main"; } || cf "(g) UX-011, whose token is an alias of another file's token that changed, does not read drift on --link-main: $r"
  r="$(_dm_row "$_dm_out" "$c" "UX-012#default@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-012#default@$p7")" = uncompared ] && _dm_has "$r" "an alias does not resolve"; } || cf "(h) UX-012, whose alias nothing defines, does not read uncompared saying so: $r"
  r="$(_dm_row "$_dm_out" "$c" "UX-014#default@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-014#default@$p7")" = drift ] && _dm_has "$r" "tokens: --jp-blue"; } || cf "(i) UX-014, in a canvas and a token file with non-ASCII names, does not read drift on --jp-blue: $r"
  r="$(_dm_row "$_dm_out" "$c" "UX-015#typo@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-015#typo@$p7")" = uncompared ] && _dm_has "$r" "state typo is not in the registry row"; } || cf "(j) a pin to a state its row does not list does not read uncompared saying so: $r"
  [ "$(_dm_verdict "$_dm_out" "$c" "UX-016#default@$p7")" = drift ] || cf "(k) a Latin-1 artboard that changed does not read drift: $(_dm_row "$_dm_out" "$c" "UX-016#default@$p7")"
  [ "$(_dm_verdict "$_dm_out" "$c" "UX-017#default@$p7")" = drift ] || cf "(k) an artboard with a duplicate bare attribute that changed does not read drift: $(_dm_row "$_dm_out" "$c" "UX-017#default@$p7")"
  r="$(_dm_row "$_dm_out" "$c" "UX-018#b@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-018#b@$p7")" = drift ] && _dm_has "$r" "~ux-018-shared"; } || cf "(l) UX-018#b, whose shared element follows an implied close of a state-a paragraph, does not read drift on it: $r"
  r="$(_dm_row "$_dm_out" "$c" "UX-019#default@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-019#default@$p7")" = drift ] && _dm_has "$r" "markup outside every id" && ! _dm_has "$r" "tokens only"; } || cf "(m) UX-019, where only a comment changed, does not read drift saying markup outside every id: $r"
  c="$SB_PREFIX-710"
  for n in 20 21 22; do
    r="$(_dm_row "$_dm_out" "$c" "UX-0$n#empty@$p7")"
    { [ "$(_dm_verdict "$_dm_out" "$c" "UX-0$n#empty@$p7")" = uncompared ] && _dm_has "$r" "data-state"; } || cf "(o) UX-0$n, whose pinned state's branch carries a mark the row does not list, is set aside or read otherwise than uncompared naming the mark: $r"
  done
  for n in 23 24; do
    r="$(_dm_row "$_dm_out" "$c" "UX-0$n#default@$p7")"
    { [ "$(_dm_verdict "$_dm_out" "$c" "UX-0$n#default@$p7")" = drift ] && _dm_has "$r" "tokens: --color-primary"; } || cf "(p) UX-0$n, which reads or declares the changed token without the plain var(--x) shape, does not read drift on it: $r"
  done
  r="$(_dm_row "$_dm_out" "$c" "UX-025#default@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-025#default@$p7")" = drift ] && _dm_has "$r" "files: app.css"; } || cf "(q) UX-025, whose linked stylesheet changed, does not read drift on it: $r"
  c="$SB_PREFIX-710"
  r="$(_dm_row "$_dm_out" "$c" "UX-026#default@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-026#default@$p7")" = uncompared ] && _dm_has "$r" "missing.css"; } || cf "(q) UX-026, which links a stylesheet in neither revision, does not read uncompared: $r"
  c="$SB_PREFIX-711"
  [ "$(_dm_verdict "$_dm_out" "$c" "UX-027#default@$p7")" = clean ] || cf "(q) UX-027, which links a remote stylesheet nothing changed, does not read clean (a remote reference is no gap): $(_dm_row "$_dm_out" "$SB_PREFIX-710" "UX-027#default@$p7")"
  for n in 28:a4.css 29:a7.css 30:a8.js 31:ds/a9.svg 32:b2.css; do
    r="$(_dm_row "$_dm_out" "$c" "UX-0${n%%:*}#default@$p7")"
    { [ "$(_dm_verdict "$_dm_out" "$c" "UX-0${n%%:*}#default@$p7")" = drift ] && _dm_has "$r" "files: ${n#*:}"; } || cf "(r) UX-0${n%%:*}, whose ${n#*:} changed, does not read drift on it: $r"
  done
  r="$(_dm_row "$_dm_out" "$c" "UX-033#default@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-033#default@$p7")" = drift ] && _dm_has "$r" "tokens: --color-primary"; } || cf "(s) UX-033, which reads the changed token by var() only in a linked sheet, does not read drift on it: $r"
  [ "$(_dm_verdict "$_dm_out" "$c" "UX-036#default@$p7")" = clean ] || cf "(s) UX-036, with a commented-out link, does not read clean: $(_dm_row "$_dm_out" "$c" "UX-036#default@$p7")"
  c="$SB_PREFIX-712"
  [ "$(_dm_verdict "$_dm_out" "$c" "UX-034#a@$p7")" = drift ] || cf "(t) UX-034#a, whose ids swapped under the pinned branch beside a change under the other, does not read drift: $(_dm_row "$_dm_out" "$c" "UX-034#a@$p7")"
  [ "$(_dm_verdict "$_dm_out" "$c" "UX-035#b@$p7")" = drift ] || cf "(t) UX-035#b, which gained an id moved from state a beside a change left in a, does not read drift: $(_dm_row "$_dm_out" "$c" "UX-035#b@$p7")"
  r="$(_dm_row "$_dm_out" "$SB_PREFIX-707" "design:")"
  [ "$(printf '%s' "$r" | awk '{ print $3 }')" = uncompared ] || cf "(n) a card whose design: value is TBD does not read uncompared: $r"
  _dm_has "$_dm_out" "pin-drift: " || cf "(n) no summary line"
  finish "$L"
  teardown
}

# _dm_links_fixture — the module enabled in a sandbox with a design project that the link check judges clean: two screens, a PRD that
# cites both, a PRD with no UI line (not design-classified) and one with a UI line in one story only (partly), and a colour literal
# inside an artboard's :root block. Approval of UX-001 is recorded against the commit that took the artboard in (_DM_X).
_dm_links_fixture() {
  _md_sandbox
  _md_mod enable design
  [ "$_md_rc" -eq 0 ] || { cf "enable exited $_md_rc: $_md_out"; return 1; }
  _dm_land "enable the design module"
  local D="$SB_WORK/requirements/design/app/project"
  _dm_tokens '{"color":{"primary":{"$value":"#485d92"}}}'
  _dm_art "$D/A.dc.html" 001 '--color-primary: #485d92;' '<h1 id="ux-001-title" style="color: var(--color-primary)"><a href="B.dc.html#top">List</a></h1>'
  _dm_art "$D/B.dc.html" 002 '--color-primary: #485d92;' '<h1 id="ux-002-title" style="color: var(--color-primary)"><a href="A.dc.html">Edit</a></h1>' PRD-001-F1-S2
  _dm_registry "$SB_WORK/requirements/design/app" 'UX-001|A.dc.html|default, empty|PRD-001-F1-S1|open|open' 'UX-002|B.dc.html|default|PRD-001-F1-S2|open|open'
  printf '# PRD-001 — App\n\n## Features\n\n### F1 — Lists\n\n#### Stories\n\n##### F1-S1 — See the list\n\n**UI:** default, empty\n\n**Acceptance Criteria**\n\n- [ ] AC1: (UI) the list shows. [design: UX-001#default]\n- [ ] AC2: (UI) an empty list shows a hint. [design: UX-001#empty]\n- [ ] AC3: the list is sorted.\n\n##### F1-S2 — Edit\n\n**UI:** default\n\n- [ ] AC1: (UI) the edit form shows. [design: UX-002#default]\n' > "$SB_WORK/requirements/PRD-001-app.md"
  printf '# PRD-002 — Api\n\n## Features\n\n### F1 — Endpoint\n\n##### F1-S1 — Serve\n\n- [ ] AC1: it serves.\n\n##### F1-S2 — Log\n\n- [ ] AC1: it logs.\n\n~~~\n```\ninside\n~~~\n\n```code```\n' > "$SB_WORK/requirements/PRD-002-api.md"
  printf '# PRD-003 — Mixed\n\n## Features\n\n### F1 — Bits\n\n##### F1-S1 — One\n\n**UI:** none\n\n- [ ] AC1: one.\n\n##### F1-S2 — Two\n\n- [ ] AC1: two.\n\n    ```\n' > "$SB_WORK/requirements/PRD-003-mixed.md"
  _dm_commit "the screens"; _DM_X="$_DM_SHA"
  _dm_registry "$SB_WORK/requirements/design/app" "UX-001|A.dc.html|default, empty|PRD-001-F1-S1|approved@$_DM_X|open" 'UX-002|B.dc.html|default|PRD-001-F1-S2|open|open'
  _dm_commit "approve UX-001"; _DM_Y="$_DM_SHA"
  return 0
}

# =============================================================================
# CASE — THE LINK CHECK REPORTS EACH GAP BETWEEN THE PRDs, THE REGISTRY, THE ARTBOARDS AND THE CARDS, AND IS QUIET ABOUT WHAT IS NOT ONE.
#   Operand: scripts/design/check-design-links.py --strict over a clean fixture (exit 0, no finding: a colour in :root, a PRD with no
#   UI line, a PRD with one) and then over the same fixture with one defect of each class added.
# =============================================================================
case_the_link_check_reports_each_gap_in_both_directions_and_is_quiet_about_a_root_block_and_unclassified_prds() {
  cf_reset
  local L="check-design-links.py --strict exits 0 with no finding over a project whose :root block holds colour literals and whose PRDs are not or only partly design-classified (info lines only), and exits 1 naming an uncovered (UI) AC, an unresolved citation, a row citing no story, a stale Design: pending, a stale approval, an approval with no sha and a colour literal outside :root"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_links_fixture || { finish "$L"; teardown; return; }
  local D="$SB_WORK/requirements/design/app/project" X="$_DM_X" out
  _dm_py scripts/design/check-design-links.py --strict
  [ "$_dm_rc" -eq 0 ] || cf "(a) the clean fixture exits $_dm_rc under --strict: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_has "$_dm_out" "; 0 finding(s)" || cf "(a) the clean fixture does not end on 0 findings: $(printf '%s' "$_dm_out" | tail -1)"
  _dm_has "$_dm_out" "PRD-002-api.md: not design-classified: no story carries a UI: line (info)" || cf "(b) a PRD with no UI line gets no info line saying it is not design-classified: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_has "$_dm_out" "PRD-003-mixed.md: not design-classified: F1-S2 carry no UI: line (info)" || cf "(b) a PRD with a UI line in one story only gets no info line naming the story without one: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_has "$_dm_out" "UNCLASSIFIED  requirements/PRD-001" && cf "(b) a fully classified PRD got an UNCLASSIFIED line"
  _dm_has "$_dm_out" "FENCE" && cf "(b) a ~~~ block holding a \`\`\` line is read as a fence never closed"
  git -C "$SB_WORK" mv requirements/design/app requirements/design/app2
  _dm_commit "the canvas moves with its bytes"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "; 0 finding(s)"; } || cf "(b2) a canvas directory moved with identical bytes loses its approval (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  git -C "$SB_WORK" mv requirements/design/app2 requirements/design/app
  _dm_commit "the canvas moves back"
  # one defect of each class
  printf '\n##### F1-S3 — Hint\n\n**UI:** default\n\n- [ ] AC1: (UI) a hint shows.\n- [ ] AC2: (UI) a bad state. [design: UX-001#nostate]\n- [ ] AC3: (UI) no such screen. [design: UX-077#a]\n' >> "$SB_WORK/requirements/PRD-001-app.md"
  printf '\n### F2 — Later\n\n**Design:** pending\n\n##### F2-S1 — Later\n\n**UI:** default\n\n- [ ] AC1: (UI) already designed. [design: UX-002#default]\n' >> "$SB_WORK/requirements/PRD-001-app.md"
  printf '| UX-003 | C.dc.html | t | phone |  | default |  | open | approved |\n' >> "$SB_WORK/requirements/design/app/CANVAS.md"
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' '<h1 id="ux-003-title" style="color: #ff0000">Lit</h1>'
  printf '| UX-004 | D.dc.html | t | phone |  | default | PRD-001-F1-S2 | approved@%s (ming) | approved (pending) |\n' "$X" >> "$SB_WORK/requirements/design/app/CANVAS.md"
  printf '| UX-005 | E.dc.html | t | phone |  | default | PRD-001-F1-S2 | approved@deadbee | open |\n' >> "$SB_WORK/requirements/design/app/CANVAS.md"
  printf '| UX-006 | Zmissing.dc.html | t | phone |  | default | PRD-001-F1-S2 | approved@%s | open |\n' "$X" >> "$SB_WORK/requirements/design/app/CANVAS.md"
  _dm_card 901 in_progress "design: [ux-001#default]"
  _dm_card 902 in_progress "design: TBD"
  _dm_card 903 in_progress "design: [UX-001#default@deadbee]"
  _dm_card 904 declined "design: [UX-001#default]"
  printf '\n```\n' >> "$SB_WORK/requirements/PRD-001-app.md"
  _dm_commit "defects"
  _dm_py scripts/design/check-design-links.py --strict
  out="$_dm_out"
  [ "$_dm_rc" -eq 1 ] || cf "(c) the project with defects exits $_dm_rc under --strict, not 1"
  _dm_has "$out" "UNCOVERED     requirements/PRD-001-app.md:" || cf "(d) no UNCOVERED line for an (UI) AC with no marker"
  { _dm_has "$out" "UNRESOLVED    requirements/PRD-001-app.md:" && _dm_has "$out" "UX-077 has no registry row"; } || cf "(d) no UNRESOLVED line for a citation of a screen with no row"
  _dm_has "$out" "UX-001#nostate - the registry lists states" || cf "(d) no UNRESOLVED line for a citation of a state the row does not list"
  _dm_has "$out" "NO-STORY      requirements/design/app/CANVAS.md" || cf "(d) no NO-STORY line for a row that cites no story"
  _dm_has "$out" "STALE-PENDING requirements/PRD-001-app.md" || cf "(d) no STALE-PENDING line for a Design: pending section that already has a marker"
  _dm_has "$out" "APPROVAL-NO-SHA" || cf "(d) no APPROVAL-NO-SHA line for a gate cell that says approved with no sha"
  _dm_has "$out" "GATE-CELL" && _dm_has "$out" "UX-004 gate1 is \`approved@" && _dm_has "$out" "UX-004 gate2 is \`approved (pending)\`" || cf "(d) no GATE-CELL line for a gate cell with words after the sha, or for 'approved (pending)'"
  _dm_has "$out" "APPROVAL-UNRESOLVED" || cf "(d) no APPROVAL-UNRESOLVED line for approved@<sha> whose sha is not a commit (a shallow clone reads this way too)"
  _dm_has "$out" "ARTBOARD      requirements/design/app/CANVAS.md" && _dm_has "$out" "Zmissing.dc.html is not there" || cf "(d) no ARTBOARD line for an approved row whose file is not there"
  _dm_has "$out" "$SB_PREFIX-901-c.md: design: \`[ux-001#default]\` is not none" && _dm_has "$out" "$SB_PREFIX-902-c.md: design: \`TBD\`" || cf "(d) no DESIGN-KEY line for a design: value that is not none or a list of UX-NNN#state"
  _dm_has "$out" "$SB_PREFIX-903-c.md: pin @deadbee of UX-001#default is not a commit" || cf "(d) a pin that is not a commit, on a card past todo/, is not an UNRESOLVED finding under --strict"
  _dm_has "$out" "$SB_PREFIX-904-c.md" && cf "(d) the check read a declined card, whose pin is nobody's to keep"
  _dm_has "$out" "FENCE" && _dm_has "$out" "never closed" || cf "(d) no FENCE line for a PRD whose code fence is never closed"
  _dm_has "$out" "LITERAL-COLOUR requirements/design/app/project/C.dc.html: #ff0000" || cf "(d) no LITERAL-COLOUR line for a colour literal in a style outside the :root block"
  _dm_has "$out" "LITERAL-COLOUR requirements/design/app/project/A.dc.html" && cf "(d) a colour literal inside a :root block was reported"
  # the approval of UX-001 was recorded against the commit that took in the artboard, which has not changed since
  _dm_has "$out" "UX-001 gate1 approved@${X:0:7}, but" && cf "(e) an approval of an artboard that has not changed since reads stale"
  _dm_edit "$D/A.dc.html" 's|>List<|>Lists<|'
  _dm_commit "the approved artboard changes"
  _dm_py scripts/design/check-design-links.py
  { _dm_has "$_dm_out" "STALE-APPROVAL" && _dm_has "$_dm_out" "UX-001 gate1 approved@${X:0:7}"; } || cf "(e) no STALE-APPROVAL for UX-001 after its artboard changed"
  [ "$_dm_rc" -eq 0 ] || cf "(f) without --strict the check is a report and exits $_dm_rc, not 0"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — --leaving ANSWERS FOR A CARD ABOUT TO LEAVE todo/: A PIN, A COMMIT THAT RESOLVES, AN APPROVED ROW OR A WAIVER.
#   Operand: scripts/design/check-design-links.py --leaving <card>, exit 1 with the class named for each refusal and 0 for a
#   card that has all three or none to give (design: none); 2 for a card it cannot read.
# =============================================================================
case_the_leaving_check_refuses_an_unpinned_unresolved_or_unapproved_pin_and_accepts_a_waiver() {
  cf_reset
  local L="check-design-links.py --leaving exits 1 naming UNPINNED, BARE-PIN, UNRESOLVED (a pin that is not a commit) and NOT-APPROVED for a card in todo/ that owes them, exits 0 for a pin to an approved row, for a waiver on the design: line and for design: none, and 2 for a card it cannot read"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_links_fixture || { finish "$L"; teardown; return; }
  local X="$_DM_X" Y="$_DM_Y" dn dm dw
  dn="D-$((6 + 6))"; dm="D-$((70 + 7))"   # built here: a decision id written out in a shipped file is read as a citation of the project's register
  _dm_card 801 todo "design: [UX-001#default]"
  _dm_card 802 todo "design: [UX-001]"
  _dm_card 803 todo "design: [UX-001#default@$X]"
  _dm_card 804 todo "design: [UX-002#default@$X]"
  _dm_card 805 todo "design: [UX-002#default@$X]   # [decision: $dn]"
  _dm_card 806 todo "design: [UX-001#default@deadbee]"
  _dm_card 807 todo "design: none"
  _dm_leaving 801; { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "UNPINNED"; } || cf "(a) an unpinned design: entry is not refused with UNPINNED (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_leaving 802; { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "BARE-PIN" && _dm_has "$_dm_out" "UNPINNED"; } || cf "(b) a bare UX id is not refused with BARE-PIN and UNPINNED (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_leaving 803; { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "0 finding(s)"; } || cf "(c) a pin to an approved row at a real commit is refused (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_leaving 804; { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "NOT-APPROVED"; } || cf "(d) a pin to a row whose gate1 is open is not refused with NOT-APPROVED (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_leaving 805; { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "WAIVER"; } || cf "(e) a waiver the project has no register to confirm is accepted (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  printf '# Decisions\n\n### %s — a ruling\n\n**Ruling.** A ruling.\n' "$dn" > "$SB_WORK/requirements/DECISIONS.md"
  _dm_commit "a register"
  _dm_leaving 805; [ "$_dm_rc" -eq 0 ] || cf "(e) a pin to an open row with a waiver the register confirms is refused (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_card 810 todo "design: [UX-002#default@$X]   # [decision: $dm]"
  _dm_leaving 810; { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "$dm is not an entry in requirements/DECISIONS.md"; } || cf "(e) a waiver citing a decision the register has no entry for is accepted (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_leaving 806; { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "deadbee of UX-001#default is not a commit"; } || cf "(f) a pin to a commit that does not exist is not refused as UNRESOLVED (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_leaving 807; [ "$_dm_rc" -eq 0 ] || cf "(g) design: none is refused (exit $_dm_rc)"
  _dm_card 808 todo "design: [ux-001#default]"
  _dm_card 809 todo "design: TBD"
  _dm_leaving 808; { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "DESIGN-KEY"; } || cf "(i) a design: value in the wrong shape is not refused with DESIGN-KEY (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_leaving 809; { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "DESIGN-KEY"; } || cf "(i) design: TBD is not refused with DESIGN-KEY (exit $_dm_rc)"
  mkdir -p "$SB_WORK/dev/drafts"
  printf -- '---\nid: %s-814\ndesign: [UX-001#default]\n---\n' "$SB_PREFIX" > "$SB_WORK/dev/drafts/$SB_PREFIX-814-c.md"
  _dm_py scripts/design/check-design-links.py --leaving "dev/drafts/$SB_PREFIX-814-c.md"
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "UNPINNED"; } || cf "(j) a card that sits outside progress/<shelf>/ is not read (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  printf '| UX-003 | C.dc.html | t | phone |  | default | PRD-001-F1-S2 | approved | open |\n' >> "$SB_WORK/requirements/design/app/CANVAS.md"
  _dm_commit "a row approved with no sha"
  _dm_card 813 todo "design: [UX-003#default@$X]"
  _dm_leaving 813; { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "NOT-APPROVED"; } || cf "(k) a pin to a row whose gate1 is plain 'approved' is not refused with NOT-APPROVED (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_edit "$SB_WORK/requirements/design/app/CANVAS.md" "s/| UX-002 | B.dc.html | t | phone |  | default | PRD-001-F1-S2 | open |/| UX-002 | B.dc.html | t | phone |  | default | PRD-001-F1-S2 | approved@$Y |/"
  _dm_commit "approve UX-002 after the pin"
  _dm_card 811 todo "design: [UX-002#default@$X]"
  _dm_leaving 811; { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "PIN-ORDER"; } || cf "(l) a pin older than the approval of its row is not refused with PIN-ORDER (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_edit "$SB_WORK/requirements/design/app/project/A.dc.html" 's|>List<|>Lists<|'
  _dm_commit "the approved artboard changes"
  _dm_card 815 todo "design: [UX-001#default@$X]   # [decision: $dn]"
  _dm_leaving 815; [ "$_dm_rc" -eq 0 ] || cf "(n) a waiver the register confirms does not stand in for an approval gone stale (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  dw="D-$((40 + 2))"
  printf '\n### %s — a ruling since withdrawn\n\n**Ruling.** WITHDRAWN 2026-01-01 — nothing replaces it.\n' "$dw" >> "$SB_WORK/requirements/DECISIONS.md"
  _dm_commit "a withdrawn entry"
  _dm_card 816 todo "design: [UX-002#default@$X]   # [decision: $dw]"
  _dm_leaving 816; { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "WITHDRAWN"; } || cf "(o) a waiver citing a withdrawn entry, which has no current ruling, is accepted (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_leaving 803; { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "STALE-APPROVAL"; } || cf "(m) a pin to a row whose approval is stale at HEAD is not refused with STALE-APPROVAL (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_py scripts/design/check-design-links.py --leaving "progress/todo/nothing.md"
  [ "$_dm_rc" -eq 2 ] || cf "(h) a card that is not a file exits $_dm_rc, not 2"
  finish "$L"
  teardown
}
_dm_leaving() { _dm_py scripts/design/check-design-links.py --leaving "progress/todo/$SB_PREFIX-$1-c.md"; }   # <card number>

# =============================================================================
# CASE — THE PRD VIEW LISTS WHAT A PRD REACHES AND WHERE THE REGISTRY AND THE MARKERS DISAGREE; THE FLOW GRAPH COMES FROM THE LINKS.
#   Operand: scripts/design/prd-view.py and scripts/design/flow-from-links.py over the links fixture. The view's file is
#   generated and says so; the graph has one edge per board link, a '#anchor' read off the target.
# =============================================================================
case_the_prd_view_lists_what_a_prd_reaches_and_the_flow_graph_comes_from_the_artboards_links() {
  cf_reset
  local L="prd-view.py lists the screens and states PRD-001 reaches, flags a registry story no marker cites and a marker the row does not list, and --md writes a views/ file that says it is generated; flow-from-links.py prints one Mermaid edge per board link"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_links_fixture || { finish "$L"; teardown; return; }
  local v="$SB_WORK/requirements/design/views/PRD-001.md" n
  _dm_py scripts/design/prd-view.py PRD-001
  _dm_has "$_dm_out" "reaches 2 screen(s)" || cf "(a) the view of PRD-001 does not say it reaches 2 screens: $(printf '%s' "$_dm_out" | head -2 | tr '\n' '|' | cut -c1-200)"
  { _dm_has "$_dm_out" "UX-001#default" && _dm_has "$_dm_out" "UX-001#empty" && _dm_has "$_dm_out" "UX-002#default"; } || cf "(a) the view does not list each cited state"
  _dm_has "$_dm_out" "0 disagreement(s)" || cf "(a) the consistent fixture shows a disagreement: $(printf '%s' "$_dm_out" | tail -3 | tr '\n' '|' | cut -c1-200)"
  [ ! -e "$v" ] || cf "(b) the view wrote a file without --md"
  _dm_py scripts/design/prd-view.py PRD-001 --md
  [ -f "$v" ] || cf "(b) --md wrote no requirements/design/views/PRD-001.md"
  if [ -f "$v" ]; then head -1 "$v" | grep -F 'GENERATED' >/dev/null || cf "(b) the written view's first line does not say it is generated"; fi
  # a story the registry gives a row and no marker cites; a marker the row does not list
  _dm_edit "$SB_WORK/requirements/design/app/CANVAS.md" 's/| UX-002 | B.dc.html | t | phone |  | default | PRD-001-F1-S2 |/| UX-002 | B.dc.html | t | phone |  | default | PRD-001-F1-S2 PRD-001-F1-S1 |/'
  printf -- '- [ ] AC4: (UI) a hint. [design: UX-001#default]\n' >> "$SB_WORK/requirements/PRD-001-app.md"
  _dm_edit "$SB_WORK/requirements/design/app/CANVAS.md" 's/PRD-001-F1-S1 | approved@/PRD-001-F1-S2 | approved@/'
  _dm_py scripts/design/prd-view.py PRD-001
  _dm_has "$_dm_out" "REGISTRY-ONLY  UX-002: registry lists PRD-001-F1-S1" || cf "(c) no REGISTRY-ONLY line for a story the registry lists on a screen none of its markers cites: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_has "$_dm_out" "MARKER-ONLY" || cf "(c) no MARKER-ONLY line for a marker on a story the row does not list"
  # the graph
  _dm_py scripts/design/flow-from-links.py requirements/design/app/project
  _dm_has "$_dm_out" "flowchart LR" || cf "(d) flow-from-links.py prints no Mermaid flowchart: $(printf '%s' "$_dm_out" | head -3 | tr '\n' '|')"
  { _dm_has "$_dm_out" 'A -->|"List"| B' && _dm_has "$_dm_out" 'B -->|"Edit"| A'; } || cf "(d) the graph lacks an edge for each board link: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  n="$(printf '%s\n' "$_dm_out" | grep -c -- '-->' || true)"
  [ "$n" = 2 ] || cf "(d) the graph has $n edges for two links"
  # boards whose names are not ASCII, one with a space in it reached through %20, and a canvas.json that is a list
  local P="$SB_WORK/requirements/design/app/project"
  printf '<x-dc><a id="x" href="%s">go on</a></x-dc>\n' 'My%20Screen.dc.html' > "$P/ä.dc.html"
  printf '<x-dc><a id="y" href="%s">back</a></x-dc>\n' 'ä.dc.html' > "$P/ö.dc.html"
  printf '<x-dc><p>end</p></x-dc>\n' > "$P/My Screen.dc.html"
  printf '[]\n' > "$P/canvas.json"
  _dm_py scripts/design/flow-from-links.py requirements/design/app/project
  _dm_has "$_dm_out" "Traceback" && cf "(e) a canvas.json that is a list stops the graph: $(printf '%s' "$_dm_out" | tail -1)"
  _dm_has "$_dm_out" "which is not in" && cf "(e) a link written with %20 is read as a board that is not there: $(printf '%s' "$_dm_out" | /usr/bin/grep -m1 'not in')"
  n="$(printf '%s\n' "$_dm_out" | /usr/bin/grep -E '^    [A-Za-z0-9_]+\[' | sed -E 's/^ +([A-Za-z0-9_]+)\[.*/\1/' | sort -u | wc -l | tr -d ' ')"
  [ "$n" = 5 ] || cf "(e) five boards, two of them with non-ASCII names, are $n distinct nodes: the names collapse"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — WHILE THE MODULE PLACES A PYTHON TOOL ITS MANIFEST REQUIRES PYTHON 3, AND status SAYS WHETHER IT HOLDS.
#   The expected answer is fixed here: a `requires:` line with the id python3 and severity required, read from module.manifest,
#   whenever a line of that manifest places a file ending .py; SETUP.md names it. Enable refuses, with the way to get it, when
#   the check fails (the check is run with python3 absent from PATH).
# =============================================================================
case_the_manifest_requires_python3_while_it_places_a_python_tool_and_enable_refuses_without_it() {
  cf_reset
  local L="while module.manifest places a .py file it declares a required requirement with the id python3, SETUP.md names it, status says it holds, and enable refuses with a Next: line when python3 is not found"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  local m="$REAL_REPO_ROOT/modules/design" bare t
  if awk '$1 == "file:" && $0 ~ /[.]py[[:space:]]*$/ { f = 1 } END { exit !f }' "$m/module.manifest"; then
    grep -E '^requires:[[:space:]]*python3 \|.*\| required[[:space:]]*$' "$m/module.manifest" >/dev/null || cf "(a) the manifest places a .py file and declares no required python3 requirement"
    grep -F 'Python 3' "$m/SETUP.md" >/dev/null || cf "(a) SETUP.md does not name Python 3"
  else
    cf "(prereq) the manifest places no .py file: this case's subject is gone"
  fi
  if _dm_python; then
    _md_sandbox
    _md_mod enable design
    [ "$_md_rc" -eq 0 ] || cf "(b) enable exited $_md_rc with python3 present: $_md_out"
    _md_mod status design
    _dm_has "$_md_out" "python3" || cf "(b) status does not name the python3 requirement: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
    teardown
  fi
  # python3 hidden: a PATH holding the programs enable needs and no python3
  bare="$(mktemp -d)"
  _md_sandbox
  for t in sh bash git awk sed grep cat cp mv rm mkdir mktemp dirname basename sort find tr head tail cut wc tee printf date env ls ln chmod touch uniq comm xargs perl shasum sha256sum diff cmp od; do
    if command -v "$t" >/dev/null 2>&1; then ln -s "$(command -v "$t")" "$bare/$t"; fi
  done
  rm -rf "$SB_TMP/records"; _md_rc=0
  _md_out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/records" PATH="$bare" /bin/bash ./scripts/module.sh enable design 2>&1 </dev/null )" || _md_rc=$?
  [ "$_md_rc" -ne 0 ] || cf "(c) enable succeeded with python3 not found"
  { _dm_has "$_md_out" "python3" && _dm_has "$_md_out" "Next:"; } || cf "(c) enable's refusal does not name python3 and a Next: line: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  [ ! -e "$SB_WORK/process/MODULES" ] || cf "(c) the refused enable wrote the record"
  rm -rf "${bare:?}"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A COLOUR LITERAL IS READ WHERE IT IS A COLOUR (A STYLE, A PRESENTATION ATTRIBUTE, THE SCRIPT) AND NOT IN COPY, A SELECTOR,
# A REFERENCE, A COMMENT OR THE :root BLOCK; IT IS A FINDING UNLESS A RECORDED DECISION WAIVES IT.
#   Operand: scripts/design/check-design-links.py --strict over a screen that holds only the safe shapes (exit 0, no LITERAL line), then
#   the same screen with a colour in each place a colour can be (exit 1, a line naming each), then the same screen with a recorded decision on its registry row (exit 0 only if the register holds it with a current ruling).
# =============================================================================
case_the_link_check_reads_a_colour_where_it_is_a_colour_and_fails_the_gate_unless_a_recorded_decision_waives_it() {
  cf_reset
  local L="check-design-links.py --strict fails a colour literal in a style block, a style attribute, a presentation attribute (quoted or not) or a local linked sheet outside :root, and not Order #1042, a comment in CSS or in the script, copy in the script, a selector, url(#id), :root[...], :root, :host in any case, or a token sheet that only defines :root; a colour in the script is a report line that leaves --strict at exit 0; a [decision: D-NN] on the screen's registry row excuses a screen only when the register holds the entry with a Ruling that is not WITHDRAWN (the token bare, in backticks or bold), and an id in a fence, a comment or with no Ruling is no entry; the brief's fenced text states the rule"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_links_fixture || { finish "$L"; teardown; return; }
  local D="$SB_WORK/requirements/design/app/project" dn="D-$((6 + 6))" body
  printf '| UX-003 | C.dc.html | t | phone |  | default | PRD-001-F1-S1 | open | open |\n' >> "$SB_WORK/requirements/design/app/CANVAS.md"
  printf ':root { --color-primary: #485d92; }\n:root[data-theme="dark"] { --color-primary: #a0b4e8; }\n:ROOT, :host { --x: #fff; }\n[data-theme="dark"] { --color-surface: #121318; }\n@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { --color-surface: #121318; } }\n' > "$D/tokens.css"
  body='<link rel="stylesheet" href="tokens.css"><h1 id="ux-003-title" style="color: var(--color-primary)">Order #1042 <a href="#fab">x</a></h1><!-- #fff --><style>/* was #ff0000 */ #add { color: var(--color-primary) } .b { background: url( #fade ); content: "#1042"; color: rgb(var(--x-rgb) / .5) }</style><input data-target="#abc" data-style="#abc"><p>fill="#fff" &#35;ff0000 color: red</p><script type="text/x-dc">// issue #123
const copy = { label: "Order #1042" }; document.querySelector("#add"); location.hash = "#feed"; function color(x) { return x; }</script>'
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' "$body"
  _dm_commit "a screen with no colour in it"
  _dm_py scripts/design/check-design-links.py --strict
  [ "$_dm_rc" -eq 0 ] || cf "(a) copy, comments, a selector, a reference, :root in its forms, a token sheet or script text is read as a colour (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_has "$_dm_out" "LITERAL-COLOUR" && cf "(a) a LITERAL-COLOUR line for a screen whose only colours are in :root rules"
  # colour only in the script: a report line, and the gate stays at 0
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' '<h1 id="ux-003-title" style="color: var(--color-primary)">Script</h1><script type="text/x-dc">const bg = "#c0ffee"; const x = "RGB(1,2,3)";</script>'
  _dm_commit "a colour in the script"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "SCRIPT-COLOUR" && _dm_has "$_dm_out" "#c0ffee" && ! _dm_has "$_dm_out" "LITERAL-COLOUR"; } || cf "(b) a colour in the script is not a report line that leaves --strict at 0 (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  # a colour in each place CSS has one: strict
  printf '.x { color: #ff0000 }\n' > "$D/lit.css"
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' '<link rel="stylesheet" href="lit.css"><h1 id="ux-003-title" style="color: oklch(60% .1 20)">Lit</h1><svg><rect fill=#f00 /></svg><p style=background:#0f0>x</p>'
  _dm_commit "a colour in each place"
  _dm_py scripts/design/check-design-links.py --strict
  [ "$_dm_rc" -eq 1 ] || cf "(c) a colour literal in CSS outside :root does not fail --strict (exit $_dm_rc)"
  for t in 'oklch(' '#f00' '#0f0' '#ff0000 (in requirements/design/app/project/lit.css)'; do
    _dm_has "$_dm_out" "$t" || cf "(c) the line for the screen does not name $t"
  done
  _dm_has "$_dm_out" "change request through the brief" || cf "(c) the line does not say to send a change request through the brief"
  grep -F 'outside the :root block' "$REAL_REPO_ROOT/modules/design/_claude/templates/design/CANVAS.template.md" >/dev/null || cf "(d) the brief's text for the design tool's agent does not state the rule up front"
  grep -F 'uncompared' "$REAL_REPO_ROOT/modules/design/RELEASE-NOTES.md" >/dev/null && grep -F 'uncompared' "$REAL_REPO_ROOT/process/KIT-RELEASE-NOTES.md" >/dev/null || cf "(d) a release note does not name the verdict uncompared"
  grep -iE 'colour literal.*(go red|fail|red)|(go red|fail).*colour' "$REAL_REPO_ROOT/modules/design/RELEASE-NOTES.md" >/dev/null || cf "(d) the module's notes do not tell an upgrading project that screens with colour literals will go red"
  # the one escape: a recorded decision on the screen's registry row, which the register must hold with a current ruling
  _dm_edit "$SB_WORK/requirements/design/app/CANVAS.md" "s/| UX-003 | C.dc.html | t |/| UX-003 | C.dc.html | t [decision: $dn] |/"
  _dm_commit "a waiver on the screen"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "WAIVER" && _dm_has "$_dm_out" "LITERAL-COLOUR"; } || cf "(e) a waiver the project has no register to confirm excuses the colour (exit $_dm_rc)"
  printf '# Decisions\n\n### %s — a ruling\n\n**Ruling.** A ruling.\n' "$dn" > "$SB_WORK/requirements/DECISIONS.md"
  _dm_commit "a register"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "LITERAL-COLOUR"; } || cf "(f) a waiver the register holds does not excuse the colour (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  for body in 'WITHDRAWN 2026-01-01 — nothing replaces it.' '`WITHDRAWN 2026-01-01 — nothing replaces it.`' '**WITHDRAWN** 2026-01-01'; do
    printf '# Decisions\n\n### %s — a ruling\n\n**Ruling.** %s\n' "$dn" "$body" > "$SB_WORK/requirements/DECISIONS.md"
    _dm_commit "the ruling is withdrawn"
    _dm_py scripts/design/check-design-links.py --strict
    { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "WITHDRAWN"; } || cf "(g) a waiver citing a ruling withdrawn as '${body:0:14}' excuses the colour (exit $_dm_rc)"
  done
  for body in '```\n### %s — in a fence\n\n**Ruling.** ruled\n```\n' '<!--\n### %s — in a comment\n\n**Ruling.** ruled\n-->\n' '### %s — no ruling\n\n**Why.** because\n'; do
    printf "# Decisions\n\n$body" "$dn" > "$SB_WORK/requirements/DECISIONS.md"
    _dm_commit "an id that is no entry"
    _dm_py scripts/design/check-design-links.py --strict
    { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "is not an entry"; } || cf "(h) an id that sits in a fence, a comment or an entry with no Ruling is accepted as an entry (exit $_dm_rc)"
  done
  # a waiver that names nothing the register holds is a finding on any row, whether or not the screen has a colour
  printf '# Decisions\n\n### %s — a ruling\n\n**Ruling.** A ruling.\n' "$dn" > "$SB_WORK/requirements/DECISIONS.md"
  _dm_edit "$SB_WORK/requirements/design/app/CANVAS.md" "s/| UX-002 | B.dc.html | t |/| UX-002 | B.dc.html | t [decision: D-$((90 + 9))] |/"
  _dm_commit "a bogus waiver on a clean screen"
  _dm_py scripts/design/check-design-links.py --strict
  { _dm_has "$_dm_out" "WAIVER" && _dm_has "$_dm_out" "D-$((90 + 9)) is not an entry"; } || cf "(i) a waiver naming an id the register lacks, on a screen with no colour, is not a finding"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE TOOLS READ THE PRD PREFIX THE PROJECT DECLARED AND REFUSE, RATHER THAN SAY 0 PRDs, WHEN PRDs SIT UNDER ANOTHER ONE.
#   Operand: the links fixture with its PRDs renamed SPEC-… and scripts/config.sh declaring PRD_PREFIX SPEC: the link check and the
#   PRD view read them (and find a defect planted in one); with the declaration back at PRD the files are under another prefix and the
#   tools exit 2 saying so.
# =============================================================================
case_the_link_check_and_the_prd_view_read_the_prd_prefix_and_refuse_when_prds_sit_under_another() {
  cf_reset
  local L="with PRD_PREFIX SPEC in scripts/config.sh the link check and the PRD view read SPEC-NNN-*.md (and find an uncovered AC planted there); with the declaration at PRD and the files under SPEC both exit 2 naming the other prefix and print no green count"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_links_fixture || { finish "$L"; teardown; return; }
  local f
  for f in "$SB_WORK"/requirements/PRD-*.md; do mv "$f" "$SB_WORK/requirements/SPEC-${f##*/PRD-}"; done
  for f in "$SB_WORK"/requirements/SPEC-*.md "$SB_WORK/requirements/design/app/CANVAS.md" "$SB_WORK"/requirements/design/app/project/*.dc.html; do _dm_edit "$f" 's/PRD-00/SPEC-00/g'; done
  _dm_edit "$SB_WORK/scripts/config.sh" 's/^PRD_PREFIX="${PRD_PREFIX:-PRD}"/PRD_PREFIX="${PRD_PREFIX:-SPEC}"/'
  _dm_commit "the project's PRDs are SPEC"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "in 3 PRD(s)" && _dm_has "$_dm_out" "; 0 finding(s)"; } || cf "(a) the link check does not read three SPEC PRDs cleanly (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_py scripts/design/prd-view.py SPEC-001
  _dm_has "$_dm_out" "reaches 2 screen(s)" || cf "(b) the PRD view does not read SPEC-001: $(printf '%s' "$_dm_out" | head -2 | tr '\n' '|' | cut -c1-200)"
  printf -- '- [ ] AC4: (UI) a hint with no marker.\n' >> "$SB_WORK/requirements/SPEC-001-app.md"
  _dm_commit "an uncovered AC"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "UNCOVERED"; } || cf "(c) an uncovered AC planted in a SPEC PRD is not found (exit $_dm_rc)"
  _dm_edit "$SB_WORK/scripts/config.sh" 's/^PRD_PREFIX="${PRD_PREFIX:-SPEC}"/PRD_PREFIX="${PRD_PREFIX:-PRD}"/'
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 2 ] && _dm_has "$_dm_out" "another prefix"; } || cf "(d) PRDs under another prefix are read as no PRDs (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_has "$_dm_out" "0 finding(s)" && cf "(d) a green count was printed for PRDs it did not read"
  _dm_py scripts/design/prd-view.py PRD-001
  [ "$_dm_rc" -ne 0 ] || cf "(d) the PRD view of an id under no declared prefix exits 0"
  rm -f "$SB_WORK"/requirements/SPEC-*.md
  printf '# ADR-001 — Database\n\nWe use one.\n' > "$SB_WORK/requirements/ADR-001-db.md"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -ne 2 ] && ! _dm_has "$_dm_out" "another prefix"; } || cf "(e) a decision record with no story headings is refused as a PRD under another prefix (exit $_dm_rc)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — NO FILE OF THE MODULE CITES A DECISION ID: THE PROJECT'S CITATION ARM READS THE MODULE'S TEST CASES AS PROSE OF ITS OWN.
#   Operand: every file under modules/design/. A decision id written out in a fixture that the project's register has no entry for
#   fails the project's day-one self-check (a fixture builds the id it needs at run time).
# =============================================================================
case_the_design_module_cites_no_decision_id_the_project_cannot_hold() {
  cf_reset
  local L="no file under modules/design/ contains a decision id written D-<digits>"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  local hits
  hits="$(find "$REAL_REPO_ROOT/modules/design" -type f -exec grep -nE '(^|[^A-Za-z0-9])D-[0-9]+' {} + 2>/dev/null || true)"
  [ -z "$hits" ] || cf "a decision id is written out: $(printf '%s' "$hits" | tr '\n' '|' | cut -c1-240)"
  finish "$L"
}
