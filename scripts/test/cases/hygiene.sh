# KIT-CLASS: MIXED — self-test harness, hygiene-instrument cases. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/hygiene.sh — sourced by scripts/test/run.sh, never run on its own.
# What the advisory instruments under scripts/hygiene/ say about what they read: a root that is not
# there is refused, a probe is not satisfied by the instrument's own source, and the walk's blind-spot
# line counts what it skips. Python is these instruments' declared carve-out: no interpreter SKIPs.
# =============================================================================

# =============================================================================
# CASE — THE STALENESS GREPS REFUSE A ROOT THAT IS NOT THERE, AND SAY HOW MUCH THEY READ.
#   (a) a nonexistent --root exits 2 and says so (it used to print "0 SUSPICION(S)" and exit 0);
#   (b) a root with nothing in scope reports n/a-control-failed, not a clean zero;
#   (c) CONTROL: a root with one file in scope prints the count and the suspicion list as before;
#   (d) a path outside the tree is not a landed artifact (an absolute token used to be statted
#       outside the root, pathlib discarding the root for it), and the report states that artifact
#       paths are read from the repository root only.
# =============================================================================
case_staleness_greps_refuse_a_missing_root_and_say_how_much_they_read() {
  cf_reset
  local L="staleness_greps.py refuses a missing --root, reports n/a-control-failed over a root with nothing in scope, prints how many files it read, ignores an absolute artifact path, and says artifact paths are read from the root only"
  if ! command -v python3 >/dev/null 2>&1; then skp "$L" "python3 absent — these are advisory instruments and Python is their declared carve-out"; return; fi
  make_sandbox
  local hy="$REAL_SCRIPTS/hygiene/staleness_greps.py" root="$SB_TMP/sg" outside="$SB_TMP/outside" rc out
  if [ ! -f "$hy" ]; then skp "$L" "scripts/hygiene/staleness_greps.py absent"; teardown; return; fi
  _sg() { rc=0; out="$( cd "$SB_TMP" && PYTHONDONTWRITEBYTECODE=1 python3 -I "$hy" "$@" 2>&1 )" || rc=$?; }
  _sg --root "$SB_TMP/no-such-root"
  { [ "$rc" -eq 2 ] && printf '%s\n' "$out" | grep -F 'not a directory' >/dev/null; } \
    || cf "(a) a nonexistent --root exited $rc, want 2 with 'not a directory': $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  mkdir -p "$root"
  _sg --root "$root"
  { [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -F 'n/a-control-failed' >/dev/null && ! printf '%s\n' "$out" | grep -F '(no suspicion)' >/dev/null; } \
    || cf "(b) a root with no file in scope was not reported n/a-control-failed, or still says '(no suspicion)' (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  mkdir -p "$root/process" "$root/scripts" "$outside"
  printf 'ISSUE_PREFIX="${ISSUE_PREFIX:-PFX}"\nPRD_PREFIX="${PRD_PREFIX:-PRD}"\n' > "$root/scripts/config.sh"
  printf '# a note\nNothing is claimed here.\n' > "$root/process/note.md"
  _sg --root "$root"
  { [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -E 'staleness greps: 0 SUSPICION\(S\) .* 1 file\(s\) in scope' >/dev/null && printf '%s\n' "$out" | grep -F '(no suspicion)' >/dev/null; } \
    || cf "(c) control: a root with one file in scope did not print its count and '(no suspicion)' (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  printf '# outside\n' > "$outside/landed.md"
  printf 'The note %s does not exist yet.\n' "$outside/landed.md" > "$root/process/claim.md"
  _sg --root "$root"
  printf '%s\n' "$out" | grep -F "$outside/landed.md" | grep -F 'exists on disk' >/dev/null \
    && cf "(d) an absolute path outside the tree was read as a landed artifact: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$out" | grep -F 'artifact paths are read from the repository root only' >/dev/null \
    || cf "(d) the report does not say that artifact paths are read from the repository root only: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE REACHABILITY WALK'S SELF-TEST PROBE IS NOT SATISFIED BY THE INSTRUMENT'S OWN SOURCE.
# The probe is an extension-less file that must have a referrer in YOUR tree; the instrument's own source
# names it (it is the BLIND_SPOT_PROBE constant), so with the instruments in the tree an uncited probe
# passed on the instrument's say-so alone.
#   (a) a tree whose starter roots exist, whose probe file exists and which NOTHING but the instruments
#       cites: --self-test FAILS (it used to pass);
#   (b) CONTROL: the same tree with a script that cites the probe through a shell-variable path: PASS.
# =============================================================================
case_the_reachability_probe_is_not_satisfied_by_the_instruments_own_source() {
  cf_reset
  local L="reachability_walk.py --self-test fails when only the instruments cite the probe, and passes when a script of the tree does"
  if ! command -v python3 >/dev/null 2>&1; then skp "$L" "python3 absent — these are advisory instruments and Python is their declared carve-out"; return; fi
  make_sandbox
  local hy="$REAL_SCRIPTS/hygiene" root="$SB_TMP/rw" probe roots r out rc
  if [ ! -f "$hy/reachability_walk.py" ]; then skp "$L" "scripts/hygiene/reachability_walk.py absent"; teardown; return; fi
  probe="$(sed -n 's/^BLIND_SPOT_PROBE = "\(.*\)"$/\1/p' "$hy/reachability_walk.py" | head -1)"
  [ -n "$probe" ] || _fixture_die "case_the_reachability_probe_is_not_satisfied_by_the_instruments_own_source: no BLIND_SPOT_PROBE constant to read"
  roots="$(awk '/^STARTER_ROOTS = \[/ {f = 1; next} f && /^\]/ {exit} f { gsub(/[ ",]/, ""); print }' "$hy/reachability_walk.py")"
  [ -n "$roots" ] || _fixture_die "case_the_reachability_probe_is_not_satisfied_by_the_instruments_own_source: no STARTER_ROOTS to read"
  mkdir -p "$root/scripts/hygiene" "$(dirname "$root/$probe")"
  cp "$hy"/*.py "$root/scripts/hygiene/"
  for r in $roots; do mkdir -p "$(dirname "$root/$r")"; : > "$root/$r"; done
  printf '#!/bin/sh\n' > "$root/$probe"
  _rw() { rc=0; out="$( cd "$SB_TMP" && PYTHONDONTWRITEBYTECODE=1 python3 -I "$root/scripts/hygiene/reachability_walk.py" --self-test --root "$root" 2>&1 )" || rc=$?; }
  _rw
  { [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -F 'SELF-TEST FAIL' >/dev/null; } \
    || cf "(a) the probe is cited by nothing but the instruments and --self-test did not FAIL (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-260)"
  printf '#!/bin/sh\nHOOK_SRC="$ROOT/%s"\n' "$probe" > "$root/scripts/run.sh"
  _rw
  { [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -F 'SELF-TEST PASS' >/dev/null; } \
    || cf "(b) control: a script of the tree cites the probe and --self-test did not PASS (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-260)"
  finish "$L"
  teardown
}

# =============================================================================
# CASE — THE BLIND-SPOT LINE COUNTS EVERY SYMLINK IT SKIPS, AND LINKS WITH A SPACE OR A %20 RESOLVE.
#   (a) a file symlink, a symlink to a directory and a broken symlink are three skipped symlinks
#       (the line counted only the file one);
#   (b) `[x](a%20b.md)` and `[x](<a b.md>)` name the file `a b.md`: it has both referrers (it showed none);
#   (c) the line names the limit that remains.
# =============================================================================
case_the_blind_spot_line_counts_every_skipped_symlink_and_a_link_may_name_a_path_with_a_space() {
  cf_reset
  local L="the blind-spot line counts file, directory and broken symlinks, a link target written with %20 or in <...> resolves, and the line names the remaining limit"
  if ! command -v python3 >/dev/null 2>&1; then skp "$L" "python3 absent — these are advisory instruments and Python is their declared carve-out"; return; fi
  make_sandbox
  local hy="$REAL_SCRIPTS/hygiene/citation_index.py" root="$SB_TMP/ci" out rc plain
  if [ ! -f "$hy" ]; then skp "$L" "scripts/hygiene/citation_index.py absent"; teardown; return; fi
  mkdir -p "$root/sub"
  printf '# a\n' > "$root/a.md"; printf '# sub\n' > "$root/sub/s.md"; printf '# spaced\n' > "$root/a b.md"
  ln -s a.md "$root/link-to-file.md"; ln -s sub "$root/link-to-dir"; ln -s no-such-target.md "$root/broken.md"
  printf 'See [one](a%%20b.md) here.\n' > "$root/r1.md"
  printf 'See [two](<a b.md>) here.\n' > "$root/r2.md"
  rc=0; out="$( cd "$SB_TMP" && PYTHONDONTWRITEBYTECODE=1 python3 -I "$hy" --root "$root" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "citation_index.py over the fixture exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  plain="$out"
  printf '%s\n' "$out" | grep -F '(3 skipped in this run' >/dev/null \
    || cf "(a) the blind-spot line does not count three skipped symlinks (a file link, a directory link, a broken link): $(printf '%s\n' "$out" | grep 'BLIND SPOT: symlinks' | cut -c1-200)"
  rc=0; out="$( cd "$SB_TMP" && PYTHONDONTWRITEBYTECODE=1 python3 -I "$hy" --root "$root" --json "a b.md" 2>&1 )" || rc=$?
  printf '%s' "$out" | PYTHONDONTWRITEBYTECODE=1 python3 -c 'import json,sys; d=json.load(sys.stdin); r=d["rows"][0]; sys.exit(0 if sorted(r["exact"]) == ["r1.md", "r2.md"] else 1)' 2>/dev/null \
    || cf "(b) 'a b.md' is not cited by both r1.md (%20) and r2.md (<...>): $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-260)"
  printf '%s\n' "$plain" | grep -F 'percent-decoded' >/dev/null \
    || cf "(c) the blind-spot line does not name the link-target limit that remains (percent-decoded and <...> targets only): $(printf '%s\n' "$plain" | grep 'BLIND SPOT' | cut -c1-200 | tr '\n' '|')"
  finish "$L"
  teardown
}
