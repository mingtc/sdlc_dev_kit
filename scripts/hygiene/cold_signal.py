#!/usr/bin/env python3
# KIT-CLASS: KIT — the git cold-signal query over this tree's own history; advisory, never a
# gate. See process/EXTRACTION.md.
# =============================================================================
# scripts/hygiene/cold_signal.py — THE GIT COLD-SIGNAL QUERY.
#
# MODALITY (the contract): the conjunction of three independent signals —
#   SINGLE-COMMIT (added once, never amended)  AND  COLD (untouched beyond the horizon)  AND
#   ZERO EXACT REFERRERS (nobody names the file itself).
# It prints a suspicion set, with the EXACT and ANCESTOR referrer columns side by side and
# never summed. Report only: it writes nothing, deletes nothing, moves nothing, makes no
# network call, needs no dependency (standard library plus `git log` on THIS working copy — no
# remote is contacted).
#
# THE CORPUS THIS WALKS, STATED BECAUSE A SILENT CORPUS IS HOW A COLD SCAN LIES. The walk is
# `citation_index.iter_files()` — every file in this working copy except git's own store, build
# output, dependency trees and caches (`citation_index.SKIP_DIRS`). On top of that this
# instrument applies a DEFAULT PREFIX EXCLUSION SET, the same one `duplication_scan.py` uses:
#   progress/    — the board. Closed-issue bodies are a FLOOR class, not decay: a done issue is
#                  written once and never touched again BY DESIGN, so it is single-commit and
#                  cold by construction and every one of them scores as a suspicion.
#   <code>/      — source and tests. Coldness there is a code question, not a hygiene one; the
#                  test suite already owns them.
#   <build>/     — build output, not authored.
# `--exclude PREFIX` (repeatable) REPLACES that set; `--no-excludes` walks the whole tree, so the
# un-excluded view stays ONE FLAG AWAY and nothing is hidden.
#
# THE PARAMETER, AND ITS DEFAULT, STATED HERE: `--days` is the coldness horizon and defaults
# to 14 ("cold beyond two weeks").
#
# CALIBRATION — AND WHY ANOTHER PROJECT'S FIGURE IS NOT A BASELINE FOR YOUR RUN. The donor
# project's census recorded 185 files / 1,473,757 B over ITS OWN 1,799-candidate scope. THIS
# INSTRUMENT DOES NOT WALK THAT SCOPE, so the two numbers are NOT COMPARABLE and a difference
# between them is NOT evidence of decay — the same discipline duplication_scan.py applies to
# itself. What travels is the METHOD, not the number:
#   • run it BOTH ways (`--no-excludes` and default) and print both totals;
#   • name the single biggest contributor to the gap, because in the donor's tree ONE directory
#     (the archived board) was 78.3% of the un-excluded byte total, and without that sentence the
#     whole-tree figure reads as decay when it is the floor class working as designed;
#   • write your two numbers down WITH THE DATE, and re-measure before quoting either.
#
# WHY THE THIRD CONJUNCT IS "EXACT" AND NOT "ANY". Almost the whole suspicion set is saved by
# ANCESTOR-directory citations — the exact-vs-ancestor distinction doing its job. Collapse the
# two columns and this instrument reports either everything or nothing; that is why
# citation_index.py refuses to collapse them.
#
# IT MUST NEVER BE INVOKED FROM A TEST. History is not a fixture, and a guard that reads live git
# is nondeterministic by construction. This is a seat-run instrument, not a guard.
#
# THE CHECKLIST THIS INSTRUMENT SERVES: `process/hygiene-checklist.md` (the "Cold evidence" shape).
# =============================================================================
"""Instrument 3 — single-commit AND cold AND zero-exact-referrer files. Read-only, stdlib."""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

# NO BYTECODE CACHE, DELIBERATELY — see citation_index.py's header for the full statement and
# the importer contract. Set BEFORE the sibling import below.
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from citation_index import (  # noqa: E402
    REPO_ROOT, DEFAULT_EXCLUDED_PREFIXES, Index, print_blind_spots, run_instrument, walk_blind_spots,
)

DEFAULT_DAYS = 14
# The default prefix exclusion set is IMPORTED, not redefined — it lives once, in
# citation_index.py, which every instrument here already imports. Replaceable with --exclude,
# clearable with --no-excludes; never silently applied. EDIT IT THERE, not here.


class HistoryUnavailable(RuntimeError):
    """`git log` could not run on this tree — so NOTHING was measured.

    Deliberately NOT raised for an empty history: a repository with no commits is a measured
    answer, and this exception means the measurement never happened. That distinction is
    `contracts/verify-gate.md` § 3's, and the vocabulary below is `verify.sh`'s: UNRUNNABLE is
    not FAIL, and a report that spells them the same way sends the reader to debug a tree that
    may be perfectly healthy.
    """

    # The remedy is passed IN, never inferred here: the two ways this fires need opposite
    # advice, and telling a reader whose git is missing to run `git init` is the same defect
    # one layer up — a true sentence aimed at the wrong reader.
    def __init__(self, root, rc, said, remedy):
        self.root, self.rc, self.said, self.remedy = root, rc, said, remedy
        self.asked = f"git -C {root} log --no-merges --format=%x01%ct --name-only"
        super().__init__(f"git log could not run in {root}")


