<!-- KIT-CLASS: KIT — transferable doctrine. § A is the pattern; § B.1 is Claude Code's own MECHANISM (travels); § B.2 is the fill-in ladder. -->
# Model-provisioning doctrine — the ladder, not habit

**KIT-CLASS: KIT.** § A states the **PATTERN** a project adopts. § B.1 states the **MECHANISM** —
how the ladder is actually set in the Claude Code harness, which travels as written because it is a
fact about the harness rather than about any project. § B.2 is the **ladder table itself**, which is
one project's calibration and is therefore a blank you fill.

## A. The pattern (this is the transferable part)

1. **A dispatched worker is provisioned from a written ladder, never from habit.** "Whatever the
   last session used" is how a fleet's cost drifts; a table someone ratified is how it stops.
2. **The ladder's axes are (work class) → (model tier, effort).** Work class is about the
   *shape* of the task — coordination, mint, spike, implementation, review, mechanical — not
   about who is asking. Two axes are enough; a third invites negotiation.
3. **The ladder carries standing riders**: the settings that are never used at all (a tier/effort
   combination the project has decided is waste), the ceiling that needs sign-off to exceed, and
   the **leaf clause** — *a dispatched worker does not spawn subagents*, because fan-out is a
   coordinator decision and an unbounded tree is where a quota surprise comes from.
4. **The ladder is written in the role docs, not only in a study.** Each worker role doc carries
   its own row (its § "Model & effort contract"), so a worker reading its own doc is already
   provisioned correctly; the study is the reasoning, the role doc is the contract.
5. **Harness-managed knobs are not project knobs.** Anything the harness owns (output-token
   ceilings, thinking defaults it decides for you) is documented as *not a lever*, so nobody
   spends a session tuning something they do not control.
6. **Re-ratify when the model tier under an alias moves.** An alias is a moving target: the same
   configuration silently lands on a new model, and prior-era effort defaults rarely transfer. A
   model-generation change is a **decision point for whoever owns the budget**, not a surprise to
   absorb.
7. **A ladder is only real where a harness knob exists.** Write the ladder's DEFAULTS into the
   harness's agent definitions — the knob it always honors — and name the escalation mechanism
   your harness actually has, in preference order, with what does **NOT** work stated just as
   plainly. An instruction that prescribes a nonexistent knob ("set effort on the spawn") is worse
   than none: every run believes it provisioned the worker while the worker silently ran on a
   default. *(Raised after repeated runs found coordinators unable to set a subagent's effort at
   spawn time — the instruction existed, the knob did not.)*

   **And the mirror image, which is worse because it looks like success: an unset knob is not a
   default, it is an INHERITANCE.** Dispatch machinery commonly inherits the *caller's*
   configuration for any value left unset — so the coordinator's expensive tier silently becomes
   every worker's, or a combination the ladder has ruled out entirely becomes the one they all get.
   Where the harness behaves that way, **naming the tier and the effort on every spawn is not
   belt-and-braces, it is the only way the ladder binds.** State it per work item *before* the run,
   so the report can grade against it: a tier decided at dispatch time is a tier decided under
   pressure. *(Arrived with [`subagent-control.md`](subagent-control.md) § A.2, which is where the
   briefing side of this rule lives.)*

**How to adopt:** copy the seven points above, then write your own § B.2 — one table, work class by
work class, ratified by whoever owns the budget. Do **not** copy a table from another project; a
ladder is calibrated to one workload, one price sheet and one date.

---

## B.1 The MECHANISM — how a ladder is set in the Claude Code harness

> **This subsection travels.** It describes the harness, not a project. Re-verify it when the
> harness changes; the shape of the answer (defaults are structural, escalation is per-call, some
> knobs do not exist) is what is stable.

1. **Defaults are structural, and that is where the ladder lives.** Every worker type's
   `(model, effort)` pair is pinned in its agent definition's frontmatter — `.claude/agents/<worker>.md`,
   the `model:` and `effort:` keys. A plain spawn of that type is correctly provisioned with **no
   per-call action**. **Frontmatter effort OUTRANKS the session's**, which cuts both ways: defaults
   cannot drift with a window's setting, and no session toggle can reach a pinned worker.
