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

Every script, role doc and process file carries a one-line marker in its own comment syntax — **with
the carve-outs at the end of this section, which are the files that cannot**:

```
# KIT-CLASS: KIT|MIXED|PROJECT — <one-line reason>. See process/EXTRACTION.md.
<!-- KIT-CLASS: … -->     (markdown)
```

`KIT` = travels unedited · `MIXED` = travels, but carries project law you must edit ·
`PROJECT` = does not travel. **Classify a file by opening it**; this manifest can drift, the
marker in the file cannot be missed. **Where a file carries no marker, the carve-outs at the end of
this section say where its class lives instead** — opening those files will not answer, and each
absence is a derivation from something about the file rather than an omission.

**The `KIT` in `KIT-CLASS:` is this convention's own word — it is NOT the identifier prefix, and it
does not change when a project stamps one.** It only looks like the prefix because the shipped
placeholder prefix is also `KIT`. That collision is not academic: the initializer's prefix
substitution matched the marker's **key**, so every stamped file came out reading
`<!-- XYZ-CLASS: KIT — … -->` — the key rewritten and the value left, a line that refutes itself,
**in every stamped file that carried the marker**, with every card minted afterwards inheriting it.
*(The shape is the load-bearing fact, not a count: what made the collision total is that no marked
file escaped it. `grep -rl 'KIT-CLASS' .claude/templates .claude/roles` if you want today's number.)* A tool that rewrites the
prefix therefore exempts this key by name, and any census of surviving placeholders exempts it in
the same change, or protecting the marker simply moves the failure into the census.

**And an instruction must not live inside a marker on a file whose marker will be removed.** The
marker is the *travel classification*; on a file that becomes the project's, graduation strips it.
Anything a reader still needs at that moment — a *replace me* notice, a *fill this in* notice —
belongs in the body, where removing the classification cannot remove it.

**Carve-outs to the marker itself, each a derivation rather than a preference** — and the class-as-data
case below them is a third way a file can lack a `KIT-CLASS:` comment, which is why no count is
written here: *the list is the list.*

- **Vendored skill directories are classified by the `Class` column of
  `.claude/skills/README.md`'s provenance table, not in-file.** *Why:* updating a skill from upstream is a **re-fetch and copy the folder over**, which
  **erases an in-file marker** — so a marker there would be a classification that silently disappears
  on the one operation the skill set is designed for, and its absence would read as an unclassified
  file rather than as an update. The provenance table survives the copy because it lives outside the
  directory being replaced. *Derive what is marked:* `grep -rl 'KIT-CLASS' .claude/skills/`.
- **`process/KIT-VERSION` carries no marker.** *Why:* it is a single version literal and **has no
  comment syntax** — any marker would become part of the value the release ritual reads. The same
  constraint applies to any file whose entire content is consumed as data.
- **A file BORN in your tree that will never travel carries no marker — and says so in one visible
  line of its own body.** *Why:* the marker is a **travel** classification, and a file that was never
  the kit's has no travel to classify; a `PROJECT` marker on it would answer a question nobody asked.
  **The visible line is not optional, and it is why this carve-out is written rather than left
  implied:** a bare absence is indistinguishable from an oversight, so without it the next extractor
  cannot tell deliberate non-marking from a file somebody forgot. *One sentence — "this file carries
  no `KIT-CLASS:` marker deliberately: it was born here and never travels" — discharges it.*
  **The distinction that decides this is whether the file's SHAPE travels, not whose content is in
  it:** `requirements/CORPUS.md` keeps its marker because the *shape* is the kit's however
  project-specific its entries become, while a feedback log you invent for your own use never had
  one.

**And one file carries its class as data because it cannot carry a comment:**
`.claude/settings.json.example` is JSON, so its classification is the `_KIT_CLASS` key beside its
other underscore-prefixed notes. *A convention that cannot be expressed in a file's own syntax is
expressed in that file's own terms, not abandoned.*

**A carve-out to the FLOOR, stated here because this is where the rule lives.** The kit assumes **git and a
POSIX shell** — and `scripts/hygiene/` is **Python 3, standard library only**. Those files are
**advisory instruments, never a gate**: nothing ships them, no gate calls them, no consumer inherits
them, and **a project that forbids Python deletes the directory and loses only the measurements** —
[`hygiene-checklist.md`](hygiene-checklist.md) states every shape in prose, so each one is
re-implementable in whatever the project already runs. Say so in the adapter if your project forbids
Python, the same way the shipped skill set handles its one optional Node dependency
(`.claude/skills/README.md`). *The floor is a claim about what the kit REQUIRES, not about what it
contains; an instrument you can delete is not a requirement.*

**In this seed almost everything is `KIT`, and that is a fact about the seed, not a boast.** The
seed *is* the kit: it holds no product. `MIXED` here means *"the frame travels, the contents are
yours"* — the gate runner, the attribution hook, the release script, the self-test harness. As soon
as you fill in `PROJECT.md` and `CLAUDE.md`, **those two are `PROJECT`-class by nature**: they are
the only files in the tree that never travel anywhere. ~~Mark them so~~ — **they LOSE their markers
at that moment rather than gaining `PROJECT` ones**, which is § The marker and graduation's act and
is specified there. Re-mark honestly as your own files accrete. A marker that says `KIT` over a file
carrying your product's law is worse than no marker.

*(The struck instruction stood until 2026-08-31 and **directly contradicted the graduation rule**,
which names `PROJECT.md` as its own worked example: one section said mark it `PROJECT`, the other said
strip it, **at the same moment in the file's life**. Both mistakes were made in an adopting project
before either was noticed. The reason above is kept because it is the reason for **stripping** — a
marker that misdescribes a file is worse than none, and a `PROJECT` marker on a file that never
travels is a travel classification for a journey nobody takes.)*

## The second axis: DISPOSITION — what state must this file be in before day one is done?

`KIT-CLASS:` answers *does this travel to the next project?* It does not answer *what has to happen
to this file before this project is set up*, and the two have different readers: the classification
is read by whoever extracts the kit **out** of a project, the disposition by whoever is standing in
a fresh unpack with a day of work ahead of them.

**This is a second axis, not a second classification.** The convention above is still the one
classification convention; nothing here changes a `KIT-CLASS:` value, and a file has both a class
and a disposition at the same time.

| Disposition | Meaning | Members in this seed |
|---|---|---|
| **KEEP** | Travels unedited; stays visibly the kit's. **Some surfaces inside `process/**` are declared blanks and are named here rather than counted:** each doctrine sheet's *your project's instance* section, this manifest's § 4 debt list, the hygiene checklist's evidence column, and everything under `process/templates/`, which is hand-filled shapes throughout (see its own row below). *They are still `KEEP`, because what travels unedited is the SHEET — a bounded blank inside it is where the project's own text goes, not an edit to the kit's half. Read "travels unedited" without this and a reader leaves every one of them empty, which is the failure this row caused.* | `process/**`, `.claude/skills/**` |
| **STAMP** | The initializer rewrites values; the structure stays the kit's. | `.claude/templates/`, `.claude/roles/`, `scripts/config.sh` |
| **FILL** | Ships as a shape with blanks. **Not done until no blank remains.** | `PROJECT.md`, `.env.example`, `.gitignore`'s build section, `scripts/verify.sh`'s `GATES`, `setup.sh`'s runtime half |
| **REPLACE** | Ships as **scaffolding to be thrown away and rewritten** — never edited into shape. | `CLAUDE.md`, `README.md` |
| **SEED** | Ships empty or skeletal; accumulates this project's own content. | `progress.md`, `ARCHIVE.md`, `progress/**`, `requirements/CORPUS.md`, `requirements/DECISIONS.md`, `dev/**` |
| **DELETE-IF-UNUSED** | Ships as an option. An unused option reads as a promise. | `consumers/`, `.claude/roles/archive/`, the notification adapters (`scripts/notify*`) |

*(The members are a **derivation of this seed**, not a definition of the axis. Re-derive them by
opening the tree; a project that adds a surface gives it a disposition then, and this table is
wrong rather than general if a reader treats it as closed.)*

**REPLACE is the row that exists because of a measured failure**, and it is the one worth reading
twice. `README.md` has always carried a *replace me* notice; nothing named the class, nothing else
was in it, and nothing checked it. The failure that follows is not that an adopter ignores the
notice — it is that **scaffolding written well enough to be plausible gets edited instead of
replaced.** A generically-filled adapter arrives with a filled roles table, a filled prefix table
and real house rules, so the reader fills two angle brackets and moves on, and the project carries
the kit's generic law forever. **A REPLACE file is therefore shipped deliberately unusable as-is** —
it states that it is scaffolding in its own first lines — because a REPLACE file that could be
mistaken for a finished one will be.

**What discharges each row is different, and saying so is the point of having the axis:**

- **KEEP** — nothing. Leaving it alone is the correct action, and an edit to a KEEP file is drift
  the next extraction pays for.
- **STAMP** — the initializer, once, at setup. A STAMP file nobody stamped still holds the kit's
  placeholder values.
- **FILL** — a human or an agent, by hand, reading the blank's own instruction. **A blank left in a
  FILL file is not a cosmetic debt:** `verify.sh`'s `GATES` ships empty, so an unfilled one is a
  gate runner with nothing to run, and the first landing sets the precedent that landings are
  ungated.
- **REPLACE** — deletion and rewriting, not editing.
- **SEED** — the project, over time. **A SEED file is never "done"**, which is exactly why it must
  not be judged by the same test as FILL: emptiness is its correct day-one state.
- **DELETE-IF-UNUSED** — a decision, recorded either way. Removing it and *keeping it on purpose*
  are both discharges; **leaving it undecided is not**, because the next reader cannot tell an
  option that was weighed from one nobody opened.

### The marker and graduation — strip where the class becomes `PROJECT`

A file that becomes the project's own stops being classified for travel, and its marker goes with
it. The rule is the one already stated above, applied at the moment it bites: **strip the
`KIT-CLASS:` marker where the file's class has become `PROJECT`; keep it — and re-mark it honestly
— where the file stays `KIT` or `MIXED`.**

**Read the rule off the class, never off the disposition.** `scripts/verify.sh` is FILL and
`setup.sh` is FILL, and both keep their markers, because both are `MIXED`: the frame travels and
only the contents are yours. A strip rule phrased over the disposition instead — *"strip on REPLACE
and FILL"* — contradicts itself on exactly those two files.

And the constraint that follows from stripping, which is easy to violate months earlier than it is
noticed: **an instruction must not live inside a marker on a file whose marker will be removed.** A
*replace me* notice belongs in the body, where removing the classification cannot remove the
instruction. *(Stated above under the classification convention; repeated here because this is the
section where somebody is deciding what to strip.)*

**The test is whether the instruction still has work to do at the moment the marker comes off**, and
that admits one case people keep re-deriving, so it is written here once:

- **A fill-in instruction MAY live inside a marker**, because it is **discharged before graduation**.
  `PROJECT.md`'s marker says *fill every `<angle-bracket>`*; you fill them on day one, and only then
  does the file become `PROJECT`-class and lose its marker. At the moment of stripping there is no
  reader left who needs the instruction — it has already been obeyed.
- **A replace-me instruction MAY NOT**, because it is **the very act graduation performs**. It is
  still in force at the moment the marker would be removed, so a marker-borne copy is removed by the
  operation it was there to prompt. That is why `README.md` and the `CLAUDE.md` stub carry their
  notices in the body.

*So the rule is about the instruction's lifetime, not about where instructions look tidy.* A marker
may carry an instruction that dies before it does.

### Day one is done when every row is discharged

That is the same list [`SEED.md`](SEED.md) § Day one is done when already carries, said in terms of
the axis rather than in terms of five filenames — and the axis is what makes it enumerable instead
of remembered. **Until then the repository is a kit wearing a project's name**, which is the state
this axis exists to make visible and finite.

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
| `process/templates/` | Fill-in-the-blank shapes. **Hand-filled** — the initializer stamps `.claude/templates/`, not these, so they carry no prefix literal. Blanks are `<angle brackets>`. **A FILL file has no template here: it ships as its own blank instance and is filled in place.** *A template nothing stamps drifts from the instance it claims to be — every edit reaches the live sheet and none reaches the copy, and nothing in the tree compares them.* |
| `process/hygiene-checklist.md` | The shapes a hygiene pass looks for, plus two ratchet rules and the anti-pigeonhole reservation. **The cadence is advisory; the pre-cut sweep is MANDATORY when the slate came from a round.** The shapes travel with their **evidence columns blank**. |
| `process/EXTRACTION.md` | This file. Update its § 4 as you pay the debts down, and **add the debts you discover** — that is ratchet rule 1 applied to a manifest. |
| `.claude/roles/` | The role docs. Read each one's marker rather than assuming a split: `grep -l 'KIT-CLASS: MIXED' .claude/roles/*.md` returns nothing in this seed, and § 4.2 says why the pull toward `MIXED` was real anyway. |
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

**Take but EDIT** — the files whose **project half you fill on day one**. *The heading used to read
"the four files", over a table that had five rows, in the file whose § 2.4 forbids exactly that: the
table is the list and the table is the count.* It is **not** simply the `MIXED` class — see the
exclusion below the table.

| File | The kit half | Your half |
|---|---|---|
| `githooks/commit-msg` | write-time enforcement, closed set, instructive refusal — **and its second rule, the refusal of generated co-author trailers and *"Generated with"* lines, which is wholly the kit's**: nothing stamps its marker list and no project edits it | the **membership** of the role set (the initializer stamps it) — **and nothing else in the file**. *The hook enforces two rules; only the first has a project-owned part. A reader who takes this row as describing the whole file will look for a project seam in the second rule and find none, which is the answer, not a gap.* |
| `verify.sh` | one runner, fixed order, one summary block, the narrowed mode and its unskippable floor | the **declared gate table** and the floor's membership |
| `release.sh` | preflight → bump → attributed commit → annotated tag → push → publish, and the refusals | which files carry the version, which documents are required, whether anything is published at all |
| `test/run.sh` | the throwaway sandbox with its own publication target, three-way accounting, capability probes, the test-only marker | any case family that pins **your** facts |
| `setup.sh` | the shape: environment → install → gate → hooks path | **everything about your language runtime** |
| `.env.example` | the kit's own entries, complete | the **project block** below them |
| `.gitignore` | the kit's own entries, complete | the marked **build-artifact section** |

**One file is `MIXED` and deliberately NOT a row: `progress/history/INDEX.md`.** Its project half is
**accumulated, not filled** — rows arrive as the log rotates — so it is `SEED`-shaped work rather than
a day-one touch. *Stated rather than omitted, because a table that silently drops a member of the
class its heading names is the failure mode this file is trying to end.*

**Derive the class rather than trusting this table, and anchor to the FIRST marker per file:**

```sh
for f in $(grep -rl 'KIT-CLASS:' .); do
  grep -m1 -o 'KIT-CLASS: [A-Z-]*' "$f" | grep -q MIXED && echo "$f"
done
```

*The `-m1` is load-bearing and a plain `grep -rl 'KIT-CLASS: MIXED'` is wrong:* `scripts/kit-init.sh`
is `KIT`, and it **generates** a `verify.sh` — so it carries a `MIXED` marker for the file it writes,
inside a heredoc. **A generator that emits a classified file contains that file's marker**, and any
census that does not read the first marker per file counts the generator as its own output.

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
copy of it would drift). Its preflight checks a **hand-listed minimum** of that copy-list — the
files without which nothing else can run — and refuses, naming each one that is missing. **It is
not a check against § 1's list**, and it cannot be: § 1 is prose, and the contract forbids the tool
carrying a second copy of it. A file that travels but is not in the minimum is not caught here.

