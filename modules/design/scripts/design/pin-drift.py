#!/usr/bin/env python3
# KIT-CLASS: KIT — design tool: pin-drift report, pinned artboards vs a later revision. A report, never a gate.
"""pin-drift.py -- for every card past todo/ that pins design states, say whether each pinned state still matches HEAD.

usage: pin-drift.py [--head REV] [--json] [--root DIR] [--design DIR] [--cards DIR] [CARD.md ...]

  no CARD   every <cards>/<shelf>/*.md except the shelves todo, done, declined and history: a card in todo/ is unpinned by
            rule, a landed card's pin is history (a later design change is new work), a declined card builds nothing
  --root    the git repository (default: the working directory);  --cards default `progress` (a path outside --root is
            allowed: a report may read a copy of the board);  --design default `requirements/design` (the registry files
            are <design>/<canvas>/CANVAS.md and the tokens <design>/tokens/*.tokens.json)
  --head    the revision to compare against (default HEAD)
  --json    one JSON object per pinned state instead of the table

A card's `design:` key lists  UX-NNN#state@<commit>  (or `none`).  For each pinned state:

  1. RESOLVE AT THE PIN. The registry (<design>/*/CANVAS.md) is read AT THE PIN, so the UX id gives the artboard
     path as it was then. The same id is resolved again in the registry at --head. A canvas directory that moved between
     the two is followed, never reported as a deletion.
  2. COMPARE BLOBS. Artboard bytes at the pin against the artboard at its HEAD path (git blob ids, so exact), and the
     values of the design tokens the artboard uses: every var(--name) in it names the token whose path, dots as hyphens,
     is `name` (`--color-primary` is `color.primary`), read from <design>/tokens/*.tokens.json at both revisions, aliases
     resolved. A token value changed or removed is drift; a token added is not.
  3. VERDICT per card per state:
       clean   same artboard bytes at the same path, and the tokens it uses unchanged. A difference confined to the root's
               data-stories attribute (the registry row's story ids, rewritten whenever a PRD adds a story to the screen) is
               bookkeeping and reads clean, flagged `meta_only`
       moved   same artboard bytes at a new path (a canvas or file move), tokens unchanged
       drift   the artboard changed, or a token it uses changed or was removed; the element ids that changed are
               listed (+ added, - removed, ~ changed; `<script>` is the component script, `(document)` is markup
               outside every id)
     PER-STATE GRANULARITY. One artboard file holds every state of a screen, so a verdict per file reads `drift` for
     every state when one state's branch changed. The artboard can say which state a branch belongs to with
     `data-state="<state> [<state> ...]"` on the branch's root element (on the element the canvas renders, not on a
     `<sc-if>` wrapper). When a state is pinned, a changed element whose every version sits under a `data-state` that
     does not list the pinned state is set aside (`scoped_out` in --json; the verdict reads `clean`, noted). Shared
     markup, the component `<script>` and tokens count for every state. An artboard with no `data-state` mark keeps the
     per-file verdict (`granularity: file`); the state cannot be derived from the markup alone, because a variant is
     computed by the component script.
       gone    the registry at --head has no row for the UX id, or the file is missing
       unresolved   the pin is not a commit, or the registry at the pin has no such row or file
     One more column is evidence, not verdict: `render` says whether the committed render of THIS state
     (renders/<Stem>-<state>.png) is byte-identical at the pin and at --head. All states of one screen share one
     source file, so the verdict is the file's; `render: identical` beside `drift` means the change is in markup this
     state does not show, or is not visual (an attribute), and the reader decides.
Python 3 standard library only; reads git, writes nothing. Exit 0 always.
"""
import hashlib, importlib.util, json, re, subprocess, sys
from html.parser import HTMLParser
from pathlib import Path

sys.dont_write_bytecode = True   # importing the sibling check must leave no __pycache__ in the project
HERE = Path(__file__).resolve().parent
ROOT = Path('.').resolve()
DESIGN = 'requirements/design'
CARDS = 'progress'
SKIP_SHELVES = ('todo', 'done', 'declined', 'history')
_spec = importlib.util.spec_from_file_location('check_design_links', HERE / 'check-design-links.py')
cdl = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cdl)

