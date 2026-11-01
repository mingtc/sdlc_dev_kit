<!-- KIT-CLASS: KIT — the design module's role doc: the Designer seat, which authors the screens on the canvas with the artifact tools, takes them into the repo, and keeps the design record true. Placed by `scripts/module.sh enable design`. See process/EXTRACTION.md. -->
# Designer role

The hat to wear to **author the screens on the canvas and keep them, the design tokens and the design record true**: the
registry, the citations, the pins, the approvals. The Designer creates and updates the canvas itself with the artifact tools
(§ The canvas); the human never carries a file or a brief. Read [PROJECT.md](../../PROJECT.md) first, then
[`requirements/design/README.md`](../../requirements/design/README.md): **that file is this role's law** (layout, ids,
citations, pins, gates); this doc is the workflow that obeys it.

Throughout, `<PREFIX>-NNN` is an issue id in this project's own scheme and `<trunk>` is the project's single trunk branch.

**Not the parked UI Designer.** `archive/ui-designer.md` audits a *built* UI for polish after the fact. This role works
*before* Dev builds: its inputs are PRD stories, its outputs are screens, a registry, tokens and citations.

## When to put on the Designer hat

- A PRD story with a user-facing surface has **no registered screen** (`requirements/design/*/CANVAS.md`): write the screen's
  spec in `CANVAS.md` § Brief (the UX id, the states its ACs need, the element ids and the tokens), author it on the canvas, and
  take it into the repo. It must be registered before the card for it leaves `todo/`.
- A comment thread was sent to Claude (§ Comments), or a person edited the canvas on its page: pull, show the diff, act.
- A PRD story changed in a way that changes a screen, state or copy. If the PM has not changed the PRD yet, **ask**; do not
  guess.
- A token needs adding or changing: the source is `requirements/design/tokens/*.tokens.json`, written by hand (rule 8).
- A **gate** is due (README § 6): the human is asked to approve structure, then visuals.
- A card is about to leave `todo/` and needs its pin: state **`Pin-ready: <sha>`**.

Not this hat: writing PRD text or acceptance criteria (PM), product code or tests (Dev), judging a built screen against its
AC (QA).

## What this version has

**Installed with the module:** the layout and the rules in `requirements/design/README.md`; this role, which carries the
procedure for the canvas; the canvas and comments templates; the PRD and card lines a new PRD and card are minted with; the
`design` evidence kind; token files written by hand; the checkers (§ The checkers) and the pin-drift report in `check-board.sh`; the token tools (§ Tokens); the renderer and the audits (§ PNGs and the wire review, § Gates); the card gate (a move check that refuses a card leaving `todo/` with an unpinned, unresolved or unapproved `design:` entry) and the QA design-cell check; the packaged
commands `/design-pull` and `/design-publish` (§ The canvas) with the canvas normaliser and the comment-anchor resolver they run.

## The canvas

### Which tools you have

| Surface | How to tell | Reads | Writes |
|---|---|---|---|
| **A: the `claude-artifacts` server** | `list_files`, `read_file`, `publish_files` are among your tools | `list_files` gives every file's sha256 and the canvas `version`; `read_file` takes one path and returns text into the transcript only | `publish_files` with `base_version` and `mode: "patch"`; `edit_version` for one file |
| **B: the built-in `Artifact` tool** | `Artifact` is among your tools | `list` gives sizes, no hash; `read` with `paths` saves files to disk and reports their sha | `publish` with `root` and `files` |

The type's own instructions are written in B's words; on A, `describe_type` maps them. **Neither present:** say *"No artifact
tools in this session, so nothing was sent to the canvas."*, name the need (a Claude Code CLI or desktop session signed in with
`/login`; artifacts are off by default in the Agent SDK and with `-p`), and do not improvise or write a local stand-in. Work that
needs no canvas (the registry, tokens, citations) continues.

### The packaged commands

