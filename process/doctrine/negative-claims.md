<!-- KIT-CLASS: KIT — transferable doctrine. § A is the pattern; § B is the fill-in for YOUR incidents and wiring. -->
# Negative-claim doctrine — enumerate the attempts, or say "unmeasured"

**KIT-CLASS: KIT.** Promoted after a shipped negative claim over-reached its evidence; § A carries
the rule and the ones that grew out of it — *its own headings are the list, which is why no count
is written here. This line said "one rule" while § A held its mirror rule and a detection-recipe
rule besides.* **§ A.5 generalises the sheet past its title:** the rule about how wide a claim may
be is the same rule as how it was OBTAINED, and it binds any claim whose scope can exceed its
evidence — the negative being the worst case and the one the title names.
§ A is the transferable pattern; § B is where **your** project records its own instance.

**Why this is its own sheet, not a section of [`supersession.md`](supersession.md).** The two are
neighbours and cite each other, but they govern different moments and are looked up by different
people: supersession governs **amending** a claim once new evidence arrives (a PM/seat act, at
ruling time); this governs **making** a claim in the first place (an implementer act at authoring
time, a reviewer act at review time). Folding this into § A of a sheet titled *supersession* would
bury the authoring-time rule under a heading nobody reads while writing a spike verdict — and the
rule's whole value is being remembered **before** the sentence ships. Separate sheet, mutual
pointer.

**What it operationalises.** `verification-before-completion` — *prove work before claiming done* —
applied in the **negative** direction, which that skill does not cover. A claim that something is
impossible is as much an assertion as a claim that it works, and it is far harder to falsify later:
nobody re-tests a documented *cannot*.

**Its other neighbour, one step upstream.** This sheet asks whether a *claim* is grounded;
[`instruments.md`](instruments.md) asks whether the **check behind it can see anything at all** — an
audit that returns no violations has not established that it *could* have found one. A.1b's rule
that a registration without a falsifier "is not a weaker guard; it is a suppression file with better
manners" is the same idea met at claim-time; instruments meets it at guard-building time.

---

## A. The pattern (this is the transferable part)

### A.1 — The rule

> A shipped **negative capability claim** — *cannot*, *impossible*, *not supported*, *does not
> exist* — must **EITHER** cite the enumerated attempts that ground it, **OR** use "unmeasured"
> language.
>
> **Enumeration** means the *actual forms tried*, listed: the address shapes, the endpoints, the
> parameter spellings — enough that a reader can see **the edge of the evidence**. An untested form
> is **`unmeasured`, not `cannot`**.
>
> **The claim's scope may not exceed its evidence's scope.** Evidence about one grammar grounds a
> claim about **that grammar**, not about its class. State the axes that were **not** covered —
> other clients, other object kinds, other tenants, other API versions — rather than leaving them
> implied.

### A.1b — The mirror rule: a claim of absence or futurity is GUARDED OR DELETED

A.1 governs the **tense-less** negative — *cannot*, *not supported*, *does not exist*. It does
not govern the **future** tense, and that is where the same failure recurs in its most durable
form. So, as its mirror:

> A shipped claim of **ABSENCE** or **FUTURITY** is **guarded or deleted**. Roadmap prose in
> shipped documents is **deletion-first** — a future-tense sentence in a shipped document is a
> promise that ages without anyone re-reading it, and the cheapest correct version of it is its
> absence.

**"Guarded" has a specific meaning here, and it is the only thing that makes the rule bite.** A
guarded claim is one a machine can falsify: it is registered somewhere the test suite reads, and
its registration names a **falsifier** — the thing whose *existence* would make the claim false
(an import path, a parameter on a shipped callable, a key in a capability registry). The guard
then holds it in **both** directions:

- a **new** forward-looking sentence in the shipped corpus fails until it is deleted or
  registered, and
- a **registered** claim whose falsifier **now exists** fails *at that moment* — which is the
  only mechanism that catches the sentence on the day it becomes false rather than on the day a
  consumer reports it.

A registration is **not a comment**. A row with no falsifier is not a weaker guard; it is a
suppression file with better manners, and it should be refused.

