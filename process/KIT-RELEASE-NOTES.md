<!-- KIT-CLASS: KIT — the kit's OWN release notes, written for the project that adopted it.
     It travels unedited and is never a project's own release notes: yours are whatever
     scripts/release.sh's RELEASE_DOCS seam declares. -->
# The process kit — release notes

**What changed in the KIT, release by release, and what an adopted project must do about it.**
This file describes the development-process kit you are running — not your product. Your own
release notes are whatever your `scripts/release.sh` declares in its `RELEASE_DOCS` seam.

- **Which version am I on?** [`KIT-VERSION`](KIT-VERSION), one line, beside this file.
- **Older releases** are in [`KIT-RELEASE-HISTORY.md`](KIT-RELEASE-HISTORY.md), unchanged but for added `Verify:` lines; `kit-upgrade.sh` reads both files.
- **The full engineering log** — every change with its reasoning, and the change file behind it —
  lives with whoever maintains the kit (`PROJECT.md` § The kit, upstream names them), not in this copy. A copy of it here would go stale the day
  you started editing your kit, and it links to files that exist only where the kit is maintained.

## How versions work

| Bump | Means |
|---|---|
| **MAJOR** | A project already running on the kit has to change how it works: a role renamed, a status folder added or removed, a contract's invariant changed. Every such change is listed under **Action required**. |
| **MINOR** | New material or changed guidance you can adopt when you like. Nothing breaks if you ignore it. |
| **PATCH** | Corrections: wrong paths, broken links, wording, a refusal that should have fired and did not. |

**Before `1.0`, a MAJOR change bumps the middle number** (`0.7.0` → `0.8.0`); MINOR and PATCH
changes bump the last.

**`X.Y.Z+<tree>` is a build between releases:** the kit after release `X.Y.Z` and before the next,
`<tree>` (eight hex characters) naming the exact kit tree it was built from. Its newest notes section
is **Unreleased**, whose entries the next release's section will carry. `X.Y.Z` alone is a release.

## How to upgrade an adopted project

**The upgrade never overwrites a file you changed, and that is deliberate.** The kit is *copied* into
your repository on day one and becomes yours — your adapter, your role set, your gates. An automated
overwrite would discard exactly the local hardening the kit tells you to do. So `scripts/kit-upgrade.sh`
takes only what you never changed, and turns the rest into a checklist
([`contracts/kit-upgrade.md`](contracts/kit-upgrade.md)).

**A project that dispatches agent seats: hand [`UPGRADE-SEAT.md`](UPGRADE-SEAT.md) to one seat.** It states
the owner's authority (including for the agent's own instructions file), and carries the upgrade in a
staged worktree through the self-test, your own gates, landing, `--finish` and a handoff. The steps below are
what it runs; a person upgrading by hand follows them directly.

**First, how does a newer version reach you, and whose job is that?** The party who gave you the
kit sends you the next zip; if nobody gave it to you, nobody will, and checking for one is yours to
schedule. Write down which — and, if it is yours, on what trigger — in
[`PROJECT.md`](../PROJECT.md) § The kit, upstream.

**When.** [`contracts/kit-upgrade.md`](contracts/kit-upgrade.md) § 2 rules it: run it when you hold
the release unless a leg is mid-card, and record a deferral as a work item
([`doctrine/subagent-control.md`](doctrine/subagent-control.md) § A.10) or file it through
`scripts/ask.sh`. From its first run, the committed checklist carries whatever is still undone,
and `check-board.sh` reports it until the upgrade is finished.

Once you hold a newer release, **run the NEW release's copy, from outside your tree.** A tree older
than the script has none of its own, and a copy inside your tree is the release you are leaving:

```sh
unzip -q <path-to>/project-kit-v<X.Y.Z>.zip -d <scratch> && <scratch>/scripts/kit-upgrade.sh --into <your project>
```

