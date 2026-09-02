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

- **The hygiene instruments' prefix-exclusion set now lives in one place.** `cold_signal.py` and
  `duplication_scan.py` each defined it, under different names, with byte-identical values and **two
  separate "EDIT THESE for your tree" instructions** — so tuning the corpus in one left the other
  reporting on a different one. It is now `DEFAULT_EXCLUDED_PREFIXES` in `citation_index.py`, which
  every instrument in that directory already imports. **Action required if you tuned either copy:**
  re-apply your edit once, in `citation_index.py`, and delete nothing else — your other copy is gone.

- **`NOTIFY_ON_SETUP_FAILURE` is declarative — nothing in the kit branches on it — and both places
  that named its legal values now agree.** `.env.example` said `continue|abort` while the warning said
  `stop`, and no code read either. The knob records what your project wants done when
  `notify.sh test` fails; `test`'s non-zero exit is the fact, and your own session-start wiring is
  what acts on it. **Action required if you set it to `stop`:** that spelling was never read by
  anything, but it is now wrong on its face — use `abort`.

- **If `finish-pr.sh` refuses because you have no gate runner at all, it now tells you how to GET
  one.** That advice — *write `scripts/verify.sh`, or generate it with `kit-init.sh --gate-command`* —
  sat in a branch no input could reach, so the refusal an adopter actually met talked about checking
  out branches and using `--worktree`: the remedy for a gate at the wrong revision, not for having no
  gate. The two cases are now told apart and each gets its own remedy. **No action required** — the
  refusal conditions are unchanged; only what they tell you.

- **`EXTRACTION.md` § 2.2's `setup.sh` row was wrong in both of its cells.** It said `setup.sh`
  CREATES the board directories; `setup.sh` contains no `mkdir` and only checks they exist. And it
  said a missed column means *"a fresh clone is missing the directory"* — that is `kit-init.sh`'s
  row. What a missed column actually costs `setup.sh` is that it **stops noticing**: a tree lacking
  the new column passes its check silently. **If you have added a board column, re-check that
  `setup.sh`'s `BOARD_FOLDERS` lists it** — nothing failed to tell you it did not.

- **The run-outcome vocabulary now has a named declaration in each runner and a self-test case holding
  the two together.** `LANDED`, `LAND_READY`, `PARKED_OK`, `PARK_UNVERIFIED`, `FAILED_AFTER_FIX_ROUND`
  and `BLOCKED_DEV` were bare string literals at twelve sites across the pair, with nothing holding
  them in step — so the two runners could report different outcome sets for the same situation. The
  case also refuses a declared token the runner never returns. **No action required** — no token was
  added, removed or renamed, and the values a run reports are unchanged.

- **`EXTRACTION.md` § 2.2 now registers the `.claude/` tree as a status-folder carrier, and its
  derivation recipe can finally reach it.** The recipe scoped to `scripts/` and `setup.sh`, so the
  runners, item templates, role docs, worker definitions and two skills — all of which name board
  columns — were invisible to the instrument the section offers for finding carriers. **If you have
  renamed or added a board column, re-run the widened recipe:** the narrow one returned fewer than
  half the files that name a column, so a previous lifecycle change may have missed the agent-facing
  half and left briefs instructing a move to a column that does not exist.

- **The two workflow runners' result schemas now agree field-for-field, and a self-test case keeps
  them that way.** Five field descriptions had drifted apart between `tranche-runner` and
  `wave-runner`, and one field had lost its description entirely — so the same result field was
  explained differently, or not at all, depending on which runner briefed the agent. The runners
  cannot share a module (the workflow runtime gives them no imports), so the copies are permanent and
  a guard now holds their agreement instead. **No action required** — no field, type or enum changed,
  only the descriptions agents are given.

- **`wave-runner` now honours a per-issue `role`.** Its description has always promised the same
  per-issue fields as `tranche-runner`, and `role` was accepted and silently ignored — so a
  Refactorer-hat issue placed in a wave was briefed as Dev, pointed at `dev.md`, **and stamped its
  board moves `[Dev]`**, which is what the commit-msg hook enforces and what the board's attribution
  arm reads. **Action required if you have run Refactorer issues through a wave:** their board moves
  and progress entries carry `[Dev]`, so attribution for that work is wrong on the trunk and in
  `check-board.sh`'s report. Nothing needs re-running; the record is what is affected.

