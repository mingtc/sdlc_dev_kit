#!/usr/bin/env bash
# KIT-CLASS: KIT — sets a model and effort everywhere the ladder is read. See process/EXTRACTION.md.
# Contract: process/contracts/model-provisioning-seam.md.
#
# A model is set in several places (process/doctrine/model-provisioning.md § B.1): the leaf-worker
# pins (.claude/agents/*.md frontmatter), the ladder row (.claude/roles/orchestrator.md § Model &
# effort contract) and, for an UNTYPED leg, the workflow runners' defaultModel/defaultEffort. This
# writes a class's (model, effort) pair to every one of those at once, so the ladder and what is
# actually pinned never disagree.
#
# Usage:
#   ./scripts/set-models.sh --class <class> --model <id> --effort <tier>
#   ./scripts/set-models.sh --all           --model <id> --effort <tier>
#   ./scripts/set-models.sh --runners       --model <id> --effort <tier>
#   ./scripts/set-models.sh --list
#
# --class <class>  one work class, exactly as the ladder row names it (see --list). Rewrites that
#                  class's leaf-worker pin file(s) (where one exists for the class) and its ladder
#                  row. Refuses a class the ladder does not carry a row for.
# --all            every class the ladder declares, to the SAME (model, effort) pair, and the
#                  runner defaults with it — the whole-fleet re-provisioning that leaves the ladder,
#                  the pins and the runners agreeing. A role the ladder carries no row for (a parked
#                  role, e.g. ui-designer-worker.md) is off this script's ladder entirely and is
#                  never touched by --all or --class; re-provision it by editing its pin by hand.
# --runners        only defaultModel/defaultEffort in both workflow runners — the fallback for a
#                  leg with no leaf-worker type, which the ladder has no row of its own for.
# --list           print the classes the ladder declares, and exit. Read-only.
# -h, --help       this text.
#
# Each pin file it writes is also recorded in .claude/model-pins.record; check-board.sh [s] compares
# the pins with the ladder, and with that record where a ladder cell is unfilled, so a pin edited
# by hand shows up as a disagreement.
#
# Model ids are written EXACTLY as given — this script never hard-codes one (EXTRACTION.md, "THE
# MODEL PINS ARE PRODUCT NAMES"). It writes only what you pass.
#
# Every refusal leaves a progress record (refusal=<rule-id>) where the project has one to write to.
# Exit 2: an unknown option or a missing option value. Exit 1: any other refusal, including a
# surplus positional argument — it looks like a usage error but is not one.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
# shellcheck source=lib/usage.sh
. "$SCRIPT_DIR/lib/usage.sh"
# shellcheck source=lib/refuse.sh
. "$SCRIPT_DIR/lib/refuse.sh"
# shellcheck source=lib/model-pins.sh
. "$SCRIPT_DIR/lib/model-pins.sh"

usage() { kit_usage "${BASH_SOURCE[0]}"; }   # the path is an ARGUMENT — see lib/usage.sh
# A usage request always succeeds, in any position, before any argument is interpreted
# (issue-creation.md § 3).
for _a in "$@"; do case "$_a" in -h|--help) usage; exit 0 ;; esac; done
# need_val — refuse an option whose value is missing: exit 2, naming it (issue-creation.md § 3).
# BYTE-IDENTICAL to every other script's copy — do not diverge (process/EXTRACTION.md).
need_val() {
  [ "$#" -ge 2 ] || { echo "Error: $1 requires a value." >&2; exit 2; }
}

# ── PARSE ARGUMENTS FIRST, BEFORE ANY ENVIRONMENT CHECK (issue-creation.md § 3): an unrecognised
# option or a missing value is a USAGE error and must exit 2 naming it, regardless of whether this
# tree even has a .claude/ to look in. Reading the environment before parsing would make a bad flag
# on an unadopted tree read as "no .claude/", which names the wrong problem at the wrong status.
LIST=false; CLASS=""; MODEL=""; EFFORT=""; DO_ALL=false; DO_RUNNERS=false
while [ $# -gt 0 ]; do
  case "$1" in
    --list)    LIST=true; shift ;;
    --class)   need_val "$@"; CLASS="$2"; shift 2 ;;
    --model)   need_val "$@"; MODEL="$2"; shift 2 ;;
    --effort)  need_val "$@"; EFFORT="$2"; shift 2 ;;
    --all)     DO_ALL=true; shift ;;
    --runners) DO_RUNNERS=true; shift ;;
    -*) kit_refuse 2 unknown-option "Error: unknown option: $1" "Next: run $(basename "$0") --help, then re-run with one of the options it lists." ;;
    *)  kit_refuse 1 unexpected-argument "Error: unexpected argument: $1" "Next: re-run naming a target with --class <class>, --all or --runners." ;;
  esac
