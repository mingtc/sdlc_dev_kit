<!-- KIT-CLASS: KIT — a blank shape. Travels unedited; every angle-bracket blank is yours to fill. -->
<!--
  HOW TO USE THIS FILE
  1. Copy to the repository root as CLAUDE.md (or your agent tool's equivalent).
  2. Fill every <angle-bracket> blank; delete every HTML comment.
  3. Keep it SHORT. The adapter's job is to route, not to restate — anything it copies out of
     process/MANUAL.md will drift, and the copy will win arguments it should lose.
  LINKS are written for this file's DESTINATION (the repository root) and resolve once copied
  there; while it sits in process/templates/, `process/…` targets are one level up at `../…`.
  Any version shown in an example is the deliberately fictional 42.x.
  DROP THE KIT-CLASS MARKER above from your copy: it classifies this file for the kit, not for
  your project. (Your adapter is PROJECT-class by nature — it is the one file that never travels.)
-->

<!-- LINKS IN THIS FILE ARE RELATIVE TO WHERE IT LANDS — ./ — NOT to the directory it
     sits in. A link written for where the template SITS resolves while you read it here and
     is dead in every copy an adopter makes: it passes a link check run in the kit and fails
     the only reader who matters. The self-test reads this line to know where to resolve from,
     so keep its shape. -->
# CLAUDE.md — <project name> operating manual

**How this project is developed.** <project> runs a **filesystem-as-kanban** process with **roles
as hats**. The transferable half of that process is [`process/MANUAL.md`](process/MANUAL.md) —
**read it; this file does not repeat it.** The project-specific facts (stack, run commands, the
quality bar, the gates, credentials, the active-roles table) live in
[`PROJECT.md`](PROJECT.md) — **read that first, every session.**

**The three documents, and what each owns:**

| Document | Owns |
|---|---|
| [`process/MANUAL.md`](process/MANUAL.md) | The process itself — roles, the board, the Dev→QA boundary, the rituals. Transferable; **adopt unedited**. |
| [`PROJECT.md`](PROJECT.md) | This project's facts — stack, commands, quality bar, gates, credentials. |
| **This file** | The **adapter**: which parts of the manual are on, which are off, and **this project's own law**. |

## Session start

1. Read [`PROJECT.md`](PROJECT.md).
2. Check the board: `<the command that lists the status folders>` — the folder IS the status.
3. Run the drift report: `<your check-board command>`.
4. **Pick a hat** and say which one. The role doc in `.claude/roles/` is your workflow.
   *(Rule: [`process/contracts/role-gate.md`](process/contracts/role-gate.md).)*
5. Read `process/LOCAL-PROCEDURES.md` — **this project's resolved kit contradictions, as law.**
   Minted at SEED step 8; short by design. Reading it is what stops the next worker paying again
   for a question already answered — and when you resolve a new one, **you append to it in the
   same session**.

## Roles

The pattern is [`process/MANUAL.md` § Roles as hats](process/MANUAL.md). **This table is this
project's cast** — it is the source of truth for which hats exist here, and it must match the
contents of `.claude/roles/` and **every file that carries the role set** —
[`process/EXTRACTION.md`](process/EXTRACTION.md) § 2.4 is the list, and that list is the count.
*(Not "the guard": there is more than one, and a role registered in only some of them commits fine
and cannot move a card. Authority:
[`process/contracts/config-seam.md`](process/contracts/config-seam.md) and
[`process/contracts/commit-attribution.md`](process/contracts/commit-attribution.md).)*

| Role | Doc | Owns |
|------|-----|------|
| **<Role>** | [<role>.md](.claude/roles/<role>.md) | <what this hat owns, in one line> |
| **<Role>** | [<role>.md](.claude/roles/<role>.md) | <…> |
| **<Role>** | [<role>.md](.claude/roles/archive/<role>.md) | **PARKED** — <why it is parked, and what would un-park it> |

**Parked is a decision, not an absence.** A role you do not run stays in the table with its reason,
in `.claude/roles/archive/`, so the next reader can see the choice was made.

**Adding a role means editing this table, `.claude/roles/`, and every file that carries the role
set** — [`process/EXTRACTION.md`](process/EXTRACTION.md) § 2.4 is the list, and **that table is the
count**. Register it in only some of them and the role commits fine and **cannot move a card**: that
is a measured incident, not a hypothetical, and it is why § 2.4 exists.

**Parking one costs no script edit, and that is deliberate** — the prefix stays accepted, so an
un-park costs no hook change. *The asymmetry is worth knowing in both directions: adding touches
every carrier, parking touches none of the scripts.*

## The trunk, the branches, and what counts as code here

- **Trunk: `<trunk>`** (a single trunk, **resolved and confirmed, never inferred** — the same value
  the initializer stamped, and it must equal `<remote>/HEAD`).
- **Work lives on per-work-item branches:** `feature/<PREFIX>-NNN-<slug>`,
  `fix/<PREFIX>-NNN-<slug>`, `refactor/<PREFIX>-NNN-<slug>`. **One branch per work item, never per
  role.**
- **What counts as CODE here — `<fill: the globs>`.** Only these go through a branch.
  **Everything else is metadata and commits direct to `<trunk>`**: board moves, requirement and
  issue edits, role-doc updates, `process/**`, `dev/**`, the running log, the project-facts sheet
  and this file.
  *(The rule: [`process/MANUAL.md` § The code-vs-metadata rule](process/MANUAL.md).)*

  <!-- THE GLOBS CONVENTION, stated so the fill-in is unambiguous:
       • Write real globs, one per entry, `**`-rooted at the repository root — e.g. `src/**`,
         `tests/**`, and the ONE manifest/build file your language uses.
       • The list is a WHITELIST of what needs a branch, not a description of the tree. If a path
         is not named, a worker may commit it straight to the trunk — so an omission is a licence,
         not a gap.
       • Include the dependency manifest / lockfile: a dependency change is code even when no
         source file moves.
       • Do NOT include generated or vendored trees; name them in `.gitignore` instead.
       • Keep it SHORT. A long list means the boundary is not really a boundary, and every worker
         will re-derive it differently.
       This block is GUIDANCE and goes when you delete the comments. The bullet below is LAW and
       stays: it is the exception the rule needs in order to be followed. -->

- **Metadata MAY ride its code branch when it is part of the same change.** A register entry, a
  matrix row, a doc correction the code change *makes true* belongs in the commit that makes it
  true — splitting it onto `<trunk>` publishes a claim about code that has not landed, and leaves
  the branch's reviewer reading a diff with its explanation missing. The direct-to-trunk rule above
  governs metadata changed **on its own**; it was never a ban on a code change carrying its own
  documentation.
  **And the carve-out is not limited to documentation** — an *executable* declaration the same
  change makes true rides with it too. The case that keeps being missed: a new guard's enrolment in
  your gate runner's guard set, which the globs above classify as metadata while the file it guards
  is code. Split those and the branch's gate cannot see the guard, `<trunk>`'s gate cannot see what
  it guards, and **the guard floor shrinks with nothing red to show it.**

## Role-attribution commit prefixes

Every commit subject starts with a role tag; the `scripts/githooks/commit-msg` hook rejects a
prefix-less subject (wired via `git config core.hooksPath scripts/githooks` — `kit-init.sh` wires it ONCE at adoption and commits the hooks' executable bit; `setup.sh` re-wires and repairs it on EVERY fresh clone).
**This table is this project's prefix set and must match the hook's `ROLE_PREFIXES` line
verbatim** — the hook keeps that list on its own line precisely so a guard can *derive* it rather
than re-hardcode it.

| Prefix | Used by |
|--------|---------|
| `[<Role>]` | <who commits under this tag, and for what> |
| `[<Role>]` | <…> |
| `[<Role>]` | (parked here — <keep the prefix accepted so an un-park costs no hook change, or say why not>) |

Examples: `[<Role>] <PREFIX>-001: <what changed>` ·
`[<Role>] <PREFIX>-001 → qa_complete: <verdict>. Squash-merged into <trunk>.`

## What is ON and what is OFF here

<!-- The adapter's real job. Everything the manual describes is optional to SOMEONE; say which
     optional parts you run, so nobody has to infer it from an empty directory. -->

| Kit feature | State here | Note |
|---|---|---|
| Specs / subtask trees | <on / on for feature-area work only / off> | <why> |
| Orchestrated runs (Dev/QA subagents) | <on/off> | <why> |
| Outbound notifications | <on/off — silent no-op when unconfigured> | <why> |
| The role gate hook | <on/off> | <why> |
| The archive sweep threshold | <N> | <why> |
| The acceptance tier (a lens, never a gate) | <on/off> | <why> |
| Retirement under a ledger (else: park only) | <on/off> | <why> |
| <your own> | <…> | <…> |

## The binding gates here

<!-- The gate DEFINITIONS live in PROJECT.md § Quality gates, one row per contract sheet. This
     section names which of them bind, so no role has to re-derive the commands. The two rules
     below are the kit's, not yours: keep them. -->

Never optional. The gate **definitions** are **[`PROJECT.md`](PROJECT.md) § Quality gates**, one
row per sheet in [`process/contracts/`](process/contracts/README.md); the rule that they are never
optional is [`process/MANUAL.md` § The default path is lite](process/MANUAL.md).

- **`<your gate command — e.g. ./scripts/verify.sh>` green** on every change, so no role
  re-derives the commands.
- **For `<the risky class of change — e.g. anything touching an external system>`: `<the check
  that is not blind>`.** A green offline suite is the floor, not a PASS —
  see [`PROJECT.md`](PROJECT.md) § The binding gate.

Calibrate rigor via the rigor-tier ladder in
[`process/doctrine/rigor-tiers.md`](process/doctrine/rigor-tiers.md).

## House rules — THIS project's law

<!-- Only rules that are genuinely yours. A rule already stated in process/MANUAL.md or in
     process/doctrine/ does not belong here — POINT at it instead. A rule that CONTRADICTS the
     manual needs a sentence saying so explicitly. -->

- **<Rule>.** <One line of why. A rule without its why gets re-litigated every quarter.>
- **<Rule about secrets>** — e.g. *the credential file is never committed*.
- **<Rule about dependencies>** — e.g. *no new runtime dependency without its own decision*.
- **<Rule about the documents that must move together>** — e.g. *touch the surface, update the
  matrix / the consumer docs, in the SAME change*.
- **<Rule about attribution>** — e.g. *every commit subject declares the role that wrote it, and no
  commit claims a co-author it did not have*. **Name the mechanism that enforces it in the same
  line**, here the `scripts/githooks/commit-msg` hook, which carries **both** halves: it refuses a
  prefix-less subject (§ Role-attribution commit prefixes above) **and** refuses a generated
  co-author trailer or a *"Generated with"* line. *A rule of this kind either has a mechanism or it
  is a preference: write which one yours is, because a stated rule with no enforcement reads to the
  next reader as enforced. Where your rule and its guard are two things, they move together — change
  one without the other and the guard starts enforcing a rule nobody wrote down.*
- **Commit hygiene is doctrine, not taste** —
  [`process/doctrine/commit-hygiene.md`](process/doctrine/commit-hygiene.md). Your own additions
  here are **subject style only** (tense, length, body format); the rules in that sheet are
  not yours to soften.
- **Worker provisioning follows the ladder, not habit** —
  [`process/doctrine/model-provisioning.md`](process/doctrine/model-provisioning.md), whose § B.2
  is **your** ratified table. State the one-line summary here and point at it.
- **Preserve the reason, supersede only the conclusion** —
  [`process/doctrine/supersession.md`](process/doctrine/supersession.md). Pointer, not a copy.

## Where a ruling is recorded

A ruling that changes behaviour goes in [`requirements/DECISIONS.md`](requirements/DECISIONS.md)
**in the same change** — not only in an issue's Activity log. An Activity line records *this
issue*; the next reader is asking *what is currently true*, and only the register answers that.

## The default path is lite

<!-- Keep or cut, but decide deliberately: the single most common process failure is running
     full ceremony on a one-file fix. State YOUR threshold. -->

**Default (lite):** issue → branch → tests → land. One issue, no spec, no subtask tree.
**Full ceremony** (a spec, decomposition, subtasks) is for **<your threshold — e.g. work spanning
multiple issues in one feature area>**, and the current example of it is **<name one>**.

## Project duties — filled by the adapter

<!-- THIS BLOCK IS A PLACEHOLDER WITH A JOB. The kit's worker role docs (.claude/roles/dev.md,
     qa.md) carry generic Definition-of-Done and review checklists. Any duty that is TRUE HERE AND
     NOWHERE ELSE belongs in this section, and the role docs point at it rather than inlining it —
     otherwise an adopter inherits checklist items naming files they do not have.

     WHAT KIND of duty goes here (not an exhaustive list, and not rules you must adopt):
       - documents that must be updated in the same change as a surface (capability matrices,
         a generated permissions/scopes projection, the front door, a changelog);
       - the surfaces whose truth is checked by a drift guard, and the guard's name;
       - project-specific evidence obligations (where a probe's captures land, what a live check
         must restore);
       - anything a reviewer must check here that a reviewer elsewhere would not.

     Each entry: the duty, who owes it (implementer / reviewer / both), and the guard that catches
     a miss — or an explicit "no guard, reviewer checks it". -->

- **<Duty>** — owed by <implementer/reviewer/both>; caught by `<guard>` / *no guard, reviewer
  checks it*.

## Where the rest of the process lives

<!-- TRAVELS VERBATIM. Every row is a kit path and none of them is a project fact, so there is
     nothing here to fill in. Keep the whole table: it is this file's only route into the process,
     and after day one this file is the one a new session opens first. -->

| Looking for | Read |
|---|---|
| Session start / close rituals | [`process/MANUAL.md`](process/MANUAL.md) § Session start, § Session close ritual |
| Execution discipline + the long-run liveness doctrine | § Execution discipline |
| Board moves, issue creation, the status folders | § Kanban rules |
| Lite path vs full ceremony, opt-in machinery | § The default path is lite |
| **The Dev → QA handoff** + the direct-to-trunk variant + bug severities | § The Dev → QA handoff |
| The kanban worktree, landing a branch, log-filtering recipes | § Branching and role attribution |
| Notifications | § Notifications (optional) |
| Every gate's contract, one sheet each | [`process/contracts/README.md`](process/contracts/README.md) |
| The doctrine sheets | [`process/doctrine/`](process/doctrine/) |
| Which shapes a hygiene pass looks for, and the instruments | [`process/hygiene-checklist.md`](process/hygiene-checklist.md) |
| Git hosting — local-only, a bare remote, or a forge | [`process/GIT-HOSTING.md`](process/GIT-HOSTING.md) |
| Extracting this kit into another repo | [`process/EXTRACTION.md`](process/EXTRACTION.md) |
| Starting a project from nothing | [`process/SEED.md`](process/SEED.md) |
| Non-Claude agents | [`AGENTS.md`](AGENTS.md) |
