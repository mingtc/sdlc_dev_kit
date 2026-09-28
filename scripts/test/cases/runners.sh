# KIT-CLASS: MIXED — self-test harness, workflow-runner cases. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/runners.sh — sourced by scripts/test/run.sh, never run on its own.
# The workflow runners and agent definitions: schemas, verdicts, briefs, leg outcomes,
# model pins, riders, provisioning, and the settings example.
# =============================================================================

# =============================================================================
# A SCHEMA'S `required` MUST NAME PROPERTIES THE SCHEMA DEFINES
# =============================================================================
# A `required` naming an undefined property means the schema cannot validate. `node --check`
# cannot see it (the defect is semantic), and the VERDICTS enum case is a different
# assertion. The extractor keys on `^const <NAME>_SCHEMA`, so every schema is covered. One
# direction only: "a property no consumer reads" would fire on legitimate keys, while an
# undefined `required` name is always a defect.
_schema_extract_awk() {
  cat <<'AWKEOF'
/^const [A-Za-z_]+_SCHEMA[[:space:]]*=/ { s=$2; inprops=0; next }
s == "" { next }
/^[[:space:]]*properties:[[:space:]]*\{/ { inprops=1; next }
inprops && /^[[:space:]]{2}\},?[[:space:]]*$/ { inprops=0; next }
inprops && /^[[:space:]]{4}[A-Za-z_]+:/ {
  k=$1; sub(/:.*/,"",k); gsub(/[[:space:]]/,"",k); print s "|prop|" k; next
}
/^[[:space:]]*required:[[:space:]]*\[/ {
  line=$0; sub(/^[^[]*\[/,"",line); sub(/\].*/,"",line)
  n=split(line, a, ",")
  for (i=1;i<=n;i++) { v=a[i]; gsub(/[[:space:]'\''"]/,"",v); if (v!="") print s "|req|" v }
  next
}
/^\}/ { s="" }
AWKEOF
}

# _schema_audit <file> <label> -> prints findings; echoes "<n_schemas> <n_bad>"
_schema_audit() {
  local f="$1" lab="$2" ex n=0 bad=0 sch r
  ex="$(mktemp)"
  awk -f <(_schema_extract_awk) "$f" > "$ex"
  while IFS= read -r sch; do
    [ -z "$sch" ] && continue
    n=$(( n + 1 ))
    while IFS= read -r r; do
      [ -z "$r" ] && continue
      if ! awk -F'|' -v s="$sch" '$1==s && $2=="prop"{print $3}' "$ex" | grep -xF "$r" >/dev/null; then
        echo "    ✗ ${lab} ${sch}: required names '${r}' which properties does not define"
        bad=$(( bad + 1 ))
      fi
    done < <(awk -F'|' -v s="$sch" '$1==s && $2=="req"{print $3}' "$ex")
  done < <(cut -d'|' -f1 "$ex" | sort -u)
  rm -f "$ex"
  echo "$n $bad"
}

case_runner_schema_required_defines() {
  cf_reset
  make_sandbox   # for SB_TMP + teardown; this case reads the REAL shipped runners

  local total_schemas=0 total_bad=0 f lab res n bad
  # THE ENUMERATION IS _shipped_runners, NOT A SECOND COPY OF ITS GLOB.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    lab="$(basename "$f")"
    res="$(_schema_audit "$f" "$lab" | tail -1)"
    _schema_audit "$f" "$lab" | grep '✗' || true
    n="${res%% *}"; bad="${res##* }"
    total_schemas=$(( total_schemas + n )); total_bad=$(( total_bad + bad ))
  done <<EOF
$(_shipped_runners)
EOF

  # ASSERT THE EXTRACTOR, NOT ONLY THE COMPARISON: zero schemas compares zero against zero
  # and passes. Six is the shipped count (DEV/QA/PARK in each of two runners); fewer means
  # the extractor stopped matching.
  [ "$total_schemas" -ge 6 ] \
    || cf "the extractor found only $total_schemas schema(s) — expected at least 6 (DEV/QA/PARK × 2 runners). A count this low means the extractor stopped matching, NOT that the tree is clean."
  [ "$total_bad" -eq 0 ] \
    || cf "$total_bad schema(s) have a required name their properties do not define (listed above)"

  finish "runner schemas: every 'required' name is defined in 'properties' ($total_schemas schemas checked, $total_bad bad)"
  teardown
}

# EVERY SHIPPED RUNNER, disarmed or armed tree — the ONE authoring site for that enumeration.
# Dual spelling: the maintainer repository stores the kit disarmed (`_claude/`) and a built
# kit ships it armed (`.claude/`), so reading whichever exists finds the real shipped tree.
# It does NOT make an in-place run a witness (run.sh's header). case_shipped_runners_parse
# globs the wider `workflows/*.js` on purpose, since a file that cannot parse matters
# whatever its name: do not collapse it into this helper.
_shipped_runners() {
  local f
  for f in "$REAL_REPO_ROOT"/_claude/workflows/*runner*.js "$REAL_REPO_ROOT"/.claude/workflows/*runner*.js; do
    [ -e "$f" ] && printf '%s\n' "$f"
  done
}

# THE TWO RUNNERS CARRY THEIR SCHEMAS BY HAND (no imports; a shared child workflow was declined).
# This case holds their agreement.
_schema_descriptions() {   # <runner file> -> "SCHEMA.field<TAB>description", sorted
  awk -v q="'" '
    /^const [A-Z_]+_SCHEMA = \{/ { s = $2; next }
    s != "" && /^\}/            { s = ""; next }
    s != "" && match($0, /^[[:space:]]+[A-Za-z_]+:[[:space:]]*\{/) {
      f = $1; sub(/:.*$/, "", f)
      key = "description: " q
      i = index($0, key)
      if (i > 0) {
        d = substr($0, i + length(key))
        j = index(d, q)
        if (j > 0) d = substr(d, 1, j - 1)
        print s "." f "\t" d
      } else {
        print s "." f "\t<no description>"
      }
    }
  ' "$1" | sort
}

case_runner_schemas_agree() {
  cf_reset
  make_sandbox   # for SB_TMP + teardown; this case reads the REAL shipped runners

  local a b f found=0 n=0
  a="$SB_TMP/schema-a.txt"; b="$SB_TMP/schema-b.txt"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    found=$(( found + 1 ))
    case "$found" in
      1) _schema_descriptions "$f" > "$a" ;;
      2) _schema_descriptions "$f" > "$b" ;;
    esac
  done <<EOF
$(_shipped_runners)
EOF

  # ASSERT THE EXTRACTOR TWICE. Either failure makes the diff below compare nothing and pass.
  [ "$found" -eq 2 ] \
    || cf "expected exactly 2 shipped runners, found $found -- a comparison needs two operands, and with fewer this case asserts nothing"
  [ -f "$a" ] && n="$(wc -l < "$a" | tr -d ' ')"
  [ "$n" -ge 10 ] \
    || cf "the extractor found only $n schema field(s) -- expected at least 10. A low count means the extractor stopped matching, NOT that the schemas agree"

  if [ "$found" -eq 2 ] && ! diff -q "$a" "$b" >/dev/null 2>&1; then
    cf "the shipped runners schemas have DIVERGED -- they are hand-maintained copies and nothing else holds them together. Reconcile them, or if a field genuinely belongs to one runner only, say so in that runner's meta.description (which promises the same fields) and widen this case. Diff: $(diff "$a" "$b" | head -6 | tr '\n' ' ')"
  fi

  finish "the two shipped runners' schemas agree field-for-field ($n field(s) compared, descriptions included)"
  teardown
}

# THE RUN-OUTCOME VOCABULARY IS HAND-COPIED INTO BOTH RUNNERS (no imports). This case holds
# both directions: the copies agree with each other, and they project the ratified table in
# process/MANUAL.md, because a pair that drifts together passes an agreement-only check. It
# also asserts that every declared token is returned somewhere in its runner.
_outcome_tokens() {   # <runner file> -> one token per line, sorted
  awk '
    /^const OUTCOME = Object\.freeze\(\{/ { inb=1; next }
    inb && /^\}\)/                         { inb=0; next }
    inb && match($0, /^[[:space:]]+[A-Z_]+:/) { t=$1; sub(/:$/, "", t); print t }
  ' "$1" | sort
}

case_runner_outcome_vocabulary_agrees() {
  cf_reset
  make_sandbox   # for SB_TMP + teardown; this case reads the REAL shipped runners

  local a b f found=0 n=0 t unused=0
  a="$SB_TMP/outcome-a.txt"; b="$SB_TMP/outcome-b.txt"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    found=$(( found + 1 ))
    case "$found" in
      1) _outcome_tokens "$f" > "$a" ;;
      2) _outcome_tokens "$f" > "$b" ;;
    esac
    # EVERY DECLARED TOKEN IS RETURNED SOMEWHERE IN ITS OWN RUNNER.
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      grep -qF "OUTCOME.$t" "$f" || { unused=$(( unused + 1 )); cf "$(basename "$f"): declares OUTCOME.$t and never returns it -- a vocabulary member the runner cannot produce is documentation, and it still compares equal to its twin"; }
      # ...and spells it one way: a log line reading LAND-READY is a token nobody can grep for.
      case "$t" in *_*) ! grep -qF -- "${t//_/-}" "$f" || cf "$(basename "$f"): spells $t as ${t//_/-}" ;; esac
    done < <(_outcome_tokens "$f")
  done <<EOF
$(_shipped_runners)
EOF

  # ASSERT THE EXTRACTOR TWICE: either failure makes the diff below compare nothing and pass.
  [ "$found" -eq 2 ] \
    || cf "expected exactly 2 shipped runners, found $found -- a comparison needs two operands"
  [ -f "$a" ] && n="$(wc -l < "$a" | tr -d ' ')"
  [ "$n" -ge 6 ] \
    || cf "the extractor found only $n outcome token(s) -- expected at least 6. A low count means the extractor stopped matching, NOT that the vocabularies agree"

  if [ "$found" -eq 2 ] && ! diff -q "$a" "$b" >/dev/null 2>&1; then
    cf "the runners' run-outcome vocabularies have DIVERGED: $(diff "$a" "$b" | tr '\n' ' ')"
  fi

  # ── THE AUTHORITY ARM. Agreement alone cannot see a pair that drifted TOGETHER.
  #    process/MANUAL.md ratifies the vocabulary; each runner PROJECTS it.
  local auth="$SB_TMP/outcome-auth.txt" man="$REAL_REPO_ROOT/process/MANUAL.md" na=0
  if [ -f "$man" ]; then
    awk '
      /^### The RUN-OUTCOME vocabulary/ { inb=1; next }
      inb && /^### /                    { inb=0 }
      inb && match($0, /^\| `[A-Z_]+`/) { t=$0; sub(/^\| `/, "", t); sub(/`.*$/, "", t); print t }
    ' "$man" | sort > "$auth"
    na="$(wc -l < "$auth" | tr -d ' ')"
    # The extractor is asserted before the comparison: an extractor that matched nothing
    # makes "the runner projects the table" true of an empty table, forever.
    [ "$na" -ge 6 ] \
      || cf "the MANUAL.md run-outcome table yielded only $na token(s) — the extractor stopped matching, so pinning the runners to it would compare against almost nothing"
    if [ "$na" -ge 6 ] && [ "$found" -eq 2 ] && ! diff -q "$a" "$auth" >/dev/null 2>&1; then
      cf "the runners' vocabulary does not PROJECT the ratified table in process/MANUAL.md — the two copies may agree with each other and with nothing else: $(diff "$a" "$auth" | tr '\n' ' ')"
    fi
  else
    cf "process/MANUAL.md is absent — the ratified table is the authority this case pins to"
  fi

  finish "the two shipped runners' run-outcome vocabularies agree with EACH OTHER and PROJECT the ratified table in process/MANUAL.md ($n token(s) per runner, $na ratified, $unused unused), and no runner spells a token with a hyphen — both arms, because an authority does not make two hand-copies agree and two hand-copies agreeing does not make either right"
  teardown
}

# =============================================================================
# THE RUNNERS' TWIN CODE IS HELD IDENTICAL
# =============================================================================
# A shared module could carry data only (a child workflow returns no functions, and nesting is
# one level), so the runners copy what they share, and this case holds the copies together:
#   • each block below, anchor line through end line, identical once whole-line comments and
#     blank lines are dropped (maintainer notes may differ; code may not);
#   • COMMON line for line, except the lines each runner declares its own in the
#     `// Own COMMON lines` comment above it. A declaration must name exactly one line its
#     twin lacks, so a stale or over-broad one reds instead of exempting a shared line;
#   • every CFG key both runners define, default for default. A key one runner alone defines is
#     one only that runner reads (the wave's worktree bootstrap).
# The guarded parse is not held: its message names the runner and its args shape by design.
_TWIN_BLOCKS='provision()|^const DEFAULT_MODEL =|^}
parkWalk()|^function parkWalk[(]|^}
leg() and the leg-notes trail|^const LEG_THREW =|^const legNotes =
DEV_SCHEMA|^const DEV_SCHEMA =|^}
the verdict and outcome vocabulary through devAnswered|^const VERDICTS =|^const devAnswered =
QA_SCHEMA|^const QA_SCHEMA =|^}
PARK_SCHEMA|^const PARK_SCHEMA =|^}
gatesOf()|^function gatesOf[(]|^}'

# <file> <start ERE> <end ERE>: the start line through the first LATER line matching end.
# Exits 3 when either anchor is missing, so a lost anchor is never an empty match.
_twin_block() {
  awk -v s="$2" -v e="$3" '
    !on && $0 ~ s        { on = 1; first = NR }
    !on                  { next }
    !/^[[:space:]]*(\/\/.*)?$/ { print }
    NR > first && $0 ~ e { closed = 1; exit }
    END                  { if (!closed) exit 3 }
  ' "$1"
}
_common_lines() { awk '/^const COMMON = `$/ { on = 1; next } on && /^`$/ { exit } on' "$1"; }
_own_common()   { sed -n 's#^// Own COMMON lines[^:]*: ##p' "$1" | grep -oE "'[^']+'" | sed "s/^'//; s/'\$//"; }
_cfg_defaults() {   # key: default, comments and alignment dropped
  awk '/^const CFG = \{/ { on = 1; next } on && /^\}/ { exit } on' "$1" \
    | grep -v '^[[:space:]]*//' | sed 's#[[:space:]]*//.*$##; s/[[:space:]][[:space:]]*/ /g; s/^ //'
}

case_runner_twin_code_is_identical() {
  cf_reset
  local f w="" t="" found=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    found=$(( found + 1 ))
    case "$(basename "$f")" in wave-runner.js) w="$f" ;; tranche-runner.js) t="$f" ;; esac
  done <<EOF
$(_shipped_runners)
EOF
  if [ "$found" -ne 2 ] || [ -z "$w" ] || [ -z "$t" ]; then
    cf "expected wave-runner.js and tranche-runner.js, found $found runner(s) -- parity needs both operands"
    finish "the runners' twin code is identical"
    return
  fi

  # ── THE BLOCKS ─────────────────────────────────────────────────────────────
  local name s e a b nb=0 nl=0
  while IFS='|' read -r name s e; do
    a="$(_twin_block "$w" "$s" "$e")" || { cf "wave-runner.js: $name's anchors ($s … $e) no longer match -- re-anchor this case"; continue; }
    b="$(_twin_block "$t" "$s" "$e")" || { cf "tranche-runner.js: $name's anchors ($s … $e) no longer match -- re-anchor this case"; continue; }
    nb=$(( nb + 1 )); nl=$(( nl + $(printf '%s\n' "$a" | wc -l) ))
    [ "$a" = "$b" ] \
      || cf "$name differs between the runners (< wave, > tranche): $(diff <(printf '%s\n' "$a") <(printf '%s\n' "$b") | grep '^[<>]' | sed -n '1,4p' | cut -c1-140 | tr '\n' ' ')"
  done <<EOF
$_TWIN_BLOCKS
EOF
  # CONTROL: one character changed in a copy's gatesOf must change the extraction.
  [ "$(_twin_block <(sed 's/the suite alone is the bar/the suite alone is the baR/' "$t") '^function gatesOf[(]' '^}')" \
    != "$(_twin_block "$t" '^function gatesOf[(]' '^}')" ] \
    || cf "(control) a one-character edit to gatesOf did not change the extracted block -- the block comparison cannot bite"

  # ── COMMON ─────────────────────────────────────────────────────────────────
  local cw ct side own twin lab tlab p line n rest rest_w="" rest_t=""
  cw="$(_common_lines "$w")"; ct="$(_common_lines "$t")"
  for side in wave tranche; do
    if [ "$side" = wave ]; then f="$w"; own="$cw"; twin="$ct"; lab=wave-runner.js; tlab=tranche-runner.js
    else f="$t"; own="$ct"; twin="$cw"; lab=tranche-runner.js; tlab=wave-runner.js; fi
    rest="$own"
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      line="$(printf '%s\n' "$own" | P="$p" awk 'index($0, ENVIRON["P"]) == 1')"
      n="$(printf '%s' "$line" | grep -c '^' || true)"
      if [ "$n" -eq 0 ]; then
        cf "$lab declares '$p' an own COMMON line and its COMMON has no such line -- drop the stale declaration"
      elif [ "$n" -gt 1 ]; then
        cf "$lab's own-line declaration '$p' matches $n COMMON lines -- a declaration names one line"
      elif printf '%s\n' "$twin" | grep -xF -- "$line" >/dev/null; then
        cf "$lab declares '$p' its own, and $tlab's COMMON has that line too -- it is shared, so drop the declaration"
      fi
      rest="$(printf '%s\n' "$rest" | P="$p" awk 'index($0, ENVIRON["P"]) != 1')"
    done < <(_own_common "$f")
    if [ "$side" = wave ]; then rest_w="$rest"; else rest_t="$rest"; fi
  done
  local ns; ns="$(printf '%s\n' "$rest_w" | grep -c . || true)"
  [ "$ns" -ge 8 ] \
    || cf "only $ns shared COMMON line(s) extracted -- the extractor stopped matching, or the declarations swallowed the block"
  [ "$rest_w" = "$rest_t" ] \
    || cf "COMMON differs in a line neither runner declares its own (< wave, > tranche) -- make them match, or declare it in the '// Own COMMON lines' comment: $(diff <(printf '%s\n' "$rest_w") <(printf '%s\n' "$rest_t") | grep '^[<>]' | sed -n '1,4p' | cut -c1-140 | tr '\n' ' ')"

  # ── CFG DEFAULTS ───────────────────────────────────────────────────────────
  local dw dt k ks=0 solo=""
  dw="$(_cfg_defaults "$w")"; dt="$(_cfg_defaults "$t")"
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    if printf '%s\n' "$dt" | grep "^$k:" >/dev/null; then
      ks=$(( ks + 1 ))
      [ "$(printf '%s\n' "$dw" | grep "^$k:")" = "$(printf '%s\n' "$dt" | grep "^$k:")" ] \
        || cf "CFG.$k's default differs: wave '$(printf '%s\n' "$dw" | grep "^$k:")' vs tranche '$(printf '%s\n' "$dt" | grep "^$k:")'"
    else solo="$solo wave:$k"; fi
  done < <(printf '%s\n' "$dw" | sed -n 's/^\([A-Za-z_]*\):.*/\1/p')
  for k in $(printf '%s\n' "$dt" | sed -n 's/^\([A-Za-z_]*\):.*/\1/p'); do
    printf '%s\n' "$dw" | grep "^$k:" >/dev/null || solo="$solo tranche:$k"
  done
  [ "$ks" -ge 8 ] \
    || cf "only $ks shared CFG key(s) extracted -- the extractor stopped matching"

  finish "the runners' twin code is identical: $nb block(s) ($nl line(s)), $ns shared COMMON line(s) with each runner's own lines declared, $ks shared CFG default(s) (one runner only:${solo:- none})"
}

# =============================================================================
# THE DOCUMENTED goldenPaths ESCAPE MUST ACTUALLY SKIP
# =============================================================================
# A project with no pinned-output corpus passes goldenPaths '' to skip the zero-drift diff.
# `'' || <default>` IS the default, so the CFG default must use `??`, and the drift step's
# own guard must turn the empty value into a skip. Both halves are asserted: either alone
# stays green while the other breaks. The runners are read statically, so this case runs
# without Node.
#
# COMMENTS ARE STRIPPED BEFORE EVERY LOOKUP. The runners' comments name the guard, so with
# the guard ablated a plain grep would still match the prose. Strip toward over-stripping:
# an over-strip reddens loudly, an under-strip passes silently.
case_runner_goldenpaths_empty_skips() {
  cf_reset
  make_sandbox   # for SB_TMP + teardown; this case reads the REAL shipped runners

  local f lab found=0 bad=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    lab="$(basename "$f")"
    found=$(( found + 1 ))

    # THE OPERAND IS THE CODE, NOT THE FILE: every `//` comment is stripped first. See the header.
    local code; code="$(sed 's://.*::' "$f")"

    # HALF 1 — the CFG default falls through only on null/undefined.
    if printf '%s\n' "$code" | grep -E '^[[:space:]]*goldenPaths:[[:space:]]*ARGS\.goldenPaths[[:space:]]*\?\?'; then >/dev/null
      :
    else
      bad=$(( bad + 1 ))
      cf "$lab: goldenPaths does not use '??' — with '||' the documented empty-string escape restores the default instead of skipping the zero-drift step, which is the defect this case exists for"
    fi
    # And the specific regression, named so a reader knows what to look for.
    ! printf '%s\n' "$code" | grep -E '^[[:space:]]*goldenPaths:[[:space:]]*ARGS\.goldenPaths[[:space:]]*\|\|' >/dev/null \
      || { bad=$(( bad + 1 )); cf "$lab: goldenPaths is back to '||' — see the comment at that line before changing it"; }

    # HALF 2 — the drift step is guarded by the value, so an empty string skips it.
    # HALF 2 — the drift step is guarded by the value, so an empty string skips it. Two
    # shapes are accepted: `CFG.goldenPaths &&`, or a ternary chain with a prose fallback for
    # derived pins. Either way an empty goldenPaths must not reach the PATH step.
    printf '%s\n' "$code" | grep -E 'CFG\.goldenPaths &&|\? CFG\.goldenPaths$|: CFG\.goldenPaths$' >/dev/null \
      || { bad=$(( bad + 1 )); cf "$lab: the drift step has no guard on CFG.goldenPaths — '??' alone does not produce a skip, it only delivers the empty string to a step that would then run against nothing"; }

    # HALF 2b — AND AN EMPTY PROSE PIN SKIPS TOO: a project with neither pin declared gets no
    # step at all, not a step interpolating an empty rule.
    if printf '%s\n' "$code" | grep -E '^[[:space:]]*driftRule:'; then >/dev/null
      printf '%s\n' "$code" | grep -E 'CFG\.driftRule &&|\? CFG\.driftRule$|: CFG\.driftRule$' >/dev/null \
        || { bad=$(( bad + 1 )); cf "$lab: driftRule is declared and the drift step does not guard on it — a project with no pin of either kind would get a step naming an empty rule, which reads to the agent as a check with nothing to check"; }
    fi

    # HALF 3 — THE STEP TELLS THE AGENT AN EMPTY MATCH IS NOT A PASS. Where a pin is declared
    # and matches nothing, the diff prints nothing and reads like a clean one; this sentence
    # in the brief is the only defence, so it is asserted.
    printf '%s\n' "$code" | grep -F 'treat the zero-drift step as NOT RUN' >/dev/null \
      || { bad=$(( bad + 1 )); cf "$lab: the drift step no longer tells the agent that an empty match is NOT RUN rather than clean — that sentence is the whole defence against a diff over nothing being recorded as a clean zero-drift result"; }
  done <<EOF
$(_shipped_runners)
EOF

  # ASSERT THE EXTRACTOR: zero runners found checks nothing and reads green. Two is the
  # shipped count.
  [ "$found" -ge 2 ] \
    || cf "the extractor found only $found runner(s) — expected at least 2 (wave + tranche). A count this low means the glob stopped matching, NOT that the tree is clean."

  finish "runner goldenPaths: '' SKIPS the zero-drift step — '??' default AND the CFG guard, in every shipped runner ($found runner(s) checked, $bad finding(s))"
  teardown
}

# =============================================================================
# EVERY SHIPPED RUNNER MUST PARSE
# =============================================================================
# `bash -n` cannot read a .js file, so this is the parse check the runners get.
#
# The runners are not standalone modules: they run inside an async wrapper, so a top-level
# `return` is legal there and illegal to a standalone parser. A healthy runner fails a plain
# parse with exactly `Illegal return statement`; a broken one fails with something else. The
# assertion is that the ONLY parse error is the dialect one:
#   healthy: SyntaxError: Illegal return statement      <- expected, tolerated
#   broken:  SyntaxError: Unexpected identifier '...'   <- the real thing, refused
# Do not simplify this into a bare `node --check` and a rc test.
#
# Node is not a kit dependency, so this SKIPS where node is absent, naming the binary.
case_shipped_runners_parse() {
  cf_reset
  if ! command -v node >/dev/null 2>&1; then
    skp "shipped runners parse (only the harness-dialect error is tolerated)" "node is not on PATH, and the kit does not require it -- this case cannot run here"
    return
  fi
  make_sandbox   # for SB_TMP + teardown; this case reads the REAL shipped runners

  local f lab found=0 out rc
  for f in "$REAL_REPO_ROOT"/_claude/workflows/*.js "$REAL_REPO_ROOT"/.claude/workflows/*.js; do
    [ -e "$f" ] || continue
    lab="$(basename "$f")"
    found=$(( found + 1 ))
    out="$(node --input-type=module --check < "$f" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then
      continue   # parses outright; fine, and means the file has no top-level return
    fi
    # The ONE tolerated failure. Anything else is a real lexical or structural break.
    if printf '%s\n' "$out" | grep 'Illegal return statement'; then >/dev/null
      continue
    fi
    cf "$lab does NOT parse, and the failure is not the tolerated harness-dialect one: $(printf '%s' "$out" | grep -m1 'SyntaxError' || printf '%s' "$out" | head -1). A runner that cannot be loaded fails at 0 agents for every adopter who drives it."
  done

  # ASSERT THE EXTRACTOR. Zero runners found checks nothing and reads green.
  [ "$found" -ge 2 ] \
    || cf "the extractor found only $found runner(s) -- expected at least 2 (wave + tranche). A count this low means the glob stopped matching, NOT that the tree is clean."

  finish "shipped runners parse -- only the harness-dialect error is tolerated ($found runner(s) checked)"
  teardown
}

# One token per line, sorted. Scoped to the ratifying TABLE, not to the section.
_verdict_tokens_manual() {  # <path to MANUAL.md>
  awk '
    /^[[:space:]]*\|[[:space:]]*Verdict[[:space:]]*\|[[:space:]]*Token[[:space:]]*\|/ { intab=1; next }
    intab && /^[[:space:]]*\|[[:space:]]*-+/ { next }
    intab && /^[[:space:]]*\|/ { if (match($0, /`[A-Z_]+`/)) print substr($0, RSTART+1, RLENGTH-2); next }
    intab { intab=0 }
  ' "$1" | sort
}
# One token per line, sorted. Scoped to the DECLARATION, not to the file.
_verdict_tokens_runner() {  # <path to a runner .js>
  sed -n "s/^const VERDICTS = \[\(.*\)\]/\1/p" "$1" | grep -oE "'[A-Z_]+'" | tr -d "'" | sort
}

# =============================================================================
# CASE — THE VERDICT VOCABULARY HAS ONE AUTHORING SITE AND TWO PROJECTIONS.
#
# MANUAL.md § Dev → QA step 6 ratifies the verdict tokens: "Every schema, runner and report
# that carries a verdict PROJECTS this list; none of them re-enumerates it." A runner whose
# enum misses a member rejects a legitimate verdict at schema validation and halts the run.
#
# Both sides are re-derived from the files, never restated here. The MANUAL extractor reads
# only the rows of the `| Verdict | Token |` table and the runner extractor only the
# `const VERDICTS` declaration, and each is pinned on the side that can fail:
#   • `FAILED_AFTER_FIX_ROUND` is an `outcome:` value in the runners, so a runner extractor
#     that reads past `const VERDICTS` sweeps it in;
#   • a bare `FAIL` is MANUAL prose, so a MANUAL extractor that reads past the table sweeps
#     it in;
#   • the positive `PASS_AC_CORRECTED` pin reddens on a rename rather than going vacuous.
# =============================================================================
case_verdict_enum_projection() {
  cf_reset
  local wf="$REAL_REPO_ROOT/.claude/workflows" manual="$REAL_REPO_ROOT/process/MANUAL.md"
  if [ ! -d "$wf" ]; then
    skp "the verdict vocabulary: one authoring site, two projections" ".claude/workflows/ absent (the kit stores it disarmed; run this from a built kit)"
    return
  fi
  [ -f "$manual" ] || { skp "the verdict vocabulary: one authoring site, two projections" "process/MANUAL.md absent"; return; }

  local ratified n_ratified
  ratified="$(_verdict_tokens_manual "$manual")"
  n_ratified="$(printf '%s\n' "$ratified" | grep -c . || true)"

  # THE INSTRUMENT FIRST. An empty or over-broad extraction would make every
  # comparison below meaningless — empty vs empty "matches", and a scan that swept in
  # neighbouring vocabulary reports a divergence that is not there.
  [ "$n_ratified" -gt 0 ] \
    || cf "no ratified verdict tokens were extracted from MANUAL.md — the '| Verdict | Token |' table moved or was renamed, and every comparison below would be vacuous"
  printf '%s\n' "$ratified" | grep -x 'FAIL' >/dev/null \
    && cf "the MANUAL extractor swept in a bare FAIL — that is prose, not a ratified token: [$ratified]"
  # The one member whose absence has a recorded cost: a runner missing it cannot
  # represent a green review whose landing was correctly deferred.
  printf '%s\n' "$ratified" | grep -x 'PASS_AC_CORRECTED' >/dev/null \
    || cf "the ratified set does not contain PASS_AC_CORRECTED — either the ruling changed or the extractor is wrong: [$ratified]"

  local r name projected n_projected missing extra
  for r in "$wf"/*runner*.js; do
    [ -e "$r" ] || continue
    name="$(basename "$r")"
    projected="$(_verdict_tokens_runner "$r")"
    n_projected="$(printf '%s\n' "$projected" | grep -c . || true)"
    if [ "$n_projected" -eq 0 ]; then
      # A runner with no `const VERDICTS` is not a silent pass. Either it does not
      # carry a verdict (fine, and it should say so) or the declaration moved.
      if grep -q 'verdict' "$r"; then
        cf "$name mentions a verdict but no 'const VERDICTS = [...]' declaration was found — the projection cannot be checked and this is not a pass"
      fi
      continue
    fi
    # THE FAILED_AFTER_FIX_ROUND PIN sits on the runner side: it is an `outcome:` value on a
    # different field, so an extractor that read past `const VERDICTS` would sweep it in.
    printf '%s\n' "$projected" | grep -x 'FAILED_AFTER_FIX_ROUND' >/dev/null \
      && cf "$name's extractor swept in FAILED_AFTER_FIX_ROUND — that is an 'outcome' value on a DIFFERENT field, so the extractor is reading past 'const VERDICTS': [$projected]"
    if [ "$projected" != "$ratified" ]; then
      missing="$(comm -23 <(printf '%s\n' "$ratified") <(printf '%s\n' "$projected") | tr '\n' ' ')"
      extra="$(comm -13 <(printf '%s\n' "$ratified") <(printf '%s\n' "$projected") | tr '\n' ' ')"
      cf "$name's VERDICTS does not project the ratified set — missing: [${missing:-none}] extra: [${extra:-none}]. MANUAL § Dev → QA step 6 is the authoring site; the runner projects it and never re-enumerates it"
    fi
  done

  # --- THIRD LEG: THE PROSE THAT TELLS THE AGENT WHAT TO RETURN ------------------
  # The legs above compare declarations; the prompt is where the agent is told what to send
  # back, and a `verdict=<TOKEN>` outside VERDICTS is rejected at runtime.
  local pr tok bad
  for r in "$wf"/*.js; do
    [ -f "$r" ] || continue
    name="$(basename "$r")"
    projected="$(_verdict_tokens_runner "$r")"
    [ -n "$projected" ] || continue
    # Only the instructing form: bare "PASS/FAIL per bullet" prose is per-AC evidence on a
    # different field.
    pr="$(grep -oE 'verdict[[:space:]]*=[[:space:]]*[A-Z_]+' "$r" | grep -oE '[A-Z_]+$' | sort -u || true)"
    while IFS= read -r tok; do
      [ -n "$tok" ] || continue
      printf '%s\n' "$projected" | grep -x "$tok" >/dev/null \
        || cf "$name's PROMPT instructs 'verdict=$tok', which its own VERDICTS does not contain — the agent is told to return a value the schema rejects"
    done <<EOF
$pr
EOF
  done

  # Its control: the leg above is vacuous if no runner instructs a verdict, so inject one
  # that is NOT ratified and require the check to name it. $SB_TMP is empty here (no
  # make_sandbox), so fall back to a mktemp dir, and remove the parent as well as the child.
  local pctl="$SB_TMP" pctl_own=""
  [ -n "$pctl" ] || { pctl="$(mktemp -d)"; pctl_own=1; }
  mkdir -p "$pctl/pctl"
  if [ -f "$wf/tranche-runner.js" ]; then
    sed 's/Do NOT fix code yourself\./Do NOT fix code yourself. return verdict=BOGUS/' \
      "$wf/tranche-runner.js" > "$pctl/pctl/tranche-runner.js"
    bad="$(grep -oE 'verdict[[:space:]]*=[[:space:]]*[A-Z_]+' "$pctl/pctl/tranche-runner.js" | grep -oE '[A-Z_]+$' | sort -u || true)"
    printf '%s\n' "$bad" | grep -x 'BOGUS' >/dev/null \
      || cf "(control) the prompt extractor did not see an injected 'verdict=BOGUS' — the third leg cannot bite"
  else
    cf "(control) tranche-runner.js not found — the prompt-prose control could not run"
  fi
  rm -rf "$pctl/pctl"
  [ -n "$pctl_own" ] && rm -rf "$pctl"

  # --- REDDENING CONTROL: drop a member from a COPY and the comparison must fail --
  # Without this the loop above passes whenever both sides are equal, including when
  # the extractors are both broken in the same direction.
  local ctl="$SB_TMP" ctl_own=""
  [ -n "$ctl" ] || { ctl="$(mktemp -d)"; ctl_own=1; }   # removed at the end, parent and all
  mkdir -p "$ctl/vctl"
  local src="$wf/wave-runner.js"
  if [ -f "$src" ]; then
    sed "s/'PASS_AC_CORRECTED', //" "$src" > "$ctl/vctl/wave-runner.js"
    local ablated
    ablated="$(_verdict_tokens_runner "$ctl/vctl/wave-runner.js")"
    [ "$ablated" != "$ratified" ] \
      || cf "(control) dropping PASS_AC_CORRECTED from a copy of wave-runner.js did NOT change the extracted set — the extractor is not reading the declaration, so the comparison above proves nothing"
    printf '%s\n' "$ablated" | grep -x 'PASS_AC_CORRECTED' >/dev/null \
      && cf "(control) the ablated copy still yields PASS_AC_CORRECTED — the ablation did not take"
    comm -23 <(printf '%s\n' "$ratified") <(printf '%s\n' "$ablated") | grep -x 'PASS_AC_CORRECTED' >/dev/null \
      || cf "(control) the comparison does not name PASS_AC_CORRECTED as the missing member, so a real drift would be reported without saying what drifted"
  else
    cf "(control) wave-runner.js not found at $src — the reddening control could not run"
  fi
  rm -rf "$ctl/vctl"

  # --- REDDENING CONTROL, MANUAL SIDE: the extraction must depend on THAT TABLE ------
  # The `n_ratified > 0` guard only defends deletion. An extractor that reads past the table
  # but stays inside step 6 picks the same tokens out of the prose and stays green, so
  # corrupting the table header must change the extraction. It pins no literal, so a rename
  # cannot make it vacuous.
  mkdir -p "$ctl/mctl"
  sed 's/|[[:space:]]*Verdict[[:space:]]*|[[:space:]]*Token[[:space:]]*|/| Xerdict | Xoken |/' \
    "$manual" > "$ctl/mctl/MANUAL.md"
  if ! grep -q '| Xerdict | Xoken |' "$ctl/mctl/MANUAL.md"; then
    cf "(control) could not corrupt the '| Verdict | Token |' header on a COPY of MANUAL.md — the ablation did not take, so the green above does not establish that the extractor reads that table"
  else
    local m_ablated
    m_ablated="$(_verdict_tokens_manual "$ctl/mctl/MANUAL.md")"
    [ "$m_ablated" != "$ratified" ] \
      || cf "(control) corrupting the ratifying table's header did NOT change the MANUAL extraction — the extractor is not anchored on that table, so it is reading the same tokens out of neighbouring prose and every comparison above is about the wrong operand: [$ratified]"
  fi
  rm -rf "$ctl/mctl"
  [ -n "$ctl_own" ] && rm -rf "$ctl"

  finish "the verdict vocabulary: every *runner*.js VERDICTS array projects MANUAL § Dev → QA step 6's ratified tokens, both sides re-derived from the files, each extractor ablation-proven against its own authority (a dropped member reddens naming itself; a corrupted table header changes the extraction)"
}

# =============================================================================
# CASE — each runner's stray-key guard admits every per-issue field that runner READS.
#
# The operand-set defect (doctrine/instruments.md § A.6): the fields a runner reads are
# derivable from the file, so nothing is maintained by hand.
case_runner_key_guards_admit_every_field_they_read() {
  cf_reset
  local wf="$REAL_REPO_ROOT/.claude/workflows" r name n=0
  [ -d "$wf" ] || _fixture_die "case_runner_key_guards_admit_every_field_they_read: no .claude/workflows/ in the published kit at $REAL_REPO_ROOT"

  for r in "$wf"/*.js; do
    [ -f "$r" ] || continue
    name="$(basename "$r")"
    grep -q 'const ISSUE_KEYS' "$r" || continue
    n=$(( n + 1 ))
    # Declared: the quoted names inside the ISSUE_KEYS literal. Read: every issue.<field> in the
    # file. `issue.sh` is excluded — it is the tail of a path in prose, not a field.
    local missing
    missing="$(python3 - "$r" <<'PY'
import re,sys
s=open(sys.argv[1],encoding='utf-8').read()
m=re.search(r'const ISSUE_KEYS = new Set\(\[(.*?)\]\)', s, re.S)
declared=set(re.findall(r"'([A-Za-z_]+)'", m.group(1))) if m else set()
used={x for x in re.findall(r'issue\.([A-Za-z_]+)', s)} - {'sh'}
print(' '.join(sorted(used - declared)))
PY
)"
    [ -z "$missing" ] \
      || cf "$name reads per-issue field(s) its own ISSUE_KEYS refuses: $missing — every call passing one throws before any agent starts"
  done

  [ "$n" -ge 1 ] \
    || cf "no runner declared an ISSUE_KEYS set — either the guard was removed or its name changed, and this case then asserts nothing"

  # REDDENING CONTROL: drop a name from a COPY and the derivation must report it.
  local ctl="$SB_TMP" ctl_own=""; [ -n "$ctl" ] || { ctl="$(mktemp -d)"; ctl_own=1; }
  mkdir -p "$ctl/kctl"
  if [ -f "$wf/wave-runner.js" ]; then
    sed "s/'worktreeMode', //" "$wf/wave-runner.js" > "$ctl/kctl/wave-runner.js"
    local ablated
    ablated="$(python3 - "$ctl/kctl/wave-runner.js" <<'PY'
import re,sys
s=open(sys.argv[1],encoding='utf-8').read()
m=re.search(r'const ISSUE_KEYS = new Set\(\[(.*?)\]\)', s, re.S)
declared=set(re.findall(r"'([A-Za-z_]+)'", m.group(1))) if m else set()
used={x for x in re.findall(r'issue\.([A-Za-z_]+)', s)} - {'sh'}
print(' '.join(sorted(used - declared)))
PY
)"
    printf '%s' "$ablated" | grep 'worktreeMode' >/dev/null \
      || cf "(control) dropping worktreeMode from a copy did NOT surface it — the derivation cannot bite"
  else
    cf "(control) wave-runner.js not found — the reddening control could not run"
  fi
  rm -rf "$ctl/kctl"
  [ -n "$ctl_own" ] && rm -rf "$ctl"   # the parent too: removing only the child left it behind

  finish "each runner's ISSUE_KEYS admits every per-issue field that runner actually reads ($n runner(s), derived from the file, ablation-proven)"
}

# THE BRIEF STUB: runs a runner file with `args` from argv (a JSON value) and prints one JSON line,
# { ok, briefs, text } or { ok: false, error, briefs }. `agent()` returns a schema-shaped reply;
# nothing is dispatched. <dest path>
_wf_brief_stub() {
  cat > "$1" <<'STUBEOF'
import fs from 'node:fs'
const [file, argsJson] = process.argv.slice(2)
const src = fs.readFileSync(file, 'utf8').replace(/^export const meta/m, 'const meta')
const briefs = []
const stubFor = (schema) => {
  const o = {}
  for (const [k, v] of Object.entries((schema && schema.properties) || {})) {
    if (v.enum) o[k] = v.enum[0]
    else if (v.type === 'array') o[k] = []
    else if (v.type === 'integer' || v.type === 'number') o[k] = 0
    else if (v.type === 'boolean') o[k] = true
    else if (v.type === 'object') o[k] = {}
    else o[k] = 'stub'
  }
  return o
}
const agent = async (prompt, opts) => {
  opts = opts || {}
  briefs.push(String(prompt))
  return opts.schema ? stubFor(opts.schema) : 'stub'
}
const parallel = async (t) => Promise.all(t.map((f) => f()))
const pipeline = async (items, ...stages) => Promise.all(items.map(async (it, i) => {
  let acc = it
  for (const s of stages) acc = await s(acc, it, i)
  return acc
}))
const phase = () => {}
const log = () => {}
const args = JSON.parse(argsJson)
const budget = { total: null, spent: () => 0, remaining: () => Infinity }
const body = new Function('agent', 'parallel', 'pipeline', 'phase', 'log', 'args', 'budget',
  'return (async () => { ' + src + ' })()')
try {
  await body(agent, parallel, pipeline, phase, log, args, budget)
  console.log(JSON.stringify({ ok: true, briefs: briefs.length, text: briefs.join(String.fromCharCode(10)) }))
} catch (e) {
  console.log(JSON.stringify({ ok: false, error: String((e && e.message) || e), briefs: briefs.length }))
}
STUBEOF
}

# CASE — the shipped workflow runners COMPOSE every brief they would send, from a realistic
# args payload, without throwing. This is the harness EXERCISING the kit rather than reading
# it: a runner that throws before its first agent cannot be found by reading.
#
# NOTHING IS DISPATCHED. `agent()` is stubbed to return a schema-shaped object, so the script
# runs its real control flow and builds its real prompts at zero agent cost. What is under
# test is the CONTRACT — that a caller following the documented shape can start a run.
case_workflow_briefs_compose_from_a_sparse_payload() {
  cf_reset
  local wf="$REAL_REPO_ROOT/.claude/workflows" stub out n=0
  [ -d "$wf" ] || _fixture_die "case_workflow_briefs_compose_from_a_sparse_payload: no .claude/workflows/ in the published kit at $REAL_REPO_ROOT"
  if ! command -v node >/dev/null 2>&1; then
    skp "the shipped workflow runners compose their briefs from a sparse args payload" "node absent"
    return
  fi

  stub="$(mktemp -d)/stub-run.mjs"
  _wf_brief_stub "$stub"

  # THE PAYLOAD IS DELIBERATELY SPARSE: only the fields a caller must supply. Every optional
  # per-issue key is omitted.
  local T_ARGS='{"repo":"/tmp/x","issues":[{"id":"ZZ-1","branch":"b","title":"t","devModel":"opus","devEffort":"high","qaModel":"opus","qaEffort":"high"}]}'
  local W_ARGS='{"repo":"/tmp/x","wave1":[{"id":"ZZ-1","branch":"b","title":"t","devModel":"opus","devEffort":"high","qaModel":"opus","qaEffort":"high","worktreeMode":"self","phase":"Wave1","restartNote":"n"}]}'

  _wf_run() { node "$stub" "$1" "$2" 2>&1; }
  _wf_ok()  { printf '%s' "$1" | grep '"ok":true' >/dev/null; }
  _wf_err() { printf '%s' "$1" | sed -n 's/.*"error":"\([^"]*\)".*/\1/p'; }

  # --- tranche-runner, sparse ------------------------------------------------------
  out="$(_wf_run "$wf/tranche-runner.js" "$T_ARGS")"; n=$(( n + 1 ))
  _wf_ok "$out" \
    || cf "tranche-runner THREW composing its briefs from a payload carrying only the required per-issue fields: $(_wf_err "$out")"

  # --- wave-runner, sparse + the wave-only fields its own description advertises ----
  out="$(_wf_run "$wf/wave-runner.js" "$W_ARGS")"; n=$(( n + 1 ))
  _wf_ok "$out" \
    || cf "wave-runner THREW composing its briefs from a payload using the wave-only fields meta.description advertises: $(_wf_err "$out")"

  # --- a MISSPELLED per-issue key must be REFUSED BY NAME, not silently ignored -----
  out="$(_wf_run "$wf/tranche-runner.js" '{"repo":"/tmp/x","issues":[{"id":"ZZ-1","branch":"b","title":"t","devModel":"o","devEffort":"h","qaModel":"o","qaEffort":"h","depends_ons":["ZZ-0"]}]}')"
  _wf_ok "$out" \
    && cf "a misspelled per-issue key (depends_ons) was ACCEPTED — a caller who meant to declare a dependency would get a silent solo run"
  printf '%s' "$out" | grep 'depends_ons' >/dev/null \
    || cf "the misspelled key was refused but not NAMED, so the caller cannot see which key is wrong"

  # --- ABLATION: the exerciser must be able to go red -------------------------------
  # Remove the depends_on guard from a COPY and the throw must come back; otherwise the
  # stub is not running the runner's real control flow.
  local abl; abl="$(dirname "$stub")/abl.js"
  sed 's/Array.isArray(issue.depends_on) ? issue.depends_on : \[\]/issue.depends_on/' \
    "$wf/tranche-runner.js" > "$abl"
  out="$(_wf_run "$abl" "$T_ARGS")"
  _wf_ok "$out" \
    && cf "(ablation) removing the depends_on guard did NOT reproduce the crash — the stub is not running the runner's real control flow, so every green above is empty"

  rm -rf "$(dirname "$stub")"
  unset -f _wf_run _wf_ok _wf_err
  finish "both shipped workflow runners compose every brief from a payload carrying only the REQUIRED per-issue fields, refuse a misspelled key by name, and the exerciser is ablation-proven (the depends_on guard removed from a copy) ($n runner(s), nothing dispatched)"
}

# CASE — a prose (non-JSON) `args` is refused at 0 agents, naming the runner and its args shape.
#
# Each runner parses a string `args` inside a guard, so a caller who sends prose learns which
# runner refused and what shape it wanted. Without the guard the raw SyntaxError names neither.
# Control: the same runner accepts a JSON payload sent as a string (the guard's other branch).
# Ablation: the guard removed from a copy must fail the refusal check.
_prose_refused() {   # <stub output> <runner name> <shape token>: 0 when refused as documented
  printf '%s' "$1" | grep -F '"ok":false' >/dev/null \
    && printf '%s' "$1" | grep -F '"briefs":0' >/dev/null \
    && printf '%s' "$1" | grep -F "$2: args must be a JSON object" >/dev/null \
    && printf '%s' "$1" | grep -F "$3" >/dev/null
}

case_runner_refuses_a_prose_payload_by_name() {
  cf_reset
  local wf="$REAL_REPO_ROOT/.claude/workflows" stub out file name shape json n=0
  [ -d "$wf" ] || _fixture_die "case_runner_refuses_a_prose_payload_by_name: no .claude/workflows/ in the published kit at $REAL_REPO_ROOT"
  command -v node >/dev/null 2>&1 || { skp "a prose args payload is refused by name" "node absent"; return; }

  stub="$(mktemp -d)/stub-run.mjs"
  _wf_brief_stub "$stub"
  local prose='"Please run ZZ-1 then ZZ-2, opus, high effort"'

  while IFS='|' read -r file name shape json; do
    [ -n "$file" ] || continue
    n=$(( n + 1 ))
    out="$(node "$stub" "$wf/$file" "$prose" 2>&1)"
    _prose_refused "$out" "$name" "$shape" \
      || cf "$file did not refuse a prose payload at 0 agents naming '$name' and its shape '$shape': $(printf '%s' "$out" | cut -c1-200)"

    # CONTROL: JSON sent as a string is parsed, not refused.
    out="$(node "$stub" "$wf/$file" "\"$(printf '%s' "$json" | sed 's/"/\\"/g')\"" 2>&1)"
    printf '%s' "$out" | grep -F '"ok":true' >/dev/null \
      || cf "(control) $file refused a valid JSON payload sent as a string: $(printf '%s' "$out" | cut -c1-200)"

    # ABLATION: the guard removed from a copy must fail the check above.
    awk '/^try \{$/ { next } /^\} catch \(e\) \{$/ { skip = 1; next } skip { if (/^\}$/) skip = 0; next } { print }' \
      "$wf/$file" > "$(dirname "$stub")/abl.js"
    if grep -F 'not prose' "$(dirname "$stub")/abl.js" >/dev/null; then
      cf "(ablation) removing the guard from a copy of $file did not take -- the check below would prove nothing"
    else
      out="$(node "$stub" "$(dirname "$stub")/abl.js" "$prose" 2>&1)"
      _prose_refused "$out" "$name" "$shape" \
        && cf "(ablation) $file with its guard removed still passed the refusal check -- the check cannot bite"
    fi
  done <<'EOF'
tranche-runner.js|tranche-runner|issues: [|{"repo":"/tmp/x","issues":[{"id":"ZZ-1","branch":"b","title":"t","devModel":"opus","devEffort":"high","qaModel":"opus","qaEffort":"high"}]}
wave-runner.js|wave-runner|wave1: [|{"repo":"/tmp/x","wave1":[{"id":"ZZ-1","branch":"b","title":"t","devModel":"opus","devEffort":"high","qaModel":"opus","qaEffort":"high"}]}
EOF

  [ "$n" -eq 2 ] || cf "expected 2 runner rows, read $n"
  rm -rf "$(dirname "$stub")"
  finish "a prose args payload is refused at 0 agents naming the runner and its args shape; JSON sent as a string is accepted; the guard removed from a copy fails the check ($n runner(s), nothing dispatched)"
}

# CASE — a QA leg that forms NO verdict is filed as NO_VERDICT, never as FAILED_AFTER_FIX_ROUND.
#
# FAILED_AFTER_FIX_ROUND is composed from a verdict FAIL in the ratified table. A leg that
# returned nothing reviewed nothing (MANUAL step 6's could-not-run rule).
#
# THE STUB DOES NOT FILL OPTIONAL FIELDS (not required, description beginning "OPTIONAL."), or
# every reply would carry precondition_failure: 'stub' and every review would halt as NO_VERDICT.
#
# NOTHING IS DISPATCHED. `agent()` is stubbed and SCRIPTED by label prefix: a prefix mapped to null
# returns null (the leg formed nothing), a prefix mapped to an object returns a schema-shaped reply
# with those fields overridden. Two CONTROL rows hold the neighbours still: a genuine FAIL-then-FAIL
# must stay FAILED_AFTER_FIX_ROUND, and a PASS must stay LANDED — so the case cannot go green by
# relabelling every non-pass.
case_runner_no_verdict_is_not_a_failure() {
  cf_reset
  local wf="$REAL_REPO_ROOT/.claude/workflows" stub out n=0 row name script want got
  [ -d "$wf" ] || _fixture_die "case_runner_no_verdict_is_not_a_failure: no .claude/workflows/ in the published kit at $REAL_REPO_ROOT"
  command -v node >/dev/null 2>&1 || { skp "the review leg that forms no verdict is NO_VERDICT, not a failure" "node absent"; return; }

  stub="$(mktemp -d)/drive.mjs"
  cat > "$stub" <<'STUBEOF'
import fs from 'node:fs'
const [file, argsJson, scriptJson] = process.argv.slice(2)
const script = JSON.parse(scriptJson)
const src = fs.readFileSync(file, 'utf8').replace(/^export const meta/m, 'const meta')
const stubFor = (schema) => {
  const o = {}
  for (const [k, v] of Object.entries((schema && schema.properties) || {})) {
    if (!((schema.required || []).includes(k)) && /^OPTIONAL\./.test(v.description || '')) continue
    if (v.enum) o[k] = v.enum[0]
    else if (v.type === 'array') o[k] = []
    else if (v.type === 'integer' || v.type === 'number') o[k] = 0
    else if (v.type === 'boolean') o[k] = true
    else if (v.type === 'object') o[k] = {}
    else o[k] = 'stub'
  }
  return o
}
const agent = async (prompt, opts) => {
  opts = opts || {}
  const pre = String(opts.label || '').split(':')[0]
  if (Object.prototype.hasOwnProperty.call(script, pre)) return script[pre] === null ? null : Object.assign(stubFor(opts.schema), script[pre])
  return opts.schema ? stubFor(opts.schema) : 'stub'
}
const parallel = async (t) => Promise.all(t.map((f) => f()))
const pipeline = async (items, ...stages) => Promise.all(items.map(async (it, i) => { let acc = it; for (const s of stages) acc = await s(acc, it, i); return acc }))
const body = new Function('agent', 'parallel', 'pipeline', 'phase', 'log', 'args', 'budget', 'return (async () => { ' + src + ' })()')
try {
  const r = await body(agent, parallel, pipeline, () => {}, () => {}, JSON.parse(argsJson), { total: null, spent: () => 0, remaining: () => Infinity })
  console.log(((r && r.results) || []).map(x => x.outcome).join(','))
} catch (e) { console.log('THREW:' + String((e && e.message) || e)) }
STUBEOF

  local T_ARGS='{"repo":"/tmp/x","issues":[{"id":"ZZ-1","branch":"b","title":"t","devModel":"opus","devEffort":"high","qaModel":"opus","qaEffort":"high"}]}'
  local W_ARGS='{"repo":"/tmp/x","wave1":[{"id":"ZZ-1","branch":"b","title":"t","devModel":"opus","devEffort":"high","qaModel":"opus","qaEffort":"high","worktreeMode":"self","phase":"Wave1","restartNote":"n"}]}'

  # name | agent script | expected outcome
  while IFS='|' read -r name script want; do
    [ -n "$name" ] || continue
    for row in "tranche-runner.js|$T_ARGS" "wave-runner.js|$W_ARGS"; do
      [ -f "$wf/${row%%|*}" ] || { cf "${row%%|*} not found in $wf"; continue; }
      got="$(node "$stub" "$wf/${row%%|*}" "${row#*|}" "$script" 2>&1)"; n=$(( n + 1 ))
      [ "$got" = "$want" ] \
        || cf "${row%%|*} [$name]: expected $want, got '$got'"
    done
  done <<'ROWS'
first QA leg returned nothing|{"qa":null}|NO_VERDICT
FAIL, fix round, second QA returned nothing|{"qa":{"verdict":"FAIL_AC"},"qa2":null}|NO_VERDICT
verdict outside the ratified set|{"qa":{"verdict":"NOT_A_TOKEN"}}|NO_VERDICT
CONTROL: FAIL, fix round, FAIL again|{"qa":{"verdict":"FAIL_AC"},"qa2":{"verdict":"FAIL_REGRESSION"}}|FAILED_AFTER_FIX_ROUND
CONTROL: PASS, landed|{}|LANDED
ROWS

  rm -rf "$(dirname "$stub")"
  finish "a review leg that forms no verdict is filed as NO_VERDICT in both runners — never FAILED_AFTER_FIX_ROUND — while a real FAIL-twice and a PASS keep their outcomes ($n drive(s), nothing dispatched)"
}

# CASE — a leg that ended with NOTHING is named for that, never as a verdict or a status it did not give.
#
# An absent park verdict is NO_VERDICT (as the issue review's is), and an absent Dev reply
# is LEG_ABORTED (as a thrown leg is): both halt, and neither spends a further leg.
# PARK_UNVERIFIED and BLOCKED_DEV are judgements a reply gives, never the absence of one.
#
# The CONTROL rows hold the neighbours still: a park review that PASSES is PARKED_OK, one that FAILS
# (twice, in the tranche runner) is PARK_UNVERIFIED, and a Dev that REPORTS blocked on an unparkable
# issue is BLOCKED_DEV — so the case cannot go green by relabelling every non-success.
# THE STUB DOES NOT FILL OPTIONAL FIELDS (not required, description beginning "OPTIONAL."), or
# every reply would carry precondition_failure: 'stub' and every review would halt as NO_VERDICT.
case_runner_absent_reply_is_named_not_judged() {
  cf_reset
  local wf="$REAL_REPO_ROOT/.claude/workflows" stub got want f args name park script n=0
  [ -d "$wf" ] || _fixture_die "case_runner_absent_reply_is_named_not_judged: no .claude/workflows/ in the published kit at $REAL_REPO_ROOT"
  command -v node >/dev/null 2>&1 || { skp "a leg that ended with nothing is named, not judged" "node absent"; return; }

  stub="$(mktemp -d)/drive.mjs"
  cat > "$stub" <<'STUBEOF'
import fs from 'node:fs'
const [file, argsJson, scriptJson] = process.argv.slice(2)
const script = JSON.parse(scriptJson)
const src = fs.readFileSync(file, 'utf8').replace(/^export const meta/m, 'const meta')
const stubFor = (schema) => {
  const o = {}
  for (const [k, v] of Object.entries((schema && schema.properties) || {})) {
    if (!((schema.required || []).includes(k)) && /^OPTIONAL\./.test(v.description || '')) continue
    if (v.enum) o[k] = v.enum[0]
    else if (v.type === 'array') o[k] = []
    else if (v.type === 'integer' || v.type === 'number') o[k] = 0
    else if (v.type === 'boolean') o[k] = true
    else if (v.type === 'object') o[k] = {}
    else o[k] = 'stub'
  }
  return o
}
const has = (k) => Object.prototype.hasOwnProperty.call(script, k)
const agent = async (prompt, opts) => {
  opts = opts || {}
  const label = String(opts.label || ''), pre = label.split(':')[0]
  const key = has(label) ? label : (has(pre) ? pre : null)
  if (key !== null) {
    if (script[key] === 'THROW') throw new Error('budget ceiling reached')
    return script[key] === null ? null : Object.assign(stubFor(opts.schema), script[key])
  }
  return opts.schema ? stubFor(opts.schema) : 'stub'
}
const parallel = async (t) => Promise.all(t.map(async (f) => { try { return await f() } catch (e) { return null } }))
const pipeline = async (items, ...stages) => Promise.all(items.map(async (it, i) => { let acc = it; for (const s of stages) acc = await s(acc, it, i); return acc }))
const body = new Function('agent', 'parallel', 'pipeline', 'phase', 'log', 'args', 'budget', 'return (async () => { ' + src + ' })()')
try {
  const r = await body(agent, parallel, pipeline, () => {}, () => {}, JSON.parse(argsJson), { total: null, spent: () => 0, remaining: () => Infinity })
  console.log(String(r && r.halted) + '|' + ((r && r.results) || []).map(x => x.id + '=' + (x.outcome || (x.skipped ? 'skipped' : '?'))).join(','))
} catch (e) { console.log('REJECTED:' + String((e && e.message) || e)) }
STUBEOF

  local base='"id":"ZZ-1","branch":"b","title":"t","devModel":"opus","devEffort":"high","qaModel":"opus","qaEffort":"high"'
  local wv=',"worktreeMode":"self","phase":"Wave1","restartNote":"n"'

  # runner | row | parkable | agent script | expected "halted|outcomes"
  while IFS='|' read -r f name park script want_h want_o; do
    [ -n "$f" ] || continue
    [ -f "$wf/$f" ] || { cf "$f not found in $wf"; continue; }
    case "$f" in
      tranche-runner.js) args="{\"repo\":\"/tmp/x\",\"issues\":[{$base,\"parkable\":$park}]}" ;;
      *)                 args="{\"repo\":\"/tmp/x\",\"wave1\":[{$base$wv,\"parkable\":$park}]}" ;;
    esac
    got="$(node "$stub" "$wf/$f" "$args" "$script" 2>&1)"; n=$(( n + 1 ))
    want="$want_h|$want_o"
    [ "$got" = "$want" ] || cf "$f [$name]: expected '$want', got '$got'"
  done <<'ROWS'
tranche-runner.js|park review returned nothing|true|{"dev":{"status":"blocked"},"park-qa":null}|ZZ-1|ZZ-1=NO_VERDICT
wave-runner.js|park review returned nothing|true|{"dev":{"status":"blocked"},"park-qa":null}|wave1|ZZ-1=NO_VERDICT
tranche-runner.js|park verdict outside the set|true|{"dev":{"status":"blocked"},"park-qa":{"verdict":"BOGUS"}}|ZZ-1|ZZ-1=NO_VERDICT
wave-runner.js|park verdict outside the set|true|{"dev":{"status":"blocked"},"park-qa":{"verdict":"BOGUS"}}|wave1|ZZ-1=NO_VERDICT
tranche-runner.js|park FAIL, fix, second park review nothing|true|{"dev":{"status":"blocked"},"park-qa":{"verdict":"FAIL_AC"},"dev-park-fix":{"status":"blocked"},"park-qa2":null}|ZZ-1|ZZ-1=NO_VERDICT
tranche-runner.js|Dev returned nothing|false|{"dev":null}|ZZ-1|ZZ-1=LEG_ABORTED
wave-runner.js|Dev returned nothing|false|{"dev":null}|wave1|ZZ-1=LEG_ABORTED
tranche-runner.js|QA FAIL, fix-round Dev returned nothing|false|{"qa":{"verdict":"FAIL_AC"},"dev-fix":null}|ZZ-1|ZZ-1=LEG_ABORTED
wave-runner.js|QA FAIL, fix-round Dev returned nothing|false|{"qa":{"verdict":"FAIL_AC"},"dev-fix":null}|wave1|ZZ-1=LEG_ABORTED
tranche-runner.js|park FAIL, park-fix Dev returned nothing|true|{"dev":{"status":"blocked"},"park-qa":{"verdict":"FAIL_AC"},"dev-park-fix":null}|ZZ-1|ZZ-1=LEG_ABORTED
tranche-runner.js|CONTROL: park review PASS|true|{"dev":{"status":"blocked"},"park-qa":{"verdict":"PASS"}}|null|ZZ-1=PARKED_OK
wave-runner.js|CONTROL: park review PASS|true|{"dev":{"status":"blocked"},"park-qa":{"verdict":"PASS"}}|null|ZZ-1=PARKED_OK
tranche-runner.js|CONTROL: park review FAIL twice|true|{"dev":{"status":"blocked"},"park-qa":{"verdict":"FAIL_AC"},"dev-park-fix":{"status":"blocked"},"park-qa2":{"verdict":"FAIL_AC"}}|ZZ-1|ZZ-1=PARK_UNVERIFIED
wave-runner.js|CONTROL: park review FAIL|true|{"dev":{"status":"blocked"},"park-qa":{"verdict":"FAIL_AC"}}|wave1|ZZ-1=PARK_UNVERIFIED
tranche-runner.js|CONTROL: Dev reports blocked, unparkable|false|{"dev":{"status":"blocked"}}|ZZ-1|ZZ-1=BLOCKED_DEV
wave-runner.js|CONTROL: Dev reports blocked, unparkable|false|{"dev":{"status":"blocked"}}|wave1|ZZ-1=BLOCKED_DEV
ROWS

  rm -rf "$(dirname "$stub")"
  finish "a park review that formed no verdict is NO_VERDICT (and spends no park fix round), and a Dev leg that returned nothing is LEG_ABORTED, in both runners — while a park PASS, a park FAIL and a REPORTED blocked keep their outcomes ($n drive(s), nothing dispatched)"
}

# CASE — a leg whose agent() THROWS is named LEG_ABORTED and halts the run; no runner drops an issue.
#
# The Workflow runtime's agent() THROWS once the turn's token budget ceiling is reached (and
# on a call it refuses), and parallel() resolves a throwing thunk to null. That null must
# not vanish from the outcomes, and a serial runner must not reject the run and lose the
# outcomes it already recorded.
#
# THE parallel() STUB IS THE RUNTIME'S, NOT THE SIBLING CASE'S: a throwing thunk resolves to
# null, and the call never rejects.
# The all-green row is the CONTROL: nothing throws, nothing halts, every issue is named.
# THE STUB DOES NOT FILL OPTIONAL FIELDS (not required, description beginning "OPTIONAL."), or
# every reply would carry precondition_failure: 'stub' and every review would halt as NO_VERDICT.
case_runner_throwing_leg_is_named_not_dropped() {
  cf_reset
  local wf="$REAL_REPO_ROOT/.claude/workflows" stub got want name script f args n=0
  [ -d "$wf" ] || _fixture_die "case_runner_throwing_leg_is_named_not_dropped: no .claude/workflows/ in the published kit at $REAL_REPO_ROOT"
  command -v node >/dev/null 2>&1 || { skp "a leg whose agent() throws is LEG_ABORTED, not dropped" "node absent"; return; }

  stub="$(mktemp -d)/drive.mjs"
  cat > "$stub" <<'STUBEOF'
import fs from 'node:fs'
const [file, argsJson, scriptJson] = process.argv.slice(2)
const script = JSON.parse(scriptJson)
const src = fs.readFileSync(file, 'utf8').replace(/^export const meta/m, 'const meta')
const stubFor = (schema) => {
  const o = {}
  for (const [k, v] of Object.entries((schema && schema.properties) || {})) {
    if (!((schema.required || []).includes(k)) && /^OPTIONAL\./.test(v.description || '')) continue
    if (v.enum) o[k] = v.enum[0]
    else if (v.type === 'array') o[k] = []
    else if (v.type === 'integer' || v.type === 'number') o[k] = 0
    else if (v.type === 'boolean') o[k] = true
    else if (v.type === 'object') o[k] = {}
    else o[k] = 'stub'
  }
  return o
}
const has = (k) => Object.prototype.hasOwnProperty.call(script, k)
const agent = async (prompt, opts) => {
  opts = opts || {}
  const label = String(opts.label || ''), pre = label.split(':')[0]
  const key = has(label) ? label : (has(pre) ? pre : null)
  if (key !== null) {
    if (script[key] === 'THROW') throw new Error('budget ceiling reached')
    return script[key] === null ? null : Object.assign(stubFor(opts.schema), script[key])
  }
  return opts.schema ? stubFor(opts.schema) : 'stub'
}
const parallel = async (t) => Promise.all(t.map(async (f) => { try { return await f() } catch (e) { return null } }))
const pipeline = async (items, ...stages) => Promise.all(items.map(async (it, i) => { let acc = it; for (const s of stages) acc = await s(acc, it, i); return acc }))
const body = new Function('agent', 'parallel', 'pipeline', 'phase', 'log', 'args', 'budget', 'return (async () => { ' + src + ' })()')
try {
  const r = await body(agent, parallel, pipeline, () => {}, () => {}, JSON.parse(argsJson), { total: null, spent: () => 0, remaining: () => Infinity })
  console.log(String(r && r.halted) + '|' + ((r && r.results) || []).map(x => x.id + '=' + (x.outcome || (x.skipped ? 'skipped' : '?'))).join(','))
} catch (e) { console.log('REJECTED:' + String((e && e.message) || e)) }
STUBEOF

  local base='"branch":"b","title":"t","devModel":"opus","devEffort":"high","qaModel":"opus","qaEffort":"high"'
  local wv=',"worktreeMode":"self","restartNote":"n"'
  local T_ARGS="{\"repo\":\"/tmp/x\",\"issues\":[{\"id\":\"ZZ-1\",$base},{\"id\":\"ZZ-2\",$base},{\"id\":\"ZZ-3\",$base}]}"
  local W_ARGS="{\"repo\":\"/tmp/x\",\"wave1\":[{\"id\":\"ZZ-1\",$base$wv,\"phase\":\"Wave1\"},{\"id\":\"ZZ-2\",$base$wv,\"phase\":\"Wave1\"}],\"wave2\":[{\"id\":\"ZZ-3\",$base$wv,\"phase\":\"Wave2\"}]}"

  # runner | row | agent script | expected "halted|outcomes"
  while IFS='|' read -r f name script want_h want_o; do
    [ -n "$f" ] || continue
    [ -f "$wf/$f" ] || { cf "$f not found in $wf"; continue; }
    case "$f" in tranche-runner.js) args="$T_ARGS" ;; *) args="$W_ARGS" ;; esac
    got="$(node "$stub" "$wf/$f" "$args" "$script" 2>&1)"; n=$(( n + 1 ))
    want="$want_h|$want_o"
    [ "$got" = "$want" ] || cf "$f [$name]: expected '$want', got '$got'"
  done <<'ROWS'
tranche-runner.js|ZZ-1 QA throws|{"qa:ZZ-1":"THROW"}|ZZ-1|ZZ-1=LEG_ABORTED,ZZ-2=skipped,ZZ-3=skipped
wave-runner.js|ZZ-1 QA throws|{"qa:ZZ-1":"THROW"}|wave1|ZZ-1=LEG_ABORTED,ZZ-2=LANDED
tranche-runner.js|ZZ-2 QA throws after ZZ-1 landed|{"qa:ZZ-2":"THROW"}|ZZ-2|ZZ-1=LANDED,ZZ-2=LEG_ABORTED,ZZ-3=skipped
wave-runner.js|ZZ-2 QA throws|{"qa:ZZ-2":"THROW"}|wave1|ZZ-1=LANDED,ZZ-2=LEG_ABORTED
tranche-runner.js|every Dev leg throws|{"dev":"THROW"}|ZZ-1|ZZ-1=LEG_ABORTED,ZZ-2=skipped,ZZ-3=skipped
wave-runner.js|every Dev leg throws|{"dev":"THROW"}|wave1|ZZ-1=LEG_ABORTED,ZZ-2=LEG_ABORTED
tranche-runner.js|CONTROL: nothing throws|{}|null|ZZ-1=LANDED,ZZ-2=LANDED,ZZ-3=LANDED
wave-runner.js|CONTROL: nothing throws|{}|null|ZZ-1=LANDED,ZZ-2=LANDED,ZZ-3=LANDED
ROWS

  # A RUNNER BUG STAYS LOUD. Only a throw from agent() is an outcome; a throw from the
  # runner's own code is a defect and must fail the run. So the depends_on guard is removed
  # from a COPY, and each runner must fail the run rather than return one.
  local bugdir="$(dirname "$stub")/bug"; mkdir -p "$bugdir"
  for f in tranche-runner.js wave-runner.js; do
    [ -f "$wf/$f" ] || continue
    sed 's/Array.isArray(issue.depends_on) ? issue.depends_on : \[\]/issue.depends_on/' "$wf/$f" > "$bugdir/$f"
    cmp -s "$wf/$f" "$bugdir/$f" && { cf "$f: the depends_on-guard ablation did not take (the pattern moved), so the loud-bug row proves nothing"; continue; }
    case "$f" in tranche-runner.js) args="$T_ARGS" ;; *) args="$W_ARGS" ;; esac
    got="$(node "$stub" "$bugdir/$f" "$args" '{}' 2>&1)"; n=$(( n + 1 ))
    case "$got" in
      REJECTED:*) ;;
      *) cf "$f: a bug in the runner's own code (depends_on guard removed from a copy) did not fail the run — got '$got'; a runner that files or drops its own bug hides it" ;;
    esac
  done

  rm -rf "$(dirname "$stub")"
  finish "a leg whose agent() throws is named LEG_ABORTED and halts the run in both runners, with no issue dropped and no recorded outcome lost — a bug in the runner's own code still fails the run loudly, and a run where nothing throws is unchanged ($n drive(s), nothing dispatched)"
}

