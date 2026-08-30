<!-- KIT-CLASS: KIT — transferable doctrine. § A is the pattern, in two parts with a seam; § B is the fill-in for YOUR instruments. The worked example is this kit's own harness, so nothing here needs anonymizing. -->
# Instrument doctrine — an instrument is believed only when it has been watched failing

**What this governs.** Anything whose job is to *notice*: a guard, a gate, a drift report, an
oracle, a probe, a monitor, an audit, a test that stands in for a class of behaviour. One rule
underneath all of it — **a green from an instrument nobody has watched fail is not information.**

**And it governs two different failures, which is why § A has two parts and a seam.**

| | **Part One — build time** | **Part Two — read time** |
|---|---|---|
| **What went wrong** | The instrument is **misaimed, or cannot fail.** It is green because it is looking slightly to the left of the defect. | The instrument is **right.** It answered a question correctly — just not the question its reader had. |
| **Who it binds** | **Whoever builds the instrument.** | **Whoever consumes the result.** |
| **What to change** | The instrument. | The reading. |

The distinction is not tidiness. **Applying Part One's remedy to a Part Two failure sends you to
re-aim an instrument that is already correct**, which is expensive and produces a worse instrument.
The two were separated after a family of measured cases turned out to divide cleanly on *who was
wrong*, with several of them insisting in their own words that the tool had not malfunctioned.

**Why its own sheet.** [`negative-claims.md`](negative-claims.md) governs **making** a claim, at
authoring time, and says of a registration with no falsifier that it "is not a weaker guard; it is a
suppression file with better manners." This sheet governs the moment before that: **whether the
check behind the claim can see anything at all.** Different moment, different reader — one is read
while writing a sentence, this one while building the thing that would catch the sentence being
wrong. Separate sheets, mutual pointer.

**One rule that looks like it belongs here and does not.** A **detection recipe offered inside a
ruling** — *"the cheap check for this is `grep …`"* — is an instrument, and it owes everything below.
But its characteristic failure is that the recipe's *presence* reads as coverage and stops anyone
looking harder, which makes it a **negative claim** about the rest of the tree. It is stated in
[`negative-claims.md`](negative-claims.md), and this sheet points at it rather than carrying it.

It is also the general form of two rules that arrived in
[`dogfooding.md`](dogfooding.md) (§ A.2, § A.16) and were promoted here because they bind every
guard author, not only whoever runs a round.

**Size note, owed by [`lookup-tables.md`](lookup-tables.md) § A.1.** This sheet is above that
section's byte trigger and still owes no index, by the read-time exemption stated there: a doctrine
sheet is addressed on demand, never loaded at session start. § A.1 asks whichever sheet is over the
trigger to carry that line in its own header, so neither end of the dependency can be edited blind —
re-derive the sizes with the command § A.1 names before narrowing either end.

---

## § A — PART ONE: BUILD TIME

> **Who this part binds: whoever BUILDS the instrument. What it changes: the instrument.**
> Every failure below is an instrument that is green while the defect stands just outside what it
> can see. **If you are writing or reviewing a guard, this part is your reading, and § A.9 onward is
> not** — it is for whoever later reads what your instrument prints.

### A.1 — Measure the instrument against the shape it will MEET, not the shape it was built from

An instrument watches for the signal **its author had in mind**. That is not a flaw in the author;
it is the definition of building one. The consequence is structural: if the thing being watched has
a paved path and an unpaved one, an instrument modelled on the paved path is precise for paved-path
subjects and **blind to everyone else** — and the unpaved cases are exactly the ones worth
catching, because they are where behaviour is unconstrained.

So, before an instrument is believed:

- **Take it to the messiest realistic input you can construct**, and check it still fires. Not a
  fixture written to satisfy it — a fixture written to defeat it.
- **Better, take it to real leftovers**: the output a real subject actually produced, from a
  previous run, incident or round. A fixture its author wrote is a fixture shaped by the same
  imagination that shaped the instrument.
- **A guard is believed only when watched behaving correctly on the exact shape it will meet.**
  Anything less is a claim about the fixture.

