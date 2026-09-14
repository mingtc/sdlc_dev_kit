<!-- KIT-CLASS: KIT — transferable doctrine. Every section EXCEPT § B is the pattern; § B is the fill-in for YOUR guards. Written as an exclusion, not a list: this line said "§§ A, C, D", § E landed later, and the list was not grown — so an adopter copying by this line left § E behind. -->
# Staleness doctrine — retirement is paid by the change that causes it

**KIT-CLASS: KIT.** **Every section except § B** is the transferable pattern — a project adopts
them verbatim. Stated as an exclusion rather than as a list, because the list form of this sentence
named "§§ A, C, D", § E landed afterwards, and nobody grew it: an adopter reading the list left § E
behind. § B is the **instance**: the specific guards that hold the pattern in *your* repository,
and the specific corpus they run over. This is a
narrower pattern/instance split than [`supersession.md`](supersession.md) or
[`retention.md`](retention.md) use (there, everything under § A is pattern and everything under § B
is instance); here the instance is confined to ONE top-level section — § B — because every other
section is pure statement with no repository-specific mechanics to separate out.

**Why this sheet exists.** Nothing is kept fresh by being revisited. A file goes stale only in the
gap between the event that spent it and the commit that says so — and the census that motivated
this sheet exists **because the sweeps did not happen**. Its sharpest number: of thirteen plan
documents in one directory, eleven had closed, nine carried a closure stamp, and the two that did
not were **the two most recent closures**. The convention does not decay randomly. It decays
exactly at closure time, which is exactly where a guard has to stand.

---

## § A — The obligation (the pattern)

### A.0 — The principle

Many projects already state a version of this for one surface: *"consumer-doc truth is part of
shipping, not a periodic sweep"*. This sheet generalizes it to every document: **retirement truth is
part of the change that causes the retirement.** No file is kept fresh by being revisited. A
periodic sweep is not a fallback for a missed stamp — it is the failure mode this doctrine exists to
remove, by putting the pen in the hand of the person who is already typing.

### A.1 — The four triggers, and who holds the pen at that moment

A retirement stamp is owed at exactly four events. In every case **the author of the causing
change owes it, in the same commit**, as part of that change's Definition of Done. Never a
follow-up work item. Never a sweep.

- **T1 — a successor lands.** Whoever writes a document covering ground an existing document
  covered (a new handoff, a re-taken audit, a replacement plan) stamps the predecessor in the
  same commit. The successor's author is the only person who knows, at that moment, exactly what
  the predecessor no longer answers.
- **T2 — a plan's work closes.** Whoever writes the run report, or lands the last item of a
  slate, stamps the pack or plan that authorized it and names the report. This is usually not a new
  instruction — the launch-pack template already carries it: author the pack `LIVE`, *"stamp it as
  `SPENT` at close"*, **"Stamped against the run report by name"**; § B is what makes the
  instruction **bind**. *Quoted from the template's own two sentences rather than compressed into
  one: a paraphrase inside quotation marks is a citation a reader cannot find in the file it names,
  and this one could not be.*
- **T3 — a ruling overturns a recorded conclusion.** Already governed:
  [`supersession.md`](supersession.md) § A.1 (preserve the reason, replace only the conclusion,
  transform the guard rather than delete it) and § A.2 (the `superseded_in_part` annotation,
  landing **with** the ruling, never in a sweep). This doctrine adds only **scope**: an internal
  working document gets the same treatment a spec gets. The *"same change, never a sweep"* property
  is the property being generalized.
- **T4 — a number or a universal stated in prose stops being true.** See § C.

### A.2 — What a stamp must contain — five fields; the fourth is the one that gets dropped

A stamp is a top-of-file blockquote, above any body text, carrying:

1. **A verdict word**, from a closed set — `SPENT` · `SLATE LANDED` · `RETIRED` ·
   `SUPERSEDED` · `DELIVERED` — as its opening words.
