---
name: refactor-planning
description: Use after refactor-audit to design the Fowler-style move sequence for a chosen target — one ordered list of behavior-preserving primitives, vertical or horizontal
---

# Refactor Planning

## Overview

A refactor target without a planned move sequence is a vague intention. The planning skill turns "this module is messy" into "do these 6 moves in this order." Each move is a named Fowler primitive, each is small, each is verifiable.

**Core principle:** Plan in *primitives*, not in goals. "Make it cleaner" is a goal. "Extract function `parseSlug` from `validateInput`" is a primitive.

## When to Use

Use per HIGH or MED target from the refactor audit output. Skip LOW targets — they're not getting moves designed yet.

**Use this BEFORE:**

- Running safety-net-check on the target — planning surfaces which behaviors the moves will touch, which guides the safety-net scope
- Running migration-planning on the target — planning surfaces whether any moves change public surface
- Creating the kanban issue — the issue's Move Sequence section is this skill's output

**Don't use when:**

- The target is too big to plan moves for in one sitting — split the target first (cue: > ~10 primitives means split)
- You're not certain what "better" looks like for this target — go back to brainstorming, or downgrade the target to LOW for a future pass

## Phase 1: State the Desired Shape

One paragraph per target. Concrete. What does the code look like after the refactor lands?

Examples:

- "`mutations.ts` is split into three files: one for create, one for update, one for delete. Shared helpers extracted to `mutations-helpers.ts`. No file > 200 LOC."
- "The 4 places where slug-collision detection happens all call one `assertSlugUnique` function. Current duplicated logic is deleted."
- "All `any` types in the API request handlers are replaced with named types from a shared `request-shapes.ts`."

Vague desired shapes produce vague move sequences. Force concreteness.

## Phase 2: Pick the Move Primitives

The catalogue. Use these names — they're standard Fowler vocabulary.

### Composition moves

| Move | When | Inverse |
| --- | --- | --- |
| **Extract Function** | A code block has a clear purpose and a good name | Inline Function |
| **Extract Variable** | An expression is hard to read or used multiple times | Inline Variable |
| **Extract Class** | A class is doing too many things | Inline Class |
| **Extract Module / File** | A file mixes concerns | Inline Module |
| **Extract Interface / Type** | A shape is used in multiple places without a name | Inline Type |

### Renaming moves

| Move | When |
| --- | --- |
| **Rename Variable** | Name doesn't describe purpose |
| **Rename Function** | Name doesn't describe what it does |
| **Rename Type** | Type name is misleading or generic |
| **Rename File / Module** | File contents have drifted from the name |

### Movement moves

| Move | When |
| --- | --- |
| **Move Function** | Function is in the wrong module |
| **Move Field** | Field belongs to a different type |
| **Move Module** | Module is in the wrong directory |

### Conditional simplification

| Move | When |
| --- | --- |
| **Decompose Conditional** | Big if/else with logic in each branch |
| **Consolidate Conditional** | Same logic guarded by multiple checks |
| **Replace Nested Conditional with Guard Clauses** | Deep nesting can flatten via early returns |
| **Replace Conditional with Polymorphism** | If/else dispatching on a type tag |

### Data simplification

| Move | When |
| --- | --- |
| **Replace Magic Number with Named Constant** | Hardcoded value used multiple places |
| **Encapsulate Field / Variable** | Direct mutation should go through an accessor |
| **Introduce Parameter Object** | Long parameter list (> 4) with cohesive params |
| **Replace Primitive with Object** | Primitive carries domain meaning (e.g. `string` for an email) |

### Larger structural moves (use with care, plan migration if public)

| Move | When |
| --- | --- |
| **Pull Up / Push Down Member** | Member belongs at a different inheritance level |
| **Replace Inheritance with Composition** | "Is-a" relationship doesn't actually hold |
| **Combine Functions into Class** | Functions share state via parameters |

If your target needs a move that isn't on this list, name it explicitly anyway. Custom moves are allowed; they just need a clear name and a one-line definition in the plan.

## Phase 3: Sequence the Moves