- **`tranche-runner` now tells Dev to cut work branches from `<remote>/<trunk>`, not the local trunk**,
  matching what `wave-runner` already said. Neither runner instructs a pull first, so *"from a fresh
  main"* meant whatever the checkout happened to hold — and in a tranche that lands issues as it runs,
  the second issue could branch off a trunk missing the first. A new optional `remote` arg defaults to
  `origin`. **No action required** unless your remote is not called `origin`, in which case pass
  `remote` in args as you already do for `wave-runner`.

- **The QA brief's procedure no longer skips a number.** The zero-drift check is conditional, and while
  it was a numbered step the list jumped from 5 to 7 whenever it was absent — which reads to a reviewer
  like a step that went missing on the way to them. It is now an unnumbered continuation of the
  binding-gates step, which is also what it is: a gate for that issue, not a separate phase. **No action
  required** — the checks are unchanged, only their presentation.

- **`tranche-runner` no longer documents a per-issue `slug` field.** It was listed in the args
  comment and echoed in the parse-failure message while nothing in either runner read it, so a caller
  was asked for a value that could not affect the run. There is nowhere it could be used: every board
  move the runners emit goes through `./scripts/move-issue.sh <id>`, which resolves the card path from
  the id alone. **No action required** — passing `slug` was always inert and still is; it is simply no
  longer asked for.

