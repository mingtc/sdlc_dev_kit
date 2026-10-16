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

- **End each register entry's Provenance with the work item that resolved it, or `no work item`.** A register entry is committed to
  the trunk before the branch is cut, so the branch diff never showed it and a card could hand off `forks: none` over it. Both
  `move-issue.sh … dev_complete` and the landing now take each entry ADDED to a D- register since the card left `todo/` (an edit to an
  existing entry is not attributed) and attribute it from its Provenance paragraph, read at the trunk tip: a work-item id that names a
  card on the trunk (any column) attributes it, else the subject of the commit that added it does, and `no work item` attributes it to
  nobody. An entry attributed to the card must be in `forks:` (`forks-contradicted`); an entry attributed to no card refuses with
  `forks-attribution-unclear`, whose `Next:` names three exits: add the id to `forks:`, name the owning card's id in the Provenance, or
  end the Provenance with `no work item` (for the last two, run `scripts/register-commit.sh` from a checkout at the trunk tip). At the
  landing the window ends at the commit that moved the card to `dev_complete/`, but Provenance is still read at the tip, so a fix
  committed after that move clears it. stdout prints a `FORKS_ATTRIBUTION_CHECK:` line saying which bound ended the window, or that the
  check did not run and why. Entries already in your register are unaffected.

### Changed

- **`register-commit.sh` now refuses a checkout cut before the trunk changed the file.** It lands your whole file, so a branch
  cut before another lane's register entry reached the trunk deleted that entry without a word. It now merges the trunk's copy
  into yours first and refuses (`register-checkout-stale`) when yours lacks what the trunk gained; nothing is changed on the
  trunk. The `Next:` names the exit: bring the trunk's file into your checkout, re-apply your edit, re-run. A deliberate removal
  from an up-to-date copy still lands.
- **The adapter's supersession bullet now names the stamp rule.** When a document you write replaces another, the replaced one
  is stamped in the same commit (`process/doctrine/staleness.md` § A.1) and kept, not deleted (`process/doctrine/retention.md`
  § A.1). Merge the clause into your `AGENTS.md` if you want sessions to see it; nothing refuses.

## [0.9.0] — 2026-10-12

### Action required

- **The hat file moved from `.claude/session-role` to `.kit/session-role`, defined once in `scripts/lib/hat-file.sh`.** The
  harness refuses a session's write under `.claude/` in every permission mode but bypass, so an unattended session could
  never declare a hat. The upgrade replaces the two hooks and adds the lib where you never changed them; do the rest: merge
  `.gitignore` so it ignores `.kit/session-role` (replace the `.claude/session-role` line), delete a leftover
  `.claude/session-role`, and change any instruction of yours that tells a session to write the old path. A hook you changed
  reads the path from the lib: `. scripts/lib/hat-file.sh`, then `$KIT_HAT_FILE_REL`. With the lib unreadable the gate blocks.

  Verify: git check-ignore -q .kit/session-role && [ -f scripts/lib/hat-file.sh ] && [ ! -e .claude/session-role ]

- **The release and refactor routes are now `DELETE-IF-UNUSED`: at graduation, remove each or record keeping it on purpose.**
  `scripts/release.sh`, `scripts/new-refactor.sh`, `.claude/roles/refactorer.md`, `.claude/agents/refactorer-worker.md` and
  `.claude/templates/REFACTOR.template.md` now declare the marker, so `check-board.sh` `[g]` names each until you decide. A project that
  ships nothing, or never restructures, deletes them (with the `Refactorer` row of the ladder in `.claude/roles/orchestrator.md`, and writes `no` and the reason on the Refactorer row of `PROJECT.md` § Roles,
  or `N/A` on the release-ritual row of the gates table). One that keeps them adds, per file, the line
  `- **`<path>` (DELETE-IF-UNUSED) kept, on purpose.** <why>` to `process/LOCAL-PROCEDURES.md` (`process/SEED.md` step 8). The upgrade
  adds the marker only to a file you never changed; add the decision for the others yourself.

- **`kit-upgrade.sh --finish` now moves the marked checklist to `process/upgrades/<from>-to-<to>.md` instead of
  deleting it, so the record survives a squash merge.** The directory is created on demand; a project's
  `KIT-MANIFEST` does not list it. **Commit the new file with the rest of what `--finish` writes.** `--finish`
  refuses if that path already exists.

