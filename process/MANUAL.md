<!-- KIT-CLASS: KIT — transferable process. Carries no project law; see EXTRACTION.md. -->
# MANUAL.md — the operating manual

**KIT-CLASS: KIT.** This file is the **transferable** half of the process: a
**filesystem-as-kanban** board with **roles as hats**. It is written to be adopted by a
different project **unedited**. Every project-specific value it needs is a **pointer**, never
a value — see § The three documents and § Seams.

> **Illustrations.** Wherever this file shows a concrete value it is an **illustration and
> nothing more**. The issue prefix is written `<PREFIX>-`, the trunk is written `<trunk>` (the
> stated default is `main`), and the gate is written as *the project's gate command* — those are
> **configured values** (`scripts/config.sh`, the remote's published default branch, the project
> doc), not rules of the process. A sentence in this file that treats one of them as a fact is a
> defect; report it.
>
> This manual is **language-agnostic**. It names no runtime, no test framework and no packaging
> tool. Where a step needs one, it says *"the project's <thing>"* and the project doc supplies it.

---

## The three documents

| Document | Holds | Changes when |
|---|---|---|
| **MANUAL.md** (this file) | The process that travels: rituals, the board, the roles pattern, the Dev → QA boundary, branching, execution discipline. | The *process* changes. |
| **The project doc** | What the project is, its stack and run commands, its quality bar, its **binding gates**, its credential doctrine. | The *project* changes. |
| **The project adapter** | The project's own **law** — the rules that are true here and nowhere else — plus the concrete role set and commit-prefix table. It points at this file **first**. | The project's law changes. |

The adapter is the file the agent harness reads at session start, so it is the **entry point**;
this manual is what it points at. This kit's default names for those two are `PROJECT.md` (the
project doc) and `CLAUDE.md` (the adapter — *the kit ships a bootstrap stub at that path, which day
one replaces with the adapter*) — both named as configuration seams in
[`EXTRACTION.md`](EXTRACTION.md) § CONFIGURE, which is the only place a kit file is allowed to
know an installation's filenames.

**Read the project doc first, every session.** This manual tells you *how* work moves; only the
project doc tells you what "green" means here.

**The fourth thing, and it is not prose: [`contracts/`](contracts/).** This manual *describes* the
gates and rituals; `process/contracts/` states, per gate, what **any** implementation must
guarantee, when it must **refuse**, and what **green** means in countable terms — one page per
gate, indexed in [`contracts/README.md`](contracts/README.md), written for a reader who will
never open the scripts. It is the **machine-facing complement** to these pages: where a sentence here says *what we do*, the matching sheet says
*what must hold*, and its section 6 marks the shipped script as **one implementation, not the
definition**. **Where a sheet and any prose disagree, the sheet wins.** A project reimplementing this kit in another language owes the contracts, not the
shell. **Both directions want guarding** — a gate with no sheet, or a sheet citing a gate that no
longer exists — and the kit's self-test guards the first (`case_travelling_scripts_have_a_sheet`);
the second is still the project's to write.

