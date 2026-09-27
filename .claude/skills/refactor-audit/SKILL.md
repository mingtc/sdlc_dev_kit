---
name: refactor-audit
description: Use when starting a refactor pass — scan the codebase holistically to identify high-impact refactor targets and produce a prioritized list with rationale
---

# Refactor Audit

## Overview

Refactoring without an audit means refactoring whatever you remember being annoyed by. That misses load-bearing problems and over-invests in cosmetic ones. A refactor audit is the discipline of looking at the whole codebase, then choosing the top ~30% of impact and deferring the rest.

**Core principle:** The audit's output is a *prioritized* list, not a comprehensive list. The Pareto cut is mandatory.

## When to Use

Use at the start of every refactor pass, typically:

- After a milestone closes (a layer of the build order lands, a release cuts)
- When file sizes / module sprawl start eating token budget noticeably
- When the human invokes the Refactorer hat
- Before any refactor planning happens — never plan in a vacuum

**Don't use when:**

- You're mid-feature and want a "while I'm here" cleanup — that belongs in the feature's own work branch if trivial, or as a follow-up issue if not
- The codebase is brand-new — there isn't enough surface area for an audit to be meaningful yet
- You audited recently and nothing has changed structurally — re-audit when new work has landed, not on a clock

## Inputs

Read these before scanning code:

1. **`PROJECT.md`** — quality bar, stack choices, declared trade-offs, anything tagged "deliberate" that looks like a smell but isn't. Critical for not flagging intentional choices as targets.
2. **`progress.md`** — last few sessions of decisions, deviations, deferred cleanups. These are often the best refactor leads — anything Dev marked "while I was here" or "deferred to <PREFIX>-NNN" is feedstock.
3. **`git log --since="<last refactor pass>"`** on the default branch — what changed lately, what density looks like.
4. **`ls progress/qa_complete/`** — what shipped recently.
5. **Project-declared stack-aware tools** (see PROJECT.md) — `ts-prune` / `knip` / `madge` / `jscpd` for TS, `vulture` / `radon` for Python, etc. Run these if present.

If PROJECT.md declares no stack-aware tools, fall back to LLM heuristics — the audit still works, just less deterministic.

## The Smell Catalogue

For each category, scan the codebase. Note file:line evidence for anything material.

| Category | What to look for | Heuristic |
| --- | --- | --- |
| **Long files** | Files where a reader needs to scroll for context | > 300 LOC is a starting point; calibrate per language and project |
| **Long functions** | Single functions that don't fit on one screen | > 50 LOC is a starting point |
| **Duplication** | Same *business concept* expressed in multiple places (not merely similar shape) | Pay attention to comments that say "same as X" or "mirrors Y" |
| **Deep nesting** | > 3 levels of conditional or loop nesting | Often a sign that guard clauses or extraction would help |
| **Unclear names** | Identifiers whose names don't describe their purpose | `data`, `result`, `helper`, `Manager`, `Util`, `info` are tells |
| **God modules** | Single file owning too many responsibilities | Often discovered via the long-files scan |
| **Long parameter lists** | Functions with > 4 positional parameters | Often a missing parameter object |
| **Dead code** | Exports nothing imports, unreachable branches, commented-out blocks | Use `ts-prune`, `vulture`, `knip` if available |
| **Coupling / cycles** | Modules importing each other circularly, or one module importing too many others | Use `madge` (TS), `dep-cruiser`, language equivalents |
| **Test gaps** | Source modules with no co-located tests, or tests that don't exercise edge cases | Surfaces as a prerequisite for safety-net-check |
| **Magic values** | Hardcoded strings/numbers repeated across files | Often a missing named constant |
| **Deferred TODOs** | `// TODO`, `// FIXME`, `// HACK` comments older than the last milestone | Re-evaluate; either fix or delete |

## Stack-Aware Augmentation

If PROJECT.md declares the stack, recommend the matching deterministic tools. Examples (not exhaustive — the project decides):

- **TS/JS:** `ts-prune` (dead exports), `knip` (unused files / deps), `madge` (cycles), `jscpd` (duplication), `eslint-plugin-sonarjs` (cognitive complexity)
- **Python:** `vulture` (dead code), `radon` (complexity), `pylint` (smells), `pydeps` (deps)
- **Ruby:** `rubocop` (style + complexity), `reek` (smells)
- **Go:** `staticcheck`, `gocyclo`, `golangci-lint`
- **Rust:** `cargo clippy`, `cargo-bloat`

**BEFORE YOU BELIEVE A TOOL'S OUTPUT, PROVE IT SAW THE SUBJECT.** Every tool above has an
exclusion list, a default glob and a config file, and **a scan that reached none of your code
reports clean** — indistinguishable, in the output pane, from a codebase with no smells. (Measured at an adopter:
a scanner whose own exclusion list held `src/` reported clean and buried the audit's two
highest-priority findings.)

