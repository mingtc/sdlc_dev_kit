# KIT-CLASS: MIXED — self-test harness, check-board cases. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/check-board.sh — sourced by scripts/test/run.sh, never run on its own.
# check-board.sh's arms, and the cb_* / _lived_signals helpers other families call.
# =============================================================================

# _lived_signals — the signals arm [g] reads to decide whether this repository has STARTED,
# derived as the arm derives them, never enumerated in part: a guard over a subset passes until
# a case seeds a signal it does not cover.
#
# It is the INSTRUMENT, deliberately NOT collapsed into scripts/lib/lived-probe.sh: a fixture that
# asked the subject what to check would agree with it by construction. It must move when the
# library does, and a divergence fails LOUDLY: a fixture carrying only a signal this copy lacks
# lets the arm run, and the not-run case then fails naming the arm.
_lived_signals() {  # prints one line per signal present; empty output means "not started"
  local col n log arc cols
  [ -f "$SB_WORK/scripts/config.sh" ] && grep -q "^$KIT_STAMP_MARK" "$SB_WORK/scripts/config.sh" 2>/dev/null \
    && echo "the initializer's stamp receipt in scripts/config.sh"
  # THE COLUMNS ARE DERIVED from the declaration the arm reads, never a literal list.
  IFS='|' read -r -a cols <<< "$(cb_status_folders)"
  [ "${#cols[@]}" -gt 0 ] \
    || _fixture_die "_lived_signals: STATUS_FOLDERS could not be read from lib/status-folders.sh — the board signal would be skipped entirely and every guard built on this would pass over a board it never looked at."
  for col in "${cols[@]}"; do
    [ -d "$SB_WORK/progress/$col" ] || continue
    n="$(find "$SB_WORK/progress/$col" -type f -name '*-[0-9]*.md' 2>/dev/null | wc -l | tr -d ' ')"
    [ "${n:-0}" -gt 0 ] && echo "progress/$col/ carries $n issue file(s)"
  done
  if [ -f "$SB_WORK/progress.md" ]; then
    log="$(awk '/^##[[:space:]]/ { if (inlog) exit; if ($0 ~ /^##[[:space:]]+Log([[:space:]]|$)/) { inlog=1; next } } inlog && NF { print }' "$SB_WORK/progress.md" 2>/dev/null | wc -l | tr -d ' ')"
    [ "${log:-0}" -gt 0 ] && echo "progress.md § Log holds ${log} line(s)"
  fi
  if [ -f "$SB_WORK/ARCHIVE.md" ]; then
    arc="$(awk '/^## Archived$/ { a=1; next } a && NF { print }' "$SB_WORK/ARCHIVE.md" 2>/dev/null | wc -l | tr -d ' ')"
    [ "${arc:-0}" -gt 0 ] && echo "ARCHIVE.md indexes ${arc} line(s)"
  fi
  return 0
}

# Read arm [g]'s SECTION from a check-board report: from its header to the next arm's header or
# the `──` verdict line. Never a fixed `grep -A<n>` window: a line added to the arm pushes an
# assertion out of it, and a missing match then reads as a finding. Both stops are needed: the
# header test alone runs into the verdict when [g] is the last arm, and `──` alone would not
# stop at a following arm.
_cb_a_section() {  # reads a check-board report on stdin
  awk '/^\[a\]/ { f = 1; print; next }
       f && /^(\[|──)/ { exit }
       f'
}

_cb_g_section() {  # reads a check-board report on stdin
  awk '/^\[g\]/ { f = 1 }
       f && /^──/ { exit }
       f && /^\[[a-z]\]/ && !/^\[g\]/ { exit }
       f'
}

# _cb_g_declare_empty_seams — declares $SB_WORK/scripts/config.sh's CODE_GLOBS and TEST_GLOBS
# deliberately empty (the `# DECLARED EMPTY —` mechanical form). Every case that graduates the
# sandbox (fills PROJECT.md, replaces AGENTS.md/README.md) needs this too, or [g]'s new
# CODE_GLOBS/TEST_GLOBS members report unfilled and graduation never reads COMPLETE (which also
# needs `_cb_g_land_day_one_work`: a PRD and a card past QA) — the same transition
# case_check_board_graduation exercises directly; the callers here only need [g] clear, not the
# glob content itself. ONE caller, not three copies: _fixture_die names which
# anchor moved if either does not match.
_cb_g_declare_empty_seams() {
  local _arr
  for _arr in CODE_GLOBS TEST_GLOBS; do
    _cb_g_fill_glob_array "$_arr" "  # DECLARED EMPTY -- fixture ($_arr)."
  done
}

# _cb_g_fill_glob_array <array-name> <entry-line> — the ONE authoring site for inserting a line
# (a real glob entry, or a `# DECLARED EMPTY —` sentinel) right after an array's opening paren in
# $SB_WORK/scripts/config.sh. Shared by every case exercising CODE_GLOBS/TEST_GLOBS, so a moved
# anchor is caught once, not per call site.
_cb_g_fill_glob_array() {
  local _arr="$1" _entry="$2" _cfg="$SB_WORK/scripts/config.sh"
  grep -qE "^${_arr}=\($" "$_cfg" \
    || _fixture_die "_cb_g_fill_glob_array: no '^${_arr}=(' line in the sandbox's scripts/config.sh — the anchor moved."
  perl -i -pe 'BEGIN{$c=0; $a=shift; $e=shift} if (!$c && /^\Q$a\E=\($/) { $_ .= "$e\n"; $c=1 }' \
    "$_arr" "$_entry" "$_cfg"
  grep -qxF "$_entry" "$_cfg" \
    || _fixture_die "_cb_g_fill_glob_array: ${_arr}'s entry was NOT inserted."
}

# _cb_g_discharge_gitignore_env — fills $SB_WORK/.gitignore's build-artifact section and
# $SB_WORK/.env.example's credentials block with a minimal real entry, clearing their `FILL ME.`
# sentinel. make_sandbox never seeds either (the real kit ships both, filled, on day one), so a
# case that graduates the sandbox needs this too, or [g]'s FILL (.gitignore)/(.env.example)
# members read ABSENT — unmeasured, never clean — and graduation never reaches COMPLETE.
_cb_g_discharge_gitignore_env() {
  printf '# .gitignore\n# ── build artifacts ──\n# produced by this fixture build\ndist/\n' \
    > "$SB_WORK/.gitignore"
  printf '# .env.example\n# ── project credentials ──\n# READ_TOKEN=   # read-only\n' \
    > "$SB_WORK/.env.example"
}

# _cb_g_seed_prd / _cb_g_seed_landed_card <folder> — the day-one work arm [g] asks for (SEED steps 6
# and 7), one half each: a file matching the PRD surface, and one card in the named column. The PRD
# glob is written out here, never read from check-board.sh (a fixture that derives its operand from
# the arm it judges agrees with it by construction); the card goes through seed_issue, the harness's
# one card writer.
_cb_g_seed_prd() {
  mkdir -p "$SB_WORK/requirements"
  printf '# PRD-001 — fixture product\n\nOne spec, scoped on day one.\n' > "$SB_WORK/requirements/PRD-001-fixture.md"
}
_cb_g_seed_landed_card() {  # <qa_complete|done>
  seed_issue "$1" "$SB_PREFIX-899" day-one-card chore "The first card through the boundary"
}
# _cb_g_land_day_one_work — both halves, for a case that graduates the sandbox and expects COMPLETE.
_cb_g_land_day_one_work() {
  _cb_g_seed_prd
  _cb_g_seed_landed_card qa_complete
}

# _cb_g_discharge_delete_if_unused — records a KEPT-ON-PURPOSE decision in
# $SB_WORK/process/LOCAL-PROCEDURES.md for every file the sandbox carries that declares
# KIT-DISPOSITION: DELETE-IF-UNUSED, in arm [g]'s own exact form. make_sandbox copies the REAL
# scripts/ tree (so every script that declares the marker arrives carrying it) and conditionally the real consumers/ tree; every case that graduates the sandbox needs
# this too, or [g]'s new DELETE-IF-UNUSED class reports unfilled and graduation never reads
# COMPLETE — the same transition case_check_board_graduation exercises directly, mirroring
# _cb_g_declare_empty_seams for CODE_GLOBS/TEST_GLOBS above. DERIVED from the sandbox's own
# markers, never a literal copy of the member list: a member added or dropped from the real kit
# changes what this discharges without this helper having to change to match.
_cb_g_discharge_delete_if_unused() {
  local _decl='^[[:space:]]*(#|<!--|//|--)?[[:space:]]*KIT-DISPOSITION:[[:space:]]*DELETE-IF-UNUSED([^A-Za-z0-9_]|$)'
  mkdir -p "$SB_WORK/process"
  [ -f "$SB_WORK/process/LOCAL-PROCEDURES.md" ] || printf '# LOCAL-PROCEDURES.md\n\n' > "$SB_WORK/process/LOCAL-PROCEDURES.md"
  local _f _n=0
  while IFS= read -r -d '' _f; do
    [ -f "$SB_WORK/$_f" ] || continue
    sed -n '1,12p' "$SB_WORK/$_f" | grep -E "$_decl" >/dev/null || continue
    printf -- '- **`%s` (DELETE-IF-UNUSED) kept, on purpose.** Fixture discharge.\n' "$_f" >> "$SB_WORK/process/LOCAL-PROCEDURES.md"
    _n=$((_n+1))
  # --untracked: this helper may run before the sandbox's first commit (a case that discharges
  # before its first publish_sandbox), when the copied scripts/notify*.sh are not yet tracked —
  # a plain `git grep` sees only tracked files and would find nothing on such a tree.
  done < <(git -C "$SB_WORK" grep --untracked -lzE "$_decl" -- 2>/dev/null || true)
  # Nothing to discharge is right only on a tree whose every DELETE-IF-UNUSED member was removed.
  [ "$_n" -gt 0 ] || _delete_if_unused_members_all_removed \
    || _fixture_die "_cb_g_discharge_delete_if_unused: no file in the sandbox declares KIT-DISPOSITION: DELETE-IF-UNUSED — the real scripts/notify*.sh marker this helper relies on has moved or been removed."
}

# _cb_g_a_declaring_file — one file the sandbox still carries that declares DELETE-IF-UNUSED, for a
# case to expect a finding to NAME. Derived from the sandbox, never a typed path: a project may have
# removed any member. Prints nothing when none remains.
_cb_g_a_declaring_file() {
  local _decl='^[[:space:]]*(#|<!--|//|--)?[[:space:]]*KIT-DISPOSITION:[[:space:]]*DELETE-IF-UNUSED([^A-Za-z0-9_]|$)' _f
  while IFS= read -r -d '' _f; do
    sed -n '1,12p' "$SB_WORK/$_f" | grep -E "$_decl" >/dev/null && { printf '%s' "$_f"; return 0; }
  done < <(git -C "$SB_WORK" grep --untracked -lzE "$_decl" -- 2>/dev/null || true)
  return 0
}

# _cb_g_remove_delete_if_unused_members — removes, from $SB_WORK, every file that declares
# KIT-DISPOSITION: DELETE-IF-UNUSED (and consumers/), a valid discharge. The population is read
# from the tree BEFORE the removal, never typed, so a member added to the kit is removed too.
_cb_g_remove_delete_if_unused_members() {
  local _decl='^[[:space:]]*(#|<!--|//|--)?[[:space:]]*KIT-DISPOSITION:[[:space:]]*DELETE-IF-UNUSED([^A-Za-z0-9_]|$)'
  local _gone _gf
  _gone="$(git -C "$SB_WORK" grep --untracked -lE "$_decl" -- || true)"
  while IFS= read -r _gf; do [ -n "$_gf" ] && rm -f "$SB_WORK/$_gf"; done <<GONE_EOF
$_gone
GONE_EOF
  rm -rf "$SB_WORK/consumers"
}

# Same shape as _cb_g_section, for arm [l] (declared reference integrity).
_cb_l_section() {  # reads a check-board report on stdin
  awk '/^\[l\]/ { f = 1 }
       f && /^──/ { exit }
       f && /^\[[a-z]\]/ && !/^\[l\]/ { exit }
       f'
}

# Same shape as _cb_g_section, for arm [q] (declared-register entry shape).
_cb_q_section() {  # reads a check-board report on stdin
  awk '/^\[q\]/ { f = 1 }
       f && /^──/ { exit }
       f && /^\[[a-z]\]/ && !/^\[q\]/ { exit }
       f'
}

# Same shape as _cb_g_section, for arm [r] (declared reverse coverage).
_cb_r_section() {  # reads a check-board report on stdin
  awk '/^\[r\]/ { f = 1 }
       f && /^──/ { exit }
       f && /^\[[a-z]\]/ && !/^\[r\]/ { exit }
       f'
}

# Same shape as _cb_g_section, for arm [s] (model pins vs the ladder).
_cb_s_section() {  # reads a check-board report on stdin
  awk '/^\[s\]/ { f = 1 }
       f && /^──/ { exit }
       f && /^\[[a-z]\]/ && !/^\[s\]/ { exit }
       f'
}

# Same shape as _cb_g_section, for arm [t] (answered questions the register has not cited).
_cb_t_section() {  # reads a check-board report on stdin
  awk '/^\[t\]/ { f = 1 }
       f && /^──/ { exit }
       f && /^\[[a-z]\]/ && !/^\[t\]/ { exit }
       f'
}

# cb_set_dep <id> <slug> <folder> <blocks|blocked_by> <target-id>
# Rewrite one dependency field into a seeded card's frontmatter. seed_issue does NOT emit
# these keys, so this INSERTS before the CLOSING fence — the second `---`, never the
# first. A fixture that did not take is FATAL, not a case failure: every assertion built
# on it would then be about a board with no dependencies at all, and would report PASS.
cb_set_dep() {
  local id="$1" slug="$2" folder="$3" key="$4" target="$5"
  local f="$SB_WORK/progress/$folder/${id}-${slug}.md"
  [ -f "$f" ] || _fixture_die "cb_set_dep: no card at $f"
  awk -v k="$key" -v t="$target" '
    /^---[[:space:]]*$/ { n++; if (n == 2) printf "%s: [%s]\n", k, t }
    { print }
  ' "$f" > "$f.new" && mv "$f.new" "$f"
  grep -qF "$key: [$target]" "$f" \
    || _fixture_die "cb_set_dep: '$key: [$target]' did not land in $f — the symmetry case would run against a board with no dependency declared and would report PASS about nothing."
}

# Run the SANDBOX copy of check-board.sh with CLAUDE_PROJECT_DIR unset: inherited, it would point
# the copy at the REAL board.
cb_run() { ( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR "$SB_WORK/scripts/check-board.sh" --full "$@" 2>&1 ); }
# The report as the SessionStart hook and a session close read it: findings first, clean arms folded.
cb_run_default() { ( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR "$SB_WORK/scripts/check-board.sh" 2>&1 ); }

# CASE — check-board's [j] arm joins the downtime queue to the board, and CLASSIFIES the
# Status cell rather than grepping it.
#
# A queue row can read `open` for a cure already on the trunk, and a stale row looks exactly like
# a live one. The fixture carries the shapes a naive `grep -c '| open |'` gets wrong: emphasis, a
# trailing `Status:` declaration that must win over the cell's opening words, a struck row and a
# live claim in todo/ that must NOT fire, and the angle-bracket SHAPE row, which is documentation.
case_downtime_queue_claim_drift() {
  cf_reset
  make_sandbox
  local out
  mkdir -p "$SB_WORK/dev"
  cat > "$SB_WORK/dev/downtime-queue.md" <<'DQEOF'
| Item | Origin | Size | Why deferred | Wake condition | Status |
|---|---|---|---|---|---|
| `<shape row>` | `<x>` | `<S/M/L>` | `<y>` | `<z>` | `<open / open (claimed by <PREFIX>-NNN) / STRUCK …>` |
| **Landed already** | audit | S | — | now | open (claimed by ZZQ-101) |
| **Still live** | audit | S | — | now | open (claimed by ZZQ-102) |
| **Emphasis + trailing decl** | audit | M | — | now | *was struck* — Status: **open (claimed by ZZQ-103)** |
| **Genuinely struck** | audit | S | — | — | STRUCK — landed as ZZQ-104, outcome fine |
DQEOF
  : > "$SB_WORK/progress/done/ZZQ-101-a.md"
  : > "$SB_WORK/progress/todo/ZZQ-102-b.md"
  : > "$SB_WORK/progress/done/ZZQ-103-c.md"
  : > "$SB_WORK/progress/done/ZZQ-104-d.md"

  # SCOPE THE ASSERTIONS TO THE [j] SECTION: arms [a] and [d] also name these ids, because the
  # fixture puts real cards on the board (instruments.md § A.6).
  _j_section() { cd "$SB_WORK" && ./scripts/check-board.sh --full 2>&1 | awk '/^\[j\]/{f=1;print;next} f&&/^\[/{f=0} f'; }
  out="$(_j_section)"

  # --- must fire -----------------------------------------------------------------
  printf '%s' "$out" | grep 'ZZQ-101' >/dev/null \
    || cf "an open row whose issue is in progress/done/ was NOT reported"
  printf '%s' "$out" | grep 'ZZQ-103' >/dev/null \
    || cf "the emphasised row with a trailing 'Status:' declaration was NOT reported — the cell is being grepped, not classified"

  # --- must NOT fire -------------------------------------------------------------
  printf '%s' "$out" | grep 'ZZQ-102' >/dev/null \
    && cf "a LIVE claim (issue still in todo/) was reported — the arm fires on any open row, not on landed ones"
  printf '%s' "$out" | grep 'ZZQ-104' >/dev/null \
    && cf "a STRUCK row was reported — the arm does not read the Status cell's verdict"
  printf '%s' "$out" | grep 'PREFIX' >/dev/null \
    && cf "the angle-bracket SHAPE row was read as data"

  # --- informational, and that is a ruling ---------------------------------------
  printf '%s' "$out" | grep '^\[j\]' >/dev/null \
    || cf "the [j] arm did not print its header, so its subject is unnamed"

  # --- the ABSENT subject still prints (contracts/drift-report.md § 4) ------------
  rm -f "$SB_WORK/dev/downtime-queue.md"
  out="$(_j_section)"
  printf '%s' "$out" | grep 'not present' >/dev/null \
    || cf "with no queue file the arm went SILENT instead of naming what was absent"

  # --- ABLATION: the clean case must be distinguishable from the finding case -----
  cat > "$SB_WORK/dev/downtime-queue.md" <<'DQEOF'
| Item | Origin | Size | Why deferred | Wake condition | Status |
|---|---|---|---|---|---|
| **Still live** | audit | S | — | now | open (claimed by ZZQ-102) |
DQEOF
  out="$(_j_section)"
  printf '%s' "$out" | grep 'no open row claims a landed issue' >/dev/null \
    || cf "(ablation) a queue with only LIVE claims did not report the clean line, so a green here proves nothing"

  unset -f _j_section
  finish "check-board [j]: an open queue row whose claiming issue has landed is reported; a live claim, a struck row and the shape row are not; the Status cell is CLASSIFIED (emphasis + trailing declaration) rather than grepped; an absent queue names itself; ablation-proven"
  teardown
}

# =============================================================================
# CASE — [j]'s finding carries the ⚠ the default report folds on
#
#   The default report folds an arm that holds no ⚠, so a finding line without one is hidden from the
#   report a session reads: (a) a landed claim stays in view, names the row, and [j] is not among the
#   arms folded as clean; (b) ablation — with only a live claim the arm folds and the report says clean,
#   so (a) is not a report that never folds [j]. Neither changes the verdict.
# =============================================================================
case_check_board_arm_j_finding_is_not_folded() {
  cf_reset
  make_sandbox
  local out fold
  mkdir -p "$SB_WORK/dev"
  printf '%s\n' '| Item | Origin | Size | Why deferred | Wake condition | Status |' '|---|---|---|---|---|---|' \
    '| Landed already | audit | S | — | now | open (claimed by ZZQ-301) |' > "$SB_WORK/dev/downtime-queue.md"
  : > "$SB_WORK/progress/done/ZZQ-301-a.md"
  out="$(cb_run_default)"
  printf '%s' "$out" | grep 'ZZQ-301 claims an OPEN row' >/dev/null \
    || cf "(a) the default report hides a landed claim [j] found: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  fold="$(printf '%s\n' "$out" | grep '^── no findings, folded' || true)"
  case "$fold" in *'[j'*) cf "(a) the default report folds [j] as clean over its finding: $fold" ;; esac

  printf '%s\n' '| Item | Origin | Size | Why deferred | Wake condition | Status |' '|---|---|---|---|---|---|' \
    '| Still live | audit | S | — | now | open (claimed by ZZQ-302) |' > "$SB_WORK/dev/downtime-queue.md"
  : > "$SB_WORK/progress/todo/ZZQ-302-b.md"
  out="$(cb_run_default)"
  fold="$(printf '%s\n' "$out" | grep '^── no findings, folded' || true)"
  case "$fold" in *'[j'*) : ;; *) cf "(b) ablation: a queue with only a live claim was not folded, so (a) proves nothing: $fold" ;; esac

  finish "check-board [j]: a landed claim's finding line carries the ⚠ the default report folds on, so the folded report shows it; a queue with only live claims still folds"
  teardown
}

# =============================================================================
# CASE — [j] reads the tree the report names, from any directory
#
#   (a) run from dev/ (the SessionStart hook does not cd), the queue is still found;
#   (b) with the queue deleted from the checkout only, the trunk's copy is still read —
#       a fix that reads "$REPO_ROOT/…" passes (a) and reddens here.
# =============================================================================
case_check_board_arm_j_reads_the_named_source() {
  cf_reset
  make_sandbox
  local out
  mkdir -p "$SB_WORK/dev"
  printf '%s\n' '| Item | Origin | Size | Why deferred | Wake condition | Status |' '|---|---|---|---|---|---|' \
    '| Landed already | audit | S | — | now | open (claimed by ZZQ-201) |' > "$SB_WORK/dev/downtime-queue.md"
  : > "$SB_WORK/progress/done/ZZQ-201-a.md"
  publish_sandbox
  origin_has_path "dev/downtime-queue.md" || _fixture_die "case_check_board_arm_j_reads_the_named_source: the queue is not on the trunk."

  _j_at() { ( cd "$1" && "$SB_WORK/scripts/check-board.sh" --full 2>&1 ) | awk '/^\[j\]/{f=1;print;next} f&&/^\[/{f=0} f'; }
  out="$(_j_at "$SB_WORK/dev")"
  printf '%s' "$out" | grep 'ZZQ-201' >/dev/null || cf "(a) run from dev/, [j] did not report the landed claim: $(printf '%s' "$out" | tr '\n' '|')"
  printf '%s' "$out" | grep 'read from: ' >/dev/null || cf "(a) [j] does not name the source it read: $(printf '%s' "$out" | head -1)"

  rm "$SB_WORK/dev/downtime-queue.md"
  out="$(_j_at "$SB_WORK")"
  printf '%s' "$out" | grep 'ZZQ-201' >/dev/null || cf "(b) with the queue absent from the checkout only, [j] did not read the trunk's: $(printf '%s' "$out" | tr '\n' '|')"

  unset -f _j_at
  finish "check-board [j]: reads the queue and the landed columns from the tree the report names, from any directory, and prints that source"
  teardown
}

cb_default() {  # <VAR_NAME>
  sed -n "s/^$1='\(.*\)'/\1/p" "$REAL_SCRIPTS/check-board.sh" 2>/dev/null | head -1
}

# cb_status_folders — the status folder set, from the one file that declares it (lib/status-folders.sh).
cb_status_folders() {
  sed -n "s/^KIT_STATUS_FOLDERS='\(.*\)'/\1/p" "$REAL_SCRIPTS/lib/status-folders.sh" 2>/dev/null | head -1
}

# cb_default_seam <VAR_NAME> — for the OTHER shape a default takes, the repointable-seam form
# `NAME="${NAME:-path}"` (DQ_FILE, CORPUS_FILE): cb_default's quoting does not match it.
cb_default_seam() {  # <VAR_NAME>
  sed -n "s/^$1=\"\\\${$1:-\\([^}\"]*\\)}\".*/\\1/p" "$REAL_SCRIPTS/check-board.sh" 2>/dev/null | head -1
}

# seed_issue_mismatched <folder> <filename_id> <slug> <frontmatter_id>
seed_issue_mismatched() {
  local folder="$1" file_id="$2" slug="$3" fm_id="$4"
  seed_issue "$folder" "$file_id" "$slug" chore "Mismatch fixture"
  local f="$SB_WORK/progress/$folder/${file_id}-${slug}.md"
  sed -i.bak "1,/^---[[:space:]]*\$/s/^id:.*/id: ${fm_id}/" "$f"
  rm -f "$f.bak"
}

# Strip check (d) out of the SANDBOX copy. The control leg asserts a finding disappears, so a
# pass is attributable to the check rather than to whatever the script emitted.
cb_remove_check_d() {
  local s="$SB_WORK/scripts/check-board.sh"
  grep -q '# BEGIN check (d)' "$s" \
    || { cf "(control) no '# BEGIN check (d)' seam in check-board.sh — cannot ablate"; return 1; }
  sed -i.bak '/# BEGIN check (d)/,/# END check (d)/d' "$s"; rm -f "$s.bak"
  grep -q '# BEGIN check (d)' "$s" && { cf "(control) the ablation removed nothing"; return 1; }
  bash -n "$s" || { cf "(control) the ablated check-board.sh no longer parses"; return 1; }
  return 0
}

# =============================================================================
# check-board.sh check (d): frontmatter id integrity
# =============================================================================
# Two cards can carry the same `id:` on the trunk under different slugs, which git never flags.
# No capability probe for the check, on purpose: it would turn the check being deleted into a
# SKIP instead of a FAIL. The constants are read from the REAL check-board.sh (cb_default) and the
# status folder set from the REAL lib/status-folders.sh (cb_status_folders), so an edit there cannot
# make these assertions vacuous.
case_check_board_id_clean() {
  cf_reset
  make_sandbox

  # Derive the three constants, and prove the derivation itself is live — an empty
  # value means the defaults block moved.
  local status_folders id_key id_pattern ncols
  status_folders="$(cb_status_folders)"
  id_key="$(cb_default ISSUE_ID_KEY)"
  id_pattern="$(cb_default ISSUE_ID_PATTERN)"
  [ -n "$status_folders" ] || cf "could not derive the status folder set from lib/status-folders.sh"
  [ -n "$id_key" ]         || cf "could not derive ISSUE_ID_KEY from the defaults block"
  [ -n "$id_pattern" ]     || cf "could not derive ISSUE_ID_PATTERN from the defaults block"
  # No column count: a new status would redden this case, not the property. What matters is
  # that the split worked (an unsplit blob matches nothing) and that done/ is present.
  ncols="$(printf '%s' "$status_folders" | tr '|' '\n' | grep -c . || true)"
  [ "$ncols" -gt 1 ] || cf "STATUS_FOLDERS did not split into columns — derived '$status_folders'"
  printf '%s' "$status_folders" | tr '|' '\n' | grep -x done >/dev/null \
    || cf "STATUS_FOLDERS lacks done/ — a new mint can collide with an ARCHIVED issue"

  seed_issue todo        "$SB_PREFIX-100" alpha chore "Healthy alpha"
  seed_issue in_progress "$SB_PREFIX-101" beta  chore "Healthy beta"
  seed_issue done        "$SB_PREFIX-102" gamma chore "Healthy gamma"

  # NEAR MISS — an id mentioned in PROSE, and a frontmatter shape QUOTED in the body at line
  # start. A whole-file grep for '^id:' would read one as the card's own id. The parse must be
  # anchored to the frontmatter block.
  cat >> "$SB_WORK/progress/todo/$SB_PREFIX-100-alpha.md" <<EOF

This paragraph supersedes progress/done/$SB_PREFIX-379-old.md and quotes a
frontmatter verbatim, at line start, exactly as a reader would paste it:

id: $SB_PREFIX-999
id: $SB_PREFIX-101

- 2026-01-02 [PM] Cross-references $SB_PREFIX-101 and $SB_PREFIX-102 in prose only.
EOF

  publish_sandbox

  local out rc
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc on a healthy board (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep '^\[d\]' >/dev/null || cf "no [d] section in the report — the check is absent"
  printf '%s\n' "$out" | grep -i 'duplicate' >/dev/null \
    && cf "a duplicate finding on a HEALTHY board — prose mentions were misread: $out"
  printf '%s\n' "$out" | grep -i 'disagrees' >/dev/null && cf "a mismatch finding on a HEALTHY board: $out"
  printf '%s\n' "$out" | grep "$SB_PREFIX-999" >/dev/null \
    && cf "an id quoted in prose was read as frontmatter: $out"
  printf '%s\n' "$out" | grep 'board-drift: clean ✓' >/dev/null \
    || cf "the healthy board did not report clean: $out"

  finish "check (d): a healthy board reads clean, and prose/quoted-frontmatter near-misses do not fire"
  teardown
}

# =============================================================================
# CASE — check-board.sh WITH ITS STATUS FOLDER LIBRARY GONE REACHES THE NAMED CONTROL, NOT AN UNBOUND VARIABLE.
#   Arm (a) says "(control) ... checked NOTHING" when no column survives the derivation, and sets the
#   verdict to drift. On bash 3.2 an empty array under `set -u` is an unbound variable, so the line was
#   unreachable and the report died at the loop before it.
# =============================================================================
case_check_board_without_its_status_folder_library_names_the_control() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-100" alpha chore "Healthy alpha"
  publish_sandbox
  [ -f "$SB_WORK/scripts/lib/status-folders.sh" ] || _fixture_die "${FUNCNAME[0]}: the sandbox has no scripts/lib/status-folders.sh to remove"
  rm -f "$SB_WORK/scripts/lib/status-folders.sh"
  local out rc
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc without its status folder library (exit 0 ALWAYS): $(printf '%s' "$out" | tail -3 | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$out" | grep -F 'unbound variable' >/dev/null && cf "check-board.sh died on an unbound variable without its status folder library: $(printf '%s' "$out" | grep -F 'unbound variable' | head -1)"
  printf '%s\n' "$out" | grep -F '(control) no column survived the STATUS_FOLDERS derivation' | grep -F 'checked NOTHING' >/dev/null \
    || cf "arm (a) did not say it checked NOTHING: $(printf '%s' "$out" | tail -4 | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -F 'scripts/lib/status-folders.sh is missing' >/dev/null || cf "the control line does not name the missing library"
  printf '%s\n' "$out" | grep -F 'board-drift: findings above' >/dev/null || cf "the report does not end on a findings verdict: $(printf '%s' "$out" | tail -2 | tr '\n' '|' | cut -c1-240)"
  finish "check-board.sh without scripts/lib/status-folders.sh exits 0, says arm (a) checked NOTHING and names the missing library, and reaches its verdict line instead of dying on an unbound array on bash 3.2"
  teardown
}

case_check_board_id_duplicate() {
  cf_reset
  make_sandbox

  # CROSS-COLUMN duplicate (todo/ vs done/): the reason arm [d] reads the whole board.
  seed_issue todo "$SB_PREFIX-195" first-shape  bug   "Dev-filed bug"
  seed_issue done "$SB_PREFIX-195" second-shape spike "PM-minted spike"
  # SAME-COLUMN duplicate, different slugs.
  seed_issue todo "$SB_PREFIX-300" same-column-one chore "Same column one"
  seed_issue todo "$SB_PREFIX-300" same-column-two chore "Same column two"
  # A TRIPLE — all three files must be named.
  seed_issue blocked      "$SB_PREFIX-400" triple-a chore "Triple a"
  seed_issue qa_complete  "$SB_PREFIX-400" triple-b chore "Triple b"
  seed_issue dev_complete "$SB_PREFIX-400" triple-c chore "Triple c"
  # A healthy control that must NOT be named.
  seed_issue in_progress "$SB_PREFIX-500" innocent chore "Innocent bystander"
  publish_sandbox

  local out rc dline
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc with planted duplicates (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep 'board-drift: findings above' >/dev/null \
    || cf "the duplicates did not reach the report footer: $out"

  dline="$(printf '%s\n' "$out" | grep -i 'duplicate' | grep "$SB_PREFIX-195" || true)"
  [ -n "$dline" ] || cf "no duplicate finding naming $SB_PREFIX-195: $out"
  printf '%s' "$dline" | grep "$SB_PREFIX-195-first-shape.md" >/dev/null \
    || cf "the $SB_PREFIX-195 finding does not name the todo/ file: $dline"
  printf '%s' "$dline" | grep "$SB_PREFIX-195-second-shape.md" >/dev/null \
    || cf "the $SB_PREFIX-195 finding does not name the done/ file — cross-column breadth missing: $dline"

  dline="$(printf '%s\n' "$out" | grep -i 'duplicate' | grep "$SB_PREFIX-300" || true)"
  [ -n "$dline" ] || cf "no duplicate finding naming the same-column pair: $out"
  printf '%s' "$dline" | grep 'same-column-one.md' >/dev/null || cf "the pair finding omits file one: $dline"
  printf '%s' "$dline" | grep 'same-column-two.md' >/dev/null || cf "the pair finding omits file two: $dline"

  dline="$(printf '%s\n' "$out" | grep -i 'duplicate' | grep "$SB_PREFIX-400" || true)"
  [ -n "$dline" ] || cf "no duplicate finding naming the triple: $out"
  printf '%s' "$dline" | grep 'triple-a.md' >/dev/null || cf "the triple omits a: $dline"
  printf '%s' "$dline" | grep 'triple-b.md' >/dev/null || cf "the triple omits b: $dline"
  printf '%s' "$dline" | grep 'triple-c.md' >/dev/null || cf "the triple omits c: $dline"

  printf '%s\n' "$out" | grep -i 'duplicate' | grep "$SB_PREFIX-500" >/dev/null \
    && cf "the innocent single-id issue was named as a duplicate: $out"

  # ACTIONABLE, not merely accusatory — it says what to do, in the same register.
  printf '%s\n' "$out" | grep -i 'duplicate' | grep 'next-id.sh' >/dev/null \
    || cf "the duplicate finding does not say what to do (next-id.sh)"
  printf '%s\n' "$out" | grep -i 'duplicate' | grep '⚠' >/dev/null \
    || cf "the duplicate finding does not use the ⚠ register of the other checks"

  # CONTROL — ablate check (d) and the finding must vanish.
  if cb_remove_check_d; then
    out="$(cb_run)"; rc=$?
    [ "$rc" -eq 0 ] || cf "(control) the ablated check-board.sh exited $rc"
    printf '%s\n' "$out" | grep -i 'duplicate' >/dev/null \
      && cf "(control) a duplicate finding survived the ablation — this case proves nothing: $out"
    printf '%s\n' "$out" | grep 'board-drift: clean ✓' >/dev/null \
      || cf "(control) without check (d) the duplicate board did not read clean, so the finding is not attributable to it: $out"
  fi

  finish "check (d): duplicate ids reported cross-column, same-column and as a triple (all files named), exit 0, ablation-proven"
  teardown
}

case_check_board_id_mismatch() {
  cf_reset
  make_sandbox

  seed_issue_mismatched todo         "$SB_PREFIX-200" ahead-fixture  "$SB_PREFIX-201"
  seed_issue_mismatched dev_complete "$SB_PREFIX-210" behind-fixture "$SB_PREFIX-205"
  # Degenerate frontmatters: no id at all, and a malformed one. This reporter runs
  # inside the SessionStart hook — it must degrade to a finding, never crash.
  seed_issue blocked "$SB_PREFIX-220" no-id chore "No id at all"
  sed -i.bak '/^id:/d' "$SB_WORK/progress/blocked/$SB_PREFIX-220-no-id.md"
  rm -f "$SB_WORK/progress/blocked/$SB_PREFIX-220-no-id.md.bak"
  seed_issue_mismatched qa_complete "$SB_PREFIX-230" malformed "not-an-id-at-all"
  seed_issue in_progress "$SB_PREFIX-240" healthy chore "Healthy"
  publish_sandbox

  local out rc line
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc with planted mismatches (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep -iE 'traceback|syntax error|command not found|unbound variable' >/dev/null \
    && cf "the reporter emitted an interpreter error on a degenerate frontmatter: $out"
  printf '%s\n' "$out" | grep 'board-drift: findings above' >/dev/null \
    || cf "the mismatches did not reach the report footer: $out"

  line="$(printf '%s\n' "$out" | grep "$SB_PREFIX-200-ahead-fixture.md" || true)"
  [ -n "$line" ] || cf "no finding for the frontmatter-AHEAD mismatch: $out"
  printf '%s' "$line" | grep "$SB_PREFIX-201" >/dev/null || cf "the ahead finding does not name the frontmatter id: $line"
  printf '%s' "$line" | grep "$SB_PREFIX-200" >/dev/null || cf "the ahead finding does not name the filename id: $line"
  line="$(printf '%s\n' "$out" | grep "$SB_PREFIX-210-behind-fixture.md" || true)"
  [ -n "$line" ] || cf "no finding for the frontmatter-BEHIND mismatch: $out"
  printf '%s' "$line" | grep "$SB_PREFIX-205" >/dev/null || cf "the behind finding does not name the frontmatter id: $line"
  printf '%s\n' "$out" | grep "$SB_PREFIX-220-no-id.md" >/dev/null \
    || cf "an issue with NO frontmatter id produced no finding: $out"
  printf '%s\n' "$out" | grep "$SB_PREFIX-230-malformed.md" >/dev/null \
    || cf "an issue with a MALFORMED frontmatter id produced no finding: $out"
  printf '%s\n' "$out" | grep "$SB_PREFIX-240-healthy.md" >/dev/null \
    && cf "the healthy control issue was reported: $out"

  # CONTROL — ablate check (d) and every finding must vanish.
  if cb_remove_check_d; then
    out="$(cb_run)"; rc=$?
    [ "$rc" -eq 0 ] || cf "(control) the ablated check-board.sh exited $rc"
    printf '%s\n' "$out" | grep "$SB_PREFIX-200-ahead-fixture.md" >/dev/null \
      && cf "(control) a mismatch finding survived the ablation — this case proves nothing: $out"
    printf '%s\n' "$out" | grep 'board-drift: clean ✓' >/dev/null \
      || cf "(control) without check (d) the mismatched board did not read clean: $out"
  fi

  finish "check (d): id/filename mismatch both directions + missing/malformed degrade to findings, exit 0, ablation-proven"
  teardown
}

# =============================================================================
# CASE — ARM [f1]: THE MAIN CHECKOUT IS WATCHED TOO.
#
# METADATA (rulings, PRDs, issue edits, role docs, process/**, progress.md) commits direct to the
# trunk from the main checkout, not from the board mover's worktree, so an unpushed commit there
# must be reported.
#
# Both directions, so neither half can be vacuous:
#   (i)  a committed-but-unpushed trunk commit in the main checkout IS reported, and
#        the finding names that home rather than the auxiliary one;
#   (ii) once pushed, it is NOT reported — so the arm is measuring publication state
#        and not merely "a commit exists".
# =============================================================================
case_check_board_main_checkout_unpushed() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-220" watched chore "Main-checkout watch"
  publish_sandbox

  local out rc
  # A metadata commit made the way every ruling is made: in the main checkout, on the
  # trunk, direct — and NOT pushed.
  printf '\n### D-01 — a ruling nobody else can see yet\n' >> "$SB_WORK/progress.md"
  git -C "$SB_WORK" add progress.md >/dev/null 2>&1
  sbcommit -qm "[PM] record a ruling" >/dev/null 2>&1
  [ "$(git -C "$SB_WORK" rev-list --count "origin/$SB_TRUNK..refs/heads/$SB_TRUNK" 2>/dev/null)" = "1" ] \
    || cf "(control) the sandbox is not actually 1 commit ahead — the premise does not exist"

  # --- (i) it must be reported, and named as the MAIN checkout -----------------
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep '\[f1\]' >/dev/null \
    || cf "(i) no [f1] reading at all — the main checkout is still unwatched: $out"
  printf '%s\n' "$out" | grep '\[f1\]' | grep -i 'ahead' >/dev/null \
    || cf "(i) [f1] did not report the unpushed commit: $(printf '%s\n' "$out" | grep '\[f1\]')"
  printf '%s\n' "$out" | grep 'board-drift: findings above' >/dev/null \
    || cf "(i) unpushed metadata did not reach the report footer: $out"
  # The finding must be attributed to the right home, or it is indistinguishable from
  # the auxiliary worktree's own divergence.
  printf '%s\n' "$out" | grep '\[f1\]' | grep -i 'main checkout' >/dev/null \
    || cf "(i) the [f1] finding does not name the main checkout as the home: $(printf '%s\n' "$out" | grep '\[f1\]')"

  # --- (ii) ABLATION: push it, and it must go quiet ----------------------------
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc after the push (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep '\[f1\]' | grep -i 'ahead of' >/dev/null \
    && cf "(ii) ABLATION FAILED — [f1] still reports the commit as unpublished after it was pushed, so half (i) proves nothing: $(printf '%s\n' "$out" | grep '\[f1\]')"
  printf '%s\n' "$out" | grep '\[f1\]' | grep '✓' >/dev/null \
    || cf "(ii) [f1] did not report clean after the push: $(printf '%s\n' "$out" | grep '\[f1\]')"

  # And the green states its span rather than implying total coverage.
  printf '%s\n' "$out" | grep -i 'orphaned sibling' >/dev/null \
    || cf "the [f] green does not state its span — an unqualified pass implies it saw stranding it cannot see: $out"

  finish "check-board [f1]: an unpushed metadata commit in the MAIN checkout is reported and named as that home, and goes quiet once pushed (ablation-proven); the green states its span"
  teardown
}

# =============================================================================
# CASE — CHECK (d)'s REGISTER ARM: the identifier space with no textual conflict.
#
# Two legs minting the same `### D-NN` in DIFFERENT SECTIONS of an append-only register produce
# no textual conflict, so a rebase merges both and the duplicate lands with no witness. Leg (2)
# is that shape. The register's path, mark and shape are DERIVED from the script's REGISTERS
# record, never re-typed.
# =============================================================================
case_check_board_registers() {
  cf_reset
  make_sandbox

  local registers reg_path reg_mark reg_shape out rc
  registers="$(cb_default REGISTERS)"
  [ -n "$registers" ] || { cf "could not derive REGISTERS from the defaults block"; finish "check (d): the register arm"; teardown; return; }
  reg_path="${registers%%|*}"
  reg_mark="$(printf '%s' "$registers" | awk -F'|' '{print $2}')"
  reg_shape="$(printf '%s' "$registers" | awk -F'|' '{print $3}')"
  [ -n "$reg_path" ]  || cf "the derived register path is empty ($registers)"
  [ -n "$reg_mark" ]  || cf "the derived heading mark is empty ($registers)"
  [ -n "$reg_shape" ] || cf "the derived id shape is empty ($registers)"
  mkdir -p "$SB_WORK/$(dirname "$reg_path")"

  # --- (1) CLEAN: distinct ids, reported distinct, with the file named ---------
  cat > "$SB_WORK/$reg_path" <<EOF
# DECISIONS
## A. First bucket
${reg_mark}D-01 — first
## B. Second bucket
${reg_mark}D-02 — second
EOF
  publish_sandbox
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(1) check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep "$reg_path" >/dev/null \
    || cf "(1) the arm does not name the register it read: $out"
  printf '%s\n' "$out" | grep "$reg_path" | grep '2 distinct' >/dev/null \
    || cf "(1) a clean register was not reported as 2 distinct: $(printf '%s\n' "$out" | grep "$reg_path")"
  printf '%s\n' "$out" | grep -i 'DUPLICATE id' >/dev/null \
    && cf "(1) a duplicate was reported on a clean register: $out"
  printf '%s\n' "$out" | grep 'board-drift: clean ✓' >/dev/null || cf "(1) a clean register did not read clean: $out"

  # --- (2) THE CROSS-SECTION DUPLICATE: no textual conflict, must be caught ----
  cat > "$SB_WORK/$reg_path" <<EOF
# DECISIONS
## A. First bucket
${reg_mark}D-07 — minted by one leg
${reg_mark}D-01 — unrelated
## B. Second bucket
${reg_mark}D-07 — minted by another leg, in a different section, no conflict
EOF
  publish_sandbox
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(2) check-board.sh exited $rc with a planted duplicate (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep -i 'DUPLICATE id' >/dev/null \
    || cf "(2) a CROSS-SECTION duplicate was NOT reported — this is the collision the arm exists for and it produces no textual conflict: $out"
  printf '%s\n' "$out" | grep -i 'DUPLICATE id' | grep 'D-07' >/dev/null \
    || cf "(2) the duplicate finding does not name D-07: $(printf '%s\n' "$out" | grep -i 'DUPLICATE')"
  printf '%s\n' "$out" | grep 'board-drift: findings above' >/dev/null \
    || cf "(2) the duplicate did not reach the report footer: $out"

  # --- (3) THE D-9 / D-10 MAXIMUM, asserted AGAINST the wrong answer ----------
  # D-10 sits ABOVE D-9. Both plausible wrong readings (positional `tail -1`, byte-compare sort)
  # give 9, so asserting NOT 9 is what makes this sharp.
  cat > "$SB_WORK/$reg_path" <<EOF
# DECISIONS
## A. First bucket
${reg_mark}D-10 — later id, earlier in the file
## B. Second bucket
${reg_mark}D-9 — earlier id, later in the file
EOF
  publish_sandbox
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(3) check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep "$reg_path" | grep 'highest id number 10' >/dev/null \
    || cf "(3) the maximum was not reported as 10 over a section-grouped register: $(printf '%s\n' "$out" | grep "$reg_path")"
  printf '%s\n' "$out" | grep "$reg_path" | grep 'highest id number 9' >/dev/null \
    && cf "(3) the maximum was reported as 9 — that is BOTH wrong answers (positional tail and byte-compare sort agree on it), so the read is not order-independent: $(printf '%s\n' "$out" | grep "$reg_path")"
  printf '%s\n' "$out" | grep -i 'DUPLICATE id' >/dev/null \
    && cf "(3) D-9 and D-10 were read as duplicates — the id shape is matching too little: $out"

  finish "check (d) register arm: a clean register reads distinct and names its file, a CROSS-SECTION duplicate (no textual conflict) is caught by id, and the maximum over a section-grouped register is 10 and not 9 (asserted against both wrong answers)"
  teardown
}

# =============================================================================
# CASE — AN ABSENT REGISTER SKIPS, AND THE CLEARANCE SAYS NOTHING WAS READ.
#
# Separate from the case above because the assertion is about the CLEARANCE LINE: it must never
# claim ids are distinct on a run where every register was SKIPPED (instruments.md § A.4). A tick
# that covers nothing tells its reader the registers are clean.
# =============================================================================
case_check_board_register_absent() {
  cf_reset
  make_sandbox
  local registers reg_path out rc
  registers="$(cb_default REGISTERS)"
  reg_path="${registers%%|*}"
  [ -n "$reg_path" ] || { cf "could not derive the register path"; finish "check (d): an absent register"; teardown; return; }
  [ ! -e "$SB_WORK/$reg_path" ] \
    || cf "(control) the sandbox already has $reg_path — this case's premise is that it is absent"
  seed_issue todo "$SB_PREFIX-230" noreg chore "No register here"
  publish_sandbox

  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep "$reg_path" >/dev/null \
    || cf "the absent register is not mentioned at all — a silently omitted line is the defect drift-report.md § 3 names: $out"
  printf '%s\n' "$out" | grep "$reg_path" | grep -i 'skipped' >/dev/null \
    || cf "the absent register was not reported as skipped: $(printf '%s\n' "$out" | grep "$reg_path")"
  # THE CLEARANCE MUST NOT COVER IT.
  printf '%s\n' "$out" | grep -i 'NO register was read' >/dev/null \
    || cf "the clearance line does not say NO register was read — a pass over unread operands: $out"
  printf '%s\n' "$out" | grep -i 'distinct in every declared register' >/dev/null \
    && cf "the clearance claims every declared register's ids are distinct on a run where none was read: $out"
  printf '%s\n' "$out" | grep 'board-drift: clean ✓' >/dev/null \
    || cf "an absent register should not itself be a finding: $out"

  finish "check (d): an absent register SKIPS with its reason and the clearance line says NO register was read — never a tick covering unread operands"
  teardown
}

# =============================================================================
# CASE — ARM (l): DECLARED REFERENCE INTEGRITY. A citation resolves, or it is a
# finding — and a MENTION is never a citation.
#
# The arm reads a declared marker, never a bare `D-NN` grep rescued by stripping comments: a
# multiline HTML-comment strip can pair a `<!--` in a shell string with a distant `-->` and
# delete most of a file, which then reads as clean. Leg (4) keeps that design honest: a card that
# DISCUSSES ids, one inside a comment, is READ and yields zero citations.
# Leg (5): a retired row names its successor, so a bare id grep over § Retired ids would mark the
# LIVE successor retired, a false red on a correct citation.
# Every operand is DERIVED from check-board.sh's declarations, never re-typed.
# =============================================================================
case_check_board_citations() {
  cf_reset
  make_sandbox

  local registers reg_path reg_mark exclude prd_dir prd_file out rc
  registers="$(cb_default REGISTERS)"
  exclude="$(sed -n "/^CITATION_EXCLUDE='/,/'\$/p" "$REAL_SCRIPTS/check-board.sh" | sed "s/^CITATION_EXCLUDE='//; s/'\$//")"
  [ -n "$registers" ] || { cf "could not derive REGISTERS"; finish "arm (l): citations"; teardown; return; }
  [ -n "$exclude" ]   || cf "could not derive CITATION_EXCLUDE from check-board.sh"
  reg_path="${registers%%|*}"
  reg_mark="$(printf '%s' "$registers" | awk -F'|' '{print $2}')"
  # The citing document's home: requirements/ — a real project surface, and not one of the
  # declared exclusions (the population is now "everything except CITATION_EXCLUDE").
  prd_dir="requirements"
  prd_file="PRD-001-cites.md"
  while IFS= read -r _excl_line; do
    case "$_excl_line" in
      'requirements/') cf "the fixture's own citing directory (requirements/) is one of CITATION_EXCLUDE's entries — this case would then prove nothing" ;;
    esac
  done <<< "$exclude"
  mkdir -p "$SB_WORK/$(dirname "$reg_path")" "$SB_WORK/$prd_dir"

  # The register the citations resolve against: D-01 and D-02 live, nothing retired.
  cat > "$SB_WORK/$reg_path" <<EOF
# DECISIONS
## A. First bucket
${reg_mark}D-01 — first
${reg_mark}D-02 — second

## Retired ids

\`<none yet>\` <!-- e.g. \`D-07\` — retired <date>; the scope it held moved into D-11. -->

## Findings
EOF

  # --- (1) A LIVE citation resolves, and the arm names what it read --------------
  printf '## Decision Log\n- `[decision: D-01]` — a live ruling\n' > "$SB_WORK/$prd_dir/$prd_file"
  publish_sandbox
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(1) check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep '^\[l\]' >/dev/null \
    || cf "(1) arm [l] did not print at all — a silent check is itself a finding (drift-report.md § 4): $out"
  printf '%s\n' "$out" | grep '^\[l\]' | grep -i 'reports only' >/dev/null \
    && cf "(1) arm [l] declares itself 'reports only' — it DECIDES the verdict, and that token is the machine contract for an ADVISORY arm: $(printf '%s\n' "$out" | grep '^\[l\]')"
  printf '%s\n' "$out" | grep "$reg_path" | grep -i 'live id' >/dev/null \
    || cf "(1) the arm does not name the register it resolved against: $out"
  printf '%s\n' "$out" | grep -i '1 citation(s)' >/dev/null \
    || cf "(1) the citation count was not reported — an unfalsifiable reading: $out"
  printf '%s\n' "$out" | grep 'board-drift: clean ✓' >/dev/null \
    || cf "(1) a resolving citation reddened the board: $out"

  # --- (2) A DANGLING citation IS a finding, and it DECIDES ----------------------
  printf '## Decision Log\n- `[decision: D-77]` — an id nobody minted\n' > "$SB_WORK/$prd_dir/$prd_file"
  publish_sandbox
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(2) check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | _cb_l_section | grep '⚠' | grep 'D-77' >/dev/null \
    || cf "(2) a dangling citation was NOT reported: $out"
  printf '%s\n' "$out" | grep 'board-drift: findings above' >/dev/null \
    || cf "(2) the dangling citation did not reach the verdict — the maintainer ruled this arm DECIDING: $out"
  # THROUGH THE REAL CONSUMER: kit-init's board self-check drops advisory arms by token.
  printf '%s\n' "$out" \
    | awk '/^\[[a-z]\]/ { adv = (index($0, "reports only") > 0) } adv { next } { print }' \
    | grep '⚠' | grep 'D-77' >/dev/null \
    || cf "(2) the finding does not survive kit-init's advisory filter, so it would not hold a gate shut: $out"

  # --- (3) A RETIRED id cited as live is a DIFFERENT finding, named as retired ---
  # POSIX sed only — the kit requires git and a POSIX shell and nothing else.
  # The retired ROW names its successor, which is the shape leg (5) then probes.
  sed -i.bak 's|^`<none yet>`.*|`D-02` — retired 2026-01-01; its scope moved into D-01.|' "$SB_WORK/$reg_path"
  rm -f "$SB_WORK/$reg_path.bak"
  grep -q '^`D-02` — retired' "$SB_WORK/$reg_path" \
    || cf "(3 setup) the retired row was not planted — this leg and leg (5) would both pass vacuously"
  printf '## Decision Log\n- `[decision: D-02]` — cites a retired handle\n' > "$SB_WORK/$prd_dir/$prd_file"
  publish_sandbox
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(3) check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | _cb_l_section | grep '⚠' | grep 'D-02' | grep -i 'RETIRED' >/dev/null \
    || cf "(3) a citation of a RETIRED id was not reported as retired — that is a different finding from a dangling one and must print as one: $out"
  printf '%s\n' "$out" | _cb_l_section | grep '⚠' | grep 'D-02' | grep -i 'NOT an entry' >/dev/null \
    && cf "(3) the retired citation printed as a DANGLING one — the two findings ask the reader for different things: $out"

  # --- (5) THE SUCCESSOR NAMED IN THE RETIRED ROW IS STILL LIVE ------------------
  # With the register still holding the row above ("`D-02` — retired …; its scope moved into
  # D-01"), a citation of D-01 must stay CLEAN.
  printf '## Decision Log\n- `[decision: D-01]` — the LIVE successor named in the retired row\n' > "$SB_WORK/$prd_dir/$prd_file"
  publish_sandbox
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(5) check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | _cb_l_section | grep '⚠' | grep 'D-01' >/dev/null \
    && cf "(5) the LIVE successor named inside the retired row was itself reported — the retired set is matching the row's prose, not the row's own id, which FALSE-REDS a correct citation: $out"
  printf '%s\n' "$out" | grep "$reg_path" | grep '1 retired id' >/dev/null \
    || cf "(5) the retired set is not 1 — one row retires exactly one id: $(printf '%s\n' "$out" | grep "$reg_path")"

  # --- (4) THE HAZARD REGRESSION: A MENTION IS NOT A CITATION --------------------
  # The card below names a dangling id, a retired id, and one inside an HTML comment,
  # and carries NO marker. It must be READ (so this is a real negative, not a skip)
  # and yield ZERO citations.
  printf '%s\n' \
    '# A card that DISCUSSES rulings' \
    'It talks about D-77 and about D-02 and about D-01 at length.' \
    '<!-- a comment mentioning D-99 -->' \
    'None of those is a citation: there is no marker anywhere in this file.' \
    > "$SB_WORK/$prd_dir/$prd_file"
  publish_sandbox
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(4) check-board.sh exited $rc (exit 0 ALWAYS)"
  # A real negative: the file COUNT must be nonzero (it was read, not skipped) and the CITATION
  # count zero (nothing in it was read as a citation).
  printf '%s\n' "$out" | _cb_l_section | grep -E '[1-9][0-9]* file\(s\) read, 0 citation' >/dev/null \
    || cf "(4) the mention-only card was not READ-with-zero-citations — a real negative must show files were read, not skipped: $(printf '%s\n' "$out" | _cb_l_section)"
  printf '%s\n' "$out" | _cb_l_section | grep '⚠' | grep -E 'D-77|D-99|D-02' >/dev/null \
    && cf "(4) a MENTION was read as a CITATION — this is the hazard the positive marker exists for, and a bare-id reader fails exactly here: $out"

  finish "arm (l): a live citation resolves and is counted, a dangling one is a DECIDING finding that survives kit-init's advisory filter, a retired one prints as retired rather than dangling, the LIVE successor named inside a retired row is not itself reported, and a card that merely MENTIONS ids (one of them inside an HTML comment) is READ and yields zero citations"
  teardown
}

# =============================================================================
# CASE — A MEMBERSHIP TEST READS ITS WHOLE LIST, NOT UNTIL THE READER LEAVES.
#
# `printf '%s\n' "$list" | grep -qx "$id"` under pipefail: grep -q exits at its first match, a
# printf still writing dies of SIGPIPE, pipefail makes the pipeline's status that death, and an id
# that IS in the list reads as absent. At a realistic size the writer has usually finished, so the
# fault shows on an occasional run and not on its rerun. This case removes the luck: the cited id is
# the FIRST line of a list well over the pipe buffer, so the writer is always still writing when the
# reader leaves. Driven through the real reader, check-board.sh arm [l], on both of its tests: the
# live-id test (a present id read as dangling) and the retired-id test (a retired id read as merely
# dangling, a different finding). The ids are long, so a list past the buffer stays a few dozen
# entries and the arms that loop over entries finish quickly. The report is read from a file: it is
# itself longer than the pipe buffer, so piping it to an early-leaving reader would repeat the fault.
# =============================================================================
CB_WIDE=2000   # digits in a fixture register id: D-[0-9]+ takes any width

_cb_wide_id() { printf "D-%0${CB_WIDE}d" "$1"; }   # <n> — one fixed width, so ids sort by n

_cb_big_register() {  # <path> <entry-mark> live|retired <count> — the cited id, _cb_wide_id 1, sorts first
  awk -v mark="$2" -v kind="$3" -v n="$4" -v w="$CB_WIDE" 'BEGIN {
    f = "D-%0" w "d"
    print "# DECISIONS"; print "## A. Bucket"
    if (kind == "live") { for (i = 1; i <= n; i++) printf "%s" f " — entry\n", mark, i }
    else                { printf "%s" f " — the successor\n", mark, 999999 }
    print ""; print "## Retired ids"; print ""
    if (kind == "retired") { for (i = 1; i <= n; i++) printf "`" f "` — retired 2026-01-01; its scope moved into " f ".\n", i, 999999 }
    else                   { print "`<none yet>`" }
    print ""; print "## Findings"
  }' > "$1"
}

case_check_board_membership_survives_an_early_close() {
  cf_reset
  make_sandbox
  local registers reg_path reg_mark out rc n=80 first rep="$SB_TMP/report.txt"
  first="$(_cb_wide_id 1)"
  registers="$(cb_default REGISTERS)"
  reg_path="${registers%%|*}"
  reg_mark="$(printf '%s' "$registers" | awk -F'|' '{print $2}')"
  [ -n "$reg_path" ] || { cf "could not derive REGISTERS"; finish "arm (l): membership tests read the whole list"; teardown; return; }
  # INSTRUMENT: the list must clearly outgrow a 64KB pipe buffer, or the early close is not certain.
  [ "$(( n * (${#first} + 1) ))" -gt 131072 ] \
    || _fixture_die "case_check_board_membership_survives_an_early_close: $n ids of ${#first} bytes do not clearly outgrow a 64KB pipe buffer."
  mkdir -p "$SB_WORK/$(dirname "$reg_path")" "$SB_WORK/requirements"
  printf '## Decision Log\n- `[decision: %s]` — the first id of the list\n' "$first" > "$SB_WORK/requirements/PRD-001-cites.md"

  # --- (1) THE LIVE-ID TEST: the id is present, so it must not be reported dangling ---
  _cb_big_register "$SB_WORK/$reg_path" "$reg_mark" live "$n"
  publish_sandbox
  cb_run > "$rep"; rc=$?
  [ "$rc" -eq 0 ] || cf "(1) check-board.sh exited $rc (exit 0 ALWAYS)"
  grep "$reg_path" "$rep" | grep "$n live id" >/dev/null \
    || cf "(1) arm [l] did not read $n live ids from the fixture register, so the early close is not guaranteed: $(grep "$reg_path" "$rep" | cut -c1-200)"
  grep -i 'write error' "$rep" >/dev/null \
    && cf "(1) a writer died on a closed pipe and said so — a membership test is still piping its list to a reader that leaves early: $(grep -i 'write error' "$rep" | head -3 | cut -c1-300)"
  _cb_l_section < "$rep" | grep '⚠' | grep -F "$first" >/dev/null \
    && cf "(1) the first live id of the register was reported anyway — the live-id test read a present id as absent: $(_cb_l_section < "$rep" | grep '⚠' | cut -c1-120 | head -3)"

  # --- (2) THE RETIRED-ID TEST: the id is retired, so it must print as retired ---
  _cb_big_register "$SB_WORK/$reg_path" "$reg_mark" retired "$n"
  publish_sandbox
  cb_run > "$rep"; rc=$?
  [ "$rc" -eq 0 ] || cf "(2) check-board.sh exited $rc (exit 0 ALWAYS)"
  grep "$reg_path" "$rep" | grep "$n retired id" >/dev/null \
    || cf "(2) arm [l] did not read $n retired ids from the fixture register, so the early close is not guaranteed: $(grep "$reg_path" "$rep" | cut -c1-200)"
  _cb_l_section < "$rep" | grep '⚠' | grep -F "$first" | grep -i 'RETIRED' >/dev/null \
    || cf "(2) the first retired id of the register was not reported as retired — the retired-id test read a present id as absent: $(_cb_l_section < "$rep" | grep '⚠' | cut -c1-120 | head -3)"
  _cb_l_section < "$rep" | grep '⚠' | grep -F "$first" | grep 'NOT an entry' >/dev/null \
    && cf "(2) the retired citation printed as a DANGLING one: $(_cb_l_section < "$rep" | grep '⚠' | cut -c1-120 | head -3)"
  grep -i 'write error' "$rep" >/dev/null \
    && cf "(2) a writer died on a closed pipe and said so: $(grep -i 'write error' "$rep" | head -3 | cut -c1-300)"

  finish "arm (l): a citation of the first id of a $n-entry live list is found and a citation of the first id of a $n-entry retired list prints as retired, with no writer dying on a pipe the reader closed early"
  teardown
}

# =============================================================================
# CASE — CONCURRENT check-board.sh RUNS REPORT NO FALSE DANGLING CITATION. A POSITIVE CONTROL ONLY.
#
# The fault this guards showed as a finding on one run and none on the next, on an unchanged tree,
# when several runs overlapped. A run that merely reproduces that luck proves nothing when it comes
# out clean, so the deterministic case above owns the red. This case is the field shape: several
# workers, each running the report back to back, over a register whose every cited id is present.
# Any "NOT an entry" or write error in any run is a finding; each run must also have counted every
# citation, so a run that read nothing cannot pass for one that read everything.
# =============================================================================
case_check_board_concurrent_runs_report_no_false_dangling() {
  cf_reset
  make_sandbox
  local registers reg_path reg_mark i j workers=4 per=2 cites=8 bad="" short="" f
  registers="$(cb_default REGISTERS)"
  reg_path="${registers%%|*}"
  reg_mark="$(printf '%s' "$registers" | awk -F'|' '{print $2}')"
  [ -n "$reg_path" ] || { cf "could not derive REGISTERS"; finish "concurrent check-board runs"; teardown; return; }
  mkdir -p "$SB_WORK/$(dirname "$reg_path")" "$SB_WORK/requirements"
  { printf '# DECISIONS\n## A. Bucket\n'
    for i in $(seq 1 40); do printf '%sD-%02d — entry\n' "$reg_mark" "$i"; done
    printf '\n## Retired ids\n\n`<none yet>`\n\n## Findings\n'; } > "$SB_WORK/$reg_path"
  : > "$SB_WORK/requirements/PRD-001-cites.md"
  for i in $(seq 1 "$cites"); do
    printf -- '- `[decision: D-%02d]` — present in the register\n' "$i" >> "$SB_WORK/requirements/PRD-001-cites.md"
  done
  publish_sandbox

  for j in $(seq 1 "$workers"); do
    ( for i in $(seq 1 "$per"); do cb_run > "$SB_TMP/par-$j-$i.out"; done ) &
  done
  wait

  for f in "$SB_TMP"/par-*.out; do
    [ -s "$f" ] || { short="$short ${f##*/}(empty)"; continue; }
    grep -E "NOT an entry|write error|Broken pipe" "$f" >/dev/null && bad="$bad ${f##*/}"
    grep "$cites citation(s)" "$f" >/dev/null || short="$short ${f##*/}"
  done
  [ -z "$short" ] \
    || cf "a concurrent run did not count all $cites citations, so it cannot show they resolved:$short"
  [ -z "$bad" ] \
    || cf "a concurrent run reported a present id as dangling, or a writer died on a closed pipe:$bad — $(grep -hE 'NOT an entry|write error|Broken pipe' "$SB_TMP"/par-*.out | head -3 | cut -c1-300)"

  finish "$((workers * per)) overlapping check-board.sh runs ($workers workers of $per) each counted all $cites citations of a register that holds them, and none reported a present id as dangling or died on a closed pipe"
  teardown
}

# =============================================================================
# CASE — ARM (l)'s BOUNDARY CONTROL: a citation OUTSIDE the two former surfaces
# (requirements/PRD-*.md and progress/*.md) is now caught, not just one planted inside them.
#
# A CONTROL planted INSIDE a declared surface cannot fail at the boundary its own claim covers.
# This case plants a dangling id in PROJECT.md and in dev/, neither a declared surface before this
# fix, and expects both to be reported. It also exercises the widened marker (no space after the
# colon) and the precision the widened population depends on: the kit's own illustrative
# `[decision: D-NN]` text (a literal `NN`) is never read as a citation, on any surface.
# =============================================================================
case_check_board_citation_population_widened() {
  cf_reset
  make_sandbox

  local registers reg_path reg_mark out
  registers="$(cb_default REGISTERS)"
  reg_path="${registers%%|*}"
  reg_mark="$(printf '%s' "$registers" | awk -F'|' '{print $2}')"
  [ -n "$reg_path" ] || { cf "could not derive REGISTERS"; finish "arm (l): population widened"; teardown; return; }
  mkdir -p "$SB_WORK/$(dirname "$reg_path")"
  cat > "$SB_WORK/$reg_path" <<EOF
# DECISIONS
## A. First bucket
${reg_mark}D-01 — first

## Retired ids

\`<none yet>\`

## Findings
EOF

  # --- (a) OUTSIDE THE OLD SURFACES: PROJECT.md and dev/, neither requirements/ nor progress/ ---
  mkdir -p "$SB_WORK/dev"
  printf '# PROJECT.md\n\nSee the ruling `[decision: D-99]` for context.\n' > "$SB_WORK/PROJECT.md"
  printf '# a dev record\n\nRuled per `[decision:D-98]` (no space — still a citation).\n' > "$SB_WORK/dev/record.md"
  publish_sandbox

  out="$(cb_run)"
  printf '%s\n' "$out" | grep '⚠' | grep 'PROJECT.md' | grep 'D-99' >/dev/null \
    || cf "(a) a dangling citation planted in PROJECT.md (outside both former surfaces) was not reported — a boundary a control planted inside the old surfaces could not fail at: $out"
  printf '%s\n' "$out" | grep '⚠' | grep 'dev/record.md' | grep 'D-98' >/dev/null \
    || cf "(a) a dangling citation planted in dev/ was not reported, or the no-space marker '[decision:D-98]' was not read as a citation at all: $out"
  printf '%s\n' "$out" | grep 'board-drift: findings above' >/dev/null \
    || cf "(a) citations outside the old surfaces did not reach the verdict: $out"

  # --- (b) PRECISION: the kit's own illustrative marker, a literal D-NN, is never a citation ---
  # Planted on the SAME widened surfaces (PROJECT.md, dev/) so precision is proven where breadth
  # was just proven, not only on a surface that was already narrow.
  printf '# PROJECT.md\n\nFormat law: the marker is `[decision: D-NN]`. See also `[decision:D-NN]`.\n' \
    > "$SB_WORK/PROJECT.md"
  printf '# a dev record\n\nSame illustrative form here too: `[decision: D-NN]`.\n' > "$SB_WORK/dev/record.md"
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | grep '⚠' | grep -i 'D-NN' >/dev/null \
    && cf "(b) the kit's own illustrative marker (a literal D-NN) was read as a dangling citation — an adopted tree must not report the kit's own example text: $out"
  printf '%s\n' "$out" | grep 'board-drift: clean ✓' >/dev/null \
    || cf "(b) illustrative-only text (no real id) reddened the board: $out"

  # --- (c) EXCLUDED MACHINERY: a citation inside scripts/ or .claude/skills/ is not read ---
  mkdir -p "$SB_WORK/.claude/skills/vendored-skill"
  printf '# a fixture in scripts/ (comments and fixtures, never a project citation)\n[decision: D-97]\n' \
    > "$SB_WORK/scripts/fixture-citation.md"
  printf '# vendored skill text\n[decision: D-96]\n' > "$SB_WORK/.claude/skills/vendored-skill/SKILL.md"
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | grep '⚠' | grep -E 'D-97|D-96' >/dev/null \
    && cf "(c) a citation inside an excluded path (scripts/ or .claude/skills/) was read anyway: $out"

  finish "arm (l)'s widened population catches a dangling citation OUTSIDE the two former surfaces (PROJECT.md, dev/) — a boundary a control planted inside the old surfaces could not fail at — accepts the marker with or without its space, never reads the kit's own illustrative 'D-NN' text as a citation, and still excludes scripts/ and .claude/skills/"
  teardown
}

# =============================================================================
# CASE — ARM (l) READS EVERY MARKER FORM THROUGH kit_decisions_cited, NOT JUST THE SINGLE-ID
# NO-LIST, NO-RANGE, CASE-SENSITIVE FORM: a capitalized label, a comma LIST (the valid id buried
# inside it), a trailing space before the bracket, and a '..' RANGE all cite. A bare 'per D-NN'
# mention (no brackets) still does not. Planted in each of those forms: the live register
# carries D-05 (so the list and the range both also prove a REAL id inside them resolves, not just
# that the marker is seen), plus a genuinely dangling id (D-93) so the list's dangling half still
# decides. The arm's own POPULATION line (marker-form citations against bare mentions) is checked
# last, on a file this case controls precisely: 9 marker citations, 2 bare mentions (the register's own D-05 heading and 'per D-95').
# =============================================================================
case_check_board_citation_forms_and_population() {
  cf_reset
  make_sandbox

  local registers reg_path reg_mark out
  registers="$(cb_default REGISTERS)"
  reg_path="${registers%%|*}"
  reg_mark="$(printf '%s' "$registers" | awk -F'|' '{print $2}')"
  [ -n "$reg_path" ] || { cf "could not derive REGISTERS"; finish "arm (l): citation forms"; teardown; return; }
  mkdir -p "$SB_WORK/$(dirname "$reg_path")"
  cat > "$SB_WORK/$reg_path" <<EOF
# DECISIONS
## A. First bucket
${reg_mark}D-05 — a live entry a list and a range both cite

## Retired ids

\`<none yet>\`

## Findings
EOF

  # One file, every form planted, plus the bare-mention control.
  printf '%s\n' \
    '[Decision: D-05]' \
    '[decision: D-93, D-05]' \
    '[decision: D-94 ]' \
    'per D-95' \
    '[decision: D-05..D-07]' \
    '[decision:D-21]' \
    "[decision: D$(printf '\xe2\x80\x93')31]" \
    '[decision: D-NN]' \
    > "$SB_WORK/PROJECT.md"
  publish_sandbox

  out="$(cb_run)"
  # (a) the capitalized label cites the live id — no dangling finding for it.
  printf '%s\n' "$out" | _cb_l_section | grep '⚠' | grep -w 'D-05' >/dev/null \
    && cf "(a) the live id D-05, cited only via the capitalized '[Decision: ...]' form, was reported dangling: $out"
  # (b) the list's dangling half (D-93) still decides, even with a live id (D-05) in the same list.
  printf '%s\n' "$out" | _cb_l_section | grep '⚠' | grep 'D-93' >/dev/null \
    || cf "(b) a dangling id inside a comma LIST ('[decision: D-93, D-05]') was not reported: $out"
  # (c) the trailing-space form cites D-94 (dangling — named so it is also seen, not swallowed).
  printf '%s\n' "$out" | _cb_l_section | grep '⚠' | grep 'D-94' >/dev/null \
    || cf "(c) the trailing-space form '[decision: D-94 ]' was not read as a citation at all: $out"
  # (d) the RANGE cites D-05 (live, already proven above) through D-07 (dangling) inclusive.
  printf '%s\n' "$out" | _cb_l_section | grep '⚠' | grep 'D-06' >/dev/null \
    || cf "(d) the RANGE '[decision: D-05..D-07]' did not cite D-06, a member with no id of its own in the text: $out"
  printf '%s\n' "$out" | _cb_l_section | grep '⚠' | grep 'D-07' >/dev/null \
    || cf "(d) the RANGE '[decision: D-05..D-07]' did not cite its own upper bound D-07: $out"
  # (e0) the no-space form cites D-21; the illustrative '[decision: D-NN]' cites nothing.
  printf '%s\n' "$out" | _cb_l_section | grep '⚠' | grep 'D-21' >/dev/null \
    || cf "(e0) '[decision:D-21]' (no space) was not read as a citation: $out"
  printf '%s\n' "$out" | _cb_l_section | grep '⚠' | grep -w 'NN' >/dev/null \
    && cf "(e0) the illustrative '[decision: D-NN]' was read as a citation: $out"
  printf '%s\n' "$out" | _cb_l_section | grep '⚠' | grep 'D-31' >/dev/null \
    || cf "(e1) an en-dash id '[decision: D–31]' was not read as the citation D-31: $out"
  # (e) a bare mention ('per D-95') is still not a citation — no dangling finding for D-95.
  printf '%s\n' "$out" | _cb_l_section | grep '⚠' | grep 'D-95' >/dev/null \
    && cf "(e) a bare mention with no brackets ('per D-95') was read as a citation: $out"
  printf '%s\n' "$out" | grep 'board-drift: findings above' >/dev/null \
    || cf "the dangling ids among the planted forms did not reach the verdict: $out"

  # (f) the POPULATION line: marker-form citations checked against bare mentions outside a
  # marker, both counted and both printed — never a bare '✓ none' alone. 9 marker citations
  # (D-05, D-93, D-05, D-94, D-05, D-06, D-07, D-21, D-31 — the range's 3 expanded ids all count), 2 bare
  # mentions (D-95 from 'per D-95', and the register file's own D-05 heading; the word 'Decision'/'decision' inside the OTHER five lines'
  # own brackets is stripped as marker text, not left behind as a second bare hit).
  printf '%s\n' "$out" | _cb_l_section | grep -iE 'population checked' >/dev/null \
    || cf "(f) arm (l) printed no population line (marker-form count vs bare-mention count): $(printf '%s\n' "$out" | _cb_l_section)"
  printf '%s\n' "$out" | _cb_l_section | grep -iE 'population checked' | grep -E '\b9\b.*marker-form' >/dev/null \
    || cf "(f) the marker-form count is not 9: $(printf '%s\n' "$out" | _cb_l_section | grep -i 'population checked')"
  printf '%s\n' "$out" | _cb_l_section | grep -iE 'population checked' | grep -E '\b2\b.*bare' >/dev/null \
    || cf "(f) the bare-mention count is not 2 (per D-95 and the register heading, outside any marker): $(printf '%s\n' "$out" | _cb_l_section | grep -i 'population checked')"

  finish "arm (l) reads a capitalized label, a comma list (dangling half deciding even beside a live id), a trailing space, and a '..' range as citations — a bare 'per D-NN' mention still is not one — and states its own population (marker-form citations checked against bare mentions outside a marker) rather than a bare '✓ none'"
  teardown
}

# =============================================================================
# CASE — ARM (p): CORPUS.md's forward-reference marker resolves.
#
# Three findings, red first against a copy with arm (p) ablated, then green: a marker naming an
# id no column carries; a marker naming an id that has LANDED while the row is still marked
# instead of `present`; and a `SEED step <N>` marker still standing once arm [g] itself reads
# graduation COMPLETE — reusing [g]'s own verdict, not a second "has day one closed" reading.
# A clean manifest (one resolving id, one still-open id, no SEED-step marker) must read clean, and
# a SEED-step marker BEFORE graduation must not fire — the scoped half of the same rule.
# =============================================================================
case_check_board_corpus_forward_reference() {
  cf_reset
  make_sandbox
  local out corpus_file
  corpus_file="$(cb_default_seam CORPUS_FILE)"
  [ -n "$corpus_file" ] || _fixture_die "case_check_board_corpus_forward_reference: could not derive CORPUS_FILE from check-board.sh."
  mkdir -p "$SB_WORK/$(dirname "$corpus_file")"

  # THE NOT-YET-GRADUATED PRECONDITION, FORCED EXPLICITLY: this case needs arm [g] to NOT read
  # graduation COMPLETE (the SEED-step marker below must stay silent until it does). On a tree
  # past day one, scripts/config.sh's CODE_GLOBS/TEST_GLOBS already carry a `# DECLARED EMPTY —`
  # comment that survives make_sandbox's neutralizer (it keeps comments, by contract), which
  # arm [g] reads as CLEAN. With every other blank filled AND the day-one PRD and landed card
  # present, that would flip G_GRADUATION_COMPLETE; AGENTS.md, README.md and PROJECT.md are never
  # seeded here and read UNMEASURED rather than counting against it. Force both arrays back to
  # genuinely empty and undeclared so this case's premise (not graduated) holds regardless of the
  # tree this harness runs in.
  _array_set_body "$SB_WORK/scripts/config.sh" CODE_GLOBS
  _array_set_body "$SB_WORK/scripts/config.sh" TEST_GLOBS

  seed_issue todo "$SB_PREFIX-720" open-work chore "Still open, correctly marked"
  seed_issue done "$SB_PREFIX-721" landed-work chore "Landed, but the row was never flipped"

  cat > "$SB_WORK/$corpus_file" <<EOF
# CORPUS.md

| Entry | Kind | Status | Why it is corpus |
|---|---|---|---|
| \`requirements/one.md\` | file | present | the north star |
| \`requirements/two.md\` | file | forward-referenced ($SB_PREFIX-720) | lands when work starts |
| \`requirements/three.md\` | file | forward-referenced ($SB_PREFIX-721) | STILL marked though the item landed |
| \`requirements/four.md\` | file | forward-referenced ($SB_PREFIX-999) | no such id was ever minted |
| \`requirements/five.md\` | file | forward-referenced (SEED step 4) | a day-one row, before graduation |
EOF
  publish_sandbox

  out="$(cb_run)"
  printf '%s\n' "$out" | grep '^\[p\]' >/dev/null \
    || cf "no [p] section in the report — the arm is absent"

  # --- must fire: the dangling id -------------------------------------------------
  printf '%s\n' "$out" | grep '⚠' | grep "$SB_PREFIX-999" >/dev/null \
    || cf "a forward-referenced id minted by nobody was NOT reported: $out"

  # --- must fire: the landed-but-unflipped id -------------------------------------
  printf '%s\n' "$out" | grep '⚠' | grep "$SB_PREFIX-721" | grep -i 'LANDED' >/dev/null \
    || cf "a forward-referenced id whose card reached progress/done/ was NOT reported as landed-but-unflipped: $out"

  # --- must NOT fire: the still-open id, correctly marked -------------------------
  printf '%s\n' "$out" | grep '⚠' | grep "$SB_PREFIX-720" >/dev/null \
    && cf "an id that is still open (not landed) and correctly marked forward-referenced was reported: $out"

  # --- must NOT fire yet: the SEED-step marker, BEFORE graduation -----------------
  printf '%s\n' "$out" | grep '⚠' | grep -i 'SEED step' >/dev/null \
    && cf "a SEED-step marker fired before day one has closed — arm [g] has not read graduation COMPLETE yet on this tree: $out"

  printf '%s\n' "$out" | grep 'board-drift: findings above' >/dev/null \
    || cf "the dangling id and the landed-unflipped id did not reach the verdict — this arm DECIDES: $out"

  # --- ABLATION: strip arm (p) and every finding above must vanish ----------------
  local s="$SB_WORK/scripts/check-board.sh"
  grep -q '# (p) CORPUS FORWARD-REFERENCE INTEGRITY' "$s" \
    || cf "(control) no '(p) CORPUS FORWARD-REFERENCE INTEGRITY' seam in check-board.sh — cannot ablate"
  sed -i.bak '/# (p) CORPUS FORWARD-REFERENCE INTEGRITY/,/# END corpus forward-reference arm/d' "$s"; rm -f "$s.bak"
  bash -n "$s" || cf "(control) the ablated check-board.sh no longer parses"
  out="$(cb_run)"
  printf '%s\n' "$out" | grep '^\[p\]' >/dev/null \
    && cf "(control) the ablation left [p] printing — the case would prove nothing"
  # Arm [m] names a landed card that carries no PRD by its id, and these fixture cards carry none:
  # that line is not arm (p)'s finding, so it is set aside before the id is searched for.
  printf '%s\n' "$out" | grep -v 'name no PRD' | grep -E "$SB_PREFIX-999|$SB_PREFIX-721" >/dev/null \
    && cf "(control) a finding survived arm (p)'s ablation, so it is not attributable to this arm: $out"
  printf '%s\n' "$out" | grep 'board-drift: clean ✓' >/dev/null \
    || cf "(control) without arm (p) the board did not read clean, so the findings above are not attributable to it: $out"

  finish "arm (p): a dangling forward-referenced id and a landed-but-unflipped one are reported and DECIDE the verdict; a still-open correctly-marked id is silent; a SEED-step marker is silent before day one closes; ablation-proven"
  teardown
}

# =============================================================================
# CASE — arm [g] reads COMPLETE only once the day-one WORK exists: a PRD (SEED step 6) and a card
# that has passed QA (step 7), beside the filled blanks. A tree whose blanks are all filled, with no
# PRD and no landed card, is not finished, and arm [p] — which reads [g]'s verdict — stays silent
# on the SEED-step marker CORPUS.md told the adopter to write. The operands are fixed in this case:
# one PRD, one card in qa_complete/ or done/, never read back from the arm.
# =============================================================================
case_check_board_graduation_requires_the_day_one_work() {
  cf_reset
  make_sandbox
  local out corpus_file
  corpus_file="$(cb_default_seam CORPUS_FILE)"
  [ -n "$corpus_file" ] || _fixture_die "case_check_board_graduation_requires_the_day_one_work: could not derive CORPUS_FILE."
  mkdir -p "$SB_WORK/$(dirname "$corpus_file")"
  cat > "$SB_WORK/$corpus_file" <<CORPUS_EOF
# CORPUS.md

| Entry | Kind | Status | Why it is corpus |
|---|---|---|---|
| \`src/\` | dir | forward-referenced (SEED step 6) | the code lands with the first card |
CORPUS_EOF
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  printf '# my project\n' > "$SB_WORK/AGENTS.md"
  printf '# my project\n' > "$SB_WORK/README.md"
  printf '<!-- %s — synthetic fill sheet, FILLED. -->\n# PROJECT.md\n\nTrunk: main\n\n## Who answers when nobody is watching\n\n- **`principal:`** `Fixture Owner`\n- **Their channel:** `dev/questions/`\n' \
    "$KIT_FILL_DISPOSITION" > "$SB_WORK/PROJECT.md"
  _cb_g_declare_empty_seams
  _cb_g_discharge_delete_if_unused
  _cb_g_discharge_gitignore_env
  publish_sandbox

  # (a) every blank filled, no PRD, no card: not COMPLETE, the missing work is NAMED, and [p] is silent.
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'PROJECT.md principal:.*declared' >/dev/null \
    || _fixture_die "case_check_board_graduation_requires_the_day_one_work: the blanks are not all filled, so (a) would not isolate the day-one work: $(printf '%s\n' "$out" | _cb_g_section)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    && cf "(a) graduation COMPLETE with no PRD and no landed card: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'DAY-ONE WORK' | grep 'day one is not finished' | grep 'no PRD' | grep 'no card has passed QA' | grep 'steps 6-7' >/dev/null \
    || cf "(a) the arm did not name both missing pieces and the SEED steps: $(printf '%s\n' "$out" | _cb_g_section)"
  printf '%s\n' "$out" | grep '⚠' | grep 'does not outlive day one' >/dev/null \
    && cf "(a) arm [p] flagged the SEED-step marker while arm [g] had not read COMPLETE: $out"

  # (b) a PRD alone: still not COMPLETE, and only the card is named.
  _cb_g_seed_prd
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    && cf "(b) graduation COMPLETE with a PRD and no landed card: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'DAY-ONE WORK' | grep 'day one is not finished' | grep 'no card has passed QA' >/dev/null \
    || cf "(b) a missing landed card was not named: $(printf '%s\n' "$out" | _cb_g_section)"
  printf '%s\n' "$out" | _cb_g_section | grep 'DAY-ONE WORK' | grep 'day one is not finished' | grep 'no PRD' >/dev/null \
    && cf "(b) a PRD exists, yet the arm still says there is none: $(printf '%s\n' "$out" | _cb_g_section)"

  # (c) a card still in todo/ is not a card that passed QA.
  seed_issue todo "$SB_PREFIX-898" open-card chore "Still open"
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    && cf "(c) graduation COMPLETE with only an open card: $out"

  # (d) a card alone, no PRD: not COMPLETE, and only the PRD is named.
  rm -f "$SB_WORK/requirements/PRD-001-fixture.md"
  _cb_g_seed_landed_card qa_complete
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    && cf "(d) graduation COMPLETE with a landed card and no PRD: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'DAY-ONE WORK' | grep 'day one is not finished' | grep 'no PRD' >/dev/null \
    || cf "(d) a missing PRD was not named: $(printf '%s\n' "$out" | _cb_g_section)"
  printf '%s\n' "$out" | _cb_g_section | grep 'DAY-ONE WORK' | grep 'day one is not finished' | grep 'no card has passed QA' >/dev/null \
    && cf "(d) a card sits in qa_complete/, yet the arm still says none has passed QA: $(printf '%s\n' "$out" | _cb_g_section)"

  # (e) both: COMPLETE, and [p] now flags the marker it was silent on.
  _cb_g_seed_prd
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    || cf "(e) a PRD and a card in qa_complete/ did not reach graduation COMPLETE: $out"
  printf '%s\n' "$out" | grep '⚠' | grep 'does not outlive day one' >/dev/null \
    || cf "(e) [g] reads COMPLETE, but the standing SEED-step marker was not reported: $out"

  # (f) the card archived to done/ (archive.sh sweeps landed cards there) still counts.
  git -C "$SB_WORK" mv "progress/qa_complete/$SB_PREFIX-899-day-one-card.md" "progress/done/$SB_PREFIX-899-day-one-card.md" >/dev/null 2>&1 \
    || _fixture_die "case_check_board_graduation_requires_the_day_one_work: could not archive the card to done/"
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    || cf "(f) a PRD and a card in done/ did not reach graduation COMPLETE: $out"

  finish "arm [g]: graduation COMPLETE needs a PRD and a card in qa_complete/ or done/ beside the filled blanks, names whichever is missing, and arm [p]'s SEED-step finding follows that verdict"
  teardown
}

# =============================================================================
# CASE — the PRD surface follows config.sh's PRD_PREFIX. A project initialised with
# `kit-init --prd-prefix FOO` keeps its PRDs at requirements/FOO-NNN-<slug>.md, and arm [g] must
# count them toward day one's work, arm [r] must read them, and the line [g] prints must name the
# surface it searched. The expected surface is written out here, never read back from the arm.
# The default prefix's control is case_check_board_graduation_requires_the_day_one_work, which
# counts requirements/PRD-NNN-<slug>.md.
# =============================================================================
case_check_board_prd_surface_follows_the_prd_prefix() {
  cf_reset
  local L="the PRD surface follows config.sh's PRD_PREFIX: after kit-init --prd-prefix FOO a FOO PRD and a card past QA read graduation COMPLETE, arm [r] reads the FOO PRD, and a PRD-prefixed file is not counted"
  if ! has_kit_init; then skp "$L" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  publish_sandbox
  local out rc
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" --prd-prefix FOO 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || _fixture_die "case_check_board_prd_surface_follows_the_prd_prefix: kit-init --prd-prefix FOO exited $rc: $out"
  grep -qxF 'PRD_PREFIX="${PRD_PREFIX:-FOO}"' "$SB_WORK/scripts/config.sh" \
    || _fixture_die "case_check_board_prd_surface_follows_the_prd_prefix: kit-init did not stamp PRD_PREFIX=FOO, so the case would not exercise the prefixed project"
  mkdir -p "$SB_WORK/requirements"; : > "$SB_WORK/requirements/.gitkeep"   # kit-init's column folders hold one; the sandbox has none
  rc=0; out="$( cd "$SB_WORK" && ./scripts/new-prd.sh feature-x 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || _fixture_die "case_check_board_prd_surface_follows_the_prd_prefix: new-prd.sh exited $rc: $out"
  [ -f "$SB_WORK/requirements/FOO-001-feature-x.md" ] \
    || _fixture_die "case_check_board_prd_surface_follows_the_prd_prefix: new-prd.sh did not write requirements/FOO-001-feature-x.md: $(ls -1A "$SB_WORK/requirements" | tr '\n' ' ')"
  # Arm [r] reads nothing without a register: D-20 is cited by the FOO PRD, D-18 by no PRD.
  cat > "$SB_WORK/requirements/DECISIONS.md" <<'DECISIONS_EOF'
# DECISIONS
## A. Bucket
### D-18 — constraining, cited by no PRD
**Ruling.** Her vocabulary at the boundary; ours behind it.
**Why.** Consumer-facing text must not leak jargon.
**Provenance.** PM session.

### D-20 — constraining, cited by its PRD
**Ruling.** Anything unusual in a tick box is read as yes.
**Why.** Silence must not hide a flagged case.
**Provenance.** PM session.
DECISIONS_EOF
  printf '\n## Decision Log\n- `[decision: D-20]` — tick-box rule\n' >> "$SB_WORK/requirements/FOO-001-feature-x.md"
  # The rest of the day-one blanks, so [g]'s verdict turns only on the day-one work.
  printf '# my project\n' > "$SB_WORK/AGENTS.md"
  printf '# my project\n' > "$SB_WORK/README.md"
  printf '<!-- %s — synthetic fill sheet, FILLED. -->\n# PROJECT.md\n\nTrunk: main\n\n## Who answers when nobody is watching\n\n- **`principal:`** `Fixture Owner`\n- **Their channel:** `dev/questions/`\n' \
    "$KIT_FILL_DISPOSITION" > "$SB_WORK/PROJECT.md"
  _cb_g_declare_empty_seams
  _cb_g_discharge_delete_if_unused
  _cb_g_discharge_gitignore_env
  _cb_g_seed_landed_card qa_complete
  publish_sandbox

  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'DAY-ONE WORK' | grep -F 'requirements/FOO-*.md' | grep '✓' >/dev/null \
    || cf "(g) a FOO PRD and a card in qa_complete/ were not counted, or the line does not name requirements/FOO-*.md: $(printf '%s\n' "$out" | _cb_g_section)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    || cf "(g) a FOO PRD and a card in qa_complete/ did not reach graduation COMPLETE: $(printf '%s\n' "$out" | _cb_g_section)"
  printf '%s\n' "$out" | grep -F 'PRDs read (requirements/FOO-*.md): 1 file(s)' >/dev/null \
    || cf "(r) arm [r] did not read the one FOO PRD: $(printf '%s\n' "$out" | grep 'PRDs read')"
  printf '%s\n' "$out" | grep '⚠' | grep -w 'D-18' | grep -F 'requirements/FOO-*.md' >/dev/null \
    || cf "(r) D-18, cited by no PRD, was not reported against requirements/FOO-*.md: $(printf '%s\n' "$out" | grep -w 'D-18')"
  printf '%s\n' "$out" | grep '⚠' | grep -w 'D-20' >/dev/null \
    && cf "(r) D-20, cited by the FOO PRD, was reported as uncited: $(printf '%s\n' "$out" | grep -w 'D-20')"

  # CONTROL: the same PRD under the default prefix is NOT counted, which shows the surface is the
  # configured one and not a widened glob.
  git -C "$SB_WORK" mv requirements/FOO-001-feature-x.md requirements/PRD-001-feature-x.md >/dev/null 2>&1 \
    || _fixture_die "case_check_board_prd_surface_follows_the_prd_prefix: could not rename the PRD for the control"
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'DAY-ONE WORK' | grep 'no PRD' | grep -F 'requirements/FOO-*.md' >/dev/null \
    || cf "(control) a PRD-001 file under the FOO prefix was counted, or the refusal does not name the surface: $(printf '%s\n' "$out" | _cb_g_section)"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — SEED's "Day one is done when" list names the PRD and the model rows. Wording-level; the
# section is cut from the shipped file with a fixed heading, not derived.
# =============================================================================
case_seed_done_list_names_the_prd_and_the_model_rows() {
  cf_reset
  local seed="$REAL_REPO_ROOT/process/SEED.md" sec
  if [ ! -f "$seed" ]; then skp "SEED's done-list names the PRD and the model rows" "process/SEED.md absent"; return; fi
  sec="$(awk '/^## Day one is done when$/ { f = 1; next } f && /^## / { exit } f' "$seed")"
  [ -n "$sec" ] || _fixture_die "case_seed_done_list_names_the_prd_and_the_model_rows: no '## Day one is done when' section in process/SEED.md."
  printf '%s\n' "$sec" | grep -F 'PRD-001' >/dev/null \
    || cf "the done-list does not name PRD-001"
  printf '%s\n' "$sec" | grep -F 'set-models.sh' >/dev/null \
    || cf "the done-list does not name set-models.sh, so the role docs' model rows are not on the checklist"
  printf '%s\n' "$sec" | grep -F 'Model & effort contract' >/dev/null \
    || cf "the done-list does not name the role docs' Model & effort contract rows"
  printf '%s\n' "$sec" | grep -F 'match no file' >/dev/null \
    || cf "the done-list does not say that a TEST_GLOBS entry matching no file is expected until the first card lands"
  printf '%s\n' "$sec" | tr '\n' ' ' | grep -E 'not `COMPLETE`.*PRD.*`qa_complete/` or `done/`' >/dev/null \
    || cf "the done-list does not say that check-board's [g] is not COMPLETE until a PRD exists and a card is in qa_complete/ or done/"
  finish "SEED's done-list names PRD-001, the role docs' model rows and set-models.sh, the TEST_GLOBS line expected until the first card, and that [g] is not COMPLETE before steps 6-7"
}

# =============================================================================
# CASE — ARM (p): a SEED-step marker fires once arm [g] itself reads graduation COMPLETE.
#
# Reuses the same day-one → graduated transition case_check_board_graduation builds, so this
# case is asserting arm (p) reading arm (g)'s OWN verdict, not a fixture-local guess at what
# "day one has closed" means.
# =============================================================================
case_check_board_corpus_seed_step_after_graduation() {
  cf_reset
  make_sandbox
  local out corpus_file
  corpus_file="$(cb_default_seam CORPUS_FILE)"
  [ -n "$corpus_file" ] || _fixture_die "case_check_board_corpus_seed_step_after_graduation: could not derive CORPUS_FILE."
  mkdir -p "$SB_WORK/$(dirname "$corpus_file")"
  cat > "$SB_WORK/$corpus_file" <<EOF
# CORPUS.md

| Entry | Kind | Status | Why it is corpus |
|---|---|---|---|
| \`requirements/one.md\` | file | forward-referenced (SEED step 4) | still standing |
EOF
  seed_scaffolding_tree
  # THE LIVED SIGNAL: a stamp receipt, the same one case_check_board_graduation uses — never a
  # real issue file, which would also have to be reasoned about by arm (p)'s own id resolution.
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  publish_sandbox

  # ── BEFORE graduation: [g] has not read COMPLETE, so [p] must stay silent on it. ──
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    && _fixture_die "case_check_board_corpus_seed_step_after_graduation: [g] already reads COMPLETE before scaffolding was replaced — the fixture does not test the transition this case needs."
  printf '%s\n' "$out" | grep '⚠' | grep -i 'SEED step' >/dev/null \
    && cf "(before) the SEED-step marker fired while [g] has not read graduation COMPLETE: $out"

  # ── AFTER graduation: replace the scaffolding exactly as case_check_board_graduation does. ──
  printf '# my project\n' > "$SB_WORK/AGENTS.md"
  printf '# my project\n' > "$SB_WORK/README.md"
  printf '<!-- %s — synthetic fill sheet, FILLED. -->\n# PROJECT.md\n\nTrunk: main\n\n## Who answers when nobody is watching\n\n- **`principal:`** `Fixture Owner`\n- **Their channel:** `dev/questions/`\n' \
    "$KIT_FILL_DISPOSITION" > "$SB_WORK/PROJECT.md"
  # [g]'s CODE_GLOBS/TEST_GLOBS/DELETE-IF-UNUSED/.gitignore/.env.example members must also clear
  # for graduation to read COMPLETE — this case only needs [g] clear, not either direction's
  # content.
  _cb_g_declare_empty_seams
  _cb_g_discharge_delete_if_unused
  _cb_g_discharge_gitignore_env
  _cb_g_land_day_one_work
  publish_sandbox

  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    || _fixture_die "case_check_board_corpus_seed_step_after_graduation: [g] still does not read COMPLETE after the scaffolding was replaced — this case's premise failed."
  printf '%s\n' "$out" | grep '⚠' | grep -i 'SEED step' >/dev/null \
    || cf "(after) [g] reads graduation COMPLETE, but the standing SEED-step marker in $corpus_file was NOT reported: $out"
  printf '%s\n' "$out" | grep 'board-drift: findings above' >/dev/null \
    || cf "(after) the stale SEED-step marker did not reach the verdict: $out"

  finish "arm (p): a SEED-step marker is silent before arm [g] reads graduation COMPLETE, and reported once [g] does — reusing [g]'s own verdict across the same day-one → graduated transition case_check_board_graduation builds"
  teardown
}

# =============================================================================
# CASE — ARM (q): DECLARED-REGISTER ENTRY SHAPE. Red-first, per the card: a fifteen-fragment
# entry is reported, a clean three-field entry stays clean, and a reopened-without-stamp pair is
# reported. Report-only: none of this may set `drift` (asserted directly, not just by omission —
# see the dedicated assertion below), the same footing as [k]/[m]/[n]/[o].
# =============================================================================
case_check_board_register_shape() {
  cf_reset
  make_sandbox
  local registers reg_path reg_mark out
  registers="$(cb_default REGISTERS)"
  [ -n "$registers" ] || { cf "could not derive REGISTERS from the defaults block"; finish "check (q): register shape"; teardown; return; }
  reg_path="${registers%%|*}"
  reg_mark="$(printf '%s' "$registers" | awk -F'|' '{print $2}')"
  mkdir -p "$SB_WORK/$(dirname "$reg_path")"

  cat > "$SB_WORK/$reg_path" <<EOF
# DECISIONS
## A. First bucket
${reg_mark}D-01 — a clean three-field entry
**Ruling.** A thing is true.
**Why.** Because reasons.
**Provenance.** Somewhere.

${reg_mark}D-02 — a working default, a legal state, still clean
**Ruling.** WORKING DEFAULT (provisional, asked 2026-09-29, dev/2026-09-29-ask.md) — the default holds.
**Why.** A question never blocks the queue.
**Provenance.** scripts/ask.sh --decision D-02, run by the PM.

## B. Second bucket
${reg_mark}D-03 — fifteen-fragment shape, one entry accumulating dated amendments
**Ruling.** Original text stands.
**(1) 2026-09-29.** First addition.
**(2) 2026-09-29.** Second addition, refines (1).
**(3) 2026-09-29.** Third addition.
**Why.** Reasons.
**Provenance.** Somewhere.

${reg_mark}D-04 — output formats
**Ruling.** No HTML, no PDF: CSV and plain text only.
**Why.** Her spreadsheet opens CSV; plain text opens anywhere.
**Provenance.** PM session.

${reg_mark}D-05 — a later entry reopening D-04 without a stamp on it
**Ruling.** [decision: D-04] is reopened for that one output: a CSV variant with a header row.
**Why.** Her bookkeeper asked for a header row.
**Provenance.** PM session, later.
EOF
  publish_sandbox

  out="$(cb_run)"
  printf '%s\n' "$out" | grep '^\[q\]' >/dev/null \
    || cf "no [q] section in the report — the arm is absent"

  # --- must fire: the fifteen-fragment shape (D-03) --------------------------
  printf '%s\n' "$out" | _cb_q_section | grep -E '⚠ .*\bD-03\b.*extra' >/dev/null \
    || cf "a D-NN entry with stacked dated fragments was NOT reported: $out"

  # --- must NOT fire: the clean three-field entry (D-01) ----------------------
  printf '%s\n' "$out" | _cb_q_section | grep '⚠' | grep -w 'D-01' >/dev/null \
    && cf "a clean three-field entry was reported: $out"

  # --- must NOT fire: the working default, a legal state (D-02) --------------
  printf '%s\n' "$out" | _cb_q_section | grep '⚠' | grep -w 'D-02' >/dev/null \
    && cf "a legally-shaped WORKING DEFAULT entry was reported: $out"

  # --- must fire: D-04 is reopened by D-05 and carries no stamp ---------------
  # Anchored on the line's OWN reported id ("⚠ D-04 —"), never a substring match: the finding's
  # own sentence legitimately names the OTHER id too ("reopened or superseded by D-05"), so a
  # loose 'D-NN.*reopen' would match either id's line. This checks which id the finding is ABOUT.
  printf '%s\n' "$out" | _cb_q_section | grep -E '⚠ D-04 —.*carries no stamp' >/dev/null \
    || cf "D-04, reopened by D-05 with no stamp of its own, was NOT reported: $out"

  # --- must NOT fire on D-05 itself (it is the reopener, not the reopened) ----
  printf '%s\n' "$out" | _cb_q_section | grep -E '⚠ D-05 —.*carries no stamp' >/dev/null \
    && cf "D-05 (the reopener) was reported as unstamped instead of D-04 (the reopened): $out"

  # --- REPORT-ONLY: this arm must never set drift --------------------------
  # Ablate every OTHER arm's ability to fire on this fixture by re-running against a copy of the
  # sandbox with only [q]'s fixture present: assert directly that [q]'s own findings never flip
  # the verdict, by checking the verdict footer names ONLY when [q] is the sole source. Simpler and
  # just as sharp: assert the report-only token is on [q]'s own header line, the same contract
  # [k]/[m]/[n]/[o] state in theirs, which kit-init's self-check keys on.
  printf '%s\n' "$out" | grep '^\[q\]' | grep -i 'reports only' >/dev/null \
    || cf "[q]'s header does not carry the 'reports only' token — kit-init's self-check cannot tell it apart from a deciding arm: $out"

  # --- ABLATION: strip arm (q) and every finding above must vanish -----------
  local s="$SB_WORK/scripts/check-board.sh"
  grep -q '# (q) DECLARED-REGISTER ENTRY SHAPE' "$s" \
    || cf "(control) no '(q) DECLARED-REGISTER ENTRY SHAPE' seam in check-board.sh — cannot ablate"
  sed -i.bak '/# (q) DECLARED-REGISTER ENTRY SHAPE/,/# END register-shape arm/d' "$s"; rm -f "$s.bak"
  bash -n "$s" || cf "(control) the ablated check-board.sh no longer parses"
  out="$(cb_run)"
  printf '%s\n' "$out" | grep '^\[q\]' >/dev/null \
    && cf "(control) the ablation left [q] printing — the case would prove nothing"
  # Scoped to arm (q)'s OWN finding wording, never a bare 'D-03|reopen' — another arm (r,
  # declared reverse coverage) also names D-03 on this same fixture (a live id no PRD cites),
  # legitimately and independently, so a whole-report grep would cross-match its line instead.
  printf '%s\n' "$out" | grep -E 'extra dated/bold fragment|carries no stamp of its own' >/dev/null \
    && cf "(control) a finding survived arm (q)'s ablation, so it is not attributable to this arm: $out"

  finish "arm (q): a stacked-amendment entry and an unstamped reopened entry are reported, a clean entry and a legal WORKING DEFAULT stay silent, the header carries 'reports only', and ablation-proven"
  teardown
}

# =============================================================================
# CASE — ARM (r): DECLARED REVERSE COVERAGE.
#
# Arm (l) walks FROM a citing surface TO the register; this is the OTHER direction — a live
# register entry that CONSTRAINS a PRD but that PRD never cites. Keyed as "cited BY THE PRD it
# constrains", not "cited anywhere" — a card citing the id must NOT satisfy this: a fork can
# constrain a PRD, be cited only from a card, and leave the PRD itself wrong. A `[cross-cutting]`
# entry (project law no single PRD should cite) is exempt.
#
# Three ids, red-first as the brief requires:
#   D-18 — constraining, cited ONLY by a card  → MUST fire.
#   D-20 — constraining, cited BY ITS PRD      → must NOT fire.
#   D-08 — declared [cross-cutting]            → must NOT fire, even though no PRD cites it.
# =============================================================================
case_check_board_reverse_coverage() {
  cf_reset
  make_sandbox
  local registers reg_path reg_mark out
  registers="$(cb_default REGISTERS)"
  [ -n "$registers" ]   || { cf "could not derive REGISTERS from the defaults block"; finish "arm (r): reverse coverage"; teardown; return; }
  reg_path="${registers%%|*}"
  reg_mark="$(printf '%s' "$registers" | awk -F'|' '{print $2}')"
  mkdir -p "$SB_WORK/$(dirname "$reg_path")" "$SB_WORK/requirements"

  cat > "$SB_WORK/$reg_path" <<EOF
# DECISIONS
## A. Bucket
${reg_mark}D-18 — constraining, cited only by a card
**Ruling.** Her vocabulary at the boundary; ours behind it.
**Why.** Consumer-facing text must not leak jargon.
**Provenance.** PM session.

${reg_mark}D-20 — constraining, cited by its own PRD
**Ruling.** Anything unusual in a tick box is read as yes.
**Why.** Silence must not hide a flagged case.
**Provenance.** PM session.

${reg_mark}D-08 — cross-cutting, no PRD should cite it
**Ruling.** [cross-cutting] The active role set is PM, Dev, QA.
**Why.** A repository-wide convention, not one PRD's requirement.
**Provenance.** SEED step 2.
EOF

  # The PRD cites D-20 only. D-18 is cited only from a card, never from a PRD.
  printf '## Decision Log\n- `[decision: D-20]` — tick-box rule\n' > "$SB_WORK/requirements/PRD-001-rota.md"
  seed_issue dev_complete "$SB_PREFIX-530" boundary-card chore "Boundary wording"
  printf '\n- <date> [Dev] cites `[decision: D-18]` as the source of this wording.\n' \
    >> "$SB_WORK/progress/dev_complete/$SB_PREFIX-530-boundary-card.md"
  publish_sandbox

  out="$(cb_run)"
  printf '%s\n' "$out" | grep '^\[r\]' >/dev/null \
    || cf "no [r] section in the report — the arm is absent"

  # --- must fire: D-18, constraining, cited only by a card --------------------
  printf '%s\n' "$out" | _cb_r_section | grep -E '⚠ D-18 is not cited by any PRD' >/dev/null \
    || cf "D-18 (constraining, cited only by a card) was NOT reported: $out"

  # --- must NOT fire: D-20, cited by its own PRD -------------------------------
  printf '%s\n' "$out" | _cb_r_section | grep '⚠' | grep -w 'D-20' >/dev/null \
    && cf "D-20, cited by the PRD it constrains, was reported: $out"

  # --- must NOT fire: D-08, declared [cross-cutting] ---------------------------
  printf '%s\n' "$out" | _cb_r_section | grep '⚠' | grep -w 'D-08' >/dev/null \
    && cf "D-08, declared [cross-cutting], was reported even though no PRD cites it: $out"
  printf '%s\n' "$out" | _cb_r_section | grep -E '1 declared \[cross-cutting\]' >/dev/null \
    || cf "the exempt count does not read 1: $(printf '%s\n' "$out" | _cb_r_section)"

  # --- THE KEYING ITSELF: a card citation is NOT a PRD citation ----------------
  # Control: if D-18 were cited from its own PRD instead of a card, it must go clean. Proves the
  # case is not merely failing to find D-18 for an unrelated reason.
  printf '## Decision Log\n- `[decision: D-20]` — tick-box rule\n- `[decision: D-18]` — now cited by its own PRD\n' \
    > "$SB_WORK/requirements/PRD-001-rota.md"
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_r_section | grep '⚠' | grep -w 'D-18' >/dev/null \
    && cf "(control) D-18, once cited by its own PRD, was still reported — the arm is not reading PRD_SURFACE citations: $out"
  printf '%s\n' "$out" | _cb_r_section | grep -E '✓ none' >/dev/null \
    || cf "(control) with D-18 now PRD-cited and D-08 exempt, the arm did not read clean: $(printf '%s\n' "$out" | _cb_r_section)"

  # --- REPORT-ONLY: this arm must never set drift ------------------------------
  printf '%s\n' "$out" | grep '^\[r\]' | grep -i 'reports only' >/dev/null \
    || cf "[r]'s header does not carry the 'reports only' token — kit-init's self-check cannot tell it apart from a deciding arm: $out"

  # --- ABLATION: strip arm (r) and D-18's finding must vanish ------------------
  printf '## Decision Log\n- `[decision: D-20]` — tick-box rule\n' > "$SB_WORK/requirements/PRD-001-rota.md"
  publish_sandbox
  local s="$SB_WORK/scripts/check-board.sh"
  grep -q '# (r) DECLARED REVERSE COVERAGE' "$s" \
    || cf "(control) no '(r) DECLARED REVERSE COVERAGE' seam in check-board.sh — cannot ablate"
  sed -i.bak '/# (r) DECLARED REVERSE COVERAGE/,/# END reverse-coverage arm/d' "$s"; rm -f "$s.bak"
  bash -n "$s" || cf "(control) the ablated check-board.sh no longer parses"
  out="$(cb_run)"
  printf '%s\n' "$out" | grep '^\[r\]' >/dev/null \
    && cf "(control) the ablation left [r] printing — the case would prove nothing"
  # Scoped to (r)'s own section — after a clean ablation the section is gone entirely, so this
  # also catches the section surviving under a different header by accident.
  printf '%s\n' "$out" | _cb_r_section | grep -E 'D-18 is not cited' >/dev/null \
    && cf "(control) a finding survived arm (r)'s ablation, so it is not attributable to this arm: $out"

  finish "arm (r): a live register entry that constrains a PRD but is cited only by a card is reported; one cited by its own PRD, and one declared [cross-cutting], stay silent; a card citation does not satisfy the keying (control); the header carries 'reports only'; ablation-proven"
  teardown
}

# =============================================================================
# CASE — ARM (a): AN ARROW IS A DECLARATION, A BACKTICK IS A MENTION.
#
# A move entry such as
#   - <date> [Dev] → dev_complete: unblocked; see `blocked` for the prior context.
# must not be read as declaring `blocked`: the arrow is the declaration, and a trailing backtick
# is a mention.
#
# Three directions, because precedence needs all three to be pinned:
#   (i)   arrow + trailing backtick mention, card matches the ARROW → no finding;
#   (ii)  arrow disagreeing with the folder → still a finding (the fix must not
#         have simply stopped judging arrows);
#   (iii) a backtick with NO arrow → still judged, as the fallback it is.
# =============================================================================
case_check_board_arrow_beats_mention() {
  cf_reset
  make_sandbox
  local out rc

  # (i) the arrow agrees with the folder, and a backticked mention of another column trails it.
  seed_issue dev_complete "$SB_PREFIX-240" arrowwins chore "Arrow beats mention"
  printf -- '- 2026-01-04 [Dev] → dev_complete: unblocked; see `blocked` for the prior context.\n' \
    >> "$SB_WORK/progress/dev_complete/$SB_PREFIX-240-arrowwins.md"
  # (ii) an arrow that genuinely disagrees with the folder — must STILL be caught.
  seed_issue todo "$SB_PREFIX-241" arrowwrong chore "Arrow disagrees"
  printf -- '- 2026-01-04 [Dev] → qa_complete: handed off.\n' \
    >> "$SB_WORK/progress/todo/$SB_PREFIX-241-arrowwrong.md"
  # (iii) a backticked declaration with no arrow — the fallback must still judge it.
  seed_issue todo "$SB_PREFIX-242" tickonly chore "Backtick only"
  printf -- '- 2026-01-04 [QA] Reviewed and moved to `qa_complete`.\n' \
    >> "$SB_WORK/progress/todo/$SB_PREFIX-242-tickonly.md"
  publish_sandbox

  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep "$SB_PREFIX-240" >/dev/null \
    && cf "(i) FALSE DRIFT — a card whose arrow matches its folder was reported because a backticked column was MENTIONED later in the same bullet: $(printf '%s\n' "$out" | grep "$SB_PREFIX-240")"
  printf '%s\n' "$out" | grep "$SB_PREFIX-241" >/dev/null \
    || cf "(ii) an arrow DISAGREEING with the folder was not reported — the precedence fix must not have stopped judging arrows: $out"
  printf '%s\n' "$out" | grep "$SB_PREFIX-241" | grep 'qa_complete' >/dev/null \
    || cf "(ii) the finding does not name what the arrow declared: $(printf '%s\n' "$out" | grep "$SB_PREFIX-241")"
  printf '%s\n' "$out" | grep "$SB_PREFIX-242" >/dev/null \
    || cf "(iii) a backticked declaration with NO arrow was not judged — the fallback pass is gone: $out"

  finish "check (a): an arrow outranks a backticked mention in the same bullet (no false drift), an arrow that disagrees is still a finding, and a backtick with no arrow is still judged"
  teardown
}

# =============================================================================
# CASE — ARM (a) JUDGES declined/, AND ARM (k) ONLY COUNTS IT.
#
# Arm (a), the only drift-deciding board arm, must walk every STATUS_FOLDERS column, declined/
# included: a card in declined/ whose last Activity entry says `→ todo` is a hand-move, which no
# other check can see (contracts/drift-report.md). Arm (k) only counts the column: a recorded
# decline is not work left undone, so it never sets drift.
#
# Four directions:
#   (i)   a declined card whose arrow AGREES with its folder → no finding;
#   (ii)  a declined card whose arrow DISAGREES → a finding, and the verdict goes red;
#   (iii) arm (k) prints a COUNT of the column;
#   (iv)  a healthy declined column ALONE never reddens the verdict — (k) has no
#         threshold, so piling cards in must stay green.
# =============================================================================
case_check_board_declined_is_judged_and_counted() {
  cf_reset
  make_sandbox
  local out rc kline

  # (iv)'s population and (i)'s subject: two declined cards whose arrows agree.
  seed_issue declined "$SB_PREFIX-250" refused-one chore "Refused one"
  printf -- '- 2026-01-05 [PM] → declined: refused; the cost lands on every reader.\n' \
    >> "$SB_WORK/progress/declined/$SB_PREFIX-250-refused-one.md"
  seed_issue declined "$SB_PREFIX-251" refused-two chore "Refused two"
  printf -- '- 2026-01-05 [PM] → declined: refused; superseded by the standing rule.\n' \
    >> "$SB_WORK/progress/declined/$SB_PREFIX-251-refused-two.md"
  publish_sandbox

  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc (exit 0 ALWAYS)"

  # (i) agreeing arrows in declined/ are not findings.
  printf '%s\n' "$out" | grep "$SB_PREFIX-250" >/dev/null \
    && cf "(i) FALSE DRIFT — a declined card whose arrow matches its folder was reported: $(printf '%s\n' "$out" | grep "$SB_PREFIX-250")"

  # (iii) arm (k) prints, and prints the count it read.
  kline="$(printf '%s\n' "$out" | grep '^\[k\]' || true)"
  [ -n "$kline" ] || cf "(iii) arm [k] did not print at all: $out"
  printf '%s\n' "$kline" | grep '2 card' >/dev/null \
    || cf "(iii) arm [k] did not report the two cards seeded into declined/: $kline"
  printf '%s\n' "$kline" | grep 'reports only' >/dev/null \
    || cf "(iii) arm [k]'s header does not carry the machine token 'reports only', so kit-init's board self-check will read its lines as findings and fail the install: $kline"

  # (iv) a populated, healthy declined column does NOT redden the verdict.
  printf '%s\n' "$out" | grep 'board-drift: clean ✓' >/dev/null \
    || cf "(iv) a healthy board with two declined cards did not read clean — arm [k] must have no threshold and must never set drift: $out"

  # --- (ii) THE ABLATION THAT MAKES (i) WORTH ANYTHING ----------------------
  # Contradict one card's folder with its own last Activity entry.
  printf -- '- 2026-01-06 [PM] → todo: reopened by hand, without the mover.\n' \
    >> "$SB_WORK/progress/declined/$SB_PREFIX-251-refused-two.md"
  publish_sandbox
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc after the plant (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep "$SB_PREFIX-251" >/dev/null \
    || cf "(ii) ABLATION FAILED — a card in declined/ declaring '→ todo' was NOT reported, so arm (a) is not reading the column and half (i) proves nothing: $out"
  printf '%s\n' "$out" | grep "$SB_PREFIX-251" | grep 'declined' >/dev/null \
    || cf "(ii) the finding does not name the folder the card is actually in: $(printf '%s\n' "$out" | grep "$SB_PREFIX-251")"
  printf '%s\n' "$out" | grep 'board-drift: clean ✓' >/dev/null \
    && cf "(ii) a real hand-move in declined/ left the verdict CLEAN — arm (a)'s finding must set drift: $out"

  finish "check-board: arm (a) JUDGES declined/ (a hand-move there is a finding and reddens the verdict — ablation-proven) while arm (k) only COUNTS it (two cards reported, 'reports only' in its header, verdict stays clean)"
  teardown
}

# =============================================================================
# CASE — ARM (b) READS THE ARCHIVE THRESHOLD FROM scripts/config.sh, NOT A HARD-CODED 10.
#
# The adapter template asks the adopter to declare "the archive sweep threshold" but the script
# ignored it and always compared against a literal 10. Set QA_COMPLETE_THRESHOLD=3 in the
# sandbox's config.sh (the one seam, process/contracts/config-seam.md) and expect arm (b) to
# report the drift at 3, not 10.
# =============================================================================
case_check_board_reads_the_configured_archive_threshold() {
  cf_reset
  make_sandbox
  local out

  # Declare the threshold the way an adopter would — the shipped seam shape, a lower number.
  sed -i.bak 's/^QA_COMPLETE_THRESHOLD="\${QA_COMPLETE_THRESHOLD:-[^}]*}"/QA_COMPLETE_THRESHOLD="\${QA_COMPLETE_THRESHOLD:-3}"/' \
    "$SB_WORK/scripts/config.sh"
  rm -f "$SB_WORK/scripts/config.sh.bak"
  grep -q 'QA_COMPLETE_THRESHOLD:-3' "$SB_WORK/scripts/config.sh" \
    || cf "(setup) the sandbox's config.sh does not declare the lowered threshold — cannot test the seam: $(grep QA_COMPLETE_THRESHOLD "$SB_WORK/scripts/config.sh")"

  seed_issue qa_complete "$SB_PREFIX-610" first  chore "First"
  seed_issue qa_complete "$SB_PREFIX-611" second chore "Second"
  seed_issue qa_complete "$SB_PREFIX-612" third  chore "Third"
  publish_sandbox

  out="$(cb_run)"
  printf '%s\n' "$out" | grep '^\[b\]' | grep -F '3 / 3 threshold' >/dev/null \
    || cf "arm (b) did not read the 3 declared in scripts/config.sh — reported against the kit's shipped default instead: $(printf '%s\n' "$out" | grep '^\[b\]')"
  printf '%s\n' "$out" | grep '^\[b\]' | grep -F 'scripts/config.sh in this source' >/dev/null \
    || cf "arm (b) did not name scripts/config.sh as the threshold's source: $(printf '%s\n' "$out" | grep '^\[b\]')"

  # One more card over the DECLARED threshold (3), still under the kit's shipped default (10):
  # this is the case the seam exists to catch — a hard-coded 10 would read this as healthy.
  seed_issue qa_complete "$SB_PREFIX-613" fourth chore "Fourth"
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | grep '^\[b\]' | grep '⚠ over' >/dev/null \
    || cf "arm (b) did not flag 4 cards as over a declared threshold of 3 — it is still comparing against 10: $(printf '%s\n' "$out" | grep '^\[b\]')"

  finish "check-board arm (b) reads QA_COMPLETE_THRESHOLD from scripts/config.sh in the source it inspects, and reports over threshold at the declared value rather than the kit's shipped default"
  teardown
}

# =============================================================================
# CASE — § LOG'S HEADING IS ONE BOUNDED DECLARATION.
#
# `^##[[:space:]]+Log` also matched `## Logistics`: kit-init refused a fresh tree as lived, the
# size arm measured the wrong section, and the rotation moved it into the history chunk. Every
# shipped reader now reads KIT_LOG_HEADING_ERE from scripts/lib/lived-probe.sh. The census holds
# the shipped scripts to that one declaration; each reader is then driven over a `## Logistics`
# section before § Log and a `## Login notes` section after it, each carrying a dated `###`.
# =============================================================================
case_log_heading_is_one_bounded_declaration() {
  cf_reset
  local L="§ Log's heading is declared once and bounded: kit-init, check-board arms c and n, setup.sh and archive-progress.sh each skip a '## Logistics' and a '## Login notes' section"
  if ! has_kit_init; then skp "$L" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox

  # ── (1) THE CENSUS: no shipped script spells the heading except the declaration.
  local lib="$SB_WORK/scripts/lib/lived-probe.sh" decl pat='\]\+Log|\^## ?Log' rows
  decl="$(grep '^KIT_LOG_HEADING_ERE=' "$lib" 2>/dev/null || true)"
  [ -n "$decl" ] \
    || _fixture_die "case_log_heading_is_one_bounded_declaration: scripts/lib/lived-probe.sh declares no KIT_LOG_HEADING_ERE — the census would hold the readers to nothing."
  # INSTRUMENT CHECK: the census pattern finds the declaration, or it is blind.
  printf '%s\n' "$decl" | grep -E "$pat" >/dev/null \
    || _fixture_die "case_log_heading_is_one_bounded_declaration: the census pattern does not match the declaration itself — it would pass over every copy."
  rows="$( { grep -rnE "$pat" "$SB_WORK/scripts" "$SB_WORK/setup.sh" "$SB_WORK/consumers" 2>/dev/null || true; } \
           | { grep -v '/scripts/lib/lived-probe.sh:[0-9]*:KIT_LOG_HEADING_ERE=' || true; } | sed "s|^$SB_WORK/||")"
  [ -z "$rows" ] \
    || cf "(census) a shipped script spells § Log's heading instead of reading KIT_LOG_HEADING_ERE: $(printf '%s' "$rows" | tr '\n' '|' | cut -c1-300)"

  # ── THE FIXTURE: a § Log smaller than the threshold between two sections that are not it.
  local thresh pad
  thresh="$(ap_thresh)"
  [ -n "$thresh" ] || _fixture_die "case_log_heading_is_one_bounded_declaration: could not derive PROGRESS_LOG_BYTE_THRESHOLD."
  pad="$(head -c "$(( thresh + 1000 ))" /dev/zero | tr '\0' 'x')"
  { printf '# progress.md\n\n## Logistics\n\n### 2026-09-01 depot schedule\n%s\n\n## Log\n\n' "$pad"
    printf '## Login notes\n\n### 2026-09-02 badge rota\n- the front desk\n'; } > "$SB_WORK/progress.md"
  publish_sandbox

  # ── (2) kit-init's lived probe: § Log is empty, so the tree has not lived.
  local out rc
  rc=0; out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)" || rc=$?
  printf '%s\n' "$out" | grep 'already lived' >/dev/null \
    && cf "(kit-init) a fresh tree was refused as lived — a section beside § Log was read as its history: $(printf '%s\n' "$out" | grep -A3 'already lived' | tr '\n' '|')"
  [ "$rc" -eq 0 ] || cf "(kit-init) exited $rc: $(printf '%s\n' "$out" | grep -m3 -E '✗|Error' | tr '\n' '|')"

  # ── (3) check-board arms c and n, over one session entry added to § Log.
  awk '{ print } /^## Log$/ { print ""; print "### 2026-01-02 [Dev] a session"; print "- kit-feedback: none" }' \
    "$SB_WORK/progress.md" > "$SB_WORK/progress.md.new" && mv "$SB_WORK/progress.md.new" "$SB_WORK/progress.md"
  git -C "$SB_WORK" add progress.md >/dev/null 2>&1
  sbcommit -q -m "[PM] log a session" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  out="$(cb_run)"
  printf '%s\n' "$out" | grep '^\[c\] progress.md § Log SLICE: .*✓' >/dev/null \
    || cf "(arm c) § Log was not measured as the small section it is: $(printf '%s\n' "$out" | grep '^\[c\]' | tr '\n' '|')"
  printf '%s\n' "$out" | grep 'newest entry (2026-01-02 \[Dev\] a session): kit-feedback: none' >/dev/null \
    || cf "(arm n) the newest § Log entry was not the one read: $(printf '%s\n' "$out" | grep -A3 '^\[n\]' | tr '\n' '|')"

  # ── (4) setup.sh: a progress.md whose only heading is `## Logistics` has no § Log.
  if [ -f "$SB_WORK/setup.sh" ]; then
    cp "$SB_WORK/progress.md" "$SB_TMP/progress.keep"
    printf '# progress.md\n\n## Logistics\n\n- depot\n' > "$SB_WORK/progress.md"
    out="$( cd "$SB_WORK" && ./setup.sh --kit-only 2>&1 )"
    printf '%s\n' "$out" | grep "progress.md has no '## Log' heading" >/dev/null \
      || cf "(setup.sh) '## Logistics' was accepted as the '## Log' heading: $(printf '%s\n' "$out" | grep -i 'progress.md' | tr '\n' '|')"
    cp "$SB_TMP/progress.keep" "$SB_WORK/progress.md"
  fi

  # ── (5) archive-progress.sh: the rotation takes only § Log's entries.
  local R="$SB_TMP/aplh"
  mkdir -p "$R/progress/history"
  cp "$SB_WORK/progress.md" "$R/progress.md"
  rc=0; out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone lh --before 2026-06-01 --apply 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(archive-progress) exited $rc: $(printf '%s' "$out" | head -3 | tr '\n' '|')"
  grep -F -- '- kit-feedback: none' "$R/progress/history/lh.md" >/dev/null 2>&1 \
    || cf "(archive-progress) the § Log entry was not rotated"
  grep -E 'depot|badge' "$R/progress/history/lh.md" >/dev/null 2>&1 \
    && cf "(archive-progress) a section beside § Log was moved into the history chunk"
  grep -qxF '## Logistics' "$R/progress.md" && grep -qxF '## Login notes' "$R/progress.md" \
    || cf "(archive-progress) progress.md lost a section beside § Log"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — setup.sh WARNS ABOUT A LATER-ADDED COLUMN; IT DOES NOT FAIL.
#
# A tree not yet upgraded to the kit that added a column is missing it.
# Those boards are one `mkdir` behind, not broken, and failing setup.sh on them trains everybody
# to ignore its output.
#
# Both directions, because "warns" is only meaningful against something that fails:
#   (i)  a board missing declined/ → WARNS, names the remedy, and setup.sh's board
#        check does not count a failure;
#   (ii) a board missing an ORIGINAL column (todo/) → still a FAILURE. Without this
#        half, softening every column to a warning would pass (i).
# =============================================================================
case_setup_warns_on_a_later_added_column() {
  cf_reset
  make_sandbox
  if [ ! -f "$SB_WORK/setup.sh" ]; then
    skp "setup.sh warns about a later-added board column rather than failing" "the sandbox carries no setup.sh"
    teardown; return
  fi
  # THE PREMISE: the file must actually declare a later-added list, or both halves
  # below are about a script that never made the distinction.
  grep -q '^BOARD_FOLDERS_ADDED_LATER=' "$SB_WORK/setup.sh" \
    || _fixture_die "case_setup_warns_on_a_later_added_column: setup.sh declares no BOARD_FOLDERS_ADDED_LATER — the later-added/original split does not exist, so this case would be asserting about nothing."

  local out rc

  # --- (i) the later-added column is absent -----------------------------------
  rm -rf "$SB_WORK/progress/declined"
  [ -d "$SB_WORK/progress/declined" ] \
    && _fixture_die "case_setup_warns_on_a_later_added_column: progress/declined/ survived the removal — the state this case is about does not exist."
  out="$( cd "$SB_WORK" && ./setup.sh 2>&1 )"; rc=$?
  printf '%s\n' "$out" | grep -i 'progress/declined/ is missing' >/dev/null \
    || cf "(i) setup.sh said nothing about the missing column — a silent pass is the other failure mode: $out"
  printf '%s\n' "$out" | grep -i 'progress/declined/ is missing' | grep '^WARN' >/dev/null \
    || cf "(i) the missing later-added column was not reported as a WARN: $(printf '%s\n' "$out" | grep -i 'progress/declined/ is missing')"
  # THE REMEDY MUST BE NAMED. A warning an adopter cannot act on is noise.
  printf '%s\n' "$out" | grep 'mkdir -p' >/dev/null \
    || cf "(i) the warning does not name the command that fixes it: $out"
  printf '%s\n' "$out" | grep -i 'the board is incomplete' >/dev/null \
    && cf "(i) the later-added column was reported with the ORIGINAL-column failure text, so it is still a hard failure: $out"

  # --- (ii) THE ABLATION: an ORIGINAL column must still FAIL --------------------
  # Without this, softening every column to a warning passes (i) and setup.sh stops
  # noticing a genuinely broken board.
  rm -rf "$SB_WORK/progress/todo"
  out="$( cd "$SB_WORK" && ./setup.sh 2>&1 )"; rc=$?
  printf '%s\n' "$out" | grep -i 'progress/todo/ is missing' >/dev/null \
    || cf "(ii) a missing ORIGINAL column was not reported at all: $out"
  printf '%s\n' "$out" | grep -i 'progress/todo/ is missing' | grep 'the board is incomplete' >/dev/null \
    || cf "(ii) ABLATION FAILED — a missing ORIGINAL column did not get the failure text, so (i) proves nothing: every column would warn: $(printf '%s\n' "$out" | grep -i 'progress/todo/ is missing')"

  finish "setup.sh: a board column this kit version ADDED warns and names its mkdir remedy, while a missing ORIGINAL column is still reported as an incomplete board (ablation-proven)"
  teardown
}

# =============================================================================
# CASE — setup.sh DOES NOT SAY "Setup complete." AND THEN REFUSE.
# A run that counts a failure ends in a refusal, so its closing banner must not announce
# completion. The control is the same sandbox before the failure is planted.
# =============================================================================
case_setup_does_not_say_complete_before_it_refuses() {
  cf_reset
  make_sandbox
  if [ ! -f "$SB_WORK/setup.sh" ]; then
    skp "setup.sh prints 'Setup complete.' only on a run without problems" "the sandbox carries no setup.sh"
    teardown; return
  fi
  local out rc
  # CONTROL FIRST: with the board complete the run succeeds and the banner says so.
  printf '# progress\n\n## Log\n' > "$SB_WORK/progress.md"
  out="$( cd "$SB_WORK" && ./setup.sh 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(control) setup.sh exited $rc on an unbroken board, so a later failure proves nothing: $(printf '%s\n' "$out" | grep -E '^(WARN|ERROR)' | grep -v 'no .gitkeep' | head -3 | tr '\n' '|')"
  printf '%s\n' "$out" | grep 'Setup complete\.' >/dev/null \
    || cf "(control) setup.sh without a problem did not print 'Setup complete.': $(printf '%s\n' "$out" | grep 'Setup ')"
  # THE PLANTED FAILURE: a missing ORIGINAL column is counted, the run refuses, the banner says so.
  rm -rf "$SB_WORK/progress/todo"
  out="$( cd "$SB_WORK" && ./setup.sh 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "setup.sh with a planted failure exited 0: $out"
  printf '%s\n' "$out" | grep 'Setup complete\.' >/dev/null \
    && cf "setup.sh announced 'Setup complete.' on a run that then refused: $(printf '%s\n' "$out" | grep 'Setup ')"
  printf '%s\n' "$out" | grep 'Setup finished with [1-9][0-9]* problem' >/dev/null \
    || cf "setup.sh's closing banner did not report the problem count: $(printf '%s\n' "$out" | grep 'Setup ')"
  finish "setup.sh closes with 'Setup complete.' only when no problem was counted, and with 'Setup finished with N problem(s).' before its refusal otherwise"
  teardown
}

# =============================================================================
# CASE — setup.sh READS THE `## Archived` HEADING THE WAY ITS SIBLINGS DO.
#
# lived-probe.sh, archive.sh and kit-init.sh all require the exact line `## Archived`. A heading
# with trailing whitespace passes a looser check in setup.sh and is then refused downstream, so
# the board check must report it. The control is the exact heading, which must pass silently.
# =============================================================================
case_setup_reads_the_archived_heading_exactly() {
  cf_reset
  make_sandbox
  if [ ! -f "$SB_WORK/setup.sh" ]; then
    skp "setup.sh: an '## Archived ' heading with trailing whitespace is reported, the exact heading is not" "the sandbox carries no setup.sh"
    teardown; return
  fi
  local out
  printf '# ARCHIVE.md\n\n## Archived \n' > "$SB_WORK/ARCHIVE.md"
  out="$( cd "$SB_WORK" && ./setup.sh 2>&1 )" || true
  printf '%s\n' "$out" | grep "ARCHIVE.md has no '## Archived' heading" >/dev/null \
    || cf "(trailing space) an '## Archived ' heading was accepted, though archive.sh and kit-init.sh refuse it: $(printf '%s\n' "$out" | grep -i 'ARCHIVE' | tr '\n' '|')"
  printf '# ARCHIVE.md\n\n## Archived\n' > "$SB_WORK/ARCHIVE.md"
  out="$( cd "$SB_WORK" && ./setup.sh 2>&1 )" || true
  printf '%s\n' "$out" | grep "ARCHIVE.md has no '## Archived' heading" >/dev/null \
    && cf "(control) the exact '## Archived' heading was reported missing: $(printf '%s\n' "$out" | grep -i 'ARCHIVE' | tr '\n' '|')"
  finish "setup.sh: an '## Archived ' heading with trailing whitespace is reported missing, as the sibling readers treat it, and the exact heading is not"
  teardown
}

# =============================================================================
# CASE — THE ARMS ANSWER ABOUT THE NAMED REF, NOT ABOUT THE CHECKOUT.
#
# Board cases that publish before running cannot tell a checkout read from a ref read, so this
# case makes the two DISAGREE. It uses check (d): duplicate ids arise only on the trunk (two
# concurrent mints landing), so a checkout read is structurally blind to them.
#   (i)  a duplicate only in the working tree is NOT reported, and the report names its ref;
#   (ii) the same duplicate, once published, IS reported.
# Reading the checkout fails (i); reading nothing, or skipping when the trees differ, fails (ii).
# =============================================================================
case_check_board_reads_the_ref() {
  cf_reset
  make_sandbox
  seed_issue todo        "$SB_PREFIX-200" alpha chore "Published alpha"
  seed_issue in_progress "$SB_PREFIX-201" beta  chore "Published beta"
  publish_sandbox

  local out rc ref
  ref="origin/$SB_TRUNK"

  # --- (i) the divergence: a duplicate id in the WORKING TREE only ------------
  seed_issue dev_complete "$SB_PREFIX-200" unpublished-twin chore "Unpublished twin"
  [ -f "$SB_WORK/progress/dev_complete/$SB_PREFIX-200-unpublished-twin.md" ] \
    || cf "(control) the working-tree twin was not written — the divergence does not exist"
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep "$ref" >/dev/null \
    || cf "(i) the report does not name $ref anywhere — the operand is still invisible: $out"
  printf '%s\n' "$out" | grep -i 'duplicate' >/dev/null \
    && cf "(i) an UNPUBLISHED duplicate was reported — the arm read the checkout, not $ref: $out"
  printf '%s\n' "$out" | grep 'board-drift: clean ✓' >/dev/null \
    || cf "(i) the trunk is clean but the report did not say so: $out"

  # --- (ii) the ablation: publish it, and it must redden ----------------------
  publish_sandbox
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc after publishing (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep -i 'duplicate' >/dev/null \
    || cf "(ii) ABLATION FAILED — the duplicate is on $ref and was NOT reported, so half (i) proves nothing: $out"
  printf '%s\n' "$out" | grep -i 'duplicate' | grep "$SB_PREFIX-200" >/dev/null \
    || cf "(ii) the duplicate finding does not name $SB_PREFIX-200: $out"

  finish "check-board: the arms answer about $ref, not the checkout — an unpublished duplicate is NOT reported, the same duplicate published IS (ablation-proven), and the ref is named in the output"
  teardown
}

# =============================================================================
# CASE — A SHALLOW CLONE DOES NOT GET A DERIVED-LOOKING NARROWING.
#
# The history arms scope themselves to the commit that ADDED the commit-msg hook. In a shallow
# clone a grafted root has no parents, so every file reads as added there and the epoch resolves
# to the CLONE BOUNDARY. Shallow is the default CI checkout on most forges. The fix is to stop
# narrowing, not to skip: scanning what is present over-reports at worst. What must never happen
# is a narrowing that LOOKS derived.
# =============================================================================
case_check_board_shallow_clone_does_not_narrow() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-500" shallow chore "Shallow probe"
  publish_sandbox
  # A few commits so a depth-limited clone genuinely truncates something.
  local k
  for k in 1 2 3; do sbcommit -q --allow-empty -m "[PM] filler $k" >/dev/null 2>&1; done
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1

  local sh="$SB_TMP/shallow"
  git clone -q --depth 2 "file://$SB_ORIGIN" "$sh" >/dev/null 2>&1 \
    || { skp "a shallow clone does not get a derived-looking narrowing" "git could not make a shallow clone here"; teardown; return; }

  # INSTRUMENT: it must actually BE shallow, or the case is about an ordinary clone.
  [ "$(git -C "$sh" rev-parse --is-shallow-repository 2>/dev/null)" = "true" ] \
    || _fixture_die "case_check_board_shallow_clone_does_not_narrow: the clone is not shallow — every assertion below would be about a full history."
  # …and the epoch derivation must genuinely be WRONG there, or there is nothing to guard.
  local grafted
  grafted="$( { git -C "$sh" log --diff-filter=A --format=%H HEAD -- scripts/githooks/commit-msg 2>/dev/null || true; } | tail -1 )"
  [ -n "$grafted" ] \
    || _fixture_die "case_check_board_shallow_clone_does_not_narrow: the shallow clone resolves no add-commit at all, so the re-homing this case is about does not occur here."

  local out
  out="$( cd "$sh" && env -u CLAUDE_PROJECT_DIR ./scripts/check-board.sh --full 2>&1 )"
  printf '%s\n' "$out" | grep 'THIS IS A SHALLOW CLONE' >/dev/null \
    || cf "the report does not say the history is shallow — the arms narrowed against a graft boundary and presented it as a derived epoch: $out"
  printf '%s\n' "$out" | grep "scope: every commit after ${grafted:0:9}" >/dev/null \
    && cf "the report narrowed to the GRAFT BOUNDARY and named it as the rule's start — that commit is an artefact of the clone depth, not of the kit's arrival: $out"

  finish "a shallow clone gets no derived-looking narrowing: the arms say the history is shallow, exclude nothing, and never present the graft boundary as the rule's epoch"
  teardown
}

# =============================================================================
# CASE — arm [h]: the trailer scan SHARES arm (e)'s epoch and cannot invent its own.
#
# Rules (1) and (2) live in one file (scripts/githooks/commit-msg), so they bind from one commit.
# Two arms deriving it separately agree on ordinary histories and silently part on a re-add, a
# shallow boundary or a root epoch; the same-epoch assertion below catches that. The marker is
# read out of the hook, never typed, so a change to the marker list cannot leave a stale plant.
# =============================================================================
case_check_board_trailer_scan_shares_the_epoch() {
  cf_reset
  make_sandbox

  local hook="$SB_WORK/scripts/githooks/commit-msg" marker
  [ -f "$hook" ] \
    || _fixture_die "case_check_board_trailer_scan_shares_the_epoch: the sandbox ships no commit-msg hook, so there is no epoch to derive and no marker list to read."
  marker="$(sed -n "s/^TOOL_TRAILER_MARKERS='\([^|]*\).*/\1/p" "$hook" | head -1)"
  [ -n "$marker" ] \
    || _fixture_die "case_check_board_trailer_scan_shares_the_epoch: TOOL_TRAILER_MARKERS could not be read from the hook — the plant would carry a marker the arm never looks for, and this case would report a green about nothing."

  # (1) PRE-ADOPTION: no hook file in this commit at all, and a real trailer in it.
  mv "$hook" "$SB_TMP/commit-msg.held"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "$(printf '[PM] pre-adoption work\n\nCo-Authored-By: %s <noreply@invalid>' "$marker")" >/dev/null 2>&1
  local sha_pre; sha_pre="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"

  # (2) THE EPOCH: the kit copy lands, hook file and all.
  mv "$SB_TMP/commit-msg.held" "$hook"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "$(printf '[PM] init\n\nCo-Authored-By: %s <noreply@invalid>' "$marker")" >/dev/null 2>&1
  local sha_epoch; sha_epoch="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"
  local derived
  derived="$( { git -C "$SB_WORK" log --diff-filter=A --format=%h --abbrev=9 HEAD -- scripts/githooks/commit-msg 2>/dev/null || true; } | tail -1 )"
  [ "$derived" = "$sha_epoch" ] \
    || _fixture_die "case_check_board_trailer_scan_shares_the_epoch: the hook file's add-commit derives to '$derived', not the fixture's commit 2 '$sha_epoch' — the fixture does not model what the arms read."

  # (3) AFTER the rule began, from a checkout that never wired the hook. Correctly
  #     PREFIXED, so this commit is arm [h]'s finding alone and not also arm (e)'s.
  sbcommit -q --allow-empty -m "$(printf '[PM] a landing made from an unwired checkout\n\nCo-Authored-By: %s <noreply@invalid>' "$marker")" >/dev/null 2>&1
  local sha_after; sha_after="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"

  publish_sandbox

  local out rc hits scopes e_scope h_scope
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep '^\[h\]' >/dev/null \
    || cf "no [h] section — the arm is absent, which no other assertion here can detect: $out"

  hits="$(printf '%s\n' "$out" | grep 'carries a generated trailer' || true)"

  # ABLATION FIRST — without a red, both exclusions below are satisfiable by an arm
  # that reports nothing at all.
  printf '%s\n' "$hits" | grep "$sha_after" >/dev/null \
    || cf "ABLATION FAILED — the post-epoch trailer commit $sha_after was NOT reported, so this arm cannot go red and every exclusion asserted below proves nothing: $out"
  printf '%s\n' "$hits" | grep "$sha_pre" >/dev/null \
    && cf "the PRE-ADOPTION trailer commit $sha_pre was reported — it predates the hook file entirely: $(printf '%s' "$hits" | tr '\n' '|')"
  printf '%s\n' "$hits" | grep "$sha_epoch" >/dev/null \
    && cf "the EPOCH commit $sha_epoch was itself reported — the boundary is 'at or after' when it must be STRICTLY after: $(printf '%s' "$hits" | tr '\n' '|')"

  # THE COMPOSITION, compared as TEXT out of the two arms' OWN scope lines. This case
  # deliberately does NOT recompute the epoch: a third derivation would agree with
  # neither arm and would answer a question nobody asked.
  scopes="$(printf '%s\n' "$out" | grep -o 'scope: every commit after [0-9a-f]\{9\}' || true)"
  e_scope="$(printf '%s\n' "$scopes" | sed -n '1p')"
  h_scope="$(printf '%s\n' "$scopes" | sed -n '2p')"
  { [ -n "$e_scope" ] && [ -n "$h_scope" ]; } \
    || cf "fewer than two 'scope: every commit after <sha>' lines — one of the two history arms does not name its narrowing where its result is printed: $out"
  [ "$e_scope" = "$h_scope" ] \
    || cf "arms [e] and [h] name DIFFERENT epochs ('$e_scope' vs '$h_scope') — one rule, one file, two boundaries: the later one is silently hiding findings"

  # INSTRUMENT AGAINST A VACUOUS PASS: if nothing was out of scope, the two exclusions
  # above are satisfied by an arm that narrowed nothing.
  printf '%s\n' "$out" | grep -E "scope: every commit after ${sha_epoch}[^—]*— [1-9][0-9]* earlier commit\(s\) not read" >/dev/null \
    || cf "the scope line reports ZERO commits excluded — nothing was narrowed, so the exclusions above would pass vacuously: $out"

  # A HUMAN CO-AUTHOR IS NOT A FINDING. Without this the arm could be a bare
  # "co-authored-by" grep and every assertion above would still pass.
  sbcommit -q --allow-empty -m "$(printf '[PM] a pair-programmed landing\n\nCo-Authored-By: Jane Smith <jane@invalid>')" >/dev/null 2>&1
  local sha_human; sha_human="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"
  publish_sandbox
  printf '%s\n' "$(cb_run)" | grep 'carries a generated trailer' | grep "$sha_human" >/dev/null \
    && cf "a Co-Authored-By naming a HUMAN was reported as a generated trailer — the arm is matching the trailer rather than the tool markers, which the hook it mirrors explicitly permits"

  finish "check-board arm [h]: a generated trailer after the rule's epoch is reported (ablation-proven), one before it is not, the epoch commit itself is not, a HUMAN co-author is not, and [h] names the SAME epoch as [e]"
  teardown
}

# =============================================================================
# CASE — arm [h] reads the SAME attribution family the hook refuses, and folds the SAME Unicode
# hyphens the hook folds — one authoring site (lib/attrib-trailer.sh), not two readers that drift.
#
# The hook's rule (2) refuses the wording family `co-authored-by|co-developed-by|assisted-by|
# generated-by|signed-off-by` plus "generated/written (with|by) …" prose; [h] must match all of it, or an
# `Assisted-by:` trailer reads clean in the drift report while the hook — on a tree that had
# it wired — would refuse it. Separately, a Unicode hyphen (U+2011 non-breaking hyphen
# here) spells `Co‑Authored‑By:` in a way an ASCII-anchored pattern does not see.
#   (1) `Assisted-by:` (a wording the hook refuses and a narrower pair would miss) → reported
#   (2) the SAME family member, hyphens folded, matches what the HOOK itself would refuse — proven
#       by running the hook (MSG_OK unset) over the identical subject+trailer and reading its exit
#   (3) a U+2011-hyphenated `Co‑Authored‑By:` → reported by [h] (ablation: without the fix
#       a byte-literal `-by:` anchor does not see it)
# =============================================================================
case_check_board_arm_h_reads_the_hook_family() {
  cf_reset
  make_sandbox

  local hook="$SB_WORK/scripts/githooks/commit-msg"
  [ -f "$hook" ] \
    || _fixture_die "case_check_board_arm_h_reads_the_hook_family: the sandbox ships no commit-msg hook."
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "init" >/dev/null 2>&1

  # (1) a wording the hook refuses but [h]'s narrower earlier pair never matched.
  sbcommit -q --allow-empty -m "$(printf '[PM] a landing\n\nAssisted-by: Claude Code')" >/dev/null 2>&1
  local sha_assisted; sha_assisted="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"

  # (3) the SAME wording family, spelled with U+2011 (non-breaking hyphen) instead of ASCII `-`.
  sbcommit -q --allow-empty -m "$(printf '[PM] another landing\n\nCo\xe2\x80\x91Authored\xe2\x80\x91By: Claude')" >/dev/null 2>&1
  local sha_unicode; sha_unicode="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"

  # (4) a bare model-family name, and (5) a blank before the colon: the hook refuses both, so [h]
  # must name them — one list and one anchoring, read from the hook.
  sbcommit -q --allow-empty -m "$(printf '[PM] a third landing\n\nCo-Authored-By: Opus 5.5 <noreply@example.com>')" >/dev/null 2>&1
  local sha_model; sha_model="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"
  sbcommit -q --allow-empty -m "$(printf '[PM] a fourth landing\n\nCo-authored-by : Claude <x@y>')" >/dev/null 2>&1
  local sha_space; sha_space="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"

  publish_sandbox

  local out
  out="$(cb_run)"
  printf '%s\n' "$out" | grep "$sha_model" | grep 'carries a generated trailer' >/dev/null \
    || cf "(4) 'Co-Authored-By: Opus 5.5' ($sha_model) was NOT reported — a model-family word is not in the marker list [h] reads from the hook: $out"
  printf '%s\n' "$out" | grep "$sha_space" | grep 'carries a generated trailer' >/dev/null \
    || cf "(5) 'Co-authored-by : Claude' ($sha_space) was NOT reported — a blank before the colon defeats the anchor: $out"
  printf '%s\n' "$out" | grep "$sha_assisted" | grep 'carries a generated trailer' >/dev/null \
    || cf "(1) 'Assisted-by: Claude Code' ($sha_assisted) was NOT reported — [h] is still matching its own older, narrower pair rather than the hook's declared wording family: $out"
  printf '%s\n' "$out" | grep "$sha_unicode" | grep 'carries a generated trailer' >/dev/null \
    || cf "(3) a U+2011-hyphenated 'Co-Authored-By:' ($sha_unicode) was NOT reported — the Unicode hyphen was not folded before matching: $out"

  # (2) THE SAME MESSAGE, put through the hook itself (no MSG_OK): if the hook does not refuse
  # this exact subject+trailer, (1) proved [h] agrees with nothing and this case is circular.
  local msgfile rc
  msgfile="$SB_TMP/msg-assisted.txt"
  printf '[PM] a landing\n\nAssisted-by: Claude Code\n' > "$msgfile"
  rc=0; ( cd "$SB_WORK" && ./scripts/githooks/commit-msg "$msgfile" >/dev/null 2>&1 ) || rc=$?
  [ "$rc" -ne 0 ] \
    || cf "(2) the hook itself ACCEPTED 'Assisted-by: Claude Code' — [h] and the hook disagree, or the hook no longer refuses the wording (1) relies on"

  finish "check-board arm [h] reads the hook's own declared attribution-trailer family via lib/attrib-trailer.sh: 'Assisted-by:' is reported (1), agreeing with what the hook itself refuses over the identical message (2), a U+2011-hyphenated 'Co-Authored-By:' is reported once the Unicode hyphen is folded (3), and so are a model-family name (4) and a blank before the colon (5)"
  teardown
}

# =============================================================================
# CASE — arm [i]: blocks/blocked_by symmetry, and the four states it must tell apart.
#
# The fields are HAND-MAINTAINED (no script writes them), yet
# .claude/roles/orchestrator.md § Chain-verify-first gates DISPATCH on them, and an asymmetric
# pair reads fine on each card alone. The arm is ADVISORY by ruling, so this case asserts both
# halves: the findings print AND the verdict stays clean. A deciding version would hold
# release.sh gate (d) shut on a field nothing writes and nothing clears.
#
# FOUR DIRECTIONS, and the last two are what stop the arm being noise or a lie:
#   (i)   A declares blocks:[B]; B's blocked_by omits A            → reported
#   (ii)  B declares blocked_by:[A]; A's blocks omits B            → reported (CONVERSE)
#   (iii) a symmetric pair                                          → NOT reported
#   (iv)  a board where no card declares either field               → says so, and does
#         NOT print what (iii) prints
# =============================================================================
case_check_board_dependency_symmetry() {
  cf_reset

  # --- leg (iv) FIRST, on its own board: (i)-(iii) need declarations, and the two
  #     states must not be able to mask each other.
  make_sandbox
  seed_issue todo "$SB_PREFIX-300" lonely chore "No dependency declared anywhere"
  publish_sandbox
  local out rc
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(iv) check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep '^\[i\]' >/dev/null \
    || cf "(iv) no [i] section — the arm is absent, which no other assertion here can detect: $out"
  # THE EFFECT, not a label: it must say it READ cards and found ZERO declarations. That
  # is the only sentence separating "nothing to check" from "checked and symmetric".
  printf '%s\n' "$out" | grep -E '[1-9][0-9]* card\(s\) read, 0 dependency declaration\(s\)' >/dev/null \
    || cf "(iv) the arm does not distinguish an UNDECLARED board from a symmetric one — an empty result and a clean result print the same thing: $out"
  teardown

  # --- legs (i)(ii)(iii) on one board: three pairs, three outcomes, one run.
  cf_reset
  make_sandbox
  # (iii) SYMMETRIC CONTROL — must stay quiet, or every red below is just noise.
  seed_issue todo "$SB_PREFIX-310" sym-a chore "Symmetric A"
  seed_issue todo "$SB_PREFIX-311" sym-b chore "Symmetric B"
  cb_set_dep "$SB_PREFIX-310" sym-a todo blocks     "$SB_PREFIX-311"
  cb_set_dep "$SB_PREFIX-311" sym-b todo blocked_by "$SB_PREFIX-310"
  # (i) FORWARD — 320 says it blocks 321; 321 says nothing.
  seed_issue todo "$SB_PREFIX-320" fwd-a chore "Forward A"
  seed_issue todo "$SB_PREFIX-321" fwd-b chore "Forward B"
  cb_set_dep "$SB_PREFIX-320" fwd-a todo blocks "$SB_PREFIX-321"
  # (ii) REVERSE — 331 says it is blocked by 330; 330 says nothing. This is the half a
  #      `blocks:`-only arm is STRUCTURALLY blind to, and the half a concurrent mint
  #      actually produces.
  seed_issue todo "$SB_PREFIX-330" rev-a chore "Reverse A"
  seed_issue todo "$SB_PREFIX-331" rev-b chore "Reverse B"
  cb_set_dep "$SB_PREFIX-331" rev-b todo blocked_by "$SB_PREFIX-330"
  publish_sandbox

  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc (exit 0 ALWAYS)"

  # (i) and (ii): both reported, each naming BOTH cards — a finding naming one card is
  #     not actionable, because either card may be the stray.
  printf '%s\n' "$out" | grep "$SB_PREFIX-320" | grep "$SB_PREFIX-321" >/dev/null \
    || cf "(i) the forward asymmetry $SB_PREFIX-320 blocks $SB_PREFIX-321 was not reported naming both cards: $out"
  printf '%s\n' "$out" | grep "$SB_PREFIX-331" | grep "$SB_PREFIX-330" >/dev/null \
    || cf "(ii) THE CONVERSE IS UNIMPLEMENTED — $SB_PREFIX-331 declares blocked_by:[$SB_PREFIX-330], $SB_PREFIX-330 does not answer, and the arm is silent. An arm reading only blocks: is blind to half its operand set: $out"

  # (iii) ABLATION: the symmetric pair must NOT appear. Without this, (i) and (ii) are
  #       satisfied by an arm that prints every card it read.
  printf '%s\n' "$out" | grep '⚠' | grep "$SB_PREFIX-310" >/dev/null \
    && cf "(iii) ABLATION FAILED — the SYMMETRIC pair $SB_PREFIX-310/$SB_PREFIX-311 was reported, so the arm fires on a healthy board and (i)/(ii) prove nothing: $(printf '%s\n' "$out" | grep '⚠' | tr '\n' '|')"

  # THE ADVISORY RULING, asserted as an EFFECT and not as a word: findings are on the
  # report and the verdict is still clean. This fails the day somebody wires it to drift.
  printf '%s\n' "$out" | grep 'board-drift: clean ✓' >/dev/null \
    || cf "an ADVISORY arm changed the verdict — release.sh gate (d) refuses on this line, so a hand-maintained field with no producer would now block a release cut: $out"
  # …and the machine contract that makes kit-init drop it, on the arm's own header line.
  printf '%s\n' "$out" | grep '^\[i\]' | grep 'reports only' >/dev/null \
    || cf "the advisory arm omits the literal 'reports only' token, so kit-init.sh's self-check reads its findings as decisions and fails fresh installs: $(printf '%s\n' "$out" | grep '^\[i\]')"

  # INSTRUMENT AGAINST A VACUOUS PASS. Everything above is satisfiable by an arm that
  # never parsed a field, if the fixture's writes silently missed.
  printf '%s\n' "$out" | grep -E '[1-9][0-9]* card\(s\) read, [1-9][0-9]* dependency declaration\(s\)' >/dev/null \
    || cf "the arm reports ZERO declarations on a board carrying four — either the fixture's writes did not take or the parser does not read this YAML shape, and every assertion above is vacuous: $out"

  finish "check-board arm [i]: forward AND converse asymmetries are reported naming both cards, a symmetric pair is not (ablation-proven), an undeclared board says so rather than clearing, and the arm is advisory — the verdict stays clean and the header carries 'reports only'"
  teardown
}

# =============================================================================
# CASE — ARM (e) SCOPES ITSELF TO THE RULE'S LIFETIME, AND THE BOUNDARY IS STRICT.
#
# A rule cannot be violated before it exists: pre-adoption commits are findings nobody can fix
# short of rewriting published history, and they would fire on an adopter's first report.
# The fixture is the kit's day-one recipe: `git add -A && MSG_OK=1 git commit -m 'init'` commits
# the hook file under the unprefixed subject `init`, so the epoch commit must itself be excluded
# ("strictly after", not "at or after"). Commit 2 below is that commit.
# =============================================================================
case_check_board_arm_e_scopes_to_the_rules_lifetime() {
  cf_reset
  make_sandbox

  local hook="$SB_WORK/scripts/githooks/commit-msg"
  [ -f "$hook" ] \
    || _fixture_die "case_check_board_arm_e_scopes_to_the_rules_lifetime: the sandbox ships no scripts/githooks/commit-msg, so there is no epoch to derive and the case would prove nothing."

  # (1) PRE-ADOPTION — the hook file does not exist in this commit at all.
  mv "$hook" "$SB_TMP/commit-msg.held"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "pre-adoption work, made under no attribution rule" >/dev/null 2>&1
  local sha_pre; sha_pre="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"

  # (2) THE EPOCH — the kit copy lands, hook file and all, under the day-one subject.
  mv "$SB_TMP/commit-msg.held" "$hook"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "init" >/dev/null 2>&1
  local sha_epoch; sha_epoch="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"
  # INSTRUMENT: the epoch must really be commit 2, or "strictly after" is being asserted
  # against the wrong commit and every verdict below is about something else.
  local derived
  derived="$( { git -C "$SB_WORK" log --diff-filter=A --format=%h --abbrev=9 HEAD -- scripts/githooks/commit-msg 2>/dev/null || true; } | tail -1 )"
  [ "$derived" = "$sha_epoch" ] \
    || _fixture_die "case_check_board_arm_e_scopes_to_the_rules_lifetime: the hook file's add-commit derives to '$derived', not the fixture's commit 2 '$sha_epoch' — the fixture does not model what the arm reads."

  # (3) AFTER the rule began, still unprefixed — a REAL finding that must survive.
  sbcommit -q --allow-empty -m "an unprefixed commit made after the hook file arrived" >/dev/null 2>&1
  local sha_after; sha_after="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"

  publish_sandbox

  local out rc hits
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc (exit 0 ALWAYS)"

  # Read the FINDINGS, not the whole report: the scope line legitimately prints the
  # epoch's sha, so a bare absence grep would fail on the arm's own correct output.
  hits="$(printf '%s\n' "$out" | grep 'lacks a \[Role\] prefix' || true)"
  # FLATTENED for the messages below: cf renders ONE line, and $hits is a list — an
  # unflattened list reports its first entry and silently hides the one that fired.
  local hits1; hits1="$(printf '%s' "$hits" | tr '\n' '|')"

  printf '%s\n' "$hits" | grep "$sha_pre" >/dev/null \
    && cf "the PRE-ADOPTION commit $sha_pre was reported as drift — it predates the hook file entirely: $hits1"
  printf '%s\n' "$hits" | grep "$sha_epoch" >/dev/null \
    && cf "the EPOCH commit $sha_epoch was itself reported — the boundary is 'at or after' when it must be STRICTLY after, and this is the exact day-one line an adopter sees: $hits1"
  # INSTRUMENT / ABLATION: without this the three assertions above are all satisfiable by
  # an arm that reports nothing whatsoever.
  printf '%s\n' "$hits" | grep "$sha_after" >/dev/null \
    || cf "ABLATION FAILED — the post-epoch unprefixed commit $sha_after was NOT reported, so the arm cannot go red and every exclusion asserted above proves nothing: $out"

  # The narrowing is NAMED, with a non-zero count: a silent narrowing is itself a defect.
  printf '%s\n' "$out" | grep "scope: every commit after $sha_epoch, which ADDED scripts/githooks/commit-msg" >/dev/null \
    || cf "the scope line does not name the epoch it derived: $out"
  printf '%s\n' "$out" | grep -E "scope: every commit after $sha_epoch, which ADDED scripts/githooks/commit-msg — [1-9][0-9]* earlier commit\(s\) not read" >/dev/null \
    || cf "the scope line reports ZERO commits excluded — nothing was narrowed, so this case would pass vacuously: $out"
  # The accepted residual is stated where the result is printed.
  printf '%s\n' "$out" | grep "the epoch is the hook FILE's arrival" >/dev/null \
    || cf "the accepted residual (hook file present, core.hooksPath never set) is not stated in the arm's output: $out"

  teardown

  # --- SECOND TOPOLOGY: THE EPOCH IS THE ROOT COMMIT. ------------------------
  # The day-one recipe on a fresh `git init` puts the hook file in a commit with NO PARENT. A
  # boundary written `$EPOCH^..` then fails, reads as an EMPTY in-scope set with stderr
  # discarded, and the arm goes blind while printing a scope line and a green. The half above
  # always builds the epoch as commit 2 and cannot catch that.
  cf_reset
  make_sandbox
  local rhook="$SB_WORK/scripts/githooks/commit-msg"
  [ -f "$rhook" ] \
    || _fixture_die "case_check_board_arm_e_scopes_to_the_rules_lifetime: the sandbox ships no commit-msg hook for the root-epoch half."
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "init" >/dev/null 2>&1
  local sha_root; sha_root="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"
  # INSTRUMENT: it must really be a ROOT commit, or this half is the first one again.
  [ -z "$(git -C "$SB_WORK" rev-parse --verify --quiet 'HEAD^' || true)" ] \
    || _fixture_die "case_check_board_arm_e_scopes_to_the_rules_lifetime: the epoch commit has a parent — this half is not exercising the root topology it is named for."
  sbcommit -q --allow-empty -m "an unprefixed commit after the root epoch" >/dev/null 2>&1
  local sha_rafter; sha_rafter="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"
  publish_sandbox

  local rout rhits rhits1
  rout="$(cb_run)"
  rhits="$(printf '%s\n' "$rout" | grep 'lacks a \[Role\] prefix' || true)"
  rhits1="$(printf '%s' "$rhits" | tr '\n' '|')"
  printf '%s\n' "$rhits" | grep "$sha_rafter" >/dev/null \
    || cf "(root) ABLATION FAILED — with the epoch at the ROOT commit the arm reported NOTHING, so it went blind rather than scoping: $rout"
  printf '%s\n' "$rhits" | grep "$sha_root" >/dev/null \
    && cf "(root) the ROOT epoch commit was itself reported — strictly-after does not hold when the epoch has no parent: $rhits1"
  printf '%s\n' "$rout" | grep "scope: every commit after $sha_root" >/dev/null \
    || cf "(root) the scope line does not name the root epoch: $rout"

  finish "check-board arm (e): pre-adoption commits and the epoch commit ITSELF are excluded, a post-epoch unprefixed commit is still reported (ablation-proven), the narrowing is named with its count — and the same holds when the epoch is the ROOT commit, which is what the day-one recipe produces"
  teardown
}

# =============================================================================
# CASE — ARM (e)'s "Merge commit " EXEMPTION REQUIRES THE QUOTE.
#
# A subject that starts with the same two words as git's own generated merge subject
# (`Merge commit '<sha>'`) but is not one — "Merge commit messages into one doc" — must not be
# exempted by a bare prefix match: the arm would print "all N scanned subject(s) carry a [Role]
# prefix", a false sentence about a subject it never held to the rule.
# =============================================================================
case_check_board_arm_e_merge_commit_quote_boundary() {
  cf_reset
  make_sandbox

  local hook="$SB_WORK/scripts/githooks/commit-msg"
  [ -f "$hook" ] \
    || _fixture_die "case_check_board_arm_e_merge_commit_quote_boundary: the sandbox ships no commit-msg hook, so there is no epoch to derive and the case would prove nothing."

  # THE EPOCH, committed EXPLICITLY and FIRST: the arm's scope starts STRICTLY AFTER the
  # commit that ADDS scripts/githooks/commit-msg (case_check_board_arm_e_scopes_to_the_rules_lifetime
  # proves that boundary). Leaving the hook file for publish_sandbox's own trailing commit to
  # add would make THAT commit the epoch instead, and everything planted before it — including
  # the whole point of this case — would be silently excluded as "predating the rule".
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "init" >/dev/null 2>&1

  # A prefixed commit AFTER the epoch, so the false subject below is not the only in-scope one
  # and a false "all carry" verdict is distinguishable from "nothing was scanned".
  sbcommit -q --allow-empty -m "[PM] a properly prefixed landing" >/dev/null 2>&1

  # THE PLANT: an ordinary subject sharing git's merge-subject OPENING WORDS but none of its
  # shape (no opening quote, no hash) — never generated by git, and carrying no [Role] prefix.
  sbcommit -q --allow-empty -m "Merge commit messages into one doc" >/dev/null 2>&1
  local sha_false; sha_false="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"

  publish_sandbox

  local out rc
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc (exit 0 ALWAYS)"

  printf '%s\n' "$out" | grep "$sha_false" | grep 'lacks a \[Role\] prefix' >/dev/null \
    || cf "the false merge-shaped subject 'Merge commit messages into one doc' ($sha_false) was NOT reported as lacking a [Role] prefix — it was exempted by a prefix-only glob match on git's real merge-subject wording: $out"

  printf '%s\n' "$out" | grep -E '✓ all [0-9]+ scanned subject\(s\) carry a \[Role\] prefix' >/dev/null \
    && cf "ABLATION FAILED — the arm still printed the clean-verdict sentence over a scan that includes an unprefixed, non-exempt subject: $out"

  teardown

  # THE CONTROL: git's own generated shape, `Merge commit '<sha>'`, stays exempt — the quote
  # requirement narrows the glob, it does not remove the exemption it was protecting.
  # NOTE: no cf_reset here — findings from both halves accumulate into the ONE finish below,
  # or a red first half is silently wiped by a green control (the mistake this comment replaced).
  make_sandbox
  local hook2="$SB_WORK/scripts/githooks/commit-msg"
  [ -f "$hook2" ] \
    || _fixture_die "case_check_board_arm_e_merge_commit_quote_boundary: the sandbox ships no commit-msg hook for the control half."
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "init" >/dev/null 2>&1
  sbcommit -q --allow-empty -m "[PM] a properly prefixed landing" >/dev/null 2>&1
  sbcommit -q --allow-empty -m "Merge commit '1f00d13cc8b29fe812a87eb45eb35c34a5ca0ee2'" >/dev/null 2>&1
  local sha_real; sha_real="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"
  publish_sandbox
  local cout; cout="$(cb_run)"
  printf '%s\n' "$cout" | grep "$sha_real" | grep 'lacks a \[Role\] prefix' >/dev/null \
    && cf "(control) git's OWN generated merge subject \"Merge commit '<sha>'\" was reported as lacking a [Role] prefix — the quote-anchored fix over-narrowed the exemption it was meant to preserve: $cout"

  finish "check-board arm (e): an ordinary subject sharing git's merge-subject OPENING WORDS but not its quoted shape is reported as lacking a [Role] prefix, and the clean-verdict sentence does not print over it (ablation-proven) — while git's own generated \"Merge commit '<sha>'\" subject stays exempt"
  teardown
}

# =============================================================================
# CASE — arm [e] counts the exempted population APART from the prefixed one: "N subject(s) carry
# a [Role] prefix; M exempt … not held to it", never "all N+M carry".
#
# One prefixed subject, one exempted (git's own `Merge branch '…'`) — the clean-verdict sentence
# must print 1 and 1, never fold the exempted one into "all 2 carry a [Role] prefix", which is a
# sentence claiming this arm checked a subject it explicitly skipped.
# =============================================================================
case_check_board_arm_e_counts_exempt_apart() {
  cf_reset
  make_sandbox

  local hook="$SB_WORK/scripts/githooks/commit-msg"
  [ -f "$hook" ] \
    || _fixture_die "case_check_board_arm_e_counts_exempt_apart: the sandbox ships no commit-msg hook, so there is no epoch to derive."
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "init" >/dev/null 2>&1
  sbcommit -q --allow-empty -m "[PM] a properly prefixed landing" >/dev/null 2>&1
  sbcommit -q --allow-empty -m "Merge branch 'feature/x' into main" >/dev/null 2>&1
  publish_sandbox

  local out
  out="$(cb_run)"
  printf '%s\n' "$out" | grep -E '✓ all [0-9]+ scanned subject\(s\) carry a \[Role\] prefix' >/dev/null \
    && cf "ABLATION FAILED — the arm still prints the OLD 'all N carry' sentence, which counts the exempted merge subject toward N: $out"
  printf '%s\n' "$out" | grep -F '✓ 1 subject(s) carry a [Role] prefix; 1 exempt' >/dev/null \
    || cf "the two populations were not printed apart as '1 … ; 1 exempt …' — the exempted merge subject was counted toward the prefixed population, or the clean-verdict sentence's shape moved: $out"

  finish "check-board arm [e]: a scan with one prefixed and one exempted (merge) subject prints '1 subject(s) carry a [Role] prefix; 1 exempt … not held to it', never 'all 2 carry' (ablation-proven)"
  teardown
}

# =============================================================================
# CASE — NO LOCATION IS THE ONLY CORRECT ONE.
#
# Arm (f)'s publication path is registered against the MAIN worktree, so a report run from a
# linked worktree must still find it, and the trunk-property arms must still name the ref: no
# location may leave part of the report blind.
# =============================================================================
case_check_board_from_a_worktree() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-210" wt chore "Worktree control"
  publish_sandbox

  # A real board op, to bootstrap .kanban-wt the way an operator would. If the mover
  # cannot run here the control has no subject, so this is a SKIP, not a pass.
  if ! ( cd "$SB_WORK" && ./scripts/move-issue.sh "$SB_PREFIX-210" in_progress \
           --role "$SB_ROLE" --note "bootstrap the publication path" >/dev/null 2>&1 ); then
    skp "check-board from a linked worktree" "the board mover would not run in this sandbox, so .kanban-wt was never created"
    teardown; return
  fi
  [ -d "$SB_WORK/.kanban-wt" ] \
    || { skp "check-board from a linked worktree" ".kanban-wt was not created by the move"; teardown; return; }

  local wt="$SB_TMP/linked" out rc
  if ! git -C "$SB_WORK" worktree add --detach "$wt" "origin/$SB_TRUNK" >/dev/null 2>&1; then
    skp "check-board from a linked worktree" "git worktree add failed in this sandbox"
    teardown; return
  fi
  [ -x "$wt/scripts/check-board.sh" ] \
    || { cf "(control) the linked worktree has no scripts/check-board.sh — it cannot be run from there"; finish "check-board from a linked worktree"; teardown; return; }

  # Run the worktree's OWN copy, so REPO_ROOT resolves to the worktree — which is
  # exactly the situation the trap lived in.
  out="$( cd "$wt" && env -u CLAUDE_PROJECT_DIR "$wt/scripts/check-board.sh" --full 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc from a linked worktree (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep "origin/$SB_TRUNK" >/dev/null \
    || cf "the trunk-property arms do not name origin/$SB_TRUNK when run from a worktree: $out"
  printf '%s\n' "$out" | grep '\[f\].*no registered worktree' >/dev/null \
    && cf "arm [f] reported NO REGISTERED WORKTREE from a linked worktree — the publication path was not located against the main checkout, so the trap survives: $out"
  printf '%s\n' "$out" | grep '^\[f\]' >/dev/null \
    || cf "arm [f] printed no line at all from a linked worktree — a missing line is itself a finding: $out"

  finish "check-board is correct from a LINKED WORKTREE too: the trunk arms name origin/$SB_TRUNK and arm [f] still locates .kanban-wt against the main checkout"
  teardown
}

# =============================================================================
# CASE — arm [g], graduation: its three states, and the verdict control
#
# make_sandbox seeds no root documents, so each state below seeds AGENTS.md / README.md /
# PROJECT.md itself. The neutralizer deletes the stamp receipt from scripts/config.sh, so a
# state that wants the arm to run puts it back from KIT_STAMP_MARK: it is the enabling condition.
# =============================================================================
case_check_board_graduation() {
  cf_reset
  make_sandbox

  # ── (a) NO SIGNAL AT ALL: the check did not run, and says so. ───────────────
  # Built EMPTY on purpose: make_sandbox publishes a board, and a card is a lived signal too, so
  # removing only the receipt tests a tree that HAS started. This is the start of a sequence (the
  # same sandbox gains a receipt in (b)), so it proves the TRANSITION out of not-run; the
  # standalone not-run case proves the state itself. "Did not run" must not read as "nothing to
  # graduate from", so the absence of COMPLETE is asserted beside the not-run statement.
  rm -f "$SB_WORK"/progress/*/*-[0-9]*.md 2>/dev/null
  printf '# progress.md\n\n## Log\n\n' > "$SB_WORK/progress.md"
  printf '# ARCHIVE.md\n\n## Archived\n\n' > "$SB_WORK/ARCHIVE.md"
  seed_scaffolding_tree
  publish_sandbox

  local out
  out="$(cb_run)"
  printf '%s\n' "$out" | grep '^\[g\]' >/dev/null \
    || cf "(a) no [g] section — the arm is absent, which no other assertion here can detect"
  printf '%s\n' "$out" | _cb_g_section | grep 'THIS CHECK DID NOT RUN' >/dev/null \
    || cf "(a) with no signal at all the arm did not say it had not run: $out"
  # AND NOT BECAUSE THE SHARED PROBE WOULD NOT LOAD: that branch prints the same did-not-run
  # string, so a broken scripts/lib/lived-probe.sh would satisfy the assertion above.
  printf '%s\n' "$out" | _cb_g_section | grep 'could not be loaded' >/dev/null \
    && cf "the arm skipped because the shared already-lived probe would not load, not because this tree has no signal: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    && cf "(a) the arm claimed graduation on a tree with no sign of having started: $out"


  # ── (b) RECEIPT + SCAFFOLDING: it reports, and names the files. ──────────────
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  # THE UNFILLED PRECONDITION, FORCED EXPLICITLY: this state asserts CODE_GLOBS/TEST_GLOBS
  # report "empty, and not declared deliberately empty" below. On a tree past day one,
  # scripts/config.sh's copy of both arrays already carries a `# DECLARED EMPTY —` comment that
  # survives make_sandbox's neutralizer (it keeps comments, by contract), which would read as
  # DECLARED rather than unfilled. Reset both to genuinely empty/undeclared so this state's
  # premise holds regardless of the tree this harness runs in.
  _array_set_body "$SB_WORK/scripts/config.sh" CODE_GLOBS
  _array_set_body "$SB_WORK/scripts/config.sh" TEST_GLOBS
  publish_sandbox

  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'AGENTS.md' >/dev/null \
    || cf "(b) the REPLACE finding did not NAME AGENTS.md — instruments.md § A.4 wants the operand: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'README.md' >/dev/null \
    || cf "(b) the REPLACE finding did not name README.md: $out"
  printf '%s\n' "$out" | _cb_g_section | grep -i 'PROJECT.md still holds' >/dev/null \
    || cf "(b) the FILL finding did not fire on a PROJECT.md holding <trunk>: $out"
  # make_sandbox copies the real scripts/notify*.sh (and, where present, consumers/), which
  # declare KIT-DISPOSITION: DELETE-IF-UNUSED — with no process/LOCAL-PROCEDURES.md in this
  # sandbox (process/ is not copied by make_sandbox), every one of them must report unfilled.
  printf '%s\n' "$out" | _cb_g_section | grep 'DELETE-IF-UNUSED:.*no recorded decision' >/dev/null \
    || cf "(b) DELETE-IF-UNUSED was not reported unfilled over a real declaring file with no LOCAL-PROCEDURES.md record: $out"
  _decl_file="$(_cb_g_a_declaring_file)"
  if [ -z "$_decl_file" ]; then
    _delete_if_unused_members_all_removed || _fixture_die "no file in the sandbox declares DELETE-IF-UNUSED, yet this tree still holds a member the manifest names as one"
    teardown; skp_lived "check (g): DELETE-IF-UNUSED members are named by the finding" "$(_first_delete_if_unused_member) and every other DELETE-IF-UNUSED member was removed from this project, so there is no declaring file to name"; return
  fi
  printf '%s\n' "$out" | _cb_g_section | grep -F "$_decl_file" >/dev/null \
    || cf "(b) the DELETE-IF-UNUSED finding did not name $_decl_file: $out"
  # CODE_GLOBS/TEST_GLOBS/principal:. The sandbox's scripts/config.sh and PROJECT.md are still
  # the shipped, empty/blank shape at this point, so all three must report unfilled, each naming
  # what it leaves off, exactly as the other FILL members above do.
  printf '%s\n' "$out" | _cb_g_section | grep 'scripts/config.sh CODE_GLOBS.*empty, and not declared deliberately empty' >/dev/null \
    || cf "(b) an empty, undeclared CODE_GLOBS was not reported as unfilled: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'scripts/config.sh TEST_GLOBS.*empty, and not declared deliberately empty' >/dev/null \
    || cf "(b) an empty, undeclared TEST_GLOBS was not reported as unfilled: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'PROJECT.md principal:.*missing or unfilled' >/dev/null \
    || cf "(b) an unfilled principal: was not reported: $out"

  # ── (c) THE VERDICT CONTROL: graduation findings must never move the verdict, or release.sh's
  #    board gate and kit-init's self-check fail every fresh install.
  printf '%s\n' "$out" | grep 'board-drift: clean ✓' >/dev/null \
    || cf "(c) graduation findings changed the board verdict — release.sh gate (d) keys on this line, and a dirty verdict is what sends kit-init's self-check looking for a cause: $out"

  # ── (d) GRADUATED: it clears, and it NAMES ITS SOURCE while clearing. ────────
  # CODE_GLOBS filled, TEST_GLOBS declared deliberately empty (both directions a real adopter
  # may take), principal: filled with a name — so graduation still reaches COMPLETE only once
  # every member, old and new, is discharged.
  printf '# my project\n'                 > "$SB_WORK/AGENTS.md"
  printf '# my project\n'                 > "$SB_WORK/README.md"
  printf '<!-- %s — synthetic fill sheet, FILLED. -->\n# PROJECT.md\n\nTrunk: main\n\n## Who answers when nobody is watching\n\n- **`principal:`** `Fixture Owner`\n- **Their channel:** `dev/questions/`\n' \
    "$KIT_FILL_DISPOSITION" > "$SB_WORK/PROJECT.md"
  # CODE_GLOBS: a real entry, exercising the "filled" direction. TEST_GLOBS: a DECLARED EMPTY
  # sentinel, exercising the "declared deliberately empty" direction — both directions a real
  # adopter may take, both through the one shared authoring site.
  _cb_g_fill_glob_array CODE_GLOBS '  "src/*"'
  _cb_g_fill_glob_array TEST_GLOBS '  # DECLARED EMPTY -- fixture has no test tree.'
  # DELETE-IF-UNUSED: record the kept-on-purpose decision for every real declaring file the
  # sandbox carries (scripts/notify*.sh, and consumers/ where present) — graduation reaches
  # COMPLETE only once this member, too, is discharged. .gitignore/.env.example: make_sandbox
  # never seeds either (the real kit ships both, filled), so they are filled here too.
  _cb_g_discharge_delete_if_unused
  _cb_g_discharge_gitignore_env
  _cb_g_land_day_one_work
  publish_sandbox

  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    || cf "(d) a graduated tree did not clear: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'read from:' >/dev/null \
    || cf "(d) the CLEARING branch did not name its operand — instruments.md § A.4, the asymmetry that only errs toward false confidence: $out"
  printf '%s\n' "$out" | _cb_g_section | grep -i 'still scaffolding' >/dev/null \
    && cf "(d) a graduated tree still reported scaffolding: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'scripts/config.sh CODE_GLOBS.*declares 1 entry' >/dev/null \
    || cf "(d) a filled CODE_GLOBS was not read as clear: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'scripts/config.sh TEST_GLOBS.*declared DECLARED EMPTY' >/dev/null \
    || cf "(d) a TEST_GLOBS array declared deliberately empty was not accepted: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'PROJECT.md principal:.*declared' >/dev/null \
    || cf "(d) a filled principal: was not read as clear: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'DELETE-IF-UNUSED:.*carry a recorded kept-on-purpose decision' >/dev/null \
    || cf "(d) a recorded DELETE-IF-UNUSED decision was not read as discharged: $out"

  finish "check (g): graduation says THIS CHECK DID NOT RUN with no signal, reports and names its files while scaffolding stands, clears once replaced naming its source (including CODE_GLOBS/TEST_GLOBS/principal:/DELETE-IF-UNUSED) — and never moves the board verdict"
  teardown
}

# =============================================================================
# CASE — arm [g]'s ENABLING DIRECTION: a lived signal with NO receipt
#
# Arm [g] reads several lived signals and the receipt is only one; every other case builds the
# receipt. This is the positive half for another signal: a card on the board, receipt ABSENT,
# arm REPORTS.
# =============================================================================
case_check_board_graduation_enabled_without_receipt() {
  cf_reset
  make_sandbox
  # No receipt: the neutralizer already stripped it, and nothing here puts it back.
  seed_scaffolding_tree
  seed_issue todo "$SB_PREFIX-410" lived chore "A card on the board is a lived signal"
  publish_sandbox

  # ASSERT THE PREMISE: no receipt. With one, the case would pass for the reason every other
  # case already covers and prove nothing about the other signals.
  local _sig; _sig="$(_lived_signals)"
  printf '%s' "$_sig" | grep 'stamp receipt' >/dev/null \
    && _fixture_die "case_check_board_graduation_enabled_without_receipt: the sandbox carries a stamp receipt, so this case would be enabled by the signal every other case already builds and would prove nothing about the other three."
  printf '%s' "$_sig" | grep 'issue file' >/dev/null \
    || _fixture_die "case_check_board_graduation_enabled_without_receipt: no issue file is on the board, so the signal this case exists to exercise is absent and a green would mean nothing."

  local out; out="$(cb_run)"
  # ANCHOR THE SECTION. The negative below is satisfied by an EMPTY section; what protects it is
  # the sibling POSITIVE (grep on empty input returns 1), not this anchor, which only names an
  # absent arm. Do not delete the positive believing this line guards the case.
  printf '%s\n' "$out" | grep '^\[g\]' >/dev/null \
    || cf "no [g] section — the arm is absent, which no other assertion here can detect"
  printf '%s\n' "$out" | _cb_g_section | grep 'THIS CHECK DID NOT RUN' >/dev/null \
    && cf "(enabled) a board carrying an issue file did not enable the arm — it reads four signals and this is one of them: $out"
  printf '%s\n' "$out" | _cb_g_section | grep -i 'still scaffolding' >/dev/null \
    || cf "(enabled) the arm ran but reported no finding on an unreplaced scaffolding tree: $out"
  # NAME THE SIGNAL. An enabling condition is an operand, and a reader who wants to know
  # why the check ran on their tree should not have to reason it out.
  printf '%s\n' "$out" | _cb_g_section | grep 'enabled by:' >/dev/null \
    || cf "(enabled) the arm did not name the signal that enabled it: $out"

  finish "check (g): a lived signal OTHER than the receipt — a card on the board — enables the arm, and it names which signal did"
  teardown
}

# =============================================================================
# CASE — arm [g]'s NOT-RUN DIRECTION, as its own named control
#
# Deliberately duplicates state (a) of the graduation case: a state buried in a multi-state case
# is the one that gets refactored away.
#
# BOTH HALVES ARE ASSERTED, because a check that says NOTHING satisfies the first alone.
# =============================================================================
case_check_board_graduation_not_run_direction() {
  cf_reset
  make_sandbox
  # DELIBERATELY EMPTY: no receipt, no issue files, no § Log history, nothing archived.
  rm -f "$SB_WORK"/progress/*/*-[0-9]*.md 2>/dev/null
  printf '# progress.md\n\n## Log\n\n' > "$SB_WORK/progress.md"
  printf '# ARCHIVE.md\n\n## Archived\n\n' > "$SB_WORK/ARCHIVE.md"
  publish_sandbox

  # ASSERT THE PREMISE: no lived signal at all, or this case tests the other direction while
  # reporting on this one.
  local _sig; _sig="$(_lived_signals)"
  [ -z "$_sig" ] \
    || _fixture_die "case_check_board_graduation_not_run_direction: the fixture carries lived signal(s) — $(printf '%s' "$_sig" | tr '\n' ';') — so the arm WILL run and this case is the enabling direction wearing the not-run name."

  local out; out="$(cb_run)"
  # ANCHOR THE SECTION. The negative below is satisfied by an EMPTY section; what protects it is
  # the sibling POSITIVE (grep on empty input returns 1), not this anchor, which only names an
  # absent arm. Do not delete the positive believing this line guards the case.
  printf '%s\n' "$out" | grep '^\[g\]' >/dev/null \
    || cf "no [g] section — the arm is absent, which no other assertion here can detect"
  printf '%s\n' "$out" | _cb_g_section | grep 'THIS CHECK DID NOT RUN' >/dev/null \
    || cf "(not-run) the arm did not state that it had not run, so a reader cannot tell an unrun check from a clean one: $out"
  # AND NOT BECAUSE THE SHARED PROBE WOULD NOT LOAD: that branch prints the same did-not-run
  # string, so a broken scripts/lib/lived-probe.sh would satisfy the assertion above.
  printf '%s\n' "$out" | _cb_g_section | grep 'could not be loaded' >/dev/null \
    && cf "the arm skipped because the shared already-lived probe would not load, not because this tree has no signal: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    && cf "(not-run) the arm claimed graduation on a tree with no sign of having started: $out"

  finish "check (g): with NO signal at all the arm says THIS CHECK DID NOT RUN and never claims completion — an unrun check is not a clean one"
  teardown
}

# =============================================================================
# CASE — arm [g] reads the TRUNK, and this is the case that matters
# =============================================================================
case_check_board_graduation_reads_the_trunk() {
  cf_reset
  make_sandbox

  # Scaffolding published; receipt present. The arm reports.
  seed_scaffolding_tree
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  publish_sandbox

  local out
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep -i 'still scaffolding' >/dev/null \
    || cf "precondition failed: the arm did not report on published scaffolding: $out"

  # ── GRADUATE IN THE WORKING TREE ONLY. DO NOT PUBLISH. ──────────────────────
  # The arm is one-way: a working-tree read would clear here and never re-open.
  printf '# my project\n'                > "$SB_WORK/AGENTS.md"
  printf '# my project\n'                > "$SB_WORK/README.md"
  printf '<!-- %s — synthetic fill sheet, FILLED. -->\n# PROJECT.md\n\nTrunk: main\n\n## Who answers when nobody is watching\n\n- **`principal:`** `Fixture Owner`\n- **Their channel:** `dev/questions/`\n' \
    "$KIT_FILL_DISPOSITION" > "$SB_WORK/PROJECT.md"
  # [g]'s CODE_GLOBS/TEST_GLOBS members must also clear for graduation to read COMPLETE here —
  # this case only needs [g] clear, not either direction's content, so both are declared empty.
  _cb_g_declare_empty_seams
  _cb_g_discharge_delete_if_unused
  _cb_g_discharge_gitignore_env
  _cb_g_land_day_one_work
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "[Architect] graduate, unpublished" >/dev/null 2>&1
  # deliberately NO push

  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep -i 'still scaffolding' >/dev/null \
    || cf "THE ARM READ THE WORKING TREE: it cleared on an unpublished graduation, and a one-way arm that clears early never re-opens: $out"
  printf '%s\n' "$out" | _cb_g_section | grep "$SB_TRUNK" >/dev/null \
    || cf "the arm did not name the trunk ref it answered about: $out"

  # And it clears once the work is actually published — the other direction.
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    || cf "the arm did not clear once the graduation was published: $out"

  finish "check (g) is a TRUNK read: an unpublished graduation does NOT clear it (a one-way arm that clears early never re-opens), and publishing does"
  teardown
}

# =============================================================================
# CASE — arm [g]'s REPLACE population is DERIVED from the declarations, as its ✓ line says
#
# A file declaring REPLACE in its header block is checked wherever it lives. A file that only
# QUOTES the marker below its header block, as a manual's worked example does, is not a member.
# =============================================================================
case_check_board_replace_population_is_derived() {
  cf_reset
  make_sandbox
  seed_scaffolding_tree
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  mkdir -p "$SB_WORK/docs"
  printf '<!-- KIT-CLASS: KIT — synthetic.\n     %s — replace it. -->\n%s\n# guide\n' \
    "$KIT_REPLACE_DISPOSITION" "$KIT_SCAFFOLD_MARK" > "$SB_WORK/docs/GUIDE.md"
  { printf '# quotes the marker\n'; printf 'line\n%.0s' 1 2 3 4 5 6 7 8 9 10 11 12
    printf '<!-- %s -->\n%s\n' "$KIT_REPLACE_DISPOSITION" "$KIT_SCAFFOLD_MARK"; } > "$SB_WORK/docs/QUOTE.md"
  publish_sandbox

  local out line
  out="$(cb_run)"
  line="$(printf '%s\n' "$out" | _cb_g_section | grep 'still scaffolding' || true)"
  printf '%s' "$line" | grep -F 'docs/GUIDE.md' >/dev/null \
    || cf "a file declaring REPLACE outside the root was not checked: ${line:-no REPLACE finding} — $out"
  printf '%s' "$line" | grep -F 'docs/QUOTE.md' >/dev/null \
    && cf "a file that only quotes the marker below its header block was counted as declaring it: $line"
  printf '%s' "$line" | grep -F 'AGENTS.md' >/dev/null && printf '%s' "$line" | grep -F 'README.md' >/dev/null \
    || cf "(control) the shipped REPLACE pair left the population: ${line:-no REPLACE finding}"

  finish "check (g): the REPLACE population is every file whose header block declares it, wherever it lives, and not a file that quotes the marker further down"
  teardown
}

# =============================================================================
# CASE — arm [g]'s (g3) DELETE-IF-UNUSED class: a real recorded decision, exactly matched.
#
# make_sandbox copies the real scripts/notify*.sh (and, where present, consumers/), which
# declare KIT-DISPOSITION: DELETE-IF-UNUSED — an otherwise-graduated tree with none of them
# discharged must NOT read COMPLETE, and the member must be NAMED as unfilled; the exact kept-
# on-purpose line clears it; a mention by basename or in free prose does not.
# =============================================================================
case_check_board_graduation_delete_if_unused() {
  cf_reset
  make_sandbox
  seed_scaffolding_tree
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  printf '# my project\n'                 > "$SB_WORK/AGENTS.md"
  printf '# my project\n'                 > "$SB_WORK/README.md"
  printf '<!-- %s — synthetic fill sheet, FILLED. -->\n# PROJECT.md\n\nTrunk: main\n\n## Who answers when nobody is watching\n\n- **`principal:`** `Fixture Owner`\n- **Their channel:** `dev/questions/`\n' \
    "$KIT_FILL_DISPOSITION" > "$SB_WORK/PROJECT.md"
  _cb_g_declare_empty_seams
  _cb_g_discharge_gitignore_env
  _cb_g_land_day_one_work
  publish_sandbox

  # ── (a) a DELETE-IF-UNUSED member present, no recorded decision: not COMPLETE, named. ───────
  local out
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    && cf "(a) graduation COMPLETE over a tree with an undischarged DELETE-IF-UNUSED member: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'DELETE-IF-UNUSED:.*no recorded decision' >/dev/null \
    || cf "(a) an undischarged DELETE-IF-UNUSED member was not reported: $out"
  _decl_file="$(_cb_g_a_declaring_file)"
  if [ -z "$_decl_file" ]; then
    _delete_if_unused_members_all_removed || _fixture_die "no file in the sandbox declares DELETE-IF-UNUSED, yet this tree still holds a member the manifest names as one"
    teardown; skp_lived "check (g): DELETE-IF-UNUSED members are named by the finding" "$(_first_delete_if_unused_member) and every other DELETE-IF-UNUSED member was removed from this project, so there is no declaring file to name"; return
  fi
  printf '%s\n' "$out" | _cb_g_section | grep -F "$_decl_file" >/dev/null \
    || cf "(a) the finding did not NAME the declaring file $_decl_file — instruments.md § A.4 wants the operand: $out"

  # ── (b) the exact kept-on-purpose line: COMPLETE. ─────────────────────────────────────────────
  mkdir -p "$SB_WORK/process"
  rm -f "$SB_WORK/process/LOCAL-PROCEDURES.md"
  _cb_g_discharge_delete_if_unused
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'DELETE-IF-UNUSED:.*carry a recorded kept-on-purpose decision' >/dev/null \
    || cf "(b) the exact kept-on-purpose line was not read as discharged: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    || cf "(b) a tree with every DELETE-IF-UNUSED member recorded kept did not reach graduation COMPLETE: $out"

  # ── (c) a basename-only / free-prose mention: still unfilled, not COMPLETE. ──────────────────
  printf '%s\n' "# LOCAL-PROCEDURES.md

We looked at notify.sh and notify-hook.sh and telegram.sh and decided to keep them, on purpose,
since nothing uses scripts/notify yet. consumers is also kept on purpose." \
    > "$SB_WORK/process/LOCAL-PROCEDURES.md"
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'DELETE-IF-UNUSED:.*no recorded decision' >/dev/null \
    || cf "(c) a basename-only / free-prose mention was read as a recorded decision — it must match the exact line, not a mention: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    && cf "(c) graduation COMPLETE over a LOCAL-PROCEDURES.md that only mentions the members in free prose: $out"

  # ── (d) the member REMOVED from the tree entirely: discharged, COMPLETE. ─────────────────────
  _cb_g_remove_delete_if_unused_members
  rm -f "$SB_WORK/process/LOCAL-PROCEDURES.md"
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'DELETE-IF-UNUSED: 0 file' >/dev/null \
    || cf "(d) a tree with every DELETE-IF-UNUSED member removed was not read as a measured, empty population: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    || cf "(d) a tree with every DELETE-IF-UNUSED member removed (a valid discharge) did not reach graduation COMPLETE: $out"

  finish "check (g3): DELETE-IF-UNUSED is measured from the same KIT-DISPOSITION header-block declarations REPLACE uses — an undischarged member blocks COMPLETE and is named, the exact kept-on-purpose line in process/LOCAL-PROCEDURES.md clears it, a basename/prose-only mention does not, and removing the member entirely is an equally valid discharge"
  teardown
}

# =============================================================================
# CASE — the release and refactor routes are DELETE-IF-UNUSED, and graduation reads each.
#
# A project that ships nothing, or never restructures, must remove the route or record keeping it
# on purpose. The five members are a FIXED operand (the decided set, not derived from the tree
# they judge): each must declare the marker in its header block, arm [g] must NAME each while
# undischarged, and removing all five (with every other declaring member discharged) reads COMPLETE.
# =============================================================================
case_release_refactor_routes_are_delete_if_unused() {
  cf_reset
  local why; why="$(_tree_has_lived)"
  if [ -n "$why" ]; then
    skp_lived "the release and refactor routes declare KIT-DISPOSITION: DELETE-IF-UNUSED (scripts/release.sh)" "$why"
    return
  fi
  if ! has_issue_template; then skp "the release and refactor routes declare DELETE-IF-UNUSED" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  local _decl='^[[:space:]]*(#|<!--|//|--)?[[:space:]]*KIT-DISPOSITION:[[:space:]]*DELETE-IF-UNUSED([^A-Za-z0-9_]|$)'
  local routes="scripts/release.sh scripts/new-refactor.sh .claude/roles/refactorer.md .claude/agents/refactorer-worker.md .claude/templates/REFACTOR.template.md"
  local p out
  for p in $routes; do
    if [ ! -f "$REAL_REPO_ROOT/$p" ]; then
      cf "$p is absent from a tree that has not been adopted"; continue
    fi
    sed -n '1,12p' "$REAL_REPO_ROOT/$p" | grep -E "$_decl" >/dev/null \
      || cf "$p does not declare KIT-DISPOSITION: DELETE-IF-UNUSED in its header block"
  done

  make_sandbox
  seed_scaffolding_tree
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  printf '# my project\n'                 > "$SB_WORK/AGENTS.md"
  printf '# my project\n'                 > "$SB_WORK/README.md"
  printf '<!-- %s — synthetic fill sheet, FILLED. -->\n# PROJECT.md\n\nTrunk: main\n\n## Who answers when nobody is watching\n\n- **`principal:`** `Fixture Owner`\n- **Their channel:** `dev/questions/`\n' \
    "$KIT_FILL_DISPOSITION" > "$SB_WORK/PROJECT.md"
  _cb_g_declare_empty_seams
  _cb_g_discharge_gitignore_env
  _cb_g_land_day_one_work
  mkdir -p "$SB_WORK/.claude/roles" "$SB_WORK/.claude/agents" "$SB_WORK/.claude/templates"
  for p in $routes; do
    case "$p" in .claude/*) [ -f "$REAL_REPO_ROOT/$p" ] && cp "$REAL_REPO_ROOT/$p" "$SB_WORK/$p" ;; esac
  done
  publish_sandbox

  # (a) undischarged: not COMPLETE, and every route is NAMED.
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    && cf "(a) graduation COMPLETE with the release and refactor routes undischarged: $out"
  for p in $routes; do
    printf '%s\n' "$out" | _cb_g_section | grep -F "$p" >/dev/null \
      || cf "(a) the DELETE-IF-UNUSED finding did not name $p: $out"
  done

  # (b) all five removed, every other declaring member discharged: COMPLETE.
  for p in $routes; do rm -f "$SB_WORK/$p"; done
  _cb_g_discharge_delete_if_unused
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    || cf "(b) removing the release and refactor routes (the other members discharged) did not reach graduation COMPLETE: $out"
  for p in $routes; do
    printf '%s\n' "$out" | _cb_g_section | grep -F "$p" >/dev/null \
      && cf "(b) a removed route $p is still named by [g]: $out"
  done

  finish "the release and refactor routes (release.sh, new-refactor.sh, the Refactorer role, its leaf worker and its template) each declare DELETE-IF-UNUSED, arm [g] names each while undecided, and removing all five reads graduation COMPLETE"
  teardown
}

# =============================================================================
# CASE — the KIT-FEEDBACK arm REPORTS a missing line and never refuses it.
#
# Under `kit-feedback: auto` (PROJECT.md § The kit, upstream — and a missing setting line reads
# as auto) each session's newest progress.md entry ends with a `kit-feedback:` line. The arm says
# what it found; a missing line is REPORTED, never refused, so the verdict never moves.
#   (1) auto, the newest entry has its line      → the line's value is printed
#   (2) auto, the newest entry has NONE          → ⚠ reported; the verdict is unchanged (control
#       below: the same board, the arm's marked block deleted from a copy)
#   (3) off                                      → not checked
#   (4) NO setting line, newest entry has none   → "none declared, read as auto", then ⚠
#   (5) auto, no dated entry at all              → "no session entry yet" — the shipped progress.md
#   (6) kit-init's board self-check DROPS (2)'s ⚠: its filter is EXTRACTED from kit-init.sh at run
#       time, never copied, and run over the report (2) produced; a header without the token is
#       the control that the filter keeps a finding.
#   (7) a FRESH kit-init completes with the arm in the report: the ⚠ condition cannot coexist with
#       a fresh install (a dated progress.md entry is a lived signal, which kit-init refuses — also
#       asserted here), so the install meets the arm's no-entry branch and must stay COMPLETE.
# =============================================================================
_kf_board() {  # <PROJECT.md setting line or ""> <progress.md Log body> — writes, publishes, runs
  make_sandbox
  { printf '# PROJECT.md\n\n## The kit, upstream\n\n'; [ -n "$1" ] && printf '%s\n' "$1"; } > "$SB_WORK/PROJECT.md"
  printf '# progress.md\n\n## Log\n\n%s' "$2" > "$SB_WORK/progress.md"
  publish_sandbox
  _kf_out="$(cb_run)"
  _kf_sec="$(printf '%s\n' "$_kf_out" | awk '/^\[[a-z]\] kit-feedback line/{f=1; print; next} f && /^(\[[a-z]\]|──)/{exit} f')"
  _kf_one="$(printf '%s' "$_kf_sec" | tr '\n' '|')"   # for messages: one line, so a FAIL line holds all its reasons
}
case_kit_feedback_line_is_reported_not_refused() {
  cf_reset
  local auto='- `kit-feedback: auto` — the kit default' e_old e_with e_without v1 v2 abl filt kept out rc
  # THE OLDER ENTRY IS THE OPPOSITE OF THE NEWEST in each board, so an arm that read any entry
  # but the newest gets (1) and (2) wrong in opposite directions.
  e_with='### 2026-01-01\n\n- [Dev] an older session, no line.\n\n### 2026-01-02\n\n- [Dev] did the work.\n- `kit-feedback: none`\n'
  e_without='### 2026-01-01\n\n- [Dev] an older session.\nkit-feedback: none\n\n### 2026-01-02\n\n- [Dev] did the work, and wrote no kit-feedback line.\n'

  # (1)
  _kf_board "$auto" "$(printf "$e_with")"
  printf '%s\n' "$_kf_sec" | grep -E '^\[[a-z]\] kit-feedback line .*reports only' >/dev/null \
    || cf "(1) no kit-feedback header carrying 'reports only': ${_kf_one:-no section}"
  printf '%s\n' "$_kf_sec" | grep -F '(2026-01-02): kit-feedback: none' >/dev/null \
    || cf "(1) the newest entry's line was not reported: $_kf_one"
  printf '%s\n' "$_kf_sec" | grep '⚠' >/dev/null && cf "(1) a present line was reported as missing: $_kf_one"
  teardown

  # (2) + the verdict control
  _kf_board "$auto" "$(printf "$e_without")"
  printf '%s\n' "$_kf_sec" | grep '⚠' | grep -F 'has no kit-feedback:' >/dev/null \
    || cf "(2) a newest entry with no kit-feedback line was not reported: ${_kf_one:-no section}"
  v1="$(printf '%s\n' "$_kf_out" | grep '^── board-drift:')"
  abl="$SB_WORK/scripts/check-board-ablated.sh"
  awk '/^# BEGIN kit-feedback arm/{skip=1} !skip{print} /^# END kit-feedback arm/{skip=0}' "$SB_WORK/scripts/check-board.sh" > "$abl"; chmod +x "$abl"
  grep -q 'kit-feedback line' "$abl" && _control_did_not_run "delete the arm's marked block from a copy of check-board.sh"
  rc=0; out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR ./scripts/check-board-ablated.sh 2>&1 )" || rc=$?
  rm -f "$abl"
  v2="$(printf '%s\n' "$out" | grep '^── board-drift:')"
  [ "$v2" = "── board-drift: clean ✓" ] \
    || _control_did_not_run "build a board whose verdict is clean without the arm (it was: ${v2:-none})"
  [ "$v1" = "$v2" ] || cf "(2) the verdict moved with the arm reporting a missing line: with '$v1', without '$v2'"
  # (6) kit-init's own filter, extracted, over this very report
  filt="$(awk '/KI_FINDINGS="\$\(printf/{f=1; next} f && /^[[:space:]]*'"'"' \| grep/{exit} f' "$SB_WORK/scripts/kit-init.sh")"
  if [ -z "$filt" ] || ! printf '%s' "$filt" | grep 'reports only' >/dev/null; then
    _control_did_not_run "extract kit-init's advisory filter from kit-init.sh (found: ${filt:-nothing})"
  else
    kept="$(printf '%s\n' "$_kf_out" | awk "$filt" | grep '⚠' | grep 'kit-feedback' || true)"
    [ -z "$kept" ] || cf "(6) kit-init's board self-check would count the kit-feedback ⚠ as a finding: $kept"
    kept="$(printf '%s\n' "$_kf_sec" | sed 's/reports only/REPORTS/' | awk "$filt" | grep '⚠' || true)"
    [ -n "$kept" ] || _control_did_not_run "show the extracted filter KEEPS a finding under a header without the token"
  fi
  teardown

  # (3)
  _kf_board '- `kit-feedback: off` — not for the kit' "$(printf "$e_without")"
  printf '%s\n' "$_kf_sec" | grep -F 'kit-feedback: off — not checked' >/dev/null \
    || cf "(3) off was not reported as not checked: ${_kf_one:-no section}"
  printf '%s\n' "$_kf_sec" | grep '⚠' >/dev/null && cf "(3) a missing line was reported under off: $_kf_one"
  teardown

  # (4)
  _kf_board "" "$(printf "$e_without")"
  printf '%s\n' "$_kf_sec" | grep -F 'none declared' | grep -F 'read as auto' >/dev/null \
    || cf "(4) a PROJECT.md with no setting line was not read as auto, out loud: ${_kf_one:-no section}"
  printf '%s\n' "$_kf_sec" | grep '⚠' >/dev/null || cf "(4) read as auto, the missing line was not reported: $_kf_one"
  teardown

  # (5)
  _kf_board "$auto" ""
  printf '%s\n' "$_kf_sec" | grep -F 'no session entry yet' >/dev/null \
    || cf "(5) a Log with no dated entry was not reported as nothing to check: ${_kf_one:-no section}"
  teardown

  # (7) a fresh kit-init completes; and a dated entry makes it refuse as lived
  if has_kit_init && has_issue_template; then
    kit_init_sandbox
    printf '# progress.md\n\n## Log\n\n' > "$SB_WORK/progress.md"
    publish_sandbox
    rc=0; out="$( cd "$SB_WORK" && ./scripts/kit-init.sh --prefix SBX --trunk "$SB_TRUNK" 2>&1 )" || rc=$?
    [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep 'kit-init COMPLETE and PROVEN' >/dev/null \
      || cf "(7) a fresh kit-init did not complete with the arm in check-board's report (rc=$rc): $(printf '%s' "$out" | tail -6 | tr '\n' '|')"
    teardown
    kit_init_sandbox
    printf '# progress.md\n\n## Log\n\n### 2026-01-02\n\n- [Dev] a session.\n' > "$SB_WORK/progress.md"
    publish_sandbox
    rc=0; out="$( cd "$SB_WORK" && ./scripts/kit-init.sh --prefix SBX --trunk "$SB_TRUNK" 2>&1 )" || rc=$?
    [ "$rc" -ne 0 ] || cf "(7) kit-init accepted a tree whose progress.md holds a dated entry — the arm's ⚠ condition CAN meet a fresh install, and (6) is then the only guard"
    teardown
  fi

  finish "check-board's kit-feedback arm reports the newest entry's line (1), reports a missing one without moving the verdict (2), skips off (3), reads a missing setting as auto out loud (4), has nothing to check before the first entry (5), is dropped by kit-init's own extracted filter (6), and a fresh install still completes (7)"
}

# =============================================================================
# CASE — ARM (s): MODEL PINS VS THE LADDER, AND VS SET-MODELS.SH'S RECORD WHERE THE LADDER IS BLANK.
#
# Two routes to a pin that disagrees, each red-first:
#   route 1 — a hand edit on a tree whose ladder is FILLED: the pin is compared with the ladder cell.
#   route 2 — a hand edit on a tree whose ladder is UNFILLED: a ladder cell says nothing to compare
#             against, so a plain "pin equals ladder" check reads it as agreement. The pin is then
#             compared with what set-models.sh last wrote (.claude/model-pins.record).
# The fixture follows the real order: set-models.sh runs, the tree is committed and pushed, the
# report reads the trunk; then a hand edit is committed and pushed, and the report is read again.
# Controls: the same tree before the edit and after it is undone reads clean; deleting the record
# silences route 2 (so the record, not the ladder, is what catches it) and the report then says the
# field is not checkable; the arm carries the 'reports only' token and never moves the verdict; and
# stripping the arm from check-board.sh removes the finding.
# =============================================================================
case_check_board_model_pins_arm() {
  cf_reset
  make_sandbox
  local ad orch out sec label f
  read -r ad orch <<<"$(_seed_provisioning_sandbox)"
  if [ -z "$ad" ]; then skp "arm (s): model pins vs the ladder" "no .claude/agents + roles/orchestrator.md in the real tree"; teardown; return; fi
  local sm="$SB_WORK/scripts/set-models.sh" rec="$SB_WORK/.claude/model-pins.record"
  [ -x "$sm" ] || { cf "scripts/set-models.sh is absent or not executable — the kit ships it"; finish "arm (s): model pins vs the ladder"; teardown; return; }
  _set_pin_effort() { awk -v e="$2" '/^effort:/{print "effort: " e; next} {print}' "$1" > "$1.new" && mv "$1.new" "$1"; }
  _verdict() { printf '%s\n' "$1" | grep '^── board-drift'; }

  # 1. the seam, then the report.
  ( cd "$SB_WORK" && ./scripts/set-models.sh --all --model m-one --effort e-one >/dev/null 2>&1 ) \
    || _fixture_die "set-models.sh --all refused in the sandbox"
  [ -f "$rec" ] || cf "set-models.sh --all wrote no .claude/model-pins.record"
  publish_sandbox
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_s_section)"
  [ -n "$sec" ] || cf "no [s] section in the report — the arm is absent: $out"
  printf '%s\n' "$sec" | grep -E '^      ⚠ .* pin says' >/dev/null \
    && cf "(control) a tree the seam just wrote reads as drifted: $sec"
  printf '%s\n' "$sec" | grep -E '[1-9][0-9]* pin field\(s\) compared with the ladder' >/dev/null \
    || cf "(control) the arm compared nothing against the filled ladder: $sec"
  printf '%s\n' "$sec" | grep -E '[1-9][0-9]* pin field.*✓ all [1-9][0-9]* compared field\(s\) agree' >/dev/null \
    || cf "(control) a clean tree with fields compared does not tick over the population it compared: $sec"
  local v_clean; v_clean="$(_verdict "$out")"

  # 2. ROUTE 1 — a hand edit, ladder filled.
  _set_pin_effort "$ad/dev-worker.md" high
  publish_sandbox
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_s_section)"
  printf '%s\n' "$sec" | grep -F "dev-worker.md effort: the pin says 'high', the ladder's Dev row says 'e-one'" >/dev/null \
    || cf "route 1: a hand-edited effort pin against a filled ladder was NOT reported: $sec"
  [ "$(printf '%s\n' "$sec" | grep -c '^      ⚠ .* pin says')" -eq 1 ] \
    || cf "route 1: expected exactly one finding: $sec"
  printf '%s\n' "$out" | grep '^\[s\]' | grep -i 'reports only' >/dev/null \
    || cf "[s]'s header does not carry the 'reports only' token"
  [ "$(_verdict "$out")" = "$v_clean" ] \
    || cf "[s] moved the verdict: '$v_clean' before, '$(_verdict "$out")' with a finding"
  _set_pin_effort "$ad/dev-worker.md" e-one
  publish_sandbox
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_s_section)"
  printf '%s\n' "$sec" | grep -E '^      ⚠ .* pin says' >/dev/null \
    && cf "(control) undoing the hand edit left a finding: $sec"

  # 3. ROUTE 2 — the ladder is unfilled (its rows blanked), then a hand edit.
  for label in "Orchestrator" "Refactorer" "PM-hat mint" "Spike / probe" "Dev" "QA" "XS / mechanical" "Cleanup / classifier"; do
    _blank_ladder_row "$orch" "$label"
  done
  publish_sandbox
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_s_section)"
  printf '%s\n' "$sec" | grep -E '^      ⚠ .* pin says' >/dev/null \
    && cf "(control) an unfilled ladder with untouched pins reads as drifted: $sec"
  printf '%s\n' "$sec" | grep -E '[1-9][0-9]* with set-models.sh.s record' >/dev/null \
    || cf "(control) with the ladder unfilled the arm did not fall back to the record: $sec"
  _set_pin_effort "$ad/dev-worker.md" high
  publish_sandbox
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_s_section)"
  printf '%s\n' "$sec" | grep -F "dev-worker.md effort: the pin says 'high', set-models.sh last wrote 'e-one' and the ladder's Dev row is unfilled" >/dev/null \
    || cf "route 2: a hand-edited effort pin against an unfilled ladder was NOT reported: $sec"

  # 4. ABLATION — without the record the same edit is silent, and the report says it cannot check.
  git -C "$SB_WORK" rm -q -f .claude/model-pins.record
  publish_sandbox
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_s_section)"
  printf '%s\n' "$sec" | grep -E '^      ⚠ .* pin says' >/dev/null \
    && cf "(control) route 2's finding survived the record's removal, so the record is not what caught it: $sec"
  printf '%s\n' "$sec" | grep -E '[1-9][0-9]* not checkable' >/dev/null \
    || cf "with no filled cell and no record the arm did not say the fields are not checkable: $sec"
  printf '%s\n' "$sec" | grep '✓' >/dev/null \
    && cf "with nothing compared the arm still printed a tick: $sec"
  printf '%s\n' "$sec" | grep -F 'nothing was compared' >/dev/null \
    || cf "with nothing compared the arm did not say so: $sec"

  # 5. ABLATION — strip the arm itself.
  _set_pin_effort "$ad/dev-worker.md" e-one
  local s="$SB_WORK/scripts/check-board.sh"
  grep -q '# (s) MODEL PINS VS THE LADDER' "$s" || cf "(control) no '(s) MODEL PINS VS THE LADDER' seam in check-board.sh — cannot ablate"
  sed -i.bak '/# (s) MODEL PINS VS THE LADDER/,/# END model-pins arm/d' "$s"; rm -f "$s.bak"
  bash -n "$s" || cf "(control) the ablated check-board.sh no longer parses"
  out="$(cb_run)"
  printf '%s\n' "$out" | grep '^\[s\]' >/dev/null && cf "(control) the ablation left [s] printing"

  finish "arm (s): a hand-edited pin is reported against a filled ladder, and against set-models.sh's record where the ladder is unfilled; an untouched or restored tree reads clean, the record is what route 2 rests on, and the arm only reports"
  teardown
}

# =============================================================================
# CASE — ARM (s) NAMES THE ROLE DOCS' MODEL TABLES THAT STILL HOLD `<fill in>`.
#
# set-models.sh writes the ladder row and the pin; the per-role tables are kept by hand, so a tree
# whose seam ran can still carry blank tables. The role docs are copied from the real tree and their
# table rows then set to a known state by this case's own writers (the real docs may be filled,
# on a lived tree). Order as in use: blank tables, the seam, the report; then the hand fill, the report.
# Controls: the seam fills orchestrator.md's table and so removes only that file from the line;
# a hand-filled tree prints no line; the line carries 'reports only' and never moves the verdict;
# and without the arm's call the line is gone.
# =============================================================================
case_check_board_model_pins_arm_names_blank_role_doc_tables() {
  cf_reset
  make_sandbox
  local ad orch out sec src d f line n want total=0 s v_blank
  read -r ad orch <<<"$(_seed_provisioning_sandbox)"
  if [ -z "$ad" ]; then skp "arm (s): blank role-doc model tables" "no .claude/agents + roles/orchestrator.md in the real tree"; teardown; return; fi
  src=""
  for d in "$REAL_REPO_ROOT/_claude" "$REAL_REPO_ROOT/.claude"; do [ -d "$d/roles" ] && src="$d"; done
  _rows_in_table() {  # the table data rows (a backticked cell) of the doc's Model & effort section
    awk '/^## /{ s = ($0 ~ /^## Model & effort contract/) } s && /^\|/ && /`/ { c++ } END { print c + 0 }' "$1"
  }
  _set_table_cells() {  # <doc> <text> — every model/effort cell of the section's rows becomes `<text>`, a cell a tree that finished day one answered with DECLARED NONE included (the case judges the arm on a table it blanked itself, so it must blank those too)
    awk -v t="$2" '/^## /{ s = ($0 ~ /^## Model & effort contract/) }
      s && /^\|/ && (/`/ || /DECLARED NONE/) { n = split($0, p, "|"); o = p[1]
        for (i = 2; i <= n; i++) { c = p[i]
          if (i >= 3 && i <= 4 && match(c, /`[^`]*`/)) c = substr(c, 1, RSTART - 1) "`" t "`" substr(c, RSTART + RLENGTH)
          else if (i >= 3 && i <= 4 && c ~ /DECLARED NONE/) c = " `" t "` "
          o = o "|" c }
        print o; next }
      { print }' "$1" > "$1.new" && mv "$1.new" "$1"
  }
  for f in dev qa pm refactorer; do
    [ -f "$src/roles/$f.md" ] && cp "$src/roles/$f.md" "$SB_WORK/.claude/roles/$f.md"
  done
  for f in "$SB_WORK"/.claude/roles/*.md; do
    _set_table_cells "$f" "<fill in>"
    n="$(_rows_in_table "$f")"
    [ "$n" -gt 0 ] || _fixture_die "$f has no model-table rows to blank"
    total=$((total + n))
  done
  local sm="$SB_WORK/scripts/set-models.sh"
  [ -x "$sm" ] || { cf "scripts/set-models.sh is absent or not executable — the kit ships it"; finish "arm (s): blank role-doc model tables"; teardown; return; }
  ( cd "$SB_WORK" && ./scripts/set-models.sh --all --model m-one --effort e-one >/dev/null 2>&1 ) \
    || _fixture_die "set-models.sh --all refused in the sandbox"
  # The seam filled the ladder rows, so those rows no longer count; derive that population from the doc.
  want="$(awk '/^## /{ s = ($0 ~ /^## Model & effort contract/) } s && /^\|/ && /<fill in/ { c++ } END { print c + 0 }' "$orch")"
  # A project that removed the Refactorer leaves its optional ladder row blank (the seam skips a class
  # whose leaf worker is gone) and arm (s) never counts ladder rows, so that row is not a blank left.
  if _member_removed .claude/agents/refactorer-worker.md && [ "$want" -gt 0 ]; then want=$((want - 1)); fi
  publish_sandbox
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_s_section)"
  v_blank="$(printf '%s\n' "$out" | grep '^── board-drift')"
  line="$(printf '%s\n' "$sec" | grep 'role-doc model row')"
  [ -n "$line" ] || cf "blank per-role tables after set-models.sh --all: no role-doc line in [s]: $sec"
  for f in dev qa pm; do
    [ -f "$SB_WORK/.claude/roles/$f.md" ] && { printf '%s\n' "$line" | grep -F "$f.md (" >/dev/null || cf "the line does not name $f.md: $line"; }
  done
  printf '%s\n' "$line" | grep -F "orchestrator.md" >/dev/null && [ "$want" -eq 0 ] \
    && cf "the line names orchestrator.md though the seam filled its table: $line"
  n="$(printf '%s\n' "$line" | sed -n 's/^ *⚠ \([0-9]*\) role-doc.*/\1/p')"
  [ "$n" = "$((total - $(_rows_in_table "$orch") + want))" ] \
    || cf "the count is '$n', not the blank rows left ($((total - $(_rows_in_table "$orch") + want))): $line"
  printf '%s\n' "$line" | grep -i 'reports only' >/dev/null || cf "the line does not say it only reports: $line"

  # The ladder rows set-models.sh writes are not counted even while blank: orchestrator.md blanked
  # again, the line still names none of them and the count does not move.
  _set_table_cells "$orch" "<fill in>"
  publish_sandbox
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_s_section)"
  line="$(printf '%s\n' "$sec" | grep 'role-doc model row')"
  printf '%s\n' "$line" | grep -F "orchestrator.md" >/dev/null \
    && cf "the line counts orchestrator.md's ladder rows, which set-models.sh writes: $line"
  [ "$(printf '%s\n' "$line" | sed -n 's/^ *⚠ \([0-9]*\) role-doc.*/\1/p')" = "$n" ] \
    || cf "blanking the ladder rows moved the count from $n: $line"

  # Hand-filled: no line, and the verdict is the same as with the blanks.
  for f in "$SB_WORK"/.claude/roles/*.md; do _set_table_cells "$f" "m-two"; done
  publish_sandbox
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_s_section)"
  printf '%s\n' "$sec" | grep 'role-doc model row' >/dev/null && cf "(control) filled tables still print the line: $sec"
  [ "$(printf '%s\n' "$out" | grep '^── board-drift')" = "$v_blank" ] \
    || cf "the line moved the verdict: '$v_blank' with blanks, '$(printf '%s\n' "$out" | grep '^── board-drift')' filled"

  # Ablation: blank again, strip the arm's call, the line is gone.
  _set_table_cells "$SB_WORK/.claude/roles/dev.md" "<fill in>"
  s="$SB_WORK/scripts/check-board.sh"
  grep -q 'kit_model_blank_rows' "$s" || cf "(control) check-board.sh never calls kit_model_blank_rows — cannot ablate"
  sed -i.bak 's/^  kit_model_blank_rows "\$CB_TREE"$/  :/' "$s"; rm -f "$s.bak"
  bash -n "$s" || cf "(control) the ablated check-board.sh no longer parses"
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | grep 'role-doc model row' >/dev/null && cf "(control) the ablation left the line printing"

  finish "arm (s) names the role docs whose own model table still holds <fill in> (count and files), skips the one the seam filled, prints nothing once they are filled, never moves the verdict, and goes silent without its call"
  teardown
}

# =============================================================================
# CASE — check-board's [t] arm lists a question file that CARRIES AN ANSWER and that NO REGISTER
# ENTRY CITES (answered, not reconciled), each with the card it parks.
#
# RED FIRST: the unfixed script has no [t]. The fixture follows the real order: the card is on the
# board, the PM files the question parking it (ask.sh --card), the question file is committed to the
# trunk; LATER the principal appends an Answer block and that is committed; LATER a register entry
# citing the question file lands. The operand is the question file's path appearing in
# requirements/DECISIONS.md, or not.
# Rows: no answer -> not listed; answer, nothing cites it -> a finding line carrying the path and the card;
# answer with no --card -> "no card named"; the entry added -> no longer listed (the others stay);
# a file channel -> the arm says it cannot attribute and lists nothing; the arm only reports (header
# token, verdict unchanged); stripping the arm removes the finding.
# =============================================================================
case_check_board_answered_question_arm() {
  cf_reset
  make_sandbox
  _ask_fill_pm "$SB_WORK"
  mkdir -p "$SB_WORK/requirements"
  cat > "$SB_WORK/requirements/DECISIONS.md" <<'REG'
# DECISIONS.md

## A. test bucket

### D-01 — an unrelated ruling

**Ruling.** Keep it small.
**Why.** Because.
**Provenance.** 2026-01-01, no work item.

---
REG
  seed_issue blocked "$SB_PREFIX-860" clear-out chore "Clear-out waits on a period"
  seed_issue blocked "$SB_PREFIX-861" digest chore "Digest waits on a day"
  publish_sandbox
  _verdict() { printf '%s\n' "$1" | grep '^── board-drift'; }
  _qpath() { local q="$1"; printf 'dev/questions/%s' "${q#*/dev/questions/}"; }

  # The PM files the questions. The first two park a card; the third parks none.
  local o1 o2 o3 q1 q2 q3 r1 r2 r3
  o1="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec1" ./scripts/ask.sh --role PM "How long to keep details?" --default "Hold." --card "$SB_PREFIX-860" 2>&1 )" \
    || _fixture_die "ask.sh --card refused in the sandbox: $o1"
  o2="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec2" ./scripts/ask.sh --role PM "Which weekday?" --default "Monday." --card "$SB_PREFIX-861" 2>&1 )" \
    || _fixture_die "second ask.sh --card refused in the sandbox: $o2"
  o3="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec3" ./scripts/ask.sh --role PM "Any colour?" --default "Blue." 2>&1 )" \
    || _fixture_die "ask.sh with no --card refused in the sandbox: $o3"
  q1="$(printf '%s\n' "$o1" | sed -n 's/^ask.sh: question written to //p')"; r1="$(_qpath "$q1")"
  q2="$(printf '%s\n' "$o2" | sed -n 's/^ask.sh: question written to //p')"; r2="$(_qpath "$q2")"
  q3="$(printf '%s\n' "$o3" | sed -n 's/^ask.sh: question written to //p')"; r3="$(_qpath "$q3")"
  [ -f "$q1" ] && [ -f "$q2" ] && [ -f "$q3" ] || _fixture_die "case_check_board_answered_question_arm: ask.sh wrote no question file(s): '$q1' '$q2' '$q3'"
  publish_sandbox

  local out sec v_clean
  # 1. NOTHING ANSWERED: not listed; the arm still says what it read.
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_t_section)"
  [ -n "$sec" ] || cf "no [t] section in the report — the arm is absent: $out"
  printf '%s\n' "$sec" | grep '⚠' >/dev/null && cf "1: an unanswered question is listed: $sec"
  printf '%s\n' "$sec" | grep -E '3 question file' >/dev/null \
    || cf "1: the arm does not say how many question files it read (an arm that prints nothing when clean is indistinguishable from one that broke): $sec"
  printf '%s\n' "$out" | grep '^\[t\]' | grep -i 'reports only' >/dev/null \
    || cf "1: [t]'s header does not carry the 'reports only' token"
  v_clean="$(_verdict "$out")"

  # 2. THE PRINCIPAL ANSWERS two of them (a later act, appended to the committed files).
  printf '\n**Answer (2026-10-17, Ros):** Eighteen months.\n' >> "$q1"
  printf '\n**Answer (2026-10-17, Ros):** Fridays.\n' >> "$q2"
  printf '\n**Answer (2026-10-17, Ros):** Green.\n' >> "$q3"
  publish_sandbox
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_t_section)"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$r1" | grep -F "$SB_PREFIX-860" >/dev/null \
    || cf "2: the answered question $r1 is not listed with a ⚠ naming the card $SB_PREFIX-860: $sec"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$r2" | grep -F "$SB_PREFIX-861" >/dev/null \
    || cf "2: the answered question $r2 is not listed with a ⚠ naming the card $SB_PREFIX-861: $sec"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$r3" | grep -F 'no card named' >/dev/null \
    || cf "2: the answered question with no --card is not listed as 'no card named': $sec"
  [ "$(_verdict "$out")" = "$v_clean" ] || cf "2: [t] moved the verdict: '$v_clean' before, '$(_verdict "$out")' with findings"

  # 3. A REGISTER ENTRY CITING THE FIRST QUESTION FILE LANDS: it is no longer listed; the others stay.
  cat >> "$SB_WORK/requirements/DECISIONS.md" <<REG

### D-02 — the retention period

**Ruling.** Eighteen months after the last confirmation.
**Why.** The principal's answer, recorded as given.
**Provenance.** 2026-10-17, the principal's answer in $r1; no work item.

---
REG
  publish_sandbox
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_t_section)"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$r1" >/dev/null \
    && cf "3: $r1 is still listed after a register entry cites it: $sec"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$r2" >/dev/null \
    || cf "3: $r2 stopped being listed although no entry cites it: $sec"

  # 4. A FILE CHANNEL: the arm cannot attribute an answer to a question and says so.
  printf '<!-- KIT-CLASS: KIT -->\n# PROJECT.md\n\n## Who answers when nobody is watching\n\n- **`principal:`** `Nadia, shop manager`\n- **Their channel:** `dev/questions.md`\n' > "$SB_WORK/PROJECT.md"
  publish_sandbox
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_t_section)"
  printf '%s\n' "$sec" | grep '⚠' >/dev/null && cf "4: a file channel produced a finding: $sec"
  printf '%s\n' "$sec" | grep -i 'skipped' >/dev/null || cf "4: a file channel did not say the arm was skipped: $sec"

  # 5. ABLATION — strip the arm.
  local s="$SB_WORK/scripts/check-board.sh"
  grep -q '# (t) ANSWERED QUESTIONS' "$s" || cf "(control) no '(t) ANSWERED QUESTIONS' seam in check-board.sh — cannot ablate"
  sed -i.bak '/# (t) ANSWERED QUESTIONS/,/# END answered-question arm/d' "$s"; rm -f "$s.bak"
  bash -n "$s" || cf "(control) the ablated check-board.sh no longer parses"
  out="$(cb_run)"
  printf '%s\n' "$out" | grep '^\[t\]' >/dev/null && cf "(control) the ablation left [t] printing"

  finish "arm (t): an answered question no register entry cites is listed with a ⚠ naming its path and the card it parks ('no card named' when none), an unanswered one is not, a citing register entry removes it, a file channel is skipped with the reason, the arm only reports, and stripping it removes the finding"
  teardown
}

# =============================================================================
# CASE — the report says what it did NOT read: a main checkout holding changes no arm reads ([f0]),
# and an answer that sits in this checkout but not on the trunk ([t]).
#
# RED FIRST: the unfixed script has no [f0], and [t] reads only <remote>/<trunk>, so an `**Answer`
# appended to a committed question file and left uncommitted reads "none" and board-drift clean.
# Rows: clean tree -> an [f0] line with no ⚠, no finding; answer uncommitted -> [t] names the file and
# "uncommitted", [f0] carries a ⚠; answer committed, not pushed -> "committed, unpushed"; answer pushed ->
# no finding, [f0] clean; a dirty README.md -> [f0] names it without a ⚠; a dirty register -> ⚠;
# the verdict never moves; each block stripped removes its own line.
# =============================================================================
case_check_board_reports_what_only_this_checkout_holds() {
  cf_reset
  make_sandbox
  _ask_fill_pm "$SB_WORK"
  mkdir -p "$SB_WORK/requirements"
  printf '# DECISIONS.md\n\n## A. test bucket\n\n### D-01 — an unrelated ruling\n\n**Ruling.** Keep it small.\n**Why.** Because.\n**Provenance.** 2026-01-01, no work item.\n\n---\n' > "$SB_WORK/requirements/DECISIONS.md"
  printf '# the project\n' > "$SB_WORK/README.md"
  publish_sandbox
  _verdict() { printf '%s\n' "$1" | grep '^── board-drift'; }
  local o1 q1 r1 out sec f0 v_clean
  o1="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec1" ./scripts/ask.sh --role Dev "Which of A or B?" --default "A." 2>&1 )" \
    || _fixture_die "case_check_board_reports_what_only_this_checkout_holds: ask.sh refused: $o1"
  q1="$(printf '%s\n' "$o1" | sed -n 's/^ask.sh: question written to //p')"; r1="dev/questions/${q1#*/dev/questions/}"
  [ -f "$q1" ] || _fixture_die "case_check_board_reports_what_only_this_checkout_holds: ask.sh wrote no question file: '$q1'"
  publish_sandbox

  # 0. A CLEAN TREE: the [f0] line is there, says clean, carries no ⚠; [t] has no local finding.
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_t_section)"; f0="$(printf '%s\n' "$out" | grep -F '[f0]')"
  [ -n "$f0" ] || cf "0: no [f0] line in the report — the arm does not say whether the working tree holds changes it did not read: $(printf '%s' "$out" | grep -F '[f]' | tr '\n' '|')"
  case "$f0" in *⚠*) cf "0: [f0] carries a ⚠ over a clean tree: $f0" ;; esac
  case "$f0" in *"reports only"*) : ;; *) cf "0: the clean [f0] line lacks the 'reports only' token: $f0" ;; esac
  printf '%s\n' "$sec" | grep -F 'answered but not on' >/dev/null && cf "0: [t] lists a local answer in a clean tree: $sec"
  v_clean="$(_verdict "$out")"

  # 1. THE ANSWER IS APPENDED AND NOT COMMITTED: [t] names the file and says uncommitted; [f0] warns;
  #    the verdict does not move.
  printf '\n**Answer (2026-10-25, Ros):** B.\n' >> "$q1"
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_t_section)"; f0="$(printf '%s\n' "$out" | grep -F '[f0]')"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$r1" | grep -F "answered but not on origin/$SB_TRUNK" | grep -F '(uncommitted)' >/dev/null \
    || cf "1: [t] does not name $r1 as answered but not on origin/$SB_TRUNK (uncommitted): $sec"
  printf '%s\n' "$sec" | grep -F '✓ none' >/dev/null && cf "1: [t] still says '✓ none' over an answer only this checkout holds: $sec"
  case "$f0" in *⚠*"$r1"*) : ;; *) cf "1: [f0] does not warn about the uncommitted question file $r1: $f0" ;; esac
  case "$f0" in *"reports only"*) : ;; *) cf "1: the warning [f0] line lacks the 'reports only' token: $f0" ;; esac
  [ "$(_verdict "$out")" = "$v_clean" ] || cf "1: the new lines moved the verdict: '$v_clean' before, '$(_verdict "$out")' after"

  # 2. COMMITTED, NOT PUSHED.
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -m "[PM] answer recorded" --quiet >/dev/null 2>&1
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_t_section)"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$r1" | grep -F '(committed, unpushed)' >/dev/null \
    || cf "2: [t] does not name $r1 as committed, unpushed: $sec"

  # 3. PUSHED: no local finding; [f0] clean.
  publish_sandbox
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_t_section)"; f0="$(printf '%s\n' "$out" | grep -F '[f0]')"
  printf '%s\n' "$sec" | grep -F 'answered but not on' >/dev/null && cf "3: [t] lists an answer that is on origin/$SB_TRUNK: $sec"
  case "$f0" in *⚠*) cf "3: [f0] warns over a clean tree after the push: $f0" ;; esac

  # 4. A DIRTY FILE NO ARM READS: [f0] names it and says no arm reads it, with no ⚠.
  printf 'edited\n' >> "$SB_WORK/README.md"
  out="$(cb_run)"; f0="$(printf '%s\n' "$out" | grep -F '[f0]')"
  case "$f0" in *README.md*) : ;; *) cf "4: [f0] does not name the dirty README.md: $f0" ;; esac
  case "$f0" in *"NOT read by any arm"*) : ;; *) cf "4: [f0] does not say no arm reads it: $f0" ;; esac
  case "$f0" in *⚠*) cf "4: [f0] warns about a path no arm reads: $f0" ;; esac
  case "$f0" in *"reports only"*) : ;; *) cf "4: the not-read [f0] line lacks the 'reports only' token: $f0" ;; esac
  # ... and a dirty register: the arms read it, so [f0] warns.
  printf '\n### D-02 — local only\n' >> "$SB_WORK/requirements/DECISIONS.md"
  out="$(cb_run)"; f0="$(printf '%s\n' "$out" | grep -F '[f0]')"
  case "$f0" in *⚠*requirements/DECISIONS.md*) : ;; *) cf "4: [f0] does not warn about a dirty register the arms would have read: $f0" ;; esac
  case "$f0" in *"reports only"*) : ;; *) cf "4: the register-dirty [f0] line lacks the 'reports only' token: $f0" ;; esac
  [ "$(_verdict "$out")" = "$v_clean" ] || cf "4: [f0] moved the verdict: '$v_clean' before, '$(_verdict "$out")' after"
  git -C "$SB_WORK" checkout -- requirements/DECISIONS.md README.md >/dev/null 2>&1

  # 4b. COMMITTED ON ANOTHER BRANCH: [t] says so and its Land line does not call the file uncommitted.
  local o3 q3 r3
  o3="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec3" ./scripts/ask.sh --role Dev "Which of E or F?" --default "E." 2>&1 )" \
    || _fixture_die "case_check_board_reports_what_only_this_checkout_holds: third ask.sh refused: $o3"
  q3="$(printf '%s\n' "$o3" | sed -n 's/^ask.sh: question written to //p')"; r3="dev/questions/${q3#*/dev/questions/}"
  publish_sandbox
  git -C "$SB_WORK" checkout -q -b feat-answer >/dev/null 2>&1
  printf '\n**Answer (2026-10-25, Ros):** F.\n' >> "$q3"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -m "[PM] answer on a branch" --quiet >/dev/null 2>&1
  out="$(cb_run)"
  printf '%s\n' "$out" | grep -F "$r3" | grep -F "committed on a branch other than $SB_TRUNK" >/dev/null \
    || cf "4b: [t] does not name $r3 as committed on a branch other than $SB_TRUNK: $(printf '%s' "$out" | grep -F "$r3")"
  printf '%s\n' "$out" | grep -F 'Land each question file listed above (uncommitted or on another branch)' >/dev/null \
    || cf "4b: the Land line does not cover a file committed on another branch: $(printf '%s' "$out" | grep -F 'Land each')"
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1

  # 5. ABLATION — strip each block; its line goes.
  local o2 q2
  o2="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec2" ./scripts/ask.sh --role Dev "Which of C or D?" --default "C." 2>&1 )" \
    || _fixture_die "case_check_board_reports_what_only_this_checkout_holds: second ask.sh refused: $o2"
  q2="$(printf '%s\n' "$o2" | sed -n 's/^ask.sh: question written to //p')"
  publish_sandbox
  printf '\n**Answer (2026-10-25, Ros):** D.\n' >> "$q2"
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_t_section)"
  printf '%s\n' "$sec" | grep -F 'answered but not on' >/dev/null || cf "(control) the second question's local answer is not listed before the ablation: $sec"
  local s="$SB_WORK/scripts/check-board.sh"
  grep -q '# BEGIN local-answer scan' "$s" && grep -q '# BEGIN \[f0\]' "$s" || cf "(control) no BEGIN seams for the local-answer scan and [f0] in check-board.sh — cannot ablate"
  sed -i.bak '/# BEGIN local-answer scan/,/# END local-answer scan/d' "$s"; rm -f "$s.bak"
  bash -n "$s" || cf "(control) the ablated check-board.sh no longer parses"
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_t_section)"
  printf '%s\n' "$sec" | grep -F 'answered but not on' >/dev/null && cf "(control) the ablation left the local-answer finding"
  sed -i.bak '/# BEGIN \[f0\]/,/# END \[f0\]/d' "$s"; rm -f "$s.bak"
  bash -n "$s" || cf "(control) the ablated check-board.sh no longer parses"
  out="$(cb_run)"
  printf '%s\n' "$out" | grep -F '[f0]' >/dev/null && cf "(control) the ablation left [f0] printing"

  finish "check-board: [f0] reports the main checkout's changes no arm reads (⚠ only for a path the arms would read), [t] lists an answer only this checkout holds as uncommitted or committed-unpushed, a pushed answer is not listed, neither line moves the verdict, and stripping each block removes its line"
  teardown
}

# =============================================================================
# CASE — check-board's [t] counts a register citation of an answered question file only when the
# commit that introduced it descends from (or is) the commit that added the `**Answer` block.
#
# The fixture follows the real order: three questions are filed and committed; a ruling that names
# the second is committed BEFORE any answer; the first two are answered and committed; a ruling
# citing the first lands AFTER; the third is answered in the SAME commit as the ruling that cites it.
# Rows: (i) cited after the answer -> not listed; (ii) cited only before it -> listed;
# (iii) cited in the answer's own commit -> not listed; (iv) no history readable -> any citation
# counts and the arm prints a note; ablation: with the ordering test disabled, (ii) goes unlisted.
# =============================================================================
case_check_board_answered_question_cited_before_the_answer() {
  cf_reset
  make_sandbox
  _ask_fill_pm "$SB_WORK"
  mkdir -p "$SB_WORK/requirements"
  printf '# DECISIONS.md\n\n## A. test bucket\n\n### D-01 — an unrelated ruling\n\n**Ruling.** Keep it small.\n**Why.** Because.\n**Provenance.** 2026-01-01, no work item.\n\n---\n' > "$SB_WORK/requirements/DECISIONS.md"
  publish_sandbox
  _qpath() { local q="$1"; printf 'dev/questions/%s' "${q#*/dev/questions/}"; }
  _ruling() {  # <D-id> <path>
    printf '\n### %s — a ruling\n\n**Ruling.** As asked.\n**Why.** Because.\n**Provenance.** 2026-10-17, asked in %s; no work item.\n\n---\n' "$1" "$2" >> "$SB_WORK/requirements/DECISIONS.md"
  }
  local o1 o2 o3 q1 q2 q3 r1 r2 r3 out sec
  o1="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec1" ./scripts/ask.sh --role PM "Question one?" --default "A." 2>&1 )" || _fixture_die "ask.sh refused: $o1"
  o2="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec2" ./scripts/ask.sh --role PM "Question two?" --default "B." 2>&1 )" || _fixture_die "ask.sh refused: $o2"
  o3="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec3" ./scripts/ask.sh --role PM "Question three?" --default "C." 2>&1 )" || _fixture_die "ask.sh refused: $o3"
  q1="$(printf '%s\n' "$o1" | sed -n 's/^ask.sh: question written to //p')"; r1="$(_qpath "$q1")"
  q2="$(printf '%s\n' "$o2" | sed -n 's/^ask.sh: question written to //p')"; r2="$(_qpath "$q2")"
  q3="$(printf '%s\n' "$o3" | sed -n 's/^ask.sh: question written to //p')"; r3="$(_qpath "$q3")"
  [ -f "$q1" ] && [ -f "$q2" ] && [ -f "$q3" ] || _fixture_die "case_check_board_answered_question_cited_before_the_answer: ask.sh wrote no question file(s)"
  publish_sandbox
  _ruling D-02 "$r2"; publish_sandbox                                  # cites question two BEFORE any answer
  printf '\n**Answer (2026-10-17, Ros):** One.\n' >> "$q1"
  printf '\n**Answer (2026-10-17, Ros):** Two.\n' >> "$q2"
  publish_sandbox
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_t_section)"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$r1" >/dev/null || cf "pre: $r1 (answered, not yet cited) is not listed: $sec"
  _ruling D-03 "$r1"; publish_sandbox                                  # cites question one AFTER its answer
  printf '\n**Answer (2026-10-17, Ros):** Three.\n' >> "$q3"; _ruling D-04 "$r3"; publish_sandbox   # same commit
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_t_section)"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$r1" >/dev/null && cf "i: $r1 is listed although a ruling cites it after the answer: $sec"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$r2" >/dev/null || cf "ii: $r2 is not listed although it was cited only before the answer: $sec"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$r3" >/dev/null && cf "iii: $r3 is listed although a ruling cites it in the answer's own commit: $sec"
  printf '%s\n' "$sec" | grep -i 'no commit history' >/dev/null && cf "history is readable here, yet the arm printed the no-history note: $sec"

  # (iv) the same files in a tree with no commit: today's behaviour (any citation counts), and the note.
  local nh="$SB_TMP/nohist"
  rm -rf "$nh"; mkdir -p "$nh"
  ( cd "$SB_WORK" && tar -cf - --exclude=.git . ) | ( cd "$nh" && tar -xf - ) || _fixture_die "could not copy the sandbox tree"
  git -C "$nh" init -q >/dev/null 2>&1 || _fixture_die "git init failed in the copy"
  out="$( cd "$nh" && env -u CLAUDE_PROJECT_DIR ./scripts/check-board.sh --full 2>&1 )"; sec="$(printf '%s\n' "$out" | _cb_t_section)"
  printf '%s\n' "$sec" | grep -i 'no commit history' >/dev/null || cf "iv: the arm did not say it could read no history: $sec"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$r2" >/dev/null && cf "iv: $r2 is listed without history, where any citation counts: $sec"

  # ABLATION — disable the ordering test; (ii) must stop being listed.
  local s="$SB_WORK/scripts/check-board.sh"
  grep -q 'merge-base --is-ancestor "$t_ans" "$t_c"' "$s" || cf "(control) no ordering test in check-board.sh — cannot ablate"
  sed -i.bak 's/git -C "\$REPO_ROOT" merge-base --is-ancestor "\$t_ans" "\$t_c" 2>\/dev\/null/true/' "$s"; rm -f "$s.bak"
  bash -n "$s" || cf "(control) the ablated check-board.sh no longer parses"
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_t_section)"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$r2" >/dev/null && cf "(control) the ablation left (ii) listed — the row does not depend on the ordering test: $sec"

  finish "arm (t): a register citation counts only from a commit that is, or descends from, the answer's commit: cited after -> not listed, cited only before -> listed, same commit -> not listed, no history -> any citation counts with a note, and disabling the ordering test unlists the before-only row"
  teardown
}

# =============================================================================
# CASE — check-board's [t] counts a WORKING DEFAULT DISCHARGED IN PLACE as a citation made after the
# answer, and does not count a post-answer commit that only REMOVES a line naming the path.
#
# The fixture follows the real order: two WITHDRAWN register entries; two questions asked with
# `ask.sh --decision` (each Ruling now carries its question file's path) and committed; a note naming
# the second question file lands in an unrelated entry (before any answer); both questions are
# answered and committed; the first entry is discharged IN PLACE (the path moves from Ruling to
# Provenance, so the file holds it the same number of times); the second entry's Ruling is replaced
# by words without the path (a commit that only removes a line naming it, while the earlier note
# keeps the path in the file).
# Rows: (i) before the discharge both are listed; (ii) after it the first is not listed;
# (iii) the second is still listed; (iv) a third question whose path carries a `+` (an extended-regex
# metacharacter), discharged in place the same way, is not listed either;
# ablation: counting a removed line as a citation unlists (iii).
# =============================================================================
case_check_board_answered_question_discharged_in_place() {
  cf_reset
  make_sandbox
  _ask_fill_pm "$SB_WORK"
  mkdir -p "$SB_WORK/requirements"
  cat > "$SB_WORK/requirements/DECISIONS.md" <<'REG'
# DECISIONS.md

## A. test bucket

### D-01 — an unrelated ruling

**Ruling.** Keep it small.
**Why.** Because.
**Provenance.** 2026-01-01, no work item.

### D-02 — the retention period

**Ruling.** WITHDRAWN 2026-09-20 — the prior period was revoked pending a new one.
**Why.** The shop manager asked for a review.
**Provenance.** withdrawn 2026-09-20, project log.

### D-03 — the weekday

**Ruling.** WITHDRAWN 2026-09-20 — the prior weekday was revoked pending a new one.
**Why.** The rota changed.
**Provenance.** withdrawn 2026-09-20, project log.

---
REG
  publish_sandbox
  _qpath() { local q="$1"; printf 'dev/questions/%s' "${q#*/dev/questions/}"; }
  local o1 o2 q1 q2 q3 r1 r2 r3 out sec dec="$SB_WORK/requirements/DECISIONS.md"
  o1="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec1" ./scripts/ask.sh --role PM "How long to keep details?" --default "Hold." --decision D-02 2>&1 )" \
    || _fixture_die "ask.sh --decision refused in the sandbox: $o1"
  o2="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec2" ./scripts/ask.sh --role PM "Which weekday?" --default "Monday." --decision D-03 2>&1 )" \
    || _fixture_die "second ask.sh --decision refused in the sandbox: $o2"
  q1="$(printf '%s\n' "$o1" | sed -n 's/^ask.sh: question written to //p')"; r1="$(_qpath "$q1")"
  q2="$(printf '%s\n' "$o2" | sed -n 's/^ask.sh: question written to //p')"; r2="$(_qpath "$q2")"
  [ -f "$q1" ] && [ -f "$q2" ] || _fixture_die "case_check_board_answered_question_discharged_in_place: ask.sh wrote no question file(s): '$q1' '$q2'"
  grep -qF "WORKING DEFAULT (provisional, asked" "$dec" && grep -qF "$r1" "$dec" && grep -qF "$r2" "$dec" \
    || _fixture_die "case_check_board_answered_question_discharged_in_place: ask.sh did not put both question paths in the Ruling lines"
  # A third question whose path carries a regex metacharacter that only an EXTENDED regex reads (+): the
  # file, then the provisional entry naming it, in the order ask.sh --decision writes them.
  r3="dev/questions/2026-10-17T000000Z-PM+x-ask.md"; q3="$SB_WORK/$r3"
  printf '# Question\n\n**Parks card:** KIT-001\n' > "$q3"
  awk -v p="$r3" '/^---$/ { print "### D-04 — the plus path\n\n**Ruling.** WORKING DEFAULT (provisional, asked 2026-10-17, " p "): Hold.\n**Why.** Because.\n**Provenance.** 2026-10-17, no work item.\n" } { print }' "$dec" > "$dec.new" && mv "$dec.new" "$dec"
  grep -qF "$r3" "$dec" || _fixture_die "case_check_board_answered_question_discharged_in_place: the plus-path entry did not land"
  publish_sandbox                                                      # the asks, committed
  sed 's|^\*\*Why\.\*\* Because\.$|**Why.** Because; see '"$r2"'.|' "$dec" > "$dec.new" && mv "$dec.new" "$dec"
  grep -qF "see $r2" "$dec" || _fixture_die "case_check_board_answered_question_discharged_in_place: the earlier note did not land"
  publish_sandbox                                                      # names question two BEFORE any answer
  printf '\n**Answer (2026-10-17, Ros):** Eighteen months.\n' >> "$q1"
  printf '\n**Answer (2026-10-17, Ros):** Fridays.\n' >> "$q2"
  printf '\n**Answer (2026-10-17, Ros):** Two weeks.\n' >> "$q3"
  publish_sandbox
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_t_section)"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$r1" >/dev/null || cf "i: $r1 (answered, not yet discharged) is not listed: $sec"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$r3" >/dev/null || cf "i: $r3 (answered, not yet discharged) is not listed: $sec"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$r2" >/dev/null || cf "i: $r2 (answered, not yet discharged) is not listed: $sec"

  # DISCHARGE D-02 IN PLACE: the Ruling takes the answer, the Provenance takes the question file's path.
  awk -v p="$r1" '
    /^### / { e = ($0 ~ /^### D-02 /) }
    e && /^\*\*Ruling\.\*\*/ { print "**Ruling.** Eighteen months after the last confirmation."; next }
    e && /^\*\*Provenance\.\*\*/ { print "**Provenance.** 2026-10-17, the principal'"'"'s answer in " p "; no work item."; next }
    { print }' "$dec" > "$dec.new" && mv "$dec.new" "$dec"
  grep -qF "answer in $r1" "$dec" || _fixture_die "case_check_board_answered_question_discharged_in_place: the in-place discharge did not take"
  # D-04, the same discharge for the path with a +.
  awk -v p="$r3" '
    /^### / { e = ($0 ~ /^### D-04 /) }
    e && /^\*\*Ruling\.\*\*/ { print "**Ruling.** Two weeks."; next }
    e && /^\*\*Provenance\.\*\*/ { print "**Provenance.** 2026-10-17, the principal'"'"'s answer in " p "; no work item."; next }
    { print }' "$dec" > "$dec.new" && mv "$dec.new" "$dec"
  grep -qF "answer in $r3" "$dec" || _fixture_die "case_check_board_answered_question_discharged_in_place: the plus-path discharge did not take"
  # D-03: the Ruling loses the path and nothing names it anew.
  awk '
    /^### / { e = ($0 ~ /^### D-03 /) }
    e && /^\*\*Ruling\.\*\*/ { print "**Ruling.** Fridays."; next }
    { print }' "$dec" > "$dec.new" && mv "$dec.new" "$dec"
  grep -qF "$r2" "$dec" || _fixture_die "case_check_board_answered_question_discharged_in_place: the earlier note no longer names $r2, so the removal row proves nothing"
  publish_sandbox
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_t_section)"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$r1" >/dev/null && cf "ii: $r1 is listed although its entry was discharged in place after the answer, citing the path: $sec"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$r2" >/dev/null || cf "iii: $r2 is not listed although the only commit after the answer REMOVED a line naming it: $sec"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$r3" >/dev/null && cf "iv: $r3 (a + in the path) is listed although its entry was discharged in place after the answer, citing the path: $sec"

  # ABLATION — count a removed line as a citation; (iii) must stop being listed.
  local s="$SB_WORK/scripts/check-board.sh"
  grep -qF '/^\+/ && index($0, ' "$s" || cf "(control) no added-line test in check-board.sh — cannot ablate"
  sed -i.bak 's|/^\\+/ && index(\$0, |/^[-+]/ \&\& index($0, |' "$s"; rm -f "$s.bak"
  bash -n "$s" || cf "(control) the ablated check-board.sh no longer parses"
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_t_section)"
  printf '%s\n' "$sec" | grep '⚠' | grep -F "$r2" >/dev/null && cf "(control) the ablation left (iii) listed — the row does not depend on the added-line test: $sec"

  finish "arm (t): a WITHDRAWN entry discharged in place after the answer (the path moves from Ruling to Provenance) is a citation and is not listed, a commit after the answer that only removes a line naming the path is not, a path carrying a + is matched like any other, and counting removed lines as citations unlists the second"
  teardown
}

# =============================================================================
# CASE — A SECOND `set-models.sh --class <c>` WITH A DIFFERENT PAIR MOVES THE LADDER ROW TOO.
#
# The first call fills the row's blanks; the second meets FILLED cells. Both calls run in the real
# order (seam, commit, report). After the second, the pin, the ladder row (its trailing prose kept),
# the seam's record and arm [s] must all show the second value, for a row whose label carries no
# backtick (Dev) and one whose label does (Spike / probe). Control: a third call with the same pair
# changes nothing.
# =============================================================================
case_set_models_second_call_moves_the_ladder_row() {
  cf_reset
  make_sandbox
  local ad orch out sec cls row
  read -r ad orch <<<"$(_seed_provisioning_sandbox)"
  if [ -z "$ad" ]; then skp "a second set-models.sh --class moves the ladder row" "no .claude/agents + roles/orchestrator.md in the real tree"; teardown; return; fi
  local rec="$SB_WORK/.claude/model-pins.record"
  [ -x "$SB_WORK/scripts/set-models.sh" ] || { cf "scripts/set-models.sh is absent or not executable"; finish "a second set-models.sh --class moves the ladder row"; teardown; return; }
  for cls in dev spike; do
    ( cd "$SB_WORK" && ./scripts/set-models.sh --class "$cls" --model m-one --effort e-one >/dev/null 2>&1 ) \
      || _fixture_die "first set-models.sh --class $cls refused in the sandbox"
  done
  publish_sandbox
  for cls in dev spike; do
    ( cd "$SB_WORK" && ./scripts/set-models.sh --class "$cls" --model m-two --effort e-two >/dev/null 2>&1 ) \
      || cf "the second set-models.sh --class $cls refused"
  done
  publish_sandbox
  grep -qx 'model: m-two' "$ad/dev-worker.md" && grep -qx 'effort: e-two' "$ad/dev-worker.md" \
    || cf "dev-worker.md is not at m-two/e-two after the second call: $(grep -E '^model:|^effort:' "$ad/dev-worker.md" | tr '\n' ' ')"
  row="$(grep -F '| **Dev** |' "$orch")"
  case "$row" in
    '| **Dev** | `m-two` | `e-two` default; higher for'*) : ;;
    *) cf "the Dev ladder row is not at m-two/e-two with its prose kept after the second call: $row" ;;
  esac
  row="$(grep -F '| **Spike / probe**' "$orch")"
  case "$row" in
    '| **Spike / probe** (`spike-worker`) | `m-two` | `e-two` |'*) : ;;
    *) cf "the Spike / probe ladder row is not at m-two/e-two (its label carries backticks) after the second call: $row" ;;
  esac
  grep -v '^#' "$rec" | grep -F "dev-worker.md$(printf '\t')m-two$(printf '\t')e-two" >/dev/null \
    || cf "model-pins.record does not name dev-worker.md at m-two/e-two: $(grep -v '^#' "$rec" | tr '\n' '|')"
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _cb_s_section)"
  [ -n "$sec" ] || cf "no [s] section in the report: $out"
  printf '%s\n' "$sec" | grep -E '^      ⚠ .* pin says' >/dev/null \
    && cf "arm [s] reports a disagreement after the second call: $sec"
  # Control: the same pair again is a no-op.
  local before after
  before="$(cat "$orch" "$ad/dev-worker.md" "$rec")"
  ( cd "$SB_WORK" && ./scripts/set-models.sh --class dev --model m-two --effort e-two >/dev/null 2>&1 ) || cf "the repeated set-models.sh --class dev refused"
  after="$(cat "$orch" "$ad/dev-worker.md" "$rec")"
  [ "$before" = "$after" ] || cf "(control) repeating the same pair changed the ladder, the pin or the record"

  finish "a second set-models.sh --class with a different pair moves the pin, the ladder row (prose kept; a backticked label too) and the record together, arm [s] is clean, and repeating the pair is a no-op"
  teardown
}

# =============================================================================
# CASE — arm [n] accepts a DISPATCHED LEG'S OWN `kit-finding:` line, not only `kit-feedback:`.
#
# MANUAL § Kit feedback, M1: "A dispatched leg writes no entry. It puts one `kit-finding: …` line
# in its progress.md entry, and the orchestrator writes the entry (M4)." A leg's own newest Log
# entry therefore correctly carries `kit-finding:` and never `kit-feedback:` — that is the
# documented shape, not an omission. Two directions, both against the SAME newest entry so one
# assertion cannot mask the other:
#   (1) a leg's entry carrying ONLY `kit-finding:`        → accepted, no ⚠
#   (2) an entry carrying NEITHER line                    → still ⚠ (the control this fix must
#       not weaken: [n] is reported-missing, never silently accepting everything)
# =============================================================================
case_check_board_arm_n_accepts_kit_finding() {
  cf_reset
  local e_finding e_neither out sec

  e_finding='### 2026-01-03\n\n- [Dev] a dispatched leg'"'"'s own entry.\n- kit-finding: some kit file:line, or "silent"\n'
  e_neither='### 2026-01-03\n\n- [Dev] a dispatched leg'"'"'s own entry, no line at all.\n'

  # (1)
  _kf_board '' "$(printf "$e_finding")"
  printf '%s\n' "$_kf_sec" | grep -F 'newest entry (2026-01-03): kit-finding:' >/dev/null \
    || cf "(1) a leg's kit-finding:-only entry was not reported as its newest-entry line: ${_kf_one:-no section}"
  printf '%s\n' "$_kf_sec" | grep '⚠' >/dev/null \
    && cf "(1) a leg's kit-finding:-only entry was flagged as missing a kit-feedback: line: $_kf_one"
  teardown

  # (2) — the control: neither line present still warns, so (1) is not just "always accept"
  _kf_board '' "$(printf "$e_neither")"
  printf '%s\n' "$_kf_sec" | grep '⚠' | grep -F 'kit-finding' >/dev/null \
    || cf "(2) an entry with NEITHER line was not reported (or the message dropped the kit-finding: alternative it now documents): ${_kf_one:-no section}"
  teardown

  finish "check-board arm [n]: a dispatched leg's own kit-finding:-only entry is accepted as its newest-entry line, never reported as a missing kit-feedback: line (1), while an entry with neither line still warns (2, the control)"
}

# =============================================================================
# CASE — the PRD-COVERAGE arm COUNTS, and never changes the verdict.
#
# Of the landed issues, how many carry `prd: n/a`, and how many of those give no
# `prd_reason:`. A card without a PRD is legal, so the arm never sets drift; a stray RATE is a
# finding, and a rate nobody prints is a rate nobody sees. The cards are MINTED through the
# shipped new-issue.sh, so the frontmatter is the template's own (including the unfilled
# `prd_reason:` line and its comment), then moved to a landed column and published.
# THE VERDICT CONTROL deletes the arm's marked block from a COPY of check-board.sh and requires
# the same verdict line and exit status from the same board. The arm is found by its label, not
# its letter, so re-lettering does not break this case.
# =============================================================================
case_prd_coverage_counts_only() {
  cf_reset
  if ! has_issue_template; then skp "check-board PRD coverage counts, never decides" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  local out line rc id cb="$SB_WORK/scripts/check-board.sh" abl v1 v2 rc1 rc2
  for id in 961:prd-probe:PRD-001 962:na-with-reason:n/a 963:na-no-reason:n/a; do
    ( cd "$SB_WORK" && ./scripts/new-issue.sh "$(printf '%s' "$id" | cut -d: -f2)" --id "$SB_PREFIX-${id%%:*}" --prd "${id##*:}" >/dev/null 2>&1 ) \
      || _fixture_die "case_prd_coverage_counts_only: new-issue.sh could not mint $SB_PREFIX-${id%%:*}"
  done
  sed -i.bak 's/^prd_reason:.*/prd_reason: a one-off chore no PRD covers/' "$SB_WORK/progress/todo/$SB_PREFIX-962-na-with-reason.md"
  rm -f "$SB_WORK/progress/todo/$SB_PREFIX-962-na-with-reason.md.bak"
  grep -q '^prd_reason: a one-off' "$SB_WORK/progress/todo/$SB_PREFIX-962-na-with-reason.md" \
    || _fixture_die "case_prd_coverage_counts_only: could not fill prd_reason on the minted card"
  # new-issue.sh writes the card into the checkout only (it is committed by whoever publishes),
  # so a plain mv, then one publish.
  mkdir -p "$SB_WORK/progress/qa_complete"
  mv "$SB_WORK/progress/todo/$SB_PREFIX-961-prd-probe.md" "$SB_WORK/progress/todo/$SB_PREFIX-962-na-with-reason.md" \
    "$SB_WORK/progress/todo/$SB_PREFIX-963-na-no-reason.md" "$SB_WORK/progress/qa_complete/" \
    || _fixture_die "case_prd_coverage_counts_only: could not move the minted cards to qa_complete/"
  # ...and each card's last Activity entry DECLARES the column it now sits in, or arm (a)
  # reports the move as drift and the verdict control below compares a dirty board with a
  # dirty board — equal, and blind to an arm that decided. The base board must be CLEAN.
  local c
  for c in "$SB_WORK/progress/qa_complete/$SB_PREFIX"-96[123]-*.md; do
    printf -- '- 2026-01-01 [%s] → qa_complete: landed (fixture)\n' "$SB_ROLE" >> "$c"
  done
  publish_sandbox
  origin_has_path "progress/qa_complete/$SB_PREFIX-963-na-no-reason.md" \
    || _fixture_die "case_prd_coverage_counts_only: the landed cards are not on the trunk — check-board reads the trunk"

  rc1=0; out="$(cb_run)" || rc1=$?
  line="$(printf '%s\n' "$out" | grep -E '^\[[a-z]\] PRD coverage' | head -1)"
  [ -n "$line" ] || cf "no PRD coverage line in the report — the arm is absent"
  printf '%s\n' "$line" | grep -F '2 of 3 landed issue(s) carry prd: n/a; 1 of those give no prd_reason' >/dev/null \
    || cf "the count is wrong (expected 2 of 3 n/a, 1 with no reason): ${line:-none}"
  printf '%s\n' "$line" | grep -F 'reports only' >/dev/null \
    || cf "the arm's header lacks the literal 'reports only' — kit-init's self-check would read its line as a finding: $line"
  v1="$(printf '%s\n' "$out" | grep '^── board-drift:')"

  # VERDICT CONTROL: the same board, the arm's block deleted from a copy.
  abl="$SB_TMP/check-board-without-prd-arm.sh"
  awk '/^# BEGIN prd-coverage arm/{skip=1} !skip{print} /^# END prd-coverage arm/{skip=0}' "$cb" > "$abl"
  grep -q 'PRD coverage' "$abl" && _control_did_not_run "delete the arm's marked block from a copy of check-board.sh"
  cp "$abl" "$SB_WORK/scripts/check-board-ablated.sh"; chmod +x "$SB_WORK/scripts/check-board-ablated.sh"
  rc2=0; out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR ./scripts/check-board-ablated.sh 2>&1 )" || rc2=$?
  rm -f "$SB_WORK/scripts/check-board-ablated.sh"
  v2="$(printf '%s\n' "$out" | grep '^── board-drift:')"
  # THE PREMISE IS ON THE BOARD WITHOUT THE ARM: it must be clean, or a dirty-equals-dirty
  # comparison is blind to an arm that decided.
  [ "$v2" = "── board-drift: clean ✓" ] \
    || _control_did_not_run "build a board whose verdict is clean without the arm (it was: ${v2:-none})"
  [ -n "$v1" ] && [ "$v1" = "$v2" ] && [ "$rc1" -eq "$rc2" ] \
    || cf "the verdict moved with the arm present: with '$v1' (rc $rc1), without '$v2' (rc $rc2)"

  finish "check-board's PRD coverage arm counts landed cards with prd: n/a (2 of 3) and those with no prd_reason (1), carries 'reports only', and leaves the verdict and exit status exactly as they are without it"
  teardown
}

# =============================================================================
# CASE — A DETACHED CHECKOUT IS NAMED AS ONE, WITH ITS SHA — never as a branch
#        called DETACHED.
#
# [f1] must not print "(checked out here: DETACHED)", which reads like a branch of that name. A
# detached checkout is common: the landing script leaves a gate checkout detached.
# =============================================================================
case_check_board_names_a_detached_head() {
  cf_reset
  make_sandbox
  publish_sandbox
  local sha out f1
  sha="$(git -C "$SB_WORK" rev-parse --short HEAD)"
  git -C "$SB_WORK" checkout -q --detach HEAD >/dev/null 2>&1
  git -C "$SB_WORK" symbolic-ref -q HEAD >/dev/null 2>&1 \
    && _control_did_not_run "detach the main checkout"
  out="$(cb_run)"
  f1="$(printf '%s\n' "$out" | grep '\[f1\] main checkout:' | head -1)"
  [ -n "$f1" ] || cf "no [f1] line — the arm did not report, so nothing below was measured: $out"
  printf '%s\n' "$f1" | grep -F "checked out here: a detached HEAD at $sha" >/dev/null \
    || cf "the [f1] line does not name the detached HEAD and its sha ($sha): $f1"
  printf '%s\n' "$f1" | grep -F 'DETACHED' >/dev/null \
    && cf "the [f1] line still prints DETACHED as if it were a branch name: $f1"
  # CONTROL: on a branch, the name is still printed, quoted.
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1
  out="$(cb_run)"
  printf '%s\n' "$out" | grep '\[f1\] main checkout:' | grep -E "checked out here: '?$SB_TRUNK'?\)" >/dev/null \
    || cf "(control) on '$SB_TRUNK' by name the [f1] line does not name the branch: $(printf '%s\n' "$out" | grep '\[f1\]')"
  finish "check-board [f1]: a detached main checkout is reported as 'a detached HEAD at <sha>', never as a branch named DETACHED; a branch is still named"
  teardown
}

# =============================================================================
# CASE — arm (g2) COUNTS BLANKS, NOT USAGE; AND A PROJECT.md THAT LOST ITS
#        DECLARATION IS STILL READ.
#
# A filled PROJECT.md documents its commands, and their usage lines carry metavariables
# (`tool <input.csv> --out <dir>`); those are not blanks. And a rewrite can drop the sheet's
# `KIT-DISPOSITION: FILL` line, so an undeclared sheet is still read, never skipped.
#
# Do not strip code spans wholesale: the shipped sheet writes most real blanks INSIDE spans
# (`<test command>`, `<trunk>`). The discriminator is SHAPE: a span that is exactly one
# <angle-bracket> is a blank; a bracket among other text is usage. A fenced block is code.
#
# THE ROWS, each on its own published PROJECT.md, REPLACE files graduated so FILL alone can hold
# completion back:
#   (1) DECLARED, filled, usage inline, in a double-backtick span and in a fenced block — 0
#       blanks, and graduation COMPLETE (the day-one work landed);
#   (2) DECLARED, the same usage PLUS one bare blank and one whole-span blank — exactly 2;
#   (3) UNDECLARED with one real blank among the usage — REPORTED, naming the missing
#       declaration, never "skipped";
#   (4) UNDECLARED and filled — read as graduated (graduation strips the marker from a filled
#       PROJECT.md, so a missing declaration alone is not a defect);
#   (5) THE CONTROL: a PROJECT.md declaring ANOTHER disposition is still not measured;
#   (6) a ``` line INSIDE a ~~~ block does not close it, and the blank after the block counts;
#   (7) a fence left OPEN to the end of the file hides nothing: the blank after it counts.
# =============================================================================
_cb_fill_usage='Run it: `./bin/tool <input.csv> --out <dir>`, and ``see `<x>` here``.

```sh
./bin/tool <arg-one> <arg-two>
```
'
_cb_fill_sheet() {  # <marker line or empty> <body…> — writes, publishes, runs; sets _cb_fill_out
  # principal: is filled unconditionally here — this helper's callers are testing the FILL arm's
  # blank-counting over $2's body, not principal:, so it stays a clean, non-varying member and
  # never the reason graduation COMPLETE does or does not fire in a given scenario.
  { [ -n "$1" ] && printf '%s\n' "$1"
    printf '# PROJECT.md\n\n%s\n\n## Who answers when nobody is watching\n\n- **`principal:`** `Fixture Owner`\n- **Their channel:** `dev/questions/`\n' "$2"
  } > "$SB_WORK/PROJECT.md"
  publish_sandbox
  _cb_fill_out="$(cb_run | _cb_g_section)"
}
case_check_board_fill_arm_reads_blanks_not_usage() {
  cf_reset
  make_sandbox
  printf '# my project\n' > "$SB_WORK/AGENTS.md"
  printf '# my project\n' > "$SB_WORK/README.md"
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  # This case is about PROJECT.md's own FILL reading; CODE_GLOBS/TEST_GLOBS/DELETE-IF-UNUSED/
  # .gitignore/.env.example do not vary across its scenarios, so each is discharged once so
  # graduation COMPLETE (assertions (1) and (4) below) turns on PROJECT.md's blanks alone, not on
  # an unrelated member.
  _cb_g_declare_empty_seams
  _cb_g_discharge_delete_if_unused
  _cb_g_discharge_gitignore_env
  _cb_g_land_day_one_work
  local decl="<!-- $KIT_FILL_DISPOSITION — synthetic fill sheet. -->"

  # (1) declared, filled, usage only
  _cb_fill_sheet "$decl" "$_cb_fill_usage"
  printf '%s\n' "$_cb_fill_out" | grep 'FILL: PROJECT.md holds 0 <angle-bracket> blanks' >/dev/null \
    || cf "(1) usage metavariables in code were counted as blanks: $(printf '%s' "$_cb_fill_out" | grep 'FILL:')"
  printf '%s\n' "$_cb_fill_out" | grep 'graduation COMPLETE' >/dev/null \
    || cf "(1) a filled sheet that documents its own commands did not reach graduation COMPLETE"

  # (2) declared, usage + one bare blank + one whole-span blank
  _cb_fill_sheet "$decl" "Owner: <owner>. Tests: \`<test command>\`.
$_cb_fill_usage"
  printf '%s\n' "$_cb_fill_out" | grep 'FILL: PROJECT.md still holds 2 <angle-bracket> blank' >/dev/null \
    || cf "(2) expected exactly 2 blanks (one bare, one whole-span — the shipped shape), beside usage that must not count: $(printf '%s' "$_cb_fill_out" | grep 'FILL:')"

  # (3) undeclared, one real blank among the usage -> a finding, never a skip
  _cb_fill_sheet "" "Owner: <owner>.
$_cb_fill_usage"
  printf '%s\n' "$_cb_fill_out" | grep 'FILL: PROJECT.md' | grep 'no KIT-DISPOSITION' | grep '1 <angle-bracket> blank' >/dev/null \
    || cf "(3) a PROJECT.md that lost its declaration and still holds a blank was not reported as one: $(printf '%s' "$_cb_fill_out" | grep 'FILL:')"
  printf '%s\n' "$_cb_fill_out" | grep 'graduation COMPLETE' >/dev/null \
    && cf "(3) graduation COMPLETE over a PROJECT.md still holding a blank"

  # (4) undeclared and filled -> graduated
  _cb_fill_sheet "" "$_cb_fill_usage"
  printf '%s\n' "$_cb_fill_out" | grep 'FILL: PROJECT.md' | grep 'no KIT-DISPOSITION' | grep 'holds 0 <angle-bracket> blanks' >/dev/null \
    || cf "(4) an undeclared, filled PROJECT.md was not read as graduated: $(printf '%s' "$_cb_fill_out" | grep 'FILL:')"
  printf '%s\n' "$_cb_fill_out" | grep 'graduation COMPLETE' >/dev/null \
    || cf "(4) a graduated PROJECT.md (marker stripped, as the graduation rule says) held completion back"

  # (5) CONTROL: another disposition is not measured
  _cb_fill_sheet "<!-- KIT-DISPOSITION: KEEP — synthetic. -->" "Owner: <owner>."
  printf '%s\n' "$_cb_fill_out" | grep 'FILL: PROJECT.md' | grep 'skipped' >/dev/null \
    || cf "(5) a PROJECT.md declaring a disposition other than FILL was measured: $(printf '%s' "$_cb_fill_out" | grep 'FILL:')"

  # (6) a mismatched inner fence does not close the block
  _cb_fill_sheet "$decl" '~~~
```
~~~
Owner: <owner>.'
  printf '%s\n' "$_cb_fill_out" | grep 'FILL: PROJECT.md still holds 1 <angle-bracket> blank' >/dev/null \
    || cf "(6) a blank after a ~~~ block holding a \`\`\` line was not counted (the fence closed on the wrong character): $(printf '%s' "$_cb_fill_out" | grep 'FILL:')"

  # (7) an unclosed fence hides nothing
  _cb_fill_sheet "$decl" '```sh
make it
Owner: <owner>.'
  printf '%s\n' "$_cb_fill_out" | grep 'FILL: PROJECT.md still holds 1 <angle-bracket> blank' >/dev/null \
    || cf "(7) a blank after a fence that never closes was hidden: $(printf '%s' "$_cb_fill_out" | grep 'FILL:')"

  # (8) two inline comments with a real blank between them: the blank counts (a greedy comment strip swallowed it)
  _cb_fill_sheet "$decl" '- <!-- a note --> `<fill me>` <!-- another -->'
  printf '%s\n' "$_cb_fill_out" | grep 'still holds 1 <angle-bracket> blank' >/dev/null \
    || cf "(8) a blank between two inline comments was swallowed: $(printf '%s' "$_cb_fill_out" | grep 'FILL:')"

  finish "check (g2): usage metavariables in code spans and fenced blocks are not blanks while a whole-span <blank> still is, a fence closes only on its own shape and an unclosed one hides nothing, and a PROJECT.md that lost its FILL declaration is read — a finding while a blank remains, graduated once none does — never skipped"
  teardown
}

# =============================================================================
# CASE — the verdict wiring, as a standalone control
#
# Duplicates state (c) of the graduation case as a NAMED control, which survives a refactor of
# that case.
#
# The two consumers read different things; do not collapse them:
#   release.sh gate (d)        keys on the VERDICT LINE alone.
#   kit-init's self-check      keys on the verdict line and, when it is NOT clean, reports the
#                              remaining findings as context, after dropping every section
#                              whose header says it "reports only" (as arm [g] does).
# So asserting the verdict string is necessary and not sufficient. The sufficiency half cannot
# live here: this sandbox's stamp receipt is an already-lived signal, so kit-init would refuse
# first. It runs in scripts/test/cases/kit-init.sh, case_kit_init_survives_the_documented_first_commit.
# =============================================================================
case_check_board_graduation_verdict_is_not_wired() {
  cf_reset
  make_sandbox
  # --no-project ON PURPOSE: g1's REPLACE finding must fire and the FILL arm must have nothing
  # to read.
  seed_scaffolding_tree --no-project
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  publish_sandbox

  local out; out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep -i 'still scaffolding' >/dev/null \
    || cf "precondition: the arm must be REPORTING for this control to mean anything: $out"
  printf '%s\n' "$out" | grep 'board-drift: clean ✓' >/dev/null \
    || cf "day-one completeness moved the board verdict — release.sh gate (d) keys on this line, and a dirty verdict is also what sends kit-init's self-check looking for a cause: $out"

  finish "check (g) does not decide the verdict: a board with unreplaced scaffolding still reads 'board-drift: clean ✓'"
  teardown
}

# =============================================================================
# CASE — arm [g] REFUSES "graduation COMPLETE" over ZERO measured members/classes.
#
# A tree "lived" enough to enable the arm (a card on the board) but where every measurable class
# comes back UNMEASURED must not print "graduation COMPLETE": nothing was checked, and that is
# not a pass. REPLACE and DELETE-IF-UNUSED both read a zero population as a real measurement (a
# whole-tree scan that found nothing to discharge), so reaching g_measured == 0 here also needs
# their declaring files removed — ONLY PROJECT.md/config.sh-dependent classes can go fully
# unreadable; REPLACE/DELETE-IF-UNUSED's own scan always runs. With the day-one work landed, this
# case ablates the refusal to show it is the mechanism holding COMPLETE back, not an accident of
# wording.
# =============================================================================
case_check_board_graduation_refuses_complete_over_nothing_measured() {
  cf_reset
  make_sandbox
  # A lived signal (a card on the board) with NO PROJECT.md and NO .gitignore/.env.example in
  # this sandbox at all (make_sandbox does not seed them) — those classes are therefore
  # UNREADABLE, not merely clean. scripts/config.sh IS copied by make_sandbox (it ships under
  # scripts/), so CODE_GLOBS/TEST_GLOBS would otherwise be readable here — removed too. REPLACE
  # and DELETE-IF-UNUSED still read 0-and-measured over an empty population (no AGENTS.md/
  # README.md here, and no consumers/ or scripts/notify*.sh once removed) — g_measured ends up 2,
  # not 0, which is this case's real premise now: EVERY class the markers alone cannot answer is
  # unmeasured, while the two whole-tree scans still count.
  rm -f "$SB_WORK/scripts/config.sh"
  _cb_g_remove_delete_if_unused_members
  seed_issue todo "$SB_PREFIX-430" nothingtomeasure chore "Nothing here to measure"
  # The ablation below must restore COMPLETE on this tree, so the day-one work is landed: only the
  # unmeasured-class refusal is then what holds COMPLETE back.
  _cb_g_land_day_one_work
  publish_sandbox

  local out
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'enabled by:' >/dev/null \
    || cf "precondition: the arm must be ENABLED for this case to mean anything: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    && cf "the arm printed graduation COMPLETE over a tree where PROJECT.md and scripts/config.sh are both absent — this is the false green the card exists to close: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'REPLACE: 0 file' >/dev/null \
    || cf "(precondition) REPLACE did not read its own zero population as measured: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'DELETE-IF-UNUSED: 0 file' >/dev/null \
    || cf "(precondition) DELETE-IF-UNUSED did not read its own zero population as measured: $out"
  printf '%s\n' "$out" | _cb_g_section | grep -i 'could not be measured, so COMPLETE cannot be claimed' >/dev/null \
    || cf "the arm did not refuse the COMPLETE claim over the classes it could not read at all, in words a reader would notice: $out"
  printf '%s\n' "$out" | _cb_g_section | grep -F 'PROJECT.md (absent)' >/dev/null \
    || cf "the arm's refusal did not name PROJECT.md among what it could not measure: $out"

  # ── THE ABLATION: with the refusal's guard removed, COMPLETE returns on the SAME tree. ────────
  # Proves the new line is load-bearing, not merely present. `-n "$g_unmeasured"` is the guard;
  # forcing it false restores the pre-fix behaviour (COMPLETE over "something measured, nothing
  # that WAS measured came back dirty") without touching anything else.
  local abl
  abl="$SB_WORK/scripts/check-board-ablated.sh"
  sed 's/elif \[ -n "\$g_unmeasured" \]; then/elif false; then/' "$SB_WORK/scripts/check-board.sh" > "$abl"
  chmod +x "$abl"
  grep -q 'elif false; then' "$abl" \
    || _control_did_not_run "the ablation did not change check-board.sh's guard — the sed anchor no longer matches the source"
  local abl_out
  abl_out="$(cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR ./scripts/check-board-ablated.sh 2>&1)"
  rm -f "$abl"
  printf '%s\n' "$abl_out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    || _control_did_not_run "with the unmeasured-classes refusal ablated, COMPLETE did not return on the same tree — the case is not isolating the guard it claims to: $abl_out"

  finish "arm [g] prints its measured population and REFUSES 'graduation COMPLETE' when a class could not be measured at all (PROJECT.md and scripts/config.sh both absent), even though REPLACE and DELETE-IF-UNUSED's own whole-tree scans still came back measured-and-clean — ablating the guard restores the false COMPLETE on the same tree, proving the refusal is load-bearing"
  teardown
}

# =============================================================================
# CASE — arm [g]'s (g2b): the NON-MARKDOWN FILL members, read by their OWN blank shape.
#
# .gitignore's build-artifact section and .env.example's project-credentials block declare
# KIT-DISPOSITION: FILL but express their instruction as a `FILL ME.` sentinel line, not an
# <angle-bracket> span — the markdown span reader cannot see them, so an unfilled `.gitignore` or
# `.env.example` was invisible to graduation COMPLETE.
# =============================================================================
case_check_board_graduation_non_markdown_fill_members() {
  cf_reset
  make_sandbox
  printf '# my project\n' > "$SB_WORK/AGENTS.md"
  printf '# my project\n' > "$SB_WORK/README.md"
  printf '<!-- FILLED. -->\n# PROJECT.md\n\nTrunk: main\n\n## Who answers when nobody is watching\n\n- **`principal:`** `Fixture Owner`\n- **Their channel:** `dev/questions/`\n' > "$SB_WORK/PROJECT.md"
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  # This case is about the .gitignore/.env.example non-markdown FILL members; CODE_GLOBS/
  # TEST_GLOBS do not vary across its scenarios, so declare both deliberately empty once, so
  # assertion (2)'s graduation COMPLETE turns on the members under test, not an unrelated one.
  _cb_g_declare_empty_seams
  _cb_g_land_day_one_work

  # (1) BOTH members still carry their FILL ME. sentinel — unfilled, and REPORTED as such.
  printf '# .gitignore\n# ── <your build artifacts> ──\n# FILL ME. one line per generated tree.\n' \
    > "$SB_WORK/.gitignore"
  printf '# .env.example\n# ── <your project credentials> ──\n# FILL ME. one block per credential.\n' \
    > "$SB_WORK/.env.example"
  publish_sandbox
  local out
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep -F '.gitignore' | grep '⚠' >/dev/null \
    || cf "(1) an unfilled .gitignore build-artifact section (its FILL ME. sentinel still present) was not reported: $(printf '%s\n' "$out" | _cb_g_section)"
  printf '%s\n' "$out" | _cb_g_section | grep -F '.env.example' | grep '⚠' >/dev/null \
    || cf "(1) an unfilled .env.example credentials block (its FILL ME. sentinel still present) was not reported: $(printf '%s\n' "$out" | _cb_g_section)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    && cf "(1) graduation COMPLETE over a tree where both non-markdown FILL members are still unfilled: $out"

  # (2) BOTH members filled — sentinel removed, as an adopter who filled the section would do.
  printf '# .gitignore\n# ── build artifacts ──\n# produced by npm run build\ndist/\n' > "$SB_WORK/.gitignore"
  printf '# .env.example\n# ── project credentials ──\n# READ_TOKEN=   # read-only\n' > "$SB_WORK/.env.example"
  # DELETE-IF-UNUSED must also clear for graduation to read COMPLETE here — this case is about
  # the non-markdown FILL members, not this one, so it is discharged once and does not vary.
  _cb_g_discharge_delete_if_unused
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep -F '.gitignore' | grep '✓' >/dev/null \
    || cf "(2) a filled .gitignore (no FILL ME. sentinel remaining) was not read as done: $(printf '%s\n' "$out" | _cb_g_section)"
  printf '%s\n' "$out" | _cb_g_section | grep -F '.env.example' | grep '✓' >/dev/null \
    || cf "(2) a filled .env.example (no FILL ME. sentinel remaining) was not read as done: $(printf '%s\n' "$out" | _cb_g_section)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    || cf "(2) a tree with every class filled (PROJECT.md, .gitignore, .env.example) did not reach graduation COMPLETE: $out"

  # (3) ABSENT: neither file exists — UNMEASURED, never counted clean, and named in the population.
  rm -f "$SB_WORK/.gitignore" "$SB_WORK/.env.example"
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep -F '.gitignore' | grep -i 'not present' >/dev/null \
    || cf "(3) an absent .gitignore was not reported as unmeasured: $(printf '%s\n' "$out" | _cb_g_section)"
  printf '%s\n' "$out" | _cb_g_section | grep -i 'could not measure' | grep -F '.gitignore' >/dev/null \
    || cf "(3) the population line did not name .gitignore among what could not be measured: $(printf '%s\n' "$out" | _cb_g_section | grep 'measured:')"

  finish "arm [g] reads .gitignore's build-artifact section and .env.example's credentials block by their own 'FILL ME.' sentinel-line shape (not the <angle-bracket> one, which their comment/ignore-file syntax hides from): unfilled is reported, filled clears, and an absent member is named UNMEASURED rather than silently skipped"
  teardown
}

# =============================================================================
# CASE — check (d) reads a frontmatter that does NOT start on line 1.
#
# The templates open with an HTML comment, so a minted card carries it ABOVE its frontmatter. A
# parser demanding `---` on line 1 reports every such card as having no id, and the board reads
# RED on a healthy first day.
# =============================================================================
case_check_board_frontmatter_offset() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-150" commented chore "Comment above the frontmatter"
  # Prepend a template-style comment header ABOVE the frontmatter.
  local f="$SB_WORK/progress/todo/$SB_PREFIX-150-commented.md" tmp
  tmp="$(mktemp)"
  { printf '<!-- KIT-CLASS: KIT — a comment header, exactly as the templates carry one.\n     It spans several lines and ends here. -->\n'; cat "$f"; } > "$tmp"
  mv "$tmp" "$f"
  publish_sandbox

  # THE ID KEY IS DERIVED: the assertion below is NEGATIVE, so a re-typed or empty key would make
  # it match nothing and pass. The derivation is asserted non-empty.
  local id_key; id_key="$(cb_default ISSUE_ID_KEY)"
  [ -n "$id_key" ] \
    || cf "(control) could not derive ISSUE_ID_KEY from check-board.sh — the negative assertion below would then match nothing and report PASS while measuring nothing"

  local out rc
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep "no $id_key: line" >/dev/null \
    && cf "a card whose frontmatter sits below a comment header was reported as having no $id_key: $out"
  printf '%s\n' "$out" | grep 'board-drift: clean ✓' >/dev/null \
    || cf "a healthy card with a comment header did not read clean: $out"

  finish "check (d): a frontmatter below a comment header is parsed, not reported as missing (id key derived, not re-typed)"
  teardown
}

# =============================================================================
# CASE — PROJECT.md's CREDENTIAL BLANK STAYS VISIBLE TO THE FILL ARM.
#
# The FILL arm counts blanks with `grep -oE '<[a-z][^<>]*>'`: lowercase-initial, no nesting. A
# capitalised or nested credential blank is INVISIBLE to it, so the arm reports zero blanks on
# an unfilled tree, a false green on the question the adopter most needs to answer.
# =============================================================================
case_project_credential_blank_is_countable() {
  cf_reset
  make_sandbox
  # THE REAL SHIPPED TREE, not the sandbox: PROJECT.md is not among the files make_sandbox
  # copies, and a case that SKIPS is not a case that passed.
  local pm="$REAL_REPO_ROOT/PROJECT.md"
  if [ ! -f "$pm" ]; then skp "PROJECT.md's credential blank stays countable" "PROJECT.md absent"; teardown; return; fi

  # INSTRUMENT: the section must be found, or the count below is zero-over-nothing.
  grep -q 'Read vs write separation' "$pm" \
    || _fixture_die "case_project_credential_blank_is_countable: no 'Read vs write separation' line in PROJECT.md — the subject moved and a zero count would read as clean."

  local line n
  line="$(grep -m1 'Read vs write separation' "$pm")"
  n="$(printf '%s\n' "$line" | grep -oE '<[a-z][^<>]*>' | grep -vc '://' || true)"

  # ── ON A TREE THAT HAS LIVED, THIS CASE HAS NO SUBJECT: the adopter filled the blank (SEED
  #    step 3). Do not accept "0 or 1 blanks": that passes on the capitalised-blank defect. Skip
  #    only on zero blanks AND the initializer's stamp receipt together.
  local stamped=0
  [ -f "$REAL_SCRIPTS/config.sh" ] && grep -q "^$KIT_STAMP_MARK" "$REAL_SCRIPTS/config.sh" 2>/dev/null && stamped=1
  if [ "${n:-0}" -eq 0 ] && [ "$stamped" -eq 1 ]; then
    skp_lived "PROJECT.md's credential blank stays countable" \
      "PROJECT.md's 'Read vs write separation' line holds no blank and scripts/config.sh carries kit-init's stamp receipt — this tree finished day one and filled it, so the SHIPPED shape this case asserts is legitimately absent"
    teardown; return
  fi

  [ "${n:-0}" -eq 1 ] \
    || cf "the credential separation line holds ${n:-0} blank(s) the FILL arm can count, want exactly 1 — a capitalised or nested blank is INVISIBLE to that arm, so an adopter graduates without answering it: $line"

  finish "PROJECT.md's read/write separation blank is exactly one blank the graduation FILL arm can count — a widening that capitalises or nests it would make it invisible and graduate an unfilled tree"
  teardown
}

case_every_arm_file_seam_is_declared_in_the_contract() {
  cf_reset
  make_sandbox
  local cb="$SB_WORK/scripts/check-board.sh"
  local sheet="$REAL_REPO_ROOT/process/contracts/drift-report.md"
  [ -f "$sheet" ] \
    || { skp "every board arm's declared file seam is named by its contract" "process/contracts/drift-report.md is absent — this project does not carry the contract set"; teardown; return; }

  # ── THE OPERAND IS DERIVED, NOT TYPED: every NAME_FILE="${NAME:-path}" seam, never the arm
  #    letters, which move (§ 6 tells a reader to derive them from the file). A seam is a file an
  #    adopter can repoint, so a reimplementation that never heard of it silently reads nothing;
  #    its default path must be named in drift-report.md.
  local seams n=0 undeclared="" nm def
  seams="$(grep -oE '^[A-Z][A-Z0-9_]*_FILE="\$\{[A-Z][A-Z0-9_]*:-[^}"]+\}"' "$cb" || true)"

  # ── INSTRUMENT CHECK FIRST: a derivation that stopped matching reports every arm as declared.
  [ -n "$seams" ] \
    || _fixture_die "case_every_arm_file_seam_is_declared_in_the_contract: derived NO file seam out of check-board.sh. The seam spelling (NAME_FILE=\"\${NAME:-path}\") has changed or the arms no longer carry one — with none derived this case asserts nothing and passes."

  while IFS= read -r nm; do
    [ -n "$nm" ] || continue
    n=$(( n + 1 ))
    # The default half is the shipped project path — the thing the sheet must name.
    def="$(printf '%s' "$nm" | sed -E 's/.*:-([^}"]+)\}"$/\1/')"
    grep -qF "$def" "$sheet" || undeclared="$undeclared $def"
  done <<EOF
$seams
EOF

  [ -z "$undeclared" ] \
    || cf "check-board.sh reads (an) adopter-repointable project file(s) that drift-report.md names nowhere —$undeclared. An arm with a file seam and no entry in the contract is invisible to § 4.1, which walks § 2's list and confirms each invariant has a line: an arm with no invariant is structurally unreachable from that walk, so it ships, runs, prints findings, and a reimplementation written from this sheet does not contain it. Either the sheet owes the entry or the arm owes its retirement"

  finish "every project file that a check-board arm reads through a NAMED, adopter-repointable seam is mentioned in drift-report.md — $n seam(s) derived out of check-board.sh's own default-expansion spelling rather than listed here, because the arm letters move. NOT ASSERTED: that the sheet's entry is a TRUE description of what the arm does, which is not decidable here and is left to review; and nothing about arms that read no repointable file"
  teardown
}

# =============================================================================
# CASE — AN ADVISORY SECTION SAYS SO IN THE MACHINE'S VOCABULARY, NOT ONLY IN PROSE.
#
# kit-init's board self-check drops advisory sections by the literal `reports only` in their
# `[x]` header (a machine contract, contracts/drift-report.md § 4). A header that says ADVISORY
# in prose without the token would have its ⚠ counted as a real finding and refuse the install.
# Prose and token are two authoring sites for one fact, so this is a census.
# =============================================================================
case_advisory_headers_carry_the_machine_token() {
  cf_reset
  make_sandbox
  local cb="$SB_WORK/scripts/check-board.sh" rows n=0

  # Every arm-header emission that CLAIMS to be advisory in prose must also carry the token.
  # Derived over the shipped script; the two spellings are held on separate lines so this
  # case's own text cannot satisfy the search it performs.
  local prose='ADVISORY'
  local token='reports only'
  rows="$(awk -v p="$prose" -v t="$token" '
    /echo "\[[a-z]\]/ {
      if (index($0, p) && !index($0, t)) print NR ": " substr($0, 1, 110)
    }
  ' "$cb")"
  [ -z "$rows" ] \
    || cf "an arm header calls itself advisory in PROSE and omits the machine token — kit-init's self-check reads the token, not the prose, so this arm's findings would be counted as real and would refuse an install: $rows"

  # ── INSTRUMENT CHECK: the token is actually present somewhere, and on more than one arm.
  #    A census for "prose without token" is satisfied forever by a file with neither.
  n="$(grep -c "$token" "$cb" || true)"
  [ "$n" -ge 3 ] \
    || cf "the literal '$token' appears only $n time(s) in check-board.sh — either the advisory vocabulary was renamed (and kit-init's awk no longer matches anything) or this census is looking for a string the script has stopped using"

  # ── AND THE CONSUMER STILL READS IT. Textual agreement is not the contract; the awk is.
  grep -qF "$token" "$SB_WORK/scripts/kit-init.sh" \
    || cf "kit-init.sh does not mention '$token' — the producer and the consumer of this machine contract have drifted, and every advisory arm would start failing installs"

  finish "every check-board arm header that calls itself advisory carries the machine token '$token' that kit-init's self-check actually reads ($n occurrence(s)), and the consumer still reads it — prose and token are one fact, and only one of them is machine-readable"
  teardown
}

# =============================================================================
# CASE — THE FRONTMATTER SCAN CAP DOES WHAT IT IS FOR.
#
# check (d) looks for a card's opening `---` only within FRONTMATTER_SCAN_LINES. A card with real
# frontmatter closes its block at the top and is never re-entered, so a body `---` is harmless
# regardless; the cap governs a card with NO frontmatter at the top, where the first `---`
# anywhere would open a block. Both directions: a normal card with a body rule parses, and a
# fence pair PAST the cap is NOT read as frontmatter. The fixture is sized from the derived cap.
# NOT COVERED: whether the cap's value is right.
# =============================================================================
case_frontmatter_scan_cap_is_enforced() {
  cf_reset
  make_sandbox
  local cap i out

  # DERIVE the cap. It is a bare numeric assignment, not the quoted form cb_default reads.
  cap="$(sed -n 's/^FRONTMATTER_SCAN_LINES=\([0-9][0-9]*\).*/\1/p' "$SB_WORK/scripts/check-board.sh" | head -1)"
  case "$cap" in
    ''|*[!0-9]*) _fixture_die "case_frontmatter_scan_cap_is_enforced: could not derive FRONTMATTER_SCAN_LINES from check-board.sh (got '$cap') — a re-typed cap would go stale the day it is retuned, and this case would assert nothing while reading green." ;;
  esac
  [ "$cap" -ge 5 ] \
    || _fixture_die "case_frontmatter_scan_cap_is_enforced: the derived cap is $cap, too small to seed either side of — the derivation is reading the wrong thing."

  # ── CARD A: normal frontmatter, plus a horizontal rule FAR past the cap. Must parse.
  seed_issue todo "$SB_PREFIX-300" bodyrule chore "A card with a body rule"
  local a="$SB_WORK/progress/todo/$SB_PREFIX-300-bodyrule.md"
  i=0; while [ "$i" -lt $((cap + 10)) ]; do printf 'filler line %s\n' "$i" >> "$a"; i=$((i + 1)); done
  printf -- '---\n\nA horizontal rule in the body, well past the cap.\n' >> "$a"

  # ── CARD B: NO frontmatter at the top; a complete fence pair PAST the cap. The cap is
  #    what stops that from being read as frontmatter, so check (d) must report this card
  #    as having no id: line — the finding it would NOT report if the cap were lifted.
  local b="$SB_WORK/progress/todo/$SB_PREFIX-301-latefence.md"
  : > "$b"
  printf '# A card whose fence sits below the cap\n\n' >> "$b"
  i=0; while [ "$i" -lt $((cap + 3)) ]; do printf 'preamble %s\n' "$i" >> "$b"; i=$((i + 1)); done
  printf -- '---\nid: %s-301\nstatus: todo\n---\n\nBody.\n' "$SB_PREFIX" >> "$b"
  publish_sandbox

  out="$(cb_run 2>&1)" || true

  # ── INSTRUMENT CHECK: check (d) ran at all. Every assertion below is about its output.
  printf '%s\n' "$out" | grep '^\[d\]' >/dev/null \
    || _fixture_die "case_frontmatter_scan_cap_is_enforced: no [d] section in the report — the arm did not run and both assertions below would be about an empty string."

  # (A) the normal card is NOT reported. Its block closed on line 3; the body rule is noise.
  printf '%s\n' "$out" | grep "$SB_PREFIX-300-bodyrule" >/dev/null \
    && cf "(A) a card with normal frontmatter and a horizontal rule in its body was reported by check (d) — a body '---' is being read as a fence"

  # (B) the late fence is NOT accepted as frontmatter. This is the arm the cap exists for.
  printf '%s\n' "$out" | grep "$SB_PREFIX-301-latefence" >/dev/null \
    || cf "(B) a fence pair $((cap + 5)) lines down was READ AS FRONTMATTER — the cap is not being applied, so any '---' anywhere in a card can start a frontmatter block and whatever follows it is parsed as fields"

  finish "check (d)'s frontmatter scan cap (derived: $cap lines) is enforced in both directions — a normal card with a horizontal rule far down its body still parses, and a complete fence pair below the cap is NOT accepted as frontmatter; the fixture is sized from the derived cap, so retuning it cannot leave this case asserting nothing. Not covered: whether $cap is the RIGHT value"
  teardown
}

# =============================================================================
# CASE — THE SESSIONSTART HOOK'S OUTPUT STAYS UNDER THE SIZE THE HARNESS DELIVERS INTACT.
# The harness cuts a hook's stdout to a short preview once it passes about 10,000 bytes
# (the cut point is the harness's, not the kit's), so a
# long drift report would reach the session as a preview and a file pointer.
# =============================================================================
HOOK_OUTPUT_BUDGET=9000   # bytes; a margin under the ~10,000-byte cut, never the cut point itself
case_session_start_hook_output_stays_within_the_delivery_budget() {
  cf_reset
  make_sandbox
  publish_sandbox
  local hook="$SB_WORK/scripts/hooks/session-start.sh"
  [ -f "$hook" ] || _fixture_die "case_session_start_hook_output_stays_within_the_delivery_budget: no scripts/hooks/session-start.sh in the sandbox"

  # (a) the real report on a sandbox board is within budget.
  local out n
  out="$(CLAUDE_PROJECT_DIR="$SB_WORK" bash "$hook" 2>&1)" || true
  n="$(printf '%s\n' "$out" | LC_ALL=C wc -c | tr -d ' ')"
  [ "$n" -gt 0 ] || cf "(a) the hook printed nothing — the board report did not reach its output"
  [ "$n" -le "$HOOK_OUTPUT_BUDGET" ] || cf "(a) the hook printed $n bytes on a sandbox board, over the $HOOK_OUTPUT_BUDGET budget"

  # (b) an oversized report (far past the cut) is bounded, and keeps its finding and its verdict.
  local stub_root="$SB_TMP/stubroot" i=0
  mkdir -p "$stub_root/scripts"
  {
    printf '#!/bin/sh\n'
    printf 'echo "[a] first arm — read from: origin/main:"\n'
    while [ "$i" -lt 400 ]; do printf 'echo "      filler line %s that a clean arm prints to explain itself at some length"\n' "$i"; i=$((i + 1)); done
    printf 'echo "    ⚠ FINDING-SENTINEL card X: in todo/ but last Activity declares in_progress"\n'
    printf 'echo "[b] second arm — read from: origin/main:"\n'
    printf 'echo "── board-drift: findings above ⚠ (informational; exit 0 by convention)"\n'
  } > "$stub_root/scripts/check-board.sh"
  chmod +x "$stub_root/scripts/check-board.sh"
  out="$(CLAUDE_PROJECT_DIR="$stub_root" bash "$hook" 2>&1)" || true
  n="$(printf '%s\n' "$out" | LC_ALL=C wc -c | tr -d ' ')"
  [ "$n" -le "$HOOK_OUTPUT_BUDGET" ] || cf "(b) the hook printed $n bytes for an oversized report, over the $HOOK_OUTPUT_BUDGET budget"
  case "$out" in *FINDING-SENTINEL*) : ;; *) cf "(b) the bounded output dropped the report's finding line" ;; esac
  case "$out" in *"[b] second arm"*) : ;; *) cf "(b) the bounded output dropped a later arm's heading" ;; esac
  case "${out##*$'\n'}" in "── board-drift:"*) : ;; *) cf "(b) the bounded output does not end on the verdict line: ${out##*$'\n'}" ;; esac

  finish "the SessionStart hook's output stays within $HOOK_OUTPUT_BUDGET bytes (the harness delivers about 10,000 intact): the real report on a sandbox board, and an oversized one cut to its arm headings and finding lines with the verdict last"
  teardown
}

# =============================================================================
# CASE — arm [q] reads a register's HISTORY: a commit that changed an existing entry's Ruling
# text with no stamp among the lines it added is named; a Findings list that collides with
# another after `## Findings` is named; a colon-labelled amendment is an extra fragment; and
# none of the history/Findings readings reaches a landing's refusal file.
#
# The register is built in the order a project builds it: the kit arrives (the epoch), the
# register is written, then each entry is edited in its own commit. Five edits, one of which is
# the defect:
#   D-01 Ruling text changed, nothing stamped           -> NAMED (the only history finding)
#   D-02 Ruling becomes a WORKING DEFAULT               -> clean (a legal state, stated at its head)
#   D-03 Why changed, Ruling untouched                  -> clean (a reopen is a Ruling change)
#   D-04 Ruling changed AND a colon-labelled Amended    -> no history finding (stamped), but the
#        line added                                        colon label is an extra fragment
#   D-05 / D-06 Ruling becomes a backticked WORKING     -> clean (the register's own format text
#        DEFAULT / WITHDRAWN, as the format shows them     writes the token in backticks)
# =============================================================================
case_check_board_register_ruling_changes_need_a_stamp() {
  cf_reset
  make_sandbox
  local registers reg_path reg_mark reg="" out q hist_n
  registers="$(cb_default REGISTERS)"
  [ -n "$registers" ] || _fixture_die "case_check_board_register_ruling_changes_need_a_stamp: could not derive REGISTERS from the defaults block."
  reg_path="${registers%%|*}"
  reg_mark="$(printf '%s' "$registers" | awk -F'|' '{print $2}')"
  reg="$SB_WORK/$reg_path"
  [ -f "$SB_WORK/scripts/githooks/commit-msg" ] \
    || _fixture_die "case_check_board_register_ruling_changes_need_a_stamp: the sandbox ships no commit-msg hook, so there is no epoch."
  # THE EPOCH, first: the kit's hook file arrives in its own commit.
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "init" >/dev/null 2>&1

  mkdir -p "$(dirname "$reg")"
  cat > "$reg" <<EOT
# DECISIONS
## A. Bucket
${reg_mark}D-01 — first
**Ruling.** Alpha holds.
**Why.** Reasons.
**Provenance.** PM.

${reg_mark}D-02 — second
**Ruling.** Beta holds.
**Why.** Reasons.
**Provenance.** PM.

${reg_mark}D-03 — third
**Ruling.** Gamma holds.
**Why.** Reasons.
**Provenance.** PM.

${reg_mark}D-04 — fourth
**Ruling.** Delta holds.
**Why.** Reasons.
**Provenance.** PM.

${reg_mark}D-05 — fifth
**Ruling.** Echo holds.
**Why.** Reasons.
**Provenance.** PM.

${reg_mark}D-06 — sixth
**Ruling.** Foxtrot holds.
**Why.** Reasons.
**Provenance.** PM.

## Findings — what surfaced
1. one
2. two

---

## What earns an entry
1. a
2. b
3. c
3. collided with c
EOT
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "[PM] register v1" >/dev/null 2>&1

  # D-01: the defect — a content change to a Ruling, nothing stamped.
  sed -i.bak 's/^\*\*Ruling\.\*\* Alpha holds\./**Ruling.** Alpha holds, except for one case./' "$reg"; rm -f "$reg.bak"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m "[PM] D-01 gains an exception" >/dev/null 2>&1
  local sha_d01; sha_d01="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"
  # D-02: becomes a WORKING DEFAULT, the token at the head of the Ruling.
  sed -i.bak 's/^\*\*Ruling\.\*\* Beta holds\./**Ruling.** WORKING DEFAULT (provisional) — Beta holds./' "$reg"; rm -f "$reg.bak"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m "[PM] D-02 becomes a working default" >/dev/null 2>&1
  # D-03: only the Why changes.
  awk '/^### D-03|^D-03|D-03 — third/{f=1} f && /^\*\*Why\.\*\*/{sub(/Reasons\./, "Reasons, restated."); f=0} {print}' "$reg" > "$reg.new" && mv "$reg.new" "$reg"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m "[PM] D-03 Why restated" >/dev/null 2>&1
  # D-04: a Ruling change WITH a colon-labelled stamp line added before Provenance.
  awk '/D-04 — fourth/{f=1} f && /^\*\*Ruling\./{sub(/Delta holds\./, "Delta holds twice.")} f && /^\*\*Provenance\./{print "**Amended 2026-10-07:** Delta now holds twice."; f=0} {print}' "$reg" > "$reg.new" && mv "$reg.new" "$reg"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m "[PM] D-04 amended" >/dev/null 2>&1
  # D-05, D-06: the token at the head of the Ruling, in backticks, as DECISIONS.md's format text shows it.
  sed -i.bak 's/^\*\*Ruling\.\*\* Echo holds\./**Ruling.** `WORKING DEFAULT (provisional) — Echo holds.`/' "$reg"; rm -f "$reg.bak"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m "[PM] D-05 becomes a working default" >/dev/null 2>&1
  sed -i.bak 's/^\*\*Ruling\.\*\* Foxtrot holds\./**Ruling.** `WITHDRAWN 2026-10-08 — until the owner answers.`/' "$reg"; rm -f "$reg.bak"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m "[PM] D-06 withdrawn" >/dev/null 2>&1
  publish_sandbox

  grep -q 'Alpha holds, except' "$reg" && grep -q 'Delta holds twice' "$reg" && grep -q 'WORKING DEFAULT (provisional)' "$reg" && grep -q 'Reasons, restated' "$reg" \
    && grep -qF '`WORKING DEFAULT (provisional) — Echo' "$reg" && grep -qF '`WITHDRAWN 2026-10-08' "$reg" \
    || _fixture_die "case_check_board_register_ruling_changes_need_a_stamp: the planted edits are not all in the register."

  out="$(cb_run)"
  q="$(printf '%s\n' "$out" | _cb_q_section)"
  printf '%s\n' "$q" | grep -E "⚠ .* D-01 — its Ruling text changed in ${sha_d01}" >/dev/null \
    || cf "D-01's unstamped Ruling change ($sha_d01) was NOT named: $q"
  printf '%s\n' "$q" | grep 'Ruling text changed' | grep -E 'D-0[23456]' >/dev/null \
    && cf "a stamped, WORKING DEFAULT or Why-only change was named as an unstamped Ruling change: $q"
  printf '%s\n' "$q" | grep -E '⚠ .* D-04 —.*extra dated/bold fragment' >/dev/null \
    || cf "D-04's colon-labelled amendment (**Amended 2026-10-07:**) was NOT read as an extra fragment: $q"
  printf '%s\n' "$q" | grep -E 'numbered item 3 follows 3 after `## Findings`' >/dev/null \
    || cf "the colliding numbered list after ## Findings was not named: $q"
  printf '%s\n' "$q" | grep -E 'numbered item [12] ' >/dev/null \
    && cf "a list restart or a clean step was named as a collision: $q"
  printf '%s\n' "$out" | grep 'board-drift: clean ✓' >/dev/null \
    || cf "arm [q]'s history findings moved the verdict (reports only): $(printf '%s\n' "$out" | grep '^── board-drift:')"

  # NOT REFUSED AT A LANDING: the function a landing runs, with no history named, records neither
  # reading in the findings file a landing reads; with history named, they print but still record
  # nothing.
  local hits="$SB_TMP/q-hits"
  : > "$hits"
  ( set +e
    . "$SB_WORK/scripts/lib/board-properties.sh" || exit 3
    kit_bp_load_declarations "$SB_WORK/scripts/check-board.sh" "$SB_WORK/scripts/config.sh" || exit 4
    KIT_BP_HITS_FILE="$hits"; KIT_BP_HIST_REPO="$SB_WORK"; KIT_BP_HIST_RANGE="HEAD"
    kit_bp_register_shape "$SB_WORK" > "$SB_TMP/q-direct.txt" 2>&1 ) \
    || _fixture_die "case_check_board_register_ruling_changes_need_a_stamp: could not drive kit_bp_register_shape directly."
  grep 'Ruling text changed' "$SB_TMP/q-direct.txt" >/dev/null \
    || cf "(direct) with history named the function did not print the Ruling finding it is meant to report"
  grep -E 'Ruling text changed|numbered item' "$hits" >/dev/null \
    && cf "(landing) a history or Findings finding reached the findings file a landing refuses on: $(cat "$hits")"
  grep -F 'extra' "$hits" >/dev/null \
    || cf "(landing) control: the colon-labelled shape finding was not recorded, so the findings file is not being written at all: $(cat "$hits")"

  # ABLATION: the comparison of the two Ruling tables, made to compare a table with itself, and the report goes quiet.
  local lib="$SB_WORK/scripts/lib/board-properties.sh"
  grep -q 'diff "\$scratch/old.r" "\$scratch/new.r"' "$lib" \
    || _control_did_not_run "find the comparison of the two Ruling tables in lib/board-properties.sh"
  sed -i.bak 's#diff "\$scratch/old.r" "\$scratch/new.r"#diff "$scratch/old.r" "$scratch/old.r"#' "$lib"; rm -f "$lib.bak"
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_q_section | grep 'Ruling text changed' >/dev/null \
    && cf "ABLATION FAILED — with the Ruling comparison removed the finding still printed, so it is not attributable to it"

  finish "arm [q]: a Ruling changed with no stamp is named from the register's own history (a stamped one, a WORKING DEFAULT head and a Why-only edit are not), a colon-labelled amendment is an extra fragment, a colliding Findings list is named, none of it moves the verdict or reaches a landing's findings file, and the comparison is ablation-proven"
  teardown
}

# =============================================================================
# CASE — arm [q] says DID NOT RUN when git cannot read a register copy of the ruling history.
# A path that is absent at a revision is a legitimate skip; a blob or a tree git cannot read (a partial or shallow
# clone used offline, a damaged object) is not, and the arm used to skip the commit without a word and print a clean
# verdict. A shim `git` makes the register's `show` (then its `ls-tree`) fail with 128, as an unreadable object does.
#   control: no shim              -> the unstamped change is named, no DID NOT RUN
#   (a) `show` of the register fails -> the arm says DID NOT RUN, names what it could not read, carries a Next
#   (b) `ls-tree` of the register fails -> the same
# =============================================================================
case_check_board_arm_q_ruling_history_says_did_not_run_when_git_cannot_read_a_copy() {
  cf_reset
  make_sandbox
  local registers reg_path reg_mark reg out q real_git shim mode
  registers="$(cb_default REGISTERS)"
  [ -n "$registers" ] || _fixture_die "case_check_board_arm_q_ruling_history_says_did_not_run_when_git_cannot_read_a_copy: could not derive REGISTERS from the defaults block."
  reg_path="${registers%%|*}"
  reg_mark="$(printf '%s' "$registers" | awk -F'|' '{print $2}')"
  reg="$SB_WORK/$reg_path"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "init" >/dev/null 2>&1
  mkdir -p "$(dirname "$reg")"
  printf '# DECISIONS\n## A. Bucket\n%sD-01 — first\n**Ruling.** Alpha holds.\n**Why.** Reasons.\n**Provenance.** PM.\n' "$reg_mark" > "$reg"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "[PM] register v1" >/dev/null 2>&1
  sed -i.bak 's/^\*\*Ruling\.\*\* Alpha holds\./**Ruling.** Alpha holds, except for one case./' "$reg"; rm -f "$reg.bak"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m "[PM] D-01 gains an exception" >/dev/null 2>&1
  publish_sandbox
  real_git="$(command -v git)"
  out="$(cb_run)"; q="$(printf '%s\n' "$out" | _cb_q_section)"
  printf '%s\n' "$q" | grep -F 'D-01 — its Ruling text changed' >/dev/null || cf "(control) the unstamped change was not named without a shim: $q"
  printf '%s\n' "$q" | grep -F 'DID NOT RUN' >/dev/null && cf "(control) the arm says DID NOT RUN without a shim: $q"
  for mode in show ls-tree; do
    shim="$SB_TMP/shim-$mode"; mkdir -p "$shim"
    printf '%s\n' '#!/bin/sh' \
      "case \" \$* \" in *\" $mode \"*) case \"\$*\" in *\"$reg_path\"*) exit 128 ;; esac ;; esac" \
      "exec \"$real_git\" \"\$@\"" > "$shim/git"
    chmod +x "$shim/git"
    out="$(PATH="$shim:$PATH" cb_run)"; q="$(printf '%s\n' "$out" | _cb_q_section)"
    printf '%s\n' "$q" | grep -F 'DID NOT RUN' >/dev/null || cf "($mode) git could not read the register's history and arm [q] does not say DID NOT RUN: $q"
    printf '%s\n' "$q" | grep -F "its ruling history is not read" >/dev/null || cf "($mode) the arm does not say the ruling history is not read (this reader's own text): $q"
    printf '%s\n' "$q" | grep -F 'Next:' >/dev/null || cf "($mode) the DID NOT RUN line carries no Next: $q"
    # a complete repository has nothing to unshallow: the Next names a re-fetch or a check of the repository
    printf '%s\n' "$q" | grep -F 'unshallow' >/dev/null && cf "($mode) the Next offers git fetch --unshallow in a complete repository: $q"
    printf '%s\n' "$q" | grep -F 'git fsck' >/dev/null || cf "($mode) the Next does not name a check or a re-fetch that works on a complete repository: $q"
    printf '%s\n' "$q" | grep -F 'with the remote reachable' >/dev/null || cf "($mode) the Next does not say to re-run with the remote reachable (a git fetch does not restore a partial clone's objects; reading them does): $q"
    printf '%s\n' "$q" | grep -F 'git fetch to re-fetch' >/dev/null && cf "($mode) the Next still says git fetch re-fetches the missing objects: $q"
  done
  # (shallow) a clone cut at --depth 1 has a boundary commit with no parent to read: it is not a root, and the arm says so (DID NOT RUN) with the Next that fits
  rm -rf "$SB_TMP/shallow"
  git clone -q --depth 1 "file://$SB_ORIGIN" "$SB_TMP/shallow" >/dev/null 2>&1 || _fixture_die "case_check_board_arm_q_ruling_history_says_did_not_run_when_git_cannot_read_a_copy: the depth-1 clone failed."
  [ "$(git -C "$SB_TMP/shallow" rev-parse --is-shallow-repository)" = true ] || _fixture_die "case_check_board_arm_q_ruling_history_says_did_not_run_when_git_cannot_read_a_copy: the clone is not shallow."
  out="$(SB_WORK="$SB_TMP/shallow" cb_run)"; q="$(printf '%s\n' "$out" | _cb_q_section)"
  printf '%s\n' "$q" | grep -F 'DID NOT RUN' >/dev/null || cf "(shallow) the clone's history stops at a boundary commit and arm [q] does not say DID NOT RUN: $q"
  printf '%s\n' "$q" | grep -F "its ruling history is not read" >/dev/null || cf "(shallow) the arm does not say the ruling history is not read: $q"
  printf '%s\n' "$q" | grep -F 'git fetch --unshallow' >/dev/null || cf "(shallow) the Next does not name git fetch --unshallow: $q"
  # (root) a depth clone that reaches the root lists the root in .git/shallow, but the root has no parent line: it is a root, not a boundary, so the history reads whole
  local rr="$SB_TMP/rootrepo" rc2="$SB_TMP/rootclone" rshape rfail
  rshape="$(printf '%s' "$registers" | awk -F'|' '{print $3}')"
  rm -rf "$rr" "$rc2"; mkdir -p "$rr/$(dirname "$reg_path")"
  git -C "$rr" init -q . >/dev/null 2>&1
  printf '# DECISIONS\n## A. Bucket\n%sD-01 — first\n**Ruling.** Alpha holds.\n**Why.** Reasons.\n**Provenance.** PM.\n' "$reg_mark" > "$rr/$reg_path"
  git -C "$rr" add -A >/dev/null 2>&1; git -C "$rr" -c user.email=t@t.invalid -c user.name=t commit -q -m "register v1" >/dev/null 2>&1
  sed -i.bak 's/^\*\*Ruling\.\*\* Alpha holds\./**Ruling.** Alpha holds, except for one case./' "$rr/$reg_path"; rm -f "$rr/$reg_path.bak"
  git -C "$rr" add -A >/dev/null 2>&1; git -C "$rr" -c user.email=t@t.invalid -c user.name=t commit -q -m "D-01 gains an exception" >/dev/null 2>&1
  git clone -q --depth 2 "file://$rr" "$rc2" >/dev/null 2>&1 || _fixture_die "case_check_board_arm_q_ruling_history_says_did_not_run_when_git_cannot_read_a_copy: the root clone failed."
  [ "$(git -C "$rc2" rev-parse --is-shallow-repository)" = true ] && [ -s "$rc2/.git/shallow" ] || _fixture_die "case_check_board_arm_q_ruling_history_says_did_not_run_when_git_cannot_read_a_copy: the root clone is not shallow."
  rfail="$SB_TMP/root-fail"; : > "$rfail"
  ( set +e
    . "$SB_WORK/scripts/lib/board-properties.sh" || exit 3
    kit_bp_load_declarations "$SB_WORK/scripts/check-board.sh" "$SB_WORK/scripts/config.sh" || exit 4
    KIT_BP_FAIL_FILE="$rfail"; KIT_BP_HIST_REPO="$rc2"; KIT_BP_HIST_RANGE="HEAD"
    _bp_ruling_history "$reg_path" "$reg_mark" "$rshape" > "$SB_TMP/root-out.txt" 2>&1 ) \
    || _fixture_die "case_check_board_arm_q_ruling_history_says_did_not_run_when_git_cannot_read_a_copy: could not drive _bp_ruling_history on the root clone."
  [ ! -s "$rfail" ] || cf "(root) a depth clone that reaches the root reads its root as a shallow boundary: $(head -2 "$rfail" | tr '\n' '|' | cut -c1-200)"
  grep -F 'D-01 — its Ruling text changed' "$SB_TMP/root-out.txt" >/dev/null || cf "(root) control: the unstamped change in the root clone was not named, so the history was not read: $(cat "$SB_TMP/root-out.txt" | tr '\n' '|' | cut -c1-200)"
  finish "arm [q]: a register copy git cannot read (its blob, then its tree) in the ruling history is DID NOT RUN with the reason and a Next, where an absent one stays a skip"
  teardown
}

# =============================================================================
# CASE — arm [q]: an edit that only adds (or removes) the CROSS_CUTTING_MARKER at the head of a
# Ruling is not a Ruling change. The marker sits in the Ruling field, so the comparison strips it
# from both sides first; a real text change still names the entry, with or without the marker.
#   D-01 marker added, nothing else          -> clean
#   D-02 marker removed, nothing else        -> clean
#   D-03 marker added AND the text changed   -> NAMED
#   D-04 text changed, marker already there  -> NAMED (the control: the strip is not a blanket pass)
# RED FIRST: on a comparison that reads the marker as text, D-01 and D-02 are named.
# =============================================================================
case_check_board_cross_cutting_marker_edit_is_not_a_ruling_change() {
  cf_reset
  make_sandbox
  local registers reg_path reg_mark reg="" out q lib
  registers="$(cb_default REGISTERS)"
  [ -n "$registers" ] || _fixture_die "case_check_board_cross_cutting_marker_edit_is_not_a_ruling_change: could not derive REGISTERS from the defaults block."
  reg_path="${registers%%|*}"
  reg_mark="$(printf '%s' "$registers" | awk -F'|' '{print $2}')"
  reg="$SB_WORK/$reg_path"
  [ -f "$SB_WORK/scripts/githooks/commit-msg" ] \
    || _fixture_die "case_check_board_cross_cutting_marker_edit_is_not_a_ruling_change: the sandbox ships no commit-msg hook, so there is no epoch."
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "init" >/dev/null 2>&1

  mkdir -p "$(dirname "$reg")"
  cat > "$reg" <<EOT
# DECISIONS
## A. Bucket
${reg_mark}D-01 — first
**Ruling.** Alpha holds.
**Why.** Reasons.
**Provenance.** PM.

${reg_mark}D-02 — second
**Ruling.** [cross-cutting] Beta holds.
**Why.** Reasons.
**Provenance.** PM.

${reg_mark}D-03 — third
**Ruling.** Gamma holds.
**Why.** Reasons.
**Provenance.** PM.

${reg_mark}D-04 — fourth
**Ruling.** [cross-cutting] Delta holds.
**Why.** Reasons.
**Provenance.** PM.
EOT
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "[PM] register v1" >/dev/null 2>&1

  sed -i.bak 's/^\*\*Ruling\.\*\* Alpha holds\./**Ruling.** [cross-cutting] Alpha holds./' "$reg"; rm -f "$reg.bak"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m "[PM] D-01 marked cross-cutting" >/dev/null 2>&1
  sed -i.bak 's/^\*\*Ruling\.\*\* \[cross-cutting\] Beta holds\./**Ruling.** Beta holds./' "$reg"; rm -f "$reg.bak"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m "[PM] D-02 no longer cross-cutting" >/dev/null 2>&1
  sed -i.bak 's/^\*\*Ruling\.\*\* Gamma holds\./**Ruling.** [cross-cutting] Gamma holds, except one case./' "$reg"; rm -f "$reg.bak"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m "[PM] D-03 marked and reworded" >/dev/null 2>&1
  sed -i.bak 's/^\*\*Ruling\.\*\* \[cross-cutting\] Delta holds\./**Ruling.** [cross-cutting] Delta holds twice./' "$reg"; rm -f "$reg.bak"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m "[PM] D-04 reworded" >/dev/null 2>&1
  publish_sandbox

  grep -qF '[cross-cutting] Alpha holds.' "$reg" && grep -qF '** Beta holds.' "$reg" && grep -qF 'Gamma holds, except' "$reg" && grep -qF 'Delta holds twice' "$reg" \
    || _fixture_die "case_check_board_cross_cutting_marker_edit_is_not_a_ruling_change: the planted edits are not all in the register."

  out="$(cb_run)"
  q="$(printf '%s\n' "$out" | _cb_q_section)"
  printf '%s\n' "$q" | grep 'Ruling text changed' | grep -E 'D-01' >/dev/null \
    && cf "D-01, which only gained the cross-cutting marker, was named as a Ruling change: $q"
  printf '%s\n' "$q" | grep 'Ruling text changed' | grep -E 'D-02' >/dev/null \
    && cf "D-02, which only lost the cross-cutting marker, was named as a Ruling change: $q"
  printf '%s\n' "$q" | grep -E "⚠ .* D-03 — its Ruling text changed" >/dev/null \
    || cf "D-03 (marker added AND the text changed) was NOT named: $q"
  printf '%s\n' "$q" | grep -E "⚠ .* D-04 — its Ruling text changed" >/dev/null \
    || cf "D-04 (text changed under an existing marker) was NOT named: $q"

  # ABLATION: the strip made a no-op, and D-01 and D-02 are named again.
  lib="$SB_WORK/scripts/lib/board-properties.sh"
  grep -q '| _bp_strip_marker |' "$lib" \
    || _control_did_not_run "find the marker strip (_bp_strip_marker) in lib/board-properties.sh"
  sed -i.bak 's/| _bp_strip_marker |/| cat |/' "$lib"; rm -f "$lib.bak"
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_q_section | grep 'Ruling text changed' | grep -E 'D-01' >/dev/null \
    || cf "ABLATION FAILED — with the marker strip removed D-01 was still not named, so its silence is not attributable to the strip"

  finish "arm [q]: adding or removing only the cross-cutting marker at the head of a Ruling is not a Ruling change, while a text change still is (with the marker added, or under one already there), and the strip is ablation-proven"
  teardown
}

# =============================================================================
# CASE — arm [e] reads EVERY commit since the rule's epoch, not a fixed 20.
#
# The epoch commit, then ONE unprefixed commit that bypassed the hook, then more prefixed
# commits than the old window held. The offender is the 26th from the tip.
# =============================================================================
case_check_board_arm_e_reads_every_commit_since_the_epoch() {
  cf_reset
  make_sandbox
  [ -f "$SB_WORK/scripts/githooks/commit-msg" ] \
    || _fixture_die "case_check_board_arm_e_reads_every_commit_since_the_epoch: the sandbox ships no commit-msg hook, so there is no epoch."
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "init" >/dev/null 2>&1
  sbcommit -q --allow-empty -m "an unprefixed commit that bypassed the hook" >/dev/null 2>&1
  local sha_off i; sha_off="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"
  for i in $(seq 1 25); do
    sbcommit -q --allow-empty -m "[Dev] filler $i" >/dev/null 2>&1
  done
  publish_sandbox
  # INSTRUMENT: the offender really is further back than the old window.
  local depth
  depth="$(git -C "$SB_WORK" rev-list --count "$sha_off..HEAD")"
  [ "$depth" -gt 21 ] || _fixture_die "case_check_board_arm_e_reads_every_commit_since_the_epoch: the offender is only $depth commits back — inside the old window, so this case proves nothing."
  local out; out="$(cb_run)"
  printf '%s\n' "$out" | grep "$sha_off" | grep 'lacks a \[Role\] prefix' >/dev/null \
    || cf "the unprefixed commit $sha_off, $depth commits back, was not reported — the window is still a fixed count: $out"
  finish "check-board arm [e]: an unprefixed commit more than 20 commits behind the tip is still reported, because the scan runs from the rule's epoch"
  teardown
}

# =============================================================================
# CASE — arm [e] exempts a Revert, or a fixup!/squash!/amend!, ONLY when its diff matches.
#
# Six commits, one verdict each. The exempt ones are real git output (`git revert`,
# `git commit --fixup`); the others carry the same subject shape over a diff that is neither.
# =============================================================================
case_check_board_arm_e_exempts_revert_and_fixup_only_when_the_diff_matches() {
  cf_reset
  make_sandbox
  [ -f "$SB_WORK/scripts/githooks/commit-msg" ] \
    || _fixture_die "case_check_board_arm_e_exempts_revert_and_fixup_only_when_the_diff_matches: the sandbox ships no commit-msg hook, so there is no epoch."
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "init" >/dev/null 2>&1
  local sha_feat sha_real_revert sha_fake_revert sha_wrong_revert sha_real_fixup sha_fake_fixup sha_far_fixup

  # A real revert: a commit, then git's own `git revert` of it.
  printf 'a\n' > "$SB_WORK/a.txt"; git -C "$SB_WORK" add a.txt; sbcommit -q -m "[Dev] add a" >/dev/null 2>&1
  MSG_OK=1 git -C "$SB_WORK" revert --no-edit HEAD >/dev/null 2>&1 \
    || _fixture_die "case_check_board_arm_e_exempts_revert_and_fixup_only_when_the_diff_matches: git revert failed in the sandbox."
  sha_real_revert="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"
  case "$(git -C "$SB_WORK" log -1 --format=%s)" in 'Revert "'*) : ;; *) _fixture_die "case_check_board_arm_e_exempts_revert_and_fixup_only_when_the_diff_matches: git revert did not write a Revert subject." ;; esac

  # A fake revert: the subject shape over an unrelated change, naming nothing.
  printf 'wholesale\n' > "$SB_WORK/allocate.js"; git -C "$SB_WORK" add allocate.js
  sbcommit -q -m 'Revert "nothing"; rewrote allocate.js wholesale' >/dev/null 2>&1
  sha_fake_revert="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"

  # A revert that names a real commit but whose diff is not its inverse.
  printf 'b\n' > "$SB_WORK/b.txt"; git -C "$SB_WORK" add b.txt; sbcommit -q -m "[Dev] add b" >/dev/null 2>&1
  sha_feat="$(git -C "$SB_WORK" rev-parse HEAD)"
  printf 'c\n' > "$SB_WORK/c.txt"; git -C "$SB_WORK" add c.txt
  sbcommit -q -m "$(printf 'Revert "[Dev] add b"\n\nThis reverts commit %s.' "$sha_feat")" >/dev/null 2>&1
  sha_wrong_revert="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"

  # A real fixup of an earlier commit, touching only that commit's file.
  printf 'b2\n' >> "$SB_WORK/b.txt"; git -C "$SB_WORK" add b.txt
  MSG_OK=1 git -C "$SB_WORK" commit -q --fixup="$sha_feat" >/dev/null 2>&1 \
    || _fixture_die "case_check_board_arm_e_exempts_revert_and_fixup_only_when_the_diff_matches: git commit --fixup failed."
  sha_real_fixup="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"

  # A fixup! naming nothing, and one naming a real commit but touching another file.
  printf 'g\n' > "$SB_WORK/g.txt"; git -C "$SB_WORK" add g.txt
  sbcommit -q -m "fixup! anything at all" >/dev/null 2>&1
  sha_fake_fixup="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"
  printf 'z\n' > "$SB_WORK/z.txt"; git -C "$SB_WORK" add z.txt
  sbcommit -q -m "fixup! [Dev] add b" >/dev/null 2>&1
  sha_far_fixup="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"
  publish_sandbox

  local out hits
  out="$(cb_run)"
  hits="$(printf '%s\n' "$out" | grep 'lacks a \[Role\] prefix' || true)"
  printf '%s\n' "$hits" | grep "$sha_fake_revert" >/dev/null || cf "a Revert naming no commit ($sha_fake_revert) was exempted: $hits"
  printf '%s\n' "$hits" | grep "$sha_wrong_revert" >/dev/null || cf "a Revert whose diff is not its named commit's inverse ($sha_wrong_revert) was exempted: $hits"
  printf '%s\n' "$hits" | grep "$sha_fake_fixup" >/dev/null || cf "a fixup! naming no commit ($sha_fake_fixup) was exempted: $hits"
  printf '%s\n' "$hits" | grep "$sha_far_fixup" >/dev/null || cf "a fixup! touching a file its target did not ($sha_far_fixup) was exempted: $hits"
  printf '%s\n' "$hits" | grep "$sha_real_revert" >/dev/null && cf "git's own revert ($sha_real_revert) was reported — the exemption over-narrowed: $hits"
  printf '%s\n' "$hits" | grep "$sha_real_fixup" >/dev/null && cf "git's own fixup ($sha_real_fixup) was reported — the exemption over-narrowed: $hits"

  finish "check-board arm [e]: a Revert is exempt only when its diff inverts the commit its body names, a fixup! only when it names an earlier commit and touches nothing that commit did not — git's own revert and --fixup stay exempt, the same subjects over any other diff are reported"
  teardown
}

# Builds the stamp fixture the next two cases read: an unstamped Ruling change (D-01, plain "Clarified"), then a later
# commit that adds the bold stamp for the same entry. Sets STAMP_FIX_UNSTAMPED and STAMP_FIX_LATER (short shas).
_cb_stamp_fixture() {
  local registers reg_path reg_mark reg
  registers="$(cb_default REGISTERS)"
  [ -n "$registers" ] || _fixture_die "_cb_stamp_fixture: could not derive REGISTERS from the defaults block."
  reg_path="${registers%%|*}"
  reg_mark="$(printf '%s' "$registers" | awk -F'|' '{print $2}')"
  reg="$SB_WORK/$reg_path"
  mkdir -p "$(dirname "$reg")"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "init" >/dev/null 2>&1
  cat > "$reg" <<EOT
# DECISIONS
## A. Bucket
${reg_mark}D-01 — first
**Ruling.** Alpha holds.
**Why.** Reasons.
**Provenance.** PM.
EOT
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "[PM] register v1" >/dev/null 2>&1
  sed -i.bak 's/^\*\*Ruling\.\*\* Alpha holds\./**Ruling.** Alpha holds in every case. Clarified 2026-10-20./' "$reg"; rm -f "$reg.bak"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m "[PM] D-01 clarified, plain" >/dev/null 2>&1
  STAMP_FIX_UNSTAMPED="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"
  sed -i.bak 's/Clarified 2026-10-20\./Clarified 2026-10-20. **Clarified 2026-10-21.**/' "$reg"; rm -f "$reg.bak"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m "[PM] D-01 stamped, later" >/dev/null 2>&1
  STAMP_FIX_LATER="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"
  grep -qF '**Clarified 2026-10-21.**' "$reg" \
    || _fixture_die "_cb_stamp_fixture: the later stamp is not in the register."
  publish_sandbox
}

# =============================================================================
# CASE — the unstamped-change warning names the bold shape and the route, and the register's
# format text states the same shape and every word the checker reads (the words derived from the
# shipped lib, the document read before the fixture replaces it).
# =============================================================================
case_check_board_ruling_warning_names_the_bold_stamp_and_the_route() {
  cf_reset
  make_sandbox
  local out q line
  _cb_stamp_fixture
  out="$(cb_run)"
  q="$(printf '%s\n' "$out" | _cb_q_section)"
  line="$(printf '%s\n' "$q" | grep "D-01 — its Ruling text changed in ${STAMP_FIX_UNSTAMPED}")"
  [ -n "$line" ] || cf "the unstamped change ($STAMP_FIX_UNSTAMPED) was not named at all: $q"
  printf '%s\n' "$line" | grep -F '**<word> <YYYY-MM-DD>.**' >/dev/null \
    || cf "the warning does not show the bold stamp shape **<word> <YYYY-MM-DD>.**: $line"
  printf '%s\n' "$line" | grep -F "inside the entry's Ruling" >/dev/null \
    || cf "the warning does not name where the stamp goes: $line"
  printf '%s\n' "$line" | grep -F 'this history stays as it is' >/dev/null \
    || cf "the warning does not say the history stays and the next change is stamped: $line"
  finish "the unstamped-change warning shows the bold dated shape, where it goes and that history stays"
  teardown
}

# =============================================================================
# CASE — the shipped register's format text states the bold dated stamp and every word [q] reads.
# The register is SEED class: past day one it is the project's own, so on a lived tree this case has
# no subject (N/A), and the warning half above still runs.
# =============================================================================
case_register_format_text_states_the_bold_stamp() {
  cf_reset
  local L="the register format text states the bold dated stamp shape and every word the checker reads"
  local lib="$REAL_REPO_ROOT/scripts/lib/board-properties.sh" registers reg_path doc words w lived
  registers="$(cb_default REGISTERS)"
  [ -n "$registers" ] || _fixture_die "case_register_format_text_states_the_bold_stamp: could not derive REGISTERS from the defaults block."
  reg_path="${registers%%|*}"; doc="$REAL_REPO_ROOT/$reg_path"
  lived="$(_tree_has_lived)"
  if [ -n "$lived" ]; then
    skp_lived "$L" "$reg_path is this project's own once $lived"; return
  fi
  [ -f "$doc" ] || _fixture_die "case_register_format_text_states_the_bold_stamp: the shipped tree has no register at $reg_path."
  words="$(sed -n "s/^_BP_STAMP_WORDS='\(.*\)'$/\1/p" "$lib")"
  [ -n "$words" ] || _fixture_die "case_register_format_text_states_the_bold_stamp: could not derive _BP_STAMP_WORDS."
  grep -F '**Amended <YYYY-MM-DD>.**' "$doc" >/dev/null \
    || cf "$reg_path does not show the bold dated stamp **Amended <YYYY-MM-DD>.**"
  grep -F 'later commit' "$doc" >/dev/null \
    || cf "$reg_path does not say a stamp in a later commit is not read"
  for w in $(printf '%s' "$words" | tr ' |' '_ '); do
    w="$(printf '%s' "$w" | tr '_' ' ')"
    grep -F "\`$w\`" "$doc" >/dev/null \
      || cf "$reg_path does not name the stamp word \`$w\` the checker reads"
  done
  finish "$L"
}

# =============================================================================
# CASE — a stamp added in a LATER commit does not clear the earlier commit's warning (positive
# control: this is the behaviour that already holds, and the warning's text says so).
# =============================================================================
case_check_board_a_later_stamp_leaves_the_earlier_warning_in_place() {
  cf_reset
  make_sandbox
  local out q
  _cb_stamp_fixture
  out="$(cb_run)"
  q="$(printf '%s\n' "$out" | _cb_q_section)"
  printf '%s\n' "$q" | grep "D-01 — its Ruling text changed in ${STAMP_FIX_UNSTAMPED}" >/dev/null \
    || cf "the later stamp ($STAMP_FIX_LATER) cleared the earlier unstamped change's warning: $q"
  printf '%s\n' "$q" | grep "D-01 — its Ruling text changed in ${STAMP_FIX_LATER}" >/dev/null \
    && cf "the stamped commit itself was named as unstamped: $q"
  finish "a stamp added in a later commit leaves the earlier unstamped change named, and the stamped commit itself is not"
  teardown
}

# =============================================================================
# CASE — arm [m] counts a landed card that names NO PRD and gives NO reason, and names it.
#
# Four landed cards: one with a PRD, one `prd:` blank with no reason, one `prd: none` with no
# reason, one `prd:` blank WITH a reason. The two bare cards are counted and named; the reasoned
# one and the PRD-covered one are not.
# =============================================================================
case_prd_coverage_names_a_card_with_neither() {
  cf_reset
  if ! has_issue_template; then skp "check-board PRD coverage names a card with neither" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  local out line id c f
  for id in 971:covered:PRD-001 972:bare-blank:PRD-001 973:bare-none:PRD-001 974:reasoned-blank:PRD-001; do
    ( cd "$SB_WORK" && ./scripts/new-issue.sh "$(printf '%s' "$id" | cut -d: -f2)" --id "$SB_PREFIX-${id%%:*}" --prd "${id##*:}" >/dev/null 2>&1 ) \
      || _fixture_die "case_prd_coverage_names_a_card_with_neither: new-issue.sh could not mint $SB_PREFIX-${id%%:*}"
  done
  f="$SB_WORK/progress/todo/$SB_PREFIX"
  sed -i.bak 's/^prd:.*/prd:/' "${f}-972-bare-blank.md"
  sed -i.bak 's/^prd:.*/prd: none/' "${f}-973-bare-none.md"
  sed -i.bak -e 's/^prd:.*/prd:/' -e 's/^prd_reason:.*/prd_reason: a one-off chore/' "${f}-974-reasoned-blank.md"
  rm -f "${f}"-97?-*.md.bak
  grep -q '^prd:$' "${f}-972-bare-blank.md" && grep -q '^prd: none$' "${f}-973-bare-none.md" && grep -q '^prd_reason: a one-off' "${f}-974-reasoned-blank.md" \
    || _fixture_die "case_prd_coverage_names_a_card_with_neither: the planted frontmatter did not take."
  mkdir -p "$SB_WORK/progress/qa_complete"
  mv "${f}"-97?-*.md "$SB_WORK/progress/qa_complete/" \
    || _fixture_die "case_prd_coverage_names_a_card_with_neither: could not move the minted cards to qa_complete/"
  for c in "$SB_WORK/progress/qa_complete/$SB_PREFIX"-97?-*.md; do
    printf -- '- 2026-01-01 [%s] → qa_complete: landed (fixture)\n' "$SB_ROLE" >> "$c"
  done
  publish_sandbox
  out="$(cb_run)"
  line="$(printf '%s\n' "$out" | grep -E '^\[[a-z]\] PRD coverage' | head -1)"
  printf '%s\n' "$line" | grep -F '2 give neither a prd: nor a prd_reason' >/dev/null \
    || cf "the two bare cards were not counted as 2 giving neither: ${line:-none}"
  printf '%s\n' "$out" | grep -E "⚠ 2 landed issue\(s\) name no PRD and give no reason: .*972-bare-blank.*973-bare-none|⚠ 2 landed issue\(s\) name no PRD and give no reason: .*973-bare-none.*972-bare-blank" >/dev/null \
    || cf "the two bare cards were not named: $(printf '%s\n' "$out" | grep 'name no PRD')"
  printf '%s\n' "$out" | grep 'name no PRD' | grep -E '971-covered|974-reasoned' >/dev/null \
    && cf "a PRD-covered card or a reasoned one was named as bare: $(printf '%s\n' "$out" | grep 'name no PRD')"
  printf '%s\n' "$out" | grep '^── board-drift: clean ✓' >/dev/null \
    || cf "the arm moved the verdict (reports only): $(printf '%s\n' "$out" | grep '^── board-drift:')"
  finish "check-board arm [m]: a landed card with neither a PRD nor a prd_reason is counted and named, a PRD-covered card and a reasoned one are not, and the verdict does not move"
  teardown
}

# =============================================================================
# CASE — arm [g] flags a TEST_GLOBS entry that matches no file.
#
# The consumers (the ablation rule) match each entry with `case` against repository paths; an
# entry nothing matches enforces nothing. One live entry and one dead one: the dead one is
# named, the live one is not; with only the live one the line reads clean.
# =============================================================================
case_check_board_fill_arm_flags_a_test_glob_that_matches_no_file() {
  cf_reset
  make_sandbox
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  _cb_g_fill_glob_array CODE_GLOBS '  # DECLARED EMPTY -- fixture (CODE_GLOBS).'
  mkdir -p "$SB_WORK/tests"
  printf '# a test\n' > "$SB_WORK/tests/a.test.sh"
  _cb_g_fill_glob_array TEST_GLOBS '  "tests/*"'
  _cb_g_fill_glob_array TEST_GLOBS '  "nothing-matches-this/*"'
  publish_sandbox
  local out line
  out="$(cb_run)"
  line="$(printf '%s\n' "$out" | _cb_g_section | grep 'scripts/config.sh TEST_GLOBS' || true)"
  printf '%s\n' "$line" | grep -F 'match no file' >/dev/null \
    || cf "a TEST_GLOBS entry matching no file was not flagged: ${line:-no TEST_GLOBS line}"
  printf '%s\n' "$line" | grep -F 'nothing-matches-this/*' >/dev/null \
    || cf "the dead entry was not named: $line"
  printf '%s\n' "$line" | grep -E 'match no file.*⚠ [^—]*tests/\*' >/dev/null \
    && cf "the live entry tests/* was named as matching nothing: $line"
  teardown

  # CONTROL: only the live entry — the same line reads clean, so the arm is not always-warn.
  # No cf_reset: the first half's findings must reach the one finish below.
  make_sandbox
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  _cb_g_fill_glob_array CODE_GLOBS '  # DECLARED EMPTY -- fixture (CODE_GLOBS).'
  mkdir -p "$SB_WORK/tests"; printf '# a test\n' > "$SB_WORK/tests/a.test.sh"
  _cb_g_fill_glob_array TEST_GLOBS '  "tests/*"'
  publish_sandbox
  out="$(cb_run)"
  line="$(printf '%s\n' "$out" | _cb_g_section | grep 'scripts/config.sh TEST_GLOBS' || true)"
  printf '%s\n' "$line" | grep -F 'declares 1 entry/entries  ✓' >/dev/null \
    || cf "(control) a TEST_GLOBS whose only entry matches a tracked file did not read clean: ${line:-none}"

  teardown

  # NOT A GATE ON DAY ONE: an otherwise-finished tree whose only TEST_GLOBS entry matches no file
  # (a greenfield project has no test yet) still reads graduation COMPLETE, with the line visible.
  make_sandbox
  printf '# my project\n' > "$SB_WORK/AGENTS.md"
  printf '# my project\n' > "$SB_WORK/README.md"
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  _cb_g_fill_glob_array CODE_GLOBS '  # DECLARED EMPTY -- fixture (CODE_GLOBS).'
  _cb_g_fill_glob_array TEST_GLOBS '  "tests/*"'
  _cb_g_discharge_delete_if_unused
  _cb_g_discharge_gitignore_env
  _cb_g_land_day_one_work
  _cb_fill_sheet "<!-- $KIT_FILL_DISPOSITION — synthetic fill sheet. -->" "$_cb_fill_usage"
  printf '%s\n' "$_cb_fill_out" | grep 'TEST_GLOBS.*match no file' >/dev/null \
    || cf "(day one) the dead TEST_GLOBS entry was not reported on a finished tree: $_cb_fill_out"
  printf '%s\n' "$_cb_fill_out" | grep 'graduation COMPLETE' >/dev/null \
    || cf "(day one) a TEST_GLOBS entry with no file yet held graduation back — the report must not wait for a first test: $_cb_fill_out"

  finish "check-board arm [g]: a TEST_GLOBS entry that matches no file is named, a live one is not, a TEST_GLOBS whose entries all match reads clean, and a dead entry on an otherwise-finished tree is reported without holding graduation COMPLETE back"
  teardown
}

# =============================================================================
# CASE — arm [c] reports a last progress.md touch that predates the last CODE commit.
#
# "Code" is CODE_GLOBS (the code-vs-metadata rule's one definition), so a board move and a
# register edit made after the last progress.md touch do NOT count; a commit under a code glob
# does. The fixture follows the workflow's order: the session writes its entry and publishes,
# a code commit lands on the trunk, then metadata moves, then the entry is written.
# =============================================================================
case_check_board_progress_trails_the_last_code_commit() {
  cf_reset
  make_sandbox
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  _cb_g_fill_glob_array CODE_GLOBS '  "src/*"'
  _cb_g_fill_glob_array TEST_GLOBS '  # DECLARED EMPTY -- fixture (TEST_GLOBS).'
  mkdir -p "$SB_WORK/src"
  printf 'v1\n' > "$SB_WORK/src/app.sh"
  printf '# progress.md\n\n## Log\n\n### 2026-01-01 [Dev] first session\n\n- built v1\n' > "$SB_WORK/progress.md"
  publish_sandbox
  local out line
  _l() { printf '%s\n' "$1" | grep '^\[c\] progress.md LAST ENTRY' || true; }

  # (a) the entry and the code share a commit: nothing after it.
  out="$(cb_run)"; line="$(_l "$out")"
  printf '%s\n' "$line" | grep -F '0 of 0 commit(s)' >/dev/null && printf '%s\n' "$line" | grep -F '✓' >/dev/null \
    || cf "(a) an entry written with the code was not read clean, with its population: ${line:-no LAST ENTRY line}"

  # (b) a code commit lands on the trunk after the entry.
  printf 'v2\n' > "$SB_WORK/src/app.sh"
  git -C "$SB_WORK" add src/app.sh >/dev/null 2>&1
  sbcommit -m "[Dev] XYZ-901: change app" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push origin "$SB_TRUNK" --quiet >/dev/null 2>&1
  out="$(cb_run)"; line="$(_l "$out")"
  printf '%s\n' "$line" | grep -F '1 of 1 commit(s)' >/dev/null && printf '%s\n' "$line" | grep -F '⚠' >/dev/null \
    || cf "(b) a code commit after the last progress.md touch was not reported: ${line:-no LAST ENTRY line}"
  printf '%s\n' "$line" | grep -F 'XYZ-901: change app' >/dev/null \
    || cf "(b) the newest code commit was not named: $line"
  printf '%s\n' "$out" | grep '^── board-drift: clean ✓' >/dev/null \
    || cf "(b) the report moved the verdict (reports only): $(printf '%s\n' "$out" | grep '^── board-drift:')"

  # (c) metadata commits after it do not change the count: a board move and a register edit.
  seed_issue todo "$SB_PREFIX-902" meta chore "Board move"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[PM] XYZ-902: file the card" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" mv "progress/todo/$SB_PREFIX-902-meta.md" "progress/in_progress/$SB_PREFIX-902-meta.md" >/dev/null 2>&1
  sbcommit -m "[Dev] XYZ-902 -> in_progress" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push origin "$SB_TRUNK" --quiet >/dev/null 2>&1
  out="$(cb_run)"; line="$(_l "$out")"
  printf '%s\n' "$line" | grep -F '1 of 3 commit(s)' >/dev/null \
    || cf "(c) board moves were counted as code, or the span was not printed: ${line:-no LAST ENTRY line}"

  # (d) the entry is written after the code: clean again.
  printf '\n### 2026-01-02 [Dev] second session\n\n- built v2\n' >> "$SB_WORK/progress.md"
  git -C "$SB_WORK" add progress.md >/dev/null 2>&1
  sbcommit -m "[Dev] progress: second session" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push origin "$SB_TRUNK" --quiet >/dev/null 2>&1
  out="$(cb_run)"; line="$(_l "$out")"
  printf '%s\n' "$line" | grep -F '0 of 0 commit(s)' >/dev/null && printf '%s\n' "$line" | grep -F '✓' >/dev/null \
    || cf "(d) an entry written after the code did not read clean: ${line:-no LAST ENTRY line}"
  teardown

  # (e) CODE_GLOBS undeclared: the check says it did not run, and does not read as a pass.
  make_sandbox
  printf '# progress.md\n\n## Log\n\n### 2026-01-01 [Dev] first session\n\n- x\n' > "$SB_WORK/progress.md"
  publish_sandbox
  out="$(cb_run)"; line="$(_l "$out")"
  printf '%s\n' "$line" | grep -F 'THIS CHECK DID NOT RUN' >/dev/null \
    || cf "(e) an undeclared CODE_GLOBS was not reported as not run: ${line:-no LAST ENTRY line}"
  printf '%s\n' "$line" | grep -F '✓' >/dev/null \
    && cf "(e) an undeclared CODE_GLOBS read as a pass: $line"
  finish "check-board arm [c]: a progress.md last touched before a CODE_GLOBS commit is reported with its population, board moves do not count, an entry written after clears it, and an undeclared CODE_GLOBS says the check did not run"
  teardown
}

# =============================================================================
# CASE — arm [f] reports a remote branch named for a card that has landed.
#
# Order as the roles do it: the card is minted, its branch is cut and pushed, then the card
# moves; the branch is left behind (a re-cut, or a landing that died before its delete). A card
# still open keeps its branch unflagged; deleting the stale branch clears the line.
# =============================================================================
case_check_board_reports_a_remote_branch_left_by_a_landed_card() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-911" recut chore "Recut"
  seed_issue todo "$SB_PREFIX-912" live chore "Still open"
  seed_issue todo "$SB_PREFIX-913" qa chore "Landed to qa_complete"
  publish_sandbox
  seed_branch "$SB_PREFIX-911" recut m911
  seed_branch "$SB_PREFIX-912" live m912
  seed_branch "$SB_PREFIX-913" qa m913
  git -C "$SB_WORK" mv "progress/todo/$SB_PREFIX-911-recut.md" "progress/done/$SB_PREFIX-911-recut.md" >/dev/null 2>&1
  git -C "$SB_WORK" mv "progress/todo/$SB_PREFIX-913-qa.md" "progress/qa_complete/$SB_PREFIX-913-qa.md" >/dev/null 2>&1
  sbcommit -m "[QA] board: 911 and 913 landed" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push origin "$SB_TRUNK" --quiet >/dev/null 2>&1
  local out sec
  _sec() { printf '%s\n' "$1" | awk '/^\[f\] remote branches/ { f = 1; print; next } f && /^\[[a-z]\]/ { exit } f && /^──/ { exit } f'; }
  out="$(cb_run)"; sec="$(_sec "$out")"
  printf '%s\n' "$sec" | grep -F "feature/$SB_PREFIX-911-recut" >/dev/null \
    || cf "(a) a branch for a card in done/ was not named: ${sec:-no section}"
  printf '%s\n' "$sec" | grep -F "feature/$SB_PREFIX-913-qa" >/dev/null \
    || cf "(a) a branch for a card in qa_complete/ was not named: $sec"
  printf '%s\n' "$sec" | grep -F "feature/$SB_PREFIX-912-live" >/dev/null \
    && cf "(a) the branch of a card still open was named: $sec"
  printf '%s\n' "$sec" | grep -F '4 read, 3 named for a card' >/dev/null \
    || cf "(a) the population was not printed (4 branches read incl. the trunk, 3 named for a card): $sec"
  printf '%s\n' "$sec" | grep -F 'reports only' >/dev/null \
    || cf "(a) the section's header does not declare itself advisory (reports only): $(printf '%s\n' "$sec" | head -1)"

  # (b) the stale branches deleted: the same section reads clean, with its population.
  git -C "$SB_WORK" push origin --delete "feature/$SB_PREFIX-911-recut" "feature/$SB_PREFIX-913-qa" --quiet >/dev/null 2>&1
  out="$(cb_run)"; sec="$(_sec "$out")"
  printf '%s\n' "$sec" | grep -F '2 read, 1 named for a card, none for a card in done/' >/dev/null \
    || cf "(b) with the stale branches deleted the section did not read clean with its population: ${sec:-no section}"
  finish "check-board arm [f]: a remote branch named for a card in done/ or qa_complete/ is named with its population, a branch of an open card is not, the verdict does not move, and deleting the stale branch clears it"
  teardown
}

# =============================================================================
# CASE — arm [f] reports a linked worktree whose card has landed, and never removes one.
#
# The population is `git worktree list` minus the main checkout and the standing kanban worktree.
# A worktree's card is read off its branch (`<kind>/<card>-<slug>`), or, when it is detached, off its
# directory's name. One for a card in done/ or qa_complete/ is named with its state, clean or holding
# changes, so a reader can tell a removable one from one that carries unsaved work; one for an open
# card is not named; removing the worktree clears the line, and the verdict never moves.
# =============================================================================
case_check_board_reports_a_worktree_left_by_a_landed_card() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-941" gone chore "Landed, clean worktree"
  seed_issue todo "$SB_PREFIX-942" live chore "Still open"
  seed_issue todo "$SB_PREFIX-943" qa chore "Landed to qa_complete, detached, dirty"
  publish_sandbox
  local wt="$SB_TMP/wts"
  mkdir -p "$wt"
  git -C "$SB_WORK" worktree add -q -b "feature/$SB_PREFIX-941-gone" "$wt/feature-$SB_PREFIX-941-gone" "$SB_TRUNK" >/dev/null 2>&1 \
    || _control_did_not_run "add a worktree on a branch of the landed card"
  git -C "$SB_WORK" worktree add -q -b "feature/$SB_PREFIX-942-live" "$wt/live" "$SB_TRUNK" >/dev/null 2>&1 \
    || _control_did_not_run "add a worktree on a branch of the open card"
  git -C "$SB_WORK" worktree add -q --detach "$wt/$SB_PREFIX-943-qa" "$SB_TRUNK" >/dev/null 2>&1 \
    || _control_did_not_run "add a detached worktree named for the qa_complete card"
  printf 'unsaved work\n' > "$wt/$SB_PREFIX-943-qa/untracked-notes.txt"
  git -C "$SB_WORK" mv "progress/todo/$SB_PREFIX-941-gone.md" "progress/done/$SB_PREFIX-941-gone.md" >/dev/null 2>&1
  git -C "$SB_WORK" mv "progress/todo/$SB_PREFIX-943-qa.md" "progress/qa_complete/$SB_PREFIX-943-qa.md" >/dev/null 2>&1
  sbcommit -m "[QA] board: 941 and 943 landed" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push origin "$SB_TRUNK" --quiet >/dev/null 2>&1
  local out sec verdict0 verdict1
  _sec() { printf '%s\n' "$1" | awk '/^\[f\] remote branches/ { f = 1; print; next } f && /^\[[a-z]\]/ { exit } f && /^──/ { exit } f'; }
  out="$(cb_run)"; sec="$(_sec "$out")"; verdict0="$(printf '%s\n' "$out" | grep '^── board-drift:')"
  printf '%s\n' "$sec" | grep -F '[f4]' >/dev/null || cf "(a) the section has no [f4] worktree line: ${sec:-no section}"
  printf '%s\n' "$sec" | grep -F "$wt/feature-$SB_PREFIX-941-gone" >/dev/null \
    || cf "(a) the worktree on a branch of a card in done/ was not named: $sec"
  printf '%s\n' "$sec" | grep -F "$wt/$SB_PREFIX-943-qa" >/dev/null \
    || cf "(a) the detached worktree named for a card in qa_complete/ was not named: $sec"
  printf '%s\n' "$sec" | grep -F "$wt/live" >/dev/null \
    && cf "(a) the worktree of a card still open was named: $sec"
  printf '%s\n' "$sec" | grep -F '3 read, 3 named for a card' >/dev/null \
    || cf "(a) the population was not printed (3 linked worktrees read, 3 named for a card): $sec"
  printf '%s\n' "$sec" | grep -F 'git worktree remove' >/dev/null \
    || cf "(a) the line does not name the command that removes one: $sec"
  printf '%s\n' "$sec" | grep -F "$wt/feature-$SB_PREFIX-941-gone (feature/$SB_PREFIX-941-gone; clean)" >/dev/null \
    || cf "(a) the clean worktree is not marked clean beside its branch: $sec"
  printf '%s\n' "$sec" | grep -F "$wt/$SB_PREFIX-943-qa (detached; 1 path(s) with uncommitted or untracked changes)" >/dev/null \
    || cf "(a) the detached worktree holding an untracked file is not marked as holding 1 changed path: $sec"
  [ -e "$wt/$SB_PREFIX-943-qa/untracked-notes.txt" ] || cf "(a) the report removed a worktree's untracked file"
  [ -d "$wt/feature-$SB_PREFIX-941-gone" ] || cf "(a) the report removed a worktree"
  printf '%s\n' "$sec" | grep -F 'reports only' >/dev/null \
    || cf "(a) the section's header does not declare itself advisory (reports only): $(printf '%s\n' "$sec" | head -1)"
  printf '%s\n' "$sec" | head -1 | grep -F 'worktrees' >/dev/null \
    || cf "(a) the section's header does not name the worktrees it now lists: $(printf '%s\n' "$sec" | head -1)"

  # (b) the two landed cards' worktrees removed: the line reads clean, with its population.
  git -C "$SB_WORK" worktree remove "$wt/feature-$SB_PREFIX-941-gone" >/dev/null 2>&1
  git -C "$SB_WORK" worktree remove --force "$wt/$SB_PREFIX-943-qa" >/dev/null 2>&1
  out="$(cb_run)"; sec="$(_sec "$out")"; verdict1="$(printf '%s\n' "$out" | grep '^── board-drift:')"
  printf '%s\n' "$sec" | grep -F '1 read, 1 named for a card, none for a card in done/' >/dev/null \
    || cf "(b) with the landed cards' worktrees removed the line did not read clean with its population: ${sec:-no section}"
  [ "$verdict0" = "$verdict1" ] || cf "(b) the report moved the verdict: '$verdict0' then '$verdict1'"
  finish "check-board arm [f]: a linked worktree whose card is in done/ or qa_complete/ is named with its population and whether it holds changes, a worktree of an open card is not, nothing is removed, the verdict does not move, and removing the worktree clears the line"
  teardown
}

# =============================================================================
# CASE — arm [g] reports a declared TEST_GLOBS that does not cover scripts/test/**.
#
# The population is the shipped scripts/test/ tree itself, copied into the sandbox, and its file
# count is read from the SHIPPED tree before the copy — never from what the sandbox holds.
# =============================================================================
case_check_board_fill_arm_reports_test_globs_missing_the_kits_own_tests() {
  cf_reset
  local n_shipped=0 _f
  for _f in $(cd "$REAL_SCRIPTS/test" && find . -type f | sed 's|^\./||'); do n_shipped=$((n_shipped+1)); done
  [ "$n_shipped" -gt 0 ] || { _control_did_not_run "read the shipped scripts/test/ population"; finish "check-board arm [g]: TEST_GLOBS vs scripts/test/**"; return; }
  local out line
  _l() { printf '%s\n' "$1" | _cb_g_section | grep 'TEST_GLOBS vs scripts/test' || true; }

  # (a) a literal fill that misses it: reported, naming a file and the population.
  make_sandbox
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  _cb_g_fill_glob_array CODE_GLOBS '  # DECLARED EMPTY -- fixture (CODE_GLOBS).'
  _cb_g_fill_glob_array TEST_GLOBS '  "test/*"'
  cp -R "$REAL_SCRIPTS/test" "$SB_WORK/scripts/test"
  mkdir -p "$SB_WORK/test"; printf '# t\n' > "$SB_WORK/test/a.sh"
  publish_sandbox
  out="$(cb_run)"; line="$(_l "$out")"
  printf '%s\n' "$line" | grep -F "$n_shipped of $n_shipped file(s) under scripts/test/ are covered by no declared entry" >/dev/null \
    && printf '%s\n' "$line" | grep -F '⚠' >/dev/null \
    || cf "(a) test/* was not reported as missing scripts/test/** with its population ($n_shipped): ${line:-no coverage line}"
  printf '%s\n' "$line" | grep -F "the kit's own self-test, not your tests" >/dev/null \
    && printf '%s\n' "$line" | grep -F 'Next: add "scripts/test/*"' >/dev/null \
    || cf "(a) the coverage line does not say what it means and what to do next: ${line:-no coverage line}"
  printf '%s\n' "$out" | grep '^── board-drift: clean ✓' >/dev/null \
    || cf "(a) the report moved the verdict: $(printf '%s\n' "$out" | grep '^── board-drift:')"
  teardown

  # (b) the same fill plus "scripts/test/*": covered, ✓.
  make_sandbox
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  _cb_g_fill_glob_array CODE_GLOBS '  # DECLARED EMPTY -- fixture (CODE_GLOBS).'
  _cb_g_fill_glob_array TEST_GLOBS '  "test/*"'
  _cb_g_fill_glob_array TEST_GLOBS '  "scripts/test/*"'
  cp -R "$REAL_SCRIPTS/test" "$SB_WORK/scripts/test"
  publish_sandbox
  out="$(cb_run)"; line="$(_l "$out")"
  printf '%s\n' "$line" | grep -F "all $n_shipped file(s) under scripts/test/ are covered" >/dev/null \
    && printf '%s\n' "$line" | grep -F '✓' >/dev/null \
    || cf "(b) scripts/test/* in TEST_GLOBS was not read as covering the kit's own tests: ${line:-no coverage line}"
  printf '%s\n' "$out" | grep '^── board-drift: clean ✓' >/dev/null \
    || cf "(b) the report moved the verdict: $(printf '%s\n' "$out" | grep '^── board-drift:')"
  finish "check-board arm [g]: a declared TEST_GLOBS that misses scripts/test/** is reported with the shipped population, one that covers it reads clean, and the verdict does not move"
  teardown
}

# =============================================================================
# CASE — arm [g] reports `hooks: off` while .claude/settings.json is absent, and says nothing once
# it exists. A report line only: the verdict lines are the same in both runs.
# =============================================================================
case_check_board_graduation_reports_hooks_off() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-431" hookswatch chore "Hooks watch"
  publish_sandbox

  local off on
  rm -f "$SB_WORK/.claude/settings.json"
  off="$(cb_run | _cb_g_section)"
  printf '%s\n' "$off" | grep 'enabled by:' >/dev/null || cf "(precondition) the arm is not enabled, so the report line could not be judged: $off"
  printf '%s\n' "$off" | grep -F 'hooks: off (`.claude/settings.json` absent)' >/dev/null \
    || cf "with .claude/settings.json absent the arm did not print the hooks-off line: $off"

  # The arm reads the trunk's copy, so the file is committed and pushed as kit-init does.
  mkdir -p "$SB_WORK/.claude"; printf '{}\n' > "$SB_WORK/.claude/settings.json"
  git -C "$SB_WORK" add .claude/settings.json >/dev/null 2>&1
  sbcommit -m "[PM] turn the hooks on" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push origin "$SB_TRUNK" >/dev/null 2>&1
  on="$(cb_run | _cb_g_section)"
  printf '%s\n' "$on" | grep 'enabled by:' >/dev/null || cf "(precondition) the arm is not enabled once the file exists: $on"
  printf '%s\n' "$on" | grep 'hooks: off' >/dev/null && cf "the arm printed hooks: off with .claude/settings.json present: $on"
  # Not a finding: the same lines minus the report line.
  # (the trunk's short sha in each "read from:" label moved with the commit above, so it is masked)
  [ "$(printf '%s\n' "$off" | grep -v 'hooks: off' | sed -E 's/@ [0-9a-f]{7,}/@ SHA/g')" = "$(printf '%s\n' "$on" | grep -v 'hooks: off' | sed -E 's/@ [0-9a-f]{7,}/@ SHA/g')" ] \
    || cf "the hooks-off report changed another line of the arm (it must be a report, not a verdict input)"

  finish "arm [g] prints 'hooks: off (.claude/settings.json absent)' when the file is absent and not when it is present, and the rest of the arm is identical in both runs"
  teardown
}

# =============================================================================
# CASE — arm [g] READS core.hooksPATH BACK. A clone has no core.hooksPath (.git/config is never
# committed), so the commit guard is not live there; the arm must say so with the act that wires it, and
# the `hooks: off` line must not claim the guard runs. The control is the wired sandbox: a ✓ line and the
# old claim. Fixture order follows the real one: a clone of the pushed trunk, the check, then setup.sh,
# then the check again.
# =============================================================================
case_check_board_graduation_reads_the_hooks_path_back() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-433" hookspath chore "Hooks path"
  rm -f "$SB_WORK/.claude/settings.json"
  publish_sandbox

  local wired clone clonereport hp
  # CONTROL: the sandbox wires its own core.hooksPath, so the guard runs and the line says so.
  wired="$(cb_run | _cb_g_section)"
  printf '%s\n' "$wired" | grep 'enabled by:' >/dev/null || _fixture_die "the wired sandbox's arm [g] is not enabled, so the hooks line could not be judged: $wired"
  printf '%s\n' "$wired" | grep -E 'git hooks: core.hooksPath = .*scripts/githooks  ✓' >/dev/null \
    || cf "(control) the wired sandbox did not report core.hooksPath read back as scripts/githooks: $wired"
  printf '%s\n' "$wired" | grep -F 'the git commit guard still does' >/dev/null \
    || cf "(control) the wired sandbox's hooks: off line lost its 'the git commit guard still does' clause: $wired"

  # THE CLONE: the pushed trunk cloned, which carries no .git/config of the sandbox.
  clone="$SB_TMP/fresh-clone"
  git clone -q "$SB_ORIGIN" "$clone" >/dev/null 2>&1 || _fixture_die "the clone of the sandbox's remote failed"
  hp="$(git -C "$clone" config --get core.hooksPath || true)"
  [ -z "$hp" ] || _fixture_die "the fresh clone already has core.hooksPath=$hp, so the unwired case could not be built"
  clonereport="$( cd "$clone" && env -u CLAUDE_PROJECT_DIR ./scripts/check-board.sh --full 2>&1 | _cb_g_section )"
  printf '%s\n' "$clonereport" | grep 'enabled by:' >/dev/null || _fixture_die "the clone's arm [g] is not enabled, so the hooks line could not be judged: $clonereport"
  printf '%s\n' "$clonereport" | grep -F 'git hooks: core.hooksPath is unset, not scripts/githooks  ⚠' >/dev/null \
    || cf "(clone) arm [g] did not report the unset core.hooksPath as a ⚠ line: $clonereport"
  printf '%s\n' "$clonereport" | grep -F 'Next: ./setup.sh --kit-only' >/dev/null \
    || cf "(clone) the hooks line names no Next: act: $clonereport"
  printf '%s\n' "$clonereport" | grep -F 'the git commit guard still does' >/dev/null \
    && cf "(clone) the hooks: off line claims the commit guard runs while core.hooksPath is unset: $clonereport"
  printf '%s\n' "$clonereport" | grep -F 'hooks: off' >/dev/null \
    || cf "(clone) the hooks: off line is gone: $clonereport"

  # THE NAMED ACT: setup.sh --kit-only wires it, and the arm then reads it back.
  ( cd "$clone" && ./setup.sh --kit-only ) >/dev/null 2>&1 || true
  hp="$(git -C "$clone" config --get core.hooksPath || true)"
  [ "$hp" = "scripts/githooks" ] || cf "(act) ./setup.sh --kit-only left core.hooksPath at '${hp:-unset}', so the Next: it is named for does not work"
  clonereport="$( cd "$clone" && env -u CLAUDE_PROJECT_DIR ./scripts/check-board.sh --full 2>&1 | _cb_g_section )"
  printf '%s\n' "$clonereport" | grep -F 'git hooks: core.hooksPath = scripts/githooks  ✓' >/dev/null \
    || cf "(after the act) the arm did not read the wired core.hooksPath back: $clonereport"

  finish "arm [g] reads core.hooksPath back: a wired project prints a ✓ line and keeps 'the git commit guard still does'; a clone with none prints a ⚠ line naming ./setup.sh --kit-only and drops the claim; running that act turns it to ✓"
  teardown
}

# =============================================================================
# CASE — A DECIDED ABSENCE HAS ONE CHEAP ANSWER, THE SAME WORDS EVERYWHERE: `DECLARED NONE`.
# A glob no file matches and a model-table row left `<fill in>` each warn on every run until answered.
# The answer is the marker: a trailing `# DECLARED NONE` comment on the glob's own line, `DECLARED NONE`
# anywhere in the row. A row or glob nobody answered still warns (the control at each place), a glob
# marked DECLARED NONE that matches a file is a finding, and none of it moves the verdict. A
# DELETE-IF-UNUSED member is NOT answered by it: a member with no use is deleted, and [g] says so.
# =============================================================================
case_check_board_declared_none_answers_one_member_one_glob_one_row() {
  cf_reset
  make_sandbox
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  _cb_g_fill_glob_array CODE_GLOBS '  # DECLARED EMPTY -- fixture (CODE_GLOBS).'
  mkdir -p "$SB_WORK/tests"; printf '# a test\n' > "$SB_WORK/tests/a.test.sh"
  _cb_g_fill_glob_array TEST_GLOBS '  "tests/*"'
  _cb_g_fill_glob_array TEST_GLOBS '  "gone-a/*"  # DECLARED NONE -- this path was abandoned.'
  _cb_g_fill_glob_array TEST_GLOBS '  "gone-b/*"'
  publish_sandbox
  local out line v_plain

  # ── TEST_GLOBS: the marked dead glob is not named, the unmarked one is. ─────────────────────
  out="$(cb_run)"
  line="$(printf '%s\n' "$out" | _cb_g_section | grep 'scripts/config.sh TEST_GLOBS' | grep -v 'vs scripts/test' || true)"
  printf '%s\n' "$line" | grep -F 'gone-b/*' >/dev/null \
    || cf "(glob) an unmarked dead TEST_GLOBS entry was not named: ${line:-no TEST_GLOBS line}"
  printf '%s\n' "$line" | grep -F 'gone-a/*' >/dev/null \
    && cf "(glob) a dead TEST_GLOBS entry carrying '# DECLARED NONE' was still named as matching no file: $line"
  v_plain="$(printf '%s\n' "$out" | grep '^── board-drift')"

  # Every dead entry answered: the line reads clean, and the verdict is what it was.
  perl -i -pe 's|^  "gone-b/\*"$|  "gone-b/*"  # DECLARED NONE -- no second tree.|' "$SB_WORK/scripts/config.sh"
  grep -F '"gone-b/*"  # DECLARED NONE' "$SB_WORK/scripts/config.sh" >/dev/null \
    || _fixture_die "the second glob's marker was not written to the sandbox's config.sh"
  publish_sandbox
  out="$(cb_run)"
  line="$(printf '%s\n' "$out" | _cb_g_section | grep 'scripts/config.sh TEST_GLOBS' | grep -v 'vs scripts/test' || true)"
  printf '%s\n' "$line" | grep -F '⚠' >/dev/null \
    && cf "(glob) every dead entry carries '# DECLARED NONE' and the line still warns: $line"
  printf '%s\n' "$line" | grep -F 'declares' >/dev/null \
    || cf "(glob) the marked entries left no line a reader can see: ${line:-no TEST_GLOBS line}"
  [ "$(printf '%s\n' "$out" | grep '^── board-drift')" = "$v_plain" ] \
    || cf "(glob) a declared-none glob moved the verdict"

  # ── DELETE-IF-UNUSED: DECLARED NONE is NOT an answer for a member — one with no use is deleted. ──
  local f
  f="$(_cb_g_a_declaring_file)"
  if [ -n "$f" ]; then
    _cb_g_discharge_delete_if_unused
    grep -vF -- "- **\`$f\` (DELETE-IF-UNUSED) kept, on purpose.**" "$SB_WORK/process/LOCAL-PROCEDURES.md" > "$SB_WORK/process/LP.new" \
      && mv "$SB_WORK/process/LP.new" "$SB_WORK/process/LOCAL-PROCEDURES.md"
    printf -- '- **`%s` (DELETE-IF-UNUSED) DECLARED NONE -- no use for it here.**\n' "$f" >> "$SB_WORK/process/LOCAL-PROCEDURES.md"
    publish_sandbox
    out="$(cb_run)"
    printf '%s\n' "$out" | _cb_g_section | grep 'DELETE-IF-UNUSED:.*no recorded decision' | grep -F "$f" >/dev/null \
      || cf "(member) a member whose line says DECLARED NONE was counted as decided: $(printf '%s\n' "$out" | _cb_g_section | grep 'DELETE-IF-UNUSED')"
    printf '%s\n' "$out" | _cb_g_section | grep 'DELETE-IF-UNUSED:' | grep -F 'a member with no use is deleted' >/dev/null \
      || cf "(member) the finding does not say the answer for a member with no use is deleting it: $(printf '%s\n' "$out" | _cb_g_section | grep 'DELETE-IF-UNUSED')"
    # The kept-on-purpose line is still the answer.
    printf -- '- **`%s` (DELETE-IF-UNUSED) kept, on purpose.** a reason\n' "$f" >> "$SB_WORK/process/LOCAL-PROCEDURES.md"
    publish_sandbox
    out="$(cb_run)"
    printf '%s\n' "$out" | _cb_g_section | grep 'DELETE-IF-UNUSED:.*no recorded decision' | grep -F "$f" >/dev/null \
      && cf "(member) the kept-on-purpose line no longer discharges the member"
  fi

  # ── A glob marked DECLARED NONE that matches a file is a finding, not an answer. ────────────
  mkdir -p "$SB_WORK/live"; printf 'x\n' > "$SB_WORK/live/a.test.sh"
  _cb_g_fill_glob_array TEST_GLOBS '  "live/*"  # DECLARED NONE -- flaky, switched off.'
  publish_sandbox
  out="$(cb_run)"
  line="$(printf '%s\n' "$out" | _cb_g_section | grep 'scripts/config.sh TEST_GLOBS' | grep 'marked' | grep 'matching a file' || true)"
  [ -n "$line" ] || cf "(live) a '# DECLARED NONE' glob that matches a file raised no finding: $(printf '%s\n' "$out" | _cb_g_section | grep 'scripts/config.sh TEST_GLOBS')"
  printf '%s\n' "$line" | grep -F '⚠' | grep -F 'live/*' | grep -F 'Next: remove the marker, or remove the files' >/dev/null \
    || cf "(live) the finding is not a ⚠ naming the glob and a Next: $line"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    && cf "(live) graduation reads COMPLETE over a glob marked DECLARED NONE that matches a file"
  printf '%s\n' "$out" | _cb_g_section | grep 'scripts/config.sh TEST_GLOBS' | grep -F 'which no file is asked to match' >/dev/null \
    && cf "(live) the TEST_GLOBS line says no file is asked to match a marked entry on the same report that finds one that matches"
  # Every entry marked, one of them matching a file: no line calls the array answered.
  perl -i -ne 'print unless /^  "tests\/\*"$/' "$SB_WORK/scripts/config.sh"
  grep -E '^  "tests/\*"$' "$SB_WORK/scripts/config.sh" >/dev/null && _fixture_die "the unmarked TEST_GLOBS entry was not removed from the sandbox's config.sh"
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'scripts/config.sh TEST_GLOBS' | grep -F 'every one of its' >/dev/null \
    && cf "(live) a ✓ line calls an array answered while one of its marked entries matches a file: $(printf '%s\n' "$out" | _cb_g_section | grep 'scripts/config.sh TEST_GLOBS')"
  printf '%s\n' "$out" | _cb_g_section | grep 'scripts/config.sh TEST_GLOBS' | grep -F 'matching a file' | grep -F '⚠' >/dev/null \
    || cf "(live) the finding is gone once every entry is marked"

  # ── Model-table rows: the marker anywhere in the row answers it; an unanswered row warns. ───
  local ad orch src d rd role n_all n_marked
  read -r ad orch <<<"$(_seed_provisioning_sandbox)"
  src=""
  for d in "$REAL_REPO_ROOT/_claude" "$REAL_REPO_ROOT/.claude"; do [ -d "$d/roles" ] && src="$d"; done
  if [ -z "$ad" ] || [ -z "$src" ]; then
    skp "check-board declared-none (model rows)" "no .claude/agents + roles in the real tree"
  else
    for role in dev qa pm refactorer; do
      [ -f "$src/roles/$role.md" ] && cp "$src/roles/$role.md" "$SB_WORK/.claude/roles/$role.md"
    done
    _blank_rows() {  # <doc> — every row of the Model & effort section is left <fill in> in both cells
      awk '/^## /{ s = ($0 ~ /^## Model & effort contract/) }
        s && /^\|/ && /`/ { n = split($0, p, "|"); o = p[1]
          for (i = 2; i <= n; i++) { c = p[i]
            if (i >= 3 && i <= 4 && match(c, /`[^`]*`/)) c = substr(c, 1, RSTART - 1) "`<fill in>`" substr(c, RSTART + RLENGTH)
            o = o "|" c }
          print o; next }
        { print }' "$1" > "$1.new" && mv "$1.new" "$1"
    }
    _mark_first_row() {  # <doc> — the MODEL cell of the first unanswered data row becomes DECLARED NONE; its effort cell is left alone
      awk '/^## /{ s = ($0 ~ /^## Model & effort contract/) }
        s && !d && /^\|/ && /<fill in/ && !/DECLARED NONE/ { n = split($0, p, "|"); o = p[1]
          for (i = 2; i <= n; i++) { c = p[i]; if (i == 3) c = " DECLARED NONE "; o = o "|" c }
          print o; d = 1; next }
        { print }' "$1" > "$1.new" && mv "$1.new" "$1"
    }
    _unanswered() {  # <doc> — rows of the section still <fill in> and not marked
      awk '/^## /{ s = ($0 ~ /^## Model & effort contract/) } s && /^\|/ && /<fill in/ && !/DECLARED NONE/ { c++ } END { print c + 0 }' "$1"
    }
    _count() { printf '%s\n' "$1" | grep 'role-doc model row' | sed -n 's/^ *⚠ \([0-9]*\) role-doc.*/\1/p'; }
    for rd in "$SB_WORK"/.claude/roles/*.md; do [ "${rd##*/}" = orchestrator.md ] || _blank_rows "$rd"; done
    publish_sandbox
    out="$(cb_run)"; n_all="$(_count "$out")"
    [ -n "$n_all" ] && [ "$n_all" -gt 1 ] || _fixture_die "the blanked role docs print no usable role-doc count (got '${n_all:-none}')"
    _mark_first_row "$SB_WORK/.claude/roles/dev.md"
    grep -F 'DECLARED NONE' "$SB_WORK/.claude/roles/dev.md" >/dev/null || _fixture_die "the marker was not written to the sandbox's dev.md"
    publish_sandbox
    out="$(cb_run)"; n_marked="$(_count "$out")"
    [ "$n_marked" = "$((n_all - 1))" ] \
      || cf "(row) one row marked 'DECLARED NONE' in its model cell should leave $((n_all - 1)) blank row(s), the report counts '${n_marked:-none}'"
    # Every row of every hand-kept table answered: the line is gone and the verdict has not moved.
    for rd in "$SB_WORK"/.claude/roles/*.md; do
      [ "${rd##*/}" = orchestrator.md ] && continue
      while [ "$(_unanswered "$rd")" -gt 0 ]; do _mark_first_row "$rd"; done
    done
    publish_sandbox
    out="$(cb_run)"
    printf '%s\n' "$out" | grep 'role-doc model row' >/dev/null \
      && cf "(row) every hand-kept row answered with 'DECLARED NONE' and the report still counts blanks: $(printf '%s\n' "$out" | grep 'role-doc model row')"
    [ "$(printf '%s\n' "$out" | grep '^── board-drift')" = "$v_plain" ] \
      || cf "(row) declared-none rows moved the verdict"
  fi

  finish "check-board: 'DECLARED NONE' answers a TEST_GLOBS entry (trailing comment) and a model-table row (anywhere in it); an unanswered one at each place still warns; a glob marked DECLARED NONE that matches a file is a finding that holds graduation back; a DELETE-IF-UNUSED member marked DECLARED NONE is not decided and the finding says to delete it; the verdict is unmoved"
  teardown
}

# =============================================================================
# CASE — THE REPORT PRINTS ITS FINDINGS FIRST AND FOLDS THE ARMS THAT FOUND NOTHING INTO ONE LINE.
# The SessionStart hook cuts the report at a byte budget, so what comes first is what a session
# reads. Order and folding are the only change: the verdict line, every `⚠` line and every skipped
# or did-not-run line are exactly what `--full` prints, and `--full` is the unfolded, original-order
# report. Driven through the real script on a board with one planted finding (a duplicate id, arm
# [d]), then through the SessionStart hook and the two consumers that read the report's text.
# =============================================================================
CB_FOLD_LEAD='── no findings, folded'   # the one line's lead, shared with scripts/hooks/session-start.sh
case_check_board_report_prints_findings_first_and_folds_clean_arms() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-195" first-shape  bug   "Dev-filed bug"
  seed_issue done "$SB_PREFIX-195" second-shape spike "PM-minted spike"
  publish_sandbox
  # One commit nobody pushed: [f1] reports it with a ⚠ while the other [f] reading is clean.
  printf 'local only\n' > "$SB_WORK/unpublished.txt"
  git -C "$SB_WORK" add unpublished.txt >/dev/null 2>&1
  sbcommit -q -m "[PM] a commit nobody pushed" >/dev/null 2>&1
  local def full rc_def rc_full first_head fold n_def n_full tag miss
  def="$(cb_run_default)"; rc_def=$?
  full="$(cb_run)"; rc_full=$?
  [ "$rc_def" -eq 0 ] || cf "the default report exited $rc_def (exit 0 ALWAYS)"
  [ "$rc_full" -eq 0 ] || cf "'--full' exited $rc_full — an unknown option is a usage error, but the report's own option is not: $(printf '%s' "$full" | head -3 | tr '\n' '|')"
  printf '%s\n' "$full" | grep '^\[a\]' >/dev/null \
    || _fixture_die "'--full' prints no [a] heading, so the unfolded report was not obtained and every comparison below is about nothing"

  # (1) Findings first: the first arm heading is the arm that found something, not a clean one.
  first_head="$(printf '%s\n' "$def" | grep -m1 '^\[' || true)"
  case "$first_head" in
    '[d]'*) : ;;
    *) cf "(1) the default report opens its arms on '${first_head:-no heading}', not on arm [d], the one with the planted duplicate" ;;
  esac
  printf '%s\n' "$def" | grep -m1 '^\[k\]' >/dev/null \
    && cf "(1) arm [k], an advisory arm of the kit's own with no finding, still has its own heading in the default report"

  # (2) The clean arms are one line, which names each of them and says where the rest is.
  fold="$(printf '%s\n' "$def" | grep -F "$CB_FOLD_LEAD" || true)"
  [ -n "$fold" ] || cf "(2) no folded line beginning '$CB_FOLD_LEAD' in the default report"
  printf '%s\n' "$fold" | grep -F -- '--full' >/dev/null || cf "(2) the folded line does not say where the folded arms are: $fold"
  miss=""
  for tag in $(printf '%s\n' "$full" | grep -oE '^\[([a-z][0-9]*)\]' | sort -u); do
    printf '%s\n' "$def" | grep -F "$tag" >/dev/null || miss="$miss $tag"
  done
  [ -z "$miss" ] || cf "(2) arm(s)$miss appear in --full and are neither printed nor named in the default report"
  # (2b) No letter is both printed as an arm and listed as one that found nothing: [c] holds a
  # did-not-run reading beside two clean ones, so the clean ones are named by heading.
  for tag in $(printf '%s\n' "$fold" | grep -oE '\[[a-z][0-9]*\]' | sort -u); do
    if printf '%s\n' "$def" | awk -v t="$tag" 'index($0, t) == 1 { f = 1 } END { exit !f }'; then
      cf "(2b) $tag is printed as an arm above and listed as one that found nothing: $fold"
    fi
  done
  [ "$(printf '%s\n' "$def" | grep -c -F "$CB_FOLD_LEAD")" = 1 ] || cf "(2) the folded line is not exactly one line"
  # (2c) A label is never cut mid-word (a cut leaves a space before the closing bracket, or a bare article).
  printf '%s\n' "$fold" | grep -E ' \]| (a|an|the|of|by|and)\]' >/dev/null \
    && cf "(2c) a label on the folded line is cut mid-phrase: $fold"

  # (3) Nothing is lost: the verdict, every finding line and every did-not-run line are the same set.
  [ "$(printf '%s\n' "$def" | grep '^── board-drift')" = "$(printf '%s\n' "$full" | grep '^── board-drift')" ] \
    || cf "(3) the verdict line differs between the default report and --full"
  case "${def##*$'\n'}" in '── board-drift:'*) : ;; *) cf "(3) the default report does not end on the verdict line: ${def##*$'\n'}" ;; esac
  [ "$(printf '%s\n' "$def" | grep '⚠' | sort)" = "$(printf '%s\n' "$full" | grep '⚠' | sort)" ] \
    || cf "(3) the ⚠ lines of the default report are not the ⚠ lines of --full"
  [ "$(printf '%s\n' "$def" | grep -E 'DID NOT RUN|did not run|\(skipped' | sort)" = "$(printf '%s\n' "$full" | grep -E 'DID NOT RUN|did not run|\(skipped' | sort)" ] \
    || cf "(3) a check that did not run was folded away: its line is in --full and not in the default report"

  # (4) Findings before the arms that did not run, before the folded line, before the verdict.
  n_def="$(printf '%s\n' "$def" | grep -n -m1 '⚠' | cut -d: -f1)"
  n_full="$(printf '%s\n' "$def" | grep -n -m1 -E 'DID NOT RUN|did not run|\(skipped' | cut -d: -f1)"
  [ -z "$n_full" ] || [ "$n_def" -lt "$n_full" ] || cf "(4) a did-not-run line (line $n_full) comes before the first finding (line $n_def)"
  n_full="$(printf '%s\n' "$def" | grep -n -m1 -F "$CB_FOLD_LEAD" | cut -d: -f1)"
  [ -n "$n_full" ] && [ "$n_def" -lt "$n_full" ] || cf "(4) the folded line (line ${n_full:-none}) does not come after the first finding (line $n_def)"

  # (5) --full is the original order: the first arm heading is [a].
  case "$(printf '%s\n' "$full" | grep -m1 '^\[')" in '[a]'*) : ;; *) cf "(5) --full does not open on arm [a]" ;; esac

  # (5b) The fold's own rules, on canned reports: the real awk, fed text the real report cannot be made to
  # print (headings that share a long prefix, a deciding arm that finds without a ⚠). The copy differs
  # from the script in the one line that runs the full report as a child.
  local fold_cp="$SB_WORK/scripts/check-board-fold.sh" canned="$SB_TMP/canned-report.txt" fout
  perl -0pe 'BEGIN { $c = shift; $f = q{cb_raw="$("${BASH:-bash}" "${BASH_SOURCE[0]}" --full)"}; $r = q{cb_raw="$(cat "} . $c . q{")"} } s/\Q$f\E/$r/ or die "NOMATCH\n"' "$canned" "$SB_WORK/scripts/check-board.sh" > "$fold_cp" \
    || _fixture_die "could not make the canned-report copy of check-board.sh: the child line moved"
  chmod +x "$fold_cp"
  {
    printf '%s\n' '── check-board.sh — board-drift report @ canned'
    printf '\n%s\n' '[c] A long heading for the quiet reading of this one letter number one runs on ✓ — read from: x:'
    printf '\n%s\n' '[c] A long heading for the quiet reading of this one letter number two runs on ✓ — read from: x:'
    printf '\n%s\n' '[c] progress.md LAST ENTRY: THIS CHECK DID NOT RUN — nothing separates them  (skipped)'
    printf '\n%s\n%s\n' '[f] a reading with a finding:' '      ⚠ UNPUBLISHED 1 commit'
    printf '\n%s\n' '[k] declined/ depth (reports only — never changes the verdict below): 0 card(s)'
    printf '\n%s\n' '── board-drift: findings above ⚠ (informational; exit 0 by convention)'
  } > "$canned"
  fout="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR ./scripts/check-board-fold.sh 2>&1 )"
  printf '%s\n' "$fout" | grep -F "$CB_FOLD_LEAD" >/dev/null || _fixture_die "the canned report produced no folded line: $fout"
  fold="$(printf '%s\n' "$fout" | grep -F "$CB_FOLD_LEAD")"
  [ "$(printf '%s\n' "$fold" | grep -o '\[c: ' | wc -l | tr -d ' ')" = 2 ] \
    || cf "(5b) the two quiet [c] readings that share a long prefix are not two labels on the folded line: $fold"
  [ "$(printf '%s\n' "$fold" | grep -oE '\[c: [^]]*\]' | sort -u | wc -l | tr -d ' ')" = 2 ] \
    || cf "(5b) the two labels for headings that share a prefix are the same label: $fold"
  printf '%s\n' "$fold" | grep -E '\[c: [^]]* \]|\[c: [^]]*[A-Za-z]\]' | grep -vF '…' >/dev/null \
    && cf "(5b) a label that was cut does not end on a word boundary with an ellipsis: $fold"
  printf '%s\n' "$fold" | grep -F '[k]' >/dev/null || cf "(5b) an advisory lettered arm with no finding was not folded: $fold"
  printf '%s\n' "$fout" | grep -E '^\[c\] A long heading' >/dev/null \
    && cf "(5b) a quiet lettered reading was left unfolded because another arm found something: $fout"
  printf '%s\n' "$fout" | grep -E '^\[c\] progress.md LAST ENTRY' >/dev/null \
    || cf "(5b) a lettered reading that did not run was folded: $fout"
  rm -f "$fold_cp"
  # (5c) A verdict that is not clean with no ⚠ anywhere was set by an arm that printed none: the deciding
  # lettered arms stay in view and a line says so; an advisory arm still folds.
  canned="$SB_TMP/canned-report2.txt"
  {
    printf '%s\n' '── check-board.sh — board-drift report @ canned'
    printf '\n%s\n%s\n' '[a] Folder drift (every column) — read from: x:' '      3 card(s) judged, nothing to say'
    printf '\n%s\n' '[k] declined/ depth (reports only — never changes the verdict below): 0 card(s)'
    printf '\n%s\n' '── board-drift: findings above ⚠ (informational; exit 0 by convention)'
  } > "$canned"
  perl -0pe 'BEGIN { $c = shift; $f = q{cb_raw="$("${BASH:-bash}" "${BASH_SOURCE[0]}" --full)"}; $r = q{cb_raw="$(cat "} . $c . q{")"} } s/\Q$f\E/$r/ or die "NOMATCH\n"' "$canned" "$SB_WORK/scripts/check-board.sh" > "$fold_cp" \
    || _fixture_die "could not make the second canned-report copy of check-board.sh"
  chmod +x "$fold_cp"
  fout="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR ./scripts/check-board-fold.sh 2>&1 )"
  printf '%s\n' "$fout" | grep -E '^\[a\] Folder drift' >/dev/null \
    || cf "(5c) a deciding lettered arm was folded although the verdict is not clean and no arm printed a ⚠: $fout"
  printf '%s\n' "$fout" | grep -F 'set by an arm that printed no ⚠ line' >/dev/null \
    || cf "(5c) nothing says the verdict was set by an arm that printed no ⚠: $fout"
  printf '%s\n' "$fout" | grep -F "$CB_FOLD_LEAD" | grep -F '[k]' >/dev/null || cf "(5c) the advisory arm was not folded: $fout"
  rm -f "$fold_cp"

  # (6) The option is documented, and an unknown option is still a usage error.
  ( cd "$SB_WORK" && ./scripts/check-board.sh --help 2>&1 ) | grep -F -- '--full' >/dev/null || cf "(6) --help does not name --full"
  ( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR ./scripts/check-board.sh --no-such-option >/dev/null 2>&1 ); rc_def=$?
  [ "$rc_def" -eq 2 ] || cf "(6) an unknown option exited $rc_def, not 2"

  # (7) The SessionStart hook: its output, under budget, opens on the finding; over budget it keeps the folded line.
  local hook="$SB_WORK/scripts/hooks/session-start.sh" hout stub_root="$SB_TMP/stubroot-fold" i=0
  [ -f "$hook" ] || _fixture_die "no scripts/hooks/session-start.sh in the sandbox"
  hout="$(CLAUDE_PROJECT_DIR="$SB_WORK" bash "$hook" 2>&1)" || true
  case "$(printf '%s\n' "$hout" | grep -m1 '^\[')" in '[d]'*) : ;; *) cf "(7) the hook's output does not open its arms on the finding: $(printf '%s\n' "$hout" | grep -m1 '^\[')" ;; esac
  mkdir -p "$stub_root/scripts"
  {
    printf '#!/bin/sh\n'
    printf 'echo "[d] a finding arm — read from: origin/main:"\n'
    printf 'echo "    ⚠ FOLD-FINDING-SENTINEL card X: in todo/ but last Activity declares in_progress"\n'
    while [ "$i" -lt 400 ]; do printf 'echo "      a clean line %s that an arm prints to explain itself at some length"\n' "$i"; i=$((i + 1)); done
    printf 'echo "%s (check-board.sh --full prints each one): [a] [b]"\n' "$CB_FOLD_LEAD"
    printf 'echo "── board-drift: findings above ⚠ (informational; exit 0 by convention)"\n'
  } > "$stub_root/scripts/check-board.sh"
  chmod +x "$stub_root/scripts/check-board.sh"
  hout="$(CLAUDE_PROJECT_DIR="$stub_root" bash "$hook" 2>&1)" || true
  printf '%s\n' "$hout" | grep -F 'FOLD-FINDING-SENTINEL' >/dev/null || cf "(7) the over-budget hook output dropped the finding"
  printf '%s\n' "$hout" | grep -F "$CB_FOLD_LEAD" >/dev/null || cf "(7) the over-budget hook output dropped the folded line, which names the arms that found nothing"

  # (8) The consumers that read the report's text: the verdict line decides (kit-init's check (3) and
  # release.sh's gate (d) both key on it), and the ⚠ lines they print are the ones --full prints.
  printf '%s\n' "$def" | grep -F 'board-drift: findings above' >/dev/null || cf "(8) the verdict text a consumer keys on moved"
  # A clean board: the verdict is the one a consumer reads as clean, still reachable on the last line.
  teardown
  make_sandbox
  publish_sandbox
  def="$(cb_run_default)"
  printf '%s\n' "$def" | grep -F "$CB_FOLD_LEAD" >/dev/null || cf "(clean) a board with no finding prints no folded line"
  case "${def##*$'\n'}" in '── board-drift: clean'*) : ;; *) cf "(clean) the clean report does not end on 'board-drift: clean': ${def##*$'\n'}" ;; esac
  [ "$(printf '%s\n' "$def" | grep -c '^\[')" -lt "$(cb_run | grep -c '^\[')" ] \
    || cf "(clean) the clean report prints as many arm headings as --full: nothing was folded"

  finish "check-board: findings print first, arms that found nothing fold into one named line, arms that did not run stay visible, the verdict and every ⚠ line match --full, --full is the original order, and the SessionStart hook opens on the finding"
  teardown
}

# =============================================================================
# CASE — THE FOLD KEEPS AN ARM THAT SIGNALS A FINDING WITHOUT A `⚠`. An arm in scripts/check-board.d/
# says it found something with status 3 and prints whatever lines it likes (the extension contract asks
# for no glyph), and it may print a skip as `skipped: <why>`. The default report folds an arm only when
# it is positively clean — no ⚠, no skipped / did-not-run wording, a ✓, and nothing under its heading
# but ✓ lines — so each of those arms prints in full, the status-3 one with a line saying so, and the
# quiet arm is the only one named on the folded line. The report is also still advisory: the verdict
# does not move.
# =============================================================================
case_check_board_fold_keeps_an_arm_that_signals_without_a_warning() {
  cf_reset
  make_sandbox
  local d="$SB_WORK/scripts/check-board.d" def full
  [ -d "$d" ] || _fixture_die "case_check_board_fold_keeps_an_arm_that_signals_without_a_warning: no scripts/check-board.d in the sandbox"
  printf '# check-board-arm: advisory\necho "      design pin drift: skipped: python3 not found"\necho "      KIT-901 -> drift, owed (a D-NN raised with scripts/ask.sh)"\nreturn 3\n' > "$d/61-drift.sh"
  printf '# check-board-arm: advisory\necho "      ✓ none: 3 thing(s) read"\nreturn 0\n' > "$d/62-quiet.sh"
  printf '# check-board-arm: advisory\necho "      3 thing(s) read, nothing to say"\nreturn 0\n' > "$d/63-unmarked.sh"
  printf '# check-board-arm: advisory\necho "      ✓ none: one line"\necho "      ✓ 0 of 4 checked (skipped: the tool is absent)"\nreturn 0\n' > "$d/64-skipwordonly.sh"
  printf '# check-board-arm: advisory\necho "      widget ✓"\necho "[a] smuggled ✓"\necho "      drift line ✓"\nreturn 3\n' > "$d/65-smuggle.sh"
  publish_sandbox
  def="$(cb_run_default)"; full="$(cb_run)"
  printf '%s\n' "$full" | grep -F -- '-> drift, owed' >/dev/null \
    || _fixture_die "the probe arm's drift line is not in the full report, so the default report cannot be judged against it"
  printf '%s\n' "$def" | grep -F -- '-> drift, owed' >/dev/null \
    || cf "(1) an arm that returned 3 and printed a drift line without a ⚠ lost that line in the default report"
  printf '%s\n' "$def" | grep -F -- 'skipped: python3 not found' >/dev/null \
    || cf "(1) a skip printed as 'skipped: <why>' lost its line in the default report"
  printf '%s\n' "$def" | grep -F 'status 3' >/dev/null \
    || cf "(1) the default report does not say the status-3 arm reported a finding"
  printf '%s\n' "$def" | grep -E '^\[\+drift\]' >/dev/null \
    || cf "(1) the status-3 arm has no heading in the default report"
  printf '%s\n' "$def" | grep -E '^\[\+unmarked\]' >/dev/null \
    || cf "(2) an arm with a line that carries no ✓ was folded"
  printf '%s\n' "$def" | grep -E '^\[\+skipwordonly\]' >/dev/null \
    || cf "(2) an arm that prints 'skipped' beside a ✓ line was folded"
  printf '%s\n' "$def" | grep -E '^\[\+quiet\]' >/dev/null \
    && cf "(3) an arm that printed only a ✓ line and returned 0 kept its heading: nothing was folded"
  printf '%s\n' "$def" | grep -F "$CB_FOLD_LEAD" | grep -F '[+quiet]' >/dev/null \
    || cf "(3) the quiet arm is not named on the folded line"
  printf '%s\n' "$def" | grep -F "$CB_FOLD_LEAD" | grep -F -e '[+drift]' -e '[+unmarked]' -e '[+skipwordonly]' >/dev/null \
    && cf "(3) the folded line names an arm that printed a finding or an unmarked line"
  [ "$(printf '%s\n' "$def" | grep '^── board-drift')" = "$(printf '%s\n' "$full" | grep '^── board-drift')" ] \
    || cf "(4) the verdict differs between the default report and --full"
  # (4b) An arm that returned 3 is in the findings-first group, ahead of the arms that merely did not run.
  n_def="$(printf '%s\n' "$def" | grep -n -m1 -E '^\[\+drift\]' | cut -d: -f1)"
  n_full="$(printf '%s\n' "$def" | grep -n -m1 -E 'DID NOT RUN' | cut -d: -f1)"
  if [ -n "$n_full" ]; then
    [ -n "$n_def" ] && [ "$n_def" -lt "$n_full" ] \
      || cf "(4b) the status-3 arm [+drift] (line ${n_def:-none}) does not come before the first arm that did not run (line $n_full)"
  fi
  # (5) The status line names its arm, so an arm that prints a heading-shaped line is still unfolded.
  printf '%s\n' "$def" | grep -F '↳ [+drift] status 3' >/dev/null || cf "(5) the status line does not name its arm: $(printf '%s\n' "$def" | grep 'status 3' | head -2)"
  printf '%s\n' "$def" | grep -F 'drift line ✓' >/dev/null || cf "(5) a line the status-3 arm printed after a heading-shaped line is not in the default report"
  printf '%s\n' "$def" | grep -F "$CB_FOLD_LEAD" | grep -F '[+smuggle]' >/dev/null \
    && cf "(5) an arm that returned 3 is named on the folded line because it printed a heading-shaped line"
  # (6) A deciding arm's status line carries a ⚠, so the lines a refusal prints name the arm.
  printf '# check-board-arm: deciding\necho "      owed ✓"\nreturn 3\n' > "$d/66-decide.sh"
  publish_sandbox
  def="$(cb_run_default)"
  printf '%s\n' "$def" | grep -F '⚠' | grep -F '[+decide] status 3' >/dev/null \
    || cf "(6) a deciding arm's status-3 line carries no ⚠ naming the arm: $(printf '%s\n' "$def" | grep 'decide' | head -3)"
  printf '%s\n' "$def" | grep '^── board-drift' | grep -F 'findings above' >/dev/null || cf "(6) a deciding arm that returned 3 left the verdict clean"
  rm -f "$d/66-decide.sh"
  publish_sandbox
  # (7) The SessionStart hook past its budget keeps what the fold protects: a [+name] section whole, its
  # status line, and the graduation arm's hooks: and verdict lines.
  local hook="$SB_WORK/scripts/hooks/session-start.sh" stub_root="$SB_TMP/stubroot-keep" i=0 hout
  [ -f "$hook" ] || _fixture_die "no scripts/hooks/session-start.sh in the sandbox"
  mkdir -p "$stub_root/scripts"
  {
    printf '#!/bin/sh\n'
    printf 'echo "[g] Graduation — has day one finished?  (reports only; it never changes the verdict below —"\n'
    printf 'echo "      hooks: off (.claude/settings.json absent) — the editor-tool hat gate does not run"\n'
    printf 'echo "      → graduation COMPLETE over the classes measured above; this arm has nothing further to ask."\n'
    printf 'echo "[+drift] arm (scripts/check-board.d/61-drift.sh; reports only) — read from: origin/main:"\n'
    printf 'echo "      design pin drift: skipped: python3 not found"\n'
    printf 'echo "      X-901 -> drift, owed (a D-NN raised)"\n'
    printf 'echo "      ↳ [+drift] status 3: this arm reported a finding above"\n'
    printf 'echo "[e] a quiet arm of the kit"\n'
    while [ "$i" -lt 400 ]; do printf 'echo "      a quiet line %%s that an arm prints to explain itself at some length"\n' "$i"; i=$((i + 1)); done
    printf 'echo "%s (check-board.sh --full prints each one): [a] [b]"\n' "$CB_FOLD_LEAD"
    printf 'echo "── board-drift: clean ✓"\n'
  } > "$stub_root/scripts/check-board.sh"
  chmod +x "$stub_root/scripts/check-board.sh"
  hout="$(CLAUDE_PROJECT_DIR="$stub_root" bash "$hook" 2>&1)" || true
  [ "$(printf '%s\n' "$hout" | LC_ALL=C wc -c | tr -d ' ')" -le 9000 ] || cf "(7) the over-budget hook output is over the delivery budget"
  printf '%s\n' "$hout" | grep -F 'hooks: off' >/dev/null || cf "(7) the over-budget hook output dropped the graduation arm's hooks: line"
  printf '%s\n' "$hout" | grep -F '→ graduation COMPLETE' >/dev/null || cf "(7) the over-budget hook output dropped the graduation verdict line"
  printf '%s\n' "$hout" | grep -F -- '-> drift, owed' >/dev/null || cf "(7) the over-budget hook output dropped a [+name] arm's finding line"
  printf '%s\n' "$hout" | grep -F 'skipped: python3 not found' >/dev/null || cf "(7) the over-budget hook output dropped a [+name] arm's skip line"
  printf '%s\n' "$hout" | grep -F '↳ [+drift] status 3' >/dev/null || cf "(7) the over-budget hook output dropped the status-3 line"
  printf '%s\n' "$hout" | grep -F 'a quiet line' >/dev/null && cf "(7) the over-budget hook output kept the quiet lines of a lettered arm"
  # (8) A [+name] section longer than the budget whose finding comes last, and a verbose quiet arm followed
  # by a late arm that returned 3: both findings and both status lines survive, and the output stays in budget.
  stub_root="$SB_TMP/stubroot-long"; i=0
  mkdir -p "$stub_root/scripts"
  {
    printf '#!/bin/sh\n'
    printf 'echo "[g] Graduation — has day one finished?  (reports only"\n'
    printf 'echo "      hooks: off (settings absent) — the hat gate does not run"\n'
    printf 'echo "      → graduation COMPLETE over the classes measured above."\n'
    printf 'echo "[+verbose] arm (scripts/check-board.d/50-verbose.sh; reports only) — read from: origin/main:"\n'
    while [ "$i" -lt 200 ]; do printf 'echo "      XYZ-%s UX-1#home@abc1234 clean and in step with its pin"\n' "$i"; i=$((i + 1)); done
    printf 'echo "      XYZ-777 -> drift, owed (a D-NN raised with scripts/ask.sh)"\n'
    printf 'echo "      ↳ [+verbose] status 3: this arm reported a finding above"\n'
    printf 'echo "[+quiet] arm (scripts/check-board.d/55-quiet.sh; reports only) — read from: origin/main:"\n'
    i=0; while [ "$i" -lt 120 ]; do printf 'echo "      verbose quiet line %s that explains itself at some length"\n' "$i"; i=$((i + 1)); done
    printf 'echo "[+late] arm (scripts/check-board.d/60-late.sh; reports only) — read from: origin/main:"\n'
    printf 'echo "      XYZ-900 -> drift, owed (a D-NN raised)"\n'
    printf 'echo "      ↳ [+late] status 3: this arm reported a finding above"\n'
    printf 'echo "%s (check-board.sh --full prints each one): [a] [b]"\n' "$CB_FOLD_LEAD"
    printf 'echo "── board-drift: clean ✓"\n'
  } > "$stub_root/scripts/check-board.sh"
  chmod +x "$stub_root/scripts/check-board.sh"
  hout="$(CLAUDE_PROJECT_DIR="$stub_root" bash "$hook" 2>&1)" || true
  [ "$(printf '%s\n' "$hout" | LC_ALL=C wc -c | tr -d ' ')" -le 8200 ] || cf "(8) the over-budget hook output is over its budget with long [+name] sections"
  printf '%s\n' "$hout" | grep -F 'XYZ-777 -> drift, owed' >/dev/null || cf "(8) a long [+name] arm's finding, which comes last, was dropped"
  printf '%s\n' "$hout" | grep -F '↳ [+verbose] status 3' >/dev/null || cf "(8) a long [+name] arm's status line was dropped"
  printf '%s\n' "$hout" | grep -F 'XYZ-900 -> drift, owed' >/dev/null || cf "(8) a late arm's finding was dropped behind a verbose arm"
  printf '%s\n' "$hout" | grep -F '↳ [+late] status 3' >/dev/null || cf "(8) a late arm's status line was dropped behind a verbose arm"
  printf '%s\n' "$hout" | grep -F 'not shown' >/dev/null || cf "(8) a section the hook cut short does not say so"
  finish "check-board: an arm that returns 3, or prints a skip as 'skipped: <why>', or prints a line without ✓, stays in the default report; only an arm that printed nothing but ✓ lines and returned 0 is folded and named"
  teardown
}

# =============================================================================
# CASE — arm [a] JUDGES THE LAST BULLET THAT CARRIES A `→ <folder>` TARGET AND COUNTS WHAT IT COULD NOT
# JUDGE, a card with no Activity section named apart. The mover's own `--note-only` entry carries no arrow, so a hand move made before it used to read
# clean. Fixture order follows the real one: the mover's entries, a hand `git mv`, then the note-only entry.
# =============================================================================
case_check_board_arm_a_judges_past_a_note_only_entry_and_counts_the_unjudgeable() {
  cf_reset
  make_sandbox
  local ma="$SB_PREFIX-441" mb="$SB_PREFIX-442" mc="$SB_PREFIX-443" md="$SB_PREFIX-444"
  seed_issue todo "$ma" masked chore "Hand-moved, then noted"
  seed_issue in_progress "$mb" kept chore "Moved by the mover, then noted"
  seed_issue todo "$mc" bare chore "Never moved"
  seed_issue todo "$md" bare-noact chore "No Activity section"
  sed -i.bak '/^## Activity/,$d' "$SB_WORK/progress/todo/$md-bare-noact.md" && rm -f "$SB_WORK/progress/todo/$md-bare-noact.md.bak"
  printf -- '- 2026-01-02 [Dev] moved → in_progress\n' >> "$SB_WORK/progress/todo/$ma-masked.md"
  printf -- '- 2026-01-02 [Dev] moved → in_progress\n' >> "$SB_WORK/progress/in_progress/$mb-kept.md"
  local noted='- 2026-01-03 [Dev] NOTE: a record made without moving it'
  # (1) BEFORE the note-only entry: the hand-moved card is already caught, so the check is alive.
  publish_sandbox
  local before after
  before="$(cb_run | _cb_a_section)"
  printf '%s\n' "$before" | grep -F "$ma-masked.md: in todo/ but last Activity declares → in_progress" >/dev/null \
    || cf "(control) the card whose last Activity entry declares a move it is not in was not reported before the note: $before"
  # (2) AFTER the note-only entry: the same card is still reported.
  printf '%s\n' "$noted" >> "$SB_WORK/progress/todo/$ma-masked.md"
  printf '%s\n' "$noted" >> "$SB_WORK/progress/in_progress/$mb-kept.md"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[PM] note without moving" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push origin "$SB_TRUNK" >/dev/null 2>&1
  after="$(cb_run | _cb_a_section)"
  printf '%s\n' "$after" | grep -F "$ma-masked.md: in todo/ but last Activity declares → in_progress" >/dev/null \
    || cf "a note-only entry after the hand move hid it: $after"
  printf '%s\n' "$after" | grep -F "$mb-kept.md" >/dev/null \
    && cf "the card the mover put in in_progress was reported after a note-only entry: $after"
  # (3) the count: two cards carry an arrow; the other two have none to judge, one of them with no Activity section.
  printf '%s\n' "$after" | grep -F '2 judged, 2 not judgeable (1 with no Activity section)' >/dev/null \
    || cf "the arm did not print '2 judged, 2 not judgeable (1 with no Activity section)': $after"
  # (4) the clean line carries the count too: the hand-moved card put right.
  git -C "$SB_WORK" mv "progress/todo/$ma-masked.md" "progress/in_progress/$ma-masked.md" >/dev/null 2>&1
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[PM] put the card back" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push origin "$SB_TRUNK" >/dev/null 2>&1
  after="$(cb_run | _cb_a_section)"
  printf '%s\n' "$after" | grep -F '✓ none across' | grep -F '2 judged, 2 not judgeable (1 with no Activity section)' >/dev/null \
    || cf "a clean arm does not print its count: $after"
  finish "arm [a] reports a hand-moved card after a note-only entry, leaves the mover's own card clean, and prints how many cards it judged and how many it could not"
  teardown
}

# =============================================================================
# CASE — THE FOLD KEEPS [g]'s VERDICT AND ITS `hooks:` LINE. MANUAL.md sends a session to the graduation
# arm for `hooks: off` and the start skill makes `→ graduation COMPLETE` the authority on whether day one
# finished, so a graduated project's default report still carries both lines, under [g]'s own heading,
# while the rest of [g] is folded; a [g] that holds a ⚠ prints whole.
# =============================================================================
case_check_board_fold_keeps_the_graduation_verdict_and_the_hooks_line() {
  cf_reset
  make_sandbox
  seed_scaffolding_tree
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  printf '# my project\n'                 > "$SB_WORK/AGENTS.md"
  printf '# my project\n'                 > "$SB_WORK/README.md"
  printf '<!-- %s — synthetic fill sheet, FILLED. -->\n# PROJECT.md\n\nTrunk: main\n\n## Who answers when nobody is watching\n\n- **`principal:`** `Fixture Owner`\n- **Their channel:** `dev/questions/`\n' \
    "$KIT_FILL_DISPOSITION" > "$SB_WORK/PROJECT.md"
  _cb_g_declare_empty_seams
  _cb_g_discharge_gitignore_env
  _cb_g_land_day_one_work
  _cb_g_discharge_delete_if_unused
  rm -f "$SB_WORK/.claude/settings.json"
  publish_sandbox
  local full def noisy
  full="$(cb_run | _cb_g_section)"
  printf '%s\n' "$full" | grep 'graduation COMPLETE' >/dev/null \
    || _fixture_die "the graduated sandbox does not read COMPLETE in --full, so the fold cannot be judged: $full"
  printf '%s\n' "$full" | grep 'hooks: off' >/dev/null \
    || _fixture_die "the sandbox prints no hooks: off line in --full, so the fold cannot be judged"
  def="$(cb_run_default)"
  printf '%s\n' "$def" | grep -E '^\[g\]' >/dev/null || cf "(1) the default report has no [g] heading"
  printf '%s\n' "$def" | grep -E '→ graduation COMPLETE' >/dev/null || cf "(1) the default report lost the graduation verdict line"
  printf '%s\n' "$def" | grep -F 'hooks: off' >/dev/null || cf "(2) the default report lost the hooks: off line"
  printf '%s\n' "$def" | grep -F 'FILL (.gitignore)' >/dev/null && cf "(3) the rest of [g] was not folded: its FILL lines are in the default report"
  # (3b) A clean report fits in a few lines: every arm heading still printed, other than [g], is one that
  # holds a finding or says it did not run.
  noisy="$(printf '%s\n' "$def" | awk '/^\[[a-z+]/ { if (h != "" && !keep && h !~ /^\[g\]/) print h; h = $0; keep = ($0 ~ /⚠|DID NOT RUN|skipped/); next }
      /^── / { if (h != "" && !keep && h !~ /^\[g\]/) print h; h = ""; next }
      h != "" && /⚠|DID NOT RUN|skipped/ { keep = 1 }
      END { if (h != "" && !keep && h !~ /^\[g\]/) print h }')"
  [ -z "$noisy" ] || cf "(3b) a clean graduated tree's default report still prints arm(s) that found nothing: $(printf '%s' "$noisy" | cut -c1-60 | tr '\n' '|')"
  # With hooks on, the line is absent from both and the verdict stays.
  mkdir -p "$SB_WORK/.claude"; printf '{}\n' > "$SB_WORK/.claude/settings.json"
  git -C "$SB_WORK" add .claude/settings.json >/dev/null 2>&1
  sbcommit -m "[PM] turn the hooks on" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push origin "$SB_TRUNK" >/dev/null 2>&1
  def="$(cb_run_default)"
  printf '%s\n' "$def" | grep -F 'hooks: off' >/dev/null && cf "(4) hooks: off printed with .claude/settings.json present"
  printf '%s\n' "$def" | grep -E '→ graduation COMPLETE' >/dev/null || cf "(4) the verdict line is gone once the hooks are on"
  # A [g] with a finding prints whole.
  printf '%s\n' "# LOCAL-PROCEDURES.md" > "$SB_WORK/process/LOCAL-PROCEDURES.md"
  git -C "$SB_WORK" add process/LOCAL-PROCEDURES.md >/dev/null 2>&1
  sbcommit -m "[PM] forget the kept lines" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push origin "$SB_TRUNK" >/dev/null 2>&1
  def="$(cb_run_default)"
  printf '%s\n' "$def" | grep -F 'FILL (.gitignore)' >/dev/null || cf "(5) a [g] holding a ⚠ was folded: its FILL lines are missing from the default report"
  finish "check-board: a graduated project's default report keeps [g]'s heading, its '→ graduation COMPLETE' line and its 'hooks: off' line and folds the rest of [g]; a [g] with a finding prints whole"
  teardown
}

# =============================================================================
# CASE — check-board's [v] compares scripts/ with process/KIT-MANIFEST, presence only, and only reports.
# The fixture manifest is written from the sandbox's own scripts/, so the control is clean on any tree.
# (control) every manifest row is on disk: ✓. (unlisted) a script the manifest does not list is named as the
# project's, not as a ⚠. (gone) a listed file that is absent is a ⚠. (optional) the same marked
# DELETE-IF-UNUSED is named as allowed, not a ⚠. (nomanifest) no manifest: a skipped line and no ✓. In each
# the verdict and the exit status are the control's.
# =============================================================================
_cb_seed_manifest() {  # [<extra manifest row>…]
  ( cd "$SB_WORK" && mkdir -p process \
    && { printf '# KIT-CLASS: KIT — the fixture manifest\n'; find scripts -type f | LC_ALL=C sort | while IFS= read -r p; do printf '%064d  %s  -  -\n' 0 "$p"; done; } > process/KIT-MANIFEST )
  local row
  for row in "$@"; do printf '%s\n' "$row" >> "$SB_WORK/process/KIT-MANIFEST"; done
}
_cb_republish() {
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[PM] fixture change" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
}
case_check_board_scripts_against_the_manifest() {
  cf_reset
  make_sandbox
  _cb_seed_manifest
  publish_sandbox
  local out sec base rc head
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _nr_arm_section v)"
  [ -n "$sec" ] || cf "no [v] section in the report — the arm is absent"
  head="$(printf '%s\n' "$out" | grep '^\[v\]' | head -1)"
  printf '%s\n' "$head" | grep -F 'reports only' >/dev/null || cf "[v]'s header does not carry the 'reports only' token: $head"
  printf '%s\n' "$head" | grep -F 'unless it could not run' >/dev/null || cf "[v]'s header does not say it can change the verdict when it could not run: $head"
  printf '%s\n' "$sec" | grep -F '✓ none missing' >/dev/null || cf "(control) a manifest that matches scripts/ is not a ✓: $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$sec" | grep -F '⚠' >/dev/null && cf "(control) a matching manifest holds a ⚠"
  base="$(printf '%s\n' "$out" | grep '^── board-drift')"
  printf '%s\n' "$base" | grep -F 'clean' >/dev/null || cf "(control) the fixture board does not read clean: $base"

  # (unlisted)
  printf '#!/bin/sh\necho mine\n' > "$SB_WORK/scripts/my-own.sh"
  _cb_republish
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _nr_arm_section v)"
  printf '%s\n' "$sec" | grep -F 'scripts/my-own.sh' | grep -F "not in the manifest (the project's own, or placed by an enabled module)" >/dev/null || cf "(unlisted) a script the manifest lacks is not named as the project's: $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$sec" | grep -F 'my-own.sh' | grep -F '⚠' >/dev/null && cf "(unlisted) a project's own script is a ⚠"
  [ "$(printf '%s\n' "$out" | grep '^── board-drift')" = "$base" ] || cf "(unlisted) the verdict moved: $(printf '%s\n' "$out" | grep '^── board-drift')"
  rm -f "$SB_WORK/scripts/my-own.sh"

  # (gone) and (optional): two listed files that are not on disk
  _cb_seed_manifest "$(printf '%064d  %s  -  -' 0 scripts/gone.sh)" "$(printf '%064d  %s  -  DELETE-IF-UNUSED' 0 scripts/optional.sh)"
  _cb_republish
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _nr_arm_section v)"
  printf '%s\n' "$sec" | grep -F 'scripts/gone.sh' | grep -F '⚠' | grep -F 'not on the trunk' >/dev/null || cf "(gone) a listed file that is absent is not a ⚠: $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$sec" | grep -F 'scripts/optional.sh' | grep -F 'deleted as unused: allowed' >/dev/null || cf "(optional) an absent DELETE-IF-UNUSED file is not named as allowed: $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$sec" | grep -F 'scripts/optional.sh' | grep -F '⚠' >/dev/null && cf "(optional) an absent DELETE-IF-UNUSED file is a ⚠"
  printf '%s\n' "$sec" | grep -F '✓' >/dev/null && cf "(gone) a ✓ line under a missing file"
  [ "$(printf '%s\n' "$out" | grep '^── board-drift')" = "$base" ] || cf "(gone) the verdict moved: $(printf '%s\n' "$out" | grep '^── board-drift')"
  ( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR ./scripts/check-board.sh --full >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 0 ] || cf "(gone) check-board.sh exited $rc over a finding in a reports-only arm"
  ( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR ./scripts/check-board.sh >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 0 ] || cf "(gone, default report) check-board.sh exited $rc over a finding in a reports-only arm"

  # (nomanifest)
  rm -f "$SB_WORK/process/KIT-MANIFEST"
  _cb_republish
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _nr_arm_section v)"
  printf '%s\n' "$sec" | grep -F 'skipped' >/dev/null || cf "(nomanifest) no skipped line: $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$sec" | grep -F '✓' >/dev/null && cf "(nomanifest) a ✓ although nothing was compared"
  [ "$(printf '%s\n' "$out" | grep '^── board-drift')" = "$base" ] || cf "(nomanifest) the verdict moved: $(printf '%s\n' "$out" | grep '^── board-drift')"
  finish "arm [v] names a script the manifest does not list as the project's, a listed absent file as a ⚠ unless it is DELETE-IF-UNUSED, skips with no ✓ when there is no manifest, and never moves the verdict or the exit status"
  teardown
}

# =============================================================================
# CASE — arm [v] AT ITS EDGES: A FAILED MANIFEST READ, A SYMLINK, AND WORKING-TREE MODE.
# (unreadable) when the manifest read fails the arm says DID NOT RUN and prints no "not in the
# manifest" line, which would attribute every script to the project from a list it never read.
# (symlink) a listed file that is a symlink is present, and an unlisted one is named like any other.
# (worktree) with no trunk ref the arm reads the working tree, where a gitignored file is not part of
# the project's scripts and is not named; an untracked one still is.
# =============================================================================
case_check_board_arm_v_edges() {
  cf_reset
  make_sandbox
  ln -s ask.sh "$SB_WORK/scripts/linked.sh"
  ln -s ask.sh "$SB_WORK/scripts/other-link.sh"
  _cb_seed_manifest "$(printf '%064d  %s  -  -' 0 scripts/linked.sh)"
  publish_sandbox
  local out sec oldp="$PATH" shimd="$SB_TMP/shim-av"
  # (symlink)
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _nr_arm_section v)"
  printf '%s\n' "$sec" | grep -F 'scripts/linked.sh' | grep -F '⚠' >/dev/null && cf "(symlink) a listed file that is a symlink reads as absent: $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$sec" | grep -F 'scripts/other-link.sh' | grep -F "not in the manifest" >/dev/null || cf "(symlink) an unlisted symlink is not named: $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$sec" | grep -F '✓ none missing' >/dev/null || cf "(symlink) a manifest whose rows are all present is not a ✓: $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-300)"
  # (unreadable)
  _nr_shim_cmd "$shimd" awk 'pfx=scripts/'
  PATH="$shimd:$oldp"
  out="$(cb_run)"
  PATH="$oldp"
  sec="$(printf '%s\n' "$out" | _nr_arm_section v)"
  printf '%s\n' "$sec" | grep -F 'DID NOT RUN' >/dev/null || cf "(unreadable) no DID NOT RUN over a manifest read that failed: $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$sec" | grep -F 'not in the manifest' >/dev/null && cf "(unreadable) the arm attributes scripts to the project from a manifest it could not read: $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-200)"
  teardown

  # (worktree): no remote, so the report reads the working tree
  make_sandbox
  printf 'scripts/ignored.sh\n' >> "$SB_WORK/.gitignore"
  _cb_seed_manifest
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[PM] seed sandbox board" --quiet >/dev/null 2>&1
  printf '#!/bin/sh\n' > "$SB_WORK/scripts/ignored.sh"
  printf '#!/bin/sh\n' > "$SB_WORK/scripts/untracked.sh"
  printf '#!/bin/sh\n' > "$SB_WORK/scripts/$(printf 'caf\303\251').sh"
  printf '#!/bin/sh\n' > "$SB_WORK/scripts/$(printf 'new\nline').sh"
  rm -f "$SB_WORK/scripts/archive.sh"
  out="$(cb_run)"; sec="$(printf '%s\n' "$out" | _nr_arm_section v)"
  printf '%s\n' "$out" | grep -F 'WORKING TREE' >/dev/null || cf "(worktree) the fixture did not read the working tree: $(printf '%s' "$out" | grep '^\[v\]' | cut -c1-200)"
  printf '%s\n' "$sec" | grep -F 'scripts/ignored.sh' >/dev/null && cf "(worktree) a gitignored file is named: $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$sec" | grep -F 'scripts/untracked.sh' | grep -F 'not in the manifest' >/dev/null || cf "(worktree) an untracked script is not named: $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$sec" | grep -F 'scripts/archive.sh' | grep -F '⚠' >/dev/null || cf "(worktree) a tracked file deleted from the working tree is not a ⚠: $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$sec" | grep -F 'scripts/archive.sh' | grep -F 'not in the working tree' >/dev/null || cf "(worktree) the ⚠ for a file missing from the working tree does not say so: $(printf '%s' "$sec" | grep -F 'archive.sh' | cut -c1-200)"
  printf '%s\n' "$sec" | grep -F 'not on the trunk' >/dev/null && cf "(worktree) a working-tree read says 'not on the trunk': $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$sec" | grep -F 'new\nline.sh' | grep -F 'not in the manifest' >/dev/null || cf "(worktree) a script whose name holds a newline is not kept as one name: $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$sec" | grep -F 'caf' | grep -F 'not in the manifest' >/dev/null || cf "(worktree) a script whose name git quotes (non-ASCII) is not named: $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-300)"
  finish "arm [v] prints DID NOT RUN and no 'not in the manifest' line when the manifest read fails, counts a symlink as present, and in working-tree mode leaves a gitignored file out"
  teardown
}
