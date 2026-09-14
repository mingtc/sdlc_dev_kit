<!-- KIT-CLASS: KIT — the shipped skill inventory. Project-specific notes go in the adapter. -->
# Project Skills

This directory contains the **Claude Code skills the kit ships**, version-controlled with the
repo and organized into four role-based skill sets — **PM**, **Dev**, **QA**, **Refactorer** —
plus one standalone skill (`orchestrate`). Anyone who clones the repo gets them automatically:
Claude Code discovers skills in `.claude/skills/` and exposes them to the session.

How many? The directory listing is the count — `find .claude/skills -name SKILL.md | wc -l` —
and no digit is typed here on purpose: a count written in prose is right until the next skill is
added and silently wrong from then on (`process/doctrine/staleness.md` § C: *derive, date, or do
not state*).

The skill set is **stack-agnostic**. Nothing here assumes a language, a test runner, a build
tool or a forge. Where a skill needs a concrete command it says
`<the project's test command>` and expects the **project adapter** (`CLAUDE.md`) and the
**project facts** (`PROJECT.md`) to supply the real one. The floor the kit itself **requires** is
**git + a POSIX shell**.

> **Two optional extras sit above that floor, and both are deletable without loss.** They are
> named here, beside the floor, so that neither the claim nor its exceptions can travel alone.
>
> - `brainstorming`'s optional **visual companion** ships a small local server
>   (`brainstorming/scripts/server.cjs`) that needs **Node** to run. It is **opt-in per
>   question** — the skill works fully without it, and declining the companion costs you nothing.
> - The hygiene instruments under `scripts/hygiene/` are **Python 3, standard library only**, and
>   are **advisory, never a gate**: nothing ships them, no gate calls them, and
>   `process/hygiene-checklist.md` states every shape they look for in prose, so deleting the
>   directory costs only the measurements.
>
> If your project forbids either, say so in the adapter; the companion stays unused and the
> instruments are deleted.

## How skills work

Each subdirectory is one skill containing a `SKILL.md` (the entry point Claude loads). Skills
are surfaced to Claude by their `description:` frontmatter; Claude invokes them via the
`Skill` tool when a request matches. You can also invoke any skill explicitly by typing its
name as a slash command (e.g. `/test-driven-development`).

Some skills carry sibling files — prompt templates, reference tables, helper scripts. Those
are loaded on demand by the `SKILL.md` that owns them; they are not entry points.

## Roles & skill inventory

### Dev — Engineering

| Skill | Purpose |
| --- | --- |
| [brainstorming](brainstorming/) | Use before any creative work — explore intent before implementing |
| [writing-plans](writing-plans/) | Turn a spec into a written, TDD-shaped implementation plan |
| [executing-plans](executing-plans/) | Execute a plan INLINE — you run the tasks yourself, with review checkpoints |
| [subagent-driven-development](subagent-driven-development/) | Execute plans with independent tasks via subagents, two-stage review per task |
| [dispatching-parallel-agents](dispatching-parallel-agents/) | Fan out 2+ genuinely independent investigations to parallel agents |
| [test-driven-development](test-driven-development/) | The red-green-refactor loop for any feature or bugfix |
| [systematic-debugging](systematic-debugging/) | Root-cause-first debugging for bugs, test failures, unexpected behavior |
| [verification-before-completion](verification-before-completion/) | Prove work is done before claiming it is |
| [requesting-code-review](requesting-code-review/) | Request review at the right moment, with the right context |
| [receiving-code-review](receiving-code-review/) | Process review feedback rigorously, not performatively |
| [finishing-a-development-branch](finishing-a-development-branch/) | End completed work: push and hand off for review, preserve, or discard — it never lands the work itself |
| [using-git-worktrees](using-git-worktrees/) | Isolated workspaces for feature work and plan execution |
| [using-skills](using-skills/) | Bootstrap: how to find and use skills; cross-harness tool mapping |

### PM — Product Management

| Skill | Purpose |
| --- | --- |
| [write-spec](write-spec/) | Draft a spec/PRD from a problem statement or feature idea |
| [product-brainstorming](product-brainstorming/) | Explore problem spaces and stress-test product ideas |

### QA — Quality Engineering (none shipped, by design)

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

### Refactorer — Code Health

The Refactorer role uses these post-milestone (or on refactor-baseline drift) to identify,
plan and safely schedule behavior-preserving improvements.

| Skill | Purpose |
| --- | --- |
| [refactor-audit](refactor-audit/) | Holistic codebase scan → prioritized refactor targets (HIGH / MED / LOW) |
| [refactor-planning](refactor-planning/) | Per target, design the Fowler-style move sequence (vertical or horizontal) |
| [safety-net-check](safety-net-check/) | Per target, verify coverage before any moves; add characterization tests; tag a baseline |
| [migration-planning](migration-planning/) | When a refactor touches public surface — coexistence → deprecation → sunset |

### Standalone

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
table above, replace the role doc's **PARKED** banner, and register the role in the adapter's
role table — all in the same change, so the kit never advertises a skill it does not carry.
**That list is the paperwork, not the work.** The role doc's own § What this role needs before
it can be woken says waking it "is a real piece of work, not a banner removal"; believe that
sheet over this line. (This line said "remove the DORMANT banner" — a banner the doc does not
carry, prescribing the exact act that doc calls insufficient.)

## How to invoke a skill

- **Slash command (any session):** type the skill name, e.g. `/write-spec`,
  `/test-driven-development`, `/refactor-audit`. Claude loads that skill's `SKILL.md` and
  follows it. Works regardless of which role hat you are wearing.
