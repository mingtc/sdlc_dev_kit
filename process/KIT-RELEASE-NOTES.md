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
staged worktree, landing each batch on the trunk through `register-commit.sh`, through the self-test,
your own gates, `--finish` and a handoff. The steps below are
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
   refuse, every open card whose branch does not contain the trunk, and the stamping checks for what arrived.
2. **Commit it through your own board and gates**, the checklist and `.kit-upgrade/` included. The
   upgrade is ordinary work: declare your hat first (`.kit/session-role`, one line `<Role> <scope>`;
   [`contracts/role-gate.md`](contracts/role-gate.md)), or the commit guard refuses the commit.
3. **Work the checklist, marking each item `- [x]`, and commit it as marked.**
   Kit feedback, unless `PROJECT.md` sets `kit-feedback: manual` or `off`: an **Action required** item you could not apply as written is a `K-NN` in `process/KIT-FEEDBACK.md`, with the item named in its *The moment.* block — `process/MANUAL.md` § Kit feedback.
4. **`./scripts/kit-upgrade.sh --finish --into .`** writes `KIT-VERSION` (the new copy's line exactly,
   any `+<tree>` included) and `process/KIT-MANIFEST`, moves the marked checklist to
   `process/upgrades/<from>-to-<to>.md` (the record of what was done, whatever merge strategy landed the
   upgrade) and removes `.kit-upgrade/`. It refuses while an item is unmarked, while the new
   kit's landing checks would refuse an open card (a QA Verdict table with no verdict filled is skipped), and while an **Action required** item that ends
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
  git grep -nE '<PREFIX>|<project name>|KIT-[^0-9]' -- .claude/roles | grep -vE 'KIT-CLASS:|KIT-DISPOSITION:|KIT-MODULES:|KIT-FEEDBACK'
  git grep -nE '<PREFIX>|<project name>|<trunk>|KIT-' -- .claude/templates | grep -vE 'KIT-CLASS:|KIT-DISPOSITION:|KIT-MODULES:|KIT-FEEDBACK'
  ./scripts/new-issue.sh --help | grep -o -- '--id [A-Z]*-NNN'
  ```

  If your trunk is not `main`, this must print nothing too:

  ```sh
  git grep -nw main -- .claude/roles .claude/templates
  ```

  And if you passed `--roles`, so must this. It reads the release's shipped role set from the zip you
  upgraded to, so it runs the same after `kit-upgrade.sh` and after the git route:

  ```sh
  grep -lF -- "'$(unzip -p <path-to>/project-kit-v<X.Y.Z>.zip scripts/githooks/commit-msg | sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p")'" scripts/*.sh scripts/githooks/*
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

_Nothing yet._

## [0.12.2] — 2026-11-01

### Action required

- **`check-board.sh`'s graduation arm now reports `COMPLETE` only once a PRD exists and a card has passed QA (`qa_complete/` or `done/`), not on filled blanks alone.** A new `DAY-ONE WORK` line names whichever is missing, and `[p]` stops flagging the `forward-referenced (SEED step 6)` marker `CORPUS.md` tells you to write until day one has closed. `kit-init`'s closing `Next:` now names `PRD-001` (`./scripts/new-prd.sh <slug>`) before the first issue. SEED's done-list names the PRD and the role docs' `Model & effort contract` rows (`set-models.sh` does not write them), and says which lines are expected until the first card lands. If your project finished day one without a PRD (every card `prd: n/a`) or with no card in `qa_complete/` or `done/`, `/start` will walk SEED again until both exist: check those two.
  Verify: ./scripts/check-board.sh 2>&1 | grep -q 'DAY-ONE WORK:.*✓'

- **`check-board.sh` finds your PRDs by `PRD_PREFIX` in `scripts/config.sh`.** A project that ran `kit-init --prd-prefix <P>` now has `requirements/<P>-NNN-*.md` counted by the graduation arm's `DAY-ONE WORK` line (it could not read `COMPLETE` before) and read by arm `[r]` and the landing's coverage and `forks:` checks. `check-board.sh` no longer carries a `PRD_SURFACE` literal; it derives it from `PRD_PREFIX`; if you had repointed it, set `PRD_PREFIX` in `scripts/config.sh` to the prefix your PRDs carry instead, or they are no longer found.
  Verify: grep -q '^PRD_PREFIX="${PRD_PREFIX:-[A-Za-z0-9]*}"$' scripts/config.sh && grep -q '^PRD_SURFACE="$(kit_prd_surface' scripts/check-board.sh

