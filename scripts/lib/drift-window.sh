#!/usr/bin/env bash
# KIT-CLASS: KIT — the drift window and the drift-acknowledgement record. See process/EXTRACTION.md.
#
# The history arms of scripts/check-board.sh ([e], [h], [e2]) and scripts/drift-ack.sh read the same
# window and the same record, so both come from here, once.
#
# THE WINDOW. Every commit after the rule's epoch (the commit that ADDED scripts/githooks/commit-msg),
# else the last <scan-n> commits; a shallow clone derives no epoch. kit_drift_window sets:
#   KIT_DW_EPOCH     the epoch commit, or empty
#   KIT_DW_SHALLOW   `yes` on a shallow clone
#   KIT_DW_INSCOPE   with an epoch: the epoch's descendants up to the rev, one sha per line
#   KIT_DW_LOG_ARGS  the `git log` arguments that walk the window (an array)
#   KIT_DW_PRE       commits at or before the epoch, which are not read
#
# THE RECORD, progress/drift-acknowledged.tsv: a header row, then one row per acknowledged commit,
# tab-separated `sha role date reason`. scripts/drift-ack.sh is the only writer; each of its commits
# appends exactly one row, to that file alone, under the subject `[<Role>] drift-ack: <12 hex>`.
# kit_drift_ack_edits finds every commit that touched the file in any other way.

KIT_DRIFT_ACK_PATH="progress/drift-acknowledged.tsv"
KIT_DRIFT_ACK_HEADER="$(printf 'sha\trole\tdate\treason')"

# kit_drift_window <repo> <rev> <scan-n>
kit_drift_window() {
  local repo="$1" rev="$2" n="$3"
  KIT_DW_EPOCH=""; KIT_DW_SHALLOW=""; KIT_DW_INSCOPE=""; KIT_DW_PRE=0
  if [ "$(git -C "$repo" rev-parse --is-shallow-repository 2>/dev/null || echo false)" = "true" ]; then
    KIT_DW_SHALLOW="yes"
  elif git -C "$repo" rev-parse --verify --quiet "$rev" >/dev/null 2>&1; then
    KIT_DW_EPOCH="$( { git -C "$repo" log --diff-filter=A --format=%H "$rev" \
                       -- scripts/githooks/commit-msg 2>/dev/null || true; } | tail -1 )"
  fi
  KIT_DW_LOG_ARGS=(-n "$n" "$rev")
  if [ -n "$KIT_DW_EPOCH" ]; then
    KIT_DW_INSCOPE="$(git -C "$repo" rev-list --ancestry-path "$KIT_DW_EPOCH..$rev" 2>/dev/null || true)"
    KIT_DW_LOG_ARGS=("$KIT_DW_EPOCH..$rev")
    KIT_DW_PRE="$(git -C "$repo" rev-list --count "$KIT_DW_EPOCH" 2>/dev/null || echo 0)"
  fi
  return 0
}

# kit_drift_window_shas <repo> <rev> — the commits the arms judge: the epoch's descendants, or the
# last commits of the window when there is no epoch. Run kit_drift_window first.
kit_drift_window_shas() {
  if [ -n "$KIT_DW_EPOCH" ]; then
    printf '%s\n' "$KIT_DW_INSCOPE"
  else
    git -C "$1" rev-list "${KIT_DW_LOG_ARGS[@]}" 2>/dev/null || true
  fi
}

# kit_drift_ack_candidates <repo> <rev> — the shas an acknowledgement may name: the window's commits
# and, for a merge in it, its second parent (the squashed subject [e] reports under).
kit_drift_ack_candidates() {
  local shas
  shas="$(kit_drift_window_shas "$1" "$2")"
  [ -n "$shas" ] || return 0
  printf '%s\n' "$shas"
  git -C "$1" rev-list --parents --no-walk --stdin <<< "$shas" 2>/dev/null | awk 'NF >= 3 { print $3 }'
}

# kit_drift_ack_read <repo> <rev> — the acknowledged rows at <rev>, header left out.
kit_drift_ack_read() {
  git -C "$1" show "$2:$KIT_DRIFT_ACK_PATH" 2>/dev/null | awk -F'\t' 'NR > 1 && NF >= 4 && $1 != "" { print }' || true
}

