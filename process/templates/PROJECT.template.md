<!-- KIT-CLASS: KIT — a blank shape. Travels unedited; every angle-bracket blank is yours to fill. -->
<!--
  HOW TO USE THIS FILE
  1. Copy to the repository root as PROJECT.md.  2. Fill every <angle-bracket> blank and delete
  every HTML comment.  3. Delete a section only when you can say why your project does not have
  it — an absent section is a decision, and the next reader should be able to see it was made.
  Blanks are <angle brackets>, the same convention .claude/templates/ uses. This file is
  HAND-FILLED: the initializer stamps .claude/templates/ and scripts/config.sh, not this one.
  Any version shown in an example is the deliberately fictional 42.x — never a real version.
  DROP THE KIT-CLASS MARKER above from your copy: it classifies this file for the kit, not for
  your project.
-->
# PROJECT.md — <project name>

**One paragraph, in the present tense: what this project IS.** Not the roadmap, not the pitch —
the sentence a stranger needs before reading anything else. This file is the **project-specific
half** of the process: [`process/MANUAL.md`](process/MANUAL.md) holds the transferable half, and
`CLAUDE.md` is the adapter that points at both — *on day one it is still the bootstrap stub, and you replace it with your adapter at `process/SEED.md` step 5.* Read this file at the start of every session.

## What <project> is

- **The problem it solves:** <one or two sentences>
- **What it is NOT:** <the adjacent thing people will mistake it for — this line prevents scope creep>
- **Who consumes it:** <human users / a downstream service / a library consumer / nobody yet>
- **Public surface:** <the CLI, the API, the endpoints, the screens — what a consumer actually touches>

## Stack & run commands

| What | Command |
|---|---|
| First-time setup | `<setup command>` |
| Run the tests | `<test command>` |
| Build / package | `<build command — or "N/A: nothing is packaged">` |
| Run it | `<run command>` |

<!-- State the language, the runtime version policy, and the dependency policy here.
     Example (fictional): "runtime 42.x; no new runtime dependency without its own decision." -->

## Quality bar

**What "good" means here, stated so a reviewer can apply it without asking.** Keep each line
checkable:

- <e.g. every public function has a test that pins its contract, not its implementation>
- <e.g. an error is loud: no silent fallback, no swallowed exception>
- <e.g. consumer-facing documentation is corrected in the SAME change as the surface it describes>
- <the drift guards you keep, if any — a doc that must move when a surface moves>

## Quality gates — and the contract each one implements

**Every row names its contract sheet.** The sheet states what must be TRUE; the command is *your*
implementation of it. Fill the command column; do not edit the sheet column — if a row has no
command yet, write `TODO` rather than deleting the row, so the gap is visible.

| Gate | Your command | The contract it implements |
|---|---|---|
| The verify gate — one runner, all gates, deterministic order | `<e.g. ./scripts/verify.sh>` | [`process/contracts/verify-gate.md`](process/contracts/verify-gate.md) |
| The landing gate — gate, squash, advance the board | `<e.g. ./scripts/finish-pr.sh ID>` | [`process/contracts/landing-gate.md`](process/contracts/landing-gate.md) |
| The board mover — the ONE way status changes | `<e.g. ./scripts/move-issue.sh ID STATUS>` | [`process/contracts/board-mover.md`](process/contracts/board-mover.md) |
| Commit attribution — the write-time role guard | `<e.g. the commit-msg hook>` | [`process/contracts/commit-attribution.md`](process/contracts/commit-attribution.md) |
| Id minting — monotonic, collision-free | `<e.g. ./scripts/next-id.sh>` | [`process/contracts/id-minting.md`](process/contracts/id-minting.md) |
| Issue / requirement creation | `<e.g. ./scripts/new-issue.sh>` | [`process/contracts/issue-creation.md`](process/contracts/issue-creation.md) |
| The drift report | `<e.g. ./scripts/check-board.sh>` | [`process/contracts/drift-report.md`](process/contracts/drift-report.md) |
| The archive sweep | `<e.g. ./scripts/archive.sh --apply>` | [`process/contracts/archive-sweep.md`](process/contracts/archive-sweep.md) |
| The auxiliary trunk checkout | `<e.g. the kanban worktree>` | [`process/contracts/kanban-worktree.md`](process/contracts/kanban-worktree.md) |
| The release ritual | `<e.g. ./scripts/release.sh — or "N/A: nothing is released">` | [`process/contracts/release-ritual.md`](process/contracts/release-ritual.md) |
| The configuration seam | `<where your adopter values live>` | [`process/contracts/config-seam.md`](process/contracts/config-seam.md) |
| The initializer | `<e.g. ./scripts/kit-init.sh>` | [`process/contracts/initializer.md`](process/contracts/initializer.md) |
| The role gate | `<how a hat is declared>` | [`process/contracts/role-gate.md`](process/contracts/role-gate.md) |
| Outbound notification (optional — silent when unconfigured) | `<e.g. ./scripts/notify.sh>` | [`process/contracts/notification.md`](process/contracts/notification.md) |
| The process self-test harness | `<e.g. ./scripts/test/run.sh>` | [`process/contracts/self-test-harness.md`](process/contracts/self-test-harness.md) |
| The liveness / watchdog ritual (a discipline, not a program) | `<how a long run is watched>` | [`process/contracts/liveness-watchdog.md`](process/contracts/liveness-watchdog.md) |
| The acceptance tier (a lens, never a gate — **no shipped implementation**) | `<how membership is marked in your runner — or "not adopted">` | [`process/contracts/acceptance-tier.md`](process/contracts/acceptance-tier.md) |
| Retention completeness (only if you retire documents under a ledger) | `<e.g. the pre-commit hook — or "N/A: park only">` | [`process/contracts/retention-completeness.md`](process/contracts/retention-completeness.md) |

