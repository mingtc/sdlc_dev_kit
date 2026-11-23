# KIT-CLASS: MIXED — self-test harness, cases about the harness itself. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/harness.sh — sourced by scripts/test/run.sh, never run on its own.
# The cases whose subject is this harness: the self-reading censuses, then ship state and
# the isolation check, which CASES runs last.
# =============================================================================

# _role_literals_used <file> — every role NAME this harness writes, extracted BY
# POSITION: a --role argument, or a [Role] tag opening a commit subject or an Activity
# line. Position excludes the same tokens in diagnostic prose ABOUT roles, with no
# exemption list to maintain.
_role_literals_used() {  # <path to a harness source>
  local f="$1"
  {
    # (1) `--role <Name>` argument positions.
    grep -vE '^[[:space:]]*#' "$f" | grep -oE '\-\-role +[A-Z][A-Za-z0-9]*' | sed 's/--role *//'
    # (2) a role tag OPENING a commit-subject argument: -m "[Name] …"
    grep -vE '^[[:space:]]*#' "$f" | grep -oE -- "-q?m +[\"']\[[A-Z][A-Za-z]+\]" \
      | grep -oE '\[[A-Z][A-Za-z]+\]' | tr -d '[]'
    # (3) a role tag OPENING a seeded Activity / progress.md line.
    grep -vE '^[[:space:]]*#' "$f" | grep -oE -- "(printf|echo)[^\"']*[\"'][^\"']*\[[A-Z][A-Za-z]+\] " \
      | grep -oE '\[[A-Z][A-Za-z]+\]' | tr -d '[]'
  } | sort -u
}

# =============================================================================
# CASE — EVERY ROLE LITERAL THIS HARNESS WRITES IS ONE THE SANDBOX DECLARES
#
# case_ship_state holds the shipped commit-msg to the declared set; this is the other
# direction: every role the CASES type is a member of it. A case typing an undeclared role
# fails with "--role must be …" or a rejected commit — a fixture red that reads as a tool
# defect. Membership, not abstinence: the hand-off cases need two distinct roles.
# =============================================================================
case_role_literals_are_declared() {
  cf_reset
  make_sandbox   # for SB_TMP + teardown; this case reads the harness's own text, not the sandbox

  local self="$SB_TMP/rolepop.sh" used n t
  if ! _harness_probe_copy "$self" || [ ! -s "$self" ]; then
    skp "every role literal this harness writes is one the sandbox declares" "cannot locate this harness's own source"
    teardown; return
  fi
  _harness_population_is_whole "$self"

  used="$(_role_literals_used "$self")"
  n="$(printf '%s\n' "$used" | grep -c . || true)"
  # ASSERT THE OPERAND: zero literals found means the scan lost its subject, not that
  # the file is clean — every one of the shapes above would have to vanish at once.
  [ "$n" -ge 1 ] \
    || cf "no role literal was found in the harness's text at all — the scan lost its operand rather than finding a clean file"

  while IFS= read -r t; do
    [ -n "$t" ] || continue
    printf '%s\n' "$KIT_NEUTRAL_ROLE_PREFIXES" | tr '|' '\n' | grep -x "$t" >/dev/null \
      || cf "this harness writes the role '$t', which the sandbox's declared set does not contain (${KIT_NEUTRAL_ROLE_PREFIXES}) — the neutralized commit-msg hook and move-issue.sh whitelist would both reject it, and the case would redden about the fixture while naming a tool"
  done <<ROLE_EOF
$used
ROLE_EOF

  # ── THE REDDENING CONTROL, on a COPY — never the harness itself (instruments.md § A.2).
  local probe="$SB_TMP/roleprobe.sh"
  cp "$self" "$probe" 2>/dev/null || true
  if [ ! -f "$probe" ]; then
    _control_did_not_run "copy this harness to plant into"
  else
    # THE OUTSIDER'S NAME IS BUILT, NEVER WRITTEN: this case scans its own source, so a
    # literal outsider role written here would redden it. `%s` carries it into the probe.
    local outsider='Eng'
    printf '\n  ( cd x && ./scripts/move-issue.sh ID in_progress --role %s --note x )\n' \
      "$outsider" >> "$probe"
    _role_literals_used "$probe" | grep -x "$outsider" >/dev/null \
      || cf "(control) a planted '--role $outsider' was NOT found by the scan — it cannot see the defect it is named after"
    # ...and the membership test must reject it, or finding it buys nothing.
    printf '%s\n' "$KIT_NEUTRAL_ROLE_PREFIXES" | tr '|' '\n' | grep -x "$outsider" >/dev/null \
      && cf "(control) '$outsider' IS in the declared set, so the plant cannot demonstrate a rejection — pick a name the set does not contain"
  fi

  finish "every role literal this harness writes is a member of the set the sandbox declares — $n found by argument position ($(printf '%s' "$used" | tr '\n' ' ')), and a planted outsider is found and rejected"
  teardown
}

# =============================================================================
# CASE — EVERY CASE THAT MINTS A CARD PROBES FOR THE TEMPLATE FIRST.
#
# A case that mints a card without calling has_issue_template FAILS on a tree without
# .claude/templates/ISSUE.template.md, reporting a missing capability as a defect in the
# subject. The population is derived from the harness text — the cases that invoke a
# creation script or kit_init_sandbox — so a new minting case cannot arrive unguarded.
# =============================================================================
case_minting_cases_probe_for_the_template() {
  cf_reset
  make_sandbox
  local self="$SB_TMP/mintpop.sh" probe="$SB_TMP/mintprobe.sh"
  _harness_probe_copy "$self" \
    || _fixture_die "case_minting_cases_probe_for_the_template: could not copy the harness's own source to census."
  _harness_population_is_whole "$self"

  # Excise this case's own body: its derivation names the creation scripts it looks for.
  awk -v fn="case_minting_cases_probe_for_the_template" '
    $0 ~ "^" fn "\\(\\) \\{" { skip=1 }
    skip && /^\}$/            { skip=0; next }
    !skip
  ' "$self" > "$probe"
  grep -q '^case_minting_cases_probe_for_the_template() {' "$probe" \
    && _fixture_die "case_minting_cases_probe_for_the_template: the excision left this case's own body in the probe."

  # For each case function: does it invoke a creator, and does it probe?
  local rows n=0 bad=0 row
  rows="$(awk '
    /^case_[a-z_0-9]+\(\) \{/ { fn=$0; sub(/\(\).*/,"",fn); mint=0; probe=0; next }
    /^\}$/ {
      if (fn != "" && mint) printf "%s|%d\n", fn, probe
      fn=""; next
    }
    # WIDE ON PURPOSE: a creator reached through a glob or a basename counts, and so does
    # kit_init_sandbox, which copies the template and refuses without it. The signal is a
    # CALL, so comment lines are skipped.
    fn != "" && $0 !~ /^[[:space:]]*#/ && /new-[a-z*]*\.sh|subtask\.sh|kit_init_sandbox/ { mint=1 }
    fn != "" && /has_issue_template/                                            { probe=1 }
  ' "$probe")"

  while IFS= read -r row; do
    [ -n "$row" ] || continue
    n=$((n + 1))
    [ "${row#*|}" = "1" ] && continue
    bad=$((bad + 1))
    cf "${row%%|*} invokes a creation script and never calls has_issue_template — on a tree without .claude/templates/ISSUE.template.md it FAILS instead of skipping, reporting a missing capability as a defect in the subject"
  done <<EOF
$rows
EOF

  # ── INSTRUMENT CHECK: a negative census whose derivation finds nothing is green forever.
  [ "$n" -ge 5 ] \
    || _fixture_die "case_minting_cases_probe_for_the_template: the derivation found only $n card-minting case(s) — the creator names or the case-function shape changed, and 'all of them probe' would then be true of almost nothing."

  finish "all $n cases that invoke a creation script probe for the issue template first, so a tree without it SKIPS rather than reporting a missing capability as a defect — and the population is derived from the harness's text, so the next minting case cannot arrive unguarded"
  teardown
}

