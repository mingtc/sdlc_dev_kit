#!/usr/bin/env bash
# KIT-CLASS: KIT — harness Notification hook adapter. See process/EXTRACTION.md.
# The harness `Notification` hook → an `attention` ping.
#
# The harness fires the Notification hook when the session is waiting on the
# user (permission prompt, idle-waiting) and sends a JSON payload on stdin. We
# turn that into notify.sh's `attention` class, so the operator is pinged whenever
# the agent needs them — automatically, for ANY role/session, no agent effort
# required.
#
# Wired in .claude/settings.json under hooks.Notification (see that file).
#
# Fail-soft: ANY problem exits 0 — a hook must never block the session. If
# notifications are disabled (NOTIFY_BACKEND unset) notify.sh is a silent no-op,
# so this hook is harmless when unconfigured.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"

payload="$(cat 2>/dev/null || true)"
sid="$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null || true)"
msg="$(printf '%s' "$payload" | jq -r '.message // empty' 2>/dev/null || true)"
[ -z "$msg" ] && msg="The agent needs your attention"

slug="sess-$(printf '%s' "${sid:-unknown}" | cut -c1-8)"

"$ROOT/scripts/notify.sh" attention "$msg" --session "$slug" >/dev/null 2>&1 || true
exit 0
