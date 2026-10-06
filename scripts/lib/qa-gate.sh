#!/usr/bin/env bash
# KIT-CLASS: KIT — the QA Verdict / forks: / Ablation landing checks, ONE parser shared by
# finish-pr.sh (a card in progress/dev_complete/) and subtask.sh (a slice's own card, moving to
# qa_complete/ within progress/subtasks/<parent>/). See process/EXTRACTION.md.
#
# Extracted from finish-pr.sh so the same rules, the same rule ids and the same messages apply to
# a subtask's own card. A caller sources this, then calls, each against ONE card file, before any
# destructive step:
#
#   kit_qa_verdict_check <card-file> <card-id> <repo> <rev>
#     The QA Verdict table (.claude/roles/qa.md step 4): a '## QA Verdict' heading exists, every
#     row has usable evidence, no row is itself FAIL_AC/FAIL_REGRESSION, the table's AC ids match
#     the card's own '- [ ] <id> —'/'- [ ] <id> -'/'- [ ] <id>:' checklist bullets one for one, and
#     the fixed 'shadow-check' row is present and filled. <rev> is the revision being landed (read
#     in <repo> with `git cat-file`/`git show`) — every evidence pointer is checked against IT, not
#     the caller's working tree. A `file:line`/`test` row's pointer must resolve (the file exists
#     at <rev> and the line, or range, is within its length) and carry a short quote the gate finds
#     at that line, whitespace-normalised; `gate-diff`/`fixture-diff` are exempt from the quote but
#     not from a `path:line` token they do carry resolving. Refuses through kit_refuse with:
#     qa-verdict-missing, qa-verdict-evidence-missing, qa-verdict-fail, qa-verdict-ac-mismatch,
#     qa-verdict-shadow-missing, qa-verdict-pointer-unresolved, qa-verdict-quote-missing,
#     qa-verdict-quote-not-found.
#
#   kit_forks_check <card-file> <card-id> <repo> <old-rev> <new-rev> <check-board-path>
#     process/MANUAL.md § Execution discipline item 6: 'forks:' names every fork ruling the
#     branch resolved, or 'none'. <old-rev>/<new-rev> bound the diff a resolved-but-uncited fork
#     is derived from (finish-pr.sh: the trunk and the feature branch); <card-file> is read for
#     the field itself and is <new-rev>'s own copy.
#     ALSO: an AC bullet's own TEXT changed (separators/whitespace aside) after the card's own
#     history shows it leaving a 'todo/' column (a rename whose OLD path ends in '/todo/' —
#     'progress/todo/' or a subtask's own 'progress/subtasks/<parent>/todo/') needs a
#     '[decision: D-NN]' citation somewhere on the card — a ruling written straight into an AC,
#     with no register entry and no citation, is invisible to the derivation above. A card whose
#     history never shows it leaving a 'todo/' column (minted straight into another one) makes
#     this half UNRUNNABLE, printed on stdout the same way kit_ablation_check reports an
#     undeclared TEST_GLOBS. This history is read from <old-rev> (the TRUNK), never <new-rev>:
#     move-issue.sh/subtask.sh commit every board move on the trunk inside their own kanban
#     worktree, so a branch cut before a later move never carries the card's later path at all.
#     <card-file> may be the CALLER's own worktree copy (finish-pr.sh's kanban worktree,
#     subtask.sh's subtask tree) rather than a path under <repo> — its 'progress/...' suffix is
#     what is read against <repo>'s history, never its full path.
#     Refuses through kit_refuse with: forks-missing, forks-malformed, forks-register-undeclared,
#     forks-register-unreadable, forks-unresolved, forks-contradicted, forks-ac-changed-uncited.
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

# The whole-cell placeholder forms (an EMPTY cell is checked separately, with a plain shell
# string test — a leading empty alternative in the regex itself makes some greps refuse the
# pattern outright), refused regardless of evidence kind: compared case-insensitively after
# stripping backticks and leading/trailing whitespace from the cell. ONE list — qa.md's prose, the
# templates and any future reader name this constant, not their own copy.
KIT_QAV_PLACEHOLDER_RE='^(n/a|na|none|tbd|see above|see below|-|—|x|\.\.\.|\?|<[^>]*>)$'

