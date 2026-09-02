<!-- KIT-CLASS: KIT — the FORMAT travels (the five-field shape row, the two ratchet rules, the anti-pigeonhole reservation, the advisory cadence, and the pre-cut sweep with its named owner). Every row's evidence column is YOURS to fill. See process/EXTRACTION.md. -->
# The hygiene checklist — the SHAPES a pass looks for, and the instruments that look

> **Pattern vs instance.** This file is two things at once. The **pattern** — a row carrying
> five fields (shape · what it looks like in the tree · the instrument that finds it, by path,
> or `HAND LANE — no instrument` · its evidence date and source · its retire condition), the
> two ratchet rules, the anti-pigeonhole reservation, an advisory cadence and the pre-cut sweep
> with its named owner — is **format law and travels**. The **instance** — every date, every
> count, every path in an evidence column — is **your project's** and travels to nobody.
> `requirements/CORPUS.md` carries the same split for the requirements corpus;
> [`EXTRACTION.md`](EXTRACTION.md) § 1.2 states the rule.
>
> **The instruments are Python 3, standard library only, and that is a carve-out with a reason.**
> The kit's floor is git and a POSIX shell; `scripts/hygiene/` is carved out here, as the skill set
> carves out its Node companion — and it holds because these are **advisory instruments, never a
> gate** — nothing ships them, no gate calls them,
> no consumer inherits them, and no dependency enters your project because they exist. **A project
> that forbids Python deletes the directory and loses only the measurements**: every shape below is
> stated in prose here, which is what makes each one re-implementable in whatever you already run.
> Say so in the adapter if that is your project. *(The shipped skill set carves out its Node
> companion the same way — `.claude/skills/README.md`.)* **This paragraph is about the INSTRUMENTS.
> The pre-cut sweep below is not one of them and is not advisory** — see its own section.
>
> **The shapes below travel as a STARTING LIST with their evidence columns blank.** They are not
> your findings; they are the six shapes that have actually been found in a real repository, kept
> because a starting list you can refute is worth more than an empty file. Fill each evidence
> column with your own measurement, or **retire the row** under ratchet rule 2 with the reason
> *"not present in this tree, measured `<date>`"*.

## Why this file exists at all

A repository-wide hygiene census ran once in the project this kit came from and produced a few
hundred dispositions, a couple of dozen staleness flags and a list of orphans. Every one of those
findings came from an instrument built in a throwaway worktree and **thrown away with it**, so
nothing in the repository could reproduce a single number in the report.

**The design principle, and it is the whole file: SYSTEMIZE THE INSTRUMENTS, NOT THE SUSPECTS.**
An instrument scans everything on every run and cannot pigeonhole. A suspect list — *"check the
plans directory for unstamped plans"* — is cheaper to write and finds exactly the problems the last
pass already found, while the next accretion happens somewhere nobody thought to look. So the
instruments are **committed**, under [`../scripts/hygiene/`](../scripts/hygiene/), and what is
written down here is a list of **shapes**, kept honest by two ratchet rules and one reserved
uninstructed lane.

**This file fails no build.** It is not a guard, not a gate, and not a doctrine sheet — the
doctrine table in [`MANUAL.md`](MANUAL.md) is scoped to `process/doctrine/` and its directory
listing is its own count, so a row for this file there would falsify that claim. The one pointer
in is from [`doctrine/staleness.md`](doctrine/staleness.md) § D.

## The two ratchet rules

**RATCHET 1 — APPEND.** Every deep sweep or fresh-eyes lane that finds a shape not on this list
**appends it, with its evidence date, in the change that found it**. The causing change holds the
pen ([`doctrine/staleness.md`](doctrine/staleness.md) § D) — never a follow-up work item, never a
later sweep. The list is therefore **monotone by construction**: a pass cannot end having found a
new shape and left the checklist unchanged.

**RATCHET 2 — RETIRE.** Every shape carries its evidence date and its retire condition, and
**retires under the same doctrine it was added under**: reason preserved, conclusion superseded,
the row **moved to `## Retired shapes` with its date and its reason — never silently deleted**
([`doctrine/supersession.md`](doctrine/supersession.md) § A.1). **A shape whose instrument was
built, or whose enforcement became a guard, retires from the hand list and names the mechanism
that now owns it** — that is how this list shrinks instead of growing forever.

**So the checklist polices itself: rule 1 makes it complete, rule 2 keeps it honest.**

## THE ANTI-PIGEONHOLE RULE — read this before spending a pass's budget

**Every systematic hygiene pass reserves budget for ONE uninstructed fresh-eyes lane** — no
checklist, no shape list, no suspect list, told only the charter and *"find what is wrong here"*.
**Its findings feed ratchet rule 1.** A pass that spends its whole budget on the list below can
only ever find last time's problems.

Its basis is measured, and here are the three measurements rather than the assertion — each from
one project, each anonymized, none of them yours:

1. **17 of 41** risky proposals were **refuted** when an independent skeptic was pointed at a
   reasoned list. Directed reasoning generates plausible targets faster than it validates them.
