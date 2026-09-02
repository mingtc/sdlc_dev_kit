<!-- KIT-CLASS: KIT — contract sheet: the drift report. See process/EXTRACTION.md. -->
# CONTRACT — the drift report

## 1. PURPOSE

To answer *"is the board telling the truth?"* on demand, by checking the small set of
disagreements this process can actually produce — before a human plans a day around one of them.

**And one question that is not about the board**, carried here because it must be asked at the same
cadence and then never again: *has day one finished — has the scaffolding been replaced?* It rides
in this instrument rather than in its own, and **it is kept out of the report's verdict**, for the
reasons invariant 7 gives.

## 2. HARD INVARIANTS

**One check per invariant below. Each is an invariant of the process, not a feature of a report; a
reimplementation owes every one of them, in any presentation it likes.**

*(This paragraph used to open "Six checks", and § 4 used to repeat the numeral. A seventh invariant
was added and the count went false in two places at once — the exact shape
[`../doctrine/staleness.md`](../doctrine/staleness.md) § C forbids. **The list below is the count**;
the reason a number was there at all is preserved in § 4.1, which needs an expectation to detect a
missing line against, and now derives it from this list instead of restating it.)*

- **1 — Location agrees with the record.** For every live item, the state declared by its last
  activity entry is the state it is actually in.
  *Why:* these two disagree only when someone moved an item by hand, and that is exactly the
  event no other check can see.
- **2 — The reviewed-and-done column is within its depth threshold.** Over it, a sweep is due and
  the report names the sweep.
  *Why:* an unbounded terminal column turns the board back into a list, which is the state the
  board was introduced to fix.
- **3 — The running narrative log is within its size threshold.** Over it, a rotation is due and
  the report names it.
  *Why:* a log nobody can open is a log nobody reads, and the process's memory is in it.
- **4 — Identifier integrity across EVERY state and EVERY identifier space the process
  maintains — each space named separately, and each skipped one skipped with its own reason.**
  Every item declares an identifier; identifiers are unique across the whole lifecycle; each
  item's declared identifier matches its own name. **The board is one identifier space. A
  REGISTER is another** — a decision register, a requirements register, any file whose entries
  carry handles that later text resolves through. Where a space is ordered by anything other than
  its identifiers, **the highest identifier is read order-independently**, and the check reports
  it, so nobody has to derive the maximum by position.
  *Why:* a duplicate identifier makes every reference ambiguous. On the board it is created by a
  rename or a copy — both of which look innocent at the time. **In a register it is created by
  concurrency, and it arrives with no witness at all:** two authors minting the same id under
  *different section headings* of an append-only file produce **no textual conflict**, so the
  merge is clean and the duplicate lands unremarked. Measured in a project running this process:
  two sessions minted the same register id within an hour, and the only defence was an instruction
  in the register's own header asking the author to re-read first — an instruction where the rest
  of this process uses a fence. The order-independence half is measured too: a section-grouped
  register put a later id *above* an earlier one, so reading the last heading in file order
  returned a number that was not the maximum, and a checklist keyed on it would have proposed an
  id that already existed — **and would have halted on a healthy register**, which is a guard
  nobody re-arms.
  *Deliberately not enumerated here:* which spaces a project has. The kit's own implementation
  names the board and one register because it ships those two; a project that keeps a third owes
  it a reading, and this sheet would be wrong rather than general if it fixed the number.
- **5 — Recent history is attributed.** Every commit subject in a recent window carries a
  declared role, and the check understands collapsed commits so a landing is judged by its own
  subject.
  *Why:* attribution erodes one unnoticed commit at a time; a periodic count is what makes the
  erosion visible while it is still small.