done

if [ "$LIST" = false ]; then
  _n_targets=0
  $DO_ALL     && _n_targets=$((_n_targets + 1))
  $DO_RUNNERS && _n_targets=$((_n_targets + 1))
  [ -n "$CLASS" ] && _n_targets=$((_n_targets + 1))
  [ "$_n_targets" -eq 1 ] || kit_refuse 2 exactly-one-target \
    "Error: name exactly one of --class <class>, --all or --runners (or --list)." \
    "Next: re-run naming exactly one target; $(basename "$0") --list shows the classes the ladder declares."

  [ -n "$MODEL" ]  || kit_refuse 2 no-model  "Error: --model <id> is required." "Next: re-run with --model <id>, the product name exactly as you were given it — never guessed here. If you were not given one, the choice is the owner's: stop and hand off."
  [ -n "$EFFORT" ] || kit_refuse 2 no-effort "Error: --effort <tier> is required." "Next: re-run with --effort <tier>, spelled as the ladder in the Orchestrator's § Model & effort contract spells its tiers. If you were not given one, the choice is the owner's: stop and hand off."
fi

# ── NOW THE ENVIRONMENT: every argument is well-formed, so a refusal past this point is about
#    THIS TREE, never about the command line. LOCATE THE PROJECT'S HARNESS DIRECTORY. Shipped
#    disarmed (_claude/) inside the kit's own maintaining repository; live (.claude/) on every
#    adopted tree. Both are checked, as scripts/test/cases/runners.sh's own case does, so this
#    script runs against either.
CLAUDE_DIR=""
for _d in "$ROOT/.claude" "$ROOT/_claude"; do
  [ -d "$_d" ] && CLAUDE_DIR="$_d"
done
[ -n "$CLAUDE_DIR" ] || kit_refuse 1 no-claude-dir \
  "Error: neither .claude/ nor _claude/ exists under $ROOT." \
  "Next: run this from the root of a kit-initialized project (./scripts/kit-init.sh makes one) or the kit's own tree."

AGENTS_DIR="$CLAUDE_DIR/agents"
ORCH_DOC="$CLAUDE_DIR/roles/orchestrator.md"
RUNNERS="$CLAUDE_DIR/workflows/wave-runner.js $CLAUDE_DIR/workflows/tranche-runner.js"

[ -f "$ORCH_DOC" ] || kit_refuse 1 no-orchestrator-doc \
  "Error: $ORCH_DOC does not exist." \
  "Next: restore $ORCH_DOC from version control or the release zip, then re-run. The ladder row lives in the Orchestrator's § Model & effort contract; without that file there is nothing to read the ladder from."

# ── THE CLASS TABLE lives in lib/model-pins.sh, which the drift report reads too: one row per
#    work class — its ladder-row label (as orchestrator.md's table spells it) and its leaf-worker
#    pin file, where one exists. Orchestrator/coordination and XS/mechanical have no leaf-worker
#    file of their own, so their pin is empty: the ladder row is still written, the pin step is a
#    no-op named as such. The label is matched as a literal row-opening substring ("| **<label>"),
#    never reconstructed from the class key, because orchestrator.md's own wording differs from
#    model-provisioning.md § B.2's (e.g. "Dev" vs "Implementer (Dev)").
ALL_CLASSES="$KIT_MODEL_CLASSES"

# kit_ladder_has <class> — does orchestrator.md's table carry a row for this class RIGHT NOW? The
# refusal reads the LIVE table, never the class list above alone: a project that trimmed its own
# ladder to fewer classes has thereby un-named the rest (model-provisioning.md § A.2 — the ladder is
# the project's own calibration).
#
# THE LABEL IS MATCHED AS A PREFIX inside the bold span, not the whole span: some rows carry
# trailing qualifiers inside the same "**...**" ("XS / mechanical (any role)", "Spike / probe
# (`spike-worker`)"), so anchoring on the bold CLOSE as well would miss them.
kit_ladder_has() {
  local label; label="$(kit_model_class_label "$1")" || return 1
  grep -qE "^\| \*\*${label}" "$ORCH_DOC"
}

