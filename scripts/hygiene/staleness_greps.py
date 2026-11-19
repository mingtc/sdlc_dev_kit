#!/usr/bin/env python3
# KIT-CLASS: KIT — the staleness-signal greps over the live reading path; advisory, never a
# gate. See process/EXTRACTION.md.
# =============================================================================
# scripts/hygiene/staleness_greps.py — THE STALENESS SIGNALS.
#
# MODALITY (the contract): two greps, and their output is SUSPICIONS, not findings. Report
# only — it writes nothing, deletes nothing, moves nothing, makes no network call, and needs no
# dependency (standard library only).
#
#   SHAPE (i)  SUPERSEDED-CONCLUSION — a sentence restating a conclusion a later change
#              narrowed: an open/absent/unstarted claim that NAMES an artifact which now
#              EXISTS, or an issue that is now in `progress/done/`.
#   SHAPE (ii) UNMEASURED-CLAIM-NOW-MEASURED — a MEASURE-FIRST / "not yet measured" /
#              "does not exist yet" claim whose named verdict artifact or issue HAS since landed.
#
# WHAT IS READ AS A CLAIM: the phrase and the landed artifact in the SAME SENTENCE of one line;
# a table row is one sentence, whatever cells hold the two. A phrase between a pair of double
# quotes (straight or curly) on its line is a MENTION of the phrase, not a claim, and is skipped;
# backticks, *italics* and **bold** are still claims, since a status line writes its state that
# way. The cost: a claim whose artifact is named only in an earlier sentence, or a real claim
# quoted on purpose, is not reported; an abbreviation such as "e.g. " ends a sentence early; and
# a stray " (an inch mark) pairs with the next " on its line, so a claim between the two is read
# as a mention. A quote is never paired across lines, so an unclosed one hides nothing past it.
#
# NO BASE RATE SHIPS. How often these greps cry wolf depends on the tree, and a figure from
# another project reads as a rate for this one. Adjudicate the first report, count the false
# positives, and record that rate with its date; an instrument that does not say how often it
# cries wolf gets wired into a gate.
#
# THE SCOPE IS THE LIVE READING PATH: root-level prose, `process/**`, the role docs,
# `requirements/*`, and the top level of `dev/` plus its handoffs — the files a fresh agent is
# TOLD to read. Ledger prose deep in an evidence tree is out of scope by design, and so are the
# HISTORICAL RECORDS below, which quote dated claims that were true when written. Each exclusion
# is a whole file with a reason, never a per-line silencer.
#
# THE CHECKLIST THIS INSTRUMENT SERVES: `process/hygiene-checklist.md` (the "decay" shape).
# =============================================================================
"""The two staleness-signal greps, reported as suspicions. Stdlib only."""

from __future__ import annotations

import argparse
import bisect
import re
import sys
from pathlib import Path

# NO BYTECODE CACHE, DELIBERATELY — see citation_index.py's header for the full statement and
# the importer contract. Set BEFORE the sibling import below.
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from citation_index import REPO_ROOT, iter_files, print_blind_spots, run_instrument, walk_blind_spots  # noqa: E402

OPEN_CLAIM = re.compile(
    r"\b(still open|unstarted|not yet (?:started|built|landed|shipped|written)|"
    r"is unrun|no such file|does not exist(?: yet)?|has not (?:landed|shipped)|"
    r"remains? (?:open|unbuilt)|to be (?:built|written))\b", re.I)
UNMEASURED_CLAIM = re.compile(
    r"\b(measure[- ]first|unmeasured|not yet measured|no measurement|"
    r"awaiting measurement|pending measurement)\b", re.I)
# A sentence ends at . ! or ? followed by white space.
SEGMENT_END = re.compile(r"[.!?]\s")
# A phrase inside a pair of double quotes on its line is mentioned, not claimed.
MENTION_SPAN = re.compile(
    r'"[^"]*"'
    r"|\u201c[^\u201d]*\u201d")


def _segment(line: str, starts: list, at: int) -> str:
    """The sentence of `line` that holds offset `at`."""
    i = bisect.bisect_right(starts, at) - 1
    end = starts[i + 1] if i + 1 < len(starts) else len(line)
    return line[starts[i]:end]


def _id_prefixes(root: Path):
    """The issue / PRD prefixes, READ FROM THE SEAM (scripts/config.sh) rather than hardcoded.

    A hardcoded prefix here is the same defect the board scripts refuse: it silently stops
    matching the day a project changes it, and this instrument then reports zero suspicions
    forever — the quietest possible failure. Falls back to a generic shape when the seam cannot
    be read, and SAYS so via the returned flag.
    """
    text = ""
    cfg = root / "scripts" / "config.sh"
    if cfg.exists():
        text = cfg.read_text(encoding="utf-8", errors="replace")
    keys = ("ISSUE_PREFIX", "PRD_PREFIX")
    found, unread = [], []
    for key in keys:
        match = re.search(rf'^{key}="\$\{{{key}:-([A-Za-z0-9]+)\}}"', text, re.M)
        if match:
            found.append(match.group(1))
        else:
            unread.append(key)
    # DERIVED MEANS *EVERY* KEY: a partial read returns what it found with the flag False, so the
    # caller can tell a real zero from a blind one. Reachable: the initializer can stamp a prefix
    # with a character outside this class.
    if found and not unread:
        return "|".join(found), True
    if found:
        # Use what was read — a partial pattern still finds SOME ids — but say it is partial.
        return "|".join(found), False
    return "[A-Z]{2,6}", False


