<!-- KIT-CLASS: KIT — a blank shape. Travels unedited; every angle-bracket blank is yours to fill. -->
<!-- LINKS IN THIS FILE ARE RELATIVE TO WHERE IT LANDS — requirements/ — NOT to the directory it
     sits in. A link written for where the template SITS resolves while you read it here and
     is dead in every copy an adopter makes: it passes a link check run in the kit and fails
     the only reader who matters. The self-test reads this line to know where to resolve from,
     so keep its shape. -->
<!--
  HOW TO USE THIS FILE
  Copy to requirements/CORPUS.md, fill every <angle-bracket> blank, delete the HTML comments.
  Start it on DAY ONE, nearly empty. A corpus manifest written after the fact is written from
  memory, which is the failure it exists to prevent.
  DROP THE KIT-CLASS MARKER. The `KIT-CLASS:` marker
 line at the top classifies this file FOR
  THE KIT (does it travel, and which half). It is kit bookkeeping, not your project's: delete it
  from your copy — or replace it with your own, if you are re-cutting a kit from your repository.
  LINKS are written for this file's DESTINATION, which is requirements/ — so a process/ target is
  spelled `../process/…` and resolves the moment you copy this file there. They therefore do NOT
  resolve while the file still sits in process/templates/, and that is expected, not a defect.
  (PROJECT.md and CLAUDE-adapter.template.md state the same convention for their own
  destination, the repository root, where the same targets are spelled `process/…`.)
-->
# CORPUS.md — what the requirements corpus IS

> **Pattern vs instance.** This file is **two things at once**, and a stranger cannot tell them
> apart unless you say which is which. The **pattern** — a north-star statement, a manifest that
> can be **enumerated** (a location may be one entry), a bucket classification covering **every**
> root document and top-level directory, a precedence clause, and one guard that reddens when a
> newcomer is unclassified — is **format law and travels**. The **instance** — every path, every
> bucket assignment, the north star's wording, the guard's filename — is **your project's content**
> and travels to nobody. Keep this note in your copy: it is what makes the file imitable.
> *(The same split is stated in [`process/EXTRACTION.md`](../process/EXTRACTION.md) § 1.2.)*

## The north star

> **<one sentence: what this corpus is FOR>**

<!-- One EXAMPLE of the shape — not law for you:
     "the requirements corpus should be able to regenerate the product — not deterministically,
      but each artifact class narrows the variance."
     Whatever you write, everything below must be downstream of it. -->

## The manifest — what a reader is allowed to read

A manifest entry **may be a location**: *"everything under `<dir>/`"* is legal where the directory
is the unit. Enumerate only where the set is small and stable.

<!-- FOUR COLUMNS, and each one answers a question a guard asks.
     `Kind` is `file` or `location`. `Status` is `present` or `forward-referenced (<ISSUE-ID>)`. -->

| Entry | Kind | Status | Why it is corpus |
|---|---|---|---|
| `<path or location>` | `<file\|location>` | `present` | <why this is an input to rebuilding the product> |
| `<path or location>` | `<file\|location>` | `forward-referenced (<ISSUE-ID>)` | <why, and what will land it> |

**Forward references are allowed and must be MARKED** — the marker is the literal
**`forward-referenced (<ISSUE-ID>)`** in the `Status` column, naming the work item that will land
the entry (e.g. `forward-referenced (<PREFIX>-042)`). An unmarked entry pointing at nothing is
indistinguishable from rot, and the guard below is entitled to fail on it. When the entry lands,
flip `Status` to `present` **in the same change**.

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
| `<file or dir>` | `<bucket>` |

<!-- ONE ARGUED EDGE CASE WORTH DECIDING EXPLICITLY: the retained-evidence directory (dev/ in a
     stock installation). It is REFERENCED BY corpus documents and is itself a LEDGER — read to
     learn how we came to know, never to learn what is true now. Decide it here, once, rather than
     re-deciding it every time somebody adds a capture. -->

## Precedence — when two corpus members disagree

<!-- State it once, here. Without it, a contradiction is resolved by whoever noticed it last. -->

`<e.g. the register of standing rulings wins over prose; prose wins over an example; an example
never wins.>`

## The guard

`<your guard's path>` holds this file true **in both directions**: (1) every manifest entry
resolves to a real path unless it is a marked forward reference; (2) every root document and
top-level directory is classified. **A guard in only one direction rots in the other.**

---

## What belongs in a corpus entry — the lessons from an actual regeneration

<!-- FOLDED IN from a real regeneration spike, whose whole output was "what the corpus failed to
     capture" — which is a lesson about the SHAPE of this file. Keep the lessons; if you keep these
     lines in your copy, cite your OWN spike's findings document once you have run one.
     The ritual itself: process/doctrine/calibration.md § A.1. -->

One project regenerated a module from its corpus alone and classified every divergence. The format
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
   alias or a base class. Prose invariants that live **only** as test assertions are invisible to a
   reader.
4. **Undefined behaviour must be written down as undefined**, or the next reader pins it by
   accident and a regression test starts asserting a coin-flip.
5. **Anchor by section, not by line**, for any target that still changes; reserve line anchors for
   append-only ledgers. *(Doctrine:
   [`process/doctrine/lookup-tables.md`](../process/doctrine/lookup-tables.md) § A.4.)*
6. **A guard that pins source *formatting* rather than *value* will redden on a correct
   regeneration.** Know which of yours do; that is a property of the guard, not of the product.
   *(The tier that answers this question per test:
   [`process/doctrine/conformance-tier.md`](../process/doctrine/conformance-tier.md).)*
