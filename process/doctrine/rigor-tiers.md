<!-- KIT-CLASS: KIT — the rigor-tier ladder: ceremony weight AND provisioning follow the issue's tier. -->
# Rigor tiers — calibrate ceremony and provisioning to the change, not the habit

**Promoted from the orchestrator role doc at the PM's word (2026-08-21)** — the ladder is
process law that binds every dispatching role, not one role's private heuristic; the role doc
now points here. The pattern is § A; there is deliberately no § B instance — the tiers are
defined by *change shape*, which is project-independent.

## A. The ladder

Place every issue on this ladder **at run-plan time** (state the tier per issue in the
proposal) and run it at that weight. The full lifecycle (brainstorm → plan → worktree →
subagent-TDD → code-review → verify → fresh-eyes QA → binding gate → merge) is right for a
schema/API/logic feature and visible over-process for a one-word relabel.

| Tier | What it covers | Planning | Dev | QA | Binding extra gate |
| --- | --- | --- | --- | --- | --- |
| **TIER 1** | Copy/comment/docstring, config tweak, test-only change — **no behavior change** | Skip brainstorming + writing-plans | Single inline implementer (no subagent fan-out) | Single-vote QA against the AC | **Skip** unless it changes public/serialized output |
| **TIER 2** | Internal logic / behavior — **no public-signature change** | Full chain | Full chain | Full fresh-eyes QA | **Required** if it changes observable output |
| **TIER 3** | Schema / public API / the project's declared risk surface | Full chain | Full chain | Full fresh-eyes QA **+ adversarial verification** of findings | **Required** |

**A tier implies a provisioning, not only a ceremony weight**
([`model-provisioning.md`](model-provisioning.md) carries the mechanism):

| Tier | Dev worker | QA worker |
| --- | --- | --- |
| **TIER 1** | The ladder's default; **the cheaper model** for XS / mechanical work | The ladder's default; **the cheaper model** for XS / mechanical work |
| **TIER 2** | The ladder's default | The ladder's default (one step up if the change is `Major`) |
| **TIER 3** | One step up — **this tier is what justifies it** | One step up |

The top effort tier is not any tier's default: it is a **beast-class** escalation and needs
**PM sign-off**, on TIER 3 as much as anywhere. The lowest effort tier is never used, the
maximum never, and every worker dispatched at any tier is a **leaf** (no sub-spawning).

**The binding-gate decision rule.** Run the project's declared binding extra gate (the
adapter's § Project duties) **iff the change is on a declared risk surface** — it alters
observable behavior, a public signature, or serialized output. A pure logic/helper/test edit
that leaves the public output byte-identical does not need it; anything that changes what the
project emits does. **When in doubt, run it.**

**Why tiers instead of judgment-per-issue:** heavy fan-outs accelerate token (and quota) burn
— they hit limits faster, they don't dodge them. A written ladder is how a fleet's ceremony
cost stops drifting toward "whatever the last session did", which is the same argument the
provisioning doctrine makes for models: a table someone ratified beats a habit nobody chose.
Do not run a TIER-3 ceremony on a TIER-1 change — and do not let a TIER-3 change sneak
through at TIER-1 weight because it was described in TIER-1 words; the tier follows the
CHANGE SHAPE, which the run plan states so the human can veto the placement.
