#!/usr/bin/env bash
# Stop the brainstorm server and clean up
# Usage: stop-server.sh <session_dir>
#
# Kills the server process. Only deletes session directory if it's
# under /tmp (ephemeral). Persistent directories (.brainstorm/) are
# kept so mockups can be reviewed later. Removes state/server-info and writes state/server-stopped.

SESSION_DIR="$1"

if [[ -z "$SESSION_DIR" ]]; then
  echo '{"error": "Usage: stop-server.sh <session_dir>"}'
  exit 1
fi

STATE_DIR="${SESSION_DIR}/state"
PID_FILE="${STATE_DIR}/server.pid"

# alive <pid> — the process exists and is not a zombie. A process that has exited and that its
# parent has not reaped still answers kill -0, and `ps -o stat=` names it with a Z. If ps cannot
# say, kill -0's answer stands. A function of this script's own: the skill's scripts stand alone.
alive() {
  kill -0 "$1" 2>/dev/null || return 1
  case "$(ps -o stat= -p "$1" 2>/dev/null | tr -d ' \t')" in Z*) return 1 ;; esac
  return 0
}

if [[ -f "$PID_FILE" ]]; then
  pid=$(cat "$PID_FILE")

  # Try to stop gracefully, fallback to force if still alive
  kill "$pid" 2>/dev/null || true

  # Wait for graceful shutdown (up to ~2s)
  for i in {1..20}; do
    if ! alive "$pid"; then
      break
    fi
    sleep 0.1
  done

  # If still running, escalate to SIGKILL
  if alive "$pid"; then
    kill -9 "$pid" 2>/dev/null || true

    # Give SIGKILL a moment to take effect
    sleep 0.1
  fi

  if alive "$pid"; then
    echo '{"status": "failed", "error": "process still running"}'
    exit 1
  fi

  # server-info is the "alive" marker the skill reads; leave server-stopped in its place
  rm -f "$PID_FILE" "${STATE_DIR}/server.log" "${STATE_DIR}/server-info"
  printf '{"reason": "stopped", "timestamp": %s000}\n' "$(date +%s)" > "${STATE_DIR}/server-stopped"

  # Only delete ephemeral /tmp directories
  if [[ "$SESSION_DIR" == /tmp/* && "$SESSION_DIR" != *..* ]]; then
    rm -rf "$SESSION_DIR"
  fi

  echo '{"status": "stopped"}'
else
  echo '{"status": "not_running"}'
fi