2. **A date** (`YYYY-MM-DD`) of the *causing event*; if the stamp lands later, annotate both
   (*"SLATE LANDED 2026-01-14 (annotated 2026-01-15, `<PREFIX>-225`)"*).
3. **The successor or outcome, by repository path or work-item id.** A stamp that says "superseded"
   without saying by what converts a live pointer into a dead end, and is worse than no stamp.
4. **The surviving-value clause — "kept because …"**: what in this file is still worth reading
   and exists nowhere else. **This is the field authors drop, and it is the field that separates
   an archive from a graveyard.**
5. **A residue clause, where one is owed** — what the stamp does **not** close. A stamp that
   overclaims closure is more harmful than a missing one, because it stops the next reader from
   looking.

A house model, from a real audit document, with all five fields present:

> **SLATE LANDED 2026-01-14 (annotated 2026-01-15, `<PREFIX>-225`).** Every item of the § C
> recommended slate — C1..C4 **and** the C5 stretch — shipped as `<PREFIX>-220`..`<PREFIX>-224`,
> zero bounces. Per-item ids and landing pointers are annotated in § C; the § A verdicts carry a
> LANDED / still-deferred line each. **Nothing below is deleted or rewritten** — this document
> stays the read-only snapshot taken at the audit's commit, so every measurement, locator and
> framing in it is **as-of-audit** and describes the *pre-slate* tree.

Verdict + date (1, 2); the successor ids (3); the surviving value — *"stays the read-only snapshot …
every measurement is as-of-audit"* (4, in the *why keep reading this* register rather than the
literal words "kept because", which other stamps use verbatim); and the residue is carried by
"as-of-audit" — the reader is told not to trust anything here as current (5).

### A.3 — In the file, not only in the index

The stamp goes **in the stamped file**. An index entry marking it retired is a **second,
separate** obligation that does **not** discharge the first: a reader arriving by search, or by
following a citation out of the code paths, never sees the index. This was learned the expensive
way — an index line read "RETIRED, superseded by the standing handoff" while the handoff file
itself carried nothing, and only a guard caught it.

**Corollary, binding on all retirement work: de-indexing is a MOVE, not a delete.** Move the
index entry under a retired heading and **keep the link.** Removing the link reddens the guard that
walks disk → index; deleting the file while the link stands is invisible to that guard — which is
exactly the hole the reverse-direction guard closes (§ B).

### A.4 — The scoping law: a declared domain with a stated exemption, or do not build it

*(Stated in the donor's own enforcement section as "the general rule this doctrine states";
it is a pattern, so it lives here.)*

**No repository-wide freshness or dead-pointer crawler.** This is refuted by measurement, not by
taste: a scan for cited-but-missing paths across one project's board found **~185 by-design false
positives** (red-proof fixtures, historical records accurate *as history*, deliberate forward
references, consumer-side install paths) against **~7 genuinely dead** pointers. A blanket guard
would have reddened the front door and the guard suite to catch seven typos.

So: **every staleness guard names its domain and its exemption**, in the guard, with the reason. And
a scope limit is stated *with its reason* — a rationale-free scope limit is what gets re-litigated
in six weeks as *"why is this only on handoffs?"*.

### A.5 — A stamp guard over a heterogeneous corpus keys on STRUCTURE, never on a word

