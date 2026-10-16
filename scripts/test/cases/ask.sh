# KIT-CLASS: MIXED — self-test harness, ask.sh and the unattended launch profile cases. See
# process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/ask.sh — sourced by scripts/test/run.sh, never run on its own.
# scripts/ask.sh, driven against a sandbox carrying a SYNTHETIC minimal PROJECT.md (never a copy
# of the real one — see _ask_pm_section) and requirements/DECISIONS.md, plus the two
# .claude/settings*.json.example files read from the real tree (make_sandbox does not copy
# .claude/ — see fixtures.sh).
# =============================================================================

# _ask_pm_section <principal-backtick-span> <channel-backtick-span> — the exact two-line shape
# lib/pm-field.sh's kit_pm_field reads (the KIT-CLASS marker line first, so a tree that DROPS it at
# graduation — SEED's own rule — is not what these cases are testing), NEVER a copy of a real
# PROJECT.md: $REAL_REPO_ROOT/PROJECT.md is unfilled only before day one, and a tree that
# finished day one (the card this family exists for) has already filled it with THAT project's
# own principal — a plant anchored on the unfilled `<who answers…>` shape then silently no-ops
# over a real answer. Synthesizing the section is state-independent of whichever tree this
# harness runs in.
_ask_pm_section() {
  printf '<!-- KIT-CLASS: KIT -->\n# PROJECT.md\n\n## Who answers when nobody is watching\n\n- **`principal:`** `%s`\n- **Their channel:** `%s`\n' "$1" "$2"
}

# _ask_fill_pm <dir> — a synthetic PROJECT.md with `principal:` and its channel FILLED.
_ask_fill_pm() {
  local dir="$1"
  _ask_pm_section 'Nadia, shop manager' 'dev/questions/' > "$dir/PROJECT.md"
}

# _ask_pm_section_bare <principal-bare-text> <channel-backtick-span> — the SAME two-line shape,
# but `principal:` filled WITHOUT backticks — a natural fill (`PM`, `nobody`) the way a person
# reads the shipped prompt, not the first-backtick-span-only shape _ask_pm_section tests.
_ask_pm_section_bare() {
  printf '<!-- KIT-CLASS: KIT -->\n# PROJECT.md\n\n## Who answers when nobody is watching\n\n- **`principal:`** %s\n- **Their channel:** `%s`\n' "$1" "$2"
}

# _ask_unfilled_pm <dir> — a synthetic PROJECT.md with `principal:` and its channel left as the
# shipped blank shape (`<angle-bracket>`, whole span) — the precondition
# case_ask_refuses_with_no_principal (b) needs, independent of whether the REAL PROJECT.md in
# this tree has already been filled.
_ask_unfilled_pm() {
  local dir="$1"
  _ask_pm_section '<who answers when no PM/human session is watching>' '<the directory or file this project'"'"'s questions go to>' > "$dir/PROJECT.md"
}

# =============================================================================
# CASE — ask.sh --help ANSWERS FIRST, IN ANY POSITION.
# =============================================================================
case_ask_help_answers_first() {
  cf_reset
  make_sandbox
  local a="$SB_WORK/scripts/ask.sh"
  [ -x "$a" ] || _fixture_die "case_ask_help_answers_first: scripts/ask.sh is not in the sandbox or not executable"

  local out rc
  out="$( cd "$SB_WORK" && ./scripts/ask.sh --help </dev/null 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) --help exited $rc, want 0: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  case "$out" in *ask.sh*) : ;; *) cf "(a) --help output does not name ask.sh" ;; esac

  out="$( cd "$SB_WORK" && ./scripts/ask.sh --bogus --help </dev/null 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) --help after an unknown option exited $rc, want 0 — help must answer BEFORE any argument is interpreted"

  out="$( cd "$SB_WORK" && ./scripts/ask.sh --role Dev --help </dev/null 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(c) --help after --role exited $rc, want 0"

  finish "ask.sh --help exits 0 and names the tool, in any position, before any other argument is interpreted"
  teardown
}

