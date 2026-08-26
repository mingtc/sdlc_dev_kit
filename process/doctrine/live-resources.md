<!-- KIT-CLASS: KIT — transferable doctrine. § A is the pattern; § B is the project instance (<fill-in>); § C is an anonymized worked example from the donor project. -->
# Live-resource doctrine — consent, budget and evidence for anything created outside the repo

**KIT-CLASS: KIT, with one project-bound section.** § A (the pattern) travels verbatim; § B is
**this project's instance** and must be filled in before the doctrine binds anything; § C is a
worked example from the project this kit was extracted from, anonymized, kept because the
reasons are the transferable part.

**Scope — what a "live resource" is.** Anything a test, script or agent creates that continues to
exist **outside this repository**: a document or record in a hosted service, a row in a shared
database, an object in a bucket, an uploaded asset, a queue message, a paid API artifact, a
tenant-level identifier. Two properties matter and they are independent:

- **Reclaimable vs permanent.** A *reclaimable* resource has a working delete path the project
  controls. A *permanent* resource does not — either no delete verb exists, or the delete verb is
  refused, or "delete" only moves it somewhere it still exists. Permanent resources accumulate
  forever, and the count is a number the project must be able to state.
- **Cheap vs costly.** Irrelevant to this doctrine. Consent is about **irreversibility**, not
  about money. A free permanent artifact still needs consent; an expensive reclaimable one may
  not.

**Why this sheet exists.** Live resources are the one class of work where a mistake cannot be
reverted by `git`. Every other discipline in this kit can be repaired by a commit. This one
cannot, so it is the only place where the kit puts a **refusal** in the execution path rather
than an instruction in a document.

---

## § A — The pattern

### A.1 — Budgets are declared and committed BEFORE the first spend

Before a run creates its first live resource it writes down, **in a commit**: the **ceiling**
(the most it may create), the **intent** (how many it expects to), and **what each one is for**.
The declaration lands first; the spending happens second. Afterwards the run states the **actual
count and every identifier**, against the declaration.

The reason is not bookkeeping. A budget declared afterwards is indistinguishable from a
description of what happened, so it cannot fail — and a limit that cannot fail is not a limit.
A budget committed first also survives the leg that spent it: the next reader can tell an overrun
from a plan.

**Corollaries.**

- **An overrun is disclosed, not absorbed.** "Spent 3 of a ceiling of 3, intended 2" is a clean
  record. Silence about the third is the defect.
- **A budget belongs to an issue, not to a session.** The authorizing text lives in the issue
  file, where a reviewer can read it cold.
- **Ceilings are per-class.** A permanent-artifact ceiling and a reclaimable-object ceiling are
  different numbers with different owners; one budget covering both hides the class that matters.

### A.2 — The permanent ledger is built from committed evidence, never from memory

The running total of permanent resources is **re-derived from committed artifacts** — the request
and response records a run captured, the ledger file a harness writes — and never carried in a
handoff sentence, a summary object, or an agent's recollection.

- **A number that cannot be rebuilt from the evidence does not ship.** If the only source for a
  total is a roll-up nobody can re-derive, the total is not a measurement.
- **A roll-up's own counter is not a total.** Instrumentation counts what it saw, in the window it
  saw it; treating it as the tenant-wide figure is the most common way these numbers go wrong.
- **State the decomposition, not just the sum.** `8 + 5 + 2 + 2 = 17` is auditable; `17` is a
  rumor. Each addend names the run or phase that produced it.
- **Frame-scoped statements are marked as such.** "The ledger's eight becomes ten" can be true
  inside one handoff's frame and false as a project-wide total. When the wider total lands, the
  narrower statement is **superseded with its reason preserved**
  ([`supersession.md`](supersession.md)) — not deleted.
- **Keep the classes separate.** Permanent artifacts and reclaimable objects are counted in
  different columns, forever. Merging them produces a total that answers no question.

### A.3 — Selection and consent are two different questions, and each needs its own fence

Most harnesses have a way to **not run** the dangerous tests by default: a marker, a tag, a
deselection in the runner's config. That is a fence **on selection**, and it is necessary. It is
not consent, and it is trivially cleared — usually by someone chasing an unrelated goal who
overrides the runner's default options for one command.

