<!-- KIT-CLASS: KIT — contract sheet: the auxiliary trunk checkout. See process/EXTRACTION.md. -->
# CONTRACT — the auxiliary trunk checkout

## 1. PURPOSE

To let **board changes land on the trunk while the operator's own workspace sits anywhere** — on
a work branch, mid-edit, dirty — without ever touching that workspace.

**THE COMMONEST CASE OF "anywhere" IS A REVIEW, and this sheet owns saying so.** During a review the
two trees have different jobs at the same moment: **the reviewer reads the WORK BRANCH** — checked
out in their own workspace — **while the board move that records the verdict happens HERE**, in this
checkout, on the trunk. They are not alternatives and neither is the "real" one. **How the reviewing role does
that is authored where that role is described** — in the stock harness, `.claude/roles/qa.md`, named
rather than linked because these sheets are the route for an adopter who takes none of it. What
belongs *here* is the fact that **an operation spans two trees at all**, which is the split this
sheet exists for.

*Why it is stated here and nowhere else, and it is a finding rather than a preference:* measured
across the sheets that describe operations spanning two trees, **each held exactly half the
situation** — this one described worktrees and never mentioned a reviewer; the landing sheet
described the review-to-land transition and never mentioned a worktree. **Neither knew it was
describing the same moment**, which is why no sheet noticed the question existed. A reimplementer
working from this sheet alone learned what the standing checkout is for and never learned who was
reading what while it was used.

**AND, SAID PLAINLY BECAUSE ITS ABSENCE COST A PROJECT ITS TRUNK: it is FOR BOARD FILES, and it is
not a spare checkout.** It is the only checkout sitting on the trunk while the main one is on a work
branch, which makes it look like a convenient clean tree — and everything written about it described
how the *scripts* use it, never what an operator may not do in it. **An operator may not use it as a
workspace.** Do not build in it, do not materialise files in it, do not `git checkout <ref> -- .`
into it, and do not run a blanket `git add -A` there. Its HEAD **is** the trunk and its push target
**is** the trunk, so anything present in that directory is one ordinary commit away from `main`, with
no branch and no landing gate in between. `git checkout <ref> -- .` is the route to know: it writes
the **index** as well as the working tree, so a plain `git commit -m` carries the payload, and no
guard can see a commit the operator makes by hand.

## 2. HARD INVARIANTS

- **The operator's workspace is NEVER switched, reset, stashed or committed from.** Not
  temporarily, not "safely", not with a promise to switch back.
  *Why:* the interrupted case is the common case; a tool that borrows a workspace and dies
  half-way has destroyed work its user never offered it.
- **Board publication happens in a SEPARATE checkout of the same repository, pinned to the
  trunk.** It is machine state, excluded from the repository's own tracked content.
  *Why:* if the publication area were tracked, every board change would show up as a change to
  the project.
- **The auxiliary checkout is SYNCHRONISED TO THE PUBLISHED TRUNK before every operation.** It
  starts each operation from the published state, never from whatever it held last time.
  *Why:* a stale publication area silently re-publishes an old tree and reverts other people's
  board changes.
- **That synchronisation RESETS the auxiliary checkout to the published trunk, and REFUSES first
  over anything the reset would destroy** — uncommitted tracked changes (discarded only on an
  explicit instruction) and unpublished commits (no opt-out). So nothing durable may be left
  there: every operation publishes what it commits before it returns
  ([`board-mover.md`](board-mover.md) § 2).
  *Why:* that area is shared between lanes, so what is left there blocks the next operation and
  may be another run's work; the drift report checks this specifically.
- **Concurrent operations are serialized by a lock, and an abandoned lock is reclaimable.** The
  lock is acquired atomically; a stale one is detected by liveness, not by age alone.
  *Why:* a lock nobody can reclaim converts one crashed run into a permanently stuck board; a
  lock reclaimed by age alone corrupts a slow but living run.
- **The operator's workspace may be brought forward only when it is UNAMBIGUOUSLY SAFE** — on the
  trunk and clean. Otherwise it is left alone, and being stale is the normal, stated outcome.
  *Why:* stale-until-you-update is how everybody already works; surprise updates are not.
- **The trunk is CONFIRMED, never inferred silently.** The identity of the trunk comes from a
  declared source; a chain of fallbacks that ends in a hard-coded name must at least announce
  what it chose.
  *Why:* a silently defaulted trunk sends the first board change to a branch nobody meant, and it
  is discovered days later.
