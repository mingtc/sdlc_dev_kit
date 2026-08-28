<!-- KIT-CLASS: KIT — contract sheet: commit attribution. See process/EXTRACTION.md. -->
# CONTRACT — commit attribution

## 1. PURPOSE

To keep the history **answerable by role** — *which hat did this?* — so that the ledger can be
filtered, audited and trusted years later without asking anybody.

## 2. HARD INVARIANTS

- **Every commit subject declares the acting role, in one fixed, machine-greppable shape.** The
  shape is the same for every role and appears at the start of the subject.
  *Why:* a convention that varies by author is a convention only its author can query.
- **The role set is CLOSED and shared.** A subject naming a role outside the declared set is
  rejected exactly like a subject naming none.
  *Why:* an open set decays into free text within a month, and then the filter that made the
  history answerable returns nothing.
- **Enforcement is mechanical, at the moment of writing.** The rule is applied by the version
  control system itself as the commit is created, not by review, not by a later sweep.
  *Why:* a described boundary is a suggestion and an enforced one is a wall; every unenforced
  attribution convention this process has met eroded silently.
- **Every path that creates a commit is guarded, not just the interactive one.** Applying a
  patch series, replaying, importing — each is a way in, and each is guarded by the same rule.
  *Why:* one unguarded entrance is the whole fence.
- **The rejection explains the rule and shows a correct subject.** A refusal that only says "no"
  costs the author a search.
  *Why:* a gate people cannot satisfy from its own message gets disabled.
- **The role set has exactly one authoritative definition, and every other statement of it is
  derived or checked against that one.** Where a copy is unavoidable, the copy is verified.
  *Why:* one project had the enforcing rule and the board tooling's own list disagree, and the
  result was a role that was allowed to commit but not allowed to move the board — discovered by
  the seat that held it.

## 3. REFUSAL CONDITIONS

- The subject carries no role declaration ⇒ reject the commit.
- The subject declares a role outside the closed set ⇒ reject, listing the legal set.
- An automated entry path is not covered by the same rule ⇒ that is a defect in the installation,
  discoverable by the drift report rather than at the next audit.

Deliberately **not** a refusal here: message length, tense or wording. Those are the adapter's
conventions, and stacking them into this gate makes the one enforced rule negotiable.

**One convention is doctrine rather than adapter taste, and it belongs beside this gate rather than
inside it:** **no generated co-author trailers**, ever
([`../doctrine/commit-hygiene.md`](../doctrine/commit-hygiene.md) § A.1). Whether you enforce it
here, in a separate hook, or by review is your call; that it is a rule is not.

## 4. WHAT GREEN MEANS

1. A commit whose subject carries a declared role is created **without comment** — the guard is
   invisible when satisfied.
2. A commit whose subject does not is **rejected**, the commit does not exist afterwards, and the
   author is shown the rule and a valid example.
3. The history can be filtered by role, and the count of unattributed commits in any recent
   window is **zero** — a number the drift report states rather than assumes.

## 5. MINIMAL INTERFACE

**In:** a proposed commit subject; the declared role set.
**Out:** accept silently, or reject with the rule, the legal set, and one valid example.
**Not in:** who the human author is (the version control system already records that), and any
judgement about the change's content.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/githooks/commit-msg` — KIT-CLASS **MIXED**: this sheet describes the **kit half**
  (the closed set, enforced at write time, with an instructive refusal). The set's *membership*
  is the project's law and must be replaced on adoption — the initializer stamps it.
- `scripts/githooks/applypatch-msg` — KIT-CLASS: KIT. The same rule on the patch-application
  entrance.
- `scripts/check-board.sh` — the drift report's role-prefix scan, which is how § 4's zero is
  measured; contracted in [drift-report.md](drift-report.md).
- The single-definition invariant is why the set is held in **one** enforcing file and *derived*
  everywhere else rather than retyped. The places it appears are listed in
  [`../EXTRACTION.md`](../EXTRACTION.md) § 2.4 — **that table is the count** — and they change
  together or not at all. *The enumeration that used to stand here named four of them and was one
  short on the day it was written; a copy of a list is the thing this invariant exists to forbid,
  and a sheet that keeps one is arguing against itself.*
