<!-- KIT-CLASS: KIT — transferable doctrine. § A is the pattern; § B is the fill-in for YOUR ledger, trunk and guards. -->
# Retention doctrine — park beats delete, and the one narrow class that may be retired

**KIT-CLASS: KIT.** § A is the transferable pattern; § B is where **your** project records its own
ledger, trunk and guards. This sheet is written under [`supersession.md`](supersession.md) § A.1
and is meant to be read as a **worked example of it**: the reason below is preserved in full, only
one conclusion is narrowed, and the guard that enforced the old conclusion is transformed rather
than deleted.

**Why the reason is written out at such length.** In the project this sheet came from, *park beats
delete* was cited roughly twenty times — in project law, in a frozen charter, in board issues, in
ledgers — and its **reason existed in exactly one place: a code comment**. Amending the rule by
editing those citing sentences directly would have been precisely the rationale-free strike
`supersession.md` predicts gets re-litigated: a future session reads "delete is allowed now", finds
no reason beside it, and either re-opens the whole question or re-derives the old conclusion from a
reason nobody wrote. **Writing the reason down is the first deliverable; narrowing the conclusion is
the second act, not the first.**

---

## A. The pattern (this is the transferable part)

### A.1 — Park beats delete (the standing rule; the REASON, unchanged)

> Retained evidence is **parked, not deleted**: moved out of the active reading path, marked
> dormant or dated in-file, and kept at a path its referrers still resolve.

**The reason, stated in full, and NOT superseded.** Three failure modes, each independent, and
each still holds — nothing in § A.2 through § A.6 weakens any of them:

1. **Deletion is the cheapest way to make a guard green, and it is always the wrong fix.**
   Every existence guard turns green the instant its target stops being cited *or* stops existing;
   a person under time pressure with a red suite will find that shortcut. Write that reasoning into
   the guard's own comment, where the person about to take the shortcut will read it: *demanding an
   exhaustive index would push people toward deleting evidence, which is exactly the failure mode
   "park beats delete" exists to prevent.* A reference that "cannot go dead again" must also be one
   that cannot be *fixed by deleting the artifacts*.
2. **Evidence is not re-derivable at its original price.** A probe capture may have cost a grant on
   a named external surface, write credentials, a permanent token that cannot be re-minted, or
   human click-time. One such document can be the **sole verbatim record** of twenty-odd manual
   clicks nobody will perform again. Re-deriving is not a cheaper path; it is often no path.
3. **A negative claim dies with its enumeration.** [`negative-claims.md`](negative-claims.md)
   requires a negative to carry the attempts it rests on. Delete the enumeration and the claim
   degrades from measured to remembered — and the distinction between *"we looked and it was fine"*
   and *"we could not look"* is exactly what the evidence document existed to preserve.

