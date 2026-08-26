<!-- KIT-CLASS: KIT — contract sheet: id minting. See process/EXTRACTION.md. -->
# CONTRACT — id minting

## 1. PURPOSE

To guarantee that an identifier this process issues means **one thing forever**, so that every
reference to it — in a commit, a note, a decision record, another item — resolves to exactly one
thing.

**Two identifier spaces, not one.** A **work item's** id is the obvious case and the one with a
tool. A **register entry's** id — a decision record, a requirements register, anything whose
entries carry handles that later text resolves through — is the second, and it is hand-minted, so
the invariants below reach it while the tooling does not. This sheet used to say *"a work item's
identifier"* while the concurrency invariant in § 2 was learned **from a register collision**: the
evidence was already about the wider space. Widened rather than duplicated, because a second sheet
would restate these invariants and the copy is the one that goes stale.

## 2. HARD INVARIANTS

- **An identifier is permanent and is never reused.** Not after the item is finished, not after
  it is cancelled, not after it is deleted.
  *Why:* every reference ever written to that identifier would silently change meaning, including
  references in history that nobody can edit.
- **Identifiers are monotonic within a prefix.** The next one is greater than every one issued so
  far; numbering never restarts.
  *Why:* monotonicity is what lets a reader order two references without a database.
- **"Every one issued so far" is read ORDER-INDEPENDENTLY, never by position.** The maximum is a
  numeric maximum over all identifiers in the space, not the last one in file order and not the
  last one a byte comparison sorts to.
  *Why:* measured, twice, in one landing set. A register grouped by section holds a later id
  *above* an earlier one, so the last heading in file order is not the maximum — read as one, it
  proposes an id that already exists. And a numeric sort that is silently not numeric (a
  non-portable extraction, a string compare) is correct on two-digit ids and wrong the first time
  the space holds both a one-digit and a two-digit id — which is the harder failure, because it
  passes every test written against the ids that already exist. **Where a tool can report the
  maximum, it reports it, so no reader has to derive it**: a recipe copied into a file header is a
  derivation waiting to be got wrong.
- **The search for "used" spans the LIVE board AND the ARCHIVE.** Retired items keep their
  numbers, so an identifier that no longer appears on the board is still taken.
  *Why:* a minting rule that only reads the live board reissues the number of the first item that
  ever completed — the collision arrives late and is nearly invisible.
- **Minting is a SUGGESTION; assignment is the caller's, and is validated.** The tool proposes
  the next free identifier; the creating step takes the identifier as an input and re-checks it.
  *Why:* the caller has context the tool does not (a reserved range, a batch being minted), and a
  tool that silently assigns while the caller also assigns produces two items with one number.
- **The prefix is configuration, not content.** The identifier's shape is prefix plus number, and
  the prefix comes from one declared setting.
  *Why:* an adopter who cannot change the prefix inherits somebody else's project name in every
  identifier forever.
- **Minting reads; it never writes.** Asking for the next identifier changes nothing, so asking
  twice is safe and asking is never a commitment.
  *Why:* a reserving mint leaks numbers on every abandoned session, and gaps then look like lost
  work.
- **Concurrent minting is the caller's hazard, and the caller is told.** Two lanes that both read
  "the next free number" get the same answer. Where concurrency is possible, the second landing
  re-reads at landing time, or cites the work-item id alongside the number in the same commit so a
  same-day collision stays disambiguable.
  *Why:* measured — two same-day landings in one project both minted the same register id, each
  correctly reading the file as it stood.

## 3. REFUSAL CONDITIONS

- No identifier has ever been issued and none can be inferred ⇒ refuse with a suggested starting
  point, rather than inventing one. Choosing where a project's numbering starts is a decision.
- The caller supplies an identifier that is already live ⇒ **hard refusal**; a collision on the
  board is unrecoverable by reading.
- The caller supplies an identifier that appears only in the archive ⇒ **warn loudly and
  continue** only if the process says so; the identifier is taken, and the operator must know.
- The supplied identifier does not match the declared shape ⇒ refuse, showing the shape.

## 4. WHAT GREEN MEANS

1. The proposal is **one identifier**, printed, in the declared shape.
2. It is **strictly greater** than every identifier found in the live set *and* the retired set —
   both were searched, and a reader can repeat the search.
3. Nothing was written: running it twice yields the same answer.

## 5. MINIMAL INTERFACE

**This interface is the WORK-ITEM minter's.** Register ids have **no minting tool by design** —
the author re-reads the space at write time, and the fence is the drift report's identifier-integrity
check (`drift-report.md` invariant 4), which reports the space's true maximum and any duplicate.
Saying so here stops the next reader concluding a register minter is missing.

**In:** the configured prefix; the live set of items; the retired index.
**Out:** one proposed identifier, or a refusal that names the starting decision the operator must
make. Validation is a separate call: identifier in, accept / hard refusal / loud warning out.
**Not in:** creating anything. Minting and creating are deliberately two steps.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/next-id.sh` — KIT-CLASS: KIT. The read-only proposal, over both the live board and
  the retired index.
- `scripts/config.sh` — KIT-CLASS: KIT. The prefix seam and the shared validation used by every
  creating step; contracted in [config-seam.md](config-seam.md).
- The creating steps that consume a validated identifier are contracted in
  [issue-creation.md](issue-creation.md).