1. **It stages the upgrade and commits nothing.** Every file you never changed is replaced by the new
   copy, and new files are added. A file you changed, or `kit-init.sh` stamped, that the kit changed
   too is left as it is, with the new copy under `.kit-upgrade/files/`, disarmed: `.kit-new` on every
   name, `_claude/` for `.claude/`, so no harness or git reads it as live. Nothing is deleted.
   `process/UPGRADE-CHECKLIST.md` lists what is left: every **Action required** entry newer than your
   [`KIT-VERSION`](KIT-VERSION) (from a `+` version, § How versions work, the entries your tree may
   already hold are flagged: diff each before applying it), every file to merge, every file dropped
   upstream, every day-one scaffolding file it did not write because your project is past day one,
   every open card (`in_progress/`, `dev_complete/`, `blocked/`) the new kit's landing checks would
   refuse, and the stamping checks for what arrived.
2. **Commit it through your own board and gates**, the checklist and `.kit-upgrade/` included. The
   upgrade is ordinary work: declare your hat first (`.kit/session-role`, one line `<Role> <scope>`;
   [`contracts/role-gate.md`](contracts/role-gate.md)), or the commit guard refuses the commit.
3. **Work the checklist, marking each item `- [x]`, and commit it as marked.**
   Kit feedback, unless `PROJECT.md` sets `kit-feedback: manual` or `off`: an **Action required** item you could not apply as written is a `K-NN` in `process/KIT-FEEDBACK.md`, with the item named in its *The moment.* block — `process/MANUAL.md` § Kit feedback.
4. **`./scripts/kit-upgrade.sh --finish --into .`** writes `KIT-VERSION` (the new copy's line exactly,
   any `+<tree>` included) and `process/KIT-MANIFEST`, moves the marked checklist to
   `process/upgrades/<from>-to-<to>.md` (the record of what was done, whatever merge strategy landed the
   upgrade) and removes `.kit-upgrade/`. It refuses while an item is unmarked, while the new
   kit's landing checks would refuse an open card, and while an **Action required** item that ends
   `Verify: <command>` fails it: the command, from the new kit's notes, runs in your tree and exits 0 when
   the action is done ([`contracts/kit-upgrade.md`](contracts/kit-upgrade.md) § 7). The archive lists every
   other item as declared, unverified. Commit that too.

Every refusal names its reason and leaves a progress record; the contract's § 3 lists them.

### Without the script — a release that predates it

An upgrade to `0.6.0` or older has no `kit-upgrade.sh` in its zip, so it is a read:

1. Read every version entry, below and in [`KIT-RELEASE-HISTORY.md`](KIT-RELEASE-HISTORY.md), that is newer than your [`KIT-VERSION`](KIT-VERSION). If yours
   carries a `+` (§ How versions work), the release after its `X.Y.Z` has entries your tree may already
   hold, because they were Unreleased when it was built: diff each against your tree before applying it.
2. Apply the **Action required** items — those are the only ones that can break you. One you could
   not apply as written is kit feedback, as in step 3 above.
3. Adopt whatever else you want from **Changed** / **Added**, file by file, the same way you would
   any other change: through your own board, with your own gates.
4. Update your `KIT-VERSION` to the version you have reached — the new copy's line exactly, any `+<tree>`
   included — so the next reader knows where you are.

Diffing your kit against a newer release is a legitimate way to do step 3 — but expect the diff to
include your own local law, which is not drift.

### Or let git do step 3 — a three-way merge against the release you are running

**An option, not the procedure.** `kit-upgrade.sh`, above, stays the default (for a release that
predates it, the read in § Without the script), and the notes are still how you decide every conflict this produces. Nothing here ships: it is plain git over your own history.

**What it needs is the release you are running, exactly as shipped** — and if you followed the kit's
`README.md` § Day one, you probably have it: the `init` commit is made *before* `kit-init.sh` stamps
anything, so your first commit **is** that release. With it as the base, git applies the new release
three ways: a line the kit changed and you did not arrives by itself; a line you changed and the kit
did not stays yours — **including every value `kit-init.sh` stamped**, which is exactly what adopting
a newer copy of the whole file loses (§ Known gaps, below); and a line you *both* changed is left as
a conflict for you to decide.

