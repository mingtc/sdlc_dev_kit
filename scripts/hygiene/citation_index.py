#!/usr/bin/env python3
# KIT-CLASS: KIT — the shared citation index behind the hygiene instruments; advisory, never a
# gate. See process/EXTRACTION.md.
# =============================================================================
# scripts/hygiene/citation_index.py — the citation index, and the shared half the others import.
#
# THE SET: every `.py` file in this directory is an instrument, and this one is also the library
# the others import. `ls scripts/hygiene/` is the list; this header carries no ordinal, because a
# hand-kept count goes false the first time the set changes.
#
# Python, STANDARD LIBRARY ONLY: these are measuring tools, not project runtime. No gate calls
# them and no dependency enters your project because they exist. A project that is not Python can
# delete this directory and lose only the measurements; process/hygiene-checklist.md states each
# shape in prose.
#
# WHAT IT IS. A deterministic, read-only map from every path in this tree to the files that cite
# it. reachability_walk.py and cold_signal.py both need one, so it lives once, here.
#
# THE ONE RULE THAT MATTERS — EXACT AND ANCESTOR REFERRERS ARE SEPARATE COLUMNS, NEVER
# COLLAPSED. A citation of `dev/<some-study>/captures` makes the TREE evidence; it does not make
# each capture load-bearing. Conflated, a census either paralyses itself (everything looks cited)
# or destroys evidence (nothing does). `referrers()` returns two sets; every caller prints two.
#
# WHAT IT IS NOT. Not a guard, not a gate, not collected by any test runner. It writes nothing,
# deletes nothing, moves nothing and makes no network call.
#
# THE SHAPES IT LOOKS FOR, each a blind spot that would otherwise yield a wrong orphan list:
#   (a) markdown link targets, `[x](process/MANUAL.md)` and `[x](verify-gate.md)`;
#   (b) repo-relative path tokens in prose, code and shell;
#   (c) referrer-relative tokens — `./file.md`, `../x/y.md`, and a bare sibling name;
#   (d) EXTENSION-LESS SCRIPT PATHS such as `HOOK_SRC="$SCRIPT_DIR/hooks/post-merge"`: a leading
#       `$VAR/` segment is stripped and the rest resolved referrer-relative;
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

# NO BYTECODE CACHE. A guard that fails on any file without a KIT-CLASS marker would redden on a
# gitignored `scripts/hygiene/__pycache__/*.pyc` that `git status` never shows. This line covers
# only modules imported AFTER this one: CPython writes this module's own `.pyc` before its body
# runs. So every importer sets `sys.dont_write_bytecode = True` BEFORE importing it, and a bare
# REPL / `python -c` import needs `rm -rf scripts/hygiene/__pycache__` afterwards.
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

# ── THE PREFIX EXCLUSION SET — ONE AUTHORING SITE for every instrument in this directory.
#
#    Every exclusion is a WHOLE TREE with a reason, never a per-file silencer:
#      progress/  — the board. A closed issue body is written once and never touched again BY
#                   DESIGN, and closed issues quote each other constantly, so including them
#                   floods a duplication report with true-but-meaningless pairs.
#      <code>/    — source and tests. Duplication there is a code question with its own tools.
#      <build>/   — not authored.
#
#    EDIT THIS for your tree: name your source, test and build roots. It is the only place;
#    the instruments import it and neither redefines it.
DEFAULT_EXCLUDED_PREFIXES = ("progress/", "src/", "tests/", "test/", "dist/", "build/")

_MD_LINK = re.compile(r"\]\(\s*<?([^)>\s]+)")
_PATH_TOKEN = re.compile(r"(?:\.{1,2}/)?[\w.\-${}]+(?:/[\w.\-${}]+)+")
_BARE_NAME = re.compile(
    r"[\w.\-]+\.(?:md|txt|rst|sh|py|rb|js|ts|go|rs|java|json|toml|yaml|yml|tsv|example)\b"
)
_VAR_SEG = re.compile(r"^\$\{?\w+\}?$")


# Set by iter_files(). None means NO WALK HAS RUN, which is not zero: the notice will not print a
# count it did not measure.
_WALK_SYMLINKS_SKIPPED = None