- **The status folder set is declared once, in the new `scripts/lib/status-folders.sh`.** `check-board.sh`, `move-issue.sh`, `subtask.sh` (the set without `done`), `kit-init.sh` and `setup.sh` derive it from that file instead of each carrying the names, and a landing reads it from the trunk's copy of the file. If your project renamed, added or removed a status folder, make that edit once, in `KIT_STATUS_FOLDERS`, and keep `progress/<folder>/` in step with it; a script of yours that carried the names arrives as a merge item, and the names in your copy are dropped in favour of the file's. A project on the shipped folders does nothing.
  Verify: ( for d in progress/*/; do [ -d "$d" ] || continue; d="${d#progress/}"; d="${d%/}"; case "$d" in history|subtasks) continue ;; esac; case "|$(sed -n "s/^KIT_STATUS_FOLDERS='\(.*\)'/\1/p" scripts/lib/status-folders.sh)|" in *"|$d|"*) ;; *) echo "progress/$d is not in KIT_STATUS_FOLDERS"; exit 1 ;; esac; done )

- **A role is added by a line in the new `process/ROLES`; merge the new `scripts/githooks/commit-msg` block that reads it.** The hook, `move-issue.sh`, `subtask.sh`, `register-commit.sh`, `ask.sh` and `check-board.sh` read the hook's `ROLE_PREFIXES` line, then `process/ROLES` (shipped with no role line), then any `process/roles.d/<name>` file, through `scripts/lib/role-set.sh`. `kit-init.sh` stamps your `ROLE_PREFIXES` into the hook, so the upgrade stages the new hook as a merge item: take its `role-set.sh` block and keep your own `ROLE_PREFIXES` line. A hook without the block still enforces your set, but a `process/ROLES` line is then accepted by the board scripts and refused by the hook. To add a role: commit and push a line in `process/ROLES` (the board is committed from the trunk); `process/EXTRACTION.md` § 2.4 lists what else a new role touches.
  Verify: grep -q 'kit_role_extend' scripts/githooks/commit-msg

- **Add the module lifecycle row to your `PROJECT.md` gates table.** The kit gains a contract sheet, `process/contracts/module-lifecycle.md`, and `PROJECT.md` a row for it. A project whose `PROJECT.md` was filled does not receive the row by itself: the table check `PROJECT.md` prints reports `UNROWED process/contracts/module-lifecycle.md` until it is in the table, and the self-test runs that check. The row has nothing to fill; take it as shipped, from the merge item or from the release's `PROJECT.md`.
  Verify: awk '/^\| Gate \|/{t=1} t&&!/^\|/{t=0} t' PROJECT.md | grep -qF 'process/contracts/module-lifecycle.md)'

- **`modules/` is `DELETE-IF-UNUSED`: at graduation, remove it or record keeping it on purpose.** `modules/README.md` declares the marker, so `check-board.sh` `[g]` names it as an undecided member until you decide. A project that will enable no module deletes `modules/`. One that keeps it adds the line `- **`modules/README.md` (DELETE-IF-UNUSED) kept, on purpose.** <why>` to `process/LOCAL-PROCEDURES.md` (`process/SEED.md` step 8). The upgrade adds the marker only to a file you never changed.
  Verify: [ ! -f modules/README.md ] || grep -qF -- '- **`modules/README.md` (DELETE-IF-UNUSED) kept, on purpose.**' process/LOCAL-PROCEDURES.md

- **Dated design passes live in `dev/design-passes/`, not `dev/design/`.** The name `dev/design/` is retired. `kit-upgrade.sh` lists `dev/design/.gitkeep` as removed upstream and adds `dev/design-passes/.gitkeep`; `dev/README.md`, `pm.md` and the parked UI-Designer role name the new path. Nothing in the scripts reads the directory. A project whose `dev/design/` holds passes (only the UI-Designer writes them) moves them: `git mv dev/design/* dev/design-passes/`, then removes the empty `dev/design/`.
  Verify: [ ! -e dev/design ] && [ -d dev/design-passes ]

### Changed

- **The `design` module now ships its checkers and a pin-drift report, and requires Python 3.9 or later.** `scripts/design/check-design-links.py` reports the links between PRD stories, screens, approvals and cards in both directions (and, with `--leaving <card>`, what a card leaving `todo/` owes), `prd-view.py` and `flow-from-links.py` derive a PRD's screens and the screen-flow graph, and `check-board.sh` prints `[+design-drift]`: each pinned state of a card past `todo/` as clean, moved, drift, gone, unresolved or uncompared (it could not tell, and says why). It reports and decides nothing. A PRD or story with no `**UI:**` line reads as none declared (an info line, not a finding). The module's gate row in `PROJECT.md` runs the link check with `--strict`; a colour literal in a screen's CSS (a style, a style attribute, a presentation attribute, a sheet or imported screen it loads) other than as the value of a custom property named for a token fails it unless the screen's registry row carries a `[decision: D-NN]` that `requirements/DECISIONS.md` holds, so a project whose screens already carry literals goes red after the upgrade (the module's notes say what to do). Pins and approvals cover the artboard, the tokens it uses and the local files it loads (stylesheets, scripts, images, screens it imports), and a pin says `uncompared` where it cannot compare. `enable` and `module.sh status` check for Python; `kit-upgrade.sh` carries a project that enabled the module to the new version, and the module's own notes carry its Action required entries. A project that does not enable the module changes no behaviour; its self-test skips what needs Python 3.9 or later when that is absent.
- **`kit-upgrade.sh --finish` now runs the `Verify:` line of an enabled module's own release notes.** A module's Action required entry that carries one is checked like the kit's own: a non-zero exit refuses `--finish` as `upgrade-verify-failed`, naming the module and the item. The checklist line shows the command. The module's notes are staged at `.kit-upgrade/module-notes/<name>.kit-new` by the first run. A module you have not enabled adds nothing; one you disabled after the upgrade was staged is skipped at `--finish` and archived as declared, not run; an entry without a `Verify:` line is still declared by whoever marks it.
- **An upgrade killed part-way and run again now lists every file it replaced or added in the "stamp what arrived" item.** `kit-upgrade.sh` writes `.kit-upgrade/arrived` before it writes the first file (committed with the rest of `.kit-upgrade/`, removed by `--finish`); a re-run used to count only the files the killed run had not reached, so the item undercounted or went missing.
- **`kit-init.sh --help` now says a role can also be added after init**, by a line in `process/ROLES` or a file under `process/roles.d/`. Help text only; nothing to do.
- **A merge item for `scripts/githooks/commit-msg` now says what to keep.** Like `scripts/config.sh` and `scripts/verify.sh`, a stamped hook holds your own values: merge the new copy into it, keep your `ROLE_PREFIXES` line, and take the role-set block.
- **`move-issue.sh --role` now refuses a role that only your checkout declares.** The commit hook that judges a board move runs in the kanban worktree, a copy of the trunk, so a role added to `process/ROLES` or `process/roles.d/` and not yet pushed used to pass the check and then be refused mid-move, leaving the worktree dirty. The mover now checks the trunk's set before it changes anything and refuses `role-not-on-trunk`, naming the push as the next act. When the sync was offline it refuses `role-trunk-unread`, saying the trunk could not be read and to reconnect.
- **`archive.sh`, `finish-pr.sh`, `subtask.sh` (new and move) and `register-commit.sh` now refuse a role that only your checkout declares, before they write; the first `--role` check of each of these scripts and of `move-issue.sh` says what to do when the trunk declares a role you lack.** Each used to pass such a role and be refused by the commit hook after the change began, leaving the kanban worktree dirty so the next board operation refused `kanban-sync-dirty`. They now check the trunk's set after the sync (`register-commit.sh`: after laying its paths over the worktree, so a call that names `process/ROLES` or a `roles.d/` file still lands, and it puts the worktree back when it refuses): `role-not-on-trunk` names the push, or acting as a role the trunk already declares, and an offline sync refuses `role-trunk-unread`. One case is newly refused: `FINISH_PR_ROLE=<role>` where the branch being landed itself adds that role used to land; land it as a role the trunk already declares (`QA` by default). A role the trunk declares and your checkout lacks is refused at the first check, whose `Next:` now says to fetch the trunk and merge it into your branch (or run from the trunk), since `git pull` does nothing on a feature branch. No action.
- **A `design` module ships, off: where screen designs live and how a story and a card cite them, with a Designer role.** `./scripts/module.sh enable design` (or `kit-init.sh … --with design`) adds the `Designer` role, the rules in `requirements/design/README.md`, canvas and comments templates, `**UI:** none` in a new PRD's first story and `design: none` in a new card, the `design` QA evidence kind, and CORPUS, gate and `.gitignore` rows; `modules/design/SETUP.md` has the human steps. The module's first version has no canvas pull or publish command, drift check, card gate, token generator, renderer, audit or checker: the Designer role lists them, and says to tell you each needs the next version of the kit rather than improvise it. Claude Design's own agent makes the screens: the Designer writes the brief, and you carry it to that agent and its files, PNG exports and comments back; creating and updating the artifact directly is the adapter's. A project that does not enable the module changes no behaviour.
- **`dev.md`'s `## Handoff to QA` section is now `## Handoff to QA: procedure and template`.** The pasted block keeps the heading `## Handoff to QA`, which QA reads in the issue file, so it is unchanged; merge the renamed heading if you cite it by name.
- **An add-on's `ISSUE` fragment (`process/fragments.d/ISSUE/`) now reaches a new bug, refactor and slice, not only a card from `new-issue.sh`.** `new-bug.sh`, `new-refactor.sh` and `subtask.sh new` place it as `new-issue.sh` does; `subtask.sh` reads it from the trunk. With no fragment enabled the cards are unchanged. No action.
- **Optional modules ship in the kit, off, and a project enables them with `scripts/module.sh`.** `modules/<name>/` holds an overlay stored disarmed (`_claude/`, never `.claude/`), so a module that is off is read by nothing. `./scripts/module.sh list | status | enable <name> | disable <name>` places a module's files, registers them with the extension points `process/MODULES.md` lists, and records each file's sha256 in a tracked `process/MODULES`; `disable` removes what is still as it wrote it and keeps, and names, a file you edited, and keeps a role layer while commits already carry its role (so the drift report does not flag them). `enable` refuses, writing nothing and with a `Next:` line, a path that is not the module's, a slot that is missing, a project not yet through `kit-init.sh` when the module's files carry its blanks, and a point your copy of the kit does not read (a project on an older kit gets the merge it needs named, rather than a check placed and never run); an `enable` that is killed is finished by running it again, or taken back by `disable`. `archive.sh` now runs the `done/` move checks before it sweeps, so it arrives as a merge item if you edited it. `modules/example` is the toy to read and copy, and the self-test enables it. New: `scripts/module.sh`, `scripts/lib/modules.sh`, `process/MODULES.md`, `process/contracts/module-lifecycle.md`, `modules/`, and `scripts/test/lib/modules.sh` and `scripts/test/cases/modules.sh` in the self-test. A project that enables no module changes no behaviour beyond the two entries under Action required above.
- **A module can be enabled on day one, and an upgrade carries an enabled module's new version.** `kit-init.sh --with <name>[,<name>]` enables the module after the stamp and before the initialization commit, so its files and `process/MODULES` are in that commit; its preflight asks every question `module.sh enable` asks, and whether git would add what enable places, and refuses, writing nothing, when one fails. `kit-upgrade.sh` now compares each file or block an enabled module placed with the sha256 `process/MODULES` holds: one still as enable wrote it is replaced; one you edited that the module changed is kept, with the module's copy staged under `.kit-upgrade/modules/<name>/` and a merge item; one you deleted stays deleted; one the module no longer places is listed and never deleted; a role layer that would drop a role your commits carry is kept. The module's own `release-notes:` entries under `### Action required` that are newer than the recorded version become checklist items, with the other duties `process/contracts/kit-upgrade.md` § 2 lists. With a module enabled and no sha256 tool, the upgrade refuses before it writes (`upgrade-modules-no-sha`). A killed upgrade is finished by running it again: the checklist is written last, after a work order for each module's record. A project that enables no module changes no behaviour; `kit-init.sh`, `kit-upgrade.sh`, `scripts/module.sh` and `scripts/lib/modules.sh` arrive as merge items if you edited them. No action.
- **The self-test's kill-enumerating cases run a bounded set of kill points by default.** `./scripts/test/run.sh` kills `kit-upgrade.sh` before the writes that mark a boundary or touch a shared file, a record or the checklist, and one in eight, instead of before every write; `KIT_TEST_KILL_ALL=1 ./scripts/test/run.sh` runs every write and every order of enabling. No action.
- **A `kit-upgrade.sh` killed while two enabled modules share a file (`PROJECT.md`, `.gitignore`) is finished by running it again, and `kit-init.sh --with` refuses two modules that place one path.** The rerun used to refuse the killed run's own blocks in that file as your uncommitted change; it now takes them as the run's, and still refuses a line or an edited block of yours there. `upgrade-target-dirty` names your paths and its `Next:` stashes those alone (a bare `git stash` also takes the killed run's work and leaves the files it wrote, so the record comes out wrong). `--with a,b` where both place one path, or one path in two cases on a filesystem that reads case as one, now refuses in the preflight, writing nothing; a module path that differs from a file `kit-init` writes only in case is refused the same way. No action.
- **A module states what it needs, and how to set it up.** Its manifest may carry `requires: <id> | <shell check> | <how to get it> | required` (or `… | optional: <what is lost>`), and `requires-agent:` for a need only an agent can check, such as a signed-in account. `module.sh enable` and `kit-init.sh --with` run each shell check first, with your own rights, stopping the wait after 10 seconds (`KIT_MOD_CHECK_SECONDS` changes the limit; read the `requires:` lines of a module you do not trust before you enable it), and refuse a required one that fails, writing nothing and naming how to get it; an optional one warns. `status` runs the checks again and names a requirement that has stopped holding; `list` shows what each module needs, enabled or not. A module ships a `SETUP.md`, which `enable` prints, and may ship a `setup.sh`, which no command of the kit runs. `process/MODULES.md` gains a catalogue of the modules, and `AGENTS.md` (as shipped), the adapter template and the `/start` skill point at it so an agent can offer a module the person's request calls for (and enable it only on their yes). No action; to have your own `AGENTS.md` carry the pointer, copy the paragraph that opens `**Optional modules ship off.**` from `process/templates/AGENTS-adapter.template.md`.
- **A board move's checks, a QA row's cell checks and a PRD's or card's extra fields are each added by a file.** `move-issue.sh` runs `scripts/move-check.d/<target>/<NN>-<name>.sh` from the trunk before it moves a card (status `0` allows, `3` refuses with a `Next:` line, any other status refuses too; `process/contracts/board-mover.md` § 3); `finish-pr.sh` runs the `qa_complete` ones before its squash and `subtask.sh` runs them before a slice moves. The QA gate runs `scripts/qa-cell.d/<evidence kind>/<NN>-<name>.sh` on each PASS row of that kind, against the revision being landed (`landing-gate.md` § 3). `new-prd.sh` and `new-issue.sh` place `process/fragments.d/<PRD or ISSUE>/<name>.frontmatter`, `.body-end` or `.slot-<slot>` into the new file (`issue-creation.md` § 3), and `PRD.template.md` gains a `<!-- KIT-MODULES:story-fields … -->` line that every mint removes (`kit-init.sh` leaves its `KIT-MODULES:` key unstamped, and the two stamping checks in § How to upgrade skip it). `scripts/lib/addon-check.sh` is new; `move-issue.sh`, `lib/qa-gate.sh`, `lib/card-head.sh`, `new-prd.sh` and `new-issue.sh` change, so a copy you edited (or `move-issue.sh`, which `kit-init --roles` stamps) arrives as a merge item: keep your stamped values, take the new blocks. A project that adds none of those files changes no behaviour, but one that adds a check needs the new readers: an older `move-issue.sh` does not run it. When `modules/<name>/test/` exists, the self-test also loads the cases its `CASE-LIST` names.
- **A drift-report arm, a QA evidence kind and a shared-file block are each added by a file.** `check-board.sh` runs `scripts/check-board.d/<NN>-<name>.sh` after its lettered arms as `[+<name>]` arms (each declares `# check-board-arm: advisory` or `deciding`; `process/contracts/drift-report.md` § 5), and `kit-init.sh`'s self-check and the SessionStart hook read a `[+name]` heading like a `[x]` one. The QA gate reads extra evidence kinds from `process/evidence-kinds.d/<name>` on the trunk through `kit_qa_evidence_kinds` in `scripts/lib/qa-gate.sh`; `KIT_QAV_KINDS` is now `KIT_QAV_KINDS_BUILTIN`, read by that function only, so a script of yours that read the variable calls the function. `scripts/lib/marker-block.sh` inserts and removes a marked block in a shared file, and `PROJECT.md` and `requirements/CORPUS.md` gain `<!-- KIT-MODULES:<slot> -->` lines it writes before. A project that adds none sees no change. `check-board.sh`, `kit-init.sh`, `hooks/session-start.sh`, `PROJECT.md` and `CORPUS.md` arrive as merge items; taking the slot lines is optional.
- **`register-commit.sh` now refuses a register line that cites an unlanded answer when `PROJECT.md`'s channel has no trailing slash** (`dev/questions` as well as `dev/questions/`), where it used to land. Where the guard cannot run it prints `the unlanded-answer guard did not run: <why>`. Nothing to do: land the question file in the same call, as the refusal says.
- **Check-board `[i]` (`blocks:`/`blocked_by:` symmetry, also run at landings) now reads the lists the way `move-issue.sh` does.** A key must start in column 0 (an indented `blocked_by:` is no longer read), only the fenced frontmatter is read (a card with no `---` fence declares nothing and has no id), and a `#` ends a value only after whitespace (`X#1` is an id). Flow lists, bare scalars, block lists and trailing comments read as before; the kit's card templates are unaffected.
- **`set-models.sh` removes the ladder row of a role you removed, if the row is still blank.** After you delete an optional role (the Refactorer), `--all` or `--class` drops its `<fill in>` row from `orchestrator.md`'s ladder and says so; a row you filled stays and is named in the output. No action.
- **`move-issue.sh` warns, without refusing, when you move a card to `in_progress` or `dev_complete` while a card in its `blocked_by:` list is not yet in `qa_complete/` or `done/` on the trunk.** One stderr line per blocker, naming where it sits; the move proceeds. No action.
- **The card templates ship the title quoted, `title: "<one-line summary>"`, so a title with a colon is valid YAML.** `kit_card_field … title --raw` strips the quotes (and unescapes `\"` and `\\`), so `ARCHIVE.md` rows and squash-commit subjects stay bare; `subtask.sh new` writes the slice title quoted. A new report-only `check-board.sh` arm, `[u]`, lists a card whose unquoted `title:` is not valid plain YAML (`: `, ` #`, a trailing `:`, or a leading YAML indicator). Inside a quoted title a `"` or `\` is written `\"` or `\\`. Existing cards need no edit. `PROJECT.md`'s read/write-separation blank names `requirements/DECISIONS.md` as the home of the open decision; SEED step 6 says to save the human's brief verbatim as an indexed `dev/` record; `qa.md` separates a dated status snapshot from a promise; `pm.md` says an Out-of-scope line that narrows an AC rewrites that AC while the card is in `todo/`.
- **The self-test no longer fails after you remove a `DELETE-IF-UNUSED` member** (`consumers/`, the notify adapters, `.claude/roles/archive/`, the release and refactor routes): it skips the cases that need the member. `process/KIT-MANIFEST` has a fourth column, the file's `KIT-DISPOSITION` (`-` where it declares none); nothing that reads the manifest needs a change.
- **The `## QA Verdict` table has a fifth evidence kind, `artifact`, for a file QA committed on the trunk (a screenshot, a render).** The pointer is `<path> <full blob sha>` (from `git rev-parse <remote>/<trunk>:<path>`; a prefix is refused), and the landing resolves it on the trunk, never on the work branch. No quote is read, and the table still needs one `test` or `file:line` row. `dev/evidence/<card-id>/` is where such files live (`dev/evidence/README.md`). Existing cards and kinds are unchanged; `qa.md` and the card templates list the new kind.
- **New question files say who lands the answer.** The `**To answer:**` line `ask.sh` writes now names the first seat to read the answer as the one who lands the file with `scripts/register-commit.sh`, which refuses a register line that cites an answer the trunk lacks. Question files already written are unchanged.
- **`finish-pr.sh` names what is dirty when it reads the landed trunk in a fresh worktree.** When your gate checkout has uncommitted tracked changes, the note lists those paths (first five, then a count) and, for a stale card copy under `progress/`, prints the `git -C '<worktree>' checkout -- '<path>'` that clears it. Nothing is discarded for you.
- **`scripts/config.sh` has an optional `POST_MERGE_PREP` command.** When `finish-pr.sh` has to read the landed trunk in a fresh worktree (your gate checkout has uncommitted tracked changes), it runs that command there first, so a gate that needs installed dependencies can run; empty (the default) changes nothing, and a failing prep reads `UNRUNNABLE`. The uncommitted-changes note now says to commit or stash to read the gate checkout in place.
- **Kit feedback gains a fifth capture moment, an `Effect:` line and a root-cause block.** `process/MANUAL.md` § Kit feedback adds **M5**: a kit refusal, `⚠` or hook denial you did not clear by doing what it printed (you worked around it, overrode it, or satisfied it with a record that was not true) is written up in the short form before your next action. M2 (b) now reads the session's refusals from `.progress-records/` and accounts for each; M2 (d) also covers a gap you filled because the kit had none. `manual` and `off` still fire nothing. `KIT-FEEDBACK.skeleton.md` gains an `Effect: blocks | misleads | friction` line, a short form (*The moment.* and *What happened* alone), `inferred` marking, and a `## Root causes — through K-NN` block to append before a send to a named destination. `MANUAL` and the skeleton arrive with `kit-upgrade.sh`; your `process/KIT-FEEDBACK.md` and `AGENTS.md` are yours, so to take it in full copy two things by hand: the `Effect:` line and the short-form paragraph from the skeleton's *The shape of an entry* into your `process/KIT-FEEDBACK.md` (existing entries stay as they are), and the M5 sentence into the kit-feedback line under step 5 of your `AGENTS.md`. Nothing breaks if you do not.

- **`check-board.sh` says what only your checkout holds, and `register-commit.sh` will not cite it.** A new `[f0]` line in the unpublished-work arm names the uncommitted and untracked paths in the main checkout that no arm reads (a `⚠` only for a path in a place an arm would read: the board, `requirements/`, the register, the question channel). `[t]` now also lists a question file whose `**Answer` is in your checkout but not on `<remote>/<trunk>` (uncommitted, or committed and unpushed); both report only. `register-commit.sh` refuses (`register-cites-unlanded-answer`) a register entry that names a question file whose answer the trunk lacks: add the question file to the same call. The Orchestrator's answered-question section now says the first seat that reads an answer lands the question file (under its own role), records one `D-NN` per independent fork, amends a standing-ruling entry in place, and adds an act that records a requirement change in the PRD and on the affected cards (a PRD story whose cards are done is not edited; the change becomes a new story). No action.
- **`finish-pr.sh` says a stacked branch's base has *already squash-landed* when it has, even if the base's local branch was left behind** (for example held by a worktree); before, it said the base had not landed. `dev.md` and `qa.md` now say who rebases a stacked branch after its base lands (the Dev, when QA lands the base) and when the verdict survives it (a patch-id-equal delta).
- **`forks:` is checked against the rulings a card *resolved*.** A `[decision: D-NN]` on an AC bullet that has not changed since the card left `todo/` no longer has to be listed in `forks:`; a citation anywhere else on the card still does. The refusal's `Next:` now says how to note an applied ruling without claiming it (write the id without brackets). A card you had to mark `forks: [D-NN]` only because an AC cited that ruling can go back to `none`. No action.
- **The contract sheets cite each other's invariants instead of restating them.** `contracts/ask.md`, `config-seam.md`, `drift-report.md` and `kit-upgrade.md` now point at `.claude/roles/orchestrator.md` § An answered question is ready work, `landing-gate.md` § 3-4, `release-ritual.md` § 3 and `initializer.md` where they used to repeat a rule. No rule changed; if you edited those sheets, expect merge items.
- **`move-issue.sh` and `lib/qa-gate.sh` print a set from the variable that holds it instead of retyping it.** `move-issue.sh --help` and its unknown-target refusal now print the target folders from the status folder set, its blocked-base warning cites `dev.md` for the rebase, `qa-verdict-no-observed` lists the evidence kinds from `kit_qa_evidence_kinds` (a project that adds a kind sees it there). Refusal ids and `Next:` lines are unchanged. If you edited these scripts, expect merge items.
- **The role docs and the four leaf-worker definitions that fill a ladder cite their home for a set or another role's condition instead of restating it.** `pm.md` points at `move-issue.sh --help` for the move targets and at `MANUAL.md` for the AC-baseline carve-out of the `forks:` check; `qa.md` names the Dev as the one who rebases a stacked branch and cites `dev.md`; `orchestrator.md` and `dev-worker.md`, `pm-mint.md`, `qa-worker.md`, `refactorer-worker.md` cite `contracts/model-provisioning-seam.md` for what `set-models.sh` writes. No act, step, refusal or report shape changed, and the role docs still say "primary checkout" (the trunk stamp rewrites a role doc's word `main`, so they cannot say "main checkout"). These files arrive as `kit-upgrade` merge items if you edited them. No action.
- **The five card templates carry each field's shape and a pointer to its rule, not the rule.** The `## QA Verdict` paragraph in `ISSUE`, `BUG`, `REFACTOR` and `SUBTASK` now points at `qa.md` step 4, `landing-gate.md` § 3 and `kit_qa_evidence_kinds` instead of listing the evidence kinds and refusals; the status-folder sentence and the lite-path and decision-citation comments cite `move-issue.sh --help`, `MANUAL.md` and `DECISIONS.md`. Cards minted from now on carry the pointers; existing cards are untouched, and no field, heading or table column changed. Template files arrive as `kit-upgrade` merge items. No action.
- **The front-door pages and the board `ls` line point at the set's home instead of listing it.** `README.md`, `.claude/skills/README.md`, `MANUAL.md`, `SEED.md`, `PROJECT.md` and `UPGRADE-SEAT.md` cite `kit_qa_evidence_kinds`, `scripts/lib/status-folders.sh`, `ls .claude/roles` and the contract sheets. `progress.md`, its skeleton, `pm.md`, `orchestrator.md`, `orchestrate/SKILL.md` and `MANUAL.md` § Session start list the board with `ls $(ls -d progress/*/ | grep -v -e /done/ -e /history/)` (the orchestrator's two also leave out `declined/`), which follows a folder you add. `MANUAL.md` § The Dev → QA handoff now says QA never rewrites a branch it reviewed. No rule changed; if you edited those files, expect merge items.
- **`doctrine/staleness.md` § C now rules that a rule stated in prose is a list in prose.** One home states a rule; every other surface cites it or derives it, with a short allocation by surface and the exception that a role's own act stays inline. No action.
- **A `deciding` `check-board.d` arm that exits with anything but 0 or 3 now makes the board verdict not `clean`.** It used to print "did not run to a verdict" and leave the verdict `clean ✓`, so a broken arm read as armed and `release.sh` gate (d) passed. The report now prints a `⚠` line naming the arm and its status, with a `Next:`; end the arm `0` (found nothing) or `3` (found something), or declare it `advisory`, which stays report-only. Only a `deciding` arm is affected.

