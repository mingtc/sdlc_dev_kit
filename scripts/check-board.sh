#!/usr/bin/env bash
# KIT-CLASS: KIT — board drift report; reads the status folders only. See process/EXTRACTION.md.
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
#   (e) [Role]-prefix scan of recent trunk commits; (f) .kanban-wt trunk-divergence.
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

drift=0
echo "── check-board.sh — board-drift report @ $(date +%Y-%m-%dT%H:%M:%S)"
echo "   repo: $REPO_ROOT"

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
echo "[a] Folder vs last-Activity drift (active columns):"
a_hits=0
for folder in todo in_progress dev_complete qa_complete blocked; do
  dir="$REPO_ROOT/progress/$folder"
  [ -d "$dir" ] || continue
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
[ "$a_hits" -eq 0 ] && echo "    ✓ none (every judgeable last-Activity entry matches its folder)"

# ---------------------------------------------------------------------------
# (b) qa_complete/ column depth vs the archive threshold.
# ---------------------------------------------------------------------------
echo
qc_count=0
if [ -d "$REPO_ROOT/progress/qa_complete" ]; then
  for f in "$REPO_ROOT"/progress/qa_complete/*.md; do
    [ -e "$f" ] && qc_count=$((qc_count+1))
  done
fi
if [ "$qc_count" -gt "$QA_COMPLETE_THRESHOLD" ]; then
  echo "[b] qa_complete/ depth: $qc_count / $QA_COMPLETE_THRESHOLD threshold  ⚠ over — run ./scripts/archive.sh --apply"
  drift=1
else
  echo "[b] qa_complete/ depth: $qc_count / $QA_COMPLETE_THRESHOLD threshold  ✓"
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
pmd="$REPO_ROOT/progress.md"
if [ -f "$pmd" ]; then
  if grep -qE '^##[[:space:]]+Log' "$pmd"; then
    logbytes="$(awk '
      /^##[[:space:]]/ { if (inlog) exit; if ($0 ~ /^##[[:space:]]+Log/) inlog=1 }
      inlog { print }
    ' "$pmd" | wc -c | tr -d ' ')"
    if [ "$logbytes" -gt "$PROGRESS_LOG_BYTE_THRESHOLD" ]; then
      echo "[c] progress.md § Log SLICE: $logbytes / $PROGRESS_LOG_BYTE_THRESHOLD bytes  ⚠ over — run ./scripts/archive-progress.sh"
      drift=1
    else
      echo "[c] progress.md § Log SLICE: $logbytes / $PROGRESS_LOG_BYTE_THRESHOLD bytes  ✓"
    fi
  else
    echo "[c] progress.md § Log SLICE: no '## Log' heading found  (skipped)"
  fi
  wholebytes="$(wc -c < "$pmd" | tr -d ' ')"
  if [ "$wholebytes" -gt "$PROGRESS_WHOLE_FILE_BYTE_THRESHOLD" ]; then
    echo "[c] progress.md WHOLE FILE: $wholebytes / $PROGRESS_WHOLE_FILE_BYTE_THRESHOLD bytes  ⚠ over (ADVISORY, does not fail the board) — a rotation is due, see ./scripts/archive-progress.sh"
  else
    echo "[c] progress.md WHOLE FILE: $wholebytes / $PROGRESS_WHOLE_FILE_BYTE_THRESHOLD bytes  ✓"
  fi
else
  echo "[c] progress.md: not found  (skipped)"
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
echo "[d] Frontmatter id integrity (all six columns, from STATUS_FOLDERS):"
d_files=(); d_hits=0
IFS='|' read -r -a d_cols <<< "$STATUS_FOLDERS"
for folder in "${d_cols[@]}"; do
  d_dir="$REPO_ROOT/progress/$folder"
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
               -v root="$REPO_ROOT/" -v dq='"' -v sq="'" '
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
[ "$d_hits" -eq 0 ] && echo "    ✓ none (every ${ISSUE_ID_KEY}: unique across all six columns and matching its filename)"
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
# ---------------------------------------------------------------------------
echo
ROLE_PREFIXES="$(sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p" "$REPO_ROOT/scripts/githooks/commit-msg" 2>/dev/null | head -1)"
# THE DERIVATION ABOVE IS THE PATTERN TO PRESERVE; the literal below is only what
# is used when the hook cannot be read — and it is the part that drifts (it once
# fell a role behind the hook it mirrors), so correct IT, never replace the
# derivation with it.
[ -z "$ROLE_PREFIXES" ] && ROLE_PREFIXES='PM|Dev|QA|Refactorer|UIDesigner|Orchestrator|Architect'
echo "[e] [Role]-prefix scan (last $ROLE_SCAN_N commits, squash-aware):"
role_hits=0
if git -C "$REPO_ROOT" rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
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
  done < <(git -C "$REPO_ROOT" log --no-color --format='%H|%P' -n "$ROLE_SCAN_N" 2>/dev/null)
fi
[ "$role_hits" -eq 0 ] && echo "    ✓ every scanned subject carries a [Role] prefix"

# ---------------------------------------------------------------------------
# (f) .kanban-wt trunk-divergence. kwt_sync's `reset --hard <remote>/<trunk>`
#     silently discards any commit that is in .kanban-wt's HEAD but not yet on the
#     remote — the exact state a process death BETWEEN the commit and the push
#     leaves behind (kanban-worktree.sh's own sync note: "an unpushed local COMMIT
#     is NOT caught here … it is reset on the next sync by design"). Surface it
#     before the next op destroys it. No-ops cleanly (skip) when .kanban-wt is
#     absent or the remote is unreachable, so it can't blow the <2s budget.
#     Informational — exit 0 by convention.
#
#     THE TRUNK CHAIN IS RESOLVED THE SAME WAY kwt_resolve DOES, and the last link
#     is READ FROM THAT LIBRARY rather than re-typed here — a re-typed branch name
#     is the drift this file's greppable-defaults contract exists to prevent. This
#     is read-only, so it degrades to a SKIP line rather than warning: the loud
#     warning belongs to the ops that actually write (see kwt_resolve).
# ---------------------------------------------------------------------------
echo
kwt_dir="$REPO_ROOT/.kanban-wt"
if [ -d "$kwt_dir" ] && git -C "$kwt_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  remote="${KWT_REMOTE:-origin}"
  def="$(git -C "$REPO_ROOT" symbolic-ref --short "refs/remotes/$remote/HEAD" 2>/dev/null | sed "s|^$remote/||" || true)"
  [ -z "$def" ] && def="$(git -C "$REPO_ROOT" config --get init.defaultBranch 2>/dev/null || true)"
  if [ -z "$def" ]; then
    def="$(sed -n 's/^KWT_TRUNK_LAST_RESORT="\${KWT_TRUNK_LAST_RESORT:-\([A-Za-z0-9._\/-]*\)}"/\1/p' \
             "$REPO_ROOT/scripts/lib/kanban-worktree.sh" 2>/dev/null | head -1)"
    echo "[f] .kanban-wt divergence: the trunk is UNCONFIRMED ($remote/HEAD and init.defaultBranch are both unset)"
    echo "      — falling back to the kit's last-resort '${def:-<unknown>}'. Settle it: git remote set-head $remote <your-trunk>"
  fi
  if [ -n "$def" ] && git -C "$kwt_dir" rev-parse --verify --quiet "$remote/$def" >/dev/null 2>&1; then
    ahead="$(git -C "$kwt_dir" rev-list --count "$remote/$def..HEAD" 2>/dev/null || echo 0)"
    if [ "${ahead:-0}" -gt 0 ]; then
      echo "[f] .kanban-wt divergence: HEAD is $ahead commit(s) ahead of $remote/$def  ⚠ the next op's 'reset --hard $remote/$def' would DISCARD them"
      echo "      Fix: push them — git -C '$kwt_dir' push $remote HEAD:$def — or re-run the op that owns the commit."
      drift=1
    else
      echo "[f] .kanban-wt divergence: in sync with $remote/$def  ✓"
    fi
  else
    echo "[f] .kanban-wt divergence: $remote/${def:-<unresolved trunk>} unavailable (offline?)  (skipped)"
  fi
else
  echo "[f] .kanban-wt divergence: no registered worktree  (skipped)"
fi

echo
if [ "$drift" -eq 0 ]; then
  echo "── board-drift: clean ✓"
else
  echo "── board-drift: findings above ⚠ (informational; exit 0 by convention)"
fi
exit 0
