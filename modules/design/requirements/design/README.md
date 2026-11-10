<!-- KIT-CLASS: MIXED — kit shape (the rules below), PROJECT content (your canvases and tokens); placed by `scripts/module.sh enable design`. See process/EXTRACTION.md. -->
# `requirements/design/` — screens, flows and tokens, beside the PRDs

Design is **evergreen corpus**, like the PRDs: it describes what the product looks like *now*, and git is its version
store. A design tool's canvas is the *working surface*, where the Designer authors and revises the screens with the artifact tools; this
directory is the *record* and the authority. The human looks, approves and may change the canvas by hand; nobody carries files.
The workflow that obeys these rules is [`.claude/roles/designer.md`](../../.claude/roles/designer.md).

**Read its § What this version has before doing any of this.** The Designer takes the canvas in with `/design-pull` and sends to it with `/design-publish`.
This binds every role: Dev and QA compare a build against the PNG committed at the pin, and do not render a screen file by hand.

## 1. Layout

```
requirements/design/<canvas>/        one canvas per PRODUCT, or per platform or major area once it outgrows one; never per PRD
  project/                           the canvas's files exactly as taken in: artboards and whatever else the tool holds
  CANVAS.md                          canvas URL, last pull, pin-ready, breakpoint, the SCREEN REGISTRY, the brief, proposed citations
  COMMENTS.md                        every review thread, as last pulled
  renders/<Screen>-<state>.png       committed renders (a PNG a human copies from the canvas, or a local render): the human-readable record
requirements/design/views/PRD-NNN.md GENERATED, never hand-edited
requirements/design/tokens/<ns>.tokens.json (+ .dark, .wire)  DTCG source of truth; generated outputs are never hand-edited
```

`.claude/templates/design/CANVAS.template.md` and `COMMENTS.template.md` start a canvas.

- **Organised by product structure, never by PRD.** Pages by product area, flows by user journey. The canvas directory and
  title are named for the product. A canvas tool's files are flat, so **product areas are registry sections** (one table per
  area, same header), not directories. A second PRD adds story ids to existing rows and adds no directory.
