#!/usr/bin/env python3
# KIT-CLASS: KIT — design tool: contrast of the token pairs and the size of touch targets. A report; --strict makes a failure the exit status.
"""contrast-audit.py -- WCAG contrast of the colour tokens, and the touch targets of the artboards.

usage: contrast-audit.py [ROOT] [--design DIR] [--min RATIO] [--target PX] [--strict]

  ROOT      default: the working directory;  --design default requirements/design
  --min     the contrast a text pair needs (default 4.5, WCAG AA for normal text)
  --target  the smallest side a touch target may have (default 44 px)
  --strict  exit 1 when a pair or a target fails (without it the exit is 0: this is a report)

CONTRAST. For every colour token `color.on-X` whose base `color.X` exists, the pair (on-X on X) is measured in every theme that holds
both (the base file is the first theme; <ns>.<theme>.tokens.json holds the others). `color.on-surface-variant`, `color.muted` and
`color.on-surface` are also measured on `color.surface` (and `color.surface-raised`, `color.surface-container*`) when those exist. A pair
below --min prints `LOW`; one at or above prints nothing but the total. A colour token the tool cannot read (a #hex of 3, 6 or 8 digits and
a DTCG colour object with a `hex` are read; an alpha below ff, a name, a function are not) prints `UNREAD`, and so does a run that measured
no pair (`NONE`), and so does a token file that is not JSON (`UNREAD <file>: <why>`; a trailing comma, a BOM, an empty file) and a token file that holds no
colour token when it is a theme file, or the base file of a namespace that has theme files or of a run that measured nothing
(`UNREAD <file>: holds no colour token`; its theme is not measured): --strict fails on all four, so an unread colour or file never passes as a measured one. A colour token outside `color.*` (`$type: color`, its own or
its group's, or a #hex value) is in no pair, since pairs are `color.on-X` on `color.X`: a `NOTE` line names them, and the count says how many;
it is a report, never a failure (a primitive such as `palette.ink`, which `color.*` tokens point at by alias, is healthy and is listed there too).
TARGETS. In each artboard under <design>/*/project/*.dc.html, a <button>, <a>, <input>, <select> or element with role="button" whose
style names a height, min-height, width or min-width in px below --target prints `SMALL`. A size set by a class or a sheet cannot be
read here; the audit says what it read.
Python 3 standard library only; reads files, writes nothing.
"""
import argparse, importlib.util, json, math, re, sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location('check_design_links', HERE / 'check-design-links.py')
cdl = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cdl)

