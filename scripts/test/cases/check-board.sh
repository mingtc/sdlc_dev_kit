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
  IFS='|' read -r -a cols <<< "$(cb_default STATUS_FOLDERS)"
  [ "${#cols[@]}" -gt 0 ] \
    || _fixture_die "_lived_signals: STATUS_FOLDERS could not be read from check-board.sh — the board signal would be skipped entirely and every guard built on this would pass over a board it never looked at."
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
_cb_g_section() {  # reads a check-board report on stdin
  awk '/^\[g\]/ { f = 1 }
       f && /^──/ { exit }
       f && /^\[[a-z]\]/ && !/^\[g\]/ { exit }
       f'
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
cb_run() { ( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR "$SB_WORK/scripts/check-board.sh" 2>&1 ); }

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
  _j_section() { cd "$SB_WORK" && ./scripts/check-board.sh 2>&1 | awk '/^\[j\]/{f=1;print;next} f&&/^\[/{f=0} f'; }
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

  _j_at() { ( cd "$1" && "$SB_WORK/scripts/check-board.sh" 2>&1 ) | awk '/^\[j\]/{f=1;print;next} f&&/^\[/{f=0} f'; }
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
# SKIP instead of a FAIL. The constants are read from the REAL check-board.sh (cb_default), so an
# edit there cannot make these assertions vacuous.
case_check_board_id_clean() {
  cf_reset
  make_sandbox

  # Derive the three constants, and prove the derivation itself is live — an empty
  # value means the defaults block moved.
  local status_folders id_key id_pattern ncols
  status_folders="$(cb_default STATUS_FOLDERS)"
  id_key="$(cb_default ISSUE_ID_KEY)"
  id_pattern="$(cb_default ISSUE_ID_PATTERN)"
  [ -n "$status_folders" ] || cf "could not derive STATUS_FOLDERS from the defaults block"
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

  local registers reg_path reg_mark marker exclude prd_dir prd_file out rc
  registers="$(cb_default REGISTERS)"
  marker="$(cb_default CITATION_MARKER)"
  exclude="$(sed -n "/^CITATION_EXCLUDE='/,/'\$/p" "$REAL_SCRIPTS/check-board.sh" | sed "s/^CITATION_EXCLUDE='//; s/'\$//")"
  [ -n "$registers" ] || { cf "could not derive REGISTERS"; finish "arm (l): citations"; teardown; return; }
  [ -n "$marker" ]    || cf "could not derive CITATION_MARKER from check-board.sh"
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
  printf '%s\n' "$out" | grep -E "$SB_PREFIX-999|$SB_PREFIX-721" >/dev/null \
    && cf "(control) a finding survived arm (p)'s ablation, so it is not attributable to this arm: $out"
  printf '%s\n' "$out" | grep 'board-drift: clean ✓' >/dev/null \
    || cf "(control) without arm (p) the board did not read clean, so the findings above are not attributable to it: $out"

  finish "arm (p): a dangling forward-referenced id and a landed-but-unflipped one are reported and DECIDE the verdict; a still-open correctly-marked id is silent; a SEED-step marker is silent before day one closes; ablation-proven"
  teardown
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
  printf '# my project\n' > "$SB_WORK/CLAUDE.md"
  printf '# my project\n' > "$SB_WORK/README.md"
  printf '<!-- %s — synthetic fill sheet, FILLED. -->\n# PROJECT.md\n\nTrunk: main\n' \
    "$KIT_FILL_DISPOSITION" > "$SB_WORK/PROJECT.md"
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
  local registers reg_path reg_mark marker prd_surface out
  registers="$(cb_default REGISTERS)"
  marker="$(cb_default CITATION_MARKER)"
  prd_surface="$(cb_default PRD_SURFACE)"
  [ -n "$registers" ]   || { cf "could not derive REGISTERS from the defaults block"; finish "arm (r): reverse coverage"; teardown; return; }
  [ -n "$marker" ]      || cf "could not derive CITATION_MARKER from check-board.sh"
  [ -n "$prd_surface" ] || cf "could not derive PRD_SURFACE from check-board.sh"
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
  out="$( cd "$sh" && env -u CLAUDE_PROJECT_DIR ./scripts/check-board.sh 2>&1 )"
  printf '%s\n' "$out" | grep 'THIS IS A SHALLOW CLONE' >/dev/null \
    || cf "the report does not say the history is shallow — the arms narrowed against a graft boundary and presented it as a derived epoch: $out"
  printf '%s\n' "$out" | grep "scope: commits after ${grafted:0:9}" >/dev/null \
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
  scopes="$(printf '%s\n' "$out" | grep -o 'scope: commits after [0-9a-f]\{9\}' || true)"
  e_scope="$(printf '%s\n' "$scopes" | sed -n '1p')"
  h_scope="$(printf '%s\n' "$scopes" | sed -n '2p')"
  { [ -n "$e_scope" ] && [ -n "$h_scope" ]; } \
    || cf "fewer than two 'scope: commits after <sha>' lines — one of the two history arms does not name its narrowing where its result is printed: $out"
  [ "$e_scope" = "$h_scope" ] \
    || cf "arms [e] and [h] name DIFFERENT epochs ('$e_scope' vs '$h_scope') — one rule, one file, two boundaries: the later one is silently hiding findings"

  # INSTRUMENT AGAINST A VACUOUS PASS: if nothing was out of scope, the two exclusions
  # above are satisfied by an arm that narrowed nothing.
  printf '%s\n' "$out" | grep -E "scope: commits after ${sha_epoch}[^—]*— [1-9][0-9]* of the last" >/dev/null \
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
  printf '%s\n' "$out" | grep "scope: commits after $sha_epoch, which ADDED scripts/githooks/commit-msg" >/dev/null \
    || cf "the scope line does not name the epoch it derived: $out"
  printf '%s\n' "$out" | grep -E "scope: commits after $sha_epoch, which ADDED scripts/githooks/commit-msg — [1-9][0-9]* of the last" >/dev/null \
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
  printf '%s\n' "$rout" | grep "scope: commits after $sha_root" >/dev/null \
    || cf "(root) the scope line does not name the root epoch: $rout"

  finish "check-board arm (e): pre-adoption commits and the epoch commit ITSELF are excluded, a post-epoch unprefixed commit is still reported (ablation-proven), the narrowing is named with its count — and the same holds when the epoch is the ROOT commit, which is what the day-one recipe produces"
  teardown
}

# =============================================================================
# CASE — ARM (e)'s "Merge commit " EXEMPTION REQUIRES THE QUOTE.
#
# A cold audit fed check-board a subject that starts with the same two words as git's own
# generated merge subject (`Merge commit '<sha>'`) but is not one: "Merge commit messages into
# one doc". At HEAD the exemption glob was a bare prefix match with no quote, so this ordinary,
# unprefixed, human-authored subject was silently exempted and the arm printed "all N scanned
# subject(s) carry a [Role] prefix" — a false sentence about a subject it never actually held to
# the rule.
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
  out="$( cd "$wt" && env -u CLAUDE_PROJECT_DIR "$wt/scripts/check-board.sh" 2>&1 )"; rc=$?
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
# make_sandbox seeds no root documents, so each state below seeds CLAUDE.md / README.md /
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
  publish_sandbox

  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'CLAUDE.md' >/dev/null \
    || cf "(b) the REPLACE finding did not NAME CLAUDE.md — instruments.md § A.4 wants the operand: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'README.md' >/dev/null \
    || cf "(b) the REPLACE finding did not name README.md: $out"
  printf '%s\n' "$out" | _cb_g_section | grep -i 'PROJECT.md still holds' >/dev/null \
    || cf "(b) the FILL finding did not fire on a PROJECT.md holding <trunk>: $out"
  # The class name exactly: a case-insensitive 'not measured' also matches the FILL span line's
  # own disclaimer, so it could not see this class being omitted.
  printf '%s\n' "$out" | _cb_g_section | grep 'DELETE-IF-UNUSED: not measured' >/dev/null \
    || cf "(b) DELETE-IF-UNUSED was silently omitted instead of declaring itself unmeasured: $out"

  # ── (c) THE VERDICT CONTROL: graduation findings must never move the verdict, or release.sh's
  #    board gate and kit-init's self-check fail every fresh install.
  printf '%s\n' "$out" | grep 'board-drift: clean ✓' >/dev/null \
    || cf "(c) graduation findings changed the board verdict — release.sh gate (d) keys on this line, and a dirty verdict is what sends kit-init's self-check looking for a cause: $out"

  # ── (d) GRADUATED: it clears, and it NAMES ITS SOURCE while clearing. ────────
  printf '# my project\n'                 > "$SB_WORK/CLAUDE.md"
  printf '# my project\n'                 > "$SB_WORK/README.md"
  printf '<!-- %s — synthetic fill sheet, FILLED. -->\n# PROJECT.md\n\nTrunk: main\n' \
    "$KIT_FILL_DISPOSITION" > "$SB_WORK/PROJECT.md"
  publish_sandbox

  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    || cf "(d) a graduated tree did not clear: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'read from:' >/dev/null \
    || cf "(d) the CLEARING branch did not name its operand — instruments.md § A.4, the asymmetry that only errs toward false confidence: $out"
  printf '%s\n' "$out" | _cb_g_section | grep -i 'still scaffolding' >/dev/null \
    && cf "(d) a graduated tree still reported scaffolding: $out"

  finish "check (g): graduation says THIS CHECK DID NOT RUN with no signal, reports and names its files while scaffolding stands, clears once replaced naming its source — and never moves the board verdict"
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
  printf '# my project\n'                > "$SB_WORK/CLAUDE.md"
  printf '# my project\n'                > "$SB_WORK/README.md"
  printf '<!-- %s — synthetic fill sheet, FILLED. -->\n# PROJECT.md\n\nTrunk: main\n' \
    "$KIT_FILL_DISPOSITION" > "$SB_WORK/PROJECT.md"
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
  printf '%s' "$line" | grep -F 'CLAUDE.md' >/dev/null && printf '%s' "$line" | grep -F 'README.md' >/dev/null \
    || cf "(control) the shipped REPLACE pair left the population: ${line:-no REPLACE finding}"

  finish "check (g): the REPLACE population is every file whose header block declares it, wherever it lives, and not a file that quotes the marker further down"
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
  printf '%s\n' "$_kf_sec" | grep '⚠' | grep 'no kit-feedback: line' >/dev/null \
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
#       blanks, and graduation COMPLETE;
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
  { [ -n "$1" ] && printf '%s\n' "$1"; printf '# PROJECT.md\n\n%s\n' "$2"; } > "$SB_WORK/PROJECT.md"
  publish_sandbox
  _cb_fill_out="$(cb_run | _cb_g_section)"
}
case_check_board_fill_arm_reads_blanks_not_usage() {
  cf_reset
  make_sandbox
  printf '# my project\n' > "$SB_WORK/CLAUDE.md"
  printf '# my project\n' > "$SB_WORK/README.md"
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
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
# comes back UNMEASURED (no REPLACE declaration anywhere, no PROJECT.md, and neither non-markdown
# FILL member present either) must not print "graduation COMPLETE": nothing was checked, and that is
# not a pass. This case ablates the refusal to show it is the mechanism holding COMPLETE back, not
# an accident of wording.
# =============================================================================
case_check_board_graduation_refuses_complete_over_nothing_measured() {
  cf_reset
  make_sandbox
  # A lived signal (a card on the board) with NO REPLACE-declaring file, NO PROJECT.md, and NO
  # .gitignore/.env.example in this sandbox at all (make_sandbox does not seed them) — every
  # measurable class in arm [g] is therefore UNREADABLE, not merely clean.
  seed_issue todo "$SB_PREFIX-430" nothingtomeasure chore "Nothing here to measure"
  publish_sandbox

  local out
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'enabled by:' >/dev/null \
    || cf "precondition: the arm must be ENABLED for this case to mean anything: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    && cf "the arm printed graduation COMPLETE over a tree where nothing was measured (no REPLACE population, no PROJECT.md, no non-markdown FILL member) — this is the false green the card exists to close: $out"
  printf '%s\n' "$out" | _cb_g_section | grep -iE 'measured: 0 member' >/dev/null \
    || cf "the arm did not print its measured population as zero: $out"
  printf '%s\n' "$out" | _cb_g_section | grep -i 'CANNOT SAY graduation is complete' >/dev/null \
    || cf "the arm did not refuse the COMPLETE claim in words a reader would notice: $out"

  # ── THE ABLATION: with the refusal's guard removed, COMPLETE returns on the SAME tree. ────────
  # Proves the new line is load-bearing, not merely present. `-eq 0` is the guard; forcing it
  # false (`-eq 999`) restores the pre-fix behaviour without touching anything else.
  local abl
  abl="$SB_WORK/scripts/check-board-ablated.sh"
  sed 's/\[ "\$g_measured" -eq 0 \]/[ "$g_measured" -eq 999 ]/' "$SB_WORK/scripts/check-board.sh" > "$abl"
  chmod +x "$abl"
  grep -q '\-eq 999' "$abl" \
    || _control_did_not_run "the ablation did not change check-board.sh's guard — the sed anchor no longer matches the source"
  local abl_out
  abl_out="$(cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR ./scripts/check-board-ablated.sh 2>&1)"
  rm -f "$abl"
  printf '%s\n' "$abl_out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    || _control_did_not_run "with the zero-measured refusal ablated, COMPLETE did not return on the same tree — the case is not isolating the guard it claims to: $abl_out"

  finish "arm [g] prints its measured population and REFUSES 'graduation COMPLETE' when nothing was measured (no REPLACE population, no PROJECT.md, no FILL member present) — ablating the guard restores the false COMPLETE on the same tree, proving the refusal is load-bearing"
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
  printf '# my project\n' > "$SB_WORK/CLAUDE.md"
  printf '# my project\n' > "$SB_WORK/README.md"
  printf '<!-- FILLED. -->\n# PROJECT.md\n\nTrunk: main\n' > "$SB_WORK/PROJECT.md"
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"

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