*(Also stated in the donor's enforcement section as a general rule.)*

A bare-substring check (*does this file contain "retired" or "superseded" anywhere?*) is sound over
a **homogeneous** corpus where that vocabulary is rare in the bodies — a directory of handoffs, say.
Over a **heterogeneous** corpus the identical mechanism produces **false greens**: a file can contain
"retired" or "superseded" as ordinary vocabulary about something else entirely, with no top-of-file
banner about *itself*, and the naive check wrongly calls it marked.

The measured counter-example: a document whose body says *"the earlier advisory bar of ≥90% is
**retired**"* — about an internal coverage target — while its own top-of-file banner carries no
verdict about *itself* at all, and a sibling file explicitly calls it *the latest* baseline, i.e.
the opposite of retired. A bare-substring guard scanning that corpus returns a false PASS.

> **The rule: any stamp guard over a heterogeneous corpus keys on a structured marker at the TOP of
> the file, never on a word appearing anywhere in it. A FALSE GREEN IS WORSE THAN NO GUARD** — it is
> confidence nobody should have.

A corollary for any **citation-graph** guard (*"a plan cited by a report must be stamped"*): resolve
against **files on disk**, not against the citation, so that a legitimately *retired* document
(§ [`retention.md`](retention.md)) does not redden a guard about *unstamped* documents. And exempt
the documents that cite a plan as **in-flight** rather than as evidence it ran — a handoff, a plan of
record — because *"points at scheduled work"* is not *"proof the work happened"*. If you implement
that exemption as a vocabulary check rather than a structural one, **say that it is a heuristic and
name its false-green surface**: a report that *quotes* a live plan's own status line near the
citation will make the guard go quiet. Carrying that as **accepted bounded debt**, re-examined when
the domain next changes, is honest; calling it a structural guarantee is not.

---

## § B — Enforcement: your project's instance — **fill this in**

> **PROJECT INSTANCE.** Nothing here is inherited. Every guard below is *yours*, in your test
> runner, over your corpus. What travels is every section except this one — stated as an
> EXCLUSION so a later section joins the pattern without anyone having to grow a list here.

**What goes here, one entry per guard:** the guard's name and path · its **declared domain** ·
its **stated exemption and the reason** · what it reddens on · and, where the guard is a heuristic
rather than a structural check, its **measured false-green surface** carried as named debt (§ A.5).

Three guards are worth building, in this order, and the third is usually the cheapest:

1. **A homogeneous-corpus stamp guard** — over one directory whose documents are the same kind of
   thing (handoffs, audits), asserting that every file but the newest carries a retirement verdict.
   Keep it narrow **and record why it is narrow** (§ A.4, § A.5).
2. **A closure-pairing guard** — derived from the **citation graph**, never from a maintained
   allowlist, so a new plan-and-report pair enrols itself: for every plan document cited by a
   document that is *evidence it ran*, the cited plan must carry a closure verdict **in its
   top-of-file banner**, checked structurally. Exempt documents that cite the plan as in-flight,
   per § A.5.
3. **The reverse index leg** — every link in your retained area's index must **resolve on disk**.
   This is the direction a retirement sweep breaks (§ A.3's corollary), and it is a few lines.

**Say plainly what you did NOT build, and why.** The donor's list, each refuted or deferred with its
reason, is worth reusing as a starting point: a repository-wide cited-path-exists guard (refuted by
measurement — § A.4); a **wall-clock** staleness guard (*"a plan still live after N days"*) —
time-dependent redness is flaky and punishes long-running work, and the citation-graph form catches
the same misses deterministically; and a completeness guard over the doctrine directory itself —
possible, but its own work item rather than a rider on another.

---

## § C — Numbers in prose: derive, date, or do not state (the pattern)

The staleness a document accumulates in *maintained* prose is overwhelmingly **drifted counts
and false universals**, not wrong reasoning. So the rule is specific, not "keep docs fresh": a
count, a measurement, or a universal quantifier in a document that presents itself as **current**
must be one of three things, never a fourth:

1. **Derived** — inside a generated region held byte-identical to its source by a test. The
   reasoning to write beside such a region: *a generated region is not an assertion anyone could
   get wrong; it is a projection.*
2. **Dated and attributed** — carrying an as-of date plus the tree state or command it was read
   from, so a reader can tell drift from error without re-measuring.
3. **Not stated** — replaced by the ordinal or qualitative claim that stays true ("the largest
   shipped file", "most of the guide"). A precise number bought at the price of going wrong in a
   week is a bad trade in a maintained document.

The fourth thing — **a bare number, or a bare "every/all/none", with no date and no derivation,
in a document claiming to be current** — is a defect.

- **A universal quantifier is a count.** It obeys this rule, and the cheapest compliance is
  almost always to restate it as a **rule to follow** rather than a **fact to trust**: "every
  plan **must** carry a dated completion banner" instead of "every plan **is** stamped."
- **Dated snapshots are exempt by their date, and this is not a loophole — the date IS the
  derivation.** A dated snapshot is *accurate as of its date, kept as background, not maintained*.
  A one-day count drift inside a dated charter is cosmetic; a bare universal in a live index is a
  defect.
- **A COUNT NAMES THE POPULATION IT COUNTED, whenever more than one plausible population exists.**
  Found vs. filtered. All vs. surviving. Declared vs. present. Raised vs. upheld. A number satisfying
  all three forms above — derived, dated, attributed — is still wrong to the reader if they resolve
  *what was counted* differently from the writer, and they usually can, because the axis is exactly
  what a bare noun leaves out.
  *The compliance is cheap and it is the shape this section already uses elsewhere:* **state the axis
  instead of the number.** *"Fifteen found, seven of them cut-blocking"* rather than *"seven false
  claims"*. The reader now knows which question the seven answers, and the fifteen tells them a
  filter ran at all.
  *Where it bites hardest, and this is the half worth remembering:* **in a record that becomes law.**
  A figure in a run report is read once and discarded. A figure in a doctrine sheet, a contract or a
  charter is **quoted onward** — so a mis-resolved population is not one wrong sentence, it is the
  seed of several, each of them now carrying a number nobody can re-derive. *Measured in the donor
  project: one unqualified count in one sheet reached three downstream documents before anyone asked
  which population it named.*
- **A re-measurement PREPENDS; it does not overwrite.** The old figure keeps its date
  ([`supersession.md`](supersession.md) § A.1), because two dated figures are how a reader sees the
  direction of travel.
- **An ENUMERATION of a growing set's members is a census in prose, even with no digit in it.**
  *"Three outcomes: A, B and C"*, *"one of two"*, *"change all five"* — each is a count written as a
  list, and it rots the same way a digit does, on the day somebody adds the fourth outcome or the
  sixth file. **The digit is not what makes a census; the closure is.** So the compliance is the same
  three: **state the axes the members vary along** rather than the members ("every arm that reports
  without deciding", not "arms [b], [c] and [g]"); or **point at the instrument whose output IS the
  list** — the run's own message, the directory listing, the command that derives it; or do not state
  it. *(The reason is the ladder's first rank in
  [`lookup-tables.md`](lookup-tables.md) § A.5 — **a list is a second copy and a second copy rots** —
  which binds prose exactly as it binds a stored index.)*
  **And where a list keeps outrunning itself, the fix is a rule against the SHAPE, not another
  list.** *Measured: four consecutive repairs to one comment block, each closing the enumeration the
  last repair had left open and each outrun by the next member somebody measured — and **two
  different authors wrote them**, the second holding the first's findings. A form that defeats a
  fresh reader who has been told about it is not an author's carelessness; replacing the list is
  re-arming the trap.*
  **THE BOUNDARY: this reaches lists that CLAIM, not lists that BUILD.** A guard's list and a
  sentence's list are assertions about the set — *these are the members* — and they are wrong the
  moment the set grows. **A builder's list is not a claim about anything; it is the thing being
  made.** A fixture that creates six directories is not saying six is all there are.
  **The test that settles it when the role is arguable — and it usually is — is the FAILURE
  DIRECTION: does a divergence here fail loudly, or pass quietly?** A builder that falls behind
  produces something incomplete, and the next thing to use it fails, near the cause. A guard or a
  claim that falls behind goes on answering — blind, or false, and silently. *The direction is
  answerable about a list whose role you cannot classify, which is why it is the test and the
  builder/claim distinction is only the usual shape of the answer.*
  **And the tell that you are looking at a builder: it deliberately includes a non-member of the
  derived set.** A list of the status columns *plus* the rotation directory is not a stale copy of
  the columns — it is a different set, correctly written out, and **"deriving" it would delete the
  member that made it a builder.** *Measured: a sweep applying this rule mechanically was one edit
  away from turning exactly such a list into a defect.*
- **Finding the statement you just outran is a ONE-HOP search, and T4 owes it in the same change.**
  The trigger is easy to accept and easy to skip, because the stale sentence is rarely in the file
  you were editing. One hop reaches almost all of them, and the change already has the operands in
  hand: the counts and universals **in the file you touched**; **anything that CONSUMES the string** you
  changed — searched by its **name**, never by its path, since a path search misses every citation
  that spells it differently. *A matcher is a citer:* a test, a hook, a gate or a parser that matches
  on a string, a heading, a label or a format your prose specifies is one hop away exactly as a
  document is, and it breaks **silently** where a document merely reads wrong. The axis is
  consumption, not prose; and, if the work is running as a phased program, whether this change
  **falsifies a statement a later phase is scheduled to be written against.** That last one is the
  expensive miss: a later phase treats the falsified statement as its specification, so a sweep at
  the end finds it long after it has been built on. *(The corpus-wide half — the surfaces no diff
  touched, which one hop structurally cannot reach — is a separate obligation:
  [`fix-execution.md`](fix-execution.md) § A.4.)*

**Where this section's reader cannot open the source.** Everything above assumes a reader who can go
and re-derive the number. Where the number is in a **product's output**, read by someone with no
access to the evidence, [`consumer-output.md`](consumer-output.md) carries the additional duties —
per-item read-vs-derived marking, and preferring the decomposed figure the reader can trace over the
combined one they must trust.

## § D — Who pays, stated as a rule (the pattern)

- **The Definition of Done for any change that lands a successor document, closes a plan, or
  overturns a recorded conclusion includes the predecessor's stamp, in the same commit.** These
  files are metadata, so the stamp commits **direct to `<trunk>`** (the adapter's code-vs-metadata
  rule): no branch, no work item, no ceremony. The marginal cost is one blockquote.
- **No retirement backlog and no retirement sweep.** A stamp not paid at the causing change is
  not scheduled — it is owed by the **next** change that touches the file, and until then it
  stands as **measured debt**: a guard's redness is that debt made visible instead of accumulated
  silently.
- **A guard, not a habit, wherever a guard can see the obligation.** Where it cannot (the
  surviving-value clause, the residue clause), the doctrine states the form and the reviewer
  checks it — this doctrine does not pretend a convention is enforcement. An unenforced convention
  decays exactly at the moment of closure, which is the whole argument for putting the load on the
  causing change rather than a later sweep.

**The standing debt a hygiene pass makes visible.** [`../hygiene-checklist.md`](../hygiene-checklist.md)
and its advisory instruments exist to make standing debt *visible*, and **they do not reinstate the
sweep this section abolishes**: the checklist **creates no retirement backlog**. What a pass finds is
still paid by the change that lands the fix, under § D's rule above — a pass produces a **report, not
a queue**, and a report nobody acts on costs nothing but the run. It fails no build: no guard, no
gate, no arm of the gate runner.

**On adopting this doctrine into an existing repository: retro-stamps are NOT the adoption cost.**
Gating adoption on sweeping every existing file would make the doctrine wait on the exact activity
it abolishes. § D's rule is what collects the remainder — each file gets its stamp the next time it
is touched, with the guards' redness standing as the visible debt in the meantime. When you measure
the backlog, **date the figure** (§ C): the donor's own count moved within a day of being taken,
which is precisely the drift § C exists to stop being asserted as a bare fact.

## § E — Three claim classes a document audit does not look at (the pattern)

§ C is about **numbers** in prose. These three are the other claims a shipped document makes that
have mechanical truth conditions — and each one survives the lens usually pointed at documents,
because that lens is looking for something harder. All three were reported by an adopter who found
them the expensive way, in a release document, across five consecutive audit passes.

### E.1 — A QUOTATION IS A PROMISE ABOUT BYTES, and it is the cheapest claim in any document to check

A quotation asserts that a named document contains a string. That is grep-checkable in one command,
which makes it the cheapest claim to verify — and therefore the one nobody verifies, because an
audit's attention goes to the figures and the logic.

**The two shapes a fabricated quotation takes, both fluent, both attributed to a real document that
says something adjacent:**

- **THE WELD.** The source gives a fact in one clause and its reason in a parenthesis. Prose splices
  them with a `because` and presents the weld as a quotation. Nobody misread the source; the
  sentence was **assembled from true pieces into a false attribution**, and a literal grep for the
  spliced form returns 0.
- **THE CITATION THAT DOES NOT SUPPORT ITS CLAIM.** The quoted span is real and verbatim, and it is
  evidence for a **different proposition** than the one it is offered for.

**THE CURE — a MISQUOTE CENSUS, as a numbered deliverable.** Extract every quoted span in the
section under audit; decide for each whether it claims a source in the repository; grep-verify each
that does; **report three numbers — how many quotes, how many verified, how many could not be
located.** A census that returns numbers cannot be silently skipped the way *"I checked the quotes"*
can. Run it flattened (§ E.2) with a control needle proved to return zero.

**And the drafting rule that removes the class at the source:** *prefer a paraphrase you can defend
to a quotation you have not checked.* An unquoted paraphrase makes a weaker claim and is honest at
the weaker strength. **Quotation marks are a promise about bytes.**

### E.2 — CENSUS THE DEFECT STRING, NEVER THE DOCUMENT YOU HAPPEN TO BE EDITING

A correction pass inherits its scope from the audit that raised the defect — *"two documents"* — and
that scope is wrong, because **the defect was never a document's. It was a sentence that had been
copied.** Its copies cross lane boundaries that nothing in the process connects, because the
connection is semantic rather than structural: prose in `*.md` is one lane, the same prose in a
source docstring, a test docstring, a comment, or a script's header block is another.

Measured by an adopter: a fix removed two defective sentences from the two documents under audit;
the next pass found both **still present, string for string, in a shipped source module**. The
artifact would have shipped two of its own members contradicting each other at one tag, with no way
for a reader to resolve it from inside.

**So: when a correction pass removes a defective claim, census the exact string tree-wide before
declaring the class swept** — including the lanes you were not auditing.

**Two riders, both learned the same day:**

1. **Census on whitespace-FLATTENED text.** The same paragraph read `0` for a line-anchored needle
   and `1` flattened, because the phrase wrapped a line break. A line-anchored grep is right for a
   freeze check and **wrong for a string census**.
2. **Prove the fix in the ARTIFACT, not the tree.** A stale build directory can make a packager ship
   a cached member, so a source fix can be invisible to the thing that ships.

### E.3 — A SCOPE WORD IS A CLAIM ABOUT THE DOCUMENT'S OWN LAYOUT, and only rendering checks it

*"The bullet above"*, *"this paragraph"*, *"the three items below"*, *"forty lines above"*, *"the
table in this section"* — each is a **factual claim about the document's structure at the point the
reader arrives**, and each is falsifiable, because an edit elsewhere can move, merge, split or
renumber the referent without touching the sentence that refers to it.

**Why it survives every lens usually applied.** A figure audit checks numbers against measurements.
A misquote census (§ E.1) checks strings against sources. A link check resolves targets. **None of
them looks at a scope word, because its referent is not in the text — it is in the LAYOUT.** The
sentence stays literally intact while becoming false, and it reads perfectly in the diff, in the
source, and in every check that reads the file as text.

**The cure that actually works: render it and look.** Parse the section, resolve what *above* and
*below* denote at that position, and compare. Cheaper approximations when full rendering is not
available: assert the referent's **type** (is there in fact a bullet list immediately preceding?)
and its **count** (does *"the three items below"* precede exactly three?).

**And the drafting rule: name the structure, do not count the distance.** *"§ 6's bullet"* survives
an edit that *"forty lines below"* does not. **The better the prose, the more of these claims it
carries** — they are exactly how a careful writer makes a long document navigable, which is why
this class scales with quality rather than against it.
