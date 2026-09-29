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
#   kit_refuse 1 card-not-found "Error: <id> is in no progress/ folder." "  <what to do instead>"
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
# An `exit N` a script keeps on purpose, beside an `Error:` line, carries
# `# refusal-exempt: <why>` on its line; the self-test reports every other one.

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
