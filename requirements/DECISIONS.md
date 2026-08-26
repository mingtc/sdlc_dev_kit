<!-- KIT-CLASS: KIT — the decision register's shape, blank. The format is law; every ruling is yours. -->
# DECISIONS.md — the standing rulings, as they stand today

> **Pattern vs instance.** The **pattern** is **format law and travels**: stable ids that are
> **retired rather than reused**; every entry exactly three things (the current ruling in the
> present tense, one line of why, provenance); the register as a **projection of current state**,
> with history left in the ledger; and one anchor convention. The **instance** — every ruling in
> the table — is **your project's content**, and travels to nobody. Keep this note in your copy.
> *(The same split is stated in [`process/EXTRACTION.md`](../process/EXTRACTION.md) § 1.2.)*

**What this file is.** The one place that answers **"what is currently true?"** for the rulings that
govern this project. It is a corpus member — [`CORPUS.md`](CORPUS.md)'s manifest lists it, as a row
of that manifest's **four** columns (`Entry | Kind | Status | Why it is corpus`) — and its job is to
**remove arbitrary choices**: every entry is a fork where a reader would otherwise pick something
defensible and wrong.

**Start it on day one with zero entries.** The first ruling you fail to record is the one that gets
re-litigated.

**Every entry is exactly three things.** The **current ruling**, present tense, stated as law.
**One line of why** — the reason, not the history. **Provenance** — where it was ruled and where the
evidence lives. An entry that needs a paragraph does not get one here: the paragraph belongs in the
ruling's home document and the entry points at it.

**Ids are stable.** `D-NN` is a permanent handle. When a ruling is removed the id is **retired,
never reused**, so a citation elsewhere can never silently come to mean something else.
<!-- ID WIDTH: zero-padded TWO digits (D-01 … D-99) until the register passes 99, then plain
     (D-100, D-101 …). Do not re-pad the old ids when that happens; the handle is the string.
     MINTING IS A READ, NOT A GUESS: a concurrent landing must check the file's actual next-free
     number at landing time — not the last heading above its own insertion point — or cite the
     work-item id alongside the D-NN in the same commit, so a same-day collision stays
     disambiguable. (Measured in the donor project: two same-day landings both minted the same
     id.) -->

**Anchor convention.** Prefer a **section anchor** (`<doc> § <section>`) over a bare `file:line`
into anything that still evolves — a line anchor drifts silently on the next edit above it. Reserve
line anchors for **append-only** ledgers.

## This register is a PROJECTION — and that is not a licence to erase

**A superseded ruling is deleted from here, not archived here.** The register answers *what is true
now*; a list of former truths makes that question harder. The history is not lost — it lives in the
ledger (`progress.md`, the issue archive, the change log).

This does **not** contradict the supersession ethic (*preserve the reason, supersede only the
conclusion* — [`process/doctrine/supersession.md`](../process/doctrine/supersession.md)). That ethic
governs the **home document**, where the original reasoning stays visible and is amended rather than
struck. **Here** the same decision appears only as its current conclusion, because a projection
carrying two generations of an answer has stopped being a projection.

<!--
  THE SHAPE OF THE REGISTER — FORMAT LAW, and it is NOT a table.
  Entries are grouped under `## <letter>. <bucket>` headings, and each entry is a
  `### D-NN — <short title>` heading followed by three bold-labelled paragraphs:
  **Ruling.** / **Why.** / **Provenance.**  A three-field table looks tidier and fails on the
  first entry whose provenance is four pointers; the heading shape also gives every ruling a
  stable anchor to cite. Buckets are separated by a `---` rule.

  BUCKET NAMES ARE NOT RESERVED. The three below are EXAMPLES; invent your own, drop these,
  reorder them. `<your-bucket>` stays in your copy as the reminder that the list is yours.
  Letter the buckets (A., B., …) so a bucket can be cited without quoting its wording.
-->

## A. Product identity & scope

### D-01 — <short title, the ruling in a few words>
**Ruling.** <the ruling, present tense, stated as law>
**Why.** <the reason, not the history — one line>
**Provenance.** <where it was ruled> · <where the evidence lives>

### D-02 — <short title>
**Ruling.** <…>
**Why.** <…>
**Provenance.** <…>

---

## B. <your-bucket — e.g. external-system truth, the measurement discipline>

### D-03 — <short title>
**Ruling.** <…>
**Why.** <…>
**Provenance.** <…>

---

## C. <your-bucket — e.g. process & workflow>

### D-04 — <short title>
**Ruling.** <…>
**Why.** <…>
**Provenance.** <…>

---

## Retired ids

<!-- FORMAT LAW: this section EXISTS from day one, even empty. `<none yet>` is the day-one
     content. An id lands here when its ruling is removed, with one line saying what it used to
     mean, so a stale citation elsewhere resolves to "retired" instead of to the wrong ruling. -->

`<none yet>` <!-- e.g. `D-07` — retired <date>; the determinism scope it held moved into D-11. -->

## Findings — what surfaced that is NOT written up as a ruling

<!-- FORMAT LAW: this section EXISTS from day one too. A rule that cannot be traced to a real
     source is REPORTED here, never paraphrased into law above; and this register never RESOLVES
     a contradiction it finds — it records both sides and names who decides. Without this section
     the only two options are to invent a ruling or to drop the observation, and both are worse. -->

1. `<what was observed, where, and what would settle it — or "none yet">`

---

## What earns an entry — the lessons from an actual regeneration

<!-- FOLDED IN from a regeneration spike in the donor project this kit was cut from, whose whole
     output was "what the corpus failed to capture" — a lesson about the SHAPE of this file. The
     lessons travel; the donor's own examples do not, and are paraphrased. -->

The donor rebuilt one module from its corpus alone; the divergences that mattered were almost all
**unrecorded arbitrary choices**. Each of the following earns a row here:

1. **A fork where two answers are both defensible.** That is the definition of an entry. If either
   choice would survive review, the register is the only thing that makes one of them true.
2. **A measured integration-time discovery** — what an external system actually does, learned by
   probing it. It is a *finding*, not an opinion, and it belongs where it is looked up, in the same
   change that discovered it. Otherwise the next reader re-probes, or worse, assumes.
3. **Consumer-visible text that is a contract** — the verbatim wording of a refusal or an error,
   where it is not already pinned in its home document.
4. **A deliberate non-answer.** *"<behaviour X> is undefined; no test may pin it"* is a ruling, and
   writing it down is what stops a regression test from asserting an accident.
5. **What must NOT happen.** The negative rulings (*"never <X>"*) are the ones a regenerating or
   newly-onboarded reader has no way to infer, because nothing in the code says *why* the obvious
   thing was not done.

**Where it does NOT go:** a ruling with a natural home — a capability-matrix row, a guide section, a
docstring — is authored **there**, and appears here only as its one-line current conclusion with a
pointer. Two authoring sites for one rule is how the two start disagreeing.
