#!/usr/bin/env bash
# KIT-CLASS: KIT — board drift report, plus one day-one completeness arm; reads the status folders,
#   the log, recent history, the publication homes and the root scaffolding, each FROM A NAMED
#   SOURCE it prints. See process/EXTRACTION.md.
# Board-drift report: the mechanical checks of MANUAL § "Session close ritual", read-only.
# Contract: process/contracts/drift-report.md. The arms, one line each, in print order:
#   (a) folder vs last-Activity drift, every column in STATUS_FOLDERS but a named skip list;
#   (b) qa_complete/ depth vs the archive.sh sweep threshold;
#   (c) progress.md § Log bytes vs the rotation threshold, plus the whole file (advisory), plus
#       the code commits made since progress.md was last touched (advisory);
#   (d) frontmatter id integrity across every column, plus the declared registers;
#   (e) [Role]-prefix scan of recent trunk commits;
#   (f) unpublished work in both homes the process writes to — [f1] trunk ref, [f2] .kanban-wt;
#       then, under its own header, a remote branch left by a card already in done/ or qa_complete/ (advisory);
#   (g) graduation — has day one finished (advisory);
#   (h) generated-trailer scan of the same commits as (e);
#   (i) blocks:/blocked_by: symmetry (advisory here; a landing refuses a finding it introduces);
#   (j) downtime-queue claim drift (advisory);
#   (k) declined/ depth, a count (advisory);
#   (l) declared reference integrity — every cited register id resolves;
#   (m) how many landed issues carry `prd: n/a`, and how many name neither a PRD nor a reason (advisory);
#   (n) whether the newest session entry ends with its `kit-feedback:` line (advisory);
#   (o) the kit upgrade: KIT-VERSION's form, and an open upgrade checklist's unmarked items (advisory).
#   (p) CORPUS.md forward-reference integrity — a dangling id, a landed id not flipped to present,
#       and a SEED-step marker once day one has closed.
#   (q) declared-register entry SHAPE — every `D-NN` entry is exactly three fields, and a later
#       entry that reopens or supersedes an earlier one names a stamp on the earlier entry; a
#       commit that changed a Ruling carries a stamp; `## Findings` numbering does not collide
#       (advisory here; a landing that changes a register refuses a shape finding it introduces).
#   (r) declared reverse coverage — a live register entry that CONSTRAINS a PRD but that PRD never
#       cites; a `[cross-cutting]` entry is exempt (advisory here; a landing that changes
#       `requirements/` refuses a finding it introduces).
#   (s) model pins vs the ladder — a leaf-worker pin that disagrees with its ladder cell, or, where
#       that cell is unfilled, with what scripts/set-models.sh last wrote (advisory).
#   (t) answered, not reconciled — a question file in the project's question channel that carries an
#       `**Answer` block and that no register entry cites, with the card it parks (advisory).
# Arms (d), (i), (l), (p), (q), (r) are lib/board-properties.sh's functions, the same ones
# lib/qa-gate.sh's kit_board_property_check runs at a landing, so the report and the refusal
# cannot disagree about a property.
# This list and the print order must hold the same letters, in the same order, once each:
#   grep -oE '^[[:space:]]*echo "\[[a-z]\]' scripts/check-board.sh | grep -oE '\[[a-z]\]' | uniq
#   grep -E '^#   \([a-z]\)' scripts/check-board.sh | sed -E 's/^#   (\([a-z]\)).*/\1/'
#
# EVERY ARM NAMES THE SOURCE IT READ, AND SAYS SO WHEN IT COULD NOT READ ONE. A trunk property is
# read from <remote>/<trunk> by name, never from the current checkout: from a branch, arm (d)
# cannot see a collision that exists only on the trunk, and would print ✓. Arm (f) is local by
# design and names each home it reads. With no <remote>/<trunk> ref the arms read the working
# tree and say so. NO FETCH: a hang at session start is worse than a dated answer, so the ref is
# read as it stands and labelled with its sha.
#
# Callers: the SessionStart hook (scripts/hooks/session-start.sh); release.sh gate (d) and
# kit-init.sh self-check (3), which both key on its verdict line; a human at session close.
# Exit 0 whatever it finds (drift is in the output, not the exit status); 2 on a usage error.
# Read-only; it never mutates.
set -uo pipefail

# ── ARGUMENT SHAPE (process/contracts/issue-creation.md § 3): a usage request is answered first,
#    in any position; an unknown option exits 2 before any inspection. The exit-0 convention
#    covers what the report FOUND, not a mis-invocation.
for _a in "$@"; do
  case "$_a" in
    -h|--help)
      echo "Usage: $(basename "$0")"
      echo ""
      echo "Reports board drift. The arms and their letters are printed as it runs."
      echo ""
      echo "Takes no options. Informational by convention: it exits 0 whatever it finds,"
      echo "because drift belongs in the output and not in the exit status. Read-only —"
      echo "it inspects files and 'git status', and never mutates."
      exit 0 ;;
  esac
done
if [ $# -gt 0 ]; then
  echo "Error: unknown option: $1" >&2
  echo "  $(basename "$0") takes no options; run it with no arguments." >&2
  exit 2   # exit-class: usage
fi

# ── Greppable defaults: consumers and tests DERIVE these with sed. Never re-type them elsewhere.
STATUS_FOLDERS='todo|in_progress|dev_complete|qa_complete|blocked|done|declined'
# QA_COMPLETE_THRESHOLD is NOT declared here: scripts/config.sh is the one authority
# (process/contracts/config-seam.md), and arm (b) reads it from $CB_TREE below, so a
# value an adopter declared there is honoured rather than shadowed by a second default.
KIT_QA_COMPLETE_THRESHOLD_DEFAULT=10
# § Log rotation trigger, in BYTES: a few long lines carry real token weight at a small line
# count. 32 KiB ≈ 8k tokens of session-start budget. Rotate with archive-progress.sh.
PROGRESS_LOG_BYTE_THRESHOLD=32768
# WHOLE-FILE size, a separate advisory threshold (10x the § Log one): the § Log arm stops at the
# next "## " heading and cannot see the rest of the file. Reusing the § Log number would make this
# arm red forever, and so ignored. It never sets `drift`.
PROGRESS_WHOLE_FILE_BYTE_THRESHOLD=327680
ROLE_SCAN_N=20        # how many recent trunk commits the HISTORY ARMS scan when the rule's epoch cannot be derived — (e) and (h) share it: one idea, one number
# Check (d): the frontmatter key holding an issue's id, and the id SHAPE (a pattern, not the
# configured prefix, so a board mid-rename still parses).
ISSUE_ID_KEY='id'
ISSUE_ID_PATTERN='[A-Za-z]+-[0-9]+'
# Check (d)'s second identifier space, the registers (contracts/drift-report.md invariant 4).
# One record per register:  <path>|<heading mark>|<id shape>   (path repo-relative; an absent
# register SKIPS with its reason). Add a record per register you keep.
REGISTERS='requirements/DECISIONS.md|### |D-[0-9]+'
# ─── ARM (l)'s OPERANDS: declared reference integrity ────────────────────────
# Only text that DECLARES itself a citation is read. Never a bare id grep plus a comment strip: a
# bare id cannot tell a citation from a mention, and a comment stripper is a second parser that
# fails silently (a stray `<!--` in a shell string swallows everything up to the next `-->`, and
# the file then reads clean).
# The marker itself — case, spacing, list and range forms — is read by lib/decision-register.sh's
# kit_decisions_cited, the ONE reader arms (l)/(r) and finish-pr.sh's `forks:` check all call:
# a second copy of the marker regex here would let one reader see a citation another cannot.
# THE POPULATION: every tracked text file in this source, EXCEPT the paths below — named here so
# the arm's own printed line states its population, not just its verdict. Widened from a declared
# surface list (PRDs and cards only): a citation planted outside a declared surface (PROJECT.md, a
# dev record, a README) read clean, because "every citation resolves" only meant "every citation on
# a surface we named". Each exclusion below is a directory this project's own tooling ever writes,
# never the adopting project's own prose:
#   scripts/        — ids there are comments and fixtures, not a project's own citations.
#   .git/            — version-control internals, never project prose.
#   .claude/skills/  — vendored, upstream skill text (process/EXTRACTION.md's provenance table):
#                      never authored by the adopting project, so a citation inside one is not
#                      this project's to resolve.
# Add a path here only for a directory that is SHIPPED MACHINERY, never for a directory merely
# unlikely to cite — unlikely is not the same as cannot.
CITATION_EXCLUDE='scripts/
.git/
.claude/skills/'
# ─── ARM (r)'s OPERAND: declared reverse coverage ─────────────────────────────
# Where a PRD lives — a glob, not a hard-coded prefix: new-prd.sh's PRD_PREFIX is a project seam
# (scripts/config.sh), and this arm must widen with it rather than go quietly blind under a
# renamed prefix. A project that renames its prefix repoints this string to match.
PRD_SURFACE='requirements/PRD-*.md'
# The exemption token: format law lives in requirements/DECISIONS.md § "Which decisions live HERE"
# — at the HEAD of an entry's Ruling field, the same place the THIRD/FOURTH states put theirs, in
# the same three fields, never a fourth.
CROSS_CUTTING_MARKER='\[cross-cutting\]'
# How far into a file check (d) looks for the frontmatter's OPENING `---`. Not always line 1: a
# card minted from a template carries an HTML comment above it. The cap stops a `---` rule deep in
# a body being read as a fence.
FRONTMATTER_SCAN_LINES=25
# Arm [g]'s (g2) FILL class, the NON-MARKDOWN members: PROJECT.md's blanks are read by their
# <angle-bracket> shape (markdown), but these two ship the disposition in comment/ignore-file
# syntax and write their instruction as a `FILL ME.` sentinel line instead — so they are read by
# THAT shape, not the angle-bracket one.  One record per member:  <path>|<sentinel prefix>
GRADUATION_FILL_MEMBERS='.gitignore|# FILL ME.
.env.example|# FILL ME.'
# Arm [g]'s (g3) DELETE-IF-UNUSED class: the one file an adopter records a kept-on-purpose
# decision in, and the exact mechanical line process/SEED.md's step 8 mints it with (the form
# travels from there — this is a reader, not a second place that states it).
GRADUATION_LOCAL_PROCEDURES='process/LOCAL-PROCEDURES.md'

# Repo root: harness CLAUDE_PROJECT_DIR, else this script's location (scripts/..).
REPO_ROOT="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." 2>/dev/null && pwd || true)"
fi

