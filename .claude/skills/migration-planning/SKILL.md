---
name: migration-planning
description: Use when a refactor touches public surface (API paths, type exports, file paths, slug schemes, CLI flags) — design the rename/redirect/deprecation sequence so downstream callers don't break in one commit
---

# Migration Planning

## Overview

Most refactor moves are internal — they reshape code that nothing outside the project sees. But the moment a refactor touches *public surface* (anything a downstream caller depends on), the move is no longer "rename + verify tests pass." It becomes "introduce new name, keep old name working, migrate callers, deprecate, sunset."

This skill plans that sequence.

**Core principle:** Public surface changes are *staged*, not atomic. A single commit that breaks downstream callers is never acceptable, even when the rename is "obviously correct."

## When to Use

Use per target, after `refactor-planning`, when any planned move changes something a downstream caller might depend on.

If `refactor-planning` produces no public-surface moves, skip this skill entirely.

**Don't skip when:**

- The change is "obviously safe" — what's safe to the Refactorer is rarely safe to every consumer
- The downstream callers are "internal" — internal callers in other modules still break atomically if the rename happens without a coexistence window
- "Nobody uses that" — verify with grep, not with belief

## Phase 1: Enumerate the Surface

For each planned move that *might* touch public surface, list what's exposed. Common surface categories:

| Surface kind | Examples |
| --- | --- |
| **HTTP routes** | `GET /api/foo`, `POST /api/foo/:id` |
| **Type exports** | `export type Foo` from a public module |
| **Named function / class exports** | `export function foo()` from a public module |
| **CLI flags / commands** | `--my-flag`, subcommand names |
| **Config keys** | env var names, settings file keys |
| **Database column names** | when consumed by external systems or migrations |
| **File paths** | when other repos / scripts depend on them |
| **URL slug schemes** | when bookmarks / external links rely on the form |
| **Event names / message shapes** | pub/sub topics, webhook payloads |
| **Error codes / sentinels** | when callers `switch` on them |

If you're not sure whether something is public, treat it as public. Conservative wins here.

## Phase 2: Classify Each Item

Three buckets:

| Classification | Definition | Migration needed? |
| --- | --- | --- |
| **Internal** | Used only within one module / file. Nothing outside knows about it. | No. Free rename. |
| **Project-internal cross-module** | Used by multiple modules inside this repo. Not exposed outside. | Atomic: rename + update all callers in one change. Compiler / test suite catches mistakes. |
| **Project-external** | Consumed outside this repo (other repos, external API clients, end users, scripts, bookmarks). | Yes. Plan a coexistence → deprecation → sunset sequence. |

To classify: grep for usage. If grep returns only the target module, it's Internal. If grep returns multiple modules in this repo but nothing in other repos / external callers, it's Project-internal cross-module. If callers exist outside the repo's control, it's Project-external.

For URL slug schemes and DB columns specifically, treat as Project-external by default — you usually cannot enumerate all consumers (bookmarks, scrapers, external integrations, archived data dumps).

## Phase 3: Design the Migration Sequence

For each Project-external item, design a three-step sequence:

### Step 1 — Coexistence window

Introduce the new name. Old name continues to work and delegates to the new one.

- **HTTP routes:** register both the new and old path; both handlers do the same thing (the old one may call the new one).
- **Type / function exports:** the new export is added; the old export is preserved and re-exports the new one (`export const oldName = newName;`).
- **CLI flags:** accept both flags; the old flag is honored and triggers the same behavior.
- **URL slug schemes:** leverage project-native redirect tables if available (many projects build redirect mechanisms for slug-rename support; check PROJECT.md and existing redirects). If none exists, build one — or kick to PM if redirect infrastructure is a foundational decision.
- **DB columns:** add the new column, dual-write to both, reads prefer the new column with fallback to the old.

A test asserts both names work. The coexistence window may last weeks, months, or indefinitely depending on the project's quality bar.

### Step 2 — Deprecation marker

Once internal callers have switched to the new name, mark the old name deprecated.