2. **The spawn tool has a `model` parameter and NO effort parameter.** "Explicit model on every
   spawn" is a rule you can keep; effort never travels on the call.
3. **Escalating one work item above its type default** — in preference order:
   - **(a) The Workflow route.** Where the harness exposes a programmatic spawn
     (`agent(prompt, { agentType: '<worker>', effort: 'high' })`), the per-call `effort` is the
     documented override: per-call, parallel-safe, no shared state touched. If a run ever observes
     a frontmatter pin winning over it, that is a harness discrepancy — report it in the run report
     and fall back to (b).
   - **(b) The serial frontmatter toggle.** Edit the worker definition's `effort:` line → spawn →
     revert. **Binding constraints:** one lane only (never while another lane shares the
     repository), spawns strictly serial while toggled, the revert **verified** (a clean status on
     `.claude/agents/` before the next spawn and again at close), and the toggled state **never
     committed**.
4. **What does NOT work — do not spend a leg rediscovering it.** A session-level effort command
   (or an effort flag at launch) is inherited only by agent types **without** a frontmatter pin, so
   it silently does nothing for a project whose workers are all pinned. And a worker **cannot raise
   its own effort** — there is no self-knob, so never instruct one to.

Per-spawn effort on the spawn tool may or may not exist in the harness you are running.
**Do not take this sheet's word for it either way — check the spawn tool's own parameter list, and
write what you find into your § B.2 with the date you checked.** *This paragraph carried an
undated "at the time of writing" and no way to test it, which is precisely the shape
[`negative-claims.md`](negative-claims.md) § A.1b refuses: a claim of absence or futurity ships
with a guard — how to re-check it — or it does not ship.*

---

## B.2 Your project's ladder — **fill this in**

> **PROJECT INSTANCE.** The table below is a **shape with blanks**, not a default. Fill it, have it
> ratified by whoever owns the budget, date the ratification, and cite it from the role docs
> (§ A.4). An unratified ladder is a habit with a table.

| Role / work class | Model tier | Effort |
|---|---|---|
| **Orchestrator / coordination** | `<tier>` | `<effort>` |
| **Refactorer** | `<tier>` | `<effort>` |
| **Spec mint (PM hat)** | `<tier>` | `<effort>` |
| **Spike / probe** | `<tier>` | `<effort>` |
| **Implementer (Dev)** | `<tier>` | `<default>`; `<higher>` for `<the class that earns it>`; `<ceiling>` **only by sign-off** |
| **Reviewer (QA)** | `<tier>` | `<default>`; `<higher>` for `<the class that earns it>` |
| **XS / mechanical (any role)** | `<cheaper tier>` | `<effort>` |
| **Cleanup / classifier** | `<tier>` | `<effort>` |

**Standing riders — write yours, and keep the third one verbatim:**

- **Never used at all:** `<the tier/effort combination your project has decided is waste>`.
- **Needs sign-off to exceed:** `<the ceiling>`, and **whose** sign-off.
- **The leaf clause (§ A.3, binding, not optional):** *a worker spawned for a role does not spawn
  subagents.* Coordinator-level fan-out is the seat's and the runner's job.
- **The seat is outside the ladder** — the human-partnered instance is not a provisionable worker,
  so it gets no row. Say so explicitly; otherwise someone provisions it.

**Where to write it down:** each worker role doc's § "Model & effort contract", and a one-paragraph
summary in the adapter's house rules. **The per-tier ladder itself lives in
[`rigor-tiers.md`](rigor-tiers.md) and is pointed at, never restated** — a second copy of a ladder
is the thing that goes stale while still reading as authoritative. The seat's own contract stays deliberately silent, per the rider above.

---

## Appendix — the originating study (a worked example from the donor project, anonymized)

> **This appendix is EVIDENCE, not law.** It is one project's evaluation, on one date, of one
> model-generation change. Its **conclusions about that generation are not yours**; what travels is
> the *shape* of the reasoning and the *kind* of measurement that settled it. Every issue id,
> price and per-agent figure has been stripped or generalized.

