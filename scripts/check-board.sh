#!/usr/bin/env bash
# KIT-CLASS: KIT — board drift report, plus one day-one completeness arm; reads the status folders,
#   the log, recent history, the publication homes and the root scaffolding, each FROM A NAMED
#   SOURCE it prints. See process/EXTRACTION.md.
# Board-drift check.
#
# A read-only (<2s) reporter for the mechanical parts of the manual's § "Session
# close ritual" that would otherwise be self-attested with zero verification. It
# reports these drift classes:
#   (a) any ACTIVE-board issue file whose folder contradicts its last Activity entry
#       (the folder is authoritative — a mismatch means the Activity log wasn't kept in sync);
#   (b) progress/qa_complete/ column depth vs the archive.sh sweep threshold;
#   (c) progress.md § Log BYTE SIZE vs the archive-progress.sh rotation threshold
#       (byte-based, not line-based — a handful of single-line mega-entries hid real token
#       weight behind a small line count, so a 44 KB § Log read "healthy" under an older
#       80-line rule), PLUS a second, ADVISORY-ONLY arm reporting the WHOLE FILE's byte
#       size against its own separate threshold — the § Log arm alone can read "healthy"
#       while the file's dominant content sits past its exit, which was a real census's
#       headline finding;
#   (d) FRONTMATTER ID INTEGRITY across all six columns — a DUPLICATE `id:` (two issue
#       files carrying the same id), an id that DISAGREES with its filename's prefix,
#       and a missing/malformed id. EMPIRICAL, not speculative: two issues carried the
#       same `id:` on the trunk at once (a Dev-filed bug and a PM-minted spike, landed
#       minutes apart from separate worktrees). Their slugs differed so git raised
#       nothing, and none of the other checks read frontmatter `id:` — so this reporter
#       said `board-drift: clean ✓` with a duplicate id on the board. It was caught by a
#       manual grep and unwound by renumbering the later mint. next-id.sh is NOT at
#       fault (it is stateless by design and already scans progress/** AND ARCHIVE.md);
#       the gap was that nothing verified the invariant AFTER allocation. This is that
#       verifier. It REPORTS, it never repairs — auto-renumbering would have to fix the
#       filename, the branch, the Activity trail and every cross-reference;
#   (e) [Role]-prefix scan of recent trunk commits;
#   (f) UNPUBLISHED WORK IN EITHER HOME THE PROCESS WRITES TO — the main checkout's
#       trunk ref [f1] and the board mover's .kanban-wt [f2], each named separately.
#       [f1] exists because everything the kit classifies as METADATA commits direct
#       to the trunk from the main checkout — rulings, PRDs, issue edits, role docs,
#       process/**, progress.md, the adapter — so the home carrying the process's own
#       memory was the one home nothing watched, and the board could read `clean ✓`
#       with a day of unpushed rulings beside it;
#   (g) GRADUATION — has day one finished: the REPLACE-class root documents still
#       carrying their scaffolding sentinel, and PROJECT.md still holding <angle-bracket>
#       blanks. NOT board drift, and deliberately NOT wired into the verdict line — a
#       repository one minute after kit-init has not graduated and its board is
#       nonetheless truthful. It reports, it never sets `drift`, and it never goes
#       silent once satisfied; the arm's own header gives all three reasons.
#
# ─────────────────────────────────────────────────────────────────────────────
# EVERY CHECK NAMES THE SOURCE IT READ, AND SAYS SO WHEN IT COULD NOT READ ONE.
#
# The defect this closes, measured: arms (a)–(e) resolved their paths through the
# CURRENT CHECKOUT. A dispatched leg legitimately switches that checkout to its own
# branch, so every one of them returned a STALE answer that looked authoritative —
# nothing in the output named the operand, so nobody chose it and nobody could see
# it had changed. Measured instances: a board report certifying a column state two
# commits old; a log-size arm frozen at an identical byte count across four
# consecutive boundaries; and an id-uniqueness arm reporting "N distinct ids ✓"
# while the trunk held N+1.
#
# ARM (d) IS THE WORST CASE AND THE REASON THIS IS S1, NOT COSMETIC. It is a
# UNIQUENESS check. Two concurrent mints collide only when BOTH land on the trunk;
# a branch, by construction, contains at most one of them. So read from a branch it
# is not a degraded check — it is structurally incapable of seeing the collision it
# exists for, and it says `✓` while being so.
#
# The rule, and it is one rule covering two failures that look different:
#   A CHECK STATES THE OPERAND IT READ AND WHETHER THE READ SUCCEEDED.
# A verdict with neither is not a verdict. Absent input then cannot read as a pass
# (there is no operand to name), and a trunk property cannot be answered from a
# branch (the named operand would be wrong). One obligation, both closed.
#
# So: every arm whose subject is a TRUNK property reads <remote>/<trunk> by name and
# prints it. Arm (f)'s subject is genuinely LOCAL — "is either home this process
# writes to holding work that never reached the trunk" — so it inspects local refs
# and working trees ON PURPOSE and names each one it inspected. Naming the operand is
# the invariant; reading the trunk is only what most of the arms happen to need.
#
# NO FETCH, DELIBERATELY. This is a <2s read-only reporter, `timeout(1)` is not
# portable, and a hang at session start is worse than a dated answer. It reads
# refs/remotes/<remote>/<trunk> as it stands and LABELS IT WITH ITS SHA — a dated
# reading, in the sense of `doctrine/fix-execution.md` § A.7 — and prints how to
# refresh. In normal use every board op's own sync has just fetched that ref.
# ─────────────────────────────────────────────────────────────────────────────
#
# Two callers:
#   • the SessionStart hook (scripts/hooks/session-start.sh) runs it so the NEXT
#     session opens with last session's misses in context;
#   • a human runs it directly as the close-ritual verifier.
#
# CONVENTION: exit 0 ALWAYS (informational). It never blocks a session or a commit;
# drift is surfaced in the output, not the exit code. Read-only: it inspects files
# and `git status`; it never mutates.
set -uo pipefail

# ── ARGUMENT SHAPE ──────────────────────────────────────────────────────────
# Per process/contracts/issue-creation.md § 3, whose CLI shape binds every command-line
# tool the kit ships and not only the creators. This script takes no options and PARSED
# none, so an unrecognised option was silently ignored and the run exited 0 — a REFUSAL
# THAT READS AS SUCCESS, which is the precise failure that section exists to prevent: a
# caller scripting against the set could not tell a typo'd flag from a clean board.
#
# THE INFORMATIONAL EXIT-0 VERDICT BELOW IS UNTOUCHED. That convention is about what the
# report FOUND; this is about whether the invocation was even legal. They are different
# questions, and this guard answers its one before any inspection begins — so no drift
# reading can reach a run that was mis-invoked.
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      # A usage request is always legal and always succeeds — § 3 again.
      echo "Usage: $(basename "$0")"
      echo ""
      echo "Reports board drift: folder-vs-activity, frontmatter ids, role prefixes,"
      echo "unpublished work, and whether day one has finished."
      echo ""
      echo "Takes no options. Informational by convention: it exits 0 whatever it finds,"
      echo "because drift belongs in the output and not in the exit status. Read-only —"
      echo "it inspects files and 'git status', and never mutates."
      exit 0 ;;
    *)
      echo "Error: unknown option: $1" >&2
      echo "  $(basename "$0") takes no options; run it with no arguments." >&2
      exit 2 ;;
  esac
done

