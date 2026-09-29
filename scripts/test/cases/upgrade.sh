# KIT-CLASS: MIXED — self-test harness, kit-upgrade cases. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/upgrade.sh — sourced by scripts/test/run.sh, never run on its own.
# scripts/kit-upgrade.sh, driven over a fabricated old/new kit pair, and check-board.sh's
# upgrade arm. The pair is two tiny trees, each with its own process/KIT-MANIFEST,
# KIT-VERSION and KIT-RELEASE-NOTES.md; the script under test is the real one, copied into
# the NEW tree, because the NEW kit is where an adopter runs it from.
# =============================================================================

KU_CHECKLIST_REL='process/UPGRADE-CHECKLIST.md'

# _ku_sha <file> — the sha256 the build writes into a manifest, or nothing without a tool.
_ku_sha() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  fi
}
_ku_have_sha() { command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1; }

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
    for l in refuse.sh progress-record.sh usage.sh; do
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
  ( cd "$KU_ELSE" && env -u CLAUDE_PROJECT_DIR "$KU_NEW/scripts/kit-upgrade.sh" "$@" ) \
    >"$SB_TMP/$tag.out" 2>&1 || rc=$?
  printf '%s' "$rc" > "$SB_TMP/$tag.rc"
}
_ku_rc()  { cat "$SB_TMP/$1.rc"; }
_ku_out() { tr '\n' '|' < "$SB_TMP/$1.out" | cut -c1-300; }
# _ku_recs <records dir> <rule> — how many records carry refusal=<rule>.
_ku_recs() { cat "$1"/*.tsv 2>/dev/null | grep -cE "refusal=$2([[:space:]]|\$)" || true; }

# _ku_subject_or_fail <finish line> — the script under test must ship; its absence is a FAIL.
_ku_subject_or_fail() {
  [ -f "$REAL_SCRIPTS/kit-upgrade.sh" ] && return 0
  cf "scripts/kit-upgrade.sh is not in this kit — there is nothing that takes a newer kit into an adopted tree"
  finish "$1"; teardown
  return 1
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

# =============================================================================
# CASE — --finish STAMPS ONLY A DONE CHECKLIST, AND ITS REFUSAL IS COUNTABLE.
#
# With an item unmarked, --finish exits non-zero, leaves KIT-VERSION alone and writes one progress
# record carrying refusal=upgrade-checklist-unmarked INTO THE TARGET's record directory — run from
# elsewhere, the record must still land where the project's records are. Marked but uncommitted,
# it refuses too: removing the checklist would lose the marks. Marked and committed, it stamps
# KIT-VERSION and the manifest from the new kit, and removes the checklist and staging.
# =============================================================================
case_kit_upgrade_stamps_only_when_the_checklist_is_done() {
  cf_reset
  make_sandbox
  local L="kit-upgrade.sh --finish refuses while a checklist item is unmarked, leaving one refusal record in the target, and stamps KIT-VERSION and the manifest only when every item is marked"
  _ku_subject_or_fail "$L" || return
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum) to build the fixture manifests with"; teardown; return; }
  _ku_pair 0.1.0 0.2.0
  _ku_run up --into "$KU_T"
  [ "$(_ku_rc up)" = 0 ] || cf "the first run exited $(_ku_rc up): $(_ku_out up)"
  git -C "$KU_T" add -A >/dev/null 2>&1 && git -C "$KU_T" commit -qm "stage the upgrade" >/dev/null 2>&1

  local recs="$KU_T/.progress-records" n
  _ku_run fin1 --finish --into "$KU_T"
  [ "$(_ku_rc fin1)" != 0 ] || cf "--finish exited 0 with items unmarked"
  grep -F 'upgrade-checklist-unmarked' "$SB_TMP/fin1.out" >/dev/null || grep -Fi 'unmarked' "$SB_TMP/fin1.out" >/dev/null \
    || cf "--finish's refusal does not say an item is unmarked: $(_ku_out fin1)"
  n="$(_ku_recs "$recs" upgrade-checklist-unmarked)"
  [ "${n:-0}" -eq 1 ] || cf "$n record(s) carrying refusal=upgrade-checklist-unmarked in the target's .progress-records/, want 1: $(ls "$recs" 2>/dev/null | tr '\n' ' ')"
  [ "$(cat "$KU_T/process/KIT-VERSION")" = 0.1.0 ] || cf "--finish stamped with an item unmarked: $(cat "$KU_T/process/KIT-VERSION")"
  [ -f "$KU_T/$KU_CHECKLIST_REL" ] || cf "the refused --finish removed the checklist"

  # Every item marked, not yet committed: the marks are the record, so --finish refuses to remove them.
  sed 's/^- \[ \] /- [x] /' "$KU_T/$KU_CHECKLIST_REL" > "$SB_TMP/cl" && cp "$SB_TMP/cl" "$KU_T/$KU_CHECKLIST_REL"
  _ku_run finu --finish --into "$KU_T"
  [ "$(_ku_rc finu)" != 0 ] || cf "--finish removed a marked checklist that was never committed"
  [ "$(_ku_recs "$recs" upgrade-checklist-uncommitted)" -eq 1 ] || cf "no refusal=upgrade-checklist-uncommitted record: $(_ku_out finu)"
  git -C "$KU_T" commit -qam "mark the checklist" >/dev/null 2>&1
  _ku_run fin2 --finish --into "$KU_T"
  [ "$(_ku_rc fin2)" = 0 ] || cf "--finish with every item marked exited $(_ku_rc fin2): $(_ku_out fin2)"
  [ "$(cat "$KU_T/process/KIT-VERSION")" = 0.2.0 ] || cf "--finish did not stamp 0.2.0: $(cat "$KU_T/process/KIT-VERSION")"
  cmp -s "$KU_T/process/KIT-MANIFEST" "$KU_NEW/process/KIT-MANIFEST" || cf "--finish did not write the new kit's manifest"
  [ ! -e "$KU_T/$KU_CHECKLIST_REL" ] || cf "--finish left the checklist behind"
  [ ! -e "$KU_T/.kit-upgrade" ] || cf "--finish left .kit-upgrade/ behind"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — EVERY REFUSAL EXITS NON-ZERO AND LEAVES ONE RECORD NAMING ITS RULE.
#
# One arm per rule id the contract names: no --into; a target that is not a repository's top
# level; a source that is not an unpacked kit; a source that IS the target; a target dirty under a
# path the upgrade would write; an upgrade already in progress to another version; a target older
# than the tree; --finish with nothing in progress. Each asserts the tree was left as it was.
# =============================================================================
case_kit_upgrade_refuses_with_a_record() {
  cf_reset
  make_sandbox
  local L="kit-upgrade.sh refuses, exiting non-zero with one refusal=<rule-id> record, on every condition its contract names"
  _ku_subject_or_fail "$L" || return
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum) to build the fixture manifests with"; teardown; return; }
  _ku_pair 0.1.0 0.2.0
  local R="$SB_TMP/recs" tag rule want rc

  # _ku_refused <tag> <rule> <want status or 'nz'> — asserts status and exactly one record.
  _ku_refused() {
    rc="$(_ku_rc "$1")"
    if [ "$3" = nz ]; then [ "$rc" != 0 ] || cf "($1) exited 0, want a refusal: $(_ku_out "$1")"
    else [ "$rc" = "$3" ] || cf "($1) exited $rc, want $3: $(_ku_out "$1")"; fi
    [ "$(_ku_recs "$R" "$2")" -eq 1 ] || cf "($1) no single refusal=$2 record in $R: $(cat "$R"/*.tsv 2>/dev/null | tr '\n' '|' | cut -c1-200)"
    rm -rf "$R"
  }
  _ku_krun() { local t="$1"; shift; KIT_PROGRESS_DIR="$R" _ku_run "$t" "$@"; }

  _ku_krun a;                               _ku_refused a upgrade-no-target 2
  mkdir -p "$SB_TMP/plain";  _ku_krun b --into "$SB_TMP/plain";  _ku_refused b upgrade-target-not-a-repo nz
  _ku_krun b2 --into "$KU_T/process";                            _ku_refused b2 upgrade-target-not-a-repo nz

  # a source with no manifest beside it
  mkdir -p "$SB_TMP/nokit/scripts/lib"
  cp "$KU_NEW/scripts/kit-upgrade.sh" "$SB_TMP/nokit/scripts/"; cp "$KU_NEW/scripts/lib/"*.sh "$SB_TMP/nokit/scripts/lib/"
  rc=0; ( cd "$KU_ELSE" && KIT_PROGRESS_DIR="$R" "$SB_TMP/nokit/scripts/kit-upgrade.sh" --into "$KU_T" ) >"$SB_TMP/c.out" 2>&1 || rc=$?
  printf '%s' "$rc" > "$SB_TMP/c.rc";                             _ku_refused c upgrade-source-not-a-kit nz

  # the source is the target: the adopter's own copy, after a first upgrade, run at its own tree
  local self="$SB_TMP/selfkit"; cp -R "$KU_NEW" "$self"
  git init -q "$self" >/dev/null 2>&1
  rc=0; ( cd "$KU_ELSE" && KIT_PROGRESS_DIR="$R" "$self/scripts/kit-upgrade.sh" --into "$self" ) >"$SB_TMP/d.out" 2>&1 || rc=$?
  printf '%s' "$rc" > "$SB_TMP/d.rc";                             _ku_refused d upgrade-source-is-target nz

  # dirty under a path it would write: a.txt as shipped in the working tree, edited in HEAD
  printf 'a1 committed edit\n' > "$KU_T/a.txt"; git -C "$KU_T" commit -qam "edit a" >/dev/null 2>&1
  printf 'a1\n' > "$KU_T/a.txt"
  _ku_krun e --into "$KU_T";                                     _ku_refused e upgrade-target-dirty nz
  [ "$(cat "$KU_T/a.txt")" = a1 ] || cf "(e) the refused run changed a.txt"
  [ ! -e "$KU_T/$KU_CHECKLIST_REL" ] || cf "(e) the refused run wrote a checklist"
  git -C "$KU_T" checkout -q -- a.txt

  # an upgrade already in progress, to another version
  mkdir -p "$KU_T/.kit-upgrade"; printf '0.1.5\n' > "$KU_T/.kit-upgrade/KIT-VERSION"
  printf 'target: 0.1.5\n\n- [ ] something\n' > "$KU_T/$KU_CHECKLIST_REL"
  _ku_krun f --into "$KU_T";                                     _ku_refused f upgrade-checklist-other-version nz
  rm -rf "$KU_T/.kit-upgrade" "$KU_T/${KU_CHECKLIST_REL:?}"

  # --finish with nothing in progress
  _ku_krun g --finish --into "$KU_T";                            _ku_refused g upgrade-nothing-to-finish nz

  # a target older than the tree
  printf '0.3.0\n' > "$KU_T/process/KIT-VERSION"; git -C "$KU_T" commit -qam "pretend 0.3.0" >/dev/null 2>&1
  _ku_krun h --into "$KU_T";                                     _ku_refused h upgrade-target-older nz
  [ ! -e "$KU_T/$KU_CHECKLIST_REL" ] || cf "(h) the refused run wrote a checklist"
  [ -z "$(git -C "$KU_T" status --porcelain)" ] || cf "a refused run left the tree changed: $(git -C "$KU_T" status --porcelain | tr '\n' '|')"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — NOTHING STAGED FOR MERGING CAN BE READ AS LIVE CONFIGURATION.
#
# A staged copy sits inside the adopter's repository. Under its live name, a staged skill, agent
# doc, CLAUDE.md or AGENTS.md is loaded by a harness session as instructions, and a staged
# .gitignore or .gitattributes governs the staging tree for git. So merge items are planted at
# .claude/skills/x/SKILL.md, CLAUDE.md and .gitignore, and under .kit-upgrade/ no path may carry a
# `.claude` component or one of those basenames; each checklist item must name its staged copy,
# and that copy must exist and hold the new kit's bytes.
# =============================================================================
case_kit_upgrade_stages_nothing_live() {
  cf_reset
  make_sandbox
  local L="kit-upgrade.sh stages merge copies under names no harness or git reads as live: no .claude component, no CLAUDE.md, AGENTS.md, SKILL.md, .gitignore or .gitattributes basename under .kit-upgrade/, and each item names its staged copy exactly"
  _ku_subject_or_fail "$L" || return
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum) to build the fixture manifests with"; teardown; return; }
  KU_OLD="$SB_TMP/kit-old"; KU_NEW="$SB_TMP/kit-new"; KU_T="$SB_TMP/project"; KU_ELSE="$SB_TMP/elsewhere"
  mkdir -p "$KU_ELSE"
  local d r live="" cl="$SB_TMP/project/$KU_CHECKLIST_REL" staged
  _ku_kit "$KU_OLD" 0.1.0 old; _ku_kit "$KU_NEW" 0.2.0 new
  for d in "$KU_OLD" "$KU_NEW"; do
    mkdir -p "$d/.claude/skills/x"
    printf 'skill %s\n' "${d##*-}" > "$d/.claude/skills/x/SKILL.md"
    printf 'claude %s\n' "${d##*-}" > "$d/CLAUDE.md"
    printf '# %s\n*\n' "${d##*-}" > "$d/.gitignore"   # live, it would hide every staged sibling
    _ku_manifest "$d"
  done
  _ku_target "$KU_T" "$KU_OLD" >/dev/null 2>&1
  printf 'skill mine\n' > "$KU_T/.claude/skills/x/SKILL.md"; printf 'claude mine\n' > "$KU_T/CLAUDE.md"
  printf 'ignored-mine\n' > "$KU_T/.gitignore"
  git -C "$KU_T" add -A >/dev/null 2>&1 && git -C "$KU_T" commit -qm "more local law" >/dev/null 2>&1

  _ku_run up --into "$KU_T"
  [ "$(_ku_rc up)" = 0 ] || cf "the upgrade exited $(_ku_rc up): $(_ku_out up)"
  [ -d "$KU_T/.kit-upgrade" ] || _control_did_not_run "stage any merge copy (no .kit-upgrade/ was written)"
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    case "/$r" in */.claude/*|*/.claude) live="$live $r" ;; esac
    case "${r##*/}" in CLAUDE.md|AGENTS.md|SKILL.md|.gitignore|.gitattributes) live="$live $r" ;; esac
  done <<KU_LIVE_EOF
