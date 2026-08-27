<!-- KIT-CLASS: KIT — the harness-neutral entry point. Travels unedited. -->
# AGENTS.md — for any agent that is not Claude Code

**You are in the right repository and this is not the operating manual.** Read, in this order:

1. **[`CLAUDE.md`](CLAUDE.md)** — and **check which of its two states you are in**, because they
   ask opposite things of you:
   - **It says the project has not been set up yet.** Then it is the **bootstrap stub**, this
     project is a fresh unpack, and your one job is day-one setup — follow the stub to
     [`process/SEED.md`](process/SEED.md) and stop reading this list until day one is done.
   - **It is the adapter** — this project's own law, its trunk, what counts as code, the role set,
     the commit prefixes, the gates that are never optional. Read [`PROJECT.md`](PROJECT.md)
     alongside it for the stack, the run commands and the quality bar.

   *(The stub is `REPLACE`-class scaffolding and is replaced, never edited, at the end of day one:
   [`process/EXTRACTION.md`](process/EXTRACTION.md) § The second axis: DISPOSITION.)*
2. **[`process/MANUAL.md`](process/MANUAL.md)** — the **process itself**: the board, roles as hats,
   the Dev → QA boundary and its seven steps, the session rituals, the execution discipline.
   **True in both states**, and it needs no configuring.

The filename says `CLAUDE.md` for one reason only: it is the filename the Claude Code harness reads
automatically. **Its contents are harness-neutral and bind you exactly as they bind Claude.** If
your own harness has a conventional instructions filename, point it at these two documents rather
than copying them — a copy will drift, and the copy will win arguments it should lose.

## `.claude/` is Claude-specific machinery. Its CONTRACTS are not.

The [`.claude/`](.claude/) directory holds mechanics only the Claude Code harness executes: agent
frontmatter, effort levels, workflow routes, skill and hook wiring. **Ignore the mechanics. Obey
the contracts they encode** — those are process law and apply to every agent, in every harness:

| What lives in `.claude/` | What binds you |
|---|---|
| `roles/*.md` — one doc per role | **The role set, and each role's workflow.** You wear exactly one hat at a time and you say which one. The doc for that hat is your workflow for the session; the Architect doc binds only the seated architect instance and never a subagent. |
| `templates/*.md` — issue, PRD, subtask shapes | **The shape of anything you create.** An issue you author by hand must carry the same frontmatter and sections the template does, because the board scripts and the drift report read them. |
| `agents/*.md` — leaf worker definitions | **The leaf rule:** a dispatched worker does not spawn further workers. Fan-out is the orchestrating seat's job. |
| hooks / settings wiring | **The guards those hooks automate still hold** even where your harness cannot run them — the commit-message role prefix, the declared hat, the gate before landing. A guard you cannot execute you must satisfy by hand, not skip. |

## The five things that will get you rejected

1. **A commit subject with no role tag.** Every subject starts `[Role] …` — the set is in
   [`CLAUDE.md`](CLAUDE.md) § "Role-attribution commit prefixes", and a git hook enforces it. The
   prefix is the audit trail for a one-person-many-hats project.
2. **Moving an issue file with `mv`.** The folder under `progress/` *is* the status; status changes
   go through the board mover so the move, the frontmatter and the commit stay in step.
   *(Contract: [`process/contracts/board-mover.md`](process/contracts/board-mover.md).)*
3. **Landing without the gate.** The gate command in [`PROJECT.md`](PROJECT.md) § Quality gates is
   never optional, and a green offline suite is the floor rather than a pass.
   *(Contract: [`process/contracts/landing-gate.md`](process/contracts/landing-gate.md).)*
4. **Putting non-code on a branch, or code straight on the trunk.** The code-vs-metadata split is
   in [`CLAUDE.md`](CLAUDE.md); the list of code globs there is a whitelist, and anything unnamed
   commits direct to the trunk.
5. **Recording a ruling only in an issue's Activity log.** A ruling that changes behaviour lands in
   [`requirements/DECISIONS.md`](requirements/DECISIONS.md) in the same change. An Activity line
   says what happened in one issue; the register says what is currently true.

## If a document contradicts another

The precedence is stated once, in [`requirements/CORPUS.md`](requirements/CORPUS.md) § Precedence.
Where a contract sheet in [`process/contracts/`](process/contracts/README.md) and any prose
disagree, **the sheet wins** — it states what must be true, and the prose is one implementation of
it. Do not resolve a contradiction silently: record it (`requirements/DECISIONS.md` § Findings) and
name who decides.
