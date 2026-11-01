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
- The pinned side is the PNG committed at the pin, read with
  `git show <pin>:requirements/design/<canvas>/renders/<Screen>-<state>.png`, never from the working tree. A screen file is
  never rendered by hand. The build side is a screenshot of the build at the same width, from the project's own tools.
- A design row names both images (the pinned PNG, `-pin`, and the build's screenshot, `-build`), committed **on the trunk** under `dev/evidence/<PREFIX>-NNN/` (`./scripts/register-commit.sh --role QA`), each a PNG, the build image not the pin image. A row with no image is not a PASS: if the
  committed PNG is missing or unusable, say so on the row and do not pass it.
- Write the pointer so no `word:number` appears other than a real `path:line`: the gate reads every one as a path.