PIN_ITEM = re.compile(r'(UX-\d+)(?:#([A-Za-z0-9_-]+))?(?:@([0-9a-fA-F]{7,40}))?')
META = re.compile(r' data-stories="[^"]*"')   # the artboard's copy of its registry row's story ids; adding a PRD's story to a row rewrites it
VOID = {'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'source', 'track', 'wbr'}


def git(*args, check=False):
    r = subprocess.run(['git', '-C', str(ROOT), *args], capture_output=True)
    if check and r.returncode:
        raise RuntimeError(r.stderr.decode())
    return r.returncode, r.stdout


def rev(r):
    rc, out = git('rev-parse', '--verify', '--quiet', f'{r}^{{commit}}')
    return out.decode().strip() if rc == 0 else None


def blob_id(r, path):
    rc, out = git('rev-parse', '--verify', '--quiet', f'{r}:{path}')
    return out.decode().strip() if rc == 0 else None


def show(r, path):
    rc, out = git('show', f'{r}:{path}')
    return out if rc == 0 else None


_reg_cache = {}


def registry_at(r):
    """{ux: row} from every requirements/design/*/CANVAS.md at revision r."""
    if r in _reg_cache:
        return _reg_cache[r]
    rc, out = git('ls-tree', '-r', '--name-only', r, '--', DESIGN)
    rows = {}
    for p in out.decode().splitlines():
        if p.endswith('/' + cdl.REGISTRY_NAME) and Path(p).parent.parent.as_posix() == DESIGN:
            text = show(r, p).decode('utf-8')
            rr, _ = cdl.parse_registry(text, p, Path(p).parent)
            for row in rr:
                rows.setdefault(row['ux'], row)
    _reg_cache[r] = rows
    return rows


def artboard_path(row):
    return (row['canvas'] / cdl.PROJECT_SUBDIR / row['file']).as_posix()


# ---- element signatures: one per id, own markup and own text only (a nested id owns its own).
# An element carrying data-state="a b" (and no id) owns its own signature under a synthetic key; every owner records the
# state scope it sits under (None = shared by all states). A nested owner inherits the scope of its parent.
def _states(v):
    return frozenset(x for x in re.split(r'[\s,]+', v or '') if x)


class Sig(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.owner = ['(document)']
        self.scope = [None]
        self.sigs = {'(document)': []}
        self.scopes = {'(document)': None}
        self.stack = []          # (tag, pushed_owner)
        self.seen = {}

    def _name(self, i):
        n = self.seen.get(i, 0) + 1
        self.seen[i] = n
        return i if n == 1 else f'{i}#{n}'

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        text = '<%s %s>' % (tag, ' '.join(f'{k}={v}' for k, v in sorted(attrs)))
        pushed, sc = None, self.scope[-1]
        if a.get('data-state'):
            sc = _states(a['data-state'])
        if tag == 'script' and 'text/x-dc' in (a.get('type') or ''):
            pushed, sc = '<script>', None
        elif a.get('id'):
            pushed = self._name(a['id'])
        elif a.get('data-state'):
            pushed = self._name('(state %s)' % ','.join(sorted(sc)))
        if pushed:
            self.sigs.setdefault(pushed, [])
            self.scopes.setdefault(pushed, sc)
            self.owner.append(pushed)      # an element with an id owns its own open tag
            self.scope.append(sc)
        self.sigs[self.owner[-1]].append(text)
        if tag not in VOID:
            self.stack.append((tag, pushed))
        elif pushed:
            self.owner.pop()
            self.scope.pop()

    def handle_endtag(self, tag):
        while self.stack:
            t, pushed = self.stack.pop()
            if pushed:
                self.owner.pop()
                self.scope.pop()
            if t == tag:
                break

    def handle_data(self, data):
        d = ' '.join(data.split())
        if d:
            self.sigs[self.owner[-1]].append(d)


def element_sigs(html):
    """{key: (sha1, scope)} - scope is a frozenset of states or None."""
    p = Sig()
    p.feed(html)
    p.close()
    return {k: (hashlib.sha1('\n'.join(v).encode()).hexdigest(), p.scopes.get(k)) for k, v in p.sigs.items()
            if v or k != '(document)'}


def changed_ids(old_html, new_html, state=None):
    """(ids that changed, ids set aside because every version sits under another state, scoped: any data-state in either)."""
    a, b = element_sigs(old_html), element_sigs(new_html)
    scoped = any(sc is not None for _, sc in list(a.values()) + list(b.values()))
    keys = [f'-{i}' for i in a if i not in b] + [f'+{i}' for i in b if i not in a] + \
           [f'~{i}' for i in a if i in b and a[i][0] != b[i][0]]
    keep, aside = [], []
    for k in keys:
        i = k[1:]
        scopes = [d[i][1] for d in (a, b) if i in d]
        if state and scopes and all(sc is not None and state not in sc for sc in scopes):
            aside.append(k)
        else:
            keep.append(k)
    return keep, aside, scoped


# ---- tokens: the DTCG files <design>/tokens/*.tokens.json, read at a revision
ALIAS = re.compile(r'^\{([^{}]+)\}$')


def _leaves(node, path=(), out=None):
    """{dotted path: $value} for every token of a DTCG tree; members whose key starts with `$` or `_` are not tokens."""
    out = {} if out is None else out
    if isinstance(node, dict):
        for k, v in node.items():
            if k.startswith(('$', '_')):
                continue
            if isinstance(v, dict) and '$value' in v:
                out['.'.join(path + (k,))] = v['$value']
            else:
                _leaves(v, path + (k,), out)
    return out


def _resolve(value, leaves, depth=0):
    m = ALIAS.match(value) if isinstance(value, str) else None
    if m and depth < 8 and m.group(1) in leaves:
        return _resolve(leaves[m.group(1)], leaves, depth + 1)
    return value


_tok_cache = {}


def token_map(r):
    """{(token file, css var name): resolved value} from every <design>/tokens/*.tokens.json at revision r. A file that is not
    JSON holds no tokens here."""
    if r in _tok_cache:
        return _tok_cache[r]
    rc, out = git('ls-tree', '-r', '--name-only', r, '--', f'{DESIGN}/tokens')
    found = {}
    for p in out.decode().splitlines():
        if not p.endswith('.tokens.json') or Path(p).parent.as_posix() != f'{DESIGN}/tokens':
            continue
        try:
            leaves = _leaves(json.loads(show(r, p).decode('utf-8')))
        except (ValueError, UnicodeDecodeError):
            continue
        for dotted, v in leaves.items():
            found[(Path(p).name, dotted.replace('.', '-'))] = json.dumps(_resolve(v, leaves), sort_keys=True)
    _tok_cache[r] = found
    return found


def tokens_changed(old_html, r_old, r_new):
    """The custom properties (--name) the artboard at the pin uses whose token value changed or vanished between the two revisions."""
    used = set(re.findall(r'var\(--([A-Za-z0-9_-]+)', old_html))
    a, b = token_map(r_old), token_map(r_new)
    return sorted('--' + n for n in used if {k: v for k, v in a.items() if k[1] == n} != {k: v for k, v in b.items() if k[1] == n})


def cards(paths):
    if paths:
        return [Path(p).resolve() for p in paths]
    out = []
    if (ROOT / CARDS).is_dir():
        for shelf in sorted((ROOT / CARDS).iterdir()):
            if shelf.is_dir() and shelf.name not in SKIP_SHELVES:
                out += sorted(shelf.glob('*.md'))
    return out


def pins_of(card):
    text = card.read_text(encoding='utf-8')
    m = re.search(r'^---\n(.*?)\n---', text, re.S | re.M)   # a card opens with an HTML comment before its frontmatter
    if not m:
        return None, []
    for line in m.group(1).splitlines():
        if line.startswith('design:'):
            body = line[len('design:'):]
            lb, rb = body.find('['), body.rfind(']')
            if lb < 0 or rb < lb:
                return body.split('#')[0].strip() or None, []
            items = [(x.group(1), x.group(2), x.group(3)) for x in PIN_ITEM.finditer(body[lb:rb])]
            return 'list', items
    return None, []


def check(card_id, ux, state, pin, head):
    base = {'card': card_id, 'ux': ux, 'state': state, 'pin': pin}
    if not pin:
        return {**base, 'verdict': 'unresolved', 'why': 'no @<commit> on a card past todo/'}
    full = rev(pin)
    if not full:
        return {**base, 'verdict': 'unresolved', 'why': f'{pin} is not a commit'}
    row_p = registry_at(full).get(ux)
    if not row_p:
        return {**base, 'verdict': 'unresolved', 'why': f'no registry row {ux} at {pin}'}
    path_p = artboard_path(row_p)
    old = show(full, path_p)
    if old is None:
        return {**base, 'verdict': 'unresolved', 'why': f'{path_p} is not in {pin}'}
    row_h = registry_at(head).get(ux)
    if not row_h:
        return {**base, 'verdict': 'gone', 'why': f'no registry row {ux} at HEAD', 'path_pin': path_p}
    path_h = artboard_path(row_h)
    new = show(head, path_h)
    if new is None:
        return {**base, 'verdict': 'gone', 'why': f'{path_h} is not in HEAD', 'path_pin': path_p}
    old_html, new_html = old.decode('utf-8'), new.decode('utf-8')
    toks = tokens_changed(old_html, full, head)
    same_bytes = blob_id(full, path_p) == blob_id(head, path_h)
    meta_only = False
    if not same_bytes and META.sub('', old_html) == META.sub('', new_html):
        same_bytes, meta_only = True, True      # only data-stories differs: registry bookkeeping, not the design
    ids, aside, scoped = ([], [], False) if same_bytes else changed_ids(old_html, new_html, state)
    stem = Path(row_p['file']).name.replace('.dc.html', '')
    rp = f"{row_p['canvas'].as_posix()}/renders/{stem}-{state}.png" if state else None
    rh = f"{row_h['canvas'].as_posix()}/renders/{Path(row_h['file']).name.replace('.dc.html', '')}-{state}.png" if state else None
    if rp and blob_id(full, rp) and blob_id(head, rh):
        render = 'identical' if blob_id(full, rp) == blob_id(head, rh) else 'changed'
    else:
        render = 'n/a'
    if (same_bytes or (not ids and aside)) and not toks:
        verdict = 'clean' if path_p == path_h else 'moved'
    else:
        verdict = 'drift'
    commits = []
    if verdict == 'drift':
        rc, out = git('log', '--follow', '--format=%h %s', f'{full}..{head}', '--', path_h)
        commits = [l[:90] for l in out.decode().splitlines()]
    res = {**base, 'meta_only': meta_only, 'commits': commits, 'verdict': verdict, 'path_pin': path_p, 'path_head': path_h,
           'ids': ids, 'scoped_out': aside, 'granularity': 'state' if scoped else 'file', 'tokens': toks, 'render': render}
    if state and state not in row_p['states']:
        res['note'] = f'{state} is not a state in the registry at the pin'
    return res


def main(argv):
    global ROOT, DESIGN, CARDS
    head_arg, as_json, paths, i = 'HEAD', False, [], 1
    while i < len(argv):
        a = argv[i]
        if a == '--head':
            head_arg = argv[i + 1]; i += 1
        elif a == '--json':
            as_json = True
        elif a in ('--root', '--design', '--cards') and i + 1 < len(argv):
            v = argv[i + 1]; i += 1
            if a == '--root':
                ROOT = Path(v).resolve()
            elif a == '--design':
                DESIGN = v.strip('/')
            else:
                CARDS = v
        elif a.startswith('--'):
            sys.exit(__doc__)
        else:
            paths.append(a)
        i += 1
    head = rev(head_arg)
    if not head:
        sys.exit(f'pin-drift: {head_arg} is not a commit')
    results, skipped = [], []
    for card in cards(paths):
        kind, items = pins_of(card)
        cid = re.match(r'([A-Z]+-\d+)', card.name)
        cid = cid.group(1) if cid else card.stem
        if kind is None or kind == 'none' or not items:
            skipped.append(f'{cid} (design: {kind or "absent"})')
            continue
        for ux, st, pin in items:
            results.append(check(cid, ux, st, pin, head))
    if as_json:
        for r in results:
            print(json.dumps(r, sort_keys=True))
        return 0
    print(f'pin-drift against {head_arg} ({head[:7]})')
    for r in results:
        loc = r.get('path_head') or r.get('path_pin') or ''
        extra = ''
        if r['verdict'] == 'drift':
            extra = (' [per-file: no data-state marks]' if r.get('granularity') == 'file' and r.get('state') else '') + ' ids: ' + (' '.join(r['ids'][:10]) + (f' (+{len(r["ids"]) - 10} more)' if len(r['ids']) > 10 else '') if r['ids'] else '(none: tokens only)')
            if r['tokens']:
                extra += ' tokens: ' + ' '.join(r['tokens'])
            if r.get('commits'):
                extra += ' | since the pin: ' + ' / '.join(c.split(' ', 1)[0] for c in r['commits'])
        elif r['verdict'] == 'clean' and r.get('scoped_out'):
            extra = f" (changed only under other states: {' '.join(r['scoped_out'][:6])})"
        elif r['verdict'] == 'clean' and r.get('meta_only'):
            extra = ' (only data-stories differs: registry bookkeeping)'
        elif r['verdict'] == 'moved':
            extra = f" {r['path_pin']} -> {r['path_head']}"
        elif r.get('why'):
            extra = ' ' + r['why']
        print(f"{r['card']:9} {r['ux']}#{r.get('state') or '*'}@{(r['pin'] or '-')[:7]:8} {r['verdict']:10}" + (f" render:{r['render']}" if 'render' in r else '') + (f' {Path(loc).name}' if loc and r['verdict'] in ('clean', 'drift') else '') + extra)
    counts = {}
    for r in results:
        counts[r['verdict']] = counts.get(r['verdict'], 0) + 1
    print('pin-drift: ' + (', '.join(f'{v} {n}' for v, n in sorted(counts.items())) or 'no pinned states') +
          (f'; not pinned: {", ".join(skipped)}' if skipped else ''))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
