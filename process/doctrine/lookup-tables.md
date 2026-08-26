<!-- KIT-CLASS: KIT — transferable doctrine. § A is the pattern; § B is the fill-in for YOUR measured documents. -->
# The lookup-table doctrine — a large consulted document is ADDRESSED, not read

**KIT-CLASS: KIT.** § A is the transferable pattern; § B is where **your** project records which of
its documents owe an index, measured.

**Neighbour sheets.** [`supersession.md`](supersession.md) governs amending any ruling this sheet
touches. [`negative-claims.md`](negative-claims.md) is the authoring-time neighbour for the opposite
failure mode — a shipped claim that overreaches its evidence; this sheet is about a claim (an index)
that must not overreach its own budget. [`staleness.md`](staleness.md) § C is the rule every number
in an index obeys.

**Why this is written at all.** A document nobody can afford to open answers no question. Every
worker that lands there pays the same tax twice: once reading a file whole to find one fact, and
once more when it gives up and searches blind, which returns a match with no way to tell which
section it sits in. Most repositories solve this two or three times, ad hoc, per file — a derived
section index here, a guard-kept link index there, stable ids in a third place — and never write the
pattern down, so the fourth and fifth large document get built without it. This sheet is the
pattern.

---

## § A — The pattern

### A.1 — Where an index is mandatory (the trigger, as two checkable numbers)

A file owes an index when **both** hold:

1. **It is in the consulted corpus** — named by path or by accessor from the adapter, the project
   doc, `process/MANUAL.md`, `process/doctrine/**`, or any role doc. This is **derived by a walk,
   never hand-listed**: a hand-listed corpus cannot notice a file it was never told about. A dated
   record cited once for one fact is **not** in the corpus and owes nothing.
2. **It is ≥ 32,768 bytes.** Reuse the constant your drift report already carries for log rotation
   (the log-size threshold named at the top of the drift-report implementation — a seam, per
   [`../contracts/drift-report.md`](../contracts/drift-report.md) § 6 — calibrated there as *"≈ ~8k
   tokens of every session's start budget"*). **Do not mint a second threshold** — a project that
   carries two numbers for one idea will drift them.

**Plus a role trigger, at any size:** a file a role doc names as a **mandatory read** owes an
index whatever its size, because that cost is paid every session rather than per lookup.

*(A doctrine sheet is addressed, never loaded at session start, so a sheet crossing the byte
threshold triggers nothing — condition 1 is unmet, and both conditions are required.)*

### A.2 — The index budget, and why the entry cap and the split point derive from it

**The index itself gets one budget: 32,768 bytes** — the same number, because the index is the
thing that must fit in one read. Everything else falls out of it:

- **Entry cap = 32,768 ÷ n**, where *n* is the number of addressable units. An entry over cap is
  a defect in the *index*, not a virtue of the entry.
- **Entry floor = 80 bytes** — below that an entry cannot carry a hook (id + what it is + why you
  would open it).
- **Therefore an index may hold at most 409 entries** (32,768 ÷ 80). Past that, shrinking entries
  cannot save it: **the index SPLITS into child indexes rather than growing.** A row whose
  subject outgrows the cap becomes a one-line hook pointing at a child index in the subject's own
  directory.

An index fails one of two ways, never one style: by **entry size** (few members, essays for
rows) or by **entry count** (too many members for any useful row). One division diagnoses both
and prescribes opposite fixes: **shorten, versus split.**

### A.3 — What an entry contains (the hook), and the ban on superlatives

Exactly enough to decide **whether to open the target, without opening it** — and nothing that
would be a second copy of the target:

`<stable address> · <what it is, one clause> · <the question it answers or the failure it cures>`

**Name the row after the failure it cures, not the subject it covers.** This is measured, not
stylistic: one project's shipped guide index is named that way because **eight independent
consumer-dogfood runs** recorded the same defect — the document was too big to read and the index
*"was found second, by luck"*. A row that says what breaks is scanned by symptom; a row that says
what a document is about is scanned by hope.

**A superlative may never be prose in an index.** "The newest", "the current", "today" are the
claims that rot, and no guard can catch them — a prose claim is not a broken link. The proof:
one index called a twelve-day-old document "the newest" while the *same file's* own opening lines
correctly named a later one — self-contradictory inside one file, four documents and twelve days
stale — **and the link guard was green over it**, because a link guard checks existence, not prose
truth. **State a DATE and a COUNT instead.** "1,161,669 B as of 2026-01-19" survives being read a
year later; "the biggest file" does not.

### A.4 — The stable-address requirement

**An index row addresses its target by an identifier that survives an edit above it. A bare
`file:line` is not an address.** Four precedents, three ruled and one measured:

- **Ruled, docs side** — prefer a **section/rule anchor** over a bare `file:line` range into any
  target that still evolves; a line anchor drifts silently on the next edit above it.
- **Ruled, id side** — a stable id is a **permanent handle**: when a ruling is removed the id is
  **retired, never reused**, so a citation elsewhere can never silently come to mean something
  else ([`../templates/DECISIONS.skeleton.md`](../templates/DECISIONS.skeleton.md) states this as
  format law).
- **Ruled, code side** — a write engine whose anchors were quote-only was changed to address by
  object id, because round-tripping a verbatim quote copied out of a fresh read is *"needless
  indirection **and** a staleness risk"*. Positional and textual addressing lost to id addressing
  inside real code before this sheet existed; a line number in prose is the same mistake.
- **Measured** — HTML-comment markers survived **24 real LLM edit trials over 302 markers, zero
  dropped, failure rate 0.0**. That is the one address form whose survival anybody has put a number
  on.

**Derived slug or declared marker — pick by measurement, not taste.** Derive the address from the
document's own headings where they are already unique (the shape that needs no authoring
discipline). Where they are not, the document carries **declared markers** and the index projects
them. Either way, **the collision rule holds**: two units deriving the same address **REFUSE at
index-build time** rather than serving one of them silently. The reasoning to write beside that
refusal: *a document edit that creates two identical section names is a defect — every later call
naming that address would silently receive one of two sections, with nothing to tell it which.*

