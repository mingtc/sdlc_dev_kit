# KIT-CLASS: MIXED — self-test harness, archive cases. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/archive.sh — sourced by scripts/test/run.sh, never run on its own.
# archive.sh and archive-progress.sh: the sweep, its index, rotation day.
# =============================================================================

# =============================================================================
# CASE — A CONTRADICTORY --apply/--dry-run PAIR REFUSES, IN EITHER ORDER.
#
# Both orders must refuse at status 2 before anything moves. The exit code is not the
# assertion: the case reads the board, the local HEAD and the remote. The control proves a
# plain `--apply` still sweeps, so the refusal is not a broken tool. The bare invocation
# stays the preview (contracts/archive-sweep.md § 2).
# =============================================================================
case_archive_hedged_flags_never_mutate() {
  cf_reset
  local out rc before card

  _hedge_leg() {  # <flag1> <flag2> <label>
    make_sandbox
    seed_issue qa_complete "$SB_PREFIX-260" hedge chore "Hedged sweep"
    publish_sandbox
    grep -q '^## Archived$' "$SB_WORK/ARCHIVE.md" 2>/dev/null \
      || _fixture_die "case_archive_hedged_flags_never_mutate: no '## Archived' heading — archive.sh would refuse for THAT reason and every 'nothing moved' assertion below would pass for the wrong one."
    before="$(git -C "$SB_WORK" rev-parse HEAD)"
    rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" "$1" "$2" 2>&1 )" || rc=$?
    [ "$rc" -eq 2 ] \
      || cf "($3) a contradictory pair exited $rc, want 2 — the published usage status: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"
    printf '%s\n' "$out" | grep -i 'contradictory' >/dev/null \
      || cf "($3) the refusal does not say the flags contradict: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"
    [ -f "$SB_WORK/progress/qa_complete/$SB_PREFIX-260-hedge.md" ] \
      || cf "($3) the card LEFT qa_complete/ — the hedge mutated"
    [ -f "$SB_WORK/progress/done/$SB_PREFIX-260-hedge.md" ] \
      && cf "($3) the card reached done/"
    grep -q "$SB_PREFIX-260" "$SB_WORK/ARCHIVE.md" 2>/dev/null \
      && cf "($3) ARCHIVE.md gained an index entry during a refusal"
    [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$before" ] \
      || cf "($3) a commit was created during a refusal"
    origin_has_path "progress/done/$SB_PREFIX-260-hedge.md" \
      && cf "($3) the sweep reached the REMOTE trunk"
    teardown
  }

  _hedge_leg --apply --dry-run "apply-then-dry"
  _hedge_leg --dry-run --apply "dry-then-apply"

  # ── INSTRUMENT CHECK. Every assertion above is "nothing happened", which a sweep
  #    broken for ANY reason satisfies. The same fixture with a plain --apply must SWEEP.
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-261" plain chore "Plain sweep"
  publish_sandbox
  rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] \
    || cf "(control) a plain --apply exited $rc — the refusals above may be a broken sweep rather than a guard: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"
  origin_has_path "progress/done/$SB_PREFIX-261-plain.md" \
    || cf "(control) a plain --apply did not reach the trunk — this case cannot tell a refusal from a no-op"
  teardown

  unset -f _hedge_leg
  finish "archive.sh: a contradictory --apply/--dry-run pair refuses at status 2 in EITHER order with the board, the local HEAD and the remote all unchanged — and a plain --apply on the same fixture still sweeps"
}

# =============================================================================
# CASE — A ONE-MEMBER ROLE TAG REFUSES BEFORE IT MUTATES.
#
# archive.sh commits under one member of the role set (ARCHIVE_ROLE). When the declared set
# no longer holds it, the sweep must refuse before it moves anything. The exit code is not
# the assertion: without the guard the hook rejects the commit and the script still exits
# nonzero. What reddens is the restore control: the refused run leaves uncommitted state in
# the shared kanban worktree, and the next board operation dies on it. The trunk assertions
# catch a variant where the move reaches the trunk.
#
# Narrow the hook's declared set, not the knob: setting ARCHIVE_ROLE proves only that the
# knob is read.
# =============================================================================
case_one_member_role_tag_refuses_before_mutating() {
  cf_reset
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-300" alpha chore "Archive alpha"
  publish_sandbox

  local cm="$SB_WORK/scripts/githooks/commit-msg" narrow='PM|Dev' out rc=0
  # PM and Dev are kept because the fixtures commit under both. EVERY FIXTURE MUTATION
  # ASSERTS: a perl -i whose pattern misses exits 0 and leaves the file byte-identical.
  NEU_NEW="$narrow" perl -i -pe "s@^ROLE_PREFIXES='.*'\$@ROLE_PREFIXES='\$ENV{NEU_NEW}'@" "$cm"
  grep -qxF "ROLE_PREFIXES='$narrow'" "$cm" \
    || _fixture_die "case_one_member_role_tag_refuses_before_mutating: the narrowed role set did not land in the sandbox's commit-msg — the refusal below would be tested against the shipped set, which CONTAINS the tag, and the case would prove nothing."
  printf '%s\n' "$narrow" | tr '|' '\n' | grep -x Orchestrator >/dev/null \
    && _fixture_die "case_one_member_role_tag_refuses_before_mutating: the narrowed set still contains the tag archive.sh writes — the premise of this case is gone."
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[PM] narrow the declared role set" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1

  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "archive.sh --apply exited 0 with a role tag the project's hook does not accept"
  # THE EFFECT, ON THE AUTHORITATIVE STATE — this is the assertion the exit code cannot make.
  origin_has_path "progress/qa_complete/$SB_PREFIX-300-alpha.md" \
    || cf "the card left qa_complete/ on the trunk even though the sweep's commit could not be made"
  origin_has_path "progress/done/$SB_PREFIX-300-alpha.md" \
    && cf "the card reached done/ — the sweep MUTATED and only the commit failed, which is the uncommitted-state-in-a-discarded-worktree loss this refusal exists to prevent"
  printf '%s\n' "$out" | grep 'ARCHIVE_ROLE' >/dev/null \
    || cf "the refusal does not name the knob that would fix it: $(printf '%s' "$out" | tr '\n' '|')"

  # ── INSTRUMENT CHECK. "Nonzero and nothing moved" is satisfied by an archive.sh
  #    broken for ANY reason. Restore the declared set and the SAME invocation must work.
  NEU_NEW="$KIT_NEUTRAL_ROLE_PREFIXES" perl -i -pe "s@^ROLE_PREFIXES='.*'\$@ROLE_PREFIXES='\$ENV{NEU_NEW}'@" "$cm"
  grep -qxF "ROLE_PREFIXES='$KIT_NEUTRAL_ROLE_PREFIXES'" "$cm" \
    || _fixture_die "case_one_member_role_tag_refuses_before_mutating: the role set was not restored — the control below cannot run."
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[PM] restore the shipped role set" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] \
    || cf "(control) archive.sh --apply still exited $rc with the shipped role set restored — the refusal above was not about the role tag: $(printf '%s' "$out" | tr '\n' '|')"
  origin_has_path "progress/done/$SB_PREFIX-300-alpha.md" \
    || cf "(control) the card did not reach done/ with a legal role tag — this case cannot tell a role refusal from a broken sweep"

  finish "one-member role tags: archive.sh refuses BEFORE mutating when its tag is not in the declared set, names ARCHIVE_ROLE, leaves the card on the trunk untouched, and sweeps normally once the tag is legal again"
  teardown
}