**The operand's REPRESENTATION is part of that shape.** A subject that reaches you as text has more
than one form — raw bytes, reflowed prose, a parse tree — and an instrument silently picks one. If it
picks the form the *authoring tool* produced rather than the form the *claim* lives in, every
reflow changes what it sees. § A.7 is that rule in full, for prose specifically; state it here
because it is a special case of measuring against the shape you will meet.

### A.2 — A negative check is not verification: every green owes an ablation

Verifying that the wrong thing is **absent** never establishes that the right thing is **present**.

- *"No forbidden vocabulary in the configuration"* is not *"the configuration works."*
- *"The content is missing from the read-back"* is not *"the write did not land."*
- *"The audit returned no violations"* is not *"the audit can see this violation."*

**Every audit owes both halves**: absence of the wrong thing **and** presence of the right thing,
with the presence half **exercised** — by a probe, or an **ablation**, that *fails when the
capability is missing*. The habit to build, asked of every green check: **"what would this look
like if the thing I need were simply not there?"** If the answer is "exactly the same", the check
is decoration.

This is the cheapest rule on this sheet and the most frequently broken. Expect to break it.

**The ablation shape, concretely.** Remove the logic under test from a copy, re-run the case against
input that *did* produce a finding, and assert the finding **disappears**. That makes a subsequent
pass attributable to the logic rather than to whatever the surrounding machinery happened to print.
Two details are load-bearing: **ablate a copy, never the live instrument**, and **check the ablated
copy still runs at all** — an ablation that breaks the harness proves nothing except that it broke.

**And the same rule pointed the other way: prove your PROBE can find.** An ablation asks whether the
instrument can go red. A probe — a planted defect, a synthetic bad case — asks whether your *attack*
can reach. **A plant that silently does nothing reads exactly like "the guard caught it."** Three
controls, each of which has been paid for:

- **Visibility** — prove the plant is where the instrument actually looks. A subject resolved
  through a package, an install, a cache or a symlink may not be the copy you edited.
- **Scanner reach** — prove the plant lives **inside the operand space**, not merely on disk beside
  it. A derivation that enumerates *tracked* files cannot see an untracked plant, and the file
  plainly existing is what makes this one easy to miss.
- **Harness realism** — prove the probe does not **invent**. A harness more destructive than any
  real edit manufactures findings; a reflow harness that also merges list items is testing a
  mutation nobody would ever make.

**Attack the attack before trusting its result.** A green from an unproven probe and a red from an
unproven probe are both uninformative, in the same run.

### A.3 — Sometimes a capability probe is the WRONG instrument, and that decision is recorded

A.2's probe can itself be the defect. If a case guards its own subject with *"does this check still
exist?"*, then **deleting or refactoring the check away turns the case from a FAIL into a SKIP** —
the guard reports "not applicable" at the precise moment its subject vanished, which is the failure
mode it existed to prevent.

So the rule is not *"always add a capability probe"*. It is: **choose, and record the choice in the
instrument itself.**

- Probe where the capability is a genuine **environment** fact — a tool that may not be installed,
  a credential that may be absent, a surface this project may not have. A missing environment is
  honestly a SKIP.
- **Do not probe** where the capability is the **subject** — the check, the guard, the behaviour
  under test. There, absence must be a FAIL. Write the reason next to the case, so the next reader
  does not "fix" the gap by adding the probe that breaks it.

### A.4 — Name the blind spot, the OPERAND SET and the SPAN in the instrument's OWN output

Every instrument has a blind spot. The only question is whether it is **named**, and named where it
will be read: **in the instrument's own output**, beside the verdict — not in a design document, not
in a commit message, not in someone's memory.

A reader who meets a silent or surprising green must find the explanation *there*, at the moment of
confusion. **A blind spot recorded is a limitation; a blind spot unrecorded is a defect that will be
found again, at full price, by whoever trusts the green next.**

The same applies to a deliberate narrowing: a check that scans the last N items, samples rather than
enumerates, or skips a class by design, **says so in the line that reports its result**. Silent
truncation reads as "covered everything."