- **Both workflow runners now refuse an omitted or empty issue list by name.** Driving
  `tranche-runner` with no `issues` previously died on JavaScript's own `TypeError: undefined is not
  iterable`, which names neither the runner nor the field; driving `wave-runner` with no waves was
  **worse — it reported a clean success over zero issues**, because an empty result list satisfies
  every wave gate vacuously. Both now fail at 0 agents with a message naming the field and the shape
  expected. One wave is still legitimate; neither is not. **No action required** — a correct call is
  unaffected.

### Added

- **Day one has a documented variant for making your first *published* commit your project's own.**
  The initializer requires a commit before it runs and then makes and pushes its own, plus more
  while self-checking, so the earliest history on a hosted remote necessarily began with kit
  scaffolding — and `--skip-self-check` does not change that. `README.md` § Day one now names the
  way through: point `origin` at a local bare repository first, run day one against it **with the
  self-check intact**, author your content, then squash and re-point at the host. **The kit does not
  perform the squash and has no flag for it** — that is deliberate, because rewriting history is
  safe there only while nothing has been published, and a tool could not know that. Nothing changes
  for a project already initialized.

### Changed

- **A minted card no longer opens by calling itself a template.** `new-issue.sh`, `new-bug.sh`,
  `new-prd.sh`, `new-refactor.sh` and `subtask.sh` copied their template wholesale, so every live
  card carried the template's `KIT-CLASS:` marker — false the moment the card exists, since a card's
  class becomes PROJECT at mint. Each script now **replaces** that block rather than deleting it,
  because the block also carried the *never leave an angle bracket* instruction, which is still in
  force while you fill the card and is stated nowhere else. The card's new head says it is a live
  card, states that its lack of a travel marker is deliberate, and keeps the fill instruction.
  **No action required.** Cards already on your board keep the old header; strip it if you like —
  nothing reads it. **If you grep your board for `KIT-CLASS` to audit classification, newly minted
  cards will now correctly not appear.**
- **`EXTRACTION.md` no longer tells you both to mark and to strip the same file at the same
  moment.** § The one file classification convention said that once you fill `PROJECT.md` and
  `CLAUDE.md` they are `PROJECT`-class *"by nature"* and to **mark them so**, while § The marker and
  graduation said to **strip** the marker at exactly that point — and named `PROJECT.md` as its own
  worked example. The graduation rule is the correct one and stands; the *mark them so* instruction
  is struck, with a pointer to it. **A new carve-out covers the file born in your own tree that will
  never travel:** it carries no marker, and it carries **one visible line saying that absence is
  deliberate**, because a bare absence cannot be told apart from an oversight. The test is whether
  the file's **shape** travels — `requirements/CORPUS.md` keeps its marker however project-specific
  its entries get; a log you invent for yourself never had one. **Action required only if you
  re-marked a graduated file `PROJECT`:** strip it instead, and if you have unmarked files of your
  own, give each the one-line note.
- **`EXTRACTION.md` § 4.6's post-initializer check now reads `.claude/roles/` too, and rules that
  `<trunk>` there is notation rather than an unfilled blank.** The check previously named `<trunk>`
  but scanned only `.claude/agents` and `.claude/workflows`, so it never read the directory that
  actually carries those symbols — and widening it naively would have reported every one as a defect.
  Every role doc **defines** `<trunk>` in its own preamble, and the initializer rewrites the
  **literal** trunk name rather than the symbol, which is also why its census line reads
  `trunk '<default>': N → N` on a project whose trunk is the shipped default: it counts the literal,
  and there was nothing to change. **No action required** — nothing an adopter runs changes; if you
  previously widened § 4.6's grep yourself and got hits in `.claude/roles/`, those hits were the
  definitions.
- **`SEED.md` step 2 now says that `--gate-command` is for that run only, and names the fallback
  where you are standing when you need it.** The flag cannot be supplied on a re-run — the
  initializer refuses and there is no resume path — so a project that has not settled its gate
  command by the time it stamps could not come back for it, and the alternative (declaring gates by
  hand in `scripts/verify.sh`'s `GATES` table) was documented only in `--help` and `README.md`. It
  is now stated in the order-of-operations document too, as a **supported route rather than a
  fallback**: what the landing gate requires is an executable, committed gate runner, never that the
  initializer wrote it. Skipping both is still refused at both ends.
- **The day-one recipe now says `git init -b main`, and the `git switch -c` line is gone.** A bare
  `git init` puts HEAD on whatever `init.defaultBranch` says — still `master` on any machine whose
  git predates the default change or whose user never set it — so the first commit landed on
  `master` and the later `git switch -c` created `main` from it, leaving two branches at one commit.
  The deleted line's condition (*"if your trunk does not exist yet"*) was false at the moment it was
  read, which invited a careful reader to skip it and then be refused by the initializer's trunk
  check for a reason that did not name the cause. `process/SEED.md` step 1 is reconciled to match.
  **No action required** — if you already initialized, a stray `master` at the same commit is
  harmless and yours to delete.
- **A malformed `args` payload to either runner now fails with a message that names the runner, the
  problem and the expected shape.** Passing non-JSON previously produced a bare
  `SyntaxError: JSON Parse error` whose only location was the harness file, not the runner — so the
  message pointed away from the thing that was wrong, at the entry point you drive first. The parse
  is now wrapped: the error names the runner, echoes the value it received (truncated), names the
  required top-level keys, points at where the full shape is declared in that file, and appends the
  underlying parse error. **The fail-fast is unchanged** — the run still dies at 0 agents.
- **`goldenPaths: ''` now actually skips the zero-drift step in both runners.** The runners
  documented *"empty string = skip the zero-drift diff entirely"* and then used `||`, so `''`
  silently restored the default `tests/fixtures tests/golden*` — a project with no pinned-output
  corpus ran a diff against paths that do not exist on every issue, and had to rely on the prompt's
  *"if it matched NOTHING, treat the step as NOT RUN"* warning each time. Both runners now use `??`.
  **If you pass `''` today you will now get a skip where you previously got the default**, which is
  what the comment always promised; if you actually want those paths, name them.

### Action required

- **`.claude/workflows/wave-runner.js` did not parse in v0.2.0 — the wave path was unusable.** A
  paragraph of maintainer narration inside the park-QA brief put backticks around a field name, which
  terminated the template literal and made the whole file unloadable; driving the wave path produced a
  syntax error at 0 agents. It was broken in the released zip, not only in the source. The narration
  has moved into a comment and the brief now matches its sibling's wording. **Action required if you
  adopted v0.2.0 and use the wave path:** take this file from a later kit, or delete the parenthetical
  beginning *"(This line used to say"* from `parkPrompt`'s returned string. `tranche-runner.js` was
  never affected.

- **Three role docs said the model-and-effort table was ratified while the kit shipped it blank.**
  `.claude/roles/dev.md` and `qa.md` said *"ratified by PM"*; `orchestrator.md` said *"the
  adapter's PM ratifies it"* in a present tense that reads as a standing fact. All three now say
  the table ships blank, that filling and ratifying it comes before relying on it, and that until
  then the seat states its chosen model and effort on the card with a reason. **Action required:**
  if you read one of those docs and never filled the ladder, fill and ratify it now — the doctrine
  sheet's own sentence is that an unratified ladder is a habit with a table, and it was coming true
  silently. `pm.md` and `refactorer.md` always said this correctly and are unchanged.
- **A `.gitignore` line whose comment trails the pattern matches nothing, and the kit's own FILL
  block taught that shape.** `#` only begins a comment at the START of a line in gitignore syntax,
  so `dist/  # produced by my build` makes the comment part of the pattern: the rule matches
  nothing, git goes on reporting the artifact, and nothing says why. All four worked examples in
  `.gitignore`'s `<your build artifacts>` block now put the comment on the line above, with the
  reason and `git check-ignore -q` beside them. **Action required if you filled that block by
  following the examples:** move each comment to its own line and verify every entry with
  `git check-ignore -q <path>` — reading them cannot tell you which are dead.

