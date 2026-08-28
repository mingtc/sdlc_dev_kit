<!-- KIT-CLASS: KIT — contract sheet: the release ritual. See process/EXTRACTION.md. -->
# CONTRACT — the release ritual

## 1. PURPOSE

To make a release **an assertion the project can stand behind** — a named, immutable point that
was proven green *before* it was named, and whose published artifact is built from that exact
point.

**If your project ships nothing, this sheet is inert** — say so in your project doc's gates table
rather than deleting the row, so the decision is visible.

## 2. HARD INVARIANTS

- **EVERY gate runs BEFORE the version is written.** The version bump is the first mutation of
  the ritual, and it happens only after the last read-only check has passed.
  *Why:* a red gate discovered after the bump leaves a repository that claims a version it never
  earned, and the cleanup is a rewrite of published history — this order was learned the expensive
  way.
- **A red preflight leaves the repository byte-for-byte untouched.** Not rolled back; never
  touched.
  *Why:* rollback is a second thing that can fail, at the worst moment.
- **The release documents are REQUIRED, and each missing one refuses in its own words.** Every
  released version has its section in each required document before the version exists.
  *Why:* an undocumented release is indistinguishable from an accidental one to the consumer who
  finds it; and a single merged refusal makes the author fix one document and be refused again.
- **The name is unique and immutable.** A name that already exists refuses; a released name is
  never moved to another point.
  *Why:* consumers pin the name; moving it changes what shipped without changing what they pinned.
- **Naming happens on a clean trunk.** The point being named is the published trunk with no local
  modification.
  *Why:* otherwise the named point contains something that exists only on one machine.
- **Between the local acts and the push, the ritual PRINTS what exists only locally and the exact
  commands that finish the job** — as ordinary output, while the run is healthy, never only on a
  failure branch.
  *Why:* the commit and the name are asserted in the transcript before either is published, and a
  run killed in that window — a caller's timeout, a closed window, the host — never reaches the
  failure branch that would have said so. The transcript then reads as a released version no
  consumer can fetch, nothing else reports it, and the obvious recovery is the wrong one: the name
  now exists, so the uniqueness invariant above refuses a re-run. The recovery has to be printed
  because the operator cannot reconstruct it from an instinct
  ([`../doctrine/fix-execution.md`](../doctrine/fix-execution.md) § A.7).
- **Publication of any built artifact happens ONLY AFTER the push of the commit and the name has
  succeeded.** The artifact is built from the named point, not from the working tree.
  *Why:* building before the push has shipped a stale artifact that matched no released point, and
  consumers then vendored it; and a publication attempted first can fail and make a completed
  release look failed.
- **A failure after the name is published is reported as a SUCCEEDED release with a failed
  follow-up step, and the follow-up is separately retryable.** It never rolls back the name.
  *Why:* rolling back a published name is worse than a missing artifact, and the retry path is
  what keeps the operator from improvising one.

- **Where a slate was minted from findings, the pre-cut sweep is a REQUIRED STEP of this ritual,
  with a NAMED OWNER, and it runs before the version is written.** The sweep reads the project's
  declared consumer-facing surfaces; it is not the periodic hygiene cadence, which is advisory.
  **Required step, not an automated check — and the distinction is deliberate, not a hedge.** This
  sheet requires that the sweep HAVE RUN and that its owner be named; it does **not** require a
  script arm that decides it. [`../hygiene-checklist.md`](../hygiene-checklist.md) says why
  mechanizing it is held back: an automated check could only inspect an **artifact** the sweep
  produces, not the sweep, and an artifact that is trivially satisfiable makes the check
  self-certifying — the defect [`../doctrine/instruments.md`](../doctrine/instruments.md) is about,
  wired into the release path. **So "required" binds the ritual and "not automated" binds the
  implementation, and a reimplementer owes the first without owing the second.**
  *Why:* a fully-green, individually-reviewed program still ships stale sibling statements — a
  change is reviewed against its own operands, and nothing in that review reads the files no diff
  touched. The sweep is the only instrument that finds a false claim in a file nobody edited, and a
  ritual that does not name it leaves the one check that catches that class to whoever remembers.
  **Naming an owner is part of the invariant:** an unowned checklist item is the thing that is
  skipped when the cut is late. *(The shapes and the sweep's own definition are in
  [`../hygiene-checklist.md`](../hygiene-checklist.md); this sheet only requires that the ritual
  run it and say who owns it.)*

## 3. REFUSAL CONDITIONS

- The proposed name does not parse in the declared shape ⇒ refuse.
- The name already exists ⇒ refuse (this is also what makes a re-run safe).
- Not on the trunk, or the workspace is not clean ⇒ refuse.
- Any gate is red ⇒ refuse, naming the gate.
- Any required release document lacks the version's section ⇒ refuse, naming **that** document
  and what to write in it.
- The board is not clean ⇒ refuse. A release cut over a drifting board mislabels what shipped.
- The slate came from a round and the pre-cut sweep **has not run**, or has run with **no named
  owner** ⇒ refuse, naming which of the two is missing.
  *Whose refusal this is:* the ritual's, not necessarily the script's. Every other condition here is
  mechanically checkable from the repository; this one is a fact about **work that happened outside
  it**, so in an implementation that has not automated the sweep the refusal is the operator's to
  honour — and it is written here rather than left to memory precisely because an unautomated
  refusal is the one that gets skipped when the cut is late. *An implementation that DOES automate
  it owes the self-certification caution above.*

## 4. WHAT GREEN MEANS

1. Every preflight gate **ran and passed**, each named with its verdict.
2. The version literal was written to **every declared place** and the new value is printed —
   e.g. a project whose next point is `42.x` shows that value in each place it was written.
3. **One** attributed commit and **one** annotated name exist at the trunk's tip, both printed —
   and printed as **local only**, with the commands that finish the job, before item 4 is attempted.
4. Both were **pushed**, and only then was the artifact built at the named point and published.
5. A dry mode exists that performs item 1 and reports 2–4 while changing **nothing**.
6. Where the slate came from a round, the **pre-cut sweep ran, and the report names its owner** —
   an unnamed owner is a finding about the ritual, not a pass.

## 5. MINIMAL INTERFACE

**In:** the proposed version; the trunk; the gate set; the required release documents.
**Out:** each gate's verdict, the files bumped, the commit and name identifiers, the push result,
the publication result — and a dry mode that prints all of it and mutates nothing.
**Not in:** what the version *means*. Ordering is the contract; semantics are the project's.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/release.sh` — KIT-CLASS **MIXED**: this sheet describes the **kit half** (preflight →
  bump → attributed commit → annotated tag → push → publish, and the refusals). Which files carry
  the version, which documents are required, what the number means, and whether anything is
  published at all are the project's law.
- The required-documents refusal wants a regression test of its own in the project's suite; it is
  the refusal most likely to be softened by whoever is mid-release at the time.
- Version literals in these contract sheets use the deliberately fictional `42.x`, so no example
  can be mistaken for a real release or rot when the real one moves.
