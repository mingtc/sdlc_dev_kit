# KIT-CLASS: MIXED — self-test harness, cases about the harness itself. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/harness.sh — sourced by scripts/test/run.sh, never run on its own.
# The cases whose subject is this harness: the self-reading censuses, then ship state and
# the isolation check, which CASES runs last.
# =============================================================================

# _role_literals_used <file> — every role NAME this harness writes, extracted BY
# POSITION rather than by neighbouring words. Position is what makes it precise: the
# same tokens appear inside diagnostic strings ("the release commit carries no [Role]
# prefix", "every --role literal in this file") and those are prose ABOUT roles, not
# roles being used. A word-proximity scan picks them up; an argument-position scan
# does not. Measured on this file: by position the answer is exactly the four roles
# the cases use, with no exemption list to maintain.
_role_literals_used() {  # <path to a harness source>
  local f="$1"
  {
    # (1) `--role <Name>` argument positions.
    grep -vE '^[[:space:]]*#' "$f" | grep -oE '\-\-role +[A-Z][A-Za-z0-9]*' | sed 's/--role *//'
    # (2) a role tag OPENING a commit-subject argument: -m "[Name] …"
    grep -vE '^[[:space:]]*#' "$f" | grep -oE -- "-q?m +[\"']\[[A-Z][A-Za-z]+\]" \
      | grep -oE '\[[A-Z][A-Za-z]+\]' | tr -d '[]'
    # (3) a role tag OPENING a seeded Activity / progress.md line.
    grep -vE '^[[:space:]]*#' "$f" | grep -oE -- "(printf|echo)[^\"']*[\"'][^\"']*\[[A-Z][A-Za-z]+\] " \
      | grep -oE '\[[A-Z][A-Za-z]+\]' | tr -d '[]'
  } | sort -u
}

# =============================================================================
# CASE — EVERY ROLE LITERAL THIS HARNESS WRITES IS ONE THE SANDBOX DECLARES
#
# WHAT THIS GUARDS, AND WHAT ALREADY GUARDS THE REST. case_ship_state asserts the
# SHIPPED commit-msg still carries the role set this file declares — that is the
# constant-vs-file direction. Nothing asserted the other direction: that the names the
# CASES TYPE are members of that set. The neutralizer corrects the sandbox's hook and
# move-issue.sh whitelist; it cannot correct a case that types a role the hook does not
# carry, and such a case fails with "--role must be …" or a rejected commit — a red
# about the fixture wearing the costume of a tool defect.
#
# THE FORM IS NARROWER THAN THE ONE FIRST PROPOSED, and the reason is kept because the
# first form would now be wrong. The original proposal was to FORBID role literals
# outright, which was right while the sandbox inherited the adopter's set: a literal was
# then one rename away from a false red. Once the sandbox DECLARES the set, the literals
# are correct — and three cases model a hand-off, so they need two distinct ones. What
# survives is membership, not abstinence.
# =============================================================================
case_role_literals_are_declared() {
  cf_reset
  make_sandbox   # for SB_TMP + teardown; this case reads the harness's own text, not the sandbox

  local self="$SB_TMP/rolepop.sh" used n t
  if ! _harness_probe_copy "$self" || [ ! -s "$self" ]; then
    skp "every role literal this harness writes is one the sandbox declares" "cannot locate this harness's own source"
    teardown; return
  fi
  _harness_population_is_whole "$self"

  used="$(_role_literals_used "$self")"
  n="$(printf '%s\n' "$used" | grep -c . || true)"
  # ASSERT THE OPERAND: zero literals found means the scan lost its subject, not that
  # the file is clean — every one of the shapes above would have to vanish at once.
  [ "$n" -ge 1 ] \
    || cf "no role literal was found in the harness's text at all — the scan lost its operand rather than finding a clean file"

  while IFS= read -r t; do
    [ -n "$t" ] || continue
    printf '%s\n' "$KIT_NEUTRAL_ROLE_PREFIXES" | tr '|' '\n' | grep -x "$t" >/dev/null \
      || cf "this harness writes the role '$t', which the sandbox's declared set does not contain (${KIT_NEUTRAL_ROLE_PREFIXES}) — the neutralized commit-msg hook and move-issue.sh whitelist would both reject it, and the case would redden about the fixture while naming a tool"
  done <<ROLE_EOF
$used
ROLE_EOF

  # ── THE REDDENING CONTROL, on a COPY — never this file (instruments.md § A.2).
  local probe="$SB_TMP/roleprobe.sh"
  cp "$self" "$probe" 2>/dev/null || true
  if [ ! -f "$probe" ]; then
    _control_did_not_run "copy this harness to plant into"
  else
    # THE OUTSIDER'S NAME IS BUILT, NEVER WRITTEN — and that is not fastidiousness, it
    # is required. This case scans THE FILE IT LIVES IN, so a literal `--role Eng`
    # written here would be found by the scan above and redden the case on its own
    # control text. Measured: it did, on the first draft. `%s` carries the name into
    # the PROBE while this source holds only the format string.
    local outsider='Eng'
    printf '\n  ( cd x && ./scripts/move-issue.sh ID in_progress --role %s --note x )\n' \
      "$outsider" >> "$probe"
    _role_literals_used "$probe" | grep -x "$outsider" >/dev/null \
      || cf "(control) a planted '--role $outsider' was NOT found by the scan — it cannot see the defect it is named after"
    # ...and the membership test must reject it, or finding it buys nothing.
    printf '%s\n' "$KIT_NEUTRAL_ROLE_PREFIXES" | tr '|' '\n' | grep -x "$outsider" >/dev/null \
      && cf "(control) '$outsider' IS in the declared set, so the plant cannot demonstrate a rejection — pick a name the set does not contain"
  fi

  finish "every role literal this harness writes is a member of the set the sandbox declares — $n found by argument position ($(printf '%s' "$used" | tr '\n' ' ')), and a planted outsider is found and rejected"
  teardown
}

