<!-- KIT-CLASS: KIT — the design module's own README: what it adds, how to switch it on and off, and what this version has. Stays in modules/design/; nothing here is placed into a project. See process/EXTRACTION.md. -->
# The design module

Projects with a UI need designs that are as evergreen, reviewable and versioned as their PRDs. This module keeps them in the
repo beside the PRDs, ties each screen to the stories it serves and to the card that built it, and lets a canvas tool (Claude
Design is the first) be the working surface without ever being the authority: the repo is the record, and a canvas edit
reaches it only when the Designer pulls it, shows the diff and commits it.

It is **off until enabled** ([`process/MODULES.md`](../../process/MODULES.md)).

```sh
./scripts/module.sh enable design     # or, on day one: ./scripts/kit-init.sh … --with design. Commit what it prints, and push
./scripts/module.sh disable design    # takes back every file and block still as enable wrote it; keeps and names an edited one
```

Push the enabling commit before expecting `[Designer]` to be known to `check-board.sh`, which reads the trunk.

The same holds for every Designer commit: the gates read `origin/<trunk>`, so the Designer pushes each one as it was made (`bash scripts/design/trunk-sync.sh push`, never a rebase), and `/design-pull` and `/design-publish` stop first when the trunk is ahead, behind or diverged.

`disable` takes back the files, not the cards: a card in flight keeps its `design:` key and its pins, which nothing reads while the module is off, so a card pinned to a screen can reach `qa_complete/` and land with no design row. Land or park those cards first, or enable the module again.

| Adds | Where |
|---|---|
| Role `Designer` | `.claude/roles/designer.md`, `process/roles.d/design` |
| The rules: layout, ids, citations, pins, gates, flows | `requirements/design/README.md` |
| Canvas and comments templates; guides for a PRD, a card and a QA design cell | `.claude/templates/design/` |
| `**UI:** none` in a new PRD's first story; `design: none` in a new card | `process/fragments.d/` |
| Evidence kind `design` | `process/evidence-kinds.d/design` |
| The checkers: the link check, the PRD view, the flow graph, the pin-drift report | `scripts/design/`; Python 3, which `enable` requires |
| The pin-drift arm of `check-board.sh`, report only | `scripts/check-board.d/50-design-drift.sh` |
| The card gate: a card arrives in `in_progress/` or `dev_complete/` pinned, resolved and approved | `scripts/move-check.d/in_progress/50-design-pin.sh`, `scripts/move-check.d/dev_complete/50-design-pin.sh` |
| The design rows check: a card reaches `qa_complete/` with a design row for every UI AC and every `design:` entry | `scripts/move-check.d/qa_complete/50-design-rows.sh` |
| The QA design-cell check on each PASS row of kind `design` | `scripts/qa-cell.d/design/50-design-cell.sh`, with `scripts/design/check-design-cell.py` |
| Gate row, CORPUS manifest and bucket rows | blocks in `PROJECT.md` and `requirements/CORPUS.md` |
| Ignore lines for the pull's scratch folder and generated tokens | a block at the end of `.gitignore` |
| The canvas commands: `/design-pull` and `/design-publish` (Claude Code 2.1.228 or later and a claude.ai login, optional), the normaliser for a page save's re-serialising, the comment-anchor resolver and the trunk check and push | `.claude/skills/design-pull/SKILL.md`, `.claude/skills/design-publish/SKILL.md`, `scripts/design/normalise-canvas.py`, `scripts/design/resolve-anchor.py`, `scripts/design/trunk-sync.sh` |
| The token generator (Node 22 or later, optional), the token converter, the renderer (Chrome and a design runtime you supply, optional) and the contrast and target audits | `scripts/design/m3-tokens.mjs`, `dtcg-convert.py`, `render.py`, `contrast-audit.py`, with `scripts/design/vendor/` (Apache-2.0, see its `NOTICE`) |

## What this version has

Available now: the layout, the Designer role, the rules, token files written by hand or generated from a seed, and the Designer creating and updating the
Claude Design canvas itself with the artifact tools, by the order in its role (list, compare shas, pull first, edit, send with
`base_version`, read back), as the packaged commands `/design-pull` and `/design-publish`; nothing passes through a person. The checkers are installed: the
link check between PRD stories, screens and cards (also the gate row in `PROJECT.md`), the PRD view, the flow graph, and the
pin-drift report that `check-board.sh` prints.
[`SETUP.md`](SETUP.md) has the steps for a human to start.
