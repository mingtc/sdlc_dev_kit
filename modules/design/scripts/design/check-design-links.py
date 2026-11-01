#!/usr/bin/env python3
# KIT-CLASS: KIT — design tool: report on the links between PRD stories, design screens and cards; with --strict, the design-record gate.
"""check-design-links.py -- report on the links between PRD stories and design screens, in both directions.

usage: check-design-links.py [REPO_ROOT] [--requirements DIR] [--design DIR] [--cards DIR] [--registry-name NAME]
                             [--project-subdir NAME] [--strict] [--leaving CARD]
  REPO_ROOT     default: the working directory
  --requirements  default requirements        <PRD_PREFIX>-*.md live here (PRD_PREFIX is read from scripts/config.sh; PRD when absent)
  --design        default <requirements>/design   <canvas>/<registry-name> files live under it
  --cards         default progress            card shelves (<cards>/<shelf>/*.md); skipped when absent. The shelves done, declined
                  and history are not read: a landed card's pin is history and a declined card builds nothing
  --registry-name default CANVAS.md           --project-subdir default project (the canvas files, beside the registry)
  --strict        exit 1 when there is any finding (the report-only classes below are not findings); without it the exit is 0
  --leaving CARD  the check to run before the board mover takes CARD out of todo/ (repeatable): reads the file named, wherever it
                  is, as a card past todo/, and reports only that card's findings; exit 1 on any, 2 for a card it cannot read.
                  It adds, for each pinned state: its commit must resolve, hold the screen's artboard and not predate the row's
                  approval; the row's gate1 must be exactly `approved@<sha>`, still true at HEAD. A `[decision: D-NN]` waiver on the
                  `design:` line stands in for all of that on the screens of that line (an approval gone stale or unresolvable
                  included), if each of its ids is an entry of the register (<requirements>/DECISIONS.md) with a current ruling
                  (not WITHDRAWN). A screen's waiver for a colour literal is the same marker in its registry row

Reads
  <PRD_PREFIX>-*.md        stories (headings `F<n>-S<n>`, full id <PRD_PREFIX>-NNN-F<n>-S<n>), ACs (`- [ ] AC<n>: (UI) ...`), a story's
                           `UI:` field, `Design: pending` lines, and citations `[design: UX-NNN]` / `[design: UX-NNN#state]`
  <canvas>/CANVAS.md       the screen registry: a table whose header names the columns (any order). Needed: UX-id, file,
                           states, stories. Optional: title, platform, pair, status or gate1/gate2.
  <canvas>/project/*.dc.html   optional: data-ux / data-stories on the artboard root, and its colour literals
  <cards>/<shelf>/*.md     the `design:` frontmatter key of each card: `none`, or `[UX-NNN#state@<commit>, ...]`
A marker inside a code span or a fenced block is prose and is ignored.

Reports (each line starts with its class)
  UNCOVERED     an AC tagged (UI) with no `[design: ...]` marker on its own line (the story is `Design: pending`: said so)
  NO-ROW        a story with a (UI) AC, not `Design: pending`, that no registry row lists
  UNRESOLVED    a citation whose UX id has no row, whose #state the row does not list, or that is not UX-NNN[#state]
                (a range such as UX-001..003 is not a citation); also a card pin that does not resolve (no row or state, or a
                commit that is not one)
  NO-STORY      a registry row that cites no story
  GHOST-STORY   a registry row citing a story no PRD defines
  STALE-PENDING a `Design: pending` section that already holds a marker or whose stories already have a row
  BARE-PIN      a card's `design:` item `UX-NNN` without #state: a bare id means "any state" and is never pinned
  UNPINNED      a card past the first shelf (`todo`) whose design item has no @<commit>
  DESIGN-KEY    a card's `design:` value that is not `none` or `[UX-NNN#state@<commit>, ...]`
  NOT-APPROVED  (only with --leaving) a pinned row whose gate1 is not `approved@<sha>`, and no waiver
  PIN-ORDER     (only with --leaving) a pin older than the approval of its row
  UI-MISMATCH   a story whose `UI:` field says none while one of its ACs is tagged (UI)
  PAIR          a row's `pair` names a row that is missing or does not name it back
  GATE-CELL     a gate cell that is not `open`, `changes`, `superseded` or `approved@<sha>`
  APPROVAL-NO-SHA a gate cell that says `approved` with no @<sha>
  APPROVAL-UNRESOLVED a gate cell `approved@<sha>` whose sha is not a commit here (a shallow clone cannot see an older one)
  STALE-APPROVAL a gate cell `approved@<sha>` whose artboard differs at HEAD from its bytes at <sha> (the root's data-stories
                aside), or is missing at either; the row goes back to review
  SUPERSEDED    a citation of a superseded screen        DUPLICATE  one UX id on two rows
  ARTBOARD      an artboard's data-ux / data-stories disagrees with its row (only when the file exists); also a row with an
                approved gate cell whose file is not there
  FENCE         a PRD with a code fence never closed: everything after it is prose to this check
  LITERAL-COLOUR an artboard holding a colour literal (#hex, rgb(), hsl(), oklch() ...) in a style, a presentation attribute or its
                component script, outside its :root block (where a screen holds its tokens' values, so it is exempt), unless the
                screen's registry row carries a `[decision: D-NN]` waiver the register confirms. The way out is a change request
                through the brief to the design tool's agent
  WAIVER        a waiver citing a D-NN the register has no entry for, or that is WITHDRAWN, or no register to check
  REGISTRY      a malformed registry row
Report lines, not findings (shown; never counted, never an exit status):
  UNCITED       a row no PRD cites
  UNCLASSIFIED  a PRD with no `UI:` line in any story ("not design-classified"), or the stories of a PRD that has some and these
                lack it. A story with no `UI:` line reads as none declared
Python 3 standard library only.
"""
import argparse, re, subprocess, sys
from pathlib import Path

