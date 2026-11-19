# KIT-CLASS: MIXED — self-test harness, the helpers every module case shares. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/lib/modules.sh — sourced by scripts/test/run.sh, never run on its own.
# The sandbox, the snapshot and the runner a case needs to enable a module and look at the tree. They
# live here, not in a case file, because a module ships its own cases (modules/<name>/test/cases/) and a
# case that calls a helper defined in another case file depends on the load order of files it does not
# own. Everything here is a helper: no case is defined.
# =============================================================================

# _ku_have_sha — status 0 when a sha256 tool exists. Enable records one per file and refuses without it.
_ku_have_sha() { command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1; }

# _md_snap <root> — "<sha256>  <path>" for every file but git's, the board mover's worktree and the
# progress records, so two snapshots compare byte for byte.
_md_snap() {
  ( cd "$1" && find . \( -path ./.git -o -path ./.kanban-wt -o -path ./.progress-records \) -prune -o -type f -print \
      | LC_ALL=C sort | while IFS= read -r f; do printf '%s  %s\n' "$(_old_sha "$f")" "$f"; done )
}

# _md_sandbox — a sandbox holding every module the tree ships, the item templates (a fragment is minted
# into them), a PROJECT.md of its own with a gate table and the `gates` slot, and a CORPUS.md with the two corpus slots,
# published. Both documents are fabricated, so an adopter's edited ones are not the operand. Sets _MD_ID, a card the
# role checks can move.
_md_sandbox() {
  make_sandbox
  # modules/ is DELETE-IF-UNUSED: a tree without it gets an empty one, which the cases that fabricate their own modules fill.
  if [ -d "$REAL_REPO_ROOT/modules" ]; then cp -R "$REAL_REPO_ROOT/modules" "$SB_WORK/modules"; else mkdir -p "$SB_WORK/modules"; fi
  if [ -d "$REAL_REPO_ROOT/.claude/templates" ]; then
    mkdir -p "$SB_WORK/.claude"
    cp -R "$REAL_REPO_ROOT/.claude/templates" "$SB_WORK/.claude/templates"
    _kit_neutral_claude
  fi
  # A project that did day one: kit-init's receipt line in config.sh is how enable reads the stamped values.
  printf '\n# Stamped by scripts/kit-init.sh on 2026-01-01 — prefix %s, trunk %s (kit-init.sh --help explains the re-run refusal).\n' "$SB_PREFIX" "$SB_TRUNK" >> "$SB_WORK/scripts/config.sh"
  printf '# PROJECT.md (sandbox)\n\n| Gate | Your command | The contract it implements |\n|---|---|---|\n| g | `x` | y |\n\n<!-- KIT-MODULES:gates the slot -->\n\ntail\n' > "$SB_WORK/PROJECT.md"
  # ...and a CORPUS.md with the two slots a module's corpus rows go above, for the same reason.
  mkdir -p "$SB_WORK/requirements"
  printf '# CORPUS.md (sandbox)\n\n| Entry | Kind | Status | Why it is corpus |\n|---|---|---|---|\n| `DECISIONS.md` | `file` | `present` | the rulings |\n\n<!-- KIT-MODULES:corpus-manifest the slot -->\n\n| Path | Bucket |\n|---|---|\n| `requirements/` | `corpus` |\n\n<!-- KIT-MODULES:corpus-buckets the slot -->\n\ntail\n' > "$SB_WORK/requirements/CORPUS.md"
  _MD_ID="$SB_PREFIX-730"
  seed_issue todo "$_MD_ID" modules chore "A card for the module lifecycle case"
  publish_sandbox
}
# _md_have_example / _md_gone_reason — the shipped template module is a DELETE-IF-UNUSED member; a case
# whose subject it is has none on a tree that deleted it (the reason names the file, as skp_lived requires).
_md_have_example() { [ -f "$REAL_REPO_ROOT/modules/example/module.manifest" ]; }
_md_gone_reason() { printf '%s' "modules/example/module.manifest is absent from this tree"; }
# _md_missing_program — the file a lifecycle case needs and this tree lacks, or nothing. The program is
# shipped with the kit, so its absence is a failure of the case, never an N/A.
_md_missing_program() {
  local f
  for f in scripts/module.sh $(script_libs "$REAL_REPO_ROOT/scripts/module.sh" | sed 's|^|scripts/lib/|'); do
    [ -f "$REAL_REPO_ROOT/$f" ] || { printf '%s' "$f"; return 0; }
  done
  return 0
}
# _md_mod <args…> — scripts/module.sh in the sandbox; sets _md_out and _md_rc. Records go to the
# sandbox's own directory, emptied first, so _md_recs counts this call's refusals and no earlier one's.
_md_rc=0; _md_out=""
_md_mod() { rm -rf "$SB_TMP/records"; _md_rc=0; _md_out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/records" ./scripts/module.sh "$@" 2>&1 </dev/null )" || _md_rc=$?; }
_md_recs() { cat "$SB_TMP"/records/*.tsv 2>/dev/null | grep -c "refusal=$1" || true; }

# _md_make_kill_walk <dir> — kill-walk.sh in <dir>, sourced by the stand-ins written there. kill_marked SIGKILLs the
# process the case MARKED (its pid is in the file $KILL_PID_FILE) and every process between it and the caller. It
# never matches on command text: a process above the marked one that only names a script survives. Status 1, nothing
# killed, when the marked pid is not an ancestor of the caller.
_md_make_kill_walk() {
  cat > "$1/kill-walk.sh" <<'WALK_EOF'
kill_marked() {
  local target pid pids=""
  target="$(cat "${KILL_PID_FILE:-/dev/null}" 2>/dev/null)"
  [ -n "$target" ] || return 1
  pid=$PPID
  while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
    pids="$pids $pid"
    if [ "$pid" = "$target" ]; then
      # shellcheck disable=SC2086
      kill -9 $pids
      return 0
    fi
    pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
  done
  return 1
}
WALK_EOF
}
# A case marks the process under test by starting it as `bash -c 'echo $$ > "$KILL_PID_FILE"; exec "$@"' _ <command…>`:
# the pid written is the command's own, because it is exec'd.

# _md_make_kill_shim — a stand-in for mv, first on PATH when _md_kill_enable runs: when the destination of a
# move ends with $KILL_ON it SIGKILLs the marked process (see _md_make_kill_walk) and the processes below it that
# lead to the move, then itself, so nothing after that move runs (no trap, no cleanup): a hard kill, not a refusal.
# With KILL_SKIP naming a file that holds a count, that many matching moves go through first (the file is counted down).
_md_make_kill_shim() {
  mkdir -p "$SB_TMP/shim"
  cat > "$SB_TMP/shim/mv" <<'MV_EOF'
#!/bin/bash
dest="${@: -1}"
case "$dest" in
  *"${KILL_ON:-@@never@@}")
    if [ -n "${KILL_SKIP:-}" ] && [ -f "$KILL_SKIP" ] && [ "$(cat "$KILL_SKIP")" -gt 0 ]; then
      echo $(( $(cat "$KILL_SKIP") - 1 )) > "$KILL_SKIP"; exec /bin/mv "$@"
    fi
    . "$(dirname "$0")/kill-walk.sh"
    kill_marked || { echo "kill stand-in: the marked process is not an ancestor of this call, so nothing was killed" >&2; exec /bin/mv "$@"; }
    kill -9 $$ ;;
esac
exec /bin/mv "$@"
MV_EOF
  chmod +x "$SB_TMP/shim/mv"
  _md_make_kill_walk "$SB_TMP/shim"
  # ...and the same for mkdir, when the last argument ends with $KILL_MKDIR: a kill at a point no move marks.
  cat > "$SB_TMP/shim/mkdir" <<'MKDIR_EOF'
#!/bin/bash
case "${@: -1}" in
  *"${KILL_MKDIR:-@@never@@}")
    . "$(dirname "$0")/kill-walk.sh"
    kill_marked || { echo "kill stand-in: the marked process is not an ancestor of this call, so nothing was killed" >&2; exec /bin/mkdir "$@"; }
    kill -9 $$ ;;
esac
exec /bin/mkdir "$@"
MKDIR_EOF
  chmod +x "$SB_TMP/shim/mkdir"
}
# _md_kill_tmp — the TMPDIR to give a run the stand-ins may kill: a directory in the sandbox, made here, printed. A
# SIGKILL runs no trap, so the scratch the killed program made under TMPDIR (module.sh's kit-module.*, kit-upgrade.sh's
# kit-upgrade-*.*, marker-block's mktemp files) is never removed by it; in the sandbox, teardown removes it, where in
# the machine's temp directory every run of the self-test would add to what is left there.
_md_kill_tmp() { mkdir -p "$SB_TMP/tmp" && printf '%s' "$SB_TMP/tmp"; }
# _md_kill_enable <destination suffix> [<module>] — enable under that stand-in, with _md_kill_tmp's TMPDIR; the
# status is left in _md_rc.
_md_kill_enable() {
  rm -rf "$SB_TMP/records"
  _md_rc=0
  _md_out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/records" TMPDIR="$(_md_kill_tmp)" PATH="$SB_TMP/shim:$PATH" KILL_ON="$1" KILL_PID_FILE="$SB_TMP/kill-pid" bash -c 'echo $$ > "$KILL_PID_FILE"; exec "$@"' _ ./scripts/module.sh enable "${2:-example}" 2>&1 </dev/null )" || _md_rc=$?
}
# _md_strays <root> — every temporary file a killed run could leave behind, one per line.
_md_strays() { find "$1" -path "$1/.git" -prune -o \( -name '*.kit-mod-new' -o -name '*.kit-mb.*' \) -print 2>/dev/null; }

# _md_make_count_shim — stand-ins for the commands that write (cp mv mkdir rm mktemp chmod), first on PATH when a program
# runs under them: every call that names a path under $KILL_ROOT is counted in the file $KILL_COUNT, and the call whose
# number is $KILL_NTH SIGKILLs the marked process and the processes between it and the call (see _md_make_kill_walk),
# then itself, before it writes. Run with
# KILL_NTH = 1, 2, 3 … to stop a program before each write in turn; a run that is not killed made fewer writes than that.
# A KILL_NTH too large to be reached counts the writes of a run without stopping it, and with $KILL_TRACE naming a file
# each counted call is appended to it as `<number> TAB <command> TAB <arguments>`.
_md_make_count_shim() {
  local c real
  mkdir -p "$SB_TMP/cshim"
  for c in cp mv mkdir rm mktemp chmod; do
    real="$(command -v "$c")"
    cat > "$SB_TMP/cshim/$c" <<'CSHIM_EOF'
#!/bin/bash
hit=0
me="${0##*/}"
for a in "$@"; do
  case "$a" in
    "${KILL_ROOT:-@@none@@}"/*)
      # a call that cannot change anything is no write: rm of a path that is not there, mkdir of a directory that is
      if [ "$me" = rm ] && [ ! -e "$a" ] && [ ! -L "$a" ]; then continue; fi
      if [ "$me" = mkdir ] && [ -d "$a" ]; then continue; fi
      hit=1 ;;
  esac
done
if [ "$hit" = 1 ] && [ -n "${KILL_NTH:-}" ]; then
  n=$(( $(cat "$KILL_COUNT" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$KILL_COUNT"
  [ -z "${KILL_TRACE:-}" ] || printf '%s\t%s\t%s\n' "$n" "$me" "$*" >> "$KILL_TRACE"
  if [ "$n" -eq "$KILL_NTH" ]; then
    . "$(dirname "$0")/kill-walk.sh"
    if kill_marked; then kill -9 $$; fi
    echo "kill stand-in: the marked process is not an ancestor of this call, so nothing was killed" >&2
  fi
fi
exec @REAL@ "$@"
CSHIM_EOF
    sed -i.bak "s|@REAL@|$real|" "$SB_TMP/cshim/$c"; rm -f "$SB_TMP/cshim/$c.bak"
    chmod +x "$SB_TMP/cshim/$c"
  done
  _md_make_kill_walk "$SB_TMP/cshim"
}

# KIT_TEST_KILL_ALL=1 makes every case that kills a program before each of its writes use every write, and every order of
# enabling its fixture offers. Without it a case uses _md_kill_points: the writes that mark a boundary (the first and last,
# each change of the project's top-level path, and the ones on either side of every write to a path the case names), and
# one in every eight, in the first order alone.

# _md_kill_points <trace file> <root> <regex> — the kill points a case runs, one per line, from the trace a counting run
# left (see _md_make_count_shim). <root> is the project the counted run wrote in; <regex> names the paths whose writes the
# case's defects hide behind: a record, a shared file, the checklist. With KIT_TEST_KILL_ALL=1 every write is a point.
_md_kill_points() {
  [ -s "$1" ] || return 0
  if [ -n "${KIT_TEST_KILL_ALL:-}" ]; then awk 'END { for (i = 1; i <= NR; i++) print i }' "$1"; return 0; fi
  KP_ROOT="$2" KP_RE="$3" awk -F'\t' '
    BEGIN { root = ENVIRON["KP_ROOT"] "/"; re = ENVIRON["KP_RE"] }
    { n = $1; last = ""
      m = split($3, a, " ")
      for (i = 1; i <= m; i++) if (index(a[i], root) == 1) last = substr(a[i], length(root) + 1)
      top = last; sub(/\/.*/, "", top)
      if (n > 1 && top != prev) { keep[n - 1] = 1; keep[n] = 1 }
      if (last ~ re) { keep[n - 1] = 1; keep[n] = 1; keep[n + 1] = 1 }
      if (n % 8 == 0) keep[n] = 1
      prev = top; total = n }
    END { keep[1] = 1; keep[total] = 1; for (i = 1; i <= total; i++) if (i in keep) print i }' "$1"
}
