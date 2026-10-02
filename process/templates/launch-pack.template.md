<!-- KIT-CLASS: KIT — the launch-pack shape. Copy, fill the <slots>, delete every `> **GUIDANCE` blockquote and this marker line. -->
# Launch pack template — the commissioning contract for one orchestrated run

<!-- LINKS IN THIS FILE ARE RELATIVE TO WHERE IT LANDS — dev/launch/ — NOT to process/templates/
     where it sits. A link that resolves while you are reading the template and dies in every copy
     of it is the worst of both: it passes a link check here and is broken for every adopter. -->

> **GUIDANCE — how to use this file.** Copy it to `dev/launch/<YYYY-MM-DD>-<run-name>-pack.md`,
> fill every `<slot>`, and **delete every blockquote that opens `> **GUIDANCE`**, and the line-1 marker, before you launch;
> the STATUS banner is a blockquote too, and stays.
> What survives is a paste-ready prompt: a runner reads the pack, wears the Orchestrator hat, and
> executes it without asking the seat what was meant. The pack is authored by **the seat** (the
> standing, human-partnered position — see [`process/doctrine/orchestration.md`](../../process/doctrine/orchestration.md));
> it is **not** written by the runner that executes it, and it is never edited mid-run except to
> stamp it or to record a seat ruling that changed the order.
>
> **The one-sentence test for a finished pack:** a fresh instance with no memory of the planning
> conversation can execute it end to end, and every judgment it is asked to make is either
> answered here or explicitly delegated. If the runner would have to guess, the pack is not done.
>
> **Size discipline.** A pack is one screen per section, ~100–120 lines total. It is a
> commissioning contract, not a manual: standing rules live in the role docs and the doctrine
> sheets, and the pack **cites** them. Restating a rule in the pack creates a second copy that
> will go stale — cite instead, and state only what is true *for this run*.

---

## The STATUS banner — the first block in the file, and it has a lifecycle

> **GUIDANCE.** Author it as `LIVE`, stamp it as `SPENT` at close, and **never rewrite the
> original wording** — the conclusion is superseded, the wording is preserved
> ([`process/doctrine/supersession.md`](../../process/doctrine/supersession.md);
> [`process/doctrine/staleness.md`](../../process/doctrine/staleness.md) is what makes the stamp owed by the
> change that closes the run, in that same commit — never by a later sweep).
> Three states, in order:
>
> - **LIVE** — authored, not yet run. This is the only state in which the pack instructs.
> - **SPENT** — the run closed. Stamped **against the run report by name**, in the same commit
>   that lands the report. The pack is now the record of *what was asked for and on what terms*,
>   not an instruction. Anything the run overturned is corrected **in the report**, and the
>   banner says which expectations were overtaken.
> - **SUPERSEDED** — a later pack or ruling replaced this one before it ran. Same rule: keep the
>   original wording, name the successor.
>
> Preserve-the-wording, in practice: strike through or quote the old line rather than editing it —
> *"(This line read* **`STATUS: LIVE — not yet run.`** *as authored <date>; the conclusion is
> superseded, the wording is preserved — the seat, <date>.)"*

**Authored form:**

```
> **STATUS: LIVE — not yet run.**
> **<delegation pattern — the name the seat's role doc gives it> pack.**
> <N> issues, STRICTLY SERIAL, real landings between issues:
> **<PREFIX>-<a> → <PREFIX>-<b> → <PREFIX>-<c>** (<one clause per ordering decision — why this
> one is first, why the largest is last>). <Provenance of the issues: which were already on the
> board, which were minted for this pack and by which commit.>
> Charter: `<dev/…-charter-or-goals-doc.md>`. Plan of record: `<dev/…/PLAN.md § N>`
> (+ any ruling whose recorded reason binds a particular issue's choices).
> Current state: `<dev/handoffs/<date>-standing-handoff.md>`. Prior run:
> `<dev/launch/<date>-<name>-run-report.md>` (<what in it bears on this run — e.g. its dominant
> defect class is this run's enemy>).
```

**Closed form (stamped at close):**

```
> **STATUS: SPENT <date> — RUN AND CLOSED.** Superseded by its own run record
> [`<date>-<name>-run-report.md>`](<date>-<name>-run-report.md): **<X> of <N> landed, <Y> parked
> at close**. Kept as the commissioning record — what was asked for and on what terms — not as
> instruction. <M> of its own expectations were overtaken by measurement and are corrected in
> the report: <name them>.
```

---

## THE RUN'S STANDING FACTS — read before anything

