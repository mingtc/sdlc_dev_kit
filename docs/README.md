<!-- KIT-CLASS: KIT — the directory's purpose. Travels unedited; every file you put here is yours. -->
# `docs/` — reference material this project did not write

**This directory is for non-development and external material**: a third-party service's API guide,
a vendor's integration notes, a specification somebody else owns, a stakeholder-facing artifact, a
diagram you were handed. Things you **read** while building, and things you **hand outward** — not
the working records of building itself.

**Working records live in [`dev/`](../dev/README.md), and the split is deliberate.** A plan, an
engineering design spec, a refactor pass, a design pass, a run report — those are *how this project
got here*, they are dated snapshots, and they are governed by `dev/`'s bidirectional index. Putting
them here instead would mix two things with opposite reading rules: `dev/` is read to learn how
something came about and is **never** maintained, while a vendor's API guide is read to learn what
is true right now and is replaced wholesale when the vendor changes it.

**The one test, when you are unsure:** *did this project's own work produce it?* If yes it is
`dev/`'s, whatever it looks like. If it arrived from outside, or exists to leave the project, it is
this directory's.

## What this directory owes

- **Nothing is indexed here.** Unlike `dev/`, this directory has no index discipline, because its
  members are not a corpus of reasoning — they are reference. Organise it however the material
  wants; subdirectories are fine and need no registration.
- **Say where a file came from.** External material acquires a provenance line — the source, and
  the date it was fetched — at the top of the file or in a sibling note. A vendor document with no
  date is indistinguishable from a current one, and it will be read as current.
- **It is metadata, not code.** Files here commit direct to the trunk under the metadata rule
  ([`../process/MANUAL.md`](../process/MANUAL.md) § The code-vs-metadata rule) unless your adapter's
  code globs say otherwise.

*This directory ships holding only this README. It is yours to fill, and it is not a placeholder for
something the kit will supply later.*
