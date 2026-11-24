# KIT-CLASS: MIXED — self-test harness, the install smoke cases. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/smoke.sh — sourced by scripts/test/run.sh, never run on its own.
# The cases an install must pass on their own, and the helpers they call: the loose list in run.sh's
# CASES names them. Every other case is listed in scripts/test/CASE-LIST.
# =============================================================================

REAL_HEAD_BEFORE=""; REAL_STATUS_BEFORE=""; REAL_RECORDS_BEFORE=""
ISSUE_TEMPLATE_REL='.claude/templates/ISSUE.template.md'
ISSUE_TEMPLATE_ABSENT="$ISSUE_TEMPLATE_REL absent (copy-list incomplete)"
KU_CHECKLIST_REL='process/UPGRADE-CHECKLIST.md'

_cb_g_section() {  # reads a check-board report on stdin
  awk '/^\[g\]/ { f = 1 }
       f && /^──/ { exit }
       f && /^\[[a-z]\]/ && !/^\[g\]/ { exit }
       f'
}

# _cb_g_declare_empty_seams — declares $SB_WORK/scripts/config.sh's CODE_GLOBS and TEST_GLOBS
# deliberately empty (the `# DECLARED EMPTY —` mechanical form). Every case that graduates the
# sandbox (fills PROJECT.md, replaces AGENTS.md/README.md) needs this too, or [g]'s new
# CODE_GLOBS/TEST_GLOBS members report unfilled and graduation never reads COMPLETE (which also
# needs `_cb_g_land_day_one_work`: a PRD and a card past QA) — the same transition
# case_check_board_graduation exercises directly; the callers here only need [g] clear, not the
# glob content itself. ONE caller, not three copies: _fixture_die names which
# anchor moved if either does not match.
_cb_g_declare_empty_seams() {
  local _arr
  for _arr in CODE_GLOBS TEST_GLOBS; do
    _cb_g_fill_glob_array "$_arr" "  # DECLARED EMPTY -- fixture ($_arr)."
  done
}

# _cb_g_fill_glob_array <array-name> <entry-line> — the ONE authoring site for inserting a line
# (a real glob entry, or a `# DECLARED EMPTY —` sentinel) right after an array's opening paren in
# $SB_WORK/scripts/config.sh. Shared by every case exercising CODE_GLOBS/TEST_GLOBS, so a moved
# anchor is caught once, not per call site.
_cb_g_fill_glob_array() {
  local _arr="$1" _entry="$2" _cfg="$SB_WORK/scripts/config.sh"
  grep -qE "^${_arr}=\($" "$_cfg" \
    || _fixture_die "_cb_g_fill_glob_array: no '^${_arr}=(' line in the sandbox's scripts/config.sh — the anchor moved."
  perl -i -pe 'BEGIN{$c=0; $a=shift; $e=shift} if (!$c && /^\Q$a\E=\($/) { $_ .= "$e\n"; $c=1 }' \
    "$_arr" "$_entry" "$_cfg"
  grep -qxF "$_entry" "$_cfg" \
    || _fixture_die "_cb_g_fill_glob_array: ${_arr}'s entry was NOT inserted."
}

# _cb_g_discharge_gitignore_env — fills $SB_WORK/.gitignore's build-artifact section and
# $SB_WORK/.env.example's credentials block with a minimal real entry, clearing their `FILL ME.`
# sentinel. make_sandbox never seeds either (the real kit ships both, filled, on day one), so a
# case that graduates the sandbox needs this too, or [g]'s FILL (.gitignore)/(.env.example)
# members read ABSENT — unmeasured, never clean — and graduation never reaches COMPLETE.
_cb_g_discharge_gitignore_env() {
  printf '# .gitignore\n# ── build artifacts ──\n# produced by this fixture build\ndist/\n' \
    > "$SB_WORK/.gitignore"
  printf '# .env.example\n# ── project credentials ──\n# READ_TOKEN=   # read-only\n' \
    > "$SB_WORK/.env.example"
}

# _cb_g_seed_prd / _cb_g_seed_landed_card <folder> — the day-one work arm [g] asks for (SEED steps 6
# and 7), one half each: a file matching the PRD surface, and one card in the named column. The PRD
# glob is written out here, never read from check-board.sh (a fixture that derives its operand from
# the arm it judges agrees with it by construction); the card goes through seed_issue, the harness's
# one card writer.
_cb_g_seed_prd() {
  mkdir -p "$SB_WORK/requirements"
  printf '# PRD-001 — fixture product\n\nOne spec, scoped on day one.\n' > "$SB_WORK/requirements/PRD-001-fixture.md"
}

_cb_g_seed_landed_card() {  # <qa_complete|done>
  seed_issue "$1" "$SB_PREFIX-899" day-one-card chore "The first card through the boundary"
}

# _cb_g_discharge_delete_if_unused — records a KEPT-ON-PURPOSE decision in
# $SB_WORK/process/LOCAL-PROCEDURES.md for every file the sandbox carries that declares
# KIT-DISPOSITION: DELETE-IF-UNUSED, in arm [g]'s own exact form. make_sandbox copies the REAL
# scripts/ tree (so every script that declares the marker arrives carrying it) and conditionally the real consumers/ tree; every case that graduates the sandbox needs
# this too, or [g]'s new DELETE-IF-UNUSED class reports unfilled and graduation never reads
# COMPLETE — the same transition case_check_board_graduation exercises directly, mirroring
# _cb_g_declare_empty_seams for CODE_GLOBS/TEST_GLOBS above. DERIVED from the sandbox's own
# markers, never a literal copy of the member list: a member added or dropped from the real kit
# changes what this discharges without this helper having to change to match.
_cb_g_discharge_delete_if_unused() {
  local _decl='^[[:space:]]*(#|<!--|//|--)?[[:space:]]*KIT-DISPOSITION:[[:space:]]*DELETE-IF-UNUSED([^A-Za-z0-9_]|$)'
  mkdir -p "$SB_WORK/process"
  [ -f "$SB_WORK/process/LOCAL-PROCEDURES.md" ] || printf '# LOCAL-PROCEDURES.md\n\n' > "$SB_WORK/process/LOCAL-PROCEDURES.md"
  local _f _n=0
  while IFS= read -r -d '' _f; do
    [ -f "$SB_WORK/$_f" ] || continue
    sed -n '1,12p' "$SB_WORK/$_f" | grep -E "$_decl" >/dev/null || continue
    printf -- '- **`%s` (DELETE-IF-UNUSED) kept, on purpose.** Fixture discharge.\n' "$_f" >> "$SB_WORK/process/LOCAL-PROCEDURES.md"
    _n=$((_n+1))
  # --untracked: this helper may run before the sandbox's first commit (a case that discharges
  # before its first publish_sandbox), when the copied scripts/notify*.sh are not yet tracked —
  # a plain `git grep` sees only tracked files and would find nothing on such a tree.
  done < <(git -C "$SB_WORK" grep --untracked -lzE "$_decl" -- 2>/dev/null || true)
  # Nothing to discharge is right only on a tree whose every DELETE-IF-UNUSED member was removed.
  [ "$_n" -gt 0 ] || _delete_if_unused_members_all_removed \
    || _fixture_die "_cb_g_discharge_delete_if_unused: no file in the sandbox declares KIT-DISPOSITION: DELETE-IF-UNUSED — the real scripts/notify*.sh marker this helper relies on has moved or been removed."
}

# Run the SANDBOX copy of check-board.sh with CLAUDE_PROJECT_DIR unset: inherited, it would point
# the copy at the REAL board.
cb_run() { ( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR "$SB_WORK/scripts/check-board.sh" --full "$@" 2>&1 ); }

# cb_default_seam <VAR_NAME> — for the OTHER shape a default takes, the repointable-seam form
# `NAME="${NAME:-path}"` (DQ_FILE, CORPUS_FILE): cb_default's quoting does not match it.
cb_default_seam() {  # <VAR_NAME>
  sed -n "s/^$1=\"\\\${$1:-\\([^}\"]*\\)}\".*/\\1/p" "$REAL_SCRIPTS/check-board.sh" 2>/dev/null | head -1
}

# THE SPAN IS THE WHOLE TREE, minus the harness's own directory: the harness reads far more
# of the real tree than scripts/ and progress/, and a narrower span cannot see a write to
# what it reads. scripts/test/ is excluded as the harness's own home. The comparison is a
# DELTA, so a tree already dirty at t0 is not a finding.
_board_status() {
  git -C "$REAL_REPO_ROOT" status --porcelain 2>/dev/null \
    | grep -v ' scripts/test/' || true
}