# =============================================================================
# CASE — VICTIM SELECTION SURVIVES PIPEFAIL.
#
# `find … | head -1` is the shape run.sh's PIPEFAIL RULE forbids: the value is right and the
# STATUS is the producer's SIGPIPE. probe_pick replaces it. This case proves the hazard exists
# here, asserts probe_pick's status and value, and censuses the harness and the shipped
# scripts for the piped readers the rule forbids.
# =============================================================================
case_probe_victim_selection_survives_pipefail() {
  cf_reset
  make_sandbox
  local big="$SB_TMP/pipebig" i v rc hit=0

  # ── INSTRUMENT CHECK: BUILD the hazard before asserting anything about it. If this
  #    environment cannot produce the SIGPIPE, every assertion below is vacuous, so SKIP.
  mkdir -p "$big"
  for i in $(seq 1 3000); do : > "$big/f$i.md"; done
  for i in 1 2 3; do
    if ! ( set -o pipefail; find "$big" -type f | head -1 >/dev/null ); then hit=1; break; fi
  done
  if [ "$hit" -eq 0 ]; then
    skp "probe victim selection survives pipefail" \
        "3000 files did not make 'find | head -1' fail under pipefail here — this environment cannot produce the hazard, so the assertions would be vacuous"
    teardown; return
  fi

  # THE EFFECT — the STATUS and the value. The raw pipeline gets the value right and the
  # status wrong, so asserting the value alone could not go red.
  rc=0; v="$(probe_pick "$big" -type f)" || rc=$?
  [ "$rc" -eq 0 ] \
    || cf "probe_pick exited $rc on a corpus where the raw pipeline SIGPIPEs — the status is still the producer's death, not the answer"
  [ -n "$v" ] && [ -f "$v" ] \
    || cf "probe_pick returned '$v', which is not an existing file — the replacement gets the status right and the answer wrong, which is worse than what it replaced"

  # …and it still returns NOTHING, nonzero, when there is genuinely nothing to find.
  rc=0; v="$(probe_pick "$SB_TMP/pipebig" -name 'nothing-matches-this' -type f)" || rc=$?
  [ -z "$v" ] \
    || cf "probe_pick invented a victim for a pattern that matches nothing: '$v'"

  # THE CENSUS: a new `find … | head -1` anywhere in the harness puts the hazard back.
  local self="$SB_TMP/pipepop.sh" probe="$SB_TMP/pipeprobe.sh" m1='find ' m2='| head -1'
  _harness_probe_copy "$self" \
    || _fixture_die "case_probe_victim_selection_survives_pipefail: could not copy the harness's own source to census."
  _harness_population_is_whole "$self"
  # EXCISE THIS CASE'S OWN BODY: its instrument check builds the forbidden pipeline on purpose.
  awk -v fn="case_probe_victim_selection_survives_pipefail" '
    $0 ~ "^" fn "\\(\\) \\{" { skip=1 }
    skip && /^\}$/                { skip=0; print ""; next }
    skip { print ""; next }
    { print }
  ' "$self" > "$probe"
  grep -q '^case_probe_victim_selection_survives_pipefail() {' "$probe" \
    && _fixture_die "case_probe_victim_selection_survives_pipefail: the excision left this case's own body in the probe — the census would report its own instrument check."
  local rows
  rows="$(awk -v a="$m1" -v b="$m2" '
    /^[[:space:]]*#/ { next }
    index($0,a) && index($0,b) { print NR ": " $0 }
  ' "$probe" | _harness_where)"
  [ -z "$rows" ] \
    || cf "a find/head pipeline is back, and run.sh's header forbids it by name: $(printf '%s' "$rows" | tr '\n' ' ' | cut -c1-200)"

  # ── THE SAME HAZARD, THE OTHER READER: `… | grep -q` behind a pipe. Assert the construct's
  #    ABSENCE, not its symptom: the false red appears only above the 64KB buffer, so a case
  #    waiting for it on a realistic payload stays green forever. A bare `grep -q FILE` is fine.
  #    A pipe, not `||`, which is no pipe; the instrument check holds the pattern to both forms.
  local qrows qre='(^|[^|])[|][[:space:]]*grep -q'
  printf 'a | grep -q b\n'  | awk -v re="$qre" '$0 ~ re { f=1 } END { exit !f }' \
    || _fixture_die "case_probe_victim_selection_survives_pipefail: the piped-grep pattern misses 'a | grep -q b' — the census would be green over the hazard."
  printf 'a || grep -q b\n' | awk -v re="$qre" '$0 ~ re { f=1 } END { exit !f }' \
    && _fixture_die "case_probe_victim_selection_survives_pipefail: the piped-grep pattern matches 'a || grep -q b', which is no pipe — a false red."
  qrows="$(awk -v re="$qre" '
    /^[[:space:]]*#/ { next }
    $0 ~ re { print NR ": " $0 }
  ' "$probe" | _harness_where)"
  [ -z "$qrows" ] \
    || cf "a 'grep -q' behind a pipe is back, and under pipefail it reports the PRODUCER'S death instead of the reader's answer once the producer clears the pipe buffer — drop the -q and redirect (\`| grep -F pat >/dev/null\`), which drains the input and returns the identical status: $(printf '%s' "$qrows" | tr '\n' ' ' | cut -c1-200)"

  # ── THE SHIPPED POPULATION, where the producer grows with the adopter's project. Narrower
  #    than the harness rule: a pipe validating one flag value is allowed, a producer that
  #    reads the repository, the board or the network is not. The harness files are excluded
  #    as a population, so each file is judged by exactly one of the two rules.
  local shipped_rows shipped_files
  shipped_files="$(find "$REAL_SCRIPTS" "$REAL_REPO_ROOT/consumers" -type f \
                     \( -name '*.sh' -o -name 'commit-msg' \) 2>/dev/null \
                   | grep -vxF -f <(_harness_sources) || true)"
  [ -n "$shipped_files" ] \
    || _fixture_die "case_probe_victim_selection_survives_pipefail: found no shipped scripts to census — a guard over an empty population passes forever."
  #    THE PRODUCER IS OFTEN ON THE PREVIOUS LINE (`… --porcelain \` then `| grep -qxF …` in
  #    lib/kanban-worktree.sh), so a line continuation is joined before the pattern is tested.
  shipped_rows="$(printf '%s\n' "$shipped_files" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    awk -v fn="$f" '
      /^[[:space:]]*#/ { next }
      {
        # Join ONLY across a real line-continuation: joining unconditionally leaks the
        # previous verb into this line and reddens the permitted flag validators. No
        # quotes in this comment: it lives inside a single-quoted awk program.
        joined = (prev ~ /[\\]$/) ? prev " " $0 : $0
        if (joined ~ /(git|find|ls|cat|_ship_manifest_paths)[^|]*\|[[:space:]]*grep -q/)
          print fn ":" NR ": " $0
        prev = $0
      }
    ' "$f"
  done)"
  [ -z "$shipped_rows" ] \
    || cf "a SHIPPED script pipes a growable producer into 'grep -q', which under pipefail returns the producer's SIGPIPE instead of the reader's answer once it clears the 64KB buffer — on an adopter's tree that is a refusal of a good state. Drop the -q and redirect (\`| grep -F pat >/dev/null\`): $(printf '%s' "$shipped_rows" | tr '\n' ' ' | cut -c1-300)"

  finish "probe_pick returns the first match with the RIGHT STATUS on a corpus that makes 'find | head -1' SIGPIPE under pipefail (the value was never the problem; the status was), returns nothing for a pattern that matches nothing, neither a find/head pipeline nor a piped 'grep -q' remains in this harness, and no SHIPPED script pipes a growable producer into 'grep -q'"
  teardown
}

