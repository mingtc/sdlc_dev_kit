# KIT-CLASS: MIXED — self-test harness, release cases. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/release.sh — sourced by scripts/test/run.sh, never run on its own.
# release.sh and the consumer updater, with the rel_* / run_release fixtures and has_release,
# which other families call.
# =============================================================================

# =============================================================================
# THE RELEASE FAMILY — driven through release.sh's DECLARED SEAMS.
#
# The frame ships with an empty config block, so each case fills it in inside the sandbox
# (two version files, quoted and bare; two release documents; optionally the publish
# config) and walks the real entry point. The cases are end to end because gates proven
# one at a time can still leave the full cut path unsatisfiable.
# =============================================================================
has_release() { [ -f "$REAL_SCRIPTS/release.sh" ]; }

# Insert a record after a config-array's opening line in the sandbox's release.sh. Both
# helpers assert (fixtures.sh's EVERY MUTATION ASSERTS): an anchor that misses would leave
# a case declaring nothing and passing.
rel_insert() {  # <array-name> <record-line>
  local rel="$SB_WORK/scripts/release.sh"
  grep -qE "^$1=\($" "$rel" \
    || _fixture_die "rel_insert: no '^$1=(' line in the sandbox's release.sh — the record '$2' was NOT inserted, so this case declares no $1."
  perl -i -pe 'BEGIN{$a=shift; $r=shift} $_ .= "  $r\n" if /^\Q$a\E=\($/' \
    "$1" "$2" "$rel"
  grep -qxF "  $2" "$rel" \
    || _fixture_die "rel_insert: '$2' is not in the sandbox's release.sh after the insert into $1."
}
rel_set() {     # <line-regex> <replacement-line>
  local rel="$SB_WORK/scripts/release.sh"
  grep -qE "^$(printf '%s' "$1" | sed 's/[][\.*^$(){}?+|/]/\\&/g')" "$rel" \
    || _fixture_die "rel_set: no line beginning '$1' in the sandbox's release.sh — it was NOT set to '$2', so this case runs against the shipped value."
  perl -i -pe 'BEGIN{$m=shift; $r=shift} s/^\Q$m\E.*$/$r/' "$1" "$2" "$rel"
  grep -qxF "$2" "$rel" \
    || _fixture_die "rel_set: the sandbox's release.sh does not carry '$2' after the set."
}

# Plant a mid-run kill immediately BEFORE the pushes, so what dies is a LEGITIMATE
# cut that has already made its local acts. ASSERTS, like rel_insert/rel_set above:
# an un-planted kill leaves the case testing a healthy run and reporting PASS.
rel_plant_midrun_kill() {
  local rel="$SB_WORK/scripts/release.sh"
  grep -qE '^echo ".*pushing commit \+ tag' "$rel" \
    || _fixture_die "rel_plant_midrun_kill: no push-announcement line in the sandbox's release.sh — the kill was NOT planted, so this case would test a healthy run."
  perl -i -pe 's|^(echo ".*pushing commit \+ tag)|exit 143  # planted mid-run kill\n$1|' "$rel"
  grep -q 'planted mid-run kill' "$rel" \
    || _fixture_die "rel_plant_midrun_kill: the sandbox's release.sh does not carry the planted kill after the edit."
}

# Seed the version-bearing files + both release documents. <doc1_target|none> [doc2_target|none]
# The pre-release version, read by the seeder and by the assertions, so both have one source.
SB_REL_PRE_VERSION="1.0.0"

seed_release_files() {
  local target="$1" notes_target="${2:-$1}"
  printf '%s\n' "$SB_REL_PRE_VERSION" > "$SB_WORK/VERSION"
  cat > "$SB_WORK/pkg.conf" <<'EOF'
[package]
name = "sandbox"
version = "PRE"
EOF
  perl -i -pe 'BEGIN{$v=shift} s/^version = "PRE"$/version = "$v"/' "$SB_REL_PRE_VERSION" "$SB_WORK/pkg.conf"
  grep -qF "version = \"$SB_REL_PRE_VERSION\"" "$SB_WORK/pkg.conf" \
    || _fixture_die "seed_release_files: pkg.conf does not carry the pre-release version — every 'was not mutated' assertion downstream would be about the wrong string."
  rel_insert VERSION_FILES '"VERSION||"'
  rel_insert VERSION_FILES '"pkg.conf|version = |\""'
  rel_insert RELEASE_DOCS  '"CHANGELOG.md|the internal engineering log"'
  rel_insert RELEASE_DOCS  '"NOTES.md|the consumer-facing filtered notes"'
  seed_release_doc "$SB_WORK/CHANGELOG.md" "Changelog" "$target"
  seed_release_doc "$SB_WORK/NOTES.md"     "Release notes" "$notes_target"
}
seed_release_doc() {  # <path> <title> <target|none> [body-date]
  local path="$1" title="$2" target="$3" body_date="${4:-2026-07-24}"
  {
    echo "# $title"
    echo
    if [ "$target" != "none" ]; then
      echo "## [$target] — 2026-07-24"
      echo "seeded section, measured $body_date"
      echo
    fi
    echo "## [1.0.0] — 2026-07-23"
    echo "seed"
  } > "$path"
}
# The LAST "release.sh: …" refusal line from a captured run — the message whose
# wording the two document arms must NOT share.
release_refusal_line() { printf '%s\n' "$1" | grep '^release\.sh:' | tail -1; }

