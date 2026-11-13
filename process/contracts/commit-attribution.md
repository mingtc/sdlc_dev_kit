<!-- KIT-CLASS: KIT — contract sheet: commit attribution. See process/EXTRACTION.md. -->
# CONTRACT — commit attribution

## 1. PURPOSE

To keep the history **answerable by role** — *which hat did this?* — so that the ledger can be
filtered, audited and trusted years later without asking anybody.

## 2. HARD INVARIANTS

- **Every commit subject declares the acting role, in one fixed, machine-greppable shape.** The
  shape is the same for every role and appears at the start of the subject.
  *Why:* a convention that varies by author is a convention only its author can query.
  *Which role to name on day one, before any issue exists:* [`role-gate.md`](role-gate.md) § 2a.
- **The role set is CLOSED and shared.** A subject naming a role outside the declared set is
  rejected exactly like a subject naming none, and so is an empty subject.
  *Why:* an open set decays into free text within a month, and then the filter that made the
  history answerable returns nothing.
- **Enforcement is mechanical, at the moment of writing, for an entrance named below.** The rule is applied by the version
  control system itself as the commit is created, not by review, not by a later sweep.
  *Why:* a described boundary is a suggestion and an enforced one is a wall; every unenforced
  attribution convention this process has met eroded silently.
- **Every path that creates a commit is covered by a layer that names it.** An entrance version
  control runs a message hook on is refused at write time: an ordinary commit, a patch applied
  with `am` or by `rebase --apply` (both run the patch-application hook), any commit made after
  `cherry-pick -n` or `merge --squash`, and a commit replayed by `cherry-pick` or a rebase's pick
  (which run no `commit-msg`; the hook that runs on a replay applies the same rule). Plumbing
  (`commit-tree`), `--no-verify` on an ordinary commit, a clone with no hooks wired, and two
  replays that reach no message hook after the message is final (`cherry-pick -e`, and a rebase pick
  finished with `rebase --continue` after a conflict) are caught after the fact by the drift
  report's role-prefix scan on the trunk.
  *Why:* one unguarded entrance is the whole fence, so each entrance names the layer that covers it.
- **The rejection explains the rule and shows a correct subject.** A refusal that only says "no"
  costs the author a search.
  *Why:* a gate people cannot satisfy from its own message gets disabled.
- **The role set has exactly one authoritative definition, and every other statement of it is
  derived or checked against that one.** Where a copy is unavoidable, the copy is verified.
  The definition is the hook's base set plus the layer files one library reads; a layer only adds
  ([`../EXTRACTION.md`](../EXTRACTION.md) § 2.4).
  *Why:* one project had the enforcing rule and the board tooling's own list disagree, and the
  result was a role that was allowed to commit but not allowed to move the board — discovered by
  the seat that held it.

## 3. REFUSAL CONDITIONS

- The subject carries no role declaration ⇒ reject the commit — **except for the two exemptions
  below, which are part of the rule and not a weakening of it.**
- The subject declares a role outside the closed set ⇒ reject, listing the legal set. *No exemption
  reaches this one: a declared role is either legal or it is not.*

**The two exemptions, stated here because an implementation built from an unconditional rule is
broken on its first day.**

1. **Host- and tool-generated subjects are exempt** — the merge, revert and autosquash families a
   version-control tool writes for you. *Why:* nobody authored them under a role, so there is no
   role to declare; a hook without this rejects every merge commit. **Match the tool's own generated
   forms and nothing wider** — a glob loose enough to catch a human sentence that merely opens with
   the same word is a hole.
2. **A documented environment escape is exempt**, for importing a third party's commit verbatim,
   where rewriting the subject would falsify the record. *Why:* the alternative is that an
   unattributable import cannot be committed at all. **Only explicit truthy values enable it** —
   unset, empty and `0` must all read as *off*, or the escape is on by accident for everyone.

*Both are exemptions from the DECLARATION requirement only, and both belong in the contract rather
than only in the implementation: an installation that re-implements this sheet literally rejects its
own first commit, and the day-one recipe depends on the escape.*
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
2. A commit whose subject does not is **rejected** at an entrance § 2 names as refused at write
   time, the commit does not exist afterwards, and the author is shown the rule and a valid
   example. Any other entrance is counted by item 3.
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
- `scripts/githooks/prepare-commit-msg` — KIT-CLASS: KIT. The same rule on the replay entrance: it
  runs `commit-msg` for a commit `cherry-pick` or a rebase is making, and the refusal prints that
  operation's own way out. `MSG_OK=1` is the escape; `--no-verify` does not reach it.
- `scripts/check-board.sh` — the drift report's role-prefix scan, which is how § 4's zero is
  measured; contracted in [drift-report.md](drift-report.md).
- The single-definition invariant is why the set is held in **one** enforcing file and *derived*
  everywhere else rather than retyped. The places it appears are listed in
  [`../EXTRACTION.md`](../EXTRACTION.md) § 2.4 — **that table is the count** — and they change
  together or not at all.
