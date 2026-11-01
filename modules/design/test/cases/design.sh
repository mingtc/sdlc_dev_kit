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
  printf '# PRD-003 — Mixed\n\n## Features\n\n### F1 — Bits\n\n##### F1-S1 — One\n\n**UI:** none\n\n- [ ] AC1: one.\n\n##### F1-S2 — Two\n\n- [ ] AC1: two.\n\n    ```\n' > "$SB_WORK/requirements/PRD-003-mixed.md"
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
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "STALE-APPROVAL"; } || cf "(e) --leaving lets a card pinned after an unapproved token change through (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
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
    { [ "$_dm_rc" -eq 2 ] && _dm_has "$_dm_out" "$3"; } || cf "($1) the row was not refused for '$3' (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
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
  { [ "$_dm_rc" -eq 2 ] && _dm_has "$_dm_out" "is not committed on the trunk"; } || cf "(k) an image only the branch holds passes (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1
  # (l) the tool is not on the trunk: the check cannot answer, and a check that cannot answer is a refusal
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1; git -C "$SB_WORK" reset -q --hard "origin/$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" rm -q -f scripts/design/check-design-cell.py
  _dm_land "the cell tool leaves"
  _dm_row_card "$good"
  _dm_qa_gate "$card" "$SB_TRUNK" "$SB_TRUNK"
  { [ "$_dm_rc" -eq 2 ] && _dm_has "$_dm_out" "could not run"; } || cf "(l) a cell check whose tool is missing passes or refuses without saying it could not run (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-300)"
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
  local L="finish-pr.sh and subtask.sh move land a card whose only AC is (UI) and a one-AC slice once their design row is backed, and refuse a card or a slice whose (UI) AC has no design row, or a slice pinned to a screen with no design row at all, or a row whose images the trunk does not hold, on a project with CODE_GLOBS filled, and land the card and the slice once QA committed the images and the verdict to the trunk with register-commit.sh"
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
  ROW="| AC1 | PASS | design | UX-001#default@$P: identical; $lev/UX-001-default-pin.png, $lev/UX-001-default-build.png | UX-001#empty@$P: identical; $lev/UX-001-empty-pin.png, $lev/UX-001-empty-build.png |" perl -0pi -e 's/(forks: none\n)/$1design: [UX-001#default\@'"$P"', UX-001#empty\@'"$P"']\n/; s/- \[ \] AC1 — [^\n]*\n/- [ ] AC1 — (UI) from PRD-001-F1-S1: both states show. [design: UX-001#default, UX-001#empty]\n/; s/^\| AC1 \|[^\n]*$/$ENV{ROW}/m' "$lf"
  _dm_png "$SB_WORK/$lev/UX-001-default-pin.png" LIST
  _dm_png "$SB_WORK/$lev/UX-001-default-build.png" BUILD
  _dm_land "a slice of two states, the second in a second cell"
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-l" ./scripts/subtask.sh move "$lid" qa_complete 2>&1 </dev/null )"; rc=$?
  { [ "$rc" -ne 0 ] && _dm_has "$out" "UX-001#empty" && origin_has_path "progress/subtasks/$SB_PREFIX-855/dev_complete/$lid-twocell.md"; } || cf "(l) a design row with a second pointer cell lets a state with no image land (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | tail -c 500)"
  # (i) a card whose only AC is (UI), its only row a design row: the cell check that passed makes it the observed row the landing needs
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
  { [ "$rc" -eq 0 ] && origin_has_path "app/list2.txt" && origin_has_path "progress/qa_complete/$aid-allui.md"; } || cf "(i) a card whose only AC is (UI), with a design row the cell check passed, does not land through finish-pr.sh (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | tail -c 500)"
  # (j) a slice with the one AC, (UI), its one row a design row, through subtask.sh
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
  { [ "$rc" -eq 0 ] && origin_has_path "progress/subtasks/$SB_PREFIX-854/qa_complete/$oid-oneac.md"; } || cf "(j) a slice of one (UI) AC with its design row does not move to qa_complete/ (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | tail -c 600)"
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
  local L="m3-tokens.mjs writes the same bytes for the same seed, role names with no prefix, a greyscale wire file and the seed as primary-container, and its output passes the contrast audit in every theme (with --pin-primary a light seed warns and fails it); dtcg-convert.py turns the pulled steep tokens into the pulled design system's tokens.json sections and the first block of its tokens.css, in the type's theme shape; contrast-audit.py reads a pulled board's buttons and a link and flags one set below 44 px; the generated set passes the audit in every theme for the seeds that once failed in wire; a colour object's alpha is read as unread by the audit and written by the converter; the converter reads #rgb and exits 1, naming it, for a colour or dimension it cannot read"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  _dm_node || { skp "$L" "Node 22 or later is absent: m3-tokens.mjs needs it (the module's manifest says optional)"; return; }
  _md_sandbox
  local m="$REAL_REPO_ROOT/modules/design/scripts/design" d="$SB_TMP/tk" i out
  mkdir -p "$d"
  node "$m/m3-tokens.mjs" '#2F6FEB' --name app --out "$d/a/requirements/design/tokens" >/dev/null 2>&1 || cf "(a) m3-tokens.mjs did not run on a seed"
  node "$m/m3-tokens.mjs" '#2F6FEB' --name app --out "$d/b" >/dev/null 2>&1
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
  { [ "$_dm_rc" -eq 0 ] && grep -F -- '--color-surface: #ffffff;' "$d/k/out/tokens.css" >/dev/null && grep -F -- '--color-on-surface: #111111;' "$d/k/out/tokens.css" >/dev/null && grep -F -- '--color-soft: #00000033;' "$d/k/out/tokens.css" >/dev/null && grep -F -- '--color-on-surface: #eeeeee;' "$d/k/out/tokens.css" >/dev/null && grep -F -- '--space-0: 0px;' "$d/k/out/tokens.css" >/dev/null; } || cf "(k) #fff, #111, #eee, a 20% black and a bare 0 are not all in the converted tokens.css (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  printf '%s\n' '{"color":{"surface":{"$value":"#fff"},"badcol":{"$value":"red"}},"space-4":{"$value":"four"}}' > "$d/k/t/k.tokens.json"
  rm -f "$d/k/t/k.dark.tokens.json"
  _dm_py "$m/dtcg-convert.py" "$d/k/t" --out "$d/k/out"
  { [ "$_dm_rc" -eq 1 ] && _dm_has "$_dm_out" "NOT CONVERTED: color.badcol" && _dm_has "$_dm_out" "NOT CONVERTED: space-4" && grep -F -- '--color-surface: #ffffff;' "$d/k/out/tokens.css" >/dev/null; } || cf "(k) a colour and a spacing the converter cannot read are not named with exit 1, the rest written (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-240)"
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
  local L="render.py in real Chrome draws the pulled plant board with its ground #f7fbf0 by default and #10150f with --scheme dark, draws the pulled settings board wire (#f9f9f9) under --theme wire, says NO-THEME-RULE for the boards no sheet answers (they stay #faf8f3), refuses an unknown theme, and fails a board drawn with a runtime that is cut short, empty or another file"
  if ! _dm_have; then skp_lived "$L" "$(_dm_gone_reason)"; return; fi
  _dm_python || { skp "$L" "python3 3.9 or later is absent: the module's checkers and its enable need it"; return; }
  local c rt="${KIT_TEST_DC_RUNTIME:-}" chrome=""
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
  _dm_py "$m/render.py" "$d/plant" "$d/o1" --runtime "$rt" --only Plant.dc.html
  { [ "$_dm_rc" -eq 0 ] && [ "$(pix "$d/o1/Plant.png")" = "#f7fbf0" ]; } || cf "(a) the default scheme does not draw the plant board's light ground #f7fbf0 (exit $_dm_rc, got $(pix "$d/o1/Plant.png" 2>/dev/null)): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  _dm_py "$m/render.py" "$d/plant" "$d/o2" --runtime "$rt" --only Plant.dc.html --scheme dark
  [ "$(pix "$d/o2/Plant.png" 2>/dev/null)" = "#10150f" ] || cf "(b) --scheme dark does not draw the plant board's dark ground #10150f (got $(pix "$d/o2/Plant.png" 2>/dev/null))"
  _dm_py "$m/render.py" "$d/steep" "$d/o3" --runtime "$rt" --theme wire
  [ "$_dm_rc" -eq 0 ] || cf "(c) --theme wire on the steep boards failed (exit $_dm_rc): $(printf '%s' "$_dm_out" | tr '\n' '|' | cut -c1-200)"
  [ "$(pix "$d/o3/Settings.png" 2>/dev/null)" = "#f9f9f9" ] || cf "(c) the settings board, which links the themed sheet, is not drawn wire (#f9f9f9): got $(pix "$d/o3/Settings.png" 2>/dev/null)"
  for b in Main Timer; do
    [ "$(pix "$d/o3/$b.png" 2>/dev/null)" = "#faf8f3" ] || cf "(c) the $b board, which no sheet answers wire for, is not the brand ground #faf8f3: got $(pix "$d/o3/$b.png" 2>/dev/null)"
    printf '%s\n' "$_dm_out" | grep "$b.dc.html" | grep NO-THEME-RULE >/dev/null || cf "(c) $b.dc.html is not said to draw as the brand version"
  done
  _dm_py "$m/render.py" "$d/steep" "$d/o4" --runtime "$rt" --theme no-such
  { [ "$_dm_rc" -eq 2 ] && _dm_has "$_dm_out" "UNKNOWN-THEME"; } || cf "(d) an unknown theme id is not refused (exit $_dm_rc): $_dm_out"
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
