#!/usr/bin/env bash
# KIT-CLASS: MIXED — kit FRAME (one gate runner, uniform invocation, fixed order, one summary); PROJECT GATES (the table below, shipped EMPTY). See process/EXTRACTION.md.
# KIT-DISPOSITION: FILL — the GATES table ships empty and is not done until it holds your gates.
# scripts/verify.sh — the one-shot quality-gate runner.
#
# THE SINGLE INVOCATION. Every role and every agent runs THIS, never a command re-derived from
# prose.
#
#   ./scripts/verify.sh                 # every gate, in the declared order
#   ./scripts/verify.sh --quick         # skip the gates classed `full` (fast sanity gate)
#   ./scripts/verify.sh --scope <item…> # the named items PLUS the always-on guard floor
#   ./scripts/verify.sh --list          # print the declared gates and exit 0
#
# EXIT STATUS — the two reds are told apart here as well as in the summary:
#   0  green: every gate that ran passed, and none could not run
#   1  RED, MEASURED: at least one gate FAILED (it dominates — whatever else happened)
#   2  REFUSED: the runner did not run (empty or malformed table, unknown argument, or a narrowed
#      run's own preconditions failed)
#   3  RED, UNKNOWN: nothing failed, and at least one gate COULD NOT RUN
# Anything non-zero is red, so a caller that asks only "green or not" is unaffected.
#
# --scope is for the TDD INNER LOOP ONLY. The FULL run stays mandatory at the dev_complete
# handoff, at QA, and at release. No flag, env var or argument combination runs a scoped
# selection without the guard floor.
#
# ─────────────────────────────────────────────────────────────────────────────
# UNTIL THE GATES TABLE HOLDS A RECORD, THIS RUNNER REFUSES TO RUN. It ships with the table empty:
# finish-pr.sh treats a green `verify.sh --quick` as a landing precondition, so an empty-but-green
# runner would authorise every landing. Declare your gates in the GATES table in this file, or, ON
# A FRESH REPO ONLY, let the initializer write the first record (it fills that table while it is
# empty):
#   ./scripts/kit-init.sh --prefix <P> --trunk <B> --gate-command "<your test command>"
# kit-init REFUSES a repository that has already lived; there, add the record to GATES by hand.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Resolved ABSOLUTELY, before the cd: --help renders this file, and a relative
# `${BASH_SOURCE[0]}` stops resolving the moment the working directory moves.
VERIFY_SRC="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

# GUARDED, unlike its siblings: this script has no `set -e`, so an unguarded `.` of a missing
# library carries on, and --help would then fail at `kit_usage: command not found`.
# shellcheck source=lib/usage.sh
if [ ! -f "$SCRIPT_DIR/lib/usage.sh" ] || ! . "$SCRIPT_DIR/lib/usage.sh" \
   || ! command -v kit_usage >/dev/null 2>&1; then
  # A minimal synopsis only: a copy of the renderer here would be a second authoring site.
  kit_usage() {
    echo "usage: verify.sh [--quick] [--scope <items…>] [--list] [--help]"
    echo "(scripts/lib/usage.sh could not be loaded, so the full header could not be"
    echo " rendered. Restore it:  git checkout -- scripts/lib/usage.sh)" >&2
  }
fi

# ── THE PROGRESS RECORD (process/contracts/progress-record.md) — OPTIONAL. Without the library
#    every call is a no-op; kit_progress never changes a verdict, the exit status or the summary.
# shellcheck source=lib/progress-record.sh
if [ ! -f "$SCRIPT_DIR/lib/progress-record.sh" ] || ! . "$SCRIPT_DIR/lib/progress-record.sh" \
   || ! command -v kit_progress >/dev/null 2>&1; then
  kit_progress() { :; }
fi
cd "$REPO_ROOT"

# ═════════════════════════════════════════════════════════════════════════════
# CONFIG BLOCK — everything a project declares lives between here and the END
# marker. Nothing below the marker needs editing to adopt this runner.
# ═════════════════════════════════════════════════════════════════════════════

