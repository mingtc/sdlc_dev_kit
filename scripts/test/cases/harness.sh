# KIT-CLASS: MIXED — self-test harness, cases about the harness itself. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/harness.sh — sourced by scripts/test/run.sh, never run on its own.
# The cases whose subject is this harness: the self-reading censuses, then ship state and
# the isolation check, which CASES runs last.
# =============================================================================

# _role_literals_used <file> — every role NAME this harness writes, extracted BY
# POSITION: a --role argument, or a [Role] tag opening a commit subject or an Activity
# line. Position excludes the same tokens in diagnostic prose ABOUT roles, with no
# exemption list to maintain.
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
# case_ship_state holds the shipped commit-msg to the declared set; this is the other
# direction: every role the CASES type is a member of it. A case typing an undeclared role
# fails with "--role must be …" or a rejected commit — a fixture red that reads as a tool
# defect. Membership, not abstinence: the hand-off cases need two distinct roles.
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

  # ── THE REDDENING CONTROL, on a COPY — never the harness itself (instruments.md § A.2).
  local probe="$SB_TMP/roleprobe.sh"
  cp "$self" "$probe" 2>/dev/null || true
  if [ ! -f "$probe" ]; then
    _control_did_not_run "copy this harness to plant into"
  else
    # THE OUTSIDER'S NAME IS BUILT, NEVER WRITTEN: this case scans its own source, so a
    # literal outsider role written here would redden it. `%s` carries it into the probe.
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
# A case that mints a card without calling has_issue_template FAILS on a tree without
# .claude/templates/ISSUE.template.md, reporting a missing capability as a defect in the
# subject. The population is derived from the harness text — the cases that invoke a
# creation script or kit_init_sandbox — so a new minting case cannot arrive unguarded.
# =============================================================================
case_minting_cases_probe_for_the_template() {
  cf_reset
  make_sandbox
  local self="$SB_TMP/mintpop.sh" probe="$SB_TMP/mintprobe.sh"
  _harness_probe_copy "$self" \
    || _fixture_die "case_minting_cases_probe_for_the_template: could not copy the harness's own source to census."
  _harness_population_is_whole "$self"

  # Excise this case's own body: its derivation names the creation scripts it looks for.
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
    # WIDE ON PURPOSE: a creator reached through a glob or a basename counts, and so does
    # kit_init_sandbox, which copies the template and refuses without it. The signal is a
    # CALL, so comment lines are skipped.
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

  # ── INSTRUMENT CHECK: a negative census whose derivation finds nothing is green forever.
  [ "$n" -ge 5 ] \
    || _fixture_die "case_minting_cases_probe_for_the_template: the derivation found only $n card-minting case(s) — the creator names or the case-function shape changed, and 'all of them probe' would then be true of almost nothing."

  finish "all $n cases that invoke a creation script probe for the issue template first, so a tree without it SKIPS rather than reporting a missing capability as a defect — and the population is derived from the harness's text, so the next minting case cannot arrive unguarded"
  teardown
}

