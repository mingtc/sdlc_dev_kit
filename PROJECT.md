<!-- KIT-CLASS: KIT — the project-facts sheet, blank. Fill every <angle-bracket>; delete a section
     only when you can say why this project does not have it. -->
# PROJECT.md — <project name>

**One paragraph, in the present tense: what this project IS.** Not the roadmap, not the pitch —
the sentence a stranger needs before reading anything else. This file is the **project-specific
half** of the process: [`process/MANUAL.md`](process/MANUAL.md) holds the transferable half, and
[`CLAUDE.md`](CLAUDE.md) is the adapter that points at both — *on day one it is still the bootstrap
stub, and you replace it with your adapter at [`process/SEED.md`](process/SEED.md) step 5.* **Read
this file at the start of every session.**

## What <project name> is

- **The problem it solves:** <one or two sentences>
- **What it is NOT:** <the adjacent thing people will mistake it for — this line prevents scope creep>
- **Who consumes it:** <human users / a downstream service / a library consumer>
- **Public surface:** <the CLI, the API, the endpoints — what a consumer actually touches>

## Stack & run commands

| What | Command |
|---|---|
| First-time setup | `./setup.sh` |
| Run the tests | `<test command>` |
| Build / package | `<build command>` |
| Run it | `<run command>` |
| The whole gate, in order | `./scripts/verify.sh` |

- **Language / runtime:** `<name and version policy>`
- **Dependency policy:** `<e.g. no new runtime dependency without its own decision; state the
  narrow class, if any, that is exempt and why>`
- **What the tooling floor is:** `<the kit itself requires git + a POSIX shell; its two optional
  extras — the Python hygiene instruments and the Node visual companion — are deletable and never
  gates. Name anything else a contributor must have installed>`

> `./setup.sh`'s **kit half is real and working** in a fresh seed (git hooks, the board sanity
> check, the `.env` seed). Its **runtime half is a marked fill-in** — wire your language
> bootstrap and your test gate there before the first issue, because `./scripts/finish-pr.sh`
> refuses to land without an executable, committed gate runner.

## Build order — what is being built now, and what is deliberately not yet

> **Shipped role docs send a reader here for this and it was not here.** `pm.md` prioritises
> *"against the build order in PROJECT.md"*; `dev.md` and `orchestrator.md` name it as project
> context. *(An earlier draft of this note said "six shipped surfaces" — that was six grep HITS
> across three files, which is the population defect `staleness.md` § C is about, written into the
> sentence announcing a fix for the same class. Derive it: `grep -rl "build order" .claude/roles/`.)* This sheet's opening paragraph says *"not the roadmap"* — which is true of that
> PARAGRAPH and was read as true of the file, so the section its own consumers depend on was never
> written. **The distinction the opening means: not a dated plan with milestones. A build order is
> "what is in scope now", which is a project FACT and belongs here.**

**The current layer — what a new issue may be about:**

- <the surface or capability being built now>
- <the second, if there is one — keep this list short enough to be a filter>

**Deliberately NOT yet, and why:**

| Not yet | Why not, and what would change it |
|---|---|
| <thing> | <the condition that would pull it in — not a date> |

**Pulling something in means pushing something out.** Record the swap here when it happens; a layer
that only grows is not a filter and stops answering the question `pm.md` asks it.

*If your project genuinely has no ordering yet — day one, one surface, nothing deferred — write
that sentence here rather than leaving the section blank. A blank reads as unanswered; a sentence
reads as answered.*

## Quality bar

**What "good" means here, stated so a reviewer can apply it without asking.** Keep each line
checkable:

- <e.g. every public function has a test that pins its contract, not its implementation>
- <e.g. an error is loud: no silent fallback, no swallowed exception>
- <e.g. consumer-facing documentation is corrected in the SAME change as the surface it describes>
- <the drift guards you keep, if any — a document that must move when a surface moves>

## Quality gates — and the contract each one implements

