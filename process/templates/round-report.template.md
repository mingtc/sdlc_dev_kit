<!-- KIT-CLASS: KIT — the round-report shape. Copy, fill the <slots>, delete every GUIDANCE line. -->
<!-- LINKS IN THIS FILE ARE RELATIVE TO WHERE IT LANDS — dev/rounds/<date>-<name>/ — NOT to process/templates/
     where it sits. A link that resolves while you read the template and dies in every copy of it
     passes a link check run here and is broken for every adopter. -->
# Round report template — what closes one dogfooding round

> **GUIDANCE — how to use this file.** Copy it to
> `dev/rounds/<YYYY-MM-DD>-<round-name>/report.md`, fill every `<slot>`, delete every `GUIDANCE`
> line, and **index it in `dev/README.md` in the same commit**. The doctrine is
> [`../doctrine/dogfooding.md`](../../../process/doctrine/dogfooding.md); the pack it grades against is
> `pack.md` beside it.
>
> **The deliverable is EVIDENCE, not a work plan** (§ A.13). Findings become final long before
> remedies do, and most remedies to a consumer-facing surface are product decisions rather than
> engineering ones. Keep the two apart on the page: merging them hands the decision-maker a
> conclusion dressed as a measurement.
>
> **Two sections are not optional and are the ones authors drop:** § 4 positives (a register of
> only complaints cannot tell the product which behaviours to copy) and § 7 **the round's own
> defects** (a round that hides its methodological faults cannot be trusted about the subject's).

---

## Header

```
Round: <name>          Pack: pack.md (stamped SPENT <date>)
Subject: <the shipped surface, at <version/commit>>
Ran: <date(s)>         Participants: <N> across <M> tiers
Scenarios: <N> graded · <N> halted · <N> unmeasurable
```

**The one-paragraph verdict.** <What a reader who stops here must know: the dominant finding class,
and whether the round's own instruments held. Do not lead with counts.>

---

## 1. Findings

> **GUIDANCE.** One block per finding. **Evidence is the artefact, not the participant's account of
> it** (§ A.3) — a document read, a record queried, an output diffed. Where the participant's claim
> and the measurement disagree, **record BOTH** and say which you believe and why: the gap between
> what the product made someone believe and what it did *is* the finding, and deleting the claim
> destroys it. Expect **inversions** and say so when you see one.
>
> Severity uses the project's ladder. **State findings and remedies separately** (§ A.13) — a
> finding is settled by evidence; a remedy is a decision, and it is the PM's.

### F<n> — <one line: what happens>

- **Scenario / participant:** `<S<n>` / `<tier>`>
- **What the participant reported:** <their claim, quoted where it matters>
- **What the artefact shows:** <the independent measurement, and how it was taken>
- **Verdict:** <which you believe, and why> `<+ "INVERSION" if a stronger tier scored worse>`
- **Severity:** `<…>` · **Class:** `<documentation | error text | naming | default | engine>`
- **Remedy status:** `<OPEN — PM decision>` / `<proposed: …, and by whom>` — never presented as
  part of the finding

---

## 2. What the findings are mostly about

> **GUIDANCE.** § A.1's corollary is a check on the round itself: most findings from a good round
> are about **words** — documentation, error text, naming, defaults. If this table is dominated by
> engine bugs, say so plainly and treat it as a signal that the scenarios were **tests wearing a
> round's clothes**. That admission belongs here, not in § 7.

| Class | Findings | Note |
|---|---|---|
| Documentation | `<n>` | |
| Error / refusal text | `<n>` | |
| Naming | `<n>` | |
| Defaults | `<n>` | |
| Engine | `<n>` | `<if this dominates, say what it implies about the scenario design>` |

---

## 3. Measures

> **GUIDANCE.** § A.12. Every number carries its **unit and basis**; a result that depends on a
> definition says so, and the caveat travels **into the verdict** rather than leaving the number
> bare. Report the inter-rater check: if two graders scored the same artefact differently, that
> measure decides nothing and must be reported as such rather than averaged into a figure.

| Measure | Value | Unit / basis | Caveat carried into the verdict |
|---|---|---|---|
| `<name>` | `<…>` | `<…>` | `<…>` |

**Inter-rater:** `<what was double-graded, the disagreements, and which measures are therefore not
decisive>`.

---

## 4. Positives — evidenced as strictly as the defects

> **GUIDANCE.** § A.11, and it is not a courtesy section. The most useful pairing a round produces
> is a defect and its **mirror** — the same product getting the same class of thing right somewhere
> else — because it converts *"fix this"* into *"make it look like that"*, which is far cheaper to
> act on. Demand the same evidence you would of a defect.

| What worked | Evidence | Mirrors which finding |
|---|---|---|
| `<the refusal that named its own remedy / the disclosure that prevented source-diving>` | `<…>` | `<F<n>, or "—">` |

---

## 5. Consolidation — findings into PROBLEMS

> **GUIDANCE.** § A.14. N findings do not become N work items. Group by **shared fix shape**, not
> shared cause: two findings with one cause and two incompatible fixes are **two** problems; two
> findings with different causes and one fix are **one**. Then record **who attacked the grouping**
> — it is judgement, it sets scope, and it is the least-reviewed artefact a round produces. The
> attack is pointed at the judgement layer, not at the findings, which are already verified.

| Problem | Findings folded in | The one fix shape | Consumer-facing surface it touches |
|---|---|---|---|
| P<n> — `<…>` | `<F1, F4, F9>` | `<…>` | `<…>` |

**Consolidation attacked by:** `<who — not whoever consolidated>`. **What the attack changed:**
`<splits, merges, or "nothing, and here is what it probed">`.

**Handoff.** These problems go to a **real PM session**, which decides what is minted; this round
opens no work items (§ A.14). This document survives whether or not anything is minted, and it is
what later readers cite.

---

## 6. What was NOT measured

> **GUIDANCE.** The section that keeps the rest honest. **Unmeasured is not passed** — the rule
> [`../doctrine/calibration.md`](../../../process/doctrine/calibration.md) § A.3 applies to unexercised scope and
> [`../doctrine/negative-claims.md`](../../../process/doctrine/negative-claims.md) § A.1 to any claim of absence.
> A halted scenario (§ A.17) is exactly where a round is most tempted to report a green it did not
> earn.

| Scenario | Why unmeasured | What we therefore cannot claim |
|---|---|---|
| `<S<n>>` | `<halted on a Blocker — escalated <when>, to <whom>` / `<fixture unmeasurable` / `<never reached>` | `<the claim this round may not make>` |

---

## 7. THE ROUND'S OWN DEFECTS

> **GUIDANCE.** § A.15, mandatory, **and kept out of the product's work items** — these are not
> fixes to the thing under test. Two reasons it exists: a round that buries its methodological
> faults cannot be trusted about the subject, and these faults are **the next round's gates** —
> the most actionable output a round produces about itself. Typical members: a contaminated or
> already-consumed fixture; an instrument that never fired; a delivery instrument that judged; a
> measure that scored backwards; a count asserted rather than derived; an isolation leak found late.

| # | The defect | How it was found | What it invalidates | Next round's gate |
|---|---|---|---|---|
| D<n> | `<…>` | `<…>` | `<which findings or measures are weakened, honestly>` | `<the check that would catch it>` |

**Instruments that stayed UNPROVEN** (no ablation, per the pack § 4): `<named, or "none">`.

---

## 8. Resource accounting

> **GUIDANCE.** Against the pack's § 6 declaration, per class. **An overrun is disclosed, never
> absorbed.** Reclaim was **by enumerating the container**; state the enumeration target, and name
> every orphan — *"deleted 14 of 15"* with the 15th unnamed is not a result
> ([`../doctrine/live-resources.md`](../../../process/doctrine/live-resources.md) §§ A.1, A.6). Anything created
> outside the enumerated container is handled **by name**; anything undeletable is **named, not
> quietly left**.

| Class | Ceiling | Intended | Actual | Reclaimed (enumeration) | Orphans, named |
|---|---|---|---|---|---|
| `<class>` | `<n>` | `<n>` | `<n>` | `<n>` — enumerated `<target>` | `<ids, or "none">` |

**Teardown proof:** `<the delete's own answer, plus the read-back proving absence>`.
**Kept deliberately as instrument fodder** (pack § 6 ruling): `<what, and where>`.

---

## Close checklist

- [ ] `pack.md` stamped **SPENT** against this file by name, in this commit; original wording
      preserved.
- [ ] Every scenario appears in § 1 or § 6 — none silently missing.
- [ ] Every finding's evidence is the **artefact**, and every disagreement records both sides.
- [ ] § 4 positives filled — not empty because nobody looked.
- [ ] § 7 filled, honestly, and none of its items leaked into the product's problems.
- [ ] The cold-grading commit precedes the register-opening commit, and the reconciliation removed
      nothing (§ A.5 — anyone can now audit this from the history).
- [ ] Resource accounting reconciles; orphans named; undeletables named.
- [ ] Indexed in `dev/README.md`.
- [ ] Handed to a PM session; **no work items minted by this round**.
