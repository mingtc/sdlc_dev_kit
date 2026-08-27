<!-- KIT-CLASS: KIT — transferable doctrine. § A is the pattern; § B is the fill-in for YOUR conventions. -->
# Commit-hygiene doctrine — what a commit owes beyond its content

**KIT-CLASS: KIT.** Four rules that used to live in one project's adapter as *"house rules"* and
were re-derived, at cost, by every adopter who did not inherit them. They are **kit doctrine**, not
project taste: each one exists because a specific, silent failure happened, and each one's remedy
is cheap enough that no project has a reason to opt out.

**What this sheet is NOT.** It does not govern subject *style* — tense, length, body format,
whether a body is required. That genuinely is the adapter's, and stacking it here would make the
four rules below negotiable by association. It also does not restate the **enforcement** contract:
that is [`../contracts/commit-attribution.md`](../contracts/commit-attribution.md). This sheet is
the *reasoning*, and the two rules the contract deliberately leaves out.

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

**The corollary that gets forgotten: the set of legal roles has ONE definition.** The adapter's
table, the enforcing hook, the board mover's whitelist and the drift report's scan are four
statements of one fact — so three of them are **derived or checked**, never retyped. A project that
retyped it discovered the drift the hard way: the enforcing hook accepted a role the board mover
did not, so the seat could commit but **could not move a card**, and had to borrow another hat to
do it.

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

**How to adopt:** A.1 and A.2 go in the adapter's house rules as one line each (each pointing at
your enforcing hook — in the reference implementation both rules live in one hook). A.3 goes in
the implementer's and reviewer's Definition of Done — it is a
*read*, not a ritual, and it takes one command. A.4 goes wherever your landing outcome vocabulary
is defined, so that "verified but not landed" is a **verdict the process can express**; a process
whose only outcomes are PASS and FAIL will report a stranded landing as one of the two, and both
are wrong.

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
