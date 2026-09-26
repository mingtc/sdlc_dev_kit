<!-- KIT-CLASS: KIT — contract sheet: the role gate. See process/EXTRACTION.md. -->
# CONTRACT — the role gate

## 1. PURPOSE

To enforce the process's first rule — **confirm the hat before changing anything** — mechanically,
so that an actor cannot drift into modifying the repository without having declared which role it
is acting as.

## 2. HARD INVARIANTS

- **A declared role is a PRECONDITION of mutation, not of reading.** Investigating needs no hat;
  changing the repository does.
  *Why:* gating reads costs every session friction for no audit value, and a gate that is
  expensive gets switched off.
- **The declaration is EXPLICIT and inspectable.** It is a piece of state something else can read,
  not an intention held in the actor's context.
  *Why:* an undeclared role is unverifiable after the fact, which is the same as no role at all.
- **The declaration is per session and does NOT survive one.** A new session starts with no hat.
  *Why:* a role that outlives its session becomes a permanent global claim, and the next actor
  inherits an assertion nobody made.
- **A hat declaration is SESSION STATE, never repository content.** Whatever holds the
  declaration is excluded from version control by the initializer, not left for each actor to
  discover.
  *Why:* versioned session state forks per branch, blocks a branch switch with "local changes
  would be overwritten", and reaches a landing gate as a merge conflict over a fact nobody was
  collaborating on — measured, four actors paying for it and one conflict, in the first twelve
  hours of one adoption.
- **The act of DECLARING is always permitted.** Writing the declaration can never itself require a
  declaration.
  *Why:* otherwise the gate is a deadlock on its first use, and the only escape is disabling it.
- **The check for an existing declaration runs FIRST and unconditionally.** Before any parsing of
  the attempted action.
  *Why:* a parsing defect must never be able to lock out a session that has already complied.
- **When the target of an action cannot be determined, the gate ALLOWS.** Ambiguity is resolved in
  favour of the actor, not of the guard.
  *Why:* a guard that hard-blocks on inputs it does not understand halts all work on its own
  bugs; this rule is deliberately weaker than the ideal and is chosen with eyes open.
- **Changes outside the repository are none of its business.** Scratch space is not gated.
  *Why:* a guard that reaches beyond the repository is a guard nobody keeps enabled.
- **A block EXPLAINS how to comply, in the refusal itself.** The message names the declaration and
  how to make it.
  *Why:* a blocked actor with no instruction retries, fails, and then works around the gate.
- **The whole mechanism is OPT-IN, and the process works without it.** It hardens a rule the
  process already states in prose.
  *Why:* a process that only works with a particular harness wired in is not transferable.

## 2a. THE PRE-ROLE HAT — a SETTING, declared here with its default

Day one commits before any issue exists, and every commit subject still names a role
([`commit-attribution.md`](commit-attribution.md) § 2). Projects that meet this choose different
hats, each for a reason it can name. So the hat for that window is a **declared seam**, not a rule:

- **The default pre-role hat:** `PM`
- **The span:** every commit a seat authors on day one, up to and including the first spec
  ([`../SEED.md`](../SEED.md) steps 1–6). Three kinds of day-one commit fall outside the span:
  - the unpacked kit's first commit, made before the commit guard is wired or under the guard's
    documented escape, which carries no hat;
  - code and tests, which carry the hat that writes them;
  - the initializer's own commits (§ 6).
- **A departure — say which, and why.** A project that wears another hat records that hat, the span
  it covers, and the reason in `process/LOCAL-PROCEDURES.md` ([`../SEED.md`](../SEED.md) § Step 8's
  closing act). A project that takes the default records nothing.
- **Nothing checks that the right hat was worn** (§ 5).

**Why this default.** Day one is the PM's session before it is anyone else's. The bootstrap
`CLAUDE.md` makes the interview about what the project *is* its first act. The project sheet's first
blanks are scope decisions: what the project is, what it is not, its public surface and its build
order. The first spec closes that session. Where day one also records the stack, the gates and the
house rules, the PM hat is **transcribing the human's answers from that interview**, not making its
own call. So the PM role doc's *"does not pick libraries"* (`.claude/roles/pm.md`) still governs
the PM's own judgement, not this record.

## 3. REFUSAL CONDITIONS

- A mutation is attempted inside the repository with no declaration present ⇒ **block**, and
  return an instructive message to the actor.
- The declaration exists ⇒ allow, silently and unconditionally.
- The action's target cannot be resolved ⇒ allow (the deliberate weakening above).

## 4. WHAT GREEN MEANS

1. With a declaration present, mutations proceed and the gate is **invisible** — it emits nothing.
2. With none, an attempted mutation **does not happen**, and the actor receives a message naming
   the declaration and how to make it.
3. A fresh session begins with **no** declaration — verifiable by looking, not by remembering.

## 5. MINIMAL INTERFACE

**In:** the attempted action and its target; the presence or absence of the session's declaration.
**Out:** allow or block; on block, an instructive message. On any input it cannot interpret:
allow.
**Not in:** deciding *which* role is appropriate for the change. The gate checks that a hat was
declared, never that it was the right one.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/hooks/require-role.sh` — KIT-CLASS: KIT. The pre-mutation gate, with the
  allow-first, fail-open behaviour above.
- `scripts/hooks/session-start.sh` — KIT-CLASS: KIT. Clears the declaration at session start,
  which is what makes it per-session.
- The declaration's location is held as a named value on its own line in both hooks so a test can
  derive it rather than restate it — the single-definition rule from
  [config-seam.md](config-seam.md).
- `scripts/kit-init.sh` — KIT-CLASS: KIT. Writes the declaration's own path — the session-role
  file under the agent-harness directory — into the new repository's ignore list, which is how the
  session-state invariant in § 2 is *installed* rather than merely stated.
  **Its own commits do not read § 2a's seam.** The initializer signs its initialization and
  self-check commits with whichever role the declared set lists first. When that role is the
  pre-role hat, the two agree. When it is not, those commits carry a different hat from the one
  § 2a declares, and nothing reconciles the two.
- What the declaration's **content** looks like, and why the gate keys on existence rather than
  content, is [`../MANUAL.md`](../MANUAL.md) § Session start.
