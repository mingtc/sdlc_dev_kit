#!/usr/bin/env python3
# KIT-CLASS: KIT — design tool: the kit's token files (DTCG) to the design system's tokens.json and tokens.css, as the design type reads them.
"""dtcg-convert.py -- requirements/design/tokens/*.tokens.json -> a design system's tokens.json (lists) and tokens.css.

usage: dtcg-convert.py [TOKENS_DIR] --out DIR [--namespace NS] [--title TEXT] [--first THEME]

  TOKENS_DIR  default requirements/design/tokens: <ns>.tokens.json is the base (the first theme, `light` unless --first says
              otherwise), <ns>.<theme>.tokens.json (`.dark`, `.wire`) holds that theme's colours. Aliases `{a.b}` are resolved.
  --out DIR   writes DIR/tokens.json and DIR/tokens.css (the design system's project/ folder, or a canvas's project/ds/<folder>/)

Order is the file's. Names are the token's path with hyphens, NO prefix (`color.primary` is `color-primary` is `--color-primary`): that is how the design
tool compiles a system's tokens, and what check-design-links.py reads. tokens.css has the shape the design type's own compiler
writes (`:root, [data-theme="<first>"]`, then `[data-theme="<id>"]` per other theme): the page does not generate it, so this tool does.
A token is a colour when its `$type` is color (its own, its group's, or its alias target's), wherever it sits (`brand.leaf`); with no type, under
`color` or when its value reads as a colour. Colours may be `#rgb`, `#rrggbb[aa]` strings or DTCG colour objects with a `hex` (an `alpha` below 1 is written as the last two
digits); dimensions `16px`, `0` (written as given) or {value, unit}, listed as spacing when a segment of the path starts space, spacing or
gap, as radius for radius, corner or shape. A colour, spacing or radius token it cannot read is said (`NOT CONVERTED: name why`) and the exit
status is 1, the rest being written; any other token (typography, shadows, a dimension with neither name) is listed on stderr with its true
reason and left out. Python 3 standard library only. Exit 1 on input it cannot read.
"""
import argparse, json, re, sys
from pathlib import Path