# THE STUB'S VERDICT LINE IS DERIVED FROM THE REAL PRODUCER, NOT RE-TYPED. check-board.sh is
# what the stub stands in for, not the subject (release.sh's gate (d) is), so reading its
# wording keeps the stand-in faithful without making an assertion circular. The needle is
# the substring release.sh greps, so a rewording that drops it kills the fixture at
# construction, naming the file.
_board_verdict() {   # <clean|drift> — the real producer's verdict line, verbatim
  local needle
  case "$1" in
    clean) needle='board-drift: clean' ;;
    *)     needle='board-drift: findings above' ;;
  esac
  # awk, not `sed | head`: a reader that exits early reports the producer's death under
  # pipefail (run.sh's PIPEFAIL RULE).
  awk -v n="$needle" '
    !seen && index($0, "echo \"── " n) {
      line = $0
      sub(/^[[:space:]]*echo "/, "", line)
      sub(/"[[:space:]]*$/, "", line)
      print line; seen = 1
    }
  ' "$REAL_REPO_ROOT/scripts/check-board.sh"
}

write_board_stub() {  # <path> clean|drift
  local verdict; verdict="$(_board_verdict "$2")"
  # ASSERT THE EXTRACTOR: an empty derivation writes a stub that prints nothing, and every
  # release case would then redden for the wrong reason.
  if [ -z "$verdict" ]; then
    echo "FIXTURE BROKEN: could not derive the '$2' verdict line from $REAL_REPO_ROOT/scripts/check-board.sh." >&2
    echo "                The stub would print nothing and every release case would redden for the wrong reason." >&2
    exit 1
  fi
  { printf '#!/usr/bin/env bash\n'; printf 'echo "%s"\n' "$verdict"; } > "$1"
  chmod +x "$1"
}

# Assert release.sh mutated NOTHING: the version files still hold the pre-release version
# locally and on the remote, and there is no tag at the cut version. The cut version is an
# argument, so the tag arm looks for the tag this cut would create.
# assert_release_unmutated <cut-version>
assert_release_unmutated() {  # <cut-version>
  local cut="${1:?assert_release_unmutated: the cut version is required — without it the tag arm looks for a tag nobody would have created and passes}"
  grep -qx "$SB_REL_PRE_VERSION" "$SB_WORK/VERSION" || cf "VERSION was mutated despite an aborted preflight"
  grep -qF "version = \"$SB_REL_PRE_VERSION\"" "$SB_WORK/pkg.conf" || cf "pkg.conf was mutated despite an aborted preflight"
  git -C "$SB_WORK" rev-parse -q --verify "refs/tags/v$cut" >/dev/null 2>&1 \
    && cf "tag v$cut was created despite an aborted preflight"
  origin_file_contains "VERSION" "$SB_REL_PRE_VERSION" || cf "a version bump reached the remote despite an aborted preflight"
}
run_release() {  # <version> [extra args…]
  ( cd "$SB_WORK" && RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=true \
      RELEASE_BOARD_CMD="$SB_TMP/board-clean.sh" \
      "$SB_WORK/scripts/release.sh" "$@" 2>&1 )
}

# =============================================================================
# CASE — THE PUBLICATION REMOTE HAS ONE SHARED NAME AND ONE NARROW OVERRIDE.
#
# release.sh reads ${RELEASE_REMOTE:-${KWT_REMOTE:-origin}}: narrow beats shared, shared
# beats the default, and neither name stops being read. Every assertion reads where the
# annotated tag landed, never a printed remote name.
# =============================================================================
case_release_honours_the_one_remote_name() {
  cf_reset
  if ! has_release; then skp "release.sh honours the shared publication remote" "scripts/release.sh absent"; return; fi
  local out rc fork

  _fork_sandbox() {
    make_sandbox; seed_release_files 1.1.0; publish_sandbox
    write_board_stub "$SB_TMP/board-clean.sh" clean
    fork="$SB_TMP/fork.git"
    git init --bare -q "$fork"
    git -C "$fork" symbolic-ref HEAD "refs/heads/$SB_TRUNK"
    git -C "$SB_WORK" remote add upstream "$fork" >/dev/null 2>&1
    git -C "$SB_WORK" push -q upstream "$SB_TRUNK" >/dev/null 2>&1
    git -C "$SB_WORK" remote set-head upstream "$SB_TRUNK" >/dev/null 2>&1
    # THE TWO REMOTES MUST BE DIFFERENT REPOSITORIES, or every leg below passes without
    # measuring anything at all.
    [ "$fork" != "$SB_ORIGIN" ] \
      || _fixture_die "case_release_honours_the_one_remote_name: the fork and origin are the same path."
    [ -n "$(git -C "$SB_WORK" ls-remote --heads "$fork" "$SB_TRUNK" 2>/dev/null)" ] \
      || _fixture_die "case_release_honours_the_one_remote_name: the fork carries no trunk, so a push there cannot be distinguished from a push nowhere."
    [ -z "$(git -C "$SB_WORK" ls-remote --tags "$fork" v1.1.0 2>/dev/null)" ] \
      || _fixture_die "case_release_honours_the_one_remote_name: the fork already carries v1.1.0 before any cut."
  }

  # --- (a) KWT_REMOTE alone retargets the release --------------------------
  _fork_sandbox
  rc=0
  out="$( cd "$SB_WORK" && KWT_REMOTE=upstream RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=true \
            RELEASE_BOARD_CMD="$SB_TMP/board-clean.sh" "$SB_WORK/scripts/release.sh" 1.1.0 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(a) the cut failed with KWT_REMOTE=upstream (rc=$rc): $(printf '%s' "$out" | tr '\n' '|')"
  [ -n "$(git -C "$SB_WORK" ls-remote --tags "$fork" v1.1.0 2>/dev/null)" ] \
    || cf "(a) the tag did NOT reach the fork — release.sh ignored KWT_REMOTE, so a fork's board and its releases go to different places"
  [ -z "$(git -C "$SB_WORK" ls-remote --tags "$SB_ORIGIN" v1.1.0 2>/dev/null)" ] \
    && : || cf "(a) the tag ALSO reached origin — the release was published to a remote the project did not name"
  teardown

  # --- (b) RELEASE_REMOTE still overrides, narrow beats shared -------------
  _fork_sandbox
  rc=0
  out="$( cd "$SB_WORK" && KWT_REMOTE=upstream RELEASE_REMOTE=origin RELEASE_TEST_ALLOW_STUB=1 \
            RELEASE_VERIFY_CMD=true RELEASE_BOARD_CMD="$SB_TMP/board-clean.sh" \
            "$SB_WORK/scripts/release.sh" 1.1.0 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(b) the cut failed with RELEASE_REMOTE=origin overriding KWT_REMOTE (rc=$rc): $(printf '%s' "$out" | tr '\n' '|')"
  [ -n "$(git -C "$SB_WORK" ls-remote --tags "$SB_ORIGIN" v1.1.0 2>/dev/null)" ] \
    || cf "(b) RELEASE_REMOTE did not win over KWT_REMOTE — the narrow override stopped being read, which silently ignores an adopter's existing setting"
  [ -z "$(git -C "$SB_WORK" ls-remote --tags "$fork" v1.1.0 2>/dev/null)" ] \
    && : || cf "(b) the tag also reached the fork — the override did not scope the push"
  teardown

  unset -f _fork_sandbox
  finish "release.sh honours the shared publication remote: KWT_REMOTE alone retargets the release push and tag to a fork (and not to origin), and RELEASE_REMOTE still overrides it for the release only — asserted on where the annotated tag physically landed"
}

# =============================================================================
# CASE — GATE (c) TEACHES THE SHAPE THAT ACTUALLY RUNS.
#
# Gate (c) word-splits a record and does not `eval` it, so an inline `sh -c '…'` is torn
# apart: only a command and its arguments work, which means a wrapper script. A gate has
# three outcomes (passed, failed, could not run), and the wrapper is where the third is
# said. Both legs assert an effect: the skip reaches the operator, and the untaught shape
# fails.
# =============================================================================
case_release_gate_c_skip_shape() {
  cf_reset
  if ! has_release; then skp "release.sh gate (c): the taught wrapper shape" "scripts/release.sh absent"; return; fi
  local out rc=0

  # --- (i) THE TAUGHT SHAPE: a wrapper script that self-skips loudly and exits 0. ---
  make_sandbox; seed_release_files 1.1.0
  printf '#!/usr/bin/env bash\nif [ -z "${CANARY_TOKEN:-}" ]; then\n  echo "SKIP: live read-canary — CANARY_TOKEN unset; the canary did not run."\n  exit 0\nfi\nexit 0\n' \
    > "$SB_WORK/canary"; chmod +x "$SB_WORK/canary"
  rel_insert PREFLIGHT_GATES '"live read-canary|./canary"'
  publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean

  rc=0; out="$(run_release 1.1.0 --dry-run)" || rc=$?
  [ "$rc" -eq 0 ] || cf "(skip) a self-skipping gate ABORTED the cut (rc=$rc) — the third state must not read as a failure: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  printf '%s\n' "$out" | grep 'SKIP: live read-canary' >/dev/null \
    || cf "(skip) the gate's third state never reached the operator — a canary that could not run passed SILENTLY, which is the false green this example exists to teach against: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # INSTRUMENT: the needle must DISCRIMINATE. If it also matches a run where the canary
  # DID run, leg (i) proves nothing.
  rc=0
  out="$( cd "$SB_WORK" && CANARY_TOKEN=x RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=true \
            RELEASE_BOARD_CMD="$SB_TMP/board-clean.sh" "$SB_WORK/scripts/release.sh" 1.1.0 --dry-run 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(ran) the canary with its credential PRESENT aborted the cut (rc=$rc)"
  printf '%s\n' "$out" | grep 'SKIP: live read-canary' >/dev/null \
    && cf "(instrument) the SKIP needle matched a run where the canary DID run — leg (i) is not measuring the skip"
  teardown

  # --- (ii) WHY THE EXAMPLE MUST BE A SCRIPT: gate (c) word-splits, it does not eval. --
  make_sandbox; seed_release_files 1.1.0
  # THE RECORD'S QUOTING IS WHAT IS BEING TESTED: `sh -c 'exit 1'` word-splits into [sh]
  # [-c] ['exit] [1'], so the gate fails because the quotes did not survive. It references
  # no variable: release.sh runs `set -u`, and an unset one would abort before gate (c).
  rel_insert PREFLIGHT_GATES "\"inline canary|sh -c 'exit 1'\""
  publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  rc=0; out="$(run_release 1.1.0 --dry-run)" || rc=$?
  [ "$rc" -ne 0 ] \
    || cf "(inline) an inline-shell gate record RAN — gate (c) is eval-ing its records, so the worked example may no longer need to teach the script shape, and this case's premise is gone"
  printf '%s\n' "$out" | grep 'inline canary' >/dev/null \
    || cf "(inline) the refusal does not name the gate that failed: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  assert_release_unmutated 1.1.0
  teardown

  finish "release.sh gate (c): a wrapper-script gate self-skips LOUDLY without aborting the cut (needle proven discriminating), and an inline-shell record does NOT run — which is why the worked example teaches a script"
}

# =============================================================================
# CASE — GATES (e) AND (f) SEE THE STATE THE DOCUMENTED WORKFLOW ACTUALLY PRODUCES.
#
# Gate (e): a `## [X.Y.Z]` heading over a placeholder is an empty section, and refuses.
# Gate (f): a heading with no date refuses, because nothing in the kit writes that date,
# so a dateless heading is the state the workflow produces. Both legs assert the cut is
# unmutated.
# =============================================================================
case_release_notes_section_is_more_than_a_heading() {
  cf_reset
  if ! has_release; then skp "release.sh gates (e)/(f): the section, not just its heading" "scripts/release.sh absent"; return; fi
  local out rc

  # --- (i) A HEADING OVER A PLACEHOLDER — gate (e). --------------------------
  make_sandbox; seed_release_files 1.1.0; publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  # The kit's own blanks convention is <angle brackets>, so the placeholder is
  # recognised BY SHAPE rather than by a word list somebody has to keep current.
  printf '# Release notes\n\n## [1.1.0] — 2026-07-24\n\n<what changed, for the consumer>\n\n## [1.0.0] — 2026-07-23\nseed\n' > "$SB_WORK/NOTES.md"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[Dev] a heading with nothing under it" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  rc=0; out="$(run_release 1.1.0)" || rc=$?
  [ "$rc" -ne 0 ] || cf "(e) a release cut with a notes section holding only a placeholder"
  printf '%s\n' "$out" | grep 'EMPTY' >/dev/null \
    || cf "(e) the refusal does not say the section is empty: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  printf '%s\n' "$out" | grep 'NOTES.md' >/dev/null \
    || cf "(e) the refusal does not name WHICH document is empty: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  assert_release_unmutated 1.1.0

  # INSTRUMENT / ABLATION: the same cut with real content must SUCCEED, or the refusal
  # above is satisfiable by a release.sh broken for any unrelated reason.
  printf '# Release notes\n\n## [1.1.0] — 2026-07-24\nsomething a consumer can read\n\n## [1.0.0] — 2026-07-23\nseed\n' > "$SB_WORK/NOTES.md"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[Dev] write the notes" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  rc=0; out="$(run_release 1.1.0)" || rc=$?
  [ "$rc" -eq 0 ] || cf "(e) ABLATION FAILED — the cut still refused once the section had real content, so the refusal above was not about emptiness: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  teardown

  # --- (ii) A HEADING WITH NO DATE — gate (f), the state the workflow produces.
  make_sandbox; seed_release_files 1.1.0; publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  printf '# Release notes\n\n## [1.1.0]\nreal content, measured 2026-07-24\n\n## [1.0.0] — 2026-07-23\nseed\n' > "$SB_WORK/NOTES.md"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[Dev] a dateless heading" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  rc=0; out="$(run_release 1.1.0)" || rc=$?
  [ "$rc" -ne 0 ] || cf "(f) a release cut from a section whose heading carries NO DATE — the state the documented workflow produces, since nothing in the kit writes that date"
  printf '%s\n' "$out" | grep 'NO DATE' >/dev/null \
    || cf "(f) the refusal does not say the date is missing: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  printf '%s\n' "$out" | grep 'nothing in the kit writes that date for you' >/dev/null \
    || cf "(f) the refusal does not tell the cutter that no tool will write it — without that they look for the tool that failed: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  assert_release_unmutated 1.1.0

  # INSTRUMENT: add the date and the SAME cut must succeed.
  printf '# Release notes\n\n## [1.1.0] — 2026-07-25\nreal content, measured 2026-07-24\n\n## [1.0.0] — 2026-07-23\nseed\n' > "$SB_WORK/NOTES.md"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[Dev] date it" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  rc=0; out="$(run_release 1.1.0)" || rc=$?
  [ "$rc" -eq 0 ] || cf "(f) ABLATION FAILED — the cut still refused once the heading carried a date: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  teardown

  finish "release.sh gates (e)/(f): a heading over a placeholder is refused naming the document, a heading with NO DATE is refused and says no tool will write it, and both cuts succeed once the section is real (ablation-proven both ways)"
}

# =============================================================================
# CASE — GATE (a) SEES A STALE CHECKOUT.
#
# A clean trunk BEHIND the remote must refuse, and its local checks alone cannot see that.
#
# THE TRACKING REF IS DELIBERATELY REWOUND before the behind leg. `git fetch <URL> <branch>`
# returns 0 without updating refs/remotes/<remote>/<branch>, so a comparison against the
# tracking ref passes a behind checkout whenever the remote is a URL. The rewind makes the
# fetch load-bearing.
#
# THE OFFLINE HALF: the sandbox origin is a local bare path, offline in the network sense
# and fetchable. Leg (v) proves the refusal does not fire there; leg (iv) proves the
# declared escape works when the remote cannot be reached. Leg (iv) is --dry-run because a
# full cut against a dead remote fails at the push regardless of this gate.
# =============================================================================
case_release_behind_the_remote() {
  cf_reset
  if ! has_release; then skp "release.sh gate (a): HEAD vs the remote tip" "scripts/release.sh absent"; return; fi
  local out rc

  # --- (control) the premise exists, AND a non-fetching reader cannot see it ---
  make_sandbox; seed_release_files 1.1.0; publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  echo "landed after this checkout" > "$SB_WORK/LATER.txt"
  git -C "$SB_WORK" add LATER.txt >/dev/null 2>&1
  sbcommit -qm "[Dev] a commit that lands after the cutter's last pull" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" reset -q --hard HEAD~1
  git -C "$SB_WORK" update-ref "refs/remotes/origin/$SB_TRUNK" "$(git -C "$SB_WORK" rev-parse HEAD)"

  [ -z "$(git -C "$SB_WORK" status --porcelain)" ] \
    || cf "(control) the tree is dirty — gate (a)'s SECOND check would refuse and this case would prove nothing"
  [ "$(git -C "$SB_WORK" symbolic-ref --short HEAD)" = "$SB_TRUNK" ] \
    || cf "(control) not on the trunk — gate (a)'s FIRST check would refuse first"
  [ "$(git -C "$SB_WORK" rev-list --count "HEAD..refs/remotes/origin/$SB_TRUNK" 2>/dev/null)" = "0" ] \
    || cf "(control) the tracking ref was NOT rewound — a non-fetching implementation would already see the gap, so this case cannot tell a real fetch from a stale read"
  [ "$(git -C "$SB_WORK" ls-remote origin "refs/heads/$SB_TRUNK" | awk '{print $1}')" \
      != "$(git -C "$SB_WORK" rev-parse HEAD)" ] \
    || cf "(control) the remote is NOT actually ahead — the premise does not exist"

  # --- (i) it refuses, names the DIRECTION and the way past, mutates nothing ---
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(i) a cut from a BEHIND checkout was allowed (rc=0)"
  printf '%s\n' "$out" | grep 'BEHIND' >/dev/null \
    || cf "(i) the refusal does not name the direction: $out"
  printf '%s\n' "$out" | grep -- 'git pull --ff-only' >/dev/null \
    || cf "(i) the refusal does not name the way past: $out"
  assert_release_unmutated 1.1.0

  # --- (ii) ABLATION: catch up and the SAME cut succeeds, naming the FULL tree -
  git -C "$SB_WORK" fetch -q origin "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" merge -q --ff-only FETCH_HEAD >/dev/null 2>&1
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(ii) ABLATION FAILED — still refused after catching up, so half (i) proves nothing: $out"
  git -C "$SB_WORK" cat-file -e "v1.1.0:LATER.txt" 2>/dev/null \
    || cf "(ii) the tag does not contain the commit that landed after the checkout — the gate refused for the wrong reason"
  teardown

  # --- (iii) A FAILED FETCH REFUSES, as a fact about the remote ----------------
  make_sandbox; seed_release_files 1.1.0; publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  git -C "$SB_WORK" remote set-url origin "$SB_TMP/gone.git" >/dev/null 2>&1
  git -C "$SB_WORK" fetch origin "$SB_TRUNK" >/dev/null 2>&1 \
    && cf "(control/iii) the broken remote is still fetchable — the failed-fetch leg measures nothing"
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(iii) a failed fetch did not refuse — the arm degrades silently, which is the class it exists to close"
  printf '%s\n' "$out" | grep -- '--no-fetch' >/dev/null \
    || cf "(iii) the refusal does not name the declared-offline escape: $out"
  printf '%s\n' "$out" | grep 'NOT ABOUT YOUR TREE' >/dev/null \
    || cf "(iii) the refusal does not attribute itself to the remote rather than the tree: $out"
  assert_release_unmutated 1.1.0

  # --- (iv) --no-fetch DECLARES the skip: gates green, and it SAYS SO ----------
  out="$(run_release 1.1.0 --no-fetch --dry-run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(iv) --no-fetch did not survive an unreachable remote (rc=$rc): $out"
  printf '%s\n' "$out" | grep 'NOT CONSULTED' >/dev/null \
    || cf "(iv) --no-fetch is SILENT — an undeclared skip is indistinguishable from a gate that ran: $out"
  assert_release_unmutated 1.1.0
  teardown

  # --- (v) THE LEGITIMATE OFFLINE CUT: a LOCAL BARE origin, NO flag ------------
  make_sandbox; seed_release_files 1.1.0; publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  case "$(git -C "$SB_WORK" remote get-url origin)" in
    http*|git@*|ssh:*|git:*) cf "(control/v) the sandbox origin is not a local path — this leg does not prove the offline case" ;;
  esac
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(v) an IN-SYNC cut against a LOCAL BARE origin was refused (rc=$rc) — the arm turned the kit's own day-one topology into a refusal: $out"
  teardown

  finish "release.sh gate (a): a clean trunk BEHIND the remote refuses naming the direction and the way past — tracking ref rewound, so only a REAL fetch can see it — and cuts once caught up (ablation: the tag contains the later commit); a FAILED fetch refuses naming --no-fetch and blames the remote not the tree; --no-fetch declares the skip loudly; an in-sync cut against a local bare origin is untouched"
}