So the pattern is **two fences**:

- **Fence 1 — selection.** By default the destructive tests are not selected. Clearing this is a
  normal, sometimes legitimate act (a full inventory of what exists, an artifact regeneration).
- **Fence 2 — consent, at the ring itself.** The harness **refuses to execute** any
  destructive-marked test unless the run carries an explicit authorization, whatever the
  selection state. Not a warning. A refusal, with a **loud, named skip** that says which variable
  is missing.

**Clearing the deselection must re-select without arming.** That is the whole point: the two
questions are answered by two mechanisms, and the cheap accident only defeats the cheap fence.

### A.4 — Consent carries the AUTHORIZING ISSUE ID, never a boolean

The consent variable's value is **the id of the issue that authorized the work**:

```
<PROJECT>_LIVE_WRITE_AUTHORIZED_BY=<PREFIX>-NNN   <run the destructive suite>
```

- **Unset ⇒ loud skip** naming the variable. **Set to something that is not an issue id ⇒ loud
  skip saying so.** Never a silent run, and never a silent pass either.
- **Nothing auto-sets it.** The environment template ships the line **commented out**, so a fresh
  clone's setup leaves the ring unarmed. A default-armed fence is not a fence.
- **The echo is a recorded claim, not a permission check.** There is no allow-list of ids; the
  authority is the PM's word in the named issue file, and the reviewer reads both. What the
  variable buys is that the authorization becomes **part of the transcript** — the command that
  did the thing names the document that permitted it.

**Why an id and not a flag: this is the earned part.** A boolean is typed by muscle memory and
means nothing when read back. An id cannot be typed without knowing which issue is being invoked,
and it converts an untraceable act into an attributable one. In the donor project **both**
incidents that produced this fence involved a *typed flag* on a run whose author was thinking
about something else entirely (§ C). The fence's teeth are that the flag now has to be a
sentence about authority.

**And the id authorizes ONE ITEM'S spend, so a FULL-SUITE run is its own spend.** The fence above
makes every destructive run attributable; it does not bound how much a single attribution may buy.
Running the **entire** live suite under one item's id charges the whole suite's resource budget to a
single item's authority — the id is honest, the accounting is not, and the item's declared ceiling
was never written for the suite.

- **Default to the targeted selection the item actually needs.** An item that authorized one ring
  gets one ring; the consent id is not a site licence.
- **Run the full suite at phase boundaries as its own budgeted, recorded decision** — declared like
  any other spend (§ A.1), with its own ceiling and its own authorizing record.
- **And if a run overspends, state it rather than absorb it.** The donor project's one budget overrun
  came precisely from full-suite runs under single-item ids; it was disclosed and fully reclaimed, and
  **the disclosure is why it stayed a footnote instead of becoming an incident.** An overrun quietly
  absorbed is a ceiling that has stopped meaning anything.

*(This rule arrives from a fix program rather than from a round:
[`fix-execution.md`](fix-execution.md) § A.10, which is where its phase-boundary half is stated in
context.)*

### A.5 — The instrument beats the self-report

**Self-reports are not measurements.** Between every leg of a run, a cheap instrument reads the
state that destructive work would move:

- the **hash and byte size** of the resource ledger, plus the per-class row counts;
- the tree, the board, and the remote (the rest of the between-leg belt — see
  [`orchestration.md`](orchestration.md)).

Any movement outside a leg that **declared** live work is a breach: stop the leg, quarantine,
record. A hash that did not move is also a reading, and worth recording — an unmoved hash at
twenty boundaries is what makes a single movement legible.

**The asymmetry is the lesson, and it generalizes far past live resources.** In the donor's worst
case, three legs' self-reports and two complete independent reviews all missed a breach that a
two-line hash check found (§ C.2). Reviews check the work that was described to them; instruments
check the world. Both are needed, and only one of them notices work nobody described.

A leg's self-report can be honestly wrong without being deceptive — a leg that never connects a
slow run to having fired a ring reports "no live work" in good faith. Design for that: the cure
for an honest wrong report is an instrument or a refusal, never a sterner instruction.

