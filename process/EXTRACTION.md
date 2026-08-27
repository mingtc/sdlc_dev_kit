<!-- KIT-CLASS: KIT — the kit manifest. Names an installation's files ONLY as configuration seams. -->
# EXTRACTION.md — the kit manifest

**What travels, what you must configure, what is pinned in place, and what is still in debt.**
Read this **before** lifting this kit into another repository, and read it again when you re-cut a
kit **out** of yours.

**The premise, and the other door.** This file is the **manifest**: *"here is a working kit — what
do I copy, what do I edit, and what will bite me?"*. If instead you have **nothing but an idea and
an empty directory**, read **[`SEED.md`](SEED.md)** — the **you-have-nothing** path, an order of
operations where every step points at its authority. **`scripts/kit-init.sh` serves both doors**:
§ 1.3 below runs it after this file's copy-list, and SEED's step 2 runs it after the same one.

**The honest summary:** the process is **copyable and no longer clean-by-assertion.** Sections 1–3
are the manifest; **section 4 is the debt**, and it is the most useful part of this file — a
manifest that claims a separation it does not have costs the next extractor a day of confusion.

**Prior art: this kit has now moved twice.** It was first cut out of one project into a second,
where it grew the contracts, the doctrine sheets and the initializer. This tree is the **third**
installation and the first one cut deliberately as a **seed** rather than as a donor copy: the
project it came from is referred to throughout as *the donor project*, anonymously, and every
lesson it paid for is kept while every one of its identifiers, paths and product facts is gone.
That is the transferable lesson of a second move, and it is worth stating before section 4: **the
debts that survived the first move were, almost without exception, the ones nobody had written
down as debts.**

---

## The one file classification convention

Every script, role doc and process file carries a one-line marker in its own comment syntax:

```
# KIT-CLASS: KIT|MIXED|PROJECT — <one-line reason>. See process/EXTRACTION.md.
<!-- KIT-CLASS: … -->     (markdown)
```

`KIT` = travels unedited · `MIXED` = travels, but carries project law you must edit ·
`PROJECT` = does not travel. **Classify a file by opening it**; this manifest can drift, the
marker in the file cannot be missed.

**In this seed almost everything is `KIT`, and that is a fact about the seed, not a boast.** The
seed *is* the kit: it holds no product. `MIXED` here means *"the frame travels, the contents are
yours"* — the gate runner, the attribution hook, the release script, the self-test harness. As soon
as you fill in `PROJECT.md` and `CLAUDE.md`, **those two are `PROJECT`-class by nature**: they are
the only files in the tree that never travel anywhere. Mark them so, and re-mark honestly as your
own files accrete. A marker that says `KIT` over a file carrying your product's law is worse than
no marker.

## The one rule about counting

**A census number written in prose is exactly the kind of claim that rots.** The donor project
proved it twice in the same file: a row of this very manifest said *"61 today"* over a component
list that itself summed to **62**, while two sections below, a harness's own case count had
*already* drifted from the **35** stated there to the **39** a fresh count returned. Three wrong
numbers, in the file whose entire job is to be true when read.

**So this manifest carries no census numbers.** Run the command; its output is the only digit that
is ever correct:

```bash
grep -rl "KIT-CLASS:" scripts setup.sh .claude/roles process | wc -l   # every classified file
find scripts -type f | wc -l                                          # scripts/ (every file marked)
find .claude/roles -type f | wc -l                                    # role docs
find process -type f | wc -l                                          # process/ itself
find process/doctrine -type f | wc -l                                 # doctrine sheets
find process/contracts -type f | wc -l                                # contract sheets + the index
find process/templates -type f | wc -l                                # templates
```

The rule generalizes past this file, and it is doctrine:
[`doctrine/staleness.md`](doctrine/staleness.md) § C — **derive, date, or do not state.** Where a
number appears anywhere below, it is either the direct output of a command stated beside it, or it
names the guard whose job is to keep it honest.

---

## 1. COPY — take these as they are