case_release_happy() {
  cf_reset
  if ! has_release; then skp "release.sh happy path" "scripts/release.sh absent"; return; fi
  local out rc v
  for v in 1.1.0 v1.1.0; do
    make_sandbox
    seed_release_files 1.1.0
    publish_sandbox
    write_board_stub "$SB_TMP/board-clean.sh" clean
    out="$(run_release "$v")"; rc=$?
    [ "$rc" -eq 0 ] || cf "release.sh $v exited $rc (expected 0): $out"
    grep -qx '1.1.0' "$SB_WORK/VERSION" || cf "$v: the bare-form version file was not bumped"
    grep -q 'version = "1.1.0"' "$SB_WORK/pkg.conf" || cf "$v: the quoted-form version file was not bumped"
    [ "$(git -C "$SB_WORK" cat-file -t v1.1.0 2>/dev/null)" = "tag" ] \
      || cf "$v: v1.1.0 is not an ANNOTATED tag (expected a 'tag' object)"
    [ -n "$(git -C "$SB_WORK" ls-remote --tags origin v1.1.0 2>/dev/null)" ] \
      || cf "$v: the tag was not pushed to the remote"
    origin_file_contains "VERSION" '1.1.0' || cf "$v: the bump did not reach the trunk"
    origin_log_has_subject '^\[' || cf "$v: the release commit carries no [Role] prefix"
    teardown
  done
  finish "release.sh happy path: preflight → bump every declared version file (bare + quoted) → annotated tag pushed (X.Y.Z and vX.Y.Z)"
}

