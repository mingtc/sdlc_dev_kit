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
5. Read [`process/LOCAL-PROCEDURES.md`](process/LOCAL-PROCEDURES.md) — **this project's resolved
   kit contradictions, as law.** Minted at SEED step 8; short by design. Reading it is what stops
   the next worker paying again for a question already answered — and when you resolve a new one,
   **you append to it in the same session**.

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

## House rules — THIS project's law

<!-- Only rules that are genuinely yours. A rule already stated in process/MANUAL.md or in
     process/doctrine/ does not belong here — POINT at it instead. A rule that CONTRADICTS the
     manual needs a sentence saying so explicitly. -->

- **<Rule>.** <One line of why. A rule without its why gets re-litigated every quarter.>
- **<Rule about secrets>** — e.g. *the credential file is never committed*.
- **<Rule about dependencies>** — e.g. *no new runtime dependency without its own decision*.
- **<Rule about the documents that must move together>** — e.g. *touch the surface, update the
  matrix / the consumer docs, in the SAME change*.
- **Commit hygiene is doctrine, not taste** —
  [`process/doctrine/commit-hygiene.md`](process/doctrine/commit-hygiene.md). Your own additions
  here are **subject style only** (tense, length, body format); the four rules in that sheet are
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
