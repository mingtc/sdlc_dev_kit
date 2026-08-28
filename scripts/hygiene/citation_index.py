#!/usr/bin/env python3
# KIT-CLASS: KIT — the shared citation index behind the hygiene instruments; advisory, never a
# gate. See process/EXTRACTION.md.
# =============================================================================
# scripts/hygiene/citation_index.py — the citation index, and the shared half the others import.
#
# THE SET, STATED ONCE SO THAT NOTHING COUNTS IT BY HAND: **every `.py` file in this directory is
# an instrument, and this one is also the library the others import.** `ls scripts/hygiene/` is
# the list. No file carries an ordinal — adding an instrument would renumber the others, and a set
# maintained by hand, one header at a time, goes false the first time it changes.
#
# WHY THIS FILE IS PYTHON, IN A KIT THAT IS OTHERWISE BASH + GIT. The files in this
# directory are INSTRUMENTS, not project runtime: nothing ships them, no gate calls them, and no
# consumer inherits them. They are the seat's measuring tools, and they are Python because a
# shingle scan and a graph walk in bash would be slower to run and far slower to read. They use
# the STANDARD LIBRARY ONLY — no dependency enters your project because these exist, which is the
# line that keeps them from becoming a runtime obligation. A project whose language is not Python
# can delete this directory and lose nothing but the measurements; process/hygiene-checklist.md
# states each shape in prose, and re-implementing one is a day's work.
#
# WHAT IT IS. A deterministic, read-only map from every path in this tree to the files that
# cite it. Instruments 2 (reachability_walk.py) and 3 (cold_signal.py) both need one, so it
# lands ONCE, here, and they import it.
#
# THE ONE RULE THAT MATTERS — EXACT AND ANCESTOR REFERRERS ARE SEPARATE COLUMNS, NEVER
# COLLAPSED. A citation of `dev/<some-study>/captures` from a shipped docstring makes the TREE
# evidence; it does not make each capture individually load-bearing. The consequence of
# conflating them, in one sentence: a census then either PARALYSES ITSELF (everything looks
# cited) or DESTROYS EVIDENCE (nothing looks cited). The donor project's worked example was one
# evidence tree carrying 718 referrers, MOSTLY ANCESTOR-LEVEL — collapse the columns and that
# tree either justifies keeping every file under it or none. `referrers()` therefore returns two
# sets and every caller prints two columns.
#
# WHAT IT IS NOT. Not a guard, not a gate, not collected by any test runner. It writes nothing,
# deletes nothing, moves nothing and makes no network call.
#
# THE SHAPES IT LOOKS FOR, and the blind spots it does NOT have — each one cost the donor
# project's census a wrong orphan list ("FOUR successive tokenizer/normalisation bugs each
# produced a plausible-looking but wrong orphan list"):
#   (a) markdown link targets, `[x](process/MANUAL.md)` and `[x](verify-gate.md)`;
#   (b) repo-relative path tokens in prose, code and shell;
#   (c) referrer-relative tokens — `./file.md`, `../x/y.md`, and a bare sibling name;
#   (d) EXTENSION-LESS SCRIPT PATHS. A setup script holding
#       `HOOK_SRC="$SCRIPT_DIR/hooks/post-merge"` was eaten by the census's regex as
#       `SCRIPT_DIR/hooks/`, and the hook it installs was reported as a FALSE ORPHAN — recorded
#       at the time as "a blind spot any future orphan guard must handle". Handled here by
#       stripping a leading `$VAR/` segment and resolving the remainder referrer-relative;
#       `reachability_walk.py --self-test` re-proves the edge on YOUR tree.
#
# THE CHECKLIST THESE INSTRUMENTS SERVE: `process/hygiene-checklist.md`.
# =============================================================================
"""The citation index shared by the hygiene instruments. Read-only, stdlib only."""

from __future__ import annotations

import argparse
import posixpath
import re
import sys
from pathlib import Path

# NO BYTECODE CACHE, DELIBERATELY — and the LIMIT of this line is stated, because a guard-rail
# that is believed to do more than it does is worse than none.
#
# THE HAZARD: a project guard that walks `scripts/` and fails on any file without a KIT-CLASS
# marker will REDDEN on an interpreter-written `scripts/hygiene/__pycache__/*.pyc`. `.gitignore`
# usually covers `__pycache__/`, so `git status` stays clean while the guard is red — invisible
# to the normal check. Measured in the donor project: one bare `python -c "import
# citation_index"` wrote the cache and took that guard from green to one failure.
#
# WHAT THIS LINE DOES: it suppresses the cache for everything imported AFTER this module in the
# same process.
#
# WHAT IT CANNOT DO — CPython writes a module's own `.pyc` at COMPILE time, BEFORE the body
# runs, so no statement inside this file can prevent `citation_index`'s OWN cache. Re-measured
# both ways: flag set by the importer first -> no `__pycache__`; flag set only here -> the `.pyc`
# is still written.
#
# THEREFORE THE IMPORTER CONTRACT, AND IT IS ON THE IMPORTER: **set
# `sys.dont_write_bytecode = True` BEFORE importing this module.** Every instrument that imports
# this file does, each with the comment saying why — the obligation is on the importer, so how many
# importers there are is a fact about the directory and not part of the rule. A
# bare REPL / `python -c` import will redden such a guard until it is cleaned up
# (`rm -rf scripts/hygiene/__pycache__`).
sys.dont_write_bytecode = True