**Two specific things belong in that line, because their absence is what lets a verdict be read
wider than it is.**

- **The operand set.** *"Board drift: clean"* should be printed, and read, as *"clean over ⟨these
  paths⟩."* A verdict that names its span cannot be mistaken for a wider one — and this is the
  build-time half of § A.10's read-time rule about two measures with disjoint operands.
- **The span, for a text guard, with its unscoped hit count.** A lexicon reported without its region
  is a measurement without units: **the ratio between what it matches over the whole corpus and what
  it matches inside its span IS the precision claim** (§ A.7).
- **The subject, on the CLEARING branch as well as the complaining one.** *Every instrument that
  names its operand when it complains must name it when it clears.* An instrument whose failure path
  prints *"⟨this tree⟩ is 2 commits ahead"* and whose success path prints *"nothing left unpushed"*
  has an asymmetry that errs **only ever toward false confidence** — the vague half is the one a
  reader stops at, and a clearance with no subject is read as covering whatever the reader had in
  mind. Measured: such a line reported all-clear beside a commit made in a different worktree that
  had not landed, and the report was true of the tree it read and false of the question being asked.
  The remedy is one token, and the test is cheap: **read the green line alone, out of context, and
  see whether it still says what it measured.**

### A.5 — Assert the FACT, never the sentence that states it

Three ways an assertion is true and still misses, and they share one cure.

- **Presence where a fact was meant.** *"The document must contain X"* is a guard against
  **deletion**, not against **staleness**. Where the required text contains a fact about the world —
  a version, a date, a count, a digest — presence is the wrong assertion: the one thing the sentence
  exists to convey is the one thing nothing checks. **A guard that cannot go red for the defect it is
  named after is folklore with a test id**, and it is worse than no guard because it buys confidence.
- **Per-member correctness, blind to quantifiers ACROSS members.** A guard can derive a set from the
  tree, assert per-member claims, and be right — while one member's prose says *"this is the only
  one that…"* about the whole set. **Set membership is checked; exclusivity claims a member makes
  about the set are not.** The falsehood is a universal quantifier, and no set comparison reads one.
- **Presence over an operand that CANNOT CHANGE.** In an append-only register that preserves
  superseded wording by design — a ledger, a decision register, an activity log — *"the sentence is
  present"* can only ever be true. The page keeps everything, so the guard stays green when the fact
  it polices changes. **A guard over such a register asserts a DERIVATION over its dated rows**,
  never the presence of a claim. And a phrase search must be **anchored to the row's own statement**,
  or it reads a quotation of the old wording instead of the current claim.

**The cure, one sentence: derive the current fact from the rows or from the tree, and assert that.**
The prose-side sibling of this rule — a count or universal in a maintained document must be derived,
dated, or not stated — is [`staleness.md`](staleness.md) § C, which owns it for prose.

### A.6 — The operand SET is where this defect lives, at four scales

The assertion is right. The instrument runs. It is looking in the wrong place — and the place can be
wrong at four different sizes, which is why fixing one instance rarely fixes the class.

- **The SPAN inside a file.** A checker whose region is delimited by a convention **shrinks silently
  when the convention is violated** — it does not redden, it narrows its field of view until there is
  nothing left to fail on. So **where an instrument's scope is delimited by a convention, the
  instrument must also assert the convention.** One check, and it fails for the right reason.
- **One MEMBER versus the FAMILY.** A guard written over the one file that motivated it is correct
  and does not travel: the next sibling file created inherits nothing. **Derive the file set** — by
  the project's own naming convention, from the filesystem — so a new member is covered on the day it
  is created rather than when someone remembers to re-write the guard.
- **The SPACE the set is derived from.** Deriving your operand set does not help if you hand-bound
  the space you derived it from — the method can be right every time while the scope is wrong every
  time. **Derive the SET from the declared authority, derive the SPACE from reality, reconcile, and
  PRINT THE DIFFERENCE IN BOTH DIRECTIONS.** Either half alone is insufficient: a tree-derived census
  over-collects (it counts things that are not members), and a declaration-derived census misses what
  the tree has grown. **The difference is the only place this bug lives**, and it lives in both
  directions — something added to the tree and never declared, and something declared and absent from
  the tree. *This is the specification, not the trigger:
  [`lookup-tables.md`](lookup-tables.md) § A.5 ranks the alternatives and says when a single guarded
  direction is survivable — with a reason in-file that **names the direction left unguarded.** The
  two sheets are not in tension: that one decides whether you owe the reconciliation, this one
  decides what it must print once you build it.*