# =============================================================================
# CASE — ask.sh REFUSES WHEN THE PRINCIPAL IS UNDECLARED, WITH A COUNTABLE RECORD.
# RED FIRST: this case fails on any ask.sh that does not check PROJECT.md's blanks.
# =============================================================================
case_ask_refuses_with_no_principal() {
  cf_reset
  make_sandbox
  local a="$SB_WORK/scripts/ask.sh"
  [ -x "$a" ] || { cf "scripts/ask.sh is not in the sandbox"; finish "ask.sh refuses when principal: is blank/undeclared, with a refusal= record"; teardown; return; }

  # (a) NO PROJECT.md AT ALL.
  local out rc
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-a" ./scripts/ask.sh --role Dev "q?" --default "d" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) with no PROJECT.md at all, exited 0 — a question was asked with nowhere declared to send it"
  case "$out" in
    *rincipal*|*PROJECT.md*) : ;;
    *) cf "(a) the refusal does not name PROJECT.md or the principal: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;;
  esac
  [ -n "$(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null)" ] \
    || cf "(a) no progress record was written for the refusal"
  grep -q 'refusal=' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
    || cf "(a) the refusal's record carries no refusal= extra: $(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null)"

  # (b) AN UNFILLED PROJECT.md — the blank is still `<angle-bracket>`. Synthesized
  # (_ask_unfilled_pm), never copied from $REAL_REPO_ROOT/PROJECT.md: on a tree that finished
  # day one that file's principal: is already filled with THIS project's own answer, and this
  # case's premise (unfilled) would silently not hold.
  _ask_unfilled_pm "$SB_WORK"
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-b" ./scripts/ask.sh --role Dev "q?" --default "d" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) with PROJECT.md's principal: unfilled, exited 0"
  [ -z "$(find "$SB_WORK/dev" -type f -name '*-ask.md' 2>/dev/null)" ] \
    || cf "(b) a question file was written despite the principal being unfilled"
  grep -q 'refusal=' "$SB_TMP/rec-b"/*.tsv 2>/dev/null \
    || cf "(b) the refusal's record carries no refusal= extra"

  finish "ask.sh refuses when principal: is blank/undeclared, with a refusal= record, and writes no question file"
  teardown
}

# =============================================================================
# CASE — A `principal:` FILLED WITHOUT BACKTICKS READS AS FILLED, AND ask.sh/[g] AGREE.
# RED FIRST: the unfixed scripts take only the first backtick span after the marker, so a bare
# fill (`PM`) reads as unfilled — [g] withholds graduation and ask.sh refuses.
# Four rows, each through BOTH readers: backticked (passes today too), bare (red today), bare
# `nobody` (read as the literal text, same as a backticked `nobody` already is), and the shipped
# blank (still refused/unfilled in either form). One assertion per row checks the two readers
# AGREE, not just that each individually passes.
# =============================================================================
case_ask_principal_field_reads_either_form() {
  cf_reset
  make_sandbox
  local a="$SB_WORK/scripts/ask.sh"
  [ -x "$a" ] || { cf "scripts/ask.sh is not in the sandbox"; finish "a principal: filled without backticks reads as filled, and ask.sh/[g] agree on every row"; teardown; return; }

  # A LIVED signal, or [g] reports "THIS CHECK DID NOT RUN" and never reaches the principal:
  # row at all (same receipt case_check_board_graduation's (b) sub-case seeds).
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"

  # Make every OTHER graduation member discharged, so [g]'s principal: row is the only signal
  # that varies across the four rows below (same recipe case_check_board_graduation's (d) sub-case uses).
  printf '# my project\n' > "$SB_WORK/AGENTS.md"
  printf '# my project\n' > "$SB_WORK/README.md"
  _cb_g_fill_glob_array CODE_GLOBS '  "src/*"'
  _cb_g_fill_glob_array TEST_GLOBS '  # DECLARED EMPTY -- fixture has no test tree.'
  _cb_g_discharge_delete_if_unused
  _cb_g_discharge_gitignore_env

  # _pm_row <principal-field, as it appears after the marker, backticks included if any>
  #   Writes PROJECT.md with that EXACT text after `` `principal:` `` (never through
  #   _ask_pm_section/_ask_pm_section_bare, which each commit to one shape) and drives BOTH
  #   readers against it, asserting they agree.
  _pm_row() {
    local label="$1" field="$2" want_filled="$3"   # want_filled: 1 = both read it as filled, 0 = both refuse/unfilled
    printf '<!-- KIT-CLASS: KIT -->\n# PROJECT.md\n\n## Who answers when nobody is watching\n\n- **`principal:`** %s\n- **Their channel:** `dev/questions/`\n' \
      "$field" > "$SB_WORK/PROJECT.md"
    publish_sandbox

    local ask_rc g_out g_filled
    ( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-$label" ./scripts/ask.sh --role Dev "q?" --default "d" >/dev/null 2>&1 ); ask_rc=$?
    g_out="$(cb_run)"
    if printf '%s\n' "$g_out" | _cb_g_section | grep 'PROJECT.md principal:.*declared' >/dev/null; then g_filled=1; else g_filled=0; fi

    if [ "$want_filled" -eq 1 ]; then
      [ "$ask_rc" -eq 0 ] || cf "($label) ask.sh refused on field '$field': $ask_rc"
      [ "$g_filled" -eq 1 ] || cf "($label) [g] read field '$field' as unfilled: $(printf '%s\n' "$g_out" | _cb_g_section | grep principal)"
    else
      [ "$ask_rc" -ne 0 ] || cf "($label) ask.sh accepted field '$field', want refusal"
      [ "$g_filled" -eq 0 ] || cf "($label) [g] read field '$field' as filled, want unfilled"
    fi
    # THE AGREEMENT ASSERTION: whatever either reader decided, it must be the SAME decision —
    # a divergence here is the two-copies-of-one-parser defect even where neither individually
    # matches want_filled above.
    local ask_filled=$([ "$ask_rc" -eq 0 ] && echo 1 || echo 0)
    [ "$ask_filled" = "$g_filled" ] \
      || cf "($label) ask.sh and [g] DISAGREE on field '$field': ask.sh filled=$ask_filled, [g] filled=$g_filled"
  }

  _pm_row backticked '`PM`' 1
  _pm_row bare 'PM' 1
  _pm_row bare-nobody 'nobody' 1
  _pm_row shipped-blank '`<who answers when no PM/human session is watching — a name or role, not a script, or "nobody">`' 0

  # The reader's value itself, which neither caller's verdict shows: emphasis around a bare fill
  # is stripped, and a bare path keeps its own underscores (ask.sh writes to that path).
  . "$SB_WORK/scripts/lib/pm-field.sh"
  local v
  printf -- '- **`principal:`** **PM**\n- **Their channel:** dev/my_questions/\n' > "$SB_TMP/pmf.md"
  v="$(kit_pm_field '`principal:`' "$SB_TMP/pmf.md")"
  [ "$v" = PM ] || cf "kit_pm_field read a bold bare principal as '$v', want 'PM'"
  v="$(kit_pm_field '\\*\\*Their channel:\\*\\*' "$SB_TMP/pmf.md")"
  [ "$v" = dev/my_questions/ ] || cf "kit_pm_field read a bare channel path as '$v', want 'dev/my_questions/'"

  finish "a principal: filled without backticks reads as filled, and ask.sh/[g] agree on every row"
  teardown
}

# =============================================================================
# CASE — A PLACEHOLDER LEFT IN `principal:` READS AS BLANK, THROUGH BOTH READERS.
# RED FIRST: the unfixed readers accept any non-empty, non-`<angle-bracket>` text, so each
# planted form below reads as DECLARED today — [g] reports "declared ✓" and ask.sh proceeds to
# write a question file — even though none carries a real answer. One row per form, through both
# callers; a whitespace-only backtick fill is the shape that motivated this case.
# =============================================================================
case_ask_principal_placeholder_forms_read_as_blank() {
  cf_reset
  make_sandbox
  local a="$SB_WORK/scripts/ask.sh"
  [ -x "$a" ] || { cf "scripts/ask.sh is not in the sandbox"; finish "a placeholder left in principal: reads as blank through both ask.sh and [g]"; teardown; return; }

  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  printf '# my project\n' > "$SB_WORK/AGENTS.md"
  printf '# my project\n' > "$SB_WORK/README.md"
  _cb_g_fill_glob_array CODE_GLOBS '  "src/*"'
  _cb_g_fill_glob_array TEST_GLOBS '  # DECLARED EMPTY -- fixture has no test tree.'
  _cb_g_discharge_delete_if_unused
  _cb_g_discharge_gitignore_env

  # _blank_row <label> <principal-field, exactly as it appears after the marker> — both readers
  # must treat it as UNFILLED: ask.sh refuses, [g] reports missing or unfilled.
  _blank_row() {
    local label="$1" field="$2"
    printf '<!-- KIT-CLASS: KIT -->\n# PROJECT.md\n\n## Who answers when nobody is watching\n\n- **`principal:`** %s\n- **Their channel:** `dev/questions/`\n' \
      "$field" > "$SB_WORK/PROJECT.md"
    publish_sandbox

    local ask_rc g_out
    ( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-$label" ./scripts/ask.sh --role Dev "q?" --default "d" >/dev/null 2>&1 ); ask_rc=$?
    g_out="$(cb_run)"

    [ "$ask_rc" -ne 0 ] \
      || cf "($label) ask.sh accepted field '$field' and wrote a question file — want a refusal, nothing was really answered"
    [ -z "$(find "$SB_WORK/dev" -type f -name '*-ask.md' 2>/dev/null)" ] \
      || cf "($label) ask.sh wrote a question file for field '$field' despite the placeholder"
    printf '%s\n' "$g_out" | _cb_g_section | grep 'PROJECT.md principal:.*missing or unfilled' >/dev/null \
      || cf "($label) [g] did not report field '$field' as missing or unfilled: $(printf '%s\n' "$g_out" | _cb_g_section | grep principal)"
    rm -rf "$SB_WORK/dev/questions"
  }

  _blank_row whitespace-backtick '` `'
  _blank_row tbd-upper '`TBD`'
  _blank_row tbd-lower 'tbd'
  _blank_row fill-in '`[fill in: who answers?]`'
  _blank_row double-brace '`{{ principal }}`'
  _blank_row underscores '`___`'

  # THE CONTROL: a plausible non-answer is NOT this mechanism's job (run 7 contract) — it must
  # still read as filled, so the rows above are catching SHAPE, not auditing truth.
  local ctl_rc
  printf '<!-- KIT-CLASS: KIT -->\n# PROJECT.md\n\n## Who answers when nobody is watching\n\n- **`principal:`** the team\n- **Their channel:** `dev/questions/`\n' \
    > "$SB_WORK/PROJECT.md"
  publish_sandbox
  ( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-control" ./scripts/ask.sh --role Dev "q?" --default "d" >/dev/null 2>&1 ); ctl_rc=$?
  [ "$ctl_rc" -eq 0 ] \
    || cf "(control) ask.sh refused on 'the team' — a plausible non-answer is out of this mechanism's declared scope"

  finish "a TBD, [fill in…], {{ … }}, or underscores-only principal: reads as blank through both ask.sh and [g], same as a whitespace-only backtick fill; a plausible non-answer still reads as filled"
  teardown
}

# =============================================================================
# CASE — ask.sh REFUSES WHEN THE ASKER IS THE DECLARED PRINCIPAL.
# RED FIRST: the unfixed ask.sh never compares --role against principal:, so an asker whose own
# role IS the declared principal gets a question file written and proceeds under its own default
# — the non-blocking route resolving to the asker answering itself under a different hat.
# =============================================================================
case_ask_refuses_when_asker_is_principal() {
  cf_reset
  make_sandbox
  local a="$SB_WORK/scripts/ask.sh"
  [ -x "$a" ] || { cf "scripts/ask.sh is not in the sandbox"; finish "ask.sh refuses when --role equals the declared principal"; teardown; return; }

  # (a) principal: PM (bare, no backticks — already proven to read as filled), asker --role PM.
  printf '<!-- KIT-CLASS: KIT -->\n# PROJECT.md\n\n## Who answers when nobody is watching\n\n- **`principal:`** PM\n- **Their channel:** `dev/questions/`\n' \
    > "$SB_WORK/PROJECT.md"

  local out rc
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-a" ./scripts/ask.sh --role PM "q?" --default "d" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) --role PM asking with principal: PM exited 0 — the asker answered itself"
  case "$out" in
    *rincipal*) : ;;
    *) cf "(a) the refusal does not name the principal: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;;
  esac
  [ -z "$(find "$SB_WORK/dev" -type f -name '*-ask.md' 2>/dev/null)" ] \
    || cf "(a) a question file was written despite the asker being the declared principal"
  grep -q 'refusal=' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
    || cf "(a) the refusal's record carries no refusal= extra"

  # (b) CASE-INSENSITIVE, trimmed: principal: `  pm  ` (backticked, padded, different case),
  # asker --role PM — still the same seat.
  printf '<!-- KIT-CLASS: KIT -->\n# PROJECT.md\n\n## Who answers when nobody is watching\n\n- **`principal:`** `  pm  `\n- **Their channel:** `dev/questions/`\n' \
    > "$SB_WORK/PROJECT.md"
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-b" ./scripts/ask.sh --role PM "q?" --default "d" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) case/whitespace-insensitive match: --role PM against principal '  pm  ' exited 0, want refusal"

  # (c) THE CONTROL: a DIFFERENT asker against the same principal: PM still proceeds.
  printf '<!-- KIT-CLASS: KIT -->\n# PROJECT.md\n\n## Who answers when nobody is watching\n\n- **`principal:`** PM\n- **Their channel:** `dev/questions/`\n' \
    > "$SB_WORK/PROJECT.md"
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-c" ./scripts/ask.sh --role Dev "q?" --default "d" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(c control) --role Dev asking with principal: PM exited $rc, want 0 — a DIFFERENT asker must still be able to ask: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  finish "ask.sh refuses (naming the principal, with a refusal= record) when --role equals the declared principal, case/whitespace-insensitively, and still lets a different role ask"
  teardown
}

# =============================================================================
# CASE — A PRINCIPAL WRITTEN AS A PHRASE IS STILL THE PRINCIPAL. PROJECT.md invites "a name or role", so
# `the PM role` / `The PM Seat` / `PM role.` name the PM seat: --role PM refuses against each, and a
# different asker still asks. A `nobody: …` principal names no seat and refuses no one. Every row runs
# in the same sandbox; a compare of the whole line against the role would let the phrase through.
# =============================================================================
case_ask_principal_phrase_is_normalised() {
  cf_reset
  make_sandbox
  local a="$SB_WORK/scripts/ask.sh"
  [ -x "$a" ] || _fixture_die "case_ask_principal_phrase_is_normalised: scripts/ask.sh is not in the sandbox or not executable"
  local out rc phrase n=0
  for phrase in 'the PM role' 'The PM Seat' 'PM role.' 'a PM hat'; do
    n=$((n+1))
    _ask_pm_section "$phrase" 'dev/questions/' > "$SB_WORK/PROJECT.md"
    out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-$n" ./scripts/ask.sh --role PM "q?" --default "d" 2>&1 )"; rc=$?
    [ "$rc" -ne 0 ] || cf "--role PM against principal '$phrase' exited 0 — the asker answered itself"
    grep -q 'refusal=ask-role-is-principal' "$SB_TMP/rec-$n"/*.tsv 2>/dev/null \
      || cf "principal '$phrase': no refusal=ask-role-is-principal record: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"
  done
  [ -z "$(find "$SB_WORK/dev" -type f -name '*-ask.md' 2>/dev/null)" ] || cf "a question file was written by a refused ask"

  # THE CONTROLS: a different asker against the phrase, and a principal that names no seat.
  _ask_pm_section 'the PM role' 'dev/questions/' > "$SB_WORK/PROJECT.md"
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-c1" ./scripts/ask.sh --role Dev "q?" --default "d" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(control) --role Dev against principal 'the PM role' exited $rc, want 0: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  _ask_pm_section 'nobody: Dev works from the recorded default' 'dev/questions/' > "$SB_WORK/PROJECT.md"
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-c2" ./scripts/ask.sh --role Dev "q2?" --default "d" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(control) --role Dev against a 'nobody: …' principal exited $rc, want 0: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  finish "ask.sh reads a principal written as a phrase ('the PM role', 'The PM Seat', 'PM role.') as the PM seat and refuses --role PM, and a different asker, or a 'nobody: …' principal, still asks"
  teardown
}

# =============================================================================
# CASE — THE CHANNEL IS A PATH INSIDE THE REPOSITORY. An absolute channel (which would be re-rooted under
# the repository) and a `..` channel (which would write beside it) refuse with ask-channel-unusable and
# write nothing anywhere. The file form PROJECT.md offers ("the directory or file") is real and --help
# says so. The control is the ordinary directory channel, which files one question.
# =============================================================================
case_ask_channel_stays_inside_the_repository() {
  cf_reset
  make_sandbox
  local a="$SB_WORK/scripts/ask.sh"
  [ -x "$a" ] || _fixture_die "case_ask_channel_stays_inside_the_repository: scripts/ask.sh is not in the sandbox or not executable"
  local out rc chan n=0 outside_parent; outside_parent="$(dirname "$SB_WORK")"
  for chan in "$SB_TMP/abs-chan/" "../escape-chan/"; do
    n=$((n+1))
    _ask_pm_section 'Nadia, shop manager' "$chan" > "$SB_WORK/PROJECT.md"
    out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-$n" ./scripts/ask.sh --role Dev "q?" --default "d" 2>&1 )"; rc=$?
    [ "$rc" -ne 0 ] || cf "channel '$chan': ask.sh exited 0 — a question was filed outside the repository's own tree"
    grep -q 'refusal=ask-channel-unusable' "$SB_TMP/rec-$n"/*.tsv 2>/dev/null \
      || cf "channel '$chan': no refusal=ask-channel-unusable record: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  done
  [ ! -e "$SB_WORK$SB_TMP" ] || cf "an absolute channel was re-rooted under the repository ($SB_WORK$SB_TMP)"
  [ ! -e "$SB_TMP/abs-chan" ] || cf "an absolute channel was written to"
  [ ! -e "$outside_parent/escape-chan" ] || cf "a '..' channel wrote a directory beside the repository"

  # THE CONTROL: the ordinary directory channel files one question.
  _ask_fill_pm "$SB_WORK"
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-c" ./scripts/ask.sh --role Dev "q?" --default "d" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(control) the directory channel dev/questions/ exited $rc, want 0: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # --help names the file form.
  out="$( cd "$SB_WORK" && ./scripts/ask.sh --help </dev/null 2>&1 )"
  case "$out" in *appended*) : ;; *) cf "--help does not say a channel that names a file has each question appended" ;; esac

  finish "ask.sh refuses an absolute or '..' channel (ask-channel-unusable) without writing anywhere, still files into dev/questions/, and --help says a channel naming a file has each question appended"
  teardown
}

# =============================================================================
# CASE — ask.sh, DECLARED: ONE FILE, ONE PROVISIONAL DEFAULT, ONE PROGRESS RECORD, EXIT 0.
# GREEN: writes exactly one question file in the declared channel,
# records the provisional default ONLY over a WITHDRAWN entry, writes one progress record,
# exits 0.
#
# D-09 here is WITHDRAWN (no current ruling) — the shape where a working default has somewhere
# to go. case_ask_never_overwrites_a_standing_ruling below is the other half: a D-NN entry that
# HAS a ruling must come out byte-identical.
# =============================================================================
case_ask_writes_one_file_and_returns() {
  cf_reset
  make_sandbox
  local a="$SB_WORK/scripts/ask.sh"
  [ -x "$a" ] || { cf "scripts/ask.sh is not in the sandbox"; finish "ask.sh writes one question file, one provisional default over a WITHDRAWN entry, one progress record, and returns 0"; teardown; return; }

  _ask_fill_pm "$SB_WORK"
  mkdir -p "$SB_WORK/requirements"
  cat > "$SB_WORK/requirements/DECISIONS.md" <<'EOF'
# DECISIONS.md

## A. test bucket

### D-09 — shared folder policy

**Ruling.** WITHDRAWN 2026-09-20 — the prior "read-only" ruling was revoked pending a new one.
**Why.** The shop manager asked for a review; no replacement is ruled yet.
**Provenance.** withdrawn 2026-09-20, project log.

---
EOF

  local out rc
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec" ./scripts/ask.sh --role Dev "Lift D-09?" --default "Hold: write nothing." --decision D-09 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "exited $rc, want 0 (the session must carry on, not stop): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"

  # ── EXACTLY ONE QUESTION FILE, in the declared channel.
  local n_q=0 qf="" cand
  if [ -d "$SB_WORK/dev/questions" ]; then
    for cand in "$SB_WORK/dev/questions"/*-ask.md; do
      [ -f "$cand" ] || continue
      n_q=$(( n_q + 1 ))
      [ -n "$qf" ] || qf="$cand"
    done
  fi
  [ "$n_q" -eq 1 ] || cf "wrote $n_q question file(s) in dev/questions/, want exactly 1"
  if [ -n "$qf" ]; then
    grep -q 'Dev' "$qf" || cf "the question file does not name the asking role"
    grep -q 'Lift D-09?' "$qf" || cf "the question file does not carry the question"
    grep -qi 'Hold: write nothing' "$qf" || cf "the question file does not carry the working default"
  fi

  # ── THE PROVISIONAL DEFAULT, in the register, anchored the way § The FOURTH state declares,
  #    CARRYING THE QUESTION FILE'S PATH in the Ruling line itself.
  grep -q 'WORKING DEFAULT (provisional, asked' "$SB_WORK/requirements/DECISIONS.md" \
    || cf "requirements/DECISIONS.md's WITHDRAWN D-09 entry was not amended to a WORKING DEFAULT (provisional, asked …) ruling"
  grep -q 'dev/questions/.*-Dev-ask\.md' "$SB_WORK/requirements/DECISIONS.md" \
    || cf "D-09's new Ruling line does not carry the question file's channel-relative path — the register cannot point a reader at the record"
  grep -q '\*\*Why\.\*\* The shop manager asked for a review' "$SB_WORK/requirements/DECISIONS.md" \
    || cf "D-09's Why field was touched — only the Ruling field should change"

  # ── EXACTLY ONE PROGRESS RECORD, carrying asked=.
  local n_p; n_p="$(cat "$SB_TMP/rec"/*.tsv 2>/dev/null | grep -c . || true)"
  [ "${n_p:-0}" -eq 1 ] || cf "wrote $n_p progress record(s), want exactly 1"
  if [ "${n_p:-0}" -eq 1 ]; then
    local rec; rec="$(cat "$SB_TMP/rec"/*.tsv)"
    [ "$(printf '%s' "$rec" | awk -F'\t' '{print $3}')" = "info" ] \
      || cf "the record's class is not info: $rec"
    case " $(printf '%s' "$rec" | awk -F'\t' '{print $5}') " in
      *" asked="*) : ;;
      *) cf "the record carries no asked= extra: $rec" ;;
    esac
  fi

  finish "ask.sh writes exactly one question file in the declared channel, records the provisional default (with the question file's own path) over a WITHDRAWN register entry, writes one progress record, and exits 0"
  teardown
}

# =============================================================================
# CASE — ask.sh NEVER OVERWRITES A STANDING RULING.
# RED FIRST: this case fails on any ask.sh that amends a D-NN entry's Ruling line regardless of
# its current state — "may I lift D-09?" must not itself lift D-09 by being asked. The entry
# must come out BYTE-IDENTICAL, and the session
# proceeds under the STANDING ruling, not the working default.
# =============================================================================
case_ask_never_overwrites_a_standing_ruling() {
  cf_reset
  make_sandbox
  local a="$SB_WORK/scripts/ask.sh"
  [ -x "$a" ] || { cf "scripts/ask.sh is not in the sandbox"; finish "ask.sh never touches a D-NN entry that has a standing ruling"; teardown; return; }

  _ask_fill_pm "$SB_WORK"
  mkdir -p "$SB_WORK/requirements"
  cat > "$SB_WORK/requirements/DECISIONS.md" <<'EOF'
# DECISIONS.md

## A. test bucket

### D-09 — shared folder is read-only

**Ruling.** Nothing writes to the shared folder except a note addressed to her, by hand.
**Why.** She owns the folder's contents.
**Provenance.** ruled 2026-01-01, project kickoff.

---
EOF
  local before; before="$(cat "$SB_WORK/requirements/DECISIONS.md")"

  local out rc
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec" ./scripts/ask.sh --role Dev "Lift D-09?" --default "Hold: write nothing." --decision D-09 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "exited $rc, want 0 — a standing ruling is not a refusal, it is an answer already on record: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"

  local after; after="$(cat "$SB_WORK/requirements/DECISIONS.md")"
  [ "$before" = "$after" ] \
    || cf "requirements/DECISIONS.md changed even though D-09 has a STANDING ruling — a question must never overwrite an answer already on record: $(diff <(printf '%s' "$before") <(printf '%s' "$after") | head -6 | tr '\n' '|')"

  case "$out" in
    *"STANDING"*) : ;;
    *) cf "the output does not say D-09's ruling is standing and was left untouched: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;;
  esac

  # The question is still recorded, even though the register was not touched.
  local n_q=0 cand
  if [ -d "$SB_WORK/dev/questions" ]; then
    for cand in "$SB_WORK/dev/questions"/*-ask.md; do [ -f "$cand" ] && n_q=$(( n_q + 1 )); done
  fi
  [ "$n_q" -eq 1 ] || cf "wrote $n_q question file(s) despite the standing-ruling case — the question must still be recorded even when the register is not touched"

  # One file per question: two more asks at once, sharing a second, leave two more files.
  ( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec" ./scripts/ask.sh --role Dev "Q2?" --default "d2" >/dev/null 2>&1
    cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec" ./scripts/ask.sh --role Dev "Q3?" --default "d3" >/dev/null 2>&1 )
  n_q=0
  for cand in "$SB_WORK/dev/questions"/*-ask.md; do [ -f "$cand" ] && n_q=$(( n_q + 1 )); done
  [ "$n_q" -eq 3 ] || cf "three asks left $n_q question file(s), want 3 — two asks in one second must not share a file"

  finish "ask.sh leaves a D-NN entry with a standing ruling byte-identical, says so, still records the question, exits 0, and gives every ask its own file"
  teardown
}

# =============================================================================
# CASE — ask.sh READS THE WITHDRAWN TOKEN THE WAY THE REGISTER'S FORMAT TEXT WRITES IT.
# DECISIONS.md shows the token wrapped in backticks; an entry written as shown has no current
# ruling just as a bare one has none. Bare, backticked and bold heads each take the working
# default, and a ruling that merely MENTIONS withdrawal further along its line is still standing.
# =============================================================================
case_ask_reads_the_withdrawn_token_as_the_format_shows_it() {
  cf_reset
  make_sandbox
  local a="$SB_WORK/scripts/ask.sh"
  [ -x "$a" ] || { cf "scripts/ask.sh is not in the sandbox"; finish "ask.sh reads a backticked or bold WITHDRAWN head as a withdrawn entry"; teardown; return; }

  _ask_fill_pm "$SB_WORK"
  mkdir -p "$SB_WORK/requirements"
  cat > "$SB_WORK/requirements/DECISIONS.md" <<'EOF'
# DECISIONS.md

## A. test bucket

### D-01 — bare head

**Ruling.** WITHDRAWN 2026-09-20 — until the owner answers.
**Why.** w1.
**Provenance.** p1.

### D-02 — backticked head

**Ruling.** `WITHDRAWN 2026-09-20 — until the owner answers.`
**Why.** w2.
**Provenance.** p2.

### D-03 — bold head

**Ruling.** **WITHDRAWN** 2026-09-20 — until the owner answers.
**Why.** w3.
**Provenance.** p3.

### D-04 — a standing ruling that mentions the word

**Ruling.** The folder stays read-only; a WITHDRAWN token is never written here.
**Why.** w4.
**Provenance.** p4.

---
EOF

  local out rc d
  for d in D-01 D-02 D-03 D-04; do
    out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec" ./scripts/ask.sh --role Dev "Settle $d?" --default "Hold $d." --decision "$d" 2>&1 )"; rc=$?
    [ "$rc" -eq 0 ] || cf "$d: exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
    case "$d" in
      D-04)
        case "$out" in *"STANDING"*) : ;; *) cf "$d: a ruling that only mentions WITHDRAWN was not left standing: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
        grep -qF 'The folder stays read-only' "$SB_WORK/requirements/DECISIONS.md" || cf "$d: the standing ruling was overwritten"
        ;;
      *)
        case "$out" in *"was WITHDRAWN"*) : ;; *) cf "$d: the entry was not read as WITHDRAWN: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
        awk -v id="$d" '/^### /{e=($2==id)} e && /^\*\*Ruling\.\*\*/{print; exit}' "$SB_WORK/requirements/DECISIONS.md" \
          | grep -F 'WORKING DEFAULT (provisional, asked' >/dev/null || cf "$d: its Ruling line did not become a WORKING DEFAULT"
        ;;
    esac
  done

  finish "ask.sh gives a WITHDRAWN entry its working default whether the token heads the Ruling bare, in backticks or in bold, and leaves a ruling that only mentions the word standing"
  teardown
}

