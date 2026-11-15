# KIT-CLASS: MIXED — self-test harness, the `forks:` landing precondition. See
# process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/forks.sh — sourced by scripts/test/run.sh, never run on its own.
# Pins the `forks:` precondition (process/contracts/landing-gate.md § 3), as finish-pr.sh applies it.
# =============================================================================

# _forks_seed_register <path> [<D-01-ruling>] — a minimal, well-shaped register: one bucket
# heading, one live entry (D-01), one retired row naming D-01 as ITS successor (so a citation of
# D-01 never reads as retired by accident).
_forks_seed_register() {
  local path="$1" ruling="${2:-Old text.}"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<EOF
# DECISIONS
## A. First bucket

### D-01

**Ruling.** ${ruling}

## Retired ids

\`D-00\` — retired 2026-01-01; its scope moved into D-01.

## Findings
EOF
}

# =============================================================================
# CASE — ABSENT OR MALFORMED 'forks:' REFUSES, NAMED, WITH A COUNTABLE RECORD.
# RED FIRST: fails on any finish-pr.sh that does not read 'forks:' at all.
# =============================================================================
case_finish_pr_forks_missing_or_malformed_refuses() {
  cf_reset
  make_sandbox
  _forks_seed_register "$SB_WORK/requirements/DECISIONS.md"

  # (a) ABSENT — seed_issue's frontmatter minus its forks: line.
  local ida="$SB_PREFIX-601"
  seed_issue dev_complete "$ida" absent chore "No forks field" "feature/$ida-work"
  sed -i.bak '/^forks: none$/d' "$SB_WORK/progress/dev_complete/$ida-absent.md"
  rm -f "$SB_WORK/progress/dev_complete/$ida-absent.md.bak"
  grep -q '^forks:' "$SB_WORK/progress/dev_complete/$ida-absent.md" \
    && _fixture_die "case_finish_pr_forks_missing_or_malformed_refuses: (a) the forks: line survived the strip"
  publish_sandbox
  seed_branch "$ida" work CHANGE601A.txt

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-a" "$SB_WORK/scripts/finish-pr.sh" "$ida" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) absent 'forks:' — finish-pr.sh exited 0"
  case "$out" in *"forks:"*) : ;; *) cf "(a) the refusal does not name 'forks:': $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "CHANGE601A.txt" && cf "(a) the branch was merged before the refusal"
  origin_has_path "progress/qa_complete/$ida-absent.md" && cf "(a) the card advanced despite the refusal"
  grep -q 'refusal=forks-missing' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
    || cf "(a) no progress record carries refusal=forks-missing: $(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null)"

  # (b) MALFORMED — neither 'none' nor a '[D-NN, ...]' list.
  local idb="$SB_PREFIX-602"
  seed_issue dev_complete "$idb" malformed chore "Bad forks field" "feature/$idb-work"
  sed -i.bak 's/^forks: none$/forks: yes/' "$SB_WORK/progress/dev_complete/$idb-malformed.md"
  rm -f "$SB_WORK/progress/dev_complete/$idb-malformed.md.bak"
  publish_sandbox
  seed_branch "$idb" work CHANGE601B.txt

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-b" "$SB_WORK/scripts/finish-pr.sh" "$idb" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) malformed 'forks:' — finish-pr.sh exited 0"
  case "$out" in *"forks:"*) : ;; *) cf "(b) the refusal does not name 'forks:': $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "CHANGE601B.txt" && cf "(b) the branch was merged before the refusal"
  grep -q 'refusal=forks-malformed' "$SB_TMP/rec-b"/*.tsv 2>/dev/null \
    || cf "(b) no progress record carries refusal=forks-malformed: $(cat "$SB_TMP/rec-b"/*.tsv 2>/dev/null)"

  # (c) MALFORMED — an empty list is not 'none'.
  local idc="$SB_PREFIX-603"
  seed_issue dev_complete "$idc" empty chore "Empty forks list" "feature/$idc-work"
  sed -i.bak 's/^forks: none$/forks: []/' "$SB_WORK/progress/dev_complete/$idc-empty.md"
  rm -f "$SB_WORK/progress/dev_complete/$idc-empty.md.bak"
  publish_sandbox
  seed_branch "$idc" work CHANGE601C.txt

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-c" "$SB_WORK/scripts/finish-pr.sh" "$idc" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(c) empty-list 'forks: []' — finish-pr.sh exited 0"
  grep -q 'refusal=forks-malformed' "$SB_TMP/rec-c"/*.tsv 2>/dev/null \
    || cf "(c) no progress record carries refusal=forks-malformed: $(cat "$SB_TMP/rec-c"/*.tsv 2>/dev/null)"

  finish "finish-pr.sh refuses a landing whose card's 'forks:' is absent, or malformed (neither 'none' nor a non-empty '[D-NN, ...]' list), before the merge, each leaving a countable refusal= record"
  teardown
}

# =============================================================================
# CASE — A 'forks:' LIST NAMING AN UNRESOLVED ID REFUSES.
# The register is read from the BRANCH's own copy: an id the branch itself mints must resolve.
# =============================================================================
case_finish_pr_forks_unresolved_id_refuses() {
  cf_reset
  make_sandbox
  _forks_seed_register "$SB_WORK/requirements/DECISIONS.md"

  local id="$SB_PREFIX-611"
  seed_issue dev_complete "$id" phantom chore "Cites a phantom decision" "feature/$id-work"
  sed -i.bak 's/^forks: none$/forks: [D-77]/' "$SB_WORK/progress/dev_complete/$id-phantom.md"
  rm -f "$SB_WORK/progress/dev_complete/$id-phantom.md.bak"
  publish_sandbox
  seed_branch "$id" work CHANGE611.txt

  local out rc _need
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "an unresolved 'forks:' id — finish-pr.sh exited 0"
  case "$out" in *D-77*) : ;; *) cf "the refusal does not name D-77: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  # A new register entry also needs a PRD citation or the exemption token, or the landing's corpus
  # check refuses it: the message names the declared PRD surface, the token and that check.
  local _prd='requirements/PRD-*.md'
  for _need in "$_prd" '[cross-cutting]' 'board-corpus-coverage'; do
    case "$out" in *"$_need"*) : ;; *) cf "the forks-unresolved refusal does not name '$_need': $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)" ;; esac
  done
  origin_has_path "CHANGE611.txt" && cf "the branch was merged before the refusal"
  grep -q 'refusal=forks-unresolved' "$SB_TMP/rec"/*.tsv 2>/dev/null \
    || cf "no progress record carries refusal=forks-unresolved: $(cat "$SB_TMP/rec"/*.tsv 2>/dev/null)"

  finish "finish-pr.sh refuses a landing whose 'forks:' names an id that is not a LIVE entry in the branch's own copy of the register, naming the id, with a refusal=forks-unresolved record"
  teardown
}

# =============================================================================
# CASE — THE DERIVATION: A BRANCH THAT ADDS/CHANGES A REGISTER ENTRY, OR CITES ONE IN
# ACTIVITY, CONTRADICTS A 'forks: none' THAT DOES NOT NAME IT.
#
# Derive, do not only self-report: two independent sources, either one alone must refuse.
# =============================================================================
case_finish_pr_forks_contradicted_by_the_branch_refuses() {
  cf_reset
  make_sandbox
  _forks_seed_register "$SB_WORK/requirements/DECISIONS.md"
  publish_sandbox

  # (a) THE BRANCH'S DIFF ADDS A NEW D-NN ENTRY, and the card still says 'forks: none'.
  local ida="$SB_PREFIX-621"
  seed_issue dev_complete "$ida" newreg chore "Adds a register entry" "feature/$ida-work"
  publish_sandbox
  git -C "$SB_WORK" branch "feature/$ida-work" "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" checkout -q "feature/$ida-work" >/dev/null 2>&1
  cat >> "$SB_WORK/requirements/DECISIONS.md" <<'EOF'

### D-02

**Ruling.** A brand new fork, resolved on this branch.
EOF
  git -C "$SB_WORK" add requirements/DECISIONS.md >/dev/null 2>&1
  sbcommit -m "[Dev] $ida: add D-02" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/$ida-work" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" checkout "$SB_TRUNK" --quiet >/dev/null 2>&1

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-a" "$SB_WORK/scripts/finish-pr.sh" "$ida" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) a branch adding D-02 with 'forks: none' — finish-pr.sh exited 0"
  case "$out" in *D-02*) : ;; *) cf "(a) the refusal does not name D-02: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "progress/qa_complete/$ida-newreg.md" && cf "(a) the card advanced despite the refusal"
  grep -q 'refusal=forks-contradicted' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
    || cf "(a) no progress record carries refusal=forks-contradicted: $(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null)"

  # (b) THE CARD'S OWN ACTIVITY CITES '[decision: D-01]', absent from 'forks:'. No register
  #     change on this branch at all — the citation alone must be enough to refuse.
  local idb="$SB_PREFIX-622"
  seed_issue dev_complete "$idb" cites chore "Cites a decision in Activity" "feature/$idb-work"
  printf '%s\n' '- 2026-01-02 [Dev] Resolved per the existing ruling. [decision: D-01]' \
    >> "$SB_WORK/progress/dev_complete/$idb-cites.md"
  publish_sandbox
  seed_branch "$idb" work CHANGE622.txt

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-b" "$SB_WORK/scripts/finish-pr.sh" "$idb" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) an Activity citation of D-01 with 'forks: none' — finish-pr.sh exited 0"
  case "$out" in *D-01*) : ;; *) cf "(b) the refusal does not name D-01: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "CHANGE622.txt" && cf "(b) the branch was merged before the refusal"
  grep -q 'refusal=forks-contradicted' "$SB_TMP/rec-b"/*.tsv 2>/dev/null \
    || cf "(b) no progress record carries refusal=forks-contradicted: $(cat "$SB_TMP/rec-b"/*.tsv 2>/dev/null)"

  # (c) THE SAME CITATION, written WITHOUT the colon's space ('[decision:D-01]') — the form two
  #     readers (this check and arm [l]) could disagree on. Must still refuse: a citation this
  #     check cannot see is a citation 'forks: none' silently contradicts and never catches.
  local idc="$SB_PREFIX-623"
  seed_issue dev_complete "$idc" nospace chore "Cites a decision in Activity, no space after the colon" "feature/$idc-work"
  printf '%s\n' '- 2026-01-02 [Dev] Resolved per the existing ruling. [decision:D-01]' \
    >> "$SB_WORK/progress/dev_complete/$idc-nospace.md"
  publish_sandbox
  seed_branch "$idc" work CHANGE623.txt

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-c" "$SB_WORK/scripts/finish-pr.sh" "$idc" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(c) a no-space Activity citation '[decision:D-01]' with 'forks: none' — finish-pr.sh exited 0 (a citation this check cannot see never contradicts 'forks: none')"
  case "$out" in *D-01*) : ;; *) cf "(c) the refusal does not name D-01: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "CHANGE623.txt" && cf "(c) the branch was merged before the refusal"
  grep -q 'refusal=forks-contradicted' "$SB_TMP/rec-c"/*.tsv 2>/dev/null \
    || cf "(c) no progress record carries refusal=forks-contradicted: $(cat "$SB_TMP/rec-c"/*.tsv 2>/dev/null)"

  # (d) A UNICODE-DASH id ('[decision: D<en dash>01]') cites D-01 — the same fold arm [l] applies.
  local idd="$SB_PREFIX-624"
  seed_issue dev_complete "$idd" unidash chore "Cites a decision with an en dash in the id" "feature/$idd-work"
  printf '%s\n' "- 2026-01-02 [Dev] Resolved per the existing ruling. [decision: D$(printf '\xe2\x80\x93')01]" \
    >> "$SB_WORK/progress/dev_complete/$idd-unidash.md"
  publish_sandbox
  seed_branch "$idd" work CHANGE624.txt

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$idd" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(d) an en-dash citation '[decision: D–01]' with 'forks: none' — finish-pr.sh exited 0 (the reader did not fold the dash)"
  case "$out" in *D-01*) : ;; *) cf "(d) the refusal does not name D-01: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac

  finish "finish-pr.sh refuses a 'forks: none' the branch itself contradicts — a register D-NN entry its own diff adds, or an Activity '[decision: D-NN]' citation with or without the colon's space, or an en dash in the id — naming the id either way, with a refusal=forks-contradicted record"
  teardown
}

# =============================================================================
# CASE — THE GREEN PATHS: A CORRECT 'forks:' LANDS.
#
# (a) 'forks: [D-01]' on a branch whose Activity cites D-01 and adds no register entry: lands.
# (b) 'forks: none' on a branch with no register change and no citation: lands (the happy path
#     every other landing case already exercises with 'forks: none' via seed_issue — this leg
#     is the one that ALSO plants an untouched register file, so the derivation ran over a real
#     one rather than an absent file it skipped).
# =============================================================================
case_finish_pr_forks_correct_field_lands() {
  cf_reset
  make_sandbox
  _forks_seed_register "$SB_WORK/requirements/DECISIONS.md"
  publish_sandbox

  # (a) forks: [D-01], cited in Activity, no register change.
  local ida="$SB_PREFIX-631"
  seed_issue dev_complete "$ida" cited chore "Correctly declares its fork" "feature/$ida-work"
  sed -i.bak 's/^forks: none$/forks: [D-01]/' "$SB_WORK/progress/dev_complete/$ida-cited.md"
  rm -f "$SB_WORK/progress/dev_complete/$ida-cited.md.bak"
  printf '%s\n' '- 2026-01-02 [Dev] Resolved per the existing ruling. [decision: D-01]' \
    >> "$SB_WORK/progress/dev_complete/$ida-cited.md"
  publish_sandbox
  seed_branch "$ida" work CHANGE631.txt

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$ida" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) correct 'forks: [D-01]' — finish-pr.sh exited $rc: $(printf '%s' "$out" | tail -6 | tr '\n' '|')"
  origin_has_path "progress/qa_complete/$ida-cited.md" || cf "(a) the card did not advance to qa_complete/"
  origin_has_path "CHANGE631.txt" || cf "(a) the squash-merged change is not on the trunk"

  # (b) forks: none, no register change, no citation — the register FILE is present and
  #     untouched, so the derivation actually ran (not skipped for want of a file to diff).
  local idb="$SB_PREFIX-632"
  seed_issue dev_complete "$idb" clean chore "No fork on this branch" "feature/$idb-work"
  publish_sandbox
  seed_branch "$idb" work CHANGE632.txt

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$idb" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) correct 'forks: none' — finish-pr.sh exited $rc: $(printf '%s' "$out" | tail -6 | tr '\n' '|')"
  origin_has_path "progress/qa_complete/$idb-clean.md" || cf "(b) the card did not advance to qa_complete/"
  origin_has_path "CHANGE632.txt" || cf "(b) the squash-merged change is not on the trunk"

  finish "finish-pr.sh lands a card whose 'forks:' is 'none' or names exactly what the branch shows (a register entry cited by id, or nothing changed and nothing cited) — the field is not merely present, it must be CORRECT"
  teardown
}

# =============================================================================
# CASE — THE REGISTER SET IS DERIVED FROM check-board.sh's OWN DECLARATION, NEVER A HARD-CODED
# PATH.
#
# A project that declares its register somewhere other than requirements/DECISIONS.md (arm [l]'s
# own REGISTERS= line, relocated) must still be caught: a branch that adds a D-NN THERE, under a
# 'forks: none' card, refuses forks-contradicted — the same as the default path would. RED FIRST:
# fails on any finish-pr.sh that hard-codes requirements/DECISIONS.md instead of reading
# check-board.sh's REGISTERS=.
# =============================================================================
case_finish_pr_forks_derives_a_relocated_register() {
  cf_reset
  make_sandbox
  # Relocate the register: a different path, still the D- shape check-board.sh's own arm [l]
  # would resolve citations against.
  _neu_scalar "$SB_WORK/scripts/check-board.sh" REGISTERS \
    "REGISTERS='requirements/RULINGS.md|### |D-[0-9]+'"
  _forks_seed_register "$SB_WORK/requirements/RULINGS.md"
  publish_sandbox

  local id="$SB_PREFIX-641"
  seed_issue dev_complete "$id" relocated chore "Register declared elsewhere" "feature/$id-work"
  publish_sandbox
  git -C "$SB_WORK" branch "feature/$id-work" "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" checkout -q "feature/$id-work" >/dev/null 2>&1
  cat >> "$SB_WORK/requirements/RULINGS.md" <<'EOF'

### D-02

**Ruling.** A fork resolved on this branch, in the RELOCATED register.
EOF
  git -C "$SB_WORK" add requirements/RULINGS.md >/dev/null 2>&1
  sbcommit -m "[Dev] $id: add D-02 to RULINGS.md" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/$id-work" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" checkout "$SB_TRUNK" --quiet >/dev/null 2>&1

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "a branch adding D-02 to the RELOCATED register with 'forks: none' — finish-pr.sh exited 0"
  case "$out" in *D-02*) : ;; *) cf "the refusal does not name D-02: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "progress/qa_complete/$id-relocated.md" && cf "the card advanced despite the refusal"
  grep -q 'refusal=forks-contradicted' "$SB_TMP/rec"/*.tsv 2>/dev/null \
    || cf "no progress record carries refusal=forks-contradicted: $(cat "$SB_TMP/rec"/*.tsv 2>/dev/null)"

  finish "finish-pr.sh derives the register set from check-board.sh's own REGISTERS= declaration — a project whose register lives somewhere other than requirements/DECISIONS.md is still caught when its branch adds a D-NN there under a 'forks: none' card"
  teardown
}

# =============================================================================
# CASE — THE MOVE TO dev_complete RUNS THE LANDING'S forks: CHECK, so Dev meets the refusal at
# hand-off, not QA at the landing. Built in the real order: the card sits in in_progress/ on the
# trunk, the branch is cut from the trunk with the code, and only then does Dev move the card.
#   (a) a card citing '[decision: D-01]' that says 'forks: none' is refused, naming D-01 with a
#       Next: line and a refusal=forks-contradicted record, and stays in in_progress/ on the
#       trunk; with 'forks: [D-01]' the same move lands the card in dev_complete/;
#   (b) a branch whose diff adds D-02 under 'forks: none' is refused naming D-02 (the branch's
#       own diff is read, not only the card), and moves once 'forks:' names it;
#   (c) CONTROL: a card with no branch of its own and 'forks: none' still moves, and the move
#       says the branch diff was not read.
# RED FIRST: every refusal row fails on a move-issue.sh that does not run kit_forks_check.
# =============================================================================
case_move_issue_dev_complete_runs_the_forks_check() {
  cf_reset
  make_sandbox
  _forks_seed_register "$SB_WORK/requirements/DECISIONS.md"
  local ida="$SB_PREFIX-831" idb="$SB_PREFIX-832" idc="$SB_PREFIX-833" out rc

  seed_issue in_progress "$ida" cites chore "Cites a decision, says forks none" "feature/$ida-work"
  printf '%s\n' '- 2026-01-02 [Dev] Resolved per the existing ruling. [decision: D-01]' \
    >> "$SB_WORK/progress/in_progress/$ida-cites.md"
  seed_issue in_progress "$idb" newreg chore "Adds a register entry, says forks none" "feature/$idb-work"
  seed_issue in_progress "$idc" nobranch chore "No branch of its own, says forks none"
  publish_sandbox
  seed_branch "$ida" work CHANGE831.txt
  git -C "$SB_WORK" checkout -q -b "feature/$idb-work" "$SB_TRUNK" >/dev/null 2>&1
  cat >> "$SB_WORK/requirements/DECISIONS.md" <<'EOF'

### D-02

**Ruling.** A brand new fork, resolved on this branch.
EOF
  git -C "$SB_WORK" add requirements/DECISIONS.md >/dev/null 2>&1
  sbcommit -m "[Dev] $idb: add D-02" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q -u origin "feature/$idb-work" >/dev/null 2>&1
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1

  # (a) the citation contradicts 'forks: none'.
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-a" ./scripts/move-issue.sh "$ida" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) 'forks: none' on a card citing [decision: D-01] moved to dev_complete (exit 0)"
  case "$out" in *D-01*) : ;; *) cf "(a) the refusal does not name D-01: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  case "$out" in *"Next:"*) : ;; *) cf "(a) the refusal carries no Next: line: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "progress/dev_complete/$ida-cites.md" && cf "(a) the card reached dev_complete/ despite the refusal"
  origin_has_path "progress/in_progress/$ida-cites.md" || cf "(a) the card is no longer in in_progress/ on the trunk"
  grep -q 'refusal=forks-contradicted' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
    || cf "(a) no progress record carries refusal=forks-contradicted: $(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null)"
  sed -i.bak 's/^forks: none$/forks: [D-01]/' "$SB_WORK/progress/in_progress/$ida-cites.md"
  rm -f "$SB_WORK/progress/in_progress/$ida-cites.md.bak"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[Dev] $ida: name the fork" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$ida" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) with 'forks: [D-01]' the move exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/dev_complete/$ida-cites.md" || cf "(a) with 'forks: [D-01]' the card did not reach dev_complete/"

  # (b) the branch's own diff adds D-02.
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$idb" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) a branch adding D-02 under 'forks: none' moved to dev_complete (exit 0)"
  case "$out" in *D-02*) : ;; *) cf "(b) the refusal does not name D-02: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "progress/dev_complete/$idb-newreg.md" && cf "(b) the card reached dev_complete/ despite the refusal"
  sed -i.bak 's/^forks: none$/forks: [D-02]/' "$SB_WORK/progress/in_progress/$idb-newreg.md"
  rm -f "$SB_WORK/progress/in_progress/$idb-newreg.md.bak"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[Dev] $idb: name the fork" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$idb" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) with 'forks: [D-02]' the move exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/dev_complete/$idb-newreg.md" || cf "(b) with 'forks: [D-02]' the card did not reach dev_complete/"

  # (c) control: no branch of its own.
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$idc" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(c) a card with no branch and 'forks: none' did not move (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  case "$out" in *"read no branch diff"*) : ;; *) cf "(c) the move does not say the branch diff was not read: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  case "$out" in *"FORKS_ATTRIBUTION_CHECK: did not run"*) : ;; *) cf "(c) a card with no todo/ history does not say the register window did not run: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  origin_has_path "progress/dev_complete/$idc-nobranch.md" || cf "(c) the card did not reach dev_complete/"

  finish "move-issue.sh to dev_complete runs the landing's forks: check: a card citing [decision: D-01] under 'forks: none' and a branch adding D-02 under 'forks: none' are refused with a Next: line and a refusal=forks-contradicted record, stay in in_progress/, and move once 'forks:' names the id; a card with no branch still moves and says the diff was not read"
  teardown
}

# _forks_sync — bring the work checkout's trunk up to the remote's (a board move pushes from its own
# worktree, so the checkout is behind after one).
_forks_sync() {
  git -C "$SB_WORK" pull --ff-only --quiet >/dev/null 2>&1 \
    || _fixture_die "_forks_sync: the work checkout could not fast-forward to the remote's trunk"
}

# _forks_add_entry <id> <Provenance text> <commit subject> — a three-field register entry inserted
# before '## Retired ids' and committed to the TRUNK and published, as the pre-commit hook requires
# of a metadata-only commit (a register entry is not code).
_forks_add_entry() {
  local id="$1" prov="$2" subject="$3" reg="$SB_WORK/requirements/DECISIONS.md"
  _forks_sync
  printf '### %s\n\n**Ruling.** A ruling for %s.\n\n**Why.** The sandbox needs one.\n\n**Provenance.** %s\n\n' \
    "$id" "$id" "$prov" > "$SB_TMP/entry.blk"
  awk -v f="$SB_TMP/entry.blk" '/^## Retired ids/ && !d { while ((getline l < f) > 0) print l; d=1 } { print }' "$reg" > "$reg.new" \
    && mv "$reg.new" "$reg"
  grep -qx "### ${id}" "$reg" || _fixture_die "_forks_add_entry: ${id} was not inserted"
  git -C "$SB_WORK" add requirements/DECISIONS.md >/dev/null 2>&1
  sbcommit -m "$subject" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 \
    || _fixture_die "_forks_add_entry: ${id}'s commit was not published"
}

# _forks_pickup <id> <slug> — the real pickup: the card leaves todo/ through the mover, which is the
# commit the register window starts from.
_forks_pickup() {
  ( cd "$SB_WORK" && ./scripts/move-issue.sh "$1" in_progress --role Dev --note "picked up" >/dev/null 2>&1 ) \
    || _fixture_die "_forks_pickup: ${1}'s move to in_progress failed"
  _forks_sync
}

# _forks_set_forks <id> <slug> <value> — the card's trunk copy, committed and published.
_forks_set_forks() {
  local f="$SB_WORK/progress/in_progress/$1-$2.md"
  _forks_sync
  sed -i.bak "s/^forks: .*$/forks: $3/" "$f" && rm -f "$f.bak"
  git -C "$SB_WORK" add "progress/in_progress/$1-$2.md" >/dev/null 2>&1
  sbcommit -m "[Dev] $1: name the forks" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "_forks_set_forks: not published"
}

# =============================================================================
# CASE — THE forks: CHECK ATTRIBUTES THE REGISTER ENTRIES THE TRUNK HOLDS TO THE CARD, IN THE REAL
# ORDER: the entry is committed to the trunk and published BEFORE the branch is cut, so the branch
# diff never shows it; the card's citation sits on the branch only.
#   (a) 'forks: none' + an entry whose Provenance names the card: refused naming the id; with
#       'forks: [D-NN]' it moves;
#   (b) another card's entry only (Provenance names another card): nothing is forced;
#   (c) another card's entry beside this card's own: only the own id is forced;
#   (d) an unattributed entry (a bare Provenance, a bare commit subject): refused with
#       forks-attribution-unclear and a Next: naming both exits; 'forks: [D-NN]' moves it;
#   (e) the other exit: naming the owning card in the entry's Provenance, through a commit whose
#       subject names THIS card, clears it, because Provenance is read first; an owner that is a
#       card on the trunk (the cases seed it), never an id that names none;
#   (f) the landing's window ends at the commit that moved the card to dev_complete/: an
#       unattributed entry another card registers while this one waits for QA does not refuse it;
#   (g) ids match exactly: an entry whose Provenance names the card's SLICE is the slice's, not
#       the parent card's.
# RED FIRST: (a), (c), (d) fail on a check that reads only the branch diff and the card.
# =============================================================================
case_move_issue_forks_check_attributes_the_trunk_register() {
  cf_reset
  make_sandbox
  _forks_seed_register "$SB_WORK/requirements/DECISIONS.md"
  local ida="$SB_PREFIX-871" idb="$SB_PREFIX-872" idc="$SB_PREFIX-873" idd="$SB_PREFIX-874" ide="$SB_PREFIX-875" idf="$SB_PREFIX-876" idg="$SB_PREFIX-877"
  local other="$SB_PREFIX-879" out rc f
  seed_issue todo "$ida" own chore "Its entry is on the trunk first" "feature/$ida-work"
  seed_issue todo "$idb" foreign chore "Only another card's entry is in its window" "feature/$idb-work"
  seed_issue todo "$idc" mixed chore "Another card's entry and its own" "feature/$idc-work"
  seed_issue todo "$idd" bare chore "An entry nothing attributes" "feature/$idd-work"
  seed_issue todo "$ide" landing chore "Lands after another card registers a bare entry" "feature/$ide-work"
  seed_issue todo "$idf" reattr chore "Attributes the bare entry to its owner" "feature/$idf-work"
  seed_issue todo "$idg" parent chore "Its slice owns the entry" "feature/$idg-work"
  seed_issue todo "$other" owner chore "Owns the entries that name it" "feature/$other-work"
  mkdir -p "$SB_WORK/progress/subtasks/$idg/todo"
  seed_issue "subtasks/$idg/todo" "$idg-s1" slice chore "The parent's slice" "feature/$idg-s1-work"
  publish_sandbox

  # (a) the entry's Provenance names the card; the commit that adds it is on the trunk, published,
  #     and only then is the branch cut; the citation is written on the branch's copy of the card.
  _forks_pickup "$ida" own
  _forks_add_entry D-02 "Product owner message, 2026-10-16; $ida." "[PM] record the owner's ruling"
  seed_branch "$ida" work CHANGE871.txt
  git -C "$SB_WORK" checkout -q "feature/$ida-work" >/dev/null 2>&1
  printf '%s\n' '- 2026-10-16 [Dev] Built to the ruling. [decision: D-02]' >> "$SB_WORK/progress/in_progress/$ida-own.md"
  git -C "$SB_WORK" add "progress/in_progress/$ida-own.md" >/dev/null 2>&1
  sbcommit -m "[Dev] $ida: cite D-02 on the card" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "feature/$ida-work" >/dev/null 2>&1
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-a" ./scripts/move-issue.sh "$ida" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) 'forks: none' over an entry already on the trunk whose Provenance names the card moved to dev_complete (exit 0)"
  case "$out" in *"does not name: D-02"*) : ;; *) cf "(a) the refusal does not name D-02: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  case "$out" in *"Next:"*) : ;; *) cf "(a) the refusal carries no Next: line" ;; esac
  case "$out" in *"ran over"*"the trunk tip"*) : ;; *) cf "(a) the hand-off does not say which bound the register window used: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  origin_has_path "progress/dev_complete/$ida-own.md" && cf "(a) the card reached dev_complete/ despite the refusal"
  grep -q 'refusal=forks-contradicted' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
    || cf "(a) no progress record carries refusal=forks-contradicted: $(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null)"
  _forks_set_forks "$ida" own "[D-02]"
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$ida" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) with 'forks: [D-02]' the move exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/dev_complete/$ida-own.md" || cf "(a) with 'forks: [D-02]' the card did not reach dev_complete/"
  _forks_sync

  # (b) another card's entry only: its Provenance names $other, so nothing is forced on this card.
  _forks_pickup "$idb" foreign
  _forks_add_entry D-03 "Product owner message, 2026-10-16; $other." "[PM] $other: record D-03"
  seed_branch "$idb" work CHANGE872.txt
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$idb" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) another card's entry in the window forced 'forks:' on this card (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/dev_complete/$idb-foreign.md" || cf "(b) the card did not reach dev_complete/"
  _forks_sync

  # (c) another card's D-04 and this card's own D-05 in one window: only D-05 is forced.
  _forks_pickup "$idc" mixed
  _forks_add_entry D-04 "Product owner message, 2026-10-16; $other." "[PM] $other: record D-04"
  _forks_add_entry D-05 "Product owner message, 2026-10-16; $idc." "[PM] $idc: record D-05"
  seed_branch "$idc" work CHANGE873.txt
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$idc" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(c) 'forks: none' over this card's own entry beside another card's moved to dev_complete (exit 0)"
  case "$out" in *"does not name: D-05"*) : ;; *) cf "(c) the refusal does not name exactly D-05: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  _forks_set_forks "$idc" mixed "[D-05]"
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$idc" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(c) with 'forks: [D-05]' the move exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  _forks_sync

  # (d) an entry no work-item id attributes: refused, with both exits named; 'forks:' naming it moves.
  _forks_pickup "$idd" bare
  _forks_add_entry D-06 "Product owner message, 2026-10-16." "[PM] record the owner's ruling"
  seed_branch "$idd" work CHANGE874.txt
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-d" ./scripts/move-issue.sh "$idd" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(d) an unattributed entry in the window moved to dev_complete (exit 0)"
  case "$out" in *D-06*) : ;; *) cf "(d) the refusal does not name D-06: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  case "$out" in *"Next:"*"'forks:'"*"Provenance"*"register-commit.sh"*) : ;; *) cf "(d) the Next: line does not name both exits (forks:, and Provenance through register-commit.sh): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-500)" ;; esac
  grep -q 'refusal=forks-attribution-unclear' "$SB_TMP/rec-d"/*.tsv 2>/dev/null \
    || cf "(d) no progress record carries refusal=forks-attribution-unclear: $(cat "$SB_TMP/rec-d"/*.tsv 2>/dev/null)"
  origin_has_path "progress/dev_complete/$idd-bare.md" && cf "(d) the card reached dev_complete/ despite the refusal"
  _forks_set_forks "$idd" bare "[D-06]"
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$idd" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(d) with 'forks: [D-06]' the move exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  _forks_sync

  # (e) the other exit: the owner is named in the Provenance, by a commit whose subject names THIS
  #     card. Provenance is read first, so that subject does not pull the entry back in.
  _forks_pickup "$idf" reattr
  _forks_add_entry D-07 "Product owner message, 2026-10-16." "[PM] record the owner's ruling"
  seed_branch "$idf" work CHANGE876.txt
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$idf" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(e) the unattributed D-07 did not refuse before it was attributed (exit 0)"
  _forks_sync
  sed -i.bak "s/^\\(\\*\\*Provenance\\.\\*\\* Product owner message, 2026-10-16\\.\\)\$/\\1 Owned by $other./" "$SB_WORK/requirements/DECISIONS.md" \
    && rm -f "$SB_WORK/requirements/DECISIONS.md.bak"
  grep -q "Owned by $other" "$SB_WORK/requirements/DECISIONS.md" || _fixture_die "case_move_issue_forks_check_attributes_the_trunk_register: (e) the Provenance edit was not planted"
  git -C "$SB_WORK" add requirements/DECISIONS.md >/dev/null 2>&1
  sbcommit -m "[PM] $idf: attribute D-07 to $other" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$idf" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(e) naming the owner in the Provenance did not clear the refusal (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"
  _forks_sync

  # (f) the landing: this card's window ends at the commit that moved it to dev_complete/, so a
  #     bare entry registered afterwards (another card's, while this one waits for QA) is outside it.
  _forks_pickup "$ide" landing
  f="$SB_WORK/progress/in_progress/$ide-landing.md"
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  _forks_add_entry D-08 "Product owner message, 2026-10-16; $ide." "[PM] $ide: record D-08"
  seed_branch "$ide" work CHANGE875.txt
  _forks_set_forks "$ide" landing "[D-08]"
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$ide" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(f) the hand-off exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  _forks_sync
  _forks_add_entry D-09 "Product owner message, 2026-10-16." "[PM] record the owner's ruling"
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$ide" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(f) an unattributed entry registered after the hand-off refused the landing (exit $rc): $(printf '%s' "$out" | tail -8 | tr '\n' '|')"
  case "$out" in *"ran over"*"moved the card to dev_complete/"*) : ;; *) cf "(f) the landing does not say its window ended at the dev_complete move: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)" ;; esac
  origin_has_path "progress/qa_complete/$ide-landing.md" || cf "(f) the card did not advance to qa_complete/"

  # (g) the entry belongs to a slice of this card: a slice id is not its parent.
  _forks_pickup "$idg" parent
  _forks_add_entry D-10 "Product owner message, 2026-10-16; $idg-s1." "[PM] $idg-s1: record D-10"
  seed_branch "$idg" work CHANGE877.txt
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$idg" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(g) an entry owned by the card's slice $idg-s1 was attributed to the parent (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"

  finish "the forks: check attributes the trunk's register entries to the card in the real order (entry published before the branch is cut): an entry whose Provenance names the card is refused under 'forks: none' and moves under 'forks: [D-NN]'; another card's entry forces nothing and sits beside this card's own without forcing it; an entry nothing attributes is refused with forks-attribution-unclear and a Next: naming both exits, and naming its owner in the Provenance clears it; the landing's window ends at the dev_complete move; a slice's entry is not its parent's"
  teardown
}

# =============================================================================
# CASE — A RULING WRITTEN STRAIGHT INTO AN AC, AFTER THE CARD LEFT 'progress/todo/', WITH NO
# '[decision: D-NN]' CITATION ANYWHERE ON THE CARD, REFUSES — even though nothing touched the
# register and 'forks:' is syntactically fine. A pure separator reformat of the same AC (no
# wording change) is the CONTROL and must still land.
# =============================================================================
case_finish_pr_forks_ac_changed_after_todo_uncited_refuses() {
  cf_reset

  # (a) THE PLANT: minted into todo/, moved to in_progress/ (the recorded "left todo" commit,
  #     via move-issue.sh — its own worktree, .kanban-wt/, is why (a) and (b) each get their OWN
  #     sandbox: a second publish_sandbox's 'git add -A' would commit that untracked worktree).
  make_sandbox work-a
  _forks_seed_register "$SB_WORK/requirements/DECISIONS.md"
  local ida="$SB_PREFIX-681"
  seed_issue todo "$ida" drift chore "AC changed after todo, no citation" "feature/$ida-work"
  publish_sandbox
  ( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$ida" in_progress --role Dev \
    --note "picked up" >/dev/null 2>&1 ) \
    || _fixture_die "case_finish_pr_forks_ac_changed_after_todo_uncited_refuses: (a) move to in_progress failed"
  git -C "$SB_WORK" push --quiet >/dev/null 2>&1
  # THE REALISTIC ORDER: the branch is cut HERE, right after pickup — BEFORE the AC edit and
  # BEFORE the in_progress -> dev_complete move, both of which still happen on the TRUNK (as
  # move-issue.sh always commits them, inside its own kanban worktree, pushed straight to the
  # trunk — never onto this branch). A branch cut AFTER those moves would carry them too, which
  # is not what an ordinary Dev/QA journey does and would hide a check that reads the wrong rev.
  seed_branch "$ida" work CHANGE681.txt
  local fa="$SB_WORK/progress/in_progress/$ida-drift.md"
  # Anchored to the CHECKLIST BULLET'S OWN line (^...$), never the QA Verdict row that quotes
  # this text verbatim: a plain substitution would edit both, and the quote must keep matching
  # the BRANCH's frozen (unedited) line — this edit is trunk-only, after the branch was cut.
  perl -i -pe 's/^(- \[ \] AC1 — the sandbox.s seeded behaviour holds\.)$/- [ ] AC1 — the sandbox'"'"'s seeded behaviour holds, per a ruling folded straight into this line./' "$fa"
  grep -qF 'folded straight into this line' "$fa" \
    || _fixture_die "case_finish_pr_forks_ac_changed_after_todo_uncited_refuses: (a) the AC rewrite was not planted"
  git -C "$SB_WORK" add "progress/in_progress/$ida-drift.md" >/dev/null 2>&1
  sbcommit -m "[PM] ${ida}: amend AC1 with a ruling, no decision citation" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push --quiet >/dev/null 2>&1
  mkdir -p "$SB_WORK/progress/dev_complete"
  git -C "$SB_WORK" mv "progress/in_progress/$ida-drift.md" "progress/dev_complete/$ida-drift.md" >/dev/null 2>&1
  sbcommit -m "[Dev] ${ida}: ready for review" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push --quiet >/dev/null 2>&1

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-a" "$SB_WORK/scripts/finish-pr.sh" "$ida" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) AC1 changed after leaving todo/, no citation — finish-pr.sh exited 0"
  case "$out" in *AC1*) : ;; *) cf "(a) the refusal does not name AC1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  origin_has_path "progress/qa_complete/$ida-drift.md" && cf "(a) the card advanced despite the refusal"
  grep -q 'refusal=forks-ac-changed-uncited' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
    || cf "(a) no progress record carries refusal=forks-ac-changed-uncited: $(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null)"
  teardown

  # (b) THE CONTROL: the SAME journey, in its own fresh sandbox, but the only edit after leaving
  #     todo/ is a separator reformat (em-dash -> hyphen) of the identical wording — no ruling,
  #     no text change. Must land clean. NO cf_reset here: (a)'s failures, if any, must survive
  #     into the one 'finish' call below, not be silently cleared by starting part (b).
  make_sandbox work-b
  _forks_seed_register "$SB_WORK/requirements/DECISIONS.md"
  local idb="$SB_PREFIX-682"
  seed_issue todo "$idb" reformat chore "AC separator reformat only after todo" "feature/$idb-work"
  publish_sandbox
  ( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$idb" in_progress --role Dev \
    --note "picked up" >/dev/null 2>&1 ) \
    || _fixture_die "case_finish_pr_forks_ac_changed_after_todo_uncited_refuses: (b) move to in_progress failed"
  # Same realistic order as (a): the branch is cut right after pickup, before the reformat and the
  # dev_complete move, both of which still happen on the trunk.
  git -C "$SB_WORK" push --quiet >/dev/null 2>&1
  seed_branch "$idb" work CHANGE682.txt
  local fb="$SB_WORK/progress/in_progress/$idb-reformat.md"
  # Anchored the same way as (a): the checklist bullet's own line only, never the QA Verdict
  # row's quote, which must keep matching the branch's frozen (unedited, em-dash) line.
  perl -i -pe "s/^(- \[ \] AC1 — the sandbox.s seeded behaviour holds\.)\$/- [ ] AC1 - the sandbox's seeded behaviour holds./" "$fb"
  grep -qF "AC1 - the sandbox's seeded behaviour holds." "$fb" \
    || _fixture_die "case_finish_pr_forks_ac_changed_after_todo_uncited_refuses: (b) the separator reformat was not planted"
  git -C "$SB_WORK" add "progress/in_progress/$idb-reformat.md" >/dev/null 2>&1
  sbcommit -m "[PM] ${idb}: AC1 separator reformat only" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push --quiet >/dev/null 2>&1
  mkdir -p "$SB_WORK/progress/dev_complete"
  git -C "$SB_WORK" mv "progress/in_progress/$idb-reformat.md" "progress/dev_complete/$idb-reformat.md" >/dev/null 2>&1
  sbcommit -m "[Dev] ${idb}: ready for review" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push --quiet >/dev/null 2>&1

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$idb" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b, control) a separator-only AC reformat after todo/ — finish-pr.sh exited $rc: $(printf '%s' "$out" | tail -8 | tr '\n' '|')"
  origin_has_path "progress/qa_complete/$idb-reformat.md" || cf "(b, control) the card did not advance to qa_complete/"

  # (c) THE SAME AC REWRITE AS (a), but the changed bullet itself carries a '[decision:D-01]'
  #     citation (no space after the colon). Must land clean: the citation is real and must be
  #     SEEN on the bullet, not silently missed because of its spacing.
  make_sandbox work-c
  _forks_seed_register "$SB_WORK/requirements/DECISIONS.md"
  local idcc="$SB_PREFIX-685"
  seed_issue todo "$idcc" nospace chore "AC changed after todo, cited with no space" "feature/$idcc-work"
  publish_sandbox
  ( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$idcc" in_progress --role Dev \
    --note "picked up" >/dev/null 2>&1 ) \
    || _fixture_die "case_finish_pr_forks_ac_changed_after_todo_uncited_refuses: (c) move to in_progress failed"
  git -C "$SB_WORK" push --quiet >/dev/null 2>&1
  seed_branch "$idcc" work CHANGE685.txt
  local fc="$SB_WORK/progress/in_progress/$idcc-nospace.md"
  perl -i -pe "s/^(- \[ \] AC1 — the sandbox.s seeded behaviour holds\.)\$/- [ ] AC1 — the sandbox's seeded behaviour holds, per a ruling cited with no space after the colon [decision:D-01]./" "$fc"
  grep -qF 'cited with no space after the colon' "$fc" \
    || _fixture_die "case_finish_pr_forks_ac_changed_after_todo_uncited_refuses: (c) the AC rewrite was not planted"
  # 'forks:' names the cited id, so the contradicted check is satisfied and only the AC-drift
  # check's own reading of the citation decides.
  sed -i.bak 's/^forks: none$/forks: [D-01]/' "$fc" && rm -f "$fc.bak"
  grep -qF 'colon [decision:D-01].' "$fc" \
    || _fixture_die "case_finish_pr_forks_ac_changed_after_todo_uncited_refuses: (c) the no-space citation was not planted"
  git -C "$SB_WORK" add "progress/in_progress/$idcc-nospace.md" >/dev/null 2>&1
  sbcommit -m "[PM] ${idcc}: amend AC1 with a ruling, cited with no space" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push --quiet >/dev/null 2>&1
  mkdir -p "$SB_WORK/progress/dev_complete"
  git -C "$SB_WORK" mv "progress/in_progress/$idcc-nospace.md" "progress/dev_complete/$idcc-nospace.md" >/dev/null 2>&1
  sbcommit -m "[Dev] ${idcc}: ready for review" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push --quiet >/dev/null 2>&1

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$idcc" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(c) AC1 changed after todo/, cited '[decision:D-01]' with no space — finish-pr.sh exited $rc (a real no-space citation must be seen, not missed): $(printf '%s' "$out" | tail -8 | tr '\n' '|')"
  origin_has_path "progress/qa_complete/$idcc-nospace.md" || cf "(c) the card did not advance to qa_complete/ despite a real (no-space) citation"

  finish "finish-pr.sh refuses a landing whose AC text changed after the card left progress/todo/ with no '[decision: D-NN]' citation on the changed bullet (refusal=forks-ac-changed-uncited, naming the AC id); a pure separator reformat of the same wording is NOT drift and lands clean; a REAL citation written '[decision:D-NN]' with no space on the changed bullet also lands clean — the AC-drift check reads the same shared, spacing-tolerant reader as the forks-contradicted check"
  teardown
}

# _forks_drift_land <sandbox> <id> <slug> <ac2:0|1> <new-AC1-bullet> <extra-activity-line> <forks-value> [finish|move]
# The real journey for an AC rewritten after pickup, in the kit's own order: minted into todo/ (with a
# second AC that already cites [decision: D-01] when <ac2> is 1), moved out by the mover, the branch
# cut, AC1's bullet then rewritten on the trunk, then the landing: the card moved to dev_complete/ by
# hand and finish-pr.sh run (the default, <caller> finish), or `move-issue.sh dev_complete` run (move).
# Leaves the run in _FDL_OUT/_FDL_RC and the progress records in $SB_TMP/rec.
_forks_drift_land() {
  local sb="$1" id="$2" slug="$3" ac2="$4" newac="$5" extra="$6" forksv="$7" caller="${8:-finish}"
  local rel f
  make_sandbox "$sb"
  [ -z "${_FDL_HOOK:-}" ] || "$_FDL_HOOK"
  _forks_seed_register "$SB_WORK/requirements/DECISIONS.md"
  seed_issue todo "$id" "$slug" chore "AC rewritten after pickup" "feature/$id-work"
  f="$SB_WORK/progress/todo/$id-$slug.md"
  if [ -n "${_FDL_TODO_CONT:-}" ]; then
    CONT="$_FDL_TODO_CONT" perl -i -pe 'BEGIN { $c = $ENV{CONT} } s/^(- \[ \] AC1 — .*)$/$1\n$c/' "$f"
    grep -qF -- "$_FDL_TODO_CONT" "$f" || _fixture_die "_forks_drift_land: the todo/ continuation line was not planted"
  fi
  if [ "$ac2" = 1 ]; then
    perl -i -pe 's/^(- \[ \] AC1 — .*)$/$1\n- [ ] AC2 — the second seeded behaviour holds, per [decision: D-01]./' "$f"
    grep -qF 'AC2 — the second seeded behaviour holds, per [decision: D-01].' "$f" \
      || _fixture_die "_forks_drift_land: the AC2 bullet was not planted"
  fi
  publish_sandbox
  _forks_pickup "$id" "$slug"
  rel="progress/in_progress/$id-$slug.md"
  f="$SB_WORK/$rel"
  if [ "$ac2" = 1 ]; then
    perl -i -pe 's/^(\| AC1 \|.*)$/$1\n| AC2 | PASS | test | ARCHIVE.md:1 "condensed index of completed issues" |/' "$f"
    git -C "$SB_WORK" add "$rel" >/dev/null 2>&1
    sbcommit -m "[PM] ${id}: add the AC2 row to the QA Verdict table" --quiet >/dev/null 2>&1
  fi
  git -C "$SB_WORK" push --quiet >/dev/null 2>&1
  seed_branch "$id" work "CHANGE-$id.txt"
  NEWAC="$newac" perl -i -pe 'BEGIN { $n = $ENV{NEWAC} } s/^- \[ \] AC1 — the sandbox.s seeded behaviour holds\.$/$n/' "$f"
  grep -qF -- "$(printf '%s' "$newac" | head -1)" "$f" \
    || _fixture_die "_forks_drift_land: the AC1 rewrite was not planted"
  if [ -n "${_FDL_AC2_CONT:-}" ]; then
    CONT="$_FDL_AC2_CONT" perl -i -pe 'BEGIN { $c = $ENV{CONT} } $_ .= "$c\n" if /^- \[ \] AC2 — /' "$f"
    grep -qF -- "$_FDL_AC2_CONT" "$f" || _fixture_die "_forks_drift_land: the AC2 continuation line was not planted"
  fi
  [ -z "$extra" ] || printf '%s\n' "$extra" >> "$f"
  sed -i.bak "s/^forks: .*\$/forks: $forksv/" "$f" && rm -f "$f.bak"
  git -C "$SB_WORK" add "$rel" >/dev/null 2>&1
  sbcommit -m "[PM] ${id}: rewrite AC1" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push --quiet >/dev/null 2>&1
  if [ "$caller" = move ]; then
    _FDL_OUT="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec" ./scripts/move-issue.sh "$id" dev_complete --role Dev --note ready 2>&1 )"; _FDL_RC=$?
    return 0
  fi
  mkdir -p "$SB_WORK/progress/dev_complete"
  git -C "$SB_WORK" mv "$rel" "progress/dev_complete/$id-$slug.md" >/dev/null 2>&1
  sbcommit -m "[Dev] ${id}: ready for review" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push --quiet >/dev/null 2>&1
  _FDL_OUT="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; _FDL_RC=$?
}

# =============================================================================
# CASE — THE '[decision: D-NN]' CITATION THAT ANSWERS A CHANGED AC BULLET IS ON THAT BULLET.
# A citation elsewhere on the card — in another AC, in the Activity — does not satisfy it, so the
# check can fire on a card that already cites a ruling. The control (the same edit with the
# citation on the changed bullet) lands; a citation on a continuation line below the bullet is not
# on the bullet.
# RED FIRST: fails while any citation anywhere on the card satisfies the check.
# =============================================================================
case_finish_pr_forks_ac_drift_citation_binds_to_the_bullet() {
  cf_reset
  local id out rc

  # (a) the card already cites D-01 on AC2; AC1 gains new text with no citation on AC1.
  id="$SB_PREFIX-688"
  _forks_drift_land work-a "$id" other-ac 1 \
    "- [ ] AC1 — the sandbox's seeded behaviour holds, and now a second condition does too." "" "none"
  [ "$_FDL_RC" -ne 0 ] || cf "(a) AC1 changed with a citation only on AC2 — finish-pr.sh exited 0"
  case "$_FDL_OUT" in *forks-ac-changed-uncited*|*"AC text changed"*) : ;; *) cf "(a) the refusal is not the AC-drift one: $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-300)" ;; esac
  case "$_FDL_OUT" in *"citation of its own: AC1"*) : ;; *) cf "(a) the refusal does not name AC1 as the uncited bullet: $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-300)" ;; esac
  case "$_FDL_OUT" in *"Next:"*"AC1"*"[decision: D-NN]"*) : ;; *) cf "(a) the Next: line does not tell the author to cite the ruling on AC1: $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-400)" ;; esac
  origin_has_path "progress/qa_complete/$id-other-ac.md" && cf "(a) the card advanced despite the refusal"
  grep -q 'refusal=forks-ac-changed-uncited' "$SB_TMP/rec"/*.tsv 2>/dev/null \
    || cf "(a) no progress record carries refusal=forks-ac-changed-uncited"
  teardown

  # (b) an unrelated '[decision: D-01]' is appended to the Activity, and 'forks:' names it.
  id="$SB_PREFIX-689"
  _forks_drift_land work-b "$id" activity 0 \
    "- [ ] AC1 — the sandbox's seeded behaviour holds, per a ruling folded into this line." \
    "- 2026-01-02 [PM] Unrelated note. [decision: D-01]" "[D-01]"
  [ "$_FDL_RC" -ne 0 ] || cf "(b) AC1 changed with a citation only in the Activity — finish-pr.sh exited 0"
  case "$_FDL_OUT" in *"citation of its own: AC1"*) : ;; *) cf "(b) the refusal does not name AC1: $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-300)" ;; esac
  origin_has_path "progress/qa_complete/$id-activity.md" && cf "(b) the card advanced despite the refusal"
  teardown

  # (c) THE CONTROL: the same edit, the citation on the changed bullet.
  id="$SB_PREFIX-800"
  _forks_drift_land work-c "$id" onbullet 1 \
    "- [ ] AC1 — the sandbox's seeded behaviour holds, and now a second condition does too [decision: D-01]." "" "[D-01]"
  [ "$_FDL_RC" -eq 0 ] || cf "(c, control) the changed bullet carries its own citation — finish-pr.sh exited $_FDL_RC: $(printf '%s' "$_FDL_OUT" | tail -8 | tr '\n' '|')"
  origin_has_path "progress/qa_complete/$id-onbullet.md" || cf "(c, control) the card did not advance to qa_complete/"
  teardown

  # (d) a citation on a continuation line below the bullet is not on the bullet.
  id="$SB_PREFIX-806"
  _forks_drift_land work-d "$id" continuation 0 \
    "$(printf '%s\n%s' "- [ ] AC1 — the sandbox's seeded behaviour holds, per a ruling written below." "  Continuation line. [decision: D-01]")" "" "[D-01]"
  [ "$_FDL_RC" -ne 0 ] || cf "(d) a citation on a continuation line satisfied the check — finish-pr.sh exited 0"
  case "$_FDL_OUT" in *"citation of its own: AC1"*) : ;; *) cf "(d) the refusal does not name AC1: $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-300)" ;; esac
  teardown

  finish "the citation that answers a changed AC bullet is on that bullet: a card that already cites a ruling on another AC, or in its Activity, is still refused (refusal=forks-ac-changed-uncited, the Next: naming the bullet's AC id); the same edit with the citation on the bullet lands; a citation on a continuation line below the bullet is not on the bullet"
}

# =============================================================================
# CASE — AN INDENTED CONTINUATION LINE IS PART OF ITS AC BULLET: ADDING OR CHANGING ONE AFTER THE
# CARD LEFT todo/ IS A TEXT CHANGE THAT NEEDS THE CITATION ON THE BULLET, AND AN UNCHANGED ONE IS NOT.
#   (a) a continuation line added under AC1, forks: none: refused, naming AC1;
#   (b) CONTROL: the todo/ copy already holds the continuation line and it is untouched: lands;
#   (c) the todo/ copy holds one continuation line and a second is added: refused, naming AC1;
#   (d) the checklist line itself carries the citation while a continuation line is added: lands;
#   (e) an AC citing D-01 gains a continuation line, forks: none: refused; (f) the control with forks: [D-01] lands.
# RED FIRST: (a) and (c) land while the bullet is compared by its checklist line alone.
# =============================================================================
case_finish_pr_forks_ac_continuation_line_is_part_of_the_bullet() {
  cf_reset
  local id
  local base="- [ ] AC1 — the sandbox's seeded behaviour holds."

  id="$SB_PREFIX-833"
  _forks_drift_land work-a "$id" contadd 0 \
    "$(printf '%s\n%s' "$base" "  and now also a second condition, written on a line below.")" "" "none"
  [ "$_FDL_RC" -ne 0 ] || cf "(a) a continuation line was added under AC1 with no citation — finish-pr.sh exited 0"
  case "$_FDL_OUT" in *"citation of its own: AC1"*) : ;; *) cf "(a) the refusal does not name AC1: $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-300)" ;; esac
  origin_has_path "progress/qa_complete/$id-contadd.md" && cf "(a) the card advanced despite the refusal"
  teardown

  id="$SB_PREFIX-834"
  _FDL_TODO_CONT="  the first condition, written on a line below." _forks_drift_land work-b "$id" contsame 0 \
    "$base" "" "none"
  [ "$_FDL_RC" -eq 0 ] || cf "(b, control) an untouched continuation line was read as a change — finish-pr.sh exited $_FDL_RC: $(printf '%s' "$_FDL_OUT" | tail -8 | tr '\n' '|')"
  origin_has_path "progress/qa_complete/$id-contsame.md" || cf "(b, control) the card did not advance to qa_complete/"
  teardown

  id="$SB_PREFIX-835"
  _FDL_TODO_CONT="  the first condition, written on a line below." _forks_drift_land work-c "$id" contmore 0 \
    "$(printf '%s\n%s' "$base" "  a second condition, added later.")" "" "none"
  [ "$_FDL_RC" -ne 0 ] || cf "(c) a second continuation line was added under AC1 with no citation — finish-pr.sh exited 0"
  case "$_FDL_OUT" in *"citation of its own: AC1"*) : ;; *) cf "(c) the refusal does not name AC1: $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-300)" ;; esac
  teardown

  id="$SB_PREFIX-836"
  _forks_drift_land work-d "$id" contcited 1 \
    "$(printf '%s\n%s' "- [ ] AC1 — the sandbox's seeded behaviour holds [decision: D-01]." "  and now also a second condition, written on a line below.")" "" "[D-01]"
  [ "$_FDL_RC" -eq 0 ] || cf "(d) the citation is on the checklist line and a continuation line was added — finish-pr.sh exited $_FDL_RC: $(printf '%s' "$_FDL_OUT" | tail -8 | tr '\n' '|')"
  teardown

  # (e) the checklist line cites D-01 and is untouched; only a continuation line below it is added. The bullet
  #     changed, so its citation is a fork the card made: 'forks: none' is refused, '[D-01]' lands.
  id="$SB_PREFIX-837"
  _FDL_AC2_CONT="  and a third condition, written on a line below." _forks_drift_land work-e "$id" contfork 1 \
    "$base" "" "none"
  [ "$_FDL_RC" -ne 0 ] || cf "(e) a continuation line was added under an AC that cites D-01, with forks: none — finish-pr.sh exited 0"
  origin_has_path "progress/qa_complete/$id-contfork.md" && cf "(e) the card advanced despite the refusal"
  teardown

  id="$SB_PREFIX-838"
  _FDL_AC2_CONT="  and a third condition, written on a line below." _forks_drift_land work-f "$id" contforkok 1 \
    "$base" "" "[D-01]"
  [ "$_FDL_RC" -eq 0 ] || cf "(f, control) the same edit with forks: [D-01] — finish-pr.sh exited $_FDL_RC: $(printf '%s' "$_FDL_OUT" | tail -8 | tr '\n' '|')"
  teardown

  finish "an indented continuation line is read as part of its AC bullet: one added (a) or a second one added (c) after the card left todo/ is refused as uncited drift naming the AC, an untouched one (b) is not drift, the citation on the checklist line (d) answers it, and an AC that already cites a ruling and gains a continuation line has changed, so the ruling is the card's fork: forks: none is refused (e), forks: [D-01] lands (f)"
}

# =============================================================================
# CASE — A CITATION ON AN AC BULLET THAT HAS NOT CHANGED SINCE THE CARD LEFT todo/ IS AN APPLIED
# RULING, NOT A FORK THE CARD RESOLVED. 'forks:' is the card's claim of what it resolved: the PM cites
# a prior ruling's id in an AC (the overlap rule), and that must not force the id into 'forks:'.
#   (a) RED: AC2 (minted in todo/, never edited) cites D-01, `forks: none`, nothing else cites it —
#       finish-pr.sh lands the card;
#   (b) RED: the same journey through `move-issue.sh dev_complete` moves it, so the callers agree;
#   (c) control: AC1's bullet edited after todo/ to cite D-01 under `forks: none` is refused;
#   (d) control: a bullet ADDED after todo/ citing D-01 under `forks: none` is refused;
#   (e) control: an Activity `[decision: D-01]` under `forks: none` is refused;
#   (f) the exit: the same Activity line with the id written bare (no brackets) lands.
# RED FIRST: (a) and (b) fail while a citation anywhere on the card counts.
# =============================================================================
case_forks_check_exempts_a_citation_on_an_unchanged_ac_bullet() {
  cf_reset
  local id ac1="- [ ] AC1 — the sandbox's seeded behaviour holds."

  id="$SB_PREFIX-740"
  _forks_drift_land work-a "$id" unchanged 1 "$ac1" "" "none" finish
  [ "$_FDL_RC" -eq 0 ] || cf "(a) an unchanged AC2 citing [decision: D-01] under 'forks: none' — finish-pr.sh exited $_FDL_RC: $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/qa_complete/$id-unchanged.md" || cf "(a) the card did not advance to qa_complete/"
  teardown

  id="$SB_PREFIX-741"
  _forks_drift_land work-b "$id" unchanged-mv 1 "$ac1" "" "none" move
  [ "$_FDL_RC" -eq 0 ] || cf "(b) an unchanged AC2 citing [decision: D-01] under 'forks: none' — move-issue.sh dev_complete exited $_FDL_RC: $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/dev_complete/$id-unchanged-mv.md" || cf "(b) the card did not reach dev_complete/"
  teardown

  id="$SB_PREFIX-742"
  _forks_drift_land work-c "$id" edited 0 "- [ ] AC1 — the sandbox's seeded behaviour holds, per a ruling [decision: D-01]." "" "none" finish
  [ "$_FDL_RC" -ne 0 ] || cf "(c) a bullet edited after todo/ to cite D-01 under 'forks: none' landed"
  grep -q 'refusal=forks-contradicted' "$SB_TMP/rec"/*.tsv 2>/dev/null || cf "(c) no progress record carries refusal=forks-contradicted: $(printf '%s' "$_FDL_OUT" | tail -6 | tr '\n' '|')"
  case "$_FDL_OUT" in *D-01*) : ;; *) cf "(c) the refusal does not name D-01" ;; esac
  teardown

  id="$SB_PREFIX-743"
  _forks_drift_land work-d "$id" added 0 "$(printf '%s\n%s' "$ac1" "- [ ] AC3 — a bullet added after pickup, per [decision: D-01].")" "" "none" finish
  [ "$_FDL_RC" -ne 0 ] || cf "(d) a bullet added after todo/ citing D-01 under 'forks: none' landed"
  grep -q 'refusal=forks-contradicted' "$SB_TMP/rec"/*.tsv 2>/dev/null || cf "(d) no progress record carries refusal=forks-contradicted: $(printf '%s' "$_FDL_OUT" | tail -6 | tr '\n' '|')"
  teardown

  id="$SB_PREFIX-744"
  _forks_drift_land work-e "$id" activity-cite 1 "$ac1" "- 2026-01-02 [Dev] Applied the ruling. [decision: D-01]" "none" move
  [ "$_FDL_RC" -eq 0 ] || cf "(e) an Activity [decision: D-01] of a ruling live before pickup was refused under 'forks: none' (exit $_FDL_RC): $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/dev_complete/$id-activity-cite.md" || cf "(e) the card did not reach dev_complete/"
  teardown

  id="$SB_PREFIX-745"
  _forks_drift_land work-f "$id" bare 1 "$ac1" "- 2026-01-02 [Dev] Applied D-01 as ruled." "none" move
  [ "$_FDL_RC" -eq 0 ] || cf "(f) an Activity line naming D-01 without brackets was refused (exit $_FDL_RC): $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/dev_complete/$id-bare.md" || cf "(f) the card did not reach dev_complete/"
  teardown

  finish "forks: counts what the card resolved: an unchanged AC bullet citing a ruling no longer forces it into 'forks:' (finish-pr.sh and move-issue.sh dev_complete agree); a bullet edited or added after todo/ still does, an Activity [decision: D-01] of a ruling live before pickup does not, and a bare D-01 in the Activity stays legal"
}

# _forks_ablate_live_citations — the hook for the ablation row: the sandbox's qa-gate.sh reads no
# ruling as live, so every Activity or Out of Scope citation counts again.
_forks_ablate_live_citations() {
  local lib="$SB_WORK/scripts/lib/qa-gate.sh"
  grep -q '"$_forks_live_before")"$' "$lib" || _control_did_not_run "find the live-citation read (the _forks_live_before argument) in lib/qa-gate.sh"
  sed -i.bak 's/"\$_forks_live_before")"$/"")"/' "$lib" && rm -f "$lib.bak"
  grep -qF '"")"' "$lib" || _control_did_not_run "plant the live-citation ablation in lib/qa-gate.sh"
}

# =============================================================================
# CASE — A '[decision: D-NN]' CITATION IN THE ACTIVITY OR OUT OF SCOPE OF A RULING ALREADY LIVE
# WHEN THE CARD LEFT 'todo/' APPLIES IT, AND IS NOT A FORK. The card template's own Activity shape
# is '[decision: D-NN]', so the check must not refuse the shape the template teaches.
#   (a) Activity cites live D-01, 'forks: none', move-issue.sh dev_complete:   lands
#   (b) Out of Scope cites live D-01:                                          lands
#   (c) live D-01 cited in the Activity AND in the Problem prose:              still refused
#   (d) an entry added on the trunk after pickup, cited in the Activity:       still refused
#   (e) finish-pr.sh agrees with (a):                                          lands
#   (f) the live-citation read made empty (ablation): (a) is refused again.
# RED FIRST: (a), (b), (e) fail on a check that counts every bracketed citation outside an unchanged AC.
# =============================================================================
case_forks_check_skips_a_citation_of_a_live_ruling_in_activity_and_out_of_scope() {
  cf_reset
  local id ac1="- [ ] AC1 — the sandbox's seeded behaviour holds." out rc

  id="$SB_PREFIX-760"
  _forks_drift_land work-a "$id" act-live 0 "$ac1" "- 2026-01-02 [Dev] Applied the ruling. [decision: D-01]" "none" move
  [ "$_FDL_RC" -eq 0 ] || cf "(a) an Activity [decision: D-01] of a live ruling under 'forks: none' was refused (exit $_FDL_RC): $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/dev_complete/$id-act-live.md" || cf "(a) the card did not reach dev_complete/"
  teardown

  id="$SB_PREFIX-761"
  _forks_drift_land work-b "$id" oos-live 0 "$ac1" "$(printf '%s\n\n%s' '## Out of Scope' '- Re-deciding the matter: out, per [decision: D-01].')" "none" move
  [ "$_FDL_RC" -eq 0 ] || cf "(b) an Out of Scope [decision: D-01] of a live ruling under 'forks: none' was refused (exit $_FDL_RC): $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/dev_complete/$id-oos-live.md" || cf "(b) the card did not reach dev_complete/"
  teardown

  id="$SB_PREFIX-762"
  _forks_drift_land work-c "$id" prose-live 0 "$ac1" "$(printf '%s\n\n%s\n\n%s\n\n%s' '## Problem' 'The matter is settled by [decision: D-01].' '## Activity' '- 2026-01-02 [Dev] Applied the ruling. [decision: D-01]')" "none" move
  [ "$_FDL_RC" -ne 0 ] || cf "(c) a live D-01 cited in the Problem prose was exempted along with the Activity citation"
  grep -q 'refusal=forks-contradicted' "$SB_TMP/rec"/*.tsv 2>/dev/null || cf "(c) no progress record carries refusal=forks-contradicted: $(printf '%s' "$_FDL_OUT" | tail -6 | tr '\n' '|')"
  teardown

  id="$SB_PREFIX-763"
  _forks_drift_land work-e "$id" act-live-fin 0 "$ac1" "- 2026-01-02 [Dev] Applied the ruling. [decision: D-01]" "none" finish
  [ "$_FDL_RC" -eq 0 ] || cf "(e) finish-pr.sh refused an Activity [decision: D-01] of a live ruling under 'forks: none' (exit $_FDL_RC): $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/qa_complete/$id-act-live-fin.md" || cf "(e) the card did not advance to qa_complete/"
  teardown

  # (d) the entry is added on the trunk AFTER pickup, by another card, and this card's Activity cites it.
  make_sandbox
  _forks_seed_register "$SB_WORK/requirements/DECISIONS.md"
  local idd="$SB_PREFIX-764" other="$SB_PREFIX-769"
  seed_issue todo "$idd" newcite chore "Cites an entry another card registers after pickup" "feature/$idd-work"
  seed_issue todo "$other" owner chore "Owns the new entry" "feature/$other-work"
  publish_sandbox
  _forks_pickup "$idd" newcite
  _forks_add_entry D-02 "Product owner message, 2026-10-16; $other." "[PM] $other: record D-02"
  printf '%s\n' '- 2026-10-16 [Dev] Built to the ruling. [decision: D-02]' >> "$SB_WORK/progress/in_progress/$idd-newcite.md"
  git -C "$SB_WORK" add "progress/in_progress/$idd-newcite.md" >/dev/null 2>&1
  sbcommit -m "[Dev] $idd: cite D-02 on the card" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "(d) the card's citation was not published"
  seed_branch "$idd" work CHANGE764.txt
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-d" ./scripts/move-issue.sh "$idd" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(d) an Activity [decision: D-02] of an entry added after pickup moved to dev_complete under 'forks: none' (exit 0)"
  case "$out" in *"does not name: D-02"*) : ;; *) cf "(d) the refusal does not name D-02: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  case "$out" in *"Next:"*) : ;; *) cf "(d) the refusal carries no Next: line" ;; esac
  teardown

  # (f) ABLATION
  id="$SB_PREFIX-765"
  _FDL_HOOK=_forks_ablate_live_citations _forks_drift_land work-f "$id" act-live-abl 0 "$ac1" "- 2026-01-02 [Dev] Applied the ruling. [decision: D-01]" "none" move
  [ "$_FDL_RC" -ne 0 ] || cf "ABLATION FAILED — with the live-citation read emptied, an Activity [decision: D-01] still landed, so (a)'s pass is not attributable to it"
  grep -q 'refusal=forks-contradicted' "$SB_TMP/rec"/*.tsv 2>/dev/null \
    || cf "ABLATION INVALID — the ablated landing was refused, but not as forks-contradicted, so the refusal is not the citation read's: $(printf '%s' "$_FDL_OUT" | tail -6 | tr '\n' '|')"
  teardown

  finish "forks: skips a '[decision: D-NN]' citation in the Activity or Out of Scope of a ruling already live when the card left todo/ (move-issue.sh and finish-pr.sh agree), still counts one cited elsewhere on the card or of an entry added after pickup, and the live-citation read is ablation-proven"
}

# Hooks for the ablation rows below: each edits the sandbox's qa-gate.sh BEFORE it is published, because a
# landing runs only the trunk's committed copy of the scripts.
_forks_ablate_amended_live() {
  local lib="$SB_WORK/scripts/lib/qa-gate.sh"
  grep -q 'comm -23 .*_fl_changed' "$lib" || { _control_did_not_run "find the amended-entry subtraction in lib/qa-gate.sh"; return 0; }
  sed -i.bak 's/comm -23 <(printf .%s\\n. "\$_fl_ids") <(printf .%s\\n. "\$_fl_changed")/printf "%s\\n" "$_fl_ids"/' "$lib" && rm -f "$lib.bak"
  grep -q 'comm -23 .*_fl_changed' "$lib" && _control_did_not_run "plant the amended-entry ablation in lib/qa-gate.sh"
  return 0
}
_forks_ablate_heading_prefix() {
  local lib="$SB_WORK/scripts/lib/qa-gate.sh"
  grep -qF '"activity"|"activity ("*|"out of scope"|"out of scope ("*)' "$lib" || { _control_did_not_run "find the exact section headings in lib/qa-gate.sh"; return 0; }
  sed -i.bak 's/"activity"|"activity ("\*|"out of scope"|"out of scope ("\*)/"activity"*|"out of scope"*)/' "$lib" && rm -f "$lib.bak"
  return 0
}
_forks_ablate_fence() {
  local lib="$SB_WORK/scripts/lib/qa-gate.sh"
  grep -q 'in_fence=\$((1 - in_fence))' "$lib" || { _control_did_not_run "find the fence toggle in lib/qa-gate.sh"; return 0; }
  sed -i.bak 's/in_fence=\$((1 - in_fence))/:/' "$lib" && rm -f "$lib.bak"
  return 0
}

# _forks_amend_cite_land <id> <slug> [<hook>] — a card amends live D-01 itself on the trunk after pickup
# (through a trunk commit naming it) and cites D-01 in its Activity under 'forks: none'; then the hand-off.
# Sets _FAL_OUT and _FAL_RC. The hook, if any, runs right after the sandbox is made.
_forks_amend_cite_land() {
  local id="$1" slug="$2" hook="${3:-}" reg
  make_sandbox
  [ -z "$hook" ] || "$hook"
  reg="$SB_WORK/requirements/DECISIONS.md"
  _forks_seed_register "$reg"
  seed_issue todo "$id" "$slug" chore "Amends a live ruling and cites it" "feature/$id-work"
  publish_sandbox
  _forks_pickup "$id" "$slug"
  sed -i.bak 's/^\*\*Ruling\.\*\* Old text\./**Ruling.** New text./' "$reg" && rm -f "$reg.bak"
  grep -q 'New text' "$reg" || _fixture_die "_forks_amend_cite_land: the ruling was not amended"
  git -C "$SB_WORK" add requirements/DECISIONS.md >/dev/null 2>&1
  sbcommit -m "[PM] $id: amend D-01" --quiet >/dev/null 2>&1
  printf '%s\n' '- 2026-01-02 [Dev] Changed the text as ruled. [decision: D-01]' >> "$SB_WORK/progress/in_progress/$id-$slug.md"
  git -C "$SB_WORK" add "progress/in_progress/$id-$slug.md" >/dev/null 2>&1
  sbcommit -m "[Dev] $id: cite D-01" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "_forks_amend_cite_land: not published"
  seed_branch "$id" work "CHANGE-$id.txt"
  _FAL_OUT="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec" ./scripts/move-issue.sh "$id" dev_complete --role Dev --note ready 2>&1 )"; _FAL_RC=$?
}

# =============================================================================
# CASE — THE LIVE-CITATION EXEMPTION HAS EDGES.
#   (a) a card that AMENDS live D-01 itself on the trunk after pickup and cites it in the Activity under
#       'forks: none' is refused: an entry the window changed is not "already made";
#   (b) ablation of (a): without the subtraction it lands;
#   (c) a heading that only BEGINS like '## Activity' opens no exempt section;
#   (d) a '## Out of Scope' line inside a code fence opens none;
#   (e) the Next: says the skip applies to a card that left a todo/ column.
# RED FIRST: (a), (c), (d), (e) fail on the check as it first read the exempt sections.
# =============================================================================
case_forks_check_live_citation_exemption_has_edges() {
  cf_reset
  local id ac1="- [ ] AC1 — the sandbox's seeded behaviour holds."

  id="$SB_PREFIX-766"
  _forks_amend_cite_land "$id" amend-cite
  [ "$_FAL_RC" -ne 0 ] || cf "(a) a card that amended live D-01 itself and cites it in the Activity landed under 'forks: none'"
  case "$_FAL_OUT" in *"does not name: D-01"*) : ;; *) cf "(a) the refusal does not name D-01: $(printf '%s' "$_FAL_OUT" | tr '\n' '|' | cut -c1-300)" ;; esac
  case "$_FAL_OUT" in *"left a todo/ column"*) : ;; *) cf "(e) the Next: does not say the skip is for a card that left a todo/ column: $(printf '%s' "$_FAL_OUT" | tr '\n' '|' | cut -c1-700)" ;; esac
  teardown

  id="$SB_PREFIX-767"
  _forks_amend_cite_land "$id" amend-abl _forks_ablate_amended_live
  [ "$_FAL_RC" -eq 0 ] || cf "ABLATION FAILED — with the subtraction of changed entries removed the amending card was still refused (exit $_FAL_RC), so (a)'s refusal is not attributable to it: $(printf '%s' "$_FAL_OUT" | tr '\n' '|' | cut -c1-300)"
  teardown

  id="$SB_PREFIX-768"
  _forks_drift_land work-c "$id" lookalike 0 "$ac1" "$(printf '%s\n\n%s' '## Activity log of rulings' 'This card decides [decision: D-01].')" "none" move
  [ "$_FDL_RC" -ne 0 ] || cf "(c) a live D-01 cited under a heading that only begins with '## Activity' was exempted"
  grep -q 'refusal=forks-contradicted' "$SB_TMP/rec"/*.tsv 2>/dev/null || cf "(c) no progress record carries refusal=forks-contradicted: $(printf '%s' "$_FDL_OUT" | tail -6 | tr '\n' '|')"
  teardown

  id="$SB_PREFIX-769"
  _FDL_HOOK=_forks_ablate_heading_prefix _forks_drift_land work-c2 "$id" lookalike-abl 0 "$ac1" "$(printf '%s\n\n%s' '## Activity log of rulings' 'This card decides [decision: D-01].')" "none" move
  [ "$_FDL_RC" -eq 0 ] || cf "ABLATION FAILED — with the headings matched by prefix the lookalike was still refused (exit $_FDL_RC), so (c) is not attributable to the exact match"
  teardown

  id="$SB_PREFIX-770"
  _forks_drift_land work-d "$id" fenced 0 "$ac1" "$(printf '%s\n%s\n%s\n%s\n\n%s' '## Problem' '```' '## Out of Scope' '```' 'This card settles the matter: [decision: D-01].')" "none" move
  [ "$_FDL_RC" -ne 0 ] || cf "(d) a live D-01 cited after a fenced '## Out of Scope' line was exempted"
  grep -q 'refusal=forks-contradicted' "$SB_TMP/rec"/*.tsv 2>/dev/null || cf "(d) no progress record carries refusal=forks-contradicted: $(printf '%s' "$_FDL_OUT" | tail -6 | tr '\n' '|')"
  teardown

  id="$SB_PREFIX-771"
  _FDL_HOOK=_forks_ablate_fence _forks_drift_land work-d2 "$id" fenced-abl 0 "$ac1" "$(printf '%s\n%s\n%s\n%s\n\n%s' '## Problem' '```' '## Out of Scope' '```' 'This card settles the matter: [decision: D-01].')" "none" move
  [ "$_FDL_RC" -eq 0 ] || cf "ABLATION FAILED — with the fence ignored the fenced heading was still refused (exit $_FDL_RC), so (d) is not attributable to the fence reader"
  teardown

  finish "forks: a live-ruling citation in the Activity or Out of Scope is not skipped for an entry the card itself amended after pickup, under a heading that only begins like the section's, or after a fenced heading line; the Next: says the skip is for a card that left a todo/ column; each edge is ablation-proven"
}

# _forks_pad_card <file> — append the template boilerplate real cards share (a long fixed section),
# so two cards differ only in their few lines of own text, as two cards from one template do.
_forks_pad_card() {
  local f="$1" i=0
  printf '\n## Notes\n\n' >> "$f"
  while [ "$i" -lt 40 ]; do
    printf -- '- Template guidance line %s: say what changed, why, and how it was checked, in one sentence.\n' "$i" >> "$f"
    i=$((i + 1))
  done
}

# =============================================================================
# CASE — THE AC-DRIFT CHECK READS THE CARD'S OWN HISTORY BY ID, NEVER BY CONTENT SIMILARITY.
# A card minted from the same boilerplate as an earlier, already-landed card is not that card:
# a similarity-following history read (git log --follow) reports the new card as a COPY of the
# old one and takes the OLD card's leave-todo commit as its own, so every AC reads as changed.
# The journey: land card A; mint a near-identical card B; move B todo -> in_progress ->
# dev_complete with NO AC change; B must land clean.
# =============================================================================
case_finish_pr_forks_ac_drift_ignores_a_similar_earlier_card() {
  cf_reset
  make_sandbox work-sim
  _forks_seed_register "$SB_WORK/requirements/DECISIONS.md"

  # Card A: the whole ordinary journey, landed.
  local ida="$SB_PREFIX-686"
  seed_issue todo "$ida" first chore "Similar card, landed first" "feature/$ida-work"
  _forks_pad_card "$SB_WORK/progress/todo/$ida-first.md"
  publish_sandbox
  ( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$ida" in_progress --role Dev \
    --note "picked up" >/dev/null 2>&1 ) \
    || _fixture_die "case_finish_pr_forks_ac_drift_ignores_a_similar_earlier_card: A's move to in_progress failed"
  git -C "$SB_WORK" push --quiet >/dev/null 2>&1
  seed_branch "$ida" work CHANGE686.txt
  mkdir -p "$SB_WORK/progress/dev_complete"
  git -C "$SB_WORK" mv "progress/in_progress/$ida-first.md" "progress/dev_complete/$ida-first.md" >/dev/null 2>&1
  sbcommit -m "[Dev] ${ida}: ready for review" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push --quiet >/dev/null 2>&1
  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$ida" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || _fixture_die "case_finish_pr_forks_ac_drift_ignores_a_similar_earlier_card: card A did not land (exit $rc): $(printf '%s' "$out" | tail -8 | tr '\n' '|')"
  git -C "$SB_WORK" pull --ff-only --quiet >/dev/null 2>&1 || true

  # Card B: same boilerplate, minted after A reached qa_complete/. Only B's own path is staged
  # (a second publish_sandbox would commit the kanban worktree).
  local idb="$SB_PREFIX-687"
  seed_issue todo "$idb" second chore "Similar card, minted after" "feature/$idb-work"
  # Its own AC wording (the boilerplate around it stays the same): the wrong card's history
  # carries A's AC text, so a wrong read shows as an AC that "changed".
  perl -i -pe "s/the sandbox.s seeded behaviour holds\\./the second card's own behaviour holds./g" "$SB_WORK/progress/todo/$idb-second.md"
  _forks_pad_card "$SB_WORK/progress/todo/$idb-second.md"
  grep -qF "the second card's own behaviour holds." "$SB_WORK/progress/todo/$idb-second.md" \
    || _fixture_die "case_finish_pr_forks_ac_drift_ignores_a_similar_earlier_card: B's own AC wording was not planted"
  git -C "$SB_WORK" add "progress/todo/$idb-second.md" >/dev/null 2>&1
  sbcommit -m "[PM] ${idb}: mint" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push --quiet >/dev/null 2>&1
  ( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$idb" in_progress --role Dev \
    --note "picked up" >/dev/null 2>&1 ) \
    || _fixture_die "case_finish_pr_forks_ac_drift_ignores_a_similar_earlier_card: B's move to in_progress failed"
  git -C "$SB_WORK" push --quiet >/dev/null 2>&1
  seed_branch "$idb" work CHANGE687.txt
  git -C "$SB_WORK" mv "progress/in_progress/$idb-second.md" "progress/dev_complete/$idb-second.md" >/dev/null 2>&1
  sbcommit -m "[Dev] ${idb}: ready for review" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push --quiet >/dev/null 2>&1

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$idb" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "a card similar to an already-landed one, no AC change after todo/ — finish-pr.sh exited $rc: $(printf '%s' "$out" | tail -8 | tr '\n' '|')"
  case "$out" in *forks-ac-changed-uncited*) cf "the AC-drift check refused a card whose ACs never changed" ;; esac
  origin_has_path "progress/qa_complete/$idb-second.md" || cf "the similar card did not advance to qa_complete/"

  finish "the AC-drift check reads a card's own todo/ history by its id: a card minted from the same boilerplate as an earlier landed card, with no AC change after todo/, lands clean"
  teardown
}

# =============================================================================
# CASE — A CARD MINTED STRAIGHT INTO A LATER COLUMN (no 'progress/todo/' in its history) MAKES
# THE AC-DRIFT HALF OF THE CHECK UNRUNNABLE, NAMED ON STDOUT — never a silent pass, and the
# landing still proceeds (the same shape as kit_ablation_check's undeclared-TEST_GLOBS report).
# =============================================================================
case_finish_pr_forks_ac_drift_unrunnable_with_no_todo_history() {
  cf_reset
  make_sandbox
  _forks_seed_register "$SB_WORK/requirements/DECISIONS.md"

  local id="$SB_PREFIX-683"
  seed_issue dev_complete "$id" direct chore "Minted straight into dev_complete, no todo/ history" "feature/$id-work"
  publish_sandbox
  seed_branch "$id" work CHANGE683.txt

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "a card with no todo/ column history — finish-pr.sh exited $rc: $(printf '%s' "$out" | tail -8 | tr '\n' '|')"
  case "$out" in *"FORKS_AC_DRIFT_CHECK: did not run"*) : ;; *) cf "no 'FORKS_AC_DRIFT_CHECK: did not run' line on stdout: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  origin_has_path "progress/qa_complete/$id-direct.md" || cf "the card did not advance to qa_complete/"

  finish "finish-pr.sh reports the AC-drift half of the forks check as UNRUNNABLE on stdout (never a silent pass) for a card whose history shows no move out of a todo/ column, and still lands it"
  teardown
}

# =============================================================================
# CASE — move-issue.sh <ID> qa_complete (the direct-to-trunk route, no --landed-at) RUNS THE AC-DRIFT
# CHECK. The real order: the card leaves todo/ through the mover, Dev hands it off (the hand-off
# check passes: nothing has changed yet), and QA then corrects an AC bullet in dev_complete/
# (PASS_AC_CORRECTED), committing to the trunk. The correction is a ruling written into an AC:
#   (a) no '[decision: D-NN]' on the corrected bullet: the move is refused, naming AC1, with a Next:
#       line and a refusal=forks-ac-changed-uncited record, and the card stays in dev_complete/;
#   (b) CONTROL: the same correction with the citation on that bullet moves;
#   (c) CONTROL: a card the mover never saw leave todo/ (minted into dev_complete/) is not blocked.
# RED FIRST: (a) fails on a mover that checks the verdict table and nothing else.
# =============================================================================
case_move_issue_qa_complete_runs_the_ac_drift_check() {
  cf_reset
  make_sandbox
  _forks_seed_register "$SB_WORK/requirements/DECISIONS.md"
  local ida="$SB_PREFIX-891" idc="$SB_PREFIX-893" out rc f rel
  seed_issue todo "$ida" corrected chore "AC corrected by QA after hand-off"
  seed_issue dev_complete "$idc" minted chore "Minted into dev_complete, no todo history"
  publish_sandbox
  _forks_pickup "$ida" corrected
  ( cd "$SB_WORK" && ./scripts/move-issue.sh "$ida" dev_complete --role Dev --note "ready" >/dev/null 2>&1 ) \
    || _fixture_die "case_move_issue_qa_complete_runs_the_ac_drift_check: the hand-off move to dev_complete failed"
  _forks_sync
  rel="progress/dev_complete/$ida-corrected.md"
  f="$SB_WORK/$rel"
  [ -f "$f" ] || _fixture_die "case_move_issue_qa_complete_runs_the_ac_drift_check: the card is not in dev_complete/"

  # QA's correction: the bullet text changes, the row says PASS_AC_CORRECTED.
  perl -i -pe 's/^(- \[ \] AC1 — the sandbox.s seeded behaviour holds)\.$/$1, as the owner clarified in review./' "$f"
  perl -i -pe 's/^(\| AC1 \| )PASS( \| test \|.*\|)$/$1PASS_AC_CORRECTED$2/' "$f"
  grep -qF 'as the owner clarified in review.' "$f" && grep -qF '| AC1 | PASS_AC_CORRECTED |' "$f" \
    || _fixture_die "case_move_issue_qa_complete_runs_the_ac_drift_check: the correction was not planted"
  git -C "$SB_WORK" add "$rel" >/dev/null 2>&1
  sbcommit -m "[QA] $ida: correct AC1 (PASS_AC_CORRECTED)" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "case_move_issue_qa_complete_runs_the_ac_drift_check: the correction was not published"

  # (a) uncited correction.
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-a" ./scripts/move-issue.sh "$ida" qa_complete --role QA --note "Review PASS, direct to trunk" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) an AC corrected after todo/ with no citation moved to qa_complete directly (exit 0)"
  case "$out" in *"citation of its own: AC1"*) : ;; *) cf "(a) the refusal does not name AC1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  case "$out" in *"Next:"*) : ;; *) cf "(a) the refusal carries no Next: line" ;; esac
  grep -q 'refusal=forks-ac-changed-uncited' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
    || cf "(a) no progress record carries refusal=forks-ac-changed-uncited: $(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null | cut -c1-200)"
  origin_has_path "progress/qa_complete/$ida-corrected.md" && cf "(a) the card reached qa_complete/ despite the refusal"
  origin_has_path "$rel" || cf "(a) the card left dev_complete/ during the refusal"

  # (b) the citation on the corrected bullet. A mover that let (a) through has already moved the card.
  [ -f "$f" ] || { finish "move-issue.sh <ID> qa_complete (direct to trunk) runs the AC-drift check"; teardown; return; }
  _forks_sync
  perl -i -pe 's/^(- \[ \] AC1 — .*as the owner clarified in review\.)$/$1 [decision: D-01]/' "$f"
  grep -qF 'clarified in review. [decision: D-01]' "$f" \
    || _fixture_die "case_move_issue_qa_complete_runs_the_ac_drift_check: the citation was not planted"
  git -C "$SB_WORK" add "$rel" >/dev/null 2>&1
  sbcommit -m "[QA] $ida: cite the ruling on AC1" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "case_move_issue_qa_complete_runs_the_ac_drift_check: the citation was not published"
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$ida" qa_complete --role QA --note "Review PASS, direct to trunk" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) the correction with its citation on the bullet exited $rc: $(printf '%s' "$out" | tail -6 | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/qa_complete/$ida-corrected.md" || cf "(b) the cited correction did not reach qa_complete/"

  # (c) no todo/ history: the check says it did not run and the move lands.
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$idc" qa_complete --role QA --note "Review PASS" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(c) a card with no todo/ history was refused at qa_complete (exit $rc): $(printf '%s' "$out" | tail -6 | tr '\n' '|' | cut -c1-300)"
  case "$out" in *"FORKS_AC_DRIFT_CHECK: did not run"*) : ;; *) cf "(c) the move does not say the AC-drift check did not run: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac

  finish "move-issue.sh <ID> qa_complete (direct to trunk) runs the AC-drift check: an AC corrected after the card left todo/ with no '[decision: D-NN]' on its bullet is refused, naming the AC with a Next: line and a refusal=forks-ac-changed-uncited record, and the card stays in dev_complete/; the same correction cited on the bullet moves, and a card with no todo/ history says the check did not run and moves"
  teardown
}

# =============================================================================
# CASE — A STRAY NON-CARD FILE UNDER todo/ IS NOT THE CARD'S DEPARTURE. A '<ID>-<slug>.md.bak'
# committed beside the card and later deleted must not become the AC baseline: the card's own
# todo/ copy is.
#   (a) the card's ACs are rewritten in todo/ after the stray copy was committed, the stray copy is
#       deleted, and the card moves through the mover to dev_complete/ and qa_complete/: both moves
#       land (no false forks-ac-changed-uncited naming the commit that dropped the stray file);
#   (b) CONTROL: with the stray file still in the history, a real uncited correction after the card
#       left todo/ is still refused, naming AC1.
# RED FIRST: (a) fails on a gate whose leave-todo pathspec matches any '<ID>-*' file.
# =============================================================================
case_stray_todo_file_is_not_the_cards_departure() {
  cf_reset
  make_sandbox
  _forks_seed_register "$SB_WORK/requirements/DECISIONS.md"
  local ida="$SB_PREFIX-894" idb="$SB_PREFIX-895" out rc id slug rel f
  seed_issue todo "$ida" stray chore "Stray copy beside the card"
  seed_issue todo "$idb" strayctl chore "Stray copy, then a real correction"
  publish_sandbox
  _forks_sync
  for id in "$ida" "$idb"; do
    slug="stray"; [ "$id" = "$idb" ] && slug="strayctl"
    cp "$SB_WORK/progress/todo/$id-$slug.md" "$SB_WORK/progress/todo/$id-$slug.md.bak"
    git -C "$SB_WORK" add "progress/todo/$id-$slug.md.bak" >/dev/null 2>&1
    sbcommit -m "[PM] $id: keep a copy" --quiet >/dev/null 2>&1
  done
  # (a)'s card is rewritten in todo/ while the stray copy still holds the old wording.
  f="$SB_WORK/progress/todo/$ida-stray.md"
  perl -i -pe 's/^(- \[ \] AC1 — the sandbox.s seeded behaviour holds)\.$/$1, as the owner specified./' "$f"
  grep -qF 'as the owner specified.' "$f" || _fixture_die "case_stray_todo_file_is_not_the_cards_departure: the rewrite was not planted"
  git -C "$SB_WORK" add "progress/todo/$ida-stray.md" >/dev/null 2>&1
  sbcommit -m "[PM] $ida: rewrite AC1 in todo" --quiet >/dev/null 2>&1
  for id in "$ida" "$idb"; do
    slug="stray"; [ "$id" = "$idb" ] && slug="strayctl"
    git -C "$SB_WORK" rm -q "progress/todo/$id-$slug.md.bak" >/dev/null 2>&1
    sbcommit -m "[PM] $id: drop the copy" --quiet >/dev/null 2>&1
  done
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "case_stray_todo_file_is_not_the_cards_departure: not published"
  _forks_pickup "$ida"
  _forks_pickup "$idb"

  # (a)
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$ida" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) the hand-off of a card with a deleted stray todo/ copy exited $rc: $(printf '%s' "$out" | tail -6 | tr '\n' '|' | cut -c1-300)"
  _forks_sync
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$ida" qa_complete --role QA --note "Review PASS, direct to trunk" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) qa_complete of a card with a deleted stray todo/ copy exited $rc: $(printf '%s' "$out" | tail -6 | tr '\n' '|' | cut -c1-300)"
  case "$out" in *"AC text changed"*) cf "(a) the stray copy's deletion was taken as the card's departure: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  origin_has_path "progress/qa_complete/$ida-stray.md" || cf "(a) the card did not reach qa_complete/"

  # (b)
  _forks_sync
  ( cd "$SB_WORK" && ./scripts/move-issue.sh "$idb" dev_complete --role Dev --note "ready" >/dev/null 2>&1 ) \
    || cf "(b) the hand-off of the control card failed"
  _forks_sync
  rel="progress/dev_complete/$idb-strayctl.md"
  f="$SB_WORK/$rel"
  if [ -f "$f" ]; then
    perl -i -pe 's/^(- \[ \] AC1 — the sandbox.s seeded behaviour holds)\.$/$1, as the owner clarified in review./' "$f"
    perl -i -pe 's/^(\| AC1 \| )PASS( \| test \|.*\|)$/$1PASS_AC_CORRECTED$2/' "$f"
    git -C "$SB_WORK" add "$rel" >/dev/null 2>&1
    sbcommit -m "[QA] $idb: correct AC1 (PASS_AC_CORRECTED)" --quiet >/dev/null 2>&1
    git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "case_stray_todo_file_is_not_the_cards_departure: the correction was not published"
    out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$idb" qa_complete --role QA --note "Review PASS" 2>&1 )"; rc=$?
    [ "$rc" -ne 0 ] || cf "(b) a real uncited AC correction moved to qa_complete (exit 0)"
    case "$out" in *"citation of its own: AC1"*) : ;; *) cf "(b) the refusal does not name AC1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  else
    cf "(b) the control card is not in dev_complete/"
  fi

  finish "a stray '<ID>-*' file under todo/ (committed beside the card, later deleted) is not the card's departure: the AC baseline stays the card's own todo/ copy, so the hand-off and qa_complete land with no false forks-ac-changed-uncited; a real uncited AC correction after the card left todo/ is still refused naming AC1"
  teardown
}

# =============================================================================
# CASE — A CARD'S `branch:` RESOLVES THROUGH ONE FUNCTION, FOR EVERY CALLER.
# subtask.sh, move-issue.sh and kit-upgrade.sh read the card's code at its branch tip. Shapes are
# planted in a throwaway repo and resolved by lib/branch-rev.sh; each caller is then proved to
# call that function and to carry no reader of its own.
# RED FIRST: fails while the library is absent or a caller still holds its own copy.
# =============================================================================
case_card_branch_resolves_through_one_function() {
  cf_reset
  make_sandbox

  local lib="$REAL_SCRIPTS/lib/branch-rev.sh" w="$SB_TMP/brw" o="$SB_TMP/bro.git" x="$SB_TMP/brx.git"
  if [ ! -f "$lib" ]; then
    cf "scripts/lib/branch-rev.sh is absent: the card-branch reader has no single home"
  else
    git init -q "$w" && git init -q --bare "$o" && git init -q --bare "$x"
    git -C "$w" -c user.name=t -c user.email=t@t commit -q --allow-empty -m base
    git -C "$w" remote add origin "$o" && git -C "$w" remote add other "$x"
    local b
    for b in local-only origin-only other-only; do git -C "$w" branch "$b"; done
    git -C "$w" push -q origin origin-only && git -C "$w" push -q other other-only
    git -C "$w" fetch -q origin && git -C "$w" fetch -q other
    git -C "$w" branch -D origin-only other-only >/dev/null 2>&1
    got() { ( . "$lib"; kit_card_branch_rev "$w" "$@" ) 2>/dev/null; }
    [ "$(got local-only origin)" = refs/heads/local-only ] || cf "local-only (remote origin) resolved to '$(got local-only origin)'"
    [ "$(got local-only)" = refs/heads/local-only ] || cf "local-only (any remote) resolved to '$(got local-only)'"
    [ "$(got origin-only origin)" = refs/remotes/origin/origin-only ] || cf "origin-only resolved to '$(got origin-only origin)'"
    [ "$(got origin-only)" = refs/remotes/origin/origin-only ] || cf "origin-only (any remote) resolved to '$(got origin-only)'"
    [ -z "$(got other-only origin)" ] || cf "a branch only on 'other' resolved when origin was named: '$(got other-only origin)'"
    [ "$(got other-only)" = refs/remotes/other/other-only ] || cf "other-only (any remote) resolved to '$(got other-only)'"
    [ -z "$(got nowhere origin)" ] || cf "a branch nowhere resolved to '$(got nowhere origin)'"
    [ -z "$(got n/a origin)" ] && [ -z "$(got null origin)" ] && [ -z "$(got '' origin)" ] || cf "n/a, null or an empty branch resolved"
  fi

  local s txt
  for s in subtask move-issue kit-upgrade; do
    s="$s.sh"; txt="$(<"$REAL_SCRIPTS/$s")"
    [[ "$txt" == *'lib/branch-rev.sh'* && "$txt" == *'kit_card_branch_rev '* ]] || cf "$s does not source branch-rev.sh and call kit_card_branch_rev"
    [[ "$txt" == *'rev-parse --verify'*'refs/heads/'* || "$txt" == *lc_branch_rev* ]] && cf "$s still holds its own branch-to-revision reader"
    [[ "$txt" == *'refs/remotes/*/'* ]] && cf "$s still holds its own remote-tracking lookup"
  done

  finish "a card's branch: resolves through lib/branch-rev.sh for local-only, remote-only and absent shapes, and the hand-off, slice and upgrade callers each call it and carry no reader of their own"
  teardown
}

