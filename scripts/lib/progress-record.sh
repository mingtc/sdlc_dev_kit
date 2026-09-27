#!/usr/bin/env bash
# KIT-CLASS: KIT — the ONE progress-record writer. See process/EXTRACTION.md.
# The contract, with every rule below and its reasons: process/contracts/progress-record.md.
#
# One record shape, appended as one line to one gitignored directory, by a script or a role.
#
# THE FOUR REQUIRED FIELDS, and nothing else is required:
#
#     timestamp   ISO-8601 UTC, so elapsed time and liveness are exact.
#     actor       ASSIGNED BY THE CALLER: `<role>` or `<role>:<issue-id>` (role from the
#                 declared set), or `<name>.sh`. Anything else is written as `unknown` with
#                 the offered value in `declared-actor=`.
#     class       status | info | warning | error — what a reader filters on.
#     description the human-readable line.
#
# EVERYTHING ELSE IS AN ADDITIONAL FIELD, never a different payload: a reader of the four
# required fields must read every record.
#
# TAB-SEPARATED, four fixed columns then space-separated `key=value` extras:
#
#     2026-09-16T10:04:11Z<TAB>Dev:KIT-042<TAB>status<TAB>moved to dev_complete<TAB>step=13/13
#
#   Tabs and newlines are stripped from every field (_pr_clean), so a record is one line with
#   at least four columns. An extra's value must be ONE token (`step=13/13`, not `step=13 of 13`).
#
# TRANSIENT: records older than KIT_PROGRESS_TTL_DAYS (default 2) are unlinked on every write.
# Wanting to KEEP one means you want a change file.
#
# NOTHING MAY DEPEND ON A RECORD: every function returns 0 and writes nothing to stderr, whatever
# happens. A new field must help an operator with no watcher but a terminal (kit_progress_tail).
#
# SEAMS: KIT_PROGRESS_DIR (default `.progress-records/` at the main checkout's root, one
# `YYYY-MM-DD.tsv` per UTC day); KIT_PROGRESS_RUN, which appends `run=<id>` to every record.
# Its propagation to subagents is the dispatching site's job, not this file's: pass it as a
# per-command prefix (.claude/skills/orchestrate/SKILL.md § Dispatch attribution § 7).

# _pr_clean <string> — collapse a field to something that cannot break the record.
# Tabs and newlines become spaces; a trailing space is trimmed. Not a quoting scheme.
_pr_clean() {
  printf '%s' "$1" | tr '\n\r\t' '   ' | sed 's/[[:space:]]\{1,\}$//'
}

# _pr_tok <string> — collapse a field to a SINGLE TOKEN, for a value read back out of the
# space-separated extras. Runs of whitespace become `_`; an empty result becomes `<empty>`.
#
# TRIM THE EDGES FIRST, then substitute: substituting first makes a caller's own `_` at an edge
# indistinguishable from a substituted one, and the trim eats it. A value that is already one
# token is carried BYTE FOR BYTE, so a typo stays visible.
_pr_tok() {
  local v
  v="$(printf '%s' "$1" | tr '\n\r\t' '   ' | sed 's/^[[:space:]]\{1,\}//; s/[[:space:]]\{1,\}$//; s/[[:space:]]\{1,\}/_/g')"
  [ -n "$v" ] || v='<empty>'
  printf '%s' "$v"
}