**Deletion-first, and why it is the default.** Most forward-looking sentences do not need to be
guarded, because they do not need to be shipped. A roadmap belongs where the roadmap is
maintained; in a shipped document it is a claim the reader has no way to date and the author has
no reason to revisit. Delete it, and the problem is gone permanently for the cost of one line.
Guard it only when the sentence is genuinely load-bearing for a reader **now** — a scoped
disclosure they must plan around.

**The honest exceptions, which the rule must not punish.** Two shapes legitimately carry a
forward-looking phrase next to a falsifier that already exists, and a guard that reddened on
them would be attacking the behaviour A.1 asks for:

- an **unmeasured disclosure** in A.1's own vocabulary (*"the cross-week case has not been
  measured, so this makes no claim of permanence"*) — that is not a promise, it is evidence
  scoping;
- a claim inside an **append-only dated record** (a release-note entry under a shipped version
  heading) — it was true of that release, and history is not edited.

Everywhere else — a live guide, a README, a docstring, a `--help` page — a forward-looking claim
whose falsifier already exists is simply **false**, and there is no registration for it. It is
fixed or deleted.

### A.2 — Why negative claims specifically

A negative claim is the most dangerous sentence in a shipped corpus, for two compounding reasons.

- **It is believed, so it is never retested.** A consumer reading *cannot* does not try it. An
  over-broad negative therefore removes a real capability from every downstream project, silently,
  for as long as it stands. A false *positive* claim fails loudly on first use; a false negative
  never fails at all.
- **It is written at the moment of maximum confidence and minimum coverage** — at the end of a
  spike, having tried every form that occurred to you, it feels like you have tried everything.
  The feeling of exhaustiveness is produced by the same imagination that bounded the search.

This is why the remedy is not "be more careful": it is a **cheap, checkable output**. Enumeration
converts an unfalsifiable feeling into a list a reviewer can read the edges of, in one line each.

### A.3 — What good looks like

The two acceptable shapes, both short:

- **Enumerated:** *"Tried the `#fragment-<token>` form, the `?anchor=<id>` query form and the
  object-get endpoint with the share token: all three refused (evidence: …). Not tried: the bare
  `#<id>` fragment, other clients."*
- **Unmeasured:** *"No form we tried produces one; the remaining forms are **unmeasured**, not
  refuted."*

Both are honest. What is **not** acceptable is the third shape — the confident class-level
*cannot* with the attempt list left in the author's head.

Corollaries worth stating, because each is a real failure mode:

- **Do not upgrade "we did not try it" to "it cannot be done"** during editing. Compression of a
  spike write-up into a shipped sentence is exactly where the scope quietly widens.
- **"No endpoint exists" is a claim about a search**, so name the search: which reference, which
  version, which date. An external system gains endpoints.
- **A negative proven on one tenant / one account / one permission set is scoped to it.** Say the
  axis rather than generalising across it.
- **Amending one later is [`supersession.md`](supersession.md) § A.1's job** — preserve the reason,
  supersede only the conclusion. A well-enumerated negative is *cheap* to amend precisely because
  the evidence's edge is already written down.

**How to adopt:** § A is project-agnostic; take it verbatim, **every rule under it**. Wire them
into the two places a claim passes through in your own process — the implementer's definition of
done, and the reviewer's checklist — as one line each. **§ A.5's second-reader clause belongs in
the REVIEWER's line specifically**, because it is the only one of these rules a reviewer can fail
while doing everything else right. The doctrine is worthless as a document nobody
is routed to. A.1b additionally asks for a **machine**: run your own shipped-text corpus past a
forward-looking phrase list, and make each surviving occurrence carry a falsifier your test
suite resolves. The phrase list, the corpus and the guard's path are **yours**, not this
document's.

**A spike's probe scripts are part of the evidence.** Commit them under the spike's evidence
directory, so a negative claim's audit trail survives the session that produced it; a leg that ran
no script says so rather than shipping an empty directory.

### A.4 — A DETECTION RECIPE offered inside a ruling is a negative claim, and owes both halves

A ruling that names a defect often offers a way to find the rest of it — *"the cheap check for this
is `grep …`"*. That recipe is doing two jobs, and only the first is obvious. It finds instances; and
it **asserts, silently, that nothing else in the tree is an instance.** The second is a negative
claim about a whole corpus, made in one line, usually unmeasured.