- **An upgrade now checks your open cards against the new kit's landing checks.** At staging,
  `kit-upgrade.sh` runs `forks:` over every `.md` file in `in_progress/`, `dev_complete/` and `blocked/` (a card headed
  by the creators' comment included), the QA Verdict check over `dev_complete/` cards and any other open card that
  already has a `## QA Verdict`, and the Ablation check over `dev_complete/` cards, from the new kit's own
  `scripts/lib/` (staged under `.kit-upgrade/lib/`). Each card they would refuse is a checklist item naming the rule
  id; a card whose `branch:` resolves to no branch, or a file with no frontmatter, is an item saying it could not be
  checked. `--finish` runs them again and refuses
  (`upgrade-open-card-refused`) while any would still be refused. **Before `--finish`, fix each listed card as its
  own landing would require, or check by hand the ones that could not be run.**

- **`kit-upgrade.sh --finish` now runs a `Verify:` command for the Action required entries that carry one, and
  refuses (`upgrade-verify-failed`) while one fails.** The first run copies each command into its checklist item
  and stages the new notes; `--finish` reads the command from that staged copy, runs it in your tree, and the
  archive under `process/upgrades/` lists every other item as declared, unverified. Entries of `0.7.0` and
  `0.8.0` carry one where a command can read the tree (your `CLAUDE.md` gone, `core.hooksPath` set, `TEST_GLOBS`
  declared, `PROJECT.md`'s `principal:` filled). **When you upgrade from before those releases, do each such item
  for real before marking it: a mark over undone work no longer stamps the version.**

- **If you wrote your own script that calls `kwt_lock` or `kit_on_exit` (`scripts/lib/exit-trap.sh`), end it with
  `exit 0`, or a clean run now reports 1.** The cleanup trap cannot tell a crash from a clean end on bash 3.2 any
  other way.

- **`finish-pr.sh` and `subtask.sh move <slice> qa_complete` now refuse when the `## QA Verdict` was committed by
  the same agent, in the same session, as the branch's code** (rule id `qa-verdict-same-agent`). The record comes
  from new Bash hooks (`scripts/hooks/agent-record.sh`), which store which (session, agent) made each commit as
  `refs/kit-agent/<sha>` — the harness's per-agent id for a dispatched agent, `main` for a session's own thread. A
  dispatched QA agent, or a fresh session, is a different identity and lands; one session's own thread writing
  both is refused. When either side has no record (hooks not wired, a commit made outside the harness) it prints
  `AGENT_CHECK: UNRUNNABLE` and lands. **To adopt it: re-copy `.claude/settings.json.example`'s
  `PreToolUse`/`PostToolUse`/`PostToolUseFailure` Bash entries into your `.claude/settings.json`; review in a
  different agent or session — `/orchestrate`'s QA leg already is its own agent.** Every trunk push the kit
  makes now also pushes `refs/kit-agent/*`, and the landing fetches them into `refs/kit-agent-remote/*`
  ([`contracts/agent-record.md`](contracts/agent-record.md)).

- **`finish-pr.sh` and `subtask.sh move … qa_complete` now refuse a branch that introduces a finding in a
  board property it touches** — the same checks `check-board.sh` reports, read on the tree the landing would
  produce: a card id that disagrees with its filename or repeats (`[d]`), a `blocks:`/`blocked_by:` no card
  answers (`[i]`), a `[decision: D-NN]` citation that resolves to no live or to a retired entry (`[l]`), a
  `requirements/` change that leaves a CORPUS forward reference dangling or landed-but-unflipped, or a register
  entry no PRD cites and no `[cross-cutting]` marks (`[p]`, `[r]`), a register change that leaves an entry not
  exactly three fields or a reopened one unstamped (`[q]`). Only a finding the branch **adds** is refused; one
  the trunk already carries stays `check-board.sh`'s to report. The rule ids are `board-id-integrity`,
  `board-blocks-asymmetric`, `board-citation-unresolved`, `board-corpus-coverage`, `board-register-shape`.
  **Before your next landing, run `./scripts/check-board.sh` over any in-flight branch that adds a register
  entry (it needs a PRD citing it, or `[cross-cutting]` at the head of its Ruling) or touches a card, a
  citation or `requirements/`.** The landing reads its operands by shape from the trunk's `scripts/check-board.sh`
  (`STATUS_FOLDERS`, `ISSUE_ID_KEY`, `ISSUE_ID_PATTERN`, `FRONTMATTER_SCAN_LINES`, `REGISTERS`,
  `CITATION_EXCLUDE`, `PRD_SURFACE`, `CROSS_CUTTING_MARKER`, `CORPUS_FILE`): **if you edited one of those
  lines, keep its declared form**, or the landing refuses (`board-property-unreadable`) naming it.

- **A `## QA Verdict` table now needs at least one `test`/`file:line` row.** `finish-pr.sh` and
  `subtask.sh move … qa_complete` refuse a landing whose AC rows are all `gate-diff` or
  `fixture-diff`: those kinds carry no quote, so the gate had no line to re-read. **Before your next
  landing, give any in-flight card with such a table one `test`/`file:line` row** with a `path:line`
  and a verbatim quote.

- **An AC's text changed after a card left `todo/` now needs a `[decision: D-NN]` citation.**
  `finish-pr.sh` and `subtask.sh move … qa_complete` refuse a landing if an AC checklist bullet's
  text (separators and whitespace aside) differs from what it was when the card left `todo/`, and
  the card carries no `[decision: D-NN]` citation anywhere. **Before your next landing, check any
  in-flight card whose AC wording changed after pickup and add the citation for the ruling that
  changed it**, or move the citation onto the ruling in `requirements/DECISIONS.md`. A card whose
  history shows no move out of `todo/` (minted straight into another column) is unaffected — this
  half of the check reports UNRUNNABLE on stdout and the landing proceeds.

- **A `## QA Verdict` row now needs a resolving pointer and, for `test`/`file:line` rows, a quote.**
  `finish-pr.sh` and `subtask.sh move … qa_complete` refuse a landing if a `path:line`/`path:a-b`
  token does not resolve at the revision being landed, if a `test`/`file:line` row carries no
  verbatim quote in double quotes after the pointer (e.g. `src/add.js:12 "return a + b"`) or the
  quote is not on the cited line, or if the pointer cell is a stock non-answer (`n/a`, `tbd`, `see
  above`, `-`, `x`, `...`, `?`, any `<...>` span, case-insensitive). An AC bullet separated by `-`
  or `:` is also now read into the table's one-for-one check (previously only `—`). **Before your
  next landing, add a quote to every `test`/`file:line` row in any in-flight card's `## QA Verdict`
  table and fix any pointer that does not resolve.**

- **`scripts/ask.sh` now refuses when `--role` names the same seat as `PROJECT.md`'s declared `principal:`**
  (compared case-insensitively, after trimming) — an asker cannot be the one who answers. If a seat of yours
  asks under the role your `principal:` names, name a principal that seat does not wear, or have another seat
  ask.

- **The `[decision: D-NN]` citation a `forks:` landing check reads now recognises a capitalized
  label, a no-space colon, a comma list, and a `..` range** (`[Decision: D-NN]`,
  `[decision:D-NN]`, `[decision: D-NN, D-MM]`, `[decision: D-NN..D-MM]`, with real ids in place of the
  letters, all cite every id named).
  `finish-pr.sh`/`subtask.sh` previously missed these forms and could let a `forks: none` land
  uncontradicted; `check-board.sh` arm `[l]` previously read some of these forms as dangling and
  others not at all. **Before your next landing, check any in-flight card whose `forks:` relied on
  one of these forms being invisible** — it will now be read, and may now refuse.

- **A commit is now refused while no hat is declared.** `scripts/githooks/pre-commit` reads the hat file
  (`.kit/session-role`, one line `<Role> <scope>`) and refuses a commit when it is absent from the checkout and from
  the repository's main checkout, with a `Next:` line naming the file and its form. The editor-tool gate never saw a
  change made by `sed -i`, a redirect or a script; every such change must pass a commit. Write the file before your
  first change in a session (the operator waiver form works too). Commits made in `.kanban-wt/` (the board scripts) need
  no file, and `kit-init.sh` and `release.sh` declare their role for their own commits. **A script of yours that runs
  `git commit` in your checkout needs the same:** `. scripts/lib/hat-file.sh`, then `env "$KIT_HAT_ENV=<Role>" git commit …`
  (nothing is left behind). The upgrade replaces the hook, the lib, `kit-init.sh` and `release.sh` where you never changed
  them; merge the rest. `MSG_OK=1` still bypasses the hook, as for its other guards.

  Verify: [ -f scripts/lib/hat-file.sh ] && grep -q KIT_HAT_ENV scripts/lib/hat-file.sh && grep -q hat-file scripts/githooks/pre-commit

- **`move-issue.sh <id> dev_complete` now runs the `forks:` check the landing runs, and refuses with its `Next:` line.** A card
  whose `forks:` is missing, malformed, names an id that is not live, or contradicts what its branch tip shows (a register
  entry the diff touches, or a `[decision: D-NN]` citation on the card) stays in `in_progress/` until `forks:` is fixed; the
  landing keeps the same check. A card whose `branch:` resolves to no local or remote branch is read against the trunk twice
  and the move says so. **Before handing off an in-flight card, check its `forks:`.** A `move-issue.sh` you changed needs the
  call to `kit_forks_check` merged in (`scripts/lib/qa-gate.sh`).

  Verify: grep -q kit_forks_check scripts/move-issue.sh

- **A `## QA Verdict` row's verdict must now be exactly `PASS`, `PASS_AC_CORRECTED`, `FAIL_AC` or `FAIL_REGRESSION`.**
  `finish-pr.sh` and `subtask.sh move … qa_complete` refuse any other spelling (`FAIL`, `Fail_AC`, `FAILED`, a blank or an
  unfilled `<…>` cell) with `qa-verdict-token-invalid`; before, only the two exact FAIL tokens were read, so a mistyped
  FAIL landed. **Before your next landing, read the verdict column of any in-flight card's table** (backticks and bold are
  still stripped). An upgrade's open-card re-check lists a `dev_complete/` card that would now refuse.

- **`setup-consumer.sh` no longer prints blanks to a consumer, and `consumers/update_vendored.sh` gained a seam and three flags it
  needs.** The to-do list carried an unfilled first-install command and `<ENV_VAR_NAME>` lines no maintainer was told to
  fill. It now asks `update_vendored.sh` for them: the first-install form is `install_hint()`, the configuration names are
  the new `CONSUMER_CONFIG` seam, and `--print-unfilled` lists every seam, the pin line, either install hint and
  `CONSUMER_CONFIG` still holding a `<blank>` (both scripts refuse while it lists any). **A project that distributes
  through `consumers/`: merge `CONSUMER_CONFIG`, `--print-unfilled`, `--print-config` and `--print-install-hint` into your
  filled `update_vendored.sh` and list your configuration names in `CONSUMER_CONFIG`; the new `setup-consumer.sh` refuses
  against an updater that lacks the flag.** Nothing to do if you have no `consumers/`.

  Verify: [ ! -f consumers/update_vendored.sh ] || grep -q -- --print-unfilled consumers/update_vendored.sh

- **`kit-init.sh --prefix` no longer rewrites `KIT-FEEDBACK.md` in `.claude/roles/orchestrator.md`.** The orchestrator
  checklist named `process/<PREFIX>-FEEDBACK.md`, a file nothing else reads. A project initialised with `--prefix` before
  this has the prefix in that name: change that one word back to `KIT-FEEDBACK` in the orchestrator's checklist.

  Verify: grep -q 'process/KIT-FEEDBACK.md' .claude/roles/orchestrator.md

### Added

- **`check-board.sh` arm `[c]` reports a `progress.md` that trails the last code commit.** It counts commits after the last one
  to touch `progress.md` that touch a `CODE_GLOBS` path (board moves and register edits do not), and says so when `CODE_GLOBS` is
  undeclared. Report only. Nothing to do.

- **`check-board.sh` reports a remote branch left behind by a landed card.** A second `[f]` section names a branch whose card is
  in `done/` or `qa_complete/`, read from the remote-tracking refs as last fetched. Report only. Nothing to do.

- **`SEED.md` and arm `[g]` name `scripts/test/**` for `TEST_GLOBS`.** `[g]` reports a declared `TEST_GLOBS` that does not cover
  the kit's own self-test, which a bare `test/*` misses. Report only. To clear it, add `"scripts/test/*"` to `TEST_GLOBS`.

- **`check-board.sh` gains arm `[s]`: a worker pin that disagrees with the ladder.** It compares each leaf-worker
  pin's model and effort with its ladder cell and, where the cell is still unfilled, with what `set-models.sh` last
  wrote (new file `.claude/model-pins.record`, written only by `set-models.sh`). Report only. It cannot see a model
  set by a launch flag or session toggle, or a hand edit on a tree where the ladder is unfilled and `set-models.sh`
  never ran. Nothing to do.

- **`process/UPGRADE-SEAT.md`: the brief for an upgrade-only agent seat.** Written in the owner's voice, it
  carries the authority for the upgrade (recorded, and asked of the human or the `principal:` only when the brief reached the seat second-hand, including for the
  agent's own instructions file) through a staged worktree, the checklist, the self-test, your own gates, landing,
  `--finish` and a handoff. Nothing to do; hand it to a seat when you next upgrade.

- **The unattended launch profile gains a Stop hook.** `.claude/settings.unattended.json.example` now wires
  `hooks.Stop` to `scripts/hooks/stop-ask.sh`, which blocks a turn once when it ends on a question nobody is
  there to answer, naming `scripts/ask.sh`; it also sets `env.KIT_UNATTENDED=1`, which `/start` § 4 reads to
  end on a next action or an `ask.sh` filing instead of a menu. **If you already copied this profile into your
  own launch config, re-copy it (or add the `hooks.Stop` and `env` blocks by hand) to pick this up — nothing
  breaks if you do not.**

- **The self-test gains a case that stamps the shipped tree with `kit-init.sh` and refuses on any `check-board.sh`
  `[l]` finding.** It reads `process/` and the root documents, so a shipped document that illustrates a citation
  form with real digits fails there instead of in an adopter's day-one self-check. No action needed.

### Changed

- **Contract sheets, role docs, templates and script headers now list what the code does.** `ask.md` and `ask.sh --help` name the refusal of a
  `--role` equal to the principal; `landing-gate.md` and `release-ritual.md` list the QA-verdict, `forks:`, ablation, stacking and approved-ship-manifest
  refusals; the card templates show the bracketed `forks: [D-NN, ...]` form, say any `word:number` in a pointer is read as a `path:line`, and name the
  refusal of a table with no `test`/`file:line` row; `qa.md` says `board-property-unreadable` is not the branch's fault; the manifest's lists were
  re-derived; `UPGRADE-SEAT.md` step 7 writes its handoff to `dev/handoffs/<date>-upgrade.md`; `config.sh` and the adapter template say glob entries are
  `case` patterns (`src/**/*.js` misses `src/main.js`). Dangling pointers, stale counts and incident narrative were cut. No action.

- **Shipped text no longer uses a maintainer-only word for the project the kit was cut from, and the card templates ship the `shadow-check` row as a
  prompt.** The wording is "the project the pattern came from", or the clause is cut; `register-commit.sh --help` examples use `<PREFIX>-014`. A card minted from the new templates carries
  `<assertions removed: …>` in that row, which the landing already refused as a placeholder: QA replaces it with `assertions removed: none` or
  each removed or weakened assertion. Cards already minted are unaffected. The ladder tables in the role docs now name `set-models.sh` as writing the
  pins and the orchestrator's row, not their own table. No action.

- **Skill text corrections.** `orchestrate` and the orchestrator role list the board with plain words instead of brace expansion (which fails under
  `dash`); `using-skills` names its implementation skills; two worked examples use the id-keyed plan filename; `safety-net-check` says the characterization
  tests land under a chore card minted first. No action.

- **A required option left out now exits 2 in every script, like an unknown option.** These exited 1: `move-issue.sh` without `--role`,
  `new-issue.sh` / `new-bug.sh` / `new-refactor.sh` without a valid `--id`, `archive-progress.sh` without `--milestone`,
  `subtask.sh new` without `--title`, and `kit-init.sh` without `--prefix` or `--trunk` (its other unmet preconditions stay 1).
  A missing or surplus positional keeps its status. **A script of yours that branches on exit 1 from any of these: branch on 2.**

- **`ask.sh` reads a principal written as a phrase, and refuses a channel outside the repository.** A `principal:` of `the PM role`
  or `The PM seat` now names the PM seat, so `--role PM` is refused (before, only the bare word was); a `nobody: …` principal still
  refuses no one. An absolute or `..` channel is refused (`ask-channel-unusable`) instead of being re-rooted or written beside the
  repository; a channel that names a file still has each question appended. No action unless your channel line is absolute.

- **The front door now says the Claude Code hooks are opt-in, and `MANUAL.md` lists them by a command, not a list.** `README.md`,
  `process/SEED.md` and `/start` say the hooks stay inactive until `.claude/settings.json.example` is copied to
  `.claude/settings.json`; `process/MANUAL.md` § The default path is lite gives the one command that lists what it wires and
  names the unattended profile. `role-gate.md` scopes "no matcher for shell commands" to gating matchers; the Dev session
  phrase has an unattended ending; `/start` says what the principal is for and what an unattended launch does before day one. No action.

- **The entry points a reader meets before a first commit now say how to declare the hat.** The `AGENTS.md` stub, the
  `PROJECT.md` role-gate row, `/start`, How to upgrade step 2 and `UPGRADE-SEAT.md` each say to write `.kit/session-role`
  (one line, `<Role> <scope>`) first; the stub no longer calls the hat "a session hook" only (the commit guard reads it
  too). The self-test's old-path scan now covers every file the manifest lists. No action.

- **Older releases' notes moved to `process/KIT-RELEASE-HISTORY.md`, unchanged but for added `Verify:` lines.** This file keeps § How to upgrade, § How
  versions work, § Unreleased and the newest release; `kit-upgrade.sh` reads both files, and stages the history beside the
  notes so `--finish` runs `Verify:` lines from it. Upgrading by hand from an older tree: read the history file's sections
  newer than your `KIT-VERSION` too. No action.

- **The session-start step now says to write the hat file, not only to say the hat.** The adapter template's step 4 and
  `process/MANUAL.md` § Session start name `.kit/session-role` and its form before any change by any tool, whether or not
  the `require-role` hook is wired. An adapter you already have keeps its older wording: copy the step across if you want
  it. No action.

- **The upgrade timing rule has one home: `process/contracts/kit-upgrade.md` § 2.** Run the upgrade when you hold the release
  unless a leg is mid-card; otherwise record the deferral as a work item, or file it through `scripts/ask.sh` when unattended,
  never a question in the reply. A principal's "eventually" does not override it. The adapter template's upgrade row,
  `PROJECT.md` § The kit, upstream and this file's § How to upgrade cite it. No action.

- **Refusal messages now carry a `Next:` line.** Every refusal made through `kit_refuse` (the landing checks, `ask.sh`,
  `set-models.sh`, `kit-upgrade.sh`, the commit hooks) names the step that clears it, or the escalation when none lies
  inside the agent's authority. Only the message text changes; rule ids, exit codes and records are as before. No action.

- **The same now holds for the rest of the scripts.** The board mover and landing scripts (`move-issue.sh`, `finish-pr.sh`,
  `subtask.sh`), the creators, the archive sweeps, `register-commit.sh`, `next-id.sh`, `notify.sh` and its Telegram adapter,
  `kit-init.sh`, `release.sh`, `verify.sh`, the role gate and `setup.sh` refuse through `kit_refuse`: a `Next:` line and a `refusal=`
  progress record. Exit statuses are unchanged; some message wording moved onto the `Next:` line. No action.

- **The board lock and the worktree refusals do too.** A held lock, an unregistered or failed `.kanban-wt/` bootstrap, a sync or detach over
  uncommitted or unpublished board work, and "not inside a git repository" now refuse through `kit_refuse` (rules `kanban-lock-held`,
  `kanban-sync-dirty`, `kanban-sync-unpushed`, `kanban-wt-*`, `not-in-git-repository`): a `Next:` line and a `refusal=` record, same exit
  status. A failed push after a landing or a subtask commit says how to publish it. `kit-init.sh` now refuses an `ARCHIVE.md` without the
  exact `## Archived` heading in its preflight, before anything is written. No action.

- **A dispatched leg's report now types its claims, and a runner promotes only a PASS backed by one.**
  `process/MANUAL.md` § The leg-report contract is the one statement: every claim is OBSERVED (a command
  with its output, or a `path:line` with a verbatim quote), INFERRED (with what it was concluded from) or
  NOT CHECKED. Both shipped runners' Dev, QA and park schemas now require `observed`, `inferred`,
  `not_checked` and `children` (`none` or `all_returned`: a leg that dispatches waits for every child and
  has no way to report "awaiting"). A PASS whose `observed` list holds no claim with its proof, and a
  reply whose `children` is neither value, are filed `NO_VERDICT` (a Dev reply: `LEG_ABORTED`); every
  record's `leg_notes` carries the three lists. The leaf-worker definitions, the orchestrate skill (§ 3:
  read the verdict from the card on the trunk before promoting) and the orchestrator role doc point at
  the contract. **Nothing to do if you run the shipped runners — the Workflow tool enforces the schema.**
  **A project that hand-wrote a runner, or a driver or test stub that returns a QA leg's reply to a
  shipped runner, must add the four fields**; without `observed` a stubbed PASS now reads `NO_VERDICT`.

- **`PROJECT.md`'s `principal:` field now reads `TBD`, `[fill in…]`, `{{ … }}`, an underscore-only fill, or a
  whitespace-only backtick fill as unfilled**, through the one blank test `scripts/ask.sh` and `check-board.sh`
  `[g]` now share. A project whose `principal:` happens to carry one of these forms today will see `ask.sh`
  refuse and `[g]` report it unfilled where it previously read as declared — fill it with a real name,
  role or channel.

- **`check-board.sh` arm `[q]` reads a register's history** (report only; a landing never refuses on it). It names an
  entry whose Ruling text a commit changed with no stamp (`**Amended…**`, `**CONFIRMED…**`, `**Clarified…**`,
  `**SUPERSEDED…**`, `**WITHDRAWN…**`, or a `WORKING DEFAULT`/`WITHDRAWN` head) among the lines it added, over the
  commits since the commit hook arrived; a numbered list that collides after `## Findings` (how findings land outside
  that section); and a colon-labelled amendment (`**Amended 2026-10-05:**`) as an extra fragment, like its period form.
  Nothing to do; stamp a changed ruling in the same change, as the register's own rules already say.

- **`check-board.sh` arms `[e]` and `[h]` scan every commit since the commit hook arrived, not the last 20.** A commit that
  bypassed the hook is no longer forgiven by 20 later ones. A `Revert "…"` is exempt from the `[Role]` prefix only when its
  diff undoes the commit its body names, and a `fixup!`/`squash!`/`amend!` only when it names an earlier commit and touches
  nothing that commit did not; the same subject over any other diff is reported. In a clone with no derivable start the
  window stays the last 20. Nothing to do; a commit reported now needs its `[Role]` prefix, which cannot be added to
  published history, so expect old bypasses to stay listed.

- **`check-board.sh` arm `[m]` names a landed card with neither a `prd:` value nor a `prd_reason:`**, instead of leaving it
  out of its count. Report only; give such a card a PRD, or `prd: n/a` with a one-line reason.

- **`check-board.sh` arm `[g]` flags a `TEST_GLOBS` entry that matches no file** (matched with `case` against repository
  paths, as the ablation rule does), and reports it with a `⚠` until it matches; it never holds graduation back. Fix the glob, or
  add the first test file it should match.

- **The commit hook and `check-board.sh` `[h]` refuse more generated trailers:** `TOOL_TRAILER_MARKERS` gains model-family
  words (`opus`, `sonnet`, `haiku`, `fable`, `llama`, `mistral`, `grok`, `deepseek`, `qwen`), and a blank before the
  colon (`Co-authored-by : …`) no longer slips past. A project whose harness adds such a trailer must configure the
  harness not to, or extend the list in the hook, in one place.

- **`check-board.sh` arm `[l]` now states its own population**: the count of marker-form
  `[decision: ...]` citations it checked against the count of bare `D-NN` mentions it found
  outside any marker, instead of a bare `✓ none` that read as having seen every reference to the
  register.

### Fixed

- **`new-issue.sh --help` and `new-bug.sh --help` show `--prd n/a`.** The usage line reads `--prd <PRD_PREFIX>-NNN|n/a`, with one line saying `n/a` is the lite path: no PRD, `stories: []` unless `--stories` is given, and you fill `prd_reason:`. No action.

- **Two prose corrections.** QA's AC-illustration step (`qa.md`, MANUAL step 6) now says a register entry added on the branch is also named in
  `forks:` and cited by a PRD or marked `[cross-cutting]`; `safety-net-check` tells a PRD-free chore to mint with `--prd n/a` and fill `prd_reason:`. No action.

- **`--prd n/a` mints a PRD-free card; an unattended `/start` reviews `dev_complete`.** `new-issue.sh` and `new-bug.sh` with `--prd n/a` write
  `stories: []` and no PRD link or `<story ids>` blank (fill `prd_reason:`); a mint without the flag is unchanged. The unattended pick is the
  oldest `in_progress`, else the oldest `dev_complete` (taken as QA), else the first `todo`. Needs `scripts/lib/card-head.sh` (arrives with
  the upgrade). No action.

- **`kit-init.sh` with no arguments printed its re-run line as `./scripts/kit-init.sh ''`; `move-issue.sh` without `--role` printed its whole help.** The
  first now prints the bare command, the second the error and one synopsis line. The `pre-commit` hook reads `CODE_GLOBS` through
  `scripts/lib/glob-array.sh` and refuses an off-trunk commit while that file is unreadable (it arrives with the upgrade). Exit status 2 is documented once
  as "a usage error" (a required option left out is one). No action.

- **The session-start hook and the self-test no longer require a grep at a fixed path.** The hook's over-budget summary and
  the harness named a grep binary by its path; on a system that keeps `grep` elsewhere the summary came back empty and the
  harness reddened with no defect behind it. They call `grep` from `PATH`, as every other shipped script does. No action.

- **Usage text and refusals now say what the code does.** `notify-hook.sh --help` answers without waiting for stdin, and
  `notify.sh --help` prints its header (a send without `--session` is a silent no-op); a creator's usage prints the same text
  whichever path reached it; `verify.sh --help` says `--scope` needs a `select` gate; `release.sh --help` says
  `--approve-shipped` writes a draft manifest; `archive-progress.sh --before` refuses a date that does not exist; the ablation
  check says a `TEST_GLOBS` declared empty on purpose is declared, not "undeclared ... adopter action required". The array
  read for that check and for `check-board.sh` is one function in the new `scripts/lib/glob-array.sh`. No action unless you
  edited `check-board.sh` or `lib/qa-gate.sh` (take the new file with the upgrade).

- **A QA Verdict row whose verdict is written in backticks or bold now counts.** The card templates show the verdict
  token in backticks; `finish-pr.sh` and `subtask.sh` read `` `FAIL_AC` `` and `` `FAIL_REGRESSION` `` as no verdict and
  let a failing row land. They now refuse it (`qa-verdict-fail`). No action needed.

- **A decision-register entry written as the format shows it is now read.** `requirements/DECISIONS.md` shows the
  `WITHDRAWN` and `WORKING DEFAULT` tokens in backticks; `ask.sh --decision` read a backticked `WITHDRAWN` as a
  standing ruling and left it untouched, and `check-board.sh` arm [q] missed a backticked head. Both now read the
  token bare, in backticks or in bold. No action needed.

- **`PASS_AC_CORRECTED` now says what it needs.** An AC changed after its card left `todo/` is refused at landing
  without a `[decision: D-NN]` citation; the third verdict's steps in `process/MANUAL.md` and `qa.md`, and the card
  templates, now say to cite the register entry that records the correction. No action needed.

- **The self-test's progress-record case no longer fails when a run straddles 00:00 UTC.** Two of its counts read a
  directory that then held two day files; it now crosses midnight on purpose and counts correctly. No action needed.

- **A card's `branch:` line with a trailing `# comment` now lands and re-checks.** `finish-pr.sh` and `kit-upgrade.sh` read the
  comment as part of the branch name (`branch-unnamed`, or "resolves to no branch"); every script that reads the field
  now does so through `scripts/lib/card-field.sh`, comment stripped. No action needed.

- **The self-test no longer goes red after `set-models.sh`.** The cases that test the model seam inherited the
  tree's ladder, pins and runner defaults, so they failed on any project that had run it. Each now writes the
  state it tests into its own sandbox. No action needed.

- **The AC-drift landing check no longer follows a look-alike card's history.** It could take an earlier,
  similar card's history as a new card's and refuse a landing whose ACs never changed (`forks-ac-changed-uncited`).
  It now reads the card's own `todo/` history by its id. No action needed.

- **The session-start hook's output is bounded.** The harness cuts a hook's output near 10,000 bytes, so a long
  drift report arrived as a preview. Over 8,000 bytes the hook now prints the arm headings, as many findings as fit and the
  verdict, and names `scripts/check-board.sh` for the full report. No action needed.

- **A script that crashed after taking the lock could exit 0 on macOS `/bin/bash` 3.2.** Under `set -e`,
  an unbound-variable abort reached the cleanup trap with status 0, so `finish-pr.sh`, `move-issue.sh`,
  `register-commit.sh`, `subtask.sh`, `archive.sh`, `release.sh` and the `new-*` scripts reported success for a
  landing or card that never completed. They now exit nonzero. No action needed for the shipped scripts.

- **The ablation landing check now reads the branch diff with `--no-renames`.** A declared
  `TEST_GLOBS` test file renamed to a path outside `TEST_GLOBS` (e.g. moved out of `tests/`) could
  carry a weakened assertion and land with no `## Ablation` section, because the diff's default
  rename-following hid the test's own declared path. No action needed; a card doing this now
  refuses `ablation-missing` as it already does for an in-place edit.

- **`set-models.sh` now rewrites a ladder row that is already filled.** A second `--class` (or `--all`) with a
  different pair moved the pins and the runners but left the ladder at the first values, which `check-board.sh`
  `[s]` then reported as a disagreement. The Model and Effort cells now change together with the pins, and the row's
  trailing prose is kept. No action needed.

- **The `forks-unresolved` refusal now says a new register entry also needs a PRD citation or `[cross-cutting]`.**
  Following its advice (add the ruling to the register) landed a branch the `board-corpus-coverage` check then
  refused. The message names the declared PRD surface and the marker, and `process/MANUAL.md` says the same. No
  action needed.

- **`notify.sh --help` and `notify/telegram.sh --help` no longer print the second line of their
  `KIT-DISPOSITION` marker.** The marker is one line now. No action needed.

- **`--help` skips a `KIT-DISPOSITION` marker that wraps, and `notify-hook.sh --help` no longer opens with its second line.**
  `scripts/lib/usage.sh` (and `release.sh`'s own copy of the rule) skip a marker whose first line does not end in a full stop
  up to the first line that does. Keep a marker of your own on one line ending in a full stop. No action needed.

- **The self-test no longer fails a project that removed the Refactorer.** The shadow-check landing case judged four named card
  templates; it now judges every card template (told from the PRD template by its frontmatter `type:` line) and skips an absent
  `REFACTOR.template.md` in a project that finished day one. No action unless you edited that case.

- **`qa.md` and `MANUAL.md` now say a PASS-with-AC-correction records its register entry before the card cites it.** The entry is
  yours in the same change, or the PM's already on trunk; the PM keeps or revises the ruling afterwards. No action needed.

