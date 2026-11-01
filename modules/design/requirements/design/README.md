<!-- KIT-CLASS: MIXED — kit shape (the rules below), PROJECT content (your canvases and tokens); placed by `scripts/module.sh enable design`. See process/EXTRACTION.md. -->
# `requirements/design/` — screens, flows and tokens, beside the PRDs

Design is **evergreen corpus**, like the PRDs: it describes what the product looks like *now*, and git is its version
store. A design tool's canvas is the *working surface*, where the tool's own agent makes and revises the screens; this directory is
the *record* and the authority. The Designer briefs that agent and takes the result in; creating and updating the artifact
directly needs the next version of the kit, and until then the human carries the brief and the result between them.
The workflow that obeys these rules is [`.claude/roles/designer.md`](../../.claude/roles/designer.md).

**Read its § What this version has before doing any of this by hand.** Each capability that section lists as needing the next
version of the kit is not installed: do not improvise it, and say that it needs the next version of the kit, which brings it. This binds
every role: Dev and QA compare a build against the PNG committed at the pin, and do not render a screen file by hand.

## 1. Layout

```
requirements/design/<canvas>/        one canvas per PRODUCT, or per platform or major area once it outgrows one; never per PRD
  project/                           the canvas's files exactly as taken in: artboards and whatever else the tool holds
  CANVAS.md                          canvas URL, last pull, pin-ready, breakpoint, the SCREEN REGISTRY, the brief, proposed citations
  COMMENTS.md                        every review thread, as last pulled
  renders/<Screen>-<state>.png       committed renders (the canvas's PNG exports): the human-readable record
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
or desktop row of the same screen (symmetric). `gate1` and `gate2` are `open`, `changes` or `approved@<sha>` (§ 6).
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
  `open`, `changes`, `superseded` or `approved@<sha>`; a card's `design:` value is `none` or `[UX-NNN#state@<commit>, ...]`.

## 4. Pins

- A card's `design:` key is `none` (no screen) or a list of `UX-NNN#state`. In `todo/` it is **unpinned**.
- Leaving `todo/`, each entry gains `@<commit>`: written by the PM, who owns the card in `todo/`, at the Designer's
  `Pin-ready: <sha>`. That sha is the last commit that touched the screen files and tokens the card cites, **excluding
  `CANVAS.md` bookkeeping** (recording a pin touches that file, so counting it would never settle).
- Only a row whose `gate1` is `approved@<sha>` can be pinned, or the card's `design:` line carries a named waiver, a
  `[decision: D-NN]` in its trailing comment: it covers every screen on that line, and its D-NN must be an entry of
  `requirements/DECISIONS.md`. The sha in an
  approval is the commit that took in the approved version; an approval whose artboard has since changed is **stale** and the row goes back to
  `changes`; the link check reports it as `STALE-APPROVAL`.
- Before the card moves, the PM checks every entry: it carries `@<commit>`, that commit resolves, its row is approved or
  waived. Where a card gate is installed it refuses the move; otherwise this check is the PM's, and
  `python3 scripts/design/check-design-links.py --leaving <card>` runs it, and also checks that each pin holds the screen's artboard,
  is not older than its row's approval, and that the approval still holds at HEAD.
- **Drift is reported, not blocked.** `check-board.sh` prints, for every card past `todo/` and not in `done/`, `declined/` or
  `history/`, each pinned state as `clean`, `moved`, `drift`, `gone`, `unresolved` or `uncompared` (`[+design-drift]`; the last means
  something could not be compared, and the line says what: it is never `clean`). A state is compared by
  its artboard, the tokens it uses and the local files it loads (stylesheets, scripts, images, through `@import`), per state when the
  artboard marks its branches with `data-state`, else per file; the pinned state's branches and everything outside all branches must
  be identical, or the line says `drift`. A
  `drift` line says `ruling pending` when a question file or `DECISIONS.md` names the card and the screen, and `owed` when not.
- **A pinned card is never re-targeted.** A change to a pinned state needs a `D-NN`, which the Designer raises with
  `scripts/ask.sh` and then proceeds; a later design change is new work. An element added to a pinned state is a change; a
  new state on a pinned screen is not. The pin includes the tokens.
- **A pin is a commit; a path is not.** A screen may move. Where a card or a QA record must show a path, qualify it with the
  commit it was true at.
- `CANVAS.md` records `Last pull: <canvas version> @ <repo commit>`, or `by hand (<date>) @ <repo commit>` when the human
  brought the files. Taking the canvas in is two commits: the files, then the record of the first one's sha.

## 5. Scope and evidence

- A card may carry `design-scope:`: element ids it does not build. Everything else in the pinned render must match.
- Each (UI) QA row gets a design cell with evidence kind `design`:
  `UX-003#some-done@<pin>: identical | diffs: <ids>` (`.claude/templates/design/QA-verdict-design.fragment.md`). QA reads
  the pinned side from the PNG committed at the pin (`git show <pin>:requirements/design/<canvas>/renders/<Screen>-<state>.png`),
  never from the working tree, and compares the build's screenshot with it. A row with no image is not a PASS.

## 6. Fidelity: one artifact, two gates

One artifact per screen; a `wire` token theme renders the same source as a greyscale wireframe, so **a literal colour in a
screen is not allowed outside its `:root` block**. Tokens are written by hand in the DTCG files until a token generator is installed, and a screen
carries a `:root` block with one custom property per token it uses, holding the token's value. The property is named for the
token's path with hyphens for dots (`color.primary` is `--color-primary`). A colour literal (`#hex`, `rgb()`, `hsl()`, `oklch()` ...)
in a screen's style blocks, style attributes, presentation attributes or a local stylesheet it links, outside a `:root` rule, is a
`LITERAL-COLOUR` finding of the link check and fails the gate; `:root` rules (also `:root[...]` and `:root, :host`) are exempt, and
a custom property declared anywhere (`--name: value`, as a theme selector of a token sheet does) defines a token and is exempt too, so a
sheet that only defines tokens passes. A colour name (`red`) is not caught. A colour in the component script is shown
as a `SCRIPT-COLOUR` line and never fails the gate: a script is code and copy and cannot be read as CSS. The way out is a change request through the brief, which the human carries to the design
tool's agent; the screen is not edited by hand. The one exception is a recorded decision: a `[decision: D-NN]` in the screen's registry
row (its title cell), the same marker and the same register as a card's waiver on its `design:` line, the D-NN an entry of
`requirements/DECISIONS.md` with a current ruling. A token change on a screen is a request the human carries to the design tool's agent.

- **Gate 1, structure:** the flow and every state in wire: content, information architecture, states, copy. The human asks
  the design tool's agent to switch the screen's `:root` to the `.wire` token values, reviews, and has it switch back; only
  the brand version is carried back, and the approval is recorded against that version.
- **Gate 2, visual:** the brand render, a contrast audit and a 44 px target audit. The human approves the render on the
  canvas; the audits are tools, and while they are not installed no figure is given for them.
- The human approves a gate by saying so; the Designer writes `approved@<sha>` in the cell. Failure and empty-state copy are
  the Designer's deliverable per state.

## 7. Flows

One flow artboard per user journey, embedding the real screens, with labelled action (solid) and condition (dashed) arrows.
Every navigation is an `<a href>`, so `scripts/design/flow-from-links.py` derives the graph from the screens, to compare with the drawn flow.

## 8. Who owns what

| Role | Owns / does |
|---|---|
| **PM** | PRDs and ACs; answers the Designer's questions; mints cards and writes the pin. |
| **Designer** | The canvas records (`CANVAS.md`, `COMMENTS.md`), registry and tokens; the renders as brought in. Proposes citations, never edits PRD text. Questions to the PM go through `scripts/ask.sh` only. |
| **Dev** | Builds from the pinned design and its tokens; never edits this directory. |
| **QA** | Verifies each (UI) AC; the design cell compares the build with the pinned render. |
| **The human** | Carries the brief and change requests to the design tool's agent, and its files, PNGs and comments back; looks at the result and approves the gates. |
