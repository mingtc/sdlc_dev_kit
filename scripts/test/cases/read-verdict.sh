# KIT-CLASS: MIXED — self-test harness, the read-only verdict reader. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/read-verdict.sh — sourced by scripts/test/run.sh, never run on its own.
# read-verdict.sh prints a card's column on the trunk and each QA Verdict row's verdict, read
# through lib/qa-gate.sh, and says whether the landing gate would accept the table.
# =============================================================================

# =============================================================================
# CASE — read-verdict.sh READS THE TRUNK'S COPY, AND WRITES NOTHING.
# A landed card with PASS rows, a direct-to-trunk card in qa_complete/ with a FAIL row, and a card
# only in a local commit. Cards are on the trunk before they are read, the third one after.
# RED FIRST: fails on a tree with no scripts/read-verdict.sh.
# =============================================================================
case_read_verdict_reads_the_trunk_and_writes_nothing() {
  cf_reset
  make_sandbox

  local ok="$SB_PREFIX-661" bad="$SB_PREFIX-662" off="$SB_PREFIX-663"
  seed_issue qa_complete "$ok" landed chore "Landed, PASS rows" "feature/$ok-work"
  seed_issue qa_complete "$bad" direct chore "Direct to the trunk, FAIL row" "n/a"
  perl -i -pe 's/^(\| AC1 \| )PASS( \| test \|.*\|)$/${1}FAIL_AC${2}/' "$SB_WORK/progress/qa_complete/$bad-direct.md"
  grep -qF '| AC1 | FAIL_AC |' "$SB_WORK/progress/qa_complete/$bad-direct.md" \
    || _fixture_die "case_read_verdict_reads_the_trunk_and_writes_nothing: the FAIL_AC row was not planted"
  publish_sandbox
  seed_issue dev_complete "$off" local chore "In a local commit only" "n/a"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[PM] local-only card" --quiet >/dev/null 2>&1

  [ -x "$SB_WORK/scripts/read-verdict.sh" ] \
    || { cf "scripts/read-verdict.sh does not exist or is not executable"; finish "read-verdict.sh reads the trunk's copy of a card and writes nothing"; teardown; return; }

  local before after out rc
  before="$(git -C "$SB_WORK" status --porcelain 2>&1)|$(find "$SB_WORK/progress" "$SB_WORK/.progress-records" -type f 2>/dev/null | sort | tr '\n' ' ')|$(git -C "$SB_WORK" rev-parse HEAD)"

  out="$( cd "$SB_WORK" && ./scripts/read-verdict.sh "$ok" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) the landed card: exit $rc, want 0: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  case "$out" in *"column: qa_complete"*) : ;; *) cf "(a) no 'column: qa_complete': $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  printf '%s\n' "$out" | grep -E '^ +AC1 +PASS$' >/dev/null || cf "(a) no AC1 PASS row: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  case "$out" in *"would ACCEPT"*) : ;; *) cf "(a) the gate's verdict is not ACCEPT: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac

  out="$( cd "$SB_WORK" && ./scripts/read-verdict.sh "$bad" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) the FAIL card: exit $rc, want 0 — a FAIL row is printed, not refused"
  case "$out" in *"column: qa_complete"*) : ;; *) cf "(b) no 'column: qa_complete': $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  printf '%s\n' "$out" | grep -E '^ +AC1 +FAIL_AC$' >/dev/null || cf "(b) no AC1 FAIL_AC row: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  case "$out" in *"would REFUSE"*"qa-verdict-fail"*) : ;; *) cf "(b) no would-REFUSE line naming qa-verdict-fail: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac

  after="$(git -C "$SB_WORK" status --porcelain 2>&1)|$(find "$SB_WORK/progress" "$SB_WORK/.progress-records" -type f 2>/dev/null | sort | tr '\n' ' ')|$(git -C "$SB_WORK" rev-parse HEAD)"
  [ "$before" = "$after" ] || cf "reading changed the tree, the board, .progress-records/ or HEAD: before [$before] after [$after]"

  out="$( cd "$SB_WORK" && env -u KIT_PROGRESS_DIR ./scripts/read-verdict.sh "$off" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(c) a card only in a local commit: exit 0, want non-zero — it has no verdict on the trunk"
  case "$out" in *"Next:"*) : ;; *) cf "(c) the refusal names no next step: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  grep -q 'refusal=card-not-on-trunk' "$SB_WORK/.progress-records"/*.tsv 2>/dev/null \
    || cf "(c) no refusal=card-not-on-trunk record for the unreadable card"

  out="$( cd "$SB_WORK" && ./scripts/read-verdict.sh --help 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(d) --help exited $rc, want 0"
  case "$out" in *"READ-ONLY"*) : ;; *) cf "(d) --help does not say it is read-only" ;; esac

  finish "read-verdict.sh prints a landed card's column and PASS rows, a direct-to-trunk FAIL card's column, row and the gate's would-REFUSE line, exits 0 for both and non-zero for a card not on the trunk, and leaves the tree, the board and .progress-records/ unchanged"
  teardown
}