# CASE — a reviewer that reports a PRECONDITION FAILURE has a legal reply, and it is NO_VERDICT.
#
# MANUAL step 6: a gate that could not run, or an AC naming a gate the tree does not hold,
# leaves no verdict to issue. The runtime retries a structured-output agent until its reply
# validates, so a required `verdict` would force the reviewer to invent a token. Each QA and
# park schema carries an OPTIONAL `precondition_failure`, `verdict` is not required, and a
# reply naming one is NO_VERDICT whatever token came with it.
#
# TWO ARMS. (1) The schemas, read off the agent() calls the runner really makes: `verdict` is NOT
# required, `precondition_failure` IS declared, and `verdict` is still exactly VERDICTS — the field is
# separate so the ratified vocabulary does not grow. (2) The routing, driven. CONTROL rows keep a real
# FAIL-twice, a PASS, a park PASS, and a PASS beside an EMPTY precondition_failure (models fill optional
# strings with "", and a blank must not halt a run) on their old outcomes.
#
# THE STUB DOES NOT FILL OPTIONAL FIELDS. A stub that fills every declared property would send
# precondition_failure: 'stub' on every reply and turn every row into NO_VERDICT; it skips a property
# that is not required and whose description begins "OPTIONAL." — the schemas' own convention.
case_runner_precondition_failure_has_a_reply() {
  cf_reset
  local wf="$REAL_REPO_ROOT/.claude/workflows" stub got want f args name park script n=0 sch
  [ -d "$wf" ] || _fixture_die "case_runner_precondition_failure_has_a_reply: no .claude/workflows/ in the published kit at $REAL_REPO_ROOT"
  command -v node >/dev/null 2>&1 || { skp "a precondition failure has a legal reply, and it is NO_VERDICT" "node absent"; return; }

  stub="$(mktemp -d)/drive.mjs"
  cat > "$stub" <<'STUBEOF'
import fs from 'node:fs'
const [file, argsJson, scriptJson, mode] = process.argv.slice(2)
const script = JSON.parse(scriptJson)
const src = fs.readFileSync(file, 'utf8').replace(/^export const meta/m, 'const meta')
const stubFor = (schema) => {
  const o = {}
  for (const [k, v] of Object.entries((schema && schema.properties) || {})) {
    if (!((schema.required || []).includes(k)) && /^OPTIONAL\./.test(v.description || '')) continue
    if (v.enum) o[k] = v.enum[0]
    else if (v.type === 'array') o[k] = []
    else if (v.type === 'integer' || v.type === 'number') o[k] = 0
    else if (v.type === 'boolean') o[k] = true
    else if (v.type === 'object') o[k] = {}
    else o[k] = 'stub'
  }
  return o
}
const has = (k) => Object.prototype.hasOwnProperty.call(script, k)
const seen = {}
const agent = async (prompt, opts) => {
  opts = opts || {}
  const label = String(opts.label || ''), pre = label.split(':')[0]
  if (opts.schema && /qa/.test(pre)) seen[pre.replace(/2$/, '')] = opts.schema
  const key = has(label) ? label : (has(pre) ? pre : null)
  if (key !== null) {
    const v = script[key]
    if (v === null) return null
    const o = Object.assign(stubFor(opts.schema), v)
    for (const k of (v.__omit || [])) delete o[k]
    delete o.__omit
    return o
  }
  return opts.schema ? stubFor(opts.schema) : 'stub'
}
const parallel = async (t) => Promise.all(t.map(async (f) => { try { return await f() } catch (e) { return null } }))
const pipeline = async (items, ...stages) => Promise.all(items.map(async (it, i) => { let acc = it; for (const s of stages) acc = await s(acc, it, i); return acc }))
const body = new Function('agent', 'parallel', 'pipeline', 'phase', 'log', 'args', 'budget', 'return (async () => { ' + src + ' })()')
try {
  const r = await body(agent, parallel, pipeline, () => {}, () => {}, JSON.parse(argsJson), { total: null, spent: () => 0, remaining: () => Infinity })
  if (mode === 'schemas') {
    for (const [leg, s] of Object.entries(seen)) {
      const req = (s.required || []).includes('verdict') ? 'verdict-required' : 'verdict-optional'
      const pf = (s.properties || {}).precondition_failure ? 'pf-declared' : 'pf-absent'
      const en = JSON.stringify(((s.properties || {}).verdict || {}).enum || [])
      console.log(leg + ' ' + req + ' ' + pf + ' ' + en)
    }
  } else {
    console.log(String(r && r.halted) + '|' + ((r && r.results) || []).map(x => x.id + '=' + (x.outcome || '?')).join(','))
  }
} catch (e) { console.log('REJECTED:' + String((e && e.message) || e)) }
STUBEOF

  local base='"id":"ZZ-1","branch":"b","title":"t","devModel":"opus","devEffort":"high","qaModel":"opus","qaEffort":"high"'
  local wv=',"worktreeMode":"self","phase":"Wave1","restartNote":"n"'
  _pf_args() { case "$1" in
      tranche-runner.js) printf '{"repo":"/tmp/x","issues":[{%s,"parkable":%s}]}' "$base" "$2" ;;
      *)                 printf '{"repo":"/tmp/x","wave1":[{%s%s,"parkable":%s}]}' "$base" "$wv" "$2" ;;
    esac; }

  # ARM 1 — the schemas the runners actually hand to agent(), QA and park, in both runners.
  for f in tranche-runner.js wave-runner.js; do
    [ -f "$wf/$f" ] || { cf "$f not found in $wf"; continue; }
    sch="$(node "$stub" "$wf/$f" "$(_pf_args "$f" false)" '{}' schemas; node "$stub" "$wf/$f" "$(_pf_args "$f" true)" '{"dev":{"status":"blocked"}}' schemas)"
    for leg in qa park-qa; do
      got="$(printf '%s\n' "$sch" | grep "^$leg " | head -1)"
      [ -n "$got" ] || { cf "$f: no $leg schema was seen — the drive did not reach that leg, so the schema arm checked nothing"; continue; }
      case "$got" in *verdict-required*) cf "$f $leg: verdict is still REQUIRED — a reviewer obeying step 6 has no legal reply" ;; esac
      case "$got" in *pf-absent*) cf "$f $leg: no precondition_failure property — nowhere to say that no verdict was possible" ;; esac
      case "$got" in *'["PASS","PASS_AC_CORRECTED","FAIL_AC","FAIL_REGRESSION"]'*) ;; *) cf "$f $leg: the verdict enum is not exactly the four ratified tokens — the precondition failure must be a separate field, not a fifth token: [$got]" ;; esac
      n=$(( n + 1 ))
    done
  done

  # ARM 2 — routing. runner | row | parkable | agent script | expected "halted|outcomes"
  while IFS='|' read -r f name park script want_h want_o; do
    [ -n "$f" ] || continue
    [ -f "$wf/$f" ] || continue
    got="$(node "$stub" "$wf/$f" "$(_pf_args "$f" "$park")" "$script" 2>&1)"; n=$(( n + 1 ))
    want="$want_h|$want_o"
    [ "$got" = "$want" ] || cf "$f [$name]: expected '$want', got '$got'"
  done <<'ROWS'