# scripts/hygiene/<file>.py → the repo root is two levels up. The ONE place any instrument
# resolves the tree it measures; override it with the `--root` flag each instrument carries.
REPO_ROOT = Path(__file__).resolve().parents[2]

# ── PARAMETERS. Every instrument's scope is declared here or in its own header — never hidden,
#    and never a per-file silencer. An exclusion is always a whole tree with a reason.
#
# Directories never scanned as referrers and never treated as targets: build output, virtual
# environments, git's own store, caches, the kanban worktree. Everything else in the tree is in
# scope. ADD YOUR LANGUAGE'S BUILD AND DEPENDENCY DIRECTORIES HERE — a scan that walks a
# vendored dependency tree reports thousands of true-but-useless facts and gets switched off.
SKIP_DIRS = {
    ".git",
    ".kanban-wt",
    # Common build / dependency / cache trees across ecosystems. Prune or extend freely.
    ".venv", "venv", "env",
    "dist", "build", "out", "target",
    "node_modules", "vendor",
    "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache", ".tox",
    ".gradle", ".idea", ".vscode",
    ".egg-info",
}
# Read as text; anything else is a binary and cites nothing.
TEXT_SUFFIXES = {
    ".md", ".txt", ".rst", ".sh", ".bash", ".zsh", ".py", ".rb", ".pl",
    ".js", ".mjs", ".ts", ".tsx", ".jsx", ".go", ".rs", ".java", ".kt", ".swift",
    ".c", ".h", ".cc", ".cpp", ".hpp", ".cs",
    ".toml", ".cfg", ".ini", ".json", ".yaml", ".yml", ".env",
    ".example", ".skeleton", ".template", ".in", ".tsv", ".csv", "",
}
MAX_BYTES = 4 * 1024 * 1024

_MD_LINK = re.compile(r"\]\(\s*<?([^)>\s]+)")
_PATH_TOKEN = re.compile(r"(?:\.{1,2}/)?[\w.\-${}]+(?:/[\w.\-${}]+)+")
_BARE_NAME = re.compile(
    r"[\w.\-]+\.(?:md|txt|rst|sh|py|rb|js|ts|go|rs|java|json|toml|yaml|yml|tsv|example)\b"
)
_VAR_SEG = re.compile(r"^\$\{?\w+\}?$")


# Set by iter_files(). None means NO WALK HAS RUN — which is not the same claim as zero, and
# the notice below refuses to print a count it did not measure. A zero that nobody earned is the
# defect this whole notice exists to prevent, one level up.
_WALK_SYMLINKS_SKIPPED = None


def iter_files(root: Path):
    """Every in-scope file in the tree, repo-relative posix, sorted.

    Also tallies the symlinks it skipped, for walk_blind_spots(). The tally counts a symlink
    ONLY where it would otherwise have been included — it resolves to a file and its path is not
    pruned — so the number means "files absent from this walk because they are symlinks" and not
    "symlinks seen". The prune test therefore runs BEFORE the symlink test; the set returned is
    byte-identical to the previous order of those two checks.
    """
    global _WALK_SYMLINKS_SKIPPED
    out = []
    skipped = 0
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(root).as_posix()
        if any(part in SKIP_DIRS or part.endswith(".egg-info") for part in rel.split("/")[:-1]):
            continue
        if path.is_symlink():
            skipped += 1
            continue
        out.append(rel)
    _WALK_SYMLINKS_SKIPPED = skipped
    return sorted(out)


def walk_blind_spots() -> list:
    """What ``iter_files`` did NOT look at — the walk's own narrowings, in one place.

    ``instruments.md`` § A.4: a deliberate narrowing says so in the line that reports its
    result. This lives BESIDE THE WALK rather than in each instrument's print block because
    every module importing ``iter_files`` or ``Index`` inherits these narrowings, and a notice
    copied into each one is one authoring site per importer for a single fact — the next narrowing
    would have to find them all. Importers call this; they do not restate it.

    Derived, not written down: the pruned-directory count comes from ``SKIP_DIRS`` itself, so
    editing that set cannot leave this line behind.
    """
    if _WALK_SYMLINKS_SKIPPED is None:
        tally = "count unavailable — no walk has run in this process"
    else:
        tally = f"{_WALK_SYMLINKS_SKIPPED} skipped in this run"
    return [
        f"symlinks are skipped — a symlinked file is absent from this walk entirely "
        f"({tally}; following one risks double-counting a file under two paths, and cycles)",
        f"{len(SKIP_DIRS)} directory names are pruned wherever they appear, as is any directory with "
        f"a name ending .egg-info — the set is SKIP_DIRS in citation_index.py, and it is yours to edit",
    ]