def iter_files(root: Path):
    """Every in-scope file in the tree, repo-relative posix, sorted.

    Also tallies the symlinks it skipped, for walk_blind_spots(): only those that would otherwise
    have been included, so the prune test runs BEFORE the symlink test.
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


class BlindSpotsUnavailable(RuntimeError):
    """``walk_blind_spots()`` derived NO lines — so the walk's narrowings were never stated.

    A defect in the instrument, never a fact about the tree: the walk narrows by construction
    (symlinks, pruned directories), so an empty list means the derivation broke. Refused as
    UNRUNNABLE, in ``cold_signal.HistoryUnavailable``'s vocabulary: UNRUNNABLE is not FAIL.
    """

    # The remedy is passed in, so a second caller cannot inherit advice written for the first.
    def __init__(self, asked, said, remedy):
        self.asked, self.said, self.remedy = asked, said, remedy
        self.rc = None
        super().__init__("walk_blind_spots() derived no lines")


def walk_blind_spots() -> list:
    """What ``iter_files`` did NOT look at — the walk's own narrowings, in one place.

    ``instruments.md`` § A.4: a narrowing says so in the line that reports its result. It lives
    beside the walk, so every importer of ``iter_files`` or ``Index`` inherits one statement;
    importers call this and do not restate it. Derived from ``SKIP_DIRS``, so editing that set
    cannot leave this line behind.
    """
    if _WALK_SYMLINKS_SKIPPED is None:
        tally = "count unavailable — no walk has run in this process"
    else:
        tally = f"{_WALK_SYMLINKS_SKIPPED} skipped in this run"
    lines = [
        f"symlinks are skipped — a symlinked file is absent from this walk entirely "
        f"({tally}; following one risks double-counting a file under two paths, and cycles)",
        f"{len(SKIP_DIRS)} directory names are pruned wherever they appear, as is any directory with "
        f"a name ending .egg-info — the set is SKIP_DIRS in citation_index.py, and it is yours to edit",
    ]
    # An empty derivation is the instrument failing, so it refuses rather than returning []: every
    # importer would print [] as "this walk has no blind spots", which the walk never has.
    if not lines:
        raise BlindSpotsUnavailable(
            asked="walk_blind_spots() in citation_index.py",
            said="the derivation returned an empty list",
            remedy="this is a code defect, not a tree state: walk_blind_spots() must state every "
                   "narrowing iter_files() applies, and it derived none. Restore the derivation — "
                   "the symlink tally and the SKIP_DIRS count are its two inputs.",
        )
    return lines


def print_blind_spots(prefix: str = "BLIND SPOT: ") -> None:
    """Print the walk's narrowings on the human path. Every instrument that walks calls this."""
    for line in walk_blind_spots():
        print(prefix + line)


def run_instrument(entry, instrument: str, argv=None) -> int:
    """Run one instrument's ``main`` and turn a broken walker into a REFUSAL, not a traceback.

    The one site for the refusal text, the exit code and the JSON shape. Each instrument's
    ``__main__`` block calls this instead of ``main()``. ``--json`` is read from argv, not the
    parsed namespace, because the exception can fire before parsing.
    """
    wants_json = "--json" in (sys.argv[1:] if argv is None else argv)
    try:
        return entry() if argv is None else entry(argv)
    except BlindSpotsUnavailable as exc:
        # THE REFUSAL, in cold_signal.py's vocabulary, which is verify.sh's. Human text on stderr
        # either way, so a caller redirecting stdout still sees why.
        print(f"{instrument}: could NOT RUN — {exc}. NOTHING was measured.", file=sys.stderr)
        print("  this is not 'no blind spots': the walker has never had none.", file=sys.stderr)
        print(f"  asked:     {exc.asked}", file=sys.stderr)
        print(f"  it said:   {exc.said or '(no message)'}", file=sys.stderr)
        print(f"  remedy:    {exc.remedy}", file=sys.stderr)
        if wants_json:
            import json

            # A valid object that says it did not run, with NO data keys: `"blind_spots": []`
            # would assert the very claim this refuses (reasoning: cold_signal.py's refusal block).
            print(json.dumps({"unrunnable": {
                "instrument": instrument, "reason": str(exc), "asked": exc.asked,
                "said": exc.said, "remedy": exc.remedy,
            }}, indent=2))
        return 2


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

        # The narrowing travels WITH the payload: a machine consumer cannot notice a file it was
        # never given (instruments.md § A.4).
        print(json.dumps({"blind_spots": walk_blind_spots(), "rows": rows}, indent=2))
        return 0
    print(f"citation index over {len(index.files)} files in {index.root}")
    print("EXACT and ANCESTOR are separate columns and are never summed.")
    # instruments.md § A.4: name the blind spot in the instrument's own output, derived from the
    # walker (walk_blind_spots).
    print_blind_spots()
    print(f"{'EXACT':>7} {'ANC':>7}  PATH")
    for row in rows:
        print(f"{row['exact_n']:>7} {row['anc_n']:>7}  {row['path']}")
    return 0


if __name__ == "__main__":
    sys.exit(run_instrument(main, "citation_index"))
