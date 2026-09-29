<!-- KIT-CLASS: KIT — contract sheet: the kit upgrade. See process/EXTRACTION.md. -->
# CONTRACT — the kit upgrade

## 1. PURPOSE

To take a newer kit into a project that runs an older one **without overwriting what the project
made its own**, and without the upgrade's unfinished part living only in somebody's memory.

## 2. HARD INVARIANTS

- **A file the project changed is never overwritten.** The merge base is the project's own record of
  every kit file as its release shipped it; a file whose bytes differ from that record is left alone
  and its new version staged beside the tree for a person to merge.
  *Why:* the kit is copied and becomes the project's. An automated overwrite would discard exactly the
  local hardening the kit tells a project to do, including every value the initializer stamped.
- **A file the kit did not change is left as the project has it**, edited or not; a file the project
  never touched is replaced; a file new upstream is added, unless the project removed its directory.
  *Why:* only the three-way comparison tells "the kit moved" from "the project moved"; comparing two
  sides reads every local edit as drift.
- **Nothing staged carries a live name.** A staged copy sits inside the project's repository, so it
  is disarmed: no path component a harness loads configuration from, and no file name a harness or
  git reads as configuration or instructions.
  *Why:* under its own name a staged skill or instruction file is loaded as live, and a staged ignore
  file governs the staging tree — a staged `*` would silently drop every staged copy from the commit.
- **Nothing is deleted.** A file the new kit no longer ships is listed.
  *Why:* the project may depend on it, and a deletion is the one change a reader of the diff can miss.
- **Everything left to do is written down before the run ends**: one checklist item per Action
  required entry newer than the tree's version, and one per merge or removal, each naming where its
  instruction lives.
  *Why:* a deferred upgrade carried in a session's working memory is lost at the next handover.
- **The tree's version is stamped only when every item is marked done**, never by the first run.
  *Why:* a version that moves before the work does tells the next reader the work is done.
- **It runs from the new kit, against a tree it is not inside.** The tree being upgraded is named
  explicitly; the code that runs is the new release's.
  *Why:* a tree older than the upgrade tool has none of its own, and the copy inside a tree is the
  release being left.
- **It never commits, and never runs when the paths it writes hold uncommitted work.**
  *Why:* the upgrade is ordinary work that goes through the project's own board and gates; and
  backing it out must never discard work of the project's.
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
| `upgrade-target-dirty` | a path it would write holds uncommitted changes |
| `upgrade-write-failed` | a write failed part-way; the message says how to undo it |
| `upgrade-nothing-to-finish` | finishing was asked for and no upgrade is in progress |
| `upgrade-staging-missing` | the checklist exists but the staged version and manifest do not |
| `upgrade-checklist-unmarked` | finishing was asked for with an item still unmarked |
| `upgrade-checklist-uncommitted` | finishing was asked for while the marked checklist is uncommitted: finishing removes it, and the marks are the record |
| `unknown-option`, `unexpected-argument` | a mis-invocation |

**Not a refusal:** no sha256 tool, or no manifest in the tree. Every file the kit changed that differs
there becomes a merge item, and the run says why. Never a guess.

## 4. WHAT GREEN MEANS

1. After the first run: every file the project never changed is the new kit's; every other changed
   file is untouched with its new version staged; the checklist lists each item; the version is
   unchanged; nothing is committed.
2. Re-running against the same new kit changes nothing; against another version it refuses.
3. After finishing: the version and the manifest are the new kit's, and the checklist and staging
   are gone — with the marked checklist in the project's history.
4. Against a tree made from the same kit: nothing is written at all.

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