# kit_drift_ack_find <rows> <sha>… — prints the first row whose sha is one of the arguments.
kit_drift_ack_find() {
  local rows="$1" c row; shift
  [ -n "$rows" ] || return 0
  for c in "$@"; do
    [ -n "$c" ] || continue
    row="$(awk -F'\t' -v s="$c" '$1 == s { print; exit }' <<< "$rows")"
    if [ -n "$row" ]; then printf '%s\n' "$row"; return 0; fi
  done
  return 0
}

# kit_drift_ack_line <arm> <row> — the one line every reader prints for an acknowledged commit; the
# release gate relays the lines that carry `drift-acknowledged:`.
kit_drift_ack_line() {
  local arm="$1" sha role date reason
  IFS=$'\t' read -r sha role date reason <<< "$2"
  printf '    drift-acknowledged: %s [%s] by %s on %s — %s\n' "${sha:0:9}" "$arm" "$role" "$date" "$reason"
}

# kit_drift_ack_edits <repo> <rev> <role-set> — one line per commit in the window that touched the
# record and is not drift-ack.sh's: `<full sha>`, a tab, why. A drift-ack.sh commit has the subject
# `[<Role>] drift-ack: <12 hex>` of a role in <role-set>, changes that file alone, and appends exactly
# one row (the header with it, when it creates the file) that begins with the subject's sha and role.
# A merge is judged by its lines: each line of the file it leaves must exist in one of its parents.
kit_drift_ack_edits() {
  local repo="$1" rev="$2" roles="$3" window c parents p1 np subj hex role added deleted files last why want
  window="$(kit_drift_window_shas "$repo" "$rev")"
  window=$'\n'"$window"$'\n'
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    case "$window" in *$'\n'"$c"$'\n'*) ;; *) continue ;; esac
    why=""
    parents="$(git -C "$repo" rev-list --parents -n 1 "$c" 2>/dev/null)"
    set -- $parents
    np=$(( $# - 1 )); p1="${2:-}"
    if [ "$np" -ge 2 ]; then
      shift
      if [ -n "$(comm -23 <(git -C "$repo" show "$c:$KIT_DRIFT_ACK_PATH" 2>/dev/null | sort -u) \
                         <(for p in "$@"; do git -C "$repo" show "$p:$KIT_DRIFT_ACK_PATH" 2>/dev/null; done | sort -u))" ]; then
        why="a merge that leaves a line none of its parents holds"
      fi
    else
      subj="$(git -C "$repo" log -1 --format=%s "$c" 2>/dev/null)"
      hex="$(printf '%s' "$subj" | sed -n 's/^\[[A-Za-z][A-Za-z0-9_-]*\] drift-ack: \([0-9a-f]\{12\}\)$/\1/p')"
      role="$(printf '%s' "$subj" | sed -n 's/^\[\([A-Za-z][A-Za-z0-9_-]*\)\] drift-ack: [0-9a-f]\{12\}$/\1/p')"
      files="$(git -C "$repo" diff-tree --no-commit-id --name-only -r --root "$c" 2>/dev/null)"
      read -r added deleted _ <<< "$(git -C "$repo" diff-tree --no-commit-id --numstat -r --root "$c" -- "$KIT_DRIFT_ACK_PATH" 2>/dev/null)"
      want=2
      [ -z "$p1" ] || ! git -C "$repo" cat-file -e "$p1:$KIT_DRIFT_ACK_PATH" 2>/dev/null || want=1
      last="$(git -C "$repo" show "$c:$KIT_DRIFT_ACK_PATH" 2>/dev/null | tail -1)"
      if [ -z "$hex" ]; then
        why="its subject is not '[<Role>] drift-ack: <12 hex>'"
      elif [ -n "$roles" ] && case "|$roles|" in *"|$role|"*) false ;; *) true ;; esac; then
        why="its role '$role' is not in the declared role set"
      elif [ "$files" != "$KIT_DRIFT_ACK_PATH" ]; then
        why="it changes more than the record"
      elif [ "${deleted:-x}" != 0 ] || [ "${added:-x}" != "$want" ]; then
        why="it does not append exactly one row (${added:-?} added, ${deleted:-?} removed)"
      else
        case "$last" in
          "$hex"*"$(printf '\t')$role$(printf '\t')"*) ;;
          *) why="the row it appends does not name the sha and role its subject names" ;;
        esac
      fi
    fi
    [ -z "$why" ] || printf '%s\t%s\n' "$c" "$why"
  done < <(git -C "$repo" rev-list --full-history --reverse "$rev" -- "$KIT_DRIFT_ACK_PATH" 2>/dev/null)
  return 0
}