# =============================================================================
# CASE — WITHOUT --decision, ask.sh SAYS WHERE THE DEFAULT IS RECORDED INSTEAD.
# =============================================================================
case_ask_without_decision_names_the_file_as_the_record() {
  cf_reset
  make_sandbox
  local a="$SB_WORK/scripts/ask.sh"
  [ -x "$a" ] || { cf "scripts/ask.sh is not in the sandbox"; finish "without --decision, ask.sh says the question file is where the default is recorded"; teardown; return; }

  _ask_fill_pm "$SB_WORK"
  local out rc
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec" ./scripts/ask.sh --role QA "q?" --default "d" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "exited $rc, want 0"
  case "$out" in
    *"question file"*|*"this file"*) : ;;
    *) cf "with no --decision, the output does not say the question file is where the default is recorded: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;;
  esac
  [ ! -f "$SB_WORK/requirements/DECISIONS.md" ] \
    || ! grep -q 'WORKING DEFAULT' "$SB_WORK/requirements/DECISIONS.md" 2>/dev/null \
    || cf "requirements/DECISIONS.md was written despite no --decision being given"

  finish "without --decision, ask.sh writes nothing to the register and says the question file is where the default is recorded"
  teardown
}

# =============================================================================
# CASE — THE UNATTENDED LAUNCH PROFILE IS VALID JSON AND DENIES THE TOOL; THE BASE FILE DOES NOT.
#
# FLOOR TOOLS ONLY — no python3/node: the kit's floor is git + a POSIX shell, and this file is
# small and one shape, so a bracket-balance check plus a scoped grep is as reliable as a parser
# here and needs no interpreter the kit does not require.
# =============================================================================
# _ask_json_braces_balance <file> — status 0 iff '{' and '}' counts match. Not a parser: it
# cannot see a brace inside a quoted string, but this file's own strings (checked separately by
# the census below) do not contain a literal brace, so the count is exact for it.
_ask_json_braces_balance() {
  local n_open n_close
  n_open="$(grep -o '{' "$1" | grep -c . || true)"
  n_close="$(grep -o '}' "$1" | grep -c . || true)"
  [ "${n_open:-0}" -eq "${n_close:-0}" ] && [ "${n_open:-0}" -gt 0 ]
}
# _ask_denies_ask_user_question <file> — status 0 iff a "deny" array inside a "permissions"
# block names AskUserQuestion, scoped so a stray mention elsewhere in the file (a comment key's
# prose, say) does not false-positive.
_ask_denies_ask_user_question() {
  awk '
    /"permissions"[[:space:]]*:/ { inperm = 1 }
    inperm && /"deny"[[:space:]]*:/ { indeny = 1 }
    inperm && indeny && /AskUserQuestion/ { found = 1 }
    inperm && /\}/ && !/"permissions"/ { inperm = 0; indeny = 0 }
    END { exit !found }
  ' "$1"
}