| Path | What it is |
|---|---|
| `process/MANUAL.md` | The transferable operating manual. Adopt unedited. |
| `process/SEED.md` | The you-have-nothing front door. Adopt unedited; it names no project. |
| `process/GIT-HOSTING.md` | Local-only, bare-repo and hosted-forge options. The kit assumes **git**, not a forge. |
| `process/doctrine/` | Process doctrine. **Every sheet states its own pattern/instance split at the top; obey it** — § A (or the sections it names) travels, and the instance section is a **blank you fill**, not an example to keep. `find process/doctrine -type f` lists them; the doctrine table in `MANUAL.md` is the index, and a new sheet joins that table **in the same change** that creates it. |
| `process/contracts/` | **The gate contracts — one sheet per gate plus an index.** Per gate: purpose, hard invariants, refusal conditions, what green means, minimal interface, and a pointer to *one* implementation. **This is the route for an adopter who takes NONE of the scripts:** you still owe every invariant in these sheets. Adopt unedited — they name no language, no flag and no path outside their sixth section. One sheet describes no script at all: `acceptance-tier.md`, whose reference implementation is deliberately **non-travelling**. |
| `process/templates/` | Fill-in-the-blank shapes. **Hand-filled** — the initializer stamps `.claude/templates/`, not these, so they carry no prefix literal. Blanks are `<angle brackets>`. |
| `process/hygiene-checklist.md` | The shapes an advisory hygiene pass looks for, plus two ratchet rules and the anti-pigeonhole reservation. The shapes travel with their **evidence columns blank**. |
| `process/EXTRACTION.md` | This file. Update its § 4 as you pay the debts down, and **add the debts you discover** — that is ratchet rule 1 applied to a manifest. |
| `.claude/roles/` | The role docs. Split `KIT` vs `MIXED` — `grep -l 'KIT-CLASS: KIT' .claude/roles/*.md` versus the same for `MIXED`; see § 4.2. |
| `.claude/skills/` | The named practices, one directory each, plus an index. |
| `.claude/agents/` | Leaf-worker agent definitions — **this is where the model/effort ladder's defaults physically live** ([`doctrine/model-provisioning.md`](doctrine/model-provisioning.md) § B.1). |
| `.claude/workflows/` | The serial and paired multi-issue runners. |
| `.claude/templates/` | **MIXED, not COPY.** The item templates travel, but only after `kit-init.sh` stamps them — and § 4.6 states exactly how far the stamp reaches. |
| **The kanban script set** — § 1.1 | The executable half of the kit. |
| `setup.sh` | **MIXED**: the frame is the kit's, the language runtime is yours. See § 1.1. |
| `consumers/` | **OPTIONAL, and delete it if it does not apply.** The thin machinery for the case where something else vendors your project, governed by [`doctrine/distribution.md`](doctrine/distribution.md). **If your project ships to nobody, remove the directory** — an unused distribution surface reads as a promise. |

**`.claude/settings.json.example` is CONFIGURE, not COPY** — § 2.8.

### 1.1 The kanban script set

Every category below is named **exhaustively**, so counting its own list is the census — no
subtotal is stated separately (§ The one rule about counting).

**Bootstrap (KIT):** `kit-init.sh` — **the executable initializer; run it first.** It stamps the
seams, creates the board, wires the hooks, then **proves** the result with a self-check. § 1.3 is
written around it.

**Board + item lifecycle (KIT):** `config.sh` · `check-board.sh` · `move-issue.sh` ·
`finish-pr.sh` · `new-issue.sh` · `new-bug.sh` · `new-refactor.sh` · `new-prd.sh` · `next-id.sh` ·
`subtask.sh` · `archive.sh` · `archive-progress.sh`

**Machinery + hooks (KIT):** `lib/kanban-worktree.sh` · `lib/push-retry.sh` ·
`hooks/require-role.sh` · `hooks/session-start.sh` · `githooks/applypatch-msg` (it delegates to
`githooks/commit-msg`, which is MIXED — the table below — because the role-set membership it
enforces is stamped)

**Notifications (KIT, all no-ops until configured):** `notify.sh` · `notify-hook.sh` ·
`notify/<channel>.sh`

**Advisory instruments (KIT, never a gate):** everything under `scripts/hygiene/` — they read the
tree, print a report, and change nothing. Described by
[`hygiene-checklist.md`](hygiene-checklist.md).

**Take but EDIT (MIXED)** — these are the four files an adoption actually has to touch:

| File | The kit half | Your half |
|---|---|---|
| `githooks/commit-msg` | write-time enforcement, closed set, instructive refusal | the **membership** of the role set (the initializer stamps it) |
| `verify.sh` | one runner, fixed order, one summary block, the narrowed mode and its unskippable floor | the **declared gate table** and the floor's membership |
| `release.sh` | preflight → bump → attributed commit → annotated tag → push → publish, and the refusals | which files carry the version, which documents are required, whether anything is published at all |
| `test/run.sh` | the throwaway sandbox with its own publication target, three-way accounting, capability probes, the test-only marker | any case family that pins **your** facts |
| `setup.sh` | the shape: environment → install → gate → hooks path | **everything about your language runtime** |

**Run `./scripts/test/run.sh` right after extraction.** Its own summary prints its
passed/failed/skipped counts; an independent count of its defined cases must agree. The families
that pin an installation's own facts are the ones expected to redden first — that is the harness
working, not a broken extraction.

### 1.2 The board itself

`progress/` (the status folders + `history/`), `progress.md`, `ARCHIVE.md` and `requirements/`
are **shape, not content**. Copying another project's items is never right — but *"create them
empty"* is wrong in two ways an adopter only discovers by failure; § 1.3 states both.

**Copy the FORMAT, not the content.** Two `requirements/` documents are **format templates**, and
saying so is what stops them reading as *not part of the kit*:

| Path | What travels | What does not |
|---|---|---|
| `requirements/CORPUS.md` | The **shape**: a north-star statement, an enumerable manifest, a bucket classification for every root document and top-level directory, and a precedence clause. | Every entry. |
| `requirements/DECISIONS.md` | The **shape**: permanent ids that are retired rather than reused; each entry exactly *current ruling / one line of why / provenance*; the register as a **projection** of current state, with history in the ledger. | Every ruling. |

You do not have to imitate them by hand: both are shipped as blanks —
[`templates/CORPUS.skeleton.md`](templates/CORPUS.skeleton.md) and
[`templates/DECISIONS.skeleton.md`](templates/DECISIONS.skeleton.md) — beside
[`templates/progress.skeleton.md`](templates/progress.skeleton.md), which is § 1.3's `progress.md`
shape for an adopter not running `kit-init.sh`.

### 1.3 Day one — RUN THE INITIALIZER

```bash
./scripts/kit-init.sh --prefix XYZ --trunk main            # add --roles / --gate-command as needed
./scripts/kit-init.sh --help                               # every option + the refusal recipes
```

**Copy the files in § 1 first, then run this.** `kit-init.sh` is **configure-only** — it does not
copy the kit (there is no `--from` mode: the copy-list is authored here, and a second executable
copy of it would drift). Its preflight names any copy-list file still missing and refuses.

It performs every precondition in the table below, then **proves them** with a **self-check** that
mints a scratch item, moves it through two columns, asserts the drift report clean, and has a real
commit **rejected** by the attribution hook — the whole point being that *every finding in this
kit's cold-read review was found by reading, and all of them would have been found by running.*
Four behaviours worth knowing before you run it:

- **The trunk is confirmed, never inferred.** `--trunk` is required and is cross-checked against
  the remote's published default branch; a disagreement refuses. `<trunk>` defaults to `main`.
- **It guides the remote, it does not create one.** No remote / no published default branch /
  unborn HEAD ⇒ refusal **with the four-step recipe**, whose step 1 is the local bare-repository
  recipe for an offline project ([`GIT-HOSTING.md`](GIT-HOSTING.md)). Creating a remote is a
  repository-topology decision an initializer must not make for you.
- **It runs a placeholder census on its own output and refuses a non-zero result**
  ([`contracts/config-seam.md`](contracts/config-seam.md) § 4.3). The promise *"the travelling
  files are clean"* was believed by three readers and checked by nobody, once. Now it is measured.
- **A second run refuses.** It names what is already stamped and writes nothing — a half-stamped
  repository is the worst outcome available, so there is no resume path. The same rule protects any
  repository that has already lived.

**The manual sequence below is the FALLBACK**, and it is still the authoritative statement of
*what* must be true — read it if you are adopting into a stack that cannot run these scripts, or if
you want to know what the initializer is doing to your repository. **A non-shell adopter's route is
[`contracts/`](contracts/)**; the initializer's own contract is
[`contracts/initializer.md`](contracts/initializer.md).

