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
- **The declaration is made BEFORE the first change, by whatever tool makes it.** An editor tool, a
  shell command, a script and a commit are all changes; the actor writes the declaration first
  whether or not any hook is wired, and the hooks only enforce what the actor was already told.
  *Why:* a rule that names the declaration only to a reader who has found the optional hook is a
  rule most sessions do not meet until after they have changed something.
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
- **The COMMIT is gated as well as the editor tools.** A change made through a shell — a
  redirect, `sed -i`, a script — passes no editor tool, and every change must pass a commit to
  count, so the commit is refused while no hat is declared. An actor may be refused at the commit
  for a change it made hatless earlier; the refusal names the declaration, and the change is
  untouched.
  *Why:* a gate on three tools is a property of those tools, not of the repository.
  *Limit, stated rather than implied:* a change left uncommitted is not seen, and a commit made
  under the git hooks' documented escape is not refused. The commit gate bounds what lands; it
  does not record who changed what.
- **No harness matcher is added for shell commands.** A matcher cannot tell a command that
  changes the repository from one that reads it (`sed -i`, a redirect, `tee`, a script that
  writes, against `ls` and `git status`), so any rule it applied would cover some forms and read
  as covering all, or would refuse the reads the first invariant exempts.
  *Why:* a partial gate that reads as complete is worse than the exact one at the commit.
- **The editor-tool gate is OPT-IN, and the process works without it.** It hardens a rule the
  process already states in prose.
  *Why:* a process that only works with a particular harness wired in is not transferable.

## 2a. THE PRE-ROLE HAT — a SETTING, declared here with its default

Day one commits before any issue exists, and every commit subject still names a role
([`commit-attribution.md`](commit-attribution.md) § 2). Projects that meet this choose different
hats, each for a reason it can name. So the hat for that window is a **declared seam**, not a rule:

- **The default pre-role hat:** `PM`
- **The span:** every commit a seat authors on day one, up to and including the first spec
  ([`../SEED.md`](../SEED.md) steps 1–6). Two kinds of day-one commit fall outside the span:
  - the unpacked kit's first commit, made before the commit guard is wired or under the guard's
    documented escape, which carries no hat;
  - code and tests, which carry the hat that writes them.

  **The initializer's own commits are inside it**: it signs them with this hat (§ 6).
- **A departure — say which, and why.** A project that wears another hat records that hat, the span
  it covers, and the reason in `process/LOCAL-PROCEDURES.md` ([`../SEED.md`](../SEED.md) § Step 8's
  closing act). A project that takes the default records nothing.
- **Nothing checks that the right hat was worn** (§ 5).

**Why this default.** Day one is the PM's session before it is anyone else's. The bootstrap
`AGENTS.md` makes the interview about what the project *is* its first act. The project sheet's first
blanks are scope decisions: what the project is, what it is not, its public surface and its build
order. The first spec closes that session. Where day one also records the stack, the gates and the
house rules, the PM hat is **transcribing the human's answers from that interview**, not making its
own call. So the PM role doc's *"does not pick libraries"* (`.claude/roles/pm.md`) still governs
the PM's own judgement, not this record.

## 3. REFUSAL CONDITIONS

- A mutation is attempted inside the repository with no declaration present ⇒ **block**, and
  return an instructive message to the actor.
- A commit is attempted with no declaration present, and none made for that one commit by the
  script committing ⇒ **block**, naming the declaration and its form.
- The declaration exists ⇒ allow, silently and unconditionally.
- The action's target cannot be resolved ⇒ allow (the deliberate weakening above).

## 4. WHAT GREEN MEANS

1. With a declaration present, mutations proceed and the gate is **invisible** — it emits nothing.
2. With none, an attempted mutation **does not happen**, and the actor receives a message naming
   the declaration and how to make it. A commit with none **does not happen**, and the change stays
   as it was.
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
- `scripts/githooks/pre-commit` — KIT-CLASS: KIT. The commit gate: it refuses a commit while the
  declaration is absent from this checkout and from the repository's main checkout (so a linked
  worktree of the same session is covered), with a `Next:` line naming the file and its form.
  **A committer that runs with no hat file is decided by a rule, never by a bypass.** A script that commits on its own account and names its role in the subject —
  the initializer, the release script — declares that role for the one commit through
  `KIT_HAT_ENV` (`scripts/lib/hat-file.sh`), which the hook reads beside the file and which
  leaves nothing behind. A commit made in the standing kanban worktree is exempt: that checkout is
  detached and linked, holds no session, and every board script that commits there names a role,
  checked against the declared role set, in the subject the commit-msg hook holds. Every other
  committer — a session's own checkout, detached or not — declares the file.
- `scripts/hooks/session-start.sh` — KIT-CLASS: KIT. Clears the declaration at session start,
  which is what makes it per-session.
- `scripts/lib/hat-file.sh` — KIT-CLASS: KIT. The declaration's location, `KIT_HAT_FILE_REL`, defined
  once and read by both hooks, the commit gate and the initializer so a test can derive it rather than restate it —
  the single-definition rule from [config-seam.md](config-seam.md). It lies outside `.claude/`
  because the harness refuses a session's write there in every permission mode but bypass, and an
  unattended session could then never declare a hat. With the lib unreadable the gate blocks.
- `scripts/kit-init.sh` — KIT-CLASS: KIT. Writes the declaration's own path — `KIT_HAT_FILE_REL` — into the new repository's ignore list, which is how the
  session-state invariant in § 2 is *installed* rather than merely stated.
  **Its own commits wear § 2a's hat.** The initializer signs its initialization and self-check
  commits with the pre-role hat — § 2a's default, or the hat named by its `KIT_INIT_ROLE` knob —
  declares that hat to the commit gate for each of them, and
  refuses, before writing anything, when that hat is not in the role set it will leave in force,
  naming the knob. A project that departs from § 2a's default sets the knob to the same hat it
  records.
  *Why:* a tag chosen by position in the role set records a seat nobody sat in.
- What the declaration's **content** looks like, and why the gate keys on existence rather than
  content, is [`../MANUAL.md`](../MANUAL.md) § Session start.