tranche-runner.js|precondition + invented FAIL|false|{"qa":{"precondition_failure":"gate X could not run","verdict":"FAIL_AC"}}|ZZ-1|ZZ-1=NO_VERDICT
wave-runner.js|precondition + invented FAIL|false|{"qa":{"precondition_failure":"gate X could not run","verdict":"FAIL_AC"}}|wave1|ZZ-1=NO_VERDICT
tranche-runner.js|precondition + invented PASS|false|{"qa":{"precondition_failure":"gate X could not run","verdict":"PASS"}}|ZZ-1|ZZ-1=NO_VERDICT
wave-runner.js|precondition + invented PASS|false|{"qa":{"precondition_failure":"gate X could not run","verdict":"PASS"}}|wave1|ZZ-1=NO_VERDICT
tranche-runner.js|precondition, verdict omitted|false|{"qa":{"precondition_failure":"gate X could not run","__omit":["verdict"]}}|ZZ-1|ZZ-1=NO_VERDICT
wave-runner.js|precondition, verdict omitted|false|{"qa":{"precondition_failure":"gate X could not run","__omit":["verdict"]}}|wave1|ZZ-1=NO_VERDICT
tranche-runner.js|park precondition + FAIL|true|{"dev":{"status":"blocked"},"park-qa":{"precondition_failure":"check-board.sh could not run","verdict":"FAIL_AC"}}|ZZ-1|ZZ-1=NO_VERDICT
wave-runner.js|park precondition + FAIL|true|{"dev":{"status":"blocked"},"park-qa":{"precondition_failure":"check-board.sh could not run","verdict":"FAIL_AC"}}|wave1|ZZ-1=NO_VERDICT
tranche-runner.js|park precondition + PASS|true|{"dev":{"status":"blocked"},"park-qa":{"precondition_failure":"check-board.sh could not run","verdict":"PASS"}}|ZZ-1|ZZ-1=NO_VERDICT
wave-runner.js|park precondition + PASS|true|{"dev":{"status":"blocked"},"park-qa":{"precondition_failure":"check-board.sh could not run","verdict":"PASS"}}|wave1|ZZ-1=NO_VERDICT
tranche-runner.js|CONTROL: FAIL twice|false|{"qa":{"verdict":"FAIL_AC"},"qa2":{"verdict":"FAIL_REGRESSION"}}|ZZ-1|ZZ-1=FAILED_AFTER_FIX_ROUND
wave-runner.js|CONTROL: FAIL twice|false|{"qa":{"verdict":"FAIL_AC"},"qa2":{"verdict":"FAIL_REGRESSION"}}|wave1|ZZ-1=FAILED_AFTER_FIX_ROUND
tranche-runner.js|FAIL, fix Dev blocked, no second QA|true|{"qa":{"verdict":"FAIL_AC"},"dev-fix":{"status":"blocked"}}|ZZ-1|ZZ-1=FAILED_AFTER_FIX_ROUND
wave-runner.js|FAIL, fix Dev blocked, no second QA|true|{"qa":{"verdict":"FAIL_AC"},"dev-fix":{"status":"blocked"}}|wave1|ZZ-1=FAILED_AFTER_FIX_ROUND
tranche-runner.js|CONTROL: PASS|false|{}|null|ZZ-1=LANDED
wave-runner.js|CONTROL: PASS|false|{}|null|ZZ-1=LANDED
tranche-runner.js|CONTROL: PASS beside an EMPTY precondition_failure|false|{"qa":{"precondition_failure":"","verdict":"PASS"}}|null|ZZ-1=LANDED
wave-runner.js|CONTROL: PASS beside an EMPTY precondition_failure|false|{"qa":{"precondition_failure":"","verdict":"PASS"}}|null|ZZ-1=LANDED
tranche-runner.js|CONTROL: park PASS|true|{"dev":{"status":"blocked"},"park-qa":{"verdict":"PASS"}}|null|ZZ-1=PARKED_OK
wave-runner.js|CONTROL: park PASS|true|{"dev":{"status":"blocked"},"park-qa":{"verdict":"PASS"}}|null|ZZ-1=PARKED_OK
ROWS
  unset -f _pf_args

  rm -rf "$(dirname "$stub")"
  finish "both runners' QA and park schemas let a reviewer report a precondition failure instead of inventing a verdict — verdict not required, precondition_failure declared, the enum still the four ratified tokens — and such a reply is NO_VERDICT whatever token came with it, while a real FAIL, a PASS, a park PASS and a PASS beside an empty string keep their outcomes ($n check(s), nothing dispatched)"
}

