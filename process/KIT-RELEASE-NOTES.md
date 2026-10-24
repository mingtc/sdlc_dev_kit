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

### Changed

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

## [0.12.0] — 2026-10-22

### Action required

- **A QA Verdict row that points at its own card now refuses the landing.** The gate (`finish-pr.sh`, `move-issue.sh <ID> qa_complete`,
  `read-verdict.sh`) refuses an evidence pointer that names the card's own file in any board column (`progress/<status>/`; `qa-verdict-self-pointer`):
  the card records the review, and its path changes when it moves, so such a pointer stops resolving after the move. An in-flight card
  whose table does this is refused at its landing. Before it lands, re-point each such row at the content the AC is about (a source,
  test, document or fixture line, with its quote) and commit the card to the trunk (`./scripts/register-commit.sh`). The `Verify:` line reads each in-flight card's table as committed to the trunk, through `read-verdict.sh`; a card's prose is not read.

  Verify: d="$(mktemp -d)"; r=0; for f in progress/*/*.md progress/subtasks/*/*/*.md; do case "$f" in */qa_complete/*|*/done/*|*/declined/*|*/history/*) continue ;; esac; [ -f "$f" ] || continue; id="$(basename "$f" | grep -oE '^[A-Za-z0-9]+-[0-9]+(-s[0-9]+)?')"; [ -n "$id" ] || continue; if KIT_PROGRESS_DIR="$d" ./scripts/read-verdict.sh "$id" 2>/dev/null | grep -q 'would REFUSE this table (qa-verdict-self-pointer)'; then r=1; fi; done; rm -rf "$d"; exit $r

- **A project that declares a second register: arm `[r]` now reads its ids too, and a landing refuses one its branch introduces
  that no PRD cites.** Arm `[r]` reads every register in `REGISTERS` by its own id shape, as arm `[l]` does, and its line names the
  registers it read. A second register's live id that no PRD cites and is not marked `[cross-cutting]` is now listed, and a branch that
  introduces one is refused at landing, as for a `D-NN`. Before your next landing, run `./scripts/check-board.sh`: cite each listed id
  from the PRD it serves, or mark the entry `[cross-cutting]` if no PRD should cite it. A project with only `requirements/DECISIONS.md`
  has nothing to do.

### Changed

- **`check-board.sh` finds the register line that cites an answered question when its path contains `+ ? ( ) { } |`.** Such a path was never matched, so its question stayed listed as answered, not reconciled. `process/KIT-RELEASE-HISTORY.md` also lists under `### Action required` the two `[0.4.0]` and four `[0.3.0]` obligations the first regrouping left behind, so `kit-upgrade.sh` puts them in the checklist. `UPGRADE-SEAT.md` step 7 re-dates a living standing handoff to the day after today. No action.
- **`setup.sh` reads the `## Archived` heading as `archive.sh` and `kit-init.sh` do.** A heading with trailing whitespace or extra spaces is now reported missing. The skills, the launch-pack and run-report templates, the shipped `progress.md`, `consumers/`, `UPGRADE-SEAT.md` step 7 and a few front-door sentences are corrected or clarified; a vendored skill copy you have not edited can be re-copied, and an upgrade seat now re-dates a living standing handoff after its own. No action.
- **`kit-upgrade.sh` now lists the `[0.3.0]` and `[0.4.0]` obligations.** `process/KIT-RELEASE-HISTORY.md` groups them under `### Action required`, which the checklist reader needs; a project older than 0.4.0 gets those items instead of a checklist without them. Upgrading by hand: read that heading.
- **`reachability_walk.py --self-test` proves the `$VAR/` edge on a fixture.** It ends `SELF-TEST FAIL` if a script's `"$VAR/dir/file"` citation no longer resolves; the line about your own tree's probe file stays as a fact about your tree. `staleness_greps.py` labels its shipped base-rate figures undated and not yours.
- **`release.sh` prints "all gates green" after gate (g)**, not before it, so a refused ship manifest no longer follows that line. `new-refactor.sh --help` shows `--prd PRD-NNN|n/a`; `read-verdict.sh --help` shows `<PREFIX>-012`; `archive-progress.sh --apply` lists `progress/history/INDEX.md` among the files it wrote, and its review line includes it.
- **`finish-pr.sh`'s `Plan:` shows the `--note` with its `(verdict read at <sha>)` clause.** The local-commit line in `move-issue.sh`, `finish-pr.sh`, `archive.sh` and `subtask.sh` reads "publishing to the trunk next". No action.
- **The metadata guard names both routes and no longer refuses an amend that adds a README to a code commit.** A metadata-only commit on a branch is still refused; its `Next:` now offers `register-commit.sh` or adding the path to the code commit it describes (`git commit --amend`). An amend is judged on HEAD's paths plus the staged ones, so it passes when HEAD carries code. Put `--amend` before any `-m`: the refusal's `Next:` says so, and `process/MANUAL.md` states that the guard runs only once `CODE_GLOBS` is declared. No action.
- **`register-commit.sh` no longer tags a subject twice.** A `--message` that already begins with the `--role` tag (`[PM] Record D-12`) keeps it once; a tag followed by `:` or by no space (`[PM]: Record D-12`) is also kept once, written with a space after it; one that begins with another declared role's tag is refused (`register-message-tag-mismatch`), and its `Next:` line says to drop the tag or switch the hat. The first line it prints now says it is publishing next. No action.
- **A landing's Activity entry always names the revision the QA Verdict was read at.** `finish-pr.sh` appends `(verdict read at <sha>)` to a `--note` you pass, as it already wrote it in the default note; the direct-to-trunk `move-issue.sh <ID> qa_complete` writes the same string, and both scripts' `--help` say so. No action.
- **A verbatim quote of a backticked line now passes the QA gate.** The evidence cell was already read with its backticks removed; the cited line now is too, so a line quoted exactly as the file has it matches. No action.
- **A quoted phrase in an evidence cell's prose is no longer checked as a quote.** A pointer's quote is the first double-quoted string after it, and each next one only when it follows the previous quote with whitespace or `;` alone between; any other double-quoted phrase is prose. A row that listed several quotes for one pointer separated by a comma or a word needs `;` or whitespace between them to keep each checked. No action for a row that already passed.
- **`check-board.sh` `[t]` can list an answered question it formerly hid.** A register line that names the question file only counts once it was written or edited in a commit at or after the answer; a ruling written before the answer no longer clears it, and an entry discharged in place (the path moving from its Ruling to its Provenance) does. Where the source has no readable history the arm keeps the old test and prints a note. No action required.
- **An arm `[l]` citation of a second register's id now resolves.** Arm `[l]` and the landing's `board-citation-unresolved` check accept, for each `REGISTERS` record in `check-board.sh`, ids of that record's own shape (`R-[0-9]+`, say) instead of `D-NN` only; a citation of such an id used to be reported as dangling. The `forks:` check still reads `D-NN` registers only. No action.
- **The Orchestrator's reconcile leg discharges a `--decision` question's entry in place.** A question asked with `ask.sh --decision D-NN` leaves a `WORKING DEFAULT` Ruling; the leg takes the token off that entry and cites the question file in its Provenance rather than minting a second `D-NN`, and lands the parked card's edit with `register-commit.sh` before the move so it is not stranded in the leg's checkout. The question file tells the principal that an answer handing the decision back adopts the working default. Role text and printed text only; no action.
- **A delegating answer is a ruling.** When a principal answers a question "I don't know — use your judgement", the Orchestrator's PM-hat leg records it as a ruling that adopts the question's working default, quoting the answer and citing the question file — a new `D-NN`, or, for a question asked with `--decision`, the working-default entry discharged in place — and does not file the question again. Role text only (`orchestrator.md`, `orchestrate/SKILL.md`, `contracts/ask.md`); no action required.

