#!/usr/bin/env python3
# KIT-CLASS: KIT — design tool: judge the design rows of a QA verdict against the trunk's record.
"""check-design-cell.py -- is a design cell of a QA verdict well formed, does the trunk hold what it points at, and has every UI AC a row?

usage: check-design-cell.py REPO TRUNK CARD-ID AC-ID CELL       judge one PASS row of kind `design`
       check-design-cell.py --rows REPO TRUNK CARD-ID           judge that every (UI) AC has its design row

  REPO     the git repository;  TRUNK  the trunk commit (the card and the evidence images are read there, never from a branch or the
           working tree: QA commits both to the trunk before landing)
  CARD-ID  the card whose verdict this is, a card or a slice (read at TRUNK, under progress/);  AC-ID  the row;  CELL  its pointer cell

A cell is one entry per pinned state, then the images:

  UX-NNN#state@<pin>: identical; dev/evidence/<CARD-ID>/UX-NNN-state-pin.png, dev/evidence/<CARD-ID>/UX-NNN-state-build.png

and is refused (exit 1, the reasons printed) unless, for every entry:
  * the verdict is `identical`: the check runs on PASS rows, and a PASS row names no difference (a `diffs: <element ids>` entry is
    a FAIL_AC row);
  * <pin> resolves to a commit, and the card at TRUNK carries `UX-NNN#state@<pin>` in its `design:` key;
  * the cell names the entry's pin and build images, under dev/evidence/<CARD-ID>/, and TRUNK holds both, each a PNG (the signature
    and an IHDR with a size), the build image not the pin image;
  * the pin image is, byte for byte, the render the pin commit holds for THAT screen and state
    (the row's canvas, renders/<Screen>-state.png): a row with no image is not a PASS.
--rows: for every AC of the card tagged (UI) or citing [design: UX-NNN#state], the verdict table has a row of evidence kind `design`
whose cell holds one `UX-NNN#state@<pin>` entry per state the AC cites (any entry when the AC cites none); and every `design:` entry
of the card has such an entry in some design row, whatever its ACs say (a card pinned to a screen cannot land without the proof).
Exit 0 and a `design-cell: ok` or `design-rows: ok` line when the answer is yes; 1 when the record is wrong; 2 when it cannot answer
(the card is not at TRUNK, a bad revision). A caller reads no line as no answer: a check that cannot run is a refusal, never a pass.
Python 3 standard library only; reads git, writes nothing.
"""
import importlib.util, re, subprocess, sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location('check_design_links', HERE / 'check-design-links.py')
cdl = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cdl)

ANCHOR = re.compile(r'(UX-\d+)#([A-Za-z0-9_-]+)@([0-9a-fA-F]{7,40}):')
IMAGE = re.compile(r'dev/evidence/[^\s,;]+?\.png')
PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'


def git(repo, *args):
    r = subprocess.run(['git', '-C', repo, '-c', 'core.quotePath=false', *args], capture_output=True)
    return r.returncode, r.stdout


def commit_of(repo, rev):
    rc, out = git(repo, 'rev-parse', '--verify', '--quiet', f'{rev}^{{commit}}')
    return out.decode().strip() if rc == 0 else None


def blob_at(repo, rev, path):
    rc, out = git(repo, 'rev-parse', '--verify', '--quiet', f'{rev}:{path}')
    return out.decode().strip() if rc == 0 else None


def bytes_at(repo, rev, path):
    rc, out = git(repo, 'show', f'{rev}:{path}')
    return out if rc == 0 else None


def png_problem(data):
    """None when data is a PNG (the signature, then an IHDR chunk with a width and a height), else what is wrong."""
    if data is None:
        return 'is not there'
    if len(data) < 33 or data[:8] != PNG_SIGNATURE or data[12:16] != b'IHDR':
        return f'is not a PNG ({len(data)} bytes)'
    if int.from_bytes(data[16:20], 'big') == 0 or int.from_bytes(data[20:24], 'big') == 0:
        return 'is a PNG with no size'
    return None


def card_text(repo, trunk, card_id):
    """The card, or the slice, named by card_id at trunk: progress/<shelf>/<file> or progress/subtasks/<parent>/<shelf>/<file>."""
    rc, out = git(repo, 'ls-tree', '-r', '--name-only', '-z', trunk, '--', 'progress')
    for p in out.decode('utf-8', 'replace').split('\0'):
        parts = p.split('/')
        if not (parts[0] == 'progress' and parts[-1].startswith(card_id + '-') and parts[-1].endswith('.md')):
            continue
        if len(parts) == 3 and parts[1] != 'history' or len(parts) == 5 and parts[1] == 'subtasks':
            rc, body = git(repo, 'show', f'{trunk}:{p}')
            if rc == 0:
                return body.decode('utf-8', 'replace')
    return None


def split_cells(ln):
    cells = re.split(r'(?<!\\)\|', ln.strip())
    return [c.strip().replace('\\|', '|') for c in cells[1:-1]]


def verdict_rows(text):
    """[[cell, ...]] of the data rows of the card's `## QA Verdict` table."""
    out, on = [], False
    for ln in text.splitlines():
        if re.match(r'^## QA Verdict\s*$', ln):
            on = True
            continue
        if on and ln.startswith('## '):
            break
        if on and ln.startswith('|'):
            cells = split_cells(ln)
            if cells and not re.match(r'^(AC id|-+)$', cells[0].replace(':', '')):
                out.append(cells)
    return out