- **The BASIS — and a space can be wrong without being SMALL.** The widest possible membership does
  not save an instrument that compared the wrong *projection* of its subject. **Derive the basis from
  the ACT you are guarding, not from the value that was convenient to compute:** which projection
  does the operation actually operate on? No membership reconciliation can see a basis error; only
  the action's own contract can.

### A.7 — Building a prose guard: representation, then region, then honesty about the remainder

Prose is the operand where instruments are weakest, because natural language has no authoritative
parse and every guard over it is a lexicon pretending otherwise. The rules below, in the order they
bite.

1. **Match the NORMALISED text or an AST — never the raw lines.** Line breaks are an artifact of the
   authoring tool, not a property of the claim. A guard matching raw text is a guard over **where the
   prose happened to wrap**, so the same sentence is caught or missed depending on reflow. Watch for
   the specific tell: a function that *normalises the text for its error message* and *matches against
   the raw text* — both representations present, and the assertion using the wrong one.
2. **Precision comes from the REGION, not from the word list.** The same lexicon can fire many times
   across a whole document — every hit legitimate — and zero times inside the one region where the
   claim lives. **Scope a prose guard to the smallest span that contains the claim, and state the span
   in its own text**, with the unscoped hit count beside it (§ A.4).
3. **A computable SUBJECT does not make a SENTENCE gradable.** Even where the underlying fact is
   derivable from the tree, grading the English that describes it requires a parse of the sentence,
   and no such parse exists anywhere in your repository. **A guard can hold the arithmetic or the
   vocabulary; connecting them is natural-language semantics.** Ask the two questions separately.
4. **Where a guard is irreducibly an enumeration, it states its own subset and asserts that the
   disclaimed spellings still slip.** A guard implying a completeness it does not have **is** the
   defect; a guard that names its own subset is a tool. Add a canary that reddens if the pattern set
   stops matching the cases it was built for, so a lexicon matching nothing fails loudly.
5. **A spelling that costs false positives is MEASURED and DECLARED, not enrolled.** Enrolling a
   token that buys one paraphrase and pays several false alarms is how a guard earns the reputation
   that gets it deleted. Measure the cost, write it down, and leave the token out. Exclude negations
   explicitly: a negated claim attributes nothing, and un-excluded it costs false positives on
   sentences that are true.

### A.8 — A green that could not have gone red

The failures above are instruments looking at the wrong thing. These are instruments that **could not
have said no** — where the greenness is a fact about the check's own machinery rather than about its
subject.

**Verification theatre — two shapes, and both survive review because nothing in the output is
false.**

- **The unconditional report.** A command whose result is discarded, followed by a message asserting
  it passed. **It will assert success after a failure, forever.** The tell is a status that is never
  read: a pipeline whose exit code is swallowed, a call whose return value is not branched on.
- **The restated premise.** A calculation fed the number it was supposed to derive. It confirms the
  input — and if the input is wrong, **it confirms the error with full confidence.**

The defence is mechanical rather than attentive: **make every check able to fail, and then confirm
that it can.** Respect the status; derive the input from the artefact instead of typing it; and
periodically feed a deliberately broken case through and watch the check reject it.

**A test that cannot RUN cannot redden either.** A test gated on an irreversible or expensive act
gets written, marked, gated — and then never fires, because firing it costs the thing the gate exists
to ration. It is collected, it is skipped, **and a skip is not a failure**, so every suite run reports
green with it inside. Nothing in the output distinguishes *"this passed"* from *"this has never been
attempted."*

- **A test gated on an irreversible act declares, in its own text, WHAT WOULD HAVE TO BE TRUE FOR IT
  TO RUN** — which consent, which precondition, whose budget. A reader then sees the gate instead of
  inferring coverage from a green line.
