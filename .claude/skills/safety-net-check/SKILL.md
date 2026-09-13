---
name: safety-net-check
description: Use per refactor target before any moves happen — verify the test suite catches behavior changes the planned moves risk, add characterization tests for gaps, tag a baseline commit
---

# Safety-Net Check

## Overview

"All tests pass" only means "tests don't currently fail." It does not mean "tests would scream if behavior accidentally moved." A refactor pass is *N behavior-preserving moves* — if any test gap matches any move's blast radius, behavior can silently break without a red CI.

This skill's job: before any refactor move on a target, verify the safety net is dense enough.

**Core principle:** No moves on a target until either (a) tests already cover the behaviors the moves will touch, or (b) characterization tests are added to fill the gap, or (c) the target is deferred because the test investment is too large to fit in this pass.

This skill is intentionally **lightweight**. It uses the test framework the project already has — no new infrastructure. Mutation testing is an optional escalation, not a default.

## When to Use

Use per target, after `refactor-planning` produces a move sequence, before any code is touched.

**Don't skip when:**

- The target's code "was TDD'd, so it must be covered" — TDD coverage is for the behaviors the original tests were written for, not necessarily for every behavior a refactor might touch
- The team is in a hurry — skipping this check is how silent behavior breaks land
- The target is "obviously low-risk" — obvious-risk assessments are how regressions ship

**You can skip when:**

- The target is a pure rename with no logic change AND your tooling (compiler, IDE rename) can perform the rename mechanically — the compiler is the safety net
- The target is dead-code deletion with deterministic dead-code detection (e.g. `ts-prune` + green build) — the absence of callers is the safety net

## Phase 1: Run the Baseline

Before scoring anything, the suite has to be green on the default branch right now.

```
git switch <trunk>
git pull --ff-only
<project's full test command>
```

If anything is red — even unrelated to your target — STOP. The refactor pass cannot start with a red baseline. Triage the red tests first (fix or revert), then return.

Tag a baseline commit:

```
git tag "refactor-baseline-$(date -u +%Y%m%dT%H%M%SZ)"
```

