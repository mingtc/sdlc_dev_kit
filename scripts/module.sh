#!/usr/bin/env bash
# KIT-CLASS: KIT — list, enable and disable the kit's optional modules. See process/EXTRACTION.md.
# Contract: process/contracts/module-lifecycle.md. What a module is: process/MODULES.md.
#
# A module is an optional overlay the kit ships DISARMED under modules/<name>/ (a harness reads
# nothing there, so a module that is off costs nothing). Enabling it copies its files into place,
# registers it with the extension points process/MODULES.md lists, and records it, with the sha256 of
# each file, in process/MODULES. Disabling it removes every file still byte-equal to what enable wrote,
# and REPORTS, never deletes, one you edited.
#
# Usage:
#   ./scripts/module.sh list
#   ./scripts/module.sh status [<name>]
#   ./scripts/module.sh enable <name>
#   ./scripts/module.sh disable <name>
#
# list      the modules this kit ships, enabled or not: version, purpose, and what each needs.
# status    every enabled module, or one: each thing it placed, as intact, edited or missing (unjudged on a machine with no sha256 tool), and each
#           requirement as holding or not (it runs the module's checks).
# enable    place the module and register it. A required command the module's checks do not find, a path
#           that is not the module's to take (a file that exists, a core kit file, a missing slot), or an
#           extension point whose reader this project's copy of the kit lacks, refuses before anything is
#           written. An optional requirement that fails is a warning. It prints the module's setup steps
#           and never runs its setup.sh. An enable that was killed part-way is finished by running it again.
# disable   take back what enable wrote; an edited file is kept and named. It also takes back an
#           enable that did not finish.
# -h, --help  this text.
#
# Both enable and disable are idempotent: the second run changes nothing and says so. Neither
# commits. They print the paths to commit; commit and push them: check-board.sh reads the trunk, so
# a role the module added is unknown to its role arm until that commit is pushed.
#
# Every refusal leaves a progress record (refusal=<rule-id>) where the project has one to write to.
# Exit 2: a usage error, as scripts/finish-pr.sh's exit table defines it. Exit 1: any other
# refusal, including a surplus positional argument — it looks like a usage error but is not one.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
# shellcheck source=lib/usage.sh
. "$SCRIPT_DIR/lib/usage.sh"
# shellcheck source=lib/exit-trap.sh
. "$SCRIPT_DIR/lib/exit-trap.sh"
# shellcheck source=lib/refuse.sh
. "$SCRIPT_DIR/lib/refuse.sh"
# shellcheck source=lib/modules.sh
. "$SCRIPT_DIR/lib/modules.sh"

usage() { kit_usage "${BASH_SOURCE[0]}"; }   # the path is an ARGUMENT — see lib/usage.sh
# A usage request always succeeds, in any position, before any argument is interpreted
# (issue-creation.md § 3).
for _a in "$@"; do case "$_a" in -h|--help) usage; exit 0 ;; esac; done

# ── PARSE ARGUMENTS FIRST, BEFORE ANY ENVIRONMENT CHECK (issue-creation.md § 3).
CMD=""; NAME=""
while [ $# -gt 0 ]; do
  case "$1" in
    -*) kit_refuse 2 unknown-option "Error: unknown option: $1" "Next: run $(basename "$0") --help, then re-run with one of the commands it lists." ;;
    *)  if [ -z "$CMD" ]; then CMD="$1"
        elif [ -z "$NAME" ]; then NAME="$1"
        else kit_refuse 1 unexpected-argument "Error: unexpected argument: $1" "Next: re-run as: $(basename "$0") list | status [<name>] | enable <name> | disable <name>."; fi
        shift ;;
  esac
done
[ -n "$CMD" ] || kit_refuse 2 module-no-command "Error: no command given." "Next: run $(basename "$0") --help; it lists the commands."
case "$CMD" in
  list|status|enable|disable) ;;
  *) kit_refuse 2 unknown-command "Error: unknown command: $CMD" "Next: run $(basename "$0") --help; it lists the commands." ;;