The blocks below carry no comments on purpose: an interactive shell that does not treat `#` as a
comment (zsh's default) would run them. Paste each one whole.

**ONCE per repository — not per clone.** It checks your first commit's *contents*, not its name,
because a first commit called `init` is not always the release: an empty `init` made so the
initializer had something to run on, or a kit unzipped into a directory that already held files,
both produce one. Branching from either would make the upgrade delete your files. It prints the
version your first commit carries; that must be the version you adopted.

```sh
root=$(git rev-list --max-parents=0 HEAD)
extra=$({ git ls-tree --full-tree -r --name-only "$root"
          git show "$root:process/KIT-MANIFEST" 2>/dev/null | awk '!/^#/ && NF { print $2 }'
          echo process/KIT-MANIFEST; } | sort | uniq -u)
if [ "$(echo "$root" | wc -l)" -eq 1 ] && [ -z "$extra" ]; then
  git show "$root:process/KIT-VERSION"
  git branch kit "$root"
else
  printf 'Your first commit is NOT the release as shipped. It differs in:\n%s\n' "$extra"
fi
```

The check compares **paths** against the release's own `process/KIT-MANIFEST`, not bytes, so a
shipped file edited *before* the first commit would pass it; README § Day one commits straight after
the unzip, so following it does not produce that case. **Releases before 0.4.0 shipped no
`KIT-MANIFEST`, so ONCE refuses them** — use the zip route below. **If the `kit` branch already
exists on your remote** (`git branch -r` lists `origin/kit`), **skip ONCE** and run
`git branch kit origin/kit` instead: re-running ONCE in a second clone moves the base back to your
first commit and brings back conflicts you have already resolved.

**EVERY UPGRADE** — one chained command, so a failed step stops everything after it. It refuses to
start unless your working tree is clean (so backing out, below, can never discard work of yours); it
unpacks the release in a checkout of its own, `../kit-upgrade`, and **refuses to commit it unless the
zip unpacked at the root and its `process/KIT-VERSION` is the version you named**; then it applies
the release, **uncommitted**, on a branch of your own. `git add -A -f` is deliberate: the zip is
exactly the release, and a personal ignore rule must not drop a shipped file from it.

```sh
{ [ -z "$(git status --porcelain)" ] || { echo 'Refusing: commit or stash your work first.'; false; }; } &&
kit_before=$(git rev-parse kit) && echo "kit was $kit_before" &&
git worktree add ../kit-upgrade kit &&
( cd ../kit-upgrade &&
  git rm -rq . && unzip -q <path-to>/project-kit-v<X.Y.Z>.zip -d . &&
  test -f process/KIT-MANIFEST && grep -qx '<X.Y.Z>' process/KIT-VERSION &&
  git add -A -f && MSG_OK=1 git commit -m 'kit <X.Y.Z>, as shipped' ) &&
git worktree remove ../kit-upgrade &&
git switch -c <your-branch> &&
git cherry-pick --no-commit kit
```

It prints `kit was <sha>` first: that is the release you were running, and BACK OUT reads it back
from `$kit_before` (if you lose the shell, set `kit_before=<that sha>` before using BACK OUT).

**If it stopped part-way** — a refused check inside `../kit-upgrade`, or a branch name already
taken — your trunk and your commits were never touched. Run `git worktree remove --force
../kit-upgrade` if that directory is still there, and BACK OUT (below), which undoes only what this
attempt did; then fix the cause and run it again. If it stopped at *nothing to commit*, `kit`
already carries that release from an earlier attempt: run only
`git switch -c <your-branch> && git cherry-pick --no-commit kit`.

The cherry-pick applies the whole release in one go and leaves **every** conflict in place at once.
Resolve each one, `git add` it (or `git rm` it, for a file you had deleted), and then — before
anything is committed — work through the list further down.

**BACK OUT**, at any point before you commit. Each line checks its own condition, so running it
twice, or after a stop before your branch existed, does nothing. The first acts only while you are on
`<your-branch>`: it **discards every uncommitted change made since the chain ran, including anything
you edited meanwhile**, returns to the trunk and deletes the branch — with `-d`, which refuses a
branch carrying commits, so a branch of your own that happens to share the name survives. The second
moves `kit` back to `$kit_before` only if this attempt added exactly one commit on top of it.

```sh
[ "$(git branch --show-current)" = '<your-branch>' ] && git reset --hard && git switch <trunk> && git branch -d <your-branch>
[ -n "$kit_before" ] && [ "$(git rev-parse -q --verify 'kit^' 2>/dev/null)" = "$kit_before" ] && git branch -f kit "$kit_before"
```

**Why `cherry-pick` and not `merge`.** A cherry-pick's base is the `kit` commit's parent — the
release you were running, as shipped — whatever your trunk's history looks like. A `git merge` finds
its base through the trunk's ancestry instead, and a squash landing (which is how
`scripts/finish-pr.sh` lands) drops the `kit` branch from that ancestry: the *next* upgrade would
then merge against your first commit, and most of the conflicts you had already resolved would come
back, with new ones on every line the kit changed in both releases. **Keep the `kit` branch** — its
tip is the next upgrade's base — and push it (`git push origin kit`) if the next upgrade may run from
another clone.

