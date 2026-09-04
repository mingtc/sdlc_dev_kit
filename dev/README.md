<!-- KIT-CLASS: KIT — the working-records index. The discipline travels; every row below is yours. -->
# `dev/` — the working-records index

Working notes, assessments, probe reports, spikes, and **handoffs** produced during this project's
development.

**No file in `dev/` is a living plan.** The plan-of-record is the **current handoff** — the newest
file in [`handoffs/`](handoffs/) — **plus the board (`progress/`)**. Everything else here is a
**dated snapshot**: accurate as of its date, kept as background, **not maintained**. That is the
whole reason this directory can hold hundreds of files without any of them lying: a snapshot with a
date in its name makes no claim about today.

This directory's bucket in [`requirements/CORPUS.md`](../requirements/CORPUS.md) is `ledger` — read
it to learn *how* something got here, **never** to learn *what is true now*. What is true now lives
in `requirements/DECISIONS.md`, the capability documents your adapter names, and the board.

## The index discipline — and it is bidirectional

**Every file and subdirectory under `dev/` is reachable from exactly one row in one of the tables
below, added in the same change that creates it.** For a loose file that row is the file's; **for a
split-out directory it is the directory's**, and that directory's own README indexes its members —
see the split-out rule below, which is an **exception to the granularity, never to the discipline**.
The rule runs both ways, and a rule enforced in only one direction rots in the other:

*(This sentence used to read "gets exactly one row" — per file, with no exception named — while the
split-out rule four paragraphs down said the opposite for anything that outgrows a row. Both read as
binding, and **the more specific one was the one nobody applied**: a directory README ordered
per-file rows into a section that has no table. Superseded on granularity only; the bidirectional
argument below is untouched and is the reason either way.)*

1. **Nothing exists here unindexed.** An unindexed file is reachable only by accident of
   cross-citation — and the ones nothing happens to cite are reachable from nowhere at all. A
   directory admitted to the corpus as a single *location* row makes this index the only thing that
   makes its members individually findable.
2. **Nothing is indexed that does not exist.** A row pointing at a deleted or renamed file is worse
   than no row: it reads as a promise. When a file moves, its row moves in the same change.

**Keep rows SHORT — one to three lines.** An index whose entries grow without limit stops being an
index; the reader who came to find one file now has to read a report. When one entry genuinely needs
more than a few lines (a directory with many members, a long-running arc), **split it out into its
own `dev/<dir>/README.md` and leave a one-line row here pointing at it.** **That row REPLACES
per-file rows for its members — the split-out directory's README is their index, and this is the
exception the opening sentence names.** *A split-out directory owes its members an index of its own;
where their filenames already carry one (a dated convention that `ls` sorts), that is it, and a table
restating it would be a second copy.* *(Measured lesson from the
donor project this kit was cut from: its `dev/README.md` grew until most rows were over any
defensible size cap and one single row was several thousand bytes — the index had become the thing
it was supposed to make unnecessary to read.)*

**Dated filenames, `YYYY-MM-DD-<slug>.md`.** The date is part of the claim. A file whose name has no
date will be read as current no matter what its first paragraph says.

## Standing queues — the one living list here

- **[`downtime-queue.md`](downtime-queue.md)** — deferred-but-genuine improvements: things
  deliberately **not** done now, kept as a table rather than lost to audit footnotes. Re-assessed at
  downtime; anything picked up goes through the normal mint → Dev → QA path, and **nothing in it may
  ride along with other work.**

<!-- Add further standing queues here only if they are genuinely LIVING (maintained, not dated).
     Everything else belongs in the snapshot tables below. -->

## Handoffs (`handoffs/`)

- **[`handoffs/`](handoffs/)** — seat-to-seat handoffs. **The newest file wins**; the convention and
  the standing-handoff pattern are in [`handoffs/README.md`](handoffs/README.md).

## Orchestrated runs (`launch/`)

- **[`launch/`](launch/)** — one **launch pack** per orchestrated run and, at close, the **run
  report** the pack is stamped SPENT against. Neither is ever deleted; the convention is in
  [`launch/README.md`](launch/README.md).

## The role outputs (`specs/`, `plans/`, `refactor/`, `design/`, `runs/`)

