#!/usr/bin/env python3
# KIT-CLASS: KIT — the orphan walk over the doc graph; advisory, never a gate.
# See process/EXTRACTION.md.
# =============================================================================
# scripts/hygiene/reachability_walk.py — THE REACHABILITY WALK.
#
# MODALITY (the contract): build the reference graph over this repo's doc nodes, walk it from the
# starter files a fresh agent actually opens, print everything NOT reached. Report only — it
# writes nothing, deletes nothing, moves nothing, makes no network call, needs no dependency
# (standard library only). Advisory, never a gate: no gate runner and no release step calls it.
#
# AN ORPHAN IS A SUSPICION, NOT A VERDICT. The donor project tested the assumption "a stray file
# nobody references will never get read" and refuted it in BOTH directions: a set of shipped,
# guarded skill files were entirely unreferenced and read constantly, while the most-cited
# document in its `dev/` tree declared itself dead at its own line 3. Reachability-by-link and
# reachability-by-convention are two different graphs, and only one of them is measurable here.
#
# THE CONVENTION EXEMPTIONS, NAMED BY NAME. These are found BY POSITION — a router selects them
# by bare name, or an installer enumerates the directory on purpose — so unreferenced-ness is a
# WORTHLESS signal for them. NOTE THAT ONE OF THEM IS A FILE, not a directory: do not "tidy" this
# list into directory prefixes, because that silently drops the file and its reason with it.
#
# THE STARTER ROOTS ARE DATA, DECLARED BELOW, AND THEY ARE THIS PROJECT'S INSTANCE, NOT THE
# PATTERN. The pattern is "walk from what a fresh agent actually opens"; WHICH files those are is
# your answer to give. `--self-test` re-verifies each on disk and refuses if one has moved, which
# is also what tells you on day one that the shipped list needs pruning to the files you have.
#
# THE EXTENSION-LESS BLIND SPOT IS HANDLED, NOT INHERITED — see citation_index.py (d). A setup
# script's `HOOK_SRC="$SCRIPT_DIR/hooks/post-merge"` was once eaten by a regex and the hook it
# installs was reported as a FALSE ORPHAN. `--self-test` re-proves that edge on YOUR tree, and
# names the probe path it used so a project without that file can point it elsewhere.
#
# THE CHECKLIST THIS INSTRUMENT SERVES: `process/hygiene-checklist.md` (the "Orphans" shape).
# =============================================================================
"""Instrument 2 — the starter-graph reachability walk. Read-only, stdlib only."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# NO BYTECODE CACHE, DELIBERATELY — see citation_index.py's header for the full statement and
# the importer contract. Set BEFORE the sibling import below.
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from citation_index import REPO_ROOT, Index, print_blind_spots, walk_blind_spots  # noqa: E402

# ── PARAMETER: THE STARTER ROOTS. **EDIT THIS LIST.** It is the answer to "what does a fresh
#    agent open on its first minute here?", and it is the only thing that makes an orphan list
#    mean anything. Ship-time defaults below are the kit's own front doors; prune the ones your
#    project does not have (--self-test names them) and add yours.
STARTER_ROOTS = [
    "CLAUDE.md",
    "PROJECT.md",
    "README.md",
    "AGENTS.md",
    "process/MANUAL.md",
    "process/SEED.md",
    "process/EXTRACTION.md",
    "process/contracts/README.md",
    ".claude/roles/architect.md",
    ".claude/roles/orchestrator.md",
    ".claude/roles/pm.md",
    ".claude/roles/dev.md",
    ".claude/roles/qa.md",
    ".claude/roles/refactorer.md",
    ".claude/skills/README.md",
    "dev/README.md",
]

# ── PARAMETER: the convention exemptions. Directories whose members are found BY POSITION, plus
#    ONE FILE. Keep the file in the list — see the header.
CONVENTION_EXEMPTIONS = [
    ".claude/agents/",
    ".claude/skills/",
    ".claude/workflows/",
    ".claude/settings.json.example",  # A FILE, not a directory. Keep it in this list.
    "consumers/skills/",
    "consumers/hooks/",
    "consumers/ci/",
    "scripts/githooks/",
]

# ── PARAMETER: the node scope. Prose and config a reader navigates, with each `dev/` evidence
#    subdirectory COLLAPSED TO ONE NODE except the prose trees named below, whose members are
#    nodes in their own right. The collapse is what keeps a 300-file capture directory from
#    drowning the report; the exception list is what keeps real prose visible.
NODE_DIRS = ("process/", "docs/", "requirements/", ".claude/", "consumers/")
DEV_PROSE_TREES = (
    "handoffs", "incidents", "launch", "drafts", "sweeps", "spikes", "refactor", "plans",
    "specs", "design", "runs",
)
INDEX_NAMES = ("README.md", "SKILL.md", "MANUAL.md")

# ── PARAMETER: the probe --self-test uses for the extension-less blind spot. Point it at any
#    extension-less file in your tree that is cited from a shell variable path.
BLIND_SPOT_PROBE = "consumers/hooks/post-merge"


def node_universe(files) -> set:
    """Every doc node considered, per the scope above."""
    nodes = set()
    for rel in files:
        parts = rel.split("/")
        if len(parts) == 1 and rel.endswith(".md"):
            nodes.add(rel)
        elif rel.startswith(NODE_DIRS) and (rel.endswith(".md") or rel.startswith(".claude/")):
            nodes.add(rel)
        elif rel.startswith("dev/"):
            if len(parts) == 2 and rel.endswith(".md"):
                nodes.add(rel)
            elif len(parts) > 2 and parts[1] in DEV_PROSE_TREES:
                if rel.endswith(".md"):
                    nodes.add(rel)
            elif len(parts) > 2:
                nodes.add("dev/" + parts[1])  # one collapsed node per evidence tree
    return nodes


def edges_between_nodes(index: Index, nodes: set) -> dict:
    """Node -> nodes it cites. A directory link resolves to that directory's own index file."""
    graph = {}
    for src, targets in index.edges.items():
        origin = src if src in nodes else _collapse(src, nodes)
        if origin is None:
            continue
        out = graph.setdefault(origin, set())
        for target in targets:
            if target in nodes:
                out.add(target)
                continue
            for name in INDEX_NAMES:
                candidate = f"{target}/{name}"
                if candidate in nodes:
                    out.add(candidate)
            collapsed = _collapse(target, nodes)
            if collapsed is not None:
                out.add(collapsed)
        out.discard(origin)
    return graph


