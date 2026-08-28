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

- **`finish-pr.sh` names the trunk on its green line.** The human-readable post-merge verify line
  now reads `PASS on <trunk>` as its FAIL sibling always did; the machine-readable
  `POST_MERGE_GATE: PASS|FAIL` pair is unchanged, so anything keyed on it keeps working. **No action
  required.**
- **Shipped scripts and workflow runners no longer cite the kit repository's change files.** Six
  comments and one prompt string handed to your agent at runtime referred to `change NNN` — a record
  that exists in no repository you have. Each now states the reason it stood for. The self-test
  harness still carries some; they are being removed. **No action required.**
- **The `dev/` index discipline names its granularity.** Every file and subdirectory under `dev/` is
  reachable from exactly one row — the file's own for a loose file, **the directory's** for a split-out
  directory, whose README then indexes its members. `dev/handoffs/` no longer asks for a row per
  handoff: its dated filenames are its member index. **Action required: none** — if you already had
  per-handoff rows they remain correct as an index of your own; the rule no longer requires them.
- **The drift report's advisory arms now carry a machine-readable token.** An arm that reports
  without deciding the verdict writes the literal `reports only` in its own header line, and
  consumers may key on it — `contracts/drift-report.md` § 4 item 5. `kit-init`'s self-check also
  stopped discarding findings an arm prints on its own header line, so an over-threshold column
  fails the self-check again as it did before the advisory arms existed.
- **`kit-init`'s self-check no longer fails on the first-commit subject the kit's own git-hosting
  recipe prints.** It decides on the drift report's verdict line, tolerates only role-prefix
  findings on commits that predate the run, and shows the rest of the report as context. Before
  this, following `GIT-HOSTING.md` § 3 to the letter — an unprefixed `init` commit, hooks wired
  after — made the initializer refuse a correctly initialized tree, naming the graduation arm as
  the cause. Nothing to do: the fix only makes an install succeed that previously refused, and
  `kit-init` refuses a second run on an initialized tree anyway.
- **The self-test suite gains nine cases, and three of them read your tree rather than a sandbox.**
  Most of the suite builds a throwaway repository and tests the kit's machinery inside it. Three of
  the new cases instead read what you actually ship: that no skill states a forge command as an
  instruction rather than as a named example, that the upstream product name survives only where
  renaming it would falsify a true statement, and that `dev/README.md` names every subdirectory
  carrying its own README. **These can go red on content that is yours to edit, and that is the
  intent** — each names the file and the line it means. If you have taken the optional forge flavor
  and written your forge's command into your own copy of a skill, mark it as your project's declared
  example or drop that case; the case's own message says which line it means. **No action required
  otherwise.**
- `scripts/test/run.sh` is classified **MIXED**, not KIT: the sandbox frame is the kit's, and any
  case family that pins your project's own facts is yours to edit or drop. The contract sheet and
  the extraction manifest already said so; the file's own marker now agrees with them.
- **A change whose operands straddle the two commit lanes is now a named case with a rule.**
  `process/doctrine/commit-hygiene.md` gains **§ A.5**: where a guard and the record it reads — or
  a declaration and the ceiling it is held against, or a procedure naming two artifacts — sit in
  different commit lanes and are only jointly satisfiable, **the unit the gate is being asked
  about is the SET, not the file**, and the invariant is **ALL-OLD or ALL-NEW, never MIXED**. The
  branch run is the only proof of ALL-NEW; the trunk is *expected* to be ALL-OLD until the merge,
  and a report calling that window a breach teaches its readers to ignore the report; the
  post-merge run is a **detector, never a gate**. It also states the thing a project would
  otherwise go hunting for: **a straddling guard cannot be made true on the trunk, and no
  mechanism removes that** — what is law is the compensator set, and two of those already ship
  here (the landing script's post-merge check, a detector by construction; the drift report's
  rule that every check names the source it read), so they are cited rather than restated.
  Nothing you already do becomes wrong, and no command, flag, path or refusal changes. What
  changes is that a straddling set now has a name and a rule where the kit previously gave you no
  way to say what was wrong. **No action required.**
- **`process/doctrine/fix-execution.md` § A.2 now asks whether a ruling has ever been executed.**
  A rule nothing has yet had to obey is **untested**, and its record says so — because the
  instances that accumulate under an unexecuted rule are retrospective, and retrospective
  instances look exactly like compliance. One bullet. **No action required.**