- **One canvas per product**, split by platform or major area once it outgrows 512 files or 40 pages.
- `views` and `tokens` are reserved names: no canvas takes either. `views/` is a `generated` CORPUS bucket.
- Dated design **passes** (the parked UI Designer's) live in `dev/design-passes/`, never here.

## 2. Identity

- A screen is `UX-NNN`, project-wide, kept in the board title and on the artboard root as `data-ux="UX-NNN"`. It is
  **never renamed or renumbered**; a retired screen is `superseded` and its file kept.
- A **state** is the screen's variant: `UX-003#some-done`. A bare `UX-003` means "any state" and is never pinned.
- Elements carry `ux-NNN-name` ids; a repeated row takes an interpolated id (`ux-003-item-{{item.id}}`). An id may repeat
  across exclusive branches of one state switch; no two elements with one id may be visible together.
- The artboard root carries `data-stories="<story ids>"`, the registry row's copy. `data-state="<state> [<state> …]"` on
  a state branch's root is opt-in and gives a drift check state-level precision; without it a verdict is per file.

**Registry**, a table in `CANVAS.md` whose header is read by name:

```
| UX-id | file | title | platform | pair | states | stories | gate1 | gate2 |
```

`stories` holds the story ids of **every** PRD that touches the screen: no row belongs to one PRD. `pair` names the phone
or desktop row of the same screen (symmetric). `gate1` and `gate2` are `open`, `changes` or `approved@<sha>` (§ 6); `gate2` may also read `build` in a wireframe canvas (§ 6).
`CANVAS.md` declares the **breakpoint** and the widths covered; a PRD covers the gap or says it is out of scope.

## 3. Citations from the PRDs

- Every story carries a `**UI:**` line: the states it needs, or `none`. A PRD minted while the module is enabled gets
  `**UI:** none` in its first story; the PM adds the line to every later story. A PRD with no `**UI:**` lines at all
  predates the module and reads as "none declared", not as a defect; so does a story that lacks the line in a PRD whose other
  stories have it. The link check prints an `UNCLASSIFIED` info line for each such PRD and never a finding.
- Each AC visible on a screen is tagged `(UI)`, **including an AC that opens a surface**. The tag goes after the id and its
  separator (`AC1: (UI) …`; on a card, `AC1 — (UI) from <story id>: …`): the QA gate reads a checklist line only when the
  separator follows the id, and a line it cannot read is an AC that needs no verdict row.
- The marker is `[design: UX-NNN#state]`, **on the AC line**, one per state, and one per width where a screen has a pair. A
  range is not a citation. A marker in a code span or fenced block is prose. Cite by UX-id and state, never by path.
- A feature with UI and no screens yet carries `**Design:** pending — UX states needed: <state>, <state>`: the Designer's
  input. Replace it in the commit that lands the first marker.
- The Designer proposes markers in `CANVAS.md` and never edits PRD text; the PM adds them.
- **PRDs stay evergreen.** An enhancement to a screen another PRD owns edits the sentences it makes untrue and appends
  **delta stories** (new ids after the last, marked *(delta, PRD-NNN)*) under a `## Deltas` section of the owning PRD.
  **An AC a card already carries is never edited**: add a delta story.
- Both directions are read: every (UI) AC has a marker; every marker resolves to a registry row and state; every row cites
  a story; no `Design: pending` outlives its first marker. `python3 scripts/design/check-design-links.py` reports these, and
  `--strict` makes it the design-record gate in `PROJECT.md`: it says the PRDs, the registry, the approvals and the pins of cards in
  flight agree, and nothing about a build. `prd-view.py <PRD id>` lists the screens and states one PRD reaches. A gate cell is
  `open`, `changes`, `superseded` or `approved@<sha>`; a card's `design:` value is `none` or `[UX-NNN#state@<commit>, ...]`. In a wireframe canvas (§ 6) an `UNCOVERED` or `STALE-PENDING` finding that reaches only its rows is shown and not counted.

## 4. Pins

- A card's `design:` key is `none` (no screen) or a list of `UX-NNN#state`. In `todo/` it is **unpinned**.
- Leaving `todo/`, each entry gains `@<commit>`: written by the PM, who owns the card in `todo/`, at the Designer's
  `Pin-ready: <sha>`. That sha is the last commit that touched the screen files, tokens and renders (each cited state's PNG) the card
  cites, **excluding `CANVAS.md` bookkeeping** (recording a pin touches that file, so counting it would never settle).
- Only a row whose `gate1` is `approved@<sha>` can be pinned, or the card's `design:` line carries a named waiver, a
  `[decision: D-NN]` in its trailing comment: it covers every screen on that line, and its D-NN must be an entry of
  `requirements/DECISIONS.md`. The sha in an
  approval is the commit that took in the approved version; an approval whose artboard, a file it loads (a sheet, a script, an image, a screen it imports) or a token it uses has since changed is **stale** and the row goes back to
  `changes`; the link check reports it as `STALE-APPROVAL` (in a wireframe canvas, § 6, only a change of structure makes gate 1 stale).
- Before the card moves, every entry is checked: it carries `@<commit>`, that commit resolves and holds the screen's artboard, its
  row is approved (`approved@<sha>`, an ancestor of the pin and still true at HEAD) or waived, and a card whose ACs cite a screen
  does not say `design: none` or leave one out. The card gate, a move check on `in_progress/` and `dev_complete/` read from the trunk,
  refuses a card arriving from `todo/` (or from `blocked/` when it was never in progress; one back from `blocked/` is checked only
  for being pinned) with a `Next:` line and changes nothing;
  `python3 scripts/design/check-design-links.py --leaving <card>` is the same check, to run first.
- **Drift is reported, not blocked.** `check-board.sh` prints, for every card past `todo/` and not in `done/`, `declined/` or
  `history/`, each pinned state as `clean`, `moved`, `drift`, `gone`, `unresolved` or `uncompared` (`[+design-drift]`; the last means
  something could not be compared, and the line says what: it is never `clean`). A state is compared by
  its artboard, the tokens it uses and the local files it loads (stylesheets, scripts, images, screens it imports with `<dc-import>`, through `@import`), per state when the
  artboard marks its branches with `data-state`, else per file; the pinned state's branches and everything outside all branches must
  be identical, or the line says `drift`. A
  `drift` line says `ruling pending` when a question file or `DECISIONS.md` names the card and the screen, and `owed` when not.
- **A pinned card is never re-targeted** (the one exception: the PM re-pins an entry whose commit holds no render of its state to the commit that holds it). A change to a pinned state needs a `D-NN`, which the Designer raises with
  `scripts/ask.sh` and then proceeds; a later design change is new work. An element added to a pinned state is a change; a
  new state on a pinned screen is not (its branch, its flag in the component script and its option in the script's props, added and nothing else changed). The pin includes the tokens.
- **A pin is a commit; a path is not.** A screen may move. Where a card or a QA record must show a path, qualify it with the
  commit it was true at.
  A test reads the canvas at the card's pin (`git show <pin>:<path>`), never at HEAD: the canvas is committed to the trunk
  without a gate, so a test that reads it there fails on the Designer's next round. A test that must read it at HEAD makes
  that path code (`scripts/config.sh`'s `CODE_GLOBS`).
- `CANVAS.md` records `Last pull: <canvas version> @ <repo commit>` and `Last publish: <canvas version> @ <repo commit>` (after the
  read-back by sha). Taking the canvas in is two commits: the files, then the record of the first one's sha.

## 5. Scope and evidence

- A card may carry `design-scope:`: element ids it does not build. Everything else in the pinned render must match.
- Each (UI) QA row gets a design cell with evidence kind `design`:
  `UX-003#some-done@<pin>: identical | diffs: <ids>` (`.claude/templates/design/QA-verdict-design.fragment.md`). The pinned
  side is the PNG committed at the pin (`git show <pin>:requirements/design/<canvas>/renders/<Screen>-<state>.png`),
  never the working tree; a human or the orchestrator compares the build's screenshot with it (`dev/evidence/README.md`), and QA records
  the result. A row with no image is not a PASS: the QA gate runs a
  cell check on each PASS row of kind `design`, which refuses unless every entry says `identical`, its pin is a commit the card
  carries in `design:`, both images are PNGs committed on the trunk (by Dev or the project's tooling, never by QA's leaf worker), the build image is
  not the pin image, and the pin image is the render the pin commit holds for that screen and state. A card cannot reach
  `qa_complete/` while an AC tagged `(UI)`, or citing a screen, has no design row for each state it cites. For a pin to a wireframe canvas
  `identical` means the same screens, states, elements, flow and copy as the pinned wireframe; styling is not compared (§ 6).

## 6. Fidelity: one artifact, two gates

One artifact per screen; a `wire` token theme renders the same source as a greyscale wireframe, so **a literal colour in a
screen is not allowed outside a token's value**. Tokens are written by hand in the DTCG files, or generated from a seed colour (`scripts/design/m3-tokens.mjs`), and a screen
(or a stylesheet under `project/` that every screen links, which is how an imported screen reads them, since its own style is limited to font links,
`@font-face` and `body{margin:0}`) declares one custom property per token it uses, holding the token's value. The property is named for the
token's path with hyphens for dots, **with no prefix** (`color.primary` is `--color-primary`): that is how the design tool compiles a design system's
tokens, and a prefix cannot be told from a stray name, so a prefixed sheet is a finding until the tokens are named without one. Its value is the
token's: a different one is a `TOKEN-VALUE` finding (a theme block of a sheet is held to the token file of that theme, `<ns>.<theme>.tokens.json`, and `:root` to the base file; a theme with no file is shown as `UNCOMPARED`, never as clean; the gate stays green).
Stylesheets and scripts are files under `project/` linked by a relative path (or by a leading `/`, read from `project/`); one uploaded to the canvas
(`/_blob/<id>`) cannot be read, and is shown as an `UNREAD` line by the link check and as `uncompared` by the pin report. A colour literal
(`#hex`, `rgb()`, `hsl()`, `oklch()` ...) in a screen's style blocks, style attributes, presentation attributes or a stylesheet or screen it loads, is a
`LITERAL-COLOUR` finding of the link check and fails the gate, wherever it sits, `:root` rules included, except as the value of a custom
property named for a token (`--color-primary` for `color.primary`): that is how a screen's `:root` rule, and a theme selector of a token
sheet, hold a token's value, so a sheet that only defines tokens passes. The `#hex` fallback of `var(--<token>, #hex)` is no finding
when it equals that token's value in a token file (it is what the canvas's colour picker writes for a token), and is one when it
differs, which also catches a fallback left stale by a token change. A custom property that is no token's, or a colour in a
non-custom property of `:root`, is a finding. A screen that has its own registry row reports its colours on its own row only, not
again on a screen that imports it. A colour name (`red`) is not caught. A colour in the component script is shown
as a `SCRIPT-COLOUR` line and never fails the gate: a script is code and copy and cannot be read as CSS. The way out is for the
Designer to correct the screen with the artifact tools (pull first, edit it to `var(--<token>)`, publish, read back). The one
exception is a recorded decision: a `[decision: D-NN]` in the screen's registry
row (its title cell), the same marker and the same register as a card's waiver on its `design:` line, the D-NN an entry of
`requirements/DECISIONS.md` with a current ruling.

- **Gate 1, structure:** the flow and every state in wire: content, information architecture, states, copy. The canvas's page has
  no theme switch (its colour picker's Theme | Custom switch chooses a token for an element), so the wire version is a local
  render (`render.py --theme wire`), which needs the design runtime (a gap the role states), or a separate board. The
  platform has no `.dark` selector, and `?theme=dark` changes no token: themes are `data-theme` blocks. The approval is recorded
  against the brand version that is taken in.
- **Gate 2, visual:** the brand render, a contrast audit and a 44 px target audit (`scripts/design/contrast-audit.py`). The human
  approves the render on the canvas; the audits are tools, and their figures are quoted as printed.
- The human approves a gate by saying so; the Designer writes `approved@<sha>` in the cell. Failure and empty-state copy are
  the Designer's deliverable per state.

### Wireframe mode

A canvas that is a wireframe of flow and content, kept current as part of the PRD, with the build as the visual anchor, says so in its
header: `- **Mode:** wireframe [decision: D-NN]`. Without the mode such a canvas is either frozen, to keep its approvals, or its
approvals reset at every sync until they mean nothing. The decision is a ruling `requirements/DECISIONS.md` holds with a current
ruling (the check a waiver gets); without one the mode is not in effect and the link check reports `WAIVER`. No line, or `none`, is the
default model above; any other value is a `REGISTRY` finding. The mode is per canvas.

- **Gate 1 is structure and flow**: the screens, their states, the elements that carry an id, and the links. It is approved per
  **round**. A round is one Designer take-in commit; the human approves once for the rows that read `STALE-APPROVAL` or `open` after it,
  and the Designer writes that commit's sha as `approved@<sha>` into those rows only. A row whose structure did not move stays
  approved at its older sha.
- **Structure** is the ordered start and end tags of the artboard and of each screen it imports, each start tag with its attributes
  except `class`, `style`, `data-props` and `data-stories`; text is not read. An element added, removed, moved or renamed, a
  `data-state` and a link are structure: the approval goes stale. Text and numbers (renumbering, copy), classes, styles, a sheet, a
  token, an image, the component script and its props are content: the approval stands, and the link check lists the row on one
  `CONTENT-ONLY` line. An attribute not named above counts as structure. Script or props logic that changes which branch shows is
  the build's, not gate 1's.
- **Gate 2 is taken on the build.** Its cell reads `build`, valid only in this mode, and is not judged (nor is a gate 2 approval
  written before). No contrast or target audit is run. The build is accepted by the QA design row of each (UI) AC (§ 5).
- **`--strict`** prints a `MODE` line, shows an `UNCOVERED` or `STALE-PENDING` finding as `UNCOVERED-WIRE` or `STALE-PENDING-WIRE` when
  every row it reaches is in a wireframe canvas, and counts them on its summary line; nothing else is demoted. A story that a default
  canvas's row also lists keeps its findings.
- **Unchanged**: a card still pins (`design:` entries, `@<commit>`, the render at the pin, gate 1 approved or waived), a change to a
  pinned state still needs a `D-NN`, the pin-drift report compares bytes, and a colour or token finding still fails the gate.
- **Switching** is editing the Mode line. No approval is rewritten; each is judged by the rule in force at the next check. Removing the
  line sends a row whose content moved since its approval back to review and makes a `build` a `GATE-CELL` finding; adding it needs the
  decision.

## 7. Flows

One flow artboard per user journey, embedding the real screens, with labelled action (solid) and condition (dashed) arrows.
Every navigation is an `<a href>`, so `scripts/design/flow-from-links.py` derives the graph from the screens, to compare with the drawn flow.

## 8. Who owns what

| Role | Owns / does |
|---|---|
| **PM** | PRDs and ACs; answers the Designer's questions; mints cards and writes the pin. |
| **Designer** | The canvas records (`CANVAS.md`, `COMMENTS.md`), registry and tokens; the renders as brought in. Proposes citations, never edits PRD text. Questions to the PM go through `scripts/ask.sh` only. |
| **Dev** | Builds from the pinned design and its tokens; never edits this directory. |
| **QA** | Verifies each (UI) AC; cites the images by sha and records in the design cell the result of the comparison a human or the orchestrator made. |
| **The human** | Looks at the canvas and approves the gates; sends the comments the Designer must act on with Send to Claude (a plain comment was invisible to the agent on the claude-artifacts server); copies a PNG; may change the canvas by hand. Carries nothing. |
