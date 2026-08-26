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
- **Publication of any built artifact happens ONLY AFTER the push of the commit and the name has
  succeeded.** The artifact is built from the named point, not from the working tree.
  *Why:* building before the push has shipped a stale artifact that matched no released point, and
  consumers then vendored it; and a publication attempted first can fail and make a completed
  release look failed.
- **A failure after the name is published is reported as a SUCCEEDED release with a failed
  follow-up step, and the follow-up is separately retryable.** It never rolls back the name.
  *Why:* rolling back a published name is worse than a missing artifact, and the retry path is
  what keeps the operator from improvising one.

## 3. REFUSAL CONDITIONS

- The proposed name does not parse in the declared shape ⇒ refuse.
- The name already exists ⇒ refuse (this is also what makes a re-run safe).
- Not on the trunk, or the workspace is not clean ⇒ refuse.
- Any gate is red ⇒ refuse, naming the gate.
- Any required release document lacks the version's section ⇒ refuse, naming **that** document
  and what to write in it.
- The board is not clean ⇒ refuse. A release cut over a drifting board mislabels what shipped.

## 4. WHAT GREEN MEANS

1. Every preflight gate **ran and passed**, each named with its verdict.
2. The version literal was written to **every declared place** and the new value is printed —
   e.g. a project whose next point is `42.x` shows that value in each place it was written.
3. **One** attributed commit and **one** annotated name exist at the trunk's tip, both printed.
4. Both were **pushed**, and only then was the artifact built at the named point and published.
5. A dry mode exists that performs item 1 and reports 2–4 while changing **nothing**.

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
