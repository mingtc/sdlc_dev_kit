#!/usr/bin/env bash
# KIT-CLASS: KIT — the non-blocking route to a project's principal. See process/EXTRACTION.md.
# A session that hits a blocking question with no PM/human session watching does not stop to
# wait for an answer — it asks in a way that RETURNS. Contract: `PROJECT.md` § Who answers when
# nobody is watching names the principal and the channel; `.claude/roles/dev.md` § Getting
# blocked and `process/doctrine/orchestration.md` § A.5's unattended corollary both point here.
#
# ./scripts/ask.sh --role <role> "<question>" --default "<working default>" [--decision D-NN]
#
# It, in order:
#   1. writes the question as ONE FILE in the channel PROJECT.md declares — one file per
#      question, named so it sorts and is unique: dev/questions/<UTC-timestamp>-<role>-ask.md.
#      The file carries the asker, the time, the question, the working default, and how the
#      answer is recorded (the register entry, if --decision named one; the file itself,
#      cleared in place, if not).
#   2. with --decision D-NN naming a WITHDRAWN entry (no current ruling — DECISIONS.md
#      § The THIRD state): records the working default as PROVISIONAL, amending that entry's
#      Ruling field to `WORKING DEFAULT (provisional, asked <date>, <question file>)` (§ The
#      FOURTH state) — the question file's own path, so the register names its record rather
#      than merely promising one exists. With --decision D-NN naming an entry that HAS a
#      standing ruling: that ruling is NEVER touched — it is what work proceeds under until the
#      principal answers, and this call only records the question. Without --decision, or with
#      an id naming no live entry: records nothing in the register — the question file itself IS
#      where the default is recorded, and the principal answers by editing or clearing it.
#   3. writes ONE progress record (class=info, actor <role>, `asked=<rule-id-shaped slug>`) so
#      every ask is countable.
#   4. RETURNS 0. The session carries on — under the working default, or under the entry's
#      standing ruling where one exists; nothing here blocks it.
#
# It refuses through kit_refuse — principal-undeclared, channel-unusable, or a required
# argument missing — never asking is not a silent success.
#
# IT DOES NOT COMMIT. The question file and any DECISIONS.md edit are metadata
# (process/MANUAL.md § The code-vs-metadata rule) — commit them direct to the trunk through your
# ordinary git flow, the same way any other metadata-only change lands. (A dispatched leg commits
# through whatever the pack's dispatch site names.)
#
# Options:
#   --role <role>        who is asking — one of this project's declared roles. Required.
#   --default "<text>"   the working default to proceed under. Required.
#   --decision <D-NN>    the requirements/DECISIONS.md entry this question could overturn.
#                         Optional; without it the question file alone carries the default.
#   -h, --help            this text.
#
# The question, quoted, is the one required positional argument.
#
# Example:
#   ./scripts/ask.sh --role Dev "Lift D-09 so the tool folder can write the shared drop?" \
#     --default "Hold: write nothing to the shared folder; a person still does it by hand." \
#     --decision D-09
#
#   The `--role` value above IS AN EXAMPLE VALUE: this tree accepts the set rendered by
#   scripts/githooks/commit-msg's ROLE_PREFIXES. Substitute one of yours.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/usage.sh
. "$SCRIPT_DIR/lib/usage.sh"
# shellcheck source=lib/refuse.sh
. "$SCRIPT_DIR/lib/refuse.sh"
# shellcheck source=lib/role-set.sh
[ -r "$SCRIPT_DIR/lib/role-set.sh" ] && . "$SCRIPT_DIR/lib/role-set.sh"

usage() { kit_usage "${BASH_SOURCE[0]}"; }   # the path is an ARGUMENT — see lib/usage.sh
# A usage request always succeeds, in any position, before any argument is interpreted
# (issue-creation.md § 3).
for _a in "$@"; do case "$_a" in -h|--help) usage; exit 0 ;; esac; done

need_val() {
  [ "$#" -ge 2 ] || { echo "Error: $1 requires a value." >&2; exit 2; }
}

ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