It performs every precondition in the table below, then **proves them** with a **self-check** that
mints a scratch item, moves it through two columns, asserts the drift report clean, and has a real
commit **rejected** by the attribution hook — the whole point being that *every finding in this
kit's cold-read review was found by reading, and all of them would have been found by running.*
The behaviours worth knowing before you run it — *the list is the list; it carried a digit once and
the digit was already short by one when a reader checked it against the tool's contract:*

- **The trunk is confirmed, never inferred.** `--trunk` is required and is cross-checked against
  the remote's published default branch; a disagreement refuses. `<trunk>` defaults to `main`.
- **It guides the remote, it does not create one.** No remote / no published default branch /
  unborn HEAD ⇒ refusal **with the four-step recipe**, whose step 1 is the local bare-repository
  recipe for an offline project ([`GIT-HOSTING.md`](GIT-HOSTING.md)). Creating a remote is a
  repository-topology decision an initializer must not make for you.
- **A filesystem remote must be an ABSOLUTE path; a relative one refuses, with the one-line fix**
  ([`contracts/initializer.md`](contracts/initializer.md) § 3). *Why:* the auxiliary checkout runs
  version-control operations from a different working directory, where a relative path resolves
  somewhere else or nowhere — so the failure surfaces later, in another tool, as a missing remote.
