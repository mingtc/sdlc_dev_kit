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
# Two invariants from process/contracts/progress-record.md, and the second is the one
# that cannot be asserted:
#
#   § 2 / § 4  ONE SHAPE. A reader that parses ONLY the four required fields reads
#              every record — including records carrying optional fields it has never
#              heard of. Tested by writing records WITH and WITHOUT extras and
#              requiring a uniform column count.
#
#   § 5b       THE ACTOR AND THE RESERVED EXTRAS have declared shapes, and the
#              validator's own RISK is the mirror of the defect it fixes — a validator
#              firing on CORRECT input. So the NEGATIVE control is the one that matters
#              and it is DERIVED: every role in this sandbox's own ROLE_PREFIXES is
#              driven through the writer and none may be tagged. The `run=` extra is
#              checked the same way — present when the seam is set, ABSENT ENTIRELY
#              when it is not.
#
#   § 4        THE ABLATION. Removing the writer entirely leaves a converted
#              producer's stdout, stderr and EXIT STATUS byte-identical. This is the
#              invariant whose violation is invisible until something unrelated turns
#              red, so it is MEASURED BY DELETING THE LIBRARY AND RE-RUNNING — never
#              by reading the `kit_progress() { :; }` stub and believing it.
#
# THE OPERAND IS ASSERTED BEFORE EITHER CHECK. A run in which the library never loaded
# would produce zero records and an identical ablation, and would pass both tests while
# measuring nothing — the green would be the sound of the subject being absent.
# =============================================================================
case_progress_record_is_one_shape_and_optional() {
  cf_reset
  make_sandbox

  local lib="$SB_WORK/scripts/lib/progress-record.sh"
  if [ ! -f "$lib" ]; then
    skp "the progress record is one shape and its writer is optional" "scripts/lib/progress-record.sh is not in the sandbox"
    teardown; return
  fi

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

  # ── § 5b, THE NEGATIVE CONTROL, AND IT IS THE ONE THAT MATTERS. This change added a
  #    validator, so its own risk is a legitimate actor being tagged. The population is
  #    DERIVED FROM THIS SANDBOX'S OWN SEAM rather than typed here: a project that narrows
  #    ROLE_PREFIXES must narrow this control with it, and a list written here would be the
  #    second declaration § 5b exists to forbid.
  # nroles is declared at the TOP so the finish() line below can name it on EVERY path.
  # Under `set -u` an unset one taken from the unreadable-seam branch would abort the whole
  # harness rather than report this case — a fixture that kills the run is worse than a red.
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

  # ── § 5b, THE POSITIVE HALF: an actor outside the shape still WRITES, is TAGGED, and
  #    the record still has its four columns on one line. The whole property being copied
  #    from the class arm is that a typo is VISIBLE rather than lost.
  local bogusdir="$SB_TMP/records-bogus"
  (
    cd "$SB_WORK" || exit 1
    # Both libraries again, for the same reason: `orchestrator/sub-3` is structurally fine
    # and is caught only by the MEMBERSHIP half, which needs the role set in scope.
    # shellcheck source=/dev/null
    . ./scripts/lib/role-set.sh
    # shellcheck source=/dev/null
    . ./scripts/lib/progress-record.sh
    export KIT_PROGRESS_DIR="$bogusdir"
    kit_progress "orchestrator/sub-3" status "structurally fine but NOT a member — the membership half"
    kit_progress ""                   info   "no actor at all"
    # THE STRUCTURAL HALF, which must hold whether or not the role set is readable. An
    # earlier draft checked structure only AFTER the membership lookup, so on a tree whose
    # hook is unreadable an actor with a space in it was accepted as a role name.
    kit_progress "has space"          info   "whitespace is not a role and never was"
    kit_progress "Dev:"               info   "a colon with no id is not the declared shape"
  ) >/dev/null 2>&1

  local nbog=0
  [ -d "$bogusdir" ] && nbog="$(cat "$bogusdir"/*.tsv 2>/dev/null | grep -c . || true)"
  if [ "${nbog:-0}" -ne 4 ]; then
    cf "an actor outside § 5b's shape produced $nbog record(s), not 4 — the validator DROPPED a record, and § 3 says a malformed field must never make work look like it never happened"
  else
    [ "$(awk -F'\t' '{print NF}' "$bogusdir"/*.tsv | sort -u | tr -d '\n')" = "5" ] \
      || cf "a tagged record does not carry the four required columns plus extras — § 2's envelope must survive normalisation"
    awk -F'\t' '$2!="unknown" {bad=1} END{exit bad?1:0}' "$bogusdir"/*.tsv 2>/dev/null \
      || cf "an actor outside § 5b's shape was written through unnormalised — the column is still best-effort"
    [ "$(grep -c 'declared-actor=' "$bogusdir"/*.tsv 2>/dev/null || echo 0)" -eq 4 ] \
      || cf "a normalised actor was not preserved in declared-actor= — § 5b requires the offered value be carried, or the typo is silent"
    # ...AND AS ONE TOKEN. A space inside the preserved value splits one extra into two,
    # so a reader tokenising the extras field sees a key nobody wrote.
    awk -F'\t' '$5 ~ /declared-actor=[^ ]* / && $5 !~ /declared-actor=[^ ]*$/ {n=split($5,p," "); for(i=1;i<=n;i++) if (p[i] !~ /=/) bad=1} END{exit bad?1:0}' "$bogusdir"/*.tsv 2>/dev/null \
      || cf "a preserved actor value was not collapsed to one token — whitespace inside it split the extras field into a key=value nobody wrote"
  fi

  # ── THE CLASS ARM, ONE COLUMN OVER, AND THE SAME TOKEN RULE. contracts/progress-record.md
  #    § "Reserved extra keys" declares `declared-class=` as *the offered class, normalised to
  #    one token*, for the reason stated there: extras are read back by splitting the field on
  #    spaces, so whitespace inside a preserved value splits one key into two and hands a
  #    reader a `key=value` nobody wrote. The actor side was given that shape first; this is
  #    the class side asserted to the same standard rather than left to a second reading.
  #
  #    BOTH DIRECTIONS ARE DRIVEN FROM ONE POPULATION, and the NEGATIVE is the one that
  #    matters: this arm cleans EVERY unrecognised class, so a change here that mangled a
  #    whitespace-free value would corrupt the common case to fix the rare one.
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
    export KIT_PROGRESS_DIR="$rundir"
    unset KIT_PROGRESS_RUN
    kit_progress "Dev:ID-1" status "no run id in scope"
    KIT_PROGRESS_RUN="" kit_progress "Dev:ID-1" status "run id declared but EMPTY"
    KIT_PROGRESS_RUN="r-1" kit_progress "Dev:ID-1" status "run id in scope"
    KIT_PROGRESS_RUN="r-env" kit_progress "Dev:ID-1" status "explicit wins" "run=r-arg" "event=x"
  ) >/dev/null 2>&1

  local nrun=0
  [ -d "$rundir" ] && nrun="$(cat "$rundir"/*.tsv 2>/dev/null | grep -c . || true)"
  if [ "${nrun:-0}" -ne 4 ]; then
    _control_did_not_run "write the four run-id records ($nrun produced) — nothing below was measured"
  else
    # UNSET AND EMPTY WRITE NO KEY. An empty key is a column that looks answered and is
    # not, and it would make a reader filtering on `run=` collect unrelated records.
    [ "$(grep -c 'run=' "$rundir"/*.tsv 2>/dev/null || echo 0)" -eq 2 ] \
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

  # ── BYTE-IDENTITY, ACROSS ALL THREE PRESERVING KEYS AT ONCE. THIS BLOCK EXISTS BECAUSE
  #    THE CONTROLS ABOVE WERE GREEN WHILE THE FEATURE WAS BROKEN, and the reason is the
  #    population, not the assertion. The class arm's negative half offers `typo` and
  #    `sta.tus`: both whitespace-free, and both — the part that cost — UNDERSCORE-FREE.
  #    So "a whitespace-free value is carried verbatim" was true of every value the suite
  #    drove and false of the writer, which substituted whitespace with `_` and then
  #    trimmed `^_` and `_$`. After the substitution a separator it inserted and one the
  #    caller typed are the same byte, so the trim ate both: `_x` was carried as `x`, and
  #    `_` was carried as the `<empty>` placeholder that means the caller offered nothing.
  #
  #    EXTENDED INTO THIS CASE RATHER THAN GIVEN ITS OWN, deliberately. This is not a new
  #    property — it is the SAME property the class and actor arms above already assert
  #    (`contracts/progress-record.md` § Reserved extra keys: a preserved value is carried
  #    byte for byte), driven against the population those arms lacked. A parallel case
  #    would put one rule in two places, and the next seat widening the population would
  #    widen one of them.
  #
  #    ONE POPULATION, THREE CALL SITES. The population is declared ONCE below, so
  #    widening it is a single edit and it cannot go stale on one arm only. The three keys
  #    are the three sites the writer synthesises — derive them with
  #    `grep -n _pr_tok scripts/lib/progress-record.sh` and a key with no row here is an
  #    arm going untested.
  #
  #    ASSERTED AS EQUALITY AGAINST THE OFFERED VALUE, never as "looks reasonable": the
  #    defect this catches produces output that is perfectly well-formed and simply is not
  #    what the caller wrote, which no shape check can see.
  local tokdir="$SB_TMP/records-tok"
  # Space-separated because the whole population is whitespace-free BY CONSTRUCTION —
  # a value with whitespace in it belongs in the POSITIVE halves above, not here.
  local tok_pop='_ __ ___ _x x_ _x_ _snake_case_ __both__ a_b typo sta.tus no_edge_underscores -_- _._ 13/13 KIT-042 _run_ run_ _run'
  local ntok=0 tok_bad=0 tok_drove=0 _v _arm _key _got
  for _v in $tok_pop; do ntok=$(( ntok + 3 )); done
  # AND THE POPULATION'S OWN PREMISE IS ASSERTED, not just stated in the comment above.
  # Every member must be whitespace-free, because the whole claim is that a value needing
  # NO collapse survives untouched. A member with whitespace in it would be a row this
  # block expects to come back changed, and it would read as a failure of the writer
  # rather than as a badly chosen fixture. The word-split above cannot produce one, so
  # this fires only if the list is later rewritten with quoting — which is exactly when
  # a reader would otherwise be misled.
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

  # ── THE ABLATION (§ 4), EXECUTED. move-issue.sh is the converted role-side producer
  #    and it REFUSES without a valid id, which is all this needs: the refusal path runs
  #    the sourcing block, so removing the library must not change it. A refusal is a
  #    deliberate choice of subject — it exercises the load WITHOUT needing a board, and
  #    an abort from an unguarded `.` under this script's `set -euo pipefail` would show
  #    up here as a changed exit status, which is precisely the failure being excluded.
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
# EVERY WORKTREE OF ONE REPOSITORY WRITES ONE PLACE. A record written from a linked
# worktree lands in the MAIN checkout's .progress-records/ — where the orchestrator
# reads — and survives the worktree's removal, which is what the landing flow does to a
# leg's worktree. The pre-fix library wrote under the worktree's own root; this case is
# red against it. The operand is asserted first: a record in NEITHER tree means the
# library never loaded, and both checks below would then pass on nothing.
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
# CASE — --set-pr WRITES BACK INTO A CARD MINTED FROM THE REAL TEMPLATE
#
# WHY THIS CASE AND NOT A FIXTURE ASSERTION: `--set-pr` writes only into an EXISTING
# `pr:` frontmatter line and otherwise warns "skipping write-back". The harness used
# to seed `pr: null` in its own fixtures while NO shipped template carried the key —
# so the suite tested a shape the templates never produced, and the flag could not
# work on a kit-minted card while passing here. The templates now declare it; this is
# the case that proves the two ends meet, and it mints through new-issue.sh rather
# than seeding, because the seam is precisely between the template and the tool.
#
# THE PREMISE IS ASSERTED IN TWO PLACES, and both were paid for. An earlier attempt at
# this case died on `move-issue.sh` refusing "no file matching …" — a not-found
# refusal that reads like a mover defect and is really the card never reaching the
# trunk. So: the minted card must carry a `pr:` line at all (or the template half is
# undone and this case proves nothing), and it must be ON the trunk before the mover
# is asked to move it (or the refusal is about the fixture).
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
  #     fixture failure, not a case failure (this file's own rule).
  kwt_clear
  # Keep a copy of the NEUTRALIZED sandbox script to restore from. Restoring from
  # $REAL_SCRIPTS instead — which is what this did — re-imports the adopter's tree
  # after the neutralizer removed it, so on a project that ran `kit-init --roles`
  # arms (c) and (d) ran against that project's role whitelist and (c) failed with
  # "--role must be …". Measured. The sandbox owns its scripts; nothing may reach
  # back past _kit_neutral_config for a copy.
  cp "$mi" "$SB_TMP/move-issue.neutral"
  grep -q '^if \[ "\$PROBE_ID_IS_GLOB" -eq 0 \] \\$' "$mi" \
    || _fixture_die "case_move_issue_probe(b): no probe condition to ablate in move-issue.sh — the anchor moved, so arm (a) above is unfalsifiable and this case proves nothing."
  perl -i -pe 's/^if \[ "\$PROBE_ID_IS_GLOB" -eq 0 \] \\$/if false \&\& [ "\$PROBE_ID_IS_GLOB" -eq 0 ] \\/' "$mi"
  grep -q '^if false && \[ "\$PROBE_ID_IS_GLOB" -eq 0 \] \\$' "$mi" \
    || _fixture_die "case_move_issue_probe(b): the ablation did not take."
  out="$( cd "$SB_WORK" && "$mi" "$SB_PREFIX-999" in_progress --role Dev --note x 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) the ablated mover accepted a nonexistent card"
  kwt_registered \
    || cf "(control) with the probe disabled the refusal STILL left no worktree — arm (a) is not measuring the probe: $out"
  cp "$SB_TMP/move-issue.neutral" "$mi"   # restore the NEUTRALIZED script for (c) and (d)
  grep -q '^if \[ "\$PROBE_ID_IS_GLOB" -eq 0 \] \\$' "$mi" \
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

  # (d) A PROBE THAT CANNOT ANSWER FALLS THROUGH — and the provenance line is the
  #     only thing that can tell the two reads apart, which is why it is asserted.
  kwt_clear
  git -C "$SB_WORK" update-ref -d "refs/remotes/origin/$SB_TRUNK" >/dev/null 2>&1
  out="$( cd "$SB_WORK" && "$mi" "$SB_PREFIX-998" in_progress --role Dev --note x 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(d) the mover accepted a nonexistent card with no tracking ref"
  printf '%s\n' "$out" | grep 'no file matching' >/dev/null \
    || cf "(d) the fall-through refusal changed shape: $out"
  printf '%s\n' "$out" | grep 'inside the kanban worktree' >/dev/null \
    || cf "(d) with an unreadable tracking ref the probe did not fall through to the worktree read: $out"

  finish "move-issue.sh: a not-found refusal creates no worktree (ablation-proven), never refuses a card the trunk actually carries, and falls through when it cannot read the ref"
  teardown
}

# =============================================================================
# CASE — THE CONFIG SEAM REFUSES RATHER THAN FALLING BACK.
#
# This case was INVERTED, not deleted, and the reason it exists is unchanged. It
# used to assert the opposite: that with config.sh unsourceable each script fell
# back to a baked-in prefix literal and CARRIED ON. That fallback was added as a
# fix for something worse (a default carrying a FOREIGN project's prefix), and the
# lesson it encoded — a silently wrong prefix is the expensive failure — is the
# same lesson the refusal now encodes, one level up: EVERY script holding its own
# copy of one project's prefix IS the silently-wrong-prefix bug (derive the set —
# grep -l 'config.sh' scripts/*.sh — rather than trusting a count here; this said
# "five" and was true when written), and in the sweep
# it is worse than a bad mint (a sweep under the wrong prefix finds nothing and
# reports "nothing to sweep" on a full column). So the conclusion is superseded
# and the guard is transformed: every one of them must now REFUSE and NAME
# config.sh. ALL of them are asserted, because fixing one in isolation would
# leave the rest inconsistent — which is exactly how the debt survived.
# =============================================================================
case_config_seam_refusal() {
  cf_reset
  if ! has_issue_template; then skp "the config seam REFUSES with a named cause across every prefix consumer" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-203" delta chore "Archive delta"
  publish_sandbox
  # Make config.sh unsourceable — the degraded path under test.
  mv "$SB_WORK/scripts/config.sh" "$SB_WORK/scripts/config.sh.disabled" >/dev/null 2>&1

  # THE CENSUS IS RUN AGAINST THE SANDBOX'S scripts/, and that is load-bearing rather
  # than incidental: THIS FILE also contains the census phrase — it is quoted on the
  # line below — so a tree-wide grep returns one more than there are consumers. The
  # sandbox has no scripts/test (make_sandbox removes it), so the list here is the
  # consumers and nothing else. A reader who greps the whole tree and gets a bigger
  # number has not found a miscount.
  #
  # THE POPULATION IS DERIVED, NOT TYPED. `new-prd.sh` was the sixth prefix consumer
  # and sat outside this loop for as long as the loop was a hand-written list — while
  # the case's own finish string claimed a five-member population. Deriving it from the census
  # the block itself publishes makes the loop and the grep the same set by construction,
  # which is the property that was missing rather than the sixth name.
  #
  # AND THE CENSUS IS KEYED ON THE BLOCK'S CODE, NOT ON ITS HEADER COMMENT — measured, because
  # the earlier pattern ('THE PREFIX HAS ONE AUTHORITY') is a SECTION-HEADER COMMENT and a
  # `grep -l` cannot tell a refusal block from a sentence explaining the absence of one.
  # `subtask.sh` carries that phrase in a comment saying the block is DELIBERATELY not copied
  # there ("pasting a guard for a value this script never reads would add a seventh copy of it
  # while fixing a second-copy defect" — and it is right: ISSUE_PREFIX appears zero times in it).
  # So the old census returned SEVEN and the finish line claimed seven asserted, while the kit
  # has six. The seventh then satisfied both assertions VIA BASH'S OWN SOURCING DIAGNOSTIC
  # under `set -euo pipefail` — nonzero, and the path in that message contains "config.sh" —
  # with zero hits for anything the kit wrote.
  #
  # FILTERING COMMENTS IS NOT THE FIX and was measured before being rejected: the phrase is a
  # header comment in ALL SEVEN, so a non-comment filter returns NOTHING and deletes the census
  # rather than correcting it.
  #
  # WHY THE CODE SHAPE IS THE RIGHT KEY HERE, when deriving from an implementation's shape is
  # usually how a census inherits an accident: this shape IS the declaration. Guarding the
  # source and refusing with a named cause is `process/contracts/config-seam.md`'s obligation
  # discharged, so the idiom tracks membership exactly — where every occurrence proxy guesses.
  # (Proxies measured: "reads ISSUE_PREFIX" drops new-prd.sh, whose seam is PRD_PREFIX, and adds
  # config.sh, which DEFINES the value, and kit-init.sh, which REWRITES it.)
  local s out rc n_consumers=0
  # hout/hrc carry the USAGE and UNKNOWN-OPTION probes below, kept separate from out/rc so the
  # refusal assertions and the argument-clause assertions cannot read each other's result.
  local hout hrc
  #
  # `grep -lF`, AND THE -F IS LOAD-BEARING. Written as a normal pattern this returns NOTHING:
  # `$` mid-expression is read as an end-of-line anchor, so `"$CONFIG"` can never match, and the
  # census silently empties — which would trip the refusal below rather than pass, but only
  # because that refusal exists. Measured while writing this fix: the first attempt returned
  # zero files. `lib/usage.sh`'s header records the same trap for the same reason.
  local consumers; consumers="$(cd "$SB_WORK/scripts" && grep -lF 'if [ ! -f "$CONFIG" ] || ! . "$CONFIG"; then' ./*.sh 2>/dev/null | sed 's@^\./@@' | sort)"
  # THE SEAM'S OWN VALUE, for the no-guessing arm inside the loop, and it is OBTAINED THE WAY A
  # CONSUMER WOULD: source the DISABLED seam in a subshell with the env override unset and read
  # what it defines. Not parsed out of the file — the shipped line is
  # `ISSUE_PREFIX="${ISSUE_PREFIX:-KIT}"`, so a pattern read of the assignment returns the
  # PARAMETER EXPANSION rather than the value, and the arm below would compare against nothing.
  # `env -u`, because a value inherited from this harness's own environment would make the
  # operand the harness's rather than the seam's.
  # `|| true`, and the arm is SKIPPED on an empty result and says so: a seam whose shape changed
  # must not end the run from inside a control.
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
      # subtask.sh joined this census when it gained a seam guard of its own, and its arm is
      # the BARE invocation — deliberately, and it is the arm least likely to rot. It sources the
      # seam before it dispatches a subcommand, so a bare call reaches the sourcing failure rather
      # than a usage error; verified by line order and by running it. No `env -u ISSUE_PREFIX`
      # either: this is the one member that reads NO prefix, and unsetting one would imply it did.
      subtask.sh)      out="$( cd "$SB_WORK" && "$SB_WORK/scripts/$s" 2>&1 )"; rc=$? ;;
      # The three creators that share one shape. NAMED rather than left to a catch-all, for the
      # reason the `*)` arm below now states.
      new-bug.sh|new-issue.sh|new-refactor.sh)
                       out="$( cd "$SB_WORK" && env -u ISSUE_PREFIX "$SB_WORK/scripts/$s" someslug --id "$SB_PREFIX-900" 2>&1 )"; rc=$? ;;
      # THE INVOCATION TABLE IS DECLARED, NOT DEFAULTED — and this arm is the half of this case
      # that was still undeclared after its POPULATION was fixed.
      #
      # It used to be the catch-all above, and that made it a LATENT F.1b GENERATOR: any script
      # that later gained the guarded-source block joined the derived population and was then run
      # with arguments nobody chose for it. It would exit non-zero — because the ARGUMENTS are
      # wrong — and every "it refused" assertion below would pass on a refusal that has nothing
      # to do with the config seam. Measured on the live candidate: `subtask.sh someslug --id
      # XYZ-900` exits 1 with `Unknown command: someslug`, since its CLI is
      # `subtask.sh move <PARENT-ID>-<suffix> <target>`.
      #
      # So a NEW MEMBER HALTS THIS CASE until somebody says how to run it. That is the right
      # failure: the population is derived and cannot go stale, and the invocation cannot be
      # guessed — a case that does not know how to exercise a member knows nothing about it.
      *)               _fixture_die "case_config_seam_refusal: no invocation is declared for scripts/$s, which the guarded-source census returned. This case cannot test a member it does not know how to run: a default invocation refuses for the WRONG REASON (bad arguments, not an unreadable seam) and every assertion below would pass on it. Add an arm to the case above naming how scripts/$s is invoked." ;;
    esac
    [ "$rc" -ne 0 ] || cf "$s: exited 0 with config.sh unsourceable — it fell back instead of refusing"
    printf '%s' "$out" | grep 'config\.sh' >/dev/null \
      || cf "$s: the refusal does not NAME scripts/config.sh: $out"
    # AUTHORSHIP, NOT PRESENCE. Naming the file is satisfied by the INTERPRETER: an unguarded
    # source dies with "<script>: line N: <path>/config.sh: No such file or directory", and that
    # path contains the filename. A refusal the kit did not write is not the kit refusing. The
    # contract path is what only the kit's own block emits — all six cite it, and bash cannot.
    printf '%s' "$out" | grep 'config-seam\.md' >/dev/null \
      || cf "$s: the refusal names config.sh but does not cite process/contracts/config-seam.md — so this may be the interpreter's sourcing diagnostic rather than the kit's guarded refusal, which is the state that let a script with NO guard pass this arm: $out"

    # ── AND § 3's TWO ARGUMENT CLAUSES STILL HOLD ON THIS SAME SEAMLESS TREE. This is the half
    #    of this case that was BLIND: it asserted the refusal and asserted nothing about what the
    #    tools do with an ARGUMENT. WHEN THIS ARM WAS WRITTEN, every member of the census below
    #    except next-id.sh refused a usage request on the tree this case builds — issue-creation.md
    #    § 3's one prohibition ("a request for the usage text is ALWAYS legal and ALWAYS
    #    succeeds"), fired in the state where an operator most needs the text. The cause was
    #    file-scope sourcing above the argument parse; next-id.sh already had the other order and
    #    answered. No count is written here: the population is derived below and the arm asserts
    #    over whatever it returns, so a number in this sentence could only go stale.
    #
    #    THE SAME POPULATION, DERIVED THE SAME WAY, so the refusal half and the argument half
    #    cannot disagree about who is in the set. And NO invocation table is needed here, which
    #    is not the oversight the `*)` arm above exists to prevent: `--help` is the one
    #    invocation § 3 declares legal for every bound tool, so it is derivable from the
    #    contract rather than from per-member knowledge.
    hout="$( cd "$SB_WORK" && "$SB_WORK/scripts/$s" --help </dev/null 2>&1 )"; hrc=$?
    [ "$hrc" -eq 0 ] \
      || cf "$s: --help exited $hrc with config.sh absent — issue-creation.md § 3 says a usage request ALWAYS succeeds, and this is the tree where the operator needs it most: $(printf '%s' "$hout" | tr '\n' '|' | cut -c1-240)"
    # NAMING ITSELF, because rc=0 alone is satisfied by a tool that printed NOTHING — the same
    # hole the CLI-shape case names, and the same remedy.
    printf '%s' "$hout" | grep -F -- "$s" >/dev/null \
      || cf "$s: --help printed nothing naming $s, with config.sh absent — and rc alone is satisfied by a tool that printed nothing at all, so this arm is stated separately from the one above rather than folded into it: $(printf '%s' "$hout" | tr '\n' '|' | cut -c1-240)"
    # AND IT DID NOT GUESS THE VALUE IT COULD NOT READ. § 3's ranked rules for usage text that
    # renders a derived value: it degrades to NAMING the seam and NEVER to the kit's shipped
    # default. Three of the six render a prefix into their usage line, so this arm is the one
    # that separates a reorder from a reorder plus a fallback literal — which is the tempting
    # wrong fix, and the one the seam block itself was written to remove one level up.
    #
    # THE OPERAND IS THE SEAM'S OWN VALUE, obtained by SOURCING the disabled file rather than
    # typed here, so a sandbox that stamps a different prefix does not silently empty this arm.
    # STATED LIMIT: in this sandbox that value IS the kit's shipped placeholder, so this arm
    # cannot tell a GUESSED default from a value read some other way. It does not need to —
    # with the seam absent there is no legitimate route to either.
    if [ -n "${seam_prefix:-}" ]; then
      printf '%s' "$hout" | grep -F -- "${seam_prefix}-NNN" >/dev/null \
        && cf "$s: --help with config.sh absent printed '${seam_prefix}-NNN' — it fell back to a prefix literal instead of naming the seam, and a prefix that is right about the kit and wrong about the project is unfalsifiable from the operator's seat (issue-creation.md § 3): $(printf '%s' "$hout" | tr '\n' '|' | cut -c1-240)"
    fi
    # THE UNKNOWN-OPTION CLAUSE, ON THE FOUR MEMBERS THAT CAN CARRY IT ABOVE THE SEAM — and the
    # split is DERIVED FROM THE GRAMMAR, not chosen. § 3 also fixes a status for an unrecognised
    # option ("refuse, non-zero, naming it ... and in this kit that status is 2"), and below the
    # seam it never gets one: measured, all six exited 1 with the seam refusal.
    #
    # WHY ONLY FOUR. The four creators take a <slug> in leading position, so a dash-leading token
    # THERE is illegal whatever the option list says — the arm re-states no vocabulary. archive.sh
    # (`--apply`) and subtask.sh (`new`) may LEGALLY lead with an option or a subcommand, so an
    # arm above their seam could not tell a bad flag from a good one without holding a SECOND COPY
    # of their option list — the defect § 3's own scar records ("the remedy was one fewer copy,
    # not a better matcher"). Those two keep rc 1 here, and the finish line says so rather than
    # this arm quietly skipping them.
    case "$s" in
      new-bug.sh|new-issue.sh|new-refactor.sh|new-prd.sh)
        hout="$( cd "$SB_WORK" && "$SB_WORK/scripts/$s" --bogus </dev/null 2>&1 )"; hrc=$?
        [ "$hrc" -eq 2 ] \
          || cf "$s: --bogus exited $hrc with config.sh absent, where issue-creation.md § 3 fixes the status for an unrecognised option at 2 — a caller scripting against the set cannot branch on a status that means 'unknown option' in one tree and 'seam missing' in another: $(printf '%s' "$hout" | tr '\n' '|' | cut -c1-240)"
        printf '%s' "$hout" | grep -F -- '--bogus' >/dev/null \
          || cf "$s: the unrecognised-option refusal does not NAME --bogus, which § 3 requires of it: $(printf '%s' "$hout" | tr '\n' '|' | cut -c1-240)" ;;
    esac
  done

  # ── INSTRUMENT CHECK FOR THE ARMS ABOVE. Written OUTSIDE scripts/ so the census cannot pick it
  #    up and turn the control into a subject — the same construction, and the same reason, as the
  #    CLI-shape case's probe. Each arm must be shown able to FAIL, because they all passed on the
  #    very first run of the fixed tree and a green that has never been red is a wish.
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
    # WHAT CARRIES THIS ARM, STATED so nobody reads the rc check as the assertion: in a
    # sandbox there is no PRD template, so new-prd.sh would exit non-zero on that alone
    # and the `rc -ne 0` check below CANNOT FAIL here. The arm is carried entirely by the
    # naming check — that the refusal says PRD_PREFIX rather than something else. The rc
    # check stays because it is free and would matter in a tree that has the template.
    #
    # BLANK THE SEAM, NOT THE ENVIRONMENT. config.sh reads PRD_PREFIX="${PRD_PREFIX:-PRD}",
    # so an empty env var is replaced by the default and the guard never fires — measured:
    # the run got as far as the template check and reported that instead. The empty seam
    # has to be empty IN THE FILE, which is also the state an adopter can actually reach.
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
  # new-prd.sh mints into requirements/, not progress/ — so the two checks above do not
  # cover the one consumer whose output lands somewhere else. Asserting refusal without
  # asserting inaction is half a measurement.
  # VACUOUS ON A CLEAN RUN, and that is the honest description: the sandbox has no
  # requirements/ at all, so `find` over a missing directory finds nothing whatever the
  # script did. It bites the moment anything CREATES that directory — which is exactly
  # the mint this asserts against — so it is a real assertion with a stated blind spot,
  # not a green that could never go red. Its control planted precisely that.
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

  finish "next-id.sh: max+1 (filenames + ARCHIVE.md), <PREFIX>-NNN shape, nonzero on an empty board"
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
  # THE CANONICAL EXPRESSION, byte-identical to lib/role-set.sh's kit_role_set and to the
  # other three sites. It used to carry a trailing `.*`, which silently tolerated content
  # after the closing quote that no other reader accepts — the kind of divergence that
  # makes two sites disagree about the same file with nothing in either to show it.
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
  local exempt=("Merge branch 'x'" "Revert \"something\"" "fixup! earlier commit")
  local s
  for s in "${exempt[@]}"; do
    printf '%s\n' "$s" > "$msg"
    ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 0 ] || cf "auto-exempt subject rejected: '$s' (exit $rc)"
  done

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
  # DERIVE the markers from the hook's own TOOL_TRAILER_MARKERS line, for the same
  # reason the prefixes are derived: a project extends that list, and a restated
  # copy here would make these assertions vacuous the day it does.
  #
  # WHAT DERIVING COSTS, STATED because a reddening control measured it: this arm
  # asserts THE RULE WORKS FOR WHATEVER MARKERS ARE DECLARED — not that the declared
  # set is the right one. Replace TOOL_TRAILER_MARKERS with a single word that matches
  # nothing real and every assertion below still passes, because the arm then tests the
  # hook against that word. Only the empty case is caught, by the derivation check. So
  # a NARROWED marker list is invisible here by construction; what this arm defends is
  # the enforcement, and deleting RULE (2) from the hook is what reddens it.
  local role markers marker
  role="${prefixes%%|*}"
  markers="$(sed -n "s/^TOOL_TRAILER_MARKERS='\\(.*\\)'.*/\\1/p" "$hook")"
  [ -n "$markers" ] || cf "could not derive TOOL_TRAILER_MARKERS from the hook"
  marker="${markers%%|*}"
  # The refusal prints that list VERBATIM, so it must stay plain words — a regex
  # metacharacter in it would be a lie in the help text and a live pattern in the match.
  printf '%s' "$markers" | grep -E '^[a-z0-9|]+$' >/dev/null \
    || cf "(trailer) TOOL_TRAILER_MARKERS is not the plain-word list the refusal prints: '$markers'"

  # `git commit -v` hands the hook the RAW DIFF below the scissors line — uncommented,
  # context lines carrying one leading space. Editing a file that contains a trailer is
  # not writing one, so this must be ACCEPTED. (\x escapes keep this file ASCII; the
  # emoji is there because the shape the tooling emits leads with decoration, not with
  # the word "Generated".)
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

  # ── NO SPACE AFTER THE COLON. This is the ablation for a hole this guard actually had:
  #    the pre-marker context was once a REQUIRED `[^[:alnum:]]` rather than an optional
  #    group, so with the marker butted against the colon there was nothing for it to
  #    consume and the trailer walked through. One deleted space defeated the rule.
  #    Measured on the hook as it then shipped: the spaced form refused, this one
  #    ACCEPTED. It is a case and not only a note because the matcher is one edit away
  #    from the same shape, and nothing else here would notice.
  printf '[%s] a valid subject\n\nCo-Authored-By:%s <noreply@example.com>\n' "$role" "$marker" > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] \
    || cf "(trailer) 'Co-Authored-By:$marker' with NO SPACE after the colon was accepted — the pre-marker context in rule 2's matcher is a required character again instead of an optional group, and deleting one space defeats the guard"

  #    …and several spaces must not defeat it either, in the other direction.
  printf '[%s] a valid subject\n\nCo-Authored-By:   %s   <noreply@example.com>\n' "$role" "$marker" > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] || cf "(trailer) a padded 'Co-Authored-By:   $marker' was accepted"

  # ── AND THE FALSE-POSITIVE GUARD THE FIX MUST NOT COST. A human whose name merely
  #    BEGINS with a marker's stem is not a tool trailer, and the trailing
  #    `([^[:alnum:]]|$)` is the only thing keeping them out of the refusal. Widening the
  #    matcher to catch the unspaced form is one careless edit away from dropping this,
  #    which would refuse a real contributor by name — a far worse failure than the hole.
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
# CASE — THE TRUNK FALLBACK IS LOUD. With no <remote>/HEAD and no
# init.defaultBranch, the resolution chain reaches its last-resort literal — and
# that used to be SILENT the whole way down, so a fresh repository got a trunk
# name nobody chose and found out when the first board move pushed to it. The
# chain is kept (a hard refusal would break every read-only caller); what is
# asserted here is that each fallback step SAYS which step it used.
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

  # Step 2: no <remote>/HEAD, but init.defaultBranch is set. NOTE the command:
  # <remote>/HEAD is a SYMBOLIC ref, and `update-ref -d` does not remove one — a
  # setup that used it silently left the ref in place, so the case passed by
  # never reaching the fallback at all. `symbolic-ref -d` is the one that works.
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
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-310" dev_complete \
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
# A DECLINE WITH NO RECORDED WHY IS A DELETION WITH EXTRA STEPS. The reasoning is the
# entire value of a declined card: a parked card's blocker can be rediscovered by
# trying again, but a refusal's argument is the only thing the card still carries once
# the work is not going to happen. Strip it and the column holds a list of titles
# nobody can act on, and the next person to propose the same thing pays for the
# refutation a second time.
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

