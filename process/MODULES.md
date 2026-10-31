<!-- KIT-CLASS: KIT — what an optional module is, how a project enables and disables one, and how to write one. See EXTRACTION.md. -->
# MODULES.md — optional modules

A **module** is an optional overlay the kit ships and a project may switch on. It ships **in the zip,
disarmed**: everything is under `modules/<name>/`, with every name a harness reads stored the way the core
stores them (`_claude/`, not `.claude/`), so a module that is off is read by nothing and costs no tokens.
`scripts/module.sh enable <name>` puts it in place; `disable` takes it back. The contract is
[`contracts/module-lifecycle.md`](contracts/module-lifecycle.md); `modules/README.md` indexes what ships.

**Why a module and not core:** the core requires git and a POSIX shell and nothing else. Whatever needs more,
or that some projects want and others would find in the way, is a module: the project decides, and nothing
loads until it does.

## The catalogue

What the kit ships, enabled or not; nothing here is read by a harness. The words in a row are the manifest's (its `purpose`, and the ids of its requirements or `declares nothing`), and
`./scripts/module.sh list` prints them from the manifests. A project that deleted a module's directory may keep its row.

| Module | What it enables | What it needs |
|---|---|---|
| `example` | A toy module to read and copy; enable it to see what a module does, then disable it. | git (required), awk (optional), example-account (agent check) |
| `design` | Evergreen screen designs beside the PRDs: the rules for where they live and how a story and a card cite them, and a Designer role to keep them true. | python3 (required) |

**Asked for something a disabled module provides, an agent says which module does it, what it needs, and offers to
enable it. It never enables one on its own:** enabling is the person's yes, recorded as a register entry the way the
consent for the Claude Code hooks is.

## Using a module

```sh
./scripts/module.sh list                 # what this kit ships, what each needs, and what is enabled
./scripts/module.sh enable <name>        # place it, register it, record it
./scripts/module.sh status [<name>]      # each placed thing: intact, edited, missing or (no sha256 tool) unjudged; each requirement: holding or not
./scripts/module.sh disable <name>       # take back what enable wrote
./scripts/kit-init.sh --prefix <P> --trunk <T> --with <name>   # on day one: enabled inside the initialization commit
```

**Enable** copies the module's files into place (re-arming names: `_claude/` becomes `.claude/`), puts in the
project's own prefix, trunk and name for the placeholders `<PREFIX>`, `<trunk>` and `<project name>`, registers
the module with the extension points below, and records the module and the sha256 of every file and block it
wrote in **`process/MODULES`** — tracked, created by the first enable, deleted by the last disable. It refuses,
naming every path and writing nothing, when:

- **a required command the module declares is not there** (`requires:`, under Writing a module). An optional one only warns,
  naming what is lost;
- a path is not the module's to take: a file that exists (whatever it holds: enable takes no file it did not
  write), a file the kit itself ships, a block whose host has no slot, no final newline or a stray marker;
- **the project's copy of the kit does not read a point the module uses** (a project that took an older kit
  and then enabled a module would get a check that is placed and never run). The refusal names the file to
  merge from the release; merge it, then enable again.

**On day one,** `kit-init.sh --with <name>[,<name>]` enables the module after it has stamped the project and before
it commits, so the module's files and `process/MODULES` are in the initialization commit. Its preflight asks every
question enable asks, plus whether git would add what enable places, and refuses with nothing written when any
fails: `kit-init.sh` has no resume path, so an enable that refused after the stamp would leave a half-initialized
repository.

**After the files land,** enable prints the module's `SETUP.md` (the steps no script can do), the line that runs its
`setup.sh` when it has one, and the agent checks it declares. **Nothing in the kit runs `setup.sh`:** a person does, or an
agent on the person's yes. `status` runs the module's checks again, so a requirement that has stopped holding is named.

**After a kill.** Enable records the module as `pending`, one row ahead of each path it writes, and writes each
file beside its target and moves it in. Run `enable` again to finish it, or `disable` to take it back; both
trust only the rows that record names. Nothing has to be deleted by hand.

**Enable fills the project's prefix, trunk and name into a module's files, so it asks for a project that has
been through `scripts/kit-init.sh`** and refuses one that has not, when a file of the module carries those
blanks. **Disable** first checks that every shared file it must rewrite can be, and refuses with nothing removed
when one cannot (a file with no final newline). It then removes each file and block still byte-equal to what
enable wrote and **reports, never deletes,** one you edited; it is yours from then on, and a kept role layer,
arm or block stays in force until you delete it. **A role layer also stays while commits on this branch or the
trunk carry its role**: `check-board.sh` judges every trunk commit against today's role set, so the role leaving
it would be reported as drift on history. Disable says so and how to retire the role on purpose. What it kept stays recorded under `kept <name>` in `process/MODULES`, which `status` and `list` show and a
re-enable names. Both commands are idempotent. Neither commits: each prints the paths to commit.
**Push the enabling commit before expecting the trunk-read points to act**: `check-board.sh`'s role arm, the
move checks, the cell checks and the evidence-kind list read the trunk. `process/MODULES` is the record, not a
setting: edit nothing in it by hand.

