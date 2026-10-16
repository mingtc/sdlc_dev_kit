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
#     row has usable evidence, every row's verdict is one of KIT_QAV_VERDICTS, no row is itself
#     FAIL_AC/FAIL_REGRESSION, the table's AC ids match the card's own '- [ ] <id> —'/'- [ ] <id> -'/'- [ ] <id>:' checklist bullets one for one, and
#     the fixed 'shadow-check' row is present and filled. <rev> is the revision being landed (read
#     in <repo> with `git cat-file`/`git show`) — every evidence pointer is checked against IT, not
#     the caller's working tree. A `file:line`/`test` row's pointer must resolve (the file exists
#     at <rev> and the line, or range, is within its length) and carry a short quote the gate finds
#     at that line, whitespace-normalised; `gate-diff`/`fixture-diff` are exempt from the quote but
#     not from a `path:line` token they do carry resolving. At least one AC row must be a `test`/
#     `file:line` row, so a table of only gate-diff/fixture-diff rows (nothing the gate can re-read)
#     is refused. Refuses through kit_refuse with:
#     qa-verdict-missing, qa-verdict-evidence-missing, qa-verdict-token-invalid, qa-verdict-fail,
#     qa-verdict-ac-mismatch, qa-verdict-shadow-missing, qa-verdict-pointer-unresolved,
#     qa-verdict-quote-missing, qa-verdict-quote-not-found, qa-verdict-no-observed.
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
#     ALSO: a register entry is metadata, committed to the trunk and published BEFORE the branch is
#     cut, so the branch diff never shows it. The entries changed on <old-rev> from the commit where
#     the card left 'todo/' to the window's end are attributed by work-item id: the entry's
#     Provenance paragraph if it names one, else the subjects of the commits that changed it. An
#     entry attributed to this card must be in 'forks:' (forks-contradicted); one no id attributes
#     is forks-attribution-unclear. The window ends at the trunk tip, or — where the card already
#     sits in 'dev_complete/' (the landing) — at the commit that put it there; stdout says which.
#     A card with no 'todo/' departure makes this half UNRUNNABLE, printed on stdout.
#     Refuses through kit_refuse with: forks-missing, forks-malformed, forks-register-undeclared,
#     forks-register-unreadable, forks-unresolved, forks-contradicted, forks-attribution-unclear,
#     forks-ac-changed-uncited.
#
#   kit_ablation_check <card-file> <card-id> <repo> <old-rev> <new-rev>
#     process/doctrine/instruments.md § A.2: a diff touching a declared TEST_GLOBS path needs a
#     well-formed '## Ablation' section. TEST_GLOBS is read as the UNION of <old-rev>'s and
#     <new-rev>'s scripts/config.sh, by glob-array.sh's reader. UNDECLARED makes the check UNRUNNABLE —
#     printed on stdout as 'ABLATION_CHECK: did not run', never a silent pass; a `# DECLARED EMPTY`
#     array does too, but its line says the project chose that — same as an <old-rev>==<new-rev> (no
#     diff to read) or a <new-rev> that does not resolve, both printed as UNRUNNABLE by the same
#     line rather than treated as "touches nothing". Refuses through kit_refuse with:
#     ablation-config-unreadable, ablation-missing, ablation-malformed.
#
#   kit_board_property_check <repo> <old-rev> <new-rev> [<card-rel> <card-dest-rel>]
#     The board properties check-board.sh reports as arms [d] (frontmatter id integrity), [i]
#     (blocks:/blocked_by: symmetry), [l] (register citations resolve), [p]/[r] (CORPUS forward
#     and reverse coverage) and [q] (register entry shape), refused at the landing when THIS
#     branch introduces a finding. The checks are lib/board-properties.sh's — the same functions
#     check-board.sh runs — so the report and the refusal cannot disagree. THE RULES are read from
#     <old-rev>'s scripts/check-board.sh (the trunk), never the branch's.
#     WHICH TREE: <old-rev> with <new-rev> squash-merged into it in a scratch worktree (the tree
#     the landing produces), then <card-rel> moved to <card-dest-rel> when both are given (the
#     landing's own board move). A merge that conflicts leaves the check UNRUNNABLE, printed on
#     stdout as 'BOARD_PROPERTY_CHECK: did not run' — the squash itself refuses a conflict.
#     WHICH ARMS RUN, from `git diff --no-renames --name-only <old-rev>...<new-rev>` plus the card
#     paths: [d] and [i] when a path is a card directly in a STATUS_FOLDERS column or a declared
#     register (for [d]); [l] when a path is a citing surface outside CITATION_EXCLUDE or a
#     register (a register change reads the whole tree, otherwise only the touched files); [p]
#     and [r] when a path is under requirements/, is CORPUS_FILE, matches PRD_SURFACE or is a
#     register; [q] when a path is a register. An arm whose property is untouched does not run.
#     WHAT IS REFUSED: a finding whose key the same arm does not already report on <old-rev>. A
#     defect already on the trunk is check-board.sh's to report, so a branch is never refused for
#     a defect it did not introduce. [p] does not read the SEED-step marker (it needs the
#     graduation arm, which a landing does not run).
#     Refuses through kit_refuse with: board-property-unreadable, board-id-integrity,
#     board-blocks-asymmetric, board-citation-unresolved, board-corpus-coverage,
#     board-register-shape.
#
# Every refusal's message carries a `Next:` line (lib/refuse.sh). A caller with no branch of its
# own for the card (a subtask slice not yet its own branch) passes <old-rev>/<new-rev> such that
# they resolve to the SAME revision (e.g. the trunk twice): the forks/ablation DIFF derivation
# then legitimately finds nothing, which is not the same claim as "no fork exists" or "no test
# path touched" — state that in the caller's own words, this file does not.