# The real project's progress records: names and bytes, from the directory the kit's own
# resolver names with no override. The directory is gitignored, so git cannot see a write there.
_real_records() {
  local d f
  d="$( cd "$REAL_REPO_ROOT" && unset KIT_PROGRESS_DIR && . "$REAL_SCRIPTS/lib/progress-record.sh" && kit_progress_dir )" || d=""
  [ -n "$d" ] || { printf '(records directory not resolved)'; return 0; }
  for f in "$d"/*; do
    [ -f "$f" ] || continue
    printf '== %s\n' "$f"; cat "$f"
  done
  return 0
}

isolation_snapshot() {
  REAL_RECORDS_BEFORE="$(_real_records)"
  REAL_HEAD_BEFORE="$(git -C "$REAL_REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "(no HEAD yet)")"
  REAL_STATUS_BEFORE="$(_board_status)"
}

has_issue_template() { [ -f "$REAL_REPO_ROOT/$ISSUE_TEMPLATE_REL" ]; }

has_kit_init() { [ -f "$REAL_SCRIPTS/kit-init.sh" ]; }

kit_init_sandbox() {   # [work_subdir] — passed to make_sandbox
  make_sandbox "$@"
  mkdir -p "$SB_WORK/.claude"
  if [ -d "$REAL_REPO_ROOT/.claude/templates" ]; then
    cp -R "$REAL_REPO_ROOT/.claude/templates" "$SB_WORK/.claude/templates"
  fi
  # The role docs are in the substitution pass; copying them gives the census an operand.
  if [ -d "$REAL_REPO_ROOT/.claude/roles" ]; then
    cp -R "$REAL_REPO_ROOT/.claude/roles" "$SB_WORK/.claude/roles"
  fi
  # Then take the adopter's stamp back out, as make_sandbox does for scripts/. After BOTH
  # copies: the neutralizer walks all of .claude/, so a call between them leaves the role docs
  # stamped.
  _kit_neutral_claude
  # A day-one tree has no session hat: kit-init's own commits must declare theirs.
  sandbox_hat_clear
}

_old_sha() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" 2>/dev/null | awk '{print $1}'; fi
}

# =============================================================================
# CASE — A MOVE TO qa_complete THAT NO finish-pr.sh LANDING VOUCHES FOR RUNS THE GATE ON THE TRUNK TIP.
#
# Two documented routes put a change on the trunk without the landing gate: QA's by-hand squash-merge and
# the direct-to-trunk close. The mover then ran only the QA Verdict check, so a red trunk reached qa_complete/
# with exit 0. A move to qa_complete/ with no verified --landed-at now runs the trunk's committed
# `verify.sh --quick`, in a fresh detached worktree at the trunk tip, and refuses on a red (1), on a runner
# that did not run (2) and on a gate that could not run (3), each named apart, with the move undone.
#
# THE FIXTURE: a real gate on the trunk, red exactly when marker.txt reads `red`. The harness defaults the
# mover's test seam ON (MOVE_ISSUE_TEST_ALLOW_STUB=1, MOVE_ISSUE_GATE_CMD=true) so the cases that only need a
# card to move stay about their own subject; every row here runs the mover with both unset (_mvg_run) unless it
# is the row about the seam. Rows: (a) a branch card landed by hand on a red trunk; (b) a branchless card closed
# direct on a red trunk; (c) the green control moves, and the refused card of (a) moves once the trunk is fixed;
# (d) a command in MOVE_ISSUE_GATE_CMD without the allow flag is ignored (the red still refuses); (e) with the
# flag, the seam's exit statuses 1, 2 and 3 are refused apart and `true` moves the card and says STUB.
# RED FIRST: on a mover with no such check, (a) and (b) move the card. Ablation: the call removed from a
# copy of the mover, committed to the sandbox trunk (a lander runs only the trunk's own copy), must let (f)'s
# red-trunk card through.
# =============================================================================
_mvg_run() {   # <id> [VAR=value…] — the mover to qa_complete, the harness's seam OFF unless the caller sets it. Sets MVG_OUT, MVG_RC.
  local id="$1"; shift
  MVG_OUT="$( cd "$SB_WORK" && env -u MOVE_ISSUE_GATE_CMD -u MOVE_ISSUE_TEST_ALLOW_STUB "$@" ./scripts/move-issue.sh "$SB_PREFIX-$id" qa_complete --role QA --note "review" 2>&1 )"; MVG_RC=$?
}

# =============================================================================
# CASE — EVERY SHIPPED MODULE READS AS A MODULE: ITS MANIFEST NAMES ITS DIRECTORY, IT HAS A ROW IN THE MODULES INDEX,
# AND IT ENABLES AND DISABLES BACK TO THE BYTES IT FOUND.
#   Derived from modules/*/module.manifest, so a module added later is judged without a case of its own for this.
# =============================================================================
# _md_tool_here <requirement id> — status 0 when the tool is on PATH; python3 also needs 3.9 or later (the floor the shipped modules ask), so an
# older python behind the name counts as absent.
_md_tool_here() {
  command -v "$1" >/dev/null 2>&1 || return 1
  [ "$1" != python3 ] || python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' >/dev/null 2>&1
}

# _gates_blank_commands <file> — <file>'s content with the COMMAND field of every verify.sh
# `GATES=( … )` record blanked, everything else byte-identical (line count and line numbers
# untouched, so a hit found elsewhere in the same file still cites its real line). The command
# is the ADOPTER's; only the array's declared record shape (`"<name>|<class>|<command>"`) is
# read, bounded by the literal `GATES=(` … `)` lines — never a loose pattern that could also
# blank kit code outside that array. The command cannot itself contain `"` (kit-init refuses
# one), so the FIRST `"` after the second `|` closes it; anything past that quote, including a
# trailing `# comment`, passes through untouched.
_gates_blank_commands() {  # <file>
  awk '
    /^GATES=\($/ { ingates=1; print; next }
    ingates && /^\)[[:space:]]*$/ { ingates=0; print; next }
    ingates {
      if (match($0, /^[[:space:]]*"[^"|]*\|[^"|]*\|/)) {
        pre = substr($0, 1, RLENGTH); rest = substr($0, RLENGTH + 1)
        if (match(rest, /"/)) {
          print pre "<gates-command-excluded>" substr(rest, RSTART); next
        }
      }
      print; next
    }
    { print }
  ' "$1"
}

# _floor_hits <word> <root> <file>… — command-position hits of <word> across <file>…, one per
# line as "<file rel to root>:<line>: <text>" when more than one file is given, else "<line>:
# <text>". ONE DEFINITION, shared by the case below and its own test: COMMAND POSITION, not mere
# appearance (`echo "… a node id …"` mentions node and does not invoke it); the leading
# `VAR=value ` group is there because the shipped idiom for passing a value safely is exactly
# `PLAN="$PLAN" perl …`.
_floor_hits() {  # <word> <root> <file>…
  local w="$1" root="$2"; shift 2
  awk -v w="$w" -v many="$#" -v root="$root" '
    /^[[:space:]]*#/ { next }
    $0 ~ ("(^|[;&|(]|\\$\\()[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*" w "([[:space:]]|$)") { print (many > 1 ? substr(FILENAME, length(root) + 2) ":" : "") FNR ": " substr($0,1,70) }
  ' "$@" 2>/dev/null || true
}

# _ku_sha <file> — the sha256 the build writes into a manifest, or nothing without a tool.
_ku_sha() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  fi
}

# _ku_manifest <dir> — write <dir>/process/KIT-MANIFEST over every file in <dir>, as the build does.
_ku_manifest() {
  local d="$1" rel
  printf '# KIT-CLASS: KIT — the shipped manifest (a test fixture).\n' > "$d/process/KIT-MANIFEST"
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    [ "$rel" = process/KIT-MANIFEST ] && continue
    printf '%s  %s  %s\n' "$(_ku_sha "$d/$rel")" "$rel" "-" >> "$d/process/KIT-MANIFEST"
  done <<KU_MAN_EOF
$(cd "$d" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)
KU_MAN_EOF
}

# The notes both kits carry. [0.1.0]'s item must never be listed from a 0.1.0 tree; [Unreleased]'s
# only for a target that is a build between releases.
_ku_notes() {
  cat <<'KU_NOTES_EOF'
# The process kit — release notes

## How versions work

Nothing here is an item.

- **Not an item: outside every Action required block.**

## [Unreleased]

### Action required

- **Unreleased item U1.** Do the unreleased thing.

### Added

- **Not an item: under Added.**

## [0.2.0] — 2026-01-02

### Added

- **Not an item either.**

### Action required

- **Item two-one.** Do the first thing.
  A continuation line, not an item.

- **Item two-two, whose bold
  wraps onto the next line.** Do the second thing.

### Changed

- **Not an item: under Changed.**

## [0.1.0] — 2026-01-01

### Action required

- **Old item.** Already applied by any 0.1.0 tree.
KU_NOTES_EOF
}

# _ku_kit <dir> <version> <old|new> — one fabricated kit. The NEW kit carries the script under
# test and the libraries it sources; the old one predates it, as every 0.6.0 tree does.
_ku_kit() {
  local d="$1" v="$2" which="$3"
  mkdir -p "$d/process"
  printf '%s\n' "$v" > "$d/process/KIT-VERSION"
  _ku_notes > "$d/process/KIT-RELEASE-NOTES.md"
  if [ "$which" = old ]; then
    printf 'a1\n' > "$d/a.txt"; printf 'b1\n' > "$d/b.txt"; printf 'c1\n' > "$d/c.txt"
    printf 'd1\n' > "$d/d.txt"; mkdir -p "$d/sub"; printf 'f1\n' > "$d/sub/f.txt"
  else
    printf 'a2\n' > "$d/a.txt"; printf 'b2\n' > "$d/b.txt"
    printf 'd1\n' > "$d/d.txt"; printf 'e1\n' > "$d/e.txt"
    mkdir -p "$d/sub"; printf 'f2\n' > "$d/sub/f.txt"; printf 'g1\n' > "$d/sub/g.txt"
    mkdir -p "$d/scripts/lib"
    cp "$REAL_SCRIPTS/kit-upgrade.sh" "$d/scripts/" 2>/dev/null
    local l
    # The list is the script's own unconditional source lines; progress-record.sh is read by refuse.sh.
    for l in progress-record.sh $(sed -n 's/^\. "\$SCRIPT_DIR\/lib\/\([^"]*\)"$/\1/p' "$REAL_SCRIPTS/kit-upgrade.sh" 2>/dev/null); do
      cp "$REAL_SCRIPTS/lib/$l" "$d/scripts/lib/" 2>/dev/null
    done
  fi
  _ku_manifest "$d"
}

# _ku_target <dir> <old kit dir> — an adopted tree: the old kit, committed, then the adopter's
# own edits committed (b.txt and d.txt edited, sub/ removed). Clean when it returns.
_ku_target() {
  local t="$1" old="$2"
  mkdir -p "$t"
  cp -R "$old/." "$t/"
  git init -q "$t"
  git -C "$t" config user.email "test@sandbox.invalid"
  git -C "$t" config user.name "Sandbox Test"
  git -C "$t" config commit.gpgsign false
  git -C "$t" add -A && git -C "$t" commit -qm "kit, as shipped"
  printf 'b1 mine\n' > "$t/b.txt"; printf 'd1 mine\n' > "$t/d.txt"; rm -rf "$t/sub"
  git -C "$t" add -A && git -C "$t" commit -qm "local law"
}

# _ku_pair <old version> <new version> — sets KU_OLD, KU_NEW, KU_T (the target) and KU_ELSE (a
# directory outside every tree, which each run is made from). Needs make_sandbox's SB_TMP.
_ku_pair() {
  KU_OLD="$SB_TMP/kit-old"; KU_NEW="$SB_TMP/kit-new"; KU_T="$SB_TMP/project"; KU_ELSE="$SB_TMP/elsewhere"
  rm -rf "$KU_OLD" "$KU_NEW" "$KU_T" "$KU_ELSE"
  mkdir -p "$KU_ELSE"
  _ku_kit "$KU_OLD" "$1" old
  _ku_kit "$KU_NEW" "$2" new
  _ku_target "$KU_T" "$KU_OLD" >/dev/null 2>&1
}

# _ku_run <tag> <args…> — run the NEW kit's copy from KU_ELSE, with no project directory in the
# environment; stdout+stderr and status land in $SB_TMP/<tag>.out / .rc.
_ku_run() {
  local tag="$1" rc=0; shift
  ( cd "$KU_ELSE" && env -u CLAUDE_PROJECT_DIR -u KIT_PROGRESS_DIR ${KU_RECDIR:+KIT_PROGRESS_DIR="$KU_RECDIR"} "$KU_NEW/scripts/kit-upgrade.sh" "$@" ) \
    >"$SB_TMP/$tag.out" 2>&1 || rc=$?
  printf '%s' "$rc" > "$SB_TMP/$tag.rc"
}

_ku_rc()  { cat "$SB_TMP/$1.rc"; }

_ku_out() { tr '\n' '|' < "$SB_TMP/$1.out" | cut -c1-300; }

# _ku_subject_or_fail <finish line> — the script under test must ship; its absence is a FAIL.
_ku_subject_or_fail() {
  [ -f "$REAL_SCRIPTS/kit-upgrade.sh" ] && return 0
  cf "scripts/kit-upgrade.sh is not in this kit — there is nothing that takes a newer kit into an adopted tree"
  finish "$1"; teardown
  return 1
}

# =============================================================================
# POST-INIT, THE KIT-CLASS MARKERS ARE INTACT — not rewritten and not deleted
# =============================================================================
# Both directions, because either alone passes on a tree whose markers were deleted: "no
# <PREFIX>-CLASS" holds with no marker at all, and "KIT-CLASS present" holds if one file kept it.
# The defect guarded: the prefix substitution rewriting the marker KEY (SBX-CLASS).
case_kit_init_markers_intact() {
  cf_reset
  if ! has_kit_init; then skp "kit-init: KIT-CLASS markers survive the stamp" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "kit-init: KIT-CLASS markers survive the stamp" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  # kit-init needs a prepared .claude/ and a published trunk; a bare make_sandbox exits 1 with
  # no output, which reads as a defect in the subject.
  kit_init_sandbox
  publish_sandbox

  local out rc
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { cf "kit-init exited $rc: $out"; finish "kit-init: KIT-CLASS markers survive the stamp"; teardown; return; }

  local dirs=() d
  for d in "$SB_WORK/.claude/templates" "$SB_WORK/.claude/roles"; do [ -d "$d" ] && dirs+=("$d"); done
  [ "${#dirs[@]}" -gt 0 ] || cf "neither .claude/templates nor .claude/roles exists post-init — the assertion has no operand"

  if [ "${#dirs[@]}" -gt 0 ]; then
    # DIRECTION 1 — the marker is still THERE. Catches deletion, and catches a rewrite.
    local kept; kept="$(grep -rl 'KIT-CLASS' "${dirs[@]}" 2>/dev/null | wc -l | tr -d ' ')"
    [ "$kept" -gt 0 ] \
      || cf "post-init, NO file under .claude/{templates,roles} carries a KIT-CLASS marker — the stamp removed or rewrote the classification off every one"

    # DIRECTION 2 — no PREFIXED variant exists. Names the rewrite specifically; without
    # it, direction 1 alone reports "markers gone" and not "the key was substituted".
    local rewritten; rewritten="$(grep -rn 'SBX-CLASS' "${dirs[@]}" 2>/dev/null || true)"
    [ -z "$rewritten" ] \
      || cf "the prefix substitution rewrote the marker's KEY — a grep for KIT-CLASS will find nothing:
$(printf '%s' "$rewritten" | sed 's/^/      /')"

    # ── REDDENING CONTROL, on a COPY: reproduce the substitution and confirm BOTH arms fire.
    local probe="$SB_TMP/mkprobe"; rm -rf "$probe"; mkdir -p "$probe"
    cp -R "${dirs[0]}" "$probe/" 2>/dev/null || true
    local pd; pd="$(probe_pick "$probe" -mindepth 1 -maxdepth 1 -type d)"
    if [ -z "$pd" ]; then
      _control_did_not_run "copy a marker directory to plant into"
    else
      find "$pd" -type f -name '*.md' -exec sed -i.bak 's/KIT-CLASS/SBX-CLASS/g' {} \; 2>/dev/null
      find "$pd" -name '*.bak' -delete 2>/dev/null
      [ -z "$(grep -rl 'KIT-CLASS' "$pd" 2>/dev/null)" ] \
        || cf "(control) the planted substitution left KIT-CLASS behind — the control did not reproduce the defect"
      [ -n "$(grep -rn 'SBX-CLASS' "$pd" 2>/dev/null)" ] \
        || cf "(control) the planted substitution produced no SBX-CLASS — direction 2 would never fire"
    fi
  fi

  finish "kit-init: KIT-CLASS markers survive the stamp — present under .claude/{templates,roles} AND no <PREFIX>-CLASS variant (both directions, deletion and rewrite)"
  teardown
}

# =============================================================================
# kit-init's OWN COMMITS DECLARE THE PRE-ROLE HAT. A day-one tree has no session hat and the
# commit guard refuses a commit with none, so the initializer declares its hat (the pre-role hat
# the subject names) for each commit it makes: the initialization commit and the self-check's.
# The sandbox is a day-one tree (kit_init_sandbox clears the hat); a raw commit afterwards is the
# control that the tree really had none, so the initializer's success is not an artefact.
# RED FIRST: with the declaration removed from kit-init.sh, its first commit is refused.
# =============================================================================
case_kit_init_commits_under_the_pre_role_hat() {
  cf_reset
  if ! has_kit_init; then skp "kit-init: its own commits declare the pre-role hat" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "kit-init: its own commits declare the pre-role hat" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  publish_sandbox
  local rel; rel="$(_sandbox_hat_file)"
  [ -n "$rel" ] && [ ! -e "$SB_WORK/$rel" ] \
    || _fixture_die "case_kit_init_commits_under_the_pre_role_hat: the day-one sandbox holds a hat file (or none could be named), so kit-init's success below would prove nothing."

  local out rc
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || cf "kit-init with no hat file declared exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_log_has_subject 'kit-init: initialize the kit' || cf "the initialization commit is not on the trunk"
  origin_log_has_subject 'kit-init self-check: mint scratch card' || cf "the self-check's mint commit is not on the trunk"
  [ ! -e "$SB_WORK/$rel" ] || cf "kit-init left a hat file declared for the session"

  # (control) the tree really had no hat: a raw commit is refused now.
  printf 'x\n' > "$SB_WORK/after-init.txt"; git -C "$SB_WORK" add after-init.txt
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[PM] after init" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(control) a raw commit after kit-init with no hat was ACCEPTED, so the success above was not a declaration's work"

  finish "kit-init: its initialization and self-check commits declare the pre-role hat, so a day-one tree with no session hat initializes; a raw commit there is refused"
  teardown
}

# =============================================================================
# CASE — new-prd.sh publishes a whole PRD or nothing: a failed step must not leave a
# half-made file in requirements/, where it spends the id.
# =============================================================================
case_new_prd_failure_leaves_nothing() {
  cf_reset
  if ! has_issue_template; then skp "new-prd.sh: a failed mint leaves nothing" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  if [ ! -f "$REAL_REPO_ROOT/.claude/templates/PRD.template.md" ]; then
    skp "new-prd.sh: a failed mint leaves nothing" ".claude/templates/PRD.template.md absent — new-prd.sh exits at its template check"
    return
  fi
  make_sandbox
  mkdir -p "$SB_WORK/.claude/templates" "$SB_WORK/requirements"
  cp -R "$REAL_REPO_ROOT/.claude/templates/." "$SB_WORK/.claude/templates/"
  _kit_neutral_claude

  local lib="$SB_WORK/scripts/lib/card-head.sh" out rc
  cp "$lib" "$SB_TMP/card-head.real"
  # The re-head is the last step before publishing; a stub that fails it stands for any late failure.
  # Appended, so the library's other functions stay defined.
  { cat "$SB_TMP/card-head.real"; printf '%s\n' 'kit_rehead_card() { echo "stub: re-head failed" >&2; return 1; }'; } > "$lib"

  rc=0; out="$( cd "$SB_WORK" && ./scripts/new-prd.sh probe 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "new-prd.sh exited 0 with a failing re-head: $(printf '%s' "$out" | tr '\n' '|')"
  printf '%s' "$out" | grep -F 'stub: re-head failed' >/dev/null \
    || cf "new-prd.sh failed before reaching the re-head, so this proves nothing about a late failure: $(printf '%s' "$out" | tr '\n' '|')"
  [ -z "$(find "$SB_WORK/requirements" -type f 2>/dev/null)" ] \
    || cf "a failed new-prd.sh left file(s) in requirements/ — the id is spent: $(ls -1A "$SB_WORK/requirements" | tr '\n' ' ')"

  # CONTROL: with the real re-head the same call mints, and at the first number.
  cp "$SB_TMP/card-head.real" "$lib"
  rc=0; out="$( cd "$SB_WORK" && ./scripts/new-prd.sh probe 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(control) new-prd.sh failed with the real re-head (rc=$rc): $(printf '%s' "$out" | tr '\n' '|')"
  [ -f "$SB_WORK/requirements/$KIT_NEUTRAL_PRD_PREFIX-001-probe.md" ] \
    || cf "(control) the retry did not mint $KIT_NEUTRAL_PRD_PREFIX-001-probe.md: $(ls -1A "$SB_WORK/requirements" | tr '\n' ' ')"

  finish "new-prd.sh: a failed re-head leaves requirements/ empty, and the retry mints the first id"
  teardown
}

# =============================================================================
# CASE — next-id.sh
# =============================================================================
case_next_id() {
  cf_reset
  local out rc err
  # (1) max+1 across progress/** filenames.
  make_sandbox
  seed_issue todo "$SB_PREFIX-001" one   chore "one"
  seed_issue todo "$SB_PREFIX-003" three chore "three"
  publish_sandbox
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/next-id.sh" 2>/dev/null )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(max+1) exited $rc"
  [ "$out" = "$SB_PREFIX-004" ] || cf "(max+1) expected $SB_PREFIX-004 across filenames, got '$out'"
  printf '%s' "$out" | grep -E "^$SB_PREFIX-[0-9]{3}$" >/dev/null || cf "(shape) output '$out' is not <PREFIX>-NNN shaped"
  teardown

  # (2) it counts ARCHIVE.md entries too — the number must not reset after a sweep.
  make_sandbox
  publish_sandbox
  printf -- "- %s-009 [chore] archived issue\n" "$SB_PREFIX" >> "$SB_WORK/ARCHIVE.md"
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/next-id.sh" 2>/dev/null )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(ARCHIVE) exited $rc"
  [ "$out" = "$SB_PREFIX-010" ] || cf "(ARCHIVE) expected $SB_PREFIX-010 from the ARCHIVE.md max, got '$out'"
  teardown

  # (3) genuinely undeterminable → nonzero + an explanatory stderr message. THE
  #     CONTRACT, not a gap: where no id has ever been issued, choosing where
  #     numbering starts is a DECISION.
  make_sandbox
  publish_sandbox
  err="$( cd "$SB_WORK" && "$SB_WORK/scripts/next-id.sh" 2>&1 1>/dev/null )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(empty) expected nonzero exit on an empty board, got 0"
  printf '%s' "$err" | grep -i 'no existing' >/dev/null || cf "(empty) no explanatory stderr message: '$err'"
  teardown

  # (4) only the FILENAME counts: a checkout under a directory named like an id is not an id.
  make_sandbox "$SB_PREFIX-900"
  seed_issue todo "$SB_PREFIX-001" one chore "one"
  publish_sandbox
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/next-id.sh" 2>/dev/null )"; rc=$?
  [ "$out" = "$SB_PREFIX-002" ] || cf "(path) a checkout at .../$SB_PREFIX-900 got '$out', want $SB_PREFIX-002 — the directory part was read as an id"
  teardown

  finish "next-id.sh: max+1 (filenames + ARCHIVE.md, never the directory part), <PREFIX>-NNN shape, nonzero on an empty board"
}

# =============================================================================
# CASE — move-issue.sh moves + appends Activity + commits + PUSHES
# =============================================================================
case_move_issue() {
  cf_reset
  make_sandbox
  seed_issue todo "$SB_PREFIX-100" sandbox chore "Sandbox move test"
  publish_sandbox

  local out rc
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" "$SB_PREFIX-100" in_progress \
            --role Dev --note "picked up in sandbox" 2>&1 )"; rc=$?

  [ "$rc" -eq 0 ] || cf "move-issue exited $rc (expected 0): $out"
  origin_has_path "progress/in_progress/$SB_PREFIX-100-sandbox.md" \
    || cf "file not moved to in_progress/ on the trunk"
  origin_has_path "progress/todo/$SB_PREFIX-100-sandbox.md" \
    && cf "file still present in todo/ on the trunk"
  origin_file_contains "progress/in_progress/$SB_PREFIX-100-sandbox.md" "picked up in sandbox" \
    || cf "Activity line not appended"
  origin_log_has_subject "\[Dev\] $SB_PREFIX-100 → in_progress: picked up in sandbox" \
    || cf "commit subject not found on the trunk (not pushed?)"

  finish "move-issue.sh: move + Activity append + commit pushed to the trunk"
  teardown
}

# =============================================================================
# CASE — finish-pr.sh happy path (squash-merge, delete branch, advance)
#
# It asserts the STATE (both refs gone) AND THE CLAIM (what the board note says happened):
# a note composed before the deletes can report a deletion that did not happen. A branch
# held by a second worktree and a delete that cannot succeed are the sibling cases below.
# =============================================================================
case_finish_pr_happy() {
  cf_reset
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-777" sandbox chore "Happy path" "feature/$SB_PREFIX-777-work"
  publish_sandbox
  seed_branch "$SB_PREFIX-777" work CHANGE.txt

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$SB_PREFIX-777" 2>&1 )"; rc=$?

  [ "$rc" -eq 0 ] || cf "finish-pr exited $rc (expected 0): $out"
  git -C "$SB_WORK" rev-parse --verify --quiet "refs/heads/feature/$SB_PREFIX-777-work" >/dev/null 2>&1 \
    && cf "local branch not deleted"
  [ -z "$(git -C "$SB_WORK" ls-remote --heads origin "feature/$SB_PREFIX-777-work" 2>/dev/null)" ] \
    || cf "remote branch not deleted"
  origin_has_path "progress/qa_complete/$SB_PREFIX-777-sandbox.md" \
    || cf "issue not advanced to qa_complete/ on the trunk"
  origin_has_path "CHANGE.txt" || cf "squash-merged change not on the trunk"

  # THE CLAIM. These strings are produced only by the arms that MEASURED a confirmed deletion.
  origin_file_contains "progress/qa_complete/$SB_PREFIX-777-sandbox.md" "local branch deleted" \
    || cf "board note does not report the local delete it performed"
  origin_file_contains "progress/qa_complete/$SB_PREFIX-777-sandbox.md" "branch deleted (confirmed gone)" \
    || cf "board note does not report the CONFIRMED remote delete it performed"
  printf '%s' "$out" | grep "confirmed gone by ls-remote" >/dev/null \
    || cf "run output does not show the remote delete being confirmed by re-measurement"

  finish "finish-pr.sh happy path: squash-merge + delete branch + advance, and the board note reports BOTH deletes truthfully"
  teardown
}

# =============================================================================
# CASE — the commit-msg hook
# =============================================================================
case_commit_msg() {
  cf_reset
  make_sandbox
  local hook="$SB_WORK/scripts/githooks/commit-msg"
  local msg="$SB_TMP/msg.txt"

  # DERIVE the accepted prefixes from the hook's own ROLE_PREFIXES line — do NOT
  # re-hardcode them, or a set change makes these assertions vacuous.
  local prefixes
  # THE CANONICAL EXPRESSION, byte-identical to lib/role-set.sh's _kit_role_base.
  # FALLBACK POLICY HERE: cf (a case finding). The set is derived to keep the assertions
  # below non-vacuous, so an unreadable hook makes this case meaningless, not skippable.
  prefixes="$(sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p" "$hook" | head -1)"
  [ -n "$prefixes" ] || cf "could not derive ROLE_PREFIXES from the hook"

  local IFS='|' p rc
  for p in $prefixes; do
    printf '[%s] a valid subject\n' "$p" > "$msg"
    ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 0 ] || cf "prefix [$p] rejected (exit $rc)"
  done
  unset IFS

  # Auto-exempt subjects (git/host-generated).
  local exempt=("Merge branch 'x'" "Revert \"something\"" "fixup! earlier commit" "Merge commit '1f00d13cc8b29fe812a87eb45eb35c34a5ca0ee2'")
  local s
  for s in "${exempt[@]}"; do
    printf '%s\n' "$s" > "$msg"
    ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 0 ] || cf "auto-exempt subject rejected: '$s' (exit $rc)"
  done

  # THE BOUNDARY: "Merge commit " WITHOUT the quote is an ORDINARY human subject that merely
  # starts with the same two words as git's own `Merge commit '<sha>'` — it must NOT be
  # exempted, or a real subject with no [Role] prefix passes silently.
  printf 'Merge commit messages into one doc\n' > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] \
    || cf "ABLATION FAILED — 'Merge commit messages into one doc' was accepted as if it were git's generated merge subject; the exemption glob must require the opening quote"

  # Unprefixed subject → rejected, and the rejection LISTS the legal tags (which
  # it derives, so the help text cannot lie about the set).
  printf 'no role prefix at all\n' > "$msg"
  local out
  out="$( env -u MSG_OK "$hook" "$msg" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "unprefixed subject accepted (must be rejected)"
  printf '%s' "$out" | grep "\[${prefixes%%|*}\]" >/dev/null \
    || cf "the rejection message does not list the derived role tags: $out"

  # The applypatch path judges a subject the SAME way (git am runs that hook, not
  # commit-msg, and its mailinfo strips bracketed tags).
  printf 'no role prefix at all\n' > "$msg"
  ( env -u MSG_OK "$SB_WORK/scripts/githooks/applypatch-msg" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] || cf "applypatch-msg accepted an unprefixed subject (the am path must not be a hole)"

  # --- § A.1: no generated co-author trailer, and no "Generated with …" line ------
  # DERIVE the markers from the hook's TOOL_TRAILER_MARKERS, as the prefixes are. This asserts
  # the rule works for WHATEVER markers are declared, not that the set is right: a narrowed
  # list is invisible here by construction, and only an empty one is caught. Deleting RULE (2)
  # from the hook is what reddens it.
  local role markers marker
  role="${prefixes%%|*}"
  markers="$(sed -n "s/^TOOL_TRAILER_MARKERS='\\(.*\\)'.*/\\1/p" "$hook")"
  [ -n "$markers" ] || cf "could not derive TOOL_TRAILER_MARKERS from the hook"
  marker="${markers%%|*}"
  # The refusal prints that list VERBATIM, so it must stay plain words — a regex
  # metacharacter in it would be a lie in the help text and a live pattern in the match.
  printf '%s' "$markers" | grep -E '^[a-z0-9|]+$' >/dev/null \
    || cf "(trailer) TOOL_TRAILER_MARKERS is not the plain-word list the refusal prints: '$markers'"

  # `git commit -v` hands the hook the RAW DIFF below the scissors line; editing a file that
  # contains a trailer is not writing one, so this is ACCEPTED. (\x escapes keep this file
  # ASCII; the emoji leads because the tooling's shape does.)
  printf '[%s] a valid subject\n\n# ------------------------ >8 ------------------------\n# Do not modify or remove the line above.\ndiff --git a/doctrine b/doctrine\n--- a/doctrine\n+++ b/doctrine\n@@ -1 +1,2 @@\n Co-Authored-By: %s <noreply@example.com>\n+\xf0\x9f\xa4\x96 Generated with [Some Tool](https://example.com)\n' "$role" "$marker" > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] || cf "(trailer) a \`commit -v\` message was refused for the DIFF below its scissors line (exit $rc)"

  # A clean multi-line message is ACCEPTED — including a HUMAN co-author trailer and the
  # words in prose. A guard that rejected every message with a body would pass a
  # one-directional test.
  printf '[%s] a valid subject\n\nA body that explains why, and mentions a file generated with the codegen step.\n\nCo-authored-by: A Person <person@example.com>\n' "$role" > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] || cf "(trailer) a clean multi-line message with a HUMAN co-author was rejected (exit $rc)"

  # A tool-naming trailer is REJECTED, and the refusal names the rule and the markers.
  printf '[%s] a valid subject\n\nCo-Authored-By: %s <noreply@example.com>\n' "$role" "$marker" > "$msg"
  out="$( env -u MSG_OK "$hook" "$msg" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(trailer) a Co-Authored-By naming '$marker' was accepted"
  printf '%s' "$out" | grep 'commit-hygiene.md' >/dev/null || cf "(trailer) the refusal does not name the rule: $out"
  printf '%s' "$out" | grep -i "$marker" >/dev/null || cf "(trailer) the refusal does not list the derived markers: $out"

  # ── NO SPACE AFTER THE COLON: the pre-marker context must be an OPTIONAL group; a required
  #    `[^[:alnum:]]` has nothing to consume here and the trailer walks through.
  printf '[%s] a valid subject\n\nCo-Authored-By:%s <noreply@example.com>\n' "$role" "$marker" > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] \
    || cf "(trailer) 'Co-Authored-By:$marker' with NO SPACE after the colon was accepted — the pre-marker context in rule 2's matcher is a required character again instead of an optional group, and deleting one space defeats the guard"

  #    …and several spaces must not defeat it either, in the other direction.
  printf '[%s] a valid subject\n\nCo-Authored-By:   %s   <noreply@example.com>\n' "$role" "$marker" > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] || cf "(trailer) a padded 'Co-Authored-By:   $marker' was accepted"

  # ── THE FALSE-POSITIVE GUARD: a human whose name BEGINS with a marker's stem is not a tool
  #    trailer, and the trailing `([^[:alnum:]]|$)` keeps them out. Refusing a real
  #    contributor by name is worse than the hole.
  printf '[%s] a valid subject\n\nCo-Authored-By: %sia Ng <person@example.com>\n' "$role" "$marker" > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] \
    || cf "(trailer) a HUMAN named '${marker}ia Ng' was refused (exit $rc) — the marker match has lost its right-hand boundary and now fires on any name starting with '$marker'"

  # The second arm of § A.1, with the leading decoration the tooling actually emits.
  printf '[%s] a valid subject\n\n\xf0\x9f\xa4\x96 Generated with [Some Tool](https://example.com)\n' "$role" > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] || cf '(trailer) a "Generated with" line was accepted'

  # The auto-exempt subjects are exempt from the PREFIX rule only: a merge carries a body.
  printf "Merge branch 'x'\n\nCo-Authored-By: %s <noreply@example.com>\n" "$marker" > "$msg"
  ( env -u MSG_OK "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] || cf "(trailer) an auto-exempt SUBJECT carried a tool trailer through — that exemption is the prefix rule's only"

  # The am path judges the trailer the same way, or the import entrance is a hole.
  printf '[%s] a valid subject\n\nCo-Authored-By: %s <noreply@example.com>\n' "$role" "$marker" > "$msg"
  ( env -u MSG_OK "$SB_WORK/scripts/githooks/applypatch-msg" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] || cf "(trailer) applypatch-msg accepted a tool trailer (the am path must not be a hole)"

  # The documented escape still works, because importing a third party's commit verbatim
  # is the case it exists for.
  printf '[%s] a valid subject\n\nCo-Authored-By: %s <noreply@example.com>\n' "$role" "$marker" > "$msg"
  ( MSG_OK=1 "$hook" "$msg" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] || cf "(trailer) MSG_OK=1 did not bypass the trailer rule (the documented import escape)"

  finish "commit-msg: accepts every derived role prefix + the auto-exempt set, rejects unprefixed; rejects a tool co-author trailer and a \"Generated with\" line on both entrances while accepting a human trailer and a \`commit -v\` diff; and applypatch-msg agrees"
  teardown
}