**The timestamp is not decoration.** A date-only tag collides the second time anyone runs this on
the same day — `git tag` refuses, and the run continues without a revert point, so **the case with
no safety net is exactly the case where two refactors are in flight at once.** (This kit measured
the identical failure in its own `scripts/archive-progress.sh`: a second same-day rotation hit "tag
already exists" and silently skipped its revert-safety tag.) UTC deliberately — this is an instant,
not a calendar day, and a local clock crossing a DST boundary can hand out the same second twice.

**Record the tag you actually created** in the assessment output; with a timestamp in the name you
can no longer reconstruct it from the date.

This makes reverting an off-the-rails refactor one command: `git reset --hard refactor-baseline-<UTC instant>`.

## Phase 2: Test Inventory for the Target

List every test that exercises the target's code.

**Approach 1: coverage tooling.** If the project has coverage reporting (`vitest --coverage`, `pytest-cov`, `jest --coverage`, etc.), run it and read which tests touch the target's files. Most precise.

**Approach 2: manual import grep.** If coverage tooling isn't set up, grep test files for references to the target's modules. **WRITE THE PATTERN AND THE FILE FILTER FOR YOUR OWN STACK** — the shape below is a JavaScript/TypeScript example, not a portable command:

```
grep -r "from.*<target-module>" --include="*.test.*" --include="*.spec.*"
```

*Run as written on a Python, Go, Rust or Java project it matches nothing — the import keyword is wrong and so are the filename globs — and an empty result here is read one line below as a finding about the project. Adapt both halves first: your language's import/include syntax, and whatever your tests are actually named (`test_*.py`, `*_test.go`, `*Test.java`, `tests/**`).*

**AN EMPTY RESULT IS ONLY A FINDING ONCE YOU HAVE CONFIRMED THE COMMAND CAN FIND ANYTHING.** Point it at a module you KNOW is tested; if that comes back empty too, the pattern is wrong and you have measured your grep, not the project's safety net.

Less precise — captures tests that *could* exercise the target, not necessarily ones that *do*. Good enough for the inventory; supplement with judgment.

**Approach 3: read the test files near the target.** A `foo.ts` usually has a sibling `foo.test.ts`. Read that file. Check what it asserts vs. what `foo.ts` does.

Output: a list of test files (and ideally test names) that cover this target. If the list is suspiciously short or empty, that itself is the most important finding of this phase.

## Phase 3: Identify Behavior Gaps

For each move in the planned sequence, ask: *what behavior would change if this move went wrong, and does any test exist that would fail if that happened?*

Common gap categories:

| Gap category | Why it's invisible to typical tests | Refactor risk |
| --- | --- | --- |
| **Error message wording** | Tests usually assert error type, not message text | A refactor that reshapes errors silently changes text downstream may parse |
| **Response field order** | Tests check field values, not ordering | Reshape of response builders can change order |
| **Defaults applied when input is omitted** | Tests pass explicit values | Refactor of default-handling can change which default applies |
| **Logging output** | Tests rarely assert log lines | Refactor of logging structure can break observability |
| **Side-effect ordering** | Tests check end state, not the sequence of side effects | Refactor of orchestration code can change order even with same end state |
| **Slug / URL / public identifier forms** | Tests use exemplars, not exhaustive forms | Refactor that touches slug generation can change form for cases not in tests |
| **Empty-input / boundary cases** | TDD tends to cover happy paths | Refactor can change empty/null/zero handling |
| **Implicit contract from naming** | A field named `created_at_ms` implicitly contracts milliseconds; tests may not assert the unit | Refactor that "simplifies" to `created_at` may change semantics |

For each gap, decide one of:

### Option A — Add a characterization test

A characterization test asserts *current* behavior, not *correct* behavior. It's allowed to encode bugs — it's documenting the contract that exists today, warts and all.

```typescript
// Characterization test — pins current behavior.
// If this fails after a refactor, behavior changed even though no AC changed.
test("createThing with empty slug returns 400 with 'slug required' message", () => {
  // ...
});
```

Name characterization tests clearly so future readers know what they're for. Add them using the project's existing framework — *no new test infrastructure*.

### Option B — Declare the gap intentionally unconstrained

Sometimes a behavior really is incidental and refactor is free to change it. Example: log format, internal field naming in private types. Document the decision in the refactor pass doc so reviewers know it was a choice, not an oversight. Pass through to the kanban issue's "Intentionally unconstrained" section so Dev and QA know not to defend it.

### Option C — Defer the target

If the gap is wide and characterization would require disproportionate investment, defer the target. Two sub-options:

- Move the target to LOW in the audit's Target List, with a note: "Defer until test investment can support a safe refactor pass."
- Carve out a smaller subset of the original target that *is* safely refactorable; refactor that subset, leave the rest for later.

## Phase 4: Add the Characterization Tests

For each gap on Option A:

1. **Write the test** asserting current behavior. Run it — it should pass (because it asserts what's already true).
2. **Briefly verify the test is real:** temporarily change the production code to break the asserted behavior. The test should fail. Revert.
3. **Land the test on the trunk BEFORE the refactor branch exists** — as its own small change,
   through whatever route your adapter's code paths require. **In most projects the test tree IS a
   code path**, so that means its own branch and the landing gate, not a direct-to-trunk commit;
   this step used to say "commit the test on the default branch", which instructs a Refactorer to
   push code straight to the trunk and contradicts the code-vs-metadata rule in
   `process/MANUAL.md`. Check your adapter before choosing the route. Prefix `[Refactorer]`, matching the role tag, and a message like `[Refactorer] <PREFIX>-NNN: characterization test for <behavior>`.

These tests land *before* the refactor branch is created. They protect the upcoming work.

> **Why land them first, rather than inside the refactor branch?** The characterization tests are part of the safety net, not the refactor itself. If the refactor is abandoned, the characterization tests stay — they're free behavior documentation. They also need to exist before Dev creates the refactor branch so that Dev can see green-on-baseline.

## Phase 5: Optional Escalation — Mutation Testing

For most refactor passes, Phases 1–4 are enough. The exception: high-stakes refactors of code where you genuinely cannot tell whether existing tests are effective.

Mutation testing (Stryker for TS/JS, mutmut for Python, PIT for Java) auto-introduces small code mutations and reports which survive — surviving mutants indicate weak tests. It's slow, can have noise, and adds setup cost.

**Default position: skip.** Flag mutation testing as a possibility only when:

- The target's code was *not* TDD'd (tests written after the fact)
- The blast radius of a silent behavior break is high (payment paths, auth, persistence, anything with external consumers)
- Phases 1–4 have surfaced gaps and the team still feels unconfident

If mutation testing is escalated, treat its score as a *guide*, not a gate. Surviving mutants are leads for new characterization tests, not blockers.

## Phase 6: Output

Add a `Safety-Net Assessment` block under the target in the refactor pass doc:

```markdown
### Safety-Net Assessment

- **Baseline tag:** `refactor-baseline-20260526T141133Z` *(record the one you created — with an
  instant in the name it cannot be reconstructed from the date)*
- **Tests covering this target:**
  - `path/to/test.ts` — covers create, update flows
  - `path/to/other.test.ts` — covers slug validation
- **Gaps identified:**
  - Error message wording for slug-collision case → characterization test added (`<test name>`)
  - Logging output during reparent → declared intentionally unconstrained
  - Defaults for null `parameters` → characterization test added (`<test name>`)
- **Mutation testing:** not invoked (TDD-built code, low-stakes target)
- **Verdict:** SAFE TO PROCEED
```

`Verdict` values:

- **SAFE TO PROCEED** — tests cover, gaps filled, baseline tagged. Issue gets created.
- **PROCEED WITH CARVEOUT** — only a subset of the original target is safe; subset described. Issue gets created for the subset.
- **DEFER** — too much test investment needed for this pass; document why and move target to LOW priority. No issue gets created.

## Red Flags — STOP

If you catch yourself:

- "Tests pass, ship it" without inventorying which tests cover the target → that's not a check
- "I'll add characterization tests later" → they protect the upcoming moves; later is too late
- "Mutation testing would be nice" on a TDD'd low-stakes target → it's overkill; skip and proceed
- "We don't need a baseline tag, git history works" → tags make revert one command; tagging is free
- Verdict = SAFE TO PROCEED with no gaps identified → either the inventory was incomplete or the analysis was shallow; recheck

## Quick Reference

| Phase | Activity | Output |
| --- | --- | --- |
| 1. Baseline | Run suite green, tag commit | Baseline tag |
| 2. Inventory | List tests covering target | Test list |
| 3. Gap analysis | Compare planned moves to test coverage | Gap list with decisions (A/B/C) |
| 4. Add chars tests | Write + commit characterization tests | New tests on default branch |
| 5. Escalate? | Optional mutation testing for high-stakes only | Defer to optional |
| 6. Output | Section in refactor pass doc | Verdict + assessment block |

## Related Skills

- **refactor-audit** — Surfaces the target list this skill audits
- **refactor-planning** — Provides the move sequence whose blast radius this skill checks
- **migration-planning** — When public surface changes, the safety net includes consumer-side concerns too
