#!/usr/bin/env python3
# KIT-CLASS: KIT — design tool: turns a canvas comment's anchor into the element it points at, in the pulled file. A report tool.
"""resolve-anchor.py -- the element a canvas comment is anchored to, in the pulled copy of the board.

usage: resolve-anchor.py PROJECT_DIR ANCHOR [ANCHOR ...]

  PROJECT_DIR  a pulled canvas's project/ folder
  ANCHOR       the `detail` of a thread's anchor as `read_comments` gives it (`Settings.dc.html: #2:1 shape "Settings Sound"`),
               or just `Settings.dc.html#2:1`. The shape is <board>.dc.html, then #<n>:<path>: <n> is the element's place counting
               depth first inside <x-dc> from 0 (the <helmet> and its children count), <path> the child positions from <x-dc> down, `/`-separated.

Prints one line per anchor, to paste into COMMENTS.md's `element` column:
  RESOLVED   <anchor>  ->  <Board>.dc.html#<element id>  <tag>  data-ux=… data-state=…  "<first words>"
  UNRESOLVED <anchor>  (<why>)
An element with no id is named by its path (`<Board>.dc.html#(no id: x-dc/1/0)`): say so in the thread's row. The place and the path must
agree; if they do not, or the board is not in PROJECT_DIR, the pulled file differs from the one the commenter saw: UNRESOLVED, and the
thread is logged against the board with `(board)` until the Designer has pulled again. A board-level or note anchor is UNRESOLVED too.
Exit 0 every anchor resolved (and --help); 1 one or more not; 2 bad usage. Python 3 standard library only; reads files, writes nothing.
"""
import html.parser, re, sys
from pathlib import Path

VOID = {'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'source', 'track', 'wbr'}
ANCHOR = re.compile(r'^\s*(?P<file>[^\s:#]+\.dc\.html)\s*:?\s*#(?P<tid>\d+):(?P<path>\d+(?:/\d+)*)\b')


class Tree(html.parser.HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = {'tag': 'x-dc', 'attrs': {}, 'children': [], 'text': ''}
        self.stack, self.flat, self.on = [self.root], [], False

    def handle_starttag(self, tag, attrs):
        if tag == 'x-dc' and not self.on:
            self.on = True
            return
        if not self.on:
            return
        node = {'tag': tag, 'attrs': dict(attrs), 'children': [], 'text': ''}
        self.stack[-1]['children'].append(node)
        self.flat.append(node)
        if tag not in VOID:
            self.stack.append(node)

    def handle_endtag(self, tag):
        if not self.on:
            return
        if tag == 'x-dc' and len(self.stack) == 1:
            self.on = False
            return
        for i in range(len(self.stack) - 1, 0, -1):
            if self.stack[i]['tag'] == tag:
                del self.stack[i:]
                break

    def handle_data(self, data):
        if self.on:
            for n in self.stack[1:]:
                n['text'] += data


def resolve(project, anchor):
    m = ANCHOR.match(anchor)
    if not m:
        return None, 'not an element anchor (<Board>.dc.html#<n>:<path>): a board or a note'
    f = Path(project) / m.group('file')
    if not f.is_file():
        return None, '%s is not in the pulled project' % m.group('file')
    try:
        t = Tree()
        t.feed(f.read_text(encoding='utf-8'))
    except (UnicodeDecodeError, ValueError) as e:
        return None, '%s cannot be read (%s)' % (m.group('file'), e)
    tid, path = int(m.group('tid')), [int(x) for x in m.group('path').split('/')]
    by_place = t.flat[tid] if tid < len(t.flat) else None
    node = t.root
    for i in path:
        node = node['children'][i] if node is not None and i < len(node['children']) else None
    if node is None or by_place is not node:
        return None, 'the place (#%d) and the path (%s) name different elements, or neither exists: %s differs from the commenter\'s copy' % (tid, m.group('path'), m.group('file'))
    ident = node['attrs'].get('id') or '(no id: x-dc/%s)' % m.group('path')
    data = ' '.join('%s=%s' % (k, v) for k, v in sorted(node['attrs'].items()) if k.startswith('data-') and k != 'data-props')
    words = ' '.join(node['text'].split())[:60]
    return '%s#%s  %s  %s  "%s"' % (m.group('file'), ident, node['tag'], data, words), None


def main(argv):
    if len(argv) == 2 and argv[1] in ('-h', '--help'):
        print(__doc__)
        return 0
    if len(argv) < 3 or argv[1].startswith('-'):
        print(__doc__)
        return 2
    rc = 0
    for a in argv[2:]:
        line, why = resolve(argv[1], a)
        if line:
            print('RESOLVED   %s  ->  %s' % (a, line))
        else:
            print('UNRESOLVED %s  (%s)' % (a, why))
            rc = 1
    return rc


if __name__ == '__main__':
    sys.exit(main(sys.argv))
