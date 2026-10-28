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
  git grep -nE '<PREFIX>|<project name>|KIT-[^0-9]' -- .claude/roles | grep -vE 'KIT-CLASS:|KIT-DISPOSITION:|KIT-FEEDBACK'
  git grep -nE '<PREFIX>|<project name>|<trunk>|KIT-' -- .claude/templates | grep -vE 'KIT-CLASS:|KIT-DISPOSITION:|KIT-FEEDBACK'
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

### Action required

- **`check-board.sh`'s graduation arm now reports `COMPLETE` only once a PRD exists and a card has passed QA (`qa_complete/` or `done/`), not on filled blanks alone.** A new `DAY-ONE WORK` line names whichever is missing, and `[p]` stops flagging the `forward-referenced (SEED step 6)` marker `CORPUS.md` tells you to write until day one has closed. `kit-init`'s closing `Next:` now names `PRD-001` (`./scripts/new-prd.sh <slug>`) before the first issue. SEED's done-list names the PRD and the role docs' `Model & effort contract` rows (`set-models.sh` does not write them), and says which lines are expected until the first card lands. If your project finished day one without a PRD (every card `prd: n/a`) or with no card in `qa_complete/` or `done/`, `/start` will walk SEED again until both exist: check those two.
  Verify: ./scripts/check-board.sh 2>&1 | grep -q 'DAY-ONE WORK:.*✓'

- **`check-board.sh` finds your PRDs by `PRD_PREFIX` in `scripts/config.sh`.** A project that ran `kit-init --prd-prefix <P>` now has `requirements/<P>-NNN-*.md` counted by the graduation arm's `DAY-ONE WORK` line (it could not read `COMPLETE` before) and read by arm `[r]` and the landing's coverage and `forks:` checks. `check-board.sh` no longer carries a `PRD_SURFACE` literal; it derives it from `PRD_PREFIX`; if you had repointed it, set `PRD_PREFIX` in `scripts/config.sh` to the prefix your PRDs carry instead, or they are no longer found.
  Verify: grep -q '^PRD_PREFIX="${PRD_PREFIX:-[A-Za-z0-9]*}"$' scripts/config.sh && grep -q '^PRD_SURFACE="$(kit_prd_surface' scripts/check-board.sh

