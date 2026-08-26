<!-- KIT-CLASS: KIT — the kit's OWN release notes, written for the project that adopted it.
     It travels unedited and is never a project's own release notes: yours are whatever
     scripts/release.sh's RELEASE_DOCS seam declares. -->
# The process kit — release notes

**What changed in the KIT, release by release, and what an adopted project must do about it.**
This file describes the development-process kit you are running — not your product. Your own
release notes are whatever your `scripts/release.sh` declares in its `RELEASE_DOCS` seam.

- **Which version am I on?** [`KIT-VERSION`](KIT-VERSION), one line, beside this file.
- **The full engineering log** — every change with its reasoning, and the change file behind it —
  lives in the kit's own repository, not in this copy. A copy of it here would go stale the day
  you started editing your kit, and it links to files that exist only in that repository.

## How versions work

| Bump | Means |
|---|---|
| **MAJOR** | A project already running on the kit has to change how it works: a role renamed, a status folder added or removed, a contract's invariant changed. Every such change is listed under **Action required**. |
| **MINOR** | New material or changed guidance you can adopt when you like. Nothing breaks if you ignore it. |
| **PATCH** | Corrections: wrong paths, broken links, wording, a refusal that should have fired and did not. |

## How to upgrade an adopted project

**There is no updater, and that is deliberate.** The kit is *copied* into your repository on day
one and becomes yours — your adapter, your role set, your gates. An automated overwrite would
discard exactly the local hardening the kit tells you to do. So an upgrade is a read, not a run:

1. Read every version entry below that is newer than your [`KIT-VERSION`](KIT-VERSION).
2. Apply the **Action required** items — those are the only ones that can break you.
3. Adopt whatever else you want from **Changed** / **Added**, file by file, the same way you would
   any other change: through your own board, with your own gates.
4. Update your `KIT-VERSION` to the version you have reached, so the next reader knows where you
   are.

Diffing your kit against a newer release is a legitimate way to do step 3 — but expect the diff to
include your own local law, which is not drift.

## Known gaps

The kit ships an honest debt list rather than a clean claim: [`EXTRACTION.md` § 4](EXTRACTION.md)
names what is still entangled, what it costs you, and how to check each one in your own copy. The
kit's repository additionally carries the open, not-yet-fixed findings under `changes/open/`.

---

## [Unreleased]

### Changed

- **`kit-init.sh --gate-command` now FILLS the shipped gate runner's empty table** instead of
  refusing because `scripts/verify.sh` already exists. The seed ships `verify.sh` as a frame whose
  `GATES` table is empty and which refuses to run until you declare a gate — so the day-one command
  in the README refused on every fresh copy, while the frame's own header told you to run the flag
  that refused. Now: no `verify.sh` at all ⇒ a minimal single-gate runner is written; the shipped
  empty frame ⇒ your command is written into its table as the first record (`"gate|core|<cmd>"`);
  a table that already declares a gate, or a runner that is not the frame ⇒ refusal, because that
  file is yours. A gate command containing `|` or `"` is refused: the record format cannot carry
  either — put it in a script and name the script.
- **The kit's own version and release notes moved out of the repository root** into
  [`KIT-VERSION`](KIT-VERSION) and this file. A root `VERSION` file describing the *kit* is a trap
  in a project that has its own product version — `release.sh`'s `VERSION_FILES` seam would
  happily bump it.

### Added

- **`kit-init.sh` refuses a relative filesystem remote URL**, printing the one-line fix. The kanban
  worktree runs git from `.kanban-wt/`, one directory down, where a relative `origin` resolves
  somewhere else — previously that surfaced two steps later, mid-self-check, disguised as an
  access-rights error.

### Fixed

- `EXTRACTION.md` § 1.1 listed a `githooks/pre-commit` the kit does not ship and omitted
  `githooks/commit-msg`, which it does — in a section whose own rule is that counting its list is
  the census.
- `.claude/skills/README.md` no longer states skill counts as digits; the directory listing is the
  count, per the kit's own *derive, date, or do not state* rule.

### Action required

None. Every change above is either a new refusal that fires only on a setup that was already
broken, or a correction to the seed's own files.

---

## [0.1.0] — 2026-08-26

The first versioned cut. The kit at this version is what a fresh adoption gets:

- **The process** — [`MANUAL.md`](MANUAL.md): a filesystem-as-kanban board, roles as hats, the
  Dev → QA boundary and its seven steps, branching and role attribution, the session rituals.
- **Two front doors** — [`SEED.md`](SEED.md) (you have nothing) and [`EXTRACTION.md`](EXTRACTION.md)
  (the manifest, with its debt list in § 4).
- **The contracts** — [`contracts/`](contracts/), one sheet per gate stating what any
  implementation must guarantee, when it must refuse, and what green means in countable terms.
  **This is the route for an adopter who takes none of the shell scripts.**
- **The doctrine** — [`doctrine/`](doctrine/), the reasoning behind the standing rules.
- **The harness** — `.claude/`: role docs, leaf-agent definitions with model/effort pins, the skill
  set, two multi-issue runners, the item templates, and an opt-in settings example.
- **The executable kit** — `scripts/`: the initializer, the board mover, id minting, the drift
  report, the landing gate, the archive sweeps, the gate-runner frame, the release ritual,
  notifications (off until configured), the hygiene instruments, and a self-test harness.
- **The board and the registers** — `progress/`, `progress.md`, `ARCHIVE.md`, `requirements/`,
  `dev/`, and the optional `consumers/` distribution machinery.

### Action required

Nothing — this is the first release. Start at [`../README.md`](../README.md) § Day one.