- **`lookup-tables.md` § A.5 and `instruments.md` § A.6 now point at each other.** Two readers
  took them for a contradiction — one tolerates a hand-kept index guarded in a single direction,
  the other says a reconciliation must print the difference **both** ways. They are two axes, not
  a disagreement: § A.5 decides **whether you owe** the reconciliation, § A.6 decides **what it
  must print** once you build one. Each now says so where the other reader lands.
- **`EXTRACTION.md` § 2.2 and § 2.4 are now tables, and the tables are the counts.** The status-folder
  carriers and the role-set carriers are each listed with what they hold; § 2.2 distinguishes the
  files that carry the lifecycle as a set from the ones that hold only the fixed endpoints of their
  own transition, and carries a divergence column because `subtask.sh` omits `done` and `setup.sh`
  adds `history/`. § 1.1's day-one table gains `.env.example` and `.gitignore`. The adapter template's
  parked-role paragraph now says what adding a role actually touches — every carrier § 2.4 lists —
  and that parking touches none of the scripts by design.
- **The self-test harness now runs green in an initialized project.** It previously reported one FAIL
  and exited 1 for every adopter who completed § Day one and then ran `./scripts/test/run.sh` as the
  kit instructs: the sandbox inherited your stamped issue prefix in `.claude/templates/` while its
  config was reset to the shipped one, so the initializer had nothing to substitute inside the
  sandbox. Nothing to do — re-run the harness. **One limit, stated because it is measured:** a project
  that also ran `kit-init.sh --roles` to declare its own role set is still red, for a different and
  unrelated reason the harness names in each failure (`--role must be …`); that is tracked separately
  and is not fixed here. **One new refusal:** if `.claude/templates/ISSUE.template.md` carries neither
  the shipped `<PREFIX>` placeholder nor your stamped prefix, the run now aborts with a FIXTURE FAILURE
  naming the file, instead of a case failure that reads like a defect in `kit-init.sh`.
  `process/contracts/self-test-harness.md` § 2 now carries the invariant behind all of this, so a
  project with its own harness is held to it too.
- **The shipped skills stop naming the upstream product where nothing depends on the name** —
  `executing-plans`, `using-superpowers` § Instruction Priority and `finishing-a-development-branch`
  § Step 6 now read in the kit's own terms, and a worked example's `~/.config/…/hooks/` path is a
  blank instead of that tool's real one. **Two dependencies are kept on purpose, and each says so
  where you will read it:** `~/.config/superpowers/worktrees/` stays exactly as written, with a
  sentence in `using-git-worktrees` § Directory Selection explaining that it is an external tool's
  directory these skills *adopt* where it already exists rather than create (a worktree is made
  inside it; the directory itself never is) — renaming it would send the check looking for a
  directory nothing creates; and the upstream repository link in the companion's page header stays
  as provenance, because a skill whose origin nobody can name is a skill nobody can safely update.
  The `using-superpowers` skill directory keeps its name for now — renaming it breaks every path that
  cites it. Also: `references/gemini-tools.md` drops two sentences that contradicted the file's own
  corrected statement, keeping the live instruction inside them.
- **`contracts/initializer.md` § 2 gains a hard invariant** — a substitution names the space it
  rewrites, and a convention's key is not in it; any census of surviving placeholder residue exempts
  those keys in the same change. **`contracts/config-seam.md` § 4 item 3** names the same exemption
  beside the provenance-citation one. If you implement your own initializer, these are new obligations
  you already needed and could not read anywhere. No action required — the code half shipped earlier.
- **`release.sh` prints where the release actually is, before it pushes.** Between the annotated tag
  and the two pushes it now states — as ordinary output, on a healthy run — that the bump, the
  release commit and the tag exist in your clone and **nowhere else**, the two `git push` commands
  that finish the cut, that each of those is safe to re-run while **re-running `release.sh` is not**
  (the tag exists now, so preflight 1 refuses), and the two commands that abandon the cut instead. A
  completed run is unchanged apart from the extra block; a run **killed** in that window used to
  leave a transcript asserting a release commit and an annotated tag with nothing saying neither had
  been pushed. `process/contracts/release-ritual.md` § 2 now carries this as an invariant, so a
  project with its own release implementation is held to it too. No action required.