if [ "$LIST" = true ]; then
  for _c in $ALL_CLASSES; do
    label="$(kit_model_class_label "$_c")"
    if kit_ladder_has "$_c"; then present="(in the ladder)"; else present="(not in this project's ladder)"; fi
    printf '%-14s %-20s %s\n' "$_c" "$label" "$present"
  done
  exit 0
fi

# kit_set_pin <file> — rewrite an existing model:/effort: frontmatter pair. Refuses a pin file that
# does not already carry both keys, rather than inventing frontmatter shape. THE KIT'S FLOOR IS
# GIT + A POSIX SHELL (no perl, no python, no node, no ruby — scripts/test/cases/shipped-tree.sh's
# interpreter-floor case): awk, never perl, does the rewrite, one whole line at a time so a
# metacharacter in a model id needs no escaping — it is printed, never matched.
kit_set_pin() {
  local f="$AGENTS_DIR/$1"
  [ -f "$f" ] || kit_refuse 1 pin-file-missing "Error: $f does not exist." "Next: restore $f (the class's leaf-worker definition under .claude/agents/) from version control or the release zip, then re-run."
  grep -qE '^model:' "$f" && grep -qE '^effort:' "$f" \
    || kit_refuse 1 pin-shape-unrecognised "Error: $f has no 'model:'/'effort:' frontmatter pair to rewrite." "Next: restore the 'model:' and 'effort:' frontmatter lines in $f from version control or the release zip, then re-run."
  awk -v m="$MODEL" -v e="$EFFORT" '
    /^model:/  { print "model: " m;  next }
    /^effort:/ { print "effort: " e; next }
    { print }
  ' "$f" > "$f.new" && mv "$f.new" "$f"
  # Record what was written, so check-board.sh [s] can tell a later hand edit from this seam.
  kit_model_record_set "$CLAUDE_DIR" "$1" "$MODEL" "$EFFORT"
}

# kit_set_ladder_row <label> — rewrite orchestrator.md's row for <label>: the first backticked token
# of the Model cell and of the Effort cell, whether it is still a `<fill in...>` blank or already
# filled, never the row's trailing prose (the Dev and QA rows carry riders after their cells that
# must survive). The label cell is skipped: it may carry backticks of its own.
#
# LABEL, MODEL, EFFORT are matched and substituted as LITERAL STRINGS (awk's index()/substr()),
# never as a regex: a label containing a metacharacter ("XS / mechanical") or a model id
# containing one would otherwise need escaping, needlessly, for a floor tool with no \Q...\E.
# After the label cell, the FIRST backticked token is Model and the SECOND is Effort.
kit_set_ladder_row() {
  local label="$1"
  grep -qE "^\| \*\*${label}" "$ORCH_DOC" \
    || kit_refuse 1 ladder-row-missing "Error: orchestrator.md has no ladder row for '${label}'." "Next: restore that row in $ORCH_DOC's § Model & effort contract table from version control or the release zip, then re-run."
  awk -v want="| **${label}" -v m="$MODEL" -v e="$EFFORT" '
    # Replace the k-th backtick-delimited token of s, backticks included, with `val`.
    function nth(s, val, k,    p1, p2, pre) {
      pre = ""
      for (;; k--) {
        p1 = index(s, "`")
        if (p1 == 0) return pre s
        p2 = index(substr(s, p1 + 1), "`")
        if (p2 == 0) return pre s
        if (k == 1) return pre substr(s, 1, p1 - 1) "`" val "`" substr(s, p1 + p2 + 1)
        pre = pre substr(s, 1, p1 + p2)
        s = substr(s, p1 + p2 + 1)
      }
    }
    {
      if (index($0, want) == 1) {
        c = index(substr($0, 2), "|")          # the pipe that closes the label cell
        head = substr($0, 1, c + 1); rest = substr($0, c + 2)
        rest = nth(rest, m, 1)
        rest = nth(rest, e, 2)
        $0 = head rest
      }
      print
    }
  ' "$ORCH_DOC" > "$ORCH_DOC.new" && mv "$ORCH_DOC.new" "$ORCH_DOC"
}