# ── THE GATE TABLE ───────────────────────────────────────────────────────────
# One record per gate, in the order they must run: "<name>|<class>|<command…>".
#
#   <name>     what the summary block calls it. Keep it short and stable — roles
#              quote it in handoffs ("PASS <name>"), so renaming one invalidates
#              every citation.
#   <class>    the SCOPE-EXEMPTION CLASS. Exactly one of:
#                core    — runs on a full run and on --quick. It does NOT accept a
#                          selection, so a --scope run skips it (and says so).
#                select  — like `core`, and it ALSO accepts a selection: on a
#                          --scope run the frame appends the requested items plus
#                          the whole GUARD_SET to this gate's command line. It
#                          never resolves an item: declare a runner that exits
#                          non-zero when an item matches nothing.
#                full    — runs ONLY on a full run. Skipped by --quick and by
#                          --scope. This is where a slow artifact build belongs.
#   <command…> the command, word-split on spaces exactly as the shell would.
#              Quote nothing here; if you need shell syntax, put it in a script
#              and name the script.
#
# THE ORDER IS FIXED AND IS THE ORDER OF THIS ARRAY: cheapest and most likely to fail first.
#
# A GATE MUST PRINT WHAT IT RAN, so a green run still shows how much ran. Own the test runner's
# verbosity in ONE place (its config, or here — never both: stacked quiet flags hide the count).
GATES=(
  # ── EMPTY ON PURPOSE. See the refusal note in the header. ──
  #
  # A worked example, for a library with a test suite and a packaged artifact:
  #
  #   "tests|select|<interpreter> -m <test-runner>"
  #   "artifact build|full|<interpreter> -m <build-tool> --outdir dist"
  #
  # The suite is `select` because its runner takes files/ids as trailing arguments, which is what
  # makes --scope possible; the build is `full` because no scoped selection can prove the package
  # assembles.
)

# ── THE GUARD SET — the always-on floor of a --scope run. ────────────────────
# WHAT BELONGS IN IT: a CROSS-CUTTING DRIFT GUARD — a test that holds an artifact (a capability
# matrix, a generated projection, the front-door docs, a registry's completeness) against code
# ELSEWHERE in the tree, so it reddens for a change made somewhere else. A scoped run would
# otherwise miss exactly that.
# WHAT DOES NOT: a test of one surface's own behaviour; the Dev's --scope selection covers it.
# WHO UPDATES IT: whoever adds or renames a cross-cutting guard, IN THE SAME CHANGE — the
# executable-declaration case of the metadata carve-out (process/doctrine/commit-hygiene.md § A.5).
#
# The list stays READABLE here without running anything. A scoped run refuses on a listed path
# that has vanished; a guard that was never listed is visible only through GUARD_ENUM below.
# Ladder rank (process/doctrine/lookup-tables.md § A.5): GUARD_ENUM set and seeing something is
# RANK 3, both directions guarded; unset is RANK 4, and the run's NOTE names the unguarded direction.
GUARD_SET=(
  # e.g. tests/test_docs_matrix_drift.<ext>
)

# THE ENUMERATION AUTHORITY — a command listing this project's guards, reconciled against
# GUARD_SET in BOTH directions (declared but unseen; seen but unenrolled). Shipped EMPTY.
# One outcome is green: set, it saw something, and no difference either way. Every other outcome
# is a REFUSAL naming its cause or a NOTE saying nothing was measured, and the run prints which —
# do not keep a list of outcomes here.
#   • THIS VALUE IS `eval`-ED. Put a command here, and treat it as a line the runner will run.
#   • Its output is compared to GUARD_SET as LITERAL STRINGS: `find . -name …` yields `./tests/x`,
#     which does not match `tests/x`. Emit the list's shape; `git ls-files` does.
#
# e.g. GUARD_ENUM="git ls-files 'tests/test_*_drift.*'"
GUARD_ENUM=""

# ═════════════════════════════════════════════════════════════════════════════
# END CONFIG BLOCK — the frame follows. Take it as-is.
# ═════════════════════════════════════════════════════════════════════════════

QUICK=0
SCOPED=0
LIST=0
SCOPE=()
in_scope=0
# A usage request always succeeds, in any position, before any argument is interpreted
# (process/contracts/issue-creation.md § 3).
for arg in "$@"; do case "$arg" in -h|--help) kit_usage "$VERIFY_SRC"; exit 0 ;; esac; done
for arg in "$@"; do
  case "$arg" in
    --scope) SCOPED=1; in_scope=1 ;;
    --quick) QUICK=1; in_scope=0 ;;
    --list)  LIST=1;  in_scope=0 ;;
    -*) echo "verify.sh: unknown arg '$arg' (known: --quick, --scope <items…>, --list, --help)" >&2; exit 2 ;;
    *)
      # A bare word is a scope item only after --scope; a flag-looking arg is caught by -* above.
      if [ "$in_scope" -eq 1 ]; then
        SCOPE+=("$arg")
      else
        echo "verify.sh: unknown arg '$arg' (known: --quick, --scope <items…>, --list, --help)" >&2; exit 2
      fi
      ;;
  esac
