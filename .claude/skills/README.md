<!-- KIT-CLASS: KIT — the shipped skill inventory. Project-specific notes go in the adapter. -->
# Project Skills

This directory contains the **20 Claude Code skills the kit ships**, version-controlled with
the repo and organized into four role-based skill sets — **PM**, **Dev**, **QA**,
**Refactorer** — plus one standalone skill (`orchestrate`). Anyone who clones the repo gets
them automatically: Claude Code discovers skills in `.claude/skills/` and exposes them to the
session.

The skill set is **stack-agnostic**. Nothing here assumes a language, a test runner, a build
tool or a forge. Where a skill needs a concrete command it says
`<the project's test command>` and expects the **project adapter** (`CLAUDE.md`) and the
**project facts** (`PROJECT.md`) to supply the real one. The floor the kit itself needs is
**git + a POSIX shell**.

> One exception worth knowing about: `brainstorming`'s optional **visual companion** ships a
> small local server (`brainstorming/scripts/server.cjs`) that needs Node to run. It is
> **opt-in per question** — the skill works fully without it, and declining the companion
> costs you nothing. If your project forbids Node, say so in the adapter and the companion
> stays unused.

## How skills work

Each subdirectory is one skill containing a `SKILL.md` (the entry point Claude loads). Skills
are surfaced to Claude by their `description:` frontmatter; Claude invokes them via the
`Skill` tool when a request matches. You can also invoke any skill explicitly by typing its
name as a slash command (e.g. `/test-driven-development`).

Some skills carry sibling files — prompt templates, reference tables, helper scripts. Those
are loaded on demand by the `SKILL.md` that owns them; they are not entry points.

## Roles & skill inventory (20)

### Dev — Engineering (13 skills)

| Skill | Purpose |
| --- | --- |
| [brainstorming](brainstorming/) | Use before any creative work — explore intent before implementing |
| [writing-plans](writing-plans/) | Turn a spec into a written, TDD-shaped implementation plan |
| [executing-plans](executing-plans/) | Execute a plan in a separate session with review checkpoints |
| [subagent-driven-development](subagent-driven-development/) | Execute plans with independent tasks via subagents, two-stage review per task |
| [dispatching-parallel-agents](dispatching-parallel-agents/) | Fan out 2+ genuinely independent investigations to parallel agents |
| [test-driven-development](test-driven-development/) | The red-green-refactor loop for any feature or bugfix |
| [systematic-debugging](systematic-debugging/) | Root-cause-first debugging for bugs, test failures, unexpected behavior |
| [verification-before-completion](verification-before-completion/) | Prove work is done before claiming it is |
| [requesting-code-review](requesting-code-review/) | Request review at the right moment, with the right context |
| [receiving-code-review](receiving-code-review/) | Process review feedback rigorously, not performatively |
| [finishing-a-development-branch](finishing-a-development-branch/) | Decide how to integrate completed work (merge / branch / cleanup) |
| [using-git-worktrees](using-git-worktrees/) | Isolated workspaces for feature work and plan execution |
| [using-superpowers](using-superpowers/) | Bootstrap: how to find and use skills; cross-harness tool mapping |

### PM — Product Management (2 skills)

| Skill | Purpose |
| --- | --- |
| [write-spec](write-spec/) | Draft a spec/PRD from a problem statement or feature idea |
| [product-brainstorming](product-brainstorming/) | Explore problem spaces and stress-test product ideas |

### QA — Quality Engineering (0 skills shipped, by design)

QA's discipline in this kit is **not** packaged as a skill, and that is deliberate:

- **The verdict procedure** is the role doc — [`.claude/roles/qa.md`](../roles/qa.md): read the
  AC, run the project's declared gates, walk the AC line by line with evidence, PASS or FAIL.
- **Bug filing** is a script plus a template —
  [`.claude/templates/BUG.template.md`](../templates/BUG.template.md) and the board's
  `new-bug.sh`, not a skill.
- **The binding extra gate** — whatever the project declares beyond a green suite (a live
  round-trip, a smoke run against a real surface, a packaging check) — is named in the
  **adapter**, because only the project knows what it is.

A project that grows a rendered surface will want web-QA skills (accessibility audit, visual
regression). **The kit ships none** — source or author them, then add them to the table above
and to the QA role doc's skill list in the same change.

### Refactorer — Code Health (4 skills)

The Refactorer role uses these post-milestone (or on refactor-baseline drift) to identify,
plan and safely schedule behavior-preserving improvements.

| Skill | Purpose |
| --- | --- |
| [refactor-audit](refactor-audit/) | Holistic codebase scan → prioritized refactor targets (HIGH / MED / LOW) |
| [refactor-planning](refactor-planning/) | Per target, design the Fowler-style move sequence (vertical or horizontal) |
| [safety-net-check](safety-net-check/) | Per target, verify coverage before any moves; add characterization tests; tag a baseline |
| [migration-planning](migration-planning/) | When a refactor touches public surface — coexistence → deprecation → sunset |

### Standalone (1 skill)

| Skill | Used by | Purpose |
| --- | --- | --- |
| [orchestrate](orchestrate/) | Orchestrator | Drive a set of issues through Dev → QA hands-off, wearing the Dev/QA hats in turn. Implements [`.claude/roles/orchestrator.md`](../roles/orchestrator.md). |

## Not shipped: the UI/design skill family

The **UI-Designer** role doc ships **parked** at
[`.claude/roles/archive/ui-designer.md`](../roles/archive/ui-designer.md) because its
workflow is worth keeping. The skills it names — a UI audit, interaction design, visual
polish, microcopy review, and whatever rendered-surface engine the project adopts — are
**intentionally absent** from this kit: a UI skill set that has no UI to look at is dead
weight that still shows up in every session's skill menu.

Waking that role means: source or author its skills into this directory, list them in the
table above, remove the DORMANT banner from the role doc, and register the role in the
adapter's role table — all in the same change, so the kit never advertises a skill it does
not carry.

## How to invoke a skill

- **Slash command (any session):** type the skill name, e.g. `/write-spec`,
  `/test-driven-development`, `/refactor-audit`. Claude loads that skill's `SKILL.md` and
  follows it. Works regardless of which role hat you are wearing.
- **From inside a role session:** the role docs in [`../roles/`](../roles/) say which skills
  auto-trigger for that role and which to invoke manually, alongside the role's session-start
  phrase and file conventions. Start there for an end-to-end PM, Dev, QA or Refactorer
  workflow; the adapter (`CLAUDE.md`) explains how to pick a hat.

## Provenance & licensing

Most of the Dev set and both PM skills came from public, permissively-shared skill
collections; the Refactorer set was authored for this kit. **Record the real provenance of
every skill directory you keep, adopt or replace** — origin and license — in this section, and
update it in the same change as the skill. A skill whose origin nobody can name is a skill
nobody can safely update.

| Set | Origin | License |
| --- | --- | --- |
| Dev (13) | `<fill in: upstream collection URL, or "authored here">` | `<fill in>` |
| PM (2) | `<fill in>` | `<fill in>` |
| Refactorer (4) | Authored for this kit | Same as this repo |
| `orchestrate` (1) | Authored for this kit | Same as this repo |

When updating a skill from upstream, re-fetch the source and copy the folder over the
existing skill, then **diff before committing** — local hardening lives in these files and a
blind overwrite silently discards it.