def artifact_pattern(root: Path):
    prefixes, derived = _id_prefixes(root)
    return re.compile(rf"\b((?:{prefixes})-\d{{3}})\b|([\w./-]+\.(?:md|txt|sh|py|toml|json|yaml))"), derived


SCOPE_EXACT_DIRS = ("process/", ".claude/roles/")
# Historical records: dated claims that were true when written and are never edited. A whole
# file with a reason. EDIT THIS for your project's equivalents.
HISTORICAL_RECORDS = ("ARCHIVE.md", "progress.md", "CHANGELOG.md", "RELEASE_NOTES.md", "NOTES.md")


def in_scope(rel: str) -> bool:
    if not rel.endswith((".md", ".txt")) or rel in HISTORICAL_RECORDS:
        return False
    if "/" not in rel:
        return True
    if rel.startswith(SCOPE_EXACT_DIRS):
        return True
    if rel.startswith("requirements/") and rel.count("/") == 1:
        return True
    return rel.startswith("dev/") and rel.count("/") == 1 or rel.startswith("dev/handoffs/")


def landed(root: Path, token: str, prefixes: str) -> str:
    """Why the named artifact contradicts the claim, or '' if it does not."""
    if re.fullmatch(rf"(?:{prefixes})-\d{{3}}", token):
        hits = sorted((root / "progress" / "done").glob(f"{token}-*.md"))
        return f"{token} is in progress/done/ ({hits[0].name})" if hits else ""
    path = root / token
    if path.exists() and path.is_file():
        return f"{token} exists on disk ({path.stat().st_size} B)"
    return ""


def survey(root: Path = REPO_ROOT):
    artifact, derived = artifact_pattern(root)
    prefixes, _ = _id_prefixes(root)
    rows = []
    for rel in iter_files(root):
        if not in_scope(rel):
            continue
        for number, line in enumerate((root / rel).read_text(encoding="utf-8",
                                                             errors="replace").splitlines(), 1):
            starts = [0] + [m.end() for m in SEGMENT_END.finditer(line)]
            mentions = [m.span() for m in MENTION_SPAN.finditer(line)]
            for shape, pattern in (("superseded-conclusion", OPEN_CLAIM),
                                   ("unmeasured-claim-now-measured", UNMEASURED_CLAIM)):
                row = None
                for claim in pattern.finditer(line):
                    if any(a <= claim.start() and claim.end() <= b for a, b in mentions):
                        continue
                    for match in artifact.finditer(_segment(line, starts, claim.start())):
                        token = match.group(1) or match.group(2)
                        why = landed(root, token, prefixes)
                        if why:
                            row = {"shape": shape, "path": rel, "line": number,
                                   "claim": claim.group(0), "artifact": token,
                                   "why": why, "text": line.strip()[:160]}
                            break
                    if row:
                        rows.append(row)
                        break
    return rows, derived


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shape", choices=("superseded-conclusion",
                                            "unmeasured-claim-now-measured"))
    parser.add_argument("--root", default=str(REPO_ROOT), help="tree to measure (default: this repo)")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    root = Path(args.root)
    rows, derived = survey(root)
    rows = [r for r in rows if not args.shape or r["shape"] == args.shape]
    if args.json:
        import json

        print(json.dumps({"blind_spots": walk_blind_spots(), "suspicions": rows,
                          "id_prefixes_derived_from_seam": derived}, indent=2))
        return 0
    print(f"staleness greps: {len(rows)} SUSPICION(S) on the live reading path")
    print_blind_spots()
    if not derived:
        print("NOTE: the issue-id prefixes could NOT be read from scripts/config.sh — falling")
        print("      back to a generic shape. Fix the seam or this arm under-reports silently.")
    print("BASE RATE — none shipped: adjudicate this report, count its false positives and record")
    print("that rate with its date before trusting a quiet run.")
    print()
    for row in rows:
        print(f"[{row['shape']}] {row['path']}:{row['line']}")
        print(f"    claim: {row['claim']!r}   artifact: {row['artifact']}")
        print(f"    contradicted by: {row['why']}")
        print(f"    {row['text']}")
    if not rows:
        print("(no suspicion)")
    return 0


if __name__ == "__main__":
    sys.exit(run_instrument(main, "staleness_greps"))