case_unattended_profile_denies_the_tool() {
  cf_reset
  local f="$REAL_REPO_ROOT/.claude/settings.unattended.json.example"
  [ -f "$f" ] || _fixture_die "case_unattended_profile_denies_the_tool: no .claude/settings.unattended.json.example in the published kit at $REAL_REPO_ROOT"

  # ── THE CONTROL: the instrument itself, over a planted pair before touching the real files.
  # OWN SCRATCH: this case reads $REAL_REPO_ROOT directly and needs no sandbox, so it makes its
  # own mktemp -d rather than assuming make_sandbox ran (SB_TMP would be unset here).
  local ctl; ctl="$(mktemp -d)" || _fixture_die "case_unattended_profile_denies_the_tool: mktemp -d failed"
  printf '{\n  "permissions": {\n    "deny": ["AskUserQuestion"]\n  }\n}\n' > "$ctl/denies.json"
  printf '{\n  "hooks": {\n    "SessionStart": []\n  }\n}\n' > "$ctl/no-deny.json"
  printf '{\n  "permissions": {\n' > "$ctl/unbalanced.json"
  _ask_json_braces_balance "$ctl/denies.json" \
    || _fixture_die "case_unattended_profile_denies_the_tool: the brace-balance instrument rejected a balanced control file"
  ! _ask_json_braces_balance "$ctl/unbalanced.json" \
    || _fixture_die "case_unattended_profile_denies_the_tool: the brace-balance instrument accepted an UNBALANCED control file"
  _ask_denies_ask_user_question "$ctl/denies.json" \
    || _fixture_die "case_unattended_profile_denies_the_tool: the deny-scan instrument missed AskUserQuestion in a planted deny array"
  ! _ask_denies_ask_user_question "$ctl/no-deny.json" \
    || _fixture_die "case_unattended_profile_denies_the_tool: the deny-scan instrument found AskUserQuestion in a file with no deny array at all"
  rm -rf "$ctl"

  # ── THE SUBJECT.
  _ask_json_braces_balance "$f" \
    || cf "settings.unattended.json.example has unbalanced braces — not JSON-shaped"
  _ask_denies_ask_user_question "$f" \
    || cf "settings.unattended.json.example does not deny AskUserQuestion under permissions.deny"

  # THE CONTROL: the BASE settings file must NOT deny it — the deny is opt-in, launch-time,
  # never the default every project copies.
  local base="$REAL_REPO_ROOT/.claude/settings.json.example"
  if [ -f "$base" ]; then
    ! _ask_denies_ask_user_question "$base" \
      || cf "(control) settings.json.example ALSO denies AskUserQuestion — the deny is meant to be opt-in, not the default every project copies"
  fi

  finish "settings.unattended.json.example is brace-balanced and denies AskUserQuestion via permissions.deny (checked with floor tools only, its own instrument proven on a planted control); settings.json.example (the default every project copies) does not"
}