- **The status folder set is declared once, in the new `scripts/lib/status-folders.sh`.** `check-board.sh`, `move-issue.sh`, `subtask.sh` (the set without `done`), `kit-init.sh` and `setup.sh` derive it from that file instead of each carrying the names, and a landing reads it from the trunk's copy of the file. If your project renamed, added or removed a status folder, make that edit once, in `KIT_STATUS_FOLDERS`, and keep `progress/<folder>/` in step with it; a script of yours that carried the names arrives as a merge item, and the names in your copy are dropped in favour of the file's. A project on the shipped folders does nothing.
  Verify: ( for d in progress/*/; do [ -d "$d" ] || continue; d="${d#progress/}"; d="${d%/}"; case "$d" in history|subtasks) continue ;; esac; case "|$(sed -n "s/^KIT_STATUS_FOLDERS='\(.*\)'/\1/p" scripts/lib/status-folders.sh)|" in *"|$d|"*) ;; *) echo "progress/$d is not in KIT_STATUS_FOLDERS"; exit 1 ;; esac; done )

### Changed

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
- **`move-issue.sh` and `lib/qa-gate.sh` print a set from the variable that holds it instead of retyping it.** `move-issue.sh --help` and its unknown-target refusal now print the target folders from the status folder set, its blocked-base warning cites `dev.md` for the rebase, `qa-verdict-no-observed` lists the evidence kinds from `KIT_QAV_KINDS` (a project that adds a kind sees it there). Refusal ids and `Next:` lines are unchanged. If you edited these scripts, expect merge items.
- **The role docs and the four leaf-worker definitions that fill a ladder cite their home for a set or another role's condition instead of restating it.** `pm.md` points at `move-issue.sh --help` for the move targets and at `MANUAL.md` for the AC-baseline carve-out of the `forks:` check; `qa.md` names the Dev as the one who rebases a stacked branch and cites `dev.md`; `orchestrator.md` and `dev-worker.md`, `pm-mint.md`, `qa-worker.md`, `refactorer-worker.md` cite `contracts/model-provisioning-seam.md` for what `set-models.sh` writes. No act, step, refusal or report shape changed, and the role docs still say "primary checkout" (the trunk stamp rewrites a role doc's word `main`, so they cannot say "main checkout"). These files arrive as `kit-upgrade` merge items if you edited them. No action.
- **The five card templates carry each field's shape and a pointer to its rule, not the rule.** The `## QA Verdict` paragraph in `ISSUE`, `BUG`, `REFACTOR` and `SUBTASK` now points at `qa.md` step 4, `landing-gate.md` § 3 and `KIT_QAV_KINDS` instead of listing the evidence kinds and refusals; the status-folder sentence and the lite-path and decision-citation comments cite `move-issue.sh --help`, `MANUAL.md` and `DECISIONS.md`. Cards minted from now on carry the pointers; existing cards are untouched, and no field, heading or table column changed. Template files arrive as `kit-upgrade` merge items. No action.

## [0.12.1] — 2026-10-25

### Changed

- **`subtask.sh new` checks `--prd` and `--stories` like `new-issue.sh`.** A malformed value is refused with exit 2, naming the option, before anything is written. No action.

- **Smaller refusals and notes now say what runs.** The pre-commit refusal for a staged card names the trunk route alone, and for a card staged beside other metadata sends the card to the trunk and offers the amend route only for the rest; `register-commit.sh`'s note for a staged copy names `git restore --staged --worktree`; `new-refactor.sh` refuses a malformed `--prd` or `--stories` like `new-issue.sh`, and all three creation scripts refuse a value containing a newline; `setup.sh`'s `kit-init.sh` line carries `--prefix` and `--trunk`. No action.

- **`staleness_greps.py` no longer prints donor base-rate figures**, and its `--json` output drops the `base_rate` key; the shipped `.gitignore` no longer lists `*.log`. A consumer of that JSON sees the key gone. No action.

- **Consumer, template and role-doc text matches what ships.** `setup-consumer.sh`'s closing list points at the upstream checkout's `ci/` and README (the consumer's repo has neither); `consumers/README.md` says refreshes and `--check`
  use the network; `LICENSE-CONTENT` no longer lists process doctrine as CC0 (it is MIT, as `LICENSE` says); `wave-runner.js` logs a Dev leg that returned nothing once; the run-report template covers an attended no-launch-pack run and
  lists its own title and heading to delete; `architect.md` has an `Agreed on:` field; `dev.md` fills the card's own `## Behaviors Preserved`; `/start` says `PROJECT.md` may name more tools the project needs; `using-skills` ends with a note telling an
  unwatched seat to decide through `scripts/ask.sh`, record and continue at gates that wait for a person. No action.

- **Script messages say what runs.** The `kit-init.sh` line in `verify.sh`'s and `finish-pr.sh`'s refusals carries the `--prefix` and `--trunk` it requires; `finish-pr.sh --help` explains `--dry-run` (it exits before the
  pre-merge gate, so it predicts nothing about it); `archive-progress.sh --apply` says "Writing to:"; `next-id.sh` outside a repository prints one error; the manual names the first card's `--id`. No action.

- **`new-issue.sh` and `new-bug.sh` refuse a malformed `--prd`, `--stories` or `--discovered-in`** (exit 2, naming the option) instead of writing it into the card's frontmatter. The shapes are those the usage text states. No action.

- **`register-commit.sh` restores a subtask card beside its parent.** A subtask card's id is its parent's id plus its suffix, so a restored slice is no longer refused as a second copy of the parent; a second copy of the slice itself is still refused. No action.

- **The card templates, `MANUAL.md` and `qa.md` say where QA evidence and a corrected AC's citation go.** The verdict and per-AC evidence live in the card's `## QA Verdict` table; `[decision: D-NN]` goes on the amended bullet's own line
  (elsewhere on the card does not count); a quoted phrase before a pointer cell's first `path:line` is refused. A reviewer in a blocked-push regime records `PASS` with the landing `deferred`. No action.

- **`kit-init.sh` tells the truth about `--enable-hooks`.** When it refuses because `.claude/settings.json` differs from the example, its re-run line leaves the flag out, as the refusal says; the header lists the settings copy
  under its hooks step; the `.gitignore` line reads "1 entry" or "N entries". No action.

- **A correctly shaped register entry is no longer refused as having a two-paragraph Why.** An entry laid out as the register shows it, with a blank line between the `**Ruling.**`, `**Why.**` and `**Provenance.**`
  fields, was read as having a Why that spans paragraphs, in `check-board.sh` arm `[q]` and at a landing. A blank line inside the Why is still refused. No action.

- **`register-commit.sh` and the role docs say what to do with your checkout's copy.** After `Published:` the edited copy stays in your checkout and a later `git pull --ff-only` is refused for it; the output
  now names `git checkout -- <path>` (or `rm` for an untracked file), as do `dev.md`, `orchestrator.md`, `qa.md`, `pm.md` and `MANUAL.md`. An unattended Dev commits its question file to the trunk with `register-commit.sh`
  before citing it. No action.

- **Texts that state what a Claude Code hook does now say it holds only with `.claude/settings.json`.** Without it nothing clears the hat file at a session start, the git commit guard still refuses a commit without a hat,
  and the agent check reports UNRUNNABLE. `kit-init.sh --enable-hooks` is offered only before `kit-init.sh` has run and in an attended session; after that, the human's `cp` is the route. The steps that write the hat file
  now create `.kit/` first. No action.

- **The card is the trunk's, in every place that said metadata may ride a work branch.** The pre-commit refusal for a card-only commit no longer offers `git commit --amend`; `AGENTS.md`, the adapter template, the card
  templates and `orchestrate` carry the exception; the landing's card-conflict note restores the card from `origin/<trunk>`. No action.

- **`check-board.sh` arm `[s]` counts only the role-doc model rows you keep by hand, and ticks only over fields it compared.** The ladder rows in `orchestrator.md`, which `set-models.sh` writes, are left out of the
  `<fill in>` line; a tree with nothing compared prints "nothing was compared" instead of a bare ✓. No action.

- **The act that turns the Claude Code hooks on is named, and `kit-init.sh --enable-hooks` makes the copy.** The harness refuses an agent's write of `.claude/settings.json`, so an agent now hands you the act: in your own terminal, at the project root, `cp .claude/settings.json.example .claude/settings.json`, then restart the session. `kit-init.sh`'s closing output, `/start`, `SEED.md` and `MANUAL.md` say it the same way; an agent suggests `--enable-hooks` and passes it only on your yes. `check-board.sh` arm `[g]` prints `hooks: off` while `.claude/settings.json` is absent; it changes no verdict. No action.

- **The card is the trunk's; never commit it on a work branch.** `MANUAL.md` § The code-vs-metadata rule and `dev.md`'s hand-off step say so, and the landing's squash-conflict refusal, when the
  conflict includes the card, names the route: drop the card edit from the branch and re-run, and land it on the trunk with `register-commit.sh`. A non-overlapping card edit on a branch still lands. No action.

- **`check-board.sh` arm `[s]` names the role docs whose own model table is still blank.** `set-models.sh` writes the ladder row and the leaf-worker pin; the per-role tables under each role doc's
  `## Model & effort contract` are kept by hand, and a `<fill in>` left there now prints one line with the count and the files. It only reports. No action.

- **A QA Verdict quote may contain a double quote, written `\"`.** A line of string literals (`{"a", 1}`) is quoted whole as `"{\"a\", 1}"`; the quote is also still any quote-free substring of the line, 8 characters or more,
  and the too-short refusal names both. No action.

- **The decision register states how a changed ruling is stamped, and the warning shows it.** A stamp is bold and dated, inside the Ruling (`**Amended <YYYY-MM-DD>.**`);
  plain text and a stamp in a later commit are not read, so an unstamped change stays reported until its history is gone. `check-board.sh`'s warning now names that shape. No action.

- **`check-board.sh` and the landing checks no longer read an id that IS in a long list as absent.** A run on an unchanged tree could report a correctly cited
  decision id as "NOT an entry" (with `printf: write error: Broken pipe`), and the next run would not. The same early close could make `release.sh` refuse a clean
  board, or `stop-ask.sh` miss a question. Every such test now reads its list without a pipe the reader can close. No action.

