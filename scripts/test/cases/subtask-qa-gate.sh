# KIT-CLASS: MIXED — self-test harness, a slice's own QA Verdict / forks: / Ablation checks.
# See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/subtask-qa-gate.sh — sourced by scripts/test/run.sh, never run on its own.
# `subtask.sh move <id> qa_complete` refuses on the same conditions finish-pr.sh applies to a
# landing card — one shared parser, scripts/lib/qa-gate.sh.
# =============================================================================

# _seed_subtask <parent> <suffix> <status> <slug> <title> [<branch>] — a slice card shaped like
# SUBTASK.template.md's live fields: AC1, a well-formed QA Verdict table, forks: none, and an
# EMPTY '## Ablation' section header with no placeholder body (the shipped default section has
# placeholder Broken:/Red line: lines; most cases here want "no section at all" or "a well-formed
# one" and plant precisely, so this seeds withOUT an Ablation section — matching what a slice
# whose diff never touched a test path leaves it, since the template's own instruction says it
# is filled "only if" the diff touches one).
_seed_subtask() {
  local parent="$1" suffix="$2" status="$3" slug="$4" title="$5" branch="${6:-n/a}"
  local id="${parent}-${suffix}"
  local dir="$SB_WORK/progress/subtasks/${parent}/${status}"
  mkdir -p "$dir"
  local f="$dir/${id}-${slug}.md"
  cat > "$f" <<EOF
---
id: ${id}
type: subtask
parent: ${parent}
title: ${title}
size: S
prd: n/a
stories: []
branch: ${branch}
pr: null
created_at: 2026-01-01
created_by: Orchestrator
forks: none
---

# ${id} — ${title}

## Why this slice exists

Seeded for the sandbox self-test.

## Acceptance Criteria (sliced from the parent)

- [ ] AC1 — the sandbox's seeded behaviour holds.

## QA Verdict

| AC id | verdict | evidence kind | evidence pointer |
|---|---|---|---|
| AC1 | PASS | test | sandbox-gate-green |
| shadow-check | — | — | assertions removed: none |

## Out of Scope

- n/a

## Spec / Plan

- Plan: n/a

## Activity

- 2026-01-01 [Orchestrator] Created under ${parent} — decomposition slice ${suffix}.
EOF
  printf '%s' "$f"
}

# _seed_parent <id> [<status>] — the minimal parent card a subtask tree needs to exist under
# (subtask.sh move never reads the parent card itself, but a realistic tree has one).
_seed_parent() {
  local id="$1" status="${2:-in_progress}"
  seed_issue "$status" "$id" parent chore "Decomposed parent"
}