**All three reasons still hold. Nothing below weakens them.** § A.2 does not relax any of the
three — it identifies the one narrow class where a different mechanism (a ledger, backed by an
unrewritten trunk's own history) satisfies the *same* reasons rather than overriding them.

### A.2 — The narrow class whose CONCLUSION changes: a ledgered retirement

The conclusion changes for **one class and no other**. A document may be retired — its bytes
removed — only when **all five** hold, each verified and written down, never assumed:

- **(a) SPENT.** Its forward-looking half is executed or abandoned, and that is provable from
  the tree (the work items it minted are closed, or a successor document supersedes it by name).
  "Looks old" is not spent.
- **(b) NO referrer in the project's code paths.** Not "re-pointable" — *none*. A shipped
  docstring or a guard citing it makes it FLOOR (§ A.3), full stop.
- **(c) Every remaining referrer is prose provenance, and every one is re-pointed at the
  ledger row in the SAME change.** Enumerated by path and line in the retiring work item. Zero
  dangling pointers land.
- **(d) The bytes are recoverable from the trunk's history**, and the recovery has been RUN,
  not reasoned about (§ A.4).
- **(e) It is not a floor item** (§ A.3).

**Why this SATISFIES the original reason rather than overriding it.** Take the three failure
modes in order:

- Failure mode 1 is about deletion as a **guard-silencing move**. Condition (b) removes the
  motive entirely: a document with no guard and no shipped citation has no guard to silence.
  The retirement is available only where the temptation to use it as a green-suite shortcut
  does not exist.
- Failure mode 2 is about **irrecoverable cost**. It assumed removal means loss. On a trunk
  whose history is never rewritten that assumption is false for *content* — and this is
  measurable, not assertable: in the donor project a ~155 KB source module deleted in one commit
  came back **byte-identical** from its content-addressed object roughly a hundred commits later.
  What deletion destroys is not the content but the **address** — nobody six months on knows the
  object's hash. The ledger line restores the address; it is the thing that makes the reason
  satisfiable, not a concession against it.
- Failure mode 3 is about a **negative claim outliving its enumeration**. Conditions (a) + (c)
  keep the claim and its enumeration in the same state: a document still holding a live claim's
  enumeration is not spent, and one whose claims are all restated elsewhere carries no orphaned
  claim.

**The test is not invented here.** The donor had already applied it once, under authorization, to
three abandoned branch refs — deleted under a table whose columns are precisely the ledger shape
(name, last commit, landing evidence, verdict). The test it stated was § A.2's almost verbatim: *a
branch ref is not citable from a file; its content is on the trunk; and no document references the
branch name outside the landing commits themselves, which are immutable and unaffected.*
Recoverable + uncitable + nothing left dangling = deletable. This doctrine extends that same test
from branch refs to spent documents; it does not invent it.

### A.3 — The floor: park-only, no ledger available

No ledger makes any of these retirable. If one looks dead, it is recorded as **considered and
kept, with the reason** — never as a delete:

- Anything cited from the project's code paths, at any strength: a shipped evidence string, a
  matrix evidence cell, a capture-anchor row, a fixture loader's corpus. **These are index-only.**
- The board, the archive index, the environment files.
- Any active contract, role doc, doctrine sheet, or living matrix.
- The evidence behind any still-**UNRESOLVED** question: a residue-ledger citation, a live-gate
  registry entry, an unmet wake condition on a deferred-work row.
- **Parked *capability* (as distinct from spent evidence)**: a dormant role or skill kept for a
  future extraction is untouched by this amendment — a parked skill is a capability awaiting a
  wake condition, not spent history, and its conclusion does not change.
- **Raw captures, categorically.** Retirement operates at PROSE-DOCUMENT granularity only. A
  capture tree is retired never; what an index owes is *membership*, not an exhaustive per-capture
  bibliography.

**The tie-break is unchanged and binding: when torn, park.** A ledgered retirement is a thing
you MAY do, never a thing you OWE.

### A.4 — What a ledger line must contain (a fetch-back must be POSSIBLE and DISCOVERABLE)

The concern the old conclusion protected is discharged only if a stranger, six months on, can
both **find** that the document existed and **get it back**. Both halves are required; a line
satisfying one is not a ledger line.

**Discoverable** — the ledger is an **append-only file with a single `## Retired` heading**,
mirroring the archive index's shape (one index, bodies elsewhere — here the "elsewhere" is version
history rather than another file). It sits **inside** the retained-evidence area and is itself
linked from that area's own index, so the guard that already forces every document there to be
indexed is the guard that also holds the ledger. **The stock path is `dev/RETIRED.md` — a path your
project CREATES at its first retirement, not a file the kit ships.** *Said plainly because it reads
as shipped: nothing in the tree carries that name, and a reader who goes looking for it concludes
the doctrine is describing a feature that was removed. § B is where you record the path you actually
used, and the stock answer is a default, not an inventory.*

**Possible** — every row carries **seven** fields, and no row lands with a field derived by
reasoning:

| Field | What it is | How it is obtained |
|---|---|---|
| `path` | the retired path **as of the recorded commit** | verbatim; a renamed file records the name the commit knows, because a show against the wrong path fails outright |
| `commit` | short id of **HEAD immediately before the retirement is staged** — the last commit that still contains the bytes, i.e. the retirement commit's parent | `git rev-parse --short HEAD` |
| `blob` | the content-addressed object id | `git rev-parse HEAD:<path>` |
| `bytes` | exact size, the fetch-back's self-check | `git cat-file -s <blob>` |
| `issue` | the `<PREFIX>-NNN` that retired it, and the date | — |
| `what it was` | ONE line: what the document was and what it was for, written so a reader can decide whether they want it back without fetching it | — |
| `fetch-back` | the command, **verbatim, not a recipe to reconstruct** | `git show "${commit}:<path>"` (braced — see `instruments.md` § A.9 on zsh eating the path) (equivalently `git cat-file -p <blob>`) |