# CASE — every record a runner returns carries each leg's free text, SUCCESS INCLUDED.
#
# Every record carries `leg_notes`: one entry per leg that replied, in call order, on the
# success paths too, where a leg's caveats and premise_refuted would otherwise be lost.
#
# MARKERS ARE READ FROM `leg_notes` ONLY, not from the whole record: the failure paths already carried
# the raw `dev`/`qa`/`park` objects, so a whole-record search would be green on them without the fix.
# Rows cover success (LANDED, LAND_READY, PARKED_OK), failure (FAILED_AFTER_FIX_ROUND, with BOTH Dev
# replies — nothing earlier is overwritten), and a thrown QA leg (the Dev leg before it keeps its
# entry). The CONTROL row: an EMPTY free-text field adds nothing, so a filler cannot pose as a note.
#
# THE STUB DOES NOT FILL OPTIONAL FIELDS (a property not required whose description begins
# "OPTIONAL."), or every reply would carry precondition_failure: 'stub' and every review would halt.
case_runner_returns_leg_notes_on_every_outcome() {
  cf_reset
  local wf="$REAL_REPO_ROOT/.claude/workflows" stub got want f args name park script n=0
  [ -d "$wf" ] || _fixture_die "case_runner_returns_leg_notes_on_every_outcome: no .claude/workflows/ in the published kit at $REAL_REPO_ROOT"
  command -v node >/dev/null 2>&1 || { skp "every runner record carries its legs' free text" "node absent"; return; }

  stub="$(mktemp -d)/drive.mjs"
  cat > "$stub" <<'STUBEOF'
import fs from 'node:fs'
const [file, argsJson, scriptJson] = process.argv.slice(2)
const script = JSON.parse(scriptJson)
const src = fs.readFileSync(file, 'utf8').replace(/^export const meta/m, 'const meta')
const stubFor = (schema) => {
  const o = {}
  for (const [k, v] of Object.entries((schema && schema.properties) || {})) {
    if (!((schema.required || []).includes(k)) && /^OPTIONAL\./.test(v.description || '')) continue
    if (v.enum) o[k] = v.enum[0]
    else if (v.type === 'array') o[k] = []
    else if (v.type === 'integer' || v.type === 'number') o[k] = 0
    else if (v.type === 'boolean') o[k] = true
    else if (v.type === 'object') o[k] = {}
    else o[k] = 'stub'
  }
  return o
}
const has = (k) => Object.prototype.hasOwnProperty.call(script, k)
const agent = async (prompt, opts) => {
  opts = opts || {}
  const label = String(opts.label || ''), pre = label.split(':')[0]
  const key = has(label) ? label : (has(pre) ? pre : null)
  if (key !== null) {
    const v = script[key]
    if (v === null) return null
    if (v === 'THROW') throw new Error('budget ceiling reached')
    const o = Object.assign(stubFor(opts.schema), v)
    for (const k of (v.__omit || [])) delete o[k]
    delete o.__omit
    return o
  }
  return opts.schema ? stubFor(opts.schema) : 'stub'
}
const parallel = async (t) => Promise.all(t.map(async (f) => { try { return await f() } catch (e) { return null } }))
const pipeline = async (items, ...stages) => Promise.all(items.map(async (it, i) => { let acc = it; for (const s of stages) acc = await s(acc, it, i); return acc }))
const body = new Function('agent', 'parallel', 'pipeline', 'phase', 'log', 'args', 'budget', 'return (async () => { ' + src + ' })()')
try {
  const r = await body(agent, parallel, pipeline, () => {}, () => {}, JSON.parse(argsJson), { total: null, spent: () => 0, remaining: () => Infinity })
  const marks = ['MARK-DEV-SUMMARY', 'MARK-DEV-DEVIATIONS', 'MARK-REVIEW-NOTES', 'MARK-PREMISE', 'MARK-FIX-SUMMARY']
  console.log(((r && r.results) || []).filter(x => x.outcome).map(x => x.outcome + '[' + marks.filter(m => JSON.stringify(x.leg_notes || []).includes(m)).map(m => m.replace('MARK-', '')).join(',') + ']' + (Array.isArray(x.leg_notes) ? '' : '(no leg_notes)')).join(' '))
} catch (e) { console.log('REJECTED:' + String((e && e.message) || e)) }
STUBEOF

  local base='"id":"ZZ-1","branch":"b","title":"t","devModel":"opus","devEffort":"high","qaModel":"opus","qaEffort":"high"'
  local wv=',"worktreeMode":"self","phase":"Wave1","restartNote":"n"'
  local D='"summary":"built MARK-DEV-SUMMARY","deviations":"MARK-DEV-DEVIATIONS"'
  _ln_args() { case "$1" in
      tranche-runner.js) printf '{"repo":"/tmp/x","issues":[{%s,"parkable":%s}]}' "$base" "$2" ;;
      *)                 printf '{"repo":"/tmp/x","wave1":[{%s%s,"parkable":%s}]}' "$base" "$wv" "$2" ;;
    esac; }

  # row | parkable | agent script (@D@ = a Dev reply's marked free text) | expected, both runners
  while IFS='|' read -r name park script want; do
    [ -n "$name" ] || continue
    script="$(printf '%s' "$script" | sed "s/@D@/$D/g")"
    for f in tranche-runner.js wave-runner.js; do
      [ -f "$wf/$f" ] || { cf "$f not found in $wf"; continue; }
      got="$(node "$stub" "$wf/$f" "$(_ln_args "$f" "$park")" "$script" 2>&1)"; n=$(( n + 1 ))
      [ "$got" = "$want" ] || cf "$f [$name]: expected '$want', got '$got'"
    done
  done <<'ROWS'