# =============================================================================
# CASE — EVERY CASE THAT MINTS A CARD PROBES FOR THE TEMPLATE FIRST.
#
# Measured when this was written: removing .claude/templates/ISSUE.template.md from the
# built tree gave 2 FAIL alongside 8 clean skips. The two failures were cases that mint
# a card and never asked whether the template exists — so a capability the TREE lacks
# was reported as a defect in the SUBJECT.
#
# THE POPULATION IS DERIVED, and that is the whole point of the case rather than the two
# lines it guards. "Which cases mint a card?" is answerable from the file — the ones that
# invoke a creation script — so case eleven cannot arrive without a probe and go unnoticed
# until somebody removes the template again. Enumerating the two would have fixed the
# instances and left the class, which is this board's most-repeated mistake.
# =============================================================================
case_minting_cases_probe_for_the_template() {
  cf_reset
  make_sandbox
  local self="$SB_TMP/mintpop.sh" probe="$SB_TMP/mintprobe.sh"
  _harness_probe_copy "$self" \
    || _fixture_die "case_minting_cases_probe_for_the_template: could not copy the harness's own source to census."
  _harness_population_is_whole "$self"

  # Excise this case's own body: its derivation names the creation scripts it looks for,
  # so a census over the whole file reports this case as an unguarded minter.
  awk -v fn="case_minting_cases_probe_for_the_template" '
    $0 ~ "^" fn "\\(\\) \\{" { skip=1 }
    skip && /^\}$/            { skip=0; next }
    !skip
  ' "$self" > "$probe"
  grep -q '^case_minting_cases_probe_for_the_template() {' "$probe" \
    && _fixture_die "case_minting_cases_probe_for_the_template: the excision left this case's own body in the probe."

  # For each case function: does it invoke a creator, and does it probe?
  local rows n=0 bad=0 row
  rows="$(awk '
    /^case_[a-z_0-9]+\(\) \{/ { fn=$0; sub(/\(\).*/,"",fn); mint=0; probe=0; next }
    /^\}$/ {
      if (fn != "" && mint) printf "%s|%d\n", fn, probe
      fn=""; next
    }
    # WIDE ON PURPOSE: two cases reached the creators through a GLOB
    # ("$SB_WORK"/scripts/new-*.sh) and a basename, and a pattern listing the four names
    # literally found neither. Both were real gaps — one of them aborted the whole run
    # with a fixture failure when the template was removed, which is worse than the FAIL
    # this item was filed about.
    # kit_init_sandbox is in here because kit-init COPIES the template into its tree and
    # refuses the preflight without it — the same capability, reached by a helper rather
    # than by a creator. The signal is the CALL, not a mention: `kit-init.sh` in a comment
    # matched two cases that never run it.
    # ...AND A COMMENT IS NOT A CALL. The note above says "the signal is the CALL, not a
    # mention" and the pattern still matched mentions: a comment naming subtask.sh, added to
    # an unrelated case on 2026-09-04, made this guard report that case as unguarded. Skip
    # comment lines before testing, so the rule matches the sentence that states it.
    fn != "" && $0 !~ /^[[:space:]]*#/ && /new-[a-z*]*\.sh|subtask\.sh|kit_init_sandbox/ { mint=1 }
    fn != "" && /has_issue_template/                                            { probe=1 }
  ' "$probe")"

  while IFS= read -r row; do
    [ -n "$row" ] || continue
    n=$((n + 1))
    [ "${row#*|}" = "1" ] && continue
    bad=$((bad + 1))
    cf "${row%%|*} invokes a creation script and never calls has_issue_template — on a tree without .claude/templates/ISSUE.template.md it FAILS instead of skipping, reporting a missing capability as a defect in the subject"
  done <<EOF
$rows
EOF

  # ── INSTRUMENT CHECK: a negative census whose derivation finds nothing is green
  #    forever. Assert it still finds the population it is judging.
  [ "$n" -ge 5 ] \
    || _fixture_die "case_minting_cases_probe_for_the_template: the derivation found only $n card-minting case(s) — the creator names or the case-function shape changed, and 'all of them probe' would then be true of almost nothing."

  finish "all $n cases that invoke a creation script probe for the issue template first, so a tree without it SKIPS rather than reporting a missing capability as a defect — and the population is derived from the harness's text, so the next minting case cannot arrive unguarded"
  teardown
}