$(cd "$KU_T" && find .kit-upgrade | sed 's|^\./||')
KU_LIVE_EOF
  [ -z "$live" ] || cf "staged under a name a harness or git reads as live:$live"
  for r in .claude/skills/x/SKILL.md CLAUDE.md .gitignore; do
    staged="$(grep -F "merge $r " "$cl" 2>/dev/null | sed -n 's/.*the new copy is \([^ ]*\)$/\1/p')"
    if [ -z "$staged" ]; then
      cf "no merge item for $r names its staged copy"
    elif ! cmp -s "$KU_T/$staged" "$KU_NEW/$r"; then
      cf "the item for $r names $staged, which is not the new kit's copy"
    fi
  done
  [ "$(cat "$KU_T/CLAUDE.md")" = "claude mine" ] || cf "the adopter's CLAUDE.md was overwritten"
  local hidden; hidden="$(cd "$KU_T" && find .kit-upgrade -type f | sed 's|^\./||' | git check-ignore --stdin 2>/dev/null)"
  [ -z "$hidden" ] || cf "git ignores staged file(s), so committing the staging would silently drop them: $(printf '%s' "$hidden" | tr '\n' ' ')"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — A BUILD BETWEEN RELEASES IS READ AS ONE, ON EITHER SIDE.
#
# process/KIT-RELEASE-NOTES.md § How versions work: X.Y.Z+<tree> is a build after X.Y.Z whose
# newest notes section is Unreleased. From such a tree the next release's items may already be
# held, so they are listed and flagged; a target that is such a build brings its Unreleased items;
# two builds after one release differ only by Unreleased; a release is older than a build after it.
# =============================================================================
case_kit_upgrade_reads_a_between_release_version() {
  cf_reset
  make_sandbox
  local L="kit-upgrade.sh reads X.Y.Z+<tree> on either side: the next release's items flagged as possibly held from a build, Unreleased items listed for a build target, and a release refused as older than a build after it"
  _ku_subject_or_fail "$L" || return
  _ku_have_sha || { skp "$L" "no sha256 tool (shasum or sha256sum) to build the fixture manifests with"; teardown; return; }
  local cl
  _ku_held() { grep -F -- "$1" "$cl" | grep '^- \[ \] ' | grep -Fi 'may already' >/dev/null; }
  _ku_item() { grep -F -- "$1" "$cl" | grep '^- \[ \] ' >/dev/null; }

  # (a) from a build after 0.1.0, to the 0.2.0 release
  _ku_pair 0.1.0+1234abcd 0.2.0; cl="$KU_T/$KU_CHECKLIST_REL"
  _ku_run a --into "$KU_T"
  [ "$(_ku_rc a)" = 0 ] || cf "(a) exited $(_ku_rc a): $(_ku_out a)"
  _ku_held 'Item two-one' || cf "(a) from 0.1.0+1234abcd, [0.2.0]'s item is not flagged as possibly held"
  _ku_item 'Unreleased item U1' && cf "(a) a 0.2.0 release target listed an Unreleased item"

  # (b) from the 0.1.0 release, to a build after 0.2.0
  _ku_pair 0.1.0 0.2.0+abcdef12; cl="$KU_T/$KU_CHECKLIST_REL"
  _ku_run b --into "$KU_T"
  [ "$(_ku_rc b)" = 0 ] || cf "(b) exited $(_ku_rc b): $(_ku_out b)"
  _ku_item 'Item two-one' || cf "(b) [0.2.0]'s item is missing"
  _ku_held 'Item two-one' && cf "(b) from a release, [0.2.0]'s item is flagged as possibly held"
  _ku_item 'Unreleased item U1' || cf "(b) a build target did not list its Unreleased item"
  grep -qx 'target: 0.2.0+abcdef12' "$cl" || cf "(b) the checklist does not name the build target exactly"

  # (c) two builds after one release
  _ku_pair 0.2.0+11111111 0.2.0+22222222; cl="$KU_T/$KU_CHECKLIST_REL"
  _ku_run c --into "$KU_T"
  [ "$(_ku_rc c)" = 0 ] || cf "(c) exited $(_ku_rc c): $(_ku_out c)"
  _ku_held 'Unreleased item U1' || cf "(c) between two builds after 0.2.0, the Unreleased item is not flagged as possibly held"
  _ku_item 'Item two-one' && cf "(c) a build after 0.2.0 was given [0.2.0]'s item again"

  # (d) a release is older than a build after it
  _ku_pair 0.2.0+11111111 0.2.0
  _ku_run d --into "$KU_T"
  [ "$(_ku_rc d)" != 0 ] || cf "(d) 0.2.0+11111111 → 0.2.0 was not refused as older"
  grep -F 'upgrade-target-older' "$SB_TMP/d.out" >/dev/null || grep -Fi 'older' "$SB_TMP/d.out" >/dev/null \
    || cf "(d) the refusal does not say the target is older: $(_ku_out d)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — check-board.sh REPORTS AN OPEN UPGRADE, AND NEVER DECIDES THE VERDICT WITH IT.
#
# Its upgrade arm names the tree's KIT-VERSION and its form, and, while the checklist exists,
# the file and how many items are unmarked, with ⚠ while any is. It is marked `reports only`, so
# the verdict is the same with the arm cut out of a copy, and kit-init's filter drops its ⚠.
# =============================================================================
case_check_board_reports_an_open_upgrade() {
  cf_reset
  make_sandbox
  local L="check-board.sh's upgrade arm reports KIT-VERSION's form and an open checklist's unmarked items, advisory only"
  mkdir -p "$SB_WORK/process"
  printf '0.1.0+abcd1234\n' > "$SB_WORK/process/KIT-VERSION"
  printf 'target: 0.2.0\n\n- [ ] one\n- [x] two\n- [ ] three\n' > "$SB_WORK/$KU_CHECKLIST_REL"
  publish_sandbox
  local out sec one v1 v2 abl rc
  out="$(cb_run)"
  sec="$(printf '%s\n' "$out" | awk '/^\[[a-z]\] kit upgrade/{f=1; print; next} f && /^(\[[a-z]\]|──)/{exit} f')"
  one="$(printf '%s' "$sec" | tr '\n' '|')"
  if [ -z "$sec" ]; then
    cf "check-board.sh prints no '[x] kit upgrade' section"
  else
    printf '%s\n' "$sec" | grep -E '^\[[a-z]\] kit upgrade .*reports only' >/dev/null || cf "the header does not carry 'reports only': $one"
    printf '%s\n' "$sec" | grep -F '0.1.0+abcd1234' | grep -Fi 'between releases' >/dev/null \
      || cf "KIT-VERSION and its form are not reported: $one"
    printf '%s\n' "$sec" | grep '⚠' | grep -F "$KU_CHECKLIST_REL" | grep -F '2 of 3' >/dev/null \
      || cf "the open checklist is not reported with ⚠, its file and '2 of 3' unmarked: $one"
    printf '%s\n' "$sec" | grep -F '0.2.0' >/dev/null || cf "the checklist's target is not named: $one"
    v1="$(printf '%s\n' "$out" | grep '^── board-drift:')"
    abl="$SB_WORK/scripts/check-board-ablated.sh"
    awk '/^# BEGIN kit-upgrade arm/{skip=1} !skip{print} /^# END kit-upgrade arm/{skip=0}' "$SB_WORK/scripts/check-board.sh" > "$abl"; chmod +x "$abl"
    grep -q '\] kit upgrade' "$abl" && _control_did_not_run "delete the arm's marked block from a copy of check-board.sh"
    rc=0; v2="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR ./scripts/check-board-ablated.sh 2>&1 )" || rc=$?
    rm -f "$abl"
    v2="$(printf '%s\n' "$v2" | grep '^── board-drift:')"
    [ "$v1" = "$v2" ] || cf "the verdict moved with the arm: with '$v1', without '$v2'"
    local filt kept
    filt="$(awk '/KI_FINDINGS="\$\(printf/{f=1; next} f && /^[[:space:]]*'"'"' \| grep/{exit} f' "$SB_WORK/scripts/kit-init.sh")"
    if [ -z "$filt" ]; then
      _control_did_not_run "extract kit-init's advisory filter from kit-init.sh"
    else
      kept="$(printf '%s\n' "$out" | awk "$filt" | grep '⚠' | grep -F "$KU_CHECKLIST_REL" || true)"
      [ -z "$kept" ] || cf "kit-init's board self-check would count the open checklist as a finding: $kept"
    fi
  fi

  # every item marked: reported, no ⚠
  printf 'target: 0.2.0\n\n- [x] one\n- [x] two\n' > "$SB_WORK/$KU_CHECKLIST_REL"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[PM] mark" >/dev/null 2>&1; git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  sec="$(cb_run | awk '/^\[[a-z]\] kit upgrade/{f=1; print; next} f && /^(\[[a-z]\]|──)/{exit} f')"
  printf '%s\n' "$sec" | grep '⚠' >/dev/null && cf "a checklist with every item marked still carries ⚠: $(printf '%s' "$sec" | tr '\n' '|')"
  printf '%s\n' "$sec" | grep -F -- '--finish' >/dev/null || cf "a done checklist does not say to run --finish: $(printf '%s' "$sec" | tr '\n' '|')"

  # no checklist, a release: says so
  git -C "$SB_WORK" rm -q "$KU_CHECKLIST_REL" >/dev/null 2>&1; printf '0.2.0\n' > "$SB_WORK/process/KIT-VERSION"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[PM] finish" >/dev/null 2>&1; git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  sec="$(cb_run | awk '/^\[[a-z]\] kit upgrade/{f=1; print; next} f && /^(\[[a-z]\]|──)/{exit} f')"
  printf '%s\n' "$sec" | grep -F '0.2.0' | grep -Fi 'a release' >/dev/null || cf "a bare KIT-VERSION is not reported as a release: $(printf '%s' "$sec" | tr '\n' '|')"
  printf '%s\n' "$sec" | grep -Fi 'no upgrade in progress' >/dev/null || cf "no checklist is not reported as none in progress: $(printf '%s' "$sec" | tr '\n' '|')"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE SHIPPED kit-upgrade.sh, RUN AGAINST A TREE MADE FROM THIS SAME KIT, CHANGES NOTHING.
#
# The tree is every path process/KIT-MANIFEST names, copied from this kit with its manifest, and
# committed. Run from outside it, the upgrade must find every file current and the version equal:
# exit 0, no checklist, no staging, a clean status. It exercises the real manifest's shape.
# =============================================================================
case_kit_upgrade_from_the_built_kit_is_a_no_op() {
  cf_reset
  make_sandbox
  local L="the shipped kit-upgrade.sh, run from this kit against a tree made from it, is a no-op: exit 0, no checklist, no staging, a clean tree"
  _ku_subject_or_fail "$L" || return
  local man="$REAL_REPO_ROOT/process/KIT-MANIFEST" t="$SB_TMP/same" e="$SB_TMP/elsewhere" rel n=0 rc out
  mkdir -p "$t/process" "$e"
  while IFS= read -r rel; do
    [ -n "$rel" ] && [ -f "$REAL_REPO_ROOT/$rel" ] || continue
    mkdir -p "$t/$(dirname "$rel")" && cp -p "$REAL_REPO_ROOT/$rel" "$t/$rel" && n=$((n+1))
  done <<KU_SAME_EOF
$(grep -v '^#' "$man" | awk '{print $2}')
KU_SAME_EOF
  cp "$man" "$t/process/KIT-MANIFEST"
  [ "$n" -gt 0 ] || _fixture_die "case_kit_upgrade_from_the_built_kit_is_a_no_op: the manifest named no file present in this kit."
  git init -q "$t" && git -C "$t" config user.email t@sandbox.invalid && git -C "$t" config user.name T \
    && git -C "$t" config commit.gpgsign false && git -C "$t" config core.hooksPath /dev/null \
    && git -C "$t" add -A -f && git -C "$t" commit -qm same >/dev/null 2>&1 \
    || _fixture_die "case_kit_upgrade_from_the_built_kit_is_a_no_op: could not commit the copy."
  rc=0; out="$( cd "$e" && env -u CLAUDE_PROJECT_DIR KIT_PROGRESS_DIR="$SB_TMP/recs" "$REAL_SCRIPTS/kit-upgrade.sh" --into "$t" 2>&1 )" || rc=$?
  [ "$rc" = 0 ] || cf "exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  [ ! -e "$t/$KU_CHECKLIST_REL" ] || cf "a checklist was written for an upgrade to the same kit: $(tr '\n' '|' < "$t/$KU_CHECKLIST_REL" | cut -c1-300)"
  [ ! -e "$t/.kit-upgrade" ] || cf "files were staged for an upgrade to the same kit: $(find "$t/.kit-upgrade" -type f | tr '\n' ' ' | cut -c1-300)"
  [ -z "$(git -C "$t" status --porcelain)" ] || cf "the tree changed: $(git -C "$t" status --porcelain | tr '\n' '|' | cut -c1-300)"
  finish "$L ($n file(s) from process/KIT-MANIFEST)"
  teardown
}
