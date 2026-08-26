<!-- KIT-CLASS: KIT — the round-pack shape. Copy, fill the <slots>, delete every GUIDANCE line. -->
# Round pack template — the pre-registration for one dogfooding round

> **GUIDANCE — how to use this file.** Copy it to
> `dev/rounds/<YYYY-MM-DD>-<round-name>/pack.md`, fill every `<slot>`, and **delete every line
> that starts with `GUIDANCE`**. The doctrine is
> [`../doctrine/dogfooding.md`](../doctrine/dogfooding.md); this file is how a round is *committed
> to* before it runs.
>
> **This is a PRE-REGISTRATION, and that is the whole point.** Every slot below is a decision that
> becomes unfalsifiable once results exist. A budget written afterwards cannot fail, so it is not a
> limit (§ A.10). A scenario's *"what this measures"* written afterwards is a description of what
> you found. **This file lands in a commit before the first participant is dispatched**, and the
> report grades against it.
>
> **A ROUND is not a RUN.** A launch pack commissions work; this commissions a **measurement**. If
> what you actually want is issues driven to landing, you want
> [`launch-pack.template.md`](launch-pack.template.md).
>
> **Size discipline.** One screen per section. Standing rules live in the doctrine sheets and are
> **cited, never restated** — a copy here goes stale and wins arguments it should lose.

---

## The STATUS banner — first block in the file, and it has a lifecycle

> **GUIDANCE.** Same lifecycle as a launch pack: authored `LIVE`, stamped `SPENT` at close against
> the report **by name**, in the same commit that lands the report. **Never rewrite the original
> wording** — the conclusion is superseded, the wording is preserved
> ([`../doctrine/supersession.md`](../doctrine/supersession.md),
> [`../doctrine/staleness.md`](../doctrine/staleness.md)).

```
> **STATUS: LIVE — not yet run.** Dogfooding round: **<round name>**.
> <N> scenarios, <M> participants. Subject: <the shipped surface under study, at <version/commit>>.
> Wake condition: <the observable thing that made this the moment>.
> Report will be: `dev/rounds/<date>-<name>/report.md`.
```

---

## 1. The round's question

> **GUIDANCE.** One sentence, in the form *"does someone who needs X find it, trust the answer, and
> recover when it refuses?"* Then **the question this round is NOT asking**, which is what stops a
> round drifting into a test suite (§ A.1). If your question can be answered by running the test
> suite, it is a test — stop here and write a test.

**We are asking:** <one sentence>.
**We are NOT asking:** <the capability question adjacent to it — "can the product do X" — plus
anything deliberately out of scope>.

**What the subject is, exactly:** <the artifact a participant receives, at a stated version or
commit — "only what ships" has to be a specific set of bytes, or the round is ungradeable>.

---

## 2. Participants and tiers

> **GUIDANCE.** Who meets the product, and **what each tier is blind to**. Tiers exist so an
> inversion is legible (§ A.3: a more capable participant may report *partial* success where a
> weaker one reports success and is wrong). State provisioning per tier if participants are agents
> ([`../doctrine/model-provisioning.md`](../doctrine/model-provisioning.md)) — and remember
> participants are **leaves**: a participant does not spawn helpers.

| Tier | Who / how provisioned | What they hold | What they are blind to |
|---|---|---|---|
| `<tier>` | `<…>` | `<the shipped artifact + nothing else>` | `<the round's own documents; the source; …>` |

---

## 3. The scenario matrix

> **GUIDANCE.** One row per scenario, and **three columns that are each a known failure mode**:
> *Measures* must say which of **what they achieved** or **what they chose** it grades — and if it
> grades a choice, the prompt hands over an **intent, never a prepared artefact** (§ A.9).
> *Fixture precondition* is the state the fixture must be in for the scenario to be measurable, and
> **how that state is verified before the leg starts** — a fixture that already satisfies the task,
> or that supplies what the scenario withholds, returns green having graded nothing (§ A.8). Treat a
> consumed fixture as **spent**.

| # | Scenario | Measures (achieve / choose) | Fixture precondition + how verified |
|---|---|---|---|
| S1 | `<what the participant is asked to accomplish>` | `<achieve\|choose>` — `<the specific thing graded>` | `<required state>` — verified by `<command or read>` |

**Provocations, if any** (§ A.4): `<the disturbance, when it lands, and which scenarios get it>`.

---

## 4. Instruments — and each one's named blind spot

> **GUIDANCE.** [`../doctrine/instruments.md`](../doctrine/instruments.md) binds here in full. Per
> instrument: what it watches, its **blind spot named in its own output**, and the **ablation** that
> proves it can fail. An instrument with no ablation is listed as **unproven, not passing**. Take
> each one to the messiest realistic behaviour — or better, to a **previous round's real leftovers**
> — before believing it.
>
> **The delivery instrument is special (§ A.4): it may never judge the response.** Give it a
> contract it can satisfy *physically* and terminal states that carry no verdict —
> *delivered* / *not delivered* / *failed to deliver*. If a terminal state can be read as "the
> participant handled it well", delete the inference and keep the delivery proof.

| Instrument | Watches | Named blind spot (and where it is printed) | Ablation evidence |
|---|---|---|---|
| `<name>` | `<…>` | `<…>` — printed in `<its own output line>` | `<how it was watched failing, or "UNPROVEN">` |

**Delivery instrument contract:** `<the physical claim>`. **Terminal states:** `<…>`. **None of
them means the participant handled it well.**

---

## 5. Isolation

> **GUIDANCE.** §§ A.6 and A.7. The participant receives **only its task, extracted** — never a
> pointer into the document that also holds the other tasks and the rubric. Then audit the whole
> observable surface **outermost first**: parent path, path, container name, configuration keys,
> object titles, neighbours in the same folder, *then* contents. The container you renamed may sit
> inside one you did not. Any irreducible leak becomes a **measured covariate**, not a hope.

