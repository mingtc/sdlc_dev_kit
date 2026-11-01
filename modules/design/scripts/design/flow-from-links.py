#!/usr/bin/env python3
# KIT-CLASS: KIT — design tool: derives the screen-flow graph from artboard links, as Mermaid or JSON.
"""Derive a screen-flow graph from a canvas project/ directory.

usage: flow-from-links.py PROJECT_DIR [--json] [--variants] [--flow-board GLOB ...] [--exclude GLOB ...]

Parses every *.dc.html and collects <a href="X.dc.html"> relative board links; prints a Mermaid `flowchart LR`
(default) or the nodes and edges as JSON (--json). Node labels come from canvas.json board titles, else the file name.
'#', http(s) and mailto links are ignored.

  * A FLOW board (default glob `FLOW*`, repeatable --flow-board) is a drawing of the flow, not a screen: it is neither a
    node nor a source of edges. --exclude drops other non-screen boards (a component sheet) the same way.
  * A link text holding `{{name}}` is interpolated when the board script gives `name` a value made of string literals
    (`submitLabel: mode === 'in' ? 'Sign in' : 'Create account'` -> "Sign in / Create account"). A `{{...}}` that cannot
    be resolved is kept, marked "[dynamic]" in the label, flagged on stderr, and `label_unresolved` in JSON.
  * An edge records the `<sc-if>` conditions enclosing its link as `when` (JSON); --variants adds them to the Mermaid
    label, so a link that exists only in one state is visible.
Python 3 standard library only.
"""
import argparse, fnmatch, json, re, sys
from urllib.parse import unquote
from html.parser import HTMLParser
from pathlib import Path

VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}


class LinkParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.links, self.open_a, self.stack, self.script, self._in_script = [], [], [], [], False

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "script" and "text/x-dc" in (a.get("type") or ""):
            self._in_script = True
        cond = None
        if tag == "sc-if":
            cond = re.sub(r"^\{\{\s*|\s*\}\}$", "", (a.get("value") or "").strip())
        if tag not in VOID:
            self.stack.append((tag, cond))
        if tag == "a":
            when = [c for t, c in self.stack if t == "sc-if" and c]
            self.open_a.append({"href": (a.get("href") or "").strip(), "id": a.get("id"), "aria": a.get("aria-label"),
                                "parts": [], "when": when})

    def handle_data(self, data):
        if self._in_script:
            self.script.append(data)
        if self.open_a:
            self.open_a[-1]["parts"].append(data)

    def handle_endtag(self, tag):
        if tag == "script":
            self._in_script = False
        if tag == "a" and self.open_a:
            self.links.append(self.open_a.pop())
        for i in range(len(self.stack) - 1, -1, -1):
            if self.stack[i][0] == tag:
                del self.stack[i:]
                break


def is_board_link(href):
    if not href or href.startswith("#"):
        return False
    if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", href):
        return False
    return href.split("#", 1)[0].split("?", 1)[0].endswith(".dc.html")


def collapse(s):
    return re.sub(r"\s+", " ", s).strip()


def string_literals_of(script, name):
    """String literals inside the expression that gives `name` its value in the board script, or []."""
    m = re.search(r"(?<![\w.])%s\s*[:=]\s*" % re.escape(name), script)
    if not m:
        return []
    i, depth, quote, buf = m.end(), 0, None, []
    while i < len(script):
        ch = script[i]
        if quote:
            if ch == "\\":
                buf.append(script[i:i + 2]); i += 2; continue
            buf.append(ch)
            if ch == quote:
                quote = None
        elif ch in "'\"`":
            quote = ch; buf.append(ch)
        elif ch in "([{":
            depth += 1; buf.append(ch)
        elif ch in ")]}":
            if depth == 0:
                break
            depth -= 1; buf.append(ch)
        elif ch in ",;\n" and depth == 0:
            break
        else:
            buf.append(ch)
        i += 1
    lits = [a or b for a, b in re.findall(r"'((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\"", "".join(buf))]
    return list(dict.fromkeys(l for l in lits if l.strip()))