HEX = re.compile(r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$')
TARGET_TAGS = {'button', 'a', 'input', 'select', 'textarea'}


def luminance(h):
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def ratio(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def hexof(v):
    """-> ('#rrggbb', None) for a colour this tool can measure, else (None, why): a #hex string (3, 6 or 8 digits; an alpha below ff cannot be
    measured without knowing what is behind it), or a DTCG colour object with a `hex`."""
    if isinstance(v, dict) and 'hex' in v:
        alpha = v.get('alpha', 1)
        if not isinstance(alpha, (int, float)) or isinstance(alpha, bool) or alpha < 1:
            return None, 'has an alpha (%s): its contrast depends on what is behind it' % (alpha,)
        v = v['hex']
    if not isinstance(v, str):
        return None, 'not a hex string or a colour object with a hex'
    m = HEX.match(v.strip())
    if not m:
        return None, 'not #hex'
    d = m.group(1)
    if len(d) == 3:
        return '#' + ''.join(c * 2 for c in d).lower(), None
    if len(d) == 8:
        if d[6:].lower() != 'ff':
            return None, 'has an alpha (%s): its contrast depends on what is behind it' % d[6:]
        d = d[:6]
    return '#' + d.lower(), None


def namespace(fname):
    """The namespace a token file belongs to: `app` for app.tokens.json and app.dark.tokens.json; '' for a bare dark.tokens.json."""
    parts = fname[:-len('.tokens.json')].split('.')
    return parts[0] if len(parts) > 1 or cdl.file_theme(fname) is None else ''


def themes_of(files):
    """-> ({(namespace, theme): {css var name: '#rrggbb'}}, [(namespace, theme, name, why)] of the colour tokens that could not be read,
    {(namespace, theme): [every colour token name]}). The base file is the theme `base`. Two namespaces are two token sets: a pair is
    measured inside one, never across."""
    out, unread, names = {}, [], {}
    for fname, toks in files.items():
        th, ns = cdl.file_theme(fname) or 'base', namespace(fname)
        for k, v in toks.items():
            if not k.startswith('color-'):
                continue
            names.setdefault((ns, th), set()).add(k)
            h, why = hexof(v)
            if h:
                out.setdefault((ns, th), {})[k] = h
            else:
                unread.append((ns, th if th != 'base' else 'light', k, why))
    return out, unread, names


def typed(node, path=(), t=None, out=None):
    """[(dotted path, $type in force, $value)] for every token of a DTCG tree; a group's $type holds for its members."""
    out = [] if out is None else out
    t = node.get('$type', t)
    for k, v in node.items():
        if k.startswith(('$', '_')) or not isinstance(v, dict):
            continue
        if '$value' in v:
            out.append(('.'.join(path + (k,)), v.get('$type', t), v['$value']))
        else:
            typed(v, path + (k,), t, out)
    return out


def outside(root, design, files):
    """{token file: [css var name]} of the colour tokens that do not sit under `color`: a $type of color, or no type and a value that reads as a colour."""
    found = {}
    d = root / design / 'tokens'
    for f in sorted(d.glob('*.tokens.json')) if d.is_dir() else []:
        if f.name not in files:
            continue                      # not read: said as UNREAD
        for dotted, t, _ in typed(json.loads(f.read_text(encoding='utf-8'))):
            name = dotted.replace('.', '-')
            if name.startswith('color-'):
                continue
            if t == 'color' or (t is None and hexof(files[f.name].get(name))[0]):
                found.setdefault(f.name, []).append(name)
    return found


def pairs(names):
    seen = []
    for n in names:
        if n.startswith('color-on-'):
            tail = n[len('color-on-'):]
            for bg in ('color-' + tail,):
                if bg in names:
                    seen.append((n, bg))
    for fg in ('color-on-surface', 'color-on-surface-variant', 'color-muted'):
        for bg in sorted(names):
            if fg in names and (bg == 'color-surface' or bg == 'color-surface-raised' or bg.startswith('color-surface-container')) and (fg, bg) not in seen:
                seen.append((fg, bg))
    return seen


def px(v):
    m = re.fullmatch(r'\s*(\d+(?:\.\d+)?)px\s*', v)
    return float(m.group(1)) if m else None


def padding_px(style, axis):
    """The padding in px along an axis ('v' top and bottom, 'h' left and right) of a parsed style: the shorthand's one to four values, then the longhands."""
    t = r = bt = l = 0.0
    parts = style.get('padding', '').split()
    if 1 <= len(parts) <= 4:
        p = [px(x) or 0.0 for x in parts]
        t = p[0]
        r = p[1] if len(p) > 1 else t
        bt = p[2] if len(p) > 2 else t
        l = p[3] if len(p) > 3 else r
    t, r, bt, l = (px(style['padding-' + n]) or 0.0 if 'padding-' + n in style else v for n, v in (('top', t), ('right', r), ('bottom', bt), ('left', l)))
    return t + bt if axis == 'v' else l + r


def targets(root, design, minimum):
    found, read = [], 0
    for art in sorted((root / design).glob('*/project/**/*.dc.html')):
        html = art.read_text(encoding='utf-8', errors='replace')
        for tag, at in cdl.tags_of(html):
            if tag not in TARGET_TAGS and at.get('role') != 'button':
                continue
            if at.get('type', '').lower() == 'hidden' or 'hidden' in at:
                continue                  # a hidden control is no target
            style = {k.lower(): v.strip() for k, v in re.findall(r'([\w-]+)\s*:\s*([^;]+)', at.get('style', ''))}
            if style.get('display', '').lower() == 'none':
                continue
            border = style.get('box-sizing', '').lower() == 'border-box' or tag in ('button', 'input', 'select', 'textarea')
            sizes = {}
            for axis, size, floor_, pad in (('height', 'height', 'min-height', 'v'), ('width', 'width', 'min-width', 'h')):
                a, b = (px(style[size]) if size in style else None), (px(style[floor_]) if floor_ in style else None)
                if a is None and b is None:
                    continue
                v = max(x for x in (a, b) if x is not None)     # the box is at least its min
                if a is not None and not border and (b is None or a >= b):
                    v += padding_px(style, pad)
                sizes[axis] = v
            if not sizes:
                continue
            read += 1
            for k, v in sizes.items():
                if v < minimum:
                    found.append(f"SMALL {art.relative_to(root).as_posix()}: <{tag}{' id=' + at['id'] if 'id' in at else ''}> {k}: {v:g}px < {minimum:g}px")
    return found, read


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('root', nargs='?', default='.')
    ap.add_argument('--design', default='requirements/design')
    ap.add_argument('--min', type=float, default=4.5)
    ap.add_argument('--target', type=float, default=44)
    ap.add_argument('--strict', action='store_true')
    a = ap.parse_args(argv[1:])
    root = Path(a.root).resolve()
    cdl.DESIGN_REL = a.design.strip('/')
    files, tprobs = cdl.token_files(root)
    themes, unread, names = themes_of(files)
    away = outside(root, cdl.DESIGN_REL, files)
    nss = sorted({ns for ns, _ in themes} | {ns for ns, _ in names})
    low, measured = [], 0
    for (ns, th), toks in sorted(themes.items()):
        merged = {**themes.get((ns, 'base'), {}), **toks}
        tag = (th if th != 'base' else 'light') + (f' [{ns}]' if len(nss) > 1 and ns else '')
        for fg, bg in pairs(set(merged)):
            r = ratio(merged[fg], merged[bg])
            measured += 1
            if r < a.min:
                low.append(f"LOW {tag}: {fg} {merged[fg]} on {bg} {merged[bg]} = {math.floor(r * 100) / 100:.2f}:1 < {a.min:g}:1")   # never rounded up to the line
    # a colour the tool cannot read is UNREAD only where it is in a pair: an overlay (an alpha, rgba(), color-mix()) in no pair measures nothing
    inpair = set()
    for (ns, th), allnames in names.items():
        inpair |= {(ns, n) for pr in pairs(allnames | names.get((ns, 'base'), set())) for n in pr}
    unpaired = [u for u in unread if (u[0], u[2]) not in inpair]
    unread = [u for u in unread if (u[0], u[2]) in inpair]
    small, read = targets(root, cdl.DESIGN_REL, a.target)
    lines = low + small + [f'UNREAD {th}{" [" + ns + "]" if ns and len(nss) > 1 else ""}: {k} ({why})' for ns, th, k, why in unread]
    lines += ['UNREAD %s: %s' % tuple(pr.split(' ', 1)) + ' (none of its tokens were read)' for pr in tprobs]
    tdir = root / cdl.DESIGN_REL / 'tokens'
    badnames = {pr.split(' ', 1)[0] for pr in tprobs}
    ondisk = sorted(f.name for f in tdir.glob('*.tokens.json') if f.is_file()) if tdir.is_dir() else []
    themed = {namespace(n) for n in ondisk if cdl.file_theme(n) is not None}
    # a file with no colour token leaves its theme unmeasured: a theme file always, the base file when its namespace has theme files or the run measured nothing
    # (a namespace of non-colour tokens alone, with no theme file, is a legitimate set)
    bare = [n for n in ondisk if n not in badnames and not any(k.startswith('color-') for k in files.get(n, {}))
            and (cdl.file_theme(n) is not None or namespace(n) in themed or measured == 0)]
    lines += [f"UNREAD {n}: holds no colour token, so its theme is not measured (a <ns>.<theme>.tokens.json holds that theme's colours; non-colour tokens go in <ns>.tokens.json)"
              if cdl.file_theme(n) is not None else f'UNREAD {n}: holds no colour token, so its base theme is not measured' for n in bare]
    lines += [f"NOTE {f}: colour token(s) outside color.* that no pair measures: {', '.join(ns[:12])}{' ...' if len(ns) > 12 else ''}" for f, ns in sorted(away.items())]
    if unpaired:
        lines.append('NOTE: colour token(s) in no pair that this tool cannot measure (an alpha, a function): ' + ', '.join(sorted({u[2] for u in unpaired})[:12]))
    if measured == 0:
        lines.append('NONE: no colour pair was measured (no readable colour token pairs `color-on-X` on `color-X`)')
    for ln in lines:
        print(ln)
    print(f"contrast-audit: {measured} pair(s) measured, {len(low)} below {a.min:g}:1, {len(unread)} colour token(s) not read, {len(tprobs) + len(bare)} token file(s) not read, "
          f"{sum(len(v) for v in away.values())} colour token(s) outside color.* in no pair; {read} sized target(s) read, "
          f"{len(small)} below {a.target:g}px (a size set by a class or a sheet is not read)")
    return 1 if (a.strict and (low or small or unread or tprobs or bare or measured == 0)) else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
