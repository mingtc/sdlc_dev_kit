#!/usr/bin/env bash
# KIT-CLASS: KIT — the one EXIT-trap helper, so a crash cannot exit 0. See process/EXTRACTION.md.
#
# kit_on_exit '<commands>' — run <commands> when the script exits, and exit with the status the
# script was exiting with. Sourced by every script that cleans up on exit; call it again to
# replace the commands (one trap, one owner).
#
# WHY IT IS NOT `trap 'rc=$?; …; exit $rc' EXIT`: bash 3.2 (macOS /bin/bash), under `set -e`, hands
# an EXIT trap `$?` = 0 after an unbound-variable abort and then exits with whatever the trap
# ends on — so the crash exits 0. No trap can read the real status there, so the script has to
# SAY it finished: an `exit 0` as its last statement. A trap that sees status 0 and no such
# statement reports 1. A script ends with `exit 0` (or an explicit `exit N`) and stays correct on
# every bash.
#
# Mechanism: this file defines a function named `exit` that records a zero exit before calling the
# builtin. Do not define another.
KIT_EXIT_CMD=""
KIT_EXIT_CLEAN=false

exit() {
  local rc="${1:-$?}"
  [ "$rc" = 0 ] && KIT_EXIT_CLEAN=true
  builtin exit "$rc"
}

_kit_exit_trap() {
  local rc=$?
  [ "$rc" -ne 0 ] || [ "$KIT_EXIT_CLEAN" = true ] || rc=1
  # `|| true`: a failing cleanup command must not stop the next one, or change the status.
  eval "$KIT_EXIT_CMD" || true
  builtin exit "$rc"
}

kit_on_exit() {  # <commands>
  KIT_EXIT_CMD="$1"
  trap '_kit_exit_trap' EXIT
}
