#!/usr/bin/env bash
# KIT-CLASS: KIT — one notify backend; add siblings the same way. See process/EXTRACTION.md.
# telegram.sh — Telegram transport adapter for scripts/notify.sh, the COMMUNICATION-METHOD LAYER.
#
# It knows nothing about issue ids, gates or progress — it just delivers a
# normalized message. Swappable: any other chat adapter implements the same verbs
# and the interaction layer is unchanged. This one ships because it is the
# cheapest end-to-end example (a bot token and a chat id, no app to register).
#
# Verbs:
#   send    — deliver NOTIFY_TEXT (exported by notify.sh). Exit 0 ok, non-0 + reason.
#   test    — diagnose config + connectivity end-to-end (token → chat → delivery).
#   chatid  — setup helper: print your chat id from the bot's recent messages.
#
# EVERY FAILURE PATH NAMES ITS FIX. That is the copyable part of this adapter, not
# the vendor: a notification backend that fails with "send failed" teaches the
# operator nothing, so each branch below prints a DIAGNOSIS and the next action.
#
# Reads from the environment (exported by notify.sh, or sourced from the project's
# environment file when run standalone):
#   TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID, NOTIFY_TEXT, NOTIFY_PROJECT_RESOLVED.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Standalone setup commands (chatid/test run by hand) need credentials loaded.
if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] && [ -f "$ROOT/.env" ]; then
  set -a; . "$ROOT/.env"; set +a
fi

API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN:-}"
err() { printf 'telegram: %s\n' "$*" >&2; }

# POST helper → echoes "BODY\nHTTPCODE"; returns non-0 only on transport failure.
tg_post() {
  local method="$1"; shift
  curl -sS -m 10 -w '\n%{http_code}' -X POST "$API/$method" "$@" 2>/dev/null
}
tg_get() {
  curl -sS -m 10 -w '\n%{http_code}' "$API/$1" 2>/dev/null
}
code_of() { printf '%s' "$1" | tail -n1; }
body_of() { printf '%s' "$1" | sed '$d'; }

VERB="${1:-send}"

# A usage request is answered before the verb is interpreted (issue-creation.md § 3).
case "${VERB:-}" in
  -h|--help|help)
    # Loaded here only: sending does not depend on the help renderer.
    # shellcheck source=../lib/usage.sh
    . "$SCRIPT_DIR/../lib/usage.sh" || exit 1
    kit_usage "${BASH_SOURCE[0]:-$0}"; exit 0 ;;
esac

case "$VERB" in
  send)
    if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
      err "missing TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID in the environment file"; exit 1
    fi
    # NOTIFY_SILENT=true → the message is delivered with no sound/vibration (it
    # still lands in the chat). Set by notify.sh from NOTIFY_WITH_MSG_ONLY.
    resp="$(tg_post sendMessage \
      --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
      --data-urlencode "text=${NOTIFY_TEXT:-(no message)}" \
      --data "disable_notification=${NOTIFY_SILENT:-false}" \
      --data "disable_web_page_preview=true")" || { err "network error reaching the API host"; exit 1; }
    [ "$(code_of "$resp")" = "200" ] && exit 0
    err "send failed (HTTP $(code_of "$resp")): $(body_of "$resp" | tr -d '\n' | cut -c1-200)"
    exit 1
    ;;

  test)
    # 1) token present?
    if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
      err "DIAGNOSIS: TELEGRAM_BOT_TOKEN is empty. → Create a bot with the platform's bot-registration flow and paste its token into your environment file."
      exit 1
    fi
    # 2) token valid + reachable?
    resp="$(tg_get getMe)" || { err "DIAGNOSIS: cannot reach the API host (network / DNS / proxy / firewall). → Check connectivity."; exit 1; }
    code="$(code_of "$resp")"; body="$(body_of "$resp")"
    if [ -z "$code" ]; then err "DIAGNOSIS: no response from the API host (network). → Check connectivity."; exit 1; fi
    if [ "$code" = "401" ]; then err "DIAGNOSIS: invalid bot token (401 Unauthorized). → Re-copy the token into TELEGRAM_BOT_TOKEN."; exit 1; fi
    if [ "$code" != "200" ]; then err "DIAGNOSIS: getMe failed (HTTP $code): $(printf '%s' "$body" | tr -d '\n' | cut -c1-160)"; exit 1; fi
    botname="$(printf '%s' "$body" | jq -r '.result.username // "?"' 2>/dev/null || echo '?')"
    # 3) chat id present?
    if [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
      err "DIAGNOSIS: token OK (bot @$botname) but TELEGRAM_CHAT_ID is empty. → Message your bot once, then run: ./scripts/notify/telegram.sh chatid"
      exit 1
    fi
    # 4) end-to-end delivery
    proj="${NOTIFY_PROJECT_RESOLVED:-$(basename "$ROOT")}"
    resp="$(tg_post sendMessage \
      --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
      --data-urlencode "text=✅ notify test OK — [$proj] via @$botname")" || { err "DIAGNOSIS: network error during sendMessage."; exit 1; }
    code="$(code_of "$resp")"; body="$(body_of "$resp")"
    if [ "$code" = "200" ]; then echo "telegram: test message delivered to chat ${TELEGRAM_CHAT_ID} (bot @$botname)"; exit 0; fi
    if printf '%s' "$body" | grep -qi 'chat not found'; then
      err "DIAGNOSIS: TELEGRAM_CHAT_ID='${TELEGRAM_CHAT_ID}' is wrong, or you haven't messaged the bot yet. → Send your bot any message, then re-fetch via: ./scripts/notify/telegram.sh chatid"
      exit 1
    fi
    err "DIAGNOSIS: sendMessage failed (HTTP $code): $(printf '%s' "$body" | tr -d '\n' | cut -c1-200)"
    exit 1
    ;;

  chatid)
    if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then err "set TELEGRAM_BOT_TOKEN in your environment file first."; exit 1; fi
    resp="$(tg_get getUpdates)" || { err "cannot reach the API host."; exit 1; }
    [ "$(code_of "$resp")" = "200" ] || { err "getUpdates failed (HTTP $(code_of "$resp")). Check the bot token."; exit 1; }
    id="$(body_of "$resp" | jq -r '[.result[].message.chat.id] | last // empty' 2>/dev/null)"
    if [ -z "$id" ]; then
      err "no recent messages found. → Open the app, send your bot any message (e.g. \"hi\"), then run this again. (getUpdates only sees the last ~24h and won't work if a webhook is set.)"
      exit 1
    fi
    echo "Your TELEGRAM_CHAT_ID is: $id"
    echo "Paste it into your environment file →  TELEGRAM_CHAT_ID=\"$id\""
    ;;

  *) err "unknown verb '$VERB' (send|test|chatid)"; exit 2 ;;
esac