**Where else this generalizes, now that somewhere else needed it:** the same asymmetry applied to a
**participant** in front of your product — whose self-report is the *conclusion* under study — is
[`dogfooding.md`](dogfooding.md) § A.3; the same asymmetry applied to a **dispatched worker**, whose
report is the only account of work nobody watched, is
[`subagent-control.md`](subagent-control.md) § A.4; and the question of whether your instrument can
see anything at all is [`instruments.md`](instruments.md).

**The two shapes a report fails in, which are worth knowing by name because the fix differs.** A
report is honestly wrong in one of two ways: **a green whose scope is smaller than it appears** — the
check passed because it could not see the case, not because the case is fine — or **a count, hash or
figure quoted rather than derived**, accurate at some earlier moment. The first is answered by asking
what the check *could* have caught; the second by re-deriving the number. Both are answered in advance
by **requiring a report to carry its own evidence**: the runner's raw summary, **the exit status read
without laundering it through a filter**, the transcript. A claim arriving without its evidence is
unverified by definition, and saying so in the brief up front costs nothing.

### A.6 — Reclaimable resources self-delete, and the teardown proof is part of the result

A harness that creates reclaimable objects **deletes them in its own teardown** and records the
teardown outcome — the delete call's own response, plus a **read-back** proving absence. "Deleted
14 of 15" with the 15th unnamed is not a result.

- **An object that never reached teardown is an orphan, and it is named.** Identifier, title,
  state, and *whose it is to reclaim*. A count cannot be reclaimed.
- **The next run flags orphans.** Enumeration of leftovers is part of the harness, not a habit —
  and the enumeration must be **unable to lose** an orphan: order any pre-filtering so that a
  surviving object cannot be filtered out of the probe set by a flag that was set before it
  survived.
- **Reclaim by ENUMERATING THE CONTAINER, never by replaying a registry of what was created.** An
  enumeration cannot miss what the creating leg forgot to register; a registry always can. This is
  not a preference between two equivalent mechanisms: a registry is a record of *intentions the
  harness knew about*, and the objects that hurt are the ones nothing knew about. Two consequences
  follow immediately — **anything created outside the enumerated container is invisible to the
  sweep and must be handled by name**, and **anything you cannot delete is named, not quietly
  left**, including residue an earlier run left you. *(Sharpened from a dogfooding round, where the
  creating party is a **participant** rather than the harness — see
  [`dogfooding.md`](dogfooding.md) § A.10. A participant forgets, improvises, names things its own
  way and abandons work halfway, which is the same failure the general rule now assumes.)*
- **Deleting someone else's orphan is itself a destructive act.** A run that finds an orphan it
  did not create **names it and stops** — it does not improvise a cleanup, because an improvised
  delete is exactly the unconsented destructive act this doctrine exists to prevent.
- **"Trash is not purge."** If the platform's delete only moves the object to a recoverable
  state, the object still exists and is counted. Say which verb was used and what it actually did.

### A.7 — Every destructive send names an object the sending leg created

The never-touch rule: a destructive call may only name an object **the sending leg made itself**.
This is **machine-checked from the captured requests**, not asserted in prose — the check is
mechanical (does each mutating request's target identifier appear in this leg's own creation
records?) and its result is reported as a count of violations, expected zero.

- Prefer a **naming convention** for created objects (a distinctive disposable prefix) so a
  stray target is visible at a glance, and so an audit can enumerate the class later.
- Read the convention **from the harness source** rather than retyping it; an ad-hoc prefix
  invented in one leg breaks every later enumeration, and is a disclosable defect in itself.

### A.8 — A measured absence is a result, and one path's measurement never carries another's claim

Probing for a capability that turns out not to exist is a **legitimate close**: "we sent every
spelling of the destructive verb we could construct; none succeeded; here are the requests and
the responses". Two rules keep it honest:

- **Enumerate from the evidence, in the closing leg, independently.** Distinct request spellings,
  total sends, how many succeeded, how many objects, how many captures. Re-derived from the
  captures by *both* the closing leg and the reviewer — not inherited from an earlier leg's
  summary.