# The upgrade staging directory, read from the one line that declares it (kit-upgrade.sh's
# STAGE_DIR). Its files are the NEW kit's copies awaiting a merge, not the project's own: arms [g]
# and [l] skip them and print how many. Empty when kit-upgrade.sh is absent: nothing is skipped.
CB_STAGE_DIR="$(sed -n "s/^STAGE_DIR='\([^']*\)'\$/\1/p" "$REPO_ROOT/scripts/kit-upgrade.sh" 2>/dev/null | sed -n '1p' || true)"
cb_staged() { [ -n "$CB_STAGE_DIR" ] || return 1; case "$1" in "$CB_STAGE_DIR"/*) return 0 ;; esac; return 1; }   # return-class: predicate

# The shared already-lived probe, resolved from THIS script's location (it ships beside this
# script; CLAUDE_PROJECT_DIR may name another tree). It also declares § Log's heading, which arms
# c and n read. A load failure is a recorded skip, never an
# exit (the one exit 2 is the usage error above).
CB_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)/lib"
CB_LIVED_LIB_ERR=""
# shellcheck source=lib/lived-probe.sh
if [ ! -f "$CB_LIB_DIR/lived-probe.sh" ] || ! . "$CB_LIB_DIR/lived-probe.sh"; then
  CB_LIVED_LIB_ERR="scripts/lib/lived-probe.sh is missing (this check sees ABSENCE only — an unsourceable file aborts before it runs)"
elif ! command -v kit_lived_signals >/dev/null 2>&1; then
  CB_LIVED_LIB_ERR="scripts/lib/lived-probe.sh sourced, but kit_lived_signals is NOT DEFINED"
fi

# The one reader of a config.sh glob array (CODE_GLOBS, TEST_GLOBS), shared with the ablation
# check. Without it the arms that read those arrays cannot run: a recorded skip, never an exit
# and never a verdict read off an empty answer.
CB_GLOB_LIB_ERR=""
# shellcheck source=lib/glob-array.sh
if [ ! -f "$CB_LIB_DIR/glob-array.sh" ] || ! . "$CB_LIB_DIR/glob-array.sh" 2>/dev/null; then
  CB_GLOB_LIB_ERR="scripts/lib/glob-array.sh is missing or does not load"
elif ! command -v kit_glob_array >/dev/null 2>&1; then
  CB_GLOB_LIB_ERR="scripts/lib/glob-array.sh sourced, but kit_glob_array is NOT DEFINED"
fi

# The shared register parser (arm [l] and finish-pr.sh's `forks:` precondition read the SAME
# register the same way). A load failure degrades arm [l] to its own "no register read" line —
# it already handles l_reg_read==0 as absence — never an exit.
# shellcheck source=lib/decision-register.sh
[ -f "$CB_LIB_DIR/decision-register.sh" ] && . "$CB_LIB_DIR/decision-register.sh" 2>/dev/null || true

# The shared attribution-family reader (arm [h] and scripts/githooks/commit-msg's rule (2) read
# the SAME wording list and fold the SAME Unicode hyphens the SAME way). A load failure degrades
# arm [h] to its own narrower, un-normalized pair — never an exit.
# shellcheck source=lib/attrib-trailer.sh
[ -f "$CB_LIB_DIR/attrib-trailer.sh" ] && . "$CB_LIB_DIR/attrib-trailer.sh" 2>/dev/null || true

# The shared PROJECT.md marker-line reader (arm [g]'s (g2d) and scripts/ask.sh read the SAME
# `principal:`/channel lines the SAME way — a natural fill with no backticks is not unfilled).
# A load failure leaves (g2d) unmeasured, never read by a second parser — never an exit.
# shellcheck source=lib/pm-field.sh
[ -f "$CB_LIB_DIR/pm-field.sh" ] && . "$CB_LIB_DIR/pm-field.sh" 2>/dev/null || true

# The shared board-property checks (arms [d], [i], [l], [p], [q], [r] and the landing in
# lib/qa-gate.sh run the SAME functions). A load failure leaves each of those arms printing that it
# did not run, never reading clean — and never an exit.
# shellcheck source=lib/board-properties.sh
[ -f "$CB_LIB_DIR/board-properties.sh" ] && . "$CB_LIB_DIR/board-properties.sh" 2>/dev/null || true
# The shared card-field reader (arm [m] and every script that reads a card's frontmatter key use
# it). A load failure leaves [m] printing that it did not run.
# shellcheck source=lib/card-field.sh
[ -f "$CB_LIB_DIR/card-field.sh" ] && . "$CB_LIB_DIR/card-field.sh" 2>/dev/null || true
cb_bp_loaded() { command -v kit_bp_ids >/dev/null 2>&1; }
cb_bp_missing() { echo "      – scripts/lib/board-properties.sh is missing or did not load — this arm did not run  (skipped)"; }

# The shared model-seam reader (arm [s] and scripts/set-models.sh read the SAME class table, ladder
# cells and pin frontmatter). A load failure leaves [s] printing that it did not run.
# shellcheck source=lib/model-pins.sh
[ -f "$CB_LIB_DIR/model-pins.sh" ] && . "$CB_LIB_DIR/model-pins.sh" 2>/dev/null || true

# ── THE SOURCE EVERY TRUNK-PROPERTY ARM ANSWERS ABOUT ────────────────────────
# Resolved as kwt_resolve does, and the last link is READ from that library, never re-typed.
CB_REMOTE="${KWT_REMOTE:-origin}"
# Every link below the first is labelled GUESSED in the output (CB_TRUNK_SRC): a clean report
# about a guessed branch name is worse than none.
CB_TRUNK_SRC=""
CB_TRUNK="$(git -C "$REPO_ROOT" symbolic-ref --short "refs/remotes/$CB_REMOTE/HEAD" 2>/dev/null | sed "s|^$CB_REMOTE/||" || true)"
if [ -n "$CB_TRUNK" ]; then
  CB_TRUNK_SRC="$CB_REMOTE/HEAD"
else
  CB_TRUNK="$(git -C "$REPO_ROOT" config --get init.defaultBranch 2>/dev/null || true)"
  if [ -n "$CB_TRUNK" ]; then
    CB_TRUNK_SRC="GUESSED from init.defaultBranch (step 2) — $CB_REMOTE/HEAD is unset"
  else
    CB_TRUNK="$(sed -n 's/^KWT_TRUNK_LAST_RESORT="\${KWT_TRUNK_LAST_RESORT:-\([^}]*\)}"/\1/p' \
                  "$REPO_ROOT/scripts/lib/kanban-worktree.sh" 2>/dev/null | head -1)"
    [ -n "$CB_TRUNK" ] \
      && CB_TRUNK_SRC="GUESSED from the kit's last-resort constant (step 3) — neither $CB_REMOTE/HEAD nor init.defaultBranch is set"
  fi
fi

# CB_SRC_KIND is `ref` or `worktree`; CB_SRC_LABEL is what every arm prints. With no
# <remote>/<trunk> ref (day one, a local-only clone) the arms read the working tree and SAY SO.
# cb_head_label <repo> — a branch prints as its quoted name, a detached HEAD as
# "a detached HEAD at <short sha>" (a bare DETACHED would read like a branch name).
cb_head_label() {
  local b h
  if b="$(git -C "$1" symbolic-ref -q --short HEAD 2>/dev/null)"; then printf "'%s'" "$b"; return; fi
  h="$(git -C "$1" rev-parse --short HEAD 2>/dev/null || true)"
  printf 'a detached HEAD at %s' "${h:-<no commit>}"
}

CB_REF=""
CB_SRC_KIND="worktree"
CB_SRC_LABEL=""
if [ -n "$CB_TRUNK" ] \
   && git -C "$REPO_ROOT" rev-parse --verify --quiet "refs/remotes/$CB_REMOTE/$CB_TRUNK" >/dev/null 2>&1; then  # card-read-exempt: the trunk, not a card branch
  CB_REF="$CB_REMOTE/$CB_TRUNK"
  CB_SRC_KIND="ref"
  CB_SRC_LABEL="$CB_REF @ $(git -C "$REPO_ROOT" rev-parse --short "$CB_REF" 2>/dev/null || echo '?')"
else
  CB_SRC_LABEL="WORKING TREE on $(cb_head_label "$REPO_ROOT") (no $CB_REMOTE/${CB_TRUNK:-<unresolved trunk>} ref)"
fi

# CB_TREE is the directory the board-reading arms walk. For a ref, one `git archive` into a temp
# dir: a `git show` per file would break the time budget on a large board.
CB_TREE="$REPO_ROOT"
CB_TMP=""
cb_cleanup() { [ -n "$CB_TMP" ] && rm -rf "$CB_TMP" 2>/dev/null; }
trap cb_cleanup EXIT
# The signals are trapped so the cleanup waits for the `archive | tar` below: with EXIT alone, a
# TERM or HUP runs cb_cleanup mid-copy and tar re-creates part of the temp dir. Signals not listed
# here, and SIGKILL, still race.
trap 'exit 143' TERM
trap 'exit 129' HUP
trap 'exit 130' INT
if [ "$CB_SRC_KIND" = "ref" ]; then
  CB_TMP="$(mktemp -d 2>/dev/null || true)"
  if [ -n "$CB_TMP" ] \
     && git -C "$REPO_ROOT" archive --format=tar "$CB_REF" 2>/dev/null \
        | tar -x -C "$CB_TMP" 2>/dev/null; then
    CB_TREE="$CB_TMP"
  else
    # Archive failed: degrade to the checkout and RELABEL, so no arm names a ref it did not read.
    CB_SRC_KIND="worktree"
    CB_SRC_LABEL="WORKING TREE on $(cb_head_label "$REPO_ROOT") (could not read $CB_REF — archive failed)"
    CB_REF=""
    CB_TREE="$REPO_ROOT"
  fi
fi

# One helper so no arm can print a verdict without its operand beside it.
cb_src() {
  printf 'read from: %s' "$CB_SRC_LABEL"
  # A guessed trunk name rides with the source line: every trunk arm is then a guess.
  case "$CB_TRUNK_SRC" in GUESSED*) printf '\n   trunk: %s' "$CB_TRUNK_SRC" ;; esac
}

# ── Arm (b)'s operand: QA_COMPLETE_THRESHOLD, read from THIS SOURCE's scripts/config.sh —
# never a second default re-typed here (process/contracts/config-seam.md § 2). Extracted by
# its fixed declaration shape, never sourced: $CB_TREE may be an archived ref, not a tree this
# process should execute. Absent or unparseable falls back to the kit's own default and says so.
QA_COMPLETE_THRESHOLD="$KIT_QA_COMPLETE_THRESHOLD_DEFAULT"
QA_COMPLETE_THRESHOLD_SRC="the kit's own default (scripts/config.sh not found in this source)"
if [ -f "$CB_TREE/scripts/config.sh" ]; then
  _qct="$(sed -n 's/^QA_COMPLETE_THRESHOLD="\${QA_COMPLETE_THRESHOLD:-\([^}]*\)}"/\1/p' \
            "$CB_TREE/scripts/config.sh" | head -1)"
  if printf '%s' "$_qct" | grep -qE '^[0-9]+$'; then
    QA_COMPLETE_THRESHOLD="$_qct"
    QA_COMPLETE_THRESHOLD_SRC="scripts/config.sh in this source"
  else
    QA_COMPLETE_THRESHOLD_SRC="the kit's own default (scripts/config.sh in this source does not declare QA_COMPLETE_THRESHOLD in its shipped shape)"
  fi
  unset _qct
fi

drift=0
echo "── check-board.sh — board-drift report @ $(date +%Y-%m-%dT%H:%M:%S)"
echo "   repo: $REPO_ROOT"
echo "   $(cb_src)"
if [ "$CB_SRC_KIND" = "ref" ]; then
  echo "   (not fetched — this is the last known state of $CB_REF; refresh with: git -C '$REPO_ROOT' fetch $CB_REMOTE $CB_TRUNK)"
else
  echo "   ⚠ NOT A TRUNK REPORT. The arms below describe this checkout, not $CB_REMOTE/${CB_TRUNK:-<trunk>}."
  echo "     A board report from a feature branch is a report about the past."
fi

# ---------------------------------------------------------------------------
# (a) Folder vs last-Activity drift, across every column in STATUS_FOLDERS except the skip list
#     (done/ only, for the time budget). The column list is DERIVED, so a new column is in by
#     default and a skip owes a reason here. declined/ is walked: a hand-move there is as
#     invisible as anywhere, and this is the only arm that can see one.
#     The declared status comes from the last Activity bullet in TWO ORDERED PASSES: a transition
#     arrow `→ <folder>` (a declaration, what the mover emits) wins; only without one does a
#     backticked `<folder>` count (a mention). Neither → skipped. A bare `<folder>/` substring is
#     never read: it matches incidental path mentions.
# ---------------------------------------------------------------------------
# done/ only. A column added here owes its reason in the header above.
A_SKIP_COLS='done'
echo
echo "[a] Folder vs last-Activity drift (every column in STATUS_FOLDERS except ${A_SKIP_COLS}/) — $(cb_src):"
a_hits=0
a_cols=0
IFS='|' read -r -a a_all_cols <<< "$STATUS_FOLDERS"
a_cols_list=()
for folder in "${a_all_cols[@]}"; do
  case "|$A_SKIP_COLS|" in *"|$folder|"*) continue ;; esac
  a_cols_list+=("$folder")
done
# An empty derivation would make this arm vacuously green, so it is reported.
if [ "${#a_cols_list[@]}" -eq 0 ]; then
  echo "    ⚠ (control) no column survived the STATUS_FOLDERS derivation — this arm checked NOTHING; STATUS_FOLDERS is '$STATUS_FOLDERS' and the skip list is '$A_SKIP_COLS'"
  drift=1
fi
for folder in "${a_cols_list[@]}"; do
  dir="$CB_TREE/progress/$folder"
  # A missing column is a SKIP, never a pass (contracts/drift-report.md § 2-3).
  if [ ! -d "$dir" ]; then
    echo "    – progress/$folder/ absent in this source  (skipped)"
    continue
  fi
  a_cols=$((a_cols+1))
  for f in "$dir"/*.md; do
    [ -e "$f" ] || continue
    # Last Activity bullet: within the "## Activity" section, the last line that
    # begins (after optional space) with "- ".
    last="$(awk '/^##[[:space:]]+Activity/{a=1; next} a && /^[[:space:]]*-[[:space:]]/{l=$0} END{print l}' "$f")"
    [ -z "$last" ] && continue
    # PRECEDENCE, NOT A WIDER PATTERN: the arrow first, a backtick only when there is no arrow, so
    # "→ dev_complete: see `blocked`" reads as dev_complete. This arm is the guarantee, not the
    # mover's refusal of status tokens in notes: it reads every card, hand-edited ones included.
    declared="$(printf '%s' "$last" \
      | grep -oE "→[[:space:]]*(${STATUS_FOLDERS})" 2>/dev/null \
      | grep -oE "(${STATUS_FOLDERS})" 2>/dev/null | tail -1 || true)"
    if [ -z "$declared" ]; then
      declared="$(printf '%s' "$last" \
        | grep -oE "\`(${STATUS_FOLDERS})/?\`" 2>/dev/null \
        | grep -oE "(${STATUS_FOLDERS})" 2>/dev/null | tail -1 || true)"
    fi
    [ -z "$declared" ] && continue
    if [ "$declared" != "$folder" ]; then
      echo "    ⚠ $(basename "$f"): in $folder/ but last Activity declares → $declared"
      a_hits=$((a_hits+1)); drift=1
    fi
  done
done
if [ "$a_cols" -eq 0 ]; then
  echo "    – none of the columns this arm reads exists in this source — nothing was checked  (skipped)"
elif [ "$a_hits" -eq 0 ]; then
  echo "    ✓ none across $a_cols column(s) (every judgeable last-Activity entry matches its folder)"
fi

# ---------------------------------------------------------------------------
# (b) qa_complete/ column depth vs the archive threshold.
#     An ABSENT column is skipped, not counted as 0-and-passing: "0 / 10 ✓" over a
#     directory that does not exist is a statement about nothing.
# ---------------------------------------------------------------------------
echo
if [ ! -d "$CB_TREE/progress/qa_complete" ]; then
  echo "[b] qa_complete/ depth: progress/qa_complete/ absent in this source  (skipped) — $(cb_src)"
else
  qc_count=0
  for f in "$CB_TREE"/progress/qa_complete/*.md; do
    [ -e "$f" ] && qc_count=$((qc_count+1))
  done
  if [ "$qc_count" -gt "$QA_COMPLETE_THRESHOLD" ]; then
    echo "[b] qa_complete/ depth: $qc_count / $QA_COMPLETE_THRESHOLD threshold  ⚠ over — run ./scripts/archive.sh --apply — $(cb_src); threshold: $QA_COMPLETE_THRESHOLD_SRC"
    drift=1
  else
    echo "[b] qa_complete/ depth: $qc_count / $QA_COMPLETE_THRESHOLD threshold  ✓ — $(cb_src); threshold: $QA_COMPLETE_THRESHOLD_SRC"
  fi
fi

# ---------------------------------------------------------------------------
# (c) progress.md size — two distinct readings, so a ✓ on one is never read as the other:
#       • § Log SLICE: bytes from "## Log" to the next "## " heading (or EOF); sets drift.
#       • WHOLE FILE: total bytes against its own threshold; advisory, never sets drift.
# ---------------------------------------------------------------------------
echo
pmd="$CB_TREE/progress.md"
if [ -f "$pmd" ]; then
  if [ -z "${KIT_LOG_HEADING_ERE:-}" ]; then
    # The heading is declared in scripts/lib/lived-probe.sh; without it there is no § Log to find.
    echo "[c] progress.md § Log SLICE: THIS CHECK DID NOT RUN — ${CB_LIVED_LIB_ERR:-scripts/lib/lived-probe.sh declares no KIT_LOG_HEADING_ERE}, and that file declares the '## Log' heading  (skipped) — $(cb_src)"
  elif grep -qE "$KIT_LOG_HEADING_ERE" "$pmd"; then
    logbytes="$(awk -v re="$KIT_LOG_HEADING_ERE" '
      /^##[[:space:]]/ { if (inlog) exit; if ($0 ~ re) inlog=1 }
      inlog { print }
    ' "$pmd" | wc -c | tr -d ' ')"
    if [ "$logbytes" -gt "$PROGRESS_LOG_BYTE_THRESHOLD" ]; then
      echo "[c] progress.md § Log SLICE: $logbytes / $PROGRESS_LOG_BYTE_THRESHOLD bytes  ⚠ over — run ./scripts/archive-progress.sh — $(cb_src)"
      drift=1
    else
      echo "[c] progress.md § Log SLICE: $logbytes / $PROGRESS_LOG_BYTE_THRESHOLD bytes  ✓ — $(cb_src)"
    fi
  else
    echo "[c] progress.md § Log SLICE: no '## Log' heading found  (skipped) — $(cb_src)"
  fi
  wholebytes="$(wc -c < "$pmd" | tr -d ' ')"
  if [ "$wholebytes" -gt "$PROGRESS_WHOLE_FILE_BYTE_THRESHOLD" ]; then
    # `reports only` is a machine contract (contracts/drift-report.md § 4): kit-init's
    # self-check drops advisory sections by that literal. Without it this ⚠ fails an install.
    echo "[c] progress.md WHOLE FILE: $wholebytes / $PROGRESS_WHOLE_FILE_BYTE_THRESHOLD bytes  ⚠ over (reports only — it never changes the verdict below) — a rotation is due, see ./scripts/archive-progress.sh — $(cb_src)"
  else
    echo "[c] progress.md WHOLE FILE: $wholebytes / $PROGRESS_WHOLE_FILE_BYTE_THRESHOLD bytes  ✓ — $(cb_src)"
  fi
  # LAST ENTRY vs the last CODE commit. "Code" is the project's own CODE_GLOBS (the code-vs-metadata
  # rule's one definition): a board move, a register edit or a progress.md commit touches no code
  # path, so none counts. Without a declared CODE_GLOBS nothing separates code from metadata, and
  # the check says it did not run. The entry's time is the commit that last touched progress.md.
  c_ref="${CB_REF:-HEAD}"
  c_specs=()
  c_nglob=0
  c_decl=0
  if [ -f "$CB_TREE/scripts/config.sh" ] && [ -z "$CB_GLOB_LIB_ERR" ]; then
    while IFS= read -r c_tag; do
      case "$c_tag" in
        E\|*) c_specs+=(":(top)${c_tag#E|}"); c_nglob=$((c_nglob+1)) ;;
        D) c_decl=1 ;;
      esac
    done < <(kit_glob_array CODE_GLOBS "$CB_TREE/scripts/config.sh")
  fi
  c_pc="$(git -C "$REPO_ROOT" log -1 --format=%H "$c_ref" -- ':(top)progress.md' 2>/dev/null || true)"
  if [ -n "$CB_GLOB_LIB_ERR" ]; then
    echo "[c] progress.md LAST ENTRY: THIS CHECK DID NOT RUN — $CB_GLOB_LIB_ERR, and CODE_GLOBS cannot be read without it  (skipped) — $(cb_src)"
  elif [ "$c_nglob" -eq 0 ]; then
    echo "[c] progress.md LAST ENTRY: THIS CHECK DID NOT RUN — CODE_GLOBS in scripts/config.sh is $([ "$c_decl" -eq 1 ] && echo 'declared empty' || echo 'undeclared'), so nothing separates a code commit from a metadata one  (skipped) — $(cb_src)"
  elif [ -z "$c_pc" ]; then
    echo "[c] progress.md LAST ENTRY: no commit of $c_ref has touched progress.md  (skipped) — $(cb_src)"
  else
    c_all="$(git -C "$REPO_ROOT" rev-list --count "$c_pc..$c_ref" 2>/dev/null || echo 0)"
    c_code="$(git -C "$REPO_ROOT" rev-list --count "$c_pc..$c_ref" -- "${c_specs[@]}" 2>/dev/null || echo 0)"
    c_when="$(git -C "$REPO_ROOT" log -1 --format='%h %cs' "$c_pc" 2>/dev/null || true)"
    if [ "${c_code:-0}" -gt 0 ]; then
      c_newest="$(git -C "$REPO_ROOT" log -1 --format='%h %s' "$c_ref" -- "${c_specs[@]}" 2>/dev/null || true)"
      echo "[c] progress.md LAST ENTRY: $c_code of $c_all commit(s) since progress.md was last touched ($c_when) touch a CODE_GLOBS path  ⚠ newest: $c_newest — the close ritual's 'progress.md written' step does not cover them; add the entry (reports only — a close with no code change is legal, and it never changes the verdict below) — $(cb_src); code = $c_nglob CODE_GLOBS entry/entries"
    else
      echo "[c] progress.md LAST ENTRY: 0 of $c_all commit(s) since progress.md was last touched ($c_when) touch a CODE_GLOBS path  ✓ — $(cb_src); code = $c_nglob CODE_GLOBS entry/entries"
    fi
  fi
else
  echo "[c] progress.md: not found in this source  (skipped) — $(cb_src)"
fi

# BEGIN check (d)
# ---------------------------------------------------------------------------
# (d) Frontmatter id integrity across EVERY column in STATUS_FOLDERS (done/ included: a new mint
#     can collide with an archived issue), then the same invariant for the declared REGISTERS.
#     The check is lib/board-properties.sh's kit_bp_ids, the one implementation the landing
#     (finish-pr.sh, subtask.sh) also calls: this arm reports it and sets `drift`, and a landing
#     refuses a finding the branch introduces. It reports; it never renumbers.
# ---------------------------------------------------------------------------
echo
echo "[d] Frontmatter id integrity (every column in STATUS_FOLDERS) — $(cb_src):"
if cb_bp_loaded; then
  kit_bp_ids "$CB_TREE"
  [ "$KIT_BP_NHITS" -eq 0 ] || drift=1
else
  cb_bp_missing
fi
# END check (d)

# ---------------------------------------------------------------------------
# (e) [Role]-prefix scan of every trunk commit since the rule's epoch (the last ROLE_SCAN_N when no
#     epoch can be derived). Plain history, never
#     --first-parent: a forge squash-merge puts the real `[Role] <ID> …` subject on PARENT 2 of a
#     merge commit, so a merge is judged by parent 2 and a non-merge by its own subject.
#     Git/host subjects (Merge/Revert/Squash/autosquash) are exempt, mirroring commit-msg's list
#     and its narrowness. The prefixes and the subjects are read from the same source.
# ---------------------------------------------------------------------------
echo
# The canonical read, byte-identical to scripts/lib/role-set.sh's kit_role_set (the self-test
# holds every site identical). FALLBACK POLICY HERE: a hardcoded set, ANNOUNCED in the output.
ROLE_PREFIXES="$(sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p" "$CB_TREE/scripts/githooks/commit-msg" 2>/dev/null | head -1)"
# The literal below is the fallback and the half that drifts: correct it, never replace the
# derivation with it.
role_src="derived from scripts/githooks/commit-msg"
if [ -z "$ROLE_PREFIXES" ]; then
  ROLE_PREFIXES='PM|Dev|QA|Refactorer|UIDesigner|Orchestrator|Architect'
  # Named in the output: a ✓ over the fallback set is not a ✓ over your project's roles.
  role_src="THE KIT'S FALLBACK SET — commit-msg was not readable in this source, so this is not your project's declared role set"
fi
# The revision walked is stated, not implied.
if [ -n "$CB_REF" ]; then
  CB_RULE_REV="$CB_REF"
else
  CB_RULE_REV="HEAD"
fi
# THE RULE'S EPOCH — derived ONCE here and shared by every history arm; no arm re-derives it.
# commit-msg's rules bind from the commit that ADDED the hook file (its EARLIEST add). Earlier
# commits predate the rule and are not reported: such a finding could only be fixed by rewriting
# published history. The hook file, not the stamp receipt (a hand-copy adopter has none); wiring
# core.hooksPath leaves no commit to find.
# kit-init's attribution filter uses a later boundary on purpose (see its board self-check).
# On a SHALLOW clone the add resolves to the graft boundary, so no epoch is derived and nothing is
# excluded: it errs toward reporting.
CB_RULE_EPOCH=""; CB_RULE_SHALLOW=""; role_why=""
if [ "$(git -C "$REPO_ROOT" rev-parse --is-shallow-repository 2>/dev/null || echo false)" = "true" ]; then
  CB_RULE_SHALLOW="yes"
elif git -C "$REPO_ROOT" rev-parse --verify --quiet "$CB_RULE_REV" >/dev/null 2>&1; then
  CB_RULE_EPOCH="$( { git -C "$REPO_ROOT" log --diff-filter=A --format=%H "$CB_RULE_REV" \
                     -- scripts/githooks/commit-msg 2>/dev/null || true; } | tail -1 )"
fi
# STRICTLY AFTER the epoch: the day-one `init` commit adds the hook file itself and is unprefixed.
CB_RULE_INSCOPE=""
if [ -n "$CB_RULE_EPOCH" ]; then
  CB_RULE_INSCOPE="$(git -C "$REPO_ROOT" rev-list --ancestry-path "$CB_RULE_EPOCH..$CB_RULE_REV" 2>/dev/null || true)"
fi
# THE WINDOW the history arms walk, derived once: every commit after the epoch — a bypass is not
# forgiven because later commits followed it — else the last ROLE_SCAN_N. CB_RULE_PRE counts the
# commits at or before the epoch, which are not read.
CB_RULE_LOG_ARGS=(-n "$ROLE_SCAN_N" "$CB_RULE_REV"); CB_RULE_PRE=0
if [ -n "$CB_RULE_EPOCH" ]; then
  CB_RULE_LOG_ARGS=("$CB_RULE_EPOCH..$CB_RULE_REV")
  CB_RULE_PRE="$(git -C "$REPO_ROOT" rev-list --count "$CB_RULE_EPOCH" 2>/dev/null || echo 0)"
fi
# One renderer for the scope lines, used by every history arm.
cb_rule_scope_lines() {
  if [ -n "$CB_RULE_EPOCH" ]; then
    echo "    scope: every commit after ${CB_RULE_EPOCH:0:9}, which ADDED scripts/githooks/commit-msg — $CB_RULE_PRE earlier commit(s) not read, as predating the rule"
    echo "      caveat: the epoch is the hook FILE's arrival, not the moment core.hooksPath was set — a"
    echo "      clone that never wired it is not enforcing the rule, yet this arm treats it as binding from"
    echo "      that commit. Erring toward reporting drift, not hiding it. This arm's findings flip the"
    echo "      board-drift verdict that release.sh gate (d) refuses on."
  elif [ -n "$CB_RULE_SHALLOW" ]; then
    echo "    scope: ALL of the last $ROLE_SCAN_N — THIS IS A SHALLOW CLONE, so the rule's start cannot be"
    echo "      derived: a grafted root has no parents and every file in it reads as ADDED there, which would"
    echo "      resolve the epoch to the clone boundary and narrow this arm to almost nothing. Nothing was"
    echo "      excluded. Run the report against a full clone if you need the narrowing."
  else
    echo "    scope: ALL of the last $ROLE_SCAN_N — no commit in $CB_RULE_REV adds scripts/githooks/commit-msg,"
    echo "      so the rule's start could not be derived and NOTHING was excluded. Any commit here that"
    echo "      predates your adoption of the kit is reported below as drift and is not."
  fi
}

# cb_revert_matches <sha> — true when <sha>'s own diff is the reverse of the commit its body names
# ("This reverts commit <sha>."), compared by patch-id so moved line numbers do not matter.
cb_revert_matches() {
  local sha="$1" named empty a b
  named="$(git -C "$REPO_ROOT" log -1 --format=%B "$sha" 2>/dev/null | sed -n 's/^This reverts commit \([0-9a-f]\{7,40\}\).*/\1/p' | sed -n '1p')"
  [ -n "$named" ] || return 1
  git -C "$REPO_ROOT" rev-parse --verify --quiet "$sha^1" >/dev/null 2>&1 || return 1
  git -C "$REPO_ROOT" rev-parse --verify --quiet "$named^{commit}" >/dev/null 2>&1 || return 1
  empty="$(git -C "$REPO_ROOT" hash-object -t tree /dev/null)"
  a="$(git -C "$REPO_ROOT" diff "$sha^1" "$sha" 2>/dev/null | git -C "$REPO_ROOT" patch-id --stable | cut -d' ' -f1)"
  if git -C "$REPO_ROOT" rev-parse --verify --quiet "$named^1" >/dev/null 2>&1; then
    b="$(git -C "$REPO_ROOT" diff "$named" "$named^1" 2>/dev/null | git -C "$REPO_ROOT" patch-id --stable | cut -d' ' -f1)"
  else
    b="$(git -C "$REPO_ROOT" diff "$named" "$empty" 2>/dev/null | git -C "$REPO_ROOT" patch-id --stable | cut -d' ' -f1)"
  fi
  [ -n "$a" ] && [ "$a" = "$b" ]
}
# cb_fixup_matches <sha> <subject> — true when the subject's `fixup! `/`squash! `/`amend! ` chain
# names an EARLIER commit by its subject and <sha> touches only files that commit touched.
cb_fixup_matches() {
  local sha="$1" tsubj="$2" cand cfiles ffiles f
  while :; do
    case "$tsubj" in
      "fixup! "*) tsubj="${tsubj#fixup! }" ;;
      "squash! "*) tsubj="${tsubj#squash! }" ;;
      "amend! "*) tsubj="${tsubj#amend! }" ;;
      *) break ;;
    esac
  done
  [ -n "$tsubj" ] || return 1
  git -C "$REPO_ROOT" rev-parse --verify --quiet "$sha^1" >/dev/null 2>&1 || return 1
  cand="$(git -C "$REPO_ROOT" log --no-color --format='%H|%s' --fixed-strings --grep="$tsubj" "$sha^1" 2>/dev/null \
            | awk -F'|' -v t="$tsubj" '{ s=$0; sub(/^[^|]*\|/, "", s); if (s == t) { print $1; exit } }')"
  [ -n "$cand" ] || return 1
  cfiles="$(git -C "$REPO_ROOT" diff-tree --no-commit-id --name-only -r --root "$cand" 2>/dev/null)"
  ffiles="$(git -C "$REPO_ROOT" diff-tree --no-commit-id --name-only -r "$sha" 2>/dev/null)"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    printf '%s\n' "$cfiles" | grep -xF -- "$f" >/dev/null || return 1
  done <<< "$ffiles"
  return 0
}