**Upgrading.** `kit-upgrade.sh` refreshes the disarmed `modules/` like any shipped file, and carries each **enabled**
module's new version into the files it placed by the rules of [`contracts/module-lifecycle.md`](contracts/module-lifecycle.md)
§ 2: a file you edited is never overwritten, and the module's copy of it is staged under `.kit-upgrade/modules/<name>/`
beside a merge item on the checklist. What else the checklist carries for a module is listed in
[`contracts/kit-upgrade.md`](contracts/kit-upgrade.md) § 2. A killed upgrade is finished by running it again. A disabled
module has only its disarmed copy refreshed; take its new version by enabling it.

## The extension points

A module adds to the kit only through these; none edits core code, and none names a module. **This table is the
one list of them**; each point's contract is stated once, in the sheet it cites.

| Manifest key | A module adds | Where it lands | Read by, and the contract |
|---|---|---|---|
| `role: <Tag> [text]` | a role to the set | `process/roles.d/<name>` | `scripts/lib/role-set.sh`, so the commit-msg hook, the board scripts and `check-board.sh` agree; [`EXTRACTION.md`](EXTRACTION.md) § 2.4 |
| `arm: <source> -> NN-<name>.sh` | a drift-report arm; it declares itself `advisory` or `deciding` | `scripts/check-board.d/NN-<name>.sh` | `check-board.sh`; [`contracts/drift-report.md`](contracts/drift-report.md) § 5 |
| `evidence-kind: <kind> [text]` | a QA evidence kind, pointer-only | `process/evidence-kinds.d/<name>` | `kit_qa_evidence_kinds`, on the trunk; [`contracts/landing-gate.md`](contracts/landing-gate.md) § 3 |
| `qa-cell: <source> -> <kind>/NN-<name>.sh` | a check on each PASS row of that kind | `scripts/qa-cell.d/<kind>/NN-<name>.sh` | the QA gate, from the trunk; [`contracts/landing-gate.md`](contracts/landing-gate.md) § 3 |
| `move-check: <source> -> <status folder>/NN-<name>.sh` | a check before a card moves to that folder | `scripts/move-check.d/<status folder>/NN-<name>.sh` | the board mover, the landing script, `subtask.sh` and the archive sweep, from the trunk; [`contracts/board-mover.md`](contracts/board-mover.md) § 3 |
| `fragment: <PRD\|ISSUE> <mode> <source>` | text minted into every new PRD or card; `<mode>` is `frontmatter`, `body-end` or `slot-<slot>` | `process/fragments.d/<template>/<name>.<mode>` | `new-prd.sh` and `new-issue.sh`; [`contracts/issue-creation.md`](contracts/issue-creation.md) § 3 |
| `release-notes: <source>` | the module's own release notes, in the kit's notes shape (`## [X.Y.Z]` sections, entries under `### Action required`) | stays in `modules/<name>/` | `kit-upgrade.sh`, only while the module is enabled; [`contracts/kit-upgrade.md`](contracts/kit-upgrade.md) |
| `block: <file> <slot> <source>` | the module's own table, in a shared file | between `KIT-MODULE:<name>:<slot>` markers, before the file's `KIT-MODULES:<slot>` line | `scripts/lib/marker-block.sh` |
| `gitignore: <source>` | ignore lines | a block at the end of `.gitignore` (the file is created when absent, and deleted again by the disable that leaves it empty) | `scripts/lib/marker-block.sh` |
| `file: <source> -> <target>` | any file | anywhere that is not a core file, `process/MODULES`, `modules/` or `.git/` | placeholders as above |

A block is **its own table** (header, separator, rows), never rows spliced into the core's, so a renderer and
the gate recipe still read both. A `fragment` fills a slot the core template owns, or adds to the frontmatter or
the end; a project that enables nothing sees no trace of it. A module has at most one fragment for each
template and mode, and the name in `<name>.<mode>` is the module's.

## Writing a module

Layout, in the kit source (`kit/modules/<name>/`; the zip carries it unchanged):

```
modules/<name>/module.manifest
modules/<name>/SETUP.md              # the steps a person does by hand; enable prints it
modules/<name>/setup.sh              # optional: the part a script can do; the kit never runs it
modules/<name>/RELEASE-NOTES.md      # optional: the `release-notes` key; read by kit-upgrade.sh while enabled
modules/<name>/_claude/…             # anything that lands under .claude/, disarmed
modules/<name>/test/cases/*.sh       # the module's own self-test cases
modules/<name>/test/CASE-LIST        # the case functions that file defines, one per line
modules/<name>/…                     # everything else, at any path the manifest names
```

