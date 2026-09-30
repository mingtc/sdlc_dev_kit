#!/usr/bin/env bash
# KIT-CLASS: KIT — the QA Verdict / forks: / Ablation landing checks, ONE parser shared by
# finish-pr.sh (a card in progress/dev_complete/) and subtask.sh (a slice's own card, moving to
# qa_complete/ within progress/subtasks/<parent>/). See process/EXTRACTION.md.
#
# Extracted from finish-pr.sh so the same rules, the same rule ids and the same messages apply to
# a subtask's own card. A caller sources this, then calls, each against ONE card file, before any
# destructive step:
#
#   kit_qa_verdict_check <card-file> <card-id>
#     The QA Verdict table (.claude/roles/qa.md step 4): a '## QA Verdict' heading exists, every
#     row has usable evidence, no row is itself FAIL_AC/FAIL_REGRESSION, the table's AC ids match
#     the card's own '- [ ] <id> —' checklist bullets one for one, and the fixed 'shadow-check'
#     row is present and filled. Refuses through kit_refuse with: qa-verdict-missing,
#     qa-verdict-evidence-missing, qa-verdict-fail, qa-verdict-ac-mismatch,
#     qa-verdict-shadow-missing.
#
#   kit_forks_check <card-file> <card-id> <repo> <old-rev> <new-rev> <check-board-path>
#     process/MANUAL.md § Execution discipline item 6: 'forks:' names every fork ruling the
#     branch resolved, or 'none'. <old-rev>/<new-rev> bound the diff a resolved-but-uncited fork
#     is derived from (finish-pr.sh: the trunk and the feature branch); <card-file> is read for
#     the field itself and is <new-rev>'s own copy. Refuses through kit_refuse with:
#     forks-missing, forks-malformed, forks-register-undeclared, forks-register-unreadable,
#     forks-unresolved, forks-contradicted.
#
#   kit_ablation_check <card-file> <card-id> <repo> <old-rev> <new-rev>
#     process/doctrine/instruments.md § A.2: a diff touching a declared TEST_GLOBS path needs a
#     well-formed '## Ablation' section. TEST_GLOBS is read as the UNION of <old-rev>'s and
#     <new-rev>'s scripts/config.sh. UNDECLARED makes the check UNRUNNABLE — printed on stdout as
#     'ABLATION_CHECK: did not run', never a silent pass — same as an <old-rev>==<new-rev> (no
#     diff to read) or a <new-rev> that does not resolve, both printed as UNRUNNABLE by the same
#     line rather than treated as "touches nothing". Refuses through kit_refuse with:
#     ablation-config-unreadable, ablation-missing, ablation-malformed.
#
# Every refusal is unchanged from finish-pr.sh's own inline text before this extraction — the
# self-test's finish-pr.sh cases are the regression proof for that. A caller with no branch of its
# own for the card (a subtask slice not yet its own branch) passes <old-rev>/<new-rev> such that
# they resolve to the SAME revision (e.g. the trunk twice): the forks/ablation DIFF derivation
# then legitimately finds nothing, which is not the same claim as "no fork exists" or "no test
# path touched" — state that in the caller's own words, this file does not.

