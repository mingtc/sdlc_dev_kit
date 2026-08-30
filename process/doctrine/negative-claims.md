<!-- KIT-CLASS: KIT — transferable doctrine. § A is the pattern; § B is the fill-in for YOUR incidents and wiring. -->
# Negative-claim doctrine — enumerate the attempts, or say "unmeasured"

**KIT-CLASS: KIT.** Promoted after a shipped negative claim over-reached its evidence; § A carries
the rule and the ones that grew out of it — *its own headings are the list, which is why no count
is written here. This line said "one rule" while § A held its mirror rule and a detection-recipe
rule besides.*
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

**How to adopt:** § A is project-agnostic; take it verbatim, **both rules**. Wire them into the
two places a claim passes through in your own process — the implementer's definition of done,
and the reviewer's checklist — as one line each. The doctrine is worthless as a document nobody
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

---

## B. Your project's instance — **fill this in**

> **PROJECT INSTANCE from here down.** Nothing here is inherited.

**What goes here, and nothing else:**

1. **Your motivating incident**, if you have one — what was claimed, what evidence it rested on,
   and which axis the claim exceeded. Keep the good half: a well-scoped enumeration is not
   discredited by the over-generalisation stacked on top of it.
2. **Where A.1 and A.1b are wired**, one line each: the implementer's Definition of Done, the
   reviewer's cross-cut checks, and the spike's probe-evidence rule.
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
