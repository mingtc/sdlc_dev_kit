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
> can see. **If you are writing or reviewing a guard, this part is your reading. § A.9 and § A.10 are
> not** — those two are for whoever later reads what your instrument prints.

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

**AND A CONTROL TAKEN ONCE, AT AUTHORING TIME, MEASURES THE SHAPE THE INSTRUMENT WAS BUILT FROM —
not the shape it later meets.** Everything above is satisfied by a control run at the bench and
written down. That is necessary and it is not enough, because the shape moves and the record does
not. So:

> **A reporting instrument's control must execute on every run and appear in its own output — a
> control recorded once at authoring time is indistinguishable, to every later reader, from one that
> no longer holds.**

*Why this is stated separately from § A.2, which already demands an ablation.* § A.2 and the arming
invariant it feeds ([`../contracts/self-test-harness.md`](../contracts/self-test-harness.md) § 2)
bind a **guard** — something that can go red — and put its ablation in an artifact *beside* it. A
**reporter** always exits 0; its output is prose a person reads. There is no red to ablate, so the
only place a control can be read is the line the reader is already looking at. **The shape: every
run also asks a question whose answer cannot legitimately be empty, and prints that answer beside
the verdict; if the control comes back empty, the verdict is reported as `n/a-control-failed`, never
as a zero.** A reader who was not present at arming can then tell a true zero from a broken
predicate. § A.4 governs what else that same output line owes — the blind spot, the operand set and
the span — and the control field is an obligation of the same kind, for the same reason: it is only
worth anything where the reader already is.

*Measured, and the measurement is what makes this a separate rule rather than a restatement.* In one
run's instruments, a group of defects all had the same shape — a plausible value where an error
belonged — and **several were in instruments whose positive and negative controls were on the record
before arming, for the very predicate that failed**. Recording was done; it did not carry: those
controls had been taken against a *simulated* subject, and the instruments failed at first contact
with a real one — this section's own rule, re-proved against instruments that had satisfied it once.
**A second group failed for a different reason, and it is what fixes the UNIT this rule binds.**
Those defects were in predicates added *after* their instrument's arming row was signed — a new
feature of a file that had already passed. An arming record kept per FILE cannot see them, and will
credit a later-written predicate with a control taken for a different one. **So the unit is the
predicate, not the file**, and re-arming is owed whenever an instrument meets a new subject, new
paths, or gains a new feature. The one instrument in that run carrying an every-run control field
was the one that reported a true zero as visibly distinct from a broken one.

**This is doctrine, and deliberately not a gate.** The reason is
[`../contracts/self-test-harness.md`](../contracts/self-test-harness.md) § 6's, preserved here rather
than re-argued: a gate whose cost is a wall gets disabled, and **a disabled gate reads as armed** —
the exact failure this sheet exists to prevent, committed by the enforcement. What is NOT established
is that the every-run form would have caught all of them: the one instrument that carried it caught
one of its own two defects, so the demonstrated claim is the narrow one — *recording is not
sufficient* — and sufficiency of the every-run form is unmeasured.

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

**And WHERE the ablation lives is a separate demand from whether it was performed.**
[`../contracts/self-test-harness.md`](../contracts/self-test-harness.md) § 2 carries the invariant
this section feeds — **a guard is not armed until its ablation is an ARTIFACT**, a file another
reader can run, not a habit and not a comment — because an ablation's whole value is that it is
re-runnable against a tree that has moved. That sheet also states the disposition: it is doctrine,
not a gate, and § 6 there carries the measurement behind that ruling. The reporter's form of the
same problem is § A.1's closing rule.

**The ablation shape, concretely.** Remove the logic under test from a copy, re-run the case against
input that *did* produce a finding, and assert the finding **disappears**. That makes a subsequent
pass attributable to the logic rather than to whatever the surrounding machinery happened to print.
Two details are load-bearing: **ablate a copy, never the live instrument**, and **check the ablated
copy still runs at all** — an ablation that breaks the harness proves nothing except that it broke.

