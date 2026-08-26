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
# gates below, or generate a starter with
#   ./scripts/kit-init.sh --gate-command "<your test command>"
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
# CHANGE. The runner refuses to start a scoped run if a listed path has vanished
# (see the existence check below), so a rename that forgets this list fails
# loudly instead of quietly shrinking the floor.
#
# The membership is READABLE HERE, without running anything — that is the point of
# a list rather than a marker scattered across the modules or a glob over names
# containing "guard".
GUARD_SET=(
  # e.g. tests/test_docs_matrix_drift.<ext>
)

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
  echo "guard floor: ${#GUARD_SET[@]} item(s) ${GUARD_SET[*]:-}"
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
run_gate() {
  local name="$1"; shift
  echo
  echo "── GATE: $name"
  echo "   \$ $*"
  local rc=0
  "$@" || rc=$?
  if [ "$rc" -eq 0 ]; then
    RESULTS+=("PASS  $name")
  else
    RESULTS+=("FAIL  $name (rc=$rc)")
    FAILED=1
  fi
}

if [ "$SCOPED" -eq 1 ]; then
  echo
  echo "── SCOPED RUN (TDD inner loop only): ${#SCOPE[@]} requested item(s) + ${#GUARD_SET[@]} always-on guard(s)."
  echo "   The FULL run stays mandatory at the dev_complete handoff, at QA and at release."
fi

for rec in "${GATES[@]}"; do
  g_name="${rec%%|*}"; rest="${rec#*|}"; g_class="${rest%%|*}"; g_cmd="${rest#*|}"
  # shellcheck disable=SC2206  # deliberate word-split of the declared command
  cmd=( $g_cmd )

  if [ "$SCOPED" -eq 1 ]; then
    if [ "$g_class" != "select" ]; then
      RESULTS+=("SKIP  $g_name (class $g_class — a scoped run cannot select within it)")
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
    continue
  fi

  run_gate "$g_name" "${cmd[@]}"
done

# ── ONE summary block. Roles read THIS, not the scrollback, so its shape is part
#    of the contract: the marker line, then one line per gate, then the exit code.
echo
echo "═══ verify.sh summary ═══"
printf '%s\n' "${RESULTS[@]}"
exit "$FAILED"
