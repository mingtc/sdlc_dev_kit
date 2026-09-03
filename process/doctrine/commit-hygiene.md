<!-- KIT-CLASS: KIT — transferable doctrine. § A is the pattern; § B is the fill-in for YOUR conventions. -->
# Commit-hygiene doctrine — what a commit owes beyond its content

**KIT-CLASS: KIT.** Rules that used to live in one project's adapter as *"house rules"* and
were re-derived, at cost, by every adopter who did not inherit them. They are **kit doctrine**, not
project taste: each one exists because a specific, silent failure happened, and each one's remedy
is cheap enough that no project has a reason to opt out. *(The § A headings are the list. A number
written here instead would go false the first time this sheet grew — and it did.)*

**What this sheet is NOT.** It does not govern subject *style* — tense, length, body format,
whether a body is required. That genuinely is the adapter's, and stacking it here would make the
rules below negotiable by association. It also does not restate the **enforcement** contract:
that is [`../contracts/commit-attribution.md`](../contracts/commit-attribution.md). This sheet is
the *reasoning*, and the rules the contract deliberately leaves out.

---

## A. The pattern (this is the transferable part)

### A.1 — **No generated co-author trailers, ever**

> No `Co-Authored-By:` line naming a tool, and no *"Generated with …"* line, in any commit
> message. The same rule covers a spec, an issue file's activity entry, and a review note.

**Why, and it is not modesty.** Three independent reasons, and dropping any one still leaves the
rule standing:

- **Attribution in this process is by ROLE, not by actor.** The history's one queryable axis is
  the role prefix (§ A.2). A trailer naming the tool adds a second, unqueryable axis that answers
  a question nobody asks of the ledger, and it dilutes the one that is answered.
- **It is a claim about provenance that ages badly.** The tool's name, version and vendor all
  move; the commit does not. A year on the trailer is a fact about a product that no longer
  exists in that form, sitting in an immutable record.
- **It is noise at scale.** In a repository where most commits are made by dispatched workers,
  a per-commit trailer is a per-commit tax on every `git log` a human reads, forever.

**The rule is stated as an absolute on purpose.** "Usually not" is a rule every hurried session
resolves in favour of the default the tool ships with — and the default is to add the trailer.
An absolute is a rule a hook can enforce and a reviewer can check by looking.

**And a hook does enforce it — the same one that enforces § A.2.** The reference implementation's
commit-message guard (`scripts/githooks/commit-msg`, delegated to from `applypatch-msg` so the
patch-application entrance judges the same way) reads the whole message rather than only the
subject and refuses a `Co-Authored-By:` naming a **tool** — the markers are one named line in the
hook, extended in one place — or a *"Generated with …"* line; a trailer naming a **human** is
legitimate practice and is accepted, and the documented bypass exists for carrying somebody
else's commit verbatim, not for your own.

### A.2 — **The subject declares the acting role, and the guard runs at write time**

> Every commit subject opens with the acting role in a fixed, machine-greppable shape. The rule
> is enforced by the version-control system **as the commit is created** — never by review, never
> by a later sweep.

The invariants (a closed role set, every entry path guarded, an instructive refusal, one
authoritative definition of the set) are the contract's; the **reason for the write-time
placement** is doctrine, and it is this:

**A described boundary is a suggestion; an enforced one is a wall.** Every unenforced attribution
convention this process has met eroded silently — one unnoticed commit at a time, with no moment at
which anybody decided to stop. By the time the erosion is visible the fix is a history-wide audit
nobody will fund. The refusal at write time costs the author one edit and is paid once.

**The corollary that gets forgotten: the set of legal roles has ONE definition.** Every other
statement of it — the adapter's table, the enforcing hook, the board mover's whitelist, the drift
report's scan, and whatever else your tooling has since grown — is **derived or checked**, never
retyped. **Keep the enumeration of those carriers in one place, and count it there rather than in a
sentence**: a number written into prose beside the list is the first thing to go false, and it goes
false silently, because adding a carrier is not an edit anybody thinks of as touching this rule. A
project that retyped the set discovered the drift the hard way: the enforcing hook accepted a role
the board mover did not, so the seat could commit but **could not move a card**, and had to borrow
another hat to do it.

### A.3 — **Hand the commit, then READ `git status -sb` before declaring done**