# =============================================================================
# CASE — archive.sh --apply indexes + moves to done/
# =============================================================================
case_archive_apply() {
  cf_reset
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-200" alpha chore "Archive alpha"
  seed_issue qa_complete "$SB_PREFIX-201" beta  chore "Archive beta"
  publish_sandbox

  local out rc
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )"; rc=$?

  [ "$rc" -eq 0 ] || cf "archive.sh --apply exited $rc: $out"
  grep -q "$SB_PREFIX-200" "$SB_WORK/ARCHIVE.md" || cf "$SB_PREFIX-200 not indexed in ARCHIVE.md"
  grep -q "$SB_PREFIX-201" "$SB_WORK/ARCHIVE.md" || cf "$SB_PREFIX-201 not indexed in ARCHIVE.md"
  [ -f "$SB_WORK/progress/done/$SB_PREFIX-200-alpha.md" ] || cf "$SB_PREFIX-200 not moved into done/"
  [ -f "$SB_WORK/progress/done/$SB_PREFIX-201-beta.md" ]  || cf "$SB_PREFIX-201 not moved into done/"
  [ -f "$SB_WORK/progress/qa_complete/$SB_PREFIX-200-alpha.md" ] && cf "$SB_PREFIX-200 still in qa_complete/"

  finish "archive.sh --apply: index in ARCHIVE.md + move into done/"
  teardown
}

# =============================================================================
# THE INDEX INSERT MUST REFUSE A MALFORMED INDEX, not mis-write it
# =============================================================================
# The insert reprints the line after the header as the separator, so an index with no
# separator loses its first data row into that slot and the new row lands second. Both
# fixtures are hand-written, because the script under test only produces the well-formed
# shape. A refusal is not enough: the file must be byte-unchanged, and the well-formed half
# rules out an unconditional refusal.
_ap_seed_small_log() {  # <repo>
  { echo "# progress.md"; echo ""; echo "## Log"; echo ""
    echo "## 2026-08-20 [Dev] one"; echo "body"; echo ""
    echo "## 2026-08-21 [Dev] two"; echo "body"; echo ""
  } > "$1/progress.md"
}

case_archive_index_refuses_malformed() {
  cf_reset
  make_sandbox
  local R="$SB_TMP/apm" out rc before
  mkdir -p "$R/progress/history"

  # ── A. MALFORMED: header present, NO separator, a real data row underneath.
  _ap_seed_small_log "$R"
  cat > "$R/progress/history/INDEX.md" <<'IDXEOF'
# rotation index

| Chunk | Covers | Entries | Rotated | Cut |
| [`old.md`](old.md) | 2026-01-01 → 2026-01-02 | 5 | 2026-01-03 | `--before 2026-01-03` |
IDXEOF
  before="$(mktemp)"; cp "$R/progress/history/INDEX.md" "$before"
  cp "$R/progress.md" "$SB_TMP/progress.before"

  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" \
            --milestone mal --keep-last 1 --apply 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(A) a malformed index did NOT refuse — exit 0: $out"
  printf '%s' "$out" | grep 'MALFORMED' >/dev/null \
    || cf "(A) the refusal does not name the file as malformed: $out"
  printf '%s' "$out" | grep -F 'old.md' >/dev/null \
    || cf "(A) the refusal does not quote the offending line it found — a drift reported without saying what drifted sends the reader to diff by eye: $out"
  # THE LOAD-BEARING ASSERTION: the failure under test is a WRITE, so proving it
  # refused is not proving it did not write.
  diff -q "$before" "$R/progress/history/INDEX.md" >/dev/null 2>&1 \
    || cf "(A) the index was MODIFIED on a run that refused — the malformed file was mis-written anyway"
  # And it must not have helpfully repaired the file by inserting a separator.
  grep -qF '|---|' "$R/progress/history/INDEX.md" \
    && cf "(A) it inserted the separator itself — the index is the adopter's record, not the tool's to repair"
  # Nor the log and the chunk: a refusal writes nothing.
  cmp -s "$SB_TMP/progress.before" "$R/progress.md" || cf "(A) progress.md was rewritten on a run that refused"
  [ ! -e "$R/progress/history/mal.md" ] || cf "(A) the chunk was written on a run that refused"
  printf '%s' "$out" | grep -F 'ARE ON DISK' >/dev/null && cf "(A) the refusal still says the chunk and the log ARE ON DISK"
  rc=0; "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone mal --keep-last 1 >/dev/null 2>&1 || rc=$?
  [ "$rc" -ne 0 ] || cf "(A) the dry run exited 0 on the index --apply refuses"
  rm -f "$before"

  # ── C. NO HEADER ROW: refuses naming it, and writes nothing.
  _ap_seed_small_log "$R"; cp "$R/progress.md" "$SB_TMP/progress.before"
  printf '# rotation index\n\nno table here\n' > "$R/progress/history/INDEX.md"
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" \
            --milestone nohdr --keep-last 1 --apply 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(C) an index with no header row did NOT refuse"
  printf '%s' "$out" | grep 'no recognisable insertion point' >/dev/null \
    || cf "(C) the refusal did not say why: $(printf '%s' "$out" | tail -2 | tr '\n' '|')"
  cmp -s "$SB_TMP/progress.before" "$R/progress.md" || cf "(C) progress.md was rewritten on a run that refused"
  [ ! -e "$R/progress/history/nohdr.md" ] || cf "(C) the chunk was written on a run that refused"

  # ── B. WELL-FORMED: must still insert, and FIRST. Without this half, a script that
  #      refused unconditionally would pass (A) and look correct.
  rm -rf "$R"; mkdir -p "$R/progress/history"
  _ap_seed_small_log "$R"
  cat > "$R/progress/history/INDEX.md" <<'IDXEOF'
# rotation index

| Chunk | Covers | Entries | Rotated | Cut |
|---|---|---|---|---|
| [`old.md`](old.md) | 2026-01-01 → 2026-01-02 | 5 | 2026-01-03 | `--before 2026-01-03` |
IDXEOF
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" \
            --milestone good --keep-last 1 --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(B) a WELL-FORMED index was refused — exit $rc: $out"
  local first_row
  first_row="$(grep -m1 '^| \[' "$R/progress/history/INDEX.md")"
  printf '%s' "$first_row" | grep -F 'good.md' >/dev/null \
    || cf "(B) the new row is not first (newest-first is format law): $first_row"
  grep -qF 'old.md' "$R/progress/history/INDEX.md" \
    || cf "(B) the pre-existing row was lost — the index is append-only"

  finish "archive-progress.sh: a MALFORMED or header-less index refuses, dry run included, with it, progress.md and the chunk all unwritten, and the index un-repaired; a well-formed one still inserts newest-first"
  teardown
}