- **A publication that loses a race is RETRIED against the new tip, within a stated bound — and a
  conflict STOPS.** Fetch, rebase onto the remote tip, retry; a conflicted rebase restores the
  pre-attempt state and says what a human must do. The bound is stated in the implementation, and
  the final failure **names the commits that did not land**.
  *Why:* two lanes publishing board changes will collide, and a single bare push loses silently.
  Silent conflict resolution on the trunk is worse than the race; an orphaned commit that is
  *reported* costs a minute, and one discovered weeks later costs a day.

## 3. REFUSAL CONDITIONS

- The publication remote or the trunk cannot be resolved ⇒ refuse **before** any change, naming
  what to configure.
- The lock cannot be acquired within its bound, and the holder is alive ⇒ refuse with the holder
  named. Waiting forever and stealing the lock are both worse.
- The auxiliary checkout holds uncommitted tracked changes ⇒ refuse, naming them, unless the caller
  explicitly asked for them to be discarded.
- The auxiliary checkout holds commits not on the published trunk ⇒ refuse, naming them. There is no
  opt-out: discarding a commit is a deliberate hand command.
- The auxiliary checkout cannot be created or synchronised ⇒ refuse; do **not** fall back to the
  operator's workspace. The fallback is the one behaviour this contract exists to forbid.
- The publication of a committed change fails, or the retry bound is exhausted, or a rebase
  conflicts ⇒ report loudly that the change is local-only, name the recovery and the unlanded
  commits, and exit non-zero.
- A version-control error is swallowed ⇒ that is a defect in the implementation. No quiet pull, no
  discarded exit status: a diverged pull fails *silently* unless it is fast-forward-only and
  checked.

## 4. WHAT GREEN MEANS

1. The operation's commit exists **on the trunk of the publication remote** — its identifier is
   printed.
2. The operator's workspace is **byte-identical** to before, unless it was unambiguously safe to
   bring forward, in which case the report says it was brought forward.
3. The lock is **released**, including on failure.
4. The auxiliary checkout holds **no unpublished commit** — the state the drift report's sixth
   check independently confirms.
5. The publishing operation **reports the main checkout's actual ahead/behind state on exit
   whenever the trunk is checked out there**, so a caller that also made a commit by hand learns
   that something is still local ([`../doctrine/commit-hygiene.md`](../doctrine/commit-hygiene.md)
   § A.3 — the *looks-pushed* trap). **The condition is part of the invariant, not a gap in it:**
   the report is about the MAIN checkout's trunk, so where the trunk is checked out somewhere else
   there is no such state to read from there, and the operation says which case it is rather than
   printing a reading it did not take. *An implementation built from an unconditional wording emits
   a number from the wrong worktree, which is worse than the silence it was trying to avoid.*

## 5. MINIMAL INTERFACE

**In:** the repository; the publication remote; the trunk's identity; the change to publish.
**Out:** the published commit identifier, the trunk it landed on, whether the operator's
workspace was brought forward, the ahead/behind state on exit, and a non-zero exit for every
refusal above.
**Not in:** what the change is. This machinery does not know a board from a document.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/lib/kanban-worktree.sh` — KIT-CLASS: KIT. A standing detached worktree at the
  repository root, excluded from tracked content, lock-serialized, reset to the remote trunk on
  each operation.
- Its consumers are `scripts/move-issue.sh`, `scripts/finish-pr.sh`, `scripts/archive.sh` and
  `scripts/subtask.sh` — contracted in [board-mover.md](board-mover.md),
  [landing-gate.md](landing-gate.md), [archive-sweep.md](archive-sweep.md) and
  [issue-creation.md](issue-creation.md).
- `scripts/lib/push-retry.sh` — KIT-CLASS: KIT. The § 2 retry invariant: fetch plus a bounded
  rebase-onto-remote-tip retry instead of a single bare push. Sourced by the worktree library, and
  usable standalone by any other script that publishes a trunk commit outside the auxiliary
  checkout (a hand-made direct-to-trunk commit), under the same contract.
- The trunk-confirmation invariant in § 2 is a standing finding in
  [`../EXTRACTION.md`](../EXTRACTION.md) § 2: a resolution chain that ends in a hard-coded name
  can only guess (it warns, but cannot know it is right), so the **initializer** confirms the trunk up front.