echo "[e] [Role]-prefix scan (commits of $CB_RULE_REV since the rule began, squash-aware) — prefixes $role_src:"
role_hits=0
role_scanned=0
role_exempt=0
if git -C "$REPO_ROOT" rev-parse --verify --quiet "$CB_RULE_REV" >/dev/null 2>&1; then
  while IFS='|' read -r sha parents subj; do
    [ -z "$sha" ] && continue
    # shellcheck disable=SC2086
    set -- $parents                       # word-split the space-separated parent list
    if [ "$#" -ge 2 ]; then
      target="$2"                         # merge commit → parent 2 carries the squashed [Role] subject
      subj=""
    else
      target="$sha"                       # non-merge → its own subject
    fi
    # Out of scope is skipped, not scanned: a side-branch commit the epoch's range reaches but
    # that is not a descendant of it. Tested on $sha (the walked commit), not $target: a merge's
    # parent 2 lives on a side branch.
    if [ -n "$CB_RULE_EPOCH" ]; then
      case $'\n'"$CB_RULE_INSCOPE"$'\n' in *$'\n'"$sha"$'\n'*) ;; *) continue ;; esac
    fi
    [ -n "$subj" ] || subj="$(git -C "$REPO_ROOT" log -1 --format=%s "$target" 2>/dev/null || true)"
    [ -z "$subj" ] && continue
    role_scanned=$((role_scanned+1))
    # "Merge commit '" REQUIRES the quote — the literal shape `git merge <sha>` writes
    # (`Merge commit '<full-hash>'`) — or this exemption also swallows an ordinary,
    # human-authored subject that happens to start with the same two words
    # ("Merge commit messages into one doc"), which is never git-generated and would be
    # silently counted as scanned-and-exempt rather than as a missing [Role] prefix.
    case "$subj" in
      "Merge branch "*|"Merge remote-tracking branch "*|"Merge pull request "*|"Merge tag "*|"Merge commit '"*) role_exempt=$((role_exempt+1)); continue ;;
      "Squashed commit of the following:"*) role_exempt=$((role_exempt+1)); continue ;;   # narrowed with commit-msg's
      "Revert \""*|"Revert '"*)
        # Exempt only when the diff undoes the commit the body names; the subject alone proves nothing.
        if cb_revert_matches "$target"; then role_exempt=$((role_exempt+1)); continue; fi
        role_why=" (a Revert whose diff does not undo a commit it names)" ;;
      "fixup! "*|"squash! "*|"amend! "*)
        # Exempt only when it names an earlier commit and touches nothing that commit did not.
        if cb_fixup_matches "$target" "$subj"; then role_exempt=$((role_exempt+1)); continue; fi
        role_why=" (a fixup!/squash!/amend! whose target is missing or whose diff leaves the target's files)" ;;
    esac
    if ! printf '%s' "$subj" | grep -qE "^\[(${ROLE_PREFIXES})\] "; then
      echo "    ⚠ ${target:0:9} subject lacks a [Role] prefix: $subj${role_why:-}"
      role_hits=$((role_hits+1)); drift=1
    fi
    role_why=""
  done < <(git -C "$REPO_ROOT" log --no-color --format='%H|%P|%s' "${CB_RULE_LOG_ARGS[@]}" 2>/dev/null)