# =============================================================================
# CASE — THE ARCHIVE INDEX CARRIES A RETIREMENT DATE (both directions).
#
# archive-sweep.md § 2: an index entry carries the identifier, the title and the retirement
# date. With the date write ablated, the assertion must fail.
# =============================================================================
case_archive_index_carries_the_date() {
  cf_reset
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-250" dated chore "Dated retirement"
  publish_sandbox

  local out rc entry today preview
  today="$(date +%Y-%m-%d)"
  # The dry run first, while the item is still on the board: its previewed entry is compared below.
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "the dry run exited $rc: $out"
  preview="$(printf '%s\n' "$out" | grep -E "^- $SB_PREFIX-250 " || true)"
  [ -n "$preview" ] || cf "the dry run previewed no entry for $SB_PREFIX-250: $out"
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "archive.sh --apply exited $rc: $out"
  entry="$(grep "$SB_PREFIX-250" "$SB_WORK/ARCHIVE.md" || true)"
  [ -n "$entry" ] || cf "$SB_PREFIX-250 was not indexed at all: $(cat "$SB_WORK/ARCHIVE.md")"
  printf '%s' "$entry" | grep -E 'retired [0-9]{4}-[0-9]{2}-[0-9]{2}' >/dev/null \
    || cf "the index entry carries no retirement date — § 2 requires the date beside the id and title: $entry"
  printf '%s' "$entry" | grep "retired $today" >/dev/null \
    || cf "the retirement date is not today's ($today): $entry"
  # The id stays the FIRST token: next-id.sh reads `- <PREFIX>-NNN …` entries so that a new
  # mint cannot collide with an archived id.
  printf '%s' "$entry" | grep -E "^- $SB_PREFIX-250 " >/dev/null \
    || cf "the entry no longer begins '- $SB_PREFIX-250 ' — next-id.sh reads this shape to avoid re-minting an archived id: $entry"
  [ "$preview" = "$entry" ] \
    || cf "the dry run previewed an entry the apply did not write — preview: $preview | written: $entry"

  # --- ABLATION: remove the date write and the assertion above must fail -----
  local a_script="$SB_WORK/scripts/archive.sh" n
  # -F: both operands carry a mid-pattern `$`, which grep implementations read differently.
  n="$(grep -cF 'ENTRY="${ENTRY} — retired ${RETIRED_ON}"' "$a_script" || true)"
  if [ "$n" != "1" ]; then
    cf "(control) expected exactly 1 date-append line in archive.sh to ablate, found $n — the anchor moved and this ablation proves nothing"
  else
    # TEARDOWN FIRST: make_sandbox sets SB_TMP afresh, so the first sandbox must go now.
    teardown
    make_sandbox
    seed_issue qa_complete "$SB_PREFIX-251" ablated chore "Ablated retirement"
    perl -i -ne 'print unless /^\s*ENTRY="\$\{ENTRY\} — retired \$\{RETIRED_ON\}"\s*$/' "$SB_WORK/scripts/archive.sh"
    grep -F 'retired ${RETIRED_ON}' "$SB_WORK/scripts/archive.sh" >/dev/null \
      && cf "(control) the ablation did not remove the date write"
    bash -n "$SB_WORK/scripts/archive.sh" || cf "(control) the ablated archive.sh no longer parses"
    publish_sandbox
    out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )"; rc=$?
    [ "$rc" -eq 0 ] || cf "(control) the ablated archive.sh exited $rc — the ablation broke more than the date: $out"
    entry="$(grep "$SB_PREFIX-251" "$SB_WORK/ARCHIVE.md" || true)"
    printf '%s' "$entry" | grep -E 'retired [0-9]{4}-[0-9]{2}-[0-9]{2}' >/dev/null \
      && cf "(control) the ABLATED script still produced a retirement date — the assertion above is not measuring the date write: $entry"
  fi

  finish "archive.sh: the index entry carries its retirement date (§ 2) with the id still leading, preview and apply agree, and the assertion fails when the date write is ablated"
  teardown
}

