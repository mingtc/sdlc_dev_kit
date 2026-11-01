<!-- KIT-CLASS: KIT — the design module's release notes, in the shape of the kit's own; kit-upgrade.sh reads them while the module is enabled. See process/EXTRACTION.md. -->
# The design module — release notes

Each release is a `## [X.Y.Z]` section, newest first. An entry under `### Action required` becomes an item on
the upgrade checklist of a project that has the module enabled and last took an older version; entries under
any other heading are not read. Nothing here is read while the module is disabled.

## [0.2.0]

### Action required

- **Install Python 3.9 or later.** The checkers below are Python 3 (standard library only), and the manifest now requires it:
  `./scripts/module.sh status design` says whether it holds, and `enable` refuses a project that lacks it. Without
  Python, the new pin-drift report prints a skip line and the gate row's command fails.
  Verify: python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)'
- **Screens that carry colour literals go red at the gate.** A project whose existing screens hold a colour literal
  (in a style, a style attribute, a presentation attribute, or a sheet or imported screen they load, other than as the value of a custom property
  named for a token, and other than as the `#hex` fallback of `var(--<token>, #hex)` equal to that token's value) fails
  `check-design-links.py --strict` after the upgrade.
  Run it first; for each finding the Designer corrects the screen with the artifact tools so it uses a token, or record a
  `[decision: D-NN]` in the screen's registry row (the entry must be in `requirements/DECISIONS.md` with a Ruling that is not WITHDRAWN).

### Added

- **The checkers.** `scripts/design/check-design-links.py` reports the links between PRD stories, screens and cards in both
  directions (an uncovered `(UI)` AC, an unresolved citation, a row citing no story, a stale `Design: pending`, a stale or
  sha-less approval, a card's malformed `design:` value) and, with `--leaving <card>`, what a card leaving `todo/` owes: a pin, a
  commit that resolves and holds the screen, an approved row that still holds, or a `[decision: D-NN]` waiver on its `design:`
  line that `requirements/DECISIONS.md` confirms. A colour literal in a style, a style attribute, a presentation attribute, or a sheet or imported screen a screen loads, is a finding, except as the value of a custom property named for a token, unless the screen's registry row carries a `[decision: D-NN]` the register holds; a colour in the component script is a report line. A custom property named for a token, with no prefix (`--color-primary` for `color.primary`), must hold that token's value (`TOKEN-VALUE`). A stylesheet or script is a file under `project/`, linked by a relative path or by a leading `/` read from `project/`; one uploaded to the canvas (`/_blob/<id>`) cannot be read, and the check says `UNREAD` where the pin report says `uncompared`.
  It reads the PRD prefix from `scripts/config.sh` and refuses rather than report on no PRDs.
  `prd-view.py` lists the screens and states one PRD reaches, `flow-from-links.py` derives the screen-flow graph from the
  artboards' links, and `pin-drift.py` compares each pinned state with HEAD. A PRD or story with no `**UI:**` line reads as
  none declared and gets an info line, not a finding.
- **The pin-drift report.** `check-board.sh` prints `[+design-drift]`: for every card past `todo/` and not landed or declined,
  each pinned state as `clean`, `moved`, `drift`, `gone`, `unresolved` or `uncompared` (it could not tell, and says why: never
  `clean`), by its artboard, the tokens it uses and the local files it loads (stylesheets, scripts, images, screens it imports with `<dc-import>`, through `@import`); an uploaded sheet or script, a `var()` naming no token that no loaded sheet declares, or a mark the row does not list gives `uncompared`. A new state on a pinned screen, with its flag added to the component script, is not a change, and a state is compared by the files and tokens its own branch loads. It reports and decides nothing. A screen names a token's custom property by the token's path with hyphens for dots.

### Changed

- The gate row the module puts in `PROJECT.md` runs `python3 scripts/design/check-design-links.py --strict`; it said `N/A`.
  Upgrading replaces the block, or stages it for a merge if you edited it.
- **The Designer authors the canvas itself.** It creates and updates the Claude Design canvas with the artifact tools, by the order in
  its role (list, compare shas, pull first, edit, send with `base_version`, read back by sha); the human carries no file or brief.
  A `warnings` entry on a publish is a stop. A plain comment on the canvas is invisible to the Designer: use Send to Claude. The
  packaged `/design-pull` and `/design-publish` skills are not in this version. A colour literal's next act is the Designer
  correcting the screen; the Gate 1 wire review is a local render with `data-theme="wire"` or a separate board, since the page has no
  theme switch; no tool makes a PNG, so a human copies one (Copy as PNG, 2x) or an agent that holds the design runtime renders it.
  The runtime cannot be fetched on the `claude-artifacts` surface, so a local render needs a copy a human or the built-in tool supplies.
- A screen with its own registry row reports its colours on its own row, not again on a screen that imports it.

## [0.1.0]

### Added

- **The skeleton.** A Designer role (`[Designer]` commits), the rules for `requirements/design/` (layout, ids, citations,
  pins, the two review gates, flows), canvas and comments templates, a `**UI:** none` line minted into a new PRD's first
  story and `design: none` into a new card, the `design` evidence kind, and CORPUS, gate and ignore rows. No action.
- **Not in 0.1.0:** the canvas adapter (`/design-pull`, `/design-publish`), the design drift check, the card gate, the
  token generator and the colour utility, the renderer and audits, and the checkers. The Designer role lists them, and says
  to tell the user a capability needs the next version of the kit rather than improvise it.