- **`move-issue.sh` no longer creates the kanban worktree just to tell you a card id is wrong.** The
  existence check now runs first, against the trunk ref itself, so a mistyped id refuses and leaves
  nothing behind — and the refusal says which tree it read. It can only refuse: an unreadable
  tracking ref, a trunk carrying no `progress/` board, or a glob passed where an id belongs all fall
  through to the old path unchanged, and a miss is re-read after a fetch, so a card another operator
  has just pushed is never reported as missing. `contracts/board-mover.md` § 2 states the rule behind
  it: a refusal decided from the invocation alone leaves nothing behind, and one that depends on
  board contents must at least try to. Nothing to do.
- **`receiving-code-review`'s thread-reply section is no longer GitHub-only.** It was headed *GitHub
  Thread Replies* and stated the rule as a `gh api …/replies` invocation — the one place the kit's
  own skill set told you to run a forge CLI, in a kit whose landing path is deliberately pure git. It
  is now headed **Replying in a Review Thread** and states the rule that travels: reply **in the
  thread you are answering**, never as a new top-level comment; the mechanism is your forge's, and
  GitHub's CLI is named as one example. It also covers the path this kit gives you out of the box,
  where the review record is a file in the repository and there is **no forge object at all** —
  answer at the finding, not in a new section at the bottom. **Nothing to do**, unless something of
  yours cites the old heading. If you re-copy this skill from upstream, `skills/README.md` now says
  why the local wording differs and which way the merge goes.
- **`process/doctrine/lookup-tables.md` § A.1 now names the read-time exemption's shipped dependent,
  and scopes "triggers nothing however large it grows" to the size axis.** Two things a reader of
  that paragraph could not see. First: at least one shipped doctrine sheet already sits above the
  byte trigger and owes no index **solely** through the exemption, and nothing in § A.1 said so — an
  editor narrowing the rule was one edit away from landing an index obligation on a real sheet.
  § A.1 now says it, names `wc -c process/doctrine/*.md | sort -n` read against the trigger as the
  way to find *which* sheet (derived, not stored), and requires **a sheet that crosses the trigger
  to carry one line in its own header naming the exemption**; `process/doctrine/instruments.md`
  carries that line. Second: *"a doctrine sheet triggers nothing however large it grows"* was
  grammatically absolute while its qualifier scoped it to size, so a hurried reader could take it as
  beating the role trigger above it. It does not: **a role doc that makes a sheet a mandatory read
  removes the exemption's premise**, so the role trigger applies to it like any other file. **The
  policy is unchanged in both cases.** No Action required — unless one of your own doctrine sheets is
  over the trigger, in which case it owes that one header line.
- **`CLAUDE.md` now ships as a bootstrap stub, not as a pre-filled adapter.** A fresh unpack's
  `CLAUDE.md` says the project is not set up yet and sends day one to `process/SEED.md`; you build
  your adapter from `process/templates/CLAUDE-adapter.template.md` and **overwrite** the stub.
  `README.md` and `CLAUDE.md` both carry a `BOOTSTRAP-SCAFFOLDING` line that goes when the file is
  replaced. `AGENTS.md` now says which of the two states you are in. See § Action required if your
  adapter predates this release.
- **`MANUAL.md`'s session-close ritual now names one more state, and § The kanban worktree stops
  over-promising.** At session close, the **local trunk ref must not be ahead of
  `<remote>/<trunk>`** — everything the process commits direct to the trunk (rulings, specs, board
  edits) lands there, so an `ahead` is work nobody else can see. The ritual cites `check-board.sh`
  arm `[f1]`, which already makes exactly that reading and prints the push command, so there is
  nothing new to run: the bullet writes down what your drift report already enforces. It deliberately
  asks nothing about `HEAD` — a dispatched leg legitimately holds the checkout on a work branch, so a
  HEAD-vs-trunk comparison would redden on every orchestrated run — and `behind` is a stale view
  rather than a finding. Separately, § The kanban worktree's claim that `check-board.sh` *"surfaces
  the divergence"* now carries the span the arm itself prints: it counts commits reachable from a
  ref, so a commit reachable from **no** ref at all — an orphaned sibling, left behind when `HEAD`
  moved — is outside that measurement and would need the reflog. The check has not changed; the
  manual has stopped implying it covers a case it never did.
