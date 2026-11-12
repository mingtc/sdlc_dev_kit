<!-- KIT-CLASS: KIT — template for one canvas's record. Copy it to requirements/design/<canvas>/CANVAS.md and re-mark the copy `KIT-CLASS: PROJECT`. Fill every <angle bracket>. See process/EXTRACTION.md. -->
# CANVAS — <canvas>

- **Canvas:** <canvas title, named for the product, never a PRD id> — <URL, or "none yet"> (a canvas that takes comments is private to the owner or shared within the organisation; a public link cannot)
- **Last pull:** none (then `<canvas version id> @ <repo commit>`: the commit that took the files into `project/`; its manifest is the `## Manifest` section)
- **Last publish:** none (then `<canvas version id> @ <repo commit>`, written after the read-back by sha)
- **Mode:** none (the default model. `wireframe [decision: D-NN]` makes this canvas a wireframe kept current with the PRD: gate 1 by structure, gate 2 `build`; the decision must be an entry of `requirements/DECISIONS.md`. See `requirements/design/README.md` § 6)
- **Pin-ready:** none (the last commit that touched the screen files and tokens a card cites, `CANVAS.md` bookkeeping excluded; set only when every row the card cites has `approved@<sha>` in `gate1`)
- **Breakpoint:** <the width where phone becomes desktop>; widths covered: <phone width>, <desktop width>. A PRD covers the gap between them or says it is out of scope.
- **PRDs served:** <PRD-NNN, PRD-NNN: listed for the reader; no screen belongs to one PRD>
- **Tokens:** `requirements/design/tokens/<ns>.tokens.json` (+ `.dark`, `.wire`)

## Manifest

Written by `/design-pull` and `/design-publish`, one line per `project/` file: `<path> <canvas sha> <repo sha>` (a path may hold a space: the last two fields are the shas). The two shas are equal unless the normaliser rewrote the file. Empty until the first pull or publish.

```
<path> <canvas sha256> <repo sha256>
```

## Screen registry

`platform`: `phone` or `web-desktop`. `pair` names the other width of the same screen (symmetric). `gate1` and `gate2` are
`open`, `changes` or `approved@<sha>`, `<sha>` being the commit that took in the approved version; `gate2` reads `build` in a wireframe canvas. One table per product area, the
same header each time.

### <product area>

| UX-id | file | title | platform | pair | states | stories | gate1 | gate2 |
|---|---|---|---|---|---|---|---|---|
| UX-001 | <Screen>.dc.html | <title (phone)> | phone | UX-002 | default, <state> | <PRD-NNN-F1-S1> | open | open |
| UX-002 | <ScreenDesktop>.dc.html | <title (desktop)> | web-desktop | UX-001 | default, <state> | <PRD-NNN-F1-S1> | open | open |

## Brief

One entry per screen and one per change: the Designer's own spec of what to author on the canvas. Add the screen's registry row
with its brief (`gate1` and `gate2` `open`), so its UX id is taken before the screen exists.

A screen:

```
Author screen UX-001, "<title>", as <Screen>.dc.html, at <width> px. On a new canvas the first board is Main.dc.html.
States: default, <state>. Each state's branch root carries data-state="<state>".
Root: data-ux="UX-001" and data-stories="<PRD-NNN-F1-S1>".
Elements, by id: ux-001-<name> (<what it is>), …
Colours: never a colour literal (#hex, rgb(), hsl() ...) in a style, an attribute or a stylesheet; every colour reads var(--<name>), the colour of a link (a) and of a:hover included.
Tokens: use only these, named for the token's path with hyphens for dots, no prefix (color.primary is --color-primary), each declared once in sheets/tokens.css, a stylesheet file under project/ that every screen links with <link rel="stylesheet" href="sheets/tokens.css">: --<name>: <value>, …
Imported screens (dc-import): such a screen holds no style of its own but font links, @font-face and body{margin:0}; it reads the linked sheet.
Any other stylesheet or script: a file under project/, linked by a relative path. Never an upload (a /_blob/ file cannot be read by the checks).
Copy, per state: <the exact text of each element>
Navigation: <element id> goes to <UX id>, as an <a href>.
```

No tool makes a PNG: a human copies one per state from the canvas (Copy as PNG, 2x), named <Screen>-<state>.png, or an agent that
holds the design runtime renders it locally; the Designer commits them under `renders/`.

A change:

```
On UX-001, state <state>: <the change, naming the element id>. Keep every other element and id as it is.
```

## Proposed PRD citations

The Designer does not edit the PRD. For the PM to add (unpinned), one marker per UI state a story's ACs need.

| Story | Marker(s) the PM adds |
|---|---|
| <PRD-NNN-F1-S1 (AC1)> | `[design: UX-001#default]` `[design: UX-002#default]` |

## Questions for the PM

A mirror of the `dev/questions/` files `scripts/ask.sh` wrote; the files are the channel.

1. <question, story id, the question file's name, and whether it blocks a card>