# ── Greppable defaults (hard-won: consumers and tests DERIVE these from here with
#    sed, they do not re-hardcode literals — so a future change here cannot
#    silently make an assertion vacuous).
STATUS_FOLDERS='todo|in_progress|dev_complete|qa_complete|blocked|done'
QA_COMPLETE_THRESHOLD=10
# The § Log rotation trigger is BYTE-based, not line-based. A handful of single-line
# mega-entries (averaging ~740 chars) hid real token weight behind a small line count, so a
# 44 KB § Log read "healthy" under a retired 80-line rule. 32 KiB ≈ ~8k tokens of every session's
# start budget — calibrated so a closed-round-heavy § Log trips BEFORE it dominates context, while
# a freshly-rotated one (post-cutoff entries only) reads healthy. Rotate with archive-progress.sh.
PROGRESS_LOG_BYTE_THRESHOLD=32768
# The § Log arm above answers "is the slice every session reads at start getting
# heavy?" — it does NOT answer "is the WHOLE file still a thing anyone could read
# end to end?", because its awk exits at the first "## " heading after "## Log".
# That gap was measured once as: the § Log arm reporting "healthy" at 18,330 bytes
# while 1,141,929 bytes — 98.3% of the file — sat past its exit, invisible. The
# WHOLE-FILE arm below is ADDITIVE, not a replacement: the byte-based reasoning is
# correct and unchanged; only its SPAN was wrong. Its threshold is a SEPARATE,
# greppable constant — reusing the § Log number here would make the whole-file arm
# red-forever (the file will always dwarf the session-start slice's budget) and
# therefore ignored, which is exactly what the derive-from-here contract above
# exists to prevent. 10x the § Log threshold (≈80k tokens) is DERIVED from the
# already-calibrated number rather than picked from any one repo's current size.
# ADVISORY ONLY, like the § Log arm: it reports, it never sets `drift` — every issue
# in flight reads this script, and a newly-failing board report would halt every run.
PROGRESS_WHOLE_FILE_BYTE_THRESHOLD=327680
ROLE_SCAN_N=20        # how many recent trunk commits the HISTORY ARMS scan — (e) and (h) share it: one idea, one number
# Check (d)'s two constants: the frontmatter key that carries an issue's identity, and
# the id SHAPE (a PATTERN, not the configured prefix, so a future prefix change is not
# a scatter of literals here — and so a board mid-rename still parses).
ISSUE_ID_KEY='id'
ISSUE_ID_PATTERN='[A-Za-z]+-[0-9]+'
# Check (d)'s SECOND identifier space. The board is one space; a REGISTER is another,
# and `contracts/drift-report.md` invariant 4 covers "every identifier space the
# process maintains", enumerated, each named — the same widening invariant 6 took.
# One record per register:  <path>|<heading mark>|<id shape>
# The path is repo-relative; an absent register SKIPS with its reason (never a silent
# pass). Add a record per register you keep; the shipped one is the decision register.
REGISTERS='requirements/DECISIONS.md|### |D-[0-9]+'
# How far into a file check (d) will look for the frontmatter's OPENING `---`.
# It is not always line 1: the kit's own templates open with an HTML comment
# explaining what the initializer stamps, and a card minted from one carries that
# comment above its frontmatter. A parser that DEMANDS `---` on line 1 reports
# every such card as having no id at all — measured on the very first minted card
# of a fresh install, which is how this constant came to exist. The cap keeps the
# parse anchored: a `---` further down a long body is a horizontal rule, not a
# frontmatter fence, and must not be mistaken for one.
FRONTMATTER_SCAN_LINES=25

# Repo root: harness CLAUDE_PROJECT_DIR, else this script's location (scripts/..).
REPO_ROOT="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." 2>/dev/null && pwd || true)"
fi

# THE SHARED ALREADY-LIVED PROBE, resolved from THIS SCRIPT'S LOCATION and deliberately
# NOT from REPO_ROOT: the line above lets CLAUDE_PROJECT_DIR name a different tree, and
# the library is code that ships beside this script, not content of the tree being read.
#
# NO exit AND NO return, ever, on this path. This script's convention is exit 0 ALWAYS,
# and contracts/drift-report.md requires that a reading whose subject is ABSENT still
# PRINTS, naming what was absent. A load failure is therefore a recorded skip, not a
# raise — and CB_LIVED_LIB_ERR is initialised on EVERY path because `set -u` is on.
CB_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)/lib"
CB_LIVED_LIB_ERR=""
# shellcheck source=lib/lived-probe.sh
if [ ! -f "$CB_LIB_DIR/lived-probe.sh" ] || ! . "$CB_LIB_DIR/lived-probe.sh"; then
  CB_LIVED_LIB_ERR="scripts/lib/lived-probe.sh is missing or could not be sourced"
elif ! command -v kit_lived_signals >/dev/null 2>&1; then
  CB_LIVED_LIB_ERR="scripts/lib/lived-probe.sh sourced, but kit_lived_signals is NOT DEFINED"
fi

# ── THE SOURCE EVERY TRUNK-PROPERTY ARM ANSWERS ABOUT ────────────────────────
# The remote and the trunk are resolved the SAME WAY kwt_resolve does, and the last
# link of the chain is READ FROM THAT LIBRARY rather than re-typed — a re-typed
# branch name is the drift this file's greppable-defaults contract exists to
# prevent. (Arm (f) already did it this way; this hoists it to the whole script.)
CB_REMOTE="${KWT_REMOTE:-origin}"
CB_TRUNK="$(git -C "$REPO_ROOT" symbolic-ref --short "refs/remotes/$CB_REMOTE/HEAD" 2>/dev/null | sed "s|^$CB_REMOTE/||" || true)"
[ -n "$CB_TRUNK" ] || CB_TRUNK="$(git -C "$REPO_ROOT" config --get init.defaultBranch 2>/dev/null || true)"
if [ -z "$CB_TRUNK" ]; then
  CB_TRUNK="$(sed -n 's/^KWT_TRUNK_LAST_RESORT="\${KWT_TRUNK_LAST_RESORT:-\([A-Za-z0-9._\/-]*\)}"/\1/p' \
                "$REPO_ROOT/scripts/lib/kanban-worktree.sh" 2>/dev/null | head -1)"
fi

# CB_SRC_KIND is `ref` or `worktree`; CB_SRC_LABEL is what every arm prints.
#
# THE WORKING-TREE FALLBACK IS LOUD, NOT SILENT, AND THAT DISTINCTION IS THE WHOLE
# FIX. Reading the working tree was never the defect — reading it while presenting
# the answer as authoritative was. A repository with no <remote>/<trunk> ref is a
# real state (day one before the first push, a local-only clone), and a report that
# skipped every arm there would be useless exactly when a new adopter first runs it.
# So it falls back, says so in a line nobody can miss, and every arm repeats the
# source beside its own verdict.
CB_REF=""
CB_SRC_KIND="worktree"
CB_SRC_LABEL=""
if [ -n "$CB_TRUNK" ] \
   && git -C "$REPO_ROOT" rev-parse --verify --quiet "refs/remotes/$CB_REMOTE/$CB_TRUNK" >/dev/null 2>&1; then
  CB_REF="$CB_REMOTE/$CB_TRUNK"
  CB_SRC_KIND="ref"
  CB_SRC_LABEL="$CB_REF @ $(git -C "$REPO_ROOT" rev-parse --short "$CB_REF" 2>/dev/null || echo '?')"
else
  cb_branch="$(git -C "$REPO_ROOT" symbolic-ref --short HEAD 2>/dev/null || echo 'DETACHED')"
  CB_SRC_LABEL="WORKING TREE on '$cb_branch' (no $CB_REMOTE/${CB_TRUNK:-<unresolved trunk>} ref)"
fi

# CB_TREE is the directory the board-reading arms walk. For a ref, the ref's own
# copy of the board is materialized ONCE into a temp dir and the arms walk that —
# so their hard-won parsers stay byte-identical and only their INPUT moved. One
# `git archive` beats a `git show` per file on a board with a few hundred archived
# cards, which is what keeps this inside its <2s budget.
CB_TREE="$REPO_ROOT"
CB_TMP=""
cb_cleanup() { [ -n "$CB_TMP" ] && rm -rf "$CB_TMP" 2>/dev/null; }
trap cb_cleanup EXIT
if [ "$CB_SRC_KIND" = "ref" ]; then
  CB_TMP="$(mktemp -d 2>/dev/null || true)"
  if [ -n "$CB_TMP" ] \
     && git -C "$REPO_ROOT" archive --format=tar "$CB_REF" 2>/dev/null \
        | tar -x -C "$CB_TMP" 2>/dev/null; then
    CB_TREE="$CB_TMP"
  else
    # The materialization is the one step that can fail without the ref being
    # wrong. Degrade to the checkout and RELABEL, so no arm prints a ref it did
    # not actually read. Silence here would re-create the exact defect above.
    cb_branch="$(git -C "$REPO_ROOT" symbolic-ref --short HEAD 2>/dev/null || echo 'DETACHED')"
    CB_SRC_KIND="worktree"
    CB_SRC_LABEL="WORKING TREE on '$cb_branch' (could not read $CB_REF — archive failed)"
    CB_REF=""
    CB_TREE="$REPO_ROOT"
  fi
fi