# =============================================================================
# CASE — VICTIM SELECTION SURVIVES PIPEFAIL.
#
# Four control blocks picked their victim with `find … | head -1`, which is the exact
# shape this file's own header forbids by name: the reader exits early, `find` takes
# SIGPIPE, and `pipefail` promotes the producer's death to the pipeline's status. The
# value is still correct — that is what makes it invisible — but the STATUS is wrong, and
# a caller that ever tested the status would read "no victim" on a probe full of victims.
#
# HONEST FRAMING: measured on this machine, the raw pipeline first fails around 300 files
# and the kit's largest real corpus here is 20. This is a threshold nobody has crossed,
# fixed for consistency with the header the three origin_* helpers were already rewritten
# for — not a live bug. The case is built so it cannot pretend otherwise.
# =============================================================================
case_probe_victim_selection_survives_pipefail() {
  cf_reset
  make_sandbox
  local big="$SB_TMP/pipebig" i v rc hit=0

  # ── INSTRUMENT CHECK, and it is what makes this case honest: BUILD the hazard before
  #    asserting anything about it. If this environment's pipe buffer cannot produce a
  #    SIGPIPE at all, every assertion below is vacuous — so say so as a SKIP, which is
  #    this file's way of making a statement about the environment rather than the code.
  mkdir -p "$big"
  for i in $(seq 1 3000); do : > "$big/f$i.md"; done
  for i in 1 2 3; do
    if ! ( set -o pipefail; find "$big" -type f | head -1 >/dev/null ); then hit=1; break; fi
  done
  if [ "$hit" -eq 0 ]; then
    skp "probe victim selection survives pipefail" \
        "3000 files did not make 'find | head -1' fail under pipefail here — this environment cannot produce the hazard, so the assertions would be vacuous"
    teardown; return
  fi

  # THE EFFECT — the STATUS and the value. Asserting only the value is a green that could
  # not go red: the raw pipeline gets the value right and the status wrong, which is the
  # entire defect.
  rc=0; v="$(probe_pick "$big" -type f)" || rc=$?
  [ "$rc" -eq 0 ] \
    || cf "probe_pick exited $rc on a corpus where the raw pipeline SIGPIPEs — the status is still the producer's death, not the answer"
  [ -n "$v" ] && [ -f "$v" ] \
    || cf "probe_pick returned '$v', which is not an existing file — the replacement gets the status right and the answer wrong, which is worse than what it replaced"

  # …and it still returns NOTHING, nonzero, when there is genuinely nothing to find.
  rc=0; v="$(probe_pick "$SB_TMP/pipebig" -name 'nothing-matches-this' -type f)" || rc=$?
  [ -z "$v" ] \
    || cf "probe_pick invented a victim for a pattern that matches nothing: '$v'"

  # THE CENSUS — the four sites are the point, not the helper. A fifth `find … | head -1`
  # typed tomorrow puts the hazard straight back.
  local self="$SB_TMP/pipepop.sh" probe="$SB_TMP/pipeprobe.sh" m1='find ' m2='| head -1'
  _harness_probe_copy "$self" \
    || _fixture_die "case_probe_victim_selection_survives_pipefail: could not copy the harness's own source to census."
  _harness_population_is_whole "$self"
  # EXCISE THIS CASE'S OWN BODY. Its instrument check BUILDS the forbidden pipeline on
  # purpose — that is how it proves the hazard exists here — so a census over the whole
  # file reports the very line that makes the case honest.
  awk -v fn="case_probe_victim_selection_survives_pipefail" '
    $0 ~ "^" fn "\\(\\) \\{" { skip=1 }
    skip && /^\}$/                { skip=0; print ""; next }
    skip { print ""; next }
    { print }
  ' "$self" > "$probe"
  grep -q '^case_probe_victim_selection_survives_pipefail() {' "$probe" \
    && _fixture_die "case_probe_victim_selection_survives_pipefail: the excision left this case's own body in the probe — the census would report its own instrument check."
  local rows
  rows="$(awk -v a="$m1" -v b="$m2" '
    /^[[:space:]]*#/ { next }
    index($0,a) && index($0,b) { print NR ": " $0 }
  ' "$probe" | _harness_where)"
  [ -z "$rows" ] \
    || cf "a find/head pipeline is back, and run.sh's header forbids it by name: $(printf '%s' "$rows" | tr '\n' ' ' | cut -c1-200)"

  # ── THE SAME HAZARD, THE OTHER READER: `… | grep -q` behind a pipe.
  #    ASSERT THE CONSTRUCT'S ABSENCE, NOT ITS SYMPTOM, and that choice is measured
  #    rather than stylistic: the false red only appears once the producer clears the
  #    64KB pipe buffer, so a case that pipes a REALISTIC payload and waits for a red
  #    stays green forever and certifies the defect as fixed. Below the buffer there is
  #    nothing to see; above it every run fails. A threshold that sharp cannot be
  #    sampled, so the census is the only honest instrument.
  #    NOTE WHAT IS NOT FORBIDDEN: a bare `grep -q FILE` with no pipe has no producer,
  #    cannot SIGPIPE anything, and is the correct form — this looks for a PIPE first.
  local qrows
  qrows="$(awk '
    /^[[:space:]]*#/ { next }
    /\|[[:space:]]*grep -q/ { print NR ": " $0 }
  ' "$probe" | _harness_where)"
  [ -z "$qrows" ] \
    || cf "a 'grep -q' behind a pipe is back, and under pipefail it reports the PRODUCER'S death instead of the reader's answer once the producer clears the pipe buffer — drop the -q and redirect (\`| grep -F pat >/dev/null\`), which drains the input and returns the identical status: $(printf '%s' "$qrows" | tr '\n' ' ' | cut -c1-200)"

  # ── THE SHIPPED POPULATION, and widening to it is the point of this arm.
  #    The census above reads only THIS FILE, so it could not see the very scripts an
  #    adopter runs — and those are where the producer grows with THEIR project, which
  #    is the condition that makes the defect reachable at all. A guard that certifies
  #    the harness while the shipped tree carries the construct is a guard that reads
  #    as armed and is not.
  #
  #    WHAT IS FORBIDDEN HERE IS NARROWER THAN ABOVE, ON PURPOSE. In this file every
  #    piped `grep -q` is forbidden, because every producer here is a fixture that can
  #    be grown. In the shipped scripts the kit DELIBERATELY LEAVES the pipelines whose
  #    producer is one flag value being validated — `printf '%s' "$NUM" | grep -qE
  #    '^[0-9]+$'` — since a single argument cannot approach the 64KB buffer and the
  #    rewrite would be churn. So this census looks for a producer that CAN grow: a
  #    command that reads the repository, the board or the network. That is the
  #    header's own test, applied to the tree we ship rather than to the tree we test.
  #
  #    THE HARNESS IS EXCLUDED AS A POPULATION, NOT BY ITS ENTRY POINT'S PATH. Excluding
  #    one path left every other file of the harness to be judged by the NARROWER shipped
  #    rule instead of the harness rule above. The set the harness census reads is the set
  #    this one leaves out, so each file is judged by exactly one of the two rules.
  local shipped_rows shipped_files
  shipped_files="$(find "$REAL_SCRIPTS" "$REAL_REPO_ROOT/consumers" -type f \
                     \( -name '*.sh' -o -name 'commit-msg' \) 2>/dev/null \
                   | grep -vxF -f <(_harness_sources) || true)"
  [ -n "$shipped_files" ] \
    || _fixture_die "case_probe_victim_selection_survives_pipefail: found no shipped scripts to census — a guard over an empty population passes forever."
  #    THE PRODUCER IS OFTEN ON A DIFFERENT LINE. `lib/kanban-worktree.sh` writes
  #    `git -C … worktree list --porcelain \` and puts `| grep -qxF …` on the NEXT line,
  #    so a single-line pattern demanding producer-and-reader together silently matches
  #    nothing — which is how the first draft of this arm stayed green through its own
  #    ablation. Carry the previous non-comment line and test the JOINED pair instead.
  shipped_rows="$(printf '%s\n' "$shipped_files" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    awk -v fn="$f" '
      /^[[:space:]]*#/ { next }
      {
        # Join ONLY across a real line-continuation. Joining unconditionally leaks the
        # previous statement verb into this one and reddens the flag validators that
        # this arm deliberately permits (a printf of one flag value piped into grep -qE,
        # sitting under an unrelated find) - measured as a false positive while writing
        # this. NOTE: no apostrophes or quotes in this comment; it lives inside a
        # single-quoted awk program, and one would end the program early.
        joined = (prev ~ /[\\]$/) ? prev " " $0 : $0
        if (joined ~ /(git|find|ls|cat|_ship_manifest_paths)[^|]*\|[[:space:]]*grep -q/)
          print fn ":" NR ": " $0
        prev = $0
      }
    ' "$f"
  done)"
  [ -z "$shipped_rows" ] \
    || cf "a SHIPPED script pipes a growable producer into 'grep -q', which under pipefail returns the producer's SIGPIPE instead of the reader's answer once it clears the 64KB buffer — on an adopter's tree that is a refusal of a good state. Drop the -q and redirect (\`| grep -F pat >/dev/null\`): $(printf '%s' "$shipped_rows" | tr '\n' ' ' | cut -c1-300)"

  finish "probe_pick returns the first match with the RIGHT STATUS on a corpus that makes 'find | head -1' SIGPIPE under pipefail (the value was never the problem; the status was), returns nothing for a pattern that matches nothing, neither a find/head pipeline nor a piped 'grep -q' remains in this harness, and no SHIPPED script pipes a growable producer into 'grep -q'"
  teardown
}

