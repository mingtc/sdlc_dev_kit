<!-- KIT-CLASS: KIT — the adapter, pre-filled generically. Every <angle-bracket> is yours to fill;
     the tables that mirror .claude/roles/ and the commit-msg hook are law, not suggestions. -->
# CLAUDE.md — <project name> operating manual

**How this project is developed.** <project name> runs a **filesystem-as-kanban** process with
**roles as hats**. The transferable half of that process is
[`process/MANUAL.md`](process/MANUAL.md) — **read it once; it is the operating manual, and this
file does not repeat it.** The project-specific facts (stack, run commands, the quality bar, the
gates, credentials, the active-roles table) live in [`PROJECT.md`](PROJECT.md) — **read that
first, every session.**

**This file is the PROJECT ADAPTER: this project's own law** — what is true here and nowhere
else. It supplies the values the manual deliberately does not know (the trunk, the code paths,
the gates, the role set, the commit prefixes) and carries the house rules that bind this
repository.

**The three documents, and what each owns:**

| Document | Owns |
|---|---|
| [`process/MANUAL.md`](process/MANUAL.md) | The process itself — roles, the board, the Dev→QA boundary, the rituals. Transferable; **adopt unedited**. |
| [`PROJECT.md`](PROJECT.md) | This project's facts — stack, commands, quality bar, gates, credentials. |
| **This file** | The **adapter**: which parts of the manual are on, which are off, and **this project's own law**. |

Extracting this kit into another repository: [`process/EXTRACTION.md`](process/EXTRACTION.md).
Starting a project from nothing: [`process/SEED.md`](process/SEED.md).

---

## Session start

The ritual is [`process/MANUAL.md` § Session start](process/MANUAL.md). Here:

1. **Read [`PROJECT.md`](PROJECT.md).** What this project is, the stack and run commands, the
   quality bar, and the binding gates.
2. **Check the board.** Issue files are `<PREFIX>-NNN-<slug>.md` (the prefix is stamped into
   `scripts/config.sh` by the initializer; PRDs are `PRD-NNN`). The folder under `progress/` **is**
   the status. `./scripts/check-board.sh` reports drift.
3. **Pick a hat** from the roles table below, and say which one. The role doc in `.claude/roles/`
   is your workflow. *(Rule: [`process/contracts/role-gate.md`](process/contracts/role-gate.md).)*
4. **Read `process/LOCAL-PROCEDURES.md`** — this project's resolved kit contradictions, as law.
   *(It does not exist in a fresh seed: you mint it at [`process/SEED.md`](process/SEED.md) step 8,
   and you append to it in the same session in which you resolve a new contradiction. Reading it is
   what stops the next worker paying again for a question already answered.)*

> First-time setup on a fresh clone: run **`./setup.sh`** — see [`PROJECT.md`](PROJECT.md)
> § Stack & run commands.

## Roles

The pattern is [`process/MANUAL.md` § Roles as hats](process/MANUAL.md). **This table is this
project's cast** — it is the source of truth for which hats exist here, and it must match the
contents of `.claude/roles/` and the role set your commit-attribution guard enforces
*(authority: [`process/contracts/config-seam.md`](process/contracts/config-seam.md) and
[`process/contracts/commit-attribution.md`](process/contracts/commit-attribution.md))*.

| Role | Doc | Owns |
|------|-----|------|
| **Architect** | [architect.md](.claude/roles/architect.md) | **The standing seat** (human-partnered): technical direction, planning, orchestration-of-orchestrators, final inspection. Worn ONLY by the seated architect instance — never assigned to subagents; its doc binds no other role. |
| **Orchestrator** | [orchestrator.md](.claude/roles/orchestrator.md) | Drives issues Dev → QA, spawning subagents that wear the Dev/QA hats and checking their work. |
| **PM** | [pm.md](.claude/roles/pm.md) | PRDs (`requirements/`), the backlog, the roadmap. |
| **Dev** | [dev.md](.claude/roles/dev.md) | Implementation on a work-item branch, test-first. |
| **QA** | [qa.md](.claude/roles/qa.md) | Verifies acceptance criteria + the binding gates; lands or fails. |
| **Refactorer** | [refactorer.md](.claude/roles/refactorer.md) | Post-milestone behaviour-preserving code health. |
| **UI-Designer** | [ui-designer.md](.claude/roles/archive/ui-designer.md) | **PARKED** (`.claude/roles/archive/`) — <un-park it when this project grows a UI surface; state here why it is parked>. |

**Parked is a decision, not an absence.** A role you do not run stays in the table with its reason,
in `.claude/roles/archive/`, so the next reader can see the choice was made. Adding or parking a
role means editing three places in the same change: this table, `.claude/roles/`, and the role set
in `scripts/githooks/commit-msg`.

## The trunk, the branches, and what counts as code here

The pattern is [`process/MANUAL.md` § Branching and role
attribution](process/MANUAL.md). This project's values:

- **Trunk: `<trunk>`** (default `main`) — a single trunk, **resolved and confirmed, never
  inferred**. The same value is stamped into the scripts by the initializer and must equal
  `<remote>/HEAD`.
- **Work lives on per-work-item branches:** `feature/<PREFIX>-NNN-<slug>`,
  `fix/<PREFIX>-NNN-<slug>`, `refactor/<PREFIX>-NNN-<slug>`. **One branch per work item, never
  per role.**
- **What counts as CODE here — `<fill: the globs>`.** Only these go through a branch.
  **Everything else is metadata and commits direct to `<trunk>`**: board moves, PRD and issue
  edits, role-doc updates, `process/**`, `dev/**`, `progress.md`, `PROJECT.md` and this file.
  *(The rule: [`process/MANUAL.md` § The code-vs-metadata rule](process/MANUAL.md).)*

  <!-- THE GLOBS CONVENTION, stated so the fill-in is unambiguous:
       • Write real globs, one per entry, `**`-rooted at the repo root — e.g. `src/**`,
         `tests/**`, and the ONE manifest/build file your language uses.
       • The list is a WHITELIST of what needs a branch, not a description of the tree. If a path
         is not named, a worker may commit it straight to the trunk — so an omission is a licence,
         not a gap.
       • Include the dependency manifest / lockfile: a dependency change is code even when no
         source file moves.
       • Do NOT include generated or vendored trees; name them in `.gitignore` instead.
       • Keep it SHORT. A long list means the boundary is not really a boundary, and every worker
         will re-derive it differently. -->

## Role-attribution commit prefixes

Every commit subject starts with a role tag; the `scripts/githooks/commit-msg` hook rejects a
prefix-less subject (wired via `git config core.hooksPath scripts/githooks`, set by `setup.sh`).
**This table is this project's prefix set and must match the hook's `ROLE_PREFIXES` line
verbatim** — the hook keeps that list on its own line precisely so a guard can *derive* it rather
than re-hardcode it.

| Prefix | Used by |
|--------|---------|
| `[PM]` | PM — PRDs, backlog, roadmap decisions. |
| `[Dev]` | Dev — code commits on a work-item branch; board moves during dev. |
| `[QA]` | QA — the squash-merge, board moves to `qa_complete`, review notes. |
| `[Refactorer]` | Refactorer — refactor issues + pass docs. |
| `[UIDesigner]` | (parked here — the prefix stays accepted so an un-park costs no hook change) |
| `[Orchestrator]` | Orchestrator — **narration only** (decomposition notes, coordination). The Orchestrator uses `[Dev]`/`[QA]` for the actual Dev/QA work its subagents do. |
| `[Architect]` | The architect seat — release commits, the roadmap, the seat contract (`.claude/roles/architect.md`), handoffs (`dev/handoffs/`), and seat-authored plans/assessments under `dev/`. |

Examples: `[Dev] <PREFIX>-001: add the download usage example` ·
`[QA] <PREFIX>-001 → qa_complete: PASS. Squash-merged into <trunk>.`

## What is ON and what is OFF here

**The adapter's real job.** Everything the manual describes is optional to *someone*; say which
optional parts you run, so nobody has to infer it from an empty directory.

| Kit feature | State here | Note |
|---|---|---|
| PRDs / subtask trees | <on / on for feature-area work only / off> | <why> |
| Orchestrated runs (Dev/QA subagents) | <on/off> | <why> |
| Launch-pack orchestration (`process/templates/launch-pack.template.md`) | <on/off> | <why> |
| Outbound notifications | <on/off — a silent no-op when unconfigured> | <why> |
| The role gate hook | <on/off> | <why> |
| The archive sweep threshold | <N files in `progress/qa_complete/`> | <why> |
| The kanban worktree | <on/off> | <why — it is load-bearing if any board move happens from a feature branch> |
| <your own> | <…> | <…> |

## The binding gates here

Never optional. The gate **definitions** are **[`PROJECT.md`](PROJECT.md) § Quality gates**, one
row per sheet in [`process/contracts/`](process/contracts/README.md); the rule that they are never
optional is [`process/MANUAL.md` § The default path is lite](process/MANUAL.md).

- **`<your gate command — e.g. ./scripts/verify.sh>` green** on every change, so no role
  re-derives the commands.
- **For `<the risky class of change — e.g. anything touching an external system>`: `<the check
  that is not blind>`.** A green offline suite is the floor, not a PASS —
  see [`PROJECT.md`](PROJECT.md) § The binding gate.

Calibrate rigor via the rigor-tier ladder in [`.claude/roles/orchestrator.md`](.claude/roles/orchestrator.md)
§ Token discretion.

## Where a ruling is recorded

A ruling that changes behaviour goes in [`requirements/DECISIONS.md`](requirements/DECISIONS.md)
**in the same change** — not only in an issue's Activity log. An Activity line records *this
issue*; the next reader is asking *what is currently true*, and only the register answers that.

## The default path is lite