def print_blind_spots(prefix: str = "BLIND SPOT: ") -> None:
    """Print the walk's narrowings on the human path. Every instrument that walks calls this."""
    for line in walk_blind_spots():
        print(prefix + line)


def _read(root: Path, rel: str) -> str:
    path = root / rel
    if path.suffix not in TEXT_SUFFIXES or path.stat().st_size > MAX_BYTES:
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def _candidates(text: str):
    """Every citation-shaped token in one file, undeduplicated and unresolved."""
    for match in _MD_LINK.finditer(text):
        yield match.group(1)
    for match in _PATH_TOKEN.finditer(text):
        yield match.group(0)
    for match in _BARE_NAME.finditer(text):
        yield match.group(0)


def _normalize(token: str) -> str:
    token = token.strip().strip("`'\"<>()[],;:").split("#", 1)[0].split("?", 1)[0]
    while token.endswith(("/", ".", ",", ")")):
        token = token[:-1]
    return token


def resolve(token: str, referrer: str, universe: set) -> set:
    """Every path in ``universe`` this token could name. Both directions, per (a)-(d) above."""
    token = _normalize(token)
    if not token or token.startswith(("http:", "https:", "mailto:")):
        return set()
    segments = token.split("/")
    # (d) drop a leading shell-variable segment: "$SCRIPT_DIR/hooks/post-merge".
    while segments and _VAR_SEG.match(segments[0]):
        segments = segments[1:]
    if not segments or any("$" in seg for seg in segments):
        return set()
    tail = "/".join(segments)
    here = posixpath.dirname(referrer)
    found = set()
    for form in (tail, posixpath.normpath(posixpath.join(here, tail)) if here else tail):
        form = form.lstrip("/")
        if form and not form.startswith("..") and form in universe:
            found.add(form)
    return found


class Index:
    """``target -> referrers``, with EXACT and ANCESTOR kept apart. Built once, read many."""

    def __init__(self, root: Path = REPO_ROOT):
        self.root = root
        self.files = iter_files(root)
        self.universe = set(self.files)
        for rel in self.files:  # directories are citable targets too
            parts = rel.split("/")
            for i in range(1, len(parts)):
                self.universe.add("/".join(parts[:i]))
        self.by_target: dict = {}
        self.edges: dict = {}
        for rel in self.files:
            text = _read(root, rel)
            if not text:
                continue
            targets = set()
            for token in _candidates(text):
                targets |= resolve(token, rel, self.universe)
            targets.discard(rel)
            self.edges[rel] = targets
            for target in targets:
                self.by_target.setdefault(target, set()).add(rel)

    def referrers(self, target: str):
        """``(exact, ancestor)`` — two sets, never one. Self-citations excluded."""
        exact = set(self.by_target.get(target, ())) - {target}
        ancestor = set()
        parts = target.split("/")
        for i in range(1, len(parts)):
            ancestor |= self.by_target.get("/".join(parts[:i]), set())
        return exact, ancestor - {target}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", help="repo-relative paths to report on")
    parser.add_argument("--root", default=str(REPO_ROOT), help="tree to measure (default: this repo)")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    args = parser.parse_args(argv)
    index = Index(Path(args.root))
    targets = args.paths or sorted(index.by_target)
    rows = []
    for target in targets:
        exact, ancestor = index.referrers(target)
        rows.append({"path": target, "exact_n": len(exact), "anc_n": len(ancestor),
                     "exact": sorted(exact)[:20], "ancestor": sorted(ancestor)[:20]})
    if args.json:
        import json

        # The narrowing that produced this set travels WITH it. A machine consumer is the
        # reader least able to infer a missing file from its absence — it cannot notice what it
        # was never given — so the notice belongs in the payload, not on a line the human path
        # prints after this branch has returned (instruments.md § A.4).
        print(json.dumps({"blind_spots": walk_blind_spots(), "rows": rows}, indent=2))
        return 0
    print(f"citation index over {len(index.files)} files in {index.root}")
    print("EXACT and ANCESTOR are separate columns and are never summed.")
    # instruments.md § A.4 — name the blind spot in the instrument's OWN output. Derived from
    # the walker (see walk_blind_spots) rather than written here, because every instrument that
    # imports iter_files or Index inherits the same narrowings, and a copy per instrument is one
    # authoring site per importer for a single fact.
    print_blind_spots()
    print(f"{'EXACT':>7} {'ANC':>7}  PATH")
    for row in rows:
        print(f"{row['exact_n']:>7} {row['anc_n']:>7}  {row['path']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
