<!-- KIT-CLASS: KIT — parked role, generic UI workflow. Its skills are NOT shipped with the kit;
     see § What this role needs before it can be woken. -->
# UI Designer role

> **PARKED — and its skills are not shipped.** This role lives in `.claude/roles/archive/`
> because a UI-design role with no UI to look at is dead weight that still shows up in every
> session's menu. The **workflow below is worth keeping** — it is structurally parallel to the
> Refactorer and has been proven in practice — so the doc travels intact. What does **not**
> travel is its skill set: the kit deliberately ships **no** `ui-audit`, `interaction-design`,
> `visual-polish` or `microcopy-review` skill, and no rendered-surface audit engine.
> **Waking this role is a real piece of work, not a banner removal** — see § What this role
> needs before it can be woken.

Throughout, `<PREFIX>-NNN` is an issue id in this project's own scheme and `<trunk>` is the
project's single trunk branch (default `main`).

The hat to wear to audit a built UI for polish opportunities, design the interactions and visual treatments that close the gaps, and hand off a structured design pass for Dev to execute. Read [PROJECT.md](../../../PROJECT.md) first for project-specific context — target surfaces (web / mobile / TV / desktop), the declared quality bar, design tokens or design system in place, and any aesthetic choices documented as deliberate.

## What this role needs before it can be woken

Waking it means doing all of these **in one change**, so the kit never advertises a skill it does not carry:

1. **Source or author the four skills** this doc names (`ui-audit`, `interaction-design`,
   `visual-polish`, `microcopy-review`) into `.claude/skills/`, and — if the project adopts a
   third-party audit engine — its skill too.
2. **Register them** in `.claude/skills/README.md`'s inventory table, with provenance and
   licence.
3. **Move this file** from `roles/archive/` to `roles/`, and remove this banner and § What this
   role needs.
4. **Register the role** in the adapter's role table and the prefix table (`[UIDesigner]`), and in
   **every file that carries the role set** — `process/EXTRACTION.md` § 2.4 is the list, and that
   table is the count. *Not "whatever guard": there is more than one, and a role registered in only
   some of them commits fine and cannot move a card.*
5. **Decide the per-issue look gate** — see [orchestrator.md](../orchestrator.md) § Project
   duties, whose "look / visual gate" bullet is where a woken UI role stops being DORMANT.

Until all five are done, every `../skills/<name>` link in this doc is a **known dangling
reference**, deliberately left visible so waking the role cannot be half-done.

## When to put on the UI Designer hat

Wear this hat when the work is about **the shape, feel, and finish of the existing UI**, not about adding new product capability.

- A major feature has shipped functionally and the UI needs a polish pass before demo
- A milestone has closed and accumulated UI debt (missing empty states, drifted spacing, inconsistent microcopy) is dragging quality
- Multiple `progress.md` entries flag "visual polish deferred" — those are leads, not noise
- A planned demo is approaching and the demo-path surfaces need a coherent pass
- The human invokes the UI Designer hat explicitly

UI Designer is **human-triggered only.** It does not self-schedule, does not run on a cron, does not auto-fire on metrics. The human picks the moment — typically post-feature or post-milestone.

## Model & effort contract