- **Extraction method:** `<how each task is extracted, and who audits the extracted text for
  round-revealing vocabulary>`.
- **Container audit, outermost first:** `<parent path>` → `<path>` → `<container name>` →
  `<config keys>` → `<titles>` → `<neighbours>` → `<contents>`. Audited by `<who/what>`.
- **Declared covariates** (irreducible leaks): `<the leak>` — recorded per participant as
  `<observed? reacted?>`.

---

## 6. Resource budget, fences, and the leftovers ruling

> **GUIDANCE.** [`../doctrine/live-resources.md`](../doctrine/live-resources.md) § A.1 (budget),
> §§ A.3–A.4 (the two fences: selection is not consent; consent carries the **authorizing
> work-item id**, never a boolean), § A.6 (teardown proof = the delete's own answer **plus a
> read-back proving absence**). Reclaim **by enumerating the container**, never by replaying a
> registry — in a round the resources are created by *participants*, who forget, improvise and
> abandon (§ A.10).
>
> And rule the tension deliberately: § A.2 wants the previous round's leftovers as instrument test
> material, while the sweep wants them gone. Decide **per class, here, before the round.**

| Class | Ceiling | Intent | What each is for | Reclaimable? | How reclaimed (enumeration target) |
|---|---|---|---|---|---|
| `<class>` | `<n>` | `<n>` | `<…>` | `<yes/no>` | `<the container enumerated>` |

- **Consent:** `<the variable, carrying work-item id `<PREFIX>-NNN`, or "no live resources — zero,
  stated absolutely">`.
- **Leftovers ruling:** kept as instrument fodder → `<classes + where they are kept so the sweep
  does not eat them>`; swept → `<classes>`.
- **Inherited residue we cannot delete:** `<named, or "none">`.

---

## 7. Measures — unit and basis, declared now

> **GUIDANCE.** § A.12: a measure defined before the round can score the **opposite** of what it
> intended (a count of *"times the participant dug into internals"* punishes the one who verified
> and rewards the one who guessed right). State **unit and basis** per measure, and say now how
> **inter-rater reliability** will be checked — a measure two graders score differently cannot
> decide anything.

| Measure | Unit | Basis (what one count counts) | Known perverse reading |
|---|---|---|---|
| `<name>` | `<…>` | `<…>` | `<what it would reward that we do not want>` |

**Inter-rater check:** `<which artefacts get two independent graders, and what disagreement means>`.

---

## 8. Grading protocol — who, and in what order

> **GUIDANCE.** § A.3 (re-verify independently against the artefact), § A.5 (**grade cold, then
> reconcile, auditably**), § A.14 (the consolidation is attacked by someone who did not do it).
> The hats are the project's existing cast; name the actual instances so nobody grades their own
> delivery.

| Duty | Hat | Who |
|---|---|---|
| The question, the matrix, the ceiling, and every **remedy** decision (§ A.13) | PM | `<…>` |
| Delivery + dispatch in isolation | Orchestrator / the seat | `<…>` |
| Independent re-verification against the artefact; **cold** grading | QA | `<…>` |
| Attacking the consolidation — **never whoever consolidated** | second QA leg / the seat | `<…>` |

**The auditable ordering (§ A.5):** cold grading lands as its own commit with the findings register
**unopened**; the register is opened only after that commit exists; the reconciliation lands as a
second commit that **appends and removes nothing**. `<state the two commit subjects you will use>`.

---

## 9. Halting policy

> **GUIDANCE.** § A.17, and it is short because the judgement is trusted: severity is the
> participant's and grader's call on the project's normal ladder. Restate only the three
> consequences, so nobody improvises them mid-round.

Severity uses the project's ladder (`<Blocker | Critical | Major | Minor>`). On a **Blocker or
Critical**: that scenario **halts** (no pressing on, no improvised workaround); it is **escalated
now, not at the close**, to `<who>`; and **every scenario the blocker does not touch continues**.
The report names each halted scenario and states what was therefore **unmeasured, not passed**.

---

## 10. The report, and the close conditions

`dev/rounds/<date>-<name>/report.md`, to the shape in
[`round-report.template.md`](round-report.template.md), **indexed in `dev/README.md` at close**.

**Close conditions:** this pack stamped **SPENT** against the report by name; every scenario either
graded or named as halted/unmeasured; the resource accounting reconciled against § 6 with orphans
named; the round's own defects filed in their own section (§ A.15); the consolidation attacked and
the attack recorded; findings handed to a **real PM session** — the round mints no work items
itself (§ A.14).

---

## Author's pre-launch checklist (before any participant is dispatched)

- [ ] Every `<slot>` filled; every `GUIDANCE` line deleted.
- [ ] **This file is committed.** A pre-registration that lands after the first dispatch is a
      description.
- [ ] Every scenario says which of *achieve* / *choose* it measures, and every *choose* scenario
      hands over an **intent, not an artefact**.
- [ ] Every fixture precondition names the command or read that **verifies** it, and no scenario
      runs against a fixture a previous round consumed.
- [ ] Every instrument has a named blind spot **and** an ablation — or is listed **UNPROVEN**.
- [ ] The delivery instrument's terminal states carry **no verdict** about the participant.
- [ ] The isolation audit ran **outermost first**, and every irreducible leak is a declared
      covariate.
- [ ] Budget declared per class, with ceiling **and** intent; consent (if any) carries a work-item
      id; the leftovers ruling is made.
- [ ] Every measure states unit and basis, and its known perverse reading.
- [ ] Nobody grades their own delivery, and the consolidation's attacker is named.