# =============================================================================
# CASE — read-verdict.sh SAYS WHY A DEFERRED PASS READS REFUSE.
# A card in dev_complete/ whose evidence is a file that exists only on its (unlanded) branch is
# refused by the gate, which reads the trunk; the output names that as expected. The same table in
# qa_complete/ is a plain REFUSE with no such note, so the note is not printed for every refusal.
# RED FIRST: fails on a read-verdict.sh that prints no note.
# =============================================================================
case_read_verdict_names_the_deferred_landing() {
  cf_reset
  make_sandbox

  local def="$SB_PREFIX-684" landed="$SB_PREFIX-702" f
  seed_issue dev_complete "$def" deferred chore "Deferred landing, evidence on its branch" "feature/$def-work"
  seed_issue qa_complete "$landed" bad chore "Landed, evidence missing" "n/a"
  for f in "$SB_WORK/progress/dev_complete/$def-deferred.md" "$SB_WORK/progress/qa_complete/$landed-bad.md"; do
    perl -i -pe 's/^(\| AC1 \| PASS \| test \| ).*$/${1}src\/feature.js:3 "return value + 1" |/' "$f"
    grep -qF 'src/feature.js:3 "return value + 1"' "$f" \
      || _fixture_die "case_read_verdict_names_the_deferred_landing: the branch-only pointer was not planted in $f"
  done
  publish_sandbox

  [ -x "$SB_WORK/scripts/read-verdict.sh" ] \
    || { cf "scripts/read-verdict.sh does not exist or is not executable"; finish "read-verdict.sh names a deferred landing"; teardown; return; }

  local out rc
  out="$( cd "$SB_WORK" && ./scripts/read-verdict.sh "$def" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) the deferred card: exit $rc, want 0"
  case "$out" in *"column: dev_complete"*"would REFUSE"*) : ;; *) cf "(a) no dev_complete column with a would-REFUSE line: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)" ;; esac
  case "$out" in *"note: "*"dev_complete/"*"on its branch"*"expected"*) : ;; *) cf "(a) a dev_complete REFUSE carries no note that a deferred landing's evidence is on its branch: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)" ;; esac

  out="$( cd "$SB_WORK" && ./scripts/read-verdict.sh "$landed" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) the landed card: exit $rc, want 0"
  case "$out" in *"would REFUSE"*) : ;; *) cf "(b) no would-REFUSE line for the unresolved pointer: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)" ;; esac
  case "$out" in *"note: "*) cf "(b) a qa_complete REFUSE carries the deferred-landing note: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)" ;; *) : ;; esac

  finish "read-verdict.sh notes, on a would-REFUSE for a card in dev_complete/, that a deferred landing's evidence is on its branch, and prints no such note for a card in qa_complete/"
  teardown
}