# =============================================================================
# CASE — EVERY LANDING PROLOGUE IS THE WHOLE FOUR-STEP.
#
# THIS CASE EXISTS BECAUSE OF A PARTIAL DECLINE. It was proposed that the landing
# prologues be collapsed into one `fpr_sandbox` helper. Declined, measured: most of them
# use a CARD slug that differs from the BRANCH slug, and that divergence is what
# exercises finish-pr.sh reading the card's `branch:` field instead of inferring it from
# the filename. A helper that erases it loses coverage; one that keeps it needs five
# positional arguments and hides the very difference a reader should see.
#
# What the collapse WOULD have bought is that an incomplete prologue becomes impossible.
# This buys that mechanically instead: the copies stay, and a copy that dropped a step is
# named by line number rather than found by diffing cases against each other.
# =============================================================================
case_landing_prologue_is_complete() {
  cf_reset
  make_sandbox
  local self="$SB_TMP/prologuepop.sh" probe="$SB_TMP/prologueprobe.sh"
  _harness_probe_copy "$self" \
    || _fixture_die "case_landing_prologue_is_complete: could not copy the harness's own source to census."
  _harness_population_is_whole "$self"

  # EXCISE THIS CASE'S OWN BODY FROM THE PROBE. It scans the file it lives in, and its
  # own derivation names every token it searches for — so without this it reports itself,
  # by line number, forever. Building the patterns from variables does not help: they
  # would still sit inside the window the census looks at.
  awk -v fn="case_landing_prologue_is_complete" '
    $0 ~ "^" fn "\\(\\) \\{" { skip=1 }
    skip && /^\}$/           { skip=0; print ""; next }
    skip { print ""; next }
    { print }
  ' "$self" > "$probe"
  # Anchored at the DEFINITION: the name also appears in the CASES registry, which the
  # excision does not (and must not) remove.
  grep -q '^case_landing_prologue_is_complete() {' "$probe" \
    && _fixture_die "case_landing_prologue_is_complete: the excision did not remove this case's own body from the probe — every finding below would be about this case's own derivation."

  # A LANDING PROLOGUE is a dev_complete card seeded right after make_sandbox in a case
  # that then invokes finish-pr.sh. That last clause is the operand definition and it
  # matters: `seed_issue dev_complete` also appears as ordinary BOARD CONTENT in cases
  # about other subjects, and counting those would report findings against fixtures that
  # have no reason to publish or branch at all.
  local rows n
  rows="$(awk '
    { L[NR]=$0 }
    END {
      for (i=1;i<=NR;i++) {
        if (L[i] !~ /seed_issue dev_complete/) continue
        ms=0; for (j=i-1;j>=i-8 && j>=1;j--) if (L[j] ~ /make_sandbox/) { ms=j; break }
        if (!ms) continue
        fpr=0; for (j=i+1;j<=i+30 && j<=NR;j++) if (L[j] ~ /finish-pr\.sh/) { fpr=1; break }
        if (!fpr) continue
        pub=0; br=0
        for (j=i+1;j<=i+12 && j<=NR;j++) {
          if (L[j] ~ /publish_sandbox/) pub=1
          # seed_branch OR a hand-rolled branch: one case creates an EMPTY branch off the
          # trunk on purpose, which the helper cannot express. The step is "the branch
          # exists", not "the helper was called".
          if (L[j] ~ /seed_branch |git -C "\$SB_WORK" branch /) br=1
        }
        miss=""
        if (!pub) miss=miss " publish_sandbox"
        if (!br)  miss=miss " a branch"
        if (miss != "") print i "|" miss
        seen++
      }
      print "COUNT|" seen+0
    }
  ' "$probe" | _harness_where)"
  n="$(printf '%s\n' "$rows" | sed -n 's/^COUNT|//p')"

  # ── INSTRUMENT CHECK: the derivation must still find prologues. A pattern that stopped
  #    matching reports "none incomplete" forever.
  [ "${n:-0}" -ge 8 ] \
    || _fixture_die "case_landing_prologue_is_complete: the derivation found only ${n:-0} landing prologue(s) — the shape changed, and 'none incomplete' would then be true of nothing."

  local row
  while IFS= read -r row; do
    case "$row" in COUNT\|*|'') continue ;; esac
    cf "the landing prologue at ${row%%|*} is missing:${row#*|} — a card seeded dev_complete that is never published, or has no branch, is a fixture finish-pr.sh cannot act on, and the case above it would pass for the wrong reason"
  done <<EOF
