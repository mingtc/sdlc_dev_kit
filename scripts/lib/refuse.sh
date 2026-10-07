#!/usr/bin/env bash
# KIT-CLASS: KIT — the one refusal helper. See process/EXTRACTION.md.
#
# kit_refuse <status> <rule-id> <message…> — a refusal that leaves a countable record.
#
#   1. prints <message…> to stderr, one argument per line;
#   2. writes ONE progress record through lib/progress-record.sh: class `error`, the script that
#      was run as actor (`<name>.sh`), the first message line as description, `refusal=<rule-id>`;
#   3. exits <status>.
#
#   kit_refuse 1 card-not-found "Error: <id> is in no progress/ folder." "Next: <the step that clears it>"
#
# THE NEXT LINE. Every message carries one argument opening `Next: `: the concrete command or
# step that clears the refusal honestly, or, where no honest route lies inside the caller's
# authority, the escalation — `./scripts/ask.sh --role <role> "<question>" --default "<working
# default>"`, or stop and hand off. A refusal that names only what is wrong leaves the agent that
# hit it to invent a way out. The self-test reads that line from every call.
#
# <status> is an integer 1-255. <rule-id> follows the convention in
# process/contracts/progress-record.md § 5b (stable, kebab-case, named for the rule).
#
# THE RECORD NEVER DECIDES THE REFUSAL: with the writer absent or its directory unwritable, the
# message and the status are unchanged.
#
# A MALFORMED CALL (bad status, bad rule id, no message) still refuses, never exits 0: it names
# itself on stderr, prints the message, records `refusal=kit-refuse-malformed`, and exits the
# given status, or 70 when the status itself is bad.
#
# CALLED INSIDE $( … ) IT EXITS ONLY THE SUBSHELL.
#
# THE THREE KINDS OF NONZERO EXIT. Every nonzero `exit` in a shipped shell program is one of:
#
#   REFUSAL   the state forbids the act, and the same command with well-formed arguments would be
#             refused again until something is done. It goes through kit_refuse, with a `Next:` line.
#   USAGE     the arguments are malformed (an unknown option, a missing value, a surplus
#             positional); the answer is the script's usage text, which is the route. It stays an
#             `exit`, on a line that calls `usage` before it (`usage >&2; exit 2`), inside the
#             `need_val` guard, or carrying `# exit-class: usage` where the usage call is on an
#             earlier line.
#   INTERNAL  a tool or I/O step failed, or the status is one the script computed or relayed; no
#             state of the caller's forbids anything. The line carries `# exit-class: internal`
#             and the message says what failed.
#
# A hook that must still block when this helper cannot load keeps its `exit` after a guarded
# `kit_refuse` call, marked `# exit-class: fallback` within 12 lines below that call.
#
# A check that reads the project's state (a card's column, a file, a git ref, a declared value) is a
# REFUSAL, whatever exit status it uses; do not mark it usage or internal to avoid the helper. The
# self-test fails any nonzero exit that is none of the three.

if ! command -v kit_progress >/dev/null 2>&1; then
  if [ -r "$(dirname "${BASH_SOURCE[0]}")/progress-record.sh" ]; then
    # shellcheck source=progress-record.sh
    . "$(dirname "${BASH_SOURCE[0]}")/progress-record.sh" 2>/dev/null || true
  fi
fi

kit_refuse() {
  local status="${1:-}" rule="${2:-}" bad="" top actor
  if [ "$#" -ge 2 ]; then shift 2; else shift "$#"; fi

  case "$status" in
    ''|*[!0-9]*|0*|????*) bad="status '$status' is not an integer 1-255" ;;
    *) [ "$status" -le 255 ] || bad="status '$status' is not an integer 1-255" ;;
  esac
  case "$rule" in
    [a-z]*) case "$rule" in *[!a-z0-9-]*|*-|*--*) bad="${bad:+$bad; }rule id '$rule' is not kebab-case" ;; esac ;;
    *) bad="${bad:+$bad; }rule id '$rule' is not kebab-case" ;;
  esac
  [ "$#" -gt 0 ] && [ -n "${1:-}" ] || bad="${bad:+$bad; }no message"

  # The actor is the script that was run: the outermost file on the call stack.
  top="${BASH_SOURCE[$(( ${#BASH_SOURCE[@]} - 1 ))]:-$0}"
  [ "$top" != "${BASH_SOURCE[0]}" ] || top="$0"
  actor="${top##*/}"

  if [ -n "$bad" ]; then
    printf 'kit_refuse: malformed call from %s — %s.\n' "$actor" "$bad" >&2
    case "$status" in ''|*[!0-9]*|0*|????*) status=70 ;; *) [ "$status" -le 255 ] || status=70 ;; esac
    rule="kit-refuse-malformed"
  fi
  [ "$#" -eq 0 ] || printf '%s\n' "$@" >&2

  if command -v kit_progress >/dev/null 2>&1; then
    kit_progress "$actor" error "${1:-kit_refuse: malformed call ($bad)}" "refusal=$rule" >/dev/null 2>&1 || true
  fi
  exit "$status"
}
