<!-- KIT-CLASS: KIT — transferable doctrine. § A is the pattern; § B is the fill-in for YOUR project.
     Written from a thin evidence base and SAYS SO in § C, which is part of the sheet rather than an
     apology for it: a sheet about generalising from little evidence that hid its own is self-refuting. -->
# Generality doctrine — when one consumer's request may become everyone's rule

**What this governs.** The moment a request arrives from someone who uses what you ship — a report
from a pilot, a complaint from an adopter, a finding from a round of dogfooding — and you are deciding
whether to change **the shipped thing** because of it. Not whether the request is reasonable; assume it
is. The question is whether satisfying it makes the product better **for everyone**, or merely better
**for them**.

**The failure this prevents, in the words of the maintainer who named it:**

> *"We might be losing generality or worse, flipping things from on/off such that one run might need
> something this way, then another might need it that way, then the next needs it back. In those cases
> we're not making improvements, more so customizations for each consumer. In that way, it'd never
> end."*

That is the shape to hold in mind. Each individual change is defensible, argued from real evidence,
and lands cleanly. The damage is only visible **across** changes, as a trajectory: the product
accumulates one consumer's taste, then another's, and where the two disagree it oscillates. **Nothing
in a single well-argued change can reveal this**, which is why the check has to be a standing question
rather than a review comment.

## The counter-failure, stated first because it is the one this sheet is likeliest to cause

**Over-applying this produces a product that learns nothing.** A reviewer who reads this sheet as
*"one consumer means no"* will refuse the best findings you ever receive, and will be able to cite
doctrine while doing it. That reading is wrong.

The strongest rules in a mature process routinely come from **exactly one** consumer, one incident,
one bad afternoon. A rule derived from a single observation can be completely general — the
observation was the occasion for noticing it, not the evidence for it. What makes such a rule general
is that its **argument** never mentions the consumer: you can state why it is right to someone who has
never heard of them, and they agree.

> **The test is not *how many consumers*. It is *does the argument NEED this consumer*.**

Both failures are real and they pull in opposite directions. **§ A.1–A.4 are the four questions that
separate them** — none counts consumers as its primary move, and the second carries most of the
weight. **§ A.5 and § A.6 are not questions**: they are what the four owe once answered — a held
request is recorded, and none of this is wired as a gate.

---

## A. The pattern (this is the transferable part)

Apply all four of A.1–A.4 before a request changes shipped behaviour. They are cheap — minutes,
not a study — and they are asked **out loud, in the change's own record**, so a later reader can disagree with the
answer rather than guess whether it was asked.

### A.1 — Is the evidence one consumer, or several? (the weakest question, asked first anyway)

> One instance is a preference with a story attached — **until its argument is examined.** This
> question sets the burden of proof; it never decides the outcome.

A request backed by several independent consumers who could not have coordinated has already survived
a test nothing else here can substitute for: it generalised **in the world**, before you reasoned about
it. Take that seriously and move quickly.

A request from one consumer is not thereby refused. It is **owed the remaining three questions in
full**, where a multi-consumer request may pass on A.2 alone. That is the whole operational content of
this question: it decides how hard you look, not what you find.

**Count independence per surface, because a shared environment is not independence.** Consumers who
could not have coordinated may still have **shared the constraint** — for example the same agent
harness, the same vendor's tooling, the same exercise design, the same product. On a surface that
shared thing shapes — how the tool wants edits isolated, what it adds to a commit by default, what the
exercise asked every participant to do — their agreement is one environment answering several times,
and it counts as **one**. On a surface the shared thing does not touch, the same consumers still count
separately. So before crediting a count, name what the consumers had in common and ask whether this
surface is one it shapes. ***Could not have coordinated* is not *did not share the constraint*.**

**And prefer a CLASS to an INSTANCE when you file the evidence.** Where you can state the request as
*this kind of thing goes wrong in this kind of way*, rather than *this file was wrong on Tuesday*, you
have done most of A.3's work already and you have something a second consumer can recognise in their
own tree.

### A.2 — Would the opposite request be equally reasonable from a different consumer? **The flip-flop test.**

> **If yes, it is a SETTING, not a rule** — and the answer to a setting is a **declared seam with a
> default**, never a change to shipped behaviour.

This is the load-bearing question and the one that directly answers the concern at the top. Ask it
concretely: **name the consumer who would want the opposite**, and say what about their situation
makes them want it. If you can name them in one sentence, you have found a setting.

