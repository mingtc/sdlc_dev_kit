<!-- KIT-CLASS: KIT — the design module's own README: what it adds, how to switch it on and off, and what this version has. Stays in modules/design/; nothing here is placed into a project. See process/EXTRACTION.md. -->
# The design module

Projects with a UI need designs that are as evergreen, reviewable and versioned as their PRDs. This module keeps them in the
repo beside the PRDs, ties each screen to the stories it serves and to the card that built it, and lets a canvas tool (Claude
Design is the first) be the working surface without ever being the authority: the repo is the record, and a canvas edit
reaches it only through a human.

It is **off until enabled** ([`process/MODULES.md`](../../process/MODULES.md)).

```sh
./scripts/module.sh enable design     # or, on day one: ./scripts/kit-init.sh … --with design. Commit what it prints, and push
./scripts/module.sh disable design    # takes back every file and block still as enable wrote it; keeps and names an edited one
```

Push the enabling commit before expecting `[Designer]` to be known to `check-board.sh`, which reads the trunk.

| Adds | Where |
|---|---|
| Role `Designer` | `.claude/roles/designer.md`, `process/roles.d/design` |
| The rules: layout, ids, citations, pins, gates, flows | `requirements/design/README.md` |
| Canvas and comments templates; guides for a PRD, a card and a QA design cell | `.claude/templates/design/` |
| `**UI:** none` in a new PRD's first story; `design: none` in a new card | `process/fragments.d/` |
| Evidence kind `design` | `process/evidence-kinds.d/design` |
| Gate row, CORPUS manifest and bucket rows | blocks in `PROJECT.md` and `requirements/CORPUS.md` |
| Ignore lines for the renderer's cache and generated tokens | a block at the end of `.gitignore` |

## What this version has

Available now: the layout, the Designer role, the rules, and working with Claude Design by hand (the human carries files
between the canvas and the repo). While `/design-pull`, `/design-publish`, the design drift check, the card gate or the
token generator is absent from your project, asking for it gets the answer that it needs the next version of the kit.
[`SETUP.md`](SETUP.md) has the steps for a human to start.
