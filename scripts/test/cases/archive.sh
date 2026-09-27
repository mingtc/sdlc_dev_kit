# KIT-CLASS: MIXED — self-test harness, archive cases. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/archive.sh — sourced by scripts/test/run.sh, never run on its own.
# archive.sh and archive-progress.sh: the sweep, its index, rotation day.
# =============================================================================

# =============================================================================
# CASE — archive.sh --apply indexes + moves to done/
# =============================================================================
# =============================================================================
# CASE — A ONE-MEMBER ROLE TAG REFUSES BEFORE IT MUTATES.
#
# Three shipped scripts commit under a role tag that is ONE MEMBER of the role set:
# archive.sh's sweep, subtask.sh's create arm, finish-pr.sh's squash. They were
# hardcoded, so `kit-init --roles` — a documented, supported invocation — left them
# naming a seat the project no longer declares. The initializer correctly cannot stamp
# them: it rewrites the whole alternation, and one member does not contain it. So the
# kit's own tooling manufactured the breakage.
#
# WHY THE EXIT CODE IS NOT THE ASSERTION. Without the guard, archive.sh still exits
# nonzero — the hook rejects the commit and `set -e` aborts. A case that checked only
# `rc -ne 0` would PASS against the defect. The whole content of the fix is WHICH SIDE
# of the mutation the refusal lands on.
#
# WHAT THE REDDENING MUTATION ACTUALLY PROVES — measured, and NOT what was predicted
# when this case was drafted. Deleting the guard does NOT move the card on the trunk:
# the sweep git-mv's inside the kanban worktree, the commit fails, and nothing is
# pushed, so both trunk assertions still hold. What fails is the RESTORE CONTROL at the
# bottom: the refused run leaves uncommitted state in the SHARED worktree, and the very
# next board operation — with a perfectly legal role tag — dies on
# "the kanban worktree has uncommitted changes". So the damage this guard prevents is
# not a bad commit; it is a POISONED WORKTREE that breaks the next operation, in
# somebody else's lane, with an error naming neither the role nor the sweep that caused
# it. That is the documented failure mode, reproduced end to end.
#
# The two trunk assertions are kept anyway: they are the ones that would catch a variant
# where the mv DID reach the trunk, which no other assertion here would notice.
#
# THE NARROWING GOES INTO THE HOOK, never into the knob. Setting ARCHIVE_ROLE would
# only prove the knob is read; narrowing the declared set is what proves the tag is
# CHECKED against it.
# =============================================================================
# =============================================================================
# CASE — A CONTRADICTORY --apply/--dry-run PAIR REFUSES, IN EITHER ORDER.
#
# archive.sh inspected `$1` ALONE — no loop, no shift, no `$#`. So every argument after
# the first was silently discarded, and one of the things it discarded was a hedge.
# Measured: `--apply --dry-run` set DRY_RUN=false and swept, committed and PUSHED to the
# trunk with `--dry-run` thrown away; the reverse order previewed and threw `--apply`
# away. Order-dependent, opposite outcomes, no warning — and `--apply --dry-run` is
# exactly the belt-and-braces spelling an operator who is unsure reaches for.
#
# THE EXIT CODE IS NOT THE ASSERTION. This case reads the BOARD, the local HEAD and the
# REMOTE, because the difference between the two orders was a push to the trunk.
#
# NOTE WHAT IS *NOT* CHANGED: the defaults. `contracts/archive-sweep.md` § 2 rules
# preview-by-default for this script and the manual documents the bare invocation as the
# dry run. This case pins that too — the instrument leg proves a plain `--apply` still
# sweeps, so the refusal cannot have been bought by breaking the tool.
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
# WHY (reproduced from an adopter following a recipe that omitted the separator): the
# insert prints the header, then READS THE NEXT LINE and reprints it as the separator.
# If that line is not a separator, the file's FIRST DATA ROW is consumed into the
# separator's position and the new row lands SECOND — silently breaking the newest-first
# ordering the index exists to provide. And `grep -qF` on the header ACCEPTED that file:
# a presence check standing in for a well-formedness check, which is the guard looking
# slightly to the left of the defect (instruments.md § A.6).
#
# BOTH FIXTURES ARE HAND-WRITTEN, DELIBERATELY. The sibling index case builds its index
# by RUNNING THE SCRIPT, so it only ever meets the well-formed shape — a guard measured
# against its author's own output is measuring the author. The malformed shape cannot be
# produced by the code under test, so it has to be typed here.
#
# AND THE FAILURE UNDER TEST IS A WRITE THAT HAPPENED, so a non-zero exit is not enough:
# the control asserts the file is BYTE-UNCHANGED. The well-formed control is the other
# half — without it, an unconditional refusal would pass the first assertion.
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
  rm -f "$before"

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

  finish "archive-progress.sh: a MALFORMED index refuses with the file byte-unchanged and un-repaired; a well-formed one still inserts newest-first"
  teardown
}

