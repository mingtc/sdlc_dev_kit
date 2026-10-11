# KIT-CLASS: MIXED — self-test harness, the board-property landing refusals. See
# process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/board-properties.sh — sourced by scripts/test/run.sh, never run on its own.
# finish-pr.sh and subtask.sh refuse a landing that INTRODUCES a finding in one of check-board.sh's
# arms [d] [i] [l] [p] [r] [q], through lib/qa-gate.sh's kit_board_property_check — the same
# functions the arms run (lib/board-properties.sh). Every row below is ONE landing, run in the
# kit's real order: the card is minted at in_progress on the trunk, the branch is cut then, and
# only afterwards does the trunk move the card to dev_complete. Per arm, three shapes:
#   a branch that touches the property and plants a defect       -> REFUSED, rule named, nothing merged
#   a branch that does not touch it, the defect already elsewhere -> LANDS (the stated limit)
#   a branch that touches it and is clean                        -> LANDS
# =============================================================================

# The register's entries are written the way the shape arm reads them: the three bold fields on
# consecutive lines under a `### D-NN` heading.
# _bpf_seed_requirements — a register, a PRD citing D-01, and a corpus manifest, all clean: D-01
# is cited by its PRD, D-02 is [cross-cutting], and D-00 is retired. The register ends in a
# `## Findings` section, so an entry a case appends is the only entry its diff reaches.
_bpf_seed_requirements() {
  mkdir -p "$SB_WORK/requirements" "$SB_WORK/docs"
  cat > "$SB_WORK/requirements/DECISIONS.md" <<'EOF'
# DECISIONS

## A. Bucket

### D-01

**Ruling.** One.
**Why.** Because.
**Provenance.** Here.

### D-02

**Ruling.** [cross-cutting] Two.
**Why.** Because.
**Provenance.** Here.

## Retired ids

`D-00` — retired 2026-01-01; its scope moved into D-01.

## Findings

Nothing yet. Rows below are appended after the last entry; a heading above keeps an entry a row
appends from reading as a change to the entry before it (the forks derivation flags an entry whose
span a hunk reaches).
EOF
  cat > "$SB_WORK/requirements/PRD-001-scope.md" <<'EOF'
# PRD-001

Constrained by [decision: D-01].
EOF
  cat > "$SB_WORK/requirements/CORPUS.md" <<'EOF'
# CORPUS

| Entry | Kind | Status | Why |
|---|---|---|---|
| scope | prd | present | the scope |
EOF
}

# _bpf_card_file <path> <id> [<frontmatter line>…] — a minimal card, written whole.
_bpf_card_file() {
  local path="$1" id="$2" l
  shift 2
  mkdir -p "$(dirname "$path")"
  {
    printf -- '---\nid: %s\ntype: chore\n' "$id"
    for l in "$@"; do printf '%s\n' "$l"; done
    printf -- '---\n\n# %s\n\n## Activity\n\n- 2026-01-01 [PM] Seeded for the sandbox self-test.\n' "$id"
  } > "$path"
}

# _bpf_begin <id> <slug> [<forks value>] — the card is minted at in_progress and published on the
# trunk, and THEN the branch is cut from it, as the roles do. Leaves the checkout on the branch.
_bpf_begin() {
  local id="$1" slug="$2" forks="${3:-none}" f
  seed_issue in_progress "$id" "$slug" chore "Board property row $id" "feature/$id-$slug"
  f="$SB_WORK/progress/in_progress/$id-$slug.md"
  if [ "$forks" != "none" ]; then
    sed -i.bak "s/^forks: none\$/forks: $forks/" "$f"; rm -f "$f.bak"
    grep -qxF "forks: $forks" "$f" || _fixture_die "_bpf_begin: the forks: line of $id did not take"
  fi
  publish_sandbox
  git -C "$SB_WORK" checkout -q -b "feature/$id-$slug" "$SB_TRUNK" >/dev/null 2>&1 \
    || _fixture_die "_bpf_begin: could not cut feature/$id-$slug"
}

# _bpf_end <id> <slug> — commit the branch's work (with a marker file, so it always has a net
# change), push it, return to the trunk, and move the card to dev_complete THERE. The trunk is
# now ahead of the branch's base.
_bpf_end() {
  local id="$1" slug="$2"
  echo "a real change" > "$SB_WORK/BP-$id.txt"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[Dev] $id: the branch work" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/$id-$slug" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" checkout "$SB_TRUNK" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" mv "progress/in_progress/$id-$slug.md" "progress/dev_complete/$id-$slug.md" >/dev/null 2>&1 \
    || _fixture_die "_bpf_end: could not move $id to dev_complete on the trunk"
  sbcommit -m "[Dev] $id: to dev_complete" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push origin "$SB_TRUNK" --quiet >/dev/null 2>&1
}