else
  # No history is a SKIP, never a ✓ over zero subjects.
  echo "    – $CB_RULE_REV does not resolve — no history to scan  (skipped)"
  role_scanned=-1
fi
# The scope lines print on the clearing branch too (doctrine/instruments.md § A.4).
if [ "$role_scanned" -ge 0 ]; then
  cb_rule_scope_lines
fi
if [ "$role_scanned" -eq 0 ]; then
  echo "    – $CB_RULE_REV resolved but yielded no inspectable subject  (skipped)"
elif [ "$role_scanned" -gt 0 ] && [ "$role_hits" -eq 0 ]; then
  # TWO POPULATIONS, printed apart: role_scanned includes every exempted subject (git's own
  # merge/revert/squash/autosquash shapes), which were never held to the rule — "all N carry"
  # over a count that INCLUDES them is a sentence that claims more than this arm checked.
  echo "    ✓ $((role_scanned - role_exempt)) subject(s) carry a [Role] prefix; $role_exempt exempt (merge/revert/squash/autosquash) not held to it"
fi

# ---------------------------------------------------------------------------
# (f) UNPUBLISHED WORK, in both homes the process writes to, each named separately:
#     [f1] the main checkout's LOCAL trunk ref, where every metadata commit lands, and
#     [f2] the board mover's .kanban-wt. LOCAL BY DESIGN: the question is what never reached the
#     trunk, which the trunk cannot answer. kwt_sync already refuses to reset over an unpushed
#     commit; this arm surfaces one at session close.
#     Span: commits reachable from a ref. An orphaned commit (reachable from no ref) is outside
#     it and needs the reflog; the arm says so at its foot.
#     The main worktree is found through --git-common-dir, so the arm is correct from a linked
#     worktree. It skips, never warns, when .kanban-wt or the remote ref is absent.
# ---------------------------------------------------------------------------
echo
# The main worktree's root: the parent of the COMMON git dir, which is identical from
# every linked worktree. Falls back to $REPO_ROOT when git cannot say.
cb_common="$(git -C "$REPO_ROOT" rev-parse --git-common-dir 2>/dev/null || true)"
case "$cb_common" in
  "") kwt_main="$REPO_ROOT" ;;
  /*) kwt_main="$(cd "$cb_common/.." 2>/dev/null && pwd || echo "$REPO_ROOT")" ;;
  *)  kwt_main="$(cd "$REPO_ROOT/$cb_common/.." 2>/dev/null && pwd || echo "$REPO_ROOT")" ;;
esac
kwt_dir="$kwt_main/.kanban-wt"
remote="$CB_REMOTE"
def="$CB_TRUNK"
echo "[f] Unpublished work in the homes this process writes to — TWO homes, each named:"
if [ "$kwt_main" != "$REPO_ROOT" ]; then
  echo "      (this run is inside a linked worktree; both homes are resolved against the main checkout $kwt_main)"
fi
if [ -z "$def" ]; then
  echo "      the trunk is UNCONFIRMED ($remote/HEAD and init.defaultBranch are both unset, and the kit's last-resort constant was unreadable)"
  echo "      Settle it: git remote set-head $remote <your-trunk>"
fi

# ── [f1] THE MAIN CHECKOUT'S TRUNK REF ───────────────────────────────────────
# The operand is the local trunk BRANCH, not HEAD: a leg legitimately holds the main checkout on a
# feature branch, and HEAD-vs-trunk would redden every normal run. HEAD is reported beside it.
f_main_ref="refs/heads/${def:-}"
if [ -z "$def" ]; then
  echo "      [f1] main checkout: trunk unresolved, so there is no ref to compare  (skipped) — inspected: $kwt_main"
elif ! git -C "$kwt_main" rev-parse --verify --quiet "$f_main_ref" >/dev/null 2>&1; then
  echo "      [f1] main checkout: no local '$def' branch exists yet  (skipped) — inspected: $kwt_main"
elif ! git -C "$kwt_main" rev-parse --verify --quiet "refs/remotes/$remote/$def" >/dev/null 2>&1; then  # card-read-exempt: the trunk, not a card branch
  echo "      [f1] main checkout: $remote/$def unavailable (never pushed? offline?)  (skipped) — inspected: $kwt_main"
else
  f_head="$(cb_head_label "$kwt_main")"
  f_ahead="$(git -C "$kwt_main" rev-list --count "$remote/$def..$f_main_ref" 2>/dev/null || echo 0)"
  f_behind="$(git -C "$kwt_main" rev-list --count "$f_main_ref..$remote/$def" 2>/dev/null || echo 0)"
  if [ "${f_ahead:-0}" -gt 0 ]; then
    echo "      [f1] main checkout: '$def' is $f_ahead commit(s) AHEAD of $remote/$def  ⚠ UNPUBLISHED — everything the process records as metadata lands here, so this is rulings/PRDs/board edits nobody else can see"
    echo "           Fix: git -C '$kwt_main' push $remote $def   (checked out here: $f_head)"
    drift=1
  else
    echo "      [f1] main checkout: '$def' is 0 ahead / $f_behind behind $remote/$def  ✓ — read from: $f_main_ref in $kwt_main (checked out here: $f_head)"
    # "Behind" is reported, never refused: this arm does not fetch, so its view of the remote may
    # be stale. release.sh gate (a) fetches first, and does refuse. Do not make this one refuse.
    [ "${f_behind:-0}" -gt 0 ] && echo "           ($f_behind behind is a STALE VIEW, not lost work — pull when convenient. NOTE: release.sh gate (a) DOES refuse a cut from here; it fetches first, this arm does not.)"
  fi
fi

# ── [f2] THE BOARD MOVER'S PUBLICATION PATH. ─────────────────────────────────
if [ -d "$kwt_dir" ] && git -C "$kwt_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [ -n "$def" ] && git -C "$kwt_dir" rev-parse --verify --quiet "$remote/$def" >/dev/null 2>&1; then
    ahead="$(git -C "$kwt_dir" rev-list --count "$remote/$def..HEAD" 2>/dev/null || echo 0)"
    if [ "${ahead:-0}" -gt 0 ]; then
      echo "      [f2] .kanban-wt: HEAD is $ahead commit(s) AHEAD of $remote/$def  ⚠ a board move committed and not pushed — read from: WORKING TREE at $kwt_dir"
      echo "           Fix: push them — git -C '$kwt_dir' push $remote HEAD:$def — or re-run the op that owns the commit."
      drift=1
    else
      echo "      [f2] .kanban-wt: 0 commit(s) ahead of $remote/$def  ✓ — read from: WORKING TREE at $kwt_dir"
    fi
  else
    echo "      [f2] .kanban-wt: $remote/${def:-<unresolved trunk>} unavailable (offline?)  (skipped) — inspected: $kwt_dir"
  fi
else
  echo "      [f2] .kanban-wt: no registered worktree at $kwt_dir  (skipped)"
fi
echo "      (span, both homes: commits REACHABLE FROM A REF. A commit reachable from no ref at all — an orphaned sibling — is outside this measurement and would need the reflog.)"

# ── [f3] A REMOTE BRANCH LEFT BEHIND BY A CARD THAT HAS LANDED ───────────────
# Printed under its OWN `[f]` header carrying "reports only": the drift-report contract's machine
# reading drops an advisory section by that header, and [f]'s own header decides.
# A card's branch is `<kind>/<ID>-<slug>`; the landing deletes it, so one still on the remote
# after its card reached done/ or qa_complete/ is a re-cut or an aborted landing's leftover. Read
# from the remote-tracking refs as last fetched (no fetch), against the cards in THIS source's
# done/ and qa_complete/. A branch for a card still open or blocked is correctly left alone.
f3_ids=""; f3_ran=1
command -v kit_card_id_of_path >/dev/null 2>&1 || f3_ran=""
for f3_col in done qa_complete; do
  [ -d "$CB_TREE/progress/$f3_col" ] || continue
  for f3_f in "$CB_TREE/progress/$f3_col"/*.md; do
    [ -f "$f3_f" ] || continue
    f3_id="$(kit_card_id_of_path "$f3_f" 2>/dev/null || true)"
    [ -n "$f3_id" ] && f3_ids="$f3_ids $f3_id "
  done
done
echo "[f] remote branches left by a landed card (reports only — never changes the verdict below):"
f3_refs="$(git -C "$REPO_ROOT" for-each-ref --format='%(refname:short)' "refs/remotes/$remote/" 2>/dev/null || true)"  # card-read-exempt: lists every remote branch to name leftovers; resolves none
if [ -z "$f3_ran" ]; then
  echo "      [f3] remote branches: THIS CHECK DID NOT RUN — scripts/lib/card-field.sh is missing or did not load  (skipped) — $(cb_src)"
elif [ -z "$f3_refs" ]; then
  echo "      [f3] remote branches: no $remote/* ref in this checkout  (skipped) — inspected: refs/remotes/$remote/ (as last fetched)"
else
  f3_n=0; f3_card=0; f3_stale=""
  while IFS= read -r f3_r; do
    f3_b="${f3_r#"$remote"/}"
    [ "$f3_b" = "HEAD" ] || [ "$f3_b" = "$remote" ] && continue
    f3_n=$((f3_n+1))
    f3_seg="${f3_b##*/}"
    f3_id="$(printf '%s\n' "$f3_seg" | sed -nE 's/^([A-Za-z][A-Za-z0-9]*-[0-9]+)(-.*)?$/\1/p')"
    [ -n "$f3_id" ] || continue
    f3_card=$((f3_card+1))
    case "$f3_ids" in *" $f3_id "*) f3_stale="${f3_stale}${f3_stale:+, }$f3_b" ;; esac
  done <<< "$f3_refs"
  if [ -n "$f3_stale" ]; then
    echo "      [f3] remote branches: $f3_n read, $f3_card named for a card; these name a card already in done/ or qa_complete/  ⚠ $f3_stale — a leftover of a re-cut or an aborted landing; delete it if nothing needs it: git push $remote --delete <branch> — inspected: refs/remotes/$remote/ as last fetched; cards: $(cb_src)"
  else
    echo "      [f3] remote branches: $f3_n read, $f3_card named for a card, none for a card in done/ or qa_complete/  ✓ — inspected: refs/remotes/$remote/ as last fetched; cards: $(cb_src)"
  fi
fi

# ---------------------------------------------------------------------------
# (g) GRADUATION — has day one finished, and has the scaffolding been replaced?
#     Reads the trunk like the other trunk-property arms: its subjects are metadata-lane, and a
#     working-tree read could declare graduation on an unpushed edit and never re-ask.
#     It NEVER sets `drift`: the verdict line answers "is the board truthful?" and release.sh
#     gate (d) reads it; a tree one minute after kit-init has not graduated, and its board is
#     truthful. Making graduation block a release is a ruling for release.sh's own gate list.
#     It never goes silent: once satisfied it still prints one line naming what it read.
# ---------------------------------------------------------------------------
echo

# G_GRADUATION_COMPLETE: arm [p] below reuses THIS arm's own verdict rather than re-deriving
# "has day one closed" a second way. Set to 1 only in the COMPLETE branch; every other outcome
# (not-run, unmeasured, not-finished) leaves it 0, which [p] reads as "cannot say day one closed".
G_GRADUATION_COMPLETE=0

# The stamp receipt token, DERIVED from kit-init.sh (the fallback is the shipped literal).
g_stamp="$(sed -n "s/^STAMP_MARK='\(.*\)'/\1/p" "$CB_TREE/scripts/kit-init.sh" 2>/dev/null | head -1)"
[ -n "$g_stamp" ] || g_stamp='# Stamped by scripts/kit-init.sh'

# `reports only` below is a machine contract (contracts/drift-report.md § 4 item 5), read by
# kit-init's self-check. Change it here, there and in the contract together, or not at all.
echo "[g] Graduation — has day one finished?  (reports only; it never changes the verdict below —"
echo "      a repository one minute after kit-init has not graduated, and its board is truthful)"
# ENABLED WHEN THE REPOSITORY HAS LIVED, not only when kit-init ran: a project on SEED step 2
# branch B never runs kit-init. The signals come from scripts/lib/lived-probe.sh, shared with
# kit-init; a tree with no signal is not nagged.
# CAPTURE, THEN SLICE — never `kit_lived_signals … | head -1`: under pipefail, head's early close
# returns SIGPIPE as the status. The library emits the receipt first.
g_lived=""
if [ -z "$CB_LIVED_LIB_ERR" ]; then
  IFS='|' read -r -a g_cols <<< "$STATUS_FOLDERS"
  g_all="$(kit_lived_signals "$CB_TREE" "$g_stamp" "${g_cols[@]}" 2>/dev/null || true)"
  g_rec="${g_all%%$'\n'*}"
  case "$g_rec" in
    stamp\|*)   g_lived="the initializer's stamp receipt in scripts/config.sh" ;;
    folder\|*)  g_f="${g_rec#folder|}"; g_lived="progress/${g_f%%|*}/ carries ${g_f##*|} issue file(s)" ;;
    log\|*)     g_lived="progress.md § Log holds ${g_rec#log|} line(s) of history" ;;
    archive\|*) g_lived="ARCHIVE.md indexes ${g_rec#archive|} archived line(s)" ;;
  esac
fi

