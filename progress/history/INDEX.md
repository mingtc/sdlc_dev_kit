<!-- KIT-CLASS: MIXED — the shape and the insertion-point convention are the kit's; every row is your project's. See process/EXTRACTION.md. -->
# `progress/history/` — the rotation index

Every chunk `../../scripts/archive-progress.sh` writes gets **one row below**, and the rows are the
only thing that makes a rotated chunk findable. Without them this directory is a folder, and **a
folder is where records go to become unfindable** — which is why the index is a hard invariant of
[`../../process/contracts/archive-sweep.md`](../../process/contracts/archive-sweep.md) § 2 and not a
courtesy.

**Read this file, never `ls`.** A directory listing gives you filenames and no spans, so finding
which chunk holds a given date means opening them until one matches. The `Covers` column is the
whole point: it is the **hook** that tells you whether to open a chunk without opening it
([`../../process/doctrine/lookup-tables.md`](../../process/doctrine/lookup-tables.md) § A.3).

**This file exists from day one, and on day one it is correctly empty.** *"No rotations yet"* is a
real answer; an absent index is not — where chunks already exist the tool REFUSES rather than
writing a zero-row index that would read as "nothing was ever archived". (With no chunks it creates
an empty one and says so, because then the empty index is simply true — `archive-sweep.md` § 3.)

**A rotated chunk inherits the index trigger.** If a chunk itself grows past the threshold in
[`../../process/doctrine/lookup-tables.md`](../../process/doctrine/lookup-tables.md) § A.1, it owes
its **own** index and this row becomes a pointer to that child — *"an index is not a diet"* (§ A.6),
and rotating without indexing has exported the problem rather than solved it.

<!-- INSERTION POINT — FORMAT LAW. New rows are appended DIRECTLY BELOW the header row of the table
     that follows, NEWEST FIRST, and no existing row is ever rewritten. `archive-progress.sh` finds
     this table by its header row and refuses if it cannot; do not reformat the header, retitle the
     columns, or wrap the table in anything.

     Columns, and why each is there:
       Chunk       the file, as a relative link — the identifier.
       Covers      the span of entry dates INSIDE it. THE LOAD-BEARING COLUMN: it is what lets a
                   reader pick the right chunk without opening any of them.
       Entries     how many entry boundaries were moved. Lets a reader check a chunk is whole.
       Rotated     the date the rotation landed — the retirement date § 2 requires.
       Cut         the selector that produced it (`--keep-last N` or `--before <date>`), so a
                   later reader can tell a size-driven rotation from a milestone-driven one. -->

| Chunk | Covers | Entries | Rotated | Cut |
|---|---|---|---|---|

<!-- `<none yet>` is the day-one state: the table above has its header and no rows. Delete this
     comment once the first row lands. -->