- **A second file axis: disposition.** Alongside `KIT-CLASS:` (does this travel?),
  `process/EXTRACTION.md` now names what state each file must reach before day one is done — KEEP,
  STAMP, FILL, REPLACE, SEED, DELETE-IF-UNUSED. The one that changes behaviour is **REPLACE**:
  `CLAUDE.md` and `README.md` are scaffolding to be thrown away and rewritten, not edited into shape.
  The marker-strip rule is stated with it: strip `KIT-CLASS:` where a file's class has become
  `PROJECT`; keep and re-mark it where the file stays `KIT` or `MIXED`.
- **`doctrine/fix-execution.md` § A.9's never-edit rule gains its missing half.** A supplied document
  that arrived corrupted in transit (mojibake, stripped bytes) may be repaired **mechanically**, with
  the raw bytes preserved beside the repair so the transformation is a diff anyone can run rather
  than a claim anyone must trust. Before this, the rule was an absolute that told you to preserve a
  corrupted document forever — which nobody would do, so it would have been broken silently instead
  of amended openly. Nothing to do unless you hold a corrupted supplied document; if you do, repair
  it this way.
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
- **[`contracts/retention-completeness.md`](contracts/retention-completeness.md) is now marked
  deliberately non-travelling.** Its § 6 named `scripts/githooks/pre-commit` as its reference
  implementation and the kit ships no such hook — `githooks/` carries `applypatch-msg` and
  `commit-msg` only. **That sheet is a spec you implement, not a gate you inherit**;
  `contracts/README.md`'s row and [`doctrine/retention.md`](doctrine/retention.md) § A.5 now say so,
  and the adoption checklist that asks you to name your guards now states that **both are yours to
  write and the kit ships neither** — an unnamed guard you never wrote is indistinguishable from one
  you have. **If you went looking for that hook in your copy and could not find it, this is why** —
  nothing is missing from your tree.
- **The shipped Dev skills no longer reference a foreign plugin namespace.** Those references named
  skills this kit does not ship, so they could never resolve — and `writing-plans` instructed every
  plan to carry the namespaced header, so the bad references grew with every plan written. **One
  skill's option set changed as a result: if you have anything reading its old option numbers, re-read
  it.** A harness case now finds a planted namespace reference, so the class cannot come back quietly.
- **[`templates/CLAUDE-adapter.template.md`](templates/CLAUDE-adapter.template.md) gains the three
  tables the rest of the kit binds on** — roles, role-attribution commit prefixes, and the
  code-vs-metadata glob declaration with its carve-out. **Which shape is law is per disposition**: for
  REPLACE-class files (`CLAUDE.md`, `README.md`) the template is law and the shipped root file is
  scaffolding; for FILL and SEED files the in-place instance stays law. The defect this closes was not
  really omission but a **broken citation**: `AGENTS.md` anchors into `CLAUDE.md` § "Role-attribution
  commit prefixes" by section name while the `commit-msg` hook enforces that set, so an adapter written
  without it carries a dangling anchor **plus** an enforced-but-unspecified seam — and that bites on
  the first commit, not later. **See Action required if you wrote your adapter from the older
  template.**
- **The `autoMode` block and the `plansDirectory` value are gone from `.claude/settings.json.example`.**
  Nothing in the kit read either, and `autoMode`'s `allow` / `soft_deny` / `environment` arrays held
  **English sentences rather than tool patterns**, so no permission engine could have enforced them
  under any key name. It enforced nothing and guided nobody while reading exactly like active
  authorization policy, which is the worse of the two failures. **If you copied the example verbatim
  and believed `autoMode` was authorizing direct-to-trunk work, it never was** — the trunk policy has
  one home, your adapter's § The trunk, the branches, and what counts as code here. The file now
  carries a short note recording that both keys were removed, so their absence is not read as an
  omission.
- **The rotation tool's header no longer calls `##` the modern log-entry form.** The **dated `###`
  session heading is the form the kit documents.** `archive-progress.sh` still matches `##` so a
  project that already wrote it is not stranded — accepting a form you no longer document is the
  forgiving direction — but **do not migrate toward it**: `check-board.sh`'s § Log size arm and
  `kit-init.sh`'s already-lived probe both scan to the next `##` and stop, so a `##` dated entry
  **terminates the § Log section it is supposed to sit inside**. Measured: the size arm then reports
  healthy forever, and the lived probe counts zero lines and reads a working repository as new,
  defeating the initializer refusal that is supposed to be made by a rule rather than by the operator's
  memory. The old wording is kept in the header beside the correction, with what it cost.

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
- **`kit-init.sh`'s prefix stamping no longer rewrites the `KIT-CLASS:` marker key.** With a
  non-default `--prefix`, the substitution matched the marker's own **key**, so every shipped file it
  touched came out reading `<!-- <PREFIX>-CLASS: KIT — … -->`: the key rewritten, the value left, a
  line that refutes itself, and a `grep KIT-CLASS` over the initialized tree finding nothing. The
  `KIT` in `KIT-CLASS:` is **the convention's own word**, not your issue prefix — it only looked like
  the prefix because the shipped placeholder prefix is also `KIT`, and that collision was the whole
  bug. The key is now a constant behind a substitution sentinel, the placeholder census excludes it,
  and the initializer's self-check asserts the shipped markers survived stamping. **See Action
  required: this stops future defacement and does not repair a tree already stamped.**