- **It runs a placeholder census on its own output and fails loudly on a non-zero result**
  ([`contracts/config-seam.md`](contracts/config-seam.md) § 4.3). *Not "refuses": the census runs
  after the initializing commit, so the tree is already written when it fires — it reports the bad
  result, it does not prevent it.* The promise *"the travelling files are clean"* was believed by
  three readers and checked by nobody, once. Now it is measured.
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
`dev_complete`, `qa_complete`, `blocked`, `done` (+ `history/` for the rotated log).

**It is a SEAM WITHOUT A VARIABLE: several files carry the names as literals, and they do not all
carry the same ones.** The table is the list and the table is the count; the divergence column is the
part that matters, because *"apply one edit N times"* is the wrong model for this seam.

| File | What it holds | If it is missed |
|---|---|---|
| `scripts/move-issue.sh` | the full set, four times: the target whitelist, the usage text, the error message that lists legal targets, and the note-scan regex (which carries it twice) | a new column cannot be moved to **at all** |
| `scripts/check-board.sh` | the full set, as the columns it walks | the new column is invisible to the drift report |
| `scripts/subtask.sh` | the set **minus `done`**, on its `move` arm | a subtask cannot reach the new column |
| `setup.sh` | the set **plus `history/`**, as the directories it creates | a fresh clone is missing the directory |
| `scripts/test/run.sh` | the set **plus `history/`**, iterated to build its sandbox board | the harness builds a board the project no longer has |
| `scripts/kit-init.sh` | the set as the board it declares and creates (`STATUS_FOLDERS`) | the board is created without the column |