**Every row names its contract sheet.** The sheet states what must be TRUE; the command is *your*
implementation of it. Fill the command column; do not edit the sheet column — if a row has no
command yet, write `TODO` rather than deleting the row, so the gap stays visible.

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
| The release ritual | `<e.g. ./scripts/release.sh>` | [`process/contracts/release-ritual.md`](process/contracts/release-ritual.md) |
| The configuration seam | `<where your adopter values live — e.g. scripts/config.sh>` | [`process/contracts/config-seam.md`](process/contracts/config-seam.md) |
| The initializer | `<e.g. ./scripts/kit-init.sh>` | [`process/contracts/initializer.md`](process/contracts/initializer.md) |
| The role gate | `<how a hat is declared>` | [`process/contracts/role-gate.md`](process/contracts/role-gate.md) |
| Outbound notification (optional — silent when unconfigured) | `<e.g. ./scripts/notify.sh>` | [`process/contracts/notification.md`](process/contracts/notification.md) |
| The process self-test harness | `<e.g. ./scripts/test/run.sh>` | [`process/contracts/self-test-harness.md`](process/contracts/self-test-harness.md) |
| The liveness / watchdog ritual (a discipline, not a program) | `<how a long run is watched>` | [`process/contracts/liveness-watchdog.md`](process/contracts/liveness-watchdog.md) |
| The acceptance tier (a lens, never a gate — **no shipped implementation**) | `<how membership is marked in your runner — or "not adopted">` | [`process/contracts/acceptance-tier.md`](process/contracts/acceptance-tier.md) |
| Retention completeness (only if you retire documents under a ledger) | `<e.g. the pre-commit hook — or "N/A: park only">` | [`process/contracts/retention-completeness.md`](process/contracts/retention-completeness.md) |

**One row per contract sheet — the whole of
[`process/contracts/`](process/contracts/README.md).** **The directory is the authority for the row
set, not this table:** if the kit you are running carries a sheet with no row here, add the row; if
a row here names a sheet your kit does not carry, delete that row and say so. A row you delete
because you have decided not to keep the *gate* is different — say why *in the row* rather than
removing it silently.

To prove every **contract-sheet** reference in this file resolves, and that no sheet is missing a
row, from the repository root. *It checks that class and no other:* command 1 greps only
`process/contracts/[a-z-]*\.md`, so this file's other references — the manual, the adapter, the
role docs — are outside it. Say what a check covers, or its green is read as covering everything:

```sh
# 1. every link points at a real sheet
grep -o 'process/contracts/[a-z-]*\.md' PROJECT.md | sort -u |
  while read -r p; do [ -f "$p" ] || echo "MISSING $p"; done
# 2. every sheet has a row here
for p in process/contracts/*.md; do
  case "$p" in */README.md) continue ;; esac
  grep -q "$p" PROJECT.md || echo "UNROWED $p"
done
```

### The binding gate

<!-- The one check that CANNOT be skipped, and the one whose absence has burned you.
     A unit suite is blind to whatever it stubs; name the check that is not blind, and the
     conditions under which it is mandatory. -->

- **Always binding:** `<the gate command>` green.
- **Binding for <the risky class of change>:** `<the check that is not blind — e.g. a live
  round-trip against a disposable target, restored to baseline afterwards>`. The doctrine is
  [`process/doctrine/live-resources.md`](process/doctrine/live-resources.md).
- **Never:** <the thing that must never be the test target — e.g. a real customer record>.

## The pre-cut sweep's surface list

**`process/doctrine/fix-execution.md` § A.4b requires a pre-cut sweep** before a release: one
fresh-context checker per **consumer-facing surface**, verifying that surface's claims against the tree
as it stands. **The sheet deliberately does not supply the list — it is yours, and this is its home**,
because a list kept in a crunch document dies when that document is struck.

**A COMMAND'S USAGE TEXT IS A SURFACE.** `--help` output, refusal messages and the remedies they
print are consumer-facing claims, they are the cheapest of all to falsify (run them), and they are
the ones a documentation-shaped surface list forgets — because they are not documents.

**Derive it from what a CONSUMER lands on, not from what you happen to edit.** That distinction is the
whole rule: scoping a sweep to *"the surfaces no diff touched"* sounds precise and inverts the risk,
because the edited set fills up with your highest-traffic documents and only ever grows.