# ── kit_qa_verdict_check <card-file> <card-id> ──────────────────────────────────────────────
kit_qa_verdict_check() {
  local src="$1" issue_id="$2"
  local _qav_body _qav_ac_ids _qav_table _qav_rows
  local _qav_table_ids="" _qav_evidence_bad="" _qav_fail_rows="" _qav_shadow_seen="" _qav_shadow_bad=""
  local _qrow _qid _qverdict _qkind _qptr _qptr_stripped

  _qav_body="$(awk '/^## QA Verdict[[:space:]]*$/{exit} {print}' "$src")"
  _qav_ac_ids="$(printf '%s\n' "$_qav_body" | grep -oE '^- \[[ xX]\] [A-Za-z][A-Za-z0-9]* —' | sed -E 's/^- \[[ xX]\] //; s/ —$//' | sort -u || true)"

  if ! grep -qE '^## QA Verdict[[:space:]]*$' "$src"; then
    kit_refuse 2 qa-verdict-missing \
      "Error: ${issue_id} has no '## QA Verdict' table." \
      "       QA fills one row per AC id plus the fixed 'shadow-check' row before a PASS lands." \
      "       (.claude/roles/qa.md step 4.)" \
      "       NOTHING WAS CHANGED."
  fi

  _qav_table="$(awk '/^## QA Verdict[[:space:]]*$/{f=1; next} f && /^## /{exit} f{print}' "$src")"
  _qav_rows="$(printf '%s\n' "$_qav_table" | grep -E '^\|' | grep -vE '^\|[[:space:]]*(AC id|-+)[[:space:]]*\|' || true)"

  while IFS= read -r _qrow; do
    [ -n "$_qrow" ] || continue
    _qid="$(printf '%s' "$_qrow"     | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2}')"
    _qverdict="$(printf '%s' "$_qrow" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$3); print $3}')"
    _qkind="$(printf '%s' "$_qrow"    | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$4); print $4}')"
    _qptr="$(printf '%s' "$_qrow"     | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$5); print $5}')"
    _qkind="$(printf '%s' "$_qkind" | tr -d '`')"
    _qptr_stripped="$(printf '%s' "$_qptr" | tr -d '`')"

    if [ "$_qid" = "shadow-check" ]; then
      _qav_shadow_seen=1
      case "$_qptr_stripped" in
        ''|'<placeholder>') _qav_shadow_bad=1 ;;
      esac
      continue
    fi

    [ -n "$_qid" ] || continue
    _qav_table_ids="${_qav_table_ids}${_qav_table_ids:+$'\n'}${_qid}"

    case "$_qkind" in
      test|file:line|gate-diff|fixture-diff) : ;;
      *) _qav_evidence_bad="${_qav_evidence_bad}${_qav_evidence_bad:+, }${_qid} (evidence kind '${_qkind}')" ;;
    esac
    case "$_qptr_stripped" in
      ''|'<placeholder>') _qav_evidence_bad="${_qav_evidence_bad}${_qav_evidence_bad:+, }${_qid} (empty or placeholder pointer)" ;;
    esac
    case "$_qverdict" in
      FAIL_AC|FAIL_REGRESSION) _qav_fail_rows="${_qav_fail_rows}${_qav_fail_rows:+, }${_qid}" ;;
    esac
  done <<< "$_qav_rows"

  if [ -n "$_qav_evidence_bad" ]; then
    kit_refuse 2 qa-verdict-evidence-missing \
      "Error: ${issue_id}'s QA Verdict table has row(s) with no usable evidence: ${_qav_evidence_bad}" \
      "       A PASS needs an evidence kind from test|file:line|gate-diff|fixture-diff, and a real" \
      "       (non-placeholder) pointer, for every AC row. (.claude/roles/qa.md step 4.)" \
      "       NOTHING WAS CHANGED."
  fi

  if [ -n "$_qav_fail_rows" ]; then
    kit_refuse 2 qa-verdict-fail \
      "Error: ${issue_id}'s QA Verdict table has FAIL row(s) on a PASS landing: ${_qav_fail_rows}" \
      "       A row whose own verdict is FAIL_AC or FAIL_REGRESSION cannot ship under an overall PASS." \
      "       (.claude/roles/qa.md step 4, step 6.)" \
      "       NOTHING WAS CHANGED."
  fi

  local _qav_table_ids_sorted _qav_missing _qav_extra
  _qav_table_ids_sorted="$(printf '%s\n' "$_qav_table_ids" | grep -E '.' | sort -u || true)"
  if [ "$_qav_table_ids_sorted" != "$_qav_ac_ids" ]; then
    _qav_missing="$(comm -23 <(printf '%s\n' "$_qav_ac_ids") <(printf '%s\n' "$_qav_table_ids_sorted") | tr '\n' ' ')"
    _qav_extra="$(comm -13 <(printf '%s\n' "$_qav_ac_ids") <(printf '%s\n' "$_qav_table_ids_sorted") | tr '\n' ' ')"
    kit_refuse 2 qa-verdict-ac-mismatch \
      "Error: ${issue_id}'s QA Verdict table's AC ids do not match its AC checklist one for one." \
      "       Missing from the table: ${_qav_missing:-none}. Extra in the table: ${_qav_extra:-none}." \
      "       (.claude/roles/qa.md step 4.)" \
      "       NOTHING WAS CHANGED."
  fi

  if [ -z "$_qav_shadow_seen" ] || [ -n "$_qav_shadow_bad" ]; then
    kit_refuse 2 qa-verdict-shadow-missing \
      "Error: ${issue_id}'s QA Verdict table has no filled 'shadow-check' row." \
      "       State 'assertions removed: none', or each removed/weakened assertion with its replacement." \
      "       (.claude/roles/qa.md step 4.)" \
      "       NOTHING WAS CHANGED."
  fi
}