$rows
EOF

  finish "all $n landing prologues in this harness are the complete four-step (make_sandbox, seed_issue dev_complete, seed_branch, publish_sandbox) — the copies were kept on purpose, because most carry a card-slug/branch-slug divergence a collapse would erase, so this is what makes an incomplete copy visible"
  teardown
}

# =============================================================================
# CASE — EVERY ANCHORED FIXTURE APPEND HAS A DECLARED AUTHOR.
#
# Two anchor families live in this file: the array fence `NAME=(` and the function-body
# fence `name() {`. Each is a four-step idiom — assert the anchor, plant, assert it
# landed, and for a sourced library `bash -n` — and the four steps are exactly what a
# copier drops. Measured when this was written: four call sites had re-typed the plant
# with no anchor assertion at all, and one of the two library plants omitted the parse
# check, which is the step that tells "the plant changed the behaviour" apart from "the
# library no longer loads".
#
# THE CENSUS IS THE CONTROL. Consolidating the four helpers did not stop the fifth copy
# from being typed; this case does. A helper nobody is required to call is a convention,
# and this file's own history is that conventions here get re-typed.
#
# THIS CASE SCANS THE FILE IT LIVES IN, so it is inside its own operand set. The two
# match strings are held in separate variables on separate lines and comment lines are
# skipped — otherwise the derivation reddens on its own source and on the comment above.
# =============================================================================
case_fixture_append_has_one_authoring_site() {
  cf_reset
  make_sandbox
  local m1='perl -i -pe'
  local m2='$_ .='
  local probe="$SB_TMP/appendprobe.sh"
  _harness_probe_copy "$probe" \
    || _fixture_die "case_fixture_append_has_one_authoring_site: could not copy the harness's own source to census."
  _harness_population_is_whole "$probe"

  # THE DECLARED AUTHORS. Anything else that plants is a bypass.
  local allowed=" _declare_gate _guard_declare _plant_in_function rel_insert "

  _append_census() {  # <file> — "line|enclosing-function" for every anchored append
    awk -v a="$m1" -v b="$m2" '
      # NOT anchored at the closing brace: several definitions here carry a trailing
      # `# <args>` comment, and an anchored tracker attributes their body to whatever
      # function was defined above them — which is a WRONG author, not a missing one.
      /^[a-z_]+\(\) \{/ { fn=$0; sub(/\(\).*$/,"",fn); next }
      /^[[:space:]]*#/   { next }
      index($0,a) && index($0,b) { print NR "|" (fn == "" ? "(top level)" : fn) }
    ' "$1"
  }

  local rows n
  rows="$(_append_census "$probe" | _harness_where)"
  n="$(printf '%s\n' "$rows" | grep -c '|' || true)"

  # ── INSTRUMENT CHECK, and it is mandatory here: arm 1 is a NEGATIVE census, so an
  #    expression that stopped matching satisfies "no bypasses" forever. Assert the
  #    derivation still finds the authors themselves.
  [ "$n" -ge 4 ] \
    || _fixture_die "case_fixture_append_has_one_authoring_site: the census found only $n anchored append(s) in the whole file — the expression stopped matching, and 'zero bypasses' would then be true of nothing."

  # ARM 1 — every append sits inside a declared author.
  local row ln fn
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    ln="${row%%|*}"; fn="${row#*|}"
    case "$allowed" in
      *" $fn "*) ;;
      *) cf "$ln plants through an anchored perl append inside '$fn', which is not one of the declared authors ($allowed) — a fifth copy of the four-step idiom, and the steps it drops are the ones that make a failed plant visible" ;;
    esac
  done <<EOF