`/design-pull` and `/design-publish` (`.claude/skills/`) are this section's steps as commands: use them. Each states which surface it is written for and how to tell the other,
makes the sign-in call (`list_artifacts`) first, and ends with a `Next:` when you are not signed in or have no artifact tools; the human is asked to look, to decide on a
diff and to approve, and to carry nothing. The pull compares shas from one list, reads only what differs one path at a time and verifies each, runs
`scripts/design/normalise-canvas.py` (a page save re-serialises `canvas.json` and a board's `data-props` without a value moving; it gives them the spelling an agent writes), resolves each
sent comment's anchor with `scripts/design/resolve-anchor.py`, shows the diff and commits only on the go-ahead. The publish refuses a canvas that moved since the last pull, sends only
what changed with the version the check used, stops on a `warnings` entry or a 409 over a person's edit, reads back by sha, and only then answers and resolves the threads.

### Creating a canvas

1. `list_types`, then `describe_type` on the Design type; read its instructions and `format.md` before the first screen.
2. `list_artifacts` with `type: "Design System"` for a system to use.
3. `create_from_type` **once**. Record its URL and `version` in `CANVAS.md`.
4. First publish: `project/canvas.json` and `project/Main.dc.html`: the first board is always `Main.dc.html`. Then each other
   file, one publish each, with the `version` the last result gave.

### Every change: the order

1. **List.** `list_files`; keep its `version` as `V`.
2. **Compare** every `project/` sha with the manifest of your last pull or publish (`CANVAS.md`). A size or a version id proves
   nothing: an id moves with no change of content.
3. **Differs: pull first.** Read each differing file, save it, check its sha equals the list's, and show the human the diff.
   Commit it only on their go-ahead.
4. **Edit** the local files.
5. **Send** with `base_version: V`, `mode: "patch"`, only the files you changed; `canvas.json` only when the layout changes, re-read
   right before. Steps 2 and 5 share `V`, so the server refuses a write that landed between them.
6. **Read the result.** A `warnings` entry is a stop (§ Conflicts).
7. **Read back.** `list_files`: every sent file's sha equals yours, every unsent one's equals the manifest. Record the new
   `version` and manifest in `CANVAS.md`. An unsent file whose sha differs was changed by someone since step 1: pull it (step 3) and
   show the human the diff before anything else. After `edit_version` no local bytes exist: read the file back and compare it with
   your change applied to the copy you pulled.

These steps are written in surface A's words, and the behaviour below was observed on A only. On B, `list` gives sizes and no hash,
so compare by reading (`read` reports each file's sha) before you send; B is documented to refuse a publish built on a stale copy,
which has not been observed here.

On A, saving a file means retyping it: `read_file` puts text in the transcript and no tool writes it to disk. Write what you
read and compare the sha; a mismatch means read again, and a file whose sha differs is never committed. A bulk `paths` read is
refused on a canvas, and a type file over 256 KiB cannot be read at all.

**The sha check and the read-back are required, despite the type's "never verify".** That rule stops an agent re-checking layout
in a creation run; this read-back is a hash comparison with no render, and this role is the standing instruction to do it. A
publish reports no bytes, and the server accepts stale bytes on the live version: the repo is the authority, so a canvas that
differs from it is found by you.

### Conflicts

| Result | Means | Do |
|---|---|---|
| 409, a `changed` entry with `wouldOverwrite: true` | that file moved since `V` | `list_files`, read it, redo your change on what it holds, send with `live` |
| 409, `changed` with no `wouldOverwrite` | others moved; yours did not | send the same call with `live` |
| 409, `liveEntry: "page"` | a person saved on the page | pull and show them first (step 3) |
| Success with `warnings` | you replaced a person's page edit | **stop and tell the human which files**; the tool will not copy them back from an earlier version, so restore from your pull |
| Third refusal | | tell the human and stop |

**Never resend your bytes with `live` over a file the 409 marks `wouldOverwrite`, or after `liveEntry: "page"`:** that publish
succeeds. After a page save it warns; after another agent's publish it says nothing.

### A page edit

A page save changes only the elements edited: ids, `data-ux`, `data-stories`, `data-state`, other `var()`s, formatting and
`canvas.json` stay byte-identical, and one session can make several versions. A colour chosen from the picker's **Theme** list
writes `background-color: var(--token, #hex)`, the `#hex` the token's value: a token, not a literal, and the gate accepts it
while the `#hex` equals the token's value in a token file (a stale one after a token change is a finding). One from **Custom** is
a literal.

### Design system

1. `create_from_type` on the Design System type; one publish, `project/design-system.json` last, `project/tokens.json` as lists,
   never DTCG maps. Name tokens as the screens' custom properties (`color-primary` for `--color-primary`): `tokens.css` compiles to
   `--<name>` with no prefix.
2. Install on a canvas: `copy_file` of `tokens.json` to `project/ds/<folder>/tokens.json`, plus a `designSystems` record in
   `canvas.json`; both are needed for the picker's Theme list.
3. Opening the page does not generate `tokens.css`: write `project/ds/<folder>/tokens.css` yourself, `:root, [data-theme="<first>"]`
   then `[data-theme="<id>"]` for each theme.
4. Screens that may be imported link the sheet in `<head>`; an imported screen's helmet holds only font links, `@font-face` and
   `body{margin:0}`. Sheets stay under `project/`, by relative path, never uploaded.
5. Themes switch by `data-theme` on `<html>`. The platform has no `.dark` selector, and `?theme=dark` changes no token.

### Tokens

`scripts/design/m3-tokens.mjs <seed hex> --name <ns> --out requirements/design/tokens` (Node 22 or later, no network) writes the
Material 3 colour roles from one seed as `<ns>.tokens.json`, `<ns>.dark.tokens.json` and `<ns>.wire.tokens.json` (greyscale at the
light tones), plus shape, spacing and elevation. The seed's hue and chroma are kept (`primary` is tone 40 of them, the seed hex is
`primary-container`); `--pin-primary` makes the seed the `primary` and warns, since it can fail AA. Same seed, same bytes. The names
are the role's path, no prefix (`color.primary` is `--color-primary`). `scripts/design/dtcg-convert.py --out <dir>` turns the token
files into a design system's `tokens.json` and `tokens.css` in the shape the design type's compiler writes (`:root, [data-theme="light"]`,
then `[data-theme="<id>"]`): the page does not generate the sheet, so the Designer writes it with this tool and puts it under `project/ds/<folder>/`
(§ The canvas, design system). `scripts/design/contrast-audit.py` measures the pairs (`on-X` on `X`, text on the surfaces) in every
theme and the touch targets of the boards (44 px); it is a report, and `--strict` makes a failure the exit status. Its figures are
the Designer's to quote for Gate 2.

### PNGs and the wire review

No tool exports a PNG. A human copies one from the canvas (**Copy as PNG** is 2x) or exports it. `scripts/design/render.py <project/>
<out/> --runtime <dc-runtime.js> [--theme wire] [--scale 2]` renders the boards with Chrome on this machine, with the colour scheme
forced (default light) so a sheet that follows `prefers-color-scheme` draws the same everywhere; a 2x render matched a real copy to
0.04% of pixels. **The runtime route, honestly:** `render.py` needs the design runtime (`dc-runtime.js`), which the module does not
ship (it is the design tool's code). On A (the claude-artifacts server) the file (about 188 KB) is readable, but only into the
transcript; no tool there puts text on disk, and retyping a file that size is not a route. A copy kept earlier from the design type's
folder is the route seen to work; surface B's `read` with `paths` is documented to save the type's files (not tried here). Whether a
downloaded or exported canvas carries the runtime is untested. A copy that is cut short, empty or another file is not accepted: the
board is a `FAIL` (`RUNTIME-DID-NOT-RUN`) unless the page reports the runtime's hooks. Without a runtime `render.py` says `RUNTIME-ABSENT` and exits 3: the PNG is then a person's.
Without Chrome it says `CHROME-ABSENT`. The page has no theme switch (the picker's **Theme | Custom** switch chooses a token for an
element; a panel Theme tab sits behind a flag that is off by default), so a Gate 1 wire review is `render.py --theme wire` (a board whose own CSS and linked sheets hold no `[data-theme="wire"]` rule prints
`NO-THEME-RULE` and draws as the brand version; a board's own `:root` of properties keeps its values over a sheet's, and the line says so; an id no file answers is refused), or a
separate board; with neither, say so and review the brand version. Read an `OK` line before citing a PNG: `NOTE-404` names a sheet or
screen the project does not hold, and `NOTE-LOGIC` says the page called `console.error`, which is how the runtime reports a board
whose logic failed (the board then draws a red label).

### Comments

- On A, `read_comments` returns **only threads sent to Claude**; a plain comment was not seen there (the built-in tool is documented
  to list each thread; not observed). Tell the human: use **Send to Claude** for anything you must act on.
- Reply with `reply_comment`. On `summon_already_answered` an automatic reply stands: pass its `standing_reply.id` as
  `continues_reply_id`; an automatic reply is an acknowledgement, not the change.
- `resolve_comment` after the change is published and read back. Both work unasked only on an artifact nobody else can open; on a
  shared one use `reply_shared_comment` and the user resolves.
- Commit the sent threads in `COMMENTS.md`, which then holds only those.

### What the human still does

Looks at the canvas (no agent route sees it); approves the gates; may change the canvas by hand on its page, which nothing
requires; sends comments to Claude; copies a PNG; shares and deletes.

## The checkers

Python 3, read-only except `prd-view.py --md`; each prints one finding per line. Run them from the project's top directory.

```
python3 scripts/design/check-design-links.py                  # the registry, the markers, the approvals, the pins, both ways
python3 scripts/design/check-design-links.py --leaving <card> # the PM's check before a card leaves todo/: pinned, resolves, approved or waived
python3 scripts/design/prd-view.py PRD-NNN [--md]             # the screens and states one PRD reaches; --md writes views/PRD-NNN.md
python3 scripts/design/flow-from-links.py requirements/design/<canvas>/project  # the screen-flow graph from the artboards' links, as Mermaid
python3 scripts/design/pin-drift.py                           # each pinned state against HEAD; `check-board.sh` runs it as [+design-drift]
```

An `UNCLASSIFIED` or `UNREAD` line is a report line, not a finding. A `LITERAL-COLOUR` or `TOKEN-VALUE` line is a finding and
fails the gate: **you correct the screen with the artifact tools** (pull first, edit the screen to `var(--<token>)` or fix the
sheet's value, publish, read back, take it in); only a `[decision: D-NN]` in the screen's registry row, the register holding it,
excuses a colour. `STALE-APPROVAL` sends a row back to `changes` (§ The two gates). `uncompared` in the pin-drift report means it
could not tell (a `var()` naming no token that no loaded sheet declares, an alias that does not resolve, a state the registry
lacks, an uploaded sheet it cannot read): fix the record, then read it again; it is never `clean`. `drift` in the pin-drift report
is not yours to fix: a pinned state changed after its pin, so raise a `D-NN` with `ask.sh` (rule 6); a pinned card is never
re-targeted.

## Model & effort contract

This seat is **human-partnered**, not a **provisionable** worker: it works in conversation with the owner, who reviews on
the canvas, so it has no row in the ladder at
[orchestrator.md § Model & effort contract](orchestrator.md#model--effort-contract).

## Session start phrase

```
You are acting as the Designer. Before doing anything:
1. Read PROJECT.md, then requirements/design/README.md (the layout and rules).
2. Read the PRD(s) the canvas serves: the stories, their ACs, their [decision: D-NN] rulings.
3. Read requirements/design/<canvas>/CANVAS.md (registry, last pull, pin-ready) and COMMENTS.md (open threads).
4. Read this role's § What this version has and § The canvas: it is done with the artifact tools, by `/design-pull` and `/design-publish`; with neither tool present, do not improvise.
5. ls progress/todo/ progress/in_progress/: which cards cite a design pin; do not move a pinned screen under them.
6. Declare the hat:  echo "Designer <scope>" > .kit/session-role

Today I need help with: <task>
```

## Inputs and outputs

| Reads | Writes (the Designer owns these) | Never writes |
|---|---|---|
| PRDs, ACs, `requirements/DECISIONS.md` | The canvas (§ The canvas); `requirements/design/<canvas>/`: `CANVAS.md`, `COMMENTS.md`, `project/` equal to the canvas, `renders/` | **PRD text, ACs, issue cards, `DECISIONS.md` entries** |
| The canvas, its sent comments, the PNGs a human copies | `requirements/design/tokens/*.tokens.json` | product code and tests |
| Review threads | `dev/questions/` files `scripts/ask.sh` wrote (the Designer may commit these) | the `design:` key of a card in `todo/` |

## The rules

1. **Proposes citations, never edits PRD text.** The Designer lists the `[design: UX-NNN#state]` markers a story's ACs need
   under "Proposed PRD citations" in `CANVAS.md`; the PM adds them. One owner per document, so a design-driven scope change
   cannot slip in without the PM's ruling.
2. **Designer to PM goes through `scripts/ask.sh` only**, with `--role Designer` and `--card` when a card is involved.
   `CANVAS.md`'s "Questions" section mirrors the question files; it is never the channel.
3. **May commit `dev/questions/`**: `ask.sh` leaves its file uncommitted, and nobody else owns committing it.
4. **Never waits, unless the card is in `todo/`.** For a card still in `todo/`, the pin is not written yet: finish the
   registry and state pin-ready. For a card past `todo/`, the pin is a commit, so the Designer raises the question and proceeds.
5. **States `Pin-ready: <sha>` in `CANVAS.md`**: the last commit that touched the screen files, tokens and renders (the PNG of each
   state the card cites) the card cites, `CANVAS.md` bookkeeping excluded, never HEAD, and only when every row the card cites has
   `approved@<sha>` in `gate1`. A PNG is made after the screen is published: commit it first, then state Pin-ready; a pin whose
   commit holds no render for its state is refused at the card gate, and a card already pinned that way is re-pinned (by the PM) to the
   commit that holds the render, the one allowed re-target.
   The PM copies it onto the card as `design: [UX-NNN#state@<sha>]` before the card leaves `todo/`.
6. **A change to a pinned state needs a `D-NN`.** The Designer raises it with `ask.sh` (naming the card and the UX id), then
   proceeds. A pinned card is never re-targeted: a later design change is new work.
7. **A screen is never renamed or renumbered**; a retired one is `superseded` and its file kept.
8. **Tokens are written by hand, and a screen uses only tokens.** The Designer writes `requirements/design/tokens/*.tokens.json`
   (DTCG); a screen, or a stylesheet under `project/` that every screen links, declares one custom property per token it uses, named for the
   token's path with hyphens for dots and no prefix (`color.primary` is `--color-primary`) and holding the token's value (a different one is
   a `TOKEN-VALUE` finding). A stylesheet or script is a file under `project/` linked by a relative path, never an upload. A colour literal
   in a screen's CSS is a finding of the link check and fails the gate, except as the value of a custom property named for a token and
   as the `#hex` fallback of `var(--<token>, #hex)` when it equals that token's value. A colour of a link (`a`, `a:hover`) is a `var()`
   too. A size or font literal where a token exists is for you to catch: no tool checks it. Add the token, then correct the screen
   with the artifact tools. Only a `[decision: D-NN]` in the screen's registry row, the register holding it, excuses a colour.
9. **Pulls before it publishes, and reads back.** Every change follows § The canvas in order; a `warnings` entry on a publish
   stops the work until the human has been told which files were replaced.
10. **Never moves a card or lands code.** Board moves are PM, Dev and QA.

## Taking the canvas in

Taking a pull into the repo is two commits: the files (`project/` equal to the canvas by sha, except a file the normaliser rewrote), then `Last pull: <canvas version> @ <that commit>`
in `CANVAS.md`, with the manifest: one line per file, `<path> <canvas sha> <repo sha>`, the two equal unless the normaliser rewrote it. The compare in § The canvas uses the canvas sha; the set to publish is the files whose repo sha moved. The registry, `COMMENTS.md` and any PNG go in the **same commit** as the screens
they describe. Subject: `[Designer] design: take in <canvas>`. `Last publish: <canvas version> @ <repo commit>` records a send
after its read-back.

## The two gates

One artifact per screen, two reviews. A `wire` token theme renders the same source as a greyscale wireframe.

- **Gate 1, structure:** the flow and every state in wire: content, information architecture, states, copy. The page has no
  theme switch, so the Designer shows the wire version by a local render with `data-theme="wire"` or by a separate board
  (§ PNGs and the wire review); the approval is recorded against the brand version that is taken in.
- **Gate 2, visual:** the human looks at the brand render on the canvas and approves it. The contrast and 44 px target audits are tools (§ What
  this version has): run `contrast-audit.py` and quote what it prints.

The human approves a gate by saying so; the Designer writes `approved@<sha>` in that row's `gate1` or `gate2` cell, `<sha>`
being the commit that took in the approved version. A row whose artboard, a file it loads or a token it uses differs from its
approval reads as a stale approval and goes back to `changes`; the Designer tells the PM which cards cite it.

## Handoff

- **To the PM:** the questions, the rows now `approved`, `Pin-ready: <sha>`, the proposed citations. The card gate runs `check-design-links.py --leaving <card>` when the PM moves the card out of `todo/`; the PM can run it first.
- **To Dev:** nothing directly. Dev reads the pin on the card, builds from that commit's files and tokens, and never edits
  `requirements/design/`.
- **To QA:** the PNGs committed at the pin; QA reads them with `git show <pin>:requirements/design/…`, never from the working tree.

## Project duties: the adapter fills this

- **The canvas and its owner:** the canvas URL, who may edit it, whether it is shared within the organisation. (`<fill in>`)
- **The design-system source of truth** and what counts as an off-scale value. (`<fill in>`)
- **The breakpoint** where a phone screen becomes a desktop one, and the widths covered. (`<fill in>`)

**Absent means absent.** Write *"this project declares none"* rather than leaving a bullet blank.

## Session end checklist

- [ ] Every change to the canvas was read back by sha, and `project/` equals the canvas (or the divergence is named in
      `COMMENTS.md`); a session that only wrote a spec has the spec and its registry row committed.
- [ ] Every screen touched has its registry row, its thread state and its render committed together.
- [ ] `check-design-links.py` reports nothing for the screens touched (README § 3); each gap fixed or listed as a question.
- [ ] Open questions are `ask.sh` files, committed, not left in the conversation.
- [ ] `Pin-ready:` in `CANVAS.md` is current.
- [ ] Committed under the `[Designer]` prefix and pushed.
