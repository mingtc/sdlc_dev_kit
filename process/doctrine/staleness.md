<!-- KIT-CLASS: KIT — transferable doctrine. §§ A, C, D are the pattern; § B is the fill-in for YOUR guards. -->
# Staleness doctrine — retirement is paid by the change that causes it

**KIT-CLASS: KIT.** § A (the obligation), § C (numbers in prose) and § D (who pays) are the
transferable pattern — a project adopts them verbatim. § B is the **instance**: the specific guards
that hold the pattern in *your* repository, and the specific corpus they run over. This is a
narrower pattern/instance split than [`supersession.md`](supersession.md) or
[`retention.md`](retention.md) use (there, everything under § A is pattern and everything under § B
is instance); here the instance is confined to one of four top-level sections, because three of the
four are pure statement with no repository-specific mechanics to separate out.

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
  instruction — the launch-pack template already says *"stamp SPENT with the run-report name when
  closed"*; § B is what makes the instruction **bind**.
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
> runner, over your corpus. What travels is §§ A, C, D.

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
- **Finding the statement you just outran is a ONE-HOP search, and T4 owes it in the same change.**
  The trigger is easy to accept and easy to skip, because the stale sentence is rarely in the file
  you were editing. One hop reaches almost all of them, and the change already has the operands in
  hand: the counts and universals **in the file you touched**; the documents that **cite what you
  changed** — searched by its **name**, never by its path, since a path search misses every citation
  that spells it differently; and, if the work is running as a phased program, whether this change
  **falsifies a statement a later phase is scheduled to be written against.** That last one is the
  expensive miss: a later phase treats the falsified statement as its specification, so a sweep at
  the end finds it long after it has been built on. *(The corpus-wide half — the surfaces no diff
  touched, which one hop structurally cannot reach — is a separate obligation:
  [`fix-execution.md`](fix-execution.md) § A.4.)*

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