| Precondition | Performed by | Why |
|---|---|---|
| **A remote exists and publishes a default branch** — `git remote add origin …`, push the trunk, then `git remote set-head origin <trunk>` (name the branch: asking the remote for its own HEAD fails against a freshly created bare repository). Do it **before** the first board move. | *guided, not automated* — the initializer's preflight refuses with the four-step recipe, then **confirms the trunk** and prints it. | The trunk resolution is a fallback chain, and a chain that ends in a literal cannot warn. With no published default branch a fresh repository silently gets **somebody else's** trunk name, and you find out when the first board move pushes to a branch nobody meant. |
| **A keep-file in every `progress/` folder.** | **the initializer's board step** — it creates one per folder and then **asserts the count**, derived from the declared folder set, never a hand-typed digit. | Version control does not track an empty directory, so a fresh clone has no board folders — and the board mover **aborts** when its target container is missing. *"Create them empty"* does not survive a clone; a keep-file does. |
| **A `progress.md` skeleton** — a `## Log` heading, under which each session's entries sit beneath a dated `### YYYY-MM-DD [Role] <title>` boundary. | **the initializer's board step** (an existing `progress.md` without a `## Log` heading is an error, not a silent pass). It writes the archive-index stub with its exact heading in the same step. | The drift report probes for the heading before it can report the log's size; the log rotation splits the file on the dated boundaries. **One** skeleton, both consumers. |
| **A gate runner written before your FIRST merge** — not "eventually". | **`--gate-command "<cmd>"`** declares your gate: it **fills** the shipped frame's empty `GATES` table with `<cmd>` as the first record, or writes a minimal runner if no `scripts/verify.sh` exists. Without the flag an existing, executable gate runner is a **required** precondition and its absence refuses — but the shipped frame **refuses to run while its table is empty**, so omit the flag only after declaring your gates by hand. It never overwrites a declared table. | The landing gate **refuses to land** when the gate definition is missing, not executable, not tracked at the revision being landed, or locally modified. A hard landing precondition, not a recommendation. |
| **The hooks path points at the kit's hooks**, and the auxiliary checkout plus the session-role file are ignored. | **the initializer's hook-wiring and ignore steps.** The self-check then **proves** the wiring by making a real prefix-less commit and requiring it to be **rejected**. | Without the wiring the role guard never fires and the audit trail erodes silently. Without the ignore entries every board move leaves the tree looking dirty — and versioned session state reaches a landing gate as a merge conflict over a fact nobody was collaborating on. |
| **The initialized tree is COMMITTED AND PUSHED to the trunk** before the first board move. | **the initializer's commit step.** | Every kanban operation runs inside the auxiliary checkout, which is reset to the published trunk on each operation. A board that exists only in your checkout is invisible to the board mover. |

---

## 2. CONFIGURE — the seams, with their real knobs

### 2.1 `scripts/config.sh` — read the file; these are its knobs

| Knob | What it controls |
|---|---|
| `ISSUE_PREFIX` | The prefix in item filenames and headers — `${ISSUE_PREFIX}-001-<slug>.md`. Used by every creating script and by the archive sweep. **Changing it takes effect on the next invocation; existing files are NOT renamed** — history keeps the identifiers it was born with. |
| `PRD_PREFIX` | The spec prefix. The default is fine for most projects. |
| `validate_issue_id()` | The shared read-only guard: requires an id, enforces the declared shape, hard-errors on an id already live, and **warns** when the id appears only in the archive. Creating scripts are deliberately **stateless** — the caller supplies the number, and `next-id.sh` suggests it. |
| The publication remote | Every fetch / push / remote-ref operation in the auxiliary checkout goes through it. Override for a fork or mirror workflow with a one-off environment value. |
| The **trunk** | *not a variable* — **a resolution chain**, and its last step cannot warn. The initializer therefore **confirms** it up front (§ 1.3, row 1) rather than letting the chain decide. |

Every knob is a `${VAR:-default}`, so a one-off run can override without an edit.

**The substitution keys on the HEADER KEY, never on a donor-shaped value.** A substitution that
matches nothing fails *silently*, and every created item then carries the template's example
identifier under a real-prefix filename — which is how one project produced a whole board its own
drift report flagged. This is contracted in
[`contracts/issue-creation.md`](contracts/issue-creation.md) § 2.

### 2.2 The status folder set

The lifecycle is the set of directories under `progress/`: `todo`, `in_progress`,
`dev_complete`, `qa_complete`, `blocked`, `done` (+ `history/` for the rotated log). The set is
read by the board mover's target validation, the drift report, the archive sweep and the landing
gate. **It is a seam; check whether your copy makes it a variable** (§ 4.5).

