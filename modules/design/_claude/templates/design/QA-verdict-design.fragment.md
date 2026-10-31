<!-- KIT-CLASS: KIT — guide for a QA verdict: the design cell of a (UI) AC row, evidence kind `design`. See process/EXTRACTION.md. -->
# QA verdict: the design cell

Each AC tagged `(UI)` gets one verdict row whose evidence kind is `design` (the module registers it; it is pointer-only).
The pointer is one cell per pinned state:

```
| AC3 | PASS | design | UX-001#<state>@<pin>: identical; dev/evidence/<PREFIX>-NNN/UX-001-<state>.png |
| AC4 | FAIL_AC | design | UX-002#<state>@<pin>: diffs: ux-002-title, ux-002-cta; dev/evidence/<PREFIX>-NNN/UX-002-<state>.png |
```

- `identical` or `diffs: <element ids>`, one per state the AC cites; it names only elements outside the card's
  `design-scope:`.
- Render the pinned side from `git archive <pin> requirements/design`, never from the working tree; render the build at the
  same width and with the same theme; commit both images under `dev/evidence/<PREFIX>-NNN/` and name them in the pointer.
- Write the pointer so no `word:number` appears other than a real `path:line`: the gate reads every one as a path.