if [ -n "$CB_LIVED_LIB_ERR" ]; then
  # A load failure is its own outcome, never the NOT-STARTED clearance below.
  echo "      THIS CHECK DID NOT RUN: $CB_LIVED_LIB_ERR — the already-lived probe this arm"
  echo "      shares with the initializer could not be loaded, so whether this repository has"
  echo "      STARTED was not measured. Nothing here is a statement that the tree is clean."
  echo "      Restore it:  git checkout -- scripts/lib/lived-probe.sh  (skipped)"
elif [ -z "$g_lived" ]; then
  # Not a pass, and worded so an unrun check cannot be read as a clean one.
  echo "      THIS CHECK DID NOT RUN: no sign this repository has started — no stamp receipt, no issue"
  echo "      files on the board, no history in progress.md § Log, nothing indexed in ARCHIVE.md."
  echo "      A fresh unpack is not nagged to finish. Nothing here is a statement that the tree is clean.  (skipped) — $(cb_src)"
else
  # Name the signal that enabled the check.
  echo "      (enabled by: $g_lived)"
  g_find=0
  # THE MEASURED POPULATION: incremented once per CLASS OR MEMBER this arm actually read (pass or
  # fail — an unread member counts as unmeasured, never as measured-and-clean). Printed before the
  # verdict, and the verdict REFUSES "COMPLETE" over zero: a report of nothing measured is not a
  # clean tree, and printing COMPLETE over it would be a false green.
  g_measured=0
  g_unmeasured=""
  g_skip=0

  # (g1) REPLACE class. The population is every tracked file whose HEADER BLOCK (first 12 lines)
  # declares `KIT-DISPOSITION: REPLACE` — process/EXTRACTION.md's derivation; a manual quoting the
  # marker further down is not a member. git grep reads the ref this report reads, or the tracked
  # files of the checkout. The test is the WHOLE shipped sentinel line, matched with `grep -qxF`:
  # a token match fires on prose that mentions it. A file whose marker and sentinel are both gone
  # has graduated. An empty population is reported, never passed.
  g_repl=""
  g_repl_pop=""
  g_decl='^[[:space:]]*(#|<!--|//|--)?[[:space:]]*KIT-DISPOSITION:[[:space:]]*REPLACE([^A-Za-z0-9_]|$)'
  while IFS= read -r -d '' f; do
    [ -n "$CB_REF" ] && f="${f#"$CB_REF":}"
    [ -f "$CB_TREE/$f" ] || continue
    sed -n '1,12p' "$CB_TREE/$f" | grep -E "$g_decl" >/dev/null || continue
    if cb_staged "$f"; then g_skip=$((g_skip+1)); continue; fi
    g_repl_pop="$g_repl_pop $f"
    grep -qxF '<!-- BOOTSTRAP-SCAFFOLDING — a tool reads this line. It goes when this file goes. -->' "$CB_TREE/$f" 2>/dev/null && g_repl="$g_repl $f"
  done < <(git -C "$REPO_ROOT" grep -lzE "$g_decl" ${CB_REF:+"$CB_REF"} -- 2>/dev/null || true)
  # Both branches name the test. The output never quotes the sentinel string (that would be one
  # more copy of it). The clearing line must NOT contain "still scaffolding": cases assert that
  # phrase only on the complaining branch.
  if [ -z "$g_repl_pop" ]; then
    # ZERO IS A READING, NOT A SKIP: the git grep above walked every tracked file (or the named
    # ref) looking for the declaration, and that walk completing with no match is the same
    # discharge REPLACE's own rule names — deletion and rewriting, which strips the marker along
    # with the sentinel (process/EXTRACTION.md § The marker and graduation). A tree that never
    # shipped a REPLACE-marked file would read identically; this arm cannot tell the two apart,
    # and says so rather than claiming more than the whole-tree scan supports.
    echo "      REPLACE: 0 file(s) in this tree declare KIT-DISPOSITION: REPLACE  ✓ (the whole tree was scanned — this is either graduated, with the marker stripped alongside the sentinel, or never shipped one; indistinguishable from here) — $(cb_src)"
    g_measured=$((g_measured+1))
  elif [ -n "$g_repl" ]; then
    echo "      REPLACE: still scaffolding —$g_repl  ⚠ replace (do not edit) with your own; matched as the exact whole shipped line, so this is the sentinel itself and not a prose mention; the adapter is built from process/templates/AGENTS-adapter.template.md — $(cb_src)"
    g_find=1; g_measured=$((g_measured+1))
  else
    echo "      REPLACE:$g_repl_pop carry no scaffolding sentinel  ✓ (population derived from KIT-DISPOSITION: REPLACE declarations, not a list typed into this script; exact whole-line match — a mention of the token in prose is not a hit) — $(cb_src)"
    g_measured=$((g_measured+1))
  fi

  # (g2) FILL class — unfilled <angle-bracket> blanks, in PROJECT.md ONLY: the other FILL members
  # write blanks in shell or ignore-file syntax (the span line below says so).
  # Read when PROJECT.md declares `KIT-DISPOSITION: FILL` or declares nothing (its marker is
  # stripped at graduation, and rewrites drop it); not when it declares another disposition.
  # Not a blank:
  #   • anything inside an HTML comment — the kit's instructions are not the adopter's answers.
  #     Comment SPANS are stripped, not lines, so a real blank beside an inline note still counts;
  #   • a code sample. A code span counts only when its WHOLE content is one <angle-bracket> (the
  #     shipped blank shape); a fenced block never counts. Do NOT strip code spans wholesale:
  #     most real blanks in the shipped sheet sit inside them.
  # Limits: an adopter's own lone `<input.csv>` span still counts; `<host>:<port>` in one span
  # does not; a span wrapped across lines is not seen as one.
  g_pm="$CB_TREE/PROJECT.md"
  g_fill_state=""
  if [ ! -f "$g_pm" ]; then
    g_fill_state="absent"
  elif grep -qE '^[[:space:]]*(#|<!--)?[[:space:]]*KIT-DISPOSITION:[[:space:]]*FILL\b' "$g_pm" 2>/dev/null; then
    g_fill_state="declared"
  elif grep -qE '^[[:space:]]*(#|<!--)?[[:space:]]*KIT-DISPOSITION:' "$g_pm" 2>/dev/null; then
    g_fill_state="other"
  else
    g_fill_state="undeclared"
  fi
  if [ "$g_fill_state" = "declared" ] || [ "$g_fill_state" = "undeclared" ]; then
    g_text="$(awk '
      # A span: a run of N backticks closed by the next run of EXACTLY N on the line.
      function run_at(s, n,   p, k, m) {
        p = 1
        while ((k = index(substr(s, p), "`")) > 0) {
          k = p + k - 1
          m = 0; while (substr(s, k + m, 1) == "`") m++
          if (m == n) return k
          p = k + m
        }
        return 0
      }
      # Keep a span only when its WHOLE content is one <angle-bracket> (the shipped blank).
      function spans(line,   out, rest, i, n, tick, after, j, c) {
        out = ""; rest = line
        while ((i = index(rest, "`")) > 0) {
          out = out substr(rest, 1, i - 1); rest = substr(rest, i)
          n = 0; while (substr(rest, n + 1, 1) == "`") n++
          tick = substr(rest, 1, n); after = substr(rest, n + 1)
          j = run_at(after, n)
          if (j == 0) { out = out tick; rest = after; continue }
          c = substr(after, 1, j - 1); rest = substr(after, j + n)
          gsub(/^[ \t]+/, "", c); gsub(/[ \t]+$/, "", c)
          if (c ~ /^<[a-z][^<>]*>$/) out = out " " c " "
          else out = out " "
        }
        return out rest
      }
      # FENCES ARE MATCHED BY SHAPE, NEVER TOGGLED. An opener: up to 3 spaces, then 3+ of one
      # char; a backtick opener whose info string holds a backtick is an inline span instead.
      # A closer: the SAME char, AT LEAST as long, nothing after it. Anything else inside is code.
      function fence_open(line,   t, info) {
        if (!match(line, /^ ? ? ?(```+|~~~+)/)) return 0
        t = substr(line, RSTART, RLENGTH); sub(/^ +/, "", t)
        info = substr(line, RSTART + RLENGTH)
        if (substr(t, 1, 1) == "`" && index(info, "`") > 0) return 0
        fch = substr(t, 1, 1); flen = length(t); return 1
      }
      function fence_close(line,   t) {
        if (!match(line, /^ ? ? ?(```+|~~~+)[ \t]*$/)) return 0
        t = line; sub(/^ +/, "", t); sub(/[ \t]+$/, "", t)
        return substr(t, 1, 1) == fch && length(t) >= flen
      }
      {
        line = $0
        while (match(line, /<!--.*-->/)) sub(/<!--.*-->/, "", line)
        if (inc) { if (match(line, /-->/)) { sub(/^.*-->/, "", line); inc = 0 } else next }
        if (match(line, /<!--/)) { sub(/<!--.*$/, "", line); inc = 1 }
        if (fence) { if (fence_close(line)) fence = 0; else held[++nh] = line; next }
        if (fence_open(line)) { fence = 1; nh = 0; next }
        print spans(line)
      }
      # A FENCE STILL OPEN AT END OF FILE HIDES NOTHING: its lines are read as prose, so a
      # blank after a broken fence still counts. The error runs toward a red, never a clean.
      END { if (fence) for (k = 1; k <= nh; k++) print spans(held[k])
      }' "$g_pm" 2>/dev/null)" && g_read=ok || g_read=""
    # An unread sheet is not a clean one: the count is taken only from a reading that completed.
    g_blanks="$(printf '%s\n' "$g_text" | grep -oE '<[a-z][^<>]*>' | grep -v '://' | wc -l | tr -d ' ')"
    if [ "$g_fill_state" = "undeclared" ]; then
      g_why="PROJECT.md carries no KIT-DISPOSITION declaration (graduated, or the line was dropped in a rewrite) and"
    else
      g_why="PROJECT.md"
    fi
    if [ -z "$g_read" ]; then
      echo "      FILL: NOT COUNTED — the blank reader failed on PROJECT.md, so nothing was counted, and that is not a pass  ⚠ — $(cb_src)"
      g_find=1
      g_unmeasured="${g_unmeasured:+$g_unmeasured, }PROJECT.md (blank reader failed)"
    elif [ "${g_blanks:-0}" -gt 0 ]; then
      echo "      FILL: ${g_why} still holds ${g_blanks} <angle-bracket> blank(s)  ⚠ a FILL file is not done until no blank remains — $(cb_src)"
      g_find=1; g_measured=$((g_measured+1))
    else
      echo "      FILL: ${g_why} holds 0 <angle-bracket> blanks  ✓ — $(cb_src)"
      g_measured=$((g_measured+1))
    fi
  elif [ "$g_fill_state" = "other" ]; then
    echo "      FILL: PROJECT.md declares a KIT-DISPOSITION other than FILL  (skipped — nothing was checked, which is not a pass) — $(cb_src)"
    g_unmeasured="${g_unmeasured:+$g_unmeasured, }PROJECT.md (declares another disposition)"
  else
    echo "      FILL: no PROJECT.md to read  (skipped) — $(cb_src)"
    g_unmeasured="${g_unmeasured:+$g_unmeasured, }PROJECT.md (absent)"
  fi
  echo "      (FILL span: PROJECT.md's own blanks are read by <angle-bracket> shape — HTML comments are stripped and code samples are not blanks: a code span counts only when its whole content is one <angle-bracket>, and fenced blocks never, so the kit's own instructions and the adopter's command usage are not the adopter's answers.)"

  # (g2b) FILL class, the NON-MARKDOWN MEMBERS (GRADUATION_FILL_MEMBERS): .gitignore's
  # build-artifact section and .env.example's project-credentials block declare the same
  # KIT-DISPOSITION: FILL, but write their instruction as a `FILL ME.` sentinel LINE rather than an
  # <angle-bracket> span (the span rule above cannot read shell/ignore-file comment syntax, and the
  # files' own optional settings legitimately keep <angle-bracket> examples that are NOT the
  # adopter's blank to fill — e.g. .env.example's NOTIFY_* lines). So each member is read by ITS
  # OWN shape instead: the section is unfilled exactly while its `FILL ME.` sentinel line is still
  # present (an adopter clears the section by deleting that instruction, the same convention
  # REPLACE's own sentinel uses). A member the sentinel does not find in this source is UNMEASURED,
  # never counted clean.
  while IFS='|' read -r gf_path gf_sentinel; do
    [ -n "$gf_path" ] || continue
    gf_file="$CB_TREE/$gf_path"
    if [ ! -f "$gf_file" ]; then
      echo "      FILL ($gf_path): not present in this source  (skipped — nothing was checked, which is not a pass) — $(cb_src)"
      g_unmeasured="${g_unmeasured:+$g_unmeasured, }$gf_path (absent)"
    elif grep -qF "$gf_sentinel" "$gf_file" 2>/dev/null; then
      echo "      FILL ($gf_path): still carries its '$gf_sentinel' instruction  ⚠ the section is not done until that line and the blank it introduces are replaced with this project's own — $(cb_src)"
      g_find=1; g_measured=$((g_measured+1))
    else
      echo "      FILL ($gf_path): no '$gf_sentinel' instruction remains  ✓ (read by its own sentinel-line shape, never the <angle-bracket> one — this member expresses its blank in comment/ignore-file syntax) — $(cb_src)"
      g_measured=$((g_measured+1))
    fi
  done <<< "$(printf '%s\n' "$GRADUATION_FILL_MEMBERS")"

  # (g2c) CODE_GLOBS / TEST_GLOBS, in scripts/config.sh — read by lib/glob-array.sh's kit_glob_array,
  # the reader the ablation check in scripts/lib/qa-gate.sh uses too (the one fixed shape:
  # `VAR=(` opens, `)` closes, each held line un-quoted and stripped of a trailing comment):
  # never a second, divergent reader of the same array. Both ship EMPTY ON PURPOSE —
  # config.sh's own comment says so — and empty means UNDECLARED to both consumers, which means
  # UNENFORCED, not "this project has no code/tests". That is exactly the gap this member closes:
  # nothing before this arm told the adopter the seam exists, so an empty array read as silence.
  #
  # DELIBERATELY EMPTY: an adopter who has decided (not merely not-yet-decided) that a seam stays
  # empty says so with a `# DECLARED EMPTY —` comment line inside that array's parens — the one
  # mechanical form, the same shape for both arrays, documented once beside them in config.sh. A
  # declaring line still reads config.sh's rule (empty means unenforced); it only stops THIS arm
  # from reporting the emptiness as an oversight.
  g_cfg="$CB_TREE/scripts/config.sh"
  if [ -n "$CB_GLOB_LIB_ERR" ]; then
    echo "      FILL (scripts/config.sh CODE_GLOBS): THIS CHECK DID NOT RUN — $CB_GLOB_LIB_ERR  (skipped — nothing was checked, which is not a pass) — $(cb_src)"
    echo "      FILL (scripts/config.sh TEST_GLOBS): THIS CHECK DID NOT RUN — $CB_GLOB_LIB_ERR  (skipped — nothing was checked, which is not a pass) — $(cb_src)"
    g_unmeasured="${g_unmeasured:+$g_unmeasured, }CODE_GLOBS ($CB_GLOB_LIB_ERR), TEST_GLOBS ($CB_GLOB_LIB_ERR)"
  elif [ ! -f "$g_cfg" ]; then
    echo "      FILL (scripts/config.sh CODE_GLOBS): not present in this source  (skipped — nothing was checked, which is not a pass) — $(cb_src)"
    echo "      FILL (scripts/config.sh TEST_GLOBS): not present in this source  (skipped — nothing was checked, which is not a pass) — $(cb_src)"
    g_unmeasured="${g_unmeasured:+$g_unmeasured, }CODE_GLOBS (scripts/config.sh absent), TEST_GLOBS (scripts/config.sh absent)"
  else
    for g_arr in CODE_GLOBS TEST_GLOBS; do
      g_arr_n=0
      g_arr_decl=0
      g_arr_entries=""
      # lib/glob-array.sh's kit_glob_array, the reader the ablation check uses too: an `E|` line per
      # real array entry and a `D` line if, and only if, a comment line inside the same parens is
      # the whole-line `# DECLARED EMPTY …` sentinel. The tag is the first character of the line so
      # the shell loop below can branch on it with a plain `case`.
      while IFS= read -r g_arr_tagged; do
        case "$g_arr_tagged" in
          E\|*) g_arr_n=$((g_arr_n+1)); g_arr_entries="${g_arr_entries}${g_arr_tagged#E|}"$'\n' ;;
          D) g_arr_decl=1 ;;
        esac
      done < <(kit_glob_array "$g_arr" "$g_cfg")
      if [ "$g_arr_n" -gt 0 ]; then
        # A TEST_GLOBS entry no file matches guards nothing: the ablation rule it feeds never
        # sees a test path. Matched with `case` against repository-relative paths, exactly as its
        # consumers do; the path list is the source's own (the ref's tree, else tracked files).
        g_arr_dead=""
        if [ "$g_arr" = "TEST_GLOBS" ]; then
          if [ -z "${g_paths+x}" ]; then
            if [ -n "$CB_REF" ]; then
              g_paths="$(git -C "$REPO_ROOT" ls-tree -r --name-only "$CB_REF" 2>/dev/null || true)"
            else
              g_paths="$(git -C "$REPO_ROOT" ls-files --cached --others --exclude-standard 2>/dev/null || true)"
            fi
          fi
          while IFS= read -r g_glob; do
            [ -n "$g_glob" ] || continue
            g_hit=0
            while IFS= read -r g_p; do
              # shellcheck disable=SC2254  # the entry is a declared glob, matched as one
              case "$g_p" in $g_glob) g_hit=1; break ;; esac
            done <<< "$g_paths"
            [ "$g_hit" -eq 1 ] || g_arr_dead="${g_arr_dead}${g_arr_dead:+, }$g_glob"
          done <<< "$g_arr_entries"
        fi
        if [ -n "$g_arr_dead" ]; then
          echo "      FILL (scripts/config.sh $g_arr): declares $g_arr_n entry/entries, and these match no file  ⚠ $g_arr_dead — a glob nothing matches enforces nothing; correct it, or add the first file it should match — $(cb_src)"
          g_measured=$((g_measured+1))   # reported, never a finding: a first day has no test file yet
        else
          echo "      FILL (scripts/config.sh $g_arr): declares $g_arr_n entry/entries  ✓ (read by the same anchored array parse scripts/githooks/pre-commit and scripts/lib/qa-gate.sh use) — $(cb_src)"
          g_measured=$((g_measured+1))
        fi
        # The kit's own self-test lives under scripts/test/, and globs match from the repository
        # root, so a bare `test/*` misses it. Reported, never a finding: the shape of the
        # declaration is read, whether the project wants that tree ablation-checked is its call.
        if [ "$g_arr" = "TEST_GLOBS" ]; then
          g_st_n=0; g_st_miss=0; g_st_first=""
          while IFS= read -r g_p; do
            case "$g_p" in scripts/test/*) ;; *) continue ;; esac
            g_st_n=$((g_st_n+1)); g_hit=0
            while IFS= read -r g_glob; do
              [ -n "$g_glob" ] || continue
              # shellcheck disable=SC2254  # the entry is a declared glob, matched as one
              case "$g_p" in $g_glob) g_hit=1; break ;; esac
            done <<< "$g_arr_entries"
            if [ "$g_hit" -eq 0 ]; then
              g_st_miss=$((g_st_miss+1)); [ -n "$g_st_first" ] || g_st_first="$g_p"
            fi
          done <<< "$g_paths"
          if [ "$g_st_n" -eq 0 ]; then
            echo "      FILL (TEST_GLOBS vs scripts/test/**): no file under scripts/test/ in this source  (nothing to cover) — $(cb_src)"
          elif [ "$g_st_miss" -gt 0 ]; then
            echo "      FILL (TEST_GLOBS vs scripts/test/**): $g_st_miss of $g_st_n file(s) under scripts/test/ are covered by no declared entry  ⚠ e.g. $g_st_first — the kit's own self-test is never ablation-checked; add \"scripts/test/*\" (globs match from the repository root) — $(cb_src)"
          else
            echo "      FILL (TEST_GLOBS vs scripts/test/**): all $g_st_n file(s) under scripts/test/ are covered by a declared entry  ✓ — $(cb_src)"
          fi
        fi
      elif [ "$g_arr_decl" -eq 1 ]; then
        echo "      FILL (scripts/config.sh $g_arr): empty, and declared DECLARED EMPTY  ✓ (an adopter's mechanical \"none, on purpose\" — the seam stays unenforced, on record rather than by omission) — $(cb_src)"
        g_measured=$((g_measured+1))
      else
        echo "      FILL (scripts/config.sh $g_arr): empty, and not declared deliberately empty  ⚠ SHIPPED EMPTY ON PURPOSE means UNDECLARED, which the consumer reads as UNENFORCED — fill it, or add a '# DECLARED EMPTY —' comment line inside its parens if that is this project's real answer — $(cb_src)"
        g_find=1; g_measured=$((g_measured+1))
      fi
    done
  fi

  # (g2d) `principal:`, in PROJECT.md — read the same way scripts/ask.sh reads it: the ONE
  # shared reader, lib/pm-field.sh's kit_pm_field (a backtick span after the marker if there is
  # one, else the rest of the line with Markdown emphasis stripped — a natural fill with no
  # backticks is not unfilled), and judged blank by that same file's kit_pm_blank — the ONE
  # blank test, so this arm and ask.sh can never disagree. `"nobody"` is PROJECT.md's own
  # documented mechanical "none, on purpose" for this field (§ Who answers when nobody is
  # watching) — filling it with that literal already reads as filled here, same as it does to
  # ask.sh, so no second declared-empty form is needed for this member.
  if [ ! -f "$g_pm" ]; then
    echo "      FILL (PROJECT.md principal:): not present in this source  (skipped — nothing was checked, which is not a pass) — $(cb_src)"
    g_unmeasured="${g_unmeasured:+$g_unmeasured, }principal: (PROJECT.md absent)"
  elif ! command -v kit_pm_field >/dev/null 2>&1 || ! command -v kit_pm_blank >/dev/null 2>&1; then
    echo "      FILL (PROJECT.md principal:): not measured — scripts/lib/pm-field.sh, the reader it shares with ask.sh, did not load  (skipped) — $(cb_src)"
    g_unmeasured="${g_unmeasured:+$g_unmeasured, }principal: (scripts/lib/pm-field.sh missing)"
  else
    g_principal="$(kit_pm_field '`principal:`' "$g_pm")"
    if kit_pm_blank "$g_principal"; then
      echo "      FILL (PROJECT.md principal:): missing or unfilled  ⚠ scripts/ask.sh refuses on this — § Who answers when nobody is watching's \`principal:\` line, filled with a name/role or the literal \"nobody\" — $(cb_src)"
      g_find=1; g_measured=$((g_measured+1))
    else
      echo "      FILL (PROJECT.md principal:): declared  ✓ (read the same way scripts/ask.sh reads it) — $(cb_src)"
      g_measured=$((g_measured+1))
    fi
  fi

  # (g3) DELETE-IF-UNUSED class. The population is every tracked file whose HEADER BLOCK (first
  # 12 lines) declares `KIT-DISPOSITION: DELETE-IF-UNUSED` — the SAME derivation g1 uses for
  # REPLACE, never a list typed into this script (process/EXTRACTION.md § The second axis names
  # the members; this reads their markers, not that table). A member discharges either way
  # EXTRACTION.md says it can: REMOVED (it is no longer a declaring file — indistinguishable from
  # "never shipped one", exactly as g1's zero-population reading above), or KEPT ON PURPOSE, which
  # is recorded as a real adopter decision in GRADUATION_LOCAL_PROCEDURES — the ONE mechanical
  # form process/SEED.md's step 8 states, matched EXACTLY (the declaring path inside backticks,
  # then the literal ` (DELETE-IF-UNUSED) kept, on purpose.`), never a basename grep or a mention
  # in free prose: a decision recorded under the wrong name is not findable by the next reader
  # either, which is the same failure this bullet exists to close.
  g_diu_decl='^[[:space:]]*(#|<!--|//|--)?[[:space:]]*KIT-DISPOSITION:[[:space:]]*DELETE-IF-UNUSED([^A-Za-z0-9_]|$)'
  g_diu_pop=""
  while IFS= read -r -d '' f; do
    [ -n "$CB_REF" ] && f="${f#"$CB_REF":}"
    [ -f "$CB_TREE/$f" ] || continue
    sed -n '1,12p' "$CB_TREE/$f" | grep -E "$g_diu_decl" >/dev/null || continue
    if cb_staged "$f"; then g_skip=$((g_skip+1)); continue; fi
    g_diu_pop="$g_diu_pop $f"
  done < <(git -C "$REPO_ROOT" grep -lzE "$g_diu_decl" ${CB_REF:+"$CB_REF"} -- 2>/dev/null || true)
  if [ -z "$g_diu_pop" ]; then
    # Same reading as g1's zero-population branch: the whole tree was scanned (every declaring
    # file would have matched), and none remains — removed on purpose or never shipped one,
    # which this arm cannot tell apart and does not claim to.
    echo "      DELETE-IF-UNUSED: 0 file(s) in this tree declare KIT-DISPOSITION: DELETE-IF-UNUSED  ✓ (the whole tree was scanned — each member is either removed on purpose or was never shipped here) — $(cb_src)"
    g_measured=$((g_measured+1))
  else
    g_diu_lp="$CB_TREE/$GRADUATION_LOCAL_PROCEDURES"
    g_diu_unfilled=""
    for f in $g_diu_pop; do
      g_diu_line="- **\`$f\` (DELETE-IF-UNUSED) kept, on purpose.**"
      if [ -f "$g_diu_lp" ] && grep -qF -- "$g_diu_line" "$g_diu_lp" 2>/dev/null; then
        g_measured=$((g_measured+1))
      else
        g_diu_unfilled="$g_diu_unfilled $f"
        g_find=1; g_measured=$((g_measured+1))
      fi
    done
    if [ -n "$g_diu_unfilled" ]; then
      echo "      DELETE-IF-UNUSED:$g_diu_unfilled  ⚠ no recorded decision in $GRADUATION_LOCAL_PROCEDURES — remove the member, or record keeping it with the exact line \`- **\`<path>\` (DELETE-IF-UNUSED) kept, on purpose.**\` (process/SEED.md step 8); a mention elsewhere, or by basename only, does not count — $(cb_src)"
    else
      echo "      DELETE-IF-UNUSED:$g_diu_pop carry a recorded kept-on-purpose decision in $GRADUATION_LOCAL_PROCEDURES  ✓ (population derived from KIT-DISPOSITION: DELETE-IF-UNUSED declarations, not a list typed into this script) — $(cb_src)"
    fi
  fi

  # THE POPULATION LINE, always printed, before either verdict below: what this pass measured and
  # what it could not. "0 measured" is itself a finding, not silence.
  echo "      measured: $g_measured member(s)/class(es)$( [ -n "$g_unmeasured" ] && printf '; could not measure: %s' "$g_unmeasured" )$( [ "$g_skip" -gt 0 ] && printf '; skipped %s staged file(s) in %s/' "$g_skip" "$CB_STAGE_DIR" )"
  # STILL CANNOT CATCH: a blank filled with plausible nonsense reads as measured-and-clean here,
  # the same as a blank filled with the adopter's real answer — no mechanism here reads MEANING.
  echo "      (still cannot catch: a blank filled with plausible nonsense — this arm reads SHAPE, not truth)"
  if [ "$g_measured" -eq 0 ]; then
    # REFUSING COMPLETE OVER ZERO. A tree that is "lived" enough to
    # enable this check but where every class above came back unmeasured (an absent PROJECT.md AND
    # absent .gitignore/.env.example FILL members, say) must not read as graduated — it read as
    # NOTHING WAS MEASURED, which is not the same claim.
    echo "      → CANNOT SAY graduation is complete: nothing above was measured ($g_unmeasured) — this is not a clean tree, it is an unmeasured one."
  elif [ -n "$g_unmeasured" ]; then
    # COMPLETE REQUIRES EVERY CLASS MEASURED, not merely "something was". REPLACE and
    # DELETE-IF-UNUSED read as measured even at zero population (the whole-tree scan above is the
    # measurement); what still lands here is a class this run could not read at all — PROJECT.md
    # absent, scripts/config.sh absent, and the like — and COMPLETE must not be claimed over a
    # class nobody read, whether or not anything else came back clean.
    echo "      → day one is not finished: ${g_unmeasured} could not be measured, so COMPLETE cannot be claimed over it — same refusal as the zero-measured case, scoped to the classes this run could not read at all."
  elif [ "$g_find" -eq 0 ]; then
    echo "      → graduation COMPLETE over the classes measured above; this arm has nothing further to ask."
    G_GRADUATION_COMPLETE=1
  else
    echo "      → day one is not finished. The checklist is process/SEED.md § Day one is done when."
  fi
fi

# ---------------------------------------------------------------------------
# (h) GENERATED-TRAILER scan of the same window as (e), sharing its epoch (one hook file, one
#     epoch) and ROLE_SCAN_N. commit-msg's rule (2) stops the next commit; this reads history
#     (contracts/commit-attribution.md § 4). The wording family and the markers are BOTH derived
#     from the hook through lib/attrib-trailer.sh's kit_attrib_offender — the same reader the hook
#     itself calls — so this arm reports exactly what the hook refuses, Unicode hyphens (U+2010
#     through U+2015, U+2212) folded first in both. The fallback is named. Scope: commit MESSAGES
#     only, not specs, Activity entries or review notes.
# ---------------------------------------------------------------------------
echo
h_src="derived from scripts/githooks/commit-msg, via lib/attrib-trailer.sh"
if ! command -v kit_attrib_offender >/dev/null 2>&1; then
  h_src="THE KIT'S FALLBACK SET — scripts/lib/attrib-trailer.sh did not load, so this is not your project's declared wording family"
elif [ -z "$(kit_attrib_trailer_words "$CB_TREE" 2>/dev/null)" ]; then
  h_src="THE KIT'S FALLBACK SET — commit-msg was not readable in this source, so this is not your project's declared wording family"
fi
echo "[h] generated-trailer scan (commits of $CB_RULE_REV since the rule began, commit MESSAGES only) — wordings $h_src:"
h_hits=0
h_scanned=0
if git -C "$REPO_ROOT" rev-parse --verify --quiet "$CB_RULE_REV" >/dev/null 2>&1; then
  # Every in-scope commit is COUNTED; only a message that could hold a trailer or a "generated/written"
  # line (a `by:` word or either verb, anywhere in it) is READ. The filter only narrows what the
  # anchored reader below sees: it never decides a hit.
  h_all="$(git -C "$REPO_ROOT" log --no-color --format='%H' "${CB_RULE_LOG_ARGS[@]}" 2>/dev/null || true)"
  h_cand="$(git -C "$REPO_ROOT" log --no-color --format='%H' -i -E --grep='by[[:space:]]*:|generated|written' "${CB_RULE_LOG_ARGS[@]}" 2>/dev/null || true)"
  if [ -n "$CB_RULE_EPOCH" ]; then
    h_all="$(printf '%s\n' "$h_all" | grep -xFf <(printf '%s\n' "$CB_RULE_INSCOPE") || true)"
    h_cand="$(printf '%s\n' "$h_cand" | grep -xFf <(printf '%s\n' "$CB_RULE_INSCOPE") || true)"
  fi
  h_scanned="$(printf '%s\n' "$h_all" | awk 'NF' | wc -l | tr -d ' ')"
  while IFS= read -r h_sha; do
    [ -z "$h_sha" ] && continue
    # The whole message: a trailer lives in the body. kit_attrib_offender is the reader the hook
    # calls, so "generated with" mid-sentence is prose, not a provenance line.
    h_body="$(git -C "$REPO_ROOT" log -1 --format=%B "$h_sha" 2>/dev/null || true)"
    h_bad=""
    if command -v kit_attrib_offender >/dev/null 2>&1; then
      h_bad="$(printf '%s\n' "$h_body" | kit_attrib_offender "$CB_TREE" 2>/dev/null || true)"
    fi
    if [ -n "$h_bad" ]; then
      echo "    ⚠ ${h_sha:0:9} carries a generated trailer: $(printf '%s' "$h_bad" | sed 's/^[[:space:]]*//')"
      h_hits=$((h_hits+1)); drift=1
    fi
  done <<< "$h_cand"
