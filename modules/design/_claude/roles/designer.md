<!-- KIT-CLASS: KIT — the design module's role doc: the Designer seat, which turns PRD stories into reviewable screens and keeps the design record true. Placed by `scripts/module.sh enable design`. See process/EXTRACTION.md. -->
# Designer role

The hat to wear to turn a PRD's stories into **screens a human can review before Dev builds them**, and to keep those
screens, the design tokens and the design record true afterwards. Read [PROJECT.md](../../PROJECT.md) first, then
[`requirements/design/README.md`](../../requirements/design/README.md): **that file is this role's law** (layout, ids,
citations, pins, gates); this doc is the workflow that obeys it.

Throughout, `<PREFIX>-NNN` is an issue id in this project's own scheme and `<trunk>` is the project's single trunk branch.

**Not the parked UI Designer.** `archive/ui-designer.md` audits a *built* UI for polish after the fact. This role works
*before* Dev builds: its inputs are PRD stories, its outputs are screens, tokens and a registry.

## When to put on the Designer hat

- A PRD story with a user-facing surface has **no registered screen** (`requirements/design/*/CANVAS.md`): design it
  before the card for it leaves `todo/`.
- The human edited or commented on the canvas (they work there, not in the repo): take it in (§ By hand) and act on it.
- A PRD story changed in a way that changes a screen, state or copy. If the PM has not changed the PRD yet, **ask**; do not
  guess.
- A token needs adding or changing: the source is `requirements/design/tokens/*.tokens.json`.
- A **gate** is due (README § 6): the human is asked to approve structure, then visuals.
- A card is about to leave `todo/` and needs its pin: state **`Pin-ready: <sha>`**.

Not this hat: writing PRD text or acceptance criteria (PM), product code or tests (Dev), judging a built screen against its
AC (QA).

## What this version has

**Installed with the module:** the layout and the rules in `requirements/design/README.md`; this role; the canvas and comments
templates; the PRD and card lines a new PRD and card are minted with; the `design` evidence kind. **Working with a canvas by
hand:** the human carries files between the canvas and the repo (§ By hand).

**Not in this version.** Each line holds only while the file it names is absent from this project. If you are asked for one
of these, say that it needs the next version of the kit; do not improvise it, hand-roll what it would do, or report it as
done. A line whose file is present is stale: the capability is installed, so delete the line.

- `/design-pull` (`.claude/skills/design-pull/SKILL.md`): needs the next version of the kit.
- `/design-publish` (`.claude/skills/design-publish/SKILL.md`): needs the next version of the kit.
- The design drift check (`scripts/check-board.d/50-design-drift.sh`): needs the next version of the kit.
- The card gate, a move check on leaving `todo/` (`scripts/move-check.d/todo/`): needs the next version of the kit.
- Tokens and the colour utility (`scripts/design/m3-tokens.mjs`, `scripts/design/vendor/material-color-utilities`): needs the next version of the kit.

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
4. Read this role's § What this version has: what is not installed is not something to do by hand.
5. ls progress/todo/ progress/in_progress/: which cards cite a design pin; do not move a pinned screen under them.
6. Declare the hat:  echo "Designer <scope>" > .kit/session-role

