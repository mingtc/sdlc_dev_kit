# KIT-CLASS: MIXED — self-test harness, board-script cases. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/board.sh — sourced by scripts/test/run.sh, never run on its own.
# The board scripts' own behaviour: move-issue.sh, next-id.sh, the commit-msg hook, push
# failure, the trunk fallback chain, the config seam, the progress record, the dirty guard.
# =============================================================================

# =============================================================================
# CASE — move-issue.sh moves + appends Activity + commits + PUSHES
# =============================================================================
case_move_issue() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-100" sandbox chore "Sandbox move test"
  publish_sandbox

  local out rc
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-100" in_progress \
            --role Dev --note "picked up in sandbox" 2>&1 )"; rc=$?

  [ "$rc" -eq 0 ] || cf "move-issue exited $rc (expected 0): $out"
  origin_has_path "progress/in_progress/$SB_PREFIX-100-sandbox.md" \
    || cf "file not moved to in_progress/ on the trunk"
  origin_has_path "progress/todo/$SB_PREFIX-100-sandbox.md" \
    && cf "file still present in todo/ on the trunk"
  origin_file_contains "progress/in_progress/$SB_PREFIX-100-sandbox.md" "picked up in sandbox" \
    || cf "Activity line not appended"
  origin_log_has_subject "\[Dev\] $SB_PREFIX-100 → in_progress: picked up in sandbox" \
    || cf "commit subject not found on the trunk (not pushed?)"

  finish "move-issue.sh: move + Activity append + commit pushed to the trunk"
  teardown
}

# =============================================================================
# CASE — THE PROGRESS RECORD IS ONE SHAPE, AND ITS WRITER'S ABSENCE IS A NO-OP
#
# Invariants from process/contracts/progress-record.md:
#
#   § 2 / § 4  ONE SHAPE: a reader parsing only the four required fields reads every record,
#              with or without optional fields, so records WITH and WITHOUT extras must share
#              one column count.
#
#   § 5b       The actor and the reserved extras have declared shapes. The validator's own
#              risk is firing on CORRECT input, so the NEGATIVE control matters most, and it is
#              DERIVED: every role in the sandbox's ROLE_PREFIXES goes through the writer and
#              none may be tagged. `run=` is present when its seam is set, ABSENT when not.
#
#   § 4        THE ABLATION: removing the writer leaves a producer's stdout, stderr and exit
#              status byte-identical, measured by deleting the library and re-running, never
#              by reading the `kit_progress() { :; }` stub.
#
# The operand is asserted first: a library that never loaded writes zero records and would
# pass both checks.
# =============================================================================
case_progress_record_is_one_shape_and_optional() {
  cf_reset
  make_sandbox

  local lib="$SB_WORK/scripts/lib/progress-record.sh"
  if [ ! -f "$lib" ]; then
    skp "the progress record is one shape and its writer is optional" "scripts/lib/progress-record.sh is not in the sandbox"
    teardown; return
  fi

  # ── THE CLOCK IS AN OPERAND. The writer files a record under its UTC day (`<day>.tsv`), so a
  #    run that straddles 00:00Z leaves one directory holding two files. The sections that count
  #    or grep across a directory run under a `date` that crosses midnight after its second
  #    record stamp, so every run meets the two-file shape instead of one run in a day.
  local clockdir="$SB_TMP/clock" _f _ndays
  mkdir -p "$clockdir"
  cat > "$clockdir/date" <<'SHIM'
#!/bin/sh
if [ "$*" = "-u +%Y-%m-%dT%H:%M:%SZ" ] && [ -n "${CLOCK_COUNT:-}" ]; then
  n=$(cat "$CLOCK_COUNT" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > "$CLOCK_COUNT"
  if [ "$n" -le 2 ]; then echo 2026-01-01T23:59:59Z; else echo 2026-01-02T00:00:00Z; fi
  exit 0
fi
exec /bin/date "$@"
SHIM
  chmod +x "$clockdir/date"

  # ── SHAPE. Four records: two carrying optional fields, two carrying none, and one
  #    whose description holds a tab and a newline — the only inputs that could split
  #    a record into the wrong number of columns or into two lines.
  local recdir="$SB_TMP/records"
  (
    cd "$SB_WORK" || exit 1
    # shellcheck source=/dev/null
    . ./scripts/lib/progress-record.sh
    export KIT_PROGRESS_DIR="$recdir"
    KIT_PROGRESS_DIR="$recdir" kit_progress "verify.sh"  status  "gate started" "gate=unit" "event=start"
    KIT_PROGRESS_DIR="$recdir" kit_progress "Dev:ID-1"   info    "no optional fields at all"
    KIT_PROGRESS_DIR="$recdir" kit_progress "QA:ID-1"    warning "$(printf 'holds a\ttab and a\nnewline')"
    KIT_PROGRESS_DIR="$recdir" kit_progress "release.sh" error   "one more" "rc=2"
  ) >/dev/null 2>&1

  local nrec=0
  [ -d "$recdir" ] && nrec="$(cat "$recdir"/*.tsv 2>/dev/null | grep -c . || true)"
  # ASSERT THE OPERAND: four calls must have produced four lines. Zero means the
  # library never loaded, which would make every check below vacuously green.
  if [ "${nrec:-0}" -ne 4 ]; then
    cf "four kit_progress calls produced $nrec record line(s), not 4 — the writer did not run, so nothing below was measured"
  else
    # ONE SHAPE: every line has the same column count, whether or not it carries extras.
    local ncols
    ncols="$(awk -F'\t' '{print NF}' "$recdir"/*.tsv 2>/dev/null | sort -u | tr '\n' ' ')"
    [ "$(printf '%s' "$ncols" | tr -d ' ')" = "5" ] \
      || cf "records do not share one column count (saw: $ncols) — a reader of the four required fields would need a fork in the middle, which contracts/progress-record.md § 2 forbids"

    # ...AND THE FOUR REQUIRED FIELDS ARE ALL NON-EMPTY on every line.
    awk -F'\t' '$1=="" || $2=="" || $3=="" || $4=="" {bad=1} END{exit bad?1:0}' "$recdir"/*.tsv 2>/dev/null \
      || cf "a record is missing one of the four REQUIRED fields — § 5's envelope is not being written"

    # ...AND THE CLASS IS A MEMBER OF THE DECLARED SET on every line.
    awk -F'\t' '$3!="status" && $3!="info" && $3!="warning" && $3!="error" {bad=1} END{exit bad?1:0}' "$recdir"/*.tsv 2>/dev/null \
      || cf "a record carries a class outside the declared set (status|info|warning|error) — § 5"

    # ...AND THE ACTOR IS A MEMBER OF § 5b's SHAPE on every line. The four calls above
    # use both declared kinds — the script side (`verify.sh`, `release.sh`) and the role
    # side (`Dev:ID-1`, `QA:ID-1`) — so a validator that fired on correct input would
    # surface right here.
    awk -F'\t' '$2=="unknown" {bad=1} END{exit bad?1:0}' "$recdir"/*.tsv 2>/dev/null \
      || cf "a record written with a WELL-SHAPED actor came back as 'unknown' — the § 5b validator is firing on correct input, which is the mirror of the defect it fixes"
  fi

  # ── § 5b, THE NEGATIVE CONTROL: no legitimate actor may be tagged. The population is
  #    DERIVED from this sandbox's ROLE_PREFIXES, never typed: a typed list would be the second
  #    declaration § 5b forbids.
  # nroles is declared at the TOP so finish() can name it on every path; under `set -u` an
  # unset one would abort the whole harness.
  local roledir="$SB_TMP/records-roles" roleset="" nroles=0
  roleset="$(sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p" "$SB_WORK/scripts/githooks/commit-msg" 2>/dev/null | head -1)"
  [ -z "$roleset" ] || nroles="$(printf '%s' "$roleset" | tr '|' '\n' | grep -c . || true)"
  if [ -z "$roleset" ]; then
    _control_did_not_run "derive ROLE_PREFIXES from the sandbox's scripts/githooks/commit-msg — the negative control for § 5b's actor shape had no population to drive"
  else
    (
      cd "$SB_WORK" || exit 1
      # BOTH libraries, in move-issue.sh's order. Sourcing only the writer leaves the
      # MEMBERSHIP half unreachable — its declared policy is to accept when the set cannot
      # be read — so this control would be green because the check never ran.
      # shellcheck source=/dev/null
      . ./scripts/lib/role-set.sh
      # shellcheck source=/dev/null
      . ./scripts/lib/progress-record.sh
      export KIT_PROGRESS_DIR="$roledir"
      # shellcheck disable=SC2086
      ( IFS='|'; for r in $roleset; do
          kit_progress "$r"          status "bare role"
          kit_progress "$r:ID-1"     status "role with an id"
        done )
    ) >/dev/null 2>&1

    local nrole_rec=0
    [ -d "$roledir" ] && nrole_rec="$(cat "$roledir"/*.tsv 2>/dev/null | grep -c . || true)"
    # ASSERT THE OPERAND FIRST: two records per declared role. Zero would make the
    # "nothing was tagged" check below vacuously green — nothing having been written.
    if [ "${nrole_rec:-0}" -ne $(( nroles * 2 )) ]; then
      _control_did_not_run "drive every declared role through the writer ($nroles role(s) should have produced $(( nroles * 2 )) records, got $nrole_rec)"
    else
      grep -q 'declared-actor=' "$roledir"/*.tsv 2>/dev/null \
        && cf "a role from this project's OWN declared set was tagged declared-actor= — § 5b's validator rejects a legitimate actor, which is worse than the best-effort column it replaced"
      awk -F'\t' '$2=="unknown" {bad=1} END{exit bad?1:0}' "$roledir"/*.tsv 2>/dev/null \
        || cf "a role from this project's OWN declared set landed in the actor column as 'unknown' — § 5b"
    fi
  fi

  # ── § 5b, THE POSITIVE HALF: an actor outside the shape still WRITES, is TAGGED, and keeps
  #    its four columns on one line, so a typo is visible rather than lost.
  local bogusdir="$SB_TMP/records-bogus"
  (
    cd "$SB_WORK" || exit 1
    # Both libraries again, for the same reason: `orchestrator/sub-3` is structurally fine
    # and is caught only by the MEMBERSHIP half, which needs the role set in scope.
    # shellcheck source=/dev/null
    . ./scripts/lib/role-set.sh
    # shellcheck source=/dev/null
    . ./scripts/lib/progress-record.sh
    export KIT_PROGRESS_DIR="$bogusdir" CLOCK_COUNT="$SB_TMP/clock.bogus" PATH="$clockdir:$PATH"
    kit_progress "orchestrator/sub-3" status "structurally fine but NOT a member — the membership half"
    kit_progress ""                   info   "no actor at all"
    # THE STRUCTURAL HALF must hold whether or not the role set is readable: an actor with a
    # space in it is never a role name.
    kit_progress "has space"          info   "whitespace is not a role and never was"
    kit_progress "Dev:"               info   "a colon with no id is not the declared shape"
  ) >/dev/null 2>&1

  local nbog=0
  [ -d "$bogusdir" ] && nbog="$(cat "$bogusdir"/*.tsv 2>/dev/null | grep -c . || true)"
  _ndays=0; for _f in "$bogusdir"/*.tsv; do [ -f "$_f" ] && _ndays=$(( _ndays + 1 )); done
  if [ "$_ndays" -ne 2 ]; then
    _control_did_not_run "cross midnight while writing the actor records ($_ndays day file(s), expected 2) — the two-file shape was not exercised"
  elif [ "${nbog:-0}" -ne 4 ]; then
    cf "an actor outside § 5b's shape produced $nbog record(s), not 4 — the validator DROPPED a record, and § 3 says a malformed field must never make work look like it never happened"
  else
    [ "$(awk -F'\t' '{print NF}' "$bogusdir"/*.tsv | sort -u | tr -d '\n')" = "5" ] \
      || cf "a tagged record does not carry the four required columns plus extras — § 2's envelope must survive normalisation"
    awk -F'\t' '$2!="unknown" {bad=1} END{exit bad?1:0}' "$bogusdir"/*.tsv 2>/dev/null \
      || cf "an actor outside § 5b's shape was written through unnormalised — the column is still best-effort"
    [ "$(cat "$bogusdir"/*.tsv 2>/dev/null | grep -c 'declared-actor=' || true)" -eq 4 ] \
      || cf "a normalised actor was not preserved in declared-actor= — § 5b requires the offered value be carried, or the typo is silent"
    # ...AND AS ONE TOKEN. A space inside the preserved value splits one extra into two,
    # so a reader tokenising the extras field sees a key nobody wrote.
    awk -F'\t' '$5 ~ /declared-actor=[^ ]* / && $5 !~ /declared-actor=[^ ]*$/ {n=split($5,p," "); for(i=1;i<=n;i++) if (p[i] !~ /=/) bad=1} END{exit bad?1:0}' "$bogusdir"/*.tsv 2>/dev/null \
      || cf "a preserved actor value was not collapsed to one token — whitespace inside it split the extras field into a key=value nobody wrote"
  fi

  # ── THE CLASS ARM, to the same token rule (contracts/progress-record.md § Reserved extra
  #    keys): extras are read back by splitting on spaces, so a preserved value holding
  #    whitespace hands a reader a `key=value` nobody wrote. The NEGATIVE half matters most:
  #    this arm cleans every unrecognised class and must not mangle a whitespace-free one.
  local classdir="$SB_TMP/records-class"
  (
    cd "$SB_WORK" || exit 1
    # shellcheck source=/dev/null
    . ./scripts/lib/role-set.sh
    # shellcheck source=/dev/null
    . ./scripts/lib/progress-record.sh
    export KIT_PROGRESS_DIR="$classdir"
    # The NEGATIVE half: unrecognised but whitespace-free. These must survive VERBATIM —
    # a typo is preserved so it stays visible, which is the whole point of the arm.
    kit_progress "Dev:C-1" "typo"      "unrecognised, no whitespace — must be preserved verbatim"
    kit_progress "Dev:C-2" "sta.tus"   "punctuation is not whitespace"
    # The POSITIVE half: whitespace of each kind that reaches this arm, plus the boundary
    # where the value collapses to nothing at all.
    kit_progress "Dev:C-3" "bad class" "a space — the measured case"
    kit_progress "Dev:C-4" "$(printf 'tab\tclass')" "a tab, which the column cleaner turns INTO a space"
    kit_progress "Dev:C-5" "  padded  " "leading whitespace, which a trailing-only trim leaves"
    kit_progress "Dev:C-6" ""          "no class at all — the empty boundary"
    # ...and alongside another extra, where a split key corrupts its NEIGHBOUR too.
    kit_progress "Dev:C-7" "bad class" "with a second extra" "gate=unit"
  ) >/dev/null 2>&1

  local ncls=0
  [ -d "$classdir" ] && ncls="$(cat "$classdir"/*.tsv 2>/dev/null | grep -c . || true)"
  # ASSERT THE OPERAND FIRST: seven calls, seven lines. Zero would make every check below
  # vacuously green — nothing having been written.
  if [ "${ncls:-0}" -ne 7 ]; then
    _control_did_not_run "drive the class arm ($ncls record(s) produced, expected 7) — nothing below was measured"
  else
    # THE NEGATIVE CONTROL. An unrecognised class with no whitespace is preserved BYTE FOR
    # BYTE. Asserted as equality against the value offered, not as "looks reasonable".
    grep -q 'declared-class=typo$' "$classdir"/*.tsv 2>/dev/null \
      || cf "a whitespace-free class was not preserved verbatim in declared-class= — the normaliser is rewriting the common case, which is worse than the split it fixes"
    grep -q 'declared-class=sta\.tus' "$classdir"/*.tsv 2>/dev/null \
      || cf "a whitespace-free class containing punctuation was altered — only WHITESPACE is collapsed"
    # ...AND THE CLOSED SET NEVER REACHES THE ARM AT ALL.
    awk -F'\t' '$3!="status" && $3!="info" && $3!="warning" && $3!="error" {bad=1} END{exit bad?1:0}' "$classdir"/*.tsv 2>/dev/null \
      || cf "a record carries a class outside the declared set — the arm must rewrite the column to info, not pass the offered value through"

    # THE POSITIVE. Every token in the extras field parses as `key=value`, on every line.
    # This is the property the contract states, asserted directly rather than via a regex
    # that only looks at the declared-class= key: a split corrupts the whole field.
    awk -F'\t' '$5!="" {n=split($5,p," "); for(i=1;i<=n;i++) if (p[i] !~ /=/) bad=1} END{exit bad?1:0}' "$classdir"/*.tsv 2>/dev/null \
      || cf "a class containing whitespace split the extras field into a token that is not a key=value pair — contracts/progress-record.md § Reserved extra keys requires a preserved value be collapsed to ONE TOKEN"
    # ...AND NO KEY IS WRITTEN WITH NOTHING AFTER THE `=`. The contract requires a
    # placeholder: an empty value is a key that looks answered and is not, which is the
    # same defect the run= seam states for itself.
    awk -F'\t' '$5 ~ /declared-class=($| )/ {bad=1} END{exit bad?1:0}' "$classdir"/*.tsv 2>/dev/null \
      || cf "declared-class= was written with an empty value — the contract requires a placeholder, or the key looks answered and is not"
    # ...AND THE NEIGHBOURING EXTRA SURVIVES INTACT.
    grep -q 'gate=unit' "$classdir"/*.tsv 2>/dev/null \
      || cf "a caller's own extra was lost beside a normalised declared-class= — the arm corrupted a neighbour"
  fi

  # ── § 5b, THE RESERVED `run=` EXTRA. The negative is the one that matters here too:
  #    an UNSET seam must write NO `run=` key at all, never `run=` with nothing after it.
  #    And an explicit argument must WIN over the environment without producing two keys.
  local rundir="$SB_TMP/records-run"
  (
    cd "$SB_WORK" || exit 1
    # shellcheck source=/dev/null
    . ./scripts/lib/role-set.sh
    # shellcheck source=/dev/null
    . ./scripts/lib/progress-record.sh
    export KIT_PROGRESS_DIR="$rundir" CLOCK_COUNT="$SB_TMP/clock.run" PATH="$clockdir:$PATH"
    unset KIT_PROGRESS_RUN
    kit_progress "Dev:ID-1" status "no run id in scope"
    KIT_PROGRESS_RUN="" kit_progress "Dev:ID-1" status "run id declared but EMPTY"
    KIT_PROGRESS_RUN="r-1" kit_progress "Dev:ID-1" status "run id in scope"
    KIT_PROGRESS_RUN="r-env" kit_progress "Dev:ID-1" status "explicit wins" "run=r-arg" "event=x"
  ) >/dev/null 2>&1

  local nrun=0
  [ -d "$rundir" ] && nrun="$(cat "$rundir"/*.tsv 2>/dev/null | grep -c . || true)"
  _ndays=0; for _f in "$rundir"/*.tsv; do [ -f "$_f" ] && _ndays=$(( _ndays + 1 )); done
  if [ "$_ndays" -ne 2 ]; then
    _control_did_not_run "cross midnight while writing the run-id records ($_ndays day file(s), expected 2) — the two-file shape was not exercised"
  elif [ "${nrun:-0}" -ne 4 ]; then
    _control_did_not_run "write the four run-id records ($nrun produced) — nothing below was measured"
  else
    # UNSET AND EMPTY WRITE NO KEY. An empty key is a column that looks answered and is
    # not, and it would make a reader filtering on `run=` collect unrelated records.
    [ "$(cat "$rundir"/*.tsv 2>/dev/null | grep -c 'run=' || true)" -eq 2 ] \
      || cf "an unset or empty run-id seam still wrote a run= key (or a set one did not) — § 5b says empty or unset writes NO key at all"
    # EXACTLY ONE `run=` PER RECORD THAT HAS ONE — the environment must not add a second.
    awk -F'\t' '{n=gsub(/(^| )run=/,"",$5); if (n>1) bad=1} END{exit bad?1:0}' "$rundir"/*.tsv 2>/dev/null \
      || cf "a record carries TWO run= keys — the explicit argument and the environment both wrote, and § 5b says the argument wins"
    # ...AND IT IS THE ARGUMENT THAT WON.
    grep -q 'run=r-arg' "$rundir"/*.tsv 2>/dev/null \
      || cf "an explicit run= argument did not reach the record — § 5b's precedence is what lets a caller change the run id on the fly"
    grep -q 'run=r-env' "$rundir"/*.tsv 2>/dev/null \
      && cf "the environment's run id overrode an explicit run= argument — § 5b declares the opposite precedence"
  fi

  # ── BYTE-IDENTITY, ACROSS ALL THREE PRESERVING KEYS AT ONCE. A preserved value is carried
  #    byte for byte (§ Reserved extra keys), and the population must include UNDERSCORES: a
  #    writer that substitutes whitespace with `_` and then trims `^_`/`_$` cannot tell its own
  #    separator from the caller's, so `_x` comes back as `x` and `_` as `<empty>`, while
  #    whitespace-free, underscore-free values all pass. The population is declared ONCE for
  #    the keys the writer synthesises (`grep -n _pr_tok scripts/lib/progress-record.sh`; a key
  #    with no row here is untested). Asserted as EQUALITY with the offered value: the defect
  #    yields well-formed output that is simply not what the caller wrote.
  local tokdir="$SB_TMP/records-tok"
  # Space-separated because the whole population is whitespace-free BY CONSTRUCTION —
  # a value with whitespace in it belongs in the POSITIVE halves above, not here.
  local tok_pop='_ __ ___ _x x_ _x_ _snake_case_ __both__ a_b typo sta.tus no_edge_underscores -_- _._ 13/13 KIT-042 _run_ run_ _run'
  local ntok=0 tok_bad=0 tok_drove=0 _v _arm _key _got
  for _v in $tok_pop; do ntok=$(( ntok + 3 )); done
  # The population's premise, asserted: every member is already one token, or a row would be
  # expected to come back changed and would read as a writer failure.
  case "$tok_pop" in
    *"  "*|*"	"*) _fixture_die "case_progress_record_is_one_shape_and_optional: tok_pop carries a value with whitespace in it, but every member must be ALREADY one token — that is the premise of the byte-identity comparison, and a spaced member would be asserted to survive a collapse it is supposed to undergo." ;;
  esac
  (
    cd "$SB_WORK" || exit 1
    # shellcheck source=/dev/null
    . ./scripts/lib/role-set.sh
    # shellcheck source=/dev/null
    . ./scripts/lib/progress-record.sh
    # ONE DIRECTORY PER ROW so the offered value can be recovered from the record without
    # parsing it back out of a shared file — the comparison is against what was OFFERED.
    i=0
    for v in $tok_pop; do
      i=$(( i + 1 ))
      # declared-class= — the class is outside the closed enum, so the arm fires.
      KIT_PROGRESS_DIR="$tokdir/$i-class" kit_progress "Dev:T" "$v" "byte-identity row"
      # declared-actor= — the actor is outside § 5b's shape, so the validator tags it.
      KIT_PROGRESS_DIR="$tokdir/$i-actor" kit_progress "$v" info "byte-identity row"
      # run= — the adopter-set seam, the one reachable on a stock tree.
      KIT_PROGRESS_DIR="$tokdir/$i-run" KIT_PROGRESS_RUN="$v" kit_progress "Dev:T" info "byte-identity row"
    done
  ) >/dev/null 2>&1

  local ntok_rec=0
  [ -d "$tokdir" ] && ntok_rec="$(cat "$tokdir"/*/*.tsv 2>/dev/null | grep -c . || true)"
  # ASSERT THE OPERAND FIRST: three records per population member. A short count means
  # an arm did not fire at all, which would make every comparison below vacuously green.
  if [ "${ntok_rec:-0}" -ne "$ntok" ]; then
    _control_did_not_run "drive the byte-identity population through all three preserving keys ($ntok_rec record(s) produced, expected $ntok) — nothing below was measured"
  else
    local _i=0
    for _v in $tok_pop; do
      _i=$(( _i + 1 ))
      for _arm in class actor run; do
        case "$_arm" in
          class) _key='declared-class=' ;;
          actor) _key='declared-actor=' ;;
          run)   _key='run=' ;;
        esac
        _got="$(awk -F'\t' -v k="$_key" '{n=split($5,p," "); for(i=1;i<=n;i++) if (index(p[i],k)==1) print substr(p[i],length(k)+1)}' "$tokdir/$_i-$_arm"/*.tsv 2>/dev/null)"
        tok_drove=$(( tok_drove + 1 ))
        if [ "$_got" != "$_v" ]; then
          tok_bad=$(( tok_bad + 1 ))
          # REPORT THE FIRST THREE IN FULL AND COUNT THE REST. Every row carries the same
          # diagnosis, so a broken cleaner would otherwise print one failure per population
          # member and bury the rest of the case; the tally below names the true total.
          [ "$tok_bad" -le 3 ] && cf "a value that was ALREADY one token was rewritten in ${_key} — offered [$_v], carried [$_got]. contracts/progress-record.md § Reserved extra keys requires it be carried BYTE FOR BYTE: a collapse touches WHITESPACE and nothing else, and a writer that trims its own substituted separator cannot tell it from one the caller typed. The record is then well-formed and wrong, which a reader cannot detect at all."
        fi
      done
    done
    # THE TALLY, ALWAYS. It states the true total when more than three rows broke, and it
    # is also the control on the LOOP: a comparison that silently skipped rows would leave
    # tok_drove short while every row it did reach passed.
    [ "$tok_drove" -eq "$ntok" ] \
      || _control_did_not_run "compare every byte-identity row (drove $tok_drove of $ntok) — the loop did not cover the population it declared"
    [ "$tok_bad" -eq 0 ] \
      || cf "$tok_bad of $ntok value/key rows carried a rewritten value — an already-one-token value must survive declared-class=, declared-actor= and run= byte for byte (first three reported above)"
  fi

  # ── THE ABLATION (§ 4), EXECUTED, against move-issue.sh --help: it runs the sourcing block
  #    without needing a board, and an abort from an unguarded `.` under `set -euo pipefail`
  #    would show as a changed exit status.
  local mv="$SB_WORK/scripts/move-issue.sh"
  if [ ! -x "$mv" ]; then
    _control_did_not_run "find an executable move-issue.sh to ablate against"
  else
    local with_out="$SB_TMP/with.out" with_err="$SB_TMP/with.err" with_rc=0
    ( cd "$SB_WORK" && ./scripts/move-issue.sh --help ) >"$with_out" 2>"$with_err" || with_rc=$?

    mv "$lib" "$SB_TMP/progress-record.sh.away" 2>/dev/null || true
    local wo_out="$SB_TMP/without.out" wo_err="$SB_TMP/without.err" wo_rc=0
    ( cd "$SB_WORK" && ./scripts/move-issue.sh --help ) >"$wo_out" 2>"$wo_err" || wo_rc=$?
    mv "$SB_TMP/progress-record.sh.away" "$lib" 2>/dev/null || true

    # THE CONTROL ON THE ABLATION ITSELF: if the library was not actually gone for the
    # second run, "identical" proves nothing. Asserted rather than assumed, because a
    # failed `mv` above is silenced by its own `|| true`.
    [ -f "$SB_TMP/progress-record.sh.away" ] \
      && _control_did_not_run "restore the library — the ablation left the sandbox modified"

    [ "$with_rc" -eq "$wo_rc" ] \
      || cf "removing scripts/lib/progress-record.sh changed move-issue.sh's exit status ($with_rc → $wo_rc) — the record is a DEPENDENCY, which contracts/progress-record.md § 2 forbids"
    cmp -s "$with_out" "$wo_out" \
      || cf "removing scripts/lib/progress-record.sh changed move-issue.sh's stdout — the record is not additive"
    cmp -s "$with_err" "$wo_err" \
      || cf "removing scripts/lib/progress-record.sh changed move-issue.sh's stderr — the record is not additive"
  fi

  finish "the progress record writes one shape ($nrec records, uniform columns, required fields present), § 5b's actor shape accepts all $nroles derived role(s) untagged and normalises a malformed one WITHOUT dropping it, the run= extra is absent when its seam is unset and an explicit one wins, every already-one-token value is carried BYTE-IDENTICAL across declared-class=, declared-actor= and run= ($ntok value/key rows compared as equality against the value offered), and removing the library leaves move-issue.sh byte-identical in stdout, stderr and exit status"
  teardown
}

# =============================================================================
# CASE — EVERY WORKTREE OF ONE REPOSITORY WRITES ONE PLACE.
# A record written from a linked worktree lands in the MAIN checkout's .progress-records/,
# where the orchestrator reads, and survives the worktree's removal (the landing flow removes a
# leg's worktree). The operand is asserted first: a record in NEITHER tree means the library
# never loaded.
# =============================================================================
case_progress_record_one_place_across_worktrees() {
  cf_reset
  make_sandbox

  if [ ! -f "$SB_WORK/scripts/lib/progress-record.sh" ]; then
    skp "progress records from a linked worktree land in the main checkout" "scripts/lib/progress-record.sh is not in the sandbox"
    teardown; return
  fi

  # make_sandbox leaves HEAD unborn, and a worktree needs a commit to check out. A setup
  # commit, so it goes through sbcommit (which bypasses the role-prefix hook) like every other.
  local wt="$SB_TMP/linked-wt" n_main=0 n_wt=0
  sbcommit -q --allow-empty -m "seed for a linked worktree" >/dev/null 2>&1
  if ! git -C "$SB_WORK" worktree add -q --detach "$wt" >/dev/null 2>&1; then
    _control_did_not_run "create a linked worktree of the sandbox — nothing below was measured"
  else
    (
      cd "$wt" || exit 1
      unset KIT_PROGRESS_DIR
      # shellcheck source=/dev/null
      . "$SB_WORK/scripts/lib/progress-record.sh"
      kit_progress "Dev:ID-1" status "written from a linked worktree"
    ) >/dev/null 2>&1
    n_main="$(cat "$SB_WORK"/.progress-records/*.tsv 2>/dev/null | grep -c 'written from a linked worktree' || true)"
    n_wt="$(cat "$wt"/.progress-records/*.tsv 2>/dev/null | grep -c . || true)"
    if [ "$(( ${n_main:-0} + ${n_wt:-0} ))" -eq 0 ]; then
      _control_did_not_run "write one record from the linked worktree (none in either tree)"
    else
      [ "${n_main:-0}" -eq 1 ] \
        || cf "a record written from a linked worktree did not land in the main checkout's .progress-records/ ($n_main there) — the orchestrator reads there"
      [ "${n_wt:-0}" -eq 0 ] \
        || cf "a record written from a linked worktree landed under the worktree's own root ($n_wt there) — it is deleted with the worktree when the leg lands"
      git -C "$SB_WORK" worktree remove --force "$wt" >/dev/null 2>&1
      [ ! -d "$wt" ] || cf "control: the linked worktree was NOT removed, so its survival is unmeasured"
      grep -q 'written from a linked worktree' "$SB_WORK"/.progress-records/*.tsv 2>/dev/null \
        || cf "the record did not survive removing the linked worktree"
    fi
  fi

  finish "a progress record written from a linked worktree lands in the main checkout's .progress-records/ ($n_main there, $n_wt in the worktree) and survives the worktree's removal"
  teardown
}

# =============================================================================
# CASE — A REFUSAL MADE THROUGH kit_refuse LEAVES ONE COUNTABLE RECORD, AND STILL REFUSES.
#
# scripts/lib/refuse.sh, driven from a probe script under `set -euo pipefail`:
#   (a) the message reaches stderr one argument per line, the exit status is the one given,
#       and exactly one record is written: class `error`, the probe as actor, `refusal=<id>`;
#   (b) with the record directory unwritable, and (c) with the writer deleted, stderr and the
#       status are byte-identical to (a) — the record never decides the refusal;
#   (d) a malformed call never exits 0, names itself, and is still counted.
# The helper's ABSENCE is a FAIL, not a SKIP: a script that calls it cannot refuse without it.
# =============================================================================
case_refusal_leaves_one_countable_record() {
  cf_reset
  make_sandbox
  local L="kit_refuse prints, exits with the given status and writes exactly one error record carrying refusal=<rule-id>; the record never changes the refusal; a malformed call never exits 0"
  local lib="$SB_WORK/scripts/lib/refuse.sh" pr="$SB_WORK/scripts/lib/progress-record.sh"
  local probe="$SB_WORK/scripts/refusal-probe.sh"
  if [ ! -f "$lib" ]; then
    cf "scripts/lib/refuse.sh is not in the sandbox — kit_refuse does not exist, so no refusal can leave a record"
    finish "$L"; teardown; return
  fi
  [ -f "$pr" ] \
    || _fixture_die "case_refusal_leaves_one_countable_record: scripts/lib/progress-record.sh is not in the sandbox, so arm (a) has no writer and arm (c)'s ablation removes nothing."

  cat > "$probe" <<'PROBE'
#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib/refuse.sh"
kit_refuse "$@"
echo "kit_refuse returned to its caller"
PROBE
  chmod +x "$probe"

  # _rp <tag> <records-dir> <args…> — run the probe; stdout, stderr and status land in $SB_TMP/<tag>.*
  _rp() {
    local tag="$1" dir="$2" rc=0; shift 2
    ( cd "$SB_WORK" && KIT_PROGRESS_DIR="$dir" ./scripts/refusal-probe.sh "$@" ) \
      >"$SB_TMP/$tag.out" 2>"$SB_TMP/$tag.err" || rc=$?
    printf '%s' "$rc" > "$SB_TMP/$tag.rc"
  }
  _rp_rc()  { cat "$SB_TMP/$1.rc"; }
  _rp_err() { tr '\n' '|' < "$SB_TMP/$1.err" | cut -c1-200; }
  _rp_n()   { cat "$1"/*.tsv 2>/dev/null | grep -c . || true; }

  # ── (a) THE REFUSAL AND ITS ONE RECORD.
  local ra="$SB_TMP/rec-a" n rec
  _rp a "$ra" 7 probe-rule "Error: probe refused" "  second line"
  [ "$(_rp_rc a)" = 7 ] || cf "(a) exited $(_rp_rc a), want the status given (7): $(_rp_err a)"
  [ ! -s "$SB_TMP/a.out" ] \
    || cf "(a) the probe went on after kit_refuse, or kit_refuse wrote to stdout: $(tr '\n' '|' < "$SB_TMP/a.out")"
  { grep -qx 'Error: probe refused' "$SB_TMP/a.err" && grep -qx '  second line' "$SB_TMP/a.err"; } \
    || cf "(a) stderr does not carry the message one argument per line: $(_rp_err a)"
  n="$(_rp_n "$ra")"
  if [ "${n:-0}" -ne 1 ]; then
    cf "(a) $n record(s) written, want exactly 1 — a refusal that leaves no record cannot be counted"
  else
    rec="$(cat "$ra"/*.tsv)"
    [ "$(printf '%s' "$rec" | awk -F'\t' '{print $2}')" = "refusal-probe.sh" ] \
      || cf "(a) the record's actor is not the calling script, refusal-probe.sh: $rec"
    [ "$(printf '%s' "$rec" | awk -F'\t' '{print $3}')" = "error" ] \
      || cf "(a) the record's class is not error: $rec"
    [ "$(printf '%s' "$rec" | awk -F'\t' '{print $4}')" = "Error: probe refused" ] \
      || cf "(a) the record's description is not the message's first line: $rec"
    case " $(printf '%s' "$rec" | awk -F'\t' '{print $5}') " in
      *" refusal=probe-rule "*) : ;;
      *) cf "(a) the record carries no refusal=probe-rule extra: $rec" ;;
    esac
  fi

  # ── (b) AN UNWRITABLE RECORD DIRECTORY: a path under a regular FILE, which no user can create.
  local blocker="$SB_TMP/not-a-dir"
  : > "$blocker"
  _rp b "$blocker/records" 7 probe-rule "Error: probe refused" "  second line"
  [ "$(_rp_rc b)" = 7 ] || cf "(b) with the record directory unwritable, exited $(_rp_rc b), want 7: $(_rp_err b)"
  cmp -s "$SB_TMP/a.err" "$SB_TMP/b.err" \
    || cf "(b) with the record directory unwritable, stderr differs from (a): $(_rp_err b)"
  [ -f "$blocker" ] || _control_did_not_run "keep the blocking file in place for arm (b)"

  # ── (c) THE ABLATION: the writer deleted.
  local rc_dir="$SB_TMP/rec-c"
  mv "$pr" "$SB_TMP/progress-record.sh.away"
  if [ -f "$pr" ]; then
    _control_did_not_run "move scripts/lib/progress-record.sh away for arm (c)"
  else
    _rp c "$rc_dir" 7 probe-rule "Error: probe refused" "  second line"
    mv "$SB_TMP/progress-record.sh.away" "$pr"
    [ "$(_rp_rc c)" = 7 ] || cf "(c) with the writer deleted, exited $(_rp_rc c), want 7: $(_rp_err c)"
    cmp -s "$SB_TMP/a.err" "$SB_TMP/c.err" \
      || cf "(c) with the writer deleted, stderr differs from (a): $(_rp_err c)"
    [ "$(_rp_n "$rc_dir")" = 0 ] || cf "(c) a record was written with the writer deleted — the ablation did not remove it"
  fi

  # ── (d) MALFORMED CALLS. Each must exit non-zero and name itself; none may exit 0.
  local row args tag i=0
  for row in '0|probe-rule|Error: x' 'abc|probe-rule|Error: x' '256|probe-rule|Error: x' \
             '7|Probe Rule|Error: x' '7|probe_rule|Error: x' '7|probe-rule|' '||'; do
    i=$(( i + 1 )); tag="d$i"
    IFS='|' read -r -a args <<< "$row"
    [ -n "${args[2]:-}" ] || args=("${args[0]:-}" "${args[1]:-}")
    [ -n "${args[0]:-}${args[1]:-}" ] || args=()
    _rp "$tag" "$SB_TMP/rec-$tag" ${args[@]+"${args[@]}"}
    [ "$(_rp_rc "$tag")" != 0 ] || cf "(d) the malformed call [$row] exited 0 — a refusal that succeeds"
    grep -q 'kit_refuse: malformed call' "$SB_TMP/$tag.err" \
      || cf "(d) the malformed call [$row] does not name itself on stderr: $(_rp_err "$tag")"
  done
  # The two statuses the helper declares for a malformed call: its own for a bad status, the
  # caller's for a bad rule id. And the malformed call is still counted.
  [ "$(_rp_rc d1)" = 70 ] || cf "(d) a status of 0 exited $(_rp_rc d1), want 70"
  [ "$(_rp_rc d4)" = 7 ] || cf "(d) a malformed rule id with a valid status exited $(_rp_rc d4), want the caller's 7"
  grep -qx 'Error: x' "$SB_TMP/d1.err" || cf "(d) a malformed call dropped the caller's message: $(_rp_err d1)"
  if [ "$(_rp_n "$SB_TMP/rec-d1")" = 1 ]; then
    grep -q 'refusal=kit-refuse-malformed' "$SB_TMP/rec-d1"/*.tsv \
      || cf "(d) the malformed call's record does not carry refusal=kit-refuse-malformed: $(cat "$SB_TMP/rec-d1"/*.tsv)"
  else
    cf "(d) a malformed call wrote $(_rp_n "$SB_TMP/rec-d1") record(s), want 1 — it would vanish from the count"
  fi

  unset -f _rp _rp_rc _rp_err _rp_n
  finish "$L"
  teardown
}

# =============================================================================
# CASE — --set-pr WRITES BACK INTO A CARD MINTED FROM THE REAL TEMPLATE
#
# `--set-pr` writes only into an EXISTING `pr:` line and otherwise warns "skipping
# write-back", so the card is MINTED through new-issue.sh from the real template, never
# seeded: the seam is between the template and the tool. Two premises are asserted: the
# minted card carries a `pr:` line, and it is ON the trunk before the mover runs (a not-found
# refusal there is about the fixture, not the mover).
# =============================================================================
case_move_issue_set_pr_on_a_minted_card() {
  cf_reset
  if ! has_kit_init; then
    skp "move-issue --set-pr writes back into a minted card" "scripts/kit-init.sh absent"; return
  fi
  if ! has_issue_template; then skp "move-issue --set-pr writes back into a minted card" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox

  local id="$SB_PREFIX-777" card="progress/todo/$SB_PREFIX-777-setpr-probe.md" out rc
  out="$( cd "$SB_WORK" && ./scripts/new-issue.sh setpr-probe --id "$id" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "new-issue.sh exited $rc minting $id: $out"
  [ -f "$SB_WORK/$card" ] || cf "new-issue.sh did not create $card: $out"

  # PREMISE 1 — the template half. Without a `pr:` line there is nothing to write back
  # into, and --set-pr would warn rather than fail, so this case would pass vacuously.
  if [ -f "$SB_WORK/$card" ]; then
    grep -q '^pr:' "$SB_WORK/$card"       || _fixture_die "case_move_issue_set_pr_on_a_minted_card: the minted card carries no 'pr:' frontmatter line, so --set-pr has nothing to write into and this case cannot distinguish the fix from its absence."
  fi

  publish_sandbox

  # PREMISE 2 — the mover reads the TRUNK's board, not the checkout. If the mint did
  # not reach the trunk the mover refuses "no file matching …", which reads exactly
  # like a mover defect and is a fixture gap.
  origin_has_path "$card"     || _fixture_die "case_move_issue_set_pr_on_a_minted_card: $card is not on the trunk after publish_sandbox, so the mover would refuse with a not-found that is about the fixture."

  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$id" in_progress \
            --role "$SB_ROLE" --note "set-pr probe" --set-pr 'https://example.invalid/pr/1' 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "the move with --set-pr exited $rc: $out"
  printf '%s\n' "$out" | grep 'skipping write-back' >/dev/null \
    && cf "--set-pr reported 'skipping write-back' on a card minted from the shipped template — the template and the flag still do not meet: $out"
  origin_file_contains "progress/in_progress/$SB_PREFIX-777-setpr-probe.md" 'example.invalid/pr/1' \
    || cf "the --set-pr value did not reach the moved card on the trunk"

  finish "move-issue --set-pr writes back into a card minted from the SHIPPED template, and the value reaches the trunk"
  teardown
}

# =============================================================================
# CASE — a parent's own subtask cards never collide with the parent's lookup
#
# Subtask ids are <PARENT>-sM, so <PARENT>-*.md also names every card under
# progress/subtasks/<PARENT>/ and, once archived, progress/done/subtasks/<PARENT>/.
#   (a) a decomposed parent still moves;
#   (b) a done parent with an archived tree still takes a --note-only (a lookup that
#       prunes only progress/subtasks/ reddens here);
#   (c) a subtask id is not the mover's: it refuses, and the card stays in its tree.
# =============================================================================
case_move_issue_moves_a_decomposed_parent() {
  cf_reset
  make_sandbox
  local p="$SB_PREFIX-120" d="$SB_PREFIX-121" out rc
  local st="progress/subtasks/$p/todo/$p-s1-anchor.md"
  seed_issue in_progress "$p" parent chore "Decomposed parent"
  mkdir -p "$SB_WORK/progress/subtasks/$p/todo"
  seed_issue "subtasks/$p/todo" "$p-s1" anchor chore "First slice"
  seed_issue done "$d" archived chore "Archived parent"
  mkdir -p "$SB_WORK/progress/done/subtasks/$d/qa_complete"
  seed_issue "done/subtasks/$d/qa_complete" "$d-s1" slice chore "Archived slice"
  publish_sandbox
  origin_has_path "$st" || _fixture_die "case_move_issue_moves_a_decomposed_parent: $st is not on the trunk, so (a) would pass without a subtask to collide with."

  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$p" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) moving a parent with a subtask exited $rc: $(printf '%s' "$out" | tr '\n' '|')"
  origin_has_path "progress/dev_complete/$p-parent.md" || cf "(a) the parent did not reach dev_complete/ on the trunk"

  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$d" --note-only --role Dev --note "late note" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) a note on a done parent with an archived subtask tree exited $rc: $(printf '%s' "$out" | tr '\n' '|')"

  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$p-s1" in_progress --role Dev --note "wrong tool" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(c) move-issue.sh moved subtask $p-s1 out of its tree"
  origin_has_path "$st" || cf "(c) subtask $p-s1 left $st"

  finish "move-issue.sh: a parent with live or archived subtasks moves, and a subtask id is refused"
  teardown
}

# =============================================================================
# CASE — A PARENT ADVANCES ONLY WHEN EVERY SUBTASK HAS.
#
# qa_complete and done claim the whole issue reviewed, and archive.sh retires the subtask tree
# with its parent, so a slice still open would be filed as completed. Each tool that can make
# the claim refuses before it writes:
#   (a) move-issue.sh to qa_complete, and (b) to done;
#   (c) finish-pr.sh, before the merge (the advance after it would refuse, leaving it landed);
#   (d) archive.sh, for a parent already in qa_complete with an open slice;
#   (e) control: with every slice in qa_complete the parent moves.
# =============================================================================
case_parent_advances_only_with_every_subtask() {
  cf_reset
  make_sandbox
  local p="$SB_PREFIX-130" q="$SB_PREFIX-131" out rc
  seed_issue dev_complete "$p" parent chore "Decomposed parent" "feature/$p-parent"
  mkdir -p "$SB_WORK/progress/subtasks/$p/todo" "$SB_WORK/progress/subtasks/$p/qa_complete"
  seed_issue "subtasks/$p/todo" "$p-s1" open chore "Open slice"
  seed_issue "subtasks/$p/qa_complete" "$p-s2" done chore "Reviewed slice"
  seed_issue qa_complete "$q" parent chore "Parent already reviewed"
  mkdir -p "$SB_WORK/progress/subtasks/$q/in_progress"
  seed_issue "subtasks/$q/in_progress" "$q-s1" open chore "Open slice"
  publish_sandbox
  seed_branch "$p" parent CHANGE130.txt

  local tgt
  for tgt in qa_complete done; do
    rc=0; out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$p" "$tgt" --role QA --note "review" 2>&1 )" || rc=$?
    [ "$rc" -ne 0 ] || cf "($tgt) move-issue.sh moved a parent with an open subtask to $tgt/"
    printf '%s\n' "$out" | grep -F "progress/subtasks/$p/todo/$p-s1-open.md" >/dev/null \
      || cf "($tgt) the refusal does not name the open slice: $(printf '%s' "$out" | tr '\n' '|')"
    printf '%s\n' "$out" | grep -F "$p-s2-done.md" >/dev/null \
      && cf "($tgt) the refusal names a slice already in qa_complete/"
    origin_has_path "progress/dev_complete/$p-parent.md" || cf "($tgt) the parent left dev_complete/ during a refusal"
  done

  rc=0; out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$p" 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(c) finish-pr.sh landed a parent with an open subtask"
  origin_has_path "CHANGE130.txt" && cf "(c) the parent's branch was merged before the refusal"
  printf '%s\n' "$out" | grep -F "$p-s1-open.md" >/dev/null || cf "(c) the refusal does not name the open slice: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"

  rc=0; out="$( cd "$SB_WORK" && ./scripts/archive.sh --apply 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(d) archive.sh retired a parent whose subtask is open"
  origin_has_path "progress/subtasks/$q/in_progress/$q-s1-open.md" || cf "(d) the open slice left progress/subtasks/"
  origin_has_path "progress/qa_complete/$q-parent.md" || cf "(d) the parent left qa_complete/ during a refusal"
  printf '%s\n' "$out" | grep -F "$q-s1-open.md" >/dev/null || cf "(d) the refusal does not name the open slice: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"

  # The slice is reviewed by a fixture move: the control is about the parent, not subtask.sh.
  if ! { git -C "$SB_WORK" mv "progress/subtasks/$p/todo/$p-s1-open.md" "progress/subtasks/$p/qa_complete/$p-s1-open.md" \
         && sbcommit -q -m "[QA] $p-s1: reviewed" && git -C "$SB_WORK" push -q origin "$SB_TRUNK"; } >/dev/null 2>&1; then
    cf "(e) could not publish $p-s1 in qa_complete/, so the control did not run"
  else
    rc=0; out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$p" qa_complete --role QA --note "review" 2>&1 )" || rc=$?
    [ "$rc" -eq 0 ] || cf "(e) with every slice in qa_complete/ the parent still did not move (rc=$rc): $(printf '%s' "$out" | tail -3 | tr '\n' '|')"
    origin_has_path "progress/qa_complete/$p-parent.md" || cf "(e) the parent did not reach qa_complete/"
  fi

  finish "a parent with an open subtask is refused by move-issue.sh (qa_complete, done), by finish-pr.sh before the merge and by archive.sh before any write, each naming the open slice; with every slice reviewed, or a slice declined with its reason, it moves"
  teardown
}

case_subtask_declined_closes_a_slice() {
  cf_reset
  local L="subtask.sh declines a slice that will not be done — only with a reason — and a declined slice no longer holds its parent"
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  make_sandbox
  local q="$SB_PREFIX-132" out rc
  seed_issue qa_complete "$q" parent chore "Parent already reviewed"
  mkdir -p "$SB_WORK/progress/subtasks/$q/in_progress"
  seed_issue "subtasks/$q/in_progress" "$q-s1" open chore "Open slice"
  publish_sandbox
  rc=0; out="$( cd "$SB_WORK" && ./scripts/archive.sh --apply 2>&1 )" || rc=$?
  printf '%s\n' "$out" | grep -F "$q-s1-open.md" >/dev/null \
    || _fixture_die "case_subtask_declined_closes_a_slice: archive.sh did not refuse over the open slice, so the row tests nothing."
  rc=0; out="$( cd "$SB_WORK" && ./scripts/subtask.sh move "$q-s1" declined 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "subtask.sh declined a slice with no --note"
  origin_has_path "progress/subtasks/$q/in_progress/$q-s1-open.md" || cf "the slice moved during the no-note refusal"
  rc=0; out="$( cd "$SB_WORK" && ./scripts/subtask.sh move "$q-s1" declined --note "superseded by the parent's own fix" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "subtask.sh would not decline a slice with a reason (rc=$rc): $(printf '%s' "$out" | tail -3 | tr '\n' '|')"
  origin_has_path "progress/subtasks/$q/declined/$q-s1-open.md" || cf "the declined slice is not in declined/"
  rc=0; out="$( cd "$SB_WORK" && ./scripts/archive.sh --apply 2>&1 )" || rc=$?
  printf '%s\n' "$out" | grep -F "$q-s1-open.md" >/dev/null \
    && cf "archive.sh still refuses over a declined slice: $(printf '%s' "$out" | tail -3 | tr '\n' '|')"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — subtask.sh REFUSES A MOVE TO blocked/ WITHOUT A --note, as move-issue.sh does.
#
# A park whose blocker is not written down cannot be unparked by anyone but the seat that parked
# it; the default note ("git mv to blocked/.") records nothing in the one column whose purpose is
# the reason. The slice must not move on the refused call, and moves with a note.
# =============================================================================
case_subtask_blocked_needs_a_note() {
  cf_reset
  local L="subtask.sh refuses a move to blocked/ with no --note and leaves the slice where it was; with a note it parks"
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  make_sandbox
  local q="$SB_PREFIX-867" out rc
  seed_issue in_progress "$q" parent chore "Parent in progress"
  mkdir -p "$SB_WORK/progress/subtasks/$q/in_progress"
  seed_issue "subtasks/$q/in_progress" "$q-s1" open chore "Open slice"
  publish_sandbox
  rc=0; out="$( cd "$SB_WORK" && ./scripts/subtask.sh move "$q-s1" blocked 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "subtask.sh parked a slice in blocked/ with no --note"
  printf '%s\n' "$out" | grep -F -e '--note' >/dev/null \
    || cf "the refusal does not name --note as the way on: $(printf '%s' "$out" | tail -3 | tr '\n' '|')"
  origin_has_path "progress/subtasks/$q/in_progress/$q-s1-open.md" || cf "the slice moved during the no-note refusal"
  rc=0; out="$( cd "$SB_WORK" && ./scripts/subtask.sh move "$q-s1" blocked --note "waiting on the parent's schema decision" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(control) subtask.sh would not park a slice WITH a note (rc=$rc): $(printf '%s' "$out" | tail -3 | tr '\n' '|')"
  origin_has_path "progress/subtasks/$q/blocked/$q-s1-open.md" || cf "(control) the parked slice is not in blocked/"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE COMMIT LINE A CREATOR PRINTS PASSES THE COMMIT-MSG HOOK AS PRINTED.
#
# print_push_before_move tells the operator to commit the new card before moving it. The line must
# carry the card's own id and a role tag from the DECLARED set (the creator's seat when the set holds
# it, else the set's first tag); a literal [<Role>] <ID> is refused by the hook. Two arms: the
# shipped set, and a narrowed set that lacks the creator's seat.
# =============================================================================
_printed_commit_subject() {   # <creator output> -> the -m subject of the printed commit line
  printf '%s\n' "$1" | grep -F 'git commit -m' | head -1 | sed -n 's/.*git commit -m "\(.*\)" && git push.*/\1/p'
}
case_creator_prints_a_commit_line_the_hook_accepts() {
  cf_reset
  local L="new-issue.sh's printed commit line carries the card's id and a declared role, and the commit-msg hook accepts it as printed"
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  local id="$SB_PREFIX-878" id2="$SB_PREFIX-889" out rc subject msgfile="$SB_TMP/printed-subject.txt"
  local cm="$SB_WORK/scripts/githooks/commit-msg"
  out="$( cd "$SB_WORK" && ./scripts/new-issue.sh printed-line --id "$id" 2>&1 )" || _fixture_die "case_creator_prints_a_commit_line_the_hook_accepts: new-issue.sh refused: $out"
  subject="$(_printed_commit_subject "$out")"
  [ -n "$subject" ] || _fixture_die "case_creator_prints_a_commit_line_the_hook_accepts: no commit line found in the creator's output, so there is nothing to test: $out"
  case "$subject" in
    *"$id"*) : ;;
    *) cf "(a) the printed commit subject does not carry the card's id $id: $subject" ;;
  esac
  printf '%s\n' "$subject" > "$msgfile"
  rc=0; ( cd "$SB_WORK" && env -u MSG_OK "$cm" "$msgfile" >/dev/null 2>&1 ) || rc=$?
  [ "$rc" -eq 0 ] || cf "(a) the commit-msg hook refuses the line the creator printed: $subject"

  # (b) A set without the creator's seat: the line must use a tag the set holds.
  NEU_NEW='Dev|QA' perl -i -pe "s@^ROLE_PREFIXES='.*'\$@ROLE_PREFIXES='\$ENV{NEU_NEW}'@" "$cm"
  grep -qxF "ROLE_PREFIXES='Dev|QA'" "$cm" \
    || _fixture_die "case_creator_prints_a_commit_line_the_hook_accepts: the narrowed role set did not land in the sandbox's commit-msg."
  out="$( cd "$SB_WORK" && ./scripts/new-issue.sh printed-line-two --id "$id2" 2>&1 )" || _fixture_die "case_creator_prints_a_commit_line_the_hook_accepts: new-issue.sh refused under the narrowed set: $out"
  subject="$(_printed_commit_subject "$out")"
  printf '%s\n' "$subject" > "$msgfile"
  rc=0; ( cd "$SB_WORK" && env -u MSG_OK "$cm" "$msgfile" >/dev/null 2>&1 ) || rc=$?
  [ "$rc" -eq 0 ] || cf "(b) under a role set without PM the printed line is refused by the hook: $subject"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE MAIN CHECKOUT'S FAST-FORWARD NOTE NAMES THE CAUSE IT CAN TELL.
#
# After a landing the mover fast-forwards a clean main checkout that is on the trunk. It fails for
# two reasons that need different actions: the checkout holds commits the trunk lacks (diverged),
# or it holds an UNTRACKED file the trunk now tracks (the state register-commit.sh leaves when it
# lands a new file from the working tree). Each gets its own note; a landing that fast-forwards
# says so.
# =============================================================================
case_main_checkout_fast_forward_note_names_its_cause() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-894" ff-diverged chore "A card moved while the checkout holds a local commit"
  publish_sandbox
  local out rc

  # (a) untracked in the main checkout, landed by register-commit.sh from the working tree.
  mkdir -p "$SB_WORK/progress/todo"
  printf 'a new card\n' > "$SB_WORK/progress/todo/$SB_PREFIX-892-ff-untracked.md"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "$SB_PREFIX-892: mint" "progress/todo/$SB_PREFIX-892-ff-untracked.md" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || _fixture_die "case_main_checkout_fast_forward_note_names_its_cause: register-commit.sh exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/todo/$SB_PREFIX-892-ff-untracked.md" || _fixture_die "case_main_checkout_fast_forward_note_names_its_cause: the file did not reach the trunk, so the premise of arm (a) is gone."
  printf '%s\n' "$out" | grep -i 'untracked' >/dev/null \
    || cf "(a) the note does not name the untracked file as the cause: $(printf '%s' "$out" | grep -i 'fast-forward' | tr '\n' '|')"
  printf '%s\n' "$out" | grep -F '(diverged)' >/dev/null \
    && cf "(a) the note still calls an untracked-file collision 'diverged': $(printf '%s' "$out" | grep -i 'fast-forward' | tr '\n' '|')"

  # (b) a local commit the trunk lacks: diverged, and counted. A board move lands it (register-commit.sh
  # refuses a trunk holding unpushed commits, so it cannot reach this state).
  rm -f "$SB_WORK/progress/todo/$SB_PREFIX-892-ff-untracked.md"
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  git -C "$SB_WORK" reset -q --hard "origin/$SB_TRUNK" >/dev/null 2>&1
  printf 'local only\n' > "$SB_WORK/local-only.txt"
  git -C "$SB_WORK" add local-only.txt >/dev/null 2>&1
  sbcommit -m "[PM] a local commit nobody pushed" --quiet >/dev/null 2>&1
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/move-issue.sh "$SB_PREFIX-894" in_progress --role Dev --note "picked up" 2>&1 )" || rc=$?
  printf '%s\n' "$out" | grep -E 'diverged: it has [0-9]+ commit' >/dev/null \
    || cf "(b) a main checkout holding a commit the trunk lacks is not reported as diverged with a count (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"

  finish "the fast-forward note after a landing names an untracked-file collision as such, and a checkout holding commits the trunk lacks as diverged"
  teardown
}

# =============================================================================
# CASE — AFTER A LANDING, THE CHECKOUT'S EDITED COPY IS NAMED, AND DISCARDING IT CLEARS THE PULL.
#
# register-commit.sh reads the edit out of the checkout and leaves it there. The trunk holds it now,
# so `git pull --ff-only` is refused for that path until the copy is discarded. The success output
# names the discard for a modified tracked file (git checkout) and an untracked one (rm), and the
# main checkout's "local changes" note says it too; running what it names clears the pull.
# =============================================================================
case_register_commit_names_the_discard_of_the_checkouts_copy() {
  cf_reset
  make_sandbox
  printf 'D-01: a ruling\n' > "$SB_WORK/requirements-register.md"
  publish_sandbox
  local out rc

  # (a) a tracked file edited in the main checkout, then landed.
  printf 'D-02: answered here\n' >> "$SB_WORK/requirements-register.md"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "record D-02" requirements-register.md 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || _fixture_die "case_register_commit_names_the_discard_of_the_checkouts_copy: register-commit.sh exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_file_contains "requirements-register.md" '^D-02: answered here$' \
    || _fixture_die "case_register_commit_names_the_discard_of_the_checkouts_copy: the edit did not reach the trunk, so the premise is gone."
  printf '%s\n' "$out" | grep -F "git checkout -- 'requirements-register.md'" >/dev/null \
    || cf "(a) the success output does not name the discard of the edited copy: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"
  printf '%s\n' "$out" | grep 'left untouched' | grep -F 'git checkout --' >/dev/null \
    || cf "(a) the main checkout's 'local changes' note does not name the discard: $(printf '%s' "$out" | grep -i 'local changes' | tr '\n' '|')"
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  git -C "$SB_WORK" merge --ff-only "origin/$SB_TRUNK" >/dev/null 2>&1 \
    && cf "(a) control: the pull was NOT refused for the edited copy, so the note warns of nothing"
  git -C "$SB_WORK" checkout -- requirements-register.md >/dev/null 2>&1
  git -C "$SB_WORK" merge --ff-only "origin/$SB_TRUNK" >/dev/null 2>&1 \
    || cf "(a) discarding the copy the output named did not clear the pull"

  # (a2) the same edit STAGED: the note names a command that discards the staged copy too, and
  # running it leaves the path clean.
  printf 'D-03: answered staged\n' >> "$SB_WORK/requirements-register.md"
  git -C "$SB_WORK" add requirements-register.md
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "record D-03" requirements-register.md 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || _fixture_die "case_register_commit_names_the_discard_of_the_checkouts_copy: the staged landing exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -F "git restore --staged --worktree -- 'requirements-register.md'" >/dev/null \
    || cf "(a2) the note for a STAGED copy does not name a command that discards the index entry: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"
  git -C "$SB_WORK" restore --staged --worktree -- requirements-register.md >/dev/null 2>&1
  [ -z "$(git -C "$SB_WORK" status --porcelain -- requirements-register.md)" ] \
    || cf "(a2) running the named command left the path modified: $(git -C "$SB_WORK" status --porcelain -- requirements-register.md)"
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  git -C "$SB_WORK" merge --ff-only "origin/$SB_TRUNK" >/dev/null 2>&1 \
    || cf "(a2) after the named discard the pull is still refused"

  # (b) a new file, untracked in the checkout, then landed.
  printf 'a new note\n' > "$SB_WORK/note-b.md"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "record a note" note-b.md 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || _fixture_die "case_register_commit_names_the_discard_of_the_checkouts_copy: register-commit.sh exited $rc on the new file."
  printf '%s\n' "$out" | grep -F "rm 'note-b.md'" >/dev/null \
    || cf "(b) the success output does not name the removal of the untracked copy: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"

  finish "register-commit.sh names the discard of the checkout's copy (git checkout for a modified file, rm for an untracked one), the main checkout's 'local changes' note names it too, and running it clears the pull the copy refused"
  teardown
}

# =============================================================================
# CASE — register-commit.sh REFUSES A REGISTER LINE THAT CITES AN ANSWER THE TRUNK LACKS.
#
# A register entry whose Provenance names a question file records a decision whose source the trunk
# cannot show while the file's `**Answer` sits only in the caller's checkout; every arm of check-board
# then reads clean. The landing refuses until the question file rides in the same call.
# Rows: (a) the register alone, citing a question whose Answer is uncommitted -> refused, naming the
# file, the trunk unchanged; (b) the same call with the question file added -> lands both;
# (c) a citation of a question with no Answer -> lands; (d) a citation of a question whose answer is
# already on the trunk -> lands; (e) ablation: the guard removed, (a)'s call lands.
# =============================================================================
case_register_commit_refuses_a_register_line_citing_an_unlanded_answer() {
  cf_reset
  make_sandbox
  _ask_fill_pm "$SB_WORK"
  mkdir -p "$SB_WORK/requirements"
  printf '# DECISIONS.md\n\n## A. test bucket\n\n### D-01 — an unrelated ruling\n\n**Ruling.** Keep it small.\n**Why.** Because.\n**Provenance.** 2026-01-01, no work item.\n\n---\n' > "$SB_WORK/requirements/DECISIONS.md"
  publish_sandbox
  local o1 o2 o3 q1 q2 q3 r1 r2 r3 out rc
  o1="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec1" ./scripts/ask.sh --role Dev "Question one?" --default "A." 2>&1 )" || _fixture_die "case_register_commit_refuses_a_register_line_citing_an_unlanded_answer: ask.sh refused: $o1"
  o2="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec2" ./scripts/ask.sh --role Dev "Question two?" --default "B." 2>&1 )" || _fixture_die "second ask.sh refused: $o2"
  o3="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec3" ./scripts/ask.sh --role Dev "Question three?" --default "C." 2>&1 )" || _fixture_die "third ask.sh refused: $o3"
  q1="$(printf '%s\n' "$o1" | sed -n 's/^ask.sh: question written to //p')"; r1="dev/questions/${q1#*/dev/questions/}"
  q2="$(printf '%s\n' "$o2" | sed -n 's/^ask.sh: question written to //p')"; r2="dev/questions/${q2#*/dev/questions/}"
  q3="$(printf '%s\n' "$o3" | sed -n 's/^ask.sh: question written to //p')"; r3="dev/questions/${q3#*/dev/questions/}"
  [ -f "$q1" ] && [ -f "$q2" ] && [ -f "$q3" ] || _fixture_die "case_register_commit_refuses_a_register_line_citing_an_unlanded_answer: ask.sh wrote no question file(s)"
  publish_sandbox
  # Question three is answered AND landed: the trunk holds its answer.
  printf '\n**Answer (2026-10-25, Ros):** Three.\n' >> "$q3"
  publish_sandbox
  _cite() {  # <D-id> <question path>
    printf '\n### %s — a ruling\n\n**Ruling.** As answered.\n**Why.** The principal said so.\n**Provenance.** 2026-10-25, the answer in %s; no work item.\n\n---\n' "$1" "$2" >> "$SB_WORK/requirements/DECISIONS.md"
  }

  # (a) the answer is uncommitted and the call names the register alone.
  printf '\n**Answer (2026-10-25, Ros):** One.\n' >> "$q1"
  _cite D-02 "$r1"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "record D-02" requirements/DECISIONS.md 2>&1 )" || rc=$?
  [ "$rc" -eq 1 ] || cf "(a) the register citing an unlanded answer was not refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -F "$r1" >/dev/null || cf "(a) the refusal does not name the question file $r1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep '^Next:' | grep -F "$r1" >/dev/null || cf "(a) the Next: line does not name the file to add: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_file_contains "requirements/DECISIONS.md" '^### D-02' && cf "(a) D-02 reached the trunk although the refusal fired"

  # (b) the same call with the question file added: both land.
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "answer recorded: $r1" requirements/DECISIONS.md "$r1" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(b) the call that carries the question file was refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_file_contains "requirements/DECISIONS.md" '^### D-02' || cf "(b) D-02 did not land"
  origin_file_contains "$r1" '^\*\*Answer' || cf "(b) the answer did not land with the entry that cites it"
  git -C "$SB_WORK" checkout -- requirements/DECISIONS.md "$r1" >/dev/null 2>&1
  git -C "$SB_WORK" merge --ff-only "origin/$SB_TRUNK" >/dev/null 2>&1 || cf "(b) control: the checkout could not take the landing"

  # (c) a citation of a question that carries no answer: nothing to land first.
  _cite D-03 "$r2"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "record D-03" requirements/DECISIONS.md 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(c) a citation of an unanswered question was refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  git -C "$SB_WORK" checkout -- requirements/DECISIONS.md >/dev/null 2>&1
  git -C "$SB_WORK" merge --ff-only "origin/$SB_TRUNK" >/dev/null 2>&1 || cf "(c) control: the checkout could not take the landing"

  # (d) a citation of a question whose answer is on the trunk already.
  _cite D-04 "$r3"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "record D-04" requirements/DECISIONS.md 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(d) a citation of an answer already on the trunk was refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  git -C "$SB_WORK" checkout -- requirements/DECISIONS.md >/dev/null 2>&1
  git -C "$SB_WORK" merge --ff-only "origin/$SB_TRUNK" >/dev/null 2>&1 || cf "(d) control: the checkout could not take the landing"

  # (e) ABLATION — strip the guard; (a)'s call lands, which is the defect.
  local o4 q4 r4 s="$SB_WORK/scripts/register-commit.sh"
  o4="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec4" ./scripts/ask.sh --role Dev "Question four?" --default "D." 2>&1 )" || _fixture_die "fourth ask.sh refused: $o4"
  q4="$(printf '%s\n' "$o4" | sed -n 's/^ask.sh: question written to //p')"; r4="dev/questions/${q4#*/dev/questions/}"
  publish_sandbox
  printf '\n**Answer (2026-10-25, Ros):** Four.\n' >> "$q4"
  _cite D-05 "$r4"
  grep -q '# BEGIN unlanded-answer guard' "$s" || cf "(control) no BEGIN seam for the unlanded-answer guard in register-commit.sh — cannot ablate"
  sed -i.bak '/# BEGIN unlanded-answer guard/,/# END unlanded-answer guard/d' "$s"; rm -f "$s.bak"
  bash -n "$s" || cf "(control) the ablated register-commit.sh no longer parses"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "record D-05" requirements/DECISIONS.md 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(e) control: with the guard stripped the call was still refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_file_contains "requirements/DECISIONS.md" '^### D-05' || cf "(e) control: with the guard stripped D-05 did not land, so row (a) proves nothing"

  finish "register-commit.sh refuses a register line that cites a question file whose answer is in the checkout and not on the trunk (naming the file to add), lands it when the file rides in the same call, and does not refuse a citation of an unanswered question or of an answer already landed"
  teardown
}

# =============================================================================
# CASE — THE UNLANDED-ANSWER GUARD RUNS FOR A CHANNEL SPELLED WITHOUT ITS TRAILING SLASH, AND SAYS WHY WHEN IT DOES NOT RUN.
#
# ask.sh and check-board [t] read a channel token naming an existing directory as a directory with or
# without the `/`. Rows: (a) `dev/questions` (no slash) + an answered, uncommitted question + a register
# line citing it -> refused register-cites-unlanded-answer; (b) control: `dev/questions/` refuses too;
# (c) blank channel, (d) absolute channel, (e) a file channel, (f) an unreadable REGISTERS declaration:
# each lands and prints one `did not run` note naming its reason.
# =============================================================================
case_register_commit_guard_reads_a_channel_without_its_slash_and_names_each_skip() {
  cf_reset
  make_sandbox
  local ch="dev/questions" q="dev/questions/2026-10-27T000000Z-dev-ask.md" out rc n=0
  mkdir -p "$SB_WORK/requirements" "$SB_WORK/dev/questions"
  printf '# DECISIONS.md\n\n## A. test bucket\n\n---\n' > "$SB_WORK/requirements/DECISIONS.md"
  _ask_pm_section 'Nadia, shop manager' "$ch" > "$SB_WORK/PROJECT.md"
  : > "$SB_WORK/dev/questions/.gitkeep"
  publish_sandbox
  _cite() {  # <D-id> — also writes the answered question, which no publish_sandbox may carry to the trunk
    printf '# Q\n\n**Asked:** x\n\n**Answer (2026-10-27, Ros):** Yes.\n' > "$SB_WORK/$q"
    printf '\n### %s — a ruling\n\n**Ruling.** As answered.\n**Why.** The principal said so.\n**Provenance.** 2026-10-27, the answer in %s; no work item.\n\n---\n' "$1" "$q" >> "$SB_WORK/requirements/DECISIONS.md"
  }
  _reset() { git -C "$SB_WORK" checkout -- requirements/DECISIONS.md PROJECT.md scripts/check-board.sh >/dev/null 2>&1; git -C "$SB_WORK" merge --ff-only "origin/$SB_TRUNK" >/dev/null 2>&1 || cf "control: the checkout could not take the landing"; }
  _try() {  # <D-id> -> out, rc
    rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "record $1" requirements/DECISIONS.md 2>&1 )" || rc=$?
  }

  # (a) no trailing slash, existing directory: refused.
  n=$((n+1)); _cite D-01; _try D-01
  [ "$rc" -eq 1 ] || cf "(a) a channel without its slash did not refuse (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -F "**Answer is in your checkout and not on the trunk" >/dev/null || cf "(a) the refusal is not the unlanded-answer one: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_file_contains "requirements/DECISIONS.md" '^### D-01' && cf "(a) D-01 reached the trunk although the guard should have refused"
  git -C "$SB_WORK" checkout -- requirements/DECISIONS.md >/dev/null 2>&1; rm -f "$SB_WORK/$q"

  # (b) control: the slash spelling refuses.
  _ask_pm_section 'Nadia, shop manager' "$ch/" > "$SB_WORK/PROJECT.md"; publish_sandbox
  _cite D-02; _try D-02
  [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -F "**Answer is in your checkout and not on the trunk" >/dev/null || cf "(b) control: the slash spelling was not refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  git -C "$SB_WORK" checkout -- requirements/DECISIONS.md >/dev/null 2>&1; rm -f "$SB_WORK/$q"

  # (c)-(e) a channel the guard cannot use: lands, and the note names why.
  local spec tok want
  for spec in "c|<who answers>|declares no channel" "d|/etc/questions/|not a path inside the repository" "e|dev/questions.md|is one file"; do
    tok="${spec#*|}"; want="${tok#*|}"; tok="${tok%%|*}"
    if [ "${spec%%|*}" = c ]; then printf '<!-- KIT-CLASS: KIT -->\n# PROJECT.md\n\n## Who answers when nobody is watching\n\n- **`principal:`** `Nadia`\n- **Their channel:** <the directory>\n' > "$SB_WORK/PROJECT.md"
    else _ask_pm_section 'Nadia, shop manager' "$tok" > "$SB_WORK/PROJECT.md"; fi
    publish_sandbox; _cite "D-${spec%%|*}"; _try "D-${spec%%|*}"
    [ "$rc" -eq 0 ] || cf "(${spec%%|*}) the call was refused (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
    printf '%s\n' "$out" | grep -F 'the unlanded-answer guard did not run' | grep -F "$want" >/dev/null \
      || cf "(${spec%%|*}) no 'did not run' note naming '$want': $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
    rm -f "$SB_WORK/$q"; _reset
  done

  # (f) the trunk's REGISTERS declaration unreadable.
  _ask_pm_section 'Nadia, shop manager' "$ch/" > "$SB_WORK/PROJECT.md"
  sed -i.bak 's/^REGISTERS=/XREGISTERS=/' "$SB_WORK/scripts/check-board.sh"; rm -f "$SB_WORK/scripts/check-board.sh.bak"
  publish_sandbox; _cite D-f; _try D-f
  printf '%s\n' "$out" | grep -F 'the unlanded-answer guard did not run: no REGISTERS declaration' >/dev/null \
    || cf "(f) no 'did not run' note for an unreadable REGISTERS declaration (rc=$rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"

  # (g) the three readers of the channel agree: ask.sh writes INTO a no-slash directory channel and [t]
  # reads it as a directory; for a file channel ask.sh appends to the file and [t] skips naming a file.
  _reset
  rm -f "$SB_WORK/$q"; git -C "$SB_WORK" checkout -- . >/dev/null 2>&1
  sed -i.bak 's/^XREGISTERS=/REGISTERS=/' "$SB_WORK/scripts/check-board.sh"; rm -f "$SB_WORK/scripts/check-board.sh.bak"
  local ga gt gf
  _ask_pm_section 'Nadia, shop manager' "$ch" > "$SB_WORK/PROJECT.md"; publish_sandbox
  ga="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/recg" ./scripts/ask.sh --role Dev "Question g?" --default "G." 2>&1 )" || cf "(g) ask.sh refused a no-slash directory channel: $ga"
  printf '%s\n' "$ga" | grep -E "question written to .*/$ch/[^/]+-ask\.md" >/dev/null || cf "(g) ask.sh did not write inside the no-slash directory channel: $ga"
  gt="$(cb_run | _cb_t_section)"
  [ -n "$gt" ] && ! printf '%s\n' "$gt" | grep '(skipped)' >/dev/null || cf "(g) [t] skipped a no-slash directory channel: $gt"
  _ask_pm_section 'Nadia, shop manager' "dev/questions.md" > "$SB_WORK/PROJECT.md"; publish_sandbox
  gf="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/recf" ./scripts/ask.sh --role Dev "Question f?" --default "F." 2>&1 )" || cf "(g) ask.sh refused a file channel: $gf"
  [ -f "$SB_WORK/dev/questions.md" ] || cf "(g) ask.sh wrote no file for a file channel: $gf"
  gt="$(cb_run | _cb_t_section)"
  printf '%s\n' "$gt" | grep '(skipped)' | grep 'one file' >/dev/null || cf "(g) [t] did not skip a file channel as one file: $gt"

  finish "register-commit.sh's unlanded-answer guard refuses a register line citing an uncommitted answer whether the channel is spelled with or without its trailing slash, and each path where it does not run prints a note naming why"
  teardown
}

# =============================================================================
# CASE — A PRODUCER THAT SOURCES ONLY progress-record.sh IS CHECKED AGAINST THE DECLARED ROLE SET.
#
# The writer's membership check reads the declared set through role-set.sh. A script that sources
# the writer alone must still get a role outside the set tagged unknown rather than accepted.
# =============================================================================
case_progress_record_alone_checks_the_declared_role_set() {
  cf_reset
  make_sandbox
  local pr="$SB_WORK/scripts/lib/progress-record.sh" out
  [ -f "$pr" ] || _fixture_die "case_progress_record_alone_checks_the_declared_role_set: the sandbox carries no scripts/lib/progress-record.sh."
  out="$( cd "$SB_WORK" && bash -c ". '$pr'; if _pr_actor_ok Zebra; then echo zebra=ok; else echo zebra=bad; fi; if _pr_actor_ok Dev:XYZ-001; then echo dev=ok; else echo dev=bad; fi" 2>&1 )"
  printf '%s\n' "$out" | grep -x 'dev=ok' >/dev/null \
    || cf "(control) a declared role with an issue id was rejected: $(printf '%s' "$out" | tr '\n' '|')"
  printf '%s\n' "$out" | grep -x 'zebra=bad' >/dev/null \
    || cf "a role outside the declared set was accepted by a producer that sources only progress-record.sh: $(printf '%s' "$out" | tr '\n' '|')"
  finish "progress-record.sh sourced alone rejects an actor whose role is not in the declared set and accepts one that is"
  teardown
}

# =============================================================================
# CASE — the mover's not-found refusal costs nothing, and cannot lie
#
# FOUR ARMS, and (b)–(d) are why this is a case and not a one-line assertion:
#   (a) a mistyped id refuses and leaves NO registered kanban worktree — the
#       property the pre-bootstrap probe exists for;
#   (b) ABLATION: (a) must be able to FAIL. The probe is disabled in the
#       sandbox's own copy and (a)'s worktree check is re-run — a green (a) over
#       a script whose probe never ran would be a green about nothing;
#   (c) FALSE-REFUSAL CONTROL: a card that IS on the trunk but absent from this
#       repo's CACHED origin/<trunk> must still MOVE. The probe reads a tracking
#       ref, so without its fetch-confirmation it refuses a card that exists —
#       worse than the worktree it saves. This arm reddens if anyone hoists the
#       fetch out of the condition chain;
#   (d) a probe that CANNOT ANSWER falls through instead of refusing, and the
#       refusal's own provenance line is what proves which read caught it.
# =============================================================================
case_move_issue_probe() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-100" sandbox chore "Sandbox probe test"
  publish_sandbox

  local out rc mi="$SB_WORK/scripts/move-issue.sh"
  kwt_registered() { git -C "$SB_WORK" worktree list --porcelain 2>/dev/null | grep -F '.kanban-wt' >/dev/null; }
  kwt_clear() {
    git -C "$SB_WORK" worktree remove --force "$SB_WORK/.kanban-wt" >/dev/null 2>&1
    rm -rf "$SB_WORK/.kanban-wt"
    git -C "$SB_WORK" worktree prune >/dev/null 2>&1
  }

  # (a) THE PROPERTY.
  kwt_clear
  out="$( cd "$SB_WORK" && "$mi" "$SB_PREFIX-999" in_progress --role Dev --note x 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) the mover accepted a card that is on no board"
  printf '%s\n' "$out" | grep 'no file matching' >/dev/null \
    || cf "(a) the not-found refusal changed shape: $out"
  printf '%s\n' "$out" | grep -i 'not yet pushed' >/dev/null \
    || cf "(a) the refusal lost the push-before-you-move cause: $out"
  kwt_registered \
    && cf "(a) a REFUSAL registered a kanban worktree — the probe is gone, or it now runs too late"
  [ -e "$SB_WORK/.kanban-wt" ] && cf "(a) a REFUSAL left a .kanban-wt/ directory behind"

  # (b) ABLATION — neuter the probe's condition in the sandbox's copy and re-run (a)'s
  #     worktree check, which must now FIRE. Self-asserting: an anchor that moved is a
  #     fixture failure, not a case failure.
  kwt_clear
  # Restore from a copy of the NEUTRALIZED sandbox script, never from $REAL_SCRIPTS: that
  # re-imports the adopter's tree (a `kit-init --roles` whitelist) past _kit_neutral_config.
  cp "$mi" "$SB_TMP/move-issue.neutral"
  grep -q '^if probe_board "\$PROBE_REF" && ' "$mi" \
    || _fixture_die "case_move_issue_probe(b): no probe condition to ablate in move-issue.sh — the anchor moved, so arm (a) above is unfalsifiable and this case proves nothing."
  perl -i -pe 's/^if probe_board "\$PROBE_REF" && /if false && probe_board "\$PROBE_REF" && /' "$mi"
  grep -q '^if false && probe_board "\$PROBE_REF" && ' "$mi" \
    || _fixture_die "case_move_issue_probe(b): the ablation did not take."
  # The mover runs only as the trunk's committed copy, so the ablated script is published.
  _mi_publish() { git -C "$SB_WORK" add scripts/move-issue.sh >/dev/null 2>&1 && sbcommit -q -m "[PM] mover copy" >/dev/null 2>&1 && git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1; }
  _mi_publish || _fixture_die "case_move_issue_probe(b): could not publish the ablated mover."
  out="$( cd "$SB_WORK" && "$mi" "$SB_PREFIX-999" in_progress --role Dev --note x 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) the ablated mover accepted a nonexistent card"
  kwt_registered \
    || cf "(control) with the probe disabled the refusal STILL left no worktree — arm (a) is not measuring the probe: $out"
  cp "$SB_TMP/move-issue.neutral" "$mi"   # restore the NEUTRALIZED script for (c) and (d)
  _mi_publish || _fixture_die "case_move_issue_probe(b): could not publish the restored mover."
  grep -q '^if probe_board "\$PROBE_REF" && ' "$mi" \
    || _fixture_die "case_move_issue_probe: the restore did not put the un-ablated script back, so arms (c) and (d) would run against the disabled probe."

  # (c) FALSE-REFUSAL CONTROL. Put a card on the trunk WITHOUT it passing through this
  #     repo's tracking ref: commit and push it from a second clone. Both halves of the
  #     premise are asserted, because a control whose premise silently did not hold is
  #     the green that proves nothing.
  kwt_clear
  local other="$SB_TMP/other"
  git clone --quiet "$SB_ORIGIN" "$other" >/dev/null 2>&1
  git -C "$other" config user.email "test@sandbox.invalid" >/dev/null 2>&1
  git -C "$other" config user.name  "Sandbox Other"        >/dev/null 2>&1
  git -C "$other" config commit.gpgsign false              >/dev/null 2>&1
  sed "s/^id: $SB_PREFIX-100$/id: $SB_PREFIX-101/" \
    "$SB_WORK/progress/todo/$SB_PREFIX-100-sandbox.md" \
    > "$other/progress/todo/$SB_PREFIX-101-elsewhere.md"
  git -C "$other" add -A >/dev/null 2>&1
  MSG_OK=1 git -C "$other" commit -qm "[PM] $SB_PREFIX-101: minted in another clone" >/dev/null 2>&1
  git -C "$other" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  ORIGIN_PATHS="$(git -C "$SB_ORIGIN" ls-tree -r --name-only "$SB_TRUNK" 2>/dev/null)"
  printf '%s\n' "$ORIGIN_PATHS" | grep "$SB_PREFIX-101-elsewhere.md" >/dev/null \
    || _fixture_die "case_move_issue_probe(c): the second clone's push did not reach the bare trunk — the control has no premise."
  CACHED_PATHS="$(git -C "$SB_WORK" ls-tree -r --name-only "origin/$SB_TRUNK" 2>/dev/null)"
  printf '%s\n' "$CACHED_PATHS" | grep "$SB_PREFIX-101-elsewhere.md" >/dev/null \
    && _fixture_die "case_move_issue_probe(c): origin/$SB_TRUNK is already current here, so nothing in this arm exercises the stale-cache path."
  out="$( cd "$SB_WORK" && "$mi" "$SB_PREFIX-101" in_progress \
            --role Dev --note "moved from a stale cache" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] \
    || cf "(c) FALSE REFUSAL: a card that IS on the trunk was refused because our cached origin/$SB_TRUNK had not seen it (rc=$rc): $out"
  origin_has_path "progress/in_progress/$SB_PREFIX-101-elsewhere.md" \
    || cf "(c) the move did not land on the trunk"

  # (d) A CONFIRMING FETCH THAT CANNOT ANSWER FALLS THROUGH — and the provenance line is the
  #     only thing that can tell the two reads apart, which is why it is asserted.
  kwt_clear
  # The tracking ref stays (the mover compares its own files with it before anything else and refuses
  # without one); the remote is made unreachable, so the confirming fetch cannot answer.
  git -C "$SB_WORK" remote set-url origin "$SB_TMP/no-such-remote.git" >/dev/null 2>&1
  out="$( cd "$SB_WORK" && "$mi" "$SB_PREFIX-998" in_progress --role Dev --note x 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(d) the mover accepted a nonexistent card with an unreachable remote"
  printf '%s\n' "$out" | grep 'no file matching' >/dev/null \
    || cf "(d) the fall-through refusal changed shape: $out"
  printf '%s\n' "$out" | grep 'inside the kanban worktree' >/dev/null \
    || cf "(d) with a fetch that cannot answer the probe did not fall through to the worktree read: $out"

  finish "move-issue.sh: a not-found refusal creates no worktree (ablation-proven), never refuses a card the trunk actually carries, and falls through when it cannot read the ref"
  teardown
}

# =============================================================================
# CASE — THE CONFIG SEAM REFUSES RATHER THAN FALLING BACK.
#
# Every script holding its own copy of one project's prefix is the silently-wrong-prefix bug:
# a sweep under the wrong prefix finds nothing and reports "nothing to sweep" on a full column.
# So with config.sh unsourceable, every consumer must REFUSE and NAME config.sh. All are
# asserted, because fixing one in isolation leaves the rest inconsistent.
# =============================================================================
case_config_seam_refusal() {
  cf_reset
  if ! has_issue_template; then skp "the config seam REFUSES with a named cause across every prefix consumer" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-203" delta chore "Archive delta"
  publish_sandbox
  # Make config.sh unsourceable — the degraded path under test.
  mv "$SB_WORK/scripts/config.sh" "$SB_WORK/scripts/config.sh.disabled" >/dev/null 2>&1

  # THE CENSUS runs against the SANDBOX's scripts/, which has no scripts/test/: the harness
  # quotes the census phrase (below), so a tree-wide grep counts one more than there are
  # consumers.
  #
  # THE POPULATION IS DERIVED from the census, never typed, so the loop and the grep are one
  # set. It is keyed on the guarded-source CODE, not a section-header comment: a header phrase
  # also appears where a script explains why it does NOT carry the block, and a non-comment
  # filter over a header phrase returns nothing. The code shape IS the declaration here:
  # guarding the source and refusing with a named cause discharges
  # `process/contracts/config-seam.md`.
  local s out rc n_consumers=0
  # hout/hrc carry the USAGE and UNKNOWN-OPTION probes below, kept separate from out/rc so the
  # refusal assertions and the argument-clause assertions cannot read each other's result.
  local hout hrc
  # `grep -lF`, and the -F is load-bearing: as a regex, `$` mid-pattern is an end-of-line
  # anchor, so `"$CONFIG"` never matches and the census empties. `lib/usage.sh`'s header
  # records the same trap.
  local consumers; consumers="$(cd "$SB_WORK/scripts" && grep -lF 'if [ ! -f "$CONFIG" ] || ! . "$CONFIG"; then' ./*.sh 2>/dev/null | sed 's@^\./@@' | sort)"
  # THE SEAM'S OWN VALUE, for the no-guessing arm, obtained as a consumer would: source the
  # DISABLED seam in a subshell with the env override unset (`env -u`, so the harness's own
  # environment cannot supply it). A pattern read of `ISSUE_PREFIX="${ISSUE_PREFIX:-KIT}"`
  # returns the expansion, not the value. An empty result SKIPS the arm, saying so.
  local seam_prefix
  seam_prefix="$( env -u ISSUE_PREFIX bash -c '. "$1" >/dev/null 2>&1 && printf "%s" "${ISSUE_PREFIX:-}"' _ "$SB_WORK/scripts/config.sh.disabled" || true )"
  [ -n "$seam_prefix" ] \
    || cf "(control) could not read ISSUE_PREFIX out of the sandbox's disabled config.sh — the no-guessing arm below is skipped, so its green is unproven"
  [ -n "$consumers" ] \
    || _fixture_die "case_config_seam_refusal: no script in the sandbox carries the guarded-source block — the census pattern moved, so this loop would assert nothing while reporting a pass."
  for s in $consumers; do
    n_consumers=$(( n_consumers + 1 ))
    case "$s" in
      archive.sh)      out="$( cd "$SB_WORK" && env -u ISSUE_PREFIX "$SB_WORK/scripts/$s" --apply 2>&1 )"; rc=$? ;;
      next-id.sh)      out="$( cd "$SB_WORK" && env -u ISSUE_PREFIX "$SB_WORK/scripts/$s" 2>&1 )"; rc=$? ;;
      # new-prd.sh takes <slug> and no --id, and its seam is PRD_PREFIX rather than
      # ISSUE_PREFIX — the one consumer whose output lands in requirements/.
      new-prd.sh)      out="$( cd "$SB_WORK" && env -u PRD_PREFIX "$SB_WORK/scripts/$s" someslug 2>&1 )"; rc=$? ;;
      # subtask.sh reads NO prefix; its BARE invocation reaches the seam because it sources the
      # seam before dispatching a subcommand. No `env -u`: unsetting a prefix would imply it
      # read one.
      subtask.sh)      out="$( cd "$SB_WORK" && "$SB_WORK/scripts/$s" 2>&1 )"; rc=$? ;;
      # The three creators that share one shape. NAMED rather than left to a catch-all, for the
      # reason the `*)` arm below now states.
      new-bug.sh|new-issue.sh|new-refactor.sh)
                       out="$( cd "$SB_WORK" && env -u ISSUE_PREFIX "$SB_WORK/scripts/$s" someslug --id "$SB_PREFIX-900" 2>&1 )"; rc=$? ;;
      # THE INVOCATION TABLE IS DECLARED, NOT DEFAULTED: a catch-all would run a new member
      # with arguments nobody chose, it would exit non-zero for the WRONG reason, and every
      # "it refused" assertion would pass. So a new member halts this case until its arm is
      # written.
      *)               _fixture_die "case_config_seam_refusal: no invocation is declared for scripts/$s, which the guarded-source census returned. This case cannot test a member it does not know how to run: a default invocation refuses for the WRONG REASON (bad arguments, not an unreadable seam) and every assertion below would pass on it. Add an arm to the case above naming how scripts/$s is invoked." ;;
    esac
    [ "$rc" -ne 0 ] || cf "$s: exited 0 with config.sh unsourceable — it fell back instead of refusing"
    printf '%s' "$out" | grep 'config\.sh' >/dev/null \
      || cf "$s: the refusal does not NAME scripts/config.sh: $out"
    # AUTHORSHIP, NOT PRESENCE: an unguarded source dies with the interpreter's "…/config.sh:
    # No such file or directory", which names the file too. Only the kit's own block cites the
    # contract.
    printf '%s' "$out" | grep 'config-seam\.md' >/dev/null \
      || cf "$s: the refusal names config.sh but does not cite process/contracts/config-seam.md — so this may be the interpreter's sourcing diagnostic rather than the kit's guarded refusal, which is the state that let a script with NO guard pass this arm: $out"

    # ── § 3's TWO ARGUMENT CLAUSES MUST STILL HOLD ON THIS SEAMLESS TREE: a usage request
    #    ALWAYS succeeds (issue-creation.md § 3), and here is where an operator most needs it.
    #    File-scope sourcing above the argument parse breaks it. No invocation table is
    #    needed: `--help` is the one invocation § 3 declares legal for every bound tool.
    hout="$( cd "$SB_WORK" && "$SB_WORK/scripts/$s" --help </dev/null 2>&1 )"; hrc=$?
    [ "$hrc" -eq 0 ] \
      || cf "$s: --help exited $hrc with config.sh absent — issue-creation.md § 3 says a usage request ALWAYS succeeds, and this is the tree where the operator needs it most: $(printf '%s' "$hout" | tr '\n' '|' | cut -c1-240)"
    # NAMING ITSELF, because rc=0 alone is satisfied by a tool that printed NOTHING — the same
    # hole the CLI-shape case names, and the same remedy.
    printf '%s' "$hout" | grep -F -- "$s" >/dev/null \
      || cf "$s: --help printed nothing naming $s, with config.sh absent — and rc alone is satisfied by a tool that printed nothing at all, so this arm is stated separately from the one above rather than folded into it: $(printf '%s' "$hout" | tr '\n' '|' | cut -c1-240)"
    # AND IT DID NOT GUESS THE VALUE IT COULD NOT READ: usage text rendering a derived value
    # degrades to NAMING the seam, never to the shipped default (§ 3). The operand is the
    # seam's own value, sourced above. In this sandbox it IS the shipped placeholder, so the
    # arm cannot tell a guessed default from another read; with the seam absent neither is
    # legitimate.
    if [ -n "${seam_prefix:-}" ]; then
      printf '%s' "$hout" | grep -F -- "${seam_prefix}-NNN" >/dev/null \
        && cf "$s: --help with config.sh absent printed '${seam_prefix}-NNN' — it fell back to a prefix literal instead of naming the seam, and a prefix that is right about the kit and wrong about the project is unfalsifiable from the operator's seat (issue-creation.md § 3): $(printf '%s' "$hout" | tr '\n' '|' | cut -c1-240)"
    fi
    # THE UNKNOWN-OPTION CLAUSE, only where the grammar allows it above the seam: the creators
    # take a <slug> first, so a dash-leading token there is illegal whatever the option list
    # says. archive.sh (`--apply`) and subtask.sh (`new`) may legally lead with an option or a
    # subcommand, so an arm above their seam would need a second copy of their option list.
    # They keep rc 1, and the finish line says so.
    case "$s" in
      new-bug.sh|new-issue.sh|new-refactor.sh|new-prd.sh)
        hout="$( cd "$SB_WORK" && "$SB_WORK/scripts/$s" --bogus </dev/null 2>&1 )"; hrc=$?
        [ "$hrc" -eq 2 ] \
          || cf "$s: --bogus exited $hrc with config.sh absent, where issue-creation.md § 3 fixes the status for an unrecognised option at 2 — a caller scripting against the set cannot branch on a status that means 'unknown option' in one tree and 'seam missing' in another: $(printf '%s' "$hout" | tr '\n' '|' | cut -c1-240)"
        printf '%s' "$hout" | grep -F -- '--bogus' >/dev/null \
          || cf "$s: the unrecognised-option refusal does not NAME --bogus, which § 3 requires of it: $(printf '%s' "$hout" | tr '\n' '|' | cut -c1-240)" ;;
    esac
  done

  # ── INSTRUMENT CHECK FOR THE ARMS ABOVE: each must be shown able to FAIL, against a probe
  #    written OUTSIDE scripts/ so the census cannot pick it up.
  local hprobe="$SB_TMP/help-refuses.sh"
  printf '#!/usr/bin/env bash\necho "%s-NNN" >&2\nexit 1\n' "${seam_prefix:-KIT}" > "$hprobe"
  chmod +x "$hprobe"
  hout="$( "$hprobe" --help </dev/null 2>&1 )"; hrc=$?
  [ "$hrc" -ne 0 ] \
    || cf "(control) the usage probe read rc=0 from a script that exits 1 — the rc arm above is measuring nothing"
  [ "$hrc" -ne 2 ] \
    || cf "(control) the probe that exits 1 was read as rc=2 — the unknown-option arm above cannot tell the two statuses apart"
  printf '%s' "$hout" | grep -F -- "$(basename "$hprobe")" >/dev/null \
    && cf "(control) the naming arm matched a probe whose output never names it — it is measuring nothing"
  if [ -n "${seam_prefix:-}" ]; then
    printf '%s' "$hout" | grep -F -- "${seam_prefix}-NNN" >/dev/null \
      || cf "(control) the fallback-literal arm did not see '${seam_prefix}-NNN' in output that carries it — it could not redden on a script that guessed"
  fi

  # THE SECOND ARM, which only one consumer has: config.sh present and SOURCEABLE but
  # the seam empty must ALSO refuse and name it. Restore the seam file, blank the value.
  mv "$SB_WORK/scripts/config.sh.disabled" "$SB_WORK/scripts/config.sh" >/dev/null 2>&1
  if [ -f "$SB_WORK/scripts/new-prd.sh" ]; then
    # The rc check cannot fail here: with no PRD template in the sandbox new-prd.sh exits
    # non-zero anyway. The naming check (PRD_PREFIX) carries this arm.
    # Blank the seam IN THE FILE, not the environment: `PRD_PREFIX="${PRD_PREFIX:-PRD}"`
    # replaces an empty env var with the default, so the guard would never fire.
    perl -i -pe 's{^PRD_PREFIX=.*$}{PRD_PREFIX=""}' "$SB_WORK/scripts/config.sh"
    grep -qxF 'PRD_PREFIX=""' "$SB_WORK/scripts/config.sh" \
      || _fixture_die "case_config_seam_refusal: could not blank PRD_PREFIX in the sandbox's config.sh — the empty-seam arm would test a populated seam."
    out="$( cd "$SB_WORK" && "$SB_WORK/scripts/new-prd.sh" someslug 2>&1 )"; rc=$?
    [ "$rc" -ne 0 ] \
      || cf "new-prd.sh: exited 0 with a sourceable config.sh and an EMPTY PRD_PREFIX — the second arm does not refuse"
    printf '%s' "$out" | grep 'PRD_PREFIX' >/dev/null \
      || cf "new-prd.sh: the empty-seam refusal does not NAME PRD_PREFIX: $out"
  fi
  mv "$SB_WORK/scripts/config.sh" "$SB_WORK/scripts/config.sh.disabled" >/dev/null 2>&1

  # And nothing happened: the sweep did not run, and no card was minted.
  origin_has_path "progress/qa_complete/$SB_PREFIX-203-delta.md" \
    || cf "the refused sweep moved the file anyway"
  [ -z "$(find "$SB_WORK/progress" -name "$SB_PREFIX-900-*.md" 2>/dev/null)" ] \
    || cf "a refused creation script minted a file anyway"
  # new-prd.sh mints into requirements/, which the checks above do not cover. The sandbox has
  # no requirements/, so this is vacuous on a clean run and bites once anything creates it.
  [ -z "$(find "$SB_WORK/requirements" -name '*someslug*' 2>/dev/null)" ] \
    || cf "a refused new-prd.sh minted into requirements/ anyway"

  finish "the config seam REFUSES with a named cause across every prefix consumer the block's own census returns ($n_consumers asserted: $(printf '%s' "$consumers" | tr '\n' ' ')), EVERY ONE OF THEM STILL ANSWERS \`--help\` on that same seamless tree — rc=0, naming itself, and WITHOUT falling back to a prefix literal (operand: the seam's own '${seam_prefix:-<unreadable, arm skipped>}', obtained by sourcing the disabled file) — the four <slug>-leading creators also still refuse an unrecognised option with § 3's status 2 and name it, with every arm shown able to redden against a probe outside scripts/; the empty-seam arm refuses too, and nothing is minted in progress/ or requirements/. TWO HOLES rather than exemptions, both stated: \`--help\` in a LATER argument position, which every member still answers below its seam block and therefore still refuses on this tree; and the unrecognised-option status for archive.sh and subtask.sh, which still exit 1 here because an arm above THEIR seam would need a second copy of their option list"
  teardown
}

# =============================================================================
# CASE — next-id.sh
# =============================================================================
case_next_id() {
  cf_reset
  local out rc err
  # (1) max+1 across progress/** filenames.
  make_sandbox
  seed_issue todo "$SB_PREFIX-001" one   chore "one"
  seed_issue todo "$SB_PREFIX-003" three chore "three"
  publish_sandbox
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/next-id.sh" 2>/dev/null )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(max+1) exited $rc"
  [ "$out" = "$SB_PREFIX-004" ] || cf "(max+1) expected $SB_PREFIX-004 across filenames, got '$out'"
  printf '%s' "$out" | grep -E "^$SB_PREFIX-[0-9]{3}$" >/dev/null || cf "(shape) output '$out' is not <PREFIX>-NNN shaped"
  teardown

  # (2) it counts ARCHIVE.md entries too — the number must not reset after a sweep.
  make_sandbox
  publish_sandbox
  printf -- "- %s-009 [chore] archived issue\n" "$SB_PREFIX" >> "$SB_WORK/ARCHIVE.md"
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/next-id.sh" 2>/dev/null )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(ARCHIVE) exited $rc"
  [ "$out" = "$SB_PREFIX-010" ] || cf "(ARCHIVE) expected $SB_PREFIX-010 from the ARCHIVE.md max, got '$out'"
  teardown

  # (3) genuinely undeterminable → nonzero + an explanatory stderr message. THE
  #     CONTRACT, not a gap: where no id has ever been issued, choosing where
  #     numbering starts is a DECISION.
  make_sandbox
  publish_sandbox
  err="$( cd "$SB_WORK" && "$SB_WORK/scripts/next-id.sh" 2>&1 1>/dev/null )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(empty) expected nonzero exit on an empty board, got 0"
  printf '%s' "$err" | grep -i 'no existing' >/dev/null || cf "(empty) no explanatory stderr message: '$err'"
  teardown

  # (4) only the FILENAME counts: a checkout under a directory named like an id is not an id.
  make_sandbox "$SB_PREFIX-900"
  seed_issue todo "$SB_PREFIX-001" one chore "one"
  publish_sandbox
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/next-id.sh" 2>/dev/null )"; rc=$?
  [ "$out" = "$SB_PREFIX-002" ] || cf "(path) a checkout at .../$SB_PREFIX-900 got '$out', want $SB_PREFIX-002 — the directory part was read as an id"
  teardown

  finish "next-id.sh: max+1 (filenames + ARCHIVE.md, never the directory part), <PREFIX>-NNN shape, nonzero on an empty board"
}

# =============================================================================
# CASE — next-id.sh outside a git repository says it once. The cause is named by the trunk
# reader's own refusal (not inside a git repository); a second Error for the same cause is noise.
# =============================================================================
case_next_id_outside_a_repository_reports_once() {
  cf_reset
  make_sandbox
  publish_sandbox
  local nogit="$SB_TMP/nogit" out rc n
  mkdir -p "$nogit/progress"
  cp -R "$SB_WORK/scripts" "$nogit/scripts"
  out="$( cd "$nogit" && ./scripts/next-id.sh 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "next-id.sh outside a repository exited 0: $out"
  printf '%s' "$out" | grep -F 'not inside a git repository' >/dev/null || cf "the cause is not named: $out"
  n="$(printf '%s\n' "$out" | grep -c '^Error:')"
  [ "$n" -eq 1 ] || cf "next-id.sh printed $n Error lines for one cause: $(printf '%s' "$out" | tr '\n' '|')"
  finish "next-id.sh outside a git repository exits non-zero and prints one Error line naming the cause"
  teardown
}

# =============================================================================
# CASE — a restored slice card is not a duplicate of its parent. A card is its id; a slice's id is
# its parent's id plus its suffix. The real order: the parent card is on the trunk, the slice is
# minted (subtask.sh new publishes it), a landing drops it from the trunk, and the same card is then
# restored through register-commit.sh. Controls: a second copy of the parent under another column,
# and of the slice under another column, are still refused. The reader's rows are read through the
# library that ships it.
# =============================================================================
case_a_restored_slice_card_is_not_a_duplicate_of_its_parent() {
  cf_reset
  if ! has_issue_template; then skp "kit_card_id_of_path gives a subtasks/ path its slice id and register-commit.sh restores a slice card beside its parent" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  make_sandbox
  local L="kit_card_id_of_path gives a subtasks/ path its slice id (parent id plus suffix) and every other card file its own; register-commit.sh therefore restores a slice card beside its parent, and still refuses a second copy of the parent or of the slice at another column"
  local rc_sh="$SB_WORK/scripts/register-commit.sh" st="$SB_WORK/scripts/subtask.sh" lib="$SB_WORK/scripts/lib/card-field.sh"
  if ! { [ -x "$rc_sh" ] && [ -x "$st" ] && [ -f "$lib" ]; }; then
    skp "$L" "register-commit.sh, subtask.sh or lib/card-field.sh is absent from this tree"; teardown; return
  fi
  if [ ! -f "$REAL_REPO_ROOT/.claude/templates/SUBTASK.template.md" ]; then
    skp_lived "$L" ".claude/templates/SUBTASK.template.md is absent from this tree"; teardown; return
  fi
  mkdir -p "$SB_WORK/.claude/templates"
  cp -R "$REAL_REPO_ROOT/.claude/templates/." "$SB_WORK/.claude/templates/"
  local pid="$SB_PREFIX-846" out rc row want got
  seed_issue todo "$pid" parent chore "Decomposition parent"
  publish_sandbox

  # (a) the reader: a slice path gives the slice's id, anything else the card's.
  for row in "progress/subtasks/$pid/todo/$pid-s1-restored.md|$pid-s1" \
             "progress/done/subtasks/$pid/qa_complete/$pid-s12.md|$pid-s12" \
             "progress/todo/$pid-parent.md|$pid" \
             "progress/subtasks/$pid/todo/$pid-notes.md|$pid" \
             "$pid.md|$pid" \
             "notes.md|"; do
    want="${row#*|}"
    got="$( . "$lib"; kit_card_id_of_path "${row%%|*}" )"
    [ "$got" = "$want" ] || cf "(a) kit_card_id_of_path '${row%%|*}' printed '$got', want '$want'"
  done

  # (b) mint the slice, drop it from the trunk, restore it.
  rc=0; out="$( cd "$SB_WORK" && ./scripts/subtask.sh new "$pid" s1 restored --title "Slice" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || _fixture_die "case_a_restored_slice_card_is_not_a_duplicate_of_its_parent: subtask.sh new exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  local rel="progress/subtasks/$pid/todo/$pid-s1-restored.md"
  origin_has_path "$rel" || _fixture_die "case_a_restored_slice_card_is_not_a_duplicate_of_its_parent: the slice is not on the trunk."
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  git -C "$SB_WORK" reset -q --hard "origin/$SB_TRUNK" >/dev/null 2>&1
  [ -f "$SB_WORK/$rel" ] || _fixture_die "case_a_restored_slice_card_is_not_a_duplicate_of_its_parent: the checkout has no slice file to remove."
  mv "$SB_WORK/$rel" "$SB_TMP/slice-text.md"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "$pid: drop the slice" "$rel" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || _fixture_die "case_a_restored_slice_card_is_not_a_duplicate_of_its_parent: dropping the slice exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "$rel" && _fixture_die "case_a_restored_slice_card_is_not_a_duplicate_of_its_parent: the slice is still on the trunk after the drop."
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  git -C "$SB_WORK" reset -q --hard "origin/$SB_TRUNK" >/dev/null 2>&1
  mkdir -p "$(dirname "$SB_WORK/$rel")"
  cp "$SB_TMP/slice-text.md" "$SB_WORK/$rel"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "$pid: restore the slice" "$rel" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(b) restoring the slice card was refused (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "$rel" || cf "(b) the restored slice did not reach the trunk"

  # (c) controls: the parent and the slice are still one card each.
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  git -C "$SB_WORK" reset -q --hard "origin/$SB_TRUNK" >/dev/null 2>&1
  mkdir -p "$SB_WORK/progress/in_progress"
  printf 'a second parent\n' > "$SB_WORK/progress/in_progress/$pid-parent.md"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "$pid: second parent" "progress/in_progress/$pid-parent.md" 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(c) a second copy of the PARENT at another column landed"
  printf '%s' "$out" | grep -F "progress/todo/$pid-parent.md" >/dev/null || cf "(c) the parent's refusal does not name the trunk's path: $out"
  mv "$SB_WORK/progress/in_progress/$pid-parent.md" "$SB_TMP/second-parent.md"
  mkdir -p "$SB_WORK/progress/subtasks/$pid/in_progress"
  cp "$SB_TMP/slice-text.md" "$SB_WORK/progress/subtasks/$pid/in_progress/$pid-s1-restored.md"
  rc=0; out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "$pid: second slice" "progress/subtasks/$pid/in_progress/$pid-s1-restored.md" 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(c) a second copy of the SLICE at another column landed"
  printf '%s' "$out" | grep -F "$rel" >/dev/null || cf "(c) the slice's refusal does not name the trunk's path: $out"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — next-id.sh on a branch cut before a trunk mint does not repeat that id
#
# The trunk is read from <remote>/<trunk> as last fetched, never fetched by the script:
#   (a) the fetched trunk's card and (b) its ARCHIVE.md entry both count, and the source is
#   named on stderr; (c) a branch-only card still counts.
# =============================================================================
# _branch_behind_a_trunk_mint <case> — a branch `work` cut at -001; a second clone then puts card
# -002 and an ARCHIVE.md entry -005 on the trunk, and the sandbox fetches (its checkout has neither).
_branch_behind_a_trunk_mint() {
  seed_issue todo "$SB_PREFIX-001" one chore "one"
  publish_sandbox
  git -C "$SB_WORK" checkout -q -b work
  local other="$SB_TMP/other"
  git clone -q "$SB_ORIGIN" "$other" >/dev/null 2>&1
  : > "$other/progress/todo/$SB_PREFIX-002-two.md"
  printf -- '- %s-005 [chore] retired on the trunk\n' "$SB_PREFIX" >> "$other/ARCHIVE.md"
  git -C "$other" add -A && MSG_OK=1 git -C "$other" -c user.email=o@x.invalid -c user.name=o commit -qm "[PM] mint" \
    && git -C "$other" push -q origin "$SB_TRUNK" >/dev/null 2>&1 \
    || _fixture_die "$1: the second clone could not publish its mint."
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1 || _fixture_die "$1: fetch failed."
  [ ! -e "$SB_WORK/progress/todo/$SB_PREFIX-002-two.md" ] || _fixture_die "$1: the branch already holds the trunk's mint."
}

case_next_id_reads_the_trunk() {
  cf_reset
  make_sandbox
  local out err rc
  _branch_behind_a_trunk_mint case_next_id_reads_the_trunk

  out="$( cd "$SB_WORK" && ./scripts/next-id.sh 2>"$SB_TMP/err" )"; rc=$?; err="$(cat "$SB_TMP/err")"
  [ "$rc" -eq 0 ] || cf "exited $rc: $err"
  [ "$out" = "$SB_PREFIX-006" ] || cf "(a)(b) on a branch behind the trunk: want $SB_PREFIX-006 (trunk ARCHIVE.md max 005), got '$out'"
  printf '%s' "$err" | grep "origin/$SB_TRUNK" >/dev/null || cf "(a) stderr does not name the trunk ref it read: '$err'"

  : > "$SB_WORK/progress/todo/$SB_PREFIX-009-local.md"
  out="$( cd "$SB_WORK" && ./scripts/next-id.sh 2>/dev/null )"
  [ "$out" = "$SB_PREFIX-010" ] || cf "(c) a card only on this checkout no longer counts: want $SB_PREFIX-010, got '$out'"

  finish "next-id.sh: max over this checkout AND <remote>/<trunk> (board and ARCHIVE.md), naming the ref it read"
  teardown
}

# =============================================================================
# CASE — a creator's --id check reads the trunk too
#
# On a branch behind a trunk mint: (a) the trunk's card id is refused, naming the ref; (b) the
# trunk's ARCHIVE.md entry warns; (c) a free id still creates.
# =============================================================================
case_creation_id_check_reads_the_trunk() {
  cf_reset
  if ! has_issue_template; then skp "a creator's --id check reads the trunk too" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  make_sandbox
  mkdir -p "$SB_WORK/.claude/templates"
  cp -R "$REAL_REPO_ROOT/.claude/templates/." "$SB_WORK/.claude/templates/"
  _kit_neutral_claude
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  local out rc
  _branch_behind_a_trunk_mint case_creation_id_check_reads_the_trunk

  rc=0; out="$( cd "$SB_WORK" && ./scripts/new-issue.sh taken --id "$SB_PREFIX-002" 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(a) --id $SB_PREFIX-002, on the trunk only, was accepted"
  printf '%s' "$out" | grep "origin/$SB_TRUNK" >/dev/null || cf "(a) the refusal does not name the trunk ref: $(printf '%s' "$out" | grep -m2 -i error | tr '\n' '|')"
  [ ! -e "$SB_WORK/progress/todo/$SB_PREFIX-002-taken.md" ] || cf "(a) the refused card was written"

  rc=0; out="$( cd "$SB_WORK" && ./scripts/new-issue.sh retired --id "$SB_PREFIX-005" 2>&1 )" || rc=$?
  printf '%s' "$out" | grep 'ARCHIVE.md' >/dev/null || cf "(b) --id $SB_PREFIX-005, in the trunk's ARCHIVE.md only, gave no warning"

  rc=0; out="$( cd "$SB_WORK" && ./scripts/new-issue.sh free --id "$SB_PREFIX-006" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(c) a free id was refused: $(printf '%s' "$out" | grep -m2 -i error | tr '\n' '|')"

  finish "creators' --id check: an id on <remote>/<trunk> (as last fetched) is refused naming the ref, one in its ARCHIVE.md warns, and a free id creates"
  teardown
}

# =============================================================================
# CASE — the commit-msg hook
# =============================================================================
case_commit_msg() {
  cf_reset
  make_sandbox
  local hook="$SB_WORK/scripts/githooks/commit-msg"
  local msg="$SB_TMP/msg.txt"

  # DERIVE the accepted prefixes from the hook's own ROLE_PREFIXES line — do NOT
  # re-hardcode them, or a set change makes these assertions vacuous.
  local prefixes
  # THE CANONICAL EXPRESSION, byte-identical to lib/role-set.sh's _kit_role_base.
  # FALLBACK POLICY HERE: cf (a case finding). The set is derived to keep the assertions
  # below non-vacuous, so an unreadable hook makes this case meaningless, not skippable.
  prefixes="$(sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p" "$hook" | head -1)"
  [ -n "$prefixes" ] || cf "could not derive ROLE_PREFIXES from the hook"

  local IFS='|' p rc
  for p in $prefixes; do
    printf '[%s] a valid subject\n' "$p" > "$msg"
    ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 0 ] || cf "prefix [$p] rejected (exit $rc)"
  done
  unset IFS

  # Auto-exempt subjects (git/host-generated).
  local exempt=("Merge branch 'x'" "Revert \"something\"" "fixup! earlier commit" "Merge commit '1f00d13cc8b29fe812a87eb45eb35c34a5ca0ee2'")
  local s
  for s in "${exempt[@]}"; do
    printf '%s\n' "$s" > "$msg"
    ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 0 ] || cf "auto-exempt subject rejected: '$s' (exit $rc)"
  done

  # THE BOUNDARY: "Merge commit " WITHOUT the quote is an ORDINARY human subject that merely
  # starts with the same two words as git's own `Merge commit '<sha>'` — it must NOT be
  # exempted, or a real subject with no [Role] prefix passes silently.
  printf 'Merge commit messages into one doc\n' > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] \
    || cf "ABLATION FAILED — 'Merge commit messages into one doc' was accepted as if it were git's generated merge subject; the exemption glob must require the opening quote"

  # Unprefixed subject → rejected, and the rejection LISTS the legal tags (which
  # it derives, so the help text cannot lie about the set).
  printf 'no role prefix at all\n' > "$msg"
  local out
  out="$( env -u MSG_OK "$hook" "$msg" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "unprefixed subject accepted (must be rejected)"
  printf '%s' "$out" | grep "\[${prefixes%%|*}\]" >/dev/null \
    || cf "the rejection message does not list the derived role tags: $out"

  # The applypatch path judges a subject the SAME way (git am runs that hook, not
  # commit-msg, and its mailinfo strips bracketed tags).
  printf 'no role prefix at all\n' > "$msg"
  ( env -u MSG_OK "$SB_WORK/scripts/githooks/applypatch-msg" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] || cf "applypatch-msg accepted an unprefixed subject (the am path must not be a hole)"

  # --- § A.1: no generated co-author trailer, and no "Generated with …" line ------
  # DERIVE the markers from the hook's TOOL_TRAILER_MARKERS, as the prefixes are. This asserts
  # the rule works for WHATEVER markers are declared, not that the set is right: a narrowed
  # list is invisible here by construction, and only an empty one is caught. Deleting RULE (2)
  # from the hook is what reddens it.
  local role markers marker
  role="${prefixes%%|*}"
  markers="$(sed -n "s/^TOOL_TRAILER_MARKERS='\\(.*\\)'.*/\\1/p" "$hook")"
  [ -n "$markers" ] || cf "could not derive TOOL_TRAILER_MARKERS from the hook"
  marker="${markers%%|*}"
  # The refusal prints that list VERBATIM, so it must stay plain words — a regex
  # metacharacter in it would be a lie in the help text and a live pattern in the match.
  printf '%s' "$markers" | grep -E '^[a-z0-9|]+$' >/dev/null \
    || cf "(trailer) TOOL_TRAILER_MARKERS is not the plain-word list the refusal prints: '$markers'"

  # `git commit -v` hands the hook the RAW DIFF below the scissors line; editing a file that
  # contains a trailer is not writing one, so this is ACCEPTED. (\x escapes keep this file
  # ASCII; the emoji leads because the tooling's shape does.)
  printf '[%s] a valid subject\n\n# ------------------------ >8 ------------------------\n# Do not modify or remove the line above.\ndiff --git a/doctrine b/doctrine\n--- a/doctrine\n+++ b/doctrine\n@@ -1 +1,2 @@\n Co-Authored-By: %s <noreply@example.com>\n+\xf0\x9f\xa4\x96 Generated with [Some Tool](https://example.com)\n' "$role" "$marker" > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] || cf "(trailer) a \`commit -v\` message was refused for the DIFF below its scissors line (exit $rc)"

  # A clean multi-line message is ACCEPTED — including a HUMAN co-author trailer and the
  # words in prose. A guard that rejected every message with a body would pass a
  # one-directional test.
  printf '[%s] a valid subject\n\nA body that explains why, and mentions a file generated with the codegen step.\n\nCo-authored-by: A Person <person@example.com>\n' "$role" > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] || cf "(trailer) a clean multi-line message with a HUMAN co-author was rejected (exit $rc)"

  # A tool-naming trailer is REJECTED, and the refusal names the rule and the markers.
  printf '[%s] a valid subject\n\nCo-Authored-By: %s <noreply@example.com>\n' "$role" "$marker" > "$msg"
  out="$( env -u MSG_OK "$hook" "$msg" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(trailer) a Co-Authored-By naming '$marker' was accepted"
  printf '%s' "$out" | grep 'commit-hygiene.md' >/dev/null || cf "(trailer) the refusal does not name the rule: $out"
  printf '%s' "$out" | grep -i "$marker" >/dev/null || cf "(trailer) the refusal does not list the derived markers: $out"

  # ── NO SPACE AFTER THE COLON: the pre-marker context must be an OPTIONAL group; a required
  #    `[^[:alnum:]]` has nothing to consume here and the trailer walks through.
  printf '[%s] a valid subject\n\nCo-Authored-By:%s <noreply@example.com>\n' "$role" "$marker" > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] \
    || cf "(trailer) 'Co-Authored-By:$marker' with NO SPACE after the colon was accepted — the pre-marker context in rule 2's matcher is a required character again instead of an optional group, and deleting one space defeats the guard"

  #    …and several spaces must not defeat it either, in the other direction.
  printf '[%s] a valid subject\n\nCo-Authored-By:   %s   <noreply@example.com>\n' "$role" "$marker" > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] || cf "(trailer) a padded 'Co-Authored-By:   $marker' was accepted"

  # ── THE FALSE-POSITIVE GUARD: a human whose name BEGINS with a marker's stem is not a tool
  #    trailer, and the trailing `([^[:alnum:]]|$)` keeps them out. Refusing a real
  #    contributor by name is worse than the hole.
  printf '[%s] a valid subject\n\nCo-Authored-By: %sia Ng <person@example.com>\n' "$role" "$marker" > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] \
    || cf "(trailer) a HUMAN named '${marker}ia Ng' was refused (exit $rc) — the marker match has lost its right-hand boundary and now fires on any name starting with '$marker'"

  # The second arm of § A.1, with the leading decoration the tooling actually emits.
  printf '[%s] a valid subject\n\n\xf0\x9f\xa4\x96 Generated with [Some Tool](https://example.com)\n' "$role" > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] || cf '(trailer) a "Generated with" line was accepted'

  # The auto-exempt subjects are exempt from the PREFIX rule only: a merge carries a body.
  printf "Merge branch 'x'\n\nCo-Authored-By: %s <noreply@example.com>\n" "$marker" > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] || cf "(trailer) an auto-exempt SUBJECT carried a tool trailer through — that exemption is the prefix rule's only"

  # The am path judges the trailer the same way, or the import entrance is a hole.
  printf '[%s] a valid subject\n\nCo-Authored-By: %s <noreply@example.com>\n' "$role" "$marker" > "$msg"
  ( env -u MSG_OK "$SB_WORK/scripts/githooks/applypatch-msg" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] || cf "(trailer) applypatch-msg accepted a tool trailer (the am path must not be a hole)"

  # The documented escape still works, because importing a third party's commit verbatim
  # is the case it exists for.
  printf '[%s] a valid subject\n\nCo-Authored-By: %s <noreply@example.com>\n' "$role" "$marker" > "$msg"
  ( MSG_OK=1 "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] || cf "(trailer) MSG_OK=1 did not bypass the trailer rule (the documented import escape)"

  finish "commit-msg: accepts every derived role prefix + the auto-exempt set, rejects unprefixed; rejects a tool co-author trailer and a \"Generated with\" line on both entrances while accepting a human trailer and a \`commit -v\` diff; and applypatch-msg agrees"
  teardown
}

# =============================================================================
# CASE — the commit-msg hook's ATTRIBUTION WORDING FAMILY, one fixture row per variant of the
# claim. Rule (2) must refuse every spelling, not only "co-authored-by:" and "generated with …". Each row is REFUSED or, with a reason, PASSED — never
# silently skipped.
# =============================================================================
case_commit_msg_attribution_family() {
  cf_reset
  make_sandbox
  local hook="$SB_WORK/scripts/githooks/commit-msg"
  local msg="$SB_TMP/msg2.txt"
  local prefixes role rc out
  prefixes="$(sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p" "$hook" | head -1)"
  [ -n "$prefixes" ] || cf "could not derive ROLE_PREFIXES from the hook"
  role="${prefixes%%|*}"

  # REFUSED — each wording the hook must refuse (the family in the case header).
  local -a refused=(
    "Signed-off-by: Claude <noreply@anthropic.com>"
    "Assisted-by: Claude Code"
    "Co-developed-by: Claude <noreply@anthropic.com>"
    "Generated-by: Claude Code"
    "Generated by Claude Code"
    "Written with Claude Code"
    "Generated-with: Claude Code"
    "Co-Authored-By: Opus 5.5 <noreply@models.example>"
    "Co-Authored-By: Fable 5.1 <fable@example.com>"
    "Co-Authored-By: Sonnet <sonnet@example.com>"
    "Co-authored-by : Claude <x@y>"
    "Assisted-by	: Claude Code"
  )
  local line
  for line in "${refused[@]}"; do
    printf '[%s] a valid subject\n\n%s\n' "$role" "$line" > "$msg"
    ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
    [ "$rc" -ne 0 ] || cf "attribution wording accepted (must be refused): '$line'"
  done

  # PASSED, WITH A REASON — each is a boundary this rule deliberately keeps open: a marker with
  # no word boundary after it (a name that merely begins with one), and ordinary prose.
  # Asserting them PASS keeps the widening from silently swallowing them.
  local -a passed=(
    "Co-Authored-By: ClaudeBot <x@y>"
    "Co-Authored-By: Opusina Ng <person@example.com>"
    "Written with care"
  )
  for line in "${passed[@]}"; do
    printf '[%s] a valid subject\n\n%s\n' "$role" "$line" > "$msg"
    ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 0 ] || cf "out-of-scope wording was refused (must still pass — marker vocabulary, not this card's widening): '$line'"
  done

  # The refusal on a widened-family hit still names the rule and offers the harness-config fix.
  printf '[%s] a valid subject\n\nAssisted-by: Claude Code\n' "$role" > "$msg"
  out="$( env -u MSG_OK "$hook" "$msg" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(family) 'Assisted-by: Claude Code' was accepted"
  printf '%s' "$out" | grep 'commit-hygiene.md' >/dev/null \
    || cf "(family) the refusal does not name the rule: $out"
  printf '%s' "$out" | grep -i 'configure your harness' >/dev/null \
    || cf "(family) the refusal does not offer the harness-configuration fix: $out"

  finish "commit-msg: the widened attribution family (assisted-by, co-developed-by, generated-by, signed-off-by, generated by/written with … ) is refused naming the rule and the harness-config fix, the model-family words and a blank before the colon are refused too, while a name that merely begins with a marker and generic 'written with care' prose still pass for a stated reason"
  teardown
}

# =============================================================================
# CASE — the commit-msg hook reads a generated trailer through the ONE reader (lib/attrib-trailer.sh's
# kit_attrib_offender), the reader check-board.sh arm [h] calls, so the two cannot disagree.
#   (a) a bulleted trailer and a backticked one naming a tool are refused at commit, as the
#       reader reports them;
#   (b) a bulleted trailer naming a HUMAN is accepted, as the reader reports it clean;
#   (c) a hook that cannot load the reader REFUSES (rule (2) cannot run) rather than accepting,
#       and the documented MSG_OK bypass still works.
# RED FIRST: (a) is accepted by a hook that anchors its own `^<word>:` pattern.
# =============================================================================
case_commit_msg_reads_trailers_through_the_one_reader() {
  cf_reset
  make_sandbox
  local hook="$SB_WORK/scripts/githooks/commit-msg"
  local msg="$SB_TMP/msg3.txt" role prefixes rc out line
  prefixes="$(sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p" "$hook" | head -1)"
  [ -n "$prefixes" ] || _fixture_die "case_commit_msg_reads_trailers_through_the_one_reader: no ROLE_PREFIXES in the hook"
  role="${prefixes%%|*}"
  [ -r "$SB_WORK/scripts/lib/attrib-trailer.sh" ] \
    || { skp "commit-msg reads trailers through the one reader" "scripts/lib/attrib-trailer.sh is absent from this tree"; teardown; return; }

  local -a refused=(
    "- Co-Authored-By: Claude <a@b.c>"
    '`Co-Authored-By: Claude <a@b.c>`'
    "* Assisted-by: Claude Code"
  )
  for line in "${refused[@]}"; do
    printf '[%s] a valid subject\n\n%s\n' "$role" "$line" > "$msg"
    ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
    [ "$rc" -ne 0 ] || cf "(a) the hook accepted '$line'"
    # The reader reports the same line: the two cannot disagree.
    out="$( . "$SB_WORK/scripts/lib/attrib-trailer.sh"; printf '[%s] a valid subject\n\n%s\n' "$role" "$line" | kit_attrib_offender "$SB_WORK" )"
    [ -n "$out" ] || cf "(a) the reader (check-board arm [h]) does not report '$line', which the hook refuses"
  done

  printf '[%s] a valid subject\n\n- Co-Authored-By: A Person <p@x.y>\n' "$role" > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) a bulleted trailer naming a human was refused (exit $rc)"

  # (c) the same hook, run from a copy of the tree with the reader removed.
  local bare="$SB_TMP/no-reader"
  mkdir -p "$bare/scripts"
  cp -R "$SB_WORK/scripts/githooks" "$SB_WORK/scripts/lib" "$bare/scripts/"
  rm -f "$bare/scripts/lib/attrib-trailer.sh"
  printf '[%s] a valid subject\n\nCo-Authored-By: Claude <a@b.c>\n' "$role" > "$msg"
  out="$( env -u MSG_OK "$bare/scripts/githooks/commit-msg" "$msg" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(c) a hook that cannot load the reader accepted a tool trailer"
  printf '%s' "$out" | grep -F 'Next:' >/dev/null || cf "(c) the refusal names no next action: $out"
  ( MSG_OK=1 "$bare/scripts/githooks/commit-msg" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] || cf "(c) MSG_OK=1 did not bypass the hook without the reader (exit $rc)"

  finish "commit-msg refuses a bulleted and a backticked tool trailer exactly as the shared reader reports them, accepts a bulleted human one, and refuses (never accepts) when the reader cannot be loaded, MSG_OK=1 still bypassing"
  teardown
}

# =============================================================================
# CASE — CODE_GLOBS UNDECLARED (the shipped, empty state) is a NO-OP, not "everything is
# metadata": a project that has not yet filled the seam in must see every ordinary feature-branch
# commit go through untouched. This is the fixture that would catch the fail-CLOSED shape of this
# guard, where an empty array made every ordinary code commit look like metadata and refused it.
# =============================================================================
case_pre_commit_undeclared_code_globs_is_a_noop() {
  cf_reset
  make_sandbox
  local hook="$SB_WORK/scripts/githooks/pre-commit"
  local cfg="$SB_WORK/scripts/config.sh"
  [ -x "$hook" ] \
    || { skp "pre-commit: undeclared CODE_GLOBS is a no-op" "scripts/githooks/pre-commit is absent from this tree"; teardown; return; }
  grep -qxF 'CODE_GLOBS=(' "$cfg" \
    || _fixture_die "case_pre_commit_undeclared_code_globs_is_a_noop: no 'CODE_GLOBS=(' line in config.sh."
  [ "$(_neu_array_records "$cfg" CODE_GLOBS)" -eq 0 ] \
    || _fixture_die "case_pre_commit_undeclared_code_globs_is_a_noop: CODE_GLOBS is not empty in a freshly made sandbox — the neutralizer did not run, or this case's premise (the SHIPPED state) is not what it is testing."

  publish_sandbox
  ( cd "$SB_WORK" && git checkout -q -b feature/undeclared-globs )
  echo "a ruling" > "$SB_WORK/a-metadata-file.md"
  git -C "$SB_WORK" add a-metadata-file.md
  local out rc
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[$SB_ROLE] add a-metadata-file.md" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] \
    || cf "a metadata-only commit on a feature branch was REFUSED while CODE_GLOBS is undeclared (shipped empty) — undeclared must mean unenforced, or every adopter who has not yet filled the seam in gets every feature-branch commit refused: $out"

  finish "pre-commit: CODE_GLOBS undeclared (the shipped empty state) is a no-op — an ordinary metadata-only commit on a feature branch is NOT refused until the adapter fills the seam in"
  teardown
}

# =============================================================================
# CASE — the pre-commit hook: a metadata-only commit is REFUSED off the trunk, naming
# register-commit.sh, and ALLOWED on the trunk. RED FIRST: run against a sandbox with
# scripts/githooks/pre-commit removed to see the refusal vanish.
# =============================================================================
case_pre_commit_refuses_metadata_off_trunk() {
  cf_reset
  make_sandbox
  local hook="$SB_WORK/scripts/githooks/pre-commit"
  local cfg="$SB_WORK/scripts/config.sh"
  [ -x "$hook" ] \
    || { skp "pre-commit: refuses a metadata-only commit off the trunk" "scripts/githooks/pre-commit is absent from this tree"; teardown; return; }

  # CODE_GLOBS must be DECLARED for this refusal to fire at all (case_pre_commit_undeclared_code_globs_is_a_noop
  # covers the undeclared/fail-open state) — declare something that will never match this
  # case's metadata paths, so every path below is judged metadata on purpose. _array_set_body
  # (fixtures.sh) replaces the WHOLE array body, so this takes whatever the tree's CODE_GLOBS
  # currently holds — empty, filled, or a `# DECLARED EMPTY —` comment on a tree past day one —
  # and its own postcondition reads the parsed array, not a bare '"src/*"' string the shipped
  # comment above CODE_GLOBS also carries.
  _array_set_body "$cfg" CODE_GLOBS '  "src/*"'

  publish_sandbox

  ( cd "$SB_WORK" && git checkout -q -b feature/off-trunk-metadata )
  echo "a ruling" > "$SB_WORK/a-metadata-file.md"
  git -C "$SB_WORK" add a-metadata-file.md

  local out rc
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[$SB_ROLE] add a-metadata-file.md" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "a metadata-only commit on 'feature/off-trunk-metadata' (not the trunk) was ACCEPTED"
  printf '%s' "$out" | grep -F 'register-commit.sh' >/dev/null \
    || cf "the refusal does not name register-commit.sh as the route: $out"
  printf '%s' "$out" | grep -F 'code-vs-metadata' >/dev/null \
    || cf "the refusal does not cite the code-vs-metadata rule: $out"
  printf '%s' "$out" | grep -F 'a-metadata-file.md' >/dev/null \
    || cf "the refusal does not name the staged path: $out"

  # Nothing committed — the working tree change is still staged, exactly as it was.
  git -C "$SB_WORK" diff --cached --name-only | grep -F 'a-metadata-file.md' >/dev/null \
    || cf "the refusal left the change NOT staged — it should be untouched, not partially undone"

  # The documented bypass still works (same escape as commit-msg, deliberately one name).
  out="$( cd "$SB_WORK" && MSG_OK=1 git commit -q -m "[$SB_ROLE] add a-metadata-file.md" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "MSG_OK=1 did not bypass the pre-commit guard (the documented escape): $out"

  finish "pre-commit: refuses a metadata-only commit made on a branch other than the trunk, naming register-commit.sh and the staged path, and MSG_OK=1 bypasses it"
  teardown
}

# =============================================================================
# CASE — the metadata guard judges the commit being made. The registered order is the real one: a code
# commit on a branch, THEN metadata added to it by `git commit --amend`. A fresh metadata-only commit is
# still refused and its Next: names both routes; a metadata-only amend of a metadata-only commit is
# judged as before; and a message that merely contains the text --amend does not read as an amend.
# =============================================================================
case_pre_commit_judges_an_amend_on_the_commit_being_made() {
  cf_reset
  make_sandbox
  local hook="$SB_WORK/scripts/githooks/pre-commit"
  local cfg="$SB_WORK/scripts/config.sh"
  [ -x "$hook" ] \
    || { skp "pre-commit: judges an amend on the commit being made" "scripts/githooks/pre-commit is absent from this tree"; teardown; return; }

  _array_set_body "$cfg" CODE_GLOBS '  "src/*"'
  publish_sandbox

  ( cd "$SB_WORK" && git checkout -q -b feature/code-then-readme )
  mkdir -p "$SB_WORK/src"
  echo "code" > "$SB_WORK/src/a.js"
  git -C "$SB_WORK" add src/a.js
  local out rc
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[$SB_ROLE] add src/a.js" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "setup: the code commit on the feature branch was refused: $out"

  # Row 1: the README joins the code commit it describes, by amend.
  echo "docs for a.js" > "$SB_WORK/README.md"
  git -C "$SB_WORK" add README.md
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q --amend --no-edit 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "an amend that adds a README to a code commit was refused: $out"
  git -C "$SB_WORK" show --name-only --format= HEAD | grep -Fx 'README.md' >/dev/null \
    || cf "the amend reported success but README.md is not in HEAD"

  # Row 2: a fresh metadata-only commit on the code branch is still refused, and Next: names both routes.
  echo "a ruling" > "$SB_WORK/notes.md"
  git -C "$SB_WORK" add notes.md
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[$SB_ROLE] add notes.md" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "a fresh metadata-only commit on a branch that carries code was ACCEPTED"
  printf '%s' "$out" | grep -F 'register-commit.sh' >/dev/null \
    || cf "the refusal does not name the trunk route (register-commit.sh): $out"
  printf '%s' "$out" | grep -F 'commit --amend' >/dev/null \
    || cf "the refusal does not name adding the file to the code commit it describes (git commit --amend): $out"

  # Row 4: a message containing the text --amend is not an amend: still refused.
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[$SB_ROLE] notes, not an --amend of anything" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "a fresh metadata-only commit whose -m text contains --amend was ACCEPTED"
  git -C "$SB_WORK" reset -q notes.md

  # Row 5: a card-only commit is refused and is NOT offered the amend route: a card is the trunk's.
  mkdir -p "$SB_WORK/progress/todo"
  printf -- '---\nid: %s-801\n---\n\n# card\n' "$SB_PREFIX" > "$SB_WORK/progress/todo/$SB_PREFIX-801-card-only.md"
  git -C "$SB_WORK" add "progress/todo/$SB_PREFIX-801-card-only.md"
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[$SB_ROLE] edit the card" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(row 5) a card-only commit on a work branch was ACCEPTED"
  printf '%s' "$out" | grep -F 'register-commit.sh' >/dev/null \
    || cf "(row 5) the card-only refusal does not name register-commit.sh: $out"
  printf '%s' "$out" | grep -F 'commit --amend' >/dev/null \
    && cf "(row 5) the card-only refusal still offers adding the card to a code commit (git commit --amend): $out"
  printf '%s' "$out" | grep -F "A card is the trunk's" >/dev/null \
    || cf "(row 5) the card-only refusal does not say the card is the trunk's: $out"
  printf '%s' "$out" | grep -F 'either route' >/dev/null \
    && cf "(row 5) the card-only refusal still says 'either route' though one route remains: $out"
  [ -z "$(printf '%s\n' "$out" | awk 'b && $0 ~ /^[[:space:]]*$/ { print "x" } { b = ($0 ~ /^[[:space:]]*$/) }')" ] \
    || cf "(row 5) the card-only refusal prints two blank lines in a row: $out"
  # Row 6: a card staged WITH other metadata: the card goes to the trunk, only the rest may amend.
  echo "a ruling" > "$SB_WORK/notes.md"
  git -C "$SB_WORK" add notes.md
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[$SB_ROLE] card and notes" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(row 6) a card plus notes on a work branch was ACCEPTED"
  printf '%s' "$out" | grep -F 'route the card to the trunk' >/dev/null \
    || cf "(row 6) the mixed refusal does not send the card to the trunk: $out"
  printf '%s' "$out" | grep -F 'add it to the code commit it describes' >/dev/null \
    && cf "(row 6) the mixed refusal still offers the whole staged set, card included, for the amend: $out"
  printf '%s' "$out" | grep -F 'with the card unstaged' >/dev/null \
    || cf "(row 6) the mixed refusal's amend route does not exclude the card: $out"
  git -C "$SB_WORK" reset -q notes.md
  git -C "$SB_WORK" reset -q "progress/todo/$SB_PREFIX-801-card-only.md"
  rm -f "$SB_WORK/progress/todo/$SB_PREFIX-801-card-only.md"

  # Row 3: a metadata-only amend of a metadata-only commit is judged as before (staged paths only).
  ( cd "$SB_WORK" && git checkout -q -b feature/meta-only feature/code-then-readme~1 )
  echo "m1" > "$SB_WORK/m1.md"
  git -C "$SB_WORK" add m1.md
  out="$( cd "$SB_WORK" && MSG_OK=1 git commit -q -m "[$SB_ROLE] add m1.md" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "setup: the MSG_OK metadata-only commit was refused: $out"
  echo "m2" > "$SB_WORK/m2.md"
  git -C "$SB_WORK" add m2.md
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q --amend --no-edit 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "a metadata-only amend of a metadata-only commit was ACCEPTED"

  finish "pre-commit: an amend is judged on HEAD's paths plus the staged ones; a fresh metadata-only commit is refused naming both routes; a metadata-only amend of a metadata-only commit and an -m text containing --amend are still refused"
  teardown
}

# =============================================================================
# CASE — the pre-commit hook reads CODE_GLOBS through the shared reader, and refuses when it cannot.
# lib/glob-array.sh is the one reader of that array; the hook carries no parser of its own. So with the
# library gone the declaration is unreadable, and a gate that allows on doubt reads as armed: the commit
# is refused, naming the library — and the same commit with the library present is refused for the
# REAL reason (a metadata-only commit off the trunk), which proves the two arms are different.
# =============================================================================
case_pre_commit_reads_code_globs_through_the_shared_reader() {
  cf_reset
  make_sandbox
  local hook="$SB_WORK/scripts/githooks/pre-commit" cfg="$SB_WORK/scripts/config.sh" lib="$SB_WORK/scripts/lib/glob-array.sh"
  [ -x "$hook" ] \
    || { skp "pre-commit: reads CODE_GLOBS through the shared reader" "scripts/githooks/pre-commit is absent from this tree"; teardown; return; }
  [ -f "$lib" ] || _fixture_die "case_pre_commit_reads_code_globs_through_the_shared_reader: scripts/lib/glob-array.sh is not in the sandbox"

  _array_set_body "$cfg" CODE_GLOBS '  "src/*"'
  publish_sandbox

  ( cd "$SB_WORK" && git checkout -q -b feature/reader-check )
  echo "a ruling" > "$SB_WORK/a-metadata-file.md"
  git -C "$SB_WORK" add a-metadata-file.md

  local out rc
  # (control) with the library present: refused, and for the metadata reason.
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[$SB_ROLE] add a-metadata-file.md" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(control) a metadata-only commit off the trunk was ACCEPTED with the reader present"
  printf '%s' "$out" | grep -F 'register-commit.sh' >/dev/null \
    || cf "(control) the refusal with the reader present does not name register-commit.sh: $out"

  # With the library gone: refused, naming the library — not silently allowed, and not by a private parser.
  rm -f "$lib"
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[$SB_ROLE] add a-metadata-file.md" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "with scripts/lib/glob-array.sh gone the commit was ACCEPTED — a gate that allows on doubt reads as armed"
  printf '%s' "$out" | grep -F 'glob-array.sh' >/dev/null \
    || cf "with the reader gone the refusal does not name scripts/lib/glob-array.sh: $out"
  printf '%s' "$out" | grep -F 'register-commit.sh' >/dev/null \
    && cf "with the reader gone the hook still judged the paths itself — it carries a parser of its own"
  git -C "$SB_WORK" diff --cached --name-only | grep -F 'a-metadata-file.md' >/dev/null \
    || cf "the refusal left the change NOT staged"
  out="$( cd "$SB_WORK" && MSG_OK=1 git commit -q -m "[$SB_ROLE] add a-metadata-file.md" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "MSG_OK=1 did not bypass the guard with the reader gone: $out"

  finish "pre-commit: reads CODE_GLOBS through lib/glob-array.sh and carries no parser of its own — with the library gone a metadata-only commit off the trunk is refused naming the library, and with it present the same commit is refused for the code-vs-metadata reason"
  teardown
}

# =============================================================================
# CASE — the pre-commit hook allows a metadata-only commit made ON the trunk branch itself, and
# from a DETACHED HEAD (the kanban worktree's own permanent state) — the two shapes the hook must
# never touch, or every board-script commit and every .kanban-wt op would start failing.
# =============================================================================
case_pre_commit_allows_metadata_on_trunk() {
  cf_reset
  make_sandbox
  local hook="$SB_WORK/scripts/githooks/pre-commit"
  [ -x "$hook" ] \
    || { skp "pre-commit: allows a metadata-only commit on the trunk" "scripts/githooks/pre-commit is absent from this tree"; teardown; return; }

  publish_sandbox

  # On the trunk branch itself.
  echo "a ruling" > "$SB_WORK/a-metadata-file.md"
  git -C "$SB_WORK" add a-metadata-file.md
  local out rc
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[$SB_ROLE] add a-metadata-file.md" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "a metadata-only commit ON the trunk branch was refused: $out"

  # From a DETACHED HEAD — .kanban-wt/'s own permanent state (kwt__ensure_detached).
  ( cd "$SB_WORK" && git checkout -q --detach HEAD )
  echo "another ruling" > "$SB_WORK/another-metadata-file.md"
  git -C "$SB_WORK" add another-metadata-file.md
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[$SB_ROLE] add another-metadata-file.md" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "a metadata-only commit from a DETACHED HEAD was refused (this is .kanban-wt/'s own state): $out"

  finish "pre-commit: allows a metadata-only commit made on the trunk branch itself, and from a detached HEAD (the kanban worktree's own state)"
  teardown
}

# =============================================================================
# CASE — the pre-commit hook allows a CODE commit on a branch, once the adapter's CODE_GLOBS
# names the path — the direction that must stay open, or the guard would refuse ordinary
# feature-branch work.
# =============================================================================
case_pre_commit_allows_code_on_a_branch() {
  cf_reset
  make_sandbox
  local hook="$SB_WORK/scripts/githooks/pre-commit"
  local cfg="$SB_WORK/scripts/config.sh"
  [ -x "$hook" ] \
    || { skp "pre-commit: allows a code commit on a branch" "scripts/githooks/pre-commit is absent from this tree"; teardown; return; }

  # Declare src/* as code, on the trunk, in its own commit (config.sh IS metadata itself).
  # _array_set_body replaces the whole array body, whatever it currently holds.
  _array_set_body "$cfg" CODE_GLOBS '  "src/*"'
  publish_sandbox

  ( cd "$SB_WORK" && git checkout -q -b feature/code-change )
  mkdir -p "$SB_WORK/src"
  echo "code" > "$SB_WORK/src/a.js"
  git -C "$SB_WORK" add src/a.js
  local out rc
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[$SB_ROLE] add src/a.js" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "a CODE commit (matching a declared CODE_GLOBS entry) on a feature branch was refused: $out"

  # And a MIXED commit (code + metadata together) is also allowed — the carve-out
  # (process/MANUAL.md § The code-vs-metadata rule: "metadata MAY ride its code branch").
  echo "doc for the code" > "$SB_WORK/src-notes.md"
  echo "more code" > "$SB_WORK/src/b.js"
  git -C "$SB_WORK" add src-notes.md src/b.js
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[$SB_ROLE] add src/b.js + its note" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "a MIXED code+metadata commit on a feature branch was refused: $out"

  finish "pre-commit: allows a code commit (declared via CODE_GLOBS) on a feature branch, and a mixed code+metadata commit alongside it"
  teardown
}

# =============================================================================
# CASE — the pre-commit hook lets a work branch commit ITS OWN card's Dev evidence by itself.
# `dev/evidence/<card>/…` is metadata, and a leg's evidence changes after the code commit; the
# branch's own card is read off the branch name (`<kind>/<card>-<slug>`), and nothing else is
# exempted. Every row that must pass is RED on a hook with no such exemption; the refusals are green
# before and after, and each one is what a looser exemption would turn red:
#   (a) the branch's own evidence file, and one nested below the card's directory, passes;
#   (b) another card's directory, a directory that is only a PREFIX of the card's id, and the bare
#       prefix, are refused naming this branch's own directory;
#   (c) own evidence staged WITH any other metadata, or with the card, is refused: the exemption is for a
#       commit whose every path is the branch's own evidence;
#   (d) a branch whose name carries no card id is refused whatever it stages;
#   (e) an amend of an evidence-only commit passes the same way;
#   (f) a file named dev/evidence/<card> (not a directory) is refused; MSG_OK=1 still bypasses.
# =============================================================================
case_pre_commit_allows_a_branchs_own_dev_evidence() {
  cf_reset
  make_sandbox
  local hook="$SB_WORK/scripts/githooks/pre-commit"
  local cfg="$SB_WORK/scripts/config.sh"
  [ -x "$hook" ] \
    || { skp "pre-commit: allows a branch's own dev/evidence" "scripts/githooks/pre-commit is absent from this tree"; teardown; return; }
  _array_set_body "$cfg" CODE_GLOBS '  "src/*"'
  # What the trunk already holds: another card (a rename source below) and a cited evidence file.
  seed_issue todo "$SB_PREFIX-078" other chore "Another card"
  mkdir -p "$SB_WORK/dev/evidence/$SB_PREFIX-079"
  printf 'the bytes a verdict row cites\nsecond line of the same file\nthird line of the same file\n' > "$SB_WORK/dev/evidence/$SB_PREFIX-079/held.txt"
  publish_sandbox

  local card="$SB_PREFIX-077" out rc
  ( cd "$SB_WORK" && git checkout -q -b "feature/$card-probe" )
  _try() {   # <label> <path>… : stage exactly these, commit as a session would; leaves the result in $out / $rc
    local lbl="$1" p; shift
    for p in "$@"; do mkdir -p "$SB_WORK/$(dirname "$p")"; echo "$lbl $p" > "$SB_WORK/$p"; git -C "$SB_WORK" add "$p"; done
    out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[$SB_ROLE] $lbl" 2>&1 )"; rc=$?
  }
  _unstage() {   # <path>… : back to a clean index and tree after a refusal
    local p
    for p in "$@"; do
      git -C "$SB_WORK" rm -q -f --cached -- "$p" >/dev/null 2>&1; rm -f "${SB_WORK:?}/$p"
      rmdir -p "${SB_WORK:?}/$(dirname "$p")" 2>/dev/null || true
    done
  }

  # (b) refusals first, on a branch with no commit of its own yet.
  _try "other card" "dev/evidence/$SB_PREFIX-078/probe.txt"
  [ "$rc" -ne 0 ] || cf "(b) another card's evidence directory was ACCEPTED on this branch"
  printf '%s' "$out" | grep -F "dev/evidence/$card/" >/dev/null \
    || cf "(b) the refusal does not name this branch's own evidence directory dev/evidence/$card/: $out"
  printf '%s' "$out" | grep -F 'register-commit.sh' >/dev/null || cf "(b) the refusal lost its trunk route: $out"
  _unstage "dev/evidence/$SB_PREFIX-078/probe.txt"
  _try "prefix of the id" "dev/evidence/$SB_PREFIX-07/probe.txt"
  [ "$rc" -ne 0 ] || cf "(b) a directory that is only a prefix of the card id ($SB_PREFIX-07) was ACCEPTED"
  _unstage "dev/evidence/$SB_PREFIX-07/probe.txt"
  _try "bare prefix" "dev/evidence/$SB_PREFIX/probe.txt"
  [ "$rc" -ne 0 ] || cf "(b) the bare prefix directory ($SB_PREFIX) was ACCEPTED"
  _unstage "dev/evidence/$SB_PREFIX/probe.txt"

  # (c) own evidence plus anything that is not the branch's own evidence.
  _try "evidence and a note" "dev/evidence/$card/probe.txt" "a-note.md"
  [ "$rc" -ne 0 ] || cf "(c) own evidence staged with another metadata file was ACCEPTED"
  _unstage "dev/evidence/$card/probe.txt" "a-note.md"
  _try "evidence and the card" "dev/evidence/$card/probe.txt" "progress/todo/$card-probe.md"
  [ "$rc" -ne 0 ] || cf "(c) own evidence staged with the card was ACCEPTED (the card is the trunk's)"
  _unstage "dev/evidence/$card/probe.txt" "progress/todo/$card-probe.md"
  _try "evidence and another card's evidence" "dev/evidence/$card/probe.txt" "dev/evidence/$SB_PREFIX-078/probe.txt"
  [ "$rc" -ne 0 ] || cf "(c) own evidence staged with another card's evidence was ACCEPTED"
  _unstage "dev/evidence/$card/probe.txt" "dev/evidence/$SB_PREFIX-078/probe.txt"

  # (f) a FILE called dev/evidence/<card> is not the card's directory.
  _try "a file, not a directory" "dev/evidence/$card"
  [ "$rc" -ne 0 ] || cf "(f) a file named dev/evidence/$card (no directory) was ACCEPTED"
  out="$( cd "$SB_WORK" && MSG_OK=1 git commit -q -m "[$SB_ROLE] escape" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(f) MSG_OK=1 did not bypass the guard: $out"

  # (a) the branch's own evidence passes, alone and nested.
  ( cd "$SB_WORK" && git checkout -q -b "feature/$card-probe2" "$SB_TRUNK" )
  _try "own evidence" "dev/evidence/$card/probe.txt"
  [ "$rc" -eq 0 ] || cf "(a) the branch's own evidence file alone was refused: $out"
  _try "own nested evidence" "dev/evidence/$card/shots/AC2-error.txt"
  [ "$rc" -eq 0 ] || cf "(a) a file nested below the branch's own evidence directory was refused: $out"

  # (e) an amend of an evidence-only commit is judged on HEAD's paths plus the staged ones.
  echo "changed after the commit" >> "$SB_WORK/dev/evidence/$card/probe.txt"
  git -C "$SB_WORK" add "dev/evidence/$card/probe.txt"
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q --amend --no-edit 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(e) an amend of an evidence-only commit with the same evidence file was refused: $out"

  # (d) a branch with no card id in its name gets no exemption.
  ( cd "$SB_WORK" && git checkout -q -b feature/no-card-here "$SB_TRUNK" )
  _try "no card in the branch name" "dev/evidence/$card/other.txt"
  [ "$rc" -ne 0 ] || cf "(d) evidence on a branch whose name carries no card id was ACCEPTED"
  _unstage "dev/evidence/$card/other.txt"

  # (g) a RENAME into the card's evidence directory is judged on its source too: `git diff` lists only
  # the destination of a rename unless asked not to, and the source is a deletion of a path that is not evidence.
  ( cd "$SB_WORK" && git checkout -q -b "feature/$card-rename" "$SB_TRUNK" )
  mkdir -p "$SB_WORK/dev/evidence/$card"
  git -C "$SB_WORK" mv "progress/todo/$SB_PREFIX-078-other.md" "dev/evidence/$card/moved.md"
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[$SB_ROLE] rename another card into the evidence" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(g) an exact rename of another card into this card's evidence directory was ACCEPTED"
  [ -f "$SB_WORK/dev/evidence/$card/moved.md" ] && git -C "$SB_WORK" reset -q --hard HEAD
  git -C "$SB_WORK" mv "progress/todo/$SB_PREFIX-078-other.md" "dev/evidence/$card/moved.md"
  printf 'one more line\n' >> "$SB_WORK/dev/evidence/$card/moved.md"
  git -C "$SB_WORK" add "dev/evidence/$card/moved.md"
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[$SB_ROLE] rename another card into the evidence, edited" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(g) a rename with edits of another card into this card's evidence directory was ACCEPTED"
  git -C "$SB_WORK" reset -q --hard HEAD

  # (h) a file the TRUNK already holds is not edited or deleted from a branch: a QA row may cite its sha.
  local held="$SB_PREFIX-079"
  ( cd "$SB_WORK" && git checkout -q -b "feature/$held-held" "$SB_TRUNK" )
  printf 'different bytes\n' > "$SB_WORK/dev/evidence/$held/held.txt"
  git -C "$SB_WORK" add "dev/evidence/$held/held.txt"
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[$SB_ROLE] rewrite the held file" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(h) an edit of a dev/evidence file the trunk holds was ACCEPTED on a work branch"
  printf '%s' "$out" | grep -F "dev/evidence/$held/held.txt" >/dev/null || cf "(h) the refusal does not name the file: $out"
  printf '%s' "$out" | grep -F 'Next:' >/dev/null || cf "(h) the refusal gives no next step: $out"
  printf '%s' "$out" | grep -F 'new file' >/dev/null || cf "(h) the refusal does not say to add a new file: $out"
  git -C "$SB_WORK" reset -q --hard HEAD
  git -C "$SB_WORK" rm -q "dev/evidence/$held/held.txt"
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[$SB_ROLE] delete the held file" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(h) a deletion of a dev/evidence file the trunk holds was ACCEPTED on a work branch"
  git -C "$SB_WORK" reset -q --hard HEAD
  # (j) the same holds for a CODE commit: metadata riding it is no exception for a file the trunk holds.
  mkdir -p "$SB_WORK/src"
  printf 'int z;\n' > "$SB_WORK/src/z.c"
  printf 'rewritten beside code\n' > "$SB_WORK/dev/evidence/$held/held.txt"
  git -C "$SB_WORK" add src/z.c "dev/evidence/$held/held.txt"
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[$SB_ROLE] code and a rewritten held file" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(j) a code commit carrying a rewritten dev/evidence file the trunk holds was ACCEPTED"
  printf '%s' "$out" | grep -F "dev/evidence/$held/held.txt" >/dev/null || cf "(j) the refusal does not name the file: $out"
  git -C "$SB_WORK" reset -q --hard HEAD
  mkdir -p "$SB_WORK/src"
  printf 'int z;\n' > "$SB_WORK/src/z.c"
  git -C "$SB_WORK" add src/z.c
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[$SB_ROLE] code alone" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(j) the control, a code commit that touches no held file, was refused: $out"
  _try "a new file beside the held one" "dev/evidence/$held/new.txt"
  [ "$rc" -eq 0 ] || cf "(h) a NEW file beside the held one was refused: $out"

  # (i) the card id is the branch's LAST segment only: a middle segment naming another card gives nothing.
  ( cd "$SB_WORK" && git checkout -q -b "wip/$SB_PREFIX-081-a/$SB_PREFIX-082-b" "$SB_TRUNK" )
  _try "card of a middle segment" "dev/evidence/$SB_PREFIX-081/o.txt"
  [ "$rc" -ne 0 ] || cf "(i) a card id from a middle segment of the branch name was ACCEPTED"
  _unstage "dev/evidence/$SB_PREFIX-081/o.txt"
  _try "card of the last segment" "dev/evidence/$SB_PREFIX-082/o.txt"
  [ "$rc" -eq 0 ] || cf "(i) the card id of the branch's last segment was refused: $out"

  finish "pre-commit: a work branch may commit its own card's dev/evidence/<card>/ files alone (nested, and by amend), refused for another card's, a prefix of the id, a file of that name, a branch with no card id, a card id taken from a middle segment of the branch name, a rename or a deletion of any other path, a change to a file the trunk already holds (a code commit's included), or any commit that adds a path that is not the branch's own evidence"
  teardown
}

# =============================================================================
# CASE — commit-msg WARNS, and never refuses, when the subject's role tag differs from the role on
# the hat file's first word. Rows (the exit status is asserted in every row; a warning is a line on
# stderr and nothing else):
#   (a) a matching tag is silent, whatever the case the hat is written in;
#   (b) a mismatch exits 0, prints one Warning naming both roles, the file and a next step;
#   (c) the operator waiver (`none — …`), no hat file at all, and a script's per-commit declaration say nothing;
#   (d) MSG_OK=1 and the auto-exempt subjects say nothing; an untagged subject is still refused by the
#       existing rule, with no warning added;
#   (e) a linked worktree with no hat file of its own reads the main checkout's, as pre-commit does;
#   (f) through a real `git commit` the commit is made, the warning shows, and the log has it;
#   (g) the standing kanban worktree (holds no session) is not compared.
# =============================================================================
case_commit_msg_warns_on_a_role_tag_that_differs_from_the_hat() {
  cf_reset
  make_sandbox
  local hook="$SB_WORK/scripts/githooks/commit-msg"
  [ -x "$hook" ] \
    || { skp "commit-msg: warns on a mismatched role tag" "scripts/githooks/commit-msg is absent from this tree"; teardown; return; }
  publish_sandbox
  local rel env_name msg="$SB_TMP/msg.txt" out rc err="$SB_TMP/err.txt"
  rel="$(_sandbox_hat_file)"
  env_name="$(sed -n 's/^KIT_HAT_ENV="\(.*\)"$/\1/p' "$SB_WORK/scripts/lib/hat-file.sh")"
  [ -n "$rel" ] && [ -n "$env_name" ] || _fixture_die "case_commit_msg_warns_on_a_role_tag_that_differs_from_the_hat: scripts/lib/hat-file.sh declares no KIT_HAT_FILE_REL or KIT_HAT_ENV on its own line."
  _hat() { mkdir -p "$SB_WORK/$(dirname "$rel")"; printf '%s\n' "$1" > "$SB_WORK/$rel"; }
  _run() {   # <cwd> <subject> [VAR=value…] : run the hook the way git does (cwd = the tree root); stderr to $err, exit in $rc
    local d="$1" s="$2"; shift 2
    printf '%s\n' "$s" > "$msg"
    ( cd "$d" && env -u MSG_OK -u "$env_name" "$@" "$hook" "$msg" ) >/dev/null 2>"$err"; rc=$?
  }
  _warned() { grep -F 'Warning' "$err" >/dev/null; }

  _hat "Dev SBX-001"
  _run "$SB_WORK" "[Dev] fine"
  [ "$rc" -eq 0 ] && [ ! -s "$err" ] || cf "(a) a matching tag was not silent or not accepted (exit $rc): $(cat "$err")"
  _hat "dev SBX-001"
  _run "$SB_WORK" "[Dev] fine"
  [ "$rc" -eq 0 ] && [ ! -s "$err" ] || cf "(a) a hat written in lower case warned against the same role: $(cat "$err")"

  _hat "Dev SBX-001"
  _run "$SB_WORK" "[PM] a ruling"
  [ "$rc" -eq 0 ] || cf "(b) a role-tag mismatch changed the exit status to $rc: $(cat "$err")"
  _warned || cf "(b) a [PM] subject under a Dev hat printed no Warning: $(cat "$err")"
  grep -F '[PM]' "$err" >/dev/null && grep -F 'Dev' "$err" >/dev/null \
    || cf "(b) the warning does not name both roles: $(cat "$err")"
  grep -F "$rel" "$err" >/dev/null || cf "(b) the warning does not name the hat file $rel: $(cat "$err")"
  grep -F 'Next:' "$err" >/dev/null || cf "(b) the warning gives no next step: $(cat "$err")"
  [ "$(grep -c 'Warning' "$err")" -eq 1 ] || cf "(b) more than one Warning line: $(cat "$err")"

  _hat "none — operator override: the operator waived the hat"
  _run "$SB_WORK" "[PM] a ruling"
  [ "$rc" -eq 0 ] && [ ! -s "$err" ] || cf "(c) the operator waiver was compared or refused (exit $rc): $(cat "$err")"
  rm -f "${SB_WORK:?}/${rel:?}"
  _run "$SB_WORK" "[PM] a ruling"
  [ "$rc" -eq 0 ] && [ ! -s "$err" ] || cf "(c) with no hat file the hook said something or refused (that gate is pre-commit's) (exit $rc): $(cat "$err")"
  _hat "Dev SBX-001"
  _run "$SB_WORK" "[PM] a ruling" "$env_name=PM"
  [ "$rc" -eq 0 ] && [ ! -s "$err" ] || cf "(c) a script's per-commit declaration ($env_name) was compared against the file (exit $rc): $(cat "$err")"

  _run "$SB_WORK" "[PM] a ruling" MSG_OK=1
  [ "$rc" -eq 0 ] && [ ! -s "$err" ] || cf "(d) MSG_OK=1 did not stay silent (exit $rc): $(cat "$err")"
  _run "$SB_WORK" "Merge branch 'x'"
  [ "$rc" -eq 0 ] && [ ! -s "$err" ] || cf "(d) an auto-exempt subject was compared (exit $rc): $(cat "$err")"
  _run "$SB_WORK" "no role tag at all"
  [ "$rc" -ne 0 ] || cf "(d) an untagged subject was ACCEPTED (the existing rule)"
  _warned && cf "(d) an untagged subject got a mismatch warning on top of its refusal: $(cat "$err")"

  # (e) a linked worktree of the same repository, the hat declared only in the main checkout.
  local leg="$SB_TMP/leg"
  if git -C "$SB_WORK" worktree add -q -b warn-leg "$leg" "$SB_TRUNK" >/dev/null 2>&1; then
    _run "$leg" "[PM] a ruling"
    { [ "$rc" -eq 0 ] && _warned; } || cf "(e) the main checkout's hat was not read for a linked worktree (exit $rc): $(cat "$err")"
    grep -F "$(cd "$SB_WORK" && pwd -P)/$rel" "$err" >/dev/null \
      || cf "(e) the warning does not print the main checkout's file it read, only the relative name: $(cat "$err")"
    mkdir -p "$leg/$(dirname "$rel")"; printf 'PM leg\n' > "$leg/$rel"
    _run "$leg" "[PM] a ruling"
    [ "$rc" -eq 0 ] && [ ! -s "$err" ] || cf "(e) the worktree's own hat file did not win over the main checkout's: $(cat "$err")"
    chmod 000 "$leg/$rel"
    _run "$leg" "[PM] a ruling"
    chmod 644 "$leg/$rel"
    [ "$rc" -eq 0 ] && [ ! -s "$err" ] || cf "(e) an unreadable own hat file fell back to the main checkout's (exit $rc): $(cat "$err")"
  else
    _control_did_not_run "add a linked worktree to the sandbox"
  fi

  # (f) a real commit: made, warned, and a second commit with the matching tag is silent.
  _hat "Dev SBX-001"
  echo x >> "$SB_WORK/ARCHIVE.md"; git -C "$SB_WORK" add ARCHIVE.md
  out="$( cd "$SB_WORK" && env -u MSG_OK -u "$env_name" git commit -q -m "[PM] a ruling by hand" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(f) a commit with a mismatched tag was refused (exit $rc): $out"
  printf '%s' "$out" | grep -F 'Warning' >/dev/null || cf "(f) git commit printed no warning: $out"
  git -C "$SB_WORK" log -1 --format=%s | grep -F '[PM] a ruling by hand' >/dev/null || cf "(f) the commit is not in the log"
  echo y >> "$SB_WORK/ARCHIVE.md"; git -C "$SB_WORK" add ARCHIVE.md
  out="$( cd "$SB_WORK" && env -u MSG_OK -u "$env_name" git commit -q -m "[Dev] a matching one" 2>&1 )"; rc=$?
  { [ "$rc" -eq 0 ] && ! printf '%s' "$out" | grep -F 'Warning' >/dev/null; } || cf "(f) a matching tag warned or was refused (exit $rc): $out"

  # (g) the standing kanban worktree holds no session: a board script's commit there is not compared.
  local kwt="$SB_TMP/x/.kanban-wt"
  mkdir -p "$SB_TMP/x"
  if git -C "$SB_WORK" worktree add -q --detach "$kwt" "$SB_TRUNK" >/dev/null 2>&1; then
    _run "$kwt" "[QA] board: a move"
    [ "$rc" -eq 0 ] && [ ! -s "$err" ] || cf "(g) a commit in the standing kanban worktree was compared against the main checkout's hat (exit $rc): $(cat "$err")"
  else
    _control_did_not_run "add a .kanban-wt-named linked worktree to the sandbox"
  fi

  # (h) a hat file this user cannot read compares nothing and says nothing: no shell error, no refusal.
  _hat "Dev SBX-001"
  chmod 000 "$SB_WORK/$rel"
  _run "$SB_WORK" "[PM] a ruling"
  chmod 644 "$SB_WORK/$rel"
  if [ "$(id -u)" = 0 ]; then _control_did_not_run "make a hat file unreadable (running as root, which reads it anyway)"
  else [ "$rc" -eq 0 ] && [ ! -s "$err" ] || cf "(h) an unreadable hat file printed something or refused (exit $rc): $(cat "$err")"; fi

  finish "commit-msg: a role tag that differs from the hat file's first word prints one Warning (both roles, the file, a Next: line) and never changes the exit status; a match in any case, the operator waiver, no hat file, a script's per-commit declaration, MSG_OK=1, an auto-exempt subject and the kanban worktree are silent; the main checkout's hat is read for a linked worktree; an untagged subject is still refused with no warning added"
  teardown
}

# =============================================================================
# CASE — the pre-commit hook refuses a commit when no hat is declared. The editor-tool gate does
# not see a mutation made through a shell, and every such mutation must pass a commit to count.
# Built in the real order: the change is made by a shell command (`sed -i`'s effect, here an
# append), staged, and only then committed.
#   (a) no hat file: refused, naming the hat file's path and its form, with a Next: line and a
#       refusal=pre-commit-hat-missing record; the commit does not happen and the change stays staged;
#   (b) the hat file declared (the form, then the operator waiver): the same commit passes;
#   (c) a script's per-commit declaration (the variable lib/hat-file.sh names) passes with no file;
#   (d) the main checkout's hat file covers a linked worktree of the same repository;
#   (e) a DETACHED HEAD in the session's own checkout is not exempt (only the kanban worktree is);
#   (f) with lib/hat-file.sh unreadable the hook refuses, naming the restore (allow-on-doubt reads
#       as armed); MSG_OK=1, the documented escape, still bypasses.
# RED FIRST: every refusal row fails on a pre-commit that does not read the hat.
# =============================================================================
case_pre_commit_refuses_a_commit_with_no_hat() {
  cf_reset
  make_sandbox
  local hook="$SB_WORK/scripts/githooks/pre-commit"
  [ -x "$hook" ] \
    || { skp "pre-commit: refuses a commit with no declared hat" "scripts/githooks/pre-commit is absent from this tree"; teardown; return; }
  publish_sandbox
  local rel env_name out rc head0
  rel="$(_sandbox_hat_file)"
  env_name="$(sed -n 's/^KIT_HAT_ENV="\(.*\)"$/\1/p' "$SB_WORK/scripts/lib/hat-file.sh")"
  [ -n "$rel" ] || _fixture_die "case_pre_commit_refuses_a_commit_with_no_hat: scripts/lib/hat-file.sh declares no KIT_HAT_FILE_REL on its own line."
  if [ -z "$env_name" ]; then
    cf "scripts/lib/hat-file.sh declares no KIT_HAT_ENV on its own line, so a script has no per-commit declaration to make and the hook has none to read"
    env_name="KIT_HAT_ENV_UNDECLARED"   # a name nothing sets: the rows below still run and fail on what they find
  fi
  sandbox_hat_clear
  [ ! -e "$SB_WORK/$rel" ] || _fixture_die "case_pre_commit_refuses_a_commit_with_no_hat: the hat file is still there after sandbox_hat_clear."

  # (a) the mutation is made by the shell, then committed, with no hat.
  printf 'a typo fixed from the shell\n' >> "$SB_WORK/ARCHIVE.md"
  git -C "$SB_WORK" add ARCHIVE.md
  head0="$(git -C "$SB_WORK" rev-parse HEAD)"
  out="$( cd "$SB_WORK" && env -u MSG_OK -u "$env_name" KIT_PROGRESS_DIR="$SB_TMP/rec-a" git commit -q -m "[$SB_ROLE] fix a typo" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) a commit with no hat declared was ACCEPTED"
  case "$out" in *"$rel"*) : ;; *) cf "(a) the refusal does not name the hat file '$rel': $out" ;; esac
  case "$out" in *"<Role> <scope>"*) : ;; *) cf "(a) the refusal does not give the file's form '<Role> <scope>': $out" ;; esac
  case "$out" in *"Next:"*) : ;; *) cf "(a) the refusal carries no Next: line: $out" ;; esac
  grep -q 'refusal=pre-commit-hat-missing' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
    || cf "(a) no progress record carries refusal=pre-commit-hat-missing: $(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null)"
  [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$head0" ] || cf "(a) HEAD moved although the commit was refused"
  git -C "$SB_WORK" diff --cached --name-only | grep -F 'ARCHIVE.md' >/dev/null \
    || cf "(a) the refusal left the change NOT staged — it should be untouched"

  # (b) declared: the form, then the operator waiver (existence is what the gate reads).
  mkdir -p "$SB_WORK/$(dirname "$rel")"; printf 'Dev SBX-001\n' > "$SB_WORK/$rel"
  out="$( cd "$SB_WORK" && env -u MSG_OK -u "$env_name" git commit -q -m "[$SB_ROLE] fix a typo" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) the same commit with the hat file declared was refused: $out"
  rm -f "$SB_WORK/$rel"
  printf 'more\n' >> "$SB_WORK/ARCHIVE.md"; git -C "$SB_WORK" add ARCHIVE.md
  printf 'none — operator override: the operator waived the hat\n' > "$SB_WORK/$rel"
  out="$( cd "$SB_WORK" && env -u MSG_OK -u "$env_name" git commit -q -m "[$SB_ROLE] more" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) a commit under the operator waiver form was refused: $out"
  rm -f "$SB_WORK/$rel"

  # (c) a script declares its hat for one commit, with no file.
  printf 'again\n' >> "$SB_WORK/ARCHIVE.md"; git -C "$SB_WORK" add ARCHIVE.md
  out="$( cd "$SB_WORK" && env -u MSG_OK "$env_name=PM" git commit -q -m "[PM] again" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(c) a commit that sets $env_name was refused: $out"
  [ ! -e "$SB_WORK/$rel" ] || cf "(c) the per-commit declaration left a hat file behind"

  # (d) the main checkout's hat covers a linked worktree of the same repository.
  local leg="$SB_TMP/leg"
  if git -C "$SB_WORK" worktree add -q -b hat-leg "$leg" "$SB_TRUNK" >/dev/null 2>&1; then
    printf 'leg\n' >> "$leg/ARCHIVE.md"; git -C "$leg" add ARCHIVE.md
    out="$( cd "$leg" && env -u MSG_OK -u "$env_name" git commit -q -m "[$SB_ROLE] leg" 2>&1 )"; rc=$?
    [ "$rc" -ne 0 ] || cf "(d) a linked worktree commit with no hat anywhere was ACCEPTED"
    mkdir -p "$SB_WORK/$(dirname "$rel")"; printf 'Dev SBX-001\n' > "$SB_WORK/$rel"
    out="$( cd "$leg" && env -u MSG_OK -u "$env_name" git commit -q -m "[$SB_ROLE] leg" 2>&1 )"; rc=$?
    [ "$rc" -eq 0 ] || cf "(d) the main checkout's hat file did not cover its linked worktree: $out"
    rm -f "$SB_WORK/$rel"
  else
    _control_did_not_run "add a linked worktree to the sandbox"
  fi

  # (e) a detached HEAD in the session's own checkout is not the kanban worktree.
  ( cd "$SB_WORK" && git checkout -q --detach HEAD )
  printf 'detached\n' >> "$SB_WORK/ARCHIVE.md"; git -C "$SB_WORK" add ARCHIVE.md
  out="$( cd "$SB_WORK" && env -u MSG_OK -u "$env_name" git commit -q -m "[$SB_ROLE] detached" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(e) a commit from a detached HEAD in the session's own checkout, with no hat, was ACCEPTED"

  # (f) the lib unreadable refuses; MSG_OK=1 still bypasses.
  mv "$SB_WORK/scripts/lib/hat-file.sh" "$SB_TMP/hat-file.held"
  out="$( cd "$SB_WORK" && env -u MSG_OK -u "$env_name" git commit -q -m "[$SB_ROLE] no lib" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(f) with scripts/lib/hat-file.sh unreadable the commit was ACCEPTED (allow-on-doubt)"
  case "$out" in *"git checkout -- scripts/lib/hat-file.sh"*) : ;; *) cf "(f) the lib-missing refusal names no restore: $out" ;; esac
  out="$( cd "$SB_WORK" && MSG_OK=1 git commit -q -m "[$SB_ROLE] escape" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(f) MSG_OK=1 did not bypass the guard (the documented escape): $out"
  mv "$SB_TMP/hat-file.held" "$SB_WORK/scripts/lib/hat-file.sh"

  finish "pre-commit: a commit with no declared hat is refused naming the hat file, its form and a Next: line, with a refusal=pre-commit-hat-missing record and nothing committed; the hat file (form or waiver), a script's per-commit declaration and the main checkout's hat for a linked worktree pass; a detached HEAD in the session's checkout and an unreadable lib do not; MSG_OK=1 still bypasses"
  teardown
}

# =============================================================================
# CASE — the pre-commit hook refuses a commit that STAGES the hat file. The hat is session state
# and is never committed; a staging commit that sweeps it in (`git add -A` before the project's
# ignore file names it) would fork it per branch. Built in the real order: the hat is declared,
# the change is made, and the hat is force-added beside it (what a sweep does) before the commit.
#   (a) hat file staged: refused, naming the file, the `git rm --cached` fix and a Next: line, with a
#       refusal=pre-commit-hat-file-staged record; nothing is committed and the change stays staged;
#   (b) the same commit without it, the hat file present on disk and unstaged: unaffected;
#   (c) the fix the refusal names — the staged deletion of a hat file that already rode a commit
#       under the documented escape — is accepted, and the hat leaves the tree;
#   (d) a linked worktree is covered too (the guard keys on the staged path, not the checkout).
# RED FIRST: on a pre-commit that does not read the staged paths, (a) and (d) are ACCEPTED.
# =============================================================================
case_pre_commit_refuses_a_staged_hat_file() {
  cf_reset
  make_sandbox
  local hook="$SB_WORK/scripts/githooks/pre-commit"
  [ -x "$hook" ] \
    || { skp "pre-commit: refuses a commit that stages the hat file" "scripts/githooks/pre-commit is absent from this tree"; teardown; return; }
  publish_sandbox
  local rel env_name out rc head0
  rel="$(_sandbox_hat_file)"
  env_name="$(sed -n 's/^KIT_HAT_ENV="\(.*\)"$/\1/p' "$SB_WORK/scripts/lib/hat-file.sh")"
  [ -n "$rel" ] || _fixture_die "case_pre_commit_refuses_a_staged_hat_file: scripts/lib/hat-file.sh declares no KIT_HAT_FILE_REL on its own line."
  [ -e "$SB_WORK/$rel" ] || _fixture_die "case_pre_commit_refuses_a_staged_hat_file: the sandbox declared no hat."

  # (a) the hat is swept into a commit with a real change.
  printf 'a change\n' >> "$SB_WORK/ARCHIVE.md"
  git -C "$SB_WORK" add ARCHIVE.md
  git -C "$SB_WORK" add -f "$rel"
  head0="$(git -C "$SB_WORK" rev-parse HEAD)"
  out="$( cd "$SB_WORK" && env -u MSG_OK -u "$env_name" KIT_PROGRESS_DIR="$SB_TMP/rec-a" git commit -q -m "[$SB_ROLE] stage everything" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) a commit that stages the hat file was ACCEPTED"
  case "$out" in *"$rel"*) : ;; *) cf "(a) the refusal does not name the hat file '$rel': $out" ;; esac
  case "$out" in *"git rm --cached $rel"*) : ;; *) cf "(a) the refusal does not name the fix 'git rm --cached $rel': $out" ;; esac
  case "$out" in *"Next:"*) : ;; *) cf "(a) the refusal carries no Next: line: $out" ;; esac
  cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null | grep -E 'refusal=pre-commit-hat-file-staged([[:space:]]|$)' >/dev/null \
    || cf "(a) no progress record carries refusal=pre-commit-hat-file-staged: $(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null)"
  [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$head0" ] || cf "(a) HEAD moved although the commit was refused"
  git -C "$SB_WORK" diff --cached --name-only | grep -F 'ARCHIVE.md' >/dev/null \
    || cf "(a) the refusal left the change NOT staged — it should be untouched"

  # (b) the fix the refusal names, then the commit without the hat: unaffected, hat still on disk.
  git -C "$SB_WORK" rm -q --cached "$rel" >/dev/null 2>&1 \
    || cf "(b) 'git rm --cached $rel', the fix the refusal names, failed"
  out="$( cd "$SB_WORK" && env -u MSG_OK -u "$env_name" git commit -q -m "[$SB_ROLE] the change alone" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) the same commit without the hat file staged was refused: $out"
  [ -e "$SB_WORK/$rel" ] || cf "(b) the fix removed the hat file from disk — it should only leave the index"
  [ -z "$(git -C "$SB_WORK" ls-tree -r --name-only HEAD -- "$rel")" ] || cf "(b) the hat file is in HEAD's tree"

  # (c) a hat file that already rode a commit (the documented escape): its staged deletion is accepted.
  git -C "$SB_WORK" add -f "$rel"
  out="$( cd "$SB_WORK" && MSG_OK=1 git commit -q -m "[$SB_ROLE] hat rides under the escape" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(c) MSG_OK=1 did not bypass the guard to plant a tracked hat file: $out"
  git -C "$SB_WORK" rm -q --cached "$rel" >/dev/null 2>&1
  out="$( cd "$SB_WORK" && env -u MSG_OK -u "$env_name" git commit -q -m "[$SB_ROLE] untrack the hat" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(c) the staged DELETION of a tracked hat file was refused — the guard blocks its own fix: $out"
  [ -z "$(git -C "$SB_WORK" ls-tree -r --name-only HEAD -- "$rel")" ] || cf "(c) the hat file is still in HEAD's tree after its deletion committed"

  # (d) a linked worktree: the main checkout's hat covers the hat gate, and the staged hat is still refused.
  local leg="$SB_TMP/leg"
  if git -C "$SB_WORK" worktree add -q -b staged-hat-leg "$leg" "$SB_TRUNK" >/dev/null 2>&1; then
    mkdir -p "$leg/$(dirname "$rel")"; printf 'Dev SBX-001\n' > "$leg/$rel"
    printf 'leg\n' >> "$leg/ARCHIVE.md"; git -C "$leg" add ARCHIVE.md; git -C "$leg" add -f "$rel"
    out="$( cd "$leg" && env -u MSG_OK -u "$env_name" git commit -q -m "[$SB_ROLE] leg" 2>&1 )"; rc=$?
    [ "$rc" -ne 0 ] || cf "(d) a commit in a linked worktree that stages the hat file was ACCEPTED"
    case "$out" in *"git rm --cached $rel"*) : ;; *) cf "(d) the linked-worktree refusal does not name the fix: $out" ;; esac
  else
    _control_did_not_run "add a linked worktree to the sandbox"
  fi

  finish "pre-commit: a commit that stages the hat file is refused naming the file, 'git rm --cached' and a Next: line, with a refusal=pre-commit-hat-file-staged record, in the main checkout and a linked worktree; the same commit without it, and the staged deletion of a tracked hat file, pass"
  teardown
}

# =============================================================================
# CASE — the board scripts' commits need no hat file: they commit in the standing kanban worktree,
# which is no session's checkout, and each takes a --role the commit-msg hook holds to the subject.
# Driven with NO hat declared, through the real entry points and in the real order (card on the
# trunk, branch cut, hand-off, landing): move-issue.sh to in_progress and dev_complete,
# register-commit.sh, and finish-pr.sh's squash. Each commit is asked of the remote.
# RED FIRST: with the exemption removed from pre-commit, every board commit below is refused.
# =============================================================================
case_board_scripts_commit_with_no_hat_file() {
  cf_reset
  make_sandbox
  local id="$SB_PREFIX-834" out rc
  seed_issue todo "$id" nohat chore "Board commits with no hat file" "feature/$id-nohat"
  publish_sandbox
  seed_branch "$id" nohat CHANGE834.txt
  sandbox_hat_clear

  out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/move-issue.sh "$id" in_progress --role Dev --note "picked up" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "move-issue.sh to in_progress with no hat file exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/in_progress/$id-nohat.md" || cf "the card did not reach in_progress/ on the trunk"
  out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/move-issue.sh "$id" dev_complete --role Dev --note "ready" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "move-issue.sh to dev_complete with no hat file exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/dev_complete/$id-nohat.md" || cf "the card did not reach dev_complete/ on the trunk"

  printf 'a ruling\n' > "$SB_WORK/hat-notes.md"
  out="$( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "record a ruling" hat-notes.md 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "register-commit.sh with no hat file exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_log_has_subject 'record a ruling' || cf "the register-commit.sh commit is not on the trunk"

  out="$( cd "$SB_WORK" && env -u MSG_OK "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "finish-pr.sh with no hat file exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/qa_complete/$id-nohat.md" || cf "the card did not reach qa_complete/ on the trunk"
  origin_has_path "CHANGE834.txt" || cf "the squash commit's content is not on the trunk"
  [ ! -e "$SB_WORK/$(_sandbox_hat_file)" ] || cf "a board script left a hat file behind"

  finish "the board scripts commit with no hat file declared: move-issue.sh (in_progress, dev_complete), register-commit.sh and finish-pr.sh's squash land on the trunk, because their commits are made in the kanban worktree"
  teardown
}

# =============================================================================
# CASE — register-commit.sh lands a hand-made metadata edit made in a LINKED WORKTREE ON A
# BRANCH OF ITS OWN onto the trunk, without ever committing in that worktree's checkout (a
# harness's own linked-worktree tool defaults to a fresh branch, not the trunk ref). Without this
# script, a bare `git commit` there is the only route, and the pre-commit case above refuses it.
# =============================================================================
case_register_commit_lands_from_a_linked_worktree() {
  cf_reset
  make_sandbox
  local rc_sh="$SB_WORK/scripts/register-commit.sh"
  local cfg="$SB_WORK/scripts/config.sh"
  [ -x "$rc_sh" ] \
    || { skp "register-commit.sh: lands a metadata edit from a linked worktree" "scripts/register-commit.sh is absent from this tree"; teardown; return; }

  # CODE_GLOBS must be DECLARED for the pre-commit control below to refuse at all
  # (case_pre_commit_undeclared_code_globs_is_a_noop covers the undeclared state).
  # _array_set_body replaces the whole array body, whatever it currently holds.
  _array_set_body "$cfg" CODE_GLOBS '  "src/*"'

  seed_issue dev_complete "$SB_PREFIX-527" linked-worktree-card chore "Card for the linked-worktree landing case"
  echo "D-01: an existing ruling" > "$SB_WORK/requirements-register.md"
  publish_sandbox

  # Bootstrap .kanban-wt the way an operator would (a real board op).
  ( cd "$SB_WORK" && ./scripts/move-issue.sh "$SB_PREFIX-527" qa_complete --role "$SB_ROLE" --note "bootstrap" >/dev/null 2>&1 ) \
    || _fixture_die "case_register_commit_lands_from_a_linked_worktree: move-issue.sh would not bootstrap .kanban-wt in this sandbox."
  [ -d "$SB_WORK/.kanban-wt" ] \
    || _fixture_die "case_register_commit_lands_from_a_linked_worktree: .kanban-wt was not created."

  # A linked worktree ON A BRANCH OF ITS OWN — never the trunk ref — the shape a harness's own
  # linked-worktree tool hands you by default.
  local leg="$SB_TMP/leg"
  git -C "$SB_WORK" worktree add -q -b "worktree-followup" "$leg" "$SB_TRUNK" >/dev/null 2>&1 \
    || { skp "register-commit.sh: lands a metadata edit from a linked worktree" "git worktree add failed in this sandbox"; teardown; return; }
  [ -x "$leg/scripts/register-commit.sh" ] \
    || { cf "(control) the linked worktree has no scripts/register-commit.sh"; finish "register-commit.sh from a linked worktree"; teardown; return; }

  echo "D-01: an existing ruling" > "$leg/requirements-register.md"
  echo "D-02: a new ruling, answered here" >> "$leg/requirements-register.md"

  # Confirm the hand-made route IS refused first (the premise this helper exists to fix).
  ( cd "$leg" && git add requirements-register.md \
      && env -u MSG_OK git commit -q -m "[$SB_ROLE] record D-02" >/dev/null 2>&1 ) \
    && cf "(control) a hand-made commit in the linked worktree on 'worktree-followup' was ACCEPTED — the pre-commit refusal did not fire, so this case's premise does not hold here"
  ( cd "$leg" && git reset -q ) 2>/dev/null || true

  # Route it through the helper instead — FROM the linked worktree's own checkout.
  local out rc
  out="$( cd "$leg" && ./scripts/register-commit.sh --role "$SB_ROLE" --message "record D-02 as answered" requirements-register.md 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "register-commit.sh exited $rc from the linked worktree: $out"
  printf '%s' "$out" | grep -F 'Published:' >/dev/null \
    || cf "register-commit.sh did not report a Published line: $out"

  # The leg's OWN branch must NOT carry the commit — it never committed in that checkout.
  git -C "$leg" log --oneline "worktree-followup" 2>/dev/null | grep -F 'record D-02' \
    && cf "the commit landed on the LEG'S OWN BRANCH ('worktree-followup') instead of the trunk — register-commit.sh must never commit in the caller's checkout"

  # THE TRUNK must carry it — asked of the remote, never the local ref (fix-execution.md § A.5d).
  origin_log_has_subject 'record D-02 as answered' \
    || cf "the trunk (origin/$SB_TRUNK) does not carry the commit — it did not actually land"
  origin_file_contains "requirements-register.md" '^D-02: a new ruling, answered here$' \
    || cf "the trunk's copy of requirements-register.md does not carry the new content"

  # SECOND LANDINGS FROM THE SAME CHECKOUT. The first landing left its edit uncommitted here, so the
  # merge-base is still old and a second edit beside it conflicts with the first; that is not staleness.
  # (a) an entry added right after the one just landed.
  echo "D-05: added right after the entry just landed" >> "$leg/requirements-register.md"
  out="$( cd "$leg" && ./scripts/register-commit.sh --role "$SB_ROLE" --message "record D-05" requirements-register.md 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) a second landing from the same checkout, an entry added right after the first, was refused (exit $rc): $out"
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  origin_file_contains "requirements-register.md" '^D-05: added right after the entry just landed$' \
    || cf "(a) the second landing's entry did not reach the trunk"
  # (b) the same line reworded twice.
  local _w
  for _w in once twice; do
    sed -i.bak "s/^D-02: .*/D-02: reworded $_w/" "$leg/requirements-register.md" && rm -f "$leg/requirements-register.md.bak"
    out="$( cd "$leg" && ./scripts/register-commit.sh --role "$SB_ROLE" --message "reword D-02 $_w" requirements-register.md 2>&1 )"; rc=$?
    [ "$rc" -eq 0 ] || cf "(b) rewording the same line '$_w' from the checkout that landed it before was refused (exit $rc): $out"
  done
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  origin_file_contains "requirements-register.md" '^D-02: reworded twice$' \
    || cf "(b) the line reworded twice did not reach the trunk"

  # THE STALE CHECKOUT — a main checkout behind the trunk — in the real workflow's order. Another lane, up to date, lands D-03.
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  local lane="$SB_TMP/lane" fresh="$SB_TMP/fresh"
  git -C "$SB_WORK" worktree add -q -b "lane-b" "$lane" "origin/$SB_TRUNK" >/dev/null 2>&1     || _fixture_die "case_register_commit_lands_from_a_linked_worktree: could not make the second lane's worktree."
  # A blank line before the entry, as a real register separates its entries: the first line the
  # trunk gained is then blank, which must not read as "nothing missing".
  printf '\n%s\n' "D-03: another lane's ruling" >> "$lane/requirements-register.md"
  out="$( cd "$lane" && ./scripts/register-commit.sh --role "$SB_ROLE" --message "record D-03" requirements-register.md 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(control) the up-to-date second lane could not land D-03 (exit $rc): $out"

  # The first leg was cut before D-03 and never took it in: its edit must be REFUSED, the trunk untouched.
  echo "D-04: written from the stale checkout" >> "$leg/requirements-register.md"
  out="$( cd "$leg" && ./scripts/register-commit.sh --role "$SB_ROLE" --message "record D-04 from stale" requirements-register.md 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "a stale checkout's register landed with no refusal (exit 0): $out"
  printf '%s' "$out" | grep -F 'Next:' | grep -F 'trunk' >/dev/null \
    || cf "the stale-checkout refusal has no Next: line naming the trunk: $out"
  printf '%s' "$out" | grep -F 'D-03: another lane' >/dev/null \
    || cf "the stale-checkout refusal does not name the trunk line the checkout lacks: $out"
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  origin_file_contains "requirements-register.md" '^D-03: another lane.s ruling$' \
    || cf "the stale checkout's landing deleted D-03 from the trunk"
  origin_file_contains "requirements-register.md" '^D-04' \
    && cf "the refused stale edit reached the trunk anyway"
  # An EMPTIED copy from the same stale checkout lacks every line the trunk gained: refused, D-03 survives.
  : > "$leg/requirements-register.md"
  out="$( cd "$leg" && ./scripts/register-commit.sh --role "$SB_ROLE" --message "empty from stale" requirements-register.md 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "a stale checkout's EMPTIED register landed with no refusal (exit 0): $out"
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  origin_file_contains "requirements-register.md" '^D-03: another lane.s ruling$' \
    || cf "the stale checkout's emptied file deleted D-03 from the trunk"

  # The same edit from an up-to-date checkout lands, and D-03 survives it.
  git -C "$SB_WORK" worktree add -q -b "fresh-c" "$fresh" "origin/$SB_TRUNK" >/dev/null 2>&1 \
    || _fixture_die "case_register_commit_lands_from_a_linked_worktree: could not make the fresh worktree."
  echo "D-04: written from an up-to-date checkout" >> "$fresh/requirements-register.md"
  out="$( cd "$fresh" && ./scripts/register-commit.sh --role "$SB_ROLE" --message "record D-04" requirements-register.md 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "the up-to-date checkout's D-04 edit was refused (exit $rc): $out"
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  origin_file_contains "requirements-register.md" '^D-04: written from an up-to-date checkout$' \
    || cf "the up-to-date edit did not land"
  origin_file_contains "requirements-register.md" '^D-03: another lane.s ruling$' \
    || cf "D-03 did not survive the up-to-date landing"

  # A legitimate removal, from the checkout that just landed (its HEAD is behind its own landing): lands.
  grep -v '^D-02' "$fresh/requirements-register.md" > "$fresh/r.tmp" && mv "$fresh/r.tmp" "$fresh/requirements-register.md"
  out="$( cd "$fresh" && ./scripts/register-commit.sh --role "$SB_ROLE" --message "retire D-02" requirements-register.md 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "a legitimate removal of D-02 was refused (exit $rc): $out"
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  origin_file_contains "requirements-register.md" '^D-02' \
    && cf "the legitimate removal did not land"

  finish "register-commit.sh lands a hand-made metadata edit made in a linked worktree on a branch of its own onto the trunk, through .kanban-wt, never committing in the leg's own checkout or branch; and refuses a stale checkout's copy that would delete what the trunk gained, while an up-to-date edit, a deliberate removal, and a second landing from the checkout that made the first (an adjacent entry; one line reworded twice) land"
  teardown
}

# =============================================================================
# CASE — register-commit.sh will not land a second copy of a card the trunk holds at another path.
# The real order: the card is in_progress, the Dev's linked worktree is cut, the card is then moved to
# dev_complete on the trunk (the hand-off's move), and the Dev, whose checkout still has the in_progress
# copy, edits it and lands it. Control: the same edit made at the trunk's path lands. A landing that
# deletes the old path and creates the new one is a move, and lands.
# =============================================================================
case_register_commit_refuses_a_second_copy_of_a_card() {
  cf_reset
  make_sandbox
  local rc_sh="$SB_WORK/scripts/register-commit.sh"
  [ -x "$rc_sh" ] \
    || { skp "register-commit.sh: refuses a second copy of a card" "scripts/register-commit.sh is absent from this tree"; teardown; return; }
  local id="$SB_PREFIX-836" out rc
  seed_issue todo "$id" second-copy chore "A card edited at a column it has left" "feature/$id-second-copy"
  publish_sandbox
  seed_branch "$id" second-copy CHANGE836.txt
  ( cd "$SB_WORK" && ./scripts/move-issue.sh "$id" in_progress --role Dev --note "picked up" >/dev/null 2>&1 ) \
    || _fixture_die "case_register_commit_refuses_a_second_copy_of_a_card: the card would not move to in_progress."
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1

  local leg="$SB_TMP/leg836" fresh="$SB_TMP/fresh836" mover="$SB_TMP/mover836"
  git -C "$SB_WORK" worktree add -q -b "leg-836" "$leg" "origin/$SB_TRUNK" >/dev/null 2>&1 \
    || { skp "register-commit.sh: refuses a second copy of a card" "git worktree add failed in this sandbox"; teardown; return; }
  [ -f "$leg/progress/in_progress/$id-second-copy.md" ] \
    || _fixture_die "case_register_commit_refuses_a_second_copy_of_a_card: the leg has no in_progress copy."

  # The hand-off's move lands on the trunk; the leg is not updated.
  ( cd "$SB_WORK" && ./scripts/move-issue.sh "$id" dev_complete --role Dev --note "ready" >/dev/null 2>&1 ) \
    || _fixture_die "case_register_commit_refuses_a_second_copy_of_a_card: the card would not move to dev_complete."
  origin_has_path "progress/dev_complete/$id-second-copy.md" \
    || _fixture_die "case_register_commit_refuses_a_second_copy_of_a_card: the card is not in dev_complete/ on the trunk."

  printf '\n## Handoff to QA\n\nwritten at the column the card left\n' >> "$leg/progress/in_progress/$id-second-copy.md"
  out="$( cd "$leg" && ./scripts/register-commit.sh --role Dev --message "$id: Handoff to QA notes" "progress/in_progress/$id-second-copy.md" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "a copy of the card at its old column landed with no refusal (exit 0): $out"
  printf '%s' "$out" | grep -F "progress/dev_complete/$id-second-copy.md" >/dev/null \
    || cf "the refusal does not name the trunk's dev_complete path: $out"
  printf '%s' "$out" | grep -F 'Next:' >/dev/null || cf "the refusal has no Next: line: $out"
  origin_has_path "progress/in_progress/$id-second-copy.md" \
    && cf "the refused copy reached the trunk: the card is in two columns"

  # Control: the same edit, made at the trunk's path in an up-to-date checkout, lands.
  git -C "$SB_WORK" worktree add -q -b "fresh-836" "$fresh" "origin/$SB_TRUNK" >/dev/null 2>&1 \
    || _fixture_die "case_register_commit_refuses_a_second_copy_of_a_card: could not make the fresh worktree."
  printf '\n## Handoff to QA\n\nwritten at the trunk path\n' >> "$fresh/progress/dev_complete/$id-second-copy.md"
  out="$( cd "$fresh" && ./scripts/register-commit.sh --role Dev --message "$id: Handoff to QA notes" "progress/dev_complete/$id-second-copy.md" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(control) the same edit at the trunk's path was refused (exit $rc): $out"
  origin_file_contains "progress/dev_complete/$id-second-copy.md" '^written at the trunk path$' \
    || cf "(control) the edit at the trunk's path did not reach the trunk"

  # A move (the old path deleted, the new one created, in one landing) is not a second copy.
  git -C "$SB_WORK" worktree add -q -b "mover-836" "$mover" "origin/$SB_TRUNK" >/dev/null 2>&1 \
    || _fixture_die "case_register_commit_refuses_a_second_copy_of_a_card: could not make the mover worktree."
  mkdir -p "$mover/progress/qa_complete"
  mv "$mover/progress/dev_complete/$id-second-copy.md" "$mover/progress/qa_complete/$id-second-copy.md"
  out="$( cd "$mover" && ./scripts/register-commit.sh --role Dev --message "$id: move by hand" \
            "progress/dev_complete/$id-second-copy.md" "progress/qa_complete/$id-second-copy.md" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "a landing that deletes the old path and creates the new one was refused (exit $rc): $out"
  origin_has_path "progress/qa_complete/$id-second-copy.md" || cf "the moved card did not reach qa_complete/"
  origin_has_path "progress/dev_complete/$id-second-copy.md" && cf "the old path survived the move"

  finish "register-commit.sh refuses a landing that creates a card file while the trunk holds that card at another path, naming the trunk's path; the same edit at the trunk's path lands, and so does a landing that deletes the old path as it creates the new"
  teardown
}

# =============================================================================
# CASE — a register-commit.sh refusal part-way through its paths leaves the shared kanban worktree
# CLEAN. The real order: the caller names a path that exists and a second that does not; the
# refusal for the second must not leave the first staged, or the next board op refuses on a worktree
# that holds a stranger's half-landing and its Next says to commit it.
#   (a) refusal, nothing landed, and `git -C .kanban-wt status --short` prints nothing;
#   (b) the board op that follows (a note on a card) succeeds;
#   (c) the same two paths with the missing one named FIRST refuse the same way, still clean.
# RED FIRST: (a) fails with 'A  dev/zz-a.md' staged, and (b) with the worktree-dirty refusal.
# =============================================================================
case_register_commit_refusal_leaves_the_kanban_worktree_clean() {
  cf_reset
  make_sandbox
  local rc_sh="$SB_WORK/scripts/register-commit.sh"
  [ -x "$rc_sh" ] \
    || { skp "register-commit.sh: a refusal leaves the kanban worktree clean" "scripts/register-commit.sh is absent from this tree"; teardown; return; }
  local id="$SB_PREFIX-838" out rc st
  seed_issue todo "$id" after-refusal chore "A board op after a refused landing"
  publish_sandbox
  mkdir -p "$SB_WORK/dev"
  printf 'a hand-made record\n' > "$SB_WORK/dev/zz-a.md"

  out="$( cd "$SB_WORK" && ./scripts/register-commit.sh --role "$SB_ROLE" --message "land two paths" dev/zz-a.md dev/zz-missing.md 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) a missing second path did not refuse (exit 0): $out"
  printf '%s' "$out" | grep -F 'dev/zz-missing.md' >/dev/null || cf "(a) the refusal does not name the missing path: $out"
  [ -d "$SB_WORK/.kanban-wt" ] || _fixture_die "case_register_commit_refusal_leaves_the_kanban_worktree_clean: the call never made the kanban worktree"
  st="$(git -C "$SB_WORK/.kanban-wt" status --short 2>&1)"
  [ -z "$st" ] || cf "(a) the refusal left the kanban worktree dirty: $(printf '%s' "$st" | tr '\n' '|')"
  origin_has_path "dev/zz-a.md" && cf "(a) the refused landing reached the trunk"

  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$id" --note-only --role "$SB_ROLE" --note "after the refused landing" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) the board op after the refusal exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"

  out="$( cd "$SB_WORK" && ./scripts/register-commit.sh --role "$SB_ROLE" --message "land two paths" dev/zz-missing.md dev/zz-a.md 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(c) a missing first path did not refuse (exit 0): $out"
  st="$(git -C "$SB_WORK/.kanban-wt" status --short 2>&1)"
  [ -z "$st" ] || cf "(c) the refusal left the kanban worktree dirty: $(printf '%s' "$st" | tr '\n' '|')"

  finish "register-commit.sh refuses a missing path named after an existing one without staging the existing one: the kanban worktree is clean, nothing reached the trunk, and the next board op succeeds; the order of the two paths does not matter"
  teardown
}

# =============================================================================
# CASE — register-commit.sh tags the subject once.
#   (a) a message that already begins with the --role tag is landed with one tag;
#   (b) an untagged message gets the tag;
#   (c) a message beginning with ANOTHER declared role's tag is refused: the rule id, a Next: line and
#       one refusal record; nothing reaches the trunk;
#   (d) a message that only mentions the tag later in its text is tagged once, at the front;
#   (e) a message beginning with the tag and a colon (`[R]: x`), or with the tag and no space, lands
#       with ONE tag followed by a space;
#   (g) the successful run's first line does not read as a failure, and --help carries no origin story.
# RED FIRST: (a) lands '[R] [R] ...', (c) lands.
# =============================================================================
case_register_commit_tags_the_subject_once() {
  cf_reset
  make_sandbox
  local rc_sh="$SB_WORK/scripts/register-commit.sh"
  [ -x "$rc_sh" ] \
    || { skp "register-commit.sh: tags the subject once" "scripts/register-commit.sh is absent from this tree"; teardown; return; }
  local other out rc subj
  other="$(printf '%s' "$KIT_NEUTRAL_ROLE_PREFIXES" | cut -d'|' -f2)"
  [ -n "$other" ] && [ "$other" != "$SB_ROLE" ] || _fixture_die "case_register_commit_tags_the_subject_once: the neutral role set has no second member."
  publish_sandbox
  mkdir -p "$SB_WORK/dev"
  _land() {   # $1 = file, $2 = message
    printf 'record %s\n' "$1" > "$SB_WORK/dev/$1.md"
    out="$( cd "$SB_WORK" && KIT_PROGRESS_DIR="$SB_TMP/rec-$1" ./scripts/register-commit.sh --role "$SB_ROLE" --message "$2" "dev/$1.md" 2>&1 )"; rc=$?
  }
  _subjects() { git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1; git -C "$SB_WORK" log "origin/$SB_TRUNK" --format=%s; }

  _land a "[$SB_ROLE] Record D-99 tagged"
  [ "$rc" -eq 0 ] || cf "(a) a message carrying the --role tag was refused (exit $rc): $out"
  _subjects | grep -Fx "[$SB_ROLE] Record D-99 tagged" >/dev/null || cf "(a) the trunk has no subject '[$SB_ROLE] Record D-99 tagged': $(_subjects | head -3 | tr '\n' '|')"
  printf '%s' "$out" | grep -F 'NOT yet published' >/dev/null \
    && cf "(a) a run that went on to publish printed a line reading as a failure ('NOT yet published'): $out"

  _land b "Record D-98 untagged"
  [ "$rc" -eq 0 ] || cf "(b) an untagged message was refused (exit $rc): $out"
  _subjects | grep -Fx "[$SB_ROLE] Record D-98 untagged" >/dev/null || cf "(b) the trunk has no subject '[$SB_ROLE] Record D-98 untagged'"

  _land d "Record D-96, as [$SB_ROLE] said"
  [ "$rc" -eq 0 ] || cf "(d) a message mentioning the tag later was refused (exit $rc): $out"
  _subjects | grep -Fx "[$SB_ROLE] Record D-96, as [$SB_ROLE] said" >/dev/null || cf "(d) the trunk has no subject tagged once at the front"

  _land e "[$SB_ROLE]: Record D-95 with a colon"
  [ "$rc" -eq 0 ] || cf "(e) a message carrying the --role tag and a colon was refused (exit $rc): $out"
  _subjects | grep -Fx "[$SB_ROLE] Record D-95 with a colon" >/dev/null || cf "(e) the trunk has no subject '[$SB_ROLE] Record D-95 with a colon' (tagged once): $(_subjects | head -3 | tr '\n' '|')"
  _land f "[$SB_ROLE]Record D-94 tight"
  [ "$rc" -eq 0 ] || cf "(f) a message carrying the --role tag with no space after it was refused (exit $rc): $out"
  _subjects | grep -Fx "[$SB_ROLE] Record D-94 tight" >/dev/null || cf "(f) the trunk has no subject '[$SB_ROLE] Record D-94 tight' (tagged once): $(_subjects | head -3 | tr '\n' '|')"
  out="$( cd "$SB_WORK" && ./scripts/register-commit.sh --help 2>&1 )"
  printf '%s' "$out" | grep -F 'WHY THIS EXISTS' >/dev/null && cf "(g) --help still carries the origin-story paragraph"
  printf '%s' "$out" | grep -F -- '--message' >/dev/null || cf "(g) --help does not describe --message"

  local before; before="$(_subjects | wc -l | tr -d ' ')"
  _land c "[$other] Record D-97 under the wrong hat"
  [ "$rc" -ne 0 ] || cf "(c) a message tagged [$other] under --role $SB_ROLE landed (exit 0): $out"
  printf '%s' "$out" | grep -F 'Next:' >/dev/null || cf "(c) the refusal carries no Next: line: $out"
  grep -q 'refusal=register-message-tag-mismatch' "$SB_TMP/rec-c"/*.tsv 2>/dev/null \
    || cf "(c) no progress record carries refusal=register-message-tag-mismatch: $(cat "$SB_TMP/rec-c"/*.tsv 2>/dev/null)"
  [ "$(_subjects | wc -l | tr -d ' ')" = "$before" ] || cf "(c) the refused message reached the trunk"

  finish "register-commit.sh adds the --role tag once: a message already carrying it, an untagged one and one that mentions it later each land with a single leading tag; the tag followed by a colon or by no space lands as one tag and a space; a message beginning with another declared role's tag is refused with register-message-tag-mismatch, a Next: line and a record, and nothing lands; a run that publishes does not print 'NOT yet published', and --help carries no origin story"
  teardown
}

# =============================================================================
# CASE — register-commit.sh REFUSES WHILE LOCAL TRUNK HOLDS COMMITS ITS REMOTE LACKS.
#
# A landing goes on the remote's tip, so a trunk with unpushed commits ends up beside them: a second
# history. Rows in the order a project meets them, one case, each with the state built the way it is
# reached (a hand commit on the trunk; another clone pushing):
#   (a) equal lands (the control);                    (b) behind only lands;
#   (c) ahead, a disjoint path: trunk-ahead, its Next names the push; nothing committed or pushed;
#   (d) ahead, the path the unpushed commit touched: the same refusal;
#   (e) the printed push, then the same call: lands, and the trunk holds no commit the remote lacks;
#   (f) diverged: trunk-diverged, its Next names the merge and the push;
#   (g) that Next as printed, then the same call: lands, and both histories are in the remote's trunk;
#   (h) the trunk checked out in no worktree: refused ahead and diverged, the local trunk ref untouched, and the
#       diverged Next merges on the trunk, not on the feature branch;
#   (i) no kanban worktree yet: the same refusal, and no worktree is made;
#   (j) the remote unreachable: refused from the last fetch, and says so;
#   (k) the remote named by KWT_REMOTE: its name is in the Next.
# ABLATION: with the call removed, (c) (d) (f) (h) (i) (j) (k) land; with the check keyed to the checked-out
# HEAD, (h) lands; with the call placed after the worktree's bootstrap, (i) gets the sync refusal instead;
# with `origin` typed in the Next, (k) is red.
# =============================================================================
case_register_commit_refuses_a_trunk_its_remote_lacks() {
  cf_reset
  make_sandbox
  local rc_sh="$SB_WORK/scripts/register-commit.sh"
  [ -x "$rc_sh" ] \
    || { skp "register-commit.sh: refuses a trunk its remote lacks" "scripts/register-commit.sh is absent from this tree"; teardown; return; }
  publish_sandbox
  mkdir -p "$SB_WORK/dev"
  local other="$SB_TMP/other" out rc n=0 t0 l0 hand next fix
  git clone -q "$SB_ORIGIN" "$other" >/dev/null 2>&1 || _fixture_die "case_register_commit_refuses_a_trunk_its_remote_lacks: could not clone the sandbox's remote."
  git -C "$other" config user.email "other@sandbox.invalid" >/dev/null 2>&1
  git -C "$other" config user.name "Other Clone" >/dev/null 2>&1
  _tip()   { git -C "$SB_ORIGIN" rev-parse "refs/heads/$SB_TRUNK"; }
  _local() { git -C "$SB_WORK" rev-parse "refs/heads/$SB_TRUNK"; }
  _reset() {   # the main checkout on the trunk, equal to the remote's
    git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1
    git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
    git -C "$SB_WORK" reset -q --hard "origin/$SB_TRUNK" >/dev/null 2>&1
  }
  _hand() {   # a hand-made commit on the local trunk, unpushed; $1 = the file it touches
    n=$((n+1)); mkdir -p "$(dirname "$SB_WORK/$1")"
    printf 'hand-made %s\n' "$n" > "$SB_WORK/$1"
    git -C "$SB_WORK" add "$1" >/dev/null 2>&1
    sbcommit -m "[$SB_ROLE] hand-made $n" --quiet >/dev/null 2>&1
  }
  _theirs() {   # another clone pushes a commit
    n=$((n+1))
    git -C "$other" fetch -q origin >/dev/null 2>&1
    git -C "$other" reset -q --hard "origin/$SB_TRUNK" >/dev/null 2>&1
    printf 'theirs %s\n' "$n" > "$other/theirs-$n.txt"
    git -C "$other" add "theirs-$n.txt" >/dev/null 2>&1
    git -C "$other" commit -q -m "theirs $n" >/dev/null 2>&1
    git -C "$other" push -q origin "HEAD:$SB_TRUNK" >/dev/null 2>&1
  }
  _land() {   # <label> [VAR=value…] — the call under test; the first line of the file it lands names the label
    local label="$1"; shift
    t0="$(_tip)"; l0="$(_local)"
    printf 'landed %s\n' "$label" > "$SB_WORK/dev/$label.md"
    rc=0; out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-$label" "$@" ./scripts/register-commit.sh --role "$SB_ROLE" --message "land $label" "dev/$label.md" 2>&1 )" || rc=$?
    next="$(printf '%s\n' "$out" | sed -n 's/^Next: //p')"
  }
  _follow() {   # run the command the refusal's Next: printed, as printed: only after a refusal, never on a landing's output
    fix=""
    if [ "$rc" -ne 1 ] || [ -z "$next" ]; then cf "(follow) nothing to follow: the call was not refused (exit $rc)"; rc=1; return 0; fi
    fix="${next#*:  }"
    rc=0; env -u MSG_OK GIT_MERGE_AUTOEDIT=no bash -c "$fix" >/dev/null 2>&1 </dev/null || rc=$?
  }
  _lands() {   # <row> <label> — it landed on the remote
    [ "$rc" -eq 0 ] || cf "($1) the landing was refused (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
    origin_has_path "dev/$2.md" || cf "($1) dev/$2.md did not reach the remote's trunk"
  }
  _refused() {   # <row> <label> <rule> <literal the Next must carry>…
    local row="$1" label="$2" rule="$3"; shift 3
    local lit
    [ "$rc" -eq 1 ] || cf "($row) the call exited $rc, not the refusal's 1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
    grep -q "refusal=$rule" "$SB_TMP/rec-$label"/*.tsv 2>/dev/null \
      || cf "($row) no progress record carries refusal=$rule: $(cat "$SB_TMP/rec-$label"/*.tsv 2>/dev/null | cut -c1-200)"
    [ -n "$next" ] || cf "($row) the refusal carries no Next: line"
    for lit in "$@"; do
      printf '%s' "$next" | grep -F -- "$lit" >/dev/null || cf "($row) the Next does not carry '$lit': $next"
    done
    [ "$(_tip)" = "$t0" ] || cf "($row) the remote's trunk moved on a refused call"
    [ "$(_local)" = "$l0" ] || cf "($row) the local trunk moved on a refused call"
    printf '%s' "$out" | grep -F 'Published:' >/dev/null && cf "($row) a refused call printed 'Published:'"
    [ ! -e "$SB_WORK/.kanban-wt.lock" ] || cf "($row) the refused call left the kanban worktree's lock"
    [ ! -e "$SB_WORK/.kanban-wt/dev/$label.md" ] || cf "($row) the refused call wrote dev/$label.md into the kanban worktree"
  }

  # (a) equal: the control
  _land a
  _lands a a

  # (b) behind only
  _reset; _theirs
  _land b
  _lands b b

  # (c) ahead, a disjoint path
  _reset; _hand hand-c.txt
  _land c
  _refused c c trunk-ahead "push origin $SB_TRUNK"
  printf '%s' "$out" | grep -F 'hand-made' >/dev/null || cf "(c) the refusal does not list the unpushed commit: $out"

  # (d) ahead, the path the unpushed commit touched
  _reset; _hand dev/d.md
  hand="$(_local)"
  _land d
  _refused d d trunk-ahead "push origin $SB_TRUNK"

  # (e) the printed push, as printed, then the same call
  _follow
  [ "$rc" -eq 0 ] || cf "(e) the push the Next printed failed (exit $rc): $next"
  _land e
  _lands e e
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  git -C "$SB_WORK" merge-base --is-ancestor "$hand" "origin/$SB_TRUNK" >/dev/null 2>&1 \
    || cf "(e) the hand-made commit is not in the remote's trunk after the push and the landing"
  [ "$(git -C "$SB_WORK" rev-list --count "origin/$SB_TRUNK..$SB_TRUNK")" = 0 ] \
    || cf "(e) the local trunk still holds commits the remote lacks"

  # (f) diverged
  _reset; _hand hand-f.txt; _theirs
  _land f
  _refused f f trunk-diverged "merge origin/$SB_TRUNK" "push origin $SB_TRUNK"
  hand="$(_local)"

  # (g) that Next as printed, then the same call
  _follow
  [ "$rc" -eq 0 ] || cf "(g) the merge and push the Next printed failed (exit $rc): $next"
  _land g
  _lands g g
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  git -C "$SB_WORK" merge-base --is-ancestor "$hand" "origin/$SB_TRUNK" >/dev/null 2>&1 \
    || cf "(g) the hand-made commit is not in the remote's trunk"
  [ "$(git -C "$SB_WORK" rev-list --count "origin/$SB_TRUNK..$SB_TRUNK")" = 0 ] \
    || cf "(g) the local trunk still holds commits the remote lacks"

  # (h) the trunk checked out in no worktree: the refs are compared, not the checkout's HEAD
  _reset; _hand hand-h.txt
  git -C "$SB_WORK" checkout -q -b feature "origin/$SB_TRUNK" >/dev/null 2>&1
  local feat; feat="$(git -C "$SB_WORK" rev-parse feature)"
  _land h
  _refused h h trunk-ahead "push origin $SB_TRUNK"
  #     and diverged: no worktree holds the trunk, so the Next switches to it before it merges (never into feature)
  _theirs
  _land h2
  _refused h2 h2 trunk-diverged "switch $SB_TRUNK" "merge origin/$SB_TRUNK" "push origin $SB_TRUNK"
  _follow
  [ "$rc" -eq 0 ] || cf "(h) the switch, merge and push the Next printed failed (exit $rc): $next"
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  [ "$(git -C "$SB_WORK" rev-list --count "origin/$SB_TRUNK..$SB_TRUNK")" = 0 ] \
    || cf "(h) after the printed route the local trunk still holds commits the remote lacks"
  [ "$(git -C "$SB_WORK" rev-parse feature)" = "$feat" ] || cf "(h) the printed merge landed on the feature branch"
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" branch -q -D feature >/dev/null 2>&1

  # (i) no kanban worktree yet: the same refusal, before one is made
  _reset; _hand hand-i.txt
  git -C "$SB_WORK" worktree remove --force .kanban-wt >/dev/null 2>&1
  git -C "$SB_WORK" worktree prune >/dev/null 2>&1
  [ ! -e "$SB_WORK/.kanban-wt" ] || _fixture_die "case_register_commit_refuses_a_trunk_its_remote_lacks: the kanban worktree could not be removed, so row (i) has no premise."
  _land i
  _refused i i trunk-ahead "push origin $SB_TRUNK"
  [ ! -e "$SB_WORK/.kanban-wt" ] || cf "(i) the refused call made the kanban worktree"
  printf '%s' "$out" | grep -F 'kanban-sync-unpushed' >/dev/null && cf "(i) the sync's refusal answered, not the trunk's: $out"

  # (j) the remote unreachable: the last fetch is read, and the refusal says so
  git -C "$SB_WORK" remote set-url origin "$SB_TMP/no-such-remote.git" >/dev/null 2>&1
  _land j
  _refused j j trunk-ahead "push origin $SB_TRUNK"
  printf '%s' "$out" | grep -F 'last fetch' >/dev/null || cf "(j) the refusal does not say it read the last fetch: $out"
  git -C "$SB_WORK" remote set-url origin "$SB_ORIGIN" >/dev/null 2>&1

  # (k) the remote under another name
  git -C "$SB_WORK" remote rename origin upstream >/dev/null 2>&1
  _land k KWT_REMOTE=upstream
  _refused k k trunk-ahead "push upstream $SB_TRUNK"
  _follow
  [ "$rc" -eq 0 ] || cf "(k) the push the Next printed failed (exit $rc): $next"
  _land k2 KWT_REMOTE=upstream
  [ "$rc" -eq 0 ] || cf "(k) the landing after the push was refused (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"

  finish "register-commit.sh refuses a trunk holding commits its remote lacks, before it touches the kanban worktree: trunk-ahead with the push in its Next, trunk-diverged with the merge, each leaving the trunk and the remote as they were, the checked-out HEAD not consulted, an unreachable remote read from the last fetch, the remote's name taken from KWT_REMOTE; the printed Next clears it; a trunk equal to or behind its remote lands"
  teardown
}

# =============================================================================
# CASE — a forced push failure is LOUD and nonzero (never a silent proceed).
# =============================================================================
case_push_failure() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-300" sandbox chore "Push failure"
  publish_sandbox
  # Break the remote AFTER the board is published, so the local commit succeeds
  # but the push in kwt_finalize fails.
  git -C "$SB_WORK" remote set-url origin "file://$SB_TMP/gone-$RANDOM.git" >/dev/null 2>&1

  local out rc
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-300" in_progress \
            --role Dev --note "should fail to push" 2>&1 )"; rc=$?

  [ "$rc" -ne 0 ] || cf "expected nonzero exit when the push fails, got 0"
  printf '%s' "$out" | grep -iE 'NOT on origin|push origin HEAD|not pushed|DISCARD this commit|unreachable' >/dev/null \
    || cf "no loud recovery text on push failure: $out"

  finish "push failure: loud recovery text + nonzero exit (no silent proceed)"
  teardown
}

# =============================================================================
# CASE — THE UNPUSHED-COMMIT REFUSAL NAMES EACH COMMIT AND DOES NOT CALL THEM AN OP'S.
# The board worktree can hold a commit that no op made (a commit of the user's own, or another
# author's), and publishing it through the board puts it on the trunk unchecked. The refusal must
# list each commit with its author and subject, say what publishing does, offer publishing only for
# commits a failed op named as not landed (an author is no test, and a hand commit can carry a
# move's subject), send local trunk work to the main checkout, and name a way out that does not
# default to publishing.
# =============================================================================
case_unpushed_commit_refusal_names_each_commit_and_does_not_call_them_an_ops() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-320" sandbox chore "Unpushed refusal"
  seed_issue todo "$SB_PREFIX-321" sandbox chore "Unpushed refusal second"
  publish_sandbox
  local out rc wt nxt me="case_unpushed_commit_refusal_names_each_commit_and_does_not_call_them_an_ops"
  wt="$SB_WORK/.kanban-wt"
  ( cd "$SB_WORK" && ./scripts/move-issue.sh "$SB_PREFIX-320" in_progress --role Dev --note warm ) >/dev/null 2>&1 \
    || _fixture_die "$me: the warm-up move failed"
  [ -d "$wt" ] || _fixture_die "$me: no board worktree after the warm-up move"
  MSG_OK=1 git -C "$wt" commit -q --allow-empty -m "[Dev] my own unpushed work" >/dev/null 2>&1 \
    || _fixture_die "$me: could not make the first commit"
  MSG_OK=1 git -C "$wt" commit -q --allow-empty --author="Some Other Person <other@sandbox.invalid>" -m "[Dev] a stranger's commit" >/dev/null 2>&1 \
    || _fixture_die "$me: could not make the second commit"
  # A hand commit in a move's own shape, by the configured author: the commit no check on author or
  # subject can tell from an op's.
  MSG_OK=1 git -C "$wt" commit -q --allow-empty -m "[QA] $SB_PREFIX-320 → qa_complete: pass" >/dev/null 2>&1 \
    || _fixture_die "$me: could not make the third commit"
  rc=0; out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$SB_PREFIX-321" in_progress --role Dev --note second 2>&1 )" || rc=$?
  [ "$rc" -eq 1 ] || cf "(control) exit $rc, expected 1: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  printf '%s\n' "$out" | grep -F 'NOT on origin' >/dev/null || cf "(control) the unpushed-commit refusal did not fire, so its Next: is unread: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  nxt="$(printf '%s\n' "$out" | sed -n '/^Next:/,$p')"
  # Each commit is named with its author and its subject.
  printf '%s\n' "$out" | grep -F 'Sandbox Test [Dev] my own unpushed work' >/dev/null \
    || cf "(a) the listing does not give the first commit's author and subject: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-500)"
  printf '%s\n' "$out" | grep -F "Some Other Person [Dev] a stranger's commit" >/dev/null \
    || cf "(a) the listing does not give the second commit's author and subject"
  # The user's own commit is not described as an op's, and publishing is not the default.
  printf '%s\n' "$nxt" | grep -F 'almost always right' >/dev/null && cf "(b) the Next: still calls publishing almost always right"
  printf '%s\n' "$nxt" | grep -F 'an op made them' >/dev/null && cf "(b) the Next: still says an op made them"
  printf '%s\n' "$nxt" | grep -F -- '--default "publish them"' >/dev/null && cf "(b) the ask the Next: names still defaults to publishing"
  printf '%s\n' "$nxt" | grep -F 'by hand' >/dev/null || cf "(b) the Next: does not name a commit made by hand as a way to get here: $(printf '%s' "$nxt" | tr '\n' '|')"
  # It still names what publishing does and the commands, so the refusal names its way out.
  printf '%s\n' "$nxt" | grep -F 'for everyone' >/dev/null || cf "(c) the Next: does not say what publishing a commit does"
  printf '%s\n' "$nxt" | grep -F 'push origin HEAD:' >/dev/null || cf "(c) the Next: names no publish command"
  printf '%s\n' "$nxt" | grep -F 'ask.sh' >/dev/null || cf "(c) the Next: names no ask for a commit that is not the reader's op's"
  # The test for publishing is a failed op's own list, never the author or the subject's shape.
  printf '%s\n' "$nxt" | grep -F 'its author is you' >/dev/null && cf "(e) the Next: offers the author as the test for publishing"
  printf '%s\n' "$nxt" | grep -F 'announced' >/dev/null && cf "(e) the Next: offers the subject's shape as the test for publishing"
  printf '%s\n' "$nxt" | grep -F 'Commits that did NOT land' >/dev/null || cf "(e) the Next: does not name a failed op's 'Commits that did NOT land' list as the test"
  printf '%s\n' "$nxt" | grep -F 'carries the same author' >/dev/null || cf "(e) the Next: does not say a hand commit carries the same author"
  # Local trunk work is recognised by one command and published from the main checkout.
  printf '%s\n' "$nxt" | grep -F "git log origin/$SB_TRUNK..$SB_TRUNK" >/dev/null || cf "(f) the Next: does not name 'git log origin/$SB_TRUNK..$SB_TRUNK' as the test for local trunk work"
  printf '%s\n' "$nxt" | grep -F 'never through this worktree' >/dev/null || cf "(f) the Next: does not send local trunk work to the main checkout"
  # Nothing was published or reset.
  [ "$(git -C "$wt" log "origin/$SB_TRUNK..HEAD" --format=%s | wc -l | tr -d ' ')" = 3 ] || cf "(d) the refused move changed what the board worktree holds"
  finish "the unpushed-commit refusal lists each commit with its author and subject, says what publishing does, offers publishing only for commits a failed op named as not landed (never an author or a subject's shape), sends local trunk work to the main checkout, does not call publishing almost always right, and its ask does not default to publishing"
  teardown
}

# =============================================================================
# CASE — THE ATTACHED-BRANCH REFUSAL HOLDS THE SAME LINE AS THE UNPUSHED-COMMIT ONE.
# A board worktree attached to a branch that carries commits its remote counterpart lacks is refused
# before it is detached. The Next: must list each commit with its author and subject, say that no
# board op commits on an attached branch so the commits were made by hand, ask before it offers the
# push, say what the push publishes, and carry an ask whose default is to leave them.
# =============================================================================
case_attached_branch_refusal_names_each_commit_and_does_not_default_to_publishing() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-322" sandbox chore "Attached refusal"
  seed_issue todo "$SB_PREFIX-323" sandbox chore "Attached refusal second"
  publish_sandbox
  local out rc wt nxt me="case_attached_branch_refusal_names_each_commit_and_does_not_default_to_publishing"
  wt="$SB_WORK/.kanban-wt"
  ( cd "$SB_WORK" && ./scripts/move-issue.sh "$SB_PREFIX-322" in_progress --role Dev --note warm ) >/dev/null 2>&1 \
    || _fixture_die "$me: the warm-up move failed"
  [ -d "$wt" ] || _fixture_die "$me: no board worktree after the warm-up move"
  git -C "$wt" switch -q -c side-board >/dev/null 2>&1 || _fixture_die "$me: could not attach the board worktree to a branch"
  git -C "$wt" push -q origin side-board >/dev/null 2>&1 || _fixture_die "$me: could not give the branch a remote counterpart"
  MSG_OK=1 git -C "$wt" commit -q --allow-empty -m "[Dev] my own unpublished work" >/dev/null 2>&1 \
    || _fixture_die "$me: could not make the first commit"
  MSG_OK=1 git -C "$wt" commit -q --allow-empty --author="Some Other Person <other@sandbox.invalid>" -m "[Dev] a stranger's commit" >/dev/null 2>&1 \
    || _fixture_die "$me: could not make the second commit"
  rc=0; out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$SB_PREFIX-323" in_progress --role Dev --note second 2>&1 )" || rc=$?
  [ "$rc" -eq 1 ] || cf "(control) exit $rc, expected 1: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  printf '%s\n' "$out" | grep -F 'ATTACHED to' >/dev/null || cf "(control) the attached-branch refusal did not fire, so its Next: is unread: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  printf '%s\n' "$out" | grep -F 'Unpublished on' >/dev/null || cf "(control) it is not the unpublished-commits refusal: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  nxt="$(printf '%s\n' "$out" | sed -n '/^Next:/,$p')"
  printf '%s\n' "$out" | grep -F 'Sandbox Test [Dev] my own unpublished work' >/dev/null \
    || cf "(a) the listing does not give the first commit's author and subject: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-500)"
  printf '%s\n' "$out" | grep -F "Some Other Person [Dev] a stranger's commit" >/dev/null \
    || cf "(a) the listing does not give the second commit's author and subject"
  printf '%s\n' "$nxt" | grep -F 'almost always' >/dev/null && cf "(b) the Next: still says publishing is almost always what you want"
  printf '%s\n' "$nxt" | grep -F -- '--default "publish them"' >/dev/null && cf "(b) the ask the Next: names defaults to publishing"
  printf '%s\n' "$nxt" | grep -F -- '--default "leave them and stop"' >/dev/null || cf "(b) the ask the Next: names does not default to leaving them: $(printf '%s' "$nxt" | tr '\n' '|')"
  printf '%s\n' "$nxt" | grep -F 'by hand' >/dev/null || cf "(b) the Next: does not name a commit made by hand as a way to get here"
  printf '%s\n' "$nxt" | grep -F 'for everyone' >/dev/null || cf "(c) the Next: does not say what publishing does"
  printf '%s\n' "$nxt" | grep -F 'push origin' >/dev/null || cf "(c) the Next: names no publish command"
  # No op commits on an attached branch, so no failed op can name these: the Next asks first.
  printf '%s\n' "$nxt" | grep -F 'never commits on an attached branch' >/dev/null || cf "(e) the Next: does not say a board op never commits on an attached branch"
  printf '%s\n' "$nxt" | grep -F 'Publish only if every one is a commit an op' >/dev/null && cf "(e) the Next: still offers publishing for an op's commit, which no op makes on an attached branch"
  printf '%s\n' "$nxt" | grep -F 'its author is you' >/dev/null && cf "(e) the Next: offers the author as the test for publishing"
  [ "$(printf '%s\n' "$nxt" | awk '/ask\.sh/{print NR; exit}')" -lt "$(printf '%s\n' "$nxt" | awk '/push origin/{print NR; exit}')" ] 2>/dev/null \
    || cf "(e) the ask does not come before the push command"
  [ "$(git -C "$wt" log "origin/side-board..side-board" --format=%s | wc -l | tr -d ' ')" = 2 ] || cf "(d) the refused move changed what the branch holds"
  finish "the attached-branch refusal lists each unpublished commit with its author and subject, says no board op commits on an attached branch, asks before it offers the push, says what the push publishes, and its ask defaults to leaving them"
  teardown
}

# =============================================================================
# CASE — A BOARD WORKTREE BUILT FROM LOCAL TRUNK WORK IS REFUSED WITH THE WAY TO RECOGNISE IT.
# With no board worktree, the next op builds one from the LOCAL trunk. A commit the user made there
# and has not pushed is then in the worktree's unpushed list. The Next: must give the one command
# that lists the same commit in the main checkout, and send that work to be published from there.
# =============================================================================
case_board_worktree_built_from_local_trunk_work_names_how_to_recognise_it() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-324" sandbox chore "Local trunk work"
  seed_issue todo "$SB_PREFIX-325" sandbox chore "Local trunk work second"
  publish_sandbox
  local out rc wt nxt o0 o1 me="case_board_worktree_built_from_local_trunk_work_names_how_to_recognise_it"
  wt="$SB_WORK/.kanban-wt"
  ( cd "$SB_WORK" && ./scripts/move-issue.sh "$SB_PREFIX-324" in_progress --role Dev --note warm ) >/dev/null 2>&1 \
    || _fixture_die "$me: the warm-up move failed"
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  git -C "$SB_WORK" merge -q --ff-only "origin/$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "$me: could not bring the main checkout up to the trunk"
  git -C "$SB_WORK" worktree remove --force "$wt" >/dev/null 2>&1 || _fixture_die "$me: could not remove the board worktree"
  printf 'local\n' > "$SB_WORK/LOCALWORK.txt"
  git -C "$SB_WORK" add LOCALWORK.txt >/dev/null 2>&1
  sbcommit -q -m "[Dev] local unpushed" >/dev/null 2>&1 || _fixture_die "$me: could not make the local trunk commit"
  o0="$(git -C "$SB_ORIGIN" rev-parse "$SB_TRUNK" 2>/dev/null)"
  rc=0; out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$SB_PREFIX-325" in_progress --role Dev --note second 2>&1 )" || rc=$?
  o1="$(git -C "$SB_ORIGIN" rev-parse "$SB_TRUNK" 2>/dev/null)"
  [ "$rc" -eq 1 ] || cf "(control) exit $rc, expected 1: $(printf '%s' "$out" | tail -4 | tr '\n' '|')"
  printf '%s\n' "$out" | grep -F 'Sandbox Test [Dev] local unpushed' >/dev/null || cf "(control) the board worktree built from local trunk work did not list the commit: $(printf '%s' "$out" | tail -6 | tr '\n' '|' | cut -c1-400)"
  git -C "$SB_WORK" log "origin/$SB_TRUNK..$SB_TRUNK" --format=%s | grep -Fx '[Dev] local unpushed' >/dev/null \
    || cf "(control) the command the Next: should name does not list the commit in the main checkout"
  nxt="$(printf '%s\n' "$out" | sed -n '/^Next:/,$p')"
  printf '%s\n' "$nxt" | grep -F "git log origin/$SB_TRUNK..$SB_TRUNK" >/dev/null || cf "(a) the Next: does not name 'git log origin/$SB_TRUNK..$SB_TRUNK' as the way to recognise local trunk work"
  printf '%s\n' "$nxt" | grep -F 'main checkout' >/dev/null || cf "(a) the Next: does not name the main checkout"
  printf '%s\n' "$nxt" | grep -F 'never through this worktree' >/dev/null || cf "(a) the Next: does not say local trunk work is not published through the worktree"
  # The local-work sentence is conditional: the tool does not publish it, its maker does when ready,
  # and anyone else asks. A hand-made card move sits in the same list, and "publish it" published one.
  printf '%s\n' "$nxt" | grep -F "not this tool's to publish" >/dev/null || cf "(c) the Next: does not say local trunk work is not this tool's to publish"
  printf '%s\n' "$nxt" | grep -F 'when it is ready' >/dev/null || cf "(c) the Next: does not leave the timing to the person who made it"
  printf '%s\n' "$nxt" | grep -F 'publish it from the main checkout' >/dev/null && cf "(c) the Next: still tells the reader, unconditionally, to publish it from the main checkout"
  printf '%s\n' "$nxt" | grep -F 'main checkout' | grep -F -- '--default "leave them and stop"' >/dev/null \
    || cf "(c) the local-work sentence carries no ask for a reader who did not make the commit: $(printf '%s' "$nxt" | grep -F 'main checkout' | tr '\n' '|' | cut -c1-300)"
  [ "$o0" = "$o1" ] || cf "(b) the refused move reached the trunk"
  finish "a board worktree built from an unpushed local-trunk commit is refused with the commit listed, the command that lists it in the main checkout, and a send-it-from-the-main-checkout instruction; nothing reaches the trunk"
  teardown
}

# =============================================================================
# CASE — A PUSH THAT FAILS ON AN UNREACHABLE REMOTE NAMES THE COMMITS THAT DID NOT LAND, AND SAYS
# SO WHEN IT CANNOT LIST THEM.
# git_push_with_retry fetches first and stops when the fetch fails. The board's refusal over
# unpushed commits tells a reader to publish only what a failed op named, so that failure must carry
# the list; where the remote ref is missing the list cannot be computed and an empty list would read
# as "none".
# =============================================================================
case_push_retry_unreachable_remote_names_the_unlanded_commits() {
  cf_reset
  make_sandbox
  local out rc me="case_push_retry_unreachable_remote_names_the_unlanded_commits"
  _pr() { ( cd "$SB_WORK" && bash -c '. scripts/lib/push-retry.sh; git_push_with_retry "$PWD" origin "$1"' _ "$SB_TRUNK" 2>&1 ); }

  # (a) the remote answers but has no such branch: the list cannot be computed.
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "[PM] seed" >/dev/null 2>&1 || _fixture_die "$me: could not make the seed commit"
  git -C "$SB_WORK" remote add origin "$SB_ORIGIN" >/dev/null 2>&1
  rc=0; out="$(_pr)" || rc=$?
  [ "$rc" -eq 1 ] || cf "(a control) exit $rc, expected 1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -F 'Commits that did NOT land' >/dev/null || cf "(a control) the failure carries no 'Commits that did NOT land' header: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  printf '%s\n' "$out" | grep -F "(cannot list: no origin/$SB_TRUNK ref)" >/dev/null \
    || cf "(a) a list that cannot be computed is printed as an empty one: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"

  # (b) the remote ref is known, the remote is then unreachable: the list names the commit.
  git -C "$SB_WORK" push -q -u origin "$SB_TRUNK" >/dev/null 2>&1 || _fixture_die "$me: could not publish the seed"
  MSG_OK=1 git -C "$SB_WORK" commit -q --allow-empty -m "[Dev] offline try" >/dev/null 2>&1 || _fixture_die "$me: could not make the commit"
  git -C "$SB_WORK" remote set-url origin "$SB_TMP/no-such-remote.git" >/dev/null 2>&1
  rc=0; out="$(_pr)" || rc=$?
  [ "$rc" -eq 1 ] || cf "(b control) exit $rc, expected 1"
  printf '%s\n' "$out" | sed -n '/Commits that did NOT land/,$p' | grep -F '[Dev] offline try' >/dev/null \
    || cf "(b) the unreachable-remote failure does not name the commit that did not land: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  finish "git_push_with_retry's unreachable-remote failure lists the commits that did not land, and says so when the remote ref is missing and the list cannot be computed"
  teardown
}

# =============================================================================
# CASE — A CLOSED OUTPUT PIPE DOES NOT STOP A BOARD OP BETWEEN ITS COMMIT AND ITS PUSH.
# An agent that reads `<op> | head -1` closes the op's stdout after one line. The op's later writes
# then fail, and under `set -e` that ends it with the move committed in the board worktree and not
# pushed; the next op is refused over the unpushed commit. Each of the five ops that commit to the
# board worktree (the four movers and archive.sh) is piped into a reader that closes (`head -1`; for
# archive.sh one that closes just before its commit) and must publish its move
# and leave nothing unpushed. Ignoring SIGPIPE alone does not hold it: the `echo` to a closed pipe
# then fails with EPIPE and `set -e` ends the script on the same line, so the last rows close stdout
# alone and stderr alone on a stub that is not the op, to keep the two streams' guards apart. Three
# more shapes of caller: a signal to the whole process group (the drain dies with the op), a stdout
# that was closed outright (`>&-`), and a socket in place of a pipe (a Node harness's stdio).
# =============================================================================
case_a_board_op_whose_output_pipe_closes_still_publishes_its_move() {
  cf_reset
  make_sandbox
  local p="$SB_PREFIX-340" me="case_a_board_op_whose_output_pipe_closes_still_publishes_its_move"
  local wt="$SB_WORK/.kanban-wt" out rc subtasks=1 unpushed errf="$SB_TMP/closed-pipe.err"
  seed_issue todo "$SB_PREFIX-341" sandbox chore "Closed pipe one"
  seed_issue todo "$SB_PREFIX-342" sandbox chore "Closed pipe two"
  seed_issue todo "$SB_PREFIX-343" sandbox chore "Closed pipe three"
  seed_issue dev_complete "$SB_PREFIX-344" sandbox chore "Closed pipe landing" "feature/$SB_PREFIX-344-work"
  seed_issue qa_complete "$SB_PREFIX-346" sweep chore "Closed pipe sweep"
  seed_issue todo "$SB_PREFIX-347" sandbox chore "Closed pipe stdout closed"
  seed_issue todo "$SB_PREFIX-348" sandbox chore "Closed pipe socket"
  if has_issue_template; then
    _seed_parent "$p"
    _seed_subtask "$p" s1 todo slice "A slice under the closed pipe" >/dev/null
  else
    subtasks=0
  fi
  publish_sandbox
  seed_branch "$SB_PREFIX-344" work CHANGE.txt
  _unpushed() {  # what the board worktree holds that origin does not
    [ -d "$wt" ] || { printf ''; return 0; }
    git -C "$wt" fetch -q origin >/dev/null 2>&1 || true
    git -C "$wt" log "origin/$SB_TRUNK..HEAD" --format=%s 2>/dev/null || true
  }
  _row() {  # <label> <path the op puts on origin>
    unpushed="$(_unpushed)"
    [ -z "$unpushed" ] || cf "($1) the op left a commit in the board worktree that origin does not have: $(printf '%s' "$unpushed" | tr '\n' '|' | cut -c1-200)"
    origin_has_path "$2" || cf "($1) the op's move is not on origin ($2)"
  }

  # (a) move-issue.sh, stdout and stderr joined, read by `head -1` (an agent's usual shape).
  ( cd "$SB_WORK" && ./scripts/move-issue.sh "$SB_PREFIX-341" in_progress --role Dev --note piped 2>&1 | head -1 ) >/dev/null 2>&1 || true
  _row "a move-issue" "progress/in_progress/$SB_PREFIX-341-sandbox.md"
  # (a2) and the next move is not refused over an unpushed commit.
  rc=0; out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$SB_PREFIX-342" in_progress --role Dev --note after 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(a2 the next move) exit $rc, expected 0: $(printf '%s' "$out" | tail -3 | tr '\n' '|' | cut -c1-300)"
  _row "a2 the next move" "progress/in_progress/$SB_PREFIX-342-sandbox.md"

  # (b) move-issue.sh with stdout alone read by `head -1` and stderr kept in a file.
  ( cd "$SB_WORK" && ./scripts/move-issue.sh "$SB_PREFIX-343" in_progress --role Dev --note piped 2>"$errf" | head -1 ) >/dev/null 2>&1 || true
  _row "b move-issue, stdout only" "progress/in_progress/$SB_PREFIX-343-sandbox.md"

  # (c) register-commit.sh.
  mkdir -p "$SB_WORK/progress/todo"
  printf 'a new card\n' > "$SB_WORK/progress/todo/$SB_PREFIX-345-closed-pipe.md"
  ( cd "$SB_WORK" && env -u MSG_OK ./scripts/register-commit.sh --role PM --message "$SB_PREFIX-345: mint" "progress/todo/$SB_PREFIX-345-closed-pipe.md" 2>&1 | head -1 ) >/dev/null 2>&1 || true
  _row "c register-commit" "progress/todo/$SB_PREFIX-345-closed-pipe.md"

  # (d) subtask.sh.
  if [ "$subtasks" = 1 ]; then
    ( cd "$SB_WORK" && ./scripts/subtask.sh move "${p}-s1" in_progress --role Dev --note piped 2>&1 | head -1 ) >/dev/null 2>&1 || true
    _row "d subtask" "progress/subtasks/${p}/in_progress/${p}-s1-slice.md"
  fi

  # (g) archive.sh: it commits the sweep in the board worktree and pushes it. Its preview ends at
  # "And move …", after which nothing is written until the commit, so a reader that closes there
  # (not one that counts lines, which closes inside the preview) kills it between commit and push.
  out="$( cd "$SB_WORK" && ./scripts/archive.sh --dry-run 2>&1 )" || true
  grep '^And move' <<<"$out" >/dev/null || cf "(g control) the dry-run preview has no 'And move' line, so the reader below would never close and the row proves nothing: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  ( cd "$SB_WORK" && ./scripts/archive.sh --apply 2>&1 | sed '/^And move/q' ) >/dev/null 2>&1 || true
  _row "g archive" "progress/done/$SB_PREFIX-346-sweep.md"

  # (e) finish-pr.sh: the squash is on the trunk, so the card must follow it.
  ( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-344" 2>&1 | head -1 ) >/dev/null 2>&1 || true
  _row "e finish-pr" "progress/qa_complete/$SB_PREFIX-344-sandbox.md"

  # (f) the guard itself, on a stub that writes after its pipe closes: stdout alone, stderr alone,
  # then both. The stub reaches its last line only if no write ended it.
  local stub="$SB_TMP/closed-pipe-stub.sh" mark="$SB_TMP/closed-pipe.reached" o2="$SB_TMP/closed-pipe.out"
  {
    printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' "cd '$SB_WORK' || exit 1"
    printf '%s\n' ". scripts/lib/kanban-worktree.sh" "kwt_hold_output" \
      "echo first" "sleep 1" "echo second" "echo third >&2" "sleep 1" "echo fourth" "echo fifth >&2" "sleep 1" "echo sixth" ": > \"\$1\""
  } > "$stub"
  rm -f "$mark"; /bin/bash "$stub" "$mark" 2>"$errf" | head -1 >/dev/null 2>&1 || true
  [ -f "$mark" ] || cf "(f1) a stub whose stdout closed after one line was ended by a later write"
  rm -f "$mark"; /bin/bash "$stub" "$mark" 2> >(head -c 1 >/dev/null 2>&1) >"$o2" || true
  [ -f "$mark" ] || cf "(f2) a stub whose stderr closed after one byte was ended by a later write"
  rm -f "$mark"; /bin/bash "$stub" "$mark" 2>&1 | head -1 >/dev/null 2>&1 || true
  [ -f "$mark" ] || cf "(f3) a stub whose joined stdout and stderr closed after one line was ended by a later write"
  # The stub's output still arrives whole and in order when nothing closes.
  out="$(/bin/bash "$stub" "$mark" 2>&1)" || true
  [ "$out" = "$(printf 'first\nsecond\nthird\nfourth\nfifth\nsixth')" ] || cf "(f4) an open pipe's output is not whole and in order: $(printf '%s' "$out" | tr '\n' '|')"

  # (h) a signal to the whole process group takes the drain with the op. The op must still end of
  # that signal, with its exit trap's output written, not of a SIGPIPE on that output. The driver
  # runs the op in its own group, reads one line, then signals the group and keeps reading.
  local drv="$SB_TMP/closed-pipe-driver.pl" stub2="$SB_TMP/closed-pipe-stub2.sh"
  cat > "$drv" <<'PERL_EOF'
use strict; use warnings; use Socket;
my ($mode, $kind, $dir, @cmd) = @ARGV;   # mode: close1 | groupterm ; kind: pipe | socket
my ($r, $w);
if ($kind eq 'socket') { socketpair($r, $w, AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair: $!"; }
else { pipe($r, $w) or die "pipe: $!"; }
my $pid = fork(); die "fork: $!" unless defined $pid;
if (!$pid) {
  setpgrp(0, 0) if $mode eq 'groupterm';
  close $r;
  open(STDOUT, '>&', $w) or die; open(STDERR, '>&', $w) or die;
  close $w;
  chdir $dir or die "chdir: $!";
  exec @cmd or die "exec: $!";
}
close $w;
my $first = <$r>;
if ($mode eq 'close1') { close $r; }
else { select(undef, undef, undef, 1.0); kill 'TERM', -$pid; 1 while defined(<$r>); close $r; }
waitpid($pid, 0);
my $st = $?;
print(($st & 127) ? "signal " . ($st & 127) . "\n" : "exit " . ($st >> 8) . "\n");
PERL_EOF
  {
    printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' "cd '$SB_WORK' || exit 1" ". scripts/lib/exit-trap.sh" ". scripts/lib/kanban-worktree.sh" "kwt_hold_output" \
      "kit_on_exit 'sleep 0.3; echo cleanup; : > \"$mark\"'" "echo first" "sleep 5" "echo never"
  } > "$stub2"
  rm -f "$mark"; out="$(perl "$drv" groupterm pipe "$SB_WORK" /bin/bash "$stub2" "$mark" 2>&1)" || true
  [ "$out" = "signal 15" ] || cf "(h1) a TERM to the op's whole process group ended it as '$out', want 'signal 15' (the drain died with it, and the op's next write was a SIGPIPE)"
  [ -f "$mark" ] || cf "(h2) a TERM to the op's whole process group stopped its exit trap before its output was written"

  # (i) a stdout closed outright (`>&-`) is not a pipe: the write fails with EBADF, not EPIPE.
  ( cd "$SB_WORK" && ./scripts/move-issue.sh "$SB_PREFIX-347" in_progress --role Dev --note closed >&- ) >/dev/null 2>&1 || true
  _row "i move-issue, stdout closed" "progress/in_progress/$SB_PREFIX-347-sandbox.md"
  rm -f "$mark"; /bin/bash "$stub" "$mark" >&- 2>&- || true
  [ -f "$mark" ] || cf "(i2) a stub run with stdout and stderr both closed outright was ended by a later write"

  # (j) a socket in place of a pipe, as a Node harness gives a child's stdio; the reader closes it
  # after one line.
  out="$(perl "$drv" close1 socket "$SB_WORK" ./scripts/move-issue.sh "$SB_PREFIX-348" in_progress --role Dev --note socket 2>&1)" || true
  [ "$out" = "exit 0" ] || cf "(j control) a move whose stdio is a socket ended as '$out', want 'exit 0'"
  _row "j move-issue, socket stdio" "progress/in_progress/$SB_PREFIX-348-sandbox.md"

  finish "each board op piped into head -1 publishes its move and leaves nothing unpushed, the next move is not refused, and a write to a closed stdout or stderr, a stdout that was closed outright, a socket, or a signal to the whole process group cannot end an op"
  teardown
}

# =============================================================================
# CASE — THE OTHER BOARD-WORKTREE REFUSALS HOLD THE LINE: UNCOMMITTED CHANGES ASK BEFORE THEY OFFER
# THE PUSH, AND THE NO-REMOTE LISTING NAMES AUTHORS.
# A board op leaves uncommitted changes in the board worktree only when it failed mid-write, so the
# refusal over them (detached, and attached) says that and asks first; "keep them — commit and push"
# is conditional and says it publishes unchecked. An attached branch with no remote counterpart lists
# its last commits with their authors.
# =============================================================================
case_dirty_and_no_remote_refusals_ask_first_and_name_authors() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-326" sandbox chore "Dirty refusals"
  seed_issue todo "$SB_PREFIX-327" sandbox chore "Dirty refusals second"
  publish_sandbox
  local out rc wt nxt aline pline me="case_dirty_and_no_remote_refusals_ask_first_and_name_authors" card
  wt="$SB_WORK/.kanban-wt"
  ( cd "$SB_WORK" && ./scripts/move-issue.sh "$SB_PREFIX-326" in_progress --role Dev --note warm ) >/dev/null 2>&1 \
    || _fixture_die "$me: the warm-up move failed"
  card="$wt/progress/in_progress/$SB_PREFIX-326-sandbox.md"
  [ -f "$card" ] || _fixture_die "$me: the warmed card is not where the dirty edit goes"
  _next() { rc=0; out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$SB_PREFIX-327" in_progress --role Dev --note second 2>&1 )" || rc=$?; nxt="$(printf '%s\n' "$out" | sed -n '/^Next:/,$p')"; }
  _dirty_rows() {
    [ "$rc" -eq 1 ] || cf "($1) exit $rc, expected 1: $(printf '%s' "$out" | tail -3 | tr '\n' '|')"
    printf '%s\n' "$nxt" | grep -F 'failed mid-write' >/dev/null || cf "($1) the Next: does not say an op leaves uncommitted changes only when it failed mid-write: $(printf '%s' "$nxt" | tr '\n' '|' | cut -c1-300)"
    printf '%s\n' "$nxt" | grep -F 'unchecked' >/dev/null || cf "($1) the Next: does not say that keeping them publishes unchecked"
    aline="$(printf '%s\n' "$nxt" | awk '/ask\.sh/{print NR; exit}')"; pline="$(printf '%s\n' "$nxt" | awk '/commit -m/{print NR; exit}')"
    [ -n "$aline" ] && [ -n "$pline" ] && [ "$aline" -lt "$pline" ] || cf "($1) the ask (line '${aline:-none}') does not come before the commit-and-push command (line '${pline:-none}')"
    printf '%s\n' "$nxt" | grep -F -- '--default "leave them and stop"' >/dev/null || cf "($1) the ask does not default to leaving them"
  }

  # (a) detached, a tracked file edited.
  printf '\nstray edit\n' >> "$card"
  _next
  printf '%s\n' "$out" | grep -F 'uncommitted tracked changes — refusing to sync' >/dev/null || cf "(a control) not the detached dirty refusal: $(printf '%s' "$out" | tail -3 | tr '\n' '|')"
  _dirty_rows "a sync-dirty"
  git -C "$wt" checkout -q -- . >/dev/null 2>&1

  # (b) attached, a tracked file edited.
  git -C "$wt" switch -q -c side-dirty >/dev/null 2>&1 || _fixture_die "$me: could not attach the board worktree"
  printf '\nstray edit\n' >> "$card"
  _next
  printf '%s\n' "$out" | grep -F 'ATTACHED to' >/dev/null || cf "(b control) not the attached dirty refusal: $(printf '%s' "$out" | tail -3 | tr '\n' '|')"
  _dirty_rows "b attached-dirty"
  git -C "$wt" checkout -q -- . >/dev/null 2>&1
  git -C "$wt" switch -q --detach >/dev/null 2>&1; git -C "$wt" branch -q -D side-dirty >/dev/null 2>&1

  # (c) attached to a branch with no remote counterpart: the last commits carry their authors.
  git -C "$wt" switch -q -c side-lonely >/dev/null 2>&1 || _fixture_die "$me: could not attach the board worktree to a lonely branch"
  MSG_OK=1 git -C "$wt" commit -q --allow-empty --author="Some Other Person <other@sandbox.invalid>" -m "[Dev] a stranger's commit" >/dev/null 2>&1 \
    || _fixture_die "$me: could not make the commit on the lonely branch"
  _next
  printf '%s\n' "$out" | grep -F 'CANNOT BE DETERMINED' >/dev/null || cf "(c control) not the no-remote refusal: $(printf '%s' "$out" | tail -3 | tr '\n' '|')"
  printf '%s\n' "$out" | grep -F "Some Other Person [Dev] a stranger's commit" >/dev/null \
    || cf "(c) the listing does not give the last commit's author and subject: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"
  finish "the refusals over uncommitted changes, detached and attached, say an op leaves them only when it failed mid-write, ask before they offer commit-and-push, and say keeping them publishes unchecked; the no-remote refusal lists its last commits with their authors"
  teardown
}

# =============================================================================
# CASE — THE BOOTSTRAP REFUSAL'S Next: NAMES THE TRUNK, NEVER `set-head -a`.
# `-a` asks the remote to guess its own default branch, which is the guess the kit teaches against
# everywhere else it names a trunk. A repository with no commit and no remote cannot create the
# board worktree, so the refusal fires; its Next: must send the operator to set the trunk by name.
# =============================================================================
case_bootstrap_failure_next_names_the_trunk_not_set_head_a() {
  cf_reset
  make_sandbox
  local out rc
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$SB_PREFIX-1" in_progress --role Dev --note x 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(control) the move succeeded on a repository with no commit: $out"
  printf '%s\n' "$out" | grep 'failed to bootstrap kanban worktree' >/dev/null \
    || cf "(control) the bootstrap refusal did not fire, so its Next: is unread: $out"
  printf '%s\n' "$out" | grep -E 'remote set-head [^ ]+ -a' >/dev/null \
    && cf "the bootstrap refusal's Next: recommends set-head -a: $(printf '%s\n' "$out" | grep 'Next:')"
  printf '%s\n' "$out" | grep 'Next:' | grep -F 'remote set-head origin <your-trunk>' >/dev/null \
    || cf "the bootstrap refusal's Next: does not name 'remote set-head origin <your-trunk>': $(printf '%s\n' "$out" | grep 'Next:')"
  finish "the bootstrap refusal's Next: sets the trunk by name (set-head origin <your-trunk>), never -a"
  teardown
}

# =============================================================================
# CASE — THE TRUNK FALLBACK IS LOUD. With no <remote>/HEAD and no init.defaultBranch, the
# chain reaches its last-resort literal. The chain is kept (a hard refusal would break every
# read-only caller); each fallback step must SAY which step it used.
# =============================================================================
case_trunk_fallback_warns() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-310" sandbox chore "Trunk fallback"
  publish_sandbox
  local last_resort
  last_resort="$(sed -n 's/^KWT_TRUNK_LAST_RESORT="\${KWT_TRUNK_LAST_RESORT:-\([^}]*\)}"/\1/p' \
                   "$SB_WORK/scripts/lib/kanban-worktree.sh" | head -1)"
  [ -n "$last_resort" ] || cf "could not derive KWT_TRUNK_LAST_RESORT from the library"

  # Step 2: no <remote>/HEAD, but init.defaultBranch is set. <remote>/HEAD is a SYMBOLIC ref:
  # `update-ref -d` leaves it in place, `symbolic-ref -d` removes it.
  git -C "$SB_WORK" symbolic-ref -d refs/remotes/origin/HEAD >/dev/null 2>&1 || true
  local out
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-310" in_progress \
            --role Dev --note "fallback step 2" 2>&1 )"
  printf '%s' "$out" | grep 'STEP 2' >/dev/null \
    || cf "the init.defaultBranch fallback did not name the step it used: $out"
  printf '%s' "$out" | grep 'remote set-head' >/dev/null \
    || cf "the step-2 warning does not name the one command that settles it: $out"

  # Step 3: neither is set → the last-resort literal, named as a GUESS.
  git -C "$SB_WORK" symbolic-ref -d refs/remotes/origin/HEAD >/dev/null 2>&1 || true
  git -C "$SB_WORK" config --unset init.defaultBranch >/dev/null 2>&1 || true
  out="$( cd "$SB_WORK" && no_machine_git_config "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-310" dev_complete \
            --role Dev --note "fallback step 3" 2>&1 )"
  printf '%s' "$out" | grep 'GUESS' >/dev/null \
    || cf "the last-resort fallback did not announce itself as a guess: $out"
  printf '%s' "$out" | grep -F "$last_resort" >/dev/null \
    || cf "the last-resort warning does not name the literal it used ($last_resort): $out"

  finish "the trunk fallback chain WARNS at every step below the first, and names the literal it guessed"
  teardown
}

# =============================================================================
# CASE — THE MOVER REFUSES A DECLINE WITH NO RECORDED WHY.
#
# The reasoning is the entire value of a declined card: a parked card's blocker can be
# rediscovered, a refusal's argument cannot. A decline with no recorded why is a deletion.
#
# BOTH DIRECTIONS, because a refusal that also refuses the legal call is not a guard,
# it is a broken target:
#   (i)  `declined` with NO --note → refused, nonzero, and the card does not move;
#   (ii) `declined` WITH a --note  → lands, on the trunk, with the reason in the file.
# =============================================================================
case_move_issue_declined_requires_a_reason() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-260" no-reason   chore "Declined without a reason"
  seed_issue todo "$SB_PREFIX-261" with-reason chore "Declined with a reason"
  publish_sandbox

  local out rc

  # --- (i) the refusal --------------------------------------------------------
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-260" declined \
            --role PM 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] \
    || cf "(i) a decline with NO --note was ACCEPTED (exit $rc) — the column would fill with titles nobody can act on: $out"
  printf '%s\n' "$out" | grep -i 'note' >/dev/null \
    || cf "(i) the refusal does not name --note as the thing that is missing, so it does not tell the operator what to do: $out"
  # THE REFUSAL MUST NOT HAVE MOVED ANYTHING. A guard that refuses after acting is
  # worse than no guard, because the operator believes nothing happened.
  origin_has_path "progress/declined/$SB_PREFIX-260-no-reason.md" \
    && cf "(i) the refusal still published the move — the card reached declined/ on the trunk without a reason"
  origin_has_path "progress/todo/$SB_PREFIX-260-no-reason.md" \
    || cf "(i) the card left todo/ on the trunk even though the move was refused"

  # --- (ii) THE ABLATION DIRECTION: the legal call must still work -------------
  # Without this half, deleting the `declined` target entirely would pass (i).
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-261" declined \
            --role PM --note "Refused: the cost lands on every reader and the benefit on one." 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] \
    || cf "(ii) a decline WITH a reason was refused (exit $rc) — the guard is refusing the legal call, not the reasonless one: $out"
  origin_has_path "progress/declined/$SB_PREFIX-261-with-reason.md" \
    || cf "(ii) the card did not reach progress/declined/ on the trunk"
  origin_file_contains "progress/declined/$SB_PREFIX-261-with-reason.md" "the cost lands on every reader" \
    || cf "(ii) the REASON is not in the card on the trunk — the whole point of the column"
  origin_log_has_subject "\[PM\] $SB_PREFIX-261 → declined" \
    || cf "(ii) the move was not published to the trunk as its own commit"

  finish "move-issue.sh: a decline with NO --note is refused and moves nothing, and a decline WITH one lands on the trunk carrying its reason"
  teardown
}

case_kwt_file_mtime_is_one_epoch_number() {
  cf_reset
  make_sandbox
  # The stale-claim age is `date +%s` minus this. On a platform where the first stat form is another option (GNU's
  # `stat -f` is filesystem status), a wrong order prints a block of text and the subtraction is a syntax error.
  local f="$SB_TMP/mtime-probe" got
  : > "$f"; TZ=UTC touch -t 202001010000.00 "$f"
  got="$( . "$SB_WORK/scripts/lib/kanban-worktree.sh" >/dev/null 2>&1; kwt__mtime "$f" )"
  [ "$got" = 1577836800 ] || cf "kwt__mtime of a file stamped 2020-01-01T00:00:00Z printed [$(printf '%s' "$got" | tr '\n' '|')], not 1577836800"
  got="$( . "$SB_WORK/scripts/lib/kanban-worktree.sh" >/dev/null 2>&1; kwt__mtime "$SB_TMP/no-such-file" )"
  [ "$got" = 0 ] || cf "kwt__mtime of a file that is not there printed [$(printf '%s' "$got" | tr '\n' '|')], not 0"
  finish "kanban-worktree.sh's file-mtime helper prints one epoch number for a file and 0 for none, so a stale claim's age is arithmetic on every platform"
  teardown
}

# =============================================================================
# CASE — THE AUXILIARY WORKTREE'S DIRTY GUARD: REPORTS WIDELY, REFUSES NARROWLY.
#
# The guard's `status --porcelain -uno` is correct and must NOT be "fixed": it scopes a
# DESTRUCTION guard to what `reset --hard` destroys, which leaves untracked files alone. But
# the worktree's HEAD and push target are the trunk, so the printed keep-your-work remedy must
# be scoped to progress/ (never a blanket `git add -A`), and the REPORT must also list the
# untracked paths such a recipe would commit. The REFUSAL stays narrow: leg (ii) holds that an
# untracked file alone does not block a board operation.
# =============================================================================
case_kwt_dirty_guard_reports_widely_refuses_narrowly() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-400" alpha chore "Guard alpha"
  seed_issue todo "$SB_PREFIX-401" beta  chore "Guard beta"
  publish_sandbox

  # One real board op, to bootstrap the auxiliary worktree.
  local out rc=0
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-400" in_progress \
            --role Dev --note "bootstrap the worktree" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(setup) the bootstrapping board move failed, so nothing below is about the guard: $(printf '%s' "$out" | tr '\n' '|')"
  local kwt="$SB_WORK/.kanban-wt"
  [ -d "$kwt" ] \
    || _fixture_die "case_kwt_dirty_guard_reports_widely_refuses_narrowly: no .kanban-wt/ after a board move — the guard under test lives there and this case cannot reach it."

  # --- (i) TRACKED dirt + an untracked stray: refuses, and reports BOTH ------
  local tracked_card; tracked_card="$(git -C "$kwt" ls-files 'progress/*' | head -1)"
  [ -n "$tracked_card" ] \
    || _fixture_die "case_kwt_dirty_guard_reports_widely_refuses_narrowly: no tracked file under progress/ in the worktree to dirty."
  printf '\nstray edit\n' >> "$kwt/$tracked_card"
  printf 'a distribution payload\n' > "$kwt/STRAY-PAYLOAD.txt"
  [ -n "$(git -C "$kwt" status --porcelain --untracked-files=no)" ] \
    || _fixture_die "case_kwt_dirty_guard_reports_widely_refuses_narrowly: the tracked edit did not register as dirty — the refusal below would not fire and the case would prove nothing."

  rc=0
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-401" in_progress \
            --role Dev --note "should refuse" 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(i) a board op proceeded with TRACKED changes in the auxiliary worktree"
  # THE REMEDY IS SCOPED. Both halves: the narrow form present, the blanket form absent.
  printf '%s\n' "$out" | grep -- "add -- progress/" >/dev/null \
    || cf "(i) the printed remedy is not scoped to progress/: $(printf '%s' "$out" | tr '\n' '|')"
  # `add -A &&`, the RECIPE shape: the refusal warns about `add -A` in prose, so a bare match
  # would find the warning.
  printf '%s\n' "$out" | grep -- "add -A &&" >/dev/null \
    && cf "(i) the printed remedy STILL offers a blanket 'add -A' recipe in a worktree that pushes to the trunk: $(printf '%s' "$out" | tr '\n' '|')"
  # THE UNTRACKED STRAY IS REPORTED, and labelled as not being the refusal's subject.
  printf '%s\n' "$out" | grep 'STRAY-PAYLOAD.txt' >/dev/null \
    || cf "(i) the untracked file the remedy would have committed is not reported at all — the guard still cannot see half of what it would commit: $(printf '%s' "$out" | tr '\n' '|')"
  printf '%s\n' "$out" | grep -i 'untracked' >/dev/null \
    || cf "(i) the untracked paths are listed without being labelled as untracked, so a reader cannot tell them from the tracked changes that caused the refusal: $(printf '%s' "$out" | tr '\n' '|')"

  # --- (ii) UNTRACKED ONLY: must NOT refuse. This is "refuses narrowly", and it
  #     is the assertion that stops a future editor widening the trigger.
  git -C "$kwt" checkout -- "$tracked_card"
  [ -z "$(git -C "$kwt" status --porcelain --untracked-files=no)" ] \
    || _fixture_die "case_kwt_dirty_guard_reports_widely_refuses_narrowly: the tracked edit did not revert, so leg (ii) would be measuring the tracked case again."
  [ -f "$kwt/STRAY-PAYLOAD.txt" ] \
    || _fixture_die "case_kwt_dirty_guard_reports_widely_refuses_narrowly: the untracked stray is gone, so leg (ii) proves nothing about untracked files."
  rc=0
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-401" in_progress \
            --role Dev --note "untracked only — must proceed" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] \
    || cf "(ii) an UNTRACKED file alone blocked a board operation — the refusal widened past what a reset destroys, and every stray editor dropping is now an outage: $(printf '%s' "$out" | tr '\n' '|')"
  origin_has_path "progress/in_progress/$SB_PREFIX-401-beta.md" \
    || cf "(ii) the board op exited 0 but the card did not reach the trunk — it did not actually run"

  finish "kanban worktree dirty guard: TRACKED dirt refuses and the report ALSO lists the untracked paths the remedy would commit (labelled), the remedy is scoped to progress/ and no longer offers a blanket add -A, and an untracked file ALONE does not block a board operation"
  teardown
}

# =============================================================================
# CASE — THE MOVER LEAVES A DIRTY MAIN CHECKOUT BYTE-IDENTICAL.
#
# The mover never switches the operator's checkout, and its only `reset --hard` is scoped to
# the kanban worktree, so a loose edit is not destroyed. The real hazard is STRANDING: the move
# commits a `git mv` on the trunk while the edit sits at the OLD path, and the next pull
# collides. Asserted on the file's bytes and HEAD, not on what any document says.
# =============================================================================
case_move_issue_leaves_a_dirty_checkout_alone() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-101" strand chore "Stranding probe"
  publish_sandbox

  local card="$SB_WORK/progress/todo/$SB_PREFIX-101-strand.md" before_hash before_head out rc=0
  [ -f "$card" ] \
    || _fixture_die "case_move_issue_leaves_a_dirty_checkout_alone: the seeded card is not in the checkout — there is nothing to leave alone."
  printf '\nan uncommitted edit the operator has not saved anywhere else\n' >> "$card"
  before_hash="$( { shasum "$card" 2>/dev/null || sha256sum "$card"; } | awk '{print $1}')"
  before_head="$(git -C "$SB_WORK" rev-parse HEAD)"
  [ -n "$before_hash" ] && [ -n "$before_head" ] \
    || _fixture_die "case_move_issue_leaves_a_dirty_checkout_alone: could not record the pre-state."
  # INSTRUMENT: the checkout must actually BE dirty, or the assertions below hold trivially.
  [ -n "$(git -C "$SB_WORK" status --porcelain -- "progress/todo/$SB_PREFIX-101-strand.md")" ] \
    || _fixture_die "case_move_issue_leaves_a_dirty_checkout_alone: the edit did not register as dirty — every assertion below would pass over a clean tree."

  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-101" in_progress \
            --role Dev --note "moved while the checkout is dirty" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "the mover failed with a dirty main checkout (rc=$rc) — its contract says that state is irrelevant to it: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # THE MOVE LANDED — otherwise "nothing was touched" is satisfied by a mover that did nothing.
  origin_has_path "progress/in_progress/$SB_PREFIX-101-strand.md" \
    || cf "the card did not reach in_progress/ on the trunk — the mover did not run, so the assertions below prove nothing"

  # …AND THE OPERATOR'S FILE IS UNTOUCHED, byte for byte.
  [ -f "$card" ] \
    || cf "the operator's uncommitted file was REMOVED from their checkout — the mover's contract is that it never touches it"
  [ "$( { shasum "$card" 2>/dev/null || sha256sum "$card" 2>/dev/null; } | awk '{print $1}')" = "$before_hash" ] \
    || cf "the operator's uncommitted edit was MODIFIED — the mover's contract is that it never touches it"
  [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$before_head" ] \
    || cf "the main checkout's HEAD moved — the mover fast-forwarded a checkout it promises never to switch"

  finish "move-issue.sh leaves a dirty main checkout byte-identical — the file, its bytes and HEAD all survive a move that lands on the trunk (the hazard is stranding at the old path, not destruction)"
  teardown
}

# =============================================================================
# CASE — A PARTIAL PREFIX DERIVATION REPORTS ITSELF PARTIAL, AND THE INITIALIZER
#        REFUSES THE VALUE THAT CAUSES ONE.
#
# kit-init must validate --prd-prefix as it does --prefix: a value like `REQ-2` is stamped,
# and the hygiene instrument's `([A-Za-z0-9]+)` pattern cannot read it. The instrument must
# then report id_prefixes_derived_from_seam FALSE, the flag a reader uses to tell a real zero
# from a blind one. Both arms: validation closes one route, the flag reports any other.
# =============================================================================
case_partial_prefix_derivation_says_so() {
  cf_reset
  make_sandbox
  local hy="$SB_WORK/scripts/hygiene/staleness_greps.py"
  if [ ! -f "$hy" ]; then
    skp "a partial prefix derivation reports itself partial" "scripts/hygiene/ is absent — it is the kit's deletable optional extra"
    teardown; return
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    skp "a partial prefix derivation reports itself partial" "python3 is not on PATH, and the kit does not require it"
    teardown; return
  fi

  local probe="$SB_TMP/prdprobe" out
  rm -rf "$probe"; mkdir -p "$probe/scripts"

  _prd_derived() {  # <config.sh body> -> "prefixes|True|False"
    printf '%s' "$1" > "$probe/scripts/config.sh"
    python3 - "$hy" "$probe" <<'PY'
import importlib.util, pathlib, sys
spec = importlib.util.spec_from_file_location('sg', sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
pat, derived = m._id_prefixes(pathlib.Path(sys.argv[2]))
print(f"{pat}|{derived}")
PY
  }

  # ── INSTRUMENT CHECK: BOTH keys readable must report derived. Without this, "partial
  #    reports False" is satisfied by a derivation that reports False for everything.
  out="$(_prd_derived 'ISSUE_PREFIX="${ISSUE_PREFIX:-KIT}"
PRD_PREFIX="${PRD_PREFIX:-PRD}"
')"
  case "$out" in
    *'|True') ;;
    *) cf "(instrument) a config.sh with BOTH keys readable reports '$out' — if a full read is not derived, the partial arm below proves nothing" ;;
  esac

  # THE ARM: one key readable, one not. Must report NOT derived, and must still use what
  # it read — a partial pattern finds some ids, and throwing it away would trade a
  # dishonest instrument for a blind one.
  out="$(_prd_derived 'ISSUE_PREFIX="${ISSUE_PREFIX:-KIT}"
PRD_PREFIX="${PRD_PREFIX:-REQ-2}"
')"
  case "$out" in
    *'|False') ;;
    *) cf "a config.sh where only ONE of the two prefix keys parses reports '$out' — a PARTIAL derivation claiming to be complete is this instrument's honesty flag asserting the opposite of the truth" ;;
  esac
  case "$out" in
    KIT'|'*) ;;
    *) cf "the partial derivation discarded the key it COULD read (got '$out') — reporting the gap is right, going blind on top of it is not" ;;
  esac

  unset -f _prd_derived

  # THE OTHER HALF: the initializer refuses the value that produces a partial read.
  if has_kit_init; then
    grep -q 'PRD_PREFIX_NEW' "$SB_WORK/scripts/kit-init.sh" \
      && grep -qE '^if \[ -n "\$PRD_PREFIX_NEW" \] && ! printf' "$SB_WORK/scripts/kit-init.sh" \
      || cf "kit-init.sh does not validate --prd-prefix the way it validates --prefix — the route that produces a partial derivation is still open, and only the flag above would catch it"
  fi

  finish "a config.sh where only one of the two prefix keys parses reports id_prefixes_derived_from_seam FALSE while still using the key it could read, a full read still reports TRUE, and kit-init refuses the --prd-prefix values that produce the partial case"
  teardown
}

# =============================================================================
# CASE — EVERY LINK BELOW THE FIRST SAYS SO, IN EVERY IMPLEMENTATION OF THE CHAIN.
#
# The trunk chain (<remote>/HEAD → init.defaultBranch → the kit's last-resort constant) is
# implemented in kwt_resolve, check-board.sh and release.sh, and cannot be one function:
# release.sh sources only the few libraries its top names from scripts/lib/ (its header says so). So the invariant is
# held here: every step below the first warns, in each. Step 2 is where a real cut lands,
# since a developer machine usually has init.defaultBranch set. The states are built by
# removal, starting from step 1.
# =============================================================================
case_trunk_chain_announces_every_fallback() {
  cf_reset
  if ! has_release; then skp "every link of the trunk chain below the first announces itself" "scripts/release.sh absent"; return; fi
  make_sandbox
  seed_release_files 1.1.0
  publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  local out rc

  # ── STEP 1: origin/HEAD is set. NOBODY announces anything. This is the instrument
  #    check for both arms below — a tool that announced here would satisfy them free.
  out="$(cb_run 2>&1)" || true
  printf '%s' "$out" | grep 'GUESSED' >/dev/null \
    && cf "(step 1) check-board announced a guess while $SB_TRUNK is set as origin/HEAD"
  out="$(run_release 1.1.0 --dry-run 2>&1)" || true
  printf '%s' "$out" | grep 'STEP 2 of the chain\|is a GUESS' >/dev/null \
    && cf "(step 1) release.sh announced a fallback while origin/HEAD is set"

  # ── STEP 2: drop origin/HEAD, set init.defaultBranch. BOTH must say so.
  git -C "$SB_WORK" symbolic-ref -d "refs/remotes/origin/HEAD" >/dev/null 2>&1 || true
  git -C "$SB_WORK" config init.defaultBranch "$SB_TRUNK"
  out="$(cb_run 2>&1)" || true
  printf '%s' "$out" | grep 'step 2' >/dev/null \
    || cf "(step 2) check-board resolved the trunk from init.defaultBranch and said nothing — every trunk arm below it is then a statement about a guessed name: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  out="$(run_release 1.1.0 --dry-run 2>&1)" || true
  printf '%s' "$out" | grep 'STEP 2 of the chain' >/dev/null \
    || cf "(step 2) release.sh cut against init.defaultBranch with no warning — the quieter half of the guessed-trunk defect, and the likelier one: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # ── STEP 3: drop init.defaultBranch too. BOTH must say so, and say it differently —
  #    the step-3 message must not be reachable while step 2 still has an answer.
  git -C "$SB_WORK" config --unset init.defaultBranch >/dev/null 2>&1 || true
  out="$(no_machine_git_config cb_run 2>&1)" || true
  printf '%s' "$out" | grep 'step 3' >/dev/null \
    || cf "(step 3) check-board fell to the last-resort constant and said nothing: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  out="$(no_machine_git_config run_release 1.1.0 --dry-run 2>&1)" || true
  printf '%s' "$out" | grep 'is a GUESS' >/dev/null \
    || cf "(step 3) release.sh fell to the last-resort constant with no warning: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # ── AND THE IMPLEMENTATIONS AGREE ON THE ANSWER. Derived from the library, so the expected
  #    value has one author.
  local last_resort
  last_resort="$(sed -n 's/^KWT_TRUNK_LAST_RESORT="\${KWT_TRUNK_LAST_RESORT:-\([^}]*\)}"/\1/p' \
                   "$SB_WORK/scripts/lib/kanban-worktree.sh" | head -1)"
  [ -n "$last_resort" ] \
    || _fixture_die "case_trunk_chain_announces_every_fallback: could not read the last-resort constant — the expected value would be empty and both arms below would pass on nothing."
  printf '%s' "$out" | grep -F "'$last_resort'" >/dev/null \
    || cf "release.sh's step-3 guess is not the library's constant '$last_resort' — the three implementations agree on the WARNING and not on the ANSWER"
  out="$(no_machine_git_config cb_run 2>&1)" || true
  # Read where check-board names the trunk — its source label, "origin/<trunk> @ <sha>" or
  # "(no origin/<trunk> ref)". A bare grep for the name matches the checkout's branch.
  printf '%s' "$out" | grep -F -e "read from: origin/$last_resort @" -e "(no origin/$last_resort ref)" >/dev/null \
    || cf "check-board's step-3 trunk is not the library's constant '$last_resort': $(printf '%s' "$out" | grep -m1 'read from:' | cut -c1-200)"

  finish "all three implementations of the trunk chain announce every link below the first — check-board at steps 2 and 3, release.sh at both — none of them announces at step 1, and both agree with the library on the step-3 constant"
  teardown
}

# =============================================================================
# CASE — THE TRUNK-CHAIN CASES REACH STEP 3 ON A MACHINE THAT SETS init.defaultBranch GLOBALLY.
# Step 3 of the chain is "neither origin/HEAD nor init.defaultBranch answers". Unsetting the
# repo-local key leaves the machine's global one in reach, and a case reading it sees step 2.
# Each case below runs with a HOME of this case's own whose .gitconfig sets the key, so the
# answer does not depend on the machine that runs the harness.
# =============================================================================
case_trunk_cases_reach_step_3_under_a_global_default_branch() {
  cf_reset
  local L="the trunk-chain cases reach step 3 while the global git config sets init.defaultBranch"
  local fake log c res ran="" skipped="" planted="machine-default"
  fake="$(mktemp -d)"; log="$(mktemp)"
  # The planted name is neither the sandbox's trunk nor the last-resort constant, so an answer
  # read from it cannot pass for either.
  printf '[init]\n\tdefaultBranch = %s\n' "$planted" > "$fake/.gitconfig"
  # INSTRUMENT CHECK: git reads the planted file as the global config. Without it every case
  # below would pass because the key was never in reach.
  [ "$(HOME="$fake" XDG_CONFIG_HOME="$fake" git config --global --get init.defaultBranch 2>/dev/null)" = "$planted" ] \
    || { rm -rf "$fake" "$log"; _fixture_die "case_trunk_cases_reach_step_3_under_a_global_default_branch: git does not read $fake/.gitconfig as the global config, so the key this case plants is not in reach."; }
  for c in case_trunk_fallback_warns case_trunk_chain_announces_every_fallback case_seam_shape_reformat_is_loud; do
    # A subshell: the inner case's PASS/FAIL/SKIP counts stay out of the run's, and are printed.
    res="$( export HOME="$fake" XDG_CONFIG_HOME="$fake"; trap teardown EXIT
            p0=$PASS f0=$FAIL s0=$SKIP
            "$c" >"$log" 2>&1
            printf '%s %s %s' "$((PASS-p0))" "$((FAIL-f0))" "$((SKIP-s0))" )"
    case "$res" in
      "1 0 0") ran="$ran ${c#case_}" ;;
      "0 0 1") skipped="$skipped ${c#case_}" ;;
      *) cf "$c, run with init.defaultBranch in the global config, recorded '$res' (PASS FAIL SKIP): $(grep -m1 'FAIL' "$log" | tr -d '\033' | cut -c1-700)" ;;
    esac
  done
  # The same key through GIT_CONFIG_GLOBAL, which wins over HOME: the helper must shut that out too.
  printf '[init]\n\tdefaultBranch = %s\n' "$planted" > "$fake/gcg"
  [ "$(HOME="$log.none" GIT_CONFIG_GLOBAL="$fake/gcg" git config --get init.defaultBranch 2>/dev/null)" = "$planted" ] \
    || { rm -rf "$fake" "$log"; _fixture_die "case_trunk_cases_reach_step_3_under_a_global_default_branch: git does not read GIT_CONFIG_GLOBAL, so the key this row plants is not in reach."; }
  c=case_trunk_fallback_warns
  res="$( export HOME="$fake" XDG_CONFIG_HOME="$fake" GIT_CONFIG_GLOBAL="$fake/gcg"; trap teardown EXIT
          p0=$PASS f0=$FAIL s0=$SKIP
          "$c" >"$log" 2>&1
          printf '%s %s %s' "$((PASS-p0))" "$((FAIL-f0))" "$((SKIP-s0))" )"
  case "$res" in
    "1 0 0"|"0 0 1") ;;
    *) cf "$c, run with init.defaultBranch in GIT_CONFIG_GLOBAL, recorded '$res' (PASS FAIL SKIP): $(grep -m1 'FAIL' "$log" | tr -d '\033' | cut -c1-700)" ;;
  esac
  rm -rf "$fake" "$log"
  if [ -z "$_cf" ] && [ -z "$ran" ]; then
    skp "$L" "every trunk-chain case skipped on this tree:$skipped"; return
  fi
  finish "$L — ran:$ran${skipped:+; skipped:$skipped}"
}

# =============================================================================
# CASE — a move to in_progress or dev_complete warns, never refuses, when a blocked_by card has
# not landed on the trunk; kit_card_list reads the list shapes a card carries.
# Expected strings are typed here, never derived from the card read.
# =============================================================================
case_move_issue_warns_on_an_unlanded_blocker() {
  cf_reset
  local L="move-issue.sh warns, without refusing, on an unlanded blocked_by card" lib="$REAL_REPO_ROOT/scripts/lib/card-field.sh" d row want got
  [ -f "$lib" ] || { skp "$L" "lib/card-field.sh is absent from this tree"; return; }
  # kit_card_list unit rows: <frontmatter lines, \n-separated> @@ <ids, space-separated>
  d="$(mktemp -d)"
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    want="${row#*@@}"; printf -- '---\nid: X-1\n%b\nforks: none\n---\nblocked_by: [X-9]\n' "${row%%@@*}" > "$d/c.md"
    got="$( . "$lib"; kit_card_list "$d/c.md" blocked_by | tr '\n' ' ' )"; got="${got% }"
    [ "$got" = "$want" ] || cf "kit_card_list: '${row%%@@*}' returned '$got', want '$want'"
  done <<'ROWS'
blocked_by: [X-2, X-3]@@X-2 X-3
blocked_by: X-2@@X-2
blocked_by:\n  - X-2\n  - X-3@@X-2 X-3
blocked_by: []@@
blocked_by:@@
blocked_by: [X-2]   # needs the first@@X-2
blocks: [X-5]@@
ROWS
  rm -rf "$d"

  make_sandbox
  local p="$SB_PREFIX"
  seed_issue dev_complete "$p-201" blk dev "Blocker in dev_complete"
  seed_issue qa_complete  "$p-202" blk dev "Blocker in qa_complete"
  seed_issue done         "$p-203" blk dev "Blocker in done"
  local n b f
  for n in 211 212 213 214 215 216 217; do seed_issue todo "$p-$n" sub dev "Subject $n"; done
  _blk_set() { sed -i.bak "s/^forks: none/forks: none\nblocked_by: $2/" "$SB_WORK/progress/todo/$p-$1-sub.md" && rm -f "$SB_WORK/progress/todo/$p-$1-sub.md.bak"; }
  _blk_set 211 "[$p-201]"; _blk_set 212 "[$p-202]"; _blk_set 213 "[$p-203]"; _blk_set 214 "[]"
  _blk_set 215 "[$p-999]"; _blk_set 216 "[$p-201]"; _blk_set 217 "[$p-201]"
  publish_sandbox

  local out rc
  mv_() { ( cd "$SB_WORK" && ./scripts/move-issue.sh "$@" --role Dev 2>&1 ); }
  out="$(mv_ "$p-211" in_progress)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(not a refusal) the move exited $rc: $out"
  origin_has_path "progress/in_progress/$p-211-sub.md" || cf "the warning changed the board: $p-211 did not move"
  printf '%s\n' "$out" | grep "Warning: $p-211 is blocked_by $p-201, which is not in qa_complete/ or done/ on origin/$SB_TRUNK (found in dev_complete/)" >/dev/null \
    || cf "in_progress with the blocker in dev_complete/ printed no warning naming it and its column: $out"
  out="$(mv_ "$p-211" dev_complete)"; rc=$?
  [ "$rc" -eq 0 ] || cf "dev_complete move exited $rc: $out"
  printf '%s\n' "$out" | grep "Warning: $p-211 is blocked_by $p-201" >/dev/null || cf "dev_complete printed no blocked_by warning: $out"
  for n in 212 213 214; do
    out="$(mv_ "$p-$n" in_progress)"; rc=$?
    [ "$rc" -eq 0 ] || cf "control $n: exit $rc: $out"
    printf '%s\n' "$out" | grep "blocked_by" >/dev/null && cf "control $n (landed blocker or empty list) printed a blocked_by warning: $out"
  done
  out="$(mv_ "$p-215" in_progress)"
  printf '%s\n' "$out" | grep "Warning: $p-215 is blocked_by $p-999, which is not in qa_complete/ or done/ on origin/$SB_TRUNK (not found on the trunk)" >/dev/null \
    || cf "a blocker on no card did not print the not-found warning: $out"
  out="$(mv_ "$p-216" blocked --note "waiting")"
  printf '%s\n' "$out" | grep "blocked_by" >/dev/null && cf "a move to blocked read blocked_by: $out"
  out="$(mv_ "$p-217" in_progress --note "x")"
  printf '%s\n' "$out" | grep "Warning: $p-217 is blocked_by" >/dev/null || cf "a second warning case did not fire: $out"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — check-board [i] reads blocks:/blocked_by: through the one list reader (kit_card_list), so it
# gives that reader's verdict on every form. Each row is one two-card board: A-1 declares
# `blocks: [A-2]`; A-2's body is the row. Expected verdicts are typed here, never derived from a read.
# =============================================================================
case_board_property_i_reads_lists_through_the_one_reader() {
  cf_reset
  local L="check-board [i] reads blocks:/blocked_by: through kit_card_list" lib="$REAL_REPO_ROOT/scripts/lib/board-properties.sh" d row body want got
  [ -f "$lib" ] || { skp "$L" "lib/board-properties.sh is absent from this tree"; return; }
  d="$(mktemp -d)"
  # <A-2 body, \n-separated> @@ <expected: 'clean N' | a substring of the output that must appear>
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    body="${row%%@@*}"; want="${row#*@@}"
    rm -rf "$d/progress"; mkdir -p "$d/progress/todo"
    printf -- '---\nid: A-1\nblocks: [A-2]\n---\n' > "$d/progress/todo/A-1.md"
    printf -- '%b\n' "$body" > "$d/progress/todo/A-2.md"
    got="$( . "$lib"; STATUS_FOLDERS=todo; FRONTMATTER_SCAN_LINES=40; kit_bp_blocks "$d" 2>&1 )"
    case "$want" in
      clean*) printf '%s\n' "$got" | grep -F '⚠' >/dev/null && cf "'${body}': expected no finding, got: $got"
              printf '%s\n' "$got" | grep -F "${want#clean }" >/dev/null || cf "'${body}': expected '${want#clean }', got: $got" ;;
      *)      printf '%s\n' "$got" | grep -F "$want" >/dev/null || cf "'${body}': expected '$want', got: $got" ;;
    esac
  done <<'ROWS'
---\nid: A-2\nblocked_by: [A-1]\n---@@clean 2 card(s) read, 2 dependency declaration(s)
---\nid: A-2\nblocked_by: A-1\n---@@clean 2 card(s) read, 2 dependency declaration(s)
---\nid: A-2\nblocked_by:\n  - A-1\n---@@clean 2 card(s) read, 2 dependency declaration(s)
---\nid: A-2\nblocked_by: [A-1]   # why\n---@@clean 2 card(s) read, 2 dependency declaration(s)
---\nid: A-2\n---@@A-1 declares blocks: [A-2] and A-2 does not declare blocked_by: [A-1]
---\nid: A-2\n  blocked_by: [A-1]\n---@@A-1 declares blocks: [A-2] and A-2 does not declare blocked_by: [A-1]
---\nid: A-2\nblocked_by: [A-1#2]\n---@@A-2 declares blocked_by: [A-1#2] — A-1#2 is not on this board
id: A-2\nblocked_by: [A-1]@@A-1 declares blocks: [A-2] — A-2 is not on this board
ROWS
  rm -rf "$d"
  finish "$L"
}

# =============================================================================
# CASE — a replayed commit (cherry-pick, rebase) is judged at write time, and an empty subject is refused
#
# `cherry-pick` and a rebase's picks run no commit-msg hook, so a replayed commit with no role tag reached
# the trunk unjudged; prepare-commit-msg holds them. Every command a refusal prints is RUN here as printed.
# =============================================================================
case_prepare_commit_msg_holds_a_replay() {
  cf_reset
  make_sandbox
  local W="$SB_WORK" T="$SB_TRUNK" out rc head0 badsha goodsha cmd lines n
  seed_issue todo "$SB_PREFIX-834" replay chore "Replay row"
  publish_sandbox
  git -C "$W" checkout -q -b side
  echo 1 > "$W/p1.txt"; git -C "$W" add p1.txt; sbcommit -q -m "no role tag on this replayed commit"
  echo 2 > "$W/p2.txt"; git -C "$W" add p2.txt; sbcommit -q -m "[Dev] a conforming replayed commit"
  badsha="$(git -C "$W" rev-parse side~1)"; goodsha="$(git -C "$W" rev-parse side)"
  git -C "$W" checkout -q "$T"
  # the trunk moves on, so a rebase of side has something to replay over
  echo t > "$W/trunk-moves.txt"; git -C "$W" add trunk-moves.txt; sbcommit -q -m "[PM] the trunk moves"
  git -C "$W" push -q origin "$T" >/dev/null 2>&1
  local base; base="$(git -C "$W" rev-parse HEAD)"
  # _reset — back to the trunk at $base with no replay in progress.
  _reset() {
    git -C "$W" cherry-pick --abort >/dev/null 2>&1; git -C "$W" rebase --abort >/dev/null 2>&1
    git -C "$W" checkout -q -f "$T" >/dev/null 2>&1; git -C "$W" reset -q --hard "$base" >/dev/null 2>&1
    git -C "$W" clean -qfd >/dev/null 2>&1
    git -C "$W" branch -qf side "$goodsha" >/dev/null 2>&1; git -C "$W" branch -qD side2 >/dev/null 2>&1 || true
  }
  # _printed <out> — the commands a refusal printed on their own indented lines.
  _printed() { printf '%s\n' "$1" | sed -n 's/^    \(\(MSG_OK=1 \)\{0,1\}git .*\)$/\1/p'; }

  # (a) a cherry-pick of a commit with no role tag is refused at write time: nothing committed.
  head0="$(git -C "$W" rev-parse HEAD)"
  out="$( cd "$W" && env -u MSG_OK git cherry-pick "$badsha" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) a cherry-pick of an untagged commit committed"
  [ "$(git -C "$W" rev-parse HEAD)" = "$head0" ] || cf "(a) HEAD moved despite the refusal"
  case "$out" in *"role tag"*) : ;; *) cf "(a) the refusal does not name the role tag: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  lines="$(_printed "$out")"; n="$(grep -c . <<< "$lines")"
  [ "$n" -ge 3 ] || cf "(a) the Next prints $n runnable lines, expected a reword, a keep-as-is and a quit: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"
  # (a1) every printed command, run as printed on a fresh refusal, does what it says.
  local i=0
  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    i=$((i+1))
    _reset
    ( cd "$W" && env -u MSG_OK git cherry-pick "$badsha" >/dev/null 2>&1 )
    out="$( cd "$W" && env -u MSG_OK GIT_EDITOR=true bash -c "$cmd" 2>&1 )"; rc=$?
    [ "$rc" -eq 0 ] || cf "(a$i) the printed line '$cmd' failed as printed (rc $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
    [ ! -e "$W/.git/CHERRY_PICK_HEAD" ] || cf "(a$i) after '$cmd' a cherry-pick is still in progress"
    case "$cmd" in
      *"commit -m"*) grep -qE '^\[[A-Za-z]+\] ' <<< "$(git -C "$W" log -1 --format=%s)" || cf "(a$i) the reworded commit has no role tag: $(git -C "$W" log -1 --format=%s)" ;;
      *"-C CHERRY_PICK_HEAD"*|*"--continue"*) [ "$(git -C "$W" log -1 --format=%s)" = "no role tag on this replayed commit" ] || cf "(a$i) keep-as-is did not keep the message: $(git -C "$W" log -1 --format=%s)" ;;
      *"--quit"*) [ "$(git -C "$W" rev-parse HEAD)" = "$base" ] && [ ! -e "$W/.git/CHERRY_PICK_HEAD" ] || cf "(a$i) the quit moved HEAD or left the pick in progress"; case "$(git -C "$W" diff --cached --name-only)" in *p1.txt*) : ;; *) cf "(a$i) the quit dropped the staged picked change" ;; esac ;;
    esac
  done <<< "$lines"

  # (b) a conforming cherry-pick passes, quietly.
  _reset
  out="$( cd "$W" && env -u MSG_OK git cherry-pick "$goodsha" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) a conforming cherry-pick was refused: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"

  # (c) the documented escape: MSG_OK=1 imports it verbatim.
  _reset
  out="$( cd "$W" && MSG_OK=1 git cherry-pick "$badsha" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(c) MSG_OK=1 git cherry-pick was refused: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"

  # (d) a rebase that replays an untagged commit stops at it; the printed lines work.
  _reset
  git -C "$W" checkout -q side
  out="$( cd "$W" && env -u MSG_OK GIT_EDITOR=true git rebase "$T" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(d) a rebase replaying an untagged commit ran to the end"
  [ -d "$W/.git/rebase-merge" ] || cf "(d) the rebase did not stop at the untagged commit"
  case "$out" in *"detached HEAD"*"your branch where it was"*) : ;; *) cf "(d) the rebase Next does not say where --quit leaves the branch and HEAD: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  lines="$(_printed "$out")"; n="$(grep -c . <<< "$lines")"
  [ "$n" -ge 3 ] || cf "(d) the Next prints $n runnable lines: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"
  i=0
  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    i=$((i+1))
    _reset
    git -C "$W" checkout -q side
    ( cd "$W" && env -u MSG_OK GIT_EDITOR=true git rebase "$T" >/dev/null 2>&1 )
    out="$( cd "$W" && env -u MSG_OK GIT_EDITOR=true bash -c "$cmd" 2>&1 )"; rc=$?
    [ "$rc" -eq 0 ] || cf "(d$i) the printed line '$cmd' failed as printed (rc $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
    case "$cmd" in
      *"--quit"*) [ ! -d "$W/.git/rebase-merge" ] || cf "(d$i) the quit left the rebase in progress" ;;
      *) [ ! -d "$W/.git/rebase-merge" ] || cf "(d$i) after '$cmd' the rebase is still in progress: $(git -C "$W" status -sb | head -3 | tr '\n' '|')"
         grep -q 'conforming replayed commit' <<< "$(git -C "$W" log --format=%s "$T..side")" || cf "(d$i) the conforming commit is missing after '$cmd'" ;;
    esac
  done <<< "$lines"

  # (e) a rebase reword that keeps the untagged subject is refused (the editor-less form).
  _reset
  git -C "$W" checkout -q side
  out="$( cd "$W" && env -u MSG_OK GIT_SEQUENCE_EDITOR="sed -i.bak 's/^pick/reword/'" GIT_EDITOR=true git rebase -i "$badsha~1" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(e) a rebase reword kept an untagged subject"

  # (e2) an editor that fixes the subject is let through: the hook does not judge the message before the
  # editor opens. (An editor that leaves it untagged is NOT refused either: git commits a `cherry-pick -e` with
  # -n semantics and runs no commit-msg, which the contract lists among the after-the-fact entrances.)
  _reset
  out="$( cd "$W" && env -u MSG_OK GIT_EDITOR="sed -i.bak '1s/.*/[Dev] fixed in the editor/'" git cherry-pick -e "$badsha" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(e2) cherry-pick -e with an editor that tags the subject was refused: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  [ "$(git -C "$W" log -1 --format=%s)" = "[Dev] fixed in the editor" ] || cf "(e2) the edited subject was not kept: $(git -C "$W" log -1 --format=%s)"

  # (f) a rebase over conforming commits runs to the end; an ordinary untagged commit is refused as before,
  # and --no-verify on an ordinary commit still bypasses.
  _reset
  git -C "$W" checkout -q -b side2 "$base"
  echo 3 > "$W/p3.txt"; git -C "$W" add p3.txt; sbcommit -q -m "[Dev] another conforming replayed commit"
  git -C "$W" checkout -q "$T"
  echo t2 > "$W/trunk-moves2.txt"; git -C "$W" add trunk-moves2.txt; sbcommit -q -m "[PM] the trunk moves again"
  git -C "$W" checkout -q side2
  out="$( cd "$W" && env -u MSG_OK GIT_EDITOR=true git rebase "$T" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(f) a rebase over conforming commits was refused: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  _reset
  echo n > "$W/n.txt"; git -C "$W" add n.txt
  out="$( cd "$W" && env -u MSG_OK git commit -q -m "no role tag, ordinary commit" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(f) an ordinary untagged commit was accepted (commit-msg is unchanged)"
  case "$out" in *"replayed by"*|*"--continue"*) cf "(f) an ordinary commit's refusal prints a replay's Next: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  out="$( cd "$W" && env -u MSG_OK git commit -q --no-verify -m "no role tag, ordinary commit" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(f) git commit --no-verify was refused: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # (g) the tools' own commits still pass: a board move, and a printed escape commit (kit-upgrade's shape).
  _reset
  out="$( cd "$W" && env -u MSG_OK "$W/scripts/move-issue.sh" "$SB_PREFIX-834" in_progress --role Dev --note "replay row" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(g) move-issue.sh was refused: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  echo m > "$W/m.txt"; git -C "$W" add m.txt
  out="$( cd "$W" && MSG_OK=1 git commit -q -m '[PM] Restore the staged kit files' -- m.txt 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(g) MSG_OK=1 git commit '[PM] …' was refused: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # (h) an empty subject is refused, naming a runnable Next; MSG_OK=1 still takes it.
  _reset
  echo e > "$W/e.txt"; git -C "$W" add e.txt; head0="$(git -C "$W" rev-parse HEAD)"
  out="$( cd "$W" && env -u MSG_OK git commit -q --allow-empty-message -m "" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(h) an empty subject was committed"
  [ "$(git -C "$W" rev-parse HEAD)" = "$head0" ] || { cf "(h) HEAD moved despite the refusal"; _reset; echo e > "$W/e.txt"; git -C "$W" add e.txt; }
  case "$out" in *"Next:"*) : ;; *) cf "(h) the refusal names no Next: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  cmd="$(_printed "$out" | head -1)"
  [ -n "$cmd" ] || cf "(h) the Next prints no runnable commit line: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  if [ -n "$cmd" ]; then
    out="$( cd "$W" && env -u MSG_OK bash -c "$cmd" 2>&1 )"; rc=$?
    [ "$rc" -eq 0 ] || cf "(h) the printed line '$cmd' failed as printed: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  fi
  _reset
  echo e2 > "$W/e2.txt"; git -C "$W" add e2.txt
  out="$( cd "$W" && MSG_OK=1 git commit -q --allow-empty-message -m "" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(h) MSG_OK=1 did not take an empty subject: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  finish "prepare-commit-msg: a cherry-pick or rebase pick with no role tag is refused at write time with a Next whose every line runs as printed; a conforming one, MSG_OK=1, --no-verify on an ordinary commit and the tools' own commits pass; an empty subject is refused"
  teardown
}

# =============================================================================
# CASE — check-board arm [e] reports a commit with no subject instead of skipping it
# =============================================================================
case_check_board_arm_e_reports_an_empty_subject() {
  cf_reset
  make_sandbox
  [ -f "$SB_WORK/scripts/githooks/commit-msg" ] \
    || _fixture_die "case_check_board_arm_e_reports_an_empty_subject: the sandbox ships no commit-msg hook, so there is no epoch."
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m "init" >/dev/null 2>&1
  echo x > "$SB_WORK/x.txt"; git -C "$SB_WORK" add x.txt
  sbcommit -q --allow-empty-message -m "" >/dev/null 2>&1
  local sha_empty; sha_empty="$(git -C "$SB_WORK" rev-parse --short=9 HEAD)"
  [ -z "$(git -C "$SB_WORK" log -1 --format=%s)" ] \
    || _fixture_die "case_check_board_arm_e_reports_an_empty_subject: the planted commit has a subject."
  sbcommit -q --allow-empty -m "[Dev] a later commit" >/dev/null 2>&1
  publish_sandbox
  local out; out="$(cb_run)"
  grep "$sha_empty" <<< "$out" | grep -i 'no subject' >/dev/null \
    || cf "the commit with no subject $sha_empty was not reported: $(grep -m3 '^\[e\]\|⚠' <<< "$out" | tr '\n' '|')"
  finish "check-board arm [e]: a commit with an empty subject is reported, not skipped"
  teardown
}

# =============================================================================
# CASE — the replay hook's edges: a stale CHERRY_PICK_HEAD, an editor run beside a pick, a cherry-pick at a
# rebase edit stop, a range of picks, `rebase --apply`, the reworded subject's role, and the kit's own push retry
# =============================================================================
case_prepare_commit_msg_edges() {
  cf_reset
  make_sandbox
  local W="$SB_WORK" T="$SB_TRUNK" out rc cmd lines n base badsha goodsha
  publish_sandbox
  git -C "$W" checkout -q -b side
  echo 1 > "$W/p1.txt"; git -C "$W" add p1.txt; sbcommit -q -m "no role tag on this replayed commit"
  echo 2 > "$W/p2.txt"; git -C "$W" add p2.txt; sbcommit -q -m "[Dev] a conforming replayed commit"
  badsha="$(git -C "$W" rev-parse side~1)"; goodsha="$(git -C "$W" rev-parse side)"
  git -C "$W" checkout -q "$T"
  echo t > "$W/trunk-moves.txt"; git -C "$W" add trunk-moves.txt; sbcommit -q -m "[PM] the trunk moves"
  git -C "$W" push -q origin "$T" >/dev/null 2>&1
  base="$(git -C "$W" rev-parse HEAD)"
  _reset() {
    git -C "$W" cherry-pick --quit >/dev/null 2>&1; git -C "$W" rebase --abort >/dev/null 2>&1
    git -C "$W" checkout -q -f "$T" >/dev/null 2>&1; git -C "$W" reset -q --hard "$base" >/dev/null 2>&1
    git -C "$W" clean -qfd >/dev/null 2>&1
    git -C "$W" branch -qf side "$goodsha" >/dev/null 2>&1
    git -C "$W" branch -qD side3 es >/dev/null 2>&1 || true
    sandbox_hat_declare
  }
  _printed() { printf '%s\n' "$1" | sed -n 's/^    \(\(MSG_OK=1 \)\{0,1\}git .*\)$/\1/p'; }

  # (a) a stale CHERRY_PICK_HEAD (an empty pick leaves it) does not turn the user's own commit into a replay.
  _reset
  git -C "$W" cherry-pick "$goodsha" >/dev/null 2>&1                       # applies it
  git -C "$W" reset -q --hard "$base"; git -C "$W" cherry-pick "$goodsha" >/dev/null 2>&1   # a pick of what is already there ...
  git -C "$W" cherry-pick "$goodsha" >/dev/null 2>&1                       # ... is empty and leaves the marker
  [ -f "$W/.git/CHERRY_PICK_HEAD" ] || _fixture_die "case_prepare_commit_msg_edges: an empty pick left no CHERRY_PICK_HEAD, so (a) proves nothing"
  echo w > "$W/w.txt"; git -C "$W" add w.txt
  out="$( cd "$W" && env -u MSG_OK git commit -q -m "wip my own change" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) an untagged commit made beside a stale marker was accepted"
  case "$out" in *"replayed by"*|*"--quit"*|*"cherry-pick --continue"*) cf "(a) an ordinary commit's refusal printed a replay's commands: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  case "$(git -C "$W" diff --cached --name-only)" in *w.txt*) : ;; *) cf "(a) the user's staged work is gone" ;; esac
  out="$( cd "$W" && env -u MSG_OK git commit -q -m "[Dev] my own change" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) a tagged commit beside a stale marker was refused: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # (b) `git commit -e -m` during a live pick reaches its editor before anything judges the message.
  _reset
  ( cd "$W" && env -u MSG_OK git cherry-pick "$badsha" >/dev/null 2>&1 )
  out="$( cd "$W" && env -u MSG_OK GIT_EDITOR="sed -i.bak '1s/.*/[Dev] tagged in the editor/'" git commit -e -m "wip" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) commit -e -m beside a live pick was refused before its editor: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  [ "$(git -C "$W" log -1 --format=%s)" = "[Dev] tagged in the editor" ] || cf "(b) the edited subject was not kept: $(git -C "$W" log -1 --format=%s)"

  # (c) a cherry-pick run at a rebase edit stop gets the cherry-pick's commands, and they leave the stop alone.
  _reset
  git -C "$W" checkout -q -b es "$base"
  echo e1 > "$W/e1.txt"; git -C "$W" add e1.txt; sbcommit -q -m "[Dev] edit-stop one"
  echo e2 > "$W/e2.txt"; git -C "$W" add e2.txt; sbcommit -q -m "[Dev] edit-stop two"
  ( cd "$W" && env -u MSG_OK GIT_EDITOR=true GIT_SEQUENCE_EDITOR="sed -i.bak '1s/^pick/edit/'" git rebase -i "$base" >/dev/null 2>&1 )
  [ -d "$W/.git/rebase-merge" ] || _fixture_die "case_prepare_commit_msg_edges: the rebase did not stop at its edit line, so (c) proves nothing"
  out="$( cd "$W" && env -u MSG_OK git cherry-pick "$badsha" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(c) an untagged cherry-pick at a rebase edit stop committed"
  case "$out" in *"rebase --"*) cf "(c) the commands name a rebase though a cherry-pick was run: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)" ;; esac
  cmd="$(_printed "$out" | head -1)"
  out="$( cd "$W" && env -u MSG_OK bash -c "$cmd" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(c) the printed line '$cmd' failed as printed: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  [ -d "$W/.git/rebase-merge" ] || cf "(c) the printed cherry-pick line ended the user's rebase edit stop"

  # (d) a range of picks: the reword and keep lines carry the range on; an untagged LAST pick works too.
  _reset
  out="$( cd "$W" && env -u MSG_OK git cherry-pick "$badsha^..$goodsha" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(d) a range starting with an untagged commit committed it"
  lines="$(_printed "$out")"
  n="$(grep -c 'git cherry-pick --continue' <<< "$lines")"
  [ "$n" -eq 2 ] || cf "(d) $n of the reword and keep lines continue the range, expected 2: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"
  while IFS= read -r cmd; do
    case "$cmd" in *"git cherry-pick --continue"*)
      _reset
      ( cd "$W" && env -u MSG_OK git cherry-pick "$badsha^..$goodsha" >/dev/null 2>&1 )
      out="$( cd "$W" && env -u MSG_OK GIT_EDITOR=true bash -c "$cmd" 2>&1 )"; rc=$?
      [ "$rc" -eq 0 ] || cf "(d) the printed line '$cmd' failed as printed (rc $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
      [ -e "$W/p2.txt" ] && [ ! -d "$W/.git/sequencer" ] || cf "(d) after '$cmd' the rest of the range was not applied" ;;
    esac
  done <<< "$lines"
  _reset
  git -C "$W" checkout -q -b side3 "$base"
  echo s1 > "$W/s1.txt"; git -C "$W" add s1.txt; sbcommit -q -m "[Dev] range first"
  echo s2 > "$W/s2.txt"; git -C "$W" add s2.txt; sbcommit -q -m "an untagged last pick"
  git -C "$W" checkout -q "$T"
  out="$( cd "$W" && env -u MSG_OK git cherry-pick "$base..side3" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(d2) an untagged last pick of a range committed"
  cmd="$(_printed "$out" | head -1)"
  out="$( cd "$W" && env -u MSG_OK GIT_EDITOR=true bash -c "$cmd" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(d2) the printed line '$cmd' failed on the last pick of a range (rc $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # (e) `rebase --apply` runs the patch-application hook and says what to do; the printed line works.
  _reset
  git -C "$W" checkout -q side
  out="$( cd "$W" && env -u MSG_OK GIT_EDITOR=true git rebase --apply "$T" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(e) a rebase --apply replaying an untagged commit ran to the end"
  case "$out" in *"commit again with a subject"*) cf "(e) the refusal offers the ordinary 'commit again' for a rebase: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  cmd="$(_printed "$out" | head -1)"
  [ -n "$cmd" ] || cf "(e) the refusal prints no runnable line: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  if [ -n "$cmd" ]; then
    out="$( cd "$W" && bash -c "$cmd" 2>&1 )"; rc=$?
    [ "$rc" -eq 0 ] || cf "(e) the printed line '$cmd' failed as printed: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
    [ ! -d "$W/.git/rebase-apply" ] || cf "(e) the rebase is still in progress after '$cmd'"
  fi

  # (f) the reword carries the hat's role, replaces a tag outside the set, and the hat warning prints once.
  _reset
  printf 'QA sandbox\n' > "$W/$(_sandbox_hat_file)"
  out="$( cd "$W" && env -u MSG_OK git cherry-pick "$badsha" 2>&1 )"
  case "$(_printed "$out" | head -1)" in "git commit -m '[QA] no role tag on this replayed commit'") : ;; *) cf "(f) the reword line does not carry the hat's role [QA]: $(_printed "$out" | head -1)" ;; esac
  out="$( cd "$W" && env -u MSG_OK git commit -q -m "[Dev] reworded under a QA hat" 2>&1 )"
  n="$(grep -c "Warning: this commit's role tag" <<< "$out")"
  [ "$n" -eq 1 ] || cf "(f) the hat-mismatch warning printed $n times, expected once: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  # a conforming commit replayed under a different hat is somebody else's tag on purpose: no warning at all
  _reset
  printf 'QA sandbox\n' > "$W/$(_sandbox_hat_file)"
  out="$( cd "$W" && env -u MSG_OK git cherry-pick "$goodsha" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(f) a conforming cherry-pick under another hat was refused: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  case "$out" in *"Warning: this commit's role tag"*) cf "(f) a replayed commit drew the hat-mismatch warning: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  _reset
  echo f > "$W/f.txt"; git -C "$W" add f.txt; sbcommit -q -m "[$(printf 'F%s' oo)] a tag outside the set"
  local foosha; foosha="$(git -C "$W" rev-parse HEAD)"; git -C "$W" reset -q --hard "$base"
  out="$( cd "$W" && env -u MSG_OK git cherry-pick "$foosha" 2>&1 )"
  case "$(_printed "$out" | head -1)" in "git commit -m '[Dev] a tag outside the set'") : ;; *) cf "(f) a tag outside the set was not replaced: $(_printed "$out" | head -1)" ;; esac

  # (g) the kit's own push retry names a hook refusal, not a conflict.
  _reset
  git -C "$W" checkout -q "$T"
  echo u > "$W/u.txt"; git -C "$W" add u.txt; sbcommit -q -m "an unpushed commit from before the rule"
  echo v > "$W/v.txt"; git -C "$W" add v.txt; sbcommit -q -m "[Dev] an unpushed tagged commit"
  git clone -q "$SB_ORIGIN" "$SB_TMP/other" >/dev/null 2>&1
  echo o > "$SB_TMP/other/o.txt"; git -C "$SB_TMP/other" add o.txt
  MSG_OK=1 git -C "$SB_TMP/other" -c user.email=o@sandbox.invalid -c user.name=Other commit -q -m "[PM] the remote advances" >/dev/null 2>&1
  git -C "$SB_TMP/other" push -q origin "HEAD:$T" >/dev/null 2>&1
  out="$( cd "$W" && env -u MSG_OK bash -c '. scripts/lib/push-retry.sh; git_push_with_retry "$PWD" origin "$1"' _ "$T" 2>&1 )"; rc=$?
  [ "$rc" -eq 1 ] || cf "(g control) exit $rc, expected 1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  case "$out" in *CONFLICTED*) cf "(g) a hook refusal was reported as a conflict: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)" ;; esac
  case "$out" in *"role tag"*) : ;; *) cf "(g) the failure does not carry what the hook said: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)" ;; esac
  case "$out" in *"MSG_OK=1 git -C"*) : ;; *) cf "(g) the failure names no way on" ;; esac
  case "$out" in *"waives the guard's trailer rule"*) : ;; *) cf "(g) the escape line does not say it also waives the trailer rule" ;; esac

  finish "prepare-commit-msg: a stale CHERRY_PICK_HEAD makes no replay, commit -e -m beside a pick reaches its editor, a cherry-pick at a rebase edit stop and a range of picks get commands that fit, rebase --apply says to run it again, the reword carries the hat's role and warns once, and the push retry names a hook refusal"
  teardown
}

# =============================================================================
# CASE — the replay hook compares raw messages, a resolution commit inside a stopped `rebase --apply` is an
# ordinary commit, and the kit's push retry names a hook refusal only when a hook refused
# =============================================================================
case_prepare_commit_msg_compares_raw_messages() {
  cf_reset
  make_sandbox
  local W="$SB_WORK" T="$SB_TRUNK" out rc base head0 sha label body
  publish_sandbox
  echo A > "$W/c.txt"; git -C "$W" add c.txt; sbcommit -q -m "[PM] c base"
  git -C "$W" push -q origin "$T" >/dev/null 2>&1
  base="$(git -C "$W" rev-parse HEAD)"
  _reset() {
    git -C "$W" cherry-pick --quit >/dev/null 2>&1; git -C "$W" rebase --abort >/dev/null 2>&1
    git -C "$W" checkout -q -f "$T" >/dev/null 2>&1; git -C "$W" reset -q --hard "$base" >/dev/null 2>&1
    git -C "$W" clean -qfd >/dev/null 2>&1
    git -C "$W" branch -qD rw ap >/dev/null 2>&1 || true
  }
  # _mk <label> <printf-format> — a commit on branch rw (off the base) whose raw message is exactly the format.
  _mk() {
    git -C "$W" checkout -q -b rw "$base" >/dev/null 2>&1
    echo "$1" > "$W/$1.txt"; git -C "$W" add "$1.txt"
    printf "$2" > "$SB_TMP/msg-$1.txt"
    MSG_OK=1 git -C "$W" -c "i18n.commitEncoding=${3:-UTF-8}" commit -q --cleanup=verbatim -F "$SB_TMP/msg-$1.txt" >/dev/null 2>&1 || _fixture_die "case_prepare_commit_msg_compares_raw_messages: could not plant the $1 message"
    git -C "$W" rev-parse HEAD
    git -C "$W" checkout -q "$T" >/dev/null 2>&1; git -C "$W" branch -q -D rw >/dev/null 2>&1
  }

  # (a) a replayed commit whose raw first line differs from its %s subject (a wrapped first paragraph, CRLF,
  # trailing blanks, a leading #) is still held.
  for label in wrapped crlf trailing hash latin1; do
    enc=UTF-8
    case "$label" in
      wrapped)  body='untagged wrapped line one\nline two of subject\n' ;;
      crlf)     body='untagged crlf\r\n\r\nbody\r\n' ;;
      trailing) body='untagged trail   \n' ;;
      hash)     body='# untagged hash\n' ;;
      latin1)   body='untagged caf\351 latin\n'; enc=ISO-8859-1 ;;
    esac
    _reset
    sha="$(_mk "$label" "$body" "$enc")"
    head0="$(git -C "$W" rev-parse HEAD)"
    out="$( cd "$W" && env -u MSG_OK git cherry-pick "$sha" 2>&1 )"; rc=$?
    [ "$rc" -ne 0 ] || cf "(a $label) an untagged cherry-pick with this raw message committed"
    [ "$(git -C "$W" rev-parse HEAD)" = "$head0" ] || cf "(a $label) HEAD moved despite the refusal"
  done
  _reset
  sha="$(_mk wrapped 'untagged wrapped line one\nline two of subject\n')"
  [ "$(git -C "$W" log -1 --format=%s "$sha")" = "untagged wrapped line one line two of subject" ] \
    || _fixture_die "case_prepare_commit_msg_compares_raw_messages: the wrapped message did not wrap, so (a) proves nothing"
  git -C "$W" checkout -q -b rw "$sha"; git -C "$W" checkout -q "$T"
  echo t > "$W/tm.txt"; git -C "$W" add tm.txt; sbcommit -q -m "[PM] the trunk moves"
  git -C "$W" checkout -q rw
  out="$( cd "$W" && env -u MSG_OK GIT_EDITOR=true git rebase "$T" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a rebase) a rebase over a wrapped untagged commit ran to the end"
  _reset
  sha="$(_mk okwrapped '[Dev] a conforming wrapped line one\nline two\n')"
  out="$( cd "$W" && env -u MSG_OK git cherry-pick "$sha" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a control) a conforming wrapped message was refused: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  # a commit in another encoding: the rebase holds it too (the file is written in UTF-8, the object is not)
  _reset
  sha="$(_mk latin1r 'untagged caf\351 rb\n' ISO-8859-1)"
  git -C "$W" checkout -q -b rw "$sha"; git -C "$W" checkout -q "$T"
  echo t > "$W/tm.txt"; git -C "$W" add tm.txt; sbcommit -q -m "[PM] the trunk moves"
  git -C "$W" checkout -q rw
  out="$( cd "$W" && env -u MSG_OK GIT_EDITOR=true git rebase "$T" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a latin1 rebase) a rebase over an untagged ISO-8859-1 commit ran to the end"

  # (b) inside a stopped `rebase --apply`, the user's own resolution commit is an ordinary commit: the ordinary
  # Next, and nothing printed discards the staged work.
  _reset
  git -C "$W" checkout -q -b ap "$base"
  echo B > "$W/c.txt"; git -C "$W" add c.txt; sbcommit -q -m "[Dev] ap change"
  git -C "$W" checkout -q "$T"
  echo C > "$W/c.txt"; git -C "$W" add c.txt; sbcommit -q -m "[PM] trunk changes c"
  git -C "$W" checkout -q ap
  ( cd "$W" && env -u MSG_OK GIT_EDITOR=true git rebase --apply "$T" >/dev/null 2>&1 )
  [ -f "$W/.git/rebase-apply/rebasing" ] || _fixture_die "case_prepare_commit_msg_compares_raw_messages: the --apply rebase did not stop on its conflict, so (b) proves nothing"
  echo R > "$W/c.txt"; git -C "$W" add c.txt; echo m > "$W/mine.txt"; git -C "$W" add mine.txt
  out="$( cd "$W" && env -u MSG_OK git commit -q -m "my resolution" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) an untagged resolution commit inside a stopped rebase --apply was accepted"
  case "$out" in *"rebase --abort"*|*"rebase applies patches"*) cf "(b) the user's own commit got the rebase --apply block, whose line discards the staged work: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  case "$out" in *"commit again"*) : ;; *) cf "(b) the ordinary Next is missing: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  case "$(git -C "$W" diff --cached --name-only)" in *mine.txt*) : ;; *) cf "(b) the user's staged work is gone" ;; esac

  # (b2) a commit of the user's own that carries the refused patch's own message is still the user's: it is told
  # apart by the file git hands the hook, not by the text. Hand-applied patch plus a staged new file.
  _reset
  git -C "$W" checkout -q -b ap "$base"
  echo ax > "$W/ax.txt"; git -C "$W" add ax.txt; sbcommit -q -m "untagged second patch"
  git -C "$W" checkout -q "$T"
  echo t2 > "$W/tm2.txt"; git -C "$W" add tm2.txt; sbcommit -q -m "[PM] the trunk moves again"
  git -C "$W" checkout -q ap
  out="$( cd "$W" && env -u MSG_OK GIT_EDITOR=true git rebase --apply "$T" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b2 control) an untagged patch under rebase --apply was not refused"
  case "$out" in *"rebase --quit"*) : ;; *) cf "(b2 control) the patch's own refusal does not print git rebase --quit: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  ( cd "$W" && git apply --index .git/rebase-apply/patch ) >/dev/null 2>&1 || _fixture_die "case_prepare_commit_msg_compares_raw_messages: could not hand-apply the patch, so (b2) proves nothing"
  echo extra > "$W/extra.txt"; git -C "$W" add extra.txt
  out="$( cd "$W" && env -u MSG_OK git commit -q -m "untagged second patch" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b2) an untagged commit was accepted"
  case "$out" in *"rebase applies patches"*|*"rebase --quit"*|*"rebase --abort"*) cf "(b2) the user's own commit got the rebase --apply block: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  case "$out" in *"commit again"*) : ;; *) cf "(b2) the ordinary Next is missing" ;; esac
  case "$(git -C "$W" diff --cached --name-only)" in *extra.txt*) : ;; *) cf "(b2) the user's staged file is gone" ;; esac

  # (c) the kit's own push retry blames a hook only when a hook refused: an untracked file in the way is a plain failure.
  _reset
  git -C "$W" checkout -q "$T"
  echo v > "$W/v.txt"; git -C "$W" add v.txt; sbcommit -q -m "[Dev] an unpushed tagged commit"
  git clone -q "$SB_ORIGIN" "$SB_TMP/other" >/dev/null 2>&1
  echo o > "$SB_TMP/other/fb.txt"; git -C "$SB_TMP/other" add fb.txt
  MSG_OK=1 git -C "$SB_TMP/other" -c user.email=o@sandbox.invalid -c user.name=Other commit -q -m "[PM] the remote adds fb.txt" >/dev/null 2>&1
  git -C "$SB_TMP/other" push -q origin "HEAD:$T" >/dev/null 2>&1
  echo mine > "$W/fb.txt"                                            # untracked here, in the way of the rebase
  out="$( cd "$W" && env -u MSG_OK bash -c '. scripts/lib/push-retry.sh; git_push_with_retry "$PWD" origin "$1"' _ "$T" 2>&1 )"; rc=$?
  [ "$rc" -eq 1 ] || cf "(c control) exit $rc, expected 1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  case "$out" in *"A hook refused"*|*"MSG_OK"*) cf "(c) an untracked file in the way was reported as a hook refusal, with the hook escape: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)" ;; esac
  case "$out" in *fb.txt*) : ;; *) cf "(c) git's own account (the file in the way) is not quoted: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)" ;; esac

  finish "prepare-commit-msg: a wrapped, CRLF, trailing-blank or # first line is still held; a resolution commit inside a stopped rebase --apply gets the ordinary Next and loses nothing; the push retry blames a hook only when a hook refused"
  teardown
}
