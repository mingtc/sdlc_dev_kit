<!-- KIT-CLASS: KIT — the day-one bootstrap stub AND the harness-neutral entry point, now one
     file. Scaffolding: it is REPLACED, never edited. See process/EXTRACTION.md § The second
     axis: DISPOSITION. -->
<!-- KIT-DISPOSITION: REPLACE — the replace-me notice is the body; the BOOTSTRAP-SCAFFOLDING line
     below is the sentinel a tool reads (EXTRACTION.md § The marker and graduation). -->
<!-- BOOTSTRAP-SCAFFOLDING — a tool reads this line. It goes when this file goes. -->
# AGENTS.md — this project has not been set up yet

**This repository is a fresh unpack of a development-process kit.** It is not yet a project:
nothing here says what you are building, because nobody has said yet. **You are reading
scaffolding**, and it is the same scaffolding for every agent — Claude Code, or any other harness
that reads `AGENTS.md`. There is no separate Claude-specific bootstrap file; this is the one file.

## Your one job this session is day-one setup

Not features, and not a plan for features. **If you are a human opening this project, the quickest
way in is `/start`** — it checks the environment, looks for prior work, and walks this exact
sequence with you. What follows is what `/start` runs; read it either way, in this order:

1. **Read [`process/SEED.md`](process/SEED.md).** It is the order of operations, and each step
   names the authority that actually governs it. Do not improvise the order — the sequence exists
   because each step out of place fails **later and in disguise**.
2. **Interview the human about what this project IS before writing anything into it** — the
   conversation SEED step 6 turns into `PRD-001`. This is the step most likely to be skipped under pressure to look
   productive, and a repository configured before anyone has said what it is for gets configured
   wrong in ways that are expensive to unwind.
3. **At `process/SEED.md` step 5, REPLACE THIS FILE** with the adapter you build from
   [`process/templates/AGENTS-adapter.template.md`](process/templates/AGENTS-adapter.template.md).

## Replace this file. Do not edit it into shape

**This file is `REPLACE`-class** — scaffolding to be thrown away and rewritten, not a draft to be
corrected: a plausible stub gets edited, and the project never decides its own law
([`process/EXTRACTION.md`](process/EXTRACTION.md) § The second axis: DISPOSITION).

**Build the adapter from the template in one pass, from the conversation that decides this
project's law.** If you find yourself writing it with nothing decided, that is the signal to go and
have the conversation — not to invent the law and move on. `process/SEED.md` § Day one is done when
is the checklist that says you are finished. **Once day one is done, this file holds the adapter**
— this project's own law, its trunk, what counts as code, the role set, the commit prefixes, the
gates that are never optional. Read [`PROJECT.md`](PROJECT.md) alongside it for the stack, the run
commands and the quality bar.

## What already binds you, before any of that

[`process/MANUAL.md`](process/MANUAL.md) is **the process itself** and is already true — it needs no
configuring and you do not rewrite it. Read it once. It is the board, roles worn as hats, the
Dev → QA boundary, and the session rituals. Everything the manual deliberately does not know — the
trunk, what counts as code here, the role set, which gates bind — is what the adapter you are about
to write will supply; the gate commands go in [`PROJECT.md`](PROJECT.md). **True whether you are the
bootstrap stub or the adapter**, and it needs no configuring either way.

## `.claude/` is Claude-specific machinery. Its CONTRACTS are not.

The [`.claude/`](.claude/) directory holds mechanics only the Claude Code harness executes: agent
frontmatter, effort levels, workflow routes, skill and hook wiring. **Ignore the mechanics. Obey
the contracts they encode** — those are process law and apply to every agent, in every harness:

| What lives in `.claude/` | What binds you |
|---|---|
| `roles/*.md` — one doc per role | **The role set, and each role's workflow.** You wear exactly one hat at a time and you say which one. The doc for that hat is your workflow for the session; the Architect doc binds only the seated architect instance and never a subagent. |
| `templates/*.md` — the shape of every issue type, PRD and subtask | **The shape of anything you create.** An issue you author by hand must carry the same frontmatter and sections the template does, because the board scripts and the drift report read them. |
| `agents/*.md` — leaf worker definitions | **The leaf rule:** a dispatched worker does not spawn further workers. Fan-out is the orchestrating seat's job. |
| `skills/*/SKILL.md` — named procedures | **The ones the manual names are steps you owe.** Read the `SKILL.md` and do it by hand. **If your own harness natively discovers skills by the open [Agent Skills](https://agentskills.io) format** (a folder with `SKILL.md`, as Codex CLI and Gemini CLI do from `.agents/skills/`) — **this kit does not duplicate them there; look in `.claude/skills/` directly.** Claude Code itself only scans `.claude/`, which is why the real files live there rather than at a shared path. |
| hooks / settings wiring | **The guards this wiring automates still hold** even where your harness cannot run them — the commit-message role prefix (a git hook) and the declared hat (a session hook). The gate before landing is the odd one out: no hook runs it, `finish-pr.sh` does when the landing seat (QA) invokes it — which is precisely why it is the easiest of the three to skip and the one worth naming here. A guard you cannot execute you must satisfy by hand, not skip. |

## What will get you rejected

1. **A commit subject with no role tag.** Every subject starts `[Role] …` — the set is in the
   adapter's § "Role-attribution commit prefixes" (until it exists: the hook's `ROLE_PREFIXES` line in
   `scripts/githooks/commit-msg`, and
   [`process/contracts/role-gate.md`](process/contracts/role-gate.md) § 2a for day one's hat), and a
   git hook enforces it. The prefix is the audit trail for a one-person-many-hats project.
2. **Moving an issue file with `mv`.** The folder under `progress/` *is* the status; status changes
   go through the board mover so the move, the frontmatter and the commit stay in step.
   *(Contract: [`process/contracts/board-mover.md`](process/contracts/board-mover.md).)*
3. **Landing without the gate.** The gate command in [`PROJECT.md`](PROJECT.md) § Quality gates is
   never optional, and a green offline suite is the floor rather than a pass.
   *(Contract: [`process/contracts/landing-gate.md`](process/contracts/landing-gate.md).)*
4. **Putting metadata changed ON ITS OWN onto a branch, or code straight on the trunk.** The
   adapter's list of code globs is a whitelist, and anything unnamed commits direct to the trunk.
   **AND THE CARVE-OUT MATTERS MORE THAN THE RULE, because reading the rule as a prohibition is the
   MEASURED failure:** metadata MAY ride its code branch when it is part of the same change. A
   register entry, a matrix row, a doc correction the code change *makes true* belongs in the commit
   that makes it true — splitting it onto the trunk publishes a claim about code that has not landed.
   The direct-to-trunk rule governs metadata changed **on its own**
   ([`process/MANUAL.md`](process/MANUAL.md) § The code-vs-metadata rule).
5. **Recording a ruling only in an issue's Activity log.** A ruling that changes behaviour lands in
   [`requirements/DECISIONS.md`](requirements/DECISIONS.md) in the same change. An Activity line
   says what happened in one issue; the register says what is currently true.

## If a document contradicts another

Your project states its own precedence in [`requirements/CORPUS.md`](requirements/CORPUS.md)
§ Precedence, which ships as a blank for you to fill. One precedence rule is the KIT's and binds
before you fill anything: where a contract sheet and any prose disagree, **the sheet wins**
([`process/MANUAL.md`](process/MANUAL.md) § The three documents). Do not resolve a contradiction
silently: record it (`requirements/DECISIONS.md` § Findings) and name who decides. A contradiction
inside the kit itself is resolved in `process/LOCAL-PROCEDURES.md`
([`process/MANUAL.md`](process/MANUAL.md) § Kit feedback).
