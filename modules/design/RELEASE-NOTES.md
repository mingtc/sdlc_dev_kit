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
  named for a token) fails `check-design-links.py --strict` after the upgrade.
  Run it first; for each finding send a change request through the brief so the design tool's agent uses a token, or record a
  `[decision: D-NN]` in the screen's registry row (the entry must be in `requirements/DECISIONS.md` with a Ruling that is not WITHDRAWN).

### Added

- **The checkers.** `scripts/design/check-design-links.py` reports the links between PRD stories, screens and cards in both
  directions (an uncovered `(UI)` AC, an unresolved citation, a row citing no story, a stale `Design: pending`, a stale or
  sha-less approval, a card's malformed `design:` value) and, with `--leaving <card>`, what a card leaving `todo/` owes: a pin, a
  commit that resolves and holds the screen, an approved row that still holds, or a `[decision: D-NN]` waiver on its `design:`
  line that `requirements/DECISIONS.md` confirms. A colour literal in a style, a style attribute, a presentation attribute, or a sheet or imported screen a screen loads, is a finding, except as the value of a custom property named for a token, unless the screen's registry row carries a `[decision: D-NN]` the register holds; a colour in the component script is a report line.
  It reads the PRD prefix from `scripts/config.sh` and refuses rather than report on no PRDs.
  `prd-view.py` lists the screens and states one PRD reaches, `flow-from-links.py` derives the screen-flow graph from the
  artboards' links, and `pin-drift.py` compares each pinned state with HEAD. A PRD or story with no `**UI:**` line reads as
  none declared and gets an info line, not a finding.
- **The pin-drift report.** `check-board.sh` prints `[+design-drift]`: for every card past `todo/` and not landed or declined,
  each pinned state as `clean`, `moved`, `drift`, `gone`, `unresolved` or `uncompared` (it could not tell, and says why: never
  `clean`), by its artboard, the tokens it uses and the local files it loads (stylesheets, scripts, images, screens it imports with `<dc-import>`, through `@import`); a missing local file, a `var()` naming no token or a mark the row does not list gives `uncompared`. It reports and decides nothing. A screen names a token's custom property by the token's path with hyphens for dots.

### Changed

- The gate row the module puts in `PROJECT.md` runs `python3 scripts/design/check-design-links.py --strict`; it said `N/A`.
  Upgrading replaces the block, or stages it for a merge if you edited it.

## [0.1.0]

### Added

- **The skeleton.** A Designer role (`[Designer]` commits), the rules for `requirements/design/` (layout, ids, citations,
  pins, the two review gates, flows), canvas and comments templates, a `**UI:** none` line minted into a new PRD's first
  story and `design: none` into a new card, the `design` evidence kind, and CORPUS, gate and ignore rows. No action.
- **Not in 0.1.0:** the canvas adapter (`/design-pull`, `/design-publish`), the design drift check, the card gate, the
  token generator and the colour utility, the renderer and audits, and the checkers. The Designer role lists them, and says
  to tell the user a capability needs the next version of the kit rather than improvise it.