# =============================================================================
# CASE — THE RETIRED STORE IS REQUIRED, NOT MANUFACTURED (both directions).
#
# archive-sweep.md § 3: a missing retired store refuses. Creating it would invent a column,
# and the container is the status (board-mover.md). The refusal must create nothing, and a
# board that has the column must still archive, or an unconditional refusal would pass.
# =============================================================================
case_archive_requires_the_retired_store() {
  cf_reset

  # --- (i) the store is ABSENT: refuse, and create nothing -------------------
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-260" nostore chore "No retired store"
  rm -rf "$SB_WORK/progress/done"
  publish_sandbox
  [ ! -d "$SB_WORK/progress/done" ] \
    || cf "(control) progress/done/ still exists locally — the premise of half (i) does not hold"

  local out rc kwt_done
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(i) archive.sh --apply SUCCEEDED with no progress/done/ — it manufactured the column: $out"
  printf '%s\n' "$out" | grep -i 'progress/done' >/dev/null \
    || cf "(i) the refusal does not name the absent store: $out"
  printf '%s\n' "$out" | grep -i 'REFUSING' >/dev/null \
    || cf "(i) the message does not say it is refusing: $out"
  printf '%s\n' "$out" | grep '\.gitkeep' >/dev/null \
    || cf "(i) the refusal does not print the deliberate creation recipe (a bare refusal leaves the operator to invent one, and an empty dir does not survive a clone): $out"
  # AND IT CREATED NOTHING, checked in the kanban worktree too, where the script operates.
  kwt_done="$SB_WORK/.kanban-wt/progress/done"
  [ ! -d "$SB_WORK/progress/done" ] || cf "(i) the refusal still created progress/done/ in the checkout"
  [ ! -d "$kwt_done" ] || cf "(i) the refusal still created progress/done/ inside the kanban worktree"
  [ -f "$SB_WORK/progress/qa_complete/$SB_PREFIX-260-nostore.md" ] \
    || cf "(i) the card left qa_complete/ during a refusal"
  # A dirty board worktree makes every later board command refuse, including this one.
  [ -z "$(git -C "$SB_WORK/.kanban-wt" status --porcelain 2>&1)" ] \
    || cf "(i) the refusal left the kanban worktree dirty: $(git -C "$SB_WORK/.kanban-wt" status --porcelain 2>&1 | tr '\n' '|')"
  # The preview must not promise a sweep that --apply refuses.
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --dry-run 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(i) --dry-run exited 0 with no progress/done/, previewing a sweep --apply refuses: $out"
  teardown

  # --- (ii) the store is PRESENT: archive normally ---------------------------
  # Without this half, an unconditional refusal would pass half (i).
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-261" hasstore chore "Has retired store"
  [ -d "$SB_WORK/progress/done" ] || cf "(control) the sandbox has no progress/done/ — half (ii) cannot test the happy path"
  publish_sandbox
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(ii) archive.sh --apply exited $rc on a board that HAS done/ — the refusal is unconditional: $out"
  [ -f "$SB_WORK/progress/done/$SB_PREFIX-261-hasstore.md" ] \
    || cf "(ii) the card was not moved into done/: $out"
  grep -q "$SB_PREFIX-261" "$SB_WORK/ARCHIVE.md" || cf "(ii) the card was not indexed: $out"

  finish "archive.sh: an absent retired store REFUSES, names it, prints the .gitkeep creation recipe, creates nothing and leaves the kanban worktree clean, and --dry-run refuses too — while a board that has done/ still archives normally"
  teardown
}

# =============================================================================
# CASE — a card or subtask tree whose name is already retired refuses before anything is written
#
# `git mv` onto an existing done/ file fails after ARCHIVE.md is rewritten, and under `set -e`
# the sweep stops there, leaving the shared board worktree dirty. Onto an existing
# done/subtasks/<parent>/ it succeeds, nesting the tree. --dry-run refuses too.
# =============================================================================
case_archive_refuses_a_name_already_retired() {
  cf_reset
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-270" twice chore "Retired twice"
  cp "$SB_WORK/progress/qa_complete/$SB_PREFIX-270-twice.md" "$SB_WORK/progress/done/"
  publish_sandbox
  local out rc
  rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "--apply exited 0 with $SB_PREFIX-270-twice.md already in done/"
  printf '%s' "$out" | grep -F "$SB_PREFIX-270-twice.md" >/dev/null || cf "the refusal does not name the colliding card: $(printf '%s' "$out" | tail -3 | tr '\n' '|')"
  [ -z "$(git -C "$SB_WORK/.kanban-wt" status --porcelain 2>&1)" ] \
    || cf "the refusal left the kanban worktree dirty: $(git -C "$SB_WORK/.kanban-wt" status --porcelain 2>&1 | tr '\n' '|')"
  rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --dry-run 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "--dry-run exited 0, previewing a sweep --apply refuses"
  teardown

  # (tree) A done/ parent's live subtask tree whose done/subtasks/<parent>/ already exists:
  # `git mv` would move it INTO that directory rather than fail.
  make_sandbox
  local p="$SB_PREFIX-280"
  seed_issue qa_complete "$SB_PREFIX-281" sweepme chore "Something to sweep"
  seed_issue done "$p" parent chore "Retired parent"
  mkdir -p "$SB_WORK/progress/done/subtasks/$p/qa_complete" "$SB_WORK/progress/subtasks/$p/qa_complete"
  seed_issue "done/subtasks/$p/qa_complete" "$p-s1" old chore "Retired slice"
  seed_issue "subtasks/$p/qa_complete" "$p-s2" late chore "Late slice"
  publish_sandbox
  rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(tree) --apply exited 0 with progress/done/subtasks/$p/ already present"
  origin_has_path "progress/done/subtasks/$p/$p/qa_complete/$p-s2-late.md" && cf "(tree) the tree was moved INTO done/subtasks/$p/, nested"
  printf '%s' "$out" | grep -F "subtasks/$p" >/dev/null || cf "(tree) the refusal does not name the tree: $(printf '%s' "$out" | tail -2 | tr '\n' '|')"
  [ -z "$(git -C "$SB_WORK/.kanban-wt" status --porcelain 2>&1)" ] || cf "(tree) the refusal left the kanban worktree dirty"
  rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --dry-run 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(tree) --dry-run exited 0, previewing a sweep --apply refuses"

  finish "archive.sh: a card or a subtask tree whose name is already in done/ refuses before any write, naming it, and --dry-run refuses too"
  teardown
}