**Why naming is the mechanism.** *"Someone might disagree"* is available about every rule ever written
and therefore refuses nothing. *"A team running unattended overnight wants this loud; a person carrying
the alerts on their phone wants it quiet; neither is wrong"* is a finding — it identifies two
populations with genuinely opposed interests, which is what makes a single shipped default impossible
rather than merely contested.

**The dispositions this question produces, and only the setting is a new kind of answer** — the
second row is a rule, shipped with what it tests:

| Answer | Disposition |
|---|---|
| **No** — the opposite is not reasonable from anyone | It is a **rule**. Ship it. |
| **No, but the consumers who agree reached the outcome by different arguments** | It is a **rule whose test is unstated**. Ship it **with one sentence stating what it tests** — the property that decides the case — not only the outcome. |
| **Yes** — a nameable consumer wants the opposite, for a reason | It is a **setting**. Ship a seam with a default; do not change behaviour. |
| **Yes, and no seam is affordable** | Ship **nothing**, and record why — including which consumer you chose not to serve. |

**A setting is not a lesser outcome, and writing it up as a refusal is the mistake to avoid.** A
declared seam serves *both* consumers permanently; a rule serves one and quietly injures the other on
a schedule nobody is watching. Where you choose a seam, the change's record should say it **upholds**
the request, in a form that survives the next consumer asking for the reverse.

**Same outcome, divergent argument, is agreement on an answer and not on a rule.** When consumers do
the same thing but each gives a reason that ignores or denies the others', nobody has written down what
the rule tests. The next consumer, in circumstances none of them had, can reach the opposite by an
argument of their own — and it may look like a setting when it may be a missing sentence. So the remedy
is neither a behaviour change nor a seam: state the property the rule turns on (for example, *what
makes day-one scaffolding metadata rather than code*), so that each consumer's case is decided by that
sentence rather than by their own reasoning.

**The signature to watch for in your own history:** the same knob argued in both directions at
different times. If you can find a reversal — the same behaviour changed one way, then back — you have
observed the failure rather than predicted it, and everything it touched is a setting.

**A caution that costs nothing to state.** A reversal **within one consumer**, an hour apart, is not
this. It is a consumer changing their mind, which is ordinary; the test is about opposed interests
across *different* parties, and conflating the two will make you call settings out of noise.

**A second caution: a consumer who did not FIND your answer has not disagreed with it.** Before
reading an opposite resolution as opposed interests, ask whether the dissenting consumer met the part
of what you ship that already addresses their stated reason. The mark of this case is that the reason
would **dissolve given the answer** — sometimes the consumer's own later record dissolves it. The
remedy is a **pointer from the surface they were on** to where the answer lives, not a seam. The same
reading applies when consumers *agree* by rediscovering a rule you already ship: that is not evidence
for a new rule, it is evidence the old one is not found where it is needed. Whatever part of the
reason survives the answer is still owed the setting question.

**Check the answer before you point at it.** A discoverability reading assumes the thing the consumer
missed is right. If it is itself defective, the dissent may have been the better call, and the finding
is a defect in your answer rather than a missing pointer.

### A.3 — Does the argument survive the donor being anonymous?

> Strip every identifier — the project, the product, the person, the tree, the incident — and read the
> argument back. **If it stops being persuasive, it had not generalised; it was borrowing.**

This is the content rule most projects already apply to *facts* (no real project's names, paths or
domain details enter a shared artifact), applied instead to **rules**. It is needed separately because
a rule is far harder to spot than a filename: **a rule arrives already argued**, wearing the shape of
something general, and the specific circumstances it depends on sit in the reader's head rather than on
the page.

The practical form is a rewrite, not a judgement. Write the rule as you would ship it — no
identifiers — then ask whether you would still ship it. Two things happen often enough to expect them:

- The rule survives and is **better**, because removing the incident forced you to state the mechanism.
  This is the common case and it is why the question is worth the minutes.
- The rule cannot be written without the incident at all. That is the answer: what you have is a
  **finding about that consumer**, valuable to them, and it belongs in their record rather than in
  what you ship.

**A rule that survives anonymisation still owes its reason.** Strip the identifiers, never the *why* —
a rule shipped without its rationale is one a successor cannot re-argue, and it will be either
cargo-culted or deleted, both wrongly.