# One helper so no arm can print a verdict without its operand beside it.
cb_src() { printf 'read from: %s' "$CB_SRC_LABEL"; }

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
# (a) Folder vs last-Activity drift across the ACTIVE columns (done/ is off-board
#     and can be huge — skipped for the <2s budget). The "declared status" is read
#     from the last Activity bullet in TWO ORDERED PASSES, because the two spellings
#     are not equals:
#       1. a transition ARROW `→ <folder>` — a DECLARATION, and what the mover emits;
#       2. only if there is no arrow, a backticked `` `<folder>` `` (optionally with
#          a trailing slash) — a MENTION, which is how prose refers to a column.
#     Where both appear, the arrow wins. Free-form notes with neither are
#     un-judgeable → skipped (no false positives). A bare `<folder>/` path-substring
#     alternative was DROPPED: it false-positived on an incidental path MENTION like
#     `supersedes progress/done/<PREFIX>-379-old.md`. The precedence and its own
#     measured false positive are recorded at the comparator below.
# ---------------------------------------------------------------------------
echo
echo "[a] Folder vs last-Activity drift (active columns) — $(cb_src):"
a_hits=0
a_cols=0
for folder in todo in_progress dev_complete qa_complete blocked; do
  dir="$CB_TREE/progress/$folder"
  # A MISSING COLUMN IS A SKIP, NOT A PASS. It used to `continue` silently, so a
  # board with no progress/ at all printed "✓ none" — a green establishing nothing,
  # which drift-report.md § 2 forbids outright ("it never reports a pass it did not
  # establish") and § 3 requires be reported as skipped with its reason.
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
    # PRECEDENCE, NOT A WIDER PATTERN: AN ARROW IS A DECLARATION, A BACKTICK IS A
    # MENTION, AND WHERE BOTH APPEAR THE ARROW WINS. One alternation over both forms
    # plus `tail -1` resolved whichever came LAST IN THE LINE, so a perfectly normal
    # entry —
    #     - <date> [Dev] → dev_complete: unblocked; see `blocked` for the prior context.
    # — was read as declaring `blocked` on a card correctly sitting in dev_complete/,
    # i.e. a FALSE drift finding on the mandated workflow. The arrow form is what the
    # mover emits and what a transition MEANS; a backticked folder is prose, and prose
    # is how a human explains the transition they just made. Two ordered passes, so a
    # mention can never outrank a declaration however the sentence is worded.
    #
    # THIS ARM IS THE LOAD-BEARING SIDE, deliberately, even though the mover now
    # refuses a note whose own text would introduce a status token. The mover can only
    # constrain entries IT writes; this arm reads every card on the board, including
    # ones seeded from a template, hand-appended before the note-only mode existed, or
    # edited by hand at 2am. Making the arm's correctness depend on provenance it
    # cannot verify would be exactly the "green because the input happened to be
    # well-formed" shape. The mover's refusal narrows the input space and is worth
    # keeping; it is not the guarantee.
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
  echo "    – no active column exists in this source — nothing was checked  (skipped)"
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
    echo "[b] qa_complete/ depth: $qc_count / $QA_COMPLETE_THRESHOLD threshold  ⚠ over — run ./scripts/archive.sh --apply — $(cb_src)"
    drift=1
  else
    echo "[b] qa_complete/ depth: $qc_count / $QA_COMPLETE_THRESHOLD threshold  ✓ — $(cb_src)"
  fi
fi

# ---------------------------------------------------------------------------
# (c) progress.md size — TWO measurements, kept deliberately distinct so no
#     reader can mistake a ✓ on one for a ✓ on the other:
#       • § Log SLICE: the byte weight of the section from the "## Log" heading
#         up to (but not including) the next "## " heading, or EOF. Byte-based,
#         not line-based. This measurement answers "is the slice every session
#         reads at start getting heavy?" and its reason is recorded beside
#         PROGRESS_LOG_BYTE_THRESHOLD above.
#       • WHOLE FILE: the file's total byte size against its OWN separate,
#         advisory threshold. The § Log slice can read "healthy" while the file's
#         dominant content sits past that heading's exit and is invisible to it,
#         so this arm answers the question the slice cannot. ADVISORY ONLY:
#         crossing it never sets `drift`, matching this check's existing
#         degrade-to-report posture (the "(skipped)" line below).
#     Both arms are trailing-newline-safe (wc -c counts the last line's bytes
#     whether or not it ends in "\n").
# ---------------------------------------------------------------------------
echo
pmd="$CB_TREE/progress.md"
if [ -f "$pmd" ]; then
  if grep -qE '^##[[:space:]]+Log' "$pmd"; then
    logbytes="$(awk '
      /^##[[:space:]]/ { if (inlog) exit; if ($0 ~ /^##[[:space:]]+Log/) inlog=1 }
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
    echo "[c] progress.md WHOLE FILE: $wholebytes / $PROGRESS_WHOLE_FILE_BYTE_THRESHOLD bytes  ⚠ over (ADVISORY, does not fail the board) — a rotation is due, see ./scripts/archive-progress.sh — $(cb_src)"
  else
    echo "[c] progress.md WHOLE FILE: $wholebytes / $PROGRESS_WHOLE_FILE_BYTE_THRESHOLD bytes  ✓ — $(cb_src)"
  fi
else
  echo "[c] progress.md: not found in this source  (skipped) — $(cb_src)"
fi

