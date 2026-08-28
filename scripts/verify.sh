#!/usr/bin/env bash
# KIT-CLASS: MIXED — kit FRAME (one gate runner, uniform invocation, fixed order, one summary); PROJECT GATES (the table below, shipped EMPTY). See process/EXTRACTION.md.
# scripts/verify.sh — the one-shot quality-gate runner.
#
# THE SINGLE INVOCATION. Every role and every agent runs THIS, never a command
# re-derived from prose. That is the whole point: "no role re-derives commands
# from docs" is only true if there is exactly one command to run.
#
#   ./scripts/verify.sh                 # every gate, in the declared order
#   ./scripts/verify.sh --quick         # skip the gates classed `full` (fast sanity gate)
#   ./scripts/verify.sh --scope <item…> # the named items PLUS the always-on guard floor
#   ./scripts/verify.sh --list          # print the declared gates and exit 0
#
# --scope is for the TDD INNER LOOP ONLY. The FULL run stays mandatory at the
# dev_complete handoff, at QA, and at release — coverage is never cut and the guard
# floor is never skipped. There is NO flag, env var or argument combination that
# runs a scoped selection without the floor: a scoped run that could skip the
# cross-cutting guards would let a change sail past the very tests designed to
# catch it from a distance.
#
# ─────────────────────────────────────────────────────────────────────────────
# THIS FILE SHIPS WITH AN EMPTY GATE TABLE, AND IT REFUSES TO RUN UNTIL YOU FILL
# IT IN. That refusal is deliberate. A runner that reports a green summary with
# zero gates is worse than no runner: finish-pr.sh treats a green
# `verify.sh --quick` as a landing precondition, so an empty-but-passing gate
# runner would silently authorise every landing in the project. Declare your
# gates below, or let the initializer write the first record for you:
#   ./scripts/kit-init.sh --prefix <P> --trunk <B> --gate-command "<your test command>"
# (it fills THIS table while it is empty; it never touches a declared one).
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Resolved ABSOLUTELY, before the cd: --help renders this file, and a relative
# `${BASH_SOURCE[0]}` stops resolving the moment the working directory moves.
VERIFY_SRC="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
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
#                          the whole GUARD_SET to this gate's command line.
#                full    — runs ONLY on a full run. Skipped by --quick and by
#                          --scope. This is where a slow artifact build belongs.
#   <command…> the command, word-split on spaces exactly as the shell would.
#              Quote nothing here; if you need shell syntax, put it in a script
#              and name the script.
#
# THE ORDER IS FIXED AND IS THE ORDER OF THIS ARRAY. Cheapest-and-most-likely-to-
# fail first: a role that has to wait ten minutes to learn a typo broke the build
# stops running the gate at all.
#
# A GATE MUST PRINT WHAT IT RAN. Hard-won: this runner once passed a redundant
# quiet flag to a test runner that already had one in its own config; the two
# stacked, the summary count line vanished, and the canonical gate reported the
# suite it had just run WITHOUT EVER PRINTING A NUMBER — so every count quoted in
# every review came from a separate, unrecorded invocation. Own the verbosity in
# ONE place (your test runner's config, or here — never both) and make sure a
# green run still shows how much it ran.
GATES=(
  # ── EMPTY ON PURPOSE. See the refusal note in the header. ──
  #
  # A WORKED EXAMPLE, from an anonymized donor project (a library with a test
  # suite and a packaged artifact). Two gates, in this order:
  #
  #   "tests|select|<interpreter> -m <test-runner>"
  #   "artifact build|full|<interpreter> -m <build-tool> --outdir dist"
  #
  # Why that split: the suite is `select` because the test runner accepts a list
  # of files/ids as trailing arguments, which is what makes --scope possible at
  # all; the artifact build is `full` because it proves the *package* still
  # assembles — a question no scoped selection can answer, and one nobody needs
  # answered ten times an hour during a TDD loop.
)