case_release_guards() {
  cf_reset
  if ! has_release; then skp "release.sh guards" "scripts/release.sh absent"; return; fi
  local out rc

  # (a) malformed target
  make_sandbox; seed_release_files 1.1.0; publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$(run_release 1.1)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(malformed) expected nonzero for '1.1', got 0"
  assert_release_unmutated 1.1.0   # (malformed) — all four arms, not just VERSION
  teardown

  # (b) the tag already exists
  make_sandbox; seed_release_files 1.1.0; publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  git -C "$SB_WORK" tag -a v1.1.0 -m "pre-existing" >/dev/null 2>&1
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(tag-exists) expected nonzero when v1.1.0 already exists, got 0"
  # (tag-exists) This leg pre-creates v1.1.0, so the tag arm cannot tell its fixture from
  # a created tag. The other three arms apply.
  grep -qx "$SB_REL_PRE_VERSION" "$SB_WORK/VERSION" || cf "(tag-exists) VERSION was mutated"
  grep -qF "version = \"$SB_REL_PRE_VERSION\"" "$SB_WORK/pkg.conf" || cf "(tag-exists) pkg.conf was mutated"
  origin_file_contains "VERSION" "$SB_REL_PRE_VERSION" || cf "(tag-exists) a bump reached the remote"
  teardown

  # (c) off-trunk
  make_sandbox; seed_release_files 1.1.0; publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  git -C "$SB_WORK" checkout -b feature/off-trunk "$SB_TRUNK" --quiet >/dev/null 2>&1
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(off-trunk) expected nonzero on a feature branch, got 0"
  assert_release_unmutated 1.1.0
  teardown

  # (d) dirty working tree
  make_sandbox; seed_release_files 1.1.0; publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  echo "dirty" > "$SB_WORK/DIRTY.txt"
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(dirty) expected nonzero on a dirty tree, got 0"
  assert_release_unmutated 1.1.0   # (dirty) — all four arms, not just VERSION
  teardown

  # (e) NO version files declared and VERSION_IN_TAG_ONLY unset → refuse. Tagging
  #     a commit whose declared version nobody moved is a silent lie.
  make_sandbox
  printf '1.0.0\n' > "$SB_WORK/VERSION"
  rel_insert RELEASE_DOCS '"CHANGELOG.md|the log"'
  seed_release_doc "$SB_WORK/CHANGELOG.md" "Changelog" 1.1.0
  publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(no-version-files) an undeclared version seam did not refuse"
  printf '%s' "$out" | grep 'VERSION_FILES' >/dev/null || cf "(no-version-files) the refusal does not name the seam: $out"
  teardown

  finish "release.sh guards: malformed / tag-exists / off-trunk / dirty / undeclared-version-seam all abort nonzero without mutating"
}

case_release_preflight_gates() {
  cf_reset
  if ! has_release; then skp "release.sh preflight gates" "scripts/release.sh absent"; return; fi
  local out rc

  # (b) verify.sh red
  make_sandbox; seed_release_files 1.1.0; publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$( cd "$SB_WORK" && RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=false RELEASE_BOARD_CMD="$SB_TMP/board-clean.sh" \
            "$SB_WORK/scripts/release.sh" 1.1.0 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(verify-red) expected nonzero, got 0"
  assert_release_unmutated 1.1.0
  teardown

  # (c) a DECLARED extra preflight gate, red
  make_sandbox; seed_release_files 1.1.0
  # Sandbox-local, for the portability reason the gate fixtures state: an absolute
  # system path that is absent returns 127, and 127 is UNRUNNABLE here, not FAIL.
  printf '#!/usr/bin/env bash\nexit 1\n' > "$SB_WORK/red-gate"; chmod +x "$SB_WORK/red-gate"
  rel_insert PREFLIGHT_GATES '"declared extra gate|./red-gate"'
  publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(extra-gate-red) a red declared gate did not abort the cut"
  printf '%s' "$out" | grep 'declared extra gate' >/dev/null \
    || cf "(extra-gate-red) the refusal does not name the gate that failed: $out"
  assert_release_unmutated 1.1.0
  teardown

  # (d) board drift
  make_sandbox; seed_release_files 1.1.0; publish_sandbox; write_board_stub "$SB_TMP/board-drift.sh" drift
  out="$( cd "$SB_WORK" && RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=true RELEASE_BOARD_CMD="$SB_TMP/board-drift.sh" \
            "$SB_WORK/scripts/release.sh" 1.1.0 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(board-drift) expected nonzero, got 0"
  assert_release_unmutated 1.1.0
  teardown

  finish "release.sh preflight gates: verify red / a declared extra gate red / board drift each abort nonzero before mutation"
}

# =============================================================================
# CASE — the release-document arms are INDEPENDENT, with DISTINCT refusals, and the
# header-date gate bites: a section dated before the newest date in its own body refuses.
# =============================================================================
case_release_doc_arms() {
  cf_reset
  if ! has_release; then skp "release.sh document arms" "scripts/release.sh absent"; return; fi
  local out rc first_line second_line

  # (1) doc2 documented, doc1 NOT → doc1's arm bites alone, naming only doc1.
  make_sandbox; seed_release_files none 1.1.0; publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(doc1-missing) expected nonzero with only doc2 documented, got 0"
  first_line="$(release_refusal_line "$out")"
  printf '%s' "$first_line" | grep 'CHANGELOG\.md' >/dev/null \
    || cf "(doc1-missing) the refusal does not name CHANGELOG.md: $first_line"
  printf '%s' "$first_line" | grep 'NOTES\.md' >/dev/null \
    && cf "(doc1-missing) the refusal names the OTHER document — the arms are conflated: $first_line"
  assert_release_unmutated 1.1.0
  # BOTH missing → exactly ONE refusal, from the first-declared arm (fail-fast).
  seed_release_doc "$SB_WORK/NOTES.md" "Release notes" none
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[Dev] drop the second doc section" >/dev/null 2>&1
  out="$(run_release 1.1.0)"; rc=$?
  local count; count="$(printf '%s\n' "$out" | grep -c '^release\.sh:')"
  [ "$count" -eq 1 ] || cf "(both-missing) expected 1 refusal line, got $count"
  teardown

  # (2) doc1 documented, doc2 NOT → RED, naming doc2 and the version; then GREEN
  #     when only doc2's section is restored (nothing else changes).
  make_sandbox; seed_release_files 1.1.0 none; publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(doc2-missing) expected nonzero — the second arm does not bite"
  second_line="$(release_refusal_line "$out")"
  printf '%s' "$second_line" | grep 'NOTES\.md' >/dev/null || cf "(doc2-missing) the refusal does not name NOTES.md: $second_line"
  printf '%s' "$second_line" | grep '1\.1\.0' >/dev/null || cf "(doc2-missing) the refusal does not name the version wanted: $second_line"
  [ "$first_line" != "$second_line" ] \
    || cf "(distinctness) both arms emit the SAME refusal: $second_line"
  assert_release_unmutated 1.1.0
  seed_release_doc "$SB_WORK/NOTES.md" "Release notes" 1.1.0
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[Dev] add the consumer-facing section" >/dev/null 2>&1
  # PUSHED: gate (a) requires HEAD to be the published trunk's tip, so the section commit
  # must reach the remote before the cut.
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(doc2-restored) the cut still aborted after restoring the section: $out"
  grep -qx '1.1.0' "$SB_WORK/VERSION" || cf "(doc2-restored) restoring the section did not unblock the cut"
  teardown

  # (3) the HEADER-DATE gate: a section dated BEFORE the newest date in its own
  #     body is refused, naming both dates and the file.
  make_sandbox; seed_release_files 1.1.0 1.1.0
  seed_release_doc "$SB_WORK/NOTES.md" "Release notes" 1.1.0 2026-09-30   # body date AFTER the header
  publish_sandbox; write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(header-date) a section dated before its own content was accepted"
  printf '%s' "$out" | grep '2026-09-30' >/dev/null || cf "(header-date) the refusal does not name the newest body date: $out"
  printf '%s' "$out" | grep 'NOTES\.md' >/dev/null || cf "(header-date) the refusal does not name the file: $out"
  printf '%s' "$out" | grep -i "CUTTER" >/dev/null || cf "(header-date) the refusal does not state whose date it is: $out"
  assert_release_unmutated 1.1.0
  # …and correcting the HEADER (never the measurement) unblocks it.
  perl -i -pe 's/^## \[1\.1\.0\] — 2026-07-24$/## [1.1.0] — 2026-09-30/' "$SB_WORK/NOTES.md"
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[Dev] date the section at the cut" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1   # gate (a) wants the published tip; see the note above
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(header-date) correcting the header did not unblock the cut: $out"
  teardown

  finish "release.sh document arms: independent, distinctly worded, one refusal on both-missing, and the header-date gate bites and clears"
}

# =============================================================================
# CASE — THE DISTRIBUTION BRANCH: the allowlist, ONE orphan commit, built AT THE
# TAG, a second publish REPLACES it, a dry run publishes NOTHING, and a publish
# failure leaves the release AUTHORITATIVE with a retry that exists.
# =============================================================================
write_build_stub() {  # <path>
  cat > "$1" <<'STUB'
#!/usr/bin/env bash
# A stand-in for a real build: the last arg is the output directory, and the
# artifact's CONTENT is derived from the tree being built — so a build at a
# different commit produces different bytes, which is what makes the
# byte-identity comparison meaningful rather than a tautology.
set -eu
outdir="${!#}"
mkdir -p "$outdir"
ver="$(head -1 ./VERSION)"
[ -n "$ver" ] || { echo "build stub: no VERSION in $(pwd)" >&2; exit 1; }
{
  echo "ARTIFACT sandbox $ver"
  echo "notes-marker: $(sed -n '3p' ./NOTES.md 2>/dev/null || echo none)"
} > "$outdir/sandbox-${ver}.pkg"
STUB
  chmod +x "$1"
}
enable_publish() {
  rel_set 'RELEASE_PUBLISH=false' 'RELEASE_PUBLISH=true'
  rel_set 'DIST_ARTIFACT_GLOB=' 'DIST_ARTIFACT_GLOB="sandbox-*.pkg"'
  rel_insert DIST_DOCS '"NOTES.md|sandbox-NOTES.md"'
}
run_release_publish() {  # <version> [extra args…]
  ( cd "$SB_WORK" && RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=true \
      RELEASE_BOARD_CMD="$SB_TMP/board-clean.sh" \
      RELEASE_BUILD_CMD="$SB_TMP/build-stub.sh" \
      "$SB_WORK/scripts/release.sh" "$@" 2>&1 )
}
dist_files()        { git -C "$SB_ORIGIN" ls-tree -r --name-only refs/heads/dist 2>/dev/null | sort; }
dist_commit_count() { git -C "$SB_ORIGIN" rev-list --count refs/heads/dist 2>/dev/null || echo 0; }

# =============================================================================
# CASE — THE SHIP MANIFEST IS DRIVEN AGAINST THE BUMP, NOT RETYPED BESIDE IT.
#
# Gate (g) hashes the files a project ships. A release rewrites the version inside them,
# so the gate normalises that value out with the bump's own substitution, which replaces
# the VALUE, not the line. One fixture drives both directions:
#   (a) bump a shipped version file — the cut PROCEEDS, because normalisation cancels it;
#   (b) append a comment after the closing quote on that same line — the cut REFUSES, with
#       nothing mutated, because that edit is not the version.
# A normaliser that cancelled the whole line would let (b) proceed.
# =============================================================================
case_release_ship_manifest_is_driven_against_the_bump() {
  cf_reset
  if ! has_release; then skp "the ship manifest is driven against the bump" "scripts/release.sh absent"; return; fi
  local out rc man

  # ── (a) A SHIPPED VERSION FILE IS BUMPED AND THE CUT PROCEEDS.
  make_sandbox
  seed_release_files 1.1.0
  man="release/shipped.sha256"
  mkdir -p "$SB_WORK/release"
  # The manifest comes from the shipped command: a hand-written hash would be a second
  # parser. Its draft is built from `git ls-files`, so the seeded files are staged first.
  git -C "$SB_WORK" add -A >/dev/null 2>&1 || true
  ( cd "$SB_WORK" && ./scripts/release.sh --approve-shipped >/dev/null 2>&1 ) || true
  [ -f "$SB_WORK/$man" ] \
    || _fixture_die "case_release_ship_manifest_is_driven_against_the_bump: --approve-shipped wrote no draft manifest, so there is nothing to drive."
  # Keep only the two version files: a manifest of the whole sandbox would churn on
  # anything else the run touches, and this case is about the version normalisation.
  grep -E '^[0-9a-f]+  (VERSION|pkg\.conf)$' "$SB_WORK/$man" > "$SB_WORK/$man.keep" 2>/dev/null || true
  mv "$SB_WORK/$man.keep" "$SB_WORK/$man"
  [ "$(wc -l < "$SB_WORK/$man" | tr -d ' ')" -eq 2 ] \
    || _fixture_die "case_release_ship_manifest_is_driven_against_the_bump: the trimmed manifest does not hold exactly the two version files, so neither arm below would be about the version."
  perl -i -pe 's/^SHIP_MANIFEST=""$/SHIP_MANIFEST="release\/shipped.sha256"/' "$SB_WORK/scripts/release.sh"
  grep -q 'SHIP_MANIFEST="release/shipped.sha256"' "$SB_WORK/scripts/release.sh" \
    || _fixture_die "case_release_ship_manifest_is_driven_against_the_bump: the SHIP_MANIFEST seam was not set in the sandbox, so gate (g) would not run and both arms would pass vacuously."
  publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -eq 0 ] \
    || cf "(a) the cut REFUSED with a shipped version file declared, exit $rc — the bump is normalised out of the hash, so bumping a shipped file must not wedge the release: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-260)"
  printf '%s' "$out" | grep 'gate (g)' >/dev/null \
    || cf "(a) gate (g) did not report at all, so the green above says nothing about the manifest: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  teardown

  # ── (b) A NON-VERSION EDIT ON THE SAME LINE AND THE CUT REFUSES, MUTATING NOTHING.
  make_sandbox
  seed_release_files 1.1.0
  mkdir -p "$SB_WORK/release"
  git -C "$SB_WORK" add -A >/dev/null 2>&1 || true
  ( cd "$SB_WORK" && ./scripts/release.sh --approve-shipped >/dev/null 2>&1 ) || true
  grep -E '^[0-9a-f]+  (VERSION|pkg\.conf)$' "$SB_WORK/$man" > "$SB_WORK/$man.keep" 2>/dev/null || true
  mv "$SB_WORK/$man.keep" "$SB_WORK/$man"
  perl -i -pe 's/^SHIP_MANIFEST=""$/SHIP_MANIFEST="release\/shipped.sha256"/' "$SB_WORK/scripts/release.sh"
  # THE PLANT: after the closing quote, on the very line the bump rewrites. Not the version.
  perl -i -pe 's{^(version = "[^"]*")$}{$1 // a sentence}' "$SB_WORK/pkg.conf"
  grep -q '// a sentence' "$SB_WORK/pkg.conf" \
    || _fixture_die "case_release_ship_manifest_is_driven_against_the_bump: the plant did not apply to pkg.conf, so arm (b) would be measuring an unmodified tree."
  publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] \
    || cf "(b) the cut PROCEEDED with a shipped file edited after the manifest was approved — a normaliser that cancels the whole line rather than the version value passes this: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-260)"
  printf '%s' "$out" | grep 'changed since the manifest was approved' >/dev/null \
    || cf "(b) the refusal does not say the shipped set changed, so an operator cannot tell gate (g) from any other refusal: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-220)"
  printf '%s' "$out" | grep 'approve-shipped' >/dev/null \
    || cf "(b) the refusal does not name the command that re-records the manifest, leaving the operator with a stop and no next step"
  [ "$(git -C "$SB_WORK" cat-file -t v1.1.0 2>/dev/null)" != "tag" ] \
    || cf "(b) gate (g) refused AFTER tagging — the whole point of running it in preflight is that nothing is mutated when it fires"
  teardown

  # ── (c) Publishing ON, no build, no manifest: the one configuration in which the ritual
  #        could hand anyone only the repository. It must refuse in preflight.
  make_sandbox
  seed_release_files 1.1.0
  perl -i -pe 's/^RELEASE_PUBLISH=false$/RELEASE_PUBLISH=true/' "$SB_WORK/scripts/release.sh"
  grep -q '^RELEASE_PUBLISH=true' "$SB_WORK/scripts/release.sh" \
    || _fixture_die "case_release_ship_manifest_is_driven_against_the_bump: RELEASE_PUBLISH was not switched on, so arm (c) would measure the default and prove nothing."
  grep -q '^BUILD_COMMAND="\${RELEASE_BUILD_CMD:-}"' "$SB_WORK/scripts/release.sh" \
    || _fixture_die "case_release_ship_manifest_is_driven_against_the_bump: the sandbox declares a BUILD_COMMAND, so arm (c) is not the no-build configuration it is about."
  publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] \
    || cf "(c) the cut PROCEEDED with publishing ON, no build and no ship manifest — the only thing it could publish is the repository, including progress/, and nothing declared what may leave: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  printf '%s' "$out" | grep 'SHIP_MANIFEST is empty' >/dev/null \
    || cf "(c) the refusal does not name the empty seam, so an operator cannot tell which of the three conditions to change: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  printf '%s' "$out" | grep 'approve-shipped' >/dev/null \
    || cf "(c) the refusal does not name the command that drafts the manifest — a stop with no next step"
  [ "$(git -C "$SB_WORK" cat-file -t v1.1.0 2>/dev/null)" != "tag" ] \
    || cf "(c) the refusal came AFTER tagging"
  teardown

  finish "gate (g)'s hash normalisation is DRIVEN against bump_one's own expression through one fixture in both directions: bumping a declared shipped version file proceeds (the version is normalised out), while a non-version edit after the closing quote on that same line refuses in preflight with nothing tagged and names --approve-shipped. A normaliser that cancelled the whole line instead of the value would let the second arm proceed. And arm (c): publishing on, no build and no manifest is refused in preflight, naming the empty seam and the command that drafts one, with nothing tagged"
}