**Its characteristic failure is worse than being wrong: it is being PRESENT.** A recipe that catches
most of a class reads as coverage, and **the ruling's having offered one is what stops anyone looking
harder.** Measured instance: a ruling forbade a class of test, named its paid instances, and offered a
grep for the literal string they shared. Two further instances of the same class were then written
*after* the ruling and survived it, because they asserted an **absence** and therefore contained no
such string. Run against the tree that still held them, the ruling's own recipe returned several
hits — **and not one of them was either survivor.**

So a recipe owes the same two halves this sheet asks of any *cannot*:

- **Run it against the tree that still contains the known instances, and record the hit count.** A
  recipe shipped unmeasured is a guess with authority. If it does not find the instances that
  motivated the ruling, that is the finding.
- **State its blind spot, or say it has none** — in the ruling, beside the recipe. The forms it
  cannot match are `unmeasured`, not absent.

**And prefer the property to the string.** *"Does the cut make this false?"* transfers; a literal to
grep for does not, because the next instance of a class rarely spells itself the same way. Where a
string is genuinely the cheapest handle, ship it **with** the property it is standing in for.

*(The recipe is also an instrument, so everything in
[`instruments.md`](instruments.md) binds it — in particular § A.7 on lexicons that imply a
completeness they do not have. It is stated **here** because its failure mode is a negative claim
about a corpus, which is this sheet's subject; that sheet points at this rule rather than carrying
it.)*

### A.5 — THE ROUTE LAW: a claim names the route that produced it, in the same sentence

§ A.1 says the claim's scope may not exceed its evidence's scope. **This is that rule pointed at
the axis A.1 leaves implied: not how WIDE the evidence was, but HOW IT WAS OBTAINED.**

> **A claim is true only of the OPERAND, the ROUTE and the MOMENT that produced it — and the scope
> goes INSIDE the sentence the reader acts on.**
>
> A **negative** is the worst case and the one this sheet is named for: *cannot*, *never*,
> *impossible*, *clean*, *none found* is a claim about **the route it was obtained by**, not about
> the system, unless every route was enumerated.

**Why a negative is the worst case, stated because it is the reason and not the rule.** A positive
result carries its own evidence — *"X happens"* is proved by the run that showed it. **A negative
carries none.** *"X does not happen"* is only ever *"X did not happen along the path I took"*, and
the distance between those two sentences is where this class lives. § A.2's two reasons compound
it: nobody re-tests a documented *cannot*, and the sentence is written at the moment of maximum
confidence and minimum coverage.

**The rule is not restricted to negatives.** Any claim whose scope can exceed its evidence — a
verdict, a count, a label, a status line, a capability, a diagnosis — owes the same thing. The
negative is named separately because it is the member nobody re-checks.

#### The six forms

Each is the same rule pointed at a different kind of claim, and each fails the same way: **a claim
true of what the speaker examined, read as a claim about the system.**

| form | the claim | what it must name |
|---|---|---|
| **1 — a negative** | *cannot, never, clean, none found* | the **route** it was obtained by |
| **2 — a diagnosis** | *"X happens because Y"* | the **instances** it was derived from |
| **3 — a count** | *"there are N"* | the **command** that produced N |
| **4 — a report** | *"component X is broken"* | the **layer** actually observed |
| **5 — a permission** | *"yes, do that"* | the **question** it was asked |
| **6 — a positive claim about a corpus** | *"X happens in the report"* | the **site** it happens at |

**Form 2 — a diagnosis is obtained by a route exactly as a negative is.** The first instance anyone
looks at is a sample of one route, and the features it happens to have get written down as the
cause. A measured case: a defect was diagnosed as *"it mis-pairs whenever the line carries a second
span"*; two later attempts called it irreproducible, both testing the same way. The true mechanism
was different and simpler — a marker that never closes at all — and the second span was irrelevant.
**The original sentence described a CO-OCCURRENCE the observer happened to see, wearing a
mechanism's clothes.** So: *a diagnosis names the instances it was derived from, in the same
sentence.*

