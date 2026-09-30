<!-- KIT-CLASS: KIT — the corpus manifest's shape, blank. Fill every <angle-bracket>; the format is law. -->
# CORPUS.md — what the requirements corpus IS

> **Pattern vs instance.** This file is **two things at once**, and a stranger cannot tell them
> apart unless you say which is which. The **pattern** — a north-star statement, a manifest that
> can be **enumerated** (a location may be one entry), a bucket classification covering **every**
> root document and top-level directory, a precedence clause, and one guard that reddens when a
> newcomer is unclassified — is **format law and travels**. The **instance** — every path, every
> bucket assignment, the north star's wording, the guard's filename — is **your project's content**
> and travels to nobody. Keep this note in your copy: it is what makes the file imitable.
> *(The same split is stated in [`process/EXTRACTION.md`](../process/EXTRACTION.md) § 1.2.)*

**Fill this file on day one, nearly empty.** A corpus manifest written after the fact is written
from memory, which is the exact failure it exists to prevent.

## The north star

> **<one sentence: what this corpus is FOR>**

<!-- One example of the shape, from the donor project this kit was cut from — not law for you:
     "the requirements corpus should be able to regenerate the product — not deterministically,
      but each artifact class narrows the variance."
     Whatever you write, everything below must be downstream of it. -->

## The manifest — what a reader is allowed to read

A manifest entry **may be a location**: *"everything under `<dir>/`"* is legal where the directory
is the unit. Enumerate only where the set is small and stable.

<!-- FOUR COLUMNS, and each earns its place: `Kind` is `file` or `location`; `Status` is `present`
     or `forward-referenced (<ISSUE-ID>)` — or, on day one, `forward-referenced (SEED step <N>)`
     (see below). `Kind` and `Status` each answer a question the guard asks, so dropping either
     would put the guard ahead of the shape it checks. -->

| Entry | Kind | Status | Why it is corpus |
|---|---|---|---|
| `<path or location>` | `<file\|location>` | `present` | <why this is an input to rebuilding the product> |
| `<path or location>` | `<file\|location>` | `forward-referenced (<PREFIX>-NNN)` | <why, and what will land it> |
| `DECISIONS.md` | `file` | `present` | <the standing rulings — the register that answers "what is true now"> |

**Forward references are allowed and must be MARKED** — the marker is the literal
**`forward-referenced (<ISSUE-ID>)`** in the `Status` column, naming the work item that will land
the entry (e.g. `forward-referenced (XYZ-042)`). An unmarked entry pointing at nothing is
indistinguishable from rot, and the guard below is entitled to fail on it. When the entry lands,
flip `Status` to `present` **in the same change**.

**On day one, name the seed step instead of an id that does not exist yet:**
**`forward-referenced (SEED step <N>)`**, for a row that a later step of
[`process/SEED.md`](../process/SEED.md) lands, such as the first spec. Minting issues only to have
ids for these rows would invent work the seed already sequences. When the step lands the entry, flip
it to `present` in the same change. If a work item takes the entry over first, re-point the marker
at that item's id. **A `SEED step` marker does not outlive day one.** An issue id has state a reader
can check, and a step number does not. So any step marker still standing when day one closes is
re-pointed at an id, or its row is removed. **A guard that parses the marker must accept both
forms, and may reject the step form once day one is done.**

**A row that nothing on day one lands stays out until the item that lands it is minted** — the
`SEED step <N>` form's scope is exactly *"a row a later step lands"*; a row no step lands is not
yet a row. [`process/SEED.md`](../process/SEED.md) § Day one is done when says what closes day one.

**A `location` row buys cheapness at a price: nothing inside it is individually reachable.** That is
usually the right call for a directory that grows with every feature area — but if a reader needs to
find one member by name, the directory gets its own small index (`<dir>/README.md`) rather than a
second copy of the manifest here.

## The bucket classification — every root document, every top-level directory

Every newcomer gets exactly one bucket. **An unclassified newcomer is a hole in the manifest**, and
the only reliable way to notice is a guard that fails.