So for each tool you run, before recording anything from it:

1. **Make it name its operand** — the file count or the file list it actually processed, not the
   finding count. `0 findings over 0 files` and `0 findings over 28 files` are different results and
   most tools print them the same way.
2. **Check that count against the subject** — `git ls-files <target paths> | wc -l`. A mismatch is
   the finding, and it outranks anything the tool did report.
3. **Where the tool cannot say, feed it a known positive** — a file you are certain contains the
   smell. A tool that misses a planted one cannot be trusted about the ones you did not plant.

*This is `process/doctrine/instruments.md` § A.6 (the operand set is where the defect lives) and
§ A.8 (a green that could not have gone red), applied to somebody else's tool.*

If these aren't configured in the project, that itself is a finding: "tool setup gap" is a refactor target too.

The skill is language-agnostic; deterministic tools are an enhancement, not a requirement.

## Prioritization (the Pareto cut)

**FIRST, FOR EACH CANDIDATE: CAN THIS ACTUALLY FIRE TODAY?** Before scoring, establish whether the
defect is **live** (reachable on a path the product executes now) or **latent** (real in the text,
unreachable as the code stands — behind a disabled flag, in a caller nobody has, on a branch of a
condition that cannot be taken). Say which, per candidate, with the evidence: the caller, the flag's
current value, the route in.

**A latent defect is not a non-finding — it is a different finding**, and it almost always drops in
priority, because the pain it is scored on is not being paid.

*Neither axis below asks this. "Likelihood-of-future-pain" is about how often the area is TOUCHED;
a defect can sit in a hot file and still be unreachable.*

Then, for each candidate target, score on:

- **Impact** — how much pain does this currently cause, or how much will it cause as the codebase grows? (High / Medium / Low)
- **Likelihood-of-future-pain** — does this area get touched often, or is it dormant?
- **Refactor cost** — how many moves does it take to fix, and how localized are they?
- **Risk** — how confidently can we preserve behavior? Test coverage, public-surface exposure.

Rough scoring: `(Impact × Likelihood) ÷ (Cost × Risk)`. Top ~30% by score → HIGH priority. Next ~30% → MEDIUM. Remainder → LOW (often "defer to next pass" or "leave alone").

**Bias toward HIGH:**

- Targets that block the next milestone's planned work
- Targets in code that gets touched every session
- Targets where the smell is compounding (long file getting longer over recent commits)

**Bias toward LOW:**

- Targets in code about to be deleted or substantially rewritten
- Targets where the "smell" is a deliberate trade-off documented in PROJECT.md or progress.md
- Targets where tests don't yet exist to verify behavior preservation (defer to a future pass that pairs with test investment)

## Output

Write the audit output into the refactor pass doc at `dev/refactor/<YYYY-MM-DD>-<scope>-pass.md` under two sections:

### Audit Findings

Group by smell category. For each finding, give:

- File:line evidence
- One-line description
- Severity hint (this is feedstock for prioritization, not a final ranking)

### Target List

A table:

| ID | Target | Priority | Impact | Cost | Risk | Rationale |
| --- | --- | --- | --- | --- | --- | --- |
| T1 | `<module / file / pattern>` | HIGH | H | M | L | One sentence why |
| T2 | ... | ... | ... | ... | ... | ... |

Each HIGH and MEDIUM target gets its own per-target detail block downstream (driven by `refactor-planning`, `safety-net-check`, optionally `migration-planning`). LOW targets are listed but not detailed — they're a record that "we saw this and chose not to act."

## Red Flags — STOP

If you catch yourself:

- Listing every smell you can find without ranking → you're cataloguing, not auditing. Force the Pareto cut.
- Recommending refactors in code that's about to be deleted → check the roadmap before adding to the list.
- Adding a target whose "smell" PROJECT.md or progress.md explicitly documents as a deliberate choice → that's a PM conversation, not a refactor.
- Scoring everything HIGH → re-calibrate. HIGH should be the top ~30%.
- Skipping the holistic-context read because "I already know the codebase" → that's how you miss the deferred cleanups buried in progress.md.

## Quick Reference

| Phase | Activity | Output |
| --- | --- | --- |
| 1. Context | Read PROJECT.md + progress.md + git log + kanban | Mental model of recent work |
| 2. Scan | Run smell catalogue (LLM + stack-aware tools) | Raw findings with file:line evidence |
| 3. Score | Apply impact / cost / risk, take Pareto cut | HIGH / MED / LOW classification |
| 4. Write | Section in refactor pass doc | Audit Findings + Target List table |

## Related Skills

- **refactor-planning** — For each HIGH/MED target, design the Fowler-move sequence
- **safety-net-check** — Verify test coverage before any moves on a target
- **migration-planning** — When a target touches public surface