def _collapse(rel: str, nodes: set):
    parts = rel.split("/")
    for i in range(len(parts) - 1, 0, -1):
        prefix = "/".join(parts[:i])
        if prefix in nodes:
            return prefix
    return None


def is_exempt(node: str) -> bool:
    return any(node == item or node.startswith(item) for item in CONVENTION_EXEMPTIONS)


def _reach(graph: dict, nodes: set, without: str = "") -> set:
    seen = set(STARTER_ROOTS) & nodes
    frontier = list(seen)
    while frontier:
        node = frontier.pop()
        if node == without:
            continue
        for nxt in sorted(graph.get(node, ())):
            if nxt not in seen:
                seen.add(nxt)
                frontier.append(nxt)
    return seen


def laundered(graph: dict, nodes: set, seen: set) -> dict:
    """Nodes reachable ONLY through one collapsed `dev/` evidence tree.

    A KNOWN LIMITATION OF THE MODALITY, REPORTED RATHER THAN HIDDEN: an appendix that merely
    ENUMERATES orphans (an audit's own findings file is the specimen) makes every file it names
    link-reachable, so reachability-by-link cannot distinguish "on the live reading path" from
    "listed once in a dated audit". Those nodes are printed as a second, softer list — they are
    not orphans, and they are not evidence of a live reader either.
    """
    hubs = {n for n in nodes if n.startswith("dev/") and n.count("/") == 1 and "." not in n}
    out = {}
    for hub in sorted(hubs):
        only = seen - _reach(graph, nodes, without=hub) - {hub}
        if only:
            out[hub] = sorted(only)
    return out