def interpolate(text, script):
    """-> (label, unresolved: bool)"""
    unresolved = False

    def sub(m):
        nonlocal unresolved
        name = m.group(1).strip()
        lits = string_literals_of(script, name) if re.fullmatch(r"[A-Za-z_]\w*", name) else []
        if lits:
            return " / ".join(lits)
        unresolved = True
        return m.group(0)
    out = re.sub(r"\{\{([^{}]*)\}\}", sub, text)
    return (out + " [dynamic]") if unresolved else out, unresolved


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("project")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--variants", action="store_true")
    ap.add_argument("--flow-board", action="append", default=None, metavar="GLOB")
    ap.add_argument("--exclude", action="append", default=[], metavar="GLOB")
    args = ap.parse_args(argv[1:])
    root = Path(args.project)
    if not root.is_dir():
        sys.exit(f"not a directory: {root}")
    skip = (args.flow_board if args.flow_board is not None else ["FLOW*"]) + args.exclude

    titles = {}
    cj = root / "canvas.json"
    if cj.is_file():
        try:
            doc = json.loads(cj.read_text(encoding="utf-8", errors="replace"))
            boards = doc.get("boards", {}) if isinstance(doc, dict) else {}
            for k, v in (boards.items() if isinstance(boards, dict) else ()):
                if isinstance(v, dict) and v.get("title"):
                    titles[k] = v["title"]
        except json.JSONDecodeError as e:
            print(f"warning: canvas.json unreadable ({e}); using file names", file=sys.stderr)

    all_files = sorted(p.name for p in root.glob("*.dc.html"))
    files = [f for f in all_files if not any(fnmatch.fnmatch(f, g) for g in skip)]
    edges = []
    for f in files:
        p = LinkParser()
        p.feed((root / f).read_text(encoding="utf-8", errors="replace"))
        script = "".join(p.script)
        for l in p.links:
            if not is_board_link(l["href"]):
                continue
            target = Path(unquote(l["href"].split("#", 1)[0].split("?", 1)[0])).name
            if any(fnmatch.fnmatch(target, g) for g in skip):
                continue
            raw = collapse("".join(l["parts"])) or collapse(l["aria"] or "") or "(no text)"
            label, unres = interpolate(raw, script)
            if unres:
                print(f"warning: {f}: link label '{raw}' has a value the script does not spell out; kept as dynamic", file=sys.stderr)
            e = {"from": f, "to": target, "label": label, "element_id": l["id"], "when": l["when"]}
            if unres:
                e["label_unresolved"] = True
            edges.append(e)

    if args.json:
        print(json.dumps({"nodes": [{"file": f, "title": titles.get(f, f)} for f in files], "edges": edges},
                         indent=2, ensure_ascii=False))
        return 0

    node_ids = {}

    def nid(f):
        """A Mermaid-safe id per file: the file's name with other characters as `_`, numbered when two names collapse to one."""
        if f not in node_ids:
            base = re.sub(r"[^A-Za-z0-9_]", "_", f.removesuffix(".dc.html"))
            node_ids[f] = base if base not in node_ids.values() else f"{base}_{len(node_ids)}"
        return node_ids[f]

    def q(s):
        return s.replace('"', "#quot;")

    nodes = list(files)
    for e in edges:
        if e["to"] not in nodes:
            nodes.append(e["to"])
            print(f"warning: {e['from']} links to {e['to']}, which is not in {root}", file=sys.stderr)
    print("flowchart LR")
    for f in nodes:
        print(f'    {nid(f)}["{q(titles.get(f, f))}"]')
    seen = set()
    for e in edges:
        lab = e["label"] + (f' (if {", ".join(e["when"])})' if args.variants and e["when"] else "")
        key = (e["from"], e["to"], lab)
        if key in seen:
            continue
        seen.add(key)
        print(f'    {nid(e["from"])} -->|"{q(lab)}"| {nid(e["to"])}')
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