Two fields carry the weight and both are non-negotiable. **`blob` + `bytes` make the fetch-back
self-verifying**: piping the object out and counting bytes either matches the recorded size or you
have the wrong object, and no path, branch or commit is needed to resolve it. **The verbatim
command** exists because a recipe a future reader must re-derive is a recipe they will get wrong —
the naive derivation, *"the last commit that touched the file"*, is subtly unreliable under history
simplification and rename detection, which is exactly why it is not the recorded field.

**One documented exception to the single-file shape.** A directory that was added whole, in one
unmodified commit, may be retired as ONE row covering many files, rather than one row per file —
**verified by re-running the check that makes it safe** (its log is one commit; that commit's
name-status for the directory is all-added), never assumed. Such a row's `path` carries an explicit
`(N of M files)` split, its `blob` is a note pointing at the per-file fetch-back rather than a
single hash, and its `fetch-back` is parametrized over a `<name>` placeholder that still names
*this row's own* commit and directory. This is a disclosed, narrowly-scoped exception a guard can
validate against its own shape — not a silent carve-out — because hundreds of rows for one
unmodified commit would be hundreds of chances to be wrong about the same fact.

**The one durability condition, stated plainly:** the recorded commit must be an **ancestor of the
trunk**. Content is recoverable for as long as its commit is reachable; a commit reachable from the
trunk is never garbage-collected, and a commit on an abandoned branch is. A retirement therefore
**lands on the trunk**, and **any rewrite of trunk history — a force-push, a history filter, a
squash of the trunk — invalidates every row in the ledger.** State this in the ledger's own header,
because it is the single assumption the whole amendment rests on. Where the trunk's remote is
mirrored by a force-syncing host, it is a **live standing hazard, not a hypothetical**.

### A.5 — What is NOT guardable, said out loud

`supersession.md` § A.1 requires this: *"If the new truth is genuinely unguardable, say so in
the amendment — do not let a deletion pass as a move."* So:

- **A ledger row's HONESTY is guardable in-tree** — that the path is really absent, that no
  live index still links to it, that the row is well-formed. All of that is tree content.
- **A ledger row's FETCH-BACK is NOT guardable by an offline test suite.** Where a suite forbids
  tests from reading live version-control state (*"assert the content of the tree instead"* — a
  good rule, and a common one), no test may run the fetch-back. The resolvability of a ledger id is
  therefore verified **once, by a human, at retirement time**, and the evidence — the byte count
  the fetch-back actually printed — is pasted into the row. **The recorded `bytes` field IS that
  verification, frozen.**
- **COMPLETENESS is not guardable by the same suite either**: no test can prove that a deletion
  which happened was ledgered, because knowing a file once existed means reading history. That
  direction **changes venue** to a write-time hook, where reading live version-control state is
  legitimate and an offline-suite prohibition does not reach. This is the one place in the doctrine
  where the mechanism changes venue rather than moving, and it changes venue for a stated reason.
  Its invariants are [`../contracts/retention-completeness.md`](../contracts/retention-completeness.md)
  — **a spec, not a shipped gate.** The kit deliberately ships no such hook: every operand it would
  need (the retained directory's name, the ledger's path and field shape) is the project's own law,
  so the travelling artifact would be a file of blanks. **The hook is yours to write**, and that
  sheet's sections 1–5 are what it owes.

### A.6 — Retirement-QA (the process verifies parks; it verifies retirements too, and harder)

Park-QA exists because a park is a *claim* — that findings are evidence-backed, the work item
really sits in the blocked queue, and no half-landed residue remains — and `PARKED_OK` means
"parked **and verified**", with an unverifiable park halting the run as `PARK_UNVERIFIED`. A
retirement is a strictly stronger claim on irreversible-looking bytes, so it gets the same
discipline with a longer checklist. **`RETIRED_OK` means retired and verified; a retirement QA
cannot verify halts the run as `RETIREMENT_UNVERIFIED`, and the correct remedy for an
unverifiable retirement is always to park instead.** A fresh-eyes reviewer, **not the retiring
worker**, confirms:

1. **The fetch-back RAN.** The reviewer executes the row's verbatim command itself and confirms the
   byte count matches the recorded `bytes`. This is the one check no automation can do, so a
   reviewer who skips it has verified nothing.
2. **The five conditions of § A.2 are each evidenced**, not asserted — in particular (b) by a
   fresh search over the code paths, run by the reviewer, not quoted from the work item.
3. **Zero dangling referrers.** Every referrer named in the work item is re-pointed in the same
   change, and the reviewer re-runs the enumeration to confirm the list was complete.
4. **No half-retirement.** The bytes are gone, the ledger row is present, the index entry is
   moved (not deleted — see [`staleness.md`](staleness.md) § A.3), and no guard row anywhere still
   names the path.
5. **The floor was not crossed** (§ A.3), and the tie-break was applied — the work item says, in
   one line, why park was rejected. "It was stale" is not a reason; a reason names which of
   § A.2's five conditions made retirement *available*.

**A retirement may only land under a named work item.** Not in a sweep, not as a tidy-up rider on
another change — one item, one review leg, one ledger append.

**THE TIE-BREAK IS UNCHANGED AND SAID PLAINLY: when torn, park. A ledgered retirement is a
thing you MAY do, never a thing you OWE.**

---

## B. Your project's instance — **fill this in**

> **PROJECT INSTANCE from here down.** Nothing here is inherited. On day one, § A is live and § B
> holds only the first three rows below — a project with no retirements has an empty ledger and
> that is the correct state.

**What goes here:**

- **The ledger's path and heading** — the stock answer is `dev/RETIRED.md`, `## Retired`,
  append-only, linked from the retained area's own index under a retired-items heading.
- **The trunk whose reachability the fetch-back depends on** (`<trunk>`), and **any standing hazard
  to that reachability** — a force-syncing mirror, a squash-merge policy on the trunk, a host that
  rewrites refs. If one exists, the ledger's own header repeats it; this is not a footnote.
- **Any transitional caveat that makes a recorded id provisional** — e.g. commits that are still
  local because publication is blocked, or a branch stack that may be rebased before landing. State
  plainly that every `commit`/`blob` field must be **re-captured** if the history moves.
- **The guards**, by name: the in-tree honesty guard (§ A.5's first bullet) and the write-time
  completeness hook (§ A.5's third bullet), plus the hook wiring that makes the latter live in
  every checkout including the auxiliary trunk checkout. **Both are yours to write — the kit ships
  neither**, and the completeness hook's sheet says so in its own § 6. Naming them here is what
  makes their absence visible if you decide not to write one; an unnamed guard you never wrote is
  indistinguishable from one you have.
- **Your own precedent**, if you have one, and the register entry that governs it.
- **A dated baseline** — how many retirements have happened, measured on a stated date with the
  command. Per [`staleness.md`](staleness.md) § C, a baseline that says *"nothing has ever been
  deleted here"* becomes historical the moment the first retirement lands; **date it rather than
  restating it as present-tense fact.**
- **What is out of scope for your retirement mechanism, and why.** In particular: the **board's own
  archive sweep** (a move into a directory that still exists, over a different corpus of closed
  work items) is *not* the retirement-under-ledger mechanism § A.2 defines, and this doctrine does
  not touch it.

### A worked example from the donor project (anonymized)

*Park beats delete was observed perfectly for the whole of that project's life* — a search for
deletions under the retained-evidence area returned nothing, across the entire history, and the
area's index carried two hundred-odd link targets with zero dead ones. **The first exception was
ledgered rather than merely permitted:** a single authorized work item retired fifteen rows'
worth of spent evidence (several hundred files, a few million bytes) in one pass, and a second
item migrated those rows losslessly into the ledger file this doctrine specifies. Both went through
the § A.6 review leg, fetch-back included.

The order matters and is the transferable part: **the reason was written down first, the ledger
shape second, and only then was anything removed.** A project that removes first and writes the
ledger afterwards has produced exactly the rationale-free strike this sheet exists to prevent.