**And the same rule pointed the other way: prove your PROBE can find.** An ablation asks whether the
instrument can go red. A probe — a planted defect, a synthetic bad case — asks whether your *attack*
can reach. **A plant that silently does nothing reads exactly like "the guard caught it."** The controls below
have each been paid for; the list is the bullets, not a number in this sentence.

- **Visibility** — prove the plant is where the instrument actually looks. A subject resolved
  through a package, an install, a cache or a symlink may not be the copy you edited.
- **Scanner reach** — prove the plant lives **inside the operand space**, not merely on disk beside
  it. A derivation that enumerates *tracked* files cannot see an untracked plant, and the file
  plainly existing is what makes this one easy to miss.
- **Harness realism** — prove the probe does not **invent**. A harness more destructive than any
  real edit manufactures findings; a reflow harness that also merges list items is testing a
  mutation nobody would ever make.
- **Application — prove the plant TOOK, and that the subject is the subject.** The three controls
  above ask whether the plant is in the right *place*; this asks whether it exists at all. Measured,
  as a chain in which every link was individually correct and every link was silent: a substitution
  whose pattern matched nothing, so nothing changed and nothing was said; a commit that therefore
  had nothing to commit, and said nothing; a one-commit rewind meant to undo that commit, which
  instead **rewound past the change under test**, and said nothing. The run then refused for a
  plausible-looking reason. **Every line of that output was true and the whole run was meaningless —
  an instrument exercised against a tree with the subject absent from it.** So: assert the mutation
  is present after making it, and assert the artifact under test is the one you meant, by comparing
  an identifier before and after rather than by trusting that a command that printed nothing did
  something. A plant you have not asserted took is not an ablation; it is a hope.
- **Adversarial choice — break the member LEAST likely to be covered.** A probe aimed at the
  convenient member measures the path the author already had in mind. Choose the operand you would
  least expect the instrument to reach: the one added most recently, the one in the unusual
  directory, the one whose name does not match the others, the one a glob would have to be widened
  to include. **A guard passes its easiest case by construction — the author wrote it against
  that case.**

**Attack the attack before trusting its result.** A green from an unproven probe and a red from an
unproven probe are both uninformative, in the same run.

**And the reader's half, which no control above supplies: do not accept a red you cannot explain.**
The chain described under *Application* was not caught by any check — it was caught because the
refusal named a defect that had already been fixed, and that did not fit. **A result that does not
fit is evidence about the instrument, not noise to be worked around.** The cost of chasing it is one
reading; the cost of accepting it is a finding written against the wrong subject, which is expensive
to withdraw and worse to leave standing.

**AND THE SAME RULE POINTED AT A QUERY, WHICH IS WHERE THIS SECTION HAS BEEN STOPPING ONE STEP
SHORT.** The third bullet above already says it for an audit — *"the audit returned no violations"*
is not *"the audit can see this violation."* **A `grep` that finds nothing, an `ls` that lists
nothing, a selector returning an empty set are each making the same claim and owe the same proof.**

> **A null result is not a measurement until the query has been shown able to return a non-null one.**

**An empty answer has two causes and they are indistinguishable from the answer alone:** the subject
has no members, or **the query cannot return any**. The remedy is this section's own, applied to the
instrument instead of the subject — **a positive control on the null**: before believing an empty
answer, run the same query against something that **must** match. *That is asserting a plant took
before believing its effect, which this sheet already requires; nobody had pointed it at the
selector.*

**Measured, in one session, four times** — a pattern unsatisfiable under one of two reachable `grep`
implementations, read as *the guard is absent*; a glob that did not descend into a subdirectory, read
as *the library would be stamped*; a process query returning nothing, announced as *the run died*
while the run was alive; and an intersection over text that could not see a **transitive** call, read
as *the change is safe*. **Each took the first reading. Each was wrong.**