# BEGIN check (d)
# ---------------------------------------------------------------------------
# (d) Frontmatter id integrity across ALL SIX columns (the folder list is DERIVED
#     from STATUS_FOLDERS above, never re-listed — done/ is in scope on purpose: a
#     new mint can collide with an ARCHIVED issue, which is exactly why next-id.sh
#     also reads ARCHIVE.md). Three findings, one pass:
#       • a DUPLICATE id — the collision this check exists for (see the header);
#       • an id that DISAGREES with its filename's prefix — the same class, since
#         both are "the id is not what the board thinks it is", and both break every
#         id-based lookup while the board reads clean;
#       • a MISSING or MALFORMED id — degraded to a finding, never a traceback: this
#         runs inside the SessionStart hook, so a crash would break every session open.
#     ANCHORED TO THE FRONTMATTER BLOCK, not a whole-file grep — check (a) already
#     learned that lesson from an incidental path MENTION, and the same trap applies
#     to an id quoted in prose or in an Activity line. A guard that cries wolf on a
#     healthy board is worse than the blind spot it replaces.
#     One awk process over the whole board (not one per file) keeps the <2s budget
#     with a couple of hundred archived issues on it. Read-only; exit 0 by convention.
# ---------------------------------------------------------------------------
echo
echo "[d] Frontmatter id integrity (all six columns, from STATUS_FOLDERS) — $(cb_src):"
d_files=(); d_hits=0
IFS='|' read -r -a d_cols <<< "$STATUS_FOLDERS"
for folder in "${d_cols[@]}"; do
  d_dir="$CB_TREE/progress/$folder"
  [ -d "$d_dir" ] || continue
  for f in "$d_dir"/*.md; do
    [ -e "$f" ] || continue
    if [ -s "$f" ]; then
      d_files+=("$f")
    else
      echo "    ⚠ progress/$folder/$(basename "$f"): empty file — it carries no ${ISSUE_ID_KEY}: at all; restore it or remove it"
      d_hits=$((d_hits+1)); drift=1
    fi
  done
done
d_out=""
if [ "${#d_files[@]}" -gt 0 ]; then
  d_out="$(awk -v key="$ISSUE_ID_KEY" -v pat="$ISSUE_ID_PATTERN" -v scan="$FRONTMATTER_SCAN_LINES" \
               -v root="$CB_TREE/" -v dq='"' -v sq="'" '
    function short(p) { s = p; sub("^" root, "", s); return s }
    FNR == 1 { n++; path[n] = FILENAME; val[n] = ""; inf = 0; closed = 0; got = 0 }
    # The OPENING fence: the first bare `---` within the first `scan` lines. It is
    # deliberately not required on line 1 — see FRONTMATTER_SCAN_LINES above.
    !closed && !inf && FNR <= scan && /^---[[:space:]]*$/ { inf = 1; next }
    inf && /^---[[:space:]]*$/ { inf = 0; closed = 1; next }
    inf && !got && $0 ~ ("^" key ":") {
      v = $0
      sub("^" key ":[[:space:]]*", "", v)
      sub(/[[:space:]]*#.*$/, "", v)        # strip an inline frontmatter comment
      gsub(dq, "", v); gsub(sq, "", v)      # and any quoting around the value
      sub(/[[:space:]]+$/, "", v)
      val[n] = v; got = 1
      next
    }
    END {
      for (i = 1; i <= n; i++) {
        base = path[i]; sub(/.*\//, "", base)
        fid = ""
        if (match(base, "^" pat)) fid = substr(base, 1, RLENGTH)
        v = val[i]
        if (v == "") {
          printf "    ⚠ %s: no %s: line in its frontmatter block — every id-based lookup (git log --grep, move-issue.sh, the Activity trail) keys on it; add it, matching the filename\n", short(path[i]), key
          continue
        }
        if (v !~ ("^" pat "$")) {
          printf "    ⚠ %s: malformed %s: %s — expected the %s shape; correct it to match the filename\n", short(path[i]), key, v, pat
          continue
        }
        if (fid != "" && v != fid) {
          printf "    ⚠ %s: frontmatter %s: %s DISAGREES with its filename prefix %s — one of the two is wrong; make them match (rename the file, or correct the frontmatter — whichever is the stray)\n", short(path[i]), key, v, fid
        }
        seen[v] = seen[v] ", " short(path[i])
        count[v]++
        order[++m] = v
      }
      for (j = 1; j <= m; j++) {
        v = order[j]
        if (count[v] > 1 && !reported[v]) {
          reported[v] = 1
          files = seen[v]; sub(/^, /, "", files)
          printf "    ⚠ DUPLICATE %s: %s is carried by %d files: %s — renumber the LATER mint (./scripts/next-id.sh gives the next free number) and rename its file, branch and Activity trail to match\n", key, v, count[v], files
        }
      }
    }
  ' "${d_files[@]}" 2>/dev/null)"
fi
if [ -n "$d_out" ]; then
  printf '%s\n' "$d_out"
  d_hits=$((d_hits + $(printf '%s\n' "$d_out" | grep -c '⚠')))
  drift=1
fi

# --- (d) continued: THE OTHER IDENTIFIER SPACES — the declared registers -------
#     Same invariant, second operand space. A register's ids are handles that
#     every later reference resolves through, exactly like a board id — but the
#     collision arrives differently and that is why it went unwatched: two legs
#     minting the same id in DIFFERENT SECTIONS of an append-only register produce
#     NO TEXTUAL CONFLICT, so a rebase merges both cleanly and the duplicate lands
#     with no witness. Measured in a project running this process: two sessions
#     minted the same id within an hour, and the only defence was an instruction in
#     the register's own header telling the author to re-read before writing.
#
#     THE MAX IS READ ORDER-INDEPENDENTLY, and that is the second half of this arm.
#     A register grouped by section puts a later id ABOVE an earlier one, so
#     `grep '^### D-' | tail -1` returns whatever sits last in FILE order, not the
#     highest id — read as "the max" it proposes an id that already exists. This
#     arm therefore prints the true maximum, so nobody has to run the fragile
#     positional grep at all: the tool is the authority, not a recipe copied into
#     a header where it can be re-derived wrong.
#
#     Reports per register, names the file it read, and SKIPS an absent one with
#     its reason. Read-only; a finding sets `drift` like the rest of check (d).
reg_read=0; reg_skipped=0
while IFS='|' read -r reg_path reg_mark reg_shape; do
  [ -n "$reg_path" ] || continue
  reg_file="$CB_TREE/$reg_path"
  if [ ! -f "$reg_file" ]; then
    echo "    $reg_path: not present  (skipped — this project keeps no register there)"
    reg_skipped=$((reg_skipped+1)); continue
  fi
  # Every id in the file, in the order the file happens to hold them.
  reg_ids="$(grep -oE "^${reg_mark}${reg_shape}" "$reg_file" 2>/dev/null | sed "s|^${reg_mark}||" || true)"
  if [ -z "$reg_ids" ]; then
    echo "    $reg_path: 0 '${reg_mark}${reg_shape}' entry headings  (nothing to check yet)"
    continue
  fi
  reg_total="$(printf '%s\n' "$reg_ids" | grep -c .)"
  reg_distinct="$(printf '%s\n' "$reg_ids" | sort -u | grep -c .)"
  # ORDER-INDEPENDENT max: numeric sort on the digits, never the file's last line.
  # `sed -E`, not a BSD-hostile `\+`: the first spelling of this line silently
  # matched NOTHING, so `sort -n` was handed whole ids ("D-07"), compared them all
  # as zero, fell back to a BYTE compare and returned the right answer for the
  # wrong reason — correct on D-60/D-66, wrong the moment a register holds D-9 and
  # D-10. Caught by reading the output against a planted case, not by trusting it.
  reg_max="$(printf '%s\n' "$reg_ids" | sed -E 's/[^0-9]*([0-9]+)$/\1/' | sort -n | tail -1)"
  reg_dupes="$(printf '%s\n' "$reg_ids" | sort | uniq -d | tr '\n' ' ' | sed 's/ $//')"
  if [ -n "$reg_dupes" ]; then
    echo "    ⚠ $reg_path: DUPLICATE id(s): $reg_dupes  — every reference to them is ambiguous; renumber the later one and its citations"
    d_hits=$((d_hits+1)); drift=1
  fi
  reg_read=$((reg_read+1))
  echo "    $reg_path: $reg_total entry heading(s), $reg_distinct distinct, highest id number $reg_max (max over ALL headings, not the file's last line)"
done <<< "$(printf '%s\n' "$REGISTERS")"
# THE CLEARANCE NAMES WHAT IT COVERED, and never more. The first spelling of this
# line said "every declared register's ids distinct" even on a run where every
# register was SKIPPED — a pass over unread operands, which is `instruments.md`
# § A.4's own rule failing inside the arm that enforces it.
if [ "$d_hits" -eq 0 ]; then
  d_reg_note=""
  if   [ "$reg_read" -gt 0 ] && [ "$reg_skipped" -gt 0 ]; then d_reg_note="; ids distinct in the $reg_read register(s) read, $reg_skipped skipped"
  elif [ "$reg_read" -gt 0 ];                            then d_reg_note="; ids distinct in every declared register"
  elif [ "$reg_skipped" -gt 0 ];                         then d_reg_note="; NO register was read ($reg_skipped skipped) — this pass says nothing about them"
  fi
  echo "    ✓ none (every ${ISSUE_ID_KEY}: unique across all six columns and matching its filename${d_reg_note})"
fi
# END check (d)

# ---------------------------------------------------------------------------
# (e) [Role]-prefix scan of the last N trunk commits. The commit-msg hook enforces
#     the prefix pre-merge, but a forge SQUASH-merge lands the real
#     `[Role] <ID> …` subject as PARENT 2 of a "Merge branch …" commit — a
#     `--first-parent` walk would silently SKIP it. So walk plain history: for a merge
#     commit inspect PARENT 2's subject; for a non-merge inspect its own. Git/host
#     subjects (Merge/Revert/Squash/autosquash) are exempt — mirror commit-msg's list,
#     including its NARROWNESS: the squash arm matches git's generated subject, not any
#     sentence beginning with the word, or this scan would under-report exactly the
#     unprefixed commits it exists to find.
#     The accepted prefixes are DERIVED from the commit-msg hook so the two never
#     drift, with the kit's known set as a fallback. Informational — exit 0.
#
#     THIS ARM SAID "trunk" AND READ HEAD. Its `git log` took no revision, so it
#     walked whatever the current checkout pointed at — the one arm that named the
#     wrong operand IN PROSE while reading it, which is why it is worth its own note.
#     It now walks CB_REF when there is one.
#
#     AND ITS TWO OPERANDS USED TO STRADDLE THE COMMIT LANES: the vocabulary came
#     from the hook file in the WORKING TREE while the subjects came from the trunk.
#     A branch that adds a role would then have accepted its own new prefix on trunk
#     commits made before it existed. Both operands now come from the same source, so
#     the arm answers one question about one tree.
# ---------------------------------------------------------------------------
echo
ROLE_PREFIXES="$(sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p" "$CB_TREE/scripts/githooks/commit-msg" 2>/dev/null | head -1)"
# THE DERIVATION ABOVE IS THE PATTERN TO PRESERVE; the literal below is only what
# is used when the hook cannot be read — and it is the part that drifts (it once
# fell a role behind the hook it mirrors), so correct IT, never replace the
# derivation with it.
role_src="derived from scripts/githooks/commit-msg"
if [ -z "$ROLE_PREFIXES" ]; then
  ROLE_PREFIXES='PM|Dev|QA|Refactorer|UIDesigner|Orchestrator|Architect'
  # NAMED, NOT SILENT. The fallback is the drifting half by construction, so a run
  # that used it says so — otherwise "✓ every scanned subject carries a [Role]
  # prefix" can mean "…one of a set this project may not actually use".
  role_src="THE KIT'S FALLBACK SET — commit-msg was not readable in this source, so this is not your project's declared role set"
fi
# The revision walked is stated, not implied.
if [ -n "$CB_REF" ]; then
  CB_RULE_REV="$CB_REF"
else
  CB_RULE_REV="HEAD"
fi
# THE RULE'S LIFETIME — DERIVED ONCE HERE AND SHARED BY EVERY HISTORY ARM.
#
# ONE RULE, ONE EPOCH. scripts/githooks/commit-msg enforces its rules as one file, so
# they all begin binding at the same commit — the one that ADDED that file. Two arms
# deriving that commit separately would be one idea carrying two numbers, and the
# divergence would be SILENT: they agree on every history that exists today and part
# company on the first re-add, shallow boundary or root epoch. So CB_RULE_EPOCH and
# CB_RULE_INSCOPE are computed once, above every arm that needs them, and no arm may
# re-derive them.
#
# This arm used to scan the last N commits unconditionally and
# report EVERY unprefixed subject as drift — including commits made before the project
# adopted the kit, when no attribution rule existed to be violated. A rule cannot be
# violated before it exists, and the finding was unfixable by construction: the only
# cure would be rewriting published history. Worse, it fired on the FIRST report an
# adopter ever sees, because the kit REQUIRES a commit before kit-init.sh may run and
# wires the hook after it — so a correctly-executed day one guarantees a false finding,
# and a report that is never clean stops being read.
#
# THE EPOCH IS THE COMMIT THAT ADDED THE HOOK FILE, and the alternatives were rejected
# for reasons worth keeping. The stamp receipt in scripts/config.sh is written only by
# kit-init.sh, so a hand-copy adopter (SEED.md step 2 branch B) would get no epoch at
# all. "The commit that wired core.hooksPath" — the shape this was first reported in —
# DOES NOT EXIST: `git config` writes .git/config and leaves no commit. The hook FILE is
# part of the kit copy, so both adoption branches have it.
#
# THE EARLIEST ADD, NOT THE LATEST (`tail -1` — git log walks newest-first). If the file
# was ever removed and restored, the rule began at its first arrival; taking the later
# add would hide every unprefixed commit in between. This arm errs toward reporting.
#
# AND THE SCOPING DOES NOT SUBSUME kit-init.sh's OWN ATTRIBUTION FILTER. That filter
# tolerates findings on commits that are ancestors of HEAD-before-its-run, which is a
# LATER boundary than this one; the commits between the two — made after the hook file
# arrived but before kit-init ran, with the hook therefore still unwired — are reported
# here and tolerated there, and each is right for the question it answers. Reconciled,
# not assumed: see the matching note at kit-init.sh's board self-check.
#
# A SHALLOW CLONE RE-HOMES THE EPOCH AND MUST NOT BE TRUSTED. A grafted root has no
# parents, so every file it contains reads as ADDED there — and the derivation below
# then resolves the hook file's "arrival" to the graft boundary instead of to the real
# commit. Measured: `git clone --depth 3` of this repository moves the epoch from the
# true add-commit to the boundary, and the in-scope set collapses to two commits out of
# a twenty-commit window. The arms would then print a scope line naming a commit that is
# an artefact of the clone depth, and a ✓ over almost nothing.
#
# SHALLOW IS COMMON, NOT EXOTIC: it is the default CI checkout on most forges, which is
# exactly where a report is most likely to be read by a machine rather than a person.
#
# THE ANSWER IS TO STOP NARROWING, NOT TO SKIP. On a shallow clone the pre-adoption
# commits are ABSENT anyway, so scanning everything present reports no more than it
# should — and it errs toward reporting, which is the direction this arm's accepted
# residual already commits to. What must not happen is a narrowing that LOOKS derived.
CB_RULE_EPOCH=""; CB_RULE_SHALLOW=""; role_preepoch=0
if [ "$(git -C "$REPO_ROOT" rev-parse --is-shallow-repository 2>/dev/null || echo false)" = "true" ]; then
  CB_RULE_SHALLOW="yes"
elif git -C "$REPO_ROOT" rev-parse --verify --quiet "$CB_RULE_REV" >/dev/null 2>&1; then
  CB_RULE_EPOCH="$( { git -C "$REPO_ROOT" log --diff-filter=A --format=%H "$CB_RULE_REV" \
                     -- scripts/githooks/commit-msg 2>/dev/null || true; } | tail -1 )"
fi
# STRICTLY AFTER, and this is an off-by-one that was corrected before it shipped: the
# kit's own day-one recipe is `git add -A && MSG_OK=1 git commit -m 'init'`, which
# commits the whole kit copy — the hook file included — under the subject `init`. So the
# epoch commit is ITSELF one of the unprefixed commits this arm would flag, and "at or
# after" would keep reporting the exact line the adopter complained about.
# `--ancestry-path` gives the strict-descendant set in one call, with no per-commit loop.
CB_RULE_INSCOPE=""
if [ -n "$CB_RULE_EPOCH" ]; then
  CB_RULE_INSCOPE="$(git -C "$REPO_ROOT" rev-list --ancestry-path "$CB_RULE_EPOCH..$CB_RULE_REV" 2>/dev/null || true)"
fi
# ONE RENDERER FOR THE NARROWING, used by every history arm. Two arms printing the same
# scope in two wordings is the same second-copy defect as two arms deriving it, one level
# up — and a reader comparing them could not tell a difference in wording from a
# difference in fact.
cb_rule_scope_lines() {  # <count excluded>
  if [ -n "$CB_RULE_EPOCH" ]; then
    echo "    scope: commits after ${CB_RULE_EPOCH:0:9}, which ADDED scripts/githooks/commit-msg — $1 of the last $ROLE_SCAN_N excluded as predating the rule"
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

echo "[e] [Role]-prefix scan (last $ROLE_SCAN_N commits of $CB_RULE_REV, squash-aware) — prefixes $role_src:"
role_hits=0
role_scanned=0
if git -C "$REPO_ROOT" rev-parse --verify --quiet "$CB_RULE_REV" >/dev/null 2>&1; then
  while IFS='|' read -r sha parents; do
    [ -z "$sha" ] && continue
    # shellcheck disable=SC2086
    set -- $parents                       # word-split the space-separated parent list
    if [ "$#" -ge 2 ]; then
      target="$2"                         # merge commit → parent 2 carries the squashed [Role] subject
    else
      target="$sha"                       # non-merge → its own subject
    fi
    # OUT OF SCOPE IS NOT SCANNED, and it is counted so the scope line can say how many.
    # The test is on $sha — the commit in the walked history — not on $target: a merge's
    # parent 2 lives on a side branch, and asking whether THAT is a strict descendant of
    # the epoch answers a different question than "was the rule in force when this landed".
    if [ -n "$CB_RULE_EPOCH" ] && ! printf '%s\n' "$CB_RULE_INSCOPE" | grep -qxF "$sha"; then
      role_preepoch=$((role_preepoch+1)); continue
    fi
    subj="$(git -C "$REPO_ROOT" log -1 --format=%s "$target" 2>/dev/null || true)"
    [ -z "$subj" ] && continue
    role_scanned=$((role_scanned+1))
    case "$subj" in
      "Merge branch "*|"Merge remote-tracking branch "*|"Merge pull request "*|"Merge tag "*|"Merge commit "*) continue ;;
      "Revert \""*|"Revert '"*) continue ;;
      "Squashed commit of the following:"*) continue ;;   # narrowed with commit-msg's
      "fixup! "*|"squash! "*|"amend! "*) continue ;;
    esac
    if ! printf '%s' "$subj" | grep -qE "^\[(${ROLE_PREFIXES})\] "; then
      echo "    ⚠ ${target:0:9} subject lacks a [Role] prefix: $subj"
      role_hits=$((role_hits+1)); drift=1
    fi
  done < <(git -C "$REPO_ROOT" log --no-color --format='%H|%P' -n "$ROLE_SCAN_N" "$CB_RULE_REV" 2>/dev/null)
else
  # NO HISTORY IS A SKIP. This used to fall through the `if` and print
  # "✓ every scanned subject carries a [Role] prefix" over ZERO subjects — a green
  # from an empty set, which is the shape drift-report.md § 2 forbids by name.
  echo "    – $CB_RULE_REV does not resolve — no history to scan  (skipped)"
  role_scanned=-1
fi
# WHAT THIS ARM DID NOT LOOK AT, NAMED — on the clearing branch as much as the
# complaining one (doctrine/instruments.md § A.4). An arm that silently narrows its own
# operand set is the defect this kit spent a crunch removing; a narrowing that is CORRECT
# still has to say so, or "✓ all N scanned subject(s) carry a [Role] prefix" quietly means
# "…all N of the ones I chose to look at".
if [ "$role_scanned" -ge 0 ]; then
  cb_rule_scope_lines "$role_preepoch"
fi
if [ "$role_scanned" -eq 0 ]; then
  echo "    – $CB_RULE_REV resolved but yielded no inspectable subject  (skipped)"
elif [ "$role_scanned" -gt 0 ] && [ "$role_hits" -eq 0 ]; then
  echo "    ✓ all $role_scanned scanned subject(s) carry a [Role] prefix"
fi

# ---------------------------------------------------------------------------
# (f) UNPUBLISHED WORK, IN BOTH HOMES — not one. This arm used to watch only the
#     board mover's .kanban-wt, which is the home a process death between commit and
#     push strands work in; it never asked the same question of the MAIN CHECKOUT,
#     which is where every ruling, PRD and role-doc edit is written. Two homes, two
#     sub-readings, each naming its own operand and each able to skip with its own
#     reason. Neither number is reported without the surface it came from.
#
#     ITS RATIONALE IS "THE OPERATOR IS TOLD EARLY", NOT "I AM THE LAST WARNING."
#     This arm used to justify itself by QUOTING kanban-worktree.sh's sync note back
#     — that an unpushed commit "is reset on the next sync by design" — so the arm
#     was the only thing standing between that commit and its deletion. `kwt_sync`
#     now REFUSES rather than resetting over such a commit, so that justification is
#     gone and the arm is a **second line of defence**: it surfaces the state at
#     session close, before the operator meets the refusal mid-op with a board move
#     to finish. Useful, no longer load-bearing.
#     DELIBERATELY DESCRIBED, NOT QUOTED. Restating a sibling script's behaviour in
#     its own words is what made this comment go false the moment that script
#     changed; naming the function and what it does survives a rewording of it.
#
#     IT SEES ONE OF THE TWO WAYS WORK GETS STRANDED HERE, AND SAYS WHICH.
#       • REACHABLE FROM HEAD but not from the remote — committed, unpushed. This is
#         what `rev-list --count <remote>/<trunk>..HEAD` counts, and it is reported.
#       • REACHABLE FROM NO REF AT ALL — an orphaned sibling, e.g. a commit made
#         while the worktree was attached, left behind when HEAD moved elsewhere. It
#         is not an ancestor of HEAD, so the count above is 0, and `git status` is
#         clean because nothing is uncommitted. **This arm cannot see it**, and an
#         unqualified "in sync ✓" would invite the reader to conclude no work is
#         stranded — a stronger claim than the measurement supports.
#     So each green NAMES ITS SPAN (instruments.md § A.4), once for both homes at the
#     arm's foot. Finding the second kind needs the reflog, which is per-worktree
#     local state and would owe its own operand line; it is deliberately not folded
#     in here.
#
#     No-ops cleanly (skip) when .kanban-wt is absent or the remote is unreachable,
#     so it can't blow the <2s budget. Informational — exit 0 by convention.
#
#     THE TRUNK CHAIN IS RESOLVED THE SAME WAY kwt_resolve DOES, and the last link
#     is READ FROM THAT LIBRARY rather than re-typed here — a re-typed branch name
#     is the drift this file's greppable-defaults contract exists to prevent. This
#     is read-only, so it degrades to a SKIP line rather than warning: the loud
#     warning belongs to the ops that actually write (see kwt_resolve).
#
#     THIS ARM IS DELIBERATELY LOCAL-SCOPED, AND IT NAMES EVERY SURFACE IT READ. It
#     is the one arm the "read <remote>/<trunk>" rule does NOT apply to, because its
#     subject IS the local side: "does either home this repository publishes from hold
#     work that never reached the trunk?" cannot be answered from the trunk — the
#     trunk is precisely what the work is missing from. [f1] compares the LOCAL trunk
#     ref against the remote-tracking one; [f2] compares the mover's worktree HEAD
#     against it. The invariant the other arms satisfy by naming a ref, this one
#     satisfies by naming both surfaces and reporting them separately.
#
#     IT LOCATES THE MAIN WORKTREE INSTEAD OF ASSUMING $REPO_ROOT IS IT, and that is
#     what makes the tool correct from ANY location. `.kanban-wt` is registered
#     against the main worktree, so `$REPO_ROOT/.kanban-wt` found nothing whenever
#     the script ran from a linked worktree — and the arm then printed "no registered
#     worktree (skipped)" about a worktree that existed. Measured consequence: the
#     obvious workaround for the stale arms above was "run it from a trunk worktree",
#     which fixed (a)–(e) and blinded THIS arm, so there was no location from which
#     the whole report was correct. Reading a named ref above removes the reason to
#     run it elsewhere; `--git-common-dir` removes the penalty for doing so anyway.
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

# ── [f1] THE MAIN CHECKOUT'S TRUNK REF. The home this arm did not watch. ──────
# EVERYTHING THE KIT CLASSIFIES AS METADATA COMMITS DIRECT TO THE TRUNK FROM HERE:
# rulings in requirements/DECISIONS.md, PRDs, issue edits, role docs, process/**,
# dev/**, progress.md, the adapter. So the one home carrying the process's own
# memory was the one home nothing watched, and a board could report `clean ✓` with a
# day of unpushed rulings beside it. Measured on a real program: a ruling recorded
# while the coordinator's main surface went unpushed left the successor unable to
# find the authority its own launch prompt cited, and the recovery took an hour.
# `doctrine/commit-hygiene.md` already forbids ending a landing on an unpushed
# looks-pushed state; the rule was written and the instrument did not cover it.
#
# THE OPERAND IS THE LOCAL TRUNK REF, NOT `HEAD`, and that choice is load-bearing.
# A leg legitimately holds the main checkout on a feature branch, so HEAD-vs-trunk
# would be `ahead` by the whole branch and would redden on every normal run — a
# false red on the common case, which is how an instrument gets ignored. The local
# trunk BRANCH is where an unpushed metadata commit actually sits, whether or not it
# is the thing checked out, so that is what is measured. What IS checked out is
# reported beside it, because it tells the reader whether the trunk is live here.
f_main_ref="refs/heads/${def:-}"
if [ -z "$def" ]; then
  echo "      [f1] main checkout: trunk unresolved, so there is no ref to compare  (skipped) — inspected: $kwt_main"
elif ! git -C "$kwt_main" rev-parse --verify --quiet "$f_main_ref" >/dev/null 2>&1; then
  echo "      [f1] main checkout: no local '$def' branch exists yet  (skipped) — inspected: $kwt_main"
elif ! git -C "$kwt_main" rev-parse --verify --quiet "refs/remotes/$remote/$def" >/dev/null 2>&1; then
  echo "      [f1] main checkout: $remote/$def unavailable (never pushed? offline?)  (skipped) — inspected: $kwt_main"
else
  f_head="$(git -C "$kwt_main" symbolic-ref --short HEAD 2>/dev/null || echo 'DETACHED')"
  f_ahead="$(git -C "$kwt_main" rev-list --count "$remote/$def..$f_main_ref" 2>/dev/null || echo 0)"
  f_behind="$(git -C "$kwt_main" rev-list --count "$f_main_ref..$remote/$def" 2>/dev/null || echo 0)"
  if [ "${f_ahead:-0}" -gt 0 ]; then
    echo "      [f1] main checkout: '$def' is $f_ahead commit(s) AHEAD of $remote/$def  ⚠ UNPUBLISHED — everything the process records as metadata lands here, so this is rulings/PRDs/board edits nobody else can see"
    echo "           Fix: git -C '$kwt_main' push $remote $def   (checked out here: $f_head)"
    drift=1
  else
    echo "      [f1] main checkout: '$def' is 0 ahead / $f_behind behind $remote/$def  ✓ — read from: $f_main_ref in $kwt_main (checked out here: $f_head)"
    # AND THIS ARM AND release.sh GATE (a) DISAGREE ABOUT "BEHIND" ON PURPOSE. That gate
    # refuses a cut from a behind checkout; this one waves it through. The difference is
    # not policy, it is what each one KNOWS: this arm reads refs/remotes/… WITHOUT
    # fetching, so its idea of the remote may be arbitrarily stale and it cannot honestly
    # gate on it — while gate (a) fetches first and is therefore entitled to. A report
    # that does not fetch may only report. Do not "reconcile" these by making this one
    # refuse; make it fetch first, or leave it alone.
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

# ---------------------------------------------------------------------------
# (g) GRADUATION — has day one finished, and has the scaffolding been replaced?
#
# WHY IT IS HERE AND NOT IN ITS OWN SCRIPT: this reporter already runs at every
# session close, and graduation is a question that must be asked repeatedly and
# then never again. A kit-graduate.sh would be a subsystem that exists to be run
# once and forgotten; an arm here is one more line in an instrument already in
# the ritual, and it goes quiet on its own.
#
# IT READS THE TRUNK, LIKE EVERY OTHER TRUNK-PROPERTY ARM, AND THAT IS THE WHOLE
# CORRECTNESS ARGUMENT. Every class it inspects — the root documents, PROJECT.md,
# the optional directories — is METADATA-lane and commits direct to the trunk. A
# working-tree read would declare graduation on an unpushed edit and then, because
# a satisfied graduation stops reporting, NEVER RE-ASK. That is the measured defect
# of a checker that never watched the home its subject lived in — here in a one-way
# arm, where it is unrecoverable rather than merely stale. So it walks $CB_TREE like
# arms (a)-(e).
#
# IT DOES NOT SET `drift`, DELIBERATELY, AND THIS IS THE PART TO READ BEFORE
# CHANGING IT. The final verdict line answers "is the BOARD telling the truth?",
# and release.sh gate (d) greps that line's literal `board-drift: clean` text to
# decide whether a cut may proceed. Wiring day-one completeness into it would mean
# a project that has not finished setup can never cut a release — a policy nobody
# has ruled — and would redden a correct state: a repository one minute after
# kit-init has NOT graduated, by definition, and its board is nonetheless perfectly
# truthful. Two different subjects, one instrument, one verdict line that keeps its
# own meaning. If graduation should ever block a release, that is a ruling and it
# belongs in release.sh's own gate list, not smuggled in through this counter.
#
# IT NEVER GOES SILENT, INCLUDING WHEN IT IS SATISFIED. `doctrine/instruments.md`
# § A.4: *every instrument that names its operand when it complains must name it
# when it clears.* An arm that printed nothing once graduated would be
# indistinguishable from an arm that had broken, which is the false-confidence
# asymmetry that rule exists to forbid. "Self-retiring" here means it stops asking
# for ACTION, not that it stops reporting: one line, forever, naming what it read.
# ---------------------------------------------------------------------------
echo

# The enabling condition is kit-init's own stamp receipt, DERIVED from kit-init.sh
# rather than re-typed, for the reason the greppable-defaults contract gives: a
# re-typed constant is drift waiting to happen. Two questions are deliberately kept
# apart here — the receipt answers "did the initializer run", this arm answers "is
# the scaffolding still in place". Before the receipt exists there is nothing to
# graduate FROM, so the arm has no subject and says so rather than reporting a pass.
g_stamp="$(sed -n "s/^STAMP_MARK='\(.*\)'/\1/p" "$CB_TREE/scripts/kit-init.sh" 2>/dev/null | head -1)"
[ -n "$g_stamp" ] || g_stamp='# Stamped by scripts/kit-init.sh'

# THE TOKEN "reports only" IN THE LINE BELOW IS A MACHINE CONTRACT, NOT PHRASING.
# Specified: process/contracts/drift-report.md § 4 item 5. Consumed: scripts/kit-init.sh's
# self-check, which drops advisory sections by it. Reword it here and that consumer silently
# starts treating these advisories as findings and failing fresh installs — which is the
# regression this token was introduced to end. Change it in all three places or none.
echo "[g] Graduation — has day one finished?  (reports only; it never changes the verdict below —"
echo "      a repository one minute after kit-init has not graduated, and its board is truthful)"
# THE ENABLING CONDITION IS "HAS THIS REPOSITORY LIVED", NOT "DID kit-init RUN".
#
# It gated on the stamp receipt alone until 2026-08-29, and the reason was sound and is
# kept: a tree that has not started must not be nagged to finish. But the receipt is
# only ONE of the signals that a project has started. process/SEED.md step 2 branch B
# is a SUPPORTED route — implement the contracts in your own toolchain — and a project
# that takes it NEVER RUNS kit-init, so it never gets a receipt and was never asked to
# graduate. That is the population most likely to still be carrying scaffolding, because
# it also skipped the tool that would have stamped it.
#
# The widened set is kit-init's OWN already-lived signal set, and the constants come
# from their declaring sites rather than from a second list here: the receipt token is
# read out of kit-init.sh above, and the columns are STATUS_FOLDERS, this file's own
# declared seam. A pre-init tree with an empty board, an empty log and an empty archive
# still has no signal and is still skipped, which is the original reason preserved.
#
# STATED LIMIT: the three non-receipt probes REIMPLEMENT kit-init's shapes rather than
# calling them, because that block is inline in kit-init.sh and cannot be sourced without
# running the initializer. The constants are derived; the probe shapes are not. Extracting
# them into scripts/lib/ is the one-authoring-site fix and is not done here — recorded so
# the next reader finds a decision rather than an oversight.
#
# SUPERSEDED 2026-09-02 — the reason above stands and is why the extraction was worth
# doing; only its conclusion is out of date. The probe shapes now live in
# scripts/lib/lived-probe.sh, sourced above, and the two copies HAD ALREADY DIVERGED on
# the receipt before they were merged (that file's header carries the measurement). What
# remains true: kit-init's block still cannot be sourced, which is exactly why the probes
# went to a third file rather than one consumer importing the other.
# CAPTURE, THEN SLICE — never `kit_lived_signals … | head -1`. This script runs
# `set -o pipefail`, head closes the pipe early, and the SIGPIPE comes back as the
# pipeline's status. The library emits the receipt FIRST, so the first record is this
# arm's enabling condition and the old short-circuit order is preserved exactly.
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
  # A THIRD OUTCOME, AHEAD OF THE OTHER TWO. Without it a load failure would fall into
  # the "$g_lived is empty" branch below and print the NOT-STARTED clearance — a green
  # over a question that was never asked, which is precisely the shape this arm's own
  # neighbours were rewritten to stop producing.
  echo "      THIS CHECK DID NOT RUN: $CB_LIVED_LIB_ERR — the already-lived probe this arm"
  echo "      shares with the initializer could not be loaded, so whether this repository has"
  echo "      STARTED was not measured. Nothing here is a statement that the tree is clean."
  echo "      Restore it:  git checkout -- scripts/lib/lived-probe.sh  (skipped)"
elif [ -z "$g_lived" ]; then
  # NOT A PASS, AND THE WORDING IS THE POINT. "Nothing to graduate from" reads as a
  # clean bill; this run did not check. A reader must be able to tell an unrun check
  # from a clean one, which is the same distinction the guard-floor note draws.
  echo "      THIS CHECK DID NOT RUN: no sign this repository has started — no stamp receipt, no issue"
  echo "      files on the board, no history in progress.md § Log, nothing indexed in ARCHIVE.md."
  echo "      A fresh unpack is not nagged to finish. Nothing here is a statement that the tree is clean.  (skipped) — $(cb_src)"
else
  # NAME THE SIGNAL THAT ENABLED THE CHECK. Every other arm in this file prints the
  # operand it read; an enabling condition is an operand too, and a reader who wants
  # to know why the check ran on their tree should not have to reason it out.
  echo "      (enabled by: $g_lived)"
  g_find=0

  # (g1) REPLACE class — the scaffolding sentinel. An exact literal, so there is no
  # pattern to be wrong about. The two members are the root documents that ship as
  # scaffolding; both carry the line, and replacing the file removes it with them.
  g_repl=""
  for f in CLAUDE.md README.md; do
    [ -f "$CB_TREE/$f" ] || continue
    grep -qF 'BOOTSTRAP-SCAFFOLDING' "$CB_TREE/$f" 2>/dev/null && g_repl="$g_repl $f"
  done
  if [ -n "$g_repl" ]; then
    echo "      REPLACE: still scaffolding —$g_repl  ⚠ replace (do not edit) with your own; the adapter is built from process/templates/CLAUDE-adapter.template.md — $(cb_src)"
    g_find=1
  else
    echo "      REPLACE: CLAUDE.md, README.md carry no scaffolding sentinel  ✓ — $(cb_src)"
  fi

  # (g2) FILL class — unfilled <angle-bracket> blanks. SCOPED TO PROJECT.md AND THE
  # SCOPE IS PRINTED: the angle-bracket convention is a markdown-document convention,
  # and the other FILL members (.gitignore's build section, .env.example, verify.sh's
  # GATES, setup.sh's runtime half) do not express a blank that way. Guessing at them
  # would manufacture false reds in shell files, which is worse than a narrow arm that
  # says how narrow it is.
  if [ -f "$CB_TREE/PROJECT.md" ]; then
    g_blanks="$(grep -oE '<[a-z][^<>]*>' "$CB_TREE/PROJECT.md" 2>/dev/null | grep -v '://' | wc -l | tr -d ' ')"
    if [ "${g_blanks:-0}" -gt 0 ]; then
      echo "      FILL: PROJECT.md still holds ${g_blanks} <angle-bracket> blank(s)  ⚠ a FILL file is not done until no blank remains — $(cb_src)"
      g_find=1
    else
      echo "      FILL: PROJECT.md holds 0 <angle-bracket> blanks  ✓ — $(cb_src)"
    fi
  else
    echo "      FILL: no PROJECT.md to read  (skipped) — $(cb_src)"
  fi
  echo "      (FILL span: PROJECT.md only. The non-markdown FILL members are NOT measured here.)"

  # (g3) DELETE-IF-UNUSED — NOT IMPLEMENTED, and said out loud rather than omitted.
  # Deciding it needs a tracked way to record "kept on purpose", which does not exist
  # yet; inventing one inside this arm would be a format nobody ratified. An omitted
  # line would read as a clean result for a class nothing looked at.
  echo "      DELETE-IF-UNUSED: not measured — no tracked way to record \"kept on purpose\" exists yet, so absence of a finding here means nothing was checked  (skipped)"

  if [ "$g_find" -eq 0 ]; then
    echo "      → graduation COMPLETE over the classes measured above; this arm has nothing further to ask."
  else
    echo "      → day one is not finished. The checklist is process/SEED.md § Day one is done when."
  fi
fi

# ---------------------------------------------------------------------------
# (h) GENERATED-TRAILER scan of the same window. RULE (2) of the commit-msg hook is a
#     WRITE-TIME wall: it stops the next commit and says nothing about history already
#     written. contracts/commit-attribution.md § 4 states the count of unattributed
#     commits in a recent window as ZERO, and nothing measured it. This arm does.
#
#     IT SHARES ARM (e)'s EPOCH AND MUST NOT DERIVE ITS OWN. Rules (1) and (2) live in
#     ONE file and therefore begin binding at ONE commit — see CB_RULE_EPOCH above.
#
#     THE WINDOW IS ROLE_SCAN_N, REUSED RATHER THAN DUPLICATED. One idea does not carry
#     two numbers; the constant's stated meaning is widened to "the history arms" at its
#     declaration rather than a sibling being minted here.
#
#     THE MARKERS ARE DERIVED FROM THE HOOK, exactly as arm (e) derives the prefixes, and
#     the fallback is NAMED for the same reason: it is the half that drifts, so a run
#     that used it must say so rather than letting a clean result imply the project's own
#     list was consulted.
#
#     SCOPE, SAID PLAINLY: commit MESSAGES in a recent window. commit-hygiene.md § A.1
#     covers specs, issue activity entries and review notes too; a clean [h] says nothing
#     about those, and a reader who assumed otherwise would be wrong.
# ---------------------------------------------------------------------------
echo
TOOL_TRAILER_MARKERS="$(sed -n "s/^TOOL_TRAILER_MARKERS='\(.*\)'/\1/p" "$CB_TREE/scripts/githooks/commit-msg" 2>/dev/null | head -1)"
h_src="derived from scripts/githooks/commit-msg"
if [ -z "$TOOL_TRAILER_MARKERS" ]; then
  TOOL_TRAILER_MARKERS='claude|anthropic|copilot|chatgpt|openai|gpt|gemini|codex|aider|bot'
  h_src="THE KIT'S FALLBACK SET — commit-msg was not readable in this source, so this is not your project's declared marker list"
fi
echo "[h] generated-trailer scan (last $ROLE_SCAN_N commits of $CB_RULE_REV, commit MESSAGES only) — markers $h_src:"
h_hits=0
h_scanned=0
h_preepoch=0
if git -C "$REPO_ROOT" rev-parse --verify --quiet "$CB_RULE_REV" >/dev/null 2>&1; then
  while IFS= read -r h_sha; do
    [ -z "$h_sha" ] && continue
    if [ -n "$CB_RULE_EPOCH" ] && ! printf '%s\n' "$CB_RULE_INSCOPE" | grep -qxF "$h_sha"; then
      h_preepoch=$((h_preepoch+1)); continue
    fi
    h_scanned=$((h_scanned+1))
    # THE WHOLE MESSAGE, not the subject: a trailer is by definition in the body. The
    # two patterns MIRROR the hook's own arms, including their anchoring — § A.1 forbids
    # such a LINE, so "generated with the codegen step" mid-sentence is prose, not a
    # provenance claim, and must not be reported.
    h_body="$(git -C "$REPO_ROOT" log -1 --format=%B "$h_sha" 2>/dev/null || true)"
    h_bad="$( { printf '%s\n' "$h_body" | grep -iE "^[[:space:]]*co-authored-by:.*[^[:alnum:]](${TOOL_TRAILER_MARKERS})([^[:alnum:]]|\$)" || true; } | head -1 )"
    [ -n "$h_bad" ] || h_bad="$( { printf '%s\n' "$h_body" | grep -iE '^[^[:alnum:]]*generated with[[:space:]]' || true; } | head -1 )"
    if [ -n "$h_bad" ]; then
      echo "    ⚠ ${h_sha:0:9} carries a generated trailer: $(printf '%s' "$h_bad" | sed 's/^[[:space:]]*//')"
      h_hits=$((h_hits+1)); drift=1
    fi
  done < <(git -C "$REPO_ROOT" log --no-color --format='%H' -n "$ROLE_SCAN_N" "$CB_RULE_REV" 2>/dev/null)
