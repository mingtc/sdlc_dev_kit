#!/usr/bin/env python3
# KIT-CLASS: KIT — design tool: report on the links between PRD stories, design screens and cards. A report, never a gate.
"""check-design-links.py -- report on the links between PRD stories and design screens, in both directions.

usage: check-design-links.py [REPO_ROOT] [--requirements DIR] [--design DIR] [--cards DIR] [--registry-name NAME]
                             [--project-subdir NAME] [--strict] [--leaving CARD]
  REPO_ROOT     default: the working directory
  --requirements  default requirements        PRD-*.md live here
  --design        default <requirements>/design   <canvas>/<registry-name> files live under it
  --cards         default progress            card shelves (<cards>/<shelf>/*.md); skipped when absent
  --registry-name default CANVAS.md           --project-subdir default project (the canvas files, beside the registry)
  --strict        exit 1 when there is any finding other than the info classes (default: exit 0, it is a report)
  --leaving CARD  the check to run before the board mover takes CARD out of todo/ (repeatable): reads it as past todo/ and
                  reports only that card's findings (UNPINNED, BARE-PIN, UNRESOLVED, NOT-APPROVED); exit 1 on any, 2 for a
                  card it cannot read

Reads
  PRD-*.md                 stories (headings `F<n>-S<n>`, full id PRD-NNN-F<n>-S<n>), ACs (`- [ ] AC<n>: (UI) ...`), a story's
                           `UI:` field, `Design: pending` lines, and citations `[design: UX-NNN]` / `[design: UX-NNN#state]`
  <canvas>/CANVAS.md       the screen registry: a table whose header names the columns (any order). Needed: UX-id, file,
                           states, stories. Optional: title, platform, pair, status or gate1/gate2.
  <canvas>/project/*.dc.html   optional: data-ux / data-stories on the artboard root, and the colours outside its :root block
  <cards>/<shelf>/*.md     the `design:` frontmatter key of each card (pins `UX-NNN#state@<commit>`)
A marker inside a code span or a fenced block is prose and is ignored.

Reports (each line starts with its class)
  UNCOVERED     an AC tagged (UI) with no `[design: ...]` marker on its own line (the story is `Design: pending`: said so)
  NO-ROW        a story with a (UI) AC, not `Design: pending`, that no registry row lists
  UNRESOLVED    a citation whose UX id has no row, whose #state the row does not list, or that is not UX-NNN[#state]
                (a range such as UX-001..003 is not a citation); also a card pin that does not resolve, or whose commit does not
  NO-STORY      a registry row that cites no story
  GHOST-STORY   a registry row citing a story no PRD defines
  STALE-PENDING a `Design: pending` section that already holds a marker or whose stories already have a row
  BARE-PIN      a card's `design:` item `UX-NNN` without #state: a bare id means "any state" and is never pinned
  UNPINNED      a card past the first shelf (`todo`) whose design item has no @<commit>
  NOT-APPROVED  (only with --leaving) a pinned row whose gate1 is not approved, and the card's `design:` line carries no
                `[decision: D-NN]` waiver
  UI-MISMATCH   a story whose `UI:` field says none while one of its ACs is tagged (UI)
  PAIR          a row's `pair` names a row that is missing or does not name it back
  STALE-APPROVAL a gate cell `approved@<sha>` whose artboard differs at HEAD from its bytes at <sha> (the root's data-stories
                aside); the row goes back to review. Needs git; skipped outside a repository or for a sha that is not a commit
  APPROVAL-NO-SHA a gate cell that says `approved` with no @<sha>
  SUPERSEDED    a citation of a superseded screen        DUPLICATE  one UX id on two rows
  ARTBOARD      an artboard's data-ux / data-stories disagrees with its row (only when the file exists)
  LITERAL-COLOUR an artboard holding a colour literal (#hex, rgb(), hsl()) outside its :root block and its component script;
                the :root block is where a screen holds its tokens' values, so it is exempt
  REGISTRY      a malformed registry row
  UNCITED       info: a row no PRD cites
  UNCLASSIFIED  info: a PRD with no `UI:` line in any story ("not design-classified"), or the stories of a PRD that has some
                and these lack it. Never a finding: a story with no `UI:` line reads as none declared
Python 3 standard library only.
"""
import argparse, re, subprocess, sys
from pathlib import Path