# shellcheck source=board-properties.sh
. "$(dirname "${BASH_SOURCE[0]}")/board-properties.sh" || return 1   # return-class: internal
# shellcheck source=card-field.sh
. "$(dirname "${BASH_SOURCE[0]}")/card-field.sh" || return 1   # return-class: internal
# shellcheck source=glob-array.sh
. "$(dirname "${BASH_SOURCE[0]}")/glob-array.sh" || return 1   # return-class: internal

# The whole-cell placeholder forms (an EMPTY cell is checked separately, with a plain shell
# string test — a leading empty alternative in the regex itself makes some greps refuse the
# pattern outright), refused regardless of evidence kind: compared case-insensitively after
# stripping backticks and leading/trailing whitespace from the cell. ONE list — qa.md's prose, the
# templates and any future reader name this constant, not their own copy.
KIT_QAV_PLACEHOLDER_RE='^(n/a|na|none|tbd|see above|see below|-|—|x|\.\.\.|\?|<[^>]*>)$'

# The verdict tokens a QA Verdict row may carry, exactly and case-sensitively — the set process/MANUAL.md
# step 6 ratifies. A cell outside it is refused (qa-verdict-token-invalid), never read as a pass.
KIT_QAV_VERDICTS='PASS PASS_AC_CORRECTED FAIL_AC FAIL_REGRESSION'

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
  return 1   # return-class: predicate
}

# ── kit_qa_verdict_check <card-file> <card-id> <repo> <rev> ────────────────────────────────────
kit_qa_verdict_check() {
  local src="$1" issue_id="$2" repo="$3" rev="$4"
  local _qav_body _qav_ac_ids _qav_table _qav_rows
  local _qav_table_ids="" _qav_evidence_bad="" _qav_fail_rows="" _qav_shadow_seen="" _qav_shadow_bad=""
  local _qav_token_bad="" _qav_unresolved="" _qav_quote_missing="" _qav_quote_not_found="" _qav_quoted_rows=0
  local _qrow _qid _qverdict _qkind _qptr _qptr_stripped

  if [ -z "$repo" ] || [ -z "$rev" ]; then
    echo "kit_qa_verdict_check: <repo> and <rev> are required — evidence pointers are read at the revision being landed." >&2
    exit 2   # exit-class: internal
  fi

  _qav_body="$(awk '/^## QA Verdict[[:space:]]*$/{exit} {print}' "$src")"
  _qav_ac_ids="$(_qav_ac_ids "$_qav_body" || true)"

  if ! grep -qE '^## QA Verdict[[:space:]]*$' "$src"; then
    kit_refuse 2 qa-verdict-missing \
      "Error: ${issue_id} has no '## QA Verdict' table." \
      "       QA fills one row per AC id plus the fixed 'shadow-check' row before a PASS lands." \
      "       (.claude/roles/qa.md step 4.)" \
      "Next: walk the AC (.claude/roles/qa.md step 4) and add the table to the card — one row per AC id plus the shadow-check row, each carrying the evidence you observed; commit the card to the trunk with ./scripts/register-commit.sh, then re-run the command that refused." \
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
    _qverdict="$(printf '%s' "$_qverdict" | tr -d '`*')"   # the templates write the token in backticks
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
          _qav_quoted_rows=$((_qav_quoted_rows+1))
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
    case " $KIT_QAV_VERDICTS " in
      *" $_qverdict "*) : ;;
      *) _qav_token_bad="${_qav_token_bad}${_qav_token_bad:+, }${_qid} (verdict '${_qverdict}')" ;;
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
      "Next: re-walk the row(s) named above and record what you actually observed for each (a test you ran, a line you read, a diff) — a stock non-answer is not evidence; commit the card to the trunk with ./scripts/register-commit.sh, then re-run the command that refused." \
      "       NOTHING WAS CHANGED."
  fi

  if [ -n "$_qav_unresolved" ]; then
    kit_refuse 2 qa-verdict-pointer-unresolved \
      "Error: ${issue_id}'s QA Verdict table has row(s) whose evidence pointer does not resolve in the tree being landed: ${_qav_unresolved}" \
      "       A file:line/path:a-b token must name a file that exists at the revision being" \
      "       landed, at a line (or range) within its length. (.claude/roles/qa.md step 4.)" \
      "Next: re-read the code each row cites and give the pointer that is actually there at the revision being landed — a pointer edited to resolve without re-reading is not a fix. If the file is missing from the branch, that is a defect on the branch: send the card back to Dev. Otherwise commit the card to the trunk with ./scripts/register-commit.sh, then re-run the command that refused." \
      "       NOTHING WAS CHANGED."
  fi

  if [ -n "$_qav_quote_missing" ]; then
    kit_refuse 2 qa-verdict-quote-missing \
      "Error: ${issue_id}'s QA Verdict table has test/file:line row(s) with no quoted evidence: ${_qav_quote_missing}" \
      "       A test or file:line row's evidence pointer carries a short verbatim quote in double" \
      "       quotes after the pointer, e.g. 'src/add.js:12 \"return a + b\"'. (.claude/roles/qa.md step 4.)" \
      "Next: add the short verbatim quote you read at each cited line, after its pointer; commit the card to the trunk with ./scripts/register-commit.sh, then re-run the command that refused." \
      "       NOTHING WAS CHANGED."
  fi

  if [ -n "$_qav_quote_not_found" ]; then
    kit_refuse 2 qa-verdict-quote-not-found \
      "Error: ${issue_id}'s QA Verdict table has row(s) whose quote is not on the cited line: ${_qav_quote_not_found}" \
      "       The quote (surrounding whitespace normalised) must be a substring of the cited" \
      "       path:line/path:a-b's own lines at the revision being landed. (.claude/roles/qa.md step 4.)" \
      "Next: re-read the cited line at the revision being landed and quote what it says, or cite where the code now is. If the code no longer shows what the AC needs, the row is a FAIL (.claude/roles/qa.md step 6), not a re-quote. Otherwise commit the card to the trunk with ./scripts/register-commit.sh, then re-run the command that refused." \
      "       NOTHING WAS CHANGED."
  fi

  if [ -n "$_qav_table_ids" ] && [ "$_qav_quoted_rows" -eq 0 ]; then
    kit_refuse 2 qa-verdict-no-observed \
      "Error: ${issue_id}'s QA Verdict table has no test/file:line row — every AC row is gate-diff or fixture-diff." \
      "       Those kinds carry no quote, so the gate has no line to re-read. Give at least one AC row a" \
      "       test or file:line pointer with a verbatim quote, e.g. 'src/add.js:12 \"return a + b\"'." \
      "       (.claude/roles/qa.md step 4.)" \
      "Next: for at least one AC row, read the line that shows the behaviour and cite it as a test or file:line pointer with the verbatim quote; commit the card to the trunk with ./scripts/register-commit.sh, then re-run the command that refused." \
      "       NOTHING WAS CHANGED."
  fi

  if [ -n "$_qav_token_bad" ]; then
    kit_refuse 2 qa-verdict-token-invalid \
      "Error: ${issue_id}'s QA Verdict table has row(s) whose verdict is not one of the four tokens: ${_qav_token_bad}" \
      "       A row's verdict is exactly one of ${KIT_QAV_VERDICTS// / | }," \
      "       spelled so (case-sensitive) and nothing else. (.claude/roles/qa.md step 6.)" \
      "Next: set each row named above to the token its own evidence shows (a failing row is FAIL_AC or FAIL_REGRESSION, and then this is not a PASS landing — .claude/roles/qa.md step 6); commit the card to the trunk with ./scripts/register-commit.sh, then re-run the command that refused." \
      "       NOTHING WAS CHANGED."
  fi

  if [ -n "$_qav_fail_rows" ]; then
    kit_refuse 2 qa-verdict-fail \
      "Error: ${issue_id}'s QA Verdict table has FAIL row(s) on a PASS landing: ${_qav_fail_rows}" \
      "       A row whose own verdict is FAIL_AC or FAIL_REGRESSION cannot ship under an overall PASS." \
      "       (.claude/roles/qa.md step 4, step 6.)" \
      "Next: this is not a PASS landing. Record the card's verdict as FAIL_AC or FAIL_REGRESSION and send it back to Dev (.claude/roles/qa.md step 6); do not change a row's verdict to make it land." \
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
      "Next: walk each missing AC and add its row, remove each extra row; commit the card to the trunk with ./scripts/register-commit.sh, then re-run the command that refused." \
      "       NOTHING WAS CHANGED."
  fi

  if [ -z "$_qav_shadow_seen" ] || [ -n "$_qav_shadow_bad" ]; then
    kit_refuse 2 qa-verdict-shadow-missing \
      "Error: ${issue_id}'s QA Verdict table has no filled 'shadow-check' row." \
      "       State 'assertions removed: none', or each removed/weakened assertion with its replacement." \
      "       (.claude/roles/qa.md step 4.)" \
      "Next: read the diff for removed or weakened assertions, fill the shadow-check row with what you found; commit the card to the trunk with ./scripts/register-commit.sh, then re-run the command that refused." \
      "       NOTHING WAS CHANGED."
  fi
}