# ── THE GUARD SET — the always-on floor of a --scope run. ────────────────────
# WHAT BELONGS IN IT (the inclusion rule, one sentence): a test whose subject is a
# CROSS-CUTTING DRIFT GUARD — it holds a hand-maintained or generated artifact (a
# capability matrix, a generated projection, the front-door docs, a registry's
# completeness) against real code ELSEWHERE in the tree, so it reddens for a
# change made somewhere else. That is exactly the class of failure a scoped run
# would otherwise miss, which is why membership here is not optional and no flag
# disables it.
#
# WHAT DOES NOT: a test of one surface's own behavior, however important — those
# redden for a change made in the file under test, so the Dev's own --scope
# selection already covers them.
#
# WHO UPDATES IT: whoever adds or renames a cross-cutting guard, IN THE SAME
# CHANGE — the guard and its enrolment here are one coupled set. Your code globs
# classify this file as metadata while the file it guards is code, so this is the
# EXECUTABLE-DECLARATION case of the adapter's metadata carve-out, not the
# documentation-of-code case its worked examples show.
# (process/doctrine/commit-hygiene.md § A.5.)
#
# WHAT THE CHECK BELOW ENFORCES, AND WHAT IT CANNOT — both, because only one of
# them is obvious. It refuses a scoped run when a LISTED path has vanished, so a
# rename or a deletion that forgets this list fails loudly. It CANNOT see the
# other direction on its own: a guard that lands and is never enrolled is invisible
# to a list, because this list is the only thing that check reads, and a list is its
# own horizon.
#
# SUPERSEDED, CONCLUSION ONLY: "and nothing in this file reports it" was true when
# written and is now false. GUARD_ENUM below supplies the SPACE the list is reconciled
# against, and the scoped run refuses on a difference in EITHER direction, ONE AT A
# TIME: both differences are computed, the first non-empty one refuses, and the other
# is not named until that one is fixed. The reason above is untouched and still holds
# — a list cannot see past itself, which is WHY a second, independent enumeration had
# to be added rather than the list made cleverer.
#
# The membership is READABLE HERE, without running anything — that is the point of
# a list rather than a marker scattered across the modules or a glob over names
# containing "guard". That readability is why the enumerator is a SECOND knob and not a
# replacement: the list stays checkable by eye, and the enumerator supplies what it is
# checked against — two authorities, deliberately, because one cannot audit itself.
#
# WHERE THIS SITS ON THE HAND-KEPT-TABLE LADDER depends on whether GUARD_ENUM is set,
# and both answers are legitimate (process/doctrine/lookup-tables.md § A.5):
#   • GUARD_ENUM DECLARED  → RANK 3: hand-kept, held complete in BOTH directions by a
#     guard. The list is the declaration, the enumeration is the space, and the run
#     refuses on a difference either way. RANK 3 IS EARNED BY THE RUN, NOT BY THE KNOB:
#     an enumerator that returns nothing reconciles nothing, however correctly it is
#     declared, and the run says so instead of reporting a clean floor.
#   • GUARD_ENUM UNSET     → RANK 4: hand-kept, one direction guarded — tolerated only
#     with a named reason in-file, and § A.5 requires that reason to name the UNGUARDED
#     direction. The run's own NOTE is that reason, printed rather than filed: it says
#     the unenrolled direction was not checked, so the blind direction is stated at the
#     moment it applies rather than discovered later.
GUARD_SET=(
  # e.g. tests/test_docs_matrix_drift.<ext>
)