CITE = re.compile(r'\[design:\s*([^\]]+)\]')
CODESPAN = re.compile(r'`[^`]*`')
UXREF = re.compile(r'^(UX-\d+)(?:#([A-Za-z0-9_-]+))?$')
STORY_ROW = re.compile(r'^\s*\|\s*(F\d+-S\d+)\s*\|', re.M)
STORY_HEAD = re.compile(r'^#{3,6}\s*(F\d+-S\d+)\b', re.M)
STORY_H = re.compile(r'^(#{3,6})\s*(F\d+-S\d+)\b')
FULL_STORY = re.compile(r'PRD-\d+-F\d+-S\d+')
AC_LINE = re.compile(r'^\s*[-*]\s*(?:\[[ xX]\]\s*)?(AC\d+)\b(.{0,24})')
PENDING = re.compile(r'^design\s*:\s*pending\b', re.I)
UI_FIELD = re.compile(r'^ui\s*:\s*(.*)$', re.I)
PIN_ITEM = re.compile(r'(UX-\d+)(?:#([A-Za-z0-9_-]+))?(?:@([0-9a-fA-F]{7,40}))?')
KNOWN = ['ux-id', 'file', 'title', 'platform', 'pair', 'states', 'stories', 'status', 'gate1', 'gate2']
REGISTRY_NAME, PROJECT_SUBDIR = 'CANVAS.md', 'project'


META = re.compile(r' data-stories="[^"]*"')
ROOT_BLOCK = re.compile(r':root\s*\{[^}]*\}')
SCRIPT_BLOCK = re.compile(r'<script\b.*?</script>', re.S | re.I)
COLOUR = re.compile(r'(?<![\w&])#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3,4})(?![\w-])|\b(?:rgba?|hsla?)\(')
INFO_CLASSES = ('UNCITED', 'UNCLASSIFIED')


def literal_colours(html):
    """The colour literals of an artboard outside its :root block (where it holds its tokens' values) and its component script.
    A `#name` that follows href=" or url( is a reference, not a colour."""
    body = SCRIPT_BLOCK.sub(' ', ROOT_BLOCK.sub(' ', html))
    return [m.group(0) for m in COLOUR.finditer(body) if not body[max(0, m.start() - 6):m.start()].endswith(('href="', "href='", 'url('))]


def git_blob(root, rev, path):
    r = subprocess.run(['git', '-C', str(root), 'show', f'{rev}:{path}'], capture_output=True)
    return r.stdout.decode('utf-8', 'replace') if r.returncode == 0 else None


def stale_approvals(root, r):
    """[line, ...] for the gate cells of registry row r that are approvals gone stale or carrying no sha."""
    out = []
    art = (r['canvas'] / PROJECT_SUBDIR / r['file'])
    try:
        rel = art.relative_to(root).as_posix()
    except ValueError:
        return out
    for gate, val in sorted(r['gates'].items()):
        m = re.fullmatch(r'approved(?:@([0-9a-f]{7,40}))?', val)
        if not m:
            continue
        if not m.group(1):
            out.append(f"APPROVAL-NO-SHA {r['where']}: {r['ux']} {gate} says `approved` with no @<sha>")
            continue
        then, now = git_blob(root, m.group(1), rel), git_blob(root, 'HEAD', rel)
        if then is None or now is None:
            continue
        if META.sub('', then) != META.sub('', now):
            out.append(f"STALE-APPROVAL {r['where']}: {r['ux']} {gate} approved@{m.group(1)[:7]}, but {rel} differs at HEAD; back to review")
    return out


def is_commit(root, rev):
    r = subprocess.run(['git', '-C', str(root), 'rev-parse', '--verify', '--quiet', f'{rev}^{{commit}}'], capture_output=True)
    return r.returncode == 0


def split_row(line):
    cells = re.split(r'(?<!\\)\|', line.strip())
    return [c.strip() for c in cells[1:-1]] if line.strip().startswith('|') else []


def head_name(c):
    n = re.sub(r'\s*\(.*\)', '', c).strip().lower().replace(' ', '-')
    return n if n in KNOWN else None


def read_registry(canvas_md, root):
    """(rows, problems) for one registry file on disk (see parse_registry)."""
    return parse_registry(canvas_md.read_text(encoding='utf-8'), str(canvas_md.relative_to(root)), canvas_md.parent)


def parse_registry(text, label, canvas):
    """(rows, problems) from registry text. A registry may hold several tables, one per product area; a table is the
    registry's when its header names `ux-id`, `file`, `states` and `stories`. Columns are found by name, so a table may
    add columns (pair, gate1, gate2) or keep the single `status`."""
    rows, problems, cols = [], [], None
    for n, line in enumerate(text.splitlines(), 1):
        cells = split_row(line)
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
            'states': set(re.findall(r'[A-Za-z0-9_-]+', get('states'))) - {'none', 'n', 'a'},
            'stories': FULL_STORY.findall(get('stories')), 'status': status,
            'superseded': 'superseded' in ([get('status').strip('`* ').lower()] + list(gates.values())),
            'where': f'{label}:{n}', 'canvas': canvas,
        })
    return rows, problems