$rows
EOF

  # ARM 2 — THE EFFECT, and arm 1 cannot see it: a spine that swallowed the per-caller
  # message would pass the census and still cost the reader the subject of the failure.
  local v="$SB_WORK/scripts/verify.sh" out rc
  # Positive leg first: on an INTACT anchor the helper succeeds. Without this, "it
  # aborts" is satisfied by a helper that aborts unconditionally.
  ( _declare_gate 'census-probe|select|/bin/echo ok' ) >/dev/null 2>&1 \
    || cf "(arm 2) _declare_gate failed on an INTACT anchor — the abort below would prove nothing"
  # Now break the anchor and require the abort to name the caller's own record.
  perl -i -pe 's/^GATES=\($/GATEZ=(/' "$v"
  rc=0; out="$( _declare_gate 'wanted-gate|select|/bin/echo x' 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] \
    || cf "(arm 2) _declare_gate returned 0 with its anchor destroyed — the plant silently did nothing and the case downstream would run against an empty gate table"
  printf '%s' "$out" | grep -F 'wanted-gate' >/dev/null \
    || cf "(arm 2) the abort does not name the record it failed to declare: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"

  finish "every anchored fixture append in this harness ($n of them) sits inside one of four declared authors — no fifth copy of the four-step plant idiom — and a plant whose anchor has moved aborts naming the record it failed to declare rather than returning 0 on a file it did not change"
  teardown
}