# =============================================================================
# CASE — NO SHIPPED SCRIPT PIPES A LIST INTO A MEMBERSHIP TEST.
#
# `printf '%s\n' "$list" | grep -qx "$id"` returns the writer's SIGPIPE instead of the reader's
# answer once the list outgrows the pipe buffer and the reader leaves at its first match: under
# pipefail a present id reads as absent. The cure is `grep -qx -- "$id" <<< "$list"`, which the
# shell feeds from a file or a buffer it finishes writing first. Whether a variable can grow cannot
# be derived, so the variables that hold ONE short value (an id, a prefix, a subject line) are
# declared below; any other variable piped into a quiet grep is a finding.
# =============================================================================
_pipes_a_list_rows() {  # <declared single-value names, space-separated> <file>… — file:line: text
  local allow="$1"; shift
  awk -v allow=" $allow " '
    /^[[:space:]]*#/ { next }
    {
      rest = $0
      while (match(rest, /(printf|echo)[^|]*"\$\{?[A-Za-z_0-9]+\}?"[[:space:]]*\|[[:space:]]*grep[[:space:]]+(-[A-Za-z]+[[:space:]]+)*-[A-Za-z]*q/)) {
        s = substr(rest, RSTART, RLENGTH)
        rest = substr(rest, RSTART + RLENGTH)
        sub(/\}?"[[:space:]]*\|.*$/, "", s)
        sub(/^.*"\$\{?/, "", s)
        if (index(allow, " " s " ") == 0) { print FILENAME ":" FNR ": " $0; break }
      }
    }
  ' "$@"
}

# A FUNCTION is a producer too: `fn args | grep -qx "$id"` hands the reader the function's whole
# output, and a function can print a list that grows. <function names, space-separated> <file>…
# It reads `fn args | grep -q…` after a `;`, `&&`, `||`, `$(` or a keyword. It does NOT read
# `fn args 2>&1 | grep -q…` (the & of 2>&1 reads as a separator), `fn |& grep -q…`,
# `{ fn; } | grep -q…`, or a pipe inside `[ -n "$(fn | grep -q …)" ]`: a reviewer reads a new
# membership test for those forms.
_pipes_a_function_rows() {
  local names="$1"; shift
  awk -v names=" $names " '
    /^[[:space:]]*#/ { next }
    {
      joined = (prev ~ /[\\]$/) ? prev " " $0 : $0
      prev = $0
      if (!match(joined, /[|][[:space:]]*grep[[:space:]]+(-[A-Za-z]+[[:space:]]+)*-[A-Za-z]*q/)) next
      p = substr(joined, 1, RSTART - 1)
      sub(/^.*[;&][[:space:]]*/, "", p)
      n = split(p, seg, /[|]/)
      for (i = 1; i <= n; i++) {
        t = seg[i]
        sub(/^[[:space:]]+/, "", t)
        # Leading command-substitution openers, an assignment prefix and shell keywords are not the command.
        while (t ~ /^(\$\(|\(|[A-Za-z_][A-Za-z_0-9]*=\$\(|(if|while|until|elif|then|!)[[:space:]]+)/) {
          if (t ~ /^(if|while|until|elif|then|!)[[:space:]]+/) sub(/^[a-z!]+[[:space:]]+/, "", t)
          else sub(/^[A-Za-z_0-9]*=?\$?\(/, "", t)
          sub(/^[[:space:]]+/, "", t)
        }
        split(t, tok, /[[:space:]]+/)
        if (tok[1] != "" && index(names, " " tok[1] " ")) { print FILENAME ":" FNR ": " $0; break }
      }
    }
  ' "$@"
}

case_shipped_membership_tests_do_not_pipe_a_list() {
  cf_reset
  local single='_qct subj PREFIX PRD_PREFIX_NEW ROLES_NEW OLD_PREFIX NUM slug ch id ID subject _dc_lo _dc_hi _dc_tok _idx_next rid STORIES BEFORE KEEP_LAST 1'
  local pipe='|' sample="$(mktemp "${TMPDIR:-/tmp}/pipes-a-list.XXXXXX")" rows files total

  # INSTRUMENT: the census must flag the hazard in each spelling and pass the cure, a declared
  # single value, and a pipe it does not govern.
  {
    printf '%s\n' "if printf '%s\\n' \"\$l_live\" $pipe grep -qx \"\$cid\"; then"
    printf '%s\n' "if echo \"\$list\" $pipe grep -qE 'x'; then"
    printf '%s\n' "if printf '%s' \"\${body}\" $pipe grep -qi 'x'; then"
    printf '%s\n' "if printf '%s' \"\$NUM\" $pipe grep -qE '^[0-9]+\$'; then"
    printf '%s\n' "if grep -qx -- \"\$cid\" <<< \"\$l_live\"; then"
    printf '%s\n' "printf '%s\\n' \"\$list\" $pipe grep -c ."
    printf '%s\n' "# printf '%s\\n' \"\$list\" $pipe grep -qx \"\$cid\""
  } > "$sample"
  rows="$(_pipes_a_list_rows "$single" "$sample")"
  [ "$(printf '%s\n' "$rows" | grep -c .)" -eq 3 ] \
    || _fixture_die "case_shipped_membership_tests_do_not_pipe_a_list: the census flagged $(printf '%s\n' "$rows" | grep -c .) of the 3 hazardous spellings (printf with a newline, echo, a braced name) and none of the 4 lines it must pass — it would be green over the hazard or red over the cure. Rows: $rows"
  rm -f "$sample"

  files="$(find "$REAL_SCRIPTS" "$REAL_REPO_ROOT/consumers" -type f 2>/dev/null \
             | grep -vxF -f <(_harness_sources) || true)"
  [ -n "$files" ] \
    || _fixture_die "case_shipped_membership_tests_do_not_pipe_a_list: found no shipped scripts to census — a guard over an empty population passes forever."
  # INSTRUMENT: with nothing declared the census must find the single-value pipes the shipped
  # scripts do carry, or it is not reading them.
  # shellcheck disable=SC2086
  total="$(_pipes_a_list_rows '' $files | grep -c . || true)"
  [ "${total:-0}" -ge 1 ] \
    || _fixture_die "case_shipped_membership_tests_do_not_pipe_a_list: with no names declared the census found no piped membership test anywhere in the shipped scripts, which carry single-value ones — its pattern no longer reads them."
  # shellcheck disable=SC2086
  rows="$(_pipes_a_list_rows "$single" $files)"
  [ -z "$rows" ] \
    || cf "a shipped script pipes a variable that can hold a list into a quiet grep; once the list outgrows the pipe buffer and the reader leaves at its first match, pipefail reports the writer's death and a present item reads as absent. Read the variable through a here-string (grep -qx -- \"\$id\" <<< \"\$list\"), or declare the name single-valued in this case: $(printf '%s' "$rows" | sed "s|$REAL_REPO_ROOT/||" | tr '\n' ' ' | cut -c1-400)"

  # A FUNCTION PRODUCER: the names are derived from the shipped scripts themselves.
  local fnames
  # shellcheck disable=SC2086
  fnames="$(cat $files | sed -n 's/^[[:space:]]*\([A-Za-z_][A-Za-z0-9_]*\)() *{.*/\1/p' | sort -u | tr '\n' ' ')"
  [ -n "$fnames" ] \
    || _fixture_die "case_shipped_membership_tests_do_not_pipe_a_list: derived no function names from the shipped scripts — the function-producer census would be green over nothing."
  sample="$(mktemp "${TMPDIR:-/tmp}/pipes-a-fn.XXXXXX")"
  {
    printf '%s\n' "if ! my_ids \"\$repo\" \"\$sha\" $pipe grep -qx \"\$d\" \\"
    printf '%s\n' "   && my_ids \"\$repo\" \"\$sha\" $pipe grep -qx \"\$d\"; then"
    printf '%s\n' "if grep -qx -- \"\$d\" <<< \"\$(my_ids \"\$repo\")\"; then"
    printf '%s\n' "my_ids \"\$repo\" $pipe grep -c ."
    printf '%s\n' "printf '%s' \"\$x\" $pipe grep -qE 'y'"
    printf '%s\n' "# my_ids \"\$repo\" $pipe grep -qx \"\$d\""
    printf '%s\n' "my_ids \"\$repo\" $pipe sed s $pipe grep -qx \"\$d\""
    printf '%s\n' "foo=\$(my_ids \"\$repo\" $pipe grep -q y)"
    printf '%s\n' "if \$(my_ids $pipe grep -q y); then"
    printf '%s\n' "grep -q y <<< \"\$(my_ids \"\$repo\" $pipe sed s)\""
  } > "$sample"
  rows="$(_pipes_a_function_rows "my_ids" "$sample")"
  [ "$(printf '%s\n' "$rows" | grep -c .)" -eq 5 ] \
    || _fixture_die "case_shipped_membership_tests_do_not_pipe_a_list: the function-producer census flagged $(printf '%s\n' "$rows" | grep -c .) lines of a sample that holds 5 piped function producers (after a bang, after &&, behind a middle stage, inside an assignment substitution, inside a bare substitution) and 5 lines it must pass (a here-string, a count, a printf pipe, a comment, a here-string over a piped substitution). Rows: $rows"
  rm -f "$sample"
  # shellcheck disable=SC2086
  rows="$(_pipes_a_function_rows "$fnames" $files)"
  [ -z "$rows" ] \
    || cf "a shipped script pipes a FUNCTION's output into a quiet grep; once the function prints more than the pipe buffer holds and the reader leaves at its first match, pipefail reports the function's death and a present item reads as absent. Read it through a here-string (grep -qx -- \"\$id\" <<< \"\$(fn …)\"): $(printf '%s' "$rows" | sed "s|$REAL_REPO_ROOT/||" | tr '\n' ' ' | cut -c1-400)"

  finish "no shipped script pipes a variable or a function's output that can hold a list into a quiet grep; the census flags printf, echo and braced spellings and piped function calls, passes the here-string cure and the declared single-value variables, and reads the single-value pipes the shipped scripts do carry"
}

# =============================================================================
# CASE — EVERY LANDING PROLOGUE IS THE WHOLE FOUR-STEP.
#
# The prologues are deliberately not one helper: most use a CARD slug that differs from the
# BRANCH slug, which exercises finish-pr.sh reading the card's `branch:` field. So the copies
# stay, and this case names by line any copy that dropped a step.
# =============================================================================
case_landing_prologue_is_complete() {
  cf_reset
  make_sandbox
  local self="$SB_TMP/prologuepop.sh" probe="$SB_TMP/prologueprobe.sh"
  _harness_probe_copy "$self" \
    || _fixture_die "case_landing_prologue_is_complete: could not copy the harness's own source to census."
  _harness_population_is_whole "$self"

  # EXCISE THIS CASE'S OWN BODY: its derivation names every token it searches for.
  awk -v fn="case_landing_prologue_is_complete" '
    $0 ~ "^" fn "\\(\\) \\{" { skip=1 }
    skip && /^\}$/           { skip=0; print ""; next }
    skip { print ""; next }
    { print }
  ' "$self" > "$probe"
  # Anchored at the DEFINITION: the name also appears in the CASES registry, which the
  # excision does not (and must not) remove.
  grep -q '^case_landing_prologue_is_complete() {' "$probe" \
    && _fixture_die "case_landing_prologue_is_complete: the excision did not remove this case's own body from the probe — every finding below would be about this case's own derivation."

  # A LANDING PROLOGUE is a dev_complete card seeded right after make_sandbox in a case that
  # then invokes finish-pr.sh. The last clause matters: dev_complete cards also appear as
  # board content in cases that never land.
  local rows n
  rows="$(awk '
    { L[NR]=$0 }
    END {
      for (i=1;i<=NR;i++) {
        if (L[i] !~ /seed_issue dev_complete/) continue
        ms=0; for (j=i-1;j>=i-8 && j>=1;j--) if (L[j] ~ /make_sandbox/) { ms=j; break }
        if (!ms) continue
        fpr=0; for (j=i+1;j<=i+30 && j<=NR;j++) if (L[j] ~ /finish-pr\.sh/) { fpr=1; break }
        if (!fpr) continue
        pub=0; br=0
        for (j=i+1;j<=i+12 && j<=NR;j++) {
          if (L[j] ~ /publish_sandbox/) pub=1
          # seed_branch OR a hand-rolled branch: one case creates an EMPTY branch off the
          # trunk on purpose. The step is that the branch exists.
          if (L[j] ~ /seed_branch |git -C "\$SB_WORK" branch /) br=1
        }
        miss=""
        if (!pub) miss=miss " publish_sandbox"
        if (!br)  miss=miss " a branch"
        if (miss != "") print i "|" miss
        seen++
      }
      print "COUNT|" seen+0
    }
  ' "$probe" | _harness_where)"
  n="$(printf '%s\n' "$rows" | sed -n 's/^COUNT|//p')"

  # ── INSTRUMENT CHECK: a pattern that stopped matching reports "none incomplete" forever.
  [ "${n:-0}" -ge 8 ] \
    || _fixture_die "case_landing_prologue_is_complete: the derivation found only ${n:-0} landing prologue(s) — the shape changed, and 'none incomplete' would then be true of nothing."

  local row
  while IFS= read -r row; do
    case "$row" in COUNT\|*|'') continue ;; esac
    cf "the landing prologue at ${row%%|*} is missing:${row#*|} — a card seeded dev_complete that is never published, or has no branch, is a fixture finish-pr.sh cannot act on, and the case above it would pass for the wrong reason"
  done <<EOF
$rows
EOF

  finish "all $n landing prologues in this harness are the complete four-step (make_sandbox, seed_issue dev_complete, seed_branch, publish_sandbox) — the copies were kept on purpose, because most carry a card-slug/branch-slug divergence a collapse would erase, so this is what makes an incomplete copy visible"
  teardown
}

# =============================================================================
# CASE — EVERY ANCHORED FIXTURE APPEND HAS A DECLARED AUTHOR.
#
# Two anchor families: the array fence `NAME=(` and the function-body fence `name() {`. A
# plant is a four-step idiom — assert the anchor, plant, assert it landed, and for a sourced
# library `bash -n` — and a re-typed copy drops steps, so every anchored perl append must sit
# inside a declared author. This case scans its own file: the two match strings are held in
# separate variables and comment lines are skipped.
# =============================================================================
case_fixture_append_has_one_authoring_site() {
  cf_reset
  make_sandbox
  local m1='perl -i -pe'
  local m2='$_ .='
  local probe="$SB_TMP/appendprobe.sh"
  _harness_probe_copy "$probe" \
    || _fixture_die "case_fixture_append_has_one_authoring_site: could not copy the harness's own source to census."
  _harness_population_is_whole "$probe"

  # THE DECLARED AUTHORS. Anything else that plants is a bypass.
  local allowed=" _declare_gate _guard_declare _plant_in_function rel_insert _cb_g_fill_glob_array "

  _append_census() {  # <file> — "line|enclosing-function" for every anchored append
    awk -v a="$m1" -v b="$m2" '
      # NOT anchored at the closing brace: several definitions here carry a trailing
      # `# <args>` comment, and an anchored tracker attributes their body to whatever
      # function was defined above them — which is a WRONG author, not a missing one.
      /^[a-z_]+\(\) \{/ { fn=$0; sub(/\(\).*$/,"",fn); next }
      /^[[:space:]]*#/   { next }
      index($0,a) && index($0,b) { print NR "|" (fn == "" ? "(top level)" : fn) }
    ' "$1"
  }

  local rows n
  rows="$(_append_census "$probe" | _harness_where)"
  n="$(printf '%s\n' "$rows" | grep -c '|' || true)"

  # ── INSTRUMENT CHECK: arm 1 is a NEGATIVE census, so assert the derivation still finds
  #    the authors themselves.
  [ "$n" -ge 4 ] \
    || _fixture_die "case_fixture_append_has_one_authoring_site: the census found only $n anchored append(s) in the whole file — the expression stopped matching, and 'zero bypasses' would then be true of nothing."

  # ARM 1 — every append sits inside a declared author.
  local row ln fn
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    ln="${row%%|*}"; fn="${row#*|}"
    case "$allowed" in
      *" $fn "*) ;;
      *) cf "$ln plants through an anchored perl append inside '$fn', which is not one of the declared authors ($allowed) — a further copy of the four-step idiom, and the steps it drops are the ones that make a failed plant visible" ;;
    esac
  done <<EOF
$rows
EOF

  # ARM 2 — THE EFFECT, and arm 1 cannot see it: a spine that swallowed the per-caller
  # message would pass the census and still cost the reader the subject of the failure.
  local v="$SB_WORK/scripts/verify.sh" out rc
  # Positive leg first: on an INTACT anchor the helper succeeds. Without this, "it
  # aborts" is satisfied by a helper that aborts unconditionally.
  ( _declare_gate 'census-probe|select|/bin/echo ok' ) >/dev/null 2>&1 \
    || cf "(arm 2) _declare_gate failed on an INTACT anchor — the abort below would prove nothing"
  # Now break the anchor and require the abort to name the caller's own record.
  perl -i -pe 's/^GATES=\($/GATEZ=(/' "$v"
  rc=0; out="$( _declare_gate 'wanted-gate|select|/bin/echo x' 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] \
    || cf "(arm 2) _declare_gate returned 0 with its anchor destroyed — the plant silently did nothing and the case downstream would run against an empty gate table"
  printf '%s' "$out" | grep -F 'wanted-gate' >/dev/null \
    || cf "(arm 2) the abort does not name the record it failed to declare: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"

  finish "every anchored fixture append in this harness ($n of them) sits inside a declared author — no further copy of the four-step plant idiom — and a plant whose anchor has moved aborts naming the record it failed to declare rather than returning 0 on a file it did not change"
  teardown
}

# =============================================================================
# CASE — THE POPULATION ROW COUNTS THE CASES THE SHELL DEFINES, NOT THE RUN'S LIST.
#
# A run cut to a few cases reassigns CASES after the case-list check, and every case_* is still
# defined. A population row held to CASES reddens every census in such a run, and its message
# leads the census's own rows. Held to the cases the shell defines, it judges the text a census
# read the same in a cut run as in a full one, and a population that lost a file still reddens.
# =============================================================================
case_population_row_counts_the_defined_cases_not_the_run_list() {
  cf_reset
  make_sandbox
  local L="the population row of a census of this harness counts the case_*() definitions in the text it read against the cases the shell defines: quiet on the whole text in a run whose CASES names two cases, and red on the text without one of its files"
  local probe="$SB_TMP/popprobe.sh" part="$SB_TMP/poppart.sh" f got
  _harness_probe_copy "$probe" \
    || _fixture_die "case_population_row_counts_the_defined_cases_not_the_run_list: could not copy the harness's own source to census."

  # (cut run) CASES names two cases; the whole population is quiet.
  got="$(CASES=(case_isolation case_population_row_counts_the_defined_cases_not_the_run_list); _cf=""; _harness_population_is_whole "$probe"; printf '%s' "$_cf")"
  [ -z "$got" ] || cf "(cut run) with CASES naming two cases, the population row reddened on the whole harness text: $got"

  # (lost a file) the population without cases/harness.sh, which defines this case: red.
  : > "$part"
  while IFS= read -r f; do
    [ -n "$f" ] && [ ! "$f" -ef "$HARNESS_DIR/cases/harness.sh" ] && cat "$f" >> "$part"
  done <<POP_PART_EOF
$(_harness_sources)
POP_PART_EOF
  got="$(CASES=(case_isolation case_population_row_counts_the_defined_cases_not_the_run_list); _cf=""; _harness_population_is_whole "$part"; printf '%s' "$_cf")"
  case "$got" in *"(population)"*) ;; *) cf "(lost a file) the harness text without cases/harness.sh left the population row quiet: ${got:-no row}" ;; esac

  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE ROLE RESET TAKES ANY ADOPTED SET, INCLUDING A PREFIX OF THE SHIPPED ONE.
#
# _neu_roles runs every sandbox on an adopted tree. A narrowed set such as 'PM|Dev|QA' is a
# substring of the shipped alternation, so a substring matcher finds it again in its own
# output and aborts the run. Each set is stamped the way kit-init stamps it, then reset in a
# subshell, because a failed reset exits. Not covered: a one-member set equal to another
# quoted literal under scripts/ ('PM', kit-init.sh's pre-role hat) is rewritten with it.
# =============================================================================
case_role_reset_takes_a_narrowed_set() {
  cf_reset
  make_sandbox
  local cm="$SB_WORK/scripts/githooks/commit-msg" set seams f out rc d
  cp -R "$SB_WORK/scripts" "$SB_TMP/scripts.shipped"
  for set in 'PM|Dev|QA' 'Dev' 'QA|Dev|PM'; do
    rm -rf "$SB_WORK/scripts"; cp -R "$SB_TMP/scripts.shipped" "$SB_WORK/scripts"
    seams="$(grep -lF -- "'$KIT_NEUTRAL_ROLE_PREFIXES'" "$SB_WORK"/scripts/*.sh "$SB_WORK"/scripts/githooks/* 2>/dev/null)"
    [ -n "$seams" ] || _fixture_die "case_role_reset_takes_a_narrowed_set: no sandbox script carries the shipped role set — nothing to stamp."
    while IFS= read -r f; do
      NEU_CUR="$KIT_NEUTRAL_ROLE_PREFIXES" NEU_NEW="$set" perl -i -pe 's@\Q$ENV{NEU_CUR}\E@$ENV{NEU_NEW}@g' "$f"
    done <<<"$seams"
    grep -qxF "ROLE_PREFIXES='$set'" "$cm" \
      || _fixture_die "case_role_reset_takes_a_narrowed_set: the stamp of '$set' did not land in commit-msg."
    rc=0; out="$( _neu_roles 2>&1 )" || rc=$?
    [ "$rc" -eq 0 ] || cf "'$set': the reset aborted: $(printf '%s' "$out" | grep '_neu_roles' | cut -c1-200)"
    # Stamp then reset is the identity: a rewrite that also hit the set's text elsewhere
    # (the '[Dev]' in an echoed example) passes the reset's own checks.
    d="$(diff -r "$SB_TMP/scripts.shipped" "$SB_WORK/scripts" 2>&1)" \
      || cf "'$set': the reset did not restore the shipped scripts: $(printf '%s\n' "$d" | awk '/^[<>]/ && n++ < 2' | tr '\n' '|' | cut -c1-200)"
  done

  finish "_neu_roles resets an adopted role set to exactly the shipped scripts, including a set that is a substring of the shipped one"
  teardown
}

# =============================================================================
# CASE — SHIP STATE. The control the neutralizer costs us.
#
# Every sandbox is reset to the KIT_NEUTRAL_* values, so no other case sees the shipped
# defaults: a kit that shipped `RELEASE_PUBLISH=true` or a populated gate table would pass a
# green run. This case reads the REAL files and mutates nothing. On an adopted tree it is
# N/A, naming the signal: a filled gate table is what the adopter was told to do.
# =============================================================================
case_ship_state() {
  cf_reset
  local rv="$REAL_SCRIPTS/verify.sh" rr="$REAL_SCRIPTS/release.sh" rc_cfg="$REAL_SCRIPTS/config.sh"
  local why=""

  # Is this tree the shipped frame, or an adopted project? _tree_has_lived decides, for this
  # case and case_scaffolding_fixture_matches_the_tree alike, and returns the signal that fired.
  why="$(_tree_has_lived)"
  if [ -n "$why" ]; then
    # On an adopted tree these shipped shapes are gone because the adopter did what they
    # were told: the case has no subject. `$why` names the file that carries the signal.
    skp_lived "ship state: the kit's own config blocks still ship neutral" "$why"
    return
  fi

  # An array that is GONE reads as an array with zero records, so the fence is
  # asserted before the count. Presence first, then the property — otherwise a
  # renamed array is indistinguishable from a clean one.
  _ship_array_empty() {  # <file> <ARRAY>
    local f="$1" a="$2" n
    grep -qE "^${a}=\($" "$f" || { cf "${f##*/}: no '${a}=(' declaration — it was renamed or removed, so 'empty' here would mean nothing"; return; }
    n="$(_neu_array_records "$f" "$a")"
    [ "$n" -eq 0 ] || cf "${f##*/}: ${a} ships with ${n} declared record(s) — the frame must ship empty"
  }
  _ship_line() {  # <file> <exact line>
    grep -qxF "$2" "$1" || cf "${1##*/}: does not ship the line '$2'"
  }

  if [ -f "$rv" ]; then
    _ship_array_empty "$rv" GATES
    _ship_array_empty "$rv" GUARD_SET
    # _ship_array_empty CANNOT SEE A SCALAR, so the guard-floor enumerator needs the
    # line form. Without it the kit could ship a populated GUARD_ENUM — one project's
    # command, in every adopter's tree — and no case would look.
    _ship_line "$rv" 'GUARD_ENUM=""'
  else
    cf "scripts/verify.sh is absent — the gate frame is part of the kit"
  fi

  if [ -f "$rr" ]; then
    _ship_array_empty "$rr" VERSION_FILES
    _ship_array_empty "$rr" PREFLIGHT_GATES
    _ship_array_empty "$rr" RELEASE_DOCS
    _ship_array_empty "$rr" DIST_DOCS
    # Publishing OFF by default is the one that can do outward-facing damage if it
    # ships wrong, so it is asserted by value and not merely by presence.
    _ship_line "$rr" 'RELEASE_PUBLISH=false'
    _ship_line "$rr" 'VERSION_IN_TAG_ONLY=false'
    _ship_line "$rr" 'DIST_ARTIFACT_GLOB=""'
    _ship_line "$rr" 'SHIP_MANIFEST=""'
  fi

  local SB_REAL_KWT="$REAL_SCRIPTS/lib/kanban-worktree.sh"

  # The three seam values, in the exact shape kit-init.sh's anchored seds parse.
  # These are also the neutralizer's targets, so this is where the harness's own
  # KIT_NEUTRAL_* constants are held against the tree instead of assumed.
  if [ -f "$rc_cfg" ]; then
    _ship_line "$rc_cfg" "ISSUE_PREFIX=\"\${ISSUE_PREFIX:-${KIT_NEUTRAL_PREFIX}}\""
    _ship_line "$rc_cfg" "PRD_PREFIX=\"\${PRD_PREFIX:-${KIT_NEUTRAL_PRD_PREFIX}}\""
    _ship_line "$rc_cfg" "PROJECT_NAME=\"\${PROJECT_NAME:-${KIT_NEUTRAL_PROJECT_NAME}}\""
    # CODE_GLOBS (process/MANUAL.md § The code-vs-metadata rule, read by
    # scripts/githooks/pre-commit) must ship empty: a populated default would be ONE
    # project's source tree declared as every adopter's.
    _ship_array_empty "$rc_cfg" CODE_GLOBS
    # TEST_GLOBS (process/MANUAL.md § The Dev → QA handoff, step 6, the PASS verdict; read by
    # scripts/finish-pr.sh) — same reasoning.
    _ship_array_empty "$rc_cfg" TEST_GLOBS
  else
    cf "scripts/config.sh is absent — it is the configuration seam itself"
  fi

  # KWT_TRUNK_LAST_RESORT lives in the lib, not the seam file, and is bound by the same shape
  # rule (config-seam.md § 2).
  if [ -f "$SB_REAL_KWT" ]; then
    _ship_line "$SB_REAL_KWT" 'KWT_TRUNK_LAST_RESORT="${KWT_TRUNK_LAST_RESORT:-main}"'
  else
    cf "scripts/lib/kanban-worktree.sh is absent — it declares the trunk last resort"
  fi

  # THE ROLE SET. It has no unstamped source to check against (`kit-init --roles` rewrites
  # every copy), so a drifted KIT_NEUTRAL_ROLE_PREFIXES would silently neutralize sandboxes
  # to a set the kit no longer ships.
  local rh="$REAL_SCRIPTS/githooks/commit-msg"
  if [ -f "$rh" ]; then
    _ship_line "$rh" "ROLE_PREFIXES='${KIT_NEUTRAL_ROLE_PREFIXES}'"
  else
    cf "scripts/githooks/commit-msg is absent — it is the role set's authoring site"
  fi

  # The shipped templates carry the prefix as a PLACEHOLDER. A kit shipping a real prefix
  # there would pass a green run, because the neutralizer hands every case what it expects.
  # Guarded on presence: a tree without .claude/templates has no subject here.
  local rt="$REAL_REPO_ROOT/.claude/templates/ISSUE.template.md"
  if [ -f "$rt" ]; then
    grep -qF "$KIT_PREFIX_PLACEHOLDER" "$rt" \
      || cf ".claude/templates/ISSUE.template.md does not ship the prefix placeholder '$KIT_PREFIX_PLACEHOLDER' — the templates ship a stamped token, and every sandbox would then inherit it"
  fi

  finish "ship state: the kit ships an empty gate table and guard floor, empty release seams, RELEASE_PUBLISH=false, the neutral config.sh seam values the neutralizer resets to, the prefix PLACEHOLDER in the shipped ISSUE template, and the shipped ROLE_PREFIXES the neutralizer declares"
}

# =============================================================================
# CASE — isolation self-check: the real repo is untouched by a run.
# (Belt-and-suspenders: every case above deliberately mutates its sandbox; we
#  then assert the real repo's HEAD + board surfaces are unchanged.)
# =============================================================================
REAL_HEAD_BEFORE=""; REAL_STATUS_BEFORE=""; REAL_RECORDS_BEFORE=""
# THE SPAN IS THE WHOLE TREE, minus the harness's own directory: the harness reads far more
# of the real tree than scripts/ and progress/, and a narrower span cannot see a write to
# what it reads. scripts/test/ is excluded as the harness's own home. The comparison is a
# DELTA, so a tree already dirty at t0 is not a finding.
_board_status() {
  git -C "$REAL_REPO_ROOT" status --porcelain 2>/dev/null \
    | grep -v ' scripts/test/' || true
}
# The real project's progress records: names and bytes, from the directory the kit's own
# resolver names with no override. The directory is gitignored, so git cannot see a write there.
_real_records() {
  local d f
  d="$( cd "$REAL_REPO_ROOT" && unset KIT_PROGRESS_DIR && . "$REAL_SCRIPTS/lib/progress-record.sh" && kit_progress_dir )" || d=""
  [ -n "$d" ] || { printf '(records directory not resolved)'; return 0; }
  for f in "$d"/*; do
    [ -f "$f" ] || continue
    printf '== %s\n' "$f"; cat "$f"
  done
  return 0
}
isolation_snapshot() {
  REAL_RECORDS_BEFORE="$(_real_records)"
  REAL_HEAD_BEFORE="$(git -C "$REAL_REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "(no HEAD yet)")"
  REAL_STATUS_BEFORE="$(_board_status)"
}
# =============================================================================
# CASE — THE ISOLATION SNAPSHOT IS TAKEN, AND READ, WITH THE MACHINE'S GIT CONFIG SHUT OUT.
#   Operand: a repository with an untracked path that a global ignore file hides. Read through the
#   shutout, `git status` lists it whatever the machine's ignore files say; and run.sh shuts the config
#   out before it takes the snapshot, so the snapshot and case_isolation's read agree.
# =============================================================================
case_isolation_is_read_with_the_machines_git_config_shut_out() {
  cf_reset
  local L="the run shuts the machine's git config out before it takes the isolation snapshot, and git status read through the shutout lists a path the machine's global ignore file hides"
  local d g got a b
  d="$(mktemp -d)" || _fixture_die "${FUNCNAME[0]}: mktemp failed"
  g="$d/home/.config/git"; mkdir -p "$g" "$d/repo/sub"
  printf 'hidden-by-global/\n' > "$g/ignore"
  git -C "$d/repo" init -q 2>/dev/null; mkdir -p "$d/repo/hidden-by-global"; : > "$d/repo/hidden-by-global/x"
  got="$(HOME="$d/home" XDG_CONFIG_HOME="$d/home/.config" git -C "$d/repo" status --porcelain 2>/dev/null)"
  [ -z "$got" ] || { rm -rf "$d"; _fixture_die "${FUNCNAME[0]}: the planted global ignore does not hide the path, so the row below proves nothing"; }
  got="$( HOME="$d/home" XDG_CONFIG_HOME="$d/home/.config"; export HOME XDG_CONFIG_HOME; no_machine_git_config git -C "$d/repo" status --porcelain 2>/dev/null )"
  case "$got" in *hidden-by-global*) ;; *) cf "git status through no_machine_git_config did not list the path a global ignore hides: '$got'" ;; esac
  rm -rf "$d"
  a="$(awk '/^machine_git_config_off /{print NR; exit}' "$HARNESS_ENTRY")"
  b="$(awk '/^isolation_snapshot$/{print NR; exit}' "$HARNESS_ENTRY")"
  if [ -z "$a" ] || [ -z "$b" ]; then cf "run.sh lacks a top-level machine_git_config_off call or isolation_snapshot call (found '$a' and '$b')"
  elif [ "$a" -ge "$b" ]; then cf "run.sh calls machine_git_config_off (line $a) after isolation_snapshot (line $b)"; fi
  finish "$L"
}

# THIS CASE REPORTS WHAT IT MEASURED, NOT WHO DID IT. A path that differs between t0 and t1
# may have been written by the harness or by a concurrent session in the same checkout, and
# no snapshot can tell them apart, so the output names both (instruments.md § A.4).
case_isolation() {
  cf_reset
  local after status_after records_after
  after="$(git -C "$REAL_REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "(no HEAD yet)")"
  [ "$after" = "$REAL_HEAD_BEFORE" ] \
    || cf "the real repo's HEAD MOVED during the run ($REAL_HEAD_BEFORE → $after). This harness never commits, so the likely cause is a concurrent session landing work in this checkout; a harness that somehow committed is the other, far less likely, candidate"
  # Compare the DELTA, not absolute cleanliness: a pre-existing dirty tree (e.g.
  # uncommitted board-script edits under active development) is fine — a board
  # surface must simply not CHANGE during a run.
  status_after="$(_board_status)"
  if [ "$status_after" != "$REAL_STATUS_BEFORE" ]; then
    cf "a board surface CHANGED during the run — two candidates, and this case cannot tell them apart: (1) the harness broke its own isolation and wrote outside its sandbox, or (2) something else wrote to this checkout while the run was in flight (a concurrent session, an editor, a watcher). Before/after status follows. If a peer holds this checkout, (2) is the likely one and the run's SKIP profile is also unreliable — re-measure on a quiet tree or a built kit. BEFORE: [${REAL_STATUS_BEFORE:-clean}] AFTER: [${status_after:-clean}]"
  fi
  # .progress-records/ is gitignored, so the comparison above cannot see it.
  records_after="$(_real_records)"
  if [ "$records_after" != "$REAL_RECORDS_BEFORE" ]; then
    cf "the project's .progress-records/ CHANGED during the run — the harness writes its records to its own scratch (KIT_PROGRESS_DIR), so either a fixture's script ran with that override cleared, or something else wrote a record while the run was in flight (a seat working in this checkout). Lines before: $(printf '%s' "$REAL_RECORDS_BEFORE" | wc -l | tr -d ' ') after: $(printf '%s' "$records_after" | wc -l | tr -d ' ')"
  fi
  finish "isolation: the real repo's HEAD and its WHOLE WORKING TREE — every path git reports, not a named subset — are unchanged across the run, as is the project's .progress-records/ (names and bytes), with scripts/test/ excluded as the harness's own home. The span is the whole tree because this harness READS far more of it than any list of surfaces named in advance; a narrower span reports the absence of findings it could not have made. Attribution is out of scope: a path that differs between t0 and t1 does not say who wrote it (see the case's note)"
}

# =============================================================================
# CASE — THE HARNESS RUNS AN ADD-ON'S CASES AND REFUSES ONE THAT IS NOT LISTED.
#   An add-on ships its cases in modules/<name>/test/cases/*.sh and lists them, one function name
#   per line, in modules/<name>/test/CASE-LIST. run.sh loads those files with its own, runs the listed
#   cases before case_isolation, and refuses the whole run on a case an add-on defines and does not
#   list, lists and does not define, or names as a core case does. The proof is a REAL run of a
#   copy of run.sh over a miniature harness (one core case, case_isolation, and the add-on under
#   test): the discovery cannot be driven from inside a run that has already loaded its cases.
# =============================================================================
case_the_harness_runs_an_add_ons_cases_and_refuses_one_that_is_not_listed() {
  cf_reset
  local L="run.sh loads an add-on's case files from modules/<name>/test/cases/, runs the cases its test/CASE-LIST lists after the core cases and before case_isolation, and refuses the run (status 2, naming the add-on's CASE-LIST file) for a case it defines and does not list, one it lists and does not define, a name the core also lists, and case files with no CASE-LIST file; a tree with no add-on runs the core cases only"
  if [ ! -f "$HARNESS_ENTRY" ]; then skp "$L" "scripts/test/run.sh is not where the harness says it is"; return; fi
  # The fixture's case names are built, not written: the census of case names the shipped files cite
  # reads every case_ token in this file, and these name nothing under cases/.
  local P="case_" fx rc out ok_a="fx add-on case a ran"
  local core="${P}fx_core" pa="${P}fx_probe_a" pb="${P}fx_probe_b" pm="${P}fx_probe_missing" iso="${P}isolation"
  fx="$(mktemp -d)" || _fixture_die "${FUNCNAME[0]}: mktemp failed"
  mkdir -p "$fx/scripts/test/lib" "$fx/scripts/test/cases" "$fx/scripts/lib" "$fx/process"
  cp "$HARNESS_ENTRY" "$fx/scripts/test/run.sh"
  cp "$HARNESS_DIR"/lib/*.sh "$fx/scripts/test/lib/"
  cp "$REAL_SCRIPTS/lib/kanban-worktree.sh" "$fx/scripts/lib/"
  cp "$REAL_SCRIPTS/config.sh" "$fx/scripts/"
  : > "$fx/process/KIT-MANIFEST"
  # The miniature harness: the real runner over its real loader, with its case list replaced by one core
  # case and the isolation case, and no isolation snapshot to take.
  perl -0pi -e 'BEGIN { $c = shift; $i = shift } s/\nCASES=\(\n.*?\n\)\n/\nCASES=(\n  $c\n  $i\n)\n/s' "$core" "$iso" "$fx/scripts/test/run.sh"
  grep -qx "  $core" "$fx/scripts/test/run.sh" || _fixture_die "${FUNCNAME[0]}: the CASES block of run.sh was not replaced — its shape moved, so no run below tests the real discovery."
  # Each definition starts one space in: a definition at column 0 in this file would be counted by the
  # population census.
  {
    printf ' isolation_snapshot() { :; }\n'
    printf ' %s() { ok "fx core case ran"; }\n' "$core"
    printf ' %s() { ok "fx isolation ran"; }\n' "$iso"
  } > "$fx/scripts/test/cases/mini.sh"
  _fx_run() { rc=0; out="$( cd "$fx" && bash scripts/test/run.sh 2>&1 )" || rc=$?; out="$(printf '%s' "$out" | sed $'s/\x1b\\[[0-9;]*m//g')"; }
  _fx_addon() {  # <defined, one name per line> <CASE-LIST body, or "-" for no file>
    local n
    rm -rf "${fx:?}/modules"; mkdir -p "$fx/modules/probe/test/cases"
    : > "$fx/modules/probe/test/cases/probe.sh"
    while IFS= read -r n; do
      [ -z "$n" ] || printf '%s() { ok "fx add-on case %s ran"; }\n' "$n" "${n##*_}" >> "$fx/modules/probe/test/cases/probe.sh"
    done <<FX_DEFINED_EOF
$1
FX_DEFINED_EOF
    [ "$2" = "-" ] || printf '%s\n' "$2" > "$fx/modules/probe/test/CASE-LIST"
  }

  # (a) NO ADD-ON: the core cases run, and nothing else.
  _fx_run
  { [ "$rc" -eq 0 ] && [[ "$out" == *"fx core case ran"* ]]; } || cf "(a) (control) the miniature harness did not run clean with no add-on (exit $rc): $(printf '%s' "$out" | tail -5 | tr '\n' '|' | cut -c1-300)"

  # (b) A LISTED CASE RUNS, after the core case and before the isolation case, as its own outcome line.
  _fx_addon "$pa" "# the add-on's cases
$pa"
  _fx_run
  [ "$rc" -eq 0 ] || cf "(b) a listed add-on case made the run exit $rc: $(printf '%s' "$out" | tail -6 | tr '\n' '|' | cut -c1-300)"
  [[ "$out" == *"$ok_a"* ]] || cf "(b) the listed add-on case did not run"
  [ "$(printf '%s\n' "$out" | grep '^case-outcome:' | awk '{print $2}' | tr '\n' ' ')" = "$core $pa $iso " ] \
    || cf "(b) the outcome table is not core, add-on, then the isolation case: $(printf '%s\n' "$out" | grep '^case-outcome:' | awk '{print $2}' | tr '\n' ' ')"

  # (c) A CASE THE ADD-ON DEFINES AND DOES NOT LIST refuses the run, naming the add-on's CASE-LIST file.
  _fx_addon "$pa
$pb" "$pa"
  _fx_run
  [ "$rc" -eq 2 ] || cf "(c) an unlisted add-on case did not refuse the run with status 2 (exit $rc)"
  [[ "$out" == *"$pb"* ]] || cf "(c) the refusal does not name the unlisted case"
  [[ "$out" == *"modules/probe/test/CASE-LIST"* ]] || cf "(c) the refusal does not name the add-on's CASE-LIST file as the place to list it: $(printf '%s' "$out" | grep -i refus | head -3 | tr '\n' '|' | cut -c1-300)"
  [[ "$out" != *"$ok_a"* ]] || cf "(c) a case ran though the run was to be refused"

  # (d) A LISTED CASE THAT IS NOT DEFINED refuses it.
  _fx_addon "$pa" "$pa
$pm"
  _fx_run
  { [ "$rc" -eq 2 ] && [[ "$out" == *"$pm"* ]] && [[ "$out" == *"modules/probe/test/CASE-LIST"* ]]; } || cf "(d) a listed case with no definition did not refuse the run naming it and the CASE-LIST file (exit $rc)"

  # (e) A NAME THE CORE ALSO LISTS refuses it: one function cannot be two cases.
  _fx_addon "$core" "$core"
  _fx_run
  { [ "$rc" -eq 2 ] && [[ "$out" == *"$core"* ]]; } || cf "(e) an add-on case with a core case's name did not refuse the run (exit $rc)"

  # (f) CASE FILES WITH NO CASE-LIST FILE refuse it: nothing says which of them are cases.
  _fx_addon "$pa" "-"
  _fx_run
  { [ "$rc" -eq 2 ] && [[ "$out" == *"has no modules/probe/test/CASE-LIST"* ]]; } || cf "(f) case files with no test/CASE-LIST did not refuse the run saying the list is missing (exit $rc)"

  # (g) THE ADD-ON GOES: the run is the core's again.
  rm -rf "${fx:?}/modules"
  _fx_run
  { [ "$rc" -eq 0 ] && [[ "$out" != *"$ok_a"* ]]; } || cf "(g) with the add-on removed the run is not the core's alone (exit $rc)"

  rm -rf "${fx:?}"
  finish "$L"
}

# =============================================================================
# CASE — THE SELECTOR: NAMED CASES RUN, AND A SELECTED RUN IS PARTIAL, WITH ITS OWN EXIT STATUS.
#   `run.sh --cases <names>` and `KIT_TEST_CASES=<names>` run only the named cases, after the
#   case-list check, and print a `partial:` line; the run exits 1 when a selected case FAILs, 3 (never 0)
#   when every selected case passed, and 2 (before anything runs) for a name no case_* defines or an
#   empty list. `--list` prints the names and runs nothing. Every run prints each case's seconds.
#   The proof is a REAL run of a copy of run.sh over a miniature harness (three stand-in cases), as the
#   add-on case above does: the selector cannot be driven from inside a run that has already loaded its cases.
# =============================================================================
case_the_selector_runs_named_cases_marks_the_run_partial_and_gives_it_its_own_exit_status() {
  cf_reset
  local L="run.sh --cases / KIT_TEST_CASES run only the named cases in list order after the case-list check, print a partial: line and exit 3 when they pass and 1 when one fails; an unknown name or an empty list refuses with status 2 and a Next:, --list runs nothing, --core runs the CORE_CASES list as a partial run and refuses a stale name or a second selector, the full run is unchanged, and every run prints case-seconds: and run-seconds:"
  if [ ! -f "$HARNESS_ENTRY" ]; then skp "$L" "scripts/test/run.sh is not where the harness says it is"; return; fi
  local P="case_" fx rc out ca cb cx
  ca="${P}fx_sel_a"; cb="${P}fx_sel_b"; cx="${P}fx_sel_bad"
  fx="$(mktemp -d)" || _fixture_die "${FUNCNAME[0]}: mktemp failed"
  mkdir -p "$fx/scripts/test/lib" "$fx/scripts/test/cases" "$fx/scripts/lib" "$fx/process"
  cp "$HARNESS_ENTRY" "$fx/scripts/test/run.sh"
  cp "$HARNESS_DIR"/lib/*.sh "$fx/scripts/test/lib/"
  cp "$REAL_SCRIPTS/lib/kanban-worktree.sh" "$fx/scripts/lib/"
  cp "$REAL_SCRIPTS/config.sh" "$fx/scripts/"
  : > "$fx/process/KIT-MANIFEST"
  perl -0pi -e 'BEGIN { $a = shift; $b = shift; $x = shift } s/\nCASES=\(\n.*?\n\)\n/\nCASES=(\n  $a\n  $b\n  $x\n)\n/s' "$ca" "$cb" "$cx" "$fx/scripts/test/run.sh"
  grep -qx "  $cx" "$fx/scripts/test/run.sh" || _fixture_die "${FUNCNAME[0]}: the CASES block of run.sh was not replaced — its shape moved, so no run below tests the real selector."
  perl -0pi -e 'BEGIN { $a = shift; $x = shift } s/\nCORE_CASES=\(\n.*?\n\)\n/\nCORE_CASES=(\n  $a\n  $x\n)\n/s' "$ca" "$cx" "$fx/scripts/test/run.sh"
  grep -A2 '^CORE_CASES=(' "$fx/scripts/test/run.sh" | grep -x "  $cx" >/dev/null || _fixture_die "${FUNCNAME[0]}: the CORE_CASES block of run.sh was not replaced — its shape moved, so no run below tests --core."
  # Each definition starts one space in: a definition at column 0 in this file would be counted by the
  # population census. The third stand-in fails only when FX_BAD is set, so one list gives both exits.
  {
    printf ' isolation_snapshot() { :; }\n'
    printf ' %s() { ok "fx selector a ran"; }\n' "$ca"
    printf ' %s() { ok "fx selector b ran"; }\n' "$cb"
    printf ' %s() { if [ -n "${FX_BAD:-}" ]; then bad "fx selector bad ran" "on purpose"; else ok "fx selector bad ran"; fi; }\n' "$cx"
  } > "$fx/scripts/test/cases/mini.sh"
  _fx_run() {  # <env assignment or ""> <run.sh arguments...>
    local e="$1"; shift
    rc=0; out="$( cd "$fx" && env -u KIT_TEST_CASES ${e:+"$e"} bash scripts/test/run.sh "$@" 2>&1 )" || rc=$?
    out="$(printf '%s' "$out" | sed $'s/\x1b\\[[0-9;]*m//g')"
  }
  _fx_table() { printf '%s\n' "$out" | grep '^case-outcome:' | awk '{print $2}' | tr '\n' ' '; }
  _fx_ran() { printf '%s\n' "$out" | grep -c "^  \(PASS\|FAIL\)  fx selector"; }

  # (a) NO SELECTOR: the full run is the run it always was: every case, exit 0 when they pass, no partial: line.
  _fx_run ""
  { [ "$rc" -eq 0 ] && [ "$(_fx_table)" = "$ca $cb $cx " ]; } || cf "(a) (control) the unselected run did not run all three cases and exit 0 (exit $rc, table: $(_fx_table))"
  [[ "$out" != *"partial:"* ]] || cf "(a) an unselected run printed a partial: line"
  # ... and exit 1 when one FAILs, as before.
  _fx_run "FX_BAD=1"
  [ "$rc" -eq 1 ] || cf "(a) an unselected run with a failing case did not exit 1 (exit $rc)"
  # An empty KIT_TEST_CASES selects nothing at all: it is the full run.
  _fx_run "KIT_TEST_CASES="
  { [ "$rc" -eq 0 ] && [ "$(_fx_table)" = "$ca $cb $cx " ]; } || cf "(a) an empty KIT_TEST_CASES did not leave the run full (exit $rc, table: $(_fx_table))"

  # (b) --cases RUNS ONLY THE NAMED CASES, IN LIST ORDER, AND EXITS 3.
  _fx_run "" --cases "$cb,$ca"
  [ "$rc" -eq 3 ] || cf "(b) a passing partial run did not exit 3 (exit $rc)"
  [ "$(_fx_table)" = "$ca $cb " ] || cf "(b) --cases did not run exactly the two named cases in the list's order (table: $(_fx_table))"
  [[ "$out" == *"partial: 2 of 3 case(s) selected by --cases"*"NOT a full run"* ]] || cf "(b) no partial: line saying 2 of 3, by --cases, not a full run: $(printf '%s' "$out" | grep partial: | head -2 | tr '\n' '|')"
  [ "$(printf '%s\n' "$out" | grep -c '^partial:')" -eq 2 ] || cf "(b) the partial: line is not printed before the run and again beside the summary"
  [ "$(_fx_ran)" -eq 2 ] || cf "(b) a case that was not selected ran"
  _fx_run "" "--cases=$ca"
  { [ "$rc" -eq 3 ] && [ "$(_fx_table)" = "$ca " ]; } || cf "(b) --cases=<name> did not run just that case and exit 3 (exit $rc, table: $(_fx_table))"
  _fx_run "" --cases "$ca $cb"
  { [ "$rc" -eq 3 ] && [ "$(_fx_table)" = "$ca $cb " ]; } || cf "(b) a space-separated list was not read (exit $rc, table: $(_fx_table))"

  # (c) A SELECTED CASE THAT FAILS EXITS 1, not 3.
  _fx_run "FX_BAD=1" --cases "$cx"
  { [ "$rc" -eq 1 ] && [[ "$out" == *"partial:"* ]]; } || cf "(c) a failing selected case did not exit 1 with the partial: line (exit $rc)"

  # (d) THE ENVIRONMENT VARIABLE SELECTS TOO, AND THE FLAG BEATS IT.
  _fx_run "KIT_TEST_CASES=$ca,$cb"
  { [ "$rc" -eq 3 ] && [ "$(_fx_table)" = "$ca $cb " ] && [[ "$out" == *"selected by KIT_TEST_CASES"* ]]; } || cf "(d) KIT_TEST_CASES did not select its two cases and exit 3 (exit $rc, table: $(_fx_table))"
  _fx_run "KIT_TEST_CASES=$ca" --cases "$cb"
  { [ "$rc" -eq 3 ] && [ "$(_fx_table)" = "$cb " ]; } || cf "(d) --cases did not beat KIT_TEST_CASES (exit $rc, table: $(_fx_table))"

  # (e) AN UNKNOWN NAME REFUSES BEFORE ANYTHING RUNS, naming it and handing a Next:.
  _fx_run "" --cases "$ca,${P}fx_sel_nonesuch"
  [ "$rc" -eq 2 ] || cf "(e) an unknown case name did not refuse with status 2 (exit $rc)"
  [[ "$out" == *"${P}fx_sel_nonesuch"* ]] || cf "(e) the refusal does not name the unknown case"
  [[ "$out" == *"Next:"*"--list"* ]] || cf "(e) the refusal has no Next: pointing at --list: $(printf '%s' "$out" | tail -3 | tr '\n' '|' | cut -c1-240)"
  [ "$(_fx_ran)" -eq 0 ] || cf "(e) a case ran although the run was to be refused"

  # (f) AN EMPTY SELECTION REFUSES: it would run nothing, and a run of nothing must not read as a pass.
  _fx_run "" --cases ""
  { [ "$rc" -eq 2 ] && [[ "$out" == *"Next:"* ]] && [ "$(_fx_ran)" -eq 0 ]; } || cf "(f) an empty --cases did not refuse with status 2 and a Next: before running anything (exit $rc)"
  _fx_run "" --cases
  [ "$rc" -eq 2 ] || cf "(f) --cases with no list did not refuse with status 2 (exit $rc)"

  # (g) --list PRINTS THE NAMES AND RUNS NOTHING.
  _fx_run "" --list
  { [ "$rc" -eq 0 ] && [[ "$out" == *"$ca"* ]] && [[ "$out" == *"$cx"* ]] && [ "$(_fx_ran)" -eq 0 ]; } || cf "(g) --list did not print the case names, run nothing and exit 0 (exit $rc)"

  # (h) EVERY RUN PRINTS EACH CASE'S SECONDS AND ITS OWN: the measured list a partition is chosen from.
  _fx_run ""
  [ "$(printf '%s\n' "$out" | grep -cE "^case-seconds: ${P}fx_sel_(a|b|bad) [0-9]+$")" -eq 3 ] || cf "(h) the run did not print a case-seconds: line for each of its three cases: $(printf '%s\n' "$out" | grep -E '^(case|run)-seconds:' | tr '\n' '|')"
  printf '%s\n' "$out" | grep -E '^run-seconds: [0-9]+$' >/dev/null || cf "(h) the run did not print a run-seconds: line"

  # (i) THE OLD CONTRACT STANDS: an unknown option refuses with 2, and a usage request succeeds in any position and names the selector.
  _fx_run "" --bogus
  [ "$rc" -eq 2 ] || cf "(i) an unknown option did not refuse with status 2 (exit $rc)"
  _fx_run "" --cases "$ca" --help
  { [ "$rc" -eq 0 ] && [[ "$out" == *"--cases"* ]] && [ "$(_fx_ran)" -eq 0 ]; } || cf "(i) --help after --cases did not print usage naming --cases and exit 0 without running (exit $rc)"

  # (j) --core RUNS THE CORE_CASES LIST, AS A PARTIAL RUN BY --core, AND EXITS 3.
  _fx_run "" --core
  { [ "$rc" -eq 3 ] && [ "$(_fx_table)" = "$ca $cx " ]; } || cf "(j) --core did not run exactly the CORE_CASES cases and exit 3 (exit $rc, table: $(_fx_table))"
  [[ "$out" == *"partial: 2 of 3 case(s) selected by --core"*"NOT a full run"* ]] || cf "(j) no partial: line saying 2 of 3, by --core, not a full run: $(printf '%s' "$out" | grep partial: | head -2 | tr '\n' '|')"
  _fx_run "FX_BAD=1" --core
  [ "$rc" -eq 1 ] || cf "(j) a failing core case did not exit 1 (exit $rc)"
  _fx_run "KIT_TEST_CASES=$cb" --core
  [ "$rc" -eq 2 ] || cf "(j) --core with KIT_TEST_CASES set did not refuse (exit $rc)"

  # (k) --core WITH A SECOND SELECTOR REFUSES, and says how to run one of them.
  _fx_run "" --core --cases "$ca"
  { [ "$rc" -eq 2 ] && [[ "$out" == *"Next:"* ]] && [ "$(_fx_ran)" -eq 0 ]; } || cf "(k) --core together with --cases did not refuse with status 2 and a Next: before running anything (exit $rc)"

  # (l) A CORE_CASES NAME THAT IS NOT DEFINED REFUSES BEFORE ANYTHING RUNS: the list is a snapshot and goes stale loudly.
  cp "$fx/scripts/test/run.sh" "$fx/scripts/test/run-stale.sh"
  perl -0pi -e 'BEGIN { $n = shift } s/\nCORE_CASES=\(\n.*?\n\)\n/\nCORE_CASES=(\n  $n\n)\n/s' "${P}fx_sel_nonesuch" "$fx/scripts/test/run-stale.sh"
  rc=0; out="$( cd "$fx" && bash scripts/test/run-stale.sh --core 2>&1 )" || rc=$?
  out="$(printf '%s' "$out" | sed $'s/\x1b\\[[0-9;]*m//g')"
  { [ "$rc" -eq 2 ] && [[ "$out" == *"${P}fx_sel_nonesuch"* ]] && [[ "$out" == *"Next:"* ]] && [ "$(_fx_ran)" -eq 0 ]; } || cf "(l) a stale CORE_CASES name did not refuse with status 2, the name and a Next: before running anything (exit $rc)"

  rm -rf "${fx:?}"
  finish "$L"
}