- **From inside a role session:** the role docs in [`../roles/`](../roles/) say which skills
  auto-trigger for that role and which to invoke manually, alongside the role's session-start
  phrase and file conventions. Start there for an end-to-end PM, Dev, QA or Refactorer
  workflow; the adapter (`CLAUDE.md`) explains how to pick a hat.

## Provenance & licensing

**The table below is the record; this paragraph does not restate it.** Origins differ by set,
and one of them is an open question rather than a fact: the Dev set was adopted from a public
collection whose terms were **never captured at adoption**, so its licence reads NOT RECORDED and
must not be assumed permissive. The PM and Refactorer sets were authored for this kit. **Record the
real provenance of every skill directory you keep, adopt or replace** — origin and license — in
this section, and update it in the same change as the skill. A skill whose origin nobody can name
is a skill nobody can safely update.

**This table is also where a skill directory's CLASSIFICATION lives**, and that is a derivation, not
a filing convenience: updating a skill from upstream is a re-fetch that copies the folder over,
which **erases an in-file marker**, so a marker inside a vendored skill would be a classification
that disappears on the one operation the set is designed for. This table survives the copy because
it lives outside the directory being replaced.
([`../../process/EXTRACTION.md`](../../process/EXTRACTION.md) § The one file classification
convention states the rule; this is where the answer is.)

**How to read the `Class` column:** it applies to **every directory in the set**. A single skill that
departs from its set — one that has acquired your project's law, say — gets its own row saying so,
and that row is what a reader trusts. **The default is `KIT`**: a skill travels unedited.

**An authored-here skill's class is recorded HERE TOO, and NOT for the reason the vendored ones
have.** The carve-out in
[`../../process/EXTRACTION.md`](../../process/EXTRACTION.md) § The one file classification
convention is scoped to **vendored** directories, and its reason is the re-fetch: a marker inside a
folder that gets copied over from upstream is a classification that disappears on the one operation
the set is designed for. **Nobody re-fetches a skill authored here, so that reason does not reach
it** — and a reason that does not hold is worse than no reason, because the next reader extends it
further. The reason that *does* hold is this column's own scope: it is read **set-wide**, so a
directory it does not name is a directory whose class this table silently does not answer. A
`Class` column with holes in it cannot be read the way its first sentence says to read it.

**So an authored-here skill may ALSO carry an in-file `KIT-CLASS:` marker, and the carve-out does
not exempt it from one** — nothing erases it. Where a sheet does carry one the `Class` column says
so, the two must agree, and **the in-file marker is the one that was easier to forget**. Derive
which of them carry one rather than trusting this paragraph: `grep -rl 'KIT-CLASS' .claude/skills/`.

| Set | Origin | License | Class |
| --- | --- | --- | --- |
| Dev | **Adopted from a public collection — the upstream "superpowers" collection, `https://github.com/obra/superpowers`.** Its link also survives in `brainstorming/scripts/frame-template.html`, kept there deliberately as provenance | **NOT RECORDED** — the upstream's terms were never captured at adoption; settle it by reading the upstream repository, and do not assume | `KIT` |
| PM | **Authored for this kit** (`write-spec`, `product-brainstorming`) | Same as this repo | `KIT` |
| Refactorer | Authored for this kit | Same as this repo | `KIT` |
| `orchestrate` | Authored for this kit | Same as this repo | `KIT` — and marked in-file |
| `finishing-a-development-branch` | Dev set, upstream | `<fill in>` | `MIXED` — carries THIS kit's landing law (the landing script, the Dev role doc); a blind re-copy erases it |
| `<a skill that departs from its set>` | `<fill in>` | `<fill in>` | `<MIXED\|PROJECT, and why>` |

**THE ORIGIN COLUMN IS THE KIT'S OWN RECORD, NOT A BLANK FOR YOU.** Two of these rows read
`<fill in>` until 2026-09-07, in the table whose opening sentence is *"a skill whose origin nobody
can name is a skill nobody can safely update"* — **so the document whose entire job is provenance was
the one document that did not carry it.** The answers were never unknown; they were recorded in the
kit's own change history and nowhere a reader of this table would look. **The only row here you fill
is the last one**, the shape row for a skill of yours that departs from its set.

**A `<fill in>` that survives into a shipped table is worth suspecting generally:** it means either
nobody knew, or nobody moved the answer to where it is looked up, and those want opposite fixes.

When updating a skill from upstream, re-fetch the source and copy the folder over the
existing skill, then **diff before committing** — local hardening lives in these files and a
blind overwrite silently discards it.

**One class of hardening the diff will show, and it is not drift.** Where an upstream skill states
an instruction in one tool's or one forge's command, this kit keeps the instruction and demotes the
command to a named example — the setup commands in `using-git-worktrees`, the review-thread reply
in `receiving-code-review`. **Other local hardening is not of that class and the diff will show
it too:** `finishing-a-development-branch` carries this kit's landing law, `using-skills`
has repaired citations, `using-git-worktrees` gained an external-directory note, and
`brainstorming`'s visual companion is opt-in machinery this kit added. **Read every diff hunk
on its own** — the class below is the one that is easiest to mistake for drift, not the only
one you will meet. A re-copy that restores the single-command form has not updated the
skill, it has re-narrowed it, and it breaks the claim this file opens with: *nothing here assumes a
language, a test runner, a build tool or a forge.* Carry the upstream's substance into the local
wording, never the reverse.