# kit_progress_dir — where records go. Derived, never assumed present.
#
# EVERY WORKTREE OF ONE REPOSITORY WRITES ONE PLACE: the MAIN checkout's root (first entry of
# `git worktree list --porcelain`), so a linked worktree's records survive its removal. It is
# accepted only if not bare AND its own top level, asked with GIT_DIR and GIT_WORK_TREE unset
# (a hook exports GIT_DIR, which makes any directory answer as a top level). Otherwise this
# checkout's top level, or $PWD outside a repository. Those fallbacks can be removed with their
# tree; carry an absolute KIT_PROGRESS_DIR there.
kit_progress_dir() {
  if [ -n "${KIT_PROGRESS_DIR:-}" ]; then printf '%s' "$KIT_PROGRESS_DIR"; return 0; fi
  local root main
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || root=""
  [ -n "$root" ] || root="$PWD"
  main="$(git worktree list --porcelain 2>/dev/null \
    | awk 'NR==1 && /^worktree /{p=substr($0,10)} /^$/{exit} /^bare$/{p=""} END{print p}')"
  if [ -n "$main" ] && [ "$(unset GIT_DIR GIT_WORK_TREE; git -C "$main" rev-parse --show-toplevel 2>/dev/null)" = "$main" ]; then
    root="$main"
  fi
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

# _pr_role_set — the project's declared role set, `|`-separated, or empty.
#
# NO SECOND READ OF ROLE_PREFIXES: lib/role-set.sh owns it (process/EXTRACTION.md § 2.4).
#
# FALLBACK POLICY — AN UNREADABLE SET IS A NAMED ACCEPT of the MEMBERSHIP question only. This
# library can neither announce nor refuse (it must not write stderr or fail its caller), and
# tagging every role record `unknown` on a hookless tree would poison the column. The structural
# half is still checked by _pr_actor_ok. Callers MUST treat empty as "could not read", never as
# "no roles declared".
_pr_role_set() {
  command -v kit_role_set >/dev/null 2>&1 || return 0
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || root=""
  [ -n "$root" ] || root="$PWD"
  kit_role_set "$root" 2>/dev/null
}

# _pr_actor_ok <actor> — status 0 when <actor> has the declared shape.
#
# CASE-SENSITIVE, like the commit-msg hook and kit_role_member: `dev` is not `Dev`. A case typo
# is tagged, never normalised; attribution is the caller's.
_pr_actor_ok() {
  local a="$1" role set_
  # The script side: `<name>.sh`, not a role (contracts/progress-record.md § 5a).
  case "$a" in
    *.sh) case "$a" in *[!A-Za-z0-9._-]*) return 1 ;; *) return 0 ;; esac ;;
  esac
  # The role side: `<role>` or `<role>:<id>`. Split on the FIRST colon only — an issue id
  # may legally contain one.
  #
  # The STRUCTURAL half — non-empty role, non-empty id after any colon, no whitespace — holds on
  # every tree, so it is checked first and unconditionally, even when the set is unreadable.
  case "$a" in
    *[[:space:]]*) return 1 ;;
  esac
  role="${a%%:*}"
  [ -n "$role" ] || return 1
  case "$a" in *:*) [ -n "${a#*:}" ] || return 1 ;; esac
  # The MEMBERSHIP half. Empty set = could not read = accept; see _pr_role_set's policy.
  set_="$(_pr_role_set)"
  [ -n "$set_" ] || return 0
  case "|$set_|" in *"|$role|"*) return 0 ;; esac
  return 1
}

# kit_progress <actor> <class> <description> [key=value …]
#
# ALWAYS RETURNS 0: a failure to write is not a failure of the caller's work.
kit_progress() {
  local actor="$1" class="$2" desc="$3"; shift 3 2>/dev/null || true

  # THE CLASS IS CLOSED; an unknown one is written as `info` with the offered value in
  # `declared-class=`, never dropped (a dropped record reads as work that never happened).
  local extra=""
  case "$class" in
    status|info|warning|error) ;;
    *) extra="declared-class=$(_pr_tok "$class")"; class="info" ;;
  esac

  # THE ACTOR'S SHAPE IS ENFORCED THE SAME WAY: written as `unknown`, never refused or dropped.
  actor="$(_pr_clean "$actor")"
  if ! _pr_actor_ok "$actor"; then
    extra="declared-actor=$(_pr_tok "$actor")${extra:+ }${extra}"
    actor="unknown"
  fi

  local dir; dir="$(kit_progress_dir)"
  mkdir -p "$dir" 2>/dev/null || return 0
  [ -w "$dir" ] || return 0
  _pr_expire "$dir"

  local ts day
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" || return 0
  day="${ts%%T*}"

  # THE CALLER'S EXTRAS, VERBATIM. Their one-token shape is the caller's obligation
  # (contracts/progress-record.md § Reserved extra keys), deliberately not enforced: enforcing it
  # would rewrite data the caller typed. The declared- keys above are this library's own, so it
  # owes their shape.
  local k run_given=0
  for k in "$@"; do
    [ -n "$k" ] || continue
    case "$k" in run=*) run_given=1 ;; esac
    extra="${extra}${extra:+ }$(_pr_clean "$k")"
  done

  # THE RUN ID is an extra, never a fifth required column. Empty or unset writes no `run=` key
  # at all. An explicit `run=` argument wins over the environment and never produces two keys.
  if [ "$run_given" -eq 0 ] && [ -n "${KIT_PROGRESS_RUN:-}" ]; then
    extra="${extra}${extra:+ }run=$(_pr_tok "$KIT_PROGRESS_RUN")"
  fi

  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$ts" "$actor" "$class" "$(_pr_clean "$desc")" "$extra" \
    >> "$dir/$day.tsv" 2>/dev/null
  return 0
}

# kit_progress_tail [n] — the operator's read, for a person with nothing running but a terminal.
kit_progress_tail() {
  local n="${1:-20}" dir; dir="$(kit_progress_dir)"
  [ -d "$dir" ] || { echo "no progress records under $dir"; return 0; }
  # shellcheck disable=SC2012  # ls is fine here: the names are ISO dates, never odd.
  cat $(ls "$dir"/*.tsv 2>/dev/null | sort) 2>/dev/null | tail -n "$n" \
    | awk -F'\t' '{printf "%s  %-22s %-7s %s%s\n", $1, $2, $3, $4, ($5 != "" ? "  [" $5 "]" : "")}'
  return 0
}