LANDED|false|{"dev":{@D@},"qa":{"verdict":"PASS","landing":"landed","notes":"MARK-REVIEW-NOTES","premise_refuted":"MARK-PREMISE"}}|LANDED[DEV-SUMMARY,DEV-DEVIATIONS,REVIEW-NOTES,PREMISE]
LAND_READY|false|{"dev":{@D@},"qa":{"verdict":"PASS","landing":"deferred","notes":"MARK-REVIEW-NOTES"}}|LAND_READY[DEV-SUMMARY,DEV-DEVIATIONS,REVIEW-NOTES]
PARKED_OK|true|{"dev":{"status":"blocked",@D@},"park-qa":{"verdict":"PASS","notes":"MARK-REVIEW-NOTES"}}|PARKED_OK[DEV-SUMMARY,DEV-DEVIATIONS,REVIEW-NOTES]
FAIL, fix, FAIL — both Dev replies kept|false|{"dev":{@D@},"dev-fix":{"summary":"MARK-FIX-SUMMARY"},"qa":{"verdict":"FAIL_AC"},"qa2":{"verdict":"FAIL_AC","notes":"MARK-REVIEW-NOTES"}}|FAILED_AFTER_FIX_ROUND[DEV-SUMMARY,DEV-DEVIATIONS,REVIEW-NOTES,FIX-SUMMARY]
QA throws — the Dev entry before it kept|false|{"dev":{@D@},"qa":"THROW"}|LEG_ABORTED[DEV-SUMMARY,DEV-DEVIATIONS]
CONTROL: empty free text adds nothing|false|{"dev":{"summary":"","deviations":""},"qa":{"verdict":"PASS","landing":"landed","notes":""}}|LANDED[]
ROWS
  unset -f _ln_args

  rm -rf "$(dirname "$stub")"
  finish "every record both runners return carries each leg's free text as leg_notes — on LANDED, LAND_READY and PARKED_OK as well as on failures and a thrown leg — in call order, with nothing overwritten and no entry for an empty field ($n drive(s), nothing dispatched)"
}