- **TypeScript / JS:** `@deprecated` JSDoc tag (TS LSP / editors warn callers).
- **HTTP routes:** deprecation header on responses from the old path (`Deprecation: true`, `Sunset: <date>`).
- **Python:** `warnings.warn(DeprecationWarning(...))` on call.
- **CLI flags:** print a deprecation notice to stderr on use.
- **URL slug schemes:** redirect responses include `X-Deprecated: true` header.

State the sunset date or version explicitly: "Sunset planned for v1.4 / 2026-08-01."

### Step 3 — Sunset

Old name removed. This is a separate change, often in a separate milestone. Caller responsibility to have migrated by now.

Before sunsetting:

- Verify no internal callers still use the old name (grep is enough).
- For Project-external surfaces with bookmarks / archives, consider an indefinite redirect rather than a hard removal. URL slugs in particular often deserve permanent redirects — sunset means "stop accepting writes against this name," not necessarily "stop accepting reads."

## Phase 4: Risk Calls

Anything you're uncertain about goes in the Risk Calls section of the refactor pass doc. Examples:

- "Renaming `/api/things` → `/api/things-v2` — do we know any external dashboards consume this path? Need to confirm before scheduling sunset."
- "Renaming role `senior_user` → `power_user` — are any analytics queries already aggregating by this name?"
- "Switching error code `E_BAD_SLUG` → `INVALID_SLUG` — clients may be switching on the string."

Each Risk Call gets:

- One-line description
- Recommendation (proceed / coexistence-only / defer / kick to PM)
- Status: `pending` → `human-approved` / `kicked to PM` / `decided`

Refactorer does not execute risk-call items until status changes from `pending`. This is where the Refactorer pauses for the human / PM / Dev to weigh in.

## Phase 5: When to Kick to PM

Some "refactors" are not refactors — they're product decisions. Kick to PM when:

- The change alters semantics (the new endpoint returns a different shape, not just under a different path)
- The change adds or removes capability (new feature / removed feature, not just renamed)
- The change touches contract guarantees with paying customers / external integrations
- The change rearranges a public surface in a way that requires partner communication

A migration plan covers *form*. A PRD covers *meaning*. If you're planning more than form, stop and kick to PM.

## Phase 6: Output

Add a `Migration Plan` block under the target in the refactor pass doc:

```markdown
### Migration Plan

| Surface item | Classification | Plan |
| --- | --- | --- |
| `GET /api/v1/things` → `/api/v1/things-v2` | Project-external | Coexistence (both paths) → deprecation header on old → sunset planned 2026-08-01 |
| `export type Foo` | Project-internal cross-module | Atomic rename in the same change; update all importers |
| `export function helper()` | Internal | Free rename, no migration |

### Risk Calls

- `senior_user` role → `power_user`: any analytics queries aggregating by name? — *Recommendation: kick to PM* — Status: `pending`
```

The `Risk Calls` subsection is *also* surfaced into the refactor pass doc's top-level Risk Calls section so the human sees all pending decisions in one place.

## Red Flags — STOP

If you catch yourself:

- "Just rename it, callers will figure it out" → never. Stage every public-surface change.
- "It's internal, no migration needed" without grepping → grep first, then classify.
- Skipping the deprecation marker because "we'll just remove it later" → markers protect callers from surprise; never skip.
- Designing a migration that adds capability or removes capability → that's a PRD-level change; kick to PM.
- Sunset date / version not stated → "indefinite coexistence" becomes "permanent surface debt"; commit to a date even if it's far out.

## Quick Reference

| Phase | Activity | Output |
| --- | --- | --- |
| 1. Enumerate | List public surface touched | Surface item list |
| 2. Classify | Internal / cross-module / external | Classification per item |
| 3. Sequence | Coexistence → deprecation → sunset for external | Migration sequence |
| 4. Risk Calls | Surface uncertainties | Pending-decision list |
| 5. PM cut | If semantics change, kick to PM | Issue moved out of refactor pass |
| 6. Output | Section in refactor pass doc | Migration Plan + Risk Calls |

## Related Skills

- **refactor-audit** — Identifies the targets that include public-surface changes
- **refactor-planning** — Provides the move sequence; this skill checks which moves are public
- **safety-net-check** — When public surface changes, the safety net includes "coexistence works" tests
