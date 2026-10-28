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

Run `ls $(ls -d progress/*/ | grep -v -e /done/ -e /history/)`
to see the board (all but the long `done/` and `history/`). `declined/` is terminal — a card considered and refused, kept for the reason it carries. Each filename is `<PREFIX>-NNN-<slug>.md`; the folder is the
status. `./scripts/check-board.sh` reports board drift. Older entries rotate into
`progress/history/` via `./scripts/archive-progress.sh`.

## How to write an entry

Two shapes below are REQUIRED, not stylistic — a script reads each one:

- the `## Log` heading itself: the drift report probes for it
  (`## Log` alone, or followed by a space and more text — `## Log:` and `## Logistics` do not count) before it can report this section's size;
- a dated `###` boundary per session: the log rotation splits this file on
  `### YYYY-MM-DD` when it rotates, so each session's entries sit under ONE
  heading. **`###`, not `##`, and that is load-bearing rather than stylistic.** The tools that read
  the `## Log` *section* scan from its heading to the **next `##`** — the drift report's `[c]` log
  arm and its `[n]` kit-feedback-line arm, and the initializer's already-lived probe. An entry
  written as `## YYYY-MM-DD` therefore *terminates the section it is supposed to be inside*: the
  size arm measures only the preamble and reports healthy forever, and the lived probe counts zero
  log lines, so a repository with a full history reads as new.

One more line is read, as a warning only, when `PROJECT.md`'s `kit-feedback:` is `auto` (the
default): the drift report's `[n]` kit-feedback-line arm looks in the newest entry for a closing
`kit-feedback: none` or `kit-feedback: K-NN[, K-NN…]` line (a dispatched leg's `kit-finding:` line
answers it too; `process/MANUAL.md` § Kit feedback) and warns when it is absent.

```markdown
### YYYY-MM-DD [Role] <session title>

- what was decided, deviated from, skipped, or handed off.
```

The convention is **forward-only**: history is never rewritten. A later session
that corrects an earlier one says so in its own entry rather than editing the old
one.

Everything below the next heading is history; nothing above it is.

## Log