# _runner_record_stub <path> — a driver that dispatches nothing and prints each agent() call it
# receives: `<label> <agentType|-> <model|-> <effort|->`, or, given a label prefix as the third
# argument, the prompts of the calls under it.
_runner_record_stub() {
  cat > "$1" <<'STUBEOF'
import fs from 'node:fs'
const [file, argsJson, want] = process.argv.slice(2)
const src = fs.readFileSync(file, 'utf8').replace(/^export const meta/m, 'const meta')
const stubFor = (schema) => {
  const o = {}
  for (const [k, v] of Object.entries((schema && schema.properties) || {})) {
    if (!((schema.required || []).includes(k)) && /^OPTIONAL\./.test(v.description || '')) continue
    if (v.enum) o[k] = v.enum[0]
    else if (v.type === 'array') o[k] = []
    else if (v.type === 'integer' || v.type === 'number') o[k] = 0
    else if (v.type === 'boolean') o[k] = true
    else if (v.type === 'object') o[k] = {}
    else o[k] = 'stub'
  }
  return o
}
const seen = []
const agent = async (prompt, opts) => { seen.push([prompt, opts || {}]); return opts && opts.schema ? stubFor(opts.schema) : 'stub' }
const parallel = async (t) => Promise.all(t.map((f) => f()))
const pipeline = async (items, ...stages) => Promise.all(items.map(async (it, i) => { let acc = it; for (const s of stages) acc = await s(acc, it, i); return acc }))
const body = new Function('agent', 'parallel', 'pipeline', 'phase', 'log', 'args', 'budget', 'return (async () => { ' + src + ' })()')
try {
  await body(agent, parallel, pipeline, () => {}, () => {}, JSON.parse(argsJson), { total: null, spent: () => 0, remaining: () => Infinity })
  for (const [p, o] of seen) {
    if (want) { if (String(o.label).startsWith(want)) console.log(p) }
    else console.log([o.label, o.agentType ?? '-', o.model ?? '-', o.effort ?? '-'].join(' '))
  }
} catch (e) { console.log('THREW:' + String((e && e.message) || e)) }
STUBEOF
}