**The empty answer is the one that never prompts a second look — and so is a plausible one.** Nothing
about a result's shape tells you to check it: an empty set looks like a finished search, and a
populated set large enough to feel like a survey looks like finished work. **The trigger cannot be
how the answer looks.** It is that you are about to *believe* it.

**AND THE RULE EARNS ITS KEEP WHEN NOTHING IS WRONG, which is the case worth showing.** One dangling
link was found in a corpus. Was that a class or an instance? The query was re-run as its own positive
control — **one dangling against a hundred and eighty links it could see, and none in the opposite
direction** — and the answer was *one instance, no guard needed.* **Without the control, "one" is
indistinguishable from "one that my query happened to find", and the cheap correct decision cannot be
made confidently.** A control is not only how a null is disbelieved; it is how a small number is
trusted.

**Why no check ships for this**, said plainly because this sheet asks for mechanisms first: the
population is **every query anybody writes**, including in a message, a card and a shell
history — most of it never in the tree at all. And any marking of *which* nulls were trusted would be
written by the same person who trusted them, which § A.12 rules out on its own. **Two independent
reasons, and the honest consequence is that this one is a discipline.** Where a null IS in a tracked
artefact — a test's `|| true`, a guard's empty expected-set — that population is bounded and a check
over it is worth building.

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

**Three specific things belong in that line, because their absence is what lets a verdict be read
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

**And the notch that all three of those stop one step short of: a DECLARED operand set can be true
while the coverage is false.**

Naming the span makes a verdict honest about what it *claims*. It does nothing about whether the
claim is right. An instrument that prints *"clean over every shipped script"* has satisfied
everything above and may still have walked a set that is not the shipped scripts — because the set
came from a glob, a directory listing, a pattern, or a list somebody typed, and each of those is a
**proxy for the population, not the population**.

Measured, repeatedly, and always with the label reading true: a floor check reporting *"none of the
25 shipped scripts"* on one tree and *"none of the 26"* on another, having counted a file the
adopter had been instructed to add and labelled it *shipped*. A guard whose population was every
file **containing** a flag's characters, so a configuration seam that merely mentioned the flag in a
stamped comment was asked for a command-line interface it does not have. A coverage report that said
*every* and meant most.

**So the rule has two halves and the second is the one that bites:**

- **Derive the operand set from the subject**, not from a proxy for it. The subject is whatever the
  claim is about — if the verdict says *shipped*, something must state what ships, and the
  instrument must read that.
- **Derive it a second time, by an independent and deliberately LOOSER reading, and compare.** One
  derivation cannot detect its own omissions; that is the same reason a prose enumeration cannot.
  The two readings disagreeing is the finding. **Where they agree, the agreement is the evidence —
  and where no second reading is possible, say so in the output, because an underived span and a
  span derived once are not the same claim.**
- **INDEPENDENT MEANS IN A DIFFERENT LANGUAGE, not merely by a different hand.** Two derivations
  written in one idiom **inherit that idiom's assumptions**, so their agreement is evidence about the
  operand and **no evidence at all about the idiom.** The place this bites hardest is the one where
  operand sets are usually written: **a pattern language cannot be used to test its own semantics.**
  *Measured: a set of path globs was declared with `*` meaning "does not cross `/`". One
  implementation read them that way and a second, in a shell `case`, read `*` as crossing — a
  difference of eleven files in one row, and in the direction that certified the surface whose
  checker actually reads the missed files. Both implementations were competent, both were tested,
  and each was internally consistent. **The disagreement was only visible across the two
  languages**; a third reading in either one would have agreed with its sibling and been wrong. So
  where the operand is expressed as globs, patterns, or any matcher, **one of the two readings must
  come from outside that matcher** — a literal enumeration, a hand-checked list, a different
  runtime — and where that is impossible, say so, because two readings in one idiom are closer to
  one reading than to two.*

**AND THE NOTCH THOSE TWO STOP ONE STEP SHORT OF: ask who WROTE the operand.**