### A.5 — Generated over hand-kept, in a five-rank preference order

Strongest first:

1. **Derived at call time from the target itself.** No stored index at all. *"There is no list of
   section names in this package … because **a list is a second copy and a second copy rots**."*
   Editing the document is the only way to change the index; no code change is needed.
2. **Generated into a region held byte-identical by a guard.** The value is authored in exactly one
   place and every document view of it is a projection — *"so a value cannot be typed into a
   document and quietly disagree with the code."*
3. **Hand-kept but held complete in both directions by a guard** — index rows ↔ real members, both
   ways.
4. **Hand-kept, one direction guarded** — tolerated only with a named reason in-file, because it
   is blind to exactly the shape a retirement sweep produces
   ([`staleness.md`](staleness.md) § A.3).
5. **Hand-kept, unguarded** — permitted only for a table under 10 rows that a single seat rewrites
   in one sitting, carrying a dated `LAST-VERIFIED` line. It will rot; the line is what makes the
   rot visible.

**A guard over an index is scoped, never blanket** — the same scoping law as
[`staleness.md`](staleness.md) § A.4, measured on the same tree at **~185 false positives against
~7 true findings**. An index guard names its corpus and carries reasoned exemptions, or it is not
built.

### A.6 — An index is not a diet

Rotation, archiving and retirement bound **what a session must hold**. An index bounds **what a
lookup must read.** They are orthogonal in what they measure, and neither substitutes for the
other — but in steady state they are **mutually reinforcing**: rotation keeps an index's
membership under the 409-entry ceiling, and a stable-address index is what makes rotation *safe*,
because a unit addressed by a marker still resolves after being moved to another file, while
every line anchor into it breaks at once. **A file created by rotation inherits the trigger**: the
overflow target owes its own index by A.1, or the problem has been exported rather than solved.

**This clause is load-bearing and must be unambiguous: nobody may be told the index means rotation
can wait, nor the reverse.**

---

## § B — Your project's instance — **fill this in**

> **PROJECT INSTANCE.** Nothing here is inherited. On day one no document is large enough and this
> section correctly holds only its own measurement command.

**What goes here:**