**The manifest** is `<key>: <value>` lines; `#` lines and blanks are ignored. A line `scripts/module.sh` does not
know refuses the manifest.

| Key | Takes | Required |
|---|---|---|
| `name` | the directory's name: lowercase letters, digits, `-` | yes |
| `version` | `X.Y.Z` | yes |
| `purpose` | one line | yes |
| `requires` | `<id> \| <shell check> \| <how to get it> \| required`, or `… \| optional: <what is lost>` | no |
| `requires-agent` | `<id> \| <the call> \| <what a pass looks like> \| <how to get it>` | no |
| the keys of the table above | as that table says; repeat a key for more | no |

**What a module needs.** A `requires:` line is a command the shell can run and a way to get what it finds absent.
The fields are split at ` | `, and the check is whatever lies between the id and the last two fields, so it may hold a pipe.
**The way to get it and the `optional:` text may not contain ` | `:** one that does is read as more check, and runs.
`enable` runs every check first: a failed `required` one refuses, naming the id and the way to get it (the `Next:` line
points at them); a failed `optional` one warns and says what is lost. A version floor or an installed app is a shell check. A need no shell
can check, such as a signed-in account, is a `requires-agent:` line: `enable` prints it and cannot refuse on it, and the
module's own first use makes the call and stops with the way to get it. **A check runs with your rights and should only read; the
safety rule, and what the kit does and does not promise, is in [`contracts/module-lifecycle.md`](contracts/module-lifecycle.md) § 2,
and you read an unfamiliar module's `requires:` lines before enabling it.** The kit stops waiting for a check after
`KIT_MOD_CHECK_SECONDS` seconds (10 when unset). Anything that installs or writes belongs in `setup.sh`, which only a person
runs. `list` shows the ids and never runs a check.

**Rules for a module's files.**
- **Stored disarmed.** A source path never carries a name a harness reads (`KIT_MOD_ARMED_NAMES` in
  `scripts/lib/modules.sh` holds the list): `scripts/module.sh` refuses the manifest and `build-kit.sh` refuses
  the build.
- **Placeholders, never a project's values:** `<PREFIX>`, `<trunk>`, `<project name>`. A literal `main` or issue
  prefix is not stamped.
- **`SETUP.md` is shipped by every module** and opens with a one-line `KIT-CLASS` comment, which `enable` does not print.
  **A module is a catalogue row too:** the row carries the manifest's `purpose` and the ids of its requirements; the
  self-test holds both to the manifest.
- **A `KIT-CLASS:` marker** at the top of each script, role doc and process file, as everywhere in the kit; the
  `modules/` row of [`EXTRACTION.md`](EXTRACTION.md) says which of a module's files carry none.
- **No census numbers in prose**, and nothing of the maintainers' own repository's ids.
- **A role doc a module places** is read by the self-test's role-doc censuses like the core's.
- **A script a module places under `scripts/`** is the project's, not the kit's; [`contracts/README.md`](contracts/README.md)
  says how the self-test treats it.
- **Paths** in the manifest are in one canonical form: no `./`, `//`, `.` or `..` component and no trailing `/`.
- **Stack-specific material** is what a module is for, but it states what it needs; the core may not.

**A module ships its own self-test cases.** `test/cases/*.sh` define `case_<name>() {` functions and
`test/CASE-LIST` lists them; the harness loads them with its own files and runs them after the core cases, and
refuses the run for a case that is defined and not listed, listed and not defined, or named as a core case is
([`contracts/self-test-harness.md`](contracts/self-test-harness.md) § 3). A case enables the module in a sandbox
with the helpers in `scripts/test/lib/modules.sh` (`_md_sandbox`, `_md_mod`, `_md_snap`), proves the project's
own scripts read what it registered, disables it, and proves they stop. `modules/example/test/cases/example.sh`
is the template; `modules/example/` is the module to copy.

## What is not handled

- A module cannot depend on another.
- A manifest key a newer kit adds is refused by an older kit's `module.sh`.
- Placed files are tracked in `process/MODULES`, not in `process/KIT-MANIFEST`: tools that ask which scripts the
  kit ships do not see a script a module placed.
- An evidence kind a module adds is pointer-only.
- `kit-upgrade.sh` runs no requirement check and prints no `SETUP.md` for an enabled module whose new version adds one:
  `status` names a requirement that does not hold, and a step the person must take belongs in the module's release notes as
  an Action required entry.
- The record is not checked by `check-board.sh`; `./scripts/module.sh status` shows an edited or missing file.