def prd_lines(path):
    """[(line_no, text)] with fenced blocks removed (a fenced marker is prose)."""
    out, fence = [], False
    for n, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        if re.match(r'^\s*(```|~~~)', line):
            fence = not fence
            continue
        if not fence:
            out.append((n, line))
    return out


def markers_in(line):
    """[ref, ...] of the citations on a line, code spans removed; the template placeholder UX-NNN skipped."""
    out = []
    for m in CITE.finditer(CODESPAN.sub('', line)):
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


def card_pins(card):
    """([(ux, state, pin)], waived) from the `design:` frontmatter key, or (None, False) when the key is absent. `waived` is
    a `[decision: D-NN]` in the line's trailing comment: the ruling that lets a pin cite a row not yet approved."""
    text = card.read_text(encoding='utf-8')
    m = re.search(r'^---\n(.*?)\n---', text, re.S | re.M)
    if not m:
        return None, False
    for line in m.group(1).splitlines():
        if line.startswith('design:'):
            body = re.sub(r'\s#\s.*$', '', line[len('design:'):])   # a trailing ` # comment` is not a pin
            waived = bool(re.search(r'\[decision:\s*D-\d+\]', line))
            return [(x.group(1), x.group(2), x.group(3)) for x in PIN_ITEM.finditer(body)], waived
    return None, False