**Other files name columns without carrying the set, and they are not all the same kind.** None is a
row above; none is safe to ignore; and what a lifecycle change costs each one differs:

- **They perform a transition and name its two ends.** `scripts/archive.sh` moves
  `qa_complete` → `done` and **refuses rather than creating a missing `done/`**;
  `scripts/finish-pr.sh` moves `dev_complete` → `qa_complete`. **A change to any column one of them
  names touches it** — which is checkable per column, and is not a question of where in the flow the
  column sits.
- **They mention one column in a comment or an example string.** `scripts/verify.sh` names
  `dev_complete` in a comment and an echo; `scripts/githooks/commit-msg` names `qa_complete` inside
  an example subject in its refusal help; `scripts/config.sh` names `in_progress` in an example
  command. **Nothing breaks if these are missed — the text simply goes stale**, which is the cheapest
  class here and the easiest to leave for years.

Derive both sets, and do not trust a single-column probe:

```sh
grep -rlE '(todo[|, ]+in_progress|STATUS_FOLDERS)' scripts/ setup.sh   # carries the SET
grep -rlE 'in_progress|dev_complete|qa_complete'   scripts/ setup.sh   # names ANY column
```

*The second pattern deliberately omits `todo` and `done`. `done` is a shell keyword, so it matches
loop terminators; it is also the tail of `progress/done/`, so most of what a bare `done` finds in
`archive.sh` is **path literals — the seam itself**. Either way a bare count answers a question about
the language and the paths rather than about the seam, which is why the pattern uses the three column
names that are neither.*

