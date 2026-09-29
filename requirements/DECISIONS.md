<!-- KIT-CLASS: KIT — the decision register's shape, blank. The format is law; every ruling is yours. -->
# DECISIONS.md — the standing rulings, as they stand today

> **Pattern vs instance.** The **pattern** is **format law and travels**: stable ids that are
> **retired rather than reused**; every entry exactly three things (the current ruling in the
> present tense, one line of why, provenance); the register as a **projection of current state**,
> with history left in the ledger; and one anchor convention. The **instance** — every ruling in
> the register — is **your project's content**, and travels to nobody. Keep this note in your copy.
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

**A ruling sourced from a CONVERSATION may not be its own evidence.** Where the authority is
something said rather than something written, Provenance carries a pointer to a **primary artifact**
— a dated record quoting the words, with whatever locator that record supports — minted at ruling
time, in the same change as the entry. *Why:* circular provenance is indistinguishable from
fabrication by construction, and afterwards the conversation is gone and nobody can supply it.

**That record lives at your working-records root** — `<YYYY-MM-DD>-<slug>.md` — indexed by
[`dev/README.md`](../dev/README.md) § *Reports, assessments, and probe findings* **in the same change
that creates it**: a file reachable from no row is as lost as one never written. **And it is the
ruling's home document**, which is what makes § *This register is a PROJECTION* safe: the register
carries the **conclusion**, the record carries the **reasoning**, and a later reader is sent there
when the conclusion changes.

**A ruling about to be EXECUTED owes more — inside those same three fields, never as a fourth.** A ruling that only describes the world can be tidied later; one that a slate of work is
about to be built on cannot.

- **Recorded before it is executed**, and *a ruling is not recorded until it is in the file the work
  will be done from.* The surfaces that do not count — a prompt, a chat, a coordinator's memory, a run
  log, a message to a peer — are enumerated once in
  [`process/doctrine/fix-execution.md`](../process/doctrine/fix-execution.md) § A.2. Record it first;
  the items then cite this entry as their authority rather than restating it.
- **Verbatim, in the decider's own words** — in the **Ruling** field. A paraphrase is a second
  authoring site, and the paraphrase is the copy that drifts. Where the decider hedged, the hedge is
  part of the ruling: it is what tells a later leg the ruling may be reopened on evidence.
- **What was explicitly NOT ruled, named in Provenance beside what was.** Otherwise a skipped
  question is indistinguishable from a settled one, and whoever needs an answer first adopts the
  default silently. *(§ Findings below is where an unruled question lives if it needs more than a
  clause.)*
- **And where the ruling sets an ORDER, the Why states what breaks if the order is reversed** — not
  the sequence alone. A reader who can see the consequence can also tell when the constraint has
  stopped applying.

**Ids are stable.** `D-NN` is a permanent handle. When a ruling is removed the id is **retired,
never reused**, so a citation elsewhere can never silently come to mean something else.
<!-- ID WIDTH: zero-padded to TWO digits until the register passes 99, then plain three digits.
     Do not re-pad the old ids when that happens; the handle is the string.
     NO LITERAL ID APPEARS IN THIS FILE'S PROSE (ids are written `D-NN`): the drift report reads a
     register with no entry headings but an id elsewhere as a register whose shape has drifted.
     MINTING IS A READ, NOT A GUESS: a concurrent landing must check the file's actual next-free
     number at landing time — not the last heading above its own insertion point — or cite the
     work-item id alongside the D-NN in the same commit, so a same-day collision stays
     disambiguable: two same-day landings can each read the file correctly and mint the same id.
     (Contract: process/contracts/id-minting.md § 2.)
     AND DO NOT DERIVE THE MAXIMUM BY HAND. This register is grouped by SECTION, so the last `### `
     heading in file order is NOT the highest id. The board's drift report prints the true maximum
     for every declared register (drift-report.md invariant 4); take it from there. -->