- **A measurement on one path does not close another path.** If a claim spans two surfaces, both
  surfaces are measured or the claim is scoped to the one that was. This is the single most
  common way a measured-absence close over-reaches.
- **Correct a mislabelled capture BY MEASURING AGAIN, never by editing the capture.** Evidence is
  append-only; a correction is a new record that supersedes the old one and says so.
- **Disclose the capture defects.** A missing script, a misleading verdict envelope, an unlabelled
  send: disclosed as provenance gaps in the same document that draws conclusions from them.

### A.9 — A capability probe never ships the verb

Discovering that a destructive operation *is* possible does not authorize shipping it. The probe
closes; **shipping the capability is a separate decision** with its own issue and its own consent.
Keeping these apart is what lets a project explore its platform's limits without quietly growing
a dangerous feature.

### A.10 — The structural cure beats the instruction, and it lands in the same run

When an incident shows a fence is missing, the fence is **built** — and the best evidence in the
donor's history is that the run which breached a fence also **landed the fence** (§ C.2). An
instruction that every brief quotes and that fires anyway has already told you it is the wrong
instrument.

**This section states one side of a boundary, and the boundary is
[`fix-execution.md`](fix-execution.md) § A.5b.** Everything here is about **irreversible** acts —
external resources, real credentials, objects a project cannot delete — where a mechanism is owed
without argument, which is why this sheet states it flatly. That is not a general licence to build
machinery: § A.5b carries the other half (*silent and compounding*), the counterweight
([`subagent-control.md`](subagent-control.md) § C's caution about accumulating process), and the two
tests that decide it. Cite § A.5b when the act is **not** irreversible and you still think a
mechanism is owed.

**Verify a fence in the condition its own tests cannot reach.** A safety fence's test suite
usually cannot arrange the dangerous state (real credentials present, authorization absent) — so
the conductor arranges it by hand, once: plant an inert destructive-marked case in a brand-new
file with no registration anywhere, run with credentials available and the consent variable
unset, and confirm the **loud skip naming the variable** plus an **unmoved ledger**. A fence
tested only where it is easy to test is a fence of unknown strength.

**And check the fence's own exemption seam.** If a fence carries an exemption list, ask whether an
exemption can be *smuggled* — whether a bad-faith or careless entry keeps the guard green. A
guard that asserts "these files are candidates" but never "these files are not exempt" polices a
class it cannot see.

---

## § B — Project duties — filled by the adapter

> **This section is `<fill-in>`. The doctrine above binds nothing until it is filled.** State the
> instance, in this project's own vocabulary — and nothing more; do not restate § A here.

1. **The resource classes this project can create**, one row each: what it is, **reclaimable or
   permanent**, how it is deleted (or that it cannot be), and where it is counted.
   `<fill-in>`
2. **The ledger file(s)** the harness maintains, by path, and what a row means. `<fill-in>`
3. **The current permanent total, with its decomposition and the evidence each addend rests on**
   ([§ A.2](#a2--the-permanent-ledger-is-built-from-committed-evidence-never-from-memory)).
   `<fill-in>`
4. **The selection fence** — how destructive tests are deselected by default, in the runner's own
   configuration, quoted. `<fill-in>`
5. **The consent fence** — the exact variable name, where it is wired, the exact refusal message,
   and the fact that the environment template ships it commented out. `<fill-in>`
6. **The command**, verbatim, for an authorized destructive run. `<fill-in>`
7. **The disposable naming convention** and where in the harness it is defined (read it from
   there, never retype it). `<fill-in>`
8. **The orphan enumerator** — what it is called, what it probes, and its cost model (how long a
   full sweep takes, and how that scales with ledger size, because a sweep nobody can afford is a
   sweep nobody runs). `<fill-in>`
9. **The belt reading** — the exact commands that read the ledger hash and row counts between
   legs. `<fill-in>`
10. **Who authorizes** a budget and a destructive run in this project (which role, recorded
    where). `<fill-in>`
11. **The credential separation** — if read and write access use different credentials, state the
    separation and that the destructive credentials are only ever used against disposable
    targets, never a real one. `<fill-in>`

---

## § C — Worked example from the donor project (anonymized)

> Kept because the reasons transfer even though the platform does not. The donor was a library
> talking to a third-party hosted-document service; substitute your own external system.

### C.1 — The permanent class, and a budget that worked

An issue set out to answer "can we delete the uploaded artifacts this library creates?" — a
question that could only be answered by creating artifacts and trying. The relevant property of
that platform: uploaded media artifacts had **no working delete path at all**, so every probe
minted something permanent.

What went right, and is now the pattern:

- The authorizing decision **granted an explicit ceiling** ("at most three more permanent
  artifacts, inside the pre-approved ten of which two are spent"), and required the count to be
  **declared before the first send**. The executing leg declared "ceiling 3 / intended 2" in a
  commit, spent exactly two, and **named both identifiers**.
- The close **re-derived every number from the captured requests and responses** rather than from
  the harness's own summary object — whose call counter, it noted explicitly, "is not a total".
- The permanent running total was published **as a decomposition** (`8 + 5 + 2 + 2 = 17`, later
  19), each addend naming its phase; an earlier handoff's narrower figure was **superseded with
  its reason preserved** rather than quietly replaced. The recoverable-object class was kept in a
  separate column.
- The close was a **measured absence** — nine distinct spellings of the destructive verb, fourteen
  sends, zero successes, on **both** surfaces the issue's title covered, because a prior ruling
  had established that *one path's measurement cannot carry the other path's claim*.
- One earlier capture had been **mislabelled**; it was corrected **by measuring again**, and three
  capture-quality defects were disclosed in the same document that drew conclusions from them —
  including one envelope that would have told a skimming reader a positive control had failed when
  it passed.
- Finding a route would **not** have shipped a delete verb: the standing gate was that no
  destructive capability ships in the run that discovers it.

The residue: **one process-level miss worth naming.** That issue's park had no fresh-eyes review —
the resuming leg audited the dead leg's work and nobody audited the resuming leg. The remedy
became standing: the close runs as its own implementer → **fresh-eyes reviewer** legs, and *both*
re-derive the enumeration from the evidence rather than inheriting a roll-up.

### C.2 — The reclaimable class, and a fence that did not exist yet

A refactoring run forbade all live work: zero destructive resources, zero writes. The instruction
was in the pack, and **every brief in the run quoted the specific trap** — never clear the
runner's default option string on an executing run.

A review leg needed a complete inventory of the project's test identifiers, which legitimately
requires clearing that option string. It cleared it **on a run that executed tests** rather than
on a collect-only run. Clearing the deselection re-selected all three live rings, one of which
**self-provisions objects**. Fifteen disposable objects were created inside three minutes, all
under one session id. Fourteen self-deleted. **The fifteenth never reached teardown and was still
live at close**, named in the run report for the operator to reclaim.

What the incident actually taught:

- **The self-report was wrong without being deceptive.** That leg reported "no live rings run
  (correctly inapplicable)" while its own action had created fifteen objects. It never connected
  its own seven-minute run — against a normal one-minute suite — to having fired a ring.
- **Three legs' self-reports and two complete independent reviews missed it. A two-line hash
  check found it.** The ledger had been hashed before the run and re-read after every leg; it
  moved exactly once, and was byte-identical at all twenty later boundaries.
- **The documented instruction was not the missing piece; the missing piece was a refusal.** The
  cure was minted mid-run and **landed in the same run**: the destructive ring now refuses to
  execute without the authorizing-issue variable, whatever the selection state, with a loud named
  skip at the ring. The conductor verified it in the condition the fence's own tests could not
  arrange — real credentials present, variable unset, an inert destructive-marked case planted in
  a brand-new unregistered file → a skip naming the variable, ledger unchanged.
- **The orphan was left alone, deliberately.** Deleting it would have been an unconsented
  destructive act by a run whose whole premise was zero live work. It was named instead, and the
  enumerator's ordering was later fixed so that a *surviving* object can never be filtered out of
  the probe set.
- **The blast radius was reported as precisely as the breach.** The permanent class was never
  touched — its row count was identical from open to close — and saying so is what made the
  incident bounded rather than alarming.

**The two incidents together are why consent is an id and not a flag.** Both were a *typed flag*
on a run whose author was thinking about something else.