PRD_PREFIX = 'PRD'
CITE = re.compile(r'\[design:\s*([^\]]+)\]')
CODESPAN = re.compile(r'`[^`]*`')
UXREF = re.compile(r'^(UX-\d+)(?:#([A-Za-z0-9_-]+))?$')
STORY_ROW = re.compile(r'^\s*\|\s*(F\d+-S\d+)\s*\|', re.M)
STORY_HEAD = re.compile(r'^#{3,6}\s*(F\d+-S\d+)\b', re.M)
STORY_H = re.compile(r'^(#{3,6})\s*(F\d+-S\d+)\b')
AC_LINE = re.compile(r'^\s*[-*]\s*(?:\[[ xX]\]\s*)?(AC\d+)\b(.{0,24})')
PENDING = re.compile(r'^design\s*:\s*pending\b', re.I)
UI_FIELD = re.compile(r'^ui\s*:\s*(.*)$', re.I)
DESIGN_ITEM = re.compile(r'^(UX-\d+)(?:#([A-Za-z0-9_-]+))?(?:@([0-9a-fA-F]{7,40}))?$')
KNOWN = ['ux-id', 'file', 'title', 'platform', 'pair', 'states', 'stories', 'status', 'gate1', 'gate2']
REGISTRY_NAME, PROJECT_SUBDIR = 'CANVAS.md', 'project'
SKIP_SHELVES = ('done', 'declined', 'history')
GATE_CELL = re.compile(r'(open|changes|superseded|approved(?:@([0-9a-f]{7,40}))?)')
REPORT_CLASSES = ('UNCITED', 'UNCLASSIFIED')
WAIVER_MARK = re.compile(r'\[decision:\s*(D-\d+)\]')

META = re.compile(r' data-stories="[^"]*"')
ROOT_BLOCK = re.compile(r':root\s*\{[^}]*\}')
HTML_COMMENT = re.compile(r'<!--.*?-->', re.S)
STYLE_BLOCK = re.compile(r'<style\b[^>]*>(.*?)</style>', re.S | re.I)
STYLE_ATTR = re.compile(r'\bstyle\s*=\s*(["\'])(.*?)\1', re.S | re.I)
PRES_ATTR = re.compile(r'\b(?:fill|stroke|stop-color|flood-color|lighting-color|color|bgcolor)\s*=\s*(["\'])(.*?)\1', re.S | re.I)
SCRIPT_BLOCK = re.compile(r'<script\b.*?</script>', re.S | re.I)
COLOUR_FN = re.compile(r'(?<![\w.-])(?:rgba?|hsla?|hwb|lab|lch|oklab|oklch|color)\(', re.I)
COLOUR_HEX = re.compile(r'(?<![\w&#])#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3,4})(?![\w-])')


def line(cls, msg):
    return cls.ljust(13) + ' ' + msg


def read(path):
    return Path(path).read_text(encoding='utf-8', errors='replace')


def set_prd_prefix(root):
    """PRD_PREFIX from scripts/config.sh, read as text in its declared shape (never sourced); PRD when there is none."""
    global PRD_PREFIX
    cfg = Path(root) / 'scripts' / 'config.sh'
    m = re.search(r'^PRD_PREFIX="\$\{PRD_PREFIX:-([A-Za-z][A-Za-z0-9]*)\}"', read(cfg), re.M) if cfg.is_file() else None
    PRD_PREFIX = m.group(1) if m else 'PRD'
    return PRD_PREFIX