# =============================================================================
# CASE — archive.sh --apply from a FEATURE BRANCH leaves that branch's tree clean
# (it routes through .kanban-wt, never the operator's checkout).
# =============================================================================
case_archive_feature_branch_clean() {
  cf_reset
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-202" gamma chore "Archive gamma"
  publish_sandbox
  git -C "$SB_WORK" checkout -b "feature/$SB_PREFIX-999-work" "$SB_TRUNK" --quiet >/dev/null 2>&1

  local out rc
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )"; rc=$?

  [ "$rc" -eq 0 ] || cf "archive.sh --apply exited $rc: $out"
  local dirty
  dirty="$(git -C "$SB_WORK" status --porcelain -- progress ARCHIVE.md 2>/dev/null)"
  [ -z "$dirty" ] || cf "feature branch tree dirty after the sweep: $dirty"
  origin_has_path "progress/done/$SB_PREFIX-202-gamma.md" || cf "sweep not visible on the trunk"

  finish "archive.sh --apply from a feature branch leaves its tree clean"
  teardown
}

# =============================================================================
# CASE — archive-progress.sh rotates a mixed-format progress.md BYTE-COMPLETE.
#
# Entries under a dated section header with undated sub-bullets must reach the retained log
# or the chunk, never neither. The proof: split the new progress.md at "## Log", splice the
# chunk (minus its YAML header) between the halves, and it must equal the original.
# =============================================================================
case_archive_progress_sections() {
  cf_reset
  make_sandbox   # only for SB_TMP + teardown; this case uses --repo-root
  local R="$SB_TMP/ap"
  mkdir -p "$R/progress/history"

  # THE FIXTURE CARRIES ALL THREE BOUNDARY FORMS, IN THEIR REAL NESTING ORDER. The post-cutoff
  # entry has its own `## ` heading: a `## DATE` section owns every line until the next `## `,
  # so a post-cutoff bullet inside a pre-cutoff section is correctly archived with it.
  cat > "$R/progress.md" <<'EOF'
# progress.md

Preamble line, not part of the Log.

## Log

### 2026-07-19
- undated sub-bullet Z under the date-at-EOL section header

### 2026-07-20 — Old section-header entry (undated sub-bullets)
- undated sub-bullet A under the section
- undated sub-bullet B under the section

- 2026-07-21 [Dev] a bare dated bullet, the flattest form (pre-cutoff)

## 2026-07-22 [Dev] a modern top-level session heading (pre-cutoff)
- a bullet inside it
### 2026-07-23 nested under the modern heading
- a nested bullet

## 2026-07-28 [QA] a modern post-cutoff session heading (retained)
- a retained bullet inside it
EOF
  cp "$R/progress.md" "$R/original.md"

  local out rc
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" \
            --milestone mix --before 2026-07-25 --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "--apply exited $rc (expected 0): $out"

  local chunk="$R/progress/history/mix.md"
  if [ ! -f "$chunk" ]; then
    cf "--apply produced no history chunk (aborted before writing?)"
    finish "archive-progress.sh: byte-complete rotation of a mixed-format log"
    teardown; return
  fi

  local recon="$R/reconstructed.md"
  {
    sed -n '1,/^## Log[[:space:]]*$/p' "$R/progress.md"   # preamble (through "## Log")
    sed '1,6d' "$chunk"                                    # archived pre (strip the YAML header)
    sed '1,/^## Log[[:space:]]*$/d' "$R/progress.md"       # retained post
  } > "$recon"
  if ! diff -q "$R/original.md" "$recon" >/dev/null 2>&1; then
    cf "reconstruction != original — $(diff "$R/original.md" "$recon" | grep -c '^<') line(s) lost"
  fi

  # The reported count must mirror the awk routing, including a dated header whose date ends
  # the line.
  local reported routed
  reported="$(printf '%s\n' "$out" | sed -n 's/^Found \([0-9][0-9]*\) entries.*/\1/p')"
  routed="$(grep -cE '^## [0-9]{4}-[0-9]{2}-[0-9]{2}|^### [0-9]{4}-[0-9]{2}-[0-9]{2}|^(- )?[0-9]{4}-[0-9]{2}-[0-9]{2} ' "$chunk")"
  [ "$reported" = "$routed" ] \
    || cf "count != routed: it reported '$reported' but the awk routed '$routed' boundaries"
  grep -qxF '### 2026-07-19' "$chunk" || cf "the date-at-EOL header is missing from the history chunk"
  grep -qF -- '- undated sub-bullet A under the section' "$chunk" \
    || cf "an undated sub-bullet under a dated section header is missing from the chunk"
  grep -qF -- '- 2026-07-21 [Dev] a bare dated bullet' "$chunk" \
    || cf "the flat bare-bullet form is missing from the chunk"
  grep -qF -- '- a nested bullet' "$chunk" \
    || cf "a bullet nested under a modern top-level heading is missing from the chunk"
  # The post-cutoff SECTION and its body are RETAINED, whole.
  grep -qF '## 2026-07-28 [QA] a modern post-cutoff session heading (retained)' "$R/progress.md" \
    || cf "the post-cutoff section heading was not retained in progress.md"
  grep -qF -- '- a retained bullet inside it' "$R/progress.md" \
    || cf "the post-cutoff section's body was not retained in progress.md"
  grep -qF '2026-07-28' "$chunk" && cf "the post-cutoff section leaked into the archive chunk"

  # Idempotency: a clean re-run (fresh milestone name) finds nothing to archive.
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" \
            --milestone mix2 --before 2026-07-25 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "the idempotent re-run exited $rc (expected 0): $out"
  printf '%s' "$out" | grep 'Nothing to archive' >/dev/null \
    || cf "the idempotent re-run did not report 'Nothing to archive': $out"

  # § LOG ENDS AT THE NEXT "## " HEADING THAT IS NOT A DATED ENTRY (the mixed fixture above
  # proves a dated "## " does not end it): the section after it stays in progress.md, in place,
  # under both knives. --before rotates every entry, so nothing retained sits between them.
  local T="$SB_TMP/ap-tail" k
  for k in "--before 2026-08-01" "--keep-last 1"; do
    rm -rf "$T"; mkdir -p "$T/progress/history"
    printf '# progress.md\n\n## Log\n\n### 2026-07-01 [Dev] old\n- a\n\n### 2026-07-02 [Dev] newer\n- b\n\n## Notes\n\n### 2026-09-01 not an entry\n- NOTES-LINE\n' > "$T/progress.md"
    # shellcheck disable=SC2086 # $k is two words on purpose
    out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$T" --milestone tail $k --apply 2>&1 )"; rc=$?
    [ "$rc" -eq 0 ] || cf "($k) a log followed by '## Notes' exited $rc: $(printf '%s' "$out" | head -2 | tr '\n' '|')"
    grep -F 'NOTES-LINE' "$T/progress/history/tail.md" >/dev/null 2>&1 \
      && cf "($k) the section after § Log was moved into the history chunk"
    [ "$(sed -n '/^## Notes$/,$p' "$T/progress.md")" = "$(printf '## Notes\n\n### 2026-09-01 not an entry\n- NOTES-LINE')" ] \
      || cf "($k) the section after § Log is not intact at the end of progress.md: $(tr '\n' '|' < "$T/progress.md")"
    grep -qxF '### 2026-07-01 [Dev] old' "$T/progress/history/tail.md" 2>/dev/null \
      || cf "($k) the oldest entry was not rotated"
  done
  # --keep-last 1 counted two entries, not the dated `###` under ## Notes: the newer one stays.
  grep -qxF '### 2026-07-02 [Dev] newer' "$T/progress.md" \
    || cf "(--keep-last 1) the newest entry was not kept"

  finish "archive-progress.sh: byte-complete rotation of a mixed-format log (0 lost lines), count mirrors routing, idempotent, and § Log ends at the next heading that is not a dated entry"
  teardown
}