**Default (lite):** issue → branch → tests → land. One issue, no PRD, no subtask tree.
**Full ceremony** (a PRD, decomposition, a subtask tree) is earned by **<your threshold — e.g.
work spanning multiple issues in one feature area>**, and the current example of it here is
**<name one, or "none yet">**.

The single most common process failure is running full ceremony on a one-file fix. State the
threshold; do not leave it to taste.

## House rules — the doctrine sheets, and this project's own law

**The doctrine sheets below are the kit's law and travel unedited.** Each states a *pattern* that
binds every project; where a sheet has an *instance* section, this project's instance is filled in
the sheet's own instance block or here — never by rewriting the pattern.

| Rule | Where it lives | One line |
|---|---|---|
| **Commit hygiene** | [`process/doctrine/commit-hygiene.md`](process/doctrine/commit-hygiene.md) | What a commit subject and body must carry, and what must never appear in one. |
| **Model provisioning** | [`process/doctrine/model-provisioning.md`](process/doctrine/model-provisioning.md) | Every dispatched worker is provisioned from the ratified model/effort ladder, not from habit — and **a dispatched worker does not spawn subagents**; fan-out is the seat's and the runner's job. |
| **Supersession** | [`process/doctrine/supersession.md`](process/doctrine/supersession.md) | **Preserve the reason, supersede only the conclusion** — a guard enforcing an overturned conclusion is *transformed, never deleted*. A rationale-free strike is what gets a settled argument re-litigated. Also § A.2: a PRD overtaken in part is annotated in the same change. |
| **Live resources** | [`process/doctrine/live-resources.md`](process/doctrine/live-resources.md) | How a test may touch a real external system: a disposable target, restored to baseline; never a real one. |
| **Distribution** | [`process/doctrine/distribution.md`](process/doctrine/distribution.md) | What shipping means here, and what must be true of a consumer-reaching surface before it ships. |

**This project's own law — fill these in, and give every rule its why.** A rule without its reason
gets re-litigated every quarter; a rule already stated in `process/MANUAL.md` does not belong here;
a rule that **contradicts** the manual needs a sentence saying so explicitly.

- **<Rule about secrets>** — e.g. *the credential file is never committed; it lives only in
  `.env` (gitignored)*. <why>
- **<Rule about dependencies>** — e.g. *no new runtime dependency without its own decision*.
  <why — and state the narrow class, if any, that is exempt>
- **<Rule about attribution>** — e.g. *no AI co-author or "generated with" trailers in any commit
  message*. <why>
- **<Rule about the documents that must move together>** — e.g. *touch the surface, correct the
  consumer docs / the capability matrix, in the SAME change*. <why>
- **<Rule about what a test may never target>** — <why>

## Project duties — filled by the adapter

<!-- WHAT GOES HERE, and nothing else: duties that are genuinely THIS project's and cannot
     generalize into the kit — the standing obligations a worker inherits by working here.
     The KINDS that belong:
       • Living documents that must move with a surface (capability matrices, a permissions
         table, a consumer-facing README that IS the package metadata) — name the document, the
         surface it tracks, and the guard that reddens when they drift.
       • Generated-vs-authored rules: which artifact is a PROJECTION and therefore never
         hand-edited, and where its single authoring site is.
       • Domain prohibitions: what this project's code may never do (widen a permission, mutate a
         customer record, call a paid endpoint in a unit test) and who may lift the prohibition.
       • Release obligations beyond the gates: notes files, tags, packaged copies held identical.
     Each duty: one bold sentence of the duty, one line of why, and the guard or the reviewer
     that enforces it. A duty with no enforcer is a wish — say so if that is what it is.
     DELETE THIS BLOCK ONLY when you can say this project has no such duties. -->

<duties go here — see the comment above for the kinds>

## Where the rest of the process lives

| Looking for | Read |
|---|---|
| Session start / close rituals | [`process/MANUAL.md`](process/MANUAL.md) § Session start, § Session close ritual |
| Execution discipline + the long-run liveness doctrine | § Execution discipline |
| Board moves, issue creation, the status folders | § Kanban rules |
| Lite path vs full ceremony, opt-in machinery | § The default path is lite |
| **The Dev → QA handoff (7 steps)** + the direct-to-trunk variant + bug severities | § The Dev → QA handoff |
| The kanban worktree, landing a branch, log-filtering recipes | § Branching and role attribution |
| Notifications | § Notifications (optional) |
| Every gate's contract, one sheet each | [`process/contracts/README.md`](process/contracts/README.md) |
| The doctrine sheets | [`process/doctrine/`](process/doctrine/) |
| Which shapes a hygiene pass looks for, and the instruments | [`process/hygiene-checklist.md`](process/hygiene-checklist.md) |
| Git hosting — local-only, a bare remote, or a forge | [`process/GIT-HOSTING.md`](process/GIT-HOSTING.md) |
| Extracting this kit into another repo | [`process/EXTRACTION.md`](process/EXTRACTION.md) |
| Starting a project from nothing | [`process/SEED.md`](process/SEED.md) |
| Non-Claude agents | [`AGENTS.md`](AGENTS.md) |
