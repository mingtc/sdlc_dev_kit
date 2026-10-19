#!/usr/bin/env bash
# KIT-CLASS: KIT — the unattended Stop hook; blocks a turn ending on an unaddressed question.
# See process/EXTRACTION.md.
#
# Wired only in .claude/settings.unattended.json.example (hooks.Stop): on an unattended launch a
# turn that ends on a question has nobody to answer it (process/doctrine/orchestration.md § A.5's
# unattended corollary). The harness passes the Stop event as JSON on stdin; exit 0 with empty
# stdout lets the stop proceed, and exit 0 with {"decision":"block","reason":"<text>"} on stdout
# blocks it once — <text> becomes the session's next prompt.
#
#   stop_hook_active true                          → allow (the loop guard: this stop was already blocked once).
#   a sentence in the final paragraph ends on ?    → block once, naming scripts/ask.sh.
#   anything else                                  → allow.
#
# Only the ENDING is judged: the final paragraph (the last run of non-blank lines), after un-escaping
# and with fenced code blocks and inline code spans removed. A sentence ends on "?" when the mark is
# followed by closing emphasis, quotes or brackets and then whitespace or the paragraph's end, so a
# "?" in a URL or in code never counts. A question in an earlier paragraph does not block, and a
# request with no "?" ("say so if you want it", "please confirm") is not caught. POSIX tools only
# (no jq); a payload it cannot parse reads as allow, so a parsing defect never holds a session open.
set -uo pipefail

payload="$(cat 2>/dev/null || true)"

# Extract a top-level JSON string field's value, RAW (still JSON-escaped) — scans char by char
# so an escaped quote inside the string never reads as the string's end.
_json_str_field() {
  local key="$1"
  printf '%s' "$payload" | awk -v key="$key" '
    {
      idx = index($0, key)
      if (idx == 0) { next }
      rest = substr($0, idx + length(key))
      sub(/^[ \t]*:[ \t]*/, "", rest)
      if (substr(rest, 1, 1) != "\"") { next }
      rest = substr(rest, 2)
      out = ""; i = 1; n = length(rest)
      while (i <= n) {
        c = substr(rest, i, 1)
        if (c == "\\") { out = out c substr(rest, i + 1, 1); i += 2; continue }
        if (c == "\"") { print out; found = 1; exit }
        out = out c; i++
      }
    }
    END { if (!found) exit 1 }
  '
}

# Extract a top-level JSON boolean field's value ("true"/"false"), empty if absent/unparsed.
_json_bool_field() {
  local key="$1"
  printf '%s' "$payload" | awk -v key="$key" '
    {
      idx = index($0, key)
      if (idx == 0) next
      rest = substr($0, idx + length(key))
      sub(/^[ \t]*:[ \t]*/, "", rest)
      if (rest ~ /^true/)  { print "true";  found = 1; exit }
      if (rest ~ /^false/) { print "false"; found = 1; exit }
    }
    END { if (!found) exit 1 }
  '
}

# ── ALLOW #1 — the loop guard. FIRST + unconditional.
stop_hook_active="$(_json_bool_field '"stop_hook_active"' 2>/dev/null || true)"
if [ "$stop_hook_active" = "true" ]; then
  exit 0
fi

last_msg="$(_json_str_field '"last_assistant_message"' 2>/dev/null || true)"

# ── ALLOW #2 — no message to judge (field absent, or the harness sent an empty string).
if [ -z "$last_msg" ]; then
  exit 0
fi

# Un-escape \n, \t, \", \\ so the message reads as the lines the model wrote, drop fenced code
# blocks and inline code spans (a "?" inside code is not a question), then take the final
# paragraph: the last run of non-blank lines.
final_para="$(
  printf '%s' "$last_msg" | awk '
    {
      s = $0; out = ""; i = 1; n = length(s)
      while (i <= n) {
        c = substr(s, i, 1)
        if (c == "\\") {
          d = substr(s, i + 1, 1)
          if (d == "n")      { out = out "\n"; i += 2; continue }
          if (d == "t")      { out = out "\t"; i += 2; continue }
          if (d == "\"")     { out = out "\""; i += 2; continue }
          if (d == "\\")     { out = out "\\"; i += 2; continue }
          out = out d; i += 2; continue
        }
        out = out c; i++
      }
      print out
    }
  ' | awk '
    /^[ \t]*(```|~~~)/ { infence = !infence; if (para != "") { last = para; para = "" }; next }
    infence            { next }
    {
      gsub(/`[^`]*`/, "")
      if ($0 ~ /^[ \t]*$/) { if (para != "") { last = para; para = "" }; next }
      para = (para == "" ? $0 : para "\n" $0)
    }
    END { if (para != "") last = para; print last }
  '
)"

# A sentence ends on "?" when the mark is followed by closing emphasis, quote or bracket
# characters and then whitespace or the end of the paragraph.
if ! printf '%s\n' "$final_para" | grep -Eq '\?[])*_"'"'"']*([[:space:]]|$)'; then
  exit 0                 # no sentence in the final paragraph asks — ALLOW
fi

# ── BLOCK ONCE. The reason is embedded in JSON unescaped, so it must hold no double quote.
reason="This turn ended on a question with no one here to answer it (an unattended launch). File it with scripts/ask.sh --role <the role you are acting as, never the principal's> then the question, --default <working default>, and continue under that default, or state the next action and take it. Do not end the turn on an unaddressed question again."
printf '{"decision":"block","reason":"%s"}' "$reason"
exit 0