ALIAS = re.compile(r'^\{([^{}]+)\}$')
HEX = re.compile(r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$')


class Fail(Exception):
    pass


def leaves(node, path=(), inherited=None, out=None):
    out = {} if out is None else out
    t = node.get('$type', inherited)
    for k, v in node.items():
        if k.startswith(('$', '_')):
            continue
        if not isinstance(v, dict):
            raise Fail('non-object member %s' % '.'.join(path + (k,)))
        if '$value' in v:
            out['.'.join(path + (k,))] = (v['$value'], v.get('$type', t), v.get('$description', ''))
        else:
            leaves(v, path + (k,), t, out)
    return out


def resolve(value, own, base, seen=()):
    if isinstance(value, str):
        m = ALIAS.match(value)
        if m:
            name = m.group(1)
            if name in seen or (name not in own and name not in base):
                raise Fail('alias %s does not resolve' % value)
            return resolve((own.get(name) or base[name])[0], own, base, seen + (name,))
    return value


def colour(v):
    """-> ('#rrggbb[aa]', None) or (None, why). #rgb is widened; a colour object's alpha below 1 is written as the last two digits, never dropped."""
    alpha = 1
    if isinstance(v, dict) and 'hex' in v:
        alpha, v = v.get('alpha', 1), v['hex']
    if not isinstance(v, str):
        return None, 'is not a #hex string or a colour object with a hex'
    m = HEX.match(v.strip())
    if not m:
        return None, 'is not a #hex (3, 6 or 8 digits)'
    d = m.group(1)
    if len(d) == 3:
        d = ''.join(c * 2 for c in d)
    if not isinstance(alpha, (int, float)) or isinstance(alpha, bool) or not 0 <= alpha <= 1:
        return None, 'has an alpha that is not a number from 0 to 1'
    if alpha < 1:
        if len(d) == 8:
            return None, 'gives its alpha twice (in the hex and as alpha)'
        d += '%02x' % round(alpha * 255)
    return '#' + d, None


def dimension(v):
    """-> ('16px', None) or (None, why)."""
    if isinstance(v, (int, float)) and not isinstance(v, bool) and v == 0:
        return str(v), None      # as given: the link check compares the sheet's text with the token's, and `0` is not `0px` to it
    if isinstance(v, str) and re.match(r'^-?\d+(\.\d+)?(px|rem|em|%)$', v.strip()):
        return v.strip(), None
    if isinstance(v, str) and v.strip() == '0':
        return '0', None
    if isinstance(v, dict) and 'value' in v and 'unit' in v:
        return '%s%s' % (v['value'], v['unit']), None
    return None, 'is not a number with a unit (16px, 1rem) or {value, unit}'


def typeof(v, t, own, base, seen=()):
    """The token's $type, or the one its alias target has (DTCG: a reference takes the type of what it points at)."""
    if t:
        return t
    m = ALIAS.match(v) if isinstance(v, str) else None
    if m and m.group(1) not in seen:
        tgt = own.get(m.group(1)) or base.get(m.group(1))
        if tgt:
            return typeof(tgt[0], tgt[1], own, base, seen + (m.group(1),))
    return None


def family(name, t):
    """-> ('color' | 'spacing' | 'radius', None), or (None, why it has no list). A colour is a token of $type color wherever it sits, or
    any token under `color` that names no type; a dimension goes to the spacing list when a segment of its path starts space, spacing or
    gap, and to the radius list when one starts radius, corner or shape."""
    parts = name.split('.')
    if t == 'color' or (t is None and parts[0] == 'color'):
        return 'color', None
    if t in (None, 'dimension'):
        if any(x.startswith(('space', 'spacing', 'gap')) for x in parts):
            return 'spacing', None
        if any(x.startswith(('radius', 'corner', 'shape')) for x in parts):
            return 'radius', None
        return None, ('is a dimension whose path names neither spacing (space*, gap*) nor radius (radius*, corner*, shape*)' if t
                      else 'names no $type and its path names no colour, spacing or radius')
    return None, 'is of $type %s, which the design system has no list for' % t


def family_of(name, v, t, own, base):
    """family() for a token, where a token with no type anywhere whose value reads as a colour is a colour wherever it sits."""
    ft = typeof(v, t, own, base)
    fam, why = family(name, ft)
    if fam is None and ft is None:
        try:
            if colour(resolve(v, own, base))[0]:
                return 'color', None
        except Fail:
            pass
    return fam, why


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('tokens', nargs='?', default='requirements/design/tokens')
    ap.add_argument('--out', required=True)
    ap.add_argument('--namespace')
    ap.add_argument('--title')
    ap.add_argument('--first', default='light')
    a = ap.parse_args(argv[1:])
    d = Path(a.tokens)
    files = sorted(d.glob('*.tokens.json')) if d.is_dir() else []
    if not files:
        print('dtcg-convert: no *.tokens.json under %s' % d, file=sys.stderr)
        return 1
    groups = {}
    for f in files:
        stem = f.name[:-len('.tokens.json')]
        ns, _, theme = stem.rpartition('.') if '.' in stem else (stem, '', '')
        groups.setdefault(ns, {})[theme or None] = f
    ns = a.namespace or sorted(groups)[0]
    if not a.namespace and len(groups) > 1:
        print('dtcg-convert: %d namespaces (%s); taking %s, name another with --namespace' % (len(groups), ', '.join(sorted(groups)), ns), file=sys.stderr)
    if ns not in groups:
        print('dtcg-convert: no namespace %s (found: %s)' % (ns, ', '.join(sorted(groups))), file=sys.stderr)
        return 1
    try:
        parsed = {t: leaves(json.loads(f.read_text(encoding='utf-8'))) for t, f in groups[ns].items()}
        base = parsed.get(None)
        if base is None:
            raise Fail('%s.tokens.json (the base file) is missing' % ns)
        themes = [a.first] + sorted(t for t in parsed if t and t != a.first)
        skipped, problems, colours, dims = [], [], {}, {'spacing': {}, 'radius': {}}
        for name, (v, t, desc) in base.items():
            fam, nofam = family_of(name, v, t, base, base)
            rv = resolve(v, base, base) if fam else None
            if fam == 'color':
                hx, why = colour(rv)
                if hx:
                    colours[name.replace('.', '-')] = {a.first: hx, 'usage': desc}
                else:
                    problems.append('%s %s' % (name, why))
            elif fam in dims:
                dv, why = dimension(rv)
                if dv:
                    dims[fam][name.replace('.', '-')] = {'value': dv, 'usage': desc}
                else:
                    problems.append('%s %s' % (name, why))
            else:
                skipped.append((name, nofam))
        for th, toks in parsed.items():
            if th is None:
                continue
            for name, (v, t, desc) in toks.items():
                key = name.replace('.', '-')
                fam, nofam = family_of(name, v, t, toks, base)
                if fam != 'color':
                    skipped.append(('%s (%s)' % (name, th), nofam or 'is not a colour, and a theme file holds colours only'))
                    continue
                hx, why = colour(resolve(v, toks, base))
                if hx and key in colours:
                    colours[key][th] = hx
                elif not hx:
                    problems.append('%s (%s) %s' % (name, th, why))
                else:
                    problems.append('%s (%s) has no value in the base file that could be read, so the theme has nothing to override' % (name, th))
    except (Fail, ValueError) as e:
        print('dtcg-convert: %s' % e, file=sys.stderr)
        return 1
    title = a.title or ns
    ds = {'name': title, 'version': 1,
          'color': {'themes': [{'id': t, 'name': t.capitalize()} for t in themes],
                    'tokens': [{'name': k, 'value': {t: v[t] for t in themes if t in v}, 'usage': v['usage']} for k, v in colours.items()]},
          'type': {'fonts': [], 'families': {}, 'groups': []},
          'spacing': {'tokens': [{'name': k, **v} for k, v in dims['spacing'].items()]},
          'radius': {'tokens': [{'name': k, **v} for k, v in dims['radius'].items()]}}
    css = ['/* %s — generated from tokens.json */\n' % title]
    for th in themes:
        sel = ':root, [data-theme="%s"]' % th if th == a.first else '[data-theme="%s"]' % th
        body = ['  --%s: %s;' % (k, v[th]) for k, v in colours.items() if th in v]
        css.append('%s {\n%s\n}\n' % (sel, '\n'.join(body)))
    other = ['  --%s: %s;' % (k, v['value']) for fam in dims.values() for k, v in fam.items()]
    if other:
        css.append(':root {\n%s\n}\n' % '\n'.join(other))
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    (out / 'tokens.json').write_text(json.dumps(ds, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
    (out / 'tokens.css').write_text('\n'.join(css), encoding='utf-8')
    for why in sorted({w for _, w in skipped}):
        names = [n for n, w in skipped if w == why]
        print('dtcg-convert: left out (%s): %s' % (why, ', '.join(names[:12]) + (' ...' if len(names) > 12 else '')), file=sys.stderr)
    print('dtcg-convert: %d colour token(s) in %d theme(s), %d dimension(s) -> %s' % (len(colours), len(themes), sum(len(x) for x in dims.values()), out))
    for pr in problems:
        print('dtcg-convert: NOT CONVERTED: %s' % pr, file=sys.stderr)
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