# =============================================================================
# CASE — A CARD'S FRONTMATTER FIELD IS READ BY ONE FUNCTION, FOR EVERY CALLER.
# subtask.sh, move-issue.sh, finish-pr.sh and kit-upgrade.sh read `branch:` from a card. The shapes
# are planted and read through lib/card-field.sh; each caller is proved to call it and carry no
# awk reader of its own; and finish-pr.sh LANDS a card whose branch: carries a trailing comment.
# RED FIRST: fails while the library is absent or a caller still holds its own copy.
# =============================================================================
case_card_field_is_read_by_one_function() {
  cf_reset
  make_sandbox

  local lib="$REAL_SCRIPTS/lib/card-field.sh" c="$SB_TMP/field-card.md"
  if [ ! -f "$lib" ]; then
    cf "scripts/lib/card-field.sh is absent: the card-field reader has no single home"
  else
    rd() { ( . "$lib"; kit_card_field "$c" "$1" ) 2>/dev/null; }
    printf '%s\n' '---' 'id: X-1' 'branch: feature/x-1   # reviewed' 'prd:    PRD-7  ' '---' 'branch: feature/body' > "$c"
    [ "$(rd branch)" = feature/x-1 ] || cf "trailing comment: branch read as '$(rd branch)'"
    [ "$(rd prd)" = PRD-7 ] || cf "extra spaces: prd read as '$(rd prd)'"
    [ "$(rd id)" = X-1 ] || cf "plain value: id read as '$(rd id)'"
    printf '%s\n' '---' 'id: X-1' 'branch: # none yet' '---' 'branch: feature/body' > "$c"
    [ -z "$(rd branch)" ] || cf "a comment-only value read as '$(rd branch)'"
    printf '%s\n' '---' 'id: X-1' '---' 'branch: feature/body' > "$c"
    [ -z "$(rd branch)" ] || cf "an absent field read the body line: '$(rd branch)'"
  fi

  local s txt
  for s in subtask move-issue finish-pr kit-upgrade; do
    s="$s.sh"; txt="$(<"$REAL_SCRIPTS/$s")"
    [[ "$txt" == *'lib/card-field.sh'* && "$txt" == *'kit_card_field '* ]] || cf "$s does not source card-field.sh and call kit_card_field"
    [[ "$txt" == *"/^branch:/"* || "$txt" == *'lc_field'* ]] && cf "$s still holds its own branch: reader"
  done

  # finish-pr.sh lands the branch a commented 'branch:' names — not the comment's words with it.
  local id="$SB_PREFIX-641"
  seed_issue dev_complete "$id" commented chore "Branch carries a comment" "feature/$id-work   # reviewed by QA"
  publish_sandbox
  seed_branch "$id" work CHANGE641.txt
  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "finish-pr.sh exited $rc on a commented branch: $(printf '%s' "$out" | tail -6 | tr '\n' '|')"
  origin_has_path "CHANGE641.txt" || cf "the commented branch was not the one landed"

  finish "a card's frontmatter field reads the same through lib/card-field.sh (trailing comment, extra spaces, absent, never the body), the four callers each call it with no reader of their own, and finish-pr.sh lands a commented branch:"
  teardown
}