# An AC checklist bullet ('- [ ] AC1 — text.') separates its id from its text with an em-dash,
# a hyphen or a colon — ONE fragment for every reader that must recognise a bullet, so a
# separator reformat reads the same way to all of them.
KIT_AC_SEP='[[:space:]]*(—|-|:)'

# _qav_ac_ids <body> — every AC id a checklist bullet declares, one per line, sorted and
# de-duplicated. The population kit_qa_verdict_check's table must match one for one.
_qav_ac_ids() {
  printf '%s\n' "$1" | grep -oE "^- \[[ xX]\] [A-Za-z][A-Za-z0-9]*${KIT_AC_SEP}" \
    | sed -E "s/^- \[[ xX]\] //; s/${KIT_AC_SEP}\$//" | sort -u
}

# _qav_ac_bullet_text <body> <id> — the NORMALISED text of AC <id>'s own checklist bullet (the
# part after its separator), or empty if <id> has no bullet in <body>. Normalised so a pure
# separator/whitespace reformat (em-dash <-> hyphen <-> colon, a run of spaces, trailing
# whitespace) compares equal: kit_forks_check's history comparison asks whether the RULING
# changed, not whether the punctuation did.
_qav_ac_bullet_text() {
  local body="$1" id="$2" _line _text
  _line="$(printf '%s\n' "$body" | grep -E "^- \\[[ xX]\\] ${id}${KIT_AC_SEP}" | head -1)"
  [ -n "$_line" ] || return 0
  _text="$(printf '%s' "$_line" | sed -E "s/^- \[[ xX]\] [A-Za-z][A-Za-z0-9]*${KIT_AC_SEP}[[:space:]]*//")"
  printf '%s' "$_text" | tr -s '[:space:]' ' ' | sed -E 's/^ //; s/ $//'
}

# _qav_is_placeholder <normalised-cell> — true if <normalised-cell> (already lower-cased, with
# backticks and outer whitespace stripped) is empty or one of KIT_QAV_PLACEHOLDER_RE's forms.
_qav_is_placeholder() {
  [ -z "$1" ] && return 0
  printf '%s' "$1" | grep -qE "$KIT_QAV_PLACEHOLDER_RE"
}

# _qav_resolve_pointers <repo> <rev> <cell> — every `path:line`/`path:a-b` token found in <cell>,
# checked against <rev> (git cat-file for existence, a line count for range). Echoes one
# "path:line:TOKEN_OK" or "path:line:TOKEN_BAD <why>" per token found; nothing if none is found.
_qav_resolve_pointers() {
  local repo="$1" rev="$2" cell="$3" _tok _path _range _lo _hi _nlines
  while IFS= read -r _tok; do
    [ -n "$_tok" ] || continue
    _path="${_tok%%:*}"
    _range="${_tok#*:}"
    case "$_range" in
      *-*) _lo="${_range%-*}"; _hi="${_range#*-}" ;;
      *)   _lo="$_range"; _hi="$_range" ;;
    esac
    if ! git -C "$repo" cat-file -e "${rev}:${_path}" 2>/dev/null; then
      printf '%s\n' "${_tok}:BAD does not exist at ${rev}"
      continue
    fi
    _nlines="$(git -C "$repo" show "${rev}:${_path}" 2>/dev/null | wc -l | tr -d ' ')"
    if [ -z "$_lo" ] || [ -z "$_hi" ] || ! [ "$_lo" -ge 1 ] 2>/dev/null || ! [ "$_hi" -ge "$_lo" ] 2>/dev/null; then
      printf '%s\n' "${_tok}:BAD malformed line range"
    elif [ "$_hi" -gt "$_nlines" ]; then
      printf '%s\n' "${_tok}:BAD line ${_hi} is past ${_path}'s ${_nlines} line(s) at ${rev}"
    else
      printf '%s\n' "${_tok}:OK ${_lo} ${_hi}"
    fi
  done <<< "$(printf '%s\n' "$cell" | sed 's/"[^"]*"//g' | grep -oE '[^[:space:]`"(),]+:[0-9]+(-[0-9]+)?' || true)"
}