- **6 — NO HOME the process writes to is holding unpublished work — EVERY such home, each named
  separately — and the check states which kind of stranding it looked for.** A project has more
  than one surface from which work reaches the trunk: whatever mechanism publishes board changes,
  **and the primary checkout itself**, which is where anything the process classifies as metadata
  is written and committed. The check enumerates them, reports each with its own reading, and skips
  any one of them with its own reason.
  Work can be stranded in a home two ways — **reachable from a ref there but not from the trunk**,
  and **reachable from nothing at all** (a commit orphaned when a position moved). A check that
  measures only the first says so, in its own output, rather than reporting an unqualified pass.
  *Why:* **the enumeration is the invariant, because a check that watches one home reads as a
  statement about all of them.** Measured: an implementation watched only the auxiliary publication
  mechanism and never asked the primary checkout the same question — so the one home carrying the
  process's own memory, its rulings and its requirements, was the one home nothing watched, and the
  report said *clean* with a day of unpublished rulings beside it. The recovery cost a successor an
  hour, looking for an authority its own instructions cited. The span matters for the same reason
  one level down: the two kinds of stranding need different instruments — the first is a count
  against a ref, the second needs the local history of positions — and a pass naming neither
  invites the reader to conclude nothing is stranded anywhere. Measured there too: an orphaned
  sibling reported as *in sync* by a check whose count was correct and whose subject was the other
  kind. **This invariant does not require the second kind be checked; it requires that a pass not
  imply it.**
  *Deliberately not enumerated here:* which homes a project has. The kit's own implementation names
  two because it ships two; a project that publishes from a third owes it a reading, and the sheet
  would be wrong rather than general if it fixed the number.
- **7 — Day-one completeness is reported once the project has STARTED, and it does NOT decide the
  report's verdict.** **Started is a property of the repository, not of one tool having run:** any
  signal that work has begun — a board carrying work items, a running log with history, an archive
  with entries, an initializer's own receipt — enables the check. **Where no such signal is present
  the report says the check DID NOT RUN**, and says it in those terms. *Why the enabling condition
  is wider than one tool:* a project may implement this process in its own toolchain and never run
  the reference initializer at all — a supported route — and gating on that tool's receipt asks
  nothing of exactly the projects most likely to still be carrying the scaffolding, because they
  also skipped the tool that would have stamped it. *Why there is an enabling condition at all — the
  original reason, unchanged:* **a repository that has not started must not be nagged to finish.** A
  fresh unpack has no signal and is asked nothing. *And why the skip must say "did not run":*
  *"nothing to graduate from"* reads as a clean bill, and a reader has to be able to tell an unrun
  check from a passing one — the same distinction every other check in this sheet owes. While the
  project still carries the kit's scaffolding — a `REPLACE`-class file that has not been replaced, a
  `FILL`-class file that still holds a blank — the report says so and names the files. **The verdict
  line stays a statement about the board.**
  *Why the separation is an invariant and not a preference:* the verdict is what other tools consume.
  Measured in this kit: the release ritual's board gate matches the verdict line's text, and the
  initializer's own post-install self-check fails on a drifting board. **A repository one minute
  after initialization has not graduated — by definition — and its board is nonetheless perfectly
  truthful.** Wire the two together and the initializer fails its own self-check on every fresh
  install, and no project can cut a release until day one is finished. Both were reproduced before
  this invariant was written. Whether graduation should ever *block* a release is a decision a
  project may take, in the release ritual's own gate list where a reader can see it — never as a
  side effect of a counter inside a report.
  *And the arm does not fall silent once satisfied.* It goes on printing one line naming what it
  read, because an arm that vanishes when clean is indistinguishable from an arm that broke — the
  false-confidence asymmetry [`../doctrine/instruments.md`](../doctrine/instruments.md) § A.4
  forbids. *Self-retiring* means it stops asking for action, not that it stops reporting.
  *Deliberately not enumerated here:* which files carry which disposition. That is the project's
  axis, in [`../EXTRACTION.md`](../EXTRACTION.md) § The second axis: DISPOSITION; this sheet would be
  wrong rather than general if it fixed the membership.
- **The report READS ONLY.** It never fixes, moves, rotates or publishes anything.
  *Why:* a reporter that repairs is a reporter nobody can trust to describe.
- **A check that cannot run says SKIPPED, and says why.** It never reports a pass it did not
  establish.
  *Why:* "no findings" must mean "checked and clean", or the report's only sentence is worthless.