> After any commit you made by hand — as opposed to one a kit script made for you — read the
> short-branch status and confirm what you believe about it. Declaring done without that read is
> not a shortcut; it is an unverified claim.

**Why: the LOOKS-PUSHED trap.** The kanban scripts push **their own** commits. A hand-made trunk
commit does not. A session that does both — commits a document by hand, then runs a board move —
sees a successful push scroll past and concludes everything landed. It did not: the board commit
is on the remote and the document is local-only. The two facts are indistinguishable from the
output unless you ask.

The same trap has a second mouth: **a push that is refused by the far side**. Local `commit`
succeeds, exits zero, and prints a hash. Nothing in that output knows the remote will reject the
ref. A run that treats "the commit succeeded" as "the work landed" can strand an entire phase
locally while the board and the running log both claim it shipped — and the board is the artifact
everyone else reads.

**Two hardenings worth taking, in this order:**

1. **Encode it where it cannot be forgotten.** A script that pushes should report its **actual**
   ahead/behind state on exit, so a leg reading the output learns that something is still local.
   A remembered check is a check that is skipped under time pressure.
2. **Never swallow a version-control error.** No `git pull -q 2>/dev/null`; a diverged pull fails
   *silently*. Use the fast-forward-only form and check the result. A swallowed error is the
   defect, not the fix.

### A.4 — **Never end a landing on an unpushed looks-pushed state**

> A landing is not finished when the merge exists locally. It is finished when the trunk commit
> is **published** — or when the run has said, loudly and in the artifact the next reader opens,
> that it is not.

This is A.3's rule turned into an obligation on the *close* of a work item rather than on a single
commit, and it has three parts:

- **Report the local-only state as a first-class outcome, not a footnote.** When publication is
  impossible — a refusing remote, no network, a lock you will not steal — the honest close is
  *"complete and verified, NOT landed, local-only"*, said in the issue's own activity log. A run
  that reports success and leaves the commit local has produced a board that lies.
- **A failed publication names what did not land.** An orphaned commit that is *reported* costs a
  minute; one discovered by digging through reflogs weeks later costs a day. Bound the retries,
  state the bound in the code, and make the final failure enumerate the commits still local.
- **A conflicted rebase stops.** It restores the pre-attempt state and says what a human must do.
  Silent conflict resolution on the trunk is worse than the race it was trying to win.

### A.5 — **Coupled operands across the commit lanes: the gate's unit is the SET**

> Where a change's operands sit in **both** commit lanes and are only **jointly** satisfiable, no
> reading of either lane alone is correct. The unit the gate is being asked about is not the file —
> it is the **SET** — and the invariant is **ALL-OLD or ALL-NEW, never MIXED**.

The code-vs-metadata rule ([`../MANUAL.md`](../MANUAL.md)) creates two commit lanes, and most changes
sit in one of them. Some do not: a guard and the record it reads, a declaration and the ceiling it is
held against, a procedure naming two artifacts. For those, the numbered points below hold, and they
are the whole rule:

1. **The branch gate proves ALL-NEW.** The code lane is the only one that can hold every operand at
   the same time, so joint satisfaction is demonstrable exactly once, and that is where.
2. **The trunk stays ALL-OLD until the merge, and the run records that window as the EXPECTED
   state** — a named, bounded incoherence, not a breach. A report that calls the window a breach
   teaches its readers to ignore the report.
3. **The merge is the atomic transition.** A squash landing leaves no reading in which the set is
   half-applied.
3b. **A RECORD WRITTEN AHEAD OF ITS STATE SAYS SO, IN ITSELF.** Point 2 makes the window
   *expected*; this makes it **self-disclosing**. A metadata annotation written in the trunk lane at
   the true time — the moment the decision was made — describes a state that does not exist yet, and
   a reader arriving during the window sees a record that appears **false**. So the record names, in
   one clause, **what an early reader will see, and how to tell that from the record being wrong**:
   *"the branch this refers to lands with the set; until it does, `<path>` reads all-old — if you see
   that, you are early, not looking at an error."*
   *Why this is a numbered point and not advice:* without it, the window is something a reader has to
   be **told about out of band** — by whoever happens to be present — and out-of-band knowledge is
   exactly what does not survive a handoff. With it, the artifact discloses its own bounded
   incoherence, and the disclosure travels with the artifact. **The test of the clause is whether it
   distinguishes EARLY from WRONG.** A note saying only *"this is expected"* fails it: a reader who
   suspects an error is not helped by being told not to.