# _qav_quote_in_range <repo> <rev> <path> <lo> <hi> <quote> — true if <quote>, whitespace-
# normalised (runs of whitespace collapsed to one space, outer whitespace trimmed), is a
# substring of <path>'s lines <lo>-<hi> at <rev>, normalised the same way.
_qav_quote_in_range() {
  local repo="$1" rev="$2" path="$3" lo="$4" hi="$5" quote="$6" _hay _needle
  _hay="$(git -C "$repo" show "${rev}:${path}" 2>/dev/null | sed -n "${lo},${hi}p" | tr '\n' ' ')"
  _hay="$(printf '%s' "$_hay" | tr -s '[:space:]' ' ' | sed -E 's/^ //; s/ $//')"
  _needle="$(printf '%s' "$quote" | tr -s '[:space:]' ' ' | sed -E 's/^ //; s/ $//')"
  [ -n "$_needle" ] && case "$_hay" in *"$_needle"*) return 0 ;; esac
  return 1
}

# ── kit_qa_verdict_check <card-file> <card-id> <repo> <rev> ────────────────────────────────────
kit_qa_verdict_check() {
  local src="$1" issue_id="$2" repo="$3" rev="$4"
  local _qav_body _qav_ac_ids _qav_table _qav_rows
  local _qav_table_ids="" _qav_evidence_bad="" _qav_fail_rows="" _qav_shadow_seen="" _qav_shadow_bad=""
  local _qav_unresolved="" _qav_quote_missing="" _qav_quote_not_found=""
  local _qrow _qid _qverdict _qkind _qptr _qptr_stripped

  if [ -z "$repo" ] || [ -z "$rev" ]; then
    echo "kit_qa_verdict_check: <repo> and <rev> are required — evidence pointers are read at the revision being landed." >&2
    exit 2
  fi

  _qav_body="$(awk '/^## QA Verdict[[:space:]]*$/{exit} {print}' "$src")"
  _qav_ac_ids="$(_qav_ac_ids "$_qav_body" || true)"

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
      local _qav_shadow_norm
      _qav_shadow_norm="$(printf '%s' "$_qptr_stripped" | tr '[:upper:]' '[:lower:]' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      _qav_is_placeholder "$_qav_shadow_norm" && _qav_shadow_bad=1
      continue
    fi

    [ -n "$_qid" ] || continue
    _qav_table_ids="${_qav_table_ids}${_qav_table_ids:+$'\n'}${_qid}"

    case "$_qkind" in
      test|file:line|gate-diff|fixture-diff) : ;;
      *) _qav_evidence_bad="${_qav_evidence_bad}${_qav_evidence_bad:+, }${_qid} (evidence kind '${_qkind}')" ;;
    esac
    # A placeholder cell is refused whole, after stripping backticks/whitespace, case-insensitive
    # (one list: KIT_QAV_PLACEHOLDER_RE above; qa.md step 4 states it in prose).
    local _qav_ptr_norm
    _qav_ptr_norm="$(printf '%s' "$_qptr_stripped" | tr '[:upper:]' '[:lower:]' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    if _qav_is_placeholder "$_qav_ptr_norm"; then
      _qav_evidence_bad="${_qav_evidence_bad}${_qav_evidence_bad:+, }${_qid} (empty or placeholder pointer)"
    else
      # Every path:line/path:a-b token in the cell must resolve AT $rev. A `file:line`
      #    row needs at least one such token; the other kinds are checked only on the tokens they
      #    do carry (a gate-diff/fixture-diff row naming a file:line is held to it; one naming none
      #    is not asked to invent one).
      local _qav_tok_results _qav_tok_line _qav_tok _qav_tok_rest
      local _qav_first_ok_path="" _qav_first_ok_lo="" _qav_first_ok_hi="" _qav_tok_count=0
      _qav_tok_results="$(_qav_resolve_pointers "$repo" "$rev" "$_qptr_stripped")"
      while IFS= read -r _qav_tok_line; do
        [ -n "$_qav_tok_line" ] || continue
        _qav_tok_count=$((_qav_tok_count+1))
        _qav_tok="${_qav_tok_line%%:*}"
        _qav_tok_rest="${_qav_tok_line#*:}"
        case "$_qav_tok_rest" in
          *:BAD\ *)
            _qav_unresolved="${_qav_unresolved}${_qav_unresolved:+, }${_qid} (${_qav_tok_line#*:BAD }: ${_qav_tok})"
            ;;
          *:OK\ *)
            if [ -z "$_qav_first_ok_path" ]; then
              _qav_first_ok_path="${_qav_tok%%:*}"
              _qav_first_ok_lo="$(printf '%s' "${_qav_tok_rest#*:OK }" | awk '{print $1}')"
              _qav_first_ok_hi="$(printf '%s' "${_qav_tok_rest#*:OK }" | awk '{print $2}')"
            fi
            ;;
        esac
      done <<< "$_qav_tok_results"
      if [ "$_qkind" = "file:line" ] && [ "$_qav_tok_count" -eq 0 ]; then
        _qav_unresolved="${_qav_unresolved}${_qav_unresolved:+, }${_qid} (no path:line token in a file:line row)"
      fi

      # file:line/test rows carry a short double-quoted verbatim quote, checked against
      #    the first resolving path:line token's line range — so a `test` row's pointer needs that
      #    token too, the same as `file:line`, or there is nothing to check the quote against.
      #    gate-diff/fixture-diff are exempt from the quote (but item 1 still binds any token they
      #    do carry).
      case "$_qkind" in
        file:line|test)
          local _qav_quote
          _qav_quote="$(printf '%s' "$_qptr_stripped" | sed -n 's/.*"\([^"]*\)".*/\1/p')"
          if [ -z "$_qav_quote" ]; then
            _qav_quote_missing="${_qav_quote_missing}${_qav_quote_missing:+, }${_qid}"
          elif [ -z "$_qav_first_ok_path" ]; then
            if [ "$_qav_tok_count" -eq 0 ]; then
              _qav_unresolved="${_qav_unresolved}${_qav_unresolved:+, }${_qid} (no path:line token to check the quote against)"
            fi
            # else: a token was present but it already failed above (qa-verdict-pointer-unresolved).
          elif ! _qav_quote_in_range "$repo" "$rev" "$_qav_first_ok_path" "$_qav_first_ok_lo" "$_qav_first_ok_hi" "$_qav_quote"; then
            _qav_quote_not_found="${_qav_quote_not_found}${_qav_quote_not_found:+, }${_qid} (\"${_qav_quote}\" not found at ${_qav_first_ok_path}:${_qav_first_ok_lo}-${_qav_first_ok_hi})"
          fi
          ;;
      esac
    fi
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

  if [ -n "$_qav_unresolved" ]; then
    kit_refuse 2 qa-verdict-pointer-unresolved \
      "Error: ${issue_id}'s QA Verdict table has row(s) whose evidence pointer does not resolve in the tree being landed: ${_qav_unresolved}" \
      "       A file:line/path:a-b token must name a file that exists at the revision being" \
      "       landed, at a line (or range) within its length. (.claude/roles/qa.md step 4.)" \
      "       NOTHING WAS CHANGED."
  fi

  if [ -n "$_qav_quote_missing" ]; then
    kit_refuse 2 qa-verdict-quote-missing \
      "Error: ${issue_id}'s QA Verdict table has test/file:line row(s) with no quoted evidence: ${_qav_quote_missing}" \
      "       A test or file:line row's evidence pointer carries a short verbatim quote in double" \
      "       quotes after the pointer, e.g. 'src/add.js:12 \"return a + b\"'. (.claude/roles/qa.md step 4.)" \
      "       NOTHING WAS CHANGED."
  fi

  if [ -n "$_qav_quote_not_found" ]; then
    kit_refuse 2 qa-verdict-quote-not-found \
      "Error: ${issue_id}'s QA Verdict table has row(s) whose quote is not on the cited line: ${_qav_quote_not_found}" \
      "       The quote (surrounding whitespace normalised) must be a substring of the cited" \
      "       path:line/path:a-b's own lines at the revision being landed. (.claude/roles/qa.md step 4.)" \
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
  local _forks_card_rel _forks_rename_log _forks_leave_commit="" _forks_leave_path=""
  local _frl_a _frl_b _frl_c _frl_commit=""
  local _forks_new_body _forks_old_body _forks_ac_ids _forks_ac_drift="" _fac _fac_old _fac_new

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

  # A ruling written straight into an AC's own text never touches the register and never adds a
  # '[decision: D-NN]' citation, so the derivation above cannot see it — the only trace is the AC
  # TEXT itself changing after the card was already underway. "Underway" is read from the card's
  # own file history: the commit where a rename moved it OUT of a 'todo/' column (never by
  # parsing a commit subject — move-issue.sh's own rename is the record, and a hand edit cannot
  # spoof it the way text can).
  # <card-file> is read from the CALLER's own worktree (finish-pr.sh's $KWT, subtask.sh's
  # $KWT/progress/subtasks/<parent>/), never from <repo> directly, so stripping <repo>'s own
  # prefix would leave a worktree-local prefix (e.g. '.kanban-wt/') still attached. 'progress/'
  # is the one anchor every caller's path shares with <repo>'s own tracked tree: take from its
  # LAST occurrence onward.
  case "$src" in
    */progress/*) _forks_card_rel="progress/${src##*/progress/}" ;;
    progress/*) _forks_card_rel="$src" ;;
    *) _forks_card_rel="${src#"$repo"/}" ;;
  esac
  # <old-rev> is the TRUNK, never <new-rev> (the feature branch): move-issue.sh and subtask.sh
  # commit every board move on the trunk, inside their own kanban worktree, so a branch cut
  # before a later move (the common case: cut right after todo -> in_progress, worked, then
  # moved to dev_complete on the trunk while the branch carries only code) never has the card at
  # its later path at all — 'log --follow <branch> -- <later path>' finds nothing and this half
  # reads as UNRUNNABLE on every ordinary landing. The trunk, read fresh, already holds the move
  # that put the card at <card-file>'s own current path (that move is what made it landable).
  _forks_rename_log="$(git -C "$repo" log --follow --diff-filter=R --name-status \
    --format='COMMIT %H' "$old_rev" -- "$_forks_card_rel" 2>/dev/null || true)"
  while IFS=$'\t' read -r _frl_a _frl_b _frl_c; do
    case "$_frl_a" in
      COMMIT*) _frl_commit="${_frl_a#COMMIT }"; continue ;;
      R*) : ;;
      *) continue ;;
    esac
    case "$_frl_b" in
      progress/todo/*|*/todo/*) _forks_leave_commit="$_frl_commit"; _forks_leave_path="$_frl_c" ;;
    esac
  done <<< "$_forks_rename_log"
  # git logs newest-first: the LAST assignment above (not the first) is the earliest commit —
  # a card can only leave todo/ once in the ordinary flow, but the loop runs to completion either
  # way so the oldest wins if it ever happened twice.

  if [ -z "$_forks_leave_commit" ]; then
    echo "FORKS_AC_DRIFT_CHECK: did not run — ${issue_id}'s history shows no move out of a todo/ column (minted straight into another column)."
  else
    _forks_new_body="$(awk '/^## QA Verdict[[:space:]]*$/{exit} {print}' "$src")"
    _forks_old_body="$(git -C "$repo" show "${_forks_leave_commit}:${_forks_leave_path}" 2>/dev/null \
      | awk '/^## QA Verdict[[:space:]]*$/{exit} {print}')"
    _forks_ac_ids="$(_qav_ac_ids "$_forks_new_body")"
    while IFS= read -r _fac; do
      [ -n "$_fac" ] || continue
      _fac_old="$(_qav_ac_bullet_text "$_forks_old_body" "$_fac")"
      _fac_new="$(_qav_ac_bullet_text "$_forks_new_body" "$_fac")"
      # A bullet absent from the leave-todo revision (a new AC added after todo) is not a
      # TEXT CHANGE of an existing ruling — nothing to compare, so it is not drift.
      [ -n "$_fac_old" ] || continue
      [ "$_fac_old" = "$_fac_new" ] || _forks_ac_drift="${_forks_ac_drift}${_forks_ac_drift:+, }$_fac"
    done <<< "$(printf '%s\n' "$_forks_ac_ids")"

    if [ -n "$_forks_ac_drift" ] && [ -z "$_forks_cited" ]; then
      kit_refuse 2 forks-ac-changed-uncited \
        "Error: ${issue_id}'s AC text changed after the card left its 'todo/' column (${_forks_leave_commit:0:9}), with no '[decision: D-NN]' citation on the card: ${_forks_ac_drift}" \
        "       A ruling written straight into an AC is still a fork — cite the id that decided it." \
        "       (process/MANUAL.md § Execution discipline item 6.)" \
        "       NOTHING WAS CHANGED."
    fi
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
    # --no-renames: a path RENAMED out of a declared glob must still surface under its OLD
    # name, or a weakened test moved out of TEST_GLOBS (e.g. test/*.test.js -> src/*.test.js)
    # shows only its new, undeclared path and the touched-test population silently excludes it.
    _abl_diff_paths="$(git -C "$repo" diff --no-renames --name-only "${old_rev}...${new_rev}" 2>/dev/null || true)"
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