else
  echo "    – $CB_RULE_REV does not resolve — no history to scan  (skipped)"
  h_scanned=-1
fi
if [ "$h_scanned" -ge 0 ]; then
  cb_rule_scope_lines "$h_preepoch"
fi
if [ "$h_scanned" -eq 0 ]; then
  echo "    – $CB_RULE_REV resolved but yielded no in-scope commit  (skipped)"
elif [ "$h_scanned" -gt 0 ] && [ "$h_hits" -eq 0 ]; then
  echo "    ✓ none of the $h_scanned in-scope commit message(s) carries a generated trailer"
fi

# ---------------------------------------------------------------------------
# (i) blocks: / blocked_by: SYMMETRY. Two card templates carry these fields and NO
#     SCRIPT WRITES THEM — measured: they appear in the two templates, two role docs and
#     one skill, and in zero scripts; the board mover writes back only `pr:`. They are
#     hand-maintained, and .claude/roles/orchestrator.md gates DISPATCH on them
#     (§ Chain-verify-first). So an asymmetric pair reads as fine on each card alone and
#     sends work onto unlanded state, and no single-file check can see it.
#
#     ADVISORY, AND THE REASON IS A PROPERTY OF THE FIELD, NOT A PREFERENCE. Every arm
#     that sets `drift` reads something a shipped mechanism produces AND clears — the
#     folder the mover put it in, the depth the sweep clears, the id the minter
#     allocates, the prefix the hook enforces. These fields have no producer and no
#     clearing operation, so a deciding finding here would be the first whose fix
#     instruction is "hand-edit a card", holding release.sh gate (d) shut on it, with the
#     only escape disabling the WHOLE board gate. Revisit when a mechanism exists that
#     writes and clears these fields; the finding will then name an operation that fixes
#     it, which is the standard the other arms meet.
#
#     THE HEADER CARRIES THE LITERAL `reports only` AND THE FINDINGS ARE INDENTED. That
#     token is a machine contract, not a turn of phrase: kit-init's self-check drops
#     advisory sections by it and resets on any line matching ^[a-z] in brackets. Get
#     either wrong and this arm starts failing fresh installs.
#
#     BOTH DIRECTIONS. Reading only `blocks:` is structurally blind to every
#     `blocked_by: [A]` whose counterpart never answered — which is the half a concurrent
#     mint actually produces. Each asymmetric pair fires ONCE, from whichever end carries
#     the declaration, and every finding names BOTH cards because either end may be the
#     stray.
#
#     IT RUNS AFTER [d] AND REUSES ITS FILE LIST. Stated because it is a real coupling:
#     d_files is the six live board columns, already filtered for empties.
# ---------------------------------------------------------------------------
echo
echo "[i] blocks:/blocked_by: symmetry (six columns, from STATUS_FOLDERS; reports only — it never changes the verdict below) — $(cb_src):"
if [ "${#d_files[@]}" -eq 0 ]; then
  echo "      – no issue file on the board  (skipped)"