Order matters. Earlier moves should set up later moves. Example sequence:

> **Target:** split `mutations.ts`.
>
> 1. **Extract Function** `validateSlug` from inline code in `createThing`
> 2. **Extract Function** `validateSlug` from inline code in `updateThing` *(same name — these get merged in step 3)*
> 3. **Inline** the duplicate by importing the first `validateSlug` everywhere
> 4. **Extract Module** `mutations-helpers.ts` containing `validateSlug` and friends
> 5. **Move Function** `createThing` to `mutations-create.ts`
> 6. **Move Function** `updateThing` to `mutations-update.ts`
> 7. **Move Function** `deleteThing` to `mutations-delete.ts`
> 8. **Delete File** `mutations.ts` (now empty)

Each numbered move is one commit. Each commit message names the Fowler primitive. Each commit's diff is small enough to review on one screen.

**Sequencing principles:**

- **Extract before move.** (Move-then-extract is harder to keep clean.)
- **Rename before extract.** (Naming clarifies what's being extracted.)
- **Composition before structural changes.** (Smaller pieces are easier to re-arrange.)
- **Public-surface moves last.** (Internal cleanup first; outside-facing changes when everything below is settled.)

## Phase 4: Classify Scope — Vertical or Horizontal

- **Vertical** — one module / module-cluster, multiple moves. Typical case. Default when uncertain.
- **Horizontal** — one rule applied across many files. Examples: rename a convention everywhere, replace all `console.log` calls with a logger, switch a type alias across the repo.

Either fits as one kanban issue / one PR. The commit pattern differs:

- **Vertical PR:** commits ordered by the move sequence (one Fowler move per commit).
- **Horizontal PR:** commits grouped by directory or rule scope, with each commit named for the rule application (e.g. `Rename old_helper → new_helper across src/<module>/`).

Don't mix vertical and horizontal in one issue. Split them.

## Phase 5: Estimate Size

S / M / L. Same scale as feature issues:

- **S** — ≤ 1 session. ~1–3 primitive moves, no public-surface changes, well-tested area.
- **M** — 2–4 sessions. ~4–8 primitive moves, possibly small migration plan.
- **L** — Split it. Either the target is too big or your plan has too many moves. Carve out a smaller subset; defer the rest.

A plan with > ~10 moves should be split. Long sequences accumulate review burden and revert risk.

## Phase 6: Output

Write the per-target plan into the refactor pass doc under a `## Target T<n>: <name>` heading, with these subsections:

- **Desired shape** — one paragraph (Phase 1 output)
- **Scope** — vertical or horizontal
- **Size** — S / M / L
- **Move sequence** — numbered list, each move named with its Fowler primitive and a one-line description of what it touches
- **Open questions** — anything the Refactorer is uncertain about (these may surface to Risk Calls in the doc's top-level Risk Calls section)

The same content populates the kanban issue's `Move Sequence` section when the issue is created via `./scripts/new-refactor.sh`.

## Red Flags — STOP

If you catch yourself:

- Writing a "make it cleaner" plan with no primitives → you haven't planned yet
- Sequencing > 10 moves → split the target
- Mixing vertical and horizontal → split into two targets
- Including a move you've never executed before → name the move and verify the primitive's mechanics before committing to it in the plan
- Skipping the desired-shape paragraph because "it's obvious" → write it; it's the artifact reviewers will read

## Quick Reference

| Phase | Activity | Output |
| --- | --- | --- |
| 1. Desired shape | One concrete paragraph | Target's end state |
| 2. Primitives | Pick from the move catalogue | List of named moves |
| 3. Sequence | Order them so each sets up the next | Numbered sequence |
| 4. Scope | Vertical or horizontal | Tag |
| 5. Size | S / M / L | Tag, with split if L |
| 6. Output | Write to refactor pass doc | Section per target |

## Related Skills

- **refactor-audit** — Produces the target list this skill plans for
- **safety-net-check** — Run *after* planning, *before* execution, to verify tests catch the behaviors the moves touch
- **migration-planning** — Run when any planned move changes public surface
