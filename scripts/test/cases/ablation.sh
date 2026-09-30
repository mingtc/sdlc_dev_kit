# KIT-CLASS: MIXED — self-test harness, the '## Ablation' landing precondition. See
# process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/ablation.sh — sourced by scripts/test/run.sh, never run on its own.
# finish-pr.sh refuses a landing whose branch diff touches a project-declared TEST_GLOBS path
# with no well-formed '## Ablation' section (a real 'Broken:' and 'Red line:' line, not
# '<placeholder>'). TEST_GLOBS undeclared (the shipped empty state) makes the check UNRUNNABLE,
# reported on stdout, never a silent pass. A branch whose diff touches no declared test path
# lands with no '## Ablation' section at all.
# =============================================================================

# _declare_test_globs <glob> — plant TEST_GLOBS as EXACTLY one entry into the sandbox's
# config.sh, via _array_set_body (fixtures.sh): a whole-body replace, state-independent of
# whatever TEST_GLOBS currently holds (empty, a `# DECLARED EMPTY —` comment on a tree past day
# one, or a stray entry). _array_set_body's own postcondition reads the PARSED array, never a
# bare string the shipped comments above TEST_GLOBS also carry ("tests/*" appears in config.sh's
# own example comment).
_declare_test_globs() {
  local glob="$1" cfg="$SB_WORK/scripts/config.sh"
  _array_set_body "$cfg" TEST_GLOBS "  \"$glob\""
}

# =============================================================================
# CASE — UNDECLARED TEST_GLOBS (the shipped empty state): the check does not run, reported,
# never a silent pass. A branch touching what LOOKS like a test path still lands.
# =============================================================================
case_finish_pr_ablation_undeclared_test_globs_does_not_run() {
  cf_reset
  make_sandbox

  local id="$SB_PREFIX-661"
  seed_issue dev_complete "$id" undeclared chore "TEST_GLOBS left undeclared" "feature/$id-work"
  publish_sandbox
  git -C "$SB_WORK" branch "feature/${id}-work" "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" checkout -q "feature/${id}-work" >/dev/null 2>&1
  mkdir -p "$SB_WORK/tests"
  echo "a real change" > "$SB_WORK/tests/CHANGE661.txt"
  git -C "$SB_WORK" add tests/CHANGE661.txt >/dev/null 2>&1
  sbcommit -m "[Dev] ${id}: add a real change" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/${id}-work" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" checkout "$SB_TRUNK" --quiet >/dev/null 2>&1

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "undeclared TEST_GLOBS — finish-pr.sh exited $rc: $(printf '%s' "$out" | tail -8 | tr '\n' '|')"
  case "$out" in *"ABLATION_CHECK: did not run"*) : ;; *) cf "no 'ABLATION_CHECK: did not run' line on stdout — an undeclared TEST_GLOBS must say the check did not run, not pass silently: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  origin_has_path "progress/qa_complete/$id-undeclared.md" || cf "the card did not advance to qa_complete/"

  finish "finish-pr.sh: TEST_GLOBS undeclared (the shipped empty state) makes the ablation check UNRUNNABLE — reported as 'ABLATION_CHECK: did not run' on stdout, never a silent pass — and the landing proceeds"
  teardown
}