def full_story():
    return re.compile(re.escape(PRD_PREFIX) + r'-\d+-F\d+-S\d+')


def find_prds(root, requirements):
    """The PRD files. Refuses (exit 2) when there are none under PRD_PREFIX and others look like PRDs under another
    prefix: a green `0 PRD(s)` would be a check that read nothing."""
    req = Path(root) / requirements
    prds = sorted(req.glob(f'{PRD_PREFIX}-*.md'))
    if not prds and req.is_dir():
        other = sorted(p.name for p in req.glob('*.md') if re.match(r'^[A-Za-z][A-Za-z0-9]*-\d+-', p.name) and STORY_HEAD.search(read(p)))
        if other:
            print(f'design-links: no {PRD_PREFIX}-*.md in {requirements}/, but {", ".join(other[:3])} hold story headings, so look like PRDs under another prefix; '
                  f'PRD_PREFIX in scripts/config.sh says {PRD_PREFIX}. Nothing was checked.', file=sys.stderr)
            sys.exit(2)
    return prds


def git(root, *args):
    r = subprocess.run(['git', '-C', str(root), *args], capture_output=True)
    return r.returncode, r.stdout


def git_blob(root, rev, path):
    rc, out = git(root, 'show', f'{rev}:{path}')
    return out.decode('utf-8', 'replace') if rc == 0 else None


def is_commit(root, rev):
    return git(root, 'rev-parse', '--verify', '--quiet', f'{rev}^{{commit}}')[0] == 0


def is_ancestor(root, older, newer):
    return git(root, 'merge-base', '--is-ancestor', older, newer)[0] == 0


def same_name_at(root, rev, rel, now):
    """The bytes at `rev` of a file named like `rel` that match `now` (the root's data-stories aside), else None."""
    rc, out = git(root, '-c', 'core.quotePath=false', 'ls-tree', '-r', '--name-only', '-z', rev, '--', str(Path(rel).parents[2]))
    base = Path(rel).name
    for p in out.decode('utf-8', 'replace').split('\0'):
        if p and Path(p).name == base:
            text = git_blob(root, rev, p)
            if text is not None and META.sub('', text) == META.sub('', now):
                return text
    return None


def artboard_rel(root, r):
    try:
        return (r['canvas'] / PROJECT_SUBDIR / r['file']).relative_to(root).as_posix()
    except ValueError:
        return None


def approval_problems(root, r, gates=None):
    """[(class, text)] about the gate cells of registry row r: a cell that is not a state, `approved` with no sha, a sha that is not a
    commit, an artboard missing at the sha or at HEAD, an artboard that differs at HEAD from its bytes at the sha."""
    out, rel = [], artboard_rel(root, r)
    for gate, val in sorted(r['gates'].items()):
        if gates and gate not in gates:
            continue
        m = GATE_CELL.fullmatch(val)
        if not m:
            out.append(('GATE-CELL', f"{r['where']}: {r['ux']} {gate} is `{val or 'empty'}`, not open, changes, superseded or approved@<sha>"))
            continue
        if not val.startswith('approved'):
            continue
        sha = m.group(2)
        if not sha:
            out.append(('APPROVAL-NO-SHA', f"{r['where']}: {r['ux']} {gate} says `approved` with no @<sha>"))
            continue
        if rel is None:
            continue
        if not is_commit(root, sha):
            out.append(('APPROVAL-UNRESOLVED', f"{r['where']}: {r['ux']} {gate} approved@{sha[:7]}: not a commit here (a shallow clone cannot see it)"))
            continue
        then, now = git_blob(root, sha, rel), git_blob(root, 'HEAD', rel)
        if then is None and now is not None:
            then = same_name_at(root, sha, rel, now)       # the canvas moved with its bytes: the approval holds
        if then is None or now is None:
            out.append(('STALE-APPROVAL', f"{r['where']}: {r['ux']} {gate} approved@{sha[:7]}: {rel} is missing at {'that commit' if then is None else 'HEAD'}; back to review"))
        elif META.sub('', then) != META.sub('', now):
            out.append(('STALE-APPROVAL', f"{r['where']}: {r['ux']} {gate} approved@{sha[:7]}, but {rel} differs at HEAD; back to review"))
    return out