### Action required

- **Your process artifacts move out of `docs/`.** The kit used to send engineering design specs
  to `docs/specs/`, plans to `docs/plans/`, refactor passes to `docs/refactor/`, design passes to
  `docs/design/` and run records to `docs/runs/`. **They now go to `dev/` under the same names**,
  inheriting `dev/`'s dated-snapshot convention and its index. **`git mv` those five directories
  into `dev/`** and update the citations that point at them — a plan or spec cited from an issue
  file carries the old path. The kit ships the five directories, so they will exist in your tree
  whether or not you have anything to put in them yet.
- **`docs/` does not go away, and it is not empty.** It is now a stated home for **material your
  project did not write** — a vendor's API guide, a third-party spec, an artifact produced to
  leave the project — with `docs/README.md` carrying the test that tells it apart from `dev/`.
  **Anything left in your `docs/` after the move is either that, or it is a working record that
  belongs in `dev/`.** Sorting it is a one-time read.
- **If you carry your own copy of `reachability_walk.py`**, add `specs`, `design` and `runs` to
  its `DEV_PROSE_TREES`. Without them the walker still runs and still reports — it just collapses
  those three directories to one node each, so their members stop being individually visible.
  Nothing goes red; the report just gets quieter about the newest part of your tree.
- **If you implement the drift report yourself, an advisory arm must carry the `reports only`
  token in its header** (`contracts/drift-report.md` § 4 item 5). A consumer that re-reads your
  rendered findings has no other way to tell an advisory line from a deciding one, and an advisory
  arm that appears on every run will otherwise fail that consumer the first time any unrelated
  finding flips the verdict.
- **The scoped run stops overstating its floor.** `scripts/verify.sh`'s guard-floor header said
  a rename that forgot the list *"fails loudly instead of quietly shrinking the floor"* — true
  of a **listed** path that vanishes, and false of the direction that actually costs you: a
  guard that lands and is never enrolled is invisible to that check, because the list is the
  only thing it reads. The header now says both, and names the unguarded direction as the price
  of keeping membership readable without running anything. The run's own output says
  `DECLARED guard(s)` instead of `always-on guard(s)` and states that the floor is only as
  complete as the declaration, and the Dev role doc no longer calls a scoped run *safe* without
  saying what it is not. **Nothing about what runs has changed** — this is the same floor,
  described honestly. **If you have filled `GUARD_SET`, take the corrected header block into
  your own copy and keep your contents**; the sentence you are replacing is the one that would
  have told you the omission could not happen quietly.
- **If you carry a hand-kept index or list guarded in only ONE direction, check what its in-file
  note actually says.** `lookup-tables.md` § A.5 rank 4 has always tolerated that shape *"only
  with a named reason in-file"*; it now requires the reason to **name the direction left
  unguarded** — not merely to explain why the list is hand-kept. A note saying *"this list is
  maintained by hand because the members are decided by a human"* does not meet it; *"nothing
  detects a member that exists in the tree and is missing from this list"* does. **One sentence
  per such list**, and the point of it is that the next reader learns the blind spot from the
  file rather than from an incident.
- **Two checks, if either applies to you.** If you derive your `MIXED` file set with
  `grep -rl 'KIT-CLASS: MIXED'`, it over-counts — a script that generates a classified file carries
  that file's marker; use the first-marker-per-file form now shown in `EXTRACTION.md` § 1.1. And if
  you added a role by following the adapter's old "editing three places" sentence, check
  `scripts/move-issue.sh` and `scripts/subtask.sh`: a role registered only in the hook and the adapter
  commits fine and cannot move a card — § 2.4's table is every carrier.