**Anchor convention.** Prefer a **section anchor** (`<doc> § <section>`) over a bare `file:line`
into anything that still evolves — a line anchor drifts silently on the next edit above it. Reserve
line anchors for **append-only** ledgers. *(Doctrine:
[`process/doctrine/lookup-tables.md`](../process/doctrine/lookup-tables.md) § A.4.)*

**And STAMP THE TREE the anchors were read against.** A content anchor survives an edit above it; it
does not survive the section being renamed, split or ruled obsolete. So an entry whose citations were
gathered at one moment records **which tree state they were read from** — a commit id is enough. The
stamp makes the rot **detectable rather than discovered**. The same rule for a *work item* is
[`process/doctrine/fix-execution.md`](../process/doctrine/fix-execution.md) § A.9.

**When this register grows past a screenful, it owes an index.** It is a lookup table by
construction — stable ids, a fixed three-field entry shape — which makes it the cheapest document
in any repository to index and the most expensive to read without one. Trigger and budget:
[`process/doctrine/lookup-tables.md`](../process/doctrine/lookup-tables.md) § A.1–A.2.

## This register is a PROJECTION — and that is not a licence to erase

**A superseded ruling is deleted from here, not archived here.** The register answers *what is true
now*; a list of former truths makes that question harder. The history is not lost — it lives in the
ledger (`progress.md`, the issue archive, the change log).

This does **not** contradict the supersession ethic (*preserve the reason, supersede only the
conclusion* — [`process/doctrine/supersession.md`](../process/doctrine/supersession.md)). That ethic
governs the **home document**, where the original reasoning stays visible and is amended rather than
struck. **Here** the same decision appears only as its current conclusion, because a projection
carrying two generations of an answer has stopped being a projection.

## The THIRD state — a ruling WITHDRAWN before its replacement exists

**An entry is a current ruling, or its id sits retired below — or it is in the interval between:**
the answer is revoked on Monday and its replacement arrives on Wednesday. A register that cannot say
*"nothing is currently true here"* is not answering its own question during that interval.

**So say it — in the same three fields, never as a fourth.**

**Ruling.** `WITHDRAWN <YYYY-MM-DD> — <the condition that discharges it>.` Then, in that same field,
what was withdrawn, stated so a reader arriving cold learns which question is now unanswered.

**Why.** **The original reason, kept, and what revoked it** —
[`process/doctrine/supersession.md`](../process/doctrine/supersession.md) § A.1 applied to the
interval: the conclusion becomes *none yet*, and the reason is what the replacement will be argued
from.

**Provenance.** Unchanged — where it was withdrawn, and where the evidence lives.

**THE TOKEN IS ANCHORED, and that is format law:** uppercase, at the **head** of the `Ruling` field,
followed by a date — **never in the `### D-NN` heading**, which is the citable anchor: a token there
would change every citation to this ruling the moment it discharges. The state moves; the handle must
not. An entry that *discusses* a withdrawal — this section included — does **not** declare one, so a
reader matching a bare substring would misread it.

**This is NOT an exception to the projection rule.** A withdrawn ruling is not superseded — it has no
successor yet, and *"there is no current ruling on X"* **is** the current state. Deleting it would
hide that the fork exists, and the next reader picks the defensible-and-wrong answer this file exists
to prevent.

**The discharging condition is a CONDITION, not a date** — the rule
[`dev/downtime-queue.md`](../dev/downtime-queue.md) § How to write a row states for a wake condition.
Where the condition carries an **id** — a work item, an open-questions block, a successor ruling —
**name the id in the token**, because that is the only part a machine can join. Where it has none,
write the observable condition and **say so**: the entry is then checkable by a reader, not by an
instrument.

**Discharge.** Answered **in place**, the entry collapses to an ordinary three-field ruling, keeping
its id and its original reason beside the new conclusion. Answered **elsewhere under a new id**, the
old id is **retired**, with the one line § Retired ids requires.

## The FOURTH state — a WORKING DEFAULT, chosen so work does not wait for the answer

