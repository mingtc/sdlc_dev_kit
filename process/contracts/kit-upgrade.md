<!-- KIT-CLASS: KIT — contract sheet: the kit upgrade. See process/EXTRACTION.md. -->
# CONTRACT — the kit upgrade

## 1. PURPOSE

To take a newer kit into a project that runs an older one **without overwriting what the project
made its own**, and without the upgrade's unfinished part living only in somebody's memory.

## 2. HARD INVARIANTS

- **The upgrade runs when the release is held; a deferral is recorded, never asked in the reply.**
  With no leg mid-card, run it when you hold the release and apply its Action required items before
  starting new work. With a leg mid-card, do not change the scripts under it: record the deferral
  now as a one-line work item naming what it waits on, and run the upgrade when the board is next
  quiet; where no session is reading, file it through `scripts/ask.sh` with that as the working
  default. A principal's "eventually" does not override this; it permits a deferral only by those
  routes. A question put in the session's reply never stands in for the record.
  *Why:* a deferral nobody can find is a deferral nobody ends. A recorded item or a filed question
  is read by the next session; a reply, when nobody is watching, is read by no one.
- **A file the project changed is never overwritten.** The merge base is the project's own record of
  every kit file as its release shipped it; a file whose bytes differ from that record is left alone
  and its new version staged beside the tree for a person to merge.
  *Why:* the kit is copied and becomes the project's. An automated overwrite would discard exactly the
  local hardening the kit tells a project to do, including every value the initializer stamped.
- **A file the kit did not change is left as the project has it**, edited or not; a file the project
  never touched is replaced; a file new upstream is added, unless the project removed its directory.
  *Why:* only the three-way comparison tells "the kit moved" from "the project moved"; comparing two
  sides reads every local edit as drift.
- **An enabled module's placed files are carried by the record, never past an edit.** A module's placed files are
  not in the shipped manifest, so the three-way comparison above cannot see them; `process/MODULES` is their merge
  base, and [`module-lifecycle.md`](module-lifecycle.md) § 2 states the rules for a file. This upgrade's own duties,
  stated here once: stage the module's copy of a file it keeps under `.kit-upgrade/modules/<name>/`; put on the
  checklist the module's own release-notes entries newer than its recorded version, a module whose enable never finished,
  one the new kit no longer ships, and a point whose reader the project's copy of the kit lacks; refuse, before
  writing, when enabled modules are recorded and the machine has no sha256 tool; and write the checklist last, after
  the work order for each module's record, so that a run killed anywhere is finished by running it again.
  *Why:* left alone, a placed file goes stale beside a module whose disarmed copy was refreshed, and no tool but this
  one is placed to say so.
- **What the upgrade adds or replaces is written down before the first file is.** A file a killed run had already
  placed reads as current on the run that finishes it, so the "stamp what arrived" item is counted from the record in
  `.kit-upgrade/arrived`, not from the files' state; `--finish` removes it with the rest of `.kit-upgrade/`.
  *Why:* the item exists to make the adopter check exactly the files that arrived unstamped, and a count taken
  from the tree loses them in proportion to how far the first run got.
- **Nothing staged carries a live name.** A staged copy sits inside the project's repository, so it
  is disarmed: no path component a harness loads configuration from, and no file name a harness or
  git reads as configuration or instructions.
  *Why:* under its own name a staged skill or instruction file is loaded as live, and a staged ignore
  file governs the staging tree — a staged `*` would silently drop every staged copy from the commit.
- **Nothing is deleted.** A file the new kit no longer ships is listed; where the hashes show the
  project changed it, the item says it is the project's own now, never a plain "delete it".
  *Why:* the project may depend on it, and a deletion is the one change a reader of the diff can miss.
- **A new kit file carrying the scaffolding sentinel is never written over a project's own copy of
  that path that has graduated past it** (no sentinel there): neither replace nor add. The checklist
  gets one item instead: `git mv -f CLAUDE.md AGENTS.md` when the path is `AGENTS.md` and the
  project's adapter is still `CLAUDE.md`, otherwise "kept, not replaced".
  *Why:* scaffolding re-arriving in a finished project tells the next agent to start over, and the
  sentinel, not the filename, is what marks scaffolding.
- **Everything left to do is written down before the run ends**: one checklist item per Action
  required entry newer than the tree's version, one per merge, removal or kept scaffolding path, one
  per open card the new kit's checks would refuse or whose branch lacks the trunk, one per thing an
  enabled module's new version leaves to a person, and one to stamp what arrived, each naming where its
  instruction lives.
  *Why:* a deferred upgrade carried in a session's working memory is lost at the next handover.
- **The tree's version is stamped only when every item is marked done**, never by the first run.
  *Why:* a version that moves before the work does tells the next reader the work is done.
- **The marked checklist outlives the upgrade, in the tree.** Finishing moves it to
  `process/upgrades/<from>-to-<to>.md`, and refuses rather than overwrite an archive of that name.
  *Why:* the branch an upgrade is staged on may be squash-merged, which erases the commits that marked
  each item; the file is then the only record of what was done.