ROLE=""; DEFAULT_TXT=""; DECISION=""; QUESTION=""
while [ $# -gt 0 ]; do
  case "$1" in
    --role)     need_val "$@"; ROLE="$2"; shift 2 ;;
    --default)  need_val "$@"; DEFAULT_TXT="$2"; shift 2 ;;
    --decision) need_val "$@"; DECISION="$2"; shift 2 ;;
    -*) kit_refuse 2 ask-unknown-option "Error: unknown option: $1" "  Run $(basename "$0") --help for its options." ;;
    *)
      if [ -z "$QUESTION" ]; then QUESTION="$1"; shift
      else kit_refuse 2 ask-unexpected-argument "Error: unexpected argument: $1" "  The question is ONE quoted positional argument."; fi
      ;;
  esac
done

[ -n "$ROLE" ] || kit_refuse 2 ask-no-role \
  "Error: no --role <role>: who is asking?" \
  "  Run $(basename "$0") --help for its options."
[ -n "$QUESTION" ] || kit_refuse 2 ask-no-question \
  "Error: no question given." \
  "  The question is a quoted positional argument, e.g. ./scripts/ask.sh --role Dev \"...\" --default \"...\""
[ -n "$DEFAULT_TXT" ] || kit_refuse 2 ask-no-default \
  "Error: no --default \"<working default>\": what does the session proceed under while it waits?" \
  "  A question with no working default is a blocked session, not an ask."

# THE ROLE'S SHAPE, checked the same way an operator-supplied role is checked everywhere else
# (lib/role-set.sh's own doc). An unreadable set is a named ACCEPT of membership, never a refusal
# — this library must not fabricate a role set the project never declared.
if command -v kit_role_set >/dev/null 2>&1; then
  _set="$(kit_role_set "$ROOT" 2>/dev/null || true)"
  if [ -n "$_set" ] && command -v kit_role_member >/dev/null 2>&1 && ! kit_role_member "$_set" "$ROLE"; then
    kit_refuse 2 ask-role-not-declared \
      "Error: --role $ROLE is not one of this project's declared roles ($_set)." \
      "  Run $(basename "$0") --help, or check scripts/githooks/commit-msg's ROLE_PREFIXES."
  fi
fi

# ── THE PRINCIPAL AND THE CHANNEL — read from PROJECT.md, never guessed. ──────
PM="$ROOT/PROJECT.md"
[ -f "$PM" ] || kit_refuse 1 ask-no-project-md \
  "Error: no PROJECT.md at $ROOT — the principal and channel are declared there." \
  "  See PROJECT.md § Who answers when nobody is watching."