- **Count the never-run.** A suite that fences dangerous tests should be able to answer *"which
  marked tests have never executed in any run?"* from committed evidence. A test skipped in every run
  since it was written is **unverified**, and the record says so wherever it is cited as coverage.
- **When such a test is resurrected, re-attack its assertions BEFORE celebrating.** Making a dead
  test run is precisely the moment an assertion quietly becomes a tautology.

**An exemption tested in one direction is an unmeasured hole.** Any guard strict enough to be worth
having needs a documented way out for the site that legitimately cannot comply. That hatch is then
tested only in the passing direction — *a marked site passes* — which proves it is usable and proves
nothing about whether it is a hatch or a hole. **A marker that accepts any content is a suppression
comment with extra ceremony.** So: **every exemption ships with two tests, and neither is optional** —
one that a properly-justified exemption is **honoured**, and one that a **degenerate** exemption is
**refused** (empty, whitespace, a stub, a restatement of the rule's own name). State the refusal
threshold where the marker is documented, so a caller learns the cost before paying it.

**And when the change's subject IS the instrument, the evidence inverts.** Belt tooling — the gate
runner, the lander, the drift report — is the machinery every other change is judged by. A green gate
normally means *the tree is good*; on a change to the gate it means *the modified gate said green*,
which is equally compatible with the gate having lost the ability to say no. **Neither result is
false. Both have stopped measuring what the reader thinks they measure.** Three things are owed, and
a brief that commissions such a change states the hazard up front:

- **A reddening control per tool** — a tool that cannot fail is not a gate. Show both states exist and
  are **distinct**, so the change is proven to be a new state rather than a rename.
- **A NAMED non-self-referential witness, reported before and after.** When the instrument cannot
  vouch for itself, something outside it must — and it must be named in the brief, or the worker will
  reach for the tool it just edited.
- **An explicit parkable escape.** If the worker judges its own landing unsafe with modified
  machinery, stopping with a clear report is the correct outcome, and saying so in advance is what
  stops it pressing on to avoid looking stuck.

**Finally: the validator must match the thing being validated.** A checker that **rejects a valid
input for a reason unrelated to correctness is worse than no checker, because it trains you to ignore
it** — and a warning that fires on every ordinary run is the same disease at a lower dose. By the
time the one real occurrence arrives, the signal has been tuned out. Where a check is noisy by
construction, either narrow it to the case that matters or demote it to an informational line and let
a hard gate carry the real refusal.

---

> ## ═══ THE SEAM ═══
>
> **Everything above is BUILD TIME: the instrument is misaimed, or cannot fail. It binds whoever
> BUILDS the instrument, and the fix is to change the instrument.**
>
> **If you came here to write or review a guard, you are done. Stop at this line, and you were right
> to.**
>
> **Everything below is READ TIME. The instrument is CORRECT.** It answered its question accurately;
> the failure is in what its reader concluded. It binds **whoever consumes the result** — a reviewer
> reading a verdict, a coordinator reading a leg's report, anyone about to act on a green. **The fix
> is to change the reading, and applying Part One's remedy here means re-aiming an instrument that is
> already right.**

---

## § A — PART TWO: READ TIME

> **Who this part binds: whoever CONSUMES the result. What it changes: the reading.**
> Nothing below is a defect in an instrument. Every case is a true answer, correctly produced, read
> as an answer to a different question.

### A.9 — Which question did it actually answer?

**A broken tool announces itself; a correctly-answering tool does not.** That is what makes this the
more expensive half: the output is authoritative, internally consistent, and about something slightly
other than what you asked.

- **Read the STATUS, never the output shape.** An empty result from a *failed* call is
  indistinguishable from an empty result from a *successful* one. A count of zero, an empty list, a
  missing line — each is produced identically by "there is nothing" and by "the command did not run."
  **Read the exit code**, and never grep for a summary line that a flag may have suppressed.
- **Find where the tool decided HOW MUCH TO SHOW YOU, before treating its output as a count.** A
  preview cap, a `first N` banner, a truncated table, an ellipsis, a paginator — each is a courtesy,
  and each is silently a cap. This is the purest member of the family, because **nothing in the output
  is false**: the lines shown really are those lines. It is right, and wrong about what it counts.
  **Derive a total from the operand, never from the presentation.**
- **A tool reports on its SUBJECT and on ITSELF in the same vocabulary unless it is made not to.**
  *"Could not run"* and *"your tree is broken"* are different facts; an instrument that spells both
  `FAIL` has merged them, and the reader cannot separate them afterwards.
- **An instrument can measure a fact and report an ATTRIBUTION** — and the attribution may be
  invented. *"X changed"* is a measurement; *"the harness changed X"* is a claim about **cause**,
  which a before/after comparison cannot establish over a resource the instrument does not own
  exclusively. **A wrong attribution is worse than a bare fact, because it sends the reader to debug
  the one thing the evidence does not implicate.**

**The habit: state, beside every instrument, WHICH QUESTION IT ACTUALLY ANSWERS** — and prefer the
instrument whose question is the one you have. Where two routes to an answer exist, run both and
print the difference; where a number steers a decision, derive it twice by different routes.

### A.10 — Reading two results together: direction, and disjoint operands

Two instruments are harder to read than one, in two specific ways.

**When two derivations disagree, the FINDING is the DIRECTION of the disagreement, not the fact of
it.** Having a second party derive a measurement independently is right and incomplete: it tells you
*whether* they agree, and teams then treat any mismatch as a symmetric alarm to reconcile. **But the
two directions usually carry opposite risk, and which one is dangerous is a property of the check,
not of the numbers.** State it before comparing, and say so in the report, so a later reader can tell
a reconciled alarm from a dismissed one:

- **Coverage or population scans** (what must be fixed): the **reviewer finding MORE** is the finding.
  The doer's set must be a superset of the reviewer's; a doer finding more merely migrated extra.
- **Residual or exemption counts** (what is left unfixed): the **doer finding FEWER** is the finding —
  under-reporting residue is how a snapshot passes as a closure.
- **Budgets and ceilings**: the **doer counting FEWER** is the finding — an undercount is how a
  ceiling is exceeded without anyone refusing.
- **Where both directions are fatal, say that too.** It is a legitimate answer and it doubles the
  verification owed.

**And two green measures with DISJOINT OPERAND SETS are not evidence about each other.** A project
accumulates more than one measure of "finished", and they feel interchangeable because both end in a
green line. Each is complete only over **its own operands**, and those sets can be nearly disjoint —
one answers *"is every work item resolved?"*, another *"is every shipped document true?"*. **A team
that has just driven the first to zero experiences it as done-ness, and that feeling is the defect:
the narrower instrument's silence about a document it never opens is not a statement that the
document is fine.**

Neither instrument is wrong. **The narrower one going green is simply not evidence about the wider
one**, and a direction check cannot catch it because the two never disagreed — they answered different
questions. So: **name the operand set beside every completeness verdict** (§ A.4), and where a
decision needs the wider claim, **enumerate what the narrower instrument does not cover** rather than
remembering it. A release audit is not a stricter board; it is a **different** board.

**A property that makes an instrument trustworthy can also make it blind, and the cure is to say so,
not to undo it.** An instrument taught to read a named reference rather than whatever is in front of
it becomes correct about the shared state — and thereby **incapable of noticing that your local copy
is stale.** That is a good trade and a real blind spot, and § A.4 is where it gets recorded.

---

## § B — Your project's instance — **fill this in**

> **PROJECT INSTANCE from here down.** Nothing here is inherited. On day one this section is
> correctly empty.

1. **Your instruments**, one row each: what it watches, **which question it actually answers**
   (§ A.9), and its **named blind spot** — plus where in its own output that blind spot appears
   (§ A.4). `<fill-in>`
2. **Which of them have been ablated** (§ A.2), and where the ablation lives. An instrument with no
   ablation is listed here as **unproven, not passing**. `<fill-in>`
3. **Your probe-or-fail rulings** (§ A.3): each case that deliberately carries **no** capability
   probe, and the one-line reason. `<fill-in>`
4. **The real leftovers you keep as test material** (§ A.1) — where they are, and which instrument
   each set was used to defeat. `<fill-in>`
5. **The operand SET and the SPACE each instrument reconciles** (§ A.6), and where it prints the
   difference. `<fill-in>`
6. **Each prose guard's span and its unscoped hit count** (§ A.7), plus the spellings it has measured
   as too costly to enrol. `<fill-in>`
7. **Each exemption mechanism, its two tests, and its refusal threshold** (§ A.8). An exemption with
   only the passing test is listed here as **unmeasured**. `<fill-in>`
8. **Your never-run list** (§ A.8): every gated test that has not executed in any recorded run.
   `<fill-in>`
9. **For each pair of completeness measures, which direction of disagreement is the finding**
   (§ A.10) — and which operands each one does **not** cover. `<fill-in>`

---

## § C — Worked example: this kit's own self-test harness

> Not anonymized, because it is ours. Read `scripts/test/run.sh` alongside this.
>
> **These examples are the harness's DESIGN, not its bugs.** An earlier version of this section cited
> three defects the kit had at the time; all three were subsequently fixed, which made the section
> false within one phase of being written. What is cited now is structure that exists **because** the
> rule is followed, plus one live instance kept deliberately.

**The ablation (§ A.2), done properly.** The harness's board-checker cases do not merely assert that
a drift finding appears. A control leg **strips the check under test out of the sandbox's copy** of
the drift report, re-runs a board that *did* produce a finding, and asserts the finding is **gone** —
so a passing leg is attributable to the check's logic rather than to any output the script happened
to emit. Two guards on the ablation itself are the part worth copying: it **refuses to proceed if the
ablated copy no longer parses**, and **if the ablation removed nothing**. An ablation that silently
removed nothing is § A.2's own defect one level up.

**The probe that was deliberately NOT written (§ A.3).** Two of those same cases carry an explicit
note that a capability probe was **left out on purpose** — one about the gate runner carrying any
particular gate, the other about the drift report still containing the check. *Two different
subjects, one reasoning*, and the reasoning is the transferable half: such a probe *"would turn the
check being deleted or refactored away into a SKIP instead of a FAIL"* — the exact regression those
cases exist to catch. The decision and its reason are recorded **in the harness**, next to the cases
they govern. That comment is where this sheet's § A.3 came from.

**A neutralizing fixture, which is § A.1 learned the hard way.** The harness copies the real
repository's scripts into a sandbox — and therefore, at first, copied the *adopter's own
configuration* along with them, so a run inside a configured project asserted that project's setup
instead of the kit's frame. Initializer cases failed rather than skipped, because the fixture handed
them an already-stamped configuration. The fix is now structural: a neutralizing step takes the
adopter's config back out before any case runs, and **refuses loudly if a stamp survives it** rather
than proceeding with a fixture that would grade the wrong thing. It was found by running the harness
somewhere its author had not, which is § A.1's whole instruction.

**A vacuous green, and the shape of its repair (§ A.2, § A.4).** The drift report once printed *"every
scanned subject carries a role prefix"* on a repository with **no history at all** — a green whose
honest reading is *nothing was scanned*. The repair is the one this sheet prescribes and the one to
copy: the arm now reports **skipped, with the reason**, and the code keeps the old behaviour's
description beside it so nobody re-introduces the fall-through.

**And one live instance, kept because it is the clearest § A.9 case we have.** The harness's isolation
case verifies that the real repository's board surfaces are untouched by a run. During a multi-session
run it reported: *"the harness added a mutation to a board surface during the run."* **The detection
was exactly correct** — a board surface had changed between the run's start and its end. **The harness
had not done it**; a concurrent session was editing that file while the run was in flight. The case
measured a **fact** (the tree changed) and reported an **attribution** (the harness changed it), which
a before/after comparison cannot establish over a tree it does not own exclusively. The first reading
it produced was that the phase's landing had broken the witness — materially more alarming, and wrong.
**Nothing in the instrument was broken; the sentence it printed was the defect.**