4. **The post-landing trunk run proves all-new landed together** — and it is a **detector, never a
   gate**: it cannot abort a merge that has already happened. It names the ref it read, and a MIXED
   trunk is escalated rather than quietly re-run.

#### The two shapes this rule covers, because one of them does not look like it

**Everything above is stated in terms of "operands" and "lanes", and readers instantiate that in the
obvious way — a document describing code, where the document is metadata and the code is code. Call
that the DOCUMENTATION-OF-CODE case. It is the easy one and it is the one people find.**

The other one is the **EXECUTABLE-DECLARATION** case, and it is missed because the file that lands in
the metadata lane *is not documentation at all — it is executable, and it is the thing doing the
guarding*:

> A cross-cutting guard lives in the code lane. **The list of what it is enrolled over** — the array,
> the table, the manifest the guard reads — lives in a file your code globs classify as metadata,
> because that file's extension or path says configuration. Adding the guard without its enrolment
> ships a check nothing is subject to; adding the enrolment without the guard ships a list pointing at
> something that does not exist. **Only jointly satisfiable, in both lanes — A.5 exactly.**

**The tell that you are in this case rather than outside the rule: you are about to write a comment
explaining why your situation is really covered.** A site that has to argue the general rule applies to
it is reporting that the general rule does not look like it does. *Measured in the donor project: nine
instances across five work items, and every one shipped the same apologetic comment at the enrolment
site — nine independent readings of this section, none of which recognised its own case in it. The
comment was not wrong. It should not have had to exist.*

**Nothing about the handling changes** — every numbered point above holds identically (count them
there; this sentence said "the four" until § 3b was inserted and made it five, which is the stale-
census class `staleness.md` § C names, committed inside the sheet about coupled changes), and the
set is still the unit. What changes is only that the executable-declaration case is now named here, so the
next reader does not have to decide whether their situation is a member.

**A MIXED trunk at any reading is the breach, and it is the only one this shape can produce.** So an
instruction keyed to *a single append* — re-run the trunk gate after each metadata commit — is
correct for a lone trunk-lane operand and **impossible** for a coupled one, because there is no
moment at which one lane's commit makes the set true. The coupled form is keyed to the **landing of
the set**.

**And a procedure whose operands straddle the lanes reads as obeyed precisely because it cannot be
executed.** *"X and Y in the same commit"*, where X is trunk-lane and Y is branch-lane, is not hard
to comply with — it is unachievable. Compliance is therefore never observed to fail, and the
retrospective instances that accumulate in its place look exactly like a rule being followed; the
defect surfaces only on the first genuinely prospective occasion, which may be many phases after the
rule was written. The consequences follow, and the last of them belongs to another sheet:

- **A procedure that names two artifacts names their LANES.** When a rule says *"in the same
  change"*, its author checks whether both operands *can* be — and if they cannot, the rule states
  the split shape instead: which lands first, on which lane, and what must be quoted to prove the
  order. *"Same commit"* is a **purpose** (the second artifact cannot precede the first) wearing a
  **mechanism**'s clothes. State the purpose and give it a mechanism that exists.
- **Prove the ORDER, never assert it.** Where the split shape is the rule, the evidence is both
  commit identifiers plus the order demonstrated. Atomicity is what the single commit was buying;
  two commits buy it only if the sequence is shown.
- A rule that has had no prospective instance yet should say so where it is recorded. That is
  [`fix-execution.md`](fix-execution.md) § A.2's, not this sheet's.

**The reading half is [`instruments.md`](instruments.md) § A.9's**, and it is why this rule binds the
reader as well as the author: a gate run is a reading of **one lane**, and an exit code does not say
which one. Quote the lane, or the verdict is read wider than it is.

#### A straddling guard cannot be made true on the trunk — the compensators are the law

