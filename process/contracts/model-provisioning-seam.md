<!-- KIT-CLASS: KIT — contract sheet: the model-provisioning seam. See process/EXTRACTION.md. -->
# CONTRACT — the model-provisioning seam

## 1. PURPOSE

A model tier is set in more than one place. A change made in only one of them is not a
re-provisioning; it is a new disagreement between a worker's pin and what the project's own
ladder and tooling still expect. This contract is what "changed" must mean.

## 2. HARD INVARIANTS

- **A work class has exactly one (model, effort) pair, and every place that pair is written
  agrees.** Where a leaf-worker definition exists for the class, its frontmatter pin; where the
  ladder documents the class, its row.
  *Why:* a class set in one place and read from another is how a re-provisioning silently
  half-happens — measured directly (§ B below).
- **The ladder is the authority; the pins and the runner default follow it, never the reverse.**
  Setting a class writes the ladder's row and the pin(s) together, in the same act.
  *Why:* a pin edited without its row, or a row filled without its pin, is exactly the
  disagreement this contract exists to prevent.
- **A declared carve-out is never silently overwritten.** A definition the kit's own declaration
  names as a deliberate exception (`process/EXTRACTION.md`'s pin table) is left alone unless the
  caller names it explicitly.
  *Why:* the exception records an intent ("this role is parked"), not an oversight; a blanket
  rewrite would erase the distinction the declaration exists to keep.
- **A class the project's ladder does not name is refused, not guessed.** The mechanism reads the
  ladder to learn which classes exist; it does not invent one.
  *Why:* a work class is a project decision (`model-provisioning.md` § A.2); a tool that accepts
  any string silently grows the ladder by typo.
- **The runner default is its own target, not a row.** `defaultModel`/`defaultEffort` provisions
  any UNTYPED leg regardless of which class it turns out to be, so it is set on its own, or
  together with every class in one pass — never inferred from a single class's value.
  *Why:* the runners hold one pair each, not one per class; reading it off whichever class was
  last touched would make the fallback depend on call order.

## 3. REFUSAL CONDITIONS

- The named class does not appear in the project's ladder ⇒ refuse, naming the classes the ladder
  does declare.
- The model or effort value is empty ⇒ refuse; a blank pin is worse than the placeholder it
  replaces.
- A target file the mechanism must edit is missing or unreadable ⇒ refuse naming the path, rather
  than silently touching only the files that do exist.

## 4. WHAT GREEN MEANS

1. For a set class: its agent pin file(s) and its ladder row carry the same (model, effort) pair.
2. A declared carve-out is unchanged unless named explicitly.
3. For a runner-default set: both workflow runners carry the same pair.
4. Running the same set again is a no-op: nothing changes on the second call.

## 5. MINIMAL INTERFACE

**In:** a work class name (or "every class", or "the runner default"), a model tier, an effort
tier.
**Out:** the pin file(s), ladder row and/or runner defaults for that target, rewritten to agree;
or a refusal naming the class the ladder does not have.
**Not in:** ratifying the ladder — a human still owns that decision
(`model-provisioning.md` § B.2); this seam only keeps what is written from disagreeing with
itself.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/set-models.sh` — KIT-CLASS: KIT. Reads the ladder row labels from
  `.claude/roles/orchestrator.md`, writes the matching agent pin(s) under `.claude/agents/`, the
  ladder row, and — for `--all` or `--runners` — `defaultModel`/`defaultEffort` in
  `.claude/workflows/wave-runner.js` and `.claude/workflows/tranche-runner.js`.
- The self-test's `case_agent_model_pins_match_their_declaration`
  (`scripts/test/cases/runners.sh`) is the consistency check this contract's § 2 invariants are
  measured by, distinguishing the shipped tree (asserts the kit's own declared pattern) from an
  adopted one (asserts agreement with the project's own ladder, or N/A while it is unfilled).