# One line each: `**label:**` or `` `label:` ``, then ONE backtick-delimited value — the same
# whole-span-is-the-blank shape check-board.sh's FILL scan reads (§ g2). First match wins.
_pm_field() {
  awk -v marker="$1" '
    match($0, marker) {
      rest = substr($0, RSTART + RLENGTH)
      if (match(rest, /`[^`]*`/)) {
        v = substr(rest, RSTART + 1, RLENGTH - 2)
        print v
        exit
      }
    }' "$2"
}
PRINCIPAL_LINE="$(_pm_field '`principal:`' "$PM")"
CHANNEL_LINE="$(_pm_field '\\*\\*Their channel:\\*\\*' "$PM")"

# A blank is still `<angle-bracket>`, WHOLE content, in the shipped sheet — that is not a
# declaration. (check-board.sh's [g2] arm defines "whole content"; this is that same test.)
_is_blank() {
  case "$1" in
    '<'[a-z]*'>') return 0 ;;
  esac
  [ -n "$1" ] || return 0
  return 1
}

if [ -z "$PRINCIPAL_LINE" ] || _is_blank "$PRINCIPAL_LINE"; then
  kit_refuse 1 ask-no-principal \
    "Error: PROJECT.md names no principal — § Who answers when nobody is watching's \`principal:\` line is missing or unfilled." \
    "  Fill it (a name/role, or \"nobody: ...\"), then re-run."
fi
if [ -z "$CHANNEL_LINE" ] || _is_blank "$CHANNEL_LINE"; then
  kit_refuse 1 ask-no-channel \
    "Error: PROJECT.md names no channel for the principal's questions — § Who answers when nobody is watching's \"Their channel\" line is missing or unfilled." \
    "  Fill it (a directory or file, e.g. \"dev/questions/\"), then re-run."
fi

# The channel line is prose ("dev/questions/, one dated file per question"); the FIRST token
# that looks like a repo-relative path is the channel. A channel this project chose to write
# as a bare filename (no trailing slash) is a FILE, not a directory: append to it.
CHANNEL_TOKEN="$(printf '%s' "$CHANNEL_LINE" | awk '{ for (i=1;i<=NF;i++) if ($i ~ /^[A-Za-z0-9._-]+\/?([A-Za-z0-9._\/-]*)?$/ && $i ~ /\//) { print $i; exit } }')"
[ -n "$CHANNEL_TOKEN" ] || CHANNEL_TOKEN="$(printf '%s' "$CHANNEL_LINE" | awk '{print $1}')"
CHANNEL_TOKEN="${CHANNEL_TOKEN%,}"

case "$CHANNEL_TOKEN" in
  */) CHANNEL_DIR="$ROOT/${CHANNEL_TOKEN%/}"; CHANNEL_IS_DIR=1 ;;
  *)  if [ -d "$ROOT/$CHANNEL_TOKEN" ]; then CHANNEL_DIR="$ROOT/$CHANNEL_TOKEN"; CHANNEL_IS_DIR=1
      else CHANNEL_DIR="$ROOT/$(dirname "$CHANNEL_TOKEN")"; CHANNEL_IS_DIR=0; fi ;;
esac

if ! mkdir -p "$CHANNEL_DIR" 2>/dev/null || [ ! -w "$CHANNEL_DIR" ]; then
  kit_refuse 1 ask-channel-unusable \
    "Error: the declared channel ($CHANNEL_TOKEN → $CHANNEL_DIR) cannot be created or is not writable." \
    "  Fix PROJECT.md's \"Their channel\" line, or the directory's permissions, then re-run."
fi

TS="$(date -u +%Y-%m-%dT%H%M%SZ)"
SAFE_ROLE="$(printf '%s' "$ROLE" | tr -c 'A-Za-z0-9' '-')"
if [ "$CHANNEL_IS_DIR" -eq 1 ]; then
  QFILE="$CHANNEL_DIR/${TS}-${SAFE_ROLE}-ask.md"
  # One file per question: a second ask in the same second takes the next free suffix.
  _n=1
  while [ -e "$QFILE" ]; do
    _n=$((_n + 1)); QFILE="$CHANNEL_DIR/${TS}-${SAFE_ROLE}-${_n}-ask.md"
  done
else
  QFILE="$ROOT/$CHANNEL_TOKEN"
fi
# CHANNEL-RELATIVE: the pointer § The FOURTH state's Ruling line carries, so the register names
# the record rather than merely promising one exists somewhere.
QREL="${QFILE#"$ROOT"/}"

# ── READ THE REGISTER'S STATE FIRST, BEFORE WRITING ANYTHING — the question file's own "how
#    the answer is recorded" text depends on it, and a STANDING RULING is never touched: it is
#    what work proceeds under until the principal answers. Overwriting it would let a question
#    provisionally grant its own premise just by being asked (run 5's own case — "may I lift
#    D-09?" must not itself lift D-09). Only an entry with NO current ruling — the register's
#    WITHDRAWN state, § The THIRD state — has anywhere for a working default to go.
DEC="$ROOT/requirements/DECISIONS.md"
DECISION_STATE="none"        # none | withdrawn | standing
CUR_RULING=""
if [ -n "$DECISION" ] && [ -f "$DEC" ] && grep -qE "^### ${DECISION}( |—|$)" "$DEC" 2>/dev/null; then
  CUR_RULING="$(awk -v id="$DECISION" '
    /^### / { in_entry = ($0 ~ ("^### " id "( |—|$)")) }
    in_entry && /^\*\*Ruling\.\*\*/ { sub(/^\*\*Ruling\.\*\* /, ""); print; exit }
  ' "$DEC")"
  case "$CUR_RULING" in
    WITHDRAWN*) DECISION_STATE="withdrawn" ;;
    *)          DECISION_STATE="standing" ;;
  esac
fi

# How the answer is recorded, and what the question file itself says — three distinct cases.
TODAY="$(date -u +%Y-%m-%d)"
case "$DECISION_STATE" in
  withdrawn)
    ANSWER_ROUTE="requirements/DECISIONS.md, entry $DECISION — was WITHDRAWN (no current ruling); this call gives it a WORKING DEFAULT (provisional, asked $TODAY, $QREL)"
    ;;
  standing)
    ANSWER_ROUTE="requirements/DECISIONS.md, entry $DECISION — HAS A STANDING RULING, left untouched. That ruling is what this session proceeds under, not the working default below; the principal answers whether to change it"
    ;;
  *)
    if [ -n "$DECISION" ]; then
      ANSWER_ROUTE="--decision $DECISION does not name a live entry in requirements/DECISIONS.md (no '### $DECISION' heading) — this file is where the default is recorded instead"
    else
      ANSWER_ROUTE="this file — the principal (or whoever answers on their behalf) edits or clears it in place"
    fi
    ;;
esac

{
  printf '# Question from %s, %s\n\n' "$ROLE" "$TS"
  printf '**Asker:** %s\n' "$ROLE"
  printf '**Time:** %s\n' "$TS"
  printf '**Question:** %s\n\n' "$QUESTION"
  printf '**Working default (provisional):** %s\n\n' "$DEFAULT_TXT"
  if [ "$DECISION_STATE" = "standing" ]; then
    printf 'The session is proceeding under requirements/DECISIONS.md entry %s'"'"'s STANDING\n' "$DECISION"
    printf 'RULING (unchanged by this call), not under the working default above, until the\n'
    printf 'principal answers.\n'
  else
    printf 'The session is proceeding under the working default above and is NOT waiting on this\n'
    printf 'file — %s.\n' "process/doctrine/orchestration.md § A.5's unattended corollary: record and keep working"
  fi
  printf '\n**How the answer is recorded:** %s\n' "$ANSWER_ROUTE"
} >> "$QFILE" || kit_refuse 1 ask-write-failed \
  "Error: could not write the question to $QFILE." \
  "  Check the channel's permissions, then re-run."

DECISION_NOTE="$ANSWER_ROUTE"
if [ "$DECISION_STATE" = "withdrawn" ]; then
  # Amend ONLY the Ruling line of that entry — everything else of the three-field entry (Why,
  # Provenance) is untouched; the working-default text replaces the ruling's own words, never
  # appended beside them (DECISIONS.md § The FOURTH state). The pointer to the question file is
  # IN the token, so a reader of the register alone can find it.
  awk -v id="$DECISION" -v tok="WORKING DEFAULT (provisional, asked $TODAY, $QREL) — $DEFAULT_TXT" '
    BEGIN { in_entry = 0; done = 0 }
    /^### / { in_entry = ($0 ~ ("^### " id "( |—|$)")) }
    in_entry && /^\*\*Ruling\.\*\*/ && !done {
      print "**Ruling.** " tok
      done = 1
      next
    }
    { print }
  ' "$DEC" > "$DEC.ask.tmp" && mv "$DEC.ask.tmp" "$DEC" \
    || kit_refuse 1 ask-decisions-write-failed \
         "Error: could not write the provisional default into requirements/DECISIONS.md." \
         "  The question file at $QFILE still records it; fix DECISIONS.md by hand."
fi

kit_progress "$ROLE" info "asked: ${QUESTION}" "asked=$(printf '%s' "$ROLE" | tr 'A-Z' 'a-z')-blocking-question" "file=$QFILE"

echo "ask.sh: question written to $QFILE"
echo "  Working default recorded in: $DECISION_NOTE"
if [ "$DECISION_STATE" = "standing" ]; then
  echo "  Proceeding under entry $DECISION's STANDING RULING — unchanged. Nothing here is committed —"
  echo "  commit the question file through your ordinary metadata commit route."
else
  echo "  Proceeding under the working default. Nothing here is committed — commit the question file"
  echo "  (and requirements/DECISIONS.md, if amended) through your ordinary metadata commit route."
fi
exit 0
