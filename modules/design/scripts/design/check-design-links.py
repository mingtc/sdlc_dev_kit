#!/usr/bin/env python3
# KIT-CLASS: KIT — design tool: report on the links between PRD stories, design screens and cards; with --strict, the design-record gate.
"""check-design-links.py -- report on the links between PRD stories and design screens, in both directions.

usage: check-design-links.py [REPO_ROOT] [--requirements DIR] [--design DIR] [--cards DIR] [--registry-name NAME]
                             [--project-subdir NAME] [--strict] [--head REV] [--leaving CARD]
  REPO_ROOT     default: the working directory
  --requirements  default requirements        <PRD_PREFIX>-*.md live here (PRD_PREFIX is read from scripts/config.sh; PRD when absent)
  --design        default <requirements>/design   <canvas>/<registry-name> files live under it
  --cards         default progress            card shelves (<cards>/<shelf>/*.md); skipped when absent. The shelves done, declined
                  and history are not read: a landed card's pin is history and a declined card builds nothing
  --registry-name default CANVAS.md           --project-subdir default project (the canvas files, beside the registry)
  --strict        exit 1 when there is any finding (the report-only classes below are not findings); without it the exit is 0
  --head REV      the revision an approval's artboard is compared with (default HEAD)
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
                aside), or is missing at either, or a file it loads (sheet, script, image, imported screen) or a token it uses has
                changed since; the row goes back to review
  SUPERSEDED    a citation of a superseded screen        DUPLICATE  one UX id on two rows
  ARTBOARD      an artboard's data-ux / data-stories disagrees with its row (only when the file exists); also a row with an
                approved gate cell whose file is not there
  FENCE         a PRD with a code fence never closed: everything after it is prose to this check
  LITERAL-COLOUR an artboard holding a colour literal (#hex, rgb(), hsl(), oklch() ...) in a style block, a style attribute, a
                presentation attribute, or in a local stylesheet or imported artboard it loads (comments, strings and url() left out),
                except a custom property whose name is a token's (where a screen, a :root rule or a token sheet holds a token's value), unless the screen's registry row carries a
                `[decision: D-NN]` waiver the register confirms. Colour names (`red`) are not caught. The way out is a change
                correction of the screen by the Designer with the artifact tools. A `var(--token, #hex)` whose #hex is the token's value is a token, not a literal; one whose #hex differs is a finding. A screen imported by a screen that has a registry row of its own is reported on that row only. A `superseded` row is not read for colours
  TOKEN-VALUE   a custom property named for a token (`--color-primary` for `color.primary`; the name has no prefix, as the design tool
                compiles it) that a screen, a :root rule or a sheet it loads declares with a value no token file gives that token: the
                :root block holds the token's value, so a different one is a second source of truth. A value written with var() or an
                alias is not compared; a token whose value is not a string is not compared; a theme sheet holding another theme's value
                matches the token file of that theme
  WAIVER        a waiver, on a card's `design:` line or a registry row, citing a D-NN the register has no entry for (a `### D-NN`
                heading with a `**Ruling.**` field, outside fences and comments), or whose Ruling is WITHDRAWN, or no register to check
  REGISTRY      a malformed registry row
Report lines, not findings (shown; never counted, never an exit status):
  UNCITED       a row no PRD cites
  UNREAD        a sheet, script or imported screen an artboard loads that the check cannot read (an uploaded `/_blob/` file): its
                colours are not checked. Put the sheet under project/ as a file and link it by a relative path
  SCRIPT-COLOUR a colour-looking string in the component script: a script cannot be read as CSS, so this is shown, never counted
  UNCLASSIFIED  a PRD with no `UI:` line in any story ("not design-classified"), or the stories of a PRD that has some and these
                lack it. A story with no `UI:` line reads as none declared
Python 3 standard library only.
"""
import argparse, html as htmllib, json, posixpath, re, subprocess, sys
from pathlib import Path
from urllib.parse import unquote