- **If you use the `brainstorming` skill's visual companion with `--project-dir`: its persistence
  directory is now `.brainstorm/`, not `.superpowers/brainstorm/`.** Add `.brainstorm/` to your
  `.gitignore`. If you had ignored only `.superpowers/`, the next session's mockups would be
  **tracked** — that is the single failure this rename can cause. Mockups already saved under
  `.superpowers/brainstorm/` are **not** moved and nothing reads them: keep the directory if you still
  want them, delete it when you do not. An old session still stops cleanly, because `stop-server.sh`
  takes the session directory as its argument.
- **The drift report gains a day-one completeness check.** `check-board.sh` now reports, at every
  session close, while `CLAUDE.md` or `README.md` still carry the shipped `BOOTSTRAP-SCAFFOLDING` line
  or `PROJECT.md` still holds `<angle-bracket>` blanks. It reads your published trunk, names what it
  read on both the reporting and the clearing branch, and **does not affect the `board-drift:`
  verdict line** — so it cannot block a release or fail `kit-init`'s self-check. **Action required:** a
  project already past day one will see the new `[g]` line report findings if it kept the kit's
  shipped `README.md`, or left `<angle-bracket>` blanks in `PROJECT.md`. That is the check working.
  Replace the files, or fill the blanks, and the arm goes quiet on its own. A reimplementation of the
  drift report in another stack now owes invariant 7. One known limit, stated because it is measured:
  the arm is gated on the initializer's stamp receipt, so a project that implemented the contracts in
  its own toolchain and never ran `kit-init.sh` does not see the prompt — an open question, recorded.
- **The commit-message hook now refuses generated co-author trailers — if your tooling adds one, your
  next commit is rejected.** `scripts/githooks/commit-msg` used to judge only the subject's role tag;
  it now also reads the **whole message** and refuses a `Co-Authored-By:` line naming a **tool**, or
  a *"Generated with …"* line (`doctrine/commit-hygiene.md` § A.1 — a rule the kit has always stated
  and never enforced, which is why the sheet predicted that "the default the tool ships with" would
  win). `scripts/githooks/applypatch-msg` delegates to it, so `git am` and `git cherry-pick` are
  covered by the same rule. **What to do: turn the trailer off where it is generated** — your
  agent's or editor's setting — rather than working around the hook; that is the point of the rule.
  **A trailer naming a human is still accepted**: only tool markers are refused, and the markers are
  one named line in the hook (`TOOL_TRAILER_MARKERS`) that you extend in one place when you meet a
  new tool. **If you must import a third party's commit verbatim** — a cherry-pick or `git am` whose
  message already carries a tool trailer — the documented escape is `MSG_OK=1 git commit …` /
  `MSG_OK=1 git am …`; it exists for somebody else's message, not for your own. Two things
  deliberately unchanged: a **merge or revert subject** is exempt from the *prefix* rule and is
  **not** exempt from this one, because the body is where the trailer lives; and **`git commit -v`
  still works** — the diff below the scissors line is cut before the scan. If you initialized with
  `kit-init.sh`, `core.hooksPath` is already set and the refusal is live as soon as you take the new
  hook; if you copied the hook by hand, copy it again.
- **If you built your adapter from a template older than this release, it is missing two sections:
  § The binding gates here and § Where the rest of the process lives.** The latter is your adapter's
  only route into `process/MANUAL.md`, `contracts/`, `doctrine/`, `hygiene-checklist.md`,
  `GIT-HOSTING.md`, `EXTRACTION.md` and `SEED.md`. Adding them to the template does not add them to
  your copy. **Diff your `CLAUDE.md` against `process/templates/CLAUDE-adapter.template.md` and port
  anything missing.**