**Form 3 sharpens [`staleness.md`](staleness.md) § C.** *Derive, date, or do not state* is
satisfied by a bare number with a date, and that number is **still unfalsifiable**: a reader who
gets a different answer cannot tell a changed tree from a different counting rule, so the cheapest
move available to them is to doubt the number rather than check it. **"Derive" has to mean "show
the derivation", not "a derivation was performed".** Measured: two parties disagreed over a figure,
one of them named the rule it had counted by, and the disagreement resolved in a single command
instead of an argument — the file had two populations and each had counted one. **A count that
names its command can be disagreed with; one that does not can only be doubted.**

**Form 4 names the OBSERVATION BOUNDARY — what the reporter could actually see.** A report that
blames a component it never inspected sends the fix to the wrong place, **and the wrongness is
invisible from where the fix lands**: the seat dispatched to fix the named component finds nothing
wrong with it, and then faces a choice between two wrong conclusions — that the report was mistaken
(it was not; the corruption was real) or that the component needed changing anyway (it did not).
Measured: output emerged corrupted from a call to a script, the script was blamed, and the
substitution was happening in the caller's own shell. **When a report blames a component, check the
layer above it before dispatching.**

**Form 5 is this law with a permission in place of a measurement.** A grant is a claim about the
question in front of the granter, and it is silent about every constraint the granter did not see.
Measured: a delivery was authorised; the executing seat held it, because it could see that the
source was an unlanded branch — a constraint the granter had never been asked about. **A permission
answers the question it was asked. The seat executing it sees constraints the granter did not, and
those remain the executing seat's to JUDGE and — the part that makes this safe — to REPORT.** A
seat that silently declines leaves the granter waiting for a result that will never arrive; a seat
that silently obeys ships the defect with the granter's signature on it. *A hold that is not
reported is indistinguishable from a hold that never happened.*

**Form 6 is the one § A.2 above argues this sheet does not need, and the exception is precise.**
§ A.2 is right that a false positive fails loudly on first use — **that is true of a
positive EVENT.** A positive claim over a **corpus** — *"this happens in the report"*, *"the guide
covers this"* — is not proved by any one event, and a reader cannot disprove *"X happens somewhere
in here"*, so nobody tries. **It is not merely less useful; it is unfalsifiable, and therefore
never checked.** Name the site.

#### The second-reader clause — two readers on one route is one measurement read twice

**This binds REVIEWS, not only findings, and it is the half that misses the case which produced the
law.** A reviewer's *"I agree it cannot be caught"* is itself a negative result, obtained by one
route.

Measured: an implementer found half a defect unfixable, documented it and shipped; a reviewer
re-derived the mechanism independently, agreed, and escalated the scope call — correct behaviour at
every step. Both were right about the mechanism. **Both stopped at the same place, having tested
the same single route.** A third party later measured a different entry point, which catches the
fault cleanly.

**That eliminates the cheap remedy.** *"Have someone else check it"* is the standard answer to a
claim class, and here **the reviewer WAS the second reader.** A second reader re-derives the same
mechanism along the same route and agrees. **The disagreement has to come from a different ROUTE,
not a different person.** So a reviewer meeting a *cannot* asks for the route, and where the claim
is load-bearing, asks for a second route rather than a second opinion.

#### Disclosure elsewhere is not scope

Every instance behind this rule disclosed its scope **somewhere** — in a design note, in the code
beside it, in a rule already in force. **The defect is entirely about POSITION.** A scope stated in
a paragraph the reader does not open while acting is not a scope; it is a fact the reader will be
told they should have known.

The sharpest measured case is the one where the rule was not merely documented but **already
binding**: a standing ruling required every instrument to state what it did not establish, and
instruments kept shipping claims they could not back anyway. **The rule existed, elsewhere, and the
elsewhere is the whole defect.** The author's own diagnosis is the reason this clause exists:

> *"I keep writing the acceptance criterion for the claim and relying on remembering the other rule
> for the limit. Remembering is not a mechanism."*

#### The corollaries — the same rule addressed to five parties

A rule addressed to everyone is remembered by no one, and the evidence is that each party misses it
for a **different** reason. So:

- **The AC author** — an acceptance criterion that demands a claim demands **the claim's limit in
  the same AC**. Not in the doctrine it points at, not in a rule the author is expected to recall.
- **The inheritor** — a technique adopted from elsewhere **re-asserts its original scope about a
  subject nobody re-measured**. Carry the measurement or re-take it. *A technique carried forward
  without its measurement is a habit wearing a control's clothes.*
- **The fixer** — a fix binds **only the layers it joined**. A green suite over the joined layer
  says nothing about the layer the consumer reads; *"the tests are green"* after a consistency fix
  names that layer or claims nothing.
- **The reviewer** — the second-reader clause above.
- **The executor** — form 5 above: judge the constraints the granter could not see, and report the
  hold.

#### When this binds — the trigger, and the exemption is the point

**Everything above tells you what a claim owes. This says when.** The rule was shipped without a
trigger, and a rule demanded of every sentence is obeyed where it is convenient and skipped where it
matters. That is not a prediction: it was measured on the seat that wrote the sheet.

**Two obligations, and they have different triggers — collapsing them is what breaks the rule.**

1. **NAMING the route is universal.** It costs three words, the route is already known at the moment
   of writing, and § *What it costs* below is the argument. Nothing below exempts you from it.
2. **TAKING a second route costs real work, so it is owed only where a claim is LOAD-BEARING** —
   and that word is used above, in the second-reader clause, without ever being defined. It is
   defined here:

> **A claim is LOAD-BEARING if someone will act on it, or if its being wrong changes a decision.**
> A load-bearing claim owes **a second observation by a different route** before it is stated.
> **Everything else owes nothing, and that exemption is the point.**

**The question that sorts them is one line: *if this is wrong, what happens?*** If the answer is
"nothing" — a remark, an aside, a claim the next step would expose anyway — it is exempt, and the
exemption is what makes the rest enforceable. If the answer is anything at all, the claim is
load-bearing and the second route is owed.

**What counts as a second route, by claim shape.** A second *reading* is never one — the
second-reader clause above is the reason, and it applies to you re-reading your own work exactly as
it applies to a reviewer.

| shape | the second route |
|---|---|
| **a count** | derive it a **second way**; re-reading the first derivation is the same route |
| **a guard** | prove it **fires** AND that it **stays quiet** — a guard only ever seen refusing has not been shown to permit |
| **a diagnosis** | reproduce it once more **with the suspected cause removed** |
| **a negative** | try a **different entry point**, not the same one more carefully |

**The guard row is the one with independent evidence, and it is the expensive one.** Two release
guards were once verified in their red state and never in their green; one of them blocked every
release for a week before anyone noticed, because a guard that refuses everything looks exactly like
a guard that is working. *An ablation proves a guard CAN fire. Nothing but a green case proves it can
stay SILENT.*

**Why this is a trigger and not a better-worded rule.** Restating the law more forcefully has been
tried and it does not work — § *What this rule does NOT claim* below records the measurement:
parties produce instances of this class **while actively writing about it**, with the rule on screen.
A trigger does something a restatement cannot: it **narrows the population** the rule is demanded of,
which is the only move that makes a convention with no mechanism affordable enough to actually run.

**What this trigger does not do.** It is a convention with a reader, not a mechanism — the honest gap
§ *What this rule does NOT claim* already names, and this clause does not close it. It has not been
measured in use; the argument for it is that the untriggered form demonstrably was not applied. **It
will also mis-sort**, and the direction of the error is chosen deliberately: a claim's consequences
are often clearer after it turns out to be wrong, so when the answer to *if this is wrong, what
happens?* is genuinely unclear, treat it as load-bearing. Thirty seconds is cheaper than the hours
the measured instances cost to discover.

#### What it costs, and why that is the argument

**Three words, in the sentence that carries the claim:**

- ❌ *"a locked file cannot be caught"*
- ✅ *"a locked file cannot be caught **through the command the consumer types**"* — which
  immediately invites *"what about the other entry points?"*, and **that question is the whole
  mechanism.**

The route is nearly always already known to the writer at the moment of writing. **It costs nothing
to state and it is never recoverable afterwards** — which is why the measured instance above
survived a review.