def colour_regions(html):
    """The text of an artboard in which a colour literal is a colour: style blocks (their declarations), style attributes,
    presentation attributes and scripts. Outside them `#1042` is copy. The :root block is dropped first: it is exempt."""
    h = ROOT_BLOCK.sub(' ', HTML_COMMENT.sub(' ', html))
    regions = []
    for m in STYLE_BLOCK.finditer(h):
        regions += [b.group(1) for b in re.finditer(r'\{([^{}]*)\}', m.group(1))]
    regions += [m.group(2) for m in STYLE_ATTR.finditer(h)]
    regions += [m.group(2) for m in PRES_ATTR.finditer(h)]
    regions += [m.group(0) for m in SCRIPT_BLOCK.finditer(h)]
    return regions


def literal_colours(html):
    """The colour literals of an artboard outside its :root block, in order, once each. A `#name` after href=" or url( is a reference."""
    found = []
    for reg in colour_regions(html):
        for m in list(COLOUR_FN.finditer(reg)) + list(COLOUR_HEX.finditer(reg)):
            if reg[max(0, m.start() - 6):m.start()].endswith(('href="', "href='", 'url(', "url('", 'url("')):
                continue
            tok = m.group(0)
            if tok not in found:
                found.append(tok)
    return found


def split_row(ln):
    cells = re.split(r'(?<!\\)\|', ln.strip())
    return [c.strip() for c in cells[1:-1]] if ln.strip().startswith('|') else []


def head_name(c):
    n = re.sub(r'\s*\(.*\)', '', c).strip().lower().replace(' ', '-')
    return n if n in KNOWN else None


def read_registry(canvas_md, root):
    """(rows, problems) for one registry file on disk (see parse_registry)."""
    return parse_registry(read(canvas_md), str(canvas_md.relative_to(root)), canvas_md.parent)


def parse_registry(text, label, canvas):
    """(rows, problems) from registry text. A registry may hold several tables, one per product area; a table is the
    registry's when its header names `ux-id`, `file`, `states` and `stories`. Columns are found by name, so a table may
    add columns (pair, gate1, gate2) or keep the single `status`."""
    rows, problems, cols = [], [], None
    fs = full_story()
    for n, ln in enumerate(text.splitlines(), 1):
        cells = split_row(ln)
        if not cells:
            cols = None
            continue
        names = [head_name(c) for c in cells]
        if names and names[0] == 'ux-id':
            cols = {nm: i for i, nm in enumerate(names) if nm} if {'file', 'states', 'stories'} <= set(names) else None
            continue
        if cols is None or set(''.join(cells)) <= set('-: '):
            continue
        if len(cells) < len(names) and len(cells) < max(cols.values()) + 1:
            problems.append(f'{label}:{n}: registry row has {len(cells)} cells, header has {len(names)}')
            continue
        get = lambda k: cells[cols[k]] if k in cols and cols[k] < len(cells) else ''
        ux = re.sub(r'[`*]', '', cells[0])
        if not re.fullmatch(r'UX-\d+', ux):
            continue  # a template/placeholder row such as UX-NNN
        gates = {g: get(g).strip('`* ').lower() for g in ('gate1', 'gate2') if g in cols}
        status = get('status').strip('`* ').lower() or ' / '.join(f'{g} {v}' for g, v in gates.items())
        rows.append({
            'ux': ux, 'file': re.sub(r'[`*]', '', get('file')), 'title': get('title'), 'platform': get('platform'),
            'pair': re.findall(r'UX-\d+', get('pair')), 'gates': gates,
            'states': set() if get('states').strip('`* ').lower() in ('', 'none', 'n/a', '-') else set(re.findall(r'[A-Za-z0-9_-]+', get('states'))),
            'stories': fs.findall(get('stories')), 'status': status,
            'superseded': 'superseded' in ([get('status').strip('`* ').lower()] + list(gates.values())),
            'where': f'{label}:{n}', 'canvas': canvas, 'waivers': WAIVER_MARK.findall(ln),
        })
    return rows, problems


FENCE_OPEN = re.compile(r'^\s*(`{3,}|~{3,})')


def fence_scan(text):
    """-> ([(line_no, text)] outside code fences, the line of a fence never closed or None). A fence closes on a line of the same
    character, at least as long as the opening one and nothing else, so a ``` line inside a ~~~ block is text."""
    out, marker, opened = [], None, None
    for n, ln in enumerate(text.splitlines(), 1):
        m = FENCE_OPEN.match(ln)
        if marker is None:
            if m:
                marker, opened = m.group(1), n
            else:
                out.append((n, ln))
        elif m and m.group(1)[0] == marker[0] and len(m.group(1)) >= len(marker) and ln.strip() == m.group(1):
            marker, opened = None, None
    return out, opened