# =============================================================================
# CASE — THE AUXILIARY WORKTREE'S DIRTY GUARD: REPORTS WIDELY, REFUSES NARROWLY.
#
# The guard used to print, as its keep-your-work option, a blanket `git add -A` in a
# worktree whose HEAD IS the trunk and whose push target IS the trunk, with nothing in
# between — and it read `status --porcelain -uno`, so it could not SEE half of what that
# recipe would commit. In one adopting project a commit made in that directory replaced
# the project README with a generated distribution page and added four release artifacts
# to main.
#
# THE `-uno` IS NOT THE BUG AND MUST NOT BE "FIXED". Its recorded reason is correct and
# measured: it scopes a DESTRUCTION guard to exactly what `reset --hard` destroys, and
# reset --hard leaves untracked files alone. The defect was the MISMATCH — a guard scoped
# to what would be destroyed, printing a remedy scoped to everything in the tree. So the
# report widens and the REFUSAL does not, and leg (ii) is what holds that line: an
# untracked file ALONE must not block a board operation, or every stray editor dropping
# becomes an outage.
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
  # `add -A &&` — the RECIPE shape, not the bare string. The refusal now WARNS about
  # `add -A` in prose, so a bare match finds this arm's own warning text and reddens on
  # the fix. (It did, on the first run of this case.) The recipe is the thing that must
  # be gone; the warning is the thing that must be there.
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
# A shipped role doc and a shipped skill both told adopters that a loose edit to their
# own checkout "is destroyed" when move-issue.sh runs. It is not: the mover's own
# contract is that the operator's checkout is NEVER switched, it has no dirty-tree
# refusal because the checkout's state is irrelevant to it, and the only `reset --hard`
# in the worktree library is scoped to the kanban worktree. Both sentences were written
# in the initial commit and neither had been touched since.
#
# THE REAL HAZARD IS STRANDING, NOT DESTRUCTION, and it is worth a different warning: the
# move commits a `git mv` on the trunk while the edit sits at the OLD path in a checkout
# the mover deliberately did not fast-forward. Nothing is lost; the next pull collides.
#
# THIS ASSERTS THE EFFECT, which is why it is worth having where a text-match would not
# be: it measures the file's bytes and the checkout's HEAD, not what any document says.
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
  before_hash="$(shasum "$card" | awk '{print $1}')"
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
  [ "$(shasum "$card" 2>/dev/null | awk '{print $1}')" = "$before_hash" ] \
    || cf "the operator's uncommitted edit was MODIFIED — 'destroyed' is what two shipped documents claimed, and this case exists because it is not true"
  [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$before_head" ] \
    || cf "the main checkout's HEAD moved — the mover fast-forwarded a checkout it promises never to switch"

  finish "move-issue.sh leaves a dirty main checkout byte-identical — the file, its bytes and HEAD all survive a move that lands on the trunk (the hazard is stranding at the old path, not destruction)"
  teardown
}