A set can be derived from the subject, derived twice, and still be worthless — because deriving
correctly from a **field the constrained party fills in** measures that party's willingness to fill
it in, and nothing else. The population is right; the *reading* is theirs.

> **A signal is worth reading only where the party it constrains did not author it.**

**This is the anti-gaming clause of § A.12 reached from the other direction.** There the rule is that a
check you can satisfy by editing the answer is not one; here it is that a check whose operand is
authored by its subject *is already* such a check, whether or not anyone edits anything. **No bad
faith is required and none should be assumed** — a person recording their own reason records the
reason they believe, and the instrument then reports the belief while appearing to report the fact.

**The test is one question: if this signal started reporting badly, who would have to change what
they write to make it stop?** If the answer is *the person the signal is about*, it is not a
measurement — it is a self-assessment with a number on it.

**Two shapes, so the line is usable rather than admirable:**

- **Readable.** A count of how often a work item came *back* from review. The transition is performed
  by the reviewer, recorded by the tool that moves it, and the item's owner controls none of it. The
  signal survives everyone involved wanting a different answer.
- **NOT readable.** A count derived from a card's own *origin* or *rationale* field, used to judge
  whether such cards should be minted. The field is written by the same person doing the minting, at
  the moment of minting, and a check over it makes the field a form to be filled correctly rather
  than a record of what happened.

**What to do when only the unreadable signal exists** — which is common, and is the case that decides
whether this rule is honest or merely a reason to build nothing: **say so, and do not build the
check.** A gate over a self-authored operand does more harm than the gap it closes, because it
converts an honest record into a defensive one — and the record was the thing of value.
**Name the judgement, name whose it is, and route it to them.** An unbuildable check is a finding
about where authority sits, not a hole in the tooling.

*Deriving from the wrong subject satisfies the first half and fails the second.* A check that read
its pattern out of the very script it was auditing would have been "derived" and would have
certified whatever that script said — including the narrowing that made eight of the operands
invisible. The second reading is what makes the first one falsifiable rather than circular.

**The accounting must balance, and the remainder must be named.** Every member of the population is
exactly one of: measured, excluded for a stated reason, or **not reached**. A member that leaves the
walk without being counted is the defect above with nothing to show it, so the instrument asserts
the three sum to the population and prints the third by name. **A hole and an exemption are
different claims** — an exemption says something need not be checked, a hole says something *is
not* — and only the second keeps arguing after its author has moved on.

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

  **Over source, the commonest wrong projection is THE FILE instead of THE CODE.** The comment
  explaining why a token matters is the place that token is most certain to appear — so an assertion
  that greps the whole file is satisfied by the documentation of the thing it exists to measure, and
  the effect grows with how well the code is commented. Three remedies, one shape: **strip** the
  comments from the operand, **anchor** the pattern where the construct must appear, or **remove**
  the token from the text that is not the subject. Which one depends on the direction of the error —
  a false pass wants stripping, a false finding usually wants anchoring — and the sign is not
  predictable from the rule alone, which is why all three are named. Comment syntax is per-language,
  so a single shared stripper is a worse answer than naming the obligation. Strip toward
  over-stripping: an over-strip reddens loudly, an under-strip passes silently. Proving any of the
  three is § A.2's ablation, not a second rule.

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

**A guard shadowed by a newer one cannot redden either.** A change adds a check that correctly
refuses some of the inputs an existing check already refuses, for a different reason. The suite
grows, every gate stays green, and review finds nothing wrong. But the existing check's tests assert
only *that* their inputs are refused, never *which check* refused them. With the new check in place
they pass without the old check, so **the old check can be deleted and its own tests stay green**.
Each check can still say no; its tests cannot tell it from its neighbour. The suite got greener as
its coverage shrank. The defence is § A.2's ablation, done when the overlap is made: **break the old
check, with the new one in place, and watch the old check's own test redden.** Feeding in a broken
input is not enough, because the new check refuses that too. Disabling the new check tests nothing. If the old check's own test stays green, give
it a test only it catches, or retire it on purpose. **An ablation done once goes stale** the moment a
neighbouring check lands, which is why the question belongs to the change that adds the neighbour.
A mutation harness shows the same thing only if a newly surviving mutant is read as coverage lost,
not as a stale entry to suppress. Nothing here requires one.

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