2. **Two blind modalities converged on one file** that the directory-walking fan-out had missed
   entirely — described in that census as its best evidence that the prose corpus was not hiding
   more. Blind scanning found what directed reasoning did not.
3. **Twin audits, counted rather than asserted.** Across two adjudicated sections, the **unguided**
   lane contributed four unique finds of which **three survived adjudication**; the
   **checklist-guided** lane contributed five of which **one** did. The unguided lane's finds
   survived at the higher rate — *that*, not the raw total, is the reservation's warrant.

## The cadence — ADVISORY, and here is the negative stated

Run a pass at an **era boundary** (an arc closing, a doctrine round, a seat succession) **or
roughly every fifth release**. **Seat-triggered, never automatic, and NEVER a release gate.**

**That is the CADENCE, and it is what nothing depends on.** Neither the release ritual nor the gate
runner calls any of the hygiene instruments in this file, and no cut depends on a periodic pass
having run. The instruments are **advisory, never a gate**.

**The pre-cut sweep below is the exception, and it is not one of them.** It is a **required step** of
the release ritual where the slate came from a round — `contracts/release-ritual.md` § 2 requires it
with a named owner before the version is written, and **§ 3 refuses a cut without it**. *Required is
not automated: no script arm decides it, for the reason the sweep's own section gives.* **Read the
two sentences together or the first one reads as covering the second.**

## Before a cut — the pre-cut sweep (MANDATORY when the slate came from a round)