# ── kit_forks_check <card-file> <card-id> <repo> <old-rev> <new-rev> <check-board-path> ────────
kit_forks_check() {
  local src="$1" issue_id="$2" repo="$3" old_rev="$4" new_rev="$5" check_board="$6"
  local _forks_line _forks_ids="" _forks_inner _forks_n_tokens _forks_n_ids
  local _forks_declared _forks_regs _forks_citation_marker='\[decision: (D-[0-9]+)\]' _forks_cited
  local _forks_live_all="" _forks_seen_all=""
  local _freg_path _freg_mark _freg_shape _forks_branch_reg
  local _forks_bad="" _fid _forks_derived _forks_missing_ids=""

  _forks_line="$(awk '/^---[[:space:]]*$/{n++; next} n==1 && /^forks:/{sub(/^forks:[[:space:]]*/, ""); sub(/(^|[[:space:]]+)#.*$/, ""); sub(/[[:space:]]+$/, ""); print; exit}' "$src")"
  if [ -z "$_forks_line" ]; then
    kit_refuse 2 forks-missing \
      "Error: ${issue_id} has no 'forks:' field." \
      "       State the fork ids this card resolved ('forks: [D-NN, ...]') or 'forks: none' if it resolved none." \
      "       (process/MANUAL.md § Execution discipline item 6; requirements/DECISIONS.md § Which decisions live HERE.)" \
      "       NOTHING WAS CHANGED."
  fi
  case "$_forks_line" in
    none) : ;;
    \[*\])
      _forks_inner="${_forks_line#\[}"; _forks_inner="${_forks_inner%\]}"
      _forks_ids="$(printf '%s' "$_forks_inner" | tr ',' '\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | grep -E '^D-[0-9]+$' || true)"
      _forks_n_tokens="$(printf '%s' "$_forks_inner" | tr ',' '\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | grep -c . || true)"
      _forks_n_ids="$(printf '%s\n' "$_forks_ids" | grep -c . || true)"
      if [ -z "$_forks_inner" ] || [ "${_forks_n_tokens:-0}" -eq 0 ] || [ "${_forks_n_tokens:-0}" -ne "${_forks_n_ids:-0}" ] 2>/dev/null; then
        kit_refuse 2 forks-malformed \
          "Error: ${issue_id}'s 'forks:' field is not 'none' or a list of D-NN ids: forks: ${_forks_line}" \
          "       (process/MANUAL.md § Execution discipline item 6; requirements/DECISIONS.md § Which decisions live HERE.)" \
          "       NOTHING WAS CHANGED."
      fi
      ;;
    *)
      kit_refuse 2 forks-malformed \
        "Error: ${issue_id}'s 'forks:' field is not 'none' or a list of D-NN ids: forks: ${_forks_line}" \
        "       (process/MANUAL.md § Execution discipline item 6; requirements/DECISIONS.md § Which decisions live HERE.)" \
        "       NOTHING WAS CHANGED."
      ;;
  esac

  _forks_declared="$(kit_registers_declared "$check_board")" || _forks_declared=""
  if [ -z "$_forks_declared" ]; then
    kit_refuse 1 forks-register-undeclared \
      "Error: could not read a 'REGISTERS=' declaration from ${check_board#"$repo"/}." \
      "       The 'forks:' check derives its register set from check-board.sh's own declaration" \
      "       (the same one arm [l] resolves citations against) and never guesses a path." \
      "       NOTHING WAS CHANGED."
  fi
  _forks_regs="$(printf '%s\n' "$_forks_declared" | awk -F'|' '$3 == "D-[0-9]+" { print }')"
  _forks_cited="$(grep -oE "$_forks_citation_marker" "$src" 2>/dev/null | sed -E 's/^\[decision:[[:space:]]*//; s/\]$//' | sort -u || true)"

  while IFS='|' read -r _freg_path _freg_mark _freg_shape; do
    [ -n "$_freg_path" ] || continue

    _forks_branch_reg="$(mktemp "${TMPDIR:-/tmp}/finish-pr-forks-reg.XXXXXX" 2>/dev/null || true)"
    if [ -z "$_forks_branch_reg" ]; then
      kit_refuse 1 forks-register-unreadable \
        "Error: could not create a scratch file to read ${new_rev}'s copy of ${_freg_path} — refusing rather than skipping the 'forks:' check." \
        "       NOTHING WAS CHANGED."
    fi
    git -C "$repo" show "${new_rev}:${_freg_path}" > "$_forks_branch_reg" 2>/dev/null || : > "$_forks_branch_reg"

    _forks_live_all="$_forks_live_all
