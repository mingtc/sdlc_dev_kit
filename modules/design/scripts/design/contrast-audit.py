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
no pair (`NONE`): --strict fails on both, so an unread colour never passes as a measured one.
TARGETS. In each artboard under <design>/*/project/*.dc.html, a <button>, <a>, <input>, <select> or element with role="button" whose
style names a height, min-height, width or min-width in px below --target prints `SMALL`. A size set by a class or a sheet cannot be
read here; the audit says what it read.
Python 3 standard library only; reads files, writes nothing.
"""
import argparse, importlib.util, json, re, sys
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


def themes_of(files):
    """-> ({theme: {css var name: '#rrggbb'}}, [(theme, name, why)] of the colour tokens that could not be read). The base file is
    the theme `base`, merged under the first theme's name later."""
    out, unread = {}, []
    for fname, toks in files.items():
        th = cdl.file_theme(fname) or 'base'
        for k, v in toks.items():
            if not k.startswith('color-'):
                continue
            h, why = hexof(v)
            if h:
                out.setdefault(th, {})[k] = h
            else:
                unread.append((th if th != 'base' else 'light', k, why))
    return out, unread


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


def targets(root, design, minimum):
    found, read = [], 0
    for art in sorted((root / design).glob('*/project/**/*.dc.html')):
        html = art.read_text(encoding='utf-8', errors='replace')
        for tag, at in cdl.tags_of(html):
            if tag not in TARGET_TAGS and at.get('role') != 'button':
                continue
            style = dict(re.findall(r'([\w-]+)\s*:\s*([^;]+)', at.get('style', '')))
            sizes = {k: px(style[k]) for k in ('height', 'min-height', 'width', 'min-width') if k in style and px(style[k]) is not None}
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
    files = cdl.token_files(root)
    themes, unread = themes_of(files)
    base = themes.get('base', {})
    low, measured = [], 0
    for th, toks in sorted(themes.items()):
        merged = {**base, **toks}
        for fg, bg in pairs(set(merged)):
            r = ratio(merged[fg], merged[bg])
            measured += 1
            if r < a.min:
                low.append(f"LOW {th if th != 'base' else 'light'}: {fg} {merged[fg]} on {bg} {merged[bg]} = {r:.2f}:1 < {a.min:g}:1")
    small, read = targets(root, cdl.DESIGN_REL, a.target)
    lines = low + small + [f'UNREAD {th}: {k} ({why})' for th, k, why in unread]
    if measured == 0:
        lines.append('NONE: no colour pair was measured (no readable colour token pairs `color-on-X` on `color-X`)')
    for ln in lines:
        print(ln)
    print(f"contrast-audit: {measured} pair(s) measured, {len(low)} below {a.min:g}:1, {len(unread)} colour token(s) not read; {read} sized target(s) read, "
          f"{len(small)} below {a.target:g}px (a size set by a class or a sheet is not read)")
    return 1 if (a.strict and (low or small or unread or measured == 0)) else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