# =============================================================================
# CASE — VICTIM SELECTION SURVIVES PIPEFAIL.
#
# `find … | head -1` is the shape run.sh's PIPEFAIL RULE forbids: the value is right and the
# STATUS is the producer's SIGPIPE. probe_pick replaces it. This case proves the hazard exists
# here, asserts probe_pick's status and value, and censuses the harness and the shipped
# scripts for the piped readers the rule forbids.
# =============================================================================
case_probe_victim_selection_survives_pipefail() {
  cf_reset
  make_sandbox
  local big="$SB_TMP/pipebig" i v rc hit=0

  # ── INSTRUMENT CHECK: BUILD the hazard before asserting anything about it. If this
  #    environment cannot produce the SIGPIPE, every assertion below is vacuous, so SKIP.
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

  # THE EFFECT — the STATUS and the value. The raw pipeline gets the value right and the
  # status wrong, so asserting the value alone could not go red.
  rc=0; v="$(probe_pick "$big" -type f)" || rc=$?
  [ "$rc" -eq 0 ] \
    || cf "probe_pick exited $rc on a corpus where the raw pipeline SIGPIPEs — the status is still the producer's death, not the answer"
  [ -n "$v" ] && [ -f "$v" ] \
    || cf "probe_pick returned '$v', which is not an existing file — the replacement gets the status right and the answer wrong, which is worse than what it replaced"

  # …and it still returns NOTHING, nonzero, when there is genuinely nothing to find.
  rc=0; v="$(probe_pick "$SB_TMP/pipebig" -name 'nothing-matches-this' -type f)" || rc=$?
  [ -z "$v" ] \
    || cf "probe_pick invented a victim for a pattern that matches nothing: '$v'"

  # THE CENSUS: a new `find … | head -1` anywhere in the harness puts the hazard back.
  local self="$SB_TMP/pipepop.sh" probe="$SB_TMP/pipeprobe.sh" m1='find ' m2='| head -1'
  _harness_probe_copy "$self" \
    || _fixture_die "case_probe_victim_selection_survives_pipefail: could not copy the harness's own source to census."
  _harness_population_is_whole "$self"
  # EXCISE THIS CASE'S OWN BODY: its instrument check builds the forbidden pipeline on purpose.
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

  # ── THE SAME HAZARD, THE OTHER READER: `… | grep -q` behind a pipe. Assert the construct's
  #    ABSENCE, not its symptom: the false red appears only above the 64KB buffer, so a case
  #    waiting for it on a realistic payload stays green forever. A bare `grep -q FILE` is fine.
  local qrows
  qrows="$(awk '
    /^[[:space:]]*#/ { next }
    /\|[[:space:]]*grep -q/ { print NR ": " $0 }
  ' "$probe" | _harness_where)"
  [ -z "$qrows" ] \
    || cf "a 'grep -q' behind a pipe is back, and under pipefail it reports the PRODUCER'S death instead of the reader's answer once the producer clears the pipe buffer — drop the -q and redirect (\`| grep -F pat >/dev/null\`), which drains the input and returns the identical status: $(printf '%s' "$qrows" | tr '\n' ' ' | cut -c1-200)"

  # ── THE SHIPPED POPULATION, where the producer grows with the adopter's project. Narrower
  #    than the harness rule: a pipe validating one flag value is allowed, a producer that
  #    reads the repository, the board or the network is not. The harness files are excluded
  #    as a population, so each file is judged by exactly one of the two rules.
  local shipped_rows shipped_files
  shipped_files="$(find "$REAL_SCRIPTS" "$REAL_REPO_ROOT/consumers" -type f \
                     \( -name '*.sh' -o -name 'commit-msg' \) 2>/dev/null \
                   | grep -vxF -f <(_harness_sources) || true)"
  [ -n "$shipped_files" ] \
    || _fixture_die "case_probe_victim_selection_survives_pipefail: found no shipped scripts to census — a guard over an empty population passes forever."
  #    THE PRODUCER IS OFTEN ON THE PREVIOUS LINE (`… --porcelain \` then `| grep -qxF …` in
  #    lib/kanban-worktree.sh), so a line continuation is joined before the pattern is tested.
  shipped_rows="$(printf '%s\n' "$shipped_files" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    awk -v fn="$f" '
      /^[[:space:]]*#/ { next }
      {
        # Join ONLY across a real line-continuation: joining unconditionally leaks the
        # previous verb into this line and reddens the permitted flag validators. No
        # quotes in this comment: it lives inside a single-quoted awk program.
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
# The prologues are deliberately not one helper: most use a CARD slug that differs from the
# BRANCH slug, which exercises finish-pr.sh reading the card's `branch:` field. So the copies
# stay, and this case names by line any copy that dropped a step.
# =============================================================================
case_landing_prologue_is_complete() {
  cf_reset
  make_sandbox
  local self="$SB_TMP/prologuepop.sh" probe="$SB_TMP/prologueprobe.sh"
  _harness_probe_copy "$self" \
    || _fixture_die "case_landing_prologue_is_complete: could not copy the harness's own source to census."
  _harness_population_is_whole "$self"

  # EXCISE THIS CASE'S OWN BODY: its derivation names every token it searches for.
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

  # A LANDING PROLOGUE is a dev_complete card seeded right after make_sandbox in a case that
  # then invokes finish-pr.sh. The last clause matters: dev_complete cards also appear as
  # board content in cases that never land.
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
          # trunk on purpose. The step is that the branch exists.
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

  # ── INSTRUMENT CHECK: a pattern that stopped matching reports "none incomplete" forever.
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
# Two anchor families: the array fence `NAME=(` and the function-body fence `name() {`. A
# plant is a four-step idiom — assert the anchor, plant, assert it landed, and for a sourced
# library `bash -n` — and a re-typed copy drops steps, so every anchored perl append must sit
# inside a declared author. This case scans its own file: the two match strings are held in
# separate variables and comment lines are skipped.
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

  # ── INSTRUMENT CHECK: arm 1 is a NEGATIVE census, so assert the derivation still finds
  #    the authors themselves.
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
# Every sandbox is reset to the KIT_NEUTRAL_* values, so no other case sees the shipped
# defaults: a kit that shipped `RELEASE_PUBLISH=true` or a populated gate table would pass a
# green run. This case reads the REAL files and mutates nothing. On an adopted tree it is
# N/A, naming the signal: a filled gate table is what the adopter was told to do.
# =============================================================================
case_ship_state() {
  cf_reset
  local rv="$REAL_SCRIPTS/verify.sh" rr="$REAL_SCRIPTS/release.sh" rc_cfg="$REAL_SCRIPTS/config.sh"
  local why=""

  # Is this tree the shipped frame, or an adopted project? _tree_has_lived decides, for this
  # case and case_scaffolding_fixture_matches_the_tree alike, and returns the signal that fired.
  why="$(_tree_has_lived)"
  if [ -n "$why" ]; then
    # On an adopted tree these shipped shapes are gone because the adopter did what they
    # were told: the case has no subject. `$why` names the file that carries the signal.
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

  # KWT_TRUNK_LAST_RESORT lives in the lib, not the seam file, and is bound by the same shape
  # rule (config-seam.md § 2).
  if [ -f "$SB_REAL_KWT" ]; then
    _ship_line "$SB_REAL_KWT" 'KWT_TRUNK_LAST_RESORT="${KWT_TRUNK_LAST_RESORT:-main}"'
  else
    cf "scripts/lib/kanban-worktree.sh is absent — it declares the trunk last resort"
  fi

  # THE ROLE SET. It has no unstamped source to check against (`kit-init --roles` rewrites
  # every copy), so a drifted KIT_NEUTRAL_ROLE_PREFIXES would silently neutralize sandboxes
  # to a set the kit no longer ships.
  local rh="$REAL_SCRIPTS/githooks/commit-msg"
  if [ -f "$rh" ]; then
    _ship_line "$rh" "ROLE_PREFIXES='${KIT_NEUTRAL_ROLE_PREFIXES}'"
  else
    cf "scripts/githooks/commit-msg is absent — it is the role set's authoring site"
  fi

  # The shipped templates carry the prefix as a PLACEHOLDER. A kit shipping a real prefix
  # there would pass a green run, because the neutralizer hands every case what it expects.
  # Guarded on presence: a tree without .claude/templates has no subject here.
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
# THE SPAN IS THE WHOLE TREE, minus the harness's own directory: the harness reads far more
# of the real tree than scripts/ and progress/, and a narrower span cannot see a write to
# what it reads. scripts/test/ is excluded as the harness's own home. The comparison is a
# DELTA, so a tree already dirty at t0 is not a finding.
_board_status() {
  git -C "$REAL_REPO_ROOT" status --porcelain 2>/dev/null \
    | grep -v ' scripts/test/' || true
}
isolation_snapshot() {
  REAL_HEAD_BEFORE="$(git -C "$REAL_REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "(no HEAD yet)")"
  REAL_STATUS_BEFORE="$(_board_status)"
}
# THIS CASE REPORTS WHAT IT MEASURED, NOT WHO DID IT. A path that differs between t0 and t1
# may have been written by the harness or by a concurrent session in the same checkout, and
# no snapshot can tell them apart, so the output names both (instruments.md § A.4).
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
