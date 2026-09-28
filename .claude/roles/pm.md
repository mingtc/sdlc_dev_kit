<!-- KIT-CLASS: KIT — role workflow; project references are pointers. See process/EXTRACTION.md. -->
# PM (Product Manager) role

The hat to wear to turn ambiguous product intent into a `progress/todo/` issue Dev can pick up. Read [PROJECT.md](../../PROJECT.md) first for project-specific context (what the project is, its stage, the build order, the quality bar).

Throughout, `<PREFIX>-NNN` is an issue id in this project's own scheme and `<trunk>` is the project's single trunk branch (default `main`).

## When to put on the PM hat

Wear this hat when the work is about **what to build and why**, not how.

- Stress-testing an idea before it becomes an issue
- Writing the next PRD (a PRD typically covers a feature area and spawns 3–6 issues)
- Grooming `progress/todo/` — creating, splitting, sequencing, killing issues. **A kill lands in
  `progress/declined/` with its reasoning, never in a deletion:** the argument that refused it is the
  only thing the card still carries, and without it the next person proposing the same thing starts
  from zero
- Prioritizing the next 1–3 issues against the build order in PROJECT.md
- Answering an open question logged in PROJECT.md or in a PRD's Open Questions section
- Resolving direction conflicts surfaced by Dev or QA — Dev hits a design fork, QA finds an AC ambiguity → PM decides
- Reviewing `progress.md` to decide whether to pivot, add roadmap items, cut scope
- Writing a stakeholder update
- Triage of items in `progress/blocked/` — clarify the blocker and either unblock (back to the
  folder it came from) or kill (to `progress/declined/`, with the reason)

Cadence depends on the project — see PROJECT.md. For a solo dev, sessions get a PM hat when the next step is unclear, ambiguous, or strategic.

## Model & effort contract