def walk(root: Path = REPO_ROOT):
    index = Index(root)
    nodes = node_universe(index.files)
    graph = edges_between_nodes(index, nodes)
    seen = _reach(graph, nodes)
    orphans = sorted(nodes - seen)
    return index, nodes, seen, orphans, graph


def self_test(root: Path = REPO_ROOT) -> int:
    """Re-verify the two facts this instrument's honesty rests on."""
    missing = [r for r in STARTER_ROOTS if not (root / r).exists()]
    index = Index(root)
    probe_present = (root / BLIND_SPOT_PROBE).exists()
    exact, _ = index.referrers(BLIND_SPOT_PROBE)
    ok = not missing and (not probe_present or bool(exact))
    print(f"starter roots on disk: {len(STARTER_ROOTS) - len(missing)}/{len(STARTER_ROOTS)}")
    if missing:
        print(f"  MISSING: {missing}")
        print("  → PRUNE THE LIST to the files this project actually has. A starter root that")
        print("    does not exist is not a walk from the front door; it is a hole in the graph.")
    if probe_present:
        print(f"extension-less blind spot: {BLIND_SPOT_PROBE} exact referrers = "
              f"{len(exact)} {sorted(exact)} (must be > 0)")
    else:
        print(f"extension-less blind spot: {BLIND_SPOT_PROBE} is absent — point BLIND_SPOT_PROBE")
        print("  at an extension-less file of yours that is cited via a shell variable path,")
        print("  or accept that this arm is UNMEASURED here (it is not passing; it is unrun).")
    print("SELF-TEST", "PASS" if ok else "FAIL")
    return 0 if ok else 1


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=str(REPO_ROOT), help="tree to measure (default: this repo)")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--self-test", action="store_true", help="re-verify roots + blind spot")
    parser.add_argument("--show-exempt", action="store_true", help="list exempted orphans too")
    args = parser.parse_args(argv)
    root = Path(args.root)
    if args.self_test:
        return self_test(root)
    index, nodes, seen, orphans, graph = walk(root)
    reported = [o for o in orphans if args.show_exempt or not is_exempt(o)]
    exempted = [o for o in orphans if is_exempt(o)]
    hubs = laundered(graph, nodes, seen)
    if args.json:
        import json

        print(json.dumps({"blind_spots": walk_blind_spots(), "nodes": len(nodes), "reachable": len(seen),
                          "orphans": reported, "exempted": exempted,
                          "laundered_by_index": hubs}, indent=2))
        return 0
    print(f"reachability walk over {len(nodes)} doc nodes from {len(STARTER_ROOTS)} starters")
    print_blind_spots()
    print(f"reachable: {len(seen)}   orphans: {len(orphans)}   "
          f"of which convention-exempt: {len(exempted)}   reported: {len(reported)}")
    print("An orphan is a SUSPICION, not a verdict. Run --self-test first: a starter root that")
    print("does not exist makes every one of these numbers smaller than the truth.")
    print(f"{'EXACT':>7} {'ANC':>7}  ORPHAN")
    for orphan in reported:
        exact, ancestor = index.referrers(orphan)
        print(f"{len(exact):>7} {len(ancestor):>7}  {orphan}")
    if exempted and not args.show_exempt:
        print(f"\n{len(exempted)} node(s) suppressed by the convention exemptions "
              "(--show-exempt to list).")
    if hubs:
        print("\nLAUNDERED BY AN INDEX — reachable ONLY through one collapsed dev/ evidence "
              "tree; an appendix that enumerates orphans makes them link-reachable:")
        for hub, only in hubs.items():
            print(f"  {hub}: {len(only)} node(s)")
            for node in only:
                print(f"      {node}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