done

# ── PREFLIGHT. Every refusal here happens BEFORE any gate runs, and every one of
#    them exits NON-ZERO: a runner that cannot honestly run its gates must never
#    look green.

# (0) --list is INFORMATIONAL and answers even an empty table — "what does this
#     project gate on?" is exactly the question an adopter asks before filling it
#     in, so it must not be behind the refusal below.
if [ "$LIST" -eq 1 ]; then
  echo "verify.sh — ${#GATES[@]} declared gate(s), in run order:"
  for rec in ${GATES[@]+"${GATES[@]}"}; do
    g_name="${rec%%|*}"; rest="${rec#*|}"; g_class="${rest%%|*}"; g_cmd="${rest#*|}"
    printf '  %-8s %-24s %s\n' "$g_class" "$g_name" "$g_cmd"
  done
  echo "guard floor: ${#GUARD_SET[@]} DECLARED item(s) ${GUARD_SET[*]:-}"
  [ "${#GATES[@]}" -eq 0 ] && echo "(the table is empty — this runner REFUSES to run until you declare a gate)"
  exit 0
fi

# (1) The table must not be empty. See the header: an empty-but-green runner
#     silently authorises every landing in the project.
if [ "${#GATES[@]}" -eq 0 ]; then
  {
    echo "verify.sh: REFUSING — the gate table is EMPTY."
    echo "  This file ships as a FRAME. Declare your gates in the GATES array at the top"
    echo "  (one record per gate: \"<name>|<core|select|full>|<command…>\"), or generate a"
    echo "  starter, ON A FRESH REPO: ./scripts/kit-init.sh --gate-command \"<your test command>\""
    echo "  (kit-init REFUSES a repository that has already lived — on a tree that has, the"
    echo "  GATES array above is the only way in.)"
    echo "  It refuses rather than reporting a green summary with nothing behind it,"
    echo "  because finish-pr.sh treats a green --quick here as a landing precondition."
    echo "  ./scripts/verify.sh --list prints the (currently empty) table."
  } >&2
  exit 2
fi

# (2) Every record must parse, and its class must be one of the three.
for rec in "${GATES[@]}"; do
  g_name="${rec%%|*}"; rest="${rec#*|}"; g_class="${rest%%|*}"; g_cmd="${rest#*|}"
  if [ -z "$g_name" ] || [ -z "$g_class" ] || [ -z "$g_cmd" ] || [ "$rest" = "$rec" ]; then
    echo "verify.sh: REFUSING — malformed gate record: '$rec'" >&2
    echo "  Expected \"<name>|<core|select|full>|<command…>\"." >&2
    exit 2
  fi
  case "$g_class" in
    core|select|full) ;;
    *) echo "verify.sh: REFUSING — gate '$g_name' has unknown class '$g_class' (core|select|full)." >&2; exit 2 ;;
  esac
done

if [ "$SCOPED" -eq 1 ] && [ "${#SCOPE[@]}" -eq 0 ]; then
  echo "verify.sh: --scope needs at least one item (a test path, a node id, whatever your runner takes)" >&2
  exit 2
fi

