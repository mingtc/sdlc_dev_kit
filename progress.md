<!-- KIT-CLASS: KIT — the running log's shape. Two of its headings are read by scripts. -->
# progress.md

The running log of activity in this project. All roles append entries here. The
kanban folders under `progress/` are the source of truth for *current* status —
this file is the *history*.

## What goes here

- **PM** appends strategic decisions only (chose option X over Y, killed an idea,
  reordered the roadmap). Routine issue creation does **not** belong here — it
  already shows up in `progress/todo/`.
- **Dev** appends per-session work entries: decisions made, deviations from the
  plan, tests skipped or marked expected-failure with reasons, anything QA needs
  to know.
- **QA** appends one line per review:
  `YYYY-MM-DD [QA] review of <PREFIX>-NNN: PASS/FAIL — <reason or bug ids>`.
- **Orchestrator** appends coordination notes when driving an issue Dev → QA.

A ruling that changes how the project behaves does **not** live only here: it goes
into [`requirements/DECISIONS.md`](requirements/DECISIONS.md) in the same change.
This file answers *what happened*; that register answers *what is true now*.

## Status quick reference

Run `ls progress/todo/ progress/in_progress/ progress/dev_complete/ progress/qa_complete/ progress/blocked/ progress/declined/`
to see the board. `declined/` is terminal — a card considered and refused, kept for the reason it carries. Each filename is `<PREFIX>-NNN-<slug>.md`; the folder is the
status. `./scripts/check-board.sh` reports board drift. Older entries rotate into
`progress/history/` via `./scripts/archive-progress.sh`.

## How to write an entry

Two shapes below are REQUIRED, not stylistic — a script reads each one:

- the `## Log` heading itself: the drift report probes for it
  (`## Log` alone, or followed by a space and more text — `## Log:` and `## Logistics` do not count) before it can report this section's size;
- a dated `###` boundary per session: the log rotation splits this file on
  `### YYYY-MM-DD` when it rotates, so each session's entries sit under ONE
  heading.

```markdown
### YYYY-MM-DD [Role] <session title>

- what was decided, deviated from, skipped, or handed off.
```

The convention is **forward-only**: history is never rewritten. A later session
that corrects an earlier one says so in its own entry rather than editing the old
one.

Everything below the next heading is history; nothing above it is.

## Log