else
  echo "    – $CB_RULE_REV does not resolve — no history to scan  (skipped)"
  h_scanned=-1
fi
if [ "$h_scanned" -ge 0 ]; then
  cb_rule_scope_lines
fi
if [ "$h_scanned" -eq 0 ]; then
  echo "    – $CB_RULE_REV resolved but yielded no in-scope commit  (skipped)"
elif [ "$h_scanned" -gt 0 ] && [ "$h_hits" -eq 0 ]; then
  echo "    ✓ none of the $h_scanned in-scope commit message(s) carries a generated trailer"
fi

# ---------------------------------------------------------------------------
# (i) blocks: / blocked_by: SYMMETRY, in both directions; each asymmetric pair fires once and
#     names both cards (either may be the stray). Hand-maintained fields that
#     .claude/roles/orchestrator.md gates dispatch on. The check is lib/board-properties.sh's
#     kit_bp_blocks, the one implementation a landing also calls.
#     REPORTS ONLY here, because no mechanism writes or clears these fields: a deciding finding
#     would hold release.sh gate (d) shut on a hand-edit. The landing refuses a finding the
#     branch introduces, which is a different act on a different operand.
#     The header carries the literal `reports only` and the findings are indented
#     (contracts/drift-report.md § 4).
# ---------------------------------------------------------------------------
echo
echo "[i] blocks:/blocked_by: symmetry (every column in STATUS_FOLDERS; reports only — it never changes the verdict below; a landing refuses a finding it introduces) — $(cb_src):"
if cb_bp_loaded; then
  kit_bp_blocks "$CB_TREE"
  # NO `drift=1` HERE, DELIBERATELY, AND DO NOT ADD ONE. See the ruling above.