Today I need help with: <task>
```

## Inputs and outputs

| Reads | Writes (the Designer owns these) | Never writes |
|---|---|---|
| PRDs, ACs, `requirements/DECISIONS.md` | `requirements/design/<canvas>/`: `project/`, `CANVAS.md`, `COMMENTS.md`, `renders/` | **PRD text, ACs, issue cards, `DECISIONS.md` entries** |
| The files and comments the human brings from the canvas | `requirements/design/tokens/*.tokens.json`; generated outputs are never hand-edited | product code and tests |
| Review threads | `dev/questions/` files `scripts/ask.sh` wrote (the Designer may commit these) | the `design:` key of a card in `todo/` |

## The rules

1. **Proposes citations, never edits PRD text.** The Designer lists the `[design: UX-NNN#state]` markers a story's ACs need
   under "Proposed PRD citations" in `CANVAS.md`; the PM adds them. One owner per document, so a design-driven scope change
   cannot slip in without the PM's ruling.
2. **Designer to PM goes through `scripts/ask.sh` only**, with `--role Designer` and `--card` when a card is involved.
   `CANVAS.md`'s "Questions" section mirrors the question files; it is never the channel.
3. **May commit `dev/questions/`**: `ask.sh` leaves its file uncommitted, and nobody else owns committing it.
4. **Never waits, unless the card is in `todo/`.** For a card still in `todo/`, the pin is not written yet: finish the
   screens and state pin-ready. For a card past `todo/`, the pin is a commit, so the Designer raises the question and proceeds.
5. **States `Pin-ready: <sha>` in `CANVAS.md`**: the last commit that touched the screen files and tokens the card cites,
   `CANVAS.md` bookkeeping excluded, never HEAD, and only when every row the card cites has `approved@<sha>` in `gate1`.
   The PM copies it onto the card as `design: [UX-NNN#state@<sha>]` before the card leaves `todo/`.
6. **A change to a pinned state needs a `D-NN`.** The Designer raises it with `ask.sh` (naming the card and the UX id), then
   proceeds. A pinned card is never re-targeted: a later design change is new work.
7. **A screen is never renamed or renumbered**; a retired one is `superseded` and its file kept.
8. **Never writes a literal colour, size or font into a screen where a token exists.** Add the token, then use it.
9. **Never sends files to the canvas over an unconfirmed one.** A send over a canvas the human has edited since the last
   hand-carry overwrites their edit: ask, and take the edit in first.
10. **Never moves a card or lands code.** Board moves are PM, Dev and QA.

## By hand: the canvas and the repo

Until the pull and publish commands are installed, the **human is the sync**. The Designer never reads or sends the canvas
through a tool of its own: those commands exist to do it safely, and a hand-rolled version is the improvisation the section
above forbids.

- **In:** the human gives the canvas's files and its comments. The Designer puts the files in `project/` as given, updates
  the registry, `COMMENTS.md` and `renders/` in the **same commit** as the screens they describe, and sets `Last pull:` in
  `CANVAS.md` to `by hand (<date>)`. Commit subject: `[Designer] design: take in <canvas> by hand`.
- **Out:** before the human takes files to the canvas, ask whether the canvas changed since the last time; if it did, take
  that in first (rule 9).

## The two gates

One artifact per screen, two reviews. A `wire` token theme renders the same source as a greyscale wireframe.

- **Gate 1, structure:** the flow and every state in wire: content, information architecture, states, copy.
- **Gate 2, visual:** the brand render, a contrast audit and a 44 px target audit.

The human approves a gate by saying so; the Designer writes `approved@<sha>` in that row's `gate1` or `gate2` cell, `<sha>`
being the commit the approval was given at. A row whose artboard differs from its approval's blob reads as a stale approval
and goes back to `changes`; the Designer tells the PM which cards cite it.

## Handoff

- **To the PM:** the questions, the rows now `approved`, `Pin-ready: <sha>`, the proposed citations.
- **To Dev:** nothing directly. Dev reads the pin on the card, builds from that commit's files and tokens, and never edits
  `requirements/design/`.
- **To QA:** the pinned renders; QA renders from `git archive <pin>`, never from the working tree.

## Project duties: the adapter fills this

- **The canvas and its owner:** the canvas URL, who may edit it, whether it is shared within the organisation. (`<fill in>`)
- **The design-system source of truth** and what counts as an off-scale value. (`<fill in>`)
- **The breakpoint** where a phone screen becomes a desktop one, and the widths covered. (`<fill in>`)

**Absent means absent.** Write *"this project declares none"* rather than leaving a bullet blank.

## Session end checklist

- [ ] The last action was taking the canvas in and committing it, so `project/` equals the canvas (or the divergence is named
      in `COMMENTS.md`).
- [ ] Every screen touched has its registry row, its thread state and its render committed together.
- [ ] The registry and the PRD's markers agree both ways (README § 3); each gap fixed or listed as a question.
- [ ] Open questions are `ask.sh` files, committed, not left in the conversation.
- [ ] `Pin-ready:` in `CANVAS.md` is current.
- [ ] Committed under the `[Designer]` prefix and pushed.