# CASE — archive-progress.sh's DRY RUN, which is the DEFAULT, writes nothing at all.
#
# The assertion is a whole-tree checksum, not `[ ! -f INDEX.md ]`: naming one file would
# pass the day a different dry-run write appears.
case_archive_progress_dry_run_writes_nothing() {
  cf_reset
  make_sandbox
  local R="$SB_TMP/apdry" out rc before after
  ap_seed "$R" 20 2026-08-20 \
    || { finish "archive-progress.sh: a dry run writes NOTHING"; teardown; return; }

  _tree_sum() { find "$R" -type f -print0 | sort -z | xargs -0 shasum | shasum; }
  before="$(_tree_sum)"

  # No --apply. Entries ARE older than the cut, so this is the live path, not a no-op.
  rc=0; out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" \
                  --milestone dry1 --before 2026-08-26 2>&1 )" || rc=$?
  after="$(_tree_sum)"

  [ "$rc" -eq 0 ] \
    || cf "the dry run exited $rc, want 0: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  [ "$before" = "$after" ] \
    || cf "THE DRY RUN MUTATED THE TREE. Files now present: $(find "$R" -type f | sed "s|^$R/||" | tr '\n' ' ')"
  printf '%s' "$out" | grep 'dry run' >/dev/null \
    || cf "the dry run did not identify itself as one"

  # AND IT SAID SO: a fix that silently skipped the creation would pass the checksum. The
  # dry run must announce the write it declined (instruments.md § A.4).
  printf '%s' "$out" | grep 'INDEX.md' >/dev/null \
    || cf "the dry run never mentioned INDEX.md, so a reader cannot tell --apply would create it"

  # THE OTHER DIRECTION, which is what makes the check above a real one: --apply DOES
  # create it. Without this leg, deleting the creation outright would pass.
  rc=0; out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" \
                  --milestone dry2 --before 2026-08-26 --apply 2>&1 )" || rc=$?
  [ -f "$R/progress/history/INDEX.md" ] \
    || cf "--apply did NOT create the index — the dry-run fix removed the behaviour instead of deferring it (rc=$rc)"

  unset -f _tree_sum
  finish "archive-progress.sh: the DEFAULT dry run leaves the tree byte-identical (whole-tree checksum) while still naming the index it would create, and --apply still creates it"
  teardown
}

# archive-progress.sh: the ordinal knife, the honest no-op, and the index
# =============================================================================
# Rotation is due on a byte threshold, and a date knife cannot cut a same-day log, so a
# second rotation in one day needs --keep-last, and an over-threshold no-op must not print
# the green phrase (exit 3). The threshold is read from the real check-board.sh so that a
# retune cannot make these cases vacuous. cb_default does not apply: it expects a quoted
# value and this constant is a bare integer.
ap_thresh() {
  sed -n 's/^PROGRESS_LOG_BYTE_THRESHOLD=\([0-9]*\).*/\1/p' "$REAL_SCRIPTS/check-board.sh" 2>/dev/null | head -1
}

# ap_seed <repo> <n_entries> <date> — a log of N same-day entries, padded so § Log
# lands OVER the derived threshold. Same-day on purpose: that is the condition a
# date knife cannot cut. The entries are `### DATE`, the documented form: a `## DATE`
# heading ends § Log for the board's slice, so the log would measure almost nothing.
ap_seed() {
  local R="$1" n="$2" d="$3" thresh pad i
  thresh="$(ap_thresh)"; [ -n "$thresh" ] || { cf "(fixture) could not derive PROGRESS_LOG_BYTE_THRESHOLD"; return 1; }
  pad=$(( thresh / n + 200 ))          # per-entry padding that guarantees the crossing
  mkdir -p "$R/progress/history"
  { echo "# progress.md"; echo ""; echo "Preamble."; echo ""; echo "## Log"; echo ""
    for i in $(seq 1 "$n"); do
      echo "### $d [Dev] session $i"
      head -c "$pad" /dev/zero | tr '\0' 'x'; echo
      echo ""
    done
  } > "$R/progress.md"
  local got; got="$(awk '/^##[[:space:]]/ { if (f) exit; if ($0 ~ /^##[[:space:]]+Log([[:space:]]|$)/) f=1 } f { print }' "$R/progress.md" | wc -c | tr -d ' ')"
  [ "$got" -gt "$thresh" ] || cf "(fixture) § Log is $got bytes, NOT over the $thresh threshold — the case would prove nothing"
}