else
  cb_bp_missing
fi

# ---------------------------------------------------------------------------
# [j] DOWNTIME-QUEUE CLAIM DRIFT — a row still `open (claimed by <PREFIX>-NNN)` whose claiming
#     issue has reached a landed column, before a duplicate issue is minted for shipped work.
#     Reports only: a gate over a record defect pressures a leg into striking a row to get green.
#     The Status cell is CLASSIFIED, not grepped: take the LAST cell, strip emphasis, and let a
#     trailing `Status:` declaration win.
#     Cannot see: a row paid by an issue that never claimed it, or a row written for work that
#     had already landed.
# ---------------------------------------------------------------------------
DQ_FILE="${DQ_FILE:-dev/downtime-queue.md}"   # relative to the repository root
echo
echo "[j] downtime-queue claim drift ($DQ_FILE; reports only — it never changes the verdict) — $(cb_src):"
if [ ! -f "$CB_TREE/$DQ_FILE" ]; then
  # A READING WHOSE SUBJECT IS ABSENT STILL PRINTS, naming what was absent.
  echo "      – $DQ_FILE not present  (skipped — no queue to read)"
else
  j_out="$(
    awk -F'|' -v folders="$STATUS_FOLDERS" '
      /^\|/ {
        n = NF
        # Header, separator and the angle-bracket SHAPE row are not data.
        if ($0 ~ /^\|[[:space:]]*-+/) next
        if ($0 ~ /Wake condition/) next
        cell = $(n-1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", cell)
        if (cell ~ /^`?</) next
        # Strip markdown emphasis and backticks before classifying.
        gsub(/[*`_~]/, "", cell)
        # A trailing "Status:" declaration wins over the cell opening words.
        if (match(cell, /Status:[[:space:]]*/)) cell = substr(cell, RSTART + RLENGTH)
        if (cell !~ /^open/) next                 # struck or ruled dead: not our business
        if (match(cell, /[A-Z][A-Z0-9]*-[0-9]+/)) {
          print substr(cell, RSTART, RLENGTH)
        }
      }' "$CB_TREE/$DQ_FILE" | sort -u | while IFS= read -r id; do
        [ -n "$id" ] || continue
        # Landed columns only. An id in todo/in_progress/blocked is a LIVE claim.
        landed=""
        for col in done qa_complete; do
          if ls "$CB_TREE/progress/$col"/${id}-*.md >/dev/null 2>&1; then landed="$col"; fi
        done
        [ -n "$landed" ] || continue
        echo "      – $id claims an OPEN row, but its card is in progress/$landed/ — strike the row or say why it is still open"
      done
  )"
  if [ -z "$j_out" ]; then
    echo "      – no open row claims a landed issue ✓"
  else
    printf '%s\n' "$j_out"
  fi
  # NO `drift=1` HERE, DELIBERATELY. See the ruling in the header.
fi

# ---------------------------------------------------------------------------
# (k) declined/ depth — a COUNT only: no threshold, and it never sets `drift` (a decline is a
#      recorded refusal, not unfinished work). Not swept: the column's value is being browsable.
#      An absent column is skipped, not reported as 0.
#      Lettered [k], never [b2]: kit-init's self-check resets its advisory flag only on
#      `^\[[a-z]\]`, so a [b2] header would inherit [b]'s NON-advisory state and fail installs.
# ---------------------------------------------------------------------------
echo
if [ ! -d "$CB_TREE/progress/declined" ]; then
  echo "[k] declined/ depth (reports only — a decline is not drift and never changes the verdict below): progress/declined/ absent in this source  (skipped) — $(cb_src)"
else
  dc_count=0
  for f in "$CB_TREE"/progress/declined/*.md; do
    [ -e "$f" ] && dc_count=$((dc_count+1))
  done
  echo "[k] declined/ depth (reports only — a decline is not drift and never changes the verdict below): $dc_count card(s) — $(cb_src)"
fi


# ---------------------------------------------------------------------------
# (l) DECLARED REFERENCE INTEGRITY (contracts/drift-report.md § 2) — every register id cited
#     ANYWHERE IN THIS TREE, outside CITATION_EXCLUDE, resolves to a live entry, and no RETIRED id
#     is cited. It sets `drift`, so it carries NO `reports only` token. The check is
#     lib/board-properties.sh's kit_bp_citations (the marker itself is read through
#     lib/decision-register.sh's kit_decisions_cited); CITATION_EXCLUDE is this file's own operand.
# ---------------------------------------------------------------------------
echo
if ! cb_bp_loaded; then
  echo "[l] Declared reference integrity — every cited register id resolves: scripts/lib/board-properties.sh is missing or did not load — cannot resolve citations (skipped) — $(cb_src)"
elif [ -z "$(kit_bp_registers_present "$CB_TREE")" ]; then
  echo "[l] Declared reference integrity — every cited register id resolves: no register was read (none of the declared ones is present in this source) — nothing to resolve citations against (skipped) — $(cb_src)"
else
  echo "[l] Declared reference integrity — every cited register id resolves to a live entry, and no retired id is cited — $(cb_src):"
  KIT_BP_SKIP_DIR="$CB_STAGE_DIR"
  kit_bp_citations "$CB_TREE"
  [ "$KIT_BP_NHITS" -eq 0 ] || drift=1
fi

# BEGIN prd-coverage arm
# ---------------------------------------------------------------------------
# (m) PRD COVERAGE — a COUNT only: of the landed issues (qa_complete/ and done/, top level), how
#      many carry `prd: n/a`, and how many of those give no `prd_reason:`. It never sets `drift`:
#      `prd: n/a` is legal, and a gate would be satisfied by PRDs written to satisfy it.
#      To read the reasons:  grep -h '^prd_reason:' progress/qa_complete/*.md progress/done/*.md
#      An empty reason (the template's unfilled line, or a card minted before the field) counts
#      as none. A card that names no PRD at all (no `prd:` value, or `none`) AND gives no reason is
#      counted and named separately: it is neither a PRD-covered card nor a reasoned n/a, and
#      would otherwise leave the count unseen. The BEGIN/END markers let the self-test remove the
#      arm from a copy.
# ---------------------------------------------------------------------------
echo
m_total=0; m_na=0; m_noreason=0; m_cols=""; m_neither=0; m_neither_ids=""
m_read=""; command -v kit_card_field >/dev/null 2>&1 && m_read="qa_complete done"   # no reader loaded, no columns read
for col in $m_read; do
  [ -d "$CB_TREE/progress/$col" ] || continue
  m_cols="${m_cols}${m_cols:+ + }$col"
  for f in "$CB_TREE/progress/$col"/*.md; do
    [ -e "$f" ] || continue
    m_total=$((m_total+1))
    m_prd="$(kit_card_field "$f" prd)"
    m_why="$(kit_card_field "$f" prd_reason)"
    # A card naming no PRD (no value, or `none`) and giving no reason is in neither population
    # below — it is counted on its own so it cannot drop out of the denominator unseen.
    case "$m_prd" in
      ""|none|None|NONE)
        if [ -z "$m_why" ]; then
          m_neither=$((m_neither+1)); m_neither_ids="${m_neither_ids}${m_neither_ids:+ }$(basename "$f" .md)"
        fi
        continue ;;
    esac
    [ "$m_prd" = "n/a" ] || continue
    m_na=$((m_na+1))
    [ -n "$m_why" ] || m_noreason=$((m_noreason+1))
  done
done
if ! command -v kit_card_field >/dev/null 2>&1; then
  echo "[m] PRD coverage (reports only — a card without a PRD is legal and never changes the verdict below): THIS CHECK DID NOT RUN — scripts/lib/card-field.sh is missing or did not load  (skipped) — $(cb_src)"
elif [ -z "$m_cols" ]; then
  echo "[m] PRD coverage (reports only — a card without a PRD is legal and never changes the verdict below): no landed column in this source  (skipped) — $(cb_src)"
else
  echo "[m] PRD coverage (reports only — a card without a PRD is legal and never changes the verdict below): $m_na of $m_total landed issue(s) carry prd: n/a; $m_noreason of those give no prd_reason; $m_neither give neither a prd: nor a prd_reason: ($m_cols) — $(cb_src)"
  if [ "$m_neither" -gt 0 ]; then
    echo "      ⚠ $m_neither landed issue(s) name no PRD and give no reason: $m_neither_ids"
  fi
fi
# END prd-coverage arm

# BEGIN kit-feedback arm — `process/MANUAL.md` § Kit feedback
# ---------------------------------------------------------------------------
# (n) KIT-FEEDBACK LINE — under `kit-feedback: auto` (a missing setting reads as auto), whether the
#      NEWEST dated `## Log` entry ends with a `kit-feedback:` OR a `kit-finding:` line — a
#      dispatched leg's own entry correctly carries only the latter (MANUAL § Kit feedback, M1;
#      the orchestrator writes `kit-feedback:` at M4). Reported, never refused: the line records
#      that the questions were asked, not that the answers are true, so a gate would only teach
#      seats to write it. `manual` and `off` write no line, so there is nothing to check.
#      Removable: delete this block, BEGIN to END, with the rest of that section's lines.
# ---------------------------------------------------------------------------
echo
echo "[n] kit-feedback line (reports only — a missing line is reported, never refused, and never changes the verdict below) — $(cb_src):"
n_set=""
[ -f "$CB_TREE/PROJECT.md" ] && n_set="$(awk 'match($0, /^[[:space:]]*[-*][[:space:]]*`?kit-feedback:[[:space:]]*[A-Za-z]+/) {
    v = substr($0, RSTART, RLENGTH); sub(/.*kit-feedback:[[:space:]]*/, "", v); print v; exit }' "$CB_TREE/PROJECT.md" 2>/dev/null || true)"