# =============================================================================
# CASE — A SLICE WITH NO '## QA Verdict' TABLE REFUSES THE MOVE TO qa_complete/, NAMED, WITH A
# COUNTABLE RECORD. RED FIRST: fails on any subtask.sh that does not call the shared check.
# =============================================================================
case_subtask_qa_verdict_missing_table_refuses() {
  cf_reset
  if ! has_issue_template; then skp "subtask.sh move <id> qa_complete refuses a slice with no '## QA Verdict' table" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  make_sandbox

  local p="$SB_PREFIX-670"
  _seed_parent "$p"
  local f; f="$(_seed_subtask "$p" s1 dev_complete notable "No QA Verdict table")"
  perl -0pi -e 's/## QA Verdict\n.*?\n\n(?=## Out of Scope)//s' "$f"
  grep -qE '^## QA Verdict' "$f" \
    && _fixture_die "case_subtask_qa_verdict_missing_table_refuses: the '## QA Verdict' heading survived the strip"
  publish_sandbox

  local out rc
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec" "$SB_WORK/scripts/subtask.sh" move "${p}-s1" qa_complete 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "no '## QA Verdict' table — subtask.sh move exited 0"
  case "$out" in *"QA Verdict"*) : ;; *) cf "the refusal does not name 'QA Verdict': $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "progress/subtasks/${p}/qa_complete/${p}-s1-notable.md" && cf "the slice advanced despite the refusal"
  origin_has_path "progress/subtasks/${p}/dev_complete/${p}-s1-notable.md" || cf "the slice left dev_complete/ despite the refusal"
  /usr/bin/grep -q 'refusal=qa-verdict-missing' "$SB_TMP/rec"/*.tsv 2>/dev/null \
    || cf "no progress record carries refusal=qa-verdict-missing: $(cat "$SB_TMP/rec"/*.tsv 2>/dev/null)"

  finish "subtask.sh move <id> qa_complete refuses a slice with no '## QA Verdict' table — before the git mv, with a countable refusal=qa-verdict-missing record"
  teardown
}

# =============================================================================
# CASE — A SLICE WITH NO 'forks:' FIELD REFUSES THE MOVE TO qa_complete/.
# =============================================================================
case_subtask_forks_missing_refuses() {
  cf_reset
  if ! has_issue_template; then skp "subtask.sh move <id> qa_complete refuses a slice with no 'forks:' field" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  make_sandbox

  local p="$SB_PREFIX-671"
  _seed_parent "$p"
  local f; f="$(_seed_subtask "$p" s1 dev_complete noforks "No forks field")"
  sed -i.bak '/^forks: none$/d' "$f"; rm -f "$f.bak"
  /usr/bin/grep -q '^forks:' "$f" \
    && _fixture_die "case_subtask_forks_missing_refuses: the forks: line survived the strip"
  publish_sandbox

  local out rc
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec" "$SB_WORK/scripts/subtask.sh" move "${p}-s1" qa_complete 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "no 'forks:' field — subtask.sh move exited 0"
  case "$out" in *"forks:"*) : ;; *) cf "the refusal does not name 'forks:': $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)" ;; esac
  origin_has_path "progress/subtasks/${p}/qa_complete/${p}-s1-noforks.md" && cf "the slice advanced despite the refusal"
  /usr/bin/grep -q 'refusal=forks-missing' "$SB_TMP/rec"/*.tsv 2>/dev/null \
    || cf "no progress record carries refusal=forks-missing: $(cat "$SB_TMP/rec"/*.tsv 2>/dev/null)"

  finish "subtask.sh move <id> qa_complete refuses a slice with no 'forks:' field, with a countable refusal=forks-missing record"
  teardown
}

# =============================================================================
# CASE — A SLICE WHOSE OWN BRANCH TOUCHES A DECLARED TEST PATH WITH NO '## Ablation' SECTION
# REFUSES. Proves the diff basis is the SLICE'S OWN branch: (a) 'feature/<id>-<slug>' checked
# out and pushed, with a change under a declared TEST_GLOBS path, and no Ablation section.
# =============================================================================
case_subtask_ablation_missing_section_refuses() {
  cf_reset
  if ! has_issue_template; then skp "subtask.sh move <id> qa_complete refuses a slice whose own branch diff touches a declared test path with no '## Ablation' section" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  make_sandbox
  _declare_test_globs 'tests/*'

  local p="$SB_PREFIX-672"
  _seed_parent "$p"
  local slice_branch="feature/${p}-s1-noablation"
  local f; f="$(_seed_subtask "$p" s1 dev_complete noablation "Touches a test path, no Ablation section" "$slice_branch")"
  publish_sandbox

  git -C "$SB_WORK" checkout -b "$slice_branch" "$SB_TRUNK" --quiet >/dev/null 2>&1
  mkdir -p "$SB_WORK/tests"
  echo "a real change" > "$SB_WORK/tests/CHANGE672.txt"
  git -C "$SB_WORK" add tests/CHANGE672.txt >/dev/null 2>&1
  sbcommit -m "[Dev] ${p}-s1: add a real change" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "$slice_branch" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" checkout "$SB_TRUNK" --quiet >/dev/null 2>&1

  local out rc
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec" "$SB_WORK/scripts/subtask.sh" move "${p}-s1" qa_complete 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "a declared test path touched on the slice's own branch, no '## Ablation' section — subtask.sh move exited 0"
  case "$out" in *"Ablation"*) : ;; *) cf "the refusal does not name 'Ablation': $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  origin_has_path "progress/subtasks/${p}/qa_complete/${p}-s1-noablation.md" && cf "the slice advanced despite the refusal"
  /usr/bin/grep -q 'refusal=ablation-missing' "$SB_TMP/rec"/*.tsv 2>/dev/null \
    || cf "no progress record carries refusal=ablation-missing: $(cat "$SB_TMP/rec"/*.tsv 2>/dev/null)"

  finish "subtask.sh move <id> qa_complete refuses a slice whose OWN branch diff touches a declared TEST_GLOBS path with no '## Ablation' section, with a countable refusal=ablation-missing record"
  teardown
}

# =============================================================================
# CASE — THE GREEN PATH: a well-formed slice (QA Verdict table, forks: none, a branch touching
# no declared test path) moves to qa_complete/ cleanly.
# =============================================================================
case_subtask_qa_gate_well_formed_lands() {
  cf_reset
  if ! has_issue_template; then skp "subtask.sh move <id> qa_complete lands a slice whose own QA Verdict table, forks: field and branch diff are all well-formed" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  make_sandbox
  _declare_test_globs 'tests/*'

  local p="$SB_PREFIX-673"
  _seed_parent "$p"
  local slice_branch="feature/${p}-s1-clean"
  local f; f="$(_seed_subtask "$p" s1 dev_complete clean "A well-formed slice" "$slice_branch")"
  publish_sandbox

  git -C "$SB_WORK" checkout -b "$slice_branch" "$SB_TRUNK" --quiet >/dev/null 2>&1
  echo "a real change" > "$SB_WORK/CHANGE673.txt"
  git -C "$SB_WORK" add CHANGE673.txt >/dev/null 2>&1
  sbcommit -m "[Dev] ${p}-s1: add a real change" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "$slice_branch" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" checkout "$SB_TRUNK" --quiet >/dev/null 2>&1

  local out rc
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/subtask.sh" move "${p}-s1" qa_complete 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "a well-formed slice — subtask.sh move exited $rc: $(printf '%s' "$out" | tail -8 | tr '\n' '|')"
  origin_has_path "progress/subtasks/${p}/qa_complete/${p}-s1-clean.md" || cf "the slice did not advance to qa_complete/"
  origin_has_path "progress/subtasks/${p}/dev_complete/${p}-s1-clean.md" && cf "the slice is still listed in dev_complete/ too"

  finish "subtask.sh move <id> qa_complete lands a slice whose own QA Verdict table, forks: field and branch diff are all well-formed"
  teardown
}

# =============================================================================
# CASE — A SLICE WITH NO BRANCH OF ITS OWN (branch: n/a, or a name that resolves to no ref
# anywhere) STILL gets the QA Verdict and forks: checks — content-only, no diff needed — and
# moves cleanly when both are well-formed; the forks:/Ablation diff derivation is UNRUNNABLE
# (a note on stderr), never silently skipped and never a false refusal.
# =============================================================================
case_subtask_no_branch_of_its_own_still_checks_table_and_forks() {
  cf_reset
  if ! has_issue_template; then skp "subtask.sh move <id> qa_complete: a slice with no branch of its own still gets the content-only checks" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  make_sandbox

  local p="$SB_PREFIX-674"
  _seed_parent "$p"
  # branch: n/a — this slice's work was done directly against the parent's branch (or none yet).
  local f; f="$(_seed_subtask "$p" s1 dev_complete nobranch "A slice with no branch of its own")"
  publish_sandbox

  local out rc
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/subtask.sh" move "${p}-s1" qa_complete 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "a slice with branch: n/a and a well-formed table/forks — subtask.sh move exited $rc: $(printf '%s' "$out" | tail -8 | tr '\n' '|')"
  origin_has_path "progress/subtasks/${p}/qa_complete/${p}-s1-nobranch.md" || cf "the slice did not advance to qa_complete/"
  case "$out" in *"not a local or"*"ref"*) : ;; *) cf "no note that the forks:/Ablation diff basis could not be derived from a branch: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac

  # NEGATIVE HALF, same fixture family: an ill-formed table on a branchless slice still refuses —
  # the content-only QA Verdict check does not depend on a branch existing.
  local q="$SB_PREFIX-675"
  _seed_parent "$q"
  local g; g="$(_seed_subtask "$q" s1 dev_complete badtable "A slice with no branch and a bad table")"
  perl -0pi -e 's/## QA Verdict\n.*?\n\n(?=## Out of Scope)//s' "$g"
  publish_sandbox

  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec2" "$SB_WORK/scripts/subtask.sh" move "${q}-s1" qa_complete 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(negative) a branchless slice with no QA Verdict table — subtask.sh move exited 0"
  /usr/bin/grep -q 'refusal=qa-verdict-missing' "$SB_TMP/rec2"/*.tsv 2>/dev/null \
    || cf "(negative) no progress record carries refusal=qa-verdict-missing: $(cat "$SB_TMP/rec2"/*.tsv 2>/dev/null)"

  finish "subtask.sh move <id> qa_complete: a slice with no branch of its own (branch: n/a) still gets the content-only QA Verdict and forks: checks, and the diff-derived half is reported UNRUNNABLE rather than silently skipped or falsely refused"
  teardown
}