**Which of those two a check gets is a ruling, and it is made elsewhere.**
[`../contracts/self-test-harness.md`](../contracts/self-test-harness.md) § 6 states the general form:
**a check that is mechanically decidable may be a gate; a check that is heuristic must be advisory,
and must publish its own precision.** Shipping a heuristic as a gate is a claim wider than the
predicate — the same error as an over-promising test name, committed by the guard instead of the
test — and the sheet carries the measured case that settled it. Read that ruling before deciding
whether a check built under this section refuses or reports.

### A.11 — Guarding EVERY number a document publishes, not one number

**Everything above is about ONE instrument. This is the population version, and it is a different
problem:** a document that publishes figures — a manifest, a charter, a report anyone quotes — has a
*set* of numbers, and guarding some of them is indistinguishable, to a reader, from guarding all of
them. The rule is one sentence:

> **The figures a document publishes are a POPULATION with a CLOSED exempt set, and both halves are
> written down.** Not "we check the important ones."

**Why the closed set is the load-bearing half.** An open exempt set is not a set — it is a habit, and
it absorbs exactly the figures nobody wanted to guard. A reader who finds *some* figures guarded
reasonably infers the rest were considered; if they were not, the document has told them something
false without stating a single false sentence.

*Not a third tier.* [`../contracts/acceptance-tier.md`](../contracts/acceptance-tier.md) § 2 rules
**two tiers and only two** for tests, and this does not touch it. The exempt set here classifies
**figures inside one document**, not tests, and nothing selects on membership — an exempt figure is
guarded by nobody and says so, which is the opposite of a bucket that decides what runs.

**THE PROCEDURE — a checklist, and read as one.** These are steps in an order, not five separate
obligations to be cited individually:

1. **Enumerate the figures.** Every number the document asserts, derived mechanically from the
   document rather than by reading it. The enumeration is the operand set, and § A.6 applies to it in
   full.
2. **Evaluate each against a measured run**, not against the document's own reasoning. A figure that
   agrees with the prose and disagrees with the tree is the case this exists to catch.
3. **Guard the ENUMERATION three ways** — that it still finds figures (a census that matches nothing
   reports full coverage), that each guarded figure has a test, and that the guard set has not
   shrunk. The third is the **completeness ratchet**: a figure that leaves the guarded set leaves a
   visible hole rather than silently rejoining the exempt one.
4. **Pin the exempt set CLOSED**, with a reason per member. *"Not guarded"* is not a reason;
   *"derived at read time from a source this document does not own"* is.
5. **Check per-axis mutation specificity.** A mutation to one figure must redden **exactly one**
   test. If it reddens two, the axes are not separated and the second test is measuring something it
   does not name; if it reddens none, § A.8 applies.

**And the reviewer's half, which is the part that does not fit in a checklist because it cannot be
performed by the guard's author:**

> **Re-census with a STRICTLY WIDER operand vocabulary than the guard's own.** A guard's vocabulary
> is the one thing it cannot use to audit itself: it will re-derive the same set and report agreement.
> Widen the scope, widen the pattern, widen the file set — then compare counts.

*Measured, twice in one month in this kit:* a sweep scoped to `scripts/` could not see `.claude/`, and
a regex that could not cross a nested brace missed a fifth divergence. **Both guards were correct
about everything they could see, and that was the defect.**

---

