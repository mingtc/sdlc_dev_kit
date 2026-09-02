<!-- KIT-CLASS: KIT — contract sheet: the configuration seam. See process/EXTRACTION.md. -->
# CONTRACT — the configuration seam

## 1. PURPOSE

To keep everything an adopter must change **in one small, declared place**, so that adopting the
process is an edit rather than an excavation.

## 2. HARD INVARIANTS

- **Every adopter-specific value has exactly ONE authoritative definition.** Identifier prefix,
  publication remote, trunk identity, role set, lifecycle states: each is authored once, and
  every consumer reads it from there.
  *Why:* a value defined twice is a value that will disagree with itself, and the disagreement
  surfaces as a bug in something unrelated.
- **Where a copy is unavoidable, the copy is DERIVED or CHECKED, never retyped.** A second
  statement of a shared value must either be computed from the first or held against it by a
  guard.
  *Why:* retyped values drift silently; a derived one cannot, and a checked one announces itself.
- **A value that anything DERIVES TEXTUALLY is declared in one exact shape:
  `NAME="${NAME:-value}"`, at column 1, whole, on one line.** No leading whitespace, no line
  continuation, no alternative spelling of the same expansion. The shape is part of the contract,
  not a formatting preference, and it binds every file that holds such a declaration — not only
  the seam file.
  *Why:* the bullet above says a copy must be derived or checked, and it does not say what the
  derivation is allowed to assume. So each consumer wrote its own anchored expression, and the
  shape became an undeclared contract between files that never mention each other. **Dropping the
  outer quotes is identical to the shell and invisible to every one of those expressions** — the
  value would keep working perfectly while every derivation of it silently returned nothing. That
  is the whole hazard in one sentence: a change that is *semantically* a no-op is *textually* a
  break, and nothing about the edit looks dangerous.
- **A derivation that comes back EMPTY refuses, naming the file it could not parse. It never
  supplies its own second default.**
  *Why:* a fallback on the degraded path is the most expensive kind of silence — it converts
  "I could not read the declaration" into "the value is `main`", and everything downstream then
  runs correctly against something nobody declared. The refusal is what makes the shape rule
  enforceable at all: a shape that can only be violated *loudly* is a shape a reformat cannot
  quietly break.
- **A configured value is overridable for one invocation without editing anything.** The
  environment may supply it; the declared default applies otherwise.
  *Why:* trying a change should not require a commit, and a sandbox must be able to run the real
  tooling with different values.
- **NO donor-specific value is baked into anything that travels.** A file that travels unedited
  contains no adopter's name, prefix, trunk or paths.
  *Why:* every such literal is a trap the next adopter finds by failure rather than by reading.
- **A DEGRADED path may not carry its own second default.** Where a script can run with the seam
  unavailable, it **refuses and names the seam** — it does not fall back to a literal of its own.
  *Why:* a defensive literal is invisible until the seam breaks, and then it silently targets the
  wrong project. If a fallback truly must exist, it is **one** shared fallback, in one place, and
  it announces itself.
- **Changing a configured value takes effect at the next invocation and NEVER rewrites existing
  records.** History keeps the identifiers it was born with.
  *Why:* rewriting existing records to match a new setting invalidates every reference already
  written to them.
- **Validation lives with the definition.** The rule for what a legal value looks like sits beside
  the value, and every consumer uses that one rule.
  *Why:* a shape enforced in four places is enforced in three places within a year.
- **A configured value that cannot be resolved is announced, never silently defaulted.** If a
  fallback chain exists, its last step still says what it chose.
  *Why:* a silent fallback to somebody else's default is the failure mode with the longest delay
  between cause and symptom.

## 3. REFUSAL CONDITIONS

- A required value is unset and has no declared default ⇒ refuse, naming the value and where to
  set it.
- A supplied value fails the declared shape ⇒ refuse, showing the shape.
- A consumer needs a value the seam does not define ⇒ that is a gap in the seam, and it is fixed
  by adding it there rather than by hard-coding it at the call site.

## 4. WHAT GREEN MEANS

1. Every adopter-specific value used anywhere is **listed in the seam**, with its default.
2. A single override applied at invocation time is **observably honoured** by every consumer.
3. A search of the travelling files for another project's values returns **nothing** — a count,
   run by the adopter, not a promise made by the kit. **The initializer runs that count itself and
   FAILS LOUDLY on a non-zero result**, so this line is an assertion rather than a sentence (§ 6
   names where). *The verb is not "refuses": a refusal means **nothing was written**, and this
   census runs **after** the initializing commit — it reports a bad result, it cannot un-write one.*
   **And it is a floor, not the whole travelling set:** the census spans the stamped role docs and
   templates — the directories the initializer itself writes — which is where a surviving foreign
   value would be its own doing. A value that travelled into a file outside them is **the adopter's
   own search to run** — this contract does not run it for you, and § 6 names where the census is
   implemented if you want to model yours on it.
   Two things make the count honest: every token searched for is **derived from the seam**, never
   retyped; and the count **excludes provenance citations** — an identifier of the form
   *prefix-number* attributing a hard-won lesson is a citation, and rewriting it would manufacture
   a reference the adopter's own history never had. Those are reported and left, not counted.
   **The count likewise excludes the KEY of any convention spelled with the placeholder literal** —
   a classification marker's key is not a surviving placeholder, and a census that counts it refuses
   on the very fix that protects it, so the substitution's exemption and this one are a single
   change or neither holds. *(Authoring site:
   [`../EXTRACTION.md`](../EXTRACTION.md) § The one file classification convention; the obligation
   on the tool is [`initializer.md`](initializer.md) § 2.)*
   *Why this line earned an implementation:* one adoption measured **hundreds** of surviving foreign
   values in files this very sheet promised were clean — the promise was believed by three readers
   and checked by nobody.

## 5. MINIMAL INTERFACE

**In:** declared names with declared defaults; an environment that may override them.
**Out:** resolved values, plus a shared validation entry point for caller-supplied identifiers.
**Not in:** any action. The seam answers questions; it never changes the repository.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/config.sh` — KIT-CLASS: KIT. The prefix knobs, the project-name knob, their
  environment overrides, and the shared identifier validation.
- `scripts/kit-init.sh` — KIT-CLASS: KIT. Stamps the seams (including the role docs and the
  harness templates) and then runs § 4.3's **census**: it derives each placeholder token from the
  seam, counts what survives, and fails when the count is non-zero. That is the promise turned into
  a measurement.
- [`../EXTRACTION.md`](../EXTRACTION.md) § 2 — the full knob table, including the
  publication-remote knob and the trunk-resolution chain that motivates the
  announce-never-default invariant.
- Any known violation of the no-foreign-literal invariant is **declared in that manifest's debt
  list rather than concealed**, which is the posture this contract asks for.