# =============================================================================
# CASE — THE UNATTRIBUTED-ENTRY HALF HAS AN HONEST EXIT, COUNTS ONLY ADDED ENTRIES, READS
# PROVENANCE AT THE TRUNK TIP, AND ITS WINDOW STARTS AT THE CARD'S OWN PICKUP. In the real order:
# the card is picked up, the entry is registered and published, then the branch is cut.
#   (a) an added entry whose Provenance says 'no work item' (any case) moves;
#   (b) an id that names no card on the trunk attributes nothing, so the entry refuses with a
#       Next: naming all three exits and the trunk-tip checkout;
#   (c) an EDIT to an old entry that carries no work-item id moves: only added entries count;
#   (d) the landing: the Provenance fix committed after the card moved to dev_complete/ clears the
#       refusal, because Provenance is read at the trunk tip, not at the window's end;
#   (e) a slice's file leaving todo/ before the parent does not start the parent's window;
#   (f) an entry added with no id, then edited by a commit whose subject names the card, is NOT
#       attributed by that edit: only the commit that added the heading is read;
#   (g) a Provenance that names a card on the trunk AND says 'no work item' is attributed to the card;
#   (h) a prose heading ('### Notes') added to the register is no entry.
#       A fenced example heading ('### D-99') is not covered: no shared fence reader exists, so it
#       still counts as an entry.
# RED FIRST: (a), (c), (d), (e) fail on a check that counts edits, reads Provenance at the window's
# end, has no 'no work item' exit and matches the parent's globs against its slices' files; (b)
# fails on one that lets an id naming no card attribute.
# =============================================================================
case_forks_check_unattributed_exits_and_window() {
  cf_reset
  make_sandbox
  _forks_seed_register "$SB_WORK/requirements/DECISIONS.md"
  local ida="$SB_PREFIX-881" idb="$SB_PREFIX-882" idc="$SB_PREFIX-883" idd="$SB_PREFIX-884" ide="$SB_PREFIX-885"
  local idf="$SB_PREFIX-886" idg="$SB_PREFIX-887" idh="$SB_PREFIX-888"
  local out rc f
  seed_issue todo "$idf" tweak chore "An id-less entry is later edited under its subject" "feature/$idf-work"
  seed_issue todo "$idg" both chore "Its Provenance names it and says no work item" "feature/$idg-work"
  seed_issue todo "$idh" notes chore "A prose heading is added to the register" "feature/$idh-work"
  seed_issue todo "$ida" nowork chore "Its window holds a card-less entry that says so" "feature/$ida-work"
  seed_issue todo "$idb" ghost chore "Its window holds an entry naming no card" "feature/$idb-work"
  seed_issue todo "$idc" edit chore "An old entry is edited in its window" "feature/$idc-work"
  seed_issue todo "$idd" landing chore "Lands after the Provenance fix" "feature/$idd-work"
  seed_issue todo "$ide" parent chore "Its slice leaves todo first" "feature/$ide-work"
  mkdir -p "$SB_WORK/progress/subtasks/$ide/todo"
  seed_issue "subtasks/$ide/todo" "$ide-s1" slice chore "The parent's slice" "feature/$ide-s1-work"
  publish_sandbox

  # (a) a card-less entry that says so.
  _forks_pickup "$ida" nowork
  _forks_add_entry D-02 "Answered by the product owner through ask.sh, 2026-10-16; No Work Item." "[PM] record D-02 answered"
  seed_branch "$ida" work CHANGE881.txt
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$ida" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) an added entry whose Provenance says 'no work item' refused the move (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"
  origin_has_path "progress/dev_complete/$ida-nowork.md" || cf "(a) the card did not reach dev_complete/"
  case "$out" in *"attributed to $ida: none."*) : ;; *) cf "(a) the hand-off does not print 'none' for an empty attribution: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)" ;; esac
  _forks_sync

  # (b) an id that names no card on the trunk attributes nothing.
  _forks_pickup "$idb" ghost
  _forks_add_entry D-03 "Product owner message, 2026-10-16; owned by $SB_PREFIX-1." "[PM] record D-03"
  seed_branch "$idb" work CHANGE882.txt
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-b" ./scripts/move-issue.sh "$idb" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) an id naming no card on the trunk attributed the entry (exit 0)"
  grep -q 'refusal=forks-attribution-unclear' "$SB_TMP/rec-b"/*.tsv 2>/dev/null \
    || cf "(b) no progress record carries refusal=forks-attribution-unclear: $(cat "$SB_TMP/rec-b"/*.tsv 2>/dev/null)"
  case "$out" in *"Next:"*"'forks:'"*"Provenance"*"no work item"*"trunk tip"*"register-commit.sh"*) : ;; *) cf "(b) the Next: line does not name the three exits and the trunk-tip checkout: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-700)" ;; esac
  _forks_set_forks "$idb" ghost "[D-03]"
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$idb" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) with 'forks: [D-03]' the move exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  _forks_sync

  # (c) an edit to an old entry that names no work item is not attributed by this half.
  _forks_pickup "$idc" edit
  _forks_sync
  sed -i.bak 's/^\*\*Ruling\.\*\* Old text\.$/**Ruling.** Reworded text./' "$SB_WORK/requirements/DECISIONS.md" && rm -f "$SB_WORK/requirements/DECISIONS.md.bak"
  grep -q 'Reworded text' "$SB_WORK/requirements/DECISIONS.md" || _fixture_die "case_forks_check_unattributed_exits_and_window: (c) the edit was not planted"
  git -C "$SB_WORK" add requirements/DECISIONS.md >/dev/null 2>&1
  sbcommit -m "[PM] reword D-01" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "case_forks_check_unattributed_exits_and_window: (c) not published"
  seed_branch "$idc" work CHANGE883.txt
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$idc" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(c) an edit to an old entry refused the move (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"
  _forks_sync

  # (d) the landing: the entry is bare when the card moves to dev_complete/ ('forks:' names it); the
  #     card then drops it from 'forks:'; the Provenance fix lands AFTER the move, through the real
  #     route, and clears the landing.
  _forks_pickup "$idd" landing
  f="$SB_WORK/progress/in_progress/$idd-landing.md"
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  _forks_add_entry D-04 "Product owner message, 2026-10-16." "[PM] record the owner's ruling"
  seed_branch "$idd" work CHANGE884.txt
  _forks_set_forks "$idd" landing "[D-04]"
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$idd" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(d) the hand-off exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  _forks_sync
  f="$SB_WORK/progress/dev_complete/$idd-landing.md"
  sed -i.bak 's/^forks: .*$/forks: none/' "$f" && rm -f "$f.bak"
  git -C "$SB_WORK" add "progress/dev_complete/$idd-landing.md" >/dev/null 2>&1
  sbcommit -m "[Dev] $idd: forks none" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "case_forks_check_unattributed_exits_and_window: (d) not published"
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-d" "$SB_WORK/scripts/finish-pr.sh" "$idd" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(d) the bare entry did not refuse the landing before its Provenance was fixed (exit 0)"
  grep -q 'refusal=forks-attribution-unclear' "$SB_TMP/rec-d"/*.tsv 2>/dev/null \
    || cf "(d) no progress record carries refusal=forks-attribution-unclear: $(cat "$SB_TMP/rec-d"/*.tsv 2>/dev/null)"
  _forks_sync
  sed -i.bak 's/^\(\*\*Provenance\.\*\* Product owner message, 2026-10-16\.\)$/\1 No work item./' "$SB_WORK/requirements/DECISIONS.md" \
    && rm -f "$SB_WORK/requirements/DECISIONS.md.bak"
  grep -q 'No work item' "$SB_WORK/requirements/DECISIONS.md" || _fixture_die "case_forks_check_unattributed_exits_and_window: (d) the Provenance edit was not planted"
  ( cd "$SB_WORK" && ./scripts/register-commit.sh --role PM --message "attribute D-04" requirements/DECISIONS.md >/dev/null 2>&1 ) \
    || _fixture_die "case_forks_check_unattributed_exits_and_window: (d) register-commit.sh refused"
  git -C "$SB_WORK" checkout -q -- requirements/DECISIONS.md >/dev/null 2>&1
  _forks_sync
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$idd" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(d) the Provenance fix committed after the dev_complete move did not clear the landing (exit $rc): $(printf '%s' "$out" | tail -8 | tr '\n' '|')"
  origin_has_path "progress/qa_complete/$idd-landing.md" || cf "(d) the card did not advance to qa_complete/"

  # (e) the slice leaves todo/ first; the entry is registered after that and before the parent's
  #     pickup, so it is outside the parent's window.
  _forks_sync
  mkdir -p "$SB_WORK/progress/subtasks/$ide/in_progress"
  git -C "$SB_WORK" mv "progress/subtasks/$ide/todo/$ide-s1-slice.md" "progress/subtasks/$ide/in_progress/$ide-s1-slice.md" >/dev/null 2>&1 \
    || _fixture_die "case_forks_check_unattributed_exits_and_window: (e) the slice was not moved out of todo/"
  sbcommit -m "[Dev] $ide-s1: picked up" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "case_forks_check_unattributed_exits_and_window: (e) not published"
  _forks_add_entry D-05 "Product owner message, 2026-10-16." "[PM] record the owner's ruling"
  _forks_pickup "$ide" parent
  seed_branch "$ide" work CHANGE885.txt
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$ide" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(e) a slice's file leaving todo/ started the parent's window (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"

  # (f) an entry added with no id, then edited by a commit whose subject names the card.
  _forks_sync
  _forks_pickup "$idf" tweak
  _forks_add_entry D-06 "Product owner message, 2026-10-16." "[PM] record D-06"
  sed -i.bak 's/^\*\*Ruling\.\*\* A ruling for D-06\.$/**Ruling.** A ruling for D-06, tweaked./' "$SB_WORK/requirements/DECISIONS.md" && rm -f "$SB_WORK/requirements/DECISIONS.md.bak"
  grep -q 'D-06, tweaked' "$SB_WORK/requirements/DECISIONS.md" || _fixture_die "case_forks_check_unattributed_exits_and_window: (f) the edit was not planted"
  git -C "$SB_WORK" add requirements/DECISIONS.md >/dev/null 2>&1
  sbcommit -m "[PM] $idf: tweak D-06" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "case_forks_check_unattributed_exits_and_window: (f) not published"
  seed_branch "$idf" work CHANGE886.txt
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-f" ./scripts/move-issue.sh "$idf" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(f) an id-less entry edited under $idf's subject moved with 'forks: none' (exit 0)"
  grep -q 'refusal=forks-attribution-unclear' "$SB_TMP/rec-f"/*.tsv 2>/dev/null \
    || cf "(f) the editor's subject attributed the entry instead of leaving it unattributed: $(cat "$SB_TMP/rec-f"/*.tsv 2>/dev/null | cut -c1-300)"
  case "$out" in *'"[PM] record D-06"'*) : ;; *) cf "(f) the refusal does not name the commit that ADDED the entry ('[PM] record D-06'): $(printf '%s' "$out" | grep -F 'Error:' | cut -c1-300)" ;; esac
  _forks_sync

  # (g) a Provenance that names the card and also says 'no work item'.
  _forks_pickup "$idg" both
  _forks_add_entry D-07 "Resolved by $idg, since there is no work item yet for the rest." "[PM] record D-07"
  seed_branch "$idg" work CHANGE887.txt
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-g" ./scripts/move-issue.sh "$idg" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(g) an entry whose Provenance names $idg was voided by 'no work item' and moved with 'forks: none' (exit 0)"
  grep -q 'refusal=forks-contradicted' "$SB_TMP/rec-g"/*.tsv 2>/dev/null \
    || cf "(g) the refusal is not forks-contradicted: $(cat "$SB_TMP/rec-g"/*.tsv 2>/dev/null | cut -c1-300)"
  _forks_set_forks "$idg" both "[D-07]"
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$idg" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(g) with 'forks: [D-07]' the move exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  _forks_sync

  # (h) a prose heading added to the register is no entry.
  _forks_pickup "$idh" notes
  printf '### Notes on the register\n\nProse, not a ruling.\n\n' > "$SB_TMP/notes.blk"
  awk -v f="$SB_TMP/notes.blk" '/^## Retired ids/ && !d { while ((getline l < f) > 0) print l; d=1 } { print }' \
    "$SB_WORK/requirements/DECISIONS.md" > "$SB_WORK/requirements/DECISIONS.md.new" \
    && mv "$SB_WORK/requirements/DECISIONS.md.new" "$SB_WORK/requirements/DECISIONS.md"
  grep -q '^### Notes on the register' "$SB_WORK/requirements/DECISIONS.md" || _fixture_die "case_forks_check_unattributed_exits_and_window: (h) the heading was not planted"
  git -C "$SB_WORK" add requirements/DECISIONS.md >/dev/null 2>&1
  sbcommit -m "[PM] add a notes heading to the register" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "case_forks_check_unattributed_exits_and_window: (h) not published"
  seed_branch "$idh" work CHANGE888.txt
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$idh" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(h) a prose heading in the register was read as an entry (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"

  finish "the forks: unattributed-entry half: an added entry whose Provenance says 'no work item' moves; an id naming no card on the trunk attributes nothing and the refusal's Next: names three exits and the trunk-tip checkout; an edit to an old entry moves; at the landing a Provenance fix committed after the dev_complete move clears the refusal; a slice's departure from todo/ does not start the parent's window; a later edit under a card's subject does not attribute an id-less entry to it; a Provenance naming a card on the trunk attributes the entry to it even where it also says 'no work item'; a prose heading in the register is no entry"
  teardown
}

# =============================================================================
# CASE — THE WORDINGS A SCRIPT PRINTS: move-issue --help names the blocked_by warning, and the
# stacked-branch refusals route the rebase to the branch's Dev.
# =============================================================================
case_script_wordings_blocked_by_help_and_stacked_routing() {
  cf_reset
  make_sandbox
  local out
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh --help </dev/null 2>&1 )"
  case "$out" in
    *'warn, never refuse'*'blocked_by'*) : ;;
    *) cf "(a) move-issue.sh --help does not say in_progress/ and dev_complete/ warn, never refuse, over a blocked_by card" ;;
  esac
  local n
  n="$(grep -c 'hand the branch to its Dev to rebase' "$SB_WORK/scripts/finish-pr.sh")"
  [ "${n:-0}" -eq 2 ] || cf "(b) finish-pr.sh: want both stacked-branch Next: lines to route the rebase to the Dev, found ${n:-0}"
  finish "move-issue --help names the blocked_by warning; both stacked-branch refusals hand the rebase to the Dev"
  teardown
}

# =============================================================================
# CASE — THE AC POPULATION: kit_ac_drift_check READS EVERY CHECKLIST LINE OF '## Acceptance Criteria',
# REFUSES A CARD WITH NO AC OR A BULLET THE QA GATE'S READER WOULD DROP, AND ASKS A RULING FOR AN AC
# REMOVED OR RENAMED AFTER todo/. Operand: the shipped lib run over a scratch repository whose commit
# history leaves the card's old body at 'todo/', one fixed answer per row. A refusal prints a Next: line
# and never exits with nothing on stderr.
#   (a) only non-id bullets: refused, each named;  (b) id bullets beside four of other shapes: all four named;
#   (c) no AC at all, no todo/ history: refused (not 'did not run');  (d) control: three id bullets, unchanged;
#   (e) an AC removed: refused naming it;  (f) renamed: the old id named;  (g) removed with the ruling cited in the
#   Activity on the line naming it: passes;  (h) removed as a struck bullet carrying the citation: passes;
#   (i) struck with no citation: refused;  (j) a citation in the Activity on a line that does not name the id:
#   refused;  (k) a reworded bullet is still the changed-bullet refusal;  (l) a card with no id bullet no longer
#   ends the caller silently;  (m) the todo copy had no AC line at all: no old id, no drift, no silent exit.
#   (n) a citation written before the removal does not cover it;  (o) a subtask heading, a lower-case heading and a CRLF card are read;
#   (p) a hyphenated id and a shared id;  (q) numbered and quoted bullets;  (r) a half-struck bullet;  (s) comments and indented
#   fences;  (t) a struck bullet citing a live ruling is skipped by the forks: derivation;
#   (u) comments cut out of a line, not the line;  (v) a second strike;  (w) hyphenated ids in the todo copy;  (x) whitespace alone;
#   (y) a heading that only begins with the section name;  (x2) whitespace added;
#   (z1) an unchanged card with a Tasks checklist;  (z6) a Tasks line dropped after todo/;  (z2) id-less todo criteria given ids;  (z3, z4) a comment on the old line;
#   (z5) several blanks after the hashes in the forks: reader.
# =============================================================================
_ac808_card() {  # <ac lines> [<activity lines>] — a card body on stdout
  printf '# card\n\n## %s\n\n%s\n\n%s## Activity\n\n%s\n' "${_AC808_HEAD:-Acceptance Criteria}" "$1" "${_AC808_TASKS:+## Tasks

$_AC808_TASKS

}" "${2:-${_AC808_OLDACT:-- opened}}" \
    | { if [ -n "${_AC808_CRLF:-}" ]; then sed 's/$/\r/'; else cat; fi; }
}
_ac808_run() {  # <old-acs> <new-acs> <new-activity|-> <leave: yes|no> — prints "rc=N" then the output
  local old="$1" new="$2" act="$3" leave="$4" d out rc lc=""
  d="$SB_TMP/ac808"; rm -rf "$d"; mkdir -p "$d/r/progress/todo" "$d/r/progress/in_progress"
  git -C "$d/r" init -q . >/dev/null 2>&1
  _AC808_TASKS="${_AC808_TASKS_OLD-${_AC808_TASKS:-}}" _ac808_card "$old" > "$d/r/progress/todo/X-001-a.md"   # the todo copy carries _AC808_OLDACT, the new card the same unless it names its own
  git -C "$d/r" add -A >/dev/null 2>&1
  git -C "$d/r" -c user.name=t -c user.email=t@t commit -q -m todo >/dev/null 2>&1
  git -C "$d/r" mv progress/todo/X-001-a.md progress/in_progress/X-001-a.md >/dev/null 2>&1
  git -C "$d/r" -c user.name=t -c user.email=t@t commit -q -m leave >/dev/null 2>&1
  [ "$leave" = no ] || lc="$(git -C "$d/r" rev-parse HEAD)"
  if [ "$act" = - ]; then _ac808_card "$new" > "$d/new.md"; else _ac808_card "$new" "$act" > "$d/new.md"; fi
  out="$(bash -c 'set -eo pipefail; . "$1/lib/refuse.sh"; . "$1/lib/decision-register.sh"; . "$1/lib/qa-gate.sh"; kit_ac_drift_check "$2" X-001 "$3" "$4" "$5"' \
    _ "$REAL_SCRIPTS" "$d/new.md" "$d/r" "$lc" progress/todo/X-001-a.md 2>&1 </dev/null)"; rc=$?
  printf 'rc=%s\n%s\n' "$rc" "$out"
}
_ac808_want() {  # <label> <out> <rc> [<needle>…]
  local lbl="$1" o="$2" want="$3" n; shift 3
  case "$o" in "rc=$want"*) : ;; *) cf "($lbl) want rc=$want: $(printf '%s' "$o" | tr '\n' '|' | cut -c1-260)" ;; esac
  for n in "$@"; do
    case "$o" in *"$n"*) : ;; *) cf "($lbl) output lacks [$n]: $(printf '%s' "$o" | tr '\n' '|' | cut -c1-260)" ;; esac
  done
}
# The acceptance-criteria examples the kit teaches are lines the landing gate's reader grades: an example
# with no id, copied onto a card verbatim, would pass the move to todo/ and be refused only at the hand-off.
case_the_acs_the_kit_teaches_are_lines_the_ac_reader_accepts() {
  cf_reset
  make_sandbox
  local root="$REAL_REPO_ROOT" out
  _ac828_check() {  # <label> <checklist lines>
    [ -n "$2" ] || { cf "($1) no checklist line was extracted"; return 0; }
    out="$(bash -c 'set -eo pipefail; . "$1/lib/refuse.sh"; . "$1/lib/qa-gate.sh"; _qav_ac_stray_bullets "$2"' \
      _ "$REAL_SCRIPTS" "$(printf '## Acceptance Criteria\n\n%s\n' "$2")" 2>&1 </dev/null)"
    [ -z "$out" ] || cf "($1) the AC reader refuses the example: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  }
  _ac828_lines() { LC_ALL=C awk '/^[[:space:]]*([-*+]|[0-9]+[.)])[[:space:]]+\[[ xX]\]/{print}' "$1"; }
  _ac828_check skill "$(_ac828_lines "$root/.claude/skills/write-spec/SKILL.md")"
  _ac828_check issue "$(_ac828_lines "$root/.claude/templates/ISSUE.template.md")"
  _ac828_check bug "$(_ac828_lines "$root/.claude/templates/BUG.template.md")"
  _ac828_check prd "$(LC_ALL=C awk '/^\*\*Acceptance Criteria\*\*/{on=1;next} /^\*\*Every/{on=0} on && /^- \[[ xX]\]/{print}' "$root/.claude/templates/PRD.template.md")"
  # The teaching names the id where a PRD line becomes a card line.
  grep -qF 'AC<n>' "$root/.claude/skills/write-spec/SKILL.md" || cf "(skill) the write-spec skill does not name the AC<n> id"
  grep -F '**Acceptance Criteria**' "$root/.claude/roles/pm.md" > "$SB_TMP/w828-pm.txt"
  grep -qF 'AC<n>' "$SB_TMP/w828-pm.txt" || cf "(pm) the ready checklist's Acceptance Criteria box does not name the AC<n> id"
  grep -E '^Copied from the PRD stories' "$root/.claude/templates/ISSUE.template.md" > "$SB_TMP/w828-issue.txt"
  grep -qF 'gets its `AC<n>` id' "$SB_TMP/w828-issue.txt" || cf "(issue) the card template does not say a PRD line gets its id when copied"
  finish "the checklist examples in write-spec and the card, bug and PRD templates are lines the AC reader accepts, and the skill, the PM's ready checklist and the card template each say a PRD line gets an AC<n> id when copied to the card"
  teardown
}
case_the_ac_population_is_every_checklist_line_and_a_removed_ac_needs_a_ruling() {
  cf_reset
  make_sandbox
  local three out
  three="$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.\n- [ ] AC3 — three.')"
  out="$(_ac808_run "$three" "$(printf -- '- [ ] the login form must work\n- [ ] it is fast')" - yes)"
  _ac808_want a "$out" 1 'Acceptance Criteria' 'the login form must work' 'it is fast' 'Next:'
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n* [ ] AC2 — two.\n  - [ ] AC3 — three.\n- [ ] AC4.1 — four.\n- [ ] an unnamed bullet')" - yes)"
  _ac808_want b "$out" 1 'Next:' 'AC2 — two' 'AC3 — three' 'AC4.1' 'an unnamed bullet'
  out="$(_ac808_run "$three" "$(printf 'no criteria here.')" - no)"
  _ac808_want c "$out" 1 'Next:'
  case "$out" in *"did not run"*) cf "(c) a card with no AC read as 'did not run'" ;; esac
  out="$(_ac808_run "$three" "$three" - yes)"
  _ac808_want d "$out" 0
  case "$out" in *"Next:"*) cf "(d) a card whose ACs never changed was refused" ;; esac
  out="$(_ac808_run "$three" "$three" - no)"
  _ac808_want d2 "$out" 0 'did not run'
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.')" - yes)"
  _ac808_want e "$out" 1 'AC text' 'AC3' 'Next:'
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC9 — two.\n- [ ] AC3 — three.')" - yes)"
  _ac808_want f "$out" 1 'AC text' 'AC2'
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.')" '- dropped AC3 [decision: D-01]' yes)"
  _ac808_want g "$out" 0
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.\n- [ ] ~~AC3 — three.~~ [decision: D-01]')" - yes)"
  _ac808_want h "$out" 0
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.\n- [ ] ~~AC3 — three.~~')" - yes)"
  _ac808_want i "$out" 1 'AC text' 'AC3'
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.')" '- dropped something else [decision: D-01]' yes)"
  _ac808_want j "$out" 1 'AC3'
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two, reworded.\n- [ ] AC3 — three.')" - yes)"
  _ac808_want k "$out" 1 'AC text' 'AC2'
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two, reworded. [decision: D-01]\n- [ ] AC3 — three.')" - yes)"
  _ac808_want k2 "$out" 0
  out="$(_ac808_run 'a todo copy with prose only.' "$three" - yes)"
  _ac808_want m "$out" 0
  case "$out" in *"Next:"*) cf "(m) a card whose todo copy had no AC line was refused" ;; esac
  # A citation written BEFORE the removal, on an Activity line that names the AC, is not the removal's citation.
  _AC808_OLDACT='- scoped AC3 per [decision: D-02]'
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.')" - yes)"
  _ac808_want n1 "$out" 1 'AC text' 'AC3'
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.')" "$(printf -- '- scoped AC3 per [decision: D-02]\n- dropped AC3 [decision: D-03]')" yes)"
  _ac808_want n2 "$out" 0
  unset _AC808_OLDACT
  # The subtask card's heading, a lower-case heading and a CRLF card are read like the template's.
  _AC808_HEAD='Acceptance Criteria (sliced from the parent)'
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n* [ ] AC2 — two.\n- [ ] AC3 — three.')" - yes)"
  _ac808_want o1 "$out" 1 'AC2 — two'
  _AC808_HEAD='Acceptance criteria'
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n* [ ] AC2 — two.\n- [ ] AC3 — three.')" - yes)"
  _ac808_want o2 "$out" 1 'AC2 — two'
  unset _AC808_HEAD
  _AC808_CRLF=1
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n* [ ] AC2 — two.\n- [ ] AC3 — three.')" - yes)"
  _ac808_want o3 "$out" 1 'AC2 — two'
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.')" '- dropped AC3 [decision: D-01]' yes)"
  _ac808_want o4 "$out" 0
  _AC808_OLDACT='- scoped AC3 per [decision: D-02]'
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.')" - yes)"
  _ac808_want o5 "$out" 1 'AC text' 'AC3'
  unset _AC808_OLDACT
  unset _AC808_CRLF
  # A hyphenated id and an id on two lines are refused, each named.
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC-1 — one.\n- [ ] AC-2 — two.')" - yes)"
  _ac808_want p1 "$out" 1 'AC-1 — one' 'AC-2 — two' 'Next:'
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.\n- [ ] AC2 — two again.')" - yes)"
  _ac808_want p2 "$out" 1 'AC2 (on more than one line)' 'Next:'
  # A numbered or quoted checklist line with an id is graded (and so cannot be dropped silently); without an id it is refused.
  out="$(_ac808_run "$three" "$(printf -- '1. [ ] AC1 — one.\n> - [ ] AC2 — two.\n- [ ] AC3 — three.')" - yes)"
  _ac808_want q1 "$out" 0
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.\n1. [ ] a numbered line of no id')" - yes)"
  _ac808_want q2 "$out" 1 'a numbered line of no id'
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.\n> - [ ] a quoted line of no id')" - yes)"
  _ac808_want q3 "$out" 1 'a quoted line of no id'
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n1. [ ] AC2 — two.')" - yes)"
  _ac808_want q4 "$out" 1 'AC3'
  # Only a bullet struck through completely is a recorded removal.
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.\n- [ ] AC3 — three.\n- [ ] ~~old~~ the login form must work')" - yes)"
  _ac808_want r "$out" 1 'the login form must work'
  # An example inside an HTML comment or an indented fence is not a checklist line of the card.
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.\n- [ ] AC3 — three.\n<!--\n- [ ] an example shape\n-->\n  ```\n  - [ ] another example\n  ```')" - yes)"
  _ac808_want s "$out" 0
  # A struck bullet cites a ruling already made like the Activity does: skipped when the register held it, counted when not.
  _ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.\n- [ ] ~~AC3 — three.~~ [decision: D-01]')" - yes >/dev/null
  out="$(bash -c '. "$1/lib/refuse.sh"; . "$1/lib/decision-register.sh"; . "$1/lib/qa-gate.sh"; _forks_cited_ids "$2" "$3" "$4" progress/todo/X-001-a.md "D-[0-9]+" "$5"' \
    _ "$REAL_SCRIPTS" "$SB_TMP/ac808/new.md" "$SB_TMP/ac808/r" "$(git -C "$SB_TMP/ac808/r" rev-parse HEAD)" "D-01" 2>&1 </dev/null)"
  [ -z "$out" ] || cf "(t1) a struck bullet's citation of a ruling the register held was counted: $out"
  out="$(bash -c '. "$1/lib/refuse.sh"; . "$1/lib/decision-register.sh"; . "$1/lib/qa-gate.sh"; _forks_cited_ids "$2" "$3" "$4" progress/todo/X-001-a.md "D-[0-9]+" "$5"' \
    _ "$REAL_SCRIPTS" "$SB_TMP/ac808/new.md" "$SB_TMP/ac808/r" "$(git -C "$SB_TMP/ac808/r" rev-parse HEAD)" "" 2>&1 </dev/null)"
  [ "$out" = "D-01" ] || cf "(t2) a struck bullet's citation of an id the register did not hold was not counted: [$out]"
  printf '# c\n\n## Acceptance Criteria\n\n- [ ] AC1 — one.\n\n## activity (notes)\r\n\n- applies [decision: D-01]\r\n' > "$SB_TMP/ac808/lower.md"
  out="$(bash -c '. "$1/lib/refuse.sh"; . "$1/lib/decision-register.sh"; . "$1/lib/qa-gate.sh"; _forks_cited_ids "$2" "$3" "$4" progress/todo/X-001-a.md "D-[0-9]+" "$5"' \
    _ "$REAL_SCRIPTS" "$SB_TMP/ac808/lower.md" "$SB_TMP/ac808/r" "$(git -C "$SB_TMP/ac808/r" rev-parse HEAD)" "D-01" 2>&1 </dev/null)"
  [ -z "$out" ] || cf "(t3) an Activity heading in lower case with a suffix and a carriage return was not read as the Activity: [$out]"
  # A comment trailing a checklist line, one inside the line, and one over several lines leave the line itself to be read.
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.\n- [ ] AC3 — three.\n* [ ] the login must work <!-- note -->')" - yes)"
  _ac808_want u1 "$out" 1 'the login must work'
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.\n- [ ] AC3 — three.\nSee notes <!-- start\n* [ ] the login must work\n--> * [ ] it is fast')" - yes)"
  _ac808_want u2 "$out" 1 'it is fast'
  case "$out" in *'the login must work'*) cf "(u2) a line inside a multi-line comment was read" ;; esac
  # A bullet is exempt only when one strike spans it: a second struck span after live text is not.
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.\n- [ ] AC3 — three.\n- [ ] ~~x~~ the login must work ~~y~~')" - yes)"
  _ac808_want v "$out" 1 'the login must work'
  # A todo copy whose ids were hyphenated still has them frozen.
  out="$(_ac808_run "$(printf -- '- [ ] AC-1 — one.\n- [ ] AC-2 — two.')" "$(printf -- '- [ ] AC1 — something else entirely.')" - yes)"
  _ac808_want w1 "$out" 1 'AC text' 'AC-1'
  out="$(_ac808_run "$(printf -- '- [ ] AC-1 — one.\n- [ ] AC-2 — two.')" "$(printf -- '- [ ] AC1 — one.')" '- AC-1 became AC1, AC-2 dropped [decision: D-01]' yes)"
  _ac808_want w2 "$out" 0
  # Whitespace alone does not make an old Activity line new.
  _AC808_OLDACT='- scoped AC3 per [decision: D-02]  '
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.')" '- scoped AC3 per [decision: D-02]' yes)"
  _ac808_want x "$out" 1 'AC3'
  _AC808_OLDACT='- scoped AC3 per [decision: D-02]'
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.')" '-   scoped AC3 per [decision: D-02]   ' yes)"
  _ac808_want x2 "$out" 1 'AC3'
  unset _AC808_OLDACT
  # A heading that only begins with the section name is another section.
  _AC808_HEAD='Acceptance Criteria notes'
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.\n- [ ] AC3 — three.\n* [ ] a note, not a criterion')" - yes)"
  _ac808_want y "$out" 0
  unset _AC808_HEAD
  # An unchanged card is never refused for a checklist elsewhere on it, however its lines read.
  _AC808_TASKS="$(printf -- '- [ ] Re-enable login\n- [ ] Follow-up — file a ticket\n- [ ] E-mail is sent')"
  out="$(_ac808_run "$three" "$three" - yes)"
  _ac808_want z1 "$out" 0
  case "$out" in *"Next:"*) cf "(z1) an unchanged card with a Tasks checklist was refused: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)" ;; esac
  unset _AC808_TASKS
  # A checklist line elsewhere on the todo copy that the new card no longer has is no removed AC.
  _AC808_TASKS_OLD="$(printf -- '- [ ] Follow-up — file a ticket')"
  out="$(_ac808_run "$three" "$three" - yes)"
  _ac808_want z6 "$out" 0
  case "$out" in *"Next:"*) cf "(z6) a Tasks line dropped after todo/ was read as a removed AC: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)" ;; esac
  unset _AC808_TASKS_OLD
  # Id-less todo criteria rewritten as the refusal's Next says are not read as removed ids.
  out="$(_ac808_run "$(printf -- '- [ ] Re-enable login after a reset\n- [ ] E-mail is sent')" "$(printf -- '- [ ] AC1 — Re-enable login after a reset.\n- [ ] AC2 — E-mail is sent.')" - yes)"
  _ac808_want z2 "$out" 0
  case "$out" in *"Next:"*) cf "(z2) id-less todo criteria rewritten with ids were refused: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)" ;; esac
  # A comment on the old Activity line does not make the line new.
  _AC808_OLDACT='- scoped AC3 per [decision: D-02] <!-- note -->'
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.')" - yes)"
  _ac808_want z3 "$out" 1 'AC3'
  _AC808_OLDACT=$'- scoped AC3 per [decision: D-02] <!-- a\n   still a comment -->'
  out="$(_ac808_run "$three" "$(printf -- '- [ ] AC1 — one.\n- [ ] AC2 — two.')" - yes)"
  _ac808_want z4 "$out" 1 'AC3'
  unset _AC808_OLDACT
  # The forks: derivation's heading takes any run of blanks after '##'.
  printf '# c\n\n## Acceptance Criteria\n\n- [ ] AC1 — one.\n\n##  Activity\n\n- applies [decision: D-01]\n\n##\tOut of Scope\n\n- applies [decision: D-01]\n' > "$SB_TMP/ac808/blanks.md"
  out="$(bash -c '. "$1/lib/refuse.sh"; . "$1/lib/decision-register.sh"; . "$1/lib/qa-gate.sh"; _forks_cited_ids "$2" "$3" "$4" progress/todo/X-001-a.md "D-[0-9]+" "$5"' \
    _ "$REAL_SCRIPTS" "$SB_TMP/ac808/blanks.md" "$SB_TMP/ac808/r" "$(git -C "$SB_TMP/ac808/r" rev-parse HEAD)" "D-01" 2>&1 </dev/null)"
  [ -z "$out" ] || cf "(z5) an Activity and an Out of Scope heading with several blanks after the hashes were not read as the sections: [$out]"
  out="$(_ac808_run "$three" "$(printf -- '- [ ] only a bullet of no id')" - yes)"
  case "$out" in "rc=1"*"Next:"*) : ;; *) cf "(l) a card with no id bullet did not print a refusal naming a Next: and exit 1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  finish "kit_ac_drift_check refuses, with a Next: line, a card with no AC or a checklist line the QA gate's reader would drop (each named), refuses an AC removed or renamed after todo/ unless the removal is cited in the Activity on a line naming it or on a struck bullet, and still passes an unchanged card"
  teardown
}


