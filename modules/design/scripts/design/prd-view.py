#!/usr/bin/env python3
# KIT-CLASS: KIT — design tool: per-PRD view of the design record, derived from the registry and the PRD's markers, never kept by hand.
"""prd-view.py -- every screen and state one PRD's stories reach, from the registry AND from the PRD's own markers.

usage: prd-view.py <PRD_PREFIX>-NNN [--md] [--root REPO_ROOT] [--requirements DIR] [--design DIR]

  default   print the view on stdout
  --md      also write <design>/views/PRD-NNN.md (GENERATED; the file says so; never hand-edit it, rerun this script)
  --root    default: the working directory;  --requirements default `requirements`;  --design default `<requirements>/design`

Two sources, compared:
  registry   <design>/*/CANVAS.md rows whose `stories` column holds a story id of this PRD
  markers    `[design: UX-NNN#state]` on the lines of this PRD's stories (an AC line, or a story's Notes);
             a marker in a code span or fenced block is prose and is ignored (as check-design-links.py does); a bare `UX-NNN`
             covers every state of the screen

Disagreements flagged (each line starts with its class):
  REGISTRY-ONLY  the registry row lists story S of this PRD, but no marker of S cites that screen
  MARKER-ONLY    story S has a marker citing screen U, but U's registry row does not list S
  NO-ROW         a marker cites a screen with no registry row
  NO-STATE       a marker cites a state the registry row does not list
  STATE-UNCITED  info: a state of a screen this PRD reaches that none of this PRD's markers cites
A screen is never "owned" by the PRD: the view also names the other PRDs whose stories sit on the same row.
Python 3 standard library only. Exit 0 once the view is printed (a report); 1 for an argument that is not a PRD id or a PRD it cannot find.
"""
import argparse, importlib.util, re, sys
from pathlib import Path

sys.dont_write_bytecode = True   # importing the sibling check must leave no __pycache__ in the project
HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location('check_design_links', HERE / 'check-design-links.py')
cdl = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cdl)

STORY_H = re.compile(r'^#{3,6}\s*(F\d+-S\d+)\b')
AC_LINE = re.compile(r'^\s*[-*]\s*(?:\[[ xX]\]\s*)?(AC\d+)\b')
REQ, DESIGN = 'requirements', 'requirements/design'


def read_markers(prd_path, prd_id):
    """[(story_id, ac_or_None, ux, state_or_None, line_no)] for the markers that sit under a story heading."""
    out, story = [], None
    for n, line in cdl.prd_lines(prd_path):
        if re.match(r'^#{1,6}\s', line):
            m = STORY_H.match(line)
            story = f'{prd_id}-{m.group(1)}' if m else None   # any heading that is not a story ends the story
        if story is None:
            continue
        am = AC_LINE.match(line)
        ac = am.group(1) if am else None
        for ref in cdl.markers_in(line):
            mm = cdl.UXREF.match(ref)
            if mm:
                out.append((story, ac, mm.group(1), mm.group(2), n))
    return out


def stories_of(prd_path, prd_id):
    text = '\n'.join(l for _, l in cdl.prd_lines(prd_path))
    return {f'{prd_id}-{s}' for s in set(cdl.STORY_ROW.findall(text)) | set(cdl.STORY_HEAD.findall(text))}


def build(root, prd_id):
    req = root / REQ
    prds = sorted(req.glob(f'{prd_id}-*.md'))
    if not prds:
        sys.exit(f'prd-view: no {REQ}/{prd_id}-*.md')
    prd = prds[0]
    mine = stories_of(prd, prd_id)
    markers = read_markers(prd, prd_id)
    rows = []
    for c in sorted((root / DESIGN).glob(f'*/{cdl.REGISTRY_NAME}')):
        r, _ = cdl.read_registry(c, root)
        rows += r
    by_ux = {r['ux']: r for r in rows}
    screens = {}      # ux -> info
    for r in rows:
        reg = [s for s in r['stories'] if s in mine]
        if reg:
            screens[r['ux']] = {'row': r, 'reg': reg, 'cites': []}
    for (story, ac, ux, st, n) in markers:
        screens.setdefault(ux, {'row': by_ux.get(ux), 'reg': [], 'cites': []})['cites'].append((story, ac, st, n))
    problems = []
    for ux, s in sorted(screens.items()):
        row = s['row']
        cite_stories = {c[0] for c in s['cites']}
        if row is None:
            problems.append(f'NO-ROW         {ux}: cited by {sorted(cite_stories)} but has no registry row')
            continue
        for st in s['reg']:
            if st not in cite_stories:
                problems.append(f'REGISTRY-ONLY  {ux}: registry lists {st}, but no marker of {st} cites {ux}')
        for st in sorted(cite_stories):
            if st not in row['stories']:
                problems.append(f"MARKER-ONLY    {ux}: {st} cites it, but the registry row ({row['where']}) does not list {st}")
        any_state = any(c[2] is None for c in s['cites'])
        cited_states = {c[2] for c in s['cites'] if c[2]}
        for _, _, st, n in s['cites']:
            if st and st not in row['states']:
                problems.append(f"NO-STATE       {ux}#{st}: cited at {prd.name}:{n}; the row lists {sorted(row['states'])}")
        if not any_state:
            for st in sorted(row['states'] - cited_states):
                problems.append(f'STATE-UNCITED  {ux}#{st}: a state of a screen {prd_id} reaches, cited by none of its markers (info)')
    return prd, mine, screens, problems