# =============================================================================
# CASE — ONE GENERATED ROW, ONE CLOCK.
#
# archive-sweep.md § 2: a calendar day is local; an instant is UTC and says Z. `Covers`
# comes from the chunk's locally stamped content, so `Rotated` must be local too. To avoid a
# wall-clock flake, the rotation runs under two zones 26 hours apart, which never share a
# calendar day, and the column must move with the operator. Both are POSIX `std offset`
# strings, so no zoneinfo database is needed.
# =============================================================================
case_rotation_day_uses_the_board_clock() {
  cf_reset
  make_sandbox
  local TZE='XXX-14' TZW='XXX+12'   # 26h apart — they NEVER share a calendar day
  local de dw out rc rot1 rot2
  de="$(TZ=$TZE date +%Y-%m-%d)"; dw="$(TZ=$TZW date +%Y-%m-%d)"

  # ── INSTRUMENT CHECK, and it must run FIRST. If `date` ignores TZ in this environment,
  #    every assertion below compares two identical strings and reports a green it could
  #    not have failed. That is a statement about the environment, so it is a SKIP.
  if [ "$de" = "$dw" ]; then
    skp "the rotation day comes from the board's clock" \
        "the two pinned zones ($TZE / $TZW) both returned $de — date is not honouring TZ here, so this case would prove nothing"
    teardown; return
  fi

  local R1="$SB_TMP/tz1" R2="$SB_TMP/tz2"
  ap_seed "$R1" 12 2026-08-26 || { finish "the rotation day comes from the board's clock"; teardown; return; }
  ap_seed "$R2" 12 2026-08-26 || { finish "the rotation day comes from the board's clock"; teardown; return; }

  out="$( TZ=$TZE "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R1" --milestone t1 --keep-last 4 --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "the east-zone rotation exited $rc: $out"
  out="$( TZ=$TZW "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R2" --milestone t2 --keep-last 4 --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "the west-zone rotation exited $rc: $out"

  # Read `Rotated` BY POSITION (field 5 of a leading-pipe row), not by pattern — a pattern
  # for a date would match the Covers column too and this case would read the wrong cell.
  rot1="$(awk -F'|' '/t1\.md/ { gsub(/ /,"",$5); print $5; exit }' "$R1/progress/history/INDEX.md" 2>/dev/null)"
  rot2="$(awk -F'|' '/t2\.md/ { gsub(/ /,"",$5); print $5; exit }' "$R2/progress/history/INDEX.md" 2>/dev/null)"
  [ -n "$rot1" ] && [ -n "$rot2" ] \
    || _fixture_die "case_rotation_day_uses_the_board_clock: no Rotated cell in one of the index rows — the column moved and this case is reading the wrong field."

  # EFFECT (i) — DIRECTION, not merely difference: the cell IS each operator's own day.
  [ "$rot1" = "$de" ] || cf "under TZ=$TZE the row reads Rotated '$rot1' but the day every other board artifact writes there is '$de'"
  [ "$rot2" = "$dw" ] || cf "under TZ=$TZW the row reads Rotated '$rot2' but the day every other board artifact writes there is '$dw'"
  # EFFECT (ii) — therefore the two zones DISAGREE. A UTC stamp is TZ-invariant and cannot.
  [ "$rot1" != "$rot2" ] \
    || cf "two rotations whose operators are 26 hours apart in calendar terms wrote the SAME Rotated day ('$rot1') — the column is on a clock the rest of the board is not"
  # EFFECT (iii) — the row's OTHER date column still comes from the chunk's own content.
  #    If this stops holding, (i) and (ii) are no longer about a row that mixes two clocks.
  awk -F'|' '/t1\.md/ { gsub(/ /,"",$3); print $3; exit }' "$R1/progress/history/INDEX.md" 2>/dev/null \
    | grep -F '2026-08-26→2026-08-26' >/dev/null \
    || cf "the Covers column is not the seeded local span — the row's two date columns no longer share a source, so this case is not measuring a mixed row"

  finish "archive-progress.sh dates the INDEX row's Rotated column on the same clock the rest of the board writes (the operator's local day), so one generated row never mixes two clocks — proven across two zones 26 hours apart, which no UTC stamp can satisfy"
  teardown
}