# ── _forks_window_entries <repo> <card-id> <register-path> <heading-mark> <lo-commit> <hi-rev> ─
#   The attribution half of kit_forks_check: which register entries changed on the trunk between
#   <lo-commit> (where the card left 'todo/') and <hi-rev> belong to THIS card. One line per
#   entry changed in the window, tab-separated:
#     MINE <TAB> <id>
#     UNATTRIBUTED <TAB> <id> <TAB> <sha> <TAB> <subject of the last commit that changed it>
#   An entry whose Provenance paragraph (read from <hi-rev>) names a work-item id is attributed by
#   that alone; otherwise by the subjects of the window commits that changed it; an entry neither
#   attributes is UNATTRIBUTED, never silently skipped. Work-item ids are '<PREFIX>-N' or a slice's
#   '<PREFIX>-N-sM', the prefix taken from the card's own id, and match EXACTLY: a slice id is not
#   its parent. An entry attributed only to other cards prints nothing.
_forks_window_entries() {
  local repo="$1" issue_id="$2" path="$3" mark="$4" lo="$5" hi="$6"
  local pre tokre touched hicopy ctable="" c cids d prov toks prov_toks last_c last_s sha_c cd
  pre="${issue_id%%-[0-9]*}"
  [ "$pre" != "$issue_id" ] || return 0
  git -C "$repo" rev-parse -q --verify "${lo}^" >/dev/null 2>&1 || return 0
  tokre="\\b${pre}-[0-9]+(-s[0-9]+)?\\b"
  touched="$(kit_decisions_touched_by_diff "$repo" "${lo}^" "$hi" "$path" "$mark")"
  [ -n "$touched" ] || return 0
  hicopy="$(git -C "$repo" show "${hi}:${path}" 2>/dev/null || true)"
  for c in $(git -C "$repo" log --no-renames --reverse --format=%H "${lo}^..${hi}" -- "$path" 2>/dev/null || true); do
    cids="$(kit_decisions_touched_by_diff "$repo" "${c}^" "$c" "$path" "$mark")"
    for d in $cids; do ctable="${ctable}${c} ${d}"$'\n'; done
  done
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    prov="$(printf '%s\n' "$hicopy" | awk -v m="$mark" -v d="$d" '
      index($0,m)==1 { id=substr($0,length(m)+1); sub(/[[:space:]].*$/,"",id); if (f) exit; f=(id==d); next }
      f && /^## / { exit }
      f && !p && /^\*\*Provenance\.\*\*/ { p=1; print; next }
      f && p { if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^\*\*[^*]+\*\*/) exit; print }')"
    toks="$(printf '%s' "$prov" | grep -oE "$tokre" || true)"; prov_toks="$toks"
    last_c=""; last_s=""
    while read -r sha_c cd; do
      [ "$cd" = "$d" ] || continue
      last_c="$sha_c"; last_s="$(git -C "$repo" log -1 --format=%s "$sha_c" 2>/dev/null || true)"
      [ -n "$prov_toks" ] || toks="${toks}"$'\n'"$(printf '%s' "$last_s" | grep -oE "$tokre" || true)"
    done <<< "$ctable"
    toks="$(printf '%s\n' "$toks" | grep . | sort -u || true)"
    if [ -z "$toks" ]; then
      [ -n "$last_c" ] || { last_c="$hi"; last_s="$(git -C "$repo" log -1 --format=%s "$hi" 2>/dev/null || true)"; }
      printf 'UNATTRIBUTED\t%s\t%s\t%s\n' "$d" "$last_c" "$last_s"
    elif printf '%s\n' "$toks" | grep -qx "$issue_id"; then
      printf 'MINE\t%s\n' "$d"
    fi
  done <<< "$touched"
  return 0
}