**Only a WITHDRAWN entry — one with NO current ruling — may take this state.** An entry that
already has a standing ruling is never touched by it: the standing ruling **is** what work
proceeds under until the principal answers, and overwriting it would let a question provisionally
grant its own premise by being asked (`scripts/ask.sh --decision D-NN` refuses to touch a
standing ruling for exactly this reason). This state exists only for the interval the THIRD state
already names — an entry withdrawn with no successor yet — and gives that interval a **guessed**
conclusion to build against, rather than none: minted by `scripts/ask.sh` at the moment the
principal it asked cannot answer synchronously
([`process/doctrine/orchestration.md`](../process/doctrine/orchestration.md) § A.5's unattended
corollary: record and keep working, never stop the session to wait for it).

**So say it — in the same three fields, never as a fourth.**

**Ruling.** `WORKING DEFAULT (provisional, asked <YYYY-MM-DD>, <channel-relative question file>) —
<the default itself, stated as law, exactly as a settled ruling would be>.` **The question file's
path is IN the token — this is the ONE place it is written.** A reader of the register alone can
then find the record without a second lookup, and nothing elsewhere restates the path as a second
authoring site.

**Why.** The reason the default was picked. Unchanged from before the ruling was withdrawn where
that reason still applies — per [`process/doctrine/supersession.md`](../process/doctrine/supersession.md)
§ A.1, a conclusion is superseded, the reason that produced it is not struck.

**Provenance.** Where `ask.sh` was run and by what actor, same as any other entry.

**THE TOKEN IS ANCHORED THE SAME WAY THE THIRD STATE'S IS:** uppercase, at the head of the `Ruling`
field, followed by the date `ask.sh` ran. An entry that *discusses* a working default does not
declare one.

**Discharge.** The principal answers **in the channel**, not here: this entry is amended **in
place** once the answer is read, dropping the token and keeping the id — the default either stands
(the token comes off, the ruling stays) or is overwritten **by a new ruling that keeps this
entry's reason and states what changed**, per the same supersession ethic the Why field above
already applies. A default nobody has overturned is still provisional no matter how long it has
stood; nothing here ages it into a ruling.

### What a checker asks — and it must be answerable with nobody looking

> **Is any entry still `WITHDRAWN` whose named discharger has already landed?**

Write the state so a machine can answer that: in an adopting project the condition fired, the
successors landed, and the author edited this very file twice more without noticing the stale entry.
**What such a check cannot see:** a withdrawal nobody declared (a ruling quietly reworded into a
hedge); a discharging condition carrying no id; and a condition that fired with nothing landing.

<!--
  THE SHAPE OF THE REGISTER — FORMAT LAW, and it is NOT a table.
  Entries are grouped under `## <letter>. <bucket>` headings, and each entry is a
  `### D-NN — <short title>` heading followed by three bold-labelled paragraphs:
  **Ruling.** / **Why.** / **Provenance.**  A three-field table looks tidier and fails on the
  first entry whose provenance is four pointers; the heading shape also gives every ruling a
  stable anchor to cite. Buckets are separated by a `---` rule. One entry:

      ### D-NN — <short title, the ruling in a few words>
      **Ruling.** <the ruling, present tense, stated as law>
      **Why.** <the reason, not the history — one line>
      **Provenance.** <where it was ruled> · <where the evidence lives>

  BUCKET NAMES ARE NOT RESERVED. The buckets below are EXAMPLES; name your own, add or drop them.
  Letter the buckets (A., B., …) so a bucket can be cited without quoting its wording.

  A SCRIPT READS THE ENTRY-HEADING SHAPE, and this is where that is said. The heading form
  `### D-NN` is not a stylistic preference: `./scripts/check-board.sh` derives every entry id
  from it — reporting how many entries the register holds, how many are DISTINCT, and the
  highest id number read order-independently — and the citation arm joins `[decision: D-NN]`
  markers to these same headings. Change the heading form and both readings go silent rather
  than wrong, which is why this is format law and not house style. The register's path and its
  heading shape reach that script as a SEAM it declares, so a project keeping its register
  elsewhere points the seam rather than editing the script.

  WHAT THAT READER CANNOT SEE, stated so the quiet case is not mistaken for a clean one: an id
  written WITHOUT the declared separator — `D01` where the shape says `D-NN` — carries neither
  the heading mark nor the id shape, so it is invisible to both. A register spelled that way
  reads as empty. The report's own line says as much where it reports nothing found; the
  remedy is to spell ids as the shape declares.
