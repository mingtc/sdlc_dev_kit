<!-- KIT-CLASS: KIT — the seed's front door. Scaffolding: REPLACE-class, like CLAUDE.md.
     See process/EXTRACTION.md § The second axis: DISPOSITION. -->
<!-- BOOTSTRAP-SCAFFOLDING — a tool reads this line. It goes when this file goes. -->
# The development-process kit — a seed

> **This file is a placeholder for yours.** Replace it with **your project's** README once you are
> running; move these instructions to `process/SEED.md`'s companion notes if you want to keep them.
>
> *Why this sentence is here in the body and not in the comment above it:* the comment is the
> **classification marker**, and the marker is removed from files that become the project's — which
> is every REPLACE-class file, of which this is one. While the instruction lived inside the marker,
> stripping the marker stripped the instruction, and the one file whose replace-me notice is not in
> a fill-in stub would have lost it silently at exactly the moment it was meant to be read.

**What this is.** A generic, language-agnostic **development-process kit**: a
filesystem-as-kanban board (the folder a file sits in *is* its status), **roles as hats** (one
worker wears one role at a time, from a doc that is its workflow), a hard **Dev → QA boundary**
with a landing gate, a set of **contract sheets** that say what each gate must guarantee, a set of
**doctrine sheets** that carry the reasoning behind the rules, and **launch-pack orchestration**
for running a batch of work with minimal human relay. It assumes **git and a POSIX shell** — no
language, no test framework, no hosted forge. *(Two optional extras are carved out where they live
and are deletable without loss: the hygiene instruments under `scripts/hygiene/` are Python 3,
standard-library only and never a gate; `brainstorming`'s visual companion wants Node and is opt-in
per question.)* The primary agent harness is
**Claude Code**, and the `.claude/` machinery here is Claude-specific on purpose; the *contracts*
those files encode (the roles, the commit prefixes, the board rules) bind every agent regardless of
harness — see [`AGENTS.md`](AGENTS.md).

**What this is not.** It is not a template for an application, and it holds no product code. It is
the process a project runs *on*.

---

## Day one

**The copy is already done** — you are looking at the kit, in place. What is left is to *stamp* it
with your project's values and to prove it works.

```sh
# 1. Prerequisites the initializer will not do for you (it guides, it never bootstraps):
git init -b main                                 # -b NAMES the trunk — see the note below
git add -A && MSG_OK=1 git commit -m 'init'      # the first commit
git remote add origin <url-or-path-to-a-bare-repo>
git push -u origin main
git remote set-head origin main                  # ← the step whose absence is SILENT

# 2. Stamp the kit: the issue prefix, the trunk, and your gate runner.
./scripts/kit-init.sh --prefix XYZ --trunk main --gate-command '<your test command>'
./scripts/kit-init.sh --help                     # every option, and the preconditions
```

**Why `-b`, and not `git init` followed by `git switch -c`.** A bare `git init` puts HEAD on whatever
`init.defaultBranch` says, which is still `master` on any machine whose git predates the default
change or whose user never set it. The commit then lands on `master`, and a later `git switch -c main`
creates `main` **from** it — leaving two branches at one commit and a `master` nobody asked for. The
switch line also used to carry the condition *"if your trunk does not exist yet"*, which is false at
the moment it is read: after the commit the branch demonstrably **does** exist, so a careful reader
skips the line, proceeds with trunk = `master`, passes `--trunk main` to the initializer, and is
refused several steps later by a check that does not name this as the cause. `-b` removes the
sequence. *(`-b` needs git 2.28 or newer, released 2020. On older git,
`git symbolic-ref HEAD refs/heads/main` immediately after `git init` does the same thing everywhere.)*

`--prefix XYZ` makes your issue files `XYZ-001-<slug>.md`; until you stamp it, `scripts/config.sh`
carries a neutral placeholder and the documents here say `<PREFIX>`. `--trunk` is **required and
confirmed, never inferred** — if it disagrees with `origin/HEAD`, the initializer refuses rather
than letting the scripts pick. `--gate-command` declares your first gate: the seed ships
`scripts/verify.sh` as a frame whose gate table is **empty and refuses to run**, and the flag
writes your command into that table as its first record. Drop the flag only if you have already
declared your gates in that table by hand — never skip both: **the landing gate refuses to land a
branch without an executable, committed gate runner, and an empty frame refuses to run.**