esac
case "$CMD" in
  enable|disable) [ -n "$NAME" ] || kit_refuse 2 module-no-name "Error: $CMD needs a module name." "Next: $(basename "$0") list names the modules this kit ships, then re-run: $(basename "$0") $CMD <name>." ;;
  list) [ -z "$NAME" ] || kit_refuse 1 unexpected-argument "Error: unexpected argument: $NAME" "Next: list takes none; re-run: $(basename "$0") list." ;;
esac

KIT_MOD_ROOT="$ROOT"; KIT_MOD_SRC="$ROOT"
KIT_MOD_TMP="$(mktemp -d "${TMPDIR:-/tmp}/kit-module.XXXXXX")" || kit_refuse 1 module-no-scratch \
  "Error: could not make a scratch directory." "Next: check the temp directory (TMPDIR), then re-run."
kit_on_exit 'rm -rf "$KIT_MOD_TMP"'

# commit_hint <paths> <trunk-note> — what to commit, and the trunk caveat when the module added something the board reads from the trunk.
commit_hint() {
  echo
  echo "Nothing is committed. Next: review, then commit and push through your own board:"
  printf '%s' "$1" | awk 'NF && !seen[$0]++' | tr '\n' ' ' | sed 's/^/  git add -A -- /; s/ *$//'
  echo
  if [ -n "${2:-}" ]; then
    echo "  check-board.sh's role arm, the move checks, the cell checks and the evidence-kind list read the TRUNK: what this module added to them acts only once that commit is pushed."
  fi
}

case "$CMD" in
  list)
    echo "modules this kit ships (modules/):"
    avail="$(kit_mod_available)" || exit "$?"   # exit-class: internal
    if [ -z "$avail" ]; then echo "  none"; else
      while read -r n v p; do
        if kit_mod_is_enabled "$n"; then st="enabled "; elif kit_mod_is_pending "$n"; then st="UNFINISHED"; else st="disabled"; fi
        # Assignments, not substitutions inside the printf: a refusal inside a substitution ends only the substitution.
        kv="$(kit_mod_kept_version "$n")" || exit "$?"   # exit-class: internal
        needs="$(kit_mod_needs "$n")" || exit "$?"   # exit-class: internal
        kept=""; [ -z "$kv" ] || kept="  [files kept from an earlier disable: ./scripts/module.sh status $n]"
        printf '  %-16s %-8s %s  %s%s\n' "$n" "$v" "$st" "$p" "$kept"
        printf '  %-16s needs: %s\n' "" "$needs"
      done <<< "$avail"
    fi
    echo "Enable one with: ./scripts/module.sh enable <name>   (process/MODULES.md § The catalogue says what each does; enable checks what it needs)" ;;
  status)
    kit_mod_stray_note
    if [ -n "$NAME" ]; then kit_mod_status "$NAME"
    else
      names="$(kit_mod_enabled_names)"
      if [ -z "$names" ]; then echo "module: none enabled (no process/MODULES, or it records none). ./scripts/module.sh list names what could be."
      else
        # Not a pipe: a refusal inside kit_mod_status must end this script, which a pipe's subshell cannot.
        while read -r n; do kit_mod_status "$n"; done <<< "$names"
      fi
    fi ;;
  enable)
    kit_mod_enable "$NAME"
    if [ -n "$KIT_MOD_TOUCHED" ]; then
      trunk_note=""
      case "$KIT_MOD_TOUCHED" in *process/roles.d/*|*process/evidence-kinds.d/*|*scripts/move-check.d/*|*scripts/qa-cell.d/*) trunk_note=1 ;; esac
      commit_hint "$KIT_MOD_TOUCHED" "$trunk_note"
    fi ;;
  disable)
    kit_mod_disable "$NAME"
    if [ -n "$KIT_MOD_TOUCHED" ]; then
      commit_hint "$KIT_MOD_TOUCHED" ""
    fi ;;
esac
exit 0