$(kit_decision_register_live "$_forks_branch_reg" "$_freg_mark" 'D-[0-9]+')"
    _forks_seen_all="$_forks_seen_all
$(kit_decisions_touched_by_diff "$repo" "$old_rev" "$new_rev" "$_freg_path" "$_freg_mark")"

    rm -f "$_forks_branch_reg"
  done <<< "$(printf '%s\n' "$_forks_regs")"
  _forks_live_all="$(printf '%s\n' "$_forks_live_all" | grep -E '^D-[0-9]+$' | sort -u || true)"
  _forks_seen_all="$(printf '%s\n' "$_forks_seen_all" | grep -E '^D-[0-9]+$' | sort -u || true)"

  if [ -n "$_forks_ids" ]; then
    while IFS= read -r _fid; do
      [ -n "$_fid" ] || continue
      printf '%s\n' "$_forks_live_all" | grep -qx "$_fid" || _forks_bad="${_forks_bad}${_forks_bad:+, }$_fid"
    done <<< "$(printf '%s\n' "$_forks_ids")"
    if [ -n "$_forks_bad" ]; then
      kit_refuse 2 forks-unresolved \
        "Error: ${issue_id}'s 'forks:' names an id that is not a live entry in any declared D- register: ${_forks_bad}" \
        "       Fix the id, or add the ruling it names to the register in this same change." \
        "       NOTHING WAS CHANGED."
    fi
  fi

  _forks_derived="$(printf '%s\n%s\n' "$_forks_seen_all" "$_forks_cited" | grep -E '^D-[0-9]+$' | sort -u || true)"
  while IFS= read -r _fid; do
    [ -n "$_fid" ] || continue
    printf '%s\n' "$_forks_ids" | grep -qx "$_fid" || _forks_missing_ids="${_forks_missing_ids}${_forks_missing_ids:+, }$_fid"
  done <<< "$(printf '%s\n' "$_forks_derived")"
  if [ -n "$_forks_missing_ids" ]; then
    kit_refuse 2 forks-contradicted \
      "Error: ${issue_id}'s branch ('${new_rev}') shows a fork 'forks:' does not name: ${_forks_missing_ids}" \
      "       (a register entry the branch's diff adds or changes, or an Activity '[decision: D-NN]' citation)." \
      "       Add the id(s) to 'forks:' — 'forks: ${_forks_line}' does not account for them." \
      "       NOTHING WAS CHANGED."
  fi
}

