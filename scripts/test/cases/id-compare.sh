# KIT-CLASS: MIXED — self-test harness, path and id comparison cases. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/id-compare.sh — sourced by scripts/test/run.sh, never run on its own.
# One class: two strings that name the same thing are compared as typed, so a guard or an id check is
# skipped or fooled. A path spelled `./x` or `a//b`, a bare prefix taken for a card id, `xyz-1` beside
# `xyz-001`, and a colon heading read as an entry by one reader and not by another.
# =============================================================================

# =============================================================================
# CASE — register-commit.sh REFUSES A PATH THAT IS NOT SPELLED CANONICALLY, SO NO GUARD IS SKIPPED BY
# A SPELLING. The card-moved guard compares paths as typed; `./progress/…`, `progress//…` and
# `progress/./…` each named a card path the guard did not recognise, and the card landed twice.
# Rows: the plain spelling refuses as a second copy (control); the spellings refuse before anything is
# written and the trunk gains no second copy; a clean path still lands (control).
# =============================================================================
case_register_commit_refuses_a_path_spelled_non_canonically() {
  cf_reset
  local L="register-commit.sh refuses a path spelled with a leading ./, a // or a . segment, naming a Next and writing nothing, while the canonical spelling is judged by the card-moved guard and a clean path lands"
  make_sandbox
  local pid="$SB_PREFIX-851" out rc sp
  seed_issue todo "$pid" first chore "First card"
  publish_sandbox
  mkdir -p "$SB_WORK/progress/in_progress" "$SB_WORK/docs"
  cp "$SB_WORK/progress/todo/$pid-first.md" "$SB_WORK/progress/in_progress/$pid-first.md"
  # (a) control: the canonical spelling is refused by the card-moved guard.
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "$pid: second copy" "progress/in_progress/$pid-first.md" 2>&1 )" || rc=$?
  if [ "$rc" -ne 1 ] || ! printf '%s\n' "$out" | grep -F 'a second copy of a card' >/dev/null; then
    cf "(a) control: the plain path was not refused as a second copy (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  fi
  # (b) the spellings.
  for sp in "./progress/in_progress/$pid-first.md" "progress//in_progress/$pid-first.md" "progress/./in_progress/$pid-first.md" "progress/in_progress//$pid-first.md"; do
    rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "$pid: spelled" "$sp" 2>&1 )" || rc=$?
    [ "$rc" -eq 1 ] || cf "(b) '$sp' was not refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
    printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "(b) '$sp': no Next line: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
    git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
    if origin_has_path "progress/in_progress/$pid-first.md"; then cf "(b) '$sp' reached the trunk: the card is now in two columns"; fi
    [ -z "$(git -C "$SB_WORK/.kanban-wt" status --porcelain --untracked-files=no 2>/dev/null)" ] || cf "(b) '$sp' left the kanban worktree dirty"
  done
  rm -f "$SB_WORK/progress/in_progress/$pid-first.md"
  # (c) control: a clean path lands.
  printf 'x\n' > "$SB_WORK/docs/a.md"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "plain note" docs/a.md 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(c) control: a clean path was refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE MOVERS TAKE A FULL ISSUE ID, NEVER A PREFIX. A bare prefix matched the first card
# `find -name "<id>-*.md"` listed, so finish-pr.sh gated another card's history and subtask.sh minted
# a slice under whichever card came first. Each refuses a malformed id with a Next before reading the
# board, and finish-pr.sh refuses two cards for one id rather than taking the last.
# =============================================================================
case_the_movers_refuse_a_bare_prefix_for_an_issue_id() {
  cf_reset
  local L="finish-pr.sh, move-issue.sh and subtask.sh new refuse a bare prefix or a malformed id with a Next and change nothing, and finish-pr.sh refuses two cards for one id"
  if [ ! -f "$REAL_REPO_ROOT/.claude/templates/SUBTASK.template.md" ]; then
    skp_lived "$L" ".claude/templates/SUBTASK.template.md is absent from this tree"; return
  fi
  make_sandbox
  mkdir -p "$SB_WORK/.claude/templates"
  cp -R "$REAL_REPO_ROOT/.claude/templates/." "$SB_WORK/.claude/templates/"
  local pid="$SB_PREFIX-852" out rc bad
  seed_issue dev_complete "$pid" first chore "First card"
  publish_sandbox
  for bad in "$SB_PREFIX" "$SB_PREFIX-" "$SB_PREFIX-85x" "$SB_PREFIX-852-s1"; do
    rc=0; out="$( cd "$SB_WORK" && ./scripts/finish-pr.sh "$bad" --dry-run 2>&1 )" || rc=$?
    if [ "$rc" -eq 0 ] || ! printf '%s\n' "$out" | grep -F 'is not an issue id' >/dev/null || ! printf '%s\n' "$out" | grep -F 'Next:' >/dev/null; then
      cf "(a) finish-pr.sh '$bad' was not refused as a malformed id with a Next (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
    fi
    rc=0; out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$bad" in_progress --role Dev --note x 2>&1 )" || rc=$?
    if [ "$rc" -eq 0 ] || ! printf '%s\n' "$out" | grep -F 'is not an issue id' >/dev/null || ! printf '%s\n' "$out" | grep -F 'Next:' >/dev/null; then
      cf "(b) move-issue.sh '$bad' was not refused as a malformed id with a Next (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
    fi
  done
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  origin_has_path "progress/dev_complete/$pid-first.md" || cf "(b) the card left dev_complete on the trunk"
  # (c) a bare prefix as the parent of a slice.
  rc=0; out="$( cd "$SB_WORK" && ./scripts/subtask.sh new "$SB_PREFIX" s1 bogus --title T 2>&1 )" || rc=$?
  if [ "$rc" -eq 0 ] || ! printf '%s\n' "$out" | grep -F 'is not an issue id' >/dev/null || ! printf '%s\n' "$out" | grep -F 'Next:' >/dev/null; then
    cf "(c) subtask.sh new with a bare prefix as the parent was not refused as a malformed id (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  fi
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  if origin_has_path "progress/subtasks/$SB_PREFIX/todo/$SB_PREFIX-s1-bogus.md"; then cf "(c) a slice was published under the bare prefix"; fi
  # (d) control: a full id with one card is not refused for its shape.
  rc=0; out="$( cd "$SB_WORK" && ./scripts/finish-pr.sh "$pid" --dry-run 2>&1 )" || rc=$?
  if printf '%s\n' "$out" | grep -F 'is not an issue id' >/dev/null; then cf "(d) control: a full id was refused as malformed: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"; fi
  # (e) two cards for one id: refused, naming both, not the last silently.
  seed_issue dev_complete "$pid" second chore "Second card"
  publish_sandbox
  rc=0; out="$( cd "$SB_WORK" && ./scripts/finish-pr.sh "$pid" --dry-run 2>&1 )" || rc=$?
  if [ "$rc" -eq 0 ] || ! printf '%s\n' "$out" | grep -F "multiple files match $pid-*.md" >/dev/null \
     || ! printf '%s\n' "$out" | grep -F "$pid-first.md" >/dev/null || ! printf '%s\n' "$out" | grep -F "$pid-second.md" >/dev/null; then
    cf "(e) finish-pr.sh did not refuse two cards for one id naming both (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  fi
  finish "$L"
  teardown
}

