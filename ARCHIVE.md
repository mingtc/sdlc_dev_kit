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
the full files into `progress/done/`. **It commits and pushes on `--apply`** — there is no staged
diff left for you to review, so review the run's output and the resulting commit instead. Use
`--dry-run` (the default) first if you want to see what it would do.

The contract this implements is
[`process/contracts/archive-sweep.md`](process/contracts/archive-sweep.md). The depth
that triggers the advisory is a **constant declared at the top of
`scripts/check-board.sh`** — not a value your adapter sets. No script reads a threshold
from the adapter, so a number written there changes nothing; change it at the constant
or not at all. What the adapter DOES record is whether this sweep is run here at all —
[`AGENTS.md`](AGENTS.md) § "What is ON and what is OFF here".

**The heading below is format law and exists from day one, empty.** The sweep
inserts directly beneath it, and the initializer's already-lived refusal counts
the lines under it — an empty section is what says "this board has not lived yet".

## Archived
