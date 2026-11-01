#!/usr/bin/env node
// KIT-CLASS: KIT — design tool: Material 3 token files (DTCG) from one seed colour. Needs Node 22 or later; no network, no npm.
// usage: m3-tokens.mjs <seed hex> [--name NS] [--out DIR] [--pin-primary]
//   Writes DIR/NS.tokens.json (light), NS.dark.tokens.json and NS.wire.tokens.json (greyscale at the light tones, for the
//   Gate 1 wire review), colours as hex strings, named by role (`color.primary` is `--color-primary`, no prefix).
//   Colour: the vendored material-color-utilities (Apache-2.0, vendor/NOTICE), SchemeTonalSpot, every dynamic role, light and dark.
//   FIDELITY BY DEFAULT: the seed's hue and chroma are kept: `primary` is tone 40 of them (tone 80 in dark) and the seed hex is
//   `primary-container`; `--pin-primary` makes the seed hex `primary` itself, and warns, since it can fail AA.
//   Shape and elevation: vendor/m3-static.json; spacing is the 4dp grid, its steps listed below. Deterministic: the same seed gives the same bytes.
//   Every on-colour of a container is searched among the palette's tones until it reaches 4.5:1 on it; a seed where none does warns.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const mcu = await import(path.join(here, 'vendor', 'material-color-utilities', 'index.js'));
const { argbFromHex, hexFromArgb, Hct, SchemeTonalSpot, MaterialDynamicColors, TonalPalette, Contrast } = mcu;

const args = process.argv.slice(2);
const opt = (n, d) => (args.includes(n) ? args[args.indexOf(n) + 1] : d);
const valueOf = new Set(['--name', '--out'].map(n => args.indexOf(n) + 1).filter(i => i > 0));
const seed = args.find((a, i) => !valueOf.has(i) && /^#?[0-9a-fA-F]{6}$/.test(a));
if (!seed) { console.error('usage: m3-tokens.mjs <seed hex> [--name NS] [--out DIR] [--pin-primary]'); process.exit(64); }
const ns = opt('--name', 'm3');
const out = opt('--out', 'requirements/design/tokens');
const pin = args.includes('--pin-primary');
const S = JSON.parse(fs.readFileSync(path.join(here, 'vendor', 'm3-static.json'), 'utf8'));

const kebab = s => s.replace(/[A-Z]/g, c => '-' + c.toLowerCase());
const roleNames = Object.getOwnPropertyNames(Object.getPrototypeOf(new MaterialDynamicColors()))
  .filter(n => n !== 'constructor' && n !== 'highestSurface' && !/PaletteKeyColor$|^(primary|secondary|tertiary|error)Dim$/.test(n));
const seedHex = (seed.startsWith('#') ? seed : '#' + seed).toLowerCase();
const source = Hct.fromInt(argbFromHex(seedHex));
const hex = argb => hexFromArgb(argb).toLowerCase();
const toneHex = (pal, tone) => hex(pal.tone(tone));

function roles(dark) {
  const sch = new SchemeTonalSpot(source, dark, 0.0, '2021'), dc = new MaterialDynamicColors(), o = {};
  for (const n of roleNames) { const c = dc[n](); if (c) o[kebab(n)] = hex(c.getArgb(sch)); }
  // fidelity: the seed's own hue and chroma for the primary family
  const pal = TonalPalette.fromHueAndChroma(source.hue, source.chroma);
  // the on-colour of a container: the first tone, nearest to the scheme's own (10, or 100 on a dark container), that reaches 4.5:1 on it
  const lum = argb => { const f = c => { c /= 255; return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4; }; return 0.2126 * f((argb >> 16) & 255) + 0.7152 * f((argb >> 8) & 255) + 0.0722 * f(argb & 255); };
  const wcag = (x, y) => { const [p, q] = [lum(x), lum(y)].sort((m, n) => n - m); return (p + 0.05) / (q + 0.05); };
  const onTone = (bg, preferred) => {
    const bgArgb = argbFromHex(bg);
    const order = [preferred, ...[10, 5, 0, 15, 20, 90, 95, 100, 25, 80].filter(t => t !== preferred)];
    for (const t of order) if (wcag(pal.tone(t), bgArgb) >= 4.5) return t;
    console.error(`warning: no tone of the seed's palette reaches 4.5:1 on ${bg}; the on-colour is the best of the tried tones`);
    return order.reduce((best, t) => (wcag(pal.tone(t), bgArgb) > wcag(pal.tone(best), bgArgb) ? t : best), order[0]);
  };
  if (pin && !dark) {
    o.primary = seedHex;
    o['on-primary'] = toneHex(pal, 100);   // the scheme's own on-primary: white; a light seed then fails AA, which the warning says
  } else {
    o.primary = toneHex(pal, dark ? 80 : 40);
    o['on-primary'] = toneHex(pal, dark ? 20 : 100);
    o['primary-container'] = dark ? toneHex(pal, 30) : seedHex;
    o['on-primary-container'] = dark ? toneHex(pal, 90) : toneHex(pal, onTone(seedHex, 10));
  }
  return o;
}
const light = roles(false), dark = roles(true);
const grey = h => { const t = Hct.fromInt(argbFromHex(h)).tone; return hex(Hct.from(0, 0, t).toInt()); };
const wire = Object.fromEntries(Object.entries(light).map(([k, v]) => [k, grey(v)]));

const px = v => v + 'px';
const colorGroup = (m, desc) => ({ $type: 'color', $description: desc, ...Object.fromEntries(Object.entries(m).map(([k, v]) => [k, { $value: v }])) });
const dim = (desc, entries) => ({ $type: 'dimension', $description: desc, ...Object.fromEntries(entries.map(([k, v]) => [k, { $value: px(v) }])) });
const head = { $description: 'Material 3 from seed ' + seedHex + ' (TonalSpot, spec 2021)' + (pin ? ', primary pinned to the seed' : ', fidelity default') + '. Generated by m3-tokens.mjs; edit the seed, not the file.' };
const base = {
  ...head,
  color: colorGroup(light, 'Colour roles, light.'),
  radius: dim('Shape corners (material-web v0_192).', Object.entries(S.shape).map(([k, v]) => ['corner-' + k.replace(/^corner-/, ''), v])),
  spacing: dim('4dp grid steps (not an official M3 token set).', [0, 2, 4, 8, 12, 16, 20, 24, 32, 40, 48, 56, 64].map(v => ['space-' + v, v])),
  elevation: dim('Elevation levels in dp.', Object.entries(S.elev)),
};
fs.mkdirSync(out, { recursive: true });
const write = (f, o) => fs.writeFileSync(path.join(out, f), JSON.stringify(o, null, 2) + '\n');
write(ns + '.tokens.json', base);
write(ns + '.dark.tokens.json', { $description: head.$description + ' Dark.', color: colorGroup(dark, 'Colour roles, dark.') });
write(ns + '.wire.tokens.json', { $description: head.$description + ' Greyscale at the light tones.', color: colorGroup(wire, 'Colour roles, wire.') });
if (pin) console.error('warning: --pin-primary makes the seed the primary; its contrast with on-primary is not guaranteed (contrast-audit.py says).');
console.log(`seed ${seedHex} -> ${out}/${ns}.{,dark.,wire.}tokens.json; ${Object.keys(light).length} colour roles; primary ${light.primary} / ${dark.primary}`);