### 2.3 The gate command

`scripts/verify.sh` is the **single invocation** every role uses (*"no role re-derives commands from
prose"*). Its *shape* is the kit's; its *content* is yours. Replace the **declared gate table** and
keep the frame, including the always-on floor that a narrowed run cannot switch off.

### 2.4 The role set — more places than the adapter's two tables

Two tables live in the **adapter** and must agree with reality: the role set (one row per role doc)
and the commit prefixes (one row per legal tag). But **several files carry the role set** — the
table below is the list, and the table is the count — and naming only the adapter's two is how a set
drifts: one project had the attribution hook accept a role the board mover
did not, so the seat that held it **could not move a card** and had to borrow another hat.

| File | What it holds | Note |
|---|---|---|
| The adapter (`CLAUDE.md`) | The human-readable role table + the commit-prefix table | The source of truth a reader consults |
| `scripts/githooks/commit-msg` | The expression the hook enforces | Kept as a named variable **on its own line** so it can be *derived*, never re-hardcoded |
| `scripts/move-issue.sh` | The acting-role whitelist, plus the same list in its usage text and its error messages | A role missing here cannot move the board **at all** |
| `scripts/check-board.sh` | The attribution scan — it **derives** the set from the hook, with a literal fallback | **Preserve the derivation**; the fallback is the part that drifts, so correct *it* |
| `scripts/subtask.sh` | The acting-role whitelist on its `move` arm | Validated **before** any mutation: an unvalidated role reaches the commit subject, the hook rejects it mid-operation, and the git-mv plus the Activity append are left uncommitted in the shared kanban worktree that the next board op `reset --hard`s |

Change one, change them all — **and the row count is this table, never a number in the prose above
it.** An earlier version of this heading said "FOUR places", which was true when it was written and
false the first time a fifth reader was added; the sentence that names a count is the one that rots
(`doctrine/staleness.md` § C). Contract: [`contracts/config-seam.md`](contracts/config-seam.md).

### 2.5 The two project files the kit points at

The manual names no filenames except through these two roles:

| Role | This kit's default | You supply |
|---|---|---|
| **The project doc** — what the project is, stack, quality bar, binding gates, credentials | `PROJECT.md` | Your equivalent. |
| **The project adapter** — the project's own law, the role set, the prefix table, the code-path definition | `CLAUDE.md` (the harness reads this filename) | Your adapter, pointing at `process/MANUAL.md` in its first paragraph. |

### 2.6 What counts as CODE

The one definition the manual cannot supply: which paths make a change *"code"* (branch + landing
gate) rather than *"metadata"* (direct to trunk). State yours in the adapter — **mechanically, as
globs** — because a boundary you can compute with one `git diff --name-only` is a boundary that
survives a busy session.

### 2.7 Notifications

Off by default. Set the backend (and its credentials) in the environment file and add the
notification hook from `.claude/settings.json.example`. Adding a backend = one script beside the
example channel adapter.

### 2.8 `.claude/settings.json.example` — CONFIGURE, not COPY

It is the opt-in harness hook wiring (the role gate, the session-start clear, notifications) — the
*mechanism* travels, but a copied-as-is settings file authorizes the wrong things in your
repository. Four values inside it are yours, and one of them is a **fifth** statement of the role
set — keep it in step with § 2.4's four:

| Value inside the file | Replace with |
|---|---|
| The trunk name | Your `<trunk>` |
| The code-path globs (in both the *allowed metadata* list and the *forbidden direct-push* list) | Your § 2.6 answer, verbatim |
| The two project filenames (cited as the rules' authority and listed among the pushable paths) | Your two files (§ 2.5) |
| The role-prefix list in its prose | Your role set |

### 2.9 The drift-report thresholds

Two bounds the drift report needs: the depth at which the reviewed-and-done column is *due for a
sweep*, and the byte size at which the running log is *due for rotation*. Both are named constants
at the top of the reference implementation — a seam, not a contract term — and **are not repeated
here as digits.** Read them from the file. The log-size one is deliberately reused as the index
trigger in [`doctrine/lookup-tables.md`](doctrine/lookup-tables.md) § A.1, so that one idea does
not carry two numbers.

---

## 3. PATH-PINNED — deliberately NOT moved

| Path | Why it stays exactly there |
|---|---|
| `.claude/**` (roles, skills, agents, workflows, templates, the settings example, the session-role file) | **Harness-mandated.** The agent harness reads this path: hooks are wired from its settings file, the role gate reads the session-role file, skills and agents are discovered by directory. Moving any of it under `process/` **breaks the harness**, so the kit classifies it with an in-file marker instead. |
| `scripts/**` | **Reference stability.** Every role doc, every hook, every template and the manual itself cite `./scripts/…` — hundreds of pointers whose only job is to be typeable and searchable, and the hooks path is configured relative to it in every worktree. Relocating the tree buys a tidier listing and invalidates every citation. **Do not "tidy" this.** |
| `progress/`, `progress.md`, `ARCHIVE.md` at the repository root | The board is meant to be seen on a plain listing and rendered by a forge at the root; the scripts resolve it from the root. Root placement is the feature. |
| `requirements/` at the repository root | The **directory** is path-pinned project content, for the same root-placement reason — but the two documents it holds define **formats that travel** (§ 1.2). Path-pinned and partly-COPY are not in tension once said in one place; they were in tension when said twice, separately, in a previous copy of this manifest. |

---

## 4. THE DEBT LIST — what is still entangled in THIS seed

**These are known, unpaid, and honestly stated.** None blocks an adoption; each costs the adopter
an edit they must be told about. **Every entry is phrased as a property you can CHECK in your own
copy**, because a debt list that describes somebody else's tree is the same defect as a transcribed
census.

### 4.1 (PAID) — commit hygiene is doctrine now
The adapter's house rules used to hold *"no generated co-author trailers"* and the
hand-commit-then-read-the-status ritual, which meant **rules every adopter wanted lived only in the
one file that never travels**. They are now
[`doctrine/commit-hygiene.md`](doctrine/commit-hygiene.md). **What remains yours:** subject *style*
only. **Check:** your adapter's house rules should *point* at that sheet, not restate it.

### 4.2 Some role docs are `MIXED` — kit workflow wearing project law
An implementer/reviewer role doc naturally accretes project-specific duties **inside** its
Definition-of-Done and review checklists, and a seat contract is written around one project's gates
and release policy. They are genuinely transferable **workflows** wearing project **law**.
**Half paid:** the adapter template now ships a named **"Project duties — filled by the adapter"**
block, so there is a home for them. **The residual:** whether every role doc *points* at that block
instead of inlining its own list.
**Check:** `grep -c 'Project duties' .claude/roles/*.md`, and read any Definition-of-Done item that
names a file your project does not have.
**Cost if unpaid:** an adopter inherits checklist items citing files that were never delivered.

### 4.3 (PAID) — the gate runner's seam
The kit shape (one runner, uniform invocation, one summary block, a narrowed mode with an
unskippable floor) and the concrete gates used to be interleaved in one file with **no seam**.
The gate set is now a **declared table**, separate from the frame that runs it, and the separation
is a hard invariant on the sheet
([`contracts/verify-gate.md`](contracts/verify-gate.md) § 2).
**Check:** you should be able to replace every row of that table without reading the frame below it.

### 4.4 The kit's own guards do not travel — and this is the largest live debt
The process's own drift guards — *the adapter's role table matches the role docs*, *the prefix
table matches the hook*, *every travelling script has a contract sheet and every sheet's
implementation exists*, *the gate runner reports the suite it ran*, *the release script refuses to
tag an undocumented version*, *the retained-evidence index is complete in both directions* — are
**process enforcement written in the project's own test path**. They cannot travel, so **an adopter
receives the rules without the guards.**
**Cost:** you rewrite them in your own runner, or you accept unguarded process docs.
**The honest ranking, cheapest and highest-value first:** (1) the contracts-both-ways guard — a new
gate with no sheet, or a sheet whose implementation is gone; (2) the role-set agreement across
§ 2.4's readers (the table there is the count); (3) the retained-index reverse leg (every index link resolves on disk).
**Partial mitigation that DOES travel:** `scripts/test/run.sh` self-tests the *scripts*, and the
acceptance tier's three floor-guard assertions are specified in
[`contracts/acceptance-tier.md`](contracts/acceptance-tier.md) even though its implementation
cannot be.

### 4.5 The status folder set may be a seam without a variable
The configuration seam parameterises the *prefixes*; whether it parameterises the *lifecycle* is
the thing to check. If it does not, renaming or adding a state (say, a `review` column) means
editing the board mover, the drift report, the archive sweep and the landing gate by hand.
**Check:** `grep -rn 'qa_complete' scripts/ | wc -l` — a handful of hits in one declared list is a
seam; a scatter across four scripts is this debt.
**Cost if unpaid:** four scripts edited, by hand, per lifecycle change.

### 4.6 The initializer's stamping reach is not total
The initializer stamps the configuration seam, the item templates and the role docs. Whether it
reaches `.claude/agents/` and `.claude/workflows/` — which contain illustrative ids, trunk names
and gate-command examples of their own — is the thing to check, and historically it did not.
**Check, after running the initializer:** `grep -rnE '<PREFIX>|<trunk>|XYZ-[0-9]' .claude/agents .claude/workflows`
should return nothing that reads as a live value rather than an illustration.
**Cost if unpaid:** a search-and-replace pass plus a read of the two runners.
**Note the honest sub-case:** a *provenance citation* of the form *prefix-number* attributing a
lesson is a **citation, not a value**, and rewriting it would manufacture a reference your history
never had. The census reports those and leaves them
([`contracts/config-seam.md`](contracts/config-seam.md) § 4.3).

### 4.7 Notification configuration shares the project's environment file
The channel's credentials live in the same ignored environment file as the project's own secrets,
and the kit's docs name that file by convention. Harmless, but it means the kit reaches into a file
whose policy is the project's.
**Cost:** none if you already have an environment file; state the variable in your own credential
doctrine. Separating them is an improvement on the kit, not a departure from it.

### 4.8 Kit files still cite an installation's filenames
The configuration seam's header and several script headers point at `CLAUDE.md` / `PROJECT.md` by
name. These are *tolerated* pointers: § 2.5 names those two files as configuration seams, which is
the only licence a kit file has to know an installation's filenames.
**Cost:** rename your adapter and these headers read stale.
**One related smell, stated rather than hidden:** `MANUAL.md` points at the orchestrator **role
doc** for the rigor-tier ladder — so one piece of process doctrine lives in a role doc rather than
in `process/doctrine/`. It is a real inconsistency; promoting it is its own work item, and the
pointer is correct in the meantime. **PAID 2026-08-21 at the PM's word:** the ladder now lives at `process/doctrine/rigor-tiers.md`; the role doc keeps only the run-plan duties that apply it and points there.

### 4.9 (PAID) — the degraded-path second default
Several scripts used to carry their own hard-coded prefix literal as a defensive fallback for the
case where the configuration seam could not be sourced — five scripts, one of them with a dedicated
test asserting the fallback *succeeds*. That is a value defined twice, invisible until the seam
breaks, and then silently targeting the wrong project. The seam sheet now forbids it outright:
**a degraded path refuses and names the seam** rather than inventing a literal
([`contracts/config-seam.md`](contracts/config-seam.md) § 2).
**Check:** `grep -rn 'ISSUE_PREFIX:=' scripts/` should find the seam's own default and nothing
else.
**The transferable half of how it was paid:** the fix was **declined once**, deliberately, when it
was proposed as a one-script edit — because changing one of five would leave four inconsistent, and
because the existing test asserted the old behaviour on purpose. It was paid as one change across
all five, with the guard **transformed** rather than deleted
([`doctrine/supersession.md`](doctrine/supersession.md) § A.1).

### 4.10 What this extraction deliberately did NOT do
- **No rule's meaning was changed.** Where a donor rule could not generalize, it was replaced by a
  clearly-marked *"Project duties — filled by the adapter"* placeholder stating what **kind** of
  duty goes there — never by an invented rule.
- **No doctrine instance was silently dropped.** Every § B was replaced by fill-in instructions
  **plus**, where the incident was instructive, a short anonymized worked example that preserves the
  reason. That is the supersession law applied to an extraction: *the pattern and the why travel;
  the conclusion's instance does not.*
- **Nothing under `.claude/` was restructured.** The harness path is pinned (§ 3).
- **No guard was written.** § 4.4 stands as the largest live debt, unpaid and named, rather than
  half-paid by a guard nobody can run.
- **Two cross-references in the donor's own doctrine were found broken while writing this** — a
  sheet citing a neighbour for a constant the neighbour does not contain, and a citation to a
  section heading that does not exist. Both are corrected in this copy. They are recorded here
  because they are the *shape* of defect a manifest cannot catch: both links resolved to a real
  file, and only reading the target revealed that the claim about it was false.
