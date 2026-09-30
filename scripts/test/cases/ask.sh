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
# ask.sh's _pm_field reads (the KIT-CLASS marker line first, so a tree that DROPS it at
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
# its current state — the exact defect run 5's own D-09 case showed: "may I lift D-09?" must not
# itself lift D-09 by being asked. The entry must come out BYTE-IDENTICAL, and the session
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