| Bucket | Meaning |
|---|---|
| `corpus` | An input to rebuilding the product. |
| `ledger` | History. Read to learn *how* it got here, never to learn *what is true now*. |
| `generated` | A projection of something else; never edited by hand. |
| `<your bucket>` | <meaning> |

| Path | Bucket |
|---|---|
| `requirements/` | `corpus` |
| `progress.md` | `ledger` |
| `ARCHIVE.md` | `ledger` |
| `progress/` | `<bucket — the live board is not history and not corpus; decide and say why>` |
| `dev/` | `ledger` |
| `docs/` | `<bucket — reference material this project did not write. A vendor's API guide may genuinely be an input to rebuilding and belong in `corpus`; a stakeholder artifact produced to leave the project is neither. Decide per what you actually keep there, and say why>` |
| `process/` | `<bucket>` |
| `README.md`, `PROJECT.md`, `CLAUDE.md`, `AGENTS.md` | `<bucket>` each |
| `.claude/`, `scripts/`, `consumers/`, `setup.sh`, `.env.example`, `.gitignore` | `<bucket>` each |
| `<your file or dir>` | `<bucket>` |

## Precedence — when two corpus members disagree

<!-- State it once, here. Without it, a contradiction is resolved by whoever noticed it last. -->

`<e.g. the register of standing rulings wins over prose; prose wins over an example; an example
never wins.>`

## The guard

`<your guard's path>` holds this file true **in both directions**: (1) every manifest entry
resolves to a real path unless it is a marked forward reference; (2) every root document and
top-level directory is classified. **A guard in only one direction rots in the other.**

Until that guard exists, say so here in one line rather than leaving the heading to imply one does.

---

## What belongs in a corpus entry — the lessons from an actual regeneration

<!-- FOLDED IN from a regeneration spike in the donor project this kit was cut from: one module was
     rebuilt from the corpus alone and every divergence classified. The whole output was "what the
     corpus failed to capture", which is a lesson about the SHAPE of this file. The lessons travel;
     the donor's own examples do not, and are paraphrased. -->

The donor regenerated one module from its corpus alone and classified every divergence. The format
lessons, in the order they cost the most:

1. **A corpus gap is a MISSING SENTENCE with a HOME.** Record each gap as the exact sentence that
   was absent *and* the document that should have carried it. *"The corpus is thin here"* is not
   actionable; *"`<function>` takes `<arg>`; the parameter names are part of the contract — belongs
   in `<doc>` § `<section>`"* is.
2. **Three classes, not two.** A divergence is (a) **the product is wrong** — the corpus was right
   and nothing caught it; (b) **a corpus gap** — the product is defensible, the corpus never said;
   (c) **merely different** — genuinely undefined, and the corpus should say *that*. Collapsing (b)
   into (c) is how a corpus quietly stops being one.
3. **The things a regenerator gets wrong are boringly specific**, and each is a sentence somebody
   could have written: exact public signatures and parameter *names*; the **verbatim** text of a
   refusal or error a consumer can see; boundary rules stated as counts and character sets (*"an
   exact segment count"*, *"the run ends at the first non-alphanumeric character"*); totality
   (*"this function never raises; a non-string passes through"*); and whether a type is a union
   alias or a base class. Prose invariants that live **only** as test assertions are invisible to
   a reader.
4. **Undefined behaviour must be written down as undefined**, or the next reader pins it by
   accident and a regression test starts asserting a coin-flip.
5. **Anchor by section, not by line**, for any target that still changes; reserve line anchors for
   append-only ledgers. *(Doctrine:
   [`process/doctrine/lookup-tables.md`](../process/doctrine/lookup-tables.md) § A.4.)*
6. **A guard that pins source *formatting* rather than *value* will redden on a correct
   regeneration.** Know which of yours do; that is a property of the guard, not of the product.
   *(The tier that answers this question per test:
   [`process/doctrine/conformance-tier.md`](../process/doctrine/conformance-tier.md).)*
