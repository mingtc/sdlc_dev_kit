#!/usr/bin/env python3
# KIT-CLASS: KIT — design tool: makes a pulled canvas's canvas.json and data-props compare byte for byte with what an agent writes.
"""normalise-canvas.py -- one spelling for the two things the canvas's editor re-serialises without changing a value.

usage: normalise-canvas.py PROJECT_DIR [--check]

  PROJECT_DIR  a pulled canvas's project/ folder (canvas.json and the *.dc.html boards)
  --check      write nothing; print what would change; exit 1 if anything would

  canvas.json   keys sorted, two-space indent, a final newline, and an empty "attachments": {} dropped (the editor adds it; absent is empty)
  *.dc.html     the data-props attribute of the board's <script type="text/x-dc" ...> becomes single-quoted compact JSON, key order kept,
                only & and ' escaped; every other byte of the file is left alone

The spelling is the one the design type's format rules ask for: the attribute single-quoted, & as &amp;, a literal ' as &#39;.
Why: a page save rewrote one line's quotes to &quot; and sorted canvas.json, and the drift checks and approvals then read a change where no
value moved. Run it on a pull before the files are compared or committed. It is idempotent. The pulled file's sha and the normalised file's
sha differ when it rewrote anything: the pull records both (see the design-pull skill).
Prints `normalised <path>` per file changed (`would normalise <path>` with --check). A file it cannot parse is named on stderr and left
untouched (`UNREAD <path>: <why>`), never passed as fine.
Exit 0 done or nothing to do (and --help); 1 --check found a file it would change; 2 a file could not be read, or bad usage.
Python 3 standard library only.
"""
import html, json, re, sys
from pathlib import Path

TAG = re.compile(r'''<script\b[^>]*\btype=["']text/x-dc["'][^>]*>''')
ATTR = re.compile(r'''(\bdata-props=)(?:"([^"]*)"|'([^']*)')''')


def canon_props(m):
    raw = m.group(2) if m.group(2) is not None else m.group(3)
    obj = json.loads(html.unescape(raw))
    s = json.dumps(obj, ensure_ascii=False, separators=(',', ':')).replace('&', '&amp;').replace("'", '&#39;')
    return m.group(1) + "'" + s + "'"


def norm_html(text):
    return TAG.sub(lambda t: ATTR.sub(canon_props, t.group(0)), text)


def norm_canvas(text):
    obj = json.loads(text)
    if not isinstance(obj, dict):
        raise ValueError('canvas.json is not a JSON object')
    if obj.get('attachments') == {}:
        del obj['attachments']
    return json.dumps(obj, indent=2, sort_keys=True, ensure_ascii=False) + '\n'


def main(argv):
    if len(argv) == 2 and argv[1] in ('-h', '--help'):
        print(__doc__)
        return 0
    args = [a for a in argv[1:] if a != '--check']
    check = len(args) != len(argv) - 1
    if len(args) != 1 or args[0].startswith('-'):
        print(__doc__)
        return 2
    d = Path(args[0])
    if not d.is_dir():
        print('normalise-canvas: %s is not a folder' % d, file=sys.stderr)
        return 2
    rc, changed = 0, 0
    todo = ([d / 'canvas.json'] if (d / 'canvas.json').is_file() else []) + sorted(d.rglob('*.dc.html'))
    for f in todo:
        try:
            with open(f, encoding='utf-8', newline='') as fh:
                old = fh.read()
            new = norm_canvas(old) if f.name == 'canvas.json' else norm_html(old)
        except (ValueError, UnicodeDecodeError) as e:
            print('UNREAD %s: %s' % (f, e), file=sys.stderr)
            rc = 2
            continue
        if new != old:
            changed += 1
            if not check:
                with open(f, 'w', encoding='utf-8', newline='') as fh:
                    fh.write(new)
            print(('would normalise %s' if check else 'normalised %s') % f.relative_to(d))
    return rc or (1 if check and changed else 0)


if __name__ == '__main__':
    sys.exit(main(sys.argv))
