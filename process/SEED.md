<!-- KIT-CLASS: KIT — the you-have-nothing front door. Travels unedited; it names no project. -->
# SEED.md — starting a project from nothing

**You have an empty directory and a sentence** (*"I want to build a new thing that does X, please
follow the `process/` package"*). This file is the **order of operations** — the sequence in which
nothing depends on something that does not exist yet.

**The honest form of that sentence: the kit runs from `process/` PLUS the copy-list `process/` names**
— **everything [`EXTRACTION.md` § 1](EXTRACTION.md)'s COPY table lists**, which is far more than
`process/`: `AGENTS.md`, `docs/README.md`, the whole of `.claude/`, the kanban script set, `setup.sh`
and `consumers/` among them. **And `PROJECT.md`, which that table does NOT list** — it is CONFIGURE
class (§ 2.5), the shipped sheet is the blank, and step 3 below cannot be done without it. Read § 1's
table and § 2's list, not this sentence's examples — because
every step below routes to something outside this directory. (Measured: a cold
reader took *"follow the `process/` package"* literally and bootstrapped without them.)

**This file is a ROUTER.** Every step names its **authority** — a `MANUAL.md` section, a contract
sheet, or a template — and the authority, not this page, is the law. If a step here ever disagrees
with its authority, the authority wins and this line is the bug report.

**The other door:** [`EXTRACTION.md`](EXTRACTION.md) is the **manifest** path — *"what travels, what
must be configured, and what is still in debt?"*. **SEED is the you-have-nothing path.** Both end
in the same place, and **[`scripts/kit-init.sh`](../scripts/kit-init.sh) serves both**: EXTRACTION
§ 1.3 runs it after the copy-list, step 2 below runs it after the same copy-list. You still need
the kit's files on disk — SEED does not conjure them; it tells you what to do *around* the copy.

---

## The eight steps

**The hat for day one.** Most of these steps commit before any issue exists, and every commit
after the first still carries a role prefix. The hat for those commits is a declared seam with a default:
[`contracts/role-gate.md`](contracts/role-gate.md) § 2a names the default, its span, and the
commits that fall outside it. The unpacked kit's first commit, made before the commit guard is
wired or under its escape, carries no hat. Code carries the hat that writes it, and the
initializer signs its own commits. If you wear a different hat, you owe step 8's file one line
saying which, and why.

| # | Do this | Authority — where the law actually lives |
|---|---|---|
| **1** | **Create the repo, the remote, and the remote's published default branch.** `git init -b <trunk>` — **`-b` names the trunk; a bare `git init` puts HEAD on `init.defaultBranch` and leaves you a branch nobody asked for** (`README.md` § Day one carries the reason) — then a remote (a **local bare repo is fine** and is the offline recipe), push the trunk, then `git remote set-head origin <trunk>` **naming the branch**. `<trunk>` defaults to `main`. | [`contracts/kanban-worktree.md`](contracts/kanban-worktree.md) (why the trunk must be *resolved*, not guessed) · [`contracts/initializer.md`](contracts/initializer.md) · [`GIT-HOSTING.md`](GIT-HOSTING.md) (local-only, bare-repo and hosted options) · `./scripts/kit-init.sh` prints the four-step recipe **on refusal** when the remote precondition is unmet (`--help` describes the precondition but does not print the recipe itself) · [`EXTRACTION.md` § 1.3](EXTRACTION.md) row 1 |
| **2** | **Fork by stack — see below.** Copy the kit files first (`EXTRACTION.md` § 1), *then* fork. | [`EXTRACTION.md` § 1](EXTRACTION.md) · [`contracts/initializer.md`](contracts/initializer.md) · [`contracts/config-seam.md`](contracts/config-seam.md) |
| **3** | **Fill in `PROJECT.md` IN PLACE.** The shipped sheet is itself the blank — there is no template to copy from, because a template a stamper never touches drifts from the instance it claims to be. It is the first thing the process asks for and the one thing no project can copy. | [`PROJECT.md`](../PROJECT.md) · [`MANUAL.md` § The three documents](MANUAL.md) |
| **4** | **Start `requirements/CORPUS.md` + `requirements/DECISIONS.md`** from the skeletons — both nearly empty on day one, both existing from day one. **And learn what ROUTES into the register before you need it:** every ruling, in the change that makes it ([`MANUAL.md` § Execution discipline](MANUAL.md) item 6). *This step said only "create it". A blind adoption then wrote the routing instruction into its own project sheet by hand at the previous step — thirteen minutes before the adapter at step 5 handed it the same instruction. The rule was never missing; it arrived after the step that needed it, and neither step 3 nor this one pointed at it.* | [`templates/CORPUS.skeleton.md`](templates/CORPUS.skeleton.md) · [`templates/DECISIONS.skeleton.md`](templates/DECISIONS.skeleton.md) · [`MANUAL.md` § Execution discipline](MANUAL.md) (item 6 — what routes into the register) · [`EXTRACTION.md` § 1.2](EXTRACTION.md) (format travels, content never does) |
| **5** | **REPLACE the `CLAUDE.md` bootstrap stub with your adapter.** The shipped `CLAUDE.md` is scaffolding that says so in its own first lines; you **build the adapter from the template and overwrite the stub**, rather than editing the stub into shape. Point at `process/MANUAL.md` early, then hold **your** project law. | [`templates/CLAUDE-adapter.template.md`](templates/CLAUDE-adapter.template.md) · [`MANUAL.md` § Seams](MANUAL.md) (what the manual deliberately does not know) · [`EXTRACTION.md` § The second axis: DISPOSITION](EXTRACTION.md) (why `REPLACE` is replaced and not edited) |
| **6** | **Hold a REAL PM session and mint `PRD-001`** — **one** spec, not a backlog. A pre-written backlog is a backlog nobody scoped. **This mandate is not in tension with the lite default:** `PRD-001` **scopes the PRODUCT** on day one; [`MANUAL.md` § The default path is lite](MANUAL.md) governs **subsequent small work**, which takes one issue and no spec. Both stand. | `.claude/roles/pm.md` · [`contracts/issue-creation.md`](contracts/issue-creation.md) · [`contracts/id-minting.md`](contracts/id-minting.md) · `.claude/templates/PRD.template.md` |
| **7** | **Drive the FIRST issue through the FULL Dev → QA boundary.** The boundary is the thing being installed; the first issue is where it is proven. Do not shortcut it because the change is small. | [`MANUAL.md` § The Dev → QA handoff (the boundary — 7 steps)](MANUAL.md) · [`contracts/verify-gate.md`](contracts/verify-gate.md) · [`contracts/board-mover.md`](contracts/board-mover.md) · [`contracts/landing-gate.md`](contracts/landing-gate.md) · [`contracts/commit-attribution.md`](contracts/commit-attribution.md) |
| **8** | **Run the session close ritual** — board matches reality, `progress.md` written, drift report clean, archive when it accumulates. **Then mint `process/LOCAL-PROCEDURES.md`** — see below; it is the closing step, not an optional extra. | [`MANUAL.md` § Session close ritual](MANUAL.md) · [`contracts/drift-report.md`](contracts/drift-report.md) · [`contracts/archive-sweep.md`](contracts/archive-sweep.md) |

---

## Step 2, in full — the stack fork

**Both branches are real, and neither is the lesser one.**

**A. Your stack can run the shipped shell scripts → run the initializer.** The mechanical path:

```bash
./scripts/kit-init.sh --prefix XYZ --trunk main      # + --roles / --gate-command as needed
./scripts/kit-init.sh --help                         # every option and the remote precondition
                                                      # (the four-step recipe itself prints on
                                                      # refusal, not from --help)
```

It stamps the seams, creates the board, wires the hooks and then **proves the result with a
self-check**. A second run **refuses**; so does a run against a repository that has already lived.

**`--gate-command` is for this run only, and that matters HERE because of the order of operations.**
A re-run refuses and there is no resume path, so a project extracting an existing tool — which may
not have settled its gate command by the time it stamps — cannot come back for the flag later. **Omit
it and declare your gates by hand in `scripts/verify.sh`'s `GATES` table instead.** That is a
supported route and not a fallback: what the landing gate requires is an **executable, committed gate
runner**, never that the initializer wrote it. What you must not do is skip both — the shipped frame
ships with an empty table that **refuses to run**, and the landing gate refuses to land without a
runner that does.
*(Authority: [`contracts/initializer.md`](contracts/initializer.md) — *configure, then prove*;
[`EXTRACTION.md` § 1.3](EXTRACTION.md).)*

**B. Any other stack → implement [`contracts/`](contracts/) in your own toolchain.**
**The contract sheets ARE the specification.** The shell in this kit is **one implementation, not
the requirement** — sections 1–5 of every sheet bind any implementation in any language; section 6
is the pointer to this repository's scripts and is marked as such. Take **no** script at all and
you still owe every invariant, every refusal condition, and every countable definition of green in
the sheets. (**How many sheets?** `find process/contracts -type f ! -name README.md | wc -l` — run it. **The exclusion is the point**: the index is a file in the directory it indexes, so the unfiltered count answers a different question and answers it one too high. Deriving is not enough on its own — the derivation has to count the thing the sentence names; a digit typed
here would be wrong the first time a sheet is added.) Any language, any task runner, any CI
config: the spirit is what transfers.
*(Authority: [`contracts/README.md`](contracts/README.md) — the index and the six-section shape.)*

This fork is a **ruling**, not a courtesy: *"the project need not use any particular language or
shell if they don't want to — but the spirit needs to be there."* Branch B is not *"you could also
roll your own"*; it is the supported route for every other stack, and `contracts/` exists to make
it followable.

---

## Step 8's closing act — mint `process/LOCAL-PROCEDURES.md`

**A home for LOCAL LAW.** Day one *will* produce resolutions this kit does not contain, such as
whether day-one scaffolding is exempt from the code-vs-metadata rule. Every one of those is a
**decision**, and with no home a decision becomes **tribal knowledge** — rediscovered independently
by the next worker, at full price, every time.

**One day-one question is now a SETTING rather than an open one:** which hat signs the commits made
before any issue exists. [`contracts/role-gate.md`](contracts/role-gate.md) § 2a answers it with a
default. **If you took the default, write nothing. If you did not, this file is where you say which
hat, and why**: the hat, the span it covers, and the reason. *This paragraph used to list that
question as open (which hat signs the very first commit, and when a hat can first be declared,
which [`contracts/role-gate.md`](contracts/role-gate.md) § 2 answers: declaring is always
permitted). The adoptions that met it did not agree, and each named a sound reason for its own
answer. When projects disagree for reasons that are each sound, a default with a recorded departure
removes the cost of every project deciding from scratch. The question still belongs here, but now
as a departure to record.*

Create it at close of day one, even if it holds two lines:

```markdown
# LOCAL-PROCEDURES.md — resolved kit contradictions, as law for the next worker

Each entry: **the contradiction**, **the resolution**, **the date**, and **who ruled**.
Not a diary and not a backlog — an entry earns its place by being something the next
worker would otherwise have to decide again.

- **YYYY-MM-DD — <the contradiction, in one line>.** Resolution: <what is now law>. Ruled by: <role>.
```

**Why it is a closing step and not an opening one:** on day zero you have no contradictions yet,
and a file of invented rules is worse than none. By the end of day one you have several — and you
will not remember them on day two.

*(Measured in the seed acceptance test: three agents independently rediscovered the same
workaround inside twelve hours, and the audit found a **third** convention that had accreted with
no friction entry at all — tribal knowledge growing inside a kit built to eliminate it.)*

### The one line to seed it with, if you will ever run agents in parallel

**Copy this in on day one, under a second heading, even if the register above is empty.** It is
not a resolved contradiction — it is the one standing obligation that **cannot be carried by a
session's opening instructions**, because the session that needs it most is the one that was never
given any.

```markdown
## Standing obligations — these bind EVERY session, including one nobody briefed

- **If you are working a queue while anyone else waits on you, write a one-line progress note
  at every job boundary and at least every `<interval>` — into `<the shared log or channel>`.**
  A note is not a question and it does not pause your work. You cannot be asked for it: an idle
  session cannot send anything, so silence from you is indistinguishable from work.
```

**Why it lives here and not in the prompt that starts a session.** An obligation delivered only at
session start **is a conversation citing itself** — the same reason `DECISIONS.md` exists rather
than a memory of what was agreed. It binds the session that heard it and evaporates at the next
restart, and the successor inherits the queue, the board and the repository but **not the prompt**.
Measured on one pair across one restart: eight unprompted notes before, none after, from a
successor that was working fine and simply did not know it owed anyone one. The doctrine — this
line is the worker's half, and the spawner's obligations sit beside it — is
[`doctrine/subagent-control.md`](doctrine/subagent-control.md) § A.15.

**Skip it honestly if it does not apply.** A project where no session ever waits on another does
not need the line, and adding it would be ceremony. **A project that runs agents in parallel and
skips it will not find out until a restart, which is the expensive way.**

---

## Why the order is what it is

Each of these fails **later and in disguise** if taken out of sequence:

| The rule | The failure if you break it |
|---|---|
| **Remote + a published default branch before the FIRST board move** (step 1 before step 7) | The trunk is resolved from a fallback chain; the board publishes to a branch nobody chose. |
| **Prefix stamped before the FIRST issue is minted** (step 2 before step 6) | Ids are minted under the kit's placeholder prefix; renaming them afterwards breaks every citation already written. |
| **A gate runner exists before the FIRST merge** (step 2 before step 7) | The landing gate has nothing to run; the first landing sets the precedent that landings are ungated. |
| **A real PM session before the first issue** (step 6 before step 7) | The project starts with a backlog nobody scoped, and the first issue's AC is invented by whoever picks it up. |
| **`PROJECT.md` before the first spec and the first issue** (step 3 before steps 6–7) | Almost every role doc says *"read PROJECT.md first"* — `architect.md` is the exception, naming it fourth in its own read order; without it each session re-invents the quality bar. |

---

## The templates

[`templates/`](templates/) — **fill-in-the-blank shapes, nothing more.** Blanks are `<angle
brackets>`, the same convention `.claude/templates/` uses. **These are hand-filled: the
initializer stamps `.claude/templates/`, not these**, so nothing here carries a prefix literal
for it to
rewrite — write your own prefix into the blanks as you fill them.

| Template | What it gives you |
|---|---|
| [`PROJECT.md`](../PROJECT.md) *(not a template — the shipped sheet IS the blank; fill it in place)* | its sections are its `##` headings — read them there rather than from a list here, which is how this row went stale twice |
| [`CLAUDE-adapter.template.md`](templates/CLAUDE-adapter.template.md) | the adapter shape: point at `process/MANUAL.md` early, then hold your own project law |
| [`KIT-FEEDBACK.skeleton.md`](templates/KIT-FEEDBACK.skeleton.md) | the OUTWARD channel: what this project learns that the kit should know. Copy to `process/KIT-FEEDBACK.md` on day one and leave it empty — the entries worth sending are the ones you notice in week one and cannot reconstruct in week three |
| [`CORPUS.skeleton.md`](templates/CORPUS.skeleton.md) | the corpus manifest shape + its bucket classification |
| [`DECISIONS.skeleton.md`](templates/DECISIONS.skeleton.md) | the standing-rulings register: stable ids, three fields, a projection |
| [`progress.skeleton.md`](templates/progress.skeleton.md) | the exact `## Log` + dated-`###` shapes **the drift report's § Log arm and the initializer's already-lived probe require** — both scan to the next `##` and stop, so a `##` dated entry terminates the section it should sit inside. *(The log rotation is the one tool that would accept `##`; it does, deliberately, so that a project which already wrote it is not stranded — and it does not recommend it.)* |
| [`CAPTURE.template.md`](templates/CAPTURE.template.md) | the measured-truth capture: verdict · endpoints · budget/pacing · verbatim codes & bodies · teardown proof · **what this does NOT establish**. Evidence-ledger class — copy it next to the capture files, not into `requirements/` |

The CORPUS and DECISIONS skeletons state a **pattern vs instance** split at the top: what is
**format law** (and travels) versus what is one project's **content** (and never does).
`progress.skeleton.md` draws the same line in its own vocabulary instead — *"TWO SHAPES BELOW ARE
REQUIRED, NOT STYLISTIC"*, and fill the blanks but keep everything else byte-for-byte — so do not
go looking for that phrase there. *This said "Each skeleton", which was true of two of the three.*

**Two more shapes sit beside them for orchestrated work** —
[`launch-pack.template.md`](templates/launch-pack.template.md) (the brief that authorizes a
multi-issue run) and [`run-report.template.md`](templates/run-report.template.md) (what closes
one). You do not need either on day one; reach for them the first time a run spans more issues
than a single session can hold.

**And a second pair, for a dogfooding round** —
[`round-pack.template.md`](templates/round-pack.template.md) (the **pre-registration**: the
question, the scenario matrix, the instruments with their blind spots, the budget) and
[`round-report.template.md`](templates/round-report.template.md) (the findings, the positives, and
the round's own defects). **A run delivers work; a round measures how the delivered thing is met** —
[`MANUAL.md` § The measurement rituals](MANUAL.md) and
[`doctrine/dogfooding.md`](doctrine/dogfooding.md). Not a day-one concern either: reach for them when
you want to know how a stranger meets what you shipped.

---

## Day one is done when

- `./scripts/check-board.sh` (or your stack's drift report) is **clean**;
- `process/KIT-FEEDBACK.md` **exists and is empty** — copied from the skeleton, not written yet.
  It is the one document that flows back to whoever gave you this kit
  ([`doctrine/distribution.md`](doctrine/distribution.md) § A.8). *Create it on day one precisely
  because you have nothing to put in it yet: the findings worth sending are the ones you notice in
  week one and cannot reconstruct in week three;*
- your gate runner is green and **committed**;
- `PROJECT.md`, `CLAUDE.md`, `CORPUS.md`, `DECISIONS.md`, `progress.md` all exist and are yours —
  and **`CLAUDE.md` and `README.md` have been REPLACED, not edited**: neither still carries the
  `BOOTSTRAP-SCAFFOLDING` line the shipped copies ship with;
- **every file's disposition is discharged** — no `FILL` file still holds an `<angle bracket>`, and
  every `DELETE-IF-UNUSED` directory has been either removed or kept **on purpose**, which is a
  decision you record rather than a question you leave open. The axis and its members are
  [`EXTRACTION.md` § The second axis: DISPOSITION](EXTRACTION.md); this bullet is that list, read as
  a checklist;
- `process/LOCAL-PROCEDURES.md` exists and holds **every kit contradiction day one resolved**
  (step 8's closing act — two lines is a pass; zero means they went into someone's head) — **and,
  if sessions here will ever run in parallel, the standing-obligations line step 8 seeds**, because
  that one cannot be carried by a prompt;
- **one** issue has gone `todo → in_progress → dev_complete → qa_complete` with its evidence in its
  own Activity log.

Anything less and the process is installed but unproven — which is the state this kit is written
against. *Every finding in this kit's own cold-read review was found by reading; all of them would
have been found by running.*
