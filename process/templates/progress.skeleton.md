<!-- KIT-CLASS: KIT — a blank shape. Travels unedited; two of its headings are read by scripts. -->
<!--
  HOW TO USE THIS FILE
  The kit ships its own progress.md at the repository root, and `kit-init.sh` writes this shape
  only where that file is absent (process/contracts/initializer.md). This copy is for a project
  that reimplements the initializer in its own toolchain: it must produce this shape.
  TWO SHAPES BELOW ARE REQUIRED, NOT STYLISTIC — a script reads each one; see "How to write an
  entry". Fill the <angle-bracket> blanks; keep everything else byte-for-byte.
  DROP THE KIT-CLASS MARKER above from your copy.
-->

<!-- LINKS IN THIS FILE ARE RELATIVE TO WHERE IT LANDS — ./ — NOT to the directory it
     sits in. A link written for where the template SITS resolves while you read it here and
     is dead in every copy an adopter makes: it passes a link check run in the kit and fails
     the only reader who matters. The self-test reads this line to know where to resolve from,
     so keep its shape. -->
# progress.md

The running log of activity in this project. All roles append entries here. The
kanban folders under `progress/` are the source of truth for *current* status —
this file is the *history*.

## Status quick reference

Run `ls progress/todo/ progress/in_progress/ progress/dev_complete/ progress/qa_complete/ progress/blocked/ progress/declined/`
to see the board. `declined/` is terminal — a card considered and refused, kept for the reason it carries. Each filename is `<PREFIX>-NNN-<slug>.md`; the folder is the status.
`<your drift-report command>` reports board drift. Older entries rotate into
`progress/history/` via `<your log-rotation command>`.

## How to write an entry

Two shapes below are REQUIRED, not stylistic — a script reads each one:

- the `## Log` heading itself: the drift report probes for it
  (`## Log`, or `## Log` and more text, never `## Logistics`) before it can report this section's size;
- a dated `###` boundary per session: the log rotation splits this file on
  `### YYYY-MM-DD` when it rotates, so each session's entries sit under ONE heading.
  **`###`, not `##`, and that is load-bearing rather than stylistic.** Two tools read the
  `## Log` *section* by scanning from its heading to the **next `##`** — the drift report's
  § Log size arm and the initializer's already-lived probe. An entry written as
  `## YYYY-MM-DD` therefore *terminates the section it is supposed to be inside*: the size arm
  measures only the preamble and reports healthy forever, and the lived probe counts zero log
  lines, so a repository with a full history reads as new.

```markdown
### YYYY-MM-DD [Role] <session title>

- what was decided, deviated from, skipped, or handed off.
```

Everything below the next heading is history; nothing above it is.

<!--
  ONE FORWARD-LOOKING NOTE, and it is cheap now and expensive later: this file grows without
  bound, and a citation into it of the form `progress.md:1234` DIES at the first rotation —
  silently, all at once, with nothing failing. Cite a session's dated `###` heading, never a line
  number. Doctrine: process/doctrine/lookup-tables.md § A.4 (stable addresses) and § A.6 (an index
  is not a diet). When this file crosses the drift report's size threshold, the rotation is due —
  and the file rotation creates inherits the same obligation.
-->

## Log