## [0.2.0] — 2026-08-31

### Changed

- **The project-facts sheet is now the only blank, and its template is gone.**
  `process/templates/PROJECT.template.md` is removed: `PROJECT.md` ships as its own blank and you
  fill it **in place**. The template's `§ Retained evidence` has moved into `PROJECT.md`, and two of
  its gate rows — the acceptance tier and retention completeness — were the correct ones and are now
  the shipped ones. *Why:* a template nothing stamps drifts from the instance it claims to be; every
  edit reached the live sheet and none reached the copy. **Action required only if you linked the
  template path** — re-point at `PROJECT.md`. A sheet you have already filled is untouched.
- **`.claude/workflows/wave-runner.js` no longer halts a wave on a verified pass whose landing was
  deferred.** A `LAND_READY` outcome now continues, matching the runner's own stated rule and its
  sibling tranche runner. If you relied on the wave stopping there, it will now proceed to wave 2.
- **The debugging helper `find-polluter.sh` parses again under the default macOS bash.** It was
  unparseable under bash 3.2 — the shell that ships on macOS — so the skill's script could not run
  at all there. Its `TEST_CMD` knob is unchanged and still required; the usage line now says so.
- **Three unused skill files were removed** — two reviewer-prompt templates whose dispatch no longer
  exists and an upstream authoring log citing paths the kit does not have. Nothing references them.
- **`.claude/templates/SUBTASK.template.md`'s parent link was one level short** and resolved to the
  wrong directory; a subtask created from the template now links its parent correctly.
- **`dev/rounds/` now ships** (empty), because the round templates write into it by name.
- **The tranche runner no longer logs `LANDED` for an issue whose landing was deferred.** It logged
  `LAND-READY (verified; landing deferred)` and then `LANDED` on the next line for the same issue.
  Each outcome now logs once, in its own branch. If you parse the runner's log, the duplicate is
  gone.
- **`process/GIT-HOSTING.md` now recommends setting the bare repository's HEAD at creation, and says
  the two forms are not interchangeable.** `git remote set-head <remote> <trunk>` against a bare
  repo whose HEAD points at a branch your first push never created **exits 0 and changes nothing on
  the remote** — the mismatch surfaces later as `HEAD branch: (unknown)`. Prefer `git -C <repo>.git
  symbolic-ref HEAD refs/heads/<trunk>` where you control the bare side. The guide also now states
  the absolute-path constraint the initializer already enforces.
- **`AGENTS.md` no longer says your precedence rule is already written.** It said precedence was
  *stated once* in `requirements/CORPUS.md § Precedence`; that section ships as a blank for you to
  fill. One precedence rule is the kit's and binds before you fill anything — where a contract sheet
  and any prose disagree, the sheet wins — and that is now said where it is authored.
- **Several shipped documents now match the tools they describe.** The archive threshold is
  documented as a constant declared at the top of the report script, not a value your adapter sets;
  the settings example no longer claims the initializer stamps any of its placeholders; the
  initializer's seeded running log teaches the dated `###` entry form its two readers key on; and
  the publishing helpers' messages describe what the code actually does.