# =============================================================================
# CASE — A DECLARED TEST PATH TOUCHED, NO '## Ablation' SECTION AT ALL: refuses, named, with a
# countable record.
# =============================================================================
case_finish_pr_ablation_missing_section_refuses() {
  cf_reset
  make_sandbox
  _declare_test_globs 'tests/*'

  local id="$SB_PREFIX-662"
  seed_issue dev_complete "$id" nosection chore "Touches a test path, no Ablation section" "feature/$id-work"
  publish_sandbox
  git -C "$SB_WORK" branch "feature/${id}-work" "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" checkout -q "feature/${id}-work" >/dev/null 2>&1
  mkdir -p "$SB_WORK/tests"
  echo "a real change" > "$SB_WORK/tests/CHANGE662.txt"
  git -C "$SB_WORK" add tests/CHANGE662.txt >/dev/null 2>&1
  sbcommit -m "[Dev] ${id}: add a real change" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/${id}-work" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" checkout "$SB_TRUNK" --quiet >/dev/null 2>&1

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "a declared test path touched with no '## Ablation' section — finish-pr.sh exited 0"
  case "$out" in *"Ablation"*) : ;; *) cf "the refusal does not name 'Ablation': $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  origin_has_path "tests/CHANGE662.txt" && cf "the branch was merged before the refusal"
  origin_has_path "progress/qa_complete/$id-nosection.md" && cf "the card advanced despite the refusal"
  /usr/bin/grep -q 'refusal=ablation-missing' "$SB_TMP/rec"/*.tsv 2>/dev/null \
    || cf "no progress record carries refusal=ablation-missing: $(cat "$SB_TMP/rec"/*.tsv 2>/dev/null)"

  finish "finish-pr.sh refuses a landing whose branch diff touches a declared TEST_GLOBS path with no '## Ablation' section, before the merge, with a countable refusal=ablation-missing record"
  teardown
}

# =============================================================================
# CASE — A BRANCH CANNOT EMPTY THE LIST IT IS JUDGED BY: TEST_GLOBS is read from the trunk's copy
# as well as the branch's, so a branch that deletes the declaration still owes '## Ablation'.
# =============================================================================
case_finish_pr_ablation_branch_cannot_undeclare_test_globs() {
  cf_reset
  make_sandbox
  _declare_test_globs 'tests/*'

  local id="$SB_PREFIX-667"
  seed_issue dev_complete "$id" undeclare chore "Branch empties TEST_GLOBS and skips Ablation" "feature/$id-work"
  publish_sandbox
  git -C "$SB_WORK" branch "feature/${id}-work" "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" checkout -q "feature/${id}-work" >/dev/null 2>&1
  _array_set_body "$SB_WORK/scripts/config.sh" TEST_GLOBS
  grep -qxF '  "tests/*"' "$SB_WORK/scripts/config.sh" \
    && _fixture_die "case_finish_pr_ablation_branch_cannot_undeclare_test_globs: the branch's TEST_GLOBS was not emptied"
  mkdir -p "$SB_WORK/tests"
  echo "a real change" > "$SB_WORK/tests/CHANGE667.txt"
  git -C "$SB_WORK" add tests/CHANGE667.txt scripts/config.sh >/dev/null 2>&1
  sbcommit -m "[Dev] ${id}: add a real change" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/${id}-work" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" checkout "$SB_TRUNK" --quiet >/dev/null 2>&1

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "a branch that emptied TEST_GLOBS and touched a declared test path landed — finish-pr.sh exited 0"
  origin_has_path "tests/CHANGE667.txt" && cf "the branch was merged before the refusal"
  /usr/bin/grep -q 'refusal=ablation-missing' "$SB_TMP/rec"/*.tsv 2>/dev/null \
    || cf "no progress record carries refusal=ablation-missing: $(cat "$SB_TMP/rec"/*.tsv 2>/dev/null)"

  finish "finish-pr.sh still requires '## Ablation' when a branch empties TEST_GLOBS in its own config.sh: the trunk's declaration is read too"
  teardown
}

# =============================================================================
# CASE — A '## Ablation' SECTION PRESENT BUT NOT WELL FORMED (placeholder or empty fields)
# REFUSES.
# =============================================================================
case_finish_pr_ablation_malformed_section_refuses() {
  cf_reset
  make_sandbox
  _declare_test_globs 'tests/*'

  # (a) both fields still the template's own placeholder.
  local ida="$SB_PREFIX-663"
  seed_issue dev_complete "$ida" placeholder chore "Ablation section left as placeholder" "feature/$ida-work"
  local fa="$SB_WORK/progress/dev_complete/$ida-placeholder.md"
  perl -0pi -e 's/(## Acceptance Criteria\n\n- \[ \] AC1 — the sandbox.s seeded behaviour holds\.\n)/$1\n## Ablation\n\nBroken: <placeholder>\nRed line: <placeholder>\n/' "$fa"
  grep -qF 'Broken: <placeholder>' "$fa" \
    || _fixture_die "case_finish_pr_ablation_malformed_section_refuses: (a) the placeholder Ablation section was not planted"
  publish_sandbox
  git -C "$SB_WORK" branch "feature/${ida}-work" "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" checkout -q "feature/${ida}-work" >/dev/null 2>&1
  mkdir -p "$SB_WORK/tests"
  echo "a real change" > "$SB_WORK/tests/CHANGE663A.txt"
  git -C "$SB_WORK" add tests/CHANGE663A.txt >/dev/null 2>&1
  sbcommit -m "[Dev] ${ida}: add a real change" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/${ida}-work" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" checkout "$SB_TRUNK" --quiet >/dev/null 2>&1

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-a" "$SB_WORK/scripts/finish-pr.sh" "$ida" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) a placeholder Ablation section — finish-pr.sh exited 0"
  origin_has_path "tests/CHANGE663A.txt" && cf "(a) the branch was merged before the refusal"
  /usr/bin/grep -q 'refusal=ablation-malformed' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
    || cf "(a) no progress record carries refusal=ablation-malformed: $(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null)"

  # (b) 'Red line:' present but empty.
  local idb="$SB_PREFIX-664"
  seed_issue dev_complete "$idb" emptyred chore "Ablation Red line left empty" "feature/$idb-work"
  local fb="$SB_WORK/progress/dev_complete/$idb-emptyred.md"
  perl -0pi -e 's/(## Acceptance Criteria\n\n- \[ \] AC1 — the sandbox.s seeded behaviour holds\.\n)/$1\n## Ablation\n\nBroken: a real leak, planted beside the notes folder\nRed line: \n/' "$fb"
  grep -qF 'Broken: a real leak' "$fb" \
    || _fixture_die "case_finish_pr_ablation_malformed_section_refuses: (b) the empty-Red-line Ablation section was not planted"
  publish_sandbox
  git -C "$SB_WORK" branch "feature/${idb}-work" "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" checkout -q "feature/${idb}-work" >/dev/null 2>&1
  mkdir -p "$SB_WORK/tests"
  echo "a real change" > "$SB_WORK/tests/CHANGE663B.txt"
  git -C "$SB_WORK" add tests/CHANGE663B.txt >/dev/null 2>&1
  sbcommit -m "[Dev] ${idb}: add a real change" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/${idb}-work" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" checkout "$SB_TRUNK" --quiet >/dev/null 2>&1

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-b" "$SB_WORK/scripts/finish-pr.sh" "$idb" 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) an empty 'Red line:' field — finish-pr.sh exited 0"
  origin_has_path "tests/CHANGE663B.txt" && cf "(b) the branch was merged before the refusal"
  /usr/bin/grep -q 'refusal=ablation-malformed' "$SB_TMP/rec-b"/*.tsv 2>/dev/null \
    || cf "(b) no progress record carries refusal=ablation-malformed: $(cat "$SB_TMP/rec-b"/*.tsv 2>/dev/null)"

  finish "finish-pr.sh refuses a landing whose '## Ablation' section is present but not well formed — a placeholder or empty 'Broken:'/'Red line:' field — with a refusal=ablation-malformed record"
  teardown
}

# =============================================================================
# CASE — A BRANCH TOUCHING NO DECLARED TEST PATH LANDS WITH NO '## Ablation' SECTION AT ALL.
# =============================================================================
case_finish_pr_ablation_no_test_path_touched_lands_without_section() {
  cf_reset
  make_sandbox
  _declare_test_globs 'tests/*'

  local id="$SB_PREFIX-665"
  seed_issue dev_complete "$id" notest chore "Touches no declared test path" "feature/$id-work"
  publish_sandbox
  seed_branch "$id" work CHANGE665.txt

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "no declared test path touched, no '## Ablation' section — finish-pr.sh exited $rc: $(printf '%s' "$out" | tail -8 | tr '\n' '|')"
  case "$out" in *"ABLATION_CHECK: PASS"*"touches no declared test path"*) : ;; *) cf "no 'touches no declared test path' PASS line on stdout: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  origin_has_path "progress/qa_complete/$id-notest.md" || cf "the card did not advance to qa_complete/"
  origin_has_path "CHANGE665.txt" || cf "the squash-merged change is not on the trunk"

  finish "finish-pr.sh lands a card whose branch touches no declared TEST_GLOBS path, carrying no '## Ablation' section at all — the requirement is scoped to the diff, not to every landing"
  teardown
}

# =============================================================================
# CASE — THE GREEN PATH: a declared test path touched, WITH a well-formed '## Ablation'
# section, lands.
# =============================================================================
case_finish_pr_ablation_well_formed_lands() {
  cf_reset
  make_sandbox
  _declare_test_globs 'tests/*'

  local id="$SB_PREFIX-666"
  seed_issue dev_complete "$id" wellformed chore "A well-formed Ablation section" "feature/$id-work"
  local f="$SB_WORK/progress/dev_complete/$id-wellformed.md"
  perl -0pi -e 's/(## Acceptance Criteria\n\n- \[ \] AC1 — the sandbox.s seeded behaviour holds\.\n)/$1\n## Ablation\n\nBroken: the leak probe'"'"'s pattern, on a copy\nRed line: 3 findings became 0 on the ablated copy\n/' "$f"
  grep -qF 'Broken: the leak' "$f" \
    || _fixture_die "case_finish_pr_ablation_well_formed_lands: the well-formed Ablation section was not planted"
  publish_sandbox
  git -C "$SB_WORK" branch "feature/${id}-work" "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" checkout -q "feature/${id}-work" >/dev/null 2>&1
  mkdir -p "$SB_WORK/tests"
  echo "a real change" > "$SB_WORK/tests/CHANGE666.txt"
  git -C "$SB_WORK" add tests/CHANGE666.txt >/dev/null 2>&1
  sbcommit -m "[Dev] ${id}: add a real change" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/${id}-work" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" checkout "$SB_TRUNK" --quiet >/dev/null 2>&1

  local out rc
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" "$SB_WORK/scripts/finish-pr.sh" "$id" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "a well-formed '## Ablation' section — finish-pr.sh exited $rc: $(printf '%s' "$out" | tail -8 | tr '\n' '|')"
  case "$out" in *"ABLATION_CHECK: PASS"*"well formed"*) : ;; *) cf "no 'well formed' PASS line on stdout: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  origin_has_path "progress/qa_complete/$id-wellformed.md" || cf "the card did not advance to qa_complete/"
  origin_has_path "tests/CHANGE666.txt" || cf "the squash-merged change is not on the trunk"

  finish "finish-pr.sh lands a card whose branch touches a declared TEST_GLOBS path and carries a well-formed '## Ablation' section — a real, non-placeholder 'Broken:' and 'Red line:'"
  teardown
}
