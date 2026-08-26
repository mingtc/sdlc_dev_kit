<!-- KIT-CLASS: KIT — the contract index. Travels unedited; every sheet beside it does too. -->
# process/contracts/ — the gates and rituals as LANGUAGE-AGNOSTIC LAW

**What must be TRUE, separated from the machinery that currently makes it true.**

The rest of this kit transfers most easily to projects that can run its shell scripts. These sheets
are the half that transfers to everyone else: *"the project need not use any particular language or
shell if they don't want to — but the spirit needs to be there."*

**Read a sheet as a specification.** Sections 1–5 are binding on **any** implementation in **any**
language; section 6 names this kit's own implementation and is marked as *one implementation,
not the definition*. A sheet that made you open the script has failed its only job — say so.

## The six sections, every sheet, no exceptions

| # | Section | What it holds |
|---|---|---|
| 1 | **PURPOSE** | One sentence: what this gate exists to prevent. |
| 2 | **HARD INVARIANTS** | What any implementation must guarantee. The load-bearing section; every invariant carries its own *Why:*. |
| 3 | **REFUSAL CONDITIONS** | When it must fail **loudly**. Silence is the failure mode this kit is organised against. |
| 4 | **WHAT GREEN MEANS** | Observable and countable. *"It passed"* is not a definition. |
| 5 | **MINIMAL INTERFACE** | Information in, information out — **not** a command line. |
| 6 | **REFERENCE IMPLEMENTATION** | A pointer, with its `KIT-CLASS`, marked as one implementation. |

## The sheets

**How many are there?** `find process/contracts -type f | wc -l` — run it. A digit written here is
wrong the first time a sheet is added, and this kit has already been bitten twice by a transcribed
census (see [`../EXTRACTION.md`](../EXTRACTION.md) § The one rule about counting).

| Contract | Sheet | Implementation it describes |
|---|---|---|
| The verify gate | [verify-gate.md](verify-gate.md) | the one gate runner (MIXED — kit half only) |
| The board mover | [board-mover.md](board-mover.md) | the one way status changes |
| The landing gate | [landing-gate.md](landing-gate.md) | pre-merge gate, squash, state advance |
| Commit attribution | [commit-attribution.md](commit-attribution.md) | the write-time role guard (MIXED — kit half only) |
| Id minting | [id-minting.md](id-minting.md) | monotonic, collision-free identifiers |
| Issue / requirement creation | [issue-creation.md](issue-creation.md) | template + header contract |
| The archive sweep | [archive-sweep.md](archive-sweep.md) | retire, index, preserve |
| The drift report | [drift-report.md](drift-report.md) | the six checks as invariants |
| The auxiliary trunk checkout | [kanban-worktree.md](kanban-worktree.md) | publish to the trunk from anywhere |
| The release ritual | [release-ritual.md](release-ritual.md) | gates before the bump, publish after the push (MIXED — kit half only) |
| The liveness / watchdog ritual | [liveness-watchdog.md](liveness-watchdog.md) | a discipline, not a program |
| The configuration seam | [config-seam.md](config-seam.md) | one definition per adopter value |
| The initializer | [initializer.md](initializer.md) | configure, then **prove** |
| The role gate | [role-gate.md](role-gate.md) | declare the hat before mutating |
| Outbound notification | [notification.md](notification.md) | silent when unconfigured, never a gate |
| The process self-test harness | [self-test-harness.md](self-test-harness.md) | the tools tested in a sandbox (MIXED — kit half only) |
| The acceptance tier | [acceptance-tier.md](acceptance-tier.md) | which tests pin the PRODUCT — **non-travelling reference** |
| Retention completeness | [retention-completeness.md](retention-completeness.md) | a deletion under the retained area requires a same-change ledger row (MIXED — kit half only) |

**The first eleven rows are the minimum set** — the set the completeness rule treats as a floor.
The rows after them are **additions**, most justified by the rule that makes the set complete
(*every travelling script owes a contract, and those gates had none*), and one by the rule's mirror
image.

| Addition | Why it earns a sheet |
|---|---|
| The configuration seam | The one place an adopter edits — leaving it uncontracted leaves adoption itself undefined. |
| The initializer | Day one is a gate: it either proves the installation or it does not. |
| The role gate | The process's first rule ("confirm the hat") is otherwise enforced only by prose. |
| Outbound notification | Its contract is almost entirely *what it must NOT do* — be a gate, fail a caller, need configuration. |
| The process self-test harness | It carries the other half of the landing gate's test-only-marker invariant. |
| The acceptance tier | **The mirror-image case: the only artifact class with no travelling spec at all.** Its reference implementation is deliberately **non-travelling** (one test runner's marker), which is exactly why the invariants had to be written here — the whole *"a rewrite from the corpus is acceptable"* claim rests on a tier an adopter can reimplement. |
| Retention completeness | A travelling gate (the retention doctrine's one venue-change mechanism) that had no contract — the same rule that makes the set complete. |

Nothing in the minimum set was merged or split.

## The rules that hold this directory honest

- **Both directions want guarding**, and the guard is the **project's**, not the kit's: every
  travelling (`KIT`/`MIXED`) script has a sheet, and every implementation a sheet cites exists. A
  new gate with no contract should redden the build; so should a contract for a gate that is gone.
  Writing that guard in your own test runner is [`../EXTRACTION.md`](../EXTRACTION.md) § 4's
  standing debt, honestly stated: the contracts travel, a guard over them does not.
- **`PROJECT`-class files owe nothing** and no sheet may claim one — a contract over a file the
  adopter never receives reads as an obligation they do not have.
- **A `MIXED` file's sheet describes the KIT HALF only**, and says so in its own section 6.
- **Sheets are ≤ one page.** A sheet nobody finishes reading is not reimplementable.
- **The version-literal trap:** any example needing a version uses the obviously-fictional
  `42.x`, so no sample can be mistaken for a real version or rot into a lie when the real one
  moves.

**These sheets describe; they do not amend.** Where writing one reveals that an implementation
violates an invariant it should hold, that is recorded as a finding for whoever owns the backlog —
never fixed silently in the same change.