case_release_publish() {
  cf_reset
  if ! has_release; then skp "release.sh distribution branch" "scripts/release.sh absent"; return; fi
  local out rc files

  make_sandbox
  seed_release_files 1.1.0
  enable_publish
  publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  write_build_stub "$SB_TMP/build-stub.sh"

  # A DRY RUN publishes NOTHING…
  out="$(run_release_publish 1.1.0 --dry-run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "the dry run exited $rc (expected 0): $out"
  [ -z "$(git -C "$SB_ORIGIN" rev-parse -q --verify refs/heads/dist 2>/dev/null)" ] \
    || cf "a DRY RUN created the dist branch on the remote"
  printf '%s' "$out" | grep 'publish: building' >/dev/null && cf "a DRY RUN ran the build step: $out"
  assert_release_unmutated 1.1.0

  # …then a real run publishes everything ("nothing, then everything", so the dry-run
  # assertion cannot pass by the publish being broken outright).
  out="$(run_release_publish 1.1.0)"; rc=$?
  [ "$rc" -eq 0 ] || cf "the cut exited $rc (expected 0): $out"
  [ -n "$(git -C "$SB_WORK" ls-remote --tags origin v1.1.0 2>/dev/null)" ] \
    || cf "the tag was not pushed — the publish must come AFTER the tag push"
  printf '%s' "$out" | grep 'clone --branch dist --depth 1' >/dev/null \
    || cf "the run never printed the consumer clone line: $out"
  # THE ALLOWLIST, exactly.
  files="$(dist_files)"
  [ "$files" = "$(printf '%s\n' README.md sandbox-1.1.0.pkg sandbox-NOTES.md | sort)" ] \
    || cf "dist carries the wrong file set: $(printf '%s' "$files" | tr '\n' ' ')"
  printf '%s\n' "$files" | grep -E '^(scripts/|progress/|pkg\.conf|VERSION)$' >/dev/null \
    && cf "dist carries repo material it must never carry: $files"
  # BUILT AT THE TAG: the artifact's name carries the TAGGED version, which exists
  # only in the tag's tree, and it is byte-identical to a fresh build there.
  local a b
  a="$SB_TMP/from-dist.pkg"
  git -C "$SB_ORIGIN" show "refs/heads/dist:sandbox-1.1.0.pkg" > "$a" 2>/dev/null \
    || cf "could not read the published artifact off dist"
  grep -q 'ARTIFACT sandbox 1.1.0' "$a" || cf "the published artifact was not built at the tagged version"
  mkdir -p "$SB_TMP/tagbuild"
  git -C "$SB_WORK" worktree add --detach --quiet "$SB_TMP/tagtree" refs/tags/v1.1.0 2>/dev/null
  ( cd "$SB_TMP/tagtree" && "$SB_TMP/build-stub.sh" "$SB_TMP/tagbuild" ) >/dev/null 2>&1
  b="$SB_TMP/tagbuild/sandbox-1.1.0.pkg"
  if [ -f "$b" ]; then
    cmp -s "$a" "$b" || cf "the artifact on dist is NOT byte-identical to a build at the same tag"
  else
    cf "the control build at the tag produced nothing"
  fi
  git -C "$SB_WORK" worktree remove --force "$SB_TMP/tagtree" >/dev/null 2>&1 || true
  # REPLACE: exactly one commit, and no shared history with the trunk.
  [ "$(dist_commit_count)" = "1" ] || cf "dist has $(dist_commit_count) commits — the policy is ONE (replace)"
  git -C "$SB_ORIGIN" merge-base refs/heads/dist "refs/heads/$SB_TRUNK" >/dev/null 2>&1 \
    && cf "dist shares history with the trunk — it must be an ORPHAN"

  # A SECOND publish replaces it: still one commit, new artifact, OLD ONE GONE.
  seed_release_doc "$SB_WORK/CHANGELOG.md" "Changelog" 1.2.0
  seed_release_doc "$SB_WORK/NOTES.md"     "Release notes" 1.2.0
  git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -qm "[Dev] document 1.2.0" >/dev/null 2>&1
  # PUSHED: gate (a) requires HEAD to be the published trunk's tip (as above).
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  out="$(run_release_publish 1.2.0)"; rc=$?
  [ "$rc" -eq 0 ] || cf "the second cut exited $rc: $out"
  [ "$(dist_commit_count)" = "1" ] || cf "after a second publish dist has $(dist_commit_count) commits — replace means ONE"
  files="$(dist_files)"
  printf '%s\n' "$files" | grep 'sandbox-1.2.0.pkg' >/dev/null || cf "the second publish did not put the new artifact on dist"
  printf '%s\n' "$files" | grep 'sandbox-1.1.0.pkg' >/dev/null && cf "the OLD artifact is still on dist — replace must not accumulate"
  teardown

  finish "release.sh dist branch: dry run publishes nothing, the real run publishes the allowlist exactly as ONE orphan commit built AT the tag (byte-identical), and a second publish REPLACES it"
}