# =============================================================================
# CASE — the pre-commit hook: a metadata-only commit is REFUSED off the trunk, naming
# register-commit.sh, and ALLOWED on the trunk. RED FIRST: run against a sandbox with
# scripts/githooks/pre-commit removed to see the refusal vanish.
# =============================================================================
case_pre_commit_refuses_metadata_off_trunk() {
  cf_reset
  make_sandbox
  local hook="$SB_WORK/scripts/githooks/pre-commit"
  local cfg="$SB_WORK/scripts/config.sh"
  [ -x "$hook" ] \
    || { skp "pre-commit: refuses a metadata-only commit off the trunk" "scripts/githooks/pre-commit is absent from this tree"; teardown; return; }

  # CODE_GLOBS must be DECLARED for this refusal to fire at all (case_pre_commit_undeclared_code_globs_is_a_noop
  # covers the undeclared/fail-open state) — declare something that will never match this
  # case's metadata paths, so every path below is judged metadata on purpose. _array_set_body
  # (fixtures.sh) replaces the WHOLE array body, so this takes whatever the tree's CODE_GLOBS
  # currently holds — empty, filled, or a `# DECLARED EMPTY —` comment on a tree past day one —
  # and its own postcondition reads the parsed array, not a bare '"src/*"' string the shipped
  # comment above CODE_GLOBS also carries.
  _array_set_body "$cfg" CODE_GLOBS '  "src/*"'

  publish_sandbox

  ( cd "$SB_WORK" && git checkout -q -b feature/off-trunk-metadata )
  echo "a ruling" > "$SB_WORK/a-metadata-file.md"
  git -C "$SB_WORK" add a-metadata-file.md

  local out rc
  out="$( cd "$SB_WORK" && env -u MSG_OK git commit -q -m "[$SB_ROLE] add a-metadata-file.md" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "a metadata-only commit on 'feature/off-trunk-metadata' (not the trunk) was ACCEPTED"
  printf '%s' "$out" | grep -F 'register-commit.sh' >/dev/null \
    || cf "the refusal does not name register-commit.sh as the route: $out"
  printf '%s' "$out" | grep -F 'code-vs-metadata' >/dev/null \
    || cf "the refusal does not cite the code-vs-metadata rule: $out"
  printf '%s' "$out" | grep -F 'a-metadata-file.md' >/dev/null \
    || cf "the refusal does not name the staged path: $out"

  # Nothing committed — the working tree change is still staged, exactly as it was.
  git -C "$SB_WORK" diff --cached --name-only | grep -F 'a-metadata-file.md' >/dev/null \
    || cf "the refusal left the change NOT staged — it should be untouched, not partially undone"

  # The documented bypass still works (same escape as commit-msg, deliberately one name).
  out="$( cd "$SB_WORK" && MSG_OK=1 git commit -q -m "[$SB_ROLE] add a-metadata-file.md" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "MSG_OK=1 did not bypass the pre-commit guard (the documented escape): $out"

  finish "pre-commit: refuses a metadata-only commit made on a branch other than the trunk, naming register-commit.sh and the staged path, and MSG_OK=1 bypasses it"
  teardown
}

