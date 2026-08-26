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
- **[`doctrine/live-resources.md`](doctrine/live-resources.md) § A.6 is stronger:** reclaim by
  **enumerating the container**, never by replaying a registry of what was created — an enumeration
  cannot miss what the creating leg forgot to register, and a registry always can. Two corollaries
  come with it: anything created outside the enumerated container is invisible to the sweep and
  handled by name, and anything you cannot delete is **named, not quietly left**. Sharpened from a
  dogfooding round, where the creating party is a participant rather than the harness.
- **[`doctrine/calibration.md`](doctrine/calibration.md) and
  [`doctrine/negative-claims.md`](doctrine/negative-claims.md)** gained the cross-references that
  place the two new sheets in the family: calibration names the round as its third ritual and says
  what each of the three does *not* answer; negative-claims names instruments as its upstream
  neighbour — that sheet asks whether a claim is grounded, this one whether the check behind it can
  see anything at all.

### Added

- **New doctrine sheet — [`doctrine/subagent-control.md`](doctrine/subagent-control.md).**
  Commissioning work you cannot watch, and believing the result: the adversarial brief, the
  contradictory-demand pair that returns nothing rather than a compromise, a report that carries its
  own evidence, resume-safety, deferred decisions named inside the item that touches them, and
  handing off while sharp. Increments land in
  [`doctrine/model-provisioning.md`](doctrine/model-provisioning.md) (an unset provisioning knob is
  an *inheritance*, not a default), [`doctrine/live-resources.md`](doctrine/live-resources.md) § A.5
  (the two shapes a self-report fails in), [`../dev/handoffs/README.md`](../dev/handoffs/README.md)
  (when to write one) and
  [`templates/launch-pack.template.md`](templates/launch-pack.template.md) (an ordering clause names
  its consequence, not just its sequence).
- **Dogfooding doctrine — a third measurement ritual.** [`doctrine/dogfooding.md`](doctrine/dogfooding.md)
  covers running a **round**: putting agents or people in front of what you shipped, as consumers,
  and grading what happens. It asks *does a competent stranger, holding only what ships, get where
  they were going?* — a question no gate can answer, and whose findings are mostly about **words**
  (documentation, error text, naming, defaults). It ships with its own document pair,
  [`templates/round-pack.template.md`](templates/round-pack.template.md) (a **pre-registration**:
  the question, the scenario matrix, the instruments and their blind spots, the budget — all
  committed *before* the round runs, because a budget written afterwards cannot fail and so is not
  a limit) and [`templates/round-report.template.md`](templates/round-report.template.md) (findings,
  positives, and the round's own defects).
  **A run delivers work; a round measures how the delivered thing is met** — keep the two words
  apart. The round is staffed from the existing cast: PM owns the question and every remedy, the
  Orchestrator delivers and dispatches in isolation, QA re-verifies and grades cold, and a second
  leg attacks the consolidation. **No new role, no new prefix, no gate.**
- **Instrument doctrine.** [`doctrine/instruments.md`](doctrine/instruments.md) — *an instrument is
  believed only when it has been watched failing.* Measure it against the shape it will actually
  meet rather than the fixture its author wrote; **every green owes an ablation**, because absence
  of the wrong thing never establishes presence of the right one; sometimes a capability probe is
  itself the defect (it turns a deleted check into a SKIP instead of a FAIL) and that choice is
  recorded; and every instrument's blind spot is named **in its own output**. This one binds every
  guard author, not only whoever runs a round — its § C worked example is the kit's own self-test
  harness, including three places the kit was breaking its own new rule.
- **[`MANUAL.md` § The measurement rituals](MANUAL.md)** now names all three — regeneration spike,
  seed acceptance test, dogfooding round — as one family: **available, never obligations**, reached
  for on a condition rather than a schedule, all producing findings rather than code, and all
  handing those findings to a real PM session rather than minting work items themselves.
- **`kit-init.sh` refuses a relative filesystem remote URL**, printing the one-line fix. The kanban
  worktree runs git from `.kanban-wt/`, one directory down, where a relative `origin` resolves
  somewhere else — previously that surfaced two steps later, mid-self-check, disguised as an
  access-rights error.
- **New doctrine sheet — `process/doctrine/fix-execution.md`.** The phase between *"we have
  findings"* and *"we cut a release"*, which the kit modelled at neither end: scrutinize the slate
  before implementing it (one fresh-context reviewer per item, four questions, **read-only**, and
  holding an item is a success); record a ruling **before** executing it, verbatim, with what was
  explicitly *not* ruled beside what was; carry the round's own traps as **acceptance criteria**
  rather than advice; sort candidate fixes by *"is there a decision here"*, never by size; budget a
  gate on a **property** (CPU time, work units, counts) and never on wall-clock; treat every claim
  about remote state as a **dated reading**; and give every vocabulary the process uses about itself
  **one authoring site** with everything else derived from it. Increments land in
  `process/templates/DECISIONS.skeleton.md` (a ruling about to be executed owes three more things
  *inside* its existing three fields, plus a tree stamp on its citations), `doctrine/staleness.md`
  (§ C — finding the statement you just outran is a one-hop search, owed in the same change) and
  `doctrine/live-resources.md` § A.4 (a consent id authorizes one item's spend, so a full-suite run
  is its own budgeted decision). **Nothing to do to adopt it:** no command, flag or file changed,
  and the template additions are guidance inside templates you already own.
- **[`MANUAL.md` § The fix-execution phase](MANUAL.md)** carries the two steps the lifecycle did not
  otherwise have — scrutiny before implementation, and the pre-cut sweep before the cut — marked
  **mandatory when the slate came from a round**, which is why its heading states its own obligation
  status rather than sitting silently beside the optional rituals above it.

### Fixed

- `EXTRACTION.md` § 1.1 listed a `githooks/pre-commit` the kit does not ship and omitted
  `githooks/commit-msg`, which it does — in a section whose own rule is that counting its list is
  the census.
- `.claude/skills/README.md` no longer states skill counts as digits; the directory listing is the
  count, per the kit's own *derive, date, or do not state* rule.

### Action required

- **The pause law's "never end a turn on a stated intention" is now an ORDERING, not a prohibition**
  ([`doctrine/orchestration.md`](doctrine/orchestration.md) § A.5). Reorder your coordinators' belt
  from belt → status → dispatch to **belt → dispatch → status**, so a turn ends on a tool call by
  construction rather than by remembering to. The original wording and its reason are preserved above
  the amendment; nothing you have written becomes wrong, but **a coordinator that follows only the
  prohibition will keep paying the failure it names** — it asks the actor to notice at exactly the
  moment the failure describes.

Otherwise none. Every other change above is either a new refusal that fires only on a setup that was
already broken, a correction to the seed's own files, or new material that binds nothing until you
reach for it. **A project that never holds a dogfooding round pays nothing for the two new sheets** —
they are one more file each in directories you already carry.

Worth reading anyway if you maintain guards: `doctrine/instruments.md` § A.2 (*every green owes an
ablation*) is the rule the kit itself was breaking in three places, and the same shape is easy to
have shipped in your own drift checks.

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