**No first commit that passes ONCE?** — ONCE said so, your release predates the manifest, you
squashed your history (README § Day one's variant for a first published commit of your own), or the
kit went into a repository that already had one. The same route works from **the zip of the version
you are running**, if you still have it: build the `kit` branch from that instead of ONCE, then
follow EVERY UPGRADE.

```sh
git worktree add --detach ../kit-upgrade &&
( cd ../kit-upgrade &&
  git switch --orphan kit && unzip -q <path-to>/project-kit-v<your-version>.zip -d . &&
  test -f process/KIT-VERSION && grep -qx '<your-version>' process/KIT-VERSION &&
  git add -A -f && MSG_OK=1 git commit -m 'kit <your-version>, as shipped' ) &&
git worktree remove ../kit-upgrade
```

Without either — no first commit that passes ONCE and no zip of your version — `kit-upgrade.sh` is
the route (or, for a release that predates it, the read in § Without the script).

**Before you commit — what this does not do for you:**

- **The Action required items still apply.** This moves text. An **Action required** item is
  something to *do*, and applying its release does not do it. `KIT-VERSION` needs no action unless you
  edited it yourself: the new release's copy arrives with everything else.
- **A clean hunk arrives without a question.** That is what makes this cheap, and it is why nothing
  is committed for you: `git diff --cached` is everything you are about to adopt, and it gets the
  review any change gets.
- **A line the kit ADDS arrives unstamped**, clean or conflicted: `kit-init.sh` stamped the lines
  that existed when it ran. What it stamps: in `.claude/roles/` and `.claude/templates/`, `<PREFIX>`
  becomes your prefix, and so does `KIT-` (before a non-digit in the role docs, before anything in
  the templates); `<project name>` becomes your project name; `<trunk>` (templates) and the word
  `main` (both, and only if your trunk is something else) become your trunk. In `scripts/`: your
  prefix, PRD prefix and project name in `config.sh`, your gate in `verify.sh`, and — if you passed
  `--roles` — your role set in every script that enforces the shipped one. In `PROJECT.md`: your project name, prefix and
  trunk. **In these checks the
  angle-bracket tokens are literal** — they are what to search for, not blanks to fill. The first two
  lines must print nothing; the third must show **your** prefix (the § Known gaps check):

  ```sh
  git grep -nE '<PREFIX>|<project name>|KIT-[^0-9]' -- .claude/roles | grep -vE 'KIT-CLASS:|KIT-DISPOSITION:'
  git grep -nE '<PREFIX>|<project name>|<trunk>|KIT-' -- .claude/templates | grep -vE 'KIT-CLASS:|KIT-DISPOSITION:'
  ./scripts/new-issue.sh --help | grep -o -- '--id [A-Z]*-NNN'
  ```

  If your trunk is not `main`, this must print nothing too:

  ```sh
  git grep -nw main -- .claude/roles .claude/templates
  ```

  And if you passed `--roles`, so must this:

  ```sh
  grep -lF -- "'$(git show kit:scripts/githooks/commit-msg | sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p")'" scripts/*.sh scripts/githooks/*
  ```

  Stamp by hand whatever they print.
- **A file you replaced or deleted conflicts whenever the kit changes it.** A `README.md` or
  `AGENTS.md` you made your own is left as a content conflict (`git checkout --ours <file>` keeps
  yours); a shipped file you deleted is left as modify/delete (`git rm <file>` keeps it gone). Read
  the version entries below first — the kit's change may be one to carry across by hand.

Then commit it, and land it the way you land anything:

```sh
git commit -m '[<Role>] Upgrade the kit to <X.Y.Z>'
```

**And one thing it gives you that the read does not.** Once an upgrade has landed,
`git diff --name-status kit` lists every shipped file your project has changed (`M`) or removed (`D`)
and every file of your own (`A`) — `kit-init.sh`'s stamps among them. That is the enumeration
§ Known gaps says the kit does not ship; here your own history makes it.

## Known gaps

The kit ships an honest debt list rather than a clean claim: [`EXTRACTION.md` § 4](EXTRACTION.md)
names what is still entangled, what it costs you, and how to check each one in your own copy.

### UPGRADING CAN UN-CONFIGURE YOUR PROJECT — what to re-check, and why

**The upgrade above never overwrites a file you changed, because an automated overwrite *"would
discard exactly the local hardening the kit tells you to do."* The hardening is ENUMERABLE, and
`kit-upgrade.sh` enumerates it from `process/KIT-MANIFEST`: a file that differs from what your release
shipped is staged for you to merge, never replaced. What follows is for the file you adopt by hand —
a merge item, or the read.**

**Several shipped files carry values the initializer wrote for YOUR project** — your issue prefix,
your role set, your gate commands, your project name. **Adopting a newer copy of one of those files
file-by-file replaces your value with the shipped placeholder**, and nothing in the kit marks which
files those are. **Derive the list against your own version rather than trusting a number here:**

```sh
# unzip the SAME kit version you are running into a scratch directory, then:
diff -rq <that-scratch-tree> . -x .git -x .kanban-wt
```

Every file that differs and that you did not edit yourself is a file the initializer stamped. **Do
that before adopting, and re-check those files after.**

**Two behaviours to know, because they fail differently:**

- **`scripts/verify.sh` fails LOUDLY** — an emptied `GATES` table refuses rather than reporting a
  green summary with nothing behind it. You will not miss it.
- **`scripts/config.sh` fails SILENTLY.** It carries `ISSUE_PREFIX`, `PRD_PREFIX` and `PROJECT_NAME`;
  replace it and the tools begin looking for the shipped placeholder prefix, so `next-id.sh` reports
  finding **no existing issues** on a board full of them. **This is the one to check first.**

  **The one-command check, because a silent failure needs a positive test rather than a warning:**

      ./scripts/new-issue.sh --help | grep -o -- '--id [A-Z]*-NNN'

  **That line renders YOUR prefix.** On a correctly configured tree it shows your own — `--id
  ABC-NNN`. If it shows **`--id KIT-NNN`**, the shipped placeholder is back and `scripts/config.sh`
  is the file to restore. Everything still runs and exits 0, which is exactly why the check is worth
  running rather than waiting for a symptom.

**And `kit-init.sh` will not re-stamp for you.** It refuses on a repository that has already lived —
correctly, because an initializer that can overwrite a working board is worse than none. **The repair
is version control: restore the file and re-apply the upgrade's changes by hand**, which is what
"file by file" was always asking for.

*The guard that stops `kit-init` re-running on a live board reads part of its evidence from
`scripts/config.sh`, so replacing that file weakens it. It does not defeat it — the board's own
contents are a separate signal that no shipped file can overwrite, because the kit ships the empty
columns and never the cards.*

---

## [Unreleased]

### Action required

- **A changed AC bullet needs its own `[decision: D-NN]` citation.** The check that refuses a landing whose AC text changed after
  the card left `todo/` (`forks-ac-changed-uncited`) now reads the citation on the changed bullet's own checklist line; a
  citation in another AC or in the Activity does not cover it. An in-flight card whose changed AC bullet carries no citation of
  its own now refuses at landing, naming the bullet: put the `[decision: D-NN]` on the bullet that changed. (This supersedes
  "anywhere on the card" in the 0.9.0 entry in `KIT-RELEASE-HISTORY.md`.)
- **A card moved to `qa_complete/` by `move-issue.sh` is checked for its `## QA Verdict` table.** That is every
  direct-to-trunk card and every landing done by hand; `finish-pr.sh` already checked its card. An in-flight card whose table
  is unfilled now refuses the move, naming the rule and the fix. Fill the table and commit it to the trunk first
  (`./scripts/register-commit.sh`): the move reads the trunk's copy, so a table in a local commit that was not pushed counts as
  unfilled.

### Changed

- **`./scripts/read-verdict.sh <id>` reads a card's verdict on the trunk.** It prints the card's column on `<remote>/<trunk>`, each
  QA Verdict row's verdict, and whether the landing gate would accept the table; it writes nothing. The Orchestrator runs it before
  promoting any QA reply to a board move, direct-to-trunk cards included (`orchestrate/SKILL.md` § 3). No action.
- **A landing's Activity entry names the revisions the QA Verdict was read at.** `finish-pr.sh`'s `Review — PASS` entry carries the
  branch tip the check read and the squash commit it landed; a direct-to-trunk `move-issue.sh <ID> qa_complete` carries the trunk
  tip it read. Re-resolve a landed row's `path:line` at that revision, not at today's code. No action.
- **A QA Verdict row is checked pointer by pointer.** Each quote is read against the `path:line` it follows, so a row that cites
  two places lists both, each followed by its own quote (`README.md:2 "first"; src/a.js:8 "second"`). The landing check now refuses
  a pointer with no quote of its own (naming the pointer), a quote shorter than 8 characters (unless it is the cited line's whole
  text), and two rows for one AC id (write one row that lists every pointer). No action unless an in-flight card carries a row of
  those shapes; its next landing says which.
- **`register-commit.sh` refuses a second copy of a card.** A landing that creates a `progress/**/<ID>-*.md` file while the trunk
  holds that card at another path (a Dev's checkout still has the `in_progress/` copy after the card moved to `dev_complete/`) is
  refused as `register-card-moved`, naming the trunk's path. Bring that file into your checkout, edit it there and land it. A
  landing that also deletes the old path is a move and lands. No action.

### Fixed

- **A QA Verdict cell may contain a pipe written `\|`.** The landing check reads `\|` as part of its cell (as `|`, so a quote
  containing a pipe matches its cited line) and refuses an unfilled template row for the cells that are actually unfilled. An
  unescaped `|` still starts a new cell.

## [0.10.1] — 2026-10-17

### Changed

- **A scheduled `/orchestrate` now proceeds instead of ending on its plan.** With `KIT_UNATTENDED=1` the Orchestrator files
  its run plan and each pre-surfaced decision through `scripts/ask.sh` (role `Orchestrator`, your plan as the default) and
  runs on the plan; a decision it cannot run under parks the cards it blocks, never the run. Attended runs still stop for
  sign-off. It needs `PROJECT.md`'s `principal:` and channel declared (as for any `ask.sh` call) and a principal other than
  the Orchestrator; if `ask.sh` refuses, the plan goes in the run report and the run carries on.