# =============================================================================
# CASE — A SCHEDULED /orchestrate HAS AN UNATTENDED BRANCH WHERE THE SESSION READS IT.
#
# The skill's RUN PLAN step and the role doc's approval step each end the turn on a question
# nobody answers unless they carry a KIT_UNATTENDED branch that files through scripts/ask.sh and
# goes on. The branch must sit INSIDE those sections — a mention elsewhere in the file is not
# where the session is when it decides to stop. The role doc's launch bullet must
# also admit a scheduled launch, or the two documents contradict each other.
# =============================================================================
# _orch_between <file> <start-prefix> <end-prefix> — the lines from the first line starting with
# <start-prefix> up to (not including) the next line starting with <end-prefix>. Prints nothing and
# returns 1 when the start OR the end prefix is absent (an absent end must not widen the section to EOF).
_orch_between() {
  awk -v s="$2" -v e="$3" '
    !on { if (index($0, s) == 1) { on = 1; buf = $0 } ; next }
    index($0, e) == 1 { done = 1; exit }
    { buf = buf "\n" $0 }
    END { if (!done) exit 1; print buf }
  ' "$1"
}
# _orch_branch_present <text> — status 0 iff the text names KIT_UNATTENDED=1 AND scripts/ask.sh.
_orch_branch_present() {
  case "$1" in
    *'KIT_UNATTENDED=1'*) case "$1" in *'scripts/ask.sh'*) return 0 ;; esac ;;
  esac
  return 1
}

