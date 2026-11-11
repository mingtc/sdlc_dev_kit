# KIT-CLASS: KIT — keeps a script's own output writable after its reader has gone. See process/EXTRACTION.md.
#   Sourced by scripts/lib/kanban-worktree.sh (so every script that commits to the board has it) and
#   by scripts/release.sh. Defines kwt_hold_output and nothing else; sourcing it runs nothing.
#
# A CLOSED OUTPUT PIPE MUST NOT STOP A SCRIPT BETWEEN TWO OF ITS WRITES TO THE REPOSITORY. A caller
# that reads `<op> | head -1` closes the pipe after one line, and the op's next write then fails:
# SIGPIPE kills it, and with that signal ignored the write returns EPIPE and `set -e` exits on the
# same line. Either way what the op had committed is left unpublished, and the account it prints
# of that state is never read. So ignoring the signal is no cure; the writes must not fail. A
# script that mutates calls kwt_hold_output before its first write that follows a commit or a
# lock: its stdout and stderr then go through a drain that copies to the caller until the caller's
# pipe closes and reads and discards after that. What the caller never read is not shown.
# Only a pipe or a socket is drained (a terminal or a file does not close under its writer); a
# stream closed outright (`>&-`) is pointed at /dev/null. Stdout and stderr that are one pipe
# (`2>&1`) share one drain, which keeps their order. The drain runs with `set +e`: it inherits the
# caller's, and the copying `cat` dies of the closed pipe, which would end the drain. It ignores
# TERM and HUP: a signal to the whole process group would otherwise take it down with the op, and
# the op's exit trap would then write to a closed pipe.
kwt_hold_output() {
  # A stream closed outright (`>&-`) fails every write with EBADF, which no drain can serve: send it
  # to /dev/null. A pipe or a socket is what a reader closes under the writer.
  [ -e /dev/fd/1 ] || exec >/dev/null
  [ -e /dev/fd/2 ] || exec 2>/dev/null
  local out=false err=false
  { [ -p /dev/stdout ] || [ -S /dev/stdout ]; } && out=true
  { [ -p /dev/stderr ] || [ -S /dev/stderr ]; } && err=true
  if [ "$out" = true ] && [ "$err" = true ] && [ /dev/stdout -ef /dev/stderr ]; then
    exec > >(trap '' TERM HUP; set +e; cat 2>/dev/null; cat >/dev/null 2>&1) 2>&1
    return 0
  fi
  if [ "$out" = true ]; then
    exec > >(trap '' TERM HUP; set +e; cat 2>/dev/null; cat >/dev/null 2>&1)
  fi
  if [ "$err" = true ]; then
    exec 2> >(trap '' TERM HUP; set +e; cat >&2 2>/dev/null; cat >/dev/null 2>&1)
  fi
  return 0
}