case_archive_progress_ordinal_knife() {
  cf_reset
  make_sandbox
  local R="$SB_TMP/apo" out rc
  ap_seed "$R" 20 2026-08-26 || { finish "archive-progress.sh: --keep-last cuts a same-day log twice"; teardown; return; }

  # FIRST rotation of the day.
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone d1 --keep-last 8 --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "first --keep-last run exited $rc (expected 0): $out"
  local left; left="$(grep -c '^### 2026-08-26' "$R/progress.md" || true)"
  [ "$left" = "8" ] || cf "after --keep-last 8 the log holds $left entries, expected 8"

  # SECOND rotation, SAME CALENDAR DAY: a date knife has nothing left to cut here.
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone d2 --keep-last 3 --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "SECOND same-day --keep-last run exited $rc (expected 0) — the duty cycle is not closed: $out"
  left="$(grep -c '^### 2026-08-26' "$R/progress.md" || true)"
  [ "$left" = "3" ] || cf "after the second cut the log holds $left entries, expected 3"

  # THE CONTROL: the date knife on the same fixture cuts NOTHING. Without this the
  # case proves the new flag runs, not that it does something the old one could not.
  ap_seed "$R" 20 2026-08-26 || true
  rm -f "$R/progress/history"/*.md
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone dc --before 2026-08-26 --apply 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(control) --before on an all-today log exited 0 — it should not have found a cut"
  [ -f "$R/progress/history/dc.md" ] && cf "(control) --before wrote a chunk on an all-today log"

  # THE BOARD'S HEADING: check-board.sh reads `## Log (older)` as § Log, so the knife must too.
  ap_seed "$R" 20 2026-08-26 || true
  rm -f "$R/progress/history"/*.md
  sed -i.bak 's/^## Log$/## Log (older)/' "$R/progress.md"; rm -f "$R/progress.md.bak"
  grep -qxF '## Log (older)' "$R/progress.md" \
    || _fixture_die "case_archive_progress_ordinal_knife: the fixture carries no '## Log (older)' heading — the row below would test the plain one."
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone dh --keep-last 8 --apply 2>&1 )"; rc=$?
  left="$(grep -c '^### 2026-08-26' "$R/progress.md" || true)"
  [ "$rc" -eq 0 ] && [ "$left" = "8" ] \
    || cf "under a '## Log (older)' heading --keep-last 8 exited $rc and left $left entries, expected 0 and 8: $(printf '%s' "$out" | head -2 | tr '\n' '|')"

  finish "archive-progress.sh: --keep-last cuts a same-day log TWICE (the duty cycle), where --before cuts nothing, and finds § Log by the board's heading"
  teardown
}

case_archive_progress_honest_noop() {
  cf_reset
  make_sandbox
  local R="$SB_TMP/apn" out rc thresh
  thresh="$(ap_thresh)"
  ap_seed "$R" 20 2026-08-26 || { finish "archive-progress.sh: nothing-matched over threshold is not a green"; teardown; return; }

  # Nothing matches (all entries are today), and § Log is OVER the threshold.
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone n1 --before 2026-08-26 2>&1 )"; rc=$?
  [ "$rc" -eq 3 ] || cf "nothing-matched-while-due exited $rc, expected 3 (a distinct code, not a failure and not a pass): $out"
  printf '%s' "$out" | grep 'ROTATION IS STILL DUE' >/dev/null || cf "the over-threshold no-op did not say a rotation is still due: $out"
  printf '%s' "$out" | grep "$thresh" >/dev/null || cf "the over-threshold no-op did not name the threshold it measured against: $out"
  # THE REDDENING CONTROL: the green phrase must be ABSENT. A fix that added the warning
  # and kept the phrase would still read as an all-clear.
  printf '%s' "$out" | grep 'Nothing to archive' >/dev/null \
    && cf "the over-threshold no-op still printed the green phrase 'Nothing to archive' — that is the false all-clear"

  # AND THE OTHER DIRECTION: under threshold, nothing matched IS a green and keeps the
  # phrase. Both states must exist, or the change is a rename rather than a new state.
  { echo "# progress.md"; echo ""; echo "## Log"; echo ""; echo "## 2026-08-26 [Dev] one small entry"; echo "body"; echo ""; } > "$R/progress.md"
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone n2 --before 2026-08-26 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "under-threshold nothing-matched exited $rc, expected 0: $out"
  printf '%s' "$out" | grep 'Nothing to archive' >/dev/null \
    || cf "under threshold the honest green phrase 'Nothing to archive' is missing: $out"
  printf '%s' "$out" | grep 'under threshold' >/dev/null \
    || cf "the under-threshold green did not state the measurement that makes it a green: $out"

  # AND THE SAME SLICE AS THE BOARD: § Log ends at the next `## ` heading, so a large section
  # after it is not the log. Measured to end of file, this read a rotation due that the board,
  # which owns the threshold, reports clear.
  { echo "# progress.md"; echo ""; echo "## Log"; echo ""; echo "### 2026-08-26 [Dev] one small entry"; echo "body"; echo ""
    echo "## Notes"; head -c "$(( thresh + 1000 ))" /dev/zero | tr '\0' 'x'; echo; } > "$R/progress.md"
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone n3 --before 2026-08-26 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "a small § Log followed by a large section exited $rc, expected 0 — § Log was measured past its own end: $out"

  finish "archive-progress.sh: nothing-matched OVER threshold exits 3 without the green phrase; UNDER threshold exits 0 with it; § Log is measured to the next '## ' heading, as the board measures it"
  teardown
}

case_archive_progress_index() {
  cf_reset
  make_sandbox
  local R="$SB_TMP/api" out rc
  ap_seed "$R" 12 2026-08-26 || { finish "archive-progress.sh: every chunk gains an index row"; teardown; return; }

  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone c1 --keep-last 4 --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "--apply exited $rc: $out"
  local idx="$R/progress/history/INDEX.md"
  [ -f "$idx" ] || { cf "no index was written or created"; finish "archive-progress.sh: every chunk gains an index row"; teardown; return; }
  grep -qF 'c1.md' "$idx" || cf "the chunk has no index row — a rotated chunk is findable only by ls, which is the defect"
  # THE SPAN IS THE LOAD-BEARING COLUMN: a row without it is a filename, and a
  # filename is what `ls` already gave you.
  grep -E '\| *\[`c1\.md`\].*2026-08-26 → 2026-08-26 *\| *8 *\|' "$idx" >/dev/null \
    || cf "the index row is missing its date span and/or its entry count: $(grep 'c1.md' "$idx")"

  # A SECOND chunk goes ABOVE the first (newest first) and rewrites no row.
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone c2 --keep-last 1 --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "the second --apply exited $rc: $out"
  local first_row; first_row="$(grep -m1 '^| \[' "$idx")"
  printf '%s' "$first_row" | grep -F 'c2.md' >/dev/null \
    || cf "the newest chunk is not the first row (newest-first is format law): $first_row"
  grep -qF 'c1.md' "$idx" || cf "the earlier index row was lost — the index is append-only"

  # THE EARNED REFUSAL: with chunks present and the index gone, it must REFUSE and
  # must NOT write a fresh empty index — that index would deny the chunks beside it.
  rm -f "$idx"
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone c3 --keep-last 1 --apply 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "a missing index with chunks present did NOT refuse: $out"
  [ -f "$idx" ] && cf "it fabricated an index while chunks existed — that row-less index denies them"
  printf '%s' "$out" | grep -F 'c1.md' >/dev/null || cf "the refusal did not name the chunks whose rows would be missing: $out"

  # AND THE OTHER SIDE OF THAT DECISION: no chunks, no index -> CREATE, because
  # "nothing was ever archived" is then simply true. This is the upgrade path.
  rm -f "$R/progress/history"/*.md
  ap_seed "$R" 12 2026-08-26 || true
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone c4 --keep-last 4 --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "an absent index with NO chunks should be created, not refused (the upgrade path) — exited $rc: $out"
  grep -qF 'c4.md' "$idx" || cf "the created index has no row for the chunk that created it"

  finish "archive-progress.sh: chunks gain index rows with their spans, newest-first and append-only; a missing index REFUSES where chunks exist and is CREATED where none do"
  teardown
}