Some sheets there are not about a script at all — read each one's § 6 for the set rather than trusting a count here:
[`contracts/acceptance-tier.md`](contracts/acceptance-tier.md) — **the acceptance (conformance)
tier**, the one artifact class that had no travelling spec until it was written. Its reference
implementation is deliberately **non-travelling** (one test runner's marker), so its invariants and
its three floor-guard assertions — non-empty selection, a count at or above a declared floor,
selection-neutrality — are the whole of what an adopter owes.

---

## Session start

1. **Read the project doc.** What the project is, the stack/run commands, the quality bar, and
   the binding gates.
2. **Check the board.** List the status folders (`ls progress/todo/ progress/in_progress/
   progress/dev_complete/ progress/qa_complete/ progress/blocked/ progress/declined/`) — each
   filename is `<PREFIX>-NNN-<slug>.md` (the prefix comes from `scripts/config.sh`); **the folder
   is the status**. `declined/` is terminal and usually short, and it is here rather than left out
   because a refusal you do not see is a refusal you re-argue. Run
   **`./scripts/check-board.sh`** for a drift report.
3. **Pick a hat.** Say which role you are wearing (see § Roles as hats). The role doc in
   `.claude/roles/` is your workflow. If the `require-role` hook is active (see
   `.claude/settings.json.example`), declare it by writing `.claude/session-role` first.

> **What goes in `.claude/session-role`.** **One line:** `<Role> <scope>` — e.g.
> `Dev <PREFIX>-001`; or, **only** when the operator has explicitly waived the hat,
> `none — operator override: <reason>`. The gate is **existence, not content**: the
> `require-role` hook allows any mutation once the file is present, and the line's job is to tell
> the next reader (and you, an hour later) which hat is on. The `session-start` hook **deletes
> the file at every session start**, so each session re-confirms its hat rather than inheriting
> the last one's. The path is a named variable on its own line in both hooks (`ROLE_REL`) so a
> guard can derive it instead of re-hardcoding it.

> First-time setup on a fresh clone: run the project's **bootstrap command** — the project doc
> names it (typically one script that creates the environment, installs the project, runs the
> gate, and wires the version-control hooks path).

## Roles as hats

Each role is a **hat** with its own workflow doc in [`.claude/roles/`](../.claude/roles/). One
person (or the Orchestrator) wears **one hat at a time**, and says which.

The **pattern** is fixed; the **cast is the project's**. A project declares its active roles —
one row per role, each linking its doc and naming what it owns — in the **adapter**, and the
adapter's table is the source of truth for which hats exist. This kit ships the role docs under
`.claude/roles/` plus an archive of parked ones; `ls .claude/roles/` is the list;
adding, parking or renaming a hat is a project decision, made in the adapter and in
`.claude/roles/`.

**Session topology — who owns a session, and how many hats it wears.** A **session belongs to
whoever holds the seat**: one actor, one working context, one hat at a time. **Each dispatched
worker leg wears exactly ONE hat for its task and commits under that hat's prefix** — a leg that
implements does not also review its own work. **The seat (or the orchestrator) narrates under its
own prefix and never wears its workers' hats for their work**: coordination commits carry the
coordinating prefix, and the Dev/QA commits its workers make carry theirs. And **a hat declaration
is SESSION STATE, never repository content** — whatever holds the declaration is excluded from
version control by the initializer, not left for each actor to discover
([`contracts/role-gate.md`](contracts/role-gate.md) § 2).

## Execution discipline

1. **Confirm the hat before changing anything.** Read-only work needs no hat; a repo mutation
   does. (The `require-role` PreToolUse hook enforces this when activated.)
2. **And the two hard parts of doing that have their own sheet.** Briefing a subagent that has none
   of your context, and deciding what to believe from work nobody watched, are
   [`doctrine/subagent-control.md`](doctrine/subagent-control.md): name the specific thing to attack
   and hand over the failure history; read every brief for the pair of demands that cannot both be
   satisfied; and **never relay a leg's self-report as a measurement** — it arrives with its own
   evidence, or it is re-measured.

   **The Orchestrator does not write code itself.** It **spawns a Dev-hat subagent** to
   implement (TDD, failing test first) and a **QA-hat subagent** to verify, then **checks their
   work** against the AC and the gates before advancing the board. Orchestrator commits are
   **narration only**; the actual Dev/QA commits carry the Dev/QA prefixes.
3. **Prove work before claiming done** (`verification-before-completion`). "Looks right" is not
   evidence; a passing test, a diff, or a real round-trip result is. **And the evidence is only as
   good as the instrument that produced it** — a guard nobody has watched *fail* is not information,
   and an audit that returns no violations has not shown it could find one. The rules for that are
   [`doctrine/instruments.md`](doctrine/instruments.md): measure the instrument against the shape it
   will meet, give every green an ablation, and name each instrument's blind spot in its own output.

   > **Where the named practices live.** `verification-before-completion`, `requesting-code-review`,
   > `test-driven-development`, `systematic-debugging` and the rest are **skills**: one directory
   > each under [`.claude/skills/`](../.claude/skills/), holding a `SKILL.md` that is the
   > workflow, invoked by name. The role docs chain them (most carry a *"Skills used in
   > this role"* section); `.claude/skills/README.md` is the index. **Which skills exist is a
   > project decision** — when this manual names one it is naming a *practice*, and a project without that skill
   > directory still owes the practice.
4. **Liveness discipline, and it is TWO rituals with different scopes.** **(i) DURATION —
   *is this long run still alive?*** Any background run expected to exceed ~30 minutes gets a
   **watchdog armed at launch**, and liveness = **artifact freshness, never absence-of-news** —
   a hang is silent, so only growth proves life. Key the watchdog on a signal that actually
   moves mid-run: a workflow's transcript-file mtimes (**resolve symlinks first — `stat -L`**; a
   symlink's own mtime never moves, so an unresolved probe false-alarms forever), or the worker
   **process itself** (CPU-time deltas across ~10-minute samples, plus
   exited-without-completion-marker). **Never key on a pipe-buffered output file** — `… | tail
   -1` cannot grow mid-run, so it false-alarms by construction. An alert is a trigger to
   **probe, not to conclude**: a zero-CPU sample a few seconds long can be a throttle/settle
   sleep — distinguish sleep from hang (a longer CPU-delta window, open connections, a stack
   sample) before reporting anything. Every status statement about an unfinished run rests on a
   fresh probe: *"no news sometimes is not good news."*
   **And the run that armed it retires it, in the act that ends the run** — by **enumerating what
   this run armed** and walking that list, never by walking the handles you happen to hold. A
   teardown made of pids and session directories cannot retire a scheduled wake-up, which has
   neither, and the party likeliest to hold one is the party running the teardown; `ps` cannot see
   it, so confirming retirement means **reading the scheduler back**. Walking an empty enumeration
   is a normal close. (**The ~30-minute scope and this retirement are both the DURATION half only**;
   the absence watchdog below is armed once and never disarmed, because the project has no end.)
   **(ii) ABSENCE — *has work stopped moving?* This one is N/A for nobody, and the ~30 minutes
   above does not scope it.** Its signal is the **newest committer date across every head on the
   remote** — never `HEAD`, never the checkout: `HEAD` is one branch in one worktree, and this
   process moves work between refs constantly. The signal must be a
   **by-product of work** — an empty commit or a heartbeat line moves it, and a check you can
   satisfy by editing the answer is not one. The threshold is **relative to the run's declared
   cadence**, never a fixed number. **And it needs a reader that is not the party being watched**:
   a signal nobody reads is absence-of-news one level up, which is what the discipline it replaces
   already forbade. `scripts/notify/stall.sh` is the shipped one.
   *Why two:* a project read the ~30-minute scope honestly, had no runs that long, declared the
   ritual not applicable — and the failure that arrived was not a hang but work stopping, three
   times, with nobody watching.
   (The contract sheet is [`contracts/liveness-watchdog.md`](contracts/liveness-watchdog.md), and
   its § 1a is the split.)
5. **Preserve the reason, supersede only the conclusion.** When new evidence overturns a
   recorded decision, amend it — do not erase it — per
   [`doctrine/supersession.md`](doctrine/supersession.md), which is the **single statement** of
   that rule (and of the `superseded_in_part` spec-annotation convention that follows from it).
   This line is a pointer, not a second copy: a rationale-free strike is what causes the
   settled argument to be re-litigated.
6. **Record the ruling where it is looked up — in the same change.** A PM/seat ruling that changes
   behavior, **and any measured integration-time discovery**, gets its entry in the project's
   **decision register** — or in the corpus home it already has — **in the same change**, not only
   an issue-file note. (This kit's default register is
   [`../requirements/DECISIONS.md`](../requirements/DECISIONS.md), which ships as its own blank; an
   installation may name its own.) An issue's Activity log records *that issue*; a reader asking *what is currently
   true* reads the register, and a ruling promised to it "later" is a ruling that stays scattered.
   The register is a **projection of current state** — current ruling, one line of why,
   provenance — and the history stays in the ledger, which is what keeps it compatible with item 5
   rather than a second archive.
   **And *"the corpus home it already has"* has a boundary, which is the fork/fact split:** a
   **fork** — two defensible answers existed and one was chosen — is a register entry under a `D-NN`;
   a **fact** — what the product does changed, with no fork — amends the PRD. The diagnostic, the
   overlap rule (*cite the id, never inline the text*) and the anchored citation marker are stated
   once in [`../requirements/DECISIONS.md`](../requirements/DECISIONS.md) § *Which decisions
   live HERE*, and this line points rather than restates: **this item stays the single authoring
   site for the *when*, the register for the *which*.** Without a boundary the clause is an unbounded
   escape — every decision has *some* home it could be argued into, and a home argued into after the
   fact is the one nobody thinks to read.

## Session close ritual

- Every issue you touched is in the folder that matches its real status (folder is the source
  of truth; the Activity log must agree).
- `progress.md` has your session's entries (decisions, deviations, QA verdicts).
- Each session's `progress.md` entries sit under one dated `### YYYY-MM-DD [Role] <title>`
  heading, **forward-only** — history is not rewritten.
- Run `./scripts/check-board.sh` — resolve any drift it reports.
- **The local trunk ref is not ahead of `<remote>/<trunk>`** — `refs/heads/<trunk>` measured
  against `refs/remotes/<remote>/<trunk>`. Everything the process records as metadata commits
  direct to the trunk, so an `ahead` here is rulings, specs and board edits nobody else can see.
  `check-board.sh` arm `[f1]` is that reading, and it prints the push command that clears it.
  Note what is **not** asked: nothing about `HEAD` — a dispatched leg legitimately holds the
  checkout on a work branch, so a HEAD-vs-trunk comparison would redden on every orchestrated
  run — and `behind` is a stale view rather than a finding.
- If `progress/qa_complete/` is over the threshold, run `./scripts/archive.sh --apply` and
  the sweep commits and pushes itself.
- **Kit feedback, unless `PROJECT.md` sets `kit-feedback: manual` or `off`:** answer the session-close questions and end your `progress.md` entry with `kit-feedback: none` or `kit-feedback: K-NN[, K-NN…]` — `process/MANUAL.md` § Kit feedback.

## Kanban rules

- **The folder is the status.** Move an issue with **`./scripts/move-issue.sh <ID> <target>
  --role <Role> --note "…"`** — never by hand, and never duplicate status into frontmatter.
  The target set is the **status folder set** (a configuration seam — see
  [`EXTRACTION.md`](EXTRACTION.md) § CONFIGURE); a stock installation ships
  `todo | in_progress | dev_complete | qa_complete | blocked | done | declined`.
- **`declined/` is where a refusal lives, and the reason is the point.** A card that was
  considered and rejected has nowhere else to go: left in `todo/` it misrepresents itself as
  pending work, and deleted it takes its reasoning with it — so the next person to propose the
  same thing starts from zero. The mover therefore **requires `--note` for `declined/`**, exactly
  as it does for `blocked/`: *a decline with no recorded why is a deletion with extra steps.* It is
  terminal and **not swept** (its value is being browsable), and `check-board.sh` reports its depth
  as a **count only** — a decline is not drift and never turns a green board red.
- Every move **appends an Activity line** to the issue file and **commits + pushes to the
  trunk** (via the kanban worktree — see § The kanban worktree), so the board is accurate on
  the trunk without a checkout.
- **Create** issues with `./scripts/new-issue.sh` / `new-bug.sh` / `new-refactor.sh` (id from
  `./scripts/next-id.sh`), specs with `./scripts/new-prd.sh`. Subtasks (Orchestrator
  decomposition) with `./scripts/subtask.sh`.
- **A newly created issue is not published.** Creation is inert by contract
  ([`contracts/issue-creation.md`](contracts/issue-creation.md) § 2) and the board mover reads
  the **published** board — so commit and push a new issue before trying to move it.
- Do **not** pre-write the product backlog; issues enter through a real PM session.

## The default path is lite — full ceremony is for feature-area work

**Default (lite) — small, well-understood work:** for **code**, `issue → branch → TDD →
finish-pr`: create one issue (`new-issue.sh`), work it on a work branch, TDD, land via
`finish-pr.sh`. For a **pure docs/process change** there is no branch to squash — it commits
**direct to the trunk** (per § The code-vs-metadata rule) and lands via `move-issue.sh <ID>
qa_complete` instead of `finish-pr.sh`. Either way: **no spec, no subtask tree** — a one-file fix
should cost **one issue, not five artifacts.**

**This rule does not repeal day one's `PRD-001`.** [`SEED.md`](SEED.md) step 6 mandates a real PM
session minting `PRD-001` because that spec **scopes the PRODUCT** — the one thing no subsequent
issue can establish. **The lite rule above governs SUBSEQUENT small work**, not the product's own
scoping. A reader meeting both texts and concluding one is wrong has found a silence, not a
contradiction: both stand, and neither weakens the other.

**Full ceremony — feature-area-scale work only.** A spec in `requirements/` (PM → `write-spec`),
story→issue decomposition, and subtask trees are reserved for a **feature area spanning multiple
issues**. Reaching for that machinery on a small fix is **visible over-process**.

**Opt-in — off unless you turn it on:** notifications (`notify.sh`; with the backend unset it is
a silent no-op), the harness `require-role` / `session-start` hooks (shipped as
`.claude/settings.json.example`), and specs / subtasks (above).

**Never optional — the binding gates.** Every project has a small set of gates that are run on
**every** change and are never traded away; **the project doc names them**, and the project's
one-shot gate runner (`./scripts/verify.sh`) is how they are invoked so that no role re-derives
a command from prose. Two rules about them are the kit's, not the project's:

- **The gate set is the project doc's to define and nobody's to skip.** A role may add rigor,
  never subtract it.
- **A green unit suite is a floor, not a ceiling.** Where a project's behavior is only
  observable against a live external system, the project doc declares an additional **binding
  round-trip check** for changes that touch that surface, and a green offline suite alone is not
  a PASS for them. The discipline for such a check — a disposable target, never a real one, and a
  restore to baseline afterwards — is
  [`doctrine/live-resources.md`](doctrine/live-resources.md).

Calibrate rigor to the change via the **rigor-tier ladder** in
[`doctrine/rigor-tiers.md`](doctrine/rigor-tiers.md).

**Why:** the process serves the product, not the reverse. Run the full chain when the risk earns
it; take the lite path otherwise.

## The Dev → QA handoff (the boundary)

The one hard boundary in the process. Dev hands a `dev_complete/` issue to QA; QA lands it or
bounces it.

1. **Dev reaches `dev_complete`.** Work branch pushed; the project's gates green; self-review
   done (`requesting-code-review` / `verification-before-completion`). Dev moves the issue
   `in_progress → dev_complete` with a note.
2. **QA reads context.** The issue file, its AC, and the linked spec stories. **AC is the
   contract** — anything not in AC is out of scope for this review.
3. **QA checks out the branch** (`git switch <branch>` from the issue's `branch:` frontmatter, or
   the Dev's worktree when it still holds the branch — `.claude/roles/qa.md` step 2) and runs
   **`./scripts/verify.sh`** — the **full** run, not a narrowed one. Anything red that isn't
   pre-existing → **FAIL outright**, Dev fixes first. **If the branch changes the gate runner, the
   trunk's copy is the gate**, as it is at landing; `.claude/roles/qa.md` step 3 has the command.

   **QA reads and gates on the branch, and WRITES on the trunk.** The issue file is metadata by
   § The code-vs-metadata rule, and `move-issue.sh` has already edited that same card on the trunk
   — a coordinator writing the trunk while a worker holds a branch being *expected, not a race*
   (§ The kanban worktree). Append review evidence to the card from the trunk, never from the
   branch you just switched to: **where the branch was cut BEFORE the board move** — the ordinary
   case, since the move to `dev_complete` happens at step 1 and the branch predates it — the branch
   carries the card's pre-move text, so two edits to one card in two lanes collide at the
   squash-merge and `finish-pr.sh` refuses the landing. (A branch rebased onto the trunk after the
   move merges the card cleanly; that is the exception, not something to rely on.)

   **Name the lane the run was in — and where the change's operands straddle the lanes, quote the
   SET.** A gate run is a reading of **one** commit lane, and an exit code does not say which one.
   Where the operands are only jointly satisfiable, the branch run is the proof of ALL-NEW and the
   trunk is **expected** to be ALL-OLD until the merge; both are quoted, separately, and neither
   alone closes the handoff. *(The rule:
   [`doctrine/commit-hygiene.md`](doctrine/commit-hygiene.md) § A.5.)*
4. **QA walks the AC line by line**, recording `PASS`/`FAIL` per bullet with **concrete
   evidence** (a test name, a diff, a command's output, a payload shape). **An illustrative
   example inside an AC must cite its source or be labelled approximate** — an uncited example
   is read as the contract, and when it is wrong the review has no honest verdict left except the
   third one below. Meeting one, check the example against its source before grading the bullet.
   **An AC whose deliverable is prose describing code behaviour is graded claim by claim**: each
   behavioural claim is tied to a falsifier the suite resolves or checked against the code at a
   named `file:line`. A claim that can be neither leaves the bullet unmet — `FAIL_AC`, naming the
   claim — and *"it is a description"* does not excuse it. Prose that makes no claim about
   behaviour is outside this rule.
   <!-- RULE-COPIES:BEGIN — deliberate copies of the behaviour-describing AC rule; the self-test holds them.
   key: prose describing code behaviour
   copies: .claude/roles/qa.md .claude/roles/dev.md .claude/templates/ISSUE.template.md .claude/workflows/wave-runner.js .claude/workflows/tranche-runner.js
   RULE-COPIES:END -->
5. **QA runs the binding cross-cut check.** For any change touching the surface the project doc
   declares binding, run the project's **live round-trip check** and restore the fixture it used
   to baseline. A green unit suite alone is not a PASS for that surface.
6. **QA decides. THIS LIST IS THE AUTHORING SITE FOR THE VERDICT VOCABULARY** — four members, each
   with a stable token, **plus a separate and orthogonal statement about whether the change
   landed.** Every schema, runner and report that carries a verdict **projects this list**; none of
   them re-enumerates it.

   | Verdict | Token |
   |---|---|
   | PASS | `PASS` |
   | FAIL on AC | `FAIL_AC` |
   | FAIL on regression | `FAIL_REGRESSION` |
   | PASS-with-AC-correction — an AC's *illustration* was wrong, never its *requirement* | `PASS_AC_CORRECTED` |

   **And `landing` is its OWN field, not a fifth verdict and not a boolean:**
   `landed` · `deferred` · `not_applicable`.

   **And `premise_refuted` is a THIRD axis, optional, orthogonal to both.** An issue can be
   implemented exactly as written, land green, and have **its own stated premise refuted by the
   measurement it produced.** That is not a failure — it is often the most valuable thing a run
   produces — and it is not a verdict, because the work was correct, and not a landing, because it
   landed. **Given no field of its own it has nowhere to go but a commit subject**, where nothing
   aggregates it and no report can ask for it.
   *When present it carries three things:* what the issue assumed · what was measured instead ·
   where that measurement is recorded. *Absent means the premise stood.* **Absent, not empty** — an
   empty string asserts that something was refuted and then names nothing.
   *Why a third axis rather than one more outcome token:* an outcome token would conflate *what
   happened to the issue* with *what the run learned*, which is exactly the conflation this step
   avoided when it split verdict from landing. The same argument, one axis further out.

   **Why the two are separate, stated because collapsing them has already cost a run.** *Did the
   review pass* and *did the change reach the trunk* are two different facts, and a machinery schema
   that carried `verdict: PASS|FAIL` plus `landed: boolean` **could not represent a green review
   whose landing was correctly deferred** — so it read one as a failure and **halted a run that had
   succeeded.** `not_applicable` is the third value because a docs-path issue has no landing script
   to complete: a boolean forces that case to lie in one direction or the other.

   **A gate that could not RUN produces no verdict at all.** If the gate runner reports that a gate
   never executed, there is no evidence about the implementation, so there is nothing for any of the
   four tokens to be true of — this is a **precondition failure that halts before a verdict is
   formed**, reported as itself. Do not reach for `FAIL_AC` or `FAIL_REGRESSION`: both assert
   something false about the code. *(This is why the gate runner names an unrunnable gate in its own
   word rather than spelling it as a failure — `contracts/verify-gate.md` § 3.)*

   **An AC that names a gate the tree under review does not hold is the same precondition failure,
   and one the runner cannot report.** The gate is either missing from the gate runner, or its
   machinery is absent — for example, still on an unlanded branch. A gate absent from the tree is not
   one the runner "could not run", so its summary stays clean. Do not grade that AC from other
   evidence. Either run the gate against a tree that holds **both** this change and the gate — for
   example, this branch's diff applied onto the tree that carries the gate — or halt before a verdict
   and report the precondition failure, naming the AC. Whoever runs it names that tree and commit:
   Dev in the `dev_complete` note, QA in the review evidence on the issue file.

   **A review leg that returns no verdict is the same precondition failure, one layer out.** When
   an orchestrated run's review leg — of the issue, or of its **park** — comes back with nothing
   (the agent returned nothing: it died or was skipped) or with a value outside the four tokens,
   the **last** review formed no verdict. The runner reports **`NO_VERDICT`** (§ The RUN-OUTCOME vocabulary, below) and halts.
   It does not spend the fix round on it, and it never files it as `FAILED_AFTER_FIX_ROUND` — or,
   for a park, as `PARK_UNVERIFIED` — both of which assert a FAIL that was never formed. The issue
   (or the park) is unreviewed as it now stands: the next move is a review, not a fix. **A reviewer
   that stops on a precondition failure says so in the structured result itself:** a runner's review
   schema carries an optional `precondition_failure` field, and `verdict` is no longer required.
   A reply that names one is `NO_VERDICT` whatever token came with it — the precondition failure
   says no verdict was possible, so a token beside it was invented to fill a slot. It is a separate
   field and not a fifth token, so the four above stay the whole verdict vocabulary.

   The four, in full:
   - **PASS** — *all* of: every AC PASS with evidence; suite green (no new failures vs the
     trunk); no `Blocker`/`Critical` bug; adjacent shipped behavior still works (a `Major`/`Minor`
     break there is filed, not failed — next bullet but one). Action:
     `./scripts/finish-pr.sh <ID>` (squash-merges the branch into the trunk locally, deletes the
     branch, advances `dev_complete → qa_complete`). Append `progress.md`:
     `YYYY-MM-DD [QA] review of <ID>: PASS — landed.`
   - **FAIL on AC** — one or more AC bullets unmet. Move the issue back to `in_progress` with a
     note listing the unmet AC; Dev resumes on the same branch.
   - **FAIL on regression** — a previously-green **test** broke, at any severity (a red suite), or
     shipped behavior the suite does not cover broke **at `Blocker` or `Critical` severity**. **File a
     bug** (`./scripts/new-bug.sh`), link it via `discovered_in`, and move the issue back. A
     `Major`/`Minor` break in uncovered behavior does not fail the review: file it the same way and
     PASS, citing it in the landing note; PM decides defer-or-fix.
   - **PASS-with-AC-correction — THE THIRD VERDICT.** The implementation is **right** and the
     AC's own **illustration** is **wrong**: the code does the correct thing, and the example
     baked into the acceptance criterion asserts something the source does not support. Three
     parts, all three required: **(1) land it** — the work is correct, and bouncing it would use
     the process to argue the product into the plausible-wrong answer the specification exists to
     prevent; **(2) amend the AC** in the issue file, replacing the wrong illustration with the
     corrected one **and its source**; **(3) leave a PM note** — the ruling is the PM's to keep,
     and a silently-corrected AC teaches nobody.
     **Verify before you invoke it.** This verdict is only available when you have
     **checked the fact yourself** against a citable source; "the AC looks off to me" is a FAIL
     or a question, never this. And it applies to an AC's *illustration*, never to its
     *requirement*: if the AC asks for the wrong **behavior**, that is a PM decision, not a
     reviewer's correction.
     <!-- RULE-COPIES:BEGIN — deliberate copies of this verdict's precondition; the self-test holds them.
     key: checked the fact yourself against a citable source
     copies: .claude/roles/qa.md .claude/workflows/wave-runner.js .claude/workflows/tranche-runner.js
     RULE-COPIES:END -->
7. **Archive.** When `qa_complete/` accumulates, `./scripts/archive.sh --apply` sweeps issues
   into `progress/done/` and indexes them in `ARCHIVE.md`. **It commits and pushes itself** — do not look for a staged diff.

### The RUN-OUTCOME vocabulary (an orchestrated run's summary of one leg)

**THIS LIST IS THE AUTHORING SITE FOR THE RUN-OUTCOME VOCABULARY.** Every runner and every report
that carries an outcome **projects this list; none of them re-enumerates it.** It is placed here, as
a sibling of the verdict table above, because an outcome is **composed from** a verdict and a
landing — not because the handoff produces one. The handoff produces the two inputs; an orchestrator
produces this.

| Outcome | Composed from | Meaning |
|---|---|---|
| `LANDED` | verdict PASS · landing `landed` or `not_applicable` | reviewed green and the change is on the trunk, or had nothing to land |
| `LAND_READY` | verdict PASS · landing `deferred` | reviewed green, landing correctly not attempted — **a SUCCESS** |
| `PARKED_OK` | — | parked, **and the park itself was verified** |
| `PARK_UNVERIFIED` | — | parked, park not verifiable as written — the LAST park review returned a FAIL verdict |
| `FAILED_AFTER_FIX_ROUND` | verdict FAIL · the one fix round did not bring a PASS (a second FAIL, or a fix Dev that answered `blocked`) | failed, and the one fix round did not cure it |
| `BLOCKED_DEV` | — | Dev could not proceed and the issue is not parkable |
| `NO_VERDICT` | no verdict formed — step 6's precondition failure, not a verdict · no landing | the last review leg — of the issue or of its park — returned nothing, a value outside the four tokens, or a named `precondition_failure`: **unreviewed, not failed** — halts |
| `LEG_ABORTED` | — | a leg's call THREW — the run's token budget ran out, or the call was refused — or a Dev leg returned nothing (or a status outside its schema), before the issue reached an outcome: **state unknown, not failed** — halts |

**`LANDED` and `LAND_READY` are both verdict PASS** and differ only in whether the landing happened.
That is why a gate treats both as success, and it is the composition rule that makes the next
sentence enforceable:

> **A new member that encodes a verdict the table above does not have is a second verdict
> vocabulary wearing another name.** Before adding one, say which verdict and which landing it is
> composed from. If you cannot, the thing you need is a verdict, and it belongs in § step 6.

**`NO_VERDICT` is composed from the ABSENCE of a verdict, and that is not a second verdict
vocabulary** — it encodes no verdict at all. It is step 6's precondition failure (*"halts before a
verdict is formed, reported as itself"*) surfacing at the outcome layer, where a runner otherwise
had only `FAILED_AFTER_FIX_ROUND` — composed from a verdict FAIL — to spend on it, and filing it there
asserted a FAIL verdict that was never formed. So the test above is met rather than waived: the composition is
*no verdict · no landing*, and the thing it names already exists in step 6.

**A fix Dev that answers `blocked` leaves the issue `FAILED_AFTER_FIX_ROUND`, not `BLOCKED_DEV`**
(one that returns nothing, or a status outside its schema, is `LEG_ABORTED`, below). The issue holds a
formed FAIL verdict and has spent its one fix round; there is no second
(`process/doctrine/fix-execution.md` § A.5c). `BLOCKED_DEV` says the issue is not parkable, which a
fix Dev's report cannot make true, and the record already carries that Dev's reply.

**`LEG_ABORTED` is not `NO_VERDICT`, and the difference is what the next move is.** `NO_VERDICT` is
about the issue: its last review leg came back and graded nothing, so the next move is a review.
`LEG_ABORTED` is about the run: a leg's call **threw** — any leg, Dev or review — which the runtime
does once the turn's token budget is spent, or a **Dev** leg returned nothing (skipped, or dead on a
terminal error). Either way the issue is in whatever state that leg left it, possibly half-done, and
the next move is to inspect the issue and resume the run, not to review it. A Dev leg that returned
nothing is not `BLOCKED_DEV`: that is a status Dev *reports*, and this Dev reported nothing.
It is marked "—" because it is composed from no review verdict and no landing: the leg that threw,
or the Dev leg that returned nothing, reported nothing. **A throw from the runner's own code is not a leg aborting**: it is a defect in
the runner, and the run fails loudly rather than filing it as an outcome. (What the runtime raises
at the agent call itself — a budget ceiling, a refused call, or a schema it cannot satisfy — is
filed as `LEG_ABORTED`, since it surfaces there; the record's `error` says which.) **Both halt, and no
runner ever drops an issue:** one outcome per dispatched issue is the invariant a run report stands
on. A runner that loses an issue — a wave runner once filtered a thrown leg out of its results, and
then judged the wave by what was left — reports green over work nobody finished.

**What a runner returns for each issue, and why the free text rides on every outcome.** Each record
is `{ id, outcome, … }`, plus the fields its outcome needs: `error` on `LEG_ABORTED`, the replies
of the legs that decided it on a failure or a park (`dev`, `qa`, `park`), and `qa_evidence` and
`gates` on `LANDED` and `LAND_READY`. **Every record with an outcome also carries `leg_notes`**: one entry per leg
that replied, in call order — `{ leg, summary, deviations, notes, premise_refuted,
precondition_failure }`, each field present only when the leg filled it. It is on the success path
on purpose. A success used to return nothing a leg had written, so a caveat, a surprise or a kit
finding reported there never reached the orchestrator — and `premise_refuted`, the axis that exists
so a PASS/landed issue can say what it learned, was lost on the one outcome it was designed for. A
leg that threw or returned nothing adds no entry; the legs before it keep theirs.

**Why this needed ratifying rather than living in the runners.** The orchestration runtime grants
those files no imports (a child workflow can pass data, at a cost the kit declines), so the vocabulary
is **hand-copied** into each one. A guard can
hold the copies equal to each other, and that is worth having — but two copies agreeing is not the
same as either being right, and a pair that drifts together drifts silently. An authority outside
both is the only thing that makes the guard a *pin* rather than a *comparison*.

### The direct-to-trunk lite variant (docs / process / metadata issues)

The steps above are the **code-work** boundary — they assume a pushed work branch and a `git
switch` to it. An issue that touches **none of the project's code paths** (see § The
code-vs-metadata rule) — a docs, process, role-doc, script, or other metadata change — is worked
**direct on the trunk**: Dev commits the change straight to the trunk with a Dev prefix, then
`move-issue.sh <ID> dev_complete`. **QA verifies on the trunk itself** — there is **no branch to
check out** and **no `finish-pr.sh`** (nothing to squash-merge) — and lands the issue with
`./scripts/move-issue.sh <ID> qa_complete --role QA --note "…"`. Steps 2 (read context), 4 (walk
the AC) and 5 (the binding cross-cut check, where applicable — usually N/A for a metadata
change) still apply; steps 1/3/6-PASS are the branch-only parts that collapse. Code work keeps
the full branch-based boundary.

### Bug-severity calibration

The labels are defined in [`.claude/roles/qa.md`](../.claude/roles/qa.md) § Severity scale.
A `Blocker` or `Critical` blocks the PASS; a `Major` or `Minor` is filed as a follow-up.

---

## Branching and role attribution

**Trunk-based development with work branches.** A project's version-control policy is **its
own**: a sibling repository's habits (everyone-on-one-branch, long-lived release branches, a
forge-PR ceremony) are not inherited by proximity. What follows is the kit's policy; a project
that departs from it says so in the adapter.

**The invariant:**

- **Code work lives on per-work-item branches** — `feature/<ID>-<slug>`, `fix/<ID>-<slug>`,
  `refactor/<ID>-<slug>`, where **`<ID>` is the work item's id — `<PREFIX>-NNN`, the same
  vocabulary the board uses** (§ Kanban rules).
  **Never per-role branches.** One branch per issue.
- **Kanban state + metadata commit to the trunk.** The board moves, spec/issue edits, role-doc
  updates, refactor/design pass docs, `progress.md`, the project doc and the adapter all commit
  **directly to the trunk** with a role-prefixed message. Only **code** goes through a work
  branch.
- **The trunk is single** — one branch, no trunk/release split. The trunk name is **resolved and
  confirmed from the remote's published default branch** by the kanban scripts (never guessed);
  the project doc declares it in prose, and `<trunk>` defaults to `main` when a project has no
  reason to prefer another name.

> **A remote may be entirely local.** The kit needs *a* publication target, not a hosting
> product: a bare repository on the same disk satisfies every contract here. Hosted forges are an
> **optional extra** — [`GIT-HOSTING.md`](GIT-HOSTING.md) covers both.

### The code-vs-metadata rule

The split above needs exactly one project-supplied definition: **which paths are code.** The
adapter states it (typically the source tree, the test tree and the build/packaging manifest).
Everything else in the repository is **metadata** and commits direct to the trunk. The rule is
mechanical on purpose — "is this file in the project's code paths?" is answerable by a `git
diff --name-only`, and a boundary you can compute is a boundary that survives a busy session.
*"Direct to the trunk"* names the trunk **ref**, not a checkout: a commit made on the trunk branch
from a linked worktree lands there just the same, and since git by default lets only one worktree
hold that branch at a time, the checkout that gives it up can simply be detached rather than moved
to a branch of its own — though not while a leg is working from that checkout (§ The kanban
worktree).

**Metadata MAY ride its code branch when it is part of the same change.** A register entry, a
capability matrix row, a doc correction that the code change *makes true* belongs in the commit
that makes it true — splitting it onto the trunk publishes a claim about code that has not landed
yet, and leaves the branch's own reviewer reading a diff with its explanation missing. The
direct-to-trunk rule governs metadata changed **on its own**; it was never a ban on a code change
carrying its own documentation. *(Measured in the seed acceptance test: a worker with a register
update inside a feature branch read the rule as a prohibition and split a coherent change in
two.)*

**And the carve-out is not limited to documentation.** An **executable declaration** the same change
makes true rides with it too — a guard's enrolment in the gate runner's always-on set, a new check's
row in a declared table, a threshold the change is what makes correct. The examples above are all
documentation-of-code, which reads as an exhaustive list of what may ride; it is not one. Where the
two operands are only **jointly** satisfiable, the unit is the **set** and neither lane alone can be
read as the answer — [`doctrine/commit-hygiene.md`](doctrine/commit-hygiene.md) § A.5, which also
states what no mechanism can do about it once the two have been split.

### The kanban worktree (load-bearing)

`move-issue.sh` / `finish-pr.sh` / `subtask.sh` never commit in your checkout (`finish-pr.sh` does
move one; its header says which, and when). All kanban version-control ops run inside a **standing detached worktree pinned to the trunk** (`.kanban-wt/`,
gitignored, auto-bootstrapped, lock-serialized, and it fast-forwards your main checkout when that
sits clean on the trunk). This is what lets a board move commit to the trunk **while your working
checkout is on a work branch**. Never delete it mid-op; if an op dies between commit and push,
`check-board.sh` surfaces the divergence — **within the span it prints**: commits reachable from a
ref. A commit reachable from no ref at all — an orphaned sibling, e.g. one made while the worktree
was attached and left behind when `HEAD` moved elsewhere — is outside that measurement and would
need the reflog. The contract is
[`contracts/kanban-worktree.md`](contracts/kanban-worktree.md).

**A COORDINATOR WRITING THE TRUNK WHILE A WORKER HOLDS A BRANCH IS EXPECTED, NOT A RACE.** Board
moves, rulings, PRDs and `dev/` evidence are metadata by the code-vs-metadata rule above, so they
commit direct to the trunk — *while* a dispatched leg is working on its own branch. That is the rule
operating as designed, and two independent projects have reported it as a defect because nothing said
so. **What is protected is the shared working tree, not the trunk**; the board scripts route through
`.kanban-wt/` precisely so both can proceed.

**The coordinator's own by-hand writes are the part that needs discipline**, because they do not go
through that worktree: while any leg is dispatched, make them from **a worktree of your own** rather
than a `git switch` in the shared root, and keep the multi-session habits — `pull --rebase`, and
`progress.md` append-only so two sessions' entries merge instead of colliding.

**And know what your detector cannot see.** A commit dropped by somebody's rebase is reachable from
no ref, which is **outside the span `check-board.sh` prints** — it says so on every run, in the line
quoted above. So a displaced commit is not something the drift report will surface for you; if a leg
rebases the trunk under you, the reflog is the only witness.

### Role-attribution commit prefixes

Every commit subject starts with a **role tag** in square brackets; the `scripts/githooks/commit-msg`
hook **rejects a prefix-less subject — and refuses a machine-attribution trailer,
a co-author line naming a tool or a *generated with* line** (wired via `git config
core.hooksPath scripts/githooks` — `kit-init.sh` wires it ONCE at adoption and commits the hooks' executable bit; `setup.sh` re-wires and repairs it on EVERY fresh clone (contracts/initializer.md § 2);
[`doctrine/commit-hygiene.md`](doctrine/commit-hygiene.md) carries the rule and its
reason). The **set of legal prefixes is the project's** —
it is declared in one table in the adapter and enforced from the hook, and the two must agree.

Two attribution rules are the kit's:

- **The Orchestrator prefix is narration only.** Coordination notes carry it; the work its
  subagents do carries the Dev/QA prefixes.
- **The hygiene conventions around a commit** — no generated co-author trailers, the
  hand-commit-then-`git status -sb` ritual, never ending a landing on an unpushed
  looks-pushed state, and the coupled-operand rule for a change whose operands straddle the two
  commit lanes — are **kit doctrine**, not each project's taste:
  [`doctrine/commit-hygiene.md`](doctrine/commit-hygiene.md), whose § A headings are the list.
  Subject *style* beyond the role tag (tense, length, body format) remains the adapter's.

### Landing code — `./scripts/finish-pr.sh <ID>`

Forge-agnostic, pure version control; **no forge CLI**. It squash-merges the issue's work branch
into the trunk locally, pushes, deletes the branch (local + remote), and advances the issue
`dev_complete → qa_complete`. QA's review evidence lives in the **issue file's Activity log —
committed on the trunk**, not on the branch (§ The Dev → QA handoff step 3) —
there is no PR/MR object to open, approve or comment on. (A forge-PR flavor can be added later if
a team wants MR ceremony; see the `finish-pr.sh` header and
[`GIT-HOSTING.md`](GIT-HOSTING.md).)

### Log-filtering recipes

Substitute the project's own prefixes and ID scheme:

```bash
git log --grep='^\[QA\]' --oneline          # every QA action
git log --grep='^\[Dev\]' --oneline         # every Dev commit
git log --grep='<ID>' --oneline             # one issue's whole trail
git log --grep='→ qa_complete' --oneline    # every issue that landed
```

---

## Notifications (optional)

The kit ships a **transport-agnostic** outbound-notification helper (`scripts/notify.sh`, with one
example channel adapter) and a harness `Notification` hook (`scripts/notify-hook.sh`). It is
**off by default** — with `NOTIFY_BACKEND` unset (or `none`), `notify.sh` is a silent no-op, so
the roles' "fire a ping" checklist items cost nothing. To enable, set `NOTIFY_BACKEND` (and the
backend's credentials) in the environment file and add the `Notification` hook from
`.claude/settings.json.example`. Roles fire an `attention`/`done` ping at session start/close
only when a backend is configured; **nothing here is required for the process to work.**
Contract: [`contracts/notification.md`](contracts/notification.md).

## Progress records (optional) — where a phase goes after the scrollback

Several shipped scripts already announce their phases to stdout. **Nothing wrote them anywhere a
reader could open once the terminal had scrolled**, which is the whole gap this closes: a
maintainer watching a long run wants *which phase, how long, what is left*, and that was available
only by staring at a terminal, and only while it was open.

`scripts/lib/progress-record.sh` appends one line per event to `.progress-records/` (gitignored,
one file per UTC day). **Four required fields — timestamp, actor, class, description — and
everything else is an OPTIONAL FIELD rather than a different payload**, so a reader that
understands only those four reads every record. `kit_progress_tail` prints the recent ones.

**Three properties, and each is load-bearing rather than decorative:**

- **Transient by construction.** Records expire on a short TTL, swept as a side effect of writing.
  *Nobody should ever have to dig through old logs for anything* — durable insight stays in
  reports and the card's Activity log. Wanting to keep one means wanting a card.
- **Never a gate, and never a dependency.** No gate's verdict, no script's exit status and no
  output changes because a record was or was not written. Delete the library and every converted
  script behaves identically.
- **Converged on two producers on purpose** — `verify.sh` and `move-issue.sh`. The rest of the
  population is deliberately unconverted until a run has exercised the format; widen from the
  derivation in the contract sheet's § 5a, not from memory.

**No role gains a reporting obligation.** The role-side record is written by the board mover,
which was already given the hat and the id as arguments — so attribution is assigned by the
caller rather than reported by the agent, which is the only version an agent cannot get wrong.
Contract: [`contracts/progress-record.md`](contracts/progress-record.md).

## Kit feedback — on by default, switchable, never sent automatically

**What the kit cannot find by reading, a project finds by running it**, and
`process/KIT-FEEDBACK.md` is where the project writes that down. A finding recorded only when
somebody remembers to is recorded by inclination, not by the workflow. So this section names the
**moments** at which a seat writes, and a setting that switches them off.

**The setting** is the `kit-feedback:` line in `PROJECT.md` § The kit, upstream:

| Value | What it means |
|---|---|
| `auto` — **the default** | At each capture moment below, the seat writes an entry, or states that there is none, without being asked. **A missing line reads as `auto`.** |
| `manual` | No capture moment fires, and no `kit-feedback:` line is written. The file is kept as this project's channel to the kit, and an entry is written when someone asks. |
| `off` | No capture moment fires, and no `kit-feedback:` line is written: a `none` would read as *nothing found*. This project's findings are not meant for the kit, which suits a tangential project. A person may still write an entry. |

**Why it is a setting.** Two situations want the opposite of the default: a kit judged mature
enough that feedback is noise, and a tangential project whose findings would pull the kit toward
one consumer's shape ([`doctrine/generality.md`](doctrine/generality.md) § A.2).

**The capture moments, a closed list.** Each is a place the workflow already stops. There is no
open-ended *"whenever something goes wrong"* trigger.

1. **M1: a `process/LOCAL-PROCEDURES.md` entry that resolves a kit contradiction or a kit
   silence.** Write its `K-NN` in the same commit. A recorded departure from a setting's default
   is **not** a kit finding and mints nothing. **A dispatched leg writes no entry.** It puts one
   `kit-finding: <what; kit file:line or "silent">` line in its `progress.md` entry, and the
   orchestrator writes the entry (M4).
2. **M2: session close.** Answer these questions:
   - (a) if this session did M1, is its `K-NN` written?
   - (b) did it bypass or override a kit hook, refusal or gate?
   - (c) did a kit script or gate report something false?
   - (d) did it hit a kit instruction it could not follow as written, without recording that
     anywhere?

   Each *yes* to (b), (c) or (d) is an entry **when the kit's rule, script or silence was the
   cause**. When the kit was plainly right and the fault is this project's, say so in `progress.md`
   and write no entry. The session's `progress.md` entry ends with
   `kit-feedback: none`, or with `kit-feedback: K-NN[, K-NN…]`. **An explicit `none` is required**,
   so a missing line shows as an omission rather than as a silence. A missing line is reported,
   never refused, and the line records that the questions were asked, not that the answers are
   true.
3. **M3: applying a kit upgrade.** An *Action required* item that could not be applied as written
   is an entry.
4. **M4: closing an orchestrated run.** During a run **the orchestrator is the only writer**:
   parallel legs would mint the same `K-NN` twice. It collects every `kit-finding:` line from the
   legs' `progress.md` entries, as well as anything a leg's report names — every record a runner
   returns carries each leg's free text as `leg_notes` (§ The RUN-OUTCOME vocabulary) — and writes
   the entries. **The `progress.md` lines stay the record:** a runner's return lives only as long as
   the orchestrator's session, and a line in the trunk's `progress.md` outlives it. The run report
   carries the same `kit-feedback:` line.

**What an entry carries, and what may leave the project**, is the skeleton's to say:
`process/templates/KIT-FEEDBACK.skeleton.md` § The shape of an entry, and its header.
**Sending is the project's act.** Nothing leaves automatically, under any setting. Where it goes is
*Feedback is sent to* in `PROJECT.md` § The kit, upstream, and how is the file's own § Sending it.

**Removing the default is the kit maintainer's act; an adopter sets `off` instead.**

## The measurement rituals (optional) — three ways to find out whether this is working

Everything above tells you how work moves. **None of it measures whether the result is any good to
the people who meet it**, and no gate can: a gate checks the thing you thought to check. The kit
carries three rituals for that, and all three are **available, never obligations** — no gate runs
one, no release waits on one, and a project that never holds any is in good standing. Reach for one
when you want the answer, on a **condition rather than a schedule**; a ritual held quarterly becomes
ceremony, and ceremony measures nothing.

| Ritual | The question it answers | Doctrine |
|---|---|---|
| **Regeneration spike** | Does the **corpus** rebuild the product — and does the acceptance tier notice where the rebuild got it *wrong*? | [`doctrine/calibration.md`](doctrine/calibration.md) § A.1 |
| **Seed acceptance test** | Does the **process** transplant to a project it was not written for — and which steps had to be guessed? | [`doctrine/calibration.md`](doctrine/calibration.md) § A.2 |
| **Dogfooding round** | Does a competent stranger, **holding only what ships**, get where they were going? | [`doctrine/dogfooding.md`](doctrine/dogfooding.md) |

The first two grade your **artifacts**; the round grades the **encounter**, and its findings are
mostly about *words* — documentation, error text, naming, defaults — which is the surface the other
two cannot see and the gates never touch.

**Three rules bind all of them**, and they are why these are worth running rather than reading:

- **The deliverable is findings, never code and never a verdict on a person.** Nothing a ritual
  produces lands as product.
- **Findings go to a real PM session, which decides what is minted.** A ritual does not open work
  items itself — that would be pre-writing a backlog nobody scoped (§ Kanban rules), and it is the
  most common way a good round's output gets ignored.
- **Declare the honest limits, or you have findings but not a measurement.** Blinding is
  honour-system, leaks are recorded, and **what the ritual never exercised is named as unproven,
  not passed** ([`doctrine/calibration.md`](doctrine/calibration.md) § A.3).

A round has a document pair of its own, beside the launch pack and run report that authorize and
close an orchestrated *run*: [`templates/round-pack.template.md`](templates/round-pack.template.md)
and [`templates/round-report.template.md`](templates/round-report.template.md). **A run delivers
work; a round measures how the delivered thing is met** — keep the two words apart.

## The fix-execution phase — MANDATORY for a slate minted from findings

The rituals above produce **findings**. This section is what happens between a set of findings and
a release, and unlike them it is **not optional when the slate came from a round**: a program that
lands a round's findings has a characteristic way of failing, and two of the steps below exist only
because it did. (For an ordinary single-issue fix, none of this applies — the lite path is the path.
The trigger is a *slate minted from findings*, not a fix.)

findings → **scrutiny** → ruled decisions recorded → implementation → **pre-cut sweep** → cut

Two of those are steps the lifecycle above does not otherwise have:

- **Scrutiny (before any implementation).** Every minted item is a hypothesis written at findings
  altitude. One fresh-context reviewer per item, **read-only**, four questions: does the fix close
  the finding it names; what else does it move; does it re-create a defect the round already found;
  is any part secretly a decision nobody made. **Holding or rescoping an item is a success, and the
  reviewer is told so** — otherwise they grade for implementability. The rescopes are then written
  **into the item files** by whoever owns minting: an implementer must meet a corrected contract,
  not a side-channel of caveats.
- **The pre-cut sweep (after the last landing, before the cut).** Per-item review judges the item's
  own grep list, and nobody's grep list is the corpus. One fresh-context checker per consumer-facing
  surface, verifying its claims against the tree as it stands. This is the half a per-change check
  cannot reach — the surfaces no diff touched.

**Who holds the pen:** the scrutiny pass is a reviewer wearing fresh eyes (QA, or a dedicated leg —
**never the minter**); the two-bucket sort and the ruling records are the PM's; the sweep is
dispatched one leg per surface. The reasoning, and the rules behind these two steps, are
[`doctrine/fix-execution.md`](doctrine/fix-execution.md).

## Seams — what this file deliberately does not know

| Seam | Where it is configured |
|---|---|
| Issue / spec prefix, id validation | `scripts/config.sh` |
| Trunk name | resolved and confirmed from the remote's published default branch; `<trunk>` defaults to `main` |
| Status folder set | the `progress/` directory + the kanban scripts |
| The gate commands | the project doc + `scripts/verify.sh` |
| The role set + the commit-prefix table | the adapter + `.claude/roles/` |
| Which paths count as **code** | the adapter (§ The code-vs-metadata rule) |
| House rules, credentials, capability/documentation duties | the adapter — **project law, and none of this file's business** |
| Where kit feedback is sent, and how kit updates reach the project | `PROJECT.md` § The kit, upstream |
| Whether kit findings are recorded without being asked (`kit-feedback:`) | `PROJECT.md` § The kit, upstream — `process/MANUAL.md` § Kit feedback |

## Doctrine — the files this manual points at

Doctrine is the *reasoning* behind a rule, kept out of this manual so the manual stays short.
Every one of them lives in [`doctrine/`](doctrine/) and travels with it — **the directory listing
is the count**, and this table is the index. A new sheet joins this table **in the same change**
that creates it; a table that lags is how a sheet becomes invisible.

| File | The pattern it states | Where this manual points at it |
|---|---|---|
| [`supersession.md`](doctrine/supersession.md) | Preserve the reason, supersede only the conclusion — and the `superseded_in_part` annotation that follows from it. | § Execution discipline, item 5 |
| [`negative-claims.md`](doctrine/negative-claims.md) | **Enumerate the attempts, or say "unmeasured"** — a shipped *cannot / impossible / not supported / does not exist* lists the forms actually tried, and its scope may not exceed its evidence's scope. § A.5 generalises that past negatives: **a claim names the route that produced it, in the same sentence** — and two readers on one route is one measurement read twice. Naming the route is universal; a **second route** is owed where the claim is **load-bearing**, sorted by *if this is wrong, what happens?* The authoring-time neighbour of `supersession.md`. | The implementer role doc's *Definition of Done* and the reviewer role doc's cross-cut checks |
| [`commit-hygiene.md`](doctrine/commit-hygiene.md) | What a commit owes beyond its content: no generated co-author trailers, a role-prefixed subject enforced at write time, hand the commit then read `git status -sb`, never end a landing on an unpushed looks-pushed state, and — where a change's operands straddle the two commit lanes — the gate's unit is the **set**, not the file. | § Branching and role attribution |
| [`model-provisioning.md`](doctrine/model-provisioning.md) | How a dispatched worker is provisioned (model + effort per work class), the leaf rule (a worker does not spawn workers), and the rule that a ladder is only real where a harness knob exists. | The role docs that carry a *"Model & effort contract"* section |
| [`conformance-tier.md`](doctrine/conformance-tier.md) | **Which tests pin the PRODUCT rather than this implementation** — one question (*"if this fails after a rewrite, is the product wrong, or merely different?"*), two tiers, marked by whoever writes the test. Its marking convention is runner-agnostic: one mark in whatever the runner offers, at file or test granularity. | Here |
| [`calibration.md`](doctrine/calibration.md) | **The two AVAILABLE rituals that measure the kit's own claims** — a regeneration spike (hide a decision-dense module; rebuild it from the corpus with the acceptance tier as the criterion) and a seed acceptance test (bootstrap a fresh project from the seed document and count the steps guessed). Both must declare their honest-worker limits, and the **findings list is the deliverable**. **Available, never an obligation.** | § The measurement rituals |
| [`retention.md`](doctrine/retention.md) | **Park beats delete, and the one narrow class that may be retired** — a SPENT, unreferenced prose document, ledgered under a seven-field contract and verified by a retirement-QA leg that runs the fetch-back. The reason (deletion silences guards; evidence is not re-derivable; a negative claim dies with its enumeration) is preserved in full; only this one conclusion narrows. | The project doc's § Retained evidence |
| [`staleness.md`](doctrine/staleness.md) | **Retirement is paid by the change that causes it** — four triggers (a successor lands, a plan closes, a ruling overturns a conclusion, a number/universal stops being true), each owed in the same commit as its cause, never a sweep. Five stamp fields (the "kept because" surviving-value clause is the one authors drop); "derive, date, or do not state" for numbers in prose. | The implementer role doc's *Definition of Done* |
| [`lookup-tables.md`](doctrine/lookup-tables.md) | **A large consulted document is addressed, not read** — a two-number trigger (in the consulted corpus, ≥ 32,768 bytes), one index budget that derives both the entry cap and the 409-entry split point, a stable-address requirement (never a bare `file:line`), and generated-over-hand-kept as a five-rank preference order. An index is not a diet — orthogonal to rotation, mutually reinforcing. | Pointed at from several sheets — derive with `grep -rl lookup-tables process/` |
| [`rigor-tiers.md`](doctrine/rigor-tiers.md) | **Ceremony weight AND provisioning follow the issue's tier** — three tiers by change shape (no-behavior-change / internal behavior / schema-API-risk-surface), each implying a lifecycle weight and a worker provisioning; the binding-gate decision rule (run it iff a declared risk surface moved; when in doubt, run it); the tier follows the CHANGE SHAPE and is stated per issue at run-plan time so the human can veto the placement. | § The default path is lite — and the orchestrator role doc's run-plan duties |
| [`live-resources.md`](doctrine/live-resources.md) | **Consent, budget and evidence for anything created outside the repository** — a check against a real external system runs against a **disposable** target, never a real one, restores it, and records what it spent. | § The default path is lite, "a green unit suite is a floor" |
| [`orchestration.md`](doctrine/orchestration.md) | **The seat, the runner, and the pack between them** — the rationale behind the delegation patterns, the pause law and the run-plan gates. The role docs are the enforcement; where the two differ, **the role doc binds**. | Here — and `doctrine/subagent-control.md`, which item 2 names |
| [`subagent-control.md`](doctrine/subagent-control.md) | **How to brief a worker that has none of your context, and what to believe from work you did not watch** — an adversarial brief outperforms a confirmatory one and it is not close; contradictory demands return *nothing* rather than a compromise; a returned report is a claim that carries its own evidence or is re-measured; a resume is only safe for work without side effects; a deferred decision is named inside every item whose scope touches it; hand off while sharp, not while failing — **and at the stop you did not choose, where what a handoff owes is an enumeration of what is HELD**; and **a file that means two things has no correct writer**, so a second consumer earns a second artifact rather than a cleverer query. **And the cadence a spawner owes PROMPTED peers** — an idle prompted session cannot emit anything, so silence from it is indistinguishable from work: only the spawner has a clock, notes come from inside the work, age is read from artifacts and never asked, overdue has a named act and a named owner, pause and done are files — **and the obligation is written into the project's working agreement, because one delivered only at session start is a conversation citing itself and dies at the next restart.** | § Execution discipline, item 2 |
| [`distribution.md`](doctrine/distribution.md) | **Shipping a project into other repositories** — what an artifact owes a consumer that pins it, and the thin machinery that keeps the two in step. **If your project ships to nobody, none of it binds you except § A.8 (kit feedback).** | Here |
| [`dogfooding.md`](doctrine/dogfooding.md) | **A round grades how the shipped thing is MET, not whether it works** — so most of its findings are about words. Its instruments are built by the builders, so they must be checked against the shape a participant actually *produces*; a self-report is never a measurement; whatever *delivers* a provocation may never *judge* the response; grade cold then reconcile, auditably; and a Blocker halts its scenario, not the round. | § The measurement rituals |
| [`instruments.md`](doctrine/instruments.md) | **An instrument is believed only when it has been watched failing.** Measure it against the shape it will meet, not the fixture its author wrote; **every green owes an ablation** (absence of the wrong thing is not presence of the right one); sometimes a capability probe is itself the defect, and that choice is recorded; and each instrument's blind spot is named **in its own output** — where naming the operand set stops one step short, so it must be **derived from the subject, derived a second time by a looser reading, and the two compared**, with the remainder named rather than dropped. And a value the instrument compares against is derived or does not exist: **a check you can satisfy by editing the answer is not one**. For an instrument that only REPORTS — one that always exits 0, so there is no red to ablate — **the control must execute on every run and appear in the instrument's own output**, and the unit it binds is the predicate, not the file. And on the declaration side: **readerless is fine; UNDECLARED readerless is not** — a document stating a format, a marker or a shape names the program that reads it, or says that none does and why, because the silent case reads exactly like an enforced rule. | § Execution discipline, item 3 |
| [`fix-execution.md`](doctrine/fix-execution.md) | **Landing what a round found, without minting what it warned about** — the span between findings and implementation, and between the last landing and the cut. A minted item is a hypothesis, so the slate is scrutinized before a line moves and **holding an item is a success**; a ruling is recorded **before** it is executed, verbatim and with what was *not* ruled beside it; the round's traps travel as acceptance criteria; truth is corpus-wide in two obligations, one per change and one before the cut; a gate budgets a **property**, never a machine; and one authoring site per vocabulary, with a guard that bites when a projection parts from it. | § The fix-execution phase |
| [`consumer-output.md`](doctrine/consumer-output.md) | **What a tool's output owes a reader who cannot RE-MEASURE it** — the discriminator is re-measurability, not honesty. A label's scope may not exceed its evidence's, said in the label itself; **read and derived are distinguished per item**, because a wrong inference usually makes the result look *better*; where every candidate value is wrong in a different direction, synthesise none and record the absence as a decision with its discharging event; a non-decidable predicate hands back a **census that says so in its own output**; an inference whose error leaves no trace is demoted from a decision to a proposal; prefer the longer form the consumer can check, and pay the new emptiness boundary a split creates; and **a limit recorded where the affected party does not look has not been disclosed** — placement separates detection from remedy. | Here |
| [`generality.md`](doctrine/generality.md) | **When one consumer's request may become everyone's rule** — four questions asked before a request changes shipped behaviour. The load-bearing one is the **flip-flop test**: *would the opposite request be equally reasonable from a different consumer?* If yes it is a **setting**, answered by a declared seam with a default, never by changing behaviour — and the consumer who wants the opposite is **named**, because "someone might disagree" refuses nothing. Also: strip the donor's identifiers and re-read the argument; name what would falsify the rule; **record a HELD request and the event that would release it**. The counter-case has equal weight — **the test is not *how many consumers*, it is *does the argument need this consumer*** — and § A.6 forbids wiring any of it as a gate. | Here |

Two neighbours of the doctrine directory, deliberately outside it:
[`hygiene-checklist.md`](hygiene-checklist.md) (the shapes a periodic hygiene pass looks for, and
the instruments that look — **the periodic cadence is advisory; the pre-cut sweep in it is
MANDATORY when the slate came from a round**) and [`GIT-HOSTING.md`](GIT-HOSTING.md) (the
local-only-to-hosted spectrum). Neither is doctrine, so neither has a row above.

The honest inventory of what is copyable, what must be configured, what is pinned in place and
what is **still entangled** is [`EXTRACTION.md`](EXTRACTION.md). Read it before lifting this kit
into another repository.