# =============================================================================
# CASE — SHIP STATE. The control the neutralizer costs us.
#
# Why this case has to exist. Before _kit_neutral_config, every sandbox inherited
# the real scripts/ verbatim, so the whole suite was an incidental — and
# unstated — witness to the SHIPPED defaults: if this repository had ever declared
# a gate or set RELEASE_PUBLISH=true, cases would have started behaving
# differently and someone would eventually have noticed. Neutralizing deliberately
# destroys that coupling, which is the point; it also destroys the witness. After
# it, every green rests on the harness's OWN assignment of the neutral values, and
# a kit that shipped `RELEASE_PUBLISH=true` would sail through a fully green run.
# A SHIPPED DEFAULT IS ITSELF A SHIPPABLE DEFECT, and this is the only case that
# looks at it. Same argument as the belt-tooling rule one level down: a fixture cannot certify the
# thing it overwrites.
#
# It reads the REAL files and mutates nothing.
#
# WHY IT SKIPS RATHER THAN FAILS ON A CONFIGURED TREE. "The frame ships empty" is
# a claim about the KIT, not about an adopter — a project that has filled its gate
# table has done exactly what it was told to. So the case states its subject and
# steps aside when the tree is not the shipped frame, naming the signal that told
# it so. A SKIP here is a statement about the environment, never a hidden failure.
# =============================================================================
case_ship_state() {
  cf_reset
  local rv="$REAL_SCRIPTS/verify.sh" rr="$REAL_SCRIPTS/release.sh" rc_cfg="$REAL_SCRIPTS/config.sh"
  local why=""

  # Is this tree the shipped frame, or an adopted project? Two signals, either sufficient, and
  # the one that fired is reported. DERIVED BY _tree_has_lived, not here: a second case
  # (case_scaffolding_fixture_matches_the_tree arm (e)) needs the same judgement about the same
  # tree, and two copies of a two-signal test are two things that can come to disagree about
  # whether one tree has been adopted — which would surface as one case measuring a document the
  # other calls adopter-owned, with nothing to say which was right.
  why="$(_tree_has_lived)"
  if [ -n "$why" ]; then
    # THE FIRST skp_lived. This case asserts the SHIPPED shape of scripts/verify.sh,
    # scripts/release.sh and scripts/config.sh; on an adopted tree those shapes are gone
    # BECAUSE THE ADOPTER DID WHAT THEY WERE TOLD, so the case has no subject rather than
    # a reason to be lenient. `$why` already names the file that carries the signal.
    skp_lived "ship state: the kit's own config blocks still ship neutral" "$why"
    return
  fi

  # An array that is GONE reads as an array with zero records, so the fence is
  # asserted before the count. Presence first, then the property — otherwise a
  # renamed array is indistinguishable from a clean one.
  _ship_array_empty() {  # <file> <ARRAY>
    local f="$1" a="$2" n
    grep -qE "^${a}=\($" "$f" || { cf "${f##*/}: no '${a}=(' declaration — it was renamed or removed, so 'empty' here would mean nothing"; return; }
    n="$(_neu_array_records "$f" "$a")"
    [ "$n" -eq 0 ] || cf "${f##*/}: ${a} ships with ${n} declared record(s) — the frame must ship empty"
  }
  _ship_line() {  # <file> <exact line>
    grep -qxF "$2" "$1" || cf "${1##*/}: does not ship the line '$2'"
  }

  if [ -f "$rv" ]; then
    _ship_array_empty "$rv" GATES
    _ship_array_empty "$rv" GUARD_SET
    # _ship_array_empty CANNOT SEE A SCALAR, so the guard-floor enumerator needs the
    # line form. Without it the kit could ship a populated GUARD_ENUM — one project's
    # command, in every adopter's tree — and no case would look.
    _ship_line "$rv" 'GUARD_ENUM=""'
  else
    cf "scripts/verify.sh is absent — the gate frame is part of the kit"
  fi

  if [ -f "$rr" ]; then
    _ship_array_empty "$rr" VERSION_FILES
    _ship_array_empty "$rr" PREFLIGHT_GATES
    _ship_array_empty "$rr" RELEASE_DOCS
    _ship_array_empty "$rr" DIST_DOCS
    # Publishing OFF by default is the one that can do outward-facing damage if it
    # ships wrong, so it is asserted by value and not merely by presence.
    _ship_line "$rr" 'RELEASE_PUBLISH=false'
    _ship_line "$rr" 'VERSION_IN_TAG_ONLY=false'
    _ship_line "$rr" 'DIST_ARTIFACT_GLOB=""'
    _ship_line "$rr" 'SHIP_MANIFEST=""'
  fi

  local SB_REAL_KWT="$REAL_SCRIPTS/lib/kanban-worktree.sh"

  # The three seam values, in the exact shape kit-init.sh's anchored seds parse.
  # These are also the neutralizer's targets, so this is where the harness's own
  # KIT_NEUTRAL_* constants are held against the tree instead of assumed.
  if [ -f "$rc_cfg" ]; then
    _ship_line "$rc_cfg" "ISSUE_PREFIX=\"\${ISSUE_PREFIX:-${KIT_NEUTRAL_PREFIX}}\""
    _ship_line "$rc_cfg" "PRD_PREFIX=\"\${PRD_PREFIX:-${KIT_NEUTRAL_PRD_PREFIX}}\""
    _ship_line "$rc_cfg" "PROJECT_NAME=\"\${PROJECT_NAME:-${KIT_NEUTRAL_PROJECT_NAME}}\""
  else
    cf "scripts/config.sh is absent — it is the configuration seam itself"
  fi

  # THE FOURTH DECLARATION, and it does NOT live in the seam file. Four consumers parse
  # KWT_TRUNK_LAST_RESORT out of the lib with the same anchored sed they use on config.sh,
  # so it is bound by the same shape rule (config-seam.md § 2) and belongs in the same
  # block. Its absence here is why the shape had three assertions and four authors.
  if [ -f "$SB_REAL_KWT" ]; then
    _ship_line "$SB_REAL_KWT" 'KWT_TRUNK_LAST_RESORT="${KWT_TRUNK_LAST_RESORT:-main}"'
  else
    cf "scripts/lib/kanban-worktree.sh is absent — it declares the trunk last resort"
  fi

  # THE ROLE SET, and it is the newest member of the KIT_NEUTRAL_* block above, so this
  # block's own rule reaches it: neutralizing a seam costs the suite its only incidental
  # witness to the shipped value, and this case is where that debt is paid. It is owed
  # here MORE than the others, not less — the other neutral constants have an unstamped
  # source in kit-init.sh to be checked against, and this one has none, because
  # `kit-init --roles` rewrites every occurrence in every seam that carries it. A drifted
  # literal here would silently neutralize sandboxes to a role set the kit no longer ships.
  local rh="$REAL_SCRIPTS/githooks/commit-msg"
  if [ -f "$rh" ]; then
    _ship_line "$rh" "ROLE_PREFIXES='${KIT_NEUTRAL_ROLE_PREFIXES}'"
  else
    cf "scripts/githooks/commit-msg is absent — it is the role set's authoring site"
  fi

  # The FOURTH seam _kit_neutral_claude now resets, and therefore the fourth the
  # suite stopped being an incidental witness to: the shipped templates carry the
  # prefix as a PLACEHOLDER, not as a token. A kit that shipped a real prefix here
  # would sail through a green run — the sandbox would restore nothing, kit-init
  # would substitute nothing, and the case that checks the stamped id would still
  # pass because the neutralizer had handed it what it expected.
  #
  # Guarded on presence rather than asserted, and the reason is this repository's
  # own storage: the kit is kept DISARMED here (kit/_claude/, not kit/.claude/), so
  # a run in place finds no .claude/templates at all. The kit-init cases skip
  # loudly for exactly that reason; a `cf` here would turn the same environment
  # fact into a FALSE RED, which is the defect measured against this file on
  # 2026-08-26 and worth not re-creating.
  local rt="$REAL_REPO_ROOT/.claude/templates/ISSUE.template.md"
  if [ -f "$rt" ]; then
    grep -qF "$KIT_PREFIX_PLACEHOLDER" "$rt" \
      || cf ".claude/templates/ISSUE.template.md does not ship the prefix placeholder '$KIT_PREFIX_PLACEHOLDER' — the templates ship a stamped token, and every sandbox would then inherit it"
  fi

  finish "ship state: the kit ships an empty gate table and guard floor, empty release seams, RELEASE_PUBLISH=false, the neutral config.sh seam values the neutralizer resets to, the prefix PLACEHOLDER in the shipped ISSUE template, and the shipped ROLE_PREFIXES the neutralizer declares"
}