> ## ═══ THE SEAM ═══
>
> **Everything above is BUILD TIME: the instrument is misaimed, or cannot fail. It binds whoever
> BUILDS the instrument, and the fix is to change the instrument.**
>
> **If you came here to write or review a guard, you are done at this line — WITH TWO EXCEPTIONS:
> read § A.12 and § A.13 as well.** Both sit below the seam and are BUILD-TIME rules like everything
> above it. § A.12: a check whose comparison value the same person maintains can be made green by
> editing the answer, which is a defect in the instrument, not in someone's reading of it. § A.13: a
> declaration with no reader is fine and a declaration that does not SAY it has no reader is not —
> which binds the guard author because it is the sentence they write beside the guard, or fail to.
> *Sections keep their numbers wherever they sit, because shipped release notes cite them.*
>
> **Everything below is READ TIME. The instrument is CORRECT.** It answered its question accurately;
> the failure is in what its reader concluded. It binds **whoever consumes the result** — a reviewer
> reading a verdict, a coordinator reading a leg's report, anyone about to act on a green. **The fix
> is to change the reading, and applying Part One's remedy here means re-aiming an instrument that is
> already right.**

---

### A.12 — A check you can satisfy by EDITING THE ANSWER is not a check

Some instruments compare a measurement against a value that a person maintains. When the measurement
moves, there are two ways to make the instrument green: change the thing being measured, or change
the value it is compared against. **If the second is available, the instrument measures nothing in
the long run** — because the second is always cheaper, always defensible in the moment, and leaves
no trace that anything was given up.

The shape is easy to recognise once named:

- an expected **count** that a person edits when the real count changes;
- a floor — *at least N members were walked* — raised or lowered to match what the walk now finds;
- an expected-failure **list** that grows by one each time something fails;
- a tolerance — *this many reds is normal* — recorded anywhere at all.

**The last one has a measured cost.** A project that adopted this kit met two failures caused by the
kit itself, wrote *"a run that reports two failures is unchanged, not broken"* into its own project
law, and demoted the check to run on demand rather than as a gate. **One gate slot was lost on day
one, and nothing anywhere was red about it.** The tolerance was written by a careful person acting
reasonably on the evidence they had; that is what makes the shape dangerous rather than careless.

**The rule:** a value the instrument compares against is either **derived at run time from something
that is not the answer**, or it does not exist. Concretely:

- **A floor is replaced by a comparison, never frozen.** *"At least fifteen members were walked"*
  becomes *"every member of the derived population was reached"* — which cannot be satisfied by
  editing a number, because there is no number.
- **An expected-failure set is DECLARED WITH A REASON PER ENTRY and compared in BOTH DIRECTIONS.**
  An undeclared failure is a finding; **a declared failure that has gone green is also a finding**,
  because the reason has outlived the defect it described. The second direction is the one a
  tolerance can never give you, since a count going down looks like progress. **Fixing something
  must also require deleting its excuse** — and an expected-failure set that has emptied itself is
  the only kind that was ever worth keeping.
- **Where a literal genuinely cannot be avoided**, the instrument says in its own output that the
  value is a literal and what would make it stale — § A.4's rule applied to the span of a number.

**And the counting rule, which is where this sheet's own advice has most often failed in practice:
after changing what an instrument derives, COUNT what the new derivation reached and compare it to
what the instrument claims to cover. Do not read the diff and conclude.** A derivation change is
exactly the edit whose defect is invisible in review — the code reads correctly, the result is
green, and the population quietly moved. Every instance of the § A.4 defect recorded on this sheet
was found by counting a result; none was found by reading the code that produced it.

### A.13 — Readerless is fine; UNDECLARED readerless is not

A document that states a law and names nothing that reads it is not thereby broken. Plenty of good
rules are kept by people, and a sheet's own carve-out — *these are advisory instruments, never a
gate* — is a complete answer. **The defect is the SILENT case: a declaration that neither has a
reader nor says it has none.** It reads exactly like an enforced rule, so the next person edits the
declaration believing something will catch a mistake, and the next person after that builds a
reimplementation from it and omits what nobody told them exists. *The same hole has a second
opening, and it is the one that is hard to see from either end: a reader with no declaration. A
script that reads a file no document names is a coupling nobody can find by grepping — the file's
owner cannot know their edit breaks something, and the script's owner cannot know the file moved.*

