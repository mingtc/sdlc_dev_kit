<!-- KIT-CLASS: KIT — contract sheet: the landing gate. See process/EXTRACTION.md. -->
# CONTRACT — the landing gate

## 1. PURPOSE

To ensure that **nothing enters the trunk that has not just been proven green**, and that the
proof was produced by the gate itself rather than by whoever wanted the change landed.

## 2. HARD INVARIANTS

- **The gate is TWO LAYERS, and this sheet governs both.** The **REVIEW gate** is the **full**
  run, performed by the reviewer on the branch before the landing is requested — **not a narrowed
  run, and not a remembered result** (that phrase scopes to *this* layer). The **LANDING
  re-check** then runs **immediately before the merge, on the tree that is about to land**, and
  its floor is the project's **fast, unskippable** subset — a subset the project **declares**, so
  it can be neither chosen by the caller nor quietly reduced to nothing.
  *Why:* a branch that was green yesterday and a trunk that moved since are two different trees,
  and only one of them is the one you are shipping — so *something* must run at merge time. But
  requiring the full run **twice** buys a second copy of a verdict the review just produced, at a
  cost that gets the re-check deleted. **A sheet that demands the full run at both layers is a
  sheet no adopter can satisfy**, which is how this one was found: an adopter building from the
  contracts alone could not land at all, because the reference implementation ran the fast floor
  while this section said "not a narrowed run".
- **The landing re-check may be a subset, but never NOTHING and never the caller's choice.** A
  project may name a bigger floor; it may not name an empty one.
  *Why:* "we already ran it on the branch" is the sentence that precedes every merged red trunk.
- **The gate executable is chosen by the gate, never by the caller: no caller-supplied gate
  command reaches the production path.** If a test harness needs a stub, it may exist only behind
  an explicit test-only marker that no production caller sets.
  *Why:* a landing gate that accepts an arbitrary command from its caller can be handed a
  command that always succeeds, which turns the strongest control in the process into a
  formality — this was learned by incident, not by design review.
- **The gate that runs is the COMMITTED one.** The gate definition must be tracked at the
  revision being landed and free of uncommitted modification, or landing refuses.
  *Why:* an edited-but-uncommitted gate means the proof came from a definition that will not
  exist for anybody else.
- **One work item, one landed commit.** The branch's history is collapsed into a single
  trunk commit that names the item.
  *Why:* the trunk's log is the project's ledger; a ledger where one decision spans forty commits
  cannot be read, reverted or bisected.
- **Landing is only legal from the handoff state.** An item that has not been handed off cannot
  be landed, however green it is.
  *Why:* the gate is the last step of a review, not a substitute for one.
- **Landing advances the item's state and records the landing, in the same operation.** A landed
  change whose board state still says "in review" is a half-landed change.
  *Why:* the two halves diverging is exactly the drift the board exists to prevent.
- **A red gate leaves the repository untouched.** Every check runs before the first mutation.
  *Why:* a partial landing is harder to diagnose than no landing.
- **A landing whose publication fails is reported as NOT LANDED, in the item's own log.** The
  merge existing locally is not the landing; the trunk commit reaching the publication target is.
  *Why:* the board is the artifact everyone else reads, and a board claiming a landing that sits
  in one checkout is worse than an obviously unfinished one. See
  [`../doctrine/commit-hygiene.md`](../doctrine/commit-hygiene.md) § A.4.

## 3. REFUSAL CONDITIONS

- The item is not in the handoff state ⇒ refuse, naming the state it is actually in.
- The work branch named by the item does not exist ⇒ refuse rather than guessing a branch.
- The gate definition is missing, not executable, not tracked at the revision being landed, or
  locally modified ⇒ refuse **before** any destructive step, saying which of the four it was.
- A gate command was supplied by the caller without the test-only marker ⇒ refuse, and say that
  the gate chooses its own executable.
- The gate is red ⇒ refuse; report the failure, mutate nothing.
- The publication of the landed commit fails ⇒ report that the merge exists locally and did not
  reach the trunk, name the recovery, and name the commits that did not land.

## 4. WHAT GREEN MEANS

1. The **pre-merge re-check ran and passed**, and its verdict is shown — not summarised as "ok";
   the **full review gate** has its own evidence, in the item's activity log, from the review.
2. The branch is **collapsed into exactly one trunk commit**, whose identifier is printed.
3. The trunk commit is **published**, and the branch is retired everywhere it existed.
4. The item's **state advanced** and the landing is written into its activity log.

All four, printed. Three of four is a defect, not a partial success.

## 5. MINIMAL INTERFACE

**In:** the work item's identity; optionally the branch, when the item does not name one.
**Out:** the gate verdict, the landed commit identifier, the retired branch, the item's new
state, and a plan-then-apply mode that prints all of the above and changes nothing.
**Not in:** the gate's own check list (see [verify-gate.md](verify-gate.md)) and any notion of a
code-review object — the item's activity log **is** the review record.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/finish-pr.sh` — KIT-CLASS: KIT. Pure version control, no forge API: the squash, the
  push, the branch deletion and the state advance. Forge-native flavours are an optional extra —
  [`../GIT-HOSTING.md`](../GIT-HOSTING.md).
- The caller-supplied-gate-command invariant in § 2 is written as a refusal at the top of that
  file, before any state is read, because it is the invariant an incident produced.
- `scripts/verify.sh` — the gate this kit hands it; contracted in
  [verify-gate.md](verify-gate.md), whose sheet describes the **kit half** of that MIXED file.
- **The two layers, named concretely in the shipped implementation (§ 2's first invariant):** the
  **review** gate is the boundary's step 3 — the reviewer runs the gate runner **unnarrowed** on the
  branch. The **landing** re-check is the landing script running that same tracked gate in its
  quick mode: the fast floor, chosen by the script and not by the caller. **The landing script was
  NOT changed when this sheet was corrected** — the practice was sound and had run for months; what
  was wrong was this sheet conflating the two layers into one demand no adopter could meet. *(Found
  by a seed acceptance test; corrected by ruling. Supersession ethic: preserve the reason,
  supersede the error.)*