# =============================================================================
# CASE — THE ARCHIVE INDEX CARRIES A RETIREMENT DATE (both directions).
#
# archive-sweep.md § 2: "Every retired item gains an INDEX entry ... carrying at
# least its identifier, its title and its RETIREMENT DATE." The entry carried the
# first two, so the index answered *what* was archived and never *when* — the one
# question a retention policy asks of it.
#
# BOTH DIRECTIONS, because the first alone proves the line RUNS, not that it DOES
# ANYTHING: with the date write ablated out, the assertion must fail. A control that
# cannot fail is not a control, and this harness has already caught one of mine that
# could not (a fixture whose own portability slip was indistinguishable from the
# defect under test).
# =============================================================================
case_archive_index_carries_the_date() {
  cf_reset
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-250" dated chore "Dated retirement"
  publish_sandbox

  local out rc entry today
  today="$(date +%Y-%m-%d)"
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "archive.sh --apply exited $rc: $out"
  entry="$(grep "$SB_PREFIX-250" "$SB_WORK/ARCHIVE.md" || true)"
  [ -n "$entry" ] || cf "$SB_PREFIX-250 was not indexed at all: $(cat "$SB_WORK/ARCHIVE.md")"
  printf '%s' "$entry" | grep -E 'retired [0-9]{4}-[0-9]{2}-[0-9]{2}' >/dev/null \
    || cf "the index entry carries no retirement date — § 2 requires the date beside the id and title: $entry"
  printf '%s' "$entry" | grep "retired $today" >/dev/null \
    || cf "the retirement date is not today's ($today): $entry"
  # The id stays the FIRST token: next-id.sh documents these entries as
  # `- <PREFIX>-NNN …` and reads them so a new mint cannot collide with an archived
  # id. If the date ever migrates to the front, that convention breaks silently and
  # a re-minted id is the symptom, a long way from the cause.
  printf '%s' "$entry" | grep -E "^- $SB_PREFIX-250 " >/dev/null \
    || cf "the entry no longer begins '- $SB_PREFIX-250 ' — next-id.sh reads this shape to avoid re-minting an archived id: $entry"
  # THE PREVIEW AND THE APPLIED ENTRY MUST AGREE. They are built from one string in
  # the script; this holds that true from outside, because a preview that understates
  # what will be written is how a bulk irreversible op gets approved.
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "the dry run exited $rc: $out"

  # --- ABLATION: remove the date write and the assertion above must fail -----
  local a_script="$SB_WORK/scripts/archive.sh" n
  # -F: these two operands carry a mid-pattern `$`, which is a literal under POSIX BRE
  # and an anchor under implementations that anchor anywhere. Inside a script `grep`
  # always resolves through PATH, so both are correct today — but a fixed-string search
  # has no metacharacter for two implementations to disagree about, and the cost of not
  # depending on that is one flag.
  n="$(grep -cF 'ENTRY="${ENTRY} — retired ${RETIRED_ON}"' "$a_script" || true)"
  if [ "$n" != "1" ]; then
    cf "(control) expected exactly 1 date-append line in archive.sh to ablate, found $n — the anchor moved and this ablation proves nothing"
  else
    # TEARDOWN FIRST. make_sandbox sets SB_TMP afresh, so without this the first sandbox's
    # path was lost and the one teardown below removed only the second — a whole sandbox
    # left in the temp dir on every run.
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
# archive-sweep.md § 3: "The retired store or the index is missing ⇒ refuse; do not
# create an index on the fly." The script honoured that for the index and `mkdir -p`'d
# the store — so it manufactured the board topology it was operating within, and
# because board-mover.md's first invariant is "the container IS the status", an
# invented container is an invented status. A mistyped or renamed column became a new
# column holding real retired work.
#
# BOTH DIRECTIONS: the refusal must fire AND MUST CREATE NOTHING, and a board that
# does have the column must still archive normally — otherwise the fix is an
# unconditional refusal, which passes the first assertion and breaks the tool.
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
  # AND IT CREATED NOTHING — the assertion that separates "refused" from "refused
  # after doing the thing". Checked in the kanban worktree too, which is where this
  # script actually operates and therefore where a stray mkdir would land.
  kwt_done="$SB_WORK/.kanban-wt/progress/done"
  [ ! -d "$SB_WORK/progress/done" ] || cf "(i) the refusal still created progress/done/ in the checkout"
  [ ! -d "$kwt_done" ] || cf "(i) the refusal still created progress/done/ inside the kanban worktree"
  [ -f "$SB_WORK/progress/qa_complete/$SB_PREFIX-260-nostore.md" ] \
    || cf "(i) the card left qa_complete/ during a refusal"
  teardown

  # --- (ii) the store is PRESENT: archive normally ---------------------------
  # Without this the fix could be an unconditional refusal and half (i) would still
  # pass. It is the same shape as the UNRUNNABLE case's second direction.
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-261" hasstore chore "Has retired store"
  [ -d "$SB_WORK/progress/done" ] || cf "(control) the sandbox has no progress/done/ — half (ii) cannot test the happy path"
  publish_sandbox
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(ii) archive.sh --apply exited $rc on a board that HAS done/ — the refusal is unconditional: $out"
  [ -f "$SB_WORK/progress/done/$SB_PREFIX-261-hasstore.md" ] \
    || cf "(ii) the card was not moved into done/: $out"
  grep -q "$SB_PREFIX-261" "$SB_WORK/ARCHIVE.md" || cf "(ii) the card was not indexed: $out"

  finish "archive.sh: an absent retired store REFUSES, names it, prints the .gitkeep creation recipe and creates nothing (checkout and kanban worktree both) — while a board that has done/ still archives normally"
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
# The defect this pins: the split-awk classified a Log line as archivable ONLY
# when it matched a bare date-prefixed bullet, so entries grouped under a dated
# section HEADER (with undated sub-bullets) matched nothing and fell into an
# "intentionally dropped" branch — they reached NEITHER the retained progress.md
# NOR the history chunk. Silent data loss on --apply.
#
# The reconstruction check is the byte-completeness proof: split the new
# progress.md at "## Log", splice the archived chunk (minus its YAML header)
# between the halves, and it must equal the original fixture verbatim.
# =============================================================================
case_archive_progress_sections() {
  cf_reset
  make_sandbox   # only for SB_TMP + teardown; this case uses --repo-root
  local R="$SB_TMP/ap"
  mkdir -p "$R/progress/history"

  # THE FIXTURE CARRIES ALL THREE BOUNDARY FORMS, IN THEIR REAL NESTING ORDER.
  # Note where the post-cutoff entry sits: at its OWN `## ` heading, not as a bare
  # bullet after one. That is not cosmetic — it is the nesting-precedence rule
  # under test. Once a `## DATE` section opens, every line until the next `## `
  # heading belongs to THAT section, whatever those lines look like, so a bare
  # post-cutoff bullet placed inside a pre-cutoff `## ` section is correctly
  # archived WITH it. A fixture that placed it there and then asserted retention
  # would be testing the fixture's own confusion, not the script.
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

  # The reported count must EXACTLY MIRROR the awk routing: a dated header whose
  # date is at END-OF-LINE is a boundary (the awk arms need no trailing space), so
  # it must be counted too. A count below what was routed is the shape of the old
  # undercount.
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

  finish "archive-progress.sh: byte-complete rotation of a mixed-format log (0 lost lines), count mirrors routing, idempotent"
  teardown
}

# CASE — archive-progress.sh's DRY RUN, which is the DEFAULT, writes nothing at all.
#
# It used to. The empty-index creation sat 223 lines above the `(dry run — no changes
# made.)` line and ran in both modes, so the default invocation created
# progress/history/INDEX.md and then closed by denying it had. Found by a fresh-context
# sweep 2026-09-03; the reason it survived the mechanical pre-cut sweep is that nothing
# CLAIMED the two were connected — the write was correct on its own, the summary was
# correct on its own, and only running the thing shows they contradict.
#
# The assertion is a WHOLE-TREE checksum, not `[ ! -f INDEX.md ]`. Naming the one file
# I know about would pass the day a different dry-run write appears, and this defect's
# whole lesson is that the write nobody thought about is the one that gets through.
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

  # AND IT SAID SO. A fix that silently skipped the creation would satisfy the checksum
  # above while leaving the reader unable to tell the index is missing — the honest-blind-
  # spot duty (instruments.md § A.4). The dry run must ANNOUNCE the write it declined.
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
# WHY THESE EXIST (measured, not speculative). The rotation's only selector was a
# DATE, while the trigger that says a rotation is due is a BYTE threshold — and
# bytes cross it more than once in a working day. So the second rotation of a day
# had no expressible cut: it reported "Nothing to archive" and exited 0 on an
# over-threshold log. THE TOOL'S SUCCESS WAS WHAT MADE IT INERT, which is why the
# exit-3 case below asserts the ABSENCE of the green phrase and not just the code.
#
# DERIVE, DO NOT RE-HARDCODE: the threshold is read out of the REAL check-board.sh,
# so a retune there cannot silently make these cases vacuous. (cb_default is not
# usable — it expects a single-quoted value and this constant is a bare integer.)
ap_thresh() {
  sed -n 's/^PROGRESS_LOG_BYTE_THRESHOLD=\([0-9]*\).*/\1/p' "$REAL_SCRIPTS/check-board.sh" 2>/dev/null | head -1
}

# ap_seed <repo> <n_entries> <date> — a log of N same-day entries, padded so § Log
# lands OVER the derived threshold. Same-day on purpose: that is the condition a
# date knife cannot cut.
ap_seed() {
  local R="$1" n="$2" d="$3" thresh pad i
  thresh="$(ap_thresh)"; [ -n "$thresh" ] || { cf "(fixture) could not derive PROGRESS_LOG_BYTE_THRESHOLD"; return 1; }
  pad=$(( thresh / n + 200 ))          # per-entry padding that guarantees the crossing
  mkdir -p "$R/progress/history"
  { echo "# progress.md"; echo ""; echo "Preamble."; echo ""; echo "## Log"; echo ""
    for i in $(seq 1 "$n"); do
      echo "## $d [Dev] session $i"
      head -c "$pad" /dev/zero | tr '\0' 'x'; echo
      echo ""
    done
  } > "$R/progress.md"
  local got; got="$(awk '/^## Log[[:space:]]*$/{f=1} f{n+=length($0)+1} END{print n+0}' "$R/progress.md")"
  [ "$got" -gt "$thresh" ] || cf "(fixture) § Log is $got bytes, NOT over the $thresh threshold — the case would prove nothing"
}

# =============================================================================
# CASE — ONE GENERATED ROW, ONE CLOCK.
#
# archive-progress.sh's INDEX row has two date columns. `Covers` is grepped out of the
# chunk's own content, which move-issue.sh and subtask.sh stamped on the operator's LOCAL
# day; `Rotated` was `date -u`. Eight hours apart on this machine, for a third of every
# day, in one row, with nothing about it looking wrong. archive-sweep.md § 2 now rules it:
# a calendar DAY is local, an INSTANT is UTC and says Z.
#
# WALL-CLOCK FLAKE IS THE HAZARD HERE, so this case does not compare against "today". It
# runs the same rotation under two zones 26 HOURS APART — UTC+14 and UTC−12 can never
# share a calendar day, at any instant — and asserts the column moved WITH the operator.
# A UTC stamp is TZ-invariant and cannot satisfy that, at any hour. Both zones are POSIX
# `std offset` strings, so no zoneinfo database is needed.
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
  local left; left="$(grep -c '^## 2026-08-26' "$R/progress.md" || true)"
  [ "$left" = "8" ] || cf "after --keep-last 8 the log holds $left entries, expected 8"

  # SECOND rotation, SAME CALENDAR DAY. This is the whole finding: a date knife
  # has nothing left to cut here, because everything before today already went.
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone d2 --keep-last 3 --apply 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "SECOND same-day --keep-last run exited $rc (expected 0) — the duty cycle is not closed: $out"
  left="$(grep -c '^## 2026-08-26' "$R/progress.md" || true)"
  [ "$left" = "3" ] || cf "after the second cut the log holds $left entries, expected 3"

  # THE CONTROL: the date knife on the same fixture cuts NOTHING. Without this the
  # case proves the new flag runs, not that it does something the old one could not.
  ap_seed "$R" 20 2026-08-26 || true
  rm -f "$R/progress/history"/*.md
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone dc --before 2026-08-26 --apply 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(control) --before on an all-today log exited 0 — it should not have found a cut"
  [ -f "$R/progress/history/dc.md" ] && cf "(control) --before wrote a chunk on an all-today log"

  finish "archive-progress.sh: --keep-last cuts a same-day log TWICE (the duty cycle), where --before cuts nothing"
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
  # THE REDDENING CONTROL, and the point of the whole case: the GREEN PHRASE must
  # be ABSENT. Its presence is what made the old behaviour read as an all-clear,
  # so a fix that added the warning and kept the phrase would still be broken.
  printf '%s' "$out" | grep 'Nothing to archive' >/dev/null \
    && cf "the over-threshold no-op still printed the green phrase 'Nothing to archive' — that is the false all-clear"

  # AND THE OTHER DIRECTION: under threshold, nothing matched, that IS a green and
  # keeps the phrase. Both states must exist and be distinct, or the change is a
  # rename rather than a new state.
  { echo "# progress.md"; echo ""; echo "## Log"; echo ""; echo "## 2026-08-26 [Dev] one small entry"; echo "body"; echo ""; } > "$R/progress.md"
  out="$( "$SB_WORK/scripts/archive-progress.sh" --repo-root "$R" --milestone n2 --before 2026-08-26 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "under-threshold nothing-matched exited $rc, expected 0: $out"
  printf '%s' "$out" | grep 'Nothing to archive' >/dev/null \
    || cf "under threshold the honest green phrase 'Nothing to archive' is missing: $out"
  printf '%s' "$out" | grep 'under threshold' >/dev/null \
    || cf "the under-threshold green did not state the measurement that makes it a green: $out"

  finish "archive-progress.sh: nothing-matched OVER threshold exits 3 without the green phrase; UNDER threshold exits 0 with it"
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
