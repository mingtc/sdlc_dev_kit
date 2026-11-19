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
# CASE — register-commit.sh REFUSES A PATH THAT DIFFERS IN LETTER CASE FROM WHAT THE TRUNK TRACKS. On a
# filesystem that folds case `Progress/…` reaches the same file as `progress/…`, and the guards compare as
# typed. The refusal does not depend on the filesystem. Rows: the card under a mis-cased directory; a new card under one; a mis-cased
# file name; a mis-cased directory over a tracked file; a non-ASCII name (`CAFÉ/` against `Café/`, under a
# UTF-8 locale, skipped where the system's awk folds ASCII only; NFC against NFD is not judged); a name with a quote; then two new paths of one call that differ
# only in case; a control character in a path; a trunk file list that cannot be read; then the controls (the
# tracked spelling lands, a path under a new directory lands, two clean paths land). A trunk that tracks both
# spellings of a directory is judged by the exact one in the case after this one.
# =============================================================================
case_register_commit_refuses_a_path_whose_letter_case_differs_from_the_trunks() {
  cf_reset
  local L="register-commit.sh refuses a path whose directory or file name differs only in letter case from a path the trunk tracks, naming the trunk's spelling and writing nothing, while the tracked spelling and a new directory still land"
  make_sandbox
  local pid="$SB_PREFIX-851" out rc sp want
  seed_issue todo "$pid" first chore "First card"
  mkdir -p "$SB_WORK/docs" "$SB_WORK/Café"; printf 'one\n' > "$SB_WORK/docs/note.md"; printf 'one\n' > "$SB_WORK/Café/x.md"; printf 'one\n' > "$SB_WORK/q\"t.md"
  publish_sandbox
  local l utf8="" utf8why="no UTF-8 locale on this machine"
  for l in en_US.UTF-8 C.UTF-8; do
    [ "$(LC_ALL=$l locale charmap 2>/dev/null)" = UTF-8 ] || continue
    if [ "$(LC_ALL=$l awk 'BEGIN{print tolower("É")}' 2>/dev/null)" = "é" ]; then utf8=1; break; fi
    utf8why="this awk folds ASCII letters only, even under $l"
  done
  # (a) rows: the spelling, and what the Next must name.
  for sp in "Progress/in_progress/$pid-first.md|progress/in_progress/$pid-first.md" "Progress/todo/$SB_PREFIX-852-new.md|progress/todo/$SB_PREFIX-852-new.md" "docs/Note.md|docs/note.md" "Docs/note.md|docs/note.md" 'CAFÉ/x.md|Café/x.md' 'Q"T.md|q"t.md'; do
    want="${sp#*|}"; sp="${sp%%|*}"
    case "$sp" in CAFÉ*) [ -n "$utf8" ] || { skp "register-commit.sh refuses CAFÉ/ against a tracked Café/" "$utf8why"; continue; } ;; esac
    mkdir -p "$SB_WORK/$(dirname "$sp")"
    case "$sp" in Progress/in_progress/*) cp "$SB_WORK/progress/todo/$pid-first.md" "$SB_WORK/$sp" ;; *) printf 'two\n' > "$SB_WORK/$sp" ;; esac
    rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK -u LC_ALL ./scripts/register-commit.sh --role PM --message "spelled" "$sp" 2>&1 )" || rc=$?
    [ "$rc" -eq 1 ] || cf "(a) '$sp' was not refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
    printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "(a) '$sp': no Next line: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
    printf '%s\n' "$out" | grep -F "Next:" | grep -F "'$want'" >/dev/null || cf "(a) '$sp': the Next does not name the trunk's spelling '$want': $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
    git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
    [ "$(git -C "$SB_WORK" ls-tree -r --name-only "origin/$SB_TRUNK" | grep -ic "^$sp\$")" -le 1 ] || cf "(a) '$sp' reached the trunk beside the tracked spelling"
    [ -z "$(git -C "$SB_WORK/.kanban-wt" status --porcelain --untracked-files=no 2>/dev/null)" ] || cf "(a) '$sp' left the kanban worktree dirty"
  done
  # (b) controls: the tracked spelling lands; so does a path under a directory the trunk does not track.
  printf 'three\n' > "$SB_WORK/docs/note.md"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "plain" docs/note.md 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(b) control: the tracked spelling was refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  mkdir -p "$SB_WORK/fresh"; printf 'x\n' > "$SB_WORK/fresh/a.md"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "new dir" fresh/a.md 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(b) control: a path under a new directory was refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  # (b) control: several paths in one call are all judged (awk of some systems refuses a newline in a -v value).
  printf 'p\n' > "$SB_WORK/docs/p.md"; printf 'q\n' > "$SB_WORK/docs/q.md"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "two paths" docs/p.md docs/q.md 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(b) control: two clean paths in one call were refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  printf 'r\n' > "$SB_WORK/docs/r.md"; printf 'two\n' > "$SB_WORK/docs/Note.md"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "second path clashes" docs/r.md docs/Note.md 2>&1 )" || rc=$?
  [ "$rc" -eq 1 ] || cf "(b) the second of two paths was not judged (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$out" | grep -F "Next:" | grep -F "'docs/note.md'" >/dev/null || cf "(b) the second of two paths was refused, but not for its letter case: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  # (c) two NEW paths of one call that differ only in case are refused as a pair.
  mkdir -p "$SB_WORK/NEW" "$SB_WORK/new"; printf 'x\n' > "$SB_WORK/NEW/x"; printf 'y\n' > "$SB_WORK/new/y"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "pair" NEW/x new/y 2>&1 )" || rc=$?
  [ "$rc" -eq 1 ] || cf "(c) two new paths differing only in case were not refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$out" | grep -F "another path of this call" >/dev/null || cf "(c) the pair was refused, but not for each other: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$out" | grep -F "Next:" | grep -F "'NEW/y'" >/dev/null || cf "(c) the Next does not name the one spelling 'NEW/y': $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  # (d) a control character in a path is refused before anything is judged, with a Next.
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "newline" $'zz\nDocs/x' 2>&1 )" || rc=$?
  [ "$rc" -eq 1 ] || cf "(d) a path with a newline was not refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$out" | grep -F "control character" >/dev/null || cf "(d) the refusal does not name a control character: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$out" | grep -F "Next:" >/dev/null || cf "(d) no Next line: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  # (e) a trunk file list that cannot be read refuses with a Next rather than exiting silently.
  mkdir -p "$SB_TMP/shim"; printf '#!/bin/bash\nfor a in "$@"; do [ "$a" = ls-tree ] && { echo "git: simulated ls-tree failure" >&2; exit 128; }; done\nexec %s "$@"\n' "$(command -v git)" > "$SB_TMP/shim/git"; chmod +x "$SB_TMP/shim/git"
  printf 's\n' > "$SB_WORK/docs/s.md"
  rc=0; out="$( cd "$SB_WORK" && PATH="$SB_TMP/shim:$PATH" env -u MSG_OK ./scripts/register-commit.sh --role PM --message "unreadable" docs/s.md 2>&1 )" || rc=$?
  [ "$rc" -eq 1 ] || cf "(e) a failed trunk read did not refuse with 1 (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$out" | grep -F "could not read the trunk's file list" >/dev/null || cf "(e) the refusal does not say the trunk could not be read: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$out" | grep -F "Next:" >/dev/null || cf "(e) no Next line: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  # (f) a case-only rename gets its route in the Next.
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "rename" docs/Note.md 2>&1 )" || rc=$?
  printf '%s\n' "$out" | grep -F "git mv" >/dev/null || cf "(f) the Next does not name git mv for a case-only rename: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A TRUNK THAT TRACKS TWO SPELLINGS OF A DIRECTORY IS JUDGED BY THE EXACT ONE. `docs/a.md` and `Docs/b.md`
# are both tracked (built with git plumbing, so no filesystem has to hold both): a prefix the trunk tracks in
# exactly the spelling given is not a clash, and a third spelling (`DOCS/c.md`) is, naming a tracked one.
# =============================================================================
case_register_commit_judges_a_trunk_that_tracks_two_spellings_by_the_exact_one() {
  cf_reset
  local L="register-commit.sh refuses a third spelling of a directory the trunk tracks in two spellings, naming a tracked one, and does not refuse the two exact spellings for their case"
  make_sandbox
  local out rc blob gd tree commit
  mkdir -p "$SB_WORK/docs"; printf 'a\n' > "$SB_WORK/docs/a.md"
  publish_sandbox
  gd="$(git -C "$SB_WORK" rev-parse --absolute-git-dir)"
  blob="$(printf 'b\n' | git -C "$SB_WORK" hash-object -w --stdin)"
  GIT_INDEX_FILE="$gd/idx851" git -C "$SB_WORK" read-tree "$SB_TRUNK"
  GIT_INDEX_FILE="$gd/idx851" git -C "$SB_WORK" update-index --add --cacheinfo "100644,$blob,Docs/b.md"
  tree="$(GIT_INDEX_FILE="$gd/idx851" git -C "$SB_WORK" write-tree)"
  commit="$(git -C "$SB_WORK" commit-tree "$tree" -p "$SB_TRUNK" -m "seed a second spelling")"
  git -C "$SB_WORK" push -q origin "$commit:refs/heads/$SB_TRUNK" >/dev/null 2>&1
  [ "$(git -C "$SB_ORIGIN" ls-tree -r --name-only "$SB_TRUNK" | grep -c '^[Dd]ocs/')" -eq 2 ] || cf "(setup) the trunk does not track docs/a.md and Docs/b.md"
  mkdir -p "$SB_WORK/DOCS"; printf 'c\n' > "$SB_WORK/DOCS/c.md"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "third" DOCS/c.md 2>&1 )" || rc=$?
  [ "$rc" -eq 1 ] || cf "(a) DOCS/c.md was not refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$out" | grep -F "Next:" | grep -E "'[Dd]ocs/c.md'" >/dev/null || cf "(a) the Next does not name a tracked spelling: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  # The exact spellings are not a clash: whatever else the call does, it is not refused for letter case (the refusal
  # comes before any write, so this holds on a filesystem that cannot hold `docs` and `Docs` side by side too).
  mkdir -p "$SB_WORK/Docs"; printf 'bb\n' > "$SB_WORK/Docs/b.md"; printf 'aa\n' >> "$SB_WORK/docs/a.md"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "exact" docs/a.md Docs/b.md 2>&1 )" || rc=$?
  ! printf '%s\n' "$out" | grep -F "letter case" >/dev/null || cf "(b) an exact tracked spelling was refused for its letter case: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
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
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  if [ ! -f "$REAL_REPO_ROOT/.claude/templates/SUBTASK.template.md" ]; then
    skp_lived "$L" ".claude/templates/SUBTASK.template.md is absent from this tree"; return
  fi
  make_sandbox
  mkdir -p "$SB_WORK/.claude/templates"
  cp -R "$REAL_REPO_ROOT/.claude/templates/." "$SB_WORK/.claude/templates/"
  local pid="$SB_PREFIX-852" out rc bad
  seed_issue dev_complete "$pid" first chore "First card" "feature/$pid-first"
  seed_branch "$pid" first "marker-first.txt"
  publish_sandbox
  for bad in "$SB_PREFIX" "$SB_PREFIX-" "$SB_PREFIX-85x" "$SB_PREFIX-852-s1"; do
    rc=0; out="$( cd "$SB_WORK" && ./scripts/finish-pr.sh "$bad" --dry-run 2>&1 )" || rc=$?
    if [ "$rc" -eq 0 ] || ! printf '%s\n' "$out" | grep -F 'not an issue id' >/dev/null || ! printf '%s\n' "$out" | grep -F 'Next:' >/dev/null; then
      cf "(a) finish-pr.sh '$bad' was not refused as a malformed id with a Next (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
    fi
    rc=0; out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$bad" in_progress --role Dev --note x 2>&1 )" || rc=$?
    if [ "$rc" -eq 0 ] || ! printf '%s\n' "$out" | grep -F 'not an issue id' >/dev/null || ! printf '%s\n' "$out" | grep -F 'Next:' >/dev/null; then
      cf "(b) move-issue.sh '$bad' was not refused as a malformed id with a Next (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
    fi
  done
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  origin_has_path "progress/dev_complete/$pid-first.md" || cf "(b) the card left dev_complete on the trunk"
  rc=0; out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$pid-s1" in_progress --role Dev --note x 2>&1 )" || rc=$?
  if [ "$rc" -eq 0 ] || ! printf '%s\n' "$out" | grep -F "./scripts/subtask.sh move $pid-s1" >/dev/null; then
    cf "(b2) move-issue.sh given a slice id did not point at subtask.sh move (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  fi
  # (c) a bare prefix as the parent of a slice.
  rc=0; out="$( cd "$SB_WORK" && ./scripts/subtask.sh new "$SB_PREFIX" s1 bogus --title T 2>&1 )" || rc=$?
  if [ "$rc" -eq 0 ] || ! printf '%s\n' "$out" | grep -F 'not an issue id' >/dev/null || ! printf '%s\n' "$out" | grep -F 'Next:' >/dev/null; then
    cf "(c) subtask.sh new with a bare prefix as the parent was not refused as a malformed id (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  fi
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  if origin_has_path "progress/subtasks/$SB_PREFIX/todo/$SB_PREFIX-s1-bogus.md"; then cf "(c) a slice was published under the bare prefix"; fi
  # (d) control: a full id with one card is not refused for its shape.
  rc=0; out="$( cd "$SB_WORK" && ./scripts/finish-pr.sh "$pid" --dry-run 2>&1 )" || rc=$?
  if printf '%s\n' "$out" | grep -F 'not an issue id' >/dev/null; then cf "(d) control: a full id was refused as malformed: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"; fi
  # (f) a prefix with a digit in it is a prefix (kit-init takes letters and digits).
  rc=0; ( . "$SB_WORK/scripts/lib/refuse.sh"; kit_require_issue_id P2-001 x ) >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 0 ] || cf "(f) a prefix with a digit (P2-001) was refused as a malformed id (rc=$rc)"
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
  sed "s/^id: .*/id: $n-07/" "$SB_WORK/progress/todo/$n-002-other.md" > "$SB_WORK/progress/todo/$n-07-seven.md"
  sed "s/^id: .*/id: $n-007/" "$SB_WORK/progress/todo/$n-002-other.md" > "$SB_WORK/progress/todo/$n-007-seven.md"
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | grep -i 'DUPLICATE' | grep -E "$n-0+7 is carried" >/dev/null \
    || cf "(c) [d] did not report $n-07 and $n-007 as one number, naming a spelling a file carries: $(printf '%s\n' "$out" | grep -A3 '^\[d\]' | tr '\n' '|' | cut -c1-300)"
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
  # (c2) a no-break space after the id ends it in no locale: the live reader runs in C like the other readers.
  printf '### D-03\xc2\xa0nbsp heading\n### D-04 plain\n' > "$SB_TMP/nbsp.md"
  live="$( . "$SB_WORK/scripts/lib/decision-register.sh"; LC_ALL=en_US.UTF-8 kit_decision_register_live "$SB_TMP/nbsp.md" '### ' 'D-[0-9]+' | tr '\n' ' ' )"
  [ "$live" = "D-04 " ] || cf "(c2) the live reader listed '$live' for a no-break space after D-03, want 'D-04 '"
  # (d) the forks check's two readers of the register agree: the colon heading is no entry at a revision,
  # and no touched entry, so a card is never told to cite an id the live reader then calls not live.
  local fe te
  fe="$( . "$SB_WORK/scripts/lib/refuse.sh"; . "$SB_WORK/scripts/lib/decision-register.sh"; . "$SB_WORK/scripts/lib/qa-gate.sh"; _forks_entry_ids "$SB_WORK" HEAD requirements/DECISIONS.md '### ' 'D-[0-9]+' | tr '\n' ' ' )"
  [ "$fe" = "D-01 D-09 " ] || cf "(d) the forks check's entry reader listed '$fe', want 'D-01 D-09 '"
  printf '\n### D-10: another colon heading\n\n**Ruling.** y\n' >> "$SB_WORK/requirements/DECISIONS.md"
  git -C "$SB_WORK" add requirements/DECISIONS.md >/dev/null 2>&1; sbcommit -q -m "[PM] add a colon heading" >/dev/null 2>&1
  te="$( . "$SB_WORK/scripts/lib/decision-register.sh"; kit_decisions_touched_by_diff "$SB_WORK" HEAD~1 HEAD requirements/DECISIONS.md '### ' | tr '\n' ' ' )"
  case "$te" in *D-10*) cf "(e) the touched-entry reader named the colon heading: '$te'" ;; esac
  finish "$L"
  teardown
}