# (3) A vanished guard is a hard stop, never a silent shrink of the floor.
if [ "$SCOPED" -eq 1 ]; then
  if [ "${#GUARD_SET[@]}" -eq 0 ]; then
    {
      echo "verify.sh: NOTE — the GUARD_SET is EMPTY, so this scoped run has NO cross-cutting floor."
      echo "  A scoped run is then exactly as narrow as what you named. If this project has"
      echo "  drift guards, list them in GUARD_SET at the top of this file; if it genuinely"
      echo "  has none, this note is the honest report of that."
    } >&2
  else
    missing=()
    for g in "${GUARD_SET[@]}"; do [ -e "$g" ] || missing+=("$g"); done
    if [ "${#missing[@]}" -ne 0 ]; then
      echo "verify.sh: GUARD_SET names ${#missing[@]} path(s) that no longer exist: ${missing[*]}" >&2
      echo "verify.sh: fix the list in this script — the guard floor must stay complete." >&2
      exit 2
    fi
  fi

  # ── THE OTHER DIRECTION: a guard in the tree that nobody enrolled. ──────────
  if [ -z "${GUARD_ENUM:-}" ]; then
    # Not a pass, and it says so: the space was never read.
    echo "verify.sh: NOTE — GUARD_ENUM is unset, so the floor was checked for vanished" >&2
    echo "  entries only. A guard added to the tree and never listed in GUARD_SET is NOT" >&2
    echo "  detected by this run. Set GUARD_ENUM at the top of this file to close that." >&2
  else
    enum_err="$(mktemp 2>/dev/null || echo /tmp/verify_enum_err.$$)"
    enum_out="$(eval "$GUARD_ENUM" 2>"$enum_err")"; enum_rc=$?
    if [ "$enum_rc" -ne 0 ]; then
      # ANY non-zero is unrunnable, not only 126/127: a mistyped enumerator exits 1 with an empty
      # stdout, which must not read as "no guards". Its stderr is shown.
      echo "verify.sh: REFUSING — GUARD_ENUM did not run cleanly (exit $enum_rc): $GUARD_ENUM" >&2
      [ -s "$enum_err" ] && { echo "  it said:" >&2; sed 's/^/    /' "$enum_err" >&2; }
      echo "  This is the command failing, not an empty answer. Fix or clear GUARD_ENUM." >&2
      rm -f "$enum_err"
      exit 2
    fi
    rm -f "$enum_err"
    unenrolled=()
    while IFS= read -r found; do
      [ -n "$found" ] || continue
      in_set=0
      # ${GUARD_SET[@]+…}: under `set -u` on bash 3.2 an empty array is unbound (the shipped state).
      for g in ${GUARD_SET[@]+"${GUARD_SET[@]}"}; do [ "$g" = "$found" ] && { in_set=1; break; }; done
      [ "$in_set" -eq 0 ] && unenrolled+=("$found")
    done <<ENUM_EOF
$enum_out
ENUM_EOF
    # SET − SPACE from the same enumeration as SPACE − SET: "both ways" is one claim about one source.
    unseen=()
    for g in ${GUARD_SET[@]+"${GUARD_SET[@]}"}; do
      in_space=0
      while IFS= read -r found; do
        [ -n "$found" ] || continue
        [ "$g" = "$found" ] && { in_space=1; break; }
      done <<SPACE_EOF
$enum_out
SPACE_EOF
      [ "$in_space" -eq 0 ] && unseen+=("$g")
    done

    # One if/elif chain: the green line is reachable only when both sides had an operand.
    if [ -z "$enum_out" ] && [ "${#GUARD_SET[@]}" -eq 0 ]; then
      # Nothing on either side: not a refusal (setting GUARD_ENUM before the first guard is
      # legitimate) and not a green. rc is unchanged.
      echo "verify.sh: NOTE — GUARD_ENUM returned nothing and GUARD_SET is empty, so nothing" >&2
      echo "  was reconciled. That is not a clean floor; it is no floor and no enumeration." >&2
      echo "  If this project has guards, this command does not see them:" >&2
      echo "    $GUARD_ENUM" >&2
    elif [ -z "$enum_out" ]; then
      # A declared list the enumerator cannot see diagnoses the ENUMERATOR, not the list.
      echo "verify.sh: REFUSING — GUARD_ENUM ran cleanly and returned NOTHING, while GUARD_SET holds ${#GUARD_SET[@]} DECLARED item(s)." >&2
      echo "  The enumeration saw none of the declared guards; a floor the enumerator cannot see is" >&2
      echo "  not reconciled. Common causes: a glob that matches nothing, or guards not yet tracked" >&2
      echo "  where the enumerator reads the index (git ls-files sees only tracked paths)." >&2
      echo "  Read via GUARD_ENUM ($GUARD_ENUM) — whatever that command reads; the existence check" >&2
      echo "  reads the working tree." >&2
      exit 2
    elif [ "${#unseen[@]}" -ne 0 ]; then
      echo "verify.sh: ${#unseen[@]} DECLARED guard(s) the enumeration does not see:" >&2
      printf '  %s\n' "${unseen[@]}" >&2
      echo "  Either the entry is wrong, or GUARD_ENUM's scope excludes it — a declared guard" >&2
      echo "  outside the enumeration is not reconciled by it, whatever the other direction says." >&2
      echo "  Read via GUARD_ENUM ($GUARD_ENUM) — whatever that command reads; the existence check" >&2
      echo "  reads the working tree." >&2
      exit 2
    elif [ "${#unenrolled[@]}" -ne 0 ]; then
      echo "verify.sh: ${#unenrolled[@]} guard(s) the enumeration lists and GUARD_SET does not:" >&2
      printf '  %s\n' "${unenrolled[@]}" >&2
      echo "  The floor is short by that many, and every scoped run has been reporting a floor" >&2
      echo "  only as complete as the list. Enrol them in GUARD_SET, or narrow GUARD_ENUM if" >&2
      echo "  they are deliberately not floor guards — either way, say which in this file." >&2
      echo "  Read via GUARD_ENUM ($GUARD_ENUM) — whatever that command reads; the existence check" >&2
      echo "  reads the working tree." >&2
      exit 2
    else
      # The green line says DECLARED and names the command TEXT: it is the line most easily
      # mistaken for a measurement of the tree.
      echo "verify.sh: guard floor reconciled BOTH ways against ONE source — ${#GUARD_SET[@]} DECLARED item(s), none unseen by the enumeration, none unenrolled (via GUARD_ENUM: $GUARD_ENUM). Existence of each declared path is checked separately, above."
    fi
  fi
  # There is NO scopable gate → a --scope run would test nothing. Refuse rather
  # than print an empty green summary.
  has_select=0
  for rec in "${GATES[@]}"; do
    rest="${rec#*|}"; [ "${rest%%|*}" = "select" ] && has_select=1
  done
  if [ "$has_select" -eq 0 ]; then
    echo "verify.sh: REFUSING — --scope was given but no gate is classed 'select'," >&2
    echo "  so there is nothing that can take a selection. Run the full gate instead." >&2
    exit 2
  fi
