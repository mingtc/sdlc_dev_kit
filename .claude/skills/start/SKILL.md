---
name: start
description: Use when a session opens in a project built on this kit and the human wants an entry point — checks the environment, looks for prior work, and either walks a fresh unpack through day one or shows what is already running and what can be done next.
---

# Start

The front door for a human, not a replacement for the kit's own authorities. This skill drives
them; it does not restate them. If anything here disagrees with `process/SEED.md`,
`process/MANUAL.md`, or `./scripts/check-board.sh`'s own output, **they win** — update this skill
rather than trusting your memory of it.

## 1. Check the environment

- **Git and a POSIX shell** are the kit's only hard requirement (`README.md` § What this is).
  Confirm both are on `PATH` (`git --version`, `echo $0` or equivalent). If either is missing, stop
  here and tell the human what to install — nothing else in this skill can run without them.
- **The two optional extras, only if the project uses them:** `brainstorming`'s visual companion
  needs Node (`node --version`); `scripts/hygiene/` needs Python 3, standard library only
  (`python3 --version`). Check for these only if the adapter (once one exists — see step 3) says
  the project actually uses them. Neither is required; say so rather than treating an absence as a
  problem.
- **Run `./scripts/check-board.sh`** if it exists at the repo root. It is the kit's own drift
  report and graduation check — read its output rather than re-deriving any of what it already
  answers. If the script is missing entirely, the kit has not been copied in yet; say so and stop.

## 2. Check for prior work

Before deciding which path to take, look for what already exists:

- Does `PROJECT.md` still read as the shipped blank (`<project name>`, `<one or two sentences>`,
  other `<angle-bracket>` placeholders), or has it been filled in?
- Does `CLAUDE.md` still carry the `BOOTSTRAP-SCAFFOLDING` line (`check-board.sh` arm `(g)` already
  checks this — read its verdict rather than grepping for it yourself)?
- Is there a board at all (`progress/todo/`, `progress/in_progress/`, etc.) with anything in it?
- Does `process/LOCAL-PROCEDURES.md` exist? Its presence is SEED step 8's closing act, and its
  absence on an otherwise-running project is itself a finding worth surfacing.

`check-board.sh`'s arm `(g)` verdict is the authority on **has day one finished** — use it to
decide which of the two paths below to take, rather than inferring it from the signals above
yourself. The signals above are for explaining the verdict to the human, not for overriding it.

## 3. Day one has not finished — walk `process/SEED.md`

Tell the human plainly: this is a fresh unpack, nothing has been configured yet, and the session's
job is day one, not features. Then:

1. Read `process/SEED.md` in full before doing anything — it is the order of operations and names
   its own authorities per step. Do not improvise the order.
2. Walk the eight steps **with** the human, conversationally, in the order SEED gives — this means
   actually having the step 3 interview (what is this project?) and the step 6 PM session (mint
   `PRD-001`) as real conversations, not placeholders you fill from a guess.
3. Do not skip ahead to "what can this project do" territory (step 4 below) until
   `check-board.sh` arm `(g)` reports graduation complete, or SEED's own "Day one is done when"
   checklist is satisfied.

This skill does not duplicate SEED's steps here. If SEED and this file ever drift, SEED is correct
and this paragraph is the bug report.

## 4. Day one is done — show status, then a menu

Give the human a short, concrete status, derived live rather than recalled:

- `./scripts/check-board.sh`'s summary — what it flags, if anything.
- What is on the board right now and in which column (`ls progress/*/`).
- The project's one-line identity, read from `PROJECT.md` § What `<project name>` is.
- Anything `check-board.sh` marks advisory-but-worth-mentioning (an open upgrade checklist, a stale
  `kit-feedback:` line, declined work sitting deep).

Then offer a menu, built from what is actually present in **this** project rather than a fixed
list — not every project ships every skill or every role:

- **Roles available** — derive from `.claude/roles/*.md` (the shipped set, plus any this project
  added or archived). Offer: "start a session as `<role>`."
- **Skills available** — derive from `.claude/skills/*/SKILL.md` frontmatter (`name` +
  `description`), the same way the harness's own skill menu would. Do not hand-list these from
  memory; the set moves as skills are added, archived, or (for the Dev set) departed from
  (`.claude/skills/README.md`'s own rule: derive, don't recall).
- **Common next actions**, if evident from the board: resume an `in_progress` item, pick up the
  next `todo`, or review something sitting in `qa_complete`.

Ask what they want to do, then hand off to the relevant role doc or skill — this skill's job ends
at the handoff; it does not perform the work itself.

## What this skill deliberately does not do

- It does not replace `process/MANUAL.md`, `process/SEED.md`, or any role doc — it routes to them.
- It does not cache or hardcode the role/skill inventory — both are derived fresh each run, because
  a project's actual set is exactly the thing most likely to have changed since this skill was
  written.
- It does not run `check-board.sh`'s mutating or write-side tooling (`kit-init.sh`,
  `archive-progress.sh`, etc.) on its own initiative — those are role actions, not front-door ones.