def registry_at(repo, rev):
    """{UX id: row} from every requirements/design/*/CANVAS.md at rev."""
    rc, out = git(repo, 'ls-tree', '-r', '--name-only', '-z', rev, '--', cdl.DESIGN_REL)
    rows = {}
    for p in out.decode('utf-8', 'replace').split('\0'):
        if p.endswith('/' + cdl.REGISTRY_NAME) and Path(p).parent.parent.as_posix() == cdl.DESIGN_REL:
            body = bytes_at(repo, rev, p)
            rr, _ = cdl.parse_registry((body or b'').decode('utf-8', 'replace'), p, Path(p).parent)
            for row in rr:
                rows.setdefault(row['ux'], row)
    return rows


def judge_cell(repo, trunk, card_id, ac, cell, text):
    dv = cdl.design_value(text)
    why = []
    anchors = list(ANCHOR.finditer(cell))
    if not anchors:
        why.append('the design cell holds no `UX-NNN#state@<pin>: identical` entry')
    images = IMAGE.findall(cell)
    for n, m in enumerate(anchors):
        ux, state, pin = m.group(1), m.group(2), m.group(3).lower()
        end = anchors[n + 1].start() if n + 1 < len(anchors) else len(cell)
        verdict = re.split(r'dev/evidence/', cell[m.end():end])[0].strip().rstrip(';,').strip()
        tag = f'{ux}#{state}@{pin[:7]}'
        if verdict != 'identical':
            what = 'names differences' if verdict.startswith('diffs:') else f'reads `{verdict[:40]}`'
            why.append(f'{tag} {what}: a PASS row says `identical`; differences make the row FAIL_AC')
        full = commit_of(repo, pin)
        if not full:
            why.append(f'{tag}: the pin is not a commit of this repository')
        if not any(i[0] == ux and i[1] == state and i[2] and (i[2].startswith(pin) or pin.startswith(i[2])) for i in dv['items']):
            why.append(f'{tag}: the card carries no such entry in its design: key')
        pin_png = f'dev/evidence/{card_id}/{ux}-{state}-pin.png'
        build_png = f'dev/evidence/{card_id}/{ux}-{state}-build.png'
        blobs = {}
        for want in (pin_png, build_png):
            if want not in images:
                why.append(f'{tag}: the cell does not name {want}')
                continue
            data = bytes_at(repo, trunk, want)
            if data is None:
                why.append(f'{tag}: {want} is not committed on the trunk ({trunk[:7]}): QA commits the evidence there first (register-commit.sh)')
                continue
            bad = png_problem(data)
            if bad:
                why.append(f'{tag}: {want} {bad}')
            blobs[want] = blob_at(repo, trunk, want)
        if pin_png in blobs and build_png in blobs and blobs[pin_png] == blobs[build_png]:
            why.append(f'{tag}: the build image is the pin image, byte for byte: it shows nothing of the build')
        if full and pin_png in blobs:
            row = registry_at(repo, full).get(ux)
            if row is None:
                why.append(f'{tag}: the registry at the pin has no row {ux}')
            else:
                stem = Path(row['file']).name.replace('.dc.html', '')
                render = f"{row['canvas'].as_posix()}/renders/{stem}-{state}.png"
                held = blob_at(repo, full, render)
                if held is None:
                    why.append(f'{tag}: the pin commit holds no render {render}; a row with no image is not a PASS')
                elif blobs[pin_png] != held:
                    why.append(f'{tag}: {pin_png} is not the render {render} that the pin commit holds')
    return why


def judge_rows(text):
    why = []
    acs, _ = cdl.card_facts(text)
    rows = verdict_rows(text)
    for ac, refs in acs:
        row = next((r for r in rows if r and r[0] == ac), None)
        if row is None:
            why.append(f'{ac} is tagged (UI) or cites a screen, and the verdict table has no row for it')
            continue
        kind = row[2].strip('`* ').lower() if len(row) > 2 else ''
        if kind != 'design':
            why.append(f'{ac}: its row is of evidence kind `{kind or "none"}`, not `design`')
            continue
        pointer = ' '.join(row[3:])
        got = {(m.group(1), m.group(2)) for m in ANCHOR.finditer(pointer)}
        if not got:
            why.append(f'{ac}: its design row holds no `UX-NNN#state@<pin>` entry')
        for ux, state in refs:
            if (state is None and not any(g[0] == ux for g in got)) or (state is not None and (ux, state) not in got):
                why.append(f'{ac}: its design row has no entry for {ux}{"#" + state if state else ""}, which the AC cites')
    for ux, state, _ in cdl.design_value(text)['items']:
        if state and not any(r[2].strip('`* ').lower() == 'design' and (ux, state) in {(m.group(1), m.group(2)) for m in ANCHOR.finditer(' '.join(r[3:]))}
                             for r in rows if len(r) > 3):
            why.append(f'the card pins {ux}#{state}, and no design row of the verdict table holds an entry for it')
    return why


def main(argv):
    args = argv[1:]
    rows_mode = bool(args) and args[0] == '--rows'
    if rows_mode:
        args = args[1:]
    if len(args) != (3 if rows_mode else 5):
        print(__doc__)
        return 2
    repo, trunk_arg, card_id = args[:3]
    trunk = commit_of(repo, trunk_arg)
    if not trunk:
        print(f'{trunk_arg} is not a commit of {repo}, so the design record cannot be checked.')
        return 2
    text = card_text(repo, trunk, card_id)
    if text is None:
        print(f'the card {card_id} is not under progress/ at {trunk[:7]}, so its design record cannot be read.')
        return 2
    if rows_mode:
        why = judge_rows(text)
        head = f'{card_id}: the design rows are refused:'
    else:
        ac, cell = args[3], args[4]
        why = judge_cell(repo, trunk, card_id, ac, cell, text)
        head = f'{ac}: the design cell is refused:'
    if why:
        print(head)
        for w in why:
            print(f'  - {w}')
        return 1
    print('design-rows: ok' if rows_mode else 'design-cell: ok')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
