#!/usr/bin/env bash
# KIT-CLASS: KIT — board drift report; reads the status folders, the log, recent history and the
#   publication homes, each FROM A NAMED SOURCE it prints. See process/EXTRACTION.md.
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
#       with a day of unpushed rulings beside it.
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
ROLE_SCAN_N=20        # how many recent trunk commits section (e) scans
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
#     and can be huge — skipped for the <2s budget). The "declared status" is the
#     LAST folder token that appears in a STRUCTURED context on the last Activity
#     bullet: a transition arrow `→ <folder>` or a backticked `` `<folder>` ``
#     (optionally with a trailing slash). Free-form notes with no such token are
#     un-judgeable → skipped (no false positives). A bare `<folder>/`
#     path-substring alternative was DROPPED: it false-positived on an incidental
#     path MENTION like `supersedes progress/done/<PREFIX>-379-old.md`.
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
    declared="$(printf '%s' "$last" \
      | grep -oE "(→[[:space:]]*(${STATUS_FOLDERS}))|(\`(${STATUS_FOLDERS})/?\`)" 2>/dev/null \
      | grep -oE "(${STATUS_FOLDERS})" 2>/dev/null | tail -1 || true)"
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
#     subjects (Merge/Revert/Squash/autosquash) are exempt — mirror commit-msg's list.
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
  role_rev="$CB_REF"
else
  role_rev="HEAD"
fi
echo "[e] [Role]-prefix scan (last $ROLE_SCAN_N commits of $role_rev, squash-aware) — prefixes $role_src:"
role_hits=0
role_scanned=0
if git -C "$REPO_ROOT" rev-parse --verify --quiet "$role_rev" >/dev/null 2>&1; then
  while IFS='|' read -r sha parents; do
    [ -z "$sha" ] && continue
    # shellcheck disable=SC2086
    set -- $parents                       # word-split the space-separated parent list
    if [ "$#" -ge 2 ]; then
      target="$2"                         # merge commit → parent 2 carries the squashed [Role] subject
    else
      target="$sha"                       # non-merge → its own subject
    fi
    subj="$(git -C "$REPO_ROOT" log -1 --format=%s "$target" 2>/dev/null || true)"
    [ -z "$subj" ] && continue
    role_scanned=$((role_scanned+1))
    case "$subj" in
      "Merge branch "*|"Merge remote-tracking branch "*|"Merge pull request "*|"Merge tag "*|"Merge commit "*) continue ;;
      "Revert \""*|"Revert '"*) continue ;;
      "Squash"*) continue ;;
      "fixup! "*|"squash! "*|"amend! "*) continue ;;
    esac
    if ! printf '%s' "$subj" | grep -qE "^\[(${ROLE_PREFIXES})\] "; then
      echo "    ⚠ ${target:0:9} subject lacks a [Role] prefix: $subj"
      role_hits=$((role_hits+1)); drift=1
    fi
  done < <(git -C "$REPO_ROOT" log --no-color --format='%H|%P' -n "$ROLE_SCAN_N" "$role_rev" 2>/dev/null)
else
  # NO HISTORY IS A SKIP. This used to fall through the `if` and print
  # "✓ every scanned subject carries a [Role] prefix" over ZERO subjects — a green
  # from an empty set, which is the shape drift-report.md § 2 forbids by name.
  echo "    – $role_rev does not resolve — no history to scan  (skipped)"
  role_scanned=-1
fi
if [ "$role_scanned" -eq 0 ]; then
  echo "    – $role_rev resolved but yielded no inspectable subject  (skipped)"
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
    [ "${f_behind:-0}" -gt 0 ] && echo "           ($f_behind behind is a STALE VIEW, not lost work — pull when convenient.)"
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

echo
if [ "$drift" -eq 0 ]; then
  echo "── board-drift: clean ✓"
else
  echo "── board-drift: findings above ⚠ (informational; exit 0 by convention)"
fi
exit 0