*This paragraph has been wrong twice, in opposite directions, about the same files.* First it claimed
the archive sweep and the landing gate held **none** of these values, on the evidence of
`grep -c 'in_progress'` over both — the command was true and the claim was false, because
`in_progress` is the one column neither touches. **A probe scoped to the one operand that exculpates
the subject is the guard looking slightly to the left of the defect.** Then the correction generalised
*"endpoints of their own transition"* from those two files onto five, when three of the five only
mention a column in a comment or an example. **Both errors were a characterisation stretched past its
measurement**, which is why the list above is now per file and says what each one does with the name
it holds.

**Check whether your copy makes it a variable** (§ 4.5).

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
| `.claude/settings.json.example` | The set spelled out in prose, in its `<role-prefix-list>` note | **Documentation only — nothing enforces it.** Derive from the hook; this is the copy an adopter reads *before* they open the hook, which is what makes a stale one expensive |
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
| **The project adapter** — the project's own law, the role set, the prefix table, the code-path definition | `CLAUDE.md` (the harness reads this filename). **The kit ships a bootstrap stub at that path, not a default adapter** — `REPLACE`-class, see § The second axis: DISPOSITION. | Your adapter, pointing at `process/MANUAL.md` in its first paragraph. Build it from `process/templates/CLAUDE-adapter.template.md` and **overwrite** the stub. |

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
repository. The values inside it listed below are yours, and one of them restates the role
set — keep it in step with § 2.4, **whose table is the list**:

