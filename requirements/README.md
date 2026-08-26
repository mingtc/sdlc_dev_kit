<!-- KIT-CLASS: KIT — the requirements directory's index. Grows one row per PRD; the two registers are fixed. -->
# `requirements/` — the requirements corpus

**One line for each of the two formats this directory holds.**

| File | What it is |
|---|---|
| [CORPUS.md](CORPUS.md) | **The manifest** — what this project's requirements corpus *is*: which paths are corpus, how every root document and top-level directory is classified, and which member wins when two disagree. A *shape*, filled once and amended as the tree grows. |
| [DECISIONS.md](DECISIONS.md) | **The register** — every standing ruling as its **current** ruling + one line of why + provenance, under a stable `D-NN` id that is retired rather than reused. A *projection of what is true now*, never a history. |

Both exist from day one, both nearly empty. They answer different questions: *"what may I read to
rebuild this?"* (CORPUS) and *"what is currently true?"* (DECISIONS).

## PRDs live here too

Product requirement documents are `PRD-NNN-<slug>.md` in this directory, minted by the PM via
`./scripts/new-prd.sh` from `.claude/templates/PRD.template.md`. `CORPUS.md` may admit them with a
single **location** row — but a location row makes no individual PRD reachable by name, so once the
set is large enough that a reader hunts for one, add a `## The PRDs` table below with one row per
PRD (id · status · what it covers) and keep it here rather than in the manifest.

<!-- The status column of such a table is a DATED READING of each PRD's own frontmatter `status:`
     field, not a derived projection — say so in the table's preamble, or the next reader will
     trust it over the file. -->

**A PRD is never renamed.** Guards and citations key on the `PRD-NNN` in the filename.

**A PRD overtaken in part is annotated in the same change** — `superseded_in_part: [<issue-id> →
<section>]` in the PRD's frontmatter, landing with the ruling that caused it, never in a later
sweep. It is orthogonal to `status`: *superseded in part* is not `status: superseded`. The law is
[`process/doctrine/supersession.md`](../process/doctrine/supersession.md) § A.2.