def analyse(root, requirements='requirements', design=None, cards='progress', leaving=()):
    """-> (findings [str], counts dict)."""
    req = root / requirements
    dsn = root / (design or f'{requirements}/design')
    out, prds = [], sorted(req.glob('PRD-*.md'))
    scans = {}
    for p in prds:
        m = re.match(r'(PRD-\d+)', p.name)
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
            out.append(f"DUPLICATE     {r['ux']} on {by_ux[r['ux']]['where']} and {r['where']}")
        by_ux.setdefault(r['ux'], r)
        for s in r['stories']:
            by_story.setdefault(s, []).append(r['ux'])

    cited, ncites = set(), 0

    def check_ref(where, ref):
        nonlocal ncites
        ncites += 1
        mm = UXREF.match(ref)
        if not mm:
            out.append(f'UNRESOLVED    {where}: `{ref}` is not UX-NNN or UX-NNN#state')
            return
        ux, st = mm.groups()
        row = by_ux.get(ux)
        if row is None:
            out.append(f'UNRESOLVED    {where}: {ux} has no registry row')
            return
        cited.add(ux)
        if st and st not in row['states']:
            out.append(f"UNRESOLVED    {where}: {ux}#{st} - the registry lists states {sorted(row['states']) or 'none'}")
        if row['superseded']:
            out.append(f'SUPERSEDED    {where}: {ux} is superseded')

    for p, sc in scans.items():
        rel = p.relative_to(root)
        for story, n, ref in sc['markers']:
            check_ref(f'{rel}:{n}', ref)
        pending_story = {s for s, v in sc['stories'].items() if any(a <= v['head'] <= b for _, a, b in sc['pending'])}
        for s, v in sorted(sc['stories'].items()):
            ui_acs = [a for a in v['acs'] if a['ui']]
            for a in ui_acs:
                if not a['refs']:
                    why = ' (story is `Design: pending`)' if s in pending_story else ''
                    why += ' - the story Notes cite a screen; move the marker onto the AC line' if v['notes_cite'] else ''
                    out.append(f"UNCOVERED     {rel}:{a['line']}: {s} {a['ac']} (UI) has no [design: ...] marker{why}")
            if v['ui_field'] is not None and re.match(r'^none\b', v['ui_field']) and ui_acs:
                out.append(f"UI-MISMATCH   {rel}:{v['head']}: {s} says `UI: none` but {ui_acs[0]['ac']} is tagged (UI)")
            ui_story = bool(ui_acs) or (v['ui_field'] not in (None, '') and not re.match(r'^(none|n/a)\b', v['ui_field'] or ''))
            if ui_story and s not in by_story and s not in pending_story:
                out.append(f'NO-ROW        {rel}:{v["head"]}: {s} has UI but no registry row lists it')
        for n, a, b in sc['pending']:
            inside = [m for m in sc['markers'] if a <= m[1] <= b and m[1] != n]
            rowed = [s for s, v in sc['stories'].items() if a <= v['head'] <= b and s in by_story]
            if inside or rowed:
                what = f'{len(inside)} marker(s)' if inside else f'a registry row for {rowed[0]}'
                out.append(f'STALE-PENDING {rel}:{n}: `Design: pending` but the section already has {what}')
        headed = {s: v for s, v in sc['stories'].items() if v['head']}
        bare = [s.rsplit('-', 2)[1] + '-' + s.rsplit('-', 2)[2] for s, v in sorted(headed.items()) if v['ui_field'] is None]
        if bare and len(bare) == len(headed):
            out.append(f'UNCLASSIFIED  {rel}: not design-classified: no story carries a UI: line (info)')
        elif bare:
            out.append(f"UNCLASSIFIED  {rel}: not design-classified: {', '.join(bare)} carry no UI: line (info)")

    for r in rows:
        if not r['stories']:
            out.append(f"NO-STORY      {r['where']}: {r['ux']} cites no story")
        for s in r['stories']:
            if s not in all_stories:
                out.append(f"GHOST-STORY   {r['where']}: {r['ux']} cites {s}, which no PRD defines")
        if r['ux'] not in cited and not r['superseded']:
            out.append(f"UNCITED       {r['where']}: {r['ux']} is cited by no PRD (info)")
        for pr in r['pair']:
            o = by_ux.get(pr)
            if o is None:
                out.append(f"PAIR          {r['where']}: {r['ux']} pairs with {pr}, which has no row")
            elif r['ux'] not in o['pair']:
                out.append(f"PAIR          {r['where']}: {r['ux']} pairs with {pr}, which does not name {r['ux']} back")
        out.extend(stale_approvals(root, r))
        art = r['canvas'] / PROJECT_SUBDIR / r['file']
        if art.is_file():
            html = art.read_text(encoding='utf-8')
            mu, ms = re.search(r'data-ux="([^"]*)"', html), re.search(r'data-stories="([^"]*)"', html)
            if not mu:
                out.append(f"ARTBOARD      {art.relative_to(root)}: no data-ux (registry says {r['ux']})")
            elif mu.group(1) != r['ux']:
                out.append(f"ARTBOARD      {art.relative_to(root)}: data-ux={mu.group(1)}, registry says {r['ux']}")
            if not ms:
                out.append(f"ARTBOARD      {art.relative_to(root)}: no data-stories")
            elif set(ms.group(1).split()) != set(r['stories']):
                out.append(f"ARTBOARD      {art.relative_to(root)}: data-stories {sorted(ms.group(1).split())} != registry {sorted(r['stories'])}")
            lits = literal_colours(html)
            if lits:
                out.append(f"LITERAL-COLOUR {art.relative_to(root)}: {', '.join(lits[:4])}{' ...' if len(lits) > 4 else ''} outside :root; use a token")

    ncards = 0
    cdir = root / cards
    if cdir.is_dir():
        for shelf in sorted(d for d in cdir.iterdir() if d.is_dir()):
            for card in sorted(shelf.glob('*.md')):
                pins, waived = card_pins(card)
                if not pins:
                    continue
                ncards += 1
                where = str(card.relative_to(root))
                for ux, st, pin in pins:
                    if st is None:
                        out.append(f'BARE-PIN      {where}: {ux} has no #state; a bare id is never pinned')
                    if (shelf.name != 'todo' or where in leaving) and not pin:
                        out.append(f'UNPINNED      {where}: {ux}{"#" + st if st else ""} has no @<commit> on a card past todo/')
                    row = by_ux.get(ux)
                    if row is None:
                        out.append(f'UNRESOLVED    {where}: pinned {ux} has no registry row')
                    elif st and st not in row['states']:
                        out.append(f'UNRESOLVED    {where}: pinned {ux}#{st}: the registry lists {sorted(row["states"]) or "none"}')
                    if where in leaving:
                        if pin and not is_commit(root, pin):
                            out.append(f'UNRESOLVED    {where}: pin @{pin} of {ux}{"#" + st if st else ""} is not a commit')
                        if row is not None and not waived and not row['gates'].get('gate1', '').startswith('approved'):
                            out.append(f"NOT-APPROVED  {where}: {ux} gate1 is `{row['gates'].get('gate1') or 'absent'}`, not approved, and the design: line carries no [decision: D-NN] waiver")
    for p in problems:
        out.append(f'REGISTRY      {p}')
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
        out, _ = analyse(root, a.requirements, a.design, a.cards, tuple(want))
        out = [l for l in out if any(f' {w}:' in l for w in want)]
        for line in out:
            print(line)
        print(f'design-links: {len(want)} card(s) leaving todo/; {len(out)} finding(s)')
        return 1 if out else 0
    out, c = analyse(root, a.requirements, a.design, a.cards)
    for line in out:
        print(line)
    n = sum(1 for l in out if not l.startswith(INFO_CLASSES))
    print(f"design-links: {c['rows']} registry row(s), {c['citations']} citation(s), {c['stories']} story(ies) in {c['prds']} PRD(s), "
          f"{c['cards']} pinned card(s); {n} finding(s)")
    return 1 if (a.strict and n) else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