- **Only if `progress/history/` ALREADY holds rotated chunks: create `progress/history/INDEX.md`
  before your next rotation.** The rotation will not write one for you while chunks exist, because a
  row-less index would deny them — and the date spans are inside those chunks, so only you have them.
  Create the file with the header row **and its markdown separator**, then one row per existing
  chunk — **both lines, exactly:**

  ```
  | Chunk | Covers | Entries | Rotated | Cut |
  |---|---|---|---|---|
  ```

  **The separator is not cosmetic — and the rotation now refuses without it.** The insert goes directly
  below the header row and reprints the line after it, so an index whose header is not followed by a
  separator would have **your first chunk row consumed in the separator's place**: the new row lands
  *second* and your newest entry is no longer first. That is why the separator is load-bearing.
  Rather than mis-write the file, `archive-progress.sh` now validates that line and **exits 1**,
  printing the two lines your index must open with; it will not insert the separator for you, because
  that file is your record. So a malformed index costs you an **aborted rotation** rather than a
  silently mis-ordered one — and note the posture: **the chunk and the rewritten log are already on
  disk when it refuses.** Fix the two lines and append the printed row by hand; do not re-run.
  *(An earlier version of this item said the rotation "assumes" the next line is the separator. It
  did, and it mis-wrote. The reason above is unchanged; only the consequence is. Corrected
  2026-08-28.)*

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
- **The rotation now REFUSES a malformed `progress/history/INDEX.md` instead of mis-writing it.** If the
  header row is not followed by a markdown separator, `archive-progress.sh` **exits 1** and prints the
  two lines your file must open with. It will not insert the separator for you: that file is your
  record, and a tool that quietly rewrites it to suit itself is how an index comes to state things
  nobody put there. **Note the posture — the chunk and the rewritten log are already on disk when it
  refuses**, so fix the two lines and **append the printed row by hand rather than re-running.** The
  separator is matched by GFM **shape**, not by exact bytes, so `| --- | --- |` is accepted as readily
  as `|---|---|`. If your index is well-formed, nothing changes for you.
- **The `ISSUE`, `BUG`, `REFACTOR` and `SUBTASK` templates carry a new `pr:` frontmatter key** (`PRD`
  does not — a PRD has no PR), **and cards minted from them start at `pr: null`.**
  `move-issue.sh --set-pr <val>` writes the resolved PR/MR reference into that line on a
  card that has it, and **warns and skips the write-back on a card that does not** — so cards you
  minted from an older template are silently not updated, which is the case to know about. Nothing
  shipped calls the flag; it exists for a forge-aware wrapper of your own, and stays `null` on the
  forge-agnostic path. **If your own tooling parses card frontmatter, expect the new key**; if you want
  it on existing cards, add the line to them, as the templates now write it.
- **If you initialized with a non-default `--prefix`, your classification markers are already defaced —
  grep for them and repair them by hand.** The stamping bug in § Fixed above rewrote the marker's key
  on every shipped file it touched, and **the fix stops future defacement; it cannot go back**, because
  there is no updater (see *How to upgrade an adopted project*). Run
  `grep -rn --exclude-dir=.git -- '-CLASS:' .` and repair any marker whose **key** is not
  `KIT-CLASS:` — the value after the colon (`KIT` / `MIXED` /
  `PROJECT`) was never touched, so the repair is the key alone. Start with `.claude/templates/` and
  `.claude/roles/`, and then check your own cards: every card minted after day one inherited the
  corrupted key from the template it was copied from.
- **If you wrote your adapter from the older `CLAUDE-adapter.template.md`, add the three tables it was
  missing.** The template now carries the roles table, the role-attribution commit-prefix table and the
  code-vs-metadata glob declaration; adding them to the template does not add them to a file already
  written from it, and the rest of the kit cites your adapter for exactly that content.
  **The prefix table is the one that bites**: `AGENTS.md` anchors into your adapter's
  § "Role-attribution commit prefixes" by section name and the `commit-msg` hook **enforces** that
  set, so an adapter without it leaves a dangling anchor plus an enforced-but-unspecified seam, on your
  first commit rather than eventually. Copy the three shapes across and fill them — the values are
  yours, only the shapes come from the template.

**Checked against the board and the tree on 2026-08-28**, at the kit repository's own revision
`7da2264` plus the reconciliation that reading produced: every adopter-visible change listed above
carries its entry, and every entry that needs something from you is in this section. Nothing else above requires an
action — the rest are refusals that fire only on a setup that was already broken, corrections to the
seed's own files, or new material that binds nothing until you reach for it. **A project that never
holds a dogfooding round pays nothing for the two new sheets** — they are one more file each in
directories you already carry.

**Read that as a measurement, not a guarantee — and here is why it is dated.** This paragraph used to
read *"Otherwise none."*: a standing all-clear that no later change re-derived. Adopter-visible work
then landed with no entry at all, twice in the same release cycle, and the all-clear went quietly false
both times while reading exactly as it always had. *Derive, date, or do not state* is the kit's own rule
and it binds this file too. **If the date above is older than the newest entry you are reading, trust
the entries and not the all-clear.**

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