| Value inside the file | Replace with |
|---|---|
| The trunk name | Your `<trunk>` |
| The code-path globs (in both the *allowed metadata* list and the *forbidden direct-push* list) | Your § 2.6 answer, verbatim |
| The two project filenames (cited as the rules' authority and listed among the pushable paths) | Your two files (§ 2.5) |
| The role-prefix list in its prose | Your role set |

### 2.9 The drift-report thresholds

The bounds the drift report needs are **named constants at the top of the reference
implementation** — a seam, not a contract term — and **are neither repeated here as digits nor
counted here.** Read them from the file. They cover the depth at which the reviewed-and-done column
is *due for a sweep* and the sizes at which the running log is *due for rotation*, its current
section and the whole file being separately bounded. The **section**-size one is deliberately
reused as the index trigger in [`doctrine/lookup-tables.md`](doctrine/lookup-tables.md) § A.1, so
that one idea does not carry two numbers.
*This paragraph said "two bounds" while the seam declared three: naming the members is the same
census the digit is, and it goes stale the same way. Say what the bounds are FOR, and let the file
say how many.*

---

## 3. PATH-PINNED — deliberately NOT moved

| Path | Why it stays exactly there |
|---|---|
| `.claude/**` (roles, skills, agents, workflows, templates, the settings example, the session-role file) | **Harness-mandated.** The agent harness reads this path: hooks are wired from its settings file, the role gate reads the session-role file, skills and agents are discovered by directory. Moving any of it under `process/` **breaks the harness**, so the kit classifies it in place rather than by location — **with an in-file marker for the role docs, agents, workflows and templates, and by the `Class` column of `.claude/skills/README.md`'s provenance table for the skill directories** (see § The one file classification convention for why the skills differ). |
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

### 4.2 Role docs are kit workflow that accretes project law — the class question is settled, the residual is not
An implementer/reviewer role doc naturally accretes project-specific duties **inside** its
Definition-of-Done and review checklists, and a seat contract is written around one project's gates
and release policy. They are genuinely transferable **workflows** wearing project **law**.
~~**Some role docs are `MIXED`.**~~ **Superseded — the classification half is paid:** every role doc
in this seed is `KIT`. Derive it rather than trusting this line:
`grep -l 'KIT-CLASS: MIXED' .claude/roles/*.md .claude/roles/archive/*.md` returns nothing.
*The reason is kept because it is what made the answer non-obvious: the pull toward `MIXED` was
real, and what resolved it was giving the project law somewhere else to live, not deciding the docs
were purer than they looked.*
**Also paid:** the adapter template ships a named **"Project duties — filled by the adapter"** block,
so there is a home for them. **The residual, still open:** whether every role doc *points* at that
block instead of inlining its own list. *A home existing is not the same as everything having moved
into it — that gap is the debt this section is now about.*
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
**opening every carrier in § 2.2's table and deciding what each one should hold** — which is not the
same as applying one edit N times, because they do not all hold the same set.
**Check:** `grep -rn 'qa_complete' scripts/ setup.sh` — a handful of hits in one declared list is a
seam; a scatter across the files § 2.2 lists is this debt.
**Cost if unpaid:** every carrier in § 2.2's table edited by hand, per lifecycle change — **and the
divergent ones decided rather than copied.** *(This line, and the sentence above it, previously named
"the board mover, the drift report, the archive sweep and the landing gate" and costed it as "four
scripts". Two of those four do not carry the set — they perform one transition each and name its two
ends — so the cost depends on **which columns** the change touches, not on where in the flow they
sit: § 2.2 has both lists and the commands that derive them.)*

### 4.6 The initializer's stamping reach is not total
The initializer stamps the configuration seam, the item templates and the role docs. Whether it
reaches `.claude/agents/` and `.claude/workflows/` — which contain illustrative ids, trunk names
and gate-command examples of their own — is the thing to check, and historically it did not.
**Check, after running the initializer** — two commands, because the role docs have a different
answer for `<trunk>` and the difference is a ruling, not an oversight:

```sh
grep -rnE '<PREFIX>|<trunk>|XYZ-[0-9]' .claude/agents .claude/workflows
grep -rnE '<PREFIX>|XYZ-[0-9]'         .claude/roles      # NOT <trunk> — see below
```

Either should return nothing that reads as a live value rather than an illustration.

**Why `<trunk>` is excluded from the role docs, and why that is a rule rather than a leniency.**
**`<trunk>` inside a role doc is NOTATION: every role doc that uses it DEFINES it, in its own
preamble** — *"Throughout, `<PREFIX>-NNN` is an issue id in this project's own scheme and `<trunk>` is
the project's single trunk branch"* — so the angle brackets are a symbol the document introduces, not a
blank the stamper missed. **Stamping it would delete the referent of a definition the same file
states.**

**And the initializer never touches it, for any project.** What it rewrites is the **literal trunk
name** — its `TRUNK_RE` is built from the shipped default read out of `lib/kanban-worktree.sh`, so a
project whose trunk is `<something-else>` gets every literal occurrence rewritten and every `<trunk>`
symbol left standing. **That is why the census line reads `trunk '<default>': N → N` on a project whose
trunk equals the shipped default: it is counting the literal, and there was nothing to change.** *The
line is honest about which string it counts; it was read as a report about the angle-bracket blanks,
which it never was.*

**So the previous version of this check was wrong in one direction only:** it named `<trunk>` and did
not read `.claude/roles`, which is the STAMP-class directory that actually carries the symbols — so it
could never have reported them, and widening it naively would have reported every definition as a
defect.
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
**Check:** `grep -rn '^[^#]*ISSUE_PREFIX:=' scripts/` — **it should find nothing at all.**
*The `:=` (assign-if-unset) form IS the defect: a script carrying it defines its own default and
stops reading the seam. The seam's own default is spelled `:-`, so it is deliberately not what this
matches — and the scripts that do mention `:=` mention it in comments recording the removal, which
is why the pattern skips comment lines.*
**This check previously read *"should find the seam's own default and nothing else"*, and was wrong
on both halves** — it found five things, none of them the seam's default, and a reader who ran it
saw five hits where the sentence promised one and had no way to tell a false alarm from a real one.
*A verification command whose expected output is wrong is worse than no check: it trains the reader
to ignore it.* Prove a check on a planted defect before writing it down.
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
