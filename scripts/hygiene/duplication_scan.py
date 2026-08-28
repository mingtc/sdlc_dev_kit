#!/usr/bin/env python3
# KIT-CLASS: KIT — the cross-file prose duplication scan; advisory, never a gate.
# See process/EXTRACTION.md.
# =============================================================================
# scripts/hygiene/duplication_scan.py — INSTRUMENT 1 of 4: CROSS-FILE DUPLICATION.
#
# MODALITY (the contract): a shingle scan over normalized windows, reporting cross-file PAIRS
# with an overlap fraction. Report only — it writes nothing, deletes nothing, moves nothing,
# makes no network call, and needs no dependency (standard library only; see
# citation_index.py's header for why these instruments are Python at all).
#
# THE PARAMETERIZATION, AND WHY THIS ONE. Two shapes were on record for the donor project's own
# scan: 9-GRAM CONTAINMENT over prose files larger than 1.5 KB, and "6-line normalized windows".
# THIS SCRIPT TAKES THE 9-GRAM SHAPE, for one reason worth copying: it is the shape in which the
# only calibration figure that existed was recorded — "only four pairs above 18%: one
# byte-identical, one duplicated by design (a pack pair that says so in its own text), two benign
# intra-spike quotations". A line-window scan cannot be compared against that number at all, so
# adopting it would have thrown away the only baseline anyone had. So: WORD SHINGLES OF SIZE 9
# (`--n`, default 9), CONTAINMENT (intersection over the SMALLER document's shingle set, so a
# short quotation inside a long document is still visible), a report threshold of 18% (`--min`),
# and a corpus floor of 1536 bytes (`--min-bytes`).
#
# RE-CALIBRATE BEFORE YOU QUOTE. That "four pairs above 18%" is ANOTHER PROJECT'S corpus on one
# day. Run this on yours, write down what you get, and cite your own number with its date — the
# whole point of the base-rate discipline (see staleness_greps.py) is that a figure without a
# date and a source is a claim, not a measurement.
#
# NORMALIZATION, stated because it is where a duplicate scan lies: text is lowercased, fenced
# code blocks and inline code are KEPT (they duplicate as often as prose does), markdown
# punctuation and whitespace collapse to single spaces, and shingles are word-level. Two files
# that differ only in heading punctuation are still reported as a pair.
#
# A PAIR IS A SUSPICION, NOT A VERDICT. Of the donor's four: one was a real duplicate, one was
# duplicated ON PURPOSE and said so in its own text, and two were quotations. The instrument
# classifies nothing; it prints pairs and the reader adjudicates.
#
# THE CHECKLIST THIS INSTRUMENT SERVES: `process/hygiene-checklist.md`.
# =============================================================================
"""Instrument 1 — cross-file 9-gram containment over the prose corpus. Read-only, stdlib."""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from collections import defaultdict
from itertools import combinations
from pathlib import Path

# NO BYTECODE CACHE, DELIBERATELY — see citation_index.py's header for the full statement and
# the importer contract. Set BEFORE the sibling import below; moving it after re-creates the
# cache and, with it, the redness in any guard that walks scripts/.
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from citation_index import REPO_ROOT, iter_files, print_blind_spots, walk_blind_spots  # noqa: E402

DEFAULT_N = 9
DEFAULT_MIN = 0.18
DEFAULT_MIN_BYTES = 1536

# ── PARAMETERS — the corpus, declared. Authored prose OUTSIDE the board, the source tree and
#    the test tree. Every exclusion is a whole tree with a reason, never a per-file silencer:
#      progress/  — the board. A closed issue body is written once and never touched again BY
#                   DESIGN, and closed issues quote each other constantly, so including them
#                   floods the report with true-but-meaningless pairs.
#      <code>/    — source and tests. Duplication there is a code question with its own tools.
#      <build>/   — not authored.
#    EDIT THESE for your tree: name your source, test and build roots.
EXCLUDED_PREFIXES = ("progress/", "src/", "tests/", "test/", "dist/", "build/")
# The file types considered "prose". Extend if your corpus is (say) .rst or .txt.
PROSE_SUFFIXES = (".md",)

_WORD = re.compile(r"[a-z0-9_./-]+")


def corpus(root: Path, min_bytes: int, excluded=EXCLUDED_PREFIXES):
    out = []
    for rel in iter_files(root):
        if not rel.endswith(PROSE_SUFFIXES) or rel.startswith(tuple(excluded)):
            continue
        if (root / rel).stat().st_size > min_bytes:
            out.append(rel)
    return out


def shingles(root: Path, rel: str, size: int) -> set:
    text = (root / rel).read_text(encoding="utf-8", errors="replace").lower()
    words = _WORD.findall(text)
    return {
        hashlib.blake2b(" ".join(words[i:i + size]).encode(), digest_size=8).digest()
        for i in range(max(0, len(words) - size + 1))
    }


def scan(root: Path = REPO_ROOT, size: int = DEFAULT_N, minimum: float = DEFAULT_MIN,
         min_bytes: int = DEFAULT_MIN_BYTES, excluded=EXCLUDED_PREFIXES):
    files = corpus(root, min_bytes, excluded)
    sets = {rel: shingles(root, rel, size) for rel in files}
    postings = defaultdict(list)
    for rel, grams in sets.items():
        for gram in grams:
            postings[gram].append(rel)
    shared = defaultdict(int)
    for members in postings.values():
        if 1 < len(members) <= 40:  # a shingle in 40+ files is boilerplate, not a pair signal
            for pair in combinations(sorted(members), 2):
                shared[pair] += 1
    rows = []
    for (left, right), overlap in shared.items():
        floor = min(len(sets[left]), len(sets[right]))
        if not floor:
            continue
        containment = overlap / floor
        if containment >= minimum:
            rows.append({"a": left, "b": right, "containment": round(containment, 4),
                         "shared": overlap, "identical": _identical(root, left, right)})
    rows.sort(key=lambda r: -r["containment"])
    return files, rows


def _identical(root: Path, left: str, right: str) -> bool:
    return (root / left).read_bytes() == (root / right).read_bytes()


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--n", type=int, default=DEFAULT_N, help=f"shingle size (default {DEFAULT_N})")
    parser.add_argument("--min", type=float, default=DEFAULT_MIN,
                        help=f"containment floor (default {DEFAULT_MIN})")
    parser.add_argument("--min-bytes", type=int, default=DEFAULT_MIN_BYTES)
    parser.add_argument("--root", default=str(REPO_ROOT), help="tree to measure (default: this repo)")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    files, rows = scan(root=Path(args.root), size=args.n, minimum=args.min,
                       min_bytes=args.min_bytes)
    if args.json:
        import json

        print(json.dumps({"blind_spots": walk_blind_spots(), "corpus": len(files), "n": args.n, "min": args.min,
                          "pairs": rows}, indent=2))
        return 0
    print(f"duplication scan: {args.n}-gram containment over {len(files)} prose files "
          f">{args.min_bytes} B, reporting pairs at or above {args.min:.0%}")
    print("excluded trees: " + " ".join(EXCLUDED_PREFIXES))
    print_blind_spots()
    print("A pair is a SUSPICION, not a verdict — deliberate duplication is common.")
    print(f"{'CONTAIN':>8} {'SHARED':>7} {'IDENT':>6}  PAIR")
    for row in rows:
        print(f"{row['containment']:>8.1%} {row['shared']:>7} "
              f"{'YES' if row['identical'] else '-':>6}  {row['a']}\n{'':>24}{row['b']}")
    if not rows:
        print("(no pair at or above the threshold)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
