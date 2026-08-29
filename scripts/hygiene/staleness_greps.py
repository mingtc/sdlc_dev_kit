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
#              EXISTS, or an issue that is now in `progress/done/`. The donor's specimen was one
#              line of a front-door README reading "Still open: <area> (unstarted)" while five
#              surfaces of that area had shipped.
#   SHAPE (ii) UNMEASURED-CLAIM-NOW-MEASURED — a MEASURE-FIRST / "not yet measured" /
#              "does not exist yet" claim whose named verdict artifact or issue HAS since landed.
#
# THE BASE RATE IS PRINTED WITH EVERY REPORT, and that is the copyable part: an instrument that
# does not say how often it cries wolf gets wired into a gate by somebody. Each figure is carried
# WITH ITS DATE AND SOURCE and is never restated as present-tense fact. THE SHIPPED FIGURES BELOW
# ARE ANOTHER PROJECT'S, on one day, and are labelled as such — replace them with yours the first
# time you run this and adjudicate the output.
#
# THE SCOPE IS THE LIVE READING PATH, stated: root-level prose, `process/**`, the role docs,
# `requirements/*`, and the top level of `dev/` plus its handoffs — the files a fresh agent is
# TOLD to read, where a wrong sentence does real damage. Ledger prose deep in an evidence tree is
# out of scope by design, not by oversight. So are the HISTORICAL RECORDS listed below: an
# archive index, a running log and a changelog quote dated claims that were true when written and
# are never edited afterwards. In the donor's first run those four files alone were 70 of 96 raw
# hits. Each exclusion is a whole file with a reason, never a per-line silencer.
#
# THE CHECKLIST THIS INSTRUMENT SERVES: `process/hygiene-checklist.md` (the "decay" shape).
# =============================================================================
"""Instrument 4 — the two staleness-signal greps, reported as suspicions. Stdlib only."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# NO BYTECODE CACHE, DELIBERATELY — see citation_index.py's header for the full statement and
# the importer contract. Set BEFORE the sibling import below.
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from citation_index import REPO_ROOT, iter_files, print_blind_spots, run_instrument, walk_blind_spots  # noqa: E402

# ── PARAMETER: THE BASE RATE. Carried with date + source, NOT re-measured here — quoting one of
#    these as present tense is the exact defect this instrument exists to find. REPLACE THESE
#    THREE with your own measurements, each with its own date and source, the first time you run
#    this and adjudicate the output. Until you do, they are labelled as another project's.
BASE_RATE = [
    ("a donor project's staleness sweep, as of its run date",
     "24 flags raised, 9 actively wrong — a ~38% true-positive rate on a hand-run of these "
     "two shapes"),
    ("the same sweep's CLEAN NEGATIVES section",
     "four named precedent chains traced forward found ZERO stale conclusions, and the one "
     "MEASURE-FIRST item in the charter was CORRECTLY unmeasured — these greps produce "
     "suspicions, not findings"),
    ("the same project's census, on cited-but-missing paths",
     "of 192 cited-but-missing paths, ~185 were by design and about 7 genuinely dead — a "
     "blanket dead-pointer guard would have reddened the front door"),
]

OPEN_CLAIM = re.compile(
    r"\b(still open|unstarted|not yet (?:started|built|landed|shipped|written)|"
    r"is unrun|no such file|does not exist(?: yet)?|has not (?:landed|shipped)|"
    r"remains? (?:open|unbuilt)|to be (?:built|written))\b", re.I)
UNMEASURED_CLAIM = re.compile(
    r"\b(measure[- ]first|unmeasured|not yet measured|no measurement|"
    r"awaiting measurement|pending measurement)\b", re.I)


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
    found = []
    for key in ("ISSUE_PREFIX", "PRD_PREFIX"):
        match = re.search(rf'^{key}="\$\{{{key}:-([A-Za-z0-9]+)\}}"', text, re.M)
        if match:
            found.append(match.group(1))
    if found:
        return "|".join(found), True
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
            for shape, pattern in (("superseded-conclusion", OPEN_CLAIM),
                                   ("unmeasured-claim-now-measured", UNMEASURED_CLAIM)):
                claim = pattern.search(line)
                if not claim:
                    continue
                for match in artifact.finditer(line):
                    token = match.group(1) or match.group(2)
                    why = landed(root, token, prefixes)
                    if why:
                        rows.append({"shape": shape, "path": rel, "line": number,
                                     "claim": claim.group(0), "artifact": token,
                                     "why": why, "text": line.strip()[:160]})
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

        print(json.dumps({"blind_spots": walk_blind_spots(), "suspicions": rows, "base_rate": BASE_RATE,
                          "id_prefixes_derived_from_seam": derived}, indent=2))
        return 0
    print(f"staleness greps: {len(rows)} SUSPICION(S) on the live reading path")
    print_blind_spots()
    if not derived:
        print("NOTE: the issue-id prefixes could NOT be read from scripts/config.sh — falling")
        print("      back to a generic shape. Fix the seam or this arm under-reports silently.")
    print("BASE RATE — carried with date and source, not re-measured here, and NOT this")
    print("project's until you replace it with your own:")
    for source, figure in BASE_RATE:
        print(f"  · {figure}  [{source}]")
    print()
    for row in rows:
        print(f"[{row['shape']}] {row['path']}:{row['line']}")
        print(f"    claim: {row['claim']!r}   artifact: {row['artifact']}")
        print(f"    contradicted by: {row['why']}")
        print(f"    {row['text']}")
    if not rows:
        print("(no suspicion — which, at the base rate above, is the expected result)")
    return 0


if __name__ == "__main__":
    sys.exit(run_instrument(main, "staleness_greps"))
