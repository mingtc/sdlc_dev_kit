<!-- KIT-CLASS: KIT — template for one canvas's record. Copy it to requirements/design/<canvas>/CANVAS.md and re-mark the copy `KIT-CLASS: PROJECT`. Fill every <angle bracket>. See process/EXTRACTION.md. -->
# CANVAS — <canvas>

- **Canvas:** <canvas title, named for the product, never a PRD id> — <URL, or "none yet"> (a canvas that takes comments is private to the owner or shared within the organisation; a public link cannot)
- **Last pull:** none (then `<canvas version id> @ <repo commit>`, or `by hand (<date>) @ <repo commit>` when the human brought the files; the commit is the one that took them into `project/`)
- **Last publish:** none (nothing is sent to the canvas by hand; the human makes repo-side changes there)
- **Pin-ready:** none (the last commit that touched the screen files and tokens a card cites, `CANVAS.md` bookkeeping excluded; set only when every row the card cites has `approved@<sha>` in `gate1`)
- **Breakpoint:** <the width where phone becomes desktop>; widths covered: <phone width>, <desktop width>. A PRD covers the gap between them or says it is out of scope.
- **PRDs served:** <PRD-NNN, PRD-NNN: listed for the reader; no screen belongs to one PRD>
- **Tokens:** `requirements/design/tokens/<ns>.tokens.json` (+ `.dark`, `.wire`)

## Screen registry

`platform`: `phone` or `web-desktop`. `pair` names the other width of the same screen (symmetric). `gate1` and `gate2` are
`open`, `changes` or `approved@<sha>`, `<sha>` being the commit the approval was given at. One table per product area, the
same header each time.

### <product area>

| UX-id | file | title | platform | pair | states | stories | gate1 | gate2 |
|---|---|---|---|---|---|---|---|---|
| UX-001 | <Screen>.dc.html | <title (phone)> | phone | UX-002 | default, <state> | <PRD-NNN-F1-S1> | open | open |
| UX-002 | <ScreenDesktop>.dc.html | <title (desktop)> | web-desktop | UX-001 | default, <state> | <PRD-NNN-F1-S1> | open | open |

## Brief

For the human who draws on the canvas, one entry per screen: the UX id (`data-ux`), the states its ACs need, the element ids
(`ux-NNN-name`) and the tokens to use.

- <UX-001: states default, <state>; elements ux-001-<name>, …; tokens <names>>

## Proposed PRD citations

The Designer does not edit the PRD. For the PM to add (unpinned), one marker per UI state a story's ACs need.

| Story | Marker(s) the PM adds |
|---|---|
| <PRD-NNN-F1-S1 (AC1)> | `[design: UX-001#default]` `[design: UX-002#default]` |

## Questions for the PM

A mirror of the `dev/questions/` files `scripts/ask.sh` wrote; the files are the channel.

1. <question, story id, the question file's name, and whether it blocks a card>