# ── kit_ablation_check <card-file> <card-id> <repo> <old-rev> <new-rev> ────────────────────────
kit_ablation_check() {
  local src="$1" issue_id="$2" repo="$3" old_rev="$4" new_rev="$5"
  local _abl_cfg_branch _abl_line _abl_test_globs=()
  local _abl_diff_paths _abl_touches_test="" _abl_path _abl_g
  local _abl_body _abl_broken _abl_red _abl_bad

  _abl_cfg_branch="$(mktemp "${TMPDIR:-/tmp}/finish-pr-test-globs.XXXXXX" 2>/dev/null || true)"
  if [ -z "$_abl_cfg_branch" ]; then
    kit_refuse 1 ablation-config-unreadable \
      "Error: could not create a scratch file to read scripts/config.sh — refusing rather than skipping the ablation check." \
      "       NOTHING WAS CHANGED."
  fi
  { git -C "$repo" show "${old_rev}:scripts/config.sh" 2>/dev/null || :
    git -C "$repo" show "${new_rev}:scripts/config.sh" 2>/dev/null || :; } > "$_abl_cfg_branch"

  while IFS= read -r _abl_line; do
    _abl_test_globs+=("$_abl_line")
  done < <(awk '
    /^TEST_GLOBS=\($/ { in_arr=1; next }
    in_arr && /^\)/ { in_arr=0; next }
    in_arr {
      line=$0
      sub(/^[[:space:]]*/, "", line)
      sub(/[[:space:]]*#.*$/, "", line)
      if (line == "") next
      gsub(/^"|"$/, "", line)
      print line
    }
  ' "$_abl_cfg_branch")
  rm -f "$_abl_cfg_branch"

  if [ ${#_abl_test_globs[@]} -eq 0 ]; then
    echo "ABLATION_CHECK: did not run — TEST_GLOBS is undeclared in scripts/config.sh (adopter action required)."
  else
    _abl_diff_paths="$(git -C "$repo" diff --name-only "${old_rev}...${new_rev}" 2>/dev/null || true)"
    while IFS= read -r _abl_path; do
      [ -n "$_abl_path" ] || continue
      for _abl_g in "${_abl_test_globs[@]}"; do
        case "$_abl_path" in
          $_abl_g) _abl_touches_test="$_abl_touches_test$_abl_path"$'\n' ;;
        esac
      done
    done <<< "$_abl_diff_paths"

    if [ -n "$_abl_touches_test" ]; then
      if ! grep -qE '^## Ablation[[:space:]]*$' "$src"; then
        kit_refuse 2 ablation-missing \
          "Error: ${issue_id}'s branch ('${new_rev}') touches a declared test path but has no '## Ablation' section." \
          "       Touched test path(s): $(printf '%s' "$_abl_touches_test" | tr '\n' ' ')" \
          "       State what was broken and the red line it produced." \
          "       (process/doctrine/instruments.md § A.2; .claude/roles/dev.md Definition of Done.)" \
          "       NOTHING WAS CHANGED."
      fi
      _abl_body="$(awk '/^## Ablation[[:space:]]*$/{f=1; next} f && /^## /{exit} f{print}' "$src")"
      _abl_broken="$(printf '%s\n' "$_abl_body" | sed -n 's/^Broken:[[:space:]]*//p' | head -1)"
      _abl_red="$(printf '%s\n' "$_abl_body" | sed -n 's/^Red line:[[:space:]]*//p' | head -1)"
      case "$_abl_broken" in ''|'<placeholder>') _abl_bad=1 ;; *) _abl_bad="" ;; esac
      case "$_abl_red" in ''|'<placeholder>') _abl_bad="${_abl_bad}1" ;; esac
      if [ -n "$_abl_bad" ]; then
        kit_refuse 2 ablation-malformed \
          "Error: ${issue_id}'s '## Ablation' section is not well formed." \
          "       It needs a non-empty 'Broken: <what>' line and a non-empty 'Red line: <the output>' line." \
          "       (process/doctrine/instruments.md § A.2; .claude/roles/dev.md Definition of Done.)" \
          "       NOTHING WAS CHANGED."
      fi
      echo "ABLATION_CHECK: PASS — '## Ablation' present and well formed for a diff touching a declared test path."
    else
      echo "ABLATION_CHECK: PASS — the branch diff touches no declared test path."
    fi
  fi
}