# THE ENUMERATION AUTHORITY — how this project lists its guards AS THE ENUMERATOR SEES
# THEM. Shipped EMPTY, like GUARD_SET above; with both seams empty a run takes the
# unset arm and says the second direction was never checked.
#
# WHAT A RUN DOES WITH IT turns on two things: whether the seam is SET, and what the
# enumeration then did — saw something, saw nothing, or failed to run. **Every outcome
# names itself in the run's own output, so THE RUN IS THE LIST**; do not keep a count
# of them here, and do not trust one kept anywhere else.
#   • A GREEN is earned by exactly one combination: set, the enumeration saw
#     something, and there is no difference in either direction.
#   • Everything else is either a REFUSAL that names its cause and the guards it
#     found, or a NOTE that says nothing was measured — and a NOTE is never a pass.
# *Written this way deliberately: four repairs to this block each replaced one closed
# set of outcomes with another, and each new list was outrun by the next arm added.*
#
# WHY BOTH DIRECTIONS, AND WHY A LIST ALONE CANNOT DO IT. The existence check below
# walks GUARD_SET and refuses on a path that has vanished — declared-but-absent. The
# other direction is the one that bites: a guard that LANDS IN THE TREE and is never
# added to the list changes neither the count nor the note, so nothing is red, nothing
# is loud, and every scoped run afterwards reports a floor exactly as complete as
# somebody's memory. The difference between the declared set and the real space is the
# only place that defect lives, and it lives in both directions.
#
# THE DECLARED LIST STAYS READABLE — that is deliberate and is why this is a second
# knob rather than a replacement. GUARD_SET remains a commented list a reader can
# check without running anything; this command supplies the SPACE to reconcile it
# against. The kit owns where the frame looks; the project owns what is in the list.
#
# TWO ASYMMETRIES WITH THE SEAMS ABOVE IT — with GATES on execution, with GUARD_SET on
# comparison — both worth knowing before setting it:
#   • THIS VALUE IS EXECUTED. The GATES table says to quote nothing and is PARSED,
#     never evaluated; this is `eval`-ed, so it is the file's first EVAL-ED surface —
#     the gate commands run too, but they are executed as parsed words, never as text
#     the shell re-reads. Put a command here, not a value, and treat it as you would
#     any other line the runner will run.
#   • ITS OUTPUT IS COMPARED AS LITERAL STRINGS to the entries in GUARD_SET, with no
#     path normalisation. `find . -name …` yields `./tests/x` and will NOT match a
#     GUARD_SET entry written `tests/x`. With a populated list every DECLARED guard then
#     reads as UNSEEN by the enumeration; with an empty one every path found reads as
#     UNENROLLED. Same mismatch, opposite arm, depending on which side has entries.
#     Emit the same shape the list uses; `git ls-files` already does.
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
for arg in "$@"; do
  case "$arg" in
    --scope) SCOPED=1; in_scope=1 ;;
    --quick) QUICK=1; in_scope=0 ;;
    --list)  LIST=1;  in_scope=0 ;;
    -h|--help)
      first="$(awk 'NR>2 && !/^#/{print NR; exit}' "$VERIFY_SRC")"
      sed -n "3,$(( ${first:-0} - 1 ))p" "$VERIFY_SRC" | sed 's|^# \{0,1\}||'
      exit 0 ;;
    -*) echo "verify.sh: unknown arg '$arg' (known: --quick, --scope <items…>, --list, --help)" >&2; exit 2 ;;
    *)
      # A bare word is a scope item only after --scope; anything else is still a
      # loud failure. A flag-looking arg AFTER --scope is caught by the -* branch
      # above, so a typo'd flag can never be swallowed as a test path.
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
    echo "  starter: ./scripts/kit-init.sh --gate-command \"<your test command>\"."
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
  # Placed here, beside the existence check, because the two are one reconciliation
  # and separating them is how only one of them ends up maintained.
  if [ -z "${GUARD_ENUM:-}" ]; then
    # NOT A PASS, AND IT SAYS SO. An unset authority means the space was never read,
    # which is a different sentence from "the declared list is complete" — and only
    # one of them is a claim this run is entitled to make.
    echo "verify.sh: NOTE — GUARD_ENUM is unset, so the floor was checked for vanished" >&2
    echo "  entries only. A guard added to the tree and never listed in GUARD_SET is NOT" >&2
    echo "  detected by this run. Set GUARD_ENUM at the top of this file to close that." >&2
  else
    enum_err="$(mktemp 2>/dev/null || echo /tmp/verify_enum_err.$$)"
    enum_out="$(eval "$GUARD_ENUM" 2>"$enum_err")"; enum_rc=$?
    if [ "$enum_rc" -ne 0 ]; then
      # ANY NON-ZERO IS UNRUNNABLE — not only 126/127. A MIS-TYPED enumerator
      # (`git ls-fils …`) exits 1 with an empty stdout, and an empty stdout is
      # indistinguishable from "this project has no guards" — so a rc-127-only test
      # let a typo print "reconciled BOTH ways … none unenrolled" and exit 0. That is
      # an affirmative claim the run did not earn, and it is WORSE than the silence
      # this whole change replaced: silence claimed nothing.
      # The enumerator's own stderr is KEPT and shown, because "it failed" without
      # what it said costs the reader the one thing that identifies the typo.
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
      # ${GUARD_SET[@]+…} — the file's own idiom, and NOT optional here: under
      # `set -u` on bash 3.2 an empty array expands to an unbound variable and the
      # runner DIES naming nothing. That is the SHIPPED state (GUARD_SET empty) with
      # an enumerator declared, which is the first thing the config comment above
      # invites — and what actually ships is BOTH seams empty, so this configuration
      # is one edit away from the shipped one and had no test at all.
      for g in ${GUARD_SET[@]+"${GUARD_SET[@]}"}; do [ "$g" = "$found" ] && { in_set=1; break; }; done
      [ "$in_set" -eq 0 ] && unenrolled+=("$found")
    done <<ENUM_EOF