- **EVERY check names the SOURCE it read, beside its own verdict — and a check whose subject is a
  shared-state property reads a source it NAMED, never whichever working copy happens to be
  current.** A check about the published state of the board, the log, or recent history answers
  about the published trunk by name; a check whose subject is genuinely local — "is any home this
  project publishes from holding work that never reached the trunk?" — inspects local refs and
  working copies on purpose and names each one it read. Either way the operand appears in the
  output, once per reading.
  *Why:* measured, and it is the invariant the other two above are special cases of. In one
  implementation **every check but the local-state one** resolved its paths through the current
  checkout. A dispatched leg
  legitimately moves that checkout to its own branch, so each check returned a stale answer that
  looked authoritative — **nobody chose the operand, and nothing in the output revealed it had
  changed.** Costs measured: a board state certified two changes out of date; a log-size check
  frozen at an identical byte count across four consecutive readings; and, worst,
  **an identifier-uniqueness check reporting "N distinct, clean" while the trunk held N+1.** That
  last one is not a degraded check: duplicate identifiers can only *arise* on the published trunk,
  and a branch contains at most one of the colliding pair, so read from a branch the check is
  **structurally incapable of the thing it exists for** — and says clean while being so. The
  general form: *a tool reporting on shared state must name the source it measured, because
  "clean" without a source is a claim nothing can falsify.*
- **A threshold check states WHAT IT MEASURED, not only its verdict.** A check reporting a size or
  a depth names the span it read.
  *Why:* measured — one implementation's log-size check read only the running log's own section
  while the file around it grew to thirty times that span, and reported a comfortable pass the
  whole time. *The measuring device reported OK while blind*, and the verdict alone could not
  reveal it. **The span and the source are the same lesson twice:** this invariant asks *how much
  of the thing* was read, the one above asks *which copy of the thing* — and a verdict missing
  either is unfalsifiable.
- **No location may be the only correct one.** Where a check must inspect a working copy, it locates
  that copy explicitly rather than assuming the report is being run from it.
  *Why:* measured, and it is the trap in the obvious workaround. When the stale checks above were
  worked around by "run the report from a clean checkout of the trunk", the one legitimately-local
  check then reported *"no publication path (skipped)"* — because that path is registered against
  the primary copy, not the one the report was run from. So there was **no location from which the
  whole report was correct**: the primary copy gave one correct check and five stale ones, and a
  trunk copy gave five correct and one blind. A fix that only relocates the caller trades one blind
  check for another.
- **Where the project enforces the no-generated-trailer rule mechanically, the report states what a
  recent window of trunk history holds, over a named window, scoped to a named epoch.**
  *Why:* the hook that enforces that rule is a **write-time wall** — it stops the next commit and
  says nothing whatever about history already written, and `contracts/commit-attribution.md` § 4
  states the count of unattributed commits in a recent window as **zero**. A rule with no reader is
  a rule nobody can show is holding.
  *Conditional on purpose, and the condition is load-bearing:* `commit-attribution.md` says of this
  rule that *"whether you enforce it here, in a separate hook, or by review is your call; that it is
  a rule is not."* An unconditional invariant would quietly upgrade an explicitly optional
  enforcement site into a mandatory check for every reimplementation, which is the opposite of what
  that sheet decided. A project that enforces by review owes this reading nothing.
  *And the epoch is part of the invariant, not an implementation detail:* a rule cannot be violated
  before it existed, so a reading that does not say where it started reports pre-adoption history as
  drift and becomes a finding nobody can act on — which is how a report stops being read at all.
  **The span is commit MESSAGES**, and the reading says so: § A.1 of `doctrine/commit-hygiene.md`
  covers specs, issue activity entries and review notes too, and a clean reading here is not a
  statement about any of them.

## 3. REFUSAL CONDITIONS

- An item carries no identifier at all, or carries one that duplicates another's ⇒ report it by
  name, in both cases, as a finding that needs a human.
- A check's input is unavailable (no history, a publication home that does not exist, offline) ⇒ report
  **skipped with the reason**; never silently omit the line.
- Findings exist ⇒ the report says so in its final line. Whether findings *fail* a build is the
  project's call; **hiding** them is not on the menu.

## 4. WHAT GREEN MEANS