# =============================================================================
# CASE — isolation self-check: the real repo is untouched by a run.
# (Belt-and-suspenders: every case above deliberately mutates its sandbox; we
#  then assert the real repo's HEAD + board surfaces are unchanged.)
# =============================================================================
REAL_HEAD_BEFORE=""; REAL_STATUS_BEFORE=""
# THE SPAN IS THE WHOLE TREE, minus the harness's own directory.
#
# It used to be three paths — `scripts progress ARCHIVE.md` — and that was narrower than what this
# harness READS by a wide margin: it reads PROJECT.md, CLAUDE.md, .claude/{templates,roles,workflows,
# agents}, _claude/skills, process/, consumers/, dev/ and setup.sh out of the real tree as well. So
# the case certified "the real repo unchanged" while three of the surfaces it could have written to
# were outside the question, and cases HAD written to the real CLAUDE.md and PROJECT.md without this
# noticing. An isolation check whose span is narrower than its subject's reach is a check that
# reports the absence of the findings it cannot have.
#
# `scripts/test/` stays excluded, and for a stated reason rather than by habit: it is the harness's
# own home, legitimately edited by whoever is developing the harness while it runs.
#
# WIDENING IS SAFE HERE BECAUSE THE COMPARISON IS A DELTA. A pre-existing dirty tree — an editor's
# scratch, a peer's uncommitted work — appears in both snapshots and is not a finding. Only a change
# DURING the run is.
_board_status() {
  git -C "$REAL_REPO_ROOT" status --porcelain 2>/dev/null \
    | grep -v ' scripts/test/' || true
}
isolation_snapshot() {
  REAL_HEAD_BEFORE="$(git -C "$REAL_REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "(no HEAD yet)")"
  REAL_STATUS_BEFORE="$(_board_status)"
}
# THIS CASE REPORTS WHAT IT MEASURED, NOT WHO DID IT — and the difference cost a
# diagnostic detour the day it was found. It compares two snapshots of a tree it does
# NOT own exclusively, so a difference means "this changed between t0 and t1" and
# nothing more. It said "the harness added a mutation", and the harness had not: a
# concurrent session was mid-edit in a board script while the run was in flight. The
# tree was clean at t0, so the detection was exactly right; only the attribution was
# invented. The reader was sent to debug the harness's isolation — the one thing the
# evidence did not implicate — and the first reading was that a landing had broken
# the witness, which is materially more alarming than "another window is editing a
# file".
#
# THE AMBIGUITY IS IRREDUCIBLE FROM IN HERE, so the output names it rather than
# resolving it. Recording the tree state at run start does not help and is already
# done — REAL_STATUS_BEFORE is that snapshot, and the comparison below is already a
# delta, so "appeared during the run" is already distinguished from "was already
# dirty". What no snapshot of a tree can distinguish is WHO WROTE: "the harness wrote
# it" and "a peer wrote it" are both just "the path differs between t0 and t1".
# Separating them needs an observation of authorship this process has no way to make.
# So per instruments.md § A.4 the case names its own blind spot in its own output.
case_isolation() {
  cf_reset
  local after status_after
  after="$(git -C "$REAL_REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "(no HEAD yet)")"
  [ "$after" = "$REAL_HEAD_BEFORE" ] \
    || cf "the real repo's HEAD MOVED during the run ($REAL_HEAD_BEFORE → $after). This harness never commits, so the likely cause is a concurrent session landing work in this checkout; a harness that somehow committed is the other, far less likely, candidate"
  # Compare the DELTA, not absolute cleanliness: a pre-existing dirty tree (e.g.
  # uncommitted board-script edits under active development) is fine — a board
  # surface must simply not CHANGE during a run.
  status_after="$(_board_status)"
  if [ "$status_after" != "$REAL_STATUS_BEFORE" ]; then
    cf "a board surface CHANGED during the run — two candidates, and this case cannot tell them apart: (1) the harness broke its own isolation and wrote outside its sandbox, or (2) something else wrote to this checkout while the run was in flight (a concurrent session, an editor, a watcher). Before/after status follows. If a peer holds this checkout, (2) is the likely one and the run's SKIP profile is also unreliable — re-measure on a quiet tree or a built kit. BEFORE: [${REAL_STATUS_BEFORE:-clean}] AFTER: [${status_after:-clean}]"
  fi
  finish "isolation: the real repo's HEAD and its WHOLE WORKING TREE — every path git reports, not a named subset — are unchanged across the run, with scripts/test/ excluded as the harness's own home. The span is the whole tree because this harness READS far more of it than any list of surfaces named in advance; a narrower span reports the absence of findings it could not have made. Attribution is out of scope: a path that differs between t0 and t1 does not say who wrote it (see the case's note)"
}