**The trigger.** A fleet of dispatched workers was provisioned with the previous model
generation's habits. The tooling requested the model as a bare **alias**, never a pinned version;
the alias moved to a new generation. Nothing in the configuration changed — the model under it did.
The result was a quota surprise, and § A.6 is the rule that came out of it.

**The seven documented behavioural deltas that mattered, and why each hit the workflow** (drawn
from the vendor's own migration guidance and cross-checked against the project's recorded per-agent
token usage):

1. **Thinking on by default**, where omitting the parameter previously meant *no* thinking.
   Baseline spend on every request that never opted in.
2. **Effort re-tune required — downward.** The new generation's low and medium tiers "punch well
   above their weight", and prior-generation effort defaults are "usually not the right setting".
   The old guidance was *default high*; the new one is *start high, then sweep down*.
3. **Over-verification: DELETE verification scaffolding.** The model verifies its own work
   unprompted, and instructions telling it to verify now cause *over*-verification with **no
   capability regression** when removed. This **inverts** the standard self-check best practice —
   briefs saturated with "double-check", "re-run after every step", "prove each claim" were paying
   twice for work the model already did.
4. **Delegates to subagents MORE**, where the previous generation under-reached. Any
   *"delegate more"* guidance comes out, and an explicit cap goes in. This is where § A.3's leaf
   clause comes from: workers had the spawn tool available and were never told not to use it, so
   any fan-out multiplied cost invisibly inside a parent's totals.
5. **Longer everything** — visible responses, narration between tool calls, files written to disk,
   self-correction prose. Effort does **not** reliably shorten visible output; a prompt-level
   length instruction does.
6. **Literal instruction-following.** Every enumerated checklist item is now guaranteed spend, so a
   brief's line count is a budget. Good for correctness; price it consciously.
7. **High-resolution vision**, at roughly triple the previous per-image token cost. An
   image-reading loop can cost more than tens of agents' text work — which is why the project's
   standing ban on screenshots and image reads was kept, not relaxed.

**The measurement that settled the argument.** Grouping recorded runs by how their workers were
provisioned showed a **~2–5× per-agent spread on comparable work**, explained by two variables and
not by task difficulty: **effort tier** and **brief width**. The cheapest workers did real
multi-file analysis at the middle effort tier with one-goal briefs; the most expensive carried
maximal effort, maximal checklists and maximal verification demands. Behavioural fingerprints of
the deltas above were visible in the transcripts: reviewers independently re-measuring every figure,
golden suites run two or three times per review, several redundant build invocations per work item,
and reports of extraordinary length.

**What the study recommended, in priority order** — the durable half:

1. **Re-tune effort downward** — the single biggest lever, and the one the project's own numbers
   supported.
2. **Add a no-spawn cap to every worker brief** (§ A.3's leaf clause).
3. **Delete implementer-side verification scaffolding; keep the objective gates.** A gate is a
   pass/fail fact and is cheap to state; *"verify yourself before claiming"* prose buys the same
   work twice.
4. **Right-size review rigor by tier, deliberately.** Fresh-eyes review stays as the quality bar;
   *"re-derive every figure, everything re-measured"* is the high tier, not the default.
5. **Length-calibrate outputs in every brief** — lead with the outcome, cap report length, keep
   commit messages compact, make activity notes carry evidence pointers rather than transcripts.
6. **Slim the briefs: goal + constraints + gates, not enumerated method.** Keep the constraints
   that are not derivable (probe-truth rules, safety rails); drop step-by-step how-to the model
   plans better itself.
7. **Keep the image ban**, now at higher stakes.
8. **Make the runner honour the ladder** — per-work-item model and effort fields at every call
   site, with an explicit default rather than an inherited one.

**What the study could NOT explain, recorded rather than guessed:** whether plan-level quota
accounting also changed on the vendor's side (invisible from inside); whether any worker had in
fact spawned children during the arc (their totals would absorb them silently — the cap makes the
question moot going forward, and auditing old transcripts was judged not worth the tokens); and
exactly when the alias moved. All three are examples of § A.6's real lesson: **the alias moving is
an event you will learn about from the meter, not from your configuration.**
