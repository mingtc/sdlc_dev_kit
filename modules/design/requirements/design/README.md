<!-- KIT-CLASS: MIXED — kit shape (the rules below), PROJECT content (your canvases and tokens); placed by `scripts/module.sh enable design`. See process/EXTRACTION.md. -->
# `requirements/design/` — screens, flows and tokens, beside the PRDs

Design is **evergreen corpus**, like the PRDs: it describes what the product looks like *now*, and git is its version
store. A design tool's canvas is the *working surface* a human edits; this directory is the *record* and the authority.
The workflow that obeys these rules is [`.claude/roles/designer.md`](../../.claude/roles/designer.md), which also says
what this version of the module can and cannot do.

## 1. Layout

```
requirements/design/<canvas>/        one canvas per PRODUCT, or per platform or major area once it outgrows one; never per PRD
  project/                           the canvas's files exactly: artboards and whatever else the tool holds
  CANVAS.md                          canvas URL, last pull, pin-ready, breakpoint, the SCREEN REGISTRY, proposed citations
  COMMENTS.md                        every review thread, as last pulled
  renders/<Screen>-<state>.png       committed renders: the human-readable record
requirements/design/views/PRD-NNN.md GENERATED, never hand-edited
requirements/design/tokens/<ns>.tokens.json (+ .dark, .wire)  DTCG source of truth; generated outputs are never hand-edited
```

`.claude/templates/design/CANVAS.template.md` and `COMMENTS.template.md` start a canvas.

- **Organised by product structure, never by PRD.** Pages by product area, flows by user journey. The canvas directory and
  title are named for the product. A canvas tool's files are flat, so **product areas are registry sections** (one table per
  area, same header), not directories. A second PRD adds story ids to existing rows and adds no directory.
- **One canvas per product**, split by platform or major area once it outgrows about 500 files or 40 pages.
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
or desktop row of the same screen (symmetric). `gate1` and `gate2` are `open`, `changes` or `approved@<sha>` (§ 6).
`CANVAS.md` declares the **breakpoint** and the widths covered; a PRD covers the gap or says it is out of scope.

## 3. Citations from the PRDs

- Every story carries a `**UI:**` line: the states it needs, or `none`. A PRD minted while the module is enabled gets
  `**UI:** none` in its first story; the PM adds the line to every later story. A PRD with no `**UI:**` lines at all
  predates the module and reads as "none declared", not as a defect.
- Each AC visible on a screen is tagged `(UI)`, **including an AC that opens a surface**.
- The marker is `[design: UX-NNN#state]`, **on the AC line**, one per state, and one per width where a screen has a pair. A
  range is not a citation. A marker in a code span or fenced block is prose. Cite by UX-id and state, never by path.
- A feature with UI and no screens yet carries `**Design:** pending — UX states needed: <state>, <state>`: the Designer's
  brief. Replace it in the commit that lands the first marker.
- The Designer proposes markers in `CANVAS.md` and never edits PRD text; the PM adds them.
- **PRDs stay evergreen.** An enhancement to a screen another PRD owns edits the sentences it makes untrue and appends
  **delta stories** (new ids after the last, marked *(delta, PRD-NNN)*) under a `## Deltas` section of the owning PRD.
  **An AC a card already carries is never edited**: add a delta story.
- Both directions are read: every (UI) AC has a marker; every marker resolves to a registry row and state; every row cites
  a story; no `Design: pending` outlives its first marker. Where a checker is installed it reports these; otherwise the
  Designer and PM read them at each hand-off.

## 4. Pins

- A card's `design:` key is `none` (no screen) or a list of `UX-NNN#state`. In `todo/` it is **unpinned**.
- Leaving `todo/`, each entry gains `@<commit>`: written by the PM, who owns the card in `todo/`, at the Designer's
  `Pin-ready: <sha>`. That sha is the last commit that touched the screen files and tokens the card cites, **excluding
  `CANVAS.md` bookkeeping** (recording a pin touches that file, so counting it would never settle).
- Only a row whose `gate1` is `approved@<sha>` can be pinned, or the pin carries a named waiver in a `D-NN`. The sha in an
  approval is the commit it was given at; an approval whose artboard has since changed is **stale** and the row goes back to
  `changes`.
- Before the card moves, the PM checks every entry: it carries `@<commit>`, that commit resolves, its row is approved or
  waived. Where a card gate is installed it refuses the move; otherwise this check is the PM's.
- **A pinned card is never re-targeted.** A change to a pinned state needs a `D-NN`, which the Designer raises with
  `scripts/ask.sh` and then proceeds; a later design change is new work. An element added to a pinned state is a change; a
  new state on a pinned screen is not. The pin includes the tokens.
- **A pin is a commit; a path is not.** A screen may move. Where a card or a QA record must show a path, qualify it with the
  commit it was true at.
- `CANVAS.md` records `Last pull: <canvas version> @ <repo commit>`.

## 5. Scope and evidence

- A card may carry `design-scope:`: element ids it does not build. Everything else in the pinned render must match.
- Each (UI) QA row gets a design cell with evidence kind `design`:
  `UX-003#some-done@<pin>: identical | diffs: <ids>` (`.claude/templates/design/QA-verdict-design.fragment.md`). QA renders
  the pinned side from `git archive <pin>`, never from the working tree.

## 6. Fidelity: one artifact, two gates

One artifact per screen; a `wire` token theme renders the same source as a greyscale wireframe, so **a literal colour in a
screen is not allowed**.

- **Gate 1, structure:** the flow and every state in wire: content, information architecture, states, copy.
- **Gate 2, visual:** the brand render, a contrast audit and a 44 px target audit.
- The human approves a gate by saying so; the Designer writes `approved@<sha>` in the cell. Failure and empty-state copy are
  the Designer's deliverable per state.

## 7. Flows

One flow artboard per user journey, embedding the real screens, with labelled action (solid) and condition (dashed) arrows.
Every navigation is an `<a href>`, so the graph can be derived from the screens and compared with the drawn flow.

## 8. Who owns what

| Role | Owns / does |
|---|---|
| **PM** | PRDs and ACs; answers the Designer's questions; mints cards and writes the pin. |
| **Designer** | Canvases, tokens, registry, `COMMENTS.md`, renders. Proposes citations, never edits PRD text. Questions to the PM go through `scripts/ask.sh` only. |
| **Dev** | Builds from the pinned design and generated tokens; never edits this directory. |
| **QA** | Verifies each (UI) AC; the design cell compares the build with the pinned render. |
| **The human** | Comments and edits on the canvas; approves the gates. |
