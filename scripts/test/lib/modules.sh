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
# into them) and a PROJECT.md of its own, a gate table and the `gates` slot, published. The PROJECT.md is
# fabricated, so an adopter's edited one is not the operand. Sets _MD_ID, a card the role checks can move.
_md_sandbox() {
  make_sandbox
  cp -R "$REAL_REPO_ROOT/modules" "$SB_WORK/modules"
  if [ -d "$REAL_REPO_ROOT/.claude/templates" ]; then
    mkdir -p "$SB_WORK/.claude"
    cp -R "$REAL_REPO_ROOT/.claude/templates" "$SB_WORK/.claude/templates"
    _kit_neutral_claude
  fi
  # A project that did day one: kit-init's receipt line in config.sh is how enable reads the stamped values.
  printf '\n# Stamped by scripts/kit-init.sh on 2026-01-01 — prefix %s, trunk %s (kit-init.sh --help explains the re-run refusal).\n' "$SB_PREFIX" "$SB_TRUNK" >> "$SB_WORK/scripts/config.sh"
  printf '# PROJECT.md (sandbox)\n\n| Gate | Your command | The contract it implements |\n|---|---|---|\n| g | `x` | y |\n\n<!-- KIT-MODULES:gates the slot -->\n\ntail\n' > "$SB_WORK/PROJECT.md"
  _MD_ID="$SB_PREFIX-730"
  seed_issue todo "$_MD_ID" modules chore "A card for the module lifecycle case"
  publish_sandbox
}
# _md_have_example / _md_gone_reason — the shipped template module is a DELETE-IF-UNUSED member; a case
# whose subject it is has none on a tree that deleted it (the reason names the file, as skp_lived requires).
_md_have_example() { [ -f "$REAL_REPO_ROOT/modules/example/module.manifest" ]; }
_md_gone_reason() { printf '%s' "modules/example/RELEASE-NOTES.md is absent from this tree"; }
# _md_missing_program — the file a lifecycle case needs and this tree lacks, or nothing. The program is
# shipped with the kit, so its absence is a failure of the case, never an N/A.
_md_missing_program() {
  local f
  for f in scripts/module.sh scripts/lib/modules.sh scripts/lib/marker-block.sh; do
    [ -f "$REAL_REPO_ROOT/$f" ] || { printf '%s' "$f"; return 0; }
  done
  return 0
}
# _md_mod <args…> — scripts/module.sh in the sandbox; sets _md_out and _md_rc. Records go to the
# sandbox's own directory, emptied first, so _md_recs counts this call's refusals and no earlier one's.
_md_rc=0; _md_out=""
_md_mod() { rm -rf "$SB_TMP/records"; _md_rc=0; _md_out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/records" ./scripts/module.sh "$@" 2>&1 </dev/null )" || _md_rc=$?; }
_md_recs() { cat "$SB_TMP"/records/*.tsv 2>/dev/null | grep -c "refusal=$1" || true; }

# _md_make_kill_shim — a stand-in for mv, first on PATH when _md_kill_enable runs: when the destination of a
# move ends with $KILL_ON it SIGKILLs every ancestor process running module.sh or kit-upgrade.sh, then itself,
# so nothing after that move runs (no trap, no cleanup): a hard kill, not a refusal. With KILL_SKIP naming a file
# that holds a count, that many matching moves go through first (the file is counted down).
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
    pids=""; pid=$PPID
    while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
      case "$(ps -o command= -p "$pid" 2>/dev/null)" in *module.sh*|*kit-upgrade.sh*) pids="$pids $pid" ;; esac
      pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
    done
    # shellcheck disable=SC2086
    [ -z "$pids" ] || kill -9 $pids
    kill -9 $$ ;;
esac
exec /bin/mv "$@"
MV_EOF
  chmod +x "$SB_TMP/shim/mv"
  # ...and the same for mkdir, when the last argument ends with $KILL_MKDIR: a kill at a point no move marks.
  cat > "$SB_TMP/shim/mkdir" <<'MKDIR_EOF'
#!/bin/bash
case "${@: -1}" in
  *"${KILL_MKDIR:-@@never@@}")
    pids=""; pid=$PPID
    while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
      case "$(ps -o command= -p "$pid" 2>/dev/null)" in *module.sh*|*kit-upgrade.sh*) pids="$pids $pid" ;; esac
      pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
    done
    # shellcheck disable=SC2086
    [ -z "$pids" ] || kill -9 $pids
    kill -9 $$ ;;
esac
exec /bin/mkdir "$@"
MKDIR_EOF
  chmod +x "$SB_TMP/shim/mkdir"
}
# _md_kill_enable <destination suffix> [<module>] — enable under that stand-in; the status is left in _md_rc.
_md_kill_enable() {
  rm -rf "$SB_TMP/records"
  _md_rc=0
  _md_out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/records" PATH="$SB_TMP/shim:$PATH" KILL_ON="$1" ./scripts/module.sh enable "${2:-example}" 2>&1 </dev/null )" || _md_rc=$?
}
# _md_strays <root> — every temporary file a killed run could leave behind, one per line.
_md_strays() { find "$1" -path "$1/.git" -prune -o \( -name '*.kit-mod-new' -o -name '*.kit-mb.*' \) -print 2>/dev/null; }

# _md_make_count_shim — stand-ins for the commands that write (cp mv mkdir rm mktemp chmod), first on PATH when a program
# runs under them: every call that names a path under $KILL_ROOT is counted in the file $KILL_COUNT, and the call whose
# number is $KILL_NTH SIGKILLs every ancestor running module.sh or kit-upgrade.sh, then itself, before it writes. Run with
# KILL_NTH = 1, 2, 3 … to stop a program before each write in turn; a run that is not killed made fewer writes than that.
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
  if [ "$n" -eq "$KILL_NTH" ]; then
    pids=""; pid=$PPID
    while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
      case "$(ps -o command= -p "$pid" 2>/dev/null)" in *module.sh*|*kit-upgrade.sh*) pids="$pids $pid" ;; esac
      pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
    done
    # shellcheck disable=SC2086
    [ -z "$pids" ] || kill -9 $pids
    kill -9 $$
  fi
fi
exec @REAL@ "$@"
CSHIM_EOF
    sed -i.bak "s|@REAL@|$real|" "$SB_TMP/cshim/$c"; rm -f "$SB_TMP/cshim/$c.bak"
    chmod +x "$SB_TMP/cshim/$c"
  done
}