The directories the process writes into **by name**, so that a role doc saying *"output goes to
`dev/plans/…`"* names somewhere that exists. They ship empty; their members are dated snapshots under
this file's rules — written once, not maintained, read to learn how something came about.

<!-- One row each, per the split-out rule above: a row is split into its own README only when it
     needs more than a few lines, and these do not. The filename column IS the convention; the role
     docs and skills that write these paths SHOULD cite this table rather than restating it.
     (Aspirational, and stated as such: no role doc, skill or template currently cites this file —
     `grep -rn dev/README` finds only the root README, PROJECT.md, docs/README.md and the
     instruments. Do not read this line as a description of the tree.) -->

| Directory | Written by | Members |
|---|---|---|
| [`specs/`](specs/) | Dev, from the brainstorming skill | `YYYY-MM-DD-<topic>-design.md` — the engineering design spec for one piece of work |
| [`plans/`](plans/) | Dev, from the writing-plans skill | `YYYY-MM-DD-<PREFIX>-NNN-<slug>.md` — the TDD-shaped task list a work item was executed from |
| [`refactor/`](refactor/) | Refactorer | `YYYY-MM-DD-<scope>-pass.md` — a refactor pass and its targets, cited by the cards it mints |
| [`design/`](design/) | whoever holds the design hat | `YYYY-MM-DD-<slug>-pass.md` — a design pass |
| [`runs/`](runs/) | the Orchestrator | `YYYY-MM-DD-<run-slug>.md` — the long-form run record that `progress.md`'s short pointers point at |

**Why they are here and not under `docs/`:** these are *this project's own working records*, and
[`../docs/README.md`](../docs/README.md) is for material the project did not write — a vendor's API
guide, a spec somebody else owns, an artifact produced to leave the project. The two have opposite
reading rules, which is the whole reason the split is worth a directory.

## Reports, assessments, and probe findings

<!-- One row per dated document. `Read for` is what a reader would come here WANTING — not a
     summary of the contents; a summary here is a second copy that will disagree with the file. -->

| Document | Date | Read for |
|---|---|---|
| `<YYYY-MM-DD-<slug>.md>` | `<YYYY-MM-DD>` | `<the one question this document answers>` |

## Spikes and captures (subdirectories)

<!-- A spike directory gets ONE row here and its own README.md inside if it has more than a couple
     of members. Captures — raw responses, fixtures, transcripts recorded from a real system — stay
     with their spike, never loose at this level.
     A PROBE THAT IS NOT PART OF A SPIKE still has a home, and this is it: its finding note is a
     row in § Reports, assessments, and probe findings, and its captures go in a dated directory
     beside that note, indexed by its own row. The rule above is "never loose at this level", not
     "only spikes may capture" — a one-off probe that produced raw evidence had nowhere to put it,
     which is how a capture ends up either loose or deleted. -->

| Directory | Date | Read for |
|---|---|---|
| `<slug>/` | `<YYYY-MM-DD>` | `<what was probed, and what the answer was>` |

## Dogfooding rounds (`rounds/`)

<!-- One subdirectory per round: `rounds/<YYYY-MM-DD>-<name>/` holding `pack.md` (the
     pre-registration), `report.md` (the findings) and the round's captures. One row here per
     round, in the change that closes it.

     These are NOT ordinary snapshots: a round's transcripts and captures are the EVIDENCE its
     findings were re-verified against (process/doctrine/dogfooding.md § A.3), and a later reader
     re-checks them. They are retained under process/doctrine/retention.md — park beats delete —
     and raw measured truth uses process/templates/CAPTURE.template.md. -->

| Round | Date | Read for |
|---|---|---|
| `rounds/<YYYY-MM-DD>-<name>/` | `<YYYY-MM-DD>` | `<the round's question, and what it found>` |

## Retired

<!-- A document that is superseded is NOT deleted: it is moved here with one line saying what
     replaced it. This preserves the reason while superseding the conclusion — see
     process/doctrine/supersession.md. Delete a working record only when it contains nothing
     nobody could want, and say so in progress.md when you do. -->

| Document | Retired | Superseded by |
|---|---|---|
| `<path>` | `<YYYY-MM-DD>` | `<what to read instead>` |