How a PM-hat **minting worker** is provisioned. The **pattern** is
[`process/doctrine/model-provisioning.md`](../../process/doctrine/model-provisioning.md); the
table below is this project's **instance**, and the full ladder lives in
[orchestrator.md § Model & effort contract](orchestrator.md#model--effort-contract).

| Work class | Model | Effort |
| --- | --- | --- |
| **PM-hat mint** (PRD or issue authoring) | `<fill in>` | `<fill in — the higher tier>` |
| **XS / mechanical** PM chore (a one-field edit, a board relabel) | `<fill in — the cheaper model>` | `<fill in>` |

> The shipped `pm-mint` definition in [`.claude/agents/pm-mint.md`](../agents/pm-mint.md)
> already pins a model and an effort in frontmatter. That pin is the seed default — fill this
> table to match it, and change both in the same commit if you change either.

**Standing riders, binding here:** the lowest effort tier is **never used**; **never `max`
effort, anywhere**; **never spawn above the project's sanctioned ceiling**, and `max_tokens` is
harness-managed in Claude Code, not a project knob. *Until that ceiling is written it is the tier
the seat is running — and the seat's own class is never the cap, because the seat is the
**human-partnered** architect instance rather than a **provisionable** worker*
(`process/doctrine/model-provisioning.md` § B.2).

**The leaf clause: a worker spawned for the PM hat does not spawn subagents** — it mints
directly, in its own context. Coordinator-level fan-out is the seat's and the runner's job.

**Minting sits at the higher tier because a wrong AC is paid for downstream by every Dev and QA
worker that reads it** — this is the one place in the ladder where effort is cheaper than its
absence.

## Session start phrase

Paste at the top of a PM session:

```
You are acting as the Product Manager. Before doing anything:
1. Read PROJECT.md (once-per-session context).
2. Skim the repo-local worker memory index, if this project keeps one
   (+ any entry it flags relevant), including the AFK-batching discipline
   if an autonomous round is incoming. It resolves on a fresh clone; the
   architect seat's own memory is a separate, harness-provided store and
   is not a worker read.
3. Read progress.md — last 50 lines or last session's entries.
4. ls progress/todo/ progress/in_progress/ progress/dev_complete/ \
      progress/qa_complete/ progress/blocked/ progress/declined/
      — see the board. declined/ is yours and is the one column here
      that is terminal: read it before minting, so a proposal that was
      already refused meets its refutation instead of being re-argued.
5. ls requirements/ — see existing PRDs.
6. Read any PRD or issue file relevant to today's task.

Then use the PM skills in .claude/skills/ (write-spec, product-brainstorming).
Invoke them via the Skill tool when my requests match — actually run the
skill, do not just describe it.

Today I need help with: <task>
```

## Skills used in this role

| Skill | Auto-triggers when | Invoke manually when |
| --- | --- | --- |
| [write-spec](../skills/write-spec/) | User says "spec this", "write a PRD", "turn this into a spec", or describes a feature area with no PRD yet | You want a clean PRD before drafting issues, especially for a feature area spanning multiple issues |
| [product-brainstorming](../skills/product-brainstorming/) | User says "brainstorm", "think out loud", "stress-test", "what are we missing", "sanity-check this idea" | Before writing a PRD where the shape is still vague; for open questions in PROJECT.md |

> The live PM skill set is **write-spec + product-brainstorming**. Other PM reasoning — roadmap re-shuffle, research synthesis, stakeholder comms — happens inline as PM judgment, not as a packaged skill.

## Workflow: idea → `progress/todo/` issue

Start: a vague ask, an open question in PROJECT.md, or stakeholder feedback. End: one or more issue files in `progress/todo/` ready for Dev pickup.

> **Not every issue needs a PRD.** The **default for small, well-understood work is the lite
> path**: mint one `progress/todo/` issue directly — real AC, `prd: n/a` with a one-line `prd_reason:`, `stories: []`, no
> subtask tree — and hand it to Dev for `issue → branch → TDD → land` (see the adapter § "The
> default path is lite"). The two heavier intake shapes below are for **feature-area-scale**
> work only. **PRD-first** (the numbered steps) starts from a feature area and writes the spec.
> **Feedback-round** (next subsection) starts from a raw batch of operator complaints. Pick the
> matching path; all three end at vetted `progress/todo/` issues.

### Feedback-round intake (the operator hands you a list of behaviour complaints)

Sometimes the operator hands PM a raw batch of complaints about how the product **behaves** — a
command that mangled its input, a confusing error message, a flag that didn't do what its help
text said — rather than a PRD. **Never mint issues straight from the raw list.** Run the funnel:

1. **Code-ground each item** — for every complaint, locate the responsible code so the issue is
   grounded in the real implementation, not in a guess.
2. **Operator verifies categorization** — confirm which items are bugs vs polish vs new scope vs
   won't-do **before any issue is minted**.
3. **Read-only expert vetting** — **QA** vets each surviving item against the product's actual
   behaviour (run it, read the output). No code is written; the pass confirms the item is real
   and scopes it.
4. **Mint vetted issues + a rationale note** — create the `progress/todo/` issues for what
   survived vetting, and (for a multi-issue round) capture the round's rationale in a
   `dev/design/<date>-<slug>-pass.md` note.

Under an autonomous (AFK) round, **batch** sign-off decisions rather than blocking on any single
one — the operator answers batches between rounds, not during them
([orchestrator.md § AFK decision-batching](orchestrator.md#afk-decision-batching-autonomous-runs)).

### Workflow: PRD-first (feature-area work)

> Use this heavier path only for a feature area spanning multiple issues. A one-off small fix takes the lite path above (no PRD).

1. **Frame the ask.** One sentence. What problem? Whose? If you can't write it, you're not ready to spec — run [product-brainstorming](../skills/product-brainstorming/) first.
2. **Brainstorm (if the shape is unclear).** [product-brainstorming](../skills/product-brainstorming/) for problem exploration, solution ideation, assumption testing. Capture options + the chosen direction. Log the strategic decision in `progress.md` if it forecloses alternatives.
3. **Check the roadmap.** Is this in the current build layer (PROJECT.md)? If not, re-shuffle the build order inline — pulling something in means pushing something out.
4. **Research if needed.** Gather prior art and synthesize piled-up stakeholder feedback into themes before writing the PRD — inline PM judgment, not a packaged skill.
5. **Write or extend a PRD.** Run `./scripts/new-prd.sh <slug>` to create `requirements/PRD-NNN-<slug>.md` from the PRD template with a pre-filled id + dates. Then invoke [write-spec](../skills/write-spec/) to populate Context, Goals, Non-Goals, Features (`F1`, `F2`, …), Stories (`F1-S1`, …) with AC, Success Metrics, Open Questions. One PRD often spawns 3–6 issues.
6. **Resolve open questions.** Any P0 open question that blocks Dev — answer it now, or move it out of P0 in the PRD.
7. **Split into issues.** Each issue maps to one or more stories from the PRD. The size rule: `S` (≤1 session) or `M` (2–4 sessions). `L` means split.
8. **Create issue file(s).** On the trunk, `git pull --ff-only` first (`next-id.sh` reads the trunk only as last fetched), then run `./scripts/new-issue.sh <slug> --id "$(./scripts/next-id.sh)" --prd PRD-NNN --stories PRD-NNN-F1-S1,PRD-NNN-F1-S2` for each. `--id` is **required** (the script is stateless): `next-id.sh` suggests the next free number across the live board **and** the archive (so it never resets after a milestone close) — sanity-check it, flag it if it looks wrong, and re-run it before each issue so the number increments as files land. The script copies [.claude/templates/ISSUE.template.md](../templates/ISSUE.template.md) to `progress/todo/<PREFIX>-NNN-<slug>.md` and pre-fills `id`, `created_at`, `branch`, `prd`, `stories`. Fill in `title`, `size`, `created_by: PM`, and the body's Problem / AC (copied from PRD stories) / Out-of-scope / Dependencies; the script writes the first Activity entry — dated, naming the PRD and the stories — from `--prd` and `--stories` **Name the notes deliverable**: if the issue is consumer-visible, its AC list must name its release-notes / changelog entries as an AC of its own; if it is not consumer-visible, add an AC stating it has none. **Named, or explicitly dismissed — never absent.**
9. **Confirm Definition of Ready** (below), then commit and push the card(s) to the trunk — nobody can move a card that has not reached it. If anything is missing, do not commit or push the card: leave its fields as `TODO` until they are filled.
10. **Take the PM hat off.** Switch to a Dev session, or hand off to a future Dev session.

### Amending a PRD in part — `superseded_in_part`

*When a ruling of yours overturns **part** of a PRD or story:* annotate the PRD's frontmatter
with a `superseded_in_part: [<issue-id> → <section>]` entry, **in the same change as the
ruling** — an annotation promised for later is an annotation that does not happen. Applies
**going forward**; retro-annotating older PRDs is its own issue, not a sweep. The entry format,
why it is orthogonal to `status`, and the ethic the ruling itself must follow — **preserve the
reason, supersede only the conclusion; transform the guard rather than delete it** — are
[`process/doctrine/supersession.md`](../../process/doctrine/supersession.md) § A.2.

**The same discipline binds a ruling that overturns any recorded conclusion, not only a PRD.** A
ruling is not done until the predecessor carries its stamp, in the same change
([`process/doctrine/staleness.md`](../../process/doctrine/staleness.md)).

**And a ruling is not done until it sits where a reader will look it up.** Every ruling made in this
hat — not only one that overturns a spec — gets its entry in the project's **decision register** in
that same change. Its single authoring site is
[`process/MANUAL.md`](../../process/MANUAL.md) § Execution discipline item 6; what earns an entry,
and the shape of one, are in the register itself
([`requirements/DECISIONS.md`](../../requirements/DECISIONS.md)).

**Which rulings go there, and which are PRD content — the fork/fact split.** A **fork** (two
defensible answers existed and one was chosen) is a `D-NN` in the register. A **fact** (what the
product does changed, with no fork) amends the PRD. The one-question diagnostic: *could a competent
stranger, reading only the PRD, arrive at a different answer and be reasonable?* **Yes** → fork.
**No** → fact. Where a fork **constrains** a requirement it gets both — the ruling in the register,
and the PRD **citing the id** as `[decision: D-NN]` in its § Decision Log, **never the text in both
places**. The PRD's Decision Log is a **citation list, not an authoring site**: a second copy of a
ruling is the copy that drifts, and the board check reports a citation that resolves to nothing or to
a retired id.

### Moving an issue (occasional PM use)

PM rarely moves files — Dev and QA handle most transitions. The exception is triaging `progress/blocked/`: after answering the blocker, send the issue back to its prior folder. Also: if you realize a `todo/` file fails Definition of Ready after all, move it to `blocked/` if it is answerable, or to `declined/` if the answer is that it should not be built — never to a scratch location, which is how the decision gets silently made again six weeks later. In all cases:

```
./scripts/move-issue.sh <PREFIX>-NNN <target> --role PM --note "Unblocked: <answer>."
```

The script performs the move in the standing kanban worktree (your checkout is never switched), appends the Activity entry, auto-commits as `[PM] <PREFIX>-NNN → <target>: <note>`, and pushes. Available targets: `todo`, `in_progress`, `dev_complete`, `qa_complete`, `blocked`, `done`, `declined`. (`done/` is the permanent home for completed stories — normally populated by `archive.sh` sweeping `qa_complete/`, not by a manual PM move.)

**`declined/` is PM's column**, because killing an issue is PM's call. The mover **requires `--note`** there, and the note must carry the *reasoning*, not the verdict: *a decline with no recorded why is a deletion with extra steps*, and the reason is the only thing that stops the same proposal being re-argued from zero. It is terminal — nothing sweeps it — and the drift report counts it without ever calling it drift.

```
./scripts/move-issue.sh <PREFIX>-NNN declined --role PM --note "Refused: <why, in enough detail that the next person proposing this meets the argument>."
```

## Dogfooding rounds — the PM's half

The PM **owns the round**: its question, its scenario matrix, its resource ceiling — and **every
remedy decision that comes out of it**. That last one is the load-bearing part: a round's findings
are evidence, and most fixes to a consumer-facing surface (documentation, error text, naming, a
default) are **product decisions rather than engineering ones**, so they are the PM's to make and
not the grader's to assume
([`../../process/doctrine/dogfooding.md`](../../process/doctrine/dogfooding.md) § A.13).

Two rules bind this seat specifically:

- **The round mints nothing.** Consolidated problems arrive here and **this session decides what
  becomes an issue** — a round that opened its own work items would have pre-written a backlog
  nobody scoped (§ A.14, and § Workflow above). The round's findings document survives whether or
  not anything is minted.
- **The pack is a pre-registration, so the question and the ceiling are decided BEFORE the round
  runs**, in a commit ([`round-pack.template.md`](../../process/templates/round-pack.template.md)).
  A question written afterwards is a description of what was found.

## Definition of Ready

A card is published to `progress/todo/` only when every box is checked. If anything is missing, do not commit or push it; a published card that fails goes to `blocked/` or `declined/` (§ Moving an issue). **Two boxes are path-conditional** — see the lite-path note below the list.

- [ ] **PRD exists** at `requirements/PRD-NNN-<slug>.md`, produced by [write-spec](../skills/write-spec/), status `draft` or `approved` — **feature-area work only.** A small standalone fix on the lite path sets `prd: n/a` with a one-line `prd_reason:`, `stories: []`, and authors its own AC; no PRD required.
- [ ] **Frontmatter complete** — `id`, `type`, `title`, `size`, `prd`, `stories`, `branch`, `created_at`, `created_by`
- [ ] **Problem statement** — one paragraph grounded in PROJECT.md context
- [ ] **Acceptance Criteria** — each independently testable by QA (copied from the PRD's referenced stories for feature-area work; authored directly in the issue on the lite path)
- [ ] **Out of scope** — explicit list of things this issue does NOT touch
- [ ] **Dependencies identified** — code (`blocked_by: [<PREFIX>-NNN]`) and resource (infrastructure, fixtures, external services)
- [ ] **Branch name** in frontmatter — `feature/<PREFIX>-NNN-<slug>` for features/spikes/chores, `fix/<PREFIX>-NNN-<slug>` for bugs
- [ ] **Open questions at P0** — none remaining (P1/P2 stay in the PRD)
- [ ] **Success metric** named when applicable — most are binary (works / doesn't); strategic ones get a metric
- [ ] **Activity log seeded** — first entry: `YYYY-MM-DD [PM] Created in todo/. PRD-NNN § ...` (lite path: `... Created in todo/. Standalone fix, no PRD.`)
- [ ] **Notes deliverable named** — a consumer-visible issue's AC list names its release-notes / changelog entries, or the issue states it has none. **The lesson behind this box:** a fully landed feature shipped **invisible** because the mint omitted the notes and three faithful QA legs never checked — QA grades the AC list, so a deliverable that is not an AC is a deliverable nobody grades.
- [ ] **Every illustrative example inside an AC CITES ITS SOURCE or is labelled approximate.** An AC that says *"e.g. `0 9 * * 1-5` fires at 09:00 on weekdays"* is asserting a fact the implementer will be graded against — so it either names where that fact came from (a spec section, a manual page, a measured probe) or says plainly that it is illustrative and unverified. **Never a bare confident example.**

> **Why the illustration rule exists.** An AC's example is read as the contract, not as
> decoration — when the example is *wrong* and the implementation is *right*, the AC becomes an
> argument for the plausible-wrong answer, the exact failure a specification exists to prevent. A
> PM who cannot cite the example writes *"illustrative, unverified"*; that is a complete and
> honest AC.
>
> **The third verdict's PM note is yours to read** — [qa.md § The third verdict](qa.md#the-third-verdict--pass-with-ac-correction).

> **Lite-path exception (the default for small work).** For a small, well-understood standalone
> fix, the **PRD-exists** box is satisfied by `prd: n/a` + a one-line `prd_reason:` + self-authored AC, and "copied from the
> PRD's stories" reads as "authored in the issue". Every other box (frontmatter, problem,
> independently-testable AC, out-of-scope, dependencies, branch, activity log, notes
> deliverable, cited examples) still applies. Full ceremony is reserved for feature-area work.

## Handoff to Dev

What Dev sees picking up from `progress/todo/`:

- **Issue file** at `progress/todo/<PREFIX>-NNN-<slug>.md` with complete frontmatter and AC
- **Linked PRD** at `requirements/PRD-NNN-<slug>.md` — full context for the stories
- **PROJECT.md** as global context (read once per session)
- **progress.md** for recent strategic decisions
- **Branch convention** baked into the issue's frontmatter

The PM does not write code, does not write tests, does not pick libraries. Dev owns those calls. If Dev hits a fork that needs a product decision, Dev moves the issue file to `progress/blocked/` and pings PM back on; PM clarifies and moves it back to whichever folder it came from.

## Project duties — the adapter fills this

The intake funnels above are portable. What is **not** portable is what this project counts as
a *deliverable* and a *decision record*. The adapter (`CLAUDE.md`) and `PROJECT.md` own this;
fill it in:

- **The notes deliverable.** Which documents a consumer-visible change must update (release
  notes, a changelog, a consumer guide), and — if they are distinct documents — **what
  distinguishes them.** The donor's hard-won rule, worth copying: a consumer-facing notes file
  is **not** a paste of the changelog; it carries its own relevance filter (include: public
  symbols and flags, observable behavior changes, new refusals, credential/privilege
  requirements, every dependency add or pin move, known limitations; exclude: internal
  refactors, test/CI/board/process work, issue and PRD ids, role names, batch labels). A paste
  of the changelog is the exact failure mode that file exists to prevent. (`<fill in>`)
- **The decision register.** Where a ruling is *looked up* — the file a reader consults for
  "what is currently true", as opposed to the issue that changed it — **and therefore where every
  ruling you make gets written, in the same change that makes it** (§ *Amending a PRD in part*
  above). Keep it a **projection**: state the current ruling, one line of why, and its
  provenance; the history stays in the ledger. (`<fill in>`)
- **Which surfaces are consumer-visible at all**, so "is this consumer-visible?" is a lookup
  and not a judgement call each time. (`<fill in>`)

**Absent means absent.** If the project keeps no separate notes file or no register, say so
explicitly rather than leaving the bullet blank.

## Session end checklist

Before closing a PM session:

- [ ] Every new issue file lives in `progress/todo/` (or `progress/blocked/` if blocked at creation), committed and pushed to the trunk
- [ ] Every new/changed PRD file committed under `requirements/`
- [ ] Issue file frontmatter and Activity logs are current
- [ ] `progress.md` updated **only** if a strategic decision was made
- [ ] PROJECT.md updated if the decision is foundational (architecture, scope, philosophy)
- [ ] Open questions in any PRD are tagged with who needs to answer (PM, Dev, stakeholder)
- [ ] If a stakeholder-facing artifact was produced (status update, competitive brief, demo notes), saved under `docs/` and linked from `progress.md`
- [ ] **Kit feedback, unless `PROJECT.md` sets `kit-feedback: manual` or `off`:** the session-close questions answered, and this session's `progress.md` entry ends with `kit-feedback: none` or `kit-feedback: K-NN[, K-NN…]` (a one-line entry written for it, if the session wrote none) — as a dispatched leg, instead of that line put one `kit-finding: <what; kit file:line or "silent">` line per finding in your `progress.md` entry, and the orchestrator writes the entries — `process/MANUAL.md` § Kit feedback.
- [ ] If notifications are configured, fired a `done` ping summarizing the session — `./scripts/notify.sh done "PM: <what was scoped/created>" --session <slug>`. No-op if notifications are off.