def path_of(root, row):
    return (row['canvas'] / cdl.PROJECT_SUBDIR / row['file']).relative_to(root).as_posix()


def render(root, prd_id):
    prd, mine, screens, problems = build(root, prd_id)
    L = []
    L.append(f'{prd_id} ({prd.name}): {len(mine)} stories; reaches {len(screens)} screen(s)')
    L.append('')
    L.append('| UX-id | screen | file | status | states cited by ' + prd_id + ' | ' + prd_id + ' stories (registry) | other PRDs on the same row |')
    L.append('|---|---|---|---|---|---|---|')
    for ux, s in sorted(screens.items()):
        r = s['row']
        if r is None:
            L.append(f'| {ux} | (no registry row) | | | | | |')
            continue
        states = sorted({c[2] for c in s['cites'] if c[2]})
        if any(c[2] is None for c in s['cites']):
            states = ['(any state)'] + states
        others = sorted({x.rsplit('-F', 1)[0] for x in r['stories']} - {prd_id})
        L.append(f"| {ux} | {r['title']} | `{path_of(root, r)}` | {r['status']} | {', '.join(states) or 'none'} | "
                 f"{' '.join(x.replace(prd_id + '-', '') for x in s['reg']) or 'none'} | {', '.join(others) or 'none'} |")
    L.append('')
    L.append('## State by state (marker → story AC)')
    L.append('')
    for ux, s in sorted(screens.items()):
        r = s['row']
        if r is None:
            continue
        L.append(f"**{ux}** {r['title']} — `{path_of(root, r)}`")
        by_state = {}
        for story, ac, st, n in s['cites']:
            by_state.setdefault(st or '(any state)', []).append(f"{story.replace(prd_id + '-', '')}{' ' + ac if ac else ''}")
        for st, who in sorted(by_state.items()):
            L.append(f'- `{ux}#{st}`: ' + ', '.join(who))
        L.append('')
    L.append('## Registry and marker disagreements')
    L.append('')
    hard = [p for p in problems if not p.startswith('STATE-UNCITED')]
    info = [p for p in problems if p.startswith('STATE-UNCITED')]
    L += (hard or ['none'])
    L.append('')
    L.append(f'## Info ({len(info)})')
    L.append('')
    L += (info or ['none'])
    return '\n'.join(L) + '\n', hard, info


def main(argv):
    global REQ, DESIGN
    ap = argparse.ArgumentParser(description='per-PRD view of the design record')
    ap.add_argument('prd', help='PRD-NNN')
    ap.add_argument('--md', action='store_true', help='also write <design>/views/PRD-NNN.md (generated)')
    ap.add_argument('--root', default='.')
    ap.add_argument('--requirements', default='requirements')
    ap.add_argument('--design')
    ns = ap.parse_args(argv[1:])
    REQ = ns.requirements
    DESIGN = ns.design or f'{ns.requirements}/design'
    root = Path(ns.root).resolve()
    prefix = cdl.set_prd_prefix(root)
    if not re.fullmatch(re.escape(prefix) + r'-\d+', ns.prd):
        sys.exit(f'prd-view: the argument is a PRD id, {prefix}-NNN (PRD_PREFIX in scripts/config.sh)')
    prd_id = ns.prd
    text, hard, info = render(root, prd_id)
    print(text, end='')
    if ns.md:
        out = root / DESIGN / 'views' / f'{prd_id}.md'
        out.parent.mkdir(parents=True, exist_ok=True)
        head = (f'<!-- GENERATED by prd-view.py {prd_id} --md from the screen registry and the {prd_id} PRD. '
                f'Never hand-edit; rerun the script. -->\n'
                f'# Design view of {prd_id} (generated)\n\n')
        out.write_text(head + text, encoding='utf-8')
        print(f'wrote {out.relative_to(root)}', file=sys.stderr)
    print(f'prd-view: {len(hard)} disagreement(s), {len(info)} info line(s)', file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
