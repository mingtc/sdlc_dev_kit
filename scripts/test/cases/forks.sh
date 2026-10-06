# KIT-CLASS: MIXED — self-test harness, the `forks:` landing precondition. See
# process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/forks.sh — sourced by scripts/test/run.sh, never run on its own.
# finish-pr.sh refuses a landing whose card carries no `forks:` field, a malformed one, one
# naming an id that is not a LIVE register entry, or one that CONTRADICTS what the branch itself
# shows (a register D-NN entry the branch's diff adds or changes, or an Activity
# `[decision: D-NN]` citation, absent from `forks:`).
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
  /usr/bin/grep -q '^forks:' "$SB_WORK/progress/dev_complete/$ida-absent.md" \
    && _fixture_die "case_finish_pr_forks_missing_or_malformed_refuses: (a) the forks: line survived the strip"
  publish_sandbox
  seed_branch "$ida" work CHANGE601A.txt

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-a" "$SB_WORK/scripts/finish-pr.sh" "$ida" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) absent 'forks:' — finish-pr.sh exited 0"
  case "$out" in *"forks:"*) : ;; *) cf "(a) the refusal does not name 'forks:': $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "CHANGE601A.txt" && cf "(a) the branch was merged before the refusal"
  origin_has_path "progress/qa_complete/$ida-absent.md" && cf "(a) the card advanced despite the refusal"
  /usr/bin/grep -q 'refusal=forks-missing' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
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
  /usr/bin/grep -q 'refusal=forks-malformed' "$SB_TMP/rec-b"/*.tsv 2>/dev/null \
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
  /usr/bin/grep -q 'refusal=forks-malformed' "$SB_TMP/rec-c"/*.tsv 2>/dev/null \
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

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "an unresolved 'forks:' id — finish-pr.sh exited 0"
  case "$out" in *D-77*) : ;; *) cf "the refusal does not name D-77: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "CHANGE611.txt" && cf "the branch was merged before the refusal"
  /usr/bin/grep -q 'refusal=forks-unresolved' "$SB_TMP/rec"/*.tsv 2>/dev/null \
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
  /usr/bin/grep -q 'refusal=forks-contradicted' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
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
  /usr/bin/grep -q 'refusal=forks-contradicted' "$SB_TMP/rec-b"/*.tsv 2>/dev/null \
    || cf "(b) no progress record carries refusal=forks-contradicted: $(cat "$SB_TMP/rec-b"/*.tsv 2>/dev/null)"

  finish "finish-pr.sh refuses a 'forks: none' the branch itself contradicts — a register D-NN entry its own diff adds, or an Activity '[decision: D-NN]' citation — naming the id either way, with a refusal=forks-contradicted record"
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
  /usr/bin/grep -q 'refusal=forks-contradicted' "$SB_TMP/rec"/*.tsv 2>/dev/null \
    || cf "no progress record carries refusal=forks-contradicted: $(cat "$SB_TMP/rec"/*.tsv 2>/dev/null)"

  finish "finish-pr.sh derives the register set from check-board.sh's own REGISTERS= declaration — a project whose register lives somewhere other than requirements/DECISIONS.md is still caught when its branch adds a D-NN there under a 'forks: none' card"
  teardown
}

# _forks_refix_qa_pointer <file> <repo-relative-path> — seed_issue's QA Verdict AC1 row points at
# the file's SEED-TIME path and line. A case that moves the file (move-issue.sh, git mv) and then
# edits the AC1 bullet must re-point the row at the file's OWN current path and the bullet's new
# line, with the same text quoted verbatim, or kit_qa_verdict_check's pointer/quote resolution
# refuses on a stale pointer that has nothing to do with the behaviour under test.
_forks_refix_qa_pointer() {
  local f="$1" rel="$2" ac1_line ac1_text
  ac1_text="$(grep -E '^- \[ \] AC1' "$f" | head -1)"
  [ -n "$ac1_text" ] || _fixture_die "_forks_refix_qa_pointer: no AC1 bullet in ${f}"
  ac1_line="$(grep -nF -- "$ac1_text" "$f" | head -1 | cut -d: -f1)"
  [ -n "$ac1_line" ] || _fixture_die "_forks_refix_qa_pointer: AC1 bullet line not found in ${f}"
  perl -i -pe "s{^\\| AC1 \\|.*\\|\$}{| AC1 | PASS | test | ${rel}:${ac1_line} \"${ac1_text}\" |}" "$f"
  grep -qF "${rel}:${ac1_line}" "$f" \
    || _fixture_die "_forks_refix_qa_pointer: the QA Verdict row was not re-pointed in ${f}"
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
  # The QA Verdict row's pointer is fixed to the card's CURRENT (in_progress) path NOW, before
  # the branch is cut: kit_qa_verdict_check reads it against the BRANCH tip, and seed_issue's
  # pointer still names the seed-time todo/ path, which the branch would carry forward verbatim.
  _forks_refix_qa_pointer "$SB_WORK/progress/in_progress/$ida-drift.md" "progress/in_progress/$ida-drift.md"
  git -C "$SB_WORK" add "progress/in_progress/$ida-drift.md" >/dev/null 2>&1
  sbcommit -m "[PM] ${ida}: re-point the QA Verdict row at its current path" --quiet >/dev/null 2>&1
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
  /usr/bin/grep -q 'refusal=forks-ac-changed-uncited' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
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
  # Same realistic order as (a): the QA Verdict pointer is re-pointed at the card's CURRENT
  # path and committed BEFORE the branch is cut (the branch carries that forward verbatim),
  # then the branch is cut right after pickup, before the reformat and the dev_complete move,
  # both of which still happen on the trunk.
  _forks_refix_qa_pointer "$SB_WORK/progress/in_progress/$idb-reformat.md" "progress/in_progress/$idb-reformat.md"
  git -C "$SB_WORK" add "progress/in_progress/$idb-reformat.md" >/dev/null 2>&1
  sbcommit -m "[PM] ${idb}: re-point the QA Verdict row at its current path" --quiet >/dev/null 2>&1
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

  finish "finish-pr.sh refuses a landing whose AC text changed after the card left progress/todo/ with no '[decision: D-NN]' citation on the card (refusal=forks-ac-changed-uncited, naming the AC id); a pure separator reformat of the same wording is NOT drift and lands clean"
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
