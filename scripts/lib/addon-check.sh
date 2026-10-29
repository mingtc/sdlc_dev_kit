#!/usr/bin/env bash
# KIT-CLASS: KIT — run an add-on's check from a revision of the project, never from the working tree.
# See process/EXTRACTION.md.
#
# WHY THIS EXISTS: a check that judges a landing or a move takes its rule from the project's TRUNK, not
# from the branch it judges and not from the operator's checkout, so nobody gets past it by editing
# or not pushing it. A check is a file; this library lists the ones a folder holds at a revision, and
# runs one from its bytes at that revision, as a child process that cannot touch the caller's state.
#
#   kit_addon_check_list <repo> <rev> <dir> <key>
#       One line per file directly under <dir>/<key>/ at <rev>, in file-name order, `run<TAB><path>` for
#       a check (`<NN>-<name>.sh`, the name made of letters, digits, `.`, `_` and `-`) and
#       `skip<TAB><path>` for any other file but README.md. Nothing when <rev> or the folder is absent.
#   kit_addon_check_keys <repo> <rev> <dir>
#       The names of the folders directly under <dir>/ at <rev>, one per line.
#   kit_addon_check_run <repo> <rev> <path> [<arg>…]
#       Run the blob <path> of <rev> with bash, in <repo>, stdin closed, <arg>… as its arguments.
#       Returns its status; KIT_ADDON_CHECK_OUT holds what it printed (stdout and stderr). A blob that
#       cannot be read, or a scratch file that cannot be made, returns 70.
#   kit_move_checks <repo> <rev> <id> <from> <to> <role> <card-file>
#       The checks of a board move (scripts/move-check.d/<to>/): refuses through kit_refuse on the first
#       that does not allow it. Called by every script that moves a card, before it changes anything
#       (process/contracts/board-mover.md § 3 names them).
#
# THE CONTRACT OF A CHECK, one for every folder (process/contracts/board-mover.md § 3 for a move,
# landing-gate.md § 3 for a QA cell): status 0 allows, status 3 says "I looked and this is wrong", any
# other status is a check that did not run to an answer. Its printed lines are the reason; a line
# opening `Next: ` is the way on. A check that did not answer refuses as well: a gate that cannot
# answer must not read as armed. A check may print and read; it must not write to the project.
# Bash 3.2.

# shellcheck source=refuse.sh
. "$(dirname "${BASH_SOURCE[0]}")/refuse.sh" || return 1   # return-class: internal

KIT_ADDON_CHECK_OUT=""

# _kit_ac_commit <repo> <rev> — the commit <rev> names, or <rev> as given when it names none.
_kit_ac_commit() {
  git -C "$1" rev-parse --verify --quiet "${2}^{commit}" 2>/dev/null || printf '%s' "$2"
}

kit_addon_check_list() {
  local repo="$1" rev="$2" dir="${3%/}" key="$4" meta path base
  [ -n "$rev" ] || return 0   # return-class: predicate
  git -C "$repo" ls-tree "$rev" "$dir/$key/" 2>/dev/null | while IFS=$'\t' read -r meta path; do
    case "$meta" in "100644 blob "*|"100755 blob "*) ;; *) continue ;; esac
    base="${path##*/}"
    [ "$base" != README.md ] || continue
    case "$base" in
      [0-9][0-9]-*.sh) case "$base" in *[!A-Za-z0-9._-]*) printf 'skip\t%s\n' "$path" ;; *) printf 'run\t%s\n' "$path" ;; esac ;;
      *) printf 'skip\t%s\n' "$path" ;;
    esac
  done
  return 0   # return-class: predicate
}

kit_addon_check_keys() {
  local repo="$1" rev="$2" dir="${3%/}" meta path
  [ -n "$rev" ] || return 0   # return-class: predicate
  git -C "$repo" ls-tree "$rev" "$dir/" 2>/dev/null | while IFS=$'\t' read -r meta path; do
    case "$meta" in *" tree "*) printf '%s\n' "${path##*/}" ;; esac
  done
  return 0   # return-class: predicate
}