fi

# ── THE RUN. Fixed order, one line per gate, exit codes carried through
#    UNLAUNDERED: each gate's rc is captured and reported, no `|| true` anywhere,
#    and the script's own exit status is 1 if ANY gate failed. A gate is never
#    "soft" — if you want a non-blocking check, it does not belong in this table.
RESULTS=()
FAILED=0            # 1 once any gate is red, of either kind — the progress record's status word reads it (its exit= field reads EXIT_STATUS)
# THE COUNTS ARE PART OF THE VERDICT (contracts/verify-gate.md § 2, § 4). Accumulated as the gates
# run, so the number cannot disagree with the lines it summarises.
PASSED=0
FAILEDN=0
UNRUNNABLE=0
SKIPPED=0
run_gate() {
  local name="$1"; shift
  echo
  echo "── GATE: $name"
  echo "   \$ $*"
  # The actor is this script, not a role: no hat is worn to run a gate.
  kit_progress "verify.sh" status "GATE: $name" "gate=$name" "event=start"
  local rc=0
  "$@" || rc=$?
  if [ "$rc" -eq 0 ]; then
    RESULTS+=("PASS  $name")
    PASSED=$(( PASSED + 1 ))
    kit_progress "verify.sh" status "GATE PASSED: $name" "gate=$name" "event=end" "outcome=pass" "rc=0"
  elif [ "$rc" -eq 127 ] || [ "$rc" -eq 126 ]; then
    # UNRUNNABLE IS NOT FAIL, AND BOTH ARE RED: 127/126 mean the gate never executed, so nothing
    # was measured (process/doctrine/instruments.md § A.9). The commonest cause: a RELATIVE
    # interpreter path, which resolves against this checkout's root and is absent in a linked
    # worktree.
    RESULTS+=("UNRUNNABLE  $name (rc=$rc — the command never executed; NOTHING was measured)")
    UNRUNNABLE=$(( UNRUNNABLE + 1 ))
    # `warning`, not `error`: an unknown is not a measured failure.
    kit_progress "verify.sh" warning "GATE COULD NOT RUN: $name" "gate=$name" "event=end" "outcome=unrunnable" "rc=$rc"
    {
      echo "verify.sh: gate '$name' could NOT RUN (rc=$rc). This is not a test failure —"
      echo "  nothing was measured. Check the command's interpreter/binary path:"
      echo "    \$ $*"
      echo "  Resolved from: $REPO_ROOT"
      echo "  A RELATIVE interpreter path resolves against THAT root. If you are in a"
      echo "  linked worktree, a project-local interpreter living in the main checkout"
      echo "  is not there — run the gate from the main checkout, or make the declared"
      echo "  command's interpreter path absolute or resolvable from any checkout."
    } >&2
    FAILED=1
  else
    RESULTS+=("FAIL  $name (rc=$rc)")
    FAILEDN=$(( FAILEDN + 1 ))
    kit_progress "verify.sh" error "GATE FAILED: $name" "gate=$name" "event=end" "outcome=fail" "rc=$rc"
    FAILED=1
  fi
}