# CASE — a leg that names a .claude/agents/ type keeps that type's frontmatter pin.
#
# Measured before the fix: both runners sent the run default (opus/medium) on every call, so a
# typed leg never ran on its pin (refactorer-worker's `effort: high`, ui-designer-worker's
# `model: sonnet`) unless the issue repeated it. The CONTROL rows hold the neighbours: an untyped
# leg still gets the defaults (never undefined), and a typed leg's explicit value still overrides.
case_runner_typed_leg_keeps_its_frontmatter_pin() {
  cf_reset
  local wf="$REAL_REPO_ROOT/.claude/workflows" stub f name fields want got args n=0
  [ -d "$wf" ] || _fixture_die "case_runner_typed_leg_keeps_its_frontmatter_pin: no .claude/workflows/ in the published kit at $REAL_REPO_ROOT"
  command -v node >/dev/null 2>&1 || { skp "a typed leg keeps its frontmatter pin" "node absent"; return; }
  stub="$(mktemp -d)/drive.mjs"; _runner_record_stub "$stub"
  # row | issue fields | the first dev call's `<agentType> <model> <effort>`, both runners
  while IFS='|' read -r name fields want; do
    [ -n "$name" ] || continue
    for f in tranche-runner.js wave-runner.js; do
      case "$f" in
        tranche-runner.js) args="{\"repo\":\"/tmp/x\",\"issues\":[{\"id\":\"ZZ-1\",\"branch\":\"b\",\"title\":\"t\"$fields}]}" ;;
        *)                 args="{\"repo\":\"/tmp/x\",\"wave1\":[{\"id\":\"ZZ-1\",\"branch\":\"b\",\"title\":\"t\",\"phase\":\"W\"$fields}]}" ;;
      esac
      got="$(node "$stub" "$wf/$f" "$args" 2>&1 | sed -n 's/^dev:ZZ-1 //p' | head -1)"; n=$(( n + 1 ))
      [ "$got" = "$want" ] || cf "$f [$name]: expected '$want', got '$got'"
    done
  done <<'ROWS'
typed, nothing named: the frontmatter governs|,"devAgentType":"refactorer-worker"|refactorer-worker - -
typed, effort named: only that is sent|,"devAgentType":"refactorer-worker","devEffort":"medium"|refactorer-worker - medium
CONTROL: typed, both named|,"devAgentType":"ui-designer-worker","devModel":"opus","devEffort":"high"|ui-designer-worker opus high
CONTROL: untyped gets the run defaults|,"devEffort":"high"|- opus high
ROWS
  rm -rf "$(dirname "$stub")"
  finish "both runners send a typed leg only the model/effort its issue names, so the type's frontmatter pin governs the rest, while an untyped leg still gets the run defaults ($n drive(s), nothing dispatched)"
}

# CASE — each wave leg's brief tells it where it may switch branches, and nothing else.
#
# Measured before the fix: the brief every wave leg shares said "work in YOUR OWN worktree, never
# run git checkout or git switch in the shared root", while the main-checkout leg's own steps
# told it to create its branch and `git switch` there.
case_wave_brief_matches_the_legs_checkout() {
  cf_reset
  local wf="$REAL_REPO_ROOT/.claude/workflows/wave-runner.js" stub leg out
  [ -f "$wf" ] || _fixture_die "case_wave_brief_matches_the_legs_checkout: no wave-runner.js in the published kit at $REAL_REPO_ROOT"
  command -v node >/dev/null 2>&1 || { skp "each wave leg's brief matches its checkout" "node absent"; return; }
  stub="$(mktemp -d)/drive.mjs"; _runner_record_stub "$stub"
  local main='{"repo":"/tmp/x","wave1":[{"id":"ZZ-1","branch":"b","title":"t","phase":"W"}]}'
  local wt='{"repo":"/tmp/x","wave1":[{"id":"ZZ-1","branch":"b","title":"t","phase":"W","worktreeMode":"self"}]}'
  for leg in dev: qa:; do
    out="$(node "$stub" "$wf" "$main" "$leg" 2>&1)"
    [ -n "$out" ] || _fixture_die "case_wave_brief_matches_the_legs_checkout: no $leg prompt was composed."
    printf '%s\n' "$out" | grep -i 'your own worktree' >/dev/null \
      && cf "the main-checkout leg's $leg brief tells it to work in its own worktree"
  done
  out="$(node "$stub" "$wf" "$main" qa: 2>&1)"
  printf '%s\n' "$out" | grep -F 'git switch' >/dev/null \
    || cf "(control) the main-checkout QA brief no longer says how to check the branch out"
  out="$(node "$stub" "$wf" "$wt" dev: 2>&1)"
  printf '%s\n' "$out" | grep -iE 'never runs? git checkout or git switch in the (main checkout|shared root)' >/dev/null \
    || cf "(control) the worktree leg's brief no longer forbids switching in the main checkout"
  rm -rf "$(dirname "$stub")"
  finish "wave-runner: the main-checkout leg is never told to work in its own worktree, and the worktree leg is still told never to switch in the main checkout"
}