# =============================================================================
# CASE — A PARTIAL PREFIX DERIVATION REPORTS ITSELF PARTIAL, AND THE INITIALIZER
#        REFUSES THE VALUE THAT CAUSES ONE.
#
# Two halves of one contract, only one of which had been written. kit-init validated
# --prefix and not --prd-prefix, so `--prd-prefix REQ-2` was accepted and stamped; the
# hygiene instrument derives its id pattern with `([A-Za-z0-9]+)` and could not then read
# that key. Its `_id_prefixes` returned `derived=True` for a list of length one, so the
# instrument silently stopped seeing PRD ids WHILE REPORTING ITSELF FULLY DERIVED —
# `id_prefixes_derived_from_seam` is the flag a reader uses to tell a real zero from a
# blind one, and a partial derivation is the blind case wearing the confident flag.
#
# BOTH ARMS ARE NEEDED. Validation closes one route to a half-derivation; only the flag
# can tell a reader when some other route was taken.
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
# CASE — EVERY LINK BELOW THE FIRST SAYS SO, IN ALL THREE IMPLEMENTATIONS.
#
# The trunk chain — <remote>/HEAD → init.defaultBranch → the kit's last-resort constant
# — is implemented three times: in kwt_resolve, in check-board.sh and in release.sh.
# It CANNOT be single-sourced as a function: release.sh sources nothing from scripts/lib/
# by a standing ruling stated in its own header. So the invariant is what has to be held,
# and this case is what holds it.
#
# WHAT WENT WRONG WITHOUT IT: kwt_resolve warns at steps 2 and 3; release.sh warned at
# step 3 ONLY, so a cut against init.defaultBranch went out silent — and step 2 is where
# a real cut lands, because a developer machine usually HAS that config set; check-board
# warned at NEITHER, while its own comment claimed parity with the library. A report
# whose every trunk arm is about a branch, printed against a guessed branch name, is the
# one case where a clean report is worse than none.
#
# THE THREE STATES ARE BUILT BY REMOVAL, in order, from a sandbox that starts at step 1.
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
  out="$(cb_run 2>&1)" || true
  printf '%s' "$out" | grep 'step 3' >/dev/null \
    || cf "(step 3) check-board fell to the last-resort constant and said nothing: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  out="$(run_release 1.1.0 --dry-run 2>&1)" || true
  printf '%s' "$out" | grep 'is a GUESS' >/dev/null \
    || cf "(step 3) release.sh fell to the last-resort constant with no warning: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # ── AND THE THREE AGREE ON THE ANSWER, which is the other half of "one chain".
  #    Derived from the library, so the expected value has one author.
  local last_resort
  last_resort="$(sed -n 's/^KWT_TRUNK_LAST_RESORT="\${KWT_TRUNK_LAST_RESORT:-\([^}]*\)}"/\1/p' \
                   "$SB_WORK/scripts/lib/kanban-worktree.sh" | head -1)"
  [ -n "$last_resort" ] \
    || _fixture_die "case_trunk_chain_announces_every_fallback: could not read the last-resort constant — the expected value would be empty and both arms below would pass on nothing."
  printf '%s' "$out" | grep -F "'$last_resort'" >/dev/null \
    || cf "release.sh's step-3 guess is not the library's constant '$last_resort' — the three implementations agree on the WARNING and not on the ANSWER"
  out="$(cb_run 2>&1)" || true
  printf '%s' "$out" | grep -F "$last_resort" >/dev/null \
    || cf "check-board's step-3 trunk is not the library's constant '$last_resort'"

  finish "all three implementations of the trunk chain announce every link below the first — check-board at steps 2 and 3, release.sh at both (step 2 was silent, and it is where a real cut lands) — none of them announces at step 1, and both agree with the library on the step-3 constant"
  teardown
}