def git_history(root: Path):
    """``path -> (commit_count, last_unix_ts)`` from ONE local history walk. No remote."""
    try:
        proc = subprocess.run(
            ["git", "-C", str(root), "log", "--no-merges", "--format=%x01%ct", "--name-only"],
            capture_output=True, text=True, check=True,
        )
    except subprocess.CalledProcessError as exc:
        raise HistoryUnavailable(
            root, exc.returncode, (exc.stderr or "").strip(),
            "this instrument reads THIS working copy's own history (see the header). An unpacked "
            "release or an export is not a repository — run it inside a clone, or `git init` first.",
        ) from None
    except FileNotFoundError:
        # git absent entirely. The kit's floor assumes it, so this is unusual — and a traceback
        # about a missing binary is exactly as unhelpful as one about a missing repository.
        raise HistoryUnavailable(
            root, None, "git is not on PATH",
            "install git, or put it on PATH. The kit's floor assumes git; nothing here can "
            "substitute for it, and no other instrument in this directory needs it.",
        ) from None
    stats: dict = {}
    stamp = 0
    for line in proc.stdout.splitlines():
        if line.startswith("\x01"):
            stamp = int(line[1:] or 0)
        elif line.strip():
            count, last = stats.get(line, (0, 0))
            stats[line] = (count + 1, max(last, stamp))
    return stats


def survey(root: Path = REPO_ROOT, days: int = DEFAULT_DAYS,
           excluded: tuple = DEFAULT_EXCLUDED_PREFIXES):
    index = Index(root)
    stats = git_history(root)
    horizon = time.time() - days * 86400
    rows = []
    for rel in index.files:
        if excluded and rel.startswith(tuple(excluded)):
            continue
        commits, last = stats.get(rel, (0, 0))
        if commits != 1 or last == 0 or last >= horizon:
            continue
        exact, ancestor = index.referrers(rel)
        if exact:
            continue
        try:
            size = (root / rel).stat().st_size
        except OSError:
            continue
        rows.append({"path": rel, "bytes": size, "age_days": int((time.time() - last) / 86400),
                     "exact_n": 0, "anc_n": len(ancestor)})
    rows.sort(key=lambda r: (r["anc_n"], -r["bytes"]))
    return rows


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--days", type=int, default=DEFAULT_DAYS,
                        help=f"coldness horizon in days (default {DEFAULT_DAYS})")
    parser.add_argument("--exclude", action="append", metavar="PREFIX",
                        help="repo-relative prefix to exclude; repeatable. REPLACES the default "
                             f"set ({' '.join(DEFAULT_EXCLUDED_PREFIXES)}).")
    parser.add_argument("--no-excludes", action="store_true",
                        help="walk the whole tree — the un-excluded view, no default excludes")
    parser.add_argument("--root", default=str(REPO_ROOT), help="tree to measure (default: this repo)")
    parser.add_argument("--limit", type=int, default=40, help="rows printed (0 = all)")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    if args.no_excludes:
        excluded: tuple = ()
    elif args.exclude:
        excluded = tuple(args.exclude)
    else:
        excluded = DEFAULT_EXCLUDED_PREFIXES
    try:
        rows = survey(root=Path(args.root), days=args.days, excluded=excluded)
    except HistoryUnavailable as exc:
        # THE REFUSAL, in verify.sh's vocabulary. Human text on stderr either way, so a caller
        # redirecting stdout still sees why.
        print(f"cold_signal.py: could NOT RUN — {exc}. NOTHING was measured.", file=sys.stderr)
        print("  this is not 'no cold files': the instrument never ran.", file=sys.stderr)
        print(f"  asked:     {exc.asked}", file=sys.stderr)
        print(f"  git said:  {exc.said or '(no message)'}"
              + (f"  (rc={exc.rc})" if exc.rc is not None else ""), file=sys.stderr)
        print(f"  remedy:    {exc.remedy}", file=sys.stderr)
        if args.json:
            import json

            # A VALID OBJECT THAT SAYS IT DID NOT RUN, and it carries NO data keys — no `rows`,
            # no `files`, no `bytes`. Both alternatives are worse for the one reader who cannot
            # infer anything: empty stdout is indistinguishable from a successful empty result
            # (instruments.md § A.9 — read the STATUS, never the output shape), and `"rows": []`
            # asserts there are no cold files, which is a measurement nobody made. Omitting the
            # keys makes a consumer that skipped the exit code fail loudly on the lookup instead.
            print(json.dumps({"unrunnable": {
                "instrument": "cold_signal", "reason": str(exc), "asked": exc.asked,
                "git_rc": exc.rc, "git_said": exc.said, "remedy": exc.remedy,
            }}, indent=2))
        return 2
    total = sum(row["bytes"] for row in rows)
    if args.json:
        import json

        print(json.dumps({"blind_spots": walk_blind_spots(), "days": args.days, "excluded": list(excluded), "files": len(rows),
                          "bytes": total, "rows": rows}, indent=2))
        return 0
    print(f"cold signal: single-commit AND cold (>{args.days}d) AND zero EXACT referrers")
    print(f"corpus: the whole working copy minus {list(excluded) or '(nothing — --no-excludes)'}.")
    print_blind_spots()
    print("Run it BOTH ways and write down both totals with today's date — a cold-file count")
    print("without its corpus and its date is a claim, not a measurement.")
    print(f"{len(rows)} file(s), {total} B. A row is a SUSPICION, not a verdict — most are "
          "saved by an ANCESTOR citation.")
    print("Sorted by ANCESTOR referrers ascending: the top rows are the least-cited.")
    print(f"{'EXACT':>7} {'ANC':>7} {'BYTES':>9} {'AGE_D':>6}  PATH")
    shown = rows if args.limit == 0 else rows[: args.limit]
    for row in shown:
        print(f"{row['exact_n']:>7} {row['anc_n']:>7} {row['bytes']:>9} "
              f"{row['age_days']:>6}  {row['path']}")
    if len(shown) < len(rows):
        print(f"... {len(rows) - len(shown)} more (--limit 0 for all)")
    return 0


if __name__ == "__main__":
    sys.exit(run_instrument(main, "cold_signal"))