### A.4 — What would falsify it?

> A rule no observation could contradict is a **taste**. Name the observation that would make you take
> it back, before you ship it.

The answer should be something that could actually happen and that you would actually notice: a
consumer who follows the rule and is worse off, a case where it produces the wrong outcome, a second
adopter who needs the opposite. Write it into the change's record.

**Two things this buys, and the second is the reason it is worth a line:**

1. It is the **honest form of the deferral** you will otherwise be tempted into. A rule with a stated
   falsifier can ship *now*, on thin evidence, because the condition for revisiting it is written down
   where the next reader will find it.
2. It converts a later disagreement from an argument into an **observation**. Without it, a consumer
   who finds the rule wrong is contradicting doctrine; with it, they are supplying the case the rule
   itself asked for. The second conversation is enormously cheaper and it is the one you want.

**And where you cannot name a falsifier, say that in the record rather than inventing a weak one.** An
unfalsifiable rule is not automatically wrong — some are definitions — but it should be shipped knowing
that no evidence will ever revise it.

### A.5 — Where a request is held, the holding is RECORDED, and the record names what would release it

> A request refused or deferred without a durable record is a request that will arrive again, be
> argued from scratch, and be decided differently. **The inconsistency the top of this sheet warns
> about is produced as much by forgotten refusals as by granted ones.**

So a held request owes three things in whatever place your project keeps its reasoning: **what was
asked**, **which of A.1–A.4 it failed and why**, and **the observable event that would change the
answer** — a second consumer meeting it, a seam becoming affordable, the named falsifier occurring.
An event, not a date.

**This clause is what makes the other four safe to apply strictly.** Holding is only a defensible
disposition when it is visible; an obligation nobody can see is not an obligation, and a request held
twice without the second holding being written down is indistinguishable from one that was dropped.

### A.6 — None of this is mechanically decidable, and it must not be wired as a gate

> Every question above requires knowing what a *different* consumer would want. No check in your
> repository has that information, and one that pretends to will be wrong in the expensive direction.

The disposition is a **reviewer's duty**, asked at the moment a request becomes a change. What you may
mechanise is the **record** — that the questions were answered somewhere — never the answers.

**A heuristic gate here would be worse than nothing** for the ordinary reason: a low-precision check
standing between a good finding and the product gets disabled, and a disabled gate reads as armed. The
thing it was watching then looks watched.

---

## B. Your project's instance — **fill this in**

Delete this section wholesale if your project ships to nobody: with one consumer who is also the
author, none of § A binds. Filling it in is what makes § A enforceable here rather than admirable.

| Duty | Fill in |
|---|---|
| **Who are your consumers?** | `<the parties whose requests could become rules>` — named, derived from your own records rather than recalled. If the answer is one, say so: A.1 is then always *one consumer* and A.2 carries the whole weight. |
| **Where is the disposition recorded?** | `<the file or field>` — where a reader finds which of A.1–A.4 a change was argued against. |
| **What a SETTING looks like here** | `<your seam convention>` (A.2) — where a declared seam lives, how its default is chosen, and where the default is stated. |
| **Where a HELD request is written** | `<the convention for A.5>`, and where its discharging **event** is recorded. |
| **Who asks the four questions, and when** | `<the review step>` — A.6 forbids a gate, so name the human step or the sheet does not bind. |

**Two duties worth stating even where the table is empty:**

1. **A request granted as a rule and a request held both get a record.** Only recording the grants
   produces a history in which every past decision was yes.
2. **When a second consumer meets a held request, the hold is revisited in the same change that
   notices** — not on a sweep. A held request whose releasing event has quietly occurred is the
   slowest way to lose a good finding.

---

## C. This sheet's own evidence base — stated, because it is thin

**Written from a single round's worth of observation on the question it is actually about, amended
after a second, and it says so here rather than reading as settled.** Two halves, and they are not
equally supported:

- **The SHAPE half is affirmative at n=2.** Two independent consumers, on different products in
  different languages, neither ever shown the process being measured, converged on substantially the
  same working shape. That is real evidence that a *process* can generalise across consumers, and it
  is why this sheet does not simply refuse single-consumer evidence.