The initializer **refuses, and writes nothing, on any repository that has already lived** — a board
carrying issue files, a `progress.md` § Log with entries, an `ARCHIVE.md` with an index, or a
`scripts/config.sh` a previous run already stamped. There is no resume path: a half-stamped
repository is worse than an unstamped one.

Then, in order: fill [`PROJECT.md`](PROJECT.md), fill [`CLAUDE.md`](CLAUDE.md), start
[`requirements/CORPUS.md`](requirements/CORPUS.md) and
[`requirements/DECISIONS.md`](requirements/DECISIONS.md), wire the runtime half of
[`setup.sh`](setup.sh), and drive your **first** issue through the **full** Dev → QA boundary.
[`process/SEED.md`](process/SEED.md) is the eight-step order of operations, and every step there
names the authority that actually holds the law.

## Reading order

| # | Read | Why |
|---|---|---|
| 1 | **This file** | What the kit is, and how to stamp it. |
| 2 | [`process/SEED.md`](process/SEED.md) **or** [`process/EXTRACTION.md`](process/EXTRACTION.md) | **SEED** is the *you-have-nothing* path: an empty directory and a sentence. **EXTRACTION** is the *donor-extraction* path: you have a working repository in front of you and want to know what to copy. Both end in the same place. |
| 3 | [`process/MANUAL.md`](process/MANUAL.md) | **The operating manual** — roles, the board, the Dev → QA boundary, the rituals, the execution discipline. Read once, in full. Adopt unedited. |
| 4 | [`CLAUDE.md`](CLAUDE.md) | **On day one, the bootstrap stub** — it says the project is not set up yet and sends you to [`process/SEED.md`](process/SEED.md). **You replace it** at the end of day one with **the adapter** — this project's own law, and the values the manual deliberately does not know — built from [`process/templates/CLAUDE-adapter.template.md`](process/templates/CLAUDE-adapter.template.md). From then on, read it every session alongside [`PROJECT.md`](PROJECT.md). |

Then, as needed: [`process/contracts/README.md`](process/contracts/README.md) (one sheet per gate —
what must be TRUE, independent of how you implement it), [`process/doctrine/`](process/doctrine/)
(the reasoning behind the standing rules), [`process/templates/`](process/templates/) (the blank
shapes), and [`process/hygiene-checklist.md`](process/hygiene-checklist.md) (the shapes a hygiene
pass looks for, and the instruments that look).

## The board, in one screen

```
progress/todo/          # minted, not started
progress/in_progress/   # someone is wearing a hat over it right now
progress/dev_complete/  # Dev is done; QA has not looked
progress/qa_complete/   # QA passed and landed it
progress/blocked/       # parked, with the blocker written down
progress/done/          # the archive shelf — full bodies, swept off the active board
progress/history/       # rotated slices of progress.md
```

The **folder is the status**; there is no status field to disagree with it. Status changes go
through the board mover (`./scripts/move-issue.sh`), never through `mv` —
[`process/contracts/board-mover.md`](process/contracts/board-mover.md) says why.
`./scripts/check-board.sh` reports drift. [`progress.md`](progress.md) is the running history;
[`ARCHIVE.md`](ARCHIVE.md) is the one-line index of everything swept.

## Git hosting — local-only is a first-class case

**You do not need a hosted forge.** The kit needs an `origin` it can fetch, reset and push through,
and **a bare repository on your own disk is a perfectly good one**:

```sh
1.  git init --bare /path/to/<project>.git
    git remote add origin /path/to/<project>.git    # ABSOLUTE path
2.  git switch -c <trunk>                           # if the trunk does not exist yet
    MSG_OK=1 git commit --allow-empty -m 'init'     # if there are no commits yet
3.  git push -u origin <trunk>
4.  git remote set-head origin <trunk>              # ← the step whose absence is SILENT
```