# CASE — settings.json.example never glosses a placeholder it does not contain.
#
# Bidirectional: every glossed <token> appears in the file (a gloss must not outlive its
# subject), and every <token> in the file is glossed (a fix must not delete a gloss while the
# token stays).
case_settings_example_glosses_only_real_placeholders() {
  cf_reset
  # $REAL_REPO_ROOT, not a sandbox: this file is a kit deliverable for the operator to copy,
  # and an initialized project is not given it.
  local f="$REAL_REPO_ROOT/.claude/settings.json.example" declared present tok
  [ -f "$f" ] || _fixture_die "case_settings_example_glosses_only_real_placeholders: no .claude/settings.json.example in the published kit at $REAL_REPO_ROOT"

  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$f" \
    || cf "settings.json.example is not valid JSON"

  # Tokens the file GLOSSES (keys of _PLACEHOLDERS, if that key exists at all) ...
  declared="$(python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
print("\n".join(k for k in d.get("_PLACEHOLDERS",{}) if k.startswith("<")))' "$f")"

  # ... versus tokens the file actually CONTAINS, everywhere but that map.
  present="$(python3 -c '
import json,re,sys
d=json.load(open(sys.argv[1]))
# Underscore keys are this file COMMENTING ON ITSELF - the carve-out that exists
# because JSON has no comment syntax. A token QUOTED in that commentary (including
# the note recording which tokens were REMOVED) is not a token to replace, and
# counting it is the self-scanning census defect: the explanation of an absence
# reads as a presence.
body=json.dumps({k:v for k,v in d.items() if not k.startswith("_")})
print("\n".join(sorted(set(re.findall(r"<[A-Za-z][A-Za-z-]*>", body)))))' "$f")"

  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    printf '%s\n' "$present" | grep -xF "$tok" >/dev/null \
      || cf "_PLACEHOLDERS glosses $tok, which appears NOWHERE else in the file — the adopter is told to replace text that is not there"
  done <<EOF
$declared
EOF

  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    printf '%s\n' "$declared" | grep -xF "$tok" >/dev/null \
      || cf "$tok appears in the file but no _PLACEHOLDERS entry says what to put there"
  done <<EOF
$present
EOF

  finish "settings.json.example: every <token> it glosses appears in it, and every <token> in it is glossed (both directions)"
}

# =============================================================================
# CASE — EVERY LEAF-WORKER DEFINITION CARRIES THE SECTIONS ITS SIBLINGS CARRY.
#
# The sections hold the quota discipline, the output budget and the commit rules. THE
# REQUIRED SET IS DERIVED BY MAJORITY, NEVER LISTED: a literal list goes blind when a section
# is added or renamed, and some definitions legitimately carry a section of their own, so set
# equality would redden on correct content.
# =============================================================================
case_leaf_workers_carry_the_common_sections() {
  cf_reset
  make_sandbox
  local ad="" d
  for d in "$REAL_REPO_ROOT/_claude/agents" "$REAL_REPO_ROOT/.claude/agents"; do [ -d "$d" ] && ad="$d"; done
  if [ -z "$ad" ]; then skp "leaf-worker definitions carry the sections their siblings carry" "no agents/ directory"; teardown; return; fi

  local n f base req missing=""
  n="$(ls "$ad"/*.md 2>/dev/null | wc -l | tr -d ' ')"
  [ "${n:-0}" -ge 5 ] \
    || _fixture_die "case_leaf_workers_carry_the_common_sections: only ${n:-0} definition(s) scanned — a majority over a lost operand finds nothing and passes."

  # Headings, normalised: the parenthetical differs legitimately per hat
  # ("Read order (before judging anything)" vs "(before probing anything)").
  req="$( for f in "$ad"/*.md; do
            [ -e "$f" ] || continue
            sed -n 's/^## //p' "$f" | sed 's/[[:space:]]*(.*)$//'
          done | sort | uniq -c | awk -v t="$n" '$1 * 2 > t { $1=""; sub(/^ /,""); print }' )"
  [ -n "$req" ] \
    || _fixture_die "case_leaf_workers_carry_the_common_sections: the derived required set is EMPTY — a zero-heading majority finds zero misses and reports PASS."

  while IFS= read -r f; do
    [ -n "$f" ] || continue
    base="$(basename "$f")"
    while IFS= read -r h; do
      [ -n "$h" ] || continue
      sed -n 's/^## //p' "$f" | sed 's/[[:space:]]*(.*)$//' | grep -xF "$h" >/dev/null \
        || missing="$missing
    $base is missing '$h'"
    done <<REQ_EOF
$req
REQ_EOF
  done <<DEFS_EOF
$(ls "$ad"/*.md)
DEFS_EOF

  [ -z "$missing" ] \
    || cf "a leaf-worker definition is missing a section every one of its siblings carries — that is where the quota discipline, the output budget and the commit rules live, so this worker is dispatched without the constraints the others run under:$missing"

  finish "every leaf-worker definition carries the sections a majority of them carry ($n definitions, $(printf '%s' "$req" | grep -c .) derived sections; a hat's own unique section is correctly NOT required)"
  teardown
}

# =============================================================================
# CASE — WHEREVER THE PROVISIONING CEILING IS STATED, THE SEAT RULE IS STATED WITH IT.
#
# The seat rule — the seat is human-partnered rather than a provisionable worker — must sit
# beside every statement of the provisioning ceiling. At some sites the retired model-class
# ban was the only sentence carrying it, so removing the ban can silently remove the rule.
#
# SCOPED TO roles/ AND agents/: a recursive sweep would match the harness itself.
# =============================================================================
case_provisioning_ceiling_keeps_the_seat_rule() {
  cf_reset
  make_sandbox
  local cd_="" d
  for d in "$REAL_REPO_ROOT/_claude" "$REAL_REPO_ROOT/.claude"; do [ -d "$d" ] && cd_="$d"; done
  if [ -z "$cd_" ]; then skp "the ceiling rule keeps the seat rule beside it" "no _claude/.claude directory"; teardown; return; fi

  local sites f n=0 missing=""
  sites="$( { grep -rl 'sanctioned ceiling' "$cd_/roles" "$cd_/agents" 2>/dev/null || true; } )"
  n="$(printf '%s\n' "$sites" | grep -c . || true)"
  [ "${n:-0}" -ge 5 ] \
    || _fixture_die "case_provisioning_ceiling_keeps_the_seat_rule: only ${n:-0} site(s) state the ceiling — the sweep lost its subject, which is not the same as a clean tree."

  while IFS= read -r f; do
    [ -n "$f" ] || continue
    # THE SEAT RULE, matched on its declared tokens rather than a whole sentence — the
    # wording differs legitimately between a role doc and a worker definition.
    grep -q 'human-partnered' "$f" && grep -q 'provisionable' "$f" \
      || missing="$missing $(basename "$f")"
  done <<SITES_EOF
$sites
SITES_EOF

  [ -z "$missing" ] \
    || cf "these state the provisioning ceiling but no longer state that the seat is human-partnered rather than a provisionable worker —$missing"

  finish "every site stating the provisioning ceiling ($n of them) also states the seat rule"
  teardown
}

# =============================================================================
# CASE — THE AGENT MODEL PINS MATCH WHAT THE KIT DECLARES ABOUT THEM.
#
# Every leaf-worker definition pins a `model:`, a vendor's product name — the class
# EXTRACTION § 4.10 otherwise keeps out of the kit, kept as a declared carve-out with one
# definition named as the exception. THIS ASSERTS THE DECLARATION, NEVER THE VALUE: a named
# model here would hard-code the product fact and redden on the vendor's rename. It reads
# the shape: the pins agree except for exactly one file, the one the declaration names.
# =============================================================================
case_agent_model_pins_match_their_declaration() {
  cf_reset
  make_sandbox
  local ad="" d
  for d in "$REAL_REPO_ROOT/_claude/agents" "$REAL_REPO_ROOT/.claude/agents"; do
    [ -d "$d" ] && ad="$d"
  done
  if [ -z "$ad" ]; then skp "agent model pins match their declaration" "no agents/ directory"; teardown; return; fi

  # Derive (file, pin) pairs. The VALUES are compared to each other, never to a literal.
  local pins n f base val minority majority mcount
  pins="$( for f in "$ad"/*.md; do
             [ -e "$f" ] || continue
             val="$(sed -n 's/^model:[[:space:]]*//p' "$f" | head -1)"
             [ -n "$val" ] && printf '%s\t%s\n' "$(basename "$f")" "$val"
           done )"
  n="$(printf '%s\n' "$pins" | grep -c . || true)"
  [ "${n:-0}" -ge 2 ] \
    || _fixture_die "case_agent_model_pins_match_their_declaration: only ${n:-0} pinned definition(s) — the comparison below is vacuous."

  # The majority pin, and the files that differ from it.
  majority="$(printf '%s\n' "$pins" | awk -F'\t' '{c[$2]++} END{m=0; for(v in c) if(c[v]>m){m=c[v]; b=v} print b}')"
  mcount="$(printf '%s\n' "$pins" | awk -F'\t' -v m="$majority" '$2!=m{print $1}' | grep -c . || true)"
  minority="$(printf '%s\n' "$pins" | awk -F'\t' -v m="$majority" '$2!=m{print $1}')"

  # THE DECLARATION must exist and must name the exception BY FILE.
  local ex="$REAL_REPO_ROOT/process/EXTRACTION.md"
  [ -f "$ex" ] || { skp "agent model pins match their declaration" "process/EXTRACTION.md absent"; teardown; return; }
  grep -q 'THE MODEL PINS ARE PRODUCT NAMES' "$ex" \
    || cf "the kit ships vendor product names in its agent frontmatter and declares that nowhere — EXTRACTION § 4.10 excludes exactly this class, so an undeclared pin is indistinguishable from an oversight"

  if [ "${mcount:-0}" -eq 0 ]; then
    grep -q 'ui-designer-worker.md' "$ex" \
      && cf "every definition now carries the SAME pin, but the declaration still names an exception — the table describes a tree that no longer exists"
  else
    [ "${mcount}" -eq 1 ] \
      || cf "$mcount definitions differ from the majority pin ($(printf '%s' "$minority" | tr '\n' ' ')), and the declaration describes exactly ONE deliberate exception — a new divergent pin is undeclared"
    grep -qF "$minority" "$ex" \
      || cf "the definition that differs from the rest ($minority) is NOT the one the declaration names as the exception — either the pin moved or the table did"
  fi

  # THE VALUES MUST NOT BE WRITTEN INTO THE DECLARATION, which is what keeps it from
  # going stale on the vendor's schedule.
  printf '%s\n' "$pins" | awk -F'\t' '{print $2}' | sort -u | while IFS= read -r val; do
    [ -n "$val" ] || continue
    grep -qF -- "$val" "$ex" \
      && echo "LEAK:$val"
  done | grep '^LEAK:' >/dev/null \
    && cf "the declaration WRITES a pin's value — a second copy of a vendor product name, in the document that exists to say the copy is a debt. Derive them instead."

  finish "the agent model pins match their declaration: $n pinned definition(s), exactly ${mcount:-0} deliberate exception named by file, and no pin VALUE is copied into the declaration"
  teardown
}

# =============================================================================
# CASE — THE AGENT-FACING PROSE THE KIT MOST DEPENDS ON IS READ BY SOMETHING.
#
# The role docs and `.claude/agents/` carry ruling-protected sentences that seats copy
# verbatim. PRESENCE, PER FILE: deletion is the defect, and a total hides a single file that
# lost the rider.
#
# WHAT THIS CANNOT DO (doctrine/negative-claims.md): it WILL NOT NOTICE A RIDER THAT IS
# PRESENT AND WRONG. It sees deletion and a new file that never carried the rule, not meaning.
# =============================================================================
case_agent_prose_carries_its_riders() {
  cf_reset
  make_sandbox
  local adir="$REAL_REPO_ROOT/.claude/agents" rdir="$REAL_REPO_ROOT/.claude/roles"
  local f base n=0 r

  # The riders are the seat rule's two declared tokens, the ones
  # case_provisioning_ceiling_keeps_the_seat_rule matches.
  local rider1='human-partnered' rider2='provisionable'

  if [ ! -d "$adir" ]; then
    skp "the agent-facing prose carries its riders" ".claude/agents/ is absent — this project ships no leaf-worker definitions"
    teardown; return
  fi

  for f in "$adir"/*.md; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"; n=$(( n + 1 ))
    for r in "$rider1" "$rider2"; do
      grep -qF "$r" "$f" \
        || cf "$base carries no '$r' — every other leaf-worker definition states the provisioning rider, and a definition that lost it tells its worker nothing about the ceiling it must not exceed"
    done
    # A leaf worker says it is one. The tools list is the mechanism; the sentence is what
    # the agent reads, and only the sentence travels into a hand-written definition.
    grep -qiE 'leaf worker|do not spawn' "$f" \
      || cf "$base does not say it is a leaf worker — the absent Agent/Workflow tools are the mechanism, and the sentence is the only half a hand-written sibling would copy"
  done

  # ── INSTRUMENT CHECK: a loop over an empty directory reports full coverage.
  [ "$n" -ge 5 ] \
    || cf "only $n leaf-worker definition(s) were read — expected at least 5. The glob stopped matching, so 'every one carries the rider' is true of almost nothing"

  # THE ROLE DOCS, same rider, same reason — and this is the half that had NO reader at all.
  local rn=0
  if [ -d "$rdir" ]; then
    for f in "$rdir"/*.md; do
      [ -f "$f" ] || continue
      base="$(basename "$f")"; rn=$(( rn + 1 ))
      grep -qF "$rider1" "$f" \
        || cf "role doc $base carries no '$rider1' — the seat-vs-worker distinction is what stops a role being provisioned like a leaf, and it is stated nowhere else in the file"
    done
    [ "$rn" -ge 4 ] \
      || cf "only $rn role doc(s) were read — expected at least 4"
  fi

  finish "every one of the $n leaf-worker definitions and $rn role docs carries the provisioning rider, per FILE rather than in total — a total hides the silent singular fall. NOT COVERED: a rider that is present and WRONG; this reads for deletion, not for meaning"
  teardown
}
