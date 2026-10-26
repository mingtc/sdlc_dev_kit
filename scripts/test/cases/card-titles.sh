# KIT-CLASS: MIXED — self-test harness, card-title cases. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/card-titles.sh — sourced by scripts/test/run.sh, never run on its own.
# A card's `title:` is free text that may hold `: `; the templates quote it, the one reader strips
# one pair of quotes, subtask.sh writes it quoted, and check-board's [u] reports an unquoted
# title that is not valid plain YAML. Plus the four wording duties that ride with them.
# =============================================================================

_ct_u_section() {  # reads a check-board report on stdin
  awk '/^\[u\]/ { f = 1 }
       f && /^──/ { exit }
       f && /^\[[a-z]\]/ && !/^\[u\]/ { exit }
       f'
}

# CASE — the five card templates ship a QUOTED title placeholder, and the reader returns the bare text.
# The expected values are typed here, never derived from the card read.
case_card_title_templates_quote_and_the_reader_strips() {
  cf_reset
  local t f got lib="$REAL_REPO_ROOT/scripts/lib/card-field.sh" d row want
  for t in ISSUE BUG REFACTOR SUBTASK PRD; do
    f="$REAL_REPO_ROOT/.claude/templates/$t.template.md"
    [ -f "$f" ] || { cf "(precondition) no $t.template.md in this tree"; continue; }
    grep -E '^title: "<[^>]+>"$' "$f" >/dev/null || cf "$t.template.md: the title: line is not a quoted <placeholder>"
  done
  d="$(mktemp -d)"
  # row: <title line> | <wanted --raw value>
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    want="${row#*@@}"; printf -- '---\nid: X-1\n%s\n---\nbody\n' "${row%%@@*}" > "$d/c.md"
    got="$( . "$lib"; kit_card_field "$d/c.md" title --raw )"
    [ "$got" = "$want" ] || cf "reader: '${row%%@@*}' returned '$got', want '$want'"
  done <<'ROWS'
title: "Today list: sort"@@Today list: sort
title: Plain@@Plain
title: "a \"b\""@@a "b"
title: "keeps # hash"@@keeps # hash
title: He said "hi"@@He said "hi"
title: "unterminated@@"unterminated
title: "<one-line summary>"@@<one-line summary>
ROWS
  rm -rf "$d"
  finish "card templates quote title:, and kit_card_field --raw strips one pair of outer double quotes (and \\\") and leaves an unquoted title unchanged"
}

# CASE — archive.sh prints a quoted-title card's bare title, with no quote marks.
case_archive_index_row_carries_the_bare_title() {
  cf_reset
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-270" colon chore '"Today list: sort by due date"'
  publish_sandbox
  local out
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --dry-run 2>&1 )"
  printf '%s\n' "$out" | grep -F "$SB_PREFIX-270 [chore] Today list: sort by due date" >/dev/null \
    || cf "the index row does not carry the bare title: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -F '"Today list' >/dev/null && cf "the index row carries the title's quote marks"
  finish "archive.sh --dry-run prints a quoted title without its quote marks"
  teardown
}

