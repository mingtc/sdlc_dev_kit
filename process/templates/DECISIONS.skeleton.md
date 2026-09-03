<!-- KIT-CLASS: KIT — a blank shape. Travels unedited; every angle-bracket blank is yours to fill. -->
<!--
  HOW TO USE THIS FILE
  Copy to requirements/DECISIONS.md, fill every <angle-bracket> blank, delete the HTML comments.
  Start it on DAY ONE with zero entries. The first ruling you fail to record is the one that gets
  re-litigated.  Any version shown in an example is the deliberately fictional 42.x.
  DROP THE KIT-CLASS MARKER. The `<!-- KIT-CLASS: … -->`
<!-- LINKS IN THIS FILE ARE RELATIVE TO WHERE IT LANDS — requirements/ — NOT to the directory it
     sits in. A link written for where the template SITS resolves while you read it here and
     is dead in every copy an adopter makes: it passes a link check run in the kit and fails
     the only reader who matters. The self-test reads this line to know where to resolve from,
     so keep its shape. -->
 line at the top of this file classifies
  it FOR THE KIT (does this artifact travel, and which half of it does). It is kit bookkeeping,
  not your project's: delete it from your copy, or replace it with your own classification if you
  are re-cutting a kit from your repository. The same goes for every template you copy.
  LINKS are written for this file's DESTINATION, which is requirements/ — so a process/ target is
  spelled `../process/…` and resolves the moment you copy this file there. They therefore do NOT
  resolve while the file still sits in process/templates/, and that is expected, not a defect.
  (PROJECT.md and CLAUDE-adapter.template.md state the same convention for their own
  destination, the repository root, where the same targets are spelled `process/…`.)
-->
# DECISIONS.md — the standing rulings, as they stand today

> **Pattern vs instance.** The **pattern** is **format law and travels**: stable ids that are
> **retired rather than reused**; every entry exactly three things (the current ruling in the
> present tense, one line of why, provenance); the register as a **projection of current state**,
> with history left in the ledger; and one anchor convention. The **instance** — every ruling in
> the table — is **your project's content**, and travels to nobody. Keep this note in your copy.
> *(The same split is stated in [`process/EXTRACTION.md`](../process/EXTRACTION.md) § 1.2.)*

**What this file is.** The one place that answers **"what is currently true?"** for the rulings
that govern <project>. It is a corpus member — your `CORPUS.md` manifest should list it, as a row
of that manifest's **four** columns (`Entry | Kind | Status | Why it is corpus`, the shape
`CORPUS.skeleton.md` ships) — and its job is to **remove arbitrary choices**: every entry is a fork
where a reader would otherwise pick something defensible and wrong.

**Every entry is exactly three things.** The **current ruling**, present tense, stated as law.
**One line of why** — the reason, not the history. **Provenance** — where it was ruled and where
the evidence lives. An entry that needs a paragraph does not get one here: the paragraph belongs in
the ruling's home document and the entry points at it.

**A ruling sourced from a CONVERSATION may not be its own evidence.** Where the authority is
something said rather than something written, Provenance carries a pointer to a **primary artifact**
— a dated record quoting the words, with whatever locator that record supports — minted at ruling
time, in the same change as the entry. *Why:* measured, and it stopped a run: an amendment cited a
quotation and an authorization that existed **nowhere in the repository except the amendment
itself**, in a file read as law at every session start. The reviewer could not tell a real ruling
from an invented one, correctly refused to proceed, and demoted both claims to provisional. Circular
provenance is indistinguishable from fabrication **by construction**, which is why the pointer is
owed at mint time and not on request: afterwards, the conversation is gone and nobody can supply it.

**Where that primary artifact LIVES.** A dated record at your working-records root —
`<YYYY-MM-DD>-<slug>.md` — indexed by [`../dev/README.md`](../dev/README.md) § *Reports, assessments,
and probe findings* **in the same change that creates it**, because that index is bidirectional and a
file reachable from no row is as lost as one that was never written. This is the same relationship a
probe capture has to the entry it grounds ([`../process/templates/CAPTURE.template.md`](../process/templates/CAPTURE.template.md)),
generalised off the probe case: the rule was always *point at a primary artifact*, and the one thing
it never said was where to put one.

**A ruling about to be EXECUTED owes three more things — inside those same three fields, never as a
fourth.** A ruling that only describes the world can be tidied later; one that a slate of work is
about to be built on cannot.

- **Recorded before it is executed**, and *a ruling is not recorded until it is in the file the work
  will be done from.* The surfaces that do not count — a prompt, a chat, a coordinator's memory, a run
  log, a message to a peer — are enumerated once in
  [`../process/doctrine/fix-execution.md`](../process/doctrine/fix-execution.md) § A.2 rather than
  here, because two copies of one list is how the two start disagreeing about what a surface is.
  Record it first; the items then cite this entry as their authority rather than restating it.