else
  i_out="$(awk -v scan="$FRONTMATTER_SCAN_LINES" '
    function flush_list(   n, i, parts) {
      # A flow list: [A, B] — or a single bare scalar.
      if (curval ~ /^\[/) {
        gsub(/^\[|\]$/, "", curval)
        n = split(curval, parts, /[[:space:]]*,[[:space:]]*/)
        for (i = 1; i <= n; i++) if (parts[i] != "") add(parts[i])
      } else if (curval != "") add(curval)
    }
    function add(t) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", t); if (t == "") return
                      DECL++; if (curkey == "blocks") B[id "\x1f" t] = 1; else BB[id "\x1f" t] = 1 }
    FNR == 1 { if (id != "") { flush_list(); CARD[id] = 1 }
               id = ""; curkey = ""; curval = ""; inlist = 0 }
    FNR > scan { next }
    {
      line = $0
      sub(/[[:space:]]*#.*$/, "", line)          # the templates END these lines with a # comment
      if (line ~ /^[[:space:]]*id:[[:space:]]*/) { v = line; sub(/^[[:space:]]*id:[[:space:]]*/, "", v)
                                                   gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); id = v }
      if (line ~ /^[[:space:]]*(blocks|blocked_by):/) {
        flush_list()
        curkey = (line ~ /^[[:space:]]*blocks:/) ? "blocks" : "blocked_by"
        curval = line; sub(/^[[:space:]]*(blocks|blocked_by):[[:space:]]*/, "", curval)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", curval)
        inlist = (curval == "")                  # empty value ⇒ a BLOCK-style list may follow
        if (!inlist) { flush_list(); curval = ""; curkey = "" }
        next
      }
      # A FENCE IS NOT A LIST ITEM. `---` matched the block-list pattern when it was
      # written `-[[:space:]]*`, so the closing frontmatter fence was parsed as a
      # dependency on "--" and reported as a dangling reference. YAML requires a space
      # after the dash, so requiring one is both correct and the fix.
      if (line ~ /^---[[:space:]]*$/) { inlist = 0; curkey = ""; curval = ""; next }
      if (inlist && line ~ /^[[:space:]]*-[[:space:]]+[^[:space:]]/) {
        v = line; sub(/^[[:space:]]*-[[:space:]]*/, "", v); add(v); next
      }
      if (inlist && line !~ /^[[:space:]]*$/) { inlist = 0; curkey = ""; curval = "" }
    }
    END {
      if (id != "") { flush_list(); CARD[id] = 1 }
      for (k in B)  { split(k, p, "\x1f")
                      if (!(p[2] in CARD))            print "    ⚠ " p[1] " declares blocks: [" p[2] "] — " p[2] " is not on this board (a DANGLING reference, not an asymmetry: check the id)"
                      else if (!((p[2] "\x1f" p[1]) in BB)) print "    ⚠ " p[1] " declares blocks: [" p[2] "] and " p[2] " does not declare blocked_by: [" p[1] "] — either card may be the stray one" }
      for (k in BB) { split(k, p, "\x1f")
                      if (!(p[2] in CARD))            print "    ⚠ " p[1] " declares blocked_by: [" p[2] "] — " p[2] " is not on this board (a DANGLING reference, not an asymmetry: check the id)"
                      else if (!((p[2] "\x1f" p[1]) in B))  print "    ⚠ " p[1] " declares blocked_by: [" p[2] "] and " p[2] " does not declare blocks: [" p[1] "] — either card may be the stray one" }
      n = 0; for (c in CARD) n++
      printf "    %d card(s) read, %d dependency declaration(s)\n", n, DECL
    }
  ' "${d_files[@]}" 2>/dev/null || true)"
  # AN UNDECLARED BOARD AND A SYMMETRIC BOARD MUST NOT PRINT THE SAME THING. The count
  # line above is what separates "checked and found nothing wrong" from "there was
  # nothing to check" — a reading whose subject is ABSENT still prints, naming what was
  # absent (contracts/drift-report.md § 4).
  printf '%s\n' "$i_out" | sed '/^$/d'
  # NO `drift=1` HERE, DELIBERATELY, AND DO NOT ADD ONE. See the ruling in the header.
fi

echo
if [ "$drift" -eq 0 ]; then
  echo "── board-drift: clean ✓"
else
  echo "── board-drift: findings above ⚠ (informational; exit 0 by convention)"
fi
exit 0