- **The CONTENT half — does one consumer's REQUEST generalise — has now been exercised on overlapping
  surfaces, once, in one environment.**
  *As of 2026-09-25, a join over both rounds:* **five consumer-instances on three products** — two of
  them carried from the first round, and one a continuation of another's tree — which is **up to four
  independent lineages**, and four only on surfaces the product does not drive. The join went surface
  by surface through each consumer's own feedback, procedure and decision records, under two counting
  rules: a consumer that continues another's tree inherits its rulings and is **never** independent of
  it, and two consumers on the same product count as one on any surface the product drives. **A.2 has
  met a genuine cross-consumer disagreement and sorted it correctly.** On one surface — which role a
  commit is attributed to before any role has been declared — four lineages gave three different
  answers, each rationale denying another's premise, and the two on the same product disagreed with
  each other, which located the choice in the seat rather than the product. A.2 called it a
  **setting**, owed a declared seam with a default. The shipped seams the join met were recognised as
  seams, with no change owed. **The falsifier this section names below did not occur, and the closest
  case was examined and judged not one:** one consumer reversed a shipped instruction that two others
  followed, but its stated reason was answered by an option that instruction's section never
  mentioned, and a later entry of its own removed the premise — a discoverability gap, not opposed
  interests. **The doubt is stated rather than closed:** that consumer's own clause about genuinely
  parallel work could still be a real setting. **So the four questions are no longer only reasoned —
  but they are not yet measured across environments:** every instance in the join shared one harness
  and one exercise design, so on the surfaces those shape, its counts overstate generality. That is
  the qualifier A.1 now carries, and it is why this section's heading still says *thin*.
  *As stated on 2026-09-18, from the first round alone, and superseded above:* **a population of
  two, and the two do not overlap.** Each of the two consumers produced exactly one request, and they
  land on different surfaces: one is a deterministic defect in the initializer, the other a boundary
  between two roles in the handoff sequence. **A.1's *one consumer or several* is therefore askable at n=2 on
  that channel** — but two requests on two different surfaces are a population, not a reversal.
  **The four questions above remain reasoned rather than measured**: nothing in the two requests
  tests whether a question sorts well, because no question has yet had to separate two consumers who
  disagree. A.2 in particular has been applied in practice and still has **not** been tested against
  a genuine cross-consumer reversal — for that the two consumers must meet the *same* surface and
  resolve it differently, which these two do not.

**What follows from that, and it is a duty rather than a caveat:** this sheet is expected to be
**tuned** as more consumers arrive. Expect some questions to be sharpened, at least one to be
demoted, and A.2's three dispositions to acquire a fourth. *(2026-09-25: the demotion has happened,
and it landed on A.1's weight rather than its place — A.1 now carries the environment qualifier, so a
count on a surface a shared environment shapes weighs less than it did. The same
evidence gave A.2 a fourth row — a rule shipped with its test stated, for the same outcome reached by
divergent arguments — and sharpened it with a discoverability caution.)* **The falsifier A.4 demands of every rule,
applied to this sheet itself:** a consumer meeting all four questions and still receiving a change
that another consumer has to reverse would show that the four are not sufficient, and this sheet would
owe a fifth.

**This section is not an apology and must not be deleted as one.** A sheet about generalising from
thin evidence that concealed its own evidence base would be its own first counter-example — and a
reader who does not know how well-supported a rule is cannot weigh it against the case in front of
them, which is exactly the judgement A.6 leaves to them.

---

## Why this is its own sheet and not a section of an existing one

Because the sheets it is nearest to are **looked up by different people at different moments**, which
is this kit's test for a sheet boundary.

- **[`supersession.md`](supersession.md)** governs **how** a ruling is amended once you have decided
  to amend it, and what happens to the superseded record. This sheet governs **whether the change
  should be made at all**. They meet only after this one has answered yes.
- **[`retention.md`](retention.md)** decides whether an existing thing is kept or retired. This sheet
  decides whether a *new* thing enters. Opposite direction, different reader.
- **[`negative-claims.md`](negative-claims.md)** and **[`consumer-output.md`](consumer-output.md)**
  govern what a *claim* or an *output* may say. Nothing here is about a claim's wording; it is about a
  disposition taken before anything is written.
- **The pattern-vs-instance rule in the extraction manifest** is the nearest relative and it is about
  the wrong object: it keeps one project's **facts** out of what ships. This sheet keeps one project's
  **preferences** out of what ships. A preference is harder to catch precisely because it arrives as an
  argument rather than as a name, which A.3 is the answer to.