$enum_out
ENUM_EOF
    # SET − SPACE, FROM THE SAME SOURCE AS SPACE − SET. Until now "both ways" was
    # stitched from two authorities: "none unenrolled" came from the enumeration and
    # "none vanished" from the -e existence test — so an enumerator that exited 0
    # having seen NOTHING made SPACE empty, SPACE−SET vacuously empty, and the run
    # printed a green claiming both directions while one of them had no operand. Same
    # unearned green a mis-typed command produced, through the other door. Computing
    # both directions from the enumeration makes "both ways" ONE claim about ONE
    # source rather than two claims stitched together.
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

    # THE OUTCOMES AS ONE CHAIN, so the green line is UNREACHABLE unless both sides had an
    # operand. Written as if/elif deliberately: every predicate in this block was once
    # scoped to a populated GUARD_SET, and the shipped state is the empty one.
    if [ -z "$enum_out" ] && [ "${#GUARD_SET[@]}" -eq 0 ]; then
      # NOTHING ON EITHER SIDE, so there is nothing to reconcile and no claim to print.
      # NOT a refusal: setting GUARD_ENUM before writing a first guard is a legitimate
      # state and blocking it would punish doing the right thing early. NOT a green:
      # a claim with no operand on either side is not a measurement. rc is unchanged.
      echo "verify.sh: NOTE — GUARD_ENUM returned nothing and GUARD_SET is empty, so nothing" >&2
      echo "  was reconciled. That is not a clean floor; it is no floor and no enumeration." >&2
      echo "  If this project has guards, this command does not see them:" >&2
      echo "    $GUARD_ENUM" >&2
    elif [ -z "$enum_out" ]; then
      # A DECLARED LIST THE ENUMERATOR CANNOT SEE — diagnoses the ENUMERATOR, not the list.
      # Naming every declared guard would be true and would bury the cause: the command
      # ran, succeeded, and saw none of them.
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
      # DECLARED, uppercase, matching the other count-lines in this runner: the green line
      # is the one most mistakable for a measurement of the tree. And it names the command
      # TEXT, not just the knob — the refusal path already did, and the green path is
      # where nobody re-checks which command actually ran.
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
FAILED=0
# THE COUNTS ARE PART OF THE VERDICT, not decoration — `contracts/verify-gate.md`
# § 2 ("the count of checks executed is part of the output, not an inference from
# the absence of complaints") and § 4 ("'it passed' with no count is not green; it
# is an assertion"). Counted here rather than derived from RESULTS at the end, so
# the number cannot disagree with the lines it summarises.
PASSED=0
FAILEDN=0
UNRUNNABLE=0
SKIPPED=0
run_gate() {
  local name="$1"; shift
  echo
  echo "── GATE: $name"
  echo "   \$ $*"
  local rc=0
  "$@" || rc=$?
  if [ "$rc" -eq 0 ]; then
    RESULTS+=("PASS  $name")
    PASSED=$(( PASSED + 1 ))
  elif [ "$rc" -eq 127 ] || [ "$rc" -eq 126 ]; then
    # UNRUNNABLE IS NOT FAIL, AND BOTH ARE RED. 127 is "command not found", 126
    # is "found but not executable" — in both the gate NEVER EXECUTED, so nothing
    # was measured. Spelling that `FAIL` is the runner reporting on ITSELF in the
    # vocabulary it uses for its SUBJECT, and the reader cannot then tell "your
    # tree is broken" from "this gate could not start" — so they debug the tree,
    # which may be perfectly fine. (process/doctrine/instruments.md § A.9.)
    #
    # THE COMMONEST CAUSE, named because the message is where it will be read: a
    # declared gate command carrying a RELATIVE interpreter path (a project-local
    # virtualenv, a vendored binary) resolves against THIS checkout's root — and
    # a linked worktree does not have one. That is exactly where a trunk gate has
    # to run, so the one command everybody must run fails there and says "FAIL".
    RESULTS+=("UNRUNNABLE  $name (rc=$rc — the command never executed; NOTHING was measured)")
    UNRUNNABLE=$(( UNRUNNABLE + 1 ))
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

# ── ONE summary block. Roles read THIS, not the scrollback, so its shape is part
#    of the contract: the marker line, then one line per gate, THEN THE COUNTS,
#    then the exit code.
#
#    THE COUNT LINE IS NOT OPTIONAL. `contracts/verify-gate.md` § 4: "'it passed'
#    with no count is not green; it is an assertion." A reader quoting this block
#    into a review must be able to say how much ran without re-running it, and a
#    per-gate list alone cannot be checked against anything — it is exactly as
#    long as whatever the frame happened to append. The counts are accumulated as
#    the gates run, not derived from the lines above, so the summary cannot
#    disagree with its own evidence.
#
#    UNRUNNABLE IS COUNTED SEPARATELY FROM FAILED, and both are red. Collapsing
#    them is the defect this line exists to prevent: "1 failed" sends a reader to
#    the tree, "1 could not run" sends them to the command.
echo
echo "═══ verify.sh summary ═══"
printf '%s\n' "${RESULTS[@]}"
echo "───"
# `ran` EXCLUDES the unrunnable, deliberately: a gate whose command never executed
# produced no measurement, so counting it as "ran" would re-merge the two states
# this block exists to separate — the count line contradicting its own lines.
echo "gates declared: ${#GATES[@]} · ran: $(( PASSED + FAILEDN )) · passed: $PASSED · failed: $FAILEDN · could not run: $UNRUNNABLE · skipped: $SKIPPED"
if [ "$SCOPED" -eq 1 ]; then
  # A NARROWED RUN IS A WEAKER CLAIM AND SAYS SO IN THE BLOCK ITSELF (§ 2, § 4),
  # not only in the banner printed before the gates — the summary is the part
  # that gets quoted into a review, so it is the part that must carry the caveat.
  echo "SCOPE: NARROWED — ${#SCOPE[@]} requested item(s) + ${#GUARD_SET[@]} DECLARED guard(s). NOT the full-gate claim, and the floor is only as complete as that declaration."
fi
[ "$UNRUNNABLE" -gt 0 ] && echo "NOTE: $UNRUNNABLE gate(s) could NOT RUN — that is an UNKNOWN, not a measured failure."
exit "$FAILED"