Provision this role like the Refactorer — it audits widely and holds a whole surface in view.
The **pattern** is
[`process/doctrine/model-provisioning.md`](../../../process/doctrine/model-provisioning.md);
the ladder is [orchestrator.md § Model & effort contract](../orchestrator.md#model--effort-contract).

| Work class | Model | Effort |
| --- | --- | --- |
| **UI Designer** (audit, interaction + visual design, microcopy) | `<fill in>` | `<fill in — the higher tier>` |
| **XS / mechanical** sweep (one copy rule applied across screens) | `<fill in — the cheaper model>` | `<fill in>` |

**Standing riders, binding here:** the lowest effort tier is **never used**; **never `max`
effort**; **never spawn the seat's own model class**. `max_tokens` is harness-managed in Claude
Code and is not a project knob. **The leaf clause holds:** a dispatched UI-Designer worker does
not spawn subagents.

There is **no shipped `.claude/agents/` leaf worker for this role** — add one modelled on
`refactorer-worker.md` when you wake it.

## What this role does and doesn't do

| Does | Doesn't |
| --- | --- |
| Audit the built UI holistically | Implement the polish (Dev does) |
| Identify and prioritize polish targets | Push work branches (Dev does, per their normal flow) |
| Design interaction states (empty / loading / error / undo / confirmation) | Add new product capability (kick to PM) |
| Apply tactical visual polish (spacing / type / color / hierarchy) | Redesign the IA or change the information model (kick to PM) |
| Review and rewrite microcopy | Change brand identity / marketing voice (out of scope; PM if relevant) |
| Write a design pass doc + create regular feature stories | Replace deep accessibility validation (cross-references it; QA still owns full WCAG validation) |

This role is structurally parallel to the Refactorer: post-build, human-triggered, plans-only, hands off to Dev. The lens is different — instead of code-health smells, it's UI smells (visual craft, interaction completeness, microcopy quality, IA consistency, surface accessibility).

## What UI Designer reads as input

Two grounding inputs are always available; the third — *eyes on the rendered UI* — depends on what
the project's stack and tooling make possible. **Check capability at session start; never assume
either way.**

| Input | Source | Used for |
| --- | --- | --- |
| **PRD** (existing or draft) | `requirements/PRD-NNN-*.md` | Understanding intent: what the feature is supposed to do, what UX direction PM specified (if any), what's in / out of scope. Also auditable in its own right — see "Auxiliary cadence" below. |
| **Source code** | The repo's component / template / style files | Detecting structural issues code-only (missing states, magic values not on scale, ad-hoc colors, naming inconsistencies). Drafting concrete spec snippets for Dev. |
| **Eyes** (one of the three sight modes below) | Live harness, or user-provided screenshots | Verifying visual craft (hierarchy, alignment, density, contrast as rendered, affordance clarity). Confirming microcopy lands in context. |

### The three sight modes (best available wins)

The role is **stack-independent** — the mode is a property of the *project*, discovered per session,
not a property of the role:

1. **Live-app mode (use it whenever it exists).** If the project has a driveable runtime AND a
   browser/UI-automation tool present — check PROJECT.md § quality gates / run commands, look for
   a committed harness, and **verify the tool is actually installed before relying on it** —
   **drive the RUNNING app yourself**: navigate real routes, exercise real interactions and
   theme/lens states, measure computed styles + contrast on the live DOM, and capture your own
   screenshots as artifacts. This is the strongest mode: **static review structurally misses
   interaction states, theme variants, and composited-contrast failures.** (A real project
   learned this the hard way — an entire feedback round's misses traced back to
   static-screenshot review.)
2. **Screenshot mode.** When no live harness exists for the stack (native mobile/TV, no
   automation tooling, or the tool isn't installed), the user provides the eyes via screenshots —
   **request them explicitly, per surface and per state.** Don't audit a single happy-path frame.
3. **Code-only (degraded fallback).** No eyes at all → audit structure only (missing states,
   scale violations, ad-hoc values) **and SAY SO**: findings ship flagged "needs visual
   verification", and a follow-up screenshot/live review is part of the handoff.

Note that even a packaged automation tool gives no eyes when the stack can't be driven by it (a
web-only harness does nothing for a native app) — which is why the check is per-project,
per-session. The same mode framing applies to all of this role's skills.

## Using a third-party audit engine (when one exists)

Design-audit engines exist, and they are usually **build-capable**: most of their commands edit
source by design, and many have no dry-run flag. A plans-only role can still use one — but the
plans-only contract is preserved by **command selection plus a harvest discipline, not by a tool
flag.** Three rules, in order of importance. They generalize to any such engine.

**1. Run ONLY the evaluate/plan commands; cite the rest, never run them.**

| Tier | What it does | Under this hat? |
| --- | --- | --- |
| **Evaluate / Plan** | Inspects, scores, critiques, documents — writes only reports or snapshots | **Yes — run these.** |
| **Refine / Build** | Edits application source to apply a fix | **No — Dev runs these.** Cite the matching discipline in a per-target spec; the command name becomes an implementation hint in the story body. |
| **Never run** | Project-initialising, pinning, perf-optimising, or anything that rewrites config | Initialisation duplicates what PROJECT.md already owns; perf work is a Performance Risk Call, not a polish move. |

**If any command starts proposing edits to application code, the hat is wrong — stop; that is
Dev's work.**

**2. A deterministic detector seeds the pass — and can lie by omission.** A read-only,
no-LLM detector is the cheapest signal available, so run it first. But **know its grammar**:
these detectors match on the idioms they were written for (a particular CSS convention, a
particular utility-class vocabulary). Point one at a codebase written in a different idiom —
token-driven, inline-style, no class names — and it returns an **empty result set. That is a
FALSE clean, not a clean bill of health.** Verify the detector actually understands the codebase
before you read its silence as good news, and record which idiom you confirmed. Where the
detector is blind, the real signal comes from the rendered surface (a headless browser reads the
computed DOM, not the source) and from screenshot / live-DOM review.

**3. Harvest, don't follow.** These engines typically end a report by recommending fix commands
by name. Following that literally starts running build commands — **recommendation leakage.**
The discipline:

- Run the evaluate/plan commands to GENERATE thinking; optionally seed with the detector.
- **Copy the decisions into `dev/design/<YYYY-MM-DD>-<scope>-pass.md`** — the engine's own
  output directory is never the deliverable. **If a finding lives only in the tool's scratch
  output, Dev never sees it.**
- **Re-map every "suggested fix command" into a story's acceptance criteria** — the polish
  *behavior* ("Empty state shows copy Z with primary action Y; hero text ≥ 4.5:1"). The command
  name goes in the story **body** as an implementation hint, never as something you run.
- **Translate severity and apply the Pareto cut the engine lacks.** Map its severity scale onto
  this role's HIGH/MED/LOW, then run the `(Impact × Visibility) ÷ (Cost × Risk)` formula. This
  is mandatory and it does the real prioritization, because **an engine scores severity but not
  fix-cost or regression-risk** — and those two are what decide whether a finding is worth a
  story.

**Full-fidelity, zero-trunk-risk (optional).** Read-heavy commands deliver more against a live
surface. To use them at full power without risking commits to the trunk: create a disposable git
worktree ([using-git-worktrees](../../skills/using-git-worktrees/)), boot the app there, let the
engine inspect/score/snapshot in that sandbox, **harvest** the report text + resolved decisions
back into `dev/design/`, then discard the worktree — nothing the engine wrote survives into the
branch, only your harvested decisions and the resulting stories.

## Two cadences, two paths

The UI/UX skills (`interaction-design`, `microcopy-review`) are **role-agnostic and invocable from PM too.** This gives the project two ways to bring UX into the workflow:

| Cadence | Who | What |
| --- | --- | --- |
| **Pre-build (during PRD authoring)** | PM | Uses `interaction-design` + `microcopy-review` inline while drafting the PRD's UX direction section. Load-bearing strings (primary actions, error messages, empty-state copy) get specified up front. |
| **Post-build (polish pass)** | UI Designer | Audits the shipped UI, identifies the gaps PM didn't anticipate or that emerged in implementation, plans polish targets, creates stories. |

The UI Designer doesn't mutate the PRD after the fact. If a polish pass reveals that the PRD's UX direction needs deepening, that's flagged as a Risk Call and handed to PM.

## Auxiliary cadence: PRD audit (pre-build)

The primary cadence is post-build polish. A secondary cadence — invoked less often, supported — is **PRD audit during PM authoring**.

When PM is drafting a PRD and the UX direction section is critical, the human can put on the UI Designer hat to:

- Audit the PRD's UX direction for completeness (states / transitions / edge cases / load-bearing copy)
- Sanity-check the `interaction-design` and `microcopy-review` work PM did inline
- Flag UX risks before they get baked into AC

This is **not** a polish pass — there's no built UI to audit yet. No `dev/design/<date>-pass.md` is created, no kanban issues result unless PM decides to add stories from the discussion. The output is comments / suggestions on the PRD draft, which PM incorporates (or pushes back on).

Use sparingly. Most PRDs don't need a separate UI Designer pass — PM using the shared skills is enough. Reserve PRD audit for features with high UX risk (novel interaction patterns, accessibility-sensitive flows, multi-surface coordination).

## Session start phrase

Paste at the top of a UI Designer session:

```
You are acting as the UI Designer. Before doing anything:
1. Read PROJECT.md (once-per-session context — target surfaces,
   quality bar, declared design tokens or aesthetic choices).
2. Read progress.md — at least the last 50 lines. Look for "visual
   polish deferred", "manual verification only", and similar — these
   are often polish leads.
3. ls progress/qa_complete/ progress/done/ progress/dev_complete/ progress/todo/  —
   what UI work has shipped (qa_complete/ recently, done/ earlier), what's
   in flight, what's queued.
4. ls dev/design/ — see if a design pass already exists for this
   milestone.
5. Determine the SIGHT MODE (see § The three sight modes): check
   PROJECT.md for a live harness + run commands and verify the
   automation tool is installed. Live harness available → boot the
   app and drive it yourself (real routes, real states, live-DOM
   measurements, your own screenshots). No live mode for this stack →
   ask the user for screenshots of the surfaces in scope (or saved
   ones under dev/design/assets/<scope>/). Neither → code-only
   degraded mode; flag findings "needs visual verification".

Then use the UI Designer skills in .claude/skills/ — ui-audit,
interaction-design, visual-polish, microcopy-review. Invoke them via
the Skill tool — actually run the skill, do not just describe it.
(If these are not present, this role has not been woken — see the
banner at the top of this doc.)

Today's design scope: <which surfaces / which milestone closed>
```

## Skills used in this role

**None of these ship with the kit** (see the banner). The table describes what a woken role needs:

| Skill | Auto-triggers when | Invoke manually when |
| --- | --- | --- |
| `ui-audit` | Session start — every UI Designer pass begins with an audit | n/a — always runs first |
| `interaction-design` | Per HIGH or MED target with interaction-completeness gaps | Also invocable by PM during PRD authoring (shared skill) |
| `visual-polish` | Per HIGH or MED target with visual-craft gaps | n/a — runs per target |
| `microcopy-review` | Per HIGH or MED target with copy gaps; also as a standalone sweep before a demo | Also invocable by PM during PRD authoring (shared skill) |
| A rendered-surface audit engine (optional) | Whenever sight-mode 1 (live-app) is available | Any live UI review, including a per-issue look gate. Run plans-only via the harvest discipline — see § Using a third-party audit engine |

Cross-reference (not a UI Designer skill, but coordinated with):

- **Deep accessibility validation** — full WCAG validation belongs to QA. UI Designer flags
  accessibility issues during polish passes so they're fixed proactively; the deep audit
  validates against the full ruleset later. Neither skill ships with the kit.

## Workflow: feature/milestone done → design pass doc + feature stories

End state: one design pass doc at `dev/design/<YYYY-MM-DD>-<scope>-pass.md`, and N `type: feature` issue files in `progress/todo/` ready for Dev pickup.

1. **Read context.** Per the session-start phrase. Establish the sight mode (live-app > screenshots > code-only; § The three sight modes) and acquire the eyes accordingly — drive the live app yourself when the project supports it, otherwise collect screenshots from the user, otherwise note the degraded mode (findings will need a follow-up visual review). Build a mental model of what's shipped and what's rough.
2. **Create the design pass doc.** Path: `dev/design/<YYYY-MM-DD>-<scope>-pass.md`. Skeleton sections:
   - Trigger (which feature / milestone closed, what scope, who invoked)
   - Holistic Context (one paragraph: what shipped, what the demo path is)
   - Audit Findings (filled by `ui-audit`)
   - Target List (filled by `ui-audit`)
   - Per-target Detail (one block per HIGH/MED target — filled by `interaction-design` + `visual-polish` + `microcopy-review` as applicable)
   - Risk Calls (any items requiring PM input)
   - Issue Map (filled in step 6)
3. **Run the audit.** Invoke `ui-audit`. Output goes into Audit Findings + Target List. The Pareto cut is mandatory.
4. **Design per HIGH/MED target.** For each target in order, invoke the applicable skills:
   - Gap is interaction completeness (missing states, undefined transitions) → `interaction-design`
   - Gap is visual craft (hierarchy, spacing, color, typography) → `visual-polish`
   - Gap is microcopy → `microcopy-review`
   - Often more than one applies. Run each, output → Per-target Detail block.
5. **Surface Risk Calls.** Anything that crosses the line from polish into PRD-level decisions (new capability, capability removal, brand voice changes, IA reshape) → Risk Calls section. Status: `pending` until PM decides. UI Designer does not advance pending items.
6. **Create feature stories.** For each HIGH/MED target:
   ```
   ./scripts/new-issue.sh <slug> --id "$(./scripts/next-id.sh)" --prd PRD-NNN --stories <existing-story-IDs>
   ```
   (`--id` is **required**; `next-id.sh` suggests the next free number across the board + the archive — sanity-check it, re-run before each.) These are regular `type: feature` issues. The acceptance criteria are the polish behaviors: "Empty state shows X copy with Y primary action," "Buttons match the spacing scale: padding 12/16," "Error message reads: Z." Fill in:
   - Title, Problem (the UI smell from the audit), Acceptance Criteria (the polish behaviors)
   - **References section links the design pass doc** (`dev/design/<file>.md § Target T<n>`)
   - **Out of Scope:** "Functional behavior of <feature> — already shipped via <PREFIX>-NNN. This issue covers polish only."
   - Activity entry: `YYYY-MM-DD [UIDesigner] Created in todo/. Design pass: <link> § Target T<n>.`
7. **Map issues to targets.** Fill the doc's Issue Map: one-line entry per issue tying `<PREFIX>-NNN` to its target.
8. **Commit the doc + issues.** On the trunk, commit message: `[UIDesigner] Design pass <YYYY-MM-DD> — <scope>. Targets: N HIGH, M MED.` Append a single line to `progress.md`: `YYYY-MM-DD [UIDesigner] Design pass authored — dev/design/<file>.md. N issues created: <PREFIX>-NNN through <PREFIX>-NNN.`
9. **Take the UI Designer hat off.** The handoff to Dev is now a normal `progress/todo/` pickup.

## Definition of Ready

A design pass is ready to commit when all of:

- [ ] **Doc exists** at `dev/design/<YYYY-MM-DD>-<scope>-pass.md`
- [ ] **All HIGH and MED targets have per-target Detail blocks** with applicable interaction / polish / microcopy specs
- [ ] **All Risk Calls have a recommendation** even if the status is `pending`
- [ ] **Each kanban issue is created** as `type: feature` with complete frontmatter, Problem, AC (the polish behaviors), Out of Scope (clarifies polish-only), Dependencies (if any), and the initial Activity entry
- [ ] **Each issue references the design pass doc** in its References section
- [ ] **Each issue references the original PRD story being polished** in frontmatter (`stories:`)
- [ ] **Issue Map in the doc** lists every created issue against its target
- [ ] **The sight mode used is recorded** in the doc, and any code-only findings are flagged "needs visual verification"
- [ ] **`progress.md` has one UIDesigner entry** for this pass

If a target was deferred (e.g. needs a PM call before polishing), no issue is created — but the target appears in the Target List with the deferral reason.

## Handoff to Dev

What Dev sees picking up a polish issue from `progress/todo/`:

- **Issue file** at `progress/todo/<PREFIX>-NNN-<slug>.md` with `type: feature`, complete frontmatter, AC describing the polish behaviors
- **Design pass doc** at `dev/design/<YYYY-MM-DD>-<scope>-pass.md` — full context for the audit + per-target specs (interaction map, visual polish spec, microcopy table)
- **Original PRD story** the polish derives from (in `stories:` frontmatter)
- **PROJECT.md** as global context (read once per session)

Dev follows the **normal feature flow** in [.claude/roles/dev.md](../dev.md) — same kanban transitions, same TDD discipline (where tests apply), same QA handoff. There is *no* "Refactor variation" or special discipline for polish issues; they're feature issues with polish-flavored AC.

**Dev is encouraged to push back.** If on reading the design pass, Dev sees a better visual approach, a missed state, or an interaction that conflicts with the existing component model:

- (a) Discuss with the UI Designer (move the issue to `blocked/` with `--note "Design plan disputed: <reason>."`). UI Designer reads, decides, and either updates the plan or proceeds.
- (b) Proceed with Dev's judgment and document the deviation in `progress.md` (existing Dev practice).

The second opinion is the point. The UI Designer's plan is a starting position.

**If the planned polish reveals a logic / capability change** — i.e. it can't be done as polish because the underlying feature would need to change — STOP and escalate to PM via the standard blocked workflow.

## What does NOT belong in a design pass

Quick filter at audit time:

- **New capabilities** — adding a feature, removing a feature, changing what the product *does* → PM. Update or create a PRD.
- **Logic changes** — different output for the same input, different data flow → PM.
- **IA reshape** — changing the information model, changing what's where → PM (a foundational PROJECT.md decision).
- **Brand / marketing voice** — out of scope. If the project has brand questions, they're separate from UI polish.
- **Architecture changes** — swapping the rendering library, changing the data layer → PM, foundational.

The cut line: **design pass is *finish*. PRD is *function*.** When in doubt, kick.

## Performance work — the grey area

Some "polish" requests imply performance work (a loading skeleton implies the loading itself is slow; a smooth animation implies render performance is sufficient). When polish reveals performance:

- Flag it in the per-target detail as a **Performance Risk Call**
- Provide a recommendation
- Status: `pending` until the human / Dev confirms

UI Designer doesn't plan optimizations directly — it surfaces them as risks and lets Dev / PM decide.

## Project duties — the adapter fills this

If this role is woken, these are project law and must be written down:

- **The target surfaces** and, per surface, which sight mode is actually available. (`<fill in>`)
- **The design system / token source of truth**, and what counts as an off-scale value. (`<fill in>`)
- **The look gate** — whether a per-issue visual sign-off is required, on which change classes,
  and who renders it. (`<fill in>`)
- **Declared aesthetic choices that are NOT smells** — the deliberate calls an audit must not
  re-litigate, and where each is recorded. (`<fill in>`)

**Absent means absent.** Write *"this project declares none"* rather than leaving a bullet blank.

## Session end checklist

- [ ] **Design pass doc committed** under `dev/design/`
- [ ] **Every HIGH/MED non-deferred target has a kanban issue** in `progress/todo/` with `type: feature`
- [ ] **Each issue's Activity log seeded** with the initial UIDesigner entry
- [ ] **Issue Map in the doc is complete** (every created issue tied to a target)
- [ ] **Risk Calls section lists every `pending` item** with a recommendation
- [ ] **`progress.md` has one UIDesigner entry** for this pass
- [ ] **No screenshots or annotated images left in scratch directories** — commit them under `dev/design/assets/` or link out
- [ ] If notifications are configured, fired a `done` ping — `./scripts/notify.sh done "UI Designer: <pass scope, N stories>" --session <slug>`. No-op if notifications are off.

> **2026-08-21:** the leaf-worker definition now exists at `.claude/agents/ui-designer-worker.md` (shipped parked-with-refusal; waking the role is a file move, not authoring work).