case "$n_set" in
  manual|off)
    echo "      kit-feedback: $n_set — not checked (no capture moment fires, and no line is written, under $n_set)" ;;
  auto|"")
    [ -n "$n_set" ] || echo "      kit-feedback: none declared in PROJECT.md — read as auto"
    if [ ! -f "$CB_TREE/progress.md" ]; then
      echo "      no progress.md in this source  (skipped — nothing to check)"
    elif [ -z "${KIT_LOG_HEADING_ERE:-}" ]; then
      echo "      THIS CHECK DID NOT RUN — ${CB_LIVED_LIB_ERR:-scripts/lib/lived-probe.sh declares no KIT_LOG_HEADING_ERE}, and that file declares the '## Log' heading  (skipped)"
    else
      # The NEWEST dated entry: the last `### YYYY-MM-DD` block under `## Log` (entries are appended).
      n_entry="$(awk -v re="$KIT_LOG_HEADING_ERE" '
          $0 ~ re { inlog = 1; next }
          inlog && /^##[[:space:]]/ && !/^###/ { inlog = 0 }
          inlog && /^###[[:space:]]+[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/ { buf = ""; have = 1 }
          inlog && have { buf = buf $0 "\n" }
          END { printf "%s", buf }' "$CB_TREE/progress.md" 2>/dev/null || true)"
      if [ -z "$n_entry" ]; then
        echo "      no session entry yet — nothing to check"
      else
        n_head="$(printf '%s\n' "$n_entry" | sed -n '1s/^###[[:space:]]*//p')"
        # A DISPATCHED LEG'S OWN ENTRY correctly carries `kit-finding:`, never `kit-feedback:`
        # (MANUAL § Kit feedback, M1: "A dispatched leg writes no entry. It puts one
        # `kit-finding: …` line…"; the ORCHESTRATOR writes `kit-feedback:` at M4). Either line
        # shape on the newest entry answers this check — a leg's `kit-finding:`-only entry is not
        # a missing line, it is the documented shape for that seat.
        n_line="$(printf '%s\n' "$n_entry" | grep -E '^[[:space:]]*([-*][[:space:]]+)?`?(kit-feedback|kit-finding):' | tail -n 1 || true)"
        if [ -n "$n_line" ]; then
          n_line="$(printf '%s' "$n_line" | sed -E 's/^[[:space:]]*([-*][[:space:]]+)?`?//; s/`[[:space:]]*$//')"
          echo "      newest entry ($n_head): $n_line"
        else
          echo "      ⚠ the newest session entry ($n_head) has no kit-feedback: (or, from a dispatched leg, kit-finding:) line — the session-close questions (MANUAL § Kit feedback, M2) end with one"
        fi
      fi
    fi ;;
  *)
    echo "      ⚠ kit-feedback: '$n_set' in PROJECT.md is not auto, manual or off — not checked" ;;
esac
# END kit-feedback arm

# BEGIN kit-upgrade arm — `process/KIT-RELEASE-NOTES.md` § How to upgrade an adopted project
# ---------------------------------------------------------------------------
# (o) KIT UPGRADE — the tree's process/KIT-VERSION and its form, and, while the upgrade checklist
#      exists, how many of its items are unmarked. Reported, never refused: deferring an upgrade
#      while a leg is in flight is legal, and the checklist is the deferral's record. Its path is
#      read from scripts/kit-upgrade.sh, which writes it. With none on the trunk it says an absent
#      checklist is not an absent duty, and that it reads the trunk, so an upgrade not yet landed is
#      unseen here ([f1] lists it).
#      Removable: delete this block, BEGIN to END, with the rest of that section's lines.
# ---------------------------------------------------------------------------
echo
echo "[o] kit upgrade (reports only; never changes the verdict below) — $(cb_src):"
o_v="$(sed -n '1{s/[[:space:]]*$//;p;}' "$CB_TREE/process/KIT-VERSION" 2>/dev/null || true)"
if [ -z "$o_v" ]; then
  echo "      process/KIT-VERSION absent in this source  (skipped)"
elif [[ "$o_v" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9a-f]+$ ]]; then
  echo "      KIT-VERSION: $o_v — a build between releases, after ${o_v%%+*} (process/KIT-RELEASE-NOTES.md § How versions work)"
elif [[ "$o_v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "      KIT-VERSION: $o_v — a release"
else
  echo "      ⚠ KIT-VERSION: '$o_v' is neither X.Y.Z nor X.Y.Z+<tree> (process/KIT-RELEASE-NOTES.md § How versions work)"
fi
o_cl="$(sed -n "/^UPGRADE_CHECKLIST='[^']*'\$/{s/^UPGRADE_CHECKLIST='\([^']*\)'\$/\1/p;q;}" "$REPO_ROOT/scripts/kit-upgrade.sh" 2>/dev/null || true)"
if [ -z "$o_cl" ]; then
  echo "      THE CHECKLIST PART DID NOT RUN — scripts/kit-upgrade.sh is absent or declares no UPGRADE_CHECKLIST, and that line names the checklist  (skipped)"
elif [ ! -f "$CB_TREE/$o_cl" ]; then
  echo "      $o_cl: none on the trunk — no checklist does not mean no duty: a release you hold that is newer than KIT-VERSION is applied now (process/contracts/kit-upgrade.md § 2). An upgrade staged or committed locally is not seen here; [f1] lists it."
else
  o_t="$(sed -n '/^target:/{s/^target:[[:space:]]*//;p;q;}' "$CB_TREE/$o_cl" 2>/dev/null || true)"
  o_open="$(grep -c '^- \[ \]' "$CB_TREE/$o_cl" 2>/dev/null || true)"
  o_done="$(grep -c '^- \[[xX]\]' "$CB_TREE/$o_cl" 2>/dev/null || true)"
  o_all=$(( ${o_open:-0} + ${o_done:-0} ))
  if [ "${o_open:-0}" -gt 0 ]; then
    echo "      ⚠ $o_cl: the upgrade to ${o_t:-<no target line>} is open — ${o_open} of $o_all item(s) unmarked; do each and mark it \`- [x]\`, then ./scripts/kit-upgrade.sh --finish --into ."
  else
    echo "      $o_cl: the upgrade to ${o_t:-<no target line>} has every item marked ($o_all) — finish it: ./scripts/kit-upgrade.sh --finish --into ."
  fi
fi
# END kit-upgrade arm

# ---------------------------------------------------------------------------
# (p) CORPUS FORWARD-REFERENCE INTEGRITY — requirements/CORPUS.md's manifest `Status` column.
#     It DECIDES the verdict, on the same footing as [l]: each finding is single-ended (the
#     marker or the row is wrong, no second party). The check is lib/board-properties.sh's
#     kit_bp_corpus, the one implementation a landing also calls; it names its three findings.
#     "Day one has closed" is NOT re-derived: it is arm [g]'s own G_GRADUATION_COMPLETE, set only
#     in [g]'s COMPLETE branch, passed in so this arm and [g] can never disagree.
# ---------------------------------------------------------------------------
CORPUS_FILE="${CORPUS_FILE:-requirements/CORPUS.md}"   # relative to the repository root
echo
echo "[p] CORPUS forward-reference integrity ($CORPUS_FILE) — $(cb_src):"
if cb_bp_loaded; then
  kit_bp_corpus "$CB_TREE" "$G_GRADUATION_COMPLETE"
  [ "$KIT_BP_NHITS" -eq 0 ] || drift=1
else
  cb_bp_missing
fi
# END corpus forward-reference arm

# ---------------------------------------------------------------------------
# (q) DECLARED-REGISTER ENTRY SHAPE (requirements/DECISIONS.md's own rule, "Every entry is exactly
#     three things"): a SHAPE lint, not an amendment-count threshold. The check is
#     lib/board-properties.sh's kit_bp_register_shape, the one implementation a landing also
#     calls. Reports only here — it never changes the verdict below, the same footing as
#     [k]/[m]/[n]/[o]: a judgement about wording, and a project may have a good reason for a shape
#     this arm has not seen. A landing that changes a register refuses a SHAPE finding it
#     introduces. The two readings that need history or judgement — a Ruling changed with no stamp,
#     a Findings list that collided — are named here, over the same window as [e], and are never
#     refused at a landing: a changed ruling is not a defect until a reader says the change was
#     substantive, and nothing keys such a finding to a line a branch introduced.
# ---------------------------------------------------------------------------
echo
echo "[q] Declared-register entry shape — every D-NN entry is exactly three fields, a reopened entry is stamped, and a changed Ruling carries a stamp (reports only — it never changes the verdict below; a landing refuses a shape finding it introduces) — $(cb_src):"
if cb_bp_loaded; then
  KIT_BP_HIST_REPO="$REPO_ROOT"
  if [ -n "$CB_RULE_EPOCH" ]; then KIT_BP_HIST_RANGE="$CB_RULE_EPOCH..$CB_RULE_REV"; else KIT_BP_HIST_RANGE="$CB_RULE_REV"; fi
  kit_bp_register_shape "$CB_TREE"
  KIT_BP_HIST_REPO=""; KIT_BP_HIST_RANGE=""
else
  cb_bp_missing
fi
# END register-shape arm

# ---------------------------------------------------------------------------
# (r) DECLARED REVERSE COVERAGE — arm (l) walks FROM a citing surface TO the register; this walks
#     the other way: a LIVE register entry that CONSTRAINS a PRD but that PRD never cites
#     (`pm.md`'s fork/fact rule). Keyed as "cited BY THE PRD it constrains", not "cited anywhere".
#     An entry marked CROSS_CUTTING_MARKER (`[cross-cutting]`, at the head of its Ruling field) is
#     exempt. The check is lib/board-properties.sh's kit_bp_reverse_coverage, the one
#     implementation a landing also calls.
#     REPORT ONLY here, like (k)/(m)/(n)/(o)/(q): this arm cannot tell "not this PRD's domain"
#     from "missed" for an entry that is neither cited nor marked exempt, so it never sets
#     `drift`. A landing that changes `requirements/` refuses an entry it newly leaves uncited.
# ---------------------------------------------------------------------------
echo
echo "[r] Declared reverse coverage — every live register entry a PRD constrains is cited BY THAT PRD, or declared \`[cross-cutting]\` (reports only — a judgement call this arm cannot make generically, and it never changes the verdict below; a landing refuses a finding it introduces) — $(cb_src):"
if cb_bp_loaded; then
  kit_bp_reverse_coverage "$CB_TREE"
else
  cb_bp_missing
fi
# END reverse-coverage arm

# ---------------------------------------------------------------------------
# (s) MODEL PINS VS THE LADDER — each leaf-worker pin's model and effort against its class's
#     ladder cell, or, where that cell is unfilled, against scripts/set-models.sh's record of what
#     it last wrote (.claude/model-pins.record). The check is lib/model-pins.sh's kit_model_drift.
#     Reports only, like [k]/[m]/[n]/[o]/[q]/[r]: a project may pin a class apart from its ladder
#     row on purpose. Cannot see: a model set by a launch flag or a session toggle, which no file
#     shows; or a hand edit on a tree where the ladder is unfilled and set-models.sh never ran.
# ---------------------------------------------------------------------------
echo
echo "[s] Model pins vs the ladder — each worker pin against its ladder cell, or set-models.sh's record where the cell is unfilled (reports only — a pin set apart on purpose is legal, and it never changes the verdict below) — $(cb_src):"
if ! command -v kit_model_drift >/dev/null 2>&1; then
  echo "      – scripts/lib/model-pins.sh is missing or did not load — this arm did not run  (skipped)"
elif ! kit_model_drift "$CB_TREE"; then
  echo "      – no .claude/ with roles/orchestrator.md in this source  (skipped)"
fi
# END model-pins arm

# ---------------------------------------------------------------------------
# (t) ANSWERED QUESTIONS NOT RECONCILED — a question file in the channel PROJECT.md declares
#     (lib/pm-field.sh's kit_pm_channel_token, the reader scripts/ask.sh writes through) that carries
#     an `**Answer` block and whose path appears in NO register file (the REGISTERS records above).
#     The operand is that one fact: the path is cited, or it is not. Each finding names the card the
#     question parks (its `**Parks card:**` line), else says none is named. Reports only, like
#     [k]/[m]/[n]/[o]/[q]/[r]/[s]: the owner is the Orchestrator's PM-hat leg, not this report. A
#     channel that is one file holds several questions and no answer can be tied to one of them: the
#     arm says so and lists nothing. Findings are single `⚠` lines so they survive the session-start
#     hook's byte budget.
#     Removable: delete this block, BEGIN to END.
# ---------------------------------------------------------------------------
echo
echo "[t] Answered, not reconciled (reports only; never changes the verdict below) — $(cb_src):"
t_pm="$CB_TREE/PROJECT.md"
t_line=""; t_tok=""; t_dir=""; t_skip=""
if ! command -v kit_pm_field >/dev/null 2>&1 || ! command -v kit_pm_channel_token >/dev/null 2>&1; then
  t_skip="scripts/lib/pm-field.sh, the reader it shares with ask.sh, did not load"
elif [ ! -f "$t_pm" ]; then
  t_skip="no PROJECT.md in this source, so no channel is declared"
else
  t_line="$(kit_pm_field '\\*\\*Their channel:\\*\\*' "$t_pm")"
  if kit_pm_blank "$t_line"; then
    t_skip="PROJECT.md declares no channel"
  else
    t_tok="$(kit_pm_channel_token "$t_line")"
    case "$t_tok" in
      /*|..|../*|*/../*|*/..) t_skip="the declared channel ($t_tok) is not a path inside the repository" ;;
      */) t_dir="${t_tok%/}" ;;
      *)  if [ -d "$CB_TREE/$t_tok" ]; then t_dir="$t_tok"
          else t_skip="the channel ($t_tok) is one file: it holds several questions, so no answer in it can be tied to one"; fi ;;
    esac
  fi
fi
if [ -n "$t_skip" ]; then
  echo "      – $t_skip  (skipped)"
else
  t_regs=""; t_reg_names=""
  while IFS='|' read -r t_rpath _t_mark _t_shape; do
    [ -n "$t_rpath" ] || continue
    t_reg_names="${t_reg_names:+$t_reg_names, }$t_rpath"
    [ -f "$CB_TREE/$t_rpath" ] && t_regs="${t_regs:+$t_regs$'\n'}$t_rpath"
  done <<T_REGS
$REGISTERS
T_REGS
  t_read=0; t_found=0
  for t_f in "$CB_TREE/$t_dir"/*-ask.md; do
    [ -f "$t_f" ] || continue
    t_read=$((t_read + 1))
    grep -qE '^\*\*Answer' "$t_f" 2>/dev/null || continue
    t_rel="$t_dir/${t_f##*/}"
    t_cited=0
    while IFS= read -r t_rpath; do
      [ -n "$t_rpath" ] || continue
      if grep -qF -- "$t_rel" "$CB_TREE/$t_rpath" 2>/dev/null; then t_cited=1; break; fi
    done <<T_CITES
$t_regs
T_CITES
    [ "$t_cited" -eq 0 ] || continue
    t_card="$(awk '/^\*\*Parks card:\*\*/ { sub(/^\*\*Parks card:\*\*[ \t]*/, ""); sub(/[ \t]+$/, ""); print; exit }' "$t_f" 2>/dev/null || true)"
    echo "      ⚠ $t_rel — card: ${t_card:-no card named} — answered, ${t_reg_names} does not cite it"
    t_found=$((t_found + 1))
  done
  if [ "$t_found" -gt 0 ]; then
    echo "      The Orchestrator dispatches the PM-hat leg for each (.claude/roles/orchestrator.md § An answered question is ready work)."
  else
    echo "      ✓ none: $t_read question file(s) read in $t_dir/"
  fi
fi
# END answered-question arm

echo
if [ "$drift" -eq 0 ]; then
  echo "── board-drift: clean ✓"
else
  echo "── board-drift: findings above ⚠ (informational; exit 0 by convention)"
fi
exit 0