case_release_publish_recovery() {
  cf_reset
  if ! has_release; then skp "release.sh publish failure + recovery" "scripts/release.sh absent"; return; fi
  local out rc before after

  make_sandbox
  seed_release_files 1.1.0
  enable_publish
  publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  # A build stub that FAILS: the publish cannot produce an artifact, so it must
  # fail AFTER the tag push has already succeeded.
  printf '#!/usr/bin/env bash\nexit 1\n' > "$SB_TMP/build-stub.sh"; chmod +x "$SB_TMP/build-stub.sh"

  out="$(run_release_publish 1.1.0)"; rc=$?
  # The release is AUTHORITATIVE and intact.
  [ "$(git -C "$SB_WORK" cat-file -t v1.1.0 2>/dev/null)" = "tag" ] \
    || cf "the annotated tag was rolled back by a publish failure — it must never be"
  [ -n "$(git -C "$SB_WORK" ls-remote --tags origin v1.1.0 2>/dev/null)" ] \
    || cf "the tag is not on the remote after a publish failure"
  origin_file_contains "VERSION" '1.1.0' || cf "the version bump is missing from the trunk after a publish failure"
  [ -z "$(git -C "$SB_ORIGIN" rev-parse -q --verify refs/heads/dist 2>/dev/null)" ] \
    || cf "a failed publish left a dist branch behind"
  printf '%s' "$out" | grep -i 'RELEASE ITSELF SUCCEEDED' >/dev/null \
    || cf "the failure message does not say the release succeeded: $out"
  printf '%s' "$out" | grep -- '--publish-only' >/dev/null || cf "the failure message names no retry command: $out"

  # The retry it names must exist: a pointer to a missing flag is a dangling pointer.
  out="$( cd "$SB_WORK" && RELEASE_BUILD_CMD="$SB_TMP/build-stub.sh" \
            "$SB_WORK/scripts/release.sh" 1.1.0 --publish-only 2>&1 )"; rc=$?
  printf '%s' "$out" | grep -i "unknown option" >/dev/null && cf "--publish-only is advertised but not implemented: $out"
  [ "$rc" -ne 0 ] || cf "--publish-only reported success with a failing build stub: $out"

  # Make the build work; the retry republishes.
  write_build_stub "$SB_TMP/build-stub.sh"
  out="$( cd "$SB_WORK" && RELEASE_BUILD_CMD="$SB_TMP/build-stub.sh" \
            "$SB_WORK/scripts/release.sh" 1.1.0 --publish-only 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "--publish-only failed on an already-cut tag: $out"
  [ -n "$(git -C "$SB_ORIGIN" rev-parse -q --verify refs/heads/dist 2>/dev/null)" ] \
    || cf "--publish-only did not publish the dist branch"
  [ "$(dist_commit_count)" = "1" ] || cf "--publish-only produced $(dist_commit_count) commits"

  # --publish-only --dry-run PUSHES NOTHING. The --publish-only handler runs before the
  # dry-run stop point, so it must honour --dry-run itself; a rehearsal that pushed could
  # roll dist back to an older artifact. The assertion is the dist commit hash: the branch
  # already exists here, so an existence check would pass vacuously.
  before="$(git -C "$SB_ORIGIN" rev-parse -q --verify refs/heads/dist 2>/dev/null)"
  printf 'echo "build-marker: ROUND2" >> "$outdir/sandbox-${ver}.pkg"\n' >> "$SB_TMP/build-stub.sh"
  out="$( cd "$SB_WORK" && RELEASE_BUILD_CMD="$SB_TMP/build-stub.sh" \
            "$SB_WORK/scripts/release.sh" 1.1.0 --publish-only --dry-run 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(publish-only dry run) exited $rc: $out"
  after="$(git -C "$SB_ORIGIN" rev-parse -q --verify refs/heads/dist 2>/dev/null)"
  [ "$before" = "$after" ] || cf "(publish-only dry run) the dist ref MOVED during a rehearsal"
  git -C "$SB_ORIGIN" show "refs/heads/dist:sandbox-1.1.0.pkg" 2>/dev/null | grep 'ROUND2' >/dev/null \
    && cf "(publish-only dry run) the rehearsal republished the artifact"
  # The anti-vacuity control: a REAL --publish-only on the same sandbox moves it.
  out="$( cd "$SB_WORK" && RELEASE_BUILD_CMD="$SB_TMP/build-stub.sh" \
            "$SB_WORK/scripts/release.sh" 1.1.0 --publish-only 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(control) the real --publish-only exited $rc: $out"
  git -C "$SB_ORIGIN" show "refs/heads/dist:sandbox-1.1.0.pkg" 2>/dev/null | grep 'ROUND2' >/dev/null \
    || cf "(control) a real --publish-only did NOT republish — the rehearsal assertion proves nothing"
  teardown

  finish "release.sh publish failure: tag intact + on the remote, no half-published branch, the named --publish-only retry exists and works, and --publish-only --dry-run pushes NOTHING (ref hash unchanged, control-proven)"
}

