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

- **`archive-progress.sh` gains an ordinal knife, an index, and a new exit code 3.** Its trigger is
  measured in **bytes** and its only selector cut in **days** — so under load the threshold is crossed
  two or three times a day while the date knife can fire once, and the second run answers *"Nothing to
  archive"* because the first already took everything before the boundary. **The tool's success was
  what made it inert.** Now: `--keep-last <N>` cuts by count and can be re-run the same day; and when
  nothing matches your selector **while a rotation is still due**, it says so, names the measurement
  against the threshold, and **exits 3** instead of reporting success. *"Nothing to archive"* is now
  reserved for when it is true — under threshold, exit 0, unchanged wording.
- **Rotation now maintains `progress/history/INDEX.md`** — one row per chunk with the span it covers,
  newest first, no row ever rewritten. This was already required (*"the same **preserve-and-index**
  rules"*), and the script's own header had recorded the deviation as a design choice: *"chunks are
  discoverable via `ls`."* They were not: `ls` gives filenames with no spans, so finding a date meant
  opening chunks until one matched.
- **`process/doctrine/fix-execution.md` § A.9 now requires supplied documents to be COPIED IN before
  anything cites them.** *A citation into a document you do not control is not a citation, it is a
  hope.* If a findings round is fed by another team's feedback file, an attachment, or a report
  pasted into a conversation, **that document is an operand** — copy it into your repository verbatim,
  date it by the day it was supplied, and never edit it (later feedback is a **new dated file**). A
  supplied document that cannot be recovered is **named as missing**, beside the ones that were,
  because a missing input nobody names reads exactly like an input nobody needed. Filed under
  § A.5b's second half: nothing breaks at mint time, every citation looks fine in review, and the gap
  surfaces only when an implementer opens a path that is not there.
- **`verify.sh` now has a FOURTH result state — UNRUNNABLE — and prints what it ran.** A gate whose
  command could not start (`127`/`126`) used to be reported as **FAIL**, which is red in the right
  direction and destroys the one distinction that matters: *"could not start"* versus *"your tree is
  broken."* The two are now separate words, and the unrunnable branch prints the interpreter path and
  the root it resolved against, so the diagnosis is where the confusion is. **The summary now carries
  counts** — declared, ran, passed, failed, could not run, skipped — and `ran` deliberately **excludes**
  the unrunnable, because a command that never executed did not run. *(That last point was caught by
  the change's own reddening control, which first printed `ran: 3` when one of three never ran.)*
- **A gate command with a relative interpreter path is no longer silently location-dependent.** It
  used to resolve against whichever root the runner stood in — so it worked in the main checkout and
  was unrunnable from a linked worktree, **which is exactly where a trunk gate has to run.** A runner
  that cannot answer from there does not have one canonical entrypoint; it has one per location.
- **`check-board.sh` now reads `<remote>/<trunk>` by name, and every verdict says what it read.**
  Previously most arms read *whatever checkout was current*, so a colleague or an agent holding the
  repository on a feature branch silently changed the board report's answer. Each arm now names its
  source (`read from: origin/main @ <sha>`), and where no trunk ref exists — day one, a local-only
  clone — it falls back to the working tree **loudly**, printing `⚠ NOT A TRUNK REPORT`. It does
  **not** fetch: it reads the remote-tracking ref as it stands, labels it with its sha, and prints
  the refresh command, because a hang at session start is worse than a dated answer.
- **A check that cannot run now says SKIPPED and why, instead of printing green.** An absent column,
  an unresolvable revision or an empty history previously fell through to a pass over zero inputs.
  **Expect to see new SKIPPED lines where you used to see ticks** — the ticks were the bug.
- **The divergence check now covers EVERY home your process publishes from, each named separately.**
  It used to watch only the board mover's auxiliary worktree, so an unpushed commit in your **main
  checkout** — which is where rulings, PRDs and board edits are written — was invisible. It now
  reports each home with its own reading, and states its span: it measures commits reachable from a
  ref, and says so, because a commit reachable from no ref at all is outside what it can see.
- **`process/doctrine/lookup-tables.md` § A.1 states the real basis for the doctrine-sheet
  exemption.** It said a doctrine sheet crossing the byte threshold triggers nothing *because
  "condition 1 is unmet"* — but condition 1 names `process/MANUAL.md`, and **MANUAL's doctrine table
  names every sheet by path, so condition 1 is met.** The exemption is correct and its stated reason
  was not: a doctrine sheet is exempt **by how it is read** — addressed on demand, never loaded at
  session start — not by failing a condition. **The policy is unchanged**; only its reasoning is,
  and the wrong reasoning was one edit away from someone removing the exemption instead of re-basing
  it.
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
  harness. *(An earlier version of this note said § C cited three places the kit was breaking its own
  new rule. It did — and all three were fixed within a phase, which is why § C now cites the
  harness's DESIGN rather than its bugs. Corrected 2026-08-27.)*
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
- **`process/doctrine/instruments.md` is now in two parts, with a visible seam.** The sheet used to
  treat every guard failure as one thing. It is two, and the difference decides the fix: **Part One
  (build time)** is *the instrument is misaimed, or cannot fail* — it binds whoever **builds** the
  instrument, and the remedy is to change the instrument. **Part Two (read time)** is *the instrument
  is right and the reading is wrong* — it binds whoever **consumes** the result, and the remedy is to
  change the reading. **Applying Part One's remedy to a Part Two failure sends you to re-aim an
  instrument that is already correct.** A ruled seam between the two says in terms that a guard author
  who stops there was right to. New in Part One: assert the fact rather than the sentence that states
  it; the operand set at four scales; building a prose guard (normalised text or an AST, never raw
  lines — then the region, then honesty about the remainder); and **§ A.8, a green that could not have
  gone red**, which now owns the two shapes of verification theatre and the rule that *a checker
  rejecting a valid input for a reason unrelated to correctness is worse than no checker, because it
  trains you to ignore it.*
- **`process/doctrine/negative-claims.md` § A.4 — a detection recipe offered inside a ruling is a
  negative claim, and owes both halves.** Run it against the tree that still holds the known
  instances and record the count; state its blind spot or say it has none. Prefer the property to the
  string. The worked instance is a ruling whose own grep returned several hits, **not one of them
  either survivor.**
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

- **Only if `progress/history/` ALREADY holds rotated chunks: create `progress/history/INDEX.md`
  before your next rotation.** The rotation will not write one for you while chunks exist, because a
  row-less index would deny them — and the date spans are inside those chunks, so only you have them.
  Create the file with the header row **and its markdown separator**, then one row per existing
  chunk — **both lines, exactly:**

  ```
  | Chunk | Covers | Entries | Rotated | Cut |
  |---|---|---|---|---|
  ```

  **The separator is not cosmetic.** The rotation inserts directly below the header and assumes the
  next line is the separator; an index built without it has its first chunk row consumed in the
  separator's place, so the new row lands *second* and your newest entry is no longer first.

  **If you have never rotated, there is nothing to do:** the file is created on first use, because an
  empty index is then simply true.
- **If you parse `verify.sh`'s output, update it for the fourth state and the count line.** Anything
  matching on exactly `PASS`/`FAIL`/`SKIP` will not recognise `UNRUNNABLE`, and a summary parser
  expecting the old shape will need the new one. **If you have been treating a red gate as "the tree
  is broken", check whether it was actually failing to start** — that is the distinction this buys.
- **Run `check-board.sh` once and read what it now reports about your MAIN checkout.** The new
  divergence reading covers the primary checkout as well as the board mover's worktree, and **if you
  have been writing rulings, PRDs or board edits directly on the trunk, it may report unpublished
  work that has been sitting there unnoticed** — that is the defect it was added to find, not a false
  positive. Push what it names. After that it goes quiet.
- **Expect new SKIPPED lines in the board report, and treat them as information rather than
  breakage.** Checks that used to print green over absent input now say SKIPPED with a reason. If a
  check you relied on now skips, its input is missing — the previous green was not evidence of
  anything.
- **The pause law's "never end a turn on a stated intention" is now an ORDERING, not a prohibition**
  ([`doctrine/orchestration.md`](doctrine/orchestration.md) § A.5). Reorder your coordinators' belt
  from belt → status → dispatch to **belt → dispatch → status**, so a turn ends on a tool call by
  construction rather than by remembering to. The original wording and its reason are preserved above
  the amendment; nothing you have written becomes wrong, but **a coordinator that follows only the
  prohibition will keep paying the failure it names** — it asks the actor to notice at exactly the
  moment the failure describes.

- **`finish-pr.sh` REFUSES a posture that used to land, and has a new exit code.** It now requires the
  gate it runs to be the **committed** one, **at the revision being landed**, and unmodified — naming
  which of five it was (missing / not executable / not at that revision / not tracked there / locally
  modified). **If you have been landing from a trunk checkout, that now refuses**: check the branch out,
  or pass `--worktree` a worktree that has it. This was already what `contracts/landing-gate.md` § 2
  required; the script did not enforce it, so a **red** branch could land green.
  **And `exit 3` is new**: it means **LANDED BUT NOT FINISHED — do not re-run**, run the printed
  recovery. Previously a failed board-advance after a successful merge exited `1`, the same code as
  *nothing landed*, so an automation reading `$?` would retry a merge that had already happened. **Any
  wrapper treating every non-zero as "did not land" must learn 3.**
- **If you copied `QA_SCHEMA` or `PARK_SCHEMA` into your own runner, the field shape changed.**
  `landed: boolean` → **`landing: enum { landed, deferred, not_applicable }`**, because a boolean
  could not represent a green review whose landing was correctly deferred — it read one as a failure
  and halted a run that had succeeded. `not_applicable` exists because a docs-path issue has no
  landing script, and a boolean forces that case to lie.
- **The board mover's Activity entry format changed — update anything that parses it.** A move now
  writes `- <date> [<role>] → <target>: <note>`; the **arrow is the status declaration**. There is also
  a new **note-only** form, `- <date> [<role>] NOTE: <note>`, which deliberately emits **no** arrow and
  changes no container. If your own tooling reads those bullets, it needs the arrow — and must not read
  a `NOTE:` line as a status.
- **`check-board.sh` gains an id-register check, and it needs one declaration from you.** It reports
  duplicate ids in a declared register — the case with **no textual conflict**, where two legs mint the
  same id in different sections and a rebase merges both cleanly. Declare yours in the `REGISTERS`
  table beside `ISSUE_ID_PATTERN` (`'<path>|<heading mark>|<id shape>'`); **an undeclared register is
  skipped with its reason, so the check is silent until you declare it.**
- **The board worktree now REFUSES where it used to reset.** `kwt_sync` refuses when the worktree
  carries a commit that is not on the trunk, instead of `reset --hard`ing over it, and the detach
  repair refuses rather than reporting *"nothing else changed"* about a state it could not read.
  **There is no opt-out flag** — discarding a commit is a deliberate act and costs a deliberate hand
  command. If a script of yours relied on sync always succeeding, it will now stop.
- **`subtask.sh` refuses two things it used to accept**, both before mutating: an **absent parent**,
  and an **unvalidated `--role`**. The second mattered more than it sounds — a typo'd role reached the
  commit subject, the hook rejected it *mid-operation*, and the `git mv` plus Activity append were left
  uncommitted in the shared worktree the next board op wipes. It also **checks `kwt_finalize`'s return
  at both sites**, so a failed push is no longer reported as success.
- **`release.sh` refuses an unmarked verify-skip override.** Setting the skip variable without the
  marker now exits non-zero having written nothing, and names the legitimate route instead — *an
  unmarked override does not weaken a gate, it removes one.*

Otherwise none. Every other change above is either a new refusal that fires only on a setup that was
already broken, a correction to the seed's own files, or new material that binds nothing until you
reach for it. **A project that never holds a dogfooding round pays nothing for the two new sheets** —
they are one more file each in directories you already carry.

Worth reading anyway if you maintain guards: `doctrine/instruments.md` § A.2 (*every green owes an
ablation*) is the rule the kit itself had been breaking, and the same shape is easy to
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