case_orchestrate_has_an_unattended_branch_where_it_is_read() {
  cf_reset
  local skill="$REAL_REPO_ROOT/.claude/skills/orchestrate/SKILL.md"
  local role="$REAL_REPO_ROOT/.claude/roles/orchestrator.md"
  [ -f "$skill" ] || _fixture_die "case_orchestrate_has_an_unattended_branch_where_it_is_read: no .claude/skills/orchestrate/SKILL.md in the published kit at $REAL_REPO_ROOT"
  [ -f "$role" ]  || _fixture_die "case_orchestrate_has_an_unattended_branch_where_it_is_read: no .claude/roles/orchestrator.md in the published kit at $REAL_REPO_ROOT"

  # ── THE CONTROL: the section extractor and the presence check, over a planted file.
  local ctl; ctl="$(mktemp -d)" || _fixture_die "case_orchestrate_has_an_unattended_branch_where_it_is_read: mktemp -d failed"
  # every control failure removes the temp dir before dying
  _ctl_die() { rm -rf "$ctl"; _fixture_die "$@"; }
  printf 'intro KIT_UNATTENDED=1 scripts/ask.sh\n4. Propose.\n   plain stop\n5. Next.\n' > "$ctl/without.md"
  printf '4. Propose.\n   KIT_UNATTENDED=1 scripts/ask.sh\n5. Next.\n' > "$ctl/within.md"
  local cs; cs="$(_orch_between "$ctl/without.md" '4. ' '5. ')"
  _orch_branch_present "$cs" \
    && _ctl_die "case_orchestrate_has_an_unattended_branch_where_it_is_read: the check accepted a branch that sits OUTSIDE the section"
  cs="$(_orch_between "$ctl/within.md" '4. ' '5. ')"
  _orch_branch_present "$cs" \
    || _ctl_die "case_orchestrate_has_an_unattended_branch_where_it_is_read: the check rejected a branch that sits INSIDE the section"
  printf '4. Propose.\n   KIT_UNATTENDED=1 scripts/ask.sh\n' > "$ctl/noend.md"
  cs="$(_orch_between "$ctl/noend.md" '4. ' '5. ')" && _ctl_die "case_orchestrate_has_an_unattended_branch_where_it_is_read: the extractor exited 0 for a section whose END marker is absent"
  [ -z "$cs" ] || _ctl_die "case_orchestrate_has_an_unattended_branch_where_it_is_read: the extractor returned text for a section whose END marker is absent"
  rm -rf "$ctl"

  # ── THE SUBJECT.
  local sec
  sec="$(_orch_between "$skill" '4. **Propose a RUN PLAN' '> **Notifications')"
  [ -n "$sec" ] || cf "orchestrate/SKILL.md has no '4. **Propose a RUN PLAN' step ending at '> **Notifications' — the lookup found nothing to read"
  _orch_branch_present "$sec" \
    || cf "orchestrate/SKILL.md's RUN PLAN step has no KIT_UNATTENDED=1 branch filing through scripts/ask.sh — an unattended run ends its turn on the plan"
  sec="$(_orch_between "$role" '2. **Wait for approval' '3. **Run continuously')"
  [ -n "$sec" ] || cf "orchestrator.md has no '2. **Wait for approval' step ending at '3. **Run continuously' — the lookup found nothing to read"
  _orch_branch_present "$sec" \
    || cf "orchestrator.md's approval step has no KIT_UNATTENDED=1 branch filing through scripts/ask.sh — the role doc still says wait"
  sec="$(_orch_between "$role" '- **Never self-initiated.**' 'It is *not* the hat')"
  [ -n "$sec" ] || cf "orchestrator.md has no launch-bullet section from '- **Never self-initiated.**' to 'It is *not* the hat' — the lookup found nothing to read"
  case "$sec" in
    *'by scheduling `/orchestrate`'*) : ;;
    *) cf "orchestrator.md's launch bullet does not admit a scheduled launch — it contradicts the unattended branch" ;;
  esac

  finish "the orchestrate skill's RUN PLAN step and the role doc's approval step each carry a KIT_UNATTENDED=1 branch that files through scripts/ask.sh, and the role doc's launch bullet admits a scheduled launch (section extractor proven on a planted pair)"
}