**So the rule is about the SENTENCE, not about the mechanism:** where a document declares a format,
a marker, a threshold or a shape, it says which program reads it — **or says that none does, and
why**. Where a program reads a project file through a seam, the file's own document names it back.
*This was derived rather than reasoned: a population of format-law declarations was walked and the
readerless ones split cleanly — all but one declared their readerlessness, each for a different and
sufficient reason (an adopter-owned guard yet to be written, an explicit never-a-gate carve-out, a
pattern copy whose instance is the read one), and the single exception was the one real defect.*
**The healthy majority is the evidence for the rule, not the exception**; what they had in common
was not a reader but a stated position on having one. And *naming the reader is cheap and naming its
absence is cheaper* — both are one sentence, and neither obliges anyone to build a mechanism. A
project that wants a stronger form derives the declarations and asserts each names a reader, which
is the cheap direction and the only one that is decidable; whether a declaration TRULY describes its
reader is a review question, not an instrument's.

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
- **A HASH OF NOTHING IS A REAL HASH, and two of them compare EQUAL.** The *Read the STATUS* bullet
  earlier in this section is stated for
  *empty* results; this is the same defect wearing a full, valid, authoritative answer.
  `git show "${ref}:<path>" | <hasher>` where the path **does not exist at that ref** hashes the **empty
  stream** and returns a forty-hex digest that looks exactly like a measurement. So a byte-identity
  check between two paths that are both **missing** passes — and it passes *confidently*.
  **Learn the constant, not the warning:** `da39a3ee5e6b4b0d3255bfef95601890afd80709` is SHA-1 of the
  empty input. A reader who has seen that string once recognises it in an output pane instantly, and
  recognises nothing at all from a paragraph about empty streams. *(The equivalents for whatever
  hasher your project uses belong in § B beside your own instruments.)*
  **The fix is the general one: assert the OPERAND EXISTS before comparing digests of it** —
  `git cat-file -e "${ref}:<path>"` — because the digest cannot tell you it had nothing to chew on.
- **AND BRACE THE REF, OR ON zsh THE PATH IS MANGLED AND THE CURE ABOVE CANCELS THE HAZARD IT
  CURES.** Unbraced, what follows `$VAR:` is taken as a zsh **history modifier** whenever the next
  character is a modifier letter (`s l u h t r e q g a A p c x f F w W`). Three outcomes, and
  **which one you get depends on the characters of YOUR path, not on the shape of the mistake** —
  which is why this cannot be learned from one example:
  - **the path silently vanishes, exit 0** — `:s` is `s<delim>old<delim>new<delim>`, so it consumes
    the path as a substitution whenever the delimiter recurs often enough in it. Measured:
    `"$REF:spath/thing.py"` → `abc`, rc 0.
  - **a letter is eaten, exit 0** — `"$V:literal/p"` → `abciteral/p` (`:l` lowercasing, and the `l`
    is gone). Measured. Several modifiers do this; `:h` also rewrites the whole expansion to `.`.
  - **`bad substitution`, exit 1** — when the modifier is unterminated. Measured:
    `"$REF:src/thing.py"` → `bad substitution`, rc 1, because `:s`'s delimiter is then `r` and the
    path holds too few of them.
  **How common zsh is among adopters is UNMEASURED here, and the hazard does not need the figure**:
  one adopter lost a landing check to it, and bracing costs two characters.
  **The two failures compose in the worst direction.** `git cat-file -e "$REF:spath/thing.py"` exits
  0 — the path vanished, so it silently asked *"does this commit exist?"*, and it does — so the
  existence assertion above passes for a path in no ref at all. And `git show "$REF:spath/thing.py" |
  grep -c <needle>` counts matches in the **commit message**, so a string you just deleted reads as still present. *The same trap makes
  an absent thing look clean and a removed thing look PRESENT.*
  **The cure is one character-pair: always `"${REF}:path"`.** Braces end the expansion, so nothing
  after the colon can be read as a modifier.