- **The new kit's landing checks judge the project's open cards, and are read from the new kit.** The
  card checks of [`landing-gate.md`](landing-gate.md) § 3 (`forks:`, QA Verdict, Ablation) run over every `.md` file in `in_progress/`, `dev_complete/` and
  `blocked/` that has a branch, headed by a comment or not (the QA Verdict where QA has filled a verdict
  cell, the Ablation only at `dev_complete/`), from a copy of the new kit's `scripts/lib/`
  staged in `.kit-upgrade/lib/`. A QA Verdict table with no verdict cell filled (the template's, or none) has nothing to judge: the
  check skips it, the staging summary counts the cards it skipped, and each is judged at its own landing.
  A table with any verdict cell filled is judged whole. `todo/` is not read (no branch, no work),
  and the staging summary counts the cards it left unread. A card they would refuse is one checklist item naming the rule id, and finishing refuses while any
  still would. A card whose branch resolves to no branch, a file with no frontmatter, or a project with no
  trunk branch, gets an item saying the checks did not run; it is never counted as passing. A card whose branch
  does not contain the trunk gets an item saying so: its owner brings the trunk into it before it is switched to
  where the hooks run, or it is reviewed from a worktree; the seat does neither.
  *Why:* a landing check never reads its own rule from the tree it judges, and an upgrade's own landing
  runs the gates the project had before it, so nothing else ever tests an in-flight card against the
  rules the project has just adopted. An unreviewed table has no verdict to judge, and the landing
  that reviews it runs the same checks, so skipping it loses no rule and an upgrade need not wait on a
  review by another hat. A column left out would be a place to move a card to avoid the checks; `todo/` can stay
  out because a card skipped there is judged by the same checks at its landing, so moving one gains nothing. A branch that predates the upgrade runs its own older hooks wherever it is
  switched to.
- **A marked Action required item is checked where the new kit can check it, and is recorded as declared
  where it cannot.** Finishing runs the `Verify:` command (§ 7) of every Action required item and
  refuses while one fails; the archived checklist names each item as verified, or as declared and
  unverified. An item never counts as verified without a command that ran.
  *Why:* a mark says someone said the work is done; only a command reads the tree. Without the check,
  an item marked and not done stamps the version over the undone work.
- **It runs from the new kit, against a tree it is not inside.** The tree being upgraded is named
  explicitly; the code that runs is the new release's.
  *Why:* a tree older than the upgrade tool has none of its own, and the copy inside a tree is the
  release being left.
- **It never commits, and never runs when the paths it writes hold uncommitted work.** A change that is only a block of
  an enabled module, written by an earlier run of this upgrade that was killed (the record's `pending` section names the
  block and the sha256 it holds), is that run's work and not the project's: running the upgrade again finishes it.
  The refusal names the paths that are the project's, so that committing or stashing those alone leaves the killed
  run's work for the rerun.
  *Why:* the upgrade is ordinary work that goes through the project's own board and gates; and
  backing it out must never discard work of the project's. A rerun that refused the killed run's own blocks in a file
  two modules share would leave the upgrade unfinishable short of committing half of it, and a stash of the whole tree
  would take the killed run's tracked changes and leave the files it wrote, so the scan would read those as the project's.
- **A version is read in both forms** — a release, and a build between releases
  (`KIT-RELEASE-NOTES.md` § How versions work) — so entries a build may already hold are flagged,
  not re-applied blind.

## 3. REFUSAL CONDITIONS

Each refusal exits non-zero **and leaves one progress record naming its rule**, so a refusal can be
counted after the terminal is gone ([`progress-record.md`](progress-record.md) § 5b).

| Rule id | When |
|---|---|
| `upgrade-no-target` | no tree to upgrade was named (a usage error) |
| `upgrade-target-not-a-repo` | the named tree is not the top level of a git work tree |
| `upgrade-source-not-a-kit` | the running copy is not inside an unpacked kit, or its manifest names a file it lacks or an unsafe path |
| `upgrade-source-is-target` | the running copy is the tree's own, so it would upgrade the tree to itself |
| `upgrade-version-unreadable` | either version is not `X.Y.Z` or `X.Y.Z+<tree>` |
| `upgrade-target-older` | the new kit is older than the tree |
| `upgrade-checklist-other-version` | an upgrade to another version is already in progress |
| `upgrade-target-dirty` | a path it would write holds uncommitted changes of the project's; the message names those paths |
| `upgrade-write-failed` | a write failed (a kit file, a module file, the record, the checklist, a scratch directory); the message says how many kit files were written and how to finish or undo |
| `upgrade-modules-no-sha` | the tree has enabled modules and the machine has no sha256 tool, so their files cannot be told from the project's edits; nothing is written |
| `upgrade-nothing-to-finish` | finishing was asked for and no upgrade is in progress |
| `upgrade-staging-missing` | the checklist exists but the staged version and manifest do not |
| `upgrade-checklist-unmarked` | finishing was asked for with an item still unmarked |
| `upgrade-open-card-refused` | finishing was asked for while an open card would still be refused by the new kit's landing checks |
| `upgrade-verify-failed` | finishing was asked for while a marked Action required item's `Verify:` command exits non-zero |
| `upgrade-archive-exists` | finishing was asked for and `process/upgrades/<from>-to-<to>.md` already exists |
| `upgrade-checklist-uncommitted` | finishing was asked for while the marked checklist is uncommitted: finishing removes it, and the marks are the record |
| `unknown-option`, `unexpected-argument` | a mis-invocation |

**Refused by the modules library:** an enabled module's record, or the new kit's manifest for it, that does not read is refused
with that library's own rule id ([`module-lifecycle.md`](module-lifecycle.md) § 3), while the run is still reading and before it writes.
A write that fails after the first file is written is always `upgrade-write-failed`.

**Not a refusal:** no sha256 tool (with a module enabled it is `upgrade-modules-no-sha`), or no manifest in the tree. Every file the kit changed that differs
there becomes a merge item, and the run says why. Never a guess.

## 4. WHAT GREEN MEANS

1. After the first run: every file the project never changed is the new kit's; every other changed
   file is untouched with its new version staged; the checklist lists each item; the version is
   unchanged; nothing is committed.
2. Re-running against the same new kit changes nothing; against another version it refuses.
3. After finishing: the version and the manifest are the new kit's, the staging is gone, and the
   marked checklist is at `process/upgrades/<from>-to-<to>.md`, ending in a section that lists each
   Action required item as verified or as declared and unverified.
4. Against a tree made from the same kit: nothing is written at all.
5. With a module enabled: the files it placed are the new version's where the project had not edited them,
   `process/MODULES` is true of them, and each file the project edited that the module changed is a checklist
   item with the module's copy staged.

## 5. MINIMAL INTERFACE

**In:** the new kit; the tree to upgrade; whether to start or to finish.
**Out:** a tree with the unconflicted files taken, the rest staged, and a checklist — or, on finish, a
stamped version; a summary of what was done and what to commit.
**Not in:** committing, resolving a merge, or applying an Action required item. Those are the
project's work.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/kit-upgrade.sh` — KIT-CLASS: KIT. Run as `<new kit>/scripts/kit-upgrade.sh --into <tree>`,
  then `--finish --into <tree>`. The checklist is `process/UPGRADE-CHECKLIST.md`, the staging
  directory `.kit-upgrade/`, the merge base `process/KIT-MANIFEST`. A merge item's copy is
  `.kit-upgrade/files/<path>.kit-new`, with each `.claude` component written `_claude`.
- `scripts/check-board.sh` arm `[o]` — KIT-CLASS: KIT. Reports the tree's version form and an open
  checklist's unmarked items; it never changes the verdict.

## 7. THE `Verify:` LINE

An Action required entry in `KIT-RELEASE-NOTES.md` (or `KIT-RELEASE-HISTORY.md`, which holds the older
releases; both are read by the one reader) may carry one line, indented under its bullet, that
starts `Verify:` and holds one shell command to the end of the line. The command exits 0 when the
action is done in an adopted tree, and also exits 0 in a tree the entry does not apply to; it reads the
tree and changes nothing. The notes' first `Verify:` line of an entry is the one read; the single reader
is `notes_items` in `scripts/kit-upgrade.sh`.

- **First run:** the item for that entry ends `Verify: <command>`, and the new kit's notes and history are staged as
  `.kit-upgrade/KIT-RELEASE-NOTES.md.kit-new` and `.kit-upgrade/KIT-RELEASE-HISTORY.md.kit-new`.
- **Finishing:** each command runs with `bash -c`, in the project's top level, with no input. It is read
  from the staged copies of the new kit's notes and history, never from the checklist's text, which whoever marks the
  item can edit. It runs with the authority of whoever runs the upgrade, so a kit not trusted that far
  is not upgraded to. A failing command is `upgrade-verify-failed`, naming the item, the command and its
  exit status; there is no override, because a command that fails where the entry does not apply is a
  defect in the entry.
- **An enabled module's notes:** an Action required entry of a module's own release notes (`module <name>, Action
  required, …` on the checklist) is read by the same reader, from a copy of those notes staged beside the kit's
  (`.kit-upgrade/module-notes/<name>.kit-new`), and its `Verify:` command is run and refused on in the same way. A module
  that is shipped and not enabled has no item, so contributes none. An item of a module disabled after the upgrade was staged is skipped at `--finish` and archived as declared, not run. The item's checklist line ends with its `Verify:` command, as the kit's own lines do.
- **No `Verify:` line:** the item is whatever its marker says. The archived checklist's last section
  lists it as declared and unverified; every item that is not an Action required entry is declared the
  same way.