# =============================================================================
# CASE — AN ISSUE ID IS ITS INTEGER. `xyz-1`, `xyz-001` and `xyz-0001` are one number; new-issue.sh
# refuses the second spelling of a taken number and check-board [d] reports two cards carrying one
# number as a duplicate, where it read `✓ none` over three cards for 1.
# =============================================================================
case_an_issue_id_is_its_integer_not_its_spelling() {
  cf_reset
  local L="new-issue.sh refuses a short or padded spelling of a taken number, and check-board [d] reports two cards for one number as a duplicate"
  if ! has_kit_init; then skp "$L" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  local out rc id n="$SB_PREFIX"
  rc=0; out="$( cd "$SB_WORK" && ./scripts/new-issue.sh first --id "$n-001" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || _fixture_die "case_an_issue_id_is_its_integer_not_its_spelling: the first mint exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  for id in "$n-1" "$n-0001" "$n-01"; do
    rc=0; out="$( cd "$SB_WORK" && ./scripts/new-issue.sh again --id "$id" 2>&1 )" || rc=$?
    if [ "$rc" -eq 0 ] || ! printf '%s\n' "$out" | grep -F 'Next:' >/dev/null; then
      cf "(a) new-issue.sh --id $id was not refused beside $n-001 (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
    fi
    [ ! -e "$SB_WORK/progress/todo/$id-again.md" ] || cf "(a) --id $id created a second card for number 1"
  done
  rc=0; out="$( cd "$SB_WORK" && ./scripts/new-issue.sh other --id "$n-002" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(b) control: a free number was refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  # (c) [d] over two cards for one number, planted by hand.
  sed "s/^id: .*/id: $n-7/" "$SB_WORK/progress/todo/$n-002-other.md" > "$SB_WORK/progress/todo/$n-7-seven.md"
  sed "s/^id: .*/id: $n-007/" "$SB_WORK/progress/todo/$n-002-other.md" > "$SB_WORK/progress/todo/$n-007-seven.md"
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | grep -i 'DUPLICATE' | grep -F "$n-7" >/dev/null \
    || cf "(c) [d] did not report $n-7 and $n-007 as one number: $(printf '%s\n' "$out" | grep -A3 '^\[d\]' | tr '\n' '|' | cut -c1-300)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A HEADING'S ID ENDS AT THE SAME PLACE IN EVERY READER. `### D-08: title` was a live id to the
# arms that list the register (the id is followed by `:`), and not an entry to the one that cuts it into
# entries, which wants a space or the end of the line. Now the colon heading is no entry to any, and
# [d] says so by name instead of counting it.
# =============================================================================
case_a_heading_id_ends_at_the_same_place_in_every_reader() {
  cf_reset
  local L="kit_decision_register_live and the entry cutter read a colon heading the same way (not an entry), and check-board [d] names it as a heading its readers will not take"
  make_sandbox
  local reg="$SB_TMP/DECISIONS.md" live spans out
  printf '# DECISIONS\n\n## A. bucket\n\n### D-01 — a ruling\n\n**Ruling.** x\n\n### D-08: colon heading\n\n### D-09\n\n' > "$reg"
  live="$( . "$SB_WORK/scripts/lib/decision-register.sh"; kit_decision_register_live "$reg" '### ' 'D-[0-9]+' | tr '\n' ' ' )"
  [ "$live" = "D-01 D-09 " ] || cf "(a) the live reader listed '$live', want 'D-01 D-09 '"
  spans="$( . "$SB_WORK/scripts/lib/board-properties.sh"; _bp_entry_spans "$reg" '### ' 'D-[0-9]+' | awk '{print $1}' | tr '\n' ' ' )"
  [ "$spans" = "D-01 D-09 " ] || cf "(b) the entry cutter listed '$spans', want 'D-01 D-09 '"
  mkdir -p "$SB_WORK/requirements"; cp "$reg" "$SB_WORK/requirements/DECISIONS.md"
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | grep -F 'D-08:' | grep -i 'space' >/dev/null \
    || cf "(c) [d] did not name the colon heading: $(printf '%s\n' "$out" | grep -A6 '^\[d\]' | tr '\n' '|' | cut -c1-300)"
  finish "$L"
  teardown
}