1. **A measured table** — one row per document, with its **byte size**, its **read cost**, and
   whether it **has an index**. Take it with a command and **quote the command and the date**
   (§ A.3, [`staleness.md`](staleness.md) § C). A convenient read-cost rate is 4 bytes/token; if
   your drift report already calibrates one, reuse that rather than inventing a second.
2. **Per document that owes an index: the arithmetic.** *n* (addressable units), the derived entry
   cap (32,768 ÷ *n*), how many rows are over it, and therefore whether the fix is **shorten** or
   **split** (§ A.2).
3. **The addressing decision per document** — derived slug or declared marker, and *why* (§ A.4).
   Where derivation collides or leaves units unaddressable, say what fraction and pick markers.
4. **The rank you achieved** on § A.5's ladder, per index, and — where you are at rank 4 or 5 —
   **the named reason in the file itself**.
5. **The citation debt.** Count the **bare `file:line` citations** into every document you plan to
   rotate or split, with the command. Those are the pointers that break simultaneously at the next
   rotation, and counting them is what turns a silent breakage into a one-time re-point.
6. **What you did NOT build, and why** — deferred index work belongs in your deferred-work queue
   with an origin, a size, a deferral reason and a wake condition. A guard that would be **red on
   arrival by design** (because the diet it demands has not happened) is *queued*, not landed.

### A worked example from the donor project (anonymized) — five measurements, five lessons

Each figure below was measured on one tree on one date; **none of them are yours**, and each is kept
because it is the evidence for a rule in § A.

1. **The tax is per-session, and it was already being paid wrong.** The largest document in the
   repository — a running activity log of ~1.16 MB, about 290k tokens — had **no index** and was a
   **mandated read** in the implementer's role doc. Nobody read it, so the coping strategy was a
   fixed-size tail — and `tail -50 | grep -c '^## '` returned **0**: the tail did not contain a
   single section heading, so a reader had no way to tell which session anything belonged to. The
   role trigger in § A.1 exists because of this row.
2. **Larger and cheaper, together, is the whole argument.** The second-largest file in the same
   tree — a ~758 KB shipped guide — was the **cheapest to consult**, because its accessor answered
   with a derived index of about 10 KB: a **~70:1** ratio, rows named after the failure each
   section cures, collisions refusing at build time. It became the accessor's **default** by ruling
   after eight independent dogfood runs asked for it.
3. **The two failure modes are different, and one division diagnoses both.** The retained-evidence
   index was the **entry-size** case: 94 top-level rows holding 97% of a 120 KB file, mean row 1,245
   B against a derived cap of 348 B — **79 of 94 rows over cap**, and the largest single row ~12 KB.
   The board's archive index was the **entry-count** case: **493 entries against the 409 ceiling**,
   i.e. 66 B/entry, below the 80 B floor — so no amount of shortening saves it and it must split.
   Fixing the first by deleting entries would destroy the evidence index for no gain; fixing the
   second by shortening rows to 66 B would destroy the hooks.
4. **Rot is structural, not a discipline failure.** In the same window a retirement sweep removed
   fifteen rows from that index, it **grew by ~6.4 KB** — because every surviving row accreted
   closure-stamp prose. The person who writes an index row is the person who just finished the work
   and knows the most about it, writing into the file everyone reads. Rows grow. That is the
   argument for § A.5's preference order, not an argument for trying harder.
5. **Stable addressing is what makes the rest of the cleanup machinery safe.** **54 bare
   `<file>:<line>` citations** into the running log existed across 22 files, every one resolving,
   every one due to die at the next log rotation, with no guard watching. Seven of them sat inside
   the decision register itself and **three had already drifted by 14 lines** — the exact failure
   § A.4 names — and were re-pointed at the register's own stable ids instead. The index does not
   make rotation cheaper; it makes it **safe to run** rather than cheap to skip.

**Two cross-reference lessons from writing that instance, worth keeping.** First: when a sheet cites
a *neighbour sheet* for a constant's lineage, check that the neighbour actually contains it — a
sheet citing a section that does not exist is the same defect as a bare `file:line`, and both were
found in the donor's own copy of this document. Second: **an entry that a test reads verbatim must
not be reshaped by a diet pass.** Where a guard pins specific words *inside* an index row, say so in
§ B by name; a future worker shortening rows will otherwise move those words into a child index one
hop away and redden a guard they never knew existed.