**One row per sheet in [`process/contracts/`](process/contracts/README.md)** — and the count is the
directory listing, never a digit typed here. To prove every reference resolves before you copy this
file to the root, and to catch a sheet with no row, from the repository root:

```sh
# every sheet this table cites exists on disk
grep -o 'process/contracts/[a-z-]*\.md' process/templates/PROJECT.template.md | sort -u |
  while read -r p; do [ -f "$p" ] || echo "MISSING ROW TARGET $p"; done
# every sheet on disk is cited by this table
for p in process/contracts/*.md; do
  case "$p" in */README.md) continue;; esac
  grep -q "$p" process/templates/PROJECT.template.md || echo "SHEET WITH NO ROW $p"
done
```

A row you delete is a gate you have decided not to keep — say why in the row rather than removing
it silently.

### The binding gate

<!-- The one check that CANNOT be skipped, and the one whose absence has burned you.
     A unit suite is blind to whatever it stubs; name the check that is not blind, and the
     conditions under which it is mandatory. Doctrine: process/doctrine/live-resources.md. -->

- **Always binding:** `<the gate command>` green.
- **Binding for <the risky class of change>:** `<the check that is not blind — e.g. a live
  round-trip against a disposable target, restored to baseline afterwards>`.
- **Never:** <the thing that must never be the test target — e.g. a real customer record>.

## Credential doctrine

<!-- Delete only if this project genuinely touches no secret. -->

- **Where credentials live:** `<e.g. an ignored environment file — never committed>`.
- **Read vs write separation:** <which credential may mutate anything, and which may not>.
- **What a test may touch:** <the disposable target>; **never** <the real one>.
- **What the code may never do:** <e.g. request, widen or escalate a permission scope —
  a grant is a console action by a human>.

## Retained evidence

<!-- Delete only if you keep no evidence documents at all. Doctrine: process/doctrine/retention.md
     (park beats delete) and process/doctrine/staleness.md (the causing change pays the stamp). -->

- **Where evidence lives:** `<e.g. dev/, indexed by dev/README.md>`.
- **The rule:** **park beats delete** — when torn, park.
- **Retirement under a ledger:** `<the ledger path, or "not adopted — park only">`.

## Branching, trunk, and the board

- **Trunk:** `<trunk>` (default `main`) — a single trunk, resolved and confirmed from the remote's
  published default branch, never inferred.
- **Remote:** `<a hosted forge, or a local bare repository — both are supported>`
  *(see [`process/GIT-HOSTING.md`](process/GIT-HOSTING.md))*.
- **Work branches:** `<feature|fix|refactor>/<ID>-<slug>` — **one branch per work item, never per role.**
- **What counts as CODE** (and therefore needs a branch): `<the paths, as globs>`.
  Everything else — the board, the docs, this file — commits **direct to the trunk**.
  *(The rule: [`process/MANUAL.md` § The code-vs-metadata rule](process/MANUAL.md).)*

## Roles — active vs parked

| Role | Doc | Active here? | Why not (if parked) |
|---|---|---|---|
| PM | `.claude/roles/pm.md` | <yes/no> | <reason> |
| Dev | `.claude/roles/dev.md` | <yes/no> | <reason> |
| QA | `.claude/roles/qa.md` | <yes/no> | <reason> |
| Orchestrator | `.claude/roles/orchestrator.md` | <yes/no> | <reason> |
| Refactorer | `.claude/roles/refactorer.md` | <yes/no> | <reason> |
| Architect | `.claude/roles/architect.md` | <yes/no> | <reason> |
| <your own role> | `<doc>` | <yes/no> | — |

**The role set is a configuration seam**, not prose: whatever you decide here must match the role
set your commit-attribution guard enforces, and the board mover's whitelist, and the drift
report's scan. *(Authority:
[`process/contracts/config-seam.md`](process/contracts/config-seam.md) and
[`process/contracts/commit-attribution.md`](process/contracts/commit-attribution.md).)*