| # | Surface | What a checker reads |
|---|---|---|
| 1 | `<your front door>` | `<fill: the files a newcomer opens first>` |
| 2 | `<your auto-loaded files>` | `<fill: whatever the harness reads at session start>` |
| 3 | `<add one row per surface>` | `<fill>` |

**Say, per row, whether it is one surface or one-per-file.** A directory of many small documents may be
one checker's job or many; the count changes the leg count, so **record which you chose rather than
leaving it to whoever dispatches.**

**§ A.4a is the other half and this list is not its job.** A.4a is per-change and one hop, searched by
**name** never by path. This list is only what the pre-cut sweep reads.

## Credential doctrine

<!-- Delete only if this project genuinely touches no secret. -->

- **Where credentials live:** `.env` at the repository root — **gitignored, never committed**.
  `.env.example` is the tracked template; copy it, fill it, never commit the copy.
- **Read vs write separation:** <which credential may mutate anything, and which may not — or, where your provider binds privilege to the account rather than to the token, that they cannot be separated, and where that open decision is recorded>.
- **What a test may touch:** <the disposable target>; **never** <the real one>.
- **What the code may never do:** <e.g. request, widen or escalate a permission —
  a grant is a console action by a human>.

## Retained evidence

<!-- Delete only if you keep no evidence documents at all. Doctrine: process/doctrine/retention.md
     (park beats delete) and process/doctrine/staleness.md (the causing change pays the stamp). -->

- **Where evidence lives:** `<e.g. dev/, indexed by dev/README.md>`.
- **The rule:** **park beats delete** — when torn, park.
- **Retirement under a ledger:** `<the ledger path, or "not adopted — park only">`.

## Branching, trunk, and the board

- **Trunk:** `<trunk>` (default `main`) — a single trunk, **resolved and confirmed, never
  inferred**; it must equal `<remote>/HEAD`.
- **Work branches:** `<feature|fix|refactor>/<PREFIX>-NNN-<slug>` — **one branch per work item,
  never per role.**
- **What counts as CODE** (and therefore needs a branch): `<the globs — the same list as
  CLAUDE.md § "The trunk, the branches, and what counts as code here", which is the authority>`.
  Everything else — the board, the docs, this file — commits **direct to the trunk**.
  *(The rule: [`process/MANUAL.md` § The code-vs-metadata rule](process/MANUAL.md).)*
- **The remote may be local-only.** A bare repository on disk is a fully supported `origin`; see
  [`process/GIT-HOSTING.md`](process/GIT-HOSTING.md).

## Roles — active vs parked

| Role | Doc | Active here? | Why not (if parked) |
|---|---|---|---|
| PM | `.claude/roles/pm.md` | <yes/no> | <reason> |
| Dev | `.claude/roles/dev.md` | <yes/no> | <reason> |
| QA | `.claude/roles/qa.md` | <yes/no> | <reason> |
| Orchestrator | `.claude/roles/orchestrator.md` | <yes/no> | <reason> |
| Refactorer | `.claude/roles/refactorer.md` | <yes/no> | <reason> |
| Architect | `.claude/roles/architect.md` | <yes/no> | <reason> |
| UI-Designer | `.claude/roles/archive/ui-designer.md` | no (parked) | <reason — un-park it by moving the doc out of `archive/`> |
| <your own role> | `<doc>` | <yes/no> | — |

**The role set is a configuration seam**, not prose: whatever you decide here must match
[`CLAUDE.md`](CLAUDE.md)'s roles table and the role alternation your commit-attribution guard
enforces. *(Authority:
[`process/contracts/config-seam.md`](process/contracts/config-seam.md) and
[`process/contracts/commit-attribution.md`](process/contracts/commit-attribution.md).)*

## The active / dormant table

<!-- What is being worked on, and what is deliberately asleep. One line each; this is the table a
     returning reader checks before the board. Keep it to surfaces / feature areas, not issues —
     issues live on the board. -->

| Surface / area | State | Note |
|---|---|---|
| `<area>` | <active / dormant / parked> | <one line> |