# ── kit_forks_check <card-file> <card-id> <repo> <old-rev> <new-rev> <check-board-path> ────────
kit_forks_check() {
  local src="$1" issue_id="$2" repo="$3" old_rev="$4" new_rev="$5" check_board="$6"
  local _forks_line _forks_ids="" _forks_inner _forks_n_tokens _forks_n_ids
  local _forks_declared _forks_regs _forks_cited
  local _forks_live_all="" _forks_seen_all=""
  local _freg_path _freg_mark _freg_shape _forks_branch_reg
  local _forks_bad="" _fid _forks_derived _forks_missing_ids=""
  local _forks_del_log _fdl_line _forks_leave_commit="" _forks_leave_path=""
  local _frl_commit=""
  local _forks_new_body _forks_old_body _forks_ac_ids _forks_ac_drift="" _fac _fac_old _fac_new
  local _forks_win_end="" _forks_win_bound="" _fwe_line _fwe_commit="" _fwe_state="" _forks_win_log
  local _forks_win_mine="" _forks_win_unattr="" _fwk _fwi _fws _fwp _fwj _forks_win_out _forks_unattr_msg=""
  local _forks_unattr_first="" _forks_unattr_reg=""

  _forks_line="$(kit_card_field "$src" forks)"
  if [ -z "$_forks_line" ]; then
    kit_refuse 2 forks-missing \
      "Error: ${issue_id} has no 'forks:' field." \
      "       State the fork ids this card resolved ('forks: [D-NN, ...]') or 'forks: none' if it resolved none." \
      "       (process/MANUAL.md § Execution discipline item 6; requirements/DECISIONS.md § Which decisions live HERE.)" \
      "Next: add the 'forks:' field to the card — the D-NN ids of the register entries this card added or changed, or 'none' only if it resolved no fork — and commit the card, then re-run the command that refused." \
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
          "Next: rewrite the field as 'forks: none' or 'forks: [D-NN, ...]' and commit the card, then re-run the command that refused." \
          "       NOTHING WAS CHANGED."
      fi
      ;;
    *)
      kit_refuse 2 forks-malformed \
        "Error: ${issue_id}'s 'forks:' field is not 'none' or a list of D-NN ids: forks: ${_forks_line}" \
        "       (process/MANUAL.md § Execution discipline item 6; requirements/DECISIONS.md § Which decisions live HERE.)" \
        "Next: rewrite the field as 'forks: none' or 'forks: [D-NN, ...]' and commit the card, then re-run the command that refused." \
        "       NOTHING WAS CHANGED."
      ;;
  esac

  _forks_declared="$(kit_registers_declared "$check_board")" || _forks_declared=""
  if [ -z "$_forks_declared" ]; then
    kit_refuse 1 forks-register-undeclared \
      "Error: could not read a 'REGISTERS=' declaration from ${check_board#"$repo"/}." \
      "       The 'forks:' check derives its register set from check-board.sh's own declaration" \
      "       (the same one arm [l] resolves citations against) and never guesses a path." \
      "Next: restore the REGISTERS= declaration in scripts/check-board.sh from version control or the release zip; do not hard-code a register path anywhere else. If the file was not yours to change, stop and hand off." \
      "       NOTHING WAS CHANGED."
  fi
  _forks_regs="$(printf '%s\n' "$_forks_declared" | awk -F'|' '$3 == "D-[0-9]+" { print }')"
  # THE ONE READER: kit_decisions_cited (lib/decision-register.sh) — case-insensitive label,
  # spacing-tolerant, list- and range-aware — the same reader arm (l) and arm (r) read a citation
  # through. A second regex here would let one caller read a citation another cannot see. Called unconditionally, like kit_decision_register_live below:
  # both are sourced by every caller before this file, same as this file's own functions are.
  _forks_cited="$(kit_decisions_cited "$src" 'D-[0-9]+' | sort -u || true)"

  # The leave-todo commit starts two reads: the register window below and the AC-drift half after it.
  # The card's identity is its ID, never its content: card templates are mostly boilerplate, so a
  # similarity-following history read (log --follow) can report a new card as a copy of an
  # earlier, similar one and continue down THAT card's history. So the leave-todo commit is read
  # by the id-anchored path: the earliest <old-rev> commit that deleted a 'todo/<id>-*' file,
  # read with --no-renames (a move out of todo/ is then a plain delete there); the card's text
  # as it stood in todo/ is that commit's parent's copy.
  # <old-rev> is the TRUNK, never <new-rev> (the feature branch): move-issue.sh and subtask.sh
  # commit every board move on the trunk, inside their own kanban worktree, so a branch cut
  # before a later move (the common case: cut right after todo -> in_progress, worked, then
  # moved to dev_complete on the trunk while the branch carries only code) never has the card at
  # its later path at all. The trunk, read fresh, already holds the move that put the card at
  # <card-file>'s own current path (that move is what made it landable).
  _forks_del_log="$(git -C "$repo" log --no-renames --diff-filter=D --name-only \
    --format='COMMIT %H' "$old_rev" -- ":(glob)**/todo/${issue_id}-*" 2>/dev/null || true)"
  while IFS= read -r _fdl_line; do
    case "$_fdl_line" in
      COMMIT*) _frl_commit="${_fdl_line#COMMIT }"; continue ;;
      */todo/"${issue_id}"-*) _forks_leave_commit="$_frl_commit"; _forks_leave_path="$_fdl_line" ;;
    esac
  done <<< "$_forks_del_log"
  # git logs newest-first: the LAST assignment above (not the first) is the earliest commit —
  # a card can only leave todo/ once in the ordinary flow, but the loop runs to completion either
  # way so the oldest wins if it ever happened twice.

  # THE REGISTER WINDOW'S END. A register entry is metadata, so it is committed to the trunk and
  # published BEFORE the branch is cut: it is in <old-rev> already, and the branch diff above shows
  # nothing. The window is therefore the trunk's own register changes from the leave-todo commit to
  # here. Where the card already sits in dev_complete/ (the landing), the window ends at the commit
  # that put it there, so an entry another card adds while this one waits for QA stays out; at the
  # hand-off, or after a bounce back out of dev_complete/, it ends at the trunk tip.
  _forks_win_end="$old_rev"; _forks_win_bound="the trunk tip"
  _forks_win_log="$(git -C "$repo" log --no-renames --diff-filter=AD --name-status \
    --format='COMMIT %H' "$old_rev" -- ":(glob)**/dev_complete/${issue_id}-*" 2>/dev/null || true)"
  while IFS= read -r _fwe_line; do
    case "$_fwe_line" in
      COMMIT*) _fwe_commit="${_fwe_line#COMMIT }" ;;
      A[[:space:]]*|D[[:space:]]*) _fwe_state="${_fwe_line%%[[:space:]]*}"; break ;;
    esac
  done <<< "$_forks_win_log"
  if [ "$_fwe_state" = A ] && [ -n "$_fwe_commit" ]; then
    _forks_win_end="$_fwe_commit"; _forks_win_bound="the commit that moved the card to dev_complete/"
  fi

  while IFS='|' read -r _freg_path _freg_mark _freg_shape; do
    [ -n "$_freg_path" ] || continue

    _forks_branch_reg="$(mktemp "${TMPDIR:-/tmp}/finish-pr-forks-reg.XXXXXX" 2>/dev/null || true)"
    if [ -z "$_forks_branch_reg" ]; then
      kit_refuse 1 forks-register-unreadable \
        "Error: could not create a scratch file to read ${new_rev}'s copy of ${_freg_path} — refusing rather than skipping the 'forks:' check." \
        "Next: free disk space or make \$TMPDIR writable, then re-run the command that refused; if it still refuses, stop and hand off." \
        "       NOTHING WAS CHANGED."
    fi
    git -C "$repo" show "${new_rev}:${_freg_path}" > "$_forks_branch_reg" 2>/dev/null || : > "$_forks_branch_reg"

    _forks_live_all="$_forks_live_all
