<!-- KIT-CLASS: KIT — guide for a QA verdict: the design cell of a (UI) AC row, evidence kind `design`. See process/EXTRACTION.md. -->
# QA verdict: the design cell

Each AC tagged `(UI)` gets one verdict row whose evidence kind is `design` (the module registers it; it is pointer-only).
The pointer is one cell, holding one entry per pinned state (a further cell is read by nothing):

```
| AC3 | PASS | design | UX-001#<state>@<pin>: identical; dev/evidence/<PREFIX>-NNN/UX-001-<state>-pin.png, dev/evidence/<PREFIX>-NNN/UX-001-<state>-build.png |
| AC4 | FAIL_AC | design | UX-002#<state>@<pin>: diffs: ux-002-title, ux-002-cta; dev/evidence/<PREFIX>-NNN/UX-002-<state>-pin.png, dev/evidence/<PREFIX>-NNN/UX-002-<state>-build.png |
```

- `identical` or `diffs: <element ids>`, one per state the AC cites; it names only elements outside the card's
  `design-scope:`.
- For a pin to a canvas in wireframe mode at the pin commit (its `CANVAS.md` there has the Mode line and `requirements/DECISIONS.md` there holds the ruling it cites; the link check, run in a checkout of the pin, prints a `MODE` line for it), `identical` means the same screens, states, elements, flow and copy as the pinned wireframe; styling is not compared, and a diff in colour, type or spacing is not a `diffs:` entry.
- The pinned side is the PNG committed at the pin, taken with
  `git show <pin>:requirements/design/<canvas>/renders/<Screen>-<state>.png`, never from the working tree. A screen file is
  never rendered by hand. The build side is a screenshot of the build at the same width, from the project's own tools.
- A design row names both images (the pinned PNG, `-pin`, and the build's screenshot, `-build`), committed **on the trunk** under `dev/evidence/<PREFIX>-NNN/`, each a PNG, the build image not the pin image. [`dev/evidence/README.md`](../../../dev/evidence/README.md) says who commits them and who compares them: QA cites the images by sha and records the comparison's result. A row with no image is not a PASS: if the
  committed PNG is missing or unusable, say so on the row and do not pass it.
- Write the pointer so no `word:number` appears other than a real `path:line`: the gate reads every one as a path.
- The design row is not an observed row on its own: the landing needs one `test` or `file:line` row, or a row that ends with a pointer
  the gate re-reads. A card or slice whose only AC is `(UI)` has one row, so end its `design` cell with `; <path>:<line> "<quote>"`,
  the code that shows the AC met and a verbatim quote of it, eight characters or more, found on that line:

```
| AC1 | PASS | design | UX-001#<state>@<pin>: identical; dev/evidence/<PREFIX>-NNN/UX-001-<state>-pin.png, dev/evidence/<PREFIX>-NNN/UX-001-<state>-build.png; src/list.css:14 "gap: var(--space-12)" |
```

  The design checks read the cell without that pointer. A `path:line` that does not resolve is refused as in any row.