#### What this rule does NOT claim

- **It does not close the gap; it makes it visible to a reader.** An implementer who writes
  *"cannot be caught through `<the one entry point>`"* may still ship, and a reviewer may still
  agree. The rule buys a question that can be asked, not an answer.
- **Nothing enforces it, and that is measured rather than conceded.** An attempt to mechanise the
  general form over a real corpus returned a hit list that was almost entirely ordinary usage,
  because **scope is a paragraph property, not a line property.** The one greppable member is the
  corpus-scoped reassurance — *"unreachable from the corpus"* and its kin — and that one is worth a
  check on its own terms. The rest is convention, and a convention that costs three words at
  authoring time may be the whole available remedy.
- **Knowing the pattern is demonstrably not sufficient to avoid it.** The strongest evidence for
  that is a party holding a collection of instances of this shape, writing about them, and
  producing a fresh one **inside the correction to one of them** — no count is written here,
  because a count of a corpus the reader cannot open is form 3 above with nothing behind it, and
  the argument needs only that it happened during the correction. Treat it as a checklist line at
  authoring and review time, not as an idea to hold in mind.

---

## B. Your project's instance — **fill this in**

> **PROJECT INSTANCE from here down.** Nothing here is inherited.

**What goes here, and nothing else:**

1. **Your motivating incident**, if you have one — what was claimed, what evidence it rested on,
   and which axis the claim exceeded. Keep the good half: a well-scoped enumeration is not
   discredited by the over-generalisation stacked on top of it.
2. **Where A.1, A.1b and A.5 are wired**, one line each: the implementer's Definition of Done, the
   reviewer's cross-cut checks, and the spike's probe-evidence rule. **A.5 additionally wants a
   line wherever your process writes an acceptance criterion** — its AC-author corollary is the one
   that fails silently, because the author is relying on remembering a rule that lives elsewhere.
3. **Your A.1b machine**, if you build one: the guard's path, the corpus it reads (**reuse the
   consumer-reaching corpus you already have — never mint a second one**), the phrase list with a
   stated reason per phrase, the falsifier kinds it resolves for real, and the surfaces where a
   dated record is allowed to keep a forward-looking sentence.
4. **Your no-retro-audit line.** State it: the rule applies **going forward**, and an existing
   claim is corrected only by a work item carrying its own fresh measurement. A sweep that
   rewrites shipped negative claims without new evidence is this same error run in reverse. When a
   census finds already-overtaken promises, **label them and leave them standing** under their
   dated headings — a labelled measurement is the opposite of a silent rewrite.

### Two worked examples from the donor project (anonymized) — the reasons, not the ids

**1. The scope failure, not a rigour failure.** A shipped constant declared that one flavour of
deep link into a document was UI-only: neither constructible nor fetchable. **The evidence behind
it was real and careful** — an exhaustive block-by-block check of a real document found nothing
matching the share-token fragment, and the object-get endpoint refused that token while returning
the object for a genuine id. The claim that grammar grounded was correct and still stands.

The defect was **scope**. The finding generalised into a class-level *"anchors of this kind are
UI-only"*, and the **bare-id fragment form was never tried**. A consumer clicked it; it worked.
Nothing in the review asked the one question that would have caught it — *which forms did you
actually try?* — which is why the remedy is a checklist line, not an exhortation. The consumer's
own ask, endorsed as a ruling, is worth quoting because it is the rule in one sentence:

> *"when declaring something unbuildable, enumerate the forms actually tried… an untested form is
> 'unmeasured,' not 'cannot.'"*

**2. The promise that outlived its truth — why A.1b needed a machine.** A shipped guide section
announced that an editable projection *"may"* arrive in *"a future release"*. It was written while
it was true and it kept shipping long after the two functions that delivered it had landed **in
the same package**; a consumer built the wrong thing on it and reported the mismatch eight
releases later. Their diagnosis is the reason A.1b exists: *"the parts under machine guard stayed
true and the parts written as prose drifted… the hole is in the coverage of the guard, not in the
guard."* One work item fixed the hits on that report's evidence; a second built the guard — and
the second **registered** what already shipped and rewrote nothing, holding the no-retro-audit
line above.