**The closed question, stated first so nobody goes looking.** Where the split puts a guard's operands
in different lanes, a fix in the code lane can only ever be gate-run on a branch or on a merge
preview: the trunk is gated **only after landing**. That is **structural, and no mechanism removes
it.** A project that goes looking for one will either not find it or build something that returns a
true verdict about the wrong unit — which is worse than the gap, because it is a green light. What is
law is the compensator set, measured in practice rather than reasoned out:

1. **After any landing that touched the trunk lane, the actor re-runs the gate ON THE TRUNK and
   quotes both lanes separately.** One exit code cannot speak for two lanes.
2. **The lander's post-merge check is a DETECTOR, never a gate**, and it names the ref it read. A
   tool that *reads* as a gate while being advisory is the false-assurance shape. *(The reference
   implementation already behaves this way — its landing script runs the tracked gate after the
   merge, reports the result on a fixed machine-readable line, and deliberately does not let that
   result move its own exit code. [`../contracts/landing-gate.md`](../contracts/landing-gate.md) is
   where a project states it as an invariant rather than leaving it to the implementation.)*
3. **A trunk-lane commit is followed by the trunk gate at the pushed tip before the act is declared
   done** — including the coordinating seat's own commits, which are the ones most likely to skip
   it, because nobody reviews the coordinator.
4. **Every board and register read during a run comes from a NAMED REF**, never from whichever
   checkout happens to be current. *(Already an invariant in its own right —
   [`../contracts/drift-report.md`](../contracts/drift-report.md) requires every check to name the
   source it read beside its own verdict. It is listed here because the compensators are a **set**,
   and one that is satisfied elsewhere is still one of them.)*

Together these do not make a straddling guard true on the trunk. They make the window in which it is
false **named, bounded and observed** — which is the strongest property available here, and the
reason to state the impossibility out loud instead of leaving a gap that reads like an unfinished
feature.

**How to adopt:** A.1 and A.2 go in the adapter's house rules as one line each (each pointing at
your enforcing hook — in the reference implementation both rules live in one hook). A.3 goes in
the implementer's and reviewer's Definition of Done — it is a
*read*, not a ritual, and it takes one command. A.4 goes wherever your landing outcome vocabulary
is defined, so that "verified but not landed" is a **verdict the process can express**; a process
whose only outcomes are PASS and FAIL will report a stranded landing as one of the two, and both
are wrong. A.5 has two audiences and goes to both: the handoff step where a gate result is quoted
(name the lane; where the operands straddle, quote the set), and the landing contract (the post-merge
run is a detector, and it completes the proof the branch could only half make).

---

## B. Your project's instance — **fill this in**

> **PROJECT INSTANCE from here down.** Nothing here is inherited.

**What goes here:**

1. **Your role-prefix set**, or a pointer to the adapter table that holds it, plus the paths of
   the other statements of it and how each is derived or checked.
2. **Your subject-style conventions** — the ones this sheet deliberately does not set: tense,
   length, whether a body is required, how an issue id appears.
3. **Your landing-outcome vocabulary**, including the word your process uses for *complete and
   verified but not published*. If it has no such word, that is the gap A.4 predicts.
4. **Any hardening you built for A.3** — the script that reports ahead/behind, the hook, the
   check in a close ritual.
5. **Your coupled operand sets** (§ A.5) — the pairs your own code-glob declaration puts in
   different lanes, named as sets rather than as files; **where the post-landing trunk run's verdict
   is recorded**, so the detector has somewhere to be read; and, for each procedure in your process
   that says *"in the same change"*, whether both its operands can in fact be. *A blank here is not
   "we have none": it is "nobody has looked", and the first prospective instance is where you find
   out.*

### A worked example from the donor project (anonymized)

The donor's remote spent a stretch of days **refusing every push, repo-wide** — a hook on the
hosting side rejected every ref, including a brand-new throwaway branch; `fetch` still worked.
Local commits succeeded normally. Several work items were implemented, reviewed and verified
during that window, and each one closed as **"complete, verified, LAND-READY — local only, no
board move"**, with the activity entry appended by hand rather than by the pushing script.

That is the rule working. What made it work was not luck: the runs already carried the standing
check *"after any hand-made trunk commit, read `git status -sb` before declaring done"*, and the
process already had a word for a finished-but-unlanded item. Without either, the same window
would have produced a board claiming a phase had shipped while the code sat in one checkout — and
the discovery would have come from whoever cloned next.