if [ "$SCOPED" -eq 1 ]; then
  echo
  echo "── SCOPED RUN (TDD inner loop only): ${#SCOPE[@]} requested item(s) + ${#GUARD_SET[@]} DECLARED guard(s)."
  echo "   The floor is this file's GUARD_SET list, not every guard in the tree: a guard that"
  echo "   exists and was never listed is not run here — the reconciliation printed BEFORE"
  echo "   this banner reports it where GUARD_ENUM is declared AND SAW SOMETHING; a NOTE on"
  echo "   stderr says so where it is not declared, or saw nothing."
  echo "   The FULL run stays mandatory at the dev_complete handoff, at QA and at release."
fi

for rec in "${GATES[@]}"; do
  g_name="${rec%%|*}"; rest="${rec#*|}"; g_class="${rest%%|*}"; g_cmd="${rest#*|}"
  # shellcheck disable=SC2206  # deliberate word-split of the declared command
  cmd=( $g_cmd )

  if [ "$SCOPED" -eq 1 ]; then
    if [ "$g_class" != "select" ]; then
      RESULTS+=("SKIP  $g_name (class $g_class — a scoped run cannot select within it)")
      SKIPPED=$(( SKIPPED + 1 ))
      continue
    fi
    # The requested items PLUS the whole guard floor, deduplicated so naming a
    # guard in the scope does not collect it twice.
    sel=()
    for a in "${SCOPE[@]}" ${GUARD_SET[@]+"${GUARD_SET[@]}"}; do
      seen=0
      for b in ${sel[@]+"${sel[@]}"}; do [ "$b" = "$a" ] && seen=1 && break; done
      [ "$seen" -eq 0 ] && sel+=("$a")
    done
    run_gate "$g_name (scoped + guards)" "${cmd[@]}" "${sel[@]}"
    continue
  fi

  if [ "$QUICK" -eq 1 ] && [ "$g_class" = "full" ]; then
    RESULTS+=("SKIP  $g_name (class full — skipped by --quick)")
    SKIPPED=$(( SKIPPED + 1 ))
    continue
  fi

  run_gate "$g_name" "${cmd[@]}"
done

# ── ONE summary block. Roles quote THIS, so its shape is contractual: the marker line, one line
#    per gate, THE COUNTS (contracts/verify-gate.md § 4: "'it passed' with no count is not
#    green"), then the exit code. UNRUNNABLE is counted apart from FAILED; both are red.
echo
echo "═══ verify.sh summary ═══"
printf '%s\n' "${RESULTS[@]}"
echo "───"
# `ran` excludes the unrunnable: they produced no measurement.
echo "gates declared: ${#GATES[@]} · ran: $(( PASSED + FAILEDN )) · passed: $PASSED · failed: $FAILEDN · could not run: $UNRUNNABLE · skipped: $SKIPPED"
if [ "$SCOPED" -eq 1 ]; then
  # A narrowed run says so in the block itself, the part that gets quoted into a review.
  echo "SCOPE: NARROWED — ${#SCOPE[@]} requested item(s) + ${#GUARD_SET[@]} DECLARED guard(s). NOT the full-gate claim; whether each item matched anything is the runner's word, not this frame's, and the floor is only as complete as that declaration."
fi
[ "$UNRUNNABLE" -gt 0 ] && echo "NOTE: $UNRUNNABLE gate(s) could NOT RUN — that is an UNKNOWN, not a measured failure."

# THE EXIT STATUS SEPARATES THE TWO REDS: a measured failure dominates (1); only when nothing
# failed does an unrunnable gate decide it (3). 2 is the refusal.
if   [ "$FAILEDN" -gt 0 ];    then EXIT_STATUS=1
elif [ "$UNRUNNABLE" -gt 0 ]; then EXIT_STATUS=3
else                               EXIT_STATUS=0
fi

# THE RUN SUMMARY AS ONE RECORD, after the summary block and changing none of it; the counts are
# the same accumulators the block printed.
kit_progress "verify.sh" "$([ "$FAILED" -eq 0 ] && echo status || echo error)" \
  "run finished — $(( PASSED + FAILEDN )) of ${#GATES[@]} gate(s) ran, $PASSED passed, $FAILEDN failed, $UNRUNNABLE could not run, $SKIPPED skipped" \
  "event=summary" "declared=${#GATES[@]}" "passed=$PASSED" "failed=$FAILEDN" \
  "unrunnable=$UNRUNNABLE" "skipped=$SKIPPED" "scoped=$SCOPED" "exit=$EXIT_STATUS"

exit "$EXIT_STATUS"