# _forks_midwork_entry <id> <slug> <entry-id> <forks-value> — the card is picked up, its branch is cut,
# and only then does a ruling naming the card land on the trunk, published; the card's trunk copy gets
# <forks-value>. The branch never holds the entry and is not merged with the trunk.
_forks_midwork_entry() {
  local id="$1" slug="$2" eid="$3" fv="$4"
  _forks_pickup "$id" "$slug"
  seed_branch "$id" work "CHANGE-$id.txt"
  _forks_add_entry "$eid" "Product owner message, 2026-10-16; $id." "[PM] $id: record $eid"
  _forks_set_forks "$id" "$slug" "$fv"
}

# _forks_midwork_land <id> <slug> <hook> <forks-value> [<mode> [cite]] — one mid-work hand-off in a fresh sandbox:
# the card is picked up and its branch cut. Mode '' : a ruling naming the card (D-02) lands on the trunk after the
# cut; 'retire': the branch moves D-01 to the Retired ids; 'withdraw': the trunk does. With 'cite' the card's
# Activity cites D-01. The hook, if any, edits the sandbox's qa-gate.sh before it is published.
# Sets _FML_OUT and _FML_RC.
_forks_midwork_land() {
  local id="$1" slug="$2" hook="$3" fv="$4" mode="${5:-}" cite="${6:-}" reg card
  make_sandbox
  [ -z "$hook" ] || "$hook"
  reg="$SB_WORK/requirements/DECISIONS.md"
  _forks_seed_register "$reg"
  seed_issue todo "$id" "$slug" chore "Mid-work ruling" "feature/$id-work"
  publish_sandbox
  _forks_pickup "$id" "$slug"
  seed_branch "$id" work "CHANGE-$id.txt"
  if [ "$mode" = retire ]; then
    git -C "$SB_WORK" checkout -q "feature/$id-work" >/dev/null 2>&1
    perl -i -pe 's/^### D-01$/#### withdrawn/; s/^## Retired ids$/## Retired ids\n\n`D-01` — retired 2026-11-01; withdrawn./' "$reg"
    grep -q 'withdrawn\.' "$reg" || _fixture_die "_forks_midwork_land: the retirement was not planted"
    git -C "$SB_WORK" add requirements/DECISIONS.md >/dev/null 2>&1
    sbcommit -m "[Dev] $id: retire D-01" --quiet >/dev/null 2>&1
    git -C "$SB_WORK" push -q origin "feature/$id-work" >/dev/null 2>&1
    git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1
  elif [ "$mode" = withdraw ]; then
    _forks_sync
    perl -i -pe 's/^### D-01$/#### withdrawn/; s/^## Retired ids$/## Retired ids\n\n`D-01` — retired 2026-11-01; withdrawn./' "$reg"
    grep -q 'withdrawn\.' "$reg" || _fixture_die "_forks_midwork_land: the withdrawal was not planted"
    git -C "$SB_WORK" add requirements/DECISIONS.md >/dev/null 2>&1
    sbcommit -m "[PM] withdraw D-01" --quiet >/dev/null 2>&1
    git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "_forks_midwork_land: the withdrawal was not published"
  else
    _forks_add_entry D-02 "Product owner message, 2026-10-16; $id." "[PM] $id: record D-02"
  fi
  if [ -n "$cite" ]; then
    _forks_sync
    card="$SB_WORK/progress/in_progress/$id-$slug.md"
    printf '%s\n' '- 2026-11-02 [Dev] Applied the ruling. [decision: D-01]' >> "$card"
    git -C "$SB_WORK" add "progress/in_progress/$id-$slug.md" >/dev/null 2>&1
    sbcommit -m "[Dev] $id: cite D-01" --quiet >/dev/null 2>&1
    git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "_forks_midwork_land: the citation was not published"
  fi
  _forks_set_forks "$id" "$slug" "$fv"
  _FML_OUT="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec" ./scripts/move-issue.sh "$id" dev_complete --role Dev --note ready 2>&1 )"; _FML_RC=$?
}
_forks_ablate_trunk_live() {
  local lib="$SB_WORK/scripts/lib/qa-gate.sh"
  grep -q '^    _fr_trunk=' "$lib" || { _control_did_not_run "find the trunk register read in lib/qa-gate.sh"; return 0; }
  sed -i.bak 's/^    _fr_trunk=.*$/    _fr_trunk=""/' "$lib" && rm -f "$lib.bak"
  return 0
}
_forks_ablate_retired_kept() {
  local lib="$SB_WORK/scripts/lib/qa-gate.sh"
  grep -q '^    _fr_retired=' "$lib" || { _control_did_not_run "find the retired read in lib/qa-gate.sh"; return 0; }
  sed -i.bak 's/^    _fr_retired=.*$/    _fr_retired=""/' "$lib" && rm -f "$lib.bak"
  return 0
}
_forks_ablate_withdrawn_live() {
  local lib="$SB_WORK/scripts/lib/qa-gate.sh"
  grep -q '^        _fl_ids="\$(comm -12 ' "$lib" || { _control_did_not_run "find the withdrawn-on-the-trunk subtraction in lib/qa-gate.sh"; return 0; }
  sed -i.bak 's/^        _fl_ids="\$(comm -12 .*$/        :/' "$lib" && rm -f "$lib.bak"
  return 0
}
_forks_ablate_branch_retired_live() {
  local lib="$SB_WORK/scripts/lib/qa-gate.sh"
  grep -q '^        _fl_ids="\$(comm -23 .*_fl_bret' "$lib" || { _control_did_not_run "find the branch-retired subtraction in lib/qa-gate.sh"; return 0; }
  sed -i.bak 's/^        _fl_ids="\$(comm -23 .*_fl_bret.*$/        :/' "$lib" && rm -f "$lib.bak"
  return 0
}