> **GUIDANCE.** The short list of facts that were *not* true last run, or that a runner would
> get wrong from the repo alone. Numbered, so a report can cite "fact 3". Four to six items;
> more than that means standing rules are leaking in from the role docs. Each fact states the
> fact, then what it costs or forbids. Typical members of this list:
>
> 1. **The remote regime.** Which remote is authoritative, whether the normal lifecycle (board
>    moves, branch pushes, landings through `./scripts/finish-pr.sh`) applies end to end or
>    whether pushes are refused and closes are **land-ready verdicts** instead. The preflight
>    and between-issue check, named as a command. Any unexplained regression → STOP and report.
>    See [`process/GIT-HOSTING.md`](../../process/GIT-HOSTING.md) § The blocked-push regime.
> 2. **The release/notes state.** Which notes section is open, whether the topmost is cut and
>    closed, and who opens the next one. If several issues write into **one shared open
>    section**, say so here and name the tripwire — it is the most reliably re-discovered defect
>    class there is (an absolute one issue lands becomes the next issue's falsified claim).
> 3. **The cost model for any expensive-to-regenerate artifact** this run will move (a generated
>    manifest, a golden corpus, a pinned payload): what one landing costs, which command pays it,
>    and that **the generated diff is the disclosure** — no hand arithmetic in prose.
> 4. **Any id-register law.** If a run mints ids into a shared register (rulings, decisions),
>    the next free id is **re-read from the file at write time**, never trusted from a brief;
>    the register tolerates a gap, never a duplicate.
> 5. **The live/destructive-resource regime for this run** — usually "zero", said explicitly.
>    See [`process/doctrine/live-resources.md`](../../process/doctrine/live-resources.md), and § Standing
>    discipline below.
> 6. **Which standing laws are newly binding** (a doctrine that landed since the last pack), so
>    the runner knows this run is their first field use.

1. **<fact>** — <what it costs, what it forbids, what to do if it is not true at preflight>.
2. **<fact>** — <…>
3. **<fact>** — <…>
4. **<fact>** — <…>

---

## Who you are and what binds you

> **GUIDANCE.** Identity, read order, and the anti-fabrication rules. Keep it to one paragraph.
> The read order matters: adapter → project facts → the role doc → current state → **the issue
> files in full**. Say plainly that **the issue ACs are the law** and the pack is not a substitute
> for reading them. Say that **the repo files are the truth**: where the pack, the issues or the
> plan disagree with the tree, the tree wins and the disagreement goes in the report's
> discrepancy ledger — *report rather than improvise*. If the mint already found places where the
> repo beat the briefs, say how many, so the runner expects more and reports them.

Fresh top-level instance, **Orchestrator hat all session**
([`.claude/roles/orchestrator.md`](../../.claude/roles/orchestrator.md) — including its
§ Model & effort contract). Read order: `PROJECT.md` → `AGENTS.md` → the role doc →
`<dev/handoffs/<date>-standing-handoff.md>` → **all <N> issue files in full** (their AC are the
law; each issue's own rigor tier binds, wherever the pack records it — there is no § Rigor
section in the shipped card templates, so do not send a runner looking for one). The repo files
are the truth; the mint recorded
`<n>` places where the repo beat the briefs (each already encoded in the issues) — expect more,
**report rather than improvise**.

**Anti-fabrication rules bind:** exit codes read **unlaundered** (piping a gate through
`tail`/`grep` launders its status), no hand-typed summary counts — quote the runner's own
summary block, **watched-red proofs are transcripts of tests actually watched failing**, and
**never relay a leg's self-report as a measurement**.

---

## Worktree discipline

> **GUIDANCE.** State exactly one worktree per runner, its path, and how it is created and
> prepared. Then the three rules that have each cost a run: (a) branch from the **current**
> trunk per issue and land before the next starts, so nothing stacks; (b) **never touch** another
> run's worktrees — they are provenance until the seat sweeps them, and name them if they exist;
> (c) the **shared-checkout law is bidirectional** — the main checkout belongs to the seat, and a
> session's uncommitted changes there can be swept into *another* session's commit. Commit or
> stash before yielding; runners close in their own worktree.
> If the run is under a blocked-push regime or a stacking order, say which branch each issue
> branches *from* — that is the single most expensive thing to leave implicit.

ONE worktree: `git -C <main> worktree add <path> <trunk>` → `./setup.sh`. Per issue: branch from
**current** `<trunk>`; land before the next starts; no stacking. **Never touch** `<older
worktrees, by name>` — provenance until the seat sweeps them. The main checkout is the seat's:
never commit from it.

---

## The mission — <N> issues, STRICTLY SERIALLY, in this order

> **GUIDANCE.** A numbered list, one entry per issue, in execution order. Each entry:
> **id — one-line identity**, then the clauses that only the seat knows: the branch type, any
> ruling whose reason binds this issue's choices, any correction the mint made to the issue's own
> premise, whether it moves an expensive artifact, and any hazard (live plumbing, a consumer-
> visible change that is CONSENTED and by what). End each entry with its **rigor line**:
> `**<implementer role> <model> <effort> / QA <model> <effort>.**` Rigor lines are load-bearing —
> the report grades against them, so no issue may be left without one.
>
> Order is a seat decision and deserves its reason in one clause: fixes to the machinery early so
> later landings exercise them; the largest, most consumer-visible change last; a blocked issue
> only after its unblocker.
>
> **The clause names the CONSEQUENCE, not just the sequence.** *"Do A before B"* is followed
> inconsistently; *"A before B, because B first would leave the gate unable to redden for the defect
> A fixes"* is followed, because the reader can see what breaks — and can therefore tell when the
> constraint has stopped applying. A bare ordering gives a runner nothing to reason with the moment
> reality diverges from the pack, which is the moment the ordering mattered.
> *(`process/doctrine/subagent-control.md` § A.11.)*

1. **<PREFIX>-<a>** — <identity> (<branch type>; <binding clauses / corrected premise>).
   **<Dev|Refactorer> <model> <effort> / QA <model> <effort>.**
2. **<PREFIX>-<b>** — <identity>. **… / QA <model> <effort>.**
3. **<PREFIX>-<c>** — <identity> (<hazard: names the plumbing it touches>). **… / QA <model>
   **<effort — escalated, and say why here>**.
4. **<PREFIX>-<d>** — <identity> (<measure-first gate: the number the issue must derive rather
   than inherit>). **… / QA <model> <effort>.**

**Provisioning mechanics.** <Which legs are correctly provisioned by the harness's own defaults
(a plain spawn of the named worker type), and which legs are **escalated** and therefore must
travel the escalation route your harness actually has — name it, and name the fallback. Budget
escalated dispatches **for FAIL paths too**: a FAIL costs a fix leg and a second review leg at
the same tier, which is the forecast error every run makes.> The standing riders bind: explicit
model on every spawn, never the ceiling tier without sign-off, **workers are leaves** (a
dispatched worker does not spawn subagents). The doctrine is
[`process/doctrine/model-provisioning.md`](../../process/doctrine/model-provisioning.md).

---

## Standing discipline (compact; prior packs' full statements bind)

> **GUIDANCE.** This section is deliberately a compressed checklist — the full statements live in
> the role docs and the doctrine sheets, and *prior packs' statements bind* so you are not
> re-deriving them. Keep it to one paragraph of semicolon-separated clauses. The recurring
> members, each of which has been earned by a real failure:

Branch per issue by type; tests-first where a guard applies; **behavior preservation is the
spine** — zero test identifiers removed except where an AC names each removal, generated/golden
artifacts byte-identical except the consented, **enumerated** set; **<the live-resource regime,
stated as an absolute: zero destructive resources, zero live writes — and the instruction that a
leg believing otherwise STOPS that issue and parks>**
([`process/doctrine/live-resources.md`](../../process/doctrine/live-resources.md)); supersession doctrine on every
guard a change moves — **transform, never delete; the reason travels**
([`process/doctrine/supersession.md`](../../process/doctrine/supersession.md)); every new `dev/` document indexed
in the same commit; salvage-then-resume on a dead leg; **QA FAIL → one bounded fix round → a
second fresh-eyes QA → else park with evidence and CONTINUE** (the pause law:
[`process/doctrine/orchestration.md`](../../process/doctrine/orchestration.md) states the pattern, the
Orchestrator role doc states the enforcement); `git status -sb` after any hand commit;
`./scripts/check-board.sh` after every board move.

**The belt runs between every leg** and its readings are recorded in the report — the ledger
hash, the tree, the board, the remote, and the returned leg's own gate transcript. It exists
because self-reports miss what a two-line instrument catches.

---

## The run report

> **GUIDANCE.** Name the file, and enumerate what the report must contain **beyond** the
> template's standing sections — the run-specific deliverables only this run owes. Then the four
> close conditions. Naming the deliverables here is what makes the report gradeable against the
> pack.

`dev/launch/<YYYY-MM-DD>-<run-name>-run-report.md`, written to the shape in
[`run-report.template.md`](../../process/templates/run-report.template.md) and **indexed at close**. Beyond the standing
sections it owes: <the run-specific figures — e.g. the chosen parameter per file with its
derivation; before/after measurements for the shrink issues; each expensive-artifact
regeneration cited by commit; the escalation route actually used>.

**Close conditions:** this pack stamped **SPENT** against the report by name; the board clean
(`./scripts/check-board.sh` exit 0); the full gate script's summary block quoted verbatim with
its exit code read; residue named. **Parking well is success; a silent stop and improvising are
the two failure modes.**

---

## Author's pre-launch checklist (the seat's, before handing the pack over)

- [ ] Every `<slot>` filled; every blockquote that opens `> **GUIDANCE` deleted, and the line-1
      `KIT-CLASS` marker with them (the header states the same rule; the STATUS banner is a
      blockquote too, and stays).
- [ ] Every issue in the mission list exists on the board, is unblocked (or its unblocker is
      earlier in the order), and **has a rigor line**.
- [ ] Every load-bearing figure in the pack was **re-derived from the tree at authoring time**,
      not copied from an audit or a previous pack. Stale baselines in a pack become a runner's
      false FAIL.
- [ ] Every claim the pack makes about the repo is either verified or marked as *the mint's
      finding to verify, not inherit*.
- [ ] The standing facts name the remote regime, the live-resource regime, and the notes state.
- [ ] The run report's filename appears in the pack, and the pack's own name will appear in the
      report.
- [ ] The charter, plan of record and current-state pointers all resolve.