**Owner: the PM.** `doctrine/fix-execution.md` § A.4b: **one fresh-context checker per consumer-facing
surface**, verifying that surface's claims against the tree as it stands. **Your surface list lives in
the project doc** (`PROJECT.md` § The pre-cut sweep's surface list) — if it is still blank, the sweep
cannot be dispatched, because *"one checker per surface"* has no leg count until the list exists.

**IT RE-RUNS AFTER EVERY FIX ROUND, until a round finds nothing.** A sweep certifies the tree as it
was *before* its own findings were fixed — and fixing a finding is a landing that edits the very
surfaces the next reader meets. One pass is a pass over a tree that does not ship.

**Where a surface can be EXECUTED, execute it.** A claim about what a command prints, what a refusal
says or what a flag does is checkable by running it, and reading is the weaker instrument for exactly
those. **Usage and `--help` text are surfaces.**

**Brief the checkers adversarially and as NAIVE CONSUMERS** — the question is *"does this tell someone
who has never seen this repository something false?"*, not *"can I reconstruct what the author
meant?"* An author-stance read repairs the sentence silently while reading it.

**This is a checklist item and not a gate, deliberately, and the reason is worth knowing:** a gate here
would have to check an **artifact** the sweep produces rather than the sweep itself, and an artifact
that is trivially satisfiable makes the gate self-certifying — which is the defect
`doctrine/instruments.md` is about, wired into the release path. **A gate is the better answer once the
surface list is machine-readable; it is the worse answer before that.**

**The honest counter-argument, recorded rather than hidden:** a checklist item is only as good as the
person who runs it, and *the kit's own maintainer repository shipped two false statements in its notes
documents that were both checklist items nobody ran.* **If you skip this twice, build the gate.**

## The instruments

Named by **role**, because the concrete filenames and the implementation language belong to
[`../scripts/hygiene/`](../scripts/hygiene/) rather than to this checklist — a reimplementation in
another language satisfies this file unchanged.

| # | Instrument | Modality |
|---|---|---|
| 1 | the **duplication scan** | cross-file n-gram containment over the prose corpus |
| 2 | the **reachability walk** | starter-graph walk → orphan list, with its convention exemptions named *in the instrument* |
| 3 | the **cold-signal scan** | single-commit AND cold AND zero EXACT referrers, from local history |
| 4 | the **staleness greps** | the loose staleness signals, reported as suspicions **with their base rate** |

All four share one **citation index**, which reports **EXACT and ANCESTOR referrers as separate
columns and never collapses them.** That separation is the central honesty mechanism of the whole
set: an ancestor referrer ("something under this directory is cited") is not evidence that *this
file* is read, and collapsing the two turns every orphan into a false negative.

## What a row may say — DATES AND COUNTS, NEVER A SUPERLATIVE

**No row below may carry a superlative as prose.** "The worst offender", "the current biggest
file", "the newest", "today" are all banned: they are true on the day they are written and
silently false afterwards, and no guard can catch the rot. **A row states a DATE and a COUNT
instead** — *"1,161,669 B as of 2026-01-19"* survives being read a year later; *"the biggest file"*
does not. The rule is not local to this file: it is
[`doctrine/lookup-tables.md`](doctrine/lookup-tables.md) § A.3, which states it for every index and
lookup table. **Every count here is carried with its measurement date and the instrument or command
that produced it**, and a re-measurement **PREPENDS** rather than replaces
([`doctrine/supersession.md`](doctrine/supersession.md) § A.1).

## The shapes

### 1. Spent-plan decay

- **What it looks like in the tree:** a closed plan whose own banner still reads `STATUS: LIVE`.
- **Instrument:** the **staleness greps** for the loose signal. **The enforced half belongs to a
  guard** — the closure-pairing guard of
  [`doctrine/staleness.md`](doctrine/staleness.md) § B, derived from the citation graph — **so
  nobody re-solves it by hand.** Name your guard here once you build it.
- **Evidence date + source:** `<date>` — `<the command, and what it reported: how many plans, how
  many carrying a closure verdict in their first N lines, how many genuinely live>`.
- **Retire condition:** retire when the guard's domain covers every closure claim a plan can make
  and the grep adds nothing the guard does not already redden on.

### 2. Cold evidence trees

- **What it looks like in the tree:** raw per-call machine residue committed wholesale — a capture
  directory added in one commit and never read again.
- **Instrument:** the **cold-signal scan**.
- **Evidence date + source:** `<date>` — `<the tree, its file count and byte size, and whether it
  was added in a single commit>`. *(Origin of the shape, anonymized: one capture tree of ~350
  files / ~6.5 MB, added whole in one commit and never amended. A later sweep thinned it rather
  than removing it, which is why the shape stayed live.)*
- **Retire condition:** retire when evidence trees stop being committed wholesale — i.e. when a
  probe's raw captures land summarized, with the raw set out of the repository.

### 3. Orphans

- **What it looks like in the tree:** live machinery nothing links, and stale prose everything
  links. **Both directions**, because reachability-by-link and reachability-by-convention are two
  different graphs.
- **Instrument:** the **reachability walk**, with its convention exemptions named in it.
- **Evidence date + source:** `<date>` — `<nodes, orphans, and how many of the orphans fall inside
  the convention exemptions>`. **Measure it on the tree AS IT WILL STAND**, including any file the
  same change adds — an earlier reading taken before this very file existed was falsified by
  landing it, which is exactly what shape 5 exists to catch.
- **Retire condition:** retire if a link-completeness guard ever owns **both** directions of your
  retained-evidence index and the same for `requirements/` — at which point the walk becomes
  redundant rather than merely quiet.

### 4. Giant-file growth

- **What it looks like in the tree:** a document too large to consult, with no index into it.
- **Instrument:** your drift report's **whole-file** arm. ~~Once it exists — the shipped log-size
  check measures one section, not the file (see shape 5).~~ *Superseded: the reference
  implementation ships the whole-file arm beside the section one, as its own advisory threshold
  constant. The reason is kept because it is still the distinction that matters — a section-size
  check does not measure the file, and shape 5 is the other one.* The **rule** half is already
  written:
  [`doctrine/lookup-tables.md`](doctrine/lookup-tables.md), which is what an index into such a file
  has to satisfy.
- **Evidence date + source:** `<date>` — `<the file, its byte size, and whether an index exists>`.
- **Retire condition:** retire when the whole-file arm measures the whole file **and** a lookup
  table exists for every document above the threshold — the shape then has a guard and a rule, and
  belongs to neither hand nor instrument.

### 5. Instrument health

- **What it looks like in the tree:** *the measuring device reports OK while blind.* A threshold
  that measures a fraction of what its name implies, and passes.
- **Instrument:** **a planted positive, re-run each pass.** Every instrument is shown finding a
  synthetic positive of the exact shape it claims to find, and the plant is then reverted.
  **This row is the one that makes the checklist police itself** — without it the list inherits
  any blindness its instruments have, silently.
- **Evidence date + source:** `<date>` — `<which instruments were plant-verified this pass>`.
  *(Origin of the shape, anonymized: a log-size threshold reported a comfortable pass — under
  20 KB against a 32 KB bound — while ~98% of the file it was named after sat outside the span its
  parser actually read. The verdict alone could never have revealed it.)*
- **Retire condition:** retire only if every instrument here is replaced by a guard that is itself
  red-proved in place inside your test suite, at which point the suite owns this row.

### 6. Banner over-claiming

- **What it looks like in the tree:** a retirement stamp asserting more closure than actually
  happened — a banner that says a question is settled when a lane only stopped asking it.
- **Instrument:** **HAND LANE — no instrument.** Judging a banner's honesty is not greppable: the
  words are correct and the claim is not. The governing rule is
  [`doctrine/supersession.md`](doctrine/supersession.md) § A.1 — preserve the reason, supersede
  only the conclusion, prepend rather than replace — plus
  [`doctrine/staleness.md`](doctrine/staleness.md) § A.2's fifth field, the **residue clause**.
- **Evidence date + source:** `<date>` — `<how many banners were reviewed, and by whom>`. *(Origin
  of the shape, anonymized: a stamping sweep of ~78 archive rows met no skeptic at all, and where
  a verifier did review rows, its recurring complaint was a banner over-claiming closure.)*
- **Retire condition:** retire if a guard is ever built that compares a banner's claim against the
  artifact it claims about. None is proposed; until then this row stays in the hand lane and says
  so.

## Retired shapes

*(None yet. A shape retires here under ratchet rule 2 — moved with its date and its reason, and
naming the mechanism that took it over. It is never deleted.)*