# =============================================================================
# CASE — arm [g] reads COMPLETE only once the day-one WORK exists: a PRD (SEED step 6) and a card
# that has passed QA (step 7), beside the filled blanks. A tree whose blanks are all filled, with no
# PRD and no landed card, is not finished, and arm [p] — which reads [g]'s verdict — stays silent
# on the SEED-step marker CORPUS.md told the adopter to write. The operands are fixed in this case:
# one PRD, one card in qa_complete/ or done/, never read back from the arm.
# =============================================================================
case_check_board_graduation_requires_the_day_one_work() {
  cf_reset
  make_sandbox
  local out corpus_file
  corpus_file="$(cb_default_seam CORPUS_FILE)"
  [ -n "$corpus_file" ] || _fixture_die "case_check_board_graduation_requires_the_day_one_work: could not derive CORPUS_FILE."
  mkdir -p "$SB_WORK/$(dirname "$corpus_file")"
  cat > "$SB_WORK/$corpus_file" <<CORPUS_EOF
# CORPUS.md

| Entry | Kind | Status | Why it is corpus |
|---|---|---|---|
| \`src/\` | dir | forward-referenced (SEED step 6) | the code lands with the first card |
CORPUS_EOF
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  printf '# my project\n' > "$SB_WORK/AGENTS.md"
  printf '# my project\n' > "$SB_WORK/README.md"
  printf '<!-- %s — synthetic fill sheet, FILLED. -->\n# PROJECT.md\n\nTrunk: main\n\n## Who answers when nobody is watching\n\n- **`principal:`** `Fixture Owner`\n- **Their channel:** `dev/questions/`\n' \
    "$KIT_FILL_DISPOSITION" > "$SB_WORK/PROJECT.md"
  _cb_g_declare_empty_seams
  _cb_g_discharge_delete_if_unused
  _cb_g_discharge_gitignore_env
  publish_sandbox

  # (a) every blank filled, no PRD, no card: not COMPLETE, the missing work is NAMED, and [p] is silent.
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'PROJECT.md principal:.*declared' >/dev/null \
    || _fixture_die "case_check_board_graduation_requires_the_day_one_work: the blanks are not all filled, so (a) would not isolate the day-one work: $(printf '%s\n' "$out" | _cb_g_section)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    && cf "(a) graduation COMPLETE with no PRD and no landed card: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'DAY-ONE WORK' | grep 'day one is not finished' | grep 'no PRD' | grep 'no card has passed QA' | grep 'steps 6-7' >/dev/null \
    || cf "(a) the arm did not name both missing pieces and the SEED steps: $(printf '%s\n' "$out" | _cb_g_section)"
  printf '%s\n' "$out" | grep '⚠' | grep 'does not outlive day one' >/dev/null \
    && cf "(a) arm [p] flagged the SEED-step marker while arm [g] had not read COMPLETE: $out"

  # (b) a PRD alone: still not COMPLETE, and only the card is named.
  _cb_g_seed_prd
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    && cf "(b) graduation COMPLETE with a PRD and no landed card: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'DAY-ONE WORK' | grep 'day one is not finished' | grep 'no card has passed QA' >/dev/null \
    || cf "(b) a missing landed card was not named: $(printf '%s\n' "$out" | _cb_g_section)"
  printf '%s\n' "$out" | _cb_g_section | grep 'DAY-ONE WORK' | grep 'day one is not finished' | grep 'no PRD' >/dev/null \
    && cf "(b) a PRD exists, yet the arm still says there is none: $(printf '%s\n' "$out" | _cb_g_section)"

  # (c) a card still in todo/ is not a card that passed QA.
  seed_issue todo "$SB_PREFIX-898" open-card chore "Still open"
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    && cf "(c) graduation COMPLETE with only an open card: $out"

  # (d) a card alone, no PRD: not COMPLETE, and only the PRD is named.
  rm -f "$SB_WORK/requirements/PRD-001-fixture.md"
  _cb_g_seed_landed_card qa_complete
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    && cf "(d) graduation COMPLETE with a landed card and no PRD: $out"
  printf '%s\n' "$out" | _cb_g_section | grep 'DAY-ONE WORK' | grep 'day one is not finished' | grep 'no PRD' >/dev/null \
    || cf "(d) a missing PRD was not named: $(printf '%s\n' "$out" | _cb_g_section)"
  printf '%s\n' "$out" | _cb_g_section | grep 'DAY-ONE WORK' | grep 'day one is not finished' | grep 'no card has passed QA' >/dev/null \
    && cf "(d) a card sits in qa_complete/, yet the arm still says none has passed QA: $(printf '%s\n' "$out" | _cb_g_section)"

  # (e) both: COMPLETE, and [p] now flags the marker it was silent on.
  _cb_g_seed_prd
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    || cf "(e) a PRD and a card in qa_complete/ did not reach graduation COMPLETE: $out"
  printf '%s\n' "$out" | grep '⚠' | grep 'does not outlive day one' >/dev/null \
    || cf "(e) [g] reads COMPLETE, but the standing SEED-step marker was not reported: $out"

  # (f) the card archived to done/ (archive.sh sweeps landed cards there) still counts.
  git -C "$SB_WORK" mv "progress/qa_complete/$SB_PREFIX-899-day-one-card.md" "progress/done/$SB_PREFIX-899-day-one-card.md" >/dev/null 2>&1 \
    || _fixture_die "case_check_board_graduation_requires_the_day_one_work: could not archive the card to done/"
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep 'graduation COMPLETE' >/dev/null \
    || cf "(f) a PRD and a card in done/ did not reach graduation COMPLETE: $out"

  finish "arm [g]: graduation COMPLETE needs a PRD and a card in qa_complete/ or done/ beside the filled blanks, names whichever is missing, and arm [p]'s SEED-step finding follows that verdict"
  teardown
}

# =============================================================================
# CASE — ENABLE PLACES AND RECORDS A MODULE, DISABLE TAKES BACK EXACTLY THAT, AND EACH IS A NO-OP THE
# SECOND TIME.
#   Operand: a byte snapshot of the tree before enable. After disable it must be equal, and after a second
#   enable or a second disable nothing may move.
# =============================================================================
case_module_enable_and_disable_are_inverse_and_idempotent() {
  cf_reset
  local L="module.sh enable places the module's files, role layer, evidence-kind layer, fragments, checks, arm and block and records each by its sha256; disable returns the tree to its bytes from before enable; a second enable and a second disable are no-ops that say so"
  if ! _md_have_example; then skp_lived "$L" "$(_md_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _md_sandbox
  local s0="$SB_TMP/snap0" s1="$SB_TMP/snap1" s2="$SB_TMP/snap2" f n rows
  _md_snap "$SB_WORK" > "$s0"
  [ -s "$s0" ] || _fixture_die "${FUNCNAME[0]}: the snapshot of the sandbox is empty."
  [ -f "$SB_WORK/scripts/module.sh" ] || cf "(prereq) scripts/module.sh is absent from the tree under test"

  # (a) list before: the module is shipped and not enabled.
  _md_mod list
  [ "$_md_rc" -eq 0 ] || cf "(a) list exited $_md_rc: $_md_out"
  printf '%s\n' "$_md_out" | grep -E '^  example +[0-9]+\.[0-9]+\.[0-9]+ +disabled' >/dev/null || cf "(a) list does not show example as disabled: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-200)"

  # (b) enable.
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || cf "(b) enable exited $_md_rc: $_md_out"
  for f in .claude/roles/example.md .claude/skills/example-skill/SKILL.md scripts/check-board.d/50-example.sh \
           scripts/move-check.d/in_progress/50-example.sh scripts/qa-cell.d/example-note/50-example.sh \
           process/fragments.d/PRD/example.slot-story-fields process/fragments.d/ISSUE/example.body-end \
           process/roles.d/example process/evidence-kinds.d/example process/MODULES; do
    [ -f "$SB_WORK/$f" ] || cf "(b) enable did not place $f"
  done
  grep -F '<!-- KIT-MODULE:example:gates BEGIN -->' "$SB_WORK/PROJECT.md" >/dev/null || cf "(b) enable did not put the module's block in PROJECT.md"
  grep -E '^module example [0-9]+\.[0-9]+\.[0-9]+$' "$SB_WORK/process/MODULES" >/dev/null || cf "(b) process/MODULES has no 'module example <version>' line"
  grep -E '^pending ' "$SB_WORK/process/MODULES" >/dev/null && cf "(b) process/MODULES still records the enable as pending after it finished"
  for f in .claude/roles/example.md scripts/check-board.d/50-example.sh process/fragments.d/ISSUE/example.body-end; do
    grep -E "^file $(_old_sha "$SB_WORK/$f") $f\$" "$SB_WORK/process/MODULES" >/dev/null || cf "(b) process/MODULES does not record $f with the sha256 of the file as placed"
  done
  grep -E '^block [0-9a-f]{64} PROJECT.md gates$' "$SB_WORK/process/MODULES" >/dev/null || cf "(b) process/MODULES does not record the PROJECT.md block"
  [ -x "$SB_WORK/scripts/move-check.d/in_progress/50-example.sh" ] || cf "(b) the module's executable move check lost its mode when placed"
  printf '%s\n' "$_md_out" | grep -F 'read the TRUNK' >/dev/null || cf "(b) enable does not say that check-board reads the trunk, so a role it adds is unknown there until the commit is pushed"
  printf '%s\n' "$_md_out" | grep -F 'git add -A --' >/dev/null || cf "(b) enable does not print what to commit"
  grep -F 'KIT-MODULE' "$SB_WORK/.claude/roles/example.md" >/dev/null && cf "(b) a module file carries a marker line it should not"
  _md_snap "$SB_WORK" > "$s1"

  # (c) status: every recorded thing intact, derived from the record rather than from a number.
  _md_mod status example
  n="$(printf '%s\n' "$_md_out" | grep -c 'intact')"
  rows="$(grep -cE '^(file|block) ' "$SB_WORK/process/MODULES")"
  { [ "$rows" -ge 1 ] && [ "$n" = "$rows" ]; } || cf "(c) status shows $n intact line(s) for $rows recorded row(s): $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$_md_out" | grep -E 'edited|missing' >/dev/null && cf "(c) status reports an edited or missing file straight after enable"

  # (d) a second enable is a no-op: the tree does not move, and it says so.
  _md_mod enable example
  [ "$_md_rc" -eq 0 ] || cf "(d) the second enable exited $_md_rc: $_md_out"
  printf '%s\n' "$_md_out" | grep -F 'already enabled' >/dev/null || cf "(d) the second enable does not say the module is already enabled: $_md_out"
  _md_snap "$SB_WORK" > "$s2"
  cmp -s "$s1" "$s2" || cf "(d) the second enable changed the tree"

  # (e) disable returns the tree to its bytes from before enable.
  _md_mod disable example
  [ "$_md_rc" -eq 0 ] || cf "(e) disable exited $_md_rc: $_md_out"
  _md_snap "$SB_WORK" > "$s2"
  cmp -s "$s0" "$s2" || cf "(e) the tree is not byte-equal to its state before enable: $(diff "$s0" "$s2" | tr '\n' '|' | cut -c1-300)"
  [ ! -e "$SB_WORK/process/MODULES" ] || cf "(e) process/MODULES remains with no module enabled"
  _md_mod list
  printf '%s\n' "$_md_out" | grep -E '^  example .* disabled' >/dev/null || cf "(e) list does not show example as disabled again"

  # (f) a second disable is a no-op.
  _md_mod disable example
  [ "$_md_rc" -eq 0 ] || cf "(f) the second disable exited $_md_rc: $_md_out"
  printf '%s\n' "$_md_out" | grep -F 'not enabled' >/dev/null || cf "(f) the second disable does not say the module is not enabled: $_md_out"
  _md_snap "$SB_WORK" > "$s1"
  cmp -s "$s0" "$s1" || cf "(f) the second disable changed the tree"

  finish "$L"
  teardown
}

case_every_shipped_module_is_indexed_and_enables_and_disables_cleanly() {
  cf_reset
  local L="each module under modules/ has a manifest whose name is its directory, a row in modules/README.md (a row may outlive a deleted directory), and enables and disables in a sandbox to the bytes it found, with every recorded thing intact in between"
  local m name dirs="" s0 s1 skipped="" judged=0 absent id
  for m in "$REAL_REPO_ROOT"/modules/*/module.manifest; do
    [ -f "$m" ] || continue
    dirs="${dirs}$(basename "$(dirname "$m")")
"
  done
  if [ -z "$dirs" ]; then skp_lived "$L" "$(_md_gone_reason)"; return; fi
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum): enable refuses without one"; return; }
  _md_sandbox
  [ -f "$SB_WORK/scripts/module.sh" ] || cf "(prereq) scripts/module.sh is absent from the tree under test"
  s0="$SB_TMP/snap0"; s1="$SB_TMP/snap1"
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    [ "$(sed -n 's/^name:[[:space:]]*//p' "$REAL_REPO_ROOT/modules/$name/module.manifest" | head -1)" = "$name" ] \
      || cf "($name) its manifest's name is not its directory"
    grep -F "[\`$name\`]" "$REAL_REPO_ROOT/modules/README.md" >/dev/null 2>&1 || cf "($name) modules/README.md has no row for it"
    _md_snap "$SB_WORK" > "$s0"
    _md_mod enable "$name"
    if [ "$_md_rc" -ne 0 ]; then
      # a required requirement that does not hold on this machine is the module's refusal, not the lifecycle's defect: named, not failed
      if [ "$(_md_recs module-requires-missing)" -ge 1 ] && [ ! -e "$SB_WORK/process/MODULES" ]; then
        # legitimate only when a tool the manifest requires (a `requires:` id) is really absent here; a check that fails with every tool present is the module's defect
        absent=""
        for id in $(sed -n -E 's/^requires:[[:space:]]*([a-z0-9][a-z0-9._-]*) \|.*\| required[[:space:]]*$/\1/p' "$REAL_REPO_ROOT/modules/$name/module.manifest"); do
          _md_tool_here "$id" || absent="$absent $id"
        done
        if [ -n "$absent" ]; then skipped="${skipped}${skipped:+, }$name"; continue; fi
        cf "($name) enable refused a required requirement although every tool it names is present: its check fails on this machine"; continue
      fi
      cf "($name) enable exited $_md_rc: $(printf '%s' "$_md_out" | tr '\n' '|' | cut -c1-240)"; continue
    fi
    judged=$((judged + 1))
    _md_mod status "$name"
    printf '%s\n' "$_md_out" | grep -E 'edited|missing' >/dev/null && cf "($name) status reports an edited or missing thing straight after enable"
    _md_mod disable "$name"
    _md_snap "$SB_WORK" > "$s1"
    cmp -s "$s0" "$s1" || cf "($name) disable did not return the tree to its bytes: $(diff "$s0" "$s1" | tr '\n' '|' | cut -c1-200)"
  done <<MODULE_DIRS_EOF
$dirs
MODULE_DIRS_EOF

  # The other direction is deliberately not checked: EXTRACTION.md sanctions deleting a module's directory,
  # and the index row of a module the project declined may stay.

  if [ -n "$skipped" ]; then
    if [ "$judged" -eq 0 ] && [ -z "$_cf" ]; then skp "$L" "every module's required requirement fails on this machine (refused module-requires-missing): $skipped"; teardown; return; fi
    printf '  note  not judged here, a required requirement does not hold (refused module-requires-missing): %s\n' "$skipped"
  fi
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE SHIPPED MANIFEST DESCRIBES THIS TREE, AND THE COPY-LIST IS INSIDE IT.
#
# The zip carries process/KIT-MANIFEST: <sha256>  <path>  <class>  <disposition>, one row per shipped file,
# generated at build and never tracked. The population cases derive from it because on an
# adopted tree a glob cannot tell a kit file from one the adopter was told to add. This case
# makes it trustworthy: present, non-empty, every path exists, it excludes itself, and it is a
# SUPERSET of the COPY_LIST kit-init refuses without.
# =============================================================================
case_shipped_manifest_describes_the_tree() {
  cf_reset
  local man="$REAL_REPO_ROOT/process/KIT-MANIFEST"
  # NOT A SKIP: the startup guard refuses the run without the manifest, so reaching here
  # without it means that guard was removed.
  [ -f "$man" ] \
    || _fixture_die "case_shipped_manifest_describes_the_tree: process/KIT-MANIFEST is absent, which the startup guard should already have refused. Either that guard was removed or something deleted the manifest mid-run; either way every population case below derives from it."

  local n=0 missing="" self=0 rel
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    n=$(( n + 1 ))
    [ "$rel" = "process/KIT-MANIFEST" ] && self=1
    [ -e "$REAL_REPO_ROOT/$rel" ] || _member_removed "$rel" || missing="$missing $rel"
  done <<EOF
$(grep -v '^#' "$man" | awk '{print $2}')
EOF

  # ── INSTRUMENT CHECK: a manifest that named nothing would satisfy every arm below. The floor
  #    is a comparison, not a typed number.
  [ "$n" -gt 0 ] \
    || cf "(instrument) process/KIT-MANIFEST holds no path rows — every assertion in this case would be vacuously true over an empty set"

  [ -z "$missing" ] \
    || cf "the manifest names path(s) that do not exist in this tree —$missing. The manifest describes the artifact or it describes nothing"

  [ "$self" -eq 0 ] \
    || cf "the manifest lists ITSELF, which cannot be right: its own hash is not knowable while it is being written, so the row is either wrong or the exclusion broke"

  # ── The copy-list minimum must be a SUBSET of the manifest. Both sides derived: the list is
  #    read out of kit-init.sh's own COPY_LIST array rather than retyped here, so a file added to
  #    that array and never shipped is caught, and this case cannot drift from it.
  local ki="$REAL_SCRIPTS/kit-init.sh" f absent="" cl=0
  if [ -f "$ki" ]; then
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      cl=$(( cl + 1 ))
      grep -v '^#' "$man" | awk '{print $2}' | grep -xF "$f" >/dev/null || absent="$absent $f"
    done <<EOF
$(awk '/^COPY_LIST=\(/{f=1;next} f&&/^\)/{exit} f{gsub(/^[[:space:]]+|[[:space:]]+$/,""); if($0!="") print}' "$ki")
EOF
    # ── INSTRUMENT CHECK: the extractor found the array; a renamed COPY_LIST yields zero
    #    entries and the subset assertion would cover nothing.
    [ "$cl" -gt 0 ] \
      || cf "(instrument) no entries were extracted from kit-init.sh's COPY_LIST — the array was renamed or reshaped, so the subset assertion below covers nothing"
    [ -z "$absent" ] \
      || cf "kit-init.sh REFUSES to run without these file(s) and the shipped manifest does not name them —$absent. Either the build stopped shipping a file the initializer demands, or COPY_LIST names something that never travelled"
  else
    cf "scripts/kit-init.sh is absent, so the copy-list subset arm could not run — and this case's whole point is that the two agree"
  fi

  finish "process/KIT-MANIFEST names $n shipped path(s), every one of which exists in this tree; it excludes itself; and all $cl entries of kit-init.sh's own COPY_LIST minimum are inside it — both sides of that comparison derived, neither retyped here"
}

# =============================================================================
# CASE — NO SHIPPED SCRIPT REACHES PAST THE DECLARED FLOOR.
#
# The kit REQUIRES git and a POSIX shell and carves out its optional extras by name (the
# Python hygiene tools; one skill's Node companion). A shell program that invokes another
# interpreter must check for it with `command -v` first, and a check for one it no longer
# invokes is stale. A floor nobody checks is a claim.
#
# AN ADOPTER'S FILLED GATES RECORD IS NOT KIT CODE: a filled `scripts/verify.sh` reads
# `"unit|core|node --test"`, and the raw file would report that as verify.sh itself invoking
# node. Every op file is scanned through _gates_blank_commands first, so the array's command
# field never reaches the interpreter scan while the rest of the file — including a genuine
# unguarded call outside GATES — is scanned unchanged.
# =============================================================================
case_shipped_scripts_stay_on_the_floor() {
  cf_reset
  # NO SANDBOX. The population is the SHIPPED MANIFEST, which describes the real tree; a sandbox
  # is a mutated copy of part of it and could not answer the question.
  local man="$REAL_REPO_ROOT/process/KIT-MANIFEST"
  [ -f "$man" ] \
    || _fixture_die "case_shipped_scripts_stay_on_the_floor: process/KIT-MANIFEST is absent, which the startup guard should already have refused."

  # The interpreters NOT on the floor, one per variable so this case's own text cannot satisfy
  # its search. `python3` is separate from `python`: the pattern anchors on a word boundary.
  local i1='perl' i2='python' i3='python3' i4='node' i5='ruby'

  local rel f sb n=0 walked=0 outspan="" absent=""
  local undeclared="" stale=""

  # A scratch root for the GATES-blanked copies this case scans instead of the real files
  # (the real tree is still what MEMBERSHIP and the shebang are read from, above and below).
  local gscratch; gscratch="$(mktemp -d)"

  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    n=$(( n + 1 ))
    f="$REAL_REPO_ROOT/$rel"
    [ -f "$f" ] || { _member_removed "$rel" || absent="$absent $rel"; continue; }
    sb="$(head -1 "$f" 2>/dev/null)"
    case "$sb" in
      '#!'*sh) ;;                        # a POSIX-shell program — inside this check's span
      '#!'*)                             # a program in another language — OUTSIDE it, see below
        outspan="$outspan ${rel}(${sb##*/})"; continue ;;
      *) continue ;;                     # not a program at all
    esac
    walked=$(( walked + 1 ))

    # THE HARNESS IS ONE PROGRAM IN SEVERAL FILES: the entry point's perl probe declares the
    # perl calls in lib/*.sh and cases/*.sh, so the entry point is read as the population it
    # loads, and a hit names the file that holds it.
    local ops=("$f") _pf
    if [ "$f" -ef "$HARNESS_ENTRY" ]; then
      ops=()
      while IFS= read -r _pf; do [ -n "$_pf" ] && ops+=("$_pf"); done <<FLOOR_POP_EOF
$(_harness_sources)
FLOOR_POP_EOF
      _harness_population_is_whole <(cat "${ops[@]}")
    fi

    # SCAN THROUGH GATES-BLANKED COPIES, never the real files: an adopter's filled GATES
    # record is not kit code (see _gates_blank_commands above). Membership, the shebang and
    # everything else above still read the real tree. Each copy keeps ITS OWN real relative
    # path as its scratch path (mkdir -p, one op per subdirectory) purely so a hit message
    # below still names the real file, never a scratch index.
    local scan_ops=() _op _od
    for _op in "${ops[@]}"; do
      _od="$gscratch/${_op#$REAL_REPO_ROOT/}"
      mkdir -p "$(dirname "$_od")"
      _gates_blank_commands "$_op" > "$_od"
      scan_ops+=("$_od")
    done

    local w hits guarded
    for w in "$i1" "$i2" "$i3" "$i4" "$i5"; do
      hits="$(_floor_hits "$w" "$gscratch" "${scan_ops[@]}")"
      # DECLARED = the file guards the interpreter with `command -v` in its own text. No name
      # list.
      guarded=0
      grep -qE "command -v ${w}([^0-9A-Za-z_]|\$)" "${scan_ops[@]}" 2>/dev/null && guarded=1
      if [ -n "$hits" ] && [ "$guarded" -eq 0 ]; then
        undeclared="$undeclared
    $rel invokes '$w' and never checks for it: $(printf '%s' "$hits" | head -1)"
      elif [ -z "$hits" ] && [ "$guarded" -eq 1 ]; then
        # THE SECOND DIRECTION: a guard for a dependency that is gone reads as coverage.
        stale="$stale $rel($w)"
      fi
    done
  done <<EOF
$(grep -v '^#' "$man" | awk '{print $2}')
EOF

  # ── INSTRUMENT CHECK: every manifest row was reached. No typed minimum.
  [ "$n" -gt 0 ] \
    || cf "(instrument) the manifest yielded no paths — every assertion here would be vacuously true"
  [ -z "$absent" ] \
    || cf "(instrument) the manifest names path(s) absent from this tree, so they were NOT examined —$absent"
  [ "$walked" -gt 0 ] \
    || cf "(instrument) not one shipped SHELL program was found among $n manifest path(s) — the shebang test stopped matching, so 'nothing off the floor' is true of nothing"

  [ -z "$undeclared" ] \
    || cf "shipped shell program(s) invoke an interpreter past the kit's declared floor (git + a POSIX shell) WITHOUT checking for it first:$undeclared"
  [ -z "$stale" ] \
    || cf "shipped shell program(s) carry a 'command -v' guard for an interpreter they no longer invoke —$stale. A declaration that outlives its use reads as coverage and is none"

  rm -rf "$gscratch"

  # THE SPAN IS PRINTED ON THE CLEARING BRANCH. Non-shell programs are named, not judged: the
  # command-position pattern reads shell, and on Python it would call `node = …` an invocation.
  finish "of $n manifest path(s), the $walked that are shipped SHELL programs invoke no interpreter past the kit's floor without checking for it first, and none carries a check for one it no longer invokes — the population is DERIVED FROM THE MANIFEST rather than from a glob, so a file the adopter was told to add is not counted as ours; the harness entry point is read as the whole population it loads. An adopter's filled verify.sh GATES record is excluded by its declared array shape, not by name — STILL NOT CAUGHT: the same quoted shape used OUTSIDE a GATES array. NOT MEASURED HERE, because this check's pattern reads shell and would report a variable named 'node' as an invocation:${outspan:- (none)}"
}

# =============================================================================
# CASE — A TEMPLATE'S LINKS RESOLVE FROM WHERE IT LANDS, NOT FROM WHERE IT SITS.
#
# A template SITS in process/templates/ and is COPIED to dev/launch/, requirements/,
# progress/todo/ … A link written for where it sits passes every link check run in the kit
# and is dead in every copy an adopter makes. Each template declares its destination in a
# header line, and this case reads it there rather than from a table here.
# =============================================================================
case_template_links_resolve_from_their_destination() {
  cf_reset
  make_sandbox
  local probe="$SB_TMP/tmpl" t base dest n=0 bad=0
  # COPY THE WHOLE TREE, not the directories this case thinks it needs: a hand-listed corpus
  # reports links into whatever the list forgot as broken.
  rm -rf "$probe"; mkdir -p "$probe"
  ( cd "$REAL_REPO_ROOT" && tar cf - . 2>/dev/null ) | ( cd "$probe" && tar xf - 2>/dev/null ) || true
  [ -d "$probe/process/templates" ] \
    || { skp "a template's links resolve from where it LANDS" "process/templates/ is absent"; teardown; return; }

  # The landing directories a template names may not exist on a fresh tree (dev/rounds/<name>/
  # is minted per round); create them so a CORRECT link is not reported as broken.
  ( cd "$probe" && mkdir -p requirements progress/todo dev/launch dev/rounds/X docs ) >/dev/null 2>&1

  for t in "$probe"/process/templates/*.md "$probe"/.claude/templates/*.md; do
    [ -f "$t" ] || continue
    base="$(basename "$t")"
    # THE DESTINATION IS THE TEMPLATE'S OWN CLAIM. Only files that state one are checked;
    # a template with no declared destination is a different (and reported) problem.
    dest="$(sed -n 's|.*RELATIVE TO WHERE IT LANDS — \([^ ]*\) .*|\1|p' "$t" | head -1)"
    [ -n "$dest" ] || dest="$(sed -n 's|.*[Cc]opy \(it \)\?to `\([^`]*\)/[^/`]*`.*|\2|p' "$t" | head -1)"
    [ -n "$dest" ] || continue
    dest="$(printf '%s' "$dest" | sed 's|<[^>]*>|X|g; s|/$||')"
    [ -d "$probe/$dest" ] || mkdir -p "$probe/$dest"
    n=$(( n + 1 ))
    local miss
    miss="$(awk -v d="$probe/$dest" '
      { while (match($0, /\]\([^)<]+\)/)) {
          l = substr($0, RSTART+2, RLENGTH-3); $0 = substr($0, RSTART+RLENGTH)
          sub(/#.*/, "", l)   # an anchored link is checked for its PATH (the anchor is not read)
          if (l == "" || l ~ /^http/ || l ~ /</) continue
          cmd = "test -e \"" d "/" l "\""
          if (system(cmd) != 0) printf "%s:%s ", FNR, l
      } }' "$t")"
    [ -z "$miss" ] || { bad=$(( bad + 1 )); cf "$base declares it lands in '$dest' and these links do not resolve from there: $miss — they resolve from process/templates/ instead, which is where the file SITS, so they pass a link check run in the kit and are dead in every copy an adopter makes"; }

    # ── THE CLIMB CHECK, for the links the resolver above SKIPS (those holding a `<`
    # placeholder). A placeholder blocks resolution, not arithmetic: a link may climb no
    # further than its destination is deep.
    local depth climb over
    depth="$(printf '%s' "$dest" | awk -F/ '{print NF}')"
    over="$(awk -v d="$depth" -v D="$dest" '
      { while (match($0, /\]\([^)#]+\)/)) {
          l = substr($0, RSTART+2, RLENGTH-3); $0 = substr($0, RSTART+RLENGTH)
          if (l ~ /^http/ || l !~ /^\.\.\//) continue
          c = 0; t = l
          while (t ~ /^\.\.\//) { c++; sub(/^\.\.\//, "", t) }
          if (c > d) printf "%s:%s(climbs %d from a %d-deep destination) ", FNR, l, c, d
      } }' "$t")"
    [ -z "$over" ] || { bad=$(( bad + 1 )); cf "$base declares it lands in '$dest' and these links climb ABOVE the repository root from there: $over"; }
  done

  # ── INSTRUMENT CHECK: a loop that resolved no destinations reports every template clean.
  [ "$n" -ge 6 ] \
    || cf "only $n template(s) declared a destination this case could read — expected at least 6. The declaration wording changed, so 'every template's links resolve' is true of almost nothing"

  finish "all $n templates that declare where they land have links that resolve FROM THERE ($bad broken) — checked from the destination each template names, because a link written for where the template SITS passes every check run in the kit and is dead in every adopter's copy"
  teardown
}

# =============================================================================
# CASE — THE MERGE IS DECIDED BY THE ADOPTER'S OWN MANIFEST, AND THE FIRST RUN NEVER STAMPS.
#
# One adopted 0.1.0 tree, upgraded by the 0.2.0 kit's copy, run from a directory outside both:
# a file the adopter never touched is replaced; one they edited is left and its new version staged
# for merging; one the kit did not change is left, edited or not; a new file arrives; a file the kit
# dropped is listed, never deleted; a file in a directory the adopter removed is not resurrected.
# Every Action required entry newer than 0.1.0 is an item, and nothing older or unreleased is.
# process/KIT-VERSION and process/KIT-MANIFEST are untouched, and nothing is committed.
# =============================================================================
case_kit_upgrade_merges_by_the_shipped_manifest() {
  cf_reset
  make_sandbox
  local L="kit-upgrade.sh, run from outside the tree it upgrades, replaces only files the adopter never changed, stages the rest as checklist items with the notes' Action required entries, and neither stamps nor commits"
  _ku_subject_or_fail "$L" || return
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum) to build the fixture manifests with"; teardown; return; }
  _ku_pair 0.1.0 0.2.0
  local head0 cl="$KU_T/$KU_CHECKLIST_REL" f want
  head0="$(git -C "$KU_T" rev-parse HEAD)"
  cp "$KU_T/process/KIT-MANIFEST" "$SB_TMP/manifest-before"

  _ku_run up --into "$KU_T"
  [ "$(_ku_rc up)" = 0 ] || cf "the upgrade exited $(_ku_rc up), want 0: $(_ku_out up)"

  [ "$(cat "$KU_T/a.txt")" = a2 ] || cf "a.txt, never changed by the adopter, was not replaced: $(cat "$KU_T/a.txt")"
  [ "$(cat "$KU_T/b.txt")" = "b1 mine" ] || cf "b.txt, edited by the adopter, was OVERWRITTEN: $(cat "$KU_T/b.txt")"
  [ "$(cat "$KU_T/.kit-upgrade/files/b.txt.kit-new" 2>/dev/null)" = b2 ] || cf "b.txt's new version is not staged at .kit-upgrade/files/b.txt.kit-new"
  [ "$(cat "$KU_T/d.txt")" = "d1 mine" ] || cf "d.txt, which the kit did not change, is not the adopter's: $(cat "$KU_T/d.txt")"
  [ "$(cat "$KU_T/e.txt" 2>/dev/null)" = e1 ] || cf "e.txt, new upstream, was not added"
  [ -f "$KU_T/c.txt" ] || cf "c.txt, dropped upstream, was DELETED — a removal is listed, never applied"
  [ ! -e "$KU_T/sub" ] || cf "sub/, which the adopter removed, was recreated: $(find "$KU_T/sub" -type f | tr '\n' ' ')"
  [ -f "$KU_T/scripts/kit-upgrade.sh" ] || cf "the new kit's own scripts/kit-upgrade.sh did not arrive, so the next upgrade and --finish have no copy in the tree"
  [ "$(cat "$KU_T/process/KIT-VERSION")" = 0.1.0 ] || cf "the FIRST run stamped process/KIT-VERSION: $(cat "$KU_T/process/KIT-VERSION")"
  cmp -s "$KU_T/process/KIT-MANIFEST" "$SB_TMP/manifest-before" || cf "the first run replaced process/KIT-MANIFEST — it is the merge base until --finish"
  [ "$(git -C "$KU_T" rev-parse HEAD)" = "$head0" ] || cf "the upgrade COMMITTED — it must leave the commit to the adopter's own board"
  [ -z "$(ls -A "$KU_ELSE")" ] || cf "the upgrade wrote into the directory it was run from: $(ls -A "$KU_ELSE" | tr '\n' ' ')"

  if [ ! -f "$cl" ]; then
    cf "no $KU_CHECKLIST_REL was written"
  else
    grep -qx 'target: 0.2.0' "$cl" || cf "the checklist does not name its target as 'target: 0.2.0'"
    for want in 'Item two-one' 'Item two-two, whose bold' 'merge b.txt' 'sub/f.txt' 'sub/g.txt' 'removed upstream: c.txt'; do
      grep -F -- "$want" "$cl" | grep '^- \[ \] ' >/dev/null || cf "no unmarked item carries '$want'"
    done
    for want in 'Old item' 'Unreleased item U1' 'Not an item' 'd.txt' 'a.txt' 'e.txt'; do
      grep -F -- "$want" "$cl" | grep '^- \[' >/dev/null && cf "an item carries '$want', which is no item of a 0.1.0 → 0.2.0 upgrade"
    done
    grep -F 'Item two-one' "$cl" | grep -F 'process/KIT-RELEASE-NOTES.md' >/dev/null \
      || cf "the Action required item does not name where its instruction lives"
  fi
  finish "$L"
  teardown
}

# THIS CASE REPORTS WHAT IT MEASURED, NOT WHO DID IT. A path that differs between t0 and t1
# may have been written by the harness or by a concurrent session in the same checkout, and
# no snapshot can tell them apart, so the output names both (instruments.md § A.4).
case_isolation() {
  cf_reset
  local after status_after records_after
  after="$(git -C "$REAL_REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "(no HEAD yet)")"
  [ "$after" = "$REAL_HEAD_BEFORE" ] \
    || cf "the real repo's HEAD MOVED during the run ($REAL_HEAD_BEFORE → $after). This harness never commits, so the likely cause is a concurrent session landing work in this checkout; a harness that somehow committed is the other, far less likely, candidate"
  # Compare the DELTA, not absolute cleanliness: a pre-existing dirty tree (e.g.
  # uncommitted board-script edits under active development) is fine — a board
  # surface must simply not CHANGE during a run.
  status_after="$(_board_status)"
  if [ "$status_after" != "$REAL_STATUS_BEFORE" ]; then
    cf "a board surface CHANGED during the run — two candidates, and this case cannot tell them apart: (1) the harness broke its own isolation and wrote outside its sandbox, or (2) something else wrote to this checkout while the run was in flight (a concurrent session, an editor, a watcher). Before/after status follows. If a peer holds this checkout, (2) is the likely one and the run's SKIP profile is also unreliable — re-measure on a quiet tree or a built kit. BEFORE: [${REAL_STATUS_BEFORE:-clean}] AFTER: [${status_after:-clean}]"
  fi
  # .progress-records/ is gitignored, so the comparison above cannot see it.
  records_after="$(_real_records)"
  if [ "$records_after" != "$REAL_RECORDS_BEFORE" ]; then
    cf "the project's .progress-records/ CHANGED during the run — the harness writes its records to its own scratch (KIT_PROGRESS_DIR), so either a fixture's script ran with that override cleared, or something else wrote a record while the run was in flight (a seat working in this checkout). Lines before: $(printf '%s' "$REAL_RECORDS_BEFORE" | wc -l | tr -d ' ') after: $(printf '%s' "$records_after" | wc -l | tr -d ' ')"
  fi
  finish "isolation: the real repo's HEAD and its WHOLE WORKING TREE — every path git reports, not a named subset — are unchanged across the run, as is the project's .progress-records/ (names and bytes), with scripts/test/ excluded as the harness's own home. The span is the whole tree because this harness READS far more of it than any list of surfaces named in advance; a narrower span reports the absence of findings it could not have made. Attribution is out of scope: a path that differs between t0 and t1 does not say who wrote it (see the case's note)"
}