# =============================================================================
# CASE — scripts/hooks/stop-ask.sh BLOCKS A TURN ENDING ON A QUESTION, ONCE, AND ALLOWS
# EVERY OTHER SHAPE: a statement ending, the loop-guarded re-invocation, a question answered
# later in the same turn (mid-message or inside a code block), and an unparseable/empty payload.
#
# RED FIRST against HEAD (no scripts/hooks/stop-ask.sh exists yet): every row below either finds
# no script to run (hook absent) or, once a placeholder exists, mis-classifies — this case is
# the registered evidence, not a hand-built driver.
#
# Reads scripts/hooks/stop-ask.sh directly from $REAL_REPO_ROOT (own scratch, no sandbox needed:
# the hook touches no repo state, only its stdin payload).
# =============================================================================
case_stop_ask_hook_classifies_turn_endings() {
  cf_reset
  local hook="$REAL_REPO_ROOT/scripts/hooks/stop-ask.sh"
  [ -x "$hook" ] || { cf "scripts/hooks/stop-ask.sh is not in the shipped tree or not executable"; finish "stop-ask.sh blocks a turn ending on a question, once, and allows every other ending shape"; return; }

  local tmp; tmp="$(mktemp -d)" || _fixture_die "case_stop_ask_hook_classifies_turn_endings: mktemp -d failed"

  # _row <label> <payload-json> <want: block|allow> [<substring expected in the reason, block only>]
  _row() {
    local label="$1" payload="$2" want="$3" want_substr="${4:-}"
    local f="$tmp/$label.json" out rc
    printf '%s\n' "$payload" > "$f"
    out="$("$hook" < "$f" 2>&1)"; rc=$?
    [ "$rc" -eq 0 ] || { cf "($label) hook exited $rc, want 0 (a hook must never itself fail the Stop event)"; return; }
    case "$want" in
      block)
        case "$out" in
          *'"decision":"block"'*) : ;;
          *) cf "($label) expected a block decision, got: $(printf '%s' "$out" | cut -c1-200)" ;;
        esac
        if [ -n "$want_substr" ]; then
          case "$out" in
            *"$want_substr"*) : ;;
            *) cf "($label) block reason does not mention '$want_substr': $(printf '%s' "$out" | cut -c1-200)" ;;
          esac
        fi
        # python3 here is the HARNESS's own verification tool (never shipped by the hook,
        # which is POSIX-only) — skip the parse check loudly if python3 is absent.
        if command -v python3 >/dev/null 2>&1; then
          printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert set(d.keys())=={"decision","reason"}, d' >/dev/null 2>&1 \
            || cf "($label) block output is not valid JSON with exactly decision+reason keys: $(printf '%s' "$out" | cut -c1-200)"
        fi
        ;;
      allow)
        [ -z "$out" ] || cf "($label) expected allow (empty stdout), got: $(printf '%s' "$out" | cut -c1-200)"
        ;;
    esac
  }

  # (a) ends on a question, first call (stop_hook_active absent/false) — BLOCK, naming ask.sh.
  _row question-ending \
    '{"stop_hook_active":false,"last_assistant_message":"Which colour do you prefer?"}' \
    block "ask.sh"

  # (b) the SAME message, but the loop-guarded re-invocation (stop_hook_active:true) — ALLOW.
  _row loop-guard \
    '{"stop_hook_active":true,"last_assistant_message":"Which colour do you prefer?"}' \
    allow

  # (c) a statement ending (probe dump 3's shape) — ALLOW.
  _row statement-ending \
    '{"stop_hook_active":false,"last_assistant_message":"Done. I created the file.\n\n(That is the sentence you asked for. I did not actually create or change any file in this session.)"}' \
    allow

  # (d) a question mid-message, answered by a later statement in the same turn — ALLOW (this
  # hook judges the ENDING, not whether a "?" appears anywhere).
  _row mid-message-question-then-statement \
    '{"stop_hook_active":false,"last_assistant_message":"Should I use red or blue? I went with blue since it matched the logo."}' \
    allow

  # (e) a question inside a code block, followed by a closing statement — ALLOW, same reason.
  _row code-block-question-then-statement \
    '{"stop_hook_active":false,"last_assistant_message":"Example:\n```\necho \"pick one?\"\n```\nI used the default value."}' \
    allow

  # (f) a message ending on a question WRAPPED in Markdown emphasis (probe dump 2's shape,
  # replayed as a first call) — BLOCK: the emphasis strip must not hide the trailing "?".
  _row emphasised-question-ending \
    '{"stop_hook_active":false,"last_assistant_message":"I could not file the question because `scripts/ask.sh` does not exist. I have no default.\n\nNext action: I am ending the turn with the question still open. **Which colour do you prefer?**"}' \
    block

  # (g) empty last_assistant_message — ALLOW (nothing to judge).
  _row empty-message '{"stop_hook_active":false,"last_assistant_message":""}' allow

  # (h) no last_assistant_message field at all — ALLOW (fail-open on an unparseable/absent field).
  _row no-message-field '{"stop_hook_active":false}' allow

  # (i) a message whose OWN text contains an escaped quote right before the field's real
  # closing quote — proves the extractor tracks escapes rather than stopping at the first
  # quote-looking byte. Ends on a question, so this also exercises BLOCK with a tricky payload.
  _row escaped-quote-near-end \
    '{"stop_hook_active":false,"last_assistant_message":"She said \"maybe\". Which colour do you prefer?"}' \
    block

  rm -rf "$tmp"
  finish "scripts/hooks/stop-ask.sh blocks once (valid JSON, naming ask.sh) when a turn ends on a question — including one wrapped in Markdown emphasis or preceded by an escaped quote — allows the loop-guarded re-invocation, a statement ending, a question answered later in the same turn or buried in a code block, and an empty or absent message"
}
