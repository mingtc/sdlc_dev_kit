<!-- KIT-CLASS: KIT — the design module's release notes, in the shape of the kit's own; kit-upgrade.sh reads them while the module is enabled. See process/EXTRACTION.md. -->
# The design module — release notes

Each release is a `## [X.Y.Z]` section, newest first. An entry under `### Action required` becomes an item on
the upgrade checklist of a project that has the module enabled and last took an older version; entries under
any other heading are not read. Nothing here is read while the module is disabled.

## [0.1.0]

### Added

- **The skeleton.** A Designer role (`[Designer]` commits), the rules for `requirements/design/` (layout, ids, citations,
  pins, the two review gates, flows), canvas and comments templates, a `**UI:** none` line minted into a new PRD's first
  story and `design: none` into a new card, the `design` evidence kind, and CORPUS, gate and ignore rows. No action.
- **Not in 0.1.0:** the canvas adapter (`/design-pull`, `/design-publish`), the design drift check, the card gate, the
  token generator and the colour utility, the renderer and audits, and the checkers. The Designer role lists them, and says
  to tell the user a capability needs the next version of the kit rather than improvise it.
