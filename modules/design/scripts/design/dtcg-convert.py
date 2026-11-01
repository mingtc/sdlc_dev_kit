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
Colours may be `#hex` strings or DTCG colour objects with a `hex`; dimensions `16px` strings or {value, unit} objects. Anything else
(typography, shadows) is listed on stderr and left out. Python 3 standard library only. Exit 1 on input it cannot read.
"""
import argparse, json, re, sys
from pathlib import Path

ALIAS = re.compile(r'^\{([^{}]+)\}$')
HEX = re.compile(r'^#[0-9a-fA-F]{6,8}$')


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
    if isinstance(v, str) and HEX.match(v):
        return v
    if isinstance(v, dict) and isinstance(v.get('hex'), str) and HEX.match(v['hex']):
        return v['hex']
    return None


def dimension(v):
    if isinstance(v, str) and re.match(r'^-?\d+(\.\d+)?(px|rem|em|%)$', v):
        return v
    if isinstance(v, dict) and 'value' in v and 'unit' in v:
        return '%s%s' % (v['value'], v['unit'])
    return None


def family(name):
    head = name.split('.')[0]
    if head == 'color':
        return 'color'
    return 'spacing' if head.startswith(('space', 'spacing')) else 'radius' if head.startswith(('radius', 'corner', 'shape')) else None


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
        skipped, colours, dims = [], {}, {'spacing': {}, 'radius': {}}
        for name, (v, t, desc) in base.items():
            fam = family(name)
            rv = resolve(v, base, base)
            if fam == 'color' and colour(rv):
                colours[name.replace('.', '-')] = {a.first: colour(rv), 'usage': desc}
            elif fam in dims and dimension(rv):
                dims[fam][name.replace('.', '-')] = {'value': dimension(rv), 'usage': desc}
            else:
                skipped.append(name)
        for th, toks in parsed.items():
            if th is None:
                continue
            for name, (v, t, desc) in toks.items():
                key = name.replace('.', '-')
                rv = colour(resolve(v, toks, base))
                if key in colours and rv:
                    colours[key][th] = rv
                elif key not in colours:
                    skipped.append('%s (%s)' % (name, th))
                else:
                    skipped.append('%s (%s, value not read)' % (name, th))
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
    if skipped:
        print('dtcg-convert: left out (no list form): %s' % ', '.join(skipped[:12]) + (' ...' if len(skipped) > 12 else ''), file=sys.stderr)
    print('dtcg-convert: %d colour token(s) in %d theme(s), %d dimension(s) -> %s' % (len(colours), len(themes), sum(len(x) for x in dims.values()), out))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
