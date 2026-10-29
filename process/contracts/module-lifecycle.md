<!-- KIT-CLASS: KIT — contract sheet: the module lifecycle (enable, disable, resume). See process/EXTRACTION.md. -->
# CONTRACT — the module lifecycle

## 1. PURPOSE

An optional part of the kit must cost nothing while it is off, arrive and leave without a hand edit
of a shared file, and never be mistaken for the project's own work when it leaves. This contract is
what "enabled" and "disabled" must mean.

## 2. HARD INVARIANTS

- **A module that is not enabled is read by nothing.** It is stored under `modules/<name>/` with every
  name a harness reads written disarmed (`_claude/`, never `.claude/`), so a session in the project
  loads none of it.
  *Why:* a module that is off but loaded costs the tokens it exists to save.
- **Enable writes only what the module's manifest names, and records each file by its sha256.**
  The record, `process/MODULES`, is the one statement of what is enabled and of what enable wrote.
  *Why:* disable can tell a file the module wrote from one the project then edited only by comparing
  against what was written; nothing else is a reliable witness.
- **Enable refuses before it writes, and takes only what it wrote itself.** A path that already exists
  (whatever it holds), a file the kit itself ships, a block whose host has no slot, no final newline or a
  stray marker, a path that is not in its one canonical form: every one is found first, all are named,
  and nothing is changed. A write that still fails is taken back by that run.
  *Why:* a half-placed module is not enabled and not disabled, and nothing can undo it by the record; and a
  file that merely equals the module's copy may be the project's, or another module's, so recording it as
  the module's would make disable delete it.
- **Enable refuses a point whose reader this project's copy of the kit lacks.** For each extension point the
  module uses, the file that reads it is checked first; one that does not read it is named, with the file to
  merge, and nothing is changed.
  *Why:* a check that is placed and never run reads as armed. A project on an older kit gets that silently
  unless the lifecycle asks.
- **An enable that is killed is finished or taken back, never left for hand repair.** The record is written
  ahead of the files, as `pending`, one row before each path, and each file is written beside its target
  and moved in. Running enable again finishes it, trusting only the paths that record names and only while
  they hold the planned bytes or the bytes the record names (so a module source that changed in between is
  placed afresh); disable takes back what the record names. A file the project changed in between is refused
  by name and kept, never adopted. A killed run leaves no temporary file and no empty file it created.
  *Why:* a kill leaves no cleanup to run, so the proof of ownership has to be on disk before the first write.
- **Disable asks before it removes.** A shared file it must rewrite and cannot (no final newline) is found
  first and named, and nothing has been removed when it refuses.
  *Why:* a refusal after the first removal leaves a module half-disabled while its record says enabled.
- **Disable removes only what is still byte-equal to what enable wrote, and reports every other
  file; it never deletes one.** What it leaves is the project's now and says so.
  *Why:* an edited file is work. The same rule the kit upgrade applies to every shipped file.
- **Enable and disable are idempotent.** A second run changes nothing and says so.
  *Why:* a retry after an interrupted run, or a second seat running the same command, must be safe.
- **A role that history uses is not withdrawn.** The module's role layer stays, kept and named, while a
  commit on this branch or the trunk carries the role, with the way to retire it on purpose.
  *Why:* the drift report judges every trunk commit against today's role set, so withdrawing the role turns
  history that was valid into findings that fail the release gate.
- **Enable fills the module's blanks, so it needs a stamped project.** A file carrying the prefix, trunk or
  name blanks is refused before kit-init has filled them in the project.
  *Why:* kit-init's later stamp would otherwise read as an edit of the module's file, and disable would keep it.
- **Disable then leaves the tree as it was before enable, apart from files the project edited and a role
  layer that history uses.** What it
  keeps stays recorded under `kept <name>` in `process/MODULES`, so `status` and a re-enable can say whose
  leftovers they are.
  *Why:* a module that cannot be taken back cleanly is one nobody tries, and a record that says "disabled"
  while the module's arm still runs is a record that is false.
- **A module adds to the kit and edits none of it.** It reaches the kit only through the extension points
  [`MODULES.md`](../MODULES.md) lists, and no core file names a module.
  *Why:* a core that names its module is a hardcode with extra directories.

## 3. REFUSAL CONDITIONS

- An unknown module, or a name that is not a module name ⇒ refuse, pointing at the list.
- A manifest that does not read (a missing name or version, an unknown key, a source that is not a
  file of the module, a source carrying an armed name, a path not in canonical form, two entries on one
  path or two blocks in one slot of one file) ⇒ refuse, naming the line.
- A target that is not the module's to take (see § 2) ⇒ refuse, naming every such path. A path under a
  symbolic link, a symbolic-link host, and `.git/` or the record spelt in another case are among them.
- A module whose files carry the blanks, in a project not yet stamped ⇒ refuse, pointing at kit-init.
- A disable that cannot rewrite a shared file ⇒ refuse before removing anything.
- An extension point whose reader is missing from the project's copy of the kit ⇒ refuse, naming each file.
- A record row whose path leaves the project ⇒ refuse: nothing may act on it.
- No sha256 tool on the machine ⇒ refuse: without one the record cannot be written or checked.
- Every refusal carries a `Next:` line, and leaves a progress record.

## 4. WHAT GREEN MEANS

1. After enable, every file the manifest names is in place, the role and evidence layers exist, each arm
   runs in `check-board.sh`, each block is between its markers, and `process/MODULES` records every one
   with the sha256 of what was written.
2. A role the module adds is accepted by the commit-msg hook and by the board mover; an evidence kind it
   adds is accepted by the QA verdict gate; a fragment it adds is in the next PRD or card minted; a move
   check it adds refuses its transition with a `Next:` line.
3. After disable, no file or block byte-equal to the record remains (a role layer that history uses
   excepted), an edited one is reported and kept,
   and with nothing edited the tree is byte-equal to what it was before enable (a `.gitignore` that enable
   created is removed with its block).
4. The second enable, and the second disable, change no byte.
5. An enable killed at any write is finished by running it again to the tree a clean enable leaves, or
   taken back by disable to the tree from before.
6. The builder refuses a module that stores an armed name, so the zip ships every module disarmed.
7. Not covered: a manifest key a future kit adds; a module's own correctness.

## 5. MINIMAL INTERFACE

**In:** a module name; the module's directory (manifest and overlay); the project's tree.
**Out:** the placed files and registrations and the record of them, or the files removed and the
record dropped; every refusal as above. Nothing is committed: the caller is told which paths to commit.
**Not in:** what a module does once enabled; whether the project should enable it.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/module.sh` — KIT-CLASS: KIT. `list`, `status`, `enable`, `disable`.
- `scripts/lib/modules.sh` — KIT-CLASS: KIT. The manifest reader, the plan, the reader check, the record
  `process/MODULES` and the resume.
- `scripts/lib/marker-block.sh` — the block a module puts in a shared table.
- `process/MODULES.md` — what a module is, each extension point, and how to write one.
- `scripts/test/cases/modules.sh` — the self-test cases for each of § 4's lines; the module's own cases ride
  with it under `modules/<name>/test/`.