# =============================================================================
# CASE — the LOCAL-ONLY state is printed as NORMAL output BEFORE the pushes, and every
# command it prints WORKS (doctrine/fix-execution.md § A.7, contracts/release-ritual.md
# § 2). A run killed between the tag and the pushes never reaches the failure branches,
# so the state must print on the healthy path. Arm (2) extracts the printed commands from
# the transcript and runs them, so recovery text that drifts fails here.
# =============================================================================
case_release_local_only_recovery() {
  cf_reset
  if ! has_release; then skp "release.sh local-only recovery" "scripts/release.sh absent"; return; fi
  local out rc pos_block pos_push c undo

  # (1) The healthy path prints it, and prints it BEFORE the pushes — and the DRY
  #     RUN does not, because a dry run makes nothing local to recover.
  make_sandbox; seed_release_files 1.1.0; publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$(run_release 1.1.0 --dry-run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(dry-run) exited $rc (expected 0): $out"
  printf '%s\n' "$out" | grep 'LOCAL ONLY' >/dev/null \
    && cf "(dry-run) printed the local-only recovery, but a dry run makes nothing local: $out"
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(healthy) exited $rc (expected 0): $out"
  printf '%s\n' "$out" | grep 'LOCAL ONLY' >/dev/null \
    || cf "(healthy) no local-only state printed between the tag and the pushes: $out"
  pos_block="$(printf '%s\n' "$out" | grep -n 'LOCAL ONLY' | head -1 | cut -d: -f1)"
  pos_push="$(printf '%s\n' "$out" | grep -n 'pushing commit + tag' | head -1 | cut -d: -f1)"
  { [ -n "$pos_block" ] && [ -n "$pos_push" ] && [ "$pos_block" -lt "$pos_push" ]; } \
    || cf "(healthy) the state is not printed BEFORE the push (state=$pos_block push=$pos_push): $out"
  teardown

  # (2) KILL the run between the local acts and the pushes — planted COMMITTED, so
  #     the clean-tree preflight still passes and a legitimate cut is what dies —
  #     then run the commands the transcript printed, VERBATIM.
  make_sandbox; seed_release_files 1.1.0; rel_plant_midrun_kill; publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -eq 143 ] || cf "(killed) the planted mid-run kill did not fire (exit $rc): $out"
  # The state the transcript CLAIMS must be the state on disk, or the text is a lie
  # that happens to be reassuring.
  [ "$(git -C "$SB_WORK" cat-file -t v1.1.0 2>/dev/null)" = "tag" ] \
    || cf "(killed) no local annotated tag — the recovery text's premise is false"
  [ -z "$(git -C "$SB_WORK" ls-remote --tags origin v1.1.0 2>/dev/null)" ] \
    || cf "(killed) the tag reached the remote before the pushes"
  origin_file_contains "VERSION" '1.1.0' \
    && cf "(killed) the bump reached the remote before the pushes"
  pos_block=0
  while IFS= read -r c; do
    [ -z "$c" ] && continue
    pos_block=$(( pos_block + 1 ))
    ( cd "$SB_WORK" && sh -c "$c" ) >/dev/null 2>&1 \
      || cf "(killed) a printed recovery command failed: $c"
  done < <(printf '%s\n' "$out" | sed -n 's|^ *\(git push .*\)$|\1|p')
  [ "$pos_block" -ge 2 ] \
    || cf "(killed) the printed recovery names $pos_block push command(s), expected the commit's and the tag's: $out"
  origin_file_contains "VERSION" '1.1.0' \
    || cf "(recovered) the printed commands did not put the bump on the trunk"
  [ -n "$(git -C "$SB_WORK" ls-remote --tags origin v1.1.0 2>/dev/null)" ] \
    || cf "(recovered) the printed commands did not push the tag"
  # The block's own warning: re-running the script is NOT one of the safe moves.
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(re-run) the script did not refuse once the tag existed"
  teardown

  # (3) The other half of the printed text — the undo. It is only valid because
  #     nothing has published, which is the fact the block exists to state.
  make_sandbox; seed_release_files 1.1.0; rel_plant_midrun_kill; publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  out="$(run_release 1.1.0)"; rc=$?
  [ "$rc" -eq 143 ] || cf "(undo) the planted mid-run kill did not fire (exit $rc): $out"
  undo="$(printf '%s\n' "$out" | sed -n 's|^ *\(git tag -d .*\)$|\1|p' | head -1)"
  [ -n "$undo" ] || cf "(undo) no undo command was printed: $out"
  if [ -n "$undo" ]; then
    ( cd "$SB_WORK" && sh -c "$undo" ) >/dev/null 2>&1 \
      || cf "(undo) the printed undo command failed: $undo"
    # (undo) ONE ARM ON PURPOSE: this leg made a real local cut, so assert_release_unmutated
    # does not apply. The printed undo's effect is asserted directly.
    grep -qx "$SB_REL_PRE_VERSION" "$SB_WORK/VERSION" || cf "(undo) the bump survived the printed undo"
    git -C "$SB_WORK" rev-parse -q --verify refs/tags/v1.1.0 >/dev/null 2>&1 \
      && cf "(undo) the tag survived the printed undo"
    [ -z "$(git -C "$SB_WORK" status --porcelain)" ] \
      || cf "(undo) the printed undo left the tree dirty"
  fi
  teardown

  finish "release.sh local-only recovery: the state + the finishing commands print as normal output BEFORE the pushes (and never on --dry-run), and every command printed — both pushes, the re-run refusal, the undo — does what the text says"
}