# CASE — check-board's [u] lists an unquoted title that is not valid plain YAML, and only reports.
case_check_board_unquoted_title_arm() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-871" colon chore "Today list: sort"
  seed_issue todo "$SB_PREFIX-872" quoted chore '"Today list: sort"'
  seed_issue blocked "$SB_PREFIX-873" hash chore "Fix the thing #12"
  seed_issue in_progress "$SB_PREFIX-874" bracket chore "[WIP] thing"
  seed_issue todo "$SB_PREFIX-875" plain chore "Plain title with a colon-free tail"
  seed_issue todo "$SB_PREFIX-876" fine chore "Plain title"
  publish_sandbox
  local out sec base
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _ct_u_section)"
  [ -n "$sec" ] || cf "no [u] section in the report — the arm is absent"
  printf '%s\n' "$out" | grep '^\[u\]' | grep -i 'reports only' >/dev/null || cf "[u]'s header does not carry the 'reports only' token"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$SB_PREFIX-871-colon.md" >/dev/null || cf "the colon title is not listed: $sec"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$SB_PREFIX-873-hash.md" >/dev/null || cf "the ' #' title is not listed: $sec"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$SB_PREFIX-874-bracket.md" >/dev/null || cf "the leading-indicator title is not listed: $sec"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$SB_PREFIX-872-quoted.md" >/dev/null && cf "the quoted title is listed: $sec"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$SB_PREFIX-876-fine.md" >/dev/null && cf "a plain title is listed: $sec"
  printf '%s\n' "$sec" | grep -F 'quote it' >/dev/null || cf "the finding does not say to quote it: $sec"
  base="$(printf '%s\n' "$out" | grep '^── board-drift')"
  # Quote the three: the arm goes silent and the verdict is the same either way.
  local f
  for f in 871-colon 873-hash 874-bracket; do
    sed -i.bak 's/^title: \(.*\)$/title: "\1"/' "$SB_WORK/progress/"*/"$SB_PREFIX-$f.md"; rm -f "$SB_WORK"/progress/*/*.bak
  done
  publish_sandbox
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _ct_u_section)"
  printf '%s\n' "$sec" | grep '⚠' >/dev/null && cf "quoted titles still listed: $sec"
  printf '%s\n' "$sec" | grep -F '✓ none' >/dev/null || cf "a clean [u] does not say '✓ none': $sec"
  [ "$(printf '%s\n' "$out" | grep '^── board-drift')" = "$base" ] || cf "[u] moved the verdict: '$base' vs '$(printf '%s\n' "$out" | grep '^── board-drift')'"
  # A landing must not read this arm: the shared property library never mentions a title.
  grep -i 'title' "$REAL_REPO_ROOT/scripts/lib/board-properties.sh" >/dev/null && cf "lib/board-properties.sh reads a title — the landing could refuse on it"
  finish "arm [u] lists an unquoted title holding ': ', ' #' or a leading YAML indicator, ignores a quoted or plain one, never moves the verdict, and sits outside the landing's property library"
  teardown
}

# CASE — subtask.sh new writes a title holding ': ', a quote and a backslash as a YAML-valid line.
case_subtask_new_quotes_a_colon_title() {
  cf_reset
  if ! has_issue_template; then skp "subtask.sh new quotes a colon title" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  make_sandbox
  mkdir -p "$SB_WORK/.claude/templates"
  cp -R "$REAL_REPO_ROOT/.claude/templates/." "$SB_WORK/.claude/templates/"
  seed_issue todo "$SB_PREFIX-880" parent feature "Parent"
  publish_sandbox
  local out rc=0 card want='Floor: say "hi" \ done'
  out="$( cd "$SB_WORK" && ./scripts/subtask.sh new "$SB_PREFIX-880" s1 floor --title "$want" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || { cf "subtask.sh new exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"; finish "subtask title quoting"; teardown; return; }
  card="$(ls "$SB_WORK"/progress/subtasks/"$SB_PREFIX-880"/todo/*-s1-*.md 2>/dev/null | head -1)"
  [ -f "$card" ] || cf "no slice card was written"
  grep -F -x 'title: "Floor: say \"hi\" \\ done"' "$card" >/dev/null || cf "the title: line is not the quoted, escaped form: $(grep '^title:' "$card")"
  [ "$( . "$REAL_REPO_ROOT/scripts/lib/card-field.sh"; kit_card_field "$card" title --raw )" = "$want" ] \
    || cf "kit_card_field does not read the title back as typed"
  finish "subtask.sh new writes a colon-bearing title double-quoted with \\ and \" escaped, and the reader returns it as typed"
  teardown
}

# CASE — the four wording duties exist where their readers look.
case_day_one_and_role_wordings_for_titles_and_homes() {
  cf_reset
  local r="$REAL_REPO_ROOT"
  # PROJECT.md's blank is the adopter's to fill: judged only while the shipped blank is still there.
  if grep -F 'Read vs write separation' "$r/PROJECT.md" | grep -F '<which credential' >/dev/null; then
    grep -F 'Read vs write separation' "$r/PROJECT.md" | grep -F 'requirements/DECISIONS.md' >/dev/null \
      || cf "PROJECT.md's read/write-separation blank does not name requirements/DECISIONS.md"
  fi
  grep -E '^\| \*\*6\*\*' "$r/process/SEED.md" | grep -E 'verbatim' | grep -F 'dev/README.md' >/dev/null \
    || cf "SEED step 6 does not say to save the brief verbatim and index it in dev/README.md"
  grep -F 'dated status snapshot' "$r/.claude/roles/qa.md" >/dev/null || cf "qa.md has no status-snapshot sentence"
  grep -F "rewrites that AC" "$r/.claude/roles/pm.md" | grep -F 'todo/' | grep -F 'new story' >/dev/null \
    || cf "pm.md's Out-of-scope sentence does not scope itself to todo/ and name a new story for delivered work"
  finish "PROJECT.md names the register home, SEED step 6 saves the brief, qa.md separates a snapshot from a promise, pm.md says an Out-of-scope line rewrites an AC in todo/"
}