-->

## A. <your-bucket — e.g. product identity & scope>

---

## B. <your-bucket — e.g. external-system truth, the measurement discipline>

---

## Retired ids

<!-- FORMAT LAW: this section EXISTS from day one, even empty. `<none yet>` is the day-one
     content. An id lands here when its ruling is removed, with one line saying what it used to
     mean, so a stale citation elsewhere resolves to "retired" instead of to the wrong ruling. -->

`<none yet>` <!-- e.g. `D-NN` — retired <date>; the scope it held moved into D-NN. -->

## Findings — what surfaced that is NOT written up as a ruling

<!-- FORMAT LAW: this section EXISTS from day one too. A rule that cannot be traced to a real
     source is REPORTED here, never paraphrased into law above; and this register never RESOLVES
     a contradiction it finds — it records both sides and names who decides. Without this section
     the only two options are to invent a ruling or to drop the observation, and both are worse. -->

1. `<what was observed, where, and what would settle it — or "none yet">`

---

## Which decisions live HERE, and which are PRD content — the fork/fact split

**A DECISION is a fork.** Two or more defensible answers existed and one was chosen, so a reader who
does not know the choice will pick a plausible wrong one. → **a `D-NN` entry in this register.**

**A REQUIREMENT CHANGE is a fact.** What the product does changed; there was no fork. → **amend the
PRD.**

**The diagnostic — ask it about the READER, never about the decision:** *could a competent stranger,
reading only the PRD, arrive at a different answer and be reasonable?* **Yes** → it is a fork, and it
is a `D-NN`. **No** → it is a fact, and it amends the PRD.

*Why the diagnostic is phrased about a stranger:* this register's own definition of an entry is
reader-relative — *a fork where a reader would otherwise pick something defensible and wrong*. A test
phrased about the decision (*"was this hard?"*, *"did we discuss it?"*) measures the author's memory
of the meeting. The stranger test measures the artifact, which is the thing that has to survive the
meeting being forgotten.

**Overlap — a fork that CONSTRAINS a requirement gets BOTH:** the ruling here under its `D-NN`, and
the PRD **citing that id**. **Never the text in both places.** Cite by id, never inline: an inlined
copy is a second authoring site, and it is the copy that drifts.

**Ad-hoc — the permanent home.** A decision made in a story, a review or a conversation is **not
durable where it was made**. The seat that makes it **promotes it to this register in the same
change** — [`process/MANUAL.md`](../process/MANUAL.md) § Execution discipline item 6 is the single
authoring site for *when*; this section is the *which*.

**And the entry is where the REASON is written** — not only the conclusion. A later ruling may
supersede the conclusion, and **the reason is what stops the same argument being re-litigated**
([`process/doctrine/supersession.md`](../process/doctrine/supersession.md)). That is what the **Why**
field is for, and it is why a PRD citing a `D-NN` loses nothing by not restating it.

**THE CITATION MARKER IS `[decision: D-NN]`, and it is format law.** A citation to a ruling — in a
PRD, an issue card, anywhere outside this file — is written as that bracketed token. It is
**anchored, not a bare id**: a bare `D-NN` cannot be told apart from prose *about* a ruling, so the
first honest sentence discussing a retired id would be misread as citing it. Only text that declares
itself a citation is read as one. `./scripts/check-board.sh` joins the marker to this register's
`### D-NN` headings and reports a citation resolving to no entry, or to a retired id.

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
   thing was not done. A negative ruling carries its **enumeration or its "unmeasured" label** —
   [`process/doctrine/negative-claims.md`](../process/doctrine/negative-claims.md).

**Where it does NOT go:** a ruling with a natural home — a capability-matrix row, a guide section, a
docstring — is authored **there**, and appears here only as its one-line current conclusion with a
pointer. Two authoring sites for one rule is how the two start disagreeing.