That four-step recipe is exactly what `./scripts/kit-init.sh` prints when it refuses for an unmet
remote precondition — the offline case is in the refusal message, not an afterthought. The
`set-head` step is the one whose absence is silent: without it the trunk is defaulted by the
worktree library and your first board move pushes to a branch nobody chose.

**GitHub (or any forge) is an OPTIONAL extra**, and everything specific to one lives in
[`process/GIT-HOSTING.md`](process/GIT-HOSTING.md) — read it only if you want a forge. The landing
gate is pure git: it does not call a forge CLI, so nothing in the core path breaks without one.

## Where the working records go

- [`dev/`](dev/) — dated working notes, assessments, and **handoffs**; every file indexed in
  [`dev/README.md`](dev/README.md). No file in `dev/` is a living plan except the newest handoff.
  It also holds the directories the process writes into by name — `specs/`, `plans/`, `refactor/`,
  `design/`, `runs/` — so a role doc's stated output path lands somewhere that exists.
- [`docs/`](docs/) — reference material **this project did not write**: a vendor's API guide, a spec
  somebody else owns, an artifact produced to leave the project. Not the working records of building
  — those are `dev/`'s, and [`docs/README.md`](docs/README.md) states the test that tells them apart.
- [`requirements/`](requirements/) — PRDs plus the two registers: the corpus manifest and the
  standing-rulings register.
- [`.claude/`](.claude/) — the Claude Code harness: role docs, issue/PRD templates, agent
  definitions.
- [`scripts/`](scripts/) — the board mover, the id minter, the drift report, the landing gate, the
  initializer, the archive sweeps, and the process self-test.
- [`consumers/`](consumers/) — present only if this project ships something someone else installs;
  the doctrine is [`process/doctrine/distribution.md`](process/doctrine/distribution.md).

## Which version of the kit is this, and what changed

- **[`process/KIT-VERSION`](process/KIT-VERSION)** — one line, the version of the process kit this
  tree was cut from. It is **not** your product's version: yours is whatever
  [`scripts/release.sh`](scripts/release.sh)'s `VERSION_FILES` seam declares, and the two must
  never be the same file.
- **[`process/KIT-RELEASE-NOTES.md`](process/KIT-RELEASE-NOTES.md)** — what changed in the kit,
  release by release, and **what an adopted project has to do about it**. Upgrading is a read and
  a set of deliberate edits, never an overwrite: the kit became yours the day you stamped it.

## Conventions used throughout

- **`<angle brackets>` are blanks you fill.** `<PREFIX>` is your issue prefix, `<trunk>` your trunk
  branch (default `main`), `<project name>` your project's name.
- **`KIT-CLASS:` markers** at the top of a file say whether it travels to another project:
  **KIT** (travels as-is or as a blank shape), **PROJECT** (yours alone), **MIXED** (a kit
  mechanism with a project-shaped section inside it). Re-mark a file honestly when you change what
  it is. When a file becomes wholly yours its class becomes `PROJECT` and the marker comes off with
  it — that is graduation, and the rule for it is in
  [`process/EXTRACTION.md`](process/EXTRACTION.md) § The second axis: DISPOSITION.
- **Disposition — what state a file must be in before day one is done.** A second axis, answering
  the question the class does not: **KEEP** · **STAMP** · **FILL** · **REPLACE** · **SEED** ·
  **DELETE-IF-UNUSED**. It matters most for **REPLACE**: this `README.md` and the shipped
  `CLAUDE.md` are **scaffolding to be thrown away and rewritten**, not files to be edited into
  shape. The axis, its members and what discharges each one are in
  [`process/EXTRACTION.md`](process/EXTRACTION.md) § The second axis: DISPOSITION.
- **Pattern vs instance.** A doctrine sheet's *pattern* section is law and travels verbatim; its
  *instance* section is one project's evidence and travels only as an illustration. When you drop
  an instance, **keep the pattern and keep the why** — that is the supersession law
  ([`process/doctrine/supersession.md`](process/doctrine/supersession.md)), and it applies to this
  kit's own documents as much as to your project's.