def prd_lines(path):
    """[(line_no, text)] with fenced blocks removed (a fenced marker is prose)."""
    return fence_scan(read(path))[0]


def unclosed_fence(path):
    """The line of a code fence the PRD never closes, or None."""
    return fence_scan(read(path))[1]


def markers_in(ln):
    """[ref, ...] of the citations on a line, code spans removed; the template placeholder UX-NNN skipped."""
    out = []
    for m in CITE.finditer(CODESPAN.sub('', ln)):
        out += [r for r in re.split(r'[,\s]+', m.group(1).strip()) if r and r != 'UX-NNN']
    return out


def scan_prd(path, prd_id):
    """One pass over a PRD. Returns dict with stories {id: {...}}, pending sections and all markers."""
    lines = prd_lines(path)
    heads = [(n, len(m.group(1)), l) for n, l in lines for m in [re.match(r'^(#{1,6})\s', l)] if m]
    stories, cur, markers, pend = {}, None, [], []
    for n, l in lines:
        hm = re.match(r'^#{1,6}\s', l)
        if hm:
            sm = STORY_H.match(l)
            cur = f'{prd_id}-{sm.group(2)}' if sm else None
            if cur:
                stories.setdefault(cur, {'head': n, 'acs': [], 'ui_field': None, 'notes_cite': False})
            continue
        plain = re.sub(r'[*_]', '', l).strip()
        if PENDING.match(plain):
            hidx = max([i for i, h in enumerate(heads) if h[0] < n] or [-1])
            level = heads[hidx][1] if hidx >= 0 else 0
            start = heads[hidx][0] if hidx >= 0 else 0
            end = next((h[0] for h in heads if h[0] > n and h[1] <= level), 10 ** 9)
            pend.append((n, start, end))
        refs = markers_in(l)
        for r in refs:
            markers.append((cur, n, r))
        if cur:
            am = AC_LINE.match(l)
            if am:
                stories[cur]['acs'].append({'ac': am.group(1), 'line': n, 'ui': '(UI)' in am.group(2), 'refs': refs})
            else:
                um = UI_FIELD.match(plain)
                if um:
                    stories[cur]['ui_field'] = um.group(1).strip().lower()
                if refs:
                    stories[cur]['notes_cite'] = True
    # story tables (| F1-S1 | ... |) define ids too
    text = '\n'.join(l for _, l in lines)
    for sid in set(STORY_ROW.findall(text)):
        stories.setdefault(f'{prd_id}-{sid}', {'head': 0, 'acs': [], 'ui_field': None, 'notes_cite': False})
    return {'stories': stories, 'markers': markers, 'pending': pend}


def design_value(text):
    """The `design:` key of a card's frontmatter. -> {'kind': absent | none | list | bad, 'items': [(ux, state, pin)], 'waivers': [D-NN],
    'raw': the value}. A trailing ` # comment` is not part of the value; a `[decision: D-NN]` in it is a waiver. The value is `none` or a
    bracketed, comma-separated list of UX-NNN[#state][@<commit>]; anything else is `bad`."""
    out = {'kind': 'absent', 'items': [], 'waivers': [], 'raw': ''}
    m = re.search(r'^---\n(.*?)\n---', text, re.S | re.M)
    if not m:
        return out
    for ln in m.group(1).splitlines():
        if not ln.startswith('design:'):
            continue
        out['waivers'] = WAIVER_MARK.findall(ln)
        raw = re.sub(r'\s#\s.*$', '', ln[len('design:'):]).strip()
        out['raw'] = raw
        if raw == 'none':
            out['kind'] = 'none'
        elif raw.startswith('[') and raw.endswith(']'):
            parts = [p.strip() for p in raw[1:-1].split(',')]
            items = [DESIGN_ITEM.match(p) for p in parts]
            if parts != [''] and all(items):
                out['kind'], out['items'] = 'list', [(i.group(1), i.group(2), (i.group(3) or '').lower() or None) for i in items]
            else:
                out['kind'] = 'bad'
        else:
            out['kind'] = 'bad'
        return out
    return out


def register_ids(root, requirements):
    """{D-NN: has a current ruling} for the entries of <requirements>/DECISIONS.md (`### D-NN` headings; an entry whose Ruling
    field opens WITHDRAWN has none), or None when there is no register."""
    f = Path(root) / requirements / 'DECISIONS.md'
    if not f.is_file():
        return None
    entries = {}
    for part in re.split(r'(?m)^(?=#{2,3} )', read(f)):
        m = re.match(r'### (D-\d+)', part)
        if m:
            entries[m.group(1)] = not re.search(r'(?m)^\*\*Ruling\.\*\*\s*WITHDRAWN\b', part)
    return entries


