<!-- KIT-CLASS: KIT — guide for a QA verdict: the design cell of a (UI) AC row, evidence kind `design`. See process/EXTRACTION.md. -->
# QA verdict: the design cell

Each AC tagged `(UI)` gets one verdict row whose evidence kind is `design` (the module registers it; it is pointer-only).
The pointer is one cell, holding one entry per pinned state (a further cell is read by nothing):

```
| AC3 | PASS | design | UX-001#<state>@<pin>: identical (image); dev/evidence/<PREFIX>-NNN/UX-001-<state>-pin.png, dev/evidence/<PREFIX>-NNN/UX-001-<state>-build.png |
| AC4 | FAIL_AC | design | UX-002#<state>@<pin>: diffs: ux-002-title, ux-002-cta; dev/evidence/<PREFIX>-NNN/UX-002-<state>-pin.png, dev/evidence/<PREFIX>-NNN/UX-002-<state>-build.png |
```

- `identical (image)`, `identical (structure)` or `diffs: <element ids>`, one per state the AC cites; it names only elements outside the card's
  `design-scope:`. The word after `identical` says which comparison you made; `requirements/design/README.md` § 5 states who compares and how, and what to write when you can do neither. A bare `identical` is refused, and `identical (structure)` is refused unless the pin is to a wireframe canvas in effect (next bullet).
- For a pin to a canvas in wireframe mode at the pin commit (its `CANVAS.md` there has the Mode line and `requirements/DECISIONS.md` there holds the ruling it cites; the link check, run in a checkout of the pin, prints a `MODE` line for it), either word of `identical` means the same screens, states, elements, flow and copy as the pinned wireframe; styling is not compared, and a diff in colour, type or spacing is not a `diffs:` entry.
- The pinned side is the PNG committed at the pin, `git show <pin>:requirements/design/<canvas>/renders/<Screen>-<state>.png`, never the working tree. A screen file is never rendered by hand.
- A design row names both images (the pinned PNG, `-pin`, and the build's screenshot, `-build`), committed **on the trunk** under `dev/evidence/<PREFIX>-NNN/`, each a PNG, the build image not the pin image. Dev makes and commits both at handoff (`requirements/design/README.md` § 5 has the recipe); QA cites them, and does not make them. A row with no image is not a PASS: if the
  committed PNG is missing or unusable, say so on the row and do not pass it.
- Write the pointer so no `word:number` appears other than a real `path:line`: the gate reads every one as a path.
- The design row is not an observed row on its own: the landing needs one `test` or `file:line` row, or a row that ends with a pointer
  the gate re-reads. A card or slice whose only AC is `(UI)` has one row, so end its `design` cell with `; <path>:<line> "<quote>"`,
  the code that shows the AC met and a verbatim quote of it, as `qa.md` step 4 asks for a `file:line` quote:

```
| AC1 | PASS | design | UX-001#<state>@<pin>: identical (image); dev/evidence/<PREFIX>-NNN/UX-001-<state>-pin.png, dev/evidence/<PREFIX>-NNN/UX-001-<state>-build.png; src/list.css:14 "gap: var(--space-12)" |
```

  The design checks read the cell without that pointer. A `path:line` that does not resolve is refused as in any row. The row's quote is read only to count the row as observed: a quote that is not on the line, or too short, is not refused, it counts for nothing, and when the table then has no observed row the refusal lists it.