kit_addon_check_run() {
  local repo="$1" rev="$2" path="$3" tmp rc=0
  shift 3
  KIT_ADDON_CHECK_OUT=""
  tmp="$(mktemp "${TMPDIR:-/tmp}/kit-addon-check.XXXXXX")" \
    || { KIT_ADDON_CHECK_OUT="could not make a scratch file to run $path from"; return 70; }   # return-class: internal
  if ! git -C "$repo" show "$rev:$path" > "$tmp" 2>/dev/null; then
    rm -f "${tmp:?}"
    KIT_ADDON_CHECK_OUT="could not read $path at $rev"
    return 70   # return-class: internal
  fi
  KIT_ADDON_CHECK_OUT="$( cd "$repo" && bash "$tmp" "$@" </dev/null 2>&1 )" || rc=$?
  rm -f "${tmp:?}"
  return "$rc"   # return-class: relay
}

# _kit_ac_message <output> — set _KIT_AC_BODY (the printed lines but the first `Next: ` one, at most
# twenty, indented) and _KIT_AC_NEXT (the text after that `Next: `, or empty).
_kit_ac_message() {
  local line n=0
  _KIT_AC_BODY=""; _KIT_AC_NEXT=""
  while IFS= read -r line; do
    line="${line%$'\r'}"
    [ -n "$line" ] || continue
    if [ -z "$_KIT_AC_NEXT" ]; then
      case "$line" in "Next: "?*) _KIT_AC_NEXT="${line#Next: }"; continue ;; esac
    fi
    n=$((n + 1))
    [ "$n" -le 20 ] || continue
    _KIT_AC_BODY="${_KIT_AC_BODY}${_KIT_AC_BODY:+$'\n'}    $line"
  done <<AC_EOF
$1
AC_EOF
  return 0   # return-class: predicate
}

kit_move_checks() {
  local repo="$1" rev id="$3" from="$4" to="$5" role="$6" card="$7"
  local listing kind path rc line name next_text
  local -a body
  rev="$(_kit_ac_commit "$repo" "$2")"
  listing="$(kit_addon_check_list "$repo" "$rev" scripts/move-check.d "$to")"
  while IFS=$'\t' read -r kind path; do
    [ -n "$kind" ] || continue
    if [ "$kind" = skip ]; then
      echo "Note: $path is not run — a move check is named <NN>-<name>.sh (letters, digits, '.', '_' and '-')." >&2
      continue
    fi
    rc=0
    kit_addon_check_run "$repo" "$rev" "$path" "$id" "$from" "$to" "$role" "$card" "$repo" "$rev" || rc=$?
    case "$rc" in 0) continue ;; esac
    _kit_ac_message "$KIT_ADDON_CHECK_OUT"
    body=()
    while IFS= read -r line; do [ -z "$line" ] || body+=("$line"); done <<BODY_EOF
$_KIT_AC_BODY
BODY_EOF
    if [ "$rc" -eq 3 ]; then
      next_text="$_KIT_AC_NEXT"
      [ -n "$next_text" ] || next_text="the check gave no next step: read the reason above and clear it, or ask whoever owns $path. Removing that file from the trunk lifts the check."
      kit_refuse 1 move-check-refused \
        "Error: ${id} cannot move to ${to}/ — the move check ${path} refused it:" \
        ${body[@]+"${body[@]}"} \
        "Next: ${next_text}" \
        "      NOTHING WAS CHANGED."
    fi
    next_text="$_KIT_AC_NEXT"
    [ -n "$next_text" ] || next_text="read what it printed above, and its code (git show ${rev}:${path}). A defective check is its owner to fix; removing the file from the trunk lifts it."
    kit_refuse 1 move-check-broken \
      "Error: ${id} cannot move to ${to}/ — the move check ${path} did not run to an answer (status ${rc}; it must exit 0 to allow or 3 to refuse), so the move was not judged:" \
      ${body[@]+"${body[@]}"} \
      "Next: ${next_text}" \
      "      NOTHING WAS CHANGED."
  done <<LIST_EOF
$listing
LIST_EOF
  # A folder that is no status folder is read by no move: say so, since its check would never run.
  if [ -n "${KIT_STATUS_FOLDERS:-}" ]; then
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      case "|${KIT_STATUS_FOLDERS}|" in *"|${name}|"*) ;; *) echo "Note: scripts/move-check.d/${name}/ names no status folder (${KIT_STATUS_FOLDERS//|/, }), so no move reads it." >&2 ;; esac
    done <<KEYS_EOF
$(kit_addon_check_keys "$repo" "$rev" scripts/move-check.d)
KEYS_EOF
  fi
  return 0   # return-class: predicate
}