# kit_set_runners — defaultModel/defaultEffort in both workflow runners. `'…'` is the shape both
# runners already use (ARGS.defaultModel || 'opus'); rewritten as single-quoted JS string literals,
# by LITERAL substring replacement (awk: the kit's floor is git + a POSIX shell, no perl), never a
# regex — a model id or the line's own quoting needs no escaping this way.
# Each matched line ends "... || '<value>',": the value is everything between the LAST TWO single
# quotes on the line, found from the right so the rule preceding it (ARGS.defaultModel/Effort)
# never has to be re-matched inside the replacement.
kit_set_runners() {
  local rf
  for rf in $RUNNERS; do
    [ -f "$rf" ] || kit_refuse 1 runner-file-missing "Error: $rf does not exist." "Next: restore $rf from version control or the release zip, then re-run."
    grep -qE "defaultModel:.*\|\|" "$rf" && grep -qE "defaultEffort:.*\|\|" "$rf" \
      || kit_refuse 1 runner-shape-unrecognised "Error: $rf has no defaultModel/defaultEffort fallback of the recognised shape." "Next: restore its 'defaultModel:' and 'defaultEffort:' fallback lines from version control or the release zip, then re-run."
    awk -v m="$MODEL" -v e="$EFFORT" -v q="'" '
      function last_quoted_replace(line, val,    n, i, q1, q2) {
        n = length(line)
        q2 = 0
        for (i = n; i >= 1; i--) { if (substr(line, i, 1) == q) { q2 = i; break } }
        if (q2 == 0) return line
        q1 = 0
        for (i = q2 - 1; i >= 1; i--) { if (substr(line, i, 1) == q) { q1 = i; break } }
        if (q1 == 0) return line
        return substr(line, 1, q1) val substr(line, q2)
      }
      {
        if (index($0, "defaultModel:") > 0 && index($0, "ARGS.defaultModel") > 0) $0 = last_quoted_replace($0, m)
        else if (index($0, "defaultEffort:") > 0 && index($0, "ARGS.defaultEffort") > 0) $0 = last_quoted_replace($0, e)
        print
      }
    ' "$rf" > "$rf.new" && mv "$rf.new" "$rf"
  done
}

if [ -n "$CLASS" ]; then
  kit_ladder_has "$CLASS" || {
    avail=""
    for _c in $ALL_CLASSES; do kit_ladder_has "$_c" && avail="$avail $_c"; done
    kit_refuse 1 class-not-in-ladder \
      "Error: '${CLASS}' is not a class this project's ladder declares a row for." \
      "  Classes the ladder currently carries:${avail:-  (none — the ladder is unfilled)}" \
      "Next: re-run with one of the classes listed above ($(basename "$0") --list shows the full mapping). A class the ladder has no row for is the owner's to add: stop and hand off."
  }
  label="$(kit_model_class_label "$CLASS")"
  pin="$(kit_model_class_pin "$CLASS")"
  kit_set_ladder_row "$label"
  if [ -n "$pin" ]; then
    kit_set_pin "$pin"
  else
    echo "set-models: '${CLASS}' has no leaf-worker pin file — ladder row updated only." >&2
  fi
  echo "set-models: ${CLASS} -> model=${MODEL} effort=${EFFORT} (ladder row, and pin file $( [ -n "$pin" ] && echo "$pin" || echo "n/a" ))"
elif [ "$DO_RUNNERS" = true ]; then
  kit_set_runners
  echo "set-models: runner default -> model=${MODEL} effort=${EFFORT} (both workflow runners)"
else
  # THE DECLARED CARVE-OUT IS STRUCTURAL, NOT A RUNTIME CHECK: ui-designer-worker.md carries no
  # ladder row (its role is parked — model-provisioning.md § B.2 has no line for it), so it has no
  # class key in lib/model-pins.sh's table and --all's loop over $ALL_CLASSES never reaches its pin file.
  # --class cannot reach it either, for the same reason: there is no class name that resolves to
  # it. Re-provisioning the parked role is done by hand, editing the pin directly, exactly because
  # it is off the ladder this script reads.
  for _c in $ALL_CLASSES; do
    kit_ladder_has "$_c" || continue
    label="$(kit_model_class_label "$_c")"
    pin="$(kit_model_class_pin "$_c")"
    kit_set_ladder_row "$label"
    [ -n "$pin" ] && kit_set_pin "$pin"
  done
  kit_set_runners
  echo "set-models: every ladder class -> model=${MODEL} effort=${EFFORT}, and the runner default"
  echo "set-models: ui-designer-worker.md is off the ladder (parked role) and was not touched — edit it directly if you mean to re-provision it too."
fi