PRD_PREFIX = 'PRD'
HEAD_REV = 'HEAD'
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
REPORT_CLASSES = ('UNCITED', 'UNCLASSIFIED', 'SCRIPT-COLOUR', 'UNREAD')
WAIVER_MARK = re.compile(r'\[decision:\s*(D-\d+)\]')

META = re.compile(r' data-stories="[^"]*"')
# A file an artboard loads that neither revision holds cannot have changed, so it is no gap in a comparison: `support.js` is supplied by the
# host and is in no project, `/_blob/<hash>` is content-addressed, a `{{template}}` href is a value. Setting this True makes each such file
# `uncompared`. The ruling on `support.js` waits on a real export from the design tool (whether a human's copy carries it).
MISSING_IS_A_GAP = False
DESIGN_REL = 'requirements/design'
ABSENT = object()
HTML_COMMENT = re.compile(r'<!--.*?-->', re.S)
STYLE_BLOCK = re.compile(r'<style\b[^>]*>(.*?)</style>', re.S | re.I)
SCRIPT_BLOCK = re.compile(r'<script\b.*?</script>', re.S | re.I)
SCRIPT_BODY = re.compile(r'(<script\b[^>]*>).*?</script>', re.S | re.I)
TAG = re.compile(r'<\s*([A-Za-z][\w:-]*)([^<>]*)>')
ATTR = re.compile(r'(?<![\w:.-])([A-Za-z_:][\w:.-]*)\s*=\s*(?:"([^"]*)"|\'([^\']*)\'|([^\s"\'>]+))')
CSS_COMMENT = re.compile(r'/\*.*?\*/', re.S)
CSS_STRING = re.compile(r'"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'')
CSS_URL = re.compile(r'url\(\s*[^)]*\)', re.I)
CSS_IMPORT = re.compile(r'@import\s+(?:url\(\s*)?(?:"([^"]*)"|\'([^\']*)\'|([^\s"\');]+))', re.I)
CSS_URLREF = re.compile(r'url\(\s*(?:"([^"]*)"|\'([^\']*)\'|([^\s"\')]+))\s*\)', re.I)
PRESENTATION = ('fill', 'stroke', 'stop-color', 'flood-color', 'lighting-color', 'color', 'bgcolor', 'background')
COLOUR_FN = re.compile(r'(?<![\w.-])(?:rgba?|hsla?|hwb|lab|lch|oklab|oklch|color)\(', re.I)
COLOUR_HEX = re.compile(r'#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3,4})(?![\w-])')
JS_STRING = re.compile(r'"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'|`[^`]*`')


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
    r = subprocess.run(['git', '-C', str(root), '-c', 'core.quotePath=false', *args], capture_output=True)
    return r.returncode, r.stdout


def git_bytes(root, rev, path):
    rc, out = git(root, 'show', f'{rev}:{path}')
    return out if rc == 0 else None


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
        then, now = git_blob(root, sha, rel), git_blob(root, HEAD_REV, rel)
        if then is None and now is not None:
            then = same_name_at(root, sha, rel, now)       # the canvas moved with its bytes: the approval holds
        if then is None or now is None:
            out.append(('STALE-APPROVAL', f"{r['where']}: {r['ux']} {gate} approved@{sha[:7]}: {rel} is missing at {'that commit' if then is None else 'HEAD'}; back to review"))
        elif META.sub('', then) != META.sub('', now):
            out.append(('STALE-APPROVAL', f"{r['where']}: {r['ux']} {gate} approved@{sha[:7]}, but {rel} differs at HEAD; back to review"))
        elif git_blob(root, sha, rel) is not None:
            extra = loaded_stale(root, sha, rel, then, now)
            if extra:
                out.append(('STALE-APPROVAL', f"{r['where']}: {r['ux']} {gate} approved@{sha[:7]}, but {extra} differs at HEAD; back to review"))
    return out


def tags_of(markup):
    """[(tag name, {attribute: value})] of the start tags of markup, comments and script bodies left out, attributes in any quoting."""
    h = SCRIPT_BODY.sub(r'\1', HTML_COMMENT.sub(' ', markup))
    return [(m.group(1).lower(), {n.lower(): htmllib.unescape(a or b or c or '') for n, a, b, c in ATTR.findall(m.group(2))}) for m in TAG.finditer(h)]


def ref_path(href):
    """The path part of a reference to a file, %-decoded, or None when it names none: empty, a fragment, a URL with a scheme or `//`
    (remote, data:, mailto:), a `{{template}}` value or a content-addressed `/_blob/` path. A remote reference is not a gap in a
    comparison: a changed one changes the artboard's own bytes."""
    h = htmllib.unescape(href.strip()).split('#')[0].split('?')[0]
    if not h or '{{' in h or h.startswith('/_blob/') or re.match(r'^([A-Za-z][A-Za-z0-9+.-]*:|//)', h):
        return None
    return unquote(h)


def css_refs(css):
    css = CSS_COMMENT.sub(' ', css)
    return [(next(g for g in m.groups() if g), 'sheet' if rx is CSS_IMPORT else 'file')
            for rx in (CSS_IMPORT, CSS_URLREF) for m in rx.finditer(css) if any(m.groups())]


def refs_kinds(text, css=False):
    """[(reference, kind)] for every reference to a file that an artboard (or, with css, a stylesheet) makes: <link href>, <script src>,
    <img src> and the other src tags, <dc-import name="N"> (the design tool's import of N.dc.html), @import and url() in a style block,
    a style attribute or a sheet, in any quoting. kind is `sheet`, `script`, `artboard` or `file`. One function for every reader."""
    if css:
        return css_refs(text)
    out = []
    for tag, at in tags_of(text):
        if tag == 'link':
            h = at.get('href', '')
            out.append((h, 'sheet' if 'stylesheet' in at.get('rel', '').lower() or h.split('?')[0].lower().endswith('.css') else 'file'))
        elif tag == 'dc-import':
            out.append((at['name'] + '.dc.html' if at.get('name') else '', 'artboard'))
        elif tag in ('image', 'use'):
            out.append((at.get('href', '') or at.get('xlink:href', ''), 'file'))
        elif tag == 'script':
            out.append((at.get('src', ''), 'script'))
        elif tag in ('img', 'source', 'video', 'audio', 'iframe', 'embed', 'track', 'input'):
            out.append((at.get('src', ''), 'file'))
        out += css_refs(at.get('style', ''))
    for m in STYLE_BLOCK.finditer(HTML_COMMENT.sub(' ', text)):
        out += css_refs(m.group(1))
    return [o for o in out if o[0]]


def refs_in(text, css=False):
    return [h for h, _ in refs_kinds(text, css)]


def strip_fallbacks(css, tokens):
    """css with each `var(--<token>, <colour>)` whose colour is that token's value (any token file's, case and spaces aside) cut back
    to `var(--<token>)`: the design page writes a picked token as `var(--color-on-surface, #1f2421)`, a token and not a literal. A
    fallback that differs from the token's value stays, to be found."""
    if not isinstance(tokens, dict):
        return css
    i = len(css)
    while True:
        i = css.lower().rfind('var(', 0, i)
        if i < 0:
            return css
        depth, j = 0, i + 3
        while j < len(css):
            depth += (css[j] == '(') - (css[j] == ')')
            if depth == 0:
                break
            j += 1
        else:
            continue
        name, sep, fb = css[i + 4:j].partition(',')
        name, fb = name.strip(), fb.strip()
        if sep and name.startswith('--') and name[2:] in tokens and (COLOUR_HEX.fullmatch(fb) or (COLOUR_FN.match(fb) and fb.endswith(')'))):
            if any(isinstance(v, str) and _norm_value(v) == _norm_value(fb) for v in tokens[name[2:]]):
                css = css[:i] + f'var({name})' + css[j + 1:]


def css_values(css, tokens=()):
    """The declaration text of CSS: selectors, comments, strings and url() removed, and every custom-property declaration whose name is a
    token's (`--color-primary` for `color.primary`: how a screen, a :root rule or a theme selector of a token sheet holds a token's value),
    so what is left can hold a colour. A custom property that is no token's stays: it is a colour in a place no token covers."""
    css = CSS_URL.sub(' ', CSS_COMMENT.sub(' ', css))
    css = CSS_STRING.sub('""', css)
    css = strip_fallbacks(css, tokens)
    parts = re.split(r'([{};])', css)
    keep = []
    for i in range(0, len(parts), 2):
        if (parts[i + 1] if i + 1 < len(parts) else '') == '{':
            continue
        m = re.match(r'\s*--([\w-]+)\s*:', parts[i])
        if m and m.group(1) in tokens:
            continue
        keep.append(parts[i])
    return ' ; '.join(keep)


def colours_in(text):
    """The colour literals (#hex, rgb(), hsl(), oklch() ...) in declaration text; a function that reads var() is a token, not a literal.
    Colour names (`red`) are not caught."""
    found = [m.group(0) for m in COLOUR_HEX.finditer(text)]
    for m in COLOUR_FN.finditer(text):
        depth, j = 0, m.end() - 1
        while j < len(text):
            depth += (text[j] == '(') - (text[j] == ')')
            if depth == 0:
                break
            j += 1
        if 'var(' not in text[m.end():j].lower():
            found.append(m.group(0))
    return found


def markup_css(markup, tokens=()):
    """The CSS declaration texts of an artboard: style blocks, style attributes, presentation attributes. A script is not CSS."""
    h = SCRIPT_BLOCK.sub(' ', HTML_COMMENT.sub(' ', markup))
    out = [css_values(m.group(1), tokens) for m in STYLE_BLOCK.finditer(h)]
    for tag, at in tags_of(h):
        if 'style' in at:
            out.append(css_values('a{' + at['style'] + '}', tokens))
        out += [css_values('a{' + k + ':' + at[k] + '}', tokens) for k in PRESENTATION if k in at]
    return out


def literal_colours(markup, loaded=(), tokens=()):
    """The colour literals of an artboard, in order, once each: its styles and presentation attributes, then those of every file it loads
    (`loaded` is [(name, text)]: a .css sheet is CSS, a .html one an artboard it imports), a literal there marked `(in <name>)`."""
    found = []
    for css in markup_css(markup, tokens):
        found += [c for c in colours_in(css) if c not in found]
    for name, text in loaded:
        csss = [css_values(text, tokens)] if name.lower().endswith('.css') else markup_css(text, tokens)
        for css in csss:
            found += [f'{c} (in {name})' for c in colours_in(css) if f'{c} (in {name})' not in found]
    return found


def script_colours(markup):
    """Colour-looking strings in the component script. A script is code and copy, and cannot be read without a JavaScript parser, so this
    is a report line and never a finding."""
    out = []
    for m in SCRIPT_BLOCK.finditer(HTML_COMMENT.sub(' ', markup)):
        body = re.sub(r'(?m)/\*.*?\*/|(?<![:\w"\'])//[^\n]*', ' ', m.group(0), flags=re.S)
        for lit in JS_STRING.findall(body):
            out += [c for c in colours_in(lit) if c not in out]
    return out


def project_top(rel):
    """The directory a leading `/` names for the artboard at repository path rel: the canvas's project directory."""
    i = rel.find('/' + PROJECT_SUBDIR + '/')
    return rel[:i + len(PROJECT_SUBDIR) + 1] if i >= 0 else posixpath.dirname(rel)


def closure(read, base, markup, limit=300, top=None):
    """-> ({path relative to the artboard's directory: bytes or None}, {path: text of the CSS sheets and imported artboards among them},
    [what could not be compared]) for every local file an artboard loads, directly or through the sheets and artboards it loads
    (refs_kinds is the one list). `read(path)` returns the bytes of a repository path or None; `base` is the artboard's directory; a
    reference with a leading `/` is read from `top`, the canvas's project directory (default `base`), as the design tool resolves it.
    A sheet or script uploaded to the canvas (`/_blob/<id>`) cannot be read: it is named in the last list, never skipped silently."""
    files, texts, why = {}, {}, []
    queue = [('', h, k) for h, k in refs_kinds(markup)]
    root_ = base if top is None else top
    while queue:
        parent, href, kind = queue.pop(0)
        if htmllib.unescape(href.strip()).startswith('/_blob/') and kind in ('sheet', 'script'):
            msg = f'{href} is an uploaded {kind} and cannot be read'
            if msg not in why:
                why.append(msg)
            continue
        path = ref_path(href)
        if path is None:
            continue
        if path.startswith('/'):
            full_ = posixpath.normpath(posixpath.join(root_, path.lstrip('/')))
            key = posixpath.relpath(full_, base or '.')
        else:
            if posixpath.normpath(posixpath.join(base, path)).startswith('..'):
                files.setdefault(href, None)            # outside the repository: nothing to read
                continue
            key = posixpath.normpath(posixpath.join(posixpath.dirname(parent), path))
            full_ = posixpath.normpath(posixpath.join(base, key))
        if full_.startswith('..'):
            files.setdefault(href, None)
            continue
        if key in files:
            continue
        if len(files) >= limit:
            why.append(f'more than {limit} files are loaded; the rest were not compared')
            break
        data = read(full_)
        files[key] = data
        if data is not None:
            low = key.lower()
            if low.endswith('.css'):
                texts[key] = data.decode('utf-8', 'replace')
                queue += [(key, h, k) for h, k in refs_kinds(texts[key], css=True)]
            elif low.endswith('.html'):
                texts[key] = data.decode('utf-8', 'replace')
                queue += [(key, h, k) for h, k in refs_kinds(texts[key])]
    return files, texts, why


def closure_diff(fa, fb):
    """-> ([files that differ between two closures], [files neither holds]). Two closures differ in a file one holds and the other does not,
    or holds differently; a file neither holds cannot have changed (MISSING_IS_A_GAP says whether it is reported)."""
    changed, missing = [], []
    for k in sorted(set(fa) | set(fb)):
        a, b = fa.get(k, ABSENT), fb.get(k, ABSENT)
        if a is None and b is None:
            missing.append(k)
        elif a != b:
            changed.append(k)
    return changed, missing


def disk_reader(root):
    def read_(path):
        f = Path(root) / path
        return f.read_bytes() if f.is_file() else None
    return read_


def loaded_files(root, art, markup):
    """-> ([(name, text)] of the local sheets and artboards an artboard loads, as read on disk, named by their path under the root,
    [what could not be read])."""
    try:
        base = art.parent.relative_to(root).as_posix()
        top = project_top(art.relative_to(root).as_posix())
    except ValueError:
        return [], []
    _, texts, why = closure(disk_reader(root), base, markup, top=top)
    return [(posixpath.normpath(posixpath.join(base, k)), t) for k, t in texts.items()], why


# ---- tokens, read at a revision: the DTCG files <design>/tokens/*.tokens.json (the one reader, for the gate, the approvals and pin-drift)
ALIAS = re.compile(r'^\{([^{}]+)\}$')
UNRESOLVED = '\x00unresolved'


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


def _resolve(value, own, merged, seen=()):
    """(value with every alias replaced, True when one did not resolve). An alias is looked up in its own file, then in any
    token file; a cycle or a name nobody defines does not resolve. Composite values (objects, lists) are resolved member by member."""
    if isinstance(value, str):
        m = ALIAS.match(value)
        if not m:
            return value, False
        name = m.group(1)
        target = own.get(name, merged.get(name))
        if name in seen or target is None:
            return value, True
        return _resolve(target, own, merged, seen + (name,))
    if isinstance(value, dict):
        res = {k: _resolve(v, own, merged, seen) for k, v in value.items()}
        return {k: r[0] for k, r in res.items()}, any(r[1] for r in res.values())
    if isinstance(value, list):
        res = [_resolve(v, own, merged, seen) for v in value]
        return [r[0] for r in res], any(r[1] for r in res)
    return value, False


_tok_cache = {}


def _token_core(blobs):
    """-> ({(token file, css var name): resolved value, or UNRESOLVED}, [problem]) from {file name: bytes}. A file that is not a JSON
    object is a problem, not silence."""
    files, problems = {}, []
    for name, raw in sorted(blobs.items()):
        try:
            data = json.loads((raw or b'').decode('utf-8'))
            if not isinstance(data, dict):
                raise ValueError('not an object')
            files[name] = _leaves(data)
        except (ValueError, UnicodeDecodeError) as e:
            problems.append(f'{name} is not a JSON object of tokens ({e})')
    merged = {}
    for name in sorted(files):
        for k, v in files[name].items():
            merged.setdefault(k, v)
    found = {}
    for name, leaves in files.items():
        for dotted, v in leaves.items():
            val, bad = _resolve(v, leaves, merged, (dotted,))
            found[(name, dotted.replace('.', '-'))] = UNRESOLVED if bad else json.dumps(val, sort_keys=True)
    return found, problems


def token_map(root, rev):
    """-> ({(token file, css var name): resolved value, or UNRESOLVED}, [problem]) from every <design>/tokens/*.tokens.json at revision rev."""
    ck = (str(root), rev, DESIGN_REL)
    if ck in _tok_cache:
        return _tok_cache[ck]
    rc, out = git(root, 'ls-tree', '-r', '--name-only', '-z', rev, '--', f'{DESIGN_REL}/tokens')
    blobs = {}
    for p in sorted(x for x in out.decode('utf-8', 'replace').split('\0') if x):
        if p.endswith('.tokens.json') and Path(p).parent.as_posix() == f'{DESIGN_REL}/tokens':
            blobs[Path(p).name] = git_bytes(root, rev, p) or b''
    _tok_cache[ck] = _token_core(blobs)
    return _tok_cache[ck]


def token_table(root):
    """{css var name: [resolved values]} of the token files on disk (`color.primary` is `color-primary`): the names that may carry a
    colour, and the values they may carry (one per token file: a theme file gives its own)."""
    d = Path(root) / DESIGN_REL / 'tokens'
    blobs = {f.name: f.read_bytes() for f in sorted(d.glob('*.tokens.json')) if f.is_file()} if d.is_dir() else {}
    found, _ = _token_core(blobs)
    table = {}
    for (_, name), v in found.items():
        table.setdefault(name, []).append(None if v == UNRESOLVED else json.loads(v))
    return table


def token_names(root):
    return set(token_table(root))


def _norm_value(v):
    v = re.sub(r'\s*!important\s*$', '', v.strip(), flags=re.I)
    v = re.sub(r'\s+', '', v).lower()
    m = re.fullmatch(r'#([0-9a-f])([0-9a-f])([0-9a-f])', v)
    return '#' + ''.join(c * 2 for c in m.groups()) if m else v


def custom_decls(css):
    """[(name, value)] of the custom-property declarations in CSS text (a style block, a style attribute body or a sheet)."""
    css = CSS_COMMENT.sub(' ', css)
    parts = re.split(r'([{};])', css)
    out = []
    for i in range(0, len(parts), 2):
        if (parts[i + 1] if i + 1 < len(parts) else '') == '{':
            continue
        m = re.match(r'\s*--([\w-]+)\s*:\s*(.*)$', parts[i], re.S)
        if m:
            out.append((m.group(1), m.group(2)))
    return out


def decls_of(markup):
    """The custom-property declarations of an artboard: style blocks and style attributes (a script is not CSS)."""
    h = SCRIPT_BLOCK.sub(' ', HTML_COMMENT.sub(' ', markup))
    out = []
    for m in STYLE_BLOCK.finditer(h):
        out += custom_decls(m.group(1))
    for tag, at in tags_of(h):
        if 'style' in at:
            out += custom_decls('a{' + at['style'] + '}')
    return out


def token_value_problems(markup, loaded, table):
    """[text] for each token-named custom property that the artboard, or a sheet or screen it loads, declares with a value no token file
    gives that token. A value with var() or an alias, and a token whose value is not a string, are not compared."""
    out = []
    pieces = [('', decls_of(markup))] + [(n, custom_decls(t) if n.lower().endswith('.css') else decls_of(t)) for n, t in loaded]
    for where, decls in pieces:
        for name, value in decls:
            if name not in table or 'var(' in value.lower() or value.strip().startswith('{'):
                continue
            vals = table[name]
            if any(not isinstance(v, str) for v in vals):
                continue
            if _norm_value(value) not in {_norm_value(v) for v in vals}:
                msg = f"--{name}: {value.strip()}" + (f' (in {where})' if where else '') + f" but the token is {' / '.join(sorted(set(vals)))}"
                if msg not in out:
                    out.append(msg)
    return out


def used_vars(*htmls, sheets=()):
    """The custom properties a screen uses: read by var() (any case, spaces allowed) or declared in a :root block; and those a local
    sheet or artboard it loads reads by var()."""
    names = set()
    for t in sheets:
        names |= set(re.findall(r'(?i:var)\(\s*--([A-Za-z0-9_-]+)', t))
    for h in htmls:
        names |= set(re.findall(r'(?i:var)\(\s*--([A-Za-z0-9_-]+)', h))
        for blk in re.findall(r':root\s*\{([^}]*)\}', h):
            names |= set(re.findall(r'(?:^|[;\s])--([A-Za-z0-9_-]+)\s*:', blk))
    return sorted(names)


def tokens_check(root, old_html, new_html, r_old, r_new, sheets=()):
    """-> (the custom properties (--name) the artboard at r_old uses whose token value changed or vanished between the two revisions,
    [what could not be compared]): a var with no token at either revision, an alias that does not resolve, a tokens file that is not JSON."""
    used = used_vars(old_html, new_html, sheets=sheets)
    (a, pa), (b, pb) = token_map(root, r_old), token_map(root, r_new)
    changed, why = [], []
    declared = {n for t in sheets for n, _ in (decls_of(t) if '<' in t else custom_decls(t))}
    if used and (pa or pb):
        why.append('tokens: ' + '; '.join(sorted(set(pa + pb))))
    for n in used:
        ea, eb = {k: v for k, v in a.items() if k[1] == n}, {k: v for k, v in b.items() if k[1] == n}
        if not ea and not eb:
            if n not in declared:        # a property a sheet or screen it loads declares is compared with that file's bytes
                why.append(f'--{n} names no token')
        elif ea != eb:
            changed.append('--' + n)
        elif UNRESOLVED in ea.values():
            why.append(f'--{n}: an alias does not resolve')
    return changed, why


def loaded_stale(root, sha, rel, then, now):
    """What an approval did not cover that has changed since: a file the approved screen loads (a sheet, an imported screen, a script, an
    image), or a token it uses. A short description, or None."""
    base, top = posixpath.dirname(rel), project_top(rel)
    fa, ta, _ = closure(lambda p: git_bytes(root, sha, p), base, then, top=top)
    fb, tb, _ = closure(lambda p: git_bytes(root, HEAD_REV, p), base, now, top=top)
    changed, _ = closure_diff(fa, fb)
    if changed:
        return ', '.join(changed[:3])
    tok, _ = tokens_check(root, then, now, sha, HEAD_REV, sheets=list(ta.values()) + list(tb.values()))
    return 'token ' + ' '.join(tok[:3]) if tok else None


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


FENCE_OPEN = re.compile(r'^ {0,3}(`{3,}|~{3,})(.*)$')


def fence_scan(text):
    """-> ([(line_no, text)] outside code fences, the line of a fence never closed or None). A fence closes on a line of the same
    character, at least as long as the opening one and nothing else, so a ``` line inside a ~~~ block is text."""
    out, marker, opened = [], None, None
    for n, ln in enumerate(text.splitlines(), 1):
        m = FENCE_OPEN.match(ln)
        if marker is None:
            if m and not (m.group(1)[0] == '`' and '`' in m.group(2)):
                marker, opened = m.group(1), n
            else:
                out.append((n, ln))
        elif m and m.group(1)[0] == marker[0] and len(m.group(1)) >= len(marker) and not m.group(2).strip():
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
    """{D-NN: has a current ruling} for the entries of <requirements>/DECISIONS.md, or None when there is no register. An entry is a
    `### D-NN` heading with a `**Ruling.**` field, outside code fences and HTML comments; the field's head is read as the kit's
    kit_ruling_state reads it (leading backticks, `*`, `_` and spaces skipped): WITHDRAWN there means no current ruling."""
    f = Path(root) / requirements / 'DECISIONS.md'
    if not f.is_file():
        return None
    lines = [ln for _, ln in fence_scan(HTML_COMMENT.sub(lambda m: '\n' * m.group(0).count('\n'), read(f)))[0]]
    entries, cur, ruling = {}, None, None
    for ln in lines + ['### END']:
        m = re.match(r'### (D-\d+)\b', ln)
        if m or ln.startswith('### ') or ln.startswith('## '):
            if cur and ruling is not None:
                entries[cur] = not re.sub(r'^[`*_ \t]*', '', ruling).startswith('WITHDRAWN')
            cur, ruling = (m.group(1) if m else None), None
        elif cur and ruling is None:
            rm = re.match(r'\*\*Ruling\.\*\*(.*)$', ln)
            if rm:
                ruling = rm.group(1)
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
    global DESIGN_REL
    set_prd_prefix(root)
    DESIGN_REL = (design or f'{requirements}/design').strip('/')
    dsn = root / DESIGN_REL
    ttable = token_table(root)
    tokens = ttable
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

    rowfiles = set()
    for r in rows:
        try:
            if not r['superseded']:
                rowfiles.add((r['canvas'] / PROJECT_SUBDIR / r['file']).relative_to(root).as_posix())
        except ValueError:
            pass
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
            loaded, unread = loaded_files(root, art, html)
            loaded = [(n, t) for n, t in loaded if not (n.lower().endswith('.html') and n in rowfiles)]   # a screen with a row of its own is reported there
            lits = [] if r['superseded'] else literal_colours(html, loaded, tokens)
            if not r['superseded']:
                for u in unread:
                    out.append(line('UNREAD', f"{art.relative_to(root)}: {u}; its colours are not checked (info). Put the sheet under {PROJECT_SUBDIR}/ as a file and link it by a relative path"))
                for tv in token_value_problems(html, loaded, ttable):
                    out.append(line('TOKEN-VALUE', f"{art.relative_to(root)}: {tv}; the Designer corrects the screen with the artifact tools (pull first), or the token if the token is what changed"))
            problem = waiver_problem(get_register(), requirements, r['waivers']) if r['waivers'] else 'no waiver'
            if r['waivers'] and problem:
                out.append(line('WAIVER', f"{r['where']}: {problem}"))
            if lits and problem:
                out.append(line('LITERAL-COLOUR', f"{art.relative_to(root)}: {', '.join(lits[:4])}{' ...' if len(lits) > 4 else ''} is a colour no token holds; the Designer corrects the screen with the artifact tools (pull first): add the token and read it as var(--color-name), a custom property named for a token with no prefix, or a var() fallback equal to the token's value"))
            sc = script_colours(html)
            if sc:
                out.append(line('SCRIPT-COLOUR', f"{art.relative_to(root)}: {', '.join(sc[:4])}{' ...' if len(sc) > 4 else ''} in the component script (report only: a script cannot be read as CSS)"))
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
    ap.add_argument('--head', default='HEAD', metavar='REV', help='the revision an approval is compared with (default HEAD)')
    ap.add_argument('--leaving', metavar='CARD', action='append', default=[])
    a = ap.parse_args(argv[1:])
    global REGISTRY_NAME, PROJECT_SUBDIR, HEAD_REV
    REGISTRY_NAME, PROJECT_SUBDIR, HEAD_REV = a.registry_name, a.project_subdir, a.head
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