def waiver_problem(register, requirements, ids):
    """Why the waiver ids cannot stand in for an approval or a token, or None: no register, an id with no entry, an entry withdrawn."""
    if register is None:
        return f'waiver {", ".join(ids)} cannot be checked: no {requirements}/DECISIONS.md'
    gone = [d for d in ids if d not in register]
    if gone:
        return f'{", ".join(gone)} is not an entry in {requirements}/DECISIONS.md'
    withdrawn = [d for d in ids if not register[d]]
    if withdrawn:
        return f'{", ".join(withdrawn)} is WITHDRAWN in {requirements}/DECISIONS.md: it has no current ruling'
    return None


def analyse(root, requirements='requirements', design=None, cards='progress', leaving=()):
    """-> (findings [str], counts dict)."""
    set_prd_prefix(root)
    dsn = root / (design or f'{requirements}/design')
    out, prds = [], find_prds(root, requirements)
    scans = {}
    for p in prds:
        m = re.match(r'(' + re.escape(PRD_PREFIX) + r'-\d+)', p.name)
        if m:
            scans[p] = scan_prd(p, m.group(1))
    all_stories = {s for sc in scans.values() for s in sc['stories']}

    rows, problems = [], []
    for c in sorted(dsn.glob(f'*/{REGISTRY_NAME}')):
        r, pr = read_registry(c, root)
        rows += r
        problems += pr
    by_ux, by_story = {}, {}
    for r in rows:
        if r['ux'] in by_ux:
            out.append(line('DUPLICATE', f"{r['ux']} on {by_ux[r['ux']]['where']} and {r['where']}"))
        by_ux.setdefault(r['ux'], r)
        for s in r['stories']:
            by_story.setdefault(s, []).append(r['ux'])

    reg_box = []

    def get_register():
        if not reg_box:
            reg_box.append(register_ids(root, requirements))
        return reg_box[0]

    cited, ncites = set(), 0

    def check_ref(where, ref):
        nonlocal ncites
        ncites += 1
        mm = UXREF.match(ref)
        if not mm:
            out.append(line('UNRESOLVED', f'{where}: `{ref}` is not UX-NNN or UX-NNN#state'))
            return
        ux, st = mm.groups()
        row = by_ux.get(ux)
        if row is None:
            out.append(line('UNRESOLVED', f'{where}: {ux} has no registry row'))
            return
        cited.add(ux)
        if st and st not in row['states']:
            out.append(line('UNRESOLVED', f"{where}: {ux}#{st} - the registry lists states {sorted(row['states']) or 'none'}"))
        if row['superseded']:
            out.append(line('SUPERSEDED', f'{where}: {ux} is superseded'))

    for p, sc in scans.items():
        rel = p.relative_to(root)
        fence = unclosed_fence(p)
        if fence:
            out.append(line('FENCE', f'{rel}:{fence}: a code fence is never closed; everything after it is read as prose'))
        for story, n, ref in sc['markers']:
            check_ref(f'{rel}:{n}', ref)
        pending_story = {s for s, v in sc['stories'].items() if any(a <= v['head'] <= b for _, a, b in sc['pending'])}
        for s, v in sorted(sc['stories'].items()):
            ui_acs = [a for a in v['acs'] if a['ui']]
            for a in ui_acs:
                if not a['refs']:
                    why = ' (story is `Design: pending`)' if s in pending_story else ''
                    why += ' - the story Notes cite a screen; move the marker onto the AC line' if v['notes_cite'] else ''
                    out.append(line('UNCOVERED', f"{rel}:{a['line']}: {s} {a['ac']} (UI) has no [design: ...] marker{why}"))
            if v['ui_field'] is not None and re.match(r'^none\b', v['ui_field']) and ui_acs:
                out.append(line('UI-MISMATCH', f"{rel}:{v['head']}: {s} says `UI: none` but {ui_acs[0]['ac']} is tagged (UI)"))
            ui_story = bool(ui_acs) or (v['ui_field'] not in (None, '') and not re.match(r'^(none|n/a)\b', v['ui_field'] or ''))
            if ui_story and s not in by_story and s not in pending_story:
                out.append(line('NO-ROW', f'{rel}:{v["head"]}: {s} has UI but no registry row lists it'))
        for n, a, b in sc['pending']:
            inside = [m for m in sc['markers'] if a <= m[1] <= b and m[1] != n]
            rowed = [s for s, v in sc['stories'].items() if a <= v['head'] <= b and s in by_story]
            if inside or rowed:
                what = f'{len(inside)} marker(s)' if inside else f'a registry row for {rowed[0]}'
                out.append(line('STALE-PENDING', f'{rel}:{n}: `Design: pending` but the section already has {what}'))
        headed = {s: v for s, v in sc['stories'].items() if v['head']}
        bare = ['-'.join(s.rsplit('-', 2)[1:]) for s, v in sorted(headed.items()) if v['ui_field'] is None]
        if bare and len(bare) == len(headed):
            out.append(line('UNCLASSIFIED', f'{rel}: not design-classified: no story carries a UI: line (info)'))
        elif bare:
            out.append(line('UNCLASSIFIED', f"{rel}: not design-classified: {', '.join(bare)} carry no UI: line (info)"))

    for r in rows:
        if not r['stories']:
            out.append(line('NO-STORY', f"{r['where']}: {r['ux']} cites no story"))
        for s in r['stories']:
            if s not in all_stories:
                out.append(line('GHOST-STORY', f"{r['where']}: {r['ux']} cites {s}, which no PRD defines"))
        if r['ux'] not in cited and not r['superseded']:
            out.append(line('UNCITED', f"{r['where']}: {r['ux']} is cited by no PRD (info)"))
        for pr in r['pair']:
            o = by_ux.get(pr)
            if o is None:
                out.append(line('PAIR', f"{r['where']}: {r['ux']} pairs with {pr}, which has no row"))
            elif r['ux'] not in o['pair']:
                out.append(line('PAIR', f"{r['where']}: {r['ux']} pairs with {pr}, which does not name {r['ux']} back"))
        for cls, text in approval_problems(root, r):
            out.append(line(cls, text))
        art = r['canvas'] / PROJECT_SUBDIR / r['file']
        if art.is_file():
            html = read(art)
            mu, ms = re.search(r'data-ux="([^"]*)"', html), re.search(r'data-stories="([^"]*)"', html)
            if not mu:
                out.append(line('ARTBOARD', f"{art.relative_to(root)}: no data-ux (registry says {r['ux']})"))
            elif mu.group(1) != r['ux']:
                out.append(line('ARTBOARD', f"{art.relative_to(root)}: data-ux={mu.group(1)}, registry says {r['ux']}"))
            if not ms:
                out.append(line('ARTBOARD', f"{art.relative_to(root)}: no data-stories"))
            elif set(ms.group(1).split()) != set(r['stories']):
                out.append(line('ARTBOARD', f"{art.relative_to(root)}: data-stories {sorted(ms.group(1).split())} != registry {sorted(r['stories'])}"))
            lits = literal_colours(html)
            if lits:
                problem = waiver_problem(get_register(), requirements, r['waivers']) if r['waivers'] else 'no waiver'
                if problem:
                    out.append(line('LITERAL-COLOUR', f"{art.relative_to(root)}: {', '.join(lits[:4])}{' ...' if len(lits) > 4 else ''} outside :root; send a change request through the brief, do not edit the screen"))
                    if r['waivers']:
                        out.append(line('WAIVER', f"{r['where']}: {problem}"))
        elif any(v.startswith('approved') for v in r['gates'].values()):
            out.append(line('ARTBOARD', f"{r['where']}: {r['ux']} has an approved gate cell but {art.relative_to(root)} is not there"))

    # the cards: every shelf not landed or declined, then any card named by --leaving wherever it sits
    paths = []
    cdir = root / cards
    if cdir.is_dir():
        for shelf in sorted(d for d in cdir.iterdir() if d.is_dir() and d.name not in SKIP_SHELVES):
            paths += [(shelf.name, c) for c in sorted(shelf.glob('*.md'))]
    seen = {str(c.relative_to(root)) for _, c in paths}
    paths += [('todo', root / w) for w in sorted(set(leaving) - seen)]
    ncards = 0
    for shelf_name, card in paths:
        dv = design_value(read(card))
        if dv['kind'] in ('absent', 'none'):
            continue
        where = str(card.relative_to(root))
        leave = where in leaving
        if dv['kind'] == 'bad':
            out.append(line('DESIGN-KEY', f"{where}: design: `{dv['raw'] or 'empty'}` is not none or [UX-NNN#state@<commit>, ...]"))
            continue
        ncards += 1
        waived = bool(dv['waivers'])
        if leave and waived:
            problem = waiver_problem(get_register(), requirements, dv['waivers'])
            if problem:
                out.append(line('WAIVER', f'{where}: {problem}'))
                waived = False
        for ux, st, pin in dv['items']:
            tag = f'{ux}#{st}' if st else ux
            if st is None:
                out.append(line('BARE-PIN', f'{where}: {ux} has no #state; a bare id is never pinned'))
            if (shelf_name != 'todo' or leave) and not pin:
                out.append(line('UNPINNED', f'{where}: {tag} has no @<commit> on a card past todo/'))
            row = by_ux.get(ux)
            if row is None:
                out.append(line('UNRESOLVED', f'{where}: pinned {ux} has no registry row'))
            elif st and st not in row['states']:
                out.append(line('UNRESOLVED', f'{where}: pinned {tag}: the registry lists {sorted(row["states"]) or "none"}'))
            pin_ok = bool(pin) and is_commit(root, pin)
            if pin and not pin_ok:
                out.append(line('UNRESOLVED', f'{where}: pin @{pin} of {tag} is not a commit'))
            if not leave or row is None:
                continue
            rel = artboard_rel(root, row)
            if pin_ok and rel and git(root, 'cat-file', '-e', f'{pin}:{rel}')[0] != 0:
                out.append(line('UNRESOLVED', f'{where}: pin @{pin[:7]} of {tag} holds no {rel}'))
            g1 = row['gates'].get('gate1', '')
            sha = re.fullmatch(r'approved@([0-9a-f]{7,40})', g1)
            if not sha and not waived:
                out.append(line('NOT-APPROVED', f"{where}: {ux} gate1 is `{g1 or 'absent'}`, not approved@<sha>, and the design: line carries no waiver the register confirms"))
            elif sha and not waived:
                for cls, text in approval_problems(root, row, ('gate1',)):
                    out.append(line(cls, text.replace(f"{row['where']}:", f'{where}:', 1)))
                if pin_ok and is_commit(root, sha.group(1)) and not is_ancestor(root, sha.group(1), pin) and not waived:
                    out.append(line('PIN-ORDER', f'{where}: pin @{pin[:7]} of {tag} is older than the approval @{sha.group(1)[:7]} of its row'))
    for p in problems:
        out.append(line('REGISTRY', p))
    counts = {'rows': len(rows), 'citations': ncites, 'stories': len(all_stories), 'prds': len(prds), 'cards': ncards}
    return out, counts


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('root', nargs='?', default='.')
    ap.add_argument('--requirements', default='requirements')
    ap.add_argument('--design')
    ap.add_argument('--cards', default='progress')
    ap.add_argument('--registry-name', default='CANVAS.md')
    ap.add_argument('--project-subdir', default='project')
    ap.add_argument('--strict', action='store_true')
    ap.add_argument('--leaving', metavar='CARD', action='append', default=[])
    a = ap.parse_args(argv[1:])
    global REGISTRY_NAME, PROJECT_SUBDIR
    REGISTRY_NAME, PROJECT_SUBDIR = a.registry_name, a.project_subdir
    root = Path(a.root).resolve()
    if a.leaving:
        # the check before a card leaves todo/: read each named card as if it were past todo/, report only its findings
        want = set()
        for cp in a.leaving:
            p = Path(cp)
            p = p if p.is_absolute() else Path.cwd() / p
            if not p.is_file():
                print(f'design-links: --leaving {cp}: not a file', file=sys.stderr)
                return 2
            try:
                want.add(str(p.resolve().relative_to(root)))
            except ValueError:
                print(f'design-links: --leaving {cp}: not inside {root}', file=sys.stderr)
                return 2
        out, _ = analyse(root, a.requirements, a.design, a.cards, tuple(sorted(want)))
        out = [l for l in out if any(f' {w}:' in l for w in want)]
        for ln in out:
            print(ln)
        print(f'design-links: {len(want)} card(s) leaving todo/; {len(out)} finding(s)')
        return 1 if out else 0
    out, c = analyse(root, a.requirements, a.design, a.cards)
    for ln in out:
        print(ln)
    n = sum(1 for l in out if not l.startswith(REPORT_CLASSES))
    reports = len(out) - n
    print(f"design-links: {c['rows']} registry row(s), {c['citations']} citation(s), {c['stories']} story(ies) in {c['prds']} PRD(s), "
          f"{c['cards']} pinned card(s); {n} finding(s)" + (f', {reports} report line(s)' if reports else ''))
    return 1 if (a.strict and n) else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
