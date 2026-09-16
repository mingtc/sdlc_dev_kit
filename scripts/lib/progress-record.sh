#!/usr/bin/env bash
# KIT-CLASS: KIT — the ONE progress-record writer. See process/EXTRACTION.md.
#
# ONE RECORD SHAPE, ONE PLACE, TRANSIENT BY CONSTRUCTION.
#
# Progress is already announced by several shipped scripts — to stdout, in their own
# wording, and nowhere a reader can open after the stream has scrolled away. This
# library adds the durable-for-a-day half: the same four fields, appended as one line
# to one gitignored directory, by a script or by a role.
#
# THE FOUR REQUIRED FIELDS, and nothing else is required:
#
#     timestamp   ISO-8601 UTC. Makes elapsed time and liveness EXACT rather than
#                 inferred — that is the whole reason it is not optional.
#     actor       who wrote it. `<role>:<issue-id>` where one applies, so attribution
#                 is ASSIGNED BY THE CALLER rather than reported by the agent.
#     class       status | info | warning | error — what a reader filters on.
#     description the human-readable line.
#
# EVERYTHING ELSE IS OPTIONAL, and optional means an ADDITIONAL FIELD, never a
# different payload. A reader that understands only the four required fields must be
# able to read every record, and that is the test. The temptation this resists: a
# script's phases are known at authoring time while a role's path branches, which
# looks like an argument for two shapes. It is not — a branch is an optional field,
# and a divergent payload is exactly what forces the fork in the parser. A format
# with a fork in the middle has to be learned twice.
#
# THE FORMAT IS TAB-SEPARATED, four fixed columns then `key=value` extras:
#
#     2026-09-16T10:04:11Z<TAB>Dev:KIT-042<TAB>status<TAB>moved to dev_complete<TAB>step=13 of 13
#
#   Tab, because the four required columns are then split by any reader in any
#   language with no quoting rules to agree on first, and because it is the one
#   separator the description will not contain — newlines and tabs are stripped from
#   every field before it is written (see _pr_clean), so a record is always exactly
#   one line and always has at least four columns. JSON was the alternative and was
#   not taken: it needs an encoder in every writer, and `awk -F'\t'` is the floor
#   this kit already requires.
#
# TRANSIENT BY CONSTRUCTION — THE RULE TO WRITE DOWN IS *nobody should ever have to
# dig through old logs for anything*. The directory is gitignored, records older than
# KIT_PROGRESS_TTL_DAYS (default 2) are unlinked on every write, and durable insight
# continues to live in reports, the card's Activity log and change files. If you find
# yourself wanting to KEEP one of these, what you actually want is a change file.
#
# THE VOLUME OBJECTION DOES NOT SURVIVE THE EXPIRY RULE. A suite running five-digit
# test counts may emit a line per test: that write is negligible against executing the
# test, and the lines are gone within a day.
#
# UNSUBSCRIBED RECORDS MAY BE OMITTED, AND NOTHING MAY DEPEND ON ONE. Every function
# here returns 0 whatever happens — an unwritable directory, a full disk, a read-only
# checkout. A caller that branches on the return value has made this a dependency,
# which is the one thing it must not become. Each addition must help WITH NO WATCHER
# AT ALL: `kit_progress_tail` is for the operator staring at a terminal, and that is
# the test a new field has to pass. A field that exists only to feed a dashboard fails.
#
# THE DIRECTORY IS A SEAM: KIT_PROGRESS_DIR overrides it. Default `.progress-records/`
# at the repo root, one file per UTC day (`YYYY-MM-DD.tsv`), appended to. One place,
# one structure — not one file.

# _pr_clean <string> — collapse a field to something that cannot break the record.
# Tabs and newlines become spaces; a trailing space is trimmed. NOT a quoting scheme:
# there is nothing to unquote, because nothing survives that would need it.
_pr_clean() {
  printf '%s' "$1" | tr '\n\r\t' '   ' | sed 's/[[:space:]]\{1,\}$//'
}

# kit_progress_dir — where records go. Derived, never assumed present.
kit_progress_dir() {
  if [ -n "${KIT_PROGRESS_DIR:-}" ]; then printf '%s' "$KIT_PROGRESS_DIR"; return 0; fi
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || root=""
  [ -n "$root" ] || root="$PWD"
  printf '%s/.progress-records' "$root"
}

# _pr_expire <dir> — unlink day files older than the TTL. Best-effort, always 0.
# `find -mtime` is POSIX and needs no date arithmetic in shell.
_pr_expire() {
  local d="$1" ttl="${KIT_PROGRESS_TTL_DAYS:-2}"
  case "$ttl" in ''|*[!0-9]*) ttl=2 ;; esac
  find "$d" -maxdepth 1 -name '*.tsv' -type f -mtime "+$ttl" -exec rm -f {} + 2>/dev/null
  return 0
}

# kit_progress <actor> <class> <description> [key=value …]
#
# ALWAYS RETURNS 0. See the header: an unsubscribed record may be omitted, so a
# failure to write is not a failure of the caller's work.
kit_progress() {
  local actor="$1" class="$2" desc="$3"; shift 3 2>/dev/null || true

  # THE CLASS IS CLOSED, and an unknown one is NOT dropped — it is written as `info`
  # with the offered value carried in an optional field. Dropping the record would
  # make a typo in a caller look like work that never happened, which is the one
  # reading this format must never produce.
  local extra=""
  case "$class" in
    status|info|warning|error) ;;
    *) extra="declared-class=$(_pr_clean "$class")"; class="info" ;;
  esac

  local dir; dir="$(kit_progress_dir)"
  mkdir -p "$dir" 2>/dev/null || return 0
  [ -w "$dir" ] || return 0
  _pr_expire "$dir"

  local ts day
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" || return 0
  day="${ts%%T*}"

  local k
  for k in "$@"; do
    [ -n "$k" ] || continue
    extra="${extra}${extra:+ }$(_pr_clean "$k")"
  done

  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$ts" "$(_pr_clean "$actor")" "$class" "$(_pr_clean "$desc")" "$extra" \
    >> "$dir/$day.tsv" 2>/dev/null
  return 0
}

# kit_progress_tail [n] — the operator's read. THIS IS THE NO-WATCHER HALF: it is
# what makes the records useful to a person with nothing running but a terminal, and
# it is why this library is not a dashboard feed wearing additive clothes.
kit_progress_tail() {
  local n="${1:-20}" dir; dir="$(kit_progress_dir)"
  [ -d "$dir" ] || { echo "no progress records under $dir"; return 0; }
  # shellcheck disable=SC2012  # ls is fine here: the names are ISO dates, never odd.
  cat $(ls "$dir"/*.tsv 2>/dev/null | sort) 2>/dev/null | tail -n "$n" \
    | awk -F'\t' '{printf "%s  %-22s %-7s %s%s\n", $1, $2, $3, $4, ($5 != "" ? "  [" $5 "]" : "")}'
  return 0
}