$(kit_decision_register_live "$_forks_branch_reg" "$_freg_mark" 'D-[0-9]+')"
    _forks_seen_all="$_forks_seen_all
$(kit_decisions_touched_by_diff "$repo" "$old_rev" "$new_rev" "$_freg_path" "$_freg_mark")"

    rm -f "$_forks_branch_reg"
    if [ -n "$_forks_leave_commit" ]; then
      _forks_win_out="$(_forks_window_entries "$repo" "$issue_id" "$_freg_path" "$_freg_mark" "$_forks_leave_commit" "$_forks_win_end")"
      while IFS=$'\t' read -r _fwk _fwi _fws _fwj; do
        case "$_fwk" in
          MINE) _forks_win_mine="${_forks_win_mine}${_fwi}"$'\n' ;;
          UNATTRIBUTED) _forks_win_unattr="${_forks_win_unattr}${_fwi}"$'\t'"${_fws}"$'\t'"${_freg_path}"$'\t'"${_fwj}"$'\n' ;;
        esac
      done <<< "$_forks_win_out"
    fi
  done <<< "$(printf '%s\n' "$_forks_regs")"
  _forks_live_all="$(printf '%s\n' "$_forks_live_all" | grep -E '^D-[0-9]+$' | sort -u || true)"
  _forks_seen_all="$(printf '%s\n' "$_forks_seen_all" | grep -E '^D-[0-9]+$' | sort -u || true)"
  _forks_win_mine="$(printf '%s\n' "$_forks_win_mine" | grep -E '^D-[0-9]+$' | sort -u || true)"
  if [ -z "$_forks_leave_commit" ]; then
    echo "FORKS_ATTRIBUTION_CHECK: did not run — ${issue_id}'s history shows no move out of a todo/ column (minted straight into another column), so the register window has no start."
  else
    echo "FORKS_ATTRIBUTION_CHECK: ran over ${_forks_leave_commit:0:9}..$(git -C "$repo" rev-parse --short=9 "$_forks_win_end" 2>/dev/null || echo "$_forks_win_end") (the window ends at ${_forks_win_bound}); register entries attributed to ${issue_id}: $(printf '%s' "$_forks_win_mine" | tr '\n' ' ' | sed -E 's/ +$//; s/^$/none/')."
  fi

  if [ -n "$_forks_ids" ]; then
    while IFS= read -r _fid; do
      [ -n "$_fid" ] || continue
      printf '%s\n' "$_forks_live_all" | grep -qx "$_fid" || _forks_bad="${_forks_bad}${_forks_bad:+, }$_fid"
    done <<< "$(printf '%s\n' "$_forks_ids")"
    if [ -n "$_forks_bad" ]; then
      _forks_prd="$(kit_declared_value "$check_board" PRD_SURFACE || true)"
      _forks_xc="$(kit_declared_value "$check_board" CROSS_CUTTING_MARKER || true)"
      kit_refuse 2 forks-unresolved \
        "Error: ${issue_id}'s 'forks:' names an id that is not a live entry in any declared D- register: ${_forks_bad}" \
        "       A NEW entry must also be cited by a PRD under ${_forks_prd:-the declared PRD surface} or marked ${_forks_xc//\\/}, or the landing's board-corpus-coverage check refuses it." \
        "Next: fix the id on the card, or add the ruling it names to the register in this same change. If that ruling is not yours to make, ask for it (./scripts/ask.sh --role <role> \"<question>\" --default \"<working default>\") and land under the recorded default." \
        "       NOTHING WAS CHANGED."
    fi
  fi

  _forks_derived="$(printf '%s\n%s\n%s\n' "$_forks_seen_all" "$_forks_cited" "$_forks_win_mine" | grep -E '^D-[0-9]+$' | sort -u || true)"
  while IFS= read -r _fid; do
    [ -n "$_fid" ] || continue
    printf '%s\n' "$_forks_ids" | grep -qx "$_fid" || _forks_missing_ids="${_forks_missing_ids}${_forks_missing_ids:+, }$_fid"
  done <<< "$(printf '%s\n' "$_forks_derived")"
  if [ -n "$_forks_missing_ids" ]; then
    kit_refuse 2 forks-contradicted \
      "Error: ${issue_id}'s branch ('${new_rev}') shows a fork 'forks:' does not name: ${_forks_missing_ids}" \
      "       (a register entry the branch's diff adds or changes, a '[decision: D-NN]' citation anywhere on the card, or an entry changed on the trunk since the card left 'todo/' whose Provenance or commit subject names ${issue_id})." \
      "       'forks: ${_forks_line}' does not account for them." \
      "Next: add the id(s) to 'forks:' on the card and commit it, then re-run the command that refused." \
      "       NOTHING WAS CHANGED."
  fi

  # An entry changed in the window that no work-item id attributes cannot be told from this card's
  # own, and a silent pass is how a fork reaches QA unnamed. 'forks:' naming it is one way out;
  # naming the owning card in its Provenance is the other.
  while IFS=$'\t' read -r _fwi _fws _fwp _fwj; do
    [ -n "$_fwi" ] || continue
    printf '%s\n' "$_forks_ids" | grep -qx "$_fwi" && continue
    _forks_unattr_msg="${_forks_unattr_msg}${_forks_unattr_msg:+; }${_fwi} (${_fws:0:9} \"${_fwj}\")"
    _forks_unattr_first="${_forks_unattr_first:-$_fwi}"; _forks_unattr_reg="${_forks_unattr_reg:-$_fwp}"
  done <<< "$_forks_win_unattr"
  if [ -n "$_forks_unattr_msg" ]; then
    kit_refuse 2 forks-attribution-unclear \
      "Error: ${issue_id}: a register entry changed on the trunk since this card left 'todo/', and neither its Provenance nor the subject of a commit that changed it names a work item: ${_forks_unattr_msg}" \
      "       'forks: ${_forks_line}' cannot say whether this card resolved it." \
      "Next: if ${issue_id} resolved it, add the id to 'forks:' on the card and commit it; if another card did, name that card's id in the entry's Provenance paragraph (./scripts/register-commit.sh --role <role> --message \"attribute ${_forks_unattr_first} to <card id>\" ${_forks_unattr_reg}). Then re-run the command that refused." \
      "       NOTHING WAS CHANGED."
  fi

  # A ruling written straight into an AC's own text never touches the register and never adds a
  # '[decision: D-NN]' citation, so the derivation above cannot see it — the only trace is the AC
  # TEXT itself changing after the card was already underway. "Underway" is read from the card's
  # own file history: the commit where a rename moved it OUT of a 'todo/' column (never by
  # parsing a commit subject — move-issue.sh's own rename is the record, and a hand edit cannot
  # spoof it the way text can).

  if [ -z "$_forks_leave_commit" ]; then
    echo "FORKS_AC_DRIFT_CHECK: did not run — ${issue_id}'s history shows no move out of a todo/ column (minted straight into another column)."
  else
    _forks_new_body="$(awk '/^## QA Verdict[[:space:]]*$/{exit} {print}' "$src")"
    _forks_old_body="$(git -C "$repo" show "${_forks_leave_commit}^:${_forks_leave_path}" 2>/dev/null \
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
        "Next: cite the register id that decided the change as '[decision: D-NN]' on the card. If no entry decided it, record the ruling in the register first (or ask for it: ./scripts/ask.sh --role <role> \"<question>\" --default \"<working default>\"), or restore the AC's earlier text." \
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
      "Next: free disk space or make \$TMPDIR writable, then re-run the command that refused; if it still refuses, stop and hand off." \
      "       NOTHING WAS CHANGED."
  fi
  { git -C "$repo" show "${old_rev}:scripts/config.sh" 2>/dev/null || :
    git -C "$repo" show "${new_rev}:scripts/config.sh" 2>/dev/null || :; } > "$_abl_cfg_branch"

  local _abl_declared_empty=""
  while IFS= read -r _abl_line; do
    case "$_abl_line" in
      E\|*) _abl_test_globs+=("${_abl_line#E|}") ;;
      D)    _abl_declared_empty=1 ;;
    esac
  done < <(kit_glob_array TEST_GLOBS "$_abl_cfg_branch")
  rm -f "$_abl_cfg_branch"

  if [ ${#_abl_test_globs[@]} -eq 0 ] && [ -n "$_abl_declared_empty" ]; then
    echo "ABLATION_CHECK: did not run — TEST_GLOBS is declared empty in scripts/config.sh (a project's own \"none, on purpose\"): the ablation rule stays unenforced."
  elif [ ${#_abl_test_globs[@]} -eq 0 ]; then
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
          "Next: break the behaviour the changed test covers, run the test and see it go red, restore it, then add the '## Ablation' section to the card with 'Broken:' and 'Red line:' from that run; commit the card and re-run the command that refused." \
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
          "Next: fill both lines from an ablation you actually ran (what you broke, the red output it produced), commit the card, then re-run the command that refused." \
          "       NOTHING WAS CHANGED."
      fi
      echo "ABLATION_CHECK: PASS — '## Ablation' present and well formed for a diff touching a declared test path."
    else
      echo "ABLATION_CHECK: PASS — the branch diff touches no declared test path."
    fi
  fi
}

# ── kit_board_property_check <repo> <old-rev> <new-rev> [<card-rel> <card-dest-rel>] ───────────
# _bpc_run_arm <hits-file> <only-list> <function> <tree> [<arg>] — one arm, in a subshell with
# `set -e` off (the arms are written for a caller without it), its findings appended to <hits-file>.
_bpc_run_arm() {
  local out="$1" only="$2"
  shift 2
  : > "$out"
  ( set +e; KIT_BP_HITS_FILE="$out"; KIT_BP_ONLY="$only"; "$@" >/dev/null 2>&1 ) || true
}

# _bpc_new_findings <base-hits> <new-hits> — the text of each finding in <new-hits> that carries a
# key <base-hits> does not.
_bpc_new_findings() {
  awk -F'\t' -v US="$KIT_BP_US" -v bf="$1" '
    FILENAME == bf { n = split($1, k, US); for (i = 1; i <= n; i++) base[k[i]] = 1; next }
    { n = split($1, k, US); for (i = 1; i <= n; i++) if (!(k[i] in base)) { print $2; break } }
  ' "$1" "$2"
}

kit_board_property_check() {
  local repo="$1" old_rev="$2" new_rev="$3" card_rel="${4:-}" card_dest="${5:-}"
  local scratch tree decl missing touched p col rest ex rpath rmark rshape reg_hit ex_hit
  local g_d=0 g_l=0 g_p=0 g_q=0 only="" reg_touched=0 cite_touched=0
  local old_sha new_sha arm base new first_rule="" msg=() ran="" skipped="" kept=0 n
  local -a cols

  scratch="$(mktemp -d "${TMPDIR:-/tmp}/board-props.XXXXXX" 2>/dev/null || true)"
  if [ -z "$scratch" ]; then
    kit_refuse 1 board-property-unreadable \
      "Error: could not create a scratch directory for the board-property check — refusing rather than skipping it." \
      "Next: free disk space or make \$TMPDIR writable, then re-run the command that refused; if it still refuses, stop and hand off." \
      "       NOTHING WAS CHANGED."
  fi
  tree="$scratch/tree"
  _bpc_cleanup() {
    git -C "$repo" worktree remove --force "$tree" >/dev/null 2>&1 || true
    rm -rf "$scratch" 2>/dev/null || true
    git -C "$repo" worktree prune >/dev/null 2>&1 || true
  }

  # THE RULES, from the trunk's own copy of check-board.sh.
  decl="$scratch/check-board.sh"
  if ! git -C "$repo" show "${old_rev}:scripts/check-board.sh" > "$decl" 2>/dev/null; then
    _bpc_cleanup
    kit_refuse 1 board-property-unreadable \
      "Error: could not read ${old_rev}:scripts/check-board.sh — the board-property check takes its operands from the trunk's own declarations and never guesses them." \
      "Next: fetch the trunk (git fetch <remote>) and confirm ${old_rev} resolves and holds scripts/check-board.sh; then re-run the command that refused. If the file is not on the trunk, stop and hand off." \
      "       NOTHING WAS CHANGED."
  fi
  if ! kit_bp_load_declarations "$decl"; then
    missing="$KIT_BP_MISSING"
    _bpc_cleanup
    kit_refuse 1 board-property-unreadable \
      "Error: ${old_rev}:scripts/check-board.sh does not declare: ${missing}" \
      "       The board-property check reads those operands from that file and never guesses them." \
      "Next: restore each missing declaration in the trunk's scripts/check-board.sh (version control or the release zip hold the original) and land that on the trunk, then re-run the command that refused. If that file was not yours to change, stop and hand off." \
      "       NOTHING WAS CHANGED."
  fi

  old_sha="$(git -C "$repo" rev-parse --verify --quiet "${old_rev}^{commit}" 2>/dev/null || true)"
  new_sha="$(git -C "$repo" rev-parse --verify --quiet "${new_rev}^{commit}" 2>/dev/null || true)"
  if [ -z "$old_sha" ] || [ -z "$new_sha" ]; then
    _bpc_cleanup
    echo "BOARD_PROPERTY_CHECK: did not run — ${old_rev} or ${new_rev} does not resolve to a commit, so there is no diff to read."
    return 0
  fi

  # WHICH PROPERTIES THE BRANCH TOUCHES.
  touched="$(git -C "$repo" diff --no-renames --name-only "${old_rev}...${new_rev}" 2>/dev/null || true)"
  [ -z "$card_rel" ] || touched="${touched}"$'\n'"${card_rel}"
  [ -z "$card_dest" ] || touched="${touched}"$'\n'"${card_dest}"
  IFS='|' read -r -a cols <<< "$STATUS_FOLDERS"
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    for col in "${cols[@]}"; do
      case "$p" in
        progress/"$col"/*.md) rest="${p#progress/"$col"/}"; case "$rest" in */*) ;; *) g_d=1 ;; esac ;;
      esac
    done
    reg_hit=0
    while IFS='|' read -r rpath rmark rshape; do
      [ -n "$rpath" ] || continue
      if [ "$p" = "$rpath" ]; then reg_hit=1; fi
    done <<< "$(printf '%s\n' "$REGISTERS")"
    if [ "$reg_hit" -eq 1 ]; then g_d=1; g_q=1; g_p=1; reg_touched=1; fi
    case "$p" in requirements/*|"$CORPUS_FILE") g_p=1 ;; esac
    # shellcheck disable=SC2254  # PRD_SURFACE is a declared glob, matched as one
    case "$p" in $PRD_SURFACE) g_p=1 ;; esac
    ex_hit=0
    while IFS= read -r ex; do
      [ -n "$ex" ] || continue
      case "$p" in "$ex"*) ex_hit=1 ;; esac
    done <<< "$(printf '%s\n' "$CITATION_EXCLUDE")"
    if [ "$ex_hit" -eq 0 ]; then cite_touched=1; only="${only}${p}"$'\n'; fi
  done <<< "$touched"
  [ "$cite_touched" -eq 0 ] || g_l=1
  [ "$reg_touched" -eq 0 ] || { g_l=1; only=""; }

  # THE TREE THE LANDING PRODUCES, and the trunk's own tree beside it as the baseline.
  if ! git -C "$repo" -c core.hooksPath=/dev/null worktree add --detach --quiet "$tree" "$old_sha" >/dev/null 2>&1; then
    _bpc_cleanup
    echo "BOARD_PROPERTY_CHECK: did not run — a scratch worktree of ${old_rev} could not be made."
    return 0
  fi
  for arm in d i l p r q; do
    case "$arm" in
      d|i) [ "$g_d" -eq 1 ] || continue ;;
      l)   [ "$g_l" -eq 1 ] || continue ;;
      p|r) [ "$g_p" -eq 1 ] || continue ;;
      q)   [ "$g_q" -eq 1 ] || continue ;;
    esac
    case "$arm" in
      d) _bpc_run_arm "$scratch/base.d" "" kit_bp_ids "$tree" ;;
      i) _bpc_run_arm "$scratch/base.i" "" kit_bp_blocks "$tree" ;;
      l) _bpc_run_arm "$scratch/base.l" "$only" kit_bp_citations "$tree" ;;
      p) _bpc_run_arm "$scratch/base.p" "" kit_bp_corpus "$tree" "" ;;
      r) _bpc_run_arm "$scratch/base.r" "" kit_bp_reverse_coverage "$tree" ;;
      q) _bpc_run_arm "$scratch/base.q" "" kit_bp_register_shape "$tree" ;;
    esac
  done
  if [ "$old_sha" != "$new_sha" ] && ! git -C "$tree" merge --squash "$new_sha" >/dev/null 2>&1; then
    _bpc_cleanup
    echo "BOARD_PROPERTY_CHECK: did not run — ${new_rev} does not merge cleanly into ${old_rev}, so there is no landed tree to read (the squash below refuses a conflict)."
    return 0
  fi
  if [ -n "$card_rel" ] && [ -n "$card_dest" ] && [ -f "$tree/$card_rel" ]; then
    if mkdir -p "$(dirname "$tree/$card_dest")"; then mv "$tree/$card_rel" "$tree/$card_dest" || true; fi
  fi

  for arm in d i l p r q; do
    case "$arm" in
      d|i) [ "$g_d" -eq 1 ] || { skipped="${skipped}${skipped:+ }$arm"; continue; } ;;
      l)   [ "$g_l" -eq 1 ] || { skipped="${skipped}${skipped:+ }$arm"; continue; } ;;
      p|r) [ "$g_p" -eq 1 ] || { skipped="${skipped}${skipped:+ }$arm"; continue; } ;;
      q)   [ "$g_q" -eq 1 ] || { skipped="${skipped}${skipped:+ }$arm"; continue; } ;;
    esac
    ran="${ran}${ran:+ }$arm"
    case "$arm" in
      d) _bpc_run_arm "$scratch/new.d" "" kit_bp_ids "$tree" ;;
      i) _bpc_run_arm "$scratch/new.i" "" kit_bp_blocks "$tree" ;;
      l) _bpc_run_arm "$scratch/new.l" "$only" kit_bp_citations "$tree" ;;
      p) _bpc_run_arm "$scratch/new.p" "" kit_bp_corpus "$tree" "" ;;
      r) _bpc_run_arm "$scratch/new.r" "" kit_bp_reverse_coverage "$tree" ;;
      q) _bpc_run_arm "$scratch/new.q" "" kit_bp_register_shape "$tree" ;;
    esac
    base="$scratch/base.$arm"; new="$scratch/new.$arm"
    n="$(_bpc_new_findings "$base" "$new")"
    if [ -n "$n" ]; then
      local rule label
      case "$arm" in
        d) rule=board-id-integrity;          label="frontmatter id integrity (check-board.sh [d])" ;;
        i) rule=board-blocks-asymmetric;     label="blocks:/blocked_by: symmetry (check-board.sh [i])" ;;
        l) rule=board-citation-unresolved;   label="register citations resolving (check-board.sh [l])" ;;
        p) rule=board-corpus-coverage;       label="CORPUS forward references (check-board.sh [p])" ;;
        r) rule=board-corpus-coverage;       label="reverse coverage of register entries by their PRD (check-board.sh [r])" ;;
        q) rule=board-register-shape;        label="register entry shape (check-board.sh [q])" ;;
      esac
      [ -n "$first_rule" ] || first_rule="$rule"
      msg+=("       ${label}:")
      while IFS= read -r p; do
        if [ -n "$p" ]; then msg+=("  $p"); fi
      done <<< "$n"
    fi
    kept=$((kept + $(wc -l < "$base" | tr -d ' ')))
  done
  _bpc_cleanup

  if [ -n "$first_rule" ]; then
    kit_refuse 2 "$first_rule" \
      "Error: landing '${new_rev}' onto ${old_rev} introduces a board-property finding that ${old_rev} does not have." \
      "${msg[@]}" \
      "       check-board.sh reports the same property; only a finding this landing introduces is refused," \
      "       and one already on ${old_rev} is not." \
      "Next: correct each finding above in the branch's change (the card, register or PRD it names), commit and push, then re-run the command that refused. A finding that is a ruling nobody has made is not yours to invent: ask for it (./scripts/ask.sh --role <role> \"<question>\" --default \"<working default>\") and land under the recorded default." \
      "       NOTHING WAS CHANGED."
  fi
  echo "BOARD_PROPERTY_CHECK: PASS — ran: ${ran:-none}; property untouched, not run: ${skipped:-none}; finding(s) already on ${old_rev} and not refused: ${kept}."
  return 0
}