- **A creation script no longer leaves a half-written card behind.** An option value containing `|`,
  `&` or `\` is written to the card exactly as given; previously it could abort the substitution and
  leave a partly-filled card and a `.bak` on the board under an id that was now burned. Cards are
  built aside and published whole.
- **A value-taking option with no value now refuses and names itself**, instead of failing with a
  shell error about a positional parameter.
- **`move-issue.sh --help` now succeeds and prints to stdout**, like every other tool in the kit.
- **The rotation tag and cutoff field are meaningful in `--keep-last` mode.** Previously the tag was
  built from the absent `--before` date, so a second keep-last rotation silently skipped tagging.
- **`check-board.sh` now refuses an unrecognised option instead of ignoring it.** It previously
  parsed no arguments at all, so a mistyped flag was silently dropped and the run reported a clean
  board — a caller scripting options against it got silence that read as success. It now exits
  non-zero naming the option, and answers a usage request. **Its drift verdict is unchanged: it
  still exits 0 whatever the board looks like.**
- **The environment template lists the whole notification path**, and the gitignore's own section
  names a producer for each entry — two entries that had none were removed, and the directory the
  brainstorming skill writes into your repository is now ignored.
- **The drift report's "what green means" no longer tells you to count lines.** A check with more
  than one reading prints each reading, and a reading whose subject is absent still prints, naming
  what was absent — so the number of lines is not the number of invariants and never was. Walk the
  invariant list instead.
- **The initializer's preflight is documented as what it is: a hand-listed minimum presence check,
  not a manifest check.** Behaviour is unchanged; the contract and the manifest previously promised
  coverage the tool never had. A file that travels but is not in the minimum is not caught.
- **The commit-attribution contract now states its two exemptions** — tool-generated subjects
  (merge, revert, autosquash) and the documented environment escape. Behaviour is unchanged; an
  implementation built from the old wording rejected every merge commit.
- **The rotation contract's "never create an index" is narrowed to the case that made it true:**
  refuse when the store already holds retired material (listing it as proof); creating an empty
  index is allowed when nothing has been retired yet.
- **The publishing operation's ahead/behind report is documented as conditional** on the trunk being
  checked out in the main checkout — as it has always behaved.
- **The CLI shape (usage always succeeds; unknown option refuses non-zero, naming it; one exit
  status across the tool set) is stated as binding every shipped command-line tool**, not only the
  creators.
- **The post-stamp placeholder census is described as failing, not refusing** — it runs after the
  initializing commit, so it reports a bad result rather than preventing one.
- **`dev/RETIRED.md` is documented as a path your project creates**, not a file the kit ships.
- **The short name a creation tool takes now has a declared shape** — lower-case letters, digits and
  single hyphens between them, starting and ending with a letter or digit. Anything else is refused
  at the door, naming the position and the character, and is never silently rewritten. *The shape is
  the intersection of what a branch name and a file name both accept, because the short name travels
  into both; the failure it prevents is an ACCEPTED name that produces an illegal branch discovered
  later by someone who did not type it.*
- **Specification identifiers: the creation contract now states its one declared exception** — the
  specification creator derives its own id; every other creator still refuses without one.
  `id-minting.md` gains § Spaces and streams, which separates WHAT an id names from WHO puts the
  number there, says what makes the exception safe (one author on that stream, so no concurrency
  hazard), and says when it lapses.
- **The rigor-tier sheet fixes the SHAPE of the effort riders, not their names** — a default per
  tier, an escalation above it that needs sign-off, a floor nobody dispatches at. The named settings
  are your project's, recorded in `model-provisioning.md` § B.2.
- **The placeholder census's span is documented as a floor** — it covers the stamped role docs and
  templates, the directories the initializer itself writes. A value that travelled into a file
  outside them is your own search to run.
- **`process/**` travels unedited, and its declared blanks are now named** — each doctrine sheet's
  instance section, the manifest's debt list, the hygiene checklist's evidence column, and everything
  under `process/templates/`. Read the old row literally and you leave all of them empty.
- **The adapter template's House rules gain an attribution example**, carrying the instruction to
  name the mechanism that enforces it in the same line.

- **The graduation check now runs on projects that never ran `kit-init`.** It enables on any sign
  the repository has started — work items on the board, history in the running log, entries in the
  archive, or the initializer's receipt — and on a tree with none of those it reports that **the
  check did not run**, rather than implying the tree is clean.
- **`doctrine/fix-execution.md` § A.5b decides when a fix must be a MECHANISM and when a SENTENCE
  will do.** The rule: *a mechanism is owed where the act is IRREVERSIBLE, or where the failure is
  SILENT AND COMPOUNDING; everywhere else, prefer the sentence.* Two tests discharge it — *can
  this act be undone?* and *if this goes wrong, does anything say so, loudly and soon?* — and
  **the burden of proof sits on the mechanism**, because a sentence is cheaper forever and a
  mechanism nobody can remove is a cost every future reader pays. `doctrine/subagent-control.md`,
  `doctrine/live-resources.md` and `doctrine/orchestration.md` previously stated their own
  versions of this trade and now point at the one sheet instead. **No Action required** — nothing
  you run changes; this is a rule you read when deciding how to fix something.
- **The no-census rule now says where it does NOT reach.** An enumeration is a census when it is a
  **claim** about a set — a guard's list, a sentence's list. **A builder's list is not**: a
  fixture that creates six directories is not asserting six is all there are. When the role is
  unclear, ask which way a divergence fails — loudly and near the cause, or silently. **No action
  required.**
- **Six shipped scripts carry one consistent phrase for the prefix-authority rule, and the block
  no longer states its own size.** `new-prd.sh`'s header used a plural form of the phrase the
  others share, so the `grep` those scripts tell you is the list did not return it — and the
  closing line said "change all five" beside a command that returned five. Both are fixed
  together: the phrase is identical in all six, and the closing line now says the grep is the list
  rather than counting it. **Nothing to do.** If you have scripted against the old plural phrase,
  it is gone; the singular one is the rule's name everywhere.
- **`doctrine/staleness.md` § C now covers enumerations, not only digits.** *"Three outcomes: A, B
  and C"* is a census in prose and rots the same way *"18 contracts"* does. State the axes the
  members vary along, or point at the instrument whose output is the list. **No action required.**
- **`verify.sh`'s guard floor is now reconciled in both directions.** A new `GUARD_ENUM` seam
  beside `GUARD_SET` names how your project enumerates its guards **as that command sees them**;
  the scoped run reports declared-but-vanished (as before) **and guards that exist and were never
  enrolled** (new), refusing on either. `GUARD_ENUM` is **executed**, and its output is compared
  to `GUARD_SET` as literal strings — emit the same path shape the list uses.
- **The self-test suite no longer fails on a project that declared its own role set.** If you ran
  `kit-init.sh --roles` to name your project's roles, the suite's sandboxes inherited that set and
  then judged the suite's own fixtures against it — so `move-issue.sh`, `archive.sh` and
  `release.sh` cases failed for reasons that had nothing to do with those tools, in the one
  instrument whose job is to be believed. The sandbox now resets the role set to the one the kit
  ships, across the same three files `--roles` stamps, so the suite tests the kit's frame and your
  declared set is left entirely alone outside it. **Nothing to do** — re-run the harness. If you
  have edited the suite's own cases and used a role name your project does not declare, that name
  is now judged against the kit's shipped set rather than yours.
- **The self-test harness no longer reports a false failure on a project whose trunk has grown.**
  Its helpers for reading the trunk piped `git log` into `grep -q`; under `pipefail` the
  early-exiting reader made the producer die of SIGPIPE and that became the answer, so an
  assertion could report a commit subject missing when it was present. The effect scaled with
  history — invisible on a young board, near-certain past about twenty-five commits — and it could
  only ever produce a false red, never a false pass, so nothing was wrongly certified. **No action
  required.**
- **`scripts/hygiene/cold_signal.py` tells you why it cannot run, instead of raising.** It reads
  your working copy's own git history, so on a tree that is not a repository — an unpacked
  release, an export, a clone you have not `git init`-ed — it used to end in a Python traceback.
  It now says **could NOT RUN**, names the command it tried, quotes git's own message, gives the
  remedy, and exits 2. **The distinction it is protecting: this is not "no cold files"** — the
  instrument never ran, and an unrunnable check is an unknown rather than a clean result. With
  `--json` it prints an object saying it did not run, with **no** rows/files/bytes keys, so a
  consumer that ignores the exit status fails loudly rather than reading a zero. **Nothing to
  do**: on a normal repository the report is byte-for-byte what it was.
- **The kit's tooling floor is stated more precisely, and two extras are named deletable.** The
  floor read *"git and a POSIX shell, and nothing else"* — an absolute the tree already
  contradicted, because `scripts/hygiene/` is Python and `brainstorming` has an optional Node
  companion. What the kit **requires** is unchanged: git and a POSIX shell, for everything that
  gates. What is now said out loud is that the hygiene instruments are **Python 3, standard
  library only, advisory, and never a gate** — *delete the directory if your project forbids
  Python and you lose the measurements, not a gate*; `process/hygiene-checklist.md` states every
  shape in prose, so each is re-implementable in whatever you already run. Say so in your adapter
  if you do forbid it, the way the skill set already handles its one optional Node dependency.
  **Nothing to do**: no gate, command or refusal changed, and if you have been running the
  instruments they still run.
- **Some shipped files carry no `KIT-CLASS:` marker, and the convention now says so.** It used
  to read *"every script, role doc and process file carries a one-line marker"* and *"classify a
  file by opening it"* — with no exceptions stated, while three kinds of file had them. Now the
  rule names them and says where each one's class actually lives: **vendored skill directories**
  in the new `Class` column of `.claude/skills/README.md`'s provenance table, because updating a
  skill from upstream is a folder copy that would erase an in-file marker; **`process/KIT-VERSION`**
  nowhere, because its entire content is the value the release ritual reads; and
  **`.claude/settings.json.example`** in a `_KIT_CLASS` key, because JSON has no comment syntax.
  Nothing in your tree changes and nothing is reclassified — **the rule caught up with the tree**.
- **The pre-cut sweep is now a required step of the release ritual, not an advisory habit.**
  `contracts/release-ritual.md` § 2 requires it where a slate was minted from findings, with a
  named owner, before the version is written; § 3 refuses without it and § 4 item 6 makes it
  observable. **Required does not mean automated** — the sheet says why mechanizing it is held
  back. `MANUAL.md` and `EXTRACTION.md` no longer describe the hygiene checklist as *"advisory,
  never a gate"*: the **cadence** is advisory, the **sweep** is not.
- **`--json` on the hygiene instruments now carries the walk's blind spots**, the same ones the
  human output prints. `citation_index.py`'s payload changes shape to carry them: it was a bare
  array of rows and is now `{"blind_spots": […], "rows": […]}`. The other four instruments
  already emitted an object and simply gain a `blind_spots` key. **Nothing in the kit reads this
  output**, and the instruments are advisory — so this is a one-line notice rather than an
  action. **If you have written a consumer of `citation_index.py --json`, it reads
  `payload["rows"]` now.** That shape is stable from here: the wrapper was added while the
  consumer set was empty precisely so it would not have to be added later.
- **Every hygiene instrument now reports what its walk did not look at.** Until now **none of
  them did** — the five share one file walker, that walker narrows twice, and no report
  mentioned either narrowing. Both are now stated, on the human path and in `--json`, derived
  from the walker itself so a new narrowing reaches every report the day it is added: **symlinks
  are skipped** (a symlinked file is absent from the walk entirely, with the count of how many
  were skipped in that run) and **the directory names in `SKIP_DIRS` are pruned wherever they
  appear**, plus any `*.egg-info`. **No instrument's results change** — the walk is what it
  always was; what changes is that a clean report now tells you what it did not read. If you
  have edited `SKIP_DIRS`, the count in the line follows your set. **Whether the scanner should
  FOLLOW symlinks instead of skipping them stays open** — naming the skip is what makes leaving
  that open honest rather than silent.
- **`.gitignore` now ignores the hygiene instruments' Python bytecode.** `scripts/hygiene/` is
  Python, and a bare `python -c` import or a REPL session writes `scripts/hygiene/__pycache__/`
  beside it — residue that reddens a guard walking `scripts/` for `KIT-CLASS` markers while
  `git status` stays clean (`citation_index.py`'s own header). `__pycache__/` and `*.pyc` are in the
  kit's own section of `.gitignore`, not the FILL ME build-artifact section, because a cache written
  by a file the kit ships is not your build artifact. Nothing to do; if you have already edited your
  copy, add the two lines whenever you next touch it.
- **The self-test suite covers the day-one path the documentation prints.** `GIT-HOSTING.md` § 3
  step 2's first commit has no role prefix and runs with the hooks unwired — the state that made a
  correct install fail its own self-check. The suite now runs `kit-init` that way and asserts it
  succeeds, that the board check is not what fails, and separately that a **real** board finding
  still does fail it, so "tolerate more" can never quietly become "check nothing". **No action
  required.**
- **`finish-pr.sh` names the trunk on its green line.** The human-readable post-merge verify line
  now reads `PASS on <trunk>` as its FAIL sibling always did; the machine-readable
  `POST_MERGE_GATE: PASS|FAIL` pair is unchanged, so anything keyed on it keeps working. **No action
  required.**
- **Shipped scripts and workflow runners no longer cite the kit repository's change files.** Six
  comments and one prompt string handed to your agent at runtime referred to `change NNN` — a record
  that exists in no repository you have. Each now states the reason it stood for. The self-test
  harness carried the last of them, removed with the guard that now refuses the whole class at
  build time. **No action required.**
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

- **If your commit subjects begin with the word "Squash" without a role prefix, they will now be
  refused.** The exemption is narrowed to git's own `Squashed commit of the following:`; prefix such
  subjects, or use the documented override for an imported commit.
- **Creation now refuses a short name outside the declared shape.** If your automation passes slugs
  containing spaces, upper case, underscores, dots or slashes — or a leading, trailing or doubled
  hyphen — those calls now refuse, naming the position and the character, and create nothing.
  Previously a space was accepted and produced a branch name that is not a legal git reference,
  discovered later by someone who did not type it. **The name is never rewritten for you.** *This is
  the script-side behaviour line; the rule itself, and its wording, are covered by the contract's
  own release line.*
- **If you ran the initializer with `--roles` before this release, check your subtask tool.** It was
  outside the set of files the role set was stamped into, so its `--role` whitelist may still name
  the shipped roles and refuse yours. Re-running `--roles` stamps it.
- **Action required:** if you adopted via `SEED.md` step 2 **branch B** (you implemented the
  contracts in your own toolchain and never ran `kit-init`), the graduation report now runs
  against your published trunk and will list any shipped scaffolding you still carry. **Its
  findings are advisory** — they do not change the drift verdict and cannot fail a build. On a tree
  with no sign of having started, it says so: **the check did not run**, rather than implying the
  tree is clean.
- **The hygiene instruments now refuse instead of reporting, when their own blind-spot derivation
  comes back empty.** Every instrument exits **2** and prints `could NOT RUN … NOTHING was
  measured`; on `--json` it emits `{"unrunnable": {…}}` with **no data keys** — no `rows`, no
  `blind_spots`. **Action required:** if anything of yours consumes these payloads, key on the
  **exit code** or on the presence of `unrunnable`, not on the shape of the output — a consumer
  that reads `blind_spots` off the JSON will now raise a lookup error on a refusal instead of
  silently reading a clean bill. That is deliberate: these instruments are advisory, and the one
  thing an advisory tool must never do is report *nothing found* when it found nothing out.
  **Changed with this release:** the same refusal now reaches `reachability_walk.py --self-test`,
  which previously reported `SELF-TEST PASS` regardless of whether the walker could derive
  anything. If you run that arm in CI, it can now exit **2** — and when it does, the instrument is
  broken, not your tree.
- **Action required:** if your `GUARD_SET` is non-empty, **set `GUARD_ENUM`**. Until you do, the
  scoped run prints a note saying the second direction was not checked — it does not fail. **When
  you set it, expect the FIRST run to refuse — and to name why.** The likeliest cause is a
  **path-shape mismatch**: your enumerator emits `./tests/x` where the list says `tests/x`, and
  every declared guard then reads as unseen. The one the seam exists for is a **guard the
  enumeration lists that nobody enrolled**. Others are possible and the run names whichever fired,
  one at a time, with the next only after that one is fixed — **read the message rather than
  working from a list of causes, including this one.** Every narrowed run before now ran a floor
  only as complete as the list, with nothing detecting the shortfall — an earlier release had
  already made the banner say so; what was missing was the detection. Enrol each such guard in
  `GUARD_SET`, or narrow `GUARD_ENUM` if it is deliberately not a floor guard — either way, say
  which in the file.
- **Action required only if you audit classifications by grep.** If you have a check that greps
  `KIT-CLASS:` across `.claude/skills/` and expects a hit per directory, it was reporting the
  vendored skills as unclassified and it will keep doing so. Point it at the provenance table's
  `Class` column instead, or scope it to the paths that do carry markers. **If you have no such
  check, there is nothing to do.**
- **If you implement the release ritual yourself, the pre-cut sweep is a required step of it and
  owes a named owner.** You do not owe a script arm that checks it.
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
  **Superseded 2026-08-29 by the guard-floor reconciliation (`verify.sh`'s `GUARD_ENUM` seam, above):** the unguarded direction is no longer the price — the enumerator supplies the space the list is reconciled against, and the scoped run reports both directions where it saw something. The readability reason above stands and is why the list remained hand-kept.
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
  drift report in another stack now owes invariant 7. ~~One known limit, stated because it is
  measured: the arm is gated on the initializer's stamp receipt, so a project that implemented the
  contracts in its own toolchain and never ran `kit-init.sh` does not see the prompt — an open
  question, recorded.~~ **SUPERSEDED — the limit was closed; see the Changed entry above for the
  release that closed it.** The arm now enables on **any sign the repository has started**, the
  initializer's receipt being only one of them, so a project that never ran the initializer does see
  the prompt. *The struck text is kept because the limit was real and measured when written, and
  because it is the reason the enabling condition is what it is: what closed it was widening the
  signal, not removing the gate.*
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
carries its entry, and every entry that needs something from you is in this section.
**That reading covers the tree AS OF THAT REVISION AND NO FURTHER — entries have landed since, and
they are not inside it.** *An all-clear inherits the date it was taken, never the date it is read.
Re-take it at the cut rather than trusting this paragraph; a stamp that outlives its revision is the
same false assurance the entries above keep being about.* Nothing else above requires an
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
