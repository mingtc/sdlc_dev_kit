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
  git -C "$SB_WORK" pull -q --rebase origin "$SB_TRUNK" >/dev/null 2>&1   # a mover or a landing may have advanced the trunk since
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
# DORMANT HALF: the 'line required' arm fires only for a capability module.manifest does not place; with every capability placed (as shipped)
# only the 'line must be dropped' arm runs.
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
50-design-pin.sh|move-check|^in_progress/
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
  # (e) the Designer authors on the canvas itself and carries the sha check and the read-back; no text sends a human to carry files or a brief.
  for tok in 'list_files' 'base_version' 'warnings' 'Send to Claude' 'read back'; do
    grep -F -- "$tok" "$role" >/dev/null || cf "(e) the Designer role does not carry '$tok' (the pull-before-publish order, the sha check, the read-back, the stop on a warning, the comment route)"
  done
  hits="$(find "$m" -type f -not -path "$m/test/*" -exec grep -niE "conduit|design tool's agent|Claude Design's (own )?agent|change request|human (carries|draws|edits|switches)" {} + || true)"
  [ -z "$hits" ] || cf "(e) design text still has the human carrying work to another agent, or no direct authoring: $(printf '%s' "$hits" | tr '\n' '|' | cut -c1-200)"
  # (f) creating and updating the canvas is not on the needs-the-next-version list: the Designer does it with the artifact tools now.
  printf '%s\n' "$lines" | grep -F 'Creating and updating' >/dev/null && cf "(f) the Designer role still lists creating and updating the canvas as needing the next version of the kit"
  grep -F 'do not improvise' "$role" >/dev/null || cf "(f) the Designer role does not tell the agent not to improvise when neither artifact tool is present"
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
# DORMANT HALF: arm (a) runs only while module.manifest places no render.py; with render.py placed (as shipped) only the QA guide's
# arm (b) is asserted. The name describes both halves; (a) fires if render.py is ever dropped from the manifest.
case_no_design_text_tells_a_role_to_render_the_pinned_side_while_the_renderer_is_absent() {
  cf_reset
  local L="while module.manifest places no render.py, no shipped design text tells a role to render the pinned side, and the QA guide names the committed PNG read with git show and forbids a PASS without an image"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  local m="$REAL_REPO_ROOT/modules/design" f hits qa
  if ! _dm_manifest_places "$m/module.manifest" file '^scripts/design/render[.]py$'; then   # once render.py is placed the text is the renderer's own; the QA guide's rules below stay
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      hits="$(grep -niE 'git archive|render(s)? the pinned|QA renders|render the build' "$f" || true)"
      [ -z "$hits" ] || cf "(a) ${f#$REAL_REPO_ROOT/} tells a role to render while render.py is absent: $(printf '%s' "$hits" | tr '\n' '|' | cut -c1-160)"
    done <<DM_FILES_EOF
$(find "$m" -type f -not -path "$m/test/*")
DM_FILES_EOF
  fi
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
# _dm_why — what the last render said: its exit status and the first 200 characters of its output. A failed row prints it, so a Chrome that timed out or died is named, never a bare "got ".
_dm_why() { printf 'render exit %s: %s' "$_dm_rc" "$(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"; }
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
# _dm_sha256_bin <dir> [<sha256sum> [<shasum>]] — puts a sha256sum into <dir>, for a scratch PATH: the host's own when it has one, else `shasum -a 256` in a wrapper.
# The two paths default to the host's; an empty one says the host lacks that tool.
_dm_sha256_bin() {
  local own="${2-$(command -v sha256sum 2>/dev/null)}" sh2="${3-$(command -v shasum 2>/dev/null)}"
  if [ -n "$own" ]; then ln -s "$own" "$1/sha256sum"
  else printf '#!/bin/sh\nexec %s -a 256 "$@"\n' "$sh2" > "$1/sha256sum"; chmod +x "$1/sha256sum"
  fi
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
#   UX-026 now reads clean: a file neither revision holds cannot have changed. UX-037 loads /_blob/<hash>, UX-038 {{item.image}}: clean
#   UX-040 is shaped like a real export (support.js absent, helmet, fonts link, data-props, <dc-import>) and unchanged: clean
#   UX-041 the same, the imported Header changed: drift. UX-042 loads vendor.js, which changed: drift
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
  _dm_art "$D/T37.dc.html" 037 "$S" '<img src="/_blob/5f2a9c" alt=""><h1 id="ux-037-t" style="color: var(--color-surface)">Blob</h1>'
  _dm_art "$D/T38.dc.html" 038 "$S" '<img src="{{item.image}}" alt=""><h1 id="ux-038-t" style="color: var(--color-surface)">Template</h1>'
  printf '<x-dc><footer id="ftr" style="color: var(--color-surface)">Footer</footer></x-dc>\n' > "$D/Footer.dc.html"
  printf '<x-dc><header id="hdr" style="color: var(--color-surface)">Header</header></x-dc>\n' > "$D/Header.dc.html"
  printf 'var v = 1;\n' > "$D/vendor.js"
  _dm_real() {  # <nnn> <imported screen> <script src> — an artboard shaped like a real export
    local props="data-props='{\"accent\":{\"editor\":\"color\",\"default\":\"#2F6FEB\"},\"\$preview\":{\"width\":390,\"height\":844}}'"
    printf '<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<title>Real</title>\n<script src="%s"></script>\n</head>\n<body>\n<x-dc>\n<helmet>\n<link rel="preconnect" href="https://fonts.googleapis.com">\n<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500&amp;display=swap" rel="stylesheet">\n<style>\nbody{margin:0}\n</style>\n</helmet>\n<div id="ux-%s-root" data-ux="UX-%s" data-stories="PRD-001-F1-S1" style="font-family: Inter, system-ui, sans-serif; color: var(--color-surface)">\n<dc-import name="%s" hint-size="390px,844px"></dc-import>\n<sc-if value="{{a}}"><p data-state="a" id="ux-%s-a">A</p></sc-if>\n</div>\n</x-dc>\n<script type="text/x-dc" data-dc-script %s>\nclass Component extends DCLogic { renderVals() { return {}; } }\n</script>\n</body>\n</html>\n' "$3" "$1" "$1" "$2" "$1" "$props" > "$D/R$1.dc.html"
  }
  _dm_real 040 Footer ./support.js
  _dm_real 041 Header ./support.js
  _dm_real 042 Footer ./vendor.js
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
    'UX-035|T35.dc.html|a, b|PRD-001-F1-S1|open|open' 'UX-036|T36.dc.html|default|PRD-001-F1-S1|open|open' \
    'UX-037|T37.dc.html|default|PRD-001-F1-S1|open|open' 'UX-038|T38.dc.html|default|PRD-001-F1-S1|open|open' \
    'UX-040|R040.dc.html|default, a|PRD-001-F1-S1|open|open' 'UX-041|R041.dc.html|default, a|PRD-001-F1-S1|open|open' \
    'UX-042|R042.dc.html|default, a|PRD-001-F1-S1|open|open'
  _dm_registry "$SB_WORK/requirements/design/café" 'UX-014|K.dc.html|default|PRD-001-F1-S1|open|open'
  _dm_commit "the design at its pin"; _DM_P="$_DM_SHA"
  local p="@$_DM_P" id="$SB_PREFIX"
  _dm_card 701 in_progress "design: [UX-001#default$p, UX-002#default$p, UX-003#default$p, UX-004#default$p, UX-004#default@deadbee, UX-099#x$p, UX-005#a$p, UX-005#b$p, UX-006#a$p, UX-007#default$p, UX-008#default$p, UX-009#default$p]"
  _dm_card 706 in_progress "design: [UX-010#default$p, UX-011#default$p, UX-012#default$p, UX-014#default$p, UX-015#typo$p, UX-016#default$p, UX-017#default$p, UX-018#b$p, UX-019#default$p]"
  _dm_card 710 in_progress "design: [UX-020#empty$p, UX-021#empty$p, UX-022#empty$p, UX-023#default$p, UX-024#default$p, UX-025#default$p, UX-026#default$p, UX-027#default$p]"
  _dm_card 711 in_progress "design: [UX-027#default$p, UX-028#default$p, UX-029#default$p, UX-030#default$p, UX-031#default$p, UX-032#default$p, UX-033#default$p, UX-036#default$p]"
  _dm_card 712 in_progress "design: [UX-034#a$p, UX-035#b$p]"
  _dm_card 713 in_progress "design: [UX-026#default$p, UX-037#default$p, UX-038#default$p, UX-040#default$p, UX-040#a$p, UX-041#default$p, UX-042#default$p]"
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
  printf '<x-dc><header id="hdr" style="color: var(--color-surface)">Header two</header></x-dc>\n' > "$D/Header.dc.html"
  printf 'var v = 2;\n' > "$D/vendor.js"
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
  c="$SB_PREFIX-713"
  for n in 26 37 38; do
    [ "$(_dm_verdict "$_dm_out" "$c" "UX-0$n#default@$p7")" = clean ] || cf "(u) UX-0$n, which loads a file neither revision holds (missing.css, /_blob/, a template value), does not read clean: $(_dm_row "$_dm_out" "$c" "UX-0$n#default@$p7")"
  done
  for st in default a; do
    [ "$(_dm_verdict "$_dm_out" "$c" "UX-040#$st@$p7")" = clean ] || cf "(v) UX-040#$st, shaped like a real export with support.js in no project, does not read clean: $(_dm_row "$_dm_out" "$c" "UX-040#$st@$p7")"
  done
  r="$(_dm_row "$_dm_out" "$c" "UX-041#default@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-041#default@$p7")" = drift ] && _dm_has "$r" "files: Header.dc.html"; } || cf "(w) UX-041, whose <dc-import>ed Header changed, does not read drift on it: $r"
  r="$(_dm_row "$_dm_out" "$c" "UX-042#default@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-042#default@$p7")" = drift ] && _dm_has "$r" "files: vendor.js"; } || cf "(w) UX-042, whose script changed, does not read drift on it: $r"
  c="$SB_PREFIX-710"
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
  _dm_tokens '{"color":{"primary":{"$value":"#485d92"},"surface":{"$value":"#ffffff"}}}'
  _dm_tokens '{"color":{"primary":{"$value":"#a0b4e8"},"surface":{"$value":"#121318"}}}' app.dark.tokens.json
  _dm_art "$D/A.dc.html" 001 '--color-primary: #485d92;' '<h1 id="ux-001-title" style="color: var(--color-primary)"><a href="B.dc.html#top">List</a></h1>'
  _dm_art "$D/B.dc.html" 002 '--color-primary: #485d92;' '<h1 id="ux-002-title" style="color: var(--color-primary)"><a href="A.dc.html">Edit</a></h1>' PRD-001-F1-S2
  _dm_registry "$SB_WORK/requirements/design/app" 'UX-001|A.dc.html|default, empty|PRD-001-F1-S1|open|open' 'UX-002|B.dc.html|default|PRD-001-F1-S2|open|open'
  printf '# PRD-001 — App\n\n## Features\n\n### F1 — Lists\n\n#### Stories\n\n##### F1-S1 — See the list\n\n**UI:** default, empty\n\n**Acceptance Criteria**\n\n- [ ] AC1: (UI) the list shows. [design: UX-001#default]\n- [ ] AC2: (UI) an empty list shows a hint. [design: UX-001#empty]\n- [ ] AC3: the list is sorted.\n\n##### F1-S2 — Edit\n\n**UI:** default\n\n- [ ] AC1: (UI) the edit form shows. [design: UX-002#default]\n' > "$SB_WORK/requirements/PRD-001-app.md"
  printf '# PRD-002 — Api\n\n## Features\n\n### F1 — Endpoint\n\n##### F1-S1 — Serve\n\n- [ ] AC1: it serves.\n\n##### F1-S2 — Log\n\n- [ ] AC1: it logs.\n\n~~~\n```\ninside\n~~~\n\n```code```\n' > "$SB_WORK/requirements/PRD-002-api.md"
  printf '# PRD-003 — Mixed\n\n## Features\n\n### F1 — Bits\n\n##### F1-S1 — One\n\n**UI:** none\n\n- [ ] AC1: one.\n\n##### F1-S2 — Two\n\n- [ ] AC1: two.\n\nA line of prose, then an indented block that is code, not a fence.\n\n    ```\n' > "$SB_WORK/requirements/PRD-003-mixed.md"
  _dm_png "$SB_WORK/requirements/design/app/renders/A-default.png" LIST
  _dm_png "$SB_WORK/requirements/design/app/renders/B-default.png" EDIT
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
  _dm_has "$out" "Zmissing.dc.html is not there. Next: " || cf "(d) the ARTBOARD line for an approved row whose file is not there names no next action"
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
  _dm_has "$_dm_out" "which is not in" && cf "(e) a link written with %20 is read as a board that is not there: $(printf '%s' "$_dm_out" | grep -m1 'not in')"
  n="$(printf '%s\n' "$_dm_out" | grep -E '^    [A-Za-z0-9_]+\[' | sed -E 's/^ +([A-Za-z0-9_]+)\[.*/\1/' | sort -u | wc -l | tr -d ' ')"
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
  printf ':root { --color-primary: #485d92; }\n:root[data-theme="dark"] { --color-primary: #a0b4e8; }\n:ROOT, :host { --color-surface: #fff; }\n[data-theme="dark"] { --color-surface: #121318; }\n@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { --color-surface: #121318; } }\n' > "$D/tokens.css"
  body='<link rel="stylesheet" href="tokens.css"><h1 id="ux-003-title" style="color: var(--color-primary)">Order #1042 <a href="#fab">x</a></h1><!-- #fff --><style>/* was #ff0000 */ #add { color: var(--color-primary) } .b { background: url( #fade ); content: "#1042"; color: rgb(var(--x-rgb) / .5) }</style><input data-target="#abc" data-style="#abc"><p>fill="#fff" &#35;ff0000 color: red</p><script type="text/x-dc">// issue #123
const copy = { label: "Order #1042" }; document.querySelector("#add"); location.hash = "#feed"; function color(x) { return x; }</script>'
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' "$body"
  _dm_commit "a screen with no colour in it"
  _dm_py scripts/design/check-design-links.py --strict
  [ "$_dm_rc" -eq 0 ] || cf "(a) copy, comments, a selector, a reference, :root in its forms, a token sheet or script text is read as a colour (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_has "$_dm_out" "LITERAL-COLOUR" && cf "(a) a LITERAL-COLOUR line for a screen whose only colours are in :root rules"
  # a custom property that is no token's carries a colour nobody tokenised: a finding, in a rule, a :root rule and an attribute
  for body in '<style>.chip { --chip-bg: #ffeedd; background: var(--chip-bg) }</style>' '<style>:root { --mine: #ff0000; color: #00ff00 }</style>' '<p style="--c:#ff0000;color:var(--c)">x</p>'; do
    _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' "$body"
    _dm_commit "a custom property that is no token"
    _dm_py scripts/design/check-design-links.py --strict
    { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "LITERAL-COLOUR"; } || cf "(a2) a colour in a custom property no token has is not a finding (exit $_dm_rc): ${body:0:50}"
  done
  # an imported screen is read as markup: its colour is the importing screen's
  printf '<x-dc><header id="hdr" style="color:#ff0000">Header</header></x-dc>\n' > "$D/Header.dc.html"
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' '<dc-import name="Header" hint-size="390px,844px"></dc-import>'
  _dm_commit "a screen that imports one with a colour"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "#ff0000 (in requirements/design/app/project/Header.dc.html)"; } || cf "(a3) a colour in a <dc-import>ed screen is not found (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  rm -f "$D/Header.dc.html"
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
  _dm_has "$_dm_out" "the Designer corrects the screen with the artifact tools" || cf "(c) the line does not name the next act: the Designer corrects the screen with the artifact tools"
  _dm_has "$_dm_out" "change request" && cf "(c) the line still says to send a change request"
  grep -F 'never a colour literal' "$REAL_REPO_ROOT/modules/design/_claude/templates/design/CANVAS.template.md" >/dev/null || cf "(d) the Designer's spec template does not state the colour rule up front"
  grep -F 'uncompared' "$REAL_REPO_ROOT/modules/design/RELEASE-NOTES.md" >/dev/null && grep -F 'uncompared' "$REAL_REPO_ROOT/process/KIT-RELEASE-NOTES.md" "$REAL_REPO_ROOT/process/KIT-RELEASE-HISTORY.md" 2>/dev/null | grep . >/dev/null || cf "(d) a release note does not name the verdict uncompared"
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

# =============================================================================
# CASE — AN APPROVAL COVERS WHAT THE APPROVED SCREEN LOADS AND THE TOKENS IT USES, NOT ONLY ITS OWN BYTES.
#   Operand: scripts/design/check-design-links.py over a screen approved while it linked a sheet and imported another screen. A change to
#   the sheet, the imported screen, a script it loads or a token it uses after the approval is a STALE-APPROVAL (the gate, and --leaving
#   for a card pinned after the change); a change to a file that is no part of the screen, and a file support.js that no project holds, are not.
# =============================================================================
case_an_approval_covers_what_the_approved_screen_loads_and_the_tokens_it_uses() {
  cf_reset
  local L="a gate cell approved@<sha> goes stale when a linked sheet, an imported screen, a script it loads or a token it uses changes after the approval (--strict and --leaving both say STALE-APPROVAL naming it), and stays good for a change to a file the screen does not load and for support.js being in no project"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_links_fixture || { finish "$L"; teardown; return; }
  local D="$SB_WORK/requirements/design/app/project" Y what
  printf 'h1 { margin: 16px }\n' > "$D/s.css"; printf 'var v = 1;\n' > "$D/vendor.js"; printf 'unused\n' > "$D/other.css"
  printf '<x-dc><header id="hdr" style="color: var(--color-primary)">Header</header></x-dc>\n' > "$D/Header.dc.html"
  _dm_art "$D/A.dc.html" 001 '--color-primary: #485d92;' '<script src="./support.js"></script><link rel="stylesheet" href="s.css"><script src="vendor.js"></script><dc-import name="Header" hint-size="390px,844px"></dc-import><h1 id="ux-001-title" style="color: var(--color-primary)"><a href="B.dc.html#top">List</a></h1>'
  _dm_commit "the screen loads a sheet, a script and a screen"; Y="$_DM_SHA"
  _dm_registry "$SB_WORK/requirements/design/app" "UX-001|A.dc.html|default, empty|PRD-001-F1-S1|approved@$Y|open" 'UX-002|B.dc.html|default|PRD-001-F1-S2|open|open'
  _dm_commit "approve it as it is"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "; 0 finding(s)"; } || cf "(a) the approval is not good straight after it is given, with support.js in no project (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  printf 'unused two\n' > "$D/other.css"; _dm_commit "a file the screen does not load"
  _dm_py scripts/design/check-design-links.py --strict
  [ "$_dm_rc" -eq 0 ] || cf "(b) a change to a file the approved screen does not load stales the approval (exit $_dm_rc)"
  for what in 's.css|h1 { margin: 90px }' 'Header.dc.html|<x-dc><header id="hdr">Header two</header></x-dc>' 'vendor.js|var v = 2;'; do
    git -C "$SB_WORK" checkout -q "$Y" -- "requirements/design/app/project/${what%%|*}" >/dev/null 2>&1
    printf '%s\n' "${what#*|}" > "$D/${what%%|*}"
    _dm_commit "${what%%|*} changes"
    _dm_py scripts/design/check-design-links.py --strict
    { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "STALE-APPROVAL" && _dm_has "$_dm_out" "${what%%|*}"; } || cf "(c) a change to ${what%%|*} after the approval does not stale it, naming it (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
    _dm_card 850 todo "design: [UX-001#default@$_DM_SHA]"
    _dm_leaving 850
    { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "STALE-APPROVAL" && _dm_has "$_dm_out" "${what%%|*}"; } || cf "(c) --leaving over a card pinned after a change to ${what%%|*} does not stale the approval, naming it (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
    git -C "$SB_WORK" checkout -q "$Y" -- "requirements/design/app/project/${what%%|*}" >/dev/null 2>&1
    _dm_commit "${what%%|*} is back"
  done
  _dm_py scripts/design/check-design-links.py --strict
  [ "$_dm_rc" -eq 0 ] || cf "(c0) the approval does not hold again once the files are back (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  # a token the screen uses, changed after the approval
  _dm_tokens '{"color":{"primary":{"$value":"#3b4f82"},"surface":{"$value":"#ffffff"}}}'
  _dm_commit "a token changes"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "STALE-APPROVAL" && _dm_has "$_dm_out" "color-primary"; } || cf "(d) a token the approved screen uses changing after the approval does not stale it (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  # --leaving for a card pinned at the changed state
  _dm_card 851 todo "design: [UX-001#default@$_DM_SHA]"
  _dm_leaving 851
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "STALE-APPROVAL" && _dm_has "$_dm_out" "color-primary"; } || cf "(e) --leaving lets a card pinned after an unapproved token change through, or does not name the token (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  finish "$L"
  teardown
}

# =============================================================================
# THE WIREFRAME MODE'S CASES. The fixture below is one canvas whose Mode line is `wireframe`, whose register holds the ruling the
# line cites, and whose UX-001 is approved at a version that loads a sheet and an imported screen and holds a script, props and
# nested elements. Every expected answer is written in the case.
# =============================================================================
# _dm_mode <text> — set the canvas's Mode line to `- **Mode:** <text>` (an empty text removes the line).
_dm_mode() {
  local f="$SB_WORK/requirements/design/app/CANVAS.md"
  awk -v m="$1" 'NR == 1 { print; if (m != "") print "\n- **Mode:** " m; next } !/^- \*\*Mode:\*\*/ { print }' "$f" > "$f.new" && mv "$f.new" "$f"
}
# _dm_mode_raw <text> — insert text (awk escapes, \n) after the title in place of any Mode line: for a Mode line in a comment or a second one.
_dm_mode_raw() {
  local f="$SB_WORK/requirements/design/app/CANVAS.md"
  awk -v m="$1" 'NR == 1 { print; print "\n" m; next } !/^- \*\*Mode:\*\*/ { print }' "$f" > "$f.new" && mv "$f.new" "$f"
}
_dm_brief() { printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-"${1:-260}"; }
# _dm_line_has <text> <line prefix> <needle> — status 0 when a line of the text starts with the prefix and holds the needle.
_dm_line_has() { printf '%s\n' "$1" | awk -v a="$2" -v b="$3" 'index($0, a) == 1 && index($0, b) { f = 1 } END { exit !f }'; }
_dm_wire_register() { printf '# Decisions\n\n### %s — the canvas is a wireframe\n\n**Ruling.** The build is the visual anchor.\n' "$_DM_DN" > "$SB_WORK/requirements/DECISIONS.md"; }
# _dm_wire_fixture — _DM_W is the approved commit, _DM_V the commit that records the approval and the mode, _DM_DN the ruling's id.
_dm_wire_fixture() {
  _dm_links_fixture || return 1
  local D="$SB_WORK/requirements/design/app/project"
  # elements whose earlier attribute holds a raw > (a title, a props JSON in single quotes): the attributes after it are still read
  _DM_RAWGT="<dc-button title=\"Next >\" id=\"ux-001-next\" data-state=\"default\" href=\"B.dc.html\">Go</dc-button><dc-link data-props='{\"f\":\"a=>b\"}' id=\"ux-001-lnk\" data-state=\"ok\" href=\"B.dc.html\">L</dc-link>"
  _DM_DN="D-$((30 + 1))"   # built here: a decision id written out in a shipped file is read as a citation of the project's register
  _dm_wire_register
  printf 'h1 { margin: 16px }\n' > "$D/s.css"
  printf '<x-dc><header id="hdr">Header</header></x-dc>\n' > "$D/Header.dc.html"
  _dm_art "$D/A.dc.html" 001 '--color-primary: #485d92;' '<link rel="stylesheet" href="s.css"><script>var n = 1;</script><dc-import name="Header"></dc-import><h1 id="ux-001-title" data-props="{&quot;a&quot;:1}" style="color: var(--color-primary)"><a href="B.dc.html#top">List</a></h1><div id="ux-001-g1"><b id="ux-001-b1">x</b></div><i id="ux-001-i1">y</i>'"$_DM_RAWGT"
  _dm_commit "the screen the approval covers"; _DM_W="$_DM_SHA"
  _dm_registry "$SB_WORK/requirements/design/app" "UX-001|A.dc.html|default, empty|PRD-001-F1-S1|approved@$_DM_W|open" 'UX-002|B.dc.html|default|PRD-001-F1-S2|open|open'
  _dm_mode "wireframe [decision: $_DM_DN]"
  _dm_commit "approve UX-001 in wireframe mode"; _DM_V="$_DM_SHA"
  return 0
}
# _dm_wire_restore — the screen files and tokens back as the approval commit recorded them.
_dm_wire_restore() { git -C "$SB_WORK" checkout -q "$_DM_V" -- requirements/design/app/project requirements/design/tokens >/dev/null 2>&1; git -C "$SB_WORK" clean -fdq -- requirements/design/app/project >/dev/null 2>&1; _dm_commit "restored"; }
_dm_wire_guards() {  # <case finish line> — status 1 (after the skip) when the case cannot run
  if ! _dm_have; then skp_lived "$1" "$(_dm_gone_reason)"; return 1; fi
  _ku_have_sha || { skp "$1" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return 1; }
  _dm_python || { skp "$1" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return 1; }
  return 0
}

# =============================================================================
# CASE — IN A WIREFRAME CANVAS AN APPROVAL OF GATE 1 SURVIVES A CHANGE OF CONTENT AND PRESENTATION AND GOES BACK TO REVIEW ON A CHANGE
#   OF STRUCTURE.
#   Operand: scripts/design/check-design-links.py --strict over the wireframe fixture, one edit at a time to the approved screen
#   (restored between). Text, numbers, class, style, a sheet, the script, the props, a token and the text of an imported screen leave
#   the approval good and are shown on a CONTENT-ONLY line; an added, renamed or moved element, a data-state, a link and a change to
#   an imported screen's elements read STALE-APPROVAL saying structure.
# =============================================================================
case_a_wireframe_canvas_keeps_gate_1_through_a_content_edit_and_loses_it_to_a_structural_one() {
  cf_reset
  local L="in a canvas whose Mode line is wireframe, check-design-links.py --strict keeps UX-001's gate 1 approval through an edit of text, a number, class, style, a sheet, the script, the props, a token and an imported screen's text (a CONTENT-ONLY line shows it), and reads STALE-APPROVAL saying structure for an added, renamed or moved element, a data-state, a changed link and a changed imported screen's elements"
  _dm_wire_guards "$L" || return
  _dm_wire_fixture || { finish "$L"; teardown; return; }
  local D="$SB_WORK/requirements/design/app/project" e name file expr
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "; 0 finding(s)"; } || cf "(a) the fixture is not clean before any edit (exit $_dm_rc): $(_dm_brief)"
  _dm_has "$_dm_out" "CONTENT-ONLY" && cf "(a) a canvas nothing has changed in has a CONTENT-ONLY line"
  for e in \
    'text::A.dc.html::s@>List<@>Lists, now 3.<@' \
    'class::A.dc.html::s@<h1 id="ux-001-title"@<h1 class="big" id="ux-001-title"@' \
    'style::A.dc.html::s@color: var(--color-primary)"@color: var(--color-primary); margin: 9px"@' \
    'script::A.dc.html::s@var n = 1;@var n = 2;@' \
    'props::A.dc.html::s@:1}"@:2}"@' \
    'sheet::s.css::s@16px@90px@' \
    'imported text::Header.dc.html::s@>Header<@>Header two<@'; do
    name="${e%%::*}"; e="${e#*::}"; file="${e%%::*}"; expr="${e#*::}"
    _dm_edit "$D/$file" "$expr"; _dm_commit "content: $name"
    _dm_py scripts/design/check-design-links.py --strict
    { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "; 0 finding(s)" && _dm_line_has "$_dm_out" "CONTENT-ONLY" "UX-001"; } || cf "(b) a change of $name does not leave the approval good with a CONTENT-ONLY line (exit $_dm_rc): $(_dm_brief)"
    _dm_has "$_dm_out" "STALE-APPROVAL" && cf "(b) a change of $name reads STALE-APPROVAL in a wireframe canvas"
    _dm_wire_restore
  done
  _dm_tokens '{"color":{"primary":{"$value":"#3b4f82"},"surface":{"$value":"#ffffff"}}}'
  _dm_edit "$D/A.dc.html" 's@#485d92@#3b4f82@'; _dm_edit "$D/B.dc.html" 's@#485d92@#3b4f82@'
  _dm_commit "content: a token and the :root value of each screen that holds it"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_line_has "$_dm_out" "CONTENT-ONLY" "UX-001"; } || cf "(b) a change of a token the screen uses stales a wireframe approval (exit $_dm_rc): $(_dm_brief)"
  _dm_wire_restore
  for e in \
    'an added element::A.dc.html::s@</h1>@</h1><p id="ux-001-hint">Hint</p>@' \
    'a renamed id::A.dc.html::s@ux-001-title@ux-001-heading@' \
    'a moved element::A.dc.html::s@</b></div><i id="ux-001-i1">y</i>@</b><i id="ux-001-i1">y</i></div>@' \
    'a data-state::A.dc.html::s@<div id="ux-001-g1">@<div id="ux-001-g1" data-state="a">@' \
    'a changed link::A.dc.html::s@B.dc.html#top@A.dc.html@' \
    'an imported screen gaining an element::Header.dc.html::s@</header>@</header><nav id="nv"></nav>@' \
    'a rename after a raw > in a title::A.dc.html::s@ux-001-next@ux-001-go@' \
    'a data-state after a raw > in a title::A.dc.html::s@data-state="default"@data-state="error"@' \
    'a link after a raw > in a title::A.dc.html::s@href="B.dc.html">Go@href="C.dc.html">Go@' \
    'a rename after a raw > in single-quoted props::A.dc.html::s@ux-001-lnk@ux-001-go2@' \
    'a data-state after a raw > in single-quoted props::A.dc.html::s@data-state="ok"@data-state="bad"@'; do
    name="${e%%::*}"; e="${e#*::}"; file="${e%%::*}"; expr="${e#*::}"
    _dm_edit "$D/$file" "$expr"; _dm_commit "structure: $name"
    _dm_py scripts/design/check-design-links.py --strict
    { [ "$_dm_rc" -eq 1 ] && _dm_line_has "$_dm_out" "STALE-APPROVAL" "UX-001 gate1" && _dm_has "$_dm_out" "structure"; } || cf "(c) $name does not read STALE-APPROVAL saying structure (exit $_dm_rc): $(_dm_brief)"
    _dm_wire_restore
  done
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "CONTENT-ONLY"; } || cf "(d) the approval does not hold again, with no CONTENT-ONLY line, once the files are back (exit $_dm_rc): $(_dm_brief)"
  # the round: the new sha in the cell clears it
  _dm_edit "$D/A.dc.html" 's@</h1>@</h1><p id="ux-001-hint">Hint</p>@'; _dm_commit "a round adds an element"
  _dm_edit "$SB_WORK/requirements/design/app/CANVAS.md" "s/approved@$_DM_W/approved@${_DM_SHA}/"
  _dm_commit "approve the round"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "; 0 finding(s)"; } || cf "(e) writing the round's commit into the cell does not clear the row (exit $_dm_rc): $(_dm_brief)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE WIREFRAME MODE IS IN EFFECT ONLY WHILE ITS LINE CITES A RULING THE REGISTER HOLDS, AND THE CHECK SAYS WHICH MODE IT READ.
#   Operand: scripts/design/check-design-links.py --strict over the wireframe fixture after a text edit to the approved screen.
#   With the ruling: a MODE line, exit 0. With no register, an id the register lacks, a withdrawn ruling or no id on the line: a
#   WAIVER finding naming a Next, the mode not in effect and the edit reading STALE-APPROVAL. A value that is not none or wireframe is
#   a REGISTRY finding and the default model; `none` is the default model with no finding.
# =============================================================================
case_the_wireframe_mode_needs_a_confirmed_ruling_and_is_named_in_the_checks_output() {
  cf_reset
  local L="check-design-links.py names a wireframe canvas's mode in a MODE line while its Mode line cites a ruling the register holds, and otherwise reports a WAIVER finding with a Next (no register, an id the register lacks, a withdrawn ruling, no id), reads the canvas by the default model, and reads a Mode value that is not none or wireframe as a REGISTRY finding"
  _dm_wire_guards "$L" || return
  _dm_wire_fixture || { finish "$L"; teardown; return; }
  local D="$SB_WORK/requirements/design/app/project" other="D-$((30 + 2))"
  _dm_edit "$D/A.dc.html" 's@>List<@>Lists<@'; _dm_commit "a text edit"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_line_has "$_dm_out" "MODE" "wireframe ($_DM_DN)" && _dm_has "$_dm_out" "gate 1 by structure" && _dm_has "$_dm_out" "gate 2 on the build"; } || cf "(a) a confirmed wireframe canvas gets no MODE line naming the ruling, or does not exit 0 (exit $_dm_rc): $(_dm_brief)"
  git -C "$SB_WORK" rm -q requirements/DECISIONS.md; _dm_commit "no register"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_line_has "$_dm_out" "WAIVER" "not in effect" && _dm_has "$_dm_out" "Next:" && _dm_line_has "$_dm_out" "STALE-APPROVAL" "UX-001 gate1"; } || cf "(b) with no register the mode stands or the finding names no Next (exit $_dm_rc): $(_dm_brief)"
  _dm_has "$_dm_out" "MODE  " && cf "(b) a mode that is not in effect is announced"
  printf '# Decisions\n\n### %s — another ruling\n\n**Ruling.** Another.\n' "$other" > "$SB_WORK/requirements/DECISIONS.md"; _dm_commit "a register without the id"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_line_has "$_dm_out" "WAIVER" "$_DM_DN is not an entry" && _dm_has "$_dm_out" "Next:" && _dm_has "$_dm_out" "STALE-APPROVAL"; } || cf "(c) an id the register lacks keeps the mode in effect (exit $_dm_rc): $(_dm_brief)"
  printf '# Decisions\n\n### %s — withdrawn\n\n**Ruling.** WITHDRAWN 2026-01-01 — nothing replaces it.\n' "$_DM_DN" > "$SB_WORK/requirements/DECISIONS.md"; _dm_commit "the ruling is withdrawn"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_line_has "$_dm_out" "WAIVER" "WITHDRAWN" && _dm_has "$_dm_out" "STALE-APPROVAL"; } || cf "(d) a withdrawn ruling keeps the mode in effect (exit $_dm_rc): $(_dm_brief)"
  _dm_wire_register; _dm_mode "wireframe"; _dm_commit "a Mode line with no ruling"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_line_has "$_dm_out" "WAIVER" "cites no [decision: D-NN]" && _dm_has "$_dm_out" "Next:" && _dm_has "$_dm_out" "STALE-APPROVAL"; } || cf "(e) a Mode line with no ruling keeps the mode in effect, or names no Next (exit $_dm_rc): $(_dm_brief)"
  _dm_mode "wireframes [decision: $_DM_DN]"; _dm_commit "a misspelt mode"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_line_has "$_dm_out" "REGISTRY" "not none or wireframe" && _dm_has "$_dm_out" "STALE-APPROVAL"; } || cf "(f) a Mode value that is not none or wireframe is no REGISTRY finding, or loosens the check (exit $_dm_rc): $(_dm_brief)"
  _dm_mode "none"; _dm_commit "mode none"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "STALE-APPROVAL" && ! _dm_has "$_dm_out" "WAIVER" && ! _dm_has "$_dm_out" "REGISTRY" && ! _dm_has "$_dm_out" "MODE  "; } || cf "(g) Mode none is not the plain default model (exit $_dm_rc): $(_dm_brief)"
  _dm_mode_raw "<!--\n- **Mode:** wireframe [decision: $_DM_DN]\n-->"; _dm_commit "a Mode line in a comment"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "STALE-APPROVAL" && ! _dm_has "$_dm_out" "MODE  " && ! _dm_has "$_dm_out" "WAIVER"; } || cf "(h) a Mode line inside an HTML comment puts the mode in effect (exit $_dm_rc): $(_dm_brief)"
  _dm_mode_raw "- **Mode:** wireframe [decision: $_DM_DN]\n- **Mode:** none"; _dm_commit "two Mode lines that disagree"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_line_has "$_dm_out" "REGISTRY" "contradicts" && _dm_has "$_dm_out" "Next: keep one Mode line" && _dm_has "$_dm_out" "STALE-APPROVAL" && ! _dm_has "$_dm_out" "MODE  "; } || cf "(i) a second Mode line that contradicts the first is not a REGISTRY finding with a Next, read by the default model (exit $_dm_rc): $(_dm_brief)"
  _dm_mode_raw "- **Mode:** wireframe [decision: $_DM_DN]\n- **Mode:** wireframe [decision: $_DM_DN]"; _dm_commit "two Mode lines that agree"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_line_has "$_dm_out" "MODE" "wireframe ($_DM_DN)" && ! _dm_has "$_dm_out" "REGISTRY"; } || cf "(j) two Mode lines that say the same are refused (exit $_dm_rc): $(_dm_brief)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A WIREFRAME CANVAS DOES NOT JUDGE GATE 2 AND SHOWS, WITHOUT COUNTING, THE TWO CLASSES IT DEMOTES.
#   Operand: scripts/design/check-design-links.py --strict. `build` is a gate 2 value in a wireframe canvas and a GATE-CELL finding
#   in any other; a stale gate 2 approval is silent in one and STALE-APPROVAL in the other. An unmarked (UI) AC and a Design: pending
#   section that already holds a marker, both reaching only wireframe rows, are UNCOVERED-WIRE and STALE-PENDING-WIRE (exit 0, counted
#   on the summary line); a story that a default canvas's row also lists keeps UNCOVERED as a finding.
# =============================================================================
case_a_wireframe_canvas_judges_no_gate_2_and_shows_what_it_does_not_count() {
  cf_reset
  local L="check-design-links.py --strict accepts build in a wireframe canvas's gate 2 and does not judge a stale gate 2 approval there (a default canvas reads GATE-CELL and STALE-APPROVAL), prints an unmarked (UI) AC and a stale Design: pending section that reach only wireframe rows as UNCOVERED-WIRE and STALE-PENDING-WIRE with the counts on the summary line and exit 0, and keeps UNCOVERED a finding for a story a default canvas also lists"
  _dm_wire_guards "$L" || return
  _dm_wire_fixture || { finish "$L"; teardown; return; }
  local D="$SB_WORK/requirements/design/app/project" C="$SB_WORK/requirements/design/app/CANVAS.md" P="$SB_WORK/requirements/PRD-001-app.md" out X="$_DM_X"
  _dm_edit "$P" 's@- \[ \] AC3: the list is sorted\.@- [ ] AC3: (UI) the list is sorted.@'
  printf '\n### F2 — Later\n\n**Design:** pending\n\n##### F2-S1 — Later\n\n**UI:** default\n\n- [ ] AC1: (UI) already designed. [design: UX-002#default]\n' >> "$P"
  _dm_commit "an unmarked (UI) AC and a stale pending section"
  _dm_py scripts/design/check-design-links.py --strict
  out="$_dm_out"
  { [ "$_dm_rc" -eq 0 ] && _dm_line_has "$out" "UNCOVERED-WIRE" "PRD-001-F1-S1 AC3" && _dm_line_has "$out" "STALE-PENDING-WIRE" "PRD-001-app.md"; } || cf "(a) the two demoted classes are not shown and passed in a wireframe canvas (exit $_dm_rc): $(_dm_brief 320)"
  _dm_has "$out" "wireframe: 1 uncovered, 1 stale-pending, 0 content-only (not counted)" || cf "(a) the summary line does not count what the mode did not count: $(printf '%s' "$out" | tail -1)"
  _dm_line_has "$out" "UNCOVERED     " "PRD-001" && cf "(a) the demoted UNCOVERED is still a finding"
  _dm_mode ""; _dm_commit "mode off"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_line_has "$_dm_out" "UNCOVERED     " "PRD-001-F1-S1 AC3" && _dm_line_has "$_dm_out" "STALE-PENDING " "PRD-001-app.md" && ! _dm_has "$_dm_out" "-WIRE"; } || cf "(b) without the mode the same two lines are not findings (exit $_dm_rc): $(_dm_brief 320)"
  # gate 2
  _dm_mode "wireframe [decision: $_DM_DN]"
  _dm_edit "$C" "s/| approved@$_DM_W | open |/| approved@$_DM_W | build |/"
  _dm_edit "$C" "s/| PRD-001-F1-S2 | open | open |/| PRD-001-F1-S2 | open | approved@$X |/"
  _dm_commit "gate 2: build, and an approval of UX-002"
  _dm_py scripts/design/check-design-links.py --strict
  _dm_has "$_dm_out" "GATE-CELL" && cf "(c) build in a wireframe canvas's gate 2 is a GATE-CELL finding: $(_dm_brief)"
  _dm_edit "$D/B.dc.html" 's@</h1>@</h1><p id="ux-002-x">n</p>@'; _dm_commit "UX-002 gains an element after its gate 2 approval"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "UX-002 gate2"; } || cf "(c) a stale gate 2 approval is judged in a wireframe canvas (exit $_dm_rc): $(_dm_brief)"
  _dm_edit "$C" "s/| PRD-001-F1-S2 | open | approved@$X |/| PRD-001-F1-S2 | build | approved@$X |/"; _dm_commit "build in gate 1"
  _dm_py scripts/design/check-design-links.py --strict
  { _dm_line_has "$_dm_out" "GATE-CELL" "UX-002 gate1 is \`build\`" && _dm_has "$_dm_out" "gate 2 value only" && ! _dm_has "$_dm_out" "declare the mode"; } || cf "(c2) build in gate 1 of a wireframe canvas is not told it is a gate 2 value, or is told to declare a mode it has: $(_dm_brief 320)"
  _dm_edit "$C" "s/| PRD-001-F1-S2 | build | approved@$X |/| PRD-001-F1-S2 | open | approved@$X |/"; _dm_commit "gate 1 back"
  _dm_mode ""; _dm_commit "mode off again"
  _dm_py scripts/design/check-design-links.py --strict
  { _dm_line_has "$_dm_out" "GATE-CELL" "UX-001 gate2 is \`build\`" && _dm_has "$_dm_out" "Next:" && _dm_line_has "$_dm_out" "STALE-APPROVAL" "UX-002 gate2"; } || cf "(d) in a default canvas build is not a GATE-CELL finding with a Next, or a stale gate 2 is silent: $(_dm_brief 320)"
  # a default canvas that also lists the story
  _dm_mode "wireframe [decision: $_DM_DN]"
  _dm_edit "$C" "s/| approved@$_DM_W | build |/| approved@$_DM_W | open |/"
  _dm_edit "$C" "s/| PRD-001-F1-S2 | open | approved@$X |/| PRD-001-F1-S2 | open | open |/"
  _dm_commit "back to a clean wireframe canvas"
  printf '\n##### F1-S4 — Hifi\n\n**UI:** default\n\n- [ ] AC1: (UI) a screen of the other canvas.\n' >> "$P"
  _dm_art "$SB_WORK/requirements/design/hifi/project/C.dc.html" 003 '--color-primary: #485d92;' '<h1 id="ux-003-title">Hi</h1>' PRD-001-F1-S4
  _dm_art "$SB_WORK/requirements/design/hifi/project/H.dc.html" 004 '--color-primary: #485d92;' '<h1 id="ux-004-title">Hi</h1>' PRD-001-F1-S1
  _dm_registry "$SB_WORK/requirements/design/hifi" 'UX-003|C.dc.html|default|PRD-001-F1-S4|open|open'
  _dm_commit "a canvas with no Mode line, listing its own story"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_line_has "$_dm_out" "UNCOVERED     " "PRD-001-F1-S4 AC1" && _dm_line_has "$_dm_out" "UNCOVERED-WIRE" "PRD-001-F1-S1 AC3"; } || cf "(e) a story only a default canvas lists is not still a finding, or the wireframe canvas's story is not still demoted (exit $_dm_rc): $(_dm_brief 320)"
  _dm_registry "$SB_WORK/requirements/design/hifi" 'UX-003|C.dc.html|default|PRD-001-F1-S4|open|open' 'UX-004|H.dc.html|default|PRD-001-F1-S1|open|open'
  _dm_commit "the default canvas lists the story too"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_line_has "$_dm_out" "UNCOVERED     " "PRD-001-F1-S1 AC3" && ! _dm_line_has "$_dm_out" "UNCOVERED-WIRE" "PRD-001-F1-S1"; } || cf "(f) a story that a default canvas's row also lists is demoted (exit $_dm_rc): $(_dm_brief 320)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A WIREFRAME CANVAS STILL PINS A CARD, AND THE PIN REPORT IS THE DEFAULT ONE.
#   Operand: scripts/design/check-design-links.py --leaving and scripts/design/pin-drift.py over the wireframe fixture. A pin to the
#   approved row is let through, also after a content edit; after a structural edit it is STALE-APPROVAL; a row not approved is
#   NOT-APPROVED and a state with no render is NO-RENDER; a content edit to a pinned state still reads drift.
# =============================================================================
case_a_wireframe_canvas_still_pins_a_card_and_pin_drift_is_unchanged() {
  cf_reset
  local L="in a wireframe canvas check-design-links.py --leaving lets a pin to the approved row through (also after a content edit), refuses it with STALE-APPROVAL after a structural edit, refuses an unapproved row (NOT-APPROVED) and a state with no render (NO-RENDER), and pin-drift.py still reads a content edit to a pinned state as drift"
  _dm_wire_guards "$L" || return
  _dm_wire_fixture || { finish "$L"; teardown; return; }
  local D="$SB_WORK/requirements/design/app/project" V="$_DM_V" v7 c="$SB_PREFIX-894"
  v7="${V:0:7}"
  _dm_card 891 todo "design: [UX-001#default@$V]"
  _dm_card 892 todo "design: [UX-002#default@$V]"
  _dm_card 893 todo "design: [UX-001#empty@$V]"
  _dm_card 894 in_progress "design: [UX-001#default@$V]"
  _dm_commit "the cards"
  _dm_leaving 891; { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "0 finding(s)"; } || cf "(a) a pin to the approved row of a wireframe canvas is refused (exit $_dm_rc): $(_dm_brief)"
  _dm_leaving 892; { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "NOT-APPROVED"; } || cf "(b) a pin to a row not approved is let through in a wireframe canvas (exit $_dm_rc): $(_dm_brief)"
  _dm_leaving 893; { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "NO-RENDER"; } || cf "(c) a pin to a state with no render is let through in a wireframe canvas (exit $_dm_rc): $(_dm_brief)"
  _dm_edit "$D/A.dc.html" 's@>List<@>Lists, now 3.<@'; _dm_commit "a content edit after the pin"
  _dm_leaving 891; { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "0 finding(s)"; } || cf "(d) a content edit after the approval refuses the pin (exit $_dm_rc): $(_dm_brief)"
  _dm_line_has "$_dm_out" "CONTENT-ONLY" "$SB_PREFIX-891" || cf "(d) a pin to a row whose content moved since its approval reads as a clean 0 finding(s) with no CONTENT-ONLY line: $(_dm_brief)"
  _dm_py scripts/design/pin-drift.py
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-001#default@$v7")" = drift ] && _dm_has "$(_dm_row "$_dm_out" "$c" "UX-001#default@$v7")" "ux-001-title"; } || cf "(e) pin-drift.py does not read a content edit to a pinned state as drift naming the element: $(_dm_row "$_dm_out" "$c" "UX-001#default@$v7")"
  _dm_edit "$D/A.dc.html" 's@</h1>@</h1><p id="ux-001-hint">Hint</p>@'; _dm_commit "a structural edit"
  _dm_leaving 891; { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "STALE-APPROVAL"; } || cf "(f) a pin after a structural edit is let through (exit $_dm_rc): $(_dm_brief)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — SWITCHING A CANVAS'S MODE REWRITES NO APPROVAL AND RE-JUDGES ALL OF THEM BY THE RULE THEN IN FORCE.
#   Operand: scripts/design/check-design-links.py --strict over the wireframe fixture after a text edit, with the Mode line removed
#   and put back. In the mode the row is approved and listed on the CONTENT-ONLY line; without it the row is STALE-APPROVAL and a
#   gate 2 of build is GATE-CELL; the gate 1 cell reads as it did throughout.
# =============================================================================
case_switching_a_canvas_mode_rejudges_its_approvals_and_rewrites_none() {
  cf_reset
  local L="removing a canvas's Mode line makes check-design-links.py read its approvals by bytes (a content edit is STALE-APPROVAL, a gate 2 of build is GATE-CELL) and putting it back reads them by structure again (CONTENT-ONLY), with the gate cells never rewritten by either switch"
  _dm_wire_guards "$L" || return
  _dm_wire_fixture || { finish "$L"; teardown; return; }
  local D="$SB_WORK/requirements/design/app/project" C="$SB_WORK/requirements/design/app/CANVAS.md" cell
  cell="approved@$_DM_W"
  _dm_edit "$D/A.dc.html" 's@>List<@>Lists<@'
  _dm_edit "$C" "s/| $cell | open |/| $cell | build |/"
  _dm_commit "a text edit and gate 2 build"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_line_has "$_dm_out" "CONTENT-ONLY" "UX-001" && _dm_has "$_dm_out" "1 content-only"; } || cf "(a) in the mode the edited row is not approved and listed (exit $_dm_rc): $(_dm_brief)"
  _dm_mode ""; _dm_commit "the mode is removed"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_line_has "$_dm_out" "STALE-APPROVAL" "UX-001 gate1" && _dm_line_has "$_dm_out" "GATE-CELL" "UX-001 gate2 is \`build\`" && ! _dm_has "$_dm_out" "CONTENT-ONLY"; } || cf "(b) without the mode the edited row is not STALE-APPROVAL with gate 2 a GATE-CELL finding (exit $_dm_rc): $(_dm_brief 320)"
  _dm_has "$(cat "$C")" "| $cell | build |" || cf "(b) the switch rewrote the gate cells"
  _dm_mode "wireframe [decision: $_DM_DN]"; _dm_commit "the mode is put back"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_line_has "$_dm_out" "CONTENT-ONLY" "UX-001"; } || cf "(c) with the mode back the row is not approved by structure again (exit $_dm_rc): $(_dm_brief)"
  _dm_has "$(cat "$C")" "| $cell | build |" || cf "(c) the switch back rewrote the gate cells"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE DOCS NAME THE WIREFRAME MODE AND THE ATTRIBUTES THE CHECKER LEAVES OUT OF STRUCTURE, ONE LIST CITED FROM THE OTHER.
#   Operand: the module's own files. The checker's STRUCT_IGNORED is read out of the script; every name in it is in the README's
#   Wireframe mode section, and the README, the Designer role, the QA fragment and the canvas template each name the Mode line.
# =============================================================================
case_the_wireframe_docs_name_the_mode_and_the_ignore_set_the_checker_holds() {
  cf_reset
  local L="the design module's README names the Mode line and every attribute the checker's STRUCT_IGNORED leaves out of a wireframe canvas's structure, and says the mode is per canvas (a rough board beside a finished one needs a second canvas), and the Designer role, the QA fragment and the canvas template name the wireframe mode"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  local M="$REAL_REPO_ROOT/modules/design" ign a f text
  ign="$(sed -n "s/^STRUCT_IGNORED = (\(.*\))\$/\1/p" "$M/scripts/design/check-design-links.py" | tr -d "' ")"
  [ -n "$ign" ] || cf "(prereq) the checker has no STRUCT_IGNORED list this case can read"
  text="$(cat "$M/requirements/design/README.md")"
  _dm_has "$text" "### Wireframe mode" || cf "(a) the README has no Wireframe mode section"
  _dm_has "$text" '`- **Mode:** wireframe [decision: D-NN]`' || cf "(a) the README does not give the Mode line"
  _dm_has "$(printf '%s' "$text" | tr '\n' ' ' | tr -s ' ')" "The mode is per canvas: a rough board beside a finished one needs a second canvas." || cf "(e) the README does not say the mode is per canvas and that a mixed need uses a second canvas"
  local IFS=,
  for a in $ign; do
    _dm_has "$text" "\`$a\`" || cf "(b) the README does not name \`$a\`, which the checker leaves out of structure"
  done
  IFS=$' \t\n'
  _dm_has "$(cat "$M/_claude/templates/design/QA-verdict-design.fragment.md")" "at the pin commit" || cf "(d) the QA fragment does not say the mode is read at the pin commit"
  for f in _claude/roles/designer.md _claude/templates/design/QA-verdict-design.fragment.md _claude/templates/design/CANVAS.template.md; do
    _dm_has "$(cat "$M/$f")" "wireframe" || cf "(c) $f does not name the wireframe mode"
  done
  finish "$L"
}

# =============================================================================
# CASE — THE CARD GATE LETS A CARD THROUGH THAT IS PINNED TO A ROW WHOSE CONTENT MOVED (A REPORT LINE, NOT A FINDING), AND TAKES ITS LIST OF
#   REPORT CLASSES FROM THE CHECKER.
#   Operand: scripts/move-issue.sh over a wireframe canvas whose approved row had a text edit since, and check-design-links.py
#   --report-classes. The card moves; the checker names the four classes of the mode among its report classes; the hook holds no list of its own.
# =============================================================================
case_the_card_gate_passes_a_pin_to_a_content_only_row_and_reads_the_report_classes_from_the_checker() {
  cf_reset
  local L="the board mover lets a card pinned to a wireframe row whose text changed since its approval into in_progress/ (the link check prints a CONTENT-ONLY report line for the pin), and the card gate takes its report classes from check-design-links.py --report-classes, which lists MODE, CONTENT-ONLY, UNCOVERED-WIRE and STALE-PENDING-WIRE, and the gate's own text names none of the classes it lists"
  _dm_wire_guards "$L" || return
  _dm_wire_fixture || { finish "$L"; teardown; return; }
  local D="$SB_WORK/requirements/design/app/project" id
  _dm_edit "$D/A.dc.html" 's@>List<@>Lists, now 3.<@'
  _dm_land "a text edit after the approval"
  _dm_seed 841 "design: [UX-001#default@$_DM_V]"; id="$_DM_CARD"
  _dm_py scripts/design/check-design-links.py --leaving "progress/todo/$id-gate.md"
  { [ "$_dm_rc" -eq 0 ] && _dm_line_has "$_dm_out" "CONTENT-ONLY" "UX-001"; } || cf "(a0) --leaving over a card pinned to that row prints no CONTENT-ONLY line for UX-001, or counts it as a finding (exit $_dm_rc): $(_dm_brief 300)"
  _dm_gate_move "$id" PM
  [ "$_dm_rc" -eq 0 ] || cf "(a) a card pinned to a wireframe row whose text changed since its approval is refused (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/in_progress/$id-gate.md" || cf "(a) the card did not reach in_progress/ on the trunk"
  _dm_py scripts/design/check-design-links.py --report-classes
  local c
  for c in MODE CONTENT-ONLY UNCOVERED-WIRE STALE-PENDING-WIRE UNCITED DESIGN-STORY; do
    _dm_has "|$_dm_out|" "|$c|" || cf "(b) --report-classes does not list $c: $_dm_out"
  done
  for c in $(printf '%s' "$_dm_out" | tr '|' ' '); do
    _dm_has "$(cat "$REAL_REPO_ROOT/modules/design/move-check.d/50-design-pin.sh")" "$c" && cf "(c) the card gate names the report class $c, so it holds a list of its own"
  done
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE TOOLS READ WHAT A REAL PULL HOLDS: A :ROOT VALUE IS HELD TO ITS TOKEN, A NEW STATE IS NOT A CHANGE, A SHEET THE TOOLS
#   CANNOT READ IS SAID, A ROOT-RELATIVE SHEET IS READ, A STATE LOADS WHAT ITS OWN MARKUP LOADS, A SHEET'S OWN PROPERTIES ARE NOT "NO TOKEN".
#   Operand: scripts/design/check-design-links.py and scripts/design/pin-drift.py over a canvas shaped like a real export (a helmet with
#   a fonts link and a :root block, a linked token sheet, data-props, <dc-import> inside one state's branch, support.js in no project).
#   Each expected answer is written here. The shapes come from a live pull of a Claude Design canvas.
# =============================================================================
case_the_link_check_and_pin_drift_read_what_a_real_pull_holds() {
  cf_reset
  local L="a :root value that is not its token's is a finding (a theme sheet matching the other theme's token file is not), a new state with its flag in the script is clean for the pinned states, an uploaded sheet is said (the gate shows it, the pin reads uncompared), a root-relative sheet is read (its colour is a finding, its change is drift), a state loads only what its own branch loads, and a property a loaded sheet declares is no 'names no token'"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _md_sandbox
  _md_mod enable design
  [ "$_md_rc" -eq 0 ] || { cf "enable exited $_md_rc: $_md_out"; finish "$L"; teardown; return; }
  _dm_land "enable the design module"
  local D="$SB_WORK/requirements/design/app/project" P c p7 r
  _dm_tokens '{"color":{"primary":{"$value":"#22577A"},"surface":{"$value":"#FAF8F3"},"on-surface":{"$value":"#1F2421"}}}'
  mkdir -p "$D/sheets"
  printf ':root { --color-primary: #22577A; --color-surface: #FAF8F3; }\n' > "$D/sheets/tokens.css"
  cat > "$D/Timer.dc.html" <<'EOF'
<x-dc>
<div id="ux-003-root" data-ux="UX-003" data-stories="PRD-001-F1-S1" style="color: var(--color-primary)"><span id="ux-003-t">Idle</span></div>
</x-dc>
EOF
  _dm_mainfile() { cat > "$D/Main.dc.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Brews</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter&display=swap">
<link rel="stylesheet" href="sheets/tokens.css">
<style>
body{margin:0}
:root{
  --color-primary: #22577A;
  --color-surface: #FAF8F3;
}
</style>
</helmet>
<div id="ux-001-root" data-ux="UX-001" data-stories="PRD-001-F1-S1" style="background: var(--color-surface)">
<sc-if value="{{isList}}" hint-placeholder-val="{{ true }}">
<div id="ux-001-list" data-state="list">
<span id="ux-001-name" style="color: var(--color-primary)">Sencha</span>
<dc-import name="Timer" view="idle" hint-size="390px,844px"></dc-import>
</div>
</sc-if>
<sc-if value="{{isEmpty}}" hint-placeholder-val="{{ false }}">
<div id="ux-001-empty" data-state="empty"><p id="ux-001-empty-text">No brews yet</p></div>
</sc-if>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"view":{"editor":"enum","default":"list","options":["list","empty"]},"$preview":{"width":390,"height":844}}'>
class Component extends DCLogic {
renderVals() {
const v = this.props.view ?? 'list';
return { isList: v === 'list', isEmpty: v === 'empty' };
}
}
</script>
</body>
</html>
EOF
  }
  _dm_settings() {  # <1 when a paused state is added> <script variant: insert | change>
    local branch='' opts='["idle"]' ret="return { isIdle: v === 'idle' };"
    if [ "$1" = 1 ]; then
      branch='<sc-if value="{{isPaused}}"><div id="ux-002-paused" data-state="paused"><span id="ux-002-p">Paused</span></div></sc-if>'
      opts='["idle","paused"]'
      [ "$2" = insert ] && ret="return { isIdle: v === 'idle', isPaused: v === 'paused' };"
      [ "$2" = change ] && ret="return { isIdle: v !== 'idle', isPaused: v === 'paused' };"
    fi
    cat > "$D/Settings.dc.html" <<EOF
<x-dc>
<helmet><style>:root{ --color-primary: #22577A; }</style></helmet>
<div id="ux-002-root" data-ux="UX-002" data-stories="PRD-001-F1-S2">
<sc-if value="{{isIdle}}"><div id="ux-002-idle" data-state="idle"><span id="ux-002-t" style="color: var(--color-primary)">Settings</span></div></sc-if>
$branch
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"view":{"editor":"enum","default":"idle","options":$opts}}'>
class Component extends DCLogic {
renderVals() {
const v = this.props.view ?? 'idle';
$ret
}
}
</script>
EOF
  }
  _dm_back() { git -C "$SB_WORK" rm -rfq --ignore-unmatch requirements/design >/dev/null 2>&1; git -C "$SB_WORK" checkout -q "$P" -- requirements/design >/dev/null 2>&1; }
  _dm_mainfile; _dm_settings 0 insert
  printf '# PRD-001 — App\n\n## Features\n\n### F1 — Lists\n\n#### Stories\n\n##### F1-S1 — Brews\n\n**UI:** list, empty\n\n**Acceptance Criteria**\n\n- [ ] AC1: (UI) the list shows. [design: UX-001#list]\n- [ ] AC2: (UI) an empty list shows a hint. [design: UX-001#empty]\n- [ ] AC3: (UI) the timer shows. [design: UX-003]\n\n##### F1-S2 — Settings\n\n**UI:** idle\n\n- [ ] AC1: (UI) settings show. [design: UX-002#idle]\n' > "$SB_WORK/requirements/PRD-001-app.md"
  _dm_registry "$SB_WORK/requirements/design/app" 'UX-001|Main.dc.html|list, empty|PRD-001-F1-S1|open|open' 'UX-002|Settings.dc.html|idle|PRD-001-F1-S2|open|open' 'UX-003|Timer.dc.html|idle|PRD-001-F1-S1|open|open'
  _dm_commit "the pulled canvas"; P="$_DM_SHA"; p7="${P:0:7}"; c="$SB_PREFIX-861"; P0="$P"
  _dm_card 861 in_progress "design: [UX-001#list@$P, UX-001#empty@$P, UX-002#idle@$P]"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "; 0 finding(s)"; } || cf "(prereq) the pulled canvas is not clean for the gate (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_py scripts/design/pin-drift.py
  [ "$(_dm_verdict "$_dm_out" "$c" "UX-001#list@$p7")$(_dm_verdict "$_dm_out" "$c" "UX-001#empty@$p7")$(_dm_verdict "$_dm_out" "$c" "UX-002#idle@$p7")" = cleancleanclean ] || cf "(prereq) the pins are not clean straight after: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"

  # (a) D1: a :root value that is not the token's
  _dm_edit "$D/Main.dc.html" 's/--color-primary: #22577A;/--color-primary: #FF0000;/'
  _dm_commit "the screen's :root holds another value"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "TOKEN-VALUE" && _dm_has "$_dm_out" "--color-primary: #FF0000" && _dm_has "$_dm_out" "#22577A"; } || cf "(a) a :root value of --color-primary that is not the token's is not a TOKEN-VALUE finding naming both values (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_back
  # a theme block is held to the token file of its theme: [data-theme="x"] to <ns>.x.tokens.json, :root to the base file
  printf ':root { --color-primary: #22577A; --color-surface: #FAF8F3; }\n[data-theme="dark"] { --color-primary: #8FB4D4; }\n' > "$D/sheets/tokens.css"
  _dm_commit "a theme block in the token sheet, and no dark token file"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "UNCOMPARED" && _dm_has "$_dm_out" "dark" && ! _dm_has "$_dm_out" "TOKEN-VALUE"; } || cf "(a2) a theme block with no token file of its theme is not an UNCOMPARED report line naming the theme, nor left out of the findings (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_tokens '{"color":{"primary":{"$value":"#8FB4D4"}}}' app.dark.tokens.json
  _dm_commit "the dark token file"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "; 0 finding(s)" && ! _dm_has "$_dm_out" "UNCOMPARED"; } || cf "(a3) a theme block matching the dark token file is a finding or is called uncompared (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_tokens '{"color":{"primary":{"$value":"#8FB4D4"},}}' app.dark.tokens.json
  _dm_commit "the dark token file with a trailing comma"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "UNREAD" && _dm_has "$_dm_out" "tokens/app.dark.tokens.json" && _dm_has "$_dm_out" "app.dark.tokens.json could not be read" && ! _dm_has "$_dm_out" "no <ns>.dark.tokens.json holds that theme"; } || cf "(a3b) a dark token file that is not JSON is not an UNREAD line naming it, or its theme block is said to have no token file (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_tokens '{"color":{"primary":{"$value":"#8FB4D4"}}}' app.dark.tokens.json
  _dm_commit "the dark token file again"
  printf ':root { --color-primary: #22577A; --color-surface: #FAF8F3; }\n[data-theme="dark"] { --color-primary: #22577A; }\n' > "$D/sheets/tokens.css"
  _dm_commit "dark's block holds light's value"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "TOKEN-VALUE" && _dm_has "$_dm_out" "sheets/tokens.css" && _dm_has "$_dm_out" "#8FB4D4"; } || cf "(a4) [data-theme=dark] holding light's value, which is in the base file and not the dark file, is not a TOKEN-VALUE naming the dark value (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  printf ':root { --color-primary: #8FB4D4; --color-surface: #FAF8F3; }\n[data-theme="dark"] { --color-primary: #8FB4D4; }\n' > "$D/sheets/tokens.css"
  _dm_commit "the base rule of the sheet holds dark's value"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "TOKEN-VALUE" && _dm_has "$_dm_out" "#22577A"; } || cf "(a4b) :root holding dark's value, which is in the dark file and not the base file, is not a TOKEN-VALUE naming the base value (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_back
  _dm_tokens '{"color":{"primary":{"$value":"#555555"}}}' app.wire.tokens.json
  _dm_edit "$D/Main.dc.html" 's/--color-primary: #22577A;/--color-primary: #555555;/'
  _dm_commit "Main's :root holds wire's value"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "TOKEN-VALUE" && _dm_has "$_dm_out" "Main.dc.html" && _dm_has "$_dm_out" "#555555"; } || cf "(a5) a :root holding wire's value is not a TOKEN-VALUE (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_back

  # a theme that shares a rule with :root is the base (the design tool's first theme can be named anything)
  printf ':root, [data-theme="brand"] { --color-primary: #22577A; --color-surface: #FAF8F3; }\n' > "$D/sheets/tokens.css"
  _dm_commit "the first theme is brand, in a rule with :root"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "; 0 finding(s)" && ! _dm_has "$_dm_out" "UNCOMPARED"; } || cf "(a6) a theme sharing a rule with :root is called not compared although its :root half was (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  printf ':root, [data-theme="brand"] { --color-primary: #123456; --color-surface: #FAF8F3; }\n' > "$D/sheets/tokens.css"
  _dm_commit "a wrong value in that rule"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && [ "$(printf '%s\n' "$_dm_out" | grep -c '^TOKEN-VALUE')" = 1 ] && _dm_has "$_dm_out" "#22577A"; } || cf "(a6b) a wrong value in a rule shared by :root and a first theme is not one TOKEN-VALUE against the base file (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_back

  # (b) D2: a new state is not a change of the pinned states
  _dm_settings 1 insert
  _dm_registry "$SB_WORK/requirements/design/app" 'UX-001|Main.dc.html|list, empty|PRD-001-F1-S1|open|open' 'UX-002|Settings.dc.html|idle, paused|PRD-001-F1-S2|open|open' 'UX-003|Timer.dc.html|idle|PRD-001-F1-S1|open|open'
  _dm_commit "a paused state, with its flag in the script"
  _dm_py scripts/design/pin-drift.py
  r="$(_dm_row "$_dm_out" "$c" "UX-002#idle@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-002#idle@$p7")" = clean ] && _dm_has "$r" "a new state: paused"; } || cf "(b) UX-002#idle, whose screen only gained a paused state and its flag, does not read clean naming the new state: $r"
  _dm_back; _dm_settings 1 insert
  _dm_edit "$D/Settings.dc.html" 's/>Settings</>Settings two</'
  _dm_registry "$SB_WORK/requirements/design/app" 'UX-001|Main.dc.html|list, empty|PRD-001-F1-S1|open|open' 'UX-002|Settings.dc.html|idle, paused|PRD-001-F1-S2|open|open' 'UX-003|Timer.dc.html|idle|PRD-001-F1-S1|open|open'
  _dm_commit "a paused state and idle's own text changed"
  _dm_py scripts/design/pin-drift.py
  [ "$(_dm_verdict "$_dm_out" "$c" "UX-002#idle@$p7")" = drift ] || cf "(b2) UX-002#idle, whose own text changed beside a new state, does not read drift: $(_dm_row "$_dm_out" "$c" "UX-002#idle@$p7")"
  _dm_back; _dm_settings 1 change
  _dm_registry "$SB_WORK/requirements/design/app" 'UX-001|Main.dc.html|list, empty|PRD-001-F1-S1|open|open' 'UX-002|Settings.dc.html|idle, paused|PRD-001-F1-S2|open|open' 'UX-003|Timer.dc.html|idle|PRD-001-F1-S1|open|open'
  _dm_commit "a paused state and the idle logic rewritten"
  _dm_py scripts/design/pin-drift.py
  [ "$(_dm_verdict "$_dm_out" "$c" "UX-002#idle@$p7")" = drift ] || cf "(b3) UX-002#idle, whose script logic was rewritten (not only added to) beside a new state, does not read drift: $(_dm_row "$_dm_out" "$c" "UX-002#idle@$p7")"
  _dm_back

  # (c) D6: a state loads what its own markup loads
  printf '<x-dc>\n<div id="ux-003-root" data-ux="UX-003" data-stories="PRD-001-F1-S1" style="color: var(--color-primary)"><span id="ux-003-t">Idle two</span></div>\n</x-dc>\n' > "$D/Timer.dc.html"
  _dm_commit "the imported Timer changes"
  _dm_py scripts/design/pin-drift.py
  r="$(_dm_row "$_dm_out" "$c" "UX-001#list@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-001#list@$p7")" = drift ] && _dm_has "$r" "Timer.dc.html"; } || cf "(c) UX-001#list, which imports Timer in its branch, does not read drift naming Timer.dc.html when Timer changed: $r"
  [ "$(_dm_verdict "$_dm_out" "$c" "UX-001#empty@$p7")" = clean ] || cf "(c) UX-001#empty, whose branch imports nothing, does not read clean when Timer changed: $(_dm_row "$_dm_out" "$c" "UX-001#empty@$p7")"
  _dm_back

  # (d) D3 and D4: an uploaded sheet is said; a root-relative sheet is read
  _dm_edit "$D/Main.dc.html" 's#<link rel="stylesheet" href="sheets/tokens.css">#<link rel="stylesheet" href="sheets/tokens.css"><link rel="stylesheet" href="/_blob/9f2c1a">#'
  _dm_commit "an uploaded sheet"; P="$_DM_SHA"; p7="${P:0:7}"
  _dm_card 862 in_progress "design: [UX-001#empty@$P]"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "UNREAD" && _dm_has "$_dm_out" "/_blob/9f2c1a"; } || cf "(d) an uploaded sheet is not said by the gate as UNREAD, naming it, without failing it (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_py scripts/design/pin-drift.py
  r="$(_dm_row "$_dm_out" "$SB_PREFIX-862" "UX-001#empty@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$SB_PREFIX-862" "UX-001#empty@$p7")" = uncompared ] && _dm_has "$r" "/_blob/9f2c1a"; } || cf "(d) a pin of a screen loading an uploaded sheet does not read uncompared naming it: $r"
  _dm_back
  mkdir -p "$D/sheets"; printf 'h1 { margin: 0 }\n' > "$D/sheets/extra.css"
  _dm_edit "$D/Main.dc.html" 's#<link rel="stylesheet" href="sheets/tokens.css">#<link rel="stylesheet" href="sheets/tokens.css"><link rel="stylesheet" href="/sheets/extra.css">#'
  _dm_commit "a root-relative sheet"; P="$_DM_SHA"; p7="${P:0:7}"
  _dm_card 863 in_progress "design: [UX-001#empty@$P]"
  printf 'h1 { margin: 0; color: #123456 }\n' > "$D/sheets/extra.css"
  _dm_commit "the root-relative sheet gains a colour"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "LITERAL-COLOUR" && _dm_has "$_dm_out" "#123456" && _dm_has "$_dm_out" "sheets/extra.css"; } || cf "(d2) a colour in a sheet linked by a root-relative path is not a LITERAL-COLOUR finding naming it (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_has "$_dm_out" "outside :root" && cf "(d2) the colour message still says 'outside :root': $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_py scripts/design/pin-drift.py
  r="$(_dm_row "$_dm_out" "$SB_PREFIX-863" "UX-001#empty@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$SB_PREFIX-863" "UX-001#empty@$p7")" = drift ] && _dm_has "$r" "sheets/extra.css"; } || cf "(d2) a change to a sheet linked by a root-relative path does not read drift naming it: $r"
  _dm_back

  # (e) D5: a property a loaded sheet declares is covered by that sheet's bytes, not 'names no token'; the rule names the form
  mkdir -p "$D/ds"; printf ':root { --plant-accent: #123456; }\n' > "$D/ds/plant.css"
  _dm_edit "$D/Settings.dc.html" 's#<helmet><style>#<helmet><link rel="stylesheet" href="ds/plant.css"><style>#'
  _dm_edit "$D/Settings.dc.html" 's#var(--color-primary)">Settings#var(--plant-accent)">Settings#'
  _dm_commit "a prefixed sheet"; P="$_DM_SHA"; p7="${P:0:7}"
  _dm_card 864 in_progress "design: [UX-002#idle@$P]"
  _dm_py scripts/design/pin-drift.py
  r="$(_dm_row "$_dm_out" "$SB_PREFIX-864" "UX-002#idle@$p7")"
  [ "$(_dm_verdict "$_dm_out" "$SB_PREFIX-864" "UX-002#idle@$p7")" = clean ] || cf "(e) a pin whose var() is declared in the sheet it loads does not read clean: $r"
  _dm_has "$r" "names no token" && cf "(e) a var() its loaded sheet declares is called 'names no token': $r"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "#123456" && _dm_has "$_dm_out" "named for a token" && _dm_has "$_dm_out" "no prefix"; } || cf "(e) the prefixed sheet's colour is not a LITERAL-COLOUR finding stating the naming rule (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"

  # (f) D9: the colour the design page writes with a picked token, background-color: var(--color-on-surface, #1f2421), is a token
  git -C "$SB_WORK" rm -rfq --ignore-unmatch requirements/design >/dev/null 2>&1; git -C "$SB_WORK" checkout -q "$P0" -- requirements/design >/dev/null 2>&1
  _dm_edit "$D/Settings.dc.html" 's#</sc-if>#</sc-if><button id="ux-002-start" type="button" style="height: 48px; color: var(--color-on-primary); font-size: 16px; background-color: var(--color-on-surface, \#1f2421)">Get Started</button>#'
  _dm_commit "a token picked on the page"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "; 0 finding(s)"; } || cf "(f) background-color: var(--color-on-surface, #1f2421), the token's own value as the fallback, is a finding (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_edit "$D/Settings.dc.html" 's#\#1f2421)#\#1f2422)#'
  _dm_commit "the fallback is no longer the token's value"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "LITERAL-COLOUR" && _dm_has "$_dm_out" "#1f2422"; } || cf "(f2) a var() fallback that is not the token's value is not a LITERAL-COLOUR finding (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  # (g) a colour in a screen that has a registry row of its own, imported by another, is reported on its own row once
  git -C "$SB_WORK" rm -rfq --ignore-unmatch requirements/design >/dev/null 2>&1; git -C "$SB_WORK" checkout -q "$P0" -- requirements/design >/dev/null 2>&1
  _dm_edit "$D/Timer.dc.html" 's#style="color: var(--color-primary)"#style="color: var(--color-primary); background-color: \#123456"#'
  _dm_commit "a literal in the imported Timer"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && [ "$(printf '%s\n' "$_dm_out" | grep -c '^LITERAL-COLOUR')" = 1 ] && _dm_has "$_dm_out" "Timer.dc.html: #123456"; } || cf "(g) a literal in a screen with its own row, imported by another, is not reported once on its own row (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  finish "$L"
  teardown
}

# =============================================================================
# THE CARD GATE, THE DESIGN ROWS CHECK AND THE QA DESIGN-CELL CHECK, through the project's own mover, its own landing script and its own
# QA gate. The operand of each case is the placed check, read by the real script from the trunk; every expected answer is written here.
# =============================================================================

# _dm_seed <number> <design line> [<extra frontmatter line>] — a card in todo/ on the trunk, with that design: line in its frontmatter; the id is in _DM_CARD.
_dm_seed() {
  _DM_CARD="$SB_PREFIX-$1"
  seed_issue todo "$_DM_CARD" gate chore "A card for the design gate"
  awk -v d="$2" -v e="${3:-}" '{ print } /^forks: none$/ && !done { print d; if (e != "") print e; done = 1 }' "$SB_WORK/progress/todo/$_DM_CARD-gate.md" > "$SB_TMP/seed.md" && mv "$SB_TMP/seed.md" "$SB_WORK/progress/todo/$_DM_CARD-gate.md"
  _dm_land "seed $_DM_CARD"
}
# _dm_png <path> <tag> — a PNG (the signature and a 1x1 IHDR) that differs from another by its tag; the checks read the header, not the pixels.
_dm_png() { mkdir -p "$(dirname "$1")"; { printf '\211PNG\r\n\032\n\0\0\0\rIHDR\0\0\0\001\0\0\0\001\010\006\0\0\0\0\0\0\0'; printf '%s' "$2"; } > "$1"; }
# _dm_refusal <rule id> — status 0 when the last mover or gate call left a refusal record of that rule.
_dm_refusal() { cat "$SB_TMP"/records/*.tsv 2>/dev/null | grep -c "refusal=$1" | grep -v '^0$' >/dev/null; }
_dm_qrefusal() { cat "$SB_TMP/qc-rec-$_dm_qn"/*.tsv 2>/dev/null | grep -c "refusal=$1" | grep -v '^0$' >/dev/null; }
# _dm_gate_to <id> <target> — the board mover to any status folder, fresh refusal records.
_dm_gate_to() {
  rm -rf "$SB_TMP/records"; _dm_rc=0
  _dm_out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/records" ./scripts/move-issue.sh "$1" "$2" --role PM --note x 2>&1 </dev/null )" || _dm_rc=$?
}
_dm_gate_move() { _dm_gate_to "$1" in_progress; }

# =============================================================================
# CASE — THE CARD GATE REFUSES, THROUGH THE REAL MOVER, A CARD ARRIVING IN in_progress/ OR dev_complete/ THAT THE DESIGN RECORD DOES NOT BACK,
# BY EVERY ROUTE THE MOVER OFFERS, AND ALLOWS THE REST.
#   Operand: scripts/move-issue.sh in a sandbox that enabled the module and pushed the design record. Refused: nothing moves (the card
#   stays where it was on the trunk) and the output ends in a Next: line. A gate that cannot run (the tool is not on the trunk, or exits
#   without its summary line) refuses as broken. Allowed: a pinned card on an approved screen, design: none with no screen in the card, a
#   park in blocked/, and a pinned card that was in progress before, whose approval has since changed (drift never blocks).
# =============================================================================
case_the_card_gate_refuses_a_card_arriving_in_progress_or_dev_complete_that_the_design_record_does_not_back() {
  cf_reset
  local L="the board mover refuses a card arriving in in_progress/ or dev_complete/ from todo/ or blocked/ whose design: entry is unpinned, pinned to a commit that does not exist or to a screen whose gate1 is not approved, or whose design: is none or lacks a screen its AC cites, with the check's reason and a Next: line and the card left where it was, allows a pinned card on an approved screen, design: none with no screen in the card, todo/ to blocked/, and a card back from blocked/ that was in progress before (its approval since changed), and a gate whose tool is missing, exits 0 or exits 1 without its summary line is refused as broken"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_links_fixture || { finish "$L"; teardown; return; }
  _dm_land "the design record"
  local X="$_DM_X" id f
  _dm_seed 831 "design: [UX-001#default]"; id="$_DM_CARD"
  _dm_gate_move "$id" PM
  { [ "$_dm_rc" -ne 0 ] && _dm_has "$_dm_out" "UNPINNED"; } || cf "(a) a card leaving todo/ with an unpinned design: entry is not refused with the reason (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$_dm_out" | grep '^Next:' >/dev/null || cf "(a) the refusal has no Next: line"
  { [ -f "$SB_WORK/progress/todo/$id-gate.md" ] && ! origin_has_path "progress/in_progress/$id-gate.md"; } || cf "(a) the refused card moved"
  _dm_refusal move-check-refused || cf "(a) no refusal=move-check-refused record"
  _dm_seed 832 "design: [UX-001#default@$X]"; id="$_DM_CARD"
  _dm_gate_move "$id" PM
  [ "$_dm_rc" -eq 0 ] || cf "(b) a card pinned to an approved screen's commit is refused (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  origin_has_path "progress/in_progress/$id-gate.md" || cf "(b) the allowed card did not reach in_progress/ on the trunk"
  _dm_seed 833 "design: none"; id="$_DM_CARD"
  _dm_gate_move "$id" PM
  [ "$_dm_rc" -eq 0 ] || cf "(c) a card with design: none and no screen in it is refused (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  _dm_seed 834 "design: [UX-002#default@$X]"; id="$_DM_CARD"
  _dm_gate_move "$id" PM
  { [ "$_dm_rc" -ne 0 ] && _dm_has "$_dm_out" "NOT-APPROVED"; } || cf "(d) a pin to a screen whose gate1 is open is not refused with NOT-APPROVED (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  _dm_seed 835 "design: [UX-001#default@deadbee]"; id="$_DM_CARD"
  _dm_gate_move "$id" PM
  { [ "$_dm_rc" -ne 0 ] && _dm_has "$_dm_out" "is not a commit"; } || cf "(e) a pin to a commit that does not exist is not refused (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  # (f) the routes round it: parked in blocked/ (free), then back to in_progress/ or to dev_complete/ (judged), or todo/ straight to dev_complete/
  _dm_seed 836 "design: [UX-001#default]"; id="$_DM_CARD"
  _dm_gate_to "$id" blocked
  { [ "$_dm_rc" -eq 0 ] && origin_has_path "progress/blocked/$id-gate.md"; } || cf "(f) parking an unpinned card in blocked/ is refused (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  _dm_gate_to "$id" in_progress
  { [ "$_dm_rc" -ne 0 ] && _dm_has "$_dm_out" "UNPINNED" && origin_has_path "progress/blocked/$id-gate.md"; } || cf "(f1) blocked/ to in_progress/ with an unpinned entry is not refused, leaving the card in blocked/ (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  _dm_gate_to "$id" dev_complete
  { [ "$_dm_rc" -ne 0 ] && _dm_has "$_dm_out" "UNPINNED"; } || cf "(f2) blocked/ to dev_complete/ with an unpinned entry is not refused (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  _dm_seed 837 "design: [UX-001#default]"; id="$_DM_CARD"
  _dm_gate_to "$id" dev_complete
  { [ "$_dm_rc" -ne 0 ] && _dm_has "$_dm_out" "UNPINNED" && origin_has_path "progress/todo/$id-gate.md"; } || cf "(f3) todo/ straight to dev_complete/ with an unpinned entry is not refused (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  # (g) a card that was in progress, parked, whose screen's approval has since gone: it comes back (drift never blocks); its entries are still pinned
  id="$SB_PREFIX-832"
  _dm_gate_to "$id" blocked
  [ "$_dm_rc" -eq 0 ] || cf "(g) parking a card that is in progress is refused (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  cp "$SB_WORK/requirements/design/app/CANVAS.md" "$SB_TMP/canvas.bak"
  _dm_edit "$SB_WORK/requirements/design/app/CANVAS.md" 's/approved@[0-9a-f]*/changes/'
  _dm_land "the approval is withdrawn"
  _dm_gate_to "$id" in_progress
  { [ "$_dm_rc" -eq 0 ] && origin_has_path "progress/in_progress/$id-gate.md"; } || cf "(g) a pinned card that was in progress is judged again on its way back from blocked/ (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  _dm_gate_to "$id" dev_complete
  [ "$_dm_rc" -eq 0 ] || cf "(g2) a card in progress is judged on its way to dev_complete/ (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  cp "$SB_TMP/canvas.bak" "$SB_WORK/requirements/design/app/CANVAS.md"; _dm_land "the approval is back"
  # (h) design: none on a card whose AC is tagged (UI), or whose story has a UI: line, is the minted default left in place
  _dm_seed 838 "design: none"; id="$_DM_CARD"
  perl -0pi -e 's/(## Acceptance Criteria\n\n)/$1- [ ] AC2 — (UI) from PRD-001-F1-S1: the list shows. [design: UX-001#default]\n/' "$SB_WORK/progress/todo/$id-gate.md"
  _dm_land "an AC that cites a screen"
  _dm_gate_move "$id" PM
  { [ "$_dm_rc" -ne 0 ] && _dm_has "$_dm_out" "DESIGN-NONE" && _dm_has "$_dm_out" "AC2" && _dm_has "$_dm_out" "marker off the AC"; } || cf "(h) design: none on a card whose AC is tagged (UI) is not refused as DESIGN-NONE naming the AC (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$_dm_out" | grep '^Next:' | grep 'tag' >/dev/null || cf "(h) the Next: line of a DESIGN-NONE refusal does not offer taking the tag off an AC of a card that builds no screen: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  _dm_seed 839 "design: none" "stories: [PRD-001-F1-S1]"; id="$_DM_CARD"
  _dm_py scripts/design/check-design-links.py --leaving "progress/todo/$id-gate.md"
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "DESIGN-STORY" && _dm_has "$_dm_out" "PRD-001-F1-S1" && _dm_has "$_dm_out" "; 0 finding(s)"; } || cf "(h2) design: none on a card that builds no screen, whose story has a UI: line, is not a report line with no finding (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  _dm_gate_move "$id" PM
  { [ "$_dm_rc" -eq 0 ] && origin_has_path "progress/in_progress/$id-gate.md"; } || cf "(h2) design: none on a card that builds no screen, whose story has a UI: line, is refused at the card gate (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  _dm_seed 841 "design: [UX-001#default@$X]"; id="$_DM_CARD"
  perl -0pi -e 's/(## Acceptance Criteria\n\n)/$1- [ ] AC2 — (UI) from PRD-001-F1-S1: the empty list shows. [design: UX-001#empty]\n/' "$SB_WORK/progress/todo/$id-gate.md"
  _dm_land "an AC that cites a state the key lacks"
  _dm_gate_move "$id" PM
  { [ "$_dm_rc" -ne 0 ] && _dm_has "$_dm_out" "DESIGN-MISSING" && _dm_has "$_dm_out" "UX-001#empty"; } || cf "(h3) an AC that cites a state the design: key lacks is not refused as DESIGN-MISSING (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  # (k) a pin whose commit holds no render for its state: the card could not land, so it does not leave todo/ (the PNG comes first)
  _dm_seed 844 "design: [UX-001#empty@$X]"; id="$_DM_CARD"
  _dm_gate_move "$id" PM
  { [ "$_dm_rc" -ne 0 ] && _dm_has "$_dm_out" "NO-RENDER" && _dm_has "$_dm_out" "A-empty.png" && _dm_has "$_dm_out" "re-pin" && origin_has_path "progress/todo/$id-gate.md"; } || cf "(k) a pin whose commit holds no render for its state leaves todo/ (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  _dm_png "$SB_WORK/requirements/design/app/renders/A-empty.png" EMPTY
  _dm_land "the PNG of the empty state"
  _dm_seed 845 "design: [UX-001#empty@$(git -C "$SB_WORK" rev-parse HEAD)]"; id="$_DM_CARD"
  _dm_gate_move "$id" PM
  [ "$_dm_rc" -eq 0 ] || cf "(k2) a pin on the commit that holds the render is refused (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  # (i) a tool that cannot answer: missing, silent with status 0, or failing with status 1 and no summary line: refused as broken, never as a record fault
  cp "$SB_WORK/scripts/design/check-design-links.py" "$SB_TMP/real-links.py"
  printf 'import sys\nsys.exit(0)\n' > "$SB_WORK/scripts/design/check-design-links.py"
  _dm_land "a tool that says nothing"
  _dm_seed 842 "design: [UX-001#default]"; id="$_DM_CARD"
  _dm_gate_move "$id" PM
  { [ "$_dm_rc" -ne 0 ] && _dm_has "$_dm_out" "could not run" && origin_has_path "progress/todo/$id-gate.md"; } || cf "(i) a tool that exits 0 and prints nothing lets an unpinned card move or refuses as a fault of the record (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  _dm_refusal move-check-broken || cf "(i) no refusal=move-check-broken record for a silent tool"
  printf 'import sys\nraise SystemExit(1)\n' > "$SB_WORK/scripts/design/check-design-links.py"
  _dm_land "a tool that fails"
  _dm_gate_move "$id" PM
  { [ "$_dm_rc" -ne 0 ] && _dm_has "$_dm_out" "could not run"; } || cf "(i2) a tool that exits 1 with no summary line is read as a refusal of the record (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  _dm_refusal move-check-broken || cf "(i2) no refusal=move-check-broken record for a failing tool"
  git -C "$SB_WORK" rm -q -f scripts/design/check-design-links.py
  _dm_land "the tool leaves"
  _dm_seed 843 "design: none"; id="$_DM_CARD"
  _dm_gate_move "$id" PM
  { [ "$_dm_rc" -ne 0 ] && _dm_has "$_dm_out" "could not run" && printf '%s\n' "$_dm_out" | grep '^Next:' >/dev/null; } || cf "(j) a gate whose tool is missing lets the move through or refuses without a reason and a Next: (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  finish "$L"
  teardown
}

# _dm_qa_gate <card file> <rev> <trunk rev> — kit_qa_verdict_check on that card, status in _dm_rc and output in _dm_out.
_dm_qn=0
_dm_qa_gate() {
  _dm_qn=$((_dm_qn + 1)); _dm_rc=0
  _dm_out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/qc-rec-$_dm_qn" bash -c '. scripts/lib/refuse.sh; . scripts/config.sh; . scripts/lib/qa-gate.sh; kit_qa_verdict_check "$@"' _ "$1" "$_DM_QID" "$SB_WORK" "$2" "$3" 2>&1 )" || _dm_rc=$?
}

# =============================================================================
# CASE — THE QA GATE REFUSES A PASS ROW OF KIND design WHOSE CELL THE TRUNK DOES NOT BACK, AND PASSES ONE IT DOES.
#   Operand: scripts/lib/qa-gate.sh's kit_qa_verdict_check, with the card and the evidence images on the TRUNK (where QA commits them) and
#   the branch holding neither. A cell that is not `identical`, names no image, cites a pin the card lacks, whose pin image is not the
#   render the pin commit holds for that screen, whose image is empty, not a PNG, or the same bytes as the pin image, or whose image only
#   a branch holds: refused, with a Next: line. A gate that cannot run: refused as broken.
# =============================================================================
case_the_qa_gate_refuses_a_design_row_the_trunk_does_not_back_and_passes_one_it_does() {
  cf_reset
  local L="the QA gate passes a PASS row of kind design whose cell says identical for a pin the card carries, with both PNGs committed on the trunk and the pin image the render the pin commit holds for that screen, and refuses (qa-verdict-cell-refused, a Next: line, NOTHING WAS CHANGED) a cell that names differences, omits an image, cites a pin the card lacks, whose pin image is another screen's or another render, whose build image is empty, text or the pin image, or whose images only a branch holds, and refuses as broken when the tool is off the trunk"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_links_fixture || { finish "$L"; teardown; return; }
  _DM_QID="$SB_PREFIX-840"
  local X="$_DM_X" P card="$SB_TMP/card840.md" ev="dev/evidence/$_DM_QID" good
  _dm_png "$SB_WORK/requirements/design/app/renders/A-default.png" LIST
  _dm_png "$SB_WORK/requirements/design/app/renders/B-default.png" EDIT
  _dm_commit "renders at the pin"; P="$_DM_SHA"
  seed_issue dev_complete "$_DM_QID" cell chore "A card with a design row"
  perl -0pi -e 's/(forks: none\n)/$1design: [UX-001#default\@'"$P"']\n/; s/(- \[ \] AC1 — [^\n]*\n)/$1- [ ] AC2 — (UI) from PRD-001-F1-S1: the list shows. [design: UX-001#default]\n/; s/(\| shadow-check )/| AC2 | PASS | design | x |\n$1/' "$SB_WORK/progress/dev_complete/$_DM_QID-cell.md"
  _dm_png "$SB_WORK/$ev/UX-001-default-pin.png" LIST
  _dm_png "$SB_WORK/$ev/UX-001-default-build.png" BUILD
  _dm_land "the card and its evidence, on the trunk"
  good="UX-001#default@$P: identical; $ev/UX-001-default-pin.png, $ev/UX-001-default-build.png"
  _dm_row_card() {  # <cell> — the trunk's card with the AC2 row's cell replaced
    git -C "$SB_WORK" show "origin/$SB_TRUNK:progress/dev_complete/$_DM_QID-cell.md" > "$card"
    CELL="$1" perl -0pi -e 's/^\| AC2 \| PASS \|[^\n]*$/| AC2 | PASS | design | $ENV{CELL} |/m' "$card"
  }
  _dm_row_card "$good"
  _dm_qa_gate "$card" "$SB_TRUNK" "$SB_TRUNK"
  [ "$_dm_rc" -eq 0 ] || cf "(a) a design row the trunk backs is refused (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  refused() {  # <label> <cell> <text the refusal must hold>
    _dm_row_card "$2"
    _dm_qa_gate "$card" "$SB_TRUNK" "$SB_TRUNK"
    { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "$3"; } || cf "($1) the row was not refused for '$3' (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
    _dm_qrefusal qa-verdict-cell-refused || cf "($1) no refusal=qa-verdict-cell-refused record"
    printf '%s\n' "$_dm_out" | grep '^Next:' >/dev/null || cf "($1) the refusal has no Next: line"
    _dm_has "$_dm_out" "NOTHING WAS CHANGED" || cf "($1) the refusal does not say nothing was changed"
  }
  refused b "UX-001#default@$P: diffs: ux-001-title; $ev/UX-001-default-pin.png, $ev/UX-001-default-build.png" "names differences"
  refused c "UX-001#default@$P: identical; $ev/UX-001-default-pin.png" "UX-001-default-build.png"
  refused d "UX-001#default@$X: identical; $ev/UX-001-default-pin.png, $ev/UX-001-default-build.png" "carries no such entry"
  refused f "UX-001#default@$P: identical; $ev/UX-001-default-pin.png, $ev/UX-001-default-missing.png" "UX-001-default-build.png"
  refused g "no entry here" "holds no"
  # the images: another screen's render as the pin image, the same bytes as the pin image, an empty file, a text file
  _dm_png "$SB_WORK/$ev/UX-001-default-pin.png" EDIT
  _dm_land "the pin image is another screen's render"
  refused e "$good" "is not the render"
  _dm_png "$SB_WORK/$ev/UX-001-default-pin.png" LIST
  _dm_png "$SB_WORK/$ev/UX-001-default-build.png" LIST
  _dm_land "the build image is the pin image"
  refused h "$good" "the build image is the pin image"
  : > "$SB_WORK/$ev/UX-001-default-build.png"
  _dm_land "an empty build image"
  refused i "$good" "is not a PNG"
  printf 'not an image\n' > "$SB_WORK/$ev/UX-001-default-build.png"
  _dm_land "a text build image"
  refused j "$good" "is not a PNG"
  _dm_png "$SB_WORK/$ev/UX-001-default-build.png" BUILD
  _dm_land "the build image is back"
  # the images on a branch only: the trunk does not hold them, so the row is refused although the branch tip does
  git -C "$SB_WORK" checkout -q -b dev-840-only "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" rm -q -f "$ev/UX-001-default-build.png" >/dev/null 2>&1
  sbcommit -qm "[PM] $_MD_ID: the trunk loses the build image" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin dev-840-only:"$SB_TRUNK" >/dev/null 2>&1
  _dm_png "$SB_WORK/$ev/UX-001-default-build.png" BUILD
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[Dev] $_DM_QID: the image on the branch" >/dev/null 2>&1
  _dm_row_card "$good"
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  _dm_qa_gate "$card" dev-840-only "origin/$SB_TRUNK"
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "is not committed on the trunk"; } || cf "(k) an image only the branch holds passes (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1
  # (l) the tool is not on the trunk: the check cannot answer, and a check that cannot answer is a refusal
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1; git -C "$SB_WORK" reset -q --hard "origin/$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" rm -q -f scripts/design/check-design-cell.py
  _dm_land "the cell tool leaves"
  _dm_row_card "$good"
  _dm_qa_gate "$card" "$SB_TRUNK" "$SB_TRUNK"
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "could not run"; } || cf "(l) a cell check whose tool is missing passes or refuses without saying it could not run (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_qrefusal qa-verdict-cell-check-broken || cf "(l) no refusal=qa-verdict-cell-check-broken record"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A CARD WITH A (UI) AC LANDS ONLY WITH A DESIGN ROW FOR IT, THROUGH THE REAL finish-pr.sh AND subtask.sh, ON A PROJECT THAT FILLED
#   CODE_GLOBS, AS QA WORKS: THE EVIDENCE AND THE VERDICT COMMITTED ON THE TRUNK WITH register-commit.sh, NOT ON THE BRANCH.
#   Operand: finish-pr.sh on a card with AC2 tagged (UI), then subtask.sh move on a slice with the same shape. Refused: a verdict with no
#   design row for AC2; a row whose images are not committed on the trunk; a row of another evidence kind. Landed: the row backed by both
#   PNGs on the trunk. The module's own cell check reads the card and the images at the trunk, so a QA following its role can pass.
# =============================================================================
case_a_card_with_a_ui_ac_lands_only_with_its_design_row_through_finish_pr_and_subtask() {
  cf_reset
  if ! has_issue_template; then skp "a card or slice with a (UI) AC lands only with its design row" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  local L="finish-pr.sh and subtask.sh move land a card and a slice with a (UI) AC and a test or file:line row once their design row is backed, refuse a card or a slice whose every AC is (UI) with qa-verdict-no-observed unless its one design row ends with a quoted path:line the gate resolves (a design row alone is not core evidence), refuse a quoted path:line that does not resolve, and refuse a card or a slice whose (UI) AC has no design row, or a slice pinned to a screen with no design row at all, or a row whose images the trunk does not hold, on a project with CODE_GLOBS filled, and land the card and the slice once QA committed the images and the verdict to the trunk with register-commit.sh"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_links_fixture || { finish "$L"; teardown; return; }
  _array_set_body "$SB_WORK/scripts/config.sh" CODE_GLOBS '  "app/*"'
  _dm_land "CODE_GLOBS is filled"
  local id="$SB_PREFIX-850" P ev out rc card good
  ev="dev/evidence/$id"
  _dm_png "$SB_WORK/requirements/design/app/renders/A-default.png" LIST
  _dm_commit "a render at the pin"; P="$_DM_SHA"
  seed_issue dev_complete "$id" walk chore "A card with a screen" "feature/$id-work"
  card="$SB_WORK/progress/dev_complete/$id-walk.md"
  perl -0pi -e 's/(forks: none\n)/$1design: [UX-001#default\@'"$P"']\n/; s/(- \[ \] AC1 — [^\n]*\n)/$1- [ ] AC2 — (UI) from PRD-001-F1-S1: the list shows. [design: UX-001#default]\n/' "$card"
  _dm_land "the design record and the card"
  git -C "$SB_WORK" checkout -q -b "feature/$id-work" "$SB_TRUNK" >/dev/null 2>&1
  mkdir -p "$SB_WORK/app"; echo "the screen's code" > "$SB_WORK/app/list.txt"
  git -C "$SB_WORK" add app/list.txt >/dev/null 2>&1; sbcommit -qm "[Dev] $id: the list screen" >/dev/null 2>&1
  git -C "$SB_WORK" push -q -u origin "feature/$id-work" >/dev/null 2>&1
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1
  good="UX-001#default@$P: identical; $ev/UX-001-default-pin.png, $ev/UX-001-default-build.png"
  _dm_qa_register() {  # <AC2 row> [<paths to commit besides the card>…] — QA's verdict (and evidence) on the trunk, by register-commit.sh
    local row="$1"; shift
    ROW="$row" perl -0pi -e 's/^\| AC2 \|[^\n]*\n//m; s/(\| shadow-check )/$ENV{ROW}\n$1/' "$card"
    ( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/reg" ./scripts/register-commit.sh --role QA --message "$id: the verdict" "progress/dev_complete/$id-walk.md" "$@" >/dev/null 2>&1 </dev/null )
  }
  _dm_land_it() { out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec" ./scripts/finish-pr.sh "$id" 2>&1 </dev/null )"; rc=$?; }
  # (a) QA wrote AC2's row as an ordinary file:line row: no design row for a (UI) AC
  _dm_qa_register '| AC2 | PASS | file:line | ARCHIVE.md:1 "condensed index of completed issues" |'
  _dm_land_it
  { [ "$rc" -ne 0 ] && _dm_has "$out" "AC2" && _dm_has "$out" "design" && ! origin_has_path "app/list.txt"; } || cf "(a) a (UI) AC with a file:line row lands (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/dev_complete/$id-walk.md" || cf "(a) the refused card left dev_complete/"
  # (b) a design row whose images exist nowhere on the trunk
  _dm_qa_register "| AC2 | PASS | design | $good |"
  _dm_land_it
  { [ "$rc" -ne 0 ] && _dm_has "$out" "is not committed on the trunk" && ! origin_has_path "app/list.txt"; } || cf "(b) a design row with no image on the trunk lands (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  # (c) the images committed on the trunk by QA (register-commit.sh); the build image the same bytes as the pin image
  _dm_png "$SB_WORK/$ev/UX-001-default-pin.png" LIST
  _dm_png "$SB_WORK/$ev/UX-001-default-build.png" LIST
  _dm_qa_register "| AC2 | PASS | design | $good |" "$ev/UX-001-default-pin.png" "$ev/UX-001-default-build.png"
  _dm_land_it
  { [ "$rc" -ne 0 ] && _dm_has "$out" "the build image is the pin image"; } || cf "(c) a build image that is the pin image lands (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  # (d) a real build image: the landing succeeds
  _dm_png "$SB_WORK/$ev/UX-001-default-build.png" BUILD
  _dm_qa_register "| AC2 | PASS | design | $good |" "$ev/UX-001-default-build.png"
  _dm_land_it
  { [ "$rc" -eq 0 ] && origin_has_path "app/list.txt" && origin_has_path "progress/qa_complete/$id-walk.md"; } || cf "(d) a design row backed by both PNGs on the trunk does not land through finish-pr.sh (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"
  # (e) a slice of a parent: the same shape, through subtask.sh
  local sid="$SB_PREFIX-851-s1" sf sev
  sev="dev/evidence/$sid"
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1; git -C "$SB_WORK" reset -q --hard "origin/$SB_TRUNK" >/dev/null 2>&1   # finish-pr.sh advanced the trunk
  _seed_parent "$SB_PREFIX-851" in_progress
  sf="$(_seed_subtask "$SB_PREFIX-851" s1 dev_complete walk "A slice with a screen")"
  perl -0pi -e 's/(forks: none\n)/$1design: [UX-001#default\@'"$P"']\n/; s/(- \[ \] AC1 — [^\n]*\n)/$1- [ ] AC2 — (UI) from PRD-001-F1-S1: the list shows. [design: UX-001#default]\n/; s/(\| shadow-check )/| AC2 | PASS | file:line | ARCHIVE.md:1 "condensed index of completed issues" |\n$1/' "$sf"
  _dm_land "a slice with a screen"
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-s" ./scripts/subtask.sh move "$sid" qa_complete 2>&1 </dev/null )"; rc=$?
  { [ "$rc" -ne 0 ] && _dm_has "$out" "AC2" && origin_has_path "progress/subtasks/$SB_PREFIX-851/dev_complete/$sid-walk.md"; } || cf "(e) a slice whose (UI) AC has a file:line row moves to qa_complete/ (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  _dm_png "$SB_WORK/$sev/UX-001-default-pin.png" LIST
  _dm_png "$SB_WORK/$sev/UX-001-default-build.png" BUILD
  ROW="| AC2 | PASS | design | UX-001#default@$P: identical; $sev/UX-001-default-pin.png, $sev/UX-001-default-build.png |" perl -0pi -e 's/^\| AC2 \|[^\n]*$/$ENV{ROW}/m' "$sf"
  _dm_land "the slice's design row and images"
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-s2" ./scripts/subtask.sh move "$sid" qa_complete 2>&1 </dev/null )"; rc=$?
  { [ "$rc" -eq 0 ] && origin_has_path "progress/subtasks/$SB_PREFIX-851/qa_complete/$sid-walk.md"; } || cf "(f) a slice with a design row backed on the trunk does not move to qa_complete/ (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | tail -c 700) [local: $(grep -c 'design |' "$sf")] [trunk: $(git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1; git -C "$SB_WORK" show "origin/$SB_TRUNK:progress/subtasks/$SB_PREFIX-851/dev_complete/$sid-walk.md" 2>&1 | grep 'AC2 |' | cut -c1-120)]"
  # (g) a slice pinned to a screen whose ACs carry no (UI) tag and no marker: the pin alone asks for a design row
  local gid="$SB_PREFIX-852-s1" gf gev
  gev="dev/evidence/$gid"
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1; git -C "$SB_WORK" reset -q --hard "origin/$SB_TRUNK" >/dev/null 2>&1
  _seed_parent "$SB_PREFIX-852" in_progress
  gf="$(_seed_subtask "$SB_PREFIX-852" s1 dev_complete pinned "A slice pinned to a screen")"
  perl -0pi -e 's/(forks: none\n)/$1design: [UX-001#default\@'"$P"']\n/; s/(- \[ \] AC1 — [^\n]*\n)/$1- [ ] AC2 — the list shows the brews.\n/; s/(\| shadow-check )/| AC2 | PASS | file:line | ARCHIVE.md:1 "condensed index of completed issues" |\n$1/' "$gf"
  _dm_land "a slice pinned to a screen, untagged ACs"
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-g" ./scripts/subtask.sh move "$gid" qa_complete 2>&1 </dev/null )"; rc=$?
  { [ "$rc" -ne 0 ] && _dm_has "$out" "pins UX-001#default" && origin_has_path "progress/subtasks/$SB_PREFIX-852/dev_complete/$gid-pinned.md"; } || cf "(g) a slice pinned to a screen, with no design row and ACs that carry no tag, moves to qa_complete/ (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | tail -c 500)"
  _dm_png "$SB_WORK/$gev/UX-001-default-pin.png" LIST
  _dm_png "$SB_WORK/$gev/UX-001-default-build.png" BUILD
  ROW="| AC2 | PASS | design | UX-001#default@$P: identical; $gev/UX-001-default-pin.png, $gev/UX-001-default-build.png |" perl -0pi -e 's/^\| AC2 \|[^\n]*$/$ENV{ROW}/m' "$gf"
  _dm_land "the slice's design row and images"
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-g2" ./scripts/subtask.sh move "$gid" qa_complete 2>&1 </dev/null )"; rc=$?
  { [ "$rc" -eq 0 ] && origin_has_path "progress/subtasks/$SB_PREFIX-852/qa_complete/$gid-pinned.md"; } || cf "(h) a pinned slice with its design row and images does not move to qa_complete/ (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | tail -c 600)"
  # (l) the table the fragment's old wording led to: one entry per cell, the second state's images nowhere on the trunk
  local lid="$SB_PREFIX-855-s1" lf lev
  lev="dev/evidence/$lid"
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1; git -C "$SB_WORK" reset -q --hard "origin/$SB_TRUNK" >/dev/null 2>&1
  _seed_parent "$SB_PREFIX-855" in_progress
  lf="$(_seed_subtask "$SB_PREFIX-855" s1 dev_complete twocell "A slice of two states")"
  ROW="| AC1 | PASS | design | UX-001#default@$P: identical; $lev/UX-001-default-pin.png, $lev/UX-001-default-build.png; ARCHIVE.md:1 \"condensed index of completed issues\" | UX-001#empty@$P: identical; $lev/UX-001-empty-pin.png, $lev/UX-001-empty-build.png |" perl -0pi -e 's/(forks: none\n)/$1design: [UX-001#default\@'"$P"', UX-001#empty\@'"$P"']\n/; s/- \[ \] AC1 — [^\n]*\n/- [ ] AC1 — (UI) from PRD-001-F1-S1: both states show. [design: UX-001#default, UX-001#empty]\n/; s/^\| AC1 \|[^\n]*$/$ENV{ROW}/m' "$lf"
  _dm_png "$SB_WORK/$lev/UX-001-default-pin.png" LIST
  _dm_png "$SB_WORK/$lev/UX-001-default-build.png" BUILD
  _dm_land "a slice of two states, the second in a second cell"
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-l" ./scripts/subtask.sh move "$lid" qa_complete 2>&1 </dev/null )"; rc=$?
  { [ "$rc" -ne 0 ] && _dm_has "$out" "UX-001#empty" && origin_has_path "progress/subtasks/$SB_PREFIX-855/dev_complete/$lid-twocell.md"; } || cf "(l) a design row with a second pointer cell lets a state with no image land (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | tail -c 500)"
  # (i) a card whose only AC is (UI), its only row a design row with no pointer: a design row is not core evidence, so the landing wants a test or file:line row, or a quoted path:line on the row ((k))
  local aid="$SB_PREFIX-853" aev of
  aev="dev/evidence/$aid"
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1; git -C "$SB_WORK" reset -q --hard "origin/$SB_TRUNK" >/dev/null 2>&1
  seed_issue dev_complete "$aid" allui chore "A card of one UI AC" "feature/$aid-work"
  ROW="| AC1 | PASS | design | UX-001#default@$P: identical; $aev/UX-001-default-pin.png, $aev/UX-001-default-build.png |" perl -0pi -e 's/(forks: none\n)/$1design: [UX-001#default\@'"$P"']\n/; s/- \[ \] AC1 — [^\n]*\n/- [ ] AC1 — (UI) from PRD-001-F1-S1: the list shows. [design: UX-001#default]\n/; s/^\| AC1 \|[^\n]*$/$ENV{ROW}/m' "$SB_WORK/progress/dev_complete/$aid-allui.md"
  _dm_land "a card of one UI AC"
  git -C "$SB_WORK" checkout -q -b "feature/$aid-work" "$SB_TRUNK" >/dev/null 2>&1
  echo "the second screen's code" > "$SB_WORK/app/list2.txt"
  git -C "$SB_WORK" add app/list2.txt >/dev/null 2>&1; sbcommit -qm "[Dev] $aid: the screen" >/dev/null 2>&1
  git -C "$SB_WORK" push -q -u origin "feature/$aid-work" >/dev/null 2>&1
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1
  _dm_png "$SB_WORK/$aev/UX-001-default-pin.png" LIST
  _dm_png "$SB_WORK/$aev/UX-001-default-build.png" BUILD
  ( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/reg-i" ./scripts/register-commit.sh --role QA --message "$aid: the evidence" "$aev/UX-001-default-pin.png" "$aev/UX-001-default-build.png" >/dev/null 2>&1 </dev/null )
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-i" ./scripts/finish-pr.sh "$aid" 2>&1 </dev/null )"; rc=$?
  { [ "$rc" -ne 0 ] && _dm_has "$out" "no test/file:line row" && _dm_has "$out" "does not stand in for one" && ! origin_has_path "progress/qa_complete/$aid-allui.md"; } || cf "(i) a card whose every AC is (UI), its design row passed, is not refused for the missing test or file:line row (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | tail -c 500)"
  grep -F 'refusal=qa-verdict-no-observed' "$SB_TMP"/rec-i/*.tsv >/dev/null 2>&1 || cf "(i) no refusal=qa-verdict-no-observed record"
  # (j) a slice with the one AC, (UI), its one row a design row with no pointer, through subtask.sh
  local oid="$SB_PREFIX-854-s1" of oev
  oev="dev/evidence/$oid"
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1; git -C "$SB_WORK" reset -q --hard "origin/$SB_TRUNK" >/dev/null 2>&1
  _seed_parent "$SB_PREFIX-854" in_progress
  of="$(_seed_subtask "$SB_PREFIX-854" s1 dev_complete oneac "A slice of one UI AC")"
  ROW="| AC1 | PASS | design | UX-001#default@$P: identical; $oev/UX-001-default-pin.png, $oev/UX-001-default-build.png |" perl -0pi -e 's/(forks: none\n)/$1design: [UX-001#default\@'"$P"']\n/; s/- \[ \] AC1 — [^\n]*\n/- [ ] AC1 — (UI) from PRD-001-F1-S1: the list shows. [design: UX-001#default]\n/; s/^\| AC1 \|[^\n]*$/$ENV{ROW}/m' "$of"
  _dm_png "$SB_WORK/$oev/UX-001-default-pin.png" LIST
  _dm_png "$SB_WORK/$oev/UX-001-default-build.png" BUILD
  _dm_land "a slice of one UI AC, its row and images"
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-j" ./scripts/subtask.sh move "$oid" qa_complete 2>&1 </dev/null )"; rc=$?
  { [ "$rc" -ne 0 ] && _dm_has "$out" "no test/file:line row" && ! origin_has_path "progress/subtasks/$SB_PREFIX-854/qa_complete/$oid-oneac.md"; } || cf "(j) a slice of one (UI) AC with only its design row is not refused for the missing test or file:line row (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | tail -c 600)"
  # (k) the same slice, its one design row ending with a path:line the gate resolves and a quote found on that line: the row is the observed row, and it lands
  local kid="$SB_PREFIX-856-s1" kf kev ptr='ARCHIVE.md:1 "condensed index of completed issues"'
  kev="dev/evidence/$kid"
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1; git -C "$SB_WORK" reset -q --hard "origin/$SB_TRUNK" >/dev/null 2>&1
  _seed_parent "$SB_PREFIX-856" in_progress
  kf="$(_seed_subtask "$SB_PREFIX-856" s1 dev_complete oneptr "A slice of one UI AC with a pointer")"
  ROW="| AC1 | PASS | design | UX-001#default@$P: identical; $kev/UX-001-default-pin.png, $kev/UX-001-default-build.png; $ptr |" perl -0pi -e 's/(forks: none\n)/$1design: [UX-001#default\@'"$P"']\n/; s/- \[ \] AC1 — [^\n]*\n/- [ ] AC1 — (UI) from PRD-001-F1-S1: the list shows. [design: UX-001#default]\n/; s/^\| AC1 \|[^\n]*$/$ENV{ROW}/m' "$kf"
  _dm_png "$SB_WORK/$kev/UX-001-default-pin.png" LIST
  _dm_png "$SB_WORK/$kev/UX-001-default-build.png" BUILD
  _dm_land "a slice of one UI AC, its design row ending with a quoted pointer"
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-k" ./scripts/subtask.sh move "$kid" qa_complete 2>&1 </dev/null )"; rc=$?
  { [ "$rc" -eq 0 ] && origin_has_path "progress/subtasks/$SB_PREFIX-856/qa_complete/$kid-oneptr.md"; } || cf "(k) a slice of one (UI) AC whose design row ends with a quoted resolving path:line does not land (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | tail -c 600)"
  # (m) the same row with a path:line that does not resolve: refused, saying so, and the Next gives the way out
  local mid="$SB_PREFIX-857-s1" mf mev
  mev="dev/evidence/$mid"
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1; git -C "$SB_WORK" reset -q --hard "origin/$SB_TRUNK" >/dev/null 2>&1
  _seed_parent "$SB_PREFIX-857" in_progress
  mf="$(_seed_subtask "$SB_PREFIX-857" s1 dev_complete badptr "A slice of one UI AC with a pointer that does not resolve")"
  ROW="| AC1 | PASS | design | UX-001#default@$P: identical; $mev/UX-001-default-pin.png, $mev/UX-001-default-build.png; no-such-file.md:1 \"condensed index of completed issues\" |" perl -0pi -e 's/(forks: none\n)/$1design: [UX-001#default\@'"$P"']\n/; s/- \[ \] AC1 — [^\n]*\n/- [ ] AC1 — (UI) from PRD-001-F1-S1: the list shows. [design: UX-001#default]\n/; s/^\| AC1 \|[^\n]*$/$ENV{ROW}/m' "$mf"
  _dm_png "$SB_WORK/$mev/UX-001-default-pin.png" LIST
  _dm_png "$SB_WORK/$mev/UX-001-default-build.png" BUILD
  _dm_land "a slice of one UI AC, its design row ending with a pointer that does not resolve"
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-m" ./scripts/subtask.sh move "$mid" qa_complete 2>&1 </dev/null )"; rc=$?
  { [ "$rc" -ne 0 ] && _dm_has "$out" "no-such-file.md:1" && _dm_has "$out" "does not exist" && _dm_has "$out" "Next: re-read the code each row cites" && ! origin_has_path "progress/subtasks/$SB_PREFIX-857/qa_complete/$mid-badptr.md"; } || cf "(m) a design row whose path:line does not resolve is not refused with the reason and a Next (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | tail -c 600)"
  # (n) the design rows check reads the row without its pointer: an entry spelled inside a quote is no entry for the AC
  local nid="$SB_PREFIX-858-s1" nf nev trunk_n
  nev="dev/evidence/$nid"
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1; git -C "$SB_WORK" reset -q --hard "origin/$SB_TRUNK" >/dev/null 2>&1
  _seed_parent "$SB_PREFIX-858" in_progress
  nf="$(_seed_subtask "$SB_PREFIX-858" s1 dev_complete twostate "A slice of one UI AC citing two states")"
  ROW="| AC1 | PASS | design | UX-001#default@$P: identical; $nev/UX-001-default-pin.png, $nev/UX-001-default-build.png; ARCHIVE.md:1 \"UX-001#empty@$P: identical\" |" perl -0pi -e 's/(forks: none\n)/$1design: [UX-001#default\@'"$P"', UX-001#empty\@'"$P"']\n/; s/- \[ \] AC1 — [^\n]*\n/- [ ] AC1 — (UI) from PRD-001-F1-S1: both states show. [design: UX-001#default, UX-001#empty]\n/; s/^\| AC1 \|[^\n]*$/$ENV{ROW}/m' "$nf"
  _dm_land "a slice citing two states, the second spelled only inside a quote"
  trunk_n="$(git -C "$SB_WORK" rev-parse "origin/$SB_TRUNK")"
  out="$( bash "$SB_WORK/scripts/move-check.d/qa_complete/50-design-rows.sh" "$nid" dev_complete qa_complete QA "$nf" "$SB_WORK" "$trunk_n" 2>&1 </dev/null )"; rc=$?
  { [ "$rc" -eq 3 ] && _dm_has "$out" "no entry for UX-001#empty" && _dm_has "$out" "the card pins UX-001#empty, and no design row"; } || cf "(n) an entry spelled inside a pointer's quote stands for a state the AC cites, or one the card pins (status $rc): $(printf '%s' "$out" | tr '\n' '|' | tail -c 500)"
  # (p) the cell check reads the cell without the pointer wherever it stands: a pointer before the images lands as one after them
  local pid="$SB_PREFIX-859-s1" pf pev
  pev="dev/evidence/$pid"
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1; git -C "$SB_WORK" reset -q --hard "origin/$SB_TRUNK" >/dev/null 2>&1
  _seed_parent "$SB_PREFIX-859" in_progress
  pf="$(_seed_subtask "$SB_PREFIX-859" s1 dev_complete midptr "A slice of one UI AC with the pointer before the images")"
  ROW="| AC1 | PASS | design | UX-001#default@$P: identical; $ptr; $pev/UX-001-default-pin.png, $pev/UX-001-default-build.png |" perl -0pi -e 's/(forks: none\n)/$1design: [UX-001#default\@'"$P"']\n/; s/- \[ \] AC1 — [^\n]*\n/- [ ] AC1 — (UI) from PRD-001-F1-S1: the list shows. [design: UX-001#default]\n/; s/^\| AC1 \|[^\n]*$/$ENV{ROW}/m' "$pf"
  _dm_png "$SB_WORK/$pev/UX-001-default-pin.png" LIST
  _dm_png "$SB_WORK/$pev/UX-001-default-build.png" BUILD
  _dm_land "a slice of one UI AC, its pointer before the images"
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-p" ./scripts/subtask.sh move "$pid" qa_complete 2>&1 </dev/null )"; rc=$?
  { [ "$rc" -eq 0 ] && origin_has_path "progress/subtasks/$SB_PREFIX-859/qa_complete/$pid-midptr.md"; } || cf "(p) a design row with its pointer before the images does not land (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | tail -c 600)"
  # (q) a pointer in backticks is taken out as the gate takes it out: an entry spelled in its quote is no entry
  local qid="$SB_PREFIX-860-s1" qf qtrunk
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1; git -C "$SB_WORK" reset -q --hard "origin/$SB_TRUNK" >/dev/null 2>&1
  _seed_parent "$SB_PREFIX-860" in_progress
  qf="$(_seed_subtask "$SB_PREFIX-860" s1 dev_complete tick "A slice citing two states, the pointer in backticks")"
  ROW="| AC1 | PASS | design | UX-001#default@$P: identical; dev/evidence/$qid/UX-001-default-pin.png, dev/evidence/$qid/UX-001-default-build.png; \`ARCHIVE.md:1\` \"UX-001#empty@$P: identical\" |" perl -0pi -e 's/(forks: none\n)/$1design: [UX-001#default\@'"$P"', UX-001#empty\@'"$P"']\n/; s/- \[ \] AC1 — [^\n]*\n/- [ ] AC1 — (UI) from PRD-001-F1-S1: both states show. [design: UX-001#default, UX-001#empty]\n/; s/^\| AC1 \|[^\n]*$/$ENV{ROW}/m' "$qf"
  _dm_land "a slice citing two states, the second spelled only inside the quote of a backticked pointer"
  qtrunk="$(git -C "$SB_WORK" rev-parse "origin/$SB_TRUNK")"
  out="$( bash "$SB_WORK/scripts/move-check.d/qa_complete/50-design-rows.sh" "$qid" dev_complete qa_complete QA "$qf" "$SB_WORK" "$qtrunk" 2>&1 </dev/null )"; rc=$?
  { [ "$rc" -eq 3 ] && _dm_has "$out" "no entry for UX-001#empty"; } || cf "(q) an entry spelled inside the quote of a backticked pointer stands for a state the AC cites (status $rc): $(printf '%s' "$out" | tr '\n' '|' | tail -c 500)"
  # (r) a design row whose quote is not on its line is not refused for it, counts for nothing, and the refusal for the missing observed row lists it; the fragment says so
  local rid="$SB_PREFIX-861-s1" rf rev
  rev="dev/evidence/$rid"
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1; git -C "$SB_WORK" reset -q --hard "origin/$SB_TRUNK" >/dev/null 2>&1
  _seed_parent "$SB_PREFIX-861" in_progress
  rf="$(_seed_subtask "$SB_PREFIX-861" s1 dev_complete wrongq "A slice of one UI AC whose pointer quote is not on its line")"
  ROW="| AC1 | PASS | design | UX-001#default@$P: identical; $rev/UX-001-default-pin.png, $rev/UX-001-default-build.png; ARCHIVE.md:1 \"a quote the line does not hold\" |" perl -0pi -e 's/(forks: none\n)/$1design: [UX-001#default\@'"$P"']\n/; s/- \[ \] AC1 — [^\n]*\n/- [ ] AC1 — (UI) from PRD-001-F1-S1: the list shows. [design: UX-001#default]\n/; s/^\| AC1 \|[^\n]*$/$ENV{ROW}/m' "$rf"
  _dm_png "$SB_WORK/$rev/UX-001-default-pin.png" LIST
  _dm_png "$SB_WORK/$rev/UX-001-default-build.png" BUILD
  _dm_land "a slice of one UI AC, its pointer quote not on the line"
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-r" ./scripts/subtask.sh move "$rid" qa_complete 2>&1 </dev/null )"; rc=$?
  { [ "$rc" -ne 0 ] && _dm_has "$out" "did not count" && _dm_has "$out" "not found at ARCHIVE.md:1-1" && ! origin_has_path "progress/subtasks/$SB_PREFIX-861/qa_complete/$rid-wrongq.md"; } || cf "(r) a design row whose quote is not on its line is not refused with the quote listed (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | tail -c 700)"
  _dm_has "$(cat "$SB_WORK/.claude/templates/design/QA-verdict-design.fragment.md" 2>/dev/null)" "counts for nothing" || cf "(r) the QA fragment does not say a quote that is not found counts for nothing"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE TOKEN TOOLS WRITE WHAT THE DESIGN TYPE READS, AND THE AUDIT MEASURES IT. FIXTURES ARE A REAL PULL.
#   Operand: scripts/design/m3-tokens.mjs, dtcg-convert.py and contrast-audit.py, run from the module's source. The expected files are the
#   design system and the board a live Claude Design canvas held (the pulled tokens.json, the first block of its tokens.css, a board
#   with a 48 px button and a link), not what the tools would write.
# =============================================================================
_dm_node() { command -v node >/dev/null 2>&1 && node -e 'process.exit(parseInt(process.versions.node) >= 22 ? 0 : 1)' >/dev/null 2>&1; }
case_the_token_tools_write_what_the_design_type_reads_and_the_audit_measures_it() {
  cf_reset
  local L="m3-tokens.mjs writes the same bytes for the same seed, role names with no prefix, a greyscale wire file and the seed as primary-container, and its output passes the contrast audit in every theme (with --pin-primary a light seed warns and fails it); dtcg-convert.py turns the pulled steep tokens into the pulled design system's tokens.json sections and the first block of its tokens.css, in the type's theme shape; contrast-audit.py reads a pulled board's buttons and a link and flags one set below 44 px; the generated set passes the audit in every theme for the seeds that once failed in wire; a colour object's alpha is read as unread by the audit and written by the converter; the converter reads #rgb and exits 1, naming it, for a colour or dimension it cannot read; a token file that is not JSON is UNREAD and fails --strict; a colour token under another head than color is a colour to the converter (by its type) and a NOTE, not a failure, to the audit"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_node || { skp "$L" "Node 22 or later is absent: m3-tokens.mjs needs it (the module's manifest says optional)"; return; }
  _md_sandbox
  local m="$REAL_REPO_ROOT/modules/design/scripts/design" d="$SB_TMP/tk" i out
  mkdir -p "$d"
  node "$m/m3-tokens.mjs" '#2F6FEB' --name app --out "$d/a/requirements/design/tokens" >/dev/null 2>&1 || cf "(a) m3-tokens.mjs did not run on a seed"
  node "$m/m3-tokens.mjs" '#2F6FEB' --name app --out "$d/b" >/dev/null 2>&1
  # (a2) a usage request succeeds and prints the usage; a call with no seed still refuses with 64
  out="$(node "$m/m3-tokens.mjs" --help 2>&1)"; i=$?
  { [ "$i" -eq 0 ] && printf '%s' "$out" | grep -F 'usage: m3-tokens.mjs' >/dev/null; } || cf "(a2) m3-tokens.mjs --help does not exit 0 with its usage (exit $i): $out"
  node "$m/m3-tokens.mjs" >/dev/null 2>&1; i=$?
  [ "$i" -eq 64 ] || cf "(a2) m3-tokens.mjs with no seed does not exit 64 (exit $i)"
  # (a5) every argument error refuses with the usage and exit 64, and writes nothing: a name or a directory with no value, an unknown flag, two seeds, a bad seed
  mkdir -p "$d/args"
  for i in "--out $d/args/o1 --name" "--name app --out" "--bogus --out $d/args/o3" "#2F6FEB --out $d/args/o4" "#12345 --out $d/args/o5" "--name --out $d/args/o6" "--name --pin-primary --out $d/args/o7"; do
    # shellcheck disable=SC2086
    out="$(cd "$d/args" && node "$m/m3-tokens.mjs" '#2F6FEB' $i 2>&1)"; j=$?
    { [ "$j" -eq 64 ] && printf '%s' "$out" | grep -F 'usage: m3-tokens.mjs' >/dev/null && ! printf '%s' "$out" | grep -F 'TypeError' >/dev/null; } || cf "(a5) m3-tokens.mjs '#2F6FEB' $i does not refuse with the usage and exit 64 (exit $j): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"
  done
  [ -z "$(find "$d/args" -type f 2>/dev/null)" ] || cf "(a5) a refused m3-tokens.mjs call wrote files: $(find "$d/args" -type f | tr '\n' ' ')"
  # (a6) an empty value is no value, whatever the word splitting above would do with it: refused with the usage, nothing written
  mkdir -p "$d/args6"
  out="$(cd "$d/args6" && node "$m/m3-tokens.mjs" '#2F6FEB' --name '' --out "$d/args6/e1" 2>&1)"; j=$?
  { [ "$j" -eq 64 ] && printf '%s' "$out" | grep -F 'usage: m3-tokens.mjs' >/dev/null; } || cf "(a6) m3-tokens.mjs --name '' is not refused with the usage and exit 64 (exit $j): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"
  out="$(cd "$d/args6" && node "$m/m3-tokens.mjs" '#2F6FEB' --out '' 2>&1)"; j=$?
  { [ "$j" -eq 64 ] && printf '%s' "$out" | grep -F 'usage: m3-tokens.mjs' >/dev/null && ! printf '%s' "$out" | grep -F 'ENOENT' >/dev/null; } || cf "(a6) m3-tokens.mjs --out '' is not refused with the usage and exit 64 (exit $j): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"
  [ -z "$(find "$d/args6" -type f 2>/dev/null)" ] || cf "(a6) a refused empty-value call wrote files: $(find "$d/args6" -type f | tr '\n' ' ')"
  # (a4) the parsed suffix: a hyphen-led value is taken spaced or with an =, the last --suffix wins, and the parser's own option name is not swallowed
  for i in "--suffix -x|-x" "--suffix=-x|-x" "--suffix -x --suffix -y|-y"; do
    # shellcheck disable=SC2086
    _dm_py -c 'import sys; sys.path.insert(0, sys.argv[1]); import render; print(render.parse(["render.py", "p", "o"] + sys.argv[2:]).suffix)' "$m" ${i%|*}
    { [ "$_dm_rc" -eq 0 ] && [ "$_dm_out" = "${i#*|}" ]; } || cf "(a4) render.py parses '${i%|*}' to '$_dm_out', not '${i#*|}' (exit $_dm_rc)"
  done
  _dm_py -c 'import sys; sys.path.insert(0, sys.argv[1]); import render; render.parse(["render.py", "p", "o"] + sys.argv[2:])' "$m" --suffix --scheme dark
  { [ "$_dm_rc" -eq 2 ] && _dm_has "$_dm_out" "expected one argument"; } || cf "(a4) render.py --suffix --scheme dark takes --scheme as the suffix (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_py -c 'import sys; sys.path.insert(0, sys.argv[1]); import render; render.parse(["render.py", "p", "o"] + sys.argv[2:])' "$m" --chr x
  { [ "$_dm_rc" -eq 2 ] && _dm_has "$_dm_out" "unrecognized arguments"; } || cf "(a4b) render.py reads --chr as --chrome, a prefix of an option name (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  # (a3) render.py takes --suffix with a value that opens with a hyphen, spaced as well as with an =
  mkdir -p "$d/rp"
  for i in "--suffix -x" "--suffix=-x"; do
    # shellcheck disable=SC2086
    _dm_py "$m/render.py" "$d/rp" "$d/ro" --runtime "$d/no-such-runtime.js" $i
    { [ "$_dm_rc" -eq 3 ] && _dm_has "$_dm_out" "RUNTIME-ABSENT"; } || cf "(a3) render.py $i is refused as an argument error, not read as a suffix (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  done
  for i in app.tokens.json app.dark.tokens.json app.wire.tokens.json; do
    cmp -s "$d/a/requirements/design/tokens/$i" "$d/b/$i" || cf "(a) the same seed does not give the same bytes in $i"
  done
  cat > "$d/check-m3.py" <<'PYEOF'
import json, sys
t = sys.argv[1] + '/'
base, wire = json.load(open(t + 'app.tokens.json')), json.load(open(t + 'app.wire.tokens.json'))
c = base['color']
assert c['primary-container']['$value'] == '#2f6feb', c['primary-container']
assert 'primary' in c and not any(k.startswith(('m3', 'md')) for k in c), 'prefixed names'
grey = [v['$value'] for k, v in wire['color'].items() if not k.startswith('$')]
assert grey and all(h[1:3] == h[3:5] == h[5:7] for h in grey), 'wire is not greyscale'
PYEOF
  _dm_py "$d/check-m3.py" "$d/a/requirements/design/tokens"
  [ "$_dm_rc" -eq 0 ] || cf "(b) the generated files are not role-named, seed-faithful and greyscale in wire: $(printf '%s' "$_dm_out" | tr '\n' '|' | tail -c 200)"
  _dm_py "$m/contrast-audit.py" "$d/a" --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "pair(s) measured, 0 below"; } || cf "(c) the fidelity default does not pass the contrast audit (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  out="$(node "$m/m3-tokens.mjs" '#F59E0B' --name app --out "$d/p/requirements/design/tokens" --pin-primary 2>&1)"
  _dm_has "$out" "warning" || cf "(d) --pin-primary does not warn"
  _dm_py "$m/contrast-audit.py" "$d/p" --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "LOW light: color-on-primary"; } || cf "(d) a light seed pinned as primary does not fail the audit (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  # the pulled design system: the steep tokens as the Designer would write them, and what the canvas's system held
  mkdir -p "$d/s/tokens" "$d/s/out"
  cat > "$d/s/tokens/steep.tokens.json" <<'EOF'
{"color":{"surface":{"$value":"#FAF8F3","$description":"Screen background."},"surface-raised":{"$value":"#FFFFFF","$description":"Rows and cards on color-surface."},"on-surface":{"$value":"#1F2421","$description":"Text on color-surface and color-surface-raised."},"muted":{"$value":"#4A5553","$description":"Secondary text on color-surface and color-surface-raised."},"primary":{"$value":"#22577A","$description":"The primary action."},"on-primary":{"$value":"#FFFFFF","$description":"Text on color-primary."}},
"space-2":{"$value":"8px","$description":"Tight gaps."},"space-4":{"$value":"16px","$description":"Screen side margin and row padding."},"space-6":{"$value":"24px","$description":"Screen top margin."},
"radius-md":{"$value":"12px","$description":"Rows and cards."},"radius-full":{"$value":"24px","$description":"Buttons."}}
EOF
  printf '%s\n' '{"color":{"surface":{"$value":"#141816"},"surface-raised":{"$value":"#1F2421"},"on-surface":{"$value":"#F0EEE8"},"muted":{"$value":"#B8C2BF"},"primary":{"$value":"#8FC4E8"},"on-primary":{"$value":"#0B2433"}}}' > "$d/s/tokens/steep.dark.tokens.json"
  printf '%s\n' '{"color":{"surface":{"$value":"#F9F9F9"},"surface-raised":{"$value":"#FFFFFF"},"on-surface":{"$value":"#1C1C1C"},"muted":{"$value":"#464646"},"primary":{"$value":"#555555"},"on-primary":{"$value":"#FFFFFF"}}}' > "$d/s/tokens/steep.wire.tokens.json"
  cat > "$d/pulled-tokens.json" <<'EOF'
{"name":"Steep tokens","version":1,
"color":{"themes":[{"id":"light","name":"Light"},{"id":"dark","name":"Dark"},{"id":"wire","name":"Wire"}],
"tokens":[
{"name":"color-surface","value":{"light":"#FAF8F3","dark":"#141816","wire":"#F9F9F9"},"usage":"Screen background."},
{"name":"color-surface-raised","value":{"light":"#FFFFFF","dark":"#1F2421","wire":"#FFFFFF"},"usage":"Rows and cards on color-surface."},
{"name":"color-on-surface","value":{"light":"#1F2421","dark":"#F0EEE8","wire":"#1C1C1C"},"usage":"Text on color-surface and color-surface-raised."},
{"name":"color-muted","value":{"light":"#4A5553","dark":"#B8C2BF","wire":"#464646"},"usage":"Secondary text on color-surface and color-surface-raised."},
{"name":"color-primary","value":{"light":"#22577A","dark":"#8FC4E8","wire":"#555555"},"usage":"The primary action."},
{"name":"color-on-primary","value":{"light":"#FFFFFF","dark":"#0B2433","wire":"#FFFFFF"},"usage":"Text on color-primary."}
]},
"type":{"fonts":[],"families":{"sans":"system-ui, sans-serif"},
"groups":[{"name":"Text","family":"sans","styles":[
{"name":"title","fontSize":"24px","lineHeight":"32px","fontWeight":600},
{"name":"body","fontSize":"16px","lineHeight":"24px","fontWeight":400},
{"name":"caption","fontSize":"14px","lineHeight":"20px","fontWeight":400}]}]},
"spacing":{"tokens":[{"name":"space-2","value":"8px","usage":"Tight gaps."},{"name":"space-4","value":"16px","usage":"Screen side margin and row padding."},{"name":"space-6","value":"24px","usage":"Screen top margin."}]},
"radius":{"tokens":[{"name":"radius-md","value":"12px","usage":"Rows and cards."},{"name":"radius-full","value":"24px","usage":"Buttons."}]}}
EOF
  _dm_py "$m/dtcg-convert.py" "$d/s/tokens" --out "$d/s/out" --title "Steep tokens"
  [ "$_dm_rc" -eq 0 ] || cf "(e) dtcg-convert.py failed on the steep tokens: $(printf '%s' "$_dm_out" | tr '\n' '|' | tail -c 200)"
  cat > "$d/cmp-ds.py" <<'PYEOF'
import json, sys
a, b = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
for k in ('color', 'spacing', 'radius'):
    assert a[k] == b[k], k
PYEOF
  _dm_py "$d/cmp-ds.py" "$d/s/out/tokens.json" "$d/pulled-tokens.json"
  [ "$_dm_rc" -eq 0 ] || cf "(e) the converted tokens.json differs from the one the canvas's design system held: $(printf '%s' "$_dm_out" | tr '\n' '|' | tail -c 200)"
  cat > "$d/pulled-block.css" <<'EOF'
:root, [data-theme="light"] {
  --color-surface: #FAF8F3;
  --color-surface-raised: #FFFFFF;
  --color-on-surface: #1F2421;
  --color-muted: #4A5553;
  --color-primary: #22577A;
  --color-on-primary: #FFFFFF;
}
EOF
  [ "$(sed -n 3,10p "$d/s/out/tokens.css")" = "$(cat "$d/pulled-block.css")" ] || cf "(e) the first block of tokens.css is not the pulled one: $(sed -n 3,10p "$d/s/out/tokens.css" | tr '\n' '|')"
  { grep -F '[data-theme="dark"] {' "$d/s/out/tokens.css" >/dev/null && grep -F '[data-theme="wire"] {' "$d/s/out/tokens.css" >/dev/null; } || cf "(e) the other themes are not [data-theme=\"<id>\"] blocks"
  # the pulled board: a 48 px button and a link; the same board with the button at 32 px
  mkdir -p "$d/s/requirements/design/steep/project"
  cp -R "$d/s/tokens" "$d/s/requirements/design/tokens"
  cat > "$d/s/requirements/design/steep/project/Timer.dc.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Timer</title>
<script src="./support.js"></script>
<link rel="stylesheet" href="sheets/tokens.css">
</head>
<body>
<x-dc>
<helmet>
<style>
body{margin:0}
</style>
</helmet>
<div id="ux-002-root" data-ux="UX-002" data-stories="PRD-001-F1-S2" class="ux-screen" style="width: 390px; height: 844px; box-sizing: border-box; padding: 24px 16px; display: flex; flex-direction: column; gap: 16px; background: var(--color-surface); color: var(--color-on-surface); font-family: system-ui, sans-serif">
<h1 id="ux-002-title" style="margin: 0; font-size: 24px; line-height: 32px; font-weight: 600">Sencha</h1>
<sc-if value="{{isIdle}}" hint-placeholder-val="{{ true }}">
<div id="ux-002-idle" data-state="idle" style="display: flex; flex-direction: column; gap: 16px">
<p id="ux-002-remaining" style="margin: 0; font-size: 48px; line-height: 56px; font-weight: 300">2:00</p>
<button id="ux-002-start" type="button" style="height: 48px; border: 0; border-radius: 24px; background: var(--color-primary); color: var(--color-on-primary); font-size: 16px; font-weight: 500; font-family: inherit">Start</button>
</div>
</sc-if>
<sc-if value="{{isDone}}" hint-placeholder-val="{{ false }}">
<div id="ux-002-done" data-state="done" style="display: flex; flex-direction: column; gap: 16px">
<p id="ux-002-ready" style="margin: 0; font-size: 24px; line-height: 32px">Ready to pour</p>
<a id="ux-002-back" href="Main.dc.html" style="display: flex; align-items: center; justify-content: center; height: 48px; border-radius: 24px; background: var(--color-primary); color: var(--color-on-primary); text-decoration: none; font-size: 16px; font-weight: 500">Back to brews</a>
</div>
</sc-if>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"view":{"editor":"enum","default":"idle","options":["idle","done"]},"$preview":{"width":390,"height":844}}'>
class Component extends DCLogic {
renderVals() {
const v = this.props.view ?? 'idle';
return { isIdle: v === 'idle', isDone: v === 'done' };
}
}
</script>
</body>
</html>
EOF
  _dm_py "$m/contrast-audit.py" "$d/s" --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "2 sized target(s) read, 0 below"; } || cf "(f) the pulled board and tokens do not audit clean with two targets read (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  _dm_edit "$d/s/requirements/design/steep/project/Timer.dc.html" 's/id="ux-002-start" type="button" style="height: 48px/id="ux-002-start" type="button" style="height: 32px/'
  _dm_py "$m/contrast-audit.py" "$d/s" --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "SMALL" && _dm_has "$_dm_out" "ux-002-start"; } || cf "(f) a button set to 32 px is not flagged SMALL, naming it (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  # (h) every seed passes, the five that failed (Material red 600, teal 600, pink 500, two greys) and the extremes among them
  for i in '#E53935' '#00897B' '#E91E63' '#808080' '#777777' '#FFFFFF' '#000000' '#FFEB3B' '#0080ff' '#009900' '#217068' '#2a68a4' '#5345fb' '#af20a7' '#cc0033' '#cc3399' '#d6316c' '#ff0080'; do
    rm -rf "$d/m"; node "$m/m3-tokens.mjs" "$i" --name app --out "$d/m/requirements/design/tokens" >/dev/null 2>&1
    _dm_py "$m/contrast-audit.py" "$d/m" --strict
    [ "$_dm_rc" -eq 0 ] || cf "(h) the fidelity default for seed $i does not pass the contrast audit (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  done
  # (i) the audit reads what the converter reads (DTCG colour objects), and does not pass what it did not read
  rm -rf "$d/o"; mkdir -p "$d/o/requirements/design/tokens"
  printf '%s\n' '{"color":{"surface":{"$value":{"colorSpace":"srgb","components":[1,1,1],"hex":"#ffffff"}},"on-surface":{"$value":{"colorSpace":"srgb","components":[0.93,0.93,0.93],"hex":"#eeeeee"}}}}' > "$d/o/requirements/design/tokens/o.tokens.json"
  _dm_py "$m/contrast-audit.py" "$d/o" --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "LOW light: color-on-surface"; } || cf "(i) a 1.13:1 pair written as DTCG colour objects is not measured and failed (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  printf '%s\n' '{"color":{"surface":{"$value":"#fff"},"on-surface":{"$value":"#eee"},"primary":{"$value":"#336699"},"on-primary":{"$value":"#ffffff20"}}}' > "$d/o/requirements/design/tokens/o.tokens.json"
  _dm_py "$m/contrast-audit.py" "$d/o" --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "LOW light: color-on-surface #eeeeee on color-surface #ffffff" && _dm_has "$_dm_out" "UNREAD light: color-on-primary"; } || cf "(i) #eee on #fff is not measured, or an alpha colour passes as read (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' '{"color":{"surface":{"$value":"#ffffff"},"on-surface":{"$value":{"colorSpace":"srgb","components":[0,0,0],"alpha":0.12,"hex":"#000000"}}}}' > "$d/o/requirements/design/tokens/o.tokens.json"
  _dm_py "$m/contrast-audit.py" "$d/o" --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "UNREAD light: color-on-surface" && _dm_has "$_dm_out" "alpha"; } || cf "(i) a colour object with alpha 0.12 passes as opaque black at 21:1 (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' '{"color":{"surface":{"$value":"#ffffff"},"on-surface":{"$value":{"colorSpace":"srgb","components":[0.93,0.93,0.93],"alpha":1,"hex":"#eeeeee"}}}}' > "$d/o/requirements/design/tokens/o.tokens.json"
  _dm_py "$m/contrast-audit.py" "$d/o" --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "LOW light: color-on-surface"; } || cf "(i) a colour object with alpha 1 is not measured (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  printf '%s\n' '{"color":{"surface":{"$value":"#747475"},"on-surface":{"$value":"#000000"}}}' > "$d/o/requirements/design/tokens/o.tokens.json"
  _dm_py "$m/contrast-audit.py" "$d/o" --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "= 4.49:1 < 4.5:1" && ! _dm_has "$_dm_out" "= 4.50:1"; } || cf "(i) a 4.4976:1 pair is not printed under the line it fails (4.49:1 < 4.5:1) (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  printf '%s\n' '{"color":{"primary":{"$value":"#336699"}}}' > "$d/o/requirements/design/tokens/o.tokens.json"
  _dm_py "$m/contrast-audit.py" "$d/o" --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "NONE"; } || cf "(i) a run that measured no pair passes --strict (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  # (j) the generator's own spacing group reaches the converter's output
  mkdir -p "$d/g/out"
  _dm_py "$m/dtcg-convert.py" "$d/a/requirements/design/tokens" --out "$d/g/out"
  { [ "$_dm_rc" -eq 0 ] && grep -F -- '--spacing-space-16: 16px;' "$d/g/out/tokens.css" >/dev/null && ! _dm_has "$_dm_out" "spacing.space-"; } || cf "(j) the generator's spacing tokens are not in the converted tokens.css: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  # (k) the converter reads #rgb and a colour object's alpha, and a token it cannot read is said and fails the exit status
  rm -rf "$d/k"; mkdir -p "$d/k/t" "$d/k/out"
  printf '%s\n' '{"color":{"surface":{"$value":"#fff"},"on-surface":{"$value":"#111"},"soft":{"$value":{"colorSpace":"srgb","components":[0,0,0],"alpha":0.2,"hex":"#000000"}}},"space-0":{"$value":0},"space-4":{"$value":"4px"}}' > "$d/k/t/k.tokens.json"
  printf '%s\n' '{"color":{"surface":{"$value":"#101417"},"on-surface":{"$value":"#eee"}}}' > "$d/k/t/k.dark.tokens.json"
  _dm_py "$m/dtcg-convert.py" "$d/k/t" --out "$d/k/out"
  { [ "$_dm_rc" -eq 0 ] && grep -F -- '--color-surface: #ffffff;' "$d/k/out/tokens.css" >/dev/null && grep -F -- '--color-on-surface: #111111;' "$d/k/out/tokens.css" >/dev/null && grep -F -- '--color-soft: #00000033;' "$d/k/out/tokens.css" >/dev/null && grep -F -- '--color-on-surface: #eeeeee;' "$d/k/out/tokens.css" >/dev/null && grep -F -- '--space-0: 0;' "$d/k/out/tokens.css" >/dev/null; } || cf "(k) #fff, #111, #eee, a 20% black and a bare 0 are not all in the converted tokens.css (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  printf '%s\n' '{"color":{"surface":{"$value":"#fff"},"badcol":{"$value":"red"}},"space-4":{"$value":"four"}}' > "$d/k/t/k.tokens.json"
  rm -f "$d/k/t/k.dark.tokens.json"
  _dm_py "$m/dtcg-convert.py" "$d/k/t" --out "$d/k/out"
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "NOT CONVERTED: color.badcol" && _dm_has "$_dm_out" "NOT CONVERTED: space-4" && grep -F -- '--color-surface: #ffffff;' "$d/k/out/tokens.css" >/dev/null; } || cf "(k) a colour and a spacing the converter cannot read are not named with exit 1, the rest written (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  # (l) a token file the audit cannot parse is said, and fails --strict, however the file is broken
  for i in comma bom empty; do
    rm -rf "$d/e"; cp -R "$d/a" "$d/e"
    case "$i" in
      comma) _dm_edit "$d/e/requirements/design/tokens/app.dark.tokens.json" '$s/}$/,}/' ;;
      bom) printf '\357\273\277' | cat - "$d/a/requirements/design/tokens/app.dark.tokens.json" > "$d/e/requirements/design/tokens/app.dark.tokens.json" ;;
      empty) : > "$d/e/requirements/design/tokens/app.dark.tokens.json" ;;
    esac
    _dm_py "$m/contrast-audit.py" "$d/e" --strict
    { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "UNREAD app.dark.tokens.json" && _dm_has "$_dm_out" "1 token file(s) not read"; } || cf "(l) a dark token file with $i passes --strict as if it were measured (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  done
  # (l2) a theme file of valid JSON that holds no colour token leaves its theme unmeasured: said, and fails --strict
  for i in '{}' '{"space-4":{"$value":"4px"}}'; do
    rm -rf "$d/h"; cp -R "$d/a" "$d/h"
    printf '%s\n' "$i" > "$d/h/requirements/design/tokens/app.dark.tokens.json"
    _dm_py "$m/contrast-audit.py" "$d/h" --strict
    { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "UNREAD app.dark.tokens.json" && _dm_has "$_dm_out" "holds no color.* token" && _dm_has "$_dm_out" "1 token file(s) not read"; } || cf "(l2) a dark token file holding $i passes --strict as if its theme were measured (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  done
  # (l3) the base file counts too when its namespace has theme files (or the run measured nothing); a spacing-only namespace beside them stays quiet
  rm -rf "$d/h"; cp -R "$d/a" "$d/h"
  printf '%s\n' '{}' > "$d/h/requirements/design/tokens/app.tokens.json"
  _dm_py "$m/contrast-audit.py" "$d/h" --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "UNREAD app.tokens.json" && _dm_has "$_dm_out" "holds no color.* token" && _dm_has "$_dm_out" "1 token file(s) not read"; } || cf "(l3) a base token file holding {} passes --strict as if its theme were measured (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  rm -rf "$d/h"; cp -R "$d/a" "$d/h"
  printf '%s\n' '{"space":{"4":{"$value":"4px","$type":"dimension"}}}' > "$d/h/requirements/design/tokens/spacing.tokens.json"
  _dm_py "$m/contrast-audit.py" "$d/h" --strict
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "UNREAD spacing.tokens.json"; } || cf "(l3) a spacing-only namespace of its own, beside a measured one, is reported or fails --strict (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  # (l5) a base of non-colour tokens beside a light and a dark file that both hold colours is what the hint leads to: nothing is unmeasured, nothing is said
  rm -rf "$d/h"; cp -R "$d/a" "$d/h"
  cp "$d/h/requirements/design/tokens/app.tokens.json" "$d/h/requirements/design/tokens/app.light.tokens.json"
  printf '%s\n' '{"space":{"4":{"$value":"4px","$type":"dimension"}}}' > "$d/h/requirements/design/tokens/app.tokens.json"
  _dm_py "$m/contrast-audit.py" "$d/h" --strict
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "UNREAD app.tokens.json"; } || cf "(l5) a spacing-only base beside a light and a dark file that hold colours is reported or fails --strict (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  # (l4) the line for a theme file says what to do; a directory named like a token file is not one
  rm -rf "$d/h"; cp -R "$d/a" "$d/h"
  printf '%s\n' '{"space":{"4":{"$value":"4px","$type":"dimension"}}}' > "$d/h/requirements/design/tokens/app.spacing.tokens.json"
  mkdir -p "$d/h/requirements/design/tokens/x.dark.tokens.json"
  _dm_py "$m/contrast-audit.py" "$d/h" --strict
  { _dm_has "$_dm_out" "UNREAD app.spacing.tokens.json" && _dm_has "$_dm_out" "non-colour tokens go in <ns>.tokens.json" && ! _dm_has "$_dm_out" "x.dark.tokens.json"; } || cf "(l4) the line for a theme file with no colour does not say where non-colour tokens go, or a directory named x.dark.tokens.json is reported (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  # (m) a colour token under another head than color: the converter takes it by its type, the audit says no pair measures it, and a primitive reached by alias stays healthy
  rm -rf "$d/f"; mkdir -p "$d/f/requirements/design/tokens" "$d/f/out"
  cat > "$d/f/requirements/design/tokens/app.tokens.json" <<'EOF'
{"palette":{"$type":"color","ink":{"$value":"#101010"},"paper":{"$value":"#ffffff"}},
 "color":{"$type":"color","surface":{"$value":"{palette.paper}"},"on-surface":{"$value":"{palette.ink}"}},
 "brand":{"$type":"color","leaf":{"$value":"#ff0000"}},
 "text":{"muted":{"$value":"#eeeeee"}},
 "gap":{"$type":"dimension","md":{"$value":"12px"}},
 "border":{"radius":{"md":{"$type":"dimension","$value":"6px"}}},
 "fx":{"$type":"shadow","a":{"$value":"0 1px 2px #000"}}}
EOF
  _dm_py "$m/contrast-audit.py" "$d/f" --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "NOTE app.tokens.json" && _dm_has "$_dm_out" "palette-ink" && _dm_has "$_dm_out" "brand-leaf" && _dm_has "$_dm_out" "text-muted" && _dm_has "$_dm_out" "1 pair(s) measured" && ! _dm_has "$_dm_out" "UNREAD"; } || cf "(m) the audit does not name the colour tokens outside color.* that no pair measures, as a note that leaves --strict at 0 (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_py "$m/dtcg-convert.py" "$d/f/requirements/design/tokens" --out "$d/f/out"
  { [ "$_dm_rc" -eq 0 ] && grep -F -- '--brand-leaf: #ff0000;' "$d/f/out/tokens.css" >/dev/null && grep -F -- '--palette-ink: #101010;' "$d/f/out/tokens.css" >/dev/null && grep -F -- '--color-on-surface: #101010;' "$d/f/out/tokens.css" >/dev/null && grep -F -- '--text-muted: #eeeeee;' "$d/f/out/tokens.css" >/dev/null && grep -F -- '--gap-md: 12px;' "$d/f/out/tokens.css" >/dev/null && grep -F -- '--border-radius-md: 6px;' "$d/f/out/tokens.css" >/dev/null && _dm_has "$_dm_out" 'of $type shadow' && ! _dm_has "$_dm_out" "not a colour"; } || cf "(m) the converter drops a colour or a dimension that sits under another head, or gives a false reason for the shadow (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' '{"brand":{"$type":"color","bad":{"$value":"red"}}}' > "$d/f/requirements/design/tokens/app.tokens.json"
  _dm_py "$m/dtcg-convert.py" "$d/f/requirements/design/tokens" --out "$d/f/out"
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "NOT CONVERTED: brand.bad"; } || cf "(m) a colour under brand that is not a colour is not NOT CONVERTED with exit 1 (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  for i in LICENSE NOTICE m3-static.json material-color-utilities/index.js; do
    [ -f "$m/vendor/$i" ] || cf "(g) vendor/$i is not in the module"
  done
  { grep -F 'material-color-utilities' "$m/vendor/NOTICE" >/dev/null && grep -F 'Apache' "$m/vendor/LICENSE" >/dev/null; } || cf "(g) the NOTICE does not name the vendored package, or the LICENSE is not the Apache text"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — RENDER.PY GIVES CHROME THE THEME, THE FORCED COLOUR SCHEME AND THE SCALE, SERVES THE RUNTIME AS support.js, AND SAYS WHAT IS MISSING.
#   Operand: scripts/design/render.py over a board and a canvas.json that a live canvas held, with a stand-in for Chrome that records its
#   arguments and fetches the page's support.js (this harness has no Chrome, and the design runtime is not ours to ship).
# =============================================================================
case_render_py_gives_chrome_the_theme_the_scheme_and_the_scale_and_says_what_is_missing() {
  cf_reset
  local L="render.py without a runtime says RUNTIME-ABSENT and exits 3, without Chrome CHROME-ABSENT and exits 3; with both it renders each board at the size canvas.json gives it, forces the colour scheme (light by default, dark on request), passes --scale and ?theme=wire, and serves the runtime followed by its postlude as support.js"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _md_sandbox
  local m="$REAL_REPO_ROOT/modules/design/scripts/design" d="$SB_TMP/rn" args="$SB_TMP/rn-args" sup="$SB_TMP/rn-support" want
  mkdir -p "$d/project" "$d/out"
  cat > "$d/project/canvas.json" <<'EOF'
{"v":3,"createdOnFiles":{"v":1,"at":"2026-11-01T04:30:00Z"},"title":"Brews","launch":{"view":"canvas"},"pages":[],"boards":{"Main.dc.html":{"x":0,"y":0,"w":390,"h":844,"title":"UX-001 Brews (phone)","is_interactive":true},"Timer.dc.html":{"x":470,"y":0,"w":390,"h":844,"title":"UX-002 Timer (phone)"},"Settings.dc.html":{"x":940,"y":0,"w":390,"h":844,"title":"UX-003 Settings (phone)"}},"order":["Main.dc.html","Timer.dc.html","Settings.dc.html"],"notes":{"note-brief":{"x":0,"y":-200,"w":320,"text":"Authored from a brief."}},"designSystems":[]}
EOF
  cat > "$d/project/Timer.dc.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Timer</title>
<script src="./support.js"></script>
<link rel="stylesheet" href="sheets/tokens.css">
</head>
<body>
<x-dc>
<helmet>
<style>
body{margin:0}
</style>
</helmet>
<div id="ux-002-root" data-ux="UX-002" data-stories="PRD-001-F1-S2" class="ux-screen" style="width: 390px; height: 844px; box-sizing: border-box; padding: 24px 16px; display: flex; flex-direction: column; gap: 16px; background: var(--color-surface); color: var(--color-on-surface); font-family: system-ui, sans-serif">
<h1 id="ux-002-title" style="margin: 0; font-size: 24px; line-height: 32px; font-weight: 600">Sencha</h1>
<sc-if value="{{isIdle}}" hint-placeholder-val="{{ true }}">
<div id="ux-002-idle" data-state="idle" style="display: flex; flex-direction: column; gap: 16px">
<p id="ux-002-remaining" style="margin: 0; font-size: 48px; line-height: 56px; font-weight: 300">2:00</p>
<button id="ux-002-start" type="button" style="height: 48px; border: 0; border-radius: 24px; background: var(--color-primary); color: var(--color-on-primary); font-size: 16px; font-weight: 500; font-family: inherit">Start</button>
</div>
</sc-if>
<sc-if value="{{isDone}}" hint-placeholder-val="{{ false }}">
<div id="ux-002-done" data-state="done" style="display: flex; flex-direction: column; gap: 16px">
<p id="ux-002-ready" style="margin: 0; font-size: 24px; line-height: 32px">Ready to pour</p>
<a id="ux-002-back" href="Main.dc.html" style="display: flex; align-items: center; justify-content: center; height: 48px; border-radius: 24px; background: var(--color-primary); color: var(--color-on-primary); text-decoration: none; font-size: 16px; font-weight: 500">Back to brews</a>
</div>
</sc-if>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"view":{"editor":"enum","default":"idle","options":["idle","done"]},"$preview":{"width":390,"height":844}}'>
class Component extends DCLogic {
renderVals() {
const v = this.props.view ?? 'idle';
return { isIdle: v === 'idle', isDone: v === 'done' };
}
}
</script>
</body>
</html>
EOF
  printf '/* stand-in design runtime */\nwindow.__stand_in = 1;\nwindow.__dcSetProps = function(){};\nwindow.__dcRootName = function(){ return "r"; };\n' > "$d/rt.js"
  cat > "$d/stub.py" <<'PYEOF'
import re, sys, urllib.parse as u, urllib.request
p = u.urlparse(sys.argv[1])
base = p.scheme + '://' + p.netloc
src = urllib.request.urlopen(base + '/support.js').read()
open(sys.argv[2], 'wb').write(src)
runtime = src.decode('utf-8', 'replace').split(';(function(){try{')[0]      # what the page runs before the postlude
if re.search(r'__dcSetProps\s*=', runtime) and re.search(r'__dcRootName\s*=', runtime):
    urllib.request.urlopen(base + '/__kit-runtime-ran?b=' + u.quote(u.unquote(p.path)[1:], safe=''))   # what the postlude's own check sends once the hooks exist
if 'Gone' in p.path:                                                  # a page that asks for a sheet the project lacks
    try:
        urllib.request.urlopen(base + '/gone.css')
    except Exception:
        pass
if 'Logs' in p.path:                                                  # a board whose logic throws: the runtime calls console.error, the postlude's wrapper sends it
    urllib.request.urlopen(base + '/__kit-runtime-error?m=' + u.quote('Error: boom'))
if 'Tall' in p.path or 'Fits' in p.path:                              # the postlude reports the page's scrollHeight once the board has drawn
    urllib.request.urlopen(base + '/__kit-board-height?b=' + u.quote(u.unquote(p.path)[1:], safe='') + '&h=' + ('1200' if 'Tall' in p.path else '844'))
if 'Quiet' in p.path:                                                 # a healthy board: the runtime's warning is a console line that Chrome logs, never a console.error call
    sys.stderr.write('[1:2:1101/000000.000000:INFO:CONSOLE:350] "[dc-runtime] Dashboard: {{ row.name }} never resolved \u2014 rendered as empty", source: %s/support.js (350)\n' % base)
PYEOF
  cat > "$d/chrome" <<EOF
#!/bin/bash
printf '%s\n' "\$@" >> '$args'
shot=""; url=""
for a in "\$@"; do case "\$a" in --screenshot=*) shot="\${a#--screenshot=}" ;; http://*) url="\$a" ;; esac; done
python3 '$d/stub.py' "\$url" '$sup'
printf '\211PNG\r\n\032\n' > "\$shot"
EOF
  chmod +x "$d/chrome"
  _dm_py "$m/render.py" "$d/project" "$d/out" --chrome "$d/chrome"
  { [ "$_dm_rc" -eq 3 ] && _dm_has "$_dm_out" "RUNTIME-ABSENT"; } || cf "(a) no runtime: not RUNTIME-ABSENT with exit 3 (exit $_dm_rc): $_dm_out"
  _dm_py "$m/render.py" "$d/project" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome-not-there"
  if [ ! -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ] && ! command -v google-chrome >/dev/null 2>&1 && ! command -v chromium >/dev/null 2>&1; then
    { [ "$_dm_rc" -eq 3 ] && _dm_has "$_dm_out" "CHROME-ABSENT"; } || cf "(b) no Chrome: not CHROME-ABSENT with exit 3 (exit $_dm_rc): $_dm_out"
  fi
  cat > "$d/project/themed.css" <<'EOF'
[data-theme="wire"] { --color-primary: #555555; }
EOF
  _dm_py "$m/render.py" "$d/project" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome" --theme wire --scale 2
  { [ "$_dm_rc" -eq 0 ] && [ -f "$d/out/Timer.png" ]; } || cf "(c) the stand-in render failed (exit $_dm_rc): $_dm_out"
  for want in '--blink-settings=preferredColorScheme=1' '--force-device-scale-factor=2' '--window-size=390,844'; do
    grep -Fx -- "$want" "$args" >/dev/null || cf "(c) Chrome was not given $want: $(tr '\n' ' ' < "$args" | cut -c1-300)"
  done
  grep -F 'Timer.dc.html?theme=wire' "$args" >/dev/null || cf "(c) the page URL does not carry ?theme=wire"
  { grep -F 'window.__stand_in = 1;' "$sup" >/dev/null && grep -F "setAttribute('data-theme'" "$sup" >/dev/null; } || cf "(c) support.js is not the runtime followed by the postlude"
  [ ! -e "$d/project/support.js" ] || cf "(c) support.js was written into the project"
  : > "$args"
  _dm_py "$m/render.py" "$d/project" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome" --scheme dark
  grep -Fx -- '--blink-settings=preferredColorScheme=0' "$args" >/dev/null || cf "(d) --scheme dark does not force the dark scheme (Blink: 0 is dark, 1 is light)"
  # (e) a re-render that fails must not leave the last PNG to pass for it
  printf 'old\n' > "$d/out/Timer.png"
  printf '#!/bin/bash\nexit 1\n' > "$d/chrome-fails"; chmod +x "$d/chrome-fails"
  _dm_py "$m/render.py" "$d/project" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome-fails"
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "FAIL" && [ ! -e "$d/out/Timer.png" ]; } || cf "(e) a Chrome that fails over an old PNG reads OK or leaves the old PNG (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  # (f) a theme no file answers is refused; a board named that is not there is said; a Chrome that is not there is not replaced
  _dm_py "$m/render.py" "$d/project" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome" --theme no-such
  { [ "$_dm_rc" -eq 2 ] && _dm_has "$_dm_out" "UNKNOWN-THEME"; } || cf "(f) an unknown theme id is not refused (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_py "$m/render.py" "$d/project" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome" --theme wire
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "NO-THEME-RULE"; } || cf "(f) a board that no sheet answers --theme wire for is not said to draw as the brand version (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_py "$m/render.py" "$d/project" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome" --only Nope.dc.html
  { [ "$_dm_rc" -eq 2 ] && _dm_has "$_dm_out" "NO-SUCH-BOARD"; } || cf "(f) --only a board that is not there renders nothing in silence (exit $_dm_rc): $_dm_out"
  _dm_py "$m/render.py" "$d/project" "$d/out" --runtime "$d/rt.js" --chrome "$d/no-such-chrome"
  { [ "$_dm_rc" -eq 3 ] && _dm_has "$_dm_out" "CHROME-ABSENT"; } || cf "(f) a --chrome that does not exist is replaced by another Chrome (exit $_dm_rc): $_dm_out"
  # (g) a runtime that does not run is a FAIL with no PNG, never an OK over a page drawn without it
  printf '/* cut short */\nwindow.__stand_in = 1;\n' > "$d/rt-bad.js"; : > "$d/rt-empty.js"
  for want in rt-bad.js rt-empty.js; do
    rm -f "$d/out/Timer.png"
    _dm_py "$m/render.py" "$d/project" "$d/out" --runtime "$d/$want" --chrome "$d/chrome" --only Timer.dc.html
    { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "FAIL" && _dm_has "$_dm_out" "RUNTIME-DID-NOT-RUN" && [ ! -e "$d/out/Timer.png" ]; } || cf "(g) $want, which defines no hook, is not a FAIL naming RUNTIME-DID-NOT-RUN with no PNG (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  done
  # (h) what it refuses is said, with its own exit code: no board, no folder, props that are not JSON
  mkdir -p "$d/empty-project"
  _dm_py "$m/render.py" "$d/empty-project" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome"
  { [ "$_dm_rc" -eq 2 ] && _dm_has "$_dm_out" "NO-BOARDS"; } || cf "(h) a folder with no board renders nothing in silence (exit $_dm_rc): $_dm_out"
  _dm_py "$m/render.py" "$d/no-such-folder" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome"
  { [ "$_dm_rc" -eq 2 ] && _dm_has "$_dm_out" "NO-SUCH-PROJECT"; } || cf "(h) a folder that is not there is not named (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_py "$m/render.py" "$d/project" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome" --props 'not json'
  { [ "$_dm_rc" -eq 2 ] && _dm_has "$_dm_out" "BAD-PROPS"; } || cf "(h) --props that is not JSON renders OK with the props unapplied (exit $_dm_rc): $_dm_out"
  _dm_py "$m/render.py" --help
  { _dm_has "$_dm_out" "NO-SUCH-BOARD" && _dm_has "$_dm_out" "RUNTIME-DID-NOT-RUN" && _dm_has "$_dm_out" "BAD-PROPS"; } || cf "(h) the help's exit codes omit a refusal the tool makes"
  # (i) a sheet linked with an unquoted or a root-relative href answers the theme, so the board is not said to draw brand
  for want in 'href=themed.css' 'href="/themed.css"'; do
    rm -rf "$d/p2"; cp -R "$d/project" "$d/p2"
    _dm_edit "$d/p2/Timer.dc.html" "s|href=\"sheets/tokens.css\"|$want|"
    _dm_py "$m/render.py" "$d/p2" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome" --theme wire --only Timer.dc.html
    { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "NO-THEME-RULE"; } || cf "(i) a sheet linked as $want is not followed: the board is said to draw as the brand version (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  done
  # (j) a board with its own :root of properties that also links the themed sheet is told it keeps its own values
  rm -rf "$d/p3"; cp -R "$d/project" "$d/p3"
  _dm_edit "$d/p3/Timer.dc.html" 's|^body{margin:0}$|:root{--color-surface:#faf8f3}body{margin:0}|; s|href="sheets/tokens.css"|href="themed.css"|'
  _dm_py "$m/render.py" "$d/p3" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome" --theme wire --only Timer.dc.html
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "own :root"; } || cf "(j) a board that keeps its own :root under a themed sheet is not told so (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  # (k) a board whose name holds a percent sequence is the board it is, not the one the sequence decodes to
  rm -rf "$d/p4"; cp -R "$d/project" "$d/p4"; cp "$d/p4/Timer.dc.html" "$d/p4/x%41y.dc.html"
  _dm_py "$m/render.py" "$d/p4" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome" --only 'x%41y.dc.html'
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "OK" && ! _dm_has "$_dm_out" "RUNTIME-DID-NOT-RUN"; } || cf "(k) a board named x%41y is a FAIL as if the runtime had not run (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  # (l) what the run should refuse is refused with its code: a wait that hangs Chrome, a canvas.json that is not one, a runtime that is not text, a $CHROME that is not there
  _dm_py "$m/render.py" "$d/project" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome" --wait 1
  { [ "$_dm_rc" -eq 2 ] && _dm_has "$_dm_out" "BAD-WAIT"; } || cf "(l) --wait 1 is not refused (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  printf '{"boards": [' > "$d/p4/canvas.json"
  _dm_py "$m/render.py" "$d/p4" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome"
  { [ "$_dm_rc" -eq 2 ] && _dm_has "$_dm_out" "BAD-CANVAS" && ! _dm_has "$_dm_out" "Traceback"; } || cf "(l) a canvas.json that is not JSON is a traceback or is not refused (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  printf '\377\376\000\200' > "$d/rt-bin.js"
  _dm_py "$m/render.py" "$d/project" "$d/out" --runtime "$d/rt-bin.js" --chrome "$d/chrome"
  { [ "$_dm_rc" -eq 3 ] && _dm_has "$_dm_out" "BAD-RUNTIME" && ! _dm_has "$_dm_out" "Traceback"; } || cf "(l) a runtime that is not text is a traceback or is not refused (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  CHROME="$d/no-such-chrome-env" _dm_py "$m/render.py" "$d/project" "$d/out" --runtime "$d/rt.js"
  { [ "$_dm_rc" -eq 3 ] && _dm_has "$_dm_out" "CHROME-ABSENT" && _dm_has "$_dm_out" '$CHROME'; } || cf "(l) a \$CHROME that is not there is replaced by another Chrome (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  # (m) an OK line carries what the page did: a file it asked for that the project lacks, and what the runtime logged
  rm -rf "$d/p5"; cp -R "$d/project" "$d/p5"; cp "$d/p5/Timer.dc.html" "$d/p5/Gone.dc.html"; cp "$d/p5/Timer.dc.html" "$d/p5/Logs.dc.html"; cp "$d/p5/Timer.dc.html" "$d/p5/Quiet.dc.html"
  _dm_py "$m/render.py" "$d/p5" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome" --only Gone.dc.html
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "OK" && _dm_has "$_dm_out" "NOTE-404" && _dm_has "$_dm_out" "/gone.css"; } || cf "(m) a file the page asked for and the project lacks is not a NOTE-404 on an OK line (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_py "$m/render.py" "$d/p5" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome" --only Logs.dc.html
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "OK" && _dm_has "$_dm_out" "NOTE-LOGIC" && _dm_has "$_dm_out" "boom"; } || cf "(m) an error the runtime logged is not a NOTE-LOGIC on an OK line (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_py "$m/render.py" "$d/p5" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome" --only Quiet.dc.html
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "OK" && ! _dm_has "$_dm_out" "NOTE-"; } || cf "(m) a board whose runtime only warned (a console line, no console.error) carries a note (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_py "$m/render.py" "$d/p5" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome" --only Timer.dc.html
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "NOTE-"; } || cf "(m) a healthy board carries a note (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  # (n) a board whose content is taller than its canvas size is said, so a leg that cannot view the PNG still sees the cut-off; one that fits, or reports no height, is not
  cp "$d/p5/Timer.dc.html" "$d/p5/Tall.dc.html"; cp "$d/p5/Timer.dc.html" "$d/p5/Fits.dc.html"
  _dm_py "$m/render.py" "$d/p5" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome" --only Tall.dc.html
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "OVERFLOW Tall.dc.html 1200px > 844px"; } || cf "(n) a board whose content is 1200px under a 844px size is not said to OVERFLOW (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_py "$m/render.py" "$d/p5" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome" --only Fits.dc.html
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "OVERFLOW"; } || cf "(n) a board whose content fits is said to OVERFLOW (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_py "$m/render.py" "$d/p5" "$d/out" --runtime "$d/rt.js" --chrome "$d/chrome" --only Timer.dc.html
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "OVERFLOW"; } || cf "(n) a board that reported no height is said to OVERFLOW (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_py "$m/render.py" --help
  _dm_has "$_dm_out" "OVERFLOW" || cf "(n) the help does not say what OVERFLOW means"
  # (o) the Designer role says what OVERFLOW means and that heights are unverified until rendered, and where a board generator is committed
  local role="$m/../../_claude/roles/designer.md"
  { grep -F 'OVERFLOW' "$role" >/dev/null && grep -iF 'until rendered' "$role" >/dev/null; } || cf "(o) designer.md does not say what OVERFLOW means and that a height is unverified until rendered"
  grep -F 'requirements/design/<canvas>/tools/' "$role" >/dev/null || cf "(o) designer.md does not say a script that writes boards is committed under requirements/design/<canvas>/tools/"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — RENDER.PY DRAWS THE PULLED BOARDS IN REAL CHROME: THE SCHEME THE RIGHT WAY ROUND, A THEME WHERE A SHEET ANSWERS IT, AND A SAY WHERE NONE DOES.
#   Operand: scripts/design/render.py with the Chrome on this machine and a saved copy of the design runtime (the module cannot ship one;
#   $KIT_TEST_DC_RUNTIME, a path to a dc-runtime.js; without it the case skips by name), over a board and sheet that a live canvas held whose sheet follows
#   prefers-color-scheme, and over the three boards of another, whose first sheet has [data-theme] blocks and whose others have none.
#   Skipped by name where there is no Chrome or no runtime. The stand-in Chrome of the case above cannot see a flag the wrong way round.
# =============================================================================
case_render_py_draws_the_pulled_boards_in_real_chrome_with_the_scheme_and_the_theme_that_were_asked_for() {
  cf_reset
  local L="render.py in real Chrome draws the pulled plant board with its ground #f7fbf0 by default and #10150f with --scheme dark, draws the pulled settings board wire (#f9f9f9) under --theme wire, says NO-THEME-RULE for the boards no sheet answers (they stay #faf8f3), refuses an unknown theme, fails a board drawn with a runtime that is cut short, empty or another file, and puts NOTE-LOGIC and NOTE-404 on the OK line of a board whose logic throws or whose sheet is missing"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  # tmo: seconds Chrome may take per board, set once for every render below. render.py's own default (90) is for an adopter's single draw; a loaded machine runs several harnesses at once.
  local c rt="${KIT_TEST_DC_RUNTIME:-}" chrome="" tmo="${KIT_TEST_DC_TIMEOUT:-300}"
  for c in google-chrome chromium chromium-browser chrome; do command -v "$c" >/dev/null 2>&1 && { chrome="$(command -v "$c")"; break; }; done
  [ -n "$chrome" ] || { [ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ] && chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; }
  [ -n "$chrome" ] || { skp "$L" "no Chrome or Chromium on this machine"; return; }
  [ -n "$rt" ] && [ -f "$rt" ] || { skp "$L" "no design runtime (set KIT_TEST_DC_RUNTIME to the path of a dc-runtime.js)"; return; }
  _md_sandbox
  local m="$REAL_REPO_ROOT/modules/design/scripts/design" d="$SB_TMP/rc" b
  mkdir -p "$d/plant/ds/plant" "$d/steep/sheets" "$d/steep/ds/steep" "$d/o1" "$d/o2" "$d/o3" "$d/o4"
  cat > "$d/pngpix.py" <<'PYEOF'
import sys, zlib, struct


def pix(path, x, y):
    d = open(path, 'rb').read()
    assert d[:8] == b'\x89PNG\r\n\x1a\n'
    pos, idat, w = 8, b'', 0
    bpp = 4
    while pos < len(d):
        n, t = struct.unpack('>I4s', d[pos:pos + 8])
        body = d[pos + 8:pos + 8 + n]
        if t == b'IHDR':
            w, h, depth, ctype = struct.unpack('>IIBB', body[:10])
            bpp = {2: 3, 6: 4}[ctype]
        elif t == b'IDAT':
            idat += body
        pos += 12 + n
    raw = zlib.decompress(idat)
    stride = w * bpp
    prev = bytearray(stride)
    for row in range(y + 1):
        f = raw[row * (stride + 1)]
        cur = bytearray(raw[row * (stride + 1) + 1:(row + 1) * (stride + 1)])
        for i in range(stride):
            a = cur[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if f == 1:
                cur[i] = (cur[i] + a) & 255
            elif f == 2:
                cur[i] = (cur[i] + b) & 255
            elif f == 3:
                cur[i] = (cur[i] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                cur[i] = (cur[i] + pr) & 255
        prev = cur
    return '#%02x%02x%02x' % tuple(prev[x * bpp:x * bpp + 3])


if __name__ == '__main__':
    print(pix(sys.argv[1], int(sys.argv[2]), int(sys.argv[3])))
PYEOF
  cat > "$d/plant/Plant.dc.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Plant watering</title>
<script src="./support.js"></script>
<link rel="stylesheet" href="ds/plant/tokens.css">
</head>
<body>
<x-dc>
<helmet>
<style>
body{margin:0}
</style>
</helmet>
<div id="ux-002-root" data-ux="UX-002" data-stories="PRD-001-F1-S2" style="width: 390px; height: 844px; box-sizing: border-box; padding: var(--plant-space-24) var(--plant-space-16); display: flex; flex-direction: column; gap: var(--plant-space-16); background: var(--plant-surface); color: var(--plant-on-surface); font-family: var(--plant-font-plain)">
<h1 id="ux-002-name" style="margin: 0; font-size: var(--plant-type-headline-small-size); line-height: var(--plant-type-headline-small-line-height); font-weight: var(--plant-type-headline-small-weight)">Boston fern</h1>
<sc-if value="{{isDue}}" hint-placeholder-val="{{ true }}">
<div id="ux-002-due" data-state="due" style="display: flex; flex-direction: column; gap: var(--plant-space-16)">
<p id="ux-002-status" style="margin: 0; font-size: var(--plant-type-body-large-size); color: var(--plant-on-surface-variant)">2 days overdue</p>
<button id="ux-002-mark" type="button" style="height: var(--plant-space-48); border: 0; border-radius: var(--plant-corner-full); background: var(--plant-primary); color: var(--plant-on-primary); font-size: var(--plant-type-label-large-size); font-weight: var(--plant-type-label-large-weight); font-family: inherit">Mark watered</button>
</div>
</sc-if>
<sc-if value="{{isWatered}}" hint-placeholder-val="{{ false }}">
<div id="ux-002-watered" data-state="watered" style="display: flex; flex-direction: column; gap: var(--plant-space-16); opacity: 0.6">
<p id="ux-002-done" style="margin: 0; padding: var(--plant-space-16); border-radius: var(--plant-corner-large); background: var(--plant-secondary-container); color: var(--plant-on-secondary-container); font-size: var(--plant-type-title-medium-size)">Watered</p>
</div>
</sc-if>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"view":{"editor":"enum","default":"due","options":["due","watered"]},"$preview":{"width":390,"height":844}}'>
class Component extends DCLogic {
renderVals() {
const v = this.props.view ?? 'due';
return { isDue: v === 'due', isWatered: v === 'watered' };
}
}
</script>
</body>
</html>
EOF
  cat > "$d/plant/ds/plant/tokens.css" <<'EOF'
/* Plant — generated from tokens.json */

:root {
  color-scheme: light;
  --plant-background: #f7fbf0;
  --plant-on-background: #181d17;
  --plant-surface: #f7fbf0;
  --plant-surface-dim: #d7dbd2;
  --plant-surface-bright: #f7fbf0;
  --plant-surface-container-lowest: #ffffff;
  --plant-surface-container-low: #f1f5eb;
  --plant-surface-container: #ebefe5;
  --plant-surface-container-high: #e5eadf;
  --plant-surface-container-highest: #e0e4da;
  --plant-on-surface: #181d17;
  --plant-surface-variant: #dbe6d5;
  --plant-on-surface-variant: #40493d;
  --plant-outline: #707a6c;
  --plant-outline-variant: #bfcaba;
  --plant-inverse-surface: #2d322b;
  --plant-inverse-on-surface: #eef2e8;
  --plant-shadow: #000000;
  --plant-scrim: #000000;
  --plant-surface-tint: #1b6d24;
  --plant-primary: #0d631b;
  --plant-on-primary: #ffffff;
  --plant-primary-container: #2e7d32;
  --plant-on-primary-container: #cbffc2;
  --plant-inverse-primary: #88d982;
  --plant-primary-fixed: #a3f69c;
  --plant-primary-fixed-dim: #88d982;
  --plant-on-primary-fixed: #002204;
  --plant-on-primary-fixed-variant: #005312;
  --plant-secondary: #476644;
  --plant-on-secondary: #ffffff;
  --plant-secondary-container: #c6e9be;
  --plant-on-secondary-container: #4c6a48;
  --plant-secondary-fixed: #c9ecc1;
  --plant-secondary-fixed-dim: #add0a6;
  --plant-on-secondary-fixed: #052106;
  --plant-on-secondary-fixed-variant: #304e2e;
  --plant-tertiary: #923357;
  --plant-on-tertiary: #ffffff;
  --plant-tertiary-container: #b14b6f;
  --plant-on-tertiary-container: #ffedf0;
  --plant-tertiary-fixed: #ffd9e2;
  --plant-tertiary-fixed-dim: #ffb1c7;
  --plant-on-tertiary-fixed: #3f001c;
  --plant-on-tertiary-fixed-variant: #7f2448;
  --plant-error: #ba1a1a;
  --plant-on-error: #ffffff;
  --plant-error-container: #ffdad6;
  --plant-on-error-container: #93000a;
  --plant-space-0: 0px;
  --plant-space-2: 2px;
  --plant-space-4: 4px;
  --plant-space-8: 8px;
  --plant-space-12: 12px;
  --plant-space-16: 16px;
  --plant-space-20: 20px;
  --plant-space-24: 24px;
  --plant-space-32: 32px;
  --plant-space-40: 40px;
  --plant-space-48: 48px;
  --plant-space-56: 56px;
  --plant-space-64: 64px;
  --plant-corner-extra-large: 28px;
  --plant-corner-extra-small: 4px;
  --plant-corner-full: 9999px;
  --plant-corner-large: 16px;
  --plant-corner-medium: 12px;
  --plant-corner-none: 0px;
  --plant-corner-small: 8px;
  --plant-level0: 0px;
  --plant-level1: 1px;
  --plant-level2: 3px;
  --plant-level3: 6px;
  --plant-level4: 8px;
  --plant-level5: 12px;
  --plant-font-brand: Roboto, sans-serif;
  --plant-font-plain: Roboto, sans-serif;
  --plant-weight-regular: 400;
  --plant-weight-medium: 500;
  --plant-weight-bold: 700;
  --plant-type-body-large-size: 16px;
  --plant-type-body-large-line-height: 24px;
  --plant-type-body-large-weight: 400;
  --plant-type-body-large-letter-spacing: 0.5px;
  --plant-type-body-medium-size: 14px;
  --plant-type-body-medium-line-height: 20px;
  --plant-type-body-medium-weight: 400;
  --plant-type-body-medium-letter-spacing: 0.25px;
  --plant-type-body-small-size: 12px;
  --plant-type-body-small-line-height: 16px;
  --plant-type-body-small-weight: 400;
  --plant-type-body-small-letter-spacing: 0.4px;
  --plant-type-display-large-size: 57px;
  --plant-type-display-large-line-height: 64px;
  --plant-type-display-large-weight: 400;
  --plant-type-display-large-letter-spacing: -0.25px;
  --plant-type-display-medium-size: 45px;
  --plant-type-display-medium-line-height: 52px;
  --plant-type-display-medium-weight: 400;
  --plant-type-display-medium-letter-spacing: 0px;
  --plant-type-display-small-size: 36px;
  --plant-type-display-small-line-height: 44px;
  --plant-type-display-small-weight: 400;
  --plant-type-display-small-letter-spacing: 0px;
  --plant-type-headline-large-size: 32px;
  --plant-type-headline-large-line-height: 40px;
  --plant-type-headline-large-weight: 400;
  --plant-type-headline-large-letter-spacing: 0px;
  --plant-type-headline-medium-size: 28px;
  --plant-type-headline-medium-line-height: 36px;
  --plant-type-headline-medium-weight: 400;
  --plant-type-headline-medium-letter-spacing: 0px;
  --plant-type-headline-small-size: 24px;
  --plant-type-headline-small-line-height: 32px;
  --plant-type-headline-small-weight: 400;
  --plant-type-headline-small-letter-spacing: 0px;
  --plant-type-label-large-size: 14px;
  --plant-type-label-large-line-height: 20px;
  --plant-type-label-large-weight: 500;
  --plant-type-label-large-letter-spacing: 0.1px;
  --plant-type-label-medium-size: 12px;
  --plant-type-label-medium-line-height: 16px;
  --plant-type-label-medium-weight: 500;
  --plant-type-label-medium-letter-spacing: 0.5px;
  --plant-type-label-small-size: 11px;
  --plant-type-label-small-line-height: 16px;
  --plant-type-label-small-weight: 500;
  --plant-type-label-small-letter-spacing: 0.5px;
  --plant-type-title-large-size: 22px;
  --plant-type-title-large-line-height: 28px;
  --plant-type-title-large-weight: 400;
  --plant-type-title-large-letter-spacing: 0px;
  --plant-type-title-medium-size: 16px;
  --plant-type-title-medium-line-height: 24px;
  --plant-type-title-medium-weight: 500;
  --plant-type-title-medium-letter-spacing: 0.15px;
  --plant-type-title-small-size: 14px;
  --plant-type-title-small-line-height: 20px;
  --plant-type-title-small-weight: 500;
  --plant-type-title-small-letter-spacing: 0.1px;
}

[data-theme="dark"] {
  color-scheme: dark;
  --plant-background: #10150f;
  --plant-on-background: #e0e4da;
  --plant-surface: #10150f;
  --plant-surface-dim: #10150f;
  --plant-surface-bright: #363b34;
  --plant-surface-container-lowest: #0b0f0a;
  --plant-surface-container-low: #181d17;
  --plant-surface-container: #1c211b;
  --plant-surface-container-high: #262b25;
  --plant-surface-container-highest: #31362f;
  --plant-on-surface: #e0e4da;
  --plant-surface-variant: #40493d;
  --plant-on-surface-variant: #bfcaba;
  --plant-outline: #8a9485;
  --plant-outline-variant: #40493d;
  --plant-inverse-surface: #e0e4da;
  --plant-inverse-on-surface: #2d322b;
  --plant-surface-tint: #88d982;
  --plant-primary: #88d982;
  --plant-on-primary: #003909;
  --plant-inverse-primary: #1b6d24;
  --plant-secondary: #add0a6;
  --plant-on-secondary: #1a3719;
  --plant-secondary-container: #304e2e;
  --plant-on-secondary-container: #9cbe95;
  --plant-tertiary: #ffb1c7;
  --plant-on-tertiary: #610931;
  --plant-error: #ffb4ab;
  --plant-on-error: #690005;
  --plant-error-container: #93000a;
  --plant-on-error-container: #ffdad6;
}

[data-theme="wire"] {
  color-scheme: light;
  --plant-background: #f9f9f9;
  --plant-on-background: #1c1c1c;
  --plant-surface: #f9f9f9;
  --plant-surface-dim: #dadada;
  --plant-surface-bright: #f9f9f9;
  --plant-surface-container-low: #f3f3f3;
  --plant-surface-container: #ededed;
  --plant-surface-container-high: #e8e8e8;
  --plant-surface-container-highest: #e2e2e2;
  --plant-on-surface: #1c1c1c;
  --plant-surface-variant: #e3e3e3;
  --plant-on-surface-variant: #464646;
  --plant-outline: #777777;
  --plant-outline-variant: #c7c7c7;
  --plant-inverse-surface: #313131;
  --plant-inverse-on-surface: #f0f0f0;
  --plant-surface-tint: #5e5e5e;
  --plant-primary: #555555;
  --plant-primary-container: #6e6e6e;
  --plant-on-primary-container: #f1f1f1;
  --plant-inverse-primary: #c6c6c6;
  --plant-primary-fixed: #e2e2e2;
  --plant-primary-fixed-dim: #c6c6c6;
  --plant-on-primary-fixed: #1c1c1c;
  --plant-on-primary-fixed-variant: #474747;
  --plant-secondary: #5e5e5e;
  --plant-secondary-container: #dfdfdf;
  --plant-on-secondary-container: #626262;
  --plant-secondary-fixed: #e2e2e2;
  --plant-secondary-fixed-dim: #c6c6c6;
  --plant-on-secondary-fixed: #1c1c1c;
  --plant-on-secondary-fixed-variant: #474747;
  --plant-tertiary: #555555;
  --plant-tertiary-container: #6e6e6e;
  --plant-on-tertiary-container: #f1f1f1;
  --plant-tertiary-fixed: #e2e2e2;
  --plant-tertiary-fixed-dim: #c7c7c7;
  --plant-on-tertiary-fixed: #1c1c1c;
  --plant-on-tertiary-fixed-variant: #474747;
  --plant-error: #5e5e5e;
  --plant-error-container: #e2e2e2;
  --plant-on-error-container: #474747;
}

@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]):not([data-theme="wire"]) {
    color-scheme: dark;
    --plant-background: #10150f;
    --plant-on-background: #e0e4da;
    --plant-surface: #10150f;
    --plant-surface-dim: #10150f;
    --plant-surface-bright: #363b34;
    --plant-surface-container-lowest: #0b0f0a;
    --plant-surface-container-low: #181d17;
    --plant-surface-container: #1c211b;
    --plant-surface-container-high: #262b25;
    --plant-surface-container-highest: #31362f;
    --plant-on-surface: #e0e4da;
    --plant-surface-variant: #40493d;
    --plant-on-surface-variant: #bfcaba;
    --plant-outline: #8a9485;
    --plant-outline-variant: #40493d;
    --plant-inverse-surface: #e0e4da;
    --plant-inverse-on-surface: #2d322b;
    --plant-surface-tint: #88d982;
    --plant-primary: #88d982;
    --plant-on-primary: #003909;
    --plant-inverse-primary: #1b6d24;
    --plant-secondary: #add0a6;
    --plant-on-secondary: #1a3719;
    --plant-secondary-container: #304e2e;
    --plant-on-secondary-container: #9cbe95;
    --plant-tertiary: #ffb1c7;
    --plant-on-tertiary: #610931;
    --plant-error: #ffb4ab;
    --plant-on-error: #690005;
    --plant-error-container: #93000a;
    --plant-on-error-container: #ffdad6;
  }
}
EOF
  cat > "$d/plant/canvas.json" <<'EOF'
{
  "boards": {
    "Main.dc.html": {
      "h": 844,
      "is_interactive": false,
      "title": "UX-001 Today (phone)",
      "w": 390,
      "x": 0,
      "y": 0
    },
    "Plant.dc.html": {
      "h": 844,
      "is_interactive": false,
      "title": "UX-002 Plant (phone)",
      "w": 390,
      "x": 480,
      "y": 0
    }
  },
  "createdOnFiles": {
    "at": "2026-10-24T09:00:00Z",
    "v": 1
  },
  "launch": {
    "view": "canvas"
  },
  "notes": {},
  "order": [
    "Main.dc.html",
    "Plant.dc.html"
  ],
  "pages": [],
  "title": "Plant",
  "v": 3
}
EOF
  cat > "$d/steep/Main.dc.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Brews</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<style>
body{margin:0}
:root{
  --color-surface: #FAF8F3;
  --color-surface-raised: #FFFFFF;
  --color-on-surface: #1F2421;
  --color-muted: #4A5553;
  --color-primary: #22577A;
  --color-on-primary: #FFFFFF;
}
</style>
</helmet>
<div id="ux-001-root" data-ux="UX-001" data-stories="PRD-001-F1-S1" style="width: 390px; height: 844px; box-sizing: border-box; padding: 24px 16px; display: flex; flex-direction: column; gap: 16px; background: var(--color-surface); color: var(--color-on-surface); font-family: system-ui, sans-serif">
<h1 id="ux-001-title" style="margin: 0; font-size: 24px; line-height: 32px; font-weight: 600">Brews</h1>
<sc-if value="{{isList}}" hint-placeholder-val="{{ true }}">
<div id="ux-001-list" data-state="list" style="display: flex; flex-direction: column; gap: 12px">
<a id="ux-001-open-sencha" href="Timer.dc.html" style="display: flex; align-items: center; justify-content: space-between; min-height: 56px; padding: 0 16px; border-radius: 12px; background: var(--color-surface-raised); color: var(--color-on-surface); text-decoration: none">
<span id="ux-001-name-sencha" style="font-size: 16px; font-weight: 500">Sencha</span>
<span id="ux-001-time-sencha" style="font-size: 14px; color: var(--color-muted)">2 min</span>
</a>
<div id="ux-001-preview" style="width: 156px; height: 338px; overflow: hidden; border-radius: 12px">
<div style="width: 390px; height: 844px; transform: scale(0.4); transform-origin: top left">
<dc-import name="Timer" view="idle" hint-size="390px,844px"></dc-import>
</div>
</div>
</div>
</sc-if>
<sc-if value="{{isEmpty}}" hint-placeholder-val="{{ false }}">
<div id="ux-001-empty" data-state="empty" style="padding: 24px; border-radius: 12px; background: var(--color-surface-raised); color: var(--color-muted); font-size: 16px">
<p id="ux-001-empty-text" style="margin: 0">No brews yet</p>
</div>
</sc-if>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"view":{"editor":"enum","default":"list","options":["list","empty"]},"$preview":{"width":390,"height":844}}'>
class Component extends DCLogic {
renderVals() {
const v = this.props.view ?? 'list';
return { isList: v === 'list', isEmpty: v === 'empty' };
}
}
</script>
</body>
</html>
EOF
  cat > "$d/steep/Timer.dc.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Timer</title>
<script src="./support.js"></script>
<link rel="stylesheet" href="sheets/tokens.css">
</head>
<body>
<x-dc>
<helmet>
<style>
body{margin:0}
</style>
</helmet>
<div id="ux-002-root" data-ux="UX-002" data-stories="PRD-001-F1-S2" class="ux-screen" style="width: 390px; height: 844px; box-sizing: border-box; padding: 24px 16px; display: flex; flex-direction: column; gap: 16px; background: var(--color-surface); color: var(--color-on-surface); font-family: system-ui, sans-serif">
<h1 id="ux-002-title" style="margin: 0; font-size: 24px; line-height: 32px; font-weight: 600">Sencha</h1>
<sc-if value="{{isIdle}}" hint-placeholder-val="{{ true }}">
<div id="ux-002-idle" data-state="idle" style="display: flex; flex-direction: column; gap: 16px">
<p id="ux-002-remaining" style="margin: 0; font-size: 48px; line-height: 56px; font-weight: 300">2:00</p>
<button id="ux-002-start" type="button" style="height: 48px; border: 0; border-radius: 24px; background: var(--color-primary); color: var(--color-on-primary); font-size: 16px; font-weight: 500; font-family: inherit">Start</button>
</div>
</sc-if>
<sc-if value="{{isDone}}" hint-placeholder-val="{{ false }}">
<div id="ux-002-done" data-state="done" style="display: flex; flex-direction: column; gap: 16px">
<p id="ux-002-ready" style="margin: 0; font-size: 24px; line-height: 32px">Ready to pour</p>
<a id="ux-002-back" href="Main.dc.html" style="display: flex; align-items: center; justify-content: center; height: 48px; border-radius: 24px; background: var(--color-primary); color: var(--color-on-primary); text-decoration: none; font-size: 16px; font-weight: 500">Back to brews</a>
</div>
</sc-if>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"view":{"editor":"enum","default":"idle","options":["idle","done"]},"$preview":{"width":390,"height":844}}'>
class Component extends DCLogic {
renderVals() {
const v = this.props.view ?? 'idle';
return { isIdle: v === 'idle', isDone: v === 'done' };
}
}
</script>
</body>
</html>
EOF
  cat > "$d/steep/Settings.dc.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Settings</title>
<script src="./support.js"></script>
<link rel="stylesheet" href="ds/steep/tokens.css">
</head>
<body>
<x-dc>
<helmet>
<style>
body{margin:0}
</style>
</helmet>
<div id="ux-003-root" data-ux="UX-003" data-stories="PRD-001-F2-S1" style="width: 390px; height: 844px; box-sizing: border-box; padding: var(--space-6) var(--space-4); display: flex; flex-direction: column; gap: var(--space-4); background: var(--color-surface); color: var(--color-on-surface); font-family: var(--font-sans)">
<h1 id="ux-003-title" style="margin: 0; font-size: 24px; line-height: 32px; font-weight: 600">Settings</h1>
<div id="ux-003-sound" data-state="default" style="padding: var(--space-4); border-radius: var(--radius-md); background: var(--color-surface-raised); color: var(--color-muted); font-size: 16px">Sound on finish</div>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"$preview":{"width":390,"height":844}}'>
class Component extends DCLogic {
renderVals() { return {}; }
}
</script>
</body>
</html>
EOF
  cat > "$d/steep/sheets/tokens.css" <<'EOF'
/* Steep tokens, for a screen that may be imported: a child's helmet takes no :root rule. */
:root {
  --color-surface: #FAF8F3;
  --color-surface-raised: #FFFFFF;
  --color-on-surface: #1F2421;
  --color-muted: #4A5553;
  --color-primary: #22577A;
  --color-on-primary: #FFFFFF;
}
.ux-screen { letter-spacing: 0.1px; }
EOF
  cat > "$d/steep/ds/steep/tokens.css" <<'EOF'
/* Steep tokens — generated from tokens.json */

:root, [data-theme="light"] {
  --color-surface: #FAF8F3;
  --color-surface-raised: #FFFFFF;
  --color-on-surface: #1F2421;
  --color-muted: #4A5553;
  --color-primary: #22577A;
  --color-on-primary: #FFFFFF;
}

[data-theme="dark"] {
  --color-surface: #141816;
  --color-surface-raised: #1F2421;
  --color-on-surface: #F0EEE8;
  --color-muted: #B8C2BF;
  --color-primary: #8FC4E8;
  --color-on-primary: #0B2433;
}

[data-theme="wire"] {
  --color-surface: #F9F9F9;
  --color-surface-raised: #FFFFFF;
  --color-on-surface: #1C1C1C;
  --color-muted: #464646;
  --color-primary: #555555;
  --color-on-primary: #FFFFFF;
}

:root {
  --space-2: 8px;
  --space-4: 16px;
  --space-6: 24px;
  --radius-md: 12px;
  --radius-full: 24px;
  --font-sans: system-ui, sans-serif;
}
EOF
  cat > "$d/steep/canvas.json" <<'EOF'
{"v":3,"createdOnFiles":{"v":1,"at":"2026-11-01T04:30:00Z"},"title":"Brews","launch":{"view":"canvas"},"pages":[],"boards":{"Main.dc.html":{"x":0,"y":0,"w":390,"h":844,"title":"UX-001 Brews (phone)","is_interactive":true},"Timer.dc.html":{"x":470,"y":0,"w":390,"h":844,"title":"UX-002 Timer (phone)"},"Settings.dc.html":{"x":940,"y":0,"w":390,"h":844,"title":"UX-003 Settings (phone)"}},"order":["Main.dc.html","Timer.dc.html","Settings.dc.html"],"notes":{"note-brief":{"x":0,"y":-200,"w":320,"text":"Authored from a brief."}},"designSystems":[]}
EOF
  pix() { python3 "$d/pngpix.py" "$1" 5 5; }
  _dm_py "$m/render.py" "$d/plant" "$d/o1" --runtime "$rt" --timeout "$tmo" --only Plant.dc.html
  { [ "$_dm_rc" -eq 0 ] && [ "$(pix "$d/o1/Plant.png")" = "#f7fbf0" ]; } || cf "(a) the default scheme does not draw the plant board's light ground #f7fbf0 (exit $_dm_rc, got $(pix "$d/o1/Plant.png" 2>/dev/null)): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_py "$m/render.py" "$d/plant" "$d/o2" --runtime "$rt" --timeout "$tmo" --only Plant.dc.html --scheme dark
  { [ "$_dm_rc" -eq 0 ] && [ "$(pix "$d/o2/Plant.png" 2>/dev/null)" = "#10150f" ]; } || cf "(b) --scheme dark does not draw the plant board's dark ground #10150f (got $(pix "$d/o2/Plant.png" 2>/dev/null); $(_dm_why))"
  _dm_py "$m/render.py" "$d/steep" "$d/o3" --runtime "$rt" --timeout "$tmo" --theme wire
  [ "$_dm_rc" -eq 0 ] || cf "(c) --theme wire on the steep boards failed (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  [ "$(pix "$d/o3/Settings.png" 2>/dev/null)" = "#f9f9f9" ] || cf "(c) the settings board, which links the themed sheet, is not drawn wire (#f9f9f9): got $(pix "$d/o3/Settings.png" 2>/dev/null); $(_dm_why)"
  for b in Main Timer; do
    [ "$(pix "$d/o3/$b.png" 2>/dev/null)" = "#faf8f3" ] || cf "(c) the $b board, which no sheet answers wire for, is not the brand ground #faf8f3: got $(pix "$d/o3/$b.png" 2>/dev/null); $(_dm_why)"
    printf '%s\n' "$_dm_out" | grep "$b.dc.html" | grep NO-THEME-RULE >/dev/null || cf "(c) $b.dc.html is not said to draw as the brand version"
  done
  _dm_py "$m/render.py" "$d/steep" "$d/o4" --runtime "$rt" --timeout "$tmo" --theme no-such
  { [ "$_dm_rc" -eq 2 ] && _dm_has "$_dm_out" "UNKNOWN-THEME"; } || cf "(d) an unknown theme id is not refused (exit $_dm_rc): $_dm_out"
  # (f) what the runtime logged and what the project lacks are on the line; a healthy board has neither
  rm -rf "$d/p2"; cp -R "$d/plant" "$d/p2"
  sed "s/const v = this.props.view ?? 'due';/throw new Error('boom');/" "$d/plant/Plant.dc.html" > "$d/p2/Throws.dc.html"
  sed 's|ds/plant/tokens.css|ds/plant/gone.css|' "$d/plant/Plant.dc.html" > "$d/p2/Missing.dc.html"
  _dm_py "$m/render.py" "$d/p2" "$d/o6" --runtime "$rt" --timeout "$tmo" --only Plant.dc.html
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "NOTE-"; } || cf "(f) the healthy plant board carries a note (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-250)"
  cat > "$d/p2/Dashboard.dc.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Weekly dashboard</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&amp;display=swap" rel="stylesheet">
<style>
body{margin:0}
a{color:#2F6FEB}a:hover{color:#1F4FB0}
</style>
</helmet>
<div id="ux-003-root" style="min-height: 760px; box-sizing: border-box; display: flex; flex-wrap: wrap; background: #F7F7F5; color: #1C1C1E; font-family: Inter, system-ui, sans-serif">
<nav id="ux-003-sidebar" aria-label="Main" style="flex: 1 1 220px; max-width: 100%; box-sizing: border-box; padding: 28px 20px; display: flex; flex-direction: column; gap: 6px; background: #FFFFFF; border-right: 1px solid #E4E4E8">
<span style="font-size: 20px; font-weight: 700; padding: 0 12px 20px">Tracker</span>
<a href="#" style="padding: 10px 12px; border-radius: 8px; background: #EAF0FD; font-size: 15px; font-weight: 600; text-decoration: none; color: #1F4FB0">Weekly</a>
<a href="#" style="padding: 10px 12px; border-radius: 8px; font-size: 15px; font-weight: 500; text-decoration: none; color: #3A3A44">Habits</a>
<a href="#" style="padding: 10px 12px; border-radius: 8px; font-size: 15px; font-weight: 500; text-decoration: none; color: #3A3A44">Settings</a>
</nav>
<main id="ux-003-main" style="flex: 999 1 560px; min-width: 0; box-sizing: border-box; padding: 32px 40px; display: flex; flex-direction: column; gap: 28px">
<div style="display: flex; flex-wrap: wrap; align-items: flex-end; justify-content: space-between; gap: 16px">
<div style="display: flex; flex-direction: column; gap: 4px">
<h1 id="ux-003-title" style="margin: 0; font-size: 28px; font-weight: 700; letter-spacing: -0.02em">This week</h1>
<span style="font-size: 15px; color: #5B5B66">20 – 26 October</span>
</div>
<div id="ux-003-range" role="group" aria-label="Range" style="display: flex; gap: 4px; padding: 4px; background: #EDEDF0; border-radius: 10px">
<button style="height: 36px; padding: 0 16px; border: none; border-radius: 8px; background: #FFFFFF; font-family: inherit; font-size: 14px; font-weight: 600; color: #1C1C1E">Week</button>
<button style="height: 36px; padding: 0 16px; border: none; border-radius: 8px; background: transparent; font-family: inherit; font-size: 14px; font-weight: 500; color: #3A3A44">Month</button>
<button style="height: 36px; padding: 0 16px; border: none; border-radius: 8px; background: transparent; font-family: inherit; font-size: 14px; font-weight: 500; color: #3A3A44">Quarter</button>
</div>
</div>
<div id="ux-003-stats" style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px">
<div style="padding: 20px; background: #FFFFFF; border: 1px solid #E4E4E8; border-radius: 14px; display: flex; flex-direction: column; gap: 6px"><span style="font-size: 14px; color: #5B5B66">Completed</span><span style="font-size: 30px; font-weight: 700">[N] / [M]</span></div>
<div style="padding: 20px; background: #FFFFFF; border: 1px solid #E4E4E8; border-radius: 14px; display: flex; flex-direction: column; gap: 6px"><span style="font-size: 14px; color: #5B5B66">Longest streak</span><span style="font-size: 30px; font-weight: 700">[N] days</span></div>
<div style="padding: 20px; background: #FFFFFF; border: 1px solid #E4E4E8; border-radius: 14px; display: flex; flex-direction: column; gap: 6px"><span style="font-size: 14px; color: #5B5B66">Best day</span><span style="font-size: 30px; font-weight: 700">[Day]</span></div>
</div>
<div id="ux-003-table-box" style="overflow-x: auto; background: #FFFFFF; border: 1px solid #E4E4E8; border-radius: 14px">
<table id="ux-003-table" style="width: 100%; min-width: 560px; border-collapse: collapse; font-size: 14px">
<thead><tr style="text-align: left; color: #5B5B66"><th style="padding: 14px 20px; font-weight: 500">Habit</th><th style="padding: 14px 8px; font-weight: 500">Mon</th><th style="padding: 14px 8px; font-weight: 500">Tue</th><th style="padding: 14px 8px; font-weight: 500">Wed</th><th style="padding: 14px 8px; font-weight: 500">Thu</th><th style="padding: 14px 8px; font-weight: 500">Fri</th><th style="padding: 14px 8px; font-weight: 500">Sat</th><th style="padding: 14px 8px; font-weight: 500">Sun</th></tr></thead>
<tbody>
<sc-for list="{{rows}}" as="row" hint-placeholder-count="4">
<tr style="border-top: 1px solid #EDEDF0"><td style="padding: 14px 20px; font-weight: 600">{{row.name}}</td>
<sc-for list="{{row.days}}" as="d" hint-placeholder-count="7"><td style="padding: 14px 8px"><span aria-label="{{d.label}}" style="display: inline-block; width: 22px; height: 22px; border-radius: 6px; background: {{d.fill}}"></span></td></sc-for>
</tr>
</sc-for>
</tbody>
</table>
</div>
</main>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"$preview":{"width":1280,"height":760}}'>
class Component extends DCLogic {
renderVals() {
const names = ['Read 10 pages', 'Walk 20 minutes', 'Drink 8 glasses', 'Journal'];
const pattern = [[1,1,1,0,1,1,0],[1,0,1,1,0,1,1],[1,1,1,1,1,1,1],[0,1,0,1,1,0,0]];
const rows = names.map((name, i) => ({
name,
days: pattern[i].map((v) => ({ fill: v ? '#2F6FEB' : '#E4E4E8', label: v ? 'done' : 'missed' }))
}));
return { rows };
}
}
</script>
</body>
</html>
EOF
  _dm_py "$m/render.py" "$d/p2" "$d/o6" --runtime "$rt" --timeout "$tmo" --only Dashboard.dc.html
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "OK" && ! _dm_has "$_dm_out" "NOTE-"; } || cf "(f) the pulled dashboard, whose runtime only warns while its rows resolve, carries a note (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-250)"
  _dm_py "$m/render.py" "$d/p2" "$d/o6" --runtime "$rt" --timeout "$tmo" --only Throws.dc.html
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "NOTE-LOGIC" && _dm_has "$_dm_out" "boom"; } || cf "(f) a board whose logic throws is OK with no word of it (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-250)"
  _dm_py "$m/render.py" "$d/p2" "$d/o6" --runtime "$rt" --timeout "$tmo" --only Missing.dc.html
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "NOTE-404" && _dm_has "$_dm_out" "gone.css"; } || cf "(f) a board linking a sheet the project lacks is OK with no word of it (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-250)"
  # (e) a runtime that is cut short, empty or another file draws a plausible screen without running: it is a FAIL with no PNG
  head -c 100000 "$rt" > "$d/rt-cut.js"; : > "$d/rt-empty.js"; printf 'window.somethingElse = 1;\n' > "$d/rt-other.js"
  for b in rt-cut rt-empty rt-other; do
    rm -rf "$d/o5"
    _dm_py "$m/render.py" "$d/plant" "$d/o5" --runtime "$d/$b.js" --only Plant.dc.html
    { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "RUNTIME-DID-NOT-RUN" && [ ! -e "$d/o5/Plant.png" ]; } || cf "(e) the runtime $b reads OK or leaves a PNG (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  done
  finish "$L"
  teardown
}

# =============================================================================
# CASE — NORMALISE-CANVAS.PY GIVES A PAGE SAVE'S RE-SERIALISING THE SPELLING AN AGENT WRITES, AND SAYS WHAT IT CANNOT READ.
#   Operand: scripts/design/normalise-canvas.py over a pulled canvas whose List board and canvas.json are as a page save left them (data-props
#   in &quot; form; canvas.json sorted with an empty "attachments") beside a Settings board an agent wrote (single-quoted), and over a canvas.json
#   as an agent writes it. The expected answers are fixed here, from the spelling the agent's own file has.
# =============================================================================
case_normalise_canvas_gives_a_page_save_the_spelling_an_agent_writes_and_says_what_it_cannot_read() {
  cf_reset
  local L="normalise-canvas.py rewrites a page-saved board's data-props to the single-quoted compact form an agent writes and nothing else in it, drops an empty attachments from a sorted canvas.json and sorts an agent's, leaves an agent-written board byte for byte, is idempotent, writes nothing under --check (exit 1 when it would), and names a file it cannot parse (UNREAD, exit 2) and leaves it"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _md_sandbox
  local m="$REAL_REPO_ROOT/modules/design/scripts/design" d="$SB_TMP/nc" want n0 n1
  mkdir -p "$d/p"
  cat > "$d/p/List.dc.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Today</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&amp;display=swap" rel="stylesheet">
<style>
body{margin:0}
a{color:#2F6FEB}a:hover{color:#1F4FB0}
</style>
</helmet>
<div id="ux-002-root" style="width: 390px; height: 844px; box-sizing: border-box; display: flex; flex-direction: column; background: #F7F7F5; color: #1C1C1E; font-family: Inter, system-ui, sans-serif">
<header id="ux-002-header" style="padding: 56px 24px 16px; display: flex; align-items: flex-end; justify-content: space-between">
<div style="display: flex; flex-direction: column; gap: 4px">
<span style="font-size: 14px; color: #5B5B66">Friday, 24 October</span>
<h1 id="ux-002-title" style="margin: 0; font-size: 28px; font-weight: 700; letter-spacing: -0.02em">Today</h1>
</div>
<button id="ux-002-add" aria-label="Add a habit" style="width: 44px; height: 44px; border: none; border-radius: 22px; background: #2F6FEB; color: #FFFFFF; display: flex; align-items: center; justify-content: center; cursor: pointer">
<svg aria-hidden="true" width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round"><path d="M10 4v12M4 10h12"></path></svg>
</button>
</header>
<main style="flex-grow: 1; padding: 8px 24px; display: flex; flex-direction: column; gap: 12px; overflow: hidden">
<sc-if value="{{showList}}" hint-placeholder-val="{{ true }}">
<p id="ux-002-progress" style="margin: 0 0 4px; font-size: 14px; color: #5B5B66">{{doneCount}} of {{totalCount}} done</p>
<sc-for list="{{habits}}" as="habit" hint-placeholder-count="4">
<div style="display: flex; align-items: center; gap: 14px; padding: 14px 16px; background: #FFFFFF; border: 1px solid #E4E4E8; border-radius: 14px">
<button onClick="{{habit.toggle}}" aria-label="{{habit.toggleLabel}}" style="width: 28px; height: 28px; flex-shrink: 0; border-radius: 14px; border: 2px solid #2F6FEB; background: {{habit.checkFill}}; display: flex; align-items: center; justify-content: center; cursor: pointer; padding: 0">
<svg aria-hidden="true" width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="#FFFFFF" stroke-width="2.4" stroke-linecap="round"><path d="M3 7.5l2.5 2.5L11 4.5"></path></svg>
</button>
<div style="display: flex; flex-direction: column; gap: 2px; flex-grow: 1; min-width: 0">
<span style="font-size: 16px; font-weight: 600">{{habit.name}}</span>
<span style="font-size: 13px; color: #5B5B66">{{habit.schedule}}</span>
</div>
<span style="font-size: 13px; font-weight: 600; color: #C2410C">{{habit.streak}}</span>
</div>
</sc-for>
</sc-if>
<sc-if value="{{showEmpty}}" hint-placeholder-val="{{ false }}">
<div id="ux-002-empty" style="flex-grow: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 16px; padding: 0 16px; text-align: center">
<svg aria-hidden="true" width="96" height="96" viewBox="0 0 96 96" fill="none" stroke="#9A9AA5" stroke-width="2.5" stroke-linecap="round"><rect x="14" y="14" width="68" height="68" rx="20"></rect><path d="M34 48l10 10 18-20"></path></svg>
<h2 style="margin: 0; font-size: 22px; font-weight: 700">No habits yet</h2>
<p style="margin: 0; font-size: 15px; line-height: 1.5; color: #5B5B66">Start with one small thing you want to do every day.</p>
<a id="ux-002-empty-cta" href="#" style="height: 48px; padding: 0 24px; display: flex; align-items: center; justify-content: center; border-radius: 12px; background: #2F6FEB; color: #FFFFFF; font-size: 16px; font-weight: 600; text-decoration: none">Add your first habit</a>
</div>
</sc-if>
</main>
<nav id="ux-002-tabbar" aria-label="Main" style="height: 84px; box-sizing: border-box; padding: 10px 24px 26px; display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); background: #FFFFFF; border-top: 1px solid #E4E4E8">
<a href="#" style="display: flex; flex-direction: column; align-items: center; gap: 4px; font-size: 12px; font-weight: 600; text-decoration: none; color: #2F6FEB">
<svg aria-hidden="true" width="22" height="22" viewBox="0 0 22 22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="3" y="3" width="16" height="16" rx="5"></rect><path d="M7.5 11l2.5 2.5 4.5-5"></path></svg>Today</a>
<a href="#" style="display: flex; flex-direction: column; align-items: center; gap: 4px; font-size: 12px; font-weight: 500; text-decoration: none; color: #5B5B66">
<svg aria-hidden="true" width="22" height="22" viewBox="0 0 22 22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M4 18V10M11 18V4M18 18v-6"></path></svg>Progress</a>
<a href="Main.dc.html" style="display: flex; flex-direction: column; align-items: center; gap: 4px; font-size: 12px; font-weight: 500; text-decoration: none; color: #5B5B66">
<svg aria-hidden="true" width="22" height="22" viewBox="0 0 22 22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="8" r="4"></circle><path d="M3.5 19c1.5-3.5 4.3-5 7.5-5s6 1.5 7.5 5"></path></svg>Account</a>
</nav>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props="{&quot;variant&quot;:{&quot;editor&quot;:&quot;enum&quot;,&quot;options&quot;:[&quot;loaded&quot;,&quot;empty&quot;],&quot;default&quot;:&quot;empty&quot;},&quot;$preview&quot;:{&quot;width&quot;:390,&quot;height&quot;:844}}">
class Component extends DCLogic {
constructor(props) {
super(props);
this.state = { done: { read: true, walk: false, water: true, journal: false } };
}
renderVals() {
const variant = this.props.variant ?? 'loaded';
const base = [
{ id: 'read', name: 'Read 10 pages', schedule: 'Every day', streak: '12 days' },
{ id: 'walk', name: 'Walk 20 minutes', schedule: 'Every day', streak: '4 days' },
{ id: 'water', name: 'Drink 8 glasses', schedule: 'Every day', streak: '30 days' },
{ id: 'journal', name: 'Journal', schedule: 'Weekdays', streak: '2 days' }
];
const done = this.state.done;
const habits = base.map((h) => ({
...h,
checkFill: done[h.id] ? '#2F6FEB' : '#FFFFFF',
toggleLabel: (done[h.id] ? 'Mark not done: ' : 'Mark done: ') + h.name,
toggle: () => this.setState({ done: { ...done, [h.id]: !done[h.id] } })
}));
const doneCount = base.filter((h) => done[h.id]).length;
return {
habits,
doneCount,
totalCount: base.length,
showList: variant === 'loaded',
showEmpty: variant === 'empty'
};
}
}
</script>
</body>
</html>
EOF
  cat > "$d/p/Settings.dc.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Settings</title>
<script src="./support.js"></script>
<link rel="stylesheet" href="ds/steep/tokens.css">
</head>
<body>
<x-dc>
<helmet>
<style>
body{margin:0}
</style>
</helmet>
<div id="ux-003-root" data-ux="UX-003" data-stories="PRD-001-F2-S1" style="width: 390px; height: 844px; box-sizing: border-box; padding: var(--space-6) var(--space-4); display: flex; flex-direction: column; gap: var(--space-4); background: var(--color-surface); color: var(--color-on-surface); font-family: var(--font-sans)">
<h1 id="ux-003-title" style="margin: 0; font-size: 24px; line-height: 32px; font-weight: 600">Settings</h1>
<div id="ux-003-sound" data-state="default" style="padding: var(--space-4); border-radius: var(--radius-md); background: var(--color-surface-raised); color: var(--color-muted); font-size: 16px">Sound when done</div>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"$preview":{"width":390,"height":844}}'>
class Component extends DCLogic {
renderVals() { return {}; }
}
</script>
</body>
</html>
EOF
  cat > "$d/p/canvas.json" <<'EOF'
{
  "v": 3,
  "attachments": {},
  "boards": {
    "List.dc.html": {
      "h": 844,
      "is_interactive": true,
      "title": "UX-002 Today (phone)",
      "w": 390,
      "x": 617,
      "y": 0
    },
    "Main.dc.html": {
      "h": 844,
      "is_interactive": true,
      "title": "UX-001 Sign in (phone)",
      "w": 390,
      "x": 0,
      "y": 0
    }
  },
  "createdOnFiles": {
    "at": "2026-10-24T09:00:00Z",
    "v": 1
  },
  "designSystems": [],
  "launch": {
    "view": "canvas"
  },
  "notes": {
    "note-brief": {
      "text": "Authored from a brief.",
      "w": 240,
      "x": 1323,
      "y": 983
    }
  },
  "order": [
    "Main.dc.html",
    "List.dc.html"
  ],
  "pages": [],
  "title": "Brews"
}
EOF
  mkdir -p "$d/agent"
  cat > "$d/agent/canvas.json" <<'EOF'
{
  "v": 3,
  "createdOnFiles": {"v": 1, "at": "2026-10-24T09:00:00Z"},
  "title": "Brews",
  "launch": {"view": "canvas"},
  "pages": [],
  "boards": {
    "Main.dc.html": {"x": 0, "y": 0, "w": 390, "h": 844, "title": "UX-001 Sign in (phone)", "is_interactive": true},
    "List.dc.html": {"x": 470, "y": 0, "w": 390, "h": 844, "title": "UX-002 Today (phone)", "is_interactive": true}
  },
  "order": ["Main.dc.html", "List.dc.html"],
  "notes": {"note-brief": {"x": 940, "y": 0, "w": 240, "text": "Authored from a brief."}},
  "designSystems": []
}
EOF
  cp "$d/p/List.dc.html" "$d/List.saved"; cp "$d/p/Settings.dc.html" "$d/Settings.agent"
  want='<script type="text/x-dc" data-dc-script data-props='"'"'{"variant":{"editor":"enum","options":["loaded","empty"],"default":"empty"},"$preview":{"width":390,"height":844}}'"'"'>'
  # (a) --check names what it would change, changes nothing, exits 1
  _dm_py "$m/normalise-canvas.py" "$d/p" --check
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "would normalise List.dc.html" && _dm_has "$_dm_out" "would normalise canvas.json" && ! _dm_has "$_dm_out" "Settings"; } || cf "(a) --check does not name the page-saved board and canvas.json, and only them, with exit 1 (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  cmp -s "$d/p/List.dc.html" "$d/List.saved" || cf "(a) --check wrote the board"
  # (b) the run: the data-props line is the agent's spelling, and it is the only line that moved
  _dm_py "$m/normalise-canvas.py" "$d/p"
  [ "$_dm_rc" -eq 0 ] || cf "(b) the run exited $_dm_rc: $_dm_out"
  grep -Fx -- "$want" "$d/p/List.dc.html" >/dev/null || cf "(b) the data-props line is not the agent's spelling: $(grep -F 'data-props' "$d/p/List.dc.html" | cut -c1-200)"
  n0="$(diff "$d/List.saved" "$d/p/List.dc.html" | grep -c '^<')"; n1="$(diff "$d/List.saved" "$d/p/List.dc.html" | grep -c '^>')"
  { [ "$n0" = 1 ] && [ "$n1" = 1 ]; } || cf "(b) more than the one data-props line changed ($n0 removed, $n1 added)"
  cmp -s "$d/p/Settings.dc.html" "$d/Settings.agent" || cf "(b) an agent-written board was rewritten"
  grep -F '"attachments"' "$d/p/canvas.json" >/dev/null && cf "(b) the empty attachments stayed in canvas.json"
  # (c) idempotent
  _dm_py "$m/normalise-canvas.py" "$d/p"
  { [ "$_dm_rc" -eq 0 ] && [ -z "$_dm_out" ]; } || cf "(c) a second run changed something or said something (exit $_dm_rc): $_dm_out"
  _dm_py "$m/normalise-canvas.py" "$d/p" --check
  [ "$_dm_rc" -eq 0 ] || cf "(c) --check on a normalised canvas exits $_dm_rc"
  # (d) a canvas.json an agent wrote becomes the sorted two-space form, and equals the page-saved one's keys
  _dm_py "$m/normalise-canvas.py" "$d/agent"
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "normalised canvas.json"; } || cf "(d) the agent's canvas.json was not normalised (exit $_dm_rc): $_dm_out"
  python3 - "$d/agent/canvas.json" "$d/p/canvas.json" <<'PYEOF' || cf "(d) the normalised canvas.json is not sorted with a two-space indent and a final newline"
import json, sys
t = open(sys.argv[1], encoding='utf-8').read()
assert t == json.dumps(json.loads(t), indent=2, sort_keys=True, ensure_ascii=False) + '\n'
assert list(json.loads(t)['boards']) == sorted(json.loads(t)['boards'])
PYEOF
  # (d2) the escaping the design type's format rules ask for: & as &amp;, a literal ' as &#39;, nothing else, and the same JSON value
  mkdir -p "$d/esc"
  printf '<x-dc>\n<script type="text/x-dc" data-dc-script data-props="{&quot;label&quot;:{&quot;default&quot;:&quot;Tom &amp; it&#39;s&quot;}}">\n</script>\n</x-dc>\n' > "$d/esc/E.dc.html"
  _dm_py "$m/normalise-canvas.py" "$d/esc"
  grep -F "data-props='{\"label\":{\"default\":\"Tom &amp; it&#39;s\"}}'" "$d/esc/E.dc.html" >/dev/null || cf "(d2) an ampersand and a quote in a default are not escaped as &amp; and &#39; in single quotes: $(grep -F data-props "$d/esc/E.dc.html" | cut -c1-160)"
  # (e) what it cannot parse is named and left alone
  mkdir -p "$d/bad"
  printf '<x-dc>\n<script type="text/x-dc" data-dc-script data-props='"'"'{not json'"'"'>\n</script>\n</x-dc>\n' > "$d/bad/Bad.dc.html"
  printf '[1]\n' > "$d/bad/canvas.json"
  cp "$d/bad/Bad.dc.html" "$d/Bad.before"
  _dm_py "$m/normalise-canvas.py" "$d/bad"
  { [ "$_dm_rc" -eq 2 ] && _dm_has "$_dm_out" "UNREAD" && _dm_has "$_dm_out" "Bad.dc.html" && _dm_has "$_dm_out" "canvas.json"; } || cf "(e) a board and a canvas.json it cannot parse are not named UNREAD with exit 2 (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  cmp -s "$d/bad/Bad.dc.html" "$d/Bad.before" || cf "(e) the unparsable board was rewritten"
  _dm_py "$m/normalise-canvas.py" "$d/no-such-folder"
  [ "$_dm_rc" -eq 2 ] || cf "(e) a folder that is not there exits $_dm_rc, not 2"
  _dm_py "$m/normalise-canvas.py" --help
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "usage:"; } || cf "(e) --help exits $_dm_rc, not 0, or prints no usage"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — RESOLVE-ANCHOR.PY NAMES THE ELEMENT A SENT COMMENT POINTS AT IN THE PULLED BOARD, AND SAYS WHEN IT CANNOT.
#   Operand: scripts/design/resolve-anchor.py over the Settings board an agent wrote, with the anchor `detail` exactly as the claude-artifacts
#   server's read_comments returned it for a thread a person sent to Claude (`Settings.dc.html: #2:1 shape "…"`), and the plain form.
# =============================================================================
case_resolve_anchor_names_the_element_a_sent_comment_points_at_and_says_when_it_cannot() {
  cf_reset
  local L="resolve-anchor.py turns a read_comments anchor detail (and the plain Board#n:path form) into <Board>#<element id> with the tag, the data attributes and the first words, exits 0 when every anchor resolved, and says UNRESOLVED with the reason, exit 1, for a place and path that disagree, a board that is not there, and a board or note anchor"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _md_sandbox
  local m="$REAL_REPO_ROOT/modules/design/scripts/design" d="$SB_TMP/ra"
  mkdir -p "$d/p"
  cat > "$d/p/Settings.dc.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Settings</title>
<script src="./support.js"></script>
<link rel="stylesheet" href="ds/steep/tokens.css">
</head>
<body>
<x-dc>
<helmet>
<style>
body{margin:0}
</style>
</helmet>
<div id="ux-003-root" data-ux="UX-003" data-stories="PRD-001-F2-S1" style="width: 390px; height: 844px; box-sizing: border-box; padding: var(--space-6) var(--space-4); display: flex; flex-direction: column; gap: var(--space-4); background: var(--color-surface); color: var(--color-on-surface); font-family: var(--font-sans)">
<h1 id="ux-003-title" style="margin: 0; font-size: 24px; line-height: 32px; font-weight: 600">Settings</h1>
<div id="ux-003-sound" data-state="default" style="padding: var(--space-4); border-radius: var(--radius-md); background: var(--color-surface-raised); color: var(--color-muted); font-size: 16px">Sound when done</div>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"$preview":{"width":390,"height":844}}'>
class Component extends DCLogic {
renderVals() { return {}; }
}
</script>
</body>
</html>
EOF
  _dm_py "$m/resolve-anchor.py" "$d/p" 'Settings.dc.html: #2:1 shape "Settings Sound when done"'
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "RESOLVED" && _dm_has "$_dm_out" "Settings.dc.html#ux-003-root" && _dm_has "$_dm_out" "data-ux=UX-003" && _dm_has "$_dm_out" "Settings Sound when done"; } || cf "(a) the anchor a sent thread carried does not resolve to the root element, with its data attributes and words (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  _dm_py "$m/resolve-anchor.py" "$d/p" 'Settings.dc.html#2:1' 'Settings.dc.html#3:1/0'
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "Settings.dc.html#ux-003-title" && _dm_has "$_dm_out" "h1"; } || cf "(b) the plain form and a nested path do not resolve to the title (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  _dm_py "$m/resolve-anchor.py" "$d/p" 'Settings.dc.html#9:9'
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "UNRESOLVED" && _dm_has "$_dm_out" "differs"; } || cf "(c) a place and path that name no element are not UNRESOLVED with the reason (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_py "$m/resolve-anchor.py" "$d/p" 'Settings.dc.html#3:1'
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "UNRESOLVED"; } || cf "(c) a place that disagrees with its path is resolved (exit $_dm_rc): $_dm_out"
  _dm_py "$m/resolve-anchor.py" "$d/p" 'Gone.dc.html#1:0'
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "not in the pulled project"; } || cf "(d) a board that is not in the project is not said (exit $_dm_rc): $_dm_out"
  _dm_py "$m/resolve-anchor.py" "$d/p" 'note-brief'
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "not an element anchor"; } || cf "(d) a note anchor is resolved or passes in silence (exit $_dm_rc): $_dm_out"
  _dm_py "$m/resolve-anchor.py"
  [ "$_dm_rc" -eq 2 ] || cf "(e) no arguments exit $_dm_rc, not 2"
  _dm_py "$m/resolve-anchor.py" --help
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "usage:"; } || cf "(e) --help exits $_dm_rc, not 0, or prints no usage"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE PULL AND PUBLISH SKILLS ARE PLACED WHEN THE MODULE IS ENABLED, STATE THEIR SURFACE AND HOW TO TELL THE OTHER, AND CARRY THE GUARDS.
#   The expected answer is fixed here: the tokens each skill must carry (the pull compares by sha, reads one path at a time, verifies, normalises, resolves
#   anchors, reads only sent threads, commits only on the go-ahead and publishes nothing; the publish refuses a moved canvas, sends with the listed version,
#   stops on a warning and on a 409 over a person's edit, reads back by sha, answers only after the read-back), every tool path they name is placed by
#   the manifest, and neither tells a person to carry anything. Skills are prose; the attended run is where their steps are walked.
# =============================================================================
case_the_design_skills_state_their_surface_and_carry_the_guards_and_are_placed_with_their_tools() {
  cf_reset
  local L="enable places /design-pull and /design-publish and the two tools they run; each skill has its frontmatter, names surface A and B, says to use A when both are present and not to improvise when neither is, makes the sign-in call and ends with a Next:; the pull carries the sha compare, one-path reads, normalise, anchors, sent-threads-only and the go-ahead and publishes nothing; the publish carries the moved-canvas refusal, the listed version, the stop on a warning and on wouldOverwrite, the read-back and the reply after it; every script path a skill names is placed by the manifest"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  local m="$REAL_REPO_ROOT/modules/design" sk tok p f
  _md_sandbox
  _md_mod enable design
  [ "$_md_rc" -eq 0 ] || { cf "enable exited $_md_rc: $_md_out"; finish "$L"; teardown; return; }
  for sk in design-pull design-publish; do
    f="$SB_WORK/.claude/skills/$sk/SKILL.md"
    [ -f "$f" ] || { cf "(a) enable did not place .claude/skills/$sk/SKILL.md"; continue; }
    [ "$(sed -n 1p "$f")" = '---' ] || cf "(a) $sk has no frontmatter"
    grep -Fx "name: $sk" "$f" >/dev/null || cf "(a) $sk's frontmatter name is not $sk"
    grep -E '^description: Use when ' "$f" >/dev/null || cf "(a) $sk's description does not begin 'Use when '"
    grep -E '^argument-hint: ' "$f" >/dev/null || cf "(a) $sk has no argument-hint"
    grep -F 'KIT-CLASS:' "$f" >/dev/null || cf "(a) $sk carries no KIT-CLASS marker"
    for tok in 'A: the `claude-artifacts` server' 'B: the built-in `Artifact` tool' 'use A' 'do not improvise' 'Next:' 'list_artifacts' '/login' 'On B'; do
      grep -F -- "$tok" "$f" >/dev/null || cf "(b) $sk does not carry '$tok' (the surface it is written for, how to tell the other, the sign-in call)"
    done
    for p in $(grep -o 'scripts/design/[a-z0-9-]*[.]py' "$f" | sort -u); do
      [ -f "$SB_WORK/$p" ] || cf "(c) $sk names $p and enable did not place it"
    done
  done
  f="$SB_WORK/.claude/skills/design-pull/SKILL.md"
  for tok in 'list_files' 'sha256' 'shasum -a 256' 'one path a call' 'normalise-canvas.py' 'resolve-anchor.py' 'read_comments' 'Send to Claude' 'invisible' 'go-ahead' 'Last pull' 'canvas sha' 'repo sha' 'You publish nothing here' 'acknowledgement, not the change' 'proves nothing' 'a size proves nothing' 'git status --porcelain' 'rm -rf .cache/design/pull' 'limit: 1' 'Last publish' 'thread' 'plain `rm`' 'BOTH-SIDES' 'do not place' 'invisible to the link check' 'wait'; do
    grep -F -- "$tok" "$f" >/dev/null || cf "(d) design-pull does not carry '$tok'"
  done
  f="$SB_WORK/.claude/skills/design-publish/SKILL.md"
  for tok in 'list_files' 'base_version: V' 'mode: "patch"' 'wouldOverwrite' 'liveEntry' 'warnings' 'stop' 'do not resend your bytes with `live`' 'Read back' 'never verify' 'continues_reply_id' 'resolve_comment' 'reply_shared_comment' '/design-pull' 'Last pull: none' 'create_from_type' 'rsync' 'Never `git diff`' 'restore nothing' 'limit: 1' 'never re-send' 'restore (they reject'; do
    grep -F -- "$tok" "$f" >/dev/null || cf "(e) design-publish does not carry '$tok'"
  done
  grep -F 'base_version' "$SB_WORK/.claude/skills/design-pull/SKILL.md" >/dev/null && cf "(f) design-pull carries base_version: the pull sends nothing"
  { grep -F '/design-pull' "$SB_WORK/.claude/roles/designer.md" >/dev/null && grep -F '/design-publish' "$SB_WORK/.claude/roles/designer.md" >/dev/null; } || cf "(g) the Designer role does not name /design-pull and /design-publish"
  _md_mod status design
  _dm_has "$_md_out" "claude-code" || cf "(h) status does not name the claude-code requirement: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  _md_mod disable design
  { [ ! -e "$SB_WORK/.claude/skills/design-pull/SKILL.md" ] && [ ! -e "$SB_WORK/.claude/skills/design-publish/SKILL.md" ]; } || cf "(i) disable left a skill behind"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE MANIFEST DECLARES CLAUDE CODE'S FLOOR AS A CHECK AND THE CLAUDE.AI LOGIN AS AN AGENT-SIDE REQUIREMENT.
#   The expected answer is fixed here: the claude-code check, run with a stand-in `claude` that prints each version, passes at 2.1.228 and above and
#   fails below it and when claude is absent; the requirement is optional (the module's checkers need no Claude Code); the claude-ai-login line has
#   its four fields; enable prints it and refuses nothing for it; SETUP.md names the floor and /login; and the skills make the call.
# =============================================================================
case_the_manifest_declares_the_claude_code_floor_and_the_login_and_the_skills_make_the_call() {
  cf_reset
  local L="module.manifest declares an optional claude-code requirement whose check passes at 2.1.228 and above (2.1.290, 2.2.0, 3.0.1) and fails below it (2.1.227, 2.0.999) and with no claude, a claude-ai-login requires-agent line of four fields that enable prints without refusing, and SETUP.md names the floor and /login"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  local m="$REAL_REPO_ROOT/modules/design" line chk v bin rc
  line="$(grep -E '^requires:[[:space:]]*claude-code \| ' "$m/module.manifest" || true)"
  [ -n "$line" ] || { cf "(a) the manifest declares no claude-code requirement"; finish "$L"; return; }
  printf '%s\n' "$line" | grep -E ' \| optional: ' >/dev/null || cf "(a) the claude-code requirement is not optional"
  chk="${line#requires: claude-code | }"; chk="${chk% | *}"; chk="${chk% | *}"
  bin="$(mktemp -d)"
  for v in 2.1.290 2.2.0 3.0.1 2.1.228 2.1.227 2.0.999 1.9.9; do
    printf '#!/bin/sh\necho "%s (Claude Code)"\n' "$v" > "$bin/claude"; chmod +x "$bin/claude"
    rc=0; PATH="$bin:/usr/bin:/bin" sh -c "$chk" >/dev/null 2>&1 || rc=$?
    case "$v" in
      2.1.290|2.2.0|3.0.1|2.1.228) [ "$rc" -eq 0 ] || cf "(b) the check fails at $v (exit $rc), a version at or above the floor" ;;
      *) [ "$rc" -ne 0 ] || cf "(b) the check passes at $v, below the floor" ;;
    esac
  done
  rm -f "$bin/claude"; rc=0; PATH="$bin:/usr/bin:/bin" sh -c "$chk" >/dev/null 2>&1 || rc=$?
  [ "$rc" -ne 0 ] || cf "(b) the check passes with no claude on the path"
  rm -rf "${bin:?}"
  line="$(grep -E '^requires-agent:[[:space:]]*claude-ai-login \| ' "$m/module.manifest" || true)"
  [ -n "$line" ] || cf "(c) the manifest declares no claude-ai-login requires-agent line"
  [ "$(printf '%s' "$line" | awk -F' [|] ' '{ print NF }')" = 4 ] || cf "(c) the claude-ai-login line does not have four fields"
  printf '%s\n' "$line" | grep -F 'list_artifacts' >/dev/null || cf "(c) the claude-ai-login call is not a read-only listing"
  _md_sandbox
  _md_mod enable design
  { [ "$_md_rc" -eq 0 ] && _dm_has "$_md_out" "claude-ai-login"; } || cf "(d) enable refuses or does not print the claude-ai-login requirement (exit $_md_rc): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-300)"
  { grep -F '2.1.228' "$m/SETUP.md" >/dev/null && grep -F '/login' "$m/SETUP.md" >/dev/null; } || cf "(e) SETUP.md does not name Claude Code 2.1.228 and /login"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE PULL SKILL, WALKED OVER A REAL PULL'S SHAPE: THE PULL FOLDER, THE NORMALISER, THE LINK CHECK ON THE PULLED FILES, THE ANCHORS AND THE UNDO.
#   Operand: the shell blocks of .claude/skills/design-pull/SKILL.md (the fenced ```sh blocks labelled start, normalise, place, check, anchor and undo),
#   run in order in a project made of a real pulled canvas (three boards, the sheets, the token files, the registry, a PRD) with the pull that follows a
#   person's page edit: a Timer board with a colour literal, and a page-saved canvas.json beside it, and nothing else, as step 4 writes it
#   (the listing's path, project/<file>). The expected answers are fixed here: the sheet is normalised, the literal is a finding only once the files are in
#   place, an unchanged board's anchor resolves, a changed board's anchor resolves, and "no" puts project/ back byte for byte.
# =============================================================================
# _dm_pull_fixture — the module enabled in a sandbox with a real pulled canvas (three boards, sheets, tokens, registry, PRD) committed as the last pull, its manifest in CANVAS.md;
# $SB_TMP/Timer.before holds the last pull's Timer.
_dm_pull_fixture() {
  _md_sandbox
  _md_mod enable design
  [ "$_md_rc" -eq 0 ] || { cf "enable exited $_md_rc: $_md_out"; return 1; }
  _dm_land "enable the design module"
  mkdir -p "$(dirname "$SB_WORK/requirements/design/steep/project/Main.dc.html")"
  cat > "$SB_WORK/requirements/design/steep/project/Main.dc.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Brews</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<style>
body{margin:0}
:root{
  --color-surface: #FAF8F3;
  --color-surface-raised: #FFFFFF;
  --color-on-surface: #1F2421;
  --color-muted: #4A5553;
  --color-primary: #22577A;
  --color-on-primary: #FFFFFF;
}
</style>
</helmet>
<div id="ux-001-root" data-ux="UX-001" data-stories="PRD-001-F1-S1" style="width: 390px; height: 844px; box-sizing: border-box; padding: 24px 16px; display: flex; flex-direction: column; gap: 16px; background: var(--color-surface); color: var(--color-on-surface); font-family: system-ui, sans-serif">
<h1 id="ux-001-title" style="margin: 0; font-size: 24px; line-height: 32px; font-weight: 600">Brews</h1>
<sc-if value="{{isList}}" hint-placeholder-val="{{ true }}">
<div id="ux-001-list" data-state="list" style="display: flex; flex-direction: column; gap: 12px">
<a id="ux-001-open-sencha" href="Timer.dc.html" style="display: flex; align-items: center; justify-content: space-between; min-height: 56px; padding: 0 16px; border-radius: 12px; background: var(--color-surface-raised); color: var(--color-on-surface); text-decoration: none">
<span id="ux-001-name-sencha" style="font-size: 16px; font-weight: 500">Sencha</span>
<span id="ux-001-time-sencha" style="font-size: 14px; color: var(--color-muted)">2 min</span>
</a>
<div id="ux-001-preview" style="width: 156px; height: 338px; overflow: hidden; border-radius: 12px">
<div style="width: 390px; height: 844px; transform: scale(0.4); transform-origin: top left">
<dc-import name="Timer" view="idle" hint-size="390px,844px"></dc-import>
</div>
</div>
</div>
</sc-if>
<sc-if value="{{isEmpty}}" hint-placeholder-val="{{ false }}">
<div id="ux-001-empty" data-state="empty" style="padding: 24px; border-radius: 12px; background: var(--color-surface-raised); color: var(--color-muted); font-size: 16px">
<p id="ux-001-empty-text" style="margin: 0">No brews yet</p>
</div>
</sc-if>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"view":{"editor":"enum","default":"list","options":["list","empty"]},"$preview":{"width":390,"height":844}}'>
class Component extends DCLogic {
renderVals() {
const v = this.props.view ?? 'list';
return { isList: v === 'list', isEmpty: v === 'empty' };
}
}
</script>
</body>
</html>
EOF
  mkdir -p "$(dirname "$SB_WORK/requirements/design/steep/project/Settings.dc.html")"
  cat > "$SB_WORK/requirements/design/steep/project/Settings.dc.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Settings</title>
<script src="./support.js"></script>
<link rel="stylesheet" href="ds/steep/tokens.css">
</head>
<body>
<x-dc>
<helmet>
<style>
body{margin:0}
</style>
</helmet>
<div id="ux-003-root" data-ux="UX-003" data-stories="PRD-001-F2-S1" style="width: 390px; height: 844px; box-sizing: border-box; padding: var(--space-6) var(--space-4); display: flex; flex-direction: column; gap: var(--space-4); background: var(--color-surface); color: var(--color-on-surface); font-family: var(--font-sans)">
<h1 id="ux-003-title" style="margin: 0; font-size: 24px; line-height: 32px; font-weight: 600">Settings</h1>
<div id="ux-003-sound" data-state="default" style="padding: var(--space-4); border-radius: var(--radius-md); background: var(--color-surface-raised); color: var(--color-muted); font-size: 16px">Sound on finish</div>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"$preview":{"width":390,"height":844}}'>
class Component extends DCLogic {
renderVals() { return {}; }
}
</script>
</body>
</html>
EOF
  mkdir -p "$(dirname "$SB_WORK/requirements/design/steep/project/Timer.dc.html")"
  cat > "$SB_WORK/requirements/design/steep/project/Timer.dc.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Timer</title>
<script src="./support.js"></script>
<link rel="stylesheet" href="sheets/tokens.css">
</head>
<body>
<x-dc>
<helmet>
<style>
body{margin:0}
</style>
</helmet>
<div id="ux-002-root" data-ux="UX-002" data-stories="PRD-001-F1-S2" class="ux-screen" style="width: 390px; height: 844px; box-sizing: border-box; padding: 24px 16px; display: flex; flex-direction: column; gap: 16px; background: var(--color-surface); color: var(--color-on-surface); font-family: system-ui, sans-serif">
<h1 id="ux-002-title" style="margin: 0; font-size: 24px; line-height: 32px; font-weight: 600">Sencha</h1>
<sc-if value="{{isIdle}}" hint-placeholder-val="{{ true }}">
<div id="ux-002-idle" data-state="idle" style="display: flex; flex-direction: column; gap: 16px">
<p id="ux-002-remaining" style="margin: 0; font-size: 48px; line-height: 56px; font-weight: 300">2:00</p>
<button id="ux-002-start" type="button" style="height: 48px; border: 0; border-radius: 24px; background: var(--color-primary); color: var(--color-on-primary); font-size: 16px; font-weight: 500; font-family: inherit">Start</button>
</div>
</sc-if>
<sc-if value="{{isDone}}" hint-placeholder-val="{{ false }}">
<div id="ux-002-done" data-state="done" style="display: flex; flex-direction: column; gap: 16px">
<p id="ux-002-ready" style="margin: 0; font-size: 24px; line-height: 32px">Ready to pour</p>
<a id="ux-002-back" href="Main.dc.html" style="display: flex; align-items: center; justify-content: center; height: 48px; border-radius: 24px; background: var(--color-primary); color: var(--color-on-primary); text-decoration: none; font-size: 16px; font-weight: 500">Back to brews</a>
</div>
</sc-if>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"view":{"editor":"enum","default":"idle","options":["idle","done"]},"$preview":{"width":390,"height":844}}'>
class Component extends DCLogic {
renderVals() {
const v = this.props.view ?? 'idle';
return { isIdle: v === 'idle', isDone: v === 'done' };
}
}
</script>
</body>
</html>
EOF
  mkdir -p "$(dirname "$SB_WORK/requirements/design/steep/project/canvas.json")"
  cat > "$SB_WORK/requirements/design/steep/project/canvas.json" <<'EOF'
{"v":3,"createdOnFiles":{"v":1,"at":"2026-11-01T04:30:00Z"},"title":"Brews canvas","launch":{"view":"canvas"},"pages":[],"boards":{"Main.dc.html":{"x":0,"y":0,"w":390,"h":844,"title":"UX-001 Brews (phone)","is_interactive":true},"Timer.dc.html":{"x":470,"y":0,"w":390,"h":844,"title":"UX-002 Timer (phone)"},"Settings.dc.html":{"x":940,"y":0,"w":390,"h":844,"title":"UX-003 Settings (phone)"}},"order":["Main.dc.html","Timer.dc.html","Settings.dc.html"],"notes":{"note-brief":{"x":0,"y":-200,"w":320,"text":"Authored from a brief."}},"designSystems":[{"title":"Steep tokens","namespace":"steep","artifact":"design-system-address","version":"0-0000","copiedAt":"2026-11-01T04:30:00Z"}]}
EOF
  mkdir -p "$(dirname "$SB_WORK/requirements/design/steep/project/sheets/tokens.css")"
  cat > "$SB_WORK/requirements/design/steep/project/sheets/tokens.css" <<'EOF'
/* Steep tokens, for a screen that may be imported: a child's helmet takes no :root rule. */
:root {
  --color-surface: #FAF8F3;
  --color-surface-raised: #FFFFFF;
  --color-on-surface: #1F2421;
  --color-muted: #4A5553;
  --color-primary: #22577A;
  --color-on-primary: #FFFFFF;
}
.ux-screen { letter-spacing: 0.1px; }
EOF
  mkdir -p "$(dirname "$SB_WORK/requirements/design/steep/project/ds/steep/tokens.css")"
  cat > "$SB_WORK/requirements/design/steep/project/ds/steep/tokens.css" <<'EOF'
/* Steep tokens — generated from tokens.json */

:root, [data-theme="light"] {
  --color-surface: #FAF8F3;
  --color-surface-raised: #FFFFFF;
  --color-on-surface: #1F2421;
  --color-muted: #4A5553;
  --color-primary: #22577A;
  --color-on-primary: #FFFFFF;
}

[data-theme="dark"] {
  --color-surface: #141816;
  --color-surface-raised: #1F2421;
  --color-on-surface: #F0EEE8;
  --color-muted: #B8C2BF;
  --color-primary: #8FC4E8;
  --color-on-primary: #0B2433;
}

[data-theme="wire"] {
  --color-surface: #F9F9F9;
  --color-surface-raised: #FFFFFF;
  --color-on-surface: #1C1C1C;
  --color-muted: #464646;
  --color-primary: #555555;
  --color-on-primary: #FFFFFF;
}

:root {
  --space-2: 8px;
  --space-4: 16px;
  --space-6: 24px;
  --radius-md: 12px;
  --radius-full: 24px;
  --font-sans: system-ui, sans-serif;
}
EOF
  mkdir -p "$(dirname "$SB_WORK/requirements/design/tokens/steep.tokens.json")"
  cat > "$SB_WORK/requirements/design/tokens/steep.tokens.json" <<'EOF'
{
 "color": {
  "surface": {
   "$type": "color",
   "$value": "#FAF8F3"
  },
  "surface-raised": {
   "$type": "color",
   "$value": "#FFFFFF"
  },
  "on-surface": {
   "$type": "color",
   "$value": "#1F2421"
  },
  "muted": {
   "$type": "color",
   "$value": "#4A5553"
  },
  "primary": {
   "$type": "color",
   "$value": "#22577A"
  },
  "on-primary": {
   "$type": "color",
   "$value": "#FFFFFF"
  }
 },
 "space": {
  "2": {
   "$type": "dimension",
   "$value": "8px"
  },
  "4": {
   "$type": "dimension",
   "$value": "16px"
  },
  "6": {
   "$type": "dimension",
   "$value": "24px"
  }
 },
 "radius": {
  "md": {
   "$type": "dimension",
   "$value": "12px"
  },
  "full": {
   "$type": "dimension",
   "$value": "24px"
  }
 },
 "font": {
  "sans": {
   "$type": "fontFamily",
   "$value": "system-ui, sans-serif"
  }
 }
}
EOF
  mkdir -p "$(dirname "$SB_WORK/requirements/design/tokens/steep.dark.tokens.json")"
  cat > "$SB_WORK/requirements/design/tokens/steep.dark.tokens.json" <<'EOF'
{
 "color": {
  "surface": {
   "$type": "color",
   "$value": "#141816"
  },
  "surface-raised": {
   "$type": "color",
   "$value": "#1F2421"
  },
  "on-surface": {
   "$type": "color",
   "$value": "#F0EEE8"
  },
  "muted": {
   "$type": "color",
   "$value": "#B8C2BF"
  },
  "primary": {
   "$type": "color",
   "$value": "#8FC4E8"
  },
  "on-primary": {
   "$type": "color",
   "$value": "#0B2433"
  }
 }
}
EOF
  mkdir -p "$(dirname "$SB_WORK/requirements/design/tokens/steep.wire.tokens.json")"
  cat > "$SB_WORK/requirements/design/tokens/steep.wire.tokens.json" <<'EOF'
{
 "color": {
  "surface": {
   "$type": "color",
   "$value": "#F9F9F9"
  },
  "surface-raised": {
   "$type": "color",
   "$value": "#FFFFFF"
  },
  "on-surface": {
   "$type": "color",
   "$value": "#1C1C1C"
  },
  "muted": {
   "$type": "color",
   "$value": "#464646"
  },
  "primary": {
   "$type": "color",
   "$value": "#555555"
  },
  "on-primary": {
   "$type": "color",
   "$value": "#FFFFFF"
  }
 }
}
EOF
  mkdir -p "$(dirname "$SB_WORK/requirements/PRD-001-steep.md")"
  cat > "$SB_WORK/requirements/PRD-001-steep.md" <<'EOF'
---
id: PRD-001
title: Steep
status: approved
---

# PRD-001 — Steep

## Features

### F1 — Brewing

#### Stories

##### F1-S1 — See my brews

**UI:** list, empty

- [ ] AC1: (UI) The home screen lists brews with their times. [design: UX-001#list]
- [ ] AC2: (UI) With no brews, it says so. [design: UX-001#empty]

##### F1-S2 — Time a brew

**UI:** idle, done

- [ ] AC1: (UI) A brew shows its time and a Start button. [design: UX-002#idle]
- [ ] AC2: (UI) When done, it offers a way back. [design: UX-002#done]

### F2 — Settings

#### Stories

##### F2-S1 — Sound

**UI:** default

- [ ] AC1: (UI) The user can see the finish sound setting. [design: UX-003#default]
EOF
  mkdir -p "$(dirname "$SB_WORK/requirements/design/steep/CANVAS.md")"
  cat > "$SB_WORK/requirements/design/steep/CANVAS.md" <<'EOF'
# CANVAS — steep

- **Canvas:** Brews canvas — design-system-address
- **Last pull:** none
- **Last publish:** none
- **Pin-ready:** none
- **Breakpoint:** none declared; widths covered: 390.
- **PRDs served:** PRD-001
- **Tokens:** `requirements/design/tokens/steep.tokens.json` (+ `.dark`, `.wire`)

## Screen registry

### Brewing

| UX-id | file | title | platform | pair | states | stories | gate1 | gate2 |
|---|---|---|---|---|---|---|---|---|
| UX-001 | Main.dc.html | Brews (phone) | phone | none | list, empty | PRD-001-F1-S1 | open | open |
| UX-002 | Timer.dc.html | Timer (phone) | phone | none | idle, done | PRD-001-F1-S2 | open | open |
| UX-003 | Settings.dc.html | Settings (phone) | phone | none | default | PRD-001-F2-S1 | open | open |
EOF
  # the manifest the pull writes: one line per project file, canvas sha and repo sha (equal at a take-in)
  ( cd "$SB_WORK/requirements/design/steep" && printf '\n## Manifest\n\n```\n' >> CANVAS.md && for f in $(find project -type f | sort); do
      s="$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$f")"; printf '%s %s %s\n' "$f" "$s" "$s" >> CANVAS.md; done; printf '```\n' >> CANVAS.md )
  _dm_commit "the last pull"
  cp "$SB_WORK/requirements/design/steep/project/Timer.dc.html" "$SB_TMP/Timer.before"
}

_dm_fence() { awk -v l="$2" '$0 == "```sh " l { f = 1; next } f && /^```$/ { exit } f { print }' "$1"; }   # <skill> <label> — the lines of that block
_dm_sh() { _dm_rc=0; _dm_out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR PYTHONDONTWRITEBYTECODE=1 bash -c "$1" 2>&1 </dev/null )" || _dm_rc=$?; }
case_the_pull_skill_walked_over_a_real_pulls_shape_checks_the_pulled_files_resolves_anchors_on_the_whole_set_and_undoes() {
  cf_reset
  local L="the design-pull skill's own shell blocks, run over a real pull's shape, empty the pull folder, normalise project/canvas.json in it, find a colour literal only after the pull is laid over project/ (and not before), resolve the anchor of an unchanged board and of a changed one, and restore project/ byte for byte on a no"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_pull_fixture || { finish "$L"; teardown; return; }
  local sk="$SB_WORK/.claude/skills/design-pull/SKILL.md" b pj="$SB_WORK/.cache/design/pull/project"
  for b in start normalise both row gone place check anchor drop undo; do
    [ -n "$(_dm_fence "$sk" "$b")" ] || cf "(a) design-pull has no fenced \`\`\`sh $b block"
  done
  blk() { _dm_fence "$sk" "$1" | sed "s|<canvas>|steep|g; s|<board>#<n>:<path>|${2:-}|g"; }   # <label> [<anchor>]
  _dm_sh 'git status --porcelain requirements/design/steep'
  [ -z "$_dm_out" ] || cf "(prereq) the fixture is not committed: $_dm_out"
  # (b) step 4 starts from an empty pull folder, however full the last one was
  mkdir -p "$SB_WORK/.cache/design/pull/project"; printf 'old\n' > "$SB_WORK/.cache/design/pull/project/Stale.dc.html"
  _dm_sh "$(blk start)"
  { [ "$_dm_rc" -eq 0 ] && [ -d "$pj" ] && [ -z "$(ls -A "$pj")" ]; } || cf "(b) the start block does not leave an empty pull/project folder (exit $_dm_rc): $_dm_out"
  # step 4 as written: only the files that differed, at the listing's path
  cat > "$pj/Timer.dc.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Timer</title>
<script src="./support.js"></script>
<link rel="stylesheet" href="sheets/tokens.css">
</head>
<body>
<x-dc>
<helmet>
<style>
body{margin:0}
</style>
</helmet>
<div id="ux-002-root" data-ux="UX-002" data-stories="PRD-001-F1-S2" class="ux-screen" style="width: 390px; height: 844px; box-sizing: border-box; padding: 24px 16px; display: flex; flex-direction: column; gap: 16px; background: var(--color-surface); color: var(--color-on-surface); font-family: system-ui, sans-serif">
<h1 id="ux-002-title" style="margin: 0; font-size: 24px; line-height: 32px; font-weight: 600">Sencha</h1>
<sc-if value="{{isIdle}}" hint-placeholder-val="{{ true }}">
<div id="ux-002-idle" data-state="idle" style="display: flex; flex-direction: column; gap: 16px">
<p id="ux-002-remaining" style="margin: 0; font-size: 48px; line-height: 56px; font-weight: 300">2:00</p>
<button id="ux-002-start" type="button" style="height: 48px; border: 0; border-radius: 24px; color: var(--color-on-primary); font-size: 16px; font-weight: 500; font-family: inherit; background-color: #ff0000">Get Started</button>
</div>
</sc-if>
<sc-if value="{{isDone}}" hint-placeholder-val="{{ false }}">
<div id="ux-002-done" data-state="done" style="display: flex; flex-direction: column; gap: 16px">
<p id="ux-002-ready" style="margin: 0; font-size: 24px; line-height: 32px">Ready to pour</p>
<a id="ux-002-back" href="Main.dc.html" style="display: flex; align-items: center; justify-content: center; height: 48px; border-radius: 24px; background: var(--color-primary); color: var(--color-on-primary); text-decoration: none; font-size: 16px; font-weight: 500">Back to brews</a>
</div>
</sc-if>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"view":{"editor":"enum","default":"idle","options":["idle","done"]},"$preview":{"width":390,"height":844}}'>
class Component extends DCLogic {
renderVals() {
const v = this.props.view ?? 'idle';
return { isIdle: v === 'idle', isDone: v === 'done' };
}
}
</script>
</body>
</html>
EOF
  cat > "$pj/canvas.json" <<'EOF'
{
  "attachments": {},
  "boards": {
    "Main.dc.html": {
      "h": 844,
      "is_interactive": true,
      "title": "UX-001 Brews (phone)",
      "w": 390,
      "x": 0,
      "y": 0
    },
    "Settings.dc.html": {
      "h": 844,
      "title": "UX-003 Settings (phone)",
      "w": 390,
      "x": 940,
      "y": 0
    },
    "Timer.dc.html": {
      "h": 844,
      "title": "UX-002 Timer (phone)",
      "w": 390,
      "x": 617,
      "y": 0
    }
  },
  "createdOnFiles": {
    "at": "2026-11-01T04:30:00Z",
    "v": 1
  },
  "designSystems": [
    {
      "artifact": "design-system-address",
      "copiedAt": "2026-11-01T04:30:00Z",
      "namespace": "steep",
      "title": "Steep tokens",
      "version": "0-0000"
    }
  ],
  "launch": {
    "view": "canvas"
  },
  "notes": {
    "note-brief": {
      "text": "Authored from a brief.",
      "w": 320,
      "x": 0,
      "y": -200
    }
  },
  "order": [
    "Main.dc.html",
    "Timer.dc.html",
    "Settings.dc.html"
  ],
  "pages": [],
  "title": "Brews canvas",
  "v": 3
}
EOF
  # (c) step 5: the page-saved canvas.json in the pull is normalised (the old path named the folder above, which has no canvas.json)
  _dm_sh "$(blk normalise)"
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "normalised canvas.json"; } || cf "(c) the normalise block does not normalise the pulled canvas.json (exit $_dm_rc): $_dm_out"
  grep -F '"attachments"' "$pj/canvas.json" >/dev/null && cf "(c) the empty attachments stayed in the pulled canvas.json"
  # (d) step 6: before the pull is laid over project/ the check reads the old files and is clean; after, it names the literal
  _dm_sh "$(blk check)"
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "LITERAL-COLOUR"; } || cf "(d) the prereq: the old files are not clean (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
  _dm_sh "$(blk place)"
  [ "$_dm_rc" -eq 0 ] || cf "(d) the place block failed (exit $_dm_rc): $_dm_out"
  _dm_sh "$(blk check)"
  { _dm_has "$_dm_out" "LITERAL-COLOUR" && _dm_has "$_dm_out" "#ff0000" && _dm_has "$_dm_out" "Timer.dc.html"; } || cf "(d) the link check, run after the pull is laid over project/, does not name the pulled colour literal: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  # (e) step 7: Settings is not in the pull and still resolves; Timer is, and resolves in its pulled form
  _dm_sh "$(blk anchor 'Settings.dc.html#2:1')"
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "Settings.dc.html#ux-003-root"; } || cf "(e) the anchor of an unchanged board does not resolve (exit $_dm_rc): $_dm_out"
  _dm_sh "$(blk anchor 'Timer.dc.html#2:1')"
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "Timer.dc.html#ux-002-root"; } || cf "(e) the anchor of a changed board does not resolve (exit $_dm_rc): $_dm_out"
  # (f) a no: project/ is as it was
  _dm_sh "$(blk undo)"
  _dm_sh 'git status --porcelain requirements/design/steep'
  [ -z "$_dm_out" ] || cf "(f) the undo block leaves project/ changed: $_dm_out"
  cmp -s "$SB_TMP/Timer.before" "$SB_WORK/requirements/design/steep/project/Timer.dc.html" || cf "(f) Timer is not the last pull's after the undo"
  finish "$L"
  teardown
}

# _dm_pull_walk <label> [<sed expression>] — the design-pull skill's shell block of that label, <canvas> read as steep, then the expression.
_dm_pull_walk() { _dm_fence "$SB_WORK/.claude/skills/design-pull/SKILL.md" "$1" | sed "s|<canvas>|steep|g; s|<gone>|${_DM_GONE:-}|g${2:+; $2}"; }

# =============================================================================
# CASE — A DECLINED PULL THAT HELD A DELETION LEAVES THE MANIFEST AND THE TREE AS THEY WERE; AN ACCEPTED ONE DROPS THE LINE AT THE TAKE-IN.
#   Operand: the pull skill's gone, undo and drop blocks over the real pulled project, Settings gone from the canvas. The expected answers are fixed
#   here: the removal touches the board file only (not CANVAS.md), the undo returns a clean tree with the manifest line still there (so the next publish
#   does not send the board back as repo-only), and the drop block removes exactly that line and leaves no backup file.
# =============================================================================
case_the_pull_skill_walked_with_a_deletion_declined_leaves_the_manifest_and_accepted_drops_its_line() {
  cf_reset
  local L="the design-pull skill's gone block removes the board file and leaves CANVAS.md alone, its undo block returns the tree and the manifest line exactly, and its drop block (after the go-ahead) removes that one manifest line and leaves no .bak"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_pull_fixture || { finish "$L"; teardown; return; }
  local c="$SB_WORK/requirements/design/steep/CANVAS.md" n0 sub='s|<path>|project/Settings.dc.html|g'
  n0="$(grep -c '^project/' "$c")"
  grep -F 'project/Settings.dc.html ' "$c" >/dev/null || cf "(prereq) the fixture's manifest has no Settings line"
  _dm_sh "$(_dm_pull_walk gone "$sub")"
  [ "$_dm_rc" -eq 0 ] || cf "(a) the gone block failed (exit $_dm_rc): $_dm_out"
  _dm_sh 'git status --porcelain requirements/design/steep'
  { printf '%s\n' "$_dm_out" | grep -F 'Settings.dc.html' >/dev/null && ! printf '%s\n' "$_dm_out" | grep -F 'CANVAS.md' >/dev/null; } || cf "(a) the gone block does not change the board file alone: $_dm_out"
  _dm_sh "$(_dm_pull_walk undo)"
  _dm_sh 'git status --porcelain requirements/design/steep'
  [ -z "$_dm_out" ] || cf "(b) after the undo the tree is not as it was: $_dm_out"
  { [ -f "$SB_WORK/requirements/design/steep/project/Settings.dc.html" ] && [ "$(grep -c '^project/' "$c")" = "$n0" ]; } || cf "(b) the undo did not bring back the board and keep every manifest line"
  # the accepted path: after the go-ahead the line goes, and only that line
  _dm_sh "$(_dm_pull_walk gone "$sub")"
  _dm_sh "$(_dm_pull_walk drop "$sub")"
  [ "$_dm_rc" -eq 0 ] || cf "(c) the drop block failed (exit $_dm_rc): $_dm_out"
  { ! grep -F 'project/Settings.dc.html ' "$c" >/dev/null && [ "$(grep -c '^project/' "$c")" = "$((n0 - 1))" ]; } || cf "(c) the drop block did not remove exactly the Settings line"
  [ ! -e "$c.bak" ] || cf "(c) the drop block left $c.bak"
  [ ! -e "$c.new" ] || cf "(c) the drop block left $c.new"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A FILE CHANGED ON BOTH SIDES IS NAMED BEFORE THE PULL IS LAID OVER IT, AND BOTH CHANGES ARE SHOWN.
#   Operand: the pull skill's both and showboth blocks over the real pulled project, after a repo commit to Timer that the canvas lacks, with a pulled Timer.
#   The expected answers are fixed here: the both block names project/Timer.dc.html and no other file; for a pull whose file the repo did not change it
#   names nothing; the showboth block shows the repo's change (the commit's marker line) and the canvas's.
# =============================================================================
case_the_pull_skill_walked_over_a_file_changed_on_both_sides_names_it_and_shows_both_changes() {
  cf_reset
  local L="the design-pull skill's both block names a pulled file whose repo copy changed since the manifest and no file the repo left alone, and its showboth block shows the repo's change and the canvas's"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_pull_fixture || { finish "$L"; teardown; return; }
  local pj="$SB_WORK/.cache/design/pull/project" t="$SB_WORK/requirements/design/steep/project/Timer.dc.html" base
  base="$(git -C "$SB_WORK" rev-parse HEAD)"
  # a pull that brings Timer and Settings while the repo has changed Timer alone
  _dm_edit "$t" 's|<title>Timer</title>|<title>Timer REPO SIDE</title>|'
  _dm_commit "the Designer changes Timer in the repo"
  _dm_sh "$(_dm_pull_walk start)"
  sed 's|<title>Timer</title>|<title>Timer CANVAS SIDE</title>|' "$SB_TMP/Timer.before" > "$pj/Timer.dc.html"
  cp "$SB_WORK/requirements/design/steep/project/Settings.dc.html" "$pj/Settings.dc.html"
  _dm_sh "$(_dm_pull_walk both)"
  { printf '%s\n' "$_dm_out" | grep -Fx 'BOTH-SIDES project/Timer.dc.html' >/dev/null && [ "$(printf '%s\n' "$_dm_out" | grep -c BOTH-SIDES)" = 1 ]; } || cf "(a) the both block does not name Timer alone (exit $_dm_rc): $_dm_out"
  _dm_sh "$(_dm_pull_walk showboth "s|<base>|$base|g; s|<path>|project/Timer.dc.html|g")"
  { _dm_has "$_dm_out" "REPO SIDE" && _dm_has "$_dm_out" "CANVAS SIDE"; } || cf "(b) the showboth block does not show the repo's change and the canvas's: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  # a pull of a file the repo did not touch is not on both sides
  _dm_sh "$(_dm_pull_walk start)"
  cp "$SB_WORK/requirements/design/steep/project/Settings.dc.html" "$pj/Settings.dc.html"
  _dm_sh "$(_dm_pull_walk both)"
  { [ "$_dm_rc" -eq 0 ] && [ -z "$_dm_out" ]; } || cf "(c) the both block names a file the repo did not change (exit $_dm_rc): $_dm_out"
  # (d) Timer is gone from the canvas while the repo changed it: the pull holds nothing, and the block still names it
  _dm_sh "$(_dm_pull_walk start)"
  _dm_sh "$(_DM_GONE=project/Timer.dc.html _dm_pull_walk both)"
  printf '%s\n' "$_dm_out" | grep -Fx 'BOTH-SIDES project/Timer.dc.html' >/dev/null || cf "(d) a file gone from the canvas that the repo changed is not named (exit $_dm_rc): $_dm_out"
  # (e0) the sha256sum of that PATH directory is the host's own when it has one, and shasum -a 256 wrapped only when it does not
  local bin t2 t3
  t3="$(mktemp -d)"
  printf '#!/bin/sh\necho OWN-SHA256SUM\n' > "$t3/sha256sum"; chmod +x "$t3/sha256sum"
  printf '#!/bin/sh\necho "SHASUM $*"\n' > "$t3/shasum"; chmod +x "$t3/shasum"
  mkdir -p "$t3/a" "$t3/b"
  _dm_sha256_bin "$t3/a" "$t3/sha256sum" ""
  [ "$("$t3/a/sha256sum" x 2>&1)" = "OWN-SHA256SUM" ] || cf "(e0) a host with its own sha256sum and no shasum does not get that sha256sum in the scratch PATH: $("$t3/a/sha256sum" x 2>&1 | head -2)"
  _dm_sha256_bin "$t3/b" "" "$t3/shasum"
  [ "$("$t3/b/sha256sum" x 2>&1)" = "SHASUM -a 256 x" ] || cf "(e0) a host with shasum and no sha256sum does not get shasum -a 256 wrapped: $("$t3/b/sha256sum" x 2>&1 | head -2)"
  rm -rf "${t3:?}"
  # (e) a host with sha256sum and no shasum gives the same answers (the harness admits such a host)
  bin="$(mktemp -d)"
  for t2 in bash awk find sort cut sed cat ls rm mkdir cp; do command -v "$t2" >/dev/null 2>&1 && ln -s "$(command -v "$t2")" "$bin/$t2"; done
  _dm_sha256_bin "$bin"
  _dm_sh "$(_dm_pull_walk start)"
  sed 's|<title>Timer</title>|<title>Timer CANVAS SIDE</title>|' "$SB_TMP/Timer.before" > "$pj/Timer.dc.html"
  cp "$SB_WORK/requirements/design/steep/project/Settings.dc.html" "$pj/Settings.dc.html"
  _dm_rc=0; _dm_out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR PATH="$bin" "$bin/bash" -c "$(_dm_pull_walk both)" 2>&1 </dev/null )" || _dm_rc=$?
  rm -rf "${bin:?}"
  { printf '%s\n' "$_dm_out" | grep -Fx 'BOTH-SIDES project/Timer.dc.html' >/dev/null && [ "$(printf '%s\n' "$_dm_out" | grep -c BOTH-SIDES)" = 1 ]; } || cf "(e) with sha256sum and no shasum the both block does not name Timer alone: $_dm_out"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE UNDO OF A FIRST PULL, WHEN project/ TRACKS NOTHING YET, LEAVES NO ROW AND NO PULLED FILE.
#   Operand: the pull skill's row, place and undo blocks over the real pulled project's record with its project/ files removed from the repository.
# =============================================================================
case_the_pull_skill_walked_as_a_first_pull_undoes_what_it_laid_with_nothing_tracked() {
  cf_reset
  local L="the design-pull skill's undo block, run after a first pull that laid a board and a registry row where project/ tracks nothing, leaves a clean tree and CANVAS.md as it was"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_pull_fixture || { finish "$L"; teardown; return; }
  local pj="$SB_WORK/.cache/design/pull/project" c="$SB_WORK/requirements/design/steep/CANVAS.md" sub
  sub='s|<ux>|UX-004|g; s|<file>|New.dc.html|g; s|<title>|New (phone)|g; s|<platform>|phone|g; s|<states>|default|g; s|<stories>|PRD-001-F2-S1|g'
  git -C "$SB_WORK" rm -r -q requirements/design/steep/project >/dev/null 2>&1
  _dm_commit "a canvas record that has taken nothing in yet"
  cp "$c" "$SB_TMP/CANVAS.before"
  _dm_sh "$(_dm_pull_walk start)"
  printf '<!doctype html><x-dc><div id="ux-004-root" data-ux="UX-004" data-stories="PRD-001-F2-S1"></div></x-dc>\n' > "$pj/New.dc.html"
  _dm_sh "$(_dm_pull_walk row "$sub")"
  _dm_sh "$(_dm_pull_walk place)"
  [ -f "$SB_WORK/requirements/design/steep/project/New.dc.html" ] || cf "(a) the place block did not lay the board"
  _dm_sh "$(_dm_pull_walk undo)"
  _dm_sh 'git status --porcelain requirements/design/steep'
  [ -z "$_dm_out" ] || cf "(b) the undo of a first pull leaves the tree changed: $_dm_out"
  cmp -s "$SB_TMP/CANVAS.before" "$c" || cf "(b) CANVAS.md is not as it was after the undo"
  [ ! -e "$SB_WORK/requirements/design/steep/project/New.dc.html" ] || cf "(b) the pulled board is still there"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A NEW BOARD IN A PULL IS GIVEN ITS REGISTRY ROW BEFORE THE LINK CHECK, SO THE VERDICT COVERS IT, AND THE ROW GOES WITH THE UNDO.
#   Operand: the pull skill's row, place, check and undo blocks over the real pulled project, with a pulled New board that holds a colour literal.
#   The expected answers are fixed here: without its row the check does not name the literal (the blindness the row closes); with the row it does;
#   the undo returns the tree and CANVAS.md byte for byte.
# =============================================================================
case_the_pull_skill_walked_with_a_new_board_registers_it_before_the_check_and_the_undo_removes_the_row() {
  cf_reset
  local L="the design-pull skill's row block puts a new board in the registry so that the check run after place names its colour literal (without the row it does not), and the undo block removes the row and the board byte for byte"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_pull_fixture || { finish "$L"; teardown; return; }
  local pj="$SB_WORK/.cache/design/pull/project" c="$SB_WORK/requirements/design/steep/CANVAS.md" sub
  sub='s|<ux>|UX-004|g; s|<file>|New.dc.html|g; s|<title>|New (phone)|g; s|<platform>|phone|g; s|<states>|default|g; s|<stories>|PRD-001-F2-S1|g'
  cp "$c" "$SB_TMP/CANVAS.before"
  _dm_sh "$(_dm_pull_walk start)"
  cat > "$pj/New.dc.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>New</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<style>
body{margin:0}
</style>
</helmet>
<div id="ux-004-root" data-ux="UX-004" data-stories="PRD-001-F2-S1" style="width: 390px; height: 844px; color: #00ff00">
<p id="ux-004-note" data-state="default">New</p>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"$preview":{"width":390,"height":844}}'>
class Component extends DCLogic {
renderVals() { return {}; }
}
</script>
</body>
</html>
EOF
  # (a) with no row the check cannot see the board: its verdict is silent about the literal
  _dm_sh "$(_dm_pull_walk place)"
  _dm_sh "$(_dm_pull_walk check)"
  _dm_has "$_dm_out" "#00ff00" && cf "(a) the check names the colour of a board that has no registry row: the control for the row block is void"
  _dm_sh "$(_dm_pull_walk undo)"
  _dm_sh 'git status --porcelain requirements/design/steep'
  [ -z "$_dm_out" ] || cf "(a) the undo leaves the tree changed: $_dm_out"
  # (b) with its row, before the check, the verdict covers it
  _dm_sh "$(_dm_pull_walk row "$sub")"
  { [ "$_dm_rc" -eq 0 ] && grep -F '| UX-004 | New.dc.html |' "$c" >/dev/null; } || cf "(b) the row block did not add the UX-004 row to the registry (exit $_dm_rc): $_dm_out"
  _dm_sh "$(_dm_pull_walk place)"
  _dm_sh "$(_dm_pull_walk check)"
  { _dm_has "$_dm_out" "LITERAL-COLOUR" && _dm_has "$_dm_out" "#00ff00" && _dm_has "$_dm_out" "New.dc.html"; } || cf "(b) with its row the check does not name the new board's colour literal: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  # (c) the undo takes the board and the row away
  _dm_sh "$(_dm_pull_walk undo)"
  _dm_sh 'git status --porcelain requirements/design/steep'
  [ -z "$_dm_out" ] || cf "(c) the undo leaves the tree changed: $_dm_out"
  cmp -s "$SB_TMP/CANVAS.before" "$c" || cf "(c) CANVAS.md is not as it was after the undo"
  # (d) a canvas made on the page has a registry with no row yet: the row goes under the header and the verdict covers the board
  grep -v '^| UX-[0-9]' "$SB_TMP/CANVAS.before" > "$c"
  _dm_commit "a registry with no row"
  _dm_sh "$(_dm_pull_walk row "$sub")"
  { [ "$_dm_rc" -eq 0 ] && grep -F '| UX-004 | New.dc.html |' "$c" >/dev/null; } || cf "(d) the row block adds nothing to an empty registry (exit $_dm_rc): $_dm_out"
  _dm_sh "$(_dm_pull_walk place)"
  _dm_sh "$(_dm_pull_walk check)"
  _dm_has "$_dm_out" "#00ff00" || cf "(d) with the row in an empty registry the check does not name the literal: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_sh "$(_dm_pull_walk undo)"
  # (e) no registry table at all: the block stops, says why and changes nothing
  grep -v '^|' "$SB_TMP/CANVAS.before" > "$c"
  _dm_commit "no registry table"
  cp "$c" "$SB_TMP/CANVAS.notable"
  _dm_sh "$(_dm_pull_walk row "$sub")"
  { [ "$_dm_rc" -ne 0 ] && _dm_has "$_dm_out" "NO-ROW"; } || cf "(e) a canvas record with no registry table is not refused with NO-ROW (exit $_dm_rc): $_dm_out"
  cmp -s "$SB_TMP/CANVAS.notable" "$c" || cf "(e) the refused row block changed CANVAS.md"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE LINK CHECK READS A TAG WHOSE QUOTED VALUE HOLDS A `>`, STALES AN APPROVAL ON A CHANGE OF BYTES THE TEXT READ HIDES, FOLLOWS A
# CANVAS MOVED TOGETHER WITH AN EDIT, AND NAMES WHAT TO RUN WHEN A SHA IS PAST A SHALLOW CLONE.
#   Operand: scripts/design/check-design-links.py over the links fixture plus one screen of each shape, each answer fixed in the case.
# =============================================================================
case_the_link_check_reads_a_quoted_gt_in_a_tag_stales_a_byte_change_follows_a_move_with_an_edit_and_names_the_unshallow_fetch() {
  cf_reset
  local L="check-design-links.py reads the style and the href of a tag whose earlier attribute holds a '>' inside quotes (a colour literal outside :root is found, a linked sheet that changes stales the approval), stales an approval when only the invalid bytes differ, says an artboard that moved with an edit differs at HEAD rather than that it is missing, and tells an unresolved sha to fetch the history"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_links_fixture || { finish "$L"; teardown; return; }
  local D="$SB_WORK/requirements/design/app/project" C="$SB_WORK/requirements/design/app/CANVAS.md" W V X5
  # (a) a colour literal after a '>' inside a quoted value
  printf '| UX-003 | C.dc.html | t | phone |  | default | PRD-001-F1-S2 | open | open |\n' >> "$C"
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' '<h1 id="ux-003-title" title="a>b" style="color: #ff0000">Lit</h1>'
  _dm_commit "a tag with a > in a quoted value"
  _dm_py scripts/design/check-design-links.py
  _dm_has "$_dm_out" "LITERAL-COLOUR requirements/design/app/project/C.dc.html: #ff0000" || cf "(a) a colour literal in the style of a tag whose title holds a '>' is not found: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  # (b) the same shape on a link: the sheet it names is part of what the approval covers
  printf 'h1 { margin: 16px }\n' > "$D/s.css"
  _dm_art "$D/D.dc.html" 004 '--color-primary: #485d92;' '<link title="a>b" rel="stylesheet" href="s.css"><h1 id="ux-004-title" style="color: var(--color-primary)">Sheet</h1>'
  printf '| UX-004 | D.dc.html | t | phone |  | default | PRD-001-F1-S2 | open | open |\n' >> "$C"
  _dm_commit "a screen that links a sheet"; W="$_DM_SHA"
  _dm_edit "$C" "s/^\\(| UX-004 .*\\)| open | open |\$/\\1| approved@$W | open |/"
  _dm_commit "approve UX-004"
  printf 'h1 { margin: 90px }\n' > "$D/s.css"
  _dm_commit "the sheet changes"
  _dm_py scripts/design/check-design-links.py
  _dm_has "$_dm_out" "UX-004 gate1 approved@${W:0:7}, but s.css differs at HEAD" || cf "(b) a sheet linked by a tag whose title holds a '>' changing after the approval does not stale it naming s.css: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  # (c) two different invalid byte sequences read as one text
  _dm_art "$D/E.dc.html" 005 '--color-primary: #485d92;' "$(printf '<h1 id="ux-005-title">a\377b</h1>')"
  printf '| UX-005 | E.dc.html | t | phone |  | default | PRD-001-F1-S2 | open | open |\n' >> "$C"
  _dm_commit "a screen with an invalid byte"; V="$_DM_SHA"
  _dm_edit "$C" "s/^\\(| UX-005 .*\\)| open | open |\$/\\1| approved@$V | open |/"
  _dm_commit "approve UX-005"
  _dm_py scripts/design/check-design-links.py
  _dm_has "$_dm_out" "UX-005 gate1 approved@${V:0:7}" && cf "(c) the approval of UX-005 reads stale before anything changed"
  perl -pi -e 's/\xff/\xfe/' "$D/E.dc.html"
  _dm_commit "the invalid byte changes"
  _dm_py scripts/design/check-design-links.py
  _dm_has "$_dm_out" "UX-005 gate1 approved@${V:0:7}, but" || cf "(c) a change from one invalid byte to another leaves the approval good: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  # (d) a sha nothing here holds, as a shallow clone sees an old one
  printf '| UX-006 | F.dc.html | t | phone |  | default | PRD-001-F1-S2 | approved@deadbee | open |\n' >> "$C"
  _dm_commit "an approval past the history"
  _dm_py scripts/design/check-design-links.py
  { _dm_has "$_dm_out" "APPROVAL-UNRESOLVED" && _dm_has "$_dm_out" "git fetch --unshallow"; } || cf "(d) an approval at a sha this clone lacks does not name git fetch --unshallow: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  # (f) a quote that is not after '=' opens no string: an apostrophe in an unquoted value, a stray double quote in an attribute name
  _dm_art "$D/H.dc.html" 008 '--color-primary: #485d92;' "<div id=\"ux-008-d\" title=Bob's style=\"color: #ff0000\">Hi</div>"
  _dm_art "$D/I.dc.html" 009 '--color-primary: #485d92;' '<h1 id="ux-009-title" data-x"y style="color: #00ff00">Lit</h1>'
  printf 't { margin: 1px }\n' > "$D/t.css"
  _dm_art "$D/J.dc.html" 010 '--color-primary: #485d92;' "<div id=\"ux-010-d\" title=Bob's></div><link rel=stylesheet href=t.css><p id=\"ux-010-p\">It's > 3</p>"
  printf '| UX-008 | H.dc.html | t | phone |  | default | PRD-001-F1-S2 | open | open |\n| UX-009 | I.dc.html | t | phone |  | default | PRD-001-F1-S2 | open | open |\n| UX-010 | J.dc.html | t | phone |  | default | PRD-001-F1-S2 | open | open |\n' >> "$C"
  _dm_commit "tags with a quote that is not after an equals sign"; X5="$_DM_SHA"
  _dm_edit "$C" "s/^\\(| UX-010 .*\\)| open | open |\$/\\1| approved@$X5 | open |/"
  _dm_commit "approve UX-010"
  printf 't { margin: 90px }\n' > "$D/t.css"
  _dm_commit "the sheet after the apostrophe changes"
  _dm_py scripts/design/check-design-links.py
  _dm_has "$_dm_out" "LITERAL-COLOUR requirements/design/app/project/H.dc.html: #ff0000" || cf "(f) a colour literal in a tag with an apostrophe in an unquoted value is not found: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_has "$_dm_out" "LITERAL-COLOUR requirements/design/app/project/I.dc.html: #00ff00" || cf "(f) a colour literal in a tag with a stray double quote in an attribute name is not found: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_has "$_dm_out" "UX-010 gate1 approved@${X5:0:7}, but t.css differs at HEAD" || cf "(f) a sheet linked after a tag with an apostrophe in an unquoted value changing after the approval does not stale it naming t.css: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  # (g) the gate's own line for a pin that is not a commit
  _dm_card 905 in_progress "design: [UX-001#default@deadbee]"
  _dm_commit "a card pinned past the history"
  _dm_py scripts/design/check-design-links.py
  _dm_line_has "$_dm_out" "UNRESOLVED" "pin @deadbee of UX-001#default is not a commit. Next: \`git fetch --unshallow\`" || cf "(g) the UNRESOLVED line for a pin that is not a commit does not name git fetch --unshallow: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  # (e) the canvas directory moves in the same commit that edits an approved artboard
  git -C "$SB_WORK" mv requirements/design/app requirements/design/app2
  _dm_edit "$SB_WORK/requirements/design/app2/project/A.dc.html" 's|>List<|>Lists<|'
  _dm_commit "the canvas moves with an edit"
  _dm_py scripts/design/check-design-links.py
  _dm_has "$_dm_out" "UX-001 gate1 approved@${_DM_X:0:7}, but" || cf "(e) the approval of an artboard moved with an edit is not judged: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  _dm_has "$_dm_out" "missing at that commit" && cf "(e) an artboard moved together with an edit reads missing at that commit"
  _dm_has "$_dm_out" "UX-005 gate1 approved@${V:0:7}, but" || cf "(e) a moved artboard whose invalid byte changed leaves the approval good: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — pin-drift.py RESOLVES AN ALIAS INSIDE A STRING, DOES NOT CALL TWO INVALID BYTE SEQUENCES BOOKKEEPING, CLOSES AN OPEN td, tr AND
# li WHEN THE NEXT ONE STARTS, SAYS A SCREEN IS SUPERSEDED, AND NAMES THE UNSHALLOW FETCH FOR A PIN IT CANNOT SEE.
#   Operand: scripts/design/pin-drift.py over a pin commit and one later commit; every screen has one fixed answer, written in the case.
# =============================================================================
case_pin_drift_reads_an_embedded_alias_invalid_bytes_an_unclosed_cell_a_superseded_screen_and_a_pin_past_a_shallow_clone() {
  cf_reset
  local L="pin-drift.py reads a changed alias inside a longer token value as drift, a change between two invalid byte sequences as uncompared, a shared element after an unclosed td, tr or li as outside the state's branch (drift for the other state), prints (screen superseded) on a retired screen's line and names git fetch --unshallow for a pin that is not a commit"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _md_sandbox
  _md_mod enable design
  [ "$_md_rc" -eq 0 ] || { cf "enable exited $_md_rc: $_md_out"; finish "$L"; teardown; return; }
  _dm_land "enable the design module"
  local D="$SB_WORK/requirements/design/app/project" r p p7 c="$SB_PREFIX-801" n
  _dm_tokens '{"shadow":{"card":{"$value":"0 0 1px {base.c}"}}}'
  _dm_tokens '{"base":{"c":{"$value":"#111111"}}}' base.tokens.json
  _dm_art "$D/A.dc.html" 001 '' '<h1 id="ux-001-title" style="box-shadow: var(--shadow-card)">Alias</h1>'
  _dm_art "$D/B.dc.html" 002 '' "$(printf '<h1 id="ux-002-title">a\377b</h1>')"
  _dm_art "$D/T3.dc.html" 003 '' '<table><tr><td data-state="a">alpha<td data-state="b">beta<td id="ux-003-shared">Shared</table>'
  _dm_art "$D/T4.dc.html" 004 '' '<ul><li data-state="a">alpha<li data-state="b">beta<li id="ux-004-shared">Shared</ul>'
  _dm_art "$D/T5.dc.html" 005 '' '<table><tr data-state="a"><td>alpha<tr data-state="b"><td>beta<tr><td id="ux-005-shared">Shared</table>'
  _dm_art "$D/F.dc.html" 006 '' '<h1 id="ux-006-title">Retired</h1>'
  _dm_art "$D/T8.dc.html" 008 '' '<ul><li data-state="a">alpha<section><li id="ux-008-shared">Shared</section></ul>'
  _dm_art "$D/T9.dc.html" 009 '' '<dl><dt data-state="a">alpha<dd data-state="b">beta<dd id="ux-009-shared">Shared</dl>'
  _dm_art "$D/T10.dc.html" 010 '' '<select><option data-state="a">alpha<option data-state="b">beta<option id="ux-010-shared">Shared</select>'
  _dm_art "$D/T11.dc.html" 011 '' '<ruby>x<rt data-state="a">alpha<rt data-state="b">beta<rt id="ux-011-shared">Shared</ruby>'
  _dm_art "$D/G.dc.html" 007 '' '<h1 id="ux-007-title">Plain</h1>'
  _dm_registry "$SB_WORK/requirements/design/app" \
    'UX-001|A.dc.html|default|PRD-001-F1-S1|open|open' 'UX-002|B.dc.html|default|PRD-001-F1-S1|open|open' \
    'UX-003|T3.dc.html|a, b|PRD-001-F1-S1|open|open' 'UX-004|T4.dc.html|a, b|PRD-001-F1-S1|open|open' \
    'UX-005|T5.dc.html|a, b|PRD-001-F1-S1|open|open' 'UX-006|F.dc.html|default|PRD-001-F1-S1|open|open' \
    'UX-007|G.dc.html|default|PRD-001-F1-S1|open|open' 'UX-008|T8.dc.html|a, b|PRD-001-F1-S1|open|open' \
    'UX-009|T9.dc.html|a, b|PRD-001-F1-S1|open|open' 'UX-010|T10.dc.html|a, b|PRD-001-F1-S1|open|open' 'UX-011|T11.dc.html|a, b|PRD-001-F1-S1|open|open'
  _dm_commit "the design at its pin"; p="$_DM_SHA"; p7="${p:0:7}"
  _dm_card 801 in_progress "design: [UX-001#default@$p, UX-002#default@$p, UX-003#b@$p, UX-004#b@$p, UX-005#b@$p, UX-006#default@$p, UX-007#default@$p, UX-008#b@$p, UX-009#b@$p, UX-010#b@$p, UX-011#b@$p, UX-099#default@deadbee]"
  _dm_commit "pin the card"
  _dm_tokens '{"base":{"c":{"$value":"#222222"}}}' base.tokens.json
  perl -pi -e 's/\xff/\xfe/' "$D/B.dc.html"
  for n in 3 4 5 8 9 10 11; do _dm_edit "$D/T$n.dc.html" 's|>Shared<|>Shared two<|'; done
  _dm_edit "$SB_WORK/requirements/design/app/CANVAS.md" 's/^\(| UX-006 .*\)| open | open |$/\1| open | superseded |/'
  _dm_commit "the design moves on"
  _dm_py scripts/design/pin-drift.py
  r="$(_dm_row "$_dm_out" "$c" "UX-001#default@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-001#default@$p7")" = drift ] && _dm_has "$r" "tokens: --shadow-card"; } || cf "(a) UX-001, whose token holds {base.c} inside a longer value and base.c changed, does not read drift on --shadow-card: $r"
  r="$(_dm_row "$_dm_out" "$c" "UX-002#default@$p7")"
  [ "$(_dm_verdict "$_dm_out" "$c" "UX-002#default@$p7")" = uncompared ] || cf "(b) UX-002, whose invalid byte became another, does not read uncompared: $r"
  _dm_has "$r" "registry bookkeeping" && cf "(b) UX-002 is called registry bookkeeping: $r"
  for n in 3 4 5; do
    r="$(_dm_row "$_dm_out" "$c" "UX-00$n#b@$p7")"
    { [ "$(_dm_verdict "$_dm_out" "$c" "UX-00$n#b@$p7")" = drift ] && _dm_has "$r" "~ux-00$n-shared"; } || cf "(c) UX-00$n#b, whose shared element follows an unclosed cell of state a, does not read drift on it: $r"
  done
  r="$(_dm_row "$_dm_out" "$c" "UX-006#default@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-006#default@$p7")" = clean ] && _dm_has "$r" "(screen superseded). Next: re-pin to the row that replaces it"; } || cf "(d) UX-006, superseded at HEAD, does not read clean with (screen superseded) on its line: $r"
  r="$(_dm_row "$_dm_out" "$c" "UX-007#default@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-007#default@$p7")" = clean ] && ! _dm_has "$r" "superseded"; } || cf "(d) UX-007, not superseded, does not read clean without the mark: $r"
  r="$(_dm_row "$_dm_out" "$c" "UX-008#b@$p7")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-008#b@$p7")" = clean ] && _dm_has "$r" "changed only under other states"; } || cf "(f) UX-008#b, whose shared li sits in a section inside state a's li, is not set aside with state a: $r"
  for n in 009 010 011; do
    r="$(_dm_row "$_dm_out" "$c" "UX-$n#b@$p7")"
    { [ "$(_dm_verdict "$_dm_out" "$c" "UX-$n#b@$p7")" = drift ] && _dm_has "$r" "~ux-$n-shared"; } || cf "(f) UX-$n#b, whose shared element follows an unclosed dd, option or rt of state a, does not read drift on it: $r"
  done
  r="$(_dm_row "$_dm_out" "$c" "UX-099#default@deadbee")"
  { [ "$(_dm_verdict "$_dm_out" "$c" "UX-099#default@deadbee")" = unresolved ] && _dm_has "$r" "git fetch --unshallow"; } || cf "(e) a pin that is not a commit does not name git fetch --unshallow: $r"
  _dm_py scripts/design/pin-drift.py --help
  { _dm_has "$_dm_out" "(screen superseded)" && _dm_has "$_dm_out" "invalid"; } || cf "(g) the usage text names neither the superseded suffix nor the invalid-bytes reason: $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A WIREFRAME CANVAS DOES NOT BORROW THE TEXT OF A SAME-NAMED SCREEN OF ANOTHER UX ID AS THE ONE IT WAS APPROVED AT.
#   Operand: check-design-links.py over the wireframe fixture plus a screen whose file name a deleted canvas also held, with an equal structure.
# =============================================================================
case_a_wireframe_approval_is_not_lent_by_a_deleted_screen_of_another_ux_id_that_shared_the_file_name() {
  cf_reset
  local L="a wireframe approval at a commit where the row's own file is absent is not carried by a same-named file of another UX id that is gone since (STALE-APPROVAL, not a good approval or a CONTENT-ONLY line)"
  _dm_wire_guards "$L" || return
  _dm_wire_fixture || { finish "$L"; teardown; return; }
  local D="$SB_WORK/requirements/design/app/project" O="$SB_WORK/requirements/design/other" S
  _dm_art "$O/project/Z.dc.html" 009 '--color-primary: #485d92;' '<h1 id="ux-009-title">One</h1>'
  _dm_registry "$O" 'UX-009|Z.dc.html|default|PRD-001-F1-S2|open|open'
  _dm_commit "another canvas holds a screen named Z"; S="$_DM_SHA"
  git -C "$SB_WORK" rm -rq requirements/design/other
  _dm_art "$D/Z.dc.html" 009 '--color-primary: #485d92;' '<h1 id="ux-009-title">Two</h1>'
  printf '| UX-007 | Z.dc.html | t | phone |  | default | PRD-001-F1-S2 | approved@%s | open |\n' "$S" >> "$SB_WORK/requirements/design/app/CANVAS.md"
  _dm_commit "the other canvas is gone and UX-007 names a Z of its own"
  _dm_py scripts/design/check-design-links.py
  _dm_line_has "$_dm_out" "STALE-APPROVAL" "UX-007 gate1 approved@${S:0:7}" || cf "(a) UX-007's approval is carried by another UX id's file of the same name: $(_dm_brief 400)"
  _dm_line_has "$_dm_out" "CONTENT-ONLY" "UX-007" && cf "(a) UX-007 reads CONTENT-ONLY from another UX id's file"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A PAGE SAVE'S RE-SPELLING OF data-props MOVES NO VALUE, AND A .wire TOKEN FILE IS NOT WHAT A PIN OR AN APPROVAL COVERS.
#   Operand: check-design-links.py --strict and pin-drift.py over a screen approved and pinned with its data-props single-quoted, then
#   re-saved in the editor's `&quot;` form, then with spaces: no STALE-APPROVAL, no drift. A changed value still is both. A
#   <ns>.wire.tokens.json that appears or changes after the pin moves nothing; a base token that changes still does.
# =============================================================================
_dm_props_art() {  # <path> <data-props attribute, as written> — screen UX-001 with a component script carrying it
  _dm_art "$1" 001 '--color-primary: #485d92;' '<h1 id="ux-001-title" style="color: var(--color-primary)"><a href="B.dc.html#top">List</a></h1>'
  printf '<script type="text/x-dc" data-dc-script %s>\nclass Component extends DCLogic {}\n</script>\n' "$2" >> "$1"
}
case_a_page_save_re_spelling_data_props_reads_as_no_change_and_a_wire_token_is_not_covered_by_a_pin() {
  cf_reset
  local L="a board whose data-props a page save rewrote to the &quot; form, or with spaces, keeps its approval and reads clean in pin-drift (a changed value still reads STALE-APPROVAL and drift), and a <ns>.wire.tokens.json that appears or changes after the approval and the pin moves neither, while a base token that changes still does"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_links_fixture || { finish "$L"; teardown; return; }
  local D="$SB_WORK/requirements/design/app/project" P0 P
  P0="data-props='{\"view\":{\"default\":\"list\",\"options\":[\"list\",\"empty\"]},\"t\":\"a&amp;b\"}'"
  _dm_props_art "$D/A.dc.html" "$P0"
  _dm_tokens '{"color":{"primary":{"$value":"#777777"},"surface":{"$value":"#ffffff"}}}' app.wire.tokens.json
  _dm_commit "the screen carries props, and a greyscale token file exists at the pin"; P="$_DM_SHA"
  _dm_registry "$SB_WORK/requirements/design/app" "UX-001|A.dc.html|default, empty|PRD-001-F1-S1|approved@$P|open" 'UX-002|B.dc.html|default|PRD-001-F1-S2|open|open'
  _dm_card 851 in_progress "design: [UX-001#default@$P]"
  _dm_commit "approve UX-001 and pin a card to it"
  _dm_py scripts/design/check-design-links.py --strict
  [ "$_dm_rc" -eq 0 ] || cf "(a0) the approval is not good straight after it is given (exit $_dm_rc): $(_dm_brief 300)"
  _dm_py scripts/design/pin-drift.py
  [ "$(_dm_verdict "$_dm_out" "$SB_PREFIX-851" "UX-001#default@${P:0:7}")" = clean ] || cf "(a0) the pin does not read clean straight after it is made: $(_dm_brief 300)"
  # (a) the editor's re-save: double quotes, &quot; for every quote, the same values
  _dm_props_art "$D/A.dc.html" 'data-props="{&quot;view&quot;:{&quot;default&quot;:&quot;list&quot;,&quot;options&quot;:[&quot;list&quot;,&quot;empty&quot;]},&quot;t&quot;:&quot;a&amp;b&quot;}"'
  _dm_commit "a page save re-spells data-props"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "STALE-APPROVAL"; } || cf "(a) a re-save that moved no value stales the approval (exit $_dm_rc): $(_dm_brief 300)"
  _dm_py scripts/design/pin-drift.py
  [ "$(_dm_verdict "$_dm_out" "$SB_PREFIX-851" "UX-001#default@${P:0:7}")" = clean ] || cf "(a) a re-save that moved no value reads as drift: $(_dm_brief 300)"
  # (b) the same values with spaces inside the quotes
  _dm_props_art "$D/A.dc.html" "data-props='{ \"view\": { \"default\": \"list\", \"options\": [ \"list\", \"empty\" ] }, \"t\": \"a&amp;b\" }'"
  _dm_commit "the props with spaces"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "STALE-APPROVAL"; } || cf "(b) props with spaces and the same values stale the approval (exit $_dm_rc): $(_dm_brief 300)"
  _dm_py scripts/design/pin-drift.py
  [ "$(_dm_verdict "$_dm_out" "$SB_PREFIX-851" "UX-001#default@${P:0:7}")" = clean ] || cf "(b) props with spaces and the same values read as drift: $(_dm_brief 300)"
  # (c) a value that moved is still both
  _dm_props_art "$D/A.dc.html" "data-props='{\"view\":{\"default\":\"list\",\"options\":[\"list\",\"empty\",\"error\"]},\"t\":\"a&amp;b\"}'"
  _dm_commit "a value in the props moves"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "STALE-APPROVAL"; } || cf "(c) a changed prop does not stale the approval (exit $_dm_rc): $(_dm_brief 300)"
  _dm_py scripts/design/pin-drift.py
  [ "$(_dm_verdict "$_dm_out" "$SB_PREFIX-851" "UX-001#default@${P:0:7}")" = drift ] || cf "(c) a changed prop does not read as drift: $(_dm_brief 300)"
  git -C "$SB_WORK" checkout -q "$P" -- requirements/design/app/project/A.dc.html >/dev/null 2>&1
  _dm_commit "the props are back"
  # (d) a wireframe token file that appears, then changes, after the pin
  _dm_tokens '{"color":{"primary":{"$value":"#888888"},"surface":{"$value":"#ffffff"}}}' other.wire.tokens.json
  _dm_commit "a second greyscale token file appears"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "STALE-APPROVAL"; } || cf "(d) a .wire token file appearing after the pin stales the approval (exit $_dm_rc): $(_dm_brief 300)"
  _dm_py scripts/design/pin-drift.py
  [ "$(_dm_verdict "$_dm_out" "$SB_PREFIX-851" "UX-001#default@${P:0:7}")" = clean ] || cf "(d) a .wire token file appearing after the pin reads as drift: $(_dm_brief 300)"
  _dm_tokens '{"color":{"primary":{"$value":"#666666"},"surface":{"$value":"#ffffff"}}}' app.wire.tokens.json
  _dm_commit "a greyscale tweak"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "STALE-APPROVAL"; } || cf "(d) a .wire token the pin held, changing, stales the approval (exit $_dm_rc): $(_dm_brief 300)"
  _dm_py scripts/design/pin-drift.py
  [ "$(_dm_verdict "$_dm_out" "$SB_PREFIX-851" "UX-001#default@${P:0:7}")" = clean ] || cf "(d) a .wire token the pin held, changing, reads as drift: $(_dm_brief 300)"
  # (e) the base token still counts
  _dm_tokens '{"color":{"primary":{"$value":"#3b4f82"},"surface":{"$value":"#ffffff"}}}'
  _dm_commit "the brand token changes"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "STALE-APPROVAL"; } || cf "(e) a base token changing no longer stales the approval (exit $_dm_rc): $(_dm_brief 300)"
  _dm_py scripts/design/pin-drift.py
  [ "$(_dm_verdict "$_dm_out" "$SB_PREFIX-851" "UX-001#default@${P:0:7}")" = drift ] || cf "(e) a base token changing no longer reads as drift: $(_dm_brief 300)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A THEME'S VALUE IN :root OR A MEDIA QUERY IS A TOKEN-VALUE THAT SAYS A THEME IS A data-theme BLOCK, AND A BARE dark.tokens.json IS THE DARK THEME.
#   Operand: check-design-links.py over screens whose :root, `@media (prefers-color-scheme: dark)` or `[data-theme="dark"]` block holds
#   dark's value. In a media query: a TOKEN-VALUE line that names data-theme. With a bare `dark.tokens.json` (no <ns>.) beside the base
#   file: the data-theme block is compared and agrees (no UNCOMPARED), and dark's value in :root is a TOKEN-VALUE.
# =============================================================================
case_a_theme_in_a_media_query_says_data_theme_and_a_bare_dark_token_file_is_the_dark_theme() {
  cf_reset
  local L="a dark value in a prefers-color-scheme media query is a TOKEN-VALUE line that says a theme is a [data-theme] block with its own token file, and a token file named dark.tokens.json alone is the dark theme: a [data-theme=\"dark\"] block holding its value is compared (no UNCOMPARED) and :root holding its value is a TOKEN-VALUE"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_links_fixture || { finish "$L"; teardown; return; }
  local D="$SB_WORK/requirements/design/app/project" C="$SB_WORK/requirements/design/app/CANVAS.md"
  # (a) a media query holds dark's value
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' '<style>@media (prefers-color-scheme: dark) { :root { --color-primary: #a0b4e8; } }</style><h1 id="ux-003-title">Media</h1>'
  printf '| UX-003 | C.dc.html | t | phone |  | default | PRD-001-F1-S2 | open | open |\n' >> "$C"
  _dm_commit "a screen with dark's value in a media query"
  _dm_py scripts/design/check-design-links.py
  _dm_line_has "$_dm_out" "TOKEN-VALUE" "C.dc.html" || cf "(a) a dark value in a media query is no TOKEN-VALUE: $(_dm_brief 300)"
  _dm_line_has "$_dm_out" "TOKEN-VALUE" 'data-theme' || cf "(a) the TOKEN-VALUE line does not say a theme is a [data-theme] block: $(_dm_brief 400)"
  # (b) a bare dark.tokens.json
  git -C "$SB_WORK" rm -q -f requirements/design/tokens/app.dark.tokens.json >/dev/null 2>&1
  _dm_tokens '{"color":{"primary":{"$value":"#a0b4e8"},"surface":{"$value":"#121318"}}}' dark.tokens.json
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' '<h1 id="ux-003-title">Plain</h1>'
  _dm_art "$D/D.dc.html" 004 '--color-primary: #485d92;' '<style>[data-theme="dark"] { --color-primary: #a0b4e8; }</style><h1 id="ux-004-title">Dark block</h1>'
  _dm_art "$D/E.dc.html" 005 '--color-primary: #a0b4e8;' '<h1 id="ux-005-title">Dark value in root</h1>'
  printf '| UX-004 | D.dc.html | t | phone |  | default | PRD-001-F1-S2 | open | open |\n| UX-005 | E.dc.html | t | phone |  | default | PRD-001-F1-S2 | open | open |\n' >> "$C"
  _dm_commit "a bare dark token file"
  _dm_py scripts/design/check-design-links.py
  _dm_line_has "$_dm_out" "UNCOMPARED" "D.dc.html" && cf "(b) a [data-theme=\"dark\"] block is UNCOMPARED beside a dark.tokens.json: $(_dm_brief 400)"
  _dm_line_has "$_dm_out" "TOKEN-VALUE" "D.dc.html" && cf "(b) a [data-theme=\"dark\"] block holding dark's value is a TOKEN-VALUE beside a dark.tokens.json: $(_dm_brief 400)"
  _dm_line_has "$_dm_out" "TOKEN-VALUE" "E.dc.html" || cf "(b) dark's value in :root is accepted although a dark.tokens.json holds it: $(_dm_brief 400)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A DESIGN PIN MUST BE A COMMIT THE TRUNK HOLDS WHEN THE CARD LANDS; A LOCAL-ONLY PIN IS REFUSED WITH A WAY OUT.
#   Operand: the design rows check (scripts/move-check.d/qa_complete/50-design-rows.sh, which runs scripts/design/check-design-cell.py
#   --rows) over a card whose design row is complete. Pinned to a commit on the trunk: allowed. Pinned to a commit only a local side
#   branch holds: refused (status 3) with a Next: that says to push it or re-pin.
# =============================================================================
case_a_design_pin_must_be_a_commit_the_trunk_holds_at_landing_and_a_local_only_pin_is_refused_with_a_next() {
  cf_reset
  local L="the design rows check allows a card whose design: pin is a commit the trunk holds, and refuses (status 3) one pinned to a commit only a local branch holds, saying the pin is on no commit the trunk holds and giving a Next: that says to push it or have the PM re-pin"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_links_fixture || { finish "$L"; teardown; return; }
  local id="$SB_PREFIX-862" P Q card hook trunk rc out
  _dm_png "$SB_WORK/requirements/design/app/renders/A-default.png" LIST
  _dm_png "$SB_WORK/requirements/design/app/renders/B-default.png" EDIT
  _dm_land "renders at the pin"; P="$(git -C "$SB_WORK" rev-parse HEAD)"
  # a commit only a side branch holds: another render of the same screen, never pushed
  git -C "$SB_WORK" checkout -q -b dm-side-branch "$SB_TRUNK" >/dev/null 2>&1
  _dm_png "$SB_WORK/requirements/design/app/renders/A-default.png" EDIT
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[PM] $_MD_ID: a render nobody pushed" >/dev/null 2>&1
  Q="$(git -C "$SB_WORK" rev-parse HEAD)"
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1
  seed_issue dev_complete "$id" pinned chore "A card with a screen"
  card="$SB_WORK/progress/dev_complete/$id-pinned.md"
  PIN="$P" perl -0pi -e 's/(forks: none\n)/$1design: [UX-001#default\@$ENV{PIN}]\n/; s/(- \[ \] AC1 — [^\n]*\n)/$1- [ ] AC2 — (UI) from PRD-001-F1-S1: the list shows. [design: UX-001#default]\n/; s/(\| shadow-check )/| AC2 | PASS | design | UX-001#default\@$ENV{PIN}: identical; x |\n$1/' "$card"
  _dm_land "the card pinned to a trunk commit"
  hook="$SB_WORK/scripts/move-check.d/qa_complete/50-design-rows.sh"
  trunk="$(git -C "$SB_WORK" rev-parse "origin/$SB_TRUNK")"
  _dm_hook_rows() { rc=0; out="$( bash "$hook" "$id" dev_complete qa_complete QA "$card" "$SB_WORK" "$trunk" 2>&1 </dev/null )" || rc=$?; }
  _dm_hook_rows
  [ "$rc" -eq 0 ] || cf "(a) a pin on the trunk is refused (status $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  PIN="$P" NEW="$Q" perl -0pi -e 's/\@$ENV{PIN}/\@$ENV{NEW}/g' "$card"
  _dm_land "the card re-pinned to a local-only commit"
  trunk="$(git -C "$SB_WORK" rev-parse "origin/$SB_TRUNK")"
  _dm_hook_rows
  { [ "$rc" -eq 3 ] && _dm_has "$out" "${Q:0:7}" && _dm_has "$out" "on no commit the trunk holds"; } || cf "(b) a pin only a local branch holds is not refused for it (status $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"
  printf '%s\n' "$out" | grep -E '^Next: .*push' >/dev/null || cf "(b) the refusal's Next: does not say to push the pin: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"
  printf '%s\n' "$out" | grep -E '^Next: .*re-pin' >/dev/null || cf "(b) the refusal's Next: does not say to re-pin: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"
  # (b2) a card with a pin reason and a rows reason gets both Nexts
  perl -0pi -e 's/(- \[ \] AC2 — [^\n]*\n)/$1- [ ] AC3 — (UI) from PRD-001-F1-S1: an empty list. [design: UX-001#empty]\n/' "$card"
  _dm_land "the card cites a state no design row holds"
  trunk="$(git -C "$SB_WORK" rev-parse "origin/$SB_TRUNK")"
  _dm_hook_rows
  { [ "$rc" -eq 3 ] && [ "$(printf '%s\n' "$out" | grep -c '^Next:')" -eq 2 ] && _dm_has "$out" "AC3"; } || cf "(b2) a pin the trunk lacks and an AC with no design row do not each get a Next: (status $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-500)"
  perl -0pi -e 's/- \[ \] AC3 — [^\n]*\n//' "$card"
  _dm_land "the card cites no more than it has rows for"
  # (b3) a short sha that two commits share is said to be ambiguous, not "not a commit"
  awk 'BEGIN { for (n = 1; n <= 100000; n++) { m = "dm amb " n; printf "commit refs/heads/dm-amb\nmark :%d\ncommitter t <t@t> 1000000000 +0000\ndata %d\n%s\n", n, length(m), m; if (n > 1) printf "from :%d\n", n - 1; printf "\n" } }' | git -C "$SB_WORK" fast-import --quiet >/dev/null 2>&1
  local amb
  amb="$(git -C "$SB_WORK" rev-list dm-amb | cut -c1-7 | sort | uniq -d | head -1)"
  if [ -z "$amb" ]; then
    cf "(prereq) no two of 100000 commits share a 7-character prefix, so the ambiguous-pin row cannot run"
  else
    PIN="$Q" NEW="$amb" perl -0pi -e 's/\@$ENV{PIN}/\@$ENV{NEW}/g' "$card"
    _dm_land "the card pinned to a short sha two commits share"
    trunk="$(git -C "$SB_WORK" rev-parse "origin/$SB_TRUNK")"
    _dm_hook_rows
    { [ "$rc" -eq 3 ] && _dm_has "$out" "is ambiguous in this repository"; } || cf "(b3) a pin that is a prefix of two commits is not said to be ambiguous (status $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"
    PIN="$amb" NEW="$Q" perl -0pi -e 's/\@$ENV{PIN}/\@$ENV{NEW}/g' "$card"
    _dm_land "the card pinned to the local-only commit again"
  fi
  # the way out it names works: push the commit to the trunk, and the same check allows
  git -C "$SB_WORK" merge -q --no-edit dm-side-branch >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  trunk="$(git -C "$SB_WORK" rev-parse "origin/$SB_TRUNK")"
  _dm_hook_rows
  [ "$rc" -eq 0 ] || cf "(c) the pin is refused after the commit that holds it reached the trunk (status $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  # (f) a shallow clone that holds the pin and the trunk tip but not the history between them says to unshallow
  local shal="$SB_TMP/shal"
  git clone -q --depth 1 "file://$(git -C "$SB_WORK" remote get-url origin)" "$shal" >/dev/null 2>&1
  git -C "$shal" fetch -q --depth 1 origin "$Q" >/dev/null 2>&1
  trunk="$(git -C "$shal" rev-parse "origin/$SB_TRUNK")"
  rc=0; out="$( bash "$hook" "$id" dev_complete qa_complete QA "$card" "$shal" "$trunk" 2>&1 </dev/null )" || rc=$?
  { [ "$rc" -eq 3 ] && printf '%s\n' "$out" | grep -E '^  - .*on no commit the trunk holds.*cut off.*this clone is shallow.*git fetch --unshallow' >/dev/null; } || cf "(f) a pin a shallow clone cannot join to the trunk is not refused with the unshallow hint (status $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"
  printf '%s\n' "$out" | grep -E '^  - .*\): only a branch or a local checkout' >/dev/null && cf "(f) the shallow reason leads with the claim that only a branch or a local checkout has a pin that is on the trunk"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A CARD PARKED IN blocked/ WITH NO PIN IS NOT UNPINNED OR UNRESOLVED; ONE IN PROGRESS STILL IS.
#   Operand: check-design-links.py --strict and pin-drift.py over the same card on blocked/ and on in_progress/.
# =============================================================================
case_a_card_parked_in_blocked_without_a_pin_reads_neither_unpinned_nor_unresolved() {
  cf_reset
  local L="a card on blocked/ whose design: entry has no @<commit> is no UNPINNED finding in the link check and no unresolved row in pin-drift (it was parked from todo/ and is pinned when it leaves blocked/), while the same card on in_progress/ is both"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_links_fixture || { finish "$L"; teardown; return; }
  _dm_card 863 blocked "design: [UX-001#default]"
  _dm_commit "a card parked from todo, never pinned"
  _dm_py scripts/design/check-design-links.py --strict
  _dm_has "$_dm_out" "UNPINNED" && cf "(a) a card on blocked/ with no pin is an UNPINNED finding: $(_dm_brief 300)"
  _dm_py scripts/design/pin-drift.py
  _dm_has "$_dm_out" "$SB_PREFIX-863" && _dm_has "$_dm_out" "unresolved" && cf "(a) a card on blocked/ with no pin is an unresolved row in pin-drift: $(_dm_brief 300)"
  git -C "$SB_WORK" mv "progress/blocked/$SB_PREFIX-863-c.md" "progress/in_progress/$SB_PREFIX-863-c.md" >/dev/null 2>&1 || { mkdir -p "$SB_WORK/progress/in_progress"; git -C "$SB_WORK" mv "progress/blocked/$SB_PREFIX-863-c.md" "progress/in_progress/$SB_PREFIX-863-c.md"; }
  _dm_commit "the same card in progress"
  _dm_py scripts/design/check-design-links.py --strict
  _dm_has "$_dm_out" "UNPINNED" || cf "(b) (control) a card in progress with no pin is no UNPINNED finding: $(_dm_brief 300)"
  _dm_py scripts/design/pin-drift.py
  _dm_has "$_dm_out" "unresolved" || cf "(b) (control) a card in progress with no pin is no unresolved row: $(_dm_brief 300)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE MODULE'S DOCS SAY WHAT ITS TOOLS DO: --leaving TAKES A CARD'S PATH, TOKENS MAY BE GENERATED, THE GATE ROW NEEDS A GATES LINE,
#   DISABLE LEAVES CARDS IN FLIGHT PINNED, AND THE IGNORE LINES NAME THE PULL'S SCRATCH FOLDER.
#   Operand: the module's own files (SETUP.md, README.md, the Designer role, the requirements README, gitignore.txt, the release notes).
# =============================================================================
case_the_design_docs_state_what_leaving_takes_what_the_gate_row_needs_and_what_disable_leaves() {
  cf_reset
  local L="the module's docs say --leaving takes a card file (the card's path), that token files are written by hand or generated, that SETUP.md tells the adopter to add the gate row's GATES line, that disable leaves a card in flight pinned, that .cache/design/ is the pull's scratch folder, and the upgrade note's Verify line does not run the whole --strict gate"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  local M="$REAL_REPO_ROOT/modules/design" f text
  for f in _claude/roles/designer.md requirements/design/README.md; do
    text="$(cat "$M/$f")"
    _dm_has "$text" '--leaving <card>' && cf "(a) $f still writes --leaving <card>, which the check reads as a path"
    _dm_has "$text" '--leaving <card file>' || cf "(a) $f does not write --leaving <card file>"
  done
  _dm_has "$(sed -n '/^usage:/,/^  REPO_ROOT/p' "$M/scripts/design/check-design-links.py")" '--leaving CARD-FILE' || cf "(a) the checker's usage line does not say --leaving CARD-FILE"
  for f in _claude/roles/designer.md README.md; do
    _dm_has "$(cat "$M/$f")" 'written by hand,' && cf "(b) $f still says token files are written by hand, with no mention of the generator"
  done
  text="$(cat "$M/SETUP.md")"
  _dm_has "$text" 'GATES' || cf "(c) SETUP.md does not tell the adopter to add the gate row to the GATES array"
  _dm_has "$text" 'check-design-links.py --strict' || cf "(c) SETUP.md does not name the --strict command to add"
  _dm_has "$(cat "$M/README.md")" 'keeps its `design:` key' || cf "(d) the README does not say disable leaves a card in flight pinned"
  _dm_has "$(cat "$M/gitignore.txt")" "renderer's" && cf "(e) gitignore.txt calls .cache/design/ the renderer's cache, which render.py never reads"
  _dm_has "$(cat "$M/gitignore.txt")" "scratch" || cf "(e) gitignore.txt does not say .cache/design/ is the pull's scratch folder"
  text="$(sed -n '/^## \[0.3.0\]/,/^### Added/p' "$M/RELEASE-NOTES.md" | grep 'Verify:')"
  case "$text" in *"check-design-links.py --strict") cf "(f) the 0.3.0 Verify line runs the whole --strict gate and nothing else, so no upgrade finishes while any finding stands" ;; esac
  finish "$L"
}

# =============================================================================
# CASE — THE CARD READERS TAKE ANY AC ID THE CORE DOES, AND A SLICE'S DRIFT LINE NAMES THE SLICE.
#   Operand: check-design-links.py --strict over a card whose (UI) AC is `B1`, design: none; pin-drift.py over a slice pinned to a screen.
# =============================================================================
case_the_card_reader_takes_any_ac_id_and_a_slices_drift_line_names_the_slice() {
  cf_reset
  local L="a card whose (UI) AC has an id the core reads but AC<n> does not (B1) with design: none is a DESIGN-NONE finding, and pin-drift labels a slice's row with the slice's id, not its parent's"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_links_fixture || { finish "$L"; teardown; return; }
  local P="$_DM_Y" sl="$SB_PREFIX-864-s1" f
  # (a) a refactor card's behaviour id
  mkdir -p "$SB_WORK/progress/in_progress"
  printf -- '---\nid: %s-865\ntype: refactor\ntitle: t\nbranch: n/a\npr: null\ncreated_at: 2026-01-01\ncreated_by: PM\nforks: none\ndesign: none\n---\n\n# card\n\n## Behaviors Preserved\n\n- [ ] B1 — (UI) the list still shows.\n' "$SB_PREFIX" > "$SB_WORK/progress/in_progress/$SB_PREFIX-865-r.md"
  _dm_commit "a refactor card with a (UI) behaviour"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_line_has "$_dm_out" "DESIGN-NONE" "$SB_PREFIX-865-r.md"; } || cf "(a) a (UI) AC with the id B1 and design: none is no DESIGN-NONE finding (exit $_dm_rc): $(_dm_brief 300)"
  local v; v="$(sed -n '/^## \[0.3.0\]/,/^### Added/p' "$REAL_REPO_ROOT/modules/design/RELEASE-NOTES.md" | grep 'Verify:' | sed 's/^ *Verify: *//')"
  _dm_sh "$v"
  [ "$_dm_rc" -ne 0 ] || cf "(a2) the 0.3.0 Verify line passes while a card is a DESIGN-NONE finding"
  rm -f "$SB_WORK/progress/in_progress/$SB_PREFIX-865-r.md"
  # (b) a slice pinned to a screen that has drifted
  mkdir -p "$SB_WORK/progress/subtasks/$SB_PREFIX-864/in_progress"
  f="$SB_WORK/progress/subtasks/$SB_PREFIX-864/in_progress/$sl-walk.md"
  printf -- '---\nid: %s\ntype: slice\ntitle: t\nbranch: n/a\npr: null\ncreated_at: 2026-01-01\ncreated_by: PM\nforks: none\ndesign: [UX-001#default@%s]\n---\n\n# slice\n' "$sl" "$P" > "$f"
  _dm_edit "$SB_WORK/requirements/design/app/project/A.dc.html" 's|>List<|>Lists<|'
  _dm_commit "a slice pinned to a screen that then changes"
  _dm_py scripts/design/pin-drift.py
  [ "$(_dm_verdict "$_dm_out" "$sl" "UX-001#default@${P:0:7}")" = drift ] || cf "(b) the slice's drift row does not carry the slice's id $sl: $(_dm_brief 300)"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "STALE-APPROVAL"; } || cf "(b2) (prereq) the edit did not stale the approval: $(_dm_brief 300)"
  _dm_sh "$v"
  [ "$_dm_rc" -eq 0 ] || cf "(b2) the 0.3.0 Verify line fails on a stale approval alone, which the note says does not hold the upgrade (exit $_dm_rc): $(_dm_brief 300)"
  # (c) the bullets the core reads: a checkbox bullet, numbered or quoted; a plain bullet that mentions (UI) or cites a screen is no AC
  local cf2="$SB_TMP/h2card.md" mine core
  printf -- '---\nid: %s-866\ntype: chore\n---\n\n## Context\n\n- Note: the list is a (UI) concern, see the story.\n- Screen: [design: UX-001#default] is the one to read.\n\n## Acceptance Criteria\n\n- [ ] AC1 — (UI) the list shows.\n1. [ ] AC2 — (UI) a numbered AC.\n> - [ ] AC3 — (UI) a quoted AC.\n- [ ] B1 — (UI) a behaviour.\n- [ ] AC4 — a plain AC.\n\n```\n- [ ] AC9 — (UI) an example inside a code fence.\n```\n~~~\n- [ ] AC8 — (UI) a tilde-fenced example.\n~~~\n' "$SB_PREFIX" > "$cf2"
  _dm_py -c "import importlib.util; s = importlib.util.spec_from_file_location('c', 'scripts/design/check-design-links.py'); m = importlib.util.module_from_spec(s); s.loader.exec_module(m); print(' '.join(sorted(a for a, _ in m.card_facts(open('$cf2').read())[0])))"
  mine="$_dm_out"
  core="$( cd "$SB_WORK" && bash -c '. scripts/lib/refuse.sh; . scripts/config.sh; . scripts/lib/qa-gate.sh; _qav_ac_ids "$(cat "$1")"' _ "$cf2" 2>&1 | grep -v '^AC4$' | tr '\n' ' ' | sed 's/ $//')"
  [ "$mine" = "AC1 AC2 AC3 B1" ] || cf "(c) the module reads '$mine' as the (UI) ACs of a card whose ACs are AC1, a numbered AC2, a quoted AC3 and B1, with a Context bullet that says (UI), one that cites a screen and fenced example bullets: want 'AC1 AC2 AC3 B1'"
  [ "$mine" = "$core" ] || cf "(c) the module's AC reader ('$mine') and the core's ('$core') read different bullets"
  # (c2) the fence shapes of the core's fence-rule case: the module and the core read the same ids from each
  local shp m_ids c_ids m_open c_open
  for shp in $_fence_shapes; do
    _fence_shape "$shp" > "$cf2"
    _dm_py -c "import importlib.util; s = importlib.util.spec_from_file_location('c', 'scripts/design/check-design-links.py'); m = importlib.util.module_from_spec(s); s.loader.exec_module(m); print(' '.join(sorted(a for a, _ in m.card_facts(open('$cf2').read())[0])))"
    m_ids="$_dm_out"
    c_ids="$( cd "$SB_WORK" && bash -c '. scripts/lib/refuse.sh; . scripts/config.sh; . scripts/lib/qa-gate.sh; _qav_ac_ids "$(cat "$1")"' _ "$cf2" 2>&1 | tr '\n' ' ' | sed 's/ $//')"
    [ "$m_ids" = "$c_ids" ] || cf "(c2) fence shape '$shp': the module reads '$m_ids' and the core '$c_ids'"
    # the line a fence opened on that nothing closes: the module's scan of the file (frontmatter included) and the core's of the body
    _dm_py -c "import importlib.util; s = importlib.util.spec_from_file_location('c', 'scripts/design/check-design-links.py'); m = importlib.util.module_from_spec(s); s.loader.exec_module(m); print(m.fence_scan(open('$cf2').read())[1] or '')"
    m_open="$_dm_out"
    c_open="$( cd "$SB_WORK" && bash -c '. scripts/lib/refuse.sh; . scripts/config.sh; . scripts/lib/qa-gate.sh; _qav_unclosed_fence "$(cat "$1")"' _ "$cf2" 2>&1 | cut -d' ' -f1)"
    [ "$m_open" = "$c_open" ] || cf "(c2) fence shape '$shp': the module finds the unclosed fence at '$m_open' and the core at '$c_open'"
  done
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE AUDIT READS A TARGET'S SIZE AS THE BROWSER DOES AND A TOKEN PAIR IN ITS OWN NAMESPACE, AND KEEPS AN UNPAIRED OVERLAY OUT OF UNREAD.
#   Operand: scripts/design/contrast-audit.py over token files and one board built here; every answer is fixed in the case.
# =============================================================================
case_the_audit_reads_a_targets_size_as_the_browser_does_a_pair_in_its_own_namespace_and_no_unpaired_overlay_as_unread() {
  cf_reset
  local L="contrast-audit.py takes the larger of height and min-height, adds the padding of a content-box element, leaves a hidden input out, measures each token namespace's pairs apart (a failing pair in one is not hidden by another's), and reads an overlay colour that is in no pair (an 8-digit hex, rgba(), color-mix()) as no UNREAD, while a paired one with an alpha still is"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _md_sandbox
  local m="$REAL_REPO_ROOT/modules/design/scripts/design" d="$SB_TMP/au" t
  t="$d/requirements/design/tokens"
  mkdir -p "$t" "$d/requirements/design/app/project"
  printf '%s\n' '{"color":{"surface":{"$value":"#ffffff"},"on-surface":{"$value":"#eeeeee"}}}' > "$t/a.tokens.json"
  printf '%s\n' '{"color":{"surface":{"$value":"#ffffff"},"on-surface":{"$value":"#000000"}}}' > "$t/b.tokens.json"
  cat > "$d/requirements/design/app/project/A.dc.html" <<'EOF'
<x-dc>
<button id="ok-min" style="height: 40px; min-height: 48px; width: 60px">Both</button>
<a id="ok-pad" style="display: inline-block; height: 24px; padding: 12px 0; min-width: 60px">Pad</a>
<button id="small-pad" style="height: 24px; padding: 12px 0; min-width: 60px">Border box</button>
<input id="hid" type="hidden" style="height: 0; width: 0">
<button id="small" style="height: 20px; min-width: 60px">Tiny</button>
</x-dc>
EOF
  _dm_py "$m/contrast-audit.py" "$d"
  _dm_has "$_dm_out" "LOW light [a]: color-on-surface #eeeeee on color-surface" || cf "(a) a failing pair in one namespace is hidden by another namespace's value: $(_dm_brief 400)"
  _dm_has "$_dm_out" "ok-min" && cf "(b) height 40px with min-height 48px reads SMALL: $(_dm_brief 400)"
  _dm_has "$_dm_out" "ok-pad" && cf "(c) height 24px with padding 12px 0 on a content-box link reads SMALL: $(_dm_brief 400)"
  _dm_has "$_dm_out" "small-pad" || cf "(c) (control) a button, border-box by default, with height 24px is not SMALL: $(_dm_brief 400)"
  _dm_has "$_dm_out" "hid" && cf "(d) a hidden input reads SMALL: $(_dm_brief 400)"
  _dm_has "$_dm_out" "id=small>" || cf "(d) (control) a 20px-high button is not SMALL: $(_dm_brief 400)"
  # (e) overlays in no pair, then a paired one with an alpha
  rm -f "$t/a.tokens.json"
  printf '%s\n' '{"color":{"surface":{"$value":"#ffffff"},"on-surface":{"$value":"#000000"},"scrim":{"$value":"#00000052"},"shadow":{"$value":"rgba(0,0,0,0.3)"},"veil":{"$value":"color-mix(in srgb, #000 30%, transparent)"}}}' > "$t/b.tokens.json"
  rm -f "$d/requirements/design/app/project/A.dc.html"
  _dm_py "$m/contrast-audit.py" "$d" --strict
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "UNREAD"; } || cf "(e) an overlay colour in no pair reads UNREAD or fails --strict (exit $_dm_rc): $(_dm_brief 400)"
  printf '%s\n' '{"color":{"surface":{"$value":"#ffffff"},"on-surface":{"$value":"#00000080"}}}' > "$t/b.tokens.json"
  _dm_py "$m/contrast-audit.py" "$d" --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "UNREAD light: color-on-surface"; } || cf "(e) (control) a paired colour with an alpha is no longer UNREAD (exit $_dm_rc): $(_dm_brief 400)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE NORMALISER DECODES AN ATTRIBUTE AS A BROWSER DOES, THE ANCHOR RESOLVER READS A PERCENT-ENCODED BOARD NAME, AND THE PULL SKILL
#   WALKS A FILE NAME WITH A SPACE.
#   Operand: normalise-canvas.py over a board whose data-props holds `?a=1&copy=2`; resolve-anchor.py over `My%20Board.dc.html#…`; the
#   design-pull skill's both and drop blocks over a manifest line for `project/My Board.dc.html`; the skill's anchor step for an apostrophe.
# =============================================================================
case_the_normaliser_decodes_an_attribute_as_a_browser_does_and_the_pull_walks_a_file_name_with_a_space() {
  cf_reset
  local L="normalise-canvas.py keeps a '&copy=' in a data-props URL as written (a reference without its semicolon followed by = is not decoded in an attribute), resolve-anchor.py finds a board named in percent-encoding, the pull skill's both and drop blocks handle a file name with a space, and its anchor step says how to write an apostrophe in a board name"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_pull_fixture || { finish "$L"; teardown; return; }
  local m="$REAL_REPO_ROOT/modules/design/scripts/design" d="$SB_TMP/nrm" pj="$SB_WORK/.cache/design/pull/project" pd="$SB_WORK/requirements/design/steep" sha
  # (a) the normaliser
  mkdir -p "$d/p"
  printf '<x-dc><div id="a">A</div></x-dc>\n<script type="text/x-dc" data-dc-script data-props="{&quot;u&quot;:&quot;x?a=1&copy=2&amp;b=3&quot;}">\nclass Component extends DCLogic {}\n</script>\n' > "$d/p/List.dc.html"
  _dm_py "$m/normalise-canvas.py" "$d/p"
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$(cat "$d/p/List.dc.html")" 'x?a=1&amp;copy=2&amp;b=3'; } || cf "(a) '&copy=2' in a data-props URL was decoded to a copyright sign (exit $_dm_rc): $(sed -n 2p "$d/p/List.dc.html")"
  # (a2) a reference with no semicolon that a browser keeps literal in an attribute: a legacy name followed by a letter or digit, or by `=`
  printf '<x-dc></x-dc>\n<script type="text/x-dc" data-dc-script data-props="{&quot;a&quot;:&quot;&copyx&quot;,&quot;b&quot;:&quot;a&ampb&quot;,&quot;c&quot;:&quot;&notit&quot;,&quot;d&quot;:&quot;?x=1&notify&y=2&quot;,&quot;e&quot;:&quot;&notit;&quot;}">\n</script>\n' > "$d/p/Lit.dc.html"
  _dm_py "$m/normalise-canvas.py" "$d/p"
  want='{"a":"&amp;copyx","b":"a&amp;ampb","c":"&amp;notit","d":"?x=1&amp;notify&amp;y=2","e":"&amp;notit;"}'
  _dm_has "$(cat "$d/p/Lit.dc.html")" "$want" || cf "(a2) a reference a browser keeps literal was decoded: $(sed -n 2p "$d/p/Lit.dc.html")"
  # (a3) a real change is still a change: the literal text &copyx against the sign followed by x
  printf '<x-dc></x-dc>\n<script type="text/x-dc" data-dc-script data-props="{&quot;u&quot;:&quot;&copyx&quot;}">\n</script>\n' > "$d/old.dc.html"
  printf '<x-dc></x-dc>\n<script type="text/x-dc" data-dc-script data-props='"'"'{"u":"©x"}'"'"'>\n</script>\n' > "$d/new.dc.html"
  _dm_py -c "import importlib.util; s = importlib.util.spec_from_file_location('c', 'scripts/design/check-design-links.py'); c = importlib.util.module_from_spec(s); s.loader.exec_module(c); print(c.plain(open('$d/old.dc.html').read()) == c.plain(open('$d/new.dc.html').read()))"
  [ "$_dm_out" = False ] || cf "(a3) the literal text &copyx and the sign followed by x compare equal, so a real change reads as a re-save: $_dm_out"
  # (a4) the character after a legacy name keeps the reference literal only when it is `=` or ASCII alphanumeric: a letter with an accent or a superscript does not
  printf '<x-dc></x-dc>\n<script type="text/x-dc" data-dc-script data-props="{&quot;a&quot;:&quot;&noté&quot;,&quot;b&quot;:&quot;&ampé&quot;,&quot;c&quot;:&quot;&copy²&quot;}">\n</script>\n' > "$d/p/Uni.dc.html"
  _dm_py "$m/normalise-canvas.py" "$d/p"
  _dm_has "$(cat "$d/p/Uni.dc.html")" '{"a":"¬é","b":"&amp;é","c":"©²"}' || cf "(a4) a legacy name before a non-ASCII character was kept literal, where the spec decodes it: $(sed -n 2p "$d/p/Uni.dc.html")"
  # (a5) and the real change that rule would hide: &ampé reads as &é, &amp;ampé reads as &ampé
  printf '<x-dc></x-dc>\n<script type="text/x-dc" data-dc-script data-props="{&quot;u&quot;:&quot;&ampé&quot;}">\n</script>\n' > "$d/old2.dc.html"
  printf '<x-dc></x-dc>\n<script type="text/x-dc" data-dc-script data-props='"'"'{"u":"&amp;ampé"}'"'"'>\n</script>\n' > "$d/new2.dc.html"
  _dm_py -c "import importlib.util; s = importlib.util.spec_from_file_location('c', 'scripts/design/check-design-links.py'); c = importlib.util.module_from_spec(s); s.loader.exec_module(c); print(c.plain(open('$d/old2.dc.html').read()) == c.plain(open('$d/new2.dc.html').read()))"
  [ "$_dm_out" = False ] || cf "(a5) the value &é and the value &ampé compare equal, so a real change reads as a re-save: $_dm_out"
  # (b) the anchor resolver, a board with a space in its name, written percent-encoded
  cp "$pd/project/Settings.dc.html" "$d/p/My Board.dc.html"
  _dm_py "$m/resolve-anchor.py" "$d/p" 'My%20Board.dc.html#2:1'
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "RESOLVED"; } || cf "(b) a percent-encoded board name reads as absent (exit $_dm_rc): $_dm_out"
  # (c) the pull skill over a manifest line with a space in the path
  cp "$pd/project/Settings.dc.html" "$pd/project/My Board.dc.html"
  sha="$( (shasum -a 256 "$pd/project/My Board.dc.html" 2>/dev/null || sha256sum "$pd/project/My Board.dc.html") | cut -d' ' -f1)"
  printf 'project/My Board.dc.html %s %s\n' "$sha" "$sha" >> "$pd/CANVAS.md"
  _dm_commit "a board with a space in its name, in the manifest"
  _dm_sh "$(_dm_pull_walk start)"
  printf '<!-- repo side -->\n' >> "$pd/project/My Board.dc.html"
  _dm_commit "the repo changes it"
  cp "$d/p/My Board.dc.html" "$pj/My Board.dc.html"
  printf '<!-- canvas side -->\n' >> "$pj/My Board.dc.html"
  _dm_sh "$(_dm_pull_walk both)"
  printf '%s\n' "$_dm_out" | grep -Fx 'BOTH-SIDES project/My Board.dc.html' >/dev/null || cf "(c) the both block does not name a file whose name has a space (exit $_dm_rc): $_dm_out"
  _dm_sh "$(_dm_pull_walk drop "s|<path>|project/My Board.dc.html|g")"
  { [ "$_dm_rc" -eq 0 ] && ! grep -F 'project/My Board.dc.html' "$pd/CANVAS.md" >/dev/null; } || cf "(c) the drop block leaves the manifest line of a file whose name has a space (exit $_dm_rc): $_dm_out"
  # (d) the anchor step says how to write an apostrophe
  _dm_has "$(cat "$REAL_REPO_ROOT/modules/design/_claude/skills/design-pull/SKILL.md")" "'\\''" || cf "(d) the pull skill does not say how to write an apostrophe in the board name inside the shell quotes"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE UPGRADE NOTE'S VERIFY LINE FOR LOCAL-ONLY PINS READS THE TRUNK AS THE KIT DOES AND COVERS SLICES AND blocked/.
#   Operand: the Verify: line of the module notes' 0.6.1 Action required item, run by bash -c in scratch repositories: a pin on the trunk
#   passes with no refs/remotes/<remote>/HEAD and a remote that is not called origin ($KWT_REMOTE); a pin only the clone has fails on a
#   card, on a slice and on a blocked card.
# =============================================================================
case_the_local_only_pin_verify_line_reads_the_trunk_as_the_kit_does_and_covers_slices_and_blocked_cards() {
  cf_reset
  local L="the 0.6.1 Verify line exits 0 when every pin is on the trunk (no origin/HEAD, a remote named by KWT_REMOTE) and 1 for a pin only the clone has, on a card, a slice and a blocked card"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _md_sandbox
  local v w="$SB_TMP/lv" a b rc
  v="$(sed -n '/^## \[0.6.1\]/,/^### Changed/p' "$REAL_REPO_ROOT/modules/design/RELEASE-NOTES.md" | grep 'Verify:' | sed 's/^ *Verify: *//')"
  [ -n "$v" ] || { cf "(prereq) the 0.6.1 notes carry no Verify line"; finish "$L"; return; }
  mkdir -p "$w/progress/in_progress" "$w/progress/blocked" "$w/progress/subtasks/X-1/in_progress"
  git -C "$w" init -q -b main . >/dev/null 2>&1; git -C "$w" config user.email t@t; git -C "$w" config user.name t
  echo x > "$w/f"; git -C "$w" add f >/dev/null 2>&1; git -C "$w" commit -qm a >/dev/null 2>&1; a="$(git -C "$w" rev-parse HEAD)"
  git init -q --bare "$SB_TMP/lv-remote.git" >/dev/null 2>&1
  git -C "$w" remote add up "$SB_TMP/lv-remote.git"; git -C "$w" push -q up main >/dev/null 2>&1
  echo y >> "$w/f"; git -C "$w" commit -qam b >/dev/null 2>&1; b="$(git -C "$w" rev-parse --short HEAD)"
  _lv_card() { printf -- '---\nid: X-9\ndesign: [UX-001#default@%s]\n---\n' "$2" > "$1"; }
  _lv_run() { rc=0; ( cd "$w" && KWT_REMOTE=up bash -c "$v" >/dev/null 2>&1 ) || rc=$?; }
  _lv_card "$w/progress/in_progress/X-1-c.md" "$a"
  _lv_run; [ "$rc" -eq 0 ] || cf "(a) a pin on the trunk fails the Verify line with no up/HEAD ref (exit $rc)"
  _lv_card "$w/progress/in_progress/X-2-c.md" "$b"
  _lv_run; [ "$rc" -eq 1 ] || cf "(b) a pin only the clone has, on a card, does not fail it (exit $rc)"
  rm -f "$w/progress/in_progress/X-2-c.md"
  _lv_card "$w/progress/subtasks/X-1/in_progress/X-1-s1-c.md" "$b"
  _lv_run; [ "$rc" -eq 1 ] || cf "(c) a pin only the clone has, on a slice, does not fail it (exit $rc)"
  rm -f "$w/progress/subtasks/X-1/in_progress/X-1-s1-c.md"
  _lv_card "$w/progress/blocked/X-3-c.md" "$b"
  _lv_run; [ "$rc" -eq 1 ] || cf "(d) a pin only the clone has, on a blocked card, does not fail it (exit $rc)"
  # (e) a project whose trunk is not main: no origin/HEAD, no init.defaultBranch, the last-resort name kit-init wrote into kanban-worktree.sh
  local w2="$SB_TMP/lv2" c d2
  mkdir -p "$w2/progress/in_progress" "$w2/scripts/lib"
  printf 'KWT_TRUNK_LAST_RESORT="${KWT_TRUNK_LAST_RESORT:-trunk}"\n' > "$w2/scripts/lib/kanban-worktree.sh"
  git -C "$w2" init -q -b trunk . >/dev/null 2>&1; git -C "$w2" config user.email t@t; git -C "$w2" config user.name t
  git -C "$w2" add -A >/dev/null 2>&1; git -C "$w2" commit -qm a >/dev/null 2>&1; c="$(git -C "$w2" rev-parse HEAD)"
  git init -q --bare "$SB_TMP/lv2-remote.git" >/dev/null 2>&1
  git -C "$w2" remote add up "$SB_TMP/lv2-remote.git"; git -C "$w2" push -q up trunk >/dev/null 2>&1
  echo y >> "$w2/f"; git -C "$w2" add f >/dev/null 2>&1; git -C "$w2" commit -qm b >/dev/null 2>&1; d2="$(git -C "$w2" rev-parse HEAD)"
  _lv_run2() { rc=0; ( cd "$w2" && env -u KWT_TRUNK_LAST_RESORT GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null KWT_REMOTE=up bash -c "$v" >/dev/null 2>&1 ) || rc=$?; }
  _lv_card "$w2/progress/in_progress/X-1-c.md" "$c"
  _lv_run2; [ "$rc" -eq 0 ] || cf "(e) a pin on a trunk that is not main fails the Verify line, which should read the last-resort name from kanban-worktree.sh (exit $rc)"
  _lv_card "$w2/progress/in_progress/X-2-c.md" "$d2"
  _lv_run2; [ "$rc" -eq 1 ] || cf "(e) a pin only the clone has, on a trunk that is not main, does not fail it (exit $rc)"
  # (f) an upper-case pin is read: the link check accepts A-F and lower-cases it
  _lv_card "$w2/progress/in_progress/X-2-c.md" "$(printf '%s' "$d2" | cut -c1-12 | tr 'a-f' 'A-F')"
  _lv_run2; [ "$rc" -eq 1 ] || cf "(f) an upper-case pin only the clone has is not read by the Verify line (exit $rc)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A SCREEN THAT READS A TOKEN THROUGH var() WITH NO FALLBACK, WHEN NO RULE OF THE SCREEN, ITS SHEETS OR ITS IMPORTS DECLARES IT, IS A TOKEN-UNDECLARED FINDING.
#   Operand: check-design-links.py --strict over a screen reading var(--elevation-1) (a generated token) with, in turn, no declaration,
#   one in its :root block, one in a sheet it links, one in a [data-theme] block alone, one in an imported screen, a fallback on the read,
#   and a name that is no token's.
# =============================================================================
case_a_screen_reading_a_token_it_never_declares_is_a_token_undeclared_finding_unless_a_rule_it_loads_declares_it() {
  cf_reset
  local L="check-design-links.py --strict names a token a screen reads by var() with no fallback when no rule of the screen, a sheet it links or a screen it imports declares it, and passes it once any of those does, when the read has a fallback, and when the name is no token's"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_links_fixture || { finish "$L"; teardown; return; }
  local D="$SB_WORK/requirements/design/app/project" C="$SB_WORK/requirements/design/app/CANVAS.md"
  _dm_tokens '{"color":{"primary":{"$value":"#485d92"},"surface":{"$value":"#ffffff"}},"elevation":{"1":{"$value":"0 1px 2px rgba(0,0,0,0.2)"}}}'
  printf '| UX-003 | C.dc.html | t | phone |  | default | PRD-001-F1-S1 | open | open |\n' >> "$C"
  local R='<h1 id="ux-003-t" style="box-shadow: var(--elevation-1)">Raised</h1>'
  # (a) read, declared nowhere
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' "$R"
  _dm_commit "a screen reading --elevation-1 and declaring nothing"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_line_has "$_dm_out" "TOKEN-UNDECLARED" "C.dc.html" && _dm_line_has "$_dm_out" "TOKEN-UNDECLARED" "--elevation-1"; } || cf "(a) an undeclared elevation token a screen reads is not a TOKEN-UNDECLARED finding naming the screen and the property (exit $_dm_rc): $(_dm_brief 400)"
  # (b) declared in the screen's :root block
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92; --elevation-1: 0 1px 2px rgba(0,0,0,0.2);' "$R"
  _dm_commit "declared in :root"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "TOKEN-UNDECLARED"; } || cf "(b) a token declared in the screen's :root block is still TOKEN-UNDECLARED (exit $_dm_rc): $(_dm_brief 400)"
  # (c) declared in a linked sheet
  printf ':root { --elevation-1: 0 1px 2px rgba(0,0,0,0.2); }\n' > "$D/app.css"
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' "<link rel=\"stylesheet\" href=\"app.css\">$R"
  _dm_commit "declared in a linked sheet"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "TOKEN-UNDECLARED"; } || cf "(c) a token declared in a sheet the screen links is still TOKEN-UNDECLARED (exit $_dm_rc): $(_dm_brief 400)"
  # (c2) read in a linked sheet, declared nowhere: the sheet's read is the screen's
  printf '.card { box-shadow: var(--elevation-1); }\n' > "$D/app.css"
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' '<link rel="stylesheet" href="app.css"><h1 id="ux-003-t" class="card">Raised</h1>'
  _dm_commit "read in a linked sheet, declared nowhere"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_line_has "$_dm_out" "TOKEN-UNDECLARED" "C.dc.html"; } || cf "(c2) a token a linked sheet reads, declared nowhere, is not TOKEN-UNDECLARED (exit $_dm_rc): $(_dm_brief 400)"
  rm -f "$D/app.css"
  # (d) declared in a theme block alone
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' "<style>[data-theme=\"dark\"] { --elevation-1: none; }</style>$R"
  _dm_commit "declared in a [data-theme] block alone"
  _dm_py scripts/design/check-design-links.py --strict
  _dm_has "$_dm_out" "TOKEN-UNDECLARED" && cf "(d) a token declared in a [data-theme] block is TOKEN-UNDECLARED: $(_dm_brief 400)"
  # (e) a read with a fallback
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' '<h1 id="ux-003-t" style="box-shadow: var(--elevation-1, 0 1px 2px)">Raised</h1>'
  _dm_commit "a read with a fallback"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "TOKEN-UNDECLARED"; } || cf "(e) a token read with a fallback is TOKEN-UNDECLARED (exit $_dm_rc): $(_dm_brief 400)"
  # (f) a name that is no token's
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' '<h1 id="ux-003-t" style="margin: var(--gap)">Plain</h1>'
  _dm_commit "a property that is no token's"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "TOKEN-UNDECLARED"; } || cf "(f) a var() of a name no token file holds is TOKEN-UNDECLARED (exit $_dm_rc): $(_dm_brief 400)"
  # (g) declared in an imported screen
  _dm_art "$D/I.dc.html" 004 '--elevation-1: 0 1px 2px rgba(0,0,0,0.2);' '<h2 id="ux-004-t">Import</h2>'
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' "<dc-import name=\"I\" hint-size=\"390px,844px\"></dc-import>$R"
  _dm_commit "declared in an imported screen"
  _dm_py scripts/design/check-design-links.py --strict
  _dm_has "$_dm_out" "TOKEN-UNDECLARED" && cf "(g) a token declared in an imported screen is TOKEN-UNDECLARED: $(_dm_brief 400)"
  # (h) the imported screen has a row of its own: its declaration still counts for the importer
  printf '| UX-004 | I.dc.html | t | phone |  | default | PRD-001-F1-S1 | open | open |\n' >> "$C"
  _dm_commit "the imported screen gets a row"
  _dm_py scripts/design/check-design-links.py --strict
  _dm_has "$_dm_out" "TOKEN-UNDECLARED" && cf "(h) a token declared in an imported screen with a row of its own is TOKEN-UNDECLARED on the importer: $(_dm_brief 400)"
  # (i) the imported screen, which has a row, reads the token and the importer declares it: clean; the importer declaring nothing: one finding, on the importer
  _dm_art "$D/I.dc.html" 004 '' '<h2 id="ux-004-t" style="box-shadow: var(--elevation-1)">Import</h2>'
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92; --elevation-1: 0 1px 2px rgba(0,0,0,0.2);' '<dc-import name="I" hint-size="390px,844px"></dc-import><h1 id="ux-003-t">Importer</h1>'
  _dm_commit "the imported screen reads the token, the importer declares it"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "TOKEN-UNDECLARED" && _dm_has "$_dm_out" "; 0 finding(s)"; } || cf "(i) a token an imported screen reads, which its importer declares, is TOKEN-UNDECLARED or counted (exit $_dm_rc): $(_dm_brief 400)"
  { _dm_line_has "$_dm_out" "TOKEN-VIA-IMPORTER" "requirements/design/app/project/I.dc.html" && _dm_line_has "$_dm_out" "TOKEN-VIA-IMPORTER" "--elevation-1"; } || cf "(i) an imported screen's read that only its importer declares is not a TOKEN-VIA-IMPORTER line naming the screen and the token: $(_dm_brief 400)"
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' '<dc-import name="I" hint-size="390px,844px"></dc-import><h1 id="ux-003-t">Importer</h1>'
  _dm_commit "the importer declares nothing"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_line_has "$_dm_out" "TOKEN-UNDECLARED" "requirements/design/app/project/C.dc.html" && ! _dm_line_has "$_dm_out" "TOKEN-UNDECLARED" "requirements/design/app/project/I.dc.html" && ! _dm_has "$_dm_out" "TOKEN-VIA-IMPORTER"; } || cf "(i) a token an imported screen reads, declared by nobody, is not one TOKEN-UNDECLARED finding on the importer (exit $_dm_rc): $(_dm_brief 400)"
  # (j) a cycle between two rows, the one that reads is C: neither is exempt, so the finding is not lost
  _dm_art "$D/I.dc.html" 004 '' '<dc-import name="C" hint-size="390px,844px"></dc-import><h2 id="ux-004-t">Import</h2>'
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' "<dc-import name=\"I\" hint-size=\"390px,844px\"></dc-import>$R"
  _dm_commit "a cycle, C reads"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "TOKEN-UNDECLARED"; } || cf "(j) a token read in a screen of an import cycle between two rows, declared nowhere, is not a finding (exit $_dm_rc): $(_dm_brief 400)"
  # (k) the same cycle, the one that reads is I
  _dm_art "$D/I.dc.html" 004 '' '<dc-import name="C" hint-size="390px,844px"></dc-import><h2 id="ux-004-t" style="box-shadow: var(--elevation-1)">Import</h2>'
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' '<dc-import name="I" hint-size="390px,844px"></dc-import><h1 id="ux-003-t">Importer</h1>'
  _dm_commit "a cycle, I reads"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "TOKEN-UNDECLARED"; } || cf "(k) the same cycle with the read in the other screen is not a finding (exit $_dm_rc): $(_dm_brief 400)"
  # (l) a screen that imports itself is judged on its own row
  _dm_art "$D/I.dc.html" 004 '' '<h2 id="ux-004-t">Import</h2>'
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' "<dc-import name=\"C\" hint-size=\"390px,844px\"></dc-import>$R"
  _dm_commit "a self-import"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_line_has "$_dm_out" "TOKEN-UNDECLARED" "C.dc.html"; } || cf "(l) a screen that imports itself escapes the check (exit $_dm_rc): $(_dm_brief 400)"
  # (m)-(s) where a var() is a read: style blocks, style attributes and sheets only, whole-name, never a fallback's own var()
  _dm_undeclared_row() {  # <label> <want: 1 a finding, 0 none> <screen body>
    _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' "$3"
    _dm_commit "$1"
    _dm_py scripts/design/check-design-links.py --strict
    if [ "$2" = 1 ]; then
      { [ "$_dm_rc" -eq 1 ] && _dm_line_has "$_dm_out" "TOKEN-UNDECLARED" "C.dc.html"; } || cf "($1) is not a TOKEN-UNDECLARED finding (exit $_dm_rc): $(_dm_brief 300)"
    else
      { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "TOKEN-UNDECLARED"; } || cf "($1) is a TOKEN-UNDECLARED finding (exit $_dm_rc): $(_dm_brief 300)"
    fi
  }
  _dm_art "$D/N.dc.html" 005 '--color-primary: #485d92;' '<script>var a = "<style>.a { box-shadow: var(--elevation-1) }</style>";</script><!-- <style>.b { color: var(--color-surface) }</style> --><p id="ux-005-t">Plain</p>'
  _dm_undeclared_row "m: a style block inside a script string and inside an HTML comment of an imported screen" 0 '<dc-import name="N" hint-size="390px,844px"></dc-import><h1 id="ux-003-t">Importer</h1>'
  _dm_undeclared_row "n: a var() in a CSS comment of the screen's own style block" 0 '<style>/* .a { box-shadow: var(--elevation-1) } */</style><h1 id="ux-003-t">Plain</h1>'
  _dm_undeclared_row "o: var(--elevation-1 /* c */) in a style block" 1 '<style>.a { box-shadow: var(--elevation-1 /* c */) }</style><h1 id="ux-003-t" class="a">Raised</h1>'
  _dm_undeclared_row "p: a var() in text content" 0 '<p id="ux-003-t">use var(--elevation-1) for a shadow</p>'
  _dm_undeclared_row "q: a var() inside a CSS string" 0 '<style>.a::before { content: "var(--elevation-1)" }</style><h1 id="ux-003-t" class="a">Plain</h1>'
  _dm_undeclared_row "r: a var() in the fallback of a declared one" 0 '<h1 id="ux-003-t" style="box-shadow: var(--color-primary, var(--elevation-1))">Plain</h1>'
  _dm_undeclared_row "s: VAR(--elevation-1) in upper case" 1 '<h1 id="ux-003-t" style="box-shadow: VAR(--elevation-1)">Raised</h1>'
  _dm_undeclared_row "y: an empty fallback, var(--elevation-1,), is a bare read" 1 '<h1 id="ux-003-t" style="box-shadow: var(--elevation-1,)">Raised</h1>'
  _dm_undeclared_row "z: a string left open ends at its line, as a CSS bad-string does, so the read after it is found" 1 $'<style>.a::after{content:"abc\n}\n.c{box-shadow:var(--elevation-1)}</style><h1 id="ux-003-t" class="c">Raised</h1>'
  _dm_undeclared_row "z2: an apostrophe on a line of its own does not hide the rule after it" 1 $'<style>// don\'t touch\n.x{}\n.c{box-shadow:var(--elevation-1)}</style><h1 id="ux-003-t" class="c">Raised</h1>'
  _dm_undeclared_row "x: an unterminated comment ends the CSS, as it does in a browser" 0 '<style>.a { margin: 0 } /* never closed .b { box-shadow: var(--elevation-1) }</style><h1 id="ux-003-t">Plain</h1>'
  # (u)-(w) a sheet whose stripping must not swallow the read that follows: a data URI with parentheses, a quoted url with one, a string holding a comment opener
  printf '.i{background:url("data:image/svg+xml,%%3Csvg transform=%%27rotate(45)%%27%%3E%%3C/svg%%3E")}.c{box-shadow:var(--elevation-1)}.t{font-family:"Inter"}\n' > "$D/app.css"
  _dm_undeclared_row "u: a minified sheet with an SVG data URI holding rotate(45), then a read, then a quoted font" 1 '<link rel="stylesheet" href="app.css"><h1 id="ux-003-t" class="c">Raised</h1>'
  printf '.i{background:url("a)b.png")}.c{box-shadow:var(--elevation-1)}.t{font-family:"Inter"}\n' > "$D/app.css"
  _dm_undeclared_row "v: url(\"a)b.png\") then a read" 1 '<link rel="stylesheet" href="app.css"><h1 id="ux-003-t" class="c">Raised</h1>'
  printf '.i::before{content:"/*"}.c{box-shadow:var(--elevation-1)}.k::after{content:"*/"}\n' > "$D/app.css"
  _dm_undeclared_row "w: a string holding a comment opener, then a read" 1 '<link rel="stylesheet" href="app.css"><h1 id="ux-003-t" class="c">Raised</h1>'
  rm -f "$D/app.css"
  # (t) a superseded importer does not exempt the screen it imports
  _dm_art "$D/I.dc.html" 004 '' '<h2 id="ux-004-t" style="box-shadow: var(--elevation-1)">Import</h2>'
  _dm_edit "$C" 's#| UX-003 | C.dc.html | t | phone |  | default | PRD-001-F1-S1 | open | open |#| UX-003 | C.dc.html | t | phone |  | default | PRD-001-F1-S1 | superseded | superseded |#'
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' '<dc-import name="I" hint-size="390px,844px"></dc-import><h1 id="ux-003-t">Importer</h1>'
  _dm_commit "a superseded importer, I reads"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && _dm_line_has "$_dm_out" "TOKEN-UNDECLARED" "requirements/design/app/project/I.dc.html"; } || cf "(t) a screen imported only by a superseded row is exempted from the check (exit $_dm_rc): $(_dm_brief 400)"
  _dm_edit "$C" 's#| UX-003 | C.dc.html | t | phone |  | default | PRD-001-F1-S1 | superseded | superseded |#| UX-003 | C.dc.html | t | phone |  | default | PRD-001-F1-S1 | open | open |#'
  _dm_art "$D/I.dc.html" 004 '' '<h2 id="ux-004-t">Import</h2>'
  # (C4) (C5) an import cycle C <-> Q, with C also importing the row R that reads
  printf '| UX-006 | Q.dc.html | t | phone |  | default | PRD-001-F1-S1 | open | open |\n| UX-007 | R.dc.html | t | phone |  | default | PRD-001-F1-S1 | open | open |\n' >> "$C"
  _dm_art "$D/Q.dc.html" 006 '' '<dc-import name="C" hint-size="390px,844px"></dc-import><h2 id="ux-006-t">Q</h2>'
  _dm_art "$D/R.dc.html" 007 '' '<h2 id="ux-007-t" style="box-shadow: var(--elevation-1)">R</h2>'
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92; --elevation-1: 0 1px 2px rgba(0,0,0,0.2);' '<dc-import name="Q" hint-size="390px,844px"></dc-import><dc-import name="R" hint-size="390px,844px"></dc-import><h1 id="ux-003-t">C</h1>'
  _dm_commit "a cycle that declares, and a row it imports that reads"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "TOKEN-UNDECLARED" && _dm_line_has "$_dm_out" "TOKEN-VIA-IMPORTER" "requirements/design/app/project/R.dc.html"; } || cf "(C4) a row imported by a cycle member that declares what it reads is a finding, or has no TOKEN-VIA-IMPORTER line (exit $_dm_rc): $(_dm_brief 400)"
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' '<dc-import name="Q" hint-size="390px,844px"></dc-import><dc-import name="R" hint-size="390px,844px"></dc-import><h1 id="ux-003-t">C</h1>'
  _dm_commit "the cycle declares nothing"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && [ "$(printf '%s\n' "$_dm_out" | grep -c '^TOKEN-UNDECLARED')" = 1 ] && _dm_line_has "$_dm_out" "TOKEN-UNDECLARED" "requirements/design/app/project/C.dc.html"; } || cf "(C5) one undeclared read reached through a cycle and a row is not one finding, on the checked row (exit $_dm_rc): $(_dm_brief 500)"
  # (F1) (F2) the same shape with the reading leaf named to sort before the cycle: which row is taken in does not follow the names
  _dm_art "$D/R.dc.html" 007 '' '<h2 id="ux-007-t">R</h2>'
  printf '| UX-008 | Aleaf.dc.html | t | phone |  | default | PRD-001-F1-S1 | open | open |\n' >> "$C"
  _dm_art "$D/Aleaf.dc.html" 008 '' '<h2 id="ux-008-t" style="box-shadow: var(--elevation-1)">Leaf</h2>'
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92; --elevation-1: 0 1px 2px rgba(0,0,0,0.2);' '<dc-import name="Q" hint-size="390px,844px"></dc-import><dc-import name="Aleaf" hint-size="390px,844px"></dc-import><h1 id="ux-003-t">C</h1>'
  _dm_commit "a cycle that declares, and a leaf that sorts first and reads"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "TOKEN-UNDECLARED" && _dm_line_has "$_dm_out" "TOKEN-VIA-IMPORTER" "requirements/design/app/project/Aleaf.dc.html"; } || cf "(F1) a reading leaf that sorts before the cycle importing it is judged on its own row (exit $_dm_rc): $(_dm_brief 400)"
  _dm_art "$D/C.dc.html" 003 '--color-primary: #485d92;' '<dc-import name="Q" hint-size="390px,844px"></dc-import><dc-import name="Aleaf" hint-size="390px,844px"></dc-import><h1 id="ux-003-t">C</h1>'
  _dm_commit "the cycle declares nothing, the leaf sorts first"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 1 ] && [ "$(printf '%s\n' "$_dm_out" | grep -c '^TOKEN-UNDECLARED')" = 1 ] && _dm_line_has "$_dm_out" "TOKEN-UNDECLARED" "requirements/design/app/project/C.dc.html"; } || cf "(F2) one read through a cycle and a leaf that sorts first is not one finding, on the cycle (exit $_dm_rc): $(_dm_brief 500)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE LINK CHECK SAYS AN ARTBOARD NO ROW NAMES, AND REPORTS AN open OR changes ROW WHOSE FILE IS NOT THERE.
#   Operand: scripts/design/check-design-links.py --strict over the clean links fixture, then over it with one screen no row names (a report
#   line naming the file, never counted, exit 0), a screen only another screen imports (not said), an open row and a changes row whose files
#   are gone (an ARTBOARD finding each, exit 1) and a superseded row whose file is gone (not a finding).
# =============================================================================
case_the_link_check_says_an_unrowed_artboard_and_an_open_row_whose_file_is_gone() {
  cf_reset
  local L="check-design-links.py --strict says UNROWED, naming the file and never counting it, for an artboard no registry row names and that no screen with a row imports, and reports an open or changes row whose file is not there as an ARTBOARD finding, as it does an approved one, and not a superseded one"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_links_fixture || { finish "$L"; teardown; return; }
  local D="$SB_WORK/requirements/design/app/project" C="$SB_WORK/requirements/design/app/CANVAS.md"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "UNROWED"; } || cf "(a) the clean fixture says UNROWED or exits $_dm_rc: $(_dm_brief 300)"
  # (b) a screen no row names; (c) a screen only an imported-by-a-rowed-screen reads is not said
  _dm_art "$D/Z.dc.html" 009 '--color-primary: #485d92;' '<h1 id="ux-009-t">Nobody registered me</h1>'
  _dm_art "$D/I.dc.html" 004 '' '<h2 id="ux-004-t">Imported</h2>'
  _dm_art "$D/B.dc.html" 002 '--color-primary: #485d92;' '<dc-import name="I" hint-size="390px,844px"></dc-import><h1 id="ux-002-title" style="color: var(--color-primary)"><a href="A.dc.html">Edit</a></h1>' PRD-001-F1-S2
  _dm_commit "a screen nobody registered, and an imported one"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "; 0 finding(s)"; } || cf "(b) an unrowed screen is counted or fails the check (exit $_dm_rc): $(_dm_brief 300)"
  { _dm_line_has "$_dm_out" "UNROWED" "requirements/design/app/project/Z.dc.html"; } || cf "(b) no UNROWED line names Z.dc.html: $(_dm_brief 300)"
  _dm_line_has "$_dm_out" "UNROWED" "I.dc.html" && cf "(c) a screen only an importer reads is said to be unrowed: $(_dm_brief 300)"
  # (d) an open row, a changes row and a superseded row, each with no file
  # an open row and a changes row whose screens were drawn, committed and deleted; a superseded row with no file; an open row briefed and never drawn
  _dm_art "$D/Gone.dc.html" 007 '' '<h1 id="ux-007-t">Gone</h1>' PRD-001-F1-S2
  _dm_art "$D/Gone2.dc.html" 008 '' '<h1 id="ux-008-t">Gone2</h1>' PRD-001-F1-S2
  printf '| UX-007 | Gone.dc.html | t | phone |  | default | PRD-001-F1-S2 | open | open |\n' >> "$C"
  printf '| UX-008 | Gone2.dc.html | t | phone |  | default | PRD-001-F1-S2 | changes | open |\n' >> "$C"
  printf '| UX-010 | Gone3.dc.html | t | phone |  | default | PRD-001-F1-S2 | superseded | superseded |\n' >> "$C"
  printf '| UX-011 | Never.dc.html | t | phone |  | default | PRD-001-F1-S2 | open | open |\n' >> "$C"
  _dm_commit "the screens are drawn"
  git -C "$SB_WORK" rm -q -- requirements/design/app/project/Gone.dc.html requirements/design/app/project/Gone2.dc.html
  _dm_commit "rows whose files are gone"
  _dm_py scripts/design/check-design-links.py --strict
  [ "$_dm_rc" -eq 1 ] || cf "(d) rows whose files are gone exit $_dm_rc under --strict, not 1: $(_dm_brief 300)"
  { _dm_line_has "$_dm_out" "ARTBOARD" "Gone.dc.html is not there" && _dm_line_has "$_dm_out" "ARTBOARD" "Gone2.dc.html is not there"; } || cf "(d) no ARTBOARD line for an open row and a changes row whose files are not there: $(_dm_brief 400)"
  _dm_has "$_dm_out" "Gone3.dc.html" && cf "(d) a superseded row whose file is gone is reported: $(_dm_brief 400)"
  _dm_has "$_dm_out" "Never.dc.html" && cf "(d) an open row whose screen was briefed and never drawn is reported: $(_dm_brief 400)"
  _dm_line_has "$_dm_out" "ARTBOARD" "Gone.dc.html is not there. Next: " || cf "(d) the ARTBOARD line names no next action: $(_dm_brief 400)"
  # (d2) the notes' Verify line for it fails over a deleted screen's row and passes over a briefed, never-drawn one
  local vl
  vl="$(grep -m1 '^  Verify:.*is registered' "$SB_WORK/modules/design/RELEASE-NOTES.md" 2>/dev/null | sed 's/^  Verify: //')"
  [ -n "$vl" ] || cf "(d2) the module's notes carry no Verify line for the ARTBOARD finding"
  _dm_sh "$vl"
  [ "$_dm_rc" -ne 0 ] || cf "(d2) the Verify line passes over a project with a deleted screen's row"
  sed -i.bak -e '/| UX-007 |/d' -e '/| UX-008 |/d' "$C" && rm -f "$C.bak"
  _dm_commit "the deleted screens' rows are removed"
  _dm_sh "$vl"
  [ "$_dm_rc" -eq 0 ] || cf "(d2) the Verify line fails over a project whose only open row is a briefed, never-drawn screen (exit $_dm_rc): $_dm_out"
  # (e) the same project with no git history to ask: the missing files are not reported either way
  rm -rf "${SB_TMP:?}/nogit"; mkdir -p "$SB_TMP/nogit"; cp -R "$SB_WORK/requirements" "$SB_TMP/nogit/"
  GIT_CEILING_DIRECTORIES="$SB_TMP" git -C "$SB_TMP/nogit" rev-parse >/dev/null 2>&1 && cf "(e) (premise) the copy sits inside a repository, so the check could ask git"
  _dm_rc=0; _dm_out="$( cd "$SB_WORK" && env GIT_CEILING_DIRECTORIES="$SB_TMP" PYTHONDONTWRITEBYTECODE=1 python3 scripts/design/check-design-links.py --strict "$SB_TMP/nogit" 2>&1 </dev/null )" || _dm_rc=$?
  _dm_has "$_dm_out" " is registered (" && cf "(e) with no git to ask, an open row whose file is missing is reported: $(_dm_brief 400)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE PULL SKILL'S both BLOCK NAMES NO FILE THAT IS EQUAL ON BOTH SIDES.
#   Operand: the both block over a pull whose Timer is byte-equal to the repo's changed Timer while the manifest still names the older bytes (a
#   send that landed and a crash before its record): nothing is named; a Timer that differs is named.
# =============================================================================
case_the_pull_skill_walked_over_a_file_equal_on_both_sides_names_nothing() {
  cf_reset
  local L="the design-pull skill's both block names no file whose pulled bytes equal the repo's, though the manifest is older than both, and still names one that differs"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_pull_fixture || { finish "$L"; teardown; return; }
  local pj="$SB_WORK/.cache/design/pull/project" t="$SB_WORK/requirements/design/steep/project/Timer.dc.html"
  _dm_edit "$t" 's|<title>Timer</title>|<title>Timer SENT</title>|'
  _dm_commit "the Designer changes Timer and sends it"
  _dm_sh "$(_dm_pull_walk start)"
  cp "$t" "$pj/Timer.dc.html"
  cp "$SB_WORK/requirements/design/steep/project/Settings.dc.html" "$pj/Settings.dc.html"
  _dm_sh "$(_dm_pull_walk both)"
  { [ "$_dm_rc" -eq 0 ] && [ -z "$_dm_out" ]; } || cf "(a) a file equal on both sides is named (exit $_dm_rc): $_dm_out"
  sed 's|SENT|EDITED ON THE CANVAS|' "$t" > "$pj/Timer.dc.html"
  _dm_sh "$(_dm_pull_walk both)"
  printf '%s\n' "$_dm_out" | grep -Fx 'BOTH-SIDES project/Timer.dc.html' >/dev/null || cf "(b) (control) a file that differs on the two sides is not named: $_dm_out"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE PUBLISH SKILL'S normalise BLOCK SENDS data-props IN THE COMPACT FORM THE PULL WRITES.
#   Operand: the block over a board whose data-props was written spaced: it becomes compact, a second run changes nothing, and the pull's
#   normaliser finds nothing left to rewrite.
# =============================================================================
case_the_publish_skill_normalises_data_props_to_the_form_a_pull_writes() {
  cf_reset
  local L="the design-publish skill's normalise block rewrites a spaced data-props to the compact form, changes nothing on a second run, and leaves nothing for the pull's normaliser"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_pull_fixture || { finish "$L"; teardown; return; }
  local f="$SB_WORK/requirements/design/steep/project/Main.dc.html" blk
  blk="$(_dm_fence "$SB_WORK/.claude/skills/design-publish/SKILL.md" normalise | sed 's|<canvas>|steep|g')"
  [ -n "$blk" ] || cf "(prereq) the publish skill has no normalise block"
  _dm_edit "$f" "s|\\(data-dc-script data-props=\\).*>\$|\\1'{\"view\": {\"editor\": \"enum\", \"default\": \"list\"}}'>|"
  grep -F '"view": {' "$f" >/dev/null || cf "(prereq) the board was not given a spaced data-props"
  _dm_sh "$blk"
  grep -F "data-props='{\"view\":{\"editor\":\"enum\",\"default\":\"list\"}}'" "$f" >/dev/null || cf "(a) the block left data-props spaced (exit $_dm_rc): $(grep -o "data-props=.*" "$f" | head -1 | cut -c1-120)"
  _dm_sh "$blk"
  { [ "$_dm_rc" -eq 0 ] && [ -z "$_dm_out" ]; } || cf "(b) a second run changes something (exit $_dm_rc): $_dm_out"
  _dm_py scripts/design/normalise-canvas.py --check requirements/design/steep/project
  { [ "$_dm_rc" -eq 0 ] && [ -z "$_dm_out" ]; } || cf "(c) the pull's normaliser would still rewrite a file the block normalised (exit $_dm_rc): $_dm_out"
  local sk="$SB_WORK/.claude/skills/design-publish/SKILL.md"
  awk '/^## 1\./ { f = 1; next } /^## 2\./ { f = 0 } f' "$sk" | grep -F 'normalise' >/dev/null || cf "(d) the first publish (step 1) does not run the normalise block"
  awk '/^## 1\./ { f = 1; next } /^## 2\./ { f = 0 } f' "$sk" | tr '\n' ' ' | grep -F 'commit what it rewrote' >/dev/null || cf "(d) the first publish (step 1) does not say to commit what the normaliser rewrote before it sends"
  grep -F 'a file it rewrote that is not sent' "$sk" >/dev/null || cf "(e) the skill does not say to commit a file the normaliser rewrote though it is not sent"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE PULL SKILL GIVES THE TWO STEPS TO TAKE ONE CANVAS EDIT AND REJECT ANOTHER.
#   Operand: the skill's text: answer yes to the pull, then restore the rejected file from the base through the repo and commit it.
# =============================================================================
case_the_pull_skill_gives_the_two_steps_for_a_partial_acceptance() {
  cf_reset
  local L="the design-pull skill names the two steps to take one canvas edit and reject another: answer yes to the pull, then restore the rejected file from the base with git checkout and commit it"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_pull_fixture || { finish "$L"; teardown; return; }
  local s="$SB_WORK/.claude/skills/design-pull/SKILL.md" para
  para="$(grep -A3 'To take one canvas edit and reject another' "$s" 2>/dev/null)"
  [ -n "$para" ] || cf "the skill has no account of taking one canvas edit and rejecting another"
  _dm_has "$para" "answer yes to the pull" || cf "the account does not say to answer yes to the pull first"
  _dm_has "$para" 'git checkout <base> -- requirements/design/<canvas>/<path>' || cf "the account does not give the restore from the base"
  _dm_has "$para" 'restore <path>' || cf "the account does not say to commit the restore"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE LINK CHECK NEVER SAYS UNROWED OF A FILE IT READ THROUGH A ROW, WHATEVER THE CASE OF THE ROW'S SPELLING.
#   Operand: a row that reads x.dc.html over a disk that holds X.dc.html, on a filesystem that reads the two as one file (skips on one that does not).
# =============================================================================
case_the_link_check_does_not_say_unrowed_of_a_file_a_row_names_in_another_case() {
  cf_reset
  local L="check-design-links.py does not say UNROWED of an artboard a registry row names in another letter case on a filesystem that reads the two as one file, and still says it of one no row names"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_links_fixture || { finish "$L"; teardown; return; }
  local D="$SB_WORK/requirements/design/app/project" C="$SB_WORK/requirements/design/app/CANVAS.md"
  _dm_art "$D/Xcase.dc.html" 012 '' '<h1 id="ux-012-t">Case</h1>' PRD-001-F1-S2
  if [ ! -e "$D/xcase.dc.html" ]; then
    teardown; skp "$L" "this filesystem tells Xcase.dc.html from xcase.dc.html, so a row spelt in another case names no file here"; return
  fi
  printf '| UX-012 | xcase.dc.html | t | phone |  | default | PRD-001-F1-S2 | open | open |\n' >> "$C"
  _dm_art "$D/Z.dc.html" 009 '' '<h1 id="ux-009-t">Nobody registered me</h1>'
  _dm_commit "a row spelt in another case, and a screen no row names"
  _dm_py scripts/design/check-design-links.py --strict
  _dm_line_has "$_dm_out" "UNROWED" "Xcase.dc.html" && cf "(a) a file a row names in another case is said to be unrowed: $(_dm_brief 300)"
  _dm_line_has "$_dm_out" "UNROWED" "Z.dc.html" || cf "(b) (control) a screen no row names is not said to be unrowed: $(_dm_brief 300)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE LINK CHECK READS A DANGLING OR LOOPING *.dc.html SYMLINK AS AN ARTBOARD NO ROW NAMES, AND DOES NOT CRASH.
#   Operand: scripts/design/check-design-links.py over the clean links fixture with project/Dang.dc.html -> nowhere and project/Loop.dc.html -> itself:
#   each is an UNROWED report line, there is no traceback, and --strict still exits 0 over the clean fixture.
# =============================================================================
case_the_link_check_does_not_crash_on_a_dangling_or_looping_artboard_symlink() {
  cf_reset
  local L="check-design-links.py says UNROWED of a dangling *.dc.html symlink and of one that points to itself, prints no traceback, and exits 0 under --strict over a clean project"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_links_fixture || { finish "$L"; teardown; return; }
  local D="$SB_WORK/requirements/design/app/project"
  ln -s nowhere.dc.html "$D/Dang.dc.html" 2>/dev/null && ln -s Loop.dc.html "$D/Loop.dc.html" 2>/dev/null || { teardown; skp "$L" "this filesystem makes no symbolic links"; return; }
  _dm_py scripts/design/check-design-links.py --strict
  _dm_has "$_dm_out" "Traceback" && cf "(a) the check crashes over a symlink artboard: $(_dm_brief 400)"
  [ "$_dm_rc" -eq 0 ] || cf "(a) the clean project with two symlink artboards exits $_dm_rc under --strict: $(_dm_brief 400)"
  _dm_line_has "$_dm_out" "UNROWED" "Dang.dc.html" || cf "(b) a dangling symlink artboard is not said to be unrowed: $(_dm_brief 400)"
  _dm_line_has "$_dm_out" "UNROWED" "Loop.dc.html" || cf "(b) a looping symlink artboard is not said to be unrowed: $(_dm_brief 400)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE DESIGNER'S COMMITS REACH THE TRUNK WITH THEIR SHAS, AND A PULL OR A PUBLISH STOPS WHEN THEY DO NOT.
#   Operand: scripts/design/trunk-sync.sh in a sandbox project with a bare remote, the two skills, the role and the manifest.
#   `check` is 0 level and refuses ahead, behind and diverged with a Next; `push` fast-forwards the remote and leaves HEAD's
#   sha as it was, and refuses diverged, a refused push, a remote that does not hold the tip afterwards, and a fetch that fails;
#   both refuse off the trunk. The skills run `check` at their start and `push` after each commit step; the role's checklist
#   names the route; the manifest places the script.
# =============================================================================
case_the_designers_commits_reach_the_trunk_with_their_shas_and_a_pull_or_publish_stops_when_they_do_not() {
  cf_reset
  local L="trunk-sync.sh check is 0 level with the remote and refuses ahead, behind and diverged with a Next, push fast-forwards the remote without changing HEAD's sha and refuses diverged, a refused push, a tip the remote does not hold and an unreachable remote, both refuse off the trunk; the skills run check first and push after each commit step, the role's checklist names the route, the manifest places the script"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _md_sandbox
  local m="$REAL_REPO_ROOT/modules/design" s="$SB_WORK/scripts/design/trunk-sync.sh" o="$SB_TMP/ts-other" head0 head1 tip
  mkdir -p "$SB_WORK/scripts/design"
  if [ -f "$m/scripts/design/trunk-sync.sh" ]; then cp "$m/scripts/design/trunk-sync.sh" "$s"; fi
  _ts() { _ts_rc=0; _ts_out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR bash scripts/design/trunk-sync.sh "$@" 2>&1 </dev/null )" || _ts_rc=$?; }
  _ts_next() { printf '%s\n' "$_ts_out" | grep -c '^Next: .*'"$1" || true; }
  _ts_brief() { printf '%s' "$_ts_out" | tr '\n' '|' | cut -c1-300; }
  # (a) level with the remote
  _ts check; [ "$_ts_rc" -eq 0 ] || cf "(a) check is not 0 on a trunk level with the remote (exit $_ts_rc): $(_ts_brief)"
  # (b) a Designer commit only the local trunk holds: check refuses, names the commit and the push, and push is the way out
  echo one > "$SB_WORK/take-in.txt"; git -C "$SB_WORK" add take-in.txt >/dev/null 2>&1; sbcommit -q -m "[$SB_ROLE] design: take in app" >/dev/null 2>&1
  head0="$(git -C "$SB_WORK" rev-parse HEAD)"
  _ts check
  { [ "$_ts_rc" -eq 1 ] && _dm_has "$_ts_out" "design: take in app" && [ "$(_ts_next 'trunk-sync.sh push')" -eq 1 ]; } || cf "(b) check over an unpushed Designer commit is not refused with the commit named and the push as its Next (exit $_ts_rc): $(_ts_brief)"
  # (c) push: the remote holds the tip, HEAD is the sha it was, and check is level again
  _ts push; tip="$(git -C "$SB_ORIGIN" rev-parse "refs/heads/$SB_TRUNK" 2>/dev/null)"
  head1="$(git -C "$SB_WORK" rev-parse HEAD)"
  { [ "$_ts_rc" -eq 0 ] && [ "$tip" = "$head0" ] && [ "$head1" = "$head0" ]; } || cf "(c) push does not leave the remote at the commit the Designer made, unchanged (exit $_ts_rc, remote $tip, head $head1, made $head0): $(_ts_brief)"
  _ts check; [ "$_ts_rc" -eq 0 ] || cf "(c) check after a push is not 0 (exit $_ts_rc): $(_ts_brief)"
  _ts push; { [ "$_ts_rc" -eq 0 ] && _dm_has "$_ts_out" "nothing to push"; } || cf "(c) push with nothing to push is not a quiet 0 (exit $_ts_rc): $(_ts_brief)"
  # (d) the remote moved by another landing: behind refuses with the fast-forward
  git clone -q "$SB_ORIGIN" "$o" >/dev/null 2>&1; git -C "$o" config user.email t@t; git -C "$o" config user.name t
  echo two > "$o/other.txt"; git -C "$o" add other.txt >/dev/null 2>&1; git -C "$o" commit -qm "[PM] other landing" >/dev/null 2>&1; git -C "$o" push -q origin "HEAD:$SB_TRUNK" >/dev/null 2>&1
  _ts check
  { [ "$_ts_rc" -eq 1 ] && [ "$(_ts_next 'pull --ff-only')" -eq 1 ]; } || cf "(d) check on a trunk the remote has moved past is not refused with the fast-forward as its Next (exit $_ts_rc): $(_ts_brief)"
  # (e) diverged: a Designer commit and the remote's; check and push refuse, the Next says merge and not rebase, nothing moves
  echo three > "$SB_WORK/more.txt"; git -C "$SB_WORK" add more.txt >/dev/null 2>&1; sbcommit -q -m "[$SB_ROLE] design: log threads for app" >/dev/null 2>&1
  head0="$(git -C "$SB_WORK" rev-parse HEAD)"; tip="$(git -C "$SB_ORIGIN" rev-parse "refs/heads/$SB_TRUNK")"
  _ts check
  { [ "$_ts_rc" -eq 1 ] && [ "$(_ts_next 'git merge')" -eq 1 ] && _dm_has "$_ts_out" "never rebase"; } || cf "(e) check on a diverged trunk is not refused with merge, never rebase, as its Next (exit $_ts_rc): $(_ts_brief)"
  _ts push
  { [ "$_ts_rc" -eq 1 ] && [ "$(git -C "$SB_ORIGIN" rev-parse "refs/heads/$SB_TRUNK")" = "$tip" ] && [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$head0" ]; } || cf "(e) push on a diverged trunk is not refused with the remote and HEAD left as they were (exit $_ts_rc): $(_ts_brief)"
  # (f) the merge route keeps the Designer's sha, and push then lands it
  git -C "$SB_WORK" fetch -q origin "$SB_TRUNK" >/dev/null 2>&1; git -C "$SB_WORK" merge -q --no-edit "origin/$SB_TRUNK" >/dev/null 2>&1
  _ts push
  { [ "$_ts_rc" -eq 0 ] && git -C "$SB_ORIGIN" merge-base --is-ancestor "$head0" "refs/heads/$SB_TRUNK" 2>/dev/null; } || cf "(f) after merging the remote in, push does not land a history that still holds the Designer's commit $head0 (exit $_ts_rc): $(_ts_brief)"
  # (g) a remote that refuses the push: refused with a Next, HEAD unchanged
  printf '#!/bin/sh\necho "denied by the test" >&2\nexit 1\n' > "$SB_ORIGIN/hooks/pre-receive"; chmod +x "$SB_ORIGIN/hooks/pre-receive"
  echo four > "$SB_WORK/refused.txt"; git -C "$SB_WORK" add refused.txt >/dev/null 2>&1; sbcommit -q -m "[$SB_ROLE] design: publish app" >/dev/null 2>&1
  head0="$(git -C "$SB_WORK" rev-parse HEAD)"
  _ts push
  { [ "$_ts_rc" -eq 1 ] && [ "$(_ts_next 'tell the human')" -eq 1 ] && [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$head0" ]; } || cf "(g) a push the remote refuses is not refused with a Next that reaches the human, HEAD unchanged (exit $_ts_rc): $(_ts_brief)"
  # (h) a push the remote accepts and then does not hold: the read-back refuses
  printf '#!/bin/sh\nwhile read old new ref; do git update-ref "$ref" "$old" 2>/dev/null || git update-ref -d "$ref"; done\n' > "$SB_ORIGIN/hooks/pre-receive"
  mv "$SB_ORIGIN/hooks/pre-receive" "$SB_ORIGIN/hooks/post-receive"
  _ts push
  { [ "$_ts_rc" -eq 1 ] && _dm_has "$_ts_out" "returned success" && [ "$(_ts_next 'git fetch')" -ge 1 ]; } || cf "(h) a push the remote reverts is not refused by the read-back (exit $_ts_rc): $(_ts_brief)"
  rm -f "$SB_ORIGIN/hooks/post-receive"
  # (i) an unreachable remote: refused with a Next, not read as level
  git -C "$SB_WORK" remote set-url origin "$SB_TMP/no-such-remote.git"
  _ts check; { [ "$_ts_rc" -eq 1 ] && [ "$(_ts_next 'git fetch')" -ge 1 ]; } || cf "(i) check over a remote that cannot be read is not refused with a Next (exit $_ts_rc): $(_ts_brief)"
  head0="$(git -C "$SB_WORK" rev-parse HEAD)"
  _ts push; { [ "$_ts_rc" -eq 1 ] && _dm_has "$_ts_out" "could not read" && [ "$(_ts_next 'git fetch')" -ge 1 ] && [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$head0" ]; } || cf "(i) push over a remote that cannot be read is not refused with a Next, HEAD unchanged (exit $_ts_rc): $(_ts_brief)"
  git -C "$SB_WORK" remote set-url origin "$SB_ORIGIN"
  # (j) off the trunk, both modes refuse before fetching or pushing
  git -C "$SB_WORK" checkout -q -b side >/dev/null 2>&1
  _ts check; { [ "$_ts_rc" -eq 1 ] && [ "$(_ts_next 'check out')" -eq 1 ]; } || cf "(j) check off the trunk is not refused with a Next that says to check out the trunk (exit $_ts_rc): $(_ts_brief)"
  _ts push;  { [ "$_ts_rc" -eq 1 ] && [ "$(_ts_next 'check out')" -eq 1 ]; } || cf "(j) push off the trunk is not refused with a Next that says to check out the trunk (exit $_ts_rc): $(_ts_brief)"
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1
  # (k) the wiring: the skills and the role name the script where the commits are made, and the manifest places it
  local p="$m/_claude/skills/design-pull/SKILL.md" b="$m/_claude/skills/design-publish/SKILL.md" r="$m/_claude/roles/designer.md"
  [ "$(grep -c 'trunk-sync.sh check' "$p")" -ge 1 ] || cf "(k) /design-pull never runs trunk-sync.sh check"
  [ "$(grep -c 'trunk-sync.sh check' "$b")" -ge 1 ] || cf "(k) /design-publish never runs trunk-sync.sh check"
  [ "$(grep -c 'trunk-sync.sh push' "$p")" -ge 2 ] || cf "(k) /design-pull names trunk-sync.sh push fewer than twice (the take-in and the thread-logging commit)"
  [ "$(grep -c 'trunk-sync.sh push' "$b")" -ge 3 ] || cf "(k) /design-publish names trunk-sync.sh push fewer than three times (the normalise commit, the pre-send commit, Last publish)"
  grep -F -- 'prefix and pushed.' "$r" >/dev/null && cf "(k) the role's checklist still says only 'and pushed.'"
  [ "$(grep -c 'trunk-sync.sh' "$r")" -ge 1 ] || cf "(k) the role never names trunk-sync.sh"
  _dm_manifest_places "$m/module.manifest" file '^scripts/design/trunk-sync\.sh$' || cf "(k) the manifest does not place scripts/design/trunk-sync.sh"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A BOARD CHROME CANNOT FINISH, OR A RENDER.PY THAT IS SIGNALLED, LEAVES NO CHROME PROCESS RUNNING.
#   Operand: scripts/design/render.py with a stand-in for Chrome that starts two long sleeps of its own (as Chrome starts its helpers)
#   and then waits without writing the screenshot. No real Chrome; the sleeps use `sleep`, so a red run burns no CPU.
# =============================================================================
_dm_rl_alive() { local s; s="$(ps -o stat= -p "$1" 2>/dev/null | tr -d ' ')"; [ -n "$s" ] && [ "${s#Z}" = "$s" ]; }   # <pid> — running (a zombie is not)
_dm_rl_pids() { cat "$1/fake.pid" "$1/child.pid" "$1/helper.pid" 2>/dev/null; }
_dm_rl_reap() { local p; [ -n "${_DM_RL_DIR:-}" ] || return 0; for p in $(_dm_rl_pids "$_DM_RL_DIR"); do kill -KILL "$p" 2>/dev/null; done; return 0; }
_dm_rl_left=""
_dm_rl_gone() {  # <dir> <seconds> — 0 once none of the stand-in's processes is running, 1 (the survivors in _dm_rl_left) after the bound
  local n=$(( $2 * 10 )) p
  while :; do
    _dm_rl_left=""
    for p in $(_dm_rl_pids "$1"); do if _dm_rl_alive "$p"; then _dm_rl_left="$_dm_rl_left $p"; fi; done
    [ -z "$_dm_rl_left" ] && return 0
    [ "$n" -le 0 ] && return 1
    n=$((n - 1)); sleep 0.1
  done
}
_dm_rl_pid=""; _dm_rl_rc=0
_dm_rl_start() {  # <dir> <timeout> — render.py in the background over the stand-in, its output in <dir>/out.txt
  rm -f "$1/fake.pid" "$1/child.pid" "$1/helper.pid" "$1/out.txt"
  ( cd "$SB_WORK" && exec env PYTHONDONTWRITEBYTECODE=1 python3 "$REAL_REPO_ROOT/modules/design/scripts/design/render.py" "$1/project" "$1/png" \
      --runtime "$1/rt.js" --chrome "$1/chrome" --only A.dc.html --timeout "$2" > "$1/out.txt" 2>&1 < /dev/null ) &
  _dm_rl_pid=$!
}
_dm_rl_wait() {  # <seconds> — the status of the background render.py in _dm_rl_rc, or 99 after the bound (it is then killed)
  local n=$(( $1 * 10 ))
  while _dm_rl_alive "$_dm_rl_pid"; do
    [ "$n" -le 0 ] && { kill -KILL "$_dm_rl_pid" 2>/dev/null; wait "$_dm_rl_pid" 2>/dev/null; _dm_rl_rc=99; return 0; }
    n=$((n - 1)); sleep 0.1
  done
  _dm_rl_rc=0; wait "$_dm_rl_pid" 2>/dev/null || _dm_rl_rc=$?
}
case_a_board_chrome_cannot_finish_or_a_signalled_render_py_leaves_no_chrome_process_running() {
  cf_reset
  local L="render.py over a Chrome that starts helper processes and never finishes: a --timeout says FAIL, exits 1 within a bound and leaves none of Chrome's processes running; a TERM or HUP to render.py ends it with 128 plus the signal and leaves none of them running; a Chrome that ignores TERM is killed outright"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _md_sandbox
  local d="$SB_TMP/rl" i w want n
  _DM_RL_DIR="$d"
  trap '_dm_rl_reap; trap - RETURN' RETURN
  mkdir -p "$d/project" "$d/png"
  printf '<!doctype html><html><body><x-dc></x-dc></body></html>\n' > "$d/project/A.dc.html"
  printf 'window.__dcSetProps = function(){};\nwindow.__dcRootName = function(){ return "r"; };\n' > "$d/rt.js"
  cat > "$d/chrome" <<EOF
#!/bin/bash
sleep 314159 &
echo \$! > '$d/child.pid'
sleep 314158 &
echo \$! > '$d/helper.pid'
echo \$\$ > '$d/fake.pid'
wait
EOF
  chmod +x "$d/chrome"
  # (a) --timeout 2: FAIL, exit 1, back within the bound
  _dm_rl_start "$d" 2; _dm_rl_wait 20
  { [ "$_dm_rl_rc" -eq 1 ] && grep -q 'FAIL A.dc.html' "$d/out.txt" && grep -qx 'Chrome did not finish in 2 s' "$d/out.txt"; } || cf "(a) a timed-out board is not FAIL with exit 1 within 20 s, or its reason is not a line of its own (exit $_dm_rl_rc): $(tr '\n' '|' < "$d/out.txt" | cut -c1-200)"
  # (b) after it returned, the stand-in and both its helpers are gone
  [ -f "$d/fake.pid" ] || cf "(b) the stand-in never ran (no pidfile), so nothing was measured"
  _dm_rl_gone "$d" 5 || cf "(b) after a timed-out board render.py returned and Chrome's processes still run (pids$_dm_rl_left)"
  _dm_rl_reap
  # (c) a signal to render.py while Chrome runs: it ends with 128+n and leaves none of them running
  for i in TERM:143 HUP:129; do
    w="${i%:*}"; want="${i#*:}"
    _dm_rl_start "$d" 120
    n=100; while [ ! -f "$d/fake.pid" ] && [ "$n" -gt 0 ]; do n=$((n - 1)); sleep 0.1; done
    sleep 0.3
    if [ -f "$d/fake.pid" ]; then
      kill -"$w" "$_dm_rl_pid" 2>/dev/null
      _dm_rl_wait 20
      [ "$_dm_rl_rc" -eq "$want" ] || cf "(c) render.py sent $w ends with exit $_dm_rl_rc, not $want"
      _dm_rl_gone "$d" 5 || cf "(c) render.py sent $w ended and Chrome's processes still run (pids$_dm_rl_left)"
    else
      kill -KILL "$_dm_rl_pid" 2>/dev/null; wait "$_dm_rl_pid" 2>/dev/null
      cf "(c) the stand-in never started under render.py ($w), so nothing was measured"
    fi
    _dm_rl_reap
  done
  # (d) a Chrome that ignores TERM (its helpers inherit that): the group is killed outright after a short wait
  { printf '#!/bin/bash\ntrap "" TERM\n'; sed 1d "$d/chrome"; } > "$d/chrome-deaf"; chmod +x "$d/chrome-deaf"; mv "$d/chrome-deaf" "$d/chrome"
  _dm_rl_start "$d" 2; _dm_rl_wait 20
  { [ "$_dm_rl_rc" -eq 1 ] && grep -q 'FAIL A.dc.html' "$d/out.txt"; } || cf "(d) a timed-out board over a Chrome that ignores TERM is not FAIL with exit 1 within 20 s (exit $_dm_rl_rc)"
  _dm_rl_gone "$d" 5 || cf "(d) a Chrome that ignores TERM still runs after render.py returned (pids$_dm_rl_left)"
  _dm_rl_reap
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A `>` IN A PROPS VALUE AND A ROOT'S data-stories IN ANY LAYOUT MOVE NO APPROVAL AND NO PIN.
#   Operand: normalise-canvas.py over boards whose data-props holds a raw `>`; then check-design-links.py --strict and pin-drift.py over
#   an approved, pinned screen whose props are re-spelled with a raw `>` in them, and whose root's data-stories is rewritten with its
#   attributes on their own lines and then single-quoted.
# =============================================================================
_dm_gt_art() {  # <path> <root attributes as written> <data-props attribute as written> — screen UX-001 with a component script
  mkdir -p "$(dirname "$1")"
  printf '<!doctype html><html><body><x-dc>\n<style>:root { --color-primary: #485d92; }</style>\n<div id="ux-001-root"%s>\n<h1 id="ux-001-title" style="color: var(--color-primary)"><a href="B.dc.html#top">List</a></h1>\n</div></x-dc>\n<script type="text/x-dc" data-dc-script %s>\nclass Component extends DCLogic {}\n</script></body></html>\n' "$2" "$3" > "$1"
}
case_a_gt_in_a_props_value_and_a_roots_data_stories_in_any_layout_move_no_approval_and_no_pin() {
  cf_reset
  local L="normalise-canvas.py rewrites a data-props whose value holds a raw > as it does any other (--check says so, a second run finds nothing, a non-x-dc script is left alone), a board re-spelled around a raw > in its props keeps its approval and its pin, and a change to only the root's data-stories keeps both whether the root's attributes sit on their own lines or the value is single-quoted, the single-quoted value being the one the ARTBOARD line reads"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_links_fixture || { finish "$L"; teardown; return; }
  local m="$REAL_REPO_ROOT/modules/design/scripts/design" n="$SB_TMP/gt" D="$SB_WORK/requirements/design/app/project" P V0 V1 V2 R
  # (a) the normaliser over a raw > in props
  mkdir -p "$n/project"
  printf '{}\n' > "$n/project/canvas.json"
  _dm_gt_art "$n/project/gt.dc.html" ' data-ux="UX-001"' 'data-props="{&quot;a&quot;:&quot;Next >&quot;}"'
  printf '<script type="text/javascript" data-props="{&quot;a&quot;:&quot;Next >&quot;}">x</script>\n' > "$n/project/js.dc.html"
  cp "$n/project/js.dc.html" "$n/js.before"
  _dm_py "$m/normalise-canvas.py" "$n/project" --check
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "would normalise gt.dc.html"; } || cf "(a) --check over a props value holding a raw > does not say it would normalise the board (exit $_dm_rc): $(_dm_brief 300)"
  _dm_has "$_dm_out" "js.dc.html" && cf "(a) a script that is not text/x-dc is rewritten: $(_dm_brief 300)"
  _dm_py "$m/normalise-canvas.py" "$n/project"
  grep -qF "data-props='{\"a\":\"Next >\"}'" "$n/project/gt.dc.html" || cf "(a) a props value holding a raw > is not written in the single-quoted form: $(grep -c data-props "$n/project/gt.dc.html")"
  cmp -s "$n/project/js.dc.html" "$n/js.before" || cf "(a) a script that is not text/x-dc was changed"
  _dm_py "$m/normalise-canvas.py" "$n/project" --check
  [ "$_dm_rc" -eq 0 ] || cf "(a) a second run finds more to normalise (exit $_dm_rc): $(_dm_brief 300)"
  # (b) an approval and a pin over a raw > re-spelled by a page save
  R=' data-ux="UX-001" data-stories="PRD-001-F1-S1"'
  V0="data-props='{\"a\":\"Next >\"}'"
  _dm_gt_art "$D/A.dc.html" "$R" "$V0"
  _dm_commit "the screen carries a raw > in its props"; P="$_DM_SHA"
  _dm_registry "$SB_WORK/requirements/design/app" "UX-001|A.dc.html|default, empty|PRD-001-F1-S1|approved@$P|open" 'UX-002|B.dc.html|default|PRD-001-F1-S2|open|open'
  _dm_card 852 in_progress "design: [UX-001#default@$P]"
  _dm_commit "approve UX-001 and pin a card to it"
  _dm_py scripts/design/check-design-links.py --strict
  [ "$_dm_rc" -eq 0 ] || cf "(b0) the approval is not good straight after it is given (exit $_dm_rc): $(_dm_brief 300)"
  _dm_gt_art "$D/A.dc.html" "$R" 'data-props="{&quot;a&quot;:&quot;Next >&quot;}"'
  _dm_commit "a page save re-spells the props around the raw >"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && ! _dm_has "$_dm_out" "STALE-APPROVAL"; } || cf "(b) a re-spelling around a raw > in props stales the approval (exit $_dm_rc): $(_dm_brief 300)"
  _dm_py scripts/design/pin-drift.py
  [ "$(_dm_verdict "$_dm_out" "$SB_PREFIX-852" "UX-001#default@${P:0:7}")" = clean ] || cf "(b) a re-spelling around a raw > in props reads as drift: $(_dm_brief 300)"
  # (c) the root's attributes on their own lines, then only data-stories changes
  V1="$(printf '\ndata-ux="UX-001"\ndata-stories="PRD-001-F1-S1"')"
  _dm_gt_art "$D/A.dc.html" "$V1" "$V0"
  _dm_commit "the root's attributes on their own lines"; P="$_DM_SHA"
  _dm_registry "$SB_WORK/requirements/design/app" "UX-001|A.dc.html|default, empty|PRD-001-F1-S1|approved@$P|open" 'UX-002|B.dc.html|default|PRD-001-F1-S2|open|open'
  _dm_card 853 in_progress "design: [UX-001#default@$P]"
  _dm_commit "approve it in that layout and pin a card to it"
  V2="$(printf '\ndata-ux="UX-001"\ndata-stories="PRD-001-F1-S1 PRD-002-F1-S1"')"
  _dm_gt_art "$D/A.dc.html" "$V2" "$V0"
  _dm_commit "a PRD adds a story to the screen"
  _dm_py scripts/design/check-design-links.py --strict
  _dm_has "$_dm_out" "STALE-APPROVAL" && cf "(c) a change to only data-stories stales the approval when the root's attributes sit on their own lines: $(_dm_brief 300)"
  _dm_has "$_dm_out" "data-stories ['PRD-001-F1-S1', 'PRD-002-F1-S1'] != registry" || cf "(c) the root's data-stories is not compared with the registry: $(_dm_brief 300)"
  _dm_py scripts/design/pin-drift.py
  [ "$(_dm_verdict "$_dm_out" "$SB_PREFIX-853" "UX-001#default@${P:0:7}")" = clean ] || cf "(c) a change to only data-stories reads as drift when the root's attributes sit on their own lines: $(_dm_brief 300)"
  # (d) the same change, single-quoted
  _dm_gt_art "$D/A.dc.html" "$(printf "\ndata-ux=\"UX-001\"\ndata-stories='PRD-001-F1-S1 PRD-002-F1-S1'")" "$V0"
  _dm_commit "the root's data-stories single-quoted"
  _dm_py scripts/design/check-design-links.py --strict
  _dm_has "$_dm_out" "STALE-APPROVAL" && cf "(d) a single-quoted data-stories stales the approval: $(_dm_brief 300)"
  _dm_has "$_dm_out" "A.dc.html: no data-stories" && cf "(d) a single-quoted data-stories reads as absent: $(_dm_brief 300)"
  _dm_has "$_dm_out" "data-stories ['PRD-001-F1-S1', 'PRD-002-F1-S1'] != registry" || cf "(d) a single-quoted data-stories is not the value the ARTBOARD line reads: $(_dm_brief 300)"
  _dm_py scripts/design/pin-drift.py
  [ "$(_dm_verdict "$_dm_out" "$SB_PREFIX-853" "UX-001#default@${P:0:7}")" = clean ] || cf "(d) a single-quoted data-stories reads as drift: $(_dm_brief 300)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A CANVAS STARTED FROM THE TEMPLATES AND NOT YET FILLED IN READS CLEAN UNDER --strict.
#   Operand: check-design-links.py --strict over the clean link fixture and then over the same project with CANVAS.template.md and
#   COMMENTS.template.md copied as a second canvas's records (SETUP.md step 2), its example rows left as shipped.
# =============================================================================
case_a_canvas_copied_from_the_templates_and_not_yet_filled_in_reads_clean_under_strict() {
  cf_reset
  local L="check-design-links.py --strict exits 0 with no finding over a second canvas whose CANVAS.md and COMMENTS.md are the shipped templates, the example rows of the screen registry being skipped as placeholders"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_links_fixture || { finish "$L"; teardown; return; }
  local t="$SB_WORK/.claude/templates/design"
  [ -f "$t/CANVAS.template.md" ] && [ -f "$t/COMMENTS.template.md" ] || { cf "the sandbox holds no canvas templates under .claude/templates/design"; finish "$L"; teardown; return; }
  mkdir -p "$SB_WORK/requirements/design/shop"
  cp "$t/CANVAS.template.md" "$SB_WORK/requirements/design/shop/CANVAS.md"
  cp "$t/COMMENTS.template.md" "$SB_WORK/requirements/design/shop/COMMENTS.md"
  _dm_commit "a canvas started from the templates"
  _dm_py scripts/design/check-design-links.py --strict
  { [ "$_dm_rc" -eq 0 ] && _dm_has "$_dm_out" "; 0 finding(s)"; } || cf "(a) the unfilled templates are a finding under --strict (exit $_dm_rc): $(_dm_brief 400)"
  _dm_has "$_dm_out" "shop/CANVAS.md" && cf "(a) a line names the unfilled template canvas: $(_dm_brief 400)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A COMMENT SENT TO CLAUDE IS THE GO-AHEAD FOR THE CHANGE IT ASKS, EXCEPT IN THE FIVE CASES THE ROLE LISTS.
#   The expected answer is fixed here, in the placed files: the role's § Comments names each of the five asks; rule 11 stops a pull at the
#   go-ahead only when no sent comment started it; the pull skill's step 6 carries the same exception beside its "go-ahead" and its
#   no-human path; the README says the comment is the go-ahead. Prose: the attended run is where behaviour is measured.
# =============================================================================
case_a_sent_comment_is_the_go_ahead_unless_one_of_five_asks_applies() {
  cf_reset
  local L="the placed role's § Comments says a sent comment is the go-ahead and names the five asks (an approved row back to review, beyond the comment's words, a recorded decision or pinned state, a deleted board or unpulled edit, two designs); rule 11 stops at the go-ahead only for a pull no sent comment started; design-pull step 6 carries the exception; the README says it"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  local m="$REAL_REPO_ROOT/modules/design" role pull sect tok r11
  _md_sandbox
  _md_mod enable design
  [ "$_md_rc" -eq 0 ] || { cf "enable exited $_md_rc: $_md_out"; finish "$L"; teardown; return; }
  role="$(cat "$SB_WORK/.claude/roles/designer.md")"
  pull="$(tr '\n' ' ' <"$SB_WORK/.claude/skills/design-pull/SKILL.md" | tr -s ' ')"
  sect="$(printf '%s\n' "$role" | awk '/^### Comments$/ { f = 1; next } /^##/ { f = 0 } f' | tr '\n' ' ' | tr -s ' ')"
  for tok in 'is the go-ahead for the change it asks' 'approved row back' 'beyond the comment' 'pinned state' 'replaces an edit not yet pulled' 'two designs' 'which of the five applies'; do
    _dm_has "$sect" "$tok" || cf "(a) the role's § Comments does not carry '$tok'"
  done
  r11="$(printf '%s\n' "$role" | awk '/^11[.] / { f = 1 } f && /^$/ { exit } f { print } f && /^## / { exit }' | tr '\n' ' ' | tr -s ' ')"
  _dm_has "$r11" "no sent comment started" || cf "(b) rule 11 does not stop a pull at the go-ahead only when no sent comment started it: $r11"
  _dm_has "$r11" "five asks" || cf "(b) rule 11 names no exception for the five asks"
  for tok in 'sent comment' 'five asks' 'go-ahead' 'no human present'; do
    _dm_has "$pull" "$tok" || cf "(c) design-pull does not carry '$tok'"
  done
  _dm_has "$(tr '\n' ' ' <"$m/README.md" | tr -s ' ')" "go-ahead for the change it asks" || cf "(d) the module README does not say a sent comment is the go-ahead for the change it asks"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A COMMENT SENT TO CLAUDE IS ANSWERED ONLY WHILE A SESSION WATCHES, AND THE DOCUMENTS SAY SO AND TELL THE DESIGNER TO READ THE WAITING THREADS.
#   The expected answer is fixed here, in the placed files: the README says a sent comment waits with no watcher, is not replayed by a watch
#   armed later, and that the page gives no notice; the role carries the act (read the threads awaiting reply on every pull and after every
#   publish); design-publish's step 7 names that read. Prose: the attended run is where behaviour is measured.
# =============================================================================
case_a_comment_sent_while_no_session_watches_waits_and_the_designer_reads_the_waiting_threads() {
  cf_reset
  local L="the module README says a sent comment is answered only while a session watches, is not replayed by a watch armed later and shows no notice on the page; the placed role says to read the threads awaiting reply on every pull and after every publish; design-publish step 7 and design-pull step 7 name that read"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  local m="$REAL_REPO_ROOT/modules/design" rdme role pub pull tok
  _md_sandbox
  _md_mod enable design
  [ "$_md_rc" -eq 0 ] || { cf "enable exited $_md_rc: $_md_out"; finish "$L"; teardown; return; }
  rdme="$(tr '\n' ' ' <"$m/README.md" | tr -s ' ')"
  role="$(tr '\n' ' ' <"$SB_WORK/.claude/roles/designer.md" | tr -s ' ')"
  pub="$(tr '\n' ' ' <"$SB_WORK/.claude/skills/design-publish/SKILL.md" | tr -s ' ')"
  pull="$(tr '\n' ' ' <"$SB_WORK/.claude/skills/design-pull/SKILL.md" | tr -s ' ')"
  for tok in 'answered only while a session watches the canvas' 'does not replay it' 'awaiting reply' 'does not say why'; do
    _dm_has "$rdme" "$tok" || cf "(a) the module README does not carry '$tok'"
  done
  for tok in 'only while a session watches the canvas' 'a watch armed later does not replay it' 'every pull and after every publish'; do
    _dm_has "$role" "$tok" || cf "(b) the placed role does not carry '$tok'"
  done
  _dm_has "$pub" "does not replay earlier comments" || cf "(c) design-publish does not say a publish's watch does not replay earlier comments"
  _dm_has "$pub" "threads awaiting reply" || cf "(c) design-publish does not tell the Designer to read the threads awaiting reply after a publish"
  _dm_has "$pull" "after each publish" || cf "(d) design-pull's comments step does not say to read threads after each publish"
  finish "$L"
  teardown
}