# =============================================================================
# CASE — A TEST-ONLY RELAXATION NEEDS ITS TEST-ONLY MARKER.
#
# self-test-harness.md § 2: "a test-only relaxation of a production rule is reachable
# ONLY behind an explicit marker that no production caller sets." RELEASE_VERIFY_CMD and
# RELEASE_BOARD_CMD override the two gates that decide whether a cut may happen, so
# without the marker they refuse, as finish-pr.sh's seams do.
#
# BOTH DIRECTIONS:
#   (i)  unmarked → refuse, before anything is written (no tag, no bump, HEAD still);
#   (ii) marked   → honored. Every other release case depends on it, and an
#        unconditional refusal would still pass (i).
# =============================================================================
case_release_stub_marker() {
  cf_reset
  if ! has_release; then skp "release.sh: gate-stubbing seams require the test-only marker" "scripts/release.sh absent"; return; fi
  make_sandbox
  seed_release_files 1.1.0
  write_board_stub "$SB_TMP/board-clean.sh" clean
  publish_sandbox

  local out rc before
  before="$(git -C "$SB_WORK" rev-parse HEAD)"

  # --- (i) UNMARKED: each seam alone must be refused, and write nothing -------
  out="$( cd "$SB_WORK" && RELEASE_VERIFY_CMD=true "$SB_WORK/scripts/release.sh" 1.1.0 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(i) RELEASE_VERIFY_CMD was honored with NO marker — an unmarked caller can skip the verify gate on a production cut: $out"
  printf '%s\n' "$out" | grep 'RELEASE_TEST_ALLOW_STUB' >/dev/null \
    || cf "(i) the refusal does not name the marker it requires: $out"
  printf '%s\n' "$out" | grep 'NOTHING WAS WRITTEN' >/dev/null \
    || cf "(i) the refusal does not state that nothing was written: $out"

  out="$( cd "$SB_WORK" && RELEASE_BOARD_CMD="$SB_TMP/board-clean.sh" "$SB_WORK/scripts/release.sh" 1.1.0 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(i) RELEASE_BOARD_CMD was honored with NO marker — the board-truth gate is stubbable on a production cut: $out"

  # Refused means refused: no tag, no version bump, HEAD unmoved, tree clean.
  [ -z "$(git -C "$SB_WORK" tag -l v1.1.0)" ] || cf "(i) a tag was created during a refusal"
  assert_release_unmutated 1.1.0   # (i) — all four arms, not just VERSION
  grep -qx "$SB_REL_PRE_VERSION" "$SB_WORK/VERSION" || cf "(i) VERSION reads $(cat "$SB_WORK/VERSION")"
  [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$before" ] || cf "(i) HEAD moved during a refusal"
  [ -z "$(git -C "$SB_WORK" status --porcelain)" ] || cf "(i) the tree was modified during a refusal"

  # --- (ii) MARKED: honored, so the refusal has not become unconditional ------
  out="$( cd "$SB_WORK" && RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=true \
            RELEASE_BOARD_CMD="$SB_TMP/board-clean.sh" \
            "$SB_WORK/scripts/release.sh" 1.1.0 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(ii) the MARKED invocation was refused too — the refusal is unconditional and every release case in this file depends on the seam: $out"
  grep -qx '1.1.0' "$SB_WORK/VERSION" || cf "(ii) the marked cut did not bump VERSION: $out"
  [ "$(git -C "$SB_WORK" cat-file -t v1.1.0 2>/dev/null)" = "tag" ] \
    || cf "(ii) the marked cut produced no annotated tag: $out"

  finish "release.sh: RELEASE_VERIFY_CMD / RELEASE_BOARD_CMD are REFUSED without RELEASE_TEST_ALLOW_STUB=1 (no tag, no bump, HEAD still, tree clean) and honored with it"
  teardown
}

case_release_bash_n() {
  cf_reset
  if ! has_release; then skp "release.sh bash -n" "scripts/release.sh absent"; return; fi
  bash -n "$REAL_SCRIPTS/release.sh" 2>/dev/null || cf "bash -n reported a syntax error in scripts/release.sh"
  finish "release.sh: bash -n clean (syntax valid)"
}

# =============================================================================
# CASE — release.sh completes a cut from a repo path CONTAINING A SPACE.
#
# The board gate runs "$SCRIPT_DIR/check-board.sh" by default. Expanded unquoted, a spaced
# repo path word-splits and the cut aborts on a false drift. Every other release case sets
# the seam to a space-free stub, so only this case drives the default gate from a spaced
# path.
# =============================================================================
case_release_spaced_path() {
  cf_reset
  if ! has_release; then skp "release.sh spaced repo path" "scripts/release.sh absent"; return; fi
  local out rc
  make_sandbox "work dir"
  seed_release_files 1.1.0
  # Pin the DEFAULT board gate deterministically: overwrite the copied
  # check-board.sh (which "$SCRIPT_DIR/check-board.sh" resolves to) with a clean
  # stub, committed via publish so the pre-cut tree stays clean.
  write_board_stub "$SB_WORK/scripts/check-board.sh" clean
  publish_sandbox

  # RELEASE_BOARD_CMD deliberately UNSET → the default path, from a spaced dir.
  out="$( cd "$SB_WORK" && RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=true "$SB_WORK/scripts/release.sh" 1.1.0 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] \
    || cf "release.sh aborted from a spaced repo path (the board gate word-split on the space?): rc=$rc: $out"
  grep -qx '1.1.0' "$SB_WORK/VERSION" || cf "the spaced-path cut did not complete"
  [ "$(git -C "$SB_WORK" cat-file -t v1.1.0 2>/dev/null)" = "tag" ] \
    || cf "no annotated tag from a spaced repo path"

  finish "release.sh completes the cut from a repo path containing a space (the board gate is quoted)"
  teardown
}

# =============================================================================
# CASE — THE CONSUMER-UPDATER FAMILY. It runs only when CONSUMER_SCRIPT names an
# executable: a vendoring/updater script is a DISTRIBUTION MODEL, not a kit
# feature. What the kit asserts is the SHAPE every such script owes
# (process/doctrine/distribution.md): --help exits 0 and says what it does, and a
# --check/dry-run mode reports without mutating. The project's own tests own its
# contents; this only keeps the seam honest.
# =============================================================================
case_consumer_updater() {
  cf_reset
  if [ -z "$CONSUMER_SCRIPT" ]; then
    skp "the consumer-updater family" "CONSUMER_SCRIPT is unset — this project declares no updater script"
    return
  fi
  if [ ! -x "$CONSUMER_SCRIPT" ]; then
    skp "the consumer-updater family" "CONSUMER_SCRIPT='$CONSUMER_SCRIPT' is not an executable"
    return
  fi
  local out rc
  bash -n "$CONSUMER_SCRIPT" 2>/dev/null || cf "bash -n reported a syntax error in $CONSUMER_SCRIPT"
  out="$("$CONSUMER_SCRIPT" --help 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || cf "--help exited $rc (a help flag must succeed)"
  [ -n "$out" ] || cf "--help printed nothing"
  make_sandbox
  publish_sandbox
  local before after
  before="$(git -C "$SB_WORK" rev-parse HEAD)"
  out="$( cd "$SB_WORK" && "$CONSUMER_SCRIPT" --check 2>&1 )" || true
  after="$(git -C "$SB_WORK" rev-parse HEAD)"
  [ "$before" = "$after" ] || cf "--check moved HEAD — a report mode must not mutate"
  [ -z "$(git -C "$SB_WORK" status --porcelain)" ] || cf "--check dirtied the tree — a report mode must not mutate"

  finish "the consumer-updater seam: syntax clean, --help exits 0 with output, --check reports without mutating"
  teardown
}

# =============================================================================
# CASE — A HOOK REJECTION BETWEEN THE BUMP AND THE COMMIT LEAVES NOTHING BEHIND.
#
# A commit-msg hook that rejects release.sh's commit must leave the version files restored,
# nothing staged and no tag. The trigger is the kit's own flow: narrowing the role set
# leaves release.sh's tag outside the hook's set, and kit-init does not stamp release.sh.
# The assertion is the state of the tree, not the message.
# =============================================================================
case_release_hook_rejection_leaves_no_bump() {
  cf_reset
  if ! has_release; then skp "a hook rejection between bump and commit leaves nothing behind" "scripts/release.sh absent"; return; fi
  make_sandbox
  seed_release_files 1.1.0
  publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  local out rc

  # BREAK THE COMMIT the way the kit's own flow does: a hook that rejects release.sh's role
  # tag only, since a hook refusing everything would fail earlier. Install it where git
  # looks: the kit points core.hooksPath at scripts/githooks, so .git/hooks is not consulted.
  local hookdir hook
  hookdir="$(git -C "$SB_WORK" config --get core.hooksPath 2>/dev/null || true)"
  [ -n "$hookdir" ] || hookdir=".git/hooks"
  case "$hookdir" in /*) hook="$hookdir/commit-msg" ;; *) hook="$SB_WORK/$hookdir/commit-msg" ;; esac
  mkdir -p "$(dirname "$hook")"
  printf '#!/usr/bin/env bash\ngrep -q "^\\[Architect\\]" "$1" && { echo "hook: [Architect] is not in this project'"'"'s role set" >&2; exit 1; }\nexit 0\n' > "$hook"
  chmod +x "$hook"
  # COMMIT THE HOOK: it lives inside the repository, and a dirty tree would refuse at the
  # cleanliness gate before the bump. --no-verify keeps the hook out of this fixture commit.
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  git -C "$SB_WORK" -c user.email=t@t -c user.name=t commit --no-verify -q -m "[PM] install a narrow role hook" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin HEAD >/dev/null 2>&1 || true

  rc=0; out="$( cd "$SB_WORK" && RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=true \
      RELEASE_BOARD_CMD="$SB_TMP/board-clean.sh" "$SB_WORK/scripts/release.sh" 1.1.0 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] \
    || cf "release.sh exited 0 with a commit-msg hook that rejects its own role tag — the commit cannot have happened"

  # ── THE STATE OF THE TREE. This is the case.
  grep -qx "$SB_REL_PRE_VERSION" "$SB_WORK/VERSION" \
    || cf "VERSION was left BUMPED on disk after the commit failed — it reads '$(cat "$SB_WORK/VERSION" 2>/dev/null)', and the next thing anyone does in this tree carries a version nobody released"
  grep -qF "version = \"$SB_REL_PRE_VERSION\"" "$SB_WORK/pkg.conf" \
    || cf "pkg.conf was left bumped on disk after the commit failed"
  [ -z "$(git -C "$SB_WORK" diff --cached --name-only 2>/dev/null)" ] \
    || cf "the bump is still STAGED after the commit failed — a later 'git commit' in this tree would carry it silently: $(git -C "$SB_WORK" diff --cached --name-only | tr '\n' ' ')"
  git -C "$SB_WORK" rev-parse -q --verify refs/tags/v1.1.0 >/dev/null 2>&1 \
    && cf "a tag was created even though the release commit failed"

  # …AND IT SAYS SO. Second, because a silent correct cleanup still leaves the operator
  # believing a release happened.
  printf '%s' "$out" | grep -i 'ABORTED between the version bump and the release commit' >/dev/null \
    || cf "the abort is not announced — the operator is left with a failed command and no account of what was undone: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  printf '%s' "$out" | grep -i 'RELEASE_ROLE' >/dev/null \
    || cf "the abort does not name the knob that fixes the likeliest cause"

  teardown

  # ── INSTRUMENT CHECK, IN ITS OWN SANDBOX: the assertions above are satisfied by a release
  #    that never ran. A successful cut pushes, and a shared origin would leave the leg
  #    above behind its remote, so gate (a) would refuse first.
  make_sandbox
  seed_release_files 1.1.0
  publish_sandbox
  write_board_stub "$SB_TMP/board-clean.sh" clean
  rc=0; out="$( cd "$SB_WORK" && RELEASE_TEST_ALLOW_STUB=1 RELEASE_VERIFY_CMD=true \
      RELEASE_BOARD_CMD="$SB_TMP/board-clean.sh" "$SB_WORK/scripts/release.sh" 1.1.0 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] \
    || cf "(instrument) the UNBROKEN fixture cannot cut (rc=$rc) — every 'nothing was left behind' assertion above is then free: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  grep -qx '1.1.0' "$SB_WORK/VERSION" \
    || cf "(instrument) a successful cut did not bump VERSION — the assertions above cannot tell a restore from a bump that never happened"

  finish "a commit-msg hook that rejects release.sh's role tag — the state the kit's own 'kit-init --roles' produces — aborts the cut with the version files restored on disk, nothing left staged, no tag, and an announcement naming both what was undone and the knob that fixes it"
  teardown
}

# =============================================================================
# CASE — assert_release_unmutated NAMES THE CUT IT IS GUARDING.
#
# The tag arm must look for the tag at the version it is handed, never a fixed literal, or
# a leg cutting another version passes by looking in the wrong place. The mutation is a
# tag and nothing else, so a green can come only from the arm under test.
# =============================================================================
case_release_unmutated_names_the_cut() {
  cf_reset
  if ! has_release; then skp "assert_release_unmutated names the cut it guards" "scripts/release.sh absent"; return; fi
  make_sandbox
  seed_release_files 1.1.0
  publish_sandbox

  # Run an assertion helper with this case's own findings set aside, and echo what IT
  # reported. cf appends to a global, so without this the helper's findings would be
  # indistinguishable from the case's.
  _cf_probe() { local saved="$_cf"; _cf=""; "$@"; local got="$_cf"; _cf="$saved"; printf '%s' "$got"; }

  # ── INSTRUMENT CHECK: on an untouched sandbox the helper reports NOTHING. Without
  #    this, "it fired" below is satisfied by a helper that fires on everything.
  local quiet; quiet="$(_cf_probe assert_release_unmutated 2.0.0)"
  [ -z "$quiet" ] \
    || cf "(instrument) assert_release_unmutated already reports on an UNTOUCHED sandbox, so every 'it fired' below would be free: $quiet"

  # THE MUTATION: a tag at the cut version, and only that.
  git -C "$SB_WORK" tag -a v2.0.0 -m 'planted' >/dev/null 2>&1
  git -C "$SB_WORK" rev-parse -q --verify refs/tags/v2.0.0 >/dev/null \
    || _fixture_die "case_release_unmutated_names_the_cut: the planted tag was not created — this sandbox has no committer identity, and the assertion below would pass by there being nothing to find."

  local got; got="$(_cf_probe assert_release_unmutated 2.0.0)"
  printf '%s' "$got" | grep -F 'v2.0.0' >/dev/null \
    || cf "a tag at the cut version sits in the sandbox and assert_release_unmutated 2.0.0 did not name it — the tag arm is looking somewhere other than the cut it was handed: '$got'"

  # …and it does NOT fire for a cut it was not handed. Otherwise the arm above could be
  # satisfied by a helper that reports every tag it finds.
  local other; other="$(_cf_probe assert_release_unmutated 3.0.0)"
  printf '%s' "$other" | grep -F 'v2.0.0' >/dev/null \
    && cf "assert_release_unmutated 3.0.0 reported the v2.0.0 tag — the arm is not scoped to the cut it was handed"

  # THE OTHER THREE ARMS still see their own subjects: mutate pkg.conf alone.
  perl -i -pe 's/^version = .*/version = "9.9.9"/' "$SB_WORK/pkg.conf"
  local pk; pk="$(_cf_probe assert_release_unmutated 3.0.0)"
  printf '%s' "$pk" | grep -F 'pkg.conf' >/dev/null \
    || cf "pkg.conf was mutated and the helper did not name it: '$pk'"

  unset -f _cf_probe
  finish "assert_release_unmutated checks the tag at the cut version it is HANDED — naming it when present, staying silent for a cut it was not handed — and its other arms still name their own subjects; the pre-release version comes from the seeder rather than a second literal"
  teardown
}