# =============================================================================
# CASE — A RULING THAT LANDS ON THE TRUNK AFTER THE BRANCH WAS CUT IS LIVE; A CHANGED AC BULLET THAT CITES
# A RULING IS A FORK AND BOTH REFUSALS NAME THE EXIT; A WITHDRAWN RULING IS NOT "ALREADY MADE".
#   (a) hand-off: a ruling naming the card is on the trunk only; 'forks: [D-NN]' passes with no merge;
#   (b) the same under 'forks: none' still refuses, and the Next names the exit (no merge needed);
#   (c) an id live on neither side is still unresolved, and its Next says both registers are read;
#   (d) the landing agrees with the hand-off;
#   (e) an AC rewritten with '[decision: D-01]' on its own bullet under 'forks: none' is refused as a fork,
#       and the Next names 'forks: [D-NN]'; doing what it says lands (hand-off and landing);
#   (f) the same rewrite with the citation only in the Activity is refused for the bullet, its Next names
#       the bullet AND 'forks: [D-NN]'; doing both lands: the two refusals never send the card back and forth;
#   (g) a changed bullet citing an id the register does not hold still counts as a fork;
#   (i) an id the branch retired is not live for 'forks:';
#   (k) an Activity citation of a ruling the trunk has since withdrawn counts, and so does one of a ruling the
#       branch itself retires.
# RED FIRST: (a), (b)'s Next, (c)'s Next, (d), (e)'s and (f)'s Next, (k) fail on a check that reads the live set
# from the branch's register alone, names no 'forks:' exit for a changed AC, and calls a withdrawn ruling live.
# =============================================================================
case_forks_a_ruling_added_on_the_trunk_after_the_cut_is_live_a_changed_ac_citing_one_is_a_fork_with_its_exit_named() {
  cf_reset
  make_sandbox
  _forks_seed_register "$SB_WORK/requirements/DECISIONS.md"
  local ida="$SB_PREFIX-881" idb="$SB_PREFIX-882" idc="$SB_PREFIX-883" idd="$SB_PREFIX-884" out rc
  seed_issue todo "$ida" mid chore "A ruling lands on the trunk mid-work" "feature/$ida-work"
  seed_issue todo "$idb" none chore "The same, under forks none" "feature/$idb-work"
  seed_issue todo "$idc" ghost chore "Names an id on neither side" "feature/$idc-work"
  seed_issue todo "$idd" land chore "The same, through the landing" "feature/$idd-work"
  publish_sandbox

  _forks_midwork_entry "$ida" mid D-02 "[D-02]"
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-a" ./scripts/move-issue.sh "$ida" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) 'forks: [D-02]' over a ruling on the trunk since the cut refused (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/dev_complete/$ida-mid.md" || cf "(a) the card did not reach dev_complete/"
  _forks_sync

  _forks_midwork_entry "$idb" none D-03 "none"
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-b" ./scripts/move-issue.sh "$idb" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) 'forks: none' over a ruling naming the card moved (exit 0)"
  grep -q 'refusal=forks-contradicted' "$SB_TMP/rec-b"/*.tsv 2>/dev/null || cf "(b) no progress record carries refusal=forks-contradicted"
  case "$out" in *"no merge of the trunk"*) : ;; *) cf "(b) the Next does not say a merge of the trunk is not the exit: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-500)" ;; esac
  _forks_sync

  _forks_pickup "$idc" ghost
  seed_branch "$idc" work "CHANGE-$idc.txt"
  _forks_set_forks "$idc" ghost "[D-77]"
  out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-c" ./scripts/move-issue.sh "$idc" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(c) an id live on neither side moved (exit 0)"
  grep -q 'refusal=forks-unresolved' "$SB_TMP/rec-c"/*.tsv 2>/dev/null || cf "(c) no progress record carries refusal=forks-unresolved"
  case "$out" in *"no merge of the trunk"*) : ;; *) cf "(c) the Next does not say both registers are read and no merge is needed: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-500)" ;; esac
  _forks_sync

  _forks_midwork_entry "$idd" land D-04 "[D-04]"
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$idd" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(d) the hand-off refused (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  _forks_sync
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$idd" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(d) the landing refused a ruling on the trunk since the cut (exit $rc): $(printf '%s' "$out" | tail -8 | tr '\n' '|' | cut -c1-400)"
  origin_has_path "progress/qa_complete/$idd-land.md" || cf "(d) the card did not advance to qa_complete/"
  teardown

  local id ac1_new="- [ ] AC1 — the sandbox's seeded behaviour holds, and now a second condition does too."
  id="$SB_PREFIX-885"
  _forks_drift_land work-e "$id" ac-cited 0 "$ac1_new per [decision: D-01]." "" "none" move
  [ "$_FDL_RC" -ne 0 ] || cf "(e) a changed AC citing D-01 on its bullet under 'forks: none' landed"
  grep -q 'refusal=forks-contradicted' "$SB_TMP/rec"/*.tsv 2>/dev/null || cf "(e) the refusal is not forks-contradicted: $(printf '%s' "$_FDL_OUT" | tail -6 | tr '\n' '|')"
  case "$_FDL_OUT" in *"'forks: [D-NN]'"*"forks-ac-changed-uncited"*) : ;; *) cf "(e) the Next does not name 'forks: [D-NN]' as the exit for a changed AC bullet: $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-700)" ;; esac
  teardown

  id="$SB_PREFIX-886"
  _forks_drift_land work-e2 "$id" ac-cited-ok 0 "$ac1_new per [decision: D-01]." "" "[D-01]" move
  [ "$_FDL_RC" -eq 0 ] || cf "(e) following the Next ('forks: [D-01]') the hand-off still refused (exit $_FDL_RC): $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-300)"
  case "$_FDL_OUT" in *"FORKS_ATTRIBUTION_CHECK: ran"*) : ;; *) cf "(e) the landing did not run the attribution check: $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-300)" ;; esac
  origin_has_path "progress/dev_complete/$id-ac-cited-ok.md" || cf "(e) the card did not reach dev_complete/"
  teardown

  id="$SB_PREFIX-887"
  _forks_drift_land work-f "$id" ac-act 0 "$ac1_new" "- 2026-01-02 [Dev] Applied the ruling. [decision: D-01]" "none" move
  [ "$_FDL_RC" -ne 0 ] || cf "(f) a changed AC with the citation only in the Activity landed"
  grep -q 'refusal=forks-ac-changed-uncited' "$SB_TMP/rec"/*.tsv 2>/dev/null || cf "(f) the refusal is not forks-ac-changed-uncited: $(printf '%s' "$_FDL_OUT" | tail -6 | tr '\n' '|')"
  case "$_FDL_OUT" in *"'forks: [D-NN]'"*) : ;; *) cf "(f) the Next does not name 'forks: [D-NN]': $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-700)" ;; esac
  teardown

  id="$SB_PREFIX-888"
  _forks_drift_land work-f2 "$id" ac-act-ok 0 "$ac1_new per [decision: D-01]." "- 2026-01-02 [Dev] Applied the ruling. [decision: D-01]" "[D-01]" move
  [ "$_FDL_RC" -eq 0 ] || cf "(f) following both Nexts (the bullet's citation and 'forks: [D-01]') the hand-off still refused (exit $_FDL_RC): $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-300)"
  teardown

  id="$SB_PREFIX-889"
  _forks_drift_land work-g "$id" ac-ghost 0 "$ac1_new per [decision: D-98]." "" "none" move
  [ "$_FDL_RC" -ne 0 ] || cf "(g) a changed AC citing an id the register does not hold landed under 'forks: none'"
  grep -q 'refusal=forks-contradicted' "$SB_TMP/rec"/*.tsv 2>/dev/null || cf "(g) the refusal is not forks-contradicted: $(printf '%s' "$_FDL_OUT" | tail -6 | tr '\n' '|')"
  teardown

  id="$SB_PREFIX-890"
  _forks_drift_land work-h "$id" ac-cited-fin 0 "$ac1_new per [decision: D-01]." "" "none" finish
  [ "$_FDL_RC" -ne 0 ] || cf "(h) the landing accepted a changed AC citing D-01 under 'forks: none'"
  grep -q 'refusal=forks-contradicted' "$SB_TMP/rec"/*.tsv 2>/dev/null || cf "(h) the landing's refusal is not forks-contradicted: $(printf '%s' "$_FDL_OUT" | tail -6 | tr '\n' '|')"
  teardown

  id="$SB_PREFIX-891"
  _forks_drift_land work-h2 "$id" ac-cited-fin-ok 0 "$ac1_new per [decision: D-01]." "" "[D-01]" finish
  [ "$_FDL_RC" -eq 0 ] || cf "(h) following the Next, the landing refused (exit $_FDL_RC): $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/qa_complete/$id-ac-cited-fin-ok.md" || cf "(h) the card did not advance to qa_complete/"
  teardown

  # (i) an id the BRANCH retired is not live, though the trunk still holds it.
  _forks_midwork_land "$SB_PREFIX-892" retired "" "[D-01]" retire
  [ "$_FML_RC" -ne 0 ] || cf "(i) 'forks: [D-01]' over an id the branch retired landed"
  grep -q 'refusal=forks-unresolved' "$SB_TMP/rec"/*.tsv 2>/dev/null || cf "(i) the refusal is not forks-unresolved: $(printf '%s' "$_FML_OUT" | tail -6 | tr '\n' '|')"
  teardown

  # (k) a ruling the trunk has withdrawn since pickup, or the branch retires, is not "already made": its Activity citation counts.
  _forks_midwork_land "$SB_PREFIX-893" wd-trunk "" "none" withdraw cite
  [ "$_FML_RC" -ne 0 ] || cf "(k) an Activity citation of a ruling the trunk withdrew landed under 'forks: none'"
  grep -q 'refusal=forks-contradicted' "$SB_TMP/rec"/*.tsv 2>/dev/null || cf "(k) the refusal is not forks-contradicted: $(printf '%s' "$_FML_OUT" | tail -6 | tr '\n' '|')"
  teardown
  _forks_midwork_land "$SB_PREFIX-894" wd-branch "" "none" retire cite
  [ "$_FML_RC" -ne 0 ] || cf "(k) an Activity citation of a ruling the branch retires landed under 'forks: none'"
  grep -q 'refusal=forks-contradicted' "$SB_TMP/rec"/*.tsv 2>/dev/null || cf "(k) the refusal is not forks-contradicted: $(printf '%s' "$_FML_OUT" | tail -6 | tr '\n' '|')"
  teardown

  # (j) ABLATIONS, each alone.
  _forks_midwork_land "$SB_PREFIX-895" abl-trunk _forks_ablate_trunk_live "[D-02]"
  [ "$_FML_RC" -ne 0 ] || cf "ABLATION FAILED — with the trunk's register unread, 'forks: [D-02]' over a trunk-only ruling still landed"
  grep -q 'refusal=forks-unresolved' "$SB_TMP/rec"/*.tsv 2>/dev/null || cf "ABLATION INVALID — refused, but not as forks-unresolved: $(printf '%s' "$_FML_OUT" | tail -6 | tr '\n' '|')"
  teardown
  _forks_midwork_land "$SB_PREFIX-896" abl-retired _forks_ablate_retired_kept "[D-01]" retire
  [ "$_FML_RC" -eq 0 ] || cf "ABLATION FAILED — with the branch's retirement not subtracted, an id the branch retired was still refused (exit $_FML_RC), so (i) is not attributable to the subtraction: $(printf '%s' "$_FML_OUT" | tail -6 | tr '\n' '|')"
  teardown
  _forks_midwork_land "$SB_PREFIX-897" abl-wd _forks_ablate_withdrawn_live "none" withdraw cite
  [ "$_FML_RC" -eq 0 ] || cf "ABLATION FAILED — with a trunk-withdrawn ruling still read as live, the Activity citation was still refused (exit $_FML_RC), so (k) is not attributable to the subtraction: $(printf '%s' "$_FML_OUT" | tail -6 | tr '\n' '|')"
  teardown
  _forks_midwork_land "$SB_PREFIX-898" abl-br _forks_ablate_branch_retired_live "none" retire cite
  [ "$_FML_RC" -eq 0 ] || cf "ABLATION FAILED — with a branch-retired ruling still read as live, the Activity citation was still refused (exit $_FML_RC), so (k) is not attributable to the subtraction: $(printf '%s' "$_FML_OUT" | tail -6 | tr '\n' '|')"
  teardown

  finish "forks: reads the live register set from the branch's and the trunk's copy, so a ruling that landed on the trunk after the cut passes under forks: [D-NN] with no merge and still refuses under 'forks: none' with a Next that says no merge is the exit; a changed AC bullet citing a ruling stays a fork, both refusals name 'forks: [D-NN]' as the exit and following them lands (hand-off and landing); a ruling the trunk withdrew or the branch retires is not 'already made'"
}

# =============================================================================
# CASE — A REGISTER OR CITATION READ THAT FAILED INSIDE THE `forks:` CHECKS REFUSES.
# kit_forks_check and kit_ac_drift_check read the register and the card's citations through the same
# readers as arms [d] [l] [r]. With no failure file named, a read that exited 2 read as "no ruling
# cited", which passed or refused for the wrong reason. One shim per read site exits 2 for that stage
# only, in the landing of a card whose AC was rewritten with its citation on the bullet (it lands
# with the real tools: the control). Each row must refuse forks-register-unreadable, with a Next, and
# merge nothing. (drift) the AC-drift check's own bullet read, on a rewrite with no citation: it must
# refuse as unreadable, not as the uncited change it would have read.
# =============================================================================
case_a_forks_register_read_that_failed_refuses_as_unreadable() {
  cf_reset
  local id n=0 row cmd frag sfrag journey slug dir oldp="$PATH" rec
  dir="$(mktemp -d "${TMPDIR:-/tmp}/forks-shims.XXXXXX")" || { cf "no temp dir"; finish "(no temp dir)"; return 0; }
  # <row>@<command>@<fragment of its arguments>@<fragment of its stdin>@<journey: cited | drift>
  while IFS='@' read -r row cmd frag sfrag journey; do
    [ -n "$row" ] || continue
    n=$((n + 1)); id="$SB_PREFIX-$((870 + n))"; slug="r$n"
    _nr_shim_cmd "$dir/$row" "$cmd" "$frag" "$sfrag"
    PATH="$dir/$row:$oldp"
    if [ "$journey" = drift ]; then
      _forks_drift_land "work-$row" "$id" "$slug" 1 "- [ ] AC1 — the sandbox's seeded behaviour holds, and now a second condition does too." "" "none"
    else
      _forks_drift_land "work-$row" "$id" "$slug" 1 "- [ ] AC1 — the sandbox's seeded behaviour holds, and now a second condition does too [decision: D-01]." "" "[D-01]"
    fi
    PATH="$oldp"
    [ "$_FDL_RC" -ne 0 ] || cf "($row) a register read exited 2 — finish-pr.sh exited 0"
    rec="$(cat "$SB_TMP/rec"/*.tsv 2>/dev/null)"
    printf '%s\n' "$rec" | grep -F 'refusal=forks-register-unreadable' >/dev/null || cf "($row) no progress record carries refusal=forks-register-unreadable: $(printf '%s' "$rec" | cut -c1-200) / $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-240)"
    case "$_FDL_OUT" in *"Next:"*) : ;; *) cf "($row) the refusal names no Next: $(printf '%s' "$_FDL_OUT" | tr '\n' '|' | cut -c1-300)" ;; esac
    origin_has_path "progress/qa_complete/$id-$slug.md" && cf "($row) the card advanced despite the refusal"
    teardown
  done <<'FK_ROWS'
cited@grep@-IaoE'*'forks-cited@@cited
live@grep@-oE ^### D-[0-9]+@D-@cited
retired@sed@-n /^## Retired ids@@cited
drift@grep@-IaoE'*'forks-ac-bullet@@drift
FK_ROWS
  # the control: the same journey with the real tools lands
  id="$SB_PREFIX-880"
  _forks_drift_land work-control "$id" control 1 "- [ ] AC1 — the sandbox's seeded behaviour holds, and now a second condition does too [decision: D-01]." "" "[D-01]"
  [ "$_FDL_RC" -eq 0 ] || cf "(control) the same landing with no shim exited $_FDL_RC: $(printf '%s' "$_FDL_OUT" | tail -6 | tr '\n' '|' | cut -c1-300)"
  teardown
  rm -rf "$dir"
  finish "a register or citation read that exits non-zero inside the forks: checks refuses the landing (refusal=forks-register-unreadable, with a Next) and merges nothing; the same landing with the real tools lands"
}