_BPF_OUT=""; _BPF_RC=0
_bpf_land() {  # <id> — land it with the trunk's finish-pr.sh; sets _BPF_OUT and _BPF_RC
  _BPF_OUT="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/rec-$1" "$SB_WORK/scripts/finish-pr.sh" "$1" 2>&1 )"; _BPF_RC=$?
}

# _bpf_expect_refused <label> <id> <slug> <rule> <text the refusal must carry>
_bpf_expect_refused() {
  local label="$1" id="$2" slug="$3" rule="$4" mention="$5"
  _bpf_land "$id"
  [ "$_BPF_RC" -ne 0 ] || cf "$label: finish-pr.sh exited 0 — the branch's defect landed"
  grep -q "refusal=$rule" "$SB_TMP/rec-$id"/*.tsv 2>/dev/null \
    || cf "$label: no progress record carries refusal=$rule: $(cat "$SB_TMP/rec-$id"/*.tsv 2>/dev/null | cut -c1-200) / output: $(printf '%s' "$_BPF_OUT" | tr '\n' '|' | cut -c1-300)"
  case "$_BPF_OUT" in *"$mention"*) : ;; *) cf "$label: the refusal does not carry '$mention': $(printf '%s' "$_BPF_OUT" | tr '\n' '|' | cut -c1-300)" ;; esac
  origin_has_path "BP-$id.txt" && cf "$label: the branch was merged before the refusal"
  origin_has_path "progress/qa_complete/$id-$slug.md" && cf "$label: the card advanced despite the refusal"
  return 0
}

# _bpf_expect_landed <label> <id> <slug> <arms that must have run> <arms that must NOT have run>
_bpf_expect_landed() {
  local label="$1" id="$2" slug="$3" ran="$4" skipped="$5"
  _bpf_land "$id"
  [ "$_BPF_RC" -eq 0 ] || cf "$label: finish-pr.sh exited $_BPF_RC: $(printf '%s' "$_BPF_OUT" | tail -8 | tr '\n' '|' | cut -c1-400)"
  origin_has_path "progress/qa_complete/$id-$slug.md" || cf "$label: the card did not advance to qa_complete/"
  origin_has_path "BP-$id.txt" || cf "$label: the squash-merged change is not on the trunk"
  # The check RAN and said which arms: a landing that passes because the check never executed
  # would print neither list.
  case "$_BPF_OUT" in
    *"BOARD_PROPERTY_CHECK: PASS — ran: ${ran}; property untouched, not run: ${skipped};"*) : ;;
    *) cf "$label: expected 'BOARD_PROPERTY_CHECK: PASS — ran: ${ran}; property untouched, not run: ${skipped};' in the output: $(printf '%s' "$_BPF_OUT" | grep 'BOARD_PROPERTY_CHECK' | head -3 | tr '\n' '|')" ;;
  esac
  return 0
}

# _bpf_control <pattern> <what> — the planted defect is REAL: check-board.sh reports it on the
# trunk the landing reads, so a landing that passes is not passing over nothing.
_bpf_control() {
  local out
  out="$(cb_run)"
  printf '%s\n' "$out" | grep -F -- "$1" >/dev/null \
    || cf "(control) check-board.sh does not report the planted pre-existing defect ($2) — the landing that passes over it would prove nothing: $(printf '%s' "$out" | grep '⚠' | head -5 | tr '\n' '|')"
}

# =============================================================================
# CASE — [d] FRONTMATTER ID INTEGRITY.
# =============================================================================
case_finish_pr_refuses_a_branch_that_breaks_frontmatter_ids() {
  cf_reset
  make_sandbox
  _bpf_seed_requirements
  # A duplicate id pair ALREADY on the trunk, in done/, that no branch below touches.
  seed_issue done "$SB_PREFIX-701" first chore "Already landed" >/dev/null
  seed_issue done "$SB_PREFIX-701" second chore "Same id, minted twice" >/dev/null
  publish_sandbox
  _bpf_control "DUPLICATE id" "a duplicate id in done/"

  # (a) the branch adds a card whose frontmatter id disagrees with its filename: REFUSED.
  local ida="$SB_PREFIX-711"
  _bpf_begin "$ida" idbreak
  _bpf_card_file "$SB_WORK/progress/todo/$SB_PREFIX-712-stray.md" "$SB_PREFIX-799"
  _bpf_end "$ida" idbreak
  _bpf_expect_refused "(a) a branch adding a card whose id disagrees with its filename" "$ida" idbreak board-id-integrity "DISAGREES"

  # (b) an unrelated branch while the duplicate sits in done/: LANDS. The arm RAN (the landing
  #     card is a board card) and found only what the trunk already reports.
  local idb="$SB_PREFIX-713"
  _bpf_begin "$idb" elsewhere
  _bpf_end "$idb" elsewhere
  _bpf_expect_landed "(b) an unrelated branch over a pre-existing duplicate id" "$idb" elsewhere "d i l" "p r q"

  # (c) a clean branch that does touch the board: LANDS.
  local idc="$SB_PREFIX-714"
  _bpf_begin "$idc" cleancard
  _bpf_card_file "$SB_WORK/progress/todo/$SB_PREFIX-715-fine.md" "$SB_PREFIX-715"
  _bpf_end "$idc" cleancard
  _bpf_expect_landed "(c) a branch adding a well-formed card" "$idc" cleancard "d i l" "p r q"

  finish "finish-pr.sh refuses a branch that adds a card whose frontmatter id disagrees with its filename (refusal=board-id-integrity, nothing merged), and lands both an unrelated branch over a duplicate id already on the trunk and a branch adding a well-formed card — the refusal is for the defect the branch introduces"
  teardown
}

# =============================================================================
# CASE — [i] blocks: / blocked_by: SYMMETRY.
# =============================================================================
case_finish_pr_refuses_a_branch_that_breaks_blocks_symmetry() {
  cf_reset
  make_sandbox
  _bpf_seed_requirements
  # An asymmetric pair ALREADY on the trunk: 721 blocks 722, and 722 never answers.
  _bpf_card_file "$SB_WORK/progress/todo/$SB_PREFIX-721-blocker.md" "$SB_PREFIX-721" "blocks: [$SB_PREFIX-722]"
  _bpf_card_file "$SB_WORK/progress/todo/$SB_PREFIX-722-blocked.md" "$SB_PREFIX-722"
  publish_sandbox
  _bpf_control "does not declare blocked_by" "an asymmetric blocks: pair"

  # (a) the branch adds a card that blocks 722 without 722 answering: REFUSED.
  local ida="$SB_PREFIX-731"
  _bpf_begin "$ida" asym
  _bpf_card_file "$SB_WORK/progress/todo/$SB_PREFIX-732-newblocker.md" "$SB_PREFIX-732" "blocks: [$SB_PREFIX-722]"
  _bpf_end "$ida" asym
  _bpf_expect_refused "(a) a branch adding a card whose blocks: is unanswered" "$ida" asym board-blocks-asymmetric "$SB_PREFIX-732"

  # (b) an unrelated branch while the pair at 721/722 stays asymmetric: LANDS.
  local idb="$SB_PREFIX-733"
  _bpf_begin "$idb" elsewhere
  _bpf_end "$idb" elsewhere
  _bpf_expect_landed "(b) an unrelated branch over a pre-existing asymmetric pair" "$idb" elsewhere "d i l" "p r q"

  # (c) a branch adding a symmetric pair: LANDS.
  local idc="$SB_PREFIX-734"
  _bpf_begin "$idc" symmetric
  _bpf_card_file "$SB_WORK/progress/todo/$SB_PREFIX-735-a.md" "$SB_PREFIX-735" "blocks: [$SB_PREFIX-736]"
  _bpf_card_file "$SB_WORK/progress/todo/$SB_PREFIX-736-b.md" "$SB_PREFIX-736" "blocked_by: [$SB_PREFIX-735]"
  _bpf_end "$idc" symmetric
  _bpf_expect_landed "(c) a branch adding a symmetric blocks:/blocked_by: pair" "$idc" symmetric "d i l" "p r q"

  finish "finish-pr.sh refuses a branch that adds a blocks: no card answers (refusal=board-blocks-asymmetric, nothing merged), and lands both an unrelated branch over an asymmetric pair already on the trunk and a branch adding a symmetric pair"
  teardown
}

# =============================================================================
# CASE — [l] REGISTER CITATIONS RESOLVE.
# =============================================================================
case_finish_pr_refuses_a_branch_that_breaks_a_register_citation() {
  cf_reset
  make_sandbox
  _bpf_seed_requirements
  # A dangling citation ALREADY on the trunk, in a file no branch below touches.
  printf 'An old note. [decision: D-88]\n' > "$SB_WORK/docs/old-note.md"
  publish_sandbox
  _bpf_control "docs/old-note.md cites D-88" "a dangling citation in docs/old-note.md"

  # (a) the branch adds a citation of D-77, which is no entry: REFUSED.
  local ida="$SB_PREFIX-741"
  _bpf_begin "$ida" dangling
  printf 'See [decision: D-77].\n' > "$SB_WORK/docs/new-note.md"
  _bpf_end "$ida" dangling
  _bpf_expect_refused "(a) a branch citing a register id that is no entry" "$ida" dangling board-citation-unresolved "D-77"

  # (b) an unrelated branch while D-88 dangles in docs/old-note.md: LANDS.
  local idb="$SB_PREFIX-742"
  _bpf_begin "$idb" elsewhere
  _bpf_end "$idb" elsewhere
  _bpf_expect_landed "(b) an unrelated branch over a pre-existing dangling citation" "$idb" elsewhere "d i l" "p r q"

  # (c) THE TRUNK MOVES AFTER THE CUT. The branch cites D-03, an entry only the trunk gains once the
  #     branch exists: the landing reads the merged tree, not the branch tip, so it resolves: LANDS.
  local idc="$SB_PREFIX-743"
  _bpf_begin "$idc" stale
  printf 'Per [decision: D-03].\n' > "$SB_WORK/docs/uses-d03.md"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[Dev] $idc: cite D-03" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/$idc-stale" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" checkout "$SB_TRUNK" --quiet >/dev/null 2>&1
  cat >> "$SB_WORK/requirements/DECISIONS.md" <<'EOF'

### D-03

**Ruling.** [cross-cutting] Three, decided on the trunk after the branch was cut.
**Why.** Because.
**Provenance.** Here.
EOF
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[PM] D-03 lands on the trunk" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" checkout "feature/$idc-stale" --quiet >/dev/null 2>&1
  _bpf_end "$idc" stale
  _bpf_expect_landed "(c) a citation of an entry the trunk gained after the branch was cut" "$idc" stale "d i l" "p r q"

  # (d) THE REGISTER CHANGE BREAKS AN UNTOUCHED CITER. The branch renames D-01 to D-11; PRD-001,
  #     which the branch never touches, still cites D-01: REFUSED, naming the PRD.
  local idd="$SB_PREFIX-744"
  _bpf_begin "$idd" rename "[D-11]"
  sed -i.bak 's/^### D-01$/### D-11/' "$SB_WORK/requirements/DECISIONS.md"; rm -f "$SB_WORK/requirements/DECISIONS.md.bak"
  grep -qxF '### D-11' "$SB_WORK/requirements/DECISIONS.md" || _fixture_die "case_finish_pr_refuses_a_branch_that_breaks_a_register_citation: the rename did not take"
  _bpf_end "$idd" rename
  _bpf_expect_refused "(d) a register change that leaves an untouched PRD citing a missing entry" "$idd" rename board-citation-unresolved "requirements/PRD-001-scope.md cites D-01"

  # (e) THE RULES ARE THE TRUNK'S. The branch adds docs/ to its own copy of CITATION_EXCLUDE, hiding
  #     the dangling citation it plants there: still REFUSED, because the operands are read from
  #     the trunk's check-board.sh.
  local ide="$SB_PREFIX-745"
  _bpf_begin "$ide" hides
  perl -0pi -e "s{\\.claude/skills/'}{.claude/skills/\\ndocs/'}" "$SB_WORK/scripts/check-board.sh"
  grep -qx "docs/'" "$SB_WORK/scripts/check-board.sh" || _fixture_die "case_finish_pr_refuses_a_branch_that_breaks_a_register_citation: the CITATION_EXCLUDE edit did not take"
  printf 'Hidden. [decision: D-66]\n' > "$SB_WORK/docs/hidden.md"
  _bpf_end "$ide" hides
  _bpf_expect_refused "(e) a branch that excludes the directory of its own dangling citation" "$ide" hides board-citation-unresolved "D-66"

  finish "finish-pr.sh refuses a branch that cites a register id that is no entry, and one whose register change leaves an untouched PRD citing a missing entry (refusal=board-citation-unresolved, nothing merged), reads the MERGED tree (a citation of an entry the trunk gained after the cut resolves), reads its operands from the trunk (a branch cannot exclude its own citation), and lands an unrelated branch over a pre-existing dangling citation"
  teardown
}

# =============================================================================
# CASE — [p] / [r] CORPUS FORWARD AND REVERSE COVERAGE, when the branch touches requirements/.
# =============================================================================
case_finish_pr_refuses_a_branch_that_breaks_corpus_coverage() {
  cf_reset
  make_sandbox
  _bpf_seed_requirements
  # Two defects ALREADY on the trunk: D-04 is cited by no PRD, and a corpus row forward-references
  # a card that does not exist.
  cat >> "$SB_WORK/requirements/DECISIONS.md" <<'EOF'

### D-04

**Ruling.** Four, never cited by a PRD.
**Why.** Because.
**Provenance.** Here.

## Notes

None.
EOF
  printf '| legacy | prd | forward-referenced (%s-998) | no card |\n' "$SB_PREFIX" >> "$SB_WORK/requirements/CORPUS.md"
  publish_sandbox
  _bpf_control "D-04 is not cited by any PRD" "a register entry no PRD cites"
  _bpf_control "$SB_PREFIX-998" "a dangling corpus forward reference"

  # (a) [p] the branch adds a corpus row forward-referencing a card that does not exist: REFUSED.
  local ida="$SB_PREFIX-751"
  _bpf_begin "$ida" fwd
  printf '| notes | prd | forward-referenced (%s-999) | no card |\n' "$SB_PREFIX" >> "$SB_WORK/requirements/CORPUS.md"
  _bpf_end "$ida" fwd
  _bpf_expect_refused "(a) a branch adding a dangling corpus forward reference" "$ida" fwd board-corpus-coverage "$SB_PREFIX-999"

  # (b) [r] the branch adds a register entry no PRD cites and nothing marks cross-cutting: REFUSED.
  local idb="$SB_PREFIX-752"
  _bpf_begin "$idb" uncited "[D-05]"
  cat >> "$SB_WORK/requirements/DECISIONS.md" <<'EOF'

### D-05

**Ruling.** Five, constraining a requirement.
**Why.** Because.
**Provenance.** Here.
EOF
  _bpf_end "$idb" uncited
  _bpf_expect_refused "(b) a branch adding a register entry no PRD cites" "$idb" uncited board-corpus-coverage "D-05 is not cited by any PRD"

  # (c) the branch touches requirements/ (a new PRD) and leaves D-04 and the legacy row as they
  #     are: LANDS — they are the trunk's to report, not this branch's.
  local idc="$SB_PREFIX-753"
  _bpf_begin "$idc" prd
  printf '# PRD-002\n\nNothing here cites a decision.\n' > "$SB_WORK/requirements/PRD-002-more.md"
  _bpf_end "$idc" prd
  _bpf_expect_landed "(c) a branch touching requirements/ over a pre-existing uncited entry and dangling row" "$idc" prd "d i l p r" "q"

  # (d) an unrelated branch: LANDS, and [p] [r] [q] did not run.
  local idd="$SB_PREFIX-754"
  _bpf_begin "$idd" elsewhere
  _bpf_end "$idd" elsewhere
  _bpf_expect_landed "(d) an unrelated branch" "$idd" elsewhere "d i l" "p r q"

  # (e) a branch that touches the register cleanly (a cross-cutting entry): LANDS.
  local ide="$SB_PREFIX-755"
  _bpf_begin "$ide" crosscut "[D-06]"
  cat >> "$SB_WORK/requirements/DECISIONS.md" <<'EOF'

### D-06

**Ruling.** [cross-cutting] Six, binding the whole project.
**Why.** Because.
**Provenance.** Here.
EOF
  _bpf_end "$ide" crosscut
  _bpf_expect_landed "(e) a branch adding a cross-cutting register entry" "$ide" crosscut "d i l p r q" "none"

  finish "finish-pr.sh refuses a branch touching requirements/ that adds a dangling corpus forward reference, or a register entry no PRD cites (refusal=board-corpus-coverage, nothing merged), and lands a branch that touches requirements/ over an uncited entry and a dangling row the trunk already has, an unrelated branch (the arms did not run), and a clean cross-cutting entry"
  teardown
}

# =============================================================================
# CASE — [q] REGISTER ENTRY SHAPE, when the branch changes the declared register.
# =============================================================================
case_finish_pr_refuses_a_branch_that_breaks_register_shape() {
  cf_reset
  make_sandbox
  _bpf_seed_requirements
  # A misshapen entry ALREADY on the trunk: D-08 carries a stacked, dated amendment.
  cat >> "$SB_WORK/requirements/DECISIONS.md" <<'EOF'

### D-08

**Ruling.** [cross-cutting] Eight.
**Why.** Because.
**(14) 2026-09-29.** A first stacked amendment.
**Provenance.** Here.

## Notes

None.
EOF
  publish_sandbox
  _bpf_control "D-08" "a stacked amendment in D-08"

  # (a) the branch adds an entry with a fourth bold field: REFUSED.
  local ida="$SB_PREFIX-761"
  _bpf_begin "$ida" fourth "[D-07]"
  cat >> "$SB_WORK/requirements/DECISIONS.md" <<'EOF'

### D-07

**Ruling.** [cross-cutting] Seven.
**Why.** Because.
**Note.** A fourth field a reader must reconcile by hand.
**Provenance.** Here.
EOF
  _bpf_end "$ida" fourth
  _bpf_expect_refused "(a) a branch adding a register entry with a fourth field" "$ida" fourth board-register-shape "D-07"

  # (b) the branch stacks a SECOND amendment onto the already-misshapen D-08: REFUSED — the new
  #     fragment is a finding the trunk does not have, though D-08 already had one.
  local idb="$SB_PREFIX-762"
  _bpf_begin "$idb" stack "[D-08]"
  perl -0pi -e 's/(\*\*\(14\) 2026-09-29\.\*\* A first stacked amendment\.\n)/$1**(15) 2026-10-01.** A second one.\n/' "$SB_WORK/requirements/DECISIONS.md"
  grep -qF '(15) 2026-10-01' "$SB_WORK/requirements/DECISIONS.md" || _fixture_die "case_finish_pr_refuses_a_branch_that_breaks_register_shape: the second amendment did not take"
  _bpf_end "$idb" stack
  _bpf_expect_refused "(b) a branch stacking a second amendment onto an entry that already has one" "$idb" stack board-register-shape "D-08"

  # (c) an unrelated branch while D-08 is misshapen: LANDS, and [q] did not run.
  local idc="$SB_PREFIX-763"
  _bpf_begin "$idc" elsewhere
  _bpf_end "$idc" elsewhere
  _bpf_expect_landed "(c) an unrelated branch over a misshapen entry" "$idc" elsewhere "d i l" "p r q"

  # (d) the branch adds a well-shaped entry beside the misshapen one: LANDS.
  local idd="$SB_PREFIX-764"
  _bpf_begin "$idd" shaped "[D-09]"
  cat >> "$SB_WORK/requirements/DECISIONS.md" <<'EOF'

### D-09

**Ruling.** [cross-cutting] Nine.
**Why.** Because.
**Provenance.** Here.
EOF
  _bpf_end "$idd" shaped
  _bpf_expect_landed "(d) a branch adding a well-shaped entry beside a misshapen one" "$idd" shaped "d i l p r q" "none"

  finish "finish-pr.sh refuses a branch that changes the register to add an entry with a fourth field, or a second stacked amendment onto an entry that already has one (refusal=board-register-shape, nothing merged), and lands an unrelated branch over a misshapen entry (the arm did not run) and a well-shaped entry beside one"
  teardown
}

# =============================================================================
# CASE — THE OPERANDS ARE READ FROM THE TRUNK, AND AN UNREADABLE DECLARATION REFUSES.
# A trunk whose check-board.sh no longer declares PRD_SURFACE gives the check nothing to read the
# PRD population from; it refuses, naming the declaration, rather than guessing one.
# =============================================================================
case_finish_pr_board_property_check_refuses_without_the_trunks_declarations() {
  cf_reset
  make_sandbox
  _bpf_seed_requirements
  sed -i.bak '/^PRD_SURFACE=/d' "$SB_WORK/scripts/check-board.sh"; rm -f "$SB_WORK/scripts/check-board.sh.bak"
  grep -q '^PRD_SURFACE=' "$SB_WORK/scripts/check-board.sh" && _fixture_die "case_finish_pr_board_property_check_refuses_without_the_trunks_declarations: the PRD_SURFACE declaration survived the strip"
  publish_sandbox

  local id="$SB_PREFIX-771"
  _bpf_begin "$id" nodecl
  _bpf_end "$id" nodecl
  _bpf_expect_refused "a trunk whose check-board.sh declares no PRD_SURFACE" "$id" nodecl board-property-unreadable "PRD_SURFACE"

  finish "finish-pr.sh refuses, naming the declaration, when the trunk's check-board.sh does not declare an operand the board-property check needs (refusal=board-property-unreadable)"
  teardown
}

# =============================================================================
# CASE — subtask.sh APPLIES THE SAME CHECK TO A SLICE MOVING TO qa_complete/.
# =============================================================================
case_subtask_move_refuses_a_slice_branch_that_breaks_a_register_citation() {
  cf_reset
  if ! has_issue_template; then skp "subtask.sh move <id> qa_complete applies the board-property check to a slice" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  make_sandbox
  _bpf_seed_requirements

  local p="$SB_PREFIX-781"
  seed_issue in_progress "$p" parent chore "Decomposed parent" >/dev/null
  _seed_subtask "$p" s1 dev_complete branchy "A slice with a branch" "feature/${p}-s1" >/dev/null
  _seed_subtask "$p" s2 dev_complete nobranch "A slice with no branch" >/dev/null
  publish_sandbox

  # (a) the slice's own branch cites D-77, which is no entry: REFUSED before the git mv.
  git -C "$SB_WORK" checkout -q -b "feature/${p}-s1" "$SB_TRUNK" >/dev/null 2>&1
  printf 'See [decision: D-77].\n' > "$SB_WORK/docs/slice-note.md"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[Dev] ${p}-s1: the slice's work" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/${p}-s1" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" checkout "$SB_TRUNK" --quiet >/dev/null 2>&1

  local out rc
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-a" "$SB_WORK/scripts/subtask.sh" move "${p}-s1" qa_complete 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) a slice whose branch cites D-77 — subtask.sh move exited 0"
  case "$out" in *D-77*) : ;; *) cf "(a) the refusal does not name D-77: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)" ;; esac
  grep -q 'refusal=board-citation-unresolved' "$SB_TMP/rec-a"/*.tsv 2>/dev/null \
    || cf "(a) no progress record carries refusal=board-citation-unresolved: $(cat "$SB_TMP/rec-a"/*.tsv 2>/dev/null | cut -c1-200)"
  origin_has_path "progress/subtasks/${p}/qa_complete/${p}-s1-branchy.md" && cf "(a) the slice advanced despite the refusal"

  # (b) a slice with no branch of its own reads the trunk against itself: LANDS, and says it ran.
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-b" "$SB_WORK/scripts/subtask.sh" move "${p}-s2" qa_complete 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) a slice with no branch — subtask.sh move exited $rc: $(printf '%s' "$out" | tail -6 | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/subtasks/${p}/qa_complete/${p}-s2-nobranch.md" || cf "(b) the slice did not advance to qa_complete/"
  case "$out" in *"BOARD_PROPERTY_CHECK: PASS"*) : ;; *) cf "(b) the output carries no BOARD_PROPERTY_CHECK line: $(printf '%s' "$out" | tail -6 | tr '\n' '|' | cut -c1-300)" ;; esac

  finish "subtask.sh move <id> qa_complete refuses a slice whose own branch introduces a dangling register citation (refusal=board-citation-unresolved, before the git mv), and moves a slice with no branch while printing that the board-property check ran"
  teardown
}

# =============================================================================
# CASE — ONE IMPLEMENTATION PER PROPERTY: the report and the refusal fail together.
#
# The check lives in lib/board-properties.sh and nowhere else. An early `return` planted into
# kit_bp_citations on a COPY (the sandbox's) must silence BOTH consumers: check-board.sh's [l]
# stops reporting a dangling citation, and finish-pr.sh lands the branch that plants one. Unplanted,
# both see it — so the two agree because they are the same code, and neither agreement is a
# coincidence of two parsers.
# =============================================================================
case_board_property_report_and_refusal_share_one_implementation() {
  cf_reset
  make_sandbox
  if [ ! -f "$SB_WORK/scripts/lib/board-properties.sh" ]; then
    cf "scripts/lib/board-properties.sh is absent from the tree — the report and the refusal have no shared implementation to silence"
    finish "silencing kit_bp_citations in lib/board-properties.sh alone silences BOTH check-board.sh's [l] and finish-pr.sh's refusal — one implementation, two callers"
    teardown
    return
  fi
  _bpf_seed_requirements
  publish_sandbox

  # UNPLANTED: the landing refuses a dangling citation, and the report names the same one.
  local ida="$SB_PREFIX-791"
  _bpf_begin "$ida" before
  printf 'See [decision: D-55].\n' > "$SB_WORK/docs/plant.md"
  _bpf_end "$ida" before
  _bpf_expect_refused "(unplanted) the landing" "$ida" before board-citation-unresolved "D-55"
  # The same citation, on the trunk, as the report reads it. The branch is merged by hand here
  # only to give check-board.sh a trunk that carries it.
  git -C "$SB_WORK" merge --squash "feature/$ida-before" >/dev/null 2>&1
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[Dev] $ida: carry the citation onto the trunk by hand" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push origin "$SB_TRUNK" --quiet >/dev/null 2>&1
  cb_run | grep -F 'docs/plant.md cites D-55' >/dev/null \
    || cf "(unplanted) check-board.sh [l] does not report docs/plant.md citing D-55"

  # PLANTED: one early return in the one function.
  _plant_in_function "$SB_WORK/scripts/lib/board-properties.sh" kit_bp_citations 'return 0' "case_board_property_report_and_refusal_share_one_implementation"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[PM] plant: the citations check returns early" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push origin "$SB_TRUNK" --quiet >/dev/null 2>&1
  cb_run | grep -F 'cites D-55' >/dev/null \
    && cf "(planted) check-board.sh [l] still reports the citation — the report has a reader of its own"
  local idb="$SB_PREFIX-792"
  _bpf_begin "$idb" after
  printf 'See [decision: D-56].\n' > "$SB_WORK/docs/plant2.md"
  _bpf_end "$idb" after
  _bpf_land "$idb"
  [ "$_BPF_RC" -eq 0 ] || cf "(planted) the landing still refuses with the shared check silenced — it has a reader of its own: $(printf '%s' "$_BPF_OUT" | tail -5 | tr '\n' '|' | cut -c1-300)"

  finish "silencing kit_bp_citations in lib/board-properties.sh alone silences BOTH check-board.sh's [l] and finish-pr.sh's refusal, which refuse and report the same dangling citation while it is intact — one implementation, two callers"
  teardown
}

# =============================================================================
# CASE — A MERGE THAT CONFLICTS LEAVES THE CHECK UNRUNNABLE, SAID ON STDOUT, AND THE SQUASH REFUSES.
# The check reads the tree the landing would produce; with no such tree it prints that it did not
# run instead of reading as a pass, and the landing is still refused by the squash itself.
# =============================================================================
case_finish_pr_board_property_check_says_so_when_the_merge_conflicts() {
  cf_reset
  make_sandbox
  _bpf_seed_requirements
  publish_sandbox

  local id="$SB_PREFIX-801"
  _bpf_begin "$id" clash
  printf 'Constrained by [decision: D-01], as the branch words it.\n' > "$SB_WORK/requirements/PRD-001-scope.md"
  _bpf_end "$id" clash
  # The trunk rewrites the same line after the cut.
  printf 'Constrained by [decision: D-01], as the trunk words it.\n' > "$SB_WORK/requirements/PRD-001-scope.md"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[PM] reword the PRD on the trunk" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push origin "$SB_TRUNK" --quiet >/dev/null 2>&1

  _bpf_land "$id"
  [ "$_BPF_RC" -ne 0 ] || cf "a branch that conflicts with the trunk — finish-pr.sh exited 0"
  case "$_BPF_OUT" in *"BOARD_PROPERTY_CHECK: did not run"*) : ;; *) cf "the output does not say the board-property check did not run: $(printf '%s' "$_BPF_OUT" | tr '\n' '|' | cut -c1-400)" ;; esac
  case "$_BPF_OUT" in *"hit conflicts"*) : ;; *) cf "the squash did not refuse the conflict: $(printf '%s' "$_BPF_OUT" | tr '\n' '|' | cut -c1-400)" ;; esac
  origin_has_path "progress/qa_complete/$id-clash.md" && cf "the card advanced despite the conflict"

  finish "when the branch does not merge cleanly the board-property check prints that it did not run (never a pass), and the squash refuses the landing"
  teardown
}