- **Verbatim, in the decider's own words** — in the **Ruling** field. A paraphrase is a second
  authoring site, and the paraphrase is the copy that drifts. Where the decider hedged, the hedge is
  part of the ruling: it is what tells a later leg the ruling may be reopened on evidence.
- **What was explicitly NOT ruled, named in Provenance beside what was.** Otherwise a skipped
  question is indistinguishable from a settled one, and whoever needs an answer first adopts the
  default silently. *(The § Findings section below is where an unruled question lives if it needs
  more than a clause.)*
- **And where the ruling sets an ORDER, the Why states what breaks if the order is reversed** — not
  the sequence alone. A reader who can see the consequence can also tell when the constraint has
  stopped applying.

*(Doctrine: [`process/doctrine/fix-execution.md`](../process/doctrine/fix-execution.md) § A.2.)*

**Ids are stable.** `D-NN` is a permanent handle. When a ruling is removed the id is **retired,
never reused**, so a citation elsewhere can never silently come to mean something else.
<!-- ID WIDTH: zero-padded TWO digits (D-01 … D-99) until the register passes 99, then plain
     (D-100, D-101 …). Do not re-pad the old ids when that happens; the handle is the string.
     MINTING IS A READ, NOT A GUESS: a concurrent landing must check the file's actual next-free
     number at landing time — not the last heading above its own insertion point — or cite the
     work-item id alongside the D-NN in the same commit, so a same-day collision stays
     disambiguable. (Measured: two same-day landings both minted the same id, each reading the
     file correctly as it stood. Contract: process/contracts/id-minting.md § 2.)
     AND DO NOT DERIVE THE MAXIMUM BY HAND. This register is grouped by SECTION, so a later id
     sits ABOVE an earlier one and the last `### ` heading in file order is NOT the highest id —
     read as one it proposes an id that already exists. The board's drift report prints the true
     maximum for every declared register (drift-report.md invariant 4); take it from there. A
     recipe copied into this header would be one more derivation to get wrong, and the two that
     were got wrong in one landing set were both hand-written greps. -->

**Anchor convention.** Prefer a **section anchor** (`<doc> § <section>`) over a bare `file:line`
into anything that still evolves — a line anchor drifts silently on the next edit above it.
Reserve line anchors for **append-only** ledgers. *(Doctrine:
[`process/doctrine/lookup-tables.md`](../process/doctrine/lookup-tables.md) § A.4.)*

**And STAMP THE TREE the anchors were read against.** A content anchor survives an edit above it; it
does not survive the section being renamed, split or ruled obsolete. So an entry whose citations were
gathered at one moment records **which tree state they were read from** — a commit id is enough. The
stamp does not stop the rot; it makes it **detectable rather than discovered**, which is the whole
difference between a citation a reader can re-check and one they have to trust.

The same rule pointed at a *work item* rather than at a ruling — mint each phase's items after the
prior phase lands, and re-derive any inherited count on the branch rather than carrying it forward —
is [`process/doctrine/fix-execution.md`](../process/doctrine/fix-execution.md) § A.9.

**When this register grows past a screenful, it owes an index.** It is a lookup table by
construction — stable ids, a fixed three-field entry shape — which makes it the cheapest document
in any repository to index and the most expensive to read without one. Trigger and budget:
[`process/doctrine/lookup-tables.md`](../process/doctrine/lookup-tables.md) § A.1–A.2.

## This register is a PROJECTION — and that is not a licence to erase

**A superseded ruling is deleted from here, not archived here.** The register answers *what is true
now*; a list of former truths makes that question harder. The history is not lost — it lives in the
ledger (`progress.md`, the issue archive, the changelog).

This does **not** contradict the supersession ethic (*preserve the reason, supersede only the
conclusion* —
[`process/doctrine/supersession.md`](../process/doctrine/supersession.md)). That ethic governs
the **home document**, where the original reasoning stays visible and is amended rather than struck.
**Here** the same decision appears only as its current conclusion, because a projection carrying two
generations of an answer has stopped being a projection.

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

<!-- FOLDED IN from a real regeneration spike, whose whole output was "what the corpus failed to
     capture" — a lesson about the SHAPE of this file. The ritual itself:
     process/doctrine/calibration.md § A.1. -->

One project rebuilt a module from its corpus alone; the divergences that mattered were almost all
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
   thing was not done. A negative ruling carries its **enumeration or its "unmeasured" label** —
   [`process/doctrine/negative-claims.md`](../process/doctrine/negative-claims.md).

**Where it does NOT go:** a ruling with a natural home — a capability matrix row, a guide section, a
docstring — is authored **there**, and appears here only as its one-line current conclusion with a
pointer. Two authoring sites for one rule is how the two start disagreeing.