1. **Every invariant in § 2 is represented in the output, and no check is silent.** A missing check
   is itself a finding. **Test it per check, never by comparing two totals:** walk § 2's list and
   confirm each invariant has a line; do not count the report's lines and expect that number to
   match. **They are different quantities on purpose**, and a reader who compares them files a
   defect that is not there.
   - **A check with more than one READING prints each reading, labelled.** One invariant, several
     measurements: a size bound that reads a section *and* the whole file emits a line per reading,
     and a check over several homes emits a named sub-reading per home.
   - **A reading whose subject is ABSENT still prints, naming what was absent.** It does not fall
     silent and it does not pass by default. *This is the property that makes line-counting useless
     and the report trustworthy at the same time: output shape does not tell you which topology you
     are in, because the report says so in words instead.*
   *Both bullets are measured, not reasoned: the reference implementation was RUN in a repository
   with the mover's auxiliary worktree and in one without, and the set of lines it printed was
   identical — the absent-home reading named the path it did not find. This paragraph previously
   said "count the invariants in § 2 and expect that many", which is false against every run.*
   **The reason a number was ever here is preserved:** § 4 needs something to detect a missing check
   against. The list in § 2 is that something. Walk it.
2. Each line states a **count against its bound** where it has one, not an adjective, and names
   the span the count covers.
3. Each line names **the source it read** — the published ref, or the working copy it inspected on
   purpose. A line whose source is absent is a finding about the report, not a pass.
4. The last line is a **single verdict**: clean, or findings-above. One sentence a human can act
   on without reading the rest.
5. **An ADVISORY arm — one that reports without deciding the verdict (invariant 7) — carries the
   literal token `reports only` in its own header line, and consumers MAY key on it.** This is a
   machine contract, not a turn of phrase: reword it and every consumer keying on it changes
   behaviour silently.
   *Why:* measured. A consumer that keyed on the verdict line and then re-scanned the rendered
   findings had no way to tell an advisory line from a deciding one, so an arm whose advisories
   appear on **every** run failed that consumer the moment any unrelated finding flipped the
   verdict — and the failure named the advisory arm. The alternative to a declared token is each
   consumer memorising which section letters are advisory, which goes stale the next time an arm is
   added. **A consumer reading rendered output is second-best either way** (the verdict line is the
   contract-backed key, item 4); this token bounds the damage where a second read is unavoidable.
   *And it binds the arm too:* an advisory arm that omits the token is a defect in the arm, because
   its advisories will be read as decisions.

## 5. MINIMAL INTERFACE

**In:** the board; the running log; recent history; **the state of every home the process publishes
from**; the declared thresholds — **each read from a source the report names, not from an ambient one.**
**Out:** one line per check with its count or its skip reason **and its source**, then one overall
verdict line.
**Not in:** any repair. Every finding names the operation that fixes it and stops there. **Not in
either:** a fetch. Refreshing the published state is a network act with no bound; the report reads
the published ref as it stands, **names the revision it read**, and says how to refresh — a stale
answer that says so beats a hang at session start. *"Names the revision" is the exact obligation:
what makes the answer checkable is that a reader can tell WHICH published state was read, which an
identifier gives and a timestamp does not.*

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/check-board.sh` — KIT-CLASS: KIT. The checks are its lettered sections, **[a]** onward,
  in the order above — invariant 7 is its **[g]**. Check 6 carries one reading per publication
  home — in the shipped implementation **[f1]** the primary checkout's trunk ref and **[f2]** the
  board mover's auxiliary worktree — because invariant 6 requires the enumeration, not a fixed
  count of them.
- Its thresholds are named constants at the top of that file — **a seam, not a contract term.**
  They bound the depth at which the reviewed-and-done column is due for a sweep, and the sizes at
  which the running log is due for rotation — its current section and the whole file being
  separately bounded. **Read them from the file** rather than from any document, and **read how
  many there are from the file too**: this sheet once said *two* and the seam had grown a third.
  The **section**-size one is also the constant
  [`../doctrine/lookup-tables.md`](../doctrine/lookup-tables.md) § A.1 reuses for its index
  trigger, deliberately, so that one idea does not carry two numbers.
- Check 5 derives the legal role set from the enforcing rule rather than restating it; see
  [commit-attribution.md](commit-attribution.md).