- **A COUNT JOINED ON A KEY IS SHORT BY EXACTLY THE MEMBERS THAT LACK THE KEY — and those members
  are systematically the interesting ones.** A join silently drops what it cannot match, so the
  count it produces is not *"how many are there"* but *"how many carry the key"*, and nothing in the
  output distinguishes those two questions.
  **Why the loss is biased rather than random:** the keyless members are the **partial** ones — the
  record written before its id was assigned, the entry whose author never filled the field, the item
  that failed halfway through the process that stamps the key. **The population a join disappears is
  the population most worth looking at.**
  **So a derived count states its JOIN KEY and reports the members that lack it as a SEPARATE
  figure** — never folded into the total, never omitted. *"Forty-one matched on `id`; three carry no
  `id` and are listed below"* is a measurement. *"Forty-one"* is a claim about a population the
  reader will resolve as forty-four.
- **An instrument can measure a fact and report an ATTRIBUTION** — and the attribution may be
  invented. *"X changed"* is a measurement; *"the harness changed X"* is a claim about **cause**,
  which a before/after comparison cannot establish over a resource the instrument does not own
  exclusively. **A wrong attribution is worse than a bare fact, because it sends the reader to debug
  the one thing the evidence does not implicate.**
  **The commonest non-exclusive owner is YOU.** A probe whose operand is a state you — or the leg you
  are grading — just wrote answers about your own side effect. `mtime`-as-freshness is the standard
  shape: the file is newer because you touched it, and the instrument reports that as evidence the
  thing you were checking happened. § A.8's **named, non-self-referential witness** is the cure, and
  it is the same cure whether the other writer is a person, a process, or the run itself.

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

> Not anonymized, because it is ours. Read `scripts/test/cases/` (`check-board.sh`, `landing.sh`,
> `harness.sh`) and `scripts/test/lib/fixtures.sh` alongside this; `scripts/test/run.sh` is only the
> entry point.
>
> **These examples are the harness's DESIGN, not its bugs:** structure that exists **because** the
> rule is followed, plus one historical instance with its repair.

**The ablation (§ A.2), done properly.** The harness's board-checker cases do not merely assert that
a drift finding appears. A control leg **strips the check under test out of the sandbox's copy** of
the drift report, re-runs a board that *did* produce a finding, and asserts the finding is **gone** —
so a passing leg is attributable to the check's logic rather than to any output the script happened
to emit. Two guards on the ablation itself are the part worth copying: it **refuses to proceed if the
ablated copy no longer parses**, and **if the ablation removed nothing**. An ablation that silently
removed nothing is § A.2's own defect one level up.

**The probe that was deliberately NOT written (§ A.3).** Two cases carry an explicit note that a
capability probe was **left out on purpose** — a board-checker case, about the drift report still
containing its check, and the gate-runner case, about the runner carrying any particular gate. *Two
different subjects, one reasoning*, and the reasoning is the transferable half: such a probe *"would
turn the check being deleted into a SKIP instead of a FAIL"* — the exact regression those
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

**And one historical instance, kept because it is the clearest § A.9 case we have.** The harness's isolation
case verifies that the real repository's board surfaces are untouched by a run. During a multi-session
run it reported: *"the harness added a mutation to a board surface during the run."* **The detection
was exactly correct** — a board surface had changed between the run's start and its end. **The harness
had not done it**; a concurrent session was editing that file while the run was in flight. The case
measured a **fact** (the tree changed) and reported an **attribution** (the harness changed it), which
a before/after comparison cannot establish over a tree it does not own exclusively. The first reading
it produced was that the phase's landing had broken the witness — materially more alarming, and wrong.
**Nothing in the instrument was broken; the sentence it printed was the defect.** The repair is in the
case: it now reports that a board surface CHANGED, names both candidates (the harness broke its
isolation, or something else wrote to the checkout) and says it cannot tell them apart.
