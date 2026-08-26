<!-- KIT-CLASS: KIT — the archive index's shape. The `## Archived` heading is read by scripts. -->
# ARCHIVE.md

One-line summaries of issues that have been swept off the active board out of
`progress/qa_complete/`. Use this as the condensed, searchable index when
answering "did we ever build X?".

**The full file bodies live in `progress/done/`** — one file per issue, preserved
on the board's archive shelf (they are moved, never deleted). This file is only
the one-line index. To read a completed issue in full:

```bash
cat progress/done/<PREFIX>-NNN-<slug>.md
```

## When to archive

When `progress/qa_complete/` has grown enough to clutter the active board (the
`check-board.sh` threshold, or after a milestone), run:

```bash
./scripts/archive.sh           # dry run — shows what would be swept
./scripts/archive.sh --apply   # index here + git mv the files into progress/done/
```

`archive.sh` prepends one-line entries below the `## Archived` heading and moves
the full files into `progress/done/`. Review the staged diff, then commit.

The contract this implements is
[`process/contracts/archive-sweep.md`](process/contracts/archive-sweep.md); the
threshold itself is a value **your adapter sets** — see
[`CLAUDE.md`](CLAUDE.md) § "What is ON and what is OFF here".

**The heading below is format law and exists from day one, empty.** The sweep
inserts directly beneath it, and the initializer's already-lived refusal counts
the lines under it — an empty section is what says "this board has not lived yet".

## Archived
